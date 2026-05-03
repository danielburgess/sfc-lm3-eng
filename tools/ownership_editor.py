#!/usr/bin/env python3
"""
ownership_editor.py — Visual editor for VWF per-cell ownership bitmaps.

Connects to a running Mesen2-Diz instance via IPC, renders the BG3 layer
(where VWF DMAs land) as a PNG, overlays the 8×32 canvas-cell grid,
and lets you click cells to author the 32-byte ownership bitmap consumed
by VWFGateDecision in asm/vwf_patch.asm.

Output is 32 bytes (256 bits, 1 = VWF owns / DMA OK, 0 = engine owns /
preserve), packed row-major MSB-first to match the asm convention:
    byte 0 bit 7  = canvas cell 0   (row 0, col 0)
    byte 0 bit 6  = canvas cell 1   (row 0, col 1)
    ...
    byte 3 bit 0  = canvas cell 31  (row 0, col 31)
    byte 4 bit 7  = canvas cell 32  (row 1, col 0)
    ...
    byte 31 bit 0 = canvas cell 255 (row 7, col 31)

Usage:
    python3 tools/ownership_editor.py [--scene file_info]
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import os
import sys
from pathlib import Path

# pywebview / Qt defaults — set before any webview/Qt import.
os.environ.setdefault("QT_QPA_PLATFORM", "xcb")
os.environ.setdefault("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-gpu --no-sandbox")

import webview                              # noqa: E402
from PIL import Image                       # noqa: E402

from retrotool.graphics.tiles import decode_tile, decode_tiles  # noqa: E402
from retrotool.graphics.palette import Palette  # noqa: E402
from retrotool.graphics.tilemap import decode_tilemap, render_tilemap  # noqa: E402

# Reuse the project's IPC client (lives in repo root).
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from mesen_ipc import (connect, send_cmd, read_mem, write_mem,        # noqa: E402
                       step_frames, set_controller, clear_controller)


# ────────────────────────────────────────────────────────────────────────
# Canvas-buffer rendering — uses retrotool.graphics
# ────────────────────────────────────────────────────────────────────────

# VWF canvas is at WRAM $7F:7000 (= linear offset 0x17000 in the 128KB image).
# Layout: 8 rows × 32 cols × 32 bytes per cell. Each cell holds two stacked
# 2bpp tiles (top tile bytes 0..15, bot tile bytes 16..31), rendering an 8×16
# px tile-pair when DMAed to BG3 char data.
CANVAS_WRAM_OFFSET    = 0x17000        # $7F:7000 in linear WRAM
TILE_BASES_WRAM_OFFSET = 0x15D62       # $7F:5D62 in linear WRAM
TILE_BASES_BYTES      = 16             # 8 word entries, one per canvas row
CANVAS_ROWS = 8
CANVAS_COLS = 32
CELL_BYTES  = 32      # 16 (top tile) + 16 (bot tile)
CELL_PX_W   = 8       # native pixels — pre-zoom
CELL_PX_H   = 16      # native pixels — pre-zoom
CANVAS_BPP  = 2

# Free BG3 tile ranges — used by the free-tile scanner below to suggest
# tile_id_bases to the user.
BG3_CHAR_RANGE_BYTES = (0xC000, 0xF800)   # bytes [start, end) of BG3 char data

# Optional: render BG3 too, for context/debug. Same layout as before.
BG3_CHAR_BASE_BYTE = 0xC000
BG3_TILEMAP_BYTE   = 0xF800
TILEMAP_W          = 32
TILEMAP_H          = 32
BG3_TILE_COUNT     = 0x200
BG3_BPP            = 2


def render_canvas(canvas_wram: bytes, cgram: bytes,
                  palette_idx: int = 0,
                  positions: dict[int, tuple[int, int]] | None = None) -> Image.Image:
    """Render the VWF canvas buffer to a 256×256 RGBA PIL image.

    canvas_wram: 8192 bytes from $7F:7000 (= 8 rows × 32 cols × 32 B).
    Each cell = top tile [0..15] above bot tile [16..31], stacked 8×16 px.

    If `positions` is given (cell_idx → (native_x, native_y) from a tilemap
    scan), each cell is blitted at its mapped screen position so the canvas
    image visually aligns with the BG3 layer underneath. Cells with no
    position fall back to the linear layout (col*8, row*16).

    Output is always 256×256 (matching BG3 size) so the canvas image and
    BG3 layer can be stacked in the same stage without offset arithmetic.
    """
    pal = Palette.from_bytes(cgram, offset=palette_idx * 4 * 2, count=4,
                             transparent_index=-1)
    positions = positions or {}

    img_w = TILEMAP_W * 8     # 256 — same as BG3 layer
    img_h = TILEMAP_H * 8     # 256
    buf = bytearray(img_w * img_h * 4)

    for cell in range(CANVAS_ROWS * CANVAS_COLS):
        cv_row = cell // CANVAS_COLS
        cv_col = cell %  CANVAS_COLS
        cell_off = cell * CELL_BYTES

        if cell in positions:
            origin_x, origin_y = positions[cell]
        else:
            origin_x = cv_col * CELL_PX_W
            origin_y = cv_row * CELL_PX_H

        top = decode_tile(canvas_wram, cell_off, CANVAS_BPP)
        bot = decode_tile(canvas_wram, cell_off + 16, CANVAS_BPP)

        for sub_y, tile in enumerate((top, bot)):
            for y in range(8):
                py = origin_y + sub_y * 8 + y
                if py < 0 or py >= img_h:
                    continue
                px_row = tile[y]
                for x in range(8):
                    px = origin_x + x
                    if px < 0 or px >= img_w:
                        continue
                    r, g, b, a = pal.rgba(px_row[x])
                    dst = (py * img_w + px) * 4
                    buf[dst]     = r
                    buf[dst + 1] = g
                    buf[dst + 2] = b
                    buf[dst + 3] = a

    return Image.frombytes("RGBA", (img_w, img_h), bytes(buf))


def render_bg3(vram: bytes, cgram: bytes) -> Image.Image:
    """Render the 32×32 BG3 tilemap to a 256×256 RGBA PIL image (context view)."""
    palettes = [Palette.from_bytes(cgram, offset=p * 4 * 2, count=4,
                                   transparent_index=-1)
                for p in range(8)]
    tiles = decode_tiles(vram, offset=BG3_CHAR_BASE_BYTE,
                         count=BG3_TILE_COUNT, bpp=BG3_BPP)
    entries = decode_tilemap(vram, offset=BG3_TILEMAP_BYTE,
                             width=TILEMAP_W, height=TILEMAP_H)
    # Tilemap entries can reference tile IDs up to $3FF (10-bit field), but
    # BG3's char data only covers tile_ids 0..$1FF (= bytes $C000..$DFFF).
    # Any out-of-range tile_id points at BG2 char data, which we don't have
    # decoded — clamp it to 0 (blank) so render_tilemap doesn't IndexError.
    for row in entries:
        for entry in row:
            if entry.tile >= BG3_TILE_COUNT:
                entry.tile = 0
    width, height, rgba = render_tilemap(entries, tiles, palettes)
    return Image.frombytes("RGBA", (width, height), bytes(rgba))


def scan_vwf_positions(vram: bytes) -> dict[int, tuple[int, int]]:
    """Scan BG3 tilemap for VWF tile IDs and return {cell_index: (px_x, px_y)}.

    For each tilemap entry whose tile_id is in [$20, $21F], decode the canvas
    cell (top-tile only) and record its screen position in *native* px (one
    tilemap entry = 8×8 native px). Empty if VWF hasn't written tilemap
    entries (e.g. ownership=0 build → no entries to scan).
    """
    out: dict[int, tuple[int, int]] = {}
    for tm_row in range(TILEMAP_H):
        for tm_col in range(TILEMAP_W):
            off = BG3_TILEMAP_BYTE + (tm_row * TILEMAP_W + tm_col) * 2
            word = vram[off] | (vram[off + 1] << 8)
            tile_id = word & 0x3FF
            if 0x20 <= tile_id < 0x220:
                rel = tile_id - 0x20
                if (rel & 1) == 0:                  # only count top tiles
                    cv_row = rel // 64
                    cv_col = (rel % 64) // 2
                    cell = cv_row * CANVAS_COLS + cv_col
                    if cell not in out:             # first hit wins
                        out[cell] = (tm_col * 8, tm_row * 8)
    return out


def image_to_data_uri(img: Image.Image) -> str:
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


# ────────────────────────────────────────────────────────────────────────
# Mesen IPC pull
# ────────────────────────────────────────────────────────────────────────

def pull_snapshot() -> tuple[bytes, bytes, bytes]:
    """Return (vram, cgram, canvas) bytes from the running Mesen instance.

    canvas is the 8 KB VWF tile-format buffer at WRAM $7F:7000 (= linear
    offset 0x17000 in the 128 KB SnesWorkRam image).
    """
    sock = connect()
    vram = read_mem(sock, "SnesVideoRam", 0, 0x10000)
    cgram = read_mem(sock, "SnesCgRam", 0, 0x200)
    canvas = read_mem(sock, "SnesWorkRam", CANVAS_WRAM_OFFSET, 0x2000)
    if vram is None or cgram is None or canvas is None:
        raise RuntimeError("Failed to read VRAM/CGRAM/canvas via Mesen IPC.")
    return bytes(vram), bytes(cgram), bytes(canvas)


# ────────────────────────────────────────────────────────────────────────
# Bitmap model
# ────────────────────────────────────────────────────────────────────────

class TileBases:
    """Per-canvas-row VWF tile_id_base table (8 × 16-bit words).

    Each entry is the BG3 tile_id where canvas_col=0 of that row lands.
    `$FFFF` sentinel means "this canvas row is not VWF-owned on this scene"
    — VWFCharHandler skips the tilemap write and vwfDoDmaForCell skips the
    DMA, leaving any prior tilemap entries / engine font tile content
    untouched.
    """

    SENTINEL = 0xFFFF

    def __init__(self):
        self.bases = [self.SENTINEL] * CANVAS_ROWS

    def get(self, row: int) -> int:
        return self.bases[row]

    def set(self, row: int, value: int) -> None:
        self.bases[row] = value & 0xFFFF

    def disable(self, row: int) -> None:
        self.bases[row] = self.SENTINEL

    def is_enabled(self, row: int) -> bool:
        return self.bases[row] != self.SENTINEL

    def clear(self) -> None:
        self.bases = [self.SENTINEL] * CANVAS_ROWS

    def fill(self, base: int = 0x0214, stride: int = 0x40) -> None:
        """Fill all 8 rows starting at `base`, stride 0x40 (= 64 tiles per row)."""
        for r in range(CANVAS_ROWS):
            self.bases[r] = (base + r * stride) & 0xFFFF

    def to_bytes(self) -> bytes:
        out = bytearray(TILE_BASES_BYTES)
        for r in range(CANVAS_ROWS):
            v = self.bases[r] & 0xFFFF
            out[r * 2]     = v & 0xFF
            out[r * 2 + 1] = (v >> 8) & 0xFF
        return bytes(out)

    def from_bytes(self, data: bytes) -> None:
        for r in range(CANVAS_ROWS):
            self.bases[r] = data[r * 2] | (data[r * 2 + 1] << 8)

    def to_asm(self, scene_name: str = "") -> str:
        lines = []
        if scene_name:
            lines.append(f"    ; tile_id_base table — {scene_name}")
        # Two dw lines × 4 entries each (8 rows total).
        for chunk_start in (0, 4):
            entries = ", ".join(f"${self.bases[r]:04X}" for r in range(chunk_start, chunk_start + 4))
            label = f"row {chunk_start}..{chunk_start+3}"
            lines.append(f"    dw {entries}      ; {label}")
        return "\n".join(lines)

def scan_free_tile_ranges(vram: bytes, min_run: int = 64) -> list[tuple[int, int, str]]:
    """Walk BG3 char data ($C000..$F7FF) and return free contiguous tile runs.

    Returns list of (start_tile_id, end_tile_id, fill_kind) where fill_kind
    is 'zero' or 'ff' and end is inclusive. Sorted longest-first so the
    UI's "Pick free range" button can offer them in order of size.
    """
    char_start = BG3_CHAR_RANGE_BYTES[0]
    char_end   = BG3_CHAR_RANGE_BYTES[1]
    n_tiles = (char_end - char_start) // 16
    if char_end > len(vram):
        return []

    def cls(t: bytes) -> str:
        if all(b == 0x00 for b in t): return 'zero'
        if all(b == 0xFF for b in t): return 'ff'
        return 'data'

    states = [cls(vram[char_start + i*16 : char_start + (i+1)*16]) for i in range(n_tiles)]

    runs = []
    cur, start = states[0], 0
    for i, s in enumerate(states[1:], 1):
        if s != cur:
            if cur in ('zero', 'ff'):
                runs.append((start, i - 1, cur))
            cur, start = s, i
    if cur in ('zero', 'ff'):
        runs.append((start, n_tiles - 1, cur))

    runs = [(s, e, k) for s, e, k in runs if (e - s + 1) >= min_run]
    runs.sort(key=lambda r: r[1] - r[0], reverse=True)
    return runs


# ────────────────────────────────────────────────────────────────────────
# Bridged API exposed to JS
# ────────────────────────────────────────────────────────────────────────

class Api:
    def __init__(self, scene_name: str):
        self.scene_name = scene_name
        self.tile_bases = TileBases()
        self.vram: bytes = b""
        self.cgram: bytes = b""
        self.canvas: bytes = b""
        self.canvas_uri: str = ""
        self.bg3_uri: str = ""
        self.palette_idx = 0
        self.positions: dict[int, tuple[int, int]] = {}
        self.aligned: bool = False    # default: sequential (linear) layout
        self.free_ranges: list = []

    def _render_canvas(self) -> Image.Image:
        pos = self.positions if self.aligned else None
        return render_canvas(self.canvas, self.cgram, self.palette_idx, pos)

    def refresh(self) -> dict:
        """Pull fresh VRAM/CGRAM/canvas/tile_bases from Mesen and re-render."""
        try:
            self.vram, self.cgram, self.canvas = pull_snapshot()
            sock = connect()
            tb = read_mem(sock, "SnesWorkRam",
                          TILE_BASES_WRAM_OFFSET, TILE_BASES_BYTES)
            if tb is not None:
                self.tile_bases.from_bytes(bytes(tb))
            self.positions  = scan_vwf_positions(self.vram)
            self.free_ranges = scan_free_tile_ranges(self.vram, min_run=64)
            canvas_img = self._render_canvas()
            bg3_img    = render_bg3(self.vram, self.cgram)
            self.canvas_uri = image_to_data_uri(canvas_img)
            self.bg3_uri    = image_to_data_uri(bg3_img)
            return {
                "ok": True,
                "canvas": self.canvas_uri,
                "bg3": self.bg3_uri,
                "positions": self.positions,
                "positionsCount": len(self.positions),
                "aligned": self.aligned,
                "bases": self.tile_bases.bases,
                "freeRanges": [
                    {"start": s, "end": e, "kind": k, "size": e - s + 1}
                    for s, e, k in self.free_ranges
                ],
            }
        except Exception as e:
            return {"ok": False, "error": str(e)}

    def set_aligned(self, on: bool) -> dict:
        """Toggle canvas/grid layout: sequential (False) or screen-aligned (True)."""
        self.aligned = bool(on)
        if self.canvas and self.cgram:
            self.canvas_uri = image_to_data_uri(self._render_canvas())
        return {
            "aligned": self.aligned,
            "canvas":  self.canvas_uri,
            "positions": self.positions,
        }

    def set_palette(self, idx: int) -> dict:
        self.palette_idx = max(0, min(7, int(idx)))
        if self.canvas and self.cgram:
            self.canvas_uri = image_to_data_uri(self._render_canvas())
        return {"palette": self.palette_idx, "canvas": self.canvas_uri}

    def apply_live(self,
                   button: str = "b",
                   hold_frames: int = 2,
                   settle_frames: int = 4) -> dict:
        """Push the current tile_bases table to WRAM, tap a button to force
        a re-emit, then refresh the views from the resulting emulator state.

        The user's table *is* the new state — no restore. Lets you preview
        the exact rendering for the current bases without rebuilding ROM.
        """
        try:
            sock = connect()
            send_cmd(sock, "pause")

            data = self.tile_bases.to_bytes()
            write_mem(sock, "SnesWorkRam",
                      TILE_BASES_WRAM_OFFSET, list(data))

            set_controller(sock, port=0, **{button: True})
            step_frames(sock, hold_frames)
            clear_controller(sock, port=0)
            step_frames(sock, settle_frames)

            vram   = read_mem(sock, "SnesVideoRam", 0, 0x10000)
            cgram  = read_mem(sock, "SnesCgRam", 0, 0x200)
            canvas = read_mem(sock, "SnesWorkRam",
                              CANVAS_WRAM_OFFSET, 0x2000)
            if vram is None or cgram is None or canvas is None:
                return {"ok": False, "error": "post-apply memory read failed"}

            self.vram   = bytes(vram)
            self.cgram  = bytes(cgram)
            self.canvas = bytes(canvas)
            self.positions = scan_vwf_positions(self.vram)

            self.canvas_uri = image_to_data_uri(self._render_canvas())
            self.bg3_uri    = image_to_data_uri(render_bg3(self.vram, self.cgram))

            return {
                "ok": True,
                "canvas":         self.canvas_uri,
                "bg3":            self.bg3_uri,
                "positions":      self.positions,
                "positionsCount": len(self.positions),
                "appliedBytes":   TILE_BASES_BYTES,
                "bases":          self.tile_bases.bases,
            }
        except Exception as e:
            return {"ok": False, "error": f"{type(e).__name__}: {e}"}

    def get_state(self) -> dict:
        return {
            "canvas":    self.canvas_uri,
            "bg3":       self.bg3_uri,
            "bases":     self.tile_bases.bases,
            "scene":     self.scene_name,
            "palette":   self.palette_idx,
            "positions": getattr(self, "positions", {}),
            "aligned":   self.aligned,
            "freeRanges": [
                {"start": s, "end": e, "kind": k, "size": e - s + 1}
                for s, e, k in self.free_ranges
            ],
        }

    def set_row_base(self, row: int, value: int) -> dict:
        """Set canvas row's tile_id_base. value < 0 → disable ($FFFF)."""
        if value is None or value < 0 or value > 0xFFFF:
            self.tile_bases.disable(row)
        else:
            self.tile_bases.set(row, value)
        return {"row": row, "base": self.tile_bases.bases[row]}

    def disable_row(self, row: int) -> dict:
        self.tile_bases.disable(row)
        return {"row": row, "base": self.tile_bases.bases[row]}

    def clear(self) -> dict:
        self.tile_bases.clear()
        return {"bases": self.tile_bases.bases}

    def fill(self) -> dict:
        """Fill all rows starting at the first free range with stride $40."""
        if self.free_ranges:
            start = self.free_ranges[0][0]
            self.tile_bases.fill(base=start, stride=0x40)
        else:
            self.tile_bases.fill()
        return {"bases": self.tile_bases.bases}

    def export_asm(self) -> str:
        return self.tile_bases.to_asm(self.scene_name)

    def save_def(self) -> dict:
        path = Path(__file__).resolve().parent / "ownership" / f"{self.scene_name}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"bases": self.tile_bases.bases}, indent=2))
        return {"path": str(path)}

    def load_def(self) -> dict:
        path = Path(__file__).resolve().parent / "ownership" / f"{self.scene_name}.json"
        if not path.exists():
            return {"ok": False, "error": f"no def at {path}"}
        data = json.loads(path.read_text())
        if "bases" in data:
            self.tile_bases.bases = list(data["bases"])
        return {"ok": True, "bases": self.tile_bases.bases}


# ────────────────────────────────────────────────────────────────────────
# HTML / JS frontend
# ────────────────────────────────────────────────────────────────────────

HTML = r"""<!doctype html>
<html><head><meta charset="utf-8"><title>VWF Tile-Bases Editor</title>
<style>
  * { box-sizing: border-box; }
  body { background:#1a1a1a; color:#ddd; font-family: monospace; margin:0; padding:12px; }
  h1 { font-size:16px; margin:0 0 8px; }
  .toolbar { margin: 8px 0; display:flex; gap:8px; flex-wrap:wrap; align-items:center; }
  .toolbar button, .toolbar select {
    background:#2a2a2a; color:#ddd; border:1px solid #444;
    padding: 6px 12px; cursor:pointer; font-family:monospace;
  }
  .toolbar button:hover { background:#333; border-color:#666; }
  .toolbar .scene { color:#9c9; }
  .panes { display:flex; gap:12px; align-items:flex-start; flex-wrap:wrap; }
  .pane-title { font-size:11px; color:#888; margin: 0 0 4px; }
  /* Stage is 512×512 (BG3 scaled 2×). Canvas overlays the top 256 px. */
  #stage {
    position: relative; width:512px; height:512px;
    background:#000; border:1px solid #444;
  }
  #bg3Img {
    position:absolute; left:0; top:0; width:512px; height:512px;
    image-rendering: pixelated; z-index:1;
  }
  #canvasImg {
    position:absolute; left:0; top:0; width:512px; height:512px;
    image-rendering: pixelated; z-index:2;
    pointer-events: none;
    /* opacity controlled at runtime by the slider */
  }
  #grid { position:absolute; left:0; top:0; width:512px; height:512px; z-index:3; }
  .cell.aligned { border-color: rgba(120, 200, 255, 0.55); }
  .cell {
    position:absolute; width:16px; height:32px;
    border:1px solid rgba(255,255,255,0.18);
    cursor: crosshair;
  }
  .cell.owned { background: rgba(60, 220, 90, 0.42); border-color: #6f6; }
  .cell:hover { outline: 1px solid #ff0; outline-offset: -1px; }
  /* Row-base table */
  .row-table { display: grid; grid-template-columns: auto auto auto auto auto; gap: 4px 8px; align-items: center; margin-top: 8px; }
  .row-table label { color:#9c9; font-family:monospace; }
  .row-table .hex-in {
    background:#222; color:#cfc; border:1px solid #444; padding:3px 6px;
    font-family:monospace; width: 80px; text-align:right;
  }
  .row-table .hex-in:focus { border-color:#aaa; outline: none; }
  .row-table .hex-in.disabled { color:#555; background:#191919; }
  .row-table button { font-size:11px; padding:2px 6px; }
  .free-list {
    margin-top:6px; color:#88a; font-family:monospace; font-size:11px;
    background:#111; border:1px solid #333; padding:4px 6px; max-height:80px; overflow:auto;
  }
  #export {
    width:512px; height:170px; margin-top:8px;
    background:#111; color:#9cf; border:1px solid #444;
    font-family:monospace; font-size:12px; padding:6px;
    white-space:pre; overflow:auto;
    resize: vertical;
    user-select: text;
    -webkit-user-select: text;
  }
  .export-row { display:flex; gap:8px; align-items:center; margin-top:4px; }
  .status { color:#888; font-size:11px; margin-left:auto; }
  .legend { color:#888; font-size:11px; margin-top:4px; }
  .slider-row { display:flex; align-items:center; gap:6px; }
  .slider-row input[type=range] { width:140px; }
</style></head>
<body>
  <h1>VWF Tile-Bases Editor — <span id="scene" class="scene">?</span></h1>
  <div class="toolbar">
    <button id="btn-refresh">↻ Refresh from Mesen</button>
    <button id="btn-apply" title="Push current tile_bases to WRAM + B-tap to redraw — preview live in Mesen">▶ Apply live</button>
    <button id="btn-clear">Clear all (all $FFFF)</button>
    <button id="btn-fill">Auto-fill from free range</button>
    <button id="btn-load">Load .def</button>
    <button id="btn-save">Save .def</button>
    <button id="btn-export">Export asm →</button>
    <label>palette
      <select id="palette">
        <option value="0">0</option><option value="1">1</option>
        <option value="2">2</option><option value="3">3</option>
        <option value="4">4</option><option value="5">5</option>
        <option value="6">6</option><option value="7">7</option>
      </select>
    </label>
    <span class="slider-row">canvas overlay
      <input id="opacity" type="range" min="0" max="100" value="100">
      <span id="opacityVal" style="width:32px;text-align:right;">100%</span>
    </span>
    <span class="status" id="status">ready</span>
  </div>
  <div>
    <div class="pane-title">BG3 screen (under) + VWF canvas buffer (over) — for context only</div>
    <div id="stage">
      <img id="bg3Img" alt="">
      <img id="canvasImg" alt="">
    </div>
    <div class="legend">Engine font + canvas-buffer overlay. Use the slider to blend. The canvas shows what VWF *would* compose for each row.</div>
  </div>
  <div class="pane-title" style="margin-top:8px;">Per-canvas-row tile_id base (hex, $FFFF = row not VWF-owned)</div>
  <div class="row-table" id="rowTable"></div>
  <div class="pane-title" style="margin-top:8px;">Free BG3 tile ranges (≥ 64 tiles)</div>
  <div class="free-list" id="freeList">scanning…</div>
  <textarea id="export" spellcheck="false" wrap="off" readonly></textarea>
  <div class="export-row">
    <button id="btn-copy">Copy to clipboard</button>
    <span class="status" id="copyStatus"></span>
  </div>
<script>
const CANVAS_ROWS = 8;

const canvasImg = document.getElementById('canvasImg');
const bg3Img = document.getElementById('bg3Img');
const status = document.getElementById('status');
const exportBox = document.getElementById('export');
const sceneEl = document.getElementById('scene');
const paletteSel = document.getElementById('palette');
const rowTable = document.getElementById('rowTable');
const freeList = document.getElementById('freeList');

let currentBases = new Array(CANVAS_ROWS).fill(0xFFFF);
let currentFreeRanges = [];

function isDisabled(v) { return (v & 0xFFFF) === 0xFFFF; }
function fmtHex(v) { return '$' + (v & 0xFFFF).toString(16).toUpperCase().padStart(4, '0'); }
function parseHex(s) {
  s = s.trim().replace(/^\$/, '').replace(/^0x/i, '');
  if (s === '' || s.toUpperCase() === 'FFFF' || s.toUpperCase() === 'OFF' || s.toUpperCase() === 'NONE') return 0xFFFF;
  const n = parseInt(s, 16);
  if (isNaN(n) || n < 0 || n > 0xFFFF) return null;
  return n;
}

function buildRowTable() {
  rowTable.innerHTML = '';
  // header
  for (const h of ['canvas row', 'tile_id_base', 'tile range (64 tiles)', 'pick free', 'disable']) {
    const el = document.createElement('div');
    el.style.color = '#888';
    el.style.fontSize = '11px';
    el.textContent = h;
    rowTable.appendChild(el);
  }
  for (let r = 0; r < CANVAS_ROWS; r++) {
    const lblCol = document.createElement('label');
    lblCol.textContent = 'row ' + r;
    rowTable.appendChild(lblCol);

    const inp = document.createElement('input');
    inp.className = 'hex-in';
    inp.type = 'text';
    inp.dataset.row = String(r);
    inp.value = fmtHex(currentBases[r]);
    inp.addEventListener('change', onRowInputChange);
    rowTable.appendChild(inp);

    const rangeEl = document.createElement('span');
    rangeEl.className = 'range-disp';
    rangeEl.dataset.row = String(r);
    rowTable.appendChild(rangeEl);

    const pickBtn = document.createElement('button');
    pickBtn.textContent = '⇣ pick';
    pickBtn.title = 'Pick the next free 64-tile range starting from $214 (skipping rows already assigned)';
    pickBtn.addEventListener('click', () => onPickFree(r));
    rowTable.appendChild(pickBtn);

    const offBtn = document.createElement('button');
    offBtn.textContent = '$FFFF';
    offBtn.title = 'Disable VWF on this row';
    offBtn.addEventListener('click', () => onDisableRow(r));
    rowTable.appendChild(offBtn);
  }
  applyBasesToTable();
}

function applyBasesToTable() {
  for (let r = 0; r < CANVAS_ROWS; r++) {
    const inp = rowTable.querySelector(`input[data-row="${r}"]`);
    const rangeEl = rowTable.querySelector(`span.range-disp[data-row="${r}"]`);
    if (!inp || !rangeEl) continue;
    inp.value = fmtHex(currentBases[r]);
    inp.classList.toggle('disabled', isDisabled(currentBases[r]));
    if (isDisabled(currentBases[r])) {
      rangeEl.textContent = '— (engine-only)';
      rangeEl.style.color = '#555';
    } else {
      const start = currentBases[r] & 0xFFFF;
      const end = start + 63;             // 32 cols × 2 tile-pair = 64 tiles
      const overflow = end >= 0x380;       // BG3 char data ends at tile $380
      rangeEl.textContent = `${fmtHex(start)}..${fmtHex(end & 0xFFFF)}` +
                            (overflow ? '  ⚠ overflows BG3 ($380+)' : '');
      rangeEl.style.color = overflow ? '#f88' : '#cfc';
    }
  }
}

async function onRowInputChange(ev) {
  const r = Number(ev.target.dataset.row);
  const v = parseHex(ev.target.value);
  if (v === null) {
    status.textContent = 'invalid hex value — keep $0000..$FFFF';
    ev.target.value = fmtHex(currentBases[r]);
    return;
  }
  currentBases[r] = v;
  applyBasesToTable();
  await pywebview.api.set_row_base(r, v);
  status.textContent = `row ${r} base = ${fmtHex(v)}`;
}

async function onDisableRow(r) {
  currentBases[r] = 0xFFFF;
  applyBasesToTable();
  await pywebview.api.disable_row(r);
  status.textContent = `row ${r} disabled`;
}

function pickNextFreeStart() {
  // Scan free ranges, skipping any 64-tile slot that overlaps an already-set row.
  const used = [];
  for (let r = 0; r < CANVAS_ROWS; r++) {
    if (!isDisabled(currentBases[r])) {
      used.push([currentBases[r], currentBases[r] + 63]);
    }
  }
  for (const fr of currentFreeRanges) {
    let probe = fr.start;
    while (probe + 63 <= fr.end) {
      const overlap = used.some(([a, b]) => probe <= b && probe + 63 >= a);
      if (!overlap) return probe;
      probe += 64;
    }
  }
  return null;
}

async function onPickFree(r) {
  const start = pickNextFreeStart();
  if (start === null) {
    status.textContent = 'no free 64-tile slot left';
    return;
  }
  currentBases[r] = start;
  applyBasesToTable();
  await pywebview.api.set_row_base(r, start);
  status.textContent = `row ${r} → ${fmtHex(start)}`;
}

function renderFreeList(ranges) {
  currentFreeRanges = ranges || [];
  if (!currentFreeRanges.length) {
    freeList.textContent = '(none ≥ 64 tiles)';
    return;
  }
  freeList.innerHTML = '';
  for (const fr of currentFreeRanges) {
    const line = document.createElement('div');
    line.textContent = `${fmtHex(fr.start)}..${fmtHex(fr.end)}  (${fr.size} tiles, ${fr.kind}-fill)`;
    freeList.appendChild(line);
  }
}

document.getElementById('btn-refresh').onclick = async () => {
  status.textContent = 'pulling Mesen state…';
  const r = await pywebview.api.refresh();
  if (r.ok) {
    canvasImg.src = r.canvas;
    bg3Img.src    = r.bg3;
    if (r.bases) { currentBases = r.bases.slice(); applyBasesToTable(); }
    renderFreeList(r.freeRanges);
    status.textContent = `snapshot refreshed (${r.positionsCount || 0} VWF tile IDs in tilemap)`;
  } else {
    status.textContent = 'refresh failed: ' + r.error;
  }
};
document.getElementById('btn-clear').onclick = async () => {
  const r = await pywebview.api.clear();
  if (r.bases) { currentBases = r.bases.slice(); applyBasesToTable(); }
  status.textContent = 'cleared (all $FFFF)';
};
document.getElementById('btn-fill').onclick = async () => {
  const r = await pywebview.api.fill();
  if (r.bases) { currentBases = r.bases.slice(); applyBasesToTable(); }
  status.textContent = 'auto-filled from first free range';
};
document.getElementById('btn-load').onclick = async () => {
  const r = await pywebview.api.load_def();
  if (r.ok) {
    if (r.bases) { currentBases = r.bases.slice(); applyBasesToTable(); }
    status.textContent = 'loaded def';
  } else {
    status.textContent = 'load failed: ' + r.error;
  }
};
document.getElementById('btn-save').onclick = async () => {
  const r = await pywebview.api.save_def();
  status.textContent = 'saved → ' + r.path;
};
document.getElementById('btn-export').onclick = async () => {
  exportBox.value = await pywebview.api.export_asm();
  exportBox.focus();
  exportBox.select();
};
document.getElementById('btn-copy').onclick = async () => {
  if (!exportBox.value) {
    exportBox.value = await pywebview.api.export_asm();
  }
  exportBox.focus();
  exportBox.select();
  let ok = false;
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(exportBox.value);
      ok = true;
    } else {
      ok = document.execCommand('copy');
    }
  } catch (e) { ok = false; }
  document.getElementById('copyStatus').textContent = ok
    ? 'copied to clipboard ✓'
    : 'copy failed — select manually and Ctrl+C';
};
paletteSel.onchange = async () => {
  const r = await pywebview.api.set_palette(Number(paletteSel.value));
  if (r.canvas) canvasImg.src = r.canvas;
};
document.getElementById('btn-apply').onclick = async () => {
  status.textContent = 'applying live (poking tile_bases, tap B, refresh)…';
  const r = await pywebview.api.apply_live();
  if (r.ok) {
    canvasImg.src = r.canvas;
    bg3Img.src    = r.bg3;
    if (r.bases) { currentBases = r.bases.slice(); applyBasesToTable(); }
    status.textContent = `live preview applied — ${r.positionsCount || 0} VWF tile IDs in tilemap`;
  } else {
    status.textContent = 'apply failed: ' + r.error;
  }
};

const opacity = document.getElementById('opacity');
const opacityVal = document.getElementById('opacityVal');
function applyOpacity() {
  const v = Number(opacity.value);
  canvasImg.style.opacity = (v / 100).toFixed(2);
  opacityVal.textContent = v + '%';
}
opacity.addEventListener('input', applyOpacity);
applyOpacity();

(async () => {
  buildRowTable();
  const st = await pywebview.api.get_state();
  sceneEl.textContent = st.scene || '(unnamed)';
  paletteSel.value = String(st.palette || 0);
  if (st.canvas) canvasImg.src = st.canvas;
  if (st.bg3)    bg3Img.src    = st.bg3;
  if (st.bases) { currentBases = st.bases.slice(); applyBasesToTable(); }
  renderFreeList(st.freeRanges);
  document.getElementById('btn-refresh').click();
})();
</script>
</body></html>
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--scene", default="file_info",
                    help="Scene tag for save/load .def filename (default: file_info)")
    args = ap.parse_args()

    api = Api(args.scene)

    win = webview.create_window(
        f"VWF Ownership Editor — {args.scene}",
        html=HTML,
        js_api=api,
        width=560,
        height=820,
        resizable=True,
    )
    webview.start()


if __name__ == "__main__":
    main()
