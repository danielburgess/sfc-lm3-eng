#!/usr/bin/env python3
"""text_finder.py — Identify on-screen text entries via Mesen IPC or beta ROM diff."""

import argparse, os, re, sys, tempfile, subprocess

# ---------------------------------------------------------------------------
# Entry index: parse all en_ptr_data/*.txt into searchable records
# ---------------------------------------------------------------------------

# Reuse lm3's encoding-aware reader
sys.path.insert(0, os.path.dirname(__file__))
from lm3 import _read_script_text, SCRIPT_TABLES

# Map ptr_tbl_pos -> table name for identification
_PTR_TO_NAME = {t['ptr_tbl_pos']: t['name'] for t in SCRIPT_TABLES}


def _strip_codes(text: str) -> str:
    """Remove [control codes] and <<<window>>> markers, keep plain text."""
    text = re.sub(r'<<<window\[\d+\]:\$[0-9A-Fa-f]+-\$[0-9A-Fa-f]+>>>', '', text)
    text = re.sub(r'\[[^\]]*\]', '', text)
    # Collapse whitespace
    return re.sub(r'\s+', ' ', text).strip()


def build_entry_index(en_folder: str = 'en_ptr_data') -> list:
    """Parse all script files, return list of entry records."""
    entries = []
    for fname in sorted(os.listdir(en_folder)):
        if not fname.endswith('.txt'):
            continue
        # Skip backups / old files
        if '.old' in fname or '.bak' in fname or fname.startswith('.'):
            continue
        fpath = os.path.join(en_folder, fname)
        try:
            text = _read_script_text(fpath)
        except Exception:
            continue

        # Track line numbers: count lines up to each header position
        lines = text.split('\n')
        # Build a char-offset -> line-number map
        char_to_line = {}
        offset = 0
        for ln, line in enumerate(lines, 1):
            char_to_line[offset] = ln
            offset += len(line) + 1  # +1 for \n

        # Find all entry headers
        for m in re.finditer(r'<<\$(\d+):(\d+)(?:\[\$(\d+)\])?>>', text):
            ptr_tbl = int(m.group(1))
            idx = int(m.group(2))
            data_addr = int(m.group(3)) if m.group(3) else None
            table_name = _PTR_TO_NAME.get(ptr_tbl, f'unknown_{ptr_tbl}')

            # Content: everything after >> until next <<$ or EOF
            content_start = m.end()
            next_header = re.search(r'<<\$', text[content_start:])
            content_end = content_start + next_header.start() if next_header else len(text)
            raw_content = text[content_start:content_end].strip()
            plain = _strip_codes(raw_content)

            # Line number of this header
            header_pos = m.start()
            line_num = 1
            for coff in sorted(char_to_line.keys()):
                if coff <= header_pos:
                    line_num = char_to_line[coff]
                else:
                    break

            entries.append({
                'table': table_name,
                'index': idx,
                'ptr_tbl': ptr_tbl,
                'data_addr': data_addr,
                'file': fpath,
                'line': line_num,
                'raw': raw_content[:200],  # truncate for display
                'plain': plain,
            })
    return entries


# ---------------------------------------------------------------------------
# scan: read WRAM $0400 buffer, decode, match to entries
# ---------------------------------------------------------------------------

def scan(en_folder: str = 'en_ptr_data', resume: bool = False):
    """Read emulator text buffer and identify which script entry is displayed."""
    from mesen_ipc import connect, send_cmd, read_wram
    from retrotool.script import Table

    sock = connect()
    send_cmd(sock, 'pause')

    # Read $0400 buffer (496 bytes max)
    buf = read_wram(sock, 0x0400, 0x1F0)
    if buf is None:
        print('ERROR: failed to read WRAM $0400')
        return

    if resume:
        send_cmd(sock, 'resume')

    # Trim at first 0x00 (text terminator)
    end = len(buf)
    for i, b in enumerate(buf):
        if b == 0x00:
            end = i
            break
    buf = buf[:end]

    if not buf:
        print('Buffer empty — no text currently displayed.')
        return

    # Decode buffer using eng.tbl with jap.tbl fallback (some chars like
    # 「」 are only in jap.tbl but appear in EN text)
    tbl = Table('eng.tbl')
    fb_tbl = Table('jap.tbl')
    decoded = tbl.interpret_binary_data(list(buf))
    # Also decode with jap.tbl for display
    decoded_jp = fb_tbl.interpret_binary_data(list(buf))
    # Merge: use eng decode but replace [XX] hex codes with jap decode chars
    plain_decoded = _strip_codes(decoded)

    print(f'--- Buffer ({len(buf)} bytes) ---')
    print(decoded)
    print(f'\n--- Plain text ---')
    print(plain_decoded)
    print()

    if not plain_decoded or len(plain_decoded) < 3:
        print('Buffer text too short to match.')
        return

    # Build index and search
    index = build_entry_index(en_folder)

    # Extract searchable fragments from buffer (runs of 3+ word chars)
    fragments = re.findall(r'[A-Za-z0-9\'".,!?~ ]{3,}', plain_decoded)
    # Also try the whole plain text
    if plain_decoded and plain_decoded not in fragments:
        fragments.append(plain_decoded)

    # Score each entry by how many buffer fragments appear in it
    matches = []
    for entry in index:
        if not entry['plain']:
            continue
        score = 0
        for frag in fragments:
            if frag in entry['plain']:
                score += len(frag)
        if score > 0:
            matches.append((score, entry))

    matches.sort(key=lambda x: -x[0])

    if not matches:
        print('No matching entries found.')
        # Try partial: longest single fragment
        longest = max(fragments, key=len) if fragments else plain_decoded[:20]
        print(f'  Searched for: "{longest[:60]}..."')
        return

    print(f'--- Top matches ---')
    for i, (score, entry) in enumerate(matches[:5]):
        print(f'\n  #{i+1} [{score}] {entry["table"]}:{entry["index"]}')
        print(f'       {entry["file"]}:{entry["line"]}')
        print(f'       {entry["plain"][:100]}')


# ---------------------------------------------------------------------------
# beta: extract from beta ROM, diff against current
# ---------------------------------------------------------------------------

def _has_japanese(text: str) -> bool:
    """Check if text contains Japanese characters (hiragana, katakana, kanji via hex codes)."""
    # CJK ranges in Unicode
    for ch in text:
        cp = ord(ch)
        if (0x3040 <= cp <= 0x309F or   # hiragana
            0x30A0 <= cp <= 0x30FF or   # katakana
            0x4E00 <= cp <= 0x9FFF or   # CJK unified
            0xFF00 <= cp <= 0xFFEF):    # fullwidth
            return True
    return False


def beta(beta_rom: str = 'DEBUGGER_FRAGMENTS/lm3_en.sfc',
         en_folder: str = 'en_ptr_data'):
    """Extract EN from beta ROM, compare against current EN files."""

    if not os.path.exists(beta_rom):
        print(f'ERROR: beta ROM not found: {beta_rom}')
        return

    # Extract to temp folder
    with tempfile.TemporaryDirectory(prefix='lm3_beta_') as tmpdir:
        print(f'Extracting EN text from beta ROM: {beta_rom}')
        print(f'  temp folder: {tmpdir}')
        result = subprocess.run(
            ['python3', 'lm3.py', 'extract',
             '--source', beta_rom, '--lang', 'en',
             '--en-folder', tmpdir],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            print(f'Extraction failed:\n{result.stderr}')
            return

        print('Building entry indices...')
        beta_entries = build_entry_index(tmpdir)
        current_entries = build_entry_index(en_folder)

        # Key by (table, index)
        beta_map = {}
        for e in beta_entries:
            beta_map[(e['table'], e['index'])] = e

        current_map = {}
        for e in current_entries:
            current_map[(e['table'], e['index'])] = e

        # Find entries translated in beta but still JP in current
        regressions = []
        for key, cur in current_map.items():
            if _has_japanese(cur['plain']):
                beta_entry = beta_map.get(key)
                if beta_entry and not _has_japanese(beta_entry['plain']) and beta_entry['plain']:
                    regressions.append({
                        'table': key[0],
                        'index': key[1],
                        'current_file': cur['file'],
                        'current_line': cur['line'],
                        'current_text': cur['plain'][:80],
                        'beta_text': beta_entry['plain'][:80],
                    })

        if not regressions:
            print('\nNo regressions found — all beta translations present in current.')
            return

        print(f'\n=== {len(regressions)} entries translated in beta but JP in current ===\n')
        regressions.sort(key=lambda r: (r['table'], r['index']))
        cur_table = None
        for r in regressions:
            if r['table'] != cur_table:
                cur_table = r['table']
                print(f'\n  [{cur_table}]')
            print(f'    :{r["index"]}  {r["current_file"]}:{r["current_line"]}')
            print(f'      current: {r["current_text"]}')
            print(f'      beta:    {r["beta_text"]}')


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description='Identify on-screen text entries')
    sub = parser.add_subparsers(dest='cmd')

    p_scan = sub.add_parser('scan', help='Read emulator text buffer and identify entry')
    p_scan.add_argument('--en-folder', default='en_ptr_data')
    p_scan.add_argument('--resume', action='store_true',
                        help='Resume emulation after reading (default: stay paused)')

    p_beta = sub.add_parser('beta', help='Diff current EN vs beta ROM translations')
    p_beta.add_argument('--rom', default='DEBUGGER_FRAGMENTS/lm3_en.sfc',
                        help='Beta ROM path')
    p_beta.add_argument('--en-folder', default='en_ptr_data')

    args = parser.parse_args()
    if args.cmd == 'scan':
        scan(en_folder=args.en_folder, resume=args.resume)
    elif args.cmd == 'beta':
        beta(beta_rom=args.rom, en_folder=args.en_folder)
    else:
        parser.print_help()

if __name__ == '__main__':
    main()
