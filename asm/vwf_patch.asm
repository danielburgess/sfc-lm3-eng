; ============================================================================
; vwf_patch.asm — Variable-width font for Little Master III (RECOVERY BUILD)
; ----------------------------------------------------------------------------
; Restored from bedd8a6 ("static rendering is working for VWF") + 399ebe5
; ([cls] reset hook + bank $E0 relocation) + saturating-bounds lesson from
; the post-restart work.
;
; DESIGN
;   - Per-char hook at $80:C17B replaces the game's per-character tilemap
;     write with VWFCharHandler. Non-renderable chars and out-of-range
;     codes pass through to the original tilemap-write path (.origPath).
;   - Wrapper hook at $80:BC75 brackets the call to processText with
;     VWFPreRender (set up canvas + flag + sentinels) and VWFPostRender
;     (synchronous bulk DMA of the canvas into VRAM, then clear flag).
;     DMA is NEVER scheduled from NMI — it runs deterministically inside
;     the text routine, eliminating the race that produced flicker.
;   - [cls] hook at $80:C022 replaces the JSL initTilemapAndSync_Long
;     dispatched by textStream_ExtFF for the [cls] opcode. It runs the
;     original clear+sync first, then resets the WRAM canvas + sentinels
;     so the next page renders with no leftover pixels.
;
; CONTROL-CODE CONTRACT
;   FF control codes (and their parameter bytes) are dispatched by Phase 2
;   (processText, $80:BF64) BEFORE they ever reach the per-char tilemap
;   path. The VWF hook is layered on top of the renderable-character path
;   only; control-code semantics (FFC0 redirect, [cls], [pause], [msg],
;   embedded pointers, DTE, [nl], etc.) remain bit-identical to the
;   original engine. Any non-renderable byte that does reach $C17B is
;   filtered to .origPath so the original tile write executes unchanged.
;
; SATURATING-BOUNDS LESSON
;   The static-working build wrote tilemap entries even past the canvas
;   width (col >= 32), pointing at tiles whose buffer slots were never
;   filled. On long lines this produced garbage glyphs after the canvas
;   filled. Recovery routes bounds-exceeded chars to .doOrig instead of
;   .skipRender, so any char beyond canvas capacity falls back to the
;   original fixed-width tile path (legible glyph, no buffer overrun).
;
; FONT BINARIES
;   en_data/fonts/font_accented_widths.bin    (256 widths, 1 byte each)
;   en_data/bin/fonts/font_accented_1bpp.bin  (1bpp 8x16 sequential glyphs)
;
; CODE BANK
;   VWF body lives at $E0:8000 (NOT $C0 — title_chunks land at PC 0x200000
;   in the expanded ROM and would collide with $C0:8000).
; ============================================================================

lorom                                       ; standard LoROM mapping for asar

; ROM expansion to 24 Mbit so $E0 bank is reachable
org $00FFD7 : db $0C                        ; SNES header byte: ROM size = 24 Mbit
org $FFFFFF : db $00                        ; force ROM image to extend through bank $FF

; ----------------------------------------------------------------------------
; WRAM scratch — game-unused window in $0A30..$0A3B
; ----------------------------------------------------------------------------
!VWF_PX     = $0A30                         ; 16-bit pen X position in absolute pixels
!VWF_FLAG   = $0A34                         ; 8-bit gate: $A5 = VWF active, $00 = idle
!VWF_SAVX   = $0A36                         ; 16-bit save slot for X (tilemap byte offset)
!VWF_ROW    = $0A3A                         ; 16-bit copy of $09FE for newline detection

; Canvas (the offscreen 2bpp tile RAM that DMAs to VRAM)
!TILE_BUF   = $7FB000                       ; 4 KB buffer = 4 rows x 32 cols x 32 B/col

; Saturation guard — when computed tile column >= this value, fall back to
; the original tile path so we never write a tilemap entry pointing at an
; un-rendered slot.
!VWF_MAX_COL = $0020                        ; 32 columns per canvas row

; ============================================================================
; Hook 1 — per-character entry  ($80:C17B, 20 bytes overwritten)
; The displaced game code pulled the char off the stack and wrote its tile.
; We replicate the "pull char + stash" prelude and dispatch into our handler.
; The handler ends in RTL so we balance our JSL.L; the trailing RTS returns
; through the original game caller's JSR.
; ============================================================================
org $80C17B
    PLA                                     ; pop 16-bit char value pushed by caller
    STA.W $0A38                             ; stash char in scratch ($0A38 = char latch)
    JSL.L VWFCharHandler                    ; long-call handler (renders or passes through)
    RTS                                     ; return to original game caller (subroutine boundary)
    padbyte $EA : pad $80C18F               ; NOP-fill remaining slot bytes through $80:C18E

; ============================================================================
; Hook 2 — processText wrapper  ($80:BC75, 15 bytes overwritten)
; Original 15 bytes initialized $14/$16, called processText ($80:BE3B), and
; performed cleanup. We split that into:
;   PreRender  → carries displaced LDA/STA/STZ + sets VWF_FLAG + clears canvas
;   processText → unchanged JSR
;   PostRender → carries displaced REP/LDA $0A16 + bulk-DMA canvas into VRAM
; DMA happens HERE, synchronously, so it can never race the per-char writes.
; ============================================================================
org $80BC75
    JSL.L VWFPreRender                      ; 4 bytes — set up VWF state, run displaced setup
    JSR.W $BE3B                             ; 3 bytes — call processText (Phase 2 dispatcher)
    JSL.L VWFPostRender                     ; 4 bytes — bulk VRAM upload + run displaced cleanup
    NOP : NOP : NOP : NOP                   ; 4 bytes — pad to original 15-byte slot

; ============================================================================
; Hook 3 — [cls] page transition  ($80:C022, 4 bytes overwritten)
; textStream_ExtFF dispatch for the [cls] opcode previously called
; initTilemapAndSync_Long ($81:ECE1). Replace with VWFClsHook which calls
; the original first, then resets VWF state so the new page is clean.
; ============================================================================
org $80C022
    JSL.L VWFClsHook                        ; 4 bytes — same size as displaced JSL

; ============================================================================
; VWF body — bank $E0 (avoids $C0 collision with title_chunks @ PC 0x200000)
; ============================================================================
org $E08000

; ----------------------------------------------------------------------------
; VWFCharHandler  (called per character)
; Entry:  16-bit A/X active, $0A38 = char value, X = tilemap byte offset
; Exit:   RTL, X restored where the caller expects it, tilemap + canvas
;         updated for renderable chars, or original game write executed for
;         pass-through cases (icons, control bytes, sub-space, saturated col)
; ----------------------------------------------------------------------------
VWFCharHandler:
    SEP #$20                                ; switch A/M to 8-bit for flag byte read
    LDA.W !VWF_FLAG                         ; load VWF active flag (8-bit)
    CMP.B #$A5                              ; sentinel meaning "VWF currently rendering"
    REP #$20                                ; restore 16-bit A/M before any branch
    BEQ .vwf                                ; flag matched → take VWF path

; --- Original tilemap write (pass-through path) -----------------------------
; This is the byte-exact tile write the displaced game code performed.
; All non-VWF traffic flows through here unchanged.
.origPath:
    LDA.W $0A38                             ; reload char value (16-bit)
    CLC : ADC.W $0A02                       ; add palette/priority bits from text-engine state
    PHA : STA.L $7E9000,X                   ; push composed word, store as TOP tilemap entry
    PLA : CLC : ADC.W #$0400                ; restore word + add palette-row offset for bottom
    STA.L $7E9040,X                         ; store as BOTTOM tilemap entry (paired tile)
    RTL                                     ; long-return to caller (balances JSL.L from hook)

; --- VWF path ---------------------------------------------------------------
.vwf:
    STX.W !VWF_SAVX                         ; preserve tilemap byte offset for later writes

    ; Newline detection: $09FE is the game's text row id. If it changed (or
    ; this is the first char of the page), reset VWF_PX to align with the
    ; current column so the new line starts at the correct pixel x.
    REP #$20                                ; ensure 16-bit for word compare
    LDA.W $09FE                             ; current text row id
    CMP.W !VWF_ROW                          ; compare against our saved row
    BEQ .sameLine                           ; same row → keep current pen
    LDA.W $09FC                             ; col index for the new row
    ASL A : ASL A : ASL A                   ; *8 → pixel x position (8 px per tile)
    STA.W !VWF_PX                           ; reset pen to start of new column
    LDA.W $09FE                             ; reload current row
    STA.W !VWF_ROW                          ; remember it for next compare
.sameLine:

    ; Character filtering — restrict VWF to printable font range.
    REP #$20                                ; 16-bit for word compare
    LDA.W $0A38                             ; load char value
    CMP.W #$0100 : BCS .doOrig              ; >=$0100 are chrome/icons → pass through
    AND.W #$00FF                            ; mask to byte (clears any stale high bits)
    STA.B $00                               ; $00 = clean 16-bit char index
    CMP.W #$00F0 : BCS .doOrig              ; chars $F0..$FF reserved/non-glyph → pass through
    CMP.W #$0020 : BCC .doOrig              ; chars below space → pass through (control range)
    BRA .doRender                           ; survived filters → render as VWF glyph

.doOrig:
    LDX.W !VWF_SAVX                         ; restore tilemap offset that origPath expects in X
    JMP .origPath                           ; tail-call original write (RTL there exits us)

.doRender:
    ; Width lookup — TAX uses 16-bit char as table index into width table.
    TAX                                     ; X = char index (full 16-bit)
    SEP #$20                                ; widths are 1 byte each
    LDA.L VWFWidthTable,X                   ; A = pixel width (0..8)
    STA.B $02                               ; $02 = width (8-bit), kept for advance step
    REP #$20                                ; back to 16-bit for masked compare
    AND.W #$00FF                            ; isolate width byte
    BNE .hasWidth                           ; width > 0 → render glyph

    ; Width 0 (e.g. space) — don't render, but still emit a blank tilemap
    ; entry so the cursor cell gets a clean BG colour.
    LDX.W !VWF_SAVX                         ; restore tilemap byte offset
    LDA.W $0A02                             ; current palette/priority bits
    STA.L $7E9000,X                         ; blank top tilemap entry
    CLC : ADC.W #$0400                      ; add palette-row offset for bottom
    STA.L $7E9040,X                         ; blank bottom tilemap entry
    RTL                                     ; done with this char

.hasWidth:
    ; Row index = ($09FE >> 1) & 3  → 4 row slots support 3+ text lines
    ; without colliding into the same canvas rows.
    LDA.W $09FE                             ; text row id
    LSR A : AND.W #$0003                    ; halve, mask to 0..3
    STA.B $04                               ; $04 = canvas row index

    ; Tile column = VWF_PX >> 3  (each tile is 8 px wide).
    LDA.W !VWF_PX                           ; pen pixel x
    LSR A : LSR A : LSR A                   ; /8 → tile column index
    STA.B $06                               ; $06 = tile col

    ; Saturation guard (recovered lesson). If column would overflow the
    ; canvas, fall back to the original tile path so we never reference
    ; an un-rendered VWF slot from the tilemap.
    CMP.W #!VWF_MAX_COL                     ; col vs canvas width
    BCC .inBounds                           ; in bounds → keep rendering
    JMP .doOrig                             ; out of bounds → original-tile fallback
.inBounds:

    ; Sub-pixel shift = VWF_PX & 7
    LDA.W !VWF_PX                           ; pen pixel x
    AND.W #$0007                            ; isolate 0..7 sub-tile shift
    STA.B $08                               ; $08 = shift, also valid as 16-bit zero-high LDX

    ; Buffer base offset = row * 1024 + col * 32
    LDA.B $04                               ; row
    XBA                                     ; row << 8
    ASL A : ASL A                           ; row << 10 (multiply by 1024)
    STA.B $0A                               ; partial: row*1024
    LDA.B $06                               ; col
    ASL A : ASL A : ASL A : ASL A : ASL A   ; col << 5 (multiply by 32)
    CLC : ADC.B $0A                         ; add row*1024
    STA.B $0A                               ; $0A = canvas top-tile byte offset

    ; Font glyph offset = char * 16  (16 bytes per glyph: 8 top + 8 bottom)
    LDA.B $00                               ; char index
    ASL A : ASL A : ASL A : ASL A           ; *16
    STA.B $0C                               ; $0C = font byte index

    ; --- Render 16 rows: rows 0..7 → top tile, rows 8..15 → bottom tile ---
    LDY.W #$0000                            ; Y = pixel row counter

.rowLoop:
    REP #$20                                ; 16-bit for index math
    TYA : CLC : ADC.B $0C                   ; A = font index + Y
    TAX                                     ; X = font byte address (within VWFFontData)
    SEP #$20                                ; 8-bit to read font byte
    LDA.L VWFFontData,X                     ; A = source font byte (8 horizontal pixels)
    STA.B $0E                               ; $0E = original (preserved for spill calc)

    LDX.B $08                               ; X = shift count (high byte already 0)
    BEQ .noSR                               ; shift 0 → skip the shift loop
.srLoop:
    LSR A : DEX : BNE .srLoop               ; shift right by sub_x positions
.noSR:
    STA.B $0F                               ; $0F = shifted byte to OR into left tile

    ; Compute write position for this row inside the canvas
    REP #$20                                ; 16-bit for offset math
    TYA                                     ; A = row counter
    CMP.W #$0008                            ; row in top half?
    BCS .botRow                             ; row >= 8 → bottom tile
    ASL A : CLC : ADC.B $0A                 ; top: pos = base + Y*2
    BRA .gotPos
.botRow:
    SEC : SBC.W #$0008                      ; relative row 0..7 within bottom tile
    ASL A : CLC : ADC.B $0A                 ; pos = base + (Y-8)*2
    CLC : ADC.W #$0010                      ; +16 to skip past top-tile bytes
.gotPos:
    STA.B $10                               ; $10 = saved canvas pos for spill calc
    TAX                                     ; X = canvas write index
    SEP #$20                                ; 8-bit for byte writes

    ; OR shifted byte into both bitplanes of the left tile (only if non-0)
    LDA.B $0F                               ; shifted byte
    BEQ .skipWrite                          ; nothing set → skip write
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp0 = bp0 | shifted
    INX                                     ; advance to bp1 byte (interleaved 2bpp)
    LDA.B $0F                               ; reload shifted byte
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp1 = bp1 | shifted
.skipWrite:

    ; --- Spillover into the next tile column when sub_x > 0 -----------------
    LDA.B $08                               ; shift (low byte read)
    BEQ .noSpill                            ; no shift → no spill
    LDA.B $0E                               ; original (un-shifted) font byte
    BEQ .noSpill                            ; original is blank → nothing to spill

    ; spill = original << (8 - sub_x)
    SEP #$20                                ; ensure 8-bit math
    LDA.B #$08                              ; constant 8
    SEC : SBC.B $08                         ; A = 8 - shift
    REP #$20                                ; 16-bit for AND/TAX
    AND.W #$00FF                            ; clean high byte
    TAX                                     ; X = left-shift count
    SEP #$20                                ; back to 8-bit
    LDA.B $0E                               ; original font byte
    CPX.W #$0000 : BEQ .noSL                ; 0 shifts → no shift loop
.slLoop:
    ASL A : DEX : BNE .slLoop               ; shift left X times
.noSL:
    STA.B $0F                               ; $0F = spill byte
    CMP.B #$00                              ; STA cleared no flags — re-test for zero
    BEQ .noSpill                            ; spill is 0 → nothing to write

    ; Spill destination = saved canvas pos + 32 (next tile column)
    REP #$20                                ; 16-bit for ADC
    LDA.B $10 : CLC : ADC.W #$0020          ; pos + 32
    CMP.W #$1000                            ; bounds: must stay inside 4 KB canvas
    BCS .noSpill                            ; out of bounds → drop the spill
    TAX                                     ; X = canvas spill write index
    SEP #$20                                ; back to 8-bit for byte writes

    LDA.B $0F                               ; spill byte
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp0 OR spill
    INX                                     ; advance to bp1
    LDA.B $0F                               ; reload spill byte
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp1 OR spill
    BRA .noSpill2                           ; skip the SEP path below (already 8-bit)

.noSpill:
    SEP #$20                                ; ensure 8-bit before falling through
.noSpill2:
    INY                                     ; next pixel row
    CPY.W #$0010                            ; rendered all 16 rows?
    BCS .doneRows                           ; yes → exit the row loop
    JMP .rowLoop                            ; continue with next row

.doneRows:
    ; --- Per-character incremental VRAM upload ------------------------------
    ; Push the two newly-touched tiles into VRAM right now (forced blank,
    ; NMI off) so the screen sees the partial line as it draws. PostRender
    ; will later bulk-upload everything once processText returns.
    SEP #$20                                ; 8-bit for register writes
    SEI                                     ; mask IRQs during VRAM access
    LDA.B #$00 : STA.W $4200                ; disable NMI (NMITIMEN bit 7 cleared)
    LDA.B #$80 : STA.W $2100                ; INIDISP forced blank (allows VRAM writes)
    LDA.B #$80 : STA.W $2115                ; VMAIN: word inc on $2119 high write

    REP #$20                                ; 16-bit for VRAM addr math
    LDA.B $0A : LSR A                       ; canvas byte offset → word offset
    CLC : ADC.W #$6100                      ; +VRAM tile-$20 word base
    STA.W $2116                             ; VMADDL/H combined 16-bit write
    SEP #$20                                ; back to 8-bit for upload loop

    LDX.B $0A                               ; X = canvas read offset
    LDY.W #$0010                            ; Y = 16 word writes (= 32 bytes = 2 tiles)
.upLoop:
    LDA.L !TILE_BUF,X : STA.W $2118 : INX   ; bp0 byte → VMDATAL, advance read
    LDA.L !TILE_BUF,X : STA.W $2119 : INX   ; bp1 byte → VMDATAH, advance read
    DEY : BNE .upLoop                       ; loop until 16 word writes done

    LDA.B $58 : STA.W $2100                 ; restore INIDISP from game's brightness shadow
    LDA.B #$81 : STA.W $4200                ; re-enable NMI + auto-joypad read
    CLI                                     ; allow IRQs again

.skipRender:
    ; --- Tilemap entry write -----------------------------------------------
    ; Compose: top_tile  = $20 + row*64 + $09FC*2
    ;          bot_tile  = top_tile + 1
    ; Then OR palette/priority from $0A02 into both, plus +$0400 for bottom.
    REP #$20                                ; 16-bit for word ops
    LDX.W !VWF_SAVX                         ; restore tilemap byte offset

    LDA.B $04                               ; canvas row
    ASL A : ASL A : ASL A : ASL A : ASL A : ASL A   ; row * 64

    CLC : ADC.W $09FC                       ; + col
    CLC : ADC.W $09FC                       ; + col again (= col*2 = top tile stride)

    CLC : ADC.W #$0020                      ; + base tile $20
    PHA                                     ; save top tile id for bottom calc
    CLC : ADC.W $0A02                       ; OR palette/priority bits
    STA.L $7E9000,X                         ; write TOP tilemap entry

    PLA : INC A                             ; restore tile id, +1 for bottom tile
    CLC : ADC.W $0A02                       ; OR palette/priority bits
    CLC : ADC.W #$0400                      ; +palette-row offset for bottom
    STA.L $7E9040,X                         ; write BOTTOM tilemap entry

    ; --- Advance pen by glyph width ----------------------------------------
    SEP #$20                                ; 8-bit width add
    LDA.B $02                               ; glyph width
    REP #$20                                ; 16-bit for ADC
    AND.W #$00FF                            ; mask to byte
    CLC : ADC.W !VWF_PX                     ; pen += width
    STA.W !VWF_PX                           ; store new pen

    ; --- Restore + return ---------------------------------------------------
    REP #$20                                ; 16-bit for X restore
    LDX.W !VWF_SAVX                         ; restore X for caller
    RTL                                     ; long-return to balance JSL.L

; ----------------------------------------------------------------------------
; VWFPreRender — called before processText
; Carries displaced bytes from $80:BC75 (LDA #$0400 / STA $14 / STZ $16),
; arms VWF state, and wipes the canvas so each text emit starts clean.
; ----------------------------------------------------------------------------
org $E08F00

VWFPreRender:
    REP #$20                                ; 16-bit for displaced setup
    LDA.W #$0400 : STA.B $14                ; displaced: text-buffer ptr low + len init
    STZ.B $16                               ; displaced: zero high byte of buffer ptr

    LDA.W $09FC                             ; current column
    ASL A : ASL A : ASL A                   ; * 8 → pixel x of column start
    STA.W !VWF_PX                           ; pen = column-aligned pixel x

    LDA.W #$FFFF                            ; sentinel for "first char this emit"
    STA.W !VWF_ROW                          ; ensures row-change branch fires on first char

    SEP #$20                                ; 8-bit for flag write
    LDA.B #$A5 : STA.W !VWF_FLAG            ; arm VWF (handler now takes VWF path)
    REP #$20                                ; back to 16-bit for clear loop

    LDX.W #$0000                            ; canvas index (byte offset)
    LDA.W #$0000                            ; word zero pattern
-   STA.L !TILE_BUF,X                       ; clear two canvas bytes
    INX : INX                               ; advance by 2
    CPX.W #$1000 : BCC -                    ; loop until 4096 bytes cleared

    RTL                                     ; long-return — wrapper continues with JSR processText

; ----------------------------------------------------------------------------
; VWFPostRender — called after processText
; Bulk-uploads the entire canvas to VRAM (forced blank, NMI off), clears the
; VWF flag, then carries the displaced bytes (REP #$20 / LDA $0A16) so the
; original code resumes byte-identically.
; ----------------------------------------------------------------------------
org $E08F80

VWFPostRender:
    SEP #$20                                ; 8-bit for flag check
    LDA.W !VWF_FLAG                         ; was this emit a VWF emit?
    CMP.B #$A5                              ; sentinel match?
    BEQ .doUpload                           ; yes → bulk-upload canvas
    JMP .done                               ; no → skip upload, run displaced cleanup

.doUpload:
    SEI                                     ; mask IRQs during DMA setup
    LDA.B #$00 : STA.W $4200                ; disable NMI
    LDA.B #$80 : STA.W $2100                ; forced blank (VRAM writes legal)
    LDA.B #$80 : STA.W $2115                ; VMAIN: word inc on $2119 high write

    REP #$20                                ; 16-bit for VRAM addr
    LDA.W #$6100 : STA.W $2116              ; VMADDL/H = tile $20 word base
    SEP #$20                                ; back to 8-bit for upload loop

    LDX.W #$0000                            ; X = canvas read index
    LDY.W #$0800                            ; Y = 2048 word writes (= 4096 bytes)
.bulkLoop:
    LDA.L !TILE_BUF,X : STA.W $2118 : INX   ; bp0 byte → VMDATAL, advance
    LDA.L !TILE_BUF,X : STA.W $2119 : INX   ; bp1 byte → VMDATAH, advance
    DEY : BNE .bulkLoop                     ; loop full canvas

    LDA.B #$00 : STA.W !VWF_FLAG            ; disarm VWF (handler now passes through)

    LDA.B $58 : STA.W $2100                 ; restore brightness from shadow
    LDA.B #$81 : STA.W $4200                ; re-enable NMI + auto-joypad
    CLI                                     ; unmask IRQs

.done:
    REP #$20                                ; displaced: 16-bit mode
    LDA.W $0A16                             ; displaced: load text-engine state word
    RTL                                     ; long-return — caller's NOPs follow harmlessly

; ----------------------------------------------------------------------------
; VWFClsHook — called from $80:C022 in place of JSL initTilemapAndSync_Long.
; Runs the original clear+sync, then resets canvas + sentinels so the next
; text page renders without leftover pixels merging into new glyphs.
; The VRAM tile range itself does NOT need clearing: initTilemapAndSync_Long
; rewrites the tilemap to point at blank tiles, so any tilemap entry not
; touched by the new page references blanks rather than stale VWF tiles.
; ----------------------------------------------------------------------------
org $E08FC0

VWFClsHook:
    JSL.L $81ECE1                           ; run displaced original (initTilemapAndSync_Long)

    SEP #$20                                ; 8-bit for flag check
    LDA.W !VWF_FLAG                         ; was VWF active for this page?
    CMP.B #$A5                              ; sentinel match?
    REP #$20                                ; back to 16-bit
    BNE .done                               ; no → nothing to reset

    LDX.W #$0000                            ; canvas index
    LDA.W #$0000                            ; zero word
-   STA.L !TILE_BUF,X                       ; clear two canvas bytes
    INX : INX                               ; advance by 2
    CPX.W #$1000 : BCC -                    ; loop full canvas (4096 bytes)

    LDA.W #$FFFF                            ; sentinel value
    STA.W !VWF_ROW                          ; force per-row reinit on next char

.done:
    RTL                                     ; long-return to game caller

; ============================================================================
; Data — placed at $E0:9000, safely past VWFPostRender + VWFClsHook
; ($E09000 + 256 widths + 16-byte zero glyph + ~3840 font bytes < $E0A000)
; ============================================================================
org $E09000

VWFWidthTable:
    incbin "en_data/fonts/font_accented_widths.bin"

VWFFontData:
    db $00,$00,$00,$00,$00,$00,$00,$00      ; reserved zero glyph (top half)
    db $00,$00,$00,$00,$00,$00,$00,$00      ; reserved zero glyph (bottom half)
    incbin "en_data/bin/fonts/font_accented_1bpp.bin"

print "VWF recovery build end: $", pc
