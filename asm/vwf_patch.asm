; ============================================================================
; vwf_patch.asm — Variable-width font for Little Master III
;
; Rebuild from scratch after v4.2 (asm/old/vwf_patch_v4.2_failed.asm) failed.
; Active plan: /home/daniel/.claude/plans/gentle-wibbling-valiant.md
; Research:    docs/vwf_research.md  (Phase 1, all 8 sub-steps verified)
;
;   STEP A..C.1  (passed) — hook + gate + DMA stub.
;
;   STEP D (previous revision — had slot collision bug):
;       Used slot = (X/2) mod 48. Line-2 cells wrapped onto line-1 slots,
;       so line-2 writes overwrote line-1 glyphs in VRAM while line-1
;       tilemap still pointed at those tiles → line-1 displayed line-2
;       content ("repeating lines"), and earlier content was trampled.
;
;   STEP D.1 (this revision) — fix slot collision + partial DMA.
;       • Slot = X/2 directly (no mod). Clamped if >= 80. 80 slots covers
;         2 dialog lines with margin.
;       • Tile index base = $B0 → $FF ($50 slots). VRAM $CB00..$D000
;         (inside font region; $CE/$CF glyphs overwritten — those are
;         icon chars unused in English dialog).
;       • NMI DMAs only the sub-range [dirty_lo..dirty_hi] that changed
;         since last NMI. Cheap when reveal emits 1 glyph/frame.
;       • [cls] reset (Phase-1 tilemap blank at $81:ECE5) clears slot
;         bounds so next page starts fresh.
;
;   STEP D.1a — relocate scratch out of $0A30 (game-owned).
;       Prior scratch at $0A30..$0A3F collided with text-engine state;
;       dirty flag + slot got clobbered every char, so divert never
;       engaged and display reverted to fixed-width passthrough. Probed
;       $0780..$078F: zero at boot, stable through full dialog. Scratch
;       relocated there. Font copy switches DP via PHD/TCD to reach
;       the 3-byte src ptr as [dp],Y.
;
;       Font layout (verified via IPC 2026-04-21):
;         BG1 char base word = $6000 (byte $C000).
;         Char code N → tile index N → VRAM byte $C000 + N*16.
;         Font .bin slots $B0..$FF: $C0..$CD + $D0..$FF blank; $B0..$BF
;         all blank; $CE/$CF nonblank but unused in EN dialog.
;
;   STEP E  — shift-and-blend proportional render (pen cursor + width).
;
; ============================================================================

lorom

; ----------------------------------------------------------------------------
; WRAM scratch — bank $00, $0780..$078F (verified unused at boot and through
; dialog on 2026-04-21). Must stay in bank $00 so the font-copy loop can
; reach the 3-byte src ptr via [dp],Y (DP is always bank $00).
; ----------------------------------------------------------------------------
!VWF_SRC_PTR = $0780      ; 3-byte font src ptr ($0780..$0782)
!VWF_DIRTY   = $0784      ; $A5 = NMI must DMA
!VWF_SAVX    = $0786      ; saved tilemap X (16-bit)
!VWF_SLOT    = $0788      ; 16-bit current slot
!VWF_DMA_LO  = $078A      ; min slot dirty since last DMA (8-bit, $FF=none)
!VWF_DMA_HI  = $078B      ; max slot dirty since last DMA ($00=none)
!VWF_PX      = $078C      ; 16-bit pixel X cursor (Step E)
!VWF_SLOT_COUNTER = $078E ; 8-bit monotonic slot idx, wraps at NUM_SLOTS; reset by [cls] hook

; ----------------------------------------------------------------------------
; VWF tile buffer — $7F:5D00..$5FFF = $300 B = 48 tiles × 16 B.
; VRAM $CD00..$D000 = 48 tiles at indices $D0..$FF.
;
; STEP D.1b: relocated from $7F:B000 — collided with game's dmaTilemapToVRAM
; (at $00:D927) which DMAs $7F:B000..$B7FF → VRAM as tilemap source. Our tile
; data got DMA'd as tilemap during title screen, wiping our tiles AND
; corrupting title text tilemap. $7F:5D00..$5FFF confirmed as only 768-byte
; zero run in WRAM outside known DMA source regions ($7F:B000 tilemap,
; $7F:D000 overlay, $7E:9000 text-tilemap).
;
; 48 slots covers ~1 dialog line. 2-line dialog collisions deferred to
; Step D.2 with [cls]/newline hooks.
; ----------------------------------------------------------------------------
!TILE_BUF   = $7F5D00
!VWF_VRAM_BASE_WORD = $6680   ; word-addr; byte $CD00 = $6000 + $D0*16
!VWF_TILE_INDEX_BASE = $00D0  ; tile idx $D0..$FF
!VWF_NUM_SLOTS = $30          ; 48

!FONT_BANK  = $2E
!FONT_OFFS  = $8000

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

; [cls] hook: reset VWF_SLOT_COUNTER so each new dialog page starts fresh
; at slot 0. Replaces 5 bytes at $81:ECE5 (REP #$20 + LDA #$2000) with
; JSL VWFClsHook + NOP. Hook re-executes the replaced behavior and zeros
; the counter.
;
; Disasm verified 2026-04-21:
;   $81:ECE5  C2 20        REP #$20
;   $81:ECE7  A9 00 20     LDA #$2000
;   $81:ECEA  8D 02 0A     STA $0A02   (untouched)
org $81ECE5
    JSL VWFClsHook
    NOP

; ----------------------------------------------------------------------------
; VWF code
; ----------------------------------------------------------------------------
org $E08000

; ============================================================================
; VWFHook — per-char tilemap entry point.
; Entry: 16-bit A/X, DBR=$00, [1,S] = char (pushed by caller), X = tilemap X
; ============================================================================
VWFHook:
    PLA                     ; A = char (16-bit)
    STX !VWF_SAVX
    CMP #$0100
    BCC .char_in_range
    JMP .chrome_passthrough
.char_in_range:
    PHA                     ; [1,S] = char
    LDA $0A10               ; dialog gate
    BNE .dialog_active
    JMP .text_passthrough
.dialog_active:

    ; ---- slot allocation: per-page saturating counter (D.1d) ----
    ; Mod-(X/2) aliased with $60-byte tilemap line stride so every line
    ; collapsed onto the same slots. Now: monotonic counter 0..NUM_SLOTS-1;
    ; [cls] hook resets it per page. On saturation (page >NUM_SLOTS chars)
    ; fall through to fixed-width passthrough so earlier VWF tiles stay
    ; intact — rather than wrapping and overwriting them.
    SEP #$20
    LDA !VWF_SLOT_COUNTER
    CMP #!VWF_NUM_SLOTS
    BCC .have_slot
    REP #$20
    JMP .text_passthrough
.have_slot:
    STA.w !VWF_SLOT         ; low byte
    STZ.w !VWF_SLOT+1       ; high byte zeroed
    INC A
    STA !VWF_SLOT_COUNTER
    REP #$20

    ; ---- update dirty bounds ----
    ; If DIRTY != $A5 (first entry, or post-NMI reset), reset bounds
    ; to sentinel LO=$FF HI=$00 so this char's slot becomes the new lo+hi.
    SEP #$20
    LDA !VWF_DIRTY
    CMP #$A5
    BEQ .bounds_ready
    LDA #$FF
    STA !VWF_DMA_LO
    LDA #$00
    STA !VWF_DMA_HI
.bounds_ready:
    LDA !VWF_SLOT
    CMP !VWF_DMA_LO
    BCS .no_lo_update
    STA !VWF_DMA_LO
.no_lo_update:
    LDA !VWF_SLOT
    CMP !VWF_DMA_HI
    BCC .no_hi_update
    STA !VWF_DMA_HI
.no_hi_update:
    LDA #$A5
    STA !VWF_DIRTY
    REP #$20

    ; ---- font src ptr: $2E:$8000 + char*16, stored at $0780..$0782 ----
    LDA $1,S
    ASL : ASL : ASL : ASL
    CLC
    ADC #$8000
    STA !VWF_SRC_PTR
    SEP #$20
    LDA #$2E
    STA !VWF_SRC_PTR+2
    REP #$20

    ; ---- copy 16 B: [dp],Y → $7F:5D00,X (X = slot*16) ----
    ; DP swap so [dp],Y at dp=$00 reads from $0780..$0782.
    PHD
    LDA #$0780
    TCD
    LDA !VWF_SLOT
    ASL : ASL : ASL : ASL
    TAX
    LDY #$0000
.font_copy:
    LDA [$00],Y
    STA $7F5D00,X
    INX : INX
    INY : INY
    CPY #$0010
    BNE .font_copy
    PLD

    ; ---- divert: replace char on stack with ($B0 + slot) ----
    LDA !VWF_SLOT
    CLC
    ADC.w #!VWF_TILE_INDEX_BASE
    STA $1,S
    PLA
    BRA .write_tilemap

.text_passthrough_unstack:
    ; already have PHA from text path; fall through
.text_passthrough:
    PLA
    BRA .write_tilemap

.chrome_passthrough:
    ; A = char (chrome)
.write_tilemap:
    LDX !VWF_SAVX
    CLC
    ADC $0A02               ; $2000 priority
    PHA
    STA $7E9000,X
    PLA
    CLC
    ADC #$0400              ; palette-1
    STA $7E9040,X
    JML $00C18E

; ============================================================================
; VWFNMI — partial DMA of dirty slot sub-range.
; A=8-bit, X/Y=16-bit on entry.
; ============================================================================
VWFNMI:
    LDA !VWF_DIRTY
    CMP #$A5
    BNE .replay
    LDA !VWF_DMA_LO
    CMP !VWF_DMA_HI         ; lo > hi → no writes queued
    BEQ .check_single
    BCS .dma_done           ; lo > hi (sentinel state)
.check_single:
    ; lo == hi: single slot OR both FF (none). Treat FF sentinel as none.
    LDA !VWF_DMA_LO
    CMP #$FF
    BEQ .dma_done

    ; Compute slot_count = hi - lo + 1
    ; VRAM word addr = $6000 + (lo + $B0)*8 = $6580 + lo*8
    ; src = $7F:B000 + lo*16
    ; bytes = (hi - lo + 1) * 16

    REP #$20
    LDA !VWF_DMA_LO
    AND #$00FF              ; A = lo (16-bit)
    ASL : ASL : ASL         ; lo*8
    CLC
    ADC.w #!VWF_VRAM_BASE_WORD
    STA $2116               ; VMADDL/H (16-bit write covers both)
    SEP #$20

    LDA #$80
    STA $2115               ; VMAIN inc after $2119

    ; src = $7F:5D00 + lo*16
    REP #$20
    LDA !VWF_DMA_LO
    AND #$00FF
    ASL : ASL : ASL : ASL   ; lo*16
    CLC
    ADC.w #$5D00
    STA $4372               ; A1T7L/M (16-bit)
    SEP #$20
    LDA #$7F
    STA $4374               ; bank

    ; count bytes = (hi - lo + 1) * 16
    REP #$20
    LDA !VWF_DMA_HI
    AND #$00FF
    SEC
    SBC !VWF_DMA_LO
    AND #$00FF
    INC A
    ASL : ASL : ASL : ASL   ; ×16
    STA $4375               ; DAS7L/H
    SEP #$20

    ; DMA config: ch7, mode 1 (2-byte to 2 regs), dest $2118
    LDA #$01
    STA $4370
    LDA #$18
    STA $4371

    LDA #$80
    STA $420B               ; enable ch7

    ; reset dirty bounds to "none"
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
; VWFClsHook — [cls] / initTilemapRegion entry at $81:ECE5.
; Replaces original REP #$20 ; LDA #$2000 (5 bytes). Resets slot counter
; then re-executes the replaced behavior so the caller sees A=$2000, M=16.
; Entry flag state: caller doesn't assume anything specific (this is the
; very first instruction of initTilemapRegion).
; ============================================================================
VWFClsHook:
    SEP #$20
    STZ !VWF_SLOT_COUNTER
    ; also clear dirty bounds so next char is a fresh range
    LDA #$FF
    STA !VWF_DMA_LO
    LDA #$00
    STA !VWF_DMA_HI
    STZ !VWF_DIRTY
    REP #$20
    LDA #$2000              ; restore replaced LDA
    RTL

; ============================================================================
; End Step D.1d
; ============================================================================
