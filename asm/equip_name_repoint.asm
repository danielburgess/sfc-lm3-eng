; equip_name_repoint.asm — point the equipment-name FF88 copiers at the
; relocated 24-byte name tables in bank $C4.
;
; Equipment weapon/armor names render through the FF88 "copy N bytes from
; inline pointer + $0A08 offset" control code (handler textRawCopyHandler
; $00:B985). The two operands live in combat-bytecode-2 entry 53 (an empty/
; preserved EN entry, so these ROM bytes are stable across builds):
;
;   ROM 0x1457D: FF 88 0A 52 80 02   ; weapon: copy 10 B from $02:8052 + $0A08
;   ROM 0x14586: FF 88 0A 5C 80 02   ; armor : copy 10 B from $02:805C + $0A08
;
; $0A08 = equipped itemID * 0x20 (record stride), computed by the menu code.
; The relocated tables keep that 0x20 stride (name@+0), so the offset math is
; unchanged — we only repoint the base + widen the count:
;
;   weapon: $02:8052 -> $C4:8920   (equip-weapon-names, 256 x 0x20)
;   armor : $02:805C -> $C4:A920   (equip-armor-names,  256 x 0x20)
;   count : 0x0A (10) -> 0x18 (24) to render full names
;
; Stats (FF84 renderer) and the icon byte stay in the original $02:8050
; records, untouched.

lorom

; --- weapon: count @ $02:C57E, 3-byte ptr @ $02:C57F ---
org $02C57E
db $18                 ; count 10 -> 24
db $20,$89,$C4         ; $C4:8920 (lo,mid,hi)

; --- armor: count @ $02:C587, 3-byte ptr @ $02:C588 ---
org $02C587
db $18
db $20,$A9,$C4         ; $C4:A920
