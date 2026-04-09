; ============================================================================
; Little Master 3 - Meta-Table Redirects
; ============================================================================
; Redirects the text meta-table entries to expanded ROM banks ($C1/$C2/$C3).
; Only applied during full builds where relocated script data exists.
; ============================================================================

lorom

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
; entry-0 (file-info + battle): relocated to $C5:$8000 (3-byte ptrs).
; EN battle text overwrites entry 0's own strings at $02:B2CA-B49E when packed
; sequentially.  All 200 sub-entries relocated wholesale to bank $C5.
org $828000
    db $00, $80, $C5, $00   ; entry  0: was E0 B0 02 00

org $828008
    db $00, $80, $C3, $00   ; entry  2: was E3 9E 22 00
org $82802C
    db $B1, $80, $C3, $00   ; entry 11: was 59 9F 22 00 (idx 59 = byte 0xB1)
org $828030
    db $89, $81, $C3, $00   ; entry 12: was E9 9F 22 00 (idx 131 = byte 0x189)
