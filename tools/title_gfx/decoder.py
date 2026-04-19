"""Title-screen plane-pair chunk-stream decoder (LM3).

Translation of `decodeTileStream` @ $00:AF6A (was `renderTextFromTable`).
Directory @ $23:8000, stream_offsets within same bank, chunk store @ $23:9000.

Decoder model:
  dir_base  = $23:8000 (file 0x118000)
  chunk_base = $23:9000 (file 0x119000)

  For record_id A: search 8-byte records starting at dir_base + 8 for
  first-word == A. Record layout:
    +0  id         (uint16 LE)
    +2  stream_off (uint16 LE)  -- stream lives at dir_base + stream_off
    +4  autostart  (uint16 LE)  -- literal-run chunk counter initial value
    +6  vram_adv   (uint16 LE)  -- likely DMA length / VRAM step; not used here

  Two chunk-idx channels:
    - $0A (autostart counter): advanced by literal-run commands
    - $06 (random-access):     set only by $40-$7F combined-immediate

  Command stream ($12 = dir_base + stream_off):
    $00               end of record
    $01..$3F  (N)     literal run: emit chunks [$0A .. $0A+N-1]; $0A += N
    $40..$7F  (CMD)   combined-immediate: read next byte LOW; idx = ((CMD&$3F)<<8)|LOW;
                      emit chunk[idx]; $06 = idx
    $80       (CMD)   repeat: read next byte N; emit chunk[$06] N times
    $81..$FF  (CMD)   delta: emit chunk[(CMD&$7F) + $06]; $06 NOT updated

  Each emit copies 16 bytes from chunk_base[idx*16] to dst; dst += 16.
  A complete 8BPP 8x8 tile is 4 consecutive chunks (4 plane-pair rows).
"""
from __future__ import annotations
import struct
from dataclasses import dataclass

DIR_BASE = 0x118000
CHUNK_BASE = 0x119000
RECORD_IDS = (0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E)


@dataclass
class Record:
    id: int
    stream_off: int
    autostart: int
    vram_adv: int
    file_offset: int


def find_record(rom: bytes, record_id: int, dir_base: int = DIR_BASE) -> Record:
    y = 8
    while True:
        word = struct.unpack_from('<H', rom, dir_base + y)[0]
        if word == 0:
            raise KeyError(f'record {record_id:#06x} not found')
        if word == record_id:
            s_off, autostart, vram_adv = struct.unpack_from('<HHH', rom, dir_base + y + 2)
            return Record(
                id=record_id,
                stream_off=s_off,
                autostart=autostart,
                vram_adv=vram_adv,
                file_offset=dir_base + y,
            )
        y += 8


def _chunk_bytes(rom: bytes, chunk_base: int, idx: int) -> bytes:
    return rom[chunk_base + idx * 16 : chunk_base + idx * 16 + 16]


def decode_record(
    rom: bytes,
    record_id: int,
    dir_base: int = DIR_BASE,
    chunk_base: int = CHUNK_BASE,
) -> tuple[bytearray, list[tuple]]:
    rec = find_record(rom, record_id, dir_base)
    out = bytearray()
    trace: list[tuple] = []
    autostart = rec.autostart
    current = 0
    pos = dir_base + rec.stream_off
    while True:
        cmd = rom[pos]
        pos += 1
        if cmd == 0x00:
            trace.append(('end', pos - 1))
            break
        if cmd < 0x40:
            n = cmd
            start = autostart
            for _ in range(n):
                out += _chunk_bytes(rom, chunk_base, autostart)
                autostart += 1
            trace.append(('literal', pos - 1, n, start))
        elif cmd < 0x80:
            low = rom[pos]
            pos += 1
            idx = ((cmd & 0x3F) << 8) | low
            out += _chunk_bytes(rom, chunk_base, idx)
            current = idx
            trace.append(('combined', pos - 2, idx))
        elif cmd == 0x80:
            n = rom[pos]
            pos += 1
            for _ in range(n):
                out += _chunk_bytes(rom, chunk_base, current)
            trace.append(('repeat', pos - 2, n, current))
        else:
            idx = (cmd & 0x7F) + current
            out += _chunk_bytes(rom, chunk_base, idx)
            trace.append(('delta', pos - 1, cmd & 0x7F, idx))
    return out, trace


def decode_all(rom: bytes) -> list[tuple[Record, bytearray]]:
    result = []
    for rid in RECORD_IDS:
        rec = find_record(rom, rid)
        data, _ = decode_record(rom, rid)
        result.append((rec, data))
    return result


if __name__ == '__main__':
    import sys
    rom_path = sys.argv[1] if len(sys.argv) > 1 else '/mnt/crucial/projects/sfc-lm3-eng/lm3.sfc'
    rom = open(rom_path, 'rb').read()
    print(f'ROM size: {len(rom):#x}')
    print(f'Directory @ {DIR_BASE:#x}, chunks @ {CHUNK_BASE:#x}\n')
    total = 0
    for rid in RECORD_IDS:
        rec = find_record(rom, rid)
        data, trace = decode_record(rom, rid)
        print(f'Record {rid:#06x}: stream_off={rec.stream_off:#06x} '
              f'autostart={rec.autostart:#06x} vram_adv={rec.vram_adv:#06x} '
              f'-> {len(data)} bytes ({len(data)//16} chunks, {len(data)//64} tiles)  '
              f'[{len(trace)} cmds]')
        total += len(data)
    print(f'\nTotal decoded: {total} bytes = {total//16} chunks = {total//64} tiles')
