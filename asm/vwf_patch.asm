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
; Per-cell tile-id pool ($7F:5DA0..$7F:5DBC and $7F:5E00..$7F:5FFF).
;
; WB-only mechanism. The legacy "TILE_BASES[row] + col*2" formula reserved
; 64 contiguous tile_ids per row, regardless of how many cells actually
; rendered glyphs. Real-world scenes (file-info menu) have only ~16-22
; rendered chars per row; the other ~40 reserved slots are wasted, and
; finding 64 contiguous BG2-safe tile_ids is impossible because BG2's
; tilemap fragments BG3's free space into 4-12 tile gaps.
;
; Per-cell pool fixes both: each rendered char allocates exactly ONE
; tile_id from a flat pool of safe ranges (1bpp-IL: top + bot tilemap
; entries share the tile_id via the +$0400 palette-row offset trick).
; Unrendered cells consume nothing. The same fragmented free space that's
; "useless" under per-row reservation is plenty under per-cell allocation.
;
; State layout:
;   POOL_RANGES  $7F:5DA0  24 B  — copy of matched row's 8 × (dw start,
;                                  db count) pool ranges. start=$FFFF
;                                  marks end of valid ranges.
;   POOL_RNG_OFF $7F:5DB8  1 B   — current byte offset within POOL_RANGES
;                                  (0, 3, 6, ..., 21 — 8 ranges × 3 B).
;   POOL_REMAIN  $7F:5DB9  1 B   — tile_ids remaining in current range.
;                                  When < 2, allocator advances to next.
;   POOL_NEXT    $7F:5DBA  2 B   — next tile_id to hand out.
;                                  Increments by 1 each allocation (1bpp-IL).
;   CELL_INIT    $7F:5DBC  1 B   — $A5 = CELL_TILE table valid for this
;                                  page. Cleared at [cls] (ClsHook); first
;                                  PreRender after [cls] re-inits.
;   CELL_TILE    $7F:5E00  512 B — per-cell allocated tile_id (256 cells
;                                  × 16-bit). $FFFF = unallocated. Persists
;                                  across emits within a page so typewriter
;                                  advance reuses prior cells' tile_ids and
;                                  only allocates for new cells revealed by
;                                  the pen advance. (1bpp-IL: 1 tile_id/cell)
;
; BB scenes never read this state — `.normalTilemap` branches on
; !VWF_INVERT and uses the legacy hardcoded formula for BB. Single-DMA
; path also bypasses CELL_TILE.
; ----------------------------------------------------------------------------
!VWF_POOL_RANGES   = $7F5DA0
!VWF_POOL_RNG_OFF  = $7F5DB8
!VWF_POOL_REMAIN   = $7F5DB9
!VWF_POOL_NEXT     = $7F5DBA
!VWF_CELL_INIT     = $7F5DBC
!VWF_CELL_TILE     = $7F5E00

; ----------------------------------------------------------------------------
; Last-col tracker for between-VWF-writes gap fill ($7F:5DBD, 1 byte sentinel).
;
; .tilemapWB tracks the engine's last-written column ($09FC) per emit. When
; the engine's position-set FF code jumps $09FC forward, the next char's col
; can be > LAST_COL+1, leaving an in-row gap of cells the engine never
; streamed through. Those cells retain whatever tilemap entry the chrome
; init wrote — usually engine-font tile_ids that look like garbage.
;
; On gap detection, .tilemapWB pre-paints those cells with tile $20 (= VRAM
; word $6100, the engine's blank tile) using current $0A02 palette/priority.
;
; Sentinel: $FF = no prior col (first write or post-reset). Reset by
; PreRender (per-emit), ClsHook (per-page), and CharHandler row-change.
; ----------------------------------------------------------------------------
!VWF_LAST_COL      = $7F5DBD

; ----------------------------------------------------------------------------
; Global blank-tile slot ($7F:5D1B, 1 byte sentinel).
;
; Reserve VRAM tile $200 as a polarity-filled "blank" tile shared by every
; VWF-active canvas row. Trailing cells past rendered text on each row
; have their tilemap entries pointed at tile $200 instead of allocating a
; per-row formula tile slot for them — that's the blank-tile-reuse savings.
;
; Sentinel: $A5 means tile $200 in VRAM has been populated with $FFFF×32
; (polarity for WB). Cleared at scene transition (VWFClsHook) and at boot.
; CharHandler row-fill calls VWFInitBlankTile when it first paints a blank
; row in the new scene.
; ----------------------------------------------------------------------------
!VWF_BLANK_TILE_VALID = $7F5D1B
!VWF_BLANK_TILE_ID    = $0200            ; constant — tile slot in BG3 char data

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
    LDA.L !VWF_TMP_ROW                               ; row
    XBA                                     ; row << 8
    ASL A                                   ; row << 9 (multiply by 512)
    STA.L !VWF_TMP_BASE                               ; partial: row*512
    LDA.L !VWF_TMP_COL                               ; col
    ASL A : ASL A : ASL A : ASL A           ; col << 4 (multiply by 16)
    CLC : ADC.L !VWF_TMP_BASE                         ; add row*512
    STA.L !VWF_TMP_BASE                               ; $0A = canvas tile byte offset

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
    BRA .skipWrite
.invRowWrite:
    ; WB: AND ~shifted into selected plane (punch black holes through white paper)
    LDA.L !VWF_TMP_SHFT
    EOR.B #$FF
    AND.L !TILE_BUF,X : STA.L !TILE_BUF,X   ; plane = plane & ~shifted
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
    BRA .noSpill2
.invSpillWrite:
    ; WB: AND ~spill into selected plane
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
    LDA.L !VWF_TMP_ROW                      ; canvas row index (0..7)
    INC A                                   ; (row+1)
    XBA                                     ; (row+1) << 8
    ASL A                                   ; (row+1) * 512 = end-of-row byte (1bpp-IL)
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
    BCC .normalTilemap                      ; < 32 → continue tilemap writes
    JMP .penAdvance                         ; >= 32 → skip writes (long jump)

.normalTilemap:
    ; BB vs WB tile_id formula split (1bpp-IL, 1 tile_id per cell):
    ;   BB (INVERT=$00): hardcoded $20 + row*32 + col. The single-DMA
    ;     path blasts the whole canvas and BB scenes don't have engine
    ;     UI font in the canvas tile range, so this works.
    ;   WB (INVERT≠$00): per-cell pool allocation. cell = row*32 + col;
    ;     CELL_TILE[cell] holds the allocated tile_id, or $FFFF if not
    ;     yet allocated. On first encounter, vwfAllocOne hands out the
    ;     next tile_id from the scene's BG3-safe pool (POOL_RANGES);
    ;     subsequent emits reuse the stored allocation so typewriter
    ;     advance keeps prior chars stable on screen.
    SEP #$20
    LDA.L !VWF_INVERT
    REP #$20
    BNE .tilemapWB                          ; non-zero → WB, use per-cell pool

    ; --- BB 1bpp-IL: tile_id = $20 + row*32 + col --------------------------
    ; One tile_id per cell (top + bot tilemap entries share it via palette
    ; trick), so row stride is 32 (was 64) and col is 1× (was col*2).
    LDA.L !VWF_TMP_ROW                              ; canvas row
    ASL A : ASL A : ASL A : ASL A : ASL A   ; row * 32
    CLC : ADC.W $09FC                       ; + col
    CLC : ADC.W #$0020                      ; + base tile $20
    JMP .tilemapWrite

.tilemapWB:
    ; --- WB per-cell pool: tile_id = CELL_TILE[row*32+col] -----------------
    PHX                                     ; save tilemap-byte-offset X

    ; --- Gap fill: blank cells between LAST_COL+1 and $09FC-1 ---
    ; When engine's $09FC jumps forward (position-set FF code), pre-paint
    ; cells in the gap with tile $20 (engine blank @ VRAM $6100.w) using
    ; current $0A02 palette/priority. Stack discipline: $01,S = caller_X
    ; (just pushed). Push base_X (16-bit) and K (8-bit) inside the loop;
    ; cleanup pops both before .gapFillDone.
    SEP #$20
    LDA.L !VWF_LAST_COL
    CMP.B #$FF
    BEQ .gapFillDone                        ; first write, no prior col
    INC A                                   ; A = LAST_COL + 1 = first gap col
    CMP.W $09FC                             ; vs current col
    BCS .gapFillDone                        ; LAST+1 >= CUR → contiguous

    ; Gap exists. Compute row's tilemap base X = caller_X - $09FC*2
    REP #$20
    LDA.B $01,S                             ; peek caller_X
    SEC : SBC.W $09FC
    SBC.W $09FC                             ; A = base X (col-0 byte offset)
    PHA                                     ; save base_X
                                            ; stack: $01-2=base_X, $03-4=caller_X
    SEP #$20
    LDA.L !VWF_LAST_COL
    INC A                                   ; K = first gap col
.gapFillLoop:
    CMP.W $09FC                             ; K vs CUR
    BCS .gapFillCleanup                     ; K >= CUR → done

    PHA                                     ; save K (1 byte)
                                            ; stack: $01=K, $02-3=base_X, $04-5=caller_X
    REP #$20
    AND.W #$00FF                            ; K (16-bit clean)
    ASL A                                   ; K * 2
    CLC : ADC.B $02,S                       ; + base_X (16-bit peek)
    TAX                                     ; X = tilemap byte offset for col K

    LDA.W $0A02
    CLC : ADC.W #$0020                      ; tile_id $20 + palette/priority
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
    LDA.W $09FC                             ; update LAST_COL = current col
    STA.L !VWF_LAST_COL
    REP #$20

    LDA.L !VWF_TMP_ROW
    AND.W #$0007                            ; sanitize row 0..7
    ASL A : ASL A : ASL A : ASL A : ASL A   ; row * 32
    CLC : ADC.W $09FC                       ; + col
    AND.W #$00FF                            ; cell index 0..255
    ASL A                                   ; cell * 2 (16-bit table offset)
    TAX                                     ; X = byte offset into CELL_TILE
    LDA.L !VWF_CELL_TILE,X                  ; existing tile_id, or $FFFF
    CMP.W #$FFFF
    BNE .haveCellTile                       ; already allocated → reuse

    ; First encounter for this cell: allocate ONE tile_id from the pool.
    PHX                                     ; save CELL_TILE byte offset
    JSR.W vwfAllocOne                       ; A = tile_id, $FFFF if exhausted
    PLX                                     ; restore CELL_TILE byte offset
    CMP.W #$FFFF
    BEQ .pulXSkip                           ; pool exhausted → skip tilemap write
    STA.L !VWF_CELL_TILE,X                  ; remember allocation for next emit
.haveCellTile:
    PLX                                     ; restore tilemap-byte-offset X
    BRA .tilemapWrite                       ; A holds top tile_id
.pulXSkip:
    PLX                                     ; balance the early PHX
    BRA .tilemapSkip

.tilemapWrite:
    ; 1bpp-IL: top + bot tilemap entries SHARE the tile_id; only the
    ; +$0400 palette-row offset distinguishes them. Top palette decodes
    ; bp0 plane (top half pixels); bot palette decodes bp1 plane (bot
    ; half pixels). Same source tile, two visible halves.
    PHA                                     ; save tile_id for bot
    CLC : ADC.W $0A02                       ; OR palette/priority bits
    STA.L $7E9000,X                         ; write TOP tilemap entry
    PLA                                     ; restore tile_id (NO INC — same tile_id)
    CLC : ADC.W $0A02                       ; OR palette/priority bits
    CLC : ADC.W #$0400                      ; +palette-row offset for bottom
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
    ; First-time-per-page CELL_TILE init. Sentinel cleared by VWFClsHook on
    ; page transitions; re-init here so CELL_TILE allocations don't leak
    ; from a stale prior page. Within a page (typewriter mode) the init is
    ; skipped so prior cells keep their tile_id assignments and the canvas
    ; tilemap entries from earlier emits stay valid.
    LDA.L !VWF_CELL_INIT                    ; M=8 (set by gate-decision check above)
    CMP.B #$A5
    BEQ .cellInitReady
    REP #$20
    JSL.L VWFInitCellTable                  ; clears CELL_TILE + resets pool cursor
    SEP #$20
    LDA.B #$A5
    STA.L !VWF_CELL_INIT
.cellInitReady:
    ; Reset LAST_COL = $FF so the first char of this emit doesn't trigger
    ; gap-fill from a stale prior-emit value.
    SEP #$20
    LDA.B #$FF
    STA.L !VWF_LAST_COL
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

    ; Initialize VWF_PREV_COL = $09FC - 1 so the first char's
    ; ($09FC == prev + 1) check passes naturally — no spurious col-jump
    ; pen reset on the first text char of the emit.
    LDA.W $09FC
    DEC A
    STA.L !VWF_PREV_COL

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

VWFClsHook:
    JSL.L $81ECE1                           ; run displaced original (initTilemapAndSync_Long)

    ; Page transitions invalidate the global blank tile — engine re-loads
    ; BG3 char data; tile $200 needs re-DMA on the first VWF-active emit
    ; of the new page. Lazy re-init from VWFCharHandler row-fill.
    SEP #$20
    LDA.B #$00
    STA.L !VWF_BLANK_TILE_VALID

    ; Page transition also invalidates per-cell tile_id allocations: the
    ; engine has overwritten the canvas tilemap to point at blank tiles,
    ; so CELL_TILE's prior assignments no longer correspond to anything
    ; on screen. PreRender's CELL_INIT check will see this $00 and re-run
    ; VWFInitCellTable on the first emit of the new page.
    STA.L !VWF_CELL_INIT

    ; Also reset gap-fill last-col tracker.
    LDA.B #$FF
    STA.L !VWF_LAST_COL

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

    ; Lazy-init the global blank tile if needed. Must run in VBlank — PPU
    ; rejects VRAM writes during active rendering, which is why doing this
    ; from CharHandler row-fill silently dropped the bytes and tile $200
    ; came back zero-filled.
    SEP #$20
    LDA.L !VWF_BLANK_TILE_VALID
    CMP.B #$A5
    BEQ +
    JSL.L VWFInitBlankTile                  ; sets VALID=$A5
+

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
; vwfDoDmaForCell — DMAs one canvas cell to its allocated VRAM tile.
; Entry: !VWF_BMP_CELL = cell index 0..255, X = byte loop counter (16-bit),
;        Y = bit loop counter (16-bit), M=8.
; Exit:  channel 7 DMA fires; A/X/Y preserved on stack, M=8.
; Per cell: source = $7F:7000 + cell*16, dest VRAM word = $6000 + tile_id*8,
;           16 bytes (single 1bpp-IL tile shared between top + bot tilemap).
; ----------------------------------------------------------------------------
vwfDoDmaForCell:
    PHA : PHX : PHY                         ; preserve loop state

    ; This helper is only reached on the WB bitmap-walk path; BB uses
    ; `.nmiSingleDMA` which never enters here. tile_id comes from the
    ; per-cell CELL_TILE table populated by .tilemapWB on first render.
    ;
    ;   tile_id   = CELL_TILE[cell]        ($FFFF = unallocated, skip cell)
    ;   VMADDR    = tile_id * 8 + $6000    (BG3 char base $C000 byte = $6000 word)
    ;   canvas src= cell * 16 + $7000      (1bpp-IL: 16 B/cell)
    REP #$20                                ; 16-bit for offset math
    LDA.L !VWF_BMP_CELL                     ; cell index in low byte
    AND.W #$00FF                            ; clean high
    STA.L !VWF_TMP_POS                      ; stash cell for canvas-src calc

    ; Look up CELL_TILE[cell] (16-bit allocated tile_id, or $FFFF sentinel)
    ASL A                                   ; cell * 2 (16-bit table offset)
    TAX
    LDA.L !VWF_CELL_TILE,X                  ; allocated tile_id
    CMP.W #$FFFF
    BEQ .skipDmaCell                        ; unallocated → skip cell

    ; Defensive bound check: tile_id must be in BG3 tileset $0..$1FF
    ; (= BG3 char data byte $C000..$DFF8). Pool ranges are pre-validated
    ; safe so this should never trip; defends against authoring mistakes.
    CMP.W #$01FF
    BCS .skipDmaCell

    ; VMADDR = tile_id * 8 + $6000  (each tile is 8 words, unchanged)
    ASL A : ASL A : ASL A                   ; tile_id * 8 (word offset)
    CLC : ADC.W #$6000                      ; + BG3 char base word
    STA.W $2116

    ; canvas src = cell * 16 + $7000  (1bpp-IL stride)
    LDA.L !VWF_TMP_POS
    ASL A : ASL A : ASL A : ASL A           ; cell * 16
    CLC : ADC.W #$7000                      ; A1T7 = $7F:7000 + offset
    STA.W $4372

    LDA.W #$0010                            ; 16 bytes per DMA (one 8x8 1bpp-IL tile)
    STA.W $4375

    SEP #$20
    LDA.B #$80                              ; trigger ch7
    STA.W $420B

    PLY : PLX : PLA                         ; restore loop state
    RTS

.skipDmaCell:
    SEP #$20                                ; restore M=8 for caller convention
    PLY : PLX : PLA                         ; restore loop state
    RTS                                     ; sentinel — no $420B trigger

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

; ----------------------------------------------------------------------------
; vwfAllocOne — hand out the next tile_id from the WB pool (1bpp-IL).
;
; Each cell needs ONE tile_id (top + bot tilemap entries share it via the
; +$0400 palette-row offset trick). Allocator returns N and bumps POOL_NEXT
; by 1. Pool ranges live in !VWF_POOL_RANGES (8 × (dw start, db count) =
; 24 B). When the current range is empty, advances RNG_OFF by 3 to load the
; next one. A range with start = $FFFF marks the end of the pool.
;
; Entry: any M/X. Caller convention: JSR (intra-bank $E0).
; Exit: A = tile_id (M=16), or $FFFF if pool exhausted. P/X preserved.
;       POOL_NEXT, POOL_REMAIN, POOL_RNG_OFF mutated as needed.
; ----------------------------------------------------------------------------
vwfAllocOne:
    PHP
    REP #$30                                ; M=16, X=16
    PHX
.tryAlloc:
    SEP #$20                                ; 8-bit for byte slots
    LDA.L !VWF_POOL_REMAIN
    BEQ .needNext                           ; remaining == 0 → advance
    DEC A                                   ; remaining -= 1
    STA.L !VWF_POOL_REMAIN
    REP #$20                                ; M=16 for word op
    LDA.L !VWF_POOL_NEXT                    ; current tile_id
    PHA                                     ; save for return
    INC A                                   ; bump for next allocation
    STA.L !VWF_POOL_NEXT
    PLA                                     ; A = old tile_id
    PLX
    PLP
    RTS
.needNext:
    LDA.L !VWF_POOL_RNG_OFF                 ; M=8 still
    CLC : ADC.B #$03                        ; advance to next range
    STA.L !VWF_POOL_RNG_OFF
    CMP.B #$18                              ; 8 ranges × 3 B = 24
    BCS .exhausted                          ; off >= 24 → end of table
    REP #$20                                ; widen for indexed read
    AND.W #$00FF
    TAX                                     ; X = byte offset into POOL_RANGES
    LDA.L !VWF_POOL_RANGES,X                ; range[idx].start (16-bit)
    CMP.W #$FFFF
    BEQ .exhausted                          ; sentinel range = end of table
    STA.L !VWF_POOL_NEXT
    SEP #$20
    LDA.L !VWF_POOL_RANGES+2,X              ; range[idx].count (8-bit)
    STA.L !VWF_POOL_REMAIN
    JMP .tryAlloc
.exhausted:
    REP #$20
    LDA.W #$FFFF
    PLX
    PLP
    RTS

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

    ; Default pool ranges = all-$FF (every range's start = $FFFF sentinel).
    ; Pure-WB unmatched scenes get an immediately-exhausted pool, so the
    ; allocator returns $FFFF for every cell and .tilemapWB falls into the
    ; skip-write path. Net effect: same as gate-OFF / original tile path.
    SEP #$20
    LDX.W #$0017                            ; 24 bytes - 1 = last index
    LDA.B #$FF
.clearPoolRanges:
    STA.L !VWF_POOL_RANGES,X
    DEX
    BPL .clearPoolRanges                    ; M=8 for byte ops continues below

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
    ;   per row (29 bytes):
    ;     db <LO>, <HI>, <BNK>              ; 3 — captured 24-bit text src ptr
    ;     dw <VRAM_word_base>               ; 2 — single-DMA path dest (BB legacy
    ;                                       ;     compat; not used on WB)
    ;     8 × (dw <start>, db <count>)      ; 24 — pool ranges (start=$FFFF
    ;                                       ;     terminates the list)
    ;
    ; Match: all three (LO, HI, BNK) bytes must equal captured ($14, $15, $16).
    ; On match: gate flips ON, VRAM_BASE + 24-byte pool ranges copied.
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

    ; Full match — flip gate ON, load VRAM_BASE, copy 24-byte pool ranges.
    LDA.B #$A5 : STA.L !VWF_GATE
    REP #$20                                ; M=16 for word read
    LDA.L VWFGateAllowList+3,X              ; row +3: dw VRAM_word_base
    STA.L !VWF_VRAM_BASE

    ; Copy 24 bytes from row+5 into !VWF_POOL_RANGES, byte-by-byte. The
    ; (dw, db) layout misaligns word reads (count byte sits between two
    ; word-aligned starts), so a byte loop avoids the alignment hazard.
    ; DBR set to $E0 (this patch's bank) so absolute,Y can read VWFGateAllowList.
    PHB
    SEP #$20
    LDA.B #$E0 : PHA : PLB                  ; DBR = $E0
    REP #$30                                ; M=16, X=16 for index math
    TXA : CLC : ADC.W #$0005                ; A = row_offset + 5 (source base)
    TAY                                     ; Y = source byte index
    LDX.W #$0000                            ; X = dest byte index
    SEP #$20                                ; M=8 for byte copy
.copyPoolRanges:
    LDA.W VWFGateAllowList,Y                ; 1 byte from src
    STA.L !VWF_POOL_RANGES,X                ; long,X destination
    INY
    INX
    CPX.W #$0018                            ; 24 bytes total
    BCC .copyPoolRanges
    PLB

    BRA .done
.next:
    REP #$20                                ; M=16 so ADC works on full word
    TXA : CLC : ADC.W #$001D                ; advance one 29-byte row
    TAX
    SEP #$20
    DEY                                     ; counter--
    BNE .scan
.done:
    PLP
    RTL

; ----------------------------------------------------------------------------
; VWFInitBlankTile — DMA the $FFFF×32 polarity-fill source into VRAM tile
; $200 (= byte $E000 at BG3 char base). One-shot per scene; the row-fill
; in VWFCharHandler triggers it lazily on the first VWF-active row paint.
; Sets !VWF_BLANK_TILE_VALID = $A5 on success.
;
; Uses DMA channel 7 (same as other VWF DMAs; safe to reconfigure mid-NMI
; or mid-emit since the bitmap-walk re-sets ch7 from scratch each cell and
; .nmiSingleDMA is the only other ch7 user).
;
; Caller convention: M=16, X=16. P preserved via PHP/PLP.
; ----------------------------------------------------------------------------
VWFInitBlankTile:
    PHP
    REP #$30

    ; VMAIN: increment after high-byte write (mode 1 alternating)
    SEP #$20
    LDA.B #$80
    STA.W $2115
    REP #$20

    ; VMADDR = word $7000 (= byte $E000 = tile $200 of BG3 char data).
    LDA.W #$7000
    STA.W $2116

    ; Set up DMA channel 7: A→B mode 1, source = ROM data block in bank $E0.
    SEP #$20
    LDA.B #$01                              ; DMAP7: mode 1
    STA.W $4370
    LDA.B #$18                              ; BBAD7 = $2118 (VMDATAL)
    STA.W $4371
    LDA.B #bank(VWFBlankTileData)           ; A1B7 = source bank
    STA.W $4374
    REP #$20
    LDA.W #VWFBlankTileData                 ; A1T7 = source addr (16-bit, .W truncates to low word)
    STA.W $4372
    LDA.W #$0010                            ; DAS7 = 16 bytes (one 1bpp-IL tile)
    STA.W $4375

    SEP #$20
    LDA.B #$80                              ; trigger ch7 (bit 7)
    STA.W $420B

    LDA.B #$A5
    STA.L !VWF_BLANK_TILE_VALID

    PLP
    RTL

; 16 bytes of $FF — DMA source for the global blank tile (1bpp-IL).
; WB polarity (white-on-white). For BB scenes the same data would render
; black-on-black (a "blank" of the opposite polarity), but blank-tile
; reuse is only invoked on WB scenes so this is fine.
VWFBlankTileData:
    db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF

; ----------------------------------------------------------------------------
; VWFInitCellTable — clear CELL_TILE to $FFFF and reset pool cursor to
; range[0]. Called once per page from PreRender when CELL_INIT sentinel
; is clear (i.e., first emit after [cls] or boot). Cleared by ClsHook so
; each new page gets a fresh allocation slate.
;
; CELL_TILE = 256 entries × 16-bit = 512 bytes. Fully clearing per emit
; would be wasteful; the cross-emit persistence is what lets typewriter
; rendering hold prior chars stable while new pen-revealed chars get
; fresh tile_id allocations.
;
; Caller convention: M=any, X=any. Both preserved via PHP/PLP.
; ----------------------------------------------------------------------------
VWFInitCellTable:
    PHP
    REP #$30                                ; M=16, X=16

    ; Fill CELL_TILE with $FFFF (unallocated sentinel)
    LDX.W #$01FE                            ; last byte offset (510 = entry 255 lo)
    LDA.W #$FFFF
.cellLoop:
    STA.L !VWF_CELL_TILE,X
    DEX : DEX
    BPL .cellLoop

    ; Reset pool cursor to range[0]. POOL_RANGES has been populated by
    ; VWFGateDecision earlier this emit (allow-list match → real ranges,
    ; no match → all $FFFF sentinels making allocator instantly exhausted).
    SEP #$20
    LDA.B #$00
    STA.L !VWF_POOL_RNG_OFF
    REP #$20
    LDA.L !VWF_POOL_RANGES                  ; range[0].start (16-bit)
    STA.L !VWF_POOL_NEXT
    SEP #$20
    LDA.L !VWF_POOL_RANGES+2                ; range[0].count (8-bit)
    STA.L !VWF_POOL_REMAIN

    PLP
    RTL

; ----------------------------------------------------------------------------
; VWFGateAllowList — opt-in table for sources we WANT VWF to run on.
;
; Layout:
;   db <count>                              ; first byte: number of rows
;   per row (29 bytes):
;     db <LO>, <HI>, <BNK>                  ; 3 — captured 24-bit text src ptr
;     dw <VRAM_word_base>                   ; 2 — BB single-DMA legacy override
;     8 × (dw <range_start>, db <count>)    ; 24 — pool ranges, 3 B each
;
; Pool ranges enumerate BG3-tileset tile_ids (within $0..$1FF) that are
; safe for VWF char data — i.e., NOT actively rendered by BG2 (since BG2
; and BG3 share VRAM bytes when their char bases overlap), AND not used
; by BG3 itself (engine UI font, chrome, borders).
;
; Allocator allocates 2 consecutive tile_ids per rendered char (top tile
; for upper 8 pixels, bot tile for lower 8). Ranges with odd counts waste
; the trailing odd tile when the range exhausts. Ranges with start=$FFFF
; mark end-of-list (so a row with fewer than 8 ranges left pads remaining
; slots with $FFFF/$00).
;
; Authoring workflow:
;   1. Load the scene in Mesen; read $7F:5D14..5D16 → (LO, HI, BNK).
;   2. Inspect BG3 tileset @ VRAM bytes $C000..$DFF8 (= tile_ids $0..$1FF)
;      and BG2 tilemap to identify safe tile_id ranges. Look for runs of
;      $FF-fill or $00-fill BG3 tiles where BG2's tilemap has no entries
;      pointing at the same tile_ids.
;   3. List the safe ranges as (start_tile_id, count) pairs. Pad to 8 with
;      ($FFFF, $00) if fewer than 8 ranges.
;   4. VRAM_word_base is only used by the BB single-DMA path; for WB rows
;      it can stay at the default $6100.
;   5. Append the 29-byte row, increment the count byte.
;   6. ./build.sh --no-cache (section cache must be busted).
;
; BB rows (where the legacy hardcoded $20+row*64+col*2 formula applies)
; don't use the pool — set all 8 ranges to ($FFFF, $00).
; ----------------------------------------------------------------------------
VWFGateAllowList:
    db 1                                    ; row count
    ; row 0: $02:DF72 — file information save-data text (WB scene).
    ;
    ; BG3 tileset window byte layout in this scene's PPU setup ($210B = $60,
    ; $210C = $66 → BG2 char base $C000, BG3 char base $C000):
    ;
    ;   $C000..$DFF8  BG3 char data (engine font + chrome glyphs, tile_ids
    ;                 $0..$1FF). UNSAFE — chrome's BG3 tilemap references
    ;                 these for button frames / labels, AND the engine
    ;                 renders cursor blink + .origPath chars (chars outside
    ;                 VWF range, esp. cursor's '>' arrow) using these
    ;                 tile_ids directly via writeTextCharacter. Snapshotting
    ;                 BG3 tilemap can't see the .origPath usage, so any
    ;                 "scanned safe" run in $0..$1FF is a trap — the cursor
    ;                 blink uses one of those slots.
    ;   $E000..$E7FF  BG2 tilemap (= BG3 tile_ids $200..$27F). UNSAFE.
    ;   $E800..$EFFF  GAP between tilemaps (= BG3 tile_ids $280..$2FF).
    ;                 SAFE — structurally unclaimed by any layer.
    ;   $F000..$F7FF  BG1 tilemap (= BG3 tile_ids $300..$37F). UNSAFE.
    ;   $F800..$FFFF  BG3 tilemap (= BG3 tile_ids $380..$3FF). UNSAFE —
    ;                 we'd corrupt our own tilemap!
    ;
    ; Pool design: anchor on the structurally-safe gap region between BG2
    ; and BG1 tilemaps, then add a user-confirmed safe range in the lower
    ; tileset window. The earlier scan-derived high-range supplements
    ; (tile_ids $130..$1EF) were dropped — they overlapped engine state
    ; that runtime tilemap snapshots couldn't see, corrupting the cursor
    ; blink and chrome.
    ;
    ;   $0280..$2FF  128 tiles  (gap $E800..$EFFF, structurally unclaimed,
    ;                            64 pairs — primary)
    ;   $00B0..$0FF   80 tiles  (= VRAM word $6580..$67F8, user-confirmed
    ;                            safe by visual inspection of file-info
    ;                            chrome, 40 pairs)
    ;   total: 208 tiles = 104 pairs (plenty for ~80 cells across 4 lines)
    ;
    ; Authoring rule: only use tile_ids in this AllowList row that have
    ; been confirmed safe through chrome-tilemap scans WITH VWF gated off
    ; (or visual inspection). Runtime snapshots taken with VWF active see
    ; OUR own writes and obscure the underlying engine font/chrome usage.
    ;
    ; VRAM_word_base $6100 is the BB single-DMA legacy default; not
    ; consulted on this WB source.
    db $72, $DF, $02 : dw $6100
    ; User-directed pool start: VRAM word $6280.w = tile_id $50. Avoids
    ; cursor's tile $3E. Range 0 stops at $AF so range 1 ($00B0..$0FF =
    ; user-verified safe range from earlier scan) can chain in without
    ; overlap. Total 176 tiles = 88 cell pairs (covers ~80 cells across
    ; Game Start / Delete Data / 3 file lines).
    dw $00B0 : db  80
    dw $0194 : db 108       ; gap word $7400..$77F8 (64 pairs)
    dw $FFFF : db   0
    dw $FFFF : db   0
    dw $FFFF : db   0
    dw $FFFF : db   0
    dw $FFFF : db   0
    dw $FFFF : db   0
print "VWF recovery build end: $", pc
