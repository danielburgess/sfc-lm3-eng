"""Compare decoder.py output vs vram_live.bin[0x0000..0xE000]."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from decoder import decode_all, RECORD_IDS


def main():
    rom = open('/mnt/crucial/projects/sfc-lm3-eng/lm3.sfc', 'rb').read()
    vram = open('/mnt/crucial/projects/sfc-lm3-eng/en_data/gfx/raw/title/vram_live.bin', 'rb').read()

    decoded_all = decode_all(rom)
    joined = bytearray()
    for rec, data in decoded_all:
        joined += data

    vram_slice = vram[0 : len(joined)]

    matches = sum(1 for a, b in zip(joined, vram_slice) if a == b)
    total = len(joined)
    print(f'Decoded total: {total} bytes ({total//64} tiles)')
    print(f'VRAM slice:    {len(vram_slice)} bytes')
    print(f'Match: {matches}/{total} = {100*matches/total:.2f}%')

    if matches != total:
        mismatches = []
        for i, (a, b) in enumerate(zip(joined, vram_slice)):
            if a != b:
                mismatches.append((i, a, b))
            if len(mismatches) >= 20:
                break
        print('\nFirst 20 mismatches:')
        for off, a, b in mismatches:
            rec_idx = off // 8192
            in_rec = off % 8192
            chunk = in_rec // 16
            in_chunk = in_rec % 16
            tile = in_rec // 64
            print(f'  off=0x{off:04X} rec={rec_idx} tile={tile} chunk={chunk} '
                  f'byte={in_chunk}:  decoded={a:02X}  vram={b:02X}')

        first_bad = mismatches[0][0] if mismatches else 0
        rec_idx = first_bad // 8192
        in_rec = first_bad % 8192
        print(f'\nFirst bad: record {RECORD_IDS[rec_idx]:#06x} at in-rec offset 0x{in_rec:04X}')
    else:
        print('\n✓ PERFECT ROUND-TRIP — decoder matches live VRAM')


if __name__ == '__main__':
    main()
