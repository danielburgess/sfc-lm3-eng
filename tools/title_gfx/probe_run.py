"""Phase 2b: automated probe runner.
  1. Reach title with the currently-loaded ROM -> baseline PNG.
  2. Load the probe ROM via IPC loadRom.
  3. Reach title with probe -> probe PNG.
  4. Diff PNGs, report which rows differ (8BPP BG1 is 32x32 tiles).
  5. Reload original ROM.

Usage: python3 tools/title_gfx/probe_run.py <probe_rom_path> [baseline_rom_path]
"""
import sys, json, time
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))
import mesen_ipc as m

OUT = ROOT / "en_data/gfx/raw/title/probes"
OUT.mkdir(parents=True, exist_ok=True)


def cmd(s, c, **kw):
    r = m.send_cmd(s, c, **kw)
    if not r.get("success", False):
        print(f"FAIL {c}: {r.get('error')}", file=sys.stderr)
    return r


def reach_title(s, timeout=8.0):
    cmd(s, "reset")
    time.sleep(0.4)
    cmd(s, "setControllerInput", port=0, start=True)
    time.sleep(0.4)
    cmd(s, "clearControllerInput", port=0)
    t0 = time.time()
    while time.time() - t0 < timeout:
        time.sleep(0.2)
        p = cmd(s, "getPpuState").get("data", {})
        if p.get("bgMode") == 4 and not p.get("forcedBlank"):
            break
    time.sleep(0.3)
    cmd(s, "pause")


def render_bg1(s, path):
    r = cmd(s, "renderBgLayer", layer=1)
    if not r.get("success"):
        print("renderBgLayer failed:", r.get("error"))
        return None
    d = r["data"]
    # Expect base64 png or raw RGBA; handle both
    if "pngBase64" in d:
        import base64
        Path(path).write_bytes(base64.b64decode(d["pngBase64"]))
    elif "png" in d:
        import base64
        Path(path).write_bytes(base64.b64decode(d["png"]))
    elif "rgba" in d or "rgbaBase64" in d:
        import base64
        raw = base64.b64decode(d.get("rgbaBase64") or d["rgba"])
        w, h = d.get("width", 256), d.get("height", 256)
        img = Image.frombytes("RGBA", (w, h), raw)
        img.save(path)
    else:
        print("Unknown renderBgLayer format, keys:", list(d.keys()))
        return None
    return path


def diff_pngs(base_path, probe_path, diff_path):
    a = Image.open(base_path).convert("RGBA")
    b = Image.open(probe_path).convert("RGBA")
    if a.size != b.size:
        print(f"size mismatch: base={a.size} probe={b.size}")
        return
    d = ImageChops.difference(a, b)
    bbox = d.getbbox()
    print(f"Diff bbox: {bbox}")
    # Render a heatmap overlay
    d.save(diff_path)
    # Count changed tiles (8x8 cells)
    w, h = a.size
    tiles_w, tiles_h = w // 8, h // 8
    changed_tiles = []
    pix = d.load()
    for ty in range(tiles_h):
        for tx in range(tiles_w):
            any_diff = False
            for py in range(8):
                for px in range(8):
                    p = pix[tx * 8 + px, ty * 8 + py]
                    if sum(p[:3]) > 0:
                        any_diff = True
                        break
                if any_diff:
                    break
            if any_diff:
                changed_tiles.append((tx, ty))
    print(f"Changed tile cells: {len(changed_tiles)} (out of {tiles_w * tiles_h})")
    if changed_tiles:
        # Group by row
        rows = {}
        for tx, ty in changed_tiles:
            rows.setdefault(ty, []).append(tx)
        for ty in sorted(rows):
            xs = sorted(rows[ty])
            print(f"  row {ty:2d}: cols {xs[0]:2d}-{xs[-1]:2d} ({len(xs)} tiles)")


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: probe_run.py <probe_rom_path> [baseline_rom_path]")
    probe_rom = str(Path(sys.argv[1]).resolve())
    baseline_rom = str(Path(sys.argv[2]).resolve()) if len(sys.argv) > 2 else str(ROOT / "lm3.sfc")

    s = m.connect()

    # Stage 1: reach title on baseline, capture
    print(f"[1/3] Loading baseline: {baseline_rom}")
    cmd(s, "loadRom", path=baseline_rom)
    time.sleep(0.8)
    reach_title(s)
    base_png = OUT / "baseline.png"
    render_bg1(s, str(base_png))
    print(f"  baseline saved: {base_png}")

    # Stage 2: reach title on probe
    print(f"[2/3] Loading probe: {probe_rom}")
    cmd(s, "loadRom", path=probe_rom)
    time.sleep(0.8)
    reach_title(s)
    probe_png = OUT / "probe.png"
    render_bg1(s, str(probe_png))
    print(f"  probe saved: {probe_png}")

    # Stage 3: diff
    print(f"[3/3] Diffing")
    diff_pngs(str(base_png), str(probe_png), str(OUT / "diff.png"))

    # Restore baseline
    cmd(s, "loadRom", path=baseline_rom)
    time.sleep(0.5)
    reach_title(s)
    print("Restored baseline in emulator.")


if __name__ == "__main__":
    main()
