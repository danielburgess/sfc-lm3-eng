;NOTES:
; < get low byte
; > get high byte
; ^ get bank byte
; ! get word value


;/////////////////////////
; A macro to store the  //
; address in IPS format //
;/////////////////////////
IPSOFS .macro (Snes2Pc,Snes2Pc2)
 ; // LoROM
 .if type = 0
  .dcb ^((bas1 OR Snes2Pc) - bas1) >> 1
  .dcb >(((Snes2Pc >>1) && $8000)  || ((Snes2Pc2 - 8000h) + hdr))
  .dcb <Snes2Pc
 .endif

 ; "else" seemed  to be bugged

 ; // HiROM
 .if type = 1
  .dcb ^((bas2 OR Snes2Pc) - bas2)
  .dcb >(Snes2Pc + hdr)
  .dcb <Snes2Pc
 .endif
.endm


;/////////////////////////
; A macro to store the  //
; sizes in IPS format   //
;/////////////////////////
IPSSZE .macro (DataSize)
 .dcb >DataSize
 .dcb <DataSize
.endm

