; ============================================================================
; Meta-table redirect: scenario-desc → $C3 (3-byte pointers)
; ============================================================================
; Entry 2 = main scenario-desc ptr table.
; Entries 11/12 = sub-views into scenario-desc (indices 59 and 131).
; ============================================================================

lorom

org $828008
    db $00, $80, $C3, $00   ; entry  2: was E3 9E 22 00

org $82802C
    db $B1, $80, $C3, $00   ; entry 11: was 59 9F 22 00 (idx 59 = byte 0xB1)

org $828030
    db $89, $81, $C3, $00   ; entry 12: was E9 9F 22 00 (idx 131 = byte 0x189)
