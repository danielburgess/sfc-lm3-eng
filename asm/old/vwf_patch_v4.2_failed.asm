; ============================================================================
; Little Master 3 - VWF Patch v4.2
; ============================================================================
; Font: 1bpp 8x16 sequential (8 top + 8 bottom bytes per char).
; Tile buffer: 2bpp at $7F:B000, 4096 bytes (256 tiles).
;   Layout: 4 rows x 32 cols, each col = 2 tiles (top+bot) = 32 bytes.
;   Row R, Col C: offset = R*1024 + C*32  (top tile at +0, bottom at +16)
; VRAM tiles: $6100+ (tile $20+), 2bpp 8x8, 8 words/tile.
;   Tile index = $20 + R*64 + C*2  (top), +1 (bottom)
; Tilemap: $7E:9000 (top), $7E:9040 (bottom) - game handles DMA via $57.
;
; KEY: VWF_PX is initialized to $09FC*8 so pixel columns match tilemap slots.
;      Tilemap uses absolute $09FC for tile index (not relative to $09F0).
;      Row index = ($09FE >> 1) & 3 to support 3+ text lines without collision.
; ============================================================================

lorom

; ROM expansion to 24 Mbit
org $00FFD7 : db $0C
org $FFFFFF : db $00

; --- VWF State (unused WRAM in $0A30-$0A3B range) ---
!VWF_PX     = $0A30       ; pixel X position (16-bit, absolute)
!VWF_PAGE   = $0A32       ; $A5 = text page init'd (TILE_BUF cleared)
!VWF_DIRTY  = $0A33       ; $A5 = TILE_BUF dirty, NMI shim DMAs to VRAM
!VWF_FLAG   = $0A34       ; $A5 = per-char VWF render active (PostRender clears)
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
; Hook 3: $80:C022 (textStream_ExtFF — [cls] screen transition)
; Original: JSL initTilemapAndSync_Long  (4 bytes)
; Replace with JSL to VWFClsHook which calls the original, then resets VWF
; state + clears VWF tile buffer/VRAM so new page starts clean.
; ============================================================================
org $80C022
    JSL.L VWFClsHook           ; 4 (same size as displaced JSL)

; ============================================================================
; Hook 4 (NMI): $00:D46F — 5 bytes replacing SEP #$20 + LDA $4210
; Game NMI handler at $00:D469:
;   $D469  PHP / REP #$30 / PHA / PHX / PHY      (register save)
;   $D46F  E2 20        SEP #$20
;   $D471  AD 10 42     LDA $4210                (ack NMI)
;   $D474  A5 10        LDA $10                  (game body continues)
; We JSL to VWFNmiShim which replays SEP + LDA $4210 and, if TILE_BUF is
; dirty, DMAs TILE_BUF → VRAM $6100 inside the legal VBlank window (no
; forced blank, no mid-frame VRAM writes → no flicker).
; ============================================================================
org $00D46F
    JSL.L VWFNmiShim           ; 4 bytes
    NOP                        ; 1 byte pad (matches 5-byte displaced range)

; ============================================================================
; VWF Code - Bank $E0 ($C0 collides w/ title_chunks @ PC 0x200000)
; ============================================================================
org $E08000

; -------------------------------------------------------------------
; VWFCharHandler
; Called per character. $0A38 = char, X = tilemap buffer offset.
; 16-bit A active on entry.
; -------------------------------------------------------------------
VWFCharHandler:
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
    RTL

.vwf:
    STX.W !VWF_SAVX

    ; --- Newline detection via $09FE ---
    ; On first char (VWF_ROW=$FFFF) or row change, reset VWF_PX to $09FC*8
    REP #$20
    LDA.W $09FE
    CMP.W !VWF_ROW
    BEQ .sameLine
    ; Row changed (or first char) → reset VWF_PX to current column
    LDA.W $09FC
    ASL A : ASL A : ASL A      ; * 8 → pixel position
    STA.W !VWF_PX
    LDA.W $09FE
    STA.W !VWF_ROW
.sameLine:

    ; --- Character filtering ---
    REP #$20
    LDA.W $0A38
    ; Icons/special tiles ($0100+) → original path
    CMP.W #$0100 : BCS .doOrig
    AND.W #$00FF
    STA.B $00                  ; $00 = char code (16-bit clean)
    ; Past font range ($F0+) → original path
    CMP.W #$00F0 : BCS .doOrig
    ; Sub-space ($00-$1F) → original path
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

    ; Width 0 → blank tilemap entry
    LDX.W !VWF_SAVX
    LDA.W $0A02               ; palette/priority from control codes
    STA.L $7E9000,X
    CLC : ADC.W #$0400        ; +palette 1 offset for bottom
    STA.L $7E9040,X
    RTL

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
    LDA.B $04                  ; row (0 or 1)
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
    BEQ .noSpill               ; original was 0 → nothing to spill

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
    BEQ .noSpill               ; spill is 0 → nothing to write

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

    ; --- Mark tile buffer dirty — NMI shim will DMA → VRAM in VBlank ---
    ; (Per-char forced-blank upload removed; was the source of flicker.)
    SEP #$20
    LDA.B #$A5
    STA.W !VWF_DIRTY

.skipRender:
    ; --- Write tilemap entries ---
    ; Use ABSOLUTE $09FC for tile column (not relative to $09F0).
    ; This matches VWF_PX which was initialized to $09FC * 8.
    ;   top_tile  = $20 + row*64 + $09FC*2
    ;   bottom_tile = top_tile + 1
    REP #$20
    LDX.W !VWF_SAVX

    ; row * 64
    LDA.B $04                  ; row (0 or 1)
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
    RTL

; -------------------------------------------------------------------
; VWFNmiShim - hooks game NMI at $00:D46F.
;
; At NMI entry, game does PHP / REP #$30 / PHA / PHX / PHY before jumping
; here, so A/X/Y are 16-bit and flags are on stack. PBR is set to $E0 by
; JSL; DBR is whatever game last set (unknown in NMI context). We force
; DBR=$00 so absolute PPU/HW-reg/low-WRAM access works uniformly.
;
; Replays displaced SEP #$20 + LDA $4210 (NMI ack). If VWF_DIRTY == $A5,
; DMAs TILE_BUF (4096 B) → VRAM $6100 via channel 0. Runs BEFORE game's
; NMI body so game VBlank DMA work is undisturbed. ~1024 master cycles.
; -------------------------------------------------------------------
org $E08E00

VWFNmiShim:
    PHB                        ; save DBR
    SEP #$20
    LDA.B #$00 : PHA : PLB     ; DBR = $00

    ; Displaced SEP #$20 folded into the SEP above; replay LDA $4210
    LDA.W $4210                ; ack NMI

    LDA.W !VWF_DIRTY
    CMP.B #$A5
    BNE .skip

    ; DMA channel 7 config: 4096 B from $7F:B000 → VRAM $6100.
    ; MUST use ch7 (not ch0): game's NMI reuses ch0 for OAM DMA and
    ; inherits mode/dest from last setup — clobbering ch0 corrupts OAM.
    LDA.B #$80 : STA.W $2115   ; word inc on $2119
    REP #$20
    LDA.W #$6100 : STA.W $2116 ; VRAM dest word addr
    SEP #$20
    LDA.B #$01 : STA.W $4370   ; mode 01 (2-byte alternating $2118/$2119)
    LDA.B #$18 : STA.W $4371   ; B-bus dest = $2118
    REP #$20
    LDA.W #$B000 : STA.W $4372 ; A-bus source low/mid
    SEP #$20
    LDA.B #$7F : STA.W $4374   ; A-bus source bank
    REP #$20
    LDA.W #$1000 : STA.W $4375 ; byte count = 4096
    SEP #$20
    LDA.B #$80 : STA.W $420B   ; kick DMA channel 7

    STZ.W !VWF_DIRTY           ; consumed

.skip:
    PLB                        ; restore DBR
    RTL

; -------------------------------------------------------------------
; VWFPreRender - called before processText
; Displaced: LDA #$0400 / STA $14 / STZ $16
; -------------------------------------------------------------------
org $E08F00

VWFPreRender:
    ; Displaced instructions from $80:BC75 — must run every call
    REP #$20
    LDA.W #$0400 : STA.B $14
    STZ.B $16

    ; Mark per-char VWF render active (VWFCharHandler gates .vwf path
    ; on this). Cleared by VWFPostRender so menu/HUD chars (no
    ; processText wrap) take the .origPath.
    SEP #$20
    LDA.B #$A5 : STA.W !VWF_FLAG

    ; First-call-of-page detection via VWF_PAGE sentinel. Set here,
    ; cleared only by VWFClsHook at [cls]. Only the first char of a
    ; new text page runs the init + TILE_BUF clear.
    LDA.W !VWF_PAGE
    CMP.B #$A5
    BEQ .midPage

    ; --- First call of page: init state + clear TILE_BUF ---
    REP #$20
    LDA.W $09FC
    ASL A : ASL A : ASL A      ; VWF_PX = $09FC * 8
    STA.W !VWF_PX

    LDA.W #$FFFF
    STA.W !VWF_ROW             ; newline sentinel

    LDX.W #$0000
    LDA.W #$0000
-   STA.L !TILE_BUF,X
    INX : INX
    CPX.W #$1000 : BCC -

    SEP #$20
    LDA.B #$A5 : STA.W !VWF_PAGE

.midPage:
    REP #$20
    RTL

; -------------------------------------------------------------------
; VWFPostRender - called after processText
; Bulk uploads all VWF tiles, then displaced: REP #$20 / LDA $0A16
; -------------------------------------------------------------------
org $E08F80

VWFPostRender:
    SEP #$20
    LDA.W !VWF_FLAG
    CMP.B #$A5
    BEQ .doUpload
    JMP .done

.doUpload:
    ; Clear per-char active flag so VWFCharHandler calls OUTSIDE
    ; processText (menus, HUD, etc.) take the .origPath.
    LDA.B #$00 : STA.W !VWF_FLAG

.done:
    ; Displaced instructions from $80:BC7F
    REP #$20
    LDA.W $0A16
    RTL

; -------------------------------------------------------------------
; VWFClsHook - replaces JSL initTilemapAndSync_Long at $80:C022.
; Runs the original clear+sync, then resets VWF so the new text page
; starts with an empty tile buffer, cleared VRAM tile range, and
; VWF_PX/VWF_ROW reset to current cursor position.
; -------------------------------------------------------------------
org $E08FC0

VWFClsHook:
    ; Original displaced op — must run first so tilemap clear completes
    JSL.L $81ECE1              ; initTilemapAndSync_Long

    ; Clear page sentinel so next PreRender re-inits state + TILE_BUF.
    SEP #$20
    LDA.B #$00 : STA.W !VWF_PAGE
    REP #$20

    LDX.W #$0000
    LDA.W #$0000
-   STA.L !TILE_BUF,X
    INX : INX
    CPX.W #$1000 : BCC -

    LDA.W #$FFFF
    STA.W !VWF_ROW

    RTL

; ============================================================================
; Data — placed at $E09000, safely after VWFPostRender.
; ($E09000 + 256 widths + 16 zeros + ~3840 font bytes ≈ $E09FFF < $E0A000)
; ============================================================================
org $E09000

VWFWidthTable:
    incbin "en_data/fonts/font_accented_widths.bin"

VWFFontData:
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    incbin "en_data/bin/fonts/font_accented_1bpp.bin"

print "VWF v4.2 end: $", pc
