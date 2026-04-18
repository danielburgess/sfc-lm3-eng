"""Iteratively build + test ROM with progressive table enablement.

Strategy: patches-only baseline boots. Add one table's [section] at a time,
rebuild, boot test. Find the first table that causes hang.

Uses retrotool's `--only` / `--skip` flags (which accept section names) so
no config mutation is needed.
"""
import subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "out"

# Bisect order — matches project.toml [rom.build].order
ORDER = [
    "combat-bytecode-2", "combat-bytecode",
    "cutscene-bytecode-2", "cutscene-bytecode",
    "dialog-1", "dialog-2", "dialog-3", "dialog-4", "dialog-5",
    "info-panels", "interaction-text", "menu-prompts",
    "quiz-questions", "recruit-lines", "scene-desc-name",
    "scene-messages", "unit-attacks",
    "unit-equipment", "unit-items", "unit-names",
    "unit-classes",
]


def build(only_names: set[str] | None):
    """Build ROM via retrotool. Font + asar patches are declared as
    `[[rom.build.sections]]` in project.toml, so no post-pass is needed.

    `only_names=None` → everything; empty set → no script tables (baseline);
    non-empty → --only <comma list>. Inline bin/asar sections run regardless.
    """
    import os
    out = OUT / "_bisect.sfc"
    cmd = ["python3", "-m", "retrotool", "build", "project.toml", "-o", str(out)]
    if only_names is not None:
        filter_arg = ",".join(sorted(only_names)) if only_names else "__none__"
        cmd += ["--only", filter_arg]
    env = os.environ.copy()
    env["PATH"] = f"{ROOT}/disassembly:{env.get('PATH', '')}"
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, env=env)
    if r.returncode != 0:
        print("retrotool build FAILED:")
        print(r.stdout[-2000:])
        print(r.stderr[-2000:])
        return None
    return out


def boot_test(rom_path: Path, runtime: float = 5.0) -> dict:
    """Load rom, reset, resume. Check if game is rendering via PPU state.

    A booting SNES game clears forced-blank ($2100 bit 7) and raises brightness
    to 15, enables BG/OBJ layers via $212C. Cycle advancement alone is not
    sufficient — a game stuck in a forced-blank init loop still advances cycles.
    """
    sys.path.insert(0, str(ROOT))
    import mesen_ipc as m
    s = m.connect()
    m.send_cmd(s, 'loadRom', path=str(rom_path))
    time.sleep(1.5)
    m.send_cmd(s, 'reset')
    time.sleep(0.2)
    m.send_cmd(s, 'resume')
    time.sleep(runtime)
    m.send_cmd(s, 'pause')
    ppu = m.send_cmd(s, 'getPpuState')['data']
    cpu = m.send_cmd(s, 'getCpuState')['data']
    rendering = (not ppu['forcedBlank']) and ppu['screenBrightness'] > 0 and ppu['mainScreenLayers'] > 0
    return {
        'pc': f"{cpu['k']}:{cpu['pc']}",
        'frames': ppu['frameCount'],
        'forcedBlank': ppu['forcedBlank'],
        'brightness': ppu['screenBrightness'],
        'mainLayers': ppu['mainScreenLayers'],
        'bgMode': ppu['bgMode'],
        'rendering': rendering,
    }


USAGE = """bisect_tables.py <cmd> [args]
  baseline              build with no script tables (asar-only)
  through <name>        enable ORDER[:name+1]
  only <name> [<name>]  enable only listed tables
  all                   enable every table in ORDER"""


def main():
    args = sys.argv[1:]
    if not args or args[0] == "baseline":
        only = set()
    elif args[0] == "through":
        if len(args) < 2 or args[1] not in ORDER:
            print(USAGE); sys.exit(2)
        only = set(ORDER[: ORDER.index(args[1]) + 1])
    elif args[0] == "only":
        only = set(args[1:])
    elif args[0] == "all":
        only = None  # no filter → run everything in spec
    else:
        print(USAGE); sys.exit(2)

    rom = build(only)
    if rom is None:
        print("BUILD FAIL"); sys.exit(1)
    r = boot_test(rom)
    status = "RENDER" if r['rendering'] else "BLACK"
    print(f"[{status}] fb={r['forcedBlank']} bright={r['brightness']} mainLyr={r['mainLayers']} bgMode={r['bgMode']} pc={r['pc']} frames={r['frames']}")


if __name__ == "__main__":
    main()
