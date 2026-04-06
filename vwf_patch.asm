; ============================================================================
; Little Master 3 - VWF Patch v3
; ============================================================================
; Font: 4bpp 8x8 tiles. Top tiles at VRAM $3000, bottom at VRAM $7000.
; Tilemap: top = char|$2000, bottom = char|$2400. $0A02 = $2000 (priority).
; ============================================================================

lorom

org $00FFD7 : db $0C
org $FFFFFF : db $00

!VWF_PX     = $0A30
!VWF_TILE   = $0A32
!VWF_FLAG   = $0A34
!VWF_SAVX   = $0A36
!TILE_BUF   = $7FB000
!TMAP_TOP   = $7E9000
!TMAP_BOT   = $7E9040

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
    JSR.W $BE3B                ; 3
    JSL.L VWFPostRender        ; 4
    NOP : NOP : NOP : NOP      ; 4 (=15 total)

; ============================================================================
; VWF Code - Bank $C0
; ============================================================================
org $C08000

VWFCharHandler:
    SEP #$20
    LDA.W !VWF_FLAG
    CMP.B #$A5
    REP #$20
    BEQ .vwf

    ; --- Original path ---
.origPath:
    LDA.W $0A38
    CLC : ADC.W $0A02
    PHA : STA.L !TMAP_TOP,X
    PLA : CLC : ADC.W #$0400
    STA.L !TMAP_BOT,X
    RTL

.vwf:
    ; Save tilemap X
    STX.W !VWF_SAVX

    ; Detect new line / page break via X position changes.
    ; Normal char advance = 2 bytes.
    ; X increase > 4 = new line (next tilemap row).
    ; X decrease = page break ([cls]) - full VWF state reset.
    ; $0A3A = $FFFF = first char sentinel - skip detection.
    REP #$20
    LDA.W $0A3A
    CMP.W #$FFFF
    BEQ .firstChar             ; first character, skip detection
    TXA
    SEC : SBC.W $0A3A          ; A = current X - previous X
    BCC .pageBreak             ; carry clear = X decreased = page break
    CMP.W #$0005               ; jumped more than 4?
    BCC .sameLine              ; no, same line
    ; New line detected - reset pixel position, advance tile
    LDA.W #$0000 : STA.W !VWF_PX
    LDA.W !VWF_TILE : INC A : STA.W !VWF_TILE
    BRA .sameLine

.pageBreak:
    ; New page - full VWF reset (keep flag active)
    LDA.W #$0000
    STA.W !VWF_PX : STA.W !VWF_TILE
    ; Clear tile buffer
    PHX
    LDX.W #$0000
-   STA.L !TILE_BUF,X : INX : INX
    CPX.W #$0800 : BCC -
    PLX

.firstChar:
.sameLine:
    STX.W $0A3A                ; update previous X
    SEP #$20

    REP #$20
    LDA.W $0A38
    AND.W #$00FF
    STA.B $00

    ; Control codes - pass to original path
    CMP.W #$0090 : BEQ .doOrig
    CMP.W #$0091 : BEQ .doOrig
    CMP.W #$00D0 : BEQ .doOrig
    CMP.W #$00CE : BEQ .doOrig
    CMP.W #$0020 : BCC .doOrig
    BRA .doRender
.doOrig:
    JMP .origPath

.doRender:
    ; Width lookup
    TAX
    SEP #$20
    LDA.L VWFWidthTable,X
    STA.B $02
    REP #$20
    AND.W #$00FF
    BNE .render

    ; Width 0: blank tile
    LDX.W !VWF_SAVX
    LDA.W #$2000
    STA.L !TMAP_TOP,X
    LDA.W #$2400
    STA.L !TMAP_BOT,X
    RTL

.render:
    ; Font offset = char * 16
    LDA.B $00 : AND.W #$00FF
    ASL A : ASL A : ASL A : ASL A
    STA.B $04

    ; Shift = pixel_x & 7
    SEP #$20
    LDA.W !VWF_PX : AND.B #$07
    STA.B $06
    REP #$20

    ; Buffer base = tile * 16
    LDA.W !VWF_TILE : AND.W #$007F
    ASL A : ASL A : ASL A : ASL A
    STA.B $08

    ; Render 16 rows
    SEP #$20
    LDY.W #$0000

.rowLoop:
    ; Load font byte
    REP #$20
    TYA : CLC : ADC.B $04
    TAX
    SEP #$20
    LDA.L VWFFontData,X
    STA.B $0A

    ; Shift right
    LDX.B $06
    BEQ .noSR
.sr: LSR A : DEX : BNE .sr
.noSR:
    STA.B $0B

    ; Buffer position = col_base + Y
    REP #$20
    TYA : AND.W #$00FF : CLC : ADC.B $08
    TAX
    SEP #$20

    LDA.L !TILE_BUF,X : ORA.B $0B : STA.L !TILE_BUF,X

    ; Spill to next column
    LDA.B $06 : BEQ .noSpill

    PHA                        ; save shift for later
    LDA.B #$08 : SEC : SBC.B $06
    PHX : TAX
    LDA.B $0A
.sl: ASL A : DEX : BNE .sl
    STA.B $0D
    PLX : PLA                  ; restore shift and X

    LDA.B $0D : BEQ .noSpill

    ; Next col = X + 16
    REP #$20
    TXA : CLC : ADC.W #$0010
    CMP.W #$0800 : BCS .noSpill
    TAX : SEP #$20

    LDA.L !TILE_BUF,X : ORA.B $0D : STA.L !TILE_BUF,X
    BRA .noSpill2

.noSpill:
    SEP #$20
.noSpill2:
    INY
    CPY.W #$0010
    BCS .doneRows
    JMP .rowLoop

.doneRows:
    ; Advance cursor
    REP #$20
    LDA.W !VWF_PX : AND.W #$00FF
    LSR A : LSR A : LSR A
    STA.B $0E

    LDA.W !VWF_PX : AND.W #$00FF
    CLC : ADC.B $02
    STA.W !VWF_PX

    LSR A : LSR A : LSR A
    SEP #$20
    CMP.B $0E : BEQ .noAdv
    REP #$20
    LDA.W !VWF_TILE : INC A : STA.W !VWF_TILE
    SEP #$20
.noAdv:
    REP #$20

    ; Write tilemap: each VWF column = 2 sequential tiles (top+bottom)
    ; Top:    tile ($20 + VWF_TILE*2)     | $2000 (priority, palette 0)
    ; Bottom: tile ($20 + VWF_TILE*2 + 1) | $2400 (priority, palette 1)
    LDX.W !VWF_SAVX

    LDA.W !VWF_TILE : AND.W #$00FF
    ASL A                          ; *2 (2 tiles per column)
    CLC : ADC.W #$0020             ; + border offset
    PHA                            ; save tile number
    ORA.W #$2000                   ; priority, palette 0
    STA.L !TMAP_TOP,X

    PLA : INC A                    ; +1 for bottom tile
    ORA.W #$2400                   ; priority, palette 1
    STA.L !TMAP_BOT,X

    ; Tile data upload deferred to VWFPostRender (bulk upload).
    ; Per-character upload removed: SEI can't block NMI on SNES,
    ; so NMI handler can restore $2100 mid-upload, dropping writes.

    REP #$20                       ; caller expects 16-bit A
    LDX.W !VWF_SAVX                ; restore X (caller needs tilemap position)

    RTL

; -------------------------------------------------------------------
; VWFPreRender
; -------------------------------------------------------------------
org $C08F00

VWFPreRender:
    REP #$20
    LDA.W #$0400 : STA.B $14
    STZ.B $16

    LDA.W #$0000
    STA.W !VWF_PX : STA.W !VWF_TILE
    LDA.W #$FFFF
    STA.W $0A3A                ; sentinel: skip first-char newline detection
    SEP #$20
    LDA.B #$A5 : STA.W !VWF_FLAG
    REP #$20
    ; Clear tile buffer
    LDX.W #$0000 : LDA.W #$0000
-   STA.L !TILE_BUF,X : INX : INX
    CPX.W #$0800 : BCC -
    RTL

; -------------------------------------------------------------------
; VWFPostRender - Upload tiles to VRAM using forced blank
; -------------------------------------------------------------------
VWFPostRender:
    SEP #$20
    LDA.W !VWF_FLAG
    CMP.B #$A5
    BEQ .doUpload
    JMP .done

.doUpload:
    ; Disable NMI + IRQ for safe VRAM access.
    ; SEI alone can't block NMI on the SNES - must disable via $4200.
    SEI
    LDA.B #$00
    STA.W $4200                ; disable NMI + auto-joypad
    LDA.B #$80
    STA.W $2100                ; force blank
    LDA.B #$80
    STA.W $2115                ; word increment on high write

    ; Upload VWF tiles to VRAM $6100 (tile $20, 2bpp 8 words/tile)
    REP #$20
    LDA.W #$6100
    STA.W $2116
    SEP #$20

    ; Upload columns: TOP tile (8 words) + BOTTOM tile (8 words) each
    LDA.W !VWF_TILE
    INC A
    STA.B $00                  ; column count

    LDX.W #$0000               ; buffer source
.tileLoop:
    LDY.W #$0008
.topRow:
    LDA.L !TILE_BUF,X
    STA.W $2118
    STA.W $2119
    INX : DEY : BNE .topRow

    LDY.W #$0008
.botRow:
    LDA.L !TILE_BUF,X
    STA.W $2118
    STA.W $2119
    INX : DEY : BNE .botRow

    DEC.B $00 : BNE .tileLoop

    ; Clear VWF flag
    LDA.B #$00 : STA.W !VWF_FLAG

    ; Restore screen + re-enable NMI/IRQ
    LDA.B $58
    STA.W $2100
    LDA.B #$81
    STA.W $4200                ; re-enable NMI + auto-joypad
    CLI

.done:
    ; Displaced instructions from $80:BC7F
    REP #$20
    LDA.W $0A16
    RTL

; ============================================================================
; Data
; ============================================================================
VWFWidthTable:
    incbin "font/widths.bin"

VWFFontData:
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    incbin "font/font_1bpp.bin"

print "VWF v3 end: $", pc
