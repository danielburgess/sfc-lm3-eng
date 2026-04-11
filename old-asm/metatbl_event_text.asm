; ============================================================================
; Meta-table redirect: event-text ptr table → $22:$9EE3
; ============================================================================
; Ptr table relocated from $22:BA9B to $22:9EE3 (reusing freed scenario-desc
; space).  Script meta-table at $0A:$8000, entry 0.
; ============================================================================

lorom

org $0A8000
    db $E3, $9E, $22, $00   ; entry 0: was 9B BA 22 00
