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
; Placed in a zero-filled gap in bank $2E (PC $172A54 = $2E:$AA54).
; Bank $04:$8000 was used previously but that overwrites kanji glyph tiles
; needed by the file-info screen and other JP text displays.
org $2EAA54

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
; Meta-table redirects are in a separate file: metatbl_patch.asm
; Only applied during full builds (requires expanded ROM with data in $C1+).
;
; Unit Name Expansion is in a separate file: name_expansion_patch.asm
; Only applied during full builds (requires 4 MB ROM + bank $C4 name data).
; ============================================================================
