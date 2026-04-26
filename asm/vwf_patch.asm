; ============================================================================
; vwf_patch.asm — Variable-width font for Little Master III
;
; Step E — Proportional render via pen cursor + shift-and-OR + spill.
;   Algorithm validated in tools/vwf_proto/vwf_render.py.
;   Research:  docs/vwf_research.md (Phase 1.1..1.8 all verified)
;
; DISCRIMINATION (research doc 1.2/1.3/1.5):
;   - A >= $0100 at $C17B entry → chrome path, raw tile index → passthrough
;   - A <  $0100 AND $0A0A != 0 → paced DIALOG text → VWF render
;   - A <  $0100 AND $0A0A == 0 → menu/chrome path → passthrough
;
; VRAM LAYOUT (research 1.8):
;   - $C000..$CFFF = base-game font (256 glyphs, MUST NOT OVERWRITE)
;   - $E000..$EFFF = UNUSED — scanned across 6 VRAM dumps → reserved for VWF
;   - Tilemap idx $0200 + canvas_idx → VRAM byte $E000 + canvas_idx*16
;   - VWF_VRAM_BASE_WORD = $7000 (word addr of canvas_idx=0)
;
; TILEMAP (research 1.1/1.7):
;   top    = ($0200 + canvas_idx) | $2000   ; palette 0
;   bottom = ($0200 + canvas_idx) | $2400   ; palette 1 (same tile, palette trick)
;
; ALGORITHM (Python-validated):
;   pen_tile   = PX >> 3
;   canvas_lo  = CANVAS_BASE + pen_tile
;   canvas_hi  = canvas_lo + 1
;   sub_x      = PX & 7,  right_shift = 8 - sub_x
;   for y in 0..15:
;     g = font[char*16 + y]
;     canvas[canvas_lo][y] |= (g >> sub_x)
;     if sub_x > 0:
;       canvas[canvas_hi][y] |= (g << right_shift) & 0xFF
;   tilemap[LINE_X + pen_tile*2]     = ($0200 + canvas_lo) | $2000  (+top/bot)
;   tilemap[LINE_X + (pen_tile+1)*2] = ($0200 + canvas_hi) | $2000
;   PX += WidthTable[char]
;   LINE_MAX_TILE = max(LINE_MAX_TILE, pen_tile + 1)
;
; [cls] at $81:ECE5: full reset (CANVAS_BASE=0, PX=0, MAGIC=$5A)
; NMI  at $00:D474: partial DMA canvas[DMA_LO..DMA_HI] → VRAM $7000 (word addr)
; ============================================================================

lorom

; ----------------------------------------------------------------------------
; WRAM scratch — bank $00, $0780..$079D
; ----------------------------------------------------------------------------
!VWF_SRC_PTR        = $0780     ; 3 bytes
!VWF_DIRTY          = $0784     ; 1 byte: $A5 = NMI must DMA
!VWF_SAVX           = $0786     ; 2 bytes
!VWF_LEFT_CANVAS    = $0788     ; 1 byte
!VWF_RIGHT_CANVAS   = $0789     ; 1 byte
!VWF_DMA_LO         = $078A     ; 1 byte
!VWF_DMA_HI         = $078B     ; 1 byte
!VWF_PX             = $078C     ; 2 bytes
!VWF_SUB_X          = $078E     ; 1 byte
!VWF_CANVAS_BASE    = $078F     ; 1 byte
!VWF_LEFT_PTR       = $0790     ; 3 bytes
!VWF_RIGHT_PTR      = $0793     ; 3 bytes
!VWF_LINE_X         = $0796     ; 2 bytes
!VWF_PREV_X         = $0798     ; 2 bytes
!VWF_TMP            = $079A     ; 1 byte
!VWF_LINE_MAX_TILE  = $079B     ; 1 byte
!VWF_MAGIC          = $079C     ; 1 byte: $5A = initialized
!VWF_RIGHT_SHIFT    = $079D     ; 1 byte

; ----------------------------------------------------------------------------
; Canvas + VRAM (per research 1.8)
; Canvas $7F:5D00, 48 tiles × 16 B. VRAM tile idx $0200..$022F at byte $E000.
; ----------------------------------------------------------------------------
!TILE_BUF              = $7F5D00
!VWF_VRAM_BASE_WORD    = $7000        ; word addr for canvas_idx=0 → byte $E000
!VWF_TILE_INDEX_BASE   = $0200        ; tilemap tile idx = $0200 + canvas_idx
!VWF_NUM_SLOTS         = $30          ; 48 canvas tiles (768 B buffer)

!FONT_BANK             = $2E
!FONT_OFFS             = $8000

; ----------------------------------------------------------------------------
; Hook sites
; ----------------------------------------------------------------------------
org $00C17B
    JML VWFHook
    NOP : NOP : NOP : NOP
    NOP : NOP : NOP : NOP
    NOP : NOP : NOP : NOP
    NOP : NOP : NOP

org $00D474
    JSL VWFNMI

org $81ECE5
    JSL VWFClsHook
    NOP

; ----------------------------------------------------------------------------
; VWF code
; ----------------------------------------------------------------------------
org $E08000

; ============================================================================
; VWFHook — per-char tilemap entry.
; Entry: M=X=16; caller PHA'd char (16-bit); X = tilemap byte offset.
; Exit:  JML $00C18E (past original tilemap write).
; ============================================================================
VWFHook:
    PLA                     ; A = char
    STX !VWF_SAVX
    CMP #$0100              ; Option D discriminator: chrome ≥ $0100
    BCC .text_char
    JMP .chrome_pt
.text_char:
    PHA                     ; preserve char; now stack = [char(2), return(2)]
    ; --- caller discriminator (research 1.2/1.3) ---
    ; Text path: JSR from $BE75 → return $BE78
    ; Chrome/setup path: JSR from $BECD → return $BED0
    ; Peek return addr at [3,S] (above the just-PHA'd char).
    LDA $3,S
    CMP #$BE78
    BEQ .caller_ok
    JMP .pt_pop_char
.caller_ok:
    LDA $0A0A               ; Research 1.5: paced dialog has $0A0A != 0
    BNE .dialog_active
    JMP .pt_pop_char

.dialog_active:
    ; Self-heal: MAGIC != $5A → full init (handles save-state resume)
    SEP #$20
    LDA !VWF_MAGIC
    CMP #$5A
    BEQ .magic_ok
    STZ !VWF_CANVAS_BASE
    STZ !VWF_LINE_MAX_TILE
    STZ !VWF_DIRTY
    LDA #$FF
    STA !VWF_DMA_LO
    LDA #$00
    STA !VWF_DMA_HI
    LDA #$5A
    STA !VWF_MAGIC
    REP #$20
    LDA #$0000
    STA !VWF_PX
    LDA #$FFFF
    STA !VWF_PREV_X
    BRA .line_check
.magic_ok:
    REP #$20

.line_check:
    ; delta = SAVX - PREV_X; != 2 → new line
    LDA !VWF_SAVX
    SEC
    SBC !VWF_PREV_X
    CMP #$0002
    BEQ .same_line

    ; New line: CANVAS_BASE += LINE_MAX_TILE + 1, PX=0, LINE_X=SAVX
    SEP #$20
    LDA !VWF_LINE_MAX_TILE
    BEQ .no_advance_base
    CLC
    ADC !VWF_CANVAS_BASE
    CLC
    ADC #$01
    STA !VWF_CANVAS_BASE
.no_advance_base:
    STZ !VWF_LINE_MAX_TILE
    REP #$20
    LDA #$0000
    STA !VWF_PX
    LDA !VWF_SAVX
    STA !VWF_LINE_X
.same_line:
    LDA !VWF_SAVX
    STA !VWF_PREV_X

    ; Compute pen_tile, sub_x, right_shift
    SEP #$20
    LDA !VWF_PX
    LSR : LSR : LSR
    STA !VWF_LEFT_CANVAS    ; temp: pen_tile
    LDA !VWF_PX
    AND #$07
    STA !VWF_SUB_X
    LDA #$08
    SEC
    SBC !VWF_SUB_X
    STA !VWF_RIGHT_SHIFT

    ; canvas_lo = CANVAS_BASE + pen_tile
    LDA !VWF_CANVAS_BASE
    CLC
    ADC !VWF_LEFT_CANVAS
    STA !VWF_LEFT_CANVAS
    CLC
    ADC #$01
    STA !VWF_RIGHT_CANVAS

    ; Saturation
    CMP #!VWF_NUM_SLOTS
    BCC .in_slot_range
    JMP .saturate

.in_slot_range:
    ; LINE_MAX_TILE = max(LINE_MAX_TILE, pen_tile + 1)
    LDA !VWF_PX
    LSR : LSR : LSR
    CLC
    ADC #$01
    CMP !VWF_LINE_MAX_TILE
    BCC .no_max_update
    STA !VWF_LINE_MAX_TILE
.no_max_update:

    ; Dirty bounds
    LDA !VWF_DIRTY
    CMP #$A5
    BEQ .bounds_ready
    LDA #$FF
    STA !VWF_DMA_LO
    LDA #$00
    STA !VWF_DMA_HI
.bounds_ready:
    LDA !VWF_LEFT_CANVAS
    CMP !VWF_DMA_LO
    BCS .no_lo
    STA !VWF_DMA_LO
.no_lo:
    LDA !VWF_RIGHT_CANVAS
    CMP !VWF_DMA_HI
    BCC .no_hi
    STA !VWF_DMA_HI
.no_hi:
    LDA #$A5
    STA !VWF_DIRTY

    ; LEFT_PTR = $7F:5D00 + canvas_lo*16
    REP #$20
    LDA !VWF_LEFT_CANVAS
    AND #$00FF
    ASL : ASL : ASL : ASL
    CLC
    ADC #$5D00
    STA !VWF_LEFT_PTR
    SEP #$20
    LDA #$7F
    STA !VWF_LEFT_PTR+2

    ; RIGHT_PTR = $7F:5D00 + canvas_hi*16
    REP #$20
    LDA !VWF_RIGHT_CANVAS
    AND #$00FF
    ASL : ASL : ASL : ASL
    CLC
    ADC #$5D00
    STA !VWF_RIGHT_PTR
    SEP #$20
    LDA #$7F
    STA !VWF_RIGHT_PTR+2

    ; SRC_PTR = $2E:$8000 + char*16
    REP #$20
    LDA $1,S
    AND #$00FF
    ASL : ASL : ASL : ASL
    CLC
    ADC #$8000
    STA !VWF_SRC_PTR
    SEP #$20
    LDA #!FONT_BANK
    STA !VWF_SRC_PTR+2

    ; Shift-and-OR render (16 bytes). M=8, X=Y=8 throughout render body.
    PHD
    REP #$20
    LDA #$0780
    TCD                     ; DP=$0780: [$00]=SRC_PTR, [$10]=LEFT_PTR, [$13]=RIGHT_PTR
    SEP #$30
    LDY #$00
.render_loop:
    LDA [$00],Y
    STA $1A                 ; TMP
    LDX $0E                 ; SUB_X
    BEQ .skip_right_shift
.lsr_loop:
    LSR A
    DEX
    BNE .lsr_loop
.skip_right_shift:
    ORA [$10],Y
    STA [$10],Y

    LDX $0E
    BEQ .skip_right
    LDA $1A
    LDX $1D                 ; RIGHT_SHIFT
.lsl_loop:
    ASL A
    DEX
    BNE .lsl_loop
    ORA [$13],Y
    STA [$13],Y
.skip_right:
    INY
    CPY #$10
    BNE .render_loop
    REP #$10
    PLD

    ; Tilemap writes
    REP #$30
    LDA !VWF_PX
    AND #$00FF
    LSR : LSR : LSR         ; pen_tile
    ASL
    CLC
    ADC !VWF_LINE_X
    TAX

    ; LEFT cell: top + bottom (palette trick)
    LDA !VWF_LEFT_CANVAS
    AND #$00FF
    CLC
    ADC #!VWF_TILE_INDEX_BASE
    ORA #$2000              ; priority + palette 0
    STA $7E9000,X
    CLC
    ADC #$0400              ; palette 1
    STA $7E9040,X

    ; RIGHT cell: top + bottom at X+2
    LDA !VWF_RIGHT_CANVAS
    AND #$00FF
    CLC
    ADC #!VWF_TILE_INDEX_BASE
    ORA #$2000
    STA $7E9002,X
    CLC
    ADC #$0400
    STA $7E9042,X

    ; Advance pen by width
    LDA $1,S
    AND #$00FF
    TAX
    SEP #$20
    LDA.l WidthTable,X
    REP #$20
    AND #$00FF
    CLC
    ADC !VWF_PX
    STA !VWF_PX

    PLA                     ; pop char
    JML $00C18E

.saturate:
    REP #$30
.pt_pop_char:
    PLA
.fixed_write:
    LDX !VWF_SAVX
    CLC
    ADC $0A02
    PHA
    STA $7E9000,X
    PLA
    CLC
    ADC #$0400
    STA $7E9040,X
    JML $00C18E

.chrome_pt:
    BRA .fixed_write

; ============================================================================
; VWFNMI — partial DMA of dirty canvas range → VRAM word $7000 (byte $E000).
; ============================================================================
VWFNMI:
    LDA !VWF_DIRTY
    CMP #$A5
    BNE .replay
    LDA !VWF_DMA_LO
    CMP !VWF_DMA_HI
    BEQ .check_single
    BCS .dma_done
.check_single:
    LDA !VWF_DMA_LO
    CMP #$FF
    BEQ .dma_done

    ; VRAM word addr = base + lo*8
    REP #$20
    LDA !VWF_DMA_LO
    AND #$00FF
    ASL : ASL : ASL
    CLC
    ADC.w #!VWF_VRAM_BASE_WORD
    STA $2116
    SEP #$20

    LDA #$80
    STA $2115

    ; src = $7F:5D00 + lo*16
    REP #$20
    LDA !VWF_DMA_LO
    AND #$00FF
    ASL : ASL : ASL : ASL
    CLC
    ADC.w #$5D00
    STA $4372
    SEP #$20
    LDA #$7F
    STA $4374

    ; bytes = (hi - lo + 1) * 16
    REP #$20
    LDA !VWF_DMA_HI
    AND #$00FF
    SEC
    SBC !VWF_DMA_LO
    AND #$00FF
    INC A
    ASL : ASL : ASL : ASL
    STA $4375
    SEP #$20

    LDA #$01
    STA $4370
    LDA #$18
    STA $4371

    LDA #$80
    STA $420B

    LDA #$FF
    STA !VWF_DMA_LO
    LDA #$00
    STA !VWF_DMA_HI
    STZ !VWF_DIRTY
.dma_done:

.replay:
    LDA $10
    BEQ .beq_taken
    RTL
.beq_taken:
    PLA : PLA : PLA
    JML $00D482

; ============================================================================
; VWFClsHook — [cls] at $81:ECE5. Full reset.
; ============================================================================
VWFClsHook:
    PHP
    SEP #$20
    STZ !VWF_CANVAS_BASE
    STZ !VWF_LINE_MAX_TILE
    STZ !VWF_DIRTY
    LDA #$FF
    STA !VWF_DMA_LO
    LDA #$00
    STA !VWF_DMA_HI
    LDA #$5A
    STA !VWF_MAGIC
    PLP
    REP #$20
    LDA #$0000
    STA !VWF_PX
    LDA #$FFFF
    STA !VWF_PREV_X
    LDA #$2000              ; restore displaced LDA
    RTL

; ============================================================================
; WidthTable — 256 bytes
; ============================================================================
WidthTable:
    incbin "../en_data/bin/fonts/font_widths.bin"
