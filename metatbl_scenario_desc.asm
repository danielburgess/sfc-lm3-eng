; ============================================================================
; Meta-table redirect: scenario-desc → $C3 (2-byte pointers, bank $C3)
; ============================================================================
; Entry 2 = main scenario-desc ptr table.
; Entries 11/12 = sub-views into scenario-desc (indices 59 and 131).
; JP uses 2-byte pointers (16-bit addresses within the bank).
; ============================================================================

lorom

org $828008
    db $00, $80, $C3, $00   ; entry  2: was E3 9E 22 00

org $82802C
    db $76, $80, $C3, $00   ; entry 11: was 59 9F 22 00 (idx 59 × 2 = $76)

org $828030
    db $06, $81, $C3, $00   ; entry 12: was E9 9F 22 00 (idx 131 × 2 = $106)
