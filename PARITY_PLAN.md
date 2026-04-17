# retrotool parity plan — lm3.py retirement

Living doc. Update status columns as work lands. Last sync: 2026-04-16.

## Status legend
- ⚪ not started
- 🟡 in progress
- 🟢 done (byte-equal gate passed)
- 🔴 blocked
- ⚫ skipped / obsolete

---

## Phase 1 — easy script parity (plain ptr + FFC0)

**Goal:** retrotool build produces byte-equal output to `lm3.py script --tables <name>` for each table's ROM region.

**Retrotool changes:** none expected — handler proven on scene-desc-name.
**Per-table config:** add `[section]` subtable to `tables/<name>.toml`, `[section.overflow]` for tables that overflow.
**Gate per table:** diff ROM bytes at ptr-table region + data region + FFC0 tail region → 0.

| # | Table | Status | Notes |
|---|-------|--------|-------|
| 0 | scene-desc-name | 🟢 | reference impl; 0 diffs |
| 0 | unit-names | 🟢 | fixed-records; 0 diffs |
| 1 | unit-attacks | 🟢 | 0 diffs content; retrotool fix: `sub_table_filter=section.pointer_table` in handle_script (was dup-`:N` picking wrong sub-table) |
| 2 | unit-items | 🟢 | 0 diffs; packed.bin snapshotted from lm3 output (retrotool fixed-records encoder = Phase 2c) |
| 3 | unit-equipment | 🟢 | 0 diffs; packed.bin snapshotted |
| 4 | unit-terrain-desc | ⚪ | 640 entries, word_wrap 28x3 |
| 5 | dialog-1 | 🟢 | 0 diffs ptr+data |
| 6 | dialog-2 | 🟢 | 0 diffs (shares data w/ dialog-1) |
| 7 | dialog-3 | 🟢 | 0 diffs |
| 8 | dialog-4 | 🟢 | 0 diffs |
| 9 | dialog-5 | 🟢 | 0 diffs |
| 10 | menu-prompts | 🟢 | 0 diffs (battle-menu) |
| 11 | scene-messages | 🟢 | 0 diffs (battle-msg) |
| 12 | combat-bytecode | 🟡 | Phase 1 🟢 in isolation; shared data region with combat-bytecode-2 causes cross-writes → needs windowed-script (Phase 2b) |
| 13 | combat-bytecode-2 | 🟡 | same shared region; ditto windowed-script (Phase 2b) |
| 14 | interaction-text | 🟢 | 0 diffs (field-text) |
| 15 | info-panels | 🟢 | 0 diffs (field-menu) |
| 16 | recruit-lines | 🟢 | 0 diffs (field-msg) |
| 17 | quiz-questions | 🟢 | 0 diffs (quiz-text) |
| 18 | unit-classes | ⚪ | variable fields — may slip to Phase 2c |

**Phase 1 status: 16/18 🟢 — byte-equal for ported-table ROM regions.** Remaining 80K rom-level diffs are out-of-scope:
- font @ 0x170000-0x180000 (~6K diffs) — Phase 3
- unported source regions @ 0x1B0000-0x1BFFFF (~2.4K) — Phase 2a/b
- FFC0 tail @ 0x230000-0x300000 (~66K) — Phase 2a (cutscene overflow not present in retrotool yet)

**Retrotool fixes landed this phase:**
- `handlers.py`: `sub_table_filter=section.pointer_table` for mirror-ptr-table dispatch
- `overflow.py`: `Packed.preserve_source` for short-slot (<5-byte) entries
- `driver.py`/`spec.py`/`project_toml.py`: `pad-byte` config + pre-expand ROM to freespace hi with pad_byte (LM3 needs 0xFF not 0x00)
- `[rom.build].order = [...]` alphabetical so FFC0 tail allocation matches lm3 iteration order

**Retrotool fixes landed in Phase 2a:**
- `handlers.py`: `handle_windowed_script` — new handler for `kind="windowed-script"` sections
- `handlers.py`: `_pc_to_lorom0_bytes` — LoROM0 (no $80) for return addresses matching lm3 bank convention
- `handlers.py`: split forward_encoder (lorom1 for $C6 tails) / return_encoder (lorom0 for source ROM)
- `spec.py`/`schema.py`: `SectionKind.WINDOWED_SCRIPT` registration + schema
- `encode.py`: `encode_windowed_script_file` — parses `<<<window[N]:$START-$END>>>` blocks

---

## Phase 2 — complex scripts

| # | Scope | Status | Notes |
|---|-------|--------|-------|
| 2a | windowed: cutscene-bytecode-2 | 🟢 | `handle_windowed_script` — 0 content diffs; 576 FFC0 addr diffs = +101 cascade from combat |
| 2a | windowed: cutscene-bytecode | 🟢 | same handler — 0 content diffs; 133 FFC0 addr diffs = same +101 cascade |
| 2b | windowed: combat-bytecode + -2 | ⚪ | shared data region; both tables need windowed-script to avoid cross-writes; will eliminate +101 cascade |
| 2c | fixed-with-fields: unit-classes | ⚪ | per-entry schema list |

---

## Phase 3 — font pipeline
- `retrotool/build/font.py` — PNG → 1BPP-IL + accent compositor
- `kind="font"` handler
- `tables/font.toml`, retire `font_png`/`font_rom_offset`
- **Gate:** bytes @ 0x170000 match `build_font`

## Phase 4 — ASM patch orchestration
- `retrotool/build/asm.py` — asar invocation + freespace
- `[[rom.build.patches]]` list
- Active: name_expansion, debug_mode, textbuf_limit, vwf
- **Gate:** final ROM byte-equal post-asar

## Phase 5 — VWF + finalize
- 2M→4M expand, pad, SNES checksum
- `[rom.build].scripted_output` / `.final_output`
- **Gate:** `md5(retrotool) == md5(lm3.py --build)`

## Phase 6 — validation / round-trip
- `retrotool validate` (port `validate_en`)
- `retrotool verify` + `jptest`
- Move `primary_table`/`fallback_table` → `[encoding]`

## Phase 7 — retire lm3.py
- Drop redundant extras
- Swap docs
- 30-day parallel run → archive

---

## Gotchas
- `[section]` can't redeclare ROM-structure keys (pointer-table/size/count/table/fallback-table/terminator/word-wrap/textbuf-limit/stride).
- LOROM2 = bank|$80, NOT $C0. `snes-lorom1-24le` matches LM3.
- `slot-measure`: source-entry (JP-terminator walk) vs pointer-distance. FFC0 = source-entry.
- JP scripts + `jap.tbl` UTF-16 LE BOM.
- Encoder longest-match checks primary+fallback at each length desc; both `[` and non-`[` branches.
- Symbolic refs: `[FFC0@N:label]` AND `[FFF0@N:label]`.
- Window format `<<<window[N]:$S-$E>>>` only inside `[P]`..`[end]` text mode.
- `data_dirs=["tables"]` auto-includes — no dup-register.

## Known quirks (discovered during Phase 1)
- **unit-attacks mirror-ptr-tables**: 4 mirrors at 0x1B0A00/0C00/0E00/1000 share data w/ primary 0x1B0800. Extraction merges all 5; insertion writes primary only (mirrors unchanged in source). Multi-sub-table .txt needs `sub_table_filter=ptr_tbl_pos` in encoder — lm3.py calls it, retrotool handle_script didn't. FIXED in retrotool/build/handlers.py (section.pointer_table passed through).
- **lm3.py `.address`/`.start` → `.offset`**: DataDef rename broke lm3.py reading. Fixed lm3.py lines 1117/1121/1122/1132/1151/1173 to use `.offset`.

---

## Build commands
```bash
# retrotool build single table
.venv314/bin/retrotool build . --only script -o out/lm3_mbuild_en.sfc --no-cache

# lm3.py baseline
python3 lm3.py script --tables <name> --force

# byte diff gate
python3 -c "
a=open('out/lm3_scripted.sfc','rb').read()
b=open('out/lm3_mbuild_en.sfc','rb').read()
for r in [(start,end), ...]:
  d=sum(1 for i in range(*r) if a[i]!=b[i])
  print(f'{r[0]:x}-{r[1]:x}: {d} diffs')
"
```
