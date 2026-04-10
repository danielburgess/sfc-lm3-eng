org $000000

; Finally figured this out over 8 years later!!
; 8/16/2014

;NOTES: 
; $0A OR $0B = compression
; $14 = End compression
;
; Code not meant to be efficient, but meant to work
; and meant to learn from it

;/////////////////////////
; Variables that exist //
;///////////////////////

!text = $14
!tbuf = $0400

; This code goes in $4C000
!table1 = $4C0AC    ; TEST THIS SHIT TOMORROW!!
!table2 = $580AC    ; I added this to define the locations of the DTE tables

;/////////////////////////////
; Look!^^^^Some Variables! //
;///////////////////////////



;//////////////////////////////
; Set IPS pointers and data //
;////////////////////////////

;Start:
; addr = ((^Start) && $F0)
; hdr  = $0000                       ; Set this to $200 or $000

; .if addr < $C0			   ; offset - need 2 for compile purposes
;   type = 0
; .else
;   type = 1
; .endif


;///////////////////
; IPS header name //
;///////////////////
;.dcb "PATCH"


;///////////////////////
; Program's Main loop //
;///////////////////////
Main:
; .mem 8				; compiler details 8-bit Accum, 16-bit X and Y
; .index 16

;.IPSOFS ($B68D,$B68D)          ; offset - need 2 tags for compile purposes
;.IPSSZE ((EndMain-5) - Main)   ; size of block

TextLoop:
 lda [text],y
 bne DoText
 jmp $BBB8

DoText:
 cmp #$09
 bcc EndMain

 CMP #$FF
 dcb $f0,$3a                  
 
 BEQ $B6D6
 STA tbuf,x		       ; change to do my routine
 INX
 jsl $4c000

 iny
 bra TextLoop

EndMain:



;/////////////////////////////
; DTE and Dictionary tables //
;/////////////////////////////
Comp:

;.IPSOFS ($4C000,$4C000)         ; offset - need 2 for compile purposes
;.IPSSZE ((EndComp-5) - Comp)    ; size of block

_Start:

 ;// This checks to see if we request a compressed string from the FIRST table
cmp #$0A         
; bne _NoCmp   ;// comment this because we have another test to do
beq _DoComp1


; // Add this line to extend it!!!
_DoTest2:
cmp #$0B         ;// This checks to see if we request a compressed string from the SECOND table
bne _NoCmp       ;// this stays

;///////////////////////
; We have compression //
;///////////////////////
; // ALL THE BELOW WAS ADDED
_DoComp2:
lda !text+0        ; load the old text pointer and save somewhere
sta $7ffff0
lda !text+1
sta $7ffff1
lda !text+2
sta $7ffff2
rep #$20        ; go into 16-bit Accum
iny            ; save the Y position for THIS pointer
tya
sta $7ffff3

lda [!text],y        ; get the index byte to compression table
and #$00ff
asl            ; multiply it by 2
phx
tax            ; save X and transfer index to X to load a new pointer

               ; // RIGHT HERE IS WHERE THE DIFFERENCE IS MADE
               ; // Where you see xxxxx you need to make that address of the Dictionary pointer table
lda [!table2],x   ;+ (_Data - _Start)
sta !text        ; store the new pointer
sep #$20
                ; // THIS LINE ALSO CHANGES [ where you see $xxxx, the xxxx needs to be the BANK of the ]
                ; // new data ( DICTIONARY, DTE data ) Ex: if the data is at $5C000, PEA $0505
PEA $0505
; phk            ; current bank is where data is, use for 24-bit bank
pla
pla                    ; need to pull TWICE because you push a WORD on the stack
sta !text+2
plx            ; restore buffer pointer
ldy #$ffff     ; Y is incremented by 1 so make it INC it to $0000
rtl            ; use the same routine to do all the work for us =]
; // ALL THE ABOVE WAS ADDED


; // ALL THIS REMAINS THE SAME [ BELOW ]
;///////////////////////
; We have compression //
;///////////////////////
_DoComp1:
lda !text+0        ; load the old text pointer and save somewhere
sta $7ffff0
lda !text+1
sta $7ffff1
lda !text+2
sta $7ffff2
rep #$20        ; go into 16-bit Accum
iny            ; save the Y position for THIS pointer
tya
sta $7ffff3

lda [!text],y        ; get the index byte to compression table
and #$00ff
asl            ; multiply it by 2
phx
tax            ; save X and transfer index to X to load a new pointer

lda [!table1],x   ; + (_Data - _Start),x
sta !text        ; store the new pointer
sep #$20
phk            ; current bank is where data is, use for 24-bit bank
pla
sta !text+2
plx            ; restore buffer pointer
ldy #$ffff     ; Y is incremented by 1 so make it INC it to $0000
rtl            ; use the same routine to do all the work for us =]
; // ALL THIS REMAINS THE SAME [ ABOVE ] 


;///////////////////////////////
; Restore the text in pointer //
;/////////////////////////////// 
_NoCmp:
 cmp #$14		    ; byte to end compression
 bne Store		    ; no error checking here. Ex: I usually check a flag
			        ; to see if this is really a return from compression
			        ; could be bad if $14 is used in a regular string
 lda $7ffff0		; reload the saved data and restore the pointer
 sta !text+0
 lda $7ffff1
 sta !text+1
 lda $7ffff2
 sta !text+2
 rep #$20		    ; 16-bit Accum
 lda $7ffff3		; restore THAT Y position
 tay
 sep #$20
 nop			; got lazy with comp table pos, Was DEY, but was wrong
 rtl			; return to old routine  


Store:			; store the text
 sta !tbuf,x	; tbuf = $0400, game's buffer
 inx			; only increment the X since on return Y is INC'd
 rtl 			; return to main routine

;/////////////////////////////
; blank compression block  // 
; 7 bytes PLUS "end byte" //
;////////////////////////// 
;_Data:
;incbin LM3_ptr.raw
;EndComp:

;//////////////////////////
; Store the EOF label   //
; Used by teh IPS prog //
;///////////////////////
;.dcb "EOF"


;///////////////////////////////////////
; Store a asm source with macros     //
; These macros contain the IPS data //
;////////////////////////////////////
;.INCSRC "IPSmacro.asm"
