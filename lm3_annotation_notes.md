# LM3 Base ROM Annotation Notes

ROM: lm3.sfc (SNES LoROM)
Addresses: SNES mapped (bank:offset) and PRG absolute offset
Total named labels: 921
Categories: 49

## Key Data Structures

- Entity table: $1800, stride $10, max $20 entries
  - +00: flags/type, +02: current X, +04: current Y
  - +06: target X, +08: target Y (bit15=flip), +0A: tile data ptr
  - +0C: frame/anim, +0E: attributes
- OAM buffer: $0100 (low table), $1A00 (extended/high table)
- Voice table: $1000/$1200, 32 bytes per slot
- Music data pointer: [$8D] (long pointer)
- Music stack: $0F00 (for call/return)
- Text stream pointer: [$14] (long pointer)
- Text cursor: $09FC=pos, $09FE=line, $09F8=width

## OAM (70 labels)

$0089C8 (PRG $0009C8)  clearOAMBuffer  — Clears OAM buffer by setting all entries to off-screen. Entry: none. Sets Y=$F0 for all OAM entries.
$0089E0 (PRG $0009E0)  updateOAMEntries  — Updates OAM entries with sprite data. Entry: expects sprite data pointers set. Writes to OAM via $2104.
$0091CA (PRG $0011CA)  updateBattleGraphics  — Updates battle scene graphics including backgrounds and sprites. Entry: called during battle. Sets up multiple OAM entries.
$0092F3 (PRG $0012F3)  drawBattleSprite  — Draws a single battle sprite with position and tile data. Entry: A=sprite data index, X=OAM slot, $28=base address.
$00931C (PRG $00131C)  drawCharacterSprite  — Draws character sprite with animation frames. Entry: A=character ID, X=OAM slot, $28=base address.
$009BE0 (PRG $001BE0)  setupSpriteOAM  — Sets up OAM entries for a sprite with 4 tiles (2x2). Entry: A=tile number, $00=X pos, Y=OAM slot. Creates 4 OAM entries.
$009E4C (PRG $001E4C)  drawEffectTile  — Draws a single effect animation tile. Entry: A=tile data, X=OAM slot, Y=animation frame. Updates OAM entry.
$00A64E (PRG $00264E)  setupLargeSprite  — Sets up OAM for large sprite (4x4 tiles). Entry: A=base tile, $00=X pos, Y=OAM slot. Creates 16 OAM entries.
$00A788 (PRG $002788)  setupBattleSprite  — Sets up battle sprite with special attributes. Entry: A=tile data, $00=X pos, Y=OAM slot. Sets up 4 OAM entries with battle flags.
$00C8BB (PRG $0048BB)  renderSprites  — Main sprite render pipeline. Calls: clearOamBuffer, clearOamExtTable, buildEntityOam, finalizeOam, setupLargeSprite.
$00C8D2 (PRG $0048D2)  clearOamBuffer  — Fills OAM buffer $0100 with $E0FF (offscreen Y). 32 entries, stride 4.
$00C8D8 (PRG $0048D8)  clearOamBuffer_Loop  — Fill loop: STA $0100,X / INX*4 / CPX $80 / BNE
$00C8E5 (PRG $0048E5)  buildEntityOam  — Converts entity table at $1800 (stride $10, max $20) to OAM entries at $1A00. Handles position lerp, screen transform, tile/palette setup.
$00C914 (PRG $004914)  oam_StoreTargetY  — Store extracted target Y offset (bit15 cleared)
$00C91D (PRG $00491D)  oam_SkipEmpty  — Entity slot empty (type=0), skip to next
$00C920 (PRG $004920)  oam_BeginMove  — Begin entity position lerp toward target X/Y
$00C942 (PRG $004942)  oam_CalcMoveSpeed  — Compute movement speed from entity type low 3 bits + 1
$00C959 (PRG $004959)  oam_MoveXNeg  — Entity X > target X, subtract speed
$00C962 (PRG $004962)  oam_CheckYMove  — Compare entity Y to target Y for movement
$00C977 (PRG $004977)  oam_MoveYNeg  — Entity Y > target Y, subtract speed
$00C980 (PRG $004980)  oam_CheckArrived  — Entity reached target — clear movement flags (bits 0x0807)
$00C98D (PRG $00498D)  oam_MoveDone  — Movement calculation complete, restore Y register
$00C98E (PRG $00498E)  oam_LoadTileData  — Load tile data ptr (entity+0A) and attributes (entity+0E) to DP
$00C9A0 (PRG $0049A0)  oam_ReadAnimCmd  — Read animation command byte from tile data stream
$00C9A2 (PRG $0049A2)  oam_AnimCmdLoop  — Animation command processing loop
$00C9B6 (PRG $0049B6)  oam_AnimCmd_NewPtr  — Cmd $FF: replace tile data pointer from stream
$00C9C8 (PRG $0049C8)  oam_AnimCmd_Cond  — Cmd $80+: conditional frame display based on $54 flags
$00C9D3 (PRG $0049D3)  oam_AnimCmd_Reread  — Re-read command byte after conditional check
$00C9DC (PRG $0049DC)  oam_CheckFlipX  — Bit6: toggle entity horizontal flip flag
$00C9EC (PRG $0049EC)  oam_CheckCountdown  — Bit5: decrement entity Y, increment attributes (animation timer)
$00CA06 (PRG $004A06)  oam_ApplyXOffset  — Apply tile X position offset to entity X coordinate
$00CA19 (PRG $004A19)  oam_XOffsetPositive  — Positive X offset path — sets bit $4000 in tile ptr
$00CA49 (PRG $004A49)  oam_JmpSingleTile  — Jump to single-tile OAM path at $CD20
$00CA4C (PRG $004A4C)  oam_MultiTileSetup  — Begin 2x2 multi-tile sprite layout setup
$00CA62 (PRG $004A62)  oam_LoadTilePtr  — Load tile data pointer for layout computation
$00CA6C (PRG $004A6C)  oam_CalcScreenX  — Convert entity X to screen-relative X (subtract camera $60)
$00CA86 (PRG $004A86)  oam_LayoutNearRight  — Tile layout: X in $E8-$F7 (near right edge)
$00CA93 (PRG $004A93)  oam_LayoutWrapLeft  — Tile layout: X >= $FFF8 (wrapping from left side)
$00CAB0 (PRG $004AB0)  oam_LayoutFarLeft  — Tile layout: X in $FFF0-$FFF7 (far left wrap)
$00CAD0 (PRG $004AD0)  oam_LayoutEdgeRight  — Tile layout: X in $F8-$FF (right edge)
$00CAF0 (PRG $004AF0)  oam_LayoutNormal  — Tile layout: X in normal visible range
$00CB22 (PRG $004B22)  oam_CalcScreenY  — Convert entity Y to screen Y (subtract camera $1E). Check bounds.
$00CB30 (PRG $004B30)  oam_StoreScreenY  — Store screen Y, add offsets, clamp to $01F4 max
$00CB42 (PRG $004B42)  oam_ClampY  — Store clamped Y position to $1A
$00CB5E (PRG $004B5E)  oam_Palette1  — Palette option 1: OR $C9FF into tile attributes
$00CB68 (PRG $004B68)  oam_Palette2  — Palette option 2: check high nibble of entity attribs
$00CB7E (PRG $004B7E)  oam_WriteTilesNormal  — Write 4 OAM tile entries to $1C00 buffer (normal orientation)
$00CBE0 (PRG $004BE0)  oam_LayoutNearRight_F  — Flipped tile layout: X in $E8-$F7
$00CBED (PRG $004BED)  oam_LayoutWrapLeft_F  — Flipped tile layout: X >= $FFF8
$00CC0E (PRG $004C0E)  oam_LayoutFarLeft_F  — Flipped tile layout: X in $FFF0-$FFF7
$00CC2E (PRG $004C2E)  oam_LayoutEdgeRight_F  — Flipped tile layout: X in $F8-$FF
$00CC4A (PRG $004C4A)  oam_LayoutNormal_F  — Flipped tile layout: normal visible X range
$00CC7E (PRG $004C7E)  oam_CalcScreenY_F  — Flipped: convert entity Y to screen Y, check bounds
$00CC8C (PRG $004C8C)  oam_StoreScreenY_F  — Flipped: store screen Y with offsets and clamp
$00CC9E (PRG $004C9E)  oam_ClampY_F  — Flipped: clamp Y to $1A
$00CCBA (PRG $004CBA)  oam_Palette1_F  — Flipped palette 1: OR $C9FF
$00CCC4 (PRG $004CC4)  oam_Palette2_F  — Flipped palette 2: high nibble check
$00CCDA (PRG $004CDA)  oam_WriteTilesFlipped  — Write 4 OAM tile entries to $1C00 buffer (flipped orientation)
$00CD3C (PRG $004D3C)  oam_SingleTileVisible  — Single-tile OAM: X in visible range, compute position
$00CD4D (PRG $004D4D)  oam_SingleTileCalcY  — Single-tile: compute screen Y from entity Y
$00CD5F (PRG $004D5F)  oam_SingleTileClampY  — Single-tile: clamp Y, write OAM entry
$00CD89 (PRG $004D89)  oam_FindFreeSlot  — Search $1A00 buffer for empty OAM slot (byte=0)
$00CD9C (PRG $004D9C)  oam_WriteSlot  — Write tile+attrib data to found OAM slot
$00CDA2 (PRG $004DA2)  oam_NextEntity  — Advance X by $10 to next entity slot, loop or exit
$00CDB3 (PRG $004DB3)  oam_AllDone  — All 32 entities processed, RTS
$00CDB6 (PRG $004DB6)  clearOamExtTable  — Zeros OAM extended attribute table $1A00-$1C00. Called before buildEntityOam.
$00CDBE (PRG $004DBE)  clearOamExtTable_Loop  — Zero loop: STA $19FE,Y / DEY / BNE
$00CDCA (PRG $004DCA)  finalizeOam  — Post-OAM processing after entity sprites are built.
$00CDE8 (PRG $004DE8)  finalizeOam_Loop  — Main processing loop for OAM finalization
$00CDF6 (PRG $004DF6)  finalizeOam_Entry  — Process non-zero OAM entry

## Text (86 labels)

$00B67C (PRG $00367C)  fillTextBuffer_Phase1  — Phase 1 text engine: streams text from ROM into WRAM $0400 buffer. Dispatches FF control codes; calls unit-name copy, etc.
$00B68D (PRG $00368D)  textLoopStart  — Text loop: reads [$14],Y into $0400 buffer
$00B694 (PRG $003694)  ffCode_DispatchRange  — CMP #$09: low bytecodes (<$09) vs chars ($09-$FE) vs FF codes
$00B6A3 (PRG $0036A3)  ffCode_HandleLow  — Handles FF codes 01-08: DEC, stores to $01, reads param to $00, writes $D0 marker + kanji index to buffer
$00B6D6 (PRG $0036D6)  ffCode_PeekNext  — Peeks at byte after FF: <$80→buffer copy, $80-$BF→jump table, $C0-$F0→inline handler, >=$F1→buffer copy
$00B6E8 (PRG $0036E8)  ffCode_CheckC0  — CMP #$C0: codes $C0+ go to $BB33 inline handler
$00B6EF (PRG $0036EF)  ffCode_LowMask  — Dispatch table calc: (code AND $3F)*4+$B701 → JMP ($0000)
$00B701 (PRG $003701)  ffHighJumpTable  — FF codes $80-$BF jump table: 16 entries, 4 bytes each
$00B775 (PRG $003775)  ffLowBufferCopy  — FF codes < $80 and >= $F1: copies 3 raw bytes to $0400 buffer
$00B78D (PRG $00378D)  ffCode80_SetParam  — FF 80 handler: reads 1 inline byte via ffReadInlineByte, stores to $0A08 (text engine param)
$00B79C (PRG $00379C)  ffCode81_SetParamIndirect  — FF 81 handler: reads 3-byte ptr, loads indirect byte from [$00], stores to $0A08
$00B7AE (PRG $0037AE)  ffCode82_MultiplyParam  — FF 82 handler: hardware multiply $0A08 * inline byte via $4202/$4203, result from $4216→$0A08
$00B7CB (PRG $0037CB)  ffCode83_RenderWord  — FF 83 handler: reads 3-byte ptr, loads 16-bit indirect value, calls $BCD6 to render number
$00B7DD (PRG $0037DD)  ffCode84_RenderByte  — FF 84 handler: reads 3-byte ptr, loads 8-bit indirect value, calls $BCFF to render number
$00B810 (PRG $003810)  ffCode85_RenderClamped99  — FF 85 handler: reads ptr, loads byte clamped to 99, calls $BD06 (unit name copy)
$00B88B (PRG $00388B)  ffCode95_RenderClamped999  — FF 95 handler: reads ptr, loads value clamped to 999, renders number
$00B8E8 (PRG $0038E8)  ffCode_RenderCompoundName  — Reads 3-byte ptr, renders two string table lookups separated by $95 separator char
$00B904 (PRG $003904)  ffCode_RenderStringLookup  — Reads 3-byte ptr, looks up single string via lookupStringTable1
$00B90F (PRG $00390F)  lookupStringTable1  — Index*8 into table at $02:A050, copies chars to $0400 until $20 (space) terminator. NOT initRandomSeed.
$00B925 (PRG $003925)  lookupStringTable2  — Index*8 into table at $02:A298, copies chars to $0400 until $20 terminator. NOT getRandomNumber.
$00B939 (PRG $003939)  textBuf_ScanString  — Common string copy: [$00],Y → $0400,X until $20 terminator
$00B94A (PRG $00394A)  ffCode86_RenderSingleDigit  — FF 86 handler: reads ptr, byte clamped to 9, adds $30 ASCII, writes single digit
$00B961 (PRG $003961)  ffCode87_CopyStringDirect  — FF 87 handler: reads ptr, copies bytes from [$00] to $0400 until $00 or $20 terminator
$00BB65 (PRG $003B65)  ffReadInlineByte  — Helper: advances text stream Y, reads 1 byte, stores to $00
$00BB71 (PRG $003B71)  ffReadInlinePtr  — Helper: advances text stream Y by 3, reads 3-byte SNES pointer, stores to $00/$02
$00B985 (PRG $003985)  textRawCopyHandler  — Copies raw bytes from embedded 3-byte SNES ptrs in text
$00BB91 (PRG $003B91)  compareStrings  — Compares two strings. Entry: $12/$14=string1, $16/$18=string2. Returns Z flag set if equal.
$00BBA7 (PRG $003BA7)  ffReadInlineWord  — Reads 2 bytes from text stream [$14]+Y into $00/$01
$00BBB8 (PRG $003BB8)  endOfTextHandler  — Null byte handler: kanji tile copy + render trigger
$00BC75 (PRG $003C75)  renderTextWrapper  — Text render wrapper - sets up parameters and calls main text processor. Entry: expects text pointer at $14/$16. Sets $14=#$0400, $16=0, calls processText. Returns via RTL.
$00BCD6 (PRG $003CD6)  renderNumber5Digit  — Renders number to $0400 buffer as up to 5 decimal digits. Calls renderNumberToBuffer with divisors 10000, 1000, 100, 10, 1.
$00BCFF (PRG $003CFF)  renderNumber3Digit  — Alternate entry: starts rendering at hundreds place
$00BD06 (PRG $003D06)  renderNumber2Digit  — Alternate entry: starts rendering at tens place
$00BD9C (PRG $003D9C)  copyTextBuffer  — Copies text buffer data between buffers. Entry: $09F0/$09F2=source, $09F4=width, $09F6=height.
$00BE3B (PRG $003E3B)  renderTextStream  — Main text/dialogue renderer. Reads byte stream from [$14], processes control codes, writes tiles to buffer.
$00BE4F (PRG $003E4F)  textStreamLoop  — Main loop: read next byte from [$14], dispatch by control code
$00BE5B (PRG $003E5B)  textStream_CheckFF  — Check for $FF extended control code
$00BE63 (PRG $003E63)  textStream_Check90  — Check for $90 newline/scroll control code
$00BE6B (PRG $003E6B)  textStream_CheckD0  — Check for $D0 icon/special character code
$00BE75 (PRG $003E75)  textStream_WriteChar  — Write regular character tile and advance cursor
$00BE88 (PRG $003E88)  textStream_CheckAutoScroll  — Check if auto-scroll needed after character write
$00BE92 (PRG $003E92)  textStream_CheckLineEnd  — Compare cursor to line width, loop or handle overflow
$00BEBB (PRG $003EBB)  textStream_HandleD0  — $D0 handler: icon/special char - read param, compute tile, write
$00BEFB (PRG $003EFB)  textStream_SetPauseFlag  — Set pause/wait flag from control code ($91/$93/$94/$A0)
$00BF01 (PRG $003F01)  textStream_Handle90  — $90 newline handler: scroll text window if at bottom, reset cursor
$00BF2F (PRG $003F2F)  textStream_90_Advance  — Advance line counter, check if scroll needed
$00BF49 (PRG $003F49)  textStream_90_StoreLine  — Store new line position
$00BF4C (PRG $003F4C)  textStream_90_ResetCursor  — Reset cursor position and char count for new line
$00BF5E (PRG $003F5E)  textStream_Handle00  — $00 null terminator handler: check if at dialog bottom
$00BF64 (PRG $003F64)  processText  — Text engine Phase 2: renders buffer, dispatches by byte value
$00BF7D (PRG $003F7D)  textStream_HandleFF  — $FF extended control: read sub-command byte, dispatch
$00BFC2 (PRG $003FC2)  textStream_ExtF1  — Extended $F1: toggle text state flag
$00BFD4 (PRG $003FD4)  textStream_ExtF1_SetPos  — Extended $F1 param>1: set cursor Y position from param
$00BFE4 (PRG $003FE4)  textStream_ExtF2  — Extended $F2: write auto-delay value from stream
$00BFF1 (PRG $003FF1)  textStream_HandleExtended  — Extended control dispatcher ($F0-$FF sub-commands)
$00C022 (PRG $004022)  textStream_ExtFF  — Extended $FF: call monitorParty, then continue
$00C028 (PRG $004028)  textStream_ExtFE  — Extended $FE: call scrollTextWindow, then continue
$00C02D (PRG $00402D)  textStream_ExtFD  — Extended $FD: set auto-advance delay from stream byte (or $FF=from RAM)
$00C03B (PRG $00403B)  textStream_ExtFD_Store  — Store auto-advance delay value
$00C041 (PRG $004041)  textStream_ExtFB  — Extended $FB: set text Y offset from stream byte
$00C053 (PRG $004053)  textStream_ExtFC  — Extended $FC: choice/menu selection handler
$00C08D (PRG $00408D)  textStream_FC_CheckRight  — Choice handler: check right button press
$00C0A1 (PRG $0040A1)  textStream_FC_CheckCancel  — Choice handler: check B/cancel button
$00C0B4 (PRG $0040B4)  textStream_FC_CheckConfirm  — Choice handler: check A/confirm button
$00C0C9 (PRG $0040C9)  textStream_FC_Grid  — Extended $FC with param>=$80: grid-style choice menu
$00C0DC (PRG $0040DC)  textStream_FC_Grid_Loop  — Grid choice: hardware multiply for cursor position
$00C114 (PRG $004114)  textStream_FC_Grid_Down  — Grid choice: check down button
$00C128 (PRG $004128)  textStream_FC_Grid_Cancel  — Grid choice: check cancel
$00C13B (PRG $00413B)  textStream_FC_Grid_Confirm  — Grid choice: check confirm, store selection
$00C1B4 (PRG $0041B4)  setTextRenderParams  — Stores text layout params to $0A2E/$0A28/$0A2A/$0A2C. NOT compareValues.
$00C156 (PRG $004156)  writeTextCharacter  — Writes single character to text buffer. Entry: A=character code, X=buffer offset. Writes to top/bottom buffers based on $0A1C/$0A1E flags.
$00C17B (PRG $00417B)  writeTilemapEntry  — Writes tilemap entry for character to top/bottom buffers. Entry: character code on stack, X=buffer offset. Adds $0A02 (priority/palette bits) to character index. Writes to $7E9000,X (top tile) and $7E9040,X (bottom tile) with +$0400 palette difference. Each buffer holds 32 tiles (16x2 area), each entry 2 bytes: tile# low + VHPPCCCC (V=vert flip, H=horiz flip, P=priority, CCCC=palette).
$00C20E (PRG $00420E)  waitForFrame  — INC $57 (frame flag), JSL waitForModeSync. NOT absoluteValue.
$00C219 (PRG $004219)  readTextCursorState  — Loads $09FC/$09FE cursor position, adds $0A00. NOT negateValue.
$00C233 (PRG $004233)  calculateBufferOffset  — Calculates buffer position from column/row/width. Entry: $09FC=column, $09FE=row, $0A00=width. Returns X=offset.
$00C27F (PRG $00427F)  checkTextActive  — Checks $0A10 text pause flag; if zero returns, else falls into textWait_Frame. NOT calculateCosine.
$00C29A (PRG $00429A)  waitForButtonPressText  — Polls controller for any button press (#$F0F0 mask) during text display. NOT interpolateValue.
$00C2A9 (PRG $0042A9)  pollInputFlashCursor  — JSL readJoypadNewPress, flashes cursor indicator ($0E counter). NOT calculateDistance.
$00C2E1 (PRG $0042E1)  setTextScrollParams  — Stores text scroll parameters to $0A36/$0A38/$0A3A. NOT calculateSlope.
$00DE05 (PRG $005E05)  loadFontTile  — Loads font tile data to VRAM - writes each byte to both $2118 and $2119 (2bpp from 1bpp source). Entry: X=VRAM address, Y=tile count, $12/$14=font data pointer.
$01ABF4 (PRG $00ABF4)  drawTextString  — Draws text string instantly (static renderer). Entry: $12/$14=text pointer, $00/$02=position. Renders entire text block at once without timing delays. Used for menus, HUD, between-level text, item/spell names. Part of dual-renderer system's static renderer.
$01B851 (PRG $00B851)  clearTextBuffer  — Clears text buffer for new message. Entry: resets text position variables ($09FC/$09FE), clears tilemap buffer area ($7E9000-$7E907F). Sets up for new message in dual-renderer system. Called before rendering any text block.
$01B872 (PRG $00B872)  setTextColor  — Sets text color palette for rendering. Entry: A=color index (0-15). Updates $0A02 priority/palette bits. Affects all subsequent character rendering until changed. Used for emphasis, different text types (dialog, menu, system messages).
$01B884 (PRG $00B884)  drawNumber  — Draws numeric value as decimal string. Entry: A=number (0-9999), $00/$02=screen position. Converts to decimal digits, renders using text system. Used for stats, gold, HP/MP values in HUD and menus.
$01C1DE (PRG $00C1DE)  drawButtonIcons  — Draws controller button icons in help text. Entry: A=button combination. Renders button graphics using special character codes ($D0 control code). Used in tutorials and help screens.
$01EE67 (PRG $00EE67)  monitorInput_textDispatch  — JSL TextPtrDispatch hook site
$028000 (PRG $010000)  textMetaTable  — 20 entries mapping text IDs to ptr table locations
$2EAA54 (PRG $172A54)  TextPtrDispatch  — Custom ptr dispatch: 2-byte vs 3-byte by bank

## Music (86 labels)

$00975E (PRG $00175E)  playBGM  — Plays background music. Entry: A=music track ID. Sends command to SPC700 via APU ports.
$00C70E (PRG $00470E)  uploadSPCProgram  — Uploads SPC700 sound program to APU. Entry: $12/$14=SPC program data. Follows SPC boot protocol.
$00C82B (PRG $00482B)  sendSPCCommand  — Sends command to SPC700. Entry: A=command, X=data1, Y=data2. Writes to $2140-$2143.
$00EB00 (PRG $006B00)  musicCmd_DispatchHigh  — Dispatch $F4-$FB music commands to handlers
$00EB0B (PRG $006B0B)  musicCmd_CheckF5  — Check for $F5 command (set envelope params)
$00EB16 (PRG $006B16)  musicCmd_CheckF6  — Check for $F6 command (loop/repeat control)
$00EB21 (PRG $006B21)  musicCmd_CheckF7  — Check for $F7 command (note with pitch data)
$00EB29 (PRG $006B29)  musicCmd_CheckF8  — Check for $F8 command (voice setup)
$00EB31 (PRG $006B31)  musicCmd_CheckFA  — Check for $FA command (channel setup)
$00EB39 (PRG $006B39)  musicCmd_CheckFB  — Check for $FB command (end track/return)
$00EB41 (PRG $006B41)  musicCmd_DispatchNote  — Dispatch by note/command byte range: $E0+, $D0+, $C0+, $B0+, $A0+, $90+, $80+, $70+, $60+
$00EB50 (PRG $006B50)  musicCmd_RangeD0  — Handle $D0-$DF range — write indexed value
$00EB58 (PRG $006B58)  musicCmd_RangeC0  — Handle $C0-$CF range — write indexed value
$00EB60 (PRG $006B60)  musicCmd_RangeB0  — Handle $B0-$BF range — spawn sub-voice
$00EB68 (PRG $006B68)  musicCmd_RangeA0  — Handle $A0-$AF range — jump table dispatch
$00EB70 (PRG $006B70)  musicCmd_Range90  — Handle $90-$9F range — pitch adjust (signed)
$00EB78 (PRG $006B78)  musicCmd_Range80  — Handle $80-$8F range — multi-byte note data
$00EB80 (PRG $006B80)  musicCmd_Range70  — Handle $70-$7F range — check voice status
$00EB88 (PRG $006B88)  musicCmd_Range60  — Handle $60-$6F range — rest/duration. Store to $1C/$1D.
$00EB90 (PRG $006B90)  musicCmd_Range60_Store  — Store duration low 6 bits to voice timer $1C/$1D, set next ptr
$00EBAD (PRG $006BAD)  musicCmd_RangeE0  — Handle $E0-$EB command range dispatch
$00EBB5 (PRG $006BB5)  musicCmd_E2  — $E2: set loop return address
$00EBBD (PRG $006BBD)  musicCmd_E0  — $E0: jump — load new music data pointer from [$8D]
$00EBC9 (PRG $006BC9)  musicCmd_E3  — $E3: call subroutine (via $F174)
$00EBD1 (PRG $006BD1)  musicCmd_E4  — $E4: return from subroutine (via $F126)
$00EBD9 (PRG $006BD9)  musicCmd_E5  — $E5: loop back (via $F162)
$00EBE1 (PRG $006BE1)  musicCmd_E6  — $E6: conditional branch (via $F251)
$00EBE9 (PRG $006BE9)  musicCmd_E7  — $E7: set register (via $F26E)
$00EBF1 (PRG $006BF1)  musicCmd_E8  — $E8: compare/test (via $F2A8)
$00EBF9 (PRG $006BF9)  musicCmd_E9  — $E9: branch on compare (via $F2BF)
$00EC01 (PRG $006C01)  musicCmd_EA  — $EA: arithmetic op (via $F2CD)
$00EC09 (PRG $006C09)  musicCmd_EB  — $EB: bitwise op (via $F2D8)
$00EC11 (PRG $006C11)  musicCmd_Unknown  — Unknown command — skip, jump back to main loop
$00EC14 (PRG $006C14)  musicNote_CheckTimer  — Check note timer — if zero, reload duration and advance; else decrement
$00EC23 (PRG $006C23)  musicNote_Reload  — Timer zero — reload from $1D, set $1C
$00EC2A (PRG $006C2A)  musicNote_Advance  — Advance music data pointer after note completes
$00EC5E (PRG $006C5E)  musicCmd_E1  — $E1: push return address to music stack $0F00, jump to target
$00EDA3 (PRG $006DA3)  musicCmd_F4_PitchAdjust  — $F4/$90+: signed pitch adjustment on voice
$00EDA6 (PRG $006DA6)  musicCmd_F4_ReadParams  — Read pitch adjust params: signed offset + duration
$00EDD3 (PRG $006DD3)  musicCmd_F5_SetEnvelope  — $F5/$60+: set envelope params (attack, decay, sustain rate)
$00EDD6 (PRG $006DD6)  musicCmd_F5_ReadParams  — Read envelope: attack rate ($0E), decay rate ($10), sustain ($12)
$00EE09 (PRG $006E09)  musicCmd_F6_Loop  — $F6: loop control — decrement counter $1A, repeat or advance
$00EE19 (PRG $006E19)  musicCmd_F6_Continue  — Loop counter nonzero — advance and loop back
$00EE1E (PRG $006E1E)  musicCmd_F6_Init  — Loop counter zero — initialize from stream byte
$00EE2C (PRG $006E2C)  musicCmd_A0_JumpTable  — $A0-$AF: indirect jump table dispatch at $EE3A
$00EE7A (PRG $006E7A)  musicCmd_F8_VoiceSetup  — $F8: setup voice — read params, configure channel base + target
$00EEC1 (PRG $006EC1)  musicCmd_FA_ChannelSetup  — $FA: channel setup — clear flags, configure base/target addresses
$00F0F3 (PRG $0070F3)  musicCmd_FB_EndTrack  — $FB: end track — store final pointer, RTS
$00F104 (PRG $007104)  musicDSP_LoadEffectTable  — Load DSP effect parameters from table. A=effect index, looks up from $0D8004.
$00F126 (PRG $007126)  musicCmd_E4_Return  — $E4: return from music subroutine. Reads return address, dispatches based on value.
$00F137 (PRG $007137)  musicCmd_E4_Special  — Return value >= $8000 — special dispatch (not normal return)
$00F145 (PRG $007145)  musicCmd_E4_Special2  — Return value == $FFFF — alternate special return
$00F14A (PRG $00714A)  musicCmd_E4_Special3  — Return value == $FFFE — third special return type
$00F156 (PRG $007156)  musicCmd_E4_Normal  — Normal return: add base $0A9B to offset, set as new music ptr
$00F162 (PRG $007162)  musicCmd_E5_LoopBack  — $E5: clear loop flags (high nibble of +$01) and return to main loop
$00F174 (PRG $007174)  musicStream_ReadVoiceParam  — Read voice parameter byte from stream. $FF triggers smoke effect; $29 is special; else used as voice index.
$00F189 (PRG $007189)  musicStream_ReadVoiceParam_Check29  — Check if param == $29 (special voice)
$00F19D (PRG $00719D)  musicStream_ReadVoiceParam_Normal  — Normal voice param: compute voice table offset
$00F1AB (PRG $0071AB)  musicStream_ReadVoiceParam_Offset  — Compute final voice offset from param
$00F1B1 (PRG $0071B1)  musicStream_ReadVoiceParam_Done  — Voice param resolved, return Y=voice ptr
$00F1D4 (PRG $0071D4)  musicPtr_Rewind  — Rewind music data pointer by 2 (DEC DEC), store to +$06. Used for loop-back.
$00F251 (PRG $007251)  musicCmd_E6_CondFlag  — $E6: conditional flag. $FFFF toggles $0AA5; else stores to $0AA7/$0AAD.
$00F265 (PRG $007265)  musicCmd_E6_StoreFlag  — Store conditional flag value
$00F26E (PRG $00726E)  musicCmd_E7_SetReg  — $E7: read byte, if nonzero compute screen brightness/fade from $99. Sets $6B/$6D.
$00F280 (PRG $007280)  musicCmd_E7_CalcBrightness  — Compute brightness: $100 - $99, store to display vars
$00F2A8 (PRG $0072A8)  musicCmd_E8_Compare  — $E8: read two words, store to $0AA7 (mask) and $0AAD (compare value). $8F to $0AAF.
$00F2BF (PRG $0072BF)  musicCmd_E9_BranchByte  — $E9: read byte from stream, store to +$0D as branch offset
$00F2CD (PRG $0072CD)  musicCmd_EA_CondJump  — $EA: if $0AA7 flag nonzero, rewind ptr (loop); else skip
$00F2D5 (PRG $0072D5)  musicCmd_EA_Skip  — Flag zero — skip to main loop
$00F2D8 (PRG $0072D8)  musicCmd_EB_SetTimer  — $EB: read byte from stream, store to $81 as timer/counter value
$00F2E5 (PRG $0072E5)  musicStream_ReadSignedByte  — Read byte from music stream [$8D], sign-extend if >= $80. Returns signed 16-bit in A.
$00F2F4 (PRG $0072F4)  musicStream_ReadSignedByte_Done  — Return path for signed byte read
$00F2F5 (PRG $0072F5)  musicStream_ReadWord  — Read 16-bit word from music stream [$8D]. Advances pointer by 2.
$00F2FC (PRG $0072FC)  musicStream_ReadByteThenExtend  — Read byte from stream, fall through to sign-extend/negate helper
$00F300 (PRG $007300)  musicHelper_SignExtendNegate  — Sign-extend and negate byte: if >= $80, invert and ASL*4; else pass through. For pitch/volume deltas.
$00F318 (PRG $007318)  musicHelper_SignExtendNegate_Pos  — Positive path: just ASL*4
$00F31D (PRG $00731D)  musicHelper_GetChannelIndex  — Extract channel index from A low nibble. If $0E, read extra param via $F374.
$00F32B (PRG $00732B)  musicHelper_GetVoicePtr  — Get voice table pointer in Y ($1000 or $1200) from channel index. Checks bit13 of entity flags.
$00F340 (PRG $007340)  musicHelper_GetVoicePtr_Select  — Select voice table offset based on channel
$00F374 (PRG $007374)  musicHelper_GetVoiceSlot  — Get voice slot pointer in Y from $000D,X channel field. Computes Y = (field & 0xF) * 32 + $1000.
$00F397 (PRG $007397)  musicHelper_WriteSPCRegister  — Write value ($40) to SPC voice register. Handles timing sync with A6/A7 flags.
$00F45C (PRG $00745C)  musicVoice_SetTarget  — Set voice target position/pitch. Stores A to +$02, Y to +$16, compares target to +$18 for interpolation.
$0188B6 (PRG $0088B6)  playTitleMusic  — Plays title screen music. Entry: starts BGM track 0.
$019CA2 (PRG $009CA2)  playBattleBGM  — Plays battle music based on enemy type. Entry: A=music track ID (0=normal, 1=boss).
$2BDE0C (PRG $15DE0C)  externalSoundFunc1  — External sound function 1. Entry: advanced audio processing.
$2BDEC3 (PRG $15DEC3)  externalSoundFunc2  — External sound function 2. Entry: additional audio operations.

## Effects (57 labels)

$008D56 (PRG $000D56)  enableScreen  — Enables screen display by setting brightness. Entry: A=brightness value (0-15). Writes to $2100.
$0097B8 (PRG $0017B8)  fadeScreen  — Screen fade effect (in/out). Entry: A=0 for fade in, 1 for fade out. Updates $2100 brightness gradually.
$009D8D (PRG $001D8D)  animateBattleEffect  — Animates battle visual effect (spell, attack). Entry: A=effect type. Updates OAM for effect animation over multiple frames.
$00ABD5 (PRG $002BD5)  initWeatherSlots  — Initialize weather/particle slots at $1200. A=count, X=base offset, Y=stride. Fills with $FFFF.
$00ABE4 (PRG $002BE4)  initWeatherSlots_Loop  — Fill loop: STA $0000,X / ADC #8 / DEY / BNE
$00ABF4 (PRG $002BF4)  updateWeatherEffect  — Updates weather/lightning visual effects. Entry: sets up effect parameters, calls getRandomValue.
$00B525 (PRG $003525)  fadeToBlack  — Fades screen to black for transitions. Entry: called before scene changes. Gradual fade via $2100.
$00D8F9 (PRG $0058F9)  dmaTextTileToVRAM  — DMA ch1: $7E:9000 → VRAM $7C00. Uploads text tilemap. SEP mode, $2115=$80 (word inc).
$00D927 (PRG $005927)  dmaTilemapToVRAM  — DMA ch1: $7F:B000 → VRAM at [$78]. Uploads tilemap buffer. SEP mode.
$00D954 (PRG $005954)  dmaOverlayToVRAM  — DMA ch1: $7F:D000 → VRAM $5C00. Uploads overlay tilemap. SEP mode.
$00DE68 (PRG $005E68)  setupOAMTransfer  — PHY/PHX/PHA, STA $2101 (OBSEL=#$00), JSR writeOAMBuffer. Sets up OAM sprite config.
$00DEA0 (PRG $005EA0)  writeOAMBuffer  — STA $2102/$2103 (OAMADD=#$0000), DMA or loop-write OAM low table ($200 bytes) + high table.
$00DF47 (PRG $005F47)  hardwareMultiplyRng  — STA $4202 (WRMPYA=A), INC $52 RNG counter, indexes table, reads $4216 result. Returns product. RTL.
$00DF72 (PRG $005F72)  getRandomValue  — INC $52, indexes lookup table at $DFB7,X. Returns pseudo-random value. Used widely for RNG.
$00DF8C (PRG $005F8C)  dmaToVRAMGeneric  — DMA ch1: $2115=$80, X→$2116 (VMADD), Y→$4315 (size), $14→$4314 (bank), configures src. Generic VRAM DMA.
$00E102 (PRG $006102)  irqBgSwapHandler  — H-IRQ handler: SEI, acks $4211, conditionally sets BG tilemap/CHR bases ($2107/$2109), resets BG3/4 scroll regs, sets screen designation ($212C/$212D), reprograms H-IRQ ($4209) from $66. Ends RTI.
$00E144 (PRG $006144)  memcpyWords  — Generic word-copy. Entry: A=byte count, [$12]=src, [$16]=dst. Copies A/2 words. RTL.
$00E157 (PRG $006157)  memfillWords  — Generic word-fill. Entry: A=byte count, X=fill value, [$12]=dst. Fills A/2 words. RTL.
$00E22D (PRG $00622D)  initMapScene  — Full scene init: JSL loadMapData, force blank ($2100=#$8F), disable IRQ/DMA/HDMA ($4200/$420B/$420C=0), clear $0A87 debug flag, reset DP=$0000, clear scroll/state vars, call setupMapObjects + updateWaterEffect.
$00E383 (PRG $006383)  uploadPaletteCGRAM  — Uploads palette data to CGRAM. Entry: stack args = CGRAM addr, src ptr, count. Writes $2121 (CGADD), loops $2122 (CGDATA) for N color entries. RTS.
$00E3BE (PRG $0063BE)  waitForModeSync  — Checks $10 game mode (2/3 = special), zeros $10/$4A, waits for $4A flag to change. RTL.
$00E3DD (PRG $0063DD)  repeatModeSync  — Calls waitForModeSync A times in a loop. Entry: A=repeat count. RTL.
$00E3F0 (PRG $0063F0)  readJoypadNewPress  — Reads joypad via $4218/$4219 after waiting for H-blank ($4212 bit 0). Stores raw to $4E/$4F, computes new-press (XOR+AND old) to $50. RTL.
$00E432 (PRG $006432)  initObjectTable  — Clears $1000 object table (1KB, $400 bytes), then builds initial object entries via buildObjectEntry. Entry: sets up object pool for scene/battle.
$00E4E2 (PRG $0064E2)  initObjectTableAlt  — Variant of initObjectTable: clears $1000 and builds a different set of object entries. Used for alternate scene init.
$00E58F (PRG $00658F)  initSingleObject  — Calls setObjectOffsets to clear HDMA offsets, then builds one object entry via buildObjectEntry. Mode 7 object setup.
$00E5D6 (PRG $0065D6)  setObjectOffsets  — Stores X→$0A9F, Y→$0AA1, Y+$7C→$0AA3. Sets base offsets for object table positioning. RTL.
$00E5E5 (PRG $0065E5)  lookupDataTable  — Entry: A=index (0-$3F). Looks up ROM table at bank $0D or $0C depending on index range. Returns value from table. Used for tile/sprite data lookup.
$00E611 (PRG $006611)  loadDspEffectParams  — Loads DSP effect parameters. Entry: A=effect index (masked $7F). JSR $F104 (table lookup). RTL.
$00E61C (PRG $00661C)  buildObjectEntry  — Builds one 32-byte object entry at X: zeros 16 words, reads 5 params from data stream [$40], applies $0A9F/$0AA1 position offsets, sets control word $80FF + state flags. RTS.
$00E688 (PRG $006688)  initObjectStreamReader  — Sets up data stream pointers: $3A=$0100, $3C=$0300, $3E=$0280, $9F=$8000. Configures object reader for subsequent buildObjectEntry calls.
$00E7B7 (PRG $0067B7)  updateObjectPhysics  — Per-object movement update: reads 2-bit state from $0001,X; dispatches 4 cases (0=inactive, 1=accumulate, 2=velocity, 3=transition). Applies velocity ($000E/$0010) to position ($0003/$0017) with 8-bit fractional. RTS.
$00E8A7 (PRG $0068A7)  renderObjectList  — Iterates object table, dispatches by $0001,X state bits. Copies position fields ($0004/$0018) to $99/$9B for OAM rendering. Calls updateObjectPhysics per entry.
$019114 (PRG $009114)  drawSpellEffect  — Draws spell visual effect graphics. Entry: A=spell ID, renders particles, glows.
$0191D7 (PRG $0091D7)  drawDamageSpark  — Draws damage hit spark effect. Entry: A=damage type, renders spark particles.
$01921F (PRG $00921F)  drawHealEffect  — Draws healing effect animation. Entry: A=heal power, renders glow, particles.
$0199CD (PRG $0099CD)  drawDamageNumbers  — Draws floating damage numbers in battle. Entry: A=damage amount, $00/$02=position.
$01B958 (PRG $00B958)  runScreenEffect  — Runs screen effect with timers and visual updates. Entry: sets up effect parameters, calls loadDspEffectParams, initObjectTable.
$01B9E2 (PRG $00B9E2)  initScreenTransition  — Initializes screen transition effect. Entry: sets $0958=$FFFF, calls dispatchGameMode, sets up graphics.
$01BA3F (PRG $00BA3F)  updateRandomEffect  — Updates random visual effect. Entry: uses $0C/$0E timers, calls getRandomValue, updates $4F.
$01BA79 (PRG $00BA79)  handleInputEffect  — Handles input-based effect movement. Entry: reads $4F for direction flags, updates $26 position based on input.
$01BB84 (PRG $00BB84)  setupHDMAEffect  — Sets up HDMA effect table. Entry: configures $4360 HDMA channel, builds table at $7EA000.
$01BBD3 (PRG $00BBD3)  buildHDMATable  — Builds HDMA table for screen effect. Entry: uses $0980-$0986 parameters, writes to $7EA000 table.
$01BDB9 (PRG $00BDB9)  setupEffectTimer  — Sets up effect timer with calculations. Entry: calls calculateEffectValue, stores in $0E58, sets $0A00.
$01C67A (PRG $00C67A)  setupTransparency  — Sets up transparency/color math for effects. Entry: A=effect type (fade, blend, etc).
$01C6A6 (PRG $00C6A6)  handleScreenShake  — Handles screen shake effect (earthquake, impact). Entry: A=intensity, updates scroll registers.
$01C91E (PRG $00C91E)  flashScreen  — Flash screen effect (white/color flash). Entry: A=color, X=duration.
$01C986 (PRG $00C986)  pulseEffect  — Pulse effect for highlighting. Entry: A=target, updates brightness cyclically.
$01C994 (PRG $00C994)  drawScanlineEffect  — Sets up scanline color effect via HDMA. Entry: A=effect type (gradient, split, etc).
$01C9F1 (PRG $00C9F1)  updateScanlineEffect  — Updates scanline effect parameters. Entry: modifies HDMA table in real-time.
$01CA0A (PRG $00CA0A)  setupMosaic  — Sets up mosaic effect for transition. Entry: A=intensity, applies to BG/OBJ layers.
$01CA21 (PRG $00CA21)  updateMosaic  — Updates mosaic effect over time. Entry: called each frame during transition.
$01CA5A (PRG $00CA5A)  setupWindowMask  — Sets up window masking for effects. Entry: A=window ID, $00-$03=coordinates.
$01CA94 (PRG $00CA94)  updateWindowMask  — Updates window mask position/size. Entry: animates window for reveal effects.
$01CAA1 (PRG $00CAA1)  handleTransitionWipe  — Handles screen transition wipes (circle, square, etc). Entry: A=wipe type.
$01CB6C (PRG $00CB6C)  drawTransitionMask  — Draws transition mask shape to window. Entry: A=shape, updates window data.
$01D638 (PRG $00D638)  callEffectFunction  — Calls effect function with parameter. Entry: A=function ID, calls $EE4A twice with different parameters.

## Entity (21 labels)

$009377 (PRG $001377)  getTileDataPointer  — Calculates pointer to tile data table. Entry: A=index. Returns $12/$14=pointer (bank $21, base $C000 + A*$28 stride).
$009397 (PRG $001397)  checkTileFlag  — Checks flag bit in tile data structure. Entry: A=bit mask position, $12/$14=data pointer. Returns A=adjusted value (adds $0400 if flag set).
$009F76 (PRG $001F76)  clearObjectBuffer  — Clears $7F:A000 buffer ($1000 bytes) via memfillWords, then calls lookupTilemapEntry. Entry: none.
$00A0A4 (PRG $0020A4)  searchTilemapTable  — Iterates $7FA000 table comparing to $22. For each match, toggles bit 15 of $7F9000,X entry. Entry: searches tilemap data.
$00A103 (PRG $002103)  readTilemapValue  — Adds $28 offset to A, reads $7F9000,X, checks bit 15 ($8000). Called from searchTilemapTable and others.
$00A157 (PRG $002157)  skipIfZero  — TAY, BNE skip, RTL. Null-check wrapper — returns immediately if A=0.
$00A9A4 (PRG $0029A4)  scenarioDispatch  — Reads $7EEA82 (scenario#), compares #$1F, calls processAIscript with A=#$0002. Scenario-specific handler.
$00A9DF (PRG $0029DF)  checkAbilityLearned  — Checks if character has learned an ability. Entry: A=character ID, X=ability ID. Returns carry set if learned.
$00B00F (PRG $00300F)  textBuf_CalcTileIndex  — Tile index calculator for text buffer: CMP #$1000, ASL×4, checks $8000 bound. Part of text tile rendering pipeline.
$0195DC (PRG $0095DC)  awardBattleRewards  — Awards XP, gold, items after battle victory. Entry: calculates based on enemy levels.
$019A05 (PRG $009A05)  updateStatusEffects  — Updates status effect timers and applications. Entry: called each turn for all units.
$019A99 (PRG $009A99)  checkAbilityCondition  — Checks if ability can be used (MP, conditions). Entry: A=ability ID, X=caster. Returns carry if usable.
$019AA6 (PRG $009AA6)  executeAbility  — Executes special ability in battle. Entry: A=ability ID, X=caster, Y=target.
$01AD3B (PRG $00AD3B)  processEntityLoop  — Processes entity loop for values 0-31. Entry: $0EA8=entity count, calls sub_00AD60 for each entity.
$01AD60 (PRG $00AD60)  updateEntity  — Updates single entity. Entry: X=entity index, reads from $1400 table, processes based on $0946.
$01B211 (PRG $00B211)  getRandomEntity  — Gets random entity from pool. Entry: calls getRandomValue, checks $1800 table.
$01B237 (PRG $00B237)  findAvailableEntity  — Finds available entity slot. Entry: calls sub_009EFD, checks for $FFFF, reads $1800 table.
$01B456 (PRG $00B456)  setupEntityData  — Sets up entity data structure. Entry: A=entity type, Y=parameter. Writes to $1800-$180A structure.
$01D1E3 (PRG $00D1E3)  processEntityBatch  — Processes batch of entities. Entry: $098C=start index, processes up to 8 entities, calls sub_00D217 for each.
$01D217 (PRG $00D217)  setupEntityParameter  — Sets up entity parameter from table. Entry: Y=$0E00 base, calls sub_00DC04, reads $0E10, looks up in $01D123 table.
$01D533 (PRG $00D533)  calculateEntityValue  — Calculates entity value with offset. Entry: $098C=base, $098A=offset, $0994=adjustment, reads $1000 table.

## Helper (203 labels)

$008CFD (PRG $000CFD)  waitForVBlank  — Waits for V-Blank by polling $4212. Entry: none. Loops until V-blank flag is set.
$00A100 (PRG $002100)  INIDISP  — Screen Display Register
$00A101 (PRG $002101)  OBSEL  — Object Size and Character Size Register
$00A102 (PRG $002102)  OAMADDL  — OAM Address Registers (Low)
$00A103 (PRG $002103)  OAMADDH  — OAM Address Registers (High)
$00A104 (PRG $002104)  OAMDATA  — OAM Data Write Register
$00A105 (PRG $002105)  BGMODE  — BG Mode and Character Size Register
$00A106 (PRG $002106)  MOSAIC  — Mosaic Register
$00A107 (PRG $002107)  BG1SC  — BG Tilemap Address Registers (BG1)
$00A108 (PRG $002108)  BG2SC  — BG Tilemap Address Registers (BG2)
$00A109 (PRG $002109)  BG3SC  — BG Tilemap Address Registers (BG3)
$00A10A (PRG $00210A)  BG4SC  — BG Tilemap Address Registers (BG4)
$00A10B (PRG $00210B)  BG12NBA  — BG Character Address Registers (BG1&2)
$00A10C (PRG $00210C)  BG34NBA  — BG Character Address Registers (BG3&4)
$00A10D (PRG $00210D)  BG1HOFS  — BG Scroll Registers (BG1)
$00A10E (PRG $00210E)  BG1VOFS  — BG Scroll Registers (BG1)
$00A10F (PRG $00210F)  BG2HOFS  — BG Scroll Registers (BG2)
$00A110 (PRG $002110)  BG2VOFS  — BG Scroll Registers (BG2)
$00A111 (PRG $002111)  BG3HOFS  — BG Scroll Registers (BG3)
$00A112 (PRG $002112)  BG3VOFS  — BG Scroll Registers (BG3)
$00A113 (PRG $002113)  BG4HOFS  — BG Scroll Registers (BG4)
$00A114 (PRG $002114)  BG4VOFS  — BG Scroll Registers (BG4)
$00A115 (PRG $002115)  VMAIN  — Video Port Control Register
$00A116 (PRG $002116)  VMADDL  — VRAM Address Registers (Low)
$00A117 (PRG $002117)  VMADDH  — VRAM Address Registers (High)
$00A118 (PRG $002118)  VMDATAL  — VRAM Data Write Registers (Low)
$00A119 (PRG $002119)  VMDATAH  — VRAM Data Write Registers (High)
$00A11A (PRG $00211A)  M7SEL  — Mode 7 Settings Register
$00A11B (PRG $00211B)  M7A  — Mode 7 Matrix Registers
$00A11C (PRG $00211C)  M7B  — Mode 7 Matrix Registers
$00A11D (PRG $00211D)  M7C  — Mode 7 Matrix Registers
$00A11E (PRG $00211E)  M7D  — Mode 7 Matrix Registers
$00A11F (PRG $00211F)  M7X  — Mode 7 Matrix Registers
$00A120 (PRG $002120)  M7Y  — Mode 7 Matrix Registers
$00A121 (PRG $002121)  CGADD  — CGRAM Address Register
$00A122 (PRG $002122)  CGDATA  — CGRAM Data Write Register
$00A123 (PRG $002123)  W12SEL  — Window Mask Settings Registers
$00A124 (PRG $002124)  W34SEL  — Window Mask Settings Registers
$00A125 (PRG $002125)  WOBJSEL  — Window Mask Settings Registers
$00A126 (PRG $002126)  WH0  — Window Position Registers (WH0)
$00A127 (PRG $002127)  WH1  — Window Position Registers (WH1)
$00A128 (PRG $002128)  WH2  — Window Position Registers (WH2)
$00A129 (PRG $002129)  WH3  — Window Position Registers (WH3)
$00A12A (PRG $00212A)  WBGLOG  — Window Mask Logic registers (BG)
$00A12B (PRG $00212B)  WOBJLOG  — Window Mask Logic registers (OBJ)
$00A12C (PRG $00212C)  TM  — Screen Destination Registers
$00A12D (PRG $00212D)  TS  — Screen Destination Registers
$00A12E (PRG $00212E)  TMW  — Window Mask Destination Registers
$00A12F (PRG $00212F)  TSW  — Window Mask Destination Registers
$00A130 (PRG $002130)  CGWSEL  — Color Math Registers
$00A131 (PRG $002131)  CGADSUB  — Color Math Registers
$00A132 (PRG $002132)  COLDATA  — Color Math Registers
$00A133 (PRG $002133)  SETINI  — Screen Mode Select Register
$00A134 (PRG $002134)  MPYL  — Multiplication Result Registers
$00A135 (PRG $002135)  MPYM  — Multiplication Result Registers
$00A136 (PRG $002136)  MPYH  — Multiplication Result Registers
$00A137 (PRG $002137)  SLHV  — Software Latch Register
$00A138 (PRG $002138)  OAMDATAREAD  — OAM Data Read Register
$00A139 (PRG $002139)  VMDATALREAD  — VRAM Data Read Register (Low)
$00A13A (PRG $00213A)  VMDATAHREAD  — VRAM Data Read Register (High)
$00A13B (PRG $00213B)  CGDATAREAD  — CGRAM Data Read Register
$00A13C (PRG $00213C)  OPHCT  — Scanline Location Registers (Horizontal)
$00A13D (PRG $00213D)  OPVCT  — Scanline Location Registers (Vertical)
$00A13E (PRG $00213E)  STAT77  — PPU Status Register
$00A13F (PRG $00213F)  STAT78  — PPU Status Register
$00A140 (PRG $002140)  APUIO0  — APU IO Registers
$00A141 (PRG $002141)  APUIO1  — APU IO Registers
$00A142 (PRG $002142)  APUIO2  — APU IO Registers
$00A143 (PRG $002143)  APUIO3  — APU IO Registers
$00A180 (PRG $002180)  WMDATA  — WRAM Data Register
$00A181 (PRG $002181)  WMADDL  — WRAM Address Registers
$00A182 (PRG $002182)  WMADDM  — WRAM Address Registers
$00A183 (PRG $002183)  WMADDH  — WRAM Address Registers
$00AEAE (PRG $002EAE)  compareAndSwapValues  — Compares and swaps values in $1200/$1201 table. Entry: X=index1, Y=index2, compares values, swaps if needed.
$00AEDD (PRG $002EDD)  maskAndProcessValue  — Masks and processes 8-bit value. Entry: A=value, masks with $00FF, processes further.
$00B0F1 (PRG $0030F1)  lookupTableEntry  — Look up entry in BE-header table. A=ID to find. [$12]=table ptr. Returns match index in $00.
$00C016 (PRG $004016)  JOYSER0  — Old Style Joypad Registers
$00C017 (PRG $004017)  JOYSER1  — Old Style Joypad Registers
$00C152 (PRG $004152)  checkZeroWrapper  — Wrapper for checkZero function. Entry: A=value. Returns via RTL.
$00C200 (PRG $004200)  NMITIMEN  — Interrupt Enable Register
$00C201 (PRG $004201)  WRIO  — IO Port Write Register
$00C202 (PRG $004202)  WRMPYA  — Multiplicand Registers
$00C203 (PRG $004203)  WRMPYB  — Multiplicand Registers
$00C204 (PRG $004204)  WRDIVL  — Divisor & Dividend Registers
$00C205 (PRG $004205)  WRDIVH  — Divisor & Dividend Registers
$00C206 (PRG $004206)  WRDIVB  — Divisor & Dividend Registers
$00C207 (PRG $004207)  HTIMEL  — IRQ Timer Registers (Horizontal - Low)
$00C208 (PRG $004208)  HTIMEH  — IRQ Timer Registers (Horizontal - High)
$00C209 (PRG $004209)  VTIMEL  — IRQ Timer Registers (Vertical - Low)
$00C20A (PRG $00420A)  VTIMEH  — IRQ Timer Registers (Vertical - High)
$00C20B (PRG $00420B)  MDMAEN  — DMA Enable Register
$00C20C (PRG $00420C)  HDMAEN  — HDMA Enable Register
$00C20D (PRG $00420D)  MEMSEL  — ROM Speed Register
$00C210 (PRG $004210)  RDNMI  — Interrupt Flag Registers
$00C211 (PRG $004211)  TIMEUP  — Interrupt Flag Registers
$00C212 (PRG $004212)  HVBJOY  — PPU Status Register
$00C213 (PRG $004213)  RDIO  — IO Port Read Register
$00C214 (PRG $004214)  RDDIVL  — Multiplication Or Divide Result Registers (Low)
$00C215 (PRG $004215)  RDDIVH  — Multiplication Or Divide Result Registers (High)
$00C216 (PRG $004216)  RDMPYL  — Multiplication Or Divide Result Registers (Low)
$00C217 (PRG $004217)  RDMPYH  — Multiplication Or Divide Result Registers (High)
$00C218 (PRG $004218)  JOY1L  — Controller Port Data Registers (Pad 1 - Low)
$00C219 (PRG $004219)  JOY1H  — Controller Port Data Registers (Pad 1 - High)
$00C21A (PRG $00421A)  JOY2L  — Controller Port Data Registers (Pad 2 - Low)
$00C21B (PRG $00421B)  JOY2H  — Controller Port Data Registers (Pad 2 - High)
$00C21C (PRG $00421C)  JOY3L  — Controller Port Data Registers (Pad 3 - Low)
$00C21D (PRG $00421D)  JOY3H  — Controller Port Data Registers (Pad 3 - High)
$00C21E (PRG $00421E)  JOY4L  — Controller Port Data Registers (Pad 4 - Low)
$00C21F (PRG $00421F)  JOY4H  — Controller Port Data Registers (Pad 4 - High)
$00C300 (PRG $004300)  DMAP0  — (H)DMA Control
$00C301 (PRG $004301)  BBAD0  — (H)DMA B-Bus Address
$00C302 (PRG $004302)  A1T0L  — DMA A-Bus Address / HDMA Table Address (Low)
$00C303 (PRG $004303)  A1T0H  — DMA A-Bus Address / HDMA Table Address (High)
$00C304 (PRG $004304)  A1B0  — DMA A-Bus Address / HDMA Table Address (Bank)
$00C305 (PRG $004305)  DAS0L  — DMA Size / HDMA Indirect Address (Low)
$00C306 (PRG $004306)  DAS0H  — DMA Size / HDMA Indirect Address (High)
$00C307 (PRG $004307)  DAS0B  — HDMA Indirect Address (Bank)
$00C308 (PRG $004308)  A2A0L  — HDMA Mid Frame Table Address (Low)
$00C309 (PRG $004309)  A2A0H  — HDMA Mid Frame Table Address (High)
$00C30A (PRG $00430A)  NTLR0  — HDMA Line Counter
$00C310 (PRG $004310)  DMAP1  — (H)DMA Control
$00C311 (PRG $004311)  BBAD1  — (H)DMA B-Bus Address
$00C312 (PRG $004312)  A1T1L  — DMA A-Bus Address / HDMA Table Address (Low)
$00C313 (PRG $004313)  A1T1H  — DMA A-Bus Address / HDMA Table Address (High)
$00C314 (PRG $004314)  A1B1  — DMA A-Bus Address / HDMA Table Address (Bank)
$00C315 (PRG $004315)  DAS1L  — DMA Size / HDMA Indirect Address (Low)
$00C316 (PRG $004316)  DAS1H  — DMA Size / HDMA Indirect Address (High)
$00C317 (PRG $004317)  DAS1B  — HDMA Indirect Address (Bank)
$00C318 (PRG $004318)  A2A1L  — HDMA Mid Frame Table Address (Low)
$00C319 (PRG $004319)  A2A1H  — HDMA Mid Frame Table Address (High)
$00C31A (PRG $00431A)  NTLR1  — HDMA Line Counter
$00C320 (PRG $004320)  DMAP2  — (H)DMA Control
$00C321 (PRG $004321)  BBAD2  — (H)DMA B-Bus Address
$00C322 (PRG $004322)  A1T2L  — DMA A-Bus Address / HDMA Table Address (Low)
$00C323 (PRG $004323)  A1T2H  — DMA A-Bus Address / HDMA Table Address (High)
$00C324 (PRG $004324)  A1B2  — DMA A-Bus Address / HDMA Table Address (Bank)
$00C325 (PRG $004325)  DAS2L  — DMA Size / HDMA Indirect Address (Low)
$00C326 (PRG $004326)  DAS2H  — DMA Size / HDMA Indirect Address (High)
$00C327 (PRG $004327)  DAS2B  — HDMA Indirect Address (Bank)
$00C328 (PRG $004328)  A2A2L  — HDMA Mid Frame Table Address (Low)
$00C329 (PRG $004329)  A2A2H  — HDMA Mid Frame Table Address (High)
$00C32A (PRG $00432A)  NTLR2  — HDMA Line Counter
$00C330 (PRG $004330)  DMAP3  — (H)DMA Control
$00C331 (PRG $004331)  BBAD3  — (H)DMA B-Bus Address
$00C332 (PRG $004332)  A1T3L  — DMA A-Bus Address / HDMA Table Address (Low)
$00C333 (PRG $004333)  A1T3H  — DMA A-Bus Address / HDMA Table Address (High)
$00C334 (PRG $004334)  A1B3  — DMA A-Bus Address / HDMA Table Address (Bank)
$00C335 (PRG $004335)  DAS3L  — DMA Size / HDMA Indirect Address (Low)
$00C336 (PRG $004336)  DAS3H  — DMA Size / HDMA Indirect Address (High)
$00C337 (PRG $004337)  DAS3B  — HDMA Indirect Address (Bank)
$00C338 (PRG $004338)  A2A3L  — HDMA Mid Frame Table Address (Low)
$00C339 (PRG $004339)  A2A3H  — HDMA Mid Frame Table Address (High)
$00C33A (PRG $00433A)  NTLR3  — HDMA Line Counter
$00C340 (PRG $004340)  DMAP4  — (H)DMA Control
$00C341 (PRG $004341)  BBAD4  — (H)DMA B-Bus Address
$00C342 (PRG $004342)  A1T4L  — DMA A-Bus Address / HDMA Table Address (Low)
$00C343 (PRG $004343)  A1T4H  — DMA A-Bus Address / HDMA Table Address (High)
$00C344 (PRG $004344)  A1B4  — DMA A-Bus Address / HDMA Table Address (Bank)
$00C345 (PRG $004345)  DAS4L  — DMA Size / HDMA Indirect Address (Low)
$00C346 (PRG $004346)  DAS4H  — DMA Size / HDMA Indirect Address (High)
$00C347 (PRG $004347)  DAS4B  — HDMA Indirect Address (Bank)
$00C348 (PRG $004348)  A2A4L  — HDMA Mid Frame Table Address (Low)
$00C349 (PRG $004349)  A2A4H  — HDMA Mid Frame Table Address (High)
$00C34A (PRG $00434A)  NTLR4  — HDMA Line Counter
$00C350 (PRG $004350)  DMAP5  — (H)DMA Control
$00C351 (PRG $004351)  BBAD5  — (H)DMA B-Bus Address
$00C352 (PRG $004352)  A1T5L  — DMA A-Bus Address / HDMA Table Address (Low)
$00C353 (PRG $004353)  A1T5H  — DMA A-Bus Address / HDMA Table Address (High)
$00C354 (PRG $004354)  A1B5  — DMA A-Bus Address / HDMA Table Address (Bank)
$00C355 (PRG $004355)  DAS5L  — DMA Size / HDMA Indirect Address (Low)
$00C356 (PRG $004356)  DAS5H  — DMA Size / HDMA Indirect Address (High)
$00C357 (PRG $004357)  DAS5B  — HDMA Indirect Address (Bank)
$00C358 (PRG $004358)  A2A5L  — HDMA Mid Frame Table Address (Low)
$00C359 (PRG $004359)  A2A5H  — HDMA Mid Frame Table Address (High)
$00C35A (PRG $00435A)  NTLR5  — HDMA Line Counter
$00C360 (PRG $004360)  DMAP6  — (H)DMA Control
$00C361 (PRG $004361)  BBAD6  — (H)DMA B-Bus Address
$00C362 (PRG $004362)  A1T6L  — DMA A-Bus Address / HDMA Table Address (Low)
$00C363 (PRG $004363)  A1T6H  — DMA A-Bus Address / HDMA Table Address (High)
$00C364 (PRG $004364)  A1B6  — DMA A-Bus Address / HDMA Table Address (Bank)
$00C365 (PRG $004365)  DAS6L  — DMA Size / HDMA Indirect Address (Low)
$00C366 (PRG $004366)  DAS6H  — DMA Size / HDMA Indirect Address (High)
$00C367 (PRG $004367)  DAS6B  — HDMA Indirect Address (Bank)
$00C368 (PRG $004368)  A2A6L  — HDMA Mid Frame Table Address (Low)
$00C369 (PRG $004369)  A2A6H  — HDMA Mid Frame Table Address (High)
$00C36A (PRG $00436A)  NTLR6  — HDMA Line Counter
$00C370 (PRG $004370)  DMAP7  — (H)DMA Control
$00C371 (PRG $004371)  BBAD7  — (H)DMA B-Bus Address
$00C372 (PRG $004372)  A1T7L  — DMA A-Bus Address / HDMA Table Address (Low)
$00C373 (PRG $004373)  A1T7H  — DMA A-Bus Address / HDMA Table Address (High)
$00C374 (PRG $004374)  A1B7  — DMA A-Bus Address / HDMA Table Address (Bank)
$00C375 (PRG $004375)  DAS7L  — DMA Size / HDMA Indirect Address (Low)
$00C376 (PRG $004376)  DAS7H  — DMA Size / HDMA Indirect Address (High)
$00C377 (PRG $004377)  DAS7B  — HDMA Indirect Address (Bank)
$00C378 (PRG $004378)  A2A7L  — HDMA Mid Frame Table Address (Low)
$00C379 (PRG $004379)  A2A7H  — HDMA Mid Frame Table Address (High)
$00C37A (PRG $00437A)  NTLR7  — HDMA Line Counter
$00C4DA (PRG $0044DA)  waitForVBlank2  — Alternative V-blank wait routine. Entry: polls $4212 with timeout. Returns carry set if timeout.
$2BDD00 (PRG $15DD00)  externalLibInit  — External library initialization. Entry: sets up library routines.
$2BE039 (PRG $15E039)  externalUtilityFunc1  — External utility function 1. Entry: general-purpose operations.
$2BE044 (PRG $15E044)  externalUtilityFunc2  — External utility function 2. Entry: additional utility operations.
$2BE063 (PRG $15E063)  externalUtilityFunc3  — External utility function 3. Entry: specialized utility operations.
$2BE24B (PRG $15E24B)  externalFinalFunc  — External final library function. Entry: cleanup or final operations.

## Menu (49 labels)

$00967F (PRG $00167F)  handleItemUse  — Handles item usage in menu or battle. Entry: A=item ID, X=target. Processes item effects, updates inventory.
$0097E9 (PRG $0017E9)  updateMenuCursor  — Updates menu cursor position and animation. Entry: reads controller input, updates cursor sprite OAM.
$00A1A9 (PRG $0021A9)  equipItem  — Equips item to character. Entry: A=character ID, X=item ID. Updates equipment slots, applies stat bonuses.
$00A239 (PRG $002239)  unequipItem  — Unequips item from character. Entry: A=character ID, X=equipment slot. Removes item, recalculates stats.
$00A2AE (PRG $0022AE)  buyItemShop  — Handles item purchase in shop. Entry: A=item ID, X=quantity. Deducts gold, adds to inventory.
$00A2FF (PRG $0022FF)  sellItemShop  — Handles item sale in shop. Entry: A=item ID, X=quantity. Adds gold, removes from inventory.
$00AC99 (PRG $002C99)  handleMenuNavigation  — Handles menu navigation logic. Entry: reads controller, updates cursor, processes selections. Called for all menus.
$00B5D7 (PRG $0035D7)  drawWindow  — Draws window frame for menus/dialogue. Entry: $00/$02=position, $04/$06=size. Renders border tiles.
$018D8C (PRG $008D8C)  drawPauseMenu  — Draws pause menu overlay with options. Entry: called when game paused.
$018E3F (PRG $008E3F)  handlePauseMenu  — Handles pause menu navigation and selections. Entry: processes input in pause menu.
$019631 (PRG $009631)  handleBattleMenu  — Handles battle command menu - attack, magic, item, defend. Entry: called for player turn.
$019AFA (PRG $009AFA)  handleItemBattle  — Handles item use in battle. Entry: A=item ID, X=user, Y=target. Applies item effect.
$019DD2 (PRG $009DD2)  handleShopMenu  — Handles shop menu - buy/sell items, view inventory. Entry: A=shop type (0=item, 1=weapon, 2=armor).
$019ED1 (PRG $009ED1)  drawShopStock  — Draws shop stock list with prices. Entry: reads shop inventory from ROM table.
$019F5D (PRG $009F5D)  handleInn  — Handles inn stay - restores HP/MP for gold. Entry: A=inn price. Deducts gold, heals party.
$01A3EA (PRG $00A3EA)  handleConfigMenu  — Handles configuration menu - sound, controls, display options. Entry: called from main menu.
$01A609 (PRG $00A609)  initScrollCounter  — Sets $0A48=$0A4A+$10, calls callCutsceneHandler(#$01), stores #$54→$06F3 tile attr, #$00A5→$66 cursor offset. Scroll/timer init.
$01A62A (PRG $00A62A)  checkScrollLimit  — Compares $0A4A vs $0A48; if less, INC $0944. Stores back, checks $0944=0. Scroll limit counter.
$01A70D (PRG $00A70D)  lookupTilemapTile  — Reads tile from $7F:9000 tilemap at X offset, extracts tile# (AND $01FF), returns VRAM byte offset in Y (*4). handleStatusScreen sub at $A729 computes tilemap offset from column.
$01A729 (PRG $00A729)  handleStatusScreen  — Handles status screen navigation - switch characters, view equipment.
$01A73D (PRG $00A73D)  drawEquipmentScreen  — Draws equipment screen with slots. Entry: A=character ID. Shows equipped items, bonuses.
$01A7B1 (PRG $00A7B1)  handleEquipment  — Handles equipment management - equip/unequip, compare stats.
$01A7E2 (PRG $00A7E2)  drawMagicScreen  — Draws magic/skills screen. Entry: A=character ID. Shows learned abilities, MP costs.
$01A836 (PRG $00A836)  handleMagicScreen  — Handles magic screen navigation - select ability, view description.
$01A83B (PRG $00A83B)  drawFormationScreen  — Draws party formation screen. Entry: shows character positions, allows rearrangement.
$01A94D (PRG $00A94D)  handleFormation  — Handles formation editing - move characters, save layout.
$01A9A3 (PRG $00A9A3)  drawItemScreen  — Draws item inventory screen. Entry: shows all items with quantities.
$01AA22 (PRG $00AA22)  handleItemScreen  — Handles item screen - use, arrange, discard items.
$01AA3C (PRG $00AA3C)  checkEntityFlag  — Entry: $00=1→INC $02; else calls hardwareMultiplyRng(#$3F), INC→$02. Entity flag check/update.
$01AA82 (PRG $00AA82)  initEntityBatch  — Zeros $0E/$0C. Loops 16×: calls updateEntity($0E, Y=$0E00), reads $0E00 mask $FF, checks $FF sentinel, loads $0E38→$0E08. Calls setupEntityParameter per entry.
$01AABE (PRG $00AABE)  searchDataTable  — Searches $7FCE00 table (up to $24 entries, SEP #$20 byte compare) for matching A. Returns X=index if found, $FFFF if not.
$01AAE2 (PRG $00AAE2)  handleMapScreen  — Handles map screen - zoom, pan, view different levels.
$01AB6E (PRG $00AB6E)  addToDataTable  — CPX #$11 overflow check. Calls searchDataTable; if $FFFF, stores A→$7FCE00,X and A|$80→$7FCE12,X, INX. Table insert helper.
$01ADEB (PRG $00ADEB)  processEntityAction  — JSR initBattleState, reads $1400,X AND #$FF, if nonzero reads $1404,X→$00, calls handleConfigMenu(X=$08). Entity action dispatcher.
$01AE70 (PRG $00AE70)  drawSystemMenu  — Draws system menu (save, load, config, quit). Entry: called from pause menu.
$01AF16 (PRG $00AF16)  handleSystemMenu  — Handles system menu selections. Entry: processes save/load/config options.
$01AF64 (PRG $00AF64)  drawLoadScreen  — Draws load game screen with save slots. Entry: shows save file info (time, party, location).
$01B22B (PRG $00B22B)  drawSaveScreen  — Draws save game screen. Entry: shows save slots, allows overwrite confirmation.
$01B7EE (PRG $00B7EE)  confirmAction  — Displays confirmation dialog (Yes/No). Entry: A=prompt text ID. Returns carry if Yes selected.
$01B90D (PRG $00B90D)  drawStatComparison  — Draws stat comparison (old vs new) for equipment. Entry: shows changes with +/- indicators.
$01BD81 (PRG $00BD81)  drawScrollBar  — Draws scroll bar for list menus. Entry: A=position, X=length, Y=total items.
$01BDD7 (PRG $00BDD7)  handleListScrolling  — Handles list scrolling logic. Entry: processes up/down input, updates scroll position.
$01C0FE (PRG $00C0FE)  drawIcon  — Draws icon sprite (item, spell, status). Entry: A=icon ID, $00/$02=position.
$01C2D5 (PRG $00C2D5)  drawPartyFace  — Draws character face portrait. Entry: A=character ID, $00/$02=position.
$01C2DF (PRG $00C2DF)  drawCharacterSpriteMenu  — Draws character sprite in menu (animated). Entry: A=character ID, $00/$02=position.
$01C594 (PRG $00C594)  drawWindowShadow  — Draws drop shadow for window. Entry: $00/$02=window position, $04/$06=size.
$01C5A9 (PRG $00C5A9)  drawBorder  — Draws decorative border around element. Entry: A=border style, $00/$02=position.
$01D644 (PRG $00D644)  drawSaveFileInfo  — Draws save file information (time, location, party). Entry: A=slot number.
$01DA2F (PRG $00DA2F)  clearBuffer7FB000  — Zero-fills $7F:B000, 2KB. Entry: none.

## GameState (27 labels)

$00885C (PRG $00085C)  dispatchGameMode  — Game mode dispatcher - jumps to different game mode handlers based on A value (0-5). Entry: A=game mode index. Uses jump table at $8869.
$00A04B (PRG $00204B)  checkPartyAlive  — Checks if any party members are still alive. Entry: scans party data at $1400. Returns carry clear if all dead.
$00A3BE (PRG $0023BE)  initNewGame  — Initializes new game state. Entry: sets up party, inventory, story flags to starting values.
$00AD3B (PRG $002D3B)  calculateGameProgress  — Calculates game progress percentage. Entry: reads $7EEA82, $0E06, $0E86, calculates percentage (0-99).
$00AF01 (PRG $002F01)  updateFlagTable  — Updates flag table at $7EEA00. Entry: A=flag ID, Y=value, sets flag with high bit ($80).
$00B201 (PRG $003201)  checkEventFlag  — Checks if story event flag is set. Entry: A=flag ID. Returns carry set if flag is true.
$00B248 (PRG $003248)  setEventFlag  — Sets story event flag. Entry: A=flag ID. Marks flag as completed in save data.
$018542 (PRG $008542)  titleScreenLoop  — Title screen main loop - handles menu, demo playback, start game transition.
$018859 (PRG $008859)  initTitleScreen  — Initializes title screen - sets up animation, music, and input handlers. Entry: called when entering title screen.
$018D3F (PRG $008D3F)  readUnitBattleStats  — Reads unit data at $0E08+Y, $0E12+Y, $0E72+Y. Extracts unit stats for battle calc. NOT pauseGame.
$018E84 (PRG $008E84)  copyBufferToWram  — Copies data from $7F:6000 to $7E:9076 via [$12]. Falls through to next function. NOT resumeGame.
$018E91 (PRG $008E91)  copyBufferLoop  — Data copy loop: reads $7F:6000+X, stores via [$12]+Y. NOT gameOverScreen.
$01956A (PRG $00956A)  checkBattleCondition  — Checks battle win/lose conditions. Entry: evaluates party/enemy status. Returns A=result (0=continue, 1=win, 2=lose).
$019BB2 (PRG $009BB2)  fleeBattle  — Attempts to flee from battle. Entry: calculates success based on agility. Returns carry if successful.
$019C16 (PRG $009C16)  setupBattleFormation  — Sets up battle formation positions. Entry: A=formation ID. Positions party and enemies.
$019CD8 (PRG $009CD8)  initBattleState  — Initializes battle state variables. Entry: sets up turn order, AI states, battle flags.
$019CE6 (PRG $009CE6)  cleanupBattle  — Cleans up battle state after battle ends. Entry: clears battle-specific RAM, restores overworld.
$01A233 (PRG $00A233)  handleWorldMap  — Handles world map navigation - movement between locations. Entry: processes map input.
$01A32B (PRG $00A32B)  subtractClamped  — CMP $00, if A>=$00: A-=$00, RTS. Else: TAY. Simple clamped subtraction. NOT checkStoryProgress.
$01A33C (PRG $00A33C)  loadMapEventParams  — Reads $7FC011/$7FC012 map params, calls playEventCutscene ($A354). NOT advanceStory.
$01A386 (PRG $00A386)  checkEntityScreenBounds  — Checks if entity at $0902/$0904 is within visible screen rect ($4B-$A2 X, $32-$73 Y). Calls playEventCutscene ($A354) then transitionFromWorldMap ($A25D) with 1=visible or 0=offscreen.
$01A49E (PRG $00A49E)  clampSpriteY  — Clamps sprite Y position: $F4 - $06, checks sign/bounds, writes to $06F0-$06FE. JSL updateDepthEffect(#$00).
$01A4FB (PRG $00A4FB)  initDisplayMode  — SEI, sets $6A=1, programs OBSEL ($2101), CGWSEL ($2130), window regs ($2123-$212F), H-IRQ ($4207/$4209), enables IRQ ($4200). Full display mode init.
$01A5B6 (PRG $00A5B6)  initScenarioDisplay  — Calls callCutsceneHandler(#$00), textMetaLookup(#$0A), commitDmaFlag. Reads $7EEA82+$0B00→textMetaLookup. Scenario intro display.
$01AB8F (PRG $00AB8F)  checkGameProgress  — Checks game progress flags for special events. Entry: checks $0A08, $0E28, $0EA8, $0E4E, $0ECE for progression conditions.
$01CF40 (PRG $00CF40)  setupGameSequence  — Sets up game sequence based on $0E6A. Entry: sets $096E, calls sub_00D0B3, runs sequence with $0A00 timing.
$01D135 (PRG $00D135)  runGameModeSequence  — Runs game mode sequence. Entry: calls dispatchGameMode mode 8, sets up graphics, calls animation functions.

## Save (20 labels)

$00A398 (PRG $002398)  lookupTilemapEntry  — JSR calcTilemapIndex, reads $7F9000,X, masks AND #$01FF, ASL×2 → Y. Returns index in Y. RTS.
$00A3AA (PRG $0023AA)  calcTilemapIndex  — Computes ($02 & $1F) << 7 + $00*2 → X. Pure arithmetic tilemap offset calculator. RTS.
$01A137 (PRG $00A137)  handleSavePoint  — Handles save point interaction - save game, restore HP/MP. Entry: displays save menu.
$01A410 (PRG $00A410)  updateConfigSettings  — Updates configuration settings in SRAM. Entry: writes options to save data.
$01AFD1 (PRG $00AFD1)  handleLoadScreen  — Handles load screen - select slot, confirm load. Entry: loads save data from SRAM.
$01B565 (PRG $00B565)  handleSaveScreen  — Handles save screen - select slot, confirm save. Entry: writes game state to SRAM.
$01CBD7 (PRG $00CBD7)  configMapMonitor  — Configures map monitor mode. Entry: A=0→Y=#$20+$0A1E=$3900; A=$80→same. INC $0970, test bit 4 for Y=#$20 override, calls monitorMap. Clears $0A1E. RTS.
$01CEB6 (PRG $00CEB6)  loadRomHeaderToWram  — Copies 64 bytes from ROM $00:8000 to WRAM $7E:9480. Then reads $0E08/$0E38 and $0E88/$0EB8 to call iterateSlotEntries twice with different base addresses. RTS.
$01CF03 (PRG $00CF03)  iterateSlotEntries  — Entry: $00=count, $02=param. If $00=0 returns. ASL×4→Y, divides $02/$00 via divideUnsigned16, clamps 1-$E→$04 loop count. Loops: increments word at [$12] by 2, advances $12 by $16 stride. RTS.
$01CF36 (PRG $00CF36)  clearAndDispatchText  — STZ $0A0C, calls textMetaLookup ($EE4A) with A=#$28. Short wrapper. RTS.
$01D231 (PRG $00D231)  initBattleSequence  — Stores A→$0992/$0E58, indexes ROM table at $01D22D, dispatches game mode 9, calls calculateSlope with X=$42/Y=$80. Sets up battle/entity sequence.
$01D462 (PRG $00D462)  processBattleSubroutine  — Called within initBattleSequence; part of battle/entity processing chain. (Exact role TBD — needs trace.)
$01D51B (PRG $00D51B)  clearEntitySubtable  — Zeros a section of entity table. Called with X=offset, Y=count within battle sequence. (Exact role TBD.)
$01D929 (PRG $00D929)  countActiveEntities  — Calls callCutsceneHandler(#$07). Zeros $097E, loops $1400 table in $20-byte stride counting non-zero entries→$097E. Then computes loop from $0978+4, calls debugMenu + other routines.
$01D9BC (PRG $00D9BC)  setupEntityTile  — Stores A→$0E03. If A=$FFFF: INC, JSR drawScanlineEffect. Else JSR lookupTileFromTable. PLA, ADC #$10→Y. Sets up tile data for entity.
$01D9D5 (PRG $00D9D5)  lookupTileFromTable  — PHY, reads $0E03 AND #$3F, looks up ROM table at $D138,X, masks AND #$03, ASL, ORA $03. Calls drawMapScreen for additional data. PLY. Returns combined tile attribute.
$01D9F8 (PRG $00D9F8)  getEntityBaseAddr  — Reads $0E00 AND #$FF; if 0 checks $0E08, returns #$3FAC or #$3FA4. Else reads $0E08, returns #$3FA4 or #$3FAC. Base address selector.
$01DA1D (PRG $00DA1D)  sceneTextDisplay  — Reads $0E37 bits 4-5, adds $24, calls textMetaLookup ($EE4A). Entry: $0E37 flags set.
$01DA43 (PRG $00DA43)  entityScreenSetup  — Sets $78=$7000 scroll, $57=$FE flags, calls $B7EE. Entry: none.
$01DA56 (PRG $00DA56)  sceneEntityInit  — Reads $7E:EA82 scenario#; sets $7F:C005 graphics, calls entityStateConfig. Entry: scenario state.

## Memory (20 labels)

$0080D8 (PRG $0000D8)  findDataEntry  — Searches data table for matching entry. Entry: $00=search value, $22/$24=data table pointer. Returns A=1 if found (sets $096C=index, $22=entry pointer, $096E=entry data), A=0 if not found.
$008122 (PRG $000122)  setupDataStructure  — Sets up data structure from loaded game data. Uses $0986/$0988 as base pointers, calls sub_00E155 for processing. Entry: expects data pointers set. Returns via RTL.
$00BBA7 (PRG $003BA7)  ffReadInlineWord  — Reads 2 bytes from text stream [$14]+Y into $00/$01. NOT copyMemory (no MVN instruction).
$00BCD6 (PRG $003CD6)  renderNumber5Digit  — Renders number as up to 5 decimal digits. Calls renderNumberToBuffer with divisors 10000, 1000, 100, 10, 1. NOT clearMemory.
$00BCFF (PRG $003CFF)  renderNumber3Digit  — Alternate entry for number rendering starting at hundreds place. NOT setMemory.
$00BD06 (PRG $003D06)  renderNumber2Digit  — Alternate entry for number rendering starting at tens place. NOT findMemory.
$00BD31 (PRG $003D31)  renderNumberToBuffer  — Converts number in A to decimal digit string in $0400 buffer. Divides by [$04] via repeated subtraction (numRender_DivLoop), suppresses leading zeros ($00 flag), adds #$30 for ASCII. Entry: A=value, $04=divisor, X=buffer offset.
$00BE22 (PRG $003E22)  clearTextTileLine  — Clears a text rendering line in $7E:9000 tile buffer. BRK at entry (may be data/padding — real entry $BE24). Calls $C240 for buffer offset, fills $80 words with zero.
$00C620 (PRG $004620)  setupHdmaScroll  — HDMA scroll setup: stores params to $04/$06, checks sign of $00. NOT setupWRAM (no $2180 access).
$00C64D (PRG $00464D)  setupHdmaParams  — Sets up HDMA/DMA parameters. Stores to $04/$05, loads constants. NOT copyToWRAM.
$00C6A7 (PRG $0046A7)  lookupMapTileType  — Reads map tile from $7F:E800+X, extracts type (AND #$001F), shifts left 5. NOT readFromWRAM.
$00D7BE (PRG $0057BE)  buildDataStructure  — Builds data structure from indirect pointer. Entry: $54/$6D base, reads from [$3A], writes to $7EA001.
$01D0B3 (PRG $00D0B3)  copyDataTable  — Copies data table from ROM to RAM. Entry: uses $0E06 count, copies from $01D113 to $1000, processes $0BE4CF table.
(Moved to SPC700 section — all bank $2B "external*" functions are SPC700 audio transfer routines)

## Math (2 labels)

(Entries $00BB65 multiply8x8, $00BB71 divide16x8 were WRONG — duplicates of ffReadInlineByte/ffReadInlinePtr in Text section)
(Entries $00BCD6 clearMemory, $00BCFF setMemory, $00BD06 findMemory were WRONG — moved to Text as renderNumber5Digit/3Digit/2Digit)
(Entries $00C1B4-$00C2E1 calculateSine/Cosine/Distance/etc were ALL WRONG — all are text engine helpers, see Text section)
$01BB5A (PRG $00BB5A)  clampValue  — Clamps value: checks sign (AND #$8000), subtracts $00 step, bounds to $FFF0 min. Entry: A=sign flag, Y=value, $00=step.
$01BD98 (PRG $00BD98)  calcBattleEffectDamage  — Calculates (random(5)+24) * $0E70 via hardwareMultiplyRng + hardware multiply $4202/$4203.
(Moved to SPC700 section — spcSetSourceAddr and spcSetDestAddr)

## Animation (13 labels)

$009CAE (PRG $001CAE)  handleBattleAnimation  — Handles battle animation selection. Entry: A=animation type, Y=animation data. Selects between different animation sets.
$00A6DC (PRG $0026DC)  animateCharacter  — Handles character walking/running animation. Entry: A=character ID. Updates sprite frames based on movement speed.
$018875 (PRG $008875)  animateTitle  — Animates title screen elements (sparkles, pulsing). Entry: called each frame.
$018F12 (PRG $008F12)  drawBattleAnimation  — Draws special battle animation frames. Entry: A=animation ID, renders to OAM.
$019031 (PRG $009031)  updateBattleAnimation  — Updates battle animation progress. Entry: advances animation frames, timing.
$01916B (PRG $00916B)  updateSpellEffect  — Updates spell effect animation. Entry: moves particles, updates graphics.
$019170 (PRG $009170)  drawWeaponSwing  — Draws weapon swing animation. Entry: A=weapon type, renders arc, trail.
$01918B (PRG $00918B)  updateWeaponSwing  — Updates weapon swing animation. Entry: advances swing frame, hit detection.
$01920C (PRG $00920C)  updateDamageSpark  — Updates damage spark animation. Entry: moves sparks, fades out.
$019964 (PRG $009964)  animateBattleAttack  — Animates physical attack in battle - weapon swing, hit spark. Entry: A=attacker, X=defender.
$01998C (PRG $00998C)  animateSpellCast  — Animates spell casting - glow effects, projectile. Entry: A=spell ID, X=caster, Y=target.
$01C13E (PRG $00C13E)  updateEffectAnimation  — Updates effect animation frame. Entry: processes $0E07 counter, updates animation based on $0E58 timer.
$01C4E5 (PRG $00C4E5)  animateMenuSprite  — Animates menu sprite (idle animation). Entry: updates sprite frame based on timer.

## Init (9 labels)

$008D78 (PRG $000D78)  fillTileBuffer9000  — Fills $7E:9000 tile buffer (STA $7E9000,X / INX*2 / DEY / BNE loop). NOT setupPPURegisters.
$00A5B4 (PRG $0025B4)  setupGraphicsMode  — Sets up graphics mode. JSL setTextScrollParams, sets BG4 tilemap addr $2108=#$70, $0E20=$01, $0EA0=$01.
$00E24A (PRG $00624A)  debugFlagInit  — STZ/INC $0A87 - debug mode patch site
$018000 (PRG $008000)  systemInit  — System initialization - clears WRAM, sets up hardware, calls external init routines. Entry: called at reset.
$018455 (PRG $008455)  initGraphics  — Initializes graphics system - sets up PPU registers, clears VRAM, loads font.
$018479 (PRG $008479)  initSceneAfterLoad  — Calls sceneEntityInit, evtScrollInitFull, scene setup. NOT initSound (no SPC interaction).
$0184F3 (PRG $0084F3)  initGameState  — Initializes game state variables - party, inventory, story flags to default.
$018515 (PRG $008515)  initControllers  — Initializes controller input system - clears input buffers, enables auto-read.
$01853D (PRG $00853D)  enableDisplay  — Enables screen display after init. Entry: sets $2100 to $0F (full brightness).

## HUD (8 labels)

$009BC1 (PRG $001BC1)  updateHPBar  — Updates HP bar display for character. Entry: A=character ID, X=current HP, Y=max HP. Draws bar in HUD.
$00A5CD (PRG $0025CD)  updateMinimap  — Updates minimap display in corner. Entry: reads player position, draws current area on minimap.
$00D7FB (PRG $0057FB)  initHdmaFromParam  — AND #$00FF, falls into buildHdmaScrollTable. HDMA setup wrapper. NOT drawHealthBars.
$0198C9 (PRG $0098C9)  drawBattleHUD  — Draws battle HUD - HP/MP bars, command list, turn order. Entry: updates each turn.
$01C11D (PRG $00C11D)  drawProgressBar  — Draws progress bar (HP, MP, XP). Entry: A=current, X=max, $00/$02=position, Y=color.
$01C201 (PRG $00C201)  drawClock  — Draws game time clock display. Entry: reads playtime counter, formats as HH:MM.
$01C234 (PRG $00C234)  calcRandomBattleParam  — Calls hardwareMultiplyRng(#5) and hardwareMultiplyRng(#6), stores results to $2A. Random battle calc. NOT drawGoldAmount.
$01D905 (PRG $00D905)  drawPlayTime  — Draws play time display. Entry: formats time string, draws to screen.

## Dialogue (7 labels)

$009A1E (PRG $001A1E)  drawDialogBox  — Draws text dialog box on screen. Entry: $12/$14=text pointer, $00/$02=screen position. Renders text with window effect.
$00A5E6 (PRG $0025E6)  handleNPCDialogue  — Handles NPC dialogue interaction. Entry: A=NPC ID. Loads dialogue text, displays choices if any.
$01A5D3 (PRG $00A5D3)  checkScrollBoundaryY  — Checks $0904-$62 vs #$0082 scroll limit. Falls to initScrollCounter if past boundary. NOT drawTutorial.
$01A5E0 (PRG $00A5E0)  advanceScrollPosition  — Increments $62 scroll, compares to $0A4A map limit, increments $0944 counter. NOT handleTutorial.
$01B80D (PRG $00B80D)  drawMessageBox  — Draws message box for text display. Entry: $00/$02=position, $04/$06=size.
$01B822 (PRG $00B822)  printText  — Prints text to message box with per-character timing (dialog boxes). Entry: $12/$14=text pointer. Handles line breaks, character-by-character display speed, calls waitTextAdvance for button press continuation. Part of per-character renderer for cinematic dialog. Used for story dialog boxes and NPC conversations.
$01B835 (PRG $00B835)  waitTextAdvance  — Waits for button press to advance text. Entry: displays 'more' prompt, waits for input. Used after printText for dialog boxes where player controls text flow.

## Script (7 labels)

$00B26B (PRG $00326B)  handleCutscene  — Handles cutscene playback. Entry: A=cutscene ID. Plays script, moves characters, displays dialogue.
$00DDE8 (PRG $005DE8)  executeMapScript  — Executes map script when trigger activated. Entry: A=script ID. Runs script commands.
$01A354 (PRG $00A354)  playEventCutscene  — Plays story event cutscene. Entry: A=cutscene ID. Runs script with dialogue, character movement.
$01D3F9 (PRG $00D3F9)  parseScriptData  — Parses script/data from ROM table. Entry: $0992=type, reads from $AF29/$AF4B table, processes with $7EEA8E.
$01F759 (PRG $00F759)  eventScriptDispatcher  — Reads bytecodes from [$85], dispatches via jump table
$01F7B9 (PRG $00F7B9)  eventDispatchTable  — 64 entries, 4-byte stride jump table for event commands
$0A8000 (PRG $050000)  scriptMetaTable  — 4 entries linking script engine to text/bytecode tables

## VRAM (6 labels)

$008919 (PRG $000919)  calculateTileOffset  — Calculates tile offset for graphics data. Entry: X=index. Reads from $7FCE00 table, multiplies by $A0, adds base offset $8000. Returns Y=calculated offset.
$008FFE (PRG $000FFE)  clearVRAM  — Clears VRAM by filling with zeros. Uses DMA channel 0. Entry: none. Clears entire VRAM space.
$00904E (PRG $00104E)  loadTileData  — Loads tile graphics data to VRAM. Entry: $12/$14=source pointer, $2116=VRAM destination, $4305=length. Uses DMA.
$00945B (PRG $00145B)  decompressGraphics  — Decompresses graphics data from ROM to RAM. Entry: $12/$14=source pointer, $16/$18=dest pointer, $02=compression type. Uses RLE-like decompression.
$00DDB2 (PRG $005DB2)  setupVramBG3Write  — Write $2116=#$7800 (VRAM addr), $2115=#$80 (incr by 1 on high-byte write). BG3 tilemap access. (was "checkMapTrigger")
$019C5A (PRG $009C5A)  loadBattleBackground  — Loads battle background graphics. Entry: A=background ID. Loads tiles and palette to VRAM.
(REMOVED: $00C6D6 "setupVRAM" was WRONG — see TileData section as processScrollEntries)

## DMA (5 labels)

$00916C (PRG $00116C)  setupDMAChannel  — Configures DMA channel for transfer. Entry: A=channel (0-7), X=DMAP/BBAD value, Y=A1T value. Sets up $43x0-$43x3.
$009183 (PRG $001183)  startDMA  — Starts DMA transfer on specified channels. Entry: A=channel mask (bits 0-7). Writes to $420B.
$0091AA (PRG $0011AA)  setupHDMA  — Sets up HDMA channel for raster effects. Entry: A=channel, X=table pointer, Y=indirect pointer. Configures $43x0-$43x7.
$00D4A3 (PRG $0054A3)  vblankDMAHandler  — V-Blank DMA handler for tilemap upload. Checks $05F5 flag, if set DMAs from $0600/$0680 buffers to VRAM using addresses at $05F6/$05F8. Also handles palette DMA ($5E flag) and other graphics updates.
$00DB69 (PRG $005B69)  setupVramDMATransfer  — Check $05F5 flag, configure $2115/$4310/$4320 for DMA channels 1+2. VRAM upload setup. (was "handleMapTransition" in Transition section)
(REMOVED: $00C454 "setupHDMATable" was WRONG — see TileData section as setupTileDataPointer)
(REMOVED: $00C469 "updateHDMA" was WRONG — see TileData section as setupTileDataFromROM)

## Input (4 labels)

$00B5B8 (PRG $0035B8)  waitForButton  — Waits for button press before continuing. Entry: displays 'press button' prompt, loops until input.
$01888F (PRG $00888F)  handleTitleInput  — Handles input on title screen - start button, demo mode.
$018BB1 (PRG $008BB1)  handleGameInput  — Handles gameplay input - movement, menu, actions. Updates player controller state.
$01A37C (PRG $00A37C)  skipCutscene  — Allows skipping cutscene with button press. Entry: checks for start button during cutscene.
(REMOVED: $00C490 "readJoypad" was WRONG — see TileData section as readTileDataWord)
(REMOVED: $00C4B1 "readJoypadEdge" was WRONG — see TileData section as readTileDataByte)

## Interrupt (1 label)

$008B17 (PRG $000B17)  handleVBlank  — V-Blank interrupt handler. Updates scroll registers, transfers OAM, handles DMA transfers. Entry: called from NMI.
(REMOVED: $00C530 "setupIRQ" was WRONG — see TileData section as copyToTileBuffer)
(REMOVED: $00C570 "acknowledgeIRQ" was WRONG — see TileData section as clearTileBuffer)
(REMOVED: $00C585 "setupNMI" was WRONG — see TileData section as readIndexedTableEntry)
(REMOVED: $00C5A7 "enableInterrupts" was WRONG — see TileData section as unpackTileProperties)
(REMOVED: $00C600 "disableInterrupts" was WRONG — see TileData section as processScrollLoop)

## TileData (10 labels — NEW: was spread across wrong sections)

$00C454 (PRG $004454)  setupTileDataPointer  — If $0A3A bit 7 set, load [$12/$14]=$7E:2000; else fall through to setupTileDataFromROM.
$00C469 (PRG $004469)  setupTileDataFromROM  — Load [$12/$14]=$24:8000, adjust bank by ($0A37 AND 7), call readIndexedTableEntry for $0A36 index.
$00C490 (PRG $004490)  readTileDataWord  — Load [$12/$14]=$24:8000+, read word at ($0A36 AND $FF)*4 index from tileset table.
$00C4B1 (PRG $0044B1)  readTileDataByte  — Call setupTileDataPointer, save [$12], add 4, read byte from tileset entry.
$00C530 (PRG $004530)  copyToTileBuffer  — Chunked copy [$12] → $7F:B000, 2048 bytes/chunk, VBlank sync between chunks. RTL.
$00C570 (PRG $004570)  clearTileBuffer  — Zero-fill $7F:B000, 2048 bytes (0x400 words). RTS.
$00C585 (PRG $004585)  readIndexedTableEntry  — Read 4-byte record at A*4 from [$12] table, advance [$12/$14] pointer. RTS.
$00C5A7 (PRG $0045A7)  unpackTileProperties  — Extract packed 5-bit fields from [$12] data → $7F:E800 entries (stride 8). Calls setupHdmaScroll.
$00C600 (PRG $004600)  processScrollLoop  — Save $00/$02 → $22/$24, iterate calling processScrollEntries ($C6D6).
$00C6D6 (PRG $0046D6)  processScrollEntries  — Call setupHdmaScroll, loop: call interpolateScrollValue ($C70E) 3x per entry, stride 8+6. Returns $096E.
$00C70E (PRG $00470E)  interpolateScrollValue  — Step $7F:E800,X toward $7F:E804,X by ±1 per call. 8-bit comparison with INC/DEC.

## Timer (6 labels)

$00954E (PRG $00154E)  incrementCounter  — Increments a counter in RAM. Entry: A=counter value. Stores incremented value at $81.
$009E3A (PRG $001E3A)  updateBattleTimer  — Updates battle turn timer. Entry: reads timer value, decrements, checks for turn end. Returns carry set if turn ended.
$00C147 (PRG $004147)  incrementCounter3  — Increments counter at $81. Entry: A=value. Similar to incrementCounter but with different entry.
$00C14A (PRG $00414A)  incrementCounter8  — Increments 8-bit counter at $81. Entry: A=value (8-bit).
$01D745 (PRG $00D745)  calculatePlayTime  — Calculates play time from frame counter. Entry: converts frames to hours:minutes.
$01D77D (PRG $00D77D)  updatePlayTime  — Updates play time counter. Entry: increments frame counter, handles overflow.

## Physics (5 labels)

(REMOVED: $0095AF "calculateBattleDamage" — no function at this address; falls in data region before awardBattleRewards at $8195DC)
$009F0B (PRG $001F0B)  markCellsInRange  — Marks cells within Manhattan distance range on battle grid. Iterates $7F:0000 table (stride 6), computes |$02-$06|+|$00-$04|, sets bit #$20 in $7F:0001+X if within [$08,$0A] range. Grid size from $7FC000/$7FC001. Entry: $00/$02=center, $08/$0A=min/max range.
$00AF6A (PRG $002F6A)  calculateSpellCost  — Calculates MP cost for spell. Entry: A=spell ID. Returns A=MP cost based on spell level and character stats.
$00D0FC (PRG $0050FC)  handleEntityDamage  — Handles damage between entities. Entry: A=attacker ID, X=defender ID. Applies damage, knockback.
$01B313 (PRG $00B313)  calculatePositionOffset  — Calculates position offset for entity. Entry: A=type, X=base, Y=offset. Uses $0936, $0958 for calculations.

## Transition (4 labels)

$019CF3 (PRG $009CF3)  transitionToBattle  — UNVERIFIED. PHP, A*16→X index, pushes registers. Needs deeper verification.
$019D33 (PRG $009D33)  transitionFromBattle  — UNVERIFIED. Transitions from battle back to overworld.
$01A258 (PRG $00A258)  transitionToWorldMap  — UNVERIFIED. REP #$20, LDX #$0008, falls into transitionFromWorldMap. Parameter setup entry point.
$01A25D (PRG $00A25D)  transitionFromWorldMap  — UNVERIFIED. STA $04, STX $0924. Shared entry with transitionToWorldMap.
(REMOVED: $00DB69 "handleMapTransition" was WRONG → setupVramDMATransfer: checks $05F5, configures $2115/$4310/$4320 for DMA ch1+2. Moved to DMA section.)

## MainLoop (4 labels)

$0093B9 (PRG $0013B9)  mainGameLoop  — Main game loop - handles frame updates, input, game logic. Entry: called each frame. Calls input, sound, and game state updates.
$0188C0 (PRG $0088C0)  gameMainLoop  — Main gameplay loop - updates all systems, renders frame. Entry: called each frame during gameplay.
$018B85 (PRG $008B85)  updateGameLogic  — Updates game logic subsystems - entities, AI, physics, triggers.
$018B92 (PRG $008B92)  updateGraphics  — Updates graphics - OAM, tilemap changes, effects. Prepares for V-blank DMA.

## Collision (2 labels)

$0098D7 (PRG $0018D7)  checkMovementCollision  — UNVERIFIED. Reads $09B4, adds offset, calls gridToPixelCoords ($983F), reads $60.
$00CFC9 (PRG $004FC9)  checkEntityCollision  — UNVERIFIED. Reads $0A5D/$0A5B, uses table at $F4CB, reads $0A66.
(REMOVED: $00983F "checkCollision" was WRONG → gridToPixelCoords: convert bytes at $00/$01 to pixel coords val*8-4, store in $00/$02)
(REMOVED: $00DDB2 "checkMapTrigger" was WRONG → setupVramBG3Write: writes $2116=#$7800, $2115=#$80 for VRAM BG3 tilemap access)

## Utility (7 labels — NEW: relocated from wrong sections)

$009754 (PRG $001754)  doubleByteToIndex  — ASL $00, LDA $00, TAX, RTS. Doubles byte value, returns in X as index. (was "playSoundEffect")
$009891 (PRG $001891)  playEntityAnimation  — Loop through byte table at $98CC, set sprite tile at $180A, renderSprites, wait 4 frames. Until $FF terminator. (was "updateCamera")
$00983F (PRG $00183F)  gridToPixelCoords  — Convert two bytes at $00/$01 to pixel coords: val*8-4. Store results in $00/$02. RTS. (was "checkCollision")
$00985E (PRG $00185E)  clearEntityEntry  — A*16=index into $1800 table, zero 16 bytes (8 words). Entity data clear. (was "moveCharacter")
$00D469 (PRG $005469)  vblankProcess  — NMI body: read $4210, dispatch by $10 mode. Mode 0: OAM DMA $0100→$2102, screen brightness $58→$2100. (was "updateCameraFollow")
$00E143 (PRG $006143)  emptyIRQHandler  — Single RTI instruction. Empty interrupt handler stub. (was "updatePaletteCycle")
$00E53D (PRG $00653D)  initEntityObject  — Zero $1000 buffer (1024 bytes), setup entity from $E42A data table, store params to entity struct. (was "updateMode7Effects")

## LevelLoad (3 labels)

$008060 (PRG $000060)  loadGameData  — Loads game data from ROM. Entry: A=data ID to load. Sets up data pointers at $22/$24, stores data at $0958-$095A, handles special cases for values $FFFF. Returns A=0 on success.
$00DC08 (PRG $005C08)  waitForVblank  — PHA/PHP, if $10==0 poll $4210 bit 7 until VBlank fires, PLP/PLA. Frame sync. (was "loadMapData" — WRONG)
$00DC18 (PRG $005C18)  setupMapObjects  — Sets up objects/NPCs for current map. Entry: reads object data from map, spawns entities.

## Palette (2 labels)

$009136 (PRG $001136)  loadPaletteData  — Loads palette data to CGRAM. Entry: $12/$14=source pointer, $2121=CGRAM address, $4305=length. Uses DMA.
$00C6F9 (PRG $0046F9)  setupCGRAM  — Sets up CGRAM address for access. Entry: A=CGRAM address. Writes to $2121.
(REMOVED: $00E143 "updatePaletteCycle" was WRONG → emptyIRQHandler: single RTI instruction, empty interrupt stub)

## Tilemap (3 labels)

$0094AB (PRG $0014AB)  setupTilemap  — Sets up background tilemap in VRAM. Entry: $12/$14=tilemap data pointer, $2116=VRAM destination. Writes 32x32 tilemap.
$00A515 (PRG $002515)  drawMap  — Draws world map or dungeon map. Entry: A=map ID. Loads tilemap, objects, NPCs to VRAM.
$01A19A (PRG $00A19A)  drawWorldMap  — Draws world map screen with locations. Entry: loads world map tiles, marks current position.

## Camera (1 label)

$0198F3 (PRG $0098F3)  lookupBattleEntityTile  — Calls lookupTilemapTile ($A70D), reads $0E28 battle data, accesses $1404 entity buffer. (was "updateBattleCamera" — WRONG)
(REMOVED: $009891 "updateCamera" was WRONG → playEntityAnimation: loops byte table at $98CC, sets sprite at $180A, renderSprites+wait per frame until $FF)
(REMOVED: $00D469 "updateCameraFollow" was WRONG → vblankProcess: NMI body, reads $4210, mode dispatch via $10, OAM DMA $0100→$2102, brightness $58→$2100)

## Scrolling (2 labels)

$0094D3 (PRG $0014D3)  updateScrollRegisters  — Updates BG scroll registers based on camera position. Entry: $00=BG1HOFS, $02=BG1VOFS, etc. Writes to $210D-$2114.
$00E31C (PRG $00631C)  updateDepthEffect  — Updates depth/parallax effect. Entry: adjusts layer scrolling based on Z-depth.

## RNG (2 labels)

(REMOVED: $00B90F "initRandomSeed" and $00B925 "getRandomNumber" were WRONG — see Text section as lookupStringTable1/lookupStringTable2)

## Player (0 labels — section emptied)

(REMOVED: $00985E "moveCharacter" was WRONG → clearEntityEntry: A*16=index into $1800 table, zero 16 bytes. Entity data clear.)

## Mode7 (0 labels — section emptied)

(REMOVED: $00E53D "updateMode7Effects" was WRONG → initEntityObject: zeros $1000 buffer, sets up entity from $E42A data table, stores params to entity struct)

## Entity — bank81 (15 labels)

$01DC00 (PRG $00DC00)  updateEntityWrapper  — JSL wrapper into updateEntity; RTL.
$01DC04 (PRG $00DC04)  updateEntity  — Core entity tick: loads anim from $0B:BF64, applies velocity/accel, dispatches by entity state ($0010,Y).
$01DDE0 (PRG $00DDE0)  signExtendByte  — Masks A to $00FF, sign-extends if >= $80 by decrementing $07.
$01DDED (PRG $00DDED)  applyMovementCurve  — Indexes curve table at $0B:E2CF, scales via multiplyUnsigned16, >>5.
$01DE2A (PRG $00DE2A)  saveEntityToBuffer  — Copies 16 words from entity struct at $0000,Y to $1400,X buffer.
$01DA43 (PRG $00DA43)  entityScreenSetup  — Sets $78=$7000 scroll, $57=$FE flags, calls $B7EE.
$01DA56 (PRG $00DA56)  sceneEntityInit  — Reads $7E:EA82 scenario#; checks $EA96; sets $7F:C005 graphics.
$01DB33 (PRG $00DB33)  entityStateConfig  — Splits A: high nibble->$76, low->$77; sets $84=$50 if high nonzero.
$01E155 (PRG $00E155)  initEntityFromData  — Unpacks entity type+props from A; calls entityStateConfig + evtEntityPropertySet; RTL.
$01E4D2 (PRG $00E4D2)  populateEntityGrid  — Fills 32-entry entity grid from $1400; first 16 conditional on type, last 16 unconditional.
$01E50A (PRG $00E50A)  initEntitySlot  — Sets $0E00=$FF active, type-specific config, clears fields $0E16-$0E1F, flushes to buffer.
$01E593 (PRG $00E593)  filterEntitiesByTeam  — Scans 16 entries in $7F:B000; copies matching team-ID to $1400.
$01E75E (PRG $00E75E)  spawnEntitiesFromFlags  — Iterates $7E:EA00-EA7F; flag >= $80 spawns entity via findEntityByType+initEntityWithTile.
$01F6C9 (PRG $00F6C9)  evtEntityInitScene  — Zeros $0A51/$0A53 entity counters, calls evtEntityClearTable.
$01F6D5 (PRG $00F6D5)  evtEntityClearTable  — Clears $1800-$19FF (entity table, 512 bytes) to zero.
$01F6EE (PRG $00F6EE)  evtEntityInitFromScript  — Decodes entity flags from A (tile#, priority, bank); looks up script meta-table at $0A:8000; inits entity state.

## Math — bank81 (7 labels)

$01DE09 (PRG $00DE09)  multiplyByFrameRate  — Hardware multiply $4202/$4203; scales A by ($3F+$08), >>6.
$01EEC2 (PRG $00EEC2)  divideUnsigned16  — Software Y/A division. Returns quotient in A, remainder in Y.
$01EEDB (PRG $00EEDB)  multiplyUnsigned16  — Software A*Y multiply. Returns low word in A, high in Y.
$01EF1F (PRG $00EF1F)  divideHardware8  — Hardware 8-bit division via $4204/$4206; reads quotient from $4214 after NOPs.
$01EF37 (PRG $00EF37)  absOrZero  — A<$8000 returned unchanged; A>=$8000 negated; Y=1 if was negative.
$01EF4A (PRG $00EF4A)  absValue  — AND #$7FFF; negates if Y!=0 (sign flag from absOrZero).
$01DDE0 (PRG $00DDE0)  signExtendByte  — (also listed under Entity) Masks A to $00FF, sign-extends if >= $80.

## GameState — bank81 (3 labels)

$01DE84 (PRG $00DE84)  getScenarioFlags  — REP #$20; AND $7E:EA88; RTS. Bit-test against scenario flags.
$01DE8B (PRG $00DE8B)  initBattleScene  — Full battle init: DMA $7F:8000 tilemap, processEnemyAI, color math, mode 7 setup.
$01E63B (PRG $00E63B)  checkScenarioTransition  — Checks $EA88 bit 5 (scenario complete); falls into saveAndLoadTilemap.

## Script — bank81 (11 labels)

$01E0F8 (PRG $00E0F8)  displayScenarioText  — Dispatches text meta-table $48/$B8; nav arrows; secondary table $0B00+scenario#.
$01E784 (PRG $00E784)  advanceScenarioTimer  — Adds $0A08 to $EA8A; sets timer $13; dispatches text $7B.
$01EB0F (PRG $00EB0F)  showScenarioIntro  — Game mode 8; scenario name text (EA82+$200); briefing/description screen.
$01EC8D (PRG $00EC8D)  callCutsceneHandler  — JSL $00:B26B jump table dispatch. A=handler index.
$01F785 (PRG $00F785)  evtCheckDelay  — Checks delay $0A83, input $4E, mode $6A; dispatches to event pre-dispatch.
$01F942 (PRG $00F942)  evtReadOperand  — Reads 16-bit from [$85]; bit7 $02 = dereference as WRAM address ($7E6A00,X or DP).
$01FCDD (PRG $00FCDD)  evtJmpIndirect  — JMP ($0000); trampoline after target loaded to DP $00.
$01FE8B (PRG $00FE8B)  eventCmd3B_debugEnable  — Event command 0x3B handler - INC $0A87.
$01FF06 (PRG $00FF06)  evtReadByte  — Reads one byte from [$85], advances by 1, masks $00FF.
$01FF0E (PRG $00FF0E)  evtReadTwoWords  — Reads first word to $00, falls through to evtReadWord for $02; advances by 4.
$01FF16 (PRG $00FF16)  evtReadWord  — Reads 16-bit from [$85], advances by 2, stores to $02.
$01FF1F (PRG $00FF1F)  evtReadAddress  — Reads 16-bit; 0=default $0A08, >=$8000=WRAM $7E:EA00; resolves 24-bit ptr.

## Save — bank81 (8 labels)

$01E2FE (PRG $00E2FE)  buildSaveSlotPreview  — Loops 3 slots: copies $60 bytes + scenario#/sub-val per slot to preview buffer.
$01E35E (PRG $00E35E)  loadTwoSaveSlots  — Reads 2 consecutive SRAM slots from $C818 via loadSaveSlot.
$01E36A (PRG $00E36A)  loadSaveSlot  — Reads one SRAM slot; validates via checkSaveSpace; $48 stride.
$01E37F (PRG $00E37F)  initSaveScreen  — Sets save mode $0A55; dispatches meta-table $B1 (save/load menu text).
$01E552 (PRG $00E552)  initSaveSlotTilemap  — DMA $1400->$7F:B000; filters entities by team ($FF/$00).
$01E626 (PRG $00E626)  loadScenarioPreserving  — Saves $EA82, calls checkScenarioTransition, restores original scenario#.
$01E64C (PRG $00E64C)  saveAndLoadTilemap  — Selects SRAM slot by map type (0/$0AA0/$1540); backs up $1400->$7E:E600; writes tilemap+checksum.
$01E6CE (PRG $00E6CE)  loadAndVerifyTilemap  — Loads tilemap from SRAM, verifies checksum; restores entities from $7E:E600 if valid.

## Tilemap — bank81 (21 labels)

$01E5D4 (PRG $00E5D4)  setupTilemapReader  — Reads $7F:C000 params; calls lookupTilemapTile ($A70D) for tilemap decode.
$01E602 (PRG $00E602)  readTilemapStream  — Streams words from $7F:9000; handles row boundaries ($06 counter); X=$FFFF=done.
$01E744 (PRG $00E744)  writeTilemapToBuffer  — Reads from [$16] to $7F:9000 via page tracking.
$01EC92 (PRG $00EC92)  calcTilemapOffset_WithWrap  — $09FC+$09FE+$0A00; wraps at row 62.
$01ECAC (PRG $00ECAC)  calcTilemapOffset  — Simpler variant without wrap check.
$01ECB9 (PRG $00ECB9)  calcTilemapXY  — X*2 + (Y&$1F)<<6 -> linear $7E:9000 tilemap index.
$01ECD6 (PRG $00ECD6)  initTilemapAndSync  — initTilemapRegion + waitVBlankAndSetup.
$01ECE1 (PRG $00ECE1)  initTilemapAndSync_Long  — RTL wrapper for initTilemapAndSync.
$01ECE5 (PRG $00ECE5)  initTilemapRegion  — Sets $0A02=$2000; fills $7E:9000 with blank tiles; $09F4/$09F6=cols/rows.
$01EDFA (PRG $00EDFA)  clearTilemapRows  — Fills $7E:9000 region with $1100; $19 rows x $1E cols at X=$0102.
$01EFA7 (PRG $00EFA7)  setupTilemapSource_Long  — RTL wrapper for setupTilemapSource.
$01EFAB (PRG $00EFAB)  setupTilemapSource  — Configures DMA src by mode in Y; dispatches evtTilemap_ProcessEntry.
$01F3A0 (PRG $00F3A0)  evtTileBufferAllRows  — Buffers all 32 rows; copies $0600/$0680 to $7F:B000/$7F:D000.
$01F3F6 (PRG $00F3F6)  evtTileBufferRowDown  — Decrements $5C, calls column builder ($F44B), restores $5C.
$01F402 (PRG $00F402)  evtTileBufferRowBottom  — Adds Y+#$F0, $5C+#$1F offset, calls $F44B, restores $5C.
$01F41C (PRG $00F41C)  evtTileBufferRowLeft  — Decrements $5A by 1, calls evtTileReadColumn ($F4C4), restores.
$01F431 (PRG $00F431)  evtTileBufferRowRight  — Adds #$F8 to $60 for X; falls through to evtTileBufferRowWithOffset.
$01F43C (PRG $00F43C)  evtTileBufferRowWithOffset  — Pushes A, adds #$20 to $5A, calls $F4C4, restores.
$01F44B (PRG $00F44B)  evtTileBufferColumn  — Stores X->$02, Y->$04; calls evtTileReadRow; sets $05F5=#$01 dirty flag.
$01F45E (PRG $00F45E)  evtTileReadRow  — Computes tilemap WRAM addr from $5A/$5C; reads $7F:0000; splits into $0600/$0680.
$01F47F (PRG $00F47F)  evtTileReadRowInner  — Alternate entry point into evtTileReadRow mid-stream.
$01F4C4 (PRG $00F4C4)  evtTileReadColumn  — Reads vertical column from $7F:0000 WRAM tilemap into $0600/$0680 buffers.
$01F544 (PRG $00F544)  evtTileClearPriority  — Clears BG priority bit (AND #$DF) across $7F:0000 tilemap using $7F:C000 dimensions.
$01F582 (PRG $00F582)  evtTileSetPriority  — Sets BG priority (ORA #$20) where $7F:A000 overlay mask is nonzero.
$01F5DE (PRG $00F5DE)  evtTileDecompressMap  — Decompresses tile indices from $7F:9082 to $7F:0306 via evtTileExpandEntry.
$01F63B (PRG $00F63B)  evtTileExpandEntry  — Expands 9-bit tile index to 3x3 metatile block from $7F:6000 lookup.

## Scrolling — bank81 (5 labels)

$01F2BF (PRG $00F2BF)  evtScrollClampY  — Clamps Y scroll ($62) to min; checks 8px boundary crossing; triggers row update.
$01F30D (PRG $00F30D)  evtScrollRefreshAllRows  — Saves/restores $5C; loops 32 rows calling tile column builder + vblank ($B7EE).
$01F33C (PRG $00F33C)  evtScrollInitFullLong  — RTL entry; builds tile buffer ($F3A0); sets $78=#$7800, $57=#$FF/#$FE with vblank waits.
$01F362 (PRG $00F362)  evtScrollInitFull  — RTS version; calls $B7EE, $F3A0, sets $78/$57 with vblank waits.
$01F388 (PRG $00F388)  evtScrollInitPartial  — Partial init: calls $F3A0, sets $78=#$7800, $57=#$FF, one vblank wait.

## Text — bank81 (6 labels)

$01DA1D (PRG $00DA1D)  sceneTextDisplay  — Reads $0E37 bits 4-5, adds $24, calls textMetaLookup ($EE4A).
$01EC12 (PRG $00EC12)  sceneTextDispatch  — Main scene text dispatcher: masks low nibble, dispatches table, entity setup, tilemap commit.
$01ED43 (PRG $00ED43)  writeTilemapChar  — calcTilemapOffset_WithWrap + JSL writeTextCharacter ($00:C152).
$01ED5E (PRG $00ED5E)  processFrame  — Joypad read, cursor blink (toggle $3E every 16 frames), writeTextCharacter, VBlank loop.
$01EE4A (PRG $00EE4A)  textMetaLookup  — High byte selects meta-table entry at $02:8000; low byte selects entry index.
$01EE6D (PRG $00EE6D)  loadTextFromPtr  — Loads text from [$14]; $7FFF sentinel = event script redirect to $0A24/$0A26.

## Music — bank81 (1 labels)

$01EB86 (PRG $00EB86)  soundDispatcher  — Routes by value: >=$8000=SPC direct, $200-$FFF=music via processAIscript, $100-$1FF=SPC reg, <$100=timer.

## BattleInit — bank81 (3 labels — NEW: relocated from wrong SFX section)

$01BC16 (PRG $00BC16)  clearBattleDataSlot  — Zero 8 bytes at $0E20-$0E27 (4 words via loop). Battle unit data partial clear.
$01BC27 (PRG $00BC27)  clearBattleUnitState  — Zero fields across $0E00-$0EDE for two battle units (offset $80 apart). Copy $0E25→$0EA5.
$01BC6D (PRG $00BC6D)  initBattleSequence  — dispatchGameMode(1), clearBattleUnitState, initObjectTable, setup battle params via $EB86/$B80D/$B872.

## Helper — bank81 (5 labels)

$01EB7C (PRG $00EB7C)  enableInterrupts  — Single JSL wrapper to enable IRQ/NMI.
$01EB81 (PRG $00EB81)  disableInterrupts  — Single JSL wrapper to disable IRQ/NMI.
$01ECCC (PRG $00ECCC)  waitVBlankAndSetup  — INC $57, JSR $B7EE; triggers VBlank transfer and waits.
$01EE1E (PRG $00EE1E)  commitDmaFlag  — Copies $0A18 -> $0A1A; triggers tilemap-to-VRAM DMA on next VBlank.
$01EF85 (PRG $00EF85)  advanceDataPointer  — Walks 4-byte records at A*4; advances 24-bit ptr [$12]:$14; handles bank crossing.

## OAM — bank81 (1 labels)

$01F6E7 (PRG $00F6E7)  evtCallRenderSprites  — JSL wrapper to renderSprites ($00:C8BB).

## Memory — bank81 (1 labels)

$01DA2F (PRG $00DA2F)  clearBuffer7FB000  — Zero-fills $7F:B000, 2KB via STZ loop.

## Debug (4 labels)

$008A87 (PRG $000A87)  debugModeFlag  — Non-zero enables debug mode features.
$01FE8B (PRG $00FE8B)  eventCmd3B_debugEnable  — Event command 0x3B handler - INC $0A87.

## GameState — bank81 additional (3 labels)

$01DAF8 (PRG $00DAF8)  setScreenEffect  — Sets PPU effect bitmask from low 3 bits of A; stores $5E/$5F; mode $74.
$0183E4 (PRG $0083E4)  decrementEventFlag  — Reads $0E98 index; decrements $7E:EA00+X by 1.
$01E7A1 (PRG $00E7A1)  incrementEventFlag  — Reads $7E:EA00+X; if <$50 and ==0 returns nonzero; else incr (max 99).

## Scrolling — bank81 additional (9 labels)

$01F12A (PRG $00F12A)  initScrollLimits  — Reads $7F:C000 map dims; computes scroll bounds $0A46-$0A4E; sets camera.
$01F18B (PRG $00F18B)  centerCameraOnPosition  — Clamps $00/$02 to scroll limits; stores $60/$62 pixel, $5A tile scroll.
$01F1D6 (PRG $00F1D6)  scrollByDelta  — Dispatches X/Y deltas to pos/neg scroll subs; RTL entry.
$01F1FC (PRG $00F1FC)  processScrollDirtyWrapper  — JSR processScrollDirty + RTL.
$01F200 (PRG $00F200)  processScrollDirty  — Checks dirty $64; handles deferred tilemap row/col updates.
$01F23E (PRG $00F23E)  scrollRightByDelta  — Adds A to $60 X scroll; clamps max; marks column dirty.
$01F262 (PRG $00F262)  scrollLeftByDelta  — Subtracts A from $60; clamps min; marks column dirty.
$01F28C (PRG $00F28C)  scrollDownByDelta  — Adds A to $62 Y scroll; clamps max; marks row dirty.
$01F2F8 (PRG $00F2F8)  saveScrollState  — Saves $5A/$5C/$60/$62 to $0A3E-$0A44.
$01F3FA (PRG $00F3FA)  renderScrollRowTop  — Decrements $5C; calls $F44B for row above; restores.
$01F406 (PRG $00F406)  renderScrollRowBottom  — Adds $F0+$1F offsets; calls $F44B for bottom edge; restores.

## Tilemap — bank81 additional (6 labels)

$01F060 (PRG $00F060)  buildSpellMenuTilemap  — Sets up tilemap at bank $23:$F800 for spell menu layout.
$01F0E4 (PRG $00F0E4)  copyTilemapFromWram  — Lookup table entry; copies $7E:2000 to dest (even/odd interleave).
$01A6A5 (PRG $00A6A5)  setupCursorTile  — Stores #$44→$06F3 tile attr; #$0095→$66 cursor offset.
$01A6B8 (PRG $00A6B8)  readMapDimensions  — Reads $7F:C000/$C001 width/height; stores $00/$02.
$01A6D7 (PRG $00A6D7)  findEmptyMapTile  — Searches tilemap via $9ED1 until FFFF; checks $7F:9000 passability.
$01F6AD (PRG $00F6AD)  selectMapVariant  — Maps input 0-3→offset; calls setTimerValue with #$000E.
$01DE49 (PRG $00DE49)  loadTileTemplate  — 7-bit tile idx * 24; copies from $02:A4E0 to $0E80 buffer.

## Entity — bank81 additional (7 labels)

$0198A0 (PRG $0098A0)  setupShopEntity  — Stores X→$0936; entity update+text meta+draw; waits 50 frames.
$019EFD (PRG $009EFD)  searchEntityByPosition  — Iterates $1800; finds nearest to ($00,$02) by abs distance.
$01A97C (PRG $00A97C)  removeUnitFromList  — Shifts unit list $1400 down by $20-byte slot; clears last.
$01AE1F (PRG $00AE1F)  applyDamageToUnit  — Subtracts damage ($26 masked 12-bit) from HP $1408+X.
$01B04F (PRG $00B04F)  dispatchBattleAction  — Masks A to 6 bits; indexes 64-entry jump table at $B05F.
$01E7C8 (PRG $00E7C8)  spawnEntityWithFlag  — Sets entity params; links to event flag $1416; calls initEntityWithTile.
$01E822 (PRG $00E822)  initEntityWithTile  — Calls loadTileTemplate; populates entity subtable from $0E8E buffer.
$01E8BE (PRG $00E8BE)  findEntityByType  — Searches $1401+X type (stride $20) across 16 entries; returns idx or $FFFF.

## Math — bank81 additional (3 labels)

$01F17E (PRG $00F17E)  multiplyBy24  — AND #$FF; A*8+A*16=A*24; map tile stride.
$01DB8F (PRG $00DB8F)  lookupSineTable  — Folds 9-bit angle; looks up sine from ROM $00:F7CB; returns 8-bit.
$01E8E9 (PRG $00E8E9)  addSignedOffset  — Sign-extends 8-bit→16-bit; adds to $00 clamped [-127,+127].

## DMA — bank81 additional (2 labels)

$01DB5B (PRG $00DB5B)  initHDMATable  — Builds HDMA table at $7E:A000; 12-scanline header + 100 2-scanline entries.
$01C62D (PRG $00C62D)  setupHdmaScroll  — Sets up HDMA scroll table at $7F:B000; bit6=clear, bit7=second layer.

## Helper — bank81 additional (4 labels)

$01DBC7 (PRG $00DBC7)  requestVblankUpdate  — INC $57 + vblank wait ($B7EE); triggers display refresh.
$01EBE5 (PRG $00EBE5)  setTimerValue  — INC A, store to $81; sets frame/delay timer.
$01EBED (PRG $00EBED)  busyWaitDelay  — 300-iteration busy-wait loop; short CPU delay.
$01F125 (PRG $00F125)  lookupTableEntryWrapper  — JSL lookupTableEntry + RTS wrapper.
$01ED4F (PRG $00ED4F)  waitForDpadInput  — Loops processFrame until joypad $50 has D-pad/button ($F0F0 mask).

## Text — bank81 additional (1 labels)

$01EBF7 (PRG $00EBF7)  dispatchSceneText  — Stores index $0A22; high nybble→sceneTextDispatch; low 12→textMetaLookup.

## AI (6 labels)

$009556 (PRG $001556)  processEnemyAI  — Processes enemy AI logic for battle. Entry: reads enemy data from $7EEA8C, processes AI scripts from ROM table $0BE579.
$009634 (PRG $001634)  processEnemyAIData  — Processes enemy AI script data from ROM table $0BE579. Entry: X=AI data index, Y=direction (2=forward, else backward).
$009E81 (PRG $001E81)  processBattleTurn  — Processes one battle turn for a unit. Entry: A=unit ID. Handles AI for enemies, input for player, executes actions.
$00AA2F (PRG $002A2F)  processAIscript  — Processes AI script for enemy behavior. Entry: A=enemy ID. Reads script from ROM, executes commands.
$00B0A8 (PRG $0030A8)  updateTurnOrder  — Updates battle turn order based on agility. Entry: sorts unit list by speed, determines next actor.
$00CF6B (PRG $004F6B)  updateEntityAI  — Updates AI for all entities. Entry: calls entity-specific AI routines based on type.

## Unused (1 labels)

$01FF43 (PRG $00FF43)  unusedFunction  — Unused function - appears to be dead code. Entry: never called in normal gameplay.

## SPC700 — bank $2B (13 labels)

$2BDD78 (PRG $15DD78)  spcSetSourceAddr  — Stores Y→$B8, A→$BA; sets source addr for SPC transfer.
$2BDD89 (PRG $15DD89)  spcSetDestAddr  — Stores Y→$BB, A→$BD; sets SPC-side dest addr.
$2BDDE2 (PRG $15DDE2)  spcBeginTransfer  — Sends cmd $02 to SPC700; prepares bulk transfer.
$2BDDF7 (PRG $15DDF7)  spcStartTransfer  — Sends cmd $03 to SPC700; initiates transfer sequence.
$2BDED8 (PRG $15DED8)  spcLoadSampleBlock  — Sends cmd $08; reads ptr+size from table; transfers sample data.
$2BDF6B (PRG $15DF6B)  spcLoadSampleSet  — Iterates sample set table; calls spcLoadSampleBlock per entry until $FF.
$2BE0A0 (PRG $15E0A0)  spcSetDspRegister  — Sends cmd $15 + register(A) + value(Y) to SPC700.
$2BE0DE (PRG $15E0DE)  spcPlaySfx  — Sends cmd $17 + SFX ID(A) + param(Y) to SPC700.
$2BE0FD (PRG $15E0FD)  spcPlayMusic  — Sends cmd $18 + track ID(A) to SPC700.
$2BE181 (PRG $15E181)  spcWritePort2  — Writes A→$2142, Y(lo)→$2143; direct SPC port manipulation.
$2BE19E (PRG $15E19E)  spcInitHandshake  — Sets $B6=$88; waits echo $2140; sends cmd via $2141.
$2BE1BD (PRG $15E1BD)  spcEchoWaitReset  — Writes $B6→$2140; waits echo; clears $2141; resets handshake.
$2BE1D8 (PRG $15E1D8)  spcPortWriteWait  — Writes $B6→$2140; waits echo; increments $B6.

## SPC registers (16 labels)

$0080F0 (PRG $0000F0)  TEST  — SPC700 Testing register
$0080F1 (PRG $0000F1)  CONTROL  — SPC700 I/O and Timer Control
$0080F2 (PRG $0000F2)  DSPADDR  — SPC700 DSP Address
$0080F3 (PRG $0000F3)  DSPDATA  — SPC700 DSP Data
$0080F4 (PRG $0000F4)  CPUIO0  — SPC700 CPU I/O 0
$0080F5 (PRG $0000F5)  CPUIO1  — SPC700 CPU I/O 1
$0080F6 (PRG $0000F6)  CPUIO2  — SPC700 CPU I/O 2
$0080F7 (PRG $0000F7)  CPUIO3  — SPC700 CPU I/O 3
$0080F8 (PRG $0000F8)  RAMREG1  — SPC700 Memory Register 1
$0080F9 (PRG $0000F9)  RAMREG2  — SPC700 Memory Register 2
$0080FA (PRG $0000FA)  T0TARGET  — SPC700 Timer 0 scaling target
$0080FB (PRG $0000FB)  T1TARGET  — SPC700 Timer 1 scaling target
$0080FC (PRG $0000FC)  T2TARGET  — SPC700 Timer 2 scaling target
$0080FD (PRG $0000FD)  T0OUT  — SPC700 Timer 0 output
$0080FE (PRG $0000FE)  T1OUT  — SPC700 Timer 1 output
$0080FF (PRG $0000FF)  T2OUT  — SPC700 Timer 2 output

## Text variables (8 labels)

$0089FC (PRG $0009FC)  textCurrentColumn  — Current column position (0-15). Updated by processText.
$0089FE (PRG $0009FE)  textCurrentRow  — Current row position (0-1). Updated by newline ($90).
$008A00 (PRG $000A00)  textLineWidth  — Line width (typically 16). Used by calculateBufferOffset.
$008A02 (PRG $000A02)  textPriorityPalette  — Priority+palette bits. Format: VHPPCCCC.
$008A0A (PRG $000A0A)  textExtendedVariable  — Extended control code variable. Set by $FD.
$008A16 (PRG $000A16)  textExtendedCounter  — Extended control code counter. Set by $FA.
$008A1C (PRG $000A1C)  textSpecialMode1  — Special rendering mode flag 1.
$008A1E (PRG $000A1E)  textSpecialMode2  — Special rendering mode flag 2.

## Text buffers (2 labels)

$019000 (PRG $009000)  textTileBufferTop  — Top tile buffer (64B, 32×2). Tile# + VHPPCCCC. VRAM via V-blank.
$019040 (PRG $009040)  textTileBufferBottom  — Bottom tile buffer (64B). +$0400 palette diff from top.

## Data tables (2 labels)

$298001 (PRG $148001)  scenarioPointerTable  — 16-bit pointer table at bank $29; scenario/map data blocks.
$3FD1CE (PRG $1FD1CE)  compressedMapData  — Compressed/packed map/event data. Not code.
$3FF606 (PRG $1FF606)  packedGraphicsTiles  — Packed 2-bit pixel data (font/UI tiles). Not code.

