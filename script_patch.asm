; ============================================================================
; Little Master 3 - Script Patch
; ============================================================================
; Enables the 3-byte pointer dispatch so the main script in bank $C1 works.
; Applied during build_scripted, before the VWF patch.
; ============================================================================

lorom

; ============================================================================
; TextPtrDispatch - replaces 2-byte pointer lookup with 3-byte for expanded ROM
; Called via JSL from $81:EE67 (patched below).
; Entry: A = script entry index (16-bit, low byte valid), $14 = ptr table base,
;        $16 = bank byte (if >= $C0 → 3-byte table; else → original 2-byte table).
; Exit:  $14/$16 updated to point at the actual text. A = entry index restored.
; ============================================================================
; Placed in the kanji glyph area (PC $20000 = $04:$8000).
; This is within the original 2 MB ROM, so every emulator maps it correctly.
; Bank $C0+ lives in the expanded region and may not be mapped for code
; execution under plain LoROM map-mode $20.
org $048000

TextPtrDispatch:
    PHP                          ; save P flags
    REP #$30                     ; 16-bit A, X, Y
    PHA                          ; save entry index

    SEP #$20                     ; 8-bit A for bank byte check
    LDA.B $16
    CMP.B #$C0                   ; bank >= $C0 → expanded area, 3-byte ptrs
    REP #$20
    BCC .twoBytePtr              ; branch if bank < $C0

.threeBytePtr:
    PLA                          ; pop entry index
    AND.W #$00FF
    PHA                          ; push copy for stack-relative add
    ASL A                        ; × 2
    CLC : ADC 1,S                ; + index from stack = × 3 (no temp register needed)
    PLX                          ; discard pushed copy (stack balance)
    TAY                          ; Y = entry_index × 3
    LDA.B [$14],Y                ; load 2-byte addr (bytes 0+1 of 3-byte entry)
    TAX                          ; save addr in X
    SEP #$20
    INY : INY                    ; advance to byte 2 (bank byte)
    LDA.B [$14],Y                ; read bank byte
    STA.B $16                    ; update bank for text access
    REP #$20
    TXA                          ; restore text address
    STA.B $14                    ; set $14 = text address
    PLP
    RTL

.twoBytePtr:
    PLA                          ; pop entry index
    AND.W #$00FF
    ASL A                        ; × 2
    TAY
    LDA.B [$14],Y                ; load 2-byte pointer
    STA.B $14
    PLP
    RTL

; ============================================================================
; Game code patch: $81:EE67 — replace 2-byte ptr lookup with dispatch
; Original 6 bytes: ASL A / TAY / LDA.B [$14],Y / STA.B $14
; JSL target is $04:8000 (kanji area, within original 2 MB ROM).
; ============================================================================
org $81EE67
    JSL.L TextPtrDispatch        ; 4 bytes  → 22 00 80 04
    NOP : NOP                    ; 2 bytes pad

; ============================================================================
; Meta-table patches — redirect main script pointers to $C1 (3-byte table).
;
; The meta-table at $82:$8000 has 20 entries (4 bytes each).  The main script
; appears TWICE: entries 3/4 AND entries 16/17.  The game uses entries 16/17
; (hi=$10/$11) at runtime, so ALL four must be patched.
;
;   Entry  3 ($82:$800C): hi=$03, entries 0-255   → $C1:$8000
;   Entry  4 ($82:$8010): hi=$04, entries 256-511 → $C1:$8300
;   Entry 16 ($82:$8040): hi=$10, entries 0-255   → $C1:$8000  (duplicate)
;   Entry 17 ($82:$8044): hi=$11, entries 256-511 → $C1:$8300  (duplicate)
; ============================================================================
org $82800C
    db $00, $80, $C1, $00   ; entry  3: was 00 80 36 00

org $828010
    db $00, $83, $C1, $00   ; entry  4: was 00 82 36 00

org $828040
    db $00, $80, $C1, $00   ; entry 16: was 00 80 36 00

org $828044
    db $00, $83, $C1, $00   ; entry 17: was 00 82 36 00

; quiz-text: relocated from $06:$8800 to $C2:$9700 (3-byte ptrs).
; unit-terrain-desc data (27 KB) overflowed into quiz-text's original location.
org $82803C
    db $00, $97, $C2, $00   ; entry 15: was 00 88 06 00

; scenario-desc: relocated from $22:$9EE3 to $C3:$8000 (3-byte ptrs).
; EN text (10840 bytes) overflows JP space (6732 bytes) into adjacent ptr tables.
; Entries 11 and 12 are sub-views into scenario-desc's ptr table (at indices 59/131).
org $828008
    db $00, $80, $C3, $00   ; entry  2: was E3 9E 22 00
org $82802C
    db $B1, $80, $C3, $00   ; entry 11: was 59 9F 22 00 (idx 59 = byte 0xB1)
org $828030
    db $89, $81, $C3, $00   ; entry 12: was E9 9F 22 00 (idx 131 = byte 0x189)

; ============================================================================
; Unit Name Expansion — relocate 8-byte names to 16-byte entries in bank $C4.
; ============================================================================
; Original unit name table: $02:A050, 146 entries × 8 bytes, $20-padded.
;   Entries 0–72 = first names, entries 73–145 = surnames.
; Two copy functions read from this table:
;   copyUnitFirstName ($00:B90F): 3×ASL (×8), base $02:A050
;   copyUnitSurname   ($00:B923): 3×ASL (×8), base $02:A298 ($A050 + 73*8)
; Both share a copy loop that stops at $20 (space padding).
;
; Expanded table: $C4:8000, 146 entries × 16 bytes, $20-padded.
;   First names: base $C4:8000
;   Surnames:    base $C4:8490 ($8000 + 73*16)
; Multiply changed from ×8 (3×ASL) to ×16 (4×ASL).
; ============================================================================

; --- Redirect original functions to expanded versions in kanji area ---
; copyUnitFirstName ($80:B90F): 22 bytes ($B90F-$B924, ends with BRA to shared tail)
; Callers: JSR $B90F at $80:B8F4, $80:B909
org $80B90F
    JSL.L ExpandedCopyFirstName   ; 4 bytes
    RTS                           ; 1 byte
    NOP : NOP : NOP : NOP : NOP  ; 5 bytes padding
    NOP : NOP : NOP : NOP : NOP  ; 5 bytes padding
    NOP : NOP : NOP : NOP : NOP  ; 5 bytes padding
    NOP : NOP                     ; 2 bytes padding (covers BRA at $B923-$B924)

; copyUnitSurname ($80:B925) + shared copy tail ($B939-$B949): 37 bytes total
; Caller: JSR $B925 at $80:B8FE
org $80B925
    JSL.L ExpandedCopySurname     ; 4 bytes
    RTS                           ; 1 byte
    NOP : NOP : NOP : NOP : NOP  ; 5 bytes padding
    NOP : NOP : NOP : NOP : NOP  ; 5 bytes padding
    NOP : NOP : NOP : NOP : NOP  ; 5 bytes padding
    NOP : NOP : NOP : NOP : NOP  ; 5 bytes padding
    NOP : NOP : NOP : NOP : NOP  ; 5 bytes padding
    NOP : NOP : NOP : NOP : NOP  ; 5 bytes padding
    NOP : NOP                     ; 2 bytes padding (total: 37 bytes)

; --- New expanded functions in kanji glyph area (safe — font relocated to $170000) ---
org $04803E

ExpandedCopyFirstName:
    PHY
    REP #$20
    AND.W #$00FF
    ASL A : ASL A : ASL A : ASL A  ; ×16
    TAY
    LDA.W #$00C4                    ; bank $C4
    STA.B $02
    LDA.W #$8000                    ; first name base
    STA.B $00
    BRA ExpandedCopyLoop

ExpandedCopySurname:
    PHY
    REP #$20
    AND.W #$00FF
    ASL A : ASL A : ASL A : ASL A  ; ×16
    TAY
    LDA.W #$00C4                    ; bank $C4
    STA.B $02
    LDA.W #$8490                    ; surname base ($8000 + 73*16)
    STA.B $00

ExpandedCopyLoop:
    SEP #$20
ExpandedCopyByte:
    LDA.B [$00],Y
    INY
    CMP.B #$20                      ; stop at space padding
    BEQ ExpandedCopyDone
    STA.W $0400,X
    INX
    BRA ExpandedCopyByte
ExpandedCopyDone:
    PLY
    RTL
