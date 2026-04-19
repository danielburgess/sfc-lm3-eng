"""Phase 2b Tier 4: watchCpuMemory READ-watch a ROM window, reach title,
report PCs that read within the window. Non-pausing (doesn't freeze game).

Usage: python3 tools/title_gfx/phase2b_readwatch.py <snes_addr> <length>
  e.g. python3 tools/title_gfx/phase2b_readwatch.py 0x238820 868

Prints top (address, PC, opType) triples.
"""
import sys, json, time
from pathlib import Path
from collections import Counter

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
            return True
    return False


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: phase2b_readwatch.py <snes_addr_hex> <length>")
    start = int(sys.argv[1], 0)
    length = int(sys.argv[2], 0)
    end = start + length - 1

    s = m.connect()

    # Clear watches, arm read-watch
    cmd(s, "clearCpuMemoryWatches")
    cmd(s, "setMemoryWatchEnabled", enabled=True)

    # Try SnesMemory CPU bus view first
    r = cmd(s, "watchCpuMemory",
            cpuType="Snes",
            ranges=[{"start": start, "end": end, "ops": ["read", "dmaread"]}])
    if not r.get("success"):
        print("SnesMemory watch failed, retrying without dmaread")
        r = cmd(s, "watchCpuMemory",
                cpuType="Snes",
                ranges=[{"start": start, "end": end, "ops": ["read"]}])
        if not r.get("success"):
            sys.exit("both watchCpuMemory attempts failed")

    # Drain any stale events
    for _ in range(5):
        rr = cmd(s, "pollMemoryEvents", maxEvents=1024)
        if rr.get("data", {}).get("count", 0) == 0:
            break

    print(f"Armed watchCpuMemory on ${start:06X}..${end:06X} ({length}B). Reaching title...")
    ok = reach_title(s)
    if not ok:
        print("Failed to reach title (bgMode != 4)")
    time.sleep(1.0)

    # Drain events after title reached
    all_events = []
    dropped = 0
    high_water = 0
    for _ in range(200):
        rr = cmd(s, "pollMemoryEvents", maxEvents=2048)
        if not rr.get("success"):
            break
        d = rr["data"]
        all_events.extend(d.get("events", []))
        dropped += d.get("dropped", 0)
        high_water = max(high_water, d.get("highWater", 0))
        if d.get("count", 0) == 0:
            break

    cmd(s, "clearCpuMemoryWatches")
    # Leave emulator paused at title for inspection
    cmd(s, "pause")

    print(f"\n=== Results ===")
    print(f"Events captured: {len(all_events)}, dropped: {dropped}, highWater: {high_water}")
    if not all_events:
        print("!! NO READS of this range during title init. The data is NOT consumed when reaching title.")
        return

    # Stats
    by_pc = Counter(e.get("programCounter", 0) for e in all_events)
    by_addr = Counter(e.get("address", 0) for e in all_events)
    by_op = Counter(e.get("opType", "?") for e in all_events)

    print(f"\nTop 10 PCs:")
    for pc, n in by_pc.most_common(10):
        print(f"  PC ${pc:06X}: {n} reads")
    print(f"\nTop 10 target addresses:")
    for a, n in by_addr.most_common(10):
        print(f"  addr ${a:06X}: {n} reads")
    print(f"\nOp types:")
    for op, n in by_op.most_common():
        print(f"  {op}: {n}")

    # Save raw events
    out = OUT / f"readwatch_{start:06X}_{length}.json"
    out.write_text(json.dumps(all_events[:5000], indent=2))
    print(f"\nRaw events -> {out}")


if __name__ == "__main__":
    main()
