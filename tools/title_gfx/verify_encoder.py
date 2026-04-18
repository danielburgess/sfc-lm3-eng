"""Verify encode → decode preserves VRAM bytes.

Build a synthetic ROM image from (chunk_store, streams) and run decoder over
it. Compare decoded bytes against the original live VRAM.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import struct
from decoder import decode_record, RECORD_IDS
from encoder import encode_vram


def main():
    rom_orig = open('/mnt/crucial/projects/sfc-lm3-eng/lm3.sfc', 'rb').read()
    vram_live = open(
        '/mnt/crucial/projects/sfc-lm3-eng/en_data/gfx/raw/title/vram_live.bin', 'rb'
    ).read()[: 7 * 8192]

    store, records, stats = encode_vram(vram_live)

    # Synthesize directory + chunk block. Put chunks far enough out that
    # the synthesized streams (larger than original) don't collide.
    DIR_BASE = 0x118000
    CHUNK_BASE = 0x120000  # in bank $24 equivalent

    rom = bytearray(rom_orig)

    # Clear directory region
    for i in range(DIR_BASE, DIR_BASE + 0x1000):
        rom[i] = 0

    # Emit 7 records at offsets 8, 16, ...
    # Stream data starts at dir_base + first_stream_off; keep after record table.
    record_count = len(records)
    stream_start_rel = 0x0200

    # Build directory entries
    cur_stream_off = stream_start_rel
    for i, rb in enumerate(records):
        rid = RECORD_IDS[i]
        record_off = DIR_BASE + 8 + i * 8
        struct.pack_into(
            '<HHHH',
            rom,
            record_off,
            rid,
            cur_stream_off,
            rb.autostart,
            0x0200,
        )
        for j, b in enumerate(rb.stream):
            rom[DIR_BASE + cur_stream_off + j] = b
        cur_stream_off += len(rb.stream)

    # Emit chunk store at CHUNK_BASE.
    for idx, chunk in enumerate(store):
        for j, b in enumerate(chunk):
            rom[CHUNK_BASE + idx * 16 + j] = b

    # Now decode and compare.
    joined = bytearray()
    for rid in RECORD_IDS:
        data, _ = decode_record(bytes(rom), rid, DIR_BASE, CHUNK_BASE)
        joined += data

    matches = sum(1 for a, b in zip(joined, vram_live) if a == b)
    total = len(joined)
    print(f'Decoded total: {total} bytes')
    print(f'VRAM live:     {len(vram_live)} bytes')
    print(f'Match: {matches}/{total} = {100*matches/total:.2f}%')

    if matches != total:
        for i, (a, b) in enumerate(zip(joined, vram_live)):
            if a != b:
                print(f'  first mismatch at 0x{i:04X}: encoded={a:02X} live={b:02X}')
                break
    else:
        print('\n✓ encode→decode roundtrip matches live VRAM')

    # Size summary
    print(f'\nStream bytes total: {stats["stream_bytes_total"]}')
    print(f'Chunk store bytes:  {stats["chunk_store_bytes"]}')
    print(f'Combined payload:   {stats["stream_bytes_total"] + stats["chunk_store_bytes"]} bytes')


if __name__ == '__main__':
    main()
