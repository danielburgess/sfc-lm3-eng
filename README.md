# sfc-lm3-eng
English Translation work for Little Master III: The Rainbow Jewels

## Current status
60% Complete
Adapting the VWF routines for different menus is proving to be an unexpected challenge.

## ROM Text Table Map

The game stores text across multiple pointer-table groups. Several groups contain
**contiguous sub-tables** that share a data region -- what initially appears as
"interleaved game data" between entries is actually text belonging to an adjacent
sub-table within the same pointer block.

### Pointer Table Groups

#### Battle Group (Bank $02)
Three contiguous sub-tables at `$02:B100`-`$02:B271` (184 entries + `$FFFF` terminator).
All entries share the text data region `$013270`-`$0164D5`.

| Sub-table    | Ptr Table PC | Entries | tbl_len | Description |
|--------------|-------------|---------|---------|-------------|
| battle-menu  | `$013100`   | 18      | `$024`  | Battle menu prompts |
| battle-text  | `$013124`   | 110     | `$0DC`  | Equip, items, save/load, scenario select |
| battle-msg   | `$013200`   | 56      | `$070`  | Spell/item use, status effects |

#### Field Group (Bank $03)
Three contiguous sub-tables at `$03:BBB4`-`$03:BD41`. A `$0000` separator sits
between field-menu and field-text. Data regions are sequential and non-overlapping.

| Sub-table   | Ptr Table PC | Entries | tbl_len | Data Start  | Description |
|-------------|-------------|---------|---------|-------------|-------------|
| field-menu  | `$01BBB4`   | 119     | `$0EE`  | `$01C0F1`   | Shop/town/equipment menus |
| field-text  | `$01BCA4`   | 46      | `$05C`  | `$01E348`   | Event/scenario descriptions |
| field-msg   | `$01BD00`   | 33      | `$042`  | `$01F2B7`   | Field NPC messages |

#### Dialog Group (Bank $37)
Four sub-tables with pointer tables at `$1B8000`-`$1B83CF`. Text is packed
sequentially from `DIALOG_TEXT_BASE` (`$1B83D0`).

| Sub-table | Ptr Table PC | Entries | tbl_len |
|-----------|-------------|---------|---------|
| dialog-2  | `$1B8000`   | 196     | `$188`  |
| dialog-3  | `$1B8100`   | 68      | `$088`  |
| dialog-4  | `$1B8200`   | 19      | `$026`  |
| dialog-5  | `$1B8300`   | 104     | `$0D0`  |

#### Standalone Tables

| Table              | Ptr Table PC | Entries | Notes |
|--------------------|-------------|---------|-------|
| script             | `$208000`   | 512     | 3-byte ptrs, relocated to bank $C1 |
| scenario-desc      | `$218000`   | 158     | 3-byte ptrs, relocated to bank $C3 |
| unit-terrain-desc  | `$030000`   | 640     | Contiguous data at `$030A00` |
| unit-attacks       | `$1B0800`   | 53      | Data at `$1B1200` (gap has unit stats) |
| quiz-text          | `$211700`   | 96      | 3-byte ptrs, relocated |
| unit-equipment     | special     | 256     | Fixed-length entries |
| script_ext         | special     | 512     | Mixed bytecode+dialog |

### Text Engine

The text engine at `$00:BE3B` reads text via `LDA [$14]` (24-bit long indirect).
The source pointer in DP `$14`/`$16` is set to `$00:0400` (WRAM) before rendering.
Text data is copied from ROM to WRAM `$0400` before the engine processes it.

Control codes use the `$FF` prefix byte:
- `$FF $xx $yy` — cursor positioning (col = byte2 & $1F, row = byte3)
- `$FF $FF` — new text window (`JSL $01:ECE1`)
- `$FF $FE` — wait for input
- `$FF $FD $nn` — set text speed
- `$FF $FC $nn` — conditional branch
- `$FF $FB $nn` — palette/attribute
- `$FF $FA` — increment counter
- `$FF $F1 $nn` — sub-command dispatch
- `$FF $F2 $nn` — name substitution

### Key Addresses

| Address      | Purpose |
|-------------|---------|
| `$00:BC75`  | Text display entry point (VWF hook site) |
| `$00:BE3B`  | processText — main text rendering loop |
| `$00:BF7D`  | `$FF` control code handler |
| `$01:ECE1`  | New text window setup (`$FF $FF` handler) |
| `$00:C233`  | Tilemap position calculator |
| `$7E:0400`  | WRAM text buffer (source for processText) |
