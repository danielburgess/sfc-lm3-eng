"""Phase 2c: watchCpuMemory on $2116-$2119 writes + DMA. Non-pausing."""
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


def main():
    s = m.connect()
    cmd(s, "clearCpuMemoryWatches")
    cmd(s, "setMemoryWatchEnabled", enabled=True)

    # Register watch BEFORE reset so init writes are captured
    cmd(s, "watchCpuMemory",
        cpuType="Snes",
        ranges=[{"start": 0x2116, "end": 0x2119,
                 "ops": ["write", "dmawrite"]}])

    # Drain any stale events
    for _ in range(5):
        r = cmd(s, "pollMemoryEvents", maxEvents=1024)
        if r.get("data", {}).get("count", 0) == 0:
            break

    cmd(s, "reset")
    # Don't pause. Let it run. Tap START early.
    time.sleep(0.5)
    cmd(s, "setControllerInput", port=0, start=True)
    time.sleep(0.4)
    cmd(s, "clearControllerInput", port=0)
    # Let title init complete
    time.sleep(2.5)

    # Drain all events
    all_events = []
    dropped_total = 0
    high_water = 0
    for _ in range(200):
        r = cmd(s, "pollMemoryEvents", maxEvents=1024)
        if not r.get("success"):
            break
        d = r["data"]
        all_events.extend(d.get("events", []))
        dropped_total += d.get("dropped", 0)
        high_water = max(high_water, d.get("highWater", 0))
        if d.get("count", 0) == 0:
            break

    cmd(s, "clearCpuMemoryWatches")

    print(f"Events: {len(all_events)}, dropped: {dropped_total}, highWater: {high_water}")
    (OUT / "phase2c_events.json").write_text(json.dumps(all_events))

    from collections import Counter
    op_addr = Counter((e["address"], e["opType"]) for e in all_events)
    print("Top (address,opType):")
    for k, v in op_addr.most_common(12):
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
