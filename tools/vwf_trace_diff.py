#!/usr/bin/env python3
"""
VWF trace-diff harness — answers Diana's question:
    Who writes the tile bytes LAST before VBlank, frame N vs frame N+1?

Streams a Mesen split-trace log, models the SNES VRAM write side-channels
(direct VMDATA writes + DMA channel transfers), tracks the JSL/JSR call
stack so DMA writes carry the calling routine (not just the dispatcher),
and emits a per-tile last-writer report focused on a target byte range.

Two side-channels modelled:

  1. Direct CPU writes to $2118/$2119 (VMDATAL/H). VMADDR advances per
     $2115 (VMAIN) low bits + bit 7.

  2. DMA channel transfers triggered by $420B. For each enabled channel,
     reconstruct (source bank, source addr, size, mode, B-bus dest). If
     B-bus dest is $2118 or $2119, transfer hits VRAM at current VMADDR.

Per-cell write log gets bucketed by frame so we can answer "last writer
in frame N for byte X" deterministically.

Usage:
    vwf_trace_diff.py <trace_dir> [--bytes RANGE] [--tile RANGE]
                      [--frame N|N..M] [--csv PATH] [--summary]
    vwf_trace_diff.py --compare <dir_a> <dir_b> [--bytes RANGE] [--tile RANGE]

Examples:
    # Header Button 2 trailing region, last writer per tile per frame:
    vwf_trace_diff.py .../lm3_vwf_20260430_212610 --bytes D160..D17F

    # Compare current vs original ROM for the same tile range:
    vwf_trace_diff.py --compare .../lm3_vwf_... .../lm3_... --bytes D160..D17F
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterator, Optional


# ────────────────────────────────────────────────────────────────────────
# Trace parsing
# ────────────────────────────────────────────────────────────────────────

# Example trace line:
# "00BC75               JSL $E08F00       A:0001 X:0000 Y:6C00 S:0FE4
#  D:0000 DB:00 P:NvmxdIzC V:258 H:149 Fr:342 Cycle:15346781 BC:22 00 8F E0"
TRACE_LINE_RE = re.compile(
    r"^(?P<pc>[0-9A-Fa-f]{6})\s+"
    r"(?P<insn>.+?)\s+"
    r"A:(?P<a>[0-9A-Fa-f]{4})\s+"
    r"X:(?P<x>[0-9A-Fa-f]{4})\s+"
    r"Y:(?P<y>[0-9A-Fa-f]{4})\s+"
    r"S:(?P<s>[0-9A-Fa-f]{4})\s+"
    r"D:(?P<d>[0-9A-Fa-f]{4})\s+"
    r"DB:(?P<db>[0-9A-Fa-f]{2})\s+"
    r"P:(?P<p>[A-Za-z]{8})\s+"
    r"V:(?P<v>\d+)\s+H:(?P<h>\d+)\s+Fr:(?P<fr>\d+)\s+Cycle:(?P<cy>\d+)"
)

INSN_STORE_RE = re.compile(r"^ST([AXYZ])\s+\$(?P<addr>[0-9A-Fa-f]+)")
INSN_JSL_RE   = re.compile(r"^JSL\s+\$(?P<tgt>[0-9A-Fa-f]{6})")
INSN_JSR_RE   = re.compile(r"^JSR\s+\$(?P<tgt>[0-9A-Fa-f]{4})")
INSN_RTS_RE   = re.compile(r"^RT[SL](?:\s|$)")


def parse_trace(path: Path) -> Iterator[dict]:
    """Yield parsed trace events as dicts. Skips non-CPU lines (e.g. SPC)."""
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            # Mesen trace prefixes some lines with "lineno:" if exported with
            # line numbers; strip that. Also skip SPC-ish lines that don't
            # match the SNES CPU register layout.
            if ":" in line[:8] and "Cycle:" not in line[:50]:
                colon_idx = line.find(":")
                if line[:colon_idx].strip().isdigit():
                    line = line[colon_idx + 1:]
            m = TRACE_LINE_RE.match(line.strip())
            if not m:
                continue
            yield m.groupdict()


# ────────────────────────────────────────────────────────────────────────
# PPU / DMA state model
# ────────────────────────────────────────────────────────────────────────

@dataclass
class DmaChannel:
    dmap: int = 0          # $43x0 — DMAP (mode + direction)
    bbad: int = 0          # $43x1 — B-bus address (e.g. $18 = $2118)
    a1t: int = 0           # $43x2/3 — A-bus addr low/high
    a1b: int = 0           # $43x4 — A-bus bank
    das: int = 0           # $43x5/6 — transfer size


@dataclass
class PpuState:
    vmaddr: int = 0
    vmain: int = 0
    dmas: list[DmaChannel] = field(default_factory=lambda: [DmaChannel() for _ in range(8)])

    def vmaddr_inc(self) -> int:
        amount_bits = self.vmain & 0x03
        if amount_bits == 0:
            return 1
        elif amount_bits == 1:
            return 32
        else:
            return 128


# ────────────────────────────────────────────────────────────────────────
# DMA simulation
# ────────────────────────────────────────────────────────────────────────

# DMAP bits 0-2: pattern of B-bus offsets written per "step"
DMA_PATTERNS: dict[int, list[int]] = {
    0: [0],
    1: [0, 1],
    2: [0, 0],
    3: [0, 0, 1, 1],
    4: [0, 1, 2, 3],
    5: [0, 1, 0, 1],
    6: [0, 0],
    7: [0, 0, 1, 1],
}


def simulate_dma_writes(ch: DmaChannel, ppu: PpuState) -> Iterator[tuple[int, int]]:
    """Yield (vram_byte_addr, source_byte_addr) for each VRAM byte the DMA writes."""
    bbad = ch.bbad
    if bbad not in (0x18, 0x19):
        return

    pattern = DMA_PATTERNS.get(ch.dmap & 0x07, [0])
    size = ch.das if ch.das != 0 else 0x10000
    a1 = (ch.a1b << 16) | ch.a1t
    fixed_addr = (ch.dmap & 0x08) != 0
    decrement = (ch.dmap & 0x10) != 0

    vmaddr = ppu.vmaddr
    vmain_inc = ppu.vmaddr_inc()

    pat_idx = 0
    transferred = 0
    while transferred < size:
        b_offset = pattern[pat_idx % len(pattern)]
        b_dest = bbad + b_offset
        if b_dest == 0x18:
            vram_byte = (vmaddr & 0xFFFF) * 2
        elif b_dest == 0x19:
            vram_byte = (vmaddr & 0xFFFF) * 2 + 1
        else:
            transferred += 1
            pat_idx += 1
            if not fixed_addr:
                a1 = a1 - 1 if decrement else a1 + 1
            continue

        yield (vram_byte, a1)

        increments_on_high = (ppu.vmain & 0x80) != 0
        if (increments_on_high and b_dest == 0x19) or (
            not increments_on_high and b_dest == 0x18
        ):
            vmaddr = (vmaddr + vmain_inc) & 0xFFFF

        transferred += 1
        pat_idx += 1
        if not fixed_addr:
            a1 = a1 - 1 if decrement else a1 + 1

    ppu.vmaddr = vmaddr


# ────────────────────────────────────────────────────────────────────────
# Event extraction
# ────────────────────────────────────────────────────────────────────────

@dataclass
class WriteEvent:
    frame: int
    cycle: int
    pc: int
    vram_byte: int
    source: int            # source addr (for DMA) or value byte (for direct)
    direct: bool           # True = direct $2118 write, False = DMA
    src_pc: Optional[int] = None      # PC of $420B trigger (DMA) or store (direct)
    caller_pc: Optional[int] = None   # most-recent JSL/JSR target before the write
    return_pc: Optional[int] = None   # most-recent JSL/JSR site before the write


def extract_writes(trace_path: Path) -> Iterator[WriteEvent]:
    """Stream-extract VRAM-write events from a Mesen trace, with call tracking."""
    ppu = PpuState()

    # Lightweight call stack: list of (call_site_pc, target_pc). Pushed on
    # JSL/JSR, popped on RT[SL]. We don't try to be 100% accurate (interrupts,
    # PHK/PHD/RTI) — best-effort is enough to credit the calling routine.
    call_stack: list[tuple[int, int]] = []

    for ev in parse_trace(trace_path):
        insn = ev["insn"]
        pc = int(ev["pc"], 16)
        frame = int(ev["fr"])
        cycle = int(ev["cy"])
        a_reg = int(ev["a"], 16)
        x_reg = int(ev["x"], 16)
        y_reg = int(ev["y"], 16)
        p_flag = ev["p"]
        m_flag_8bit = "M" in p_flag        # accumulator-size flag
        x_flag_8bit = "X" in p_flag        # index-register-size flag

        # ── Call-stack tracking ─────────────────────────────────────────
        m_jsl = INSN_JSL_RE.match(insn)
        if m_jsl:
            tgt = int(m_jsl.group("tgt"), 16)
            call_stack.append((pc, tgt))
            if len(call_stack) > 64:
                call_stack.pop(0)  # cap depth — drop oldest if runaway
            continue
        m_jsr = INSN_JSR_RE.match(insn)
        if m_jsr:
            # JSR is 16-bit target in current PB; canonicalise to PB:tgt
            tgt = int(m_jsr.group("tgt"), 16) | (pc & 0xFF0000)
            call_stack.append((pc, tgt))
            if len(call_stack) > 64:
                call_stack.pop(0)
            continue
        if INSN_RTS_RE.match(insn):
            if call_stack:
                call_stack.pop()
            continue

        m = INSN_STORE_RE.match(insn)
        if not m:
            continue
        addr = int(m.group("addr"), 16)
        opcode = m.group(1)  # A, X, Y, Z

        # Determine value being stored AND its width.
        # Critical: A's width is M flag, X/Y's width is X flag.
        # STZ stores zero; the width depends on M flag (operates as A).
        if opcode == "A":
            val = a_reg
            wide = not m_flag_8bit
        elif opcode == "X":
            val = x_reg
            wide = not x_flag_8bit
        elif opcode == "Y":
            val = y_reg
            wide = not x_flag_8bit
        else:  # Z
            val = 0
            wide = not m_flag_8bit

        val_lo = val & 0xFF

        caller_pc = call_stack[-1][1] if call_stack else None
        return_pc = call_stack[-1][0] if call_stack else None

        # ── PPU registers ───────────────────────────────────────────────
        if addr == 0x2115:
            ppu.vmain = val_lo
        elif addr == 0x2116:
            if wide:
                ppu.vmaddr = val & 0xFFFF
            else:
                ppu.vmaddr = (ppu.vmaddr & 0xFF00) | val_lo
        elif addr == 0x2117:
            ppu.vmaddr = (ppu.vmaddr & 0x00FF) | (val_lo << 8)
        elif addr == 0x2118:
            vram_byte = (ppu.vmaddr & 0xFFFF) * 2
            yield WriteEvent(frame, cycle, pc, vram_byte, val_lo,
                             direct=True, caller_pc=caller_pc, return_pc=return_pc)
            increments_on_high = (ppu.vmain & 0x80) != 0
            if not increments_on_high:
                ppu.vmaddr = (ppu.vmaddr + ppu.vmaddr_inc()) & 0xFFFF
        elif addr == 0x2119:
            vram_byte = (ppu.vmaddr & 0xFFFF) * 2 + 1
            yield WriteEvent(frame, cycle, pc, vram_byte, val_lo,
                             direct=True, caller_pc=caller_pc, return_pc=return_pc)
            increments_on_high = (ppu.vmain & 0x80) != 0
            if increments_on_high:
                ppu.vmaddr = (ppu.vmaddr + ppu.vmaddr_inc()) & 0xFFFF

        # ── DMA channel registers ($43X0..$43X7) ────────────────────────
        elif 0x4300 <= addr <= 0x437F:
            ch_idx = (addr >> 4) & 0x07
            sub = addr & 0x0F
            ch = ppu.dmas[ch_idx]
            if sub == 0:
                ch.dmap = val_lo
            elif sub == 1:
                ch.bbad = val_lo
            elif sub == 2:
                if wide:
                    ch.a1t = val & 0xFFFF
                else:
                    ch.a1t = (ch.a1t & 0xFF00) | val_lo
            elif sub == 3:
                ch.a1t = (ch.a1t & 0x00FF) | (val_lo << 8)
            elif sub == 4:
                ch.a1b = val_lo
            elif sub == 5:
                if wide:
                    ch.das = val & 0xFFFF
                else:
                    ch.das = (ch.das & 0xFF00) | val_lo
            elif sub == 6:
                ch.das = (ch.das & 0x00FF) | (val_lo << 8)

        # ── DMA trigger ─────────────────────────────────────────────────
        elif addr == 0x420B:
            mask = val_lo
            for bit in range(8):
                if mask & (1 << bit):
                    ch = ppu.dmas[bit]
                    for vram_byte, src_addr in simulate_dma_writes(ch, ppu):
                        yield WriteEvent(
                            frame, cycle, pc, vram_byte, src_addr,
                            direct=False, src_pc=pc,
                            caller_pc=caller_pc, return_pc=return_pc,
                        )


# ────────────────────────────────────────────────────────────────────────
# Reporting
# ────────────────────────────────────────────────────────────────────────

def parse_byte_range(spec: str) -> tuple[int, int]:
    sep = ".." if ".." in spec else "-"
    a, b = spec.split(sep)
    return (int(a, 16), int(b, 16))


def parse_tile_range(spec: str, char_base: int = 0xC000, tile_size: int = 16) -> tuple[int, int]:
    sep = ".." if ".." in spec else "-"
    a, b = spec.split(sep)
    lo_tile = int(a, 16)
    hi_tile = int(b, 16)
    return (char_base + lo_tile * tile_size, char_base + (hi_tile + 1) * tile_size - 1)


def parse_frame_range(spec: str) -> tuple[int, int]:
    if ".." in spec:
        a, b = spec.split("..")
        return (int(a), int(b))
    elif "-" in spec:
        a, b = spec.split("-")
        return (int(a), int(b))
    else:
        n = int(spec)
        return (n, n)


def collect(trace_dir: Path, byte_lo: int, byte_hi: int,
            frame_lo: int, frame_hi: int) -> list[WriteEvent]:
    trace_files = sorted(trace_dir.glob("trace_*.log"))
    if not trace_files:
        print(f"No trace_*.log in {trace_dir}", file=sys.stderr)
        return []
    out: list[WriteEvent] = []
    for tf in trace_files:
        print(f"# Parsing {tf.name} ({tf.stat().st_size / 1e6:.1f} MB) from {tf.parent.name}",
              file=sys.stderr)
        for ev in extract_writes(tf):
            if byte_lo <= ev.vram_byte <= byte_hi and frame_lo <= ev.frame <= frame_hi:
                out.append(ev)
    return out


def fmt_caller(ev: WriteEvent) -> str:
    if ev.direct:
        if ev.caller_pc is not None:
            return f"VMDATA@${ev.pc:06X} (caller ${ev.caller_pc:06X})"
        return f"VMDATA@${ev.pc:06X}"
    if ev.caller_pc is not None:
        return f"DMA@${ev.src_pc:06X} (caller ${ev.caller_pc:06X})"
    return f"DMA@${ev.src_pc:06X}"


def print_summary(events: list[WriteEvent], byte_lo: int, byte_hi: int) -> None:
    last_per_tile: dict[tuple[int, int], WriteEvent] = {}
    for ev in events:
        tile = (ev.vram_byte - 0xC000) // 16 if ev.vram_byte >= 0xC000 else (ev.vram_byte // 16)
        key = (ev.frame, tile)
        prev = last_per_tile.get(key)
        if prev is None or ev.cycle > prev.cycle:
            last_per_tile[key] = ev

    print(f"\n# Last writer per (frame, tile) — range ${byte_lo:04X}..${byte_hi:04X}")
    print("# Fr      tile  byte    last_pc    caller    via")
    for (frame, tile), ev in sorted(last_per_tile.items()):
        kind = "VMDATA" if ev.direct else "DMA"
        caller_s = f"${ev.caller_pc:06X}" if ev.caller_pc is not None else "—"
        print(f"  Fr={frame:5d}  ${tile:03X}   ${ev.vram_byte:04X}   "
              f"${ev.pc:06X}  {caller_s}   {kind}")


def print_writer_histogram(events: list[WriteEvent], label: str) -> None:
    """Top callers + total bytes written across all frames."""
    by_caller: Counter[Optional[int]] = Counter()
    by_caller_bytes: Counter[Optional[int]] = Counter()
    for ev in events:
        by_caller[ev.caller_pc] += 1
        by_caller_bytes[ev.caller_pc] += 1

    print(f"\n# [{label}] Writer histogram (caller → write count)")
    print("# caller        writes")
    for caller, n in by_caller.most_common(15):
        caller_s = f"${caller:06X}" if caller is not None else "(no stack)"
        print(f"  {caller_s:12s}  {n:6d}")


def print_frame_table(events: list[WriteEvent], label: str) -> None:
    """Per-frame: how many bytes hit, who wrote last."""
    by_frame: dict[int, list[WriteEvent]] = defaultdict(list)
    for ev in events:
        by_frame[ev.frame].append(ev)

    print(f"\n# [{label}] Per-frame writes-into-range")
    print("# frame  total_writes  last_writer_caller   last_pc  via")
    for fr in sorted(by_frame):
        evs = by_frame[fr]
        last = max(evs, key=lambda e: e.cycle)
        kind = "VMDATA" if last.direct else "DMA"
        caller_s = f"${last.caller_pc:06X}" if last.caller_pc is not None else "—"
        print(f"  {fr:5d}  {len(evs):8d}     {caller_s:12s}     ${last.pc:06X}  {kind}")


def print_compare(events_a: list[WriteEvent], events_b: list[WriteEvent],
                  label_a: str, label_b: str,
                  byte_lo: int, byte_hi: int) -> None:
    print(f"\n# Comparing writes in ${byte_lo:04X}..${byte_hi:04X}")
    print(f"# A = {label_a}   ({len(events_a)} writes)")
    print(f"# B = {label_b}   ({len(events_b)} writes)")

    print_writer_histogram(events_a, label_a)
    print_writer_histogram(events_b, label_b)
    print_frame_table(events_a, label_a)
    print_frame_table(events_b, label_b)

    # Set difference — callers that write in A but not B (and vice versa)
    callers_a = {ev.caller_pc for ev in events_a if ev.caller_pc is not None}
    callers_b = {ev.caller_pc for ev in events_b if ev.caller_pc is not None}

    only_a = callers_a - callers_b
    only_b = callers_b - callers_a
    both = callers_a & callers_b

    def fmt(s: set) -> str:
        return ", ".join(f"${c:06X}" for c in sorted(s)) if s else "(none)"

    print(f"\n# Callers writing into the range:")
    print(f"#   only in A ({label_a}): {fmt(only_a)}")
    print(f"#   only in B ({label_b}): {fmt(only_b)}")
    print(f"#   in both:               {fmt(both)}")


def write_csv(path: Path, events: list[WriteEvent]) -> None:
    with path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["frame", "cycle", "pc", "vram_byte", "source", "direct",
                    "src_pc", "caller_pc", "return_pc"])
        for ev in events:
            w.writerow([
                ev.frame, ev.cycle, f"${ev.pc:06X}",
                f"${ev.vram_byte:04X}", f"${ev.source:06X}",
                "1" if ev.direct else "0",
                f"${ev.src_pc:06X}" if ev.src_pc is not None else "",
                f"${ev.caller_pc:06X}" if ev.caller_pc is not None else "",
                f"${ev.return_pc:06X}" if ev.return_pc is not None else "",
            ])


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("trace_dir", type=Path, nargs="?",
                    help="Mesen split-trace directory (single-trace mode)")
    ap.add_argument("--compare", nargs=2, metavar=("A", "B"), type=Path,
                    help="Compare writes between two trace dirs")
    ap.add_argument("--bytes", help="VRAM byte range (hex), e.g. D160..D17F")
    ap.add_argument("--tile", help="BG3 tile range (hex, $10-byte tiles), e.g. 116..117")
    ap.add_argument("--frame", help="Frame number or range, e.g. 451 or 451..460")
    ap.add_argument("--csv", type=Path, help="Write all events to CSV (single-trace mode)")
    ap.add_argument("--csv-a", type=Path, help="CSV for A (compare mode)")
    ap.add_argument("--csv-b", type=Path, help="CSV for B (compare mode)")
    ap.add_argument("--summary", action="store_true",
                    help="Print last-writer-per-tile-per-frame summary")
    args = ap.parse_args(argv)

    if args.bytes:
        byte_lo, byte_hi = parse_byte_range(args.bytes)
    elif args.tile:
        byte_lo, byte_hi = parse_tile_range(args.tile)
    else:
        byte_lo, byte_hi = (0xC000, 0xDFFF)

    frame_lo, frame_hi = (0, 1 << 30)
    if args.frame:
        frame_lo, frame_hi = parse_frame_range(args.frame)

    if args.compare:
        dir_a, dir_b = args.compare
        events_a = collect(dir_a, byte_lo, byte_hi, frame_lo, frame_hi)
        events_b = collect(dir_b, byte_lo, byte_hi, frame_lo, frame_hi)
        if args.csv_a:
            write_csv(args.csv_a, events_a)
            print(f"# Wrote {args.csv_a}", file=sys.stderr)
        if args.csv_b:
            write_csv(args.csv_b, events_b)
            print(f"# Wrote {args.csv_b}", file=sys.stderr)
        print_compare(events_a, events_b, dir_a.name, dir_b.name, byte_lo, byte_hi)
        return 0

    if args.trace_dir is None:
        ap.error("trace_dir is required (or use --compare)")

    events = collect(args.trace_dir, byte_lo, byte_hi, frame_lo, frame_hi)
    print(f"# {len(events)} VRAM writes in range ${byte_lo:04X}..${byte_hi:04X}",
          file=sys.stderr)

    if args.csv:
        write_csv(args.csv, events)
        print(f"# Wrote {args.csv}", file=sys.stderr)

    if args.summary or not args.csv:
        print_summary(events, byte_lo, byte_hi)
        print_writer_histogram(events, args.trace_dir.name)
        print_frame_table(events, args.trace_dir.name)

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
