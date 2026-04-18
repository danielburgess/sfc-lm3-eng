"""Push corrected labels for title-gfx decoder + loader to Mesen via IPC.

Labels identified via static disassembly trace 2026-04-18:
- renderTextFromTable is NOT a text renderer; it's the plane-skip 8BPP tile decoder.
- textBuf_* helpers are decoder internals, not text-buffer logic.
- $01:F060 is the title gfx + palette loader.
- $01:EF85 is a palette-src index translator (was mislabeled advanceDataPointer).
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from mesen_ipc import connect, send_cmd

# (snes_addr_24, new_label, old_label_for_reference, category, comment)
LABELS = [
    (0x00AF6A, 'decodeTileStream',
        'renderTextFromTable', 'VRAM',
        'Plane-skip 8BPP tile decoder. Entry: A=recordID, $12=dir base. Searches 8B records for first-byte==A; reads stream/autostart/chunkcount offsets at +2/+4/+6 (into $08/$0A/$0C); advances $12 by $08; runs command-byte stream.\n\nStream cmds: $00=end, $01..$3F=literal run of N tiles (plane-pairs from chunk store), $40..$7F=combined-immediate (sub-count = cmd AND $3F), $80=repeat-prev-chunk with count from next byte, $81..$FF=delta (A = cmd AND $7F, +$06, emit once).\n\nMISNAMED as renderTextFromTable; has nothing to do with text. Used by loadTitleGfx.'),
    (0x00B005, 'decodeStreamEnd',
        'textBuf_ReturnZero', 'Helper',
        'Decoder stream-end tail. LDA #0; PLP; RTL. Reached on cmd $00.'),
    (0x00B00F, 'decoderCalcChunkSrc',
        'textBuf_CalcTileIndex', 'Helper',
        'Decoder helper: compute 16B chunk source pointer from chunk-index A.\nFor idx<$1000: offset=idx*16, src=$16+offset (bank $18 or $18+1 if high-bit spill).\nFor idx>=$1000: additional bank adjust via (idx>>3) AND $1E.\nFeeds emit16BChunk with $1A = source pointer.'),
    (0x00B033, 'calcChunkSrcHighSpill',
        'textBuf_CalcPtrOffset', 'Helper',
        'Decoder sub: chunk-src calc for idx>=$1000 branch; bank adjust (idx>>3) AND $1E.'),
    (0x00B04B, 'calcChunkSrcLowIdx',
        'textBuf_ShiftIndex', 'Helper',
        'Decoder sub: chunk-src calc for idx<$1000 branch; offset = idx*16 within bank.'),
    (0x00B05F, 'calcChunkSrcLowIdxSpill',
        'textBuf_CalcPtrOffset2', 'Helper',
        'Decoder sub: low-idx path bank-bit spill fixup.'),
    (0x00B06C, 'emit16BChunk',
        'textBuf_CopyData', 'Helper',
        'Decoder emit: copy 16 bytes (8 words) from [$1A] to [$22]; $22 += $10. One plane-pair row of an 8x8 tile.'),
    (0x01F060, 'loadTitleGfx',
        'buildSpellMenuTilemap', 'Init',
        'Title screen gfx + palette loader. Called from $01:E168 boot loop after dispatchGameMode(5).\n1. JSR $EF85 + JSL uploadPaletteWrapper ($0094AB) — palette from $23:F800 table, entry 1 = $23:F80E (512B).\n2. Loop 7x calling decodeTileStream (JSL $00AF6A) with record IDs $0008..$000E; directory $23:8000, chunk store $23:9000.\n3. Each decoded record staged at $7E:2000 then DMAed via dmaToVRAMGeneric to successive VRAM offsets starting at VRAM 0.\n\nMISNAMED as buildSpellMenuTilemap; builds title art not spell menu.'),
    (0x01EF85, 'resolvePaletteSrc',
        'advanceDataPointer', 'Palette',
        'Palette-source index translator. Y=A*4; reads (offset_16, bank_adj_16) from table; computes new $12/$14. Used by loadTitleGfx to resolve palette entry index 1 -> $23:F80E.\n\nMISNAMED as advanceDataPointer.'),
]


def main():
    sock = connect()
    payload = []
    for snes_addr, new_label, old_label, category, comment in LABELS:
        # LoROM: PC = (bank & 0x7F) * 0x8000 + (addr - 0x8000)
        bank = (snes_addr >> 16) & 0xFF
        addr = snes_addr & 0xFFFF
        prg = (bank & 0x7F) * 0x8000 + (addr - 0x8000)
        payload.append({
            'address': hex(prg),
            'memoryType': 'SnesPrgRom',
            'label': new_label,
            'comment': comment,
            'category': category,
        })
        print(f'  {snes_addr:06X} (PRG {prg:06X})  [{category}]  {old_label}  ->  {new_label}')
    r = send_cmd(sock, 'setLabels', labels=payload)
    print('\nsetLabels result:')
    import json
    print(json.dumps(r, indent=2))


if __name__ == '__main__':
    main()
