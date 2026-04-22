"""Shift window[N] start back by 1 byte for windows currently at +7 from
the backup. Leaves windows already at +6 (user-fixed) and other shifts alone.
"""
from __future__ import annotations
import re
from pathlib import Path

ENTRY_RE = re.compile(r'^<<\$\d+:(\d+)\[\$\d+\]>>\s*$')
WINDOW_RE = re.compile(r'^<<<window\[(\d+)\]:\$([0-9A-Fa-f]+)-\$([0-9A-Fa-f]+)>>>\s*$')

BAK = 'en_data/scripts/cutscene-bytecode-2.txt.bak'
CUR = 'en_data/scripts/cutscene-bytecode-2.txt'


def parse_starts(path):
    out = {}
    cur = None
    for line in Path(path).read_text(encoding='utf-8').splitlines():
        me = ENTRY_RE.match(line)
        if me:
            cur = int(me.group(1)); continue
        mw = WINDOW_RE.match(line)
        if mw and cur is not None:
            out[(cur, int(mw.group(1)))] = (int(mw.group(2), 16), int(mw.group(3), 16))
    return out


def main():
    bak = parse_starts(BAK)
    need_fix = set()
    for k, (os_, _) in bak.items():
        pass
    # Identify windows that currently show start == backup_start + 7
    cur_starts = parse_starts(CUR)
    for k, (cs, _) in cur_starts.items():
        if k in bak and cs == bak[k][0] + 7:
            need_fix.add(k)

    print(f'windows to fix (+7 -> +6): {len(need_fix)}')

    lines = Path(CUR).read_text(encoding='utf-8').splitlines(keepends=True)
    out_lines = []
    cur_entry = None
    changed = 0
    for line in lines:
        me = ENTRY_RE.match(line)
        if me:
            cur_entry = int(me.group(1))
            out_lines.append(line); continue
        mw = WINDOW_RE.match(line)
        if mw and cur_entry is not None:
            win = int(mw.group(1))
            s = int(mw.group(2), 16); e = int(mw.group(3), 16)
            if (cur_entry, win) in need_fix:
                new_s = s - 1
                out_lines.append(f'<<<window[{win}]:${new_s:04X}-${e:04X}>>>\n')
                changed += 1
                continue
        out_lines.append(line)

    Path(CUR).write_text(''.join(out_lines), encoding='utf-8')
    print(f'updated {changed} window headers')


if __name__ == '__main__':
    main()
