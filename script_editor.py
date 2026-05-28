#!/usr/bin/env python3
"""LM3 script editor with a live VWF preview + read-only reference language.

Edit the working-language `*/scripts/*.txt` translation files with a side-by-side
preview that renders each entry the way the in-game variable-width font does
(per-glyph advance from the font's widths table), and compare against the
read-only reference language (e.g. the original Japanese) rendered in its own
game font directly below.

Configurable for any language pair: see LANGUAGES / WORKING_LANG / REFERENCE_LANG
below — script folders, encoding tables and font assets are all per-language.

retrotool does the heavy lifting (this repo's source of truth):
  - `retrotool.script.table.Table` — loads each language's `.tbl`, exposes its
    value map (single- + multi-byte kanji codes) and FF control-code lengths.
  - `Table.encode_text` — text → the exact ROM byte stream, so the preview and
    its byte count match what the build inserts.

Design adapted from the rbshura `script_editor.py` (pywebview + PIL render →
base64 PNG + entry model) and this repo's `window_def.py` GUI conventions.

Run:  python3 script_editor.py [<file>.txt]
"""
from __future__ import annotations

import base64
import io
import os
import re
import sys
import tempfile
import threading
import tomllib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

os.environ.setdefault("QT_QPA_PLATFORM", os.environ.get("QT_QPA_PLATFORM", "xcb"))

from PIL import Image

from retrotool.script.table import Table
from retrotool.script.encode import encode_text as _rt_encode_text

ROOT = Path(__file__).resolve().parent

# ---------------------------------------------------------------------------
# Project config (folders + tables come from project.toml; fonts are declared
# per-language here). Edit LANGUAGES to retarget the tool or add a language.
# ---------------------------------------------------------------------------
try:
    _PT = tomllib.loads((ROOT / "project.toml").read_text(encoding="utf-8"))
except Exception:
    _PT = {}
_EN_DIR = _PT.get("en_data_dir", "en_data/scripts")
_JP_DIR = _PT.get("jp_data_dir", "jp_data/scripts")
_PRIMARY_TBL = _PT.get("rom", {}).get("primary_table", "en_data/eng.tbl")
_FALLBACK_TBL = _PT.get("rom", {}).get("fallback_table", "jp_data/jap.tbl")

# Each language profile is fully self-describing. `widths` None → fixed-width
# (advance == glyph_w). `kanji_png`/`kanji_base` enable the 2-byte kanji atlas
# (big-endian code → kanji index = code - kanji_base). `glyph_bias` accounts
# for a font sheet whose cell N holds byte (N - bias)'s glyph.
LANGUAGES: dict[str, dict] = {
    "en": {
        "label": "English",
        "scripts_dir": _EN_DIR,
        "table": _PRIMARY_TBL,
        "fallback": _FALLBACK_TBL,
        "font_png": "en_data/fonts/font_accented.png",
        "widths": "en_data/fonts/font_accented_widths.bin",
        "glyph_w": 8, "glyph_h": 16, "glyph_bias": -1,
        "kanji_png": None, "kanji_base": 0x0100,
    },
    "jp": {
        "label": "Japanese",
        "scripts_dir": _JP_DIR,
        "table": _FALLBACK_TBL,
        "fallback": None,
        "font_png": "jp_data/fonts/original_font.png",
        "widths": None,                       # fixed-width kana/ASCII
        "glyph_w": 8, "glyph_h": 16, "glyph_bias": 0,
        "kanji_png": "jp_data/fonts/kanji.png", "kanji_base": 0x0100,
        # kanji.png packs each 16x16 glyph as a 32x16 cell (2x horizontal),
        # 8 glyphs per row. Cells are downscaled to 16x16 for display.
        "kanji_cols": 8, "kanji_cell_w": 32, "kanji_cell_h": 16,
    },
}
WORKING_LANG = "en"
REFERENCE_LANG = "jp"

# ---------------------------------------------------------------------------
# Layout / appearance
# ---------------------------------------------------------------------------
ATLAS_COLS = 16
KANJI_DIM = 16
KANJI_COLS = 16
DEFAULT_COLS = 28           # in-game dialog text area width (docs/vwf_research.md)
SCALE = 3
LINE_LEAD = 2               # px between rows

COL_BG = (12, 14, 28)
COL_BOX = (28, 34, 66)
COL_BORDER = (90, 110, 160)
COL_TEXT = (240, 242, 248)
COL_BOX_REF = (40, 30, 30)   # reference box tinted differently
COL_BORDER_REF = (150, 110, 110)

B_END, B_NL, B_FF = 0x00, 0x90, 0xFF

ENTRY_HEADER_RE = re.compile(r"<<\$([0-9A-Fa-f]+):(\d+)(?:\[\$[0-9A-Fa-f]+\]|\.\w+)?>>")
HEADER_SPLIT_RE = re.compile(r"(<<\$[0-9A-Fa-f]+:\d+(?:\[\$[0-9A-Fa-f]+\]|\.\w+)?>>)")
WINDOW_MARKER_RE = re.compile(r"^\s*<<<.*?>>>\s*$", re.MULTILINE)


# ===========================================================================
# Atlas helpers
# ===========================================================================
def _atlas_from_png(path: Path, text_rgb) -> Image.Image:
    """Load a monochrome font sheet (any mode/polarity) and rebuild it as an
    RGBA atlas: `text_rgb` on the glyph ink, transparent on the background.
    Polarity is auto-detected — kana sheets are dark-on-light, kanji.png is
    light-on-dark — so the majority value is treated as background."""
    src = Image.open(path).convert("L")
    h = src.histogram()
    ink_is_light = sum(h[:128]) > sum(h[128:])   # majority dark → glyphs are light
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    sp, op = src.load(), out.load()
    tr = (text_rgb[0], text_rgb[1], text_rgb[2], 255)
    for y in range(src.height):
        for x in range(src.width):
            is_ink = (sp[x, y] >= 128) if ink_is_light else (sp[x, y] < 128)
            if is_ink:
                op[x, y] = tr
    return out


# ===========================================================================
# Language profile — table + fonts + render, all retrotool-driven
# ===========================================================================
@dataclass
class LangProfile:
    key: str
    label: str
    scripts_dir: Path
    table: Table
    fallback: Optional[Table]
    atlas: Image.Image
    glyph_w: int
    glyph_h: int
    glyph_bias: int
    widths: Optional[list]                 # None == fixed-width
    kanji_atlas: Optional[Image.Image]
    kanji_base: int
    kanji_leads: set                        # high bytes that begin a 2-byte code
    kanji_cols: int = 16                    # glyph cells per row in kanji sheet
    kanji_cell_w: int = KANJI_DIM           # px per cell (may be >16 if stretched)
    kanji_cell_h: int = KANJI_DIM
    ctrl: dict = field(default_factory=dict)

    @classmethod
    def load(cls, key: str, cfg: dict) -> "LangProfile":
        tbl = Table(str(ROOT / cfg["table"]))
        fb = Table(str(ROOT / cfg["fallback"])) if cfg.get("fallback") else None
        atlas = _atlas_from_png(ROOT / cfg["font_png"], COL_TEXT)
        widths = None
        if cfg.get("widths"):
            widths = list((ROOT / cfg["widths"]).read_bytes())
        kanji_atlas = None
        if cfg.get("kanji_png"):
            kanji_atlas = _atlas_from_png(ROOT / cfg["kanji_png"], COL_TEXT)
        # Kanji lead bytes = high byte of genuine 2-byte codes (0x0100..0xFEFF);
        # excludes the 0xFF-prefixed control sequences and any 3-byte values.
        vmap = tbl.val_map
        leads = {k >> 8 for k in vmap if 0x0100 <= k <= 0xFEFF}
        return cls(
            key=key, label=cfg["label"], scripts_dir=ROOT / cfg["scripts_dir"],
            table=tbl, fallback=fb, atlas=atlas,
            glyph_w=cfg["glyph_w"], glyph_h=cfg["glyph_h"], glyph_bias=cfg["glyph_bias"],
            widths=widths, kanji_atlas=kanji_atlas, kanji_base=cfg.get("kanji_base", 0x0100),
            kanji_leads=leads,
            kanji_cols=int(cfg.get("kanji_cols", 16)),
            kanji_cell_w=int(cfg.get("kanji_cell_w", KANJI_DIM)),
            kanji_cell_h=int(cfg.get("kanji_cell_h", KANJI_DIM)),
            ctrl=dict(getattr(tbl, "ctrl_lengths", {}) or {}),
        )

    # ---- text → bytes (the real build encoder) --------------------------
    def encode(self, body: str) -> tuple[bytes, Optional[str]]:
        text = WINDOW_MARKER_RE.sub("", body)
        try:
            enc, _fixups, _labels = _rt_encode_text(text, self.table,
                                                    fallback_table=self.fallback)
            return bytes(enc), None
        except Exception as e:
            return b"", f"{type(e).__name__}: {e}"

    # ---- byte stream → pages of glyphs ----------------------------------
    def layout(self, enc: bytes, cols_px: int):
        """Walk the stream into pages → lines → glyphs. A glyph is
        (is_kanji, cell_index, advance_px). 0x00 ends, 0x90 newlines, FF FF is
        a page break ([cls]), other FF codes skip their @ctrl length, kanji
        lead bytes consume 2 bytes, everything else is one font glyph."""
        pages = [[[]]]
        i, n = 0, len(enc)
        while i < n:
            b = enc[i]
            if b == B_END:
                break
            if b == B_NL:
                pages[-1].append([]); i += 1; continue
            if b == B_FF:
                cmd = enc[i + 1] if i + 1 < n else 0
                length = self.ctrl.get(cmd)
                if length is None:
                    length = 3 if cmd == 0xFF else 2
                if cmd == 0xFF:
                    pages.append([[]])
                i += max(length, 1); continue
            if b in self.kanji_leads and self.kanji_atlas is not None and i + 1 < n:
                code = (b << 8) | enc[i + 1]
                pages[-1][-1].append((True, code - self.kanji_base, KANJI_DIM))
                i += 2; continue
            adv = self.widths[b] if (self.widths and b < len(self.widths)) else self.glyph_w
            if adv <= 0:
                adv = self.glyph_w
            pages[-1][-1].append((False, b, adv))
            i += 1
        wrapped = []
        for page in pages:
            wp = []
            for line in page:
                wp.extend(_wrap(line, cols_px) if line else [[]])
            wrapped.append(wp)
        return wrapped

    # ---- render to PNG bytes --------------------------------------------
    def render_png(self, enc: bytes, cols: int, box_rgb, border_rgb) -> bytes:
        cols_px = cols * self.glyph_w
        pages = self.layout(enc, cols_px)
        row_h = self.glyph_h + LINE_LEAD
        pad, gap = 10, 10
        page_imgs = []
        for lines in pages:
            rows = max(1, len(lines))
            bw, bh = cols_px + pad * 2, rows * row_h + pad * 2
            img = Image.new("RGB", (bw, bh), box_rgb)
            for x in range(bw):
                img.putpixel((x, 0), border_rgb); img.putpixel((x, bh - 1), border_rgb)
            for y in range(bh):
                img.putpixel((0, y), border_rgb); img.putpixel((bw - 1, y), border_rgb)
            y = pad
            for line in lines:
                x = pad
                for is_kanji, idx, adv in line:
                    if is_kanji and self.kanji_atlas is not None:
                        cw, ch, cols_k = self.kanji_cell_w, self.kanji_cell_h, self.kanji_cols
                        cells = (self.kanji_atlas.width // cw) * (self.kanji_atlas.height // ch)
                        if 0 <= idx < cells:
                            ax = (idx % cols_k) * cw
                            ay = (idx // cols_k) * ch
                            g = self.kanji_atlas.crop((ax, ay, ax + cw, ay + ch))
                            if (cw, ch) != (KANJI_DIM, KANJI_DIM):
                                g = g.resize((KANJI_DIM, KANJI_DIM), Image.Resampling.NEAREST)
                            img.paste(g, (x, y), g)
                    else:
                        gi = idx + self.glyph_bias
                        cells = (self.atlas.width // self.glyph_w) * (self.atlas.height // self.glyph_h)
                        if 0 <= gi < cells:
                            ax = (gi % ATLAS_COLS) * self.glyph_w
                            ay = (gi // ATLAS_COLS) * self.glyph_h
                            g = self.atlas.crop((ax, ay, ax + self.glyph_w, ay + self.glyph_h))
                            img.paste(g, (x, y), g)
                    x += adv
                y += row_h
            page_imgs.append(img)
        full_w = max(im.width for im in page_imgs)
        full_h = sum(im.height for im in page_imgs) + gap * (len(page_imgs) - 1)
        canvas = Image.new("RGB", (full_w, full_h), COL_BG)
        yy = 0
        for im in page_imgs:
            canvas.paste(im, (0, yy)); yy += im.height + gap
        if SCALE != 1:
            canvas = canvas.resize((canvas.width * SCALE, canvas.height * SCALE),
                                   Image.Resampling.NEAREST)
        buf = io.BytesIO(); canvas.save(buf, format="PNG")
        return buf.getvalue()


def _wrap(glyphs, cols_px):
    """Pixel word-wrap a run of (is_kanji, idx, adv) glyphs, breaking at spaces."""
    lines = [[]]
    width, last_space = 0, -1
    for g in glyphs:
        cur = lines[-1]
        if width + g[2] > cols_px and cur:
            if 0 <= last_space < len(cur) - 1:
                carry = cur[last_space + 1:]; del cur[last_space:]
                lines.append(carry); width = sum(x[2] for x in carry)
            else:
                lines.append([]); width = 0
            last_space = -1
        cur = lines[-1]
        if not g[0] and g[1] == 0x20:
            last_space = len(cur)
        cur.append(g); width += g[2]
    return lines


# ===========================================================================
# Script-file model
# ===========================================================================
def _detect_encoding(raw: bytes) -> str:
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return "utf-16"
    if raw[:3] == b"\xef\xbb\xbf":
        return "utf-8-sig"
    return "utf-8"


class ScriptFile:
    def __init__(self, path: Path):
        self.path = path
        self.encoding = "utf-8"
        self.entries: list[dict] = []
        self.reload()

    def reload(self) -> None:
        raw = self.path.read_bytes()
        self.encoding = _detect_encoding(raw)
        dec = "utf-8-sig" if self.encoding == "utf-8-sig" else self.encoding
        text = raw.decode(dec, errors="replace").lstrip("﻿")
        self.entries = []
        parts = HEADER_SPLIT_RE.split(text)
        for k in range(1, len(parts), 2):
            header = parts[k]
            body = parts[k + 1] if k + 1 < len(parts) else ""
            if body.startswith("\n"):
                body = body[1:]
            body = body.rstrip("\n")
            m = ENTRY_HEADER_RE.match(header)
            idx = int(m.group(2)) if m else k // 2
            self.entries.append({
                # Match the reference by entry index only: files correspond by
                # name (one table each), and the header's table-id is formatted
                # inconsistently across languages (EN hex $13100 vs JP decimal
                # $78080 == 0x13100), so it's not a reliable join key.
                "header": header, "key": idx, "idx": idx, "body": body,
            })

    def by_key(self) -> dict:
        return {e["key"]: e for e in self.entries}

    def save_entry(self, pos: int, new_body: str) -> None:
        self.entries[pos]["body"] = new_body
        content = "".join(f"{e['header']}\n{e['body']}\n" for e in self.entries)
        enc = "utf-16" if self.encoding == "utf-16" else (
            "utf-8-sig" if self.encoding == "utf-8-sig" else "utf-8")
        fd, tmp = tempfile.mkstemp(dir=str(self.path.parent),
                                   prefix=f".{self.path.name}.", suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding=enc, newline="\n") as f:
                f.write(content)
            os.replace(tmp, self.path)
        except Exception:
            try:
                os.unlink(tmp)
            except FileNotFoundError:
                pass
            raise


# ===========================================================================
# pywebview API bridge
# ===========================================================================
STATE_PATH = ROOT / ".script-editor-state.json"
_OVERRIDE_KEYS = ("scripts_dir", "table", "fallback", "font_png", "widths", "kanji_png")
_TRANSLATED_RE = re.compile(r"[A-Za-z]{2,}")


class Api:
    def __init__(self):
        st = self._read_state()
        self.working_lang = st.get("working_lang", WORKING_LANG)
        self.reference_lang = st.get("reference_lang", REFERENCE_LANG)
        self.overrides: dict = st.get("overrides", {})
        self.last: dict = st.get("last", {})
        self.work: Optional[LangProfile] = None
        self.ref: Optional[LangProfile] = None
        self.file: Optional[ScriptFile] = None
        self.ref_file: Optional[ScriptFile] = None
        self._cache: dict = {}            # filename -> ScriptFile (working side, for search)
        self._window = None
        # ---- background auto-save queue (debounced; badge polls state) ----
        self._save_timer: Optional[threading.Timer] = None
        self._save_lock = threading.Lock()
        self._pending: dict = {}          # entry pos -> body
        self._save_state = "idle"
        self._save_error: Optional[str] = None
        self._save_seq = 0
        self._build_profiles()

    # ---- config / profiles ----------------------------------------------
    def _eff_cfg(self, lang: str) -> dict:
        cfg = dict(LANGUAGES.get(lang, {}))
        cfg.update({k: v for k, v in self.overrides.get(lang, {}).items() if v})
        return cfg

    def _build_profiles(self) -> None:
        self.work = LangProfile.load(self.working_lang, self._eff_cfg(self.working_lang))
        self.ref = None
        if self.reference_lang and self.reference_lang in LANGUAGES:
            try:
                self.ref = LangProfile.load(self.reference_lang, self._eff_cfg(self.reference_lang))
            except Exception as e:
                print(f"reference '{self.reference_lang}' unavailable: {e}", file=sys.stderr)
        self._cache.clear()

    # ---- state persistence (atomic JSON) --------------------------------
    @staticmethod
    def _read_state() -> dict:
        try:
            import json
            return json.loads(STATE_PATH.read_text(encoding="utf-8"))
        except Exception:
            return {}

    def _write_state(self) -> None:
        import json
        payload = {"working_lang": self.working_lang, "reference_lang": self.reference_lang,
                   "overrides": self.overrides, "last": self.last}
        try:
            fd, tmp = tempfile.mkstemp(dir=str(ROOT), prefix=".se-state.", suffix=".tmp")
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(payload, f, indent=2)
            os.replace(tmp, STATE_PATH)
        except Exception:
            pass

    def save_state(self, file: str = "", pos: int = -1, cols: int = DEFAULT_COLS,
                   cursor: int = 0, scroll: int = 0) -> None:
        self.last = {"file": file, "pos": int(pos), "cols": int(cols),
                     "cursor": int(cursor), "scroll": int(scroll)}
        self._write_state()

    def load_state(self) -> dict:
        return dict(self.last)

    # ---- language labels / settings -------------------------------------
    def langs(self) -> dict:
        return {"work": self.work.label, "ref": self.ref.label if self.ref else None}

    def settings(self) -> dict:
        out = {"working_lang": self.working_lang, "reference_lang": self.reference_lang,
               "languages": {}}
        for k in LANGUAGES:
            cfg = self._eff_cfg(k)
            sd = (ROOT / cfg["scripts_dir"]) if cfg.get("scripts_dir") else None
            fp = (ROOT / cfg["font_png"]) if cfg.get("font_png") else None
            out["languages"][k] = {
                "label": cfg.get("label", k),
                "scripts_dir": cfg.get("scripts_dir", ""),
                "table": cfg.get("table", ""),
                "fallback": cfg.get("fallback") or "",
                "font_png": cfg.get("font_png", ""),
                "widths": cfg.get("widths") or "",
                "kanji_png": cfg.get("kanji_png") or "",
                "dir_exists": bool(sd and sd.exists()),
                "font_exists": bool(fp and fp.exists()),
            }
        return out

    def apply_settings(self, working_lang: str, reference_lang: str,
                       overrides: Optional[dict] = None) -> dict:
        try:
            if overrides:
                for lang, ov in overrides.items():
                    self.overrides.setdefault(lang, {})
                    for k in _OVERRIDE_KEYS:
                        if k in ov:
                            self.overrides[lang][k] = ov[k].strip() if isinstance(ov[k], str) else ov[k]
            self.working_lang = working_lang or self.working_lang
            self.reference_lang = reference_lang or ""
            self._build_profiles()
            self._write_state()
            return {"ok": True, "files": self.list_files(), "langs": self.langs()}
        except Exception as e:
            return {"ok": False, "error": f"{type(e).__name__}: {e}"}

    def pick_path(self, kind: str = "folder", initial: str = "") -> Optional[str]:
        """Native folder/file picker for the settings modal."""
        try:
            import webview
        except ImportError:
            return None
        if not webview.windows:
            return None
        win = webview.windows[0]
        start = initial or str(ROOT)
        if start and not Path(start).is_absolute():
            start = str(ROOT / start)
        dlg = webview.FOLDER_DIALOG if kind == "folder" else webview.OPEN_DIALOG
        try:
            res = win.create_file_dialog(dlg, directory=start or str(ROOT),
                                         allow_multiple=False)
        except Exception:
            return None
        if not res:
            return None
        chosen = res[0] if isinstance(res, (list, tuple)) else res
        # Store relative to the project root when possible (keeps state portable).
        try:
            return str(Path(chosen).resolve().relative_to(ROOT))
        except ValueError:
            return str(chosen)

    # ---- files / entries ------------------------------------------------
    def list_files(self) -> list[str]:
        return sorted(p.name for p in self.work.scripts_dir.glob("*.txt"))

    def _work_file(self, name: str) -> ScriptFile:
        sf = self._cache.get(name)
        if sf is None:
            sf = ScriptFile(self.work.scripts_dir / name)
            self._cache[name] = sf
        return sf

    def open_file(self, name: str) -> dict:
        self.file = ScriptFile(self.work.scripts_dir / name)
        self._cache[name] = self.file
        self.ref_file = None
        if self.ref:
            rp = self.ref.scripts_dir / name
            if rp.exists():
                self.ref_file = ScriptFile(rp)
        return {
            "name": name,
            "encoding": self.file.encoding,
            "has_ref": self.ref_file is not None,
            "entries": [{"idx": e["idx"], "preview": self._one_line(e["body"]),
                         "tr": bool(_TRANSLATED_RE.search(e["body"]))}
                        for e in self.file.entries],
        }

    @staticmethod
    def _one_line(body: str) -> str:
        s = WINDOW_MARKER_RE.sub("", body)
        return re.sub(r"\s+", " ", s).strip()[:48]

    def get_entry(self, pos: int) -> dict:
        e = self.file.entries[pos]
        return {"idx": e["idx"], "header": e["header"], "body": e["body"]}

    def render(self, body: str, cols: int = DEFAULT_COLS) -> dict:
        enc, err = self.work.encode(body)
        png = self.work.render_png(enc, int(cols), COL_BOX, COL_BORDER)
        return {"png": "data:image/png;base64," + base64.b64encode(png).decode(),
                "bytes": len(enc), "error": err}

    def get_reference(self, pos: int, cols: int = DEFAULT_COLS) -> dict:
        """Read-only reference entry for the current working entry, matched by
        index. Returns rendered PNG (reference font) + raw text."""
        if not (self.ref and self.ref_file):
            return {"found": False}
        key = self.file.entries[pos]["key"]
        ref_e = self.ref_file.by_key().get(key)
        if ref_e is None:
            return {"found": False}
        enc, err = self.ref.encode(ref_e["body"])
        png = self.ref.render_png(enc, int(cols), COL_BOX_REF, COL_BORDER_REF)
        return {"found": True,
                "png": "data:image/png;base64," + base64.b64encode(png).decode(),
                "text": ref_e["body"], "bytes": len(enc), "error": err,
                "label": self.ref.label}

    # ---- cross-file search ----------------------------------------------
    def search(self, query: str, case: bool = False, regex: bool = False,
               side: str = "work") -> dict:
        """Search every file's entry bodies (working side by default, or the
        reference side). Returns up to 400 hits with context."""
        if not query:
            return {"matches": [], "truncated": False, "error": None}
        try:
            pat = re.compile(query if regex else re.escape(query),
                             0 if case else re.IGNORECASE)
        except re.error as e:
            return {"matches": [], "truncated": False, "error": str(e)}
        prof = self.ref if (side == "ref" and self.ref) else self.work
        if prof is None:
            return {"matches": [], "truncated": False, "error": "no reference language"}
        matches: list = []
        for name in sorted(p.name for p in prof.scripts_dir.glob("*.txt")):
            try:
                sf = self._work_file(name) if prof is self.work else ScriptFile(prof.scripts_dir / name)
            except Exception:
                continue
            for pos, e in enumerate(sf.entries):
                body = e["body"]
                for m in pat.finditer(body):
                    s, en = m.span()
                    matches.append({"file": name, "pos": pos, "idx": e["idx"],
                                    "start": s, "end": en,
                                    "before": body[max(0, s - 22):s],
                                    "match": body[s:en],
                                    "after": body[en:en + 22]})
                    if len(matches) >= 400:
                        return {"matches": matches, "truncated": True, "error": None}
        return {"matches": matches, "truncated": False, "error": None}

    # ---- auto-save: debounced background write + polled status badge ----
    def queue_save(self, pos: int, body: str) -> None:
        """Queue an edit; a 0.4s background Timer coalesces rapid edits into a
        single file write. JS polls get_save_state() to drive the badge."""
        with self._save_lock:
            self._pending[int(pos)] = body
            self._save_state = "queued"
            self._save_error = None
            if self._save_timer is not None:
                self._save_timer.cancel()
            self._save_timer = threading.Timer(0.4, self._flush_pending)
            self._save_timer.daemon = True
            self._save_timer.start()

    def _flush_pending(self) -> None:
        with self._save_lock:
            pending = dict(self._pending)
            self._pending.clear()
            self._save_timer = None
            if not pending or self.file is None:
                self._save_state = "idle"
                return
            self._save_state = "saving"
        try:
            for pos, body in pending.items():
                if 0 <= pos < len(self.file.entries):
                    self.file.entries[pos]["body"] = body
            last = max(pending)
            self.file.save_entry(last, pending[last])     # one atomic file write
            self._cache.pop(self.file.path.name, None)     # invalidate search cache
        except Exception as exc:
            with self._save_lock:
                self._save_state = "error"
                self._save_error = f"{type(exc).__name__}: {exc}"
                self._save_seq += 1
            return
        with self._save_lock:
            self._save_state = "saved"
            self._save_seq += 1

    def flush_now(self) -> dict:
        """Force any pending edit to disk immediately (Ctrl+S / window close)."""
        with self._save_lock:
            if self._save_timer is not None:
                self._save_timer.cancel()
                self._save_timer = None
            has_pending = bool(self._pending)
        if has_pending:
            self._flush_pending()
        return self.get_save_state()

    def get_save_state(self) -> dict:
        with self._save_lock:
            return {"state": self._save_state, "error": self._save_error, "seq": self._save_seq}


# ===========================================================================
# HTML / JS frontend
# ===========================================================================
def build_html() -> str:
    return r"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>LM3 Script Editor</title>
<style>
  :root { --bg:#14161f; --panel:#1d2130; --line:#2a3150; --txt:#e6e9f2; --fg2:#8893b5; --accent:#7aa2ff; --warn:#ff6b6b; --ok:#67e08a; }
  * { box-sizing:border-box; }
  body { margin:0; font:13px/1.4 ui-monospace,Menlo,Consolas,monospace; background:var(--bg); color:var(--txt); height:100vh; display:flex; flex-direction:column; }
  header { display:flex; gap:8px; align-items:center; padding:8px 12px; background:var(--panel); border-bottom:1px solid var(--line); }
  select, button, input[type=text] { background:#0e1018; color:var(--txt); border:1px solid var(--line); border-radius:6px; padding:5px 9px; font:inherit; }
  button { cursor:pointer; } button:hover { border-color:var(--accent); }
  button.act { background:#243056; border-color:var(--accent); }
  label { color:var(--fg2); }
  /* find bar */
  #findbar { display:none; gap:6px; align-items:center; padding:7px 12px; background:#161a2a; border-bottom:1px solid var(--line); }
  #findbar.open { display:flex; }
  #findbar input { padding:4px 8px; } #findbar .mini { padding:4px 8px; min-width:30px; }
  #findcount { color:var(--fg2); }
  #main { flex:1; display:flex; min-height:0; }
  #entries { width:240px; border-right:1px solid var(--line); overflow:auto; background:#11131b; }
  .ent { padding:6px 10px; border-bottom:1px solid #1a1d28; cursor:pointer; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .ent:hover { background:#1a1e2c; } .ent.sel { background:#243056; }
  .ent .n { color:var(--accent); margin-right:6px; }
  .ent .dot { display:inline-block; width:6px; height:6px; border-radius:50%; margin-right:6px; background:#39405a; vertical-align:middle; }
  .ent.tr .dot { background:var(--ok); }
  /* two comparison columns: each = preview (top) + text (bottom) */
  .col { flex:1; min-width:0; display:flex; flex-direction:column; border-right:1px solid var(--line); }
  .col.ref { border-right:0; background:#0c0a0a; }
  .colhead { padding:7px 12px; font-size:11px; letter-spacing:.08em; text-transform:uppercase; color:var(--fg2); font-weight:600; border-bottom:1px solid var(--line); display:flex; gap:10px; align-items:center; }
  .colhead .tag { color:var(--accent); } .col.ref .colhead .tag { color:var(--warn); }
  .colhead .sp { flex:1; }
  .pvbox { flex:1 1 50%; overflow:auto; padding:12px 14px; background:#0c0e16; }
  .col.ref .pvbox { background:#0c0a0a; }
  img.pv { image-rendering:pixelated; display:block; max-width:100%; }
  #hdr { padding:5px 12px; color:var(--fg2); border-top:1px solid var(--line); border-bottom:1px solid var(--line); display:flex; gap:10px; align-items:center; font-size:11px; }
  #hdr #curhdr { flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
  #ta { flex:1 1 50%; resize:none; border:0; background:#0e1018; color:var(--txt); padding:12px; font:14px/1.55 ui-monospace,monospace; outline:none; }
  #reftext { flex:1 1 50%; resize:none; border:0; border-top:1px solid var(--line); background:#0c0a0a; color:#d9c9c9; padding:12px; font:14px/1.7 ui-monospace,monospace; outline:none; }
  /* the read-only reference is a textarea so its text is always selectable/copyable */
  textarea, #reftext { user-select:text; -webkit-user-select:text; }
  .err { color:var(--warn); } .ok { color:var(--ok); }
  .pill { background:#0e1018; border:1px solid var(--line); border-radius:10px; padding:2px 8px; }
  .savebadge { display:inline-flex; align-items:center; gap:6px; border:1px solid var(--line); border-radius:999px; padding:2px 10px; font-size:11px; }
  .savebadge .bdot { width:8px; height:8px; border-radius:50%; background:var(--fg2); }
  .savebadge.idle  { color:var(--fg2); } .savebadge.idle  .bdot { background:var(--fg2); }
  .savebadge.dirty { color:#f0c040; border-color:#f0c040; } .savebadge.dirty .bdot { background:#f0c040; }
  .savebadge.saving{ color:#66a8ff; border-color:#66a8ff; } .savebadge.saving .bdot { background:#66a8ff; animation:pulse 1s infinite; }
  .savebadge.saved { color:var(--ok); border-color:var(--ok); } .savebadge.saved .bdot { background:var(--ok); }
  .savebadge.error { color:var(--warn); border-color:var(--warn); } .savebadge.error .bdot { background:var(--warn); }
  @keyframes pulse { 0%,100%{opacity:1;} 50%{opacity:.35;} }
  /* search results */
  #results { display:none; position:absolute; left:248px; right:12px; top:96px; max-height:50vh; overflow:auto; background:#0e1224; border:1px solid var(--line); border-radius:8px; box-shadow:0 12px 40px rgba(0,0,0,.6); z-index:30; }
  #results.open { display:block; }
  .hit { padding:7px 11px; border-bottom:1px solid #1a1d2e; cursor:pointer; }
  .hit:hover { background:#1a2138; }
  .hit .where { color:var(--accent); font-size:11px; } .hit .ctx { color:var(--fg2); font-size:12px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .hit .ctx b { color:#f0c040; background:rgba(240,192,64,.16); }
  /* settings modal */
  #modalbg { display:none; position:fixed; inset:0; background:rgba(0,0,0,.6); z-index:50; align-items:center; justify-content:center; }
  #modalbg.open { display:flex; }
  .modal { width:560px; max-height:88vh; overflow:auto; background:var(--panel); border:1px solid var(--line); border-radius:10px; padding:18px 20px; }
  .modal h3 { margin:0 0 4px; color:var(--accent); } .modal h4 { margin:16px 0 6px; color:var(--txt); font-size:12px; }
  .modal .row { margin:8px 0; } .modal label { display:block; font-size:11px; margin-bottom:3px; }
  .modal .fld { display:flex; gap:6px; } .modal .fld input { flex:1; }
  .modal .meta { color:var(--fg2); font-size:10px; margin-top:2px; }
  .modal .actions { margin-top:16px; display:flex; gap:8px; justify-content:flex-end; }
  .modal .actions .primary { background:var(--accent); border-color:var(--accent); color:#0a0c14; }
</style></head>
<body>
  <header>
    <label>File</label><select id="file"></select>
    <label>Width</label><select id="cols"></select>
    <span style="flex:1"></span>
    <span class="pill" id="enc">—</span>
    <span class="pill" id="bytes">0 B</span>
    <span class="savebadge idle" id="badge"><span class="bdot"></span><span id="badgelbl">idle</span></span>
    <button id="findbtn" title="Find (Ctrl+F)">🔍 Find</button>
    <button id="setbtn" title="Settings">⚙ Settings</button>
    <button id="save" title="Force save (Ctrl+S)">Save</button>
  </header>
  <div id="findbar">
    <input id="findq" type="text" placeholder="Find across all files…" style="width:280px">
    <input id="findr" type="text" placeholder="Replace…" style="width:160px">
    <button class="mini" id="fcase" title="Case sensitive">Aa</button>
    <button class="mini" id="fregex" title="Regex">.*</button>
    <select id="fside" title="Search side"><option value="work">Working</option><option value="ref">Reference</option></select>
    <button class="mini" id="fprev" title="Prev (Shift+Enter)">◀</button>
    <button class="mini" id="fnext" title="Next (Enter)">▶</button>
    <button id="frep" title="Replace current selection">Replace</button>
    <span id="findcount"></span>
  </div>
  <div id="main">
    <div id="entries"></div>
    <div class="col" id="encol">
      <div class="colhead"><span class="tag" id="worklabel">Working</span> preview<span class="sp"></span><span id="msg"></span></div>
      <div class="pvbox"><img id="pv" class="pv"></div>
      <div id="hdr"><span id="curhdr">—</span></div>
      <textarea id="ta" spellcheck="false" placeholder="Select an entry…"></textarea>
    </div>
    <div class="col ref" id="jpcol">
      <div class="colhead"><span class="tag" id="reflabel">Reference</span> · read-only</div>
      <div class="pvbox"><img id="refpv" class="pv"></div>
      <textarea id="reftext" readonly spellcheck="false" placeholder="reference source"></textarea>
    </div>
  </div>
  <div id="results"></div>

  <div id="modalbg"><div class="modal">
    <h3>Settings</h3>
    <div class="meta">Folders, encoding tables and font sheets per language. Paths are relative to the project root.</div>
    <h4>Working language</h4>
    <div class="row"><label>Language</label><select id="s-work-lang" style="width:100%"></select></div>
    <div id="s-work-fields"></div>
    <h4>Reference language (read-only)</h4>
    <div class="row"><label>Language</label><select id="s-ref-lang" style="width:100%"></select></div>
    <div id="s-ref-fields"></div>
    <div class="actions"><button onclick="closeSettings()">Cancel</button>
      <button class="primary" onclick="saveSettings()">Save &amp; reload</button></div>
  </div></div>

<script>
let curPos=-1, savedBody="", curFile="";
let FIND={case:false,regex:false}, RESULTS=[], RINDEX=-1;
let SETCFG=null;
const $=id=>document.getElementById(id);
function debounce(fn,ms){let t;return(...a)=>{clearTimeout(t);t=setTimeout(()=>fn(...a),ms);};}
function esc(s){return s.replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));}
function cols(){return +$('cols').value;}

async function init(){
  const L=await pywebview.api.langs();
  $('worklabel').textContent=L.work; $('reflabel').textContent=L.ref||'Reference';
  const st=await pywebview.api.load_state();
  [20,24,26,28,30,32].forEach(c=>{const o=document.createElement('option');o.value=c;o.textContent=c+' cols';$('cols').appendChild(o);});
  $('cols').value=st.cols||28;
  const files=await pywebview.api.list_files();
  files.forEach(f=>{const o=document.createElement('option');o.value=f;o.textContent=f;$('file').appendChild(o);});
  $('file').onchange=()=>openFile($('file').value);
  $('cols').onchange=()=>{renderPreview();renderRef();bumpState();};
  $('ta').addEventListener('input',()=>{setBadge('dirty','editing…');bumpState();schedRender();});
  $('ta').addEventListener('keyup',bumpState); $('ta').addEventListener('click',bumpState);
  $('save').onclick=manualSave;
  $('findbtn').onclick=toggleFind; $('setbtn').onclick=openSettings;
  $('fcase').onclick=()=>tflag('case','fcase'); $('fregex').onclick=()=>tflag('regex','fregex');
  $('fside').onchange=runSearch; $('fprev').onclick=findPrev; $('fnext').onclick=findNext; $('frep').onclick=replaceOne;
  $('findq').addEventListener('input',debounce(runSearch,200));
  $('findq').addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();e.shiftKey?findPrev():findNext();}if(e.key==='Escape')toggleFind();});
  document.addEventListener('keydown',e=>{
    if((e.ctrlKey||e.metaKey)&&e.key==='s'){e.preventDefault();manualSave();}
    if((e.ctrlKey||e.metaKey)&&e.key==='f'){e.preventDefault();if(!$('findbar').classList.contains('open'))toggleFind();else $('findq').focus();}
  });
  document.addEventListener('mousedown',e=>{
    if(!$('results').classList.contains('open'))return;
    if($('results').contains(e.target)||$('findbar').contains(e.target)||e.target===$('findbtn'))return;
    $('results').classList.remove('open');
  });
  const want=(files.includes(st.file)?st.file:files[0]);
  if(want){$('file').value=want; await openFile(want, st);}
}
async function openFile(name, restore){
  curFile=name;
  const d=await pywebview.api.open_file(name);
  $('enc').textContent=d.encoding+(d.has_ref?'':' · no ref');
  const list=$('entries');list.innerHTML='';
  d.entries.forEach((e,pos)=>{const el=document.createElement('div');el.className='ent'+(e.tr?' tr':'');el.dataset.pos=pos;
    el.innerHTML=`<span class="dot"></span><span class="n">${e.idx}</span>${esc(e.preview||'(empty)')}`;el.onclick=()=>selectEntry(pos);list.appendChild(el);});
  curPos=-1;$('ta').value='';$('curhdr').textContent='—';
  const pos=(restore&&typeof restore.pos==='number'&&restore.pos<d.entries.length)?restore.pos:0;
  if(d.entries.length){await selectEntry(pos,true);
    if(restore&&restore.cursor){try{$('ta').setSelectionRange(restore.cursor,restore.cursor);}catch(e){}}
    const sel=document.querySelector(`.ent[data-pos="${pos}"]`); if(sel)sel.scrollIntoView({block:'center'});}
}
async function selectEntry(pos, force){
  // Auto-save flushes the current entry before switching (no discard prompt).
  if(curPos>=0&&curPos!==pos){
    if($('ta').value!==savedBody) pywebview.api.queue_save(curPos,$('ta').value);
    await pywebview.api.flush_now();
  }
  curPos=pos;
  document.querySelectorAll('.ent').forEach(el=>el.classList.toggle('sel',+el.dataset.pos===pos));
  const e=await pywebview.api.get_entry(pos);
  $('curhdr').textContent=e.header;$('ta').value=e.body;savedBody=e.body;
  setBadge('idle','idle');
  renderPreview();renderRef();bumpState();
}
async function renderPreview(){
  const r=await pywebview.api.render($('ta').value,cols());
  $('pv').src=r.png;$('bytes').textContent=r.bytes+' B';
  $('msg').className=r.error?'err':'';$('msg').textContent=r.error?('⚠ '+r.error):'';
}
async function renderRef(){
  if(curPos<0)return;
  const r=await pywebview.api.get_reference(curPos,cols());
  if(!r.found){$('refpv').src='';$('reftext').value='(no matching reference entry)';return;}
  $('refpv').src=r.png;$('reftext').value=r.text||'';
}
/* ---- auto-save + status badge (polls get_save_state) ---- */
let SAVE_POLL=null, LAST_SEQ=0, FADE=null;
function setBadge(cls,txt){const b=$('badge');if(!b)return;b.className='savebadge '+cls;$('badgelbl').textContent=txt;}
function startSavePolling(){
  if(SAVE_POLL)return;
  SAVE_POLL=setInterval(async()=>{
    try{
      const s=await pywebview.api.get_save_state();
      if(s.state==='queued'||s.state==='saving'){setBadge('saving','saving…');}
      else if(s.state==='saved'&&s.seq!==LAST_SEQ){LAST_SEQ=s.seq;setBadge('saved','saved ✓');
        clearInterval(SAVE_POLL);SAVE_POLL=null;if(FADE)clearTimeout(FADE);FADE=setTimeout(()=>setBadge('idle','idle'),2500);}
      else if(s.state==='error'){setBadge('error','save failed');clearInterval(SAVE_POLL);SAVE_POLL=null;}
    }catch(e){}
  },120);
}
function autoSave(){
  if(curPos<0)return;
  pywebview.api.queue_save(curPos,$('ta').value);
  savedBody=$('ta').value;
  const el=document.querySelector(`.ent[data-pos="${curPos}"]`); if(el)el.classList.toggle('tr',/[A-Za-z]{2,}/.test($('ta').value));
  startSavePolling();
}
async function manualSave(){
  if(curPos<0)return;
  pywebview.api.queue_save(curPos,$('ta').value); savedBody=$('ta').value;
  await pywebview.api.flush_now(); startSavePolling();
}
const schedRender=debounce(()=>{renderPreview();autoSave();},200);
const bumpState=debounce(()=>{if(curPos<0)return;pywebview.api.save_state(curFile,curPos,cols(),$('ta').selectionStart||0,$('ta').scrollTop||0);},500);
window.addEventListener('beforeunload',()=>{try{pywebview.api.flush_now();}catch(e){}});

/* ---- find / search ---- */
function toggleFind(){const b=$('findbar');b.classList.toggle('open');
  if(b.classList.contains('open'))$('findq').focus();else $('results').classList.remove('open');}
function tflag(k,btn){FIND[k]=!FIND[k];$(btn).classList.toggle('act',FIND[k]);runSearch();}
async function runSearch(){
  const q=$('findq').value;
  if(!q){$('results').classList.remove('open');RESULTS=[];RINDEX=-1;$('findcount').textContent='';return;}
  const r=await pywebview.api.search(q,FIND.case,FIND.regex,$('fside').value);
  if(r.error){$('findcount').textContent='regex err';return;}
  RESULTS=r.matches;RINDEX=-1;showResults(r.truncated);count();
}
function showResults(truncated){
  const p=$('results');p.innerHTML='';
  if(!RESULTS.length){p.innerHTML='<div class="hit">no matches</div>';p.classList.add('open');return;}
  RESULTS.slice(0,120).forEach((h,i)=>{const d=document.createElement('div');d.className='hit';
    d.innerHTML=`<div class="where">${h.file} · #${h.idx}</div><div class="ctx">…${esc(h.before)}<b>${esc(h.match)}</b>${esc(h.after)}…</div>`;
    d.onclick=()=>jumpTo(i);p.appendChild(d);});
  if(truncated){const n=document.createElement('div');n.className='hit';n.textContent='(more not shown — refine query)';p.appendChild(n);}
  p.classList.add('open');
}
function count(){$('findcount').textContent=RESULTS.length?`${RINDEX<0?0:RINDEX+1} of ${RESULTS.length}`:'';}
async function jumpTo(i){
  if(i<0||i>=RESULTS.length)return; RINDEX=i; const h=RESULTS[i];
  if($('fside').value==='work'){
    if(curFile!==h.file){$('file').value=h.file;await openFile(h.file);}
    await selectEntry(h.pos,true);
    const ta=$('ta');ta.focus();try{ta.setSelectionRange(h.start,h.end);}catch(e){}
  }
  $('results').classList.remove('open');count();
}
async function findNext(){if(!RESULTS.length){await runSearch();} if(RESULTS.length)jumpTo((RINDEX+1)%RESULTS.length);}
async function findPrev(){if(!RESULTS.length){await runSearch();} if(RESULTS.length)jumpTo((RINDEX-1+RESULTS.length)%RESULTS.length);}
function replaceOne(){
  if($('fside').value!=='work'||curPos<0)return;
  const ta=$('ta'); if(ta.selectionStart===ta.selectionEnd){findNext();return;}
  ta.setRangeText($('findr').value,ta.selectionStart,ta.selectionEnd,'end');
  renderPreview();bumpState();
}

/* ---- settings ---- */
async function openSettings(){
  SETCFG=await pywebview.api.settings();
  const langs=Object.keys(SETCFG.languages);
  const fill=(sel,cur)=>{const s=$(sel);s.innerHTML='';langs.forEach(k=>{const o=document.createElement('option');o.value=k;o.textContent=SETCFG.languages[k].label+' ('+k+')';if(k===cur)o.selected=true;s.appendChild(o);});};
  fill('s-work-lang',SETCFG.working_lang); fill('s-ref-lang',SETCFG.reference_lang);
  $('s-work-lang').onchange=()=>renderFields('work'); $('s-ref-lang').onchange=()=>renderFields('ref');
  renderFields('work'); renderFields('ref');
  $('modalbg').classList.add('open');
}
function renderFields(side){
  const lang=$(side==='work'?'s-work-lang':'s-ref-lang').value;
  const c=SETCFG.languages[lang]||{};
  const f=(key,label,kind)=>`<div class="row"><label>${label}</label><div class="fld">
    <input id="f-${side}-${key}" type="text" value="${esc(c[key]||'')}">
    <button onclick="browse('${side}','${key}','${kind}')">📁</button></div></div>`;
  let h=f('scripts_dir','Scripts folder','folder')+f('table','Encoding table (.tbl)','file')+f('font_png','Font sheet (.png)','file');
  h+= side==='ref' ? f('kanji_png','Kanji sheet (.png, optional)','file') : f('widths','VWF widths (.bin, optional)','file');
  $(side==='work'?'s-work-fields':'s-ref-fields').innerHTML=h;
}
async function browse(side,key,kind){
  const cur=$(`f-${side}-${key}`).value;
  const p=await pywebview.api.pick_path(kind,cur);
  if(p)$(`f-${side}-${key}`).value=p;
}
function closeSettings(){$('modalbg').classList.remove('open');}
async function saveSettings(){
  const wl=$('s-work-lang').value, rl=$('s-ref-lang').value;
  const grab=(side)=>{const o={};['scripts_dir','table','font_png','widths','kanji_png'].forEach(k=>{const el=$(`f-${side}-${k}`);if(el)o[k]=el.value;});return o;};
  const ov={}; ov[wl]=grab('work'); ov[rl]=Object.assign(ov[rl]||{},grab('ref'));
  const r=await pywebview.api.apply_settings(wl,rl,ov);
  if(!r.ok){alert('Settings error: '+r.error);return;}
  closeSettings();
  $('worklabel').textContent=r.langs.work;$('reflabel').textContent=r.langs.ref||'Reference';
  const fsel=$('file');fsel.innerHTML='';r.files.forEach(f=>{const o=document.createElement('option');o.value=f;o.textContent=f;fsel.appendChild(o);});
  if(r.files.length){$('file').value=r.files[0];openFile(r.files[0]);}
}
window.addEventListener('pywebviewready',init);
</script></body></html>"""


# ===========================================================================
# main
# ===========================================================================
def main() -> int:
    api = Api()
    # CLI file arg overrides the restored session file (init() restores `last`).
    if len(sys.argv) > 1:
        api.last = {**api.last, "file": Path(sys.argv[1]).name, "pos": 0, "cursor": 0}
    import webview
    win = webview.create_window(
        f"LM3 Script Editor — {api.work.label} → VWF preview"
        + (f" + {api.ref.label} ref" if api.ref else ""),
        html=build_html(), js_api=api, width=1340, height=880, min_size=(960, 620))
    api._window = win
    webview.start(debug=bool(os.environ.get("LM3_EDITOR_DEBUG")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
