# Equipment & Item Name Expansion Plan

## Problem

English translations of equipment/item names exceed the fixed-length fields:
- **Weapon names**: 9 bytes max, EN translations often 11-23 bytes
- **Armor names**: 9 bytes max, EN translations often 10-16 bytes  
- **Item names**: 9 bytes max, EN translations often 10-18 bytes

Japanese fits in 9 bytes because each kana/kanji is 1 byte in the game encoding,
giving 9 "characters" of content. English needs roughly 2x the bytes for the same
semantic content.

## Current Table Layout

| Table | PC Address | Records | Record Size | Name Offset | Name Len | Fill |
|-------|-----------|---------|-------------|-------------|----------|------|
| unit-equipment | `$010050` | 256 | 32 (`$20`) | +0 (weapon), +12 (armor) | 9 | `$20` |
| unit-items | `$0124E0` | 128 | 24 (`$18`) | +0 | 9 | `$20` |

Both tables live in bank `$02` (`$02:8050` and `$02:A4E0` SNES).

## How Names Are Currently Accessed

### Item Names — `sub_00DE49` (`$81:DE49`, PC `$00DE49`)

Single function handles all item access:
```asm
sub_00DE49:
    REP #$20
    AND #$007F            ; mask to 128 entries
    PHA
    ASL A : ASL A : ASL A ; ×8
    STA $00
    ASL A
    CLC : ADC $00         ; ×8 + ×16 = ×24
    TAX
    LDY #$0000
.loop:
    LDA.L $02A4E0,X      ; read from item table
    STA $0E80,Y           ; copy to RAM buffer
    INX : INX : INY : INY
    CPY #$0018            ; 24 bytes
    BNE .loop
    PLA
    STA $0E80,Y           ; store item index at +24
    ...
    RTS
```

**Callers** (4 sites):
- `$81:9443` (line 294) — early game sequence
- `$81:D3A5` (line 8170) — item selection in menu
- `$81:D48C` (line 8278) — item display during gameplay
- `$81:E822` (line 10516) — item handling in battle

After `sub_00DE49` copies the 24-byte record to RAM `$0E80`, the name at
`$0E80+0` (9 bytes) is read by the menu renderer for display. The menu
renderer reads bytes until hitting `$20` (space padding).

### Equipment Names — Access Pattern Unknown

Only one direct reference found: `LDA.L $028050,X` at `$01:D6AF` — reads a
byte for sprite/graphics lookup, **not** name rendering.

Equipment names within the 32-byte records at `$02:8050` are likely accessed
through the WRAM unit data structure at `$1400` (32 bytes per unit), which
mirrors the ROM record layout. The menu screens read names from these WRAM
records.

**TODO**: Trace the equipment menu rendering code paths:
- `drawEquipmentScreen` (`$81:A736`, line 4034)
- `handleEquipment` (`$81:A7A4`, line 4089)
- `drawStatComparison` (line 5540)
- Shop buy/sell menus (line 2921)

### Unit Names (SOLVED)

Two dedicated functions copy names to `$0400` (text buffer):
- `copyUnitFirstName` (`$00:B90F`): base `$02:A050`, ×8, stops at `$20`
- `copyUnitSurname` (`$00:B923`): base `$02:A298`, ×8, stops at `$20`

Called by the text engine's `$FF $F2` name substitution control code.
**Already expanded** to 16 bytes via relocation to bank `$C4` with ASM patch.

## Expansion Strategy

### Option A: Separate Name Tables (Recommended)

Create expanded name-only tables in free ROM (bank `$C4`+), leaving the
original stat records untouched. Patch the rendering code to read names
from the expanded tables instead of from within the records.

**Pros**: No record layout changes, no risk to stat data, clean separation.
**Cons**: Need to find and patch every name rendering site.

#### Proposed Layout (bank `$C4`)

| Table | Base | Entries | Entry Size | Total |
|-------|------|---------|------------|-------|
| unit-names (done) | `$C4:8000` | 146 | 16 | 2336 |
| equip-weapons | `$C4:8920` | 256 | 16 | 4096 |
| equip-armor | `$C4:9920` | 256 | 16 | 4096 |
| item-names | `$C4:A920` | 128 | 16 | 2048 |
| **Total** | | | | ~12,576 |

All easily fit in bank `$C4` (32 KB available).

#### ASM Work Required

1. **Items**: Hook `sub_00DE49` — after the existing record copy to `$0E80`,
   overwrite the 9-byte name field with expanded data. Or replace the
   `LDA.L $02A4E0,X` / `STA $0E80,Y` loop to pull names from the new table.
   
   Simplest approach: **post-copy fixup**. After `sub_00DE49` returns,
   the caller's item index is on the stack or in a register. A small patch
   could read the expanded name (up to 16 bytes) into `$0E80` from the
   new table, overwriting the 9-byte field.

   **Problem**: `$0E80` buffer is only 24 bytes for items. A 16-byte name
   would overwrite stat bytes at `$0E80+9` through `$0E80+15`. Need to
   either expand the buffer or ensure the stats are re-read from the
   record afterwards.

2. **Equipment**: Find the WRAM→screen rendering path. Equipment names in
   WRAM unit records at `$1400+offset` are copied from ROM during unit
   initialization. Could patch the init code to copy expanded names, but
   the WRAM record size (32 bytes) is also constrained.

3. **Menu layout**: The menu tile layouts may need widening for longer names.
   This affects tilemap positioning, cursor bounds, and window sizes.

### Option B: In-Place Record Expansion

Relocate entire equipment/item tables with wider records to expanded ROM.
Patch all code that indexes into records to use the new record size.

**Pros**: Everything stays consistent.
**Cons**: Must find and patch every `×32` / `×24` multiply and every
field offset reference. Many code sites, high risk of missing one.

### Option C: VWF-Only Solution

Keep 9-byte names but render them with VWF (variable-width font) so more
characters fit visually in the same pixel space. Currently VWF only applies
to the text engine (`$0400` buffer), not menu tile rendering.

**Pros**: No table changes needed.
**Cons**: Requires extending VWF to the menu renderer — significant work.
Still limited by the 9-byte encoding, though VWF would help a lot since
many EN names would fit if rendered proportionally.

## Key Addresses

| Label | SNES | PC | Purpose |
|-------|------|----|---------|
| Item record copy | `$81:DE49` | `$00DE49` | `sub_00DE49` — copies 24-byte item record to `$0E80` |
| Item table | `$02:A4E0` | `$0124E0` | 128 entries × 24 bytes |
| Equipment table | `$02:8050` | `$010050` | 256 entries × 32 bytes |
| Unit WRAM records | `$00:1400` | — | 32 bytes per unit, mirrors equipment layout |
| Equipment screen | `$81:A736` | `$00A736` | `drawEquipmentScreen` |
| Equipment handler | `$81:A7A4` | `$00A7A4` | `handleEquipment` |
| Text buffer | `$00:0400` | — | Text engine render buffer |
| Item/equip buffer | `$00:0E80` | — | Menu system data buffer (24 bytes) |
| Expanded names | `$C4:8000` | `$220000` | Unit names (done), space for more |

## Open Questions

1. How does the equipment menu renderer read weapon/armor name bytes? Does
   it read directly from WRAM unit records or from the ROM equipment table?
2. Are equipment names rendered through the static tile renderer or through
   the text engine?
3. Can the `$0E80` buffer be safely extended beyond 24 bytes, or does other
   data follow immediately at `$0E9A`+?
4. Does the VWF patch need to be extended to cover menu name rendering, or
   is the tile-based renderer sufficient with wider fields?

## Files

- `script_patch.asm` — ASM patches (unit name expansion already here)
- `vwf_patch.asm` — VWF rendering (does NOT touch equipment/item names)
- `lm3.py` — `FIXED_TABLES` config, `insert_fixed_table()`, `insert_all_fixed()`
- `en_ptr_data/unit-equipment.txt` — weapon/armor translations (currently truncated)
- `en_ptr_data/unit-items.txt` — item translations (not yet created)
- `en_ptr_data/lm3_names.txt` — master localization reference
