; ============================================================================
; Little Master 3 - Debug Mode Patch
; ============================================================================
; Enables built-in debug mode by keeping WRAM $0A87 non-zero permanently.
;
; The game clears $0A87 in 5 places (STZ $0A87 = 9C 87 0A):
;   $80:E24A — hardware init (patched to INC to set flag = 1)
;   $80:D3D4 — game state reset (NOPed)
;   $81:A83B — scene init (NOPed)
;   $81:F74A — event dispatcher entry (NOPed)
;   $81:F755 — event dispatcher no-script path (NOPed)
;
; The only INC $0A87 in the original game is at $81:FE94 (event command 0x3B).
; By NOPing all clears and setting the flag at init, debug mode stays active.
;
; Debug features: scenario/level select, variable inspection, etc.
; ============================================================================

lorom

; --- Set debug flag at hardware init ---
org $80E24A
    INC.W $0A87          ; was STZ $0A87 — set debug flag = 1 at boot

; --- Prevent game from clearing the debug flag ---
org $80D3D4
    NOP : NOP : NOP      ; was STZ $0A87 — game state reset

org $81A83B
    NOP : NOP : NOP      ; was STZ $0A87 — scene init

org $81F74A
    NOP : NOP : NOP      ; was STZ $0A87 — event dispatcher entry

org $81F755
    NOP : NOP : NOP      ; was STZ $0A87 — event dispatcher no-script path
