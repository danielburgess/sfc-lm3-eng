; Title chunk-base relocation.
;
; loadTitleGfx @ $01:F060 loads the plane-pair chunk-store base into
; zero-page ($18:$16) before JSL decodeTileStream. Original: $23:9000.
;
; Bank $23 is NOT safe to extend into: $23:D000..$23:F800 holds battle-scene
; palette data (read by bank80 @ $00:80887A, LDA #$0023 / LDA #$D000 +
; $096E offset, JSL uploadPaletteWrapper — 8 colors per scene into CGRAM
; idx 8). Overwriting that region with chunks corrupts in-battle colors.
;
; Solution: move chunks entirely out of bank $23 to file 0x200000
; (SNES $40:8000) — the first slot of expansion space, before script data
; at 0x208000. Directory + command streams stay at $23:8000..$23:A000
; (0x2000 B cap, plenty); bank $23 chunk region $23:A000..$23:F800 goes
; back to pass-through source ROM (dead data, no readers after this patch).
;
; Two byte edits inside `evtTilemap_Init @ $01:F08F`:
;   F09D : LDA.W #$0023 immediate low byte (chunk bank)  $23 -> $40
;   F0A3 : LDA.W #$9000 immediate high byte (chunk offset hi)  $90 -> $80

lorom

; Chunk bank: F09C A9 23 00  (LDA.W #$0023).  F09D holds low byte $23.
org $01F09D
    db $40

; Chunk offset: F0A1 A9 00 90  (LDA.W #$9000).  F0A3 holds high byte $90.
org $01F0A3
    db $80
