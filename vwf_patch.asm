; ============================================================================
; Little Master 3 - Variable Width Font Patch
; Assembler: asar
; Target: LoROM
; ============================================================================
;
; This patch replaces the fixed-width 8px tile-based text renderer with a
; variable-width font system for English dialog text.
;
; Architecture:
;   - Font pixel data is read from ROM (1bpp, 8x16 per glyph)
;   - Each character is shifted right by (cursor_x % 8) pixels
;   - Shifted pixels are OR'd into a tile graphics buffer in WRAM
;   - When cursor crosses an 8px tile boundary, advance to next tile column
;   - Width table in ROM determines each character's pixel advance
;   - Rendered tiles are DMA'd to VRAM during VBlank (existing DMA path)
;
; Memory map:
;   $7E9000-$7E97FF  - Rendered tile graphics buffer (existing, 2KB)
;                      Used for the dialog BG layer tile data
;   $7EA000-$7EA0FF  - Tilemap buffer (existing)
;   $7E1E00-$7E1EFF  - VWF state variables (new, 256 bytes)
;     $7E1E00        - Pixel X cursor position (16-bit)
;     $7E1E02        - Current tile column index
;     $7E1E04        - Current tile row (0 = top half, 1 = bottom half for 8x16)
;     $7E1E06        - Line number (for newlines)
;     $7E1E08        - Tile counter (unique tiles generated)
;
; ROM space used:
;   Bank $AF:D100 (PC 0x17D100) - 1793 bytes free
;
; ============================================================================

lorom

; ============================================================================
; Constants
; ============================================================================
!VWF_STATE     = $7E1E00       ; VWF state block in WRAM
!PIXEL_X       = $7E1E00       ; Current pixel X position (16-bit)
!TILE_COL      = $7E1E02       ; Current tile column
!TILE_ROW      = $7E1E04       ; Current tile row within line
!LINE_NUM      = $7E1E06       ; Current line number
!TILE_COUNT    = $7E1E08       ; Tiles generated so far
!VWF_ACTIVE    = $7E1E0A       ; VWF active flag

!TILE_BUF      = $7E9000       ; Tile graphics buffer (existing)
!TILEMAP_BUF   = $7EA000       ; Tilemap buffer (existing)

!MAX_LINE_PX   = 192           ; Max pixels per line (24 tiles * 8px)
!TILE_BASE     = $0100         ; Base tile index for VWF-rendered tiles
!DIALOG_LINES  = 4             ; Max dialog lines

; ============================================================================
; Width table and font data - placed in free space at $AF:D100
; ============================================================================
org $AFD100

VWFWidthTable:
    ; Character widths (indexed by character code 0x00-0xEF)
    ; These should be tuned after testing. Values are pixel widths.
    ; 0x00-0x1F: control codes (width 0, not rendered)
    db $00,$00,$00,$00,$00,$00,$00,$00  ; 00-07
    db $00,$00,$00,$00,$00,$00,$00,$00  ; 08-0F
    db $00,$00,$00,$00,$00,$00,$00,$00  ; 10-17
    db $00,$00,$00,$00,$00,$00,$00,$00  ; 18-1F
    ; 0x20-0x7E: ASCII printable characters
    db $03                             ; 20 space
    db $02,$04,$06,$06,$06,$06,$02      ; 21-27  !"#$%&'
    db $03,$03,$06,$05,$02,$04,$02,$04  ; 28-2F  ()*+,-./
    db $05,$04,$05,$05,$05,$05,$05,$05  ; 30-37  01234567
    db $05,$05,$02,$02,$04,$04,$04,$05  ; 38-3F  89:;<=>?
    db $06,$06,$05,$05,$05,$05,$05,$05  ; 40-47  @ABCDEFG
    db $05,$02,$04,$05,$05,$06,$06,$06  ; 48-4F  HIJKLMNO
    db $05,$06,$05,$05,$06,$05,$06,$07  ; 50-57  PQRSTUVW
    db $06,$06,$05,$04,$04,$04,$06,$05  ; 58-5F  XYZ[\]^_
    db $03,$05,$05,$04,$05,$05,$04,$05  ; 60-67  `abcdefg
    db $05,$02,$03,$05,$02,$07,$05,$05  ; 68-6F  hijklmno
    db $05,$05,$04,$04,$04,$05,$05,$07  ; 70-77  pqrstuvw
    db $06,$05,$04,$04,$02,$04,$06,$00  ; 78-7F  xyz{|}~
    ; 0x80-0x8F: accented lowercase
    db $05,$05,$05,$05,$05,$05,$05,$05  ; 80-87  àáâäèéêë
    db $02,$02,$02,$05,$05,$05,$05,$05  ; 88-8F  ìíîòóôöù
    ; 0x90-0x9F: control codes / more accented
    db $00,$00,$00,$00,$00             ; 90-94  [nl] etc
    db $05,$05,$05,$05,$04             ; 95-99  úûüñç
    db $00,$00,$00,$00,$00,$00         ; 9A-9F
    ; 0xA0-0xAF: accented uppercase
    db $06,$06,$06,$06,$05,$05,$05,$02  ; A0-A7  ÀÁÂÄÈÉÊÍl
    db $06,$06,$06,$05,$05,$06,$04,$00  ; A8-AF  ÓÔÖÚÜÑÇ

; Pad to 240 entries
    db $00,$00,$00,$00,$00,$00,$00,$00  ; B0-B7
    db $00,$00,$00,$00,$00,$00,$00,$00  ; B8-BF
    db $00,$00,$00,$00,$00,$00,$00,$00  ; C0-C7
    db $00,$00,$00,$00,$00,$00,$00,$00  ; C8-CF
    db $00,$00,$00,$00,$00,$00,$00,$00  ; D0-D7
    db $00,$00,$00,$00,$00,$00,$00,$00  ; D8-DF
    db $00,$00,$00,$00,$00,$00,$00,$00  ; E0-E7
    db $00,$00,$00,$00,$00,$00,$00,$00  ; E8-EF

; ============================================================================
; VWF Rendering Routine
; ============================================================================
;
; Entry: A = character code (8-bit)
; Modifies: A, X, Y, $00-$0F (scratch)
; Uses: VWF state variables at $7E1E00+
;
; For each character:
;   1. Look up pixel width from table
;   2. Read 8x16 font glyph (16 bytes of 1bpp data)
;   3. Shift glyph right by (pixel_x & 7) bits
;   4. OR shifted data into tile buffer at current tile column
;   5. If glyph spills into next tile, OR remainder there too
;   6. Advance pixel_x by character width
;   7. Update tile column index
;
VWFRenderChar:
    PHP
    PHX
    PHY
    SEP #$30                   ; 8-bit A and X/Y

    ; Store character code
    STA.B $00                  ; $00 = char code

    ; Look up width
    TAX
    LDA.L VWFWidthTable,X
    BEQ .done                  ; Width 0 = control code, skip
    STA.B $01                  ; $01 = char width in pixels

    ; Calculate font data source address
    ; Each glyph is 16 bytes (8x16, 1bpp)
    ; Font data address = FontBase + (char_code * 16)
    REP #$20                  ; 16-bit A
    LDA.B $00
    AND.W #$00FF
    ASL A
    ASL A
    ASL A
    ASL A                     ; * 16
    CLC
    ADC.W #FontData&$FFFF     ; Add font data base (low 16 bits)
    STA.B $02                 ; $02/$03 = font source offset
    SEP #$20

    LDA.B #FontData>>16       ; Font data bank
    STA.B $04                 ; $04 = font source bank

    ; Get current pixel X position
    REP #$20
    LDA.L !PIXEL_X
    STA.B $05                 ; $05/$06 = pixel X
    SEP #$20

    ; Calculate shift amount = pixel_x & 7
    LDA.B $05
    AND.B #$07
    STA.B $07                 ; $07 = shift amount (0-7)

    ; Calculate tile column = pixel_x / 8
    REP #$20
    LDA.B $05
    LSR A
    LSR A
    LSR A                     ; / 8
    STA.B $08                 ; $08/$09 = tile column
    SEP #$20

    ; Calculate tile buffer destination
    ; Each tile in 2bpp format = 16 bytes (8x8)
    ; For 8x16 chars: top tile + bottom tile = 32 bytes per column
    ; Buffer offset = tile_column * 32
    REP #$20
    LDA.B $08
    ASL A
    ASL A
    ASL A
    ASL A
    ASL A                     ; * 32
    TAX                       ; X = buffer offset for this tile column
    SEP #$20

    ; Render the glyph: OR shifted font data into tile buffer
    ; Process 16 rows (8 for top tile, 8 for bottom tile)
    LDY.W #$0000              ; Y = font data row index

.renderLoop:
    ; Read font pixel row (1bpp, 8 pixels)
    LDA.B [$02],Y             ; Load font row from ROM

    ; Shift right by shift amount
    PHX
    LDX.B $07                 ; shift count
    BEQ .noShift
.shiftLoop:
    LSR A
    DEX
    BNE .shiftLoop
.noShift:
    PLX

    ; OR into current tile buffer position
    ; Top 8 rows go to tile bytes 0-7 (plane 0) at even offsets
    ; Bottom 8 rows go to next tile (+16 bytes)
    CPY.W #$0008
    BCS .bottomTile

    ; Top tile: row Y, plane 0
    ORA.L !TILE_BUF,X
    STA.L !TILE_BUF,X
    BRA .checkSpill

.bottomTile:
    ; Bottom tile: row Y-8, plane 0, offset +16 bytes
    PHX
    TXA
    CLC
    ADC.W #$0010              ; Next tile (bottom half)
    TAX
    TYA
    SEC
    SBC.B #$08
    PHY
    TAY                       ; Y now 0-7 for bottom tile
    ; Use Y as offset within the 16-byte tile
    LDA.B [$02],Y             ; Re-read font row...
    PLY
    PLX
    ; Actually need to shift and OR here too
    ; TODO: This needs refinement for the bottom tile half
    BRA .nextRow

.checkSpill:
    ; Check if glyph spills into next tile column
    ; If shift > 0, some pixels overflow to the right
    LDA.B $07
    BEQ .nextRow              ; No shift = no spill

    ; Read font row again and shift LEFT by (8 - shift)
    LDA.B [$02],Y
    PHX
    LDA.B #$08
    SEC
    SBC.B $07                 ; 8 - shift
    TAX
.spillShift:
    LDA.B [$02],Y
    ASL A                     ; TODO: need to re-approach this shift logic
    DEX
    BNE .spillShift
    PLX

    ; OR into next tile column
    ; offset = current_offset + 32
    PHX
    TXA
    CLC
    ADC.W #$0020
    TAX
    ;ORA.L !TILE_BUF,X        ; OR spill pixels
    ;STA.L !TILE_BUF,X
    PLX

.nextRow:
    INY
    CPY.W #$0010              ; 16 rows done?
    BCC .renderLoop

    ; Advance pixel X by character width
    REP #$20
    LDA.L !PIXEL_X
    CLC
    ADC.B $01                 ; Add width (zero-extended)
    STA.L !PIXEL_X
    SEP #$20

.done:
    PLY
    PLX
    PLP
    RTL

; ============================================================================
; VWF Initialization - call when opening dialog box
; ============================================================================
VWFInit:
    PHP
    REP #$20
    LDA.W #$0000
    STA.L !PIXEL_X
    STA.L !TILE_COL
    STA.L !TILE_ROW
    STA.L !LINE_NUM
    STA.L !TILE_COUNT
    SEP #$20
    LDA.B #$01
    STA.L !VWF_ACTIVE

    ; Clear tile graphics buffer (2KB)
    REP #$20
    LDA.W #$0000
    LDX.W #$0000
.clearLoop:
    STA.L !TILE_BUF,X
    INX
    INX
    CPX.W #$0800
    BCC .clearLoop
    SEP #$20

    PLP
    RTL

; ============================================================================
; VWF Newline - advance to next line
; ============================================================================
VWFNewline:
    PHP
    REP #$20
    LDA.W #$0000
    STA.L !PIXEL_X             ; Reset X to left margin
    LDA.L !LINE_NUM
    INC A
    STA.L !LINE_NUM
    SEP #$20
    PLP
    RTL

; ============================================================================
; Font Data - 1bpp 8x16 glyphs (to be generated from font.png)
; This is a placeholder - actual data will be incbin'd from a binary file
; ============================================================================
FontData:
    ; incbin "font/font_1bpp.bin"
    ; For now, fill with placeholder
    fill 3840, $00             ; 240 chars * 16 bytes each = 3840 bytes

; ============================================================================
; End of VWF patch code
; ============================================================================
print "VWF patch size: ", pc-$AFD100, " bytes"
