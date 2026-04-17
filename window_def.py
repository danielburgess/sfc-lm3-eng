#!/usr/bin/env python3
"""
window_def.py — Window Definition Editor for windowed-script tables.

Visual tool for defining text windows (<<<window[N]:$START-$END>>>) in
event-script ROM data. Reads pointer table + ROM binary, shows decoded
text, lets user confirm/edit/create window regions, exports windowed
script files for retrotool.

Usage:
    python3 window_def.py combat-bytecode-2
    python3 window_def.py --def combat-bytecode-2_window.def
"""

import json
import os
import re
import shutil
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Imports from project
# ---------------------------------------------------------------------------

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib  # type: ignore[no-redef]

from retrotool.script.table import Table
from retrotool.core.address import SFCAddress, SFCAddressType

# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------


@dataclass
class WindowDef:
    index: int       # sequential within entry
    start: int       # byte offset in entry binary (the [P] byte)
    end: int         # byte offset (the [end] byte)
    text_preview: str = ""


@dataclass
class EntryData:
    index: int
    header: str
    ptr_pc: int             # PC address where entry data begins
    binary: bytes
    decoded_text: str
    windows: list[WindowDef] = field(default_factory=list)
    excluded: bool = False


class ScriptModel:
    """Holds all state for the window definition editor."""

    def __init__(self, table_name: str, toml_path: str, project_toml_path: str, lang: str = "jp"):
        self.table_name = table_name
        self.lang = lang
        self.toml_config: dict = {}
        self.project_config: dict = {}
        self.entries: dict[int, EntryData] = {}
        self.tbl: Table | None = None
        self.fallback_tbl: Table | None = None
        self.ctrl_lengths: dict = {}
        self.rom: bytes = b""
        self.def_path: str = ""

        self._load_config(toml_path, project_toml_path)
        self._load_rom()
        self._extract_entries()

    def _load_config(self, toml_path: str, project_toml_path: str):
        with open(toml_path, "rb") as f:
            self.toml_config = tomllib.load(f)
        with open(project_toml_path, "rb") as f:
            self.project_config = tomllib.load(f)

        enc = self.toml_config.get("encoding", {})
        en_tbl = enc.get("table_file", self.project_config.get("primary_table", ""))
        jp_tbl = enc.get("fallback", self.project_config.get("fallback_table", ""))

        if self.lang == "jp" and jp_tbl and os.path.exists(jp_tbl):
            tbl_file = jp_tbl
            fallback_file = en_tbl
        else:
            tbl_file = en_tbl
            fallback_file = jp_tbl

        self.tbl = Table(tbl_file)
        if fallback_file and os.path.exists(fallback_file):
            self.fallback_tbl = Table(fallback_file)
        self.ctrl_lengths = self.tbl.ctrl_lengths

        # .def path: same dir as script file, base name + _window.def
        section = self.toml_config.get("section", {})
        script_file = section.get("file", "")
        if script_file:
            base = os.path.splitext(script_file)[0]
            self.def_path = base + "_window.def"
        else:
            self.def_path = f"{self.table_name}_window.def"

    def _load_rom(self):
        rom_file = self.project_config.get("source_rom", "lm3.sfc")
        with open(rom_file, "rb") as f:
            self.rom = f.read()

    def _extract_entries(self):
        ptrs = self.toml_config["pointers"]
        ptr_offset = ptrs["offset"]
        ptr_count = ptrs["count"]
        ptr_size = ptrs.get("size", 2)

        data_section = self.toml_config.get("data", {})
        data_offset_override = data_section.get("offset", None)

        full_extent = self.toml_config.get("full_extent_entries", [])
        event_script = self.toml_config.get("event_script", False)

        # Read pointer table → list of PC addresses
        pc_addrs = []
        for i in range(ptr_count):
            off = ptr_offset + i * ptr_size
            if ptr_size == 2:
                raw_ptr = struct.unpack_from("<H", self.rom, off)[0]
                # 2-byte ptr: need bank from pointer table location
                bank = (ptr_offset >> 15) & 0x7F
                pc = bank * 0x8000 + (raw_ptr - 0x8000)
                pc_addrs.append(pc)
            elif ptr_size == 3:
                lo = self.rom[off]
                hi = self.rom[off + 1]
                bk = self.rom[off + 2]
                addr = (bk << 16) | (hi << 8) | lo
                sfc = SFCAddress(addr, SFCAddressType.LOROM1)
                pc_addrs.append(sfc.get_address(SFCAddressType.PC))

        # Compute entry boundaries using sorted unique addresses
        sorted_unique = sorted(set(pc_addrs))

        ptr_table_sfc = SFCAddress(ptr_offset)
        tab_addr = ptr_table_sfc.get_address()

        for idx in range(ptr_count):
            data_start = pc_addrs[idx]
            # Find end: next unique address or find_entry_end
            addr_pos = sorted_unique.index(data_start) if data_start in sorted_unique else -1

            if event_script or idx in full_extent:
                # Use next pointer as boundary (don't truncate at 0x00)
                if addr_pos >= 0 and addr_pos + 1 < len(sorted_unique):
                    data_end = sorted_unique[addr_pos + 1]
                else:
                    data_end = data_start + 256  # fallback
            else:
                if addr_pos >= 0 and addr_pos + 1 < len(sorted_unique):
                    max_addr = sorted_unique[addr_pos + 1]
                else:
                    max_addr = None
                data_end = self.tbl.find_entry_end(self.rom, data_start, max_addr=max_addr)

            binary = self.rom[data_start:data_end]
            decoded = interpret_event_script(binary, self.tbl)
            header = f"${tab_addr:X}:{idx}[${data_start:X}]"

            self.entries[idx] = EntryData(
                index=idx,
                header=f"<<{header}>>",
                ptr_pc=data_start,
                binary=binary,
                decoded_text=decoded,
            )


# ---------------------------------------------------------------------------
# Text decode (from lm3.py)
# ---------------------------------------------------------------------------


def interpret_event_script(bin_data, tbl):
    """Decode event-text binary using standard table + @ctrl lengths."""
    if not bin_data:
        return ""

    ctrl = tbl.ctrl_lengths
    result = ""
    i = 0

    while i < len(bin_data):
        b = bin_data[i]

        if b == 0x00:
            result += "[end]"
            i += 1
            continue

        if b == 0xFF and i + 1 < len(bin_data):
            cmd = bin_data[i + 1]
            ctrl_len = ctrl.get(cmd, 3)

            if i + 2 < len(bin_data):
                val_3byte = (0xFF << 16) | (bin_data[i + 1] << 8) | bin_data[i + 2]
                char = tbl.get_chars(val_3byte, False)
                if char:
                    result += char
                    i += 3
                    continue

            end = min(i + ctrl_len, len(bin_data))
            code_bytes = bin_data[i:end]
            hex_str = "".join(f"{b:02X}" for b in code_bytes)
            result += f"[{hex_str}]"
            i += ctrl_len
            continue

        matched = False
        for size in (3, 2, 1):
            if i + size > len(bin_data):
                continue
            if size > 1 and any(bin_data[i + j] == 0x00 for j in range(1, size)):
                continue
            val = 0
            for j in range(size):
                val = (val << 8) | bin_data[i + j]
            char = tbl.get_chars(val, False)
            if char:
                result += char
                i += size
                matched = True
                break

        if not matched:
            result += tbl.get_chars(b, True) or f"[{b:02X}]"
            i += 1

    return result


def _find_text_windows(bin_data, ctrl_lengths):
    """Scan for text windows: regions between [P] (0x10) and [end] (0x00)."""
    windows = []
    pos = 0
    in_text = False
    text_start = None
    while pos < len(bin_data):
        b = bin_data[pos]
        if b == 0xFF and pos + 1 < len(bin_data):
            sub = bin_data[pos + 1]
            cl = ctrl_lengths.get(sub, 2)
            pos += cl
        elif b == 0x10 and not in_text:
            in_text = True
            text_start = pos
            pos += 1
        elif b == 0x00 and in_text:
            windows.append((text_start, pos))
            in_text = False
            pos += 1
        elif b == 0x00:
            pos += 1
        else:
            pos += 1
    if in_text:
        windows.append((text_start, len(bin_data)))
    return windows


def decode_with_positions(bin_data, tbl):
    """Like interpret_event_script but also returns char_to_byte mapping.

    Returns (decoded_str, char_to_byte: list[int])
    where char_to_byte[i] = byte offset in bin_data for character i.
    """
    if not bin_data:
        return "", []

    ctrl = tbl.ctrl_lengths
    result = ""
    char_to_byte = []
    i = 0

    while i < len(bin_data):
        b = bin_data[i]
        token_start = i

        if b == 0x00:
            token = "[end]"
            i += 1
        elif b == 0xFF and i + 1 < len(bin_data):
            cmd = bin_data[i + 1]
            ctrl_len = ctrl.get(cmd, 3)

            token = None
            if i + 2 < len(bin_data):
                val_3byte = (0xFF << 16) | (bin_data[i + 1] << 8) | bin_data[i + 2]
                char = tbl.get_chars(val_3byte, False)
                if char:
                    token = char
                    i += 3

            if token is None:
                end = min(i + ctrl_len, len(bin_data))
                code_bytes = bin_data[i:end]
                hex_str = "".join(f"{b:02X}" for b in code_bytes)
                token = f"[{hex_str}]"
                i += ctrl_len
        else:
            token = None
            for size in (3, 2, 1):
                if i + size > len(bin_data):
                    continue
                if size > 1 and any(bin_data[i + j] == 0x00 for j in range(1, size)):
                    continue
                val = 0
                for j in range(size):
                    val = (val << 8) | bin_data[i + j]
                char = tbl.get_chars(val, False)
                if char:
                    token = char
                    i += size
                    break

            if token is None:
                token = tbl.get_chars(b, True) or f"[{b:02X}]"
                i += 1

        # Map every character of this token to the byte offset
        for _ in token:
            char_to_byte.append(token_start)
        result += token

    return result, char_to_byte


# ---------------------------------------------------------------------------
# .def file I/O
# ---------------------------------------------------------------------------


def save_def(model: ScriptModel, path: str | None = None):
    """Save current window definitions to JSON .def file. Returns saved path or None on failure."""
    path = path or model.def_path
    if not path:
        print("[save_def] no def_path configured")
        return None
    data = {
        "table": model.table_name,
        "source_script": model.toml_config.get("section", {}).get("file", ""),
        "entries": {},
    }
    for idx, entry in sorted(model.entries.items()):
        if entry.windows or entry.excluded:
            data["entries"][str(idx)] = {
                "excluded": entry.excluded,
                "windows": [
                    {"start": f"{w.start:04X}", "end": f"{w.end:04X}"}
                    for w in entry.windows
                ],
            }
    try:
        os.makedirs(os.path.dirname(os.path.abspath(path)) or ".", exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"[save_def] wrote {path} ({len(data['entries'])} entries)")
        return path
    except Exception as exc:
        print(f"[save_def] FAILED to write {path}: {exc}")
        return None


def load_def(model: ScriptModel, path: str):
    """Load .def file, backing up existing .def first."""
    if os.path.exists(model.def_path) and os.path.abspath(path) != os.path.abspath(model.def_path):
        backup = model.def_path + ".bak"
        shutil.copy2(model.def_path, backup)

    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Clear existing windows
    for entry in model.entries.values():
        entry.windows = []
        entry.excluded = False

    for idx_str, edata in data.get("entries", {}).items():
        idx = int(idx_str)
        if idx not in model.entries:
            continue
        entry = model.entries[idx]
        entry.excluded = edata.get("excluded", False)
        for wi, wdef in enumerate(edata.get("windows", [])):
            start = int(wdef["start"], 16)
            end = int(wdef["end"], 16)
            preview = _window_preview(entry.binary, start, end, model.tbl)
            entry.windows.append(WindowDef(index=wi, start=start, end=end, text_preview=preview))


def _window_preview(binary, start, end, tbl, max_len=60):
    """Decode full window range for preview — no byte stripping."""
    text_data = binary[start:end]
    decoded = interpret_event_script(text_data, tbl)
    if len(decoded) > max_len:
        decoded = decoded[:max_len] + "..."
    return decoded


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------


def export_windowed_script(model: ScriptModel, output_path: str | None = None):
    """Export windowed script file for retrotool."""
    section = model.toml_config.get("section", {})
    script_file = section.get("file", "")
    if output_path is None:
        base, ext = os.path.splitext(script_file)
        if "-windowed" not in base:
            output_path = base + "-windowed" + ext
        else:
            output_path = script_file

    ptrs = model.toml_config["pointers"]
    ptr_offset = ptrs["offset"]
    ptr_table_sfc = SFCAddress(ptr_offset)
    tab_addr = ptr_table_sfc.get_address()

    lines = []
    first = True
    for idx in sorted(model.entries.keys()):
        entry = model.entries[idx]

        header = f"<<${tab_addr:X}:{idx}[${entry.ptr_pc:X}]>>"
        if not first:
            lines.append("")
        first = False
        lines.append(header)

        if entry.excluded:
            continue

        if not entry.windows:
            continue

        for wi, w in enumerate(entry.windows):
            lines.append(f"<<<window[{wi}]:${w.start:04X}-${w.end:04X}>>>")
            bin_data = entry.binary
            s = w.start + 1 if w.start < len(bin_data) and bin_data[w.start] == 0x10 else w.start
            e = w.end if w.end <= len(bin_data) and (w.end <= 0 or bin_data[w.end - 1] != 0x00) else w.end - 1
            text_data = bin_data[s:e] if e > s else b""
            decoded = interpret_event_script(text_data, model.tbl)
            lines.append(decoded)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    return output_path


# ---------------------------------------------------------------------------
# API class (exposed to pywebview JS)
# ---------------------------------------------------------------------------


class Api:
    def __init__(self, model: ScriptModel):
        self.model = model
        self._window = None  # set after webview.create_window
        # Separate table for preview decoding; defaults to main model.tbl
        self.preview_tbl = model.tbl
        self.autosave = True

    def set_window(self, window):
        self._window = window

    def get_info(self):
        """Return model info for UI init."""
        return {
            "table_name": self.model.table_name,
            "lang": self.model.lang,
            "def_path": self.model.def_path,
            "entry_count": len(self.model.entries),
            "autosave": self.autosave,
        }

    def set_autosave(self, enabled):
        """Toggle autosave on/off."""
        self.autosave = bool(enabled)
        return {"ok": True, "autosave": self.autosave}

    def _autosave(self):
        """Conditional autosave."""
        if self.autosave:
            return save_def(self.model)
        return None

    def set_preview_lang(self, lang):
        """Toggle preview decode table. lang: 'jp'|'en'."""
        enc = self.model.toml_config.get("encoding", {})
        en_file = enc.get("table_file", self.model.project_config.get("primary_table", ""))
        jp_file = enc.get("fallback", self.model.project_config.get("fallback_table", ""))
        target = jp_file if lang == "jp" else en_file
        if not target or not os.path.exists(target):
            return {"error": f"table file missing for lang={lang}"}
        self.preview_tbl = Table(target)
        # Regenerate all previews
        for entry in self.model.entries.values():
            for w in entry.windows:
                w.text_preview = _window_preview(entry.binary, w.start, w.end, self.preview_tbl)
        return {"ok": True, "lang": lang}

    def get_entries(self):
        """Return all entries with metadata."""
        result = []
        for idx in sorted(self.model.entries.keys()):
            e = self.model.entries[idx]
            result.append({
                "index": idx,
                "header": e.header,
                "window_count": len(e.windows),
                "excluded": e.excluded,
                "has_text_windows": len(_find_text_windows(e.binary, self.model.ctrl_lengths)) > 0,
            })
        return result

    def get_window_char_ranges(self, entry_idx):
        """Return char-range list for an entry's windows (for in-text highlighting).

        Each: {"index", "char_start", "char_end"} mapped from byte offsets via
        decode_with_positions on the decoded_text string.
        """
        entry_idx = int(entry_idx)
        if entry_idx not in self.model.entries:
            return []
        entry = self.model.entries[entry_idx]
        if not entry.windows:
            return []
        _, c2b = decode_with_positions(entry.binary, self.model.tbl)
        total = len(c2b)
        out = []
        for w in entry.windows:
            cs = next((i for i, b in enumerate(c2b) if b >= w.start), total)
            ce = next((i for i, b in enumerate(c2b) if b >= w.end), total)
            out.append({"index": w.index, "char_start": cs, "char_end": ce})
        return out

    def get_windows(self, entry_idx):
        """Return windows for given entry."""
        entry_idx = int(entry_idx)
        if entry_idx not in self.model.entries:
            return []
        entry = self.model.entries[entry_idx]
        return [
            {
                "index": w.index,
                "start": f"{w.start:04X}",
                "end": f"{w.end:04X}",
                "preview": w.text_preview,
            }
            for w in entry.windows
        ]

    def get_entry_text(self, entry_idx):
        """Return full decoded text for an entry."""
        entry_idx = int(entry_idx)
        if entry_idx not in self.model.entries:
            return ""
        return self.model.entries[entry_idx].decoded_text

    def get_full_text(self):
        """Return all entries' decoded text concatenated with headers."""
        lines = []
        for idx in sorted(self.model.entries.keys()):
            e = self.model.entries[idx]
            lines.append(e.header)
            lines.append(e.decoded_text)
            lines.append("")
        return "\n".join(lines)

    def get_entry_line_map(self):
        """Return mapping of entry index → line number in full text."""
        line_map = {}
        line = 0
        for idx in sorted(self.model.entries.keys()):
            line_map[idx] = line
            e = self.model.entries[idx]
            text_lines = e.decoded_text.count("\n") + 1
            line += 1 + text_lines + 1  # header + text + blank
        return line_map

    def create_window(self, entry_idx, start_hex, end_hex):
        """Create window from byte range. Auto-saves."""
        entry_idx = int(entry_idx)
        if entry_idx not in self.model.entries:
            return {"error": f"Entry {entry_idx} not found"}
        entry = self.model.entries[entry_idx]
        start = int(start_hex, 16)
        end = int(end_hex, 16)
        preview = _window_preview(entry.binary, start, end, self.preview_tbl)
        wi = len(entry.windows)
        entry.windows.append(WindowDef(index=wi, start=start, end=end, text_preview=preview))
        # Sort windows by start offset and re-index
        entry.windows.sort(key=lambda w: w.start)
        for i, w in enumerate(entry.windows):
            w.index = i
        saved = self._autosave()
        return {"ok": True, "window_count": len(entry.windows), "saved": saved}

    def update_window(self, entry_idx, window_idx, start_hex, end_hex):
        """Modify existing window's byte range. Auto-saves."""
        entry_idx = int(entry_idx)
        window_idx = int(window_idx)
        if entry_idx not in self.model.entries:
            return {"error": f"Entry {entry_idx} not found"}
        entry = self.model.entries[entry_idx]
        if not (0 <= window_idx < len(entry.windows)):
            return {"error": f"Window index {window_idx} out of range"}
        try:
            start = int(start_hex, 16)
            end = int(end_hex, 16)
        except ValueError:
            return {"error": "Invalid hex"}
        if end <= start or start < 0 or end > len(entry.binary):
            return {"error": f"Range out of bounds (0..{len(entry.binary):04X})"}
        w = entry.windows[window_idx]
        w.start = start
        w.end = end
        w.text_preview = _window_preview(entry.binary, start, end, self.preview_tbl)
        entry.windows.sort(key=lambda x: x.start)
        for i, ww in enumerate(entry.windows):
            ww.index = i
        saved = self._autosave()
        return {"ok": True, "saved": saved}

    def delete_window(self, entry_idx, window_idx):
        """Delete specific window. Re-indexes remaining. Auto-saves."""
        entry_idx = int(entry_idx)
        window_idx = int(window_idx)
        if entry_idx not in self.model.entries:
            return {"error": f"Entry {entry_idx} not found"}
        entry = self.model.entries[entry_idx]
        if 0 <= window_idx < len(entry.windows):
            entry.windows.pop(window_idx)
            for i, w in enumerate(entry.windows):
                w.index = i
        saved = self._autosave()
        return {"ok": True, "window_count": len(entry.windows), "saved": saved}

    def delete_entry(self, entry_idx):
        """Mark entry excluded. Auto-saves."""
        entry_idx = int(entry_idx)
        if entry_idx not in self.model.entries:
            return {"error": f"Entry {entry_idx} not found"}
        self.model.entries[entry_idx].excluded = True
        saved = self._autosave()
        return {"ok": True, "saved": saved}

    def restore_entry(self, entry_idx):
        """Un-exclude entry. Auto-saves."""
        entry_idx = int(entry_idx)
        if entry_idx not in self.model.entries:
            return {"error": f"Entry {entry_idx} not found"}
        self.model.entries[entry_idx].excluded = False
        saved = self._autosave()
        return {"ok": True, "saved": saved}

    def auto_detect_entry(self, entry_idx):
        """Run _find_text_windows on entry binary. Replace windows. Auto-saves."""
        entry_idx = int(entry_idx)
        if entry_idx not in self.model.entries:
            return {"error": f"Entry {entry_idx} not found"}
        entry = self.model.entries[entry_idx]
        raw_windows = _find_text_windows(entry.binary, self.model.ctrl_lengths)
        entry.windows = []
        for wi, (s, e) in enumerate(raw_windows):
            preview = _window_preview(entry.binary, s, e, self.preview_tbl)
            entry.windows.append(WindowDef(index=wi, start=s, end=e, text_preview=preview))
        saved = self._autosave()
        return {"ok": True, "window_count": len(entry.windows), "saved": saved}

    def auto_detect_all(self):
        """Auto-detect windows for ALL non-excluded entries. Auto-saves."""
        count = 0
        for idx, entry in self.model.entries.items():
            if entry.excluded:
                continue
            raw_windows = _find_text_windows(entry.binary, self.model.ctrl_lengths)
            entry.windows = []
            for wi, (s, e) in enumerate(raw_windows):
                preview = _window_preview(entry.binary, s, e, self.preview_tbl)
                entry.windows.append(WindowDef(index=wi, start=s, end=e, text_preview=preview))
            count += 1
        saved = self._autosave()
        return {"ok": True, "entries_processed": count, "saved": saved}

    def export(self, output_path=None):
        """Export windowed script. If output_path given, use it; else prompt via native dialog."""
        if not output_path and self._window is not None:
            import webview
            section = self.model.toml_config.get("section", {})
            script_file = section.get("file", "")
            default_name = ""
            default_dir = ""
            if script_file:
                base, ext = os.path.splitext(script_file)
                if "-windowed" not in base:
                    base = base + "-windowed"
                default_path = base + ext
                default_dir = os.path.dirname(os.path.abspath(default_path)) or os.getcwd()
                default_name = os.path.basename(default_path)
            try:
                dialog_type = getattr(webview, "FileDialog", None)
                dialog_type = dialog_type.SAVE if dialog_type else webview.SAVE_DIALOG
                result = self._window.create_file_dialog(
                    dialog_type,
                    directory=default_dir,
                    save_filename=default_name,
                    file_types=("Text Files (*.txt)", "All files (*.*)"),
                )
            except Exception as exc:
                return {"error": f"dialog failed: {exc}"}
            if not result:
                return {"cancelled": True}
            output_path = result if isinstance(result, str) else result[0]
        try:
            path = export_windowed_script(self.model, output_path)
            return {"ok": True, "path": path}
        except Exception as exc:
            return {"error": f"export failed: {exc}"}

    def nudge_window(self, entry_idx, window_idx, edge, delta):
        """Shift window edge ('start'|'end') by delta bytes. Auto-saves."""
        entry_idx = int(entry_idx)
        window_idx = int(window_idx)
        delta = int(delta)
        if entry_idx not in self.model.entries:
            return {"error": f"Entry {entry_idx} not found"}
        entry = self.model.entries[entry_idx]
        if not (0 <= window_idx < len(entry.windows)):
            return {"error": "bad window idx"}
        w = entry.windows[window_idx]
        new_start = w.start + (delta if edge == "start" else 0)
        new_end = w.end + (delta if edge == "end" else 0)
        if new_start < 0 or new_end > len(entry.binary) or new_end <= new_start:
            return {"error": "range out of bounds"}
        w.start = new_start
        w.end = new_end
        w.text_preview = _window_preview(entry.binary, w.start, w.end, self.preview_tbl)
        # Re-sort + re-index if start changed
        entry.windows.sort(key=lambda x: x.start)
        for i, ww in enumerate(entry.windows):
            ww.index = i
        saved = self._autosave()
        return {
            "ok": True,
            "saved": saved,
            "start": f"{w.start:04X}",
            "end": f"{w.end:04X}",
            "preview": w.text_preview,
        }

    def get_entry_preview(self, entry_idx, max_len=60):
        """Return short preview of entry — first window if present, else entry start."""
        entry_idx = int(entry_idx)
        if entry_idx not in self.model.entries:
            return ""
        entry = self.model.entries[entry_idx]
        if entry.windows:
            w = entry.windows[0]
            return _window_preview(entry.binary, w.start, w.end, self.preview_tbl, max_len=max_len)
        decoded = interpret_event_script(entry.binary[:max_len * 3], self.preview_tbl)
        return decoded[:max_len] + ("..." if len(decoded) > max_len else "")

    def selection_byte_length(self, entry_idx, char_start, char_end):
        """Return byte-length of char range in entry binary."""
        entry_idx = int(entry_idx)
        char_start = int(char_start)
        char_end = int(char_end)
        if entry_idx not in self.model.entries:
            return {"bytes": 0}
        entry = self.model.entries[entry_idx]
        _, c2b = decode_with_positions(entry.binary, self.model.tbl)
        if not c2b:
            return {"bytes": 0}
        cs = max(0, min(char_start, len(c2b) - 1))
        ce = max(0, min(char_end, len(c2b) - 1))
        if ce <= cs:
            return {"bytes": 0}
        byte_start = c2b[cs]
        # End byte = c2b[ce] if in range, else next token's byte_start, else len(binary)
        byte_end = c2b[ce] if ce < len(c2b) else len(entry.binary)
        return {"bytes": max(0, byte_end - byte_start), "byte_start": f"{byte_start:04X}", "byte_end": f"{byte_end:04X}"}

    def load_def_file(self, path):
        """Load .def file. Backs up existing first."""
        if not path:
            path = self.model.def_path
        if not os.path.exists(path):
            return {"error": f"File not found: {path}"}
        load_def(self.model, path)
        return {"ok": True}

    def get_char_to_byte(self, entry_idx, char_start, char_end):
        """Map text selection char positions to byte offsets."""
        entry_idx = int(entry_idx)
        char_start = int(char_start)
        char_end = int(char_end)
        if entry_idx not in self.model.entries:
            return {"error": f"Entry {entry_idx} not found"}
        entry = self.model.entries[entry_idx]
        _, c2b = decode_with_positions(entry.binary, self.model.tbl)
        if not c2b:
            return {"error": "No decode data"}
        # Clamp to valid range
        char_start = max(0, min(char_start, len(c2b) - 1))
        char_end = max(0, min(char_end, len(c2b) - 1))
        byte_start = c2b[char_start]
        byte_end = c2b[char_end]
        return {
            "byte_start": f"{byte_start:04X}",
            "byte_end": f"{byte_end:04X}",
        }

    def save(self):
        """Force save .def."""
        saved = self._autosave()
        return {"ok": saved is not None, "saved": saved}


# ---------------------------------------------------------------------------
# HTML/JS frontend
# ---------------------------------------------------------------------------


def build_html(model: ScriptModel) -> str:
    """Build complete HTML page with embedded CSS/JS."""
    import html as html_mod

    # Pre-build entry text for embedding
    entries_json = []
    for idx in sorted(model.entries.keys()):
        e = model.entries[idx]
        entries_json.append({
            "index": idx,
            "header": e.header,
            "decoded_text": e.decoded_text,
            "excluded": e.excluded,
            "window_count": len(e.windows),
        })

    entries_data = json.dumps(entries_json, ensure_ascii=False)

    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Window Definition Editor — {html_mod.escape(model.table_name)}</title>
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{
    font-family: 'Consolas', 'Monaco', monospace;
    font-size: 13px;
    background: #1e1e2e;
    color: #cdd6f4;
    display: flex;
    flex-direction: column;
    height: 100vh;
    overflow: hidden;
}}

/* Toolbar */
.toolbar {{
    display: flex;
    gap: 8px;
    padding: 8px 12px;
    background: #181825;
    border-bottom: 1px solid #313244;
    flex-shrink: 0;
}}
.toolbar button {{
    padding: 6px 14px;
    background: #45475a;
    color: #cdd6f4;
    border: 1px solid #585b70;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
}}
.toolbar button:hover {{ background: #585b70; }}
.toolbar button.primary {{ background: #89b4fa; color: #1e1e2e; border-color: #89b4fa; }}
.toolbar button.primary:hover {{ background: #74c7ec; }}
.toolbar button.danger {{ background: #f38ba8; color: #1e1e2e; border-color: #f38ba8; }}
.toolbar button.danger:hover {{ background: #eba0ac; }}

/* Main layout */
.main {{
    display: flex;
    flex: 1;
    overflow: hidden;
}}

/* Left pane: script text */
.text-pane {{
    flex: 1;
    overflow-y: auto;
    padding: 8px 12px;
    user-select: text;
    white-space: pre-wrap;
    word-break: break-all;
    line-height: 1.5;
    min-width: 200px;
}}

/* Splitter */
.splitter {{
    width: 5px;
    background: #313244;
    cursor: col-resize;
    flex-shrink: 0;
}}
.splitter:hover, .splitter.dragging {{ background: #89b4fa; }}
.text-pane .entry-block {{ margin-bottom: 12px; }}
.text-pane .entry-block.excluded .entry-text {{
    opacity: 0.35;
    text-decoration: line-through;
    color: #6c7086;
}}
.text-pane .entry-block.excluded .entry-header {{
    opacity: 0.55;
    color: #6c7086;
}}
.text-pane .entry-header {{
    color: #89b4fa;
    font-weight: bold;
    cursor: pointer;
}}
.text-pane .entry-header:hover {{ text-decoration: underline; }}
.text-pane .entry-text {{ color: #cdd6f4; }}
.text-pane .bracket-code {{ color: #6c7086; }}
.text-pane .highlight {{ background: #45475a; }}
.text-pane .window-range {{
    background: #3a4d5c;
    border-bottom: 1px dashed #89b4fa;
    border-radius: 2px;
}}
.text-pane .window-range:hover {{ background: #4a6073; }}

/* Right pane */
.right-pane {{
    width: 380px;
    min-width: 220px;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    flex-shrink: 0;
}}

/* Entry list */
.entry-list-header {{
    padding: 8px 12px;
    background: #181825;
    border-bottom: 1px solid #313244;
    font-weight: bold;
    color: #a6adc8;
    font-size: 12px;
}}
.entry-list {{
    flex: 1;
    overflow-y: auto;
    border-bottom: 2px solid #313244;
}}
.entry-item {{
    display: flex;
    align-items: center;
    padding: 4px 12px;
    cursor: pointer;
    border-bottom: 1px solid #181825;
    font-size: 12px;
}}
.entry-item:hover {{ background: #313244; }}
.entry-item.selected {{ background: #45475a; }}
.entry-item.excluded {{ opacity: 0.4; text-decoration: line-through; }}
.entry-item {{ gap: 6px; }}
.entry-item .idx {{ color: #89b4fa; width: 40px; flex-shrink: 0; }}
.entry-item .info {{ width: 80px; color: #a6adc8; flex-shrink: 0; font-size: 11px; }}
.entry-item .ent-preview {{ flex: 1; color: #7a869a; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 11px; }}
.entry-item .del-btn {{
    color: #f38ba8;
    cursor: pointer;
    padding: 2px 6px;
    border-radius: 3px;
    font-size: 11px;
    visibility: hidden;
}}
.entry-item:hover .del-btn {{ visibility: visible; }}
.entry-item .del-btn:hover {{ background: #f38ba8; color: #1e1e2e; }}

/* Window list */
.window-list-header {{
    padding: 8px 12px;
    background: #181825;
    border-bottom: 1px solid #313244;
    font-weight: bold;
    color: #a6adc8;
    font-size: 12px;
}}
.window-list {{
    flex: 1;
    overflow-y: auto;
    min-height: 120px;
}}
.window-item {{
    display: flex;
    align-items: center;
    padding: 4px 12px;
    border-bottom: 1px solid #181825;
    font-size: 12px;
}}
.window-item:hover {{ background: #313244; }}
.window-item {{ gap: 3px; }}
.window-item .widx {{ color: #f9e2af; width: 30px; flex-shrink: 0; }}
.window-item .range {{ color: #a6e3a1; width: 115px; font-family: monospace; cursor: pointer; text-decoration: underline dotted; flex-shrink: 0; }}
.window-item .range:hover {{ color: #f9e2af; }}
.window-item .nudge {{
    background: #313244; color: #cdd6f4; border: none; border-radius: 2px;
    width: 16px; height: 16px; font-size: 10px; cursor: pointer; padding: 0;
    line-height: 1; flex-shrink: 0;
}}
.window-item .nudge:hover {{ background: #585b70; color: #89b4fa; }}
.window-item .nudge.expand {{ color: #a6e3a1; }}
.window-item .nudge.shrink {{ color: #f38ba8; }}
.window-item .preview {{ flex: 1; color: #a6adc8; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }}
.window-item .del-btn {{
    color: #f38ba8;
    cursor: pointer;
    padding: 2px 6px;
    border-radius: 3px;
    font-size: 11px;
    visibility: hidden;
}}
.window-item:hover .del-btn {{ visibility: visible; }}
.window-item .del-btn:hover {{ background: #f38ba8; color: #1e1e2e; }}

/* Action buttons */
.actions {{
    padding: 8px 12px;
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
    background: #181825;
    border-top: 1px solid #313244;
}}
.actions button {{
    padding: 5px 12px;
    background: #45475a;
    color: #cdd6f4;
    border: 1px solid #585b70;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
}}
.actions button:hover {{ background: #585b70; }}
.actions button:disabled {{ opacity: 0.4; cursor: default; }}

/* Status bar */
.status-bar {{
    padding: 4px 12px;
    background: #181825;
    border-top: 1px solid #313244;
    font-size: 11px;
    color: #6c7086;
    flex-shrink: 0;
}}
</style>
</head>
<body>

<div class="toolbar">
    <button class="primary" onclick="autoDetectAll()">Auto-detect All</button>
    <button class="primary" onclick="doExport()">Export</button>
    <button onclick="loadDef()">Load .def</button>
    <button onclick="doSave()">Save .def</button>
    <label style="align-self:center;font-size:12px;color:#a6adc8;">
        <input type="checkbox" id="chkAutosave" checked onchange="toggleAutosave()"> autosave
    </label>
    <label style="align-self:center;font-size:12px;color:#a6adc8;">
        <input type="checkbox" id="chkQuickAdjust" checked onchange="toggleQuickAdjust()"> quick adjust
    </label>
    <span style="flex:1"></span>
    <span style="color:#6c7086;align-self:center;font-size:12px;">{html_mod.escape(model.table_name)} [{html_mod.escape(model.lang)}]</span>
</div>

<div class="main">
    <div class="text-pane" id="textPane"></div>
    <div class="splitter" id="splitter"></div>
    <div class="right-pane" id="rightPane">
        <div class="entry-list-header">Entries</div>
        <div class="entry-list" id="entryList"></div>
        <div class="window-list-header" id="windowListHeader">Windows</div>
        <div class="window-list" id="windowList"></div>
        <div class="actions">
            <button id="btnCreateWindow" onclick="createWindow()" disabled>Create Window</button>
            <button id="btnAutoDetect" onclick="autoDetectEntry()" disabled>Auto-detect Entry</button>
            <button id="btnRestoreEntry" onclick="restoreEntry()" style="display:none">Restore Entry</button>
        </div>
    </div>
</div>

<div class="status-bar" id="statusBar">Ready</div>

<script>
// State
let selectedEntryIdx = null;
let entryLineMap = {{}};  // idx -> line number in text pane

// --- Initialization ---
const entriesData = {entries_data};

function init() {{
    buildTextPane();
    buildEntryList();
    initSplitter();
    restoreLayout();
    setStatus(`${{entriesData.length}} entries loaded`);
    // Highlight windowed ranges for all entries upfront
    entriesData.forEach(e => {{
        if (e.window_count > 0) applyWindowHighlights(e.index);
    }});
}}

// --- Layout persistence (localStorage) ---
const LAYOUT_KEY = 'window_def_layout_{html_mod.escape(model.table_name)}';

function saveLayout() {{
    const right = document.getElementById('rightPane');
    const data = {{
        right_width: right.offsetWidth,
        autosave: document.getElementById('chkAutosave').checked,
        quick_adjust: document.getElementById('chkQuickAdjust').checked,
    }};
    try {{ localStorage.setItem(LAYOUT_KEY, JSON.stringify(data)); }} catch (e) {{}}
}}

function restoreLayout() {{
    try {{
        const raw = localStorage.getItem(LAYOUT_KEY);
        if (!raw) return;
        const d = JSON.parse(raw);
        if (d.right_width) {{
            document.getElementById('rightPane').style.width = d.right_width + 'px';
        }}
        if (d.autosave === false) {{
            document.getElementById('chkAutosave').checked = false;
            pywebview.api.set_autosave(false);
        }}
        if (d.quick_adjust === false) {{
            document.getElementById('chkQuickAdjust').checked = false;
        }}
    }} catch (e) {{}}
}}

// --- Splitter drag ---
function initSplitter() {{
    const splitter = document.getElementById('splitter');
    const right = document.getElementById('rightPane');
    const main = document.querySelector('.main');
    let dragging = false;

    splitter.addEventListener('mousedown', (e) => {{
        dragging = true;
        splitter.classList.add('dragging');
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
        e.preventDefault();
    }});

    document.addEventListener('mousemove', (e) => {{
        if (!dragging) return;
        const rect = main.getBoundingClientRect();
        const newRight = Math.max(220, Math.min(rect.right - e.clientX, rect.width - 200));
        right.style.width = newRight + 'px';
    }});

    document.addEventListener('mouseup', () => {{
        if (!dragging) return;
        dragging = false;
        splitter.classList.remove('dragging');
        document.body.style.cursor = '';
        document.body.style.userSelect = '';
        saveLayout();
    }});
}}

// --- Autosave + preview lang toggles ---
async function toggleAutosave() {{
    const on = document.getElementById('chkAutosave').checked;
    await pywebview.api.set_autosave(on);
    setStatus(on ? 'Autosave: ON' : 'Autosave: OFF');
    saveLayout();
}}

function toggleQuickAdjust() {{
    saveLayout();
    if (selectedEntryIdx !== null) refreshWindows(selectedEntryIdx);
}}

function reportSave(result) {{
    if (result && result.saved) {{
        const ts = new Date().toLocaleTimeString();
        setStatus('Saved ' + result.saved + ' @ ' + ts);
    }} else if (result && result.ok === false) {{
        setStatus('Save FAILED — check console');
    }}
}}

function buildTextPane() {{
    const pane = document.getElementById('textPane');
    pane.innerHTML = '';
    entriesData.forEach(e => {{
        const block = document.createElement('div');
        block.className = 'entry-block' + (e.excluded ? ' excluded' : '');
        block.id = 'entry-block-' + e.index;

        const header = document.createElement('div');
        header.className = 'entry-header';
        header.textContent = e.header;
        header.onclick = () => selectEntry(e.index);

        const text = document.createElement('div');
        text.className = 'entry-text';
        text.id = 'entry-text-' + e.index;
        // Syntax highlight bracket codes
        text.innerHTML = highlightText(e.decoded_text);

        block.appendChild(header);
        block.appendChild(text);
        pane.appendChild(block);
    }});

    // Track selection changes for entry sync
    pane.addEventListener('mouseup', onTextSelect);
}}

function highlightText(text) {{
    // Escape HTML first, then highlight [xxx] bracket codes
    let escaped = text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    escaped = escaped.replace(/\\[([^\\]]+)\\]/g, '<span class="bracket-code">[$1]</span>');
    return escaped;
}}

function renderEntryWithWindows(text, ranges) {{
    // ranges: [{{index, char_start, char_end}}, ...] — wrap each range with window-range span
    if (!ranges || !ranges.length) return highlightText(text);
    const sorted = ranges.slice().sort((a, b) => a.char_start - b.char_start);
    let html = '';
    let cursor = 0;
    sorted.forEach(r => {{
        const s = Math.max(cursor, r.char_start);
        const e = Math.min(text.length, r.char_end);
        if (s > cursor) html += highlightText(text.slice(cursor, s));
        if (e > s) {{
            html += `<span class="window-range" title="window #${{r.index}}">${{highlightText(text.slice(s, e))}}</span>`;
        }}
        cursor = Math.max(cursor, e);
    }});
    if (cursor < text.length) html += highlightText(text.slice(cursor));
    return html;
}}

async function applyWindowHighlights(idx) {{
    const textEl = document.getElementById('entry-text-' + idx);
    if (!textEl) return;
    const entry = entriesData.find(e => e.index === idx);
    if (!entry) return;
    if (!entry.window_count) {{
        textEl.innerHTML = highlightText(entry.decoded_text);
        return;
    }}
    const ranges = await pywebview.api.get_window_char_ranges(idx);
    textEl.innerHTML = renderEntryWithWindows(entry.decoded_text, ranges);
}}

function buildEntryList() {{
    const list = document.getElementById('entryList');
    list.innerHTML = '';
    entriesData.forEach(e => {{
        const item = document.createElement('div');
        item.className = 'entry-item' + (e.excluded ? ' excluded' : '');
        item.id = 'entry-item-' + e.index;
        item.onclick = () => selectEntry(e.index);

        const idx = document.createElement('span');
        idx.className = 'idx';
        idx.textContent = ':' + e.index;

        const info = document.createElement('span');
        info.className = 'info';
        info.id = 'entry-info-' + e.index;
        info.textContent = e.excluded ? '[excluded]' : `[${{e.window_count}} win]`;

        const preview = document.createElement('span');
        preview.className = 'ent-preview';
        preview.id = 'entry-preview-' + e.index;
        preview.textContent = '...';

        const del = document.createElement('span');
        del.className = 'del-btn';
        del.textContent = e.excluded ? '↩' : '✕';
        del.onclick = (ev) => {{
            ev.stopPropagation();
            if (e.excluded) restoreEntryByIdx(e.index);
            else deleteEntry(e.index);
        }};

        item.appendChild(idx);
        item.appendChild(info);
        item.appendChild(preview);
        item.appendChild(del);
        list.appendChild(item);
    }});
    loadEntryPreviews();
}}

async function loadEntryPreviews() {{
    for (const e of entriesData) {{
        const el = document.getElementById('entry-preview-' + e.index);
        if (!el) continue;
        try {{
            const text = await pywebview.api.get_entry_preview(e.index, 40);
            el.textContent = text || '';
        }} catch (err) {{ el.textContent = ''; }}
    }}
}}

async function refreshEntryPreview(idx) {{
    const el = document.getElementById('entry-preview-' + idx);
    if (!el) return;
    try {{
        const text = await pywebview.api.get_entry_preview(idx, 40);
        el.textContent = text || '';
    }} catch (err) {{}}
}}

function selectEntry(idx) {{
    // Deselect previous
    if (selectedEntryIdx !== null) {{
        const prev = document.getElementById('entry-item-' + selectedEntryIdx);
        if (prev) prev.classList.remove('selected');
        const prevBlock = document.getElementById('entry-block-' + selectedEntryIdx);
        if (prevBlock) prevBlock.classList.remove('highlight');
    }}

    selectedEntryIdx = idx;

    // Highlight in entry list
    const item = document.getElementById('entry-item-' + idx);
    if (item) {{
        item.classList.add('selected');
        item.scrollIntoView({{ block: 'nearest' }});
    }}

    // Highlight; only scroll if partially out of view
    const block = document.getElementById('entry-block-' + idx);
    if (block) {{
        block.classList.add('highlight');
        const pane = document.getElementById('textPane');
        const pr = pane.getBoundingClientRect();
        const br = block.getBoundingClientRect();
        const fullyVisible = br.top >= pr.top && br.bottom <= pr.bottom;
        if (!fullyVisible) {{
            block.scrollIntoView({{ block: 'nearest', behavior: 'smooth' }});
        }}
    }}

    // Update window list + highlight windowed ranges in text
    refreshWindows(idx);
    applyWindowHighlights(idx);

    // Update buttons
    const entry = entriesData.find(e => e.index === idx);
    document.getElementById('btnCreateWindow').disabled = !entry || entry.excluded;
    document.getElementById('btnAutoDetect').disabled = !entry || entry.excluded;
    const restoreBtn = document.getElementById('btnRestoreEntry');
    restoreBtn.style.display = (entry && entry.excluded) ? '' : 'none';

    setStatus(`Entry :${{idx}} | ${{entry ? entry.window_count : 0}} windows`);
}}

async function refreshWindows(entryIdx) {{
    const list = document.getElementById('windowList');
    const header = document.getElementById('windowListHeader');
    list.innerHTML = '';

    if (entryIdx === null) {{
        header.textContent = 'Windows';
        return;
    }}

    const windows = await pywebview.api.get_windows(entryIdx);
    header.textContent = `Windows for :${{entryIdx}} (${{windows.length}})`;
    // Keep entriesData in sync so info column + status reflect live count
    const entry = entriesData.find(e => e.index === entryIdx);
    if (entry && entry.window_count !== windows.length) {{
        entry.window_count = windows.length;
        updateEntryInfo(entryIdx);
    }}

    windows.forEach(w => {{
        const item = document.createElement('div');
        item.className = 'window-item';

        const widx = document.createElement('span');
        widx.className = 'widx';
        widx.textContent = '#' + w.index;

        const range = document.createElement('span');
        range.className = 'range';
        range.textContent = '$' + w.start + '-$' + w.end;
        range.title = 'Click to edit range';
        range.onclick = () => editWindow(entryIdx, w.index, w.start, w.end);

        const preview = document.createElement('span');
        preview.className = 'preview';
        preview.textContent = w.preview;

        const del = document.createElement('span');
        del.className = 'del-btn';
        del.textContent = '✕';
        del.onclick = () => deleteWindow(entryIdx, w.index);

        item.appendChild(widx);
        item.appendChild(range);

        const quickAdjust = document.getElementById('chkQuickAdjust').checked;
        if (quickAdjust) {{
            const mkNudge = (label, title, cls, onclick) => {{
                const b = document.createElement('button');
                b.className = 'nudge ' + cls;
                b.textContent = label;
                b.title = title;
                b.onclick = onclick;
                return b;
            }};
            // front pair: expand start (-1) / shrink start (+1)
            item.appendChild(mkNudge('◀', 'Expand start (-1 byte)', 'expand',
                () => nudge(entryIdx, w.index, 'start', -1)));
            item.appendChild(mkNudge('▶', 'Shrink start (+1 byte)', 'shrink',
                () => nudge(entryIdx, w.index, 'start', +1)));
        }}

        item.appendChild(preview);

        if (quickAdjust) {{
            const mkNudge2 = (label, title, cls, onclick) => {{
                const b = document.createElement('button');
                b.className = 'nudge ' + cls;
                b.textContent = label;
                b.title = title;
                b.onclick = onclick;
                return b;
            }};
            // back pair: shrink end (-1) / expand end (+1)
            item.appendChild(mkNudge2('◀', 'Shrink end (-1 byte)', 'shrink',
                () => nudge(entryIdx, w.index, 'end', -1)));
            item.appendChild(mkNudge2('▶', 'Expand end (+1 byte)', 'expand',
                () => nudge(entryIdx, w.index, 'end', +1)));
        }}

        item.appendChild(del);
        list.appendChild(item);
    }});

    applyWindowHighlights(entryIdx);
}}

async function nudge(entryIdx, windowIdx, edge, delta) {{
    const result = await pywebview.api.nudge_window(entryIdx, windowIdx, edge, delta);
    if (result.error) {{ setStatus('nudge: ' + result.error); return; }}
    refreshWindows(entryIdx);
    reportSave(result);
}}

// --- Text selection → entry sync ---
async function onTextSelect() {{
    const sel = window.getSelection();
    if (!sel || sel.isCollapsed) return;

    const node = sel.anchorNode;
    if (!node) return;

    // Walk up to find entry-block
    let el = node.nodeType === 3 ? node.parentElement : node;
    while (el && !el.classList?.contains('entry-block')) {{
        el = el.parentElement;
    }}
    if (!el) return;

    const idStr = el.id.replace('entry-block-', '');
    const idx = parseInt(idStr, 10);
    if (!isNaN(idx) && idx !== selectedEntryIdx) {{
        selectEntry(idx);
    }}

    // Show byte-length of selection in status bar
    const textEl = document.getElementById('entry-text-' + idx);
    if (!textEl) return;
    try {{
        const fullText = textEl.textContent;
        const range = sel.getRangeAt(0);
        const preRange = document.createRange();
        preRange.setStart(textEl, 0);
        preRange.setEnd(range.startContainer, range.startOffset);
        const charStart = preRange.toString().length;
        const charEnd = charStart + sel.toString().length;
        const info = await pywebview.api.selection_byte_length(idx, charStart, charEnd);
        if (info && info.bytes !== undefined) {{
            setStatus(`Entry :${{idx}} | selected ${{info.bytes}} bytes ($${{info.byte_start || '?'}}-$${{info.byte_end || '?'}})`);
        }}
    }} catch (err) {{}}
}}

// --- Actions ---
async function createWindow() {{
    if (selectedEntryIdx === null) return;

    // Get text selection within the entry
    const sel = window.getSelection();
    if (!sel || sel.isCollapsed) {{
        // No selection: prompt for byte range
        const range = prompt('Enter byte range (hex): START-END\\nExample: 0006-0033');
        if (!range) return;
        const parts = range.split('-');
        if (parts.length !== 2) {{ alert('Invalid format. Use START-END'); return; }}
        const result = await pywebview.api.create_window(selectedEntryIdx, parts[0].trim(), parts[1].trim());
        if (result.error) {{ alert(result.error); return; }}
    }} else {{
        // Map selection to byte offsets
        const textEl = document.getElementById('entry-text-' + selectedEntryIdx);
        if (!textEl) return;

        // Get character offsets relative to entry text element
        const fullText = textEl.textContent;
        const range = sel.getRangeAt(0);

        // Create a range from start of textEl to selection start
        const preRange = document.createRange();
        preRange.setStart(textEl, 0);
        preRange.setEnd(range.startContainer, range.startOffset);
        const charStart = preRange.toString().length;
        const charEnd = charStart + sel.toString().length;

        const mapping = await pywebview.api.get_char_to_byte(selectedEntryIdx, charStart, charEnd);
        if (mapping.error) {{ alert(mapping.error); return; }}

        const result = await pywebview.api.create_window(selectedEntryIdx, mapping.byte_start, mapping.byte_end);
        if (result.error) {{ alert(result.error); return; }}
    }}

    // Refresh
    const entry = entriesData.find(e => e.index === selectedEntryIdx);
    const windows = await pywebview.api.get_windows(selectedEntryIdx);
    if (entry) entry.window_count = windows.length;
    updateEntryInfo(selectedEntryIdx);
    refreshWindows(selectedEntryIdx);
    refreshEntryPreview(selectedEntryIdx);
    setStatus(`Entry :${{selectedEntryIdx}} | ${{windows.length}} windows`);
    reportSave(result);
}}

async function editWindow(entryIdx, windowIdx, curStart, curEnd) {{
    const initial = curStart + '-' + curEnd;
    const input = prompt('Edit window range (hex): START-END', initial);
    if (!input || input.trim() === initial) return;
    const parts = input.split('-').map(s => s.trim());
    if (parts.length !== 2) {{ alert('Invalid format. Use START-END'); return; }}
    const result = await pywebview.api.update_window(entryIdx, windowIdx, parts[0], parts[1]);
    if (result.error) {{ alert(result.error); return; }}
    refreshWindows(entryIdx);
    reportSave(result);
}}

async function deleteWindow(entryIdx, windowIdx) {{
    const result = await pywebview.api.delete_window(entryIdx, windowIdx);
    if (result.error) {{ alert(result.error); return; }}
    const entry = entriesData.find(e => e.index === entryIdx);
    if (entry) entry.window_count = result.window_count;
    updateEntryInfo(entryIdx);
    refreshWindows(entryIdx);
    reportSave(result);
}}

async function deleteEntry(entryIdx) {{
    const result = await pywebview.api.delete_entry(entryIdx);
    if (result.error) {{ alert(result.error); return; }}
    const entry = entriesData.find(e => e.index === entryIdx);
    if (entry) entry.excluded = true;
    const item = document.getElementById('entry-item-' + entryIdx);
    if (item) item.className = 'entry-item excluded' + (entryIdx === selectedEntryIdx ? ' selected' : '');
    const block = document.getElementById('entry-block-' + entryIdx);
    if (block) block.classList.add('excluded');
    updateEntryInfo(entryIdx);
    document.getElementById('btnCreateWindow').disabled = true;
    document.getElementById('btnAutoDetect').disabled = true;
    document.getElementById('btnRestoreEntry').style.display = '';
    // Update del button to restore icon
    const delBtn = item?.querySelector('.del-btn');
    if (delBtn) delBtn.textContent = '↩';
    reportSave(result);
}}

async function restoreEntryByIdx(entryIdx) {{
    const result = await pywebview.api.restore_entry(entryIdx);
    if (result.error) {{ alert(result.error); return; }}
    const entry = entriesData.find(e => e.index === entryIdx);
    if (entry) entry.excluded = false;
    const item = document.getElementById('entry-item-' + entryIdx);
    if (item) item.className = 'entry-item' + (entryIdx === selectedEntryIdx ? ' selected' : '');
    const block = document.getElementById('entry-block-' + entryIdx);
    if (block) block.classList.remove('excluded');
    updateEntryInfo(entryIdx);
    if (entryIdx === selectedEntryIdx) {{
        document.getElementById('btnCreateWindow').disabled = false;
        document.getElementById('btnAutoDetect').disabled = false;
        document.getElementById('btnRestoreEntry').style.display = 'none';
    }}
    const delBtn = item?.querySelector('.del-btn');
    if (delBtn) delBtn.textContent = '✕';
    reportSave(result);
}}

async function restoreEntry() {{
    if (selectedEntryIdx !== null) await restoreEntryByIdx(selectedEntryIdx);
}}

async function autoDetectEntry() {{
    if (selectedEntryIdx === null) return;
    const result = await pywebview.api.auto_detect_entry(selectedEntryIdx);
    if (result.error) {{ alert(result.error); return; }}
    const entry = entriesData.find(e => e.index === selectedEntryIdx);
    if (entry) entry.window_count = result.window_count;
    updateEntryInfo(selectedEntryIdx);
    refreshWindows(selectedEntryIdx);
    setStatus(`Auto-detected ${{result.window_count}} windows for entry :${{selectedEntryIdx}}`);
    reportSave(result);
}}

async function autoDetectAll() {{
    const result = await pywebview.api.auto_detect_all();
    if (result.error) {{ alert(result.error); return; }}
    // Refresh all entry window counts
    for (const e of entriesData) {{
        if (!e.excluded) {{
            const windows = await pywebview.api.get_windows(e.index);
            e.window_count = windows.length;
            updateEntryInfo(e.index);
        }}
    }}
    if (selectedEntryIdx !== null) refreshWindows(selectedEntryIdx);
    setStatus(`Auto-detected windows for ${{result.entries_processed}} entries`);
    reportSave(result);
}}

async function doExport() {{
    const result = await pywebview.api.export();
    if (result.error) {{ alert(result.error); return; }}
    setStatus(`Exported to ${{result.path}}`);
    alert('Exported to: ' + result.path);
}}

async function loadDef() {{
    const path = prompt('Path to .def file (leave empty for default):');
    const result = await pywebview.api.load_def_file(path || '');
    if (result.error) {{ alert(result.error); return; }}
    // Refresh everything
    for (const e of entriesData) {{
        const windows = await pywebview.api.get_windows(e.index);
        e.window_count = windows.length;
        // Check excluded status
        const entries = await pywebview.api.get_entries();
        const fresh = entries.find(x => x.index === e.index);
        if (fresh) e.excluded = fresh.excluded;
    }}
    buildEntryList();
    if (selectedEntryIdx !== null) {{
        selectEntry(selectedEntryIdx);
    }}
    setStatus('Loaded .def file');
}}

async function doSave() {{
    const result = await pywebview.api.save();
    if (result && result.saved) {{
        setStatus('Saved .def: ' + result.saved);
    }} else {{
        setStatus('Save FAILED — check console');
    }}
}}

function updateEntryInfo(idx) {{
    const entry = entriesData.find(e => e.index === idx);
    const info = document.getElementById('entry-info-' + idx);
    if (entry && info) {{
        info.textContent = entry.excluded ? '[excluded]' : `[${{entry.window_count}} win]`;
    }}
}}

function setStatus(msg) {{
    document.getElementById('statusBar').textContent = msg;
}}

// --- Init on load ---
window.addEventListener('load', () => {{
    // Wait for pywebview API to be ready
    if (window.pywebview) {{
        init();
    }} else {{
        window.addEventListener('pywebviewready', init);
    }}
}});
</script>
</body>
</html>"""


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def find_project_toml():
    """Find project.toml in CWD or parent dirs."""
    p = Path.cwd()
    while p != p.parent:
        candidate = p / "project.toml"
        if candidate.exists():
            return str(candidate)
        p = p.parent
    return None


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Window Definition Editor")
    parser.add_argument("table", nargs="?", help="Table name (loads tables/<name>.toml)")
    parser.add_argument("--def", dest="def_file", help="Load from .def file")
    parser.add_argument("--project", help="Path to project.toml")
    parser.add_argument("--lang", choices=["jp", "en"], default="jp",
                        help="Decode language (default: jp — source ROM byte encoding)")
    args = parser.parse_args()

    project_toml = args.project or find_project_toml()
    if not project_toml:
        print("Error: project.toml not found")
        sys.exit(1)

    if args.def_file:
        # Load .def to get table name
        with open(args.def_file, "r", encoding="utf-8") as f:
            def_data = json.load(f)
        table_name = def_data.get("table", "")
        if not table_name:
            print("Error: .def file missing 'table' field")
            sys.exit(1)
    elif args.table:
        table_name = args.table
    else:
        parser.print_help()
        sys.exit(1)

    toml_path = f"tables/{table_name}.toml"
    if not os.path.exists(toml_path):
        print(f"Error: {toml_path} not found")
        sys.exit(1)

    print(f"Loading {table_name}...")
    model = ScriptModel(table_name, toml_path, project_toml, lang=args.lang)
    print(f"  {len(model.entries)} entries extracted")

    # Load existing .def if present
    if args.def_file:
        print(f"Loading .def: {args.def_file}")
        load_def(model, args.def_file)
    elif os.path.exists(model.def_path):
        print(f"Loading existing .def: {model.def_path}")
        load_def(model, model.def_path)

    # Build API + HTML
    api = Api(model)
    html = build_html(model)

    # Launch pywebview
    import tempfile
    import webview

    tmp = tempfile.NamedTemporaryFile(
        suffix=".html", delete=False, mode="w", encoding="utf-8"
    )
    tmp.write(html)
    tmp.close()

    window = webview.create_window(
        f"Window Def — {table_name}",
        url=f"file://{tmp.name}",
        width=1400,
        height=900,
        min_size=(900, 600),
    )
    api.set_window(window)
    window.expose(
        api.get_entries,
        api.get_windows,
        api.get_window_char_ranges,
        api.get_entry_text,
        api.get_full_text,
        api.get_entry_line_map,
        api.create_window,
        api.update_window,
        api.delete_window,
        api.delete_entry,
        api.restore_entry,
        api.auto_detect_entry,
        api.auto_detect_all,
        api.export,
        api.load_def_file,
        api.get_char_to_byte,
        api.save,
        api.get_info,
        api.set_autosave,
        api.set_preview_lang,
        api.nudge_window,
        api.get_entry_preview,
        api.selection_byte_length,
    )
    webview.start(debug=True)

    os.unlink(tmp.name)
    print("Done.")


if __name__ == "__main__":
    main()
