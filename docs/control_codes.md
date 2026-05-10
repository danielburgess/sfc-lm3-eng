# LM3 Text Engine — Control Code Reference

This document is the authoritative reference for the FF-prefixed control codes consumed by Little Master III's text engine. All addresses are SNES bus addresses on `lm3.sfc` (LoROM, fast). PC offsets are reachable via `PC = (bank & 0x7F) * 0x8000 + (addr - 0x8000)`.

Every detail below was traced from the disassembly in `disassembly/lm3_bank80.asm` and verified against script byte patterns in `en_data/scripts/`.

---

## 1. Two-phase architecture

The engine is split across two routines that run on different ticks of the same text stream:

| Phase | Entry | Role |
|---|---|---|
| **Phase 1** — `fillTextBuffer_Phase1` | `$80:B67C` | Streams bytes from ROM at `[$14],Y` into the WRAM tilemap-staging buffer at `$0400`. Some FF codes are processed *inline* (event-style commands that mutate state but emit no buffer bytes); the rest are *passed through* into the buffer for Phase 2 to interpret. |
| **Phase 2** — `processText` / `renderTextStream` | `$80:BE3B` (entry `$80:BF64`) | Walks the staged `$0400` buffer, dispatches by byte value, and writes finished tilemap entries into the WRAM tilemap mirror at `$7E:9000` / `$7E:9040`. This is the layer that actually positions the cursor, picks palettes, and sequences pauses/scrolls. |

Phase 1 dispatches at `$80:B68D`:

```
LDA [$14],Y                     ; read next stream byte
BNE                             ; 0x00 ⇒ end-of-text
CMP #$09 BCC ffCode_HandleLow   ; 0x01-0x08 ⇒ kanji-tile reference
CMP #$FF BEQ ffCode_PeekNext    ; 0xFF ⇒ control prefix
STA $0400,X / INX / INY         ; 0x09-0xFE ⇒ literal character
```

Phase 1 sub-dispatch on the FF sub-code at `$80:B6D6`:

| Range | Action | Notes |
|---|---|---|
| `FF 01..1D` and `FF F1..FF` | `ffLowBufferCopy` at `$80:B775`: copy 3 bytes raw to `$0400` | Phase 2 sees the FF in the buffer and re-interprets it. |
| `FF 80..9C` | Jump table at `$80:B701` | Inline event commands: number rendering, pointer dereference, name copy, hardware multiply, etc. Not buffered. |
| `FF C0..EF` | `JMP $80:BB33` (FFC0 conditional redirect) | Inline. Conditional pointer rewrite of `$14/$15/$16` based on flag in `$54`. The "universal overflow" mechanism. |
| `FF F0` | (range-overlap with extended) | Treated as buffer copy by Phase 1. |

---

## 2. Length table (`@ctrl` directives in `eng.tbl` / `jap.tbl`)

`@ctrl XX=N` declares total byte length **including** the leading `FF` byte. The encoder uses these to keep multi-byte parameter sequences atomic during text packing.

```
@ctrl 00=2                       FF 00            (terminator)
@ctrl 01=4                       FF 01 ?? ??      (only known 4-byte short ctrl)
@ctrl 02..0F = 3                 FF XX YY         (cursor positioning)
@ctrl 10..1D = 3                 FF XX YY
@ctrl 1E=4                       FF 1E ?? ??
@ctrl 7F=3                       FF 7F YY         ([msg] mode flag)
@ctrl 80=3                       FF 80 PP         (set $0A08 = PP)
@ctrl 81=5                       FF 81 LL HH BB   (3-byte ptr → load byte to $0A08)
@ctrl 82=3                       FF 82 PP         ($0A08 = $0A08 * PP)
@ctrl 83..87 = 5                 FF XX LL HH BB   (3-byte ptr → render number)
@ctrl 88=6                       FF 88 LL HH BB ?? (raw-byte copy from ptr)
@ctrl 89..8B = 4                 FF XX ?? ??
@ctrl 8C..8E = 5                 FF XX LL HH BB
@ctrl 8F=2                       FF 8F            (no-op / passthrough)
@ctrl 90=2                       FF 90            (newline → Phase 2 dispatch)
@ctrl 91..93 = 5                 FF XX LL HH BB
@ctrl 94=4                       FF 94 LL HH      (16-bit param)
@ctrl 95..9C = 5                 FF XX LL HH BB
@ctrl C0..F0 = 5                 FF XX LL HH BB   (conditional redirect)
@ctrl F1..F3, FB, FD..FF = 3     FF XX YY         (Phase 2 extended)
@ctrl F2=3                       FF F2 NN         ([waitNN] / [pause])
@ctrl F6=2                       FF F6            (DTE return — historical)
@ctrl F7..F8 = 3                 FF XX II         (DTE redirect — historical)
@ctrl FA=4                       FF FA ?? ??      (end + post-process)
@ctrl FC=4                       FF FC PP ??      (choice/menu input)
```

Historical DTE codes (`F6/F7/F8`) are no longer applied — replaced by the universal `FFC0` redirect mechanism. They remain in the length table because legacy text dumps may contain them.

---

## 3. Phase-1 inline commands (FF 80–9C, jump table at `$80:B701`)

These run during Phase 1, mutate engine state, and write directly into the `$0400` buffer (or simply update WRAM). They are **never** themselves buffered.

| Code | Handler | Length | Effect |
|---|---|---|---|
| `FF 80 PP` | `ffCode80_SetParam` `$80:B78D` | 3 | `$0A08 = PP` (the universal text parameter / index). |
| `FF 81 LL HH BB` | `ffCode81_SetParamIndirect` `$80:B79C` | 5 | `$0A08 = byte at SNES $BB:HHLL` (after adding `$0A08` to LL — see `ffReadInlinePtr`). |
| `FF 82 PP` | `ffCode82_MultiplyParam` `$80:B7AE` | 3 | `$0A08 = $0A08 × PP` via SNES hardware multiplier (`$4202/$4203/$4216`). |
| `FF 83 LL HH BB` | `ffCode83_RenderWord` `$80:B7CB` | 5 | Read 16-bit value at ptr, render as 5-digit decimal. |
| `FF 84 LL HH BB` | `ffCode84_RenderByte` `$80:B7DD` | 5 | Read 8-bit value at ptr, render as 3-digit decimal. |
| `FF 85 LL HH BB` | `ffCode85_RenderClamped99` `$80:B810` | 5 | Read byte, clamp to 99, render as 2-digit decimal (used for unit numbers). |
| `FF 86 LL HH BB` | `ffCode86_RenderSingleDigit` `$80:B94A` | 5 | Read byte, clamp to 9, render as 1 ASCII digit (`+ $30`). |
| `FF 87 LL HH BB` | `ffCode87_CopyStringDirect` `$80:B961` | 5 | Copy bytes from ptr to buffer until `$00` or `$20`. Used for unit names in inline contexts. |
| `FF 88 LL HH BB CC` | `textRawCopyHandler` `$80:B985` | 6 | Copy `CC` raw bytes from ptr to buffer (no terminator scan). |
| `FF 89` / `FF 8A` / `FF 8B` | (jump-table slots, 4-byte) | 4 | Aux number/string helpers. |
| `FF 8C..8E LL HH BB` | (5-byte ptr ops) | 5 | Number/name renderers. `FF 8E` is the "lookup attack name into render slot" used by combat. |
| `FF 8F` | (2-byte) | 2 | No-op. |
| `FF 90` | (2-byte) | 2 | Newline. Phase 2 also handles `0x90` directly when seen in the `$0400` buffer. |
| `FF 91..93 LL HH BB` | (renderers) | 5 | Number/string variants — `FF 91 = renderCompoundName` (writes string + `$95` separator + second string, for two-part names like compound classes). |
| `FF 94 LL HH` | (4-byte) | 4 | `$0A08 += word at LLHH` — adds a 16-bit displacement. |
| `FF 95 LL HH BB` | `ffCode95_RenderClamped999` `$80:B88B` | 5 | Read 16-bit, clamp 999, render 3-digit. |
| `FF 96..9A LL HH BB` | (renderers) | 5 | Various number/string variants used by stats/combat (HP, MP, gold, etc.). |
| `FF 9B XX` | (3-byte) | 3 | Engine helper (text mode flag). |
| `FF 9C LL HH BB` | `ffCode_RenderStringLookup` `$80:B904` | 5 | Indirect string-table lookup at `$02:A050` (table 1) / `$02:A298` (table 2). Each entry is 8 bytes terminated by `$20`. |

`ffReadInlinePtr` (`$80:BB71`) is the helper used by every 5-byte inline command. It reads `LL HH BB`, then **adds `$0A08` to LL** with carry to `HH/BB`. This means commands like `FF 85 00 10 00` followed by `FF 80 NN` reference the *NN-th* entry of a table at `$00:1000` — the "set index, then read indexed table" idiom.

---

## 4. Phase-2 commands (interpreted from the `$0400` buffer at `$80:BF7D`)

When Phase 2 encounters `FF` in the buffer it runs `textStream_HandleFF`:

```
LDA [$14] / INC $14 / AND #$00FF       ; first param byte
CMP #$F0 BCS textStream_HandleExtended ; ≥F0 → extended dispatcher
CMP #$80 BEQ textStream_FFReadCode     ; ==80 → skip column write
AND #$001F / STA $09FC                 ; otherwise: column = param & 0x1F

textStream_FFReadCode:
LDA [$14] / AND #$00FF                 ; second param byte
CMP #$80 BCS textStream_FFHighMask     ; ≥80 → relative row
AND #$001F / STA $09FE / STZ $0A06     ; absolute row = param & 0x1F
INC $14 / JSR calculateBufferOffset    ; update $7E:9000 destination ptr
```

So **every `FF XX YY` where `XX` is `01..7F` (excluding `7F`) and `YY < $80`** is "set cursor to (XX, YY)". The two parameter bytes are masked to 5 bits, giving ranges 0–31 — sufficient to address every position in the 32×30 tilemap window.

When `YY ≥ $80`, `YY & 0x3F` is **subtracted** from the current row (`$09FE`), giving relative-up positioning. (Rare; the game prefers absolute.)

`calculateBufferOffset` at `$80:C233` computes:
```
X = ($09FC × 2) + (($09FE & $1F) × 64) + ($09FC × 2)   ; equivalent to col*2 + row*64
```
…which lands in the 32×N WRAM tilemap mirror starting at `$7E:9000`. Each tilemap entry is 2 bytes (`tile_lo`, `vhopppcc`).

### 4.1 Extended commands (`FF F0..FF`, dispatcher at `$80:BFF1`)

| Code | Handler | Length | Effect |
|---|---|---|---|
| `FF F0 ??` | default — JMP `$80:BE4F` (loop) | 3 | Effectively a no-op consume. |
| `FF F1 PP` | `textStream_ExtF1` `$80:BFC2` | 3 | If `PP == 1`: `$0A1E = 0` (disable special-render mode). Otherwise: `$0A1F = ((PP - 1) × 4) + $21` — sets the high byte of the tilemap-attribute base used by `textChar_CalcTileAddr`. See §5.4. |
| `FF F2 NN` | `textStream_ExtF2` `$80:BFE4` | 3 | Set auto-pause delay to `NN` frames; rendered as `[waitNN]` / `[pause]` in the .tbl. |
| `FF F3..F9` | (default branch in `ExtDispatch`) | 3 | Fall-through to default loop. |
| `FF FA ??` | `textStream_HandleExtended` (FA branch) | 4 | `INC $0A16` then `JMP textStream_Handle00` — terminates *this* render pass but flags an outer "more text pending" state. Used to chain two renders. |
| `FF FB SS` | `textStream_ExtFB` `$80:C041` | 3 | Set text Y row offset: `$0A03 = (SS × 8) + $20`. Encoded as `[white]` (`FF FB 00`) and `[pink]` (`FF FB 01`) — selects between white and pink palette rows. |
| `FF FC PP ??` | `textStream_ExtFC` `$80:C053` | 4 | Choice/menu selection. If `PP < $80`: linear list of `PP` items; if `PP ≥ $80`: 2D grid with `PP & $7F` columns. Polls input, flashes cursor, sets `$0A08` to selection index. |
| `FF FD NN` | `textStream_ExtFD` `$80:C02D` | 3 | `$0A0A = NN` — sets auto-advance frame delay (`NN = $FF` reads from RAM `$7EEA84`). |
| `FF FE` | `textStream_ExtFE` `$80:C028` | 2 (then read advance) | Calls `checkTextActive` — frame-yields and scrolls if a window has reached the bottom. |
| `FF FF` | `textStream_ExtFF` `$80:C022` | 2 (then read advance) | `JSL initTilemapAndSync_Long` — full tilemap clear + VBlank sync. Encoded as `[cls]` (often `FF FF 00`). |

### 4.2 The conditional redirect (`FF C0..F0`, handler at `$80:BB33`)

`FFC0` is the universal "if condition met, jump to a different location in the text stream". Format: `FF Cx LL HH BB` (5 bytes).

```
$80:BB33: AND #$3F       ; sub-code 0x00..0x30 → comparison threshold
          STA $04
          JSR compareStrings ; reads 3-byte target ptr into $00/$01/$02
          LDA $04 / CMP #$30 BNE checkCond
          LDA $0A08 BEQ setPtr / JMP textLoopStart
checkCond:LDA $54 / AND #$3F / CMP $04
          BCS setPtr / JMP textLoopStart
setPtr:   ; $14/$15/$16 = $00/$01/$02 → jump to new location
```

- `FF C0 LL HH BB` — unconditional jump (or "if `$0A08 == 0` jump" — depends on RAM `$54` low bits).
- `FF Cx LL HH BB` for `x ∈ 1..F` — jump if `($54 & $3F) ≥ x`.
- The target address is a full 24-bit SNES pointer, so redirects can land in any bank.

This is the mechanism that allows the EN translation to spill long text into an overflow region (bank `$C6`+) without corrupting the original pointer table — see `feedback_ffc0_not_strippable` and `project_ffc0_overflow` in the project memory.

---

## 5. The seven specific sequences

The codes the user asked about all come from menu/UI text. They subdivide into three families: **two-byte cursor positioning** (§5.1), **four-byte cursor-then-character** (§5.2), and **highlight-mode toggle** (§5.4).

### 5.1 `FF 03 06`  —  cursor → (col 3, row 6)

| Field | Value |
|---|---|
| Length | 3 bytes |
| Phase | Phase 2 (`$80:BF7D`) — buffered by Phase 1 via `ffLowBufferCopy` |
| Effect | `$09FC = 0x03 & 0x1F = 3`  /  `$09FE = 0x06 & 0x1F = 6`  /  `$0A06 = 0`  /  recompute `$7E:9000` write offset |
| Use | Place next character at column 3, row 6 of the 32-wide tilemap window |

Real example from `menu-prompts.txt:91`:
```
[FF0306]Which mode will you start?
[FF0808]Normal
[FF1308]Advanced
```
Sets the cursor to (3, 6) for the prompt, (8, 8) for the first option, (19, 8) for the second.

### 5.2 `FF 12 06`  —  cursor → (col 18, row 6)

| Field | Value |
|---|---|
| Length | 3 bytes |
| Effect | `$09FC = 0x12 & 0x1F = 18`  /  `$09FE = 0x06 & 0x1F = 6` |
| Use | Right-column header position for two-column menus |

From the title screen menu (`menu-prompts.old:86`):
```
[FF0306]  Game Start
[FF1206] Delete Data
```
Two top-of-screen menu entries at row 6, columns 3 and 18.

### 5.3 `FF 03 12`  —  cursor → (col 3, row 18)

| Field | Value |
|---|---|
| Length | 3 bytes |
| Effect | `$09FC = 3`  /  `$09FE = 0x12 & 0x1F = 18` |
| Use | Lower-rows label position |

From the same title menu, third row of the scene-select layout:
```
[FF030A]1 Scene…
[FF030E]2 Scene…
[FF0312]3 Scene…
```
The pattern `FF 03 0A`, `FF 03 0E`, `FF 03 12` walks down the left column at rows 10, 14, 18 — a 4-row stride for each scene-slot block.

### 5.4 `FF F1 05`  —  enable highlight render mode (variant 5)

| Field | Value |
|---|---|
| Length | 3 bytes |
| Phase | Phase 2 (`$80:BFC2`) |
| Effect | `$0A1F = ((5 - 1) × 4) + $21 = $31`  /  `$0A1E low byte unchanged` |

The pair `$0A1E/$0A1F` is the **special-render base attribute** used by `textChar_CalcTileAddr` at `$80:C1A6`:

```
PLA                  ; character code
SEC / SBC #$0020     ; subtract 0x20 (space-relative offset)
CLC / ADC $0A1E      ; add the base
STA.L $7E9000,X      ; tilemap entry
```

So characters rendered while `$0A1E ≠ 0` land at tile `(char - $20 + $0A1E)` with the high byte of `$0A1E` overlaying the SNES tilemap attribute byte (`vhopppcc`):

| `FF F1 PP` | `$0A1F` | Resulting attribute byte | `vhopppcc` decoded |
|---|---|---|---|
| `FF F1 01` | (clears `$0A1E` to `0000`) | normal text | — |
| `FF F1 02` | `$25` | `0010_0101` | priority=1, palette=1, tile-hi=01 |
| `FF F1 03` | `$29` | `0010_1001` | priority=1, palette=2, tile-hi=01 |
| `FF F1 04` | `$2D` | `0010_1101` | priority=1, palette=3, tile-hi=01 |
| `FF F1 05` | `$31` | `0011_0001` | priority=1, palette=4, tile-hi=01 |
| `FF F1 06` | `$35` | `0011_0101` | priority=1, palette=5, tile-hi=01 |
| `FF F1 07` | `$39` | `0011_1001` | priority=1, palette=6, tile-hi=01 |
| `FF F1 25` | `$B1` | `1011_0001` | **vert-flip**, priority=1, palette=4, tile-hi=01 |

Each step of `PP` advances the BG palette by one. `PP = 5` selects palette 4 with priority on — the standard "highlighted/selected menu cursor" attribute. `PP = 25` (`0x25`) keeps palette 4 but adds vertical flip — used to draw the *bottom* half of a 16-px-tall cursor sprite from the same source tile as the top half.

`FF F1 01` is the canonical "back to normal" code; the encoder emits it as `[FFF101]`.

### 5.5 `FF 0C 0A 2F`, `FF 0C 0E 2F`, `FF 0C 12 2F`  —  cursor + glyph

These are not 4-byte control codes — they are `FF 0C YY` (3-byte cursor positioning) **followed by** a literal character byte `0x2F`.

| Sequence | Cursor | Then renders |
|---|---|---|
| `FF 0C 0A 2F` | (col 12, row 10) | char `0x2F` (`/` in `eng.tbl`, `／` in `jap.tbl`) |
| `FF 0C 0E 2F` | (col 12, row 14) | char `0x2F` |
| `FF 0C 12 2F` | (col 12, row 18) | char `0x2F` |

In context, these only appear inside an `FF F1 NN` highlight bracket. From `menu-prompts.old:86`:
```
[FFF105][FF0C0A]／[FF0C0E]／[FF0C12]／[FFF125][FF0C0B]／[FF0C0F]／[FF0C13]／[FFF101]
```
Decoded:
1. `FF F1 05` → highlight mode, palette 4, priority on (top-half tiles).
2. `FF 0C 0A 2F` → place "／" at (12, 10) — tile = `0x2F - 0x20 + 0x0031` = `0x40` with attribute `$31`.
3. `FF 0C 0E 2F` → place "／" at (12, 14).
4. `FF 0C 12 2F` → place "／" at (12, 18).
5. `FF F1 25` → highlight mode, palette 4, **vertical flip** (bottom-half tiles).
6. `FF 0C 0B 2F` → place "／" at (12, 11) — directly under the first one, drawing the bottom half.
7. `FF 0C 0F 2F` → bottom of (12, 14)'s cursor → row 15.
8. `FF 0C 13 2F` → bottom of (12, 18)'s cursor → row 19.
9. `FF F1 01` → restore normal rendering.

Together this paints **three 16-pixel-tall menu cursors** (one per scene slot in the title-screen scene selector). Each cursor is built from two halves of tile `0x4F` (a hand-drawn corner glyph in the system font) — the top-half uses palette 4 with no flip, the bottom-half uses palette 4 with V-flip, so the same source tile mirrors itself to form a complete cursor frame.

The `0x2F` glyph in this context is **not** rendered as a slash. With `$0A1E` non-zero, `textChar_CalcTileAddr` adds `$0A1E` to `(char - $20)`, so character `$2F` becomes a different VRAM tile entirely — specifically tile `$31 + ($2F - $20) = $40`. That tile is whatever the menu UI tileset defines at index `0x40` (a corner-bracket cursor piece in this game).

---

## 6. WRAM state used by the engine (cheat sheet)

| Address | Width | Meaning |
|---|---|---|
| `$0014/$0015/$0016` | 24-bit | Current text-stream pointer (Phase 1 source / Phase 2 buffer) |
| `$0400+` | up to ~496 bytes | Phase-1 staging buffer |
| `$0700+` | array | Kanji-tile index buffer (filled by `0x01..0x08` markers) |
| `$09F0` | word | First-column reset value (used by `FF 90` newline) |
| `$09F8` | word | Line-end column threshold |
| `$09FA` | word | Line-end row threshold (window-scroll trigger) |
| `$09FC` | word | Current **column** cursor |
| `$09FE` | word | Current **row** cursor |
| `$0A00` | word | Tilemap row stride |
| `$0A02` | word | Default attribute bits added to every char |
| `$0A03` | byte | Current text Y offset (set by `FF FB`) |
| `$0A06` | word | Pause/wait flag |
| `$0A08` | word | Universal text parameter / index (mutated by `FF 80..82, 94`) |
| `$0A0A` | word | Auto-advance delay frames |
| `$0A0C` | word | Initial delay frames (copied to `$0A0A` at start of render) |
| `$0A10` | word | Char-count since last newline |
| `$0A16` | word | "More text pending" flag (set by `FF FA`) |
| `$0A18`, `$0A1A` | word | Kanji-tile palette index counters |
| `$0A1C` | word | Alternate render-mode flag |
| `$0A1E/$0A1F` | word | Special-render tilemap base + attribute (set by `FF F1`) |
| `$0A20` | word | Mode flag set by miscellaneous helpers |

`$54` (low 6 bits) is the conditional flag register read by `FF Cx` — it is set elsewhere in the game logic (story-progress flags, party state) and persists across renders.

---

## 7. References

- Phase 1: `disassembly/lm3_bank80.asm:5233+` (`fillTextBuffer_Phase1`)
- Phase 2: `disassembly/lm3_bank80.asm:6061+` (`renderTextStream` / `processText`)
- FF dispatch table: `disassembly/lm3_bank80.asm:5314+` (`ffHighJumpTable`)
- FFC0 redirect: `disassembly/lm3_bank80.asm:5710+` (handler at `$80:BB33`)
- Cursor offset math: `disassembly/lm3_bank80.asm:6580+` (`calculateBufferOffset`)
- `@ctrl` length tables: `en_data/eng.tbl:260+`, `jp_data/jap.tbl:2225+`
