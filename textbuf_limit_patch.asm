; ============================================================================
; Text Buffer Hard Limit Patch
; ============================================================================
; Adds a hard limit on the number of bytes that can be written to the $0400
; text buffer during the text fill loop at $80:B68D.
;
; When X (buffer offset) reaches the limit, the text fill loop is forced to
; end as if a null terminator was encountered.  This prevents overflow into
; game variables at $05F5+ and keeps the rendering pipeline from crashing.
;
; The limit is defined by TEXTBUF_LIMIT below.  With the default $01F0 (496),
; the buffer spans $0400–$05EF, safely below $05F5.
; ============================================================================

lorom

; --------------- configurable limit -----------------------------------------
!TEXTBUF_LIMIT = $01F0      ; max X offset (496 bytes → buffer $0400–$05EF)

; --------------- hook at text loop entry ------------------------------------
; Original 7 bytes at $80:B68D:
;   B7 14        LDA [$14],Y
;   D0 03        BNE $B694
;   4C B8 BB     JMP $BBB8      (end-of-text handler)
;
; Replaced with JSL to our check routine + 3 NOP pad.
; On return (Z=0): execution falls through to $B694 (CMP #$09).
; If limit hit or null byte: check routine discards its own return address
; and JMPs directly to the end-of-text handler at $BBB8.
org $80B68D
    JSL textbuf_check       ; 4 bytes
    NOP : NOP : NOP         ; 3 bytes pad

; --------------- check routine in free space --------------------------------
; 36 bytes available at $80:F7A7 (all $FF in original ROM).  Routine is 16 b.
org $80F7A7

textbuf_check:
    CPX.W #!TEXTBUF_LIMIT   ; 3  has buffer reached the limit?
    BCS .force_end           ; 2  yes → terminate text
    LDA [$14],Y              ; 2  load next source text byte
    BNE .ok                  ; 2  non-zero → return to caller
.force_end:
    PLA                      ; 1  \
    PLA                      ; 1   } discard 3-byte JSL return address
    PLA                      ; 1  /  (A is 8-bit here, so PLA pulls 1 byte)
    JMP $BBB8                ; 3  jump to end-of-text handler
.ok:
    RTL                      ; 1  return with A=byte, Z=0
; total = 16 bytes
