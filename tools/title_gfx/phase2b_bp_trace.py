"""Phase 2 fallback: addBreakpoint on $2118 write (VRAM low-data reg) with
resume + isPaused poll. When hit, inspect PPU.vramAddress; if in char-base
range, record; else resume and try again.
"""
import sys, json, time
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))
import mesen_ipc as m

OUT = ROOT / "en_data/gfx/raw/title"


def cmd(s, c, **kw):
    r = m.send_cmd(s, c, **kw)
    if not r.get("success", False):
        print(f"FAIL {c}: {r.get('error')}", file=sys.stderr)
    return r


def wait_pause(s, timeout=10.0, poll=0.02):
    t0 = time.time()
    while time.time() - t0 < timeout:
        r = cmd(s, "isPaused")
        if r.get("data", {}).get("paused"):
            return True
        time.sleep(poll)
    return False


def main():
    s = m.connect()

    # Clear any stale breakpoints
    cmd(s, "clearBreakpoints")
    cmd(s, "reset")
    time.sleep(0.3)

    # Set breakpoint on write to $2118 (VRAM low data) — catches VRAM uploads.
    # Condition: restrict to low chunk of char base.
    bp = cmd(s, "addBreakpoint",
             address="0x2118",
             endAddress="0x2119",
             memoryType="SnesMemory",
             breakOnExec=False,
             breakOnWrite=True,
             breakOnRead=False,
             enabled=True)
    print("bp:", bp)

    cmd(s, "resume")
    # User-confirmed: press START moments after reset to trigger title load.
    time.sleep(0.5)
    cmd(s, "setControllerInput", port=0, start=True)
    time.sleep(0.5)
    cmd(s, "clearControllerInput", port=0)

    # Poll for BP hits. Goal: find writes to char-base word range $0001..$7000
    # that also land at high frame counts (post-title-START press).
    hits = []
    def h2i(v):
        return int(v, 16) if isinstance(v, str) else v
    for i in range(400):
        if not wait_pause(s, timeout=3.0):
            print(f"[{i}] no pause within 3s — assuming title stable; done")
            break
        ppu = cmd(s, "getPpuState")["data"]
        cpu = cmd(s, "getCpuState")["data"]
        vaddr = h2i(ppu.get("vramAddress", 0))
        pc = h2i(cpu["pc"]); k = h2i(cpu["k"])
        a = h2i(cpu["a"]); x = h2i(cpu["x"]); y = h2i(cpu["y"]); dbr = h2i(cpu["dbr"])
        frame = ppu.get("frameCount", 0)
        k_pc = f"{k:02X}:{pc:04X}"
        hits.append({"i": i, "vram": vaddr, "pc": k_pc,
                     "a": a, "x": x, "y": y, "dbr": dbr, "frame": frame})
        # Looking for: write to char-base ($0001..$6FFF word) AFTER frame 120
        # (post-title-START). Skip boot/tilemap/CGRAM writes.
        in_char_base = 0 < vaddr < 0x7000
        if in_char_base and frame > 100:
            print(f"[{i}] CHAR-BASE HIT vram={vaddr:04X} pc={k_pc} frame={frame}")
            # Don't break yet — grab a few more to characterize loop
            if sum(1 for h in hits if 0 < h["vram"] < 0x7000 and h["frame"] > 100) >= 8:
                break
        cmd(s, "resume")

    (OUT / "phase2b_bp_hits.json").write_text(json.dumps(hits, indent=2))
    print(f"captured {len(hits)} breakpoint hits")
    for h in hits[:20]:
        print(f"  i={h['i']:02d} vram={h['vramAddress']:04X} pc={h['pc']} "
              f"a={h['a']:04X} x={h['x']:04X} y={h['y']:04X} dbr={h['dbr']:02X}")

    if hits:
        # Save callstack of last hit
        cs = cmd(s, "getCallstack")
        (OUT / "phase2b_callstack.json").write_text(json.dumps(cs, indent=2))

    cmd(s, "clearBreakpoints")


if __name__ == "__main__":
    main()
