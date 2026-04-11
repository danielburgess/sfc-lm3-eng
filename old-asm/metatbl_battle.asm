; ============================================================================
; Meta-table redirect: entry-0 (battle tables) → $C5:$8000 (3-byte pointers)
; ============================================================================
; All 200 sub-entries (raw strings + battle-menu + battle-text + battle-msg)
; relocated wholesale to bank $C5.
; ============================================================================

lorom

org $828000
    db $00, $80, $C5, $00   ; entry  0: was E0 B0 02 00
