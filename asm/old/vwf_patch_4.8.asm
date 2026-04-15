; ============================================================================
; Little Master 3 - VWF Patch v4.8
; ============================================================================
; Font: 1bpp 8x16 sequential (8 top + 8 bottom bytes per char).
; Tile buffer: 2bpp at $7F:B000, 4096 bytes (256 tiles).
;   Layout: 4 rows x 32 cols, each col = 2 tiles (top+bot) = 32 bytes.
;   Row R, Col C: offset = R*1024 + C*32  (top tile at +0, bottom at +16)
; VRAM tiles: $6100+ (tile $20+), 2bpp 8x8, 8 words/tile.
;   Tile index = $20 + R*64 + C*2  (top), +1 (bottom)
; Tilemap: $7E:9000 (top), $7E:9040 (bottom) - game handles DMA via $57.
;
; KEY CHANGES in v4.8:
;   - Tilemap pre-fill: VWFPreRender fills current row with sequential tile
;     indices so every tilemap column maps 1:1 to the correct VRAM tile.
;     This fixes the $09FC / tile_col divergence that caused progressive
;     corruption in per-character dialog rendering.
;   - Buffer preservation: VWF_FLAG stays set across frames for dialog.
;     Only reinit when a new text block is detected ($09FC=0, $09FE=0).
;     Per-character VRAM uploads accumulate in VRAM; bulk upload in
;     VWFPostRender re-uploads entire buffer as safety net.
; ============================================================================

lorom

; ROM expansion to 24 Mbit
org $00FFD7 : db $0C
org $FFFFFF : db $00

; --- VWF State (unused WRAM in $0A30-$0A3B range) ---
!VWF_PX     = $0A30       ; pixel X position (16-bit, absolute)
!VWF_FLAG   = $0A34       ; $A5 = VWF active, $00 = inactive
!VWF_SAVX   = $0A36       ; saved X register (tilemap buffer position)
!VWF_ROW    = $0A3A       ; saved $09FE for newline detection
!TILE_BUF   = $7FB000     ; 2bpp tile buffer (4096 bytes, 4 rows x 32 cols)

; ============================================================================
; Hook 1: $80:C17B (20 bytes, C17B-C18E)
; ============================================================================
org $80C17B
    PLA
    STA.W $0A38
    JSL.L VWFCharHandler
    RTS
    padbyte $EA : pad $80C18F

; ============================================================================
; Hook 2: $80:BC75 (15 bytes, BC75-BC83)
; ============================================================================
org $80BC75
    JSL.L VWFPreRender         ; 4
    JSR.W $BE3B                ; 3 (processText)
    JSL.L VWFPostRender        ; 4
    NOP : NOP : NOP : NOP      ; 4 (pad to 15)

; ============================================================================
; VWF Code - Bank $C0
; ============================================================================
org $C08000

; -------------------------------------------------------------------
; VWFCharHandler
; Called per character. $0A38 = char, X = tilemap buffer offset.
; 16-bit A active on entry.
; -------------------------------------------------------------------
VWFCharHandler:
    PHP : REP #$10              ; save caller P; force 16-bit X/Y
    SEP #$20
    LDA.W !VWF_FLAG
    CMP.B #$A5
    REP #$20
    BEQ .vwf

    ; --- Original tilemap write (non-VWF path) ---
.origPath:
    LDA.W $0A38
    CLC : ADC.W $0A02
    PHA : STA.L $7E9000,X
    PLA : CLC : ADC.W #$0400
    STA.L $7E9040,X
    PLP : RTL

.vwf:
    STX.W !VWF_SAVX

    ; --- Newline detection via $09FE ---
    ; On first char (VWF_ROW=$FFFF) or row change, reset VWF_PX to $09FC*8
    REP #$20
    LDA.W $09FE
    CMP.W !VWF_ROW
    BEQ .sameLine
    ; Row changed (or first char) -> reset VWF_PX to current column
    LDA.W $09FC
    ASL A : ASL A : ASL A      ; * 8 -> pixel position
    STA.W !VWF_PX
    LDA.W $09FE
    STA.W !VWF_ROW
.sameLine:

    ; --- Character filtering ---
    REP #$20
    LDA.W $0A38
    ; Icons/special tiles ($0100+) -> original path
    CMP.W #$0100 : BCS .doOrig
    AND.W #$00FF
    STA.B $00                  ; $00 = char code (16-bit clean)
    ; Past font range ($F0+) -> original path
    CMP.W #$00F0 : BCS .doOrig
    ; Sub-space ($00-$1F) -> original path
    CMP.W #$0020 : BCC .doOrig
    BRA .doRender

.doOrig:
    LDX.W !VWF_SAVX
    JMP .origPath

.doRender:
    ; --- Width lookup ---
    TAX
    SEP #$20
    LDA.L VWFWidthTable,X
    STA.B $02                  ; $02 = pixel width (8-bit)
    REP #$20
    AND.W #$00FF
    BNE .hasWidth

    ; Width 0 -> blank tilemap entry (pre-fill handles it, just return)
    LDX.W !VWF_SAVX
    PLP : RTL

.hasWidth:
    ; --- Compute rendering parameters ---

    ; Row index = ($09FE >> 1) & 3  (4 rows, supports 3+ text lines)
    LDA.W $09FE
    LSR A : AND.W #$0003
    STA.B $04                  ; $04 = row (0-3)

    ; VWF tile column = VWF_PX >> 3  (full 16-bit, no 8-bit mask)
    LDA.W !VWF_PX
    LSR A : LSR A : LSR A
    STA.B $06                  ; $06 = tile col (0-31)

    ; Bounds check: if tile col >= 32, skip render
    CMP.W #$0020 : BCC .inBounds
    JMP .skipRender
.inBounds:

    ; Shift = VWF_PX & 7 (stored 16-bit clean for later LDX)
    LDA.W !VWF_PX
    AND.W #$0007
    STA.B $08                  ; $08 = shift (0-7, 16-bit clean)

    ; Buffer base = row * 1024 + col * 32
    LDA.B $04                  ; row (0-3)
    XBA                        ; * 256
    ASL A : ASL A              ; * 1024
    STA.B $0A
    LDA.B $06                  ; col (0-31)
    ASL A : ASL A : ASL A : ASL A : ASL A  ; * 32
    CLC : ADC.B $0A
    STA.B $0A                  ; $0A = top tile buffer offset

    ; Font offset = char * 16
    LDA.B $00
    ASL A : ASL A : ASL A : ASL A
    STA.B $0C                  ; $0C = font data offset

    ; --- Render 16 rows (0-7 top, 8-15 bottom) ---
    LDY.W #$0000

.rowLoop:
    ; Load font byte for row Y
    REP #$20
    TYA : CLC : ADC.B $0C
    TAX
    SEP #$20
    LDA.L VWFFontData,X
    STA.B $0E                  ; $0E = original font byte (preserved)

    ; Shift right into A (don't modify $0E)
    LDX.B $08                  ; X = shift (16-bit, high byte is 0)
    BEQ .noSR
.srLoop:
    LSR A : DEX : BNE .srLoop
.noSR:
    STA.B $0F                  ; $0F = shifted byte

    ; Compute buffer write position for this row
    REP #$20
    TYA
    CMP.W #$0008
    BCS .botRow
    ; Top tile: pos = $0A + Y * 2
    ASL A : CLC : ADC.B $0A
    BRA .gotPos
.botRow:
    ; Bottom tile: pos = $0A + 16 + (Y-8) * 2
    SEC : SBC.W #$0008
    ASL A : CLC : ADC.B $0A
    CLC : ADC.W #$0010
.gotPos:
    STA.B $10                  ; $10 = buffer position (save for spill calc)
    TAX
    SEP #$20

    ; OR shifted byte into buffer (bp0 and bp1)
    LDA.B $0F : BEQ .skipWrite
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp0
    INX
    LDA.B $0F
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp1
.skipWrite:

    ; --- Spillover to next column ---
    LDA.B $08                  ; shift (8-bit read of low byte)
    BEQ .noSpill
    LDA.B $0E                  ; ORIGINAL font byte (unmodified)
    BEQ .noSpill               ; original was 0 -> nothing to spill

    ; Compute spill: original << (8 - shift)
    SEP #$20
    LDA.B #$08
    SEC : SBC.B $08            ; A = 8 - shift
    REP #$20
    AND.W #$00FF
    TAX                        ; X = left shift count
    SEP #$20
    LDA.B $0E                  ; original font byte
    CPX.W #$0000 : BEQ .noSL
.slLoop:
    ASL A : DEX : BNE .slLoop
.noSL:
    STA.B $0F                  ; $0F = spill byte
    CMP.B #$00                 ; STA doesn't set flags; re-check Z
    BEQ .noSpill               ; spill is 0 -> nothing to write

    ; Next column buffer pos = saved pos + 32
    REP #$20
    LDA.B $10 : CLC : ADC.W #$0020
    ; Bounds check: must stay within buffer (< $1000)
    CMP.W #$1000 : BCS .noSpill
    TAX
    SEP #$20

    LDA.B $0F
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp0
    INX
    LDA.B $0F
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp1
    BRA .noSpill2

.noSpill:
    SEP #$20
.noSpill2:
    INY
    CPY.W #$0010
    BCS .doneRows
    JMP .rowLoop
.doneRows:

.skipRender:
    ; --- Write tilemap entries (palette update) ---
    ; Pre-fill already set correct tile indices. This write updates the
    ; palette/priority ($0A02) for the column where this char was placed.
    ; Uses $09FC as the column (same as pre-fill, so tile index matches).
    REP #$20
    LDX.W !VWF_SAVX

    ; row * 64
    LDA.B $04                  ; row (0-3)
    ASL A : ASL A : ASL A : ASL A : ASL A : ASL A  ; * 64

    ; + $09FC * 2
    CLC : ADC.W $09FC
    CLC : ADC.W $09FC

    ; + $20 base
    CLC : ADC.W #$0020
    PHA
    CLC : ADC.W $0A02          ; palette/priority from control codes
    STA.L $7E9000,X            ; top tilemap

    PLA : INC A                ; +1 for bottom tile
    CLC : ADC.W $0A02          ; palette/priority from control codes
    CLC : ADC.W #$0400         ; +palette 1 offset for bottom row
    STA.L $7E9040,X            ; bottom tilemap

    ; --- Advance VWF pixel position ---
    SEP #$20
    LDA.B $02                  ; width (8-bit)
    REP #$20
    AND.W #$00FF
    CLC : ADC.W !VWF_PX
    STA.W !VWF_PX

    ; --- Restore and return ---
    REP #$20
    LDX.W !VWF_SAVX
    PLP : RTL

; -------------------------------------------------------------------
; VWFPreRender - called before processText
; Displaced: LDA #$0400 / STA $14 / STZ $16
;
; v4.8: Preserves tile buffer across frames for dialog rendering.
; Detects new text blocks via $09FC=0 AND $09FE=0 (set by game's
; waitForButton/clearTextBuffer). Pre-fills tilemap with sequential
; tile indices so every column maps 1:1 to VRAM tile data.
; -------------------------------------------------------------------
org $C08200

VWFPreRender:
    PHP : REP #$10              ; save caller P; force 16-bit X/Y
    ; Displaced instructions from $80:BC75 (always execute)
    REP #$20
    LDA.W #$0400 : STA.B $14
    STZ.B $16

    ; --- Check if we should reinit or preserve ---
    SEP #$20
    LDA.W !VWF_FLAG
    CMP.B #$A5
    BNE .fullInit              ; flag not set -> new text block

    ; Flag is $A5: check if game cleared text state (new dialog/page)
    ; waitForButton resets $09FC=0, $09FE=0 between pages/dialogs
    REP #$20
    LDA.W $09FC
    ORA.W $09FE
    BNE .preserve              ; either non-zero -> continuing dialog
    ; Both zero -> new text block (after clear)

.fullInit:
    REP #$20
    ; Init VWF_PX to $09FC * 8 (align with tilemap starting column)
    LDA.W $09FC
    ASL A : ASL A : ASL A      ; * 8
    STA.W !VWF_PX

    ; Sentinel for first-char newline detection
    LDA.W #$FFFF
    STA.W !VWF_ROW

    SEP #$20
    LDA.B #$A5 : STA.W !VWF_FLAG
    REP #$20

    ; Clear tile buffer ($7F:B000, 4096 bytes)
    LDX.W #$0000
    LDA.W #$0000
-   STA.L !TILE_BUF,X
    INX : INX
    CPX.W #$1000 : BCC -

.preserve:
    ; --- Tilemap pre-fill: sequential tile indices for current row ---
    ; This ensures every tilemap column C maps to VRAM tile at buffer
    ; column C, regardless of $09FC / VWF_PX divergence.

    ; Compute VWF row = ($09FE >> 1) & 3
    REP #$20
    LDA.W $09FE
    LSR A : AND.W #$0003       ; vwf_row (0-3)

    ; Tile base = $20 + vwf_row * 64
    ASL A : ASL A : ASL A : ASL A : ASL A : ASL A  ; * 64
    CLC : ADC.W #$0020         ; + base tile $20

    ; Build first top tilemap entry: tile_base + $0A02
    CLC : ADC.W $0A02
    STA.B $08                  ; $08 = current top entry (tile + palette)

    ; Tilemap buffer offset = $09FE * $40
    LDA.W $09FE
    ASL A : ASL A : ASL A : ASL A : ASL A : ASL A  ; * 64 ($40)
    TAX                        ; X = tilemap buffer position

    ; Fill 32 columns with sequential tile pairs
    LDY.W #$0020               ; 32 iterations
.prefillLoop:
    LDA.B $08
    STA.L $7E9000,X            ; top tilemap entry
    INC A                      ; +1 for bottom tile
    CLC : ADC.W #$0400         ; bottom palette offset
    STA.L $7E9040,X            ; bottom tilemap entry
    ; Advance to next tile pair (+2)
    INC.B $08 : INC.B $08
    INX : INX
    DEY : BNE .prefillLoop

    PLP : RTL

; -------------------------------------------------------------------
; VWFPostRender - called after processText
; Bulk uploads all VWF tiles. Does NOT clear VWF_FLAG so buffer
; persists across dialog frames.
; Displaced: REP #$20 / LDA $0A16
; -------------------------------------------------------------------
org $C08300

VWFPostRender:
    PHP : REP #$10              ; save caller P; force 16-bit X/Y
    SEP #$20
    LDA.W !VWF_FLAG
    CMP.B #$A5
    BEQ .doUpload
    JMP .done

.doUpload:
    ; Bulk VRAM upload with NMI disabled
    SEI
    LDA.B #$00 : STA.W $4200  ; disable NMI
    LDA.B #$80 : STA.W $2100  ; forced blank
    LDA.B #$80 : STA.W $2115  ; VRAM word increment on high write

    ; Upload entire tile buffer to VRAM $6100 (tile $20)
    REP #$20
    LDA.W #$6100 : STA.W $2116
    SEP #$20

    LDX.W #$0000
    LDY.W #$0800              ; 2048 word writes = 4096 bytes
.bulkLoop:
    LDA.L !TILE_BUF,X : STA.W $2118 : INX
    LDA.L !TILE_BUF,X : STA.W $2119 : INX
    DEY : BNE .bulkLoop

    ; NOTE: VWF_FLAG intentionally NOT cleared here.
    ; For dialog, flag stays $A5 so VWFPreRender preserves the buffer
    ; across frames. For static text, the next clearTextBuffer /
    ; waitForButton resets $09FC/$09FE to 0, which VWFPreRender detects
    ; as a new text block and reinits.

    ; Restore display + NMI (PLP at RTL restores caller I flag)
    LDA.B $58 : STA.W $2100
    LDA.B #$81 : STA.W $4200

.done:
    ; Displaced instructions from $80:BC7F
    REP #$20
    LDA.W $0A16
    PLP : RTL

; ============================================================================
; Data
; ============================================================================
VWFWidthTable:
    incbin "font/widths.bin"

VWFFontData:
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    incbin "font/font_1bpp.bin"

print "VWF v4.8 end: $", pc
