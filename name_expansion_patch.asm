; ============================================================================
; Unit Name Expansion — relocate 8-byte names to 16-byte entries in bank $C4.
; ============================================================================
; Original unit name table: $02:A050, 146 entries × 8 bytes, $20-padded.
;   Entries 0–72 = first names, entries 73–145 = surnames.
; Two copy functions read from this table:
;   copyUnitFirstName ($00:B90F): 3×ASL (×8), base $02:A050
;   copyUnitSurname   ($00:B925): 3×ASL (×8), base $02:A298 ($A050 + 73*8)
; Both share a copy loop that stops at $20 (space padding).
;
; Expanded table: $C4:8000, 146 entries × 16 bytes, $20-padded.
;   First names: base $C4:8000
;   Surnames:    base $C4:8490 ($8000 + 73*16)
; Multiply changed from ×8 (3×ASL) to ×16 (4×ASL).
;
; Requires: ROM padded to 4 MB, expanded name data at PC $220000 (bank $C4).
; ============================================================================

lorom

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
