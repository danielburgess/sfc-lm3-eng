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
!VWF_PREV_COL = $7F5D06
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
; Per-emit text-source capture
; Set by VWFCaptureSource hook at fillTextBuffer entry $80:B67C. Holds the
; resolved 24-bit ROM ptr the engine is about to stream into the $0400
; buffer. Load-bearing: VWFPreRender's scene-change detect compares
; (TEXT_LO, TEXT_HI, TEXT_BNK, INVERT) against the LAST_* fingerprint at the
; previous SceneInit; mismatch → JSL VWFRequestSceneInit.
;
;   $7F:5D14  VWF_TEXT_LO   (1 B) — $14 low byte at Phase 1 entry
;   $7F:5D15  VWF_TEXT_HI   (1 B) — $15 high byte
;   $7F:5D16  VWF_TEXT_BNK  (1 B) — $16 bank
; ----------------------------------------------------------------------------
!VWF_TEXT_LO  = $7F5D14
!VWF_TEXT_HI  = $7F5D15
!VWF_TEXT_BNK = $7F5D16

; ----------------------------------------------------------------------------
; Last-scene fingerprint ($7F:5D17..5D1A, 4 bytes)
;
; Captured by VWFRequestSceneInit at the moment of (re-)init. PreRender's
; scene-change detect compares the current (INVERT, TEXT_LO/HI/BNK) tuple
; against this fingerprint; any mismatch triggers a fresh SceneInit.
;
;   $7F:5D17  VWF_LAST_INVERT    (1 B) — polarity at last init
;   $7F:5D18  VWF_LAST_TEXT_LO   (1 B) — text src LO at last init
;   $7F:5D19  VWF_LAST_TEXT_HI   (1 B) — text src HI at last init
;   $7F:5D1A  VWF_LAST_TEXT_BNK  (1 B) — text src BNK at last init
; ----------------------------------------------------------------------------
!VWF_LAST_INVERT   = $7F5D17
!VWF_LAST_TEXT_LO  = $7F5D18
!VWF_LAST_TEXT_HI  = $7F5D19
!VWF_LAST_TEXT_BNK = $7F5D1A

; ----------------------------------------------------------------------------
; Scene-init pending sentinel ($7F:5D1B, 1 byte)
;
; Set to $A5 by VWFRequestSceneInit; consumed by VWFNMI which runs the
; deferred VRAM polarity-wipe DMA in vblank, then clears the sentinel.
; (Renamed from VWF_BLANK_TILE_VALID — same WRAM slot, new semantics.)
; ----------------------------------------------------------------------------
!VWF_SCENE_INIT_PENDING = $7F5D1B

; ----------------------------------------------------------------------------
; Per-emit cursor-blink one-shot ($7F:5D1C, 1 byte) — RELOCATED from $5D1A.
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
; routing to .origPath and immediately clears the flag so subsequent
; in-stream text still renders via VWF. Single-shot semantics keep the gate
; scoped to the cursor write only.
; ----------------------------------------------------------------------------
!VWF_BLINK    = $7F5D1C

; Sentinel counter — VWFCaptureSource increments this once per call.
; Lets us confirm in Mesen IPC ($7F:5D60) that the hook is firing without
; needing a breakpoint. Wraps at 256.
!VWF_DBG_CAPCOUNT = $7F5D60

; ----------------------------------------------------------------------------
; Per-cell tile-id pool ($7F:5DBA..$5DBD and $7F:5E00..$5FFF).
;
; WB-only allocator (BB uses formula `$20 + row*32 + col`). Bumps a single
; cursor (POOL_NEXT) starting at $0021, capped strictly at $0100 to keep
; engine territory ($100+: kanji / chrome / icons) safe. Per-cell allocation
; via CELL_TILE persists across emits inside a scene so typewriter advance
; keeps prior chars' tile_ids stable.
;
; State layout:
;   POOL_NEXT    $7F:5DBA  2 B   — next tile_id to hand out (range $0021..$00FF;
;                                  $0100 = exhausted, .wbBlank fallback)
;   CELL_INIT    $7F:5DBC  1 B   — $A5 = CELL_TILE table valid for this scene.
;                                  Cleared by VWFRequestSceneInit; re-set after
;                                  the table is filled with $FFFF.
;   LAST_COL     $7F:5DBD  1 B   — gap-fill tracker; $FF = no prior col.
;   CELL_TILE    $7F:5E00  512 B — per-cell allocated tile_id (256 cells
;                                  × 16-bit). $FFFF = unallocated.
; ----------------------------------------------------------------------------
!VWF_POOL_NEXT     = $7F5DBA
!VWF_CELL_INIT     = $7F5DBC
!VWF_LAST_COL      = $7F5DBD
!VWF_CELL_TILE     = $7F5E00

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
!VWF_TMP_DREW  = $7F5D32    ; 1 B — $A5 if rasterization touched any pixel this
                            ;       glyph; $00 = blank glyph (WB shortcut to
                            ;       tile $20). Reused from old VWF_BMP_TMP slot.
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

; ============================================================================
; VWF VRAM-owned tile ranges — polarity-dependent.
;
; WB is the constrained mode: tile_ids strictly < $100. Tiles >= $100 are
; engine territory (kanji / chrome / icons / sprites) — wipe must not touch
; them, pool must not allocate them.
;
; BB is the spill-tolerant mode: tile_ids may exceed $100 (formula naturally
; produces $20..$13F for an 8x32 canvas). BB scenes don't collide with engine
; UI in this range, so the spill is safe. The wipe pre-clears only $20..$11F
; (256 tiles); the formula's overflow into $120..$13F is fine because canvas
; DMA writes those tiles directly with rendered pixels.
; ============================================================================
!VWF_TILE_BASE       = $0020              ; first tile in VWF range (both modes)
!VWF_BLANK_TILE_ID   = $0020              ; canonical blank — never rewritten by VWF
                                          ; (used by WB blank-glyph shortcut + gap fill)

; --- WB-specific (bounded pool) ---
!VWF_WB_POOL_FIRST   = $0021              ; first allocatable tile_id (skips $20)
!VWF_WB_TILE_LIMIT   = $0100              ; HARD CAP — pool exhausted at $00FF+1
                                          ; (CMP #!VWF_WB_TILE_LIMIT, BCS = exhausted)
!VWF_WB_WIPE_BYTES   = $0E00              ; 224 tiles × 16 B = 3584 B
                                          ; covers VRAM bytes $C200..$CFFF
                                          ; (= word $6100..$67FF inclusive)

; --- BB-specific (formula, allowed to spill) ---
!VWF_BB_WIPE_BYTES   = $1000              ; 256 tiles × 16 B = 4096 B
                                          ; covers VRAM bytes $C200..$D1FF
                                          ; (= word $6100..$68FF inclusive)
                                          ; formula spill ($120..$13F) overwritten
                                          ; by canvas DMA, no pre-wipe needed there

; --- Common ---
!VWF_VRAM_WORD_BASE  = $6100              ; tile $20 word addr in BG3 char data
                                          ; ($6100 word = $C200 byte = tile_id $20)

; Canvas (the offscreen 1bpp-IL tile RAM that DMAs to VRAM)
; Located at $7F:7000..$7F:7FFF (4 KB; verified zero across $7F:7000..$7F:BFFF
; — no engine code touches it). Layout: 8 rows × 32 cols × 16 B/cell.
;
; 1bpp-IL trick: each 8x16 visible glyph occupies ONE 16 B canvas tile.
; Top tilemap entry uses palette that decodes bp0 plane → top half of glyph.
; Bot tilemap entry uses palette that decodes bp1 plane → bot half of glyph.
; Both tilemap entries point at the SAME tile_id; only the +$0400 palette
; offset differs. Halves canvas/DMA/tile_id footprint vs the prior 2bpp-IL
; pair layout (which used 32 B/cell + 2 tile_ids/cell).
;
; Hardcoded #$7000 literals in NMI single-DMA + per-cell DMA helper match.
!TILE_BUF    = $7F7000                       ; 4 KB buffer = 8 rows x 32 cols x 16 B/col (1bpp-IL)
!CANVAS_SIZE = $1000                         ; 4096 bytes

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
    ASL A                                   ; row << 9 = row*512 byte offset (1bpp-IL stride)
    TAX                                     ; X = canvas byte start of new row

    LDY.W #$0100                            ; 256 iterations × 2 = 512 bytes

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

    ; New row → reset gap-fill last-col tracker so the first char on this
    ; row doesn't gap-fill from the prior row's last col.
    SEP #$20
    LDA.B #$FF
    STA.L !VWF_LAST_COL
    REP #$20
    BRA .updatePrevCol                      ; row-change pen reset already aligned
.sameLine:
    ; Same row — check for engine col-jump (FF nn set new $09FC mid-emit).
    ; If $09FC != VWF_PREV_COL + 1, it's a jump (not a typewriter advance);
    ; re-anchor VWF pen to $09FC * 8 so subsequent rendering lands in the
    ; cell the engine's tilemap entry will reference. Without this, new
    ; segments after FF nn render INTO the prior segment's cells.
    LDA.W $09FC
    SEC : SBC.L !VWF_PREV_COL               ; A = $09FC - prev
    CMP.W #$0001                            ; expected = +1 typewriter
    BEQ .updatePrevCol                      ; matches → no reset
    LDA.W $09FC
    ASL A : ASL A : ASL A                   ; * 8 = pen pixel x
    STA.L !VWF_PX                           ; re-anchor pen
.updatePrevCol:
    LDA.W $09FC
    STA.L !VWF_PREV_COL                     ; track for next-char compare

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

    ; Advance VWF_PX by 8 (= one full cell) so it tracks engine's $09FC
    ; INC. Without this, width-0 chars desync VWF pen from engine col,
    ; which breaks rendering of subsequent chars: their tilemap entries
    ; (indexed by $09FC) and canvas writes (indexed by VWF_PX/8) point
    ; at DIFFERENT cells. Symptom: chars right after a col-jump+width-0
    ; pair render at the wrong col or not at all.
    LDA.L !VWF_PX
    CLC : ADC.W #$0008
    STA.L !VWF_PX
    RTL                                     ; done with this char

.hasWidth:
    ; Reset blank-glyph sentinel. Set to $A5 by every canvas write below;
    ; remains $00 if the rasterizer never touched the canvas this glyph.
    ; Consumed by .doneRows (skip DMA bounds) and .wbTileId (point at $20).
    ; M is 16 here from caller; SEP for 1-byte STZ then back.
    SEP #$20 : LDA.B #$00 : STA.L !VWF_TMP_DREW : REP #$20

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

    ; Buffer base offset = row * 512 + col * 16  (1bpp-IL: 16 B/cell)
    ; This is the FORMULA position used by BB. WB overrides below using
    ; the per-cell pool-allocated tile_id position.
    LDA.L !VWF_TMP_ROW                               ; row
    XBA                                     ; row << 8
    ASL A                                   ; row << 9 (multiply by 512)
    STA.L !VWF_TMP_BASE                               ; partial: row*512
    LDA.L !VWF_TMP_COL                               ; col
    ASL A : ASL A : ASL A : ASL A           ; col << 4 (multiply by 16)
    CLC : ADC.L !VWF_TMP_BASE                         ; add row*512
    STA.L !VWF_TMP_BASE                               ; $0A = canvas tile byte offset (BB final)

    ; --- WB-only: pool allocator + TMP_BASE override ---------------------
    ; WB cells use per-cell pool allocation (skipping tile $20 = canonical
    ; blank, skipping tile $3E = engine cursor, hard cap at $0100). Canvas
    ; position MUST match the allocated tile_id slot ((tile - $20) * 16),
    ; not the row/col formula, because the canvas DMA writes contiguously
    ; and tilemap references the allocated tile_id.
    ;
    ; CELL_TILE[cell] persists across emits within a scene so typewriter
    ; advance reuses prior allocations. SceneInit wipes CELL_TILE on scene
    ; change so allocations don't leak across scenes.
    ;
    ; Pool exhaustion → fall back to .doOrig (engine pass-through path).
    SEP #$20
    LDA.L !VWF_INVERT
    BNE .wbAllocStart                       ; non-zero (WB) → run allocator
    JMP .wbAllocSkip_M8                     ; BB → out-of-range branch via JMP
.wbAllocStart:
    REP #$20

    ; Cell index = (row & 7) * 32 + $09FC (engine col, NOT TMP_COL).
    ; CRITICAL: this MUST match .normalTilemap's cell-index expression.
    ; Using TMP_COL here (pen-derived) diverges from $09FC (engine col)
    ; for variable-width chars whose pen lags or leads the engine col,
    ; causing .normalTilemap to read CELL_TILE[wrong_cell]=$FFFF and
    ; write tile $3FF (= $FFFF tile_id field) to the tilemap.
    LDA.L !VWF_TMP_ROW
    AND.W #$0007
    ASL A : ASL A : ASL A : ASL A : ASL A   ; row * 32
    CLC : ADC.W $09FC                       ; + engine col (matches .normalTilemap)
    AND.W #$00FF                            ; cell 0..255
    ASL A                                   ; cell * 2 (16-bit table offset)
    TAX                                     ; X = byte offset into CELL_TILE

    LDA.L !VWF_CELL_TILE,X
    CMP.W #$FFFF
    BNE .wbHaveTile                         ; reuse stored tile_id

    ; --- Allocate from pool ---
    ; If POOL_NEXT == $3E (cursor), bump to $3F before alloc (persist the bump).
    LDA.L !VWF_POOL_NEXT
    CMP.W #$003E
    BNE .wbSkipCursorBump
    LDA.W #$003F
    STA.L !VWF_POOL_NEXT
.wbSkipCursorBump:
    LDA.L !VWF_POOL_NEXT
    CMP.W #!VWF_WB_TILE_LIMIT               ; >= $0100?
    BCS .wbExhausted
    PHA                                     ; save tile_id (16-bit)
    INC A                                   ; bump cursor
    STA.L !VWF_POOL_NEXT
    PLA                                     ; A = allocated tile_id
    STA.L !VWF_CELL_TILE,X                  ; remember for tilemap write

.wbHaveTile:
    ; A = allocated tile_id. Override TMP_BASE = (tile_id - $20) * 16.
    SEC : SBC.W #!VWF_TILE_BASE             ; A -= $20  (range 1..$DF)
    AND.W #$00FF                            ; safety mask
    ASL A : ASL A : ASL A : ASL A           ; * 16 → canvas byte offset
    STA.L !VWF_TMP_BASE                     ; OVERRIDE: canvas pos = allocated slot

    ; NO per-cell wipe here. Variable-width chars rely on prior char's
    ; spillover landing in adjacent cell's canvas (via OR/AND-NOT bit
    ; accumulation). Wiping erases that spillover → narrow chars lose
    ; their right-side pixels in the next tile.
    ;
    ; PreRender's partial canvas wipe (from pen forward) handles fresh
    ; emits. Static WB scenes get idempotent re-rasterization (same OR/
    ; AND-NOT input → same output). Dynamic content with text changes is
    ; deferred (would need different wipe strategy).
    BRA .wbAllocDone

.wbExhausted:
    REP #$20
    JMP .doOrig                             ; pool exhausted — fallback

.wbAllocSkip_M8:
    REP #$20
.wbAllocDone:

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

    ; Compute write position for this row inside the canvas (1bpp-IL):
    ;   Y in 0..7  → bp0 plane byte at canvas row Y  (top half of glyph)
    ;   Y in 8..15 → bp1 plane byte at canvas row Y-8 (bot half of glyph)
    ; bp0 byte = base + R*2, bp1 byte = base + R*2 + 1 (interleaved within tile).
    REP #$20                                ; 16-bit for offset math
    TYA                                     ; A = row counter
    CMP.W #$0008                            ; row in top half?
    BCS .botRow                             ; row >= 8 → bp1 plane
    ASL A : CLC : ADC.L !VWF_TMP_BASE                 ; bp0: pos = base + Y*2
    BRA .gotPos
.botRow:
    SEC : SBC.W #$0008                      ; relative row 0..7 (becomes canvas row R)
    ASL A : CLC : ADC.L !VWF_TMP_BASE                 ; pos = base + R*2
    CLC : ADC.W #$0001                      ; +1 = bp1 byte (interleaved within tile)
.gotPos:
    STA.L !VWF_TMP_POS                               ; $10 = saved canvas pos for spill calc
    TAX                                     ; X = canvas write index
    SEP #$20                                ; 8-bit for byte writes

    ; Polarity-aware combine: OR for normal (BB), AND-NOT for inverted (WB).
    ; 1bpp-IL: write a SINGLE plane byte per iteration. X selects bp0 (Y<8)
    ; or bp1 (Y>=8) byte within the canvas tile (set in .gotPos above).
    LDA.L !VWF_TMP_SHFT                     ; shifted byte
    BEQ .skipWrite                          ; nothing set → skip write
    LDA.L !VWF_INVERT                       ; polarity flag
    BNE .invRowWrite
    ; BB: OR shifted into selected plane (light pen pixels onto dark canvas)
    LDA.L !VWF_TMP_SHFT
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; plane = plane | shifted
    LDA.B #$A5 : STA.L !VWF_TMP_DREW        ; mark glyph as non-blank (M=8 byte write)
    BRA .skipWrite
.invRowWrite:
    ; WB: AND ~shifted into selected plane (punch black holes through white paper)
    LDA.L !VWF_TMP_SHFT
    EOR.B #$FF
    AND.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; plane = plane & ~shifted
    LDA.B #$A5 : STA.L !VWF_TMP_DREW        ; mark glyph as non-blank
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

    ; Spill destination = saved canvas pos + 16 (next cell, same plane).
    ; Cell stride is 16 bytes in 1bpp-IL canvas, so pos+16 lands in the SAME
    ; plane byte (bp0 if we were writing bp0, bp1 if bp1) of the next cell.
    REP #$20                                ; 16-bit for ADC
    LDA.L !VWF_TMP_POS : CLC : ADC.W #$0010          ; pos + 16 (next cell, same plane)
    CMP.W #!CANVAS_SIZE                     ; bounds: must stay inside 4 KB canvas
    BCS .noSpill                            ; out of bounds → drop the spill
    TAX                                     ; X = canvas spill write index
    SEP #$20                                ; back to 8-bit for byte writes

    ; Polarity-aware spillover combine — same OR vs AND-NOT split as the row write.
    ; Single-byte write only (1bpp-IL: one plane per iteration).
    LDA.L !VWF_INVERT
    BNE .invSpillWrite
    ; BB: OR spill into selected plane
    LDA.L !VWF_TMP_SHFT                     ; spill byte
    ORA.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; plane = plane | spill
    LDA.B #$A5 : STA.L !VWF_TMP_DREW        ; mark glyph as non-blank
    BRA .noSpill2
.invSpillWrite:
    ; WB: AND ~spill into selected plane
    LDA.L !VWF_TMP_SHFT
    EOR.B #$FF
    AND.L !TILE_BUF,X : STA.L !TILE_BUF,X
    LDA.B #$A5 : STA.L !VWF_TMP_DREW        ; mark glyph as non-blank
    BRA .noSpill2                           ; skip the SEP path below (already 8-bit)

.noSpill:
    SEP #$20                                ; ensure 8-bit before falling through
.noSpill2:
    INY                                     ; next pixel row
    CPY.W #$0010                            ; rendered all 16 rows?
    BCS .doneRows                           ; yes → exit the row loop
    JMP .rowLoop                            ; continue with next row

.doneRows:
    ; --- Update DMA_LO/HI bounds for the canvas → VRAM upload --------------
    ; LO = min cell start (TMP_BASE).
    ; HI = polarity-dependent:
    ;   BB → end of canvas row ((row+1) * 512). DMAing the polarity-fill
    ;        tail clears trailing VRAM tile slots from prior emits.
    ;   WB → just this cell's end (TMP_BASE + 16). Pool allocator means
    ;        canvas is sparse; row-end extension would DMA polarity-fill
    ;        over engine cursor (tile $3E) and other unallocated slots.
    REP #$20                                ; M=16 for word compares
    LDA.L !VWF_TMP_BASE                     ; current cell canvas start
    CMP.L !VWF_DMA_LO
    BCS .lo_keep
    STA.L !VWF_DMA_LO                       ; new LO
.lo_keep:
    SEP #$20
    LDA.L !VWF_INVERT
    BEQ .hiFromRow                          ; BB → end-of-row math
    ; WB: HI candidate = TMP_BASE + 16 (just this allocated cell)
    REP #$20
    LDA.L !VWF_TMP_BASE
    CLC : ADC.W #$0010
    BRA .hiCheck
.hiFromRow:
    ; BB: HI candidate = (row+1) * 512 (full canvas row end)
    REP #$20
    LDA.L !VWF_TMP_ROW
    INC A                                   ; M=16: 16-bit INC
    XBA                                     ; (row+1) << 8
    ASL A                                   ; (row+1) * 512
.hiCheck:
    CMP.L !VWF_DMA_HI
    BCC .hi_keep                            ; HI already >= candidate → keep
    STA.L !VWF_DMA_HI                       ; new HI
.hi_keep:
    SEP #$20                                ; M=8 for flag write
    LDA.B #$A5                              ; dirty sentinel
    STA.L !VWF_DIRTY                        ; arm NMI upload
    REP #$20                                ; M=16 for tilemap write below

.skipRender:
    ; --- Tilemap entry write -----------------------------------------------
    ; Compose: tile_id (BB formula or WB pool/blank) + palette/priority.
    ; Top + bot tilemap entries SHARE tile_id; only the +$0400 palette-row
    ; offset distinguishes them (1bpp-IL trick).
    REP #$20                                ; M=16 for word ops
    LDA.L !VWF_SAVX
    TAX                                     ; restore tilemap byte offset

    ; Row-overflow guard: when the game's $09FC has crept past 31, the engine's
    ; INX/INX has already advanced X into the NEXT tilemap row's bytes. Either
    ; write at the overflowed X clobbers neighboring lines' valid tilemap
    ; entries. SKIP all tilemap writes when overflowed.
    LDA.W $09FC
    CMP.W #$0020                            ; 32 = tilemap row width
    BCC .normalTilemap                      ; < 32 → continue tilemap writes
    JMP .penAdvance                         ; >= 32 → skip writes (long jump)

.normalTilemap:
    ; --- Step 1: Universal gap-fill (both polarities) --------------------
    ; Pre-paint cells [LAST_COL+1 .. $09FC-1] with tilemap = blank tile $20
    ; + current palette. Triggered when engine $09FC jumps forward via
    ; position-set FF codes. Stack discipline:
    ;   $01,S = caller_X (just pushed)
    ;   inside gap loop:  $01=K, $02-3=base_X, $04-5=caller_X
    PHX                                     ; save tilemap-byte-offset X (M=16)
    SEP #$20
    LDA.L !VWF_LAST_COL
    CMP.B #$FF
    BEQ .gapFillDone                        ; first write, no prior col
    INC A                                   ; A = LAST_COL + 1 = first gap col
    CMP.W $09FC
    BCS .gapFillDone                        ; LAST+1 >= CUR → contiguous

    ; Gap exists. Compute row's tilemap base_X = caller_X - $09FC*2
    REP #$20
    LDA.B $01,S                             ; peek caller_X (16-bit)
    SEC : SBC.W $09FC
    SBC.W $09FC                             ; A = base_X (col-0 byte offset)
    PHA                                     ; save base_X
    SEP #$20
    LDA.L !VWF_LAST_COL
    INC A                                   ; K = first gap col (M=8)
.gapFillLoop:
    CMP.W $09FC                             ; K vs CUR (M=8 cmp; $09FC low byte sufficient)
    BCS .gapFillCleanup                     ; K >= CUR → done
    PHA                                     ; save K
    REP #$20
    AND.W #$00FF                            ; K (16-bit clean)
    ASL A                                   ; K * 2
    CLC : ADC.B $02,S                       ; + base_X (16-bit peek under saved K)
    TAX                                     ; X = tilemap byte offset for col K
    LDA.W $0A02
    CLC : ADC.W #!VWF_BLANK_TILE_ID         ; tile $20 + palette
    STA.L $7E9000,X                         ; top tilemap entry
    CLC : ADC.W #$0400                      ; +palette-row offset for bot
    STA.L $7E9040,X                         ; bot tilemap entry
    SEP #$20
    PLA                                     ; restore K
    INC A                                   ; K++
    BRA .gapFillLoop
.gapFillCleanup:
    REP #$20
    PLA                                     ; pop base_X (16-bit)
    SEP #$20
.gapFillDone:
    LDA.W $09FC                             ; update LAST_COL (8-bit; $09FC low byte)
    STA.L !VWF_LAST_COL
    REP #$20                                ; M=16 for tile_id math below

    ; --- Step 2: tile_id source — polarity branch -----------------------
    ; BB: formula tile_id = $20 + row*32 + col (matches canvas DMA position)
    ; WB: pool-allocated tile_id from CELL_TILE[cell] (set in .hasWidth)
    ;     Canvas position for WB also matches (TMP_BASE was overridden).
    SEP #$20
    LDA.L !VWF_INVERT
    BEQ .bbTileFormula                      ; BB → formula

    ; --- WB: tile_id = CELL_TILE[cell] (allocated in .hasWidth) ----------
    REP #$20
    LDA.L !VWF_TMP_ROW
    AND.W #$0007
    ASL A : ASL A : ASL A : ASL A : ASL A   ; row * 32
    CLC : ADC.W $09FC                       ; + col
    AND.W #$00FF
    ASL A                                   ; cell * 2
    TAX                                     ; X = byte offset into CELL_TILE
    LDA.L !VWF_CELL_TILE,X                  ; A = allocated tile_id
    BRA .haveTileId

.bbTileFormula:
    ; --- BB: formula (unchanged from working baseline) ------------------
    REP #$20                                ; M=16 for tile_id math
    LDA.L !VWF_TMP_ROW
    AND.W #$0007                            ; sanitize row 0..7
    ASL A : ASL A : ASL A : ASL A : ASL A   ; row * 32
    CLC : ADC.W $09FC                       ; + col
    CLC : ADC.W #!VWF_TILE_BASE             ; + $20 → formula tile_id

.haveTileId:                                ; ENTRY: M=16, A=tile_id
    PLX                                     ; restore tilemap-byte-offset (balances .normalTilemap PHX)

.tilemapWrite:                              ; ENTRY: M=16, A=tile_id, X=tilemap byte off
    PHA                                     ; save tile_id for bot
    CLC : ADC.W $0A02                       ; + palette/priority bits
    STA.L $7E9000,X                         ; write TOP tilemap entry
    PLA                                     ; restore tile_id (NO INC — same tile_id)
    CLC : ADC.W $0A02                       ; + palette/priority bits
    CLC : ADC.W #$0400                      ; + palette-row offset for bottom
    STA.L $7E9040,X                         ; write BOTTOM tilemap entry (same tile)

.tilemapSkip:
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

; ENTRY: M=any (caller is text-engine inside processText wrapper). We start
;        with REP #$20 to set M=16 for displaced setup.
; EXIT:  M=16, X unchanged. RTL.
VWFPreRender:
    REP #$20                                ; 16-bit for displaced setup
    LDA.W #$0400 : STA.B $14                ; displaced: text-buffer ptr low + len init
    STZ.B $16                               ; displaced: zero high byte of buffer ptr

    ; Polarity selector (white-bg scenes set DP $70 hi-bit). Cached for the
    ; per-glyph row + spill writes so they branch without reloading $70.
    SEP #$20                                ; 8-bit for byte read
    LDA.B $70
    AND.B #$80                              ; isolate hi-bit
    STA.L !VWF_INVERT                       ; non-zero = inverted polarity (WB)

    ; Cross-emit cursor-blink leak guard. The OFF frame of a cursor blink
    ; writes $0100 directly inside writeTextCharacter and never reaches our
    ; hook, so a !VWF_BLINK arm from the prior frame's readTextCursorState
    ; can persist into the next emit. Clearing it at PreRender ensures the
    ; first char of this emit takes the .vwf path, not .origPath.
    LDA.B #$00 : STA.L !VWF_BLINK           ; M=8 here (set above)

    ; --- Scene-change detection -----------------------------------------
    ; Compare current (INVERT, TEXT_LO/HI/BNK) tuple against the LAST_*
    ; fingerprint captured at the previous SceneInit. Any mismatch triggers
    ; a fresh SceneInit (canvas wipe, CELL_TILE reset, queue VRAM wipe).
    ; All compares are 8-bit (M=8 already set above).
    LDA.L !VWF_INVERT      : CMP.L !VWF_LAST_INVERT   : BNE .needInit
    LDA.L !VWF_TEXT_LO     : CMP.L !VWF_LAST_TEXT_LO  : BNE .needInit
    LDA.L !VWF_TEXT_HI     : CMP.L !VWF_LAST_TEXT_HI  : BNE .needInit
    LDA.L !VWF_TEXT_BNK    : CMP.L !VWF_LAST_TEXT_BNK : BEQ .sceneSame
.needInit:
    REP #$20                                ; M=16 for JSL boundary
    JSL.L VWFRequestSceneInit               ; canvas wipe, CELL_TILE reset, queue VRAM wipe
    SEP #$20                                ; M=8 for byte stores below
.sceneSame:

    ; --- Pen / row / col anchors for this emit --------------------------
    ; (LAST_COL was reset by SceneInit if it ran; if not, it carries the
    ; prior-emit value which is correct for typewriter advance.)
    REP #$20                                ; M=16 for word ops
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

    ; Initialize VWF_PREV_COL = $09FC - 1 so the first char's
    ; ($09FC == prev + 1) check passes naturally — no spurious col-jump
    ; pen reset on the first text char of the emit.
    LDA.W $09FC
    DEC A
    STA.L !VWF_PREV_COL

    SEP #$20                                ; 8-bit for flag write
    LDA.B #$A5 : STA.L !VWF_FLAG            ; arm VWF (handler now takes VWF path)
    REP #$20                                ; back to 16-bit

    ; Reset dirty-range bounds for this emit. NMI uploads nothing if
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
    ;
    ; offset = row * 512 + col * 16   (matches VWFCharHandler's $0A calc)
    ;   row = ($09FE >> 1) & 7
    ;   col = $09FC
    ; -----------------------------------------------------------------------
    LDA.W $09FE                             ; text row source word
    LSR A : AND.W #$0007                    ; row index 0..7
    XBA                                     ; row << 8
    ASL A                                   ; row << 9 = * 512 (max 7*512=$0E00)
    STA.L !VWF_TMP_BASE                     ; partial: row * 512 (1bpp-IL stride)
    LDA.W $09FC                             ; col index
    AND.W #$001F                            ; clamp 0..31 defensively
    ASL A : ASL A : ASL A : ASL A           ; col * 16 (1bpp-IL cell stride)
    CLC : ADC.L !VWF_TMP_BASE               ; + row * 512
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
    RTL                                     ; long-return — wrapper continues with JSR processText

warnpc $E08FE0                              ; VWFPreRender must end before VWFPostRender

; ----------------------------------------------------------------------------
; VWFPostRender — called after processText
; Bulk-uploads the entire canvas to VRAM (forced blank, NMI off), clears the
; VWF flag, then carries the displaced bytes (REP #$20 / LDA $0A16) so the
; original code resumes byte-identically.
; ----------------------------------------------------------------------------
org $E08FE0

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

; ENTRY: M=16 (caller convention from $80:C022 is M=16 mid-text-stream).
; EXIT:  M=16 (RTL preserves carrier P state).
VWFClsHook:
    JSL.L $81ECE1                           ; run displaced original (initTilemapAndSync_Long)
    JSL.L VWFRequestSceneInit               ; canvas wipe, CELL_TILE reset, queue VRAM wipe
    LDA.W #$FFFF                            ; M=16 — sentinel
    STA.L !VWF_ROW                          ; force per-row reinit on first char post-cls
    RTL                                     ; long-return to game caller

warnpc $E09200                              ; VWFClsHook must end before VWFNMI

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

; ENTRY: native NMI vector entry (after game's $00:D469-D46C bytes that we
;        displaced: PHP / REP #$30 / PHA). We replicate them here, then run
;        deferred work, then JML back to $00:D46D for the rest of NMI.
VWFNMI:
    PHP                                     ; displaced from $D469
    REP #$30                                ; displaced from $D46A — M=16, X=16
    PHA                                     ; displaced from $D46C
    PHX                                     ; preserve interrupted X
    PHY                                     ; preserve interrupted Y

    ; --- Scene-init pending? Run polarity wipe DMA first (vblank-safe) ---
    SEP #$20                                ; M=8 for sentinel byte
    LDA.L !VWF_SCENE_INIT_PENDING
    CMP.B #$A5
    BNE .checkDirty
    JSR.W VWFNMIVramWipe                    ; runs ch7 DMA, clears the sentinel

.checkDirty:
    SEP #$20                                ; (defensive — VWFNMIVramWipe leaves M=8)
    LDA.L !VWF_DIRTY                        ; was canvas modified?
    CMP.B #$A5                              ; sentinel match?
    BEQ +                                   ; A=A5 → continue
    JMP .skipDMA                            ; otherwise → straight to return
+

    ; --- DMA channel 7 setup for canvas → VRAM upload --------------------
    ; A1T7L/H, $2116, $4375 set per-emit below; common regs once here.
    LDA.B #$80                              ; VMAIN: word inc on $2119 high
    STA.W $2115
    LDA.B #$01                              ; DMAP7: mode 1 (2-byte alternating)
    STA.W $4370
    LDA.B #$18                              ; BBAD7: low byte of $2118 (VMDATAL)
    STA.W $4371
    LDA.B #$7F                              ; A1B7 = source bank ($7F = canvas)
    STA.W $4374

    ; --- DMA range check ------------------------------------------------
    REP #$20                                ; M=16 for word compare/math
    LDA.L !VWF_DMA_HI
    CMP.L !VWF_DMA_LO
    BCS .dmaRangeOk1                        ; HI >= LO
    JMP .clearAndExit                       ; HI < LO → invalid (out-of-range)
.dmaRangeOk1:
    BNE .dmaRangeOk2                        ; HI != LO
    JMP .clearAndExit                       ; HI == LO → empty range
.dmaRangeOk2:

    ; --- Polarity selector ----------------------------------------------
    ; BB → single contiguous DMA covering [LO..HI]
    ; WB → split at canvas $1E0..$1EF (= tile $3E, engine cursor) if range
    ;      crosses it. Pool allocator skips tile $3E so canvas slot $1E0
    ;      is unused; DMAing it would overwrite the cursor with whatever
    ;      garbage the slot contains.
    SEP #$20
    LDA.L !VWF_INVERT
    BEQ .doSingleDMA                        ; BB → single DMA

    ; WB: check if range crosses cursor canvas range [$1E0..$1F0)
    REP #$20
    LDA.L !VWF_DMA_LO
    CMP.W #$01F0
    BCS .doSingleDMA                        ; LO >= $1F0 → entirely after cursor
    LDA.L !VWF_DMA_HI
    CMP.W #$01F0
    BCC .doSingleDMA                        ; HI <= $1F0 → entirely before/at cursor
    BEQ .doSingleDMA

    ; --- WB two-chunk DMA: split at $1E0/$1F0 ---------------------------
    ; Chunk 1: [LO..$1E0) → VRAM tiles up to $3D
    LDA.W #$01E0
    SEC : SBC.L !VWF_DMA_LO                 ; chunk 1 byte count
    STA.W $4375                             ; DAS7
    LDA.L !VWF_DMA_LO
    CLC : ADC.W #$7000                      ; source = $7F:7000 + LO
    STA.W $4372                             ; A1T7
    LDA.L !VWF_DMA_LO
    LSR A                                   ; byte → word
    CLC : ADC.W #!VWF_VRAM_WORD_BASE
    STA.W $2116                             ; VMADDR
    SEP #$20
    LDA.B #$80 : STA.W $420B                ; trigger chunk 1

    ; Chunk 2: [$1F0..HI) → VRAM tiles from $3F onward
    REP #$20
    LDA.L !VWF_DMA_HI
    SEC : SBC.W #$01F0                      ; chunk 2 byte count
    STA.W $4375
    LDA.W #$71F0                            ; source = $7F:71F0 (= $7000 + $1F0)
    STA.W $4372
    LDA.W #!VWF_VRAM_WORD_BASE+$00F8        ; dest VRAM word = $6100 + $F8 = $61F8 (= tile $3F)
    STA.W $2116
    SEP #$20
    LDA.B #$80 : STA.W $420B                ; trigger chunk 2
    BRA .clearAndExit

.doSingleDMA:
    REP #$20
    LDA.L !VWF_DMA_HI
    SEC : SBC.L !VWF_DMA_LO                 ; count in bytes
    STA.W $4375                             ; DAS7L/H

    ; Source = $7F:7000 + LO  (canvas)
    LDA.L !VWF_DMA_LO
    CLC : ADC.W #$7000
    STA.W $4372                             ; A1T7L/H

    ; VRAM word addr = !VWF_VRAM_WORD_BASE + LO/2
    LDA.L !VWF_DMA_LO
    LSR A                                   ; byte offset → word offset
    CLC : ADC.W #!VWF_VRAM_WORD_BASE        ; tile $20 word base ($6100)
    STA.W $2116                             ; VMADDL/H
    SEP #$20                                ; M=8 to write trigger

    LDA.B #$80                              ; MDMAEN: trigger channel 7 (bit 7)
    STA.W $420B

.clearAndExit:
    REP #$20                                ; M=16 for word stores
    LDA.W #$FFFF                            ; reset dirty-range bounds
    STA.L !VWF_DMA_LO
    LDA.W #$0000
    STA.L !VWF_DMA_HI

    SEP #$20                                ; M=8 for byte clear
    LDA.B #$00 : STA.L !VWF_DIRTY           ; clear dirty flag

.skipDMA:
    REP #$30                                ; restore M=16, X=16 for downstream NMI
    PLY                                     ; restore interrupted Y
    PLX                                     ; restore interrupted X
    JML $00D46D                             ; resume original NMI handler at PHX

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
; ============================================================================
; VWFRequestSceneInit  ($E0:AA00)
;
; Called from:
;   - VWFClsHook  (after displaced initTilemapAndSync_Long)  — JSL.L
;   - VWFPreRender (when scene-change detected)              — JSL.L
;
; Effects (all immediate, no vblank required):
;   - Captures current (INVERT, TEXT_LO/HI/BNK) into LAST_* fingerprint
;   - Wipes canvas $7F:7000..$7F7FFF with polarity fill ($0000 BB / $FFFF WB)
;   - Resets CELL_TILE[0..255] to $FFFF (unallocated)
;   - Resets POOL_NEXT cursor to $0021 (skips canonical-blank tile $20)
;   - Clears DIRTY/DMA bounds, LAST_COL, sets CELL_INIT
;   - Sets SCENE_INIT_PENDING=$A5 → next NMI vblank does the VRAM wipe DMA
;
; Register-state contract:
;   ENTRY: M/X any (PHP first, PLP last)
;   EXIT:  caller's M/X restored
; ============================================================================
org $E0AA00

VWFRequestSceneInit:
    PHP                                     ; preserve caller's M/X
    REP #$30                                ; M=16, X=16 inside helper

    ; --- Polarity + fingerprint capture (M=8 byte ops) -------------------
    SEP #$20                                ; M=8
    LDA.B $70 : AND.B #$80
    STA.L !VWF_INVERT
    STA.L !VWF_LAST_INVERT                  ; remember polarity at this init

    LDA.L !VWF_TEXT_LO  : STA.L !VWF_LAST_TEXT_LO
    LDA.L !VWF_TEXT_HI  : STA.L !VWF_LAST_TEXT_HI
    LDA.L !VWF_TEXT_BNK : STA.L !VWF_LAST_TEXT_BNK

    ; --- Canvas wipe — polarity-aware fill ($7F:7000..$7FFF, 4 KB) -------
    ; INVERT==0 → BB → fill $0000;  INVERT!=0 → WB → fill $FFFF
    LDA.L !VWF_INVERT
    REP #$20                                ; M=16 for word fill
    BEQ .canvasFillBlack
    LDA.W #$FFFF : BRA .canvasFillReady
.canvasFillBlack:
    LDA.W #$0000
.canvasFillReady:
    LDX.W #$0000
.canvasLoop:
    STA.L !TILE_BUF,X
    INX : INX
    CPX.W #!CANVAS_SIZE                     ; reached 4096?
    BCC .canvasLoop

    ; --- CELL_TILE = $FFFF (unallocated; 256 entries × 2 B = 512 B) ------
    LDX.W #$01FE                            ; last byte offset
    LDA.W #$FFFF
.cellLoop:
    STA.L !VWF_CELL_TILE,X
    DEX : DEX
    BPL .cellLoop

    ; --- Pool cursor (WB only — BB ignores POOL_NEXT) --------------------
    LDA.W #!VWF_WB_POOL_FIRST               ; $0021
    STA.L !VWF_POOL_NEXT

    ; --- DIRTY / DMA bounds reset (M=16 word stores, then M=8 sentinels) -
    LDA.W #$FFFF : STA.L !VWF_DMA_LO
    LDA.W #$0000 : STA.L !VWF_DMA_HI

    SEP #$20                                ; M=8 for byte sentinels
    LDA.B #$00 : STA.L !VWF_DIRTY           ; nothing to upload
    LDA.B #$FF : STA.L !VWF_LAST_COL        ; gap-fill: no prior col
    LDA.B #$A5 : STA.L !VWF_CELL_INIT       ; CELL_TILE valid
    STA.L !VWF_SCENE_INIT_PENDING           ; tell NMI: do VRAM wipe next vblank

    PLP                                     ; restore caller's M/X
    RTL

; ============================================================================
; VWFNMIVramWipe  ($E0:AB00)
;
; Called from VWFNMI when SCENE_INIT_PENDING == $A5. Runs in vblank, so VRAM
; writes are safe.
;
; Strategy: DMA mode 1 (alternating B at $2118/$2119) + FIXED source
; (DMAP bit 3 = 1) lets a single source byte fill the entire range. Source
; address is a 1-byte slot in ROM; DAS = polarity-dependent:
;   BB (INVERT==0) → $1000 byte DAS, source = byte $00 (covers tiles $20..$11F)
;   WB (INVERT!=0) → $0E00 byte DAS, source = byte $FF (covers tiles $20..$FF;
;                    STRICT cap — never touches engine tiles $100+)
;
; Channel 7 is unused by the engine. VMAIN word-inc on $2119 high write
; advances VRAM word per pair.
;
; Register-state contract:
;   ENTRY: M=8, X=16  (NMI prelude already set REP #$30 then SEP #$20)
;   EXIT:  M=8, X=16  (channel 7 reconfig persists harmlessly)
; ============================================================================
org $E0AB00

VWFNMIVramWipe:
    SEP #$20
    LDA.B #$80 : STA.W $2115                ; VMAIN: word-inc on $2119 high write
    LDA.B #$09 : STA.W $4370                ; DMAP7 = mode 1 + FIXED source (bit 3)
    LDA.B #$18 : STA.W $4371                ; BBAD7 = $2118 (VMDATAL)
    LDA.B #bank(VWFVramWipeBytes) : STA.W $4374  ; A1B7 = source bank ($E0)

    ; Source byte addr depends on polarity (BB→$00, WB→$FF).
    ; Set source once; we'll trigger 2 chunks (split at tile $3E to preserve cursor).
    LDA.L !VWF_INVERT
    BEQ .wipeBlackBB
    REP #$20
    LDA.W #VWFVramWipeBytes+1               ; addr of $FF byte (WB)
    BRA .srcSet
.wipeBlackBB:
    REP #$20
    LDA.W #VWFVramWipeBytes                 ; addr of $00 byte (BB)
.srcSet:
    STA.W $4372                             ; A1T7 = fixed source byte addr

    ; --- Chunk 1: tiles $20..$3D (canvas/VRAM bytes 0..$1E0, 480 bytes) ---
    ; Wipes 30 tiles, leaving tile $3E (cursor) untouched.
    LDA.W #$01E0                            ; 480 bytes
    STA.W $4375
    LDA.W #!VWF_VRAM_WORD_BASE              ; $6100 = tile $20 word
    STA.W $2116
    SEP #$20
    LDA.B #$80 : STA.W $420B                ; trigger chunk 1

    ; --- Chunk 2: tiles $3F..end of polarity range (skip tile $3E) -------
    ; BB: $3F..$11F → 225 tiles × 16 = 3600 bytes ($0E10 hex). Total wiped: 480 + 3600 = 4080 = $0FF0.
    ;     ...wait $0E10 + $1E0 = $FF0. Hmm. Let me use easier: original BB wipe was $1000 (256 tiles).
    ;     Chunk 1 = $1E0 (30 tiles). Chunk 2 = $1000 - $1E0 - $10 (subtract tile $3E itself) = $E10.
    ; WB: $3F..$FF → 193 tiles × 16 = 3088 bytes. Original WB wipe was $0E00 (224 tiles).
    ;     Chunk 2 = $0E00 - $1E0 - $10 = $C10 bytes.
    REP #$20
    LDA.L !VWF_INVERT
    BEQ .chunk2_BB
    LDA.W #$0C10                            ; WB chunk 2 byte count
    BRA .chunk2_setDAS
.chunk2_BB:
    LDA.W #$0E10                            ; BB chunk 2 byte count
.chunk2_setDAS:
    STA.W $4375
    LDA.W #!VWF_VRAM_WORD_BASE+$00F8        ; $61F8 = tile $3F word
    STA.W $2116
    SEP #$20
    LDA.B #$80 : STA.W $420B                ; trigger chunk 2

    LDA.B #$00 : STA.L !VWF_SCENE_INIT_PENDING  ; clear pending sentinel
    RTS                                     ; back to NMI body (M=8, X=16)

; ============================================================================
; VWFVramWipeBytes  ($E0:AC00, 2 bytes)
; Source bytes for the polarity wipe. Address +0 = $00 (BB), +1 = $FF (WB).
; ============================================================================
org $E0AC00
VWFVramWipeBytes:
    db $00, $FF

warnpc $E0AC10                              ; sanity bound

print "VWF recovery build end: $", pc
