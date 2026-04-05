; ============================================================================
; Little Master 3 - Variable Width Font (VWF) Patch v2
; ============================================================================

lorom

; ROM expansion
org $00FFD7
    db $0C
org $FFFFFF
    db $00

; ============================================================================
; VWF state ($0A30-$0A3F)
; ============================================================================
!VWF_PX        = $0A30
!VWF_TILE      = $0A32
!VWF_FLAG      = $0A34

!TILE_BUF      = $7FB000
!TMAP_TOP      = $7E9000
!TMAP_BOT      = $7E9040

; ============================================================================
; Hook 1: $80:C17B (20 bytes available, through $80:C18E)
;
; Original sequence at C170-C18E:
;   C170: PHA                    ; push char
;   C171: AD 1E 0A  LDA $0A1E   ; check flag
;   C174: D0 30     BNE $C1A6   ; branch if set (different render path)
;   C176: AD 1C 0A  LDA $0A1C   ; check flag
;   C179: D0 14     BNE $C18F   ; branch if set (inverted render path)
;   C17B: PLA                    ; *** OUR HOOK STARTS HERE ***
;   C17C: CLC
;   C17D: ADC $0A02
;   C180: PHA
;   C181: STA $7E9000,X
;   C185: PLA
;   C186: CLC
;   C187: ADC #$0400
;   C18A: STA $7E9040,X
;   C18E: RTS
;
; At hook entry: char is on stack (PHA at C170), 16-bit A mode, X = tilemap pos
; ============================================================================
org $80C17B

    PLA                        ; 1 byte - get char (original PLA at C17B)
    STA.W $0A38                ; 3 bytes - save char to known location
    JSL.L VWFCharHandler       ; 4 bytes - handler reads from $0A38
    RTS                        ; 1 byte (= 9 bytes total)
    padbyte $EA
    pad $80C18F                ; pad to 20 bytes

; ============================================================================
; Hook 2: $80:BC75 (15 bytes available, through $80:BC83)
;
; Original:
;   BC75: LDA #$0400   (3)
;   BC78: STA $14      (2)
;   BC7A: STZ $16      (2)
;   BC7C: JSR $BE3B    (3) = tilemap writer
;   BC7F: REP #$20     (2)
;   BC81: LDA $0A16    (3) = 15 bytes total
;
; New: pre-render, tilemap write, post-render (trigger DMA), then continue
; ============================================================================
org $80BC75

    JSL.L VWFPreRender         ; 4 - init VWF + set $14/$16
    JSR.W $BE3B                ; 3 - tilemap writer (calls VWFCharHandler)
    JSL.L VWFPostRender        ; 4 - trigger DMA + do REP#20 + LDA $0A16
    NOP                        ; 1
    NOP                        ; 1
    NOP                        ; 1
    NOP                        ; 1 (= 15 bytes, padded to reach BC84)

; ============================================================================
; VWF Code - Bank $C0
; ============================================================================
org $C08000

; -------------------------------------------------------------------
; VWFCharHandler
;
; Entry state:
;   - 16-bit A (REP #$20 active)
;   - Char code is on the stack (PHA'd at $80:C170)
;   - X = tilemap write position (index into $7E:9000)
;   - We must PLA the char and write tilemap entries
;   - X must be preserved for caller's INX INX after we return
; -------------------------------------------------------------------
VWFCharHandler:
    ; Char code is in $0A38 (saved by hook before JSL)
    ; X = tilemap write position, 16-bit A mode

    ; Check VWF flag
    SEP #$20
    LDA.W !VWF_FLAG
    CMP.B #$A5
    REP #$20
    BEQ .vwfPath

    ; --- ORIGINAL CODE PATH ---
    LDA.W $0A38                ; char code
    CLC
    ADC.W $0A02
    PHA
    STA.L !TMAP_TOP,X
    PLA
    CLC
    ADC.W #$0400
    STA.L !TMAP_BOT,X
    RTL

.vwfPath:
    LDA.W $0A38
    AND.W #$00FF
    STA.B $00                  ; $00 = char code

    ; Save X (tilemap position) - we'll need it at the end
    PHX

    ; --- Look up width ---
    LDA.B $00
    AND.W #$00FF
    TAX
    SEP #$20
    LDA.L VWFWidthTable,X
    STA.B $02                  ; $02 = width
    REP #$20
    AND.W #$00FF
    BNE .hasWidth

    ; Width 0: write blank
    PLX
    LDA.W #$0000
    STA.L !TMAP_TOP,X
    STA.L !TMAP_BOT,X
    RTL

.hasWidth:
    ; --- Font data offset = char * 16 ---
    LDA.B $00
    AND.W #$00FF
    ASL A
    ASL A
    ASL A
    ASL A
    STA.B $04                  ; $04 = font offset

    ; --- Shift = VWF_PX & 7 ---
    SEP #$20
    LDA.W !VWF_PX
    AND.B #$07
    STA.B $06                  ; $06 = shift
    REP #$20

    ; --- Tile buffer offset = VWF_TILE * 32 ---
    LDA.W !VWF_TILE
    AND.W #$003F
    ASL A
    ASL A
    ASL A
    ASL A
    ASL A
    STA.B $08                  ; $08 = tile buf base

    ; --- Render 16 rows ---
    SEP #$20
    LDY.W #$0000

.rowLoop:
    ; Load font byte
    REP #$20
    PHY
    TYA
    CLC
    ADC.B $04
    TAX
    SEP #$20
    LDA.L VWFFontData,X
    STA.B $0A                  ; original pixels
    PLY

    ; Shift right for current tile
    LDX.B $06
    BEQ .noSR
.srLoop:
    LSR A
    DEX
    BNE .srLoop
.noSR:
    STA.B $0B                  ; shifted pixels

    ; 2bpp row offset: (row & 7) * 2, +16 if row >= 8
    TYA
    AND.B #$07
    ASL A
    CPY.W #$0008
    BCC .topH
    CLC
    ADC.B #$10
.topH:
    STA.B $0C                  ; row offset in tile column

    ; OR into tile buffer
    REP #$20
    LDA.B $0C
    AND.W #$00FF
    CLC
    ADC.B $08
    TAX
    SEP #$20

    LDA.L !TILE_BUF,X
    ORA.B $0B
    STA.L !TILE_BUF,X
    LDA.L !TILE_BUF+1,X
    ORA.B $0B
    STA.L !TILE_BUF+1,X

    ; Spill to next tile
    LDA.B $06
    BEQ .noSpill

    ; spill = original << (8 - shift)
    LDA.B #$08
    SEC
    SBC.B $06
    PHX                        ; save tile buf X
    TAX
    LDA.B $0A
.slLoop:
    ASL A
    DEX
    BNE .slLoop
    STA.B $0D
    PLX                        ; restore tile buf X

    LDA.B $0D
    BEQ .noSpill

    ; Next column = X + 32
    REP #$20
    TXA
    CLC
    ADC.W #$0020
    CMP.W #$1000               ; bounds check (4KB buffer)
    BCS .noSpill
    TAX
    SEP #$20

    LDA.L !TILE_BUF,X
    ORA.B $0D
    STA.L !TILE_BUF,X
    LDA.L !TILE_BUF+1,X
    ORA.B $0D
    STA.L !TILE_BUF+1,X

.noSpill:
    SEP #$20                   ; ensure 8-bit A
    INY
    CPY.W #$0010
    BCS .doneRows
    JMP .rowLoop
.doneRows:

    ; --- Advance pixel cursor ---
    REP #$20
    LDA.W !VWF_PX
    AND.W #$00FF
    LSR A
    LSR A
    LSR A
    STA.B $0E                  ; old tile column

    LDA.W !VWF_PX
    AND.W #$00FF
    CLC
    ADC.B $02                  ; + width (still in $02 low byte)
    STA.W !VWF_PX

    LSR A
    LSR A
    LSR A
    SEP #$20
    CMP.B $0E
    BEQ .noTileAdvance
    REP #$20
    LDA.W !VWF_TILE
    INC A
    STA.W !VWF_TILE
    SEP #$20
.noTileAdvance:
    REP #$20

    ; --- Write tilemap entries ---
    PLX                        ; restore original tilemap X

    ; Use original tile index (char + $0A02) for now.
    ; The VWF rendering modifies the tile graphics in-place,
    ; and the DMA uploads them over the original font tiles.
    LDA.W $0A38                ; char code
    CLC
    ADC.W $0A02                ; + tile base offset
    PHA
    STA.L !TMAP_TOP,X          ; top tilemap entry

    PLA
    CLC
    ADC.W #$0400               ; palette for bottom row
    STA.L !TMAP_BOT,X          ; bottom tilemap entry

    RTL

; -------------------------------------------------------------------
; VWFPreRender - called before the tilemap writer loop
; Sets up $14/$16 (original behavior) and inits VWF state
; -------------------------------------------------------------------
org $C08F00

VWFPreRender:
    ; Called BEFORE the tilemap writer loop.
    ; Set up $14/$16 as original code did.
    REP #$20
    LDA.W #$0400
    STA.B $14
    STZ.B $16

    ; Init VWF state
    LDA.W #$0000
    STA.W !VWF_PX
    STA.W !VWF_TILE
    SEP #$20
    LDA.B #$A5
    STA.W !VWF_FLAG
    REP #$20

    ; Clear tile buffer (2KB at $7F:B000)
    LDX.W #$0000
    LDA.W #$0000
-   STA.L !TILE_BUF,X
    INX
    INX
    CPX.W #$0800
    BCC -

    RTL

; -------------------------------------------------------------------
; VWFPostRender - called AFTER tilemap writing is done
; Triggers DMA of rendered tiles to VRAM
; -------------------------------------------------------------------
VWFPostRender:
    ; Trigger DMA of rendered tiles if VWF was active
    SEP #$20
    LDA.W !VWF_FLAG
    CMP.B #$A5
    BNE .skip

    ; Set VRAM target to font tile area ($3000 words)
    REP #$20
    LDA.W #$3000
    STA.B $78                  ; spawnParticle reads $78 as VRAM dest
    SEP #$20
    LDA.B #$FE                 ; $57 = $FE triggers spawnParticle DMA
    STA.B $57                  ; ($7F:B000 -> VRAM $3000, 2KB)

    ; Clear VWF flag
    LDA.B #$00
    STA.W !VWF_FLAG

.skip:
    ; Execute the displaced instructions from BC7F-BC83
    REP #$20                   ; was at BC7F
    LDA.W $0A16                ; was at BC81 (3 bytes)
    RTL                        ; return to BC84

; ============================================================================
; Data
; ============================================================================
VWFWidthTable:
    incbin "font/widths.bin"

VWFFontData:
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    incbin "font/font_1bpp.bin"

print "VWF v2 end: $", pc
