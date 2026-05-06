# VWF Unification — One-Wipe Scene Init, Index-Gated Render, Inheritance over Customization

> Plan target: `asm/vwf_patch.asm` (1956 lines, current state). Single-pass execution.
> Companion docs: `Plans/vwf-gate-removal.md` (prior direction), `Plans/vwf-1bpp-il-rewrite.md`
> (encoding invariants), `Plans/file-info-fixup.md` (chrome-collision history).

---

## Context

The VWF (variable-width font) patch overlays a per-pixel proportional font on
LM3's tile-grid text engine. Three scene categories exist:

| Scene type | Status | Render path |
|------------|--------|-------------|
| **SBB** — Static black-bg menus | ✅ working perfectly | shares BB path |
| **BB** — typewriter dialog | ✅ working | `tile_id = $20 + row*32 + col` — **allowed to spill above `$100`** (up to `$13F`); no engine-UI conflict in BB-only scenes |
| **WB** — white-bg menus (file info, etc.) | ⚠️ partial / fragile | per-cell pool allocation, bitmap-walk DMA, hand-tuned `VWFGateAllowList` |

**Why WB mangles on multiple paint cycles** (root cause):

1. WB uses **bitmap-walk DMA** (`.nmiBitmapWalk`, `vwfDoDmaForCell` at lines
   1368, 1435). Only DMAs cells *this emit* rendered. Cells that previously had
   VWF content but are now blank in the new emit keep their stale VRAM tile data.
2. WB has no concept of "scene-level destination wipe" — every emit just rasterizes
   *additional* glyphs over whatever VRAM held. The "blank tile $200" hack
   (`VWFInitBlankTile` line 1774) is a single tile shared by all blanks but only
   referenced via gap-fill, not as a permanent canonical.
3. The pool allocator (`vwfAllocOne` line 1540) + `VWFGateAllowList` (line 1898)
   require **hand-authored per-scene tile-range tables** that scale poorly and
   leak across paints when allocations accumulate.
4. M/X register state has been a recurring bug source (lines 670–676, 787–788
   document past TAX/LDA-with-stale-B failures).

**What the user wants**:

- **Single wipe per scene**: VWF VRAM destination range is wiped once on scene
  start (white for WB, black for BB). Subsequent paints rasterize only what they
  need; untouched cells stay visually blank because they reference pre-wiped tiles.
- **Tile `$20` is the canonical blank**, polarity-filled, never rewritten by VWF.
  Cells without VWF content (or with blank glyphs) point their tilemap entry at
  `$20`.
- **Tile-index constraint is polarity-dependent**:
  - **BB** (`INVERT=$00`): formula `$20 + row*32 + col`, **may spill above
    `$100`** (up to `$13F` for an 8×32 canvas). BB scenes don't conflict with
    engine UI in this range — this is the documented exception.
  - **WB** (`INVERT≠$00`): bounded pool `$21..$FF`, **strictly `< $100`**.
    Tiles `≥ $100` are engine territory (kanji / chrome / icons) and must
    never be wiped or rewritten. Pool exhaustion → fallback to tile `$20`
    blank.
- **Per-character index gate** at line 543 (`CMP #$0100`) is unchanged: any
  character whose **char value** is `≥ $100` passes through to original tile
  path regardless of polarity. (Char index gate is independent of tile_id
  range.)
- **Mixing VWF + non-VWF tiles**: out-of-range chars (chrome, icons, kanji) pass
  through to the engine's original tile path at full width.
- **No hard coding**: drop `VWFGateAllowList`, drop per-scene pool ranges, drop
  per-emit `VRAM_BASE` overrides.
- **BB inheritance**: BB scenes use the same render path as WB; only the
  polarity-controlled blank value + font source differ.
- **Pay attention to 8/16-bit register state** (M, X flags via REP/SEP). This
  has burned us multiple times; see "Register-state discipline" below.

---

## Target architecture — at a glance

```
[cls] or scene-change → SceneInit (queue)
                          │
                  next NMI vblank
                          ↓
            polarity-dependent DMA wipe of VWF VRAM range:
              BB: VRAM[$6100..$6900]   = $00 (256 tiles × 16 B = 4096 B)
              WB: VRAM[$6100..$67FF]   = $FF (224 tiles × 16 B = 3584 B; STRICT cap at tile $FF)
            DMA-fill canvas[$7F:7000..$7FFF] = polarity_blank (in-loop, no vblank needed)
            CELL_TILE[256] = $FFFF                            (used by WB only)
            POOL_NEXT = $0021                                 (used by WB only; cap = $0100)
            DIRTY/DMA range / LAST_COL reset

per text emit (PreRender → processText → PostRender → NMI):
   PreRender:
     - polarity = $70 bit 7
     - if (text-source ptr changed) OR (polarity flipped) → queue SceneInit
     - reset PEN, PREV_COL, partial canvas-pen-forward wipe (existing)
     - DIRTY/DMA bounds reset

   per char (CharHandler):
     - if char_value >= $100 OR in [$00..$1F] OR in [$F0..$FF] → .doOrig (passthrough)
     - else → .doRender:
         · width lookup
         · width 0 (space) → tilemap = $20 + palette; advance pen 8 px
         · width > 0 → rasterize 16 rows into canvas[cell]
                       BB:   tile_id = $20 + row*32 + col   (formula, may exceed $100)
                       WB:   if rasterizer didn't touch any pixel → blank_glyph path:
                               tilemap = $20 + palette; do NOT allocate; do NOT mark dirty
                             else if CELL_TILE[cell] != $FFFF → reuse stored tile_id
                             else allocate POOL_NEXT++ (cap $00FF; exhaustion → tile $20)
                       tilemap write = tile_id + palette (top + bot share via +$0400 pal)
                       extend DMA_LO/HI to cover row end (existing — BB and non-blank WB)

   PostRender: arm DIRTY for NMI

   NMI:
     - if SceneInit pending → run VRAM wipe DMA (channel 7, polarity-sized), clear flag
     - if DIRTY → single contiguous DMA canvas[LO..HI] → VRAM[$6100 + LO/2]
     - reset DIRTY / DMA bounds
```

**Hard invariants the new code MUST guarantee:**
1. WB pool never produces a tile_id `≥ $00FF`. Audit: `CMP #$0100, BCS .blank`
   in the alloc-path is the only allowed gate.
2. WB SceneInit wipe DAS register is `≤ $0E00` (3584 bytes). Wipe never
   touches VRAM byte `≥ $D000` (= tile_id `$100`+).
3. BB SceneInit wipe DAS register is `≤ $1000` (4096 bytes; covers `$20..$11F`).
   BB still tolerates rendering up to tile `$13F` because BB scenes don't
   collide with engine UI in `$100..$13F` — the wipe just doesn't pre-clear
   that overflow region; canvas+DMA writes overwrite it directly.

---

## Constants & state — the new layout

Update `asm/vwf_patch.asm` headers. **Removed** state slots are marked with
strikethrough; **renamed/repurposed** are flagged.

```asm
; ============================================================================
; VWF VRAM-owned tile ranges — polarity-dependent
;
; WB is the constrained mode: tile_ids strictly < $100. Tiles >= $100 are
; engine territory (kanji / chrome / icons / sprites) — wipe must not touch
; them, pool must not allocate them.
;
; BB is the spill-tolerant mode: tile_ids may exceed $100 (formula naturally
; produces $20..$13F for an 8x32 canvas). BB scenes don't collide with engine
; UI in this range, so the spill is safe. The wipe pre-clears only $20..$11F
; (matching the original BB behavior); the formula's overflow into $120..$13F
; is fine because canvas-DMA writes those tiles directly with rendered pixels
; (no untouched-tile-blank-correctness requirement for BB's overflow rows).
; ============================================================================
!VWF_TILE_BASE       = $0020              ; first tile in VWF range (both modes)
!VWF_BLANK_TILE_ID   = $0020              ; canonical blank — never rewritten by VWF
                                          ;   used by WB blank-glyph shortcut + gap fill

; --- WB-specific (bounded pool) ---
!VWF_WB_POOL_FIRST   = $0021              ; first allocatable tile_id (skips $20)
!VWF_WB_TILE_LIMIT   = $0100              ; HARD CAP — pool exhaustion at $00FF+1
                                          ;   (CMP #!VWF_WB_TILE_LIMIT, BCS = exhausted)
!VWF_WB_WIPE_BYTES   = $0E00              ; 224 tiles × 16 B = 3584 B
                                          ;   covers VRAM bytes $C200..$CFFF
                                          ;   (= word $6100..$67FF inclusive)

; --- BB-specific (formula, allowed to spill) ---
!VWF_BB_WIPE_BYTES   = $1000              ; 256 tiles × 16 B = 4096 B
                                          ;   covers VRAM bytes $C200..$D1FF
                                          ;   (= word $6100..$68FF inclusive)
                                          ;   formula spill ($120..$13F) overwritten
                                          ;   by canvas DMA, no pre-wipe needed there

; --- Common ---
!VWF_VRAM_WORD_BASE  = $6100              ; tile $20 word addr in BG3 char data
                                          ;   ($6100 word = $C200 byte = tile_id $20)

; ============================================================================
; State block ($7F:5D00..)
; ============================================================================
!VWF_DIRTY    = $7F5D00
!VWF_DMA_LO   = $7F5D02
!VWF_DMA_HI   = $7F5D04
!VWF_PREV_COL = $7F5D06
!VWF_PX       = $7F5D08
!VWF_FLAG     = $7F5D0A
!VWF_SAVX     = $7F5D0C
!VWF_ROW      = $7F5D0E
!VWF_CHAR     = $7F5D10
!VWF_INVERT   = $7F5D12

; Scene-change detection
!VWF_TEXT_LO       = $7F5D14
!VWF_TEXT_HI       = $7F5D15
!VWF_TEXT_BNK      = $7F5D16
!VWF_LAST_INVERT   = $7F5D17    ; (was VWF_GATE) polarity captured at last SceneInit
!VWF_LAST_TEXT_LO  = $7F5D18    ; (was VWF_VRAM_BASE) text src LO at last SceneInit
!VWF_LAST_TEXT_HI  = $7F5D19    ;                     text src HI at last SceneInit
!VWF_LAST_TEXT_BNK = $7F5D1A    ;                     text src BNK at last SceneInit
!VWF_SCENE_INIT_PENDING = $7F5D1B  ; (was VWF_BLANK_TILE_VALID) $A5 = NMI must wipe VRAM
!VWF_BLINK         = $7F5D1C    ; cursor-blink one-shot (relocated)

; --- Removed: VWF_CHROME_LO/HI ($7F5D1C/E) — chrome-skip mechanism is dead.
;     Tile $20 acts as universal blank; engine UI lives outside $20..$11F or
;     via passthrough chars (>= $100).

; Debug counter (kept)
!VWF_DBG_CAPCOUNT  = $7F5D60

; --- Removed: VWF_BITMAP, VWF_BMP_TMP, VWF_BMP_CELL ($7F5D40..$5D5F)
;     Bitmap-walk DMA is gone — single-DMA path used for both polarities.

; --- Pool allocator (simplified) ---
!VWF_POOL_NEXT     = $7F5DBA    ; next tile_id to hand out (16-bit)
!VWF_CELL_INIT     = $7F5DBC    ; $A5 = CELL_TILE valid (post-SceneInit sentinel)
!VWF_CELL_TILE     = $7F5E00    ; 256 × 16-bit allocated tile_id; $FFFF = unalloc
!VWF_LAST_COL      = $7F5DBD    ; gap-fill tracker (kept)

; --- Removed: VWF_POOL_RANGES ($7F5DA0..$5DBC), VWF_POOL_RNG_OFF, VWF_POOL_REMAIN
;     Replaced by single bump-pointer allocator (POOL_NEXT++ until $11F).

; Scratch (kept verbatim — DP-collision-safe, register-state-tested)
!VWF_TMP_CHAR/W/ROW/COL/SHIFT/BASE/FBI/ORIG/SHFT/POS  (unchanged $7F5D20..$5D31)

!TILE_BUF    = $7F7000
!CANVAS_SIZE = $1000
!VWF_MAX_COL = $0020
```

---

## Phase 1 — Constants + state header rewrite

**File**: `asm/vwf_patch.asm` lines 60–315 (state section)

- Replace state-block comments with the layout above.
- Add the `!VWF_TILE_BASE`/`COUNT`/`LIMIT`, `!VWF_BLANK_TILE_ID`,
  `!VWF_POOL_FIRST`, `!VWF_VRAM_WORD_BASE`, `!VWF_VRAM_WIPE_WORDS` defines.
- Rename `!VWF_GATE → !VWF_LAST_INVERT`, `!VWF_VRAM_BASE → !VWF_LAST_TEXT_LO`
  family, `!VWF_BLANK_TILE_VALID → !VWF_SCENE_INIT_PENDING`. Re-purposing reuses
  WRAM addrs so the layout stays compact.
- Delete (comment-out, then remove) `!VWF_POOL_RANGES`, `_RNG_OFF`, `_REMAIN`,
  `!VWF_BITMAP`, `!VWF_BMP_TMP`, `!VWF_BMP_CELL`, `!VWF_CHROME_LO/HI`.

---

## Phase 2 — `VWFSceneInit` routine (the heart of the change)

**Replaces**: `VWFInitBlankTile` (line 1774), `VWFInitCellTable` (line 1833),
the per-emit canvas wipe in `VWFClsHook` (lines 1225–1238).

Two parts:

### 2a. `VWFRequestSceneInit` (callable from ClsHook + PreRender, M=any)

```asm
; M/X-AGNOSTIC entry. Preserves caller M/X via PHP/PLP.
; Side effects: sets pending flag, resets canvas + CELL_TILE + POOL_NEXT
;               + state immediately. Defers VRAM wipe to NMI.
VWFRequestSceneInit:
    PHP                                    ; ENTRY: M/X unknown
    REP #$30                               ; M=16, X=16 inside helper

    ; --- Polarity + capture last-scene fingerprint -----------------------
    SEP #$20                               ; M=8 for byte reads
    LDA.B $70 : AND.B #$80
    STA.L !VWF_INVERT
    STA.L !VWF_LAST_INVERT                 ; remember polarity at this init

    LDA.L !VWF_TEXT_LO  : STA.L !VWF_LAST_TEXT_LO
    LDA.L !VWF_TEXT_HI  : STA.L !VWF_LAST_TEXT_HI
    LDA.L !VWF_TEXT_BNK : STA.L !VWF_LAST_TEXT_BNK
    REP #$20                               ; M=16

    ; --- Canvas wipe ($7F:7000..$7FFF, polarity fill) --------------------
    SEP #$20 : LDA.L !VWF_INVERT : REP #$20
    BEQ .canvasFillBlack
    LDA.W #$FFFF : BRA .canvasFillReady
.canvasFillBlack:
    LDA.W #$0000
.canvasFillReady:
    LDX.W #$0000
.canvasLoop:
    STA.L !TILE_BUF,X
    INX : INX
    CPX.W #!CANVAS_SIZE
    BCC .canvasLoop

    ; --- CELL_TILE = $FFFF (unallocated) ---------------------------------
    LDX.W #$01FE
    LDA.W #$FFFF
.cellLoop:
    STA.L !VWF_CELL_TILE,X
    DEX : DEX
    BPL .cellLoop

    ; --- Pool cursor (WB only — BB ignores POOL_NEXT, uses formula) -------
    ; Pool runs $21..$FF inclusive (223 allocatable tile_ids). Exhaustion
    ; (POOL_NEXT == $0100) routes to .blankGlyph fallback in CharHandler.
    LDA.W #!VWF_WB_POOL_FIRST              ; $0021
    STA.L !VWF_POOL_NEXT

    ; --- DIRTY / DMA bounds / gap tracker reset ---------------------------
    LDA.W #$FFFF : STA.L !VWF_DMA_LO       ; sentinel "no range"
    STZ.L !VWF_DMA_HI
    SEP #$20
    STZ.L !VWF_DIRTY
    LDA.B #$FF : STA.L !VWF_LAST_COL
    LDA.B #$A5 : STA.L !VWF_CELL_INIT
    STA.L !VWF_SCENE_INIT_PENDING          ; tell NMI: do VRAM wipe next vblank
    REP #$20

    PLP                                    ; EXIT: caller M/X restored
    RTL
```

### 2b. `VWFNMIVramWipe` (NMI-side, runs during vblank)

```asm
; ENTRY: M=8, X=16 (NMI prelude already set; see VWFNMI header).
; EXIT:  M=8, X=16. Channel 7 reconfig harmless; NMI continues.
;
; Strategy: DMA mode 1 (alternating B at $2118/$2119) + FIXED source (DMAP bit
; 3 = 1) lets a single source byte fill the entire range. Source = 1 byte
; ($00 for BB, $FF for WB). DAS = polarity-dependent:
;   BB → $1000 (4096 B = 256 tiles, covers $20..$11F)
;   WB → $0E00 (3584 B = 224 tiles, covers $20..$FF; STRICT cap)
; ROM cost: 2 bytes total ($00 and $FF).
VWFNMIVramWipe:
    SEP #$20
    LDA.B #$80 : STA.W $2115                ; VMAIN = word-inc on $2119 high
    LDA.B #$09 : STA.W $4370                ; DMAP7 = mode 1 + FIXED source (bit 3 set)
    LDA.B #$18 : STA.W $4371                ; BBAD7 = $2118 (VMDATAL)
    LDA.B #bank(VWFVramWipeBytes) : STA.W $4374  ; A1B7

    LDA.L !VWF_INVERT
    BEQ .wipeBlackBB
    ; --- WB: $FF byte source, $0E00 byte DAS (HARD CAP) -----------------
    REP #$20
    LDA.W #VWFVramWipeBytes+1 & $FFFF       ; addr of $FF byte
    STA.W $4372
    LDA.W #!VWF_WB_WIPE_BYTES               ; DAS7 = $0E00 = 3584 bytes
    BRA .doWipe
.wipeBlackBB:
    ; --- BB: $00 byte source, $1000 byte DAS ----------------------------
    REP #$20
    LDA.W #VWFVramWipeBytes & $FFFF         ; addr of $00 byte
    STA.W $4372
    LDA.W #!VWF_BB_WIPE_BYTES               ; DAS7 = $1000 = 4096 bytes
.doWipe:
    STA.W $4375                             ; commit DAS
    LDA.W #!VWF_VRAM_WORD_BASE              ; VMADDR = $6100
    STA.W $2116

    SEP #$20
    LDA.B #$80 : STA.W $420B                ; trigger ch7
    STZ.L !VWF_SCENE_INIT_PENDING           ; clear the pending sentinel
    RTS                                     ; back to NMI
```

**ROM data** (2 bytes, append at any free slot in bank `$E0`):

```asm
VWFVramWipeBytes:
    db $00, $FF      ; +0 = BB blank, +1 = WB blank
```

ROM cost: 2 bytes. Bank `$E0` has plenty of room (current code ends ≈
`$E0:A411`). Place these at `$E0:A810` next to `VWFCaptureSource` to keep
the data block tight. **Verify with `warnpc`** that nothing collides.

---

## Phase 3 — Refactor `VWFCharHandler` (collapse BB/WB split)

**File lines**: 425–1011 (entire CharHandler).

Key changes (preserve everything that works in BB):

### 3a. Keep verbatim
- `.origPath` (435–441)
- Cursor-blink suppression (443–459)
- Newline detection + per-row polarity fill (461–522)
- Same-line col-jump pen reset (523–538)
- Char-index gate `< $100`, `$00..$1F`, `$F0..$FF` (540–548) — **this is the new
  canonical gate**
- `.doOrig` snap-up + tilemap-write (550–585)
- Width-0 handling (597–615)
- Width lookup, row/col/shift/base/FBI math (587–656)
- Saturation guard `.inBounds` (630–636)
- The 16-row rasterization loop with polarity-aware OR vs AND-NOT writes
  (658–780). **Critically including the M=16 wrap on `LDA.L !VWF_TMP_SHIFT` at
  lines 670–676** — that's the past LDA-with-stale-B bug fix.
- Spillover handling (726–776)

### 3b. Track "did this glyph rasterize anything?"

Add a sentinel slot reused from removed bitmap state:

```asm
!VWF_TMP_DREW = $7F5D32         ; (reuse old VWF_BMP_TMP slot) 1 byte: $00 = no
                                ; pixels written, $A5 = at least one set/cleared
```

In `.doRender` prelude (around line 644), add:
```asm
SEP #$20 : STZ.L !VWF_TMP_DREW : REP #$20
```

In `.skipWrite` paths (lines 712–724) — every place we actually OR or AND-NOT —
set the flag:
```asm
; BB row-write (after the ORA/STA at line 717):
SEP #$20 : LDA.B #$A5 : STA.L !VWF_TMP_DREW : REP #$20
; ditto WB (after AND/STA line 723) and the spillover paths (lines 765, 771).
```

(Cheaper alternative once we trust this: precompute "is_blank" per glyph at
build time; see Phase 7 follow-up. For Phase 3 we keep it runtime.)

### 3c. Refactor `.normalTilemap` — share gap-fill, split tile_id source

Keep the BB/WB branch but compress it. Both paths share gap-fill (was WB-only;
generalize because BB also benefits from engine col-jumps), share the final
`.tilemapWrite` block, and share the blank-glyph shortcut. Only the tile_id
**source** differs:

```asm
.normalTilemap:
    ; --- Step 1: gap-fill (UNIVERSAL — both polarities) ------------------
    ; Pre-paint cells [LAST_COL+1 .. $09FC-1] with tilemap = $20 + palette.
    ; This is the existing WB gap-fill code, hoisted out of the WB branch.
    PHX                                    ; save tilemap-byte-offset (M=16 entry)
    SEP #$20
    LDA.L !VWF_LAST_COL
    CMP.B #$FF
    BEQ .gapDone                           ; first write, no prior col
    INC A
    CMP.W $09FC
    BCS .gapDone
    REP #$20
    LDA.B $01,S                            ; peek caller_X
    SEC : SBC.W $09FC : SBC.W $09FC        ; base_X = caller_X - $09FC*2
    PHA                                    ; stack: $01-2=base_X, $03-4=caller_X
    SEP #$20
    LDA.L !VWF_LAST_COL : INC A
.gapLoop:
    CMP.W $09FC
    BCS .gapCleanup
    PHA
    REP #$20
    AND.W #$00FF : ASL A : CLC : ADC.B $02,S
    TAX
    LDA.W $0A02
    CLC : ADC.W #!VWF_BLANK_TILE_ID        ; tile $20 + palette
    STA.L $7E9000,X
    CLC : ADC.W #$0400
    STA.L $7E9040,X
    SEP #$20
    PLA : INC A
    BRA .gapLoop
.gapCleanup:
    REP #$20
    PLA                                    ; pop base_X
    SEP #$20
.gapDone:
    LDA.W $09FC : STA.L !VWF_LAST_COL
    REP #$20

    ; --- Step 2: tile_id source — polarity branch ------------------------
    SEP #$20
    LDA.L !VWF_INVERT
    REP #$20
    BNE .wbTileId

    ; --- BB: formula, may spill above $100 (allowed for BB-only scenes) -
    LDA.L !VWF_TMP_ROW                     ; canvas row 0..7
    ASL A : ASL A : ASL A : ASL A : ASL A  ; row * 32
    CLC : ADC.W $09FC                      ; + col
    CLC : ADC.W #!VWF_TILE_BASE            ; + $20  (no cap — BB allowed to spill)
    BRA .haveTileId

.wbTileId:
    ; --- WB: blank-glyph shortcut OR per-cell pool allocation -----------
    SEP #$20
    LDA.L !VWF_TMP_DREW
    REP #$20
    BEQ .wbBlank                           ; nothing rasterized → tile $20

    ; CELL_TILE[cell] lookup
    LDA.L !VWF_TMP_ROW
    AND.W #$0007
    ASL A : ASL A : ASL A : ASL A : ASL A  ; row * 32
    CLC : ADC.W $09FC                      ; + col
    AND.W #$00FF
    ASL A                                  ; cell * 2
    TAX
    LDA.L !VWF_CELL_TILE,X
    CMP.W #$FFFF
    BNE .haveTileId                        ; reuse stored tile_id

    ; First encounter — allocate from pool ($21..$FF, hard cap at $0100).
    LDA.L !VWF_POOL_NEXT
    CMP.W #!VWF_WB_TILE_LIMIT              ; >= $0100 → exhausted (HARD CAP)
    BCS .wbBlank                           ; exhaustion → blank fallback
    PHA                                    ; save tile_id
    INC A
    STA.L !VWF_POOL_NEXT                   ; bump pool cursor
    PLA
    STA.L !VWF_CELL_TILE,X                 ; remember for next emit
    BRA .haveTileId

.wbBlank:
    LDA.W #!VWF_BLANK_TILE_ID              ; tile $20 — canonical blank
    ; fall through (don't extend DMA bounds for blank — see Step 3)

.haveTileId:                               ; ENTRY: M=16, A=tile_id
    PLX                                    ; restore tilemap-byte-offset

.tilemapWrite:                             ; ENTRY: M=16, A=tile_id, X=tilemap byte off
    PHA
    CLC : ADC.W $0A02
    STA.L $7E9000,X                        ; TOP entry
    PLA
    CLC : ADC.W $0A02
    CLC : ADC.W #$0400
    STA.L $7E9040,X                        ; BOT entry (same tile_id, +pal row)
```

**Step 3 — DMA-bound update** (unchanged for BB and non-blank WB; **skipped**
for `.wbBlank` path since blank tiles need no canvas DMA — tile $20's VRAM is
permanent from SceneInit). Wrap the existing DMA-bound code (current lines
820–833) with:

```asm
    ; Skip DMA-bound extend on WB blank-glyph path (no canvas data to upload).
    SEP #$20
    LDA.L !VWF_INVERT : BEQ .extendDma     ; BB always extends
    LDA.L !VWF_TMP_DREW : BEQ .skipDmaExtend ; WB blank → skip
.extendDma:
    REP #$20
    ; ... existing lines 820-833 unchanged ...
.skipDmaExtend:
    REP #$20
```

### 3d. Update DMA bound tracking (lines 812–833)

Keep the existing "extend HI to row end" logic unchanged — it already handles
the contiguous-DMA-covers-trailing-blanks case. But move the `STA.L !VWF_DIRTY`
to happen even on **blank glyphs that gap-fill** — gap-filled cells need the
DMA to cover them too (their tile_id already points to `$20`, but only because
we wrote the tilemap; canvas itself stays blank from SceneInit).

Actually re-examine: the DMA bound logic operates on canvas bytes, not tilemap.
For a blank glyph, we write tile $20 to tilemap (no canvas touch needed because
$20's VRAM is permanent). So **don't** extend DMA bounds on blank glyphs — they
have no canvas data to DMA. Skip the DMA-bound-extend block (lines 820–833) on
the `.blankGlyph` path. Tilemap write alone is sufficient.

---

## Phase 4 — `VWFPreRender` scene-change detection

**File lines**: 1013–1156

Insert after the polarity capture (around line 1023), before the displaced setup:

```asm
    ; --- Scene-change detection ------------------------------------------
    ; Compare current (polarity, text-source) against last-seen at SceneInit.
    ; Any change → request scene init (which DMAs polarity wipe in next NMI).
    SEP #$20
    LDA.L !VWF_INVERT      : CMP.L !VWF_LAST_INVERT   : BNE .needInit
    LDA.L !VWF_TEXT_LO     : CMP.L !VWF_LAST_TEXT_LO  : BNE .needInit
    LDA.L !VWF_TEXT_HI     : CMP.L !VWF_LAST_TEXT_HI  : BNE .needInit
    LDA.L !VWF_TEXT_BNK    : CMP.L !VWF_LAST_TEXT_BNK : BEQ .sceneSame
.needInit:
    REP #$20
    JSL.L VWFRequestSceneInit               ; resets canvas, CELL_TILE, queues VRAM wipe
    SEP #$20
.sceneSame:
    REP #$20
```

**Strip out**:
- `VWFGateDecision` JSL (line 1039) — gate is now per-char index check inside
  CharHandler. Remove the routine entirely (lines 1644–1760) along with
  `VWFGateAllowList` (1898–1955).
- The `.gateOn`/`.gateOff` branch (1041–1048).
- The `VWFInitCellTable` JSL (line 1058) — folded into `VWFRequestSceneInit`.

Keep lines 1063–1155 (LAST_COL reset, PEN init, VWF_ROW init, PREV_COL, FLAG arm,
DIRTY range reset, partial canvas wipe, bitmap clear). The bitmap clear (lines
1146–1153) becomes unnecessary since `!VWF_BITMAP` is removed — delete that
block.

---

## Phase 5 — `VWFClsHook` and `VWFNMI` simplification

### 5a. ClsHook (lines 1199–1276)

Replace the entire body after the `JSL.L $81ECE1` (line 1200) with:

```asm
VWFClsHook:
    JSL.L $81ECE1                           ; displaced original
    JSL.L VWFRequestSceneInit               ; canvas+state reset, NMI does VRAM wipe
    RTL
```

Saves ~75 bytes. The `VWF_FLAG`-conditional canvas wipe (the
`BNE .done`/`.done:` skip at 1220–1273) is gone — SceneInit is unconditional on
[cls] because the engine just rewrote the tilemap to blanks; matching VWF
state is correct.

### 5b. VWFNMI (lines 1294–1425)

Inject `VWFNMIVramWipe` invocation BEFORE the DIRTY check:

```asm
VWFNMI:
    PHP : REP #$30 : PHA : PHX : PHY        ; (unchanged displaced + preserve)

    SEP #$20
    LDA.L !VWF_SCENE_INIT_PENDING
    CMP.B #$A5
    BNE .checkDirty
    JSR.W VWFNMIVramWipe                    ; runs DMA, clears the pending flag

.checkDirty:
    LDA.L !VWF_DIRTY
    CMP.B #$A5
    BNE .skipDMA
    ; ... existing single-DMA setup (lines 1322–1362) UNCHANGED ...
```

**Delete** the strategy selector (lines 1331–1336) and entire bitmap-walk path
(lines 1366–1400). Single-DMA is universal.

`vwfDoDmaForCell` (lines 1435–1487) — delete.

`VWFInitBlankTile` (lines 1774–1818) — delete.

`VWFBlankTileData` (lines 1816–1818) — delete.

`VWFInitCellTable` (lines 1833–1859) — delete (subsumed).

`VWFGateDecision` (lines 1661–1760) — delete.

`VWFGateAllowList` (lines 1898–1955) — delete.

`vwfAllocOne` (lines 1540–1581) — delete (replaced by inline bump in 3c).

---

## Phase 6 — Hook 6 (capture) survives, helper trims

`VWFCaptureSource` at `$E0:A800` (lines 1620–1642) stays — it's now load-bearing
for scene-change detection. Keep the debug counter increment.

---

## Register-state discipline (CRITICAL — user reminder)

The current code has documented past regressions from M/X mismatches:
- Lines 670–676: `LDA.L !VWF_TMP_SHIFT` in M=8 with stale B byte → TAX got
  $1XXX, LSR loop ran ~4000× (entire VWF broke).
- Lines 787–788: bitmap math required `REP #$20` because M=8+X=16 TAX transferred
  the stale "B" byte into X.high.
- Line 446 area: `REP #$20` before branching to `.vwf` — restoring 16-bit
  *before* a BNE keeps any stack/register width assumptions of the target
  routine intact.

**Invariants for new + edited code**:

| Routine | Entry | Body | Exit |
|---|---|---|---|
| `VWFRequestSceneInit` | M/X any (PHP first) | M=16/X=16 throughout helper interior; SEP for byte ops only | restored via PLP |
| `VWFNMIVramWipe` | M=8, X=16 (NMI prelude) | mostly M=16 for word DMA regs; SEP only for byte regs ($2115, $4370/71/74, $420B) | M=8, X=16 |
| `VWFCharHandler` (new code) | M=16 from `JSL.L` (caller convention; verify by reading hook prelude at $80:C17B) | every SEP marked, every REP marked, paired in linear flow | M=16 before any RTL |
| `VWFPreRender` scene-detect insert | M=16 (caller convention) | wrap in SEP/REP cleanly | M=16 before continuing |

**Boundary rules**:
1. Every `JSL.L` boundary requires the callee to either preserve M/X via PHP/PLP
   *or* document its expected entry/exit M/X explicitly in a header comment.
2. Every BCC/BCS/BEQ/BNE that jumps OUT of a SEP-narrowed block must restore
   M=16 before the branch (existing pattern at lines 446, 459, 478, etc.).
3. Any `LDA.L slot` followed by `TAX` MUST be in M=16 if `slot` is 16-bit, OR
   in M=8 if `slot` is byte-sized; a 16-bit `slot` read in M=8 takes only the
   low byte and TAX will copy the stale B byte into X.high.
4. `INC A` widths follow M; document explicitly when incrementing pool/counter
   slots (`POOL_NEXT` is 16-bit → INC A in M=16; `LAST_COL` is 8-bit → INC A
   in M=8).
5. After any code change, run `grep -n "TAX\|TAY\|LDA.L\|STA.L\|INC A\|DEC A"`
   on the modified routines and audit each call's surrounding M/X state.

A short audit comment block goes above each modified routine recording its
expected M/X-at-entry and exit.

---

## Phase 7 — Cleanup + space accounting

After all deletions:

- Update `warnpc` markers (line 1185 `$E09000`, 1276 `$E09200`, 1583 `$E09400`)
  to reflect new code-end addresses. Code shrinks by ~600 bytes.
- Audit `org` directives — `VWFCaptureSource` at `$E0:A800` may move closer.
- `incbin` paths unchanged: `font_accented_widths.bin`, `font_accented_1bpp.bin`.
- Add new ROM data: `VWFVramWipeBytes` (2 bytes: `$00, $FF`). Place at
  `$E0:A810` (after `VWFCaptureSource` body). **Add `warnpc $E0:A820`** to
  assert no overrun.
- Build flow unchanged: `./build.sh` (which is `retrotool build project.toml -D version=vwf`).

**Optional follow-up** (not in this single pass; document in TODO):
- Precompute per-glyph "is_blank" bit at build time
  (`tools/vwf_*` Python emits a 32-byte bitfield alongside widths).
  Replaces the runtime `VWF_TMP_DREW` check with one `BIT` against the
  bitfield. Save ~4 cycles/char.

---

## Critical files & line-anchored change list

| File | Lines | Change |
|---|---|---|
| `asm/vwf_patch.asm` | 60–315 | rewrite state-block headers + new constants |
| `asm/vwf_patch.asm` | 425–1011 | refactor CharHandler — unify BB/WB tilemap paths, add `.blankGlyph` short-circuit, rasterization-touched flag |
| `asm/vwf_patch.asm` | 1013–1156 | PreRender — add scene-change detect; remove gate-decision JSL; remove bitmap clear |
| `asm/vwf_patch.asm` | 1199–1276 | ClsHook — collapse to JSL displaced + JSL VWFRequestSceneInit |
| `asm/vwf_patch.asm` | 1294–1425 | NMI — drop bitmap-walk; insert NMIVramWipe call |
| `asm/vwf_patch.asm` | 1435–1487 | delete `vwfDoDmaForCell` |
| `asm/vwf_patch.asm` | 1540–1581 | delete `vwfAllocOne` (inline bump in CharHandler) |
| `asm/vwf_patch.asm` | 1644–1760 | delete `VWFGateDecision` |
| `asm/vwf_patch.asm` | 1774–1818 | delete `VWFInitBlankTile` + data |
| `asm/vwf_patch.asm` | 1833–1859 | delete `VWFInitCellTable` |
| `asm/vwf_patch.asm` | 1898–1955 | delete `VWFGateAllowList` |
| `asm/vwf_patch.asm` | new (`$E0:8xxx`) | add `VWFRequestSceneInit` |
| `asm/vwf_patch.asm` | new (`$E0:9xxx`) | add `VWFNMIVramWipe` |
| `asm/vwf_patch.asm` | new (`$E0:A810`) | add `VWFVramWipeBytes` (2 B: `$00, $FF`) |
| `tools/vwf_gate_probe.py` | top | remove `VWF_GATE`, `VRAM_BASE`, `BITMAP`, `BMP_TMP/CELL`, `POOL_*` slots; add `LAST_INVERT`, `LAST_TEXT_*`, `SCENE_INIT_PENDING`, `POOL_NEXT` |
| `tools/debug_vwf_probe.py` | similar | mirror state-block changes |
| `tools/ownership/file_info.json` | (untouched) | becomes vestigial — leave for now, can prune later |

---

## Verification (single-pass execution end-state)

After build (`./build.sh --no-cache` per memory `feedback_build_no_cache.md`):

1. **BB regression — typewriter dialog**
   Boot, advance to first dialog box (any scenario intro). Verify text renders
   identically to the prior `df3a737` build (compare against a saved screenshot
   if available). Run through 2–3 dialog frames; confirm no glyph residue, no
   line corruption.

2. **WB single paint — file-info menu open**
   Boot → main menu → File Info. Confirm all 3 file slots render their initial
   text correctly with white background. No engine-UI corruption.

3. **WB multiple paints — file-info navigate**
   In the File Info screen, press up/down to move the cursor between slots.
   Each cursor-move repaints the menu; verify no canvas mangling, no leftover
   glyphs from prior cursor positions, no chrome corruption.

4. **WB → BB transition**
   From File Info, back out to main menu, enter a scenario, advance to dialog.
   Confirm the BB dialog renders cleanly (i.e., SceneInit fires at scene
   change and BB polarity wipe runs).

5. **Mixed VWF + non-VWF**
   Find any scene that mixes VWF glyphs with chrome or icons. Confirm icons
   render at original tile_ids (passthrough) and VWF text renders adjacent.

6. **Pool exhaustion (WB only)**
   Synthetic stress: long WB text scene with 224+ unique non-blank glyph cells.
   Beyond 223 allocations (pool runs $21..$FF) the fallback writes tile $20
   (visible blanks). Confirm no crash, no garbage — just truncation.
   Verify no tile_id ever exceeds `$00FF` in CELL_TILE on a WB scene.
   For BB scenes, tile_ids may legitimately reach `$13F` (formula spill); the
   audit must distinguish polarity before flagging.

7. **Mesen IPC checks**
   - Pause emulator after any text emit. Read `$7F:5D1B`
     (`VWF_SCENE_INIT_PENDING`) — should be `$00` between frames.
   - Check `$7F:5D12` (`VWF_INVERT`) to know polarity context first.
   - **WB context**: read `$7F:5DBA` (`VWF_POOL_NEXT`) — should be in
     `$0021..$0100`. Any value `> $0100` is a bug (pool overran the hard cap).
   - **WB context**: read `$7F:5E00` first 16 bytes (`VWF_CELL_TILE[0..7]`) —
     non-`$FFFF` for cells with content, `$FFFF` for unallocated. Any
     allocated value `≥ $0100` is a bug.
   - **WB context**: read VRAM `$6800..$68FF` (= bytes after WB's $0E00 wipe
     range) and confirm it was NOT clobbered (engine UI / kanji territory).
   - **BB context**: VRAM up to `$68FF` may be wiped or written; up to `$69FF`
     may hold formula-spill tiles ($120..$13F). Beyond is engine territory.
   - Use `tools/vwf_gate_probe.py` (after probe-side update) to dump full state.

8. **Register-state audit**
   `grep -n "TAX\|TAY\|LDA.L\|INC A" asm/vwf_patch.asm` on changed routines;
   visually confirm M/X width matches data width at every site.

If any verification step fails, **stop and root-cause**, do not patch over.
Per memory `feedback_one_fix_at_a_time.md`: but this plan is the documented
"atomic-coupled refactor exception" (`feedback_atomic_coupled_refactor.md`)
because canvas + DMA + tilemap + allocator stride change in lockstep.

---

## Out of scope

- Per-scene chrome-collision verification (WB only): tile range `$20..$FF` is
  assumed universally safe across all WB scenes. If a scene shows chrome
  corruption, the resolution is to re-route engine chrome to tile_ids `≥ $100`
  (separate task, not this plan). The hard cap at `$00FF` for WB wipe-DMA
  range and pool allocator is the strict enforcement of this invariant.
- BB chrome-collision checks: BB scenes are documented as the "spill exception"
  and assumed not to collide with engine UI in `$100..$13F`. If a BB scene
  shows chrome corruption in that range, the resolution is to migrate that
  scene to the WB-style bounded model (separate task).
- Build-time blank-glyph bitfield (Phase 7 follow-up).
- Pool exhaustion graceful degrade beyond "fall back to tile $20".
- `tools/ownership/` editor — vestigial after this change, plan its removal in
  a separate cleanup pass.
