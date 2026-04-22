#!/usr/bin/env python3
"""VWF render prototype — models the asm Step E algorithm end-to-end.

Font format (confirmed via font_accented_1bppil.bin byte dump):
  16 bytes per char = 8 rows × 2 bytes per row (2BPP-IL).
  byte[2N]   = plane 0 row N → encodes TOP half of glyph (rows 0-7 of 16-tall char)
  byte[2N+1] = plane 1 row N → encodes BOTTOM half of glyph (rows 8-15)
  Both planes share one 2BPP tile per char. Palette trick:
    - Top tilemap cell, palette P   → only plane-0 bits render as fg
    - Bottom tilemap cell, palette P+4 → only plane-1 bits render as fg

Algorithm (Strategy A — tilemap takeover, per-page canvas):
  State:
    pen          — pixel cursor, reset per line
    canvas_base  — NEXT_CANVAS at line start (baseline for line's canvas tiles)
    canvas[]     — pool of 2BPP-IL tile buffers (per-page, reset on [cls])
    dirty_lo/hi  — canvas-tile range dirty since last NMI DMA

  Per char:
    pen_tile   = pen >> 3                                    → line-relative tile idx
    canvas_lo  = canvas_base + pen_tile                      → left canvas tile
    canvas_hi  = canvas_base + pen_tile + 1                  → right canvas tile (spill)
    sub_x      = pen & 7
    for y in 0..15:
      g = font[char*16 + y]
      canvas[canvas_lo][y] |= (g >> sub_x)                   → main into left
      if sub_x > 0:
        canvas[canvas_hi][y] |= (g << (8 - sub_x)) & 0xFF    → spill into right
    tilemap[line_base + pen_tile*2]     = canvas_lo + VRAM_BASE | palette
    tilemap[line_base + (pen_tile+1)*2] = canvas_hi + VRAM_BASE | palette
    tilemap[line_base + pen_tile*2 + $40]      = canvas_lo + VRAM_BASE | palette+4  (bottom row)
    tilemap[line_base + (pen_tile+1)*2 + $40]  = canvas_hi + VRAM_BASE | palette+4
    dirty_lo = min(dirty_lo, canvas_lo), dirty_hi = max(dirty_hi, canvas_hi)
    pen += width[char]

  On line transition:
    canvas_base = NEXT_CANVAS                      (reserve new canvas block)
    NEXT_CANVAS += (highest pen_tile in line) + 2  (don't overwrite prev line)
    pen = 0
    Capture game-X at line start as line_base.

  On [cls] ($81:ECE5):
    NEXT_CANVAS = 0
    pen = 0
    all canvas tiles cleared to 0
    MAGIC = $5A

  NMI:
    if dirty: DMA canvas[dirty_lo..dirty_hi] → VRAM at $6680 + dirty_lo*8

  Saturation: canvas_lo ≥ 48 → fall back to fixed-width passthrough.
"""
from __future__ import annotations

import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
FONT_BIN = ROOT / "en_data/bin/fonts/font_accented_1bppil.bin"
WIDTH_BIN = ROOT / "en_data/bin/fonts/font_widths.bin"

NUM_CANVAS = 48       # canvas pool (shared across lines within a page)
LINE_COLS  = 32       # tilemap cells per line (top row)


def load_font() -> bytes:
    return FONT_BIN.read_bytes()


def load_widths() -> bytes:
    if WIDTH_BIN.exists():
        return WIDTH_BIN.read_bytes()
    font = load_font()
    widths = bytearray(256)
    for c in range(256):
        g = font[c*16:(c+1)*16]
        max_col = -1
        for r in range(8):
            for p in (0, 1):
                b = g[2*r + p]
                for col in range(8):
                    if b & (0x80 >> col):
                        max_col = max(max_col, col)
        if c == 0x20:
            widths[c] = 4
        elif max_col < 0:
            widths[c] = 0
        else:
            widths[c] = max_col + 2
    return bytes(widths)


@dataclass
class Line:
    """Per-line tilemap (32 cells top + 32 cells bottom pointing at canvas tile ids)."""
    top: list[int | None] = field(default_factory=lambda: [None] * LINE_COLS)
    bot: list[int | None] = field(default_factory=lambda: [None] * LINE_COLS)
    pen_end: int = 0
    canvas_base: int = 0
    canvas_span: int = 0


@dataclass
class VwfState:
    font: bytes = field(default_factory=load_font)
    widths: bytes = field(default_factory=load_widths)
    canvas: list[bytearray] = field(default_factory=lambda: [bytearray(16) for _ in range(NUM_CANVAS)])
    next_canvas: int = 0
    pen: int = 0
    canvas_base: int = 0
    line_max_tile: int = 0       # highest pen_tile used in current line
    dirty_lo: int = 0xFF
    dirty_hi: int = 0x00
    lines: list[Line] = field(default_factory=lambda: [Line()])
    cur_line: int = 0
    saturated: bool = False

    def cls(self):
        for c in self.canvas:
            for i in range(16):
                c[i] = 0
        self.next_canvas = 0
        self.pen = 0
        self.canvas_base = 0
        self.line_max_tile = 0
        self.dirty_lo = 0xFF
        self.dirty_hi = 0x00
        self.lines = [Line()]
        self.cur_line = 0
        self.saturated = False

    def newline(self):
        # Stamp completed line's stats, reserve its canvas block, open next line.
        cur = self.lines[self.cur_line]
        cur.pen_end = self.pen
        cur.canvas_base = self.canvas_base
        cur.canvas_span = self.line_max_tile + 1
        self.next_canvas = self.canvas_base + cur.canvas_span
        self.canvas_base = self.next_canvas
        self.pen = 0
        self.line_max_tile = 0
        self.saturated = False
        self.lines.append(Line())
        self.cur_line += 1

    def finish(self):
        """Call at end of message to stamp the last line's stats."""
        cur = self.lines[self.cur_line]
        cur.pen_end = self.pen
        cur.canvas_base = self.canvas_base
        cur.canvas_span = self.line_max_tile + 1 if self.line_max_tile else 0

    def render_char(self, ch: str):
        if ch == '\n':
            self.newline()
            return
        if self.saturated:
            return
        c = ord(ch) & 0xFF
        w = self.widths[c]
        sub_x = self.pen & 7
        pen_tile = self.pen >> 3
        canvas_lo = self.canvas_base + pen_tile
        canvas_hi = canvas_lo + 1
        if canvas_hi >= NUM_CANVAS:
            self.saturated = True
            return
        glyph = self.font[c*16:(c+1)*16]
        for y in range(16):
            g = glyph[y]
            self.canvas[canvas_lo][y] |= (g >> sub_x) & 0xFF
            if sub_x > 0:
                self.canvas[canvas_hi][y] |= (g << (8 - sub_x)) & 0xFF
        line = self.lines[self.cur_line]
        if pen_tile < LINE_COLS:
            line.top[pen_tile] = canvas_lo
            line.bot[pen_tile] = canvas_lo
        if pen_tile + 1 < LINE_COLS:
            line.top[pen_tile + 1] = canvas_hi
            line.bot[pen_tile + 1] = canvas_hi
        self.dirty_lo = min(self.dirty_lo, canvas_lo)
        self.dirty_hi = max(self.dirty_hi, canvas_hi)
        self.line_max_tile = max(self.line_max_tile, pen_tile + 1)
        self.pen += w


def render_line(state: VwfState, line: Line) -> list[str]:
    """Render one tilemap line (8 top rows + 8 bottom rows) as 16 ASCII strings."""
    out_rows = []
    # Top half: plane 0 of tiles referenced by line.top
    for row in range(8):
        s = ''
        for col in range(LINE_COLS):
            ti = line.top[col]
            if ti is None:
                s += '        '
                continue
            b: int = state.canvas[ti][2*row + 0]
            for bit in range(8):
                s += '#' if (b & (0x80 >> bit)) else '.'
        out_rows.append(s.rstrip())
    # Bottom half: plane 1 of tiles referenced by line.bot
    for row in range(8):
        s = ''
        for col in range(LINE_COLS):
            ti = line.bot[col]
            if ti is None:
                s += '        '
                continue
            b = state.canvas[ti][2*row + 1]
            for bit in range(8):
                s += '#' if (b & (0x80 >> bit)) else '.'
        out_rows.append(s.rstrip())
    return out_rows


def to_ascii(state: VwfState) -> str:
    """Render all tilemap lines stacked vertically with a separator between lines."""
    blocks = []
    for i, line in enumerate(state.lines):
        blocks.append(f"--- line {i} ---")
        blocks.extend(render_line(state, line))
    return '\n'.join(blocks)


def main():
    msg = sys.argv[1] if len(sys.argv) > 1 else "Hi there!"
    state = VwfState()
    state.cls()
    for ch in msg:
        state.render_char(ch)
    state.finish()
    total_vwf = sum(line.pen_end for line in state.lines)
    total_fixed = sum(len(seg) * 8 for seg in msg.split('\n'))
    canvas_used = state.canvas_base + state.line_max_tile + 1 if state.line_max_tile else state.canvas_base
    print(f"msg={msg!r}")
    print(f"  lines={len(state.lines)}  canvas_used={canvas_used}/{NUM_CANVAS}  dirty=[{state.dirty_lo}..{state.dirty_hi}]")
    for i, line in enumerate(state.lines):
        fixed = 0
        if i < len(msg.split('\n')):
            fixed = len(msg.split('\n')[i]) * 8
        print(f"  L{i}: pen={line.pen_end}px  fixed={fixed}px  "
              f"compression={100*(fixed-line.pen_end)//max(fixed,1)}%  "
              f"canvas[{line.canvas_base}..{line.canvas_base + line.canvas_span - 1}]")
    print(f"  TOTAL: vwf={total_vwf}px  fixed={total_fixed}px  compression={100*(total_fixed-total_vwf)//max(total_fixed,1)}%")
    print(to_ascii(state))


if __name__ == '__main__':
    main()
