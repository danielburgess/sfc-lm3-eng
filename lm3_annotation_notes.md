# LM3 Base ROM Annotation Notes

ROM: lm3.sfc (SNES LoROM)
Addresses: SNES mapped (bank:offset) and PRG absolute offset
Total named labels: 905
Categories: 38

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

## Text (56 labels)

$00B67C (PRG $00367C)  fillTextBuffer_Phase1  — Phase 1 text engine: streams text from ROM into WRAM $0400 buffer. Dispatches FF control codes; calls unit-name copy, etc.
$00B68D (PRG $00368D)  textLoopStart  — Text loop: reads [$14],Y into $0400 buffer
$00B701 (PRG $003701)  ffHighJumpTable  — FF codes >= $80: processed inline Phase 1, NOT buffered
$00B775 (PRG $003775)  ffLowBufferCopy  — FF codes < $80: 3 raw bytes copied to $0400 buffer
$00B985 (PRG $003985)  textRawCopyHandler  — Copies raw bytes from embedded 3-byte SNES ptrs in text
$00BB91 (PRG $003B91)  compareStrings  — Compares two strings. Entry: $12/$14=string1, $16/$18=string2. Returns Z flag set if equal.
$00BBB8 (PRG $003BB8)  endOfTextHandler  — Null byte handler: kanji tile copy + render trigger
$00BC75 (PRG $003C75)  renderTextWrapper  — Text render wrapper - sets up parameters and calls main text processor. Entry: expects text pointer at $14/$16. Sets $14=#$0400, $16=0, calls processText. Returns via RTL.
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
$00C156 (PRG $004156)  writeTextCharacter  — Writes single character to text buffer. Entry: A=character code, X=buffer offset. Writes to top/bottom buffers based on $0A1C/$0A1E flags.
$00C17B (PRG $00417B)  writeTilemapEntry  — Writes tilemap entry for character to top/bottom buffers. Entry: character code on stack, X=buffer offset. Adds $0A02 (priority/palette bits) to character index. Writes to $7E9000,X (top tile) and $7E9040,X (bottom tile) with +$0400 palette difference. Each buffer holds 32 tiles (16x2 area), each entry 2 bytes: tile# low + VHPPCCCC (V=vert flip, H=horiz flip, P=priority, CCCC=palette).
$00C233 (PRG $004233)  calculateBufferOffset  — Calculates buffer position from column/row/width. Entry: $09FC=column, $09FE=row, $0A00=width. Returns X=offset.
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
$00ABF4 (PRG $002BF4)  updateWeatherEffect  — Updates weather/lightning visual effects. Entry: sets up effect parameters, calls updateLightningEffect.
$00B525 (PRG $003525)  fadeToBlack  — Fades screen to black for transitions. Entry: called before scene changes. Gradual fade via $2100.
$00D8F9 (PRG $0058F9)  updateParticleSystem  — Updates particle effects system. Entry: processes particle list, updates positions, lifetimes.
$00D927 (PRG $005927)  spawnParticle  — Spawns new particle effect. Entry: A=particle type, $00/$02=position, $04/$06=velocity.
$00D954 (PRG $005954)  drawParticles  — Draws all active particles to OAM. Entry: scans particle list, creates OAM entries.
$00DE68 (PRG $005E68)  updateWaterEffect  — Updates water ripple effect. Entry: animates water tiles, applies distortion.
$00DEA0 (PRG $005EA0)  updateFireEffect  — Updates fire animation effect. Entry: animates flame sprites, light flicker.
$00DF47 (PRG $005F47)  updateSmokeEffect  — Updates smoke particle effect. Entry: animates smoke plumes, dissipation.
$00DF72 (PRG $005F72)  updateLightningEffect  — Updates lightning flash effect. Entry: random flashes, screen brightening.
$00DF8C (PRG $005F8C)  updateWeatherParticles  — Updates weather particles (rain, snow). Entry: moves particles, respawns off-screen.
$00E102 (PRG $006102)  updateDayNightCycle  — Updates day/night cycle lighting. Entry: adjusts palette based on time of day.
$00E144 (PRG $006144)  updateColorMath  — Updates color math for special effects. Entry: adjusts $2130-$2132 registers.
$00E157 (PRG $006157)  updateBlendEffect  — Updates screen blend/fade effect. Entry: adjusts transparency levels.
$00E22D (PRG $00622D)  updateMotionBlur  — Updates motion blur for fast movement. Entry: applies afterimage effect.
$00E383 (PRG $006383)  updateLensFlare  — Updates lens flare effect for light sources. Entry: calculates flare position, brightness.
$00E3BE (PRG $0063BE)  updateShadowEffect  — Updates dynamic shadow casting. Entry: calculates shadow positions based on light.
$00E3DD (PRG $0063DD)  updateReflection  — Updates reflection effect on water/mirrors. Entry: renders flipped sprites.
$00E3F0 (PRG $0063F0)  updateTransparency  — Updates transparency levels for objects. Entry: adjusts alpha based on distance/layer.
$00E432 (PRG $006432)  updateScanlineEffects  — Updates multiple scanline effects. Entry: combines gradient, split, color changes.
$00E4E2 (PRG $0064E2)  updateRasterEffects  — Updates raster (per-scanline) effects. Entry: modifies HDMA tables in real-time.
$00E58F (PRG $00658F)  updateDistortionEffect  — Updates distortion/warp effect. Entry: applies wave distortion to tilemap.
$00E5D6 (PRG $0065D6)  updateChromaEffect  — Updates chromatic aberration effect. Entry: shifts color channels slightly.
$00E5E5 (PRG $0065E5)  updateVignetteEffect  — Updates vignette (darkened edges) effect. Entry: adjusts corner darkness.
$00E611 (PRG $006611)  updateFilmGrain  — Updates film grain/noise effect. Entry: adds random pixel noise.
$00E61C (PRG $00661C)  updateCRTEffect  — Updates CRT screen effect (scanlines, curvature). Entry: simulates old monitor.
$00E688 (PRG $006688)  updateBloomEffect  — Updates bloom/glow effect for bright areas. Entry: blurs bright pixels.
$00E7B7 (PRG $0067B7)  updateDepthOfField  — Updates depth of field blur. Entry: blurs distant/close objects.
$00E8A7 (PRG $0068A7)  updatePostProcessing  — Updates all post-processing effects. Entry: combines multiple visual effects.
$019114 (PRG $009114)  drawSpellEffect  — Draws spell visual effect graphics. Entry: A=spell ID, renders particles, glows.
$0191D7 (PRG $0091D7)  drawDamageSpark  — Draws damage hit spark effect. Entry: A=damage type, renders spark particles.
$01921F (PRG $00921F)  drawHealEffect  — Draws healing effect animation. Entry: A=heal power, renders glow, particles.
$0199CD (PRG $0099CD)  drawDamageNumbers  — Draws floating damage numbers in battle. Entry: A=damage amount, $00/$02=position.
$01B958 (PRG $00B958)  runScreenEffect  — Runs screen effect with timers and visual updates. Entry: sets up effect parameters, calls updateFilmGrain, updateScanlineEffects.
$01B9E2 (PRG $00B9E2)  initScreenTransition  — Initializes screen transition effect. Entry: sets $0958=$FFFF, calls dispatchGameMode, sets up graphics.
$01BA3F (PRG $00BA3F)  updateRandomEffect  — Updates random visual effect. Entry: uses $0C/$0E timers, calls updateLightningEffect for random value, updates $4F.
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

$009377 (PRG $001377)  getCharacterDataPointer  — Calculates pointer to character data table. Entry: A=character ID. Returns $12/$14=pointer to character data (bank $21, base $C000 + ID*$28).
$009397 (PRG $001397)  checkCharacterFlag  — Checks character flag bit in data structure. Entry: A=bit mask position, $12/$14=character data pointer. Returns A=adjusted value based on flag (adds $0400 if flag set).
$009F76 (PRG $001F76)  applyStatusEffect  — Applies status effect to character. Entry: A=character ID, X=status effect type. Updates character status flags.
$00A0A4 (PRG $0020A4)  reviveCharacter  — Revives a KO'd character with partial HP. Entry: A=character ID. Restores HP to 25% of max.
$00A103 (PRG $002103)  gainExperience  — Awards experience points to character. Entry: A=character ID, X=XP amount. Updates level if threshold reached.
$00A157 (PRG $002157)  levelUpCharacter  — Handles character level up. Entry: A=character ID. Increases stats, learns new abilities if any.
$00A9A4 (PRG $0029A4)  calculateStatBonus  — Calculates stat bonus from equipment. Entry: A=character ID. Sums bonuses from all equipped items.
$00A9DF (PRG $0029DF)  checkAbilityLearned  — Checks if character has learned an ability. Entry: A=character ID, X=ability ID. Returns carry set if learned.
$00B00F (PRG $00300F)  castSpell  — Casts spell in battle. Entry: A=caster ID, X=spell ID, Y=target. Deducts MP, applies spell effects.
$0195DC (PRG $0095DC)  awardBattleRewards  — Awards XP, gold, items after battle victory. Entry: calculates based on enemy levels.
$019A05 (PRG $009A05)  updateStatusEffects  — Updates status effect timers and applications. Entry: called each turn for all units.
$019A99 (PRG $009A99)  checkAbilityCondition  — Checks if ability can be used (MP, conditions). Entry: A=ability ID, X=caster. Returns carry if usable.
$019AA6 (PRG $009AA6)  executeAbility  — Executes special ability in battle. Entry: A=ability ID, X=caster, Y=target.
$01AD3B (PRG $00AD3B)  processEntityLoop  — Processes entity loop for values 0-31. Entry: $0EA8=entity count, calls sub_00AD60 for each entity.
$01AD60 (PRG $00AD60)  updateEntity  — Updates single entity. Entry: X=entity index, reads from $1400 table, processes based on $0946.
$01B211 (PRG $00B211)  getRandomEntity  — Gets random entity from pool. Entry: calls updateLightningEffect for random value, checks $1800 table.
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
$01A609 (PRG $00A609)  drawBestiary  — Draws bestiary screen with enemy info. Entry: A=enemy ID. Displays stats, weaknesses.
$01A62A (PRG $00A62A)  handleBestiary  — Handles bestiary navigation - scroll list, view details. Entry: processes bestiary input.
$01A70D (PRG $00A70D)  drawStatusScreen  — Draws character status screen with stats. Entry: A=character ID. Displays all attributes.
$01A729 (PRG $00A729)  handleStatusScreen  — Handles status screen navigation - switch characters, view equipment.
$01A73D (PRG $00A73D)  drawEquipmentScreen  — Draws equipment screen with slots. Entry: A=character ID. Shows equipped items, bonuses.
$01A7B1 (PRG $00A7B1)  handleEquipment  — Handles equipment management - equip/unequip, compare stats.
$01A7E2 (PRG $00A7E2)  drawMagicScreen  — Draws magic/skills screen. Entry: A=character ID. Shows learned abilities, MP costs.
$01A836 (PRG $00A836)  handleMagicScreen  — Handles magic screen navigation - select ability, view description.
$01A83B (PRG $00A83B)  drawFormationScreen  — Draws party formation screen. Entry: shows character positions, allows rearrangement.
$01A94D (PRG $00A94D)  handleFormation  — Handles formation editing - move characters, save layout.
$01A9A3 (PRG $00A9A3)  drawItemScreen  — Draws item inventory screen. Entry: shows all items with quantities.
$01AA22 (PRG $00AA22)  handleItemScreen  — Handles item screen - use, arrange, discard items.
$01AA3C (PRG $00AA3C)  drawKeyItemScreen  — Draws key items screen (plot-critical items). Entry: shows key items with descriptions.
$01AA82 (PRG $00AA82)  handleKeyItems  — Handles key items screen navigation. Entry: view item details.
$01AABE (PRG $00AABE)  drawMapScreen  — Draws in-game map screen. Entry: shows current area with player position.
$01AAE2 (PRG $00AAE2)  handleMapScreen  — Handles map screen - zoom, pan, view different levels.
$01AB6E (PRG $00AB6E)  drawQuestLog  — Draws quest log screen. Entry: shows active/completed quests with objectives.
$01ADEB (PRG $00ADEB)  handleQuestLog  — Handles quest log navigation - scroll, view details.
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
$01DA2F (PRG $00DA2F)  drawSRAMStatus  — Draws SRAM status (free space, slots). Entry: shows save slot usage.

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
$018D3F (PRG $008D3F)  pauseGame  — Pauses game - freezes logic, displays pause menu. Entry: called when start pressed.
$018E84 (PRG $008E84)  resumeGame  — Resumes game from pause - hides menu, unfreezes logic.
$018E91 (PRG $008E91)  gameOverScreen  — Game over screen - displays 'game over', options to retry/quit.
$01956A (PRG $00956A)  checkBattleCondition  — Checks battle win/lose conditions. Entry: evaluates party/enemy status. Returns A=result (0=continue, 1=win, 2=lose).
$019BB2 (PRG $009BB2)  fleeBattle  — Attempts to flee from battle. Entry: calculates success based on agility. Returns carry if successful.
$019C16 (PRG $009C16)  setupBattleFormation  — Sets up battle formation positions. Entry: A=formation ID. Positions party and enemies.
$019CD8 (PRG $009CD8)  initBattleState  — Initializes battle state variables. Entry: sets up turn order, AI states, battle flags.
$019CE6 (PRG $009CE6)  cleanupBattle  — Cleans up battle state after battle ends. Entry: clears battle-specific RAM, restores overworld.
$01A233 (PRG $00A233)  handleWorldMap  — Handles world map navigation - movement between locations. Entry: processes map input.
$01A32B (PRG $00A32B)  checkStoryProgress  — Checks story progression flags. Entry: A=flag set ID. Returns carry if story condition met.
$01A33C (PRG $00A33C)  advanceStory  — Advances story by setting flags. Entry: A=event ID. Sets story flags, may trigger cutscene.
$01A386 (PRG $00A386)  drawCredits  — Draws credits sequence - scrolling text, staff names. Entry: called after game completion.
$01A49E (PRG $00A49E)  drawMinigame  — Draws minigame screen (fishing, puzzle, etc). Entry: A=minigame type. Loads graphics, rules.
$01A4FB (PRG $00A4FB)  handleMinigame  — Handles minigame logic and input. Entry: updates minigame state each frame.
$01A5B6 (PRG $00A5B6)  awardMinigamePrize  — Awards prize for minigame success. Entry: A=prize type (item, gold, etc).
$01AB8F (PRG $00AB8F)  checkGameProgress  — Checks game progress flags for special events. Entry: checks $0A08, $0E28, $0EA8, $0E4E, $0ECE for progression conditions.
$01CF40 (PRG $00CF40)  setupGameSequence  — Sets up game sequence based on $0E6A. Entry: sets $096E, calls sub_00D0B3, runs sequence with $0A00 timing.
$01D135 (PRG $00D135)  runGameModeSequence  — Runs game mode sequence. Entry: calls dispatchGameMode mode 8, sets up graphics, calls animation functions.

## Save (20 labels)

$00A398 (PRG $002398)  saveGame  — Saves game to SRAM. Entry: copies game state from WRAM to SRAM $700000. Includes checksum.
$00A3AA (PRG $0023AA)  loadGame  — Loads game from SRAM. Entry: copies from SRAM $700000 to WRAM, verifies checksum.
$01A137 (PRG $00A137)  handleSavePoint  — Handles save point interaction - save game, restore HP/MP. Entry: displays save menu.
$01A410 (PRG $00A410)  updateConfigSettings  — Updates configuration settings in SRAM. Entry: writes options to save data.
$01AFD1 (PRG $00AFD1)  handleLoadScreen  — Handles load screen - select slot, confirm load. Entry: loads save data from SRAM.
$01B565 (PRG $00B565)  handleSaveScreen  — Handles save screen - select slot, confirm save. Entry: writes game state to SRAM.
$01CBD7 (PRG $00CBD7)  compressSaveData  — Compresses save data before writing to SRAM. Entry: $12/$14=source, $16/$18=dest.
$01CEB6 (PRG $00CEB6)  decompressSaveData  — Decompresses save data after reading from SRAM. Entry: $12/$14=source, $16/$18=dest.
$01CF03 (PRG $00CF03)  verifySaveData  — Verifies save data integrity with checksum. Entry: reads SRAM, calculates checksum.
$01CF36 (PRG $00CF36)  migrateSaveData  — Migrates old save data format to new version. Entry: converts data structures if needed.
$01D231 (PRG $00D231)  backupSaveData  — Creates backup of save data. Entry: copies primary save to backup slot.
$01D462 (PRG $00D462)  restoreBackup  — Restores save data from backup. Entry: copies backup to primary slot.
$01D51B (PRG $00D51B)  clearSaveData  — Clears save slot (new game). Entry: A=slot number. Initializes with default data.
$01D929 (PRG $00D929)  handleAutoSave  — Handles auto-save feature. Entry: called at specific points (zone transitions).
$01D9BC (PRG $00D9BC)  checkSaveSpace  — Checks if enough space for save data. Entry: verifies SRAM is writable.
$01D9D5 (PRG $00D9D5)  initSRAM  — Initializes SRAM on first boot. Entry: writes header, initializes all slots.
$01D9F8 (PRG $00D9F8)  detectSRAM  — Detects SRAM type and size. Entry: tests write/read to determine capacity.
$01DA1D (PRG $00DA1D)  formatSRAM  — Formats SRAM (erase all saves). Entry: called from options menu.
$01DA43 (PRG $00DA43)  handleSRAMError  — Handles SRAM error (corrupt, missing). Entry: displays error message, offers recovery.
$01DA56 (PRG $00DA56)  recoverSaveData  — Attempts to recover corrupted save data. Entry: scans SRAM for valid data fragments.

## Memory (20 labels)

$0080D8 (PRG $0000D8)  findDataEntry  — Searches data table for matching entry. Entry: $00=search value, $22/$24=data table pointer. Returns A=1 if found (sets $096C=index, $22=entry pointer, $096E=entry data), A=0 if not found.
$008122 (PRG $000122)  setupDataStructure  — Sets up data structure from loaded game data. Uses $0986/$0988 as base pointers, calls sub_00E155 for processing. Entry: expects data pointers set. Returns via RTL.
$00BBA7 (PRG $003BA7)  copyMemory  — Copies memory block. Entry: $12/$14=source, $16/$18=dest, A=length. Uses MVN instruction.
$00BCD6 (PRG $003CD6)  clearMemory  — Clears memory block to zero. Entry: $12/$14=address, A=length. Uses STZ in loop.
$00BCFF (PRG $003CFF)  setMemory  — Fills memory block with value. Entry: $12/$14=address, A=length, X=fill value.
$00BD06 (PRG $003D06)  findMemory  — Searches memory for value. Entry: $12/$14=address, A=length, X=search value. Returns Y=offset if found.
$00BD31 (PRG $003D31)  compressData  — Compresses data using simple RLE. Entry: $12/$14=source, $16/$18=dest. Returns A=compressed size.
$00BE22 (PRG $003E22)  decompressData  — Decompresses RLE-compressed data. Entry: $12/$14=source, $16/$18=dest. Returns A=decompressed size.
$00C620 (PRG $004620)  setupWRAM  — Sets up WRAM access via $2180. Entry: A=bank, X=address. Configures $2181-$2183.
$00C64D (PRG $00464D)  copyToWRAM  — Copies data to WRAM via $2180. Entry: $12/$14=source, A=length. Uses loop with $2180 writes.
$00C6A7 (PRG $0046A7)  readFromWRAM  — Reads data from WRAM via $2180. Entry: $12/$14=dest, A=length. Uses loop with $2180 reads.
$00D7BE (PRG $0057BE)  buildDataStructure  — Builds data structure from indirect pointer. Entry: $54/$6D base, reads from [$3A], writes to $7EA001.
$01D0B3 (PRG $00D0B3)  copyDataTable  — Copies data table from ROM to RAM. Entry: uses $0E06 count, copies from $01D113 to $1000, processes $0BE4CF table.
$2BDED8 (PRG $15DED8)  externalMemoryFunc1  — External memory function 1. Entry: advanced memory operations.
$2BDF6B (PRG $15DF6B)  externalMemoryFunc2  — External memory function 2. Entry: additional memory operations.
$2BE0A0 (PRG $15E0A0)  externalCompressionFunc  — External compression/decompression function. Entry: data compression operations.
$2BE0DE (PRG $15E0DE)  externalEncryptionFunc  — External encryption/decryption function. Entry: data security operations.
$2BE0FD (PRG $15E0FD)  externalCRC32Func  — External CRC32 calculation function. Entry: checksum generation.
$2BE181 (PRG $15E181)  externalSortFunc  — External sorting algorithm function. Entry: data sorting operations.
$2BE19E (PRG $15E19E)  externalSearchFunc  — External search algorithm function. Entry: data search operations.

## Math (14 labels)

$00BB65 (PRG $003B65)  multiply8x8  — 8x8 unsigned multiplication. Entry: A=multiplicand, X=multiplier. Returns A=product (16-bit). Uses $4202/$4203.
$00BB71 (PRG $003B71)  divide16x8  — 16÷8 unsigned division. Entry: A=dividend, X=divisor. Returns A=quotient, Y=remainder. Uses $4204-$4206.
$00C1B4 (PRG $0041B4)  compareValues  — Compares two 16-bit values. Entry: A=value1, X=value2. Returns flags for signed comparison.
$00C20E (PRG $00420E)  absoluteValue  — Calculates absolute value. Entry: A=value (16-bit signed). Returns A=absolute value.
$00C219 (PRG $004219)  negateValue  — Negates value (two's complement). Entry: A=value. Returns A=-value.
$00C240 (PRG $004240)  calculateSine  — Calculates sine value using lookup table. Entry: A=angle (0-255). Returns A=sine value (8.8 fixed point).
$00C27F (PRG $00427F)  calculateCosine  — Calculates cosine value (sine of angle+64). Entry: A=angle (0-255). Returns A=cosine value.
$00C29A (PRG $00429A)  interpolateValue  — Linear interpolation between values. Entry: A=start, X=end, Y=factor (0-255). Returns A=interpolated value.
$00C2A9 (PRG $0042A9)  calculateDistance  — Calculates distance between two points. Entry: $00-$01=point1, $02-$03=point2. Returns A=distance.
$00C2E1 (PRG $0042E1)  calculateSlope  — Calculates slope between two points. Entry: A=dx, X=dy. Returns A=slope (fixed point).
$01BB5A (PRG $00BB5A)  clampValue  — Clamps value within boundaries. Entry: A=sign flag, Y=value, $00=step. Returns clamped value.
$01BD98 (PRG $00BD98)  calculateEffectValue  — Calculates effect value using hardware multiply. Entry: calls updateSmokeEffect, multiplies with $0E70.
$2BDD78 (PRG $15DD78)  externalMathFunc1  — External math function 1. Entry: performs complex calculations.
$2BDD89 (PRG $15DD89)  externalMathFunc2  — External math function 2. Entry: additional math operations.

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

$008D78 (PRG $000D78)  setupPPURegisters  — Initializes PPU registers for graphics mode. Sets BGMODE, tile/screen bases, mosaic, etc. Entry: called during init.
$00A5B4 (PRG $0025B4)  setupGraphicsMode  — Sets up graphics mode for specific screen. Entry: calls calculateSlope, sets $2108, $0E20, $0EA0.
$00E24A (PRG $00624A)  debugFlagInit  — STZ/INC $0A87 - debug mode patch site
$018000 (PRG $008000)  systemInit  — System initialization - clears WRAM, sets up hardware, calls external init routines. Entry: called at reset.
$018455 (PRG $008455)  initGraphics  — Initializes graphics system - sets up PPU registers, clears VRAM, loads font.
$018479 (PRG $008479)  initSound  — Initializes sound system - uploads SPC program, sets up sound driver.
$0184F3 (PRG $0084F3)  initGameState  — Initializes game state variables - party, inventory, story flags to default.
$018515 (PRG $008515)  initControllers  — Initializes controller input system - clears input buffers, enables auto-read.
$01853D (PRG $00853D)  enableDisplay  — Enables screen display after init. Entry: sets $2100 to $0F (full brightness).

## HUD (8 labels)

$009BC1 (PRG $001BC1)  updateHPBar  — Updates HP bar display for character. Entry: A=character ID, X=current HP, Y=max HP. Draws bar in HUD.
$00A5CD (PRG $0025CD)  updateMinimap  — Updates minimap display in corner. Entry: reads player position, draws current area on minimap.
$00D7FB (PRG $0057FB)  drawHealthBars  — Draws health bars for visible entities. Entry: scans entity list, draws bars above entities.
$0198C9 (PRG $0098C9)  drawBattleHUD  — Draws battle HUD - HP/MP bars, command list, turn order. Entry: updates each turn.
$01C11D (PRG $00C11D)  drawProgressBar  — Draws progress bar (HP, MP, XP). Entry: A=current, X=max, $00/$02=position, Y=color.
$01C201 (PRG $00C201)  drawClock  — Draws game time clock display. Entry: reads playtime counter, formats as HH:MM.
$01C234 (PRG $00C234)  drawGoldAmount  — Draws gold amount with icon. Entry: reads party gold, formats with commas.
$01D905 (PRG $00D905)  drawPlayTime  — Draws play time display. Entry: formats time string, draws to screen.

## Dialogue (7 labels)

$009A1E (PRG $001A1E)  drawDialogBox  — Draws text dialog box on screen. Entry: $12/$14=text pointer, $00/$02=screen position. Renders text with window effect.
$00A5E6 (PRG $0025E6)  handleNPCDialogue  — Handles NPC dialogue interaction. Entry: A=NPC ID. Loads dialogue text, displays choices if any.
$01A5D3 (PRG $00A5D3)  drawTutorial  — Draws tutorial screen with instructions. Entry: A=tutorial page. Displays text and examples.
$01A5E0 (PRG $00A5E0)  handleTutorial  — Handles tutorial navigation - page turns, exit. Entry: processes tutorial input.
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
$00C6D6 (PRG $0046D6)  setupVRAM  — Sets up VRAM address for access. Entry: A=VRAM address. Writes to $2116-$2117.
$019C5A (PRG $009C5A)  loadBattleBackground  — Loads battle background graphics. Entry: A=background ID. Loads tiles and palette to VRAM.

## DMA (6 labels)

$00916C (PRG $00116C)  setupDMAChannel  — Configures DMA channel for transfer. Entry: A=channel (0-7), X=DMAP/BBAD value, Y=A1T value. Sets up $43x0-$43x3.
$009183 (PRG $001183)  startDMA  — Starts DMA transfer on specified channels. Entry: A=channel mask (bits 0-7). Writes to $420B.
$0091AA (PRG $0011AA)  setupHDMA  — Sets up HDMA channel for raster effects. Entry: A=channel, X=table pointer, Y=indirect pointer. Configures $43x0-$43x7.
$00C454 (PRG $004454)  setupHDMATable  — Sets up HDMA table for gradient effects. Entry: A=channel, $12/$14=table data. Configures indirect HDMA.
$00C469 (PRG $004469)  updateHDMA  — Updates HDMA table values dynamically. Entry: A=channel, X=table offset, Y=new value.
$00D4A3 (PRG $0054A3)  vblankDMAHandler  — V-Blank DMA handler for tilemap upload. Checks $05F5 flag, if set DMAs from $0600/$0680 buffers to VRAM using addresses at $05F6/$05F8. Also handles palette DMA ($5E flag) and other graphics updates.","category":"DMA

## Input (6 labels)

$00B5B8 (PRG $0035B8)  waitForButton  — Waits for button press before continuing. Entry: displays 'press button' prompt, loops until input.
$00C490 (PRG $004490)  readJoypad  — Reads controller input via auto-read. Entry: none. Returns A=joypad1 state, X=joypad2 state.
$00C4B1 (PRG $0044B1)  readJoypadEdge  — Reads newly pressed buttons (edge detection). Entry: compares current with previous frame. Returns A=new presses.
$01888F (PRG $00888F)  handleTitleInput  — Handles input on title screen - start button, demo mode.
$018BB1 (PRG $008BB1)  handleGameInput  — Handles gameplay input - movement, menu, actions. Updates player controller state.
$01A37C (PRG $00A37C)  skipCutscene  — Allows skipping cutscene with button press. Entry: checks for start button during cutscene.

## Interrupt (6 labels)

$008B17 (PRG $000B17)  handleVBlank  — V-Blank interrupt handler. Updates scroll registers, transfers OAM, handles DMA transfers. Entry: called from NMI.
$00C530 (PRG $004530)  setupIRQ  — Sets up IRQ for raster effects. Entry: A=scanline, X=handler address. Configures $4207-$420A.
$00C570 (PRG $004570)  acknowledgeIRQ  — Acknowledges IRQ by reading $4211. Entry: called in IRQ handler. Clears IRQ flag.
$00C585 (PRG $004585)  setupNMI  — Sets up NMI handler. Entry: X=handler address. Stores vector at $00FFEA.
$00C5A7 (PRG $0045A7)  enableInterrupts  — Enables interrupts (NMI/IRQ). Entry: A=interrupt mask. Writes to $4200.
$00C600 (PRG $004600)  disableInterrupts  — Disables all interrupts. Entry: writes $00 to $4200.

## Timer (6 labels)

$00954E (PRG $00154E)  incrementCounter  — Increments a counter in RAM. Entry: A=counter value. Stores incremented value at $81.
$009E3A (PRG $001E3A)  updateBattleTimer  — Updates battle turn timer. Entry: reads timer value, decrements, checks for turn end. Returns carry set if turn ended.
$00C147 (PRG $004147)  incrementCounter3  — Increments counter at $81. Entry: A=value. Similar to incrementCounter but with different entry.
$00C14A (PRG $00414A)  incrementCounter8  — Increments 8-bit counter at $81. Entry: A=value (8-bit).
$01D745 (PRG $00D745)  calculatePlayTime  — Calculates play time from frame counter. Entry: converts frames to hours:minutes.
$01D77D (PRG $00D77D)  updatePlayTime  — Updates play time counter. Entry: increments frame counter, handles overflow.

## Physics (5 labels)

$0095AF (PRG $0015AF)  calculateBattleDamage  — Calculates damage in battle based on attacker/defender stats. Entry: A=attacker ID, X=defender ID. Returns A=damage amount.
$009F0B (PRG $001F0B)  calculateHitRate  — Calculates hit rate for attack. Entry: A=attacker accuracy, X=defender evasion. Returns A=hit chance (0-100).
$00AF6A (PRG $002F6A)  calculateSpellCost  — Calculates MP cost for spell. Entry: A=spell ID. Returns A=MP cost based on spell level and character stats.
$00D0FC (PRG $0050FC)  handleEntityDamage  — Handles damage between entities. Entry: A=attacker ID, X=defender ID. Applies damage, knockback.
$01B313 (PRG $00B313)  calculatePositionOffset  — Calculates position offset for entity. Entry: A=type, X=base, Y=offset. Uses $0936, $0958 for calculations.

## Transition (5 labels)

$00DB69 (PRG $005B69)  handleMapTransition  — Handles map transition (fade out, load new map, fade in). Entry: A=destination map ID.
$019CF3 (PRG $009CF3)  transitionToBattle  — Transitions from overworld to battle. Entry: fades out, loads battle data, fades in.
$019D33 (PRG $009D33)  transitionFromBattle  — Transitions from battle back to overworld. Entry: fades out, restores map, fades in.
$01A258 (PRG $00A258)  transitionToWorldMap  — Transitions to world map from location. Entry: fades out, loads map, fades in.
$01A25D (PRG $00A25D)  transitionFromWorldMap  — Transitions from world map to location. Entry: fades out, loads location, fades in.

## MainLoop (4 labels)

$0093B9 (PRG $0013B9)  mainGameLoop  — Main game loop - handles frame updates, input, game logic. Entry: called each frame. Calls input, sound, and game state updates.
$0188C0 (PRG $0088C0)  gameMainLoop  — Main gameplay loop - updates all systems, renders frame. Entry: called each frame during gameplay.
$018B85 (PRG $008B85)  updateGameLogic  — Updates game logic subsystems - entities, AI, physics, triggers.
$018B92 (PRG $008B92)  updateGraphics  — Updates graphics - OAM, tilemap changes, effects. Prepares for V-blank DMA.

## Collision (4 labels)

$00983F (PRG $00183F)  checkCollision  — Checks collision between two objects. Entry: $00-$03=object1 rect, $04-$07=object2 rect. Returns carry set if collision.
$0098D7 (PRG $0018D7)  checkMovementCollision  — Checks movement collision with environment. Entry: $09B4=offset, calls checkCollision, updates position.
$00CFC9 (PRG $004FC9)  checkEntityCollision  — Checks collisions between entities. Entry: scans entity list, tests bounding boxes.
$00DDB2 (PRG $005DB2)  checkMapTrigger  — Checks for map triggers (doors, warps, events). Entry: tests player position against trigger areas.

## SFX (4 labels)

$009754 (PRG $001754)  playSoundEffect  — Plays a sound effect via APU. Entry: A=sound effect ID. Writes to APU ports $2140-$2143.
$01BC16 (PRG $00BC16)  playCursorSound  — Plays cursor movement sound effect. Entry: called when menu cursor moves.
$01BC27 (PRG $00BC27)  playSelectSound  — Plays selection sound effect. Entry: called when menu item selected.
$01BC6D (PRG $00BC6D)  playErrorSound  — Plays error sound (invalid action). Entry: called when action not allowed.

## LevelLoad (3 labels)

$008060 (PRG $000060)  loadGameData  — Loads game data from ROM. Entry: A=data ID to load. Sets up data pointers at $22/$24, stores data at $0958-$095A, handles special cases for values $FFFF. Returns A=0 on success.
$00DC08 (PRG $005C08)  loadMapData  — Loads map data from ROM. Entry: A=map ID. Loads tiles, collision, objects to WRAM.
$00DC18 (PRG $005C18)  setupMapObjects  — Sets up objects/NPCs for current map. Entry: reads object data from map, spawns entities.

## Palette (3 labels)

$009136 (PRG $001136)  loadPaletteData  — Loads palette data to CGRAM. Entry: $12/$14=source pointer, $2121=CGRAM address, $4305=length. Uses DMA.
$00C6F9 (PRG $0046F9)  setupCGRAM  — Sets up CGRAM address for access. Entry: A=CGRAM address. Writes to $2121.
$00E143 (PRG $006143)  updatePaletteCycle  — Cycles palette colors for effects. Entry: rotates color values in CGRAM.

## Tilemap (3 labels)

$0094AB (PRG $0014AB)  setupTilemap  — Sets up background tilemap in VRAM. Entry: $12/$14=tilemap data pointer, $2116=VRAM destination. Writes 32x32 tilemap.
$00A515 (PRG $002515)  drawMap  — Draws world map or dungeon map. Entry: A=map ID. Loads tilemap, objects, NPCs to VRAM.
$01A19A (PRG $00A19A)  drawWorldMap  — Draws world map screen with locations. Entry: loads world map tiles, marks current position.

## Camera (3 labels)

$009891 (PRG $001891)  updateCamera  — Updates camera position to follow player. Entry: reads player position, calculates camera bounds, updates scroll.
$00D469 (PRG $005469)  updateCameraFollow  — Updates camera to follow target entity. Entry: A=target entity ID. Smooth scrolling with bounds.
$0198F3 (PRG $0098F3)  updateBattleCamera  — Updates battle camera between combatants. Entry: pans between attacker and defender.

## Scrolling (2 labels)

$0094D3 (PRG $0014D3)  updateScrollRegisters  — Updates BG scroll registers based on camera position. Entry: $00=BG1HOFS, $02=BG1VOFS, etc. Writes to $210D-$2114.
$00E31C (PRG $00631C)  updateDepthEffect  — Updates depth/parallax effect. Entry: adjusts layer scrolling based on Z-depth.

## RNG (2 labels)

$00B90F (PRG $00390F)  initRandomSeed  — Initializes random number generator seed. Entry: sets seed based on frame counter.
$00B925 (PRG $003925)  getRandomNumber  — Generates random number. Entry: A=max value. Returns A=random number (0 to max-1). Uses LFSR algorithm.

## Player (1 labels)

$00985E (PRG $00185E)  moveCharacter  — Moves character based on input and collision. Entry: A=character ID, reads controller, updates position.

## Mode7 (1 labels)

$00E53D (PRG $00653D)  updateMode7Effects  — Updates Mode 7 transformation effects. Entry: rotates, scales background.

## Debug (104 labels)

$008A87 (PRG $000A87)  debugModeFlag  — Non-zero enables debug mode features
$01DAF8 (PRG $00DAF8)  exportSaveData  — Exports save data (debug feature). Entry: copies to WRAM for analysis.
$01DB33 (PRG $00DB33)  importSaveData  — Imports save data (debug feature). Entry: writes from WRAM to SRAM.
$01DBC7 (PRG $00DBC7)  dumpMemory  — Dumps memory to log (debug feature). Entry: $12/$14=address, A=length.
$01DC00 (PRG $00DC00)  breakpointHandler  — Breakpoint handler for debugging. Entry: called via BRK instruction.
$01DC04 (PRG $00DC04)  debugMenu  — Debug menu for developers. Entry: hidden menu with cheat options, tests.
$01DDE0 (PRG $00DDE0)  drawDebugInfo  — Draws debug information overlay. Entry: shows coordinates, flags, memory values.
$01DDED (PRG $00DDED)  updateDebugDisplay  — Updates debug display each frame. Entry: reads live game state, updates overlay.
$01DE09 (PRG $00DE09)  handleDebugInput  — Handles debug menu input. Entry: processes debug commands, toggles cheats.
$01DE2A (PRG $00DE2A)  executeDebugCommand  — Executes debug command. Entry: A=command ID, X/Y=parameters.
$01DE84 (PRG $00DE84)  testBattle  — Battle test mode (debug). Entry: starts battle with specified enemies.
$01DE8B (PRG $00DE8B)  testMap  — Map test mode (debug). Entry: loads specified map for testing.
$01E0F8 (PRG $00E0F8)  testMenu  — Menu test mode (debug). Entry: opens specified menu screen.
$01E155 (PRG $00E155)  testGraphics  — Graphics test mode (debug). Entry: displays all tiles, palettes.
$01E2FE (PRG $00E2FE)  testSound  — Sound test mode (debug). Entry: plays all sound effects, music tracks.
$01E35E (PRG $00E35E)  testController  — Controller test mode (debug). Entry: shows button inputs, analog values.
$01E36A (PRG $00E36A)  testMemory  — Memory test mode (debug). Entry: tests WRAM, VRAM, SRAM access.
$01E37F (PRG $00E37F)  runDiagnostics  — Runs system diagnostics. Entry: tests hardware, reports issues.
$01E4D2 (PRG $00E4D2)  logError  — Logs error to debug buffer. Entry: A=error code, X/Y=context.
$01E50A (PRG $00E50A)  assertCondition  — Asserts condition for debugging. Entry: checks condition, breaks if false.
$01E552 (PRG $00E552)  profileCode  — Code profiler for performance analysis. Entry: measures function execution time.
$01E593 (PRG $00E593)  dumpProfileData  — Dumps profiling results. Entry: shows timing information for functions.
$01E5D4 (PRG $00E5D4)  traceExecution  — Execution tracer for debugging. Entry: logs instruction flow.
$01E602 (PRG $00E602)  dumpTraceLog  — Dumps execution trace log. Entry: shows recent instruction history.
$01E626 (PRG $00E626)  setWatchpoint  — Sets memory watchpoint. Entry: A=address, breaks on read/write.
$01E63B (PRG $00E63B)  clearWatchpoints  — Clears all watchpoints. Entry: disables memory breakpoints.
$01E64C (PRG $00E64C)  singleStep  — Single-step execution (debug). Entry: executes one instruction, pauses.
$01E6CE (PRG $00E6CE)  stepOver  — Step over subroutine (debug). Entry: executes until return from current function.
$01E744 (PRG $00E744)  stepOut  — Step out of subroutine (debug). Entry: executes until return to caller.
$01E75E (PRG $00E75E)  runToAddress  — Run to address (debug). Entry: executes until specified PC.
$01E784 (PRG $00E784)  debugMonitor  — Interactive debug monitor. Entry: command-line interface for debugging.
$01EB0F (PRG $00EB0F)  handleMonitorCommand  — Handles debug monitor commands. Entry: parses and executes debug commands.
$01EB7C (PRG $00EB7C)  monitorHelp  — Displays debug monitor help. Entry: shows available commands.
$01EB81 (PRG $00EB81)  monitorRegisters  — Displays CPU registers in monitor. Entry: shows current register values.
$01EB86 (PRG $00EB86)  monitorMemory  — Displays memory in monitor. Entry: shows memory dump at address.
$01EBE5 (PRG $00EBE5)  monitorDisassemble  — Disassembles code in monitor. Entry: shows assembly at address.
$01EBED (PRG $00EBED)  monitorBreakpoints  — Manages breakpoints in monitor. Entry: lists/sets/clears breakpoints.
$01EBF7 (PRG $00EBF7)  monitorWatchpoints  — Manages watchpoints in monitor. Entry: lists/sets/clears watchpoints.
$01EC12 (PRG $00EC12)  monitorStack  — Displays stack in monitor. Entry: shows stack contents.
$01EC8D (PRG $00EC8D)  monitorFlags  — Displays CPU flags in monitor. Entry: shows status register bits.
$01EC92 (PRG $00EC92)  monitorCallStack  — Displays call stack in monitor. Entry: shows function call hierarchy.
$01ECAC (PRG $00ECAC)  monitorVariables  — Displays game variables in monitor. Entry: shows important RAM values.
$01ECB9 (PRG $00ECB9)  monitorTimers  — Displays timer values in monitor. Entry: shows game timers, counters.
$01ECCC (PRG $00ECCC)  monitorEntities  — Displays entity list in monitor. Entry: shows all active entities.
$01ECD6 (PRG $00ECD6)  monitorInventory  — Displays inventory in monitor. Entry: shows party items.
$01ECE1 (PRG $00ECE1)  monitorParty  — Displays party status in monitor. Entry: shows character stats.
$01ECE5 (PRG $00ECE5)  monitorEvents  — Displays event flags in monitor. Entry: shows story progress flags.
$01ED43 (PRG $00ED43)  monitorMap  — Displays map information in monitor. Entry: shows current map data.
$01ED5E (PRG $00ED5E)  monitorBattle  — Displays battle state in monitor. Entry: shows battle variables.
$01EDFA (PRG $00EDFA)  monitorSound  — Displays sound state in monitor. Entry: shows APU/SPC status.
$01EE1E (PRG $00EE1E)  monitorGraphics  — Displays graphics state in monitor. Entry: shows PPU registers, VRAM info.
$01EE4A (PRG $00EE4A)  monitorInput  — Displays input state in monitor. Entry: shows controller readings.
$01EE6D (PRG $00EE6D)  monitorDMA  — Displays DMA state in monitor. Entry: shows DMA channel configurations.
$01EEC2 (PRG $00EEC2)  monitorIRQ  — Displays interrupt state in monitor. Entry: shows IRQ/NMI status.
$01EEDB (PRG $00EEDB)  monitorSave  — Displays save data in monitor. Entry: shows SRAM contents.
$01EF1F (PRG $00EF1F)  monitorTest  — Test monitor functionality. Entry: runs monitor self-test.
$01EF37 (PRG $00EF37)  monitorExit  — Exits debug monitor. Entry: returns to game execution.
$01EF4A (PRG $00EF4A)  cheatInfiniteHP  — Cheat: infinite HP for party. Entry: toggles HP cheat on/off.
$01EF85 (PRG $00EF85)  cheatInfiniteMP  — Cheat: infinite MP for party. Entry: toggles MP cheat on/off.
$01EFA7 (PRG $00EFA7)  cheatMaxStats  — Cheat: max all stats for party. Entry: sets all characters to max stats.
$01EFAB (PRG $00EFAB)  cheatAllItems  — Cheat: get all items. Entry: fills inventory with all items.
$01F060 (PRG $00F060)  cheatAllMagic  — Cheat: learn all magic. Entry: teaches all spells to party.
$01F0E4 (PRG $00F0E4)  cheatMaxGold  — Cheat: max gold. Entry: sets party gold to maximum.
$01F125 (PRG $00F125)  cheatInstantLevel  — Cheat: instant level up. Entry: levels up selected character.
$01F12A (PRG $00F12A)  cheatNoEncounters  — Cheat: no random encounters. Entry: toggles encounters on/off.
$01F17E (PRG $00F17E)  cheatWalkThroughWalls  — Cheat: walk through walls. Entry: toggles collision on/off.
$01F18B (PRG $00F18B)  cheatFastBattle  — Cheat: fast battle (instant win). Entry: toggles instant battle victory.
$01F1D6 (PRG $00F1D6)  cheatAllKeys  — Cheat: all key items. Entry: gives all key plot items.
$01F1FC (PRG $00F1FC)  cheatTeleport  — Cheat: teleport to map. Entry: A=map ID, teleports party.
$01F200 (PRG $00F200)  cheatWeather  — Cheat: change weather. Entry: A=weather type, sets current weather.
$01F23E (PRG $00F23E)  cheatTimeOfDay  — Cheat: set time of day. Entry: A=time (0=day, 1=night, 2=dawn, 3=dusk).
$01F262 (PRG $00F262)  cheatUnlockAll  — Cheat: unlock all content. Entry: opens all areas, quests, features.
$01F28C (PRG $00F28C)  cheatDebugMode  — Cheat: enable debug mode. Entry: toggles full debug features.
$01F2BF (PRG $00F2BF)  testCombat  — Combat test routine. Entry: runs automated battle tests.
$01F30D (PRG $00F30D)  testAI  — AI test routine. Entry: runs AI behavior tests.
$01F33C (PRG $00F33C)  testPathfinding  — Pathfinding test routine. Entry: tests movement algorithms.
$01F362 (PRG $00F362)  testCollision  — Collision test routine. Entry: tests collision detection.
$01F388 (PRG $00F388)  testGraphicsRendering  — Graphics rendering test. Entry: tests tile, sprite rendering.
$01F3A0 (PRG $00F3A0)  testSoundPlayback  — Sound playback test. Entry: tests all sound channels.
$01F3F6 (PRG $00F3F6)  testMemoryAllocation  — Memory allocation test. Entry: tests heap/stack operations.
$01F402 (PRG $00F402)  testAnimationSystem  — Tests animation system functionality. Entry: runs animation tests.
$01F41C (PRG $00F41C)  testEffectSystem  — Tests visual effect system. Entry: runs effect rendering tests.
$01F431 (PRG $00F431)  testAudioSystem  — Tests audio system functionality. Entry: runs sound playback tests.
$01F43C (PRG $00F43C)  testFileIO  — File I/O test (SRAM). Entry: tests save/load operations.
$01F44B (PRG $00F44B)  testInputSystem  — Tests input system functionality. Entry: runs controller reading tests.
$01F45E (PRG $00F45E)  testMemorySystem  — Tests memory system functionality. Entry: runs RAM/ROM access tests.
$01F47F (PRG $00F47F)  testInputProcessing  — Input processing test. Entry: tests controller reading.
$01F4C4 (PRG $00F4C4)  testGraphicsSystem  — Tests graphics system functionality. Entry: runs tile/sprite rendering tests.
$01F544 (PRG $00F544)  testGameLogic  — Tests game logic systems. Entry: runs battle, menu, entity tests.
$01F582 (PRG $00F582)  testSaveSystem  — Tests save system functionality. Entry: runs save/load operation tests.
$01F5DE (PRG $00F5DE)  testNetwork  — Tests network functionality (if any). Entry: runs communication tests.
$01F63B (PRG $00F63B)  testHardware  — Tests hardware functionality. Entry: runs PPU, APU, DMA tests.
$01F6C9 (PRG $00F6C9)  runAllTests  — Runs all diagnostic tests. Entry: comprehensive system test suite.
$01F6D5 (PRG $00F6D5)  generateTestReport  — Generates test results report. Entry: summarizes test outcomes.
$01F6E7 (PRG $00F6E7)  logTestFailure  — Logs test failure details. Entry: records failed test information.
$01F6EE (PRG $00F6EE)  resetTestState  — Resets test state between tests. Entry: clears test variables.
$01F785 (PRG $00F785)  benchmarkPerformance  — Runs performance benchmarks. Entry: measures frame rate, memory speed.
$01F942 (PRG $00F942)  stressTestSystem  — Runs stress tests on systems. Entry: pushes systems to limits.
$01FCDD (PRG $00FCDD)  validateGameData  — Validates game data integrity. Entry: checks ROM data structures.
$01FE8B (PRG $00FE8B)  eventCmd3B_debugEnable  — Event command 0x3B handler - INC $0A87
$01FF06 (PRG $00FF06)  finalizeTests  — Finalizes test suite execution. Entry: cleans up test environment.
$01FF0E (PRG $00FF0E)  exitTestMode  — Exits test mode returns to game. Entry: restores normal game state.
$01FF16 (PRG $00FF16)  emergencyReset  — Emergency reset handler. Entry: called on critical errors, soft resets.
$01FF1F (PRG $00FF1F)  panicHandler  — Panic handler for unrecoverable errors. Entry: displays error code, halts.

## AI (8 labels)

$009556 (PRG $001556)  processEnemyAI  — Processes enemy AI logic for battle. Entry: reads enemy data from $7EEA8C, processes AI scripts from ROM table $0BE579.
$009634 (PRG $001634)  processEnemyAIData  — Processes enemy AI script data from ROM table $0BE579. Entry: X=AI data index, Y=direction (2=forward, else backward).
$009E81 (PRG $001E81)  processBattleTurn  — Processes one battle turn for a unit. Entry: A=unit ID. Handles AI for enemies, input for player, executes actions.
$00AA2F (PRG $002A2F)  processAIscript  — Processes AI script for enemy behavior. Entry: A=enemy ID. Reads script from ROM, executes commands.
$00B0A8 (PRG $0030A8)  updateTurnOrder  — Updates battle turn order based on agility. Entry: sorts unit list by speed, determines next actor.
$00CF6B (PRG $004F6B)  updateEntityAI  — Updates AI for all entities. Entry: calls entity-specific AI routines based on type.
$2BE1BD (PRG $15E1BD)  externalPathfindingFunc  — External pathfinding algorithm function. Entry: A* or similar pathfinding.
$2BE1D8 (PRG $15E1D8)  externalAIFunc  — External AI decision function. Entry: complex AI decision making.

## Unused (1 labels)

$01FF43 (PRG $00FF43)  unusedFunction  — Unused function - appears to be dead code. Entry: never called in normal gameplay.

## None (55 labels)

$0080F0 (PRG $0000F0)  TEST  — Testing functions
$0080F1 (PRG $0000F1)  CONTROL  — I/O and Timer Control
$0080F2 (PRG $0000F2)  DSPADDR  — DSP Address
$0080F3 (PRG $0000F3)  DSPDATA  — DSP Data
$0080F4 (PRG $0000F4)  CPUIO0  — CPU I/O 0
$0080F5 (PRG $0000F5)  CPUIO1  — CPU I/O 1
$0080F6 (PRG $0000F6)  CPUIO2  — CPU I/O 2
$0080F7 (PRG $0000F7)  CPUIO3  — CPU I/O 3
$0080F8 (PRG $0000F8)  RAMREG1  — Memory Register 1
$0080F9 (PRG $0000F9)  RAMREG2  — Memory Register 2
$0080FA (PRG $0000FA)  T0TARGET  — Timer 0 scaling target
$0080FB (PRG $0000FB)  T1TARGET  — Timer 1 scaling target
$0080FC (PRG $0000FC)  T2TARGET  — Timer 2 scaling target
$0080FD (PRG $0000FD)  T0OUT  — Timer 0 output
$0080FE (PRG $0000FE)  T1OUT  — Timer 1 output
$0080FF (PRG $0000FF)  T2OUT  — Timer 2 output
$008859 (PRG $000859)  drawTitleLogo  — Draws title screen logo graphics to VRAM. Entry: loads logo tiles and palette.
$0089FC (PRG $0009FC)  textCurrentColumn  — Current column position for text rendering (0-15). Updated by processText as characters are written. Reset by clearTextBuffer.
$0089FE (PRG $0009FE)  textCurrentRow  — Current row position for text rendering (0-1). Updated by newline ($90) control code. Reset by clearTextBuffer.
$008A00 (PRG $000A00)  textLineWidth  — Line width for text rendering (typically 16). Used by calculateBufferOffset to compute buffer position.
$008A02 (PRG $000A02)  textPriorityPalette  — Priority and palette bits added to tile numbers. Set by setTextColor. Format: VHPPCCCC where V=vertical flip, H=horizontal flip, P=priority, CCCC=palette (0-15).
$008A0A (PRG $000A0A)  textExtendedVariable  — Extended control code variable. Set by $FD control code. Used for parameter passing in text scripts.
$008A16 (PRG $000A16)  textExtendedCounter  — Extended control code counter. Incremented by $FA control code. Used for conditional text rendering.
$008A1C (PRG $000A1C)  textSpecialMode1  — Special rendering mode flag 1. Checked by writeTextCharacter for alternate character handling.
$008A1E (PRG $000A1E)  textSpecialMode2  — Special rendering mode flag 2. Checked by writeTextCharacter for alternate character handling.
$0183E4 (PRG $0083E4)  sub_0083E4
$019000 (PRG $009000)  textTileBufferTop  — Top tile buffer (64 bytes, 32 entries × 2 bytes). Holds 16×2 tile area for text rendering. Each entry: tile# low + VHPPCCCC attributes. Transferred to VRAM during V-blank.
$019040 (PRG $009040)  textTileBufferBottom  — Bottom tile buffer (64 bytes, 32 entries × 2 bytes). Holds 16×2 tile area for text rendering. Each entry: tile# low + VHPPCCCC attributes with +$0400 palette difference from top buffer. Transferred to VRAM during V-blank.
$0198A0 (PRG $0098A0)  sub_0098A0
$019EFD (PRG $009EFD)  sub_009EFD
$01A6A5 (PRG $00A6A5)  sub_00A6A5
$01A6B8 (PRG $00A6B8)  sub_00A6B8
$01A6D7 (PRG $00A6D7)  sub_00A6D7
$01A97C (PRG $00A97C)  sub_00A97C
$01AE1F (PRG $00AE1F)  sub_00AE1F
$01B04F (PRG $00B04F)  sub_00B04F
$01C62D (PRG $00C62D)  drawBackgroundPattern  — Draws background pattern (checker, gradient). Entry: A=pattern type, fills area.
$01DB5B (PRG $00DB5B)  sub_00DB5B
$01DB8F (PRG $00DB8F)  sub_00DB8F
$01DE49 (PRG $00DE49)  sub_00DE49
$01E7A1 (PRG $00E7A1)  sub_00E7A1
$01E7C8 (PRG $00E7C8)  sub_00E7C8
$01E822 (PRG $00E822)  sub_00E822
$01E8BE (PRG $00E8BE)  sub_00E8BE
$01E8E9 (PRG $00E8E9)  sub_00E8E9
$01ED4F (PRG $00ED4F)  sub_00ED4F
$01F2F8 (PRG $00F2F8)  sub_00F2F8
$01F3FA (PRG $00F3FA)  sub_00F3FA
$01F406 (PRG $00F406)  sub_00F406
$01F6AD (PRG $00F6AD)  sub_00F6AD
$298001 (PRG $148001)  sub_148001
$2BDDE2 (PRG $15DDE2)  externalGraphicsFunc1  — External graphics function 1. Entry: advanced graphics operations.
$2BDDF7 (PRG $15DDF7)  externalGraphicsFunc2  — External graphics function 2. Entry: additional graphics operations.
$3FD1CE (PRG $1FD1CE)  sub_1FD1CE
$3FF606 (PRG $1FF606)  sub_1FF606

