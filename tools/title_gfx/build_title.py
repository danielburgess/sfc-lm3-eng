"""Build step: PNG -> (title_dir_streams.bin + title_chunks.bin).

Invoked by retrotool via a pre-build hook (or project.toml build handler). Emits
two blobs that `project.toml` inserts at fixed ROM offsets:

  0x118000  title_dir_streams.bin   (skip header + 7x8B records + packed streams)
  0x119000  title_chunks.bin        (flat chunk store, 16 B per chunk)

Round-trip gate:
  png_to_vram(png) -> encode_vram -> synth ROM -> decode_all -> byte-equal to vram

Constraint: len(title_dir_streams.bin) <= 0x1000. If breached, decoder's chunk
base ($23:9000) needs relocation and $01:F060 must be patched.
"""
from __future__ import annotations
import sys, os, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose import png_to_vram
from encoder import encode_vram
from decoder import decode_record, RECORD_IDS


ROM_PATH = '/mnt/crucial/projects/sfc-lm3-eng/lm3.sfc'
PNG_PATH = '/mnt/crucial/projects/sfc-lm3-eng/en_data/gfx/title_bg1_tiles.png'
CGRAM_PATH = '/mnt/crucial/projects/sfc-lm3-eng/en_data/gfx/raw/title/cgram_live.bin'
OUT_DIR = '/mnt/crucial/projects/sfc-lm3-eng/en_data/bin/gfx'
DIR_STREAMS_BIN = os.path.join(OUT_DIR, 'title_dir_streams.bin')
CHUNKS_BIN = os.path.join(OUT_DIR, 'title_chunks.bin')

STREAM_START = 0x0200
VRAM_ADV = 0x0200
# Bank layout after asm/title_chunk_relocate.asm:
#   dir+streams : 0x118000..0x11D000 (bank $23:8000..$23:D000)
#                 cap 0x5000 — $23:D000+ holds battle palette data.
#   chunks      : 0x200000..0x208000 (SNES $40:8000; before script @0x208000)
#                 cap 0x8000.
#   title palette dispatch still at $23:F800 (untouched source ROM).
MAX_DIR_STREAMS_SIZE = 0x5000
MAX_CHUNKS_SIZE = 0x8000
CHUNK_ROM_OFFSET = 0x200000
DIR_ROM_OFFSET = 0x118000


def build_dir_streams(records, skip_header: bytes) -> bytes:
    """Assemble: 8B skip header + 7x8B record table + zero pad + packed streams."""
    out = bytearray(STREAM_START)
    out[0:8] = skip_header
    cur_off = STREAM_START
    for i, rb in enumerate(records):
        rec_off = 8 + i * 8
        struct.pack_into(
            '<HHHH', out, rec_off,
            RECORD_IDS[i], cur_off, rb.autostart, VRAM_ADV,
        )
        cur_off += len(rb.stream)
    # Append streams
    for rb in records:
        out += rb.stream
    return bytes(out)


def build_chunks(store) -> bytes:
    out = bytearray()
    for chunk in store:
        out += chunk
    return bytes(out)


def verify_synth_roundtrip(
    dir_streams: bytes, chunks: bytes, expected_vram: bytes
) -> None:
    """Synth a ROM with the new bins and run the decoder against it."""
    rom = bytearray(open(ROM_PATH, 'rb').read())
    # Expand to cover both regions (chunks now at 0x200000 expansion space).
    need = max(DIR_ROM_OFFSET + len(dir_streams), CHUNK_ROM_OFFSET + len(chunks))
    if len(rom) < need:
        rom.extend(b'\xFF' * (need - len(rom)))

    if len(dir_streams) > MAX_DIR_STREAMS_SIZE:
        raise ValueError(
            f'dir_streams.bin (0x{len(dir_streams):X}) exceeds cap 0x{MAX_DIR_STREAMS_SIZE:X}'
        )
    if len(chunks) > MAX_CHUNKS_SIZE:
        raise ValueError(
            f'chunks.bin (0x{len(chunks):X}) exceeds cap 0x{MAX_CHUNKS_SIZE:X}'
        )
    rom[DIR_ROM_OFFSET:DIR_ROM_OFFSET + len(dir_streams)] = dir_streams
    rom[CHUNK_ROM_OFFSET:CHUNK_ROM_OFFSET + len(chunks)] = chunks

    joined = bytearray()
    for rid in RECORD_IDS:
        data, _ = decode_record(bytes(rom), rid, dir_base=DIR_ROM_OFFSET, chunk_base=CHUNK_ROM_OFFSET)
        joined += data

    joined = bytes(joined)
    assert len(joined) == len(expected_vram), f'decoded len {len(joined)} != expected {len(expected_vram)}'
    if joined != expected_vram:
        for i, (a, b) in enumerate(zip(joined, expected_vram)):
            if a != b:
                raise ValueError(f'mismatch at {i:#06x}: decoded={a:02X} expected={b:02X}')
    print('✓ synth round-trip: decoded VRAM == expected VRAM')


def main():
    print(f'source PNG: {PNG_PATH}')
    vram = png_to_vram(PNG_PATH, CGRAM_PATH)
    print(f'composed VRAM: {len(vram)} B ({len(vram)//64} tiles)')

    store, records, stats = encode_vram(vram)
    print(f'chunks: {stats["chunk_store_count"]} ({stats["chunk_store_bytes"]} B)')
    print(f'records: {stats["record_count"]}  streams total: {stats["stream_bytes_total"]} B')

    skip_header = open(ROM_PATH, 'rb').read()[0x118000:0x118008]
    dir_streams = build_dir_streams(records, skip_header)
    chunks = build_chunks(store)

    print(f'title_dir_streams.bin: {len(dir_streams)} B  (cap 0x{MAX_DIR_STREAMS_SIZE:X})')
    print(f'title_chunks.bin:      {len(chunks)} B  (cap 0x{MAX_CHUNKS_SIZE:X})')

    verify_synth_roundtrip(dir_streams, chunks, vram)

    os.makedirs(OUT_DIR, exist_ok=True)
    open(DIR_STREAMS_BIN, 'wb').write(dir_streams)
    open(CHUNKS_BIN, 'wb').write(chunks)
    print(f'wrote {DIR_STREAMS_BIN}')
    print(f'wrote {CHUNKS_BIN}')


if __name__ == '__main__':
    main()
