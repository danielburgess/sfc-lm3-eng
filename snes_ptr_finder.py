#!/usr/bin/env python3
"""
snes_ptr_finder.py — SNES ROM pointer table finder

Heuristic tools for locating text pointer tables, meta-tables, and text
regions in SNES (Super Famicom) ROMs.  No external dependencies.

METHODOLOGY — How to find an unknown text block:
=================================================

This tool automates the process described below, which was used to discover
an unextracted 100-entry event-text table at $22:$BA9B in a LoROM game ROM.

  1. OBSERVE:  Set a read breakpoint in an emulator when untranslated text
     appears.  Note the SNES address being read (e.g. $22:$DE08).

  2. CONVERT: Translate the SNES address to a PC (file) offset.
       $ python3 snes_ptr_finder.py snes2pc 22:DE08
       → 0x115E08

  3. VERIFY:  Confirm that ROM data at that offset matches what the emulator
     showed.  Use `dump-table` with a single address or a hex editor.

  4. TRACE BACKWARDS: From the text data, search backwards for a pointer
     table.  Pointer tables are arrays of 2-byte (intra-bank) or 3-byte
     (absolute) little-endian SNES addresses.  They have a distinctive
     signature: mostly-ascending values in the $8000–$FFFF range.
       $ python3 snes_ptr_finder.py scan-ptrs rom.sfc --bank 0x22

  5. FIND REFERENCES: Once you have a pointer table address, search the
     entire ROM for 2-byte and 3-byte references to it.  This often reveals
     a higher-level "meta-table" that dispatches between multiple text
     pointer tables.
       $ python3 snes_ptr_finder.py find-refs rom.sfc 22:BA9B

  6. DUMP: Confirm the table by dumping its entries:
       $ python3 snes_ptr_finder.py dump-table rom.sfc 22:BA9B --entries 100

  7. AUTOMATE:  Or use `trace-ptr-chain` to do steps 4–5 automatically:
       $ python3 snes_ptr_finder.py trace rom.sfc 22:DE08

SNES Address Formats Accepted:
  $22:$BA9B  or  22:BA9B   — SNES bank:address
  0x113A9B   or  113A9B    — PC (file) offset
  Use --pc flag to force PC interpretation when ambiguous.
"""

import argparse
import struct
import sys
import os

# ============================================================================
# Constants
# ============================================================================

LOROM = 'lorom'
HIROM = 'hirom'

# Valid SNES address range for intra-bank pointers in LoROM
LOROM_PTR_RANGE = (0x8000, 0xFFFF)

# ============================================================================
# Address Conversion
# ============================================================================

def snes_to_pc(bank, addr, mapping=LOROM):
    """Convert SNES bank:address to PC file offset."""
    if mapping == LOROM:
        return (bank & 0x7F) * 0x8000 + (addr - 0x8000)
    else:  # HiROM
        return ((bank & 0x3F) << 16) | addr


def pc_to_snes(pc, mapping=LOROM):
    """Convert PC file offset to (bank, addr) tuple."""
    if mapping == LOROM:
        bank = (pc >> 15) & 0xFF
        addr = (pc & 0x7FFF) | 0x8000
        return bank, addr
    else:  # HiROM
        bank = 0xC0 | ((pc >> 16) & 0x3F)
        addr = pc & 0xFFFF
        return bank, addr


def fmt_snes(bank, addr):
    """Format as $BB:$AAAA."""
    return f"${bank:02X}:${addr:04X}"


def fmt_pc(pc):
    """Format as 0xNNNNNN."""
    return f"0x{pc:06X}"


def parse_addr(s):
    """
    Parse a flexible address string.  Returns (bank, addr, is_snes).

    Accepted formats:
      $22:$BA9B  or  22:BA9B   → SNES  (is_snes=True)
      0x113A9B   or  113A9B    → PC    (is_snes=False)
    """
    s = s.strip().lstrip('$').replace('$', '')
    if ':' in s:
        parts = s.split(':')
        bank = int(parts[0], 16)
        addr = int(parts[1], 16)
        return bank, addr, True
    else:
        val = int(s, 16)
        return val, 0, False


def resolve_addr(s, mapping=LOROM, force_pc=False):
    """
    Parse address string and return (pc_offset, bank, snes_addr).
    """
    raw, _, is_snes = parse_addr(s)
    if is_snes and not force_pc:
        bank, addr = raw, _
        pc = snes_to_pc(bank, addr, mapping)
        return pc, bank, addr
    else:
        pc = raw
        bank, addr = pc_to_snes(pc, mapping)
        return pc, bank, addr


# ============================================================================
# ROM Loading
# ============================================================================

def load_rom(path):
    """Load ROM, stripping copier header if present."""
    with open(path, 'rb') as f:
        data = f.read()
    if len(data) % 0x8000 == 512:
        print(f"  [info] Stripped 512-byte copier header ({len(data)} → {len(data)-512} bytes)")
        data = data[512:]
    return data


def detect_mapping(rom):
    """Auto-detect LoROM vs HiROM from ROM header."""
    # Check LoROM header at PC 0x7FD5
    if len(rom) > 0x7FE0:
        mode_lo = rom[0x7FD5]
        # Check complement + checksum at 0x7FDC-0x7FDF
        comp_lo = struct.unpack_from('<HH', rom, 0x7FDC)
        valid_lo = (comp_lo[0] ^ comp_lo[1]) == 0xFFFF

    # Check HiROM header at PC 0xFFD5
    if len(rom) > 0xFFE0:
        mode_hi = rom[0xFFD5]
        comp_hi = struct.unpack_from('<HH', rom, 0xFFDC)
        valid_hi = (comp_hi[0] ^ comp_hi[1]) == 0xFFFF

    if len(rom) > 0xFFE0 and valid_hi and (mode_hi & 0x01):
        return HIROM
    if len(rom) > 0x7FE0 and valid_lo and not (mode_lo & 0x01):
        return LOROM
    # Default fallback
    return LOROM


# ============================================================================
# Core Analysis Functions
# ============================================================================

def cmd_snes2pc(args):
    """Convert SNES address to PC offset."""
    mapping = args.mapping or LOROM
    bank, addr, is_snes = parse_addr(args.address)
    if not is_snes:
        print(f"Error: '{args.address}' doesn't look like a SNES address (use BB:AAAA format)")
        sys.exit(1)
    pc = snes_to_pc(bank, addr, mapping)
    print(f"  SNES {fmt_snes(bank, addr)} → PC {fmt_pc(pc)}")


def cmd_pc2snes(args):
    """Convert PC offset to SNES address."""
    mapping = args.mapping or LOROM
    raw, _, is_snes = parse_addr(args.address)
    if is_snes:
        print(f"Error: '{args.address}' looks like a SNES address; use a plain hex value for PC")
        sys.exit(1)
    bank, addr = pc_to_snes(raw, mapping)
    print(f"  PC {fmt_pc(raw)} → SNES {fmt_snes(bank, addr)}")


def scan_ptrs(rom, mapping, bank_filter=None, min_entries=8, ptr_size=2,
              verify_text=False, max_results=20):
    """
    Scan ROM for candidate pointer tables.

    A pointer table is a contiguous array of ptr_size-byte little-endian values
    where most values are valid SNES addresses.  Scoring heuristics:

    1. Geometry: first pointer's target should fall right after the table ends
       (pointer tables are immediately followed by their data).
    2. Non-decreasing: pointers are >= the previous entry (duplicates OK).
       Tables with many duplicates are still valid (placeholder entries).
    3. Spread: distinct pointer values should span a meaningful address range.
    4. Uniqueness ratio: heavily repeated byte patterns (e.g. $AAAA) are
       more likely random data than real pointer tables.

    Returns list of dicts sorted by score descending.
    """
    candidates = []
    rom_len = len(rom)

    if bank_filter is not None:
        banks = bank_filter if isinstance(bank_filter, list) else [bank_filter]
    else:
        max_bank = (rom_len + 0x7FFF) // 0x8000
        banks = list(range(max_bank))

    for bank in banks:
        bank_pc_start = bank * 0x8000
        bank_pc_end = min(bank_pc_start + 0x8000, rom_len)
        if bank_pc_end - bank_pc_start < min_entries * ptr_size:
            continue

        # Scan at EVERY byte offset, not just aligned ones.
        # Pointer tables can start at odd addresses (e.g. $BA9B).
        i = bank_pc_start
        while i < bank_pc_end - min_entries * ptr_size:
            ptrs = []
            j = i

            while j + ptr_size <= bank_pc_end:
                if ptr_size == 2:
                    val = struct.unpack_from('<H', rom, j)[0]
                    if not (LOROM_PTR_RANGE[0] <= val <= LOROM_PTR_RANGE[1]):
                        break
                    ptrs.append(val)
                elif ptr_size == 3:
                    val = rom[j] | (rom[j+1] << 8) | (rom[j+2] << 16)
                    ptr_bank = (val >> 16) & 0xFF
                    ptr_addr = val & 0xFFFF
                    pc_target = snes_to_pc(ptr_bank, ptr_addr, mapping)
                    if pc_target < 0 or pc_target >= rom_len:
                        break
                    ptrs.append(val)
                j += ptr_size

            num_ptrs = len(ptrs)
            if num_ptrs < min_entries:
                i += 1  # advance by 1, not ptr_size — tables can start at any offset
                continue

            # --- Scoring ---

            # 1. Non-decreasing pairs (duplicates count as ascending)
            ascending_count = sum(1 for k in range(1, num_ptrs) if ptrs[k] >= ptrs[k-1])
            monotonicity = ascending_count / max(num_ptrs - 1, 1)

            # 2. Geometry: first pointer should be right after the table
            first_ptr = ptrs[0]
            if ptr_size == 2:
                _, tbl_snes_addr = pc_to_snes(i, mapping)
                tbl_end_snes = tbl_snes_addr + num_ptrs * ptr_size
                # Tight geometry: first data immediately follows table
                geometry_tight = (first_ptr == tbl_end_snes)
                # Loose geometry: first data is at least after the table
                geometry_ok = (first_ptr >= tbl_end_snes)
            else:
                geometry_tight = False
                geometry_ok = True

            # 3. Distinct pointer count and spread
            unique_ptrs = set(ptrs)
            uniqueness = len(unique_ptrs) / num_ptrs
            if ptr_size == 2:
                spread = (max(unique_ptrs) - min(unique_ptrs))
            else:
                spread = (max(unique_ptrs) - min(unique_ptrs)) & 0xFFFF

            # 4. Byte-pattern uniqueness: reject if bytes are too repetitive
            # (e.g. $AAAA $AAAA = every byte is 0xAA)
            raw = rom[i:i + num_ptrs * ptr_size]
            byte_set = set(raw)
            byte_variety = len(byte_set)

            # 5. Verify text at targets (optional)
            text_score = 0
            if verify_text and ptr_size == 2:
                tbl_bank, _ = pc_to_snes(i, mapping)
                sample_indices = list(set([0, num_ptrs//4, num_ptrs//2, 3*num_ptrs//4, num_ptrs-1]))
                sample_count = len(sample_indices)
                for s in sample_indices:
                    if s < num_ptrs:
                        target_pc = snes_to_pc(tbl_bank, ptrs[s] & 0xFFFF, mapping)
                        if 0 <= target_pc < rom_len - 4:
                            chunk = rom[target_pc:target_pc+256]
                            if 0x00 in chunk:
                                text_score += 1
                text_score /= max(sample_count, 1)

            # --- Composite score ---
            score = num_ptrs * monotonicity

            # Strong geometry bonus (tight = first ptr immediately follows table)
            if geometry_tight:
                score *= 3.0
            elif geometry_ok:
                score *= 1.5

            # Penalize very low byte variety (repetitive data like $AA $AA $BB $BB)
            if byte_variety < 6:
                score *= 0.1
            elif byte_variety < 12:
                score *= 0.5

            # Bonus for good spread (pointers spanning meaningful address range)
            if spread > 0x1000:
                score *= 1.3
            elif spread > 0x400:
                score *= 1.1

            if verify_text:
                score *= (0.5 + text_score)

            tbl_bank_byte, tbl_snes = pc_to_snes(i, mapping)
            candidates.append({
                'score': score,
                'pc': i,
                'bank': tbl_bank_byte,
                'snes_addr': tbl_snes,
                'num_entries': num_ptrs,
                'monotonicity': monotonicity,
                'geometry_ok': geometry_ok,
                'geometry_tight': geometry_tight,
                'text_score': text_score if verify_text else None,
                'first_ptr': ptrs[0],
                'last_ptr': ptrs[-1],
                'unique_ptrs': len(unique_ptrs),
                'byte_variety': byte_variety,
            })

            i += num_ptrs * ptr_size
            continue

    candidates.sort(key=lambda c: c['score'], reverse=True)

    # Remove overlapping candidates (keep highest-scoring)
    filtered = []
    used_ranges = set()
    for c in candidates:
        overlap = False
        for used_pc in used_ranges:
            if abs(c['pc'] - used_pc) < min_entries * ptr_size:
                overlap = True
                break
        if not overlap:
            filtered.append(c)
            used_ranges.add(c['pc'])

    return filtered[:max_results]


def cmd_scan_ptrs(args):
    """Find candidate pointer tables in ROM."""
    rom = load_rom(args.rom)
    mapping = args.mapping or detect_mapping(rom)
    print(f"  [info] Mapping: {mapping}, ROM size: {len(rom)} bytes ({len(rom)//1024} KB)")

    bank_filter = None
    if args.bank is not None:
        bank_filter = [args.bank]
    elif args.bank_range:
        lo, hi = args.bank_range.split('-')
        bank_filter = list(range(int(lo, 16), int(hi, 16) + 1))

    candidates = scan_ptrs(
        rom, mapping,
        bank_filter=bank_filter,
        min_entries=args.min_entries,
        ptr_size=args.ptr_size,
        verify_text=args.verify_text,
        max_results=args.max_results,
    )

    if not candidates:
        print("  No pointer table candidates found.")
        return

    print(f"\n  Found {len(candidates)} candidate pointer table(s):\n")
    print(f"  {'Score':>7}  {'PC':>10}  {'SNES':>10}  {'#Ent':>5}  {'Mono%':>5}  {'Geom':>5}  {'Uniq':>4}  {'Range'}")
    print(f"  {'-----':>7}  {'--':>10}  {'----':>10}  {'----':>5}  {'-----':>5}  {'----':>5}  {'----':>4}  {'-----'}")

    for c in candidates:
        geom = 'TIGHT' if c.get('geometry_tight') else ('OK' if c['geometry_ok'] else '--')
        ptr_range = f"${c['first_ptr']:04X}–${c['last_ptr']:04X}" if args.ptr_size == 2 else f"${c['first_ptr']:06X}–${c['last_ptr']:06X}"
        txt = ''
        if c['text_score'] is not None:
            txt = f"  txt={c['text_score']:.0%}"
        print(f"  {c['score']:7.1f}  {fmt_pc(c['pc']):>10}  {fmt_snes(c['bank'], c['snes_addr']):>10}  "
              f"{c['num_entries']:>5}  {c['monotonicity']:>5.0%}  {geom:>5}  {c.get('unique_ptrs', '?'):>4}  {ptr_range}{txt}")


def find_refs(rom, target_bank, target_addr, mapping=LOROM, search_2byte=True,
              search_3byte=True, context_bytes=8, exclude_range=None):
    """
    Search entire ROM for 2-byte and/or 3-byte LE references to a SNES address.

    Returns list of {pc, bank, snes_addr, ref_size, context_before, context_after}.
    """
    results = []
    lo = target_addr & 0xFF
    hi = (target_addr >> 8) & 0xFF
    bk = target_bank & 0xFF

    pat2 = bytes([lo, hi])
    pat3 = bytes([lo, hi, bk])

    if search_3byte:
        pos = 0
        while True:
            pos = rom.find(pat3, pos)
            if pos == -1:
                break
            if exclude_range and exclude_range[0] <= pos < exclude_range[1]:
                pos += 1
                continue
            ref_bank, ref_addr = pc_to_snes(pos, mapping)
            ctx_before = rom[max(0, pos - context_bytes):pos]
            ctx_after = rom[pos + 3:pos + 3 + context_bytes]
            results.append({
                'pc': pos,
                'bank': ref_bank,
                'snes_addr': ref_addr,
                'ref_size': 3,
                'context_before': ctx_before,
                'match_bytes': pat3,
                'context_after': ctx_after,
            })
            pos += 1

    if search_2byte:
        pos = 0
        while True:
            pos = rom.find(pat2, pos)
            if pos == -1:
                break
            if exclude_range and exclude_range[0] <= pos < exclude_range[1]:
                pos += 1
                continue
            # Skip if this is part of a 3-byte match already found
            already_3byte = any(r['pc'] == pos and r['ref_size'] == 3 for r in results)
            if already_3byte:
                pos += 1
                continue
            ref_bank, ref_addr = pc_to_snes(pos, mapping)
            ctx_before = rom[max(0, pos - context_bytes):pos]
            ctx_after = rom[pos + 2:pos + 2 + context_bytes]
            results.append({
                'pc': pos,
                'bank': ref_bank,
                'snes_addr': ref_addr,
                'ref_size': 2,
                'context_before': ctx_before,
                'match_bytes': pat2,
                'context_after': ctx_after,
            })
            pos += 1

    # Sort by PC offset
    results.sort(key=lambda r: r['pc'])
    return results


def cmd_find_refs(args):
    """Search ROM for references to a SNES address."""
    rom = load_rom(args.rom)
    mapping = args.mapping or detect_mapping(rom)
    pc, bank, addr = resolve_addr(args.address, mapping, args.pc)

    search_2 = args.size in ('2', 'both')
    search_3 = args.size in ('3', 'both')

    print(f"  Searching for references to {fmt_snes(bank, addr)} (PC {fmt_pc(pc)})...")
    refs = find_refs(rom, bank, addr, mapping,
                     search_2byte=search_2, search_3byte=search_3,
                     context_bytes=args.context)

    if not refs:
        print("  No references found.")
        return

    # Group by ref_size
    refs_3 = [r for r in refs if r['ref_size'] == 3]
    refs_2 = [r for r in refs if r['ref_size'] == 2]

    if refs_3:
        print(f"\n  3-byte references ({len(refs_3)}):")
        for r in refs_3:
            ctx = r['context_before'].hex(' ') + ' [' + r['match_bytes'].hex(' ') + '] ' + r['context_after'].hex(' ')
            print(f"    {fmt_pc(r['pc'])}  {fmt_snes(r['bank'], r['snes_addr'])}  {ctx}")

    if refs_2:
        print(f"\n  2-byte references ({len(refs_2)}):")
        for r in refs_2[:50]:  # limit to avoid flooding
            ctx = r['context_before'].hex(' ') + ' [' + r['match_bytes'].hex(' ') + '] ' + r['context_after'].hex(' ')
            print(f"    {fmt_pc(r['pc'])}  {fmt_snes(r['bank'], r['snes_addr'])}  {ctx}")
        if len(refs_2) > 50:
            print(f"    ... and {len(refs_2) - 50} more (use --size 3 to filter)")

    print(f"\n  Total: {len(refs)} references ({len(refs_3)} × 3-byte, {len(refs_2)} × 2-byte)")


def cmd_dump_table(args):
    """Dump a pointer table's entries with data previews."""
    rom = load_rom(args.rom)
    mapping = args.mapping or detect_mapping(rom)
    pc, bank, addr = resolve_addr(args.address, mapping, args.pc)

    ptr_size = args.ptr_size
    tbl_bank = args.bank if args.bank is not None else bank

    # Auto-detect entry count if not specified
    if args.entries:
        num_entries = args.entries
    else:
        # Scan until pointers stop being valid
        num_entries = 0
        while True:
            off = pc + num_entries * ptr_size
            if off + ptr_size > len(rom):
                break
            if ptr_size == 2:
                val = struct.unpack_from('<H', rom, off)[0]
                if not (LOROM_PTR_RANGE[0] <= val <= LOROM_PTR_RANGE[1]):
                    break
            elif ptr_size == 3:
                val = rom[off] | (rom[off+1] << 8) | (rom[off+2] << 16)
                target_pc = snes_to_pc((val >> 16) & 0xFF, val & 0xFFFF, mapping)
                if target_pc < 0 or target_pc >= len(rom):
                    break
            num_entries += 1
            if num_entries > 10000:  # safety limit
                break

    print(f"  Pointer table at {fmt_snes(bank, addr)} (PC {fmt_pc(pc)})")
    print(f"  {num_entries} entries, {ptr_size}-byte pointers, data bank ${tbl_bank:02X}")
    print()

    preview_len = args.preview

    for i in range(num_entries):
        off = pc + i * ptr_size
        if ptr_size == 2:
            ptr_val = struct.unpack_from('<H', rom, off)[0]
            target_pc = snes_to_pc(tbl_bank, ptr_val, mapping)
            ptr_str = f"${ptr_val:04X}"
        elif ptr_size == 3:
            ptr_val = rom[off] | (rom[off+1] << 8) | (rom[off+2] << 16)
            ptr_bank = (ptr_val >> 16) & 0xFF
            ptr_addr = ptr_val & 0xFFFF
            target_pc = snes_to_pc(ptr_bank, ptr_addr, mapping)
            ptr_str = f"${ptr_bank:02X}:${ptr_addr:04X}"

        if 0 <= target_pc < len(rom):
            data = rom[target_pc:target_pc + preview_len]
            hex_str = data.hex(' ')
            # Simple ASCII preview (replace non-printable)
            ascii_str = ''.join(chr(b) if 0x20 <= b < 0x7F else '.' for b in data)
        else:
            hex_str = "(out of range)"
            ascii_str = ""

        print(f"  [{i:4d}] {ptr_str} → PC {fmt_pc(target_pc)}  {hex_str}  |{ascii_str}|")


def cmd_find_text(args):
    """Scan ROM for text-like regions."""
    rom = load_rom(args.rom)
    mapping = args.mapping or detect_mapping(rom)

    if args.range:
        lo, hi = args.range.split('-')
        scan_start = int(lo, 16)
        scan_end = int(hi, 16)
    else:
        scan_start = 0
        scan_end = len(rom)

    min_len = args.min_length
    null_term = args.null_term
    ctrl_prefix = args.control_prefix
    window = 256

    regions = []
    i = scan_start

    while i < scan_end - window:
        chunk = rom[i:i + window]

        # Score: count null terminators (text entry boundaries)
        null_count = chunk.count(null_term)

        # Count control codes (FF XX patterns)
        ctrl_count = sum(1 for j in range(len(chunk)-1) if chunk[j] == ctrl_prefix)

        # Count bytes in "text-like" ranges
        # For Japanese games: $01-$FE excluding control prefixes is common
        # For ASCII: $20-$7E
        text_bytes = sum(1 for b in chunk if 0x01 <= b <= 0xFE and b != ctrl_prefix)

        # Heuristic: good text regions have multiple nulls (entry boundaries),
        # some control codes, and mostly non-zero bytes
        text_density = text_bytes / window
        null_density = null_count / window

        # Text regions typically: >60% text bytes, 1-15% null terminators
        is_text = (text_density > 0.60 and 0.005 < null_density < 0.15)

        if is_text:
            # Extend the region forward
            region_start = i
            i += window
            while i < scan_end - window:
                chunk2 = rom[i:i + window]
                td2 = sum(1 for b in chunk2 if 0x01 <= b <= 0xFE and b != ctrl_prefix) / window
                nd2 = chunk2.count(null_term) / window
                if td2 > 0.50 and 0.003 < nd2 < 0.20:
                    i += window
                else:
                    break
            region_end = i

            if region_end - region_start >= min_len:
                bank_s, addr_s = pc_to_snes(region_start, mapping)
                bank_e, addr_e = pc_to_snes(min(region_end, scan_end - 1), mapping)
                # Count actual null terminators in the full region
                full_nulls = rom[region_start:region_end].count(null_term)
                regions.append({
                    'pc_start': region_start,
                    'pc_end': region_end,
                    'bank_start': bank_s,
                    'addr_start': addr_s,
                    'bank_end': bank_e,
                    'addr_end': addr_e,
                    'size': region_end - region_start,
                    'null_count': full_nulls,
                })
        else:
            i += window // 2  # half-step for overlapping scan

    if not regions:
        print("  No text-like regions found.")
        return

    print(f"  Found {len(regions)} text-like region(s):\n")
    print(f"  {'PC Range':>25}  {'SNES Range':>23}  {'Size':>7}  {'Nulls':>5}")
    print(f"  {'--------':>25}  {'----------':>23}  {'----':>7}  {'-----':>5}")
    for r in regions:
        pc_range = f"{fmt_pc(r['pc_start'])}–{fmt_pc(r['pc_end'])}"
        snes_range = f"{fmt_snes(r['bank_start'], r['addr_start'])}–{fmt_snes(r['bank_end'], r['addr_end'])}"
        print(f"  {pc_range:>25}  {snes_range:>23}  {r['size']:>7}  {r['null_count']:>5}")


def cmd_trace(args):
    """
    Trace backwards from a known text address to find the pointer table
    and meta-table that reference it.

    This automates the full discovery process:
      text address → pointer table → meta-table
    """
    rom = load_rom(args.rom)
    mapping = args.mapping or detect_mapping(rom)
    target_pc, target_bank, target_addr = resolve_addr(args.address, mapping, args.pc)

    if target_pc < 0 or target_pc >= len(rom):
        print(f"  Error: PC {fmt_pc(target_pc)} is outside ROM range")
        sys.exit(1)

    print(f"  Target: {fmt_snes(target_bank, target_addr)} (PC {fmt_pc(target_pc)})")

    # Step 1: Verify text data exists at target
    sample = rom[target_pc:target_pc + 64]
    null_pos = sample.find(0x00)
    if null_pos == -1:
        print(f"  [warn] No null terminator within 64 bytes of target — may not be text data")
    else:
        print(f"  [ok] Null terminator found at +{null_pos} bytes (likely text entry boundary)")

    # Step 2: Find the start of the text data block
    # Walk backwards from target looking for a region that ISN'T text
    print(f"\n  Step 1: Scanning for text region boundaries...")
    search_back = min(args.radius, target_pc)
    region_start = target_pc

    # Walk backwards byte by byte, looking for the start of the text block
    # Text blocks are preceded by pointer tables or other structural data
    for back in range(target_pc - 1, target_pc - search_back, -1):
        if back < 0:
            break
        # If we find a long run of non-text bytes, we've left the text region
        if rom[back] == 0x00:
            # Check if this null is a terminator (part of text) or structural
            # Look at what follows - if there's another null or non-text, it's structural
            continue
        region_start = back

    # Step 3: Search for pointer table
    print(f"  Step 2: Searching for pointer table referencing ${target_addr:04X}...")

    # The 2-byte LE representation of the target SNES address
    target_le = struct.pack('<H', target_addr)

    # Search backwards from text region for the pointer value
    ptr_table_candidates = []

    # Scan the region before the text data for pointer tables
    bank_pc_start = snes_to_pc(target_bank, 0x8000, mapping)
    scan_start = bank_pc_start
    scan_end = target_pc

    # Use scan_ptrs to find pointer tables in this bank
    ptr_candidates = scan_ptrs(rom, mapping, bank_filter=[target_bank],
                               min_entries=4, ptr_size=2, verify_text=False,
                               max_results=10)

    if ptr_candidates:
        print(f"\n  Found {len(ptr_candidates)} pointer table candidate(s) in bank ${target_bank:02X}:\n")
        for c in ptr_candidates:
            # Check if any pointer in this table points to our target
            tbl_pc = c['pc']
            n = c['num_entries']
            contains_target = False
            target_entry = -1
            for k in range(n):
                val = struct.unpack_from('<H', rom, tbl_pc + k * 2)[0]
                if val == target_addr:
                    contains_target = True
                    target_entry = k
                    break
                # Also check if target falls within an entry's data range
                if k + 1 < n:
                    next_val = struct.unpack_from('<H', rom, tbl_pc + (k+1) * 2)[0]
                    if val <= target_addr < next_val:
                        target_entry = k
                        break
                elif val <= target_addr:
                    target_entry = k

            marker = " ◄ CONTAINS TARGET" if contains_target else ""
            if target_entry >= 0 and not contains_target:
                marker = f" ◄ target in entry [{target_entry}] data range"

            print(f"    {fmt_snes(c['bank'], c['snes_addr'])} (PC {fmt_pc(c['pc'])})  "
                  f"{c['num_entries']} entries  mono={c['monotonicity']:.0%}  "
                  f"ptrs: ${c['first_ptr']:04X}–${c['last_ptr']:04X}{marker}")

            # If this table contains the target, search for references to it
            if (contains_target or target_entry >= 0) and not args.no_meta:
                print(f"\n  Step 3: Searching for meta-table references to {fmt_snes(c['bank'], c['snes_addr'])}...")
                refs = find_refs(rom, c['bank'], c['snes_addr'], mapping,
                                 search_2byte=False, search_3byte=True,
                                 context_bytes=12)
                if refs:
                    print(f"    Found {len(refs)} 3-byte reference(s):")
                    for r in refs:
                        ctx = r['context_before'].hex(' ') + ' [' + r['match_bytes'].hex(' ') + '] ' + r['context_after'].hex(' ')
                        print(f"      {fmt_pc(r['pc'])}  {fmt_snes(r['bank'], r['snes_addr'])}  {ctx}")

                        # Check if this looks like a meta-table entry (4-byte: addr_lo, addr_hi, bank, fmt)
                        if r['pc'] + 4 <= len(rom):
                            entry = rom[r['pc']:r['pc'] + 4]
                            mt_addr = entry[0] | (entry[1] << 8)
                            mt_bank = entry[2]
                            mt_fmt = entry[3]
                            if mt_addr == c['snes_addr'] and mt_bank == c['bank']:
                                print(f"      → Looks like meta-table entry: "
                                      f"addr=${mt_addr:04X} bank=${mt_bank:02X} fmt={mt_fmt}")
                                # Check neighboring entries
                                print(f"      Neighboring 4-byte entries:")
                                for delta in [-3, -2, -1, 0, 1, 2, 3]:
                                    entry_pc = r['pc'] + delta * 4
                                    if 0 <= entry_pc < len(rom) - 4:
                                        e = rom[entry_pc:entry_pc + 4]
                                        e_addr = e[0] | (e[1] << 8)
                                        e_bank = e[2]
                                        e_fmt = e[3]
                                        tag = " ◄" if delta == 0 else ""
                                        print(f"        [{delta:+d}] ${e_bank:02X}:${e_addr:04X} fmt={e_fmt}{tag}")
                else:
                    print(f"    No 3-byte references found in ROM.")
    else:
        print(f"  No pointer table candidates found in bank ${target_bank:02X}")

        # Fallback: just search for 2-byte LE of target address in the same bank
        print(f"\n  Fallback: searching for raw 2-byte reference to ${target_addr:04X} in bank ${target_bank:02X}...")
        bank_start = snes_to_pc(target_bank, 0x8000, mapping)
        bank_end = bank_start + 0x8000
        pos = bank_start
        while pos < bank_end:
            pos = rom.find(target_le, pos, bank_end)
            if pos == -1:
                break
            ref_bank, ref_addr = pc_to_snes(pos, mapping)
            print(f"    {fmt_pc(pos)}  {fmt_snes(ref_bank, ref_addr)}  context: {rom[pos-4:pos+6].hex(' ')}")
            pos += 1


# ============================================================================
# Argument Parsing
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        prog='snes_ptr_finder',
        description='SNES ROM pointer table finder — heuristic tools for ROM hackers',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s snes2pc 22:BA9B                        Convert SNES → PC
  %(prog)s pc2snes 0x113A9B                        Convert PC → SNES
  %(prog)s scan-ptrs rom.sfc --bank 0x22           Find pointer tables in bank $22
  %(prog)s find-refs rom.sfc 22:BA9B               Find what references this address
  %(prog)s dump-table rom.sfc 22:BA9B -n 100       Dump 100 pointer entries
  %(prog)s find-text rom.sfc --range 110000-118000  Scan for text regions
  %(prog)s trace rom.sfc 22:DE08                   Full automated discovery
""")

    sub = parser.add_subparsers(dest='command')

    # -- snes2pc --
    p = sub.add_parser('snes2pc', help='Convert SNES address to PC offset')
    p.add_argument('address', help='SNES address (e.g. 22:BA9B or $22:$BA9B)')
    p.add_argument('--mapping', choices=[LOROM, HIROM], default=None)
    p.set_defaults(func=cmd_snes2pc)

    # -- pc2snes --
    p = sub.add_parser('pc2snes', help='Convert PC offset to SNES address')
    p.add_argument('address', help='PC offset (e.g. 0x113A9B)')
    p.add_argument('--mapping', choices=[LOROM, HIROM], default=None)
    p.set_defaults(func=cmd_pc2snes)

    # -- scan-ptrs --
    p = sub.add_parser('scan-ptrs', help='Scan ROM for pointer table candidates')
    p.add_argument('rom', help='Path to SNES ROM file')
    p.add_argument('--mapping', choices=[LOROM, HIROM], default=None)
    p.add_argument('--bank', type=lambda x: int(x, 16), default=None,
                   help='Restrict scan to one bank (hex, e.g. 0x22)')
    p.add_argument('--bank-range', default=None,
                   help='Bank range (hex, e.g. 00-3F)')
    p.add_argument('--min-entries', type=int, default=8,
                   help='Minimum pointer count to report (default: 8)')
    p.add_argument('--ptr-size', type=int, choices=[2, 3], default=2,
                   help='Pointer width in bytes (default: 2)')
    p.add_argument('--verify-text', action='store_true',
                   help='Check if pointed-to data looks like text')
    p.add_argument('--max-results', type=int, default=20,
                   help='Maximum candidates to report (default: 20)')
    p.set_defaults(func=cmd_scan_ptrs)

    # -- find-refs --
    p = sub.add_parser('find-refs', help='Search ROM for references to an address')
    p.add_argument('rom', help='Path to SNES ROM file')
    p.add_argument('address', help='Target address to search for')
    p.add_argument('--mapping', choices=[LOROM, HIROM], default=None)
    p.add_argument('--pc', action='store_true', help='Interpret address as PC offset')
    p.add_argument('--size', choices=['2', '3', 'both'], default='both',
                   help='Reference size to search for (default: both)')
    p.add_argument('--context', type=int, default=8,
                   help='Bytes of hex context around each match (default: 8)')
    p.set_defaults(func=cmd_find_refs)

    # -- dump-table --
    p = sub.add_parser('dump-table', help='Dump pointer table entries with data previews')
    p.add_argument('rom', help='Path to SNES ROM file')
    p.add_argument('address', help='Pointer table start address')
    p.add_argument('--mapping', choices=[LOROM, HIROM], default=None)
    p.add_argument('--pc', action='store_true', help='Interpret address as PC offset')
    p.add_argument('-n', '--entries', type=int, default=None,
                   help='Number of entries (auto-detect if omitted)')
    p.add_argument('--ptr-size', type=int, choices=[2, 3], default=2,
                   help='Pointer width in bytes (default: 2)')
    p.add_argument('--bank', type=lambda x: int(x, 16), default=None,
                   help='Data bank byte for 2-byte pointers (default: same as table)')
    p.add_argument('--preview', type=int, default=24,
                   help='Bytes of data preview per entry (default: 24)')
    p.set_defaults(func=cmd_dump_table)

    # -- find-text --
    p = sub.add_parser('find-text', help='Scan ROM for text-like data regions')
    p.add_argument('rom', help='Path to SNES ROM file')
    p.add_argument('--mapping', choices=[LOROM, HIROM], default=None)
    p.add_argument('--range', default=None,
                   help='PC byte range to scan (hex, e.g. 110000-118000)')
    p.add_argument('--min-length', type=int, default=64,
                   help='Minimum region size in bytes (default: 64)')
    p.add_argument('--null-term', type=lambda x: int(x, 16), default=0x00,
                   help='Terminator byte (default: 0x00)')
    p.add_argument('--control-prefix', type=lambda x: int(x, 16), default=0xFF,
                   help='Control code prefix byte (default: 0xFF)')
    p.set_defaults(func=cmd_find_text)

    # -- trace --
    p = sub.add_parser('trace', help='Trace from text address → pointer table → meta-table')
    p.add_argument('rom', help='Path to SNES ROM file')
    p.add_argument('address', help='Known text data SNES address')
    p.add_argument('--mapping', choices=[LOROM, HIROM], default=None)
    p.add_argument('--pc', action='store_true', help='Interpret address as PC offset')
    p.add_argument('--radius', type=int, default=0x4000,
                   help='Max search distance backwards (default: 0x4000)')
    p.add_argument('--no-meta', action='store_true',
                   help='Skip meta-table reference search')
    p.set_defaults(func=cmd_trace)

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)
    args.func(args)


if __name__ == '__main__':
    main()
