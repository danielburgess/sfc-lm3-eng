"""Shift window[N] starts past `[P][msg][special]` opener so those ctrl codes
run from source JP bytecode context instead of being re-emitted inside the
FFC0 overflow. Strips leading `[msg][special]` from EN body.

Source pattern at window start: 10 FF 7F 02 FF FD 02 (7 bytes) → new start = +7.

Usage:
  python3 tools/shift_msg_special_windows.py [--dry-run] FILE
"""
from __future__ import annotations
import re, sys, argparse
from pathlib import Path

ROM = Path('/mnt/crucial/projects/sfc-lm3-eng/lm3.sfc')
# cutscene-bytecode-2 pointer table at PC 0x50010, 120 entries, 2-byte ptrs.
# Data base at 0x50101 (SNES $0A:8101). Entry addr = bank_base + (ptr - $8000).
PTR_TBL_PC = 0x50010
BANK_BASE_PC = 0x50000     # PC base for SNES bank $0A
ENTRY_COUNT = 120

PATTERN = bytes([0x10, 0xFF, 0x7F, 0x02, 0xFF, 0xFD, 0x02])
SHIFT = len(PATTERN)  # 7

ENTRY_RE = re.compile(r'^<<\$\d+:(\d+)\[\$\d+\]>>\s*$')
WINDOW_RE = re.compile(r'^<<<window\[(\d+)\]:\$([0-9A-Fa-f]+)-\$([0-9A-Fa-f]+)>>>\s*$')


def load_entry_starts() -> list[int]:
    rom = ROM.read_bytes()
    starts = []
    for i in range(ENTRY_COUNT):
        p = int.from_bytes(rom[PTR_TBL_PC + 2*i:PTR_TBL_PC + 2*i + 2], 'little')
        # LoROM bank $0A: PC = 0x50000 + (addr - 0x8000)
        starts.append(BANK_BASE_PC + p - 0x8000)
    return starts, rom


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('file')
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()

    entry_starts, rom = load_entry_starts()

    lines = Path(args.file).read_text(encoding='utf-8').splitlines(keepends=True)
    out_lines = []
    cur_entry = None
    shifts = []  # (entry_idx, win_idx, old_start, new_start, had_prefix_in_body)

    i = 0
    while i < len(lines):
        line = lines[i]
        m_entry = ENTRY_RE.match(line)
        if m_entry:
            cur_entry = int(m_entry.group(1))
            out_lines.append(line)
            i += 1
            continue

        m_win = WINDOW_RE.match(line)
        if m_win and cur_entry is not None:
            win_idx = int(m_win.group(1))
            win_start = int(m_win.group(2), 16)
            win_end = int(m_win.group(3), 16)
            # Read source bytes at entry_start + win_start
            entry_pc = entry_starts[cur_entry]
            src_pc = entry_pc + win_start
            src_bytes = rom[src_pc:src_pc + SHIFT]

            if src_bytes == PATTERN:
                new_start = win_start + SHIFT
                # Check if end > new_start (window must remain non-empty)
                if new_start < win_end:
                    # Emit shifted header
                    new_header = f'<<<window[{win_idx}]:${new_start:04X}-${win_end:04X}>>>\n'
                    out_lines.append(new_header)
                    i += 1
                    # Look at next non-header line (EN body) — it may be empty line
                    # or the body; append all lines until next header/entry
                    body_lines = []
                    while i < len(lines):
                        nxt = lines[i]
                        if ENTRY_RE.match(nxt) or WINDOW_RE.match(nxt):
                            break
                        body_lines.append(nxt)
                        i += 1
                    # Strip leading [msg][special] from first non-empty body line
                    stripped = False
                    for bi, bl in enumerate(body_lines):
                        if bl.strip() == '':
                            continue
                        if bl.startswith('[msg][special]'):
                            body_lines[bi] = bl[len('[msg][special]'):]
                            stripped = True
                        break
                    out_lines.extend(body_lines)
                    shifts.append((cur_entry, win_idx, win_start, new_start, stripped))
                    continue
            # Fall-through: keep window as-is
            out_lines.append(line)
            i += 1
            continue

        out_lines.append(line)
        i += 1

    # Report
    print(f'Shifted {len(shifts)} windows:')
    for e, w, o, n, st in shifts:
        print(f'  entry :{e:3d} window[{w:2d}]  ${o:04X} -> ${n:04X}  body_stripped={st}')

    if not args.dry_run:
        Path(args.file).write_text(''.join(out_lines), encoding='utf-8')
        print(f'wrote {args.file}')


if __name__ == '__main__':
    main()
