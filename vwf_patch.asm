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

    LDA.W $0A38
    AND.W #$00FF
    STA.B $00

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
    ; Disable interrupts + force blank for safe VRAM access
    SEI
    LDA.B #$80
    STA.W $2100

    ; Set VRAM mode: word increment on high write
    LDA.B #$80
    STA.W $2115

    ; --- Upload tiles to VRAM $6800 ---
    ; Each character = ONE 4bpp tile (32 bytes = 16 VRAM words):
    ;   bp0/bp1 = top 8 rows (buffer bytes 0-7)
    ;   bp2/bp3 = bottom 8 rows (buffer bytes 8-15)
    ; Palette 0 shows bp0/bp1 (top), palette 1 shows bp2/bp3 (bottom)
    ; --- Upload top tiles (2bpp, 8 words each) ---
    ; BG3 tileset base = $6000 VRAM words (confirmed by user)
    ; Tile $20 (2bpp, 8 words/tile) = $6000 + $20*8 = $6100
    REP #$20
    LDA.W #$6100
    STA.W $2116
    SEP #$20

    ; Upload tiles: for each column, write TOP tile (8 words) then
    ; BOTTOM tile (8 words) sequentially to VRAM, matching $DE05 layout.
    LDA.W !VWF_TILE
    INC A
    STA.B $00                  ; column count

    LDX.W #$0000               ; buffer source
.tileLoop:
    ; Write top 8 rows (bytes 0-7 of column)
    LDY.W #$0008
.topRow:
    LDA.L !TILE_BUF,X
    STA.W $2118
    STA.W $2119
    INX : DEY : BNE .topRow

    ; Write bottom 8 rows (bytes 8-15 of column)
    ; X is now at offset 8 (bottom rows) - just continue reading
    LDY.W #$0008
.botRow:
    LDA.L !TILE_BUF,X
    STA.W $2118
    STA.W $2119
    INX : DEY : BNE .botRow

    ; X advanced by 16 (full column), ready for next
    DEC.B $00 : BNE .tileLoop

    ; Also upload tilemap from $7E:9000 to VRAM $7C00
    ; (normally done by the $05F5 DMA mechanism, but we do it directly)
    REP #$20
    LDA.W #$7C00
    STA.W $2116                ; VRAM dest = $7C00 (BG3 tilemap)
    SEP #$20

    ; Upload $7E:9000 tilemap (128 bytes = 64 entries = enough for ~24 columns)
    LDX.W #$0000
    LDY.W #$0080               ; 128 bytes = 64 tilemap entries
.tmapLoop:
    LDA.L !TMAP_TOP,X
    STA.W $2118
    INX
    LDA.L !TMAP_TOP,X
    STA.W $2119
    INX
    DEY : DEY
    BNE .tmapLoop

    ; Upload bottom tilemap from $7E:9040
    LDX.W #$0000
    LDY.W #$0080
.tmapLoop2:
    LDA.L !TMAP_BOT,X
    STA.W $2118
    INX
    LDA.L !TMAP_BOT,X
    STA.W $2119
    INX
    DEY : DEY
    BNE .tmapLoop2

    ; Clear VWF flag
    LDA.B #$00 : STA.W !VWF_FLAG

    ; Restore screen brightness + re-enable interrupts
    LDA.B #$0F
    STA.W $2100
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
