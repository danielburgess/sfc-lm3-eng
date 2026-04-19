"""Title-screen plane-pair chunk-stream encoder (LM3) — inverse of decoder.py.

Produces a compressed command stream for a sequence of 16-byte chunks.
Given the global chunk store (dedupe index), emit commands greedily:

  Per chunk to emit, prefer (shortest first):
    literal run   -- 0 bytes/chunk amortized (1 cmd byte for up to 63 chunks)
    delta         -- 1 byte/chunk  (idx = current + k; k in 1..$7F)
    repeat        -- ~1 byte/chunk (2 bytes for N repeats; good for N>=2)
    combined-imm  -- 2 bytes/chunk

State:
  autostart : $0A in decoder; next literal-run source chunk idx
  current   : $06 in decoder; set by combined-immediate; referenced by
              repeat ($80) and delta ($81-$FF)

This encoder keeps `autostart` and `current` in lock-step with the decoder so
output round-trips exactly via decode_record().
"""
from __future__ import annotations
from dataclasses import dataclass, field


CMD_END = 0x00
CMD_REPEAT = 0x80
MAX_LITERAL = 0x3F
MAX_REPEAT = 0xFF
MAX_DELTA = 0x7F


@dataclass
class RecordBuild:
    stream: bytearray = field(default_factory=bytearray)
    autostart: int = 0


def build_chunk_store(vram: bytes) -> tuple[list[bytes], dict[bytes, int]]:
    """Dedupe 16-byte chunks from vram, return (store, bytes->idx map).

    Store preserves first-seen order so referencing a chunk by index is stable.
    """
    store: list[bytes] = []
    idx_of: dict[bytes, int] = {}
    for off in range(0, len(vram), 16):
        c = bytes(vram[off : off + 16])
        if c not in idx_of:
            idx_of[c] = len(store)
            store.append(c)
    return store, idx_of


def encode_record(
    chunks_to_emit: list[int],
    autostart_hint: int | None = None,
) -> RecordBuild:
    """Emit a command stream that decodes to chunks_to_emit[...].

    chunks_to_emit is a list of global chunk-store indices (length = # of 16B
    chunks in the record).
    """
    if autostart_hint is not None:
        autostart = autostart_hint
    else:
        autostart = chunks_to_emit[0] if chunks_to_emit else 0

    rb = RecordBuild(autostart=autostart)
    pos = 0
    n = len(chunks_to_emit)
    current = 0  # $06 at entry is 0

    while pos < n:
        c = chunks_to_emit[pos]

        literal_run = 0
        cur = autostart
        while (
            pos + literal_run < n
            and chunks_to_emit[pos + literal_run] == cur
            and literal_run < MAX_LITERAL
        ):
            cur += 1
            literal_run += 1

        repeat_run = 0
        while (
            pos + repeat_run < n
            and chunks_to_emit[pos + repeat_run] == current
            and repeat_run < MAX_REPEAT
        ):
            repeat_run += 1

        delta_ok = 1 <= (c - current) <= MAX_DELTA

        if literal_run >= 2:
            rb.stream.append(literal_run)
            pos += literal_run
            autostart += literal_run
            continue

        if repeat_run >= 2:
            rb.stream.append(CMD_REPEAT)
            rb.stream.append(repeat_run)
            pos += repeat_run
            continue

        if literal_run == 1:
            rb.stream.append(1)
            pos += 1
            autostart += 1
            continue

        if delta_ok:
            delta = c - current
            rb.stream.append(0x80 | delta)
            pos += 1
            continue

        if c <= 0x3FFF:
            high = (c >> 8) & 0x3F
            low = c & 0xFF
            rb.stream.append(0x40 | high)
            rb.stream.append(low)
            current = c
            pos += 1
            continue

        raise ValueError(f'chunk idx {c:#x} exceeds 14-bit combined-immediate range')

    rb.stream.append(CMD_END)
    return rb


def encode_vram(
    vram: bytes,
    record_size: int = 8192,
) -> tuple[list[bytes], list[RecordBuild], dict]:
    """Encode an entire VRAM region as N records of record_size bytes each.

    Returns (chunk_store, [RecordBuild, ...], stats).
    """
    store, idx_of = build_chunk_store(vram)
    records: list[RecordBuild] = []
    total_stream_bytes = 0

    for off in range(0, len(vram), record_size):
        block = vram[off : off + record_size]
        ids = [idx_of[bytes(block[i : i + 16])] for i in range(0, len(block), 16)]
        rb = encode_record(ids, autostart_hint=ids[0])
        records.append(rb)
        total_stream_bytes += len(rb.stream)

    stats = {
        'chunk_store_count': len(store),
        'chunk_store_bytes': len(store) * 16,
        'record_count': len(records),
        'stream_bytes_total': total_stream_bytes,
    }
    return store, records, stats


if __name__ == '__main__':
    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from decoder import decode_all, RECORD_IDS

    rom = open('/mnt/crucial/projects/sfc-lm3-eng/lm3.sfc', 'rb').read()

    decoded = decode_all(rom)
    vram = bytearray()
    for _, data in decoded:
        vram += data

    store, records, stats = encode_vram(bytes(vram))

    print(f'VRAM:           {len(vram):6d} bytes ({len(vram)//64} tiles)')
    print(f'Chunk store:    {stats["chunk_store_count"]:6d} chunks = '
          f'{stats["chunk_store_bytes"]} bytes')
    print(f'Records:        {stats["record_count"]}')
    print(f'Stream total:   {stats["stream_bytes_total"]:6d} bytes')

    print(f'\nPer-record stream sizes:')
    for i, rb in enumerate(records):
        rid = RECORD_IDS[i]
        print(f'  record {rid:#06x}: {len(rb.stream):4d} bytes (autostart={rb.autostart:#06x})')

    original_streams = [
        0x0447 - 0x0200,
        0x0529 - 0x0447,
        0x05F4 - 0x0529,
        0x0820 - 0x05F4,
        0x0A7E - 0x0820,
        0x0CFF - 0x0A7E,
        None,
    ]
    print(f'\nOriginal stream sizes (from directory stream_off deltas):')
    for i, sz in enumerate(original_streams):
        rid = RECORD_IDS[i]
        if sz is None:
            print(f'  record {rid:#06x}: ??? (last)')
        else:
            print(f'  record {rid:#06x}: {sz:4d} bytes')
