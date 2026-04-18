# Mesen2-Diz IPC

## Connection
Pipe name: auto from ROM (e.g. `Mesen2Diz_SuperMetroid`). Override via config.
- Linux: `/tmp/CoreFxPipe_{pipeName}`
- Windows: `\\.\pipe\{pipeName}`
- Default (no ROM): `Mesen2Diz_DebuggerIpc`

Protocol: line-based JSON. One `{"command":"X",...}\n` per request, one JSON response per line.
Response: `{"success":true,"data":...}` or `{"success":false,"error":"..."}`

Use `getIpcInfo` to discover current pipe name + platform path at runtime.

## Address Format
Hex prefix: `"0x8000"`, `"$8000"`. Decimal: `32768`. Bare hex: `"8000"`.
All response addresses: uppercase no prefix (`"008000"`).

## Types

### MemoryType
`SnesMemory` (CPU mapped) | `SnesPrgRom` (absolute, for labels) | `SnesWorkRam` (128K) | `SnesSaveRam` | `SnesVideoRam` (64K) | `SnesSpriteRam` (544B) | `SnesCgRam` (512B) | `SnesRegister` ($2100-$43FF) | `SpcRam` (64K) | `SpcRom` (64B)

### CpuType
`Snes` | `Spc` | `Sa1` | `Gsu`

### FunctionCategory
`None` `Init` `MainLoop` `Interrupt` `DMA` `Input` `Player` `OAM` `VRAM` `Tilemap` `Palette` `Scrolling` `Animation` `Effects` `Mode7` `Music` `SFX` `Physics` `Collision` `Entity` `Enemy` `AI` `Camera` `StateMachine` `GameState` `Menu` `HUD` `LevelLoad` `Transition` `Script` `Dialogue` `Math` `RNG` `Timer` `Memory` `Text` `Save` `Debug` `Unused` `Unknown` `Helper`

### StepType
`Step` `StepOut` `StepOver` `PpuFrame` `RunToNmi` `RunToIrq` `StepBack`

### StepBackUnit (for stepTrace with StepBack)
`Instruction` (default) | `Scanline` | `Frame`

### CheatType
`SnesGameGenie` `SnesProActionReplay` `NesGameGenie` `NesProActionRocky` `NesCustom` `GbGameGenie` `GbGameShark` `PceRaw` `PceAddress` `SmsProActionReplay` `SmsGameGenie`

## Commands

### Labels
| Command | Params | Notes |
|---------|--------|-------|
| `setLabel` | address, memoryType, label?, comment?, category?, length?(1) | Create/update. Returns warning if no category set |
| `setLabels` | labels:[{address, memoryType, label?, comment?, category?, length?},...] | Batch create/update. Returns count + results array |
| `deleteLabel` | address, memoryType | |
| `getLabel` | address, memoryType | Returns null data if not found |
| `getLabelByName` | name | |
| `getAllLabels` | cpuType? | Filter by CPU or get all |

Label names: `^[@_a-zA-Z]+[@_a-zA-Z0-9]*$`. Comments support `\n`.
All labels set via IPC are marked with an IPC flag (visible in label/function list as green dot, sortable).
**Always set a category** — omitting it triggers a warning in the response.

### Memory
| Command | Params | Notes |
|---------|--------|-------|
| `readMemory` | memoryType, address, length?(1) | Max 65536. Returns hex + bytes array |
| `writeMemory` | memoryType, address, hex\|values | hex: `"FF 00 42"`, values: `[255,0,66]` |
| `getMemorySize` | memoryType | |

### PPU Memory
| Command | Params | Notes |
|---------|--------|-------|
| `getVram` | address?(0), length?(32768) | Word-addressed. Max 32768 words (64KB). Returns wordAddress, wordCount, hex, bytes |
| `getCgram` | address?(0), length?(512) | Byte-addressed. Max 512 bytes. Returns hex, bytes + colors array with index/rgb555/r/g/b per entry |
| `getOam` | _(none)_ | Returns raw 544 bytes + parsed sprites array (128 entries): index, x, y, tile, palette, priority, hFlip, vFlip, size, width, height. Also returns oamMode |

### Memory Search & Diff
| Command | Params | Notes |
|---------|--------|-------|
| `searchMemory` | memoryType, pattern, startAddress?(0), maxResults?(20) | Pattern: hex with `??` wildcards, e.g. `"B4 ?? 4A D6"`. Max 2MB search region, max 1000 results, max 256-byte pattern |
| `snapshotMemory` | id, memoryType, address?(0), length?(256) | Save memory region snapshot. Max 16 snapshots, 64KB each, 5-min TTL |
| `diffMemory` | snapshotId, memoryType?, address?, length? | Compare current memory against snapshot. Returns change runs with offset/address/oldHex/newHex + totals |
| `clearSnapshots` | _(none)_ | Clear all stored snapshots |

### CPU State
| Command | Params | Notes |
|---------|--------|-------|
| `getCpuState` | cpuType?(Snes) | SNES: a,x,y,sp,d,pc,k,dbr,flags,emulationMode,cycleCount |
| `setCpuState` | cpuType?(Snes), a?, x?, y?, sp?, d?, dbr?, k?, pc?, flags?, emulationMode? | Partial update — only provided fields change. Returns full state |
| `getProgramCounter` | cpuType?(Snes) | |
| `setProgramCounter` | cpuType?(Snes), address | |

### Execution Control
| Command | Params | Notes |
|---------|--------|-------|
| `pause` | | |
| `resume` | | |
| `isPaused` | | Returns `{"paused":bool}` |
| `step` | cpuType?(Snes), count?(1), stepType?(Step) | Fire-and-forget. For StepBack: count = StepBackType (0=Instruction,1=Scanline,2=Frame) |
| `stepTrace` | cpuType?(Snes), count?(1), stepType?(Step), stepBackUnit?(Instruction) | Returns CPU state after **each** step. Max 500. `states` array in response |

### Trace Log
| Command | Params | Notes |
|---------|--------|-------|
| `getTraceLog` | count?(100), cpuType? | Recent execution history (up to 30000). Requires trace logging enabled. Returns pc, cpuType, byteCode, log (formatted disassembly + registers) |
| `setTraceLogEnabled` | enabled?(true), cpuType?(Snes), format?, useLabels?(true), condition? | Enable/disable trace logging. Default format: `[Disassembly][Align,24] A:[A,4h] X:[X,4h] Y:[Y,4h] S:[SP,4h] D:[D,4h] DB:[DB,2h] P:[P,h]` |

### Event Wait
| Command | Params | Notes |
|---------|--------|-------|
| `waitForEvent` | event, timeout?(5000) | **Blocks** until event fires or timeout (ms, 100-60000). Events: `breakpoint`, `paused`, `resumed`, `debuggerResumed`, `frameComplete`, `romLoaded`, `stateLoaded`, `reset`. Returns triggered, event, timedOut. On breakpoint: includes cpuState |

### Disassembly
| Command | Params | Notes |
|---------|--------|-------|
| `getDisassembly` | cpuType?(Snes), address, rows?(20) | Max 500 rows |
| `searchDisassembly` | cpuType?(Snes), search, startAddress?(0) | Returns address or found=false |

### Breakpoints
| Command | Params | Notes |
|---------|--------|-------|
| `addBreakpoint` | address, memoryType, cpuType?(Snes), endAddress?, breakOnExec?(true), breakOnRead?(false), breakOnWrite?(false), condition?, enabled?(true) | |
| `removeBreakpoint` | address, memoryType, cpuType?(Snes) | |
| `getBreakpoints` | cpuType?(Snes) | |
| `clearBreakpoints` | | |

### Expression Evaluation
| Command | Params | Notes |
|---------|--------|-------|
| `evaluate` | expression, cpuType?(Snes) | Supports registers (`A`,`X`,`Y`,`PC`,`SP`), memory reads (`[$7E0100]`), arithmetic |

### Call Stack
| Command | Params | Notes |
|---------|--------|-------|
| `getCallstack` | cpuType?(Snes) | Array of {source,target,returnAddress,flags} |

### Code/Data Log (CDL)
| Command | Params | Notes |
|---------|--------|-------|
| `getCdlData` | memoryType, address, length?(1) | Max 65536 |
| `getCdlStatistics` | memoryType | codeBytes, dataBytes, totalBytes |
| `getCdlFunctions` | memoryType | Array of function entry point addresses |

### Address Mapping
| Command | Params | Notes |
|---------|--------|-------|
| `getAbsoluteAddress` | address, memoryType | CPU→ROM. Null data if unmapped |
| `getRelativeAddress` | address, memoryType, cpuType?(Snes) | ROM→CPU |

### ROM Info & Status
| Command | Params | Notes |
|---------|--------|-------|
| `getRomInfo` | | romPath, format, consoleType, cpuTypes |
| `getStatus` | | running, paused, romLoaded, romPath, consoleType, cpuState |

### Screenshot
| Command | Params | Notes |
|---------|--------|-------|
| `takeScreenshot` | path? | No path = default location |

### Emulator Control
| Command | Params | Notes |
|---------|--------|-------|
| `loadRom` | path, patchPath? | Async — poll `getStatus` |
| `reloadRom` | | |
| `powerCycle` | | Cold boot, RAM wiped |
| `powerOff` | | Stops emulation |
| `reset` | | Soft reset, RAM preserved |

### Save States
| Command | Params | Notes |
|---------|--------|-------|
| `saveStateSlot` | slot(1-10) | |
| `loadStateSlot` | slot(1-10) | |
| `saveStateFile` | path | Absolute path |
| `loadStateFile` | path | |

### Controller Input
| Command | Params | Notes |
|---------|--------|-------|
| `setControllerInput` | port?(0), buttons:{a,b,x,y,l,r,up,down,left,right,select,start} | All bool. Unset=false. **Persists** until changed |
| `clearControllerInput` | port?(0) | Release all |

Tap pattern: set → step PpuFrame ×N → clear.

### Emulation Settings
| Command | Params | Notes |
|---------|--------|-------|
| `getEmulationSpeed` | | 0=unlimited, 100=normal |
| `setEmulationSpeed` | speed(0-5000) | Applied immediately |
| `getTurboSpeed` | | |
| `setTurboSpeed` | speed(0-5000) | |
| `getRunAheadFrames` | | |
| `setRunAheadFrames` | frames(0-10) | |
| `getConfig` | | All emu settings in one call |

### Timing & PPU
| Command | Params | Notes |
|---------|--------|-------|
| `getTimingInfo` | cpuType?(Snes) | fps, masterClock, masterClockRate, frameCount, scanlineCount, firstScanline, cycleCount |
| `getPpuState` | cpuType?(Snes) | SNES: cycle, scanline, hClock, frameCount, forcedBlank, screenBrightness, bgMode, mode1Bg3Priority, mainScreenLayers, subScreenLayers, vramAddress |
| `getBgState` | layer?(all) | Layer 1-4 or omit for all. Per-layer: charBaseAddress, mapBaseAddress, mapSize, tileSize, bpp, hScroll, vScroll, mainScreen, subScreen. All-layers also returns bgMode, mode1Bg3Priority, mainScreenLayers, subScreenLayers |
| `getDmaState` | channel?(all) | Channel 0-7 or omit for all. Per-channel: active, hdmaEnabled, transferMode, direction, fixedTransfer, decrement, ioAddress, sourceBank, sourceAddress, transferSize, hdmaIndirect, hdmaBank, hdmaTableAddress, hdmaLineCounter |

### Tilemap / Graphics decode
| Command | Params | Notes |
|---------|--------|-------|
| `getTilemap` | layer(1-4), startX?, startY?, width?, height? | Decodes tilemap entries from VRAM for BG layer. Handles DoubleWidth/Height quadrants. Returns entries:[{x,y,tileIndex,palette,priority,hFlip,vFlip,vramWord}], plus mapBaseAddress/charBaseAddress/bpp/tileSize. Default = full map. Max 8192 entries/call |
| `decodeTiles` | source("vram"\|"rom"\|"wram"), address, count(1-4096), bpp(2\|4\|8), palette?("cgram"\|"grayscale"), paletteOffset?(0-255) | Decodes SNES planar tile bytes into 8x8 pixels. Returns indexed:[...] flat palette-index buffer + rgbaBase64 (count×64 pixels, RGBA row-major within each 8x8 tile, tiles concatenated). Color 0 alpha=0 (transparent). paletteOffset = CGRAM color index start |
| `renderBgLayer` | layer(1-4) | Composites full BG layer to RGBA: tilemap + char + per-tile palette + flips + LargeTiles 2x2 sub-tile arrangement. Returns width/height + rgbaBase64 (row-major pixels). Color 0 = transparent (alpha=0). Output capped at 1024×1024 pixels |

### Targeted Execution
| Command | Params | Notes |
|---------|--------|-------|
| `runUntilVramWrite` | vramAddress, vramEndAddress?(=start), timeout?(10000ms) | Sets temp breakpoint on writes to $2118/$2119, resumes, loops: check ppu.VramAddress in [start,end] → return cpuState+pc; else resume. Cleans up breakpoint on all paths. Returns {triggered, timedOut, vramAddress, pc, cpuState, matchedRange} |

### IPC Info
| Command | Params | Notes |
|---------|--------|-------|
| `getIpcInfo` | | pipeName, pipePath, romPath, platform |
| `listCommands` | | Returns {count, commands:[...], categories:{cat:[cmds]}}. Alias: `getCommands`. Use for self-discovery when this prompt is stale |

### Cheats
| Command | Params | Notes |
|---------|--------|-------|
| `setCheats` | cheats:[{type,code},...] | See CheatType enum. Replaces all active cheats |
| `clearCheats` | | Remove all |

### Memory Watch Hook (MMIO callback, pull model)
Native SPSC ring captures CPU memory accesses matching registered ranges. Drain via `pollMemoryEvents`. Hot path is lock-free; filter is per-CpuType linear range scan. v1 = CPU memory only (read/write/exec/dma — no PPU/APU bus). Value is **pre-commit** for writes (new value being stored). Old value not captured (avoids extra DebugRead). To recover old value: issue `readMemory` at `event.address` BEFORE next poll cycle (intra-batch the prior event's value is the most recent old value). For bursty same-address writes, reconstruct from prior event in batch.

| Command | Params | Notes |
|---------|--------|-------|
| `watchCpuMemory` | cpuType, ranges:[{start,end?,ops?,valueMin?,valueMax?,sampleRate?}], ops?:[...] | Replace all watches for cpuType. ops: read/write/exec/execoperand/dmaread/dmawrite/all/allaccess. Default ops=allaccess. valueMin/Max (hex/dec, default 0..0xFFFF) filter event value. sampleRate=N captures 1-in-N matching events (0/1=every). Auto-enables hook. Re-sending watches resets sample counters |
| `addCpuMemoryWatch` | cpuType, start, end?, ops?, valueMin?, valueMax?, sampleRate? | Append one range. Same value/sample semantics as watchCpuMemory |
| `clearCpuMemoryWatches` | | Drop all watches across all CpuTypes |
| `pollMemoryEvents` | maxEvents?:1024 | Returns {count,dropped,highWater,events:[{masterClock,cpuType,address,absAddress,value,opType,accessWidth}]}. dropped/highWater since last poll |
| `setMemoryWatchEnabled` | enabled:bool | Master gate. Off = zero hot-path cost |
| `setMemoryWatchRingSize` | size | Power-of-2, 1024..4194304. Resets ring (drops in-flight events). Persisted to config |

Event opType: Read, Write, ExecOpCode, ExecOperand, DmaRead, DmaWrite. AccessWidth: 1 or 2 bytes. Value is uint16 (covers SNES word — widest Mesen bus). absAddress is null in v1 (mapping not computed in hot path).

Ring overflow policy: drop newest, increment dropped counter. If dropped > 0: poll faster, raise ring size, or narrow ranges.

## Key Rules
- Labels use **absolute** addresses (SnesPrgRom). Use `getAbsoluteAddress` to convert CPU addresses.
- **Pause before** reading CPU state/memory for consistency. Resume when done.
- Controller input **persists** — always clear when done.
- `loadRom`/`powerCycle`/`reset` are async — poll `getStatus`.
- Save state slots: 1-10. File paths: absolute.
- IPC connection persists across ROM reloads by default. No reconnection needed.

## Debugging Techniques

### Reverse Stepping
Execution can be **reversed**. The debugger records history and can step backward:
- `stepType: "StepBack"` with `stepBackUnit: "Instruction"` — undo one instruction
- `stepType: "StepBack"` with `stepBackUnit: "Scanline"` — rewind one PPU scanline
- `stepType: "StepBack"` with `stepBackUnit: "Frame"` — rewind one full frame

Use `stepTrace` to step back N times and receive CPU state at each point. This is invaluable for understanding how a value was computed or how execution reached a particular state.

### Forcing Conditions via CPU State
You can **modify any CPU register, flag, or memory** to force specific execution paths:
- `setCpuState` — change A, X, Y, SP, D, DBR, K, PC, flags, emulationMode (partial: only fields you provide are changed)
- `writeMemory` to SnesWorkRam — modify stack contents, variables, or any RAM
- `setProgramCounter` — jump execution to any address
- Combine: set registers + flags + PC to simulate any entry condition for a function

Example — force a branch: pause, read flags, set/clear the Zero flag via `setCpuState`, step to observe the alternate path.

Example — test a function: set A/X/Y to desired arguments, set PC to function entry, step through to observe behavior.

### Breakpoint-Driven Analysis
Breakpoints trigger asynchronously. The emulator pauses when hit, but the IPC response to `addBreakpoint` returns immediately — it does **not** wait for the break to occur.

Workflow:
1. `addBreakpoint` — set the trap (exec, read, or write; with optional condition expression)
2. `resume` — let emulation run
3. **Poll** `isPaused` or `getStatus` periodically to detect when a break occurs
4. Once paused: `getCpuState`, `getCallstack`, `getDisassembly`, `readMemory` to inspect
5. `stepTrace` to walk through code instruction by instruction with full state at each step
6. `resume` to continue, or step further

Conditional breakpoints use the expression evaluator: registers (`A`, `X`, `Y`, `PC`, `SP`), memory reads (`[$7E0100]`), arithmetic, comparisons. Example: `"condition": "A == #$42 && [$7E0010] > #$00"`.

### Execution State Awareness
- `step` is **fire-and-forget** — it tells the debugger to step, but the step may not complete before the response arrives (the CPU resumes briefly then breaks)
- `stepTrace` is **synchronous** — it steps and reads CPU state in a tight loop, returning all states in one response. Use this for tracing.
- After `step`, poll `isPaused` before reading state. After `stepTrace`, states are already in the response.
- `StepOver` skips subroutine calls (JSR/JSL). `StepOut` runs until the current subroutine returns.

## Gathering Context from the User

Before starting an RE task, ask the user for any of the following they can provide. Each item dramatically reduces wasted investigation time.

### Critical (ask first)
| Question | Why it matters |
|----------|---------------|
| **What game state shows the target?** | "Font appears during dialogue after title screen" prevents tracing the wrong data (e.g., title logo instead of dialogue font). Knowing the game phase narrows the search window from "entire boot sequence" to a specific moment. |
| **Known addresses or partial RE work?** | Existing labels, tilemap locations, BG mode, RAM maps, or prior disassembly notes. Even partial info ("I think the tilemap is near $1000") eliminates entire categories of investigation. |
| **Expected data format?** | 2bpp vs 4bpp tiles, compressed vs uncompressed, known compression type (LZ, Huffman, custom), tile size (8x8 vs 16x16). Wrong format assumption wastes full decompression attempts. |

### High Value (ask if task involves graphics or text)
| Question | Why it matters |
|----------|---------------|
| **Character encoding / expected glyphs?** | "Japanese game with hiragana + katakana + scene-swapped kanji" helps validate decompressed output. Status abbreviations or custom symbols are confusing without context. |
| **ROM map or bank layout?** | Even rough ("game data in banks $B0-$BF, code in $80-$8F") helps prioritize where to scan when searching for data tables. |
| **Screenshot of the target?** | A screenshot showing the font/sprite/tilemap in-game serves as ground truth for validating decoded output. Without it, you're guessing whether garbled output is wrong data or wrong decode. |

### Helpful (ask if investigation stalls)
| Question | Why it matters |
|----------|---------------|
| **Other games on the same engine?** | Same developer often reuses compression, tile formats, and memory layouts. Cross-referencing sister titles can confirm format assumptions. |
| **DMA vs manual VRAM writes?** | Some games (like SBD) use manual `STA $2118` loops instead of DMA for tile transfers. This changes the entire tracing strategy — DMA register watches find nothing if the game doesn't use DMA. |
| **How many variants of the target exist?** | Fonts may have a base set + overlay pages (like SBD's 25 kanji pages). Sprite sheets may be split across multiple tilesets. Knowing this prevents premature "found it" conclusions. |

### Lessons from past investigations
- **Don't assume the first VRAM write to a region is the target.** The same VRAM address range gets overwritten by different tilesets at different game phases. The title logo and dialogue font both wrote to $4000.
- **Tileset/data table scanning is faster than runtime tracing** when the compression format and table location are known. Scanning all 512 entries in a tileset table takes seconds offline vs hours of breakpoint tracing.
- **Standalone ROM analysis beats IPC tracing** for static data (fonts, graphics, tables). Reserve IPC/runtime analysis for dynamic behavior (what code calls what, runtime state).

## Annotation Guidelines
- Follow the user's instructions on what to annotate and how to categorize.
- **Always annotate the base ROM** — the original, unmodified ROM file. Annotations describe the original game code, not patched/hacked variants.
- When new discoveries are made (function purpose identified, data table decoded, variable meaning understood), immediately update labels and comments via `setLabel`.
- Use `category` to classify functions (see FunctionCategory enum). This helps organize the codebase.
- Add comments explaining **why**, not just what — "Checks if player is underwater" is better than "Compares A to #$03".
- Label names must match `^[@_a-zA-Z]+[@_a-zA-Z0-9]*$`. Use descriptive names: `Player_CheckCollision`, `LoadTilemap_BG1`, `SFX_PlaySound`.

## Reverse Engineering Workflow
1. `getStatus` → confirm ROM loaded
2. `getCdlFunctions` → all known entry points
3. `getAllLabels` → existing annotations
4. `getDisassembly` at each function → read code
5. `setLabel` → name functions, add comments, set category
6. `readMemory` → examine data tables, RAM
7. `addBreakpoint` + `resume` + poll `isPaused` → wait for condition
8. `stepTrace` → walk through code with full CPU state at each step
9. `setCpuState` / `writeMemory` → force conditions to test alternate paths
10. `step` with `StepBack` → reverse execution to understand causality
11. `getAbsoluteAddress`/`getRelativeAddress` → address conversion
