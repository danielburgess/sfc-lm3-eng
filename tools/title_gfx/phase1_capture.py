"""Phase 1: reach title, snapshot BG state + tilemap + palette + live render.

Outputs to en_data/gfx/raw/title/ and en_data/gfx/.
"""
import sys, json, time, base64, struct
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))
import mesen_ipc as m

OUT_RAW = ROOT / "en_data/gfx/raw/title"
OUT_GFX = ROOT / "en_data/gfx"
OUT_RAW.mkdir(parents=True, exist_ok=True)


def cmd(s, c, **kw):
    r = m.send_cmd(s, c, **kw)
    if not r.get("success", False):
        print(f"FAIL {c} {kw}: {r}", file=sys.stderr)
    return r


def step_frames(s, n):
    cmd(s, "step", stepType="PpuFrame", count=n)


def reach_title(s):
    """Reset. Intro plays. Press START ONCE during intro to skip to title.

    Title is mode 4, BG1-only. After title, game waits for START to enter menu —
    don't press again once title shown.
    """
    cmd(s, "reset")
    time.sleep(0.3)
    cmd(s, "resume")
    # Let intro run ~3s then bump START once
    time.sleep(3.0)
    cmd(s, "setControllerInput", port=0, start=True)
    time.sleep(0.1)
    cmd(s, "clearControllerInput", port=0)
    # Poll for title (bgMode==4). Bail after 8s.
    for _ in range(40):
        time.sleep(0.2)
        p = cmd(s, "getPpuState")["data"]
        if p.get("bgMode") == 4 and not p.get("forcedBlank"):
            break
    cmd(s, "pause")


def main():
    s = m.connect()
    reach_title(s)

    ppu = cmd(s, "getPpuState")["data"]
    bg = cmd(s, "getBgState")
    # Save raw dicts to JSON for record
    (OUT_RAW / "phase1_ppu.json").write_text(json.dumps(ppu, indent=2))
    (OUT_RAW / "phase1_bg.json").write_text(json.dumps(bg, indent=2))
    print("PPU:", json.dumps({k: ppu.get(k) for k in (
        "bgMode", "forcedBlank", "screenBrightness",
        "mainScreenLayers", "subScreenLayers", "frameCount")}))
    if bg.get("success") and "data" in bg:
        print("BG data keys:", list(bg["data"].keys()))

    # Tilemap BG1
    tm = cmd(s, "getTilemap", layer=1, startX=0, startY=0, width=32, height=32)
    (OUT_RAW / "phase1_tilemap_bg1.json").write_text(json.dumps(tm, indent=2))

    # CGRAM
    cg = cmd(s, "getCgram")
    (OUT_RAW / "phase1_cgram.json").write_text(json.dumps(cg, indent=2))

    # RenderBg layer 1
    rb = cmd(s, "renderBgLayer", layer=1)
    if rb.get("success") and "rgbaBase64" in rb.get("data", {}):
        raw = base64.b64decode(rb["data"]["rgbaBase64"])
        w = rb["data"].get("width", 256)
        h = rb["data"].get("height", 224)
        _write_png(OUT_GFX / "title_bg1_live.png", w, h, raw)
        print(f"Wrote title_bg1_live.png {w}x{h}")
    else:
        print("renderBgLayer missing rgba", rb)

    # VRAM + WRAM dump
    vr = cmd(s, "readMemory", memoryType="SnesVideoRam", address="0x0", length=0x10000)
    if vr.get("success"):
        vb = bytes(vr["data"]["bytes"])
        (OUT_RAW / "vram_live.bin").write_bytes(vb)
        print(f"VRAM {len(vb)}B saved")

    cg2 = cmd(s, "readMemory", memoryType="SnesCgRam", address="0x0", length=0x200)
    if cg2.get("success"):
        cb = bytes(cg2["data"]["bytes"])
        (OUT_RAW / "cgram_live.bin").write_bytes(cb)
        print(f"CGRAM {len(cb)}B saved")

    # DMA state snapshot (not very useful at pause but record)
    dma = cmd(s, "getDmaState")
    (OUT_RAW / "phase1_dma.json").write_text(json.dumps(dma, indent=2))


def _write_png(path, w, h, rgba):
    import zlib
    def chunk(tag, data):
        crc = zlib.crc32(tag + data).to_bytes(4, "big")
        return struct.pack(">I", len(data)) + tag + data + crc
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    raw_scan = b""
    stride = w * 4
    for y in range(h):
        raw_scan += b"\x00" + rgba[y*stride:(y+1)*stride]
    idat = zlib.compress(raw_scan, 9)
    path.write_bytes(sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b""))


if __name__ == "__main__":
    main()
