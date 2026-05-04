#!/usr/bin/env python3
"""Probe VWF state + BG3 tilemap on file-info menu (build $F327)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from mesen_ipc import connect, send_cmd, read_mem


def read_vram(sock, byte_off, length):
    return read_mem(sock, 'SnesVideoRam', byte_off, length)


def read_wram_addr(sock, snes_addr, length):
    """SNES bank:addr → WRAM offset. $7E:xxxx = 0x0xxxx, $7F:xxxx = 0x1xxxx."""
    bank = (snes_addr >> 16) & 0xFF
    addr = snes_addr & 0xFFFF
    if bank == 0x7E:
        off = addr
    elif bank == 0x7F:
        off = 0x10000 | addr
    else:
        raise ValueError(f'Not a WRAM bank: {bank:02X}')
    return read_mem(sock, 'SnesWorkRam', off, length)


def words(data):
    return [data[i] | (data[i + 1] << 8) for i in range(0, len(data) - 1, 2)]


def dump_words(label, data, per_row=16):
    ws = words(data)
    print(f'\n--- {label} ({len(ws)} words) ---')
    for i in range(0, len(ws), per_row):
        row = ws[i:i + per_row]
        print(f'  +{i*2:04X}  ' + ' '.join(f'{w:04X}' for w in row))


def vwf_state(sock):
    print('\n========== VWF state at $7F:5D00..$5DBD ==========')
    s = read_wram_addr(sock, 0x7F5D00, 0xC0)
    labels = {
        0x00: 'DIRTY',
        0x02: 'DMA_LO',
        0x04: 'DMA_HI',
        0x06: 'PREV_COL',
        0x08: 'PX',
        0x0A: 'FLAG',
        0x0C: 'SAVX',
        0x0E: 'ROW',
        0x10: 'CHAR',
        0x12: 'INVERT',
        0x14: 'TEXT_LO',
        0x15: 'TEXT_HI',
        0x16: 'TEXT_BNK',
        0x17: 'LAST_INVERT',
        0x18: 'LAST_TEXT_LO',
        0x19: 'LAST_TEXT_HI',
        0x1A: 'LAST_TEXT_BNK',
        0x1B: 'SCENE_INIT_PENDING',
        0x1C: 'BLINK',
        0x32: 'TMP_DREW',
        0xBA: 'POOL_NEXT',
        0xBC: 'CELL_INIT',
        0xBD: 'LAST_COL',
    }
    for off, name in sorted(labels.items()):
        if off + 1 < len(s):
            w = s[off] | (s[off + 1] << 8)
            print(f'  $7F:5D{off:02X}  {name:<18}  ${w:04X}  ({s[off]:02X} {s[off+1]:02X})')
        elif off < len(s):
            print(f'  $7F:5D{off:02X}  {name:<18}  ${s[off]:02X}')


def bg3_tilemap(sock):
    """BG3 tilemap is at VRAM bytes $F800..$FFFF (= words $7C00..$7FFF)."""
    print('\n========== BG3 tilemap @ VRAM $F800..$FFFF (32x32, word entries) ==========')
    raw = read_vram(sock, 0xF800, 0x800)  # 2048 bytes = 1024 words = 32x32
    ws = words(raw)
    # 32 wide x 32 tall
    print('  col→ ', ' '.join(f'{c:>4X}' for c in range(32)))
    for r in range(32):
        row = ws[r * 32:(r + 1) * 32]
        # Show tile_id (low 10 bits) only for compactness; mark non-zero
        cells = []
        for w in row:
            tid = w & 0x3FF
            if w == 0:
                cells.append('....')
            elif tid == 0:
                cells.append(f'.{w >> 10:03X}')  # palette/priority bits only
            else:
                cells.append(f'{tid:04X}')
        print(f'  R{r:02X}  ' + ' '.join(cells))


def vwf_canvas_summary(sock):
    """Canvas at $7F:7000..$7FFF = 4 KB. Show non-blank cells (cell stride = 16 B)."""
    print('\n========== Canvas $7F:7000..$7FFF — non-blank cells only ==========')
    raw = read_wram_addr(sock, 0x7F7000, 0x1000)
    invert = read_wram_addr(sock, 0x7F5D12, 1)[0]
    blank = 0xFF if invert else 0x00
    n_cells = 256
    found = 0
    for c in range(n_cells):
        cell_bytes = raw[c * 16:(c + 1) * 16]
        non_blank_count = sum(1 for b in cell_bytes if b != blank)
        if non_blank_count > 0:
            row = c // 32
            col = c % 32
            tid = 0x40 + c
            print(f'  cell[{c:3d}] r={row} c={col} tile_id=${tid:03X}  '
                  + ' '.join(f'{b:02X}' for b in cell_bytes))
            found += 1
            if found > 20:
                print('  ... (truncated)')
                break
    if found == 0:
        print(f'  (all blank — invert={invert:02X})')


def vram_wb_region(sock):
    """VRAM $C400..$CFF0 = WB DMA region (tile $40..$FF)."""
    print('\n========== VRAM WB region $C400..$CFF0 (tile $40..$FF) — non-blank tiles only ==========')
    raw = read_vram(sock, 0xC400, 0xC00)  # 3072 bytes = 192 tiles × 16 B
    found = 0
    for t in range(192):
        tile_bytes = raw[t * 16:(t + 1) * 16]
        # Tile is "blank" if all bytes are $FF or all $00
        if all(b == 0xFF for b in tile_bytes) or all(b == 0x00 for b in tile_bytes):
            continue
        tid = 0x40 + t
        print(f'  tile $${tid:03X}  bytes=' + ' '.join(f'{b:02X}' for b in tile_bytes))
        found += 1
        if found > 20:
            print('  ... (truncated)')
            break
    if found == 0:
        print('  (all tiles blank)')


def engine_text_state(sock):
    """$09FC = engine col, $09FE = engine row, $0A02 = palette/priority."""
    s = read_wram_addr(sock, 0x7E0900, 0x110)
    print('\n========== Engine text state ==========')
    fields = {
        0xFC: ('$09FC col', 2),
        0xFE: ('$09FE row', 2),
        0x100: ('$0A00', 2),
        0x102: ('$0A02 pal/pri', 2),
    }
    for off, (name, w) in fields.items():
        v = s[off]
        if w == 2:
            v |= s[off + 1] << 8
        print(f'  $7E:09{off:02X}  {name:<18}  ${v:04X}')


def cpu_state(sock):
    r = send_cmd(sock, 'getCpuState')
    if r.get('success'):
        cs = r['data']
        print(f"\n========== CPU @ PC={cs.get('pc', '?')}  P={cs.get('p', '?')}  "
              f"A={cs.get('a', '?')}  X={cs.get('x', '?')}  Y={cs.get('y', '?')} ==========")


def main():
    sock = connect()
    s = send_cmd(sock, 'getStatus')
    print(f"paused={s['data']['paused']}  rom={s['data']['romPath']}")
    cpu_state(sock)
    vwf_state(sock)
    engine_text_state(sock)
    bg3_tilemap(sock)
    vwf_canvas_summary(sock)
    vram_wb_region(sock)


if __name__ == '__main__':
    main()
