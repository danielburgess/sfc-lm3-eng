"""Phase 2: trace the title 8BPP decompressor by breakpointing the first VRAM
write into the char-base range ($0000..$00FF), then walking the call chain.

Strategy:
  1. reset
  2. let intro run ~3s; press START once; clear
  3. pause *before* the title init writes to VRAM char base
  4. runUntilVramWrite vramAddress=0x0000 vramEndAddress=0x00FF → pause at
     the CPU instruction that did the first write
  5. getCallstack, getCpuState, disassemble around PC — dump all to JSON
  6. stepTrace 200 instructions to capture the loop body
"""
import sys, json, time
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))
import mesen_ipc as m

OUT = ROOT / "en_data/gfx/raw/title"
OUT.mkdir(parents=True, exist_ok=True)


def cmd(s, c, **kw):
    r = m.send_cmd(s, c, **kw)
    if not r.get("success", False):
        print(f"FAIL {c}: {r}", file=sys.stderr)
    return r


def wait_for_condition(s, probe_cmd, probe_args, check_fn, timeout=8.0, poll=0.1):
    t0 = time.time()
    while time.time() - t0 < timeout:
        r = cmd(s, probe_cmd, **probe_args)
        if r.get("success") and check_fn(r.get("data", {})):
            return r["data"]
        time.sleep(poll)
    return None


def main():
    s = m.connect()

    # --- stage: arrive just before title init ---
    cmd(s, "reset")
    time.sleep(0.3)
    cmd(s, "resume")
    # Intro plays ~3s; bump START so game transitions to title init.
    time.sleep(3.0)
    cmd(s, "setControllerInput", port=0, start=True)
    time.sleep(0.08)
    cmd(s, "clearControllerInput", port=0)
    # Pause explicitly — runUntilVramWrite resumes internally
    cmd(s, "pause")
    time.sleep(0.1)

    # Trap FIRST VRAM write in narrow window at start of char base.
    # NOTE: vramAddress=0 errors; range size >= 0x4000 errors (Mesen format bug).
    # Use $0001..$0100 — catches first decompressor write to char-base region.
    trap = cmd(s, "runUntilVramWrite",
               vramAddress=1,
               vramEndAddress=0x0100,
               timeout=15000)
    (OUT / "phase2_runUntilVramWrite.json").write_text(json.dumps(trap, indent=2))
    if not trap.get("success"):
        print("runUntilVramWrite failed")
        return
    d = trap["data"]
    print("triggered:", d.get("triggered"), "timedOut:", d.get("timedOut"))
    print("pc:", d.get("pc"), "vramAddress:", d.get("vramAddress"))
    if not d.get("triggered"):
        return

    # Already paused at the CPU write site.
    cpu = cmd(s, "getCpuState")["data"]
    stk = cmd(s, "getCallstack")
    (OUT / "phase2_cpu.json").write_text(json.dumps(cpu, indent=2))
    (OUT / "phase2_callstack.json").write_text(json.dumps(stk, indent=2))
    print("CPU  K:PC =", f"{cpu['k']:02X}:{cpu['pc']:04X}",
          "A=", f"{cpu['a']:04X}", "X=", f"{cpu['x']:04X}",
          "Y=", f"{cpu['y']:04X}", "DBR=", f"{cpu['dbr']:02X}")
    if stk.get("success"):
        print("Callstack depth:", len(stk["data"]) if isinstance(stk.get("data"), list) else "?")
        for i, f in enumerate(stk["data"][:12] if isinstance(stk.get("data"), list) else []):
            print(f"  [{i}] src={f.get('source')} tgt={f.get('target')} ret={f.get('returnAddress')}")

    # Disassemble around PC for context
    pc_abs = (cpu["k"] << 16) | cpu["pc"]
    disasm = cmd(s, "getDisassembly",
                 startAddress=hex(max(pc_abs - 0x20, 0)),
                 endAddress=hex(pc_abs + 0x40))
    (OUT / "phase2_disasm_near_pc.json").write_text(json.dumps(disasm, indent=2))

    # stepTrace 200 to capture decoder loop body
    # Ensure paused for inspection
    cmd(s, "pause")
    trace = cmd(s, "stepTrace", count=200, stepType="Step")
    (OUT / "phase2_steptrace.json").write_text(json.dumps(trace, indent=2))
    if trace.get("success") and "states" in trace.get("data", {}):
        states = trace["data"]["states"]
        print(f"Traced {len(states)} instructions")
        # Print first 20 and any that write $2118/$2119
        seen = set()
        hdr = False
        for i, st in enumerate(states[:30]):
            print(f"  [{i:03d}] {st.get('k','??'):02X}:{st.get('pc',0):04X} "
                  f"A={st.get('a',0):04X} X={st.get('x',0):04X} Y={st.get('y',0):04X}")


if __name__ == "__main__":
    main()
