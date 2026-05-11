; ============================================================================
; vwf_patch.asm — Variable-width font for Little Master III (RECOVERY BUILD)
; ----------------------------------------------------------------------------
; Restored from bedd8a6 ("static rendering is working for VWF") + 399ebe5
; ([cls] reset hook + bank $E0 relocation) + saturating-bounds lesson from
; the post-restart work.
;
; DESIGN
;   - Per-char hook at $80:C17B replaces the game's per-character tilemap
;     write (writeTilemapEntry) with VWFCharHandler. Non-renderable chars
;     and out-of-range codes pass through via .origPath / .doOrig.
;   - Wrapper hook at $80:BC75 brackets the call to processText with
;     VWFPreRender (set up canvas + flag + sentinels) and VWFPostRender
;     (mark canvas dirty + clear flag).  PreRender and PostRender run
;     SYNCHRONOUSLY around processText — they touch only WRAM (canvas at
;     $7F:7000 + state at $7F:5D00), no PPU access, no DMA trigger.
;   - DMA is DEFERRED to NMI.  VWFNMI (Hook 4) checks VWF_DIRTY at vblank
;     entry and uploads the dirty canvas range to VRAM tiles $20+ on DMA
;     channel 7 (engine never uses ch7).  The deferral is intentional:
;     vblank is the only safe window for VRAM writes outside forced blank,
;     and a forced blank inside processText would cause a visible
;     mid-frame brightness blip.  The cost is one frame of latency
;     between rasterizing into the canvas and seeing the pixels on
;     screen — which lines up naturally with the engine's per-character
;     typewriter delay.
;   - Scene-change detection: VWFCaptureSource (Hook 6) records the
;     resolved 24-bit text source pointer at every Phase 1 entry.
;     PreRender compares the current (INVERT, TEXT_LO/HI/BNK) tuple
;     against the LAST_* fingerprint; mismatch triggers a fresh
;     SceneInit (canvas wipe, CELL_TILE reset, queued VRAM polarity
;     wipe).  Catches transitions even when the engine doesn't issue an
;     explicit [cls].
;   - [cls] hook at $80:C022 replaces the JSL initTilemapAndSync_Long
;     dispatched by textStream_ExtFF for the [cls] opcode.  It runs the
;     original clear+sync first, then forces a SceneInit so the next
;     page renders with no leftover canvas pixels.
;   - Cursor-blink suppression: the readTextCursorState hook (Hook 7,
;     $00:C219) arms VWF_BLINK before every cursor write.  The cursor-ON
;     frame (A=$3E) consumes the flag through CharHandler's .vwf →
;     .origPath route.  The cursor-OFF frame (A=$0000) takes
;     writeTextCharacter's early path at $00:C167 and bypasses Hook 1
;     entirely; Hook 8 (R3.F-4) intercepts that write site and clears
;     VWF_BLINK after replicating its displaced two-plane store.  Either
;     frame leaves BLINK==$00 — no leak past the cursor loop.
;   - Pixel-based line wrap: the line-end check at $00:BE92 (Hook 5)
;     compares VWF_PX to (line_char_limit * 8) instead of the engine's
;     col-count comparison.  Lets VWF use the full pixel width of the
;     dialog box.
;
; COVERAGE GAPS (sub-paths of writeTextCharacter that VWF does NOT see):
;   The Hook 1 install point is on the *default* branch of
;   writeTextCharacter at $00:C156.  Three sibling branches bypass our
;   hook entirely; they remain on the original engine path:
;     - early-out at $00:C167 when (A == 0 && $6F != 0): writes tile
;       $0100 raw to both planes.  Triggered by the cursor "off" frame
;       in pollInputFlashCursor.
;     - textChar_AltMode at $00:C18F: runs when $0A1C != 0
;       (alt-palette mode).
;     - textChar_CalcTileAddr at $00:C1A6: runs when $0A1E != 0
;       (special-tile mode, subtracts $20 and adds $0A1E).
;   These produce fixed-width tile output — acceptable degradation,
;   but worth knowing if a future translation pushes $0A1C/$0A1E
;   non-zero and a glyph appears at the wrong width.
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

; ROM expansion to 32 Mbit / 4 MB so the $E0 bank is reachable.
; Header byte = log2(rom_KB): $0C = 12 → 4096 KB = 4 MB = 32 Mbit (the LoROM max).
org $00FFD7 : db $0C                        ; SNES header byte: ROM size = 32 Mbit (4 MB)
org $FFFFFF : db $00                        ; force ROM image to extend through bank $FF

; ----------------------------------------------------------------------------
; Bank where the VWF body, font, and helpers live (must match every `org $E0...`
; below and the source-bank loaded into DMA channel 7's A1B7 register).
; Defined as a named constant so live-code references read as e.g.
; `LDA.B #!VWF_BANK` instead of a bare `#$E0` literal — single source of
; truth if the bank ever needs to move.
; ----------------------------------------------------------------------------
!VWF_BANK = $E0

; ----------------------------------------------------------------------------
; Debug flag (R1.F-10).  When non-zero, compiles in instrumentation that helps
; live debugging in Mesen but adds runtime overhead:
;   - VWF_DBG_CAPCOUNT:  per-Phase-1-entry counter at $7F:5D60. Lets you
;                        confirm Hook 6 is firing by watching that address
;                        increment, without needing a breakpoint.
; Set to 0 for release builds. Each gated block's overhead is documented at
; its `if !VWF_DEBUG` site.
; ----------------------------------------------------------------------------
!VWF_DEBUG = 0

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

; ----------------------------------------------------------------------------
; Scene-aware tile cache (Plans/vwf-scene-aware-cache-plan.md, Phase 1).
;
; Phase 1 = read-only instrumentation: VWFPreRender computes a 4-byte
; fingerprint identifying the current scene and stores it in
; !VWF_SCENE_TAG. No render-path consumer reads it yet — verification is
; via Mesen IPC reading $7F:5D40 across scenes (dialog, file-info,
; unit-info) and confirming distinct stable values per scene type.
;
; Subsequent phases (2..4) introduce SLICE / HEAD / CACHE_VALID consumers
; that turn the fingerprint into per-scene tile-range allocation and
; tilemap-only re-emit caching. Phase 1 only allocates the slots; phases
; 2..4 wire them up.
;
; Layout:
;   $7F:5D40  +0..+1  text source LO / HI       (mirrors !VWF_TEXT_LO/HI)
;   $7F:5D42  +2      text source BNK           (mirrors !VWF_TEXT_BNK)
;   $7F:5D43  +3      polarity | $0A1E_HI       (composite scene byte)
;
; Composite byte recipe:
;   bit 7   = polarity ($00 or $80, mirrors !VWF_INVERT bit 7)
;   bits 6..0 = $0A1E high byte's low 7 bits  (encodes palette / priority /
;             flips / tile_high_2bits — distinguishes menu categories)
;
; Observed values during Unit Information rendering (V2 capture):
;   $0A1E = $3900 → comp = $80 | ($39 & $7F) = $B9   (names, palette 6)
;   $0A1E = $3500 → comp = $80 | ($35 & $7F) = $B5   (classes, palette 5)
;   $0A1E = $3100 → comp = $80 | ($31 & $7F) = $B1   (numbers, palette 4)
;   $0A1E = $0000 → comp = $80 | $00 = $80           (dialog WB)
;   $0A1E = $0000 → comp = $00 | $00 = $00           (dialog BB)
; All distinct.
; ----------------------------------------------------------------------------
!VWF_SCENE_TAG    = $7F5D40   ; 4 B  scene fingerprint (Phase 1: read-only)
!VWF_SCENE_SLICE  = $7F5D44   ; 1 B  active slice index (Phase 3+)
!VWF_SCENE_HEAD   = $7F5D46   ; 2 B  next-free tile_id in active slice (Phase 3+)
!VWF_CACHE_VALID  = $7F5D48   ; 1 B  $A5 = previous emit's CELL_TILE/canvas
                              ;       state is committed and reusable
                              ;       (Phase 2: set by VWFPostRender,
                              ;        cleared by VWFRequestSceneInit/
                              ;        VWFRequestPageReset).
!VWF_REGEN_ONLY   = $7F5D49   ; 1 B  REPURPOSED for !VWF_CLS_PENDING in
                              ;       Phase 4b Option D (cls-gated PageReset).
                              ;       Original Phase 2 use (re-emit cache fast
                              ;       path) was never wired up to consumers.
                              ;       New use: $A5 = VWFClsHook fired since
                              ;       last VWFPreRender; consumed (cleared) by
                              ;       VWFPreRender's PageReset gate. Distinguishes
                              ;       dialog page advance (cls fires) from
                              ;       menu sub-string emits (no cls), so menu
                              ;       state persists across emits within scene.
!VWF_CLS_PENDING  = $7F5D49   ; alias for !VWF_REGEN_ONLY (Phase 4b Option D)
!VWF_LAST_SCENE_TAG = $7F5D4A ; 4 B  prev committed emit's SCENE_TAG
!VWF_LAST_BUF_SIG   = $7F5D4E ; 2 B  prev committed emit's buffer
                              ;       XOR-fold of first 32 bytes ($0400..$041F)

; --- Phase 3 step 1 — scene→slice LRU tracking (instrumentation) -----------
; 3-slot LRU mapping SCENE_TAG → slice index. On scene change, PreRender
; calls VWFAssignSlice which sets !VWF_SCENE_SLICE to the slot owning this
; scene. On hit, slot is reused (next phase: tile-range cache hit). On
; miss, round-robin advance LRU_NEXT and copy SCENE_TAG into the chosen
; slot's tag slot.
;
; Phase 3 step 1 is INSTRUMENTATION ONLY — !VWF_SCENE_SLICE is set but
; not yet consumed by the pool allocator or canvas wipe. Verification:
; navigate dialog → file-info → unit-info → dialog and confirm each
; scene type lands at a stable slot index, and re-visits hit existing
; slots without round-robin churn (within 3-slot LRU capacity).
;
; The slice ownership lives in the upcoming WB pool carve-up:
;   slot 0 → tiles $00B1..$00C8 (24 tiles)  (Phase 3 step 2)
;   slot 1 → tiles $00C9..$00E0 (24 tiles)
;   slot 2 → tiles $00E1..$00F1 (17 tiles)
; Phase 3 step 1 does not yet reserve these — that happens when the
; allocator and wipe routines learn to scope to !VWF_SCENE_SLICE.
!VWF_SLICE_LRU_TAG_0 = $7F5D52 ; 4 B  scene tag for LRU slot 0
!VWF_SLICE_LRU_TAG_1 = $7F5D56 ; 4 B  scene tag for LRU slot 1
!VWF_SLICE_LRU_TAG_2 = $7F5D5A ; 4 B  scene tag for LRU slot 2
!VWF_SLICE_LRU_NEXT  = $7F5D5E ; 1 B  next slot to evict on miss (0..2)

; --- Phase 3 step 2 — active slice's pool tile range (set per-emit by
;     VWFAssignSlice; consumed by VWFCharHandler's pool allocator and
;     exhaustion check).  Carved into the CHROME-SAFE range $00B1..$00F1
;     only — VRAM analysis showed unit-info and file-info both use
;     tile_ids in $0022..$008C (in the broader $21..$F1 window) for
;     chrome / icons / stat indicators.  Allocating Hook 9 / VWF tiles
;     anywhere in $0022..$00B0 corrupted chrome on screens that revisit
;     those tiles.  Restricting all 3 LRU slots to $00B1..$00F1 (which
;     was clean of chrome usage on both observed WB screens) preserves
;     chrome while still giving Hook 9 a reasonable allocation pool.
;
;       LRU slot 0:  $00B1..$00C8  (24 tiles)
;       LRU slot 1:  $00C9..$00E0  (24 tiles)
;       LRU slot 2:  $00E1..$00F1  (17 tiles)
;
; Trade-off: total VWF allocator capacity drops from 209 → 65 tiles.
; Per-slice capacity drops to ~24 tiles, which may exhaust on
; chunkier menus (file-info needed 36 tiles in earlier 48-tile slice).
; Phase 4+ may need to expand by carving narrow allocator-safe slivers
; INSIDE the otherwise chrome-occupied range, but for the immediate
; "Hero renders + chrome stays" goal, the conservative all-in-$B1..$F1
; layout is the cleanest first cut.
;
; BB / dialog (SCENE_SLICE = $FF) does NOT consume pool tiles — its
; per-char tilemap entries are computed by formula (`$20 + row*32 +
; col`).  POOL_FIRST_ACTIVE / POOL_END_ACTIVE are written to safe
; defaults on the BB short-circuit but are not read on the BB code
; path.
!VWF_POOL_FIRST_ACTIVE = $7F5D60 ; 2 B  active slice's first allocable tile_id
!VWF_POOL_END_ACTIVE   = $7F5D62 ; 2 B  active slice's exhausted-at tile_id
                                 ;       (CMP A, end_active; BCS = exhausted)
!VWF_LAST_SCENE_SLICE  = $7F5D64 ; 1 B  prev emit's SCENE_SLICE; if differs
                                 ;       from current, POOL_NEXT is reset to
                                 ;       new slice's FIRST (cross-scene
                                 ;       isolation). Within same slice,
                                 ;       POOL_NEXT carries over for typewriter
                                 ;       advance + cell reuse.

; Phase 4 step 1+: char-map caching for the Hook 9 path.
;   Maps char_value (8-bit) → tile_id_low_byte within the active slice.
;   $FF = unallocated. Otherwise the byte holds the tile_id; tilemap
;   composition reuses it to avoid re-allocating on repeat chars.
;   Wiped on slice-change (so a new slice's char-map starts fresh).
;
;   Without this, 68 Hook 9 hits on file-info (only 23 distinct chars)
;   would exhaust a 24-tile slice; with the cache, ~23 unique
;   allocations fit comfortably.
!VWF_HOOK9_CHARMAP     = $7F6000 ; 256 B  char_map[char] = tile_id_low ($FF=unalloc)

if !VWF_DEBUG
    ; Sentinel counter — VWFCaptureSource increments this once per call.
    ; Lets us confirm in Mesen IPC ($7F:5D60) that the hook is firing without
    ; needing a breakpoint. Wraps at 256. Compiled out when !VWF_DEBUG = 0.
    !VWF_DBG_CAPCOUNT = $7F5D60
endif

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
;   ($7F:5DBC was VWF_CELL_INIT — set but never read, removed in R1.)
;   LAST_COL     $7F:5DBD  1 B   — gap-fill tracker; $FF = no prior col.
;   CELL_TILE    $7F:5E00  512 B — per-cell allocated tile_id (256 cells
;                                  × 16-bit). $FFFF = unallocated.
; ----------------------------------------------------------------------------
!VWF_POOL_NEXT     = $7F5DBA
!VWF_LAST_COL      = $7F5DBD
!VWF_CELL_TILE     = $7F5E00

; ----------------------------------------------------------------------------
; Step 9 — non-blank run list (VWFDedupeRow + VWFNMI multi-segment DMA).
;
; The dedupe scan walks each tile in [FIRST_SAVX..VWF_SAVX]. Consecutive
; non-blank tiles form a "run". The list captures up to MAX_RUNS runs;
; each entry = (canvas_byte_start, canvas_byte_end_exclusive). VWFNMI's
; WB path iterates the list and issues one DMA per run, skipping interior
; blank gaps that the existing single-DMA approach would have re-uploaded.
;
;   $7F:5DBE  DMA_RUNS    16 B  — array of 4 × (start_W, end_W)
;   $7F:5DCE  DMA_NRUNS    2 B  — number of valid entries (0..MAX_RUNS)
;   $7F:5DD0  DMA_IN_RUN   2 B  — transient flag during scan ($A5 = in run)
;
; Slots are 16-bit so M=16 helper code can load/store without M dance.
;
; NRUNS == 0 → no run list captured. VWFNMI falls back to the legacy
; [DMA_LO..DMA_HI] single-DMA path (preserves BB behavior + WB fallback).
; ----------------------------------------------------------------------------
!VWF_DMA_RUNS     = $7F5DBE     ; 16 B  (4 × (start_W, end_W))
!VWF_DMA_NRUNS    = $7F5DCE     ; 2 B
!VWF_DMA_IN_RUN   = $7F5DD0     ; 2 B
!VWF_DMA_MAX_RUNS = 4           ; cap; exceeding this falls back to single-DMA

; ----------------------------------------------------------------------------
; Path B — max canvas slot index reached by rasterizer in current emit.
; Tracks the highest canvas tile slot the rasterizer wrote to (primary OR
; spill). Used by PostRender's VWFDedupeRow (Step B7) to compute a precise
; DMA_HI = row_base + (MAX_SLOT+1)*16. Sentinel $FFFF = no writes yet.
;
; This is INDEX, not byte offset. End byte of slot N = (N+1)*16.
; ----------------------------------------------------------------------------
!VWF_MAX_SLOT     = $7F5DD2     ; 2 B  (canvas slot INDEX, 0..31; $FFFF = none)

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
!VWF_TM_OFFSET = $7F5D33    ; 1 B — count of dedup-blank tilemap entries
                            ; skipped on the current row. Each skip shifts
                            ; subsequent tilemap byte offsets by -2 (one cell
                            ; left), so the next char fills the slot the
                            ; engine was about to write a phantom $20 into.
                            ; The blank was an artifact of pen-tile sharing
                            ; without spill (LEFTMOST reused, no PRIMARY) —
                            ; it was never intended content. Reset on
                            ; PreRender (per emit) and on row change.
!VWF_TMP_TILE_ID = $7F5D34  ; 2 B — PRIMARY pen-tile alloc tile_id (Variant F).
                            ; Saved by .hasWidth WB allocator: equals LEFTMOST
                            ; alloc when sub_shift+width <= 8 (no spill), else
                            ; equals PRIMARY=LEFTMOST+1 alloc. Consumed by
                            ; .normalTilemap WB path as the tilemap entry's
                            ; tile_id, so each engine col references the
                            ; canvas tile holding the char's primary body.

; --- Phase 4b Bug-B fix: end-of-emit flush state -----------------------------
; The dedup-blank discard path drops the LAST char of an emit when it kerns
; into the prior char's pen-tile with no spill — TMP_TILE_ID is set to BLANK
; ($20), discard fires, TM_OFFSET++, and the trailing engine col is left
; unwritten (chrome blank). With no NEXT non-blank emit on the row to absorb
; the shift, the trailing chars of class strings disappeared visually.
;
; Fix: CharHandler tracks LAST_LEFTMOST_TID (the LEFTMOST tile_id at every
; alloc/reuse) and LAST_DISCARD ($A5 = last char hit the discard path).
; PostRender, if both VWF_FLAG=$A5 and LAST_DISCARD=$A5, writes a final
; "flush" tilemap entry at VWF_SAVX (the last char's engine-side tilemap
; offset) reusing LAST_LEFTMOST_TID — the trailing engine col gets the same
; canvas tile that holds the discarded char's rasterized pixels (kerned
; alongside its predecessor in the LEFTMOST canvas slot).
!VWF_LAST_LEFTMOST_TID = $7F5D36 ; 2 B — last LEFTMOST tile_id allocated/reused
!VWF_LAST_DISCARD      = $7F5D38 ; 1 B — $A5 if last char was discard-blank
                                  ;       Reset to $00 by every non-discard
                                  ;       tilemap write and by VWFPreRender.

; ----------------------------------------------------------------------------
; PostRender single-row tilemap dedupe (Plans/vwf-scene-aware-cache-plan.md
; "Multi-row dedupe (deferred from $5B93)" — restart 2026-05-10).
;
; !VWF_FIRST_SAVX = tilemap byte offset of the FIRST char drawn in the
; current emit's current row. Sentinel $FFFF means "not yet captured".
;
; Captured at .tilemapWrite on first arrival per emit/row; reset to $FFFF by
; VWFPreRender (per emit) and by CharHandler's row-change branch (per row,
; so multi-row emits dedupe only the row containing the LAST char).
;
; Aliased onto !VWF_LAST_LEFTMOST_TID — that slot has zero writers and its
; only reader (VWFPostFlush) is dead code (reverted from PostRender 2026-05-09,
; see comment block at VWFPostRender body). Repurposing avoids growing the
; state block at $7F:5D40+.
; ----------------------------------------------------------------------------
!VWF_FIRST_SAVX        = !VWF_LAST_LEFTMOST_TID ; alias — see PostRender dedupe

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
; Original 15 bytes were:
;   LDA #$0400 / STA $14 / STZ $16    (3+2+2 = 7 bytes — text-buffer init)
;   JSR processText  ($80:BE3B)       (3 bytes)
;   REP #$20 / LDA $0A16              (2+3 = 5 bytes — pre-BNE setup)
; ...followed by an unchanged BNE kanji_Return at $80:BC84.
;
; We split the 15-byte slot into three pieces while preserving that BNE:
;   PreRender  → carries displaced LDA #$0400 / STA $14 / STZ $16 plus
;                VWF setup (polarity sample, scene-fingerprint compare,
;                per-emit cursor-blink clear, partial canvas wipe, DMA
;                bounds reset, VWF_FLAG arm).  WRAM-only; no DMA.
;   processText → unchanged JSR $BE3B.
;   PostRender → sets VWF_DIRTY=$A5 + carries displaced REP #$20 / LDA
;                $0A16 (so the BNE at $BC84 reads Z from $0A16 just as in
;                the original).  WRAM-only; no DMA.
;
; The actual canvas → VRAM DMA happens in NMI (see VWFNMI / Hook 4),
; not here.  This file used to claim "synchronous bulk DMA inside
; PostRender" — that design was abandoned; NMI-deferred DMA replaced it
; to avoid the mid-frame forced-blank flicker the synchronous version
; produced.
; ============================================================================
org $80BC75
    JSL.L VWFPreRender                      ; 4 bytes — VWF setup + displaced LDA/STA/STZ
    JSR.W $BE3B                             ; 3 bytes — processText (Phase 2 dispatcher)
    JSL.L VWFPostRender                     ; 4 bytes — arm DIRTY + displaced REP/LDA $0A16
    NOP : NOP : NOP : NOP                   ; 4 bytes — pad to 15-byte slot; original BNE
                                            ;          at $80:BC84 reads Z from $0A16

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
; Hook 8 — cursor-OFF blank write  ($00:C167, 8 bytes overwritten)  R3.F-4
;
; writeTextCharacter at $00:C156 has an EARLY path that fires when
; A==$0000 && $6F!=0 && $0A1C==0 (the cursor "off" frame in border-mode
; dialog). It writes tile $0100 raw to both planes and bypasses Hook 1
; entirely:
;   $C167: STA.L $7E9000,X        ; 4 bytes (A = $0100, top tilemap entry)
;   $C16B: STA.L $7E9040,X        ; 4 bytes (bottom tilemap entry)
;   $C16F: RTS
;
; This bypass is the source of the BLINK leak: Hook 7 (readTextCursorState)
; armed VWF_BLINK before this write, but since the write skips Hook 1, the
; CharHandler never gets to consume the flag. BLINK persisted past the
; cursor loop and would route the next non-cursor char (typewriter advance,
; menu redraw, etc.) through .origPath instead of VWF rendering — visible
; as a single fixed-width glyph mid-line.
;
; Replacement: JSL VWFCursorBlank (4 bytes) + NOP×4 (4 bytes). The helper
; replicates the two displaced STA.L writes (so the cursor cell still
; renders as tile $0100), then clears VWF_BLINK so it cannot bridge to
; the next char. The RTS at $C16F still terminates the path normally.
;
; The other path that hits CharHandler (cursor-ON frame, A=$3E) still
; consumes BLINK via the existing .vwf → .origPath route in CharHandler,
; so both frames now reliably clear the flag — no leak past any cursor
; iteration, no leak past the post-loop final blank, no leak across the
; pollInputFlashCursor/waitForButtonPressText boundary.
; ============================================================================
org $80C167
    JSL.L VWFCursorBlank                    ; 4 bytes — replicates 2 STA.L + clears BLINK
    NOP : NOP : NOP : NOP                   ; 4 bytes — pad to original 8-byte slot

; ============================================================================
; Hook 9 — textChar_CalcTileAddr  ($00:C1A6, 14 bytes overwritten)
;
; writeTextCharacter ($00:C156) dispatches to textChar_CalcTileAddr at $C1A6
; whenever $0A1E != 0 (the "special-tile mode" — single-plane TOP-only
; tilemap write with formula `entry = (char - $20) + $0A1E`).  Hook 1's
; install site at writeTilemapEntry ($C17B) is on the *fall-through* branch,
; so this path bypasses VWF entirely.
;
; The Unit Information screen exercises this path via configMapMonitor
; ($01:CBD7), which sets $0A1E = $3900 around each char-write.  In the EN
; build the formula lands tile_ids at $100..$15F — outside the WB pool's
; hard cap of $00FF — so VRAM there holds whatever the engine left behind
; (no English glyph data) and names render as garbled fragments.
;
; The hook reroutes renderable chars through VWFCharHandler.  Non-renderable
; chars (control codes, padding) replicate the original engine math
; byte-exactly inside the helper.  The helper's design contract is in the
; VWFCalcTileAddrHook header in $E0:9100.
;
; Original 14 bytes at $C1A6:
;   PLA / SEC / SBC #$0020 / CLC / ADC $0A1E / STA.L $7E9000,X / RTS
; Replacement (14 bytes exactly):
;   PLA                       ; consume PHA-pushed char from $00:C170
;   STA.L !VWF_CHAR           ; stash for handler
;   JSL VWFCalcTileAddrHook   ; long-call (pushes K=$00 + ret addr)
;   RTS                       ; return to writeTextCharacter caller
;   NOP × 4                   ; pad to 14
;
; Why JSL/RTL instead of JML:
;   JML to bank $E0 changes K to $E0; an RTS at end of helper would pop the
;   caller's 2-byte JSR return but execute it at K=$E0, jumping into bank
;   $E0 garbage (caused the SP=$FFFF runaway in the first V1 attempt).
;   JSL pushes K+ret; RTL pops K+ret and resumes at the install-site RTS in
;   bank $00. Proper bank discipline.
; ============================================================================
; ============================================================================
; Hook 9 UNINSTALLED — restored to original engine bytes while we study
; the original render path more carefully (per user feedback: chrome
; territory is tiles $100+, font territory is $00..$FF; understand
; before redesigning Hook 9).  Phase 3 slice / LRU / char-map
; infrastructure stays installed but inert without Hook 9.
; ============================================================================
org $00C1A6
    PLA                                     ; original byte ($68)
    SEC : SBC.W #$0020                      ; original 4 bytes
    CLC : ADC.W $0A1E                       ; original 4 bytes
    STA.L $7E9000,X                         ; original 4 bytes
    RTS                                     ; original byte

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
    ;   1. Clear the new canvas row to the polarity fill value (BB only —
    ;      preserves pre-Phase-A multi-line dialog rendering). WB skips
    ;      this because PreRender does a full canvas wipe and the WB
    ;      rasterizer's canvas_row source (SAVX) wouldn't match the
    ;      $09FE-based row-fill source.
    ;   2. Reset VWF_PX so the new row's pen aligns to the engine's col.
    REP #$20                                ; ensure 16-bit for word compare
    LDA.W $09FE                             ; current text row id
    CMP.L !VWF_ROW                          ; compare against our saved row
    BEQ .sameLine                           ; same row → keep current pen

    ; --- BB-only: clear the new canvas row before render -----------------
    SEP #$20
    LDA.L !VWF_INVERT
    REP #$20
    BNE .skipBBRowFill                      ; WB → skip (PreRender did full wipe)

    PHX                                     ; preserve caller's tilemap-byte X
    PHA                                     ; preserve current $09FE (16-bit)

    LDA.W $09FE
    LSR A : AND.W #$0007                    ; canvas row 0..7
    XBA                                     ; row << 8
    ASL A                                   ; row << 9 = row*512 byte offset (1bpp-IL stride)
    TAX                                     ; X = canvas byte start of new row

    LDY.W #$0100                            ; 256 iterations × 2 = 512 bytes

    ; BB polarity fill = $0000 (no need to re-check INVERT, just fall through
    ; to the BB fill value).
    LDA.W #$0000                            ; BB → fill black
.bbRowFillLoop:
    STA.L !TILE_BUF,X
    INX : INX
    DEY
    BNE .bbRowFillLoop

    PLA                                     ; restore $09FE word
    PLX                                     ; restore caller's tilemap-byte X
.skipBBRowFill:

    ; Continue with pen reset
    LDA.W $09FC                             ; col index for the new row
    ASL A : ASL A : ASL A                   ; *8 → pixel x
    STA.L !VWF_PX                           ; reset pen
    LDA.W $09FE
    STA.L !VWF_ROW                          ; remember new row for next compare

    ; New row → reset gap-fill last-col tracker so the first char on this
    ; row doesn't gap-fill from the prior row's last col. Also reset the
    ; dedup-blank shift counter so this row starts unshifted.
    SEP #$20
    LDA.B #$FF
    STA.L !VWF_LAST_COL
    LDA.B #$00
    STA.L !VWF_TM_OFFSET
    REP #$20

    ; Step 3b — re-arm FIRST_SAVX sentinel on row change so VWFDedupeRow
    ; (PostRender) scans only the row containing the LAST char. Multi-row
    ; emits dedupe only that final row; earlier rows are untouched. The
    ; next .tilemapWrite on the new row will recapture FIRST_SAVX = SAVX.
    LDA.W #$FFFF
    STA.L !VWF_FIRST_SAVX
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

    ; R1.F-9: clear any pending dedup-blank shift before crossing the col-jump.
    ; If the prior char on this row hit the WB dedup discard path,
    ; VWF_TM_OFFSET is non-zero and would shift the NEXT tilemap write LEFT by
    ; (offset * 2) bytes — but the col-jump just re-anchored us elsewhere on
    ; the row, so the shift would land at a stale offset and clobber an
    ; unrelated cell. The shift was scoped to the run between the discard
    ; and the next emit at the same engine col; a col-jump invalidates it.
    SEP #$20
    LDA.B #$00 : STA.L !VWF_TM_OFFSET
    REP #$20
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

    LDA.L !VWF_CHAR                         ; reload char value (full 16-bit)
    ; R1.F-15: NO AND.W #$00FF here. Icon tile_ids ($180-$1FF, emitted by
    ; engine textStream_HandleD0 via ADC #$0180) need their high bit
    ; preserved or the tilemap entry references the wrong tile (e.g.
    ; tile $185 → tile $85 = font glyph instead of chrome icon). The mask
    ; was a no-op for the other .doOrig entry paths (sub-$20 / $F0-$FF /
    ; saturation / pool-exhausted) since their chars fit in 8 bits anyway,
    ; and is harmful for the chars-≥-$100 path.
    CLC : ADC.W $0A02                       ; + palette/priority (16-bit add preserves high bit)
    PHA                                     ; save composed top word
    STA.L $7E9000,X                         ; top tilemap entry at VWF col
    PLA                                     ; restore
    CLC : ADC.W #$0400                      ; + palette-row offset for bot
    STA.L $7E9040,X                         ; bot tilemap entry at VWF col
    ; Update LAST_COL so subsequent VWF chars don't gap-fill over this
    ; .doOrig-written tilemap entry. The .doOrig wrote engine's char
    ; tile_id at the pen-snapped col; we want gap-fill to treat $09FC
    ; (engine col) as "already written" so it skips this cell.
    SEP #$20
    LDA.W $09FC
    STA.L !VWF_LAST_COL
    REP #$20

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

    ; Width 0 (e.g. space, or width-0 control chars the engine emits
    ; between visible chars for original Japanese spacing — these are
    ; leftover JP kana that didn't get translated, like $D2=イ, $D5=オ,
    ; $DC=シ, etc.). Don't render. Tilemap entry = tile $20 (canonical
    ; blank, properly polarity-filled by SceneInit) + palette. This is
    ; the "missing AND" — without pointing at tile $20, the cell would
    ; reference tile $00 (engine default) which has no polarity wipe and
    ; can show stale chrome content.
    LDA.L !VWF_SAVX                         ; load via A (LDX.L unsupported)
    TAX                                     ; restore tilemap byte offset
    LDA.W $0A02                             ; current palette/priority bits
    CLC : ADC.W #!VWF_BLANK_TILE_ID         ; + tile $20 (canonical blank)
    STA.L $7E9000,X                         ; top tilemap entry
    CLC : ADC.W #$0400                      ; +palette-row offset for bot
    STA.L $7E9040,X                         ; bot tilemap entry

    ; Update LAST_COL so subsequent gap-fill doesn't think this cell is a
    ; gap. Without this, width-0 control chars between visible chars
    ; (engine-side spacing artifacts) cause gap-fill from the next visible
    ; char to write tile $20 over THIS cell — same visual outcome as the
    ; width-0 path would produce, but the issue is gap-fill ALSO fires
    ; whenever sequential width-0+VWF char pairs occur, inserting an
    ; extra blank cell mid-text.
    SEP #$20
    LDA.W $09FC
    STA.L !VWF_LAST_COL
    REP #$20

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

    ; Row index — polarity-branched.
    ;
    ; BB dialog: canvas_row = ($09FE >> 1) & 7. Pre-Phase-A behavior;
    ;   BB rendering historically worked correctly with this source.
    ;   Switching BB to SAVX broke rasterization (root cause TBD —
    ;   user-attested "this worked before"). Preserved per polarity
    ;   branch.
    ;
    ; WB menus: canvas_row = (SAVX >> 6) mod 7. Engine masks $09FE to
    ;   5 bits (docs/control_codes.md §4), so 4-slot menus' distinct
    ;   engine rows collapse to identical $09FE values → all slots hash
    ;   to same canvas_row → cross-slot tile_id collision. SAVX (engine
    ;   tilemap byte offset) preserves true engine_row. Mod 7 caps
    ;   canvas_row at 6 to keep tile_id in $20..$FF (no chrome overflow).
    ;
    ; Each polarity is internally consistent: TMP_BASE (canvas write pos)
    ; and tile_id formula both read TMP_ROW so they always pick the
    ; same canvas slot/tile. PreRender's full canvas wipe handles
    ; cross-emit canvas freshness regardless of canvas_row source.
    SEP #$20
    LDA.L !VWF_INVERT
    REP #$20
    BEQ .bbRowSrc                           ; BB → $09FE>>1 & 7
    ; WB: canvas_row = (SAVX >> 6) mod 7
    LDA.L !VWF_SAVX
    LSR A : LSR A : LSR A
    LSR A : LSR A : LSR A                   ; /64 → engine_row (0..31)
.rowMod7:
    CMP.W #$0007
    BCC .rowDone
    SBC.W #$0007                            ; CMP set C=1 when A>=7, SBC clean
    BRA .rowMod7
.bbRowSrc:
    LDA.W $09FE
    LSR A : AND.W #$0007                    ; ($09FE>>1) & 7
.rowDone:
    STA.L !VWF_TMP_ROW                      ; canvas row index 0..7 (BB) / 0..6 (WB)

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
    LDA.L !VWF_TMP_COL                               ; col (pen_col)
    ASL A : ASL A : ASL A : ASL A           ; col << 4 (multiply by 16)
    CLC : ADC.L !VWF_TMP_BASE                         ; add row*512
    STA.L !VWF_TMP_BASE                               ; $0A = canvas tile byte offset

    ; --- Phase A: WB allocator dropped (2026-05-09) ----------------------
    ; The variable-width pool allocator (LEFTMOST + PRIMARY pen-tile-keyed
    ; CELL_TILE lookup, POOL_NEXT advancement, dedup-blank discard,
    ; .tmShiftX shifted writes) is gone. Both polarities now use the
    ; formula tile_id below (.bbTileFormula): tile_id = $20 + row*32 +
    ; $09FC. Each engine col gets a deterministic tile_id; no cross-emit
    ; sharing, no end-of-emit kerning loss.
    ;
    ; Kerning still works visually: chars whose pen-tile shares a canvas
    ; slot OR-merge (BB) or AND-NOT-merge (WB) into the shared canvas
    ; bytes via sub-pixel shift + spill (existing rendering loop below).
    ; Trailing engine cols whose canvas was never written display as
    ; canvas-default (BB: $0000 = black BG; WB: $FFFF = white BG) — same
    ; as the surrounding background, so visually invisible.
    ;
    ; Phase D adds a trailing-blank scan to skip DMA'ing those untouched
    ; tiles, but until then the full canvas DMAs harmlessly.
    ;
    ; TMP_BASE remains its formula value (set at line 972: row*512 +
    ; TMP_COL*16). Kerning-overlap via TMP_BASE = pen-tile canvas pos.
    ; TMP_TILE_ID is now inert (no consumer; .haveTileId tile_id source
    ; is unconditional formula).
    ; --------------------------------------------------------------------

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
    ; (M=8 entry from .skipWrite paths above.)
    LDA.L !VWF_TMP_SHIFT                               ; shift (low byte read)
    BEQ .noSpill                            ; no shift → no spill
    LDA.L !VWF_TMP_ORIG                               ; original (un-shifted) font byte
    BEQ .noSpill                            ; original is blank → nothing to spill

    ; spill = original << (8 - sub_x)
    ; F-7: removed redundant SEP #$20 — the .skipWrite predecessors above
    ; all leave M=8, so this block already runs in 8-bit mode.
    LDA.B #$08                              ; constant 8 (M=8 already)
    SEC : SBC.L !VWF_TMP_SHIFT                         ; A = 8 - shift
    REP #$20                                ; 16-bit for AND/TAX
    AND.W #$00FF                            ; clean high byte
    TAX                                     ; X = left-shift count (always 1..8 — never 0)
    SEP #$20                                ; back to 8-bit
    LDA.L !VWF_TMP_ORIG                               ; original font byte
    ; F-7: removed dead `CPX #$0000 : BEQ .noSL` — TMP_SHIFT in {1..7} via
    ; the BEQ guards above (line LDA TMP_SHIFT : BEQ .noSpill), so
    ; X = 8 - shift is always in {1..7} and the loop always executes at
    ; least once.
.slLoop:
    ASL A : DEX : BNE .slLoop               ; shift left X times
    STA.L !VWF_TMP_SHFT                               ; $0F = spill byte
    CMP.B #$00                              ; STA doesn't set flags — re-test for zero
    BEQ .noSpill                            ; spill is 0 → nothing to write

    ; Spill destination = saved canvas pos + 16 (next cell, same plane).
    ; Cell stride is 16 bytes in 1bpp-IL canvas, so pos+16 lands in the SAME
    ; plane byte (bp0 if we were writing bp0, bp1 if bp1) of the next cell.
    REP #$20                                ; 16-bit for ADC
    LDA.L !VWF_TMP_POS : CLC : ADC.W #$0010          ; pos + 16 (next cell, same plane)
    CMP.W #!CANVAS_SIZE                     ; bounds: must stay inside 4 KB canvas
    BCS .noSpill                            ; out of bounds → drop the spill (M=16 join — F-8)
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
    BRA .noSpill2

.noSpill:                                   ; F-8: SEP #$20 was redundant; .rowLoop /
                                            ; .doneRows each force their own M state.
                                            ; INY / CPY use the X flag.  M=16 entry
                                            ; from BCS bounds-check is safe.
.noSpill2:
    INY                                     ; next pixel row
    CPY.W #$0010                            ; rendered all 16 rows?
    BCS .doneRows                           ; yes → exit the row loop
    JMP .rowLoop                            ; continue with next row

.doneRows:
    ; --- Update DMA_LO/HI bounds for the canvas → VRAM upload ----------
    ; Phase A: BOTH polarities use end-of-row HI (same as historical BB).
    ; WB previously used per-cell HI (TMP_BASE + 16) because the pool
    ; allocator made canvas sparse — row-end extension would DMA over
    ; the cursor canvas range and unallocated slots. With the pool
    ; allocator gone, canvas is pen-tile-based (dense in active row),
    ; so end-of-row DMA correctly clears trailing VRAM tile slots from
    ; prior emits with the canvas-default polarity fill (BG-matching,
    ; visually invisible). The cursor-tile preservation lives in
    ; VWFNMI's two-chunk DMA (which still runs for WB).
    ;
    ; LOAD-BEARING: Step 10 (2026-05-10) tried tightening to TMP_BASE+$20
    ; and caused full regression on both polarities (BB static garbage,
    ; BB typewriter end-of-line garbage, WB missing lines + garbage).
    ; Mid-emit NMI DMAs see tilemap entries pointing at VWF tile_ids
    ; before the rasterizer rewrites them or PostRender dedupe runs;
    ; if those VRAM slots aren't pre-cleared via this row-end fill,
    ; stale prior-emit content is displayed.
    REP #$20                                ; M=16 for word compares
    LDA.L !VWF_TMP_BASE                     ; current cell canvas start
    CMP.L !VWF_DMA_LO
    BCS .lo_keep
    STA.L !VWF_DMA_LO                       ; new LO
.lo_keep:
    LDA.L !VWF_TMP_ROW
    INC A                                   ; (row+1)
    XBA                                     ; (row+1) << 8
    ASL A                                   ; (row+1) * 512 — end-of-row byte
    CMP.L !VWF_DMA_HI
    BCC .hi_keep
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

    ; --- Step 2: tile_id source — formula for both polarities (Phase A) -
    ; tile_id = $20 + row*32 + $09FC. Each engine col gets a deterministic,
    ; unique tile_id. Canvas writes go to PEN-tile slot (TMP_BASE) via
    ; sub-pixel-shifted rasterization; tilemap entries point at engine-col
    ; slots. PEN and engine col can diverge for variable-width chars —
    ; that's the kerning visual: chars at later engine cols whose canvas
    ; was never written display as canvas-default (matches BG color, so
    ; visually invisible).
    REP #$20                                ; M=16 for tile_id math
    LDA.L !VWF_TMP_ROW
    AND.W #$0007
    ASL A : ASL A : ASL A : ASL A : ASL A   ; row * 32
    CLC : ADC.W $09FC                       ; + col
    CLC : ADC.W #!VWF_TILE_BASE             ; + $20 → formula tile_id

.haveTileId:                                ; ENTRY: M=16, A=tile_id, X-on-stack from .normalTilemap PHX
    ; --- WB-only dedup-blank discard ----------------------------------
    ; In WB, when the per-row pen-tile allocator decides this engine col's
    ; content is already merged into a neighbor's tile (LEFTMOST reused,
    ; no spill), TMP_TILE_ID was set to $20. That blank was never intended
    ; data — discard it (no tilemap write) and bump VWF_TM_OFFSET so the
    ; NEXT non-blank emit writes into the slot we just skipped, instead of
    ; leaving a visible blank in the middle of the line.
    ;
    ; Pen advance still happens (we still consumed the engine col), so we
    ; jump to .penAdvance after popping the saved X.
    PHA                                     ; preserve A (tile_id) across SEP/REP M-flag flips
    SEP #$20
    LDA.L !VWF_INVERT
    REP #$20
    BEQ .tmDoneCheck                        ; BB → no dedup discard, no shift
    PLA                                     ; restore A = tile_id
    PHA                                     ; re-save (16-bit M=16)
    CMP.W #!VWF_BLANK_TILE_ID
    BNE .tmShiftX                           ; non-blank: shift X and write
    ; Dedup-blank: discard.
    PLA                                     ; pop saved tile_id (unused)
    PLX                                     ; pop saved X (unused — no write)
    SEP #$20
    LDA.L !VWF_TM_OFFSET
    INC A
    STA.L !VWF_TM_OFFSET
    LDA.B #$A5                              ; Bug-B fix: arm flush flag for PostRender
    STA.L !VWF_LAST_DISCARD
    REP #$20
    JMP .penAdvance                         ; skip tilemap write, still advance pen

.tmDoneCheck:
    PLA                                     ; restore A = tile_id (BB or non-WB)
    PLX                                     ; restore SAVX (no shift)
    BRA .tilemapWrite

.tmShiftX:
    ; WB non-blank: write at X' = SAVX - VWF_TM_OFFSET * 2.
    ; Stack on entry: [savX (bottom), tile_id (top)] — TWO items.
    ; PLX would pop the TOP (tile_id), so pop tile_id with PLA first,
    ; THEN PLX to get savX. Save tile_id in scratch (TMP_FBI) so we
    ; can use A for the offset*2 math below.
    PLA                                     ; A = tile_id (top of stack)
    STA.L !VWF_TMP_FBI                      ; stash tile_id in scratch
    PLX                                     ; X = SAVX (now top)
    SEP #$20
    LDA.L !VWF_TM_OFFSET
    REP #$20
    AND.W #$00FF
    ASL A                                   ; A = offset * 2
    ; A = offset*2. Apply X -= A.
    PHA                                     ; push offset*2 for stack-relative SBC
    TXA
    SEC : SBC $01,S                         ; A = SAVX - offset*2
    TAX                                     ; X = adjusted tilemap byte offset
    PLA                                     ; pop offset*2 (discard)
    LDA.L !VWF_TMP_FBI                      ; restore A = tile_id
    ; Fall through to .tilemapWrite (M=16, A=tile_id, X=SAVX-offset*2)

.tilemapWrite:                              ; ENTRY: M=16, A=tile_id, X=tilemap byte off
    ; Step 3a — capture FIRST_SAVX on first .tilemapWrite per emit/row.
    ; FIRST_SAVX sentinel $FFFF is set by VWFPreRender (per emit) and by
    ; CharHandler's row-change branch (per row). On match, store current X
    ; (= tilemap byte offset) so PostRender's VWFDedupeRow has a valid
    ; "first-col" anchor for the row scan.
    PHA                                     ; preserve A=tile_id during check
    LDA.L !VWF_FIRST_SAVX
    CMP.W #$FFFF
    BNE .tmFirstCaptured
    TXA                                     ; X = tilemap byte offset (= SAVX)
    STA.L !VWF_FIRST_SAVX
.tmFirstCaptured:
    PLA                                     ; restore A=tile_id

    PHA                                     ; save tile_id for bot
    CLC : ADC.W $0A02                       ; + palette/priority bits
    STA.L $7E9000,X                         ; write TOP tilemap entry
    PLA                                     ; restore tile_id (NO INC — same tile_id)
    CLC : ADC.W $0A02                       ; + palette/priority bits
    CLC : ADC.W #$0400                      ; + palette-row offset for bottom
    STA.L $7E9040,X                         ; write BOTTOM tilemap entry (same tile)
    ; Bug-B fix: a real tilemap entry was just written → cancel any pending
    ; flush request from a prior discard-blank in this emit. (Each emit's
    ; flush should target the CURRENT trailing discard, not an old one
    ; that's already been absorbed by the shifted write above.)
    SEP #$20
    LDA.B #$00 : STA.L !VWF_LAST_DISCARD
    REP #$20

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
    ; Two-tier reset (R3.F-Y / R3.F-Z):
    ;   INVERT (polarity) flip → JSL VWFRequestSceneInit
    ;     - True scene change.  Resets allocator state AND queues the
    ;       per-NMI VRAM polarity wipe (chunk 1 / chunk 2 sequence).
    ;   TEXT_LO/HI/BNK change → JSL VWFRequestPageReset
    ;     - Dialog page advance (fillTextBuffer fired since last emit).
    ;       Resets canvas + CELL_TILE + POOL_NEXT so the new page's
    ;       glyphs allocate fresh tile_ids and write to clean canvas
    ;       slots (otherwise WB pool keeps incrementing past $FF and
    ;       CELL_TILE serves stale tile_ids whose canvas slots still
    ;       hold prior page's pixels — visible as OR/AND-merged
    ;       garbled glyphs).  Does NOT queue the VRAM wipe; the engine
    ;       has already cleared the dialog tilemap to blank tile $100,
    ;       so the prior page's VRAM tile data is unreferenced and the
    ;       new emit's canvas DMA overwrites the slots it allocates.
    ;
    ; All compares are 8-bit (M=8 already set above).
    LDA.L !VWF_INVERT      : CMP.L !VWF_LAST_INVERT   : BNE .needSceneInit
    LDA.L !VWF_TEXT_LO     : CMP.L !VWF_LAST_TEXT_LO  : BNE .textChanged
    LDA.L !VWF_TEXT_HI     : CMP.L !VWF_LAST_TEXT_HI  : BNE .textChanged
    LDA.L !VWF_TEXT_BNK    : CMP.L !VWF_LAST_TEXT_BNK : BEQ .sceneSame
.textChanged:
    ; Phase 4b Option D: TEXT_LO/HI/BNK changed, but only PageReset if
    ; VWFClsHook fired since last emit (= dialog page advance / scene
    ; pop / sub-menu open|close). Otherwise this is a menu sub-string
    ; emit (each name/class/stat field is a separate JSR-driven emit
    ; with its own text source pointer). Preserve allocator state so
    ; multi-emit menus don't recycle the same low tile_ids across slots.
    ;
    ; Audit data (2026-05-08): cls fires for unit-info exit, dialog
    ; page-advance, dialog close, sub-menu open/close. Does NOT fire for
    ; re-entering screens, file-info navigation, or sub-string emits
    ; within a menu render.
    ; M=8 byte gate. EOR-trick: A := A ^ $A5 — if A was $A5, result = $00
    ; (Z set, A=0); otherwise non-zero (Z clear). Saves 2 bytes vs LDA+CMP+
    ; BNE+LDA#0+STA path because STA reuses the now-zero A.
    LDA.L !VWF_CLS_PENDING
    EOR.B #$A5
    BNE .updateLastTextOnly                 ; A!=0 ⇒ flag wasn't $A5 ⇒ suppress
    STA.L !VWF_CLS_PENDING                  ; A=0 ⇒ consume one-shot to $00
.needPageReset:
    REP #$20                                ; M=16 for JSL boundary
    JSL.L VWFRequestPageReset               ; canvas + CELL_TILE + POOL_NEXT only
                                            ; (also updates LAST_TEXT_*)
    SEP #$20
    BRA .sceneSame
.updateLastTextOnly:
    ; Phase 4b refinement (post initial-Option-D regression): "lite reset"
    ; — full PageReset (wipes canvas + CELL_TILE, updates LAST_TEXT_*,
    ; clears DIRTY/LAST_COL), but preserves POOL_NEXT across emits so each
    ; emit gets unique tile_ids (avoids tile_id reuse / canvas-pos
    ; collision visible as cross-emit leakage). Without the CELL_TILE
    ; wipe here, prior emit's stale entries served as "reuse" for cells
    ; that THIS emit re-keys — the new char's pixels would land at the
    ; PRIOR emit's canvas pos, corrupting prior tile content.
    JSR.W VWFLiteReset                      ; same-bank near call
    BRA .sceneSame
.needSceneInit:
    REP #$20                                ; M=16 for JSL boundary
    JSL.L VWFRequestSceneInit               ; full reset + queue VRAM wipe
                                            ; (clears CLS_PENDING via VWFResetState)
    SEP #$20                                ; M=8 for byte stores below
.sceneSame:

    ; --- Phase 1 — scene fingerprint capture -----------------------------
    ; (See state-block header at $5D40 for layout details.)
    ; Stack at this point (inside VWFPreRender, called via JSL from
    ; $80:BC75): $01,S..$03,S = JSL ret; $04,S..$05,S = caller's JSR ret.
    REP #$20                                 ; M=16 to read 2-byte caller ret
    LDA $04,S
    STA.L !VWF_SCENE_TAG                     ; +0..+1 caller PC fingerprint
    SEP #$20                                 ; back to M=8
    LDA.L !VWF_INVERT
    STA.L !VWF_SCENE_TAG+2                   ; +2 polarity
    LDA.W $0A1F : AND.B #$7F : ORA.L !VWF_INVERT
    STA.L !VWF_SCENE_TAG+3                   ; +3 composite scene byte

    ; --- Phase 2 — re-emit detection -------------------------------------
    ; Helper computes buffer XOR-fold signature, compares (SCENE_TAG,
    ; sig) to LAST_*, sets !VWF_REGEN_ONLY = $A5 on cache hit, and
    ; updates LAST_* slots.  Factored out so PreRender stays under its
    ; warnpc bound. M=8 entry/exit.
    JSR.W VWFCheckReEmit                     ; same-bank near call

    ; --- Phase 3 step 1 — slice LRU assignment (instrumentation) ---------
    ; Helper looks up SCENE_TAG in 3-slot LRU. Sets !VWF_SCENE_SLICE to
    ; the matching slot (hit) or to the next round-robin slot (miss,
    ; advancing LRU_NEXT and writing SCENE_TAG into the chosen slot).
    ; No allocator consumer yet — verification only at this step.
    JSR.W VWFAssignSlice                     ; same-bank near call

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
    LDA.B #$00 : STA.L !VWF_TM_OFFSET       ; reset dedup-blank shift counter
    REP #$20                                ; back to 16-bit

    ; Reset dirty-range bounds for this emit. NMI uploads nothing if
    ; no char gets rendered between now and next vblank.
    LDA.W #$FFFF
    STA.L !VWF_DMA_LO                       ; sentinel "no range yet"
    STA.L !VWF_FIRST_SAVX                   ; sentinel: PostRender dedupe
                                            ;   "no FIRST_SAVX captured yet"
    STA.L !VWF_MAX_SLOT                     ; Path B: sentinel "no rasterizer
                                            ;   writes yet" (A still $FFFF)
    LDA.W #$0000
    STA.L !VWF_DMA_HI

    ; Step B3 (REVERTED 2026-05-10): pre-clearing the entire engine_row at
    ; PreRender clobbers OTHER emits' tilemap entries on the same row.
    ; Unit-info has multiple emits per row (name, class, stats). Emit B's
    ; pre-clear wiped emit A's content → visible bleed (e.g., slot 4 class
    ; label rendered as "DkAmberUser" with leftover chars from prior emit).
    ; Path B needs a SCOPED clear — only the cells THIS emit writes, or
    ; only the trailing cells past the LAST char — not the entire row.

    ; -----------------------------------------------------------------------
    ; Canvas clear — polarity-gated:
    ;   BB: partial wipe from current pen pos onwards (pre-Phase-A behavior).
    ;       Tiles BEHIND the pen hold previously-rendered chars in this page
    ;       (their tilemap entries are still on screen, so their tile bytes
    ;       must persist across the per-frame PreRender→processText→
    ;       PostRender cycle that drives typewriter dialog rendering).
    ;       Tiles AT or AFTER the pen are about to be (re)written by this
    ;       emit, so they need a fresh start.
    ;   WB: full canvas wipe from $0. WB menu emits are independent (each
    ;       scene re-paints from scratch) so partial wipe leaks stale data
    ;       under SAVX-derived canvas_row source. Full wipe removes the
    ;       canvas_row consistency requirement for WB.
    ;
    ; offset = row * 512 + col * 16   (matches CharHandler's TMP_BASE calc)
    ;   row = ($09FE >> 1) & 7  (BB's canvas_row source)
    ;   col = $09FC
    ; -----------------------------------------------------------------------
    SEP #$20
    LDA.L !VWF_INVERT
    REP #$20
    BEQ .partialWipeStart                   ; BB → partial wipe from pen pos
    ; WB: full wipe from canvas start
    LDX.W #$0000
    BRA .preFillCheckPolarity
.partialWipeStart:
    LDA.W $09FE                             ; text row source word
    LSR A : AND.W #$0007                    ; row index 0..7
    XBA                                     ; row << 8
    ASL A                                   ; row << 9 = * 512 (max 7*512=$0E00)
    STA.L !VWF_TMP_BASE                     ; partial: row * 512
    LDA.W $09FC                             ; col index
    AND.W #$001F                            ; clamp 0..31 defensively
    ASL A : ASL A : ASL A : ASL A           ; col * 16
    CLC : ADC.L !VWF_TMP_BASE               ; + row * 512
    TAX                                     ; X = canvas byte offset to start
.preFillCheckPolarity:

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

warnpc $E09030                              ; VWFPreRender must end before VWFPostRender (bumped +$10 cascade for Path B Step B3 row pre-clear)

; ----------------------------------------------------------------------------
; VWFPostRender — called after processText
; Bulk-uploads the entire canvas to VRAM (forced blank, NMI off), clears the
; VWF flag, then carries the displaced bytes (REP #$20 / LDA $0A16) so the
; original code resumes byte-identically.
;
; Org bumped from $E08FE0 → $E09000 (Phase 1, scene-aware cache plan) to
; give VWFPreRender room for fingerprint capture; subsequent phases add
; more PreRender code. Bumped again $E09000 → $E09010 (Phase A polarity-
; gated wipe) for partial-vs-full wipe selector. Bumped again $E09010 →
; $E09020 for FIRST_SAVX sentinel init (PostRender dedupe Step 2).
; Bumped again $E09020 → $E09030 for Path B Step B3 (PreRender row pre-clear).
; ----------------------------------------------------------------------------
org $E09030

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

    ; Phase 2 — commit cache: this emit's CELL_TILE/canvas state is now
    ; live and reusable. Next emit's PreRender compares (SCENE_TAG,
    ; LAST_BUF_SIG) and skips rasterization on a hit.
    LDA.B #$A5 : STA.L !VWF_CACHE_VALID

    ; Step 5 — single-row tilemap dedupe. Helper scans the last row of this
    ; emit ([FIRST_SAVX..VWF_SAVX]) and rewrites all-blank canvas tiles to
    ; canonical blank tile_id. Step 5 wires plumbing only; helper is
    ; RTS-only until Steps 6→8b add logic.
    JSR.W VWFDedupeRow

    ; Bug-B fix-attempt #1 (REVERTED 2026-05-09): VWFPostFlush JSR was here.
    ; The fix didn't address the actual bug — most "missing" trailing
    ; class chars come from .tmShiftX consuming TM_OFFSET on the right
    ; edge (not from a trailing discard), so the flush condition
    ; (LAST_DISCARD==$A5) was never true on unit-info. On screens where
    ; it DID fire, it wrote LEFTMOST_TID at SAVX duplicating the prior
    ; cell's content (user observed "extra repeat of last tile").
    ; State slots LAST_LEFTMOST_TID + LAST_DISCARD remain in code as
    ; instrumentation but no consumer wired up.

.done:
    REP #$20                                ; displaced: 16-bit mode
    LDA.W $0A16                             ; displaced: load text-engine state word
    RTL                                     ; long-return — caller's NOPs follow harmlessly

warnpc $E09060                              ; VWFPostRender must end before VWFClsHook (bumped +$10 cascade for Path B B3)

; ----------------------------------------------------------------------------
; VWFClsHook — called from $80:C022 in place of JSL initTilemapAndSync_Long.
; Runs the original clear+sync, then resets canvas + sentinels so the next
; text page renders without leftover pixels merging into new glyphs.
; The VRAM tile range itself does NOT need clearing: initTilemapAndSync_Long
; rewrites the tilemap to point at blank tiles, so any tilemap entry not
; touched by the new page references blanks rather than stale VWF tiles.
;
; Org bumped from $E0:9000 → $E0:9030 (Phase 1, scene-aware cache plan)
; to clear room for VWFPostRender's new home at $E09000. Bumped again
; $E09030 → $E09040 (Phase A) and $E09040 → $E09050 (FIRST_SAVX sentinel).
; Bumped again $E09050 → $E09060 (Path B Step B3 cascade).
; ----------------------------------------------------------------------------
org $E09060

; ENTRY: M=16 (caller convention from $80:C022 is M=16 mid-text-stream).
; EXIT:  M=16 (RTL preserves carrier P state).
VWFClsHook:
    JSL.L $81ECE1                           ; run displaced original (initTilemapAndSync_Long)
    JSL.L VWFRequestSceneInit               ; canvas wipe, CELL_TILE reset, queue VRAM wipe
    LDA.W #$FFFF                            ; M=16 — sentinel
    STA.L !VWF_ROW                          ; force per-row reinit on first char post-cls
    ; Phase 4b Option D: arm cls-pending flag so the next VWFPreRender
    ; runs PageReset on TEXT_*-change. Without this flag set, PreRender
    ; preserves POOL_NEXT/CELL_TILE across emits (correct for menu
    ; sub-string emits that don't go through cls).
    SEP #$20                                ; M=8 for byte store
    LDA.B #$A5 : STA.L !VWF_CLS_PENDING
    REP #$20                                ; restore M=16 per exit contract
    RTL                                     ; long-return to game caller

; ----------------------------------------------------------------------------
; VWFLiteReset — Phase 4b Option D refinement helper.
;
; "Lite reset" = full VWFRequestPageReset (wipes canvas + CELL_TILE, updates
; LAST_TEXT_*, clears DIRTY / LAST_COL), but POOL_NEXT is saved across the
; reset so each emit-after-suppression continues allocating UNIQUE tile_ids
; instead of restarting from slice_first.
;
; Why this is necessary:
;   - Wipes are needed to prevent cross-emit CELL_TILE reuse pointing into
;     prior emit's canvas slots (corrupts prior emit's tilemap entries).
;   - POOL_NEXT preservation is needed so 11 menu sub-string emits don't
;     all hammer the same low tile_ids (the original bug).
;
; ENTRY: M=8 (caller is VWFPreRender's .updateLastTextOnly branch).
; EXIT:  M=8, X-state caller-restored by VWFRequestPageReset's PLP.
; ----------------------------------------------------------------------------
VWFLiteReset:
    REP #$20                                ; M=16 for word save/restore
    LDA.L !VWF_POOL_NEXT
    PHA                                     ; save POOL_NEXT (16-bit)
    JSL.L VWFRequestPageReset               ; full reset (clobbers POOL_NEXT to $21)
    PLA                                     ; restore POOL_NEXT
    STA.L !VWF_POOL_NEXT
    SEP #$20                                ; back to M=8 per exit contract
    RTS

; ----------------------------------------------------------------------------
; VWFPostFlush — Phase 4b Bug-B fix.
;
; Called from VWFPostRender (M=8). If LAST_DISCARD == $A5, the last char
; processed in this emit hit the dedup-blank discard path — its content was
; rasterized into LEFTMOST's canvas slot but the trailing engine col was
; left unwritten. Write a final tilemap entry at VWF_SAVX referencing
; LAST_LEFTMOST_TID so the trailing col displays the kerned content.
;
; Consumes LAST_DISCARD on use (one-shot per emit).
;
; ENTRY: M=8.  Caller: VWFPostRender after FLAG/DIRTY/CACHE_VALID setup.
; EXIT:  M=8.  RTS (same-bank near call).
; ----------------------------------------------------------------------------
VWFPostFlush:
    LDA.L !VWF_LAST_DISCARD
    CMP.B #$A5
    BNE .skip                               ; no pending discard → nothing to do
    LDA.B #$00 : STA.L !VWF_LAST_DISCARD    ; consume one-shot
    REP #$20                                ; M=16 for tilemap word write
    LDA.L !VWF_LAST_LEFTMOST_TID
    CLC : ADC.W $0A02                       ; + palette/priority bits
    PHA                                     ; save composed top
    LDA.L !VWF_SAVX                         ; engine tilemap byte offset
    TAX
    PLA
    STA.L $7E9000,X                         ; write TOP tilemap entry
    CLC : ADC.W #$0400                      ; + palette-row offset for bottom
    STA.L $7E9040,X                         ; write BOTTOM tilemap entry
    SEP #$20                                ; back to M=8 per exit contract
.skip:
    RTS

; ----------------------------------------------------------------------------
; VWFTrailingRowClear — Path B Step B2.
;
; Writes canonical $20 + palette to all 32 tilemap entries (both TOP and
; BOTTOM rows) for an engine row. Called from PreRender (Step B3) and
; CharHandler's row-change branch (Step B4) to pre-clear trailing tilemap
; entries before the rasterizer overwrites them per char. After the emit,
; cells past the last rendered char remain canonical $20 — so the upcoming
; DMA_HI tightening (Step B6) is safe (stale VRAM at trailing VWF tile_ids
; isn't referenced by the now-canonical trailing tilemap entries).
;
; ENTRY: M=16. A = row tilemap byte base (= engine_row * 64). Caller saved
;        A/X/Y as needed. This helper clobbers A, X, Y.
; EXIT:  M=16. RTS (same-bank near call).
;
; Loop body pre-computes TOP / BOTTOM composed values once to avoid
; per-iteration SEC/SBC of the palette-row offset.
; ----------------------------------------------------------------------------
VWFTrailingRowClear:
    TAX                                     ; X = row tilemap byte base
    LDY.W #$0020                            ; 32 cells per row
    LDA.W #!VWF_BLANK_TILE_ID
    CLC : ADC.W $0A02                       ; canonical blank + palette/priority (TOP)
    STA.L !VWF_TMP_FBI                      ; cache TOP composed word
    CLC : ADC.W #$0400                      ; + palette-row offset (BOTTOM)
    STA.L !VWF_TMP_W                        ; cache BOTTOM composed word
.clrLoop:
    LDA.L !VWF_TMP_FBI
    STA.L $7E9000,X                         ; TOP tilemap entry
    LDA.L !VWF_TMP_W
    STA.L $7E9040,X                         ; BOTTOM tilemap entry
    INX : INX                               ; next cell (2 bytes per entry)
    DEY
    BNE .clrLoop
    RTS

; ----------------------------------------------------------------------------
; VWFDedupeRow — PostRender single-row tilemap dedupe (Step 4: stub).
;
; For each tile in the row [FIRST_SAVX..VWF_SAVX] inclusive, check whether
; its canvas tile is fully blank polarity-fill. If so, rewrite both TOP
; and BOTTOM tilemap entries to canonical blank tile $20 so the engine
; serves the chrome/blank layer at that cell instead of an all-blank VWF
; tile (reduces VRAM duplication and avoids overwriting chrome cells the
; engine wrote in cursor-jump gaps).
;
; "Current row only": FIRST_SAVX is reset to sentinel on emit start
; (PreRender) and on row change (CharHandler). PostRender invokes this
; helper after CACHE_VALID is set, before .done — so the most recent row
; of the just-completed emit is what gets scanned.
;
; ENTRY: M=8. Caller: VWFPostRender post-CACHE_VALID, pre-.done.
; EXIT:  M=8. Near-call (RTS).
;
; Step 6 — sentinel-check only. If no .tilemapWrite captured FIRST_SAVX
; this emit (every char hit a skip path, or VWF_FLAG was $00 so PreRender
; ran but processText emitted no chars at all), the sentinel $FFFF is
; still in place — bail out fast. Steps 7→8b add the canvas-scan +
; tilemap-rewrite body inside the BEQ-fall-through path.
; ----------------------------------------------------------------------------
VWFDedupeRow:
    REP #$20                                ; M=16 for word ops
    LDA.L !VWF_FIRST_SAVX
    CMP.W #$FFFF
    BNE +
    BRL .exit                               ; sentinel intact → nothing to dedupe
+

    ; Defensive: backward cursor jumps (FF nn col-jump) could leave
    ; VWF_SAVX < FIRST_SAVX. Skip scan in that case (handle in a later
    ; phase if needed).
    CMP.L !VWF_SAVX
    BEQ .rangeOK                            ; FIRST == SAVX → single cell
    BCC .rangeOK                            ; FIRST < SAVX → forward range
    BRL .exit                               ; FIRST > SAVX → backward jump, skip
.rangeOK:

    ; Step 7 polarity gate: WB only (Step 8b drops the gate for BB).
    SEP #$20
    LDA.L !VWF_INVERT
    BNE +
    BRL .exit_m8                            ; BB → skip dedupe
+
    REP #$20

    ; canvas_row = (FIRST_SAVX >> 6) mod 7  — matches WB rasterizer source.
    ; engine_row = FIRST_SAVX >> 6 (tilemap stride 64 = 32 cells × 2 B).
    LDA.L !VWF_FIRST_SAVX
    LSR A : LSR A : LSR A
    LSR A : LSR A : LSR A                   ; A = engine_row (0..31)
    AND.W #$001F                            ; defensive: 5-bit $09FE mask
.mod7:
    CMP.W #$0007
    BCC .modDone
    SEC : SBC.W #$0007
    BRA .mod7
.modDone:
    ; A = canvas_row (0..6). row_base = canvas_row * 512.
    XBA                                     ; A = canvas_row << 8
    ASL A                                   ; A = canvas_row << 9 = * 512
    STA.L !VWF_TMP_BASE                     ; row_base byte offset

    ; Loop end (exclusive) = VWF_SAVX + 2 so SAVX==VWF_SAVX still processes.
    ; (REVERTED 2026-05-10: tried extending to row_end, but trailing cells
    ; past VWF_SAVX belong to sibling emits' content / right-margin chrome.
    ; Rewriting them with canonical $20 + palette $2000 caused white tiles
    ; to overrun the right-hand black border. Leaving cells past VWF_SAVX
    ; alone preserves sibling content.)
    LDA.L !VWF_SAVX
    INC A : INC A
    STA.L !VWF_TMP_W                        ; loop bound (exclusive)

    LDA.L !VWF_FIRST_SAVX
    STA.L !VWF_TMP_FBI                      ; outer loop counter = current SAVX

    ; Step 8a-ext v2 — DMA-trim sentinels for first/last non-blank canvas
    ; byte. Reuses TMP_ORIG / TMP_SHIFT (transient in rasterizer; dead at
    ; PostRender). After scan, only used to SHRINK existing DMA bounds —
    ; never expand, never clear DIRTY.
    LDA.W #$FFFF
    STA.L !VWF_TMP_ORIG                     ; first_nonblank sentinel = "none"
    LDA.W #$0000
    STA.L !VWF_TMP_SHIFT                    ; last_nonblank end = 0

    ; Step 9a — non-blank run list capture (consumed by VWFNMI Step 9b).
    LDA.W #$0000
    STA.L !VWF_DMA_NRUNS                    ; runs captured so far
    STA.L !VWF_DMA_IN_RUN                   ; not currently in a run

.scanRow:
    LDA.L !VWF_TMP_FBI
    CMP.L !VWF_TMP_W
    BCC +                                   ; counter < bound → continue
    BRL .scanDone                           ; counter >= bound → done (long branch)
+

    ; canvas byte offset = row_base + col*16  (col*2 = SAVX & $003F)
    AND.W #$003F                            ; col*2 (low 6 bits of SAVX)
    ASL A : ASL A : ASL A                   ; * 8 → col*16
    CLC : ADC.L !VWF_TMP_BASE               ; + row_base
    STA.L !VWF_TMP_POS                      ; canvas byte offset for this tile

    ; Inner: 16 bytes (8 words) at TILE_BUF + TMP_POS all $FFFF?
    LDA.L !VWF_TMP_POS
    TAX                                     ; X = canvas byte offset
    LDY.W #$0008                            ; 8 word iterations
.tileScan:
    LDA.L !TILE_BUF,X
    CMP.W #$FFFF
    BNE .tileNotBlank                       ; non-blank → record + advance
    INX : INX
    DEY
    BNE .tileScan
    ; All 8 words = $FFFF → tile is fully blank. Maybe rewrite tilemap.
    ; Range-check: only rewrite entries pointing inside the VWF tile range
    ; ($20..$FF). Tile_ids $00..$1F are engine pre-loaded tiles (icons,
    ; cursors). Tile_ids $100+ are chrome (palette-4 icons/frames). Both
    ; classes belong to non-VWF engine UI and must be preserved.
    LDA.L !VWF_TMP_FBI                      ; A = current outer SAVX (tilemap byte off)
    TAX                                     ; X = tilemap byte offset
    LDA.L $7E9000,X                         ; existing TOP tilemap entry
    AND.W #$03FF                            ; mask tile_id (bits 0..9)
    CMP.W #$0020
    BCC .chromeSkipRewrite                  ; < $20 → engine tile, preserve
    CMP.W #$0100
    BCS .chromeSkipRewrite                  ; >= $100 → chrome, preserve
    LDA.W #!VWF_BLANK_TILE_ID               ; A = $0020 (canonical blank)
    CLC : ADC.W $0A02                       ; + palette/priority bits
    STA.L $7E9000,X                         ; rewrite TOP tilemap entry
    CLC : ADC.W #$0400                      ; + palette-row offset for bottom
    STA.L $7E9040,X                         ; rewrite BOTTOM tilemap entry
.chromeSkipRewrite:

    ; Step 9a — blank tile ends any current run.
    LDA.L !VWF_DMA_IN_RUN
    BEQ .tileAdvance                        ; not in run → nothing to close
    LDA.W #$0000
    STA.L !VWF_DMA_IN_RUN                   ; clear in-run flag
    LDA.L !VWF_DMA_NRUNS
    CMP.W #!VWF_DMA_MAX_RUNS+1
    BCS .tileAdvance                        ; already abandoned
    INC A
    STA.L !VWF_DMA_NRUNS                    ; commit closed run
    BRA .tileAdvance                        ; skip non-blank tracker

.tileNotBlank:
    ; v2 trim tracking — capture first non-blank canvas byte (once) and
    ; running last non-blank canvas byte end.
    LDA.L !VWF_TMP_ORIG
    CMP.W #$FFFF
    BNE +
    LDA.L !VWF_TMP_POS                      ; first encounter — record
    STA.L !VWF_TMP_ORIG
+
    LDA.L !VWF_TMP_POS
    CLC : ADC.W #$0010                      ; tile_end = TMP_POS + 16
    STA.L !VWF_TMP_SHIFT

    ; Step 9a — open or extend the current run.
    LDA.L !VWF_DMA_IN_RUN
    BNE .runExtend                          ; already in a run → just extend end

    ; Not in a run. Try to open one.
    LDA.L !VWF_DMA_NRUNS
    CMP.W #!VWF_DMA_MAX_RUNS
    BCC .runOpen                            ; < MAX → open
    ; ≥ MAX → abandon list. Set NRUNS to a sentinel beyond MAX so VWFNMI
    ; falls back to legacy single-DMA. Edge trim (v2) still applies.
    LDA.W #!VWF_DMA_MAX_RUNS+1
    STA.L !VWF_DMA_NRUNS
    BRA .tileAdvance

.runOpen:
    ; X = NRUNS * 4 (byte offset into RUNS array)
    ASL A : ASL A
    TAX
    LDA.L !VWF_TMP_POS
    STA.L !VWF_DMA_RUNS,X                   ; RUNS[NRUNS].start = TMP_POS
    LDA.W #$00A5
    STA.L !VWF_DMA_IN_RUN

.runExtend:
    ; RUNS[NRUNS].end = TMP_POS + 16
    LDA.L !VWF_DMA_NRUNS
    ASL A : ASL A
    CLC : ADC.W #$0002
    TAX
    LDA.L !VWF_TMP_POS
    CLC : ADC.W #$0010
    STA.L !VWF_DMA_RUNS,X

.tileAdvance:
    ; Advance outer SAVX by 2 (next cell)
    LDA.L !VWF_TMP_FBI
    INC A : INC A
    STA.L !VWF_TMP_FBI
    BRL .scanRow                            ; long branch (loop body grew)

.scanDone:
    ; Step 9a — close any pending run (last tile was non-blank).
    LDA.L !VWF_DMA_IN_RUN
    BEQ .runsDone
    LDA.W #$0000
    STA.L !VWF_DMA_IN_RUN
    LDA.L !VWF_DMA_NRUNS
    CMP.W #!VWF_DMA_MAX_RUNS+1
    BCS .runsDone                           ; already abandoned → leave
    INC A
    STA.L !VWF_DMA_NRUNS
.runsDone:

    ; --- DMA-trim v2: strictly shrink bounds ----------------------------
    ; If no non-blanks recorded → leave DMA bounds alone. Otherwise:
    ;   DMA_LO ← max(DMA_LO, TMP_ORIG)  — shrink from left only
    ;   DMA_HI ← min(DMA_HI, TMP_SHIFT) — shrink from right only
    ; Cannot expand, cannot clear DIRTY. If our scan range disagrees with
    ; the rasterizer's actual canvas writes (different row, multi-row
    ; emit, etc.) the worst case is no benefit, not a regression.
    LDA.L !VWF_TMP_ORIG
    CMP.W #$FFFF
    BEQ .exit                               ; no non-blanks → leave DMA alone

    ; LO trim: DMA_LO = max(DMA_LO, TMP_ORIG)
    LDA.L !VWF_TMP_ORIG
    CMP.L !VWF_DMA_LO
    BCC .skipLo                             ; TMP_ORIG < DMA_LO → don't expand
    STA.L !VWF_DMA_LO                       ; ≥ → safe to advance LO
.skipLo:

    ; HI trim: DMA_HI = min(DMA_HI, TMP_SHIFT)
    LDA.L !VWF_TMP_SHIFT
    CMP.L !VWF_DMA_HI
    BCS .skipHi                             ; TMP_SHIFT ≥ DMA_HI → don't expand
    STA.L !VWF_DMA_HI                       ; < → safe to retreat HI
.skipHi:

.exit:
    SEP #$20
.exit_m8:                                   ; entry for BB polarity-gate skip
    RTS

; ============================================================================
; VWFCalcTileAddrHook — body of Hook 9 (install site at $00:C1A6).
;
; Phase 4 step 1 implementation, sitting on the slice infrastructure
; from Phase 3:
;   - Phase 3 step 1: SCENE_SLICE = LRU(SCENE_TAG)
;   - Phase 3 step 2: POOL_NEXT / POOL_END_ACTIVE scoped to active slice
;   - Hook 9 path now allocates from the same POOL_NEXT, so unit-info /
;     file-info-style menus rasterize into their own slice's tile range.
;     Dialog (BB) is unchanged because BB renders via formula path, not
;     pool, and our SCENE_SLICE = $FF short-circuit keeps BB from
;     touching this code.
;
; ENTRY (M=16, X=16):
;   X = caller's tilemap byte offset (preserved across handler)
;   !VWF_CHAR = char value (stashed by install-site STA)
;
; EXIT: RTL — pops install-site JSL return; install-site RTS then pops
;       the writeTextCharacter caller's JSR return.
;
; Strategy:
;   1. Gate to .passthrough on:
;        - char outside $20..$EF (control code / icon)
;        - VWF_FLAG != $A5 (PreRender hasn't run; spurious entry)
;        - SCENE_SLICE = $FF (BB; formula path owns this scene)
;        - POOL_NEXT >= POOL_END_ACTIVE (slice exhausted)
;   2. Allocate next tile_id from slice (POOL_NEXT++).
;   3. Rasterize 1bpp glyph into canvas at the allocated tile's slot
;      ((tile - $20) * 16 byte offset). For Phase 4 step 1, render only
;      the TOP HALF (8 rows) of the 8x16 font glyph; the engine's
;      $0A1E-mode rendering is single-tile per char, so a paired
;      bottom-half render would need a separate dispatch from the engine
;      side that we haven't yet characterized.
;   4. Update DMA bounds + DIRTY for next NMI canvas-to-VRAM upload.
;   5. Write tilemap entry at $7E:9000+X (single-plane, matching the
;      original $C1A6 path's output): entry = vwf_tile_id + ($0A1E mask).
;
; The mask = $FC00 strips tile_id bits (9:0) from $0A1E, leaving the
; palette / priority / flip bits intact. This is the V3-mask lesson:
; $0A1E packs both palette and a tile_id base; we want the palette but
; we provide our own tile_id from the slice pool.
; ============================================================================
VWFCalcTileAddrHook:
    PHX                                     ; +1 save caller's tilemap byte offset
    BRA .gateStart                          ; jump over passthrough block

; --- Passthrough early so gate branches reach (relative branch ±127) ----
.passthrough_pull_M8:
    REP #$20
.passthrough_pull:
    PLX                                     ; restore caller's tilemap X
.passthrough:
    LDA.L !VWF_CHAR
    SEC : SBC.W #$0020
    CLC : ADC.W $0A1E
    STA.L $7E9000,X
    RTL

.gateStart:
    LDA.L !VWF_CHAR
    CMP.W #$0020 : BCC .passthrough_pull
    CMP.W #$00F0 : BCS .passthrough_pull

    SEP #$20
    LDA.L !VWF_SCENE_SLICE : CMP.B #$FF : BEQ .passthrough_pull_M8
    REP #$20

    ; --- Char-map lookup (Phase 4 step 1+ caching) -----------------------
    ; If we've already rasterized this char in the active slice, just
    ; reuse the cached tile_id and skip rasterization.
    LDA.L !VWF_CHAR
    AND.W #$00FF
    TAX                                     ; X = char index (16-bit)
    SEP #$20
    LDA.L !VWF_HOOK9_CHARMAP,X
    CMP.B #$FF
    BEQ .charMiss                           ; unallocated → rasterize fresh

    ; --- Char-map HIT: reuse cached tile_id -----------------------------
    REP #$20
    AND.W #$00FF                            ; A = tile_id low byte (high cleared)
    STA.L !VWF_TMP_TILE_ID
    LDA.W $0A1E
    AND.W #$FC00                            ; strip tile_id bits
    CLC : ADC.L !VWF_TMP_TILE_ID
    PLX                                     ; restore caller's tilemap X
    STA.L $7E9000,X
    RTL

.charMiss:
    REP #$20
    LDA.L !VWF_POOL_NEXT
    CMP.L !VWF_POOL_END_ACTIVE
    BCS .passthrough_pull                   ; slice exhausted → fallback
    STA.L !VWF_TMP_TILE_ID                  ; allocated tile_id
    INC A
    STA.L !VWF_POOL_NEXT

    ; --- Stash tile_id in char-map for future re-emits ------------------
    LDA.L !VWF_CHAR
    AND.W #$00FF
    TAX
    SEP #$20
    LDA.L !VWF_TMP_TILE_ID                  ; A = tile_id low byte (M=8 reads only low)
    STA.L !VWF_HOOK9_CHARMAP,X
    REP #$20

    ; --- Compute font base offset = char * 16 (saved to scratch) -----------
    LDA.L !VWF_CHAR
    AND.W #$00FF
    ASL A : ASL A : ASL A : ASL A
    STA.L !VWF_TMP_FBI                      ; reuse existing font-byte-index scratch

    ; --- X = canvas byte offset = (tile_id - $20) * 16 --------------------
    LDA.L !VWF_TMP_TILE_ID
    SEC : SBC.W #$0020
    ASL A : ASL A : ASL A : ASL A
    TAX                                     ; X = canvas write index

    ; --- Loop 8 rows: read 1bpp font byte, write to canvas low+high planes -
    LDY.W #$0000                            ; Y = row counter (16-bit)
    SEP #$20                                ; M=8 for byte ops
.rasterRow:
    PHX                                     ; +1 save canvas X
    PHY                                     ; +2 save row counter
    REP #$20
    TYA : CLC : ADC.L !VWF_TMP_FBI
    TAX                                     ; X = font byte index
    SEP #$20
    LDA.L VWFFontData,X                     ; 1bpp font byte
    REP #$20
    PLY                                     ; -2
    PLX                                     ; -1
    SEP #$20
    STA.L !TILE_BUF,X                       ; canvas low plane
    INX
    STA.L !TILE_BUF,X                       ; canvas high plane (same byte → solid)
    INX
    INY
    CPY.W #$0008
    BNE .rasterRow
    REP #$20

    ; --- Update DMA bounds + DIRTY -----------------------------------------
    LDA.L !VWF_TMP_TILE_ID
    SEC : SBC.W #$0020
    ASL A : ASL A : ASL A : ASL A           ; canvas start byte
    PHA                                     ; +1 save canvas start
    CMP.L !VWF_DMA_LO
    BCS .skipUpdLO
    STA.L !VWF_DMA_LO
.skipUpdLO:
    PLA                                     ; -1 → A = canvas start
    CLC : ADC.W #$0010                      ; +16 bytes (8 rows × 2 planes)
    CMP.L !VWF_DMA_HI
    BCC .skipUpdHI
    STA.L !VWF_DMA_HI
.skipUpdHI:
    SEP #$20
    LDA.B #$A5 : STA.L !VWF_DIRTY
    REP #$20

    ; --- Write tilemap entry: vwf_tile_id + ($0A1E & $FC00) ----------------
    LDA.W $0A1E
    AND.W #$FC00                            ; strip tile_id bits 9:0; keep pal/pri/flip
    CLC : ADC.L !VWF_TMP_TILE_ID            ; A = composed tilemap entry word
    PLX                                     ; restore caller's tilemap X
    STA.L $7E9000,X                         ; single-plane top entry (matches engine)
    RTL                                     ; back to install-site RTS

; ============================================================================
; VWFCheckReEmit — Phase 2 re-emit detection helper.
;
; ENTRY: M=8, X=any. Called via JSR.W from VWFPreRender (same-bank).
; EXIT:  M=8 (caller's PreRender expects M=8 to continue with its byte
;        sentinel writes). Stomps A, X.
;
; Behavior:
;   1. Compute current text-buffer XOR-fold of 16 words ($0400..$041F).
;   2. If !VWF_CACHE_VALID == $A5 AND !VWF_SCENE_TAG matches
;      !VWF_LAST_SCENE_TAG AND current sig matches !VWF_LAST_BUF_SIG:
;        set !VWF_REGEN_ONLY = $A5 (re-emit cache hit).
;      Else:
;        clear !VWF_REGEN_ONLY = 0 (full rasterization will run);
;        copy SCENE_TAG → LAST_SCENE_TAG.
;   3. Always: write current sig → LAST_BUF_SIG.
;
; Phase 2 is INSTRUMENTATION ONLY at this point — no consumer reads
; !VWF_REGEN_ONLY yet. Verification via Mesen IPC: pause across
; consecutive emits and check $7F:5D49 lights up at expected moments.
; Phase 2.5+ wires VWFCharHandler's fast-path to skip rasterization
; when REGEN_ONLY is set.
; ============================================================================
VWFCheckReEmit:
    ; --- Compute current buffer signature (M=16, X=16) -------------------
    REP #$30
    LDA.W #$0000
    LDX.W #$001E                            ; index 30 = last word of 32-byte window
.sigLoop:
    EOR.W $0400,X
    DEX : DEX
    BPL .sigLoop
    PHA                                     ; +1: save current sig

    ; --- CACHE_VALID gate (M=8) ------------------------------------------
    SEP #$20
    LDA.B #$00 : STA.L !VWF_REGEN_ONLY      ; default: full rasterization
    LDA.L !VWF_CACHE_VALID
    CMP.B #$A5
    BNE .miss                               ; no prior commit → cache miss

    ; --- SCENE_TAG word-compare to LAST_SCENE_TAG (M=16) -----------------
    REP #$20
    LDA.L !VWF_SCENE_TAG+0 : CMP.L !VWF_LAST_SCENE_TAG+0 : BNE .missRep
    LDA.L !VWF_SCENE_TAG+2 : CMP.L !VWF_LAST_SCENE_TAG+2 : BNE .missRep

    ; --- Buffer-sig compare (M=16, current sig is at $01,S) --------------
    LDA $01,S
    CMP.L !VWF_LAST_BUF_SIG
    BNE .missRep

    ; --- Cache hit ------------------------------------------------------
    SEP #$20
    LDA.B #$A5 : STA.L !VWF_REGEN_ONLY
    BRA .commit

.missRep:
    SEP #$20
.miss:
    ; Update LAST_SCENE_TAG ← SCENE_TAG (4 bytes via 2 word writes)
    REP #$20
    LDA.L !VWF_SCENE_TAG+0 : STA.L !VWF_LAST_SCENE_TAG+0
    LDA.L !VWF_SCENE_TAG+2 : STA.L !VWF_LAST_SCENE_TAG+2
    SEP #$20

.commit:
    ; Always commit current buffer sig (and pop)
    REP #$20
    PLA
    STA.L !VWF_LAST_BUF_SIG
    SEP #$20
    RTS                                     ; near-call return to PreRender

; ============================================================================
; VWFAssignSlice — Phase 3 step 1 LRU tracking helper.
;
; ENTRY: M=8, X-flag-status preserved by PHP/PLP. SCENE_TAG already
;        captured at $7F:5D40. JSR-called from VWFPreRender.
; EXIT:  M=8. !VWF_SCENE_SLICE = 0/1/2 = LRU slot owning this scene.
;        On miss: !VWF_SLICE_LRU_NEXT advanced (round-robin 0,1,2).
;        Stomps A, X.
;
; Comparison strategy: 4-byte SCENE_TAG matched against each slot's
; cached tag in 2-word compares. First slot that matches wins. On miss,
; the slot at LRU_NEXT is overwritten with the new SCENE_TAG.
;
; This is INSTRUMENTATION ONLY in step 1 — no pool allocator or canvas
; wipe consumer reads !VWF_SCENE_SLICE yet. Phase 3 step 2 wires
; per-slice tile-range allocation.
; ============================================================================
VWFAssignSlice:
    PHP                                     ; preserve caller's M/X
    REP #$30                                ; M=16, X=16 inside helper

    ; --- BB short-circuit (INVERT=$00 → dialog, no LRU slice) ------------
    SEP #$20
    LDA.L !VWF_INVERT
    BNE .doLRU                              ; non-zero = WB → use LRU slice

    ; BB / dialog: no slice allocation. BB uses formula path, doesn't
    ; consume pool tiles. POOL_*_ACTIVE set to safe non-empty defaults
    ; (range never read on BB code path; values just need to exist so
    ; any spurious WB-path read can't crash).
    LDA.B #$FF : STA.L !VWF_SCENE_SLICE
    REP #$20
    LDA.W #$0021 : STA.L !VWF_POOL_FIRST_ACTIVE
    LDA.W #$00F2 : STA.L !VWF_POOL_END_ACTIVE   ; full WB range as safety default
    SEP #$20
    LDA.B #$FF : STA.L !VWF_LAST_SCENE_SLICE    ; record BB-mode marker
    PLP : RTS

.doLRU:
    REP #$20

    ; --- Slot 0 ---------------------------------------------------------
    LDA.L !VWF_SCENE_TAG+0 : CMP.L !VWF_SLICE_LRU_TAG_0+0 : BNE .checkSlot1
    LDA.L !VWF_SCENE_TAG+2 : CMP.L !VWF_SLICE_LRU_TAG_0+2 : BNE .checkSlot1
    SEP #$20
    LDA.B #$00 : STA.L !VWF_SCENE_SLICE
    BRA .applyRange

.checkSlot1:
    LDA.L !VWF_SCENE_TAG+0 : CMP.L !VWF_SLICE_LRU_TAG_1+0 : BNE .checkSlot2
    LDA.L !VWF_SCENE_TAG+2 : CMP.L !VWF_SLICE_LRU_TAG_1+2 : BNE .checkSlot2
    SEP #$20
    LDA.B #$01 : STA.L !VWF_SCENE_SLICE
    BRA .applyRange

.checkSlot2:
    LDA.L !VWF_SCENE_TAG+0 : CMP.L !VWF_SLICE_LRU_TAG_2+0 : BNE .miss
    LDA.L !VWF_SCENE_TAG+2 : CMP.L !VWF_SLICE_LRU_TAG_2+2 : BNE .miss
    SEP #$20
    LDA.B #$02 : STA.L !VWF_SCENE_SLICE
    BRA .applyRange

.miss:
    ; Allocate next slot (LRU_NEXT). Copy SCENE_TAG → LRU_TAG[NEXT].
    SEP #$20
    LDA.L !VWF_SLICE_LRU_NEXT
    STA.L !VWF_SCENE_SLICE                  ; SCENE_SLICE = slot index 0..2

    ; Compute byte offset into LRU table = NEXT * 4 (4 B per slot).
    AND.B #$03                              ; safety mask
    ASL A : ASL A                           ; A = NEXT * 4
    REP #$20
    AND.W #$00FF
    TAX                                     ; X = byte offset within LRU table

    LDA.L !VWF_SCENE_TAG+0
    STA.L !VWF_SLICE_LRU_TAG_0+0,X
    LDA.L !VWF_SCENE_TAG+2
    STA.L !VWF_SLICE_LRU_TAG_0+2,X

    SEP #$20
    LDA.L !VWF_SLICE_LRU_NEXT
    INC A
    CMP.B #$03
    BCC .storeNext
    LDA.B #$00
.storeNext:
    STA.L !VWF_SLICE_LRU_NEXT
    ; Fall through to .applyRange

.applyRange:
    ; SCENE_SLICE (0/1/2) is set. Compute slice tile range via small
    ; ROM table indexed by SLICE * 4 (4 B per entry: first_word, end_word).
    ; M=8 here; need M=16 for word table reads.
    LDA.L !VWF_SCENE_SLICE                  ; A = 0/1/2
    AND.B #$03
    ASL A : ASL A                           ; A = SLICE * 4
    REP #$20
    AND.W #$00FF
    TAX                                     ; X = byte offset into table

    LDA.L VWFSliceRangeTable+0,X
    STA.L !VWF_POOL_FIRST_ACTIVE
    LDA.L VWFSliceRangeTable+2,X
    STA.L !VWF_POOL_END_ACTIVE

    ; If SCENE_SLICE differs from LAST_SCENE_SLICE, the previous emit's
    ; POOL_NEXT was bumping into a DIFFERENT slice's range. Only reset
    ; POOL_NEXT if the current value is OUTSIDE the new slice's range —
    ; otherwise preserve POOL_NEXT so consecutive emits within a scene
    ; (each with potentially distinct caller_PC fingerprints producing
    ; different LRU slots) accumulate unique tile_id allocations instead
    ; of restarting from slice_first on every emit.
    ;
    ; Phase 4b post-regression: Phase 1 SCENE_TAG fingerprints were observed
    ; cycling among 3 slots within a SINGLE unit-info render (caller_PC
    ; varies per JSR-driven sub-emit dispatcher). With single-pool slices
    ; ($21..$FF for all 3), the in-range check always preserves POOL_NEXT,
    ; eliminating the cross-emit tile_id collision that produced "Hero
    ; duplicated across all 4 slots" symptom.
    SEP #$20
    LDA.L !VWF_SCENE_SLICE
    CMP.L !VWF_LAST_SCENE_SLICE
    BEQ .sameSlice
    REP #$20
    LDA.L !VWF_POOL_NEXT
    CMP.L !VWF_POOL_FIRST_ACTIVE
    BCC .resetPoolNext                      ; POOL_NEXT < FIRST → out of range, reset
    CMP.L !VWF_POOL_END_ACTIVE
    BCC .poolNextInRange                    ; POOL_NEXT < END → in range, preserve
.resetPoolNext:
    LDA.L !VWF_POOL_FIRST_ACTIVE
    STA.L !VWF_POOL_NEXT
.poolNextInRange:
    SEP #$20
    LDA.L !VWF_SCENE_SLICE
    STA.L !VWF_LAST_SCENE_SLICE

    ; Wipe Hook 9 char-map (256 bytes → $FF = unallocated)
    REP #$10                                ; X=16 for 16-bit indexing
    LDX.W #$00FF
    LDA.B #$FF
.assignWipeMap:
    STA.L !VWF_HOOK9_CHARMAP,X
    DEX
    BPL .assignWipeMap

.sameSlice:
    PLP : RTS

; ROM table: per-slice (first_tile, end_tile_exclusive) word pairs.
; All slices live in chrome-safe $B1..$F1 (65 tiles split 3 ways).
VWFSliceRangeTable:
    ; Phase 4b post-regression: single shared pool, all 3 slots cover the
    ; full font area $0021..$00FF (255 tiles; $20 blank, $3E cursor → ~222
    ; usable). Pool starts at VRAM word $6108 ($21*16 + $C000 byte). The
    ; chrome-safe carve from Phase 4 step 1 ($B1..$F1 in 24/24/17) was too
    ; small to fit a multi-emit menu like unit-info (~50 unique chars
    ; across 4 slots) and produced large unused VRAM gaps. Slicing infra
    ; preserved (LRU, FIRST/END_ACTIVE) but degenerates to one pool while
    ; we test Option D's preserve-POOL_NEXT behavior end-to-end.
    dw $0021, $0100                         ; slot 0: tiles $21..$FF (255)
    dw $0021, $0100                         ; slot 1: same
    dw $0021, $0100                         ; slot 2: same

warnpc $E09520                              ; ClsHook + helpers + slice LRU + flush helper + Phase 4 rasterizer + VWFDedupeRow + VWFTrailingRowClear must end before VWFNMI (bumped +$10 for trailing-clear chrome check)

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
;
; Org bumped from $E09200 → $E09300 (Phase 4 step 1, scene-aware-cache
; plan) to give the ClsHook block more room for the Hook 9 helper +
; phase 2/3 helpers + Phase 4 rasterizer.
; Bumped again $E09300 → $E09340 (Phase 4b Bug-B fix) for VWFPostFlush.
; ============================================================================
org $E09520

; ENTRY: native NMI vector entry (after game's $00:D469-D46C bytes that we
;        displaced: PHP / REP #$30 / PHA). We replicate them here, then run
;        deferred work, then JML back to $00:D46D for the rest of NMI.
;
; DBR DISCIPLINE (R1.F-14):
;   The interrupted code may have left DBR in any bank. Our STA.W $211x /
;   $437x / $420B writes are DBR-relative — if DBR is $40-$7D or $7E/$7F,
;   they hit RAM instead of PPU/DMA registers and silently corrupt WRAM.
;   The original NMI body at $00:D46D+ shares this hazard (LDA.W $4210,
;   STA.W $2100, etc.). We harden BOTH by pushing the interrupted DBR,
;   forcing DBR=$00 for the duration of NMI, and restoring DBR before the
;   JML so the original body inherits the safe state.
;
;   Stack on entry to VWFNMI body (after preserves):
;       [P from displaced PHP] [A from displaced PHA] [X] [Y] [caller_DBR]
;   Stack on exit (before JML to $D46D):
;       [P from displaced PHP] [A from displaced PHA]
;   (PLB/PLY/PLX in reverse-push order; original $D46D PHX/PHY then re-push.)
VWFNMI:
    PHP                                     ; displaced from $D469
    REP #$30                                ; displaced from $D46A — M=16, X=16
    PHA                                     ; displaced from $D46C
    PHX                                     ; preserve interrupted X
    PHY                                     ; preserve interrupted Y
    PHB                                     ; preserve interrupted DBR (R1.F-14)
    SEP #$20                                ; M=8 for byte ops + DBR fixup
    LDA.B #$00                              ; bank $00 = PPU/CPU register bank
    PHA : PLB                               ; DBR = $00 → STA.W $21xx/$43xx safe

    ; --- Scene-init pending? Run polarity wipe DMA first (vblank-safe) ---
    ; (M=8 already set above; the SEP #$20 here is retained for clarity.)
    ;
    ; R3.F-X: wipe is split across TWO consecutive NMIs.  PENDING values:
    ;   $00 = no wipe pending (canvas DMA path)
    ;   $A5 = chunk 1 pending (wipes tiles $20..$3D, ~480 B / ~3.8 k cyc)
    ;   $A6 = chunk 2 pending (wipes tiles $3F..$FF/$11F, ~3088/3600 B /
    ;                          ~24.7/28.8 k cyc)
    ; The combined wipe (~28-33 k cyc) leaked past vblank when NMI entered
    ; at V=240 (~30 k cyc remaining); chunk 2 alone fits comfortably.  The
    ; cost is an extra 1-frame transition stall at scene boundaries.
    SEP #$20                                ; M=8 for sentinel byte
    LDA.L !VWF_SCENE_INIT_PENDING
    BEQ .checkDirty                         ; $00 → no wipe → canvas DMA path
    JSR.W VWFNMIVramWipe                    ; runs chunk 1 ($A5) or chunk 2 ($A6)
    ; R2.F-2: defer canvas DMA past every wipe frame.  DIRTY/DMA bounds
    ; remain intact across both wipe NMIs; the first non-wipe NMI uploads.
    JMP .skipDMA

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

    ; --- Step 9b: prefer run-list DMA when populated --------------------
    ; If VWFDedupeRow captured a valid run list (NRUNS in [1..MAX_RUNS]),
    ; iterate the runs and DMA each segment individually. This skips
    ; interior blank tiles within the dedupe range, beyond what the v2
    ; edge-trim achieves. NRUNS == 0 (BB or unprocessed) and NRUNS ==
    ; MAX_RUNS+1 (overflow sentinel) fall through to the legacy path.
    SEP #$20
    LDA.L !VWF_DMA_NRUNS
    BEQ .checkPolarity                      ; no runs → legacy
    CMP.B #!VWF_DMA_MAX_RUNS+1
    BCS .checkPolarity                      ; sentinel → legacy
    JMP .doRunList                          ; valid → per-run DMA

.checkPolarity:
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
    BRA .clearAndExit                       ; fall-through guard for .doRunList below

    ; --- Step 9b: per-run DMA loop --------------------------------------
    ; Iterates DMA_RUNS[0..NRUNS-1], one DMA per (start, end) pair. Uses
    ; X as byte offset into RUNS (advances +4 per entry). NRUNS is consumed
    ; (decremented to 0) as we iterate — .clearAndExit also clears it for
    ; safety.
.doRunList:
    REP #$20                                ; M=16 for word loads
    LDX.W #$0000                            ; byte offset within RUNS
.runLoop:
    LDA.L !VWF_DMA_RUNS,X                   ; A = run.start (canvas byte)
    STA.L !VWF_TMP_BASE                     ; stash for reuse
    LDA.L !VWF_DMA_RUNS+2,X                 ; A = run.end (exclusive)
    SEC : SBC.L !VWF_TMP_BASE               ; byte count = end - start
    STA.W $4375                             ; DAS7L/H
    LDA.L !VWF_TMP_BASE
    CLC : ADC.W #$7000                      ; src = $7F:7000 + start
    STA.W $4372                             ; A1T7L/H
    LDA.L !VWF_TMP_BASE
    LSR A                                   ; byte → word offset
    CLC : ADC.W #!VWF_VRAM_WORD_BASE        ; + tile $20 word base
    STA.W $2116                             ; VMADDL/H
    SEP #$20
    LDA.B #$80
    STA.W $420B                             ; trigger this run's DMA

    ; Decrement run counter; exit when zero.
    LDA.L !VWF_DMA_NRUNS
    DEC A
    STA.L !VWF_DMA_NRUNS
    BEQ .clearAndExit                       ; all runs done

    REP #$20                                ; M=16 to advance X
    TXA
    CLC : ADC.W #$0004                      ; next entry
    TAX
    BRA .runLoop

.clearAndExit:
    REP #$20                                ; M=16 for word stores
    LDA.W #$FFFF                            ; reset dirty-range bounds
    STA.L !VWF_DMA_LO
    LDA.W #$0000
    STA.L !VWF_DMA_HI
    STA.L !VWF_DMA_NRUNS                    ; clear run-list state (Step 9b)
    STA.L !VWF_DMA_IN_RUN                   ; (defensive)

    SEP #$20                                ; M=8 for byte clear
    LDA.B #$00 : STA.L !VWF_DIRTY           ; clear dirty flag

.skipDMA:
    REP #$30                                ; restore M=16, X=16 for downstream NMI
    PLB                                     ; restore interrupted DBR (R1.F-14)
    PLY                                     ; restore interrupted Y
    PLX                                     ; restore interrupted X
    JML $00D46D                             ; resume original NMI handler at PHX

; ----------------------------------------------------------------------------
; VWFLineEndCheck — called from $00:BE92 hook in place of the engine's
; char-count comparison. Sets carry as if the original CMP ran:
;   carry CLEAR if VWF_PX < (line_char_limit * 8) → caller's BCC continues loop
;   carry SET   otherwise → caller falls through to wrap path
; Caller is in M=16 mode (text engine convention at this hook site).
;
; STACK-SCRATCH TRICK (R1.F-6):
;   We need a 16-bit scratch to compare VWF_PX against (limit * 8). Rather
;   than burn a permanent WRAM slot, we PHA a placeholder, overwrite the
;   pushed word in-place via `STA $01,S`, do `CMP $01,S` against it, and
;   PLA the scratch.  PLA only updates N and Z — it leaves CARRY untouched
;   — so the C flag set by CMP survives the pop.  The caller's BCC at
;   $00:BE96 reads that carry. **Don't replace this with a regular WRAM
;   scratch unless you need to**; the in-stack form keeps the helper
;   reentrant and avoids cluttering the $7F:5D00 state region.
; ----------------------------------------------------------------------------
VWFLineEndCheck:
    PHA                                     ; reserve stack slot (2 bytes, M=16)
    LDA.W $09F8                             ; line-width limit IN CHARACTERS
    ASL A : ASL A : ASL A                   ; * 8 → pixel limit
    STA $01,S                               ; overwrite our PHA'd word with pixel limit
    LDA.L !VWF_PX                           ; current VWF pen pixel x
    CMP $01,S                               ; compare pen vs pixel limit (sets C)
    PLA                                     ; pop scratch — C survives (PLA only sets N/Z)
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
; VWFCursorBlank — runs at writeTextCharacter's A==0 early path (Hook 8,
; $00:C167). Replicates the two displaced STA.L writes that put tile $0100
; into both the top and bottom BG3 tilemap planes (the visible cursor "off"
; cell), then clears VWF_BLINK so the flag cannot leak past this write.
;
; Caller convention at $00:C167: M=16 (text engine sets it via REP earlier
; in the dispatch chain), A=$0100 (loaded by $C164 LDA.W #$0100), X = the
; tilemap byte offset for the cursor cell. After this hook, $00:C16F's
; original RTS terminates the path.
;
; R3.F-4: paired with Hook 7 (which arms BLINK before every cursor write)
; to guarantee BLINK is cleared by SOMETHING in every cursor iteration —
; cursor-ON consumes via CharHandler's .vwf → .origPath route, cursor-OFF
; consumes here. Either path leaves BLINK==$00 by the time the next non-
; cursor writer reaches Hook 1.
; ----------------------------------------------------------------------------
VWFCursorBlank:
    STA.L $7E9000,X                         ; displaced from $C167 (A=$0100, top plane)
    STA.L $7E9040,X                         ; displaced from $C16B (same A, bot plane)
    PHP                                     ; preserve caller's M state
    SEP #$20                                ; M=8 for flag byte clear
    LDA.B #$00
    STA.L !VWF_BLINK                        ; clear so it cannot leak past cursor wipe
    PLP                                     ; restore M=16
    RTL

warnpc $E096E0                              ; VWFNMI + helpers must end before data table (bumped +$10 for trailing-clear)

; ============================================================================
; Data — placed at $E0:96E0, safely past VWFNMI (bumped +$10 for
; trailing-clear chrome check; was $E096D0)
; ($E096E0 + 256 widths + 16-byte zero glyph + ~3840 font bytes ≈ $E0:A6F1)
; ============================================================================
org $E096E0

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
; The captured TEXT_LO/HI/BNK slots feed VWFPreRender's scene-change
; fingerprint compare (PreRender vs LAST_*) — that is the load-bearing
; observable effect.  When !VWF_DEBUG = 1 a sentinel counter at
; !VWF_DBG_CAPCOUNT also increments per call (Mesen IPC convenience).
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
    ; Compiled out when !VWF_DEBUG = 0 (R1.F-10) — saves 6 cycles per
    ; Phase-1 entry on release builds.
if !VWF_DEBUG
    LDA.L !VWF_DBG_CAPCOUNT
    INC A
    STA.L !VWF_DBG_CAPCOUNT
endif

    REP #$20                                ; M=16 for the displaced STZ.W
    STZ.W $0A08                             ; displaced from $80:B67C+0
    STZ.W $0A16                             ; displaced from $80:B67C+3
    STZ.W $0A18                             ; displaced from $80:B67C+6

    PLP                                     ; restore caller's M/X
    RTL
; ============================================================================
; VWFRequestSceneInit  ($E0:AA00) / VWFRequestPageReset  (R3.F-Z addition)
;
; Two PUBLIC entry points share the same allocator-state-reset body.  The
; difference is whether the per-NMI VRAM polarity wipe is queued.
;
; VWFRequestSceneInit (full)
;   Caller: VWFClsHook (after displaced initTilemapAndSync_Long), or
;           VWFPreRender on INVERT (polarity) flip.
;   Effects: full state reset + sets SCENE_INIT_PENDING=$A5 → NMI runs
;            chunk-1 / chunk-2 VRAM wipe sequence.
;
; VWFRequestPageReset (light)
;   Caller: VWFPreRender on TEXT_LO/HI/BNK change (= dialog page advance).
;   Effects: full state reset, but does NOT touch SCENE_INIT_PENDING.
;            The engine has already cleared the dialog tilemap to blank
;            tile $100, so the prior page's VRAM tile_ids are unreferenced
;            and the new emit's canvas DMA overwrites the slots it
;            allocates.  Avoids the OAM-DMA-past-vblank glitch caused by
;            re-running the VRAM wipe on every page boundary.
;
; Common state-reset effects (both entry points):
;   - Captures current INVERT into VWF_LAST_INVERT
;   - Captures current TEXT_LO/HI/BNK into VWF_LAST_TEXT_*
;   - Wipes canvas $7F:7000..$7F7FFF with polarity fill (BB skips, R2.F-3)
;   - Resets CELL_TILE[0..255] to $FFFF (unallocated)
;   - Resets POOL_NEXT cursor to $0021
;   - Clears DIRTY / DMA bounds, resets LAST_COL to $FF
;
; Register-state contract:
;   ENTRY: M/X any (PHP first, PLP last)
;   EXIT:  caller's M/X restored
; ============================================================================
org $E0AA00

VWFRequestSceneInit:
    PHP                                     ; preserve caller's M/X
    REP #$30                                ; M=16, X=16 inside helper
    JSR.W VWFResetState                     ; common allocator-state reset (M=8 exit)
    LDA.B #$A5 : STA.L !VWF_SCENE_INIT_PENDING  ; queue VRAM wipe for next NMI
    PLP                                     ; restore caller's M/X
    RTL

VWFRequestPageReset:
    PHP                                     ; preserve caller's M/X
    REP #$30                                ; M=16, X=16 inside helper
    JSR.W VWFResetState                     ; common allocator-state reset (M=8 exit)
    PLP                                     ; restore caller's M/X
    RTL

; ----------------------------------------------------------------------------
; VWFResetState — internal (RTS) shared body for the two entry points above.
; ENTRY: M=16, X=16
; EXIT:  M=8, X=16  (caller's PLP will restore the original width)
; ----------------------------------------------------------------------------
VWFResetState:
    ; --- Polarity + fingerprint capture (M=8 byte ops) -------------------
    SEP #$20                                ; M=8
    LDA.B $70 : AND.B #$80
    STA.L !VWF_INVERT
    STA.L !VWF_LAST_INVERT                  ; remember polarity at this reset

    LDA.L !VWF_TEXT_LO  : STA.L !VWF_LAST_TEXT_LO
    LDA.L !VWF_TEXT_HI  : STA.L !VWF_LAST_TEXT_HI
    LDA.L !VWF_TEXT_BNK : STA.L !VWF_LAST_TEXT_BNK

    ; --- Canvas wipe — polarity-conditional (R2.F-3 BB-skip) ------------
    ; WB: full 4 KB wipe so AND-NOT rendering punches holes through clean
    ;     white paper without merging stale pixels.
    ; BB: skipped — formula tile_id = $20 + row*32 + col means PreRender's
    ;     pen-onward partial wipe + CharHandler row-change wipe cover all
    ;     referenced canvas bytes.  Saves ~25 000 master cycles per reset.
    LDA.L !VWF_INVERT                       ; (M=8 from SEP above)
    REP #$20                                ; M=16 for the fill loop + downstream code
    BEQ .canvasWipeDone                     ; BB → skip canvas wipe entirely
    LDA.W #$FFFF                            ; WB → fill white
    LDX.W #$0000
.canvasLoop:
    STA.L !TILE_BUF,X
    INX : INX
    CPX.W #!CANVAS_SIZE                     ; reached 4096?
    BCC .canvasLoop
.canvasWipeDone:

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

    ; Phase 2 — invalidate re-emit cache. CELL_TILE just got wiped to
    ; $FFFF and POOL_NEXT reset, so any cached tile_id from a prior emit
    ; would point at uninitialized canvas bytes. Force the next emit to
    ; rasterize fresh.
    LDA.B #$00 : STA.L !VWF_CACHE_VALID
    STA.L !VWF_REGEN_ONLY                   ; clear regen flag too
    RTS

; ============================================================================
; VWFNMIVramWipe  ($E0:AB00)
;
; Runs ONE chunk per NMI (3-way split, R3.F-X expansion).  The original
; 2-chunk split still leaked past vblank because chunk 2 alone was
; ~18-21 scanlines of DMA + game NMI's ~4 scanlines of OAM DMA, edging
; over the ~21-scanline vblank window remaining when NMI fires at V=240.
; Halving chunk 2 keeps each NMI's wipe to ~9-11 scanlines, leaving
; ample headroom for the game's NMI work.
;
; PENDING values (1 byte at $7F:5D1B):
;   $A5 = chunk 1   tiles $20..$3D   480 B   ~3.8 k cyc   ~3 scanlines
;   $A6 = chunk 2a  tiles $3F..$9E   1536 B  ~12.3 k cyc  ~9 scanlines
;   $A7 = chunk 2b  tiles $9F..end   1552/2064 B WB/BB    ~9-12 scanlines
;   $00 = no wipe pending
;
; Tile $3E (cursor) is preserved by the chunk-1 / chunk-2a gap.  The
; chunk-2a / chunk-2b boundary at tile $9F is arbitrary (no semantic
; significance — just splits the remaining range roughly in half).
;
; Polarity-fill uses DMA mode 1 + FIXED source (DMAP bit 3) → one ROM
; byte fills the entire range; source = $00 (BB) or $FF (WB).
;
; Channel 7 is unused by the engine; VMAIN word-inc on $2119 high write
; advances VRAM word per byte pair.
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
    LDA.B #!VWF_BANK : STA.W $4374          ; A1B7 = source bank (VWFVramWipeBytes lives here)

    ; Source byte addr depends on polarity (BB→$00, WB→$FF).
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

    ; --- Dispatch on PENDING value ---------------------------------------
    SEP #$20
    LDA.L !VWF_SCENE_INIT_PENDING
    CMP.B #$A5
    BEQ .doChunk1
    CMP.B #$A6
    BEQ .doChunk2a
    ; else falls through to chunk 2b ($A7)

    ; --- Chunk 2b: tiles $9F..end-of-polarity-range ---------------------
    ; WB: $9F..$FF  → 97 tiles × 16 = 1552 bytes ($0610)
    ; BB: $9F..$11F → 129 tiles × 16 = 2064 bytes ($0810)
    REP #$20
    LDA.L !VWF_INVERT
    BEQ .chunk2b_BB
    LDA.W #$0610                            ; WB chunk 2b byte count
    BRA .chunk2b_setDAS
.chunk2b_BB:
    LDA.W #$0810                            ; BB chunk 2b byte count
.chunk2b_setDAS:
    STA.W $4375
    LDA.W #!VWF_VRAM_WORD_BASE+$03F8        ; $64F8 = tile $9F word
    STA.W $2116
    SEP #$20
    LDA.B #$80 : STA.W $420B                ; trigger chunk 2b

    LDA.B #$00 : STA.L !VWF_SCENE_INIT_PENDING  ; chunk 2b done → clear pending
    RTS                                     ; back to NMI body (M=8, X=16)

.doChunk2a:
    ; --- Chunk 2a: tiles $3F..$9E (96 tiles × 16 = 1536 B / ~12.3 k cyc) -
    REP #$20
    LDA.W #$0600                            ; 1536 bytes (same for BB and WB)
    STA.W $4375
    LDA.W #!VWF_VRAM_WORD_BASE+$00F8        ; $61F8 = tile $3F word
    STA.W $2116
    SEP #$20
    LDA.B #$80 : STA.W $420B                ; trigger chunk 2a

    LDA.B #$A7 : STA.L !VWF_SCENE_INIT_PENDING  ; advance to chunk 2b next NMI
    RTS                                     ; back to NMI body (M=8, X=16)

.doChunk1:
    ; --- Chunk 1: tiles $20..$3D (480 bytes / ~3.8 k cyc) ---------------
    ; Wipes 30 tiles, leaving tile $3E (cursor) untouched for chunks 2a/2b.
    REP #$20
    LDA.W #$01E0                            ; 480 bytes
    STA.W $4375
    LDA.W #!VWF_VRAM_WORD_BASE              ; $6100 = tile $20 word
    STA.W $2116
    SEP #$20
    LDA.B #$80 : STA.W $420B                ; trigger chunk 1

    LDA.B #$A6 : STA.L !VWF_SCENE_INIT_PENDING  ; advance to chunk 2a next NMI
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
