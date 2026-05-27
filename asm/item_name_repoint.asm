; item_name_repoint.asm — route all item-name rendering at the relocated
; 24-byte item-name table (item-names.toml @ $C4:C920) so item names can be
; longer than the cramped 9-byte in-record field. See
; Plans/equipment-name-expansion.md, Phase 3.
;
; Items render two ways:
;   (1) DESCRIPTION screens — 7 direct FF88 copiers, ptr $02:A4E0,
;       $0A08 = itemID*0x18. Mirror of the equipment path: repoint base ->
;       $C4:C920 (same 0x18 stride, name@+0), count 0x0A -> 0x18.
;   (2) SHOP LIST — sub_00DE49 ($01:DE49) copies the 24-byte record
;       $02:A4E0+ID*0x18 into WRAM $0E80, then FF88 @ $02:C81E copies the name
;       from $0E80 ($0A08=0). $0E80's stat bytes are still read, so the name
;       can't widen in place. We tail-hijack sub_00DE49 to ALSO stage the full
;       name from $C4:C920+ID*0x18 into a free WRAM scratch ($7E:0740, verified
;       idle via SplitTrace), and repoint $02:C81E to read from there.
;
; $C4:C920 as a 3-byte LE pointer = 20 C9 C4 ; $00:0740 = 40 07 00.

lorom

; ============================================================================
; (1) 7 direct description FF88 sites: count @ PC+2, ptr @ PC+3 -> $C4:C920
; ============================================================================
org $02CEA9
db $18, $20,$C9,$C4
org $02CF05
db $18, $20,$C9,$C4
org $02CF3F
db $18, $20,$C9,$C4
org $02CF91
db $18, $20,$C9,$C4
org $02DD4F
db $18, $20,$C9,$C4
org $02DD87
db $18, $20,$C9,$C4
org $02E342
db $18, $20,$C9,$C4

; ============================================================================
; (2a) Shop-list FF88 @ $02:C81E — count @ $02:C820, ptr @ $02:C821.
;      Repoint from $00:0E80 (9-byte buffer name) to $00:0740 (full-name
;      scratch staged by the sub_00DE49 hijack below); count 0x0A -> 0x18.
; ============================================================================
org $02C820
db $18, $40,$07,$00

; ============================================================================
; (2b) sub_00DE49 ENTRY hijack. Original entry at $01:DE49:
;        C2 20      REP #$20
;        29 7F 00   AND #$007F          ; A = item ID
;      (then PHA; ASL×3; ... copies the 24-byte record into $0E80)
;      Replace those 5 bytes with `JSL stager : NOP`. At entry only the
;      caller's JSR return is on the stack (clean — no pending PHY), so the
;      JSL is safe. The stager replicates REP #$20 / AND #$007F (leaving A =
;      ID, M=0 for the rest of the function), stages the full item name into
;      the $0740 scratch, restores A/X/Y, and RTLs into the kept continuation
;      at $01:DE4E (the original PHA).
; ============================================================================
org $01DE49
    JSL item_shop_name_stage
    NOP                              ; pad to 5 bytes (was REP #$20 / AND #$007F)

; ----------------------------------------------------------------------------
; Stager in bank $C4 freespace (PC 0x227000; past the name tables which end at
; 0x225520, below the FFC0 freespace at 0x230200). Entry: A = item ID (low
; byte), 16-bit X/Y (sub_00DE49 requires it), DBR=$00, caller+JSL returns on
; stack. Leaves A = ID (16-bit, masked), M=0, X/Y unchanged for the kept
; continuation at $01:DE4E.
; ----------------------------------------------------------------------------
org $C4F000
item_shop_name_stage:
    REP #$20                         ; replicate original (A 16-bit, M=0)
    AND.w #$007F                     ; replicate original (A = item ID)
    PHA                              ; save ID (for continuation's PHA + our math)
    PHX
    PHY
    ASL                              ; ID*2
    ASL                              ; ID*4
    ASL                              ; ID*8
    STA.b $00
    ASL                              ; ID*16
    CLC
    ADC.b $00                        ; ID*24 = ID*0x18
    TAX                              ; X = source offset into $C4:C920
    LDY.w #$0000
.copy:
    LDA.l $C4C920,X                  ; relocated item-name table
    STA.w $0740,Y                    ; -> $00:0740 scratch (DBR=$00 -> $7E:0740)
    INX
    INX
    INY
    INY
    CPY.w #$0018                     ; 24 bytes
    BNE .copy
    PLY
    PLX
    PLA                              ; A = item ID (16-bit, masked) for continuation
    RTL
