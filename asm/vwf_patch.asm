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
; VWF state — ALL in $7F:5D00..$7F:5D1F, away from the contended $0A30..$0A3B
; window. Original game uses $0A38 as a 16-bit text-data pointer and $0A3A as
; 16-bit config flags ($0A3A AND #1, AND #8, AND #$10, AND #$100 per the
; disassembly). When VWF wrote to those addresses, the game's event-script
; code read corrupted state and branched to wrong paths, producing visibly
; different stat numbers, palette behavior, etc. Relocating here keeps VWF
; fully isolated from game state. All accesses are long-addressed.
;
;   $7F:5D00  VWF_DIRTY    (1 B)  $A5 = canvas needs vblank upload, $00 = idle
;   $7F:5D02  VWF_DMA_LO   (16-bit) low  bound of dirty range, sentinel $FFFF
;   $7F:5D04  VWF_DMA_HI   (16-bit) high bound (exclusive), sentinel $0000
;   $7F:5D08  VWF_PX       (16-bit) pen X position in absolute pixels
;   $7F:5D0A  VWF_FLAG     (1 B)   $A5 = VWF active in this emit, $00 = idle
;   $7F:5D0C  VWF_SAVX     (16-bit) saved tilemap-byte X for tilemap writes
;   $7F:5D0E  VWF_ROW      (16-bit) copy of $09FE for newline detection
;   $7F:5D10  VWF_CHAR     (16-bit) char latch from Hook 1 PLA (was $0A38)
; ----------------------------------------------------------------------------
!VWF_DIRTY    = $7F5D00
!VWF_DMA_LO   = $7F5D02
!VWF_DMA_HI   = $7F5D04
!VWF_PX       = $7F5D08
!VWF_FLAG     = $7F5D0A
!VWF_SAVX     = $7F5D0C
!VWF_ROW      = $7F5D0E
!VWF_CHAR     = $7F5D10

; Polarity selector — set in PreRender from DP $70 hi-bit. Non-zero = inverted
; (white-bg scenes: menus + event-text). Cached so the per-glyph render path
; branches without reloading $70 every row.
!VWF_INVERT   = $7F5D12

; ----------------------------------------------------------------------------
; Per-emit text-source capture (Phase A of WB-scene gating)
; Set by VWFCaptureSource hook at fillTextBuffer entry $80:B67C. Holds the
; resolved 24-bit ROM ptr the engine is about to stream into the $0400
; buffer, so future gate decisions can key on (BNK, HI, LO).
;
; PHASE A NOTE: these slots are populated but NOT YET CONSUMED by any gate
; logic — Phase A only proves the capture hook runs without regression.
; Phase B will add VWFGateDecision; Phase C will substitute INVERT reads
; with GATE reads at the 5 known sites.
;
;   $7F:5D14  VWF_TEXT_LO  (1 B) — $14 low byte at Phase 1 entry
;   $7F:5D15  VWF_TEXT_HI  (1 B) — $14 high byte ($15)
;   $7F:5D16  VWF_TEXT_BNK (1 B) — $16 (bank)
;   $7F:5D17  VWF_GATE     (1 B) — $A5 = VWF active for this emit, $00 = engine fallback
; ----------------------------------------------------------------------------
!VWF_TEXT_LO  = $7F5D14
!VWF_TEXT_HI  = $7F5D15
!VWF_TEXT_BNK = $7F5D16
!VWF_GATE     = $7F5D17

; ----------------------------------------------------------------------------
; Per-emit VRAM destination override (Phase C of WB-scene gating)
;
; 16-bit VRAM WORD address where canvas cell 0 (= tile $20 under the canvas-
; position formula) should land on this emit. Default is $6100 (BB dialog —
; BG3 char base $6, tile $20 = byte $C200 = word $6100). VWFGateAllowList
; rows can override per scene to retarget VWF DMA away from tile slots that
; the scene's chrome occupies.
;
; Set by VWFGateDecision: cleared to $6100 default at entry, overwritten
; from the matched allow-list row's `dw <VRAM_word_base>` field.
;
; Consumed by NMI single-DMA path and vwfDoDmaForCell helper.
;   $7F:5D18  VWF_VRAM_BASE  (16-bit word)
; ----------------------------------------------------------------------------
!VWF_VRAM_BASE = $7F5D18

; ----------------------------------------------------------------------------
; Per-emit cursor-blink one-shot ($7F:5D1A, 1 byte)
;
; pollInputFlashCursor ($80:C2A9) runs INSIDE processText (via the $FC
; choice/menu handler) and JSR's writeTextCharacter every frame to redraw the
; blinking arrow at $003E. Because VWF_FLAG is still $A5 mid-emit, those
; redraws would otherwise fall into the VWF render path: each blink advances
; VWF_PX by the glyph width and rasterizes a `>` glyph at the new pen
; position, leaving a trail of cursor tiles across the row.
;
; readTextCursorState ($80:C219) is the perfect marker — it is called only
; by pollInputFlashCursor and runs immediately before every cursor write.
; The hook sets BLINK=$A5; CharHandler honors it for the very next char by
; routing to .origPath (the byte-equal replacement of writeTilemapEntry) and
; immediately clears the flag so subsequent in-stream text still renders via
; VWF. Single-shot semantics keep the gate scoped to the cursor write only.
; ----------------------------------------------------------------------------
!VWF_BLINK    = $7F5D1A

; ----------------------------------------------------------------------------
; Per-emit chrome-tile preserve range ($7F:5D1C..5D1F, two 16-bit words).
;
; Some scenes use the same BG char-data window for both VWF text glyphs AND
; chrome border tiles (file information menu uses BG3 char data byte $C000+
; for both). The engine compose `tile = $20 + col*2 + row*64` puts long-text
; canvas-row-3 cells at tiles $100+, where the chrome separator rows place
; their `$3101 $3102 ... $310F` entries. Without selectivity, vwfDoDmaForCell
; overwrites those chrome tile slots whenever EN-length text reaches them.
;
; CHROME_LO and CHROME_HI define an inclusive tile-index range that
; vwfDoDmaForCell must NOT overwrite. The cell occupies tiles
; (top = $20 + 2*cell, bot = top + 1); a cell is skipped if
; `bot >= CHROME_LO AND top <= CHROME_HI`. Sentinel for "no skip" is
; CHROME_LO > CHROME_HI (default $FFFF / $0000 set at gate-decision entry).
;
; Staged glyphs in those skipped cells stay in canvas (not DMAed to VRAM),
; so on screen the chrome tile data the engine pre-loaded survives. Net
; effect: the rightmost few characters of long text lines are clipped
; rather than stomping the box border.
;
;   $7F:5D1C  VWF_CHROME_LO  (16-bit word) — inclusive lower tile bound
;   $7F:5D1E  VWF_CHROME_HI  (16-bit word) — inclusive upper tile bound
; ----------------------------------------------------------------------------
!VWF_CHROME_LO = $7F5D1C
!VWF_CHROME_HI = $7F5D1E

; Sentinel counter — VWFCaptureSource increments this once per call.
; Lets us confirm in Mesen IPC ($7F:5D60) that the hook is firing without
; needing a breakpoint. Wraps at 256.
!VWF_DBG_CAPCOUNT = $7F5D60

; ----------------------------------------------------------------------------
; Per-tile rendered bitmap (32 bytes, 1 bit per canvas cell).
; 8 rows × 32 cols = 256 cells, packed MSB-first within each byte.
; .doneRows sets the bit for every cell VWF actually rendered to.
; NMI's bitmap-walk path uses this to DMA ONLY rendered cells, leaving
; engine-loaded tiles (chrome, borders, icons) intact in the canvas-range
; VRAM. This is what makes VWF rendering safe on WB scenes that share the
; canvas VRAM range with engine font.
;
; Expanded from 4-row (128 cell) to 8-row (256 cell) layout to fix file-info
; menu canvas aliasing. Original 4-row mapping `($09FE>>1) & 3` collided
; whenever the menu had >4 simultaneous text lines: header/file2 both fell
; on canvas row 3, file1/file3 both on row 1, with the second emit of each
; pair stomping the first. 8 rows covers up to 8 distinct lines.
; ----------------------------------------------------------------------------
!VWF_BITMAP   = $7F5D40    ; 32 bytes ($5D40..$5D5F)
!VWF_BMP_TMP  = $7F5D32    ; 1 byte — moved from $5D50 (now inside bitmap range)
!VWF_BMP_CELL = $7F5D34    ; 1 byte — moved from $5D52 (now inside bitmap range)

; --- VWFCharHandler scratch — RELOCATED FROM DP $00..$10 ---
; Earlier builds used direct-page slots $00..$10 as render scratch. The game's
; task-state dispatcher at $01:B7F0..$B807 reads DP $10 to decide whether to
; call vblankDMADispatch ($00:DB69), which is what uploads scene palette +
; sprite tile DMA at scene transitions. Per-char `STA.L !VWF_TMP_POS` from the renderer
; hit DP $10 ~1200x per dialog window, drowning the only writes that ever
; sets $10=$03 — so vblankDMADispatch never fired and dialog/sprite palettes
; (and other DMA-driven scene assets) loaded with whatever was in WRAM
; cold-boot or from a previous scene. Relocating scratch to high WRAM
; eliminates all DP collisions; long-addressing costs ~+1 byte/+2 cycles per
; access (~negligible for the per-char render path).
!VWF_TMP_CHAR  = $7F5D20    ; was DP $00 — clean 16-bit char index (also $02-relative)
!VWF_TMP_W     = $7F5D22    ; was DP $02 — 8-bit glyph width (kept for advance)
!VWF_TMP_ROW   = $7F5D24    ; was DP $04 — canvas row index 0..3
!VWF_TMP_COL   = $7F5D26    ; was DP $06 — tile column index
!VWF_TMP_SHIFT = $7F5D28    ; was DP $08 — sub-pixel shift 0..7
!VWF_TMP_BASE  = $7F5D2A    ; was DP $0A — canvas top-tile byte offset
!VWF_TMP_FBI   = $7F5D2C    ; was DP $0C — font byte index (char*16)
!VWF_TMP_ORIG  = $7F5D2E    ; was DP $0E — original (un-shifted) font byte
!VWF_TMP_SHFT  = $7F5D2F    ; was DP $0F — shifted byte to OR into tile (8-bit)
!VWF_TMP_POS   = $7F5D30    ; was DP $10 — saved canvas write pos for spill calc

; Canvas (the offscreen 2bpp tile RAM that DMAs to VRAM)
; Located at $7F:7000..$7F:8FFF (8 KB hole in WRAM, verified zero across
; entire $7F:7000..$7F:BFFF range — no engine code touches it). Original
; 4 KB layout @ $7F:7000..$7FFF held 4 rows × 32 cols. Doubled to 8 KB to
; fix canvas aliasing on menus with >4 simultaneous text lines (file info
; was the trigger: 5 visible rows collapsed to 4 canvas slots, with later
; emits stomping earlier ones in the shared slot).
;
; Hardcoded #$7000 literals in NMI single-DMA + per-cell DMA helper match.
!TILE_BUF    = $7F7000                       ; 8 KB buffer = 8 rows x 32 cols x 32 B/col
!CANVAS_SIZE = $2000                         ; 8192 bytes

; Saturation guard — when computed tile column >= this value, fall back to
; the original tile path so we never write a tilemap entry pointing at an
; un-rendered slot.
!VWF_MAX_COL = $0020                        ; 32 columns per canvas row

; ============================================================================
; Hook 6 — fillTextBuffer_Phase1 entry  ($80:B67C, 9 bytes overwritten)
;
; PHASE A of WB-scene gating: capture the resolved 24-bit text source pointer
; ($14/$15/$16) into !VWF_TEXT_LO/HI/BNK so future gate logic (Phase B) can
; key on it. Both JSL fillTextBuffer_Phase1 call sites (loadTextFromPtr at
; $81:EE6D and the post-redirect path at $81:EE91) funnel through this entry,
; so capture is universal — covers textMetaLookup-driven dialog/menus AND
; evtCmd10_InlineText event-script [P] text AND sceneTextDispatch redirects.
;
; Original 9 bytes were 3 STZ.W ($0A08, $0A16, $0A18) executed at M=16 from
; the caller's REP #$20. VWFCaptureSource replicates them inline so the
; patched fillTextBuffer body runs bit-identically.
; ============================================================================
org $80B67C
    JSL.L VWFCaptureSource                  ; 4 bytes
    NOP : NOP : NOP : NOP : NOP             ; 5 bytes — pad to 9 (3 displaced STZ.W)

; ============================================================================
; Hook 1 — per-character entry  ($80:C17B, 20 bytes overwritten)
; The displaced game code pulled the char off the stack and wrote its tile.
; We replicate the "pull char + stash" prelude and dispatch into our handler.
; The handler ends in RTL so we balance our JSL.L; the trailing RTS returns
; through the original game caller's JSR.
; ============================================================================
org $80C17B
    PLA                                     ; pop 16-bit char value pushed by caller
    STA.L !VWF_CHAR                             ; stash char in scratch ($0A38 = char latch)
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
; Hook 4 — NMI entry  ($00:D469, 4 bytes overwritten)
; Original: PHP / REP #$30 / PHA  (4 bytes through $D46C)
; JML to VWFNMI which replicates those 3 ops, performs deferred DMA on
; channel 7 (which the game never uses — channels 0,1,2,5 are taken by
; OAM/VRAM/palette uploads), then JMLs back to $00:D46D so the original
; NMI handler resumes at PHX. No forced blank → no flicker.
; ============================================================================
org $00D469
    JML VWFNMI                              ; 4 bytes — exact replacement of PHP/REP/PHA

; ============================================================================
; Hook 5 — line-width check  ($00:BE92, 9 bytes overwritten)
; Original: LDA $09FC / DEC / CMP $09F8 / BCC textStreamLoop
;   (compares (game_col - 1) to char-count limit at $09F8 — wraps when col
;   exceeds the per-line CHARACTER count)
; Replacement: JSL VWFLineEndCheck / BCC textStreamLoop / NOPx3
;   (helper compares VWF_PX to (line-char-limit * 8) = pixel limit, sets
;   carry the same way as the original CMP — caller's BCC works unchanged)
; This converts the engine's char-based wrap into a pixel-based wrap so
; VWF can fully utilize the dialog-box width.
; ============================================================================
org $00BE92
    JSL VWFLineEndCheck                     ; 4 — pen-vs-pixel-limit, sets carry
    db $90, $B7                             ; BCC -73 → $00:BE4F (textStreamLoop)
    NOP : NOP : NOP                         ; pad to 9 (original instr length)

; ============================================================================
; Hook 7 — cursor-blink marker  ($00:C219, 5 bytes overwritten)
; readTextCursorState is the unique entry path used by pollInputFlashCursor
; immediately before every cursor redraw. Hook it to arm !VWF_BLINK so the
; very next CharHandler invocation routes to .origPath, suppressing VWF
; rendering of the blinking arrow. The trampoline replicates the displaced
; REP #$20 / LDX.W $09FC so the rest of readTextCursorState resumes byte-
; identically at $00:C21E (LDA.W $09FE).
; ============================================================================
org $00C219
    JSL.L VWFFlashMark                      ; 4 bytes — arms BLINK + runs displaced setup
    NOP                                     ; 1 byte — pad to 5 (REP + LDX.W)

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
    LDA.L !VWF_FLAG                         ; load VWF active flag (8-bit)
    CMP.B #$A5                              ; sentinel meaning "VWF currently rendering"
    REP #$20                                ; restore 16-bit A/M before any branch
    BEQ .vwf                                ; flag matched → take VWF path

; --- Original tilemap write (pass-through path) -----------------------------
; This is the byte-exact tile write the displaced game code performed.
; All non-VWF traffic flows through here unchanged.
.origPath:
    LDA.L !VWF_CHAR                             ; reload char value (16-bit)
    CLC : ADC.W $0A02                       ; add palette/priority bits from text-engine state
    PHA : STA.L $7E9000,X                   ; push composed word, store as TOP tilemap entry
    PLA : CLC : ADC.W #$0400                ; restore word + add palette-row offset for bottom
    STA.L $7E9040,X                         ; store as BOTTOM tilemap entry (paired tile)
    RTL                                     ; long-return to caller (balances JSL.L from hook)

; --- VWF path ---------------------------------------------------------------
.vwf:
    ; Cursor-blink suppression: pollInputFlashCursor's per-frame writeTextChar
    ; calls happen with VWF_FLAG=$A5 (we're still mid-emit inside processText's
    ; $FC choice handler). Without this gate, each blink would render `>` at
    ; the advancing pen and drag a trail across the row. !VWF_BLINK is armed
    ; by the readTextCursorState hook ($00:C219) immediately before each
    ; cursor write, then cleared here so the next text char still renders.
    SEP #$20                                ; 8-bit for flag byte
    LDA.L !VWF_BLINK                        ; cursor-blink one-shot flag
    CMP.B #$A5
    BNE .vwfNotBlink                        ; not a blink redraw → normal VWF
    LDA.B #$00 : STA.L !VWF_BLINK           ; one-shot: consume the flag
    REP #$20                                ; restore 16-bit before branching
    JMP .origPath                           ; route cursor write through orig tile path
.vwfNotBlink:
    REP #$20                                ; restore 16-bit for the rest of the path

    TXA                                     ; X→A (LDX.L doesn't exist; round-trip via A)
    STA.L !VWF_SAVX                         ; preserve tilemap byte offset for later writes

    ; Newline detection: $09FE is the game's text row id. If it changed
    ; mid-emit (engine FF nn codes can jump $09FE between chars):
    ;   1. Clear the new canvas row to the polarity fill value, since
    ;      PreRender only cleared from its own pen forward — rows the
    ;      emit jumps to LATER may still hold stale data from prior
    ;      sessions and cause unpaired bp0/bp1 (visible as garbage).
    ;   2. Reset VWF_PX so the new row's pen aligns to the engine's col.
    ; Single-row emits (typewriter dialog) never hit this branch — first
    ; char's $09FE matches PreRender's STA $09FE→VWF_ROW init, so no
    ; redundant clear of pre-pen typewriter content.
    REP #$20                                ; ensure 16-bit for word compare
    LDA.W $09FE                             ; current text row id
    CMP.L !VWF_ROW                          ; compare against our saved row
    BEQ .sameLine                           ; same row → keep current pen

    ; --- New canvas row: clear it before render ---------------------------
    PHX                                     ; preserve caller's tilemap-byte X
    PHA                                     ; preserve current $09FE (16-bit)

    LDA.W $09FE
    LSR A : AND.W #$0007                    ; canvas row 0..7
    XBA                                     ; row << 8
    ASL A : ASL A                           ; row << 10 = row*1024 byte offset
    TAX                                     ; X = canvas byte start of new row

    LDY.W #$0200                            ; 512 iterations × 2 = 1024 bytes

    SEP #$20                                ; 8-bit polarity peek
    LDA.L !VWF_INVERT
    REP #$20
    BEQ .rowFillBlack
    LDA.W #$FFFF                            ; WB → fill white
    BRA .rowFillReady
.rowFillBlack:
    LDA.W #$0000                            ; BB → fill black
.rowFillReady:
.rowFillLoop:
    STA.L !TILE_BUF,X
    INX : INX
    DEY
    BNE .rowFillLoop

    PLA                                     ; restore $09FE word
    PLX                                     ; restore caller's tilemap-byte X

    ; Continue with pen reset
    LDA.W $09FC                             ; col index for the new row
    ASL A : ASL A : ASL A                   ; *8 → pixel x
    STA.L !VWF_PX                           ; reset pen
    LDA.W $09FE
    STA.L !VWF_ROW                          ; remember new row for next compare
.sameLine:

    ; Character filtering — restrict VWF to printable font range.
    REP #$20                                ; 16-bit for word compare
    LDA.L !VWF_CHAR                             ; load char value
    CMP.W #$0100 : BCS .doOrig              ; >=$0100 are chrome/icons → pass through
    AND.W #$00FF                            ; mask to byte (clears any stale high bits)
    STA.L !VWF_TMP_CHAR                               ; $00 = clean 16-bit char index
    CMP.W #$00F0 : BCS .doOrig              ; chars $F0..$FF reserved/non-glyph → pass through
    CMP.W #$0020 : BCC .doOrig              ; chars below space → pass through (control range)
    BRA .doRender                           ; survived filters → render as VWF glyph

.doOrig:
    ; Special-char path while VWF active: $1B "!!", $1C "...", and other
    ; chars below $20 / above $EF / icons. These reference base-font tiles
    ; the game preloaded into VRAM (not our VWF canvas). The tile DATA is
    ; correct as-is — the bug is POSITION: game's tilemap col = $09FC*8 px,
    ; but VWF pen is usually further LEFT (chars narrower than 8 px each).
    ;
    ; Fix: override tilemap-write X to point at the current VWF pen tile
    ; col (snap pen up to next 8-px boundary first), then advance VWF_PX
    ; by 8 so subsequent VWF chars resume after the special tile.
    REP #$20                                ; 16-bit for word math
    LDA.L !VWF_PX                           ; current pen pixel x
    CLC : ADC.W #$0007                      ; +7 ...
    AND.W #$FFF8                            ; ...AND $FFF8 = ceil to next 8-px boundary
    STA.L !VWF_PX                           ; store snapped pen
    LSR A : LSR A : LSR A                   ; / 8 → VWF tile col
    SEC : SBC.W $09FC                       ; delta = VWF_col - game_col (signed)
    ASL A                                   ; * 2 (tilemap byte stride)
    CLC : ADC.L !VWF_SAVX                   ; X' = game_X + delta = tilemap byte offset @ VWF col
    TAX                                     ; X register now points at VWF tile col

    LDA.L !VWF_CHAR                             ; reload char value
    AND.W #$00FF                            ; mask to byte (clear any stale high bits)
    CLC : ADC.W $0A02                       ; + palette/priority
    PHA                                     ; save composed top word
    STA.L $7E9000,X                         ; top tilemap entry at VWF col
    PLA                                     ; restore
    CLC : ADC.W #$0400                      ; + palette-row offset for bot
    STA.L $7E9040,X                         ; bot tilemap entry at VWF col

    ; Advance VWF_PX by 8 (special tiles are tile-sized = 8 px)
    LDA.L !VWF_PX
    CLC : ADC.W #$0008
    STA.L !VWF_PX

    RTL                                     ; long-return — done with this special char

.doRender:
    ; Width lookup — TAX uses 16-bit char as table index into width table.
    TAX                                     ; X = char index (full 16-bit)
    SEP #$20                                ; widths are 1 byte each
    LDA.L VWFWidthTable,X                   ; A = pixel width (0..8)
    STA.L !VWF_TMP_W                               ; $02 = width (8-bit), kept for advance step
    REP #$20                                ; back to 16-bit for masked compare
    AND.W #$00FF                            ; isolate width byte
    BNE .hasWidth                           ; width > 0 → render glyph

    ; Width 0 (e.g. space) — don't render, but still emit a blank tilemap
    ; entry so the cursor cell gets a clean BG colour.
    LDA.L !VWF_SAVX                         ; load via A (LDX.L unsupported)
    TAX                         ; restore tilemap byte offset
    LDA.W $0A02                             ; current palette/priority bits
    STA.L $7E9000,X                         ; blank top tilemap entry
    CLC : ADC.W #$0400                      ; add palette-row offset for bottom
    STA.L $7E9040,X                         ; blank bottom tilemap entry
    RTL                                     ; done with this char

.hasWidth:
    ; Row index = ($09FE >> 1) & 7  → 8 row slots support up to 8 text
    ; lines without colliding (file info menu has 4 lines that previously
    ; collapsed to 2 canvas rows under the old &3 mask).
    LDA.W $09FE                             ; text row id
    LSR A : AND.W #$0007                    ; halve, mask to 0..7
    STA.L !VWF_TMP_ROW                      ; canvas row index 0..7

    ; Tile column = VWF_PX >> 3  (each tile is 8 px wide).
    LDA.L !VWF_PX                           ; pen pixel x
    LSR A : LSR A : LSR A                   ; /8 → tile column index
    STA.L !VWF_TMP_COL                               ; $06 = tile col

    ; Saturation guard (recovered lesson). If column would overflow the
    ; canvas, fall back to the original tile path so we never reference
    ; an un-rendered VWF slot from the tilemap.
    CMP.W #!VWF_MAX_COL                     ; col vs canvas width
    BCC .inBounds                           ; in bounds → keep rendering
    JMP .doOrig                             ; out of bounds → original-tile fallback
.inBounds:

    ; Sub-pixel shift = VWF_PX & 7
    LDA.L !VWF_PX                           ; pen pixel x
    AND.W #$0007                            ; isolate 0..7 sub-tile shift
    STA.L !VWF_TMP_SHIFT                               ; $08 = shift, also valid as 16-bit zero-high LDX

    ; Buffer base offset = row * 1024 + col * 32
    LDA.L !VWF_TMP_ROW                               ; row
    XBA                                     ; row << 8
    ASL A : ASL A                           ; row << 10 (multiply by 1024)
    STA.L !VWF_TMP_BASE                               ; partial: row*1024
    LDA.L !VWF_TMP_COL                               ; col
    ASL A : ASL A : ASL A : ASL A : ASL A   ; col << 5 (multiply by 32)
    CLC : ADC.L !VWF_TMP_BASE                         ; add row*1024
    STA.L !VWF_TMP_BASE                               ; $0A = canvas top-tile byte offset

    ; Font glyph offset = char * 16  (16 bytes per glyph: 8 top + 8 bottom)
    LDA.L !VWF_TMP_CHAR                               ; char index
    ASL A : ASL A : ASL A : ASL A           ; *16
    STA.L !VWF_TMP_FBI                               ; $0C = font byte index

    ; --- Render 16 rows: rows 0..7 → top tile, rows 8..15 → bottom tile ---
    LDY.W #$0000                            ; Y = pixel row counter

.rowLoop:
    REP #$20                                ; 16-bit for index math
    TYA : CLC : ADC.L !VWF_TMP_FBI                   ; A = font index + Y
    TAX                                     ; X = font byte address (within VWFFontData)
    SEP #$20                                ; 8-bit to read font byte
    LDA.L VWFFontData,X                     ; A = source font byte (8 horizontal pixels)
    STA.L !VWF_TMP_ORIG                               ; $0E = original (preserved for spill calc)

    ; Load shift count into X without disturbing A. The original `LDX.B $08`
    ; preserved A (the font byte) so the LSR loop below could shift it. After
    ; relocating the scratch out of DP, we must use `LDA.L : TAX` — which
    ; CLOBBERS A. Save A first via the scratch, do the load, then reload A.
    ; The 16-bit-M wrap on the load is also required: in M=8 mode, LDA.L only
    ; updates A's visible low byte and TAX would copy A's stale hidden high
    ; byte into X.high — earlier symptom: shift count came out as $1XXX,
    ; LSR loop ran ~4000 times instead of 0..7 (entire VWF rendering broke).
    REP #$20                                ; 16-bit M so LDA.L reads full word + clears A high
    LDA.L !VWF_TMP_SHIFT                    ; A = shift count (0..7)
    TAX                                     ; X = shift count (high byte clean)
    SEP #$20                                ; back to 8-bit M for byte shift loop
    LDA.L !VWF_TMP_ORIG                     ; reload font byte that TAX/load clobbered
    CPX.W #$0000                            ; X=0 means no shift
    BEQ .noSR                               ; → skip shift loop, store byte as-is
.srLoop:
    LSR A : DEX : BNE .srLoop               ; shift A (font byte) right by X positions
.noSR:
    STA.L !VWF_TMP_SHFT                               ; $0F = shifted byte to OR into left tile

    ; Compute write position for this row inside the canvas
    REP #$20                                ; 16-bit for offset math
    TYA                                     ; A = row counter
    CMP.W #$0008                            ; row in top half?
    BCS .botRow                             ; row >= 8 → bottom tile
    ASL A : CLC : ADC.L !VWF_TMP_BASE                 ; top: pos = base + Y*2
    BRA .gotPos
.botRow:
    SEC : SBC.W #$0008                      ; relative row 0..7 within bottom tile
    ASL A : CLC : ADC.L !VWF_TMP_BASE                 ; pos = base + (Y-8)*2
    CLC : ADC.W #$0010                      ; +16 to skip past top-tile bytes
.gotPos:
    STA.L !VWF_TMP_POS                               ; $10 = saved canvas pos for spill calc
    TAX                                     ; X = canvas write index
    SEP #$20                                ; 8-bit for byte writes

    ; Polarity-aware combine: OR for normal (BB), AND-NOT for inverted (WB).
    ; (BEQ skip works for both modes — shifted=0 means no pen pixels in this
    ;  row regardless of polarity.)
    LDA.L !VWF_TMP_SHFT                     ; shifted byte
    BEQ .skipWrite                          ; nothing set → skip write
    LDA.L !VWF_INVERT                       ; polarity flag
    BNE .invRowWrite
    ; BB: OR shifted into canvas (light pen pixels onto dark canvas)
    LDA.L !VWF_TMP_SHFT
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp0 = bp0 | shifted
    INX                                     ; advance to bp1 byte (interleaved 2bpp)
    LDA.L !VWF_TMP_SHFT
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp1 = bp1 | shifted
    BRA .skipWrite
.invRowWrite:
    ; WB: AND ~shifted into canvas (punch black holes through white paper)
    LDA.L !VWF_TMP_SHFT
    EOR.B #$FF
    AND.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp0 = bp0 & ~shifted
    INX
    LDA.L !VWF_TMP_SHFT
    EOR.B #$FF
    AND.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp1 = bp1 & ~shifted
.skipWrite:

    ; --- Spillover into the next tile column when sub_x > 0 -----------------
    LDA.L !VWF_TMP_SHIFT                               ; shift (low byte read)
    BEQ .noSpill                            ; no shift → no spill
    LDA.L !VWF_TMP_ORIG                               ; original (un-shifted) font byte
    BEQ .noSpill                            ; original is blank → nothing to spill

    ; spill = original << (8 - sub_x)
    SEP #$20                                ; ensure 8-bit math
    LDA.B #$08                              ; constant 8
    SEC : SBC.L !VWF_TMP_SHIFT                         ; A = 8 - shift
    REP #$20                                ; 16-bit for AND/TAX
    AND.W #$00FF                            ; clean high byte
    TAX                                     ; X = left-shift count
    SEP #$20                                ; back to 8-bit
    LDA.L !VWF_TMP_ORIG                               ; original font byte
    CPX.W #$0000 : BEQ .noSL                ; 0 shifts → no shift loop
.slLoop:
    ASL A : DEX : BNE .slLoop               ; shift left X times
.noSL:
    STA.L !VWF_TMP_SHFT                               ; $0F = spill byte
    CMP.B #$00                              ; STA cleared no flags — re-test for zero
    BEQ .noSpill                            ; spill is 0 → nothing to write

    ; Spill destination = saved canvas pos + 32 (next tile column)
    REP #$20                                ; 16-bit for ADC
    LDA.L !VWF_TMP_POS : CLC : ADC.W #$0020          ; pos + 32
    CMP.W #!CANVAS_SIZE                     ; bounds: must stay inside 3 KB canvas
    BCS .noSpill                            ; out of bounds → drop the spill
    TAX                                     ; X = canvas spill write index
    SEP #$20                                ; back to 8-bit for byte writes

    ; Polarity-aware spillover combine — same OR vs AND-NOT split as the row write.
    LDA.L !VWF_INVERT
    BNE .invSpillWrite
    ; BB: OR spill into canvas
    LDA.L !VWF_TMP_SHFT                     ; spill byte
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp0 OR spill
    INX                                     ; advance to bp1
    LDA.L !VWF_TMP_SHFT
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; bp1 OR spill
    BRA .noSpill2
.invSpillWrite:
    ; WB: AND ~spill into canvas
    LDA.L !VWF_TMP_SHFT
    EOR.B #$FF
    AND.L !TILE_BUF,X : STA.L !TILE_BUF,X
    INX
    LDA.L !VWF_TMP_SHFT
    EOR.B #$FF
    AND.L !TILE_BUF,X : STA.L !TILE_BUF,X
    BRA .noSpill2                           ; skip the SEP path below (already 8-bit)

.noSpill:
    SEP #$20                                ; ensure 8-bit before falling through
.noSpill2:
    INY                                     ; next pixel row
    CPY.W #$0010                            ; rendered all 16 rows?
    BCS .doneRows                           ; yes → exit the row loop
    JMP .rowLoop                            ; continue with next row

.doneRows:
    ; --- Track the rendered cell in BOTH the per-tile bitmap (used by the
    ;     NMI bitmap-walk path on WB scenes to preserve engine UI tiles) AND
    ;     in DMA_LO/HI (used by NMI single-DMA path on BB scenes). The strategy
    ;     selector in NMI picks the right path per polarity.
    ; CRITICAL: bitmap math runs in M=16. With M=8 + X=16, TAX transfers 16
    ; bits using the stale "B" byte into X.high — bogus offset.
    REP #$20                                ; M=16 for clean A-high
    LDA.L !VWF_TMP_ROW
    AND.W #$00FF
    ASL A : ASL A : ASL A : ASL A : ASL A   ; row * 32
    CLC : ADC.L !VWF_TMP_COL                ; + col → cell_index 0..127
    AND.W #$00FF
    PHA                                     ; save cell_index
    LSR A : LSR A : LSR A                   ; byte_offset 0..15
    TAX
    PLA
    AND.W #$0007                            ; bit_index 0..7
    TAY
    SEP #$20
    LDA.B #$80
.bitMaskShift:
    DEY
    BMI .bitMaskDone
    LSR A
    BRA .bitMaskShift
.bitMaskDone:
    ORA.L !VWF_BITMAP,X
    STA.L !VWF_BITMAP,X

    ; --- Update DMA_LO/HI (BB single-DMA path uses these) -------------------
    ; HI is extended to the END of the current canvas row, not just this
    ; char's tile end. The bytes between the pen and the row end are ALREADY
    ; ZERO in canvas (PreRender partial-cleared them). DMAing the zero tail
    ; zeros out trailing VRAM tile slots that game tilemap entries (advancing
    ; 1 per char regardless of glyph width) reference past where VWF actually
    ; drew pixels. Without this, those trailing tile slots show leftover
    ; glyphs from prior emits.
    REP #$20                                ; 16-bit for word compares
    LDA.L !VWF_TMP_BASE                     ; current tile-pair start
    CMP.L !VWF_DMA_LO                       ; vs current LO
    BCS .lo_keep                            ; LO already <= current → keep
    STA.L !VWF_DMA_LO                       ; new LO
.lo_keep:
    LDA.L !VWF_TMP_ROW                      ; canvas row index (0..3)
    INC A                                   ; (row+1)
    XBA                                     ; (row+1) << 8
    ASL A : ASL A                           ; (row+1) * 1024 = end-of-row byte
    CMP.L !VWF_DMA_HI                       ; vs current HI
    BCC .hi_keep                            ; HI already >= end-of-row → keep
    STA.L !VWF_DMA_HI                       ; new HI = end of current row
.hi_keep:
    SEP #$20                                ; 8-bit for flag write
    LDA.B #$A5                              ; dirty sentinel
    STA.L !VWF_DIRTY                        ; arm NMI upload
    REP #$20                                ; restore 16-bit for tilemap write below

.skipRender:
    ; --- Tilemap entry write -----------------------------------------------
    ; Compose: top_tile  = $20 + row*64 + $09FC*2
    ;          bot_tile  = top_tile + 1
    ; Then OR palette/priority from $0A02 into both, plus +$0400 for bottom.
    REP #$20                                ; 16-bit for word ops
    LDA.L !VWF_SAVX                         ; load via A (LDX.L unsupported)
    TAX                         ; restore tilemap byte offset

    ; Row-overflow guard: when the game's $09FC has crept past 31, the engine's
    ; INX/INX has already advanced X into the NEXT tilemap row's bytes — that
    ; row holds the BOTTOM tiles of the CURRENT text line (each line uses
    ; rows N+N+1 paired). The +$40 offset for our bot-tile write goes one
    ; row further into the NEXT text line's TOP row. Either write at the
    ; overflowed X clobbers neighboring lines' valid tilemap entries.
    ;
    ; SKIP all tilemap writes when overflowed. Pen still advances per glyph
    ; width below; char's canvas pixels still combine into earlier tile via
    ; the OR-rendering. Visually the char joins the previous tile's contents
    ; instead of scribbling on adjacent lines.
    LDA.W $09FC
    CMP.W #$0020                            ; 32 = tilemap row width
    BCS .penAdvance                         ; >= 32 → skip writes, just advance pen

.normalTilemap:
    LDA.L !VWF_TMP_ROW                               ; canvas row
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

.penAdvance:

    ; --- Advance pen by glyph width ----------------------------------------
    SEP #$20                                ; 8-bit width add
    LDA.L !VWF_TMP_W                               ; glyph width
    REP #$20                                ; 16-bit for ADC
    AND.W #$00FF                            ; mask to byte
    CLC : ADC.L !VWF_PX                     ; pen += width
    STA.L !VWF_PX                           ; store new pen

    ; --- Restore + return ---------------------------------------------------
    REP #$20                                ; 16-bit for X restore
    LDA.L !VWF_SAVX                         ; load via A (LDX.L unsupported)
    TAX                         ; restore X for caller
    RTL                                     ; long-return to balance JSL.L

warnpc $E08F00                              ; VWFCharHandler must end before VWFPreRender

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

    ; Polarity selector (white-bg scenes set DP $70 hi-bit). Cached for the
    ; per-glyph row + spill writes so they branch without reloading $70.
    SEP #$20                                ; 8-bit for byte read
    LDA.B $70                               ; scene-type indicator
    AND.B #$80                              ; isolate hi-bit
    STA.L !VWF_INVERT                       ; non-zero = inverted polarity

    ; Cross-emit cursor-blink leak guard. The OFF frame of a cursor blink
    ; writes $0100 directly inside writeTextCharacter and never reaches our
    ; hook, so a !VWF_BLINK arm from the prior frame's readTextCursorState
    ; can persist into the next emit. Clearing it at PreRender ensures the
    ; first char of this emit takes the .vwf path, not .origPath.
    LDA.B #$00 : STA.L !VWF_BLINK

    ; --- Phase B: gate decision ------------------------------------------
    ; VWFGateDecision sets !VWF_GATE = $A5 (active) or $00 (engine fallback)
    ; based on !VWF_INVERT (default policy) + VWFGateAllowList overrides.
    ; If gate is OFF, arm CharHandler for engine pass-through and skip the
    ; rest of PreRender. The displaced LDA #$0400 / STA $14 / STZ $16 above
    ; must run regardless (Phase 2 reads from $0400 either way).
    REP #$20                                ; back to 16-bit before JSL
    JSL.L VWFGateDecision

    SEP #$20                                ; 8-bit for flag check + write
    LDA.L !VWF_GATE
    CMP.B #$A5
    BEQ .gateOn
    LDA.B #$00 : STA.L !VWF_FLAG            ; FLAG≠$A5 → CharHandler → .origPath
    REP #$20
    RTL                                     ; gate off → done; no canvas setup
.gateOn:
    REP #$20                                ; back to 16-bit for setup below

    LDA.W $09FC                             ; current column
    ASL A : ASL A : ASL A                   ; * 8 → pixel x of column start
    STA.L !VWF_PX                           ; pen = column-aligned pixel x

    ; Initialize VWF_ROW to PreRender's $09FE so the first char doesn't
    ; trigger CharHandler's row-change clear (which would wipe pre-pen
    ; typewriter content). PreRender's partial canvas clear has already
    ; reset the trailing portion of this row + all subsequent canvas-bytes
    ; up to canvas end — so the first row is clean from pen forward.
    ; Subsequent FF nn jumps to other canvas rows trigger row-change clear.
    LDA.W $09FE
    STA.L !VWF_ROW

    SEP #$20                                ; 8-bit for flag write
    LDA.B #$A5 : STA.L !VWF_FLAG            ; arm VWF (handler now takes VWF path)
    REP #$20                                ; back to 16-bit

    ; Reset dirty-range bounds for this emit. NMI will upload nothing if
    ; no char gets rendered between now and next vblank.
    LDA.W #$FFFF
    STA.L !VWF_DMA_LO                       ; sentinel "no range yet"
    LDA.W #$0000
    STA.L !VWF_DMA_HI

    ; -----------------------------------------------------------------------
    ; Partial canvas clear: zero bytes from current pen position to end of
    ; canvas. Tiles BEHIND the pen hold previously-rendered chars in this
    ; page (their tilemap entries are still on screen, so their tile bytes
    ; must persist across the per-frame PreRender→processText→PostRender
    ; cycle that drives typewriter rendering). Tiles AT or AFTER the pen
    ; are about to be (re)written by this emit, so they need a fresh start.
    ; ClsHook does the full-canvas wipe at [cls] page transitions.
    ;
    ; offset = row * 1024 + col * 32   (matches VWFCharHandler's $0A calc)
    ;   row = ($09FE >> 1) & 7
    ;   col = $09FC
    ; -----------------------------------------------------------------------
    LDA.W $09FE                             ; text row source word
    LSR A : AND.W #$0007                    ; row index 0..7
    XBA                                     ; row << 8
    ASL A : ASL A                           ; row << 10 = * 1024 (max 7*1024=$1C00)
    STA.L !VWF_TMP_BASE                     ; partial: row * 1024 (zero-page scratch)
    LDA.W $09FC                             ; col index
    AND.W #$001F                            ; clamp 0..31 defensively
    ASL A : ASL A : ASL A : ASL A : ASL A   ; col * 32
    CLC : ADC.L !VWF_TMP_BASE               ; + row * 1024
    TAX                                     ; X = canvas byte offset to start clearing

    ; Polarity-aware fill: $FFFF for inverted (WB) so AND-NOT render punches
    ; black holes through a white paper; $0000 for normal (BB) so OR-render
    ; lights white pixels on a dark canvas.
    SEP #$20
    LDA.L !VWF_INVERT
    REP #$20
    BEQ .preFillBlack
    LDA.W #$FFFF
    BRA .preFillReady
.preFillBlack:
    LDA.W #$0000
.preFillReady:
-   CPX.W #!CANVAS_SIZE                     ; reached canvas end?
    BCS +                                   ; yes → done
    STA.L !TILE_BUF,X                       ; fill two canvas bytes
    INX : INX                               ; advance by 2
    BRA -                                   ; loop
+
    ; Clear the per-tile rendered bitmap (32 bytes for 8-row canvas). Each
    ; new emit starts with no cells flagged; CharHandler.doneRows sets bits
    ; as it renders.
    LDX.W #$001F
    SEP #$20
    LDA.B #$00
.preBitmapClear:
    STA.L !VWF_BITMAP,X
    DEX
    BPL .preBitmapClear
    REP #$20

    RTL                                     ; long-return — wrapper continues with JSR processText

warnpc $E08FC0                              ; VWFPreRender must end before VWFPostRender

; ----------------------------------------------------------------------------
; VWFPostRender — called after processText
; Bulk-uploads the entire canvas to VRAM (forced blank, NMI off), clears the
; VWF flag, then carries the displaced bytes (REP #$20 / LDA $0A16) so the
; original code resumes byte-identically.
; ----------------------------------------------------------------------------
org $E08FC0

VWFPostRender:
    SEP #$20                                ; 8-bit for flag check
    LDA.L !VWF_FLAG                         ; was this emit a VWF emit?
    CMP.B #$A5                              ; sentinel match?
    BNE .done                               ; no → skip dirty mark

    ; Defer the final canvas upload to next vblank. Per-char renders may
    ; have already set DIRTY, but mark again so an emit ending without
    ; per-char rendering still flushes.
    LDA.B #$A5
    STA.L !VWF_DIRTY                        ; ensure NMI does the upload
    LDA.B #$00 : STA.L !VWF_FLAG            ; disarm VWF (handler passes through)

.done:
    REP #$20                                ; displaced: 16-bit mode
    LDA.W $0A16                             ; displaced: load text-engine state word
    RTL                                     ; long-return — caller's NOPs follow harmlessly

warnpc $E09000                              ; VWFPostRender must end before VWFClsHook

; ----------------------------------------------------------------------------
; VWFClsHook — called from $80:C022 in place of JSL initTilemapAndSync_Long.
; Runs the original clear+sync, then resets canvas + sentinels so the next
; text page renders without leftover pixels merging into new glyphs.
; The VRAM tile range itself does NOT need clearing: initTilemapAndSync_Long
; rewrites the tilemap to point at blank tiles, so any tilemap entry not
; touched by the new page references blanks rather than stale VWF tiles.
; Moved to $E0:9000 (was $E0:8FC0) — PostRender body extends to ~$E0:8FD4,
; old placement caused fall-through into this hook every emit (silent crash).
; ----------------------------------------------------------------------------
org $E09000

VWFClsHook:
    JSL.L $81ECE1                           ; run displaced original (initTilemapAndSync_Long)

    SEP #$20                                ; 8-bit for flag check
    LDA.L !VWF_FLAG                         ; was VWF active for this page?
    CMP.B #$A5                              ; sentinel match?
    REP #$20                                ; back to 16-bit
    BNE .done                               ; no → nothing to reset

    ; --- Wipe canvas (4 KB at !TILE_BUF) — polarity-aware fill ---
    LDX.W #$0000                            ; canvas index
    SEP #$20                                ; 8-bit for byte read
    LDA.B $70                               ; scene-type indicator
    REP #$20                                ; back to 16-bit (preserves N flag)
    BPL .clsFillBlack                       ; $70 hi-bit clear → BB → fill $0000
    LDA.W #$FFFF                            ; WB: fill $FFFF (white paper)
    BRA .clsFillReady
.clsFillBlack:
    LDA.W #$0000                            ; BB: fill $0000 (black canvas)
.clsFillReady:
-   STA.L !TILE_BUF,X                       ; fill two canvas bytes
    INX : INX                               ; advance by 2
    CPX.W #!CANVAS_SIZE : BCC -             ; loop full canvas

    ; Clear the per-tile rendered bitmap on page transition too (32 bytes).
    LDX.W #$001F
    SEP #$20
    LDA.B #$00
.clsBitmapClear:
    STA.L !VWF_BITMAP,X
    DEX
    BPL .clsBitmapClear
    REP #$20

    ; VRAM zero-blast removed: forced-blank + NMI-off for ~4 KB of STZ pairs
    ; (~hundreds of µs) blocked OAM/palette DMA on the affected frame and
    ; the $6100..$6900 word range is not exclusively VWF tiles in event
    ; scenes — it overlapped dialog-box and sprite tile data, producing
    ; "dialog missing + sprite garbage" on event scripts. The canvas wipe
    ; above + initTilemapAndSync_Long's tilemap reset suffice: untouched
    ; tilemap entries reference blanks, and PostRender's DMA rewrites the
    ; tiles the new page actually uses.

    LDA.W #$FFFF                            ; sentinel value
    STA.L !VWF_ROW                          ; force per-row reinit on next char

    ; Reset dirty-range bounds — entire VRAM region was just zero-blasted,
    ; no leftover dirty range from prior page is meaningful.
    LDA.W #$FFFF
    STA.L !VWF_DMA_LO
    LDA.W #$0000
    STA.L !VWF_DMA_HI
    SEP #$20
    LDA.B #$00
    STA.L !VWF_DIRTY                        ; nothing to upload at next NMI
    REP #$20

.done:
    RTL                                     ; long-return to game caller

warnpc $E09200                              ; VWFClsHook (~$120 B w/ VRAM clear) must end before VWFNMI

; ============================================================================
; VWFNMI — runs at $00:D469 NMI entry (replaces PHP/REP#$30/PHA, 4 bytes).
; Replicates the displaced ops, performs deferred DMA of the canvas to
; VRAM via channel 7 if !VWF_DIRTY is set, then JMLs back to $00:D46D so
; the original NMI handler resumes at PHX.
;
; Channel choice: game uses DMA channels 0 (OAM), 1+2 (VRAM), 5 (palette).
; Channel 7 is unused — its config persists across frames harmlessly.
; Vblank is naturally a safe time for VRAM writes — no forced blank → no
; scanline flicker.
;
; $2115/$2116 leftover is harmless: game's NMI body re-writes them at
; $D4F0+ before triggering its own VRAM DMA on channels 1/2.
; ============================================================================
org $E09200

VWFNMI:
    PHP                                     ; displaced from $D469
    REP #$30                                ; displaced from $D46A — M=16, X=16
    PHA                                     ; displaced from $D46C
    PHX                                     ; preserve interrupted X for restoration
    PHY                                     ; preserve interrupted Y

    SEP #$20                                ; 8-bit for flag check
    LDA.L !VWF_DIRTY                        ; was canvas modified?
    CMP.B #$A5                              ; sentinel match?
    BEQ +                                   ; A=A5 → continue
    JMP .skipDMA                            ; otherwise → straight to return
+

    ; --- DMA channel 7 common setup (used by both strategies) ---------------
    ; All channel-7 control regs except A1T7/$2116/$4375 are constant for
    ; both paths, so we set them once before the selector.
    LDA.B #$80                              ; VMAIN: word inc on $2119 high write
    STA.W $2115
    LDA.B #$01                              ; DMAP7: mode 1 (2-byte alternating)
    STA.W $4370
    LDA.B #$18                              ; BBAD7: low byte of $2118 (VMDATAL)
    STA.W $4371
    LDA.B #$7F
    STA.W $4374                             ; A1B7 = source bank ($7F)

    ; --- Strategy selector --------------------------------------------------
    ; BB scenes (INVERT=$00) → single contiguous DMA from DMA_LO..DMA_HI.
    ; WB scenes (INVERT=$80) → bitmap-walk per-cell DMA, leaving engine UI
    ; tiles in the canvas-range VRAM intact.
    LDA.L !VWF_INVERT
    BNE .nmiBitmapWalk

; --- BB single-DMA path -----------------------------------------------------
.nmiSingleDMA:
    ; Validate range: HI must be > LO (otherwise sentinel state)
    REP #$20                                ; 16-bit for compare
    LDA.L !VWF_DMA_HI
    CMP.L !VWF_DMA_LO
    BCC .clearAndExit                       ; HI < LO → invalid, just clear flag
    BEQ .clearAndExit                       ; HI == LO → empty range
    SEC : SBC.L !VWF_DMA_LO                 ; count in bytes
    STA.W $4375                             ; DAS7L/H

    ; Source = $7F:7000 + LO  (canvas relocated)
    LDA.L !VWF_DMA_LO
    CLC : ADC.W #$7000
    STA.W $4372                             ; A1T7L/H

    ; VRAM word addr = !VWF_VRAM_BASE + LO/2
    LDA.L !VWF_DMA_LO
    LSR A                                   ; byte offset → word offset
    CLC : ADC.L !VWF_VRAM_BASE              ; per-emit tile $20 word base
    STA.W $2116                             ; VMADDL/H
    SEP #$20

    LDA.B #$80                              ; MDMAEN: trigger channel 7 (bit 7)
    STA.W $420B
    BRA .clearAndExit

; --- WB bitmap-walk path ----------------------------------------------------
; X/Y are 16-bit at NMI entry (REP #$30). Loop is byte-based on
; !VWF_BMP_CELL and 1-byte LDA.L !VWF_BITMAP,X reads, so we stay M=8.
.nmiBitmapWalk:
    LDX.W #$0000                            ; byte index 0..15
    LDA.B #$00
    STA.L !VWF_BMP_CELL                     ; cell index 0..127

.bmpWalkByte:
    LDA.L !VWF_BITMAP,X
    BEQ .bmpSkipByte                        ; whole byte zero → skip 8 cells
    STA.L !VWF_BMP_TMP                      ; save byte for shift-walk
    LDY.W #$0008                            ; 8 bits per byte
.bmpWalkBit:
    LDA.L !VWF_BMP_TMP                      ; reload byte (ASL.L unsupported on memory)
    ASL A                                   ; shift in register
    STA.L !VWF_BMP_TMP                      ; store back
    BCC .bmpSkipBit
    JSR.W vwfDoDmaForCell                   ; bit set → DMA this cell
.bmpSkipBit:
    LDA.L !VWF_BMP_CELL                     ; cell_index++
    INC A
    STA.L !VWF_BMP_CELL
    DEY
    BNE .bmpWalkBit
    BRA .bmpNextByte

.bmpSkipByte:
    LDA.L !VWF_BMP_CELL                     ; cell_index += 8 (whole byte skipped)
    CLC : ADC.B #$08
    STA.L !VWF_BMP_CELL

.bmpNextByte:
    INX
    CPX.W #$0020                            ; 32 bytes for 8-row bitmap
    BCC .bmpWalkByte
    ; fall into .clearAndExit

.clearAndExit:
    REP #$20
    LDA.W #$FFFF                            ; reset dirty-range bounds
    STA.L !VWF_DMA_LO
    LDA.W #$0000
    STA.L !VWF_DMA_HI

    ; Clear the per-tile rendered bitmap so next emit starts fresh (32 B).
    SEP #$20
    LDX.W #$001F
    LDA.B #$00
.bmpReset:
    STA.L !VWF_BITMAP,X
    DEX
    BPL .bmpReset

    STA.L !VWF_DIRTY                        ; A=0; clear dirty flag

.skipDMA:
    REP #$30                                ; restore M=16, X=16 for downstream NMI flow
    PLY                                     ; restore interrupted Y
    PLX                                     ; restore interrupted X
    JML $00D46D                             ; resume original NMI handler at PHX

; ----------------------------------------------------------------------------
; vwfDoDmaForCell — DMAs one canvas cell to its corresponding VRAM tile pair.
; Entry: !VWF_BMP_CELL = cell index 0..127, X = byte loop counter (16-bit),
;        Y = bit loop counter (16-bit), M=8.
; Exit:  channel 7 DMA fires; A/X/Y preserved on stack, M=8.
; Per cell: source = $7F:7000 + cell*32, dest VRAM byte = $C200 + cell*32
;           (= word $6100 + cell*16), 32 bytes (top tile + bot tile).
; ----------------------------------------------------------------------------
vwfDoDmaForCell:
    PHA : PHX : PHY                         ; preserve loop state

    REP #$20                                ; 16-bit for offset math
    LDA.L !VWF_BMP_CELL                     ; cell index in low byte
    AND.W #$00FF                            ; clean high
    PHA                                     ; save cell index for chrome check

    ; --- VRAM bound skip + chrome-tile preserve filter --------------------
    ; Cell N occupies BG3 char tiles top=($20+2N), bot=top+1. Two skips:
    ;
    ; (1) VRAM bound: BG3 char data ends at byte $E000 (= tile $200). Cells
    ;     whose top tile >= $200 land in BG2 tilemap territory (byte $E000+).
    ;     For 8-row canvas, cells 240..255 (canvas row 7 cols 16..31) hit
    ;     this. Skip them to keep BG2 tilemap intact.
    ;
    ; (2) Chrome preserve: skip if [top, top+1] overlaps
    ;     [VWF_CHROME_LO, VWF_CHROME_HI] from the matched allow-list row.
    ;     Sentinel CHROME_LO=$FFFF, HI=$0000 (LO>HI) disables the check.
    ASL A                                   ; A = cell * 2
    CLC : ADC.W #$0020                      ; A = top_tile = $20 + 2*cell

    CMP.W #$0200                            ; top_tile >= $200 (BG3 end)?
    BCS .skipChrome                         ; yes → skip, would stomp BG2

    ; Chrome overlap test:
    ;   (top + 1) >= CHROME_LO  AND  top <= CHROME_HI
    ; If both true, cell is in the preserve range → skip DMA.
    INC A                                   ; A = top + 1 = bot_tile
    CMP.L !VWF_CHROME_LO                    ; bot_tile vs CHROME_LO
    BCC .doDma_restore                      ; bot_tile < LO → no overlap, DMA
    DEC A                                   ; A = top_tile again
    CMP.L !VWF_CHROME_HI
    BEQ .skipChrome                         ; top_tile == HI → in range, skip
    BCS .doDma_restore                      ; top_tile > HI → no overlap, DMA
.skipChrome:
    PLA                                     ; pop cell index (clean stack)
    SEP #$20                                ; restore M=8 for caller convention
    PLY : PLX : PLA                         ; restore loop state
    RTS                                     ; cell preserved — no $420B trigger
.doDma_restore:
    PLA                                     ; restore cell index
    ASL A : ASL A : ASL A : ASL A : ASL A   ; * 32 = canvas byte offset
    PHA                                     ; save offset for VRAM calc

    CLC : ADC.W #$7000                      ; A1T7 = $7F:7000 + offset
    STA.W $4372

    PLA                                     ; offset back
    LSR A                                   ; offset / 2
    CLC : ADC.L !VWF_VRAM_BASE              ; VMADDR = !VWF_VRAM_BASE + offset/2
    STA.W $2116

    LDA.W #$0020                            ; 32 bytes per DMA (one 8x16 tile pair)
    STA.W $4375

    SEP #$20
    LDA.B #$80                              ; trigger ch7
    STA.W $420B

    PLY : PLX : PLA                         ; restore loop state (M=8 preserved)
    RTS

; ----------------------------------------------------------------------------
; VWFLineEndCheck — called from $00:BE92 hook in place of the engine's
; char-count comparison. Sets carry as if the original CMP ran:
;   carry CLEAR if VWF_PX < (line_char_limit * 8) → caller's BCC continues loop
;   carry SET   otherwise → caller falls through to wrap path
; Caller is in M=16 mode (text engine convention at this hook site).
; ----------------------------------------------------------------------------
VWFLineEndCheck:
    PHA                                     ; reserve stack slot (2 bytes, M=16)
    LDA.W $09F8                             ; line-width limit IN CHARACTERS
    ASL A : ASL A : ASL A                   ; * 8 → pixel limit
    STA $01,S                               ; overwrite our PHA'd word with pixel limit
    LDA.L !VWF_PX                           ; current VWF pen pixel x
    CMP $01,S                               ; compare pen vs pixel limit
    PLA                                     ; pop scratch (CMP-set carry survives PLA)
    RTL                                     ; return — caller's BCC reads carry

; ----------------------------------------------------------------------------
; VWFFlashMark — runs at readTextCursorState entry (Hook 7, $00:C219).
; readTextCursorState is reached only via pollInputFlashCursor's two call
; sites (loop top and post-input clear), so every invocation is followed by
; a writeTextCharacter for the cursor cell. Arming !VWF_BLINK here flips
; CharHandler's .vwf path into .origPath for that single next char. The
; trampoline replicates the displaced REP #$20 / LDX.W $09FC so the rest of
; readTextCursorState resumes at $C21E byte-identically.
;
; Caller convention at $00:C219: M=8 from the JSR's caller (no guarantee),
; so we explicitly SEP/REP around the byte write and finish in M=16 to
; match the displaced REP #$20.
; ----------------------------------------------------------------------------
VWFFlashMark:
    SEP #$20                                ; 8-bit for flag byte
    LDA.B #$A5
    STA.L !VWF_BLINK                        ; one-shot: cursor write incoming
    REP #$20                                ; displaced: REP #$20 (M=16)
    LDX.W $09FC                             ; displaced: LDX.W $09FC
    RTL

warnpc $E09400                              ; VWFNMI + helpers must end before data table

; ============================================================================
; Data — placed at $E0:9400, safely past VWFNMI
; ($E09400 + 256 widths + 16-byte zero glyph + ~3840 font bytes ≈ $E0:A411)
; ============================================================================
org $E09400

VWFWidthTable:
    incbin "en_data/fonts/font_accented_widths.bin"

VWFFontData:
    db $00,$00,$00,$00,$00,$00,$00,$00      ; reserved zero glyph (top half)
    db $00,$00,$00,$00,$00,$00,$00,$00      ; reserved zero glyph (bottom half)
    incbin "en_data/bin/fonts/font_accented_1bpp.bin"

; ============================================================================
; Phase A capture helper — placed at $E0:A800 to clear the font-data extent.
; ============================================================================
org $E0A800

; ----------------------------------------------------------------------------
; VWFCaptureSource — runs at fillTextBuffer_Phase1 entry (Hook 6, $80:B67C).
;
; Captures the resolved 24-bit text source pointer ($14/$15/$16) into VWF
; state slots, replicates the 3 displaced STZ.W instructions inline, and
; returns. M-state is preserved across the helper via PHP/PLP so the
; patched fillTextBuffer body sees exactly the M state it would have seen
; without the hook.
;
; Caller convention at $80:B67C is M=16 (set by REP #$20 in loadTextFromPtr
; just before the JSL).
;
; Phase A: the captured slots are ONLY read by debug tooling. No render
; code consults them yet, so the only observable effect of this helper is
; the sentinel counter increment at !VWF_DBG_CAPCOUNT.
; ----------------------------------------------------------------------------
VWFCaptureSource:
    PHP                                     ; preserve caller's M/X
    SEP #$20                                ; M=8 for byte ops

    ; Capture pointer (3 byte-sized stores keep the read width unambiguous).
    LDA.B $14 : STA.L !VWF_TEXT_LO
    LDA.B $15 : STA.L !VWF_TEXT_HI
    LDA.B $16 : STA.L !VWF_TEXT_BNK

    ; Sentinel — increment counter so live debugging can confirm the hook
    ; fires. Wraps at 256; any non-zero value after a text emit means we
    ; ran. INC has no long-addressing form, so do it through A (M=8).
    LDA.L !VWF_DBG_CAPCOUNT
    INC A
    STA.L !VWF_DBG_CAPCOUNT

    REP #$20                                ; M=16 for the displaced STZ.W
    STZ.W $0A08                             ; displaced from $80:B67C+0
    STZ.W $0A16                             ; displaced from $80:B67C+3
    STZ.W $0A18                             ; displaced from $80:B67C+6

    PLP                                     ; restore caller's M/X
    RTL

; ----------------------------------------------------------------------------
; VWFGateDecision — central policy for "should VWF render this emit?"
;
; Default policy: gate = NOT INVERT
;   - BB scenes (INVERT=0) → gate=$A5 (VWF active)
;   - WB scenes (INVERT=1) → gate=$00 (engine fallback)
; This generalizes the previous hand-disable-VWF-on-WB-screens behavior.
;
; Override: VWFGateAllowList rows of (bank, addr_high) flip the gate ON for
; matching captured text sources, so individual WB scenes can opt INTO VWF.
;
; Phase B: empty allow-list (single $FF terminator). Once the data structure
; is verified working, add rows in Phase C as scenes are tuned.
;
; Sets !VWF_GATE = $A5 (active) or $00 (fallback). M/X preserved via PHP/PLP.
; Caller convention: M=16 from VWFPreRender's REP #$20.
; ----------------------------------------------------------------------------
VWFGateDecision:
    PHP
    REP #$30                                ; M=16, X=16 inside helper

    ; Default VRAM word base = $6100 (BB dialog target). Allow-list match
    ; can override on a per-source basis. Always reset here so a stale value
    ; from a prior emit can't leak into a later default-path emit.
    LDA.W #$6100
    STA.L !VWF_VRAM_BASE

    ; Default chrome preserve range = "no skip" sentinel (LO > HI).
    ; Only allow-list rows with explicit chrome bounds populate these.
    LDA.W #$FFFF
    STA.L !VWF_CHROME_LO
    LDA.W #$0000
    STA.L !VWF_CHROME_HI

    SEP #$20                                ; M=8 for byte ops

    ; Default-derive gate from polarity
    LDA.L !VWF_INVERT
    BEQ .defaultOn                          ; INVERT=0 (BB) → gate on
    LDA.B #$00 : BRA .storeAndScan          ; INVERT=1 (WB) → gate off (default)
.defaultOn:
    LDA.B #$A5
.storeAndScan:
    STA.L !VWF_GATE

    ; --- Allow-list scan -------------------------------------------------
    ; Table layout:
    ;   db <count>                          ; 1 byte: number of rows
    ;   per row: db <LO>, <HI>, <BNK>       ; 3 bytes — text source pointer
    ;            dw <VRAM_word_base>        ; 2 bytes — canvas DMA dest override
    ;            dw <chrome_lo>             ; 2 bytes — chrome preserve range LO
    ;            dw <chrome_hi>             ; 2 bytes — chrome preserve range HI
    ; → 9 bytes per row total. (chrome_lo>chrome_hi disables the skip.)
    ;
    ; Match: all three (LO, HI, BNK) bytes must equal captured ($14, $15, $16).
    ; On match: gate flips ON, VRAM_BASE/CHROME_LO/CHROME_HI overwritten.
    LDA.L VWFGateAllowList                  ; A.low = row count (M=8)
    REP #$20                                ; widen for clean Y init
    AND.W #$00FF
    BEQ .done                               ; zero rows → use defaults
    TAY                                     ; Y = loop counter (16-bit)
    SEP #$20                                ; back to M=8

    LDX.W #$0001                            ; X = byte offset, skip count byte
.scan:
    LDA.L VWFGateAllowList,X
    CMP.L !VWF_TEXT_LO                      ; LO match?
    BNE .next
    LDA.L VWFGateAllowList+1,X
    CMP.L !VWF_TEXT_HI                      ; HI match?
    BNE .next
    LDA.L VWFGateAllowList+2,X
    CMP.L !VWF_TEXT_BNK                     ; BNK match?
    BNE .next

    ; Full match — flip gate ON and load the row's overrides
    LDA.B #$A5 : STA.L !VWF_GATE
    REP #$20                                ; M=16 for word reads
    LDA.L VWFGateAllowList+3,X              ; row +3: dw VRAM_word_base
    STA.L !VWF_VRAM_BASE
    LDA.L VWFGateAllowList+5,X              ; row +5: dw chrome_lo
    STA.L !VWF_CHROME_LO
    LDA.L VWFGateAllowList+7,X              ; row +7: dw chrome_hi
    STA.L !VWF_CHROME_HI
    SEP #$20
    BRA .done
.next:
    REP #$20                                ; M=16 so ADC works on full word
    TXA : CLC : ADC.W #$0009                ; advance one 9-byte row
    TAX
    SEP #$20
    DEY                                     ; counter--
    BNE .scan
.done:
    PLP
    RTL

; ----------------------------------------------------------------------------
; VWFGateAllowList — opt-in table for sources we WANT VWF to run on.
;
; Layout:
;   db <count>                              ; first byte: number of rows
;   ; per row (5 bytes):
;   db <LO>, <HI>, <BNK>                    ; capture-order text source ptr
;   dw <VRAM_word_base>                     ; canvas DMA dest override
;       ;                                   ;   = WORD addr where tile $20 lands
;       ;                                   ;   for the BG layer rendering this text
;
; To add a row:
;   1. Load the scene in Mesen so VWFCaptureSource has captured the source
;      ptr; read $7F:5D14..5D16 → (LO, HI, BNK).
;   2. Identify a free VRAM tile range on that scene at the BG char base
;      that displays the text. VRAM_word_base = WORD address of tile $20
;      in that BG (= char_base * $1000 + $0100).
;   3. Append the 5-byte row, increment the count byte.
;   4. ./build.sh --no-cache (section cache must be busted).
;
; VRAM_word_base = $6100 is the BB default (BG3 char base $6, tile $20 at
; byte $C200 = word $6100). Use this for any BB row.
; ----------------------------------------------------------------------------
VWFGateAllowList:
    db 1                                    ; row count
    ; row 0: $02:DF72 — file information save-data text
    ;        File info BG3 runs with charBase = WORD $6000 (= BYTE $C000).
    ;        VRAM word base $6100 = BYTE $C200 = tile $20 of BG3 char data.
    ;        Chrome separators on this scene reuse BG3 tiles $101..$10F
    ;        (entries like $3101, $3102, $310F in the F800 tilemap). Without
    ;        the chrome preserve range, EN-length text reaches canvas row 3
    ;        col 16+ and stomps those tile slots. Range $0101..$010F skips
    ;        cells 112..119 (= canvas row 3 cols 16..23) so the box border
    ;        and column separator survive at the cost of clipping the
    ;        rightmost glyphs of long save-slot lines.
    db $72, $DF, $02 : dw $6100 : dw $0101, $010F

print "VWF recovery build end: $", pc
