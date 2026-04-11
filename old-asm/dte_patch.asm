; ============================================================================
; Little Master 3 - DTE (Dual Table Encoding) Patch
; ============================================================================
; Hooks the per-character text renderer to intercept DTE trigger codes:
;   FF F7 [INDEX] = redirect to DTE table 1 expansion string
;   FF F8 [INDEX] = redirect to DTE table 2 expansion string
;   FF F6         = return from DTE expansion to inline text
;
; DTE pointer tables are 2-byte within-bank pointers:
;   Table 1: $C6:$8000 (pointers), expansion text follows in bank $C6
;   Table 2: $C6:$C000 (pointers), expansion text follows in bank $C6
;
; Text pointer is $14/$15 (16-bit addr) + $16 (bank byte).
; Y register is the current read offset within the text stream.
; Save/restore area: $7F:FFF0-$7F:FFF4 (single level, no nesting).
; ============================================================================

lorom

; ============================================================================
; Hook point: $80:B698
; Original: CMP #$FF / BEQ $B6D6  (C9 FF F0 3A — 4 bytes)
; Replace with: JSL DTE_Hook       (22 xx xx xx — 4 bytes, exact fit)
;
; At entry the current text byte is in A (8-bit). Y = read offset.
; After JSL, if it was a normal character (not FF), we need to fall
; through to the STA $0400,X / INX at $80:B69C.
; If it was FF (control code), we need to reach the handler at $80:B6D6.
; ============================================================================
org $80B698
    JSL.L DTE_Hook

; ============================================================================
; DTE_Hook — intercept FF bytes and dispatch DTE codes
; ============================================================================
; Placed after TextPtrDispatch in the free area at bank $2E.
;
; Stack after JSL from $80:B698:
;   S+1 = PCL ($9B), S+2 = PCH ($B6), S+3 = PBR ($80)
;   Default return: $80:B69C (normal char: STA $0400,X / INX)
;
; Flow:
;   A != FF → RTL back to $80:B69C (normal character path)
;   A == FF → peek at sub-opcode:
;     F6 → DTE return
;     F7 → DTE table 1 entry
;     F8 → DTE table 2 entry
;     else → redirect return to $80:B6D6 (original FF handler)
; ============================================================================
org $2EAA90

DTE_Hook:
    CMP #$FF
    BEQ .isFF
    ; Not FF — normal text character. Return to $80:B69C.
    RTL

.isFF:
    ; Peek at the sub-opcode (next byte after FF)
    INY
    LDA [$14],Y
    DEY                         ; restore Y to FF position

    ; Check for DTE codes (F6 first — shortest code path)
    CMP #$F6
    BEQ .dteReturn
    CMP #$F7
    BEQ .dteEntry1
    CMP #$F8
    BEQ .dteEntry2

    ; --- Not a DTE code: forward to original FF handler at $80:B6D6 ---
    ; Change return address on stack from $B69B to $B6D5 (RTL adds 1 → $B6D6)
    REP #$20
    LDA #$B6D5
    STA $01,S
    SEP #$20
    LDA #$FF                    ; restore A = $FF for the handler
    RTL

; --- DTE Return (FF F6) — restore saved pointer and resume inline text ---
.dteReturn:
    ; Restore the original text pointer
    LDA.L $7FFFF0
    STA $14
    LDA.L $7FFFF1
    STA $15
    LDA.L $7FFFF2
    STA $16
    ; Restore Y (saved as position past FF F7/F8 INDEX)
    REP #$20
    LDA.L $7FFFF3
    TAY
    ; Redirect return to $80:B68D (text loop top)
    LDA #$B68C
    STA $01,S
    SEP #$20
    RTL

; --- DTE Table 1 Entry (FF F7 INDEX) ---
.dteEntry1:
    JSR .dteSaveContext          ; save $14-$16 and Y+3
    ; Read INDEX byte (at Y+2 from current FF position)
    INY : INY
    SEP #$20
    LDA [$14],Y
    ; Look up pointer in table 1 at $C6:$8000
    REP #$20
    AND #$00FF
    ASL A                       ; INDEX * 2
    TAX                         ; X = pointer table offset
    LDA.L $C68000,X             ; read 2-byte pointer from DTE table 1
    STA $14
    SEP #$20
    LDA #$C6
    STA $16                     ; bank = $C6
    LDY #$0000                  ; start reading expansion string at offset 0
    ; Redirect return to text loop top
    REP #$20
    LDA #$B68C
    STA $01,S
    SEP #$20
    RTL

; --- DTE Table 2 Entry (FF F8 INDEX) ---
.dteEntry2:
    JSR .dteSaveContext
    INY : INY
    SEP #$20
    LDA [$14],Y
    REP #$20
    AND #$00FF
    ASL A
    TAX
    LDA.L $C6C000,X             ; read 2-byte pointer from DTE table 2
    STA $14
    SEP #$20
    LDA #$C6
    STA $16
    LDY #$0000
    REP #$20
    LDA #$B68C
    STA $01,S
    SEP #$20
    RTL

; --- Shared: save text pointer + Y to $7F:FFF0-FFF4 ---
; Called via JSR. Expects 16-bit mode on entry (A is 16-bit from caller).
; Leaves in REP #$20 (16-bit A) state.
.dteSaveContext:
    SEP #$20                    ; 8-bit for byte-sized DP reads
    LDA $14
    STA.L $7FFFF0
    LDA $15
    STA.L $7FFFF1
    LDA $16
    STA.L $7FFFF2
    ; Save Y+3 (return position: past FF + sub-opcode + INDEX)
    REP #$20
    TYA
    CLC
    ADC #$0003
    STA.L $7FFFF3
    RTS
