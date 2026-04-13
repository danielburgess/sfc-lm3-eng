        org $808000

        db $00,$00,$58,$39,$59,$39,$59,$39,$59,$39,$59,$39,$59,$39,$59,$39
        db $59,$39,$59,$39,$59,$39,$59,$39,$59,$39,$59,$39,$58,$79,$3F,$35
        db $4F,$35,$58,$39,$59,$39,$59,$39,$59,$39,$59,$39,$59,$39,$59,$39
        db $59,$39,$59,$39,$59,$39,$59,$39,$59,$39,$59,$39,$58,$79,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; [LevelLoad] Loads game data from ROM. Entry: A=data ID to load. Sets up data pointers at $22/$24, stores data at $0958-$095A, handles special cases for values $FFFF. Returns A=0 on success.
loadGameData: ; $008060
        REP #$20
        STA.B $00
        LDA.W #$8000
        STA.B $22
        STA.W $0986
        LDA.W #$003E
        STA.B $24
        STA.W $0988
        LDA.B $00
        CMP.W #$FFFF
        BEQ CODE_80809A
        JSR.W findDataEntry
        BNE CODE_8080A3
        INC.B $24
        JSR.W findDataEntry
        BNE CODE_8080A3
        LDA.W #$0039
        STA.B $24
        LDA.W #$8000
        STA.B $22
        JSR.W findDataEntry
        BNE CODE_8080A3
        db $A9,$FF,$FF,$6B
CODE_80809A: ; $00809A
        db $A5,$22,$18,$69,$10,$00,$8D,$86,$09
CODE_8080A3: ; $0080A3
        STA.W $096C
        LDY.W #$0002
        LDA.B [$22],Y
        STA.W $0958
        LDY.W #$0004
        LDA.B [$22],Y
        STA.W $095A
        SEP #$20
        LDY.W #$0006
        LDA.B [$22],Y
        CMP.B #$FF
        BEQ CODE_8080C5
        STA.L $7FC003
CODE_8080C5: ; $0080C5
        LDY.W #$0007
        LDA.B [$22],Y
        CMP.B #$FF
        BEQ CODE_8080D2
        STA.L $7EEA84
CODE_8080D2: ; $0080D2
        REP #$20
        LDA.W #$0000
        RTL
; [Memory] Searches data table for matching entry. Entry: $00=search value, $22/$24=data table pointer. Returns A=1 if found (sets $096C=index, $22=entry pointer, $096E=entry data), A=0 if not found.
findDataEntry: ; $0080D8
        LDY.W #$0000
        STZ.B $08
CODE_8080DD: ; $0080DD
        LDA.B [$22],Y
        BNE CODE_8080E2
        RTS
CODE_8080E2: ; $0080E2
        STA.B $02
        INY
        INY
        LDA.B [$22],Y
        INY
        INY
        STA.B $04
        LDA.B [$22],Y
        STA.B $06
; [Helper]
TEST: ; $0080F0
        LDA.B $04
; [Helper]
DSPADDR: ; $0080F2
        CMP.B $00
; [Helper]
CPUIO0: ; $0080F4
        BEQ T1OUT
; [Helper]
CPUIO2: ; $0080F6
        INC.B $08
; [Helper]
RAMREG1: ; $0080F8
        INY
; [Helper]
RAMREG2: ; $0080F9
        INY
; [Helper]
T0TARGET: ; $0080FA
        INY
; [Helper]
T1TARGET: ; $0080FB
        INY
; [Helper]
T2TARGET: ; $0080FC
        BRA CODE_8080DD
; [Helper]
T1OUT: ; $0080FE
        LDA.B $08
        STA.W $096C
        LDA.B $02
        AND.W #$7FFF
        CLC
        ADC.B $22
        STA.B $22
        CLC
        ADC.W #$0010
        STA.W $0986
        LDA.B $24
        STA.W $0988
        LDA.B $06
        STA.W $096E
        LDA.W #$0001
        RTS
; [Memory] Sets up data structure from loaded game data. Uses $0986/$0988 as base pointers, calls sub_00E155 for processing. Entry: expects data pointers set. Returns via RTL.
setupDataStructure: ; $008122
        REP #$20
        LDA.W $0986
        SEC
        SBC.W #$0006
        STA.B $22
        LDA.W $0988
        STA.B $24
        LDA.B [$22]
        PHA
        INC.B $22
        INC.B $22
        LDA.B [$22]
        PHA
        INC.B $22
        INC.B $22
        LDA.B [$22]
        STA.W $098A
        PLA
        JSL.L initEntityFromData
        LDA.W $098A
        CLC
        ADC.W #$0104
        TAX
        PLA
        CMP.W #$0000
        BEQ CODE_80815F
        LDY.W #$0080
        JSL.L setTextScrollParams
CODE_80815F: ; $00815F
        RTL
        db $C2,$20,$C9,$00,$00,$F0,$03,$8D,$9C,$09,$86,$30,$84,$2E,$64,$26
        db $64,$28,$AD,$9A,$09,$4A,$4A,$4A,$4A,$29,$07,$00,$85,$2C,$A5,$2C
        db $C9,$02,$00,$90,$20,$E2,$20,$AD,$9C,$09,$18,$65,$2E,$8D,$9C,$09
        db $85,$26,$AD,$9D,$09,$18,$65,$2F,$8D,$9D,$09,$85,$28,$C2,$20,$22
        db $FD,$82,$00,$80,$20,$E2,$20,$AD,$9C,$09,$18,$65,$2E,$8D,$9C,$09
        db $85,$22,$AD,$9D,$09,$18,$65,$2F,$8D,$9D,$09,$85,$24,$C2,$20,$A5
        db $2C,$22,$5D,$82,$00,$C6,$30,$D0,$B5,$6B,$C2,$20,$8D,$9A,$09,$D0
        db $03,$4C,$45,$82,$9C,$9C,$09,$A9,$03,$00,$85,$14,$A9,$40,$8B,$85
        db $12,$A2,$00,$50,$A0,$00,$08,$22,$30,$C5,$00,$A2,$00,$00,$A9,$00
        db $00,$A0,$00,$04,$9F,$00,$B0,$7F,$E8,$E8,$88,$D0,$F7,$A2,$00,$00
        db $A9,$00,$3F,$A0,$80,$02,$9F,$80,$B0,$7F,$E8,$E8,$88,$D0,$F7,$A9
        db $03,$00,$85,$14,$A9,$B2,$B4,$85,$12,$AD,$9A,$09,$3A,$29,$0F,$00
        db $18,$65,$13,$85,$13,$A2,$00,$00,$A0,$80,$00,$A7,$12,$9D,$00,$0B
        db $E8,$E8,$E6,$12,$E6,$12,$88,$D0,$F2,$22,$BE,$E3,$00,$64,$6B,$64
        db $6D,$20,$42,$84,$6B,$C2,$20,$A2,$00,$00,$A9,$00,$00,$A0,$00,$04
        db $9F,$00,$B0,$7F,$E8,$E8,$88,$D0,$F7,$20,$42,$84,$6B,$C2,$20,$A2
        db $00,$00,$C9,$01,$00,$D0,$03,$A2,$00,$0A,$A9,$7F,$00,$85,$18,$A9
        db $80,$B0,$85,$16,$A9,$00,$0B,$85,$12,$A9,$00,$3F,$85,$00,$A5,$22
        db $29,$07,$00,$85,$04,$A5,$24,$29,$0F,$00,$0A,$0A,$0A,$0A,$05,$04
        db $85,$04,$A9,$14,$00,$85,$08,$A0,$20,$00,$E2,$20,$64,$00,$BF,$40
        db $8D,$03,$18,$65,$04,$85,$12,$B2,$12,$F0,$02,$E6,$00,$BF,$41,$8D
        db $03,$18,$65,$04,$85,$12,$B2,$12,$F0,$04,$E6,$00,$E6,$00,$BF,$80
        db $8D,$03,$18,$65,$04,$85,$12,$B2,$12,$F0,$04,$A9,$04,$04,$00,$BF
        db $81,$8D,$03,$18,$65,$04,$85,$12,$B2,$12,$F0,$04,$A9,$08,$04,$00
        db $C2,$20,$A5,$00,$87,$16,$E6,$16,$E6,$16,$E8,$E8,$88,$D0,$AB,$8A
        db $18,$69,$40,$00,$AA,$C6,$08,$D0,$9E,$20,$42,$84,$6B,$C2,$20,$A9
        db $00,$0B,$85,$12,$A5,$26,$85,$00,$A5,$28,$18,$69,$80,$00,$20,$56
        db $84,$85,$02,$84,$04,$A5,$28,$18,$69,$40,$00,$20,$56,$84,$85,$06
        db $84,$08,$20,$7A,$84,$E2,$20,$A2,$82,$00,$A9,$14,$85,$0A,$DA,$A0
        db $1E,$00,$64,$00,$A5,$14,$18,$65,$02,$85,$14,$A5,$15,$65,$03,$85
        db $15,$29,$0F,$85,$12,$A5,$16,$18,$65,$04,$85,$16,$A5,$17,$65,$05
        db $85,$17,$29,$F0,$05,$12,$85,$12,$B2,$12,$F0,$02,$E6,$00,$A5,$14
        db $18,$65,$02,$85,$14,$A5,$15,$65,$03,$85,$15,$29,$0F,$85,$12,$A5
        db $16,$18,$65,$04,$85,$16,$A5,$17,$65,$05,$85,$17,$29,$F0,$05,$12
        db $85,$12,$B2,$12,$F0,$04,$E6,$00,$E6,$00,$A5,$00,$9F,$00,$B0,$7F
        db $E8,$E8,$88,$D0,$9D,$C2,$20,$FA,$DA,$A5,$18,$18,$65,$06,$85,$18
        db $85,$14,$A5,$1A,$18,$65,$08,$85,$1A,$85,$16,$E2,$20,$A0,$1E,$00
        db $64,$00,$A5,$14,$18,$65,$02,$85,$14,$A5,$15,$65,$03,$85,$15,$29
        db $0F,$85,$12,$A5,$16,$18,$65,$04,$85,$16,$A5,$17,$65,$05,$85,$17
        db $29,$F0,$05,$12,$85,$12,$B2,$12,$F0,$04,$A9,$04,$04,$00,$A5,$14
        db $18,$65,$02,$85,$14,$A5,$15,$65,$03,$85,$15,$29,$0F,$85,$12,$A5
        db $16,$18,$65,$04,$85,$16,$A5,$17,$65,$05,$85,$17,$29,$F0,$05,$12
        db $85,$12,$B2,$12,$F0,$04,$A9,$08,$04,$00,$BF,$00,$B0,$7F,$05,$00
        db $9F,$00,$B0,$7F,$E8,$E8,$88,$D0,$97,$C2,$20,$68,$18,$69,$40,$00
        db $AA,$A5,$18,$18,$65,$06,$85,$18,$85,$14,$A5,$1A,$18,$65,$08,$85
        db $1A,$85,$16,$E2,$20,$C6,$0A,$F0,$03,$4C,$2E,$83,$20,$42,$84,$C2
        db $20,$6B,$C2,$20,$A9,$00,$70,$85,$78,$E2,$20,$A9,$FE,$85,$57,$C2
        db $20,$22,$BE,$E3,$00,$60,$29,$FF,$00,$AA,$BF,$00,$80,$03,$20,$2C
        db $87,$48,$8A,$18,$69,$40,$00,$29,$FF,$00,$AA,$BF,$00,$80,$03,$20
        db $2C,$87,$AA,$0A,$0A,$0A,$0A,$A8,$68,$60,$A5,$22,$A0,$1E,$00,$38
        db $E5,$02,$38,$E5,$06,$88,$D0,$F7,$85,$14,$85,$18,$A5,$24,$A0,$14
        db $00,$38,$E5,$04,$38,$E5,$08,$88,$D0,$F7,$85,$16,$85,$1A,$60,$C2
        db $20,$A9,$00,$00,$85,$14,$A9,$EC,$84,$85,$12,$A7,$12,$29,$FF,$00
        db $8D,$D6,$09,$E6,$12,$A0,$00,$00,$AD,$D6,$09,$85,$08,$A9,$00,$00
        db $99,$00,$0B,$A7,$12,$29,$FF,$00,$99,$02,$0B,$E6,$12,$A7,$12,$29
        db $FF,$00,$99,$04,$0B,$E6,$12,$A7,$12,$29,$FF,$00,$99,$06,$0B,$E6
        db $12,$98,$18,$69,$08,$00,$A8,$C6,$08,$D0,$D2,$6B,$1D,$00,$00,$00
        db $00,$EA,$F0,$06,$F3,$F0,$0D,$FC,$F0,$14,$04,$F0,$1A,$0D,$F0,$20
        db $16,$F0,$14,$16,$F0,$07,$16,$F0,$F9,$16,$F0,$EC,$16,$F0,$E0,$16
        db $F0,$E6,$0D,$F0,$EC,$04,$F0,$F3,$FC,$F0,$FA,$F3,$F0,$00,$EE,$F6
        db $00,$F3,$FD,$00,$F7,$04,$00,$FC,$0A,$00,$00,$10,$FA,$04,$0A,$F3
        db $09,$04,$EC,$0D,$FD,$E6,$12,$F6,$06,$04,$0A,$0D,$09,$04,$14,$0D
        db $FD,$1A,$12,$F6,$C2,$20,$A5,$2A,$29,$FF,$00,$AA,$A5,$28,$29,$FF
        db $00,$A8,$E2,$20,$BF,$00,$82,$03,$85,$14,$BF,$40,$82,$03,$85,$15
        db $BB,$BF,$00,$82,$03,$85,$12,$BF,$40,$82,$03,$85,$13,$C2,$20,$A0
        db $00,$00,$A2,$00,$00,$AD,$D6,$09,$85,$08,$A5,$14,$85,$00,$BD,$02
        db $0B,$20,$2C,$87,$85,$04,$BD,$06,$0B,$20,$2C,$87,$85,$06,$A5,$15
        db $85,$00,$BD,$02,$0B,$20,$2C,$87,$18,$65,$06,$85,$16,$BD,$06,$0B
        db $20,$2C,$87,$38,$E5,$04,$0A,$0A,$85,$18,$A5,$12,$85,$00,$A5,$19
        db $20,$2C,$87,$85,$06,$BD,$04,$0B,$20,$2C,$87,$85,$04,$A5,$13,$85
        db $00,$A5,$19,$20,$2C,$87,$18,$65,$04,$18,$65,$26,$85,$18,$BD,$04
        db $0B,$20,$2C,$87,$38,$E5,$06,$85,$1A,$A5,$19,$18,$69,$80,$00,$85
        db $00,$4A,$4A,$4A,$29,$1E,$00,$18,$69,$2D,$86,$85,$06,$A5,$16,$18
        db $65,$22,$20,$E5,$86,$85,$02,$F0,$28,$A5,$1A,$18,$65,$24,$20,$E5
        db $86,$85,$03,$F0,$1C,$A5,$02,$99,$00,$01,$C8,$C8,$B2,$06,$99,$00
        db $01,$C8,$C8,$8A,$18,$69,$08,$00,$AA,$C6,$08,$F0,$03,$4C,$7A,$85
        db $6B,$A9,$00,$E0,$99,$00,$01,$C8,$C8,$C8,$C8,$80,$E6,$AA,$2B,$AA
        db $2B,$A8,$2B,$A6,$2B,$A6,$2B,$A4,$2B,$A4,$2B,$A4,$2B,$A2,$2B,$A2
        db $2B,$A2,$2B,$A0,$2B,$A0,$2B,$A0,$2B,$A0,$2B,$A0,$2B,$C2,$20,$A5
        db $54,$29,$FF,$00,$AA,$E2,$20,$BF,$00,$82,$03,$85,$14,$BF,$40,$82
        db $03,$85,$15,$C2,$20,$A0,$00,$00,$A2,$00,$00,$AD,$D6,$09,$85,$08
        db $A5,$14,$85,$00,$BD,$02,$0B,$20,$2C,$87,$85,$04,$BD,$04,$0B,$20
        db $2C,$87,$85,$06,$A5,$15,$85,$00,$BD,$02,$0B,$20,$2C,$87,$38,$E5
        db $06,$85,$16,$BD,$04,$0B,$20,$2C,$87,$18,$65,$04,$85,$18,$BD,$06
        db $0B,$38,$E5,$54,$29,$7F,$00,$18,$69,$20,$00,$85,$00,$A5,$16,$20
        db $E5,$86,$85,$02,$F0,$23,$A5,$18,$20,$E5,$86,$85,$03,$F0,$1A,$A5
        db $02,$99,$00,$01,$C8,$C8,$A9,$A0,$2B,$99,$00,$01,$C8,$C8,$8A,$18
        db $69,$08,$00,$AA,$C6,$08,$D0,$98,$6B,$A9,$00,$E0,$99,$00,$01,$C8
        db $C8,$C8,$C8,$80,$E9,$C9,$00,$80,$90,$21,$3A,$49,$FF,$FF,$8D,$04
        db $42,$E2,$20,$A5,$00,$8D,$06,$42,$EA,$EA,$EA,$EA,$C2,$20,$A9,$70
        db $00,$38,$ED,$14,$42,$C9,$00,$01,$B0,$1E,$60,$8D,$04,$42,$E2,$20
        db $A5,$00,$8D,$06,$42,$EA,$EA,$EA,$EA,$C2,$20,$A9,$70,$00,$18,$6D
        db $14,$42,$C9,$00,$01,$B0,$01,$60,$A9,$00,$00,$60,$E2,$20,$C9,$80
        db $B0,$1B,$8D,$02,$42,$A5,$00,$C9,$80,$90,$21,$3A,$49,$FF,$8D,$03
        db $42,$C2,$20,$A9,$00,$00,$38,$ED,$16,$42,$60,$E2,$20,$3A,$49,$FF
        db $8D,$02,$42,$A5,$00,$C9,$80,$90,$E5,$3A,$49,$FF,$8D,$03,$42,$EA
        db $EA,$C2,$20,$AD,$16,$42,$60,$A5,$00,$18,$69,$04,$F8,$85,$2C,$22
        db $9F,$84,$00,$64,$22,$64,$24,$A9,$00,$91,$85,$26,$64,$28,$64,$2A
        db $22,$44,$85,$00,$A5,$2C,$85,$00,$22,$A8,$87,$00,$E6,$28,$E6,$2A
        db $E6,$28,$E6,$2A,$A5,$26,$C9,$00,$69,$F0,$0C,$18,$69,$00,$02,$85
        db $26,$22,$BE,$E3,$00,$80,$D9,$6B,$A4,$00,$AD,$00,$01,$20,$C3,$87
        db $18,$65,$22,$85,$22,$A4,$01,$AD,$01,$01,$20,$C3,$87,$18,$65,$24
        db $85,$24,$6B,$29,$FF,$00,$85,$02,$98,$29,$FF,$00,$38,$E5,$02,$F0
        db $06,$0A,$0A,$0A,$0A,$0A,$60,$A9,$00,$00,$60,$C2,$20,$A5,$4F,$29
        db $02,$00,$F0,$08,$A5,$22,$18,$69,$80,$00,$85,$22,$A5,$4F,$29,$01
        db $00,$F0,$08,$A5,$22,$38,$E9,$80,$00,$85,$22,$A5,$4F,$29,$08,$00
        db $F0,$08,$A5,$24,$18,$69,$80,$00,$85,$24,$A5,$4F,$29,$04,$00,$F0
        db $08,$A5,$24,$38,$E9,$80,$00,$85,$24,$A5,$4E,$29,$10,$00,$F0,$08
        db $A5,$26,$18,$69,$00,$01,$85,$26,$A5,$4E,$29,$20,$00,$F0,$08,$A5
        db $26,$38,$E9,$00,$01,$85,$26,$A5,$4E,$29,$80,$00,$F0,$02,$E6,$28
        db $A5,$4E,$29,$00,$80,$F0,$02,$C6,$28,$A5,$4E,$29,$40,$00,$F0,$02
        db $E6,$2A,$A5,$4E,$29,$00,$40,$F0,$02
; [Helper] DEC $2A, RTL — single-instruction stub
decrementFlag2A: ; $008859
        db $C6,$2A,$6B
; [GameState] Game mode dispatcher - jumps to different game mode handlers based on A value (0-5). Entry: A=game mode index. Uses jump table at $8869.
dispatchGameMode: ; $00885C
        REP #$20
        ASL A
        ASL A
        CLC
        ADC.W #$8869
        STA.B $00
        JMP.W ($0000)
        db $4C,$9D,$88,$EA
        JMP.W $8E82
        db $EA
        JMP.W $889E
        db $EA
        JMP.W textLineWidth
        db $EA
        JMP.W $8A52
        db $EA
        JMP.W $8B65
        db $EA
        JMP.W $8B8B
        db $EA
        JMP.W $8D84
        db $EA
        JMP.W $8BDA
        db $EA
        JMP.W $8C2E
        db $EA
        JMP.W $8C6E
        db $EA
        JMP.W $8DE9
        db $EA
        JMP.W $8E2B
        db $EA,$6B
        PHP
        REP #$20
        LDA.W #$FFFF
        STA.B $6F
        JSR.W mainGameLoop
        LDA.W #$0003
        STA.B $14
        LDA.W #$A1D2
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0008
        STA.B $02
        JSL.L uploadPaletteWrapper
        JSL.L calcEntityDataPtr
        LDA.W #$0002
        STA.B $00
        LDA.W #$0005
        STA.B $02
        JSL.L unpackTileProperties
        JSL.L waitForModeSync
        REP #$20
        JSR.W calculateTileOffset
        LDA.W #$002E
        STA.B $14
        LDA.W #$F000
        STA.B $12
        LDX.W #$1800
        LDY.W #$1000
        JSL.L dmaToVRAMGeneric
        JSR.W calcD800DataPtr
        LDA.B [$12]
        STA.B $00
        INC.B $12
        SEP #$20
        LDA.B [$12]
        STA.B $72
        REP #$20
        LDA.B $00
        AND.W #$00FF
        INC A
        LDX.W #$2000
        LDY.W #$0000
        JSL.L setupTilemapSource_Long
        LDA.W $0A4A
        STA.W $0A48
        PLP
        RTL
; [VRAM] Calculates tile offset for graphics data. Entry: X=index. Reads from $7FCE00 table, multiplies by $A0, adds base offset $8000. Returns Y=calculated offset.
calculateTileOffset: ; $008919
        STZ.B $22
CODE_80891B: ; $00891B
        LDX.B $22
        SEP #$20
        LDA.B #$2C
        STA.B $14
        LDA.L $7FCE00,X
        CMP.B #$80
        BCC CODE_80892F
        INC.B $14
        AND.B #$7F
CODE_80892F: ; $00892F
        STA.W $4202
        LDA.B #$A0
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDY.W $4216
        REP #$20
        TYA
        ASL A
        CLC
        ADC.W #$8000
        STA.B $12
        LDA.B $22
        ASL A
        TAX
        LDA.L $008980,X
        ASL A
        ASL A
        ASL A
        ASL A
        CLC
        ADC.W #$0000
        PHA
        TAX
        LDY.W #$00A0
        JSL.L dmaToVRAMGeneric
        LDA.B $12
        CLC
        ADC.W #$00A0
        STA.B $12
        PLA
        CLC
        ADC.W #$0100
        TAX
        LDY.W #$00A0
        JSL.L dmaToVRAMGeneric
        INC.B $22
        LDA.B $22
        CMP.W #$0024
        BNE CODE_80891B
        RTS
        db $00,$00,$05,$00,$0A,$00,$20,$00,$25,$00,$2A,$00,$40,$00,$45,$00
        db $4A,$00,$60,$00,$65,$00,$6A,$00,$80,$00,$85,$00,$8A,$00,$A0,$00
        db $A5,$00,$AA,$00,$C0,$00,$C5,$00,$CA,$00,$E0,$00,$E5,$00,$EA,$00
        db $00,$01,$05,$01,$0A,$01,$20,$01,$25,$01,$2A,$01,$40,$01,$45,$01
        db $4A,$01,$60,$01,$65,$01,$6A,$01
; [Entity] Reads $7EEA84 low nibble as index, computes pointer into data block via calcD800DataPtr
calcEntityDataPtr: ; $0089C8
        REP #$20
        JSR.W calcD800DataPtr
        LDA.L $7EEA84
        AND.W #$000F
        INC A
        ASL A
        CLC
        ADC.B $12
        STA.B $12
        LDA.B [$12]
        STA.B $12
        RTL
; [Entity] Reads $7FC003, multiplies by 8, computes pointer into $2F:D800 ROM data block
calcD800DataPtr: ; $0089E0
        REP #$20
        LDA.L $7FC003
        AND.W #$00FF
        ASL A
        ASL A
        ASL A
        STA.B $00
        LDA.W #$002F
        STA.B $14
        LDA.W #$D800
        STA.B $12
        LDA.B $12
        CLC
        ADC.B $00
        STA.B $12
        RTS
; [Text]
textLineWidth: ; $008A00
        PHP
        REP #$20
        STZ.B $6F
        JSR.W mainGameLoop
        SEP #$20
; [Text]
textExtendedVariable: ; $008A0A
        LDA.B #$02
        STA.W $2130
        LDA.B #$14
        STA.B $74
        LDA.B #$00
        STA.B $75
        REP #$20
        LDX.W #$2000
; [Text]
textSpecialMode1: ; $008A1C
        LDY.W #$1000
        LDA.W #$0000
        JSL.L fillVRAMRegion
        LDX.W #$7800
        LDY.W #$1000
        LDA.W #$0000
        JSL.L fillVRAMRegion
        LDX.W #$7000
        LDY.W #$0800
        LDA.W #$0000
        JSL.L fillVRAMRegion
        LDX.W #$0000
        LDY.W #$2000
        LDA.W #$0000
        JSL.L fillVRAMRegion
        JSR.W initOAMBuffer_Battle
        PLP
        RTL
        PHP
        REP #$20
        STZ.B $6F
        SEP #$20
        JSL.L initMapScene
        JSL.L clearBGTilemapVRAM
        LDA.B #$81
        STA.W $4200
        LDA.B #$00
        STA.L $7EA000
        SEP #$20
        STZ.B $6B
        STZ.B $6D
        LDA.B #$03
        STA.W $210C
        REP #$20
        LDA.W #$0001
        STA.W $0A1C
        LDA.W #$002E
        STA.B $14
        LDA.W #$8000
; [Debug] Non-zero enables debug mode features
debugModeFlag: ; $008A87
        STA.B $12
        LDX.W #$3000
        LDY.W #$0100
        JSL.L loadFontTile
        LDA.W #$0000
        STA.B $14
        LDA.W #$0D80
        STA.B $12
        LDA.W #$0000
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L uploadPaletteWrapper
        JSL.L setEventFlag
        LDA.W #$E800
        LDX.W #$0000
        LDY.W #$0080
CODE_808AB8: ; $008AB8
        STA.W $0100,X
        INX
        INX
        INX
        INX
        DEY
        BNE CODE_808AB8
        LDA.W #$002E
        STA.B $14
        LDA.W #$F000
        STA.B $12
        LDX.W #$1800
        LDY.W #$1000
        JSL.L dmaToVRAMGeneric
        LDA.W #$002E
        STA.B $14
        LDA.W #$A000
        STA.B $12
        LDX.W #$5000
        LDY.W #$1000
        JSL.L dmaToVRAMGeneric
        LDA.W #$0003
        STA.B $14
        LDA.W #$A1A0
        STA.B $12
        LDA.W #$0007
        STA.B $00
        LDA.W #$0001
        STA.B $02
        JSL.L uploadPaletteWrapper
        LDX.W #$2000
        LDY.W #$1000
        LDA.W #$0000
        JSL.L fillVRAMRegion
        JSR.W initBattleBGTilemap
        JSR.W initOAMBuffer_Battle
        PLP
        RTL
; [Tilemap] Fills $7FB000 with 32x32 tilemap (col&7 + row_base + $1F00), sets $78=$7000, syncs
initBattleBGTilemap: ; $008B17
        REP #$20
        LDX.W #$0000
        LDA.W #$0000
        STA.B $00
        LDY.W #$0020
CODE_808B24: ; $008B24
        PHY
        LDA.W #$0000
        STA.B $02
        LDY.W #$0020
CODE_808B2D: ; $008B2D
        LDA.B $02
        AND.W #$0007
        CLC
        ADC.B $00
        CLC
        ADC.W #$1F00
        STA.L $7FB000,X
        INX
        INX
        INC.B $02
        DEY
        BNE CODE_808B2D
        LDA.B $00
        CLC
        ADC.W #$0008
        AND.W #$0038
        STA.B $00
        PLY
        DEY
        BNE CODE_808B24
        LDA.W #$7000
        STA.B $78
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSL.L waitForModeSync
        RTS
        PHP
        REP #$20
        STZ.B $6F
        JSR.W mainGameLoop
        SEP #$20
        LDA.B #$04
        STA.W $2105
        REP #$20
        JSR.W initOAMBuffer_Battle
        SEP #$20
        LDA.B #$01
        STA.W $212C
        STA.W $212D
        STA.B $74
        STA.B $75
        REP #$20
        PLP
        RTL
        PHP
        JSR.W initSceneAndClearOAM
        REP #$20
        JSR.W calculateTileOffset
        LDA.W #$002E
        STA.B $14
        LDA.W #$F000
        STA.B $12
        LDX.W #$1800
        LDY.W #$1000
        JSL.L dmaToVRAMGeneric
        LDA.W #$0003
        STA.B $14
        LDA.W #$A1D2
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0008
        STA.B $02
        JSL.L uploadPaletteWrapper
        LDA.W #$0000
        STA.B $14
        LDA.W #$0D80
        STA.B $12
        LDA.W #$0000
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L uploadPaletteWrapper
        PLP
        RTL
        PHP
        LDA.W #$FFFF
        STA.B $6F
        JSR.W initSceneAndClearOAM
        REP #$20
        JSR.W calculateTileOffset
        LDA.W #$002E
        STA.B $14
        LDA.W #$A800
        STA.B $12
        LDX.W #$1800
        LDY.W #$0800
        JSL.L dmaToVRAMGeneric
        LDA.W #$0003
        STA.B $14
        LDA.W #$A2F2
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0008
        STA.B $02
        JSL.L uploadPaletteWrapper
        LDA.W #$0000
        STA.B $14
        LDA.W #$0D80
        STA.B $12
        LDA.W #$0000
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L uploadPaletteWrapper
        PLP
        RTL
        PHP
        REP #$20
        JSR.W initSceneAndClearOAM
        SEP #$20
        LDA.B #$01
        STA.W $2105
        REP #$20
        JSR.W calculateTileOffset
        LDA.W #$002E
        STA.B $14
        LDA.W #$D800
        STA.B $12
        LDX.W #$1800
        LDY.W #$0800
        JSL.L dmaToVRAMGeneric
        LDA.W #$0003
        STA.B $14
        LDA.W #$A4F2
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0001
        STA.B $02
        JSL.L uploadPaletteWrapper
        PLP
        RTL
        PHP
        JSR.W initSceneAndClearOAM
        LDA.W #$0001
        STA.W $2105
        REP #$20
        LDA.W #$002E
        STA.B $14
        LDA.W #$E000
        STA.B $12
        LDX.W #$1800
        LDY.W #$1000
        JSL.L dmaToVRAMGeneric
        LDA.W #$0003
        STA.B $14
        LDA.W #$A3F2
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0008
        STA.B $02
        JSL.L uploadPaletteWrapper
        LDA.W #$0009
        LDX.W #$0300
        LDY.W #$0000
        JSL.L setTextScrollParams
        LDX.W #$0000
        LDY.W #$02E0
        LDA.W #$1100
        JSR.W fillTileBuffer9000
        LDX.W #$0540
        LDY.W #$0020
        LDA.W #$3D76
        JSR.W fillTileBuffer9000
        LDX.W #$0580
        LDY.W #$00E0
        LDA.W #$0900
        JSR.W fillTileBuffer9000
        LDX.W #$0040
        LDY.W #$0020
        LDA.W #$0900
        JSR.W fillTileBuffer9000
        LDX.W #$0080
        LDY.W #$0020
        LDA.W #$0900
        JSR.W fillTileBuffer9000
        LDX.W #$00C0
        LDY.W #$0020
        LDA.W #$0900
        JSR.W fillTileBuffer9000
        PLP
        RTL
; [Init] Scene init: waitForModeSync, initMapScene, fillVRAMRegion, enable NMI, zero $7EA000, fill OAM $F0FF
initSceneAndClearOAM: ; $008CFD
        SEP #$20
        JSL.L waitForModeSync
        LDA.B $72
        PHA
        JSL.L initMapScene
        JSL.L waitForButton
        LDX.W #$7C00
        LDY.W #$0800
        LDA.B #$00
        JSL.L fillVRAMRegion
        PLA
        STA.B $72
        REP #$20
        LDA.W #$0081
        STA.W $4200
        LDA.W #$0000
        STA.L $7EA000
        STZ.B $6B
        STZ.B $6D
        LDA.W #$0002
        STA.W $2130
        LDA.W #$0016
        STA.B $74
        LDA.W #$0000
        STA.B $75
        REP #$20
        LDA.W #$F0FF
        LDX.W #$0000
        LDY.W #$0080
CODE_808D4B: ; $008D4B
        STA.W $0100,X
        INX
        INX
        INX
        INX
        DEY
        BNE CODE_808D4B
        RTS
; [OAM] Fills $0100-$01FF OAM shadow with $E000 (offscreen), $0200+ with $FFFF
initOAMBuffer_Battle: ; $008D56
        LDA.W #$E000
        LDX.W #$0000
        LDY.W #$0080
CODE_808D5F: ; $008D5F
        STA.W $0100,X
        INX
        INX
        INX
        INX
        DEY
        BNE CODE_808D5F
        LDA.W #$FFFF
        LDY.W #$0010
CODE_808D6F: ; $008D6F
        STA.W $0100,X
        INX
        INX
        DEY
        BNE CODE_808D6F
        RTS
; Fills $7E:9000 tile buffer in loop.
fillTileBuffer9000: ; $008D78
        REP #$20
CODE_808D7A: ; $008D7A
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE CODE_808D7A
        RTS
        PHP
        REP #$20
        LDA.W #$FFFF
        STA.B $6F
        JSR.W mainGameLoop
        LDA.W #$0003
        STA.B $14
        LDA.W #$A180
        STA.B $12
        LDA.W #$0001
        STA.B $00
        LDA.W #$0001
        STA.B $02
        JSL.L uploadPaletteWrapper
        LDA.W #$0003
        STA.B $14
        LDA.W #$A532
        STA.B $12
        LDA.W #$0002
        STA.B $00
        LDA.W #$0007
        STA.B $02
        JSL.L unpackTileProperties
        LDA.W #$0003
        STA.B $14
        LDA.W #$A612
        STA.B $12
        LDX.W #$0000
        LDY.W #$1000
        JSL.L dmaToVRAMGeneric
        LDA.W #$002E
        STA.B $14
        LDA.W #$C000
        STA.B $12
        LDX.W #$2000
        LDY.W #$1800
        JSL.L dmaToVRAMGeneric
        PLP
        RTL
        PHP
        REP #$20
        STZ.B $6F
        JSR.W mainGameLoop
        STZ.B $60
        STZ.B $62
        STZ.B $6B
        JSR.W setupBattleScene
        LDA.W $096E
        INC A
        LDX.W #$0000
        LDY.W #$0004
        JSL.L setupTilemapSource_Long
        LDA.W #$0023
        STA.B $14
        LDA.W #$D000
        STA.B $12
        LDA.B $13
        CLC
        ADC.W $096E
        STA.B $13
        LDA.W #$0008
        STA.B $00
        LDA.W #$0008
        STA.B $02
        JSL.L uploadPaletteWrapper
        JMP.W $8F8D
        PHP
        REP #$20
        LDA.W #$FFFF
        STA.B $6F
        JSR.W mainGameLoop
        LDA.W #$0001
        STA.W $2105
        LDA.W #$1F1E
        STA.L $7FCE00
        LDA.W #$2220
        STA.L $7FCE02
        JSR.W calculateTileOffset
        LDA.W #$0003
        STA.B $14
        LDA.W #$A2F2
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0008
        STA.B $02
        JSL.L uploadPaletteWrapper
        LDA.W #$0000
        STA.B $14
        LDA.W #$0D80
        STA.B $12
        LDA.W #$0000
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L uploadPaletteWrapper
        JSR.W initOAMBuffer_Battle
        PLP
        RTL
        PHP
        REP #$20
        LDA.W #$FFFF
        STA.B $6F
        JSR.W mainGameLoop
        STZ.B $60
        STZ.B $62
        STZ.B $6B
        STZ.B $6D
        REP #$20
        LDA.W #$001F
        STA.B $14
        LDA.W #$A800
        STA.B $12
        LDA.W $0E03
        JSR.W adjustDataPointer
        LDA.W #$007F
        STA.B $18
        LDA.W #$CF00
        STA.B $16
        LDA.W #$0040
        JSL.L memcpyWords
        LDA.W #$000C
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L swapBytePairsAndUploadPalette
        LDA.W #$001F
        STA.B $14
        LDA.W #$A800
        STA.B $12
        LDA.W $0E83
        JSR.W adjustDataPointer
        LDA.W #$007F
        STA.B $18
        LDA.W #$CF40
        STA.B $16
        LDA.W #$0040
        JSL.L memcpyWords
        LDA.W #$000E
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L swapBytePairsAndUploadPalette
        REP #$20
        LDA.W $0E03
        AND.W #$003F
        INC A
        LDX.W #$0000
        LDY.W #$0002
        JSL.L setupTilemapSource_Long
        LDA.W $0E83
        AND.W #$003F
        CMP.W #$003F
        BEQ CODE_808F1E
        INC A
        LDX.W #$1000
        LDY.W #$0002
        JSL.L setupTilemapSource_Long
CODE_808F1E: ; $008F1E
        JSL.L fadeToBlack
        JSR.W setupBattleScene
        LDA.W #$0003
        STA.B $14
        LDA.W #$B212
        STA.B $12
        LDX.W #$0E80
        LDY.W #$0100
        JSL.L dmaToVRAMGeneric
        LDA.W #$0003
        STA.B $14
        LDA.W #$B312
        STA.B $12
        LDX.W #$0F80
        LDY.W #$0100
        JSL.L dmaToVRAMGeneric
        LDA.W #$0003
        STA.B $14
        LDA.W #$B432
        STA.B $12
        LDX.W #$1E80
        LDY.W #$0100
        JSL.L dmaToVRAMGeneric
        LDA.W #$0003
        STA.B $14
        LDA.W #$B472
        STA.B $12
        LDX.W #$1F80
        LDY.W #$0100
        JSL.L dmaToVRAMGeneric
        LDA.W #$0003
        STA.B $14
        LDA.W #$B412
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0001
        STA.B $02
        JSL.L uploadPaletteWrapper
        LDA.W #$0002
        JSL.L updateDepthEffect
        SEP #$20
        LDA.B #$71
        STA.W $2108
        LDA.B #$00
        STA.W $2126
        LDA.B #$FF
        STA.W $2127
        LDA.B #$FF
        STA.W $2128
        LDA.B #$00
        STA.W $2129
        LDA.W $0E25
        BEQ CODE_808FBE
        LDA.B #$7D
        STA.W $2128
        LDA.B #$83
        STA.W $2129
CODE_808FBE: ; $008FBE
        LDA.B #$33
        STA.W $2124
        LDA.B #$BB
        STA.W $2123
        LDA.B #$0B
        STA.W $2125
        STZ.W $212A
        STZ.W $212B
        LDA.B #$13
        STA.W $212E
        LDA.B #$04
        STA.W $212F
        LDA.B #$00
        STA.W $2101
        LDA.B #$55
        STA.W $2131
        LDA.B #$02
        STA.W $2130
        LDA.B #$10
        STA.B $84
        LDX.W #$2000
        LDY.W #$0010
        LDA.B #$00
        JSL.L fillVRAMRegion
        PLP
        RTL
; [Init] Sets up memory from $0E03 index: copies $1F:A800 data, configures $7F:CF00, calls tilemap setup
initBattleDataRegion: ; $008FFE
        REP #$20
        LDA.W #$001F
        STA.B $14
        LDA.W #$A800
        STA.B $12
        LDA.W $0E03
        JSR.W adjustDataPointer
        LDA.W #$007F
        STA.B $18
        LDA.W #$CF00
        STA.B $16
        LDA.W #$0040
        JSL.L memcpyWords
        LDA.W #$007F
        STA.B $14
        LDA.W #$CF00
        STA.B $12
        LDA.W #$000C
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSR.W swapDataPairs
        JSL.L unpackTileProperties
        LDA.W $0E03
        AND.W #$003F
        INC A
        LDX.W #$0000
        LDY.W #$0002
        JSL.L setupTilemapSource_Long
        RTL
; [Init] Places all battle sprites via drawBattleSprite/drawCharacterSprite, loads 5 palettes, mirrors $7FB000
setupBattleScene: ; $00904E
        REP #$20
        LDA.W $0958
        CMP.W #$FFFF
        BNE CODE_80905B
        JMP.W $9135
CODE_80905B: ; $00905B
        CMP.W #$0100
        BCC CODE_80907C
        LDX.W #$2104
        LDY.W #$0040
        JSL.L setTextScrollParams
        LDA.W $095A
        BEQ CODE_809079
        LDX.W #$0104
        LDY.W #$0000
        JSL.L setTextScrollParams
CODE_809079: ; $009079
        JMP.W $9135
CODE_80907C: ; $00907C
        LDA.W $0958
        JSR.W lookupCharacterROMData
        STA.W $095C
        STY.W $095E
        LDA.W $095A
        JSR.W lookupCharacterROMData
        STA.W $0960
        STY.W $0962
        LDA.W $0962
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        CLC
        ADC.W $095E
        TAX
        LDA.L $09C000,X
        AND.W #$00FF
        STA.W $09D8
        JSR.W updateBattleGraphics
        LDA.W $095C
        INC A
        LDY.W #$0001
        LDX.W #$4000
        JSL.L setupTilemapSource_Long
        LDA.W $095E
        INC A
        INC A
        LDY.W #$0003
        LDX.W #$48C0
        JSL.L setupTilemapSource_Long
        LDA.W $0960
        INC A
        LDY.W #$0001
        LDX.W #$3000
        JSL.L setupTilemapSource_Long
        LDA.W $0962
        INC A
        INC A
        LDY.W #$0003
        LDX.W #$38C0
        JSL.L setupTilemapSource_Long
        LDA.W $09D8
        CMP.W #$0080
        BCS CODE_809103
        AND.W #$003F
        CLC
        ADC.W #$0079
        LDY.W #$0003
        LDX.W #$3C00
        JSL.L setupTilemapSource_Long
CODE_809103: ; $009103
        LDA.W #$0002
        STA.B $00
        LDA.W $095C
        JSR.W uploadCharacterPalette
        LDA.W $095E
        CLC
        ADC.W #$0040
        JSR.W uploadCharacterPalette
        LDA.W $0960
        JSR.W uploadCharacterPalette
        LDA.W $0962
        CLC
        ADC.W #$0040
        JSR.W uploadCharacterPalette
        LDA.W $09D8
        AND.W #$003F
        CLC
        ADC.W #$00B8
        JSR.W uploadCharacterPalette
        RTS
; [Palette] Computes CGRAM offset from $7EEA84 + A, calls uploadPaletteCGRAM
uploadCharacterPalette: ; $009136
        REP #$20
        PHA
        LDA.W #$002F
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.L $7EEA84
        AND.W #$000F
        STA.B $04
        PLA
        STA.B $06
        ASL A
        CLC
        ADC.B $06
        CLC
        ADC.B $04
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        CLC
        ADC.B $12
        STA.B $12
        LDA.W #$0001
        STA.B $02
        JSL.L uploadPaletteWrapper
        INC.B $00
        RTS
; [Helper] Extracts upper 2 bits of A into $00, lower 6 into $01, adds $00 to $12
adjustDataPointer: ; $00916C
        PHA
        AND.W #$00C0
        STA.B $00
        PLA
        SEP #$20
        AND.B #$3F
        STA.B $01
        REP #$20
        LDA.B $12
        CLC
        ADC.B $00
        STA.B $12
        RTS
; [Entity] A*4 index into ROM table $2296E5; returns 7-bit value in Y and shifted word in $00
lookupCharacterROMData: ; $009183
        ASL A
        ASL A
        TAX
        LDA.L $7FC003
        AND.W #$00F0
        BEQ CODE_809195
        TXA
        CLC
        ADC.W #$0400
        TAX
CODE_809195: ; $009195
        LDA.L $2296E5,X
        STA.B $00
        AND.W #$007F
        TAY
        LDA.B $00
        ASL A
        STA.B $00
        LDA.B $01
        AND.W #$003F
        RTS
; [Helper] Byte-swaps pairs in [$12] for $02*16 iterations: swaps bytes at Y and Y+1
swapDataPairs: ; $0091AA
        LDA.B $02
        ASL A
        ASL A
        ASL A
        ASL A
        TAX
        LDY.W #$0000
CODE_8091B4: ; $0091B4
        LDA.B [$12],Y
        STA.B $05
        SEP #$20
        LDA.B $06
        STA.B $04
        REP #$20
        LDA.B $04
        STA.B [$12],Y
        INY
        INY
        DEX
        BNE CODE_8091B4
        RTS
; [OAM] Updates battle scene graphics including backgrounds and sprites. Entry: called during battle. Sets up multiple OAM entries.
updateBattleGraphics: ; $0091CA
        PHP
        REP #$20
        LDX.W #$0104
        LDA.W #$0A00
        STA.B $28
        LDA.W #$000E
        STA.B $22
        LDA.W #$000A
        STA.B $24
        LDA.W $095C
        JSR.W drawBattleSprite
        LDA.B $28
        CLC
        ADC.W #$0400
        STA.B $28
        LDA.W #$0003
        STA.B $24
        LDA.W #$0000
        JSR.W drawBattleSprite
        LDX.W #$0120
        LDA.W #$1100
        STA.B $28
        LDA.W #$000E
        STA.B $22
        LDA.W #$000A
        STA.B $24
        LDA.W $0960
        JSR.W drawCharacterSprite
        LDA.B $28
        CLC
        ADC.W #$0400
        STA.B $28
        LDA.W #$0003
        STA.B $24
        LDA.W #$0000
        JSR.W drawCharacterSprite
        LDX.W #$0104
        LDY.W #$001C
CODE_809229: ; $009229
        LDA.L $7FB000,X
        EOR.W #$8000
        STA.L $7FAFC0,X
        LDA.L $7FB040,X
        EOR.W #$8000
        STA.L $7FAF80,X
        LDA.L $7FB300,X
        EOR.W #$8000
        STA.L $7FB340,X
        LDA.L $7FB2C0,X
        EOR.W #$8000
        STA.L $7FB380,X
        INX
        INX
        DEY
        BNE CODE_809229
        LDX.W #$0084
        LDY.W #$0011
CODE_809260: ; $009260
        LDA.L $7FB000,X
        EOR.W #$4000
        STA.L $7FAFFE,X
        LDA.L $7FB002,X
        EOR.W #$4000
        STA.L $7FAFFC,X
        LDA.L $7FB036,X
        EOR.W #$4000
        STA.L $7FB038,X
        LDA.L $7FB034,X
        EOR.W #$4000
        STA.L $7FB03A,X
        TXA
        CLC
        ADC.W #$0040
        TAX
        DEY
        BNE CODE_809260
        LDA.W $09D8
        CMP.W #$0080
        BCS CODE_8092E0
        CMP.W #$0040
        BCS CODE_8092C2
        LDX.W #$039E
        LDY.W #$0003
        LDA.W #$19C0
CODE_8092AB: ; $0092AB
        STA.L $7FB000,X
        INC A
        STA.L $7FB002,X
        INC A
        PHA
        TXA
        CLC
        ADC.W #$0040
        TAX
        PLA
        DEY
        BNE CODE_8092AB
        BRA CODE_8092E0
CODE_8092C2: ; $0092C2
        LDX.W #$039E
        LDY.W #$0003
        LDA.W #$59C0
CODE_8092CB: ; $0092CB
        STA.L $7FB002,X
        INC A
        STA.L $7FB000,X
        INC A
        PHA
        TXA
        CLC
        ADC.W #$0040
        TAX
        PLA
        DEY
        BNE CODE_8092CB
CODE_8092E0: ; $0092E0
        LDA.W #$7800
        STA.B $78
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSL.L waitForModeSync
        PLP
        RTS
; [OAM] Draws a single battle sprite with position and tile data. Entry: A=sprite data index, X=OAM slot, $28=base address.
drawBattleSprite: ; $0092F3
        JSR.W getTileDataPointer
        LDA.B $24
        STA.B $00
CODE_8092FA: ; $0092FA
        LDY.B $22
        STX.B $04
CODE_8092FE: ; $0092FE
        LDA.B $28
        INC.B $28
        JSR.W checkTileFlag
        STA.L $7FB000,X
        INX
        INX
        DEY
        BNE CODE_8092FE
        LDA.B $04
        CLC
        ADC.W #$0040
        TAX
        DEC.B $00
        LDA.B $00
        BNE CODE_8092FA
        RTS
; [OAM] Draws character sprite with animation frames. Entry: A=character ID, X=OAM slot, $28=base address.
drawCharacterSprite: ; $00931C
        JSR.W getTileDataPointer
        LDA.B $24
        STA.B $00
        TXA
        CLC
        ADC.W #$001A
        TAX
CODE_809329: ; $009329
        LDY.B $22
        STX.B $04
CODE_80932D: ; $00932D
        LDA.B $28
        INC.B $28
        EOR.W #$4000
        JSR.W checkTileFlag
        STA.L $7FB000,X
        DEX
        DEX
        DEY
        BNE CODE_80932D
        LDA.B $04
        CLC
        ADC.W #$0040
        TAX
        DEC.B $00
        LDA.B $00
        BNE CODE_809329
        TXA
        SEC
        SBC.W #$001A
        TAX
        RTS
        db $A5,$24,$85,$00,$A4,$22,$86,$04,$A5,$28,$E6,$28,$9F,$00,$B0,$7F
        db $E8,$E8,$88,$D0,$F3,$A5,$04,$18,$69,$40,$00,$AA,$C6,$00,$A5,$00
        db $D0,$E2,$60
; [Tilemap] A=idx, returns $12/$14 ptr (bank $21, $C000+A*$28).
getTileDataPointer: ; $009377
        PHA
        LDA.W #$0021
        STA.B $14
        LDA.W #$C000
        STA.B $12
        PLA
        ASL A
        STA.B $00
        ASL A
        ASL A
        ASL A
        CLC
        ADC.B $00
        CLC
        ADC.B $12
        STA.B $12
        LDA.W #$0001
        STA.B $06
        RTS
; [Tilemap] A=bit mask, $12/$14=ptr. Returns A+$0400 if flag.
checkTileFlag: ; $009397
        STA.B $08
        LDA.B [$12]
        AND.B $06
        BEQ CODE_8093A7
        LDA.W #$0400
        CLC
        ADC.B $08
        STA.B $08
CODE_8093A7: ; $0093A7
        LDA.B $06
        ASL A
        CMP.W #$0100
        BNE CODE_8093B4
        INC.B $12
        LDA.W #$0001
CODE_8093B4: ; $0093B4
        STA.B $06
        LDA.B $08
        RTS
; [MainLoop] Main game loop - handles frame updates, input, game logic. Entry: called each frame. Calls input, sound, and game state updates.
mainGameLoop: ; $0093B9
        PHP
        SEP #$20
        JSL.L initMapScene
        SEP #$20
        JSL.L clearBGTilemapVRAM
        JSL.L waitForButton
        LDA.B #$81
        STA.W $4200
        LDA.B #$00
        STA.L $7EA000
        SEP #$20
        STZ.B $6B
        STZ.B $6D
        REP #$20
        LDA.W #$002E
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.B $6F
        BEQ CODE_8093F5
        LDA.W #$002E
        STA.B $14
        LDA.W #$9000
        STA.B $12
CODE_8093F5: ; $0093F5
        LDX.W #$6000
        LDY.W #$1000
        JSL.L dmaToVRAMGeneric
        LDA.W #$0003
        STA.B $14
        LDA.W #$8340
        STA.B $12
        LDX.W #$6800
        LDY.W #$0800
        JSL.L dmaToVRAMGeneric
        LDA.W #$0000
        STA.B $14
        LDA.W #$0D80
        STA.B $12
        LDA.W #$0000
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L uploadPaletteWrapper
        REP #$20
        LDA.B $6F
        PHA
        STZ.B $6F
        JSL.L setEventFlag
        PLA
        STA.B $6F
        LDA.W #$E800
        LDX.W #$0000
        LDY.W #$0080
CODE_809442: ; $009442
        STA.W $0100,X
        INX
        INX
        INX
        INX
        DEY
        BNE CODE_809442
        LDX.W #$7000
        LDY.W #$1000
        LDA.W #$0000
        JSL.L fillVRAMRegion
        PLP
        RTS
; [Palette] Byte-pair swap to $0C00, then calls uploadPaletteCGRAM
swapBytePairsAndUploadPalette: ; $00945B
        PHP
        REP #$20
        LDA.W #$0000
        STA.B $18
        LDA.W #$0C00
        STA.B $16
        LDY.W #$0000
        LDA.B $02
        ASL A
        ASL A
        ASL A
        ASL A
        TAX
        SEP #$20
CODE_809474: ; $009474
        LDA.B [$12],Y
        INY
        STA.B [$16],Y
        LDA.B [$12],Y
        DEY
        STA.B [$16],Y
        INY
        INY
        DEX
        BNE CODE_809474
        SEP #$20
        LDA.B #$00
        PHA
        REP #$20
        LDA.W #$0C00
        PHA
        SEP #$20
        LDA.B $02
        ASL A
        ASL A
        ASL A
        ASL A
        PHA
        LDA.B $00
        ASL A
        ASL A
        ASL A
        ASL A
        PHA
        REP #$20
        JSR.W uploadPaletteCGRAM
        TSC
        CLC
        ADC.W #$0005
        TCS
        PLP
        RTL
; [Palette] Pushes 4 params from $14/$12/$02/$00, calls uploadPaletteCGRAM
uploadPaletteWrapper: ; $0094AB
        PHP
        SEP #$20
        LDA.B $14
        PHA
        REP #$20
        LDA.B $12
        PHA
        SEP #$20
        LDA.B $02
        ASL A
        ASL A
        ASL A
        ASL A
        PHA
        LDA.B $00
        ASL A
        ASL A
        ASL A
        ASL A
        PHA
        REP #$20
        JSR.W uploadPaletteCGRAM
        TSC
        CLC
        ADC.W #$0005
        TCS
        PLP
        RTL
; [Init] Full PPU init: CGWSEL, CGADSUB, windows, color math, updateDepthEffect, H/V timer, NMI+IRQ enable
initPPUAndInterrupts: ; $0094D3
        SEI
        PHP
        REP #$20
        LDA.W #$0000
        JSL.L updateDepthEffect
        LDA.W #$0001
        JSL.L handleCutscene
        SEP #$20
        INC.B $6A
        LDA.B #$54
        STA.W $06F3
        LDA.B #$02
        STA.W $2130
        LDA.B #$41
        STA.W $2131
        LDA.B #$FF
        STA.W $2126
        LDA.B #$00
        STA.W $2127
        LDA.B #$FF
        STA.W $2128
        LDA.B #$00
        STA.W $2129
        LDA.B #$3B
        STA.W $2124
        LDA.B #$BB
        STA.W $2123
        LDA.B #$0B
        STA.W $2125
        STZ.W $212A
        STZ.W $212B
        LDA.B #$17
        STA.W $212E
        LDA.B #$17
        STA.W $212F
        LDA.B #$50
        STA.B $84
        REP #$20
        LDA.W #$00FA
        STA.W $4207
        LDA.W #$00A5
        STA.B $66
        STA.W $4209
        LDA.W #$0413
        STA.B $74
        SEP #$20
        LDA.B #$B1
        STA.W $4200
        PLP
        CLI
        RTL
; [Timer] Increments a counter in RAM. Entry: A=counter value. Stores incremented value at $81.
incrementCounter: ; $00954E
        SEP #$20
        INC A
        STA.B $81
        REP #$20
        RTS
; [AI] Processes enemy AI logic for battle. Entry: reads enemy data from $7EEA8C, processes AI scripts from ROM table $0BE579.
processEnemyAI: ; $009556
        REP #$20
        LDX.W #$0000
        LDA.L $7EEA8C
        STA.B $22
CODE_809561: ; $009561
        LDA.B $22
        BEQ CODE_8095AB
        LDA.L $0BE579,X
        STA.B $00
        BEQ CODE_8095AB
        LDA.L $0BE57B,X
        CMP.W #$8000
        BCC CODE_809594
        PHX
        AND.W #$FF00
        CMP.W #$F000
        BCS CODE_8095A3
        JSR.W doubleByteToIndex
        LDA.L $7F0000,X
        AND.W #$FC00
        ORA.W #$00A0
        STA.L $7F0000,X
        DEC.B $22
        BRA CODE_8095A3
CODE_809594: ; $009594
        PHX
        JSR.W doubleByteToIndex
        LDA.L $7F0000,X
        ORA.W #$2000
        STA.L $7F0000,X
CODE_8095A3: ; $0095A3
        PLA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_809561
CODE_8095AB: ; $0095AB
        STX.W $09C0
        RTL
; [Physics] Calculates damage in battle based on attacker/defender stats. Entry: A=attacker ID, X=defender ID. Returns A=damage amount.
calculateBattleDamage: ; $0095AF
        REP #$20
        LDY.W #$0014
CODE_8095B4: ; $0095B4
        PHY
        JSL.L renderSprites
        JSL.L waitForModeSync
        PLY
        DEY
        BNE CODE_8095B4
        JSL.L processEnemyAI
        TXA
        CLC
        ADC.W #$0004
        TAX
        STX.W $09C4
CODE_8095CE: ; $0095CE
        LDA.L $0BE579,X
        STA.B $00
        BEQ CODE_809607
        LDA.L $0BE57B,X
        CMP.W #$8000
        BCS CODE_809607
        PHX
        JSR.W doubleByteToIndex
        LDA.L $7F0000,X
        ORA.W #$2000
        STA.L $7F0000,X
        JSL.L evtScrollInitFullLong
        LDA.W #$0003
        JSR.W incrementCounter
        LDA.W #$0003
        JSL.L repeatModeSync
        PLA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_8095CE
CODE_809607: ; $009607
        LDA.L $7EEA8C
        INC A
        STA.L $7EEA8C
        JSL.L processEnemyAI
        JSL.L evtScrollInitFullLong
        LDA.W #$0002
        JSR.W incrementCounter
        LDX.W $09C4
        LDY.W #$0001
        BRA processEnemyAIData
        db $C2,$20,$5A,$22,$E9,$97,$00,$8A,$18,$69,$04,$00,$AA,$7A
; [AI] Processes enemy AI script data from ROM table $0BE579. Entry: X=AI data index, Y=direction (2=forward, else backward).
processEnemyAIData: ; $009634
        CPY.W #$0002
        BNE CODE_80963E
        LDY.W #$FFFC
        BRA CODE_809641
CODE_80963E: ; $00963E
        LDY.W #$0004
CODE_809641: ; $009641
        STY.B $22
        STX.W $09D0
CODE_809646: ; $009646
        LDA.L $0BE579,X
        STA.B $00
        BEQ CODE_809673
        LDA.L $0BE57B,X
        CMP.W #$8000
        BCS CODE_809673
        CMP.W #$0100
        BCC CODE_809668
        AND.W #$00FF
        STA.L $7EEA82
        CPX.W $09D0
        BNE CODE_809673
CODE_809668: ; $009668
        PHX
        JSR.W handleItemUse
        PLA
        CLC
        ADC.B $22
        TAX
        BRA CODE_809646
CODE_809673: ; $009673
        JSL.L updateMenuCursor
        LDA.B $04
        STA.B $00
        JSR.W handleItemUse
        RTL
; [Menu] Handles item usage in menu or battle. Entry: A=item ID, X=target. Processes item effects, updates inventory.
handleItemUse: ; $00967F
        JSR.W gridToPixelCoords
        LDA.B $00
        STA.W $1806
        LDA.B $02
        STA.W $1808
        STZ.B $24
        STZ.B $26
        LDX.B $24
        LDY.B $26
        JSL.L scrollByDelta
        JSL.L renderSprites
        STZ.B $24
        STZ.B $26
        STZ.B $28
        LDY.W #$0000
        LDA.W $1802
        CMP.W $1806
        BEQ CODE_8096C3
        BCC CODE_8096BA
        LDY.W #$0008
        SEC
        SBC.W #$0002
        INC.B $28
        BRA CODE_8096C3
CODE_8096BA: ; $0096BA
        LDY.W #$0028
        CLC
        ADC.W #$0002
        INC.B $28
CODE_8096C3: ; $0096C3
        STA.W $1802
        SEC
        SBC.B $60
        CMP.W #$0049
        BCS CODE_8096D2
        DEC.B $24
        DEC.B $24
CODE_8096D2: ; $0096D2
        CMP.W #$008F
        BCC CODE_8096DB
        INC.B $24
        INC.B $24
CODE_8096DB: ; $0096DB
        LDA.W $1804
        CMP.W $1808
        BEQ CODE_80971A
        BCC CODE_809704
        SEC
        SBC.W #$0002
        INC.B $28
        CPY.W #$0008
        BNE CODE_8096F5
        LDY.W #$000C
        BRA CODE_80971A
CODE_8096F5: ; $0096F5
        CPY.W #$0028
        BNE CODE_8096FF
        LDY.W #$0024
        BRA CODE_80971A
CODE_8096FF: ; $0096FF
        LDY.W #$0020
        BRA CODE_80971A
CODE_809704: ; $009704
        CLC
        ADC.W #$0002
        INC.B $28
        CPY.W #$0008
        BNE CODE_809712
        LDY.W #$0004
CODE_809712: ; $009712
        CPY.W #$0028
        BNE CODE_80971A
        LDY.W #$002C
CODE_80971A: ; $00971A
        STA.W $1804
        SEC
        SBC.B $62
        CMP.W #$0048
        BCS CODE_809729
        DEC.B $26
        DEC.B $26
CODE_809729: ; $009729
        CMP.W #$0071
        BCC CODE_809732
        INC.B $26
        INC.B $26
CODE_809732: ; $009732
        LDA.B $54
        AND.W #$0004
        STA.B $00
        TYA
        ORA.W #$A000
        LDY.B $00
        BEQ CODE_809745
        CLC
        ADC.W #$0002
CODE_809745: ; $009745
        STA.W $180A
        JSL.L waitForModeSync
        LDA.B $28
        BEQ CODE_809753
        JMP.W $9690
CODE_809753: ; $009753
        RTS
; ASL $00, LDA $00, TAX, RTS. Doubles byte value, returns in X as index.
doubleByteToIndex: ; $009754
        SEP #$20
        ASL.B $00
        REP #$20
        LDA.B $00
        TAX
        RTS
; [Music] Plays background music. Entry: A=music track ID. Sends command to SPC700 via APU ports.
playBGM: ; $00975E
        JSL.L readJoypadNewPress
        JSL.L renderSprites
        JSL.L waitForModeSync
        JSL.L updateMenuCursor
        LDA.B $50
        AND.W #$0100
        BEQ CODE_809779
        INC.B $04
        BRA CODE_8097A2
CODE_809779: ; $009779
        LDA.B $50
        AND.W #$0200
        BEQ CODE_809784
        DEC.B $04
        BRA CODE_8097A2
CODE_809784: ; $009784
        LDA.B $50
        AND.W #$0400
        BEQ CODE_80978F
        INC.B $05
        BRA CODE_8097A2
CODE_80978F: ; $00978F
        LDA.B $50
        AND.W #$0800
        BEQ CODE_80979A
        DEC.B $05
        BRA CODE_8097A2
CODE_80979A: ; $00979A
        LDA.B $50
        AND.W #$F0F0
        BEQ playBGM
        RTL
CODE_8097A2: ; $0097A2
        JSR.W fadeScreen
        CMP.W #$FFFF
        BEQ playBGM
        LDA.W #$01F0
        STA.W $1800
        JSL.L processEnemyAIData
        LDA.W #$0000
        RTL
; [Effects] Screen fade effect (in/out). Entry: A=0 for fade in, 1 for fade out. Updates $2100 brightness gradually.
fadeScreen: ; $0097B8
        REP #$20
        LDX.W #$0000
CODE_8097BD: ; $0097BD
        CPX.W $09C0
        BCS CODE_8097E5
        LDA.L $0BE579,X
        BEQ CODE_8097E5
        STA.B $00
        LDA.L $0BE57B,X
        STA.B $02
        LDA.B $00
        CMP.B $04
        BNE CODE_8097DD
        LDA.B $03
        AND.W #$00FF
        TAY
        RTS
CODE_8097DD: ; $0097DD
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_8097BD
CODE_8097E5: ; $0097E5
        LDA.W #$FFFF
        RTS
; [Menu] Updates menu cursor position and animation. Entry: reads controller input, updates cursor sprite OAM.
updateMenuCursor: ; $0097E9
        REP #$20
        STZ.W $09B2
        LDA.L $7EEA82
        STA.B $00
        LDX.W #$0000
CODE_8097F7: ; $0097F7
        LDA.L $0BE579,X
        STA.B $04
        BEQ CODE_809837
        LDA.L $0BE57B,X
        STA.B $02
        CMP.W #$8000
        BCC CODE_80982F
        STA.W $09B6
        AND.W #$00FF
        CMP.B $00
        BNE CODE_80982F
        LDA.B $03
        AND.W #$00FF
        CMP.W #$00F0
        BCC CODE_809837
        AND.W #$000F
        STA.W $09B2
        LDA.B $05
        AND.W #$00FF
        STA.L $7EEA82
        STA.B $00
CODE_80982F: ; $00982F
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_8097F7
CODE_809837: ; $009837
        LDA.B $04
        STA.B $00
        JSR.W gridToPixelCoords
        RTL
; Convert two bytes at $00/$01 to pixel coords: val*8-4. Store results in $00/$02. RTS.
gridToPixelCoords: ; $00983F
        REP #$20
        LDA.B $01
        AND.W #$00FF
        ASL A
        ASL A
        ASL A
        SEC
        SBC.W #$0004
        STA.B $02
        LDA.B $00
        AND.W #$00FF
        ASL A
        ASL A
        ASL A
        SEC
        SBC.W #$0004
        STA.B $00
        RTS
; A*16=index into $1800 table, zero 16 bytes (8 words). Entity data clear.
clearEntityEntry: ; $00985E
        REP #$20
        ASL A
        ASL A
        ASL A
        ASL A
        TAX
        PHX
        LDY.W #$0008
CODE_809869: ; $009869
        STZ.W $1800,X
        INX
        INX
        DEY
        BNE CODE_809869
        PLX
        LDA.W #$81F0
        STA.W $1800,X
        LDA.B $04
        ORA.W #$2000
        STA.W $180A,X
        LDA.B $00
        STA.W $1802,X
        STA.W $1806,X
        LDA.B $02
        STA.W $1804,X
        STA.W $1808,X
        RTL
; Loop through byte table at $98CC, set sprite tile at $180A, renderSprites, wait 4 frames. Until $FF.
playEntityAnimation: ; $009891
        SEP #$20
        LDA.B #$02
        STA.B $81
        REP #$20
        LDX.W #$0000
        LDA.W #$01F0
        STA.W $1800
CODE_8098A2: ; $0098A2
        LDA.L $0098CC,X
        AND.W #$00FF
        CMP.W #$00FF
        BEQ CODE_8098C4
        PHX
        ORA.W #$2000
        STA.W $180A
        JSL.L renderSprites
        LDA.W #$0004
        JSL.L repeatModeSync
        PLX
        INX
        BRA CODE_8098A2
CODE_8098C4: ; $0098C4
        LDA.W #$000F
        JSL.L repeatModeSync
        RTL
        db $00,$04,$08,$0C,$20,$24,$28,$2C,$40,$42,$FF
; [Collision] Checks movement collision with environment. Entry: $09B4=offset, calls checkCollision, updates position.
checkMovementCollision: ; $0098D7
        REP #$20
        LDA.W $09B4
        CLC
        ADC.W #$0201
        STA.B $00
        JSR.W gridToPixelCoords
        LDA.B $60
        CLC
        ADC.B $00
        STA.B $00
        LDA.B $62
        CLC
        ADC.B $02
        STA.B $02
        STZ.B $04
        LDA.W #$0000
        JSL.L clearEntityEntry
CODE_8098FC: ; $0098FC
        JSL.L readJoypadNewPress
        JSL.L renderSprites
        JSL.L waitForModeSync
        LDY.W $09B2
        LDA.B $50
        AND.W $09BA
        BNE CODE_809922
        LDA.B $50
        AND.W $09BC
        BNE CODE_80992B
        LDA.B $50
        AND.W #$F0F0
        BNE CODE_809935
        BRA CODE_8098FC
CODE_809922: ; $009922
        TYA
        INC A
        CMP.W $09B8
        BEQ CODE_8098FC
        BRA CODE_80992F
CODE_80992B: ; $00992B
        TYA
        BEQ CODE_8098FC
        DEC A
CODE_80992F: ; $00992F
        STA.W $09B2
        LDA.W #$0000
CODE_809935: ; $009935
        RTL
        db $02,$00,$00,$00,$FD,$FF,$00,$00,$FE,$FF,$00,$00,$FE,$FF,$00,$00
        db $FF,$FF,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00
        db $00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00
        db $01,$00,$00,$00,$02,$00,$00,$00,$02,$00,$00,$00,$03,$00,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$03,$00,$00,$00
        db $FD,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF
        db $01,$00,$FE,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        db $00,$00,$FC,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        db $00,$00,$FE,$FF,$00,$00,$FF,$FF
; [Dialogue] Draws text dialog box on screen. Entry: $12/$14=text pointer, $00/$02=screen position. Renders text with window effect.
drawDialogBox: ; $009A1E
        REP #$20
        CPY.W #$0006
        BNE CODE_809A2B
        LDY.W #$00F0
        JMP.W $9D3A
CODE_809A2B: ; $009A2B
        CPY.W #$0007
        BNE CODE_809A36
        LDY.W #$0000
        JMP.W $9D3A
CODE_809A36: ; $009A36
        CPY.W #$0008
        BNE CODE_809A3E
        JMP.W $9C26
CODE_809A3E: ; $009A3E
        CPY.W #$0009
        BNE CODE_809A46
        JMP.W $9B79
CODE_809A46: ; $009A46
        CPY.W #$000A
        BNE CODE_809A4E
        JMP.W $9C47
CODE_809A4E: ; $009A4E
        CPY.W #$000B
        BNE CODE_809A56
        JMP.W $9B19
CODE_809A56: ; $009A56
        CPY.W #$000C
        BNE CODE_809A5E
        JMP.W $9ABB
CODE_809A5E: ; $009A5E
        PHX
        STZ.B $24
        LDX.W #$99B6
        CPY.W #$0000
        BNE CODE_809A6C
        LDX.W #$9936
CODE_809A6C: ; $009A6C
        CPY.W #$0001
        BNE CODE_809A74
        db $A2,$82,$99
CODE_809A74: ; $009A74
        STX.B $22
        LDA.B [$22]
        AND.W #$00FF
        STA.B $26
        INC.B $22
        INC.B $22
        PLX
CODE_809A82: ; $009A82
        LDY.W #$0000
CODE_809A85: ; $009A85
        LDA.B [$22],Y
        CMP.W #$FFFF
        BEQ CODE_809AB6
        STA.B $00
        INY
        INY
        LDA.B [$22],Y
        STA.B $02
        INY
        INY
        PHY
        PHX
        LDA.W $1802,X
        CLC
        ADC.B $00
        STA.W $1802,X
        LDA.W $1804,X
        CLC
        ADC.B $02
        STA.W $1804,X
        JSL.L renderSprites
        JSL.L waitForModeSync
        PLX
        PLY
        BRA CODE_809A85
CODE_809AB6: ; $009AB6
        DEC.B $26
        BNE CODE_809A82
        RTL
        REP #$20
        STX.W $09C8
        LDA.W $1804,X
        STA.W $09CA
        LDA.B $62
        SEC
        SBC.W #$0010
        BCS CODE_809AD1
        LDA.W #$0001
CODE_809AD1: ; $009AD1
        STA.W $1804,X
        LDA.W $1800,X
        ORA.W #$00F0
        STA.W $1800,X
CODE_809ADD: ; $009ADD
        JSL.L renderSprites
        JSL.L waitForModeSync
        LDX.W $09C8
        LDA.W $1804,X
        CLC
        ADC.W #$0006
        CMP.W $09CA
        BCS CODE_809B07
        STA.W $1804,X
        STA.B $00
        LDA.W $09CA
        SEC
        SBC.B $00
        ORA.W #$8000
        STA.W $1808,X
        BRA CODE_809ADD
CODE_809B07: ; $009B07
        LDA.W $09CA
        STA.W $1804,X
        STZ.W $1808,X
        JSL.L renderSprites
        JSL.L waitForModeSync
        RTL
        REP #$20
        STX.W $09C8
        LDA.W $1804,X
        STA.W $09CC
        LDA.B $62
        SEC
        SBC.W #$0010
        BCS CODE_809B2F
        LDA.W #$0001
CODE_809B2F: ; $009B2F
        STA.W $09CA
CODE_809B32: ; $009B32
        LDX.W $09C8
        LDA.W $1804,X
        CMP.W $09CA
        BCC CODE_809B5E
        SEC
        SBC.W #$0006
        BCC CODE_809B5E
        STA.W $1804,X
        STA.B $00
        LDA.W $09CC
        SEC
        SBC.B $00
        ORA.W #$8000
        STA.W $1808,X
        JSL.L renderSprites
        JSL.L waitForModeSync
        BRA CODE_809B32
CODE_809B5E: ; $009B5E
        LDA.W $1800,X
        AND.W #$FF00
        STA.W $1800,X
        LDA.W $09CC
        STA.W $1804,X
        STZ.W $1808,X
        JSL.L renderSprites
        JSL.L waitForModeSync
        RTL
        REP #$20
        LDA.W $1802,X
        SEC
        SBC.B $60
        STA.B $00
        LDA.W $1804,X
        SEC
        SBC.B $62
        SEC
        SBC.W #$000F
        STA.B $01
        LDA.B $00
        STA.W $09CA
        LDA.W #$39CA
        LDY.W #$0004
        JSR.W renderSpriteFrames
        LDA.W #$39E0
        LDY.W #$0004
        JSR.W renderSpriteFrames
        LDA.W #$39E5
        LDY.W #$0004
        JSR.W renderSpriteFrames
        LDA.W #$39EA
        LDY.W #$0004
        JSR.W renderSpriteFrames
        JSL.L renderSprites
        JSL.L waitForModeSync
        RTL
; [Animation] Renders sprite A at OAM slot for Y frames with waitForModeSync each
renderSpriteFrames: ; $009BC1
        STA.W $09C8
CODE_809BC4: ; $009BC4
        PHY
        JSL.L renderSprites
        LDA.W $09CA
        STA.B $00
        LDA.W $09C8
        LDY.W #$0000
        JSR.W setupSpriteOAM
        JSL.L waitForModeSync
        PLY
        DEY
        BNE CODE_809BC4
        RTS
; [OAM] Sets up OAM entries for a sprite with 4 tiles (2x2). Entry: A=tile number, $00=X pos, Y=OAM slot. Creates 4 OAM entries.
setupSpriteOAM: ; $009BE0
        STA.W $0106,Y
        CLC
        ADC.W #$0002
        STA.W $010A,Y
        CLC
        ADC.W #$0002
        STA.W $0102,Y
        CLC
        ADC.W #$0010
        STA.W $010E,Y
        LDA.B $00
        STA.W $0100,Y
        CLC
        ADC.W #$0008
        STA.W $0104,Y
        SEC
        SBC.W #$0008
        CLC
        ADC.W #$0800
        STA.W $0108,Y
        CLC
        ADC.W #$0810
        STA.W $010C,Y
        TYA
        LSR A
        LSR A
        LSR A
        LSR A
        TAY
        SEP #$20
        LDA.B #$28
        STA.W $0300,Y
        REP #$20
        RTS
        REP #$20
        LDY.W #$0010
CODE_809C2B: ; $009C2B
        PHY
        LDA.W $1802,X
        EOR.W #$0008
        STA.W $1802,X
        PHX
        JSL.L renderSprites
        LDA.W #$0002
        JSL.L repeatModeSync
        PLX
        PLY
        DEY
        BNE CODE_809C2B
        RTL
        REP #$20
        STX.W $09CC
        STZ.W $096C
        LDA.W $180A,X
        STA.W $09CE
        LDA.W $1802,X
        SEC
        SBC.B $60
        CLC
        ADC.W #$0004
        STA.B $00
        LDA.W $1804,X
        SEC
        SBC.B $62
CODE_809C67: ; $009C67
        TAY
        SEC
        SBC.W #$0010
        BMI CODE_809C73
        INC.W $096C
        BRA CODE_809C67
CODE_809C73: ; $009C73
        STY.B $01
        LDA.B $00
        STA.W $096E
        LDX.W #$0200
        LDA.W #$AAAA
CODE_809C80: ; $009C80
        STA.W $0100,X
        INX
        INX
        CPX.W #$0208
        BNE CODE_809C80
        LDA.W $096C
        BEQ CODE_809CA9
        LDA.W #$0001
CODE_809C92: ; $009C92
        PHA
        LDY.W #$0001
        JSR.W handleBattleAnimation
        PLA
        INC A
        CMP.W $096C
        BCC CODE_809C92
        LDA.W $096C
        LDY.W #$0028
        JSR.W handleBattleAnimation
CODE_809CA9: ; $009CA9
        JSL.L renderSprites
        RTL
; [Animation] Handles battle animation selection. Entry: A=animation type, Y=animation data. Selects between different animation sets.
handleBattleAnimation: ; $009CAE
        STY.W $09C8
        STA.W $09CA
CODE_809CB4: ; $009CB4
        LDA.W $09CA
        CMP.W $096C
        BNE CODE_809CDC
        LDY.W $09CE
        LDA.W $09C8
        AND.W #$0002
        BEQ CODE_809CD5
        LDY.W #$2AAA
        LDA.W $09C8
        AND.W #$0004
        BEQ CODE_809CD5
        LDY.W #$2B6A
CODE_809CD5: ; $009CD5
        LDX.W $09CC
        TYA
        STA.W $180A,X
CODE_809CDC: ; $009CDC
        JSL.L renderSprites
        LDY.W #$0000
        LDA.W $09CA
        STA.B $00
        LDA.W $096E
        STA.B $02
        LDA.W $09C8
        AND.W #$0001
        BEQ CODE_809CFD
        LDA.B $02
        SEC
        SBC.W #$0800
        STA.B $02
CODE_809CFD: ; $009CFD
        LDA.B $02
        STA.W $0100,Y
        CLC
        ADC.W #$1000
        STA.B $02
        JSL.L getRandomValue
        AND.W #$0006
        TAX
        LDA.W $9D32,X
        STA.W $0102,Y
        TYA
        CLC
        ADC.W #$0004
        TAY
        DEC.B $00
        LDA.B $00
        BNE CODE_809CFD
        LDA.W #$0002
        JSL.L repeatModeSync
        DEC.W $09C8
        LDA.W $09C8
        BNE CODE_809CB4
        RTS
        db $8A,$3B,$8C,$3B,$8E,$3B,$AC,$3B
        REP #$20
        STY.W $09D0
        STX.W $09D4
        STZ.W $09D2
        LDX.W #$0000
CODE_809D48: ; $009D48
        PHX
        LDA.W #$00F0
        CPX.W #$0000
        BNE CODE_809D54
        LDA.W #$0000
CODE_809D54: ; $009D54
        EOR.W $09D0
        STA.B $00
        LDX.W $09D4
        LDA.W $1800,X
        AND.W #$FF00
        ORA.B $00
        STA.W $1800,X
        JSL.L renderSprites
        JSL.L waitForModeSync
        PLX
        INX
        LDA.W $09D2
        LSR A
        LSR A
        LSR A
        INC A
        STA.B $00
        CPX.B $00
        BCC CODE_809D84
        LDX.W #$0000
        INC.W $09D2
CODE_809D84: ; $009D84
        LDA.W $09D2
        CMP.W #$0028
        BNE CODE_809D48
        RTL
; [Effects] Animates battle visual effect (spell, attack). Entry: A=effect type. Updates OAM for effect animation over multiple frames.
animateBattleEffect: ; $009D8D
        REP #$20
        LDY.W #$0000
        CMP.W #$000E
        BEQ CODE_809DC7
CODE_809D97: ; $009D97
        LDX.W #$0000
        JSR.W renderConditionalSprite
        INY
        LDA.W $096C
        CLC
        ADC.W #$0800
        STA.W $096C
        CMP.W $096E
        BCC CODE_809D97
        LDA.W $096E
        STA.W $096C
        LDY.W #$0032
CODE_809DB6: ; $009DB6
        LDX.W #$0000
        JSR.W renderConditionalSprite
        DEY
        BNE CODE_809DB6
        SEP #$20
        LDA.B #$1D
        STA.B $81
        REP #$20
CODE_809DC7: ; $009DC7
        LDA.W $096E
        STA.W $096C
        LDA.W $096C
        SEC
        SBC.W #$0800
        STA.W $096C
        LDX.W #$001F
        LDY.W #$0004
        LDA.W #$0008
        JSL.L initWeatherSlots
        LDY.W #$0064
CODE_809DE7: ; $009DE7
        PHY
        TYA
        AND.W #$0007
        BNE CODE_809E27
        JSL.L getRandomValue
        AND.W #$0038
        CLC
        ADC.W #$1200
        TAX
        JSL.L getRandomValue
        AND.W #$000F
        STA.B $00
        JSL.L getRandomValue
        AND.W #$001F
        STA.B $01
        LDA.W $096C
        CLC
        ADC.B $00
        STA.W $0000,X
        LDA.W #$0000
        STA.W $0002,X
        LDA.W #$0002
        STA.W $0004,X
        LDA.W #$0000
        STA.W $0006,X
CODE_809E27: ; $009E27
        LDX.W #$0008
        JSR.W tickRenderAndNav
        PLY
        DEY
        BNE CODE_809DE7
        JSL.L renderSprites
        JSL.L waitForModeSync
        RTL
; [Animation] Single frame: renderSprites + animateSpriteFrames + waitForModeSync
tickRenderAndNav: ; $009E3A
        PHX
        JSL.L renderSprites
        PLX
        LDY.W #$0000
        JSL.L animateSpriteFrames
        JSL.L waitForModeSync
        RTS
; [OAM] Conditionally writes OAM entry based on $54 flags; renders sprite from $096C/$3BC0
renderConditionalSprite: ; $009E4C
        PHY
        PHX
        JSL.L renderSprites
        LDA.W $096C
        STA.B $00
        LDA.W #$3BC0
        STA.B $02
        LDA.B $54
        AND.W #$0001
        BNE CODE_809E66
        PLX
        BRA CODE_809E7B
CODE_809E66: ; $009E66
        LDA.B $54
        AND.W #$0002
        BEQ CODE_809E75
        LDA.B $02
        CLC
        ADC.W #$0005
        STA.B $02
CODE_809E75: ; $009E75
        LDA.B $02
        PLY
        JSR.W setupSpriteOAM
CODE_809E7B: ; $009E7B
        JSL.L waitForModeSync
        PLY
        RTS
; [Entity] Searches $7FC0C8+$1400 tables for closest entity by Manhattan distance; result in $096E
findNearestEntity: ; $009E81
        REP #$20
        LDX.W #$0000
        LDA.W #$03E7
        STA.B $06
        STZ.W $096E
CODE_809E8E: ; $009E8E
        LDA.L $7FC0C8,X
        BNE CODE_809E95
        RTL
CODE_809E95: ; $009E95
        STA.B $04
        LDA.L $7FC0CA,X
        CMP.W #$1800
        BEQ CODE_809EA8
CODE_809EA0: ; $009EA0
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_809E8E
CODE_809EA8: ; $009EA8
        PHX
        LDX.W #$0000
        STZ.B $08
CODE_809EAE: ; $009EAE
        LDA.B $08
        CMP.W $091C
        BEQ CODE_809EBF
        LDA.W $1404,X
        CMP.B $04
        BNE CODE_809EBF
        PLX
        BRA CODE_809EA0
CODE_809EBF: ; $009EBF
        TXA
        CLC
        ADC.W #$0020
        TAX
        INC.B $08
        LDA.B $08
        CMP.W #$0020
        BNE CODE_809EAE
        PLX
        LDA.B $04
        AND.W #$00FF
        CMP.B $00
        BCS CODE_809EE1
        STA.B $08
        LDA.B $00
        SEC
        SBC.B $08
        BRA CODE_809EE4
CODE_809EE1: ; $009EE1
        SEC
        SBC.B $00
CODE_809EE4: ; $009EE4
        STA.B $0A
        LDA.B $05
        AND.W #$00FF
        CMP.B $02
        BCS CODE_809EF8
        STA.B $08
        LDA.B $02
        SEC
        SBC.B $08
        BRA CODE_809EFB
CODE_809EF8: ; $009EF8
        SEC
        SBC.B $02
CODE_809EFB: ; $009EFB
        CLC
        ADC.B $0A
        CMP.B $06
        BCS CODE_809F09
        STA.B $06
        LDA.B $04
        STA.W $096E
CODE_809F09: ; $009F09
        BRA CODE_809EA0
; Marks battle grid cells within Manhattan distance range. Sets bit $20 in $7F:0001+X.
markCellsInRange: ; $009F0B
        PHP
        REP #$20
        STZ.B $06
        LDA.W #$0102
        STA.B $12
CODE_809F15: ; $009F15
        SEP #$20
        LDA.B $02
        CMP.B $06
        BCS CODE_809F24
        LDA.B $06
        SEC
        SBC.B $02
        BRA CODE_809F27
CODE_809F24: ; $009F24
        SEC
        SBC.B $06
CODE_809F27: ; $009F27
        STA.B $14
        STZ.B $04
        LDX.B $12
CODE_809F2D: ; $009F2D
        LDA.B $00
        CMP.B $04
        BCS CODE_809F3A
        LDA.B $04
        SEC
        SBC.B $00
        BRA CODE_809F3D
CODE_809F3A: ; $009F3A
        SEC
        SBC.B $04
CODE_809F3D: ; $009F3D
        CLC
        ADC.B $14
        CMP.B $0A
        BCS CODE_809F52
        CMP.B $08
        BCC CODE_809F52
        LDA.L $7F0001,X
        ORA.B #$20
        STA.L $7F0001,X
CODE_809F52: ; $009F52
        INX
        INX
        INX
        INX
        INX
        INX
        LDA.B $04
        INC.B $04
        CMP.L $7FC000
        BNE CODE_809F2D
        LDA.B $06
        INC.B $06
        CMP.L $7FC001
        BEQ CODE_809F74
        INC.B $13
        INC.B $13
        INC.B $13
        BRA CODE_809F15
CODE_809F74: ; $009F74
        PLP
        RTL
; [AI] Clears $7FA000, marks entity positions from $1400/$1800 tables as blocked ($0100)
buildMovementCostMap: ; $009F76
        REP #$20
        LDA.W #$007F
        STA.B $14
        LDA.W #$A000
        STA.B $12
        LDA.W #$1000
        LDX.W #$0000
        JSL.L memfillWords
        JSR.W lookupTilemapEntry
        LDA.B $04
        INC A
        STA.L $7FA000,X
        STA.B $22
        REP #$20
        LDX.W #$0000
        LDA.W #$0010
        STA.B $06
        LDA.W $0E28
        CMP.W #$0010
        BCS CODE_809FAD
        LDX.W #$0200
CODE_809FAD: ; $009FAD
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_809FD1
        LDA.W $1404,X
        AND.W #$00FF
        STA.B $00
        LDA.W $1405,X
        AND.W #$00FF
        STA.B $02
        PHX
        JSR.W calcTilemapIndex
        LDA.W #$0100
        STA.L $7FA000,X
        PLX
CODE_809FD1: ; $009FD1
        TXA
        CLC
        ADC.W #$0020
        TAX
        DEC.B $06
        BNE CODE_809FAD
        JSR.W checkPartyAlive
        JSR.W searchTilemapTable
        JSR.W checkPartyAlive
        LDA.L $7FC013
        STA.B $06
        STZ.B $00
        STZ.B $02
        STZ.B $0E
        LDX.W #$0000
CODE_809FF3: ; $009FF3
        LDA.W $0E28
        CMP.B $0E
        BEQ CODE_80A03B
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_80A03B
        LDA.W $1404,X
        STA.B $00
        CMP.B $06
        BNE CODE_80A01A
        LDA.W $0E28
        CMP.W #$0010
        BCS CODE_80A01A
        LDA.B $0E
        CMP.W #$0010
        BCC CODE_80A03B
CODE_80A01A: ; $00A01A
        SEP #$20
        LDA.B $01
        STA.B $02
        STZ.B $01
        REP #$20
        PHX
        JSR.W calcTilemapIndex
        SEP #$20
        LDA.L $7FA000,X
        STA.L $7FA001,X
        LDA.B #$00
        STA.L $7FA000,X
        REP #$20
        PLX
CODE_80A03B: ; $00A03B
        TXA
        CLC
        ADC.W #$0020
        TAX
        INC.B $0E
        LDA.B $0E
        CMP.W #$0020
        BNE CODE_809FF3
        RTL
; [GameState] Checks if any party members are still alive. Entry: scans party data at $1400. Returns carry clear if all dead.
checkPartyAlive: ; $00A04B
        LDA.W $0E28
        CMP.W #$0010
        BCS CODE_80A0A3
        LDA.W $0E03
        AND.W #$00FF
        CMP.W #$0001
        BEQ CODE_80A0A3
        LDX.W #$0000
        LDA.W #$0010
        STA.B $06
CODE_80A066: ; $00A066
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_80A099
        LDA.W $1403,X
        AND.W #$00FF
        CMP.W #$0001
        BNE CODE_80A099
        LDA.W $1404,X
        AND.W #$00FF
        STA.B $00
        LDA.W $1405,X
        AND.W #$00FF
        STA.B $02
        PHX
        JSR.W calcTilemapIndex
        LDA.L $7F9000,X
        EOR.W #$8000
        STA.L $7F9000,X
        PLX
CODE_80A099: ; $00A099
        TXA
        CLC
        ADC.W #$0020
        TAX
        DEC.B $06
        BNE CODE_80A066
CODE_80A0A3: ; $00A0A3
        RTS
; [Tilemap] Iterates $7FA000 vs $22, toggles bit15 of $7F9000,X.
searchTilemapTable: ; $00A0A4
        STZ.B $02
        INC.B $02
        LDX.W #$0082
        STZ.B $00
        INC.B $00
        STX.B $26
        LDA.L $7FA000,X
        CMP.B $22
        BNE CODE_80A0D5
        PHX
        STX.B $28
        LDA.W #$0002
        JSR.W readTilemapValue
        LDA.W #$FFFE
        JSR.W readTilemapValue
        LDA.W #$0080
        JSR.W readTilemapValue
        LDA.W #$FF80
        JSR.W readTilemapValue
        PLX
CODE_80A0D5: ; $00A0D5
        INX
        INX
        INC.B $00
        LDA.B $00
        CMP.W #$0029
        BEQ CODE_80A0E3
        JMP.W $A0B1
CODE_80A0E3: ; $00A0E3
        LDA.B $26
        CLC
        ADC.W #$0080
        TAX
        INC.B $02
        LDA.B $02
        CMP.W #$001F
        BEQ CODE_80A0F6
        JMP.W $A0AB
CODE_80A0F6: ; $00A0F6
        DEC.B $22
        LDA.B $22
        CMP.W #$0001
        BEQ OAMADDL
        JMP.W searchTilemapTable
; [Helper] OAM Address Registers (Low)
OAMADDL: ; $00A102
        RTS
; [Tilemap] A+$28 offset, reads $7F9000,X, checks bit 15.
readTilemapValue: ; $00A103
        CLC
; [Helper] OAM Data Write Register
OAMDATA: ; $00A104
        ADC.B $28
; [Helper] Mosaic Register
MOSAIC: ; $00A106
        TAX
; [Helper] BG Tilemap Address Registers (BG1)
BG1SC: ; $00A107
        PHX
; [Helper] BG Tilemap Address Registers (BG2)
BG2SC: ; $00A108
        LDA.L $7F9000,X
; [Helper] BG Character Address Registers (BG3&4)
BG34NBA: ; $00A10C
        CMP.W #$8000
; [Helper] BG Scroll Registers (BG2)
BG2HOFS: ; $00A10F
        BCS CODE_80A14E
; [Helper] BG Scroll Registers (BG3)
BG3HOFS: ; $00A111
        AND.W #$01FF
; [Helper] BG Scroll Registers (BG4)
BG4VOFS: ; $00A114
        ASL A
; [Helper] Video Port Control Register
VMAIN: ; $00A115
        ASL A
; [Helper] VRAM Address Registers (Low)
VMADDL: ; $00A116
        TAX
; [Helper] VRAM Address Registers (High)
VMADDH: ; $00A117
        LDA.L $7FE000,X
; [Helper] Mode 7 Matrix Registers
M7A: ; $00A11B
        PHA
; [Helper] Mode 7 Matrix Registers
M7B: ; $00A11C
        AND.W #$000F
; [Helper] Mode 7 Matrix Registers
M7X: ; $00A11F
        STA.B $04
; [Helper] CGRAM Address Register
CGADD: ; $00A121
        PLA
; [Helper] CGRAM Data Write Register
CGDATA: ; $00A122
        AND.W #$00F0
; [Helper] Window Mask Settings Registers
WOBJSEL: ; $00A125
        CMP.B $0C
; [Helper] Window Position Registers (WH1)
WH1: ; $00A127
        BEQ WOBJLOG
; [Helper] Window Position Registers (WH3)
WH3: ; $00A129
        BCS CODE_80A155
; [Helper] Window Mask Logic registers (OBJ)
WOBJLOG: ; $00A12B
        LDA.B $0C
; [Helper] Screen Destination Registers
TS: ; $00A12D
        CMP.W #$0020
; [Helper] Color Math Registers
CGWSEL: ; $00A130
        BEQ CODE_80A14E
; [Helper] Color Math Registers
COLDATA: ; $00A132
        LDA.B $22
; [Helper] Multiplication Result Registers
MPYL: ; $00A134
        SEC
; [Helper] Multiplication Result Registers
MPYM: ; $00A135
        SBC.B $04
; [Helper] Software Latch Register
SLHV: ; $00A137
        BCS OPHCT
; [Helper] VRAM Data Read Register (Low)
VMDATALREAD: ; $00A139
        LDA.W #$0000
; [Helper] Scanline Location Registers (Horizontal)
OPHCT: ; $00A13C
        STA.B $06
; [Helper] PPU Status Register
STAT77: ; $00A13E
        PLX
; [Helper] PPU Status Register
STAT78: ; $00A13F
        LDA.L $7FA000,X
; [Helper] APU IO Registers
APUIO3: ; $00A143
        CMP.B $06
        BCS CODE_80A14D
        LDA.B $06
        STA.L $7FA000,X
CODE_80A14D: ; $00A14D
        RTS
CODE_80A14E: ; $00A14E
        LDA.W #$0002
        STA.B $04
        BRA COLDATA
CODE_80A155: ; $00A155
        PLX
        RTS
; [Helper] TAY, BNE skip, RTL.
skipIfZero: ; $00A157
        REP #$20
        TAY
        BNE CODE_80A15D
        RTL
CODE_80A15D: ; $00A15D
        db $A2,$00,$00,$BF,$00,$F0,$7F,$F0,$3B,$4A,$4A,$4A,$4A,$85,$00,$64
        db $02,$A9,$00,$00,$18,$6D,$3E,$0E,$C6,$01,$D0,$F8,$85,$04,$C0,$03
        db $00,$F0,$1A
; [Helper] WRAM Data Register
WMDATA: ; $00A180
        db $BF
; [Helper] WRAM Address Registers
WMADDL: ; $00A181
        db $00
; [Helper] WRAM Address Registers
WMADDM: ; $00A182
        db $F0
; [Helper] WRAM Address Registers
WMADDH: ; $00A183
        db $7F,$29,$FF,$0F,$38,$E5,$04,$B0,$03,$A9,$00,$00,$C0,$02,$00,$D0
        db $01,$0A,$CD,$08,$0E,$90,$07,$A9,$00,$00,$9F,$00,$A0,$7F,$E8,$E8
        db $E0,$00,$10,$D0,$B8,$6B
; [Menu] Equips item to character. Entry: A=character ID, X=item ID. Updates equipment slots, applies stat bonuses.
equipItem: ; $00A1A9
        REP #$20
        LDA.W #$007F
        STA.B $14
        LDA.W #$F000
        STA.B $12
        LDA.W #$1000
        LDX.W #$0000
        JSL.L memfillWords
        LDX.W #$0000
        LDY.W #$0010
CODE_80A1C5: ; $00A1C5
        PHY
        PHX
        TXA
        LDY.W #$0E00
        JSL.L updateEntityWrapper
        LDA.W $0E00
        AND.W #$00FF
        BEQ CODE_80A232
        LDA.W $0E04
        AND.W #$00FF
        STA.B $00
        LDA.W $0E05
        AND.W #$00FF
        STA.B $02
        LDA.W $0E37
        AND.W #$00FF
        STA.B $0C
        LDA.W $0E48
        AND.W #$00FF
        CLC
        ADC.W #$0001
        STA.B $04
        JSR.W calcTilemapIndex
        LDA.B $04
        INC A
        STA.L $7FA000,X
        STA.B $22
        JSR.W searchTilemapTable
        LDA.W $0E56
        STA.B $06
        JSR.W buyItemShop
        LDX.W #$0000
CODE_80A215: ; $00A215
        LDA.L $7FB000,X
        BEQ CODE_80A22B
        LDA.L $7FF000,X
        CLC
        ADC.W $0E3A
        CLC
        ADC.W #$1000
        STA.L $7FF000,X
CODE_80A22B: ; $00A22B
        INX
        INX
        CPX.W #$1000
        BNE CODE_80A215
CODE_80A232: ; $00A232
        PLX
        PLY
        INX
        DEY
        BNE CODE_80A1C5
        RTL
; [Menu] Unequips item from character. Entry: A=character ID, X=equipment slot. Removes item, recalculates stats.
unequipItem: ; $00A239
        REP #$20
        JSR.W buyItemShop
        LDX.W #$0000
        LDY.W #$0008
        LDA.W #$0000
CODE_80A247: ; $00A247
        STA.W $099E,X
        INX
        INX
        DEY
        BNE CODE_80A247
        LDX.W #$0000
        LDA.W #$0000
        STA.B $06
        LDA.W #$270F
        STA.B $08
CODE_80A25C: ; $00A25C
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_80A29E
        LDA.W $1404,X
        AND.W #$00FF
        STA.B $00
        LDA.W $1405,X
        AND.W #$00FF
        STA.B $02
        LDA.W $1408,X
        STA.B $04
        PHX
        JSR.W calcTilemapIndex
        LDA.L $7FB000,X
        BEQ CODE_80A29D
        LDA.B $06
        ORA.W #$8000
        STA.L $7FB000,X
        LDA.B $06
        ORA.W #$0100
        STA.W $09AE
        LDX.B $06
        LDA.W $099E,X
        INC A
        STA.W $099E,X
CODE_80A29D: ; $00A29D
        PLX
CODE_80A29E: ; $00A29E
        TXA
        CLC
        ADC.W #$0020
        TAX
        INC.B $06
        LDA.B $06
        CMP.W #$0010
        BNE CODE_80A25C
        RTL
; [Menu] Handles item purchase in shop. Entry: A=item ID, X=quantity. Deducts gold, adds to inventory.
buyItemShop: ; $00A2AE
        REP #$20
        LDA.W #$007F
        STA.B $14
        LDA.W #$A000
        STA.B $12
        LDA.W #$007F
        STA.B $18
        LDA.W #$B000
        STA.B $16
        LDA.W #$1000
        JSL.L memcpyWords
        STZ.W $09AE
        LDX.W #$0082
        STX.B $12
        LDA.W #$001E
        STA.B $00
        LDA.W #$0200
        STA.B $04
CODE_80A2DD: ; $00A2DD
        LDA.W #$0028
        STA.B $02
CODE_80A2E2: ; $00A2E2
        LDA.L $7FA000,X
        BEQ CODE_80A2EB
        JSR.W sellItemShop
CODE_80A2EB: ; $00A2EB
        INX
        INX
        DEC.B $02
        BNE CODE_80A2E2
        LDA.B $12
        CLC
        ADC.W #$0080
        STA.B $12
        TAX
        DEC.B $00
        BNE CODE_80A2DD
        RTS
; [Menu] Handles item sale in shop. Entry: A=item ID, X=quantity. Adds gold, removes from inventory.
sellItemShop: ; $00A2FF
        LDY.B $04
        LDA.L $7FAFFE,X
        BNE CODE_80A30C
        TYA
        STA.L $7FAFFE,X
CODE_80A30C: ; $00A30C
        LDA.L $7FB002,X
        BNE CODE_80A317
        TYA
        STA.L $7FB002,X
CODE_80A317: ; $00A317
        LDA.L $7FAF80,X
        BNE CODE_80A322
        TYA
        STA.L $7FAF80,X
CODE_80A322: ; $00A322
        LDA.L $7FB080,X
        BNE CODE_80A32D
        TYA
        STA.L $7FB080,X
CODE_80A32D: ; $00A32D
        LDA.B $06
        CMP.W #$0002
        BCS CODE_80A335
        RTS
CODE_80A335: ; $00A335
        LDA.L $7FAFFC,X
        BNE CODE_80A340
        TYA
        STA.L $7FAFFC,X
CODE_80A340: ; $00A340
        LDA.L $7FB004,X
        BNE CODE_80A34B
        TYA
        STA.L $7FB004,X
CODE_80A34B: ; $00A34B
        LDA.L $7FAF82,X
        BNE CODE_80A356
        TYA
        STA.L $7FAF82,X
CODE_80A356: ; $00A356
        LDA.L $7FAF7E,X
        BNE CODE_80A361
        TYA
        STA.L $7FAF7E,X
CODE_80A361: ; $00A361
        LDA.L $7FB07E,X
        BNE CODE_80A36C
        TYA
        STA.L $7FB07E,X
CODE_80A36C: ; $00A36C
        LDA.L $7FB082,X
        BNE CODE_80A377
        TYA
        STA.L $7FB082,X
CODE_80A377: ; $00A377
        CPX.W #$0F00
        BCS CODE_80A387
        LDA.L $7FB100,X
        BNE CODE_80A387
        TYA
        STA.L $7FB100,X
CODE_80A387: ; $00A387
        CPX.W #$0100
        BCC CODE_80A397
        LDA.L $7FAF00,X
        BNE CODE_80A397
        TYA
        STA.L $7FAF00,X
CODE_80A397: ; $00A397
        RTS
; [Tilemap] calcTilemapIndex, $7F9000,X, AND #$01FF, ASL x2 -> Y.
lookupTilemapEntry: ; $00A398
        JSR.W calcTilemapIndex
        LDA.L $7F9000,X
        PHX
        PHA
        AND.W #$01FF
        ASL A
        ASL A
        TAY
        PLA
        PLX
        RTS
; [Tilemap] ($02 & $1F) << 7 + $00*2 -> X.
calcTilemapIndex: ; $00A3AA
        LDA.B $02
        AND.W #$001F
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        CLC
        ADC.B $00
        CLC
        ADC.B $00
        TAX
        RTS
; [GameState] Initializes new game state. Entry: sets up party, inventory, story flags to starting values.
initNewGame: ; $00A3BE
        REP #$20
        LDA.W #$0008
        STA.B $0A
        LDA.L $7FC016
        AND.W #$00FF
        BEQ CODE_80A3D0
        db $85,$0A
CODE_80A3D0: ; $00A3D0
        LDX.W #$0000
CODE_80A3D3: ; $00A3D3
        LDA.L $7FC0C8,X
        BNE CODE_80A3DA
        RTL
CODE_80A3DA: ; $00A3DA
        STA.B $00
        LDA.L $7FC0CA,X
        CMP.W #$1800
        BNE CODE_80A3EB
        LDA.B $0A
        STA.B $08
        BRA CODE_80A402
CODE_80A3EB: ; $00A3EB
        AND.W #$00FF
        CMP.W #$0040
        BNE CODE_80A3FA
        db $A9,$04,$00,$85,$08,$80,$08
CODE_80A3FA: ; $00A3FA
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_80A3D3
CODE_80A402: ; $00A402
        PHX
        SEP #$20
        LDA.B $01
        STA.B $02
        STZ.B $01
        STZ.B $03
        REP #$20
        JSR.W lookupTilemapEntry
        CMP.B $08
        BEQ CODE_80A419
        PLX
        BRA CODE_80A3FA
CODE_80A419: ; $00A419
        db $FA,$A9,$FF,$FF,$9F,$CA,$C0,$7F,$9F,$C8,$C0,$7F,$80,$D3,$C2,$20
        db $85,$06,$F0,$43,$98,$09,$00,$3F,$85,$04,$A9,$A2,$A4,$85,$12,$B2
        db $12,$85,$06,$64,$08,$E6,$12,$E6,$12,$A2,$00,$00,$A0,$00,$00,$B2
        db $12,$29,$FF,$00,$C9,$FF,$00,$F0,$34,$18,$65,$04,$9F,$00,$B0,$7F
        db $E8,$E8,$E6,$12,$C8,$C4,$06,$D0,$0C,$A5,$08,$18,$69,$40,$00,$85
        db $08,$AA,$A0,$00,$00,$80,$D8,$A2,$00,$00,$A9,$00,$00,$9F,$00,$B0
        db $7F,$E8,$E8,$E0,$00,$08,$D0,$F5,$C0,$00,$08,$B0,$0E,$A9,$00,$70
        db $85,$78,$E2,$20,$A9,$FE,$85,$57,$C2,$20,$6B,$A9,$00,$74,$85,$78
        db $E2,$20,$A9,$FE,$85,$57,$C2,$20,$6B,$07,$00,$20,$21,$22,$23,$24
        db $25,$26,$30,$31,$32,$33,$34,$35,$36,$00,$01,$02,$03,$04,$05,$06
        db $10,$11,$12,$13,$14,$15,$16,$20,$21,$22,$23,$24,$25,$26,$30,$31
        db $32,$33,$34,$35,$36,$00,$01,$02,$03,$04,$05,$06,$10,$11,$12,$13
        db $14,$15,$16,$20,$21,$22,$23,$24,$25,$26,$30,$31,$32,$33,$34,$35
        db $36,$40,$41,$42,$43,$44,$45,$46,$50,$51,$52,$53,$54,$55,$56,$60
        db $61,$62,$63,$64,$65,$66,$70,$71,$72,$73,$74,$75,$76,$77,$77,$07
        db $17,$27,$37,$77,$77,$77,$47,$57,$67,$77,$77,$FF
; [Tilemap] Draws world map or dungeon map. Entry: A=map ID. Loads tilemap, objects, NPCs to VRAM.
drawMap: ; $00A515
        REP #$20
        JSL.L waitForModeSync
        LDA.W $0E6A
        CMP.W #$0001
        BEQ CODE_80A571
        LDA.L $7EEA82
        CMP.W #$0004
        BNE CODE_80A53E
        LDA.W #$001E
        LDX.W #$0000
        JSR.W setupGraphicsMode
        LDA.W #$0A05
        JSL.L initEntityFromData
        BRA CODE_80A571
CODE_80A53E: ; $00A53E
        CMP.W #$000D
        BNE CODE_80A555
        db $A9,$21,$00,$A2,$00,$00,$20,$B4,$A5,$A9,$20,$09,$22,$55,$E1,$01
        db $80,$1C
CODE_80A555: ; $00A555
        CMP.W #$0012
        BNE CODE_80A56C
        db $A9,$09,$03,$A2,$00,$00,$20,$B4,$A5,$A9,$24,$00,$22,$55,$E1,$01
        db $80,$05
CODE_80A56C: ; $00A56C
        CMP.W #$001E
        BEQ CODE_80A572
CODE_80A571: ; $00A571
        RTL
CODE_80A572: ; $00A572
        db $AD,$58,$09,$C9,$BE,$00,$F0,$28,$C9,$BF,$00,$F0,$23,$C9,$C0,$00
        db $F0,$1E,$C9,$C2,$00,$F0,$19,$AD,$5A,$09,$C9,$BE,$00,$F0,$11,$C9
        db $BF,$00,$F0,$0C,$C9,$C0,$00,$F0,$07,$C9,$C2,$00,$F0,$02,$80,$CF
        db $A9,$12,$03,$A2,$00,$01,$20,$B4,$A5,$A9,$20,$09,$22,$55,$E1,$01
        db $80,$BD
; [Init] Sets up graphics mode for specific screen. Entry: calls calculateSlope, sets $2108, $0E20, $0EA0.
setupGraphicsMode: ; $00A5B4
        LDY.W #$0000
        JSL.L setTextScrollParams
        SEP #$20
        LDA.B #$70
        STA.W $2108
        LDA.B #$01
        STA.W $0E20
        STA.W $0EA0
        REP #$20
        RTS
; [HUD] Updates minimap display in corner. Entry: reads player position, draws current area on minimap.
updateMinimap: ; $00A5CD
        REP #$20
        LDA.W #$0008
        STA.W $09E2
        LDX.W #$1200
        LDA.W #$0000
CODE_80A5DB: ; $00A5DB
        STZ.W $0000,X
        INX
        INX
        CPX.W #$1340
        BNE CODE_80A5DB
        RTL
; [Dialogue] Handles NPC dialogue interaction. Entry: A=NPC ID. Loads dialogue text, displays choices if any.
handleNPCDialogue: ; $00A5E6
        LDY.W $09E2
        LDX.W #$1200
        STA.B $00
        LDA.B $02
        CMP.W #$8000
        BCC CODE_80A60B
        AND.W #$7FFF
        ASL A
        ASL A
        ASL A
        ASL A
        CLC
        ADC.W #$1200
        TAX
        LDA.W $0004,X
        ASL A
        ASL A
        STA.W $0004,X
        BRA CODE_80A637
CODE_80A60B: ; $00A60B
        LDA.W $0000,X
        BEQ CODE_80A61A
        TXA
        CLC
        ADC.W #$0010
        TAX
        DEY
        BNE CODE_80A60B
        db $6B
CODE_80A61A: ; $00A61A
        DEC A
        STA.W $0000,X
        PHX
        INX
        INX
        LDY.W #$0007
CODE_80A624: ; $00A624
        STZ.W $0000,X
        INX
        INX
        DEY
        BNE CODE_80A624
        PLX
        LDA.B $02
        STA.W $0002,X
        LDA.B $04
        STA.W $0004,X
CODE_80A637: ; $00A637
        LDA.B $06
        STA.W $000A,X
        LDA.B $00
        BEQ CODE_80A64D
        DEC A
        ASL A
        CLC
        ADC.W #$A86E
        STA.B $12
        LDA.B ($12)
        STA.W $000C,X
CODE_80A64D: ; $00A64D
        RTL
; [OAM] Sets up OAM for large sprite (4x4 tiles). Entry: A=base tile, $00=X pos, Y=OAM slot. Creates 16 OAM entries.
setupLargeSprite: ; $00A64E
        REP #$20
        LDA.W $0A87
        BNE CODE_80A656
        RTL
CODE_80A656: ; $00A656
        LDX.W #$1200
        LDY.W #$0000
CODE_80A65C: ; $00A65C
        LDA.W $0000,X
        BEQ CODE_80A6B8
        DEC A
        STA.W $0000,X
        CMP.W #$0100
        BCS CODE_80A66F
        db $29,$01,$00,$F0,$49
CODE_80A66F: ; $00A66F
        LDA.W $000E,X
        BNE CODE_80A6C4
        LDA.W $0004,X
        CLC
        ADC.W $0008,X
        STA.W $0004,X
        STA.B $02
CODE_80A680: ; $00A680
        LDA.W $0002,X
        CLC
        ADC.W $0006,X
        STA.W $0002,X
        SEC
        SBC.B $60
        CMP.W #$0100
        BCS CODE_80A6B0
        STA.B $00
        LDA.B $02
        SEC
        SBC.B $62
        CMP.W #$00E6
        BCS CODE_80A6B0
        STA.B $01
        LDA.W $000A,X
        CMP.W #$C000
        BCC CODE_80A6AD
        JSR.W setupBattleSprite
        BRA CODE_80A6B0
CODE_80A6AD: ; $00A6AD
        db $20,$38,$A7
CODE_80A6B0: ; $00A6B0
        LDA.W $000C,X
        BEQ CODE_80A6B8
        JSR.W animateCharacter
CODE_80A6B8: ; $00A6B8
        TXA
        CLC
        ADC.W #$0010
        TAX
        CPX.W #$1340
        BNE CODE_80A65C
        RTL
CODE_80A6C4: ; $00A6C4
        CLC
        ADC.W $0008,X
        STA.W $0008,X
        STA.B $06
        LDA.W $0004,X
        CLC
        ADC.B $06
        STA.W $0004,X
        LSR A
        LSR A
        STA.B $02
        BRA CODE_80A680
; [Animation] Handles character walking/running animation. Entry: A=character ID. Updates sprite frames based on movement speed.
animateCharacter: ; $00A6DC
        STA.B $12
        LDA.B ($12)
        BMI CODE_80A70A
        CMP.W #$7000
        BCS CODE_80A72B
        CMP.W #$0010
        BCC CODE_80A6F1
        db $A9,$00,$00,$80,$36
CODE_80A6F1: ; $00A6F1
        STA.B $14
        TXA
        CLC
        ADC.B $14
        STA.B $14
        INC.B $12
        INC.B $12
        LDA.B $12
        INC A
        INC A
        STA.W $000C,X
        LDA.B ($12)
        STA.B ($14)
        RTS
        db $60
CODE_80A70A: ; $00A70A
        STA.B $00
        LDA.W $0000,X
        CMP.B $00
        BEQ CODE_80A71B
        INC.B $12
        INC.B $12
        LDA.B ($12)
        BRA CODE_80A727
CODE_80A71B: ; $00A71B
        LDA.W #$FFFF
        STA.W $0000,X
        LDA.B $12
        CLC
        ADC.W #$0004
CODE_80A727: ; $00A727
        STA.W $000C,X
        RTS
CODE_80A72B: ; $00A72B
        db $29,$FF,$0F,$25,$54,$D0,$D7,$A5,$12,$1A,$1A,$80,$EF,$C2,$20,$99
        db $06,$01,$18,$69,$02,$00,$99,$0A,$01,$18,$69,$02,$00,$99,$02,$01
        db $18,$69,$10,$00,$99,$0E,$01,$A5,$00,$99,$00,$01,$18,$69,$08,$00
        db $99,$04,$01,$38,$E9,$08,$00,$18,$69,$00,$08,$99,$08,$01,$18,$69
        db $10,$08,$99,$0C,$01,$5A,$98,$4A,$4A,$4A,$4A,$A8,$E2,$20,$A9,$28
        db $99,$00,$03,$C2,$20,$7A,$98,$18,$69,$10,$00,$A8,$60
; [OAM] Sets up battle sprite with special attributes. Entry: A=tile data, $00=X pos, Y=OAM slot. Sets up 4 OAM entries with battle flags.
setupBattleSprite: ; $00A788
        REP #$20
        AND.W #$3FFF
        STA.W $0102,Y
        CLC
        ADC.W #$0002
        STA.W $0106,Y
        CLC
        ADC.W #$0003
        STA.W $010A,Y
        CLC
        ADC.W #$0002
        STA.W $010E,Y
        LDA.B $00
        STA.W $0100,Y
        CLC
        ADC.W #$0010
        STA.W $0104,Y
        LDA.B $00
        CLC
        ADC.W #$1000
        STA.W $0108,Y
        CLC
        ADC.W #$0010
        STA.W $010C,Y
        PHY
        TYA
        LSR A
        LSR A
        LSR A
        LSR A
        TAY
        SEP #$20
        LDA.B #$AA
        STA.W $0300,Y
        STZ.B $02
        REP #$20
        PLY
        TYA
        CLC
        ADC.W #$0010
        TAY
        RTS
        db $C2,$20,$A9,$14,$00,$8D,$E2,$09,$A9,$05,$00,$85,$26,$A9,$04,$00
        db $85,$24,$A9,$64,$00,$85,$22,$A9,$C0,$00,$85,$04,$A4,$24,$A5,$22
        db $85,$02,$5A,$22,$72,$DF,$00,$29,$06,$00,$AA,$BD,$66,$A8,$85,$06
        db $A9,$0E,$00,$22,$47,$DF,$00,$18,$69,$07,$00,$85,$08,$A9,$05,$00
        db $22,$47,$DF,$00,$38,$E9,$02,$00,$85,$0A,$A9,$05,$00,$22,$E6,$A5
        db $00,$A5,$0A,$9D,$06,$00,$A9,$00,$00,$38,$E5,$08,$9D,$08,$00,$A9
        db $01,$00,$9D,$0E,$00,$22,$72,$DF,$00,$29,$0F,$00,$49,$FF,$FF,$9D
        db $00,$00,$A5,$02,$18,$69,$1A,$00,$85,$02,$7A,$88,$D0,$A4,$A5,$04
        db $18,$69,$60,$00,$85,$04,$C6,$26,$D0,$92,$6B,$40,$34,$00,$35,$2A
        db $34,$EA,$34,$8A,$A8,$BA,$A8,$CA,$A8,$DA,$A8,$EA,$A8,$04,$A9,$0C
        db $A9,$18,$A9,$24,$A9,$30,$A9,$64,$A9,$74,$A9,$84,$A9,$94,$A9,$06
        db $00,$FF,$FF,$08,$00,$08,$00,$F0,$FF,$92,$A8,$0A,$00,$CA,$39,$08
        db $00,$00,$00,$06,$00,$00,$00,$03,$70,$0A,$00,$E0,$39,$03,$70,$0A
        db $00,$E5,$39,$03,$70,$0A,$00,$EA,$39,$03,$70,$00,$00,$00,$00,$06
        db $00,$FF,$FF,$08,$00,$F8,$FF,$E2,$FF,$C2,$A8,$00,$00,$00,$00,$06
        db $00,$FE,$FF,$08,$00,$F8,$FF,$E2,$FF,$D2,$A8,$00,$00,$00,$00,$06
        db $00,$FD,$FF,$08,$00,$F8,$FF,$E2,$FF,$E2,$A8,$00,$00,$00,$00,$DD
        db $FF,$EA,$A8,$0A,$00,$E0,$39,$03,$70,$0A,$00,$E5,$39,$03,$70,$0A
        db $00,$EA,$39,$03,$70,$00,$00,$00,$00,$0C,$00,$00,$00,$00,$00,$00
        db $00,$06,$00,$00,$00,$0E,$00,$01,$00,$0C,$00,$3C,$A9,$06,$00,$01
        db $00,$0E,$00,$01,$00,$0C,$00,$3C,$A9,$06,$00,$FF,$FF,$0E,$00,$01
        db $00,$0C,$00,$3C,$A9,$0E,$00,$01,$00,$D8,$FF,$34,$A9,$00,$00,$00
        db $00,$EC,$FF,$3C,$A9,$08,$00,$F0,$FF,$D8,$FF,$44,$A9,$08,$00,$F0
        db $FF,$D8,$FF,$4C,$A9,$08,$00,$F0,$FF,$D8,$FF,$54,$A9,$08,$00,$F0
        db $FF,$D8,$FF,$5C,$A9,$00,$00,$00,$00,$06,$00,$FE,$FF,$08,$00,$EE
        db $FF,$0E,$00,$01,$00,$0C,$00,$EA,$A8,$06,$00,$FF,$FF,$08,$00,$E7
        db $FF,$0E,$00,$01,$00,$0C,$00,$EA,$A8,$06,$00,$01,$00,$08,$00,$EA
        db $FF,$0E,$00,$01,$00,$0C,$00,$EA,$A8,$06,$00,$02,$00,$08,$00,$F0
        db $FF,$0E,$00,$01,$00,$0C,$00,$EA,$A8
; [GameState] Reads $7EEA82, CMP #$1F, calls processAIscript(#$02).
scenarioDispatch: ; $00A9A4
        REP #$20
        LDA.L $7EEA82
        CMP.W #$001F
        BNE CODE_80A9B8
        db $A9,$02,$00,$22,$2F,$AA,$00,$80,$0B
CODE_80A9B8: ; $00A9B8
        JSR.W checkAbilityLearned
        CLC
        ADC.W #$0080
        JSL.L processAIscript
        JSR.W checkAbilityLearned
        CLC
        ADC.W #$0021
        SEP #$20
        LDY.W #$0000
        JSL.L externalUtilityFunc2
        LDY.W #$0000
        LDA.B #$AE
        JSL.L spcPlaySfx
        REP #$20
        RTL
; [Entity] Checks if character has learned an ability. Entry: A=character ID, X=ability ID. Returns carry set if learned.
checkAbilityLearned: ; $00A9DF
        LDA.L $7EEA82
        DEC A
        AND.W #$00FF
        TAX
        LDA.W $A9EF,X
        AND.W #$00FF
        RTS
        db $06,$06,$08,$07,$07,$24,$23,$23,$08,$16,$0C,$0C,$0E,$06,$0F,$0F
        db $0F,$0B,$06,$09,$0A,$1F,$09,$0A,$20,$1F,$0D,$0B,$15,$0E,$1B,$28
        db $28,$17,$27,$27,$22,$2B,$23,$09,$23,$08,$06,$08,$07,$1F,$16,$20
        db $0E,$24,$0A,$07,$09,$08,$0B,$23,$07,$08,$06,$07,$06,$06,$06,$06
; [AI] Processes AI script for enemy behavior. Entry: A=enemy ID. Reads script from ROM, executes commands.
processAIscript: ; $00AA2F
        PHP
        REP #$20
        CMP.W $09E4
        BNE CODE_80AA3A
        JMP.W $AAC9
CODE_80AA3A: ; $00AA3A
        STA.W $09E4
        CMP.W #$0080
        BCS CODE_80AA4D
        ASL A
        TAX
        LDA.W $AB17,X
        STA.B $12
        STZ.B $14
        BRA CODE_80AA80
CODE_80AA4D: ; $00AA4D
        LDY.W #$AACB
        CMP.W #$0100
        BCC CODE_80AA58
        LDY.W #$AAF4
CODE_80AA58: ; $00AA58
        STY.B $16
        AND.W #$007F
        CLC
        ADC.W #$0021
        PHA
        LDA.W #$007F
        STA.B $14
        LDA.W #$CE80
        STA.B $12
        LDY.W #$0000
CODE_80AA6F: ; $00AA6F
        LDA.B ($16)
        BEQ CODE_80AA7A
        STA.B [$12],Y
        INC.B $16
        INY
        BRA CODE_80AA6F
CODE_80AA7A: ; $00AA7A
        PLA
        ORA.W #$FF00
        STA.B [$12],Y
CODE_80AA80: ; $00AA80
        SEP #$20
        STZ.B $81
        LDY.W #$0000
        JSL.L externalUtilityFunc3
        LDY.W #$0001
        JSL.L externalUtilityFunc3
        JSL.L spcStartTransfer
        LDA.L $7EEA88
        AND.B #$08
        JSL.L spcPlayMusic
        JSL.L spcBeginTransfer
        JSL.L externalSoundFunc2
        LDA.B $14
        LDY.B $12
        JSL.L spcLoadSampleSet
        LDY.W #$01F4
CODE_80AAB3: ; $00AAB3
        LDA.B #$00
        DEY
        BNE CODE_80AAB3
        LDY.W #$0000
        LDA.B #$AE
        JSL.L spcPlaySfx
        LDY.W #$01F4
CODE_80AAC4: ; $00AAC4
        LDA.B #$00
        DEY
        BNE CODE_80AAC4
        PLP
        RTL
        db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F
        db $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F
        db $20,$26,$33,$22,$25,$46,$47,$00,$00,$00,$01,$02,$03,$04,$05,$06
        db $07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,$10,$11,$12,$13,$14,$15,$16
        db $17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F,$20,$00,$00,$1D,$AB,$33,$AB
        db $39,$AB,$00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D
        db $0E,$0F,$21,$27,$23,$24,$31,$FF,$00,$01,$02,$03,$04,$FF,$00,$01
        db $02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,$10,$11
        db $12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F,$20,$26
        db $33,$22,$25,$46,$47,$3C,$3B,$FF,$C2,$20,$22,$F0,$E3,$00,$64,$00
        db $A5,$50,$29,$00,$01,$F0,$02,$E6,$00,$A5,$50,$29,$00,$02,$F0,$02
        db $C6,$00,$A5,$50,$29,$00,$04,$F0,$05,$A9,$05,$00,$85,$00,$A5,$50
        db $29,$00,$08,$F0,$05,$A9,$FB,$FF,$85,$00,$22,$BE,$E3,$00,$A5,$00
        db $6B,$08,$E2,$20,$18,$69,$21,$8D,$00,$10,$A9,$FF,$8D,$01,$10,$A0
        db $00,$00,$22,$63,$E0,$2B,$22,$F7,$DD,$2B,$22,$E2,$DD,$2B,$22,$C3
        db $DE,$2B,$A9,$00,$A0,$00,$10,$22,$6B,$DF,$2B,$A0,$00,$00,$AD,$00
        db $10,$22,$44,$E0,$2B,$9C,$E4,$09,$28,$6B
; [Effects] Initialize weather/particle slots at $1200. A=count, X=base offset, Y=stride. Fills with $FFFF.
initWeatherSlots: ; $00ABD5
        REP #$20
        STX.W $09EC
        STY.W $09EA
        STZ.W $09E8
        TAY
        LDX.W #$1200
; [Effects] Fill loop: STA $0000,X / ADC #8 / DEY / BNE
initWeatherSlots_Loop: ; $00ABE4
        LDA.W #$FFFF
        STA.W $0000,X
        TXA
        CLC
        ADC.W #$0008
        TAX
        DEY
        BNE initWeatherSlots_Loop
        RTL
; [Effects] Updates weather/lightning visual effects. Entry: sets up effect parameters, calls updateLightningEffect.
updateWeatherEffect: ; $00ABF4
        REP #$20
        LDX.W #$000F
        LDY.W #$0002
        LDA.W #$0020
        JSL.L initWeatherSlots
        LDA.W #$0000
        STA.B $14
        LDA.W #$AC79
        STA.B $12
        LDX.W #$1200
        STZ.B $04
        LDY.W #$0010
CODE_80AC15: ; $00AC15
        PHY
        JSL.L getRandomValue
        AND.W #$0007
        STA.B $00
        JSL.L getRandomValue
        AND.W #$0007
        STA.B $01
        LDA.W $096C
        CLC
        ADC.B $00
        STA.W $0000,X
        LDA.W #$0000
        STA.W $0002,X
        LDA.W #$0002
        STA.W $0004,X
        LDY.B $04
        LDA.B [$12],Y
        STA.W $0006,X
        INY
        INY
        TYA
        AND.W #$001F
        STA.B $04
        TXA
        CLC
        ADC.W #$0008
        TAX
        PLY
        DEY
        BNE CODE_80AC15
        LDY.W #$0018
CODE_80AC59: ; $00AC59
        PHY
        JSL.L renderSprites
        LDX.W #$0010
        LDY.W #$0000
        JSL.L animateSpriteFrames
        JSL.L waitForModeSync
        PLY
        DEY
        BNE CODE_80AC59
        JSL.L renderSprites
        JSL.L waitForModeSync
        RTL
        db $00,$FE,$01,$FE,$02,$FE,$02,$FF,$02,$00,$02,$01,$02,$02,$01,$02
        db $00,$02,$FF,$02,$FE,$02,$FE,$01,$FE,$00,$FE,$FF,$FE,$FE,$FF,$FE
; [Animation] Walks animation table at $1200 ($08 stride), advances frame counters, wraps at $09EA
animateSpriteFrames: ; $00AC99
        REP #$20
        TXA
        ASL A
        ASL A
        ASL A
        TAX
CODE_80ACA0: ; $00ACA0
        TXA
        SEC
        SBC.W #$0008
        TAX
        LDA.W $1200,X
        CMP.W #$FFFF
        BEQ CODE_80ACF4
        STA.W $0100,Y
        STA.B $00
        LDA.W $1202,X
        PHX
        TAX
        LDA.W $AD0C,X
        STA.W $0102,Y
        PLX
        LDA.W $09E8
        BNE CODE_80ACF4
        LDA.W $1206,X
        BEQ CODE_80ACDF
        STA.B $02
        SEP #$20
        LDA.B $00
        CLC
        ADC.B $02
        STA.W $1200,X
        LDA.B $01
        CLC
        ADC.B $03
        STA.W $1201,X
        REP #$20
CODE_80ACDF: ; $00ACDF
        LDA.W $1204,X
        STA.B $00
        SEP #$20
        LDA.W $1202,X
        CLC
        ADC.B $00
        AND.W $09EC
        STA.W $1202,X
        REP #$20
CODE_80ACF4: ; $00ACF4
        TYA
        CLC
        ADC.W #$0004
        TAY
        TXA
        BNE CODE_80ACA0
        INC.W $09E8
        LDA.W $09E8
        CMP.W $09EA
        BNE CODE_80AD0B
        STZ.W $09E8
CODE_80AD0B: ; $00AD0B
        RTL
        db $A0,$3B,$A0,$3B,$A2,$3B,$A2,$3B,$A4,$3B,$A6,$3B,$A8,$3B,$AA,$3B
        db $A8,$3B,$A6,$3B,$A4,$3B,$A2,$3B,$A2,$3B,$A0,$3B,$A0,$3B,$80,$3B
        db $08,$09,$06,$12,$04,$07,$11,$11,$0F,$0E,$0E,$0D,$0C,$1E,$1C
; [Entity] Sums entity stats from $0Exx, caps at 100, indexes ROM table $0BBF64 to load 40-byte records
calcCharStatIndex: ; $00AD3B
        REP #$20
        STZ.B $12
        LDA.W #$0002
        STA.W $09E6
        LDA.L $7EEA82
        CMP.W #$0027
        BNE CODE_80AD51
        STZ.W $09E6
CODE_80AD51: ; $00AD51
        SEP #$20
        LDA.W $0E06
        LSR A
        STA.B $22
        LDA.W $0E86
        LSR A
        LSR A
        LSR A
        CLC
        ADC.B $22
        INC A
        CMP.B #$64
        BCC CODE_80AD69
        db $A9,$63
CODE_80AD69: ; $00AD69
        STA.B $22
        REP #$20
        LDA.W $0E4D
        AND.W #$00FF
        STA.B $14
        LDA.W $0E17
        AND.W #$00FF
        CLC
        ADC.B $14
        STA.B $14
        LDA.W $0ECE
        AND.W #$00FF
        CLC
        ADC.B $14
        CLC
        ADC.W $09E6
        CMP.W #$0100
        BCC CODE_80AD95
        db $A9,$FF,$00
CODE_80AD95: ; $00AD95
        STA.B $12
        LDX.B $12
        LDA.L $0BE164,X
        AND.W #$00FF
        STA.B $23
        LDY.W #$1000
        JSL.L loadCharDataRecord
        LDA.W $104D
        AND.W #$00FF
        STA.B $26
        SEP #$20
        LDA.W $0E86
        LSR A
        STA.B $24
        LDA.W $0E06
        LSR A
        LSR A
        LSR A
        CLC
        ADC.B $24
        INC A
        CMP.B #$64
        BCC CODE_80ADC9
        db $A9,$63
CODE_80ADC9: ; $00ADC9
        STA.B $24
        REP #$20
        LDA.W $0ECD
        AND.W #$00FF
        STA.B $14
        LDA.W $0E97
        AND.W #$00FF
        CLC
        ADC.B $14
        STA.B $14
        LDA.W $0E4E
        AND.W #$00FF
        CLC
        ADC.B $14
        CLC
        ADC.W $09E6
        CMP.W #$0100
        BCC CODE_80ADF5
        db $A9,$FF,$00
CODE_80ADF5: ; $00ADF5
        STA.B $12
        LDX.B $12
        LDA.L $0BE164,X
        STA.B $25
        LDY.W #$1000
        JSL.L loadCharDataRecord
        LDA.W $104D
        AND.W #$00FF
        STA.B $28
        LDX.B $22
        LDY.B $24
        LDA.B $26
        CMP.B $28
        BCS CODE_80AE1C
        db $A4,$22,$A6,$24
CODE_80AE1C: ; $00AE1C
        STX.W $1200
        STY.W $1202
        SEP #$20
        LDA.W $0E03
        STA.B $23
        LDA.W $0E86
        LSR A
        LSR A
        CLC
        ADC.W $0E06
        INC A
        CMP.B #$64
        BCC CODE_80AE39
        db $A9,$63
CODE_80AE39: ; $00AE39
        STA.B $22
        LDA.W $0E83
        STA.B $25
        LDA.W $0E06
        LSR A
        LSR A
        CLC
        ADC.W $0E86
        INC A
        CMP.B #$64
        BCC CODE_80AE50
        db $A9,$63
CODE_80AE50: ; $00AE50
        STA.B $24
        REP #$20
        LDA.B $22
        STA.W $1204
        LDA.B $24
        STA.W $1206
        LDY.W #$0000
        LDA.W #$0002
        JSR.W compareAndSwapValues
        LDA.W #$0004
        JSR.W compareAndSwapValues
        LDA.W #$0006
        JSR.W compareAndSwapValues
        LDY.W #$0002
        LDA.W #$0004
        JSR.W compareAndSwapValues
        LDA.W #$0006
        JSR.W compareAndSwapValues
        LDY.W #$0004
        LDA.W #$0006
        JSR.W compareAndSwapValues
        REP #$20
        LDY.W #$0000
        LDX.W #$0000
        STZ.W $1210
CODE_80AE96: ; $00AE96
        LDA.W $1200,Y
        CMP.W #$FFFF
        BEQ CODE_80AEA6
        STA.W $1208,X
        INX
        INX
        INC.W $1210
CODE_80AEA6: ; $00AEA6
        INY
        INY
        CPY.W #$0008
        BNE CODE_80AE96
        RTL
; [Helper] Compares and swaps values in $1200/$1201 table. Entry: X=index1, Y=index2, compares values, swaps if needed.
compareAndSwapValues: ; $00AEAE
        PHP
        REP #$20
        TAX
        SEP #$20
        LDA.W $1201,Y
        CMP.B #$FF
        BEQ CODE_80AEDB
        STA.B $00
        LDA.W $1201,X
        CMP.B #$FF
        BEQ CODE_80AEDB
        CMP.B $00
        BNE CODE_80AEDB
        db $90,$09,$99,$01,$12,$BD,$00,$12,$99,$00,$12,$A9,$FF,$9D,$00,$12
        db $9D,$01,$12
CODE_80AEDB: ; $00AEDB
        PLP
        RTS
; [Entity] Copies 40-byte ($28 stride) record from ROM $0BBF64 into WRAM at [$002A],Y; A=index
loadCharDataRecord: ; $00AEDD
        REP #$20
        AND.W #$00FF
        ASL A
        ASL A
        ASL A
        STA.B $00
        ASL A
        ASL A
        CLC
        ADC.B $00
        TAX
        LDA.W #$0014
CODE_80AEF0: ; $00AEF0
        PHA
        LDA.L $0BBF64,X
        STA.W $002A,Y
        INX
        INX
        INY
        INY
        PLA
        DEC A
        BNE CODE_80AEF0
        RTL
; [GameState] Scans $7EEA00[0..127] for entry matching A, ORs with $80 to mark active
setFlagInTable: ; $00AF01
        PHP
        SEP #$20
        STA.B $22
        STY.B $24
        LDX.W #$0000
CODE_80AF0B: ; $00AF0B
        LDA.L $7EEA00,X
        CMP.B #$80
        BCC CODE_80AF21
        db $29,$7F,$C5,$22,$D0,$08,$A5,$24,$09,$80,$9F,$00,$EA,$7E
CODE_80AF21: ; $00AF21
        INX
        CPX.W #$0080
        BNE CODE_80AF0B
        PLP
        RTL
        db $00,$01,$03,$06,$09,$0C,$0F,$18,$19,$1B,$1E,$21,$30,$31,$32,$34
        db $36,$3A,$40,$44,$46,$4A,$4C,$9B,$12,$15,$27,$2A,$3E,$41,$42,$48
        db $49,$FF,$50,$51,$52,$53,$54,$55,$56,$57,$58,$60,$61,$62,$63,$64
        db $65,$66,$67,$68,$69,$6A,$6B,$6D,$6E,$6F,$9B,$59,$5A,$5B,$5C,$5D
        db $FF
; [Text] Searches font/text table by ID, dispatches tile placement to $7E:2000 via textBuf helpers
renderTextFromTable: ; $00AF6A
        PHP
        REP #$20
        STZ.B $1C
        LDY.W #$0008
        STA.B $00
CODE_80AF74: ; $00AF74
        LDA.B [$12],Y
        BNE CODE_80AF7B
        db $4C,$0A,$B0
CODE_80AF7B: ; $00AF7B
        CMP.B $00
        BEQ CODE_80AF87
        TYA
        CLC
        ADC.W #$0008
        TAY
        BRA CODE_80AF74
CODE_80AF87: ; $00AF87
        INY
        INY
        LDA.B [$12],Y
        STA.B $08
        INY
        INY
        LDA.B [$12],Y
        STA.B $0A
        INY
        INY
        LDA.B [$12],Y
        STA.B $0C
        LDA.W #$007E
        STA.B $24
        LDA.W #$2000
        STA.B $22
        LDA.W #$0000
        STA.B $06
        LDA.B $08
        CLC
        ADC.B $12
        STA.B $12
CODE_80AFAF: ; $00AFAF
        LDA.B [$12]
        INC.B $12
        AND.W #$00FF
        BEQ textBuf_ReturnZero
        CMP.W #$0040
        BCC CODE_80AFD9
        CMP.W #$0080
        BEQ CODE_80AFE7
        BCS CODE_80AFFA
        SEP #$20
        AND.B #$3F
        STA.B $07
        LDA.B [$12]
        STA.B $06
        REP #$20
        INC.B $12
        LDA.B $06
        JSR.W textBuf_CalcTileIndex
        BRA CODE_80AFAF
CODE_80AFD9: ; $00AFD9
        PHA
        LDA.B $0A
        JSR.W textBuf_CalcTileIndex
        INC.B $0A
        PLA
        DEC A
        BNE CODE_80AFD9
        BRA CODE_80AFAF
CODE_80AFE7: ; $00AFE7
        LDA.B [$12]
        INC.B $12
        AND.W #$00FF
CODE_80AFEE: ; $00AFEE
        PHA
        LDA.B $06
        JSR.W textBuf_CalcTileIndex
        PLA
        DEC A
        BNE CODE_80AFEE
        BRA CODE_80AFAF
CODE_80AFFA: ; $00AFFA
        AND.W #$007F
        CLC
        ADC.B $06
        JSR.W textBuf_CalcTileIndex
        BRA CODE_80AFAF
; [Text] LDA #0, PLP, RTL. Returns zero result from text buffer operation.
textBuf_ReturnZero: ; $00B005
        LDA.W #$0000
        PLP
        RTL
        db $A9,$01,$00,$28,$6B
; [Text] CMP #$1000, ASL x4, check $8000. Text tile calc.
textBuf_CalcTileIndex: ; $00B00F
        CMP.W #$1000
        BCC textBuf_ShiftIndex
        STA.B $1B
        ASL A
        ASL A
        ASL A
        ASL A
        CMP.W #$8000
        BCS textBuf_CalcPtrOffset
        CLC
        ADC.B $16
        STA.B $1A
        LDA.B $1C
        LSR A
        LSR A
        LSR A
        AND.W #$001E
        CLC
        ADC.B $18
        STA.B $1C
        BRA textBuf_CopyData
; [Text] AND #$7FFF, CLC ADC $16, STA $1A. Calculates text data pointer offset.
textBuf_CalcPtrOffset: ; $00B033
        AND.W #$7FFF
        CLC
        ADC.B $16
        STA.B $1A
        LDA.B $1C
        LSR A
        LSR A
        LSR A
        AND.W #$001E
        INC A
        CLC
        ADC.B $18
        STA.B $1C
        BRA textBuf_CopyData
; [Text] ASL*4. Left-shifts index by 4 (multiply by 16) for table lookup.
textBuf_ShiftIndex: ; $00B04B
        ASL A
        ASL A
        ASL A
        ASL A
        CMP.W #$8000
        BCS textBuf_CalcPtrOffset2
        CLC
        ADC.B $16
        STA.B $1A
        LDA.B $18
        STA.B $1C
        BRA textBuf_CopyData
; [Text] AND #$7FFF, CLC ADC $16, STA $1A. Second pointer offset calculation path.
textBuf_CalcPtrOffset2: ; $00B05F
        AND.W #$7FFF
        CLC
        ADC.B $16
        STA.B $1A
        LDA.B $18
        INC A
        STA.B $1C
; [Text] LDY #0, LDA [$1A],Y STA [$22],Y INY. Copies text data from source to destination.
textBuf_CopyData: ; $00B06C
        LDY.W #$0000
        LDA.B [$1A],Y
        STA.B [$22],Y
        INY
        INY
        LDA.B [$1A],Y
        STA.B [$22],Y
        INY
        INY
        LDA.B [$1A],Y
        STA.B [$22],Y
        INY
        INY
        LDA.B [$1A],Y
        STA.B [$22],Y
        INY
        INY
        LDA.B [$1A],Y
        STA.B [$22],Y
        INY
        INY
        LDA.B [$1A],Y
        STA.B [$22],Y
        INY
        INY
        LDA.B [$1A],Y
        STA.B [$22],Y
        INY
        INY
        LDA.B [$1A],Y
        STA.B [$22],Y
        INY
        INY
        LDA.B $22
        CLC
        ADC.W #$0010
        STA.B $22
        RTS
; [AI] Updates battle turn order based on agility. Entry: sorts unit list by speed, determines next actor.
updateTurnOrder: ; $00B0A8
        REP #$20
        LDX.W #$0000
        LDY.W #$0400
        LDA.W #$03FF
; [Tilemap] Inner loop: fills $7F:B000 tilemap region with constant value in A
fillTilemapConst: ; $00B0B3
        STA.L $7FB000,X
        INX
        INX
        DEY
        BNE fillTilemapConst
        LDX.W #$0040
        LDY.W #$0380
        LDA.W #$0000
; [Tilemap] Fills $7F:B000 with sequential 0,1,2... then sets PPU BG regs $210B/$2108
fillTilemapSeq: ; $00B0C5
        STA.L $7FB000,X
        INX
        INX
        INC A
        DEY
        BNE fillTilemapSeq
        LDA.W #$7800
        STA.B $78
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSL.L waitForModeSync
        SEP #$20
        LDA.B #$60
        STA.W $210B
        STA.B $73
        LDA.B #$7C
        STA.W $2108
        REP #$20
        RTL
; [Text] Validates BE block header at [$12], searches 4-byte stride entries by 1-byte ID
textTbl_FindEntry: ; $00B0F1
        PHP
        REP #$20
        AND.W #$00FF
        STA.B $02
        LDA.B [$12]
        CMP.W #$4245
        BNE textTbl_NotFound
        LDY.W #$0003
        LDA.B [$12],Y
        STA.B $08
        LDY.W #$0008
        LDA.W #$0000
        STA.B $00
; [Text] LDA [$12],Y AND $FF, CMP $02. Searches table at [$12] for matching entry ID.
textTbl_SearchEntry: ; $00B10F
        LDA.B [$12],Y
        AND.W #$00FF
        CMP.B $02
        BEQ textTbl_ReadEntryData
        TYA
        CLC
        ADC.W #$0004
        TAY
        INC.B $00
        LDA.B $00
        CMP.B $08
        BEQ textTbl_NotFound
        BRA textTbl_SearchEntry
; [Text] Not-found exit path: returns X=0, RTL
textTbl_NotFound: ; $00B128
        db $A2,$00,$00,$28,$6B
; [Text] INY, LDA [$12],Y PHA INY. Reads entry data word after match.
textTbl_ReadEntryData: ; $00B12D
        INY
        LDA.B [$12],Y
        PHA
        INY
        INY
        LDA.B [$12],Y
        ASL A
        CLC
        ADC.B $14
        STA.B $14
        PLA
        CLC
        ADC.B $12
        BCC textTbl_SetupDecomp
        db $09,$00,$80,$E6,$14
; [Text] STA $12, LDY #0, LDX #0, SEP #$20. Sets up decompression pointer, 8-bit mode.
textTbl_SetupDecomp: ; $00B146
        STA.B $12
        LDY.W #$0000
        LDX.W #$0000
        SEP #$20
; [Text] LDA [$12],Y BEQ end INY STA $7E2000,X. Reads decompressed byte, stores to WRAM $7E2000.
textDecomp_ReadByte: ; $00B150
        LDA.B [$12],Y
        BEQ textDecomp_NextCmd
        INY
        STA.L $7E2000,X
        INX
        BRA textDecomp_ReadByte
; [Text] INY, LDA [$12],Y BNE continue JMP end. Reads next decompression command byte.
textDecomp_NextCmd: ; $00B15C
        INY
        LDA.B [$12],Y
        BNE textDecomp_Dispatch
        JMP.W $B1E9
; [Text] CMP #$E0 BCS high, CMP #$C0 BCS mid. Dispatches decompression command by range.
textDecomp_Dispatch: ; $00B164
        CMP.B #$E0
        BCS textDecomp_Finalize2
        CMP.B #$C0
        BCS textDecomp_Finalize
        CMP.B #$80
        BCS textDecomp_SetCount
        INY
        STA.B $00
        LDA.B #$00
; [Text] STA $7E2000,X INX DEC $00 BNE loop. Repeat fill — writes same byte $00 times.
textDecomp_RepeatByte: ; $00B175
        STA.L $7E2000,X
        INX
        DEC.B $00
        BNE textDecomp_RepeatByte
        BRA textDecomp_ReadByte
; [Text] AND #$1F STA $00 PHY DEY. Extracts 5-bit repeat count from command byte.
textDecomp_SetCount: ; $00B180
        AND.B #$1F
        STA.B $00
        PHY
        DEY
        DEY
        LDA.B [$12],Y
        PLY
        INY
        BRA textDecomp_RepeatByte
; [Text] DEX STX $00. Finalizes decompression, stores output size.
textDecomp_Finalize: ; $00B18D
        db $29,$1F,$85,$00,$5A,$88,$88,$88,$B7,$12,$85,$02,$C8,$B7,$12,$85
        db $03,$7A,$C8,$A5,$02,$9F,$00,$20,$7E,$E8,$A5,$03,$9F,$00,$20,$7E
        db $E8,$C6,$00,$D0,$EE,$80,$9C
; [Text] DEX STX $00 LDX #0. Second finalization path, resets X.
textDecomp_Finalize2: ; $00B1B4
        db $29,$1F,$85,$00,$5A,$88,$88,$88,$88,$B7,$12,$85,$02,$C8,$B7,$12
        db $85,$03,$C8,$B7,$12,$85,$04,$7A,$C8,$A5,$02,$9F,$00,$20,$7E,$E8
        db $A5,$03,$9F,$00,$20,$7E,$E8,$A5,$04,$9F,$00,$20,$7E,$E8,$C6,$00
        db $D0,$E7,$4C,$50,$B1
        DEX
        STX.B $00
        LDX.W #$0000
        LDA.B #$00
; [Text] CLC ADC $7E2000,X STA back INX. Delta decompression — adds delta to previous value.
textDecomp_AddDelta: ; $00B1F1
        CLC
        ADC.L $7E2000,X
        STA.L $7E2000,X
        INX
        CPX.B $00
        BNE textDecomp_AddDelta
        PLP
        RTL
; [GameState] Checks if story event flag is set. Entry: A=flag ID. Returns carry set if flag is true.
checkEventFlag: ; $00B201
        PHP
        REP #$20
        STZ.W $0A0C
        STZ.W $0A0E
        STZ.W $0A1A
        STZ.W $0A00
        LDA.W #$2000
        STA.W $0A02
        LDA.W #$0020
        STA.W $0A20
        LDA.B $04
        STA.W $09F4
        LDA.B $06
        STA.W $09F6
        LDA.B $00
        STA.W $09F0
        STA.W $09FC
        CLC
        ADC.B $04
        SEC
        SBC.W #$0001
        STA.W $09F8
        LDA.B $02
        STA.W $09F2
        STA.W $09FE
        CLC
        ADC.B $06
        STA.W $09FA
        PLP
        RTS
; [GameState] Sets story event flag. Entry: A=flag ID. Marks flag as completed in save data.
setEventFlag: ; $00B248
        PHP
        REP #$20
        LDA.W #$0000
        STA.B $00
        LDA.W #$0000
        STA.B $02
        LDA.W #$0020
        STA.B $04
        LDA.W #$001E
        STA.B $06
        JSR.W checkEventFlag
        JSL.L initTilemapAndSync_Long
        JSR.W waitForFrame
; [Text] A & $3F -> 4-byte jump table; each entry draws 1-2 text windows at fixed coords
dispatchDialogLayout: ; $00B269
        PLP
        RTL
; [Script] Handles cutscene playback. Entry: A=cutscene ID. Plays script, moves characters, displays dialogue.
handleCutscene: ; $00B26B
        REP #$20
        AND.W #$003F
        ASL A
        ASL A
        CLC
        ADC.W #$B27B
        STA.B $00
        JMP.W ($0000)
        JMP.W $B2B3
        db $EA
        JMP.W $B2E5
        db $EA,$4C,$1B,$B3,$EA,$4C,$4D,$B3,$EA,$4C,$CD,$B2,$EA
        JMP.W $B37F
        db $EA
        JMP.W $B3B5
        db $EA
        JMP.W $B3E7
        db $EA
        JMP.W $B3FF
        db $EA
        JMP.W $B417
        db $EA
        JMP.W $B436
        db $EA
        JMP.W $B455
        db $EA
        JMP.W $B46D
        db $EA
        JMP.W $B4F0
        db $EA
        LDA.W #$0001
        STA.B $00
        LDA.W #$0017
        STA.B $02
        LDA.W #$001E
        STA.B $04
        LDA.W #$0006
        STA.B $06
        JSR.W checkEventFlag
        JSR.W drawWindow
        LDA.W #$0002
        STA.B $00
        LDA.W #$0018
        STA.B $02
        LDA.W #$001C
        STA.B $04
        LDA.W #$0004
        STA.B $06
        JSR.W checkEventFlag
        RTL
        LDA.W #$0001
        STA.B $00
        LDA.W #$0015
        STA.B $02
        LDA.W #$001E
        STA.B $04
        LDA.W #$0008
        STA.B $06
        JSR.W checkEventFlag
        JSL.L initTilemapAndSync_Long
        JSR.W drawWindow
        LDA.W #$0002
        STA.B $00
        LDA.W #$0016
        STA.B $02
        LDA.W #$001C
        STA.B $04
        LDA.W #$0006
        STA.B $06
        JSR.W checkEventFlag
        RTL
        db $A9,$01,$00,$85,$00,$A9,$0A,$00,$85,$02,$A9,$1E,$00,$85,$04,$A9
        db $06,$00,$85,$06,$20,$01,$B2,$20,$D7,$B5,$A9,$02,$00,$85,$00,$A9
        db $0B,$00,$85,$02,$A9,$1C,$00,$85,$04,$A9,$04,$00,$85,$06,$20,$01
        db $B2,$6B,$A9,$01,$00,$85,$00,$A9,$0A,$00,$85,$02,$A9,$1E,$00,$85
        db $04,$A9,$08,$00,$85,$06,$20,$01,$B2,$20,$D7,$B5,$A9,$02,$00,$85
        db $00,$A9,$0B,$00,$85,$02,$A9,$1C,$00,$85,$04,$A9,$06,$00,$85,$06
        db $20,$01,$B2,$6B
        LDA.W #$0001
        STA.B $00
        LDA.W #$0013
        STA.B $02
        LDA.W #$001E
        STA.B $04
        LDA.W #$000A
        STA.B $06
        JSR.W checkEventFlag
        JSL.L initTilemapAndSync_Long
        JSR.W drawWindow
        LDA.W #$0002
        STA.B $00
        LDA.W #$0014
        STA.B $02
        LDA.W #$001C
        STA.B $04
        LDA.W #$0008
        STA.B $06
        JSR.W checkEventFlag
        RTL
        LDA.W #$0001
        STA.B $00
        LDA.W #$0013
        STA.B $02
        LDA.W #$001E
        STA.B $04
        LDA.W #$0008
        STA.B $06
        JSR.W checkEventFlag
        JSR.W drawWindow
        LDA.W #$0002
        STA.B $00
        LDA.W #$0014
        STA.B $02
        LDA.W #$001C
        STA.B $04
        LDA.W #$0006
        STA.B $06
        JSR.W checkEventFlag
        RTL
        LDA.W #$0002
        STA.B $00
        LDA.W #$0016
        STA.B $02
        LDA.W #$001D
        STA.B $04
        LDA.W #$0006
        STA.B $06
        JSR.W checkEventFlag
        RTL
        LDA.W #$0003
        STA.B $00
        LDA.W #$0008
        STA.B $02
        LDA.W #$001A
        STA.B $04
        LDA.W #$000E
        STA.B $06
        JSR.W checkEventFlag
        RTL
        LDA.W #$0007
        STA.B $00
        LDA.W #$000D
        STA.B $02
        LDA.W #$0015
        STA.B $04
        LDA.W #$0006
        STA.B $06
        JSR.W checkEventFlag
        JSL.L initTilemapAndSync_Long
        JSR.W drawWindow
        RTL
        LDA.W #$0005
        STA.B $00
        LDA.W #$000D
        STA.B $02
        LDA.W #$0019
        STA.B $04
        LDA.W #$0008
        STA.B $06
        JSR.W checkEventFlag
        JSL.L initTilemapAndSync_Long
        JSR.W drawWindow
        RTL
        LDA.W #$0002
        STA.B $00
        LDA.W #$0013
        STA.B $02
        LDA.W #$001C
        STA.B $04
        LDA.W #$0008
        STA.B $06
        JSR.W checkEventFlag
        RTL
        LDA.W #$0001
        STA.B $00
        LDA.W #$0005
        STA.B $02
        LDA.W #$000F
        STA.B $04
        LDA.W #$0004
        STA.B $06
        JSR.W checkEventFlag
        JSR.W drawWindow
        LDA.W #$0010
        STA.B $00
        LDA.W #$0005
        STA.B $02
        LDA.W #$000F
        STA.B $04
        LDA.W #$0004
        STA.B $06
        JSR.W checkEventFlag
        JSR.W drawWindow
        LDA.W #$0001
        STA.B $00
        LDA.W #$0009
        STA.B $02
        LDA.W #$001E
        STA.B $04
        LDA.W #$0004
        STA.B $06
        JSR.W checkEventFlag
        JSR.W drawWindow
        LDA.W #$0001
        STA.B $00
        LDA.W #$000D
        STA.B $02
        LDA.W #$001E
        STA.B $04
        LDA.W #$0004
        STA.B $06
        JSR.W checkEventFlag
        JSR.W drawWindow
        LDA.W #$0001
        STA.B $00
        LDA.W #$0011
        STA.B $02
        LDA.W #$001E
        STA.B $04
        LDA.W #$0004
        STA.B $06
        JSR.W checkEventFlag
        JSR.W drawWindow
        RTL
        LDA.W #$0001
        STA.B $00
        LDA.W #$0005
        STA.B $02
        LDA.W #$001E
        STA.B $04
        LDA.W #$0006
        STA.B $06
        JSR.W checkEventFlag
        JSR.W drawWindow
        LDA.W #$0001
        STA.B $00
        LDA.W #$000B
        STA.B $02
        LDA.W #$001E
        STA.B $04
        LDA.W #$0012
        STA.B $06
        JSR.W checkEventFlag
        JSR.W drawWindow
        RTL
; [Effects] Fades screen to black for transitions. Entry: called before scene changes. Gradual fade via $2100.
fadeToBlack: ; $00B525
        REP #$20
        STZ.B $6F
        LDA.W $0E25
        AND.W #$00FF
        BNE drawTwoPanelWindow
        LDA.W #$0001
        STA.B $00
        LDA.W #$0003
        STA.B $02
        LDA.W #$001E
        STA.B $04
        LDA.W #$000F
        STA.B $06
        JSR.W checkEventFlag
        JSR.W drawWindow
        BRA drawDialogFrame
; [Text] Draws two side-by-side windows: (1,3,$F,$F) and ($10,3,$F,$F)
drawTwoPanelWindow: ; $00B54D
        LDA.W #$0001
        STA.B $00
        LDA.W #$0003
        STA.B $02
        LDA.W #$000F
        STA.B $04
        LDA.W #$000F
        STA.B $06
        JSR.W checkEventFlag
        JSR.W drawWindow
        LDA.W #$0010
        STA.B $00
        LDA.W #$0003
        STA.B $02
        LDA.W #$000F
        STA.B $04
        LDA.W #$000F
        STA.B $06
        JSR.W checkEventFlag
        JSR.W drawWindow
; [Text] Sets $6F=$FFFF (border mode), draws outer (1,$13,$1E,$8) + inner (2,$14,$1C,$6) windows
drawDialogFrame: ; $00B581
        LDA.W #$FFFF
        STA.B $6F
        LDA.W #$0001
        STA.B $00
        LDA.W #$0013
        STA.B $02
        LDA.W #$001E
        STA.B $04
        LDA.W #$0008
        STA.B $06
        JSR.W checkEventFlag
        JSR.W drawWindow
        LDA.W #$0002
        STA.B $00
        LDA.W #$0014
        STA.B $02
        LDA.W #$001C
        STA.B $04
        LDA.W #$0006
        STA.B $06
        JSR.W checkEventFlag
        RTL
; [Input] Waits for button press before continuing. Entry: displays 'press button' prompt, loops until input.
waitForButton: ; $00B5B8
        PHP
        REP #$20
        STZ.W $09FC
        STZ.W $09FE
        LDX.W #$0000
        LDA.W #$0000
; [Text] STA $7E9000,X INX INX CPX #$0800. Clears tile buffer $7E9000 (2048 bytes).
textWin_ClearTileBuf: ; $00B5C7
        STA.L $7E9000,X
        INX
        INX
        CPX.W #$0800
        BNE textWin_ClearTileBuf
        STZ.W $0A1C
        PLP
        RTL
; [Menu] Draws window frame for menus/dialogue. Entry: $00/$02=position, $04/$06=size. Renders border tiles.
drawWindow: ; $00B5D7
        PHP
        REP #$20
        LDA.W $09F0
        STA.W $09FC
        LDA.W $09F2
        STA.W $09FE
        JSR.W calculateBufferOffset
        TXA
        STA.B $02
        CLC
        ADC.W #$0040
        STA.B $04
        LDY.W #$3101
        LDA.B $6F
        BNE textWin_FillTileBuf
        LDY.W #$3105
; [Text] TYA STA $22, STA $7E9000,X. Fills tile buffer with uniform value.
textWin_FillTileBuf: ; $00B5FC
        TYA
        STA.B $22
        STA.L $7E9000,X
        INX
        INX
        LDY.W $09F4
        DEY
        DEY
        INC A
; [Text] STA $7E9000,X INX INX DEY. Writes one row of tiles to buffer.
textWin_WriteTileRow: ; $00B60B
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE textWin_WriteTileRow
        LDA.B $22
        CLC
        ADC.W #$4000
        STA.L $7E9000,X
        LDA.B $22
        INC A
        INC A
        STA.B $06
        LDA.W $09F6
        TAY
        DEY
        DEY
; [Text] LDA $06 LDX $04, STA $7E9000,X. Writes tile value at specific buffer offset.
textWin_WriteAtOffset: ; $00B62A
        LDA.B $06
        LDX.B $04
        STA.L $7E9000,X
        LDA.W $09F4
        ASL A
        SEC
        SBC.W #$0002
        CLC
        ADC.B $04
        TAX
        LDA.B $06
        CLC
        ADC.W #$4000
        STA.L $7E9000,X
        LDA.B $04
        CLC
        ADC.W #$0040
        STA.B $04
        DEY
        BNE textWin_WriteAtOffset
        LDX.B $04
        LDA.B $22
        CLC
        ADC.W #$8000
        LDY.W $09F4
        DEY
        DEY
        STA.L $7E9000,X
        INX
        INX
        INC A
; [Text] STA $7E9000,X INX INX DEY. Another tile row fill loop.
textWin_FillRow: ; $00B667
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE textWin_FillRow
        LDA.B $22
        CLC
        ADC.W #$C000
        STA.L $7E9000,X
        PLP
        RTS
; [Text] Phase 1 text engine: streams text from ROM into WRAM $0400 buffer. Dispatches FF control codes; calls unit-name copy, etc.
fillTextBuffer_Phase1: ; $00B67C
        STZ.W $0A08
        STZ.W $0A16
        STZ.W $0A18
        SEP #$20
        LDY.W #$0000
        LDX.W #$0000
; [Text] Text loop: reads [$14],Y into $0400 buffer
textLoopStart: ; $00B68D
        LDA.B [$14],Y
        BNE ffCode_DispatchRange
        JMP.W endOfTextHandler
; [Text] CMP #9 BCC low, CMP #$FF BEQ ff. Phase 1 FF sub-code range dispatch.
ffCode_DispatchRange: ; $00B694
        CMP.B #$09
        BCC ffCode_HandleLow
        CMP.B #$FF
        BEQ ffCode_PeekNext
        STA.W $0400,X
        INX
        INY
        BRA textLoopStart
; [Text] DEC STA $01, INY LDA [$14],Y. Handles FF codes < $09 — copies raw bytes to $0400 buffer.
ffCode_HandleLow: ; $00B6A3
        DEC A
        STA.B $01
        INY
        LDA.B [$14],Y
        STA.B $00
        INY
        LDA.B #$D0
        STA.W $0400,X
        INX
        LDA.W $0A18
        CLC
        ADC.W $0A1A
        STA.W $0400,X
        INX
        PHX
        REP #$20
        LDA.W $0A18
        CLC
        ADC.W $0A1A
        ASL A
        TAX
        LDA.B $00
        STA.W $0700,X
        INC.W $0A18
        PLX
        SEP #$20
        BRA textLoopStart
; [Text] INY LDA [$14],Y DEY CMP #$80. Peeks at next byte after FF to check high/low dispatch.
ffCode_PeekNext: ; $00B6D6
        INY
        LDA.B [$14],Y
        DEY
        CMP.B #$80
        BCS ffCode_CheckF1
        JMP.W ffLowBufferCopy
; [Text] CMP #$F1 BCC buffer, JMP ffHighJumpTable. Checks if FF sub-code >= $F1 for high jump table.
ffCode_CheckF1: ; $00B6E1
        CMP.B #$F1
        BCC ffCode_CheckC0
        JMP.W ffLowBufferCopy
; [Text] CMP #$C0 BCC low, JMP $BB33. Checks if FF sub-code >= $C0 (FFC0 redirect handler).
ffCode_CheckC0: ; $00B6E8
        CMP.B #$C0
        BCC ffCode_LowMask
        JMP.W $BB33
; [Text] REP #$20, AND #$3F ASL ASL. Masks low FF code to 6 bits, *4 for jump table index.
ffCode_LowMask: ; $00B6EF
        REP #$20
        AND.W #$003F
        ASL A
        ASL A
        CLC
        ADC.W #$B701
        STA.B $00
        SEP #$20
        JMP.W ($0000)
; [Text] FF codes >= $80: processed inline Phase 1, NOT buffered
ffHighJumpTable: ; $00B701
        JMP.W ffCode80_SetParam
        db $EA
        JMP.W ffCode81_SetParamIndirect
        db $EA
        JMP.W ffCode82_MultiplyParam
        db $EA
        JMP.W ffCode83_RenderWord
        db $EA
        JMP.W ffCode84_RenderByte
        db $EA
        JMP.W ffCode85_RenderClamped99
        db $EA
        JMP.W ffCode86_RenderSingleDigit
        db $EA
        JMP.W ffCode87_CopyStringDirect
        db $EA
        JMP.W $B97B
        db $EA
        JMP.W $B998
        db $EA,$4C,$AB,$B9,$EA,$4C,$CF,$B9,$EA
        JMP.W $BA38
        db $EA
        JMP.W $BA6D
        db $EA
        JMP.W $BAA6
        db $EA,$4C,$BA,$BA,$EA,$4C,$C9,$BA,$EA,$4C,$5E,$B8,$EA,$4C,$DC,$BA
        db $EA,$4C,$E7,$BA,$EA
        JMP.W $BAFD
        db $EA
        JMP.W ffCode95_RenderClamped999
        db $EA,$4C,$12,$BB,$EA
        JMP.W ffCode_RenderCompoundName
        db $EA,$4C,$B7,$B8,$EA,$4C,$2D,$B8,$EA,$4C,$F2,$B7,$EA
        JMP.W $BB2A
        db $EA
        JMP.W ffCode_RenderStringLookup
        db $EA
; FF codes <$80 and >=$F1: copies 3 raw bytes to $0400 buffer.
ffLowBufferCopy: ; $00B775
        LDA.B [$14],Y
        STA.W $0400,X
        INY
        INX
        LDA.B [$14],Y
        STA.W $0400,X
        INY
        INX
        LDA.B [$14],Y
        STA.W $0400,X
        INY
        INX
        JMP.W textLoopStart
; FF 80: reads 1 inline byte, stores to $0A08 (text param).
ffCode80_SetParam: ; $00B78D
        JSR.W ffReadInlineByte
        REP #$20
        LDA.B $00
        STA.W $0A08
        SEP #$20
        JMP.W textLoopStart
; FF 81: reads 3-byte ptr, loads indirect byte to $0A08.
ffCode81_SetParamIndirect: ; $00B79C
        JSR.W ffReadInlinePtr
        REP #$20
        LDA.B [$00]
        AND.W #$00FF
        STA.W $0A08
        SEP #$20
        JMP.W textLoopStart
; FF 82: hardware multiply $0A08 * inline byte via $4202/$4203.
ffCode82_MultiplyParam: ; $00B7AE
        JSR.W ffReadInlineByte
        PHY
        LDA.W $0A08
        STA.W $4202
        LDA.B $00
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDY.W $4216
        STY.W $0A08
        PLY
        JMP.W textLoopStart
; FF 83: reads 3-byte ptr, loads 16-bit value, renders via $BCD6.
ffCode83_RenderWord: ; $00B7CB
        JSR.W ffReadInlinePtr
        PHY
        REP #$20
        LDA.B [$00]
        TAY
        JSR.W renderNumber5Digit
        SEP #$20
        PLY
        JMP.W textLoopStart
; FF 84: reads 3-byte ptr, loads 8-bit value, renders via $BCFF.
ffCode84_RenderByte: ; $00B7DD
        JSR.W ffReadInlinePtr
        PHY
        REP #$20
        LDA.B [$00]
        AND.W #$00FF
        TAY
        JSR.W renderNumber3Digit
        SEP #$20
        PLY
        JMP.W textLoopStart
        db $20,$71,$BB,$5A,$C2,$20,$E6,$00,$A7,$00,$20,$0D,$BD,$C6,$00,$A7
        db $00,$20,$0D,$BD,$E6,$00,$E6,$00,$E2,$20,$7A,$4C,$8D,$B6
; FF 85: reads ptr, loads byte clamped to 99, renders via $BD06.
ffCode85_RenderClamped99: ; $00B810
        JSR.W ffReadInlinePtr
        PHY
        REP #$20
        LDA.B [$00]
        AND.W #$00FF
        CMP.W #$0064
        BCC textBuf_CopyUnitName
        LDA.W #$0063
; [Text] TAY JSR $BD06 SEP #$20 PLY. Copies unit name bytes to $0400 buffer via clearMemory.
textBuf_CopyUnitName: ; $00B823
        TAY
        JSR.W renderNumber2Digit
        SEP #$20
        PLY
        JMP.W textLoopStart
        db $20,$71,$BB,$5A,$C2,$20,$A0,$20,$00,$A7,$00,$20,$6C,$C2,$85,$04
        db $C0,$00,$00,$F0,$05,$A0,$2D,$00,$80,$03,$A0,$20,$00,$E2,$20,$98
        db $9D,$00,$04,$E8,$C2,$20,$A4,$04,$20,$06,$BD,$E2,$20,$7A,$4C,$8D
        db $B6,$20,$71,$BB,$5A,$C2,$20,$A7,$00,$29,$FF,$00,$C9,$64,$00,$B0
        db $11,$A8,$A9,$25,$00,$9D,$00,$04,$E8,$20,$06,$BD,$E2,$20,$7A,$4C
        db $8D,$B6,$C2,$20,$A8,$20,$FF,$BC,$E2,$20,$7A,$4C,$8D,$B6
; FF 95: reads ptr, loads value clamped to 999, renders number.
ffCode95_RenderClamped999: ; $00B88B
        JSR.W ffReadInlinePtr
        PHY
        REP #$20
        LDA.B [$00]
        CMP.W #$03E8
        BCC textBuf_CopyRaw
        db $A9,$E7,$03
; [Text] TAY JSR $BCFF. Copies raw bytes using setMemory, then returns to text loop.
textBuf_CopyRaw: ; $00B89B
        TAY
        JSR.W renderNumber3Digit
        BRA textBuf_ReturnToLoop
        db $A8,$20,$06,$BD,$E2,$20,$A9,$20,$9D,$00,$04,$E8,$7A,$4C,$8D,$B6
; [Text] SEP #$20 PLY JMP textLoopStart. Returns to Phase 1 text loop after copy.
textBuf_ReturnToLoop: ; $00B8B1
        SEP #$20
        PLY
        JMP.W textLoopStart
        db $20,$71,$BB,$5A,$C2,$20,$A0,$20,$00,$A7,$00,$20,$6C,$C2,$85,$04
        db $C0,$00,$00,$F0,$05,$A0,$2D,$00,$80,$03,$A0,$20,$00,$E2,$20,$98
        db $9D,$00,$04,$E8,$C2,$20,$A4,$04,$20,$CF,$BC,$E2,$20,$7A,$4C,$8D
        db $B6
; Reads 3-byte ptr, renders two string lookups separated by $95 char.
ffCode_RenderCompoundName: ; $00B8E8
        JSR.W ffReadInlinePtr
        INC.B $00
        LDA.B [$00]
        PHA
        DEC.B $00
        LDA.B [$00]
        JSR.W lookupStringTable1
        LDA.B #$95
        STA.W $0400,X
        INX
        PLA
        JSR.W lookupStringTable2
        JMP.W textLoopStart
; Reads 3-byte ptr, looks up single string via $B90F.
ffCode_RenderStringLookup: ; $00B904
        JSR.W ffReadInlinePtr
        LDA.B [$00]
        JSR.W lookupStringTable1
        JMP.W textLoopStart
; Text engine: index*8 into table at $02:A050, copy chars to $0400 until $20 terminator.
lookupStringTable1: ; $00B90F
        PHY
        REP #$20
        AND.W #$00FF
        ASL A
        ASL A
        ASL A
        TAY
        LDA.W #$0002
        STA.B $02
        LDA.W #$A050
        STA.B $00
        BRA textBuf_ScanString
; Text engine: index*8 into table at $02:A298, copy chars to $0400 until $20 terminator.
lookupStringTable2: ; $00B925
        PHY
        REP #$20
        AND.W #$00FF
        ASL A
        ASL A
        ASL A
        TAY
        LDA.W #$0002
        STA.B $02
        LDA.W #$A298
        STA.B $00
; [Text] SEP #$20, LDA [$00],Y INY CMP #$20. Scans string for space ($20) delimiter.
textBuf_ScanString: ; $00B939
        SEP #$20
; [Text] LDA [$00],Y INY CMP #$20 BEQ found. String scan loop body.
textBuf_ScanLoop: ; $00B93B
        LDA.B [$00],Y
        INY
        CMP.B #$20
        BEQ textBuf_ScanDone
        STA.W $0400,X
        INX
        BRA textBuf_ScanLoop
; [Text] PLY RTS. String scan complete, return.
textBuf_ScanDone: ; $00B948
        PLY
        RTS
; FF 86: reads ptr, loads byte clamped to 9, adds $30, writes single ASCII digit.
ffCode86_RenderSingleDigit: ; $00B94A
        JSR.W ffReadInlinePtr
        LDA.B [$00]
        AND.B #$FF
        CMP.B #$0A
        BCC textBuf_WriteDigit
        db $A9,$09
; [Text] CLC ADC #$30, STA $0400,X INX. Converts digit to ASCII ($30 base) and writes to text buffer.
textBuf_WriteDigit: ; $00B957
        CLC
        ADC.B #$30
        STA.W $0400,X
        INX
        JMP.W textLoopStart
; FF 87: reads ptr, copies bytes from [$00] to $0400 until $00 or $20 terminator.
ffCode87_CopyStringDirect: ; $00B961
        JSR.W ffReadInlinePtr
; [Text] LDA [$00] BEQ done CMP #$20 BEQ done. Checks for null or space terminator.
textBuf_CheckEnd: ; $00B964
        LDA.B [$00]
        BEQ textBuf_JmpLoop
        CMP.B #$20
        BEQ textBuf_JmpLoop
        STA.W $0400,X
        INX
        REP #$20
        INC.B $00
        SEP #$20
        BRA textBuf_CheckEnd
; [Text] JMP textLoopStart. Returns to Phase 1 main loop.
textBuf_JmpLoop: ; $00B978
        JMP.W textLoopStart
        INY
        INY
        LDA.B [$14],Y
        STA.B $04
        DEY
        JSR.W ffReadInlinePtr
; [Text] Copies raw bytes from embedded 3-byte SNES ptrs in text
textRawCopyHandler: ; $00B985
        LDA.B [$00]
        STA.W $0400,X
        INX
        REP #$20
        INC.B $00
        SEP #$20
        DEC.B $04
        BNE textRawCopyHandler
        JMP.W textLoopStart
        JSR.W ffReadInlineWord
        REP #$20
        LDA.W $0A08
        CLC
        ADC.B $00
        STA.W $0A08
        SEP #$20
        JMP.W textLoopStart
        db $20,$A7,$BB,$20,$A1,$EE,$C2,$20,$5A,$AC,$0E,$0A,$A5,$00,$99,$00
        db $01,$C8,$C8,$AD,$08,$0A,$99,$00,$01,$C8,$C8,$8C,$0E,$0A,$7A,$E2
        db $20,$4C,$8D,$B6,$20,$A7,$BB,$20,$A1,$EE,$C2,$20,$5A,$AC,$0E,$0A
        db $A5,$00,$99,$00,$01,$C8,$C8,$AD,$08,$0A,$99,$00,$01,$C8,$C8,$A5
        db $00,$18,$69,$10,$00,$99,$00,$01,$C8,$C8,$AD,$08,$0A,$18,$69,$02
        db $00,$99,$00,$01,$C8,$C8,$A5,$00,$18,$69,$00,$10,$99,$00,$01,$C8
        db $C8,$AD,$08,$0A,$18,$69,$20,$00,$99,$00,$01,$C8,$C8,$A5,$00,$18
        db $69,$10,$10,$99,$00,$01,$C8,$C8,$AD,$08,$0A,$18,$69,$22,$00,$99
        db $00,$01,$C8,$C8,$8C,$0E,$0A,$7A,$E2,$20,$4C,$8D,$B6
        JSR.W ffReadInlinePtr
        LDA.B [$00]
        STA.B $00
        LDA.B [$14],Y
        INY
        CMP.B #$20
        BCC ffBuf_ClampMin
        STA.B $01
        LDA.B $00
        BNE ffBuf_LoadParam
        JMP.W textLoopStart
; [Text] LDA $01, BRA store. Loads parameter byte for FF buffer copy.
ffBuf_LoadParam: ; $00BA4F
        LDA.B $01
        BRA ffBuf_FillLoop
; [Text] CMP $00 BCS skip STA $00. Clamps value to minimum in $00.
ffBuf_ClampMin: ; $00BA53
        CMP.B $00
        BCS ffBuf_CheckZero
        STA.B $00
; [Text] LDA $00 BNE continue JMP textLoopStart. If count is zero, skip to next byte.
ffBuf_CheckZero: ; $00BA59
        LDA.B $00
        BNE ffBuf_FillChar3E
        JMP.W textLoopStart
; [Text] LDA #$3E, STA $0400,X. Fills buffer with character $3E (dash/fill char).
ffBuf_FillChar3E: ; $00BA60
        LDA.B #$3E
; [Text] STA $0400,X INX DEC $00 BNE loop. Fill loop for text buffer with repeated character.
ffBuf_FillLoop: ; $00BA62
        STA.W $0400,X
        INX
        DEC.B $00
        BNE ffBuf_FillLoop
        JMP.W textLoopStart
        JSR.W ffReadInlinePtr
        LDA.B [$00]
        STA.B $00
        LDA.B [$14],Y
        INY
        STA.B $01
        SEC
        SBC.B $00
        BPL ffBuf_PadSpaces
        LDA.B $01
        STA.B $00
        LDA.B #$00
; [Text] STA $02, BEQ skip, LDA #$20. Pads text buffer with spaces ($20).
ffBuf_PadSpaces: ; $00BA84
        STA.B $02
        BEQ ffBuf_CheckZero2
        LDA.B #$20
; [Text] STA $0400,X INX DEC $02 BNE loop. Space padding loop.
ffBuf_SpaceLoop: ; $00BA8A
        STA.W $0400,X
        INX
        DEC.B $02
        BNE ffBuf_SpaceLoop
; [Text] LDA $00 BNE continue JMP textLoopStart. Second zero-check path.
ffBuf_CheckZero2: ; $00BA92
        LDA.B $00
        BNE ffBuf_FillChar3C
        JMP.W textLoopStart
; [Text] LDA #$3C, STA $0400,X. Fills with character $3C.
ffBuf_FillChar3C: ; $00BA99
        LDA.B #$3C
; [Text] STA $0400,X INX DEC $00 BNE loop. Fill loop for character $3C.
ffBuf_FillLoop3C: ; $00BA9B
        STA.W $0400,X
        INX
        DEC.B $00
        BNE ffBuf_FillLoop3C
        JMP.W textLoopStart
        JSR.W ffReadInlinePtr
        LDA.B [$00]
        STA.B $00
        LDA.B [$14],Y
        INY
        CLC
        ADC.B $00
        STA.W $0400,X
        INX
        JMP.W textLoopStart
        db $C8,$C8,$C2,$20,$AD,$08,$0A,$8D,$14,$0A,$E2,$20,$4C,$8D,$B6,$C8
        db $C8,$C2,$20,$AD,$08,$0A,$18,$6D,$14,$0A,$8D,$08,$0A,$E2,$20,$4C
        db $8D,$B6,$20,$91,$BB,$AD,$08,$0A,$87,$00,$4C,$8D,$B6,$20,$91,$BB
        db $C2,$20,$A7,$00,$29,$FF,$00,$18,$6D,$08,$0A,$8D,$08,$0A,$E2,$20
        db $4C,$8D,$B6
        INY
        INY
        LDA.B [$14],Y
        STA.B $00
        INY
        LDA.B [$14],Y
        INY
; [Text] STA $0400,X INX DEC $00 BNE loop. Generic character fill loop.
ffBuf_FillGeneric: ; $00BB07
        STA.W $0400,X
        INX
        DEC.B $00
        BNE ffBuf_FillGeneric
        JMP.W textLoopStart
        db $20,$71,$BB,$5A,$C2,$20,$A7,$00,$A8,$E6,$00,$E6,$00,$A7,$00,$20
        db $8E,$BC,$E2,$20,$7A,$4C,$8D,$B6
        JSR.W ffReadInlineByte
        STA.W $0A20
        JMP.W textLoopStart
        AND.B #$3F
        STA.B $04
        JSR.W compareStrings
        LDA.B $04
        CMP.B #$30
        BNE ffC0_CheckCondition
        LDA.W $0A08
        BEQ ffC0_SetTextPtr
        JMP.W textLoopStart
; [Text] LDA $54 AND #$3F CMP $04. Checks condition flags for FF C0 conditional redirect.
ffC0_CheckCondition: ; $00BB48
        LDA.B $54
        AND.B #$3F
        CMP.B $04
        BCS ffC0_SetTextPtr
        db $4C,$8D,$B6
; [Text] LDA $00 STA $14, LDA $01 STA $15. Sets text stream pointer from computed address.
ffC0_SetTextPtr: ; $00BB53
        LDA.B $00
        STA.B $14
        LDA.B $01
        STA.B $15
        LDA.B $02
        STA.B $16
        LDY.W #$0000
        JMP.W textLoopStart
; Helper: reads 1 byte from text stream after FF code, stores to $00.
ffReadInlineByte: ; $00BB65
        SEP #$20
        INY
        INY
        STZ.B $01
        LDA.B [$14],Y
        STA.B $00
        INY
        RTS
; Helper: reads 3-byte SNES pointer from text stream, stores to $00/$02.
ffReadInlinePtr: ; $00BB71
        PHP
        SEP #$20
        INY
        INY
        LDA.B [$14],Y
        STA.B $00
        INY
        LDA.B [$14],Y
        STA.B $01
        INY
        LDA.B [$14],Y
        STA.B $02
        INY
        REP #$20
        LDA.B $00
        CLC
        ADC.W $0A08
        STA.B $00
        PLP
        RTS
; [Text] Compares two strings. Entry: $12/$14=string1, $16/$18=string2. Returns Z flag set if equal.
compareStrings: ; $00BB91
        PHP
        SEP #$20
        INY
        INY
        LDA.B [$14],Y
        STA.B $00
        INY
        LDA.B [$14],Y
        STA.B $01
        INY
        LDA.B [$14],Y
        STA.B $02
        INY
        PLP
        RTS
; Reads 2 bytes from text stream [$14]+Y into $00/$01.
ffReadInlineWord: ; $00BBA7
        PHP
        SEP #$20
        INY
        INY
        LDA.B [$14],Y
        STA.B $00
        INY
        LDA.B [$14],Y
        STA.B $01
        INY
        PLP
        RTS
; [Text] Null byte handler: kanji tile copy + render trigger
endOfTextHandler: ; $00BBB8
        REP #$20
        STZ.W $0400,X
        INY
        TYA
        CLC
        ADC.B $14
        PHA
        LDA.W $0A18
        BNE ffC0_CalcOffset
        JMP.W renderTextWrapper
; [Text] CLC ADC $0A1A ASL STA $00. Calculates entry offset for FF C0 redirect table.
ffC0_CalcOffset: ; $00BBCB
        CLC
        ADC.W $0A1A
        ASL A
        STA.B $00
        LDA.W #$007F
        STA.B $16
        LDA.W #$B000
        STA.B $14
        LDA.W #$8000
        STA.B $18
        LDA.W #$0004
        STA.B $1A
        LDY.W #$0000
; [Text] LDA $0700,Y INY INY PHY. Reads kanji tile data from $0700 buffer.
kanji_ReadTileData: ; $00BBE9
        LDA.W $0700,Y
        INY
        INY
        PHY
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        LDY.W #$0004
        CMP.W #$8000
        BCC kanji_SetupWrite
        LDY.W #$0005
        AND.W #$7FFF
; [Text] STY $1A TAY, LDA $0A1C BNE alt. Sets up kanji tile write, checks special mode.
kanji_SetupWrite: ; $00BC02
        STY.B $1A
        TAY
        LDA.W $0A1C
        BNE kanji_AltWrite
        LDX.W #$0010
; [Text] LDA [$18],Y EOR $6F STA [$14]. Writes kanji tile with XOR mask ($6F) for inversion.
kanji_WriteTile: ; $00BC0D
        LDA.B [$18],Y
        EOR.B $6F
        STA.B [$14]
        INY
        INY
        INC.B $14
        INC.B $14
        DEX
        BNE kanji_WriteTile
        BRA kanji_LoopCheck
; [Text] Alternate kanji write path when $0A1C special mode is set.
kanji_AltWrite: ; $00BC1E
        db $A9,$02,$00,$85,$02,$5A,$A2,$08,$00,$E2,$20,$B7,$18,$87,$14,$E6
        db $14,$87,$14,$C2,$20,$E6,$14,$C8,$C8,$CA,$D0,$ED,$7A,$C8,$A2,$08
        db $00,$E2,$20,$B7,$18,$87,$14,$E6,$14,$87,$14,$C2,$20,$E6,$14,$C8
        db $C8,$CA,$D0,$ED,$88,$C6,$02,$D0,$CC
; [Text] PLY CPY $00 BNE loop LDY #$6C00. Checks if all kanji tiles processed, sets VRAM dest.
kanji_LoopCheck: ; $00BC57
        PLY
        CPY.B $00
        BNE kanji_ReadTileData
        LDY.W #$6C00
        LDA.W $0A1C
        BEQ kanji_SetVRAMDest
        db $A0,$00,$48
; [Text] STY $78, SEP #$20, LDA #$FE STA $57. Sets VRAM destination $78=$6C00, DMA flag $57=$FE.
kanji_SetVRAMDest: ; $00BC67
        STY.B $78
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSL.L waitForModeSync
; [Text] Text render wrapper - sets up parameters and calls main text processor. Entry: expects text pointer at $14/$16. Sets $14=#$0400, $16=0, calls processText. Returns via RTL.
renderTextWrapper: ; $00BC75
        LDA.W #$0400
        STA.B $14
        STZ.B $16
        JSR.W renderTextStream
        REP #$20
        LDA.W $0A16
        BNE kanji_Return
        JSR.W waitForFrame
        STZ.W $0A0E
; [Text] PLA RTL. Returns from kanji tile processing.
kanji_Return: ; $00BC8C
        PLA
        RTL
        db $08,$C2,$20,$64,$00,$84,$06,$85,$08,$A9,$98,$00,$85,$0C,$A9,$80
        db $96,$85,$0A,$20,$5F,$BD,$A9,$0F,$00,$85,$0C,$A9,$40,$42,$85,$0A
        db $20,$5F,$BD,$A9,$01,$00,$85,$0C,$A9,$A0,$86,$85,$0A,$20,$5F,$BD
        db $A9,$00,$00,$85,$0C,$A9,$10,$27,$85,$0A,$20,$5F,$BD,$A4,$06,$80
        db $12,$08,$C2,$20,$64,$00,$80,$0B
; Renders number as up to 5 decimal digits via renderNumberToBuffer.
renderNumber5Digit: ; $00BCD6
        PHP
        REP #$20
        STZ.B $00
        LDA.W #$2710
        JSR.W renderNumberToBuffer
        LDA.W #$03E8
        JSR.W renderNumberToBuffer
; [Text] LDA #100 JSR $BD31. Divides by 100 for hundreds digit.
numRender_Hundreds: ; $00BCE7
        LDA.W #$0064
        JSR.W renderNumberToBuffer
; [Text] LDA #10 JSR $BD31 TYA SEP #$20. Divides remainder by 10 for tens digit.
numRender_Tens: ; $00BCED
        LDA.W #$000A
        JSR.W renderNumberToBuffer
        TYA
        SEP #$20
        CLC
        ADC.B #$30
        STA.W $0400,X
        INX
        PLP
        RTS
; Alternate entry: starts at hundreds place.
renderNumber3Digit: ; $00BCFF
        PHP
        REP #$20
        STZ.B $00
        BRA numRender_Hundreds
; Alternate entry: starts at tens place.
renderNumber2Digit: ; $00BD06
        PHP
        REP #$20
        STZ.B $00
        BRA numRender_Tens
        db $C2,$20,$A8,$29,$0F,$00,$48,$98,$4A,$4A,$4A,$4A,$29,$0F,$00,$A8
        db $E2,$20,$B9,$C7,$E0,$9D,$00,$04,$E8,$7A,$B9,$C7,$E0,$9D,$00,$04
        db $E8,$C2,$20,$60
; Converts A to decimal string in $0400. Division by repeated subtraction, leading zero suppression, +$30 ASCII.
renderNumberToBuffer: ; $00BD31
        STA.B $04
        TYA
        LDY.W #$0000
; [Text] SEC SBC $04 BCC done INY. Division loop — repeated subtraction.
numRender_DivLoop: ; $00BD37
        SEC
        SBC.B $04
        BCC numRender_DivDone
        INY
        BRA numRender_DivLoop
; [Text] CLC ADC $04 PHA PHP. Division complete, save remainder.
numRender_DivDone: ; $00BD3F
        CLC
        ADC.B $04
        PHA
        PHP
        SEP #$20
        LDA.B $00
        BNE numRender_ToASCII
        TYA
        BNE numRender_IncLeading
        LDA.W $0A20
        BRA numRender_StoreBuf
; [Text] INC $00 — marks leading digit as nonzero (suppress leading zeros).
numRender_IncLeading: ; $00BD52
        INC.B $00
; [Text] TYA CLC ADC #$30. Converts digit to ASCII character code.
numRender_ToASCII: ; $00BD54
        TYA
        CLC
        ADC.B #$30
; [Text] STA $0400,X INX PLP PLY. Stores digit character to text buffer $0400.
numRender_StoreBuf: ; $00BD58
        STA.W $0400,X
        INX
        PLP
        PLY
        RTS
        db $A0,$00,$00,$A5,$06,$38,$E5,$0A,$85,$06,$A5,$08,$E5,$0C,$85,$08
        db $90,$03,$C8,$80,$EE,$A5,$06,$18,$65,$0A,$85,$06,$A5,$08,$65,$0C
        db $85,$08,$08,$E2,$20,$A5,$00,$D0,$0A,$98,$D0,$05,$AD,$20,$0A,$80
        db $06,$E6,$00,$98,$18,$69,$30,$9D,$00,$04,$E8,$28,$60
; [Text] Copies text buffer data between buffers. Entry: $09F0/$09F2=source, $09F4=width, $09F6=height.
copyTextBuffer: ; $00BD9C
        PHP
        REP #$20
        PHA
        LDX.W $09F0
        LDY.W $09F2
        JSR.W calculateSine
        STX.B $02
        LDA.W $09F6
        DEC A
        STA.B $00
; [Text] LDX $02, LDY $09F4. Copies tile buffer upward — $7E9040→$7E9000 for text scrolling.
textScroll_CopyUp: ; $00BDB1
        LDX.B $02
        LDY.W $09F4
; [Text] LDA $7E9040,X STA $7E9000,X INX INX. Copies bottom tile row to top row.
textScroll_CopyLoop: ; $00BDB6
        LDA.L $7E9040,X
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE textScroll_CopyLoop
        LDA.B $02
        CLC
        ADC.W #$0040
        STA.B $02
        DEC.B $00
        BNE textScroll_CopyUp
        PLA
        BNE textScroll_End
        LDX.B $02
        LDY.W #$0000
        LDA.B $6F
        BEQ textScroll_ClearLine
        LDA.W #$3100
; [Text] LDY $09F4, STA $7E9000,X. Clears bottom tile row after scroll.
textScroll_ClearLine: ; $00BDDE
        LDY.W $09F4
; [Text] STA $7E9000,X INX INX DEY. Fill loop to clear scrolled-out line.
textScroll_ClearLoop: ; $00BDE1
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE textScroll_ClearLoop
        JSR.W waitForFrame
        PLP
        RTS
; [Text] End of text scroll operation.
textScroll_End: ; $00BDEF
        db $AE,$F0,$09,$A8,$20,$40,$C2,$AC,$F4,$09,$A5,$02,$18,$69,$00,$90
        db $85,$02,$A9,$7E,$00,$85,$04,$BF,$00,$90,$7E,$87,$02,$E8,$E8,$E6
        db $02,$E6,$02,$88,$D0,$F1,$20,$0E,$C2,$22,$BE,$E3,$00,$28,$60,$08
        db $C2,$20,$A2
; Clears text tile buffer line in $7E:9000. Fills $80 words with zero.
clearTextTileLine: ; $00BE22
        BRK #$00
        LDY.W #$001E
        JSR.W calculateSine
        LDA.W #$0000
        LDY.W #$0080
; [Text] STA $7E9000,X INX INX DEY. Fills tile buffer line for rendering.
textRender_FillLine: ; $00BE30
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE textRender_FillLine
        PLP
        RTS
; [Text] Main text/dialogue renderer. Reads byte stream from [$14], processes control codes, writes tiles to buffer.
renderTextStream: ; $00BE3B
        REP #$20
        LDA.W $0A0C
        STA.W $0A0A
        STZ.W $0A10
        STZ.W $0A06
        JSR.W calculateBufferOffset
        STZ.W $0A1E
; [Text] Main loop: read next byte from [$14], dispatch by control code
textStreamLoop: ; $00BE4F
        LDA.B [$14]
        INC.B $14
        AND.W #$00FF
        BNE textStream_CheckFF
        JMP.W textStream_Handle00
; [Text] Check for $FF extended control code
textStream_CheckFF: ; $00BE5B
        CMP.W #$00FF
        BNE textStream_Check90
        JMP.W textStream_HandleFF
; [Text] Check for $90 newline/scroll control code
textStream_Check90: ; $00BE63
        CMP.W #$0090
        BNE textStream_CheckD0
        JMP.W textStream_Handle90
; [Text] Check for $D0 icon/special character code
textStream_CheckD0: ; $00BE6B
        CMP.W #$00D0
        BEQ textStream_HandleD0
        CMP.W #$00CE
        BEQ textStreamLoop
; [Text] Write regular character tile and advance cursor
textStream_WriteChar: ; $00BE75
        JSR.W writeTextCharacter
        INC.W $0A10
        LDA.W $0A0A
        BEQ textStream_CheckAutoScroll
        JSR.W setTextRenderParams
        LDA.B $82
        BPL textStream_CheckAutoScroll
        RTS
; [Text] Check if auto-scroll needed after character write
textStream_CheckAutoScroll: ; $00BE88
        LDA.W $0A06
        BNE textStream_CheckLineEnd
        INX
        INX
        INC.W $09FC
; [Text] Compare cursor to line width, loop or handle overflow
textStream_CheckLineEnd: ; $00BE92
        LDA.W $09FC
        DEC A
        CMP.W $09F8
        BCC textStreamLoop
        LDA.W $0A1E
        BNE textStreamLoop
        LDA.B [$14]
        AND.W #$00FF
        CMP.W #$0091
        BEQ textStream_SetPauseFlag
        CMP.W #$0093
        BEQ textStream_SetPauseFlag
        CMP.W #$0094
        BEQ textStream_SetPauseFlag
        CMP.W #$00A0
        BEQ textStream_SetPauseFlag
        BRA textStream_Handle90
; [Text] $D0 handler: icon/special char - read param, compute tile, write
textStream_HandleD0: ; $00BEBB
        LDA.W $0A1C
        BNE textStream_StorePauseCode
        LDA.B [$14]
        INC.B $14
        AND.W #$00FF
        ASL A
        CLC
        ADC.W #$0180
        PHA
        JSR.W writeTextCharacter
        INC.W $0A10
        INX
        INX
        INC.W $09FC
        PLA
        INC A
        BRA textStream_WriteChar
; [Text] STA $0A06. Stores pause/wait flag value from control code ($91/$93/$94/$A0).
textStream_StorePauseCode: ; $00BEDC
        db $A7,$14,$E6,$14,$29,$FF,$00,$0A,$0A,$18,$69,$00,$03,$48,$20,$56
        db $C1,$EE,$10,$0A,$E8,$E8,$EE,$FC,$09,$68,$1A,$1A,$4C,$75,$BE
; [Text] Set pause/wait flag from control code ($91/$93/$94/$A0)
textStream_SetPauseFlag: ; $00BEFB
        STA.W $0A06
        JMP.W textStreamLoop
; [Text] $90 newline handler: scroll text window if at bottom, reset cursor
textStream_Handle90: ; $00BF01
        LDA.W $09FE
        CMP.W #$003E
        BNE textStream_90_Advance
        db $A9,$1E,$00,$20,$9C,$BD,$A9,$1F,$00,$20,$9C,$BD,$20,$1E,$BE,$AD
        db $04,$0A,$18,$69,$02,$00,$8D,$04,$0A,$CD,$F6,$09,$90,$06,$20,$7F
        db $C2,$9C,$04,$0A,$80,$1D
; [Text] Advance line counter, check if scroll needed
textStream_90_Advance: ; $00BF2F
        CLC
        ADC.W #$0002
        CMP.W $09FA
        BCC textStream_90_StoreLine
        JSR.W checkTextActive
        LDA.W #$0000
        JSR.W copyTextBuffer
        LDA.W #$0000
        JSR.W copyTextBuffer
        BRA textStream_90_ResetCursor
; [Text] Store new line position
textStream_90_StoreLine: ; $00BF49
        STA.W $09FE
; [Text] Reset cursor position and char count for new line
textStream_90_ResetCursor: ; $00BF4C
        LDA.W $09F0
        STA.W $09FC
        STZ.W $0A06
        STZ.W $0A10
        JSR.W calculateBufferOffset
        JMP.W textStreamLoop
; [Text] $00 null terminator handler: check if at dialog bottom
textStream_Handle00: ; $00BF5E
        LDA.W $09FE
        CMP.W #$003E
; [Text] Text engine Phase 2: renders buffer, dispatches by byte value
processText: ; $00BF64
        BNE textStream_RTS
        db $A9,$1E,$00,$20,$9C,$BD,$A9,$1F,$00,$20,$9C,$BD,$AD,$FA,$09,$38
        db $E9,$02,$00,$8D,$FE,$09
; [Text] RTS — Phase 2 sub-function return.
textStream_RTS: ; $00BF7C
        RTS
; [Text] $FF extended control: read sub-command byte, dispatch
textStream_HandleFF: ; $00BF7D
        LDA.B [$14]
        INC.B $14
        AND.W #$00FF
        CMP.W #$00F0
        BCS textStream_HandleExtended
        CMP.W #$0080
        BEQ textStream_FFReadCode
        AND.W #$001F
        STA.W $09FC
; [Text] LDA [$14] AND $FF, CMP #$80 BCS high. Reads FF sub-command, dispatches by range.
textStream_FFReadCode: ; $00BF94
        LDA.B [$14]
        AND.W #$00FF
        CMP.W #$0080
        BCS textStream_FFHighMask
        AND.W #$001F
        STA.W $09FE
        STZ.W $0A06
        BRA textStream_FFAdvance
; [Text] AND #$3F STA $00, LDA $09FE SEC. Masks high FF code, reads current line position.
textStream_FFHighMask: ; $00BFA9
        AND.W #$003F
        STA.B $00
        LDA.W $09FE
        SEC
        SBC.B $00
        STA.W $09FE
        STZ.W $0A06
; [Text] INC $14, JSR calculateBufferOffset, JMP textStreamLoop. Advances past FF byte, recalcs offset.
textStream_FFAdvance: ; $00BFBA
        INC.B $14
        JSR.W calculateBufferOffset
        JMP.W textStreamLoop
; [Text] Extended $F1: toggle text state flag
textStream_ExtF1: ; $00BFC2
        LDA.B [$14]
        AND.W #$00FF
        INC.B $14
        CMP.W #$0001
        BNE textStream_ExtF1_SetPos
        STZ.W $0A1E
        JMP.W textStreamLoop
; [Text] Extended $F1 param>1: set cursor Y position from param
textStream_ExtF1_SetPos: ; $00BFD4
        SEP #$20
        DEC A
        ASL A
        ASL A
        CLC
        ADC.B #$21
        STA.W $0A1F
        REP #$20
        JMP.W textStreamLoop
; [Text] Extended $F2: write auto-delay value from stream
textStream_ExtF2: ; $00BFE4
        LDA.B [$14]
        AND.W #$00FF
        INC.B $14
        JSR.W setTextRenderParams
        JMP.W textStreamLoop
; [Text] Extended control dispatcher ($F0-$FF sub-commands)
textStream_HandleExtended: ; $00BFF1
        CMP.W #$00FF
        BEQ textStream_ExtFF
        CMP.W #$00FE
        BEQ textStream_ExtFE
        CMP.W #$00FD
        BEQ textStream_ExtFD
        CMP.W #$00FC
        BEQ textStream_ExtFC
        CMP.W #$00FB
        BEQ textStream_ExtFB
        CMP.W #$00FA
        BNE textStream_ExtDispatch
        INC.W $0A16
        JMP.W textStream_Handle00
; [Text] CMP #$F1 BEQ, CMP #$F2 BEQ. Extended FF command dispatcher — checks F1, F2, etc.
textStream_ExtDispatch: ; $00C015
        CMP.W #$00F1
        BEQ textStream_ExtF1
        CMP.W #$00F2
        BEQ textStream_ExtF2
        db $4C,$4F,$BE
; [Text] Extended $FF: call monitorParty, then continue
textStream_ExtFF: ; $00C022
        JSL.L initTilemapAndSync_Long
        BRA textStream_FFAdvance
; [Text] Extended $FE: call scrollTextWindow, then continue
textStream_ExtFE: ; $00C028
        JSR.W checkTextActive
        BRA textStream_FFAdvance
; [Text] Extended $FD: set auto-advance delay from stream byte (or $FF=from RAM)
textStream_ExtFD: ; $00C02D
        LDA.B [$14]
        AND.W #$00FF
        CMP.W #$00FF
        BNE textStream_ExtFD_Store
        db $AF,$84,$EA,$7E
; [Text] Store auto-advance delay value
textStream_ExtFD_Store: ; $00C03B
        STA.W $0A0A
        JMP.W textStream_FFAdvance
; [Text] Extended $FB: set text Y offset from stream byte
textStream_ExtFB: ; $00C041
        SEP #$20
        LDA.B [$14]
        ASL A
        ASL A
        ASL A
        CLC
        ADC.B #$20
        STA.W $0A03
        REP #$20
        JMP.W textStream_FFAdvance
; [Text] Extended $FC: choice/menu selection handler
textStream_ExtFC: ; $00C053
        LDA.B [$14]
        AND.W #$00FF
        CMP.W #$0080
        BCS textStream_FC_Grid
        STA.W $0A12
        LDA.W $09FE
        STA.B $22
        STZ.W $0A08
; [Text] LDA $0A08 ASL CLC ADC $22. Calculates cursor position for choice/menu selection.
textStream_FC_CalcPos: ; $00C068
        LDA.W $0A08
        ASL A
        CLC
        ADC.B $22
        STA.W $09FE
        JSR.W pollInputFlashCursor
        LDA.B $50
        AND.W #$0400
        BEQ textStream_FC_CheckRight
        JSR.W incrementCounter3
        LDA.W $0A08
        INC A
        CMP.W $0A12
        BEQ textStream_FC_CheckRight
        STA.W $0A08
        BRA textStream_FC_CalcPos
; [Text] Choice handler: check right button press
textStream_FC_CheckRight: ; $00C08D
        LDA.B $50
        AND.W #$0800
        BEQ textStream_FC_CheckCancel
        db $20,$47,$C1,$AD,$08,$0A,$F0,$05,$CE,$08,$0A,$80,$C7
; [Text] Choice handler: check B/cancel button
textStream_FC_CheckCancel: ; $00C0A1
        LDA.B $50
        AND.W #$8000
        BEQ textStream_FC_CheckConfirm
        db $A9,$02,$00,$20,$4A,$C1,$9C,$08,$0A,$4C,$BA,$BF
; [Text] Choice handler: check A/confirm button
textStream_FC_CheckConfirm: ; $00C0B4
        LDA.B $50
        AND.W #$0080
        BNE textStream_FC_Confirm
        db $80,$AB
; [Text] LDA #1 JSR $C14A, INC $0A08. Processes confirm input in choice menu.
textStream_FC_Confirm: ; $00C0BD
        LDA.W #$0001
        JSR.W incrementCounter8
        INC.W $0A08
        JMP.W textStream_FFAdvance
; [Text] Extended $FC with param>=$80: grid-style choice menu
textStream_FC_Grid: ; $00C0C9
        AND.W #$007F
        STA.W $0A12
        LDA.W $09FC
        STA.B $24
        LDA.W $0A08
        STA.B $22
        STZ.W $0A08
; [Text] Grid choice: hardware multiply for cursor position
textStream_FC_Grid_Loop: ; $00C0DC
        SEP #$20
        LDA.W $0A08
        STA.W $4202
        LDA.B $22
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDY.W $4216
        REP #$20
        TYA
        CLC
        ADC.B $24
        STA.W $09FC
        JSR.W pollInputFlashCursor
        LDA.B $50
        AND.W #$0100
        BEQ textStream_FC_Grid_Down
        JSR.W incrementCounter3
        LDA.W $0A08
        INC A
        CMP.W $0A12
        BEQ textStream_FC_Grid_Down
        STA.W $0A08
        BRA textStream_FC_Grid_Loop
; [Text] Grid choice: check down button
textStream_FC_Grid_Down: ; $00C114
        LDA.B $50
        AND.W #$0200
        BEQ textStream_FC_Grid_Cancel
        JSR.W incrementCounter3
        LDA.W $0A08
        BEQ textStream_FC_Grid_Cancel
        DEC.W $0A08
        BRA textStream_FC_Grid_Loop
; [Text] Grid choice: check cancel
textStream_FC_Grid_Cancel: ; $00C128
        LDA.B $50
        AND.W #$8000
        BEQ textStream_FC_Grid_Confirm
        LDA.W #$0002
        JSR.W incrementCounter8
        STZ.W $0A08
        JMP.W textStream_FFAdvance
; [Text] Grid choice: check confirm, store selection
textStream_FC_Grid_Confirm: ; $00C13B
        LDA.B $50
        AND.W #$0080
        BEQ textStream_FC_GridLoop
        JMP.W textStream_FC_Confirm
; [Text] BRA textStream_FC_Grid_Loop. Branches back to grid choice input loop.
textStream_FC_GridLoop: ; $00C145
        BRA textStream_FC_Grid_Loop
; [Timer] Increments counter at $81. Entry: A=value. Similar to incrementCounter but with different entry.
incrementCounter3: ; $00C147
        LDA.W #$0003
; [Timer] Increments 8-bit counter at $81. Entry: A=value (8-bit).
incrementCounter8: ; $00C14A
        SEP #$20
        INC A
        STA.B $81
        REP #$20
        RTS
; [Helper] Wrapper for checkZero function. Entry: A=value. Returns via RTL.
checkZeroWrapper: ; $00C152
        JSR.W writeTextCharacter
        RTL
; [Text] Writes single character to text buffer. Entry: A=character code, X=buffer offset. Writes to top/bottom buffers based on $0A1C/$0A1E flags.
writeTextCharacter: ; $00C156
        CMP.W #$0000
        BNE textChar_CheckMode
        LDA.B $6F
        BEQ textChar_CheckMode
        LDA.W $0A1C
        BNE textChar_AltMode
        LDA.W #$0100
        STA.L $7E9000,X
        STA.L $7E9040,X
        RTS
; [Text] PHA, LDA $0A1E BNE alt, LDA $0A1C. Checks special rendering mode flags before writing.
textChar_CheckMode: ; $00C170
        PHA
        LDA.W $0A1E
        BNE textChar_CalcTileAddr
        LDA.W $0A1C
        BNE textChar_AltMode
; [Text] Writes tilemap entry for character to top/bottom buffers. Entry: character code on stack, X=buffer offset. Adds $0A02 (priority/palette bits) to character index. Writes to $7E9000,X (top tile) and $7E9040,X (bottom tile) with +$0400 palette difference. Each buffer holds 32 tiles (16x2 area), each entry 2 bytes: tile# low + VHPPCCCC (V=vert flip, H=horiz flip, P=priority, CCCC=palette).
writeTilemapEntry: ; $00C17B
        PLA
        CLC
        ADC.W $0A02
        PHA
        STA.L $7E9000,X
        PLA
        CLC
        ADC.W #$0400
        STA.L $7E9040,X
        RTS
; [Text] PLA — alternate character write path entry (special mode $0A1E).
textChar_AltMode: ; $00C18F
        db $68,$C9,$80,$01,$B0,$01,$0A,$18,$6D,$02,$0A,$48,$9F,$00,$90,$7E
        db $68,$1A,$9F,$40,$90,$7E,$60
; [Text] PLA SEC SBC #$20 CLC. Calculates tile address: subtract $20 (space offset) for indexing.
textChar_CalcTileAddr: ; $00C1A6
        PLA
        SEC
        SBC.W #$0020
        CLC
        ADC.W $0A1E
        STA.L $7E9000,X
        RTS
; Stores text layout params to $0A2E/$0A28/$0A2A/$0A2C.
setTextRenderParams: ; $00C1B4
        REP #$20
        STA.W $0A2E
        LDA.B $14
        STA.W $0A28
        LDA.B $16
        STA.W $0A2A
        STX.W $0A2C
        JSR.W waitForFrame
; [Text] DEC $0A2E, check zero. Auto-advance delay countdown for per-character timing.
textChar_AutoDelay: ; $00C1C9
        DEC.W $0A2E
        LDA.W $0A2E
        BEQ NMITIMEN
        LDA.B $6A
        AND.W #$00FF
        CMP.W #$0001
        BNE textChar_WaitFrame
        JSL.L renderSprites
; [Text] JSL updateTransparency, LDA $4E AND #$30 BNE done. Waits for frame with transparency update.
textChar_WaitFrame: ; $00C1DF
        JSL.L readJoypadNewPress
        LDA.B $4E
        AND.W #$0030
        BNE NMITIMEN
        LDA.B $82
        BEQ textChar_WaitShadow
        LDA.B $4E
        AND.W #$3000
        BNE textChar_SetEndFlag
; [Text] JSL updateShadowEffect BRA autoDelay. Waits with shadow effect update loop.
textChar_WaitShadow: ; $00C1F5
        JSL.L waitForModeSync
        BRA textChar_AutoDelay
; [Text] LDA #$FFFF STA $82, LDA $0A28. Sets text-complete flag ($82=$FFFF).
textChar_SetEndFlag: ; $00C1FB
        LDA.W #$FFFF
        STA.B $82
; [Helper] Interrupt Enable Register
NMITIMEN: ; $00C200
        LDA.W $0A28
; [Helper] Multiplicand Registers
WRMPYB: ; $00C203
        STA.B $14
; [Helper] Divisor & Dividend Registers
WRDIVH: ; $00C205
        LDA.W $0A2A
; [Helper] IRQ Timer Registers (Horizontal - High)
HTIMEH: ; $00C208
        STA.B $16
; [Helper] IRQ Timer Registers (Vertical - High)
VTIMEH: ; $00C20A
        LDX.W $0A2C
; [Helper] ROM Speed Register
MEMSEL: ; $00C20D
        RTS
; INC $57 frame flag, JSL waitForModeSync.
waitForFrame: ; $00C20E
        PHP
        SEP #$20
; [Helper] Interrupt Flag Registers
TIMEUP: ; $00C211
        INC.B $57
; [Helper] IO Port Read Register
RDIO: ; $00C213
        JSL.L waitForModeSync
; [Helper] Multiplication Or Divide Result Registers (High)
RDMPYH: ; $00C217
        PLP
; [Helper] Controller Port Data Registers (Pad 1 - Low)
JOY1L: ; $00C218
        RTS
; Loads $09FC/$09FE cursor pos, adds $0A00.
readTextCursorState: ; $00C219
        REP #$20
; [Helper] Controller Port Data Registers (Pad 2 - High)
JOY2H: ; $00C21B
        LDX.W $09FC
; [Helper] Controller Port Data Registers (Pad 4 - Low)
JOY4L: ; $00C21E
        LDA.W $09FE
        CLC
        ADC.W $0A00
        TAY
        CPY.W #$003E
        BNE textChar_JmpCalcSine
        db $AC,$FA,$09,$88,$88
; [Text] JMP calculateSine ($C240). Jumps to sine calculation for wavy text effect.
textChar_JmpCalcSine: ; $00C230
        JMP.W calculateSine
; [Text] Calculates buffer position from column/row/width. Entry: $09FC=column, $09FE=row, $0A00=width. Returns X=offset.
calculateBufferOffset: ; $00C233
        REP #$20
        LDX.W $09FC
        LDA.W $09FE
        CLC
        ADC.W $0A00
        TAY
; [Math] Calculates sine value using lookup table. Entry: A=angle (0-255). Returns A=sine value (8.8 fixed point).
calculateSine: ; $00C240
        TXA
        ASL A
        STA.B $00
        TYA
        AND.W #$001F
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        CLC
        ADC.B $00
        TAX
        RTS
        db $08,$C2,$20,$85,$04,$98,$A0,$00,$00,$38,$E5,$04,$90,$03,$C8,$80
        db $F8,$18,$65,$04,$48,$98,$7A,$28,$60,$A0,$00,$00,$C9,$00,$80,$B0
        db $01,$60,$C8,$85,$00,$A9,$00,$00,$38,$E5,$00,$60
; Checks $0A10 text pause flag; returns if zero.
checkTextActive: ; $00C27F
        LDA.W $0A10
        BNE textWait_Frame
        db $60
; [Text] JSR $C29A, LDA $0A06 BEQ done JSR $C219. Frame wait with pause flag check.
textWait_Frame: ; $00C285
        JSR.W waitForButtonPressText
        LDA.W $0A06
        BEQ textWait_RTS
        db $20,$19,$C2,$AD,$06,$0A,$20,$56,$C1,$20,$0E,$C2
; [Text] RTS — text wait return.
textWait_RTS: ; $00C299
        RTS
; Polls controller ($50 AND #$F0F0) during text display.
waitForButtonPressText: ; $00C29A
        PHP
        REP #$20
; [Text] JSR $C2A9, LDA $50 AND #$F0F0 BEQ poll. Polls controller for any button press.
textWait_PollInput: ; $00C29D
        JSR.W pollInputFlashCursor
        LDA.B $50
        AND.W #$F0F0
        BEQ textWait_PollInput
        PLP
        RTS
; JSL readJoypadNewPress + flash cursor indicator.
pollInputFlashCursor: ; $00C2A9
        PHP
        REP #$20
        JSL.L readJoypadNewPress
        STZ.B $0E
; [Text] JSR $C219, LDY #$3E, INC $0E. Flashes cursor indicator while waiting for input.
textWait_FlashCursor: ; $00C2B2
        JSR.W readTextCursorState
        LDY.W #$003E
        INC.B $0E
        LDA.B $0E
        AND.W #$0010
        BEQ textWait_WriteCursor
        LDY.W #$0000
; [Text] TYA JSR writeTextCharacter JSR $C20E JSL updateTransparency. Writes animated cursor char.
textWait_WriteCursor: ; $00C2C4
        TYA
        JSR.W writeTextCharacter
        JSR.W waitForFrame
        JSL.L readJoypadNewPress
        LDA.B $50
        BEQ textWait_FlashCursor
        JSR.W readTextCursorState
        LDA.W #$0000
        JSR.W writeTextCharacter
        JSR.W waitForFrame
        PLP
        RTS
; Stores text scroll params to $0A36/$0A38/$0A3A.
setTextScrollParams: ; $00C2E1
        REP #$20
        STA.W $0A36
        STX.W $0A38
        STY.W $0A3A
        TYA
        AND.W #$0080
        BEQ DAS2B
        INC.W $0A36
        JSR.W readTileDataWord
        PHA
        DEC.W $0A36
        JSR.W readTileDataWord
        STA.B $00
; [Helper] (H)DMA B-Bus Address
BBAD0: ; $00C301
        PLA
; [Helper] DMA A-Bus Address / HDMA Table Address (Low)
A1T0L: ; $00C302
        SEC
; [Helper] DMA A-Bus Address / HDMA Table Address (High)
A1T0H: ; $00C303
        SBC.B $00
; [Helper] DMA Size / HDMA Indirect Address (Low)
DAS0L: ; $00C305
        INC A
; [Helper] DMA Size / HDMA Indirect Address (High)
DAS0H: ; $00C306
        STA.B $16
; [Helper] HDMA Mid Frame Table Address (Low)
A2A0L: ; $00C308
        JSR.W setupTileDataFromROM
        LDX.W #$0000
; [Text] LDA [$12] STA $7E2000,X. Loads tile data from source to WRAM $7E2000.
textGfx_LoadTile: ; $00C30E
        LDA.B [$12]
; [Helper] (H)DMA Control
DMAP1: ; $00C310
        STA.L $7E2000,X
; [Helper] DMA A-Bus Address / HDMA Table Address (Bank)
A1B1: ; $00C314
        LDA.B $12
; [Helper] DMA Size / HDMA Indirect Address (High)
DAS1H: ; $00C316
        INC A
; [Helper] HDMA Indirect Address (Bank)
DAS1B: ; $00C317
        INC A
; [Helper] HDMA Mid Frame Table Address (Low)
A2A1L: ; $00C318
        BNE textGfx_StorePtr
; [Helper] HDMA Line Counter
NTLR1: ; $00C31A
        INC.B $14
        LDA.W #$8000
; [Text] STA $12 INX. Stores updated source pointer.
textGfx_StorePtr: ; $00C31F
        STA.B $12
; [Helper] (H)DMA B-Bus Address
BBAD2: ; $00C321
        INX
; [Helper] DMA A-Bus Address / HDMA Table Address (Low)
A1T2L: ; $00C322
        INX
; [Helper] DMA A-Bus Address / HDMA Table Address (High)
A1T2H: ; $00C323
        CPX.B $16
; [Helper] DMA Size / HDMA Indirect Address (Low)
DAS2L: ; $00C325
        BCC textGfx_LoadTile
; [Helper] HDMA Indirect Address (Bank)
DAS2B: ; $00C327
        LDA.W $0A3A
; [Helper] HDMA Line Counter
NTLR2: ; $00C32A
        AND.W #$0002
        BNE DAS6H
        JSR.W setupTileDataPointer
; [Helper] DMA A-Bus Address / HDMA Table Address (Low)
A1T3L: ; $00C332
        LDY.W #$0006
; [Helper] DMA Size / HDMA Indirect Address (Low)
DAS3L: ; $00C335
        LDA.B [$12],Y
; [Helper] HDMA Indirect Address (Bank)
DAS3B: ; $00C337
        CMP.W #$0020
; [Helper] HDMA Line Counter
NTLR3: ; $00C33A
        BEQ DAS6H
        LDX.W #$5000
        LDA.W $0A38
; [Helper] DMA A-Bus Address / HDMA Table Address (Low)
A1T4L: ; $00C342
        CMP.W #$2000
; [Helper] DMA Size / HDMA Indirect Address (Low)
DAS4L: ; $00C345
        BCC NTLR4
; [Helper] HDMA Indirect Address (Bank)
DAS4B: ; $00C347
        LDX.W #$2000
; [Helper] HDMA Line Counter
NTLR4: ; $00C34A
        LDA.W $0A3A
        AND.W #$0010
; [Helper] (H)DMA Control
DMAP5: ; $00C350
        BEQ DAS5L
; [Helper] DMA A-Bus Address / HDMA Table Address (Low)
A1T5L: ; $00C352
        LDX.W #$4000
; [Helper] DMA Size / HDMA Indirect Address (Low)
DAS5L: ; $00C355
        LDY.W #$1800
; [Helper] HDMA Mid Frame Table Address (Low)
A2A5L: ; $00C358
        LDA.W $0A3A
        AND.W #$0040
        BEQ A1T6H
; [Helper] (H)DMA Control
DMAP6: ; $00C360
        LDY.W #$2000
; [Helper] DMA A-Bus Address / HDMA Table Address (High)
A1T6H: ; $00C363
        JSR.W waitForVBlank2
; [Helper] DMA Size / HDMA Indirect Address (High)
DAS6H: ; $00C366
        LDA.W $0A3A
; [Helper] HDMA Mid Frame Table Address (High)
A2A6H: ; $00C369
        AND.W #$0004
        BNE textGfx_CheckDMA
        JSR.W readTileDataByte
; [Helper] (H)DMA B-Bus Address
BBAD7: ; $00C371
        LDA.W #$0007
; [Helper] DMA A-Bus Address / HDMA Table Address (Bank)
A1B7: ; $00C374
        STA.B $00
; [Helper] DMA Size / HDMA Indirect Address (High)
DAS7H: ; $00C376
        LDA.W #$0001
; [Helper] HDMA Mid Frame Table Address (High)
A2A7H: ; $00C379
        STA.B $02
        LDA.W $0A38
        CMP.W #$2000
        BCC textGfx_CheckFlags
        LDA.W #$0002
        STA.B $00
; [Text] LDA $0A3A AND #1 BEQ skip LDA #$80. Checks text graphics config flags.
textGfx_CheckFlags: ; $00C388
        LDA.W $0A3A
        AND.W #$0001
        BEQ textGfx_EnableInterrupts
        db $A9,$80,$00,$04,$00
; [Text] JSL enableInterrupts, LDA $0A3A AND #8. Re-enables interrupts, checks more flags.
textGfx_EnableInterrupts: ; $00C395
        JSL.L unpackTileProperties
; [Text] LDA $0A3A AND #8 BEQ skip JMP $C453. Checks if DMA transfer needed for text tiles.
textGfx_CheckDMA: ; $00C399
        LDA.W $0A3A
        AND.W #$0008
        BEQ textGfx_ReadInput
        db $4C,$53,$C4
; [Text] JSR readJoypadEdge ($C4B1), LDA $12 CLC ADC #$20. Reads input during graphics setup.
textGfx_ReadInput: ; $00C3A4
        JSR.W readTileDataByte
        LDA.B $12
        CLC
        ADC.W #$0020
        STA.B $12
        LDA.W $0A3A
        AND.W #$0020
        BNE textGfx_CopyWRAM
        JSR.W clearTileBuffer
        BRA textGfx_SetPalette
; [Text] LDX #0, LDA $7FF000,X STA $7FB000,X. Copies WRAM $7F:F000 → $7F:B000 (tilemap buffer).
textGfx_CopyWRAM: ; $00C3BC
        LDX.W #$0000
; [Text] LDA $7FF000,X STA $7FB000,X INX INX. WRAM copy loop body.
textGfx_CopyLoop: ; $00C3BF
        LDA.L $7FF000,X
        STA.L $7FB000,X
        INX
        INX
        CPX.W #$0800
        BNE textGfx_CopyLoop
; [Text] LDA #$3F00 STA $06, LDA $0A38. Sets palette/priority bits for text tiles.
textGfx_SetPalette: ; $00C3CE
        LDA.W #$3F00
        STA.B $06
        LDA.W $0A38
        LDY.W #$7000
        CMP.W #$2000
        BCS textGfx_VRAMBase7800
        CMP.W #$0800
        BCC textGfx_CheckPriority
        LDY.W #$7400
; [Text] LDA $0A3A AND #$10 BEQ skip LDA #$3E00. Checks priority flag for alternate palette.
textGfx_CheckPriority: ; $00C3E6
        LDA.W $0A3A
        AND.W #$0010
        BEQ textGfx_SetVRAMBase
        LDA.W #$3E00
        STA.B $06
; [Text] BRA common. Falls through to VRAM base address setup.
textGfx_SetVRAMBase: ; $00C3F3
        BRA textGfx_CheckBit8
; [Text] LDY #$7800 LDA #$0800 STA $06. VRAM base $7800, size $0800.
textGfx_VRAMBase7800: ; $00C3F5
        LDY.W #$7800
        LDA.W #$0800
        STA.B $06
; [Text] LDA $0A3A AND #$100 BEQ skip LDA #$2000. Checks bit 8 of config for alternate mode.
textGfx_CheckBit8: ; $00C3FD
        LDA.W $0A3A
        AND.W #$0100
        BEQ textGfx_StoreVRAM
        db $A9,$00,$20,$14,$06
; [Text] STY $78, LDA $0A38 AND #$07FE TAX. Stores VRAM destination, masks data address.
textGfx_StoreVRAM: ; $00C40A
        STY.B $78
        LDA.W $0A38
        AND.W #$07FE
        TAX
; [Text] PHX LDY $08. Pushes X, loads Y for tile decompression loop.
textGfx_PushAndRead: ; $00C413
        PHX
        LDY.B $08
; [Text] LDA [$12] AND $FF INC $12 CMP #$FF. Reads compressed tile byte, checks for $FF terminator.
textGfx_DecompTile: ; $00C416
        LDA.B [$12]
        AND.W #$00FF
        INC.B $12
        CMP.W #$00FF
        BNE textGfx_StoreTile
        LDA.B $06
        EOR.W #$4000
        STA.B $06
        LDA.B [$12]
        AND.W #$00FF
        INC.B $12
; [Text] ORA $06 STA $7FB000,X INX INX. ORs palette bits and stores to WRAM buffer.
textGfx_StoreTile: ; $00C430
        ORA.B $06
        STA.L $7FB000,X
        INX
        INX
        DEY
        BNE textGfx_DecompTile
        PLA
        CLC
        ADC.W #$0040
        TAX
        DEC.B $0A
        LDA.B $0A
        BNE textGfx_PushAndRead
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSL.L waitForModeSync
        RTL
; If $0A3A bit 7 set, load [$12/$14]=$7E:2000; else fall through to setupTileDataFromROM.
setupTileDataPointer: ; $00C454
        REP #$20
        LDA.W $0A3A
        AND.W #$0080
        BEQ setupTileDataFromROM
        LDA.W #$007E
        STA.B $14
        LDA.W #$2000
        STA.B $12
        RTS
; Load [$12/$14]=$24:8000, adjust bank by $0A37 AND 7, call readIndexedTableEntry for $0A36 index.
setupTileDataFromROM: ; $00C469
        LDA.W #$0024
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.W $0A36
        CMP.W #$0100
        BCC textGfx_SetupNMI
        LDA.W $0A37
        AND.W #$0007
        CLC
        ADC.B $14
        STA.B $14
        LDA.W $0A36
        AND.W #$00FF
; [Text] JSR setupNMI ($C585) RTS. Configures NMI for text graphics transfer.
textGfx_SetupNMI: ; $00C48C
        JSR.W readIndexedTableEntry
        RTS
; Load [$12/$14]=$24:8000+, read word at ($0A36 AND $FF)*4 index from tileset table.
readTileDataWord: ; $00C490
        LDA.W #$0024
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.W $0A37
        AND.W #$0007
        CLC
        ADC.B $14
        STA.B $14
        LDA.W $0A36
        AND.W #$00FF
        ASL A
        ASL A
        TAY
        LDA.B [$12],Y
        RTS
; Call setupTileDataPointer, save [$12], add 4, read byte from tileset entry.
readTileDataByte: ; $00C4B1
        REP #$20
        JSR.W setupTileDataPointer
        LDA.B $12
        STA.B $16
        CLC
        ADC.W #$0004
        STA.B $12
        LDA.B [$12]
        AND.W #$00FF
        STA.B $08
        INC.B $12
        LDA.B [$12]
        AND.W #$00FF
        STA.B $0A
        INC.B $12
        LDA.B [$12]
        CLC
        ADC.B $16
        STA.B $12
        RTS
; [Helper] Alternative V-blank wait routine. Entry: polls $4212 with timeout. Returns carry set if timeout.
waitForVBlank2: ; $00C4DA
        REP #$20
        STY.B $04
        STZ.B $02
        STX.B $78
        LDY.W #$0000
; [Text] LDX #0, LDA [$12] STA $7FB000,X. Direct (uncompressed) tile copy to WRAM.
textGfx_DirectCopy: ; $00C4E5
        LDX.W #$0000
; [Text] LDA [$12] STA $7FB000,X INX INX. Direct copy loop body.
textGfx_DirectLoop: ; $00C4E8
        LDA.B [$12]
        STA.L $7FB000,X
        INX
        INX
        INC.B $12
        INC.B $12
        CPX.W #$0800
        BNE textGfx_DirectLoop
        LDA.B $02
        BNE CODE_80C50F
        LDX.W #$0000
        LDY.W #$0010
        LDA.W #$0000
CODE_80C506: ; $00C506
        STA.L $7FB000,X
        INX
        INX
        DEY
        BNE CODE_80C506
CODE_80C50F: ; $00C50F
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSL.L waitForModeSync
        LDA.B $78
        CLC
        ADC.W #$0400
        STA.B $78
        LDA.B $02
        CLC
        ADC.W #$0800
        STA.B $02
        CMP.B $04
        BCC textGfx_DirectCopy
        RTS
; Chunked copy [$12] -> $7F:B000, 2048 bytes/chunk, VBlank sync between chunks. RTL.
copyToTileBuffer: ; $00C530
        REP #$20
        STY.B $04
        STZ.B $02
        STX.B $78
        LDY.W #$0000
CODE_80C53B: ; $00C53B
        LDX.W #$0000
CODE_80C53E: ; $00C53E
        LDA.B [$12]
        STA.L $7FB000,X
        INX
        INX
        INC.B $12
        INC.B $12
        CPX.W #$0800
        BNE CODE_80C53E
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSL.L waitForModeSync
        LDA.B $78
        CLC
        ADC.W #$0400
        STA.B $78
        LDA.B $02
        CLC
        ADC.W #$0800
        STA.B $02
        CMP.B $04
        BCC CODE_80C53B
        RTL
; Zero-fill $7F:B000, 2048 bytes (0x400 words). RTS.
clearTileBuffer: ; $00C570
        REP #$20
        LDX.W #$0000
        LDA.W #$0000
        LDY.W #$0400
CODE_80C57B: ; $00C57B
        STA.L $7FB000,X
        INX
        INX
        DEY
        BNE CODE_80C57B
        RTS
; Read 4-byte record at A*4 from [$12] table, advance [$12/$14] pointer. RTS.
readIndexedTableEntry: ; $00C585
        REP #$20
        PHY
        ASL A
        ASL A
        TAY
        LDA.B [$12],Y
        PHA
        INY
        INY
        LDA.B [$12],Y
        ASL A
        CLC
        ADC.B $14
        STA.B $14
        PLA
        CLC
        ADC.B $12
        BCC CODE_80C5A3
        ORA.W #$8000
        INC.B $14
CODE_80C5A3: ; $00C5A3
        STA.B $12
        PLY
        RTS
; Extract packed 5-bit fields from [$12] data -> $7F:E800 entries (stride 8). Calls setupHdmaScroll.
unpackTileProperties: ; $00C5A7
        REP #$20
        JSR.W setupHdmaScroll
        LDY.W #$0000
CODE_80C5AF: ; $00C5AF
        LDA.B [$12],Y
        STA.B $06
        INY
        INY
        LDA.B $06
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        AND.W #$001F
        SEP #$20
        STA.L $7FE800,X
        LDA.B $06
        AND.B #$1F
        STA.L $7FE801,X
        LDA.B $07
        LSR A
        LSR A
        AND.B #$1F
        STA.L $7FE802,X
        REP #$20
        TXA
        CLC
        ADC.W #$0008
        TAX
        DEC.B $04
        LDA.B $04
        BNE CODE_80C5AF
        LDA.B $00
        CMP.W #$0080
        BCS CODE_80C5FF
        LDA.B $10
        AND.W #$00FF
        CMP.W #$0003
        BCC CODE_80C5FC
        JSL.L uploadPaletteWrapper
        BRA CODE_80C5FF
CODE_80C5FC: ; $00C5FC
        JSR.W setupCGRAM
CODE_80C5FF: ; $00C5FF
        RTL
; Save $00/$02 -> $22/$24, iterate calling processScrollEntries ($C6D6).
processScrollLoop: ; $00C600
        REP #$20
        LDA.B $00
        STA.B $22
        LDA.B $02
        STA.B $24
CODE_80C60A: ; $00C60A
        LDA.B $22
        STA.B $00
        LDA.B $24
        STA.B $02
        JSR.W processScrollEntries
        BEQ CODE_80C61C
        JSR.W setupCGRAM
        BRA CODE_80C60A
CODE_80C61C: ; $00C61C
        JSR.W setupCGRAM
        RTL
; HDMA scroll setup: params to $04/$06.
setupHdmaScroll: ; $00C620
        REP #$20
        LDA.W #$0004
        STA.B $06
        SEP #$20
        STZ.B $04
        LDA.B $00
        CMP.B #$80
        BCS CODE_80C633
        STZ.B $06
CODE_80C633: ; $00C633
        AND.B #$7F
        STA.B $05
        REP #$20
        LDA.B $04
        LSR A
        CLC
        ADC.B $06
        TAX
        LDA.B $02
        ASL A
        ASL A
        ASL A
        ASL A
        STA.B $04
        RTS
        db $20,$4D,$C6,$6B
; Sets up HDMA/DMA parameters.
setupHdmaParams: ; $00C64D
        SEP #$20
        STA.B $05
        STZ.B $04
        REP #$20
        LDA.B $04
        LSR A
        TAX
        REP #$20
        LDY.W #$0010
        LDA.W #$0DC0
        STA.B $12
CODE_80C663: ; $00C663
        JSR.W lookupMapTileType
        STA.B ($12)
        INC.B $12
        INC.B $12
        TXA
        CLC
        ADC.W #$0008
        TAX
        DEY
        BNE CODE_80C663
        SEP #$20
        LDA.B $05
        ASL A
        ASL A
        ASL A
        ASL A
        STA.B $5F
        LDA.B #$20
        STA.B $5E
        REP #$20
        RTS
        db $C2,$20,$20,$20,$C6,$A4,$04,$BF,$04,$E8,$7F,$9F,$00,$E8,$7F,$BF
        db $06,$E8,$7F,$9F,$02,$E8,$7F,$8A,$18,$69,$08,$00,$AA,$88,$D0,$E7
        db $60
; Reads $7F:E800+X, extracts tile type AND $001F, shifts left 5.
lookupMapTileType: ; $00C6A7
        REP #$20
        LDA.L $7FE800,X
        AND.W #$001F
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        STA.B $06
        SEP #$20
        LDA.L $7FE801,X
        AND.B #$1F
        CLC
        ADC.B $06
        STA.B $06
        LDA.L $7FE802,X
        AND.B #$1F
        ASL A
        ASL A
        CLC
        ADC.B $07
        STA.B $07
        REP #$20
        LDA.B $06
        RTS
; Call setupHdmaScroll, loop: call interpolateScrollValue 3x per entry, stride 8+6. Returns $096E.
processScrollEntries: ; $00C6D6
        REP #$20
        JSR.W setupHdmaScroll
        STZ.W $096E
CODE_80C6DE: ; $00C6DE
        JSR.W interpolateScrollValue
        INX
        JSR.W interpolateScrollValue
        INX
        JSR.W interpolateScrollValue
        TXA
        CLC
        ADC.W #$0006
        TAX
        DEC.B $04
        LDA.B $04
        BNE CODE_80C6DE
        LDA.W $096E
        RTS
; [Palette] Sets up CGRAM address for access. Entry: A=CGRAM address. Writes to $2121.
setupCGRAM: ; $00C6F9
        REP #$20
        LDY.B $02
CODE_80C6FD: ; $00C6FD
        PHY
        LDA.B $00
        JSR.W setupHdmaParams
        JSL.L waitForModeSync
        PLY
        INC.B $00
        DEY
        BNE CODE_80C6FD
        RTS
; Step $7F:E800,X toward $7F:E804,X by +/-1 per call. 8-bit comparison with INC/DEC.
interpolateScrollValue: ; $00C70E
        PHP
        SEP #$20
        LDA.L $7FE800,X
        CMP.L $7FE804,X
        BEQ CODE_80C728
        BCS CODE_80C720
        INC A
        BRA CODE_80C721
CODE_80C720: ; $00C720
        DEC A
CODE_80C721: ; $00C721
        STA.L $7FE800,X
        INC.W $096E
CODE_80C728: ; $00C728
        PLP
        RTS
        db $00,$00,$42,$08,$84,$10,$C6,$18,$08,$21,$4A,$29,$8C,$31,$CE,$39
        db $10,$42,$52,$4A,$94,$52,$D6,$5A,$18,$63,$5A,$6B,$9C,$73,$DE,$7B
        db $C2,$20,$A9,$00,$00,$85,$14,$A9,$2A,$C7,$85,$12,$A9,$82,$00,$85
        db $00,$A9,$01,$00,$85,$02,$A0,$05,$00,$5A,$22,$A7,$C5,$00,$E6,$00
        db $7A,$88,$D0,$F5,$22,$00,$C6,$00,$6B,$00,$00,$01,$00,$09,$17,$80
        db $08,$02,$19,$80,$00,$09,$19,$80,$01,$02,$1B,$80,$02,$09,$1B,$80
        db $03,$00,$00,$00,$02,$00,$00,$01,$02,$02,$19,$80,$04,$09,$19,$80
        db $05,$02,$1B,$80,$06,$09,$1B,$80,$07,$00,$00,$00,$01,$00,$00,$01
        db $01,$04,$16,$3E,$00,$11,$16,$3E,$00,$04,$18,$3E,$00,$11,$18,$3E
        db $00,$04,$1A,$3E,$00,$11,$1A,$3E,$00,$00,$00,$00,$02,$00,$00,$01
        db $02,$03,$18,$3E,$84,$11,$18,$3E,$88,$03,$1A,$3E,$90,$11,$1A,$3E
        db $A0,$00,$00,$00,$01,$00,$00,$01,$01,$06,$11,$80,$00,$00,$00,$00
        db $00,$06,$13,$80,$01,$00,$00,$00,$01,$00,$00,$00,$01,$00,$00,$00
        db $01,$02,$19,$80,$09,$09,$19,$80,$0A,$02,$1B,$80,$0B,$09,$1B,$80
        db $0C,$00,$00,$00,$01,$00,$00,$01,$01,$03,$18,$3E,$81,$11,$18,$3E
        db $88,$03,$1A,$3E,$82,$00,$00,$01,$00,$00,$00,$00,$01,$00,$00,$01
        db $00
; [Music] Sends command to SPC700. Entry: A=command, X=data1, Y=data2. Writes to $2140-$2143.
sendSPCCommand: ; $00C82B
        REP #$20
        LDY.W #$C7AB
        CMP.W #$0019
        BNE CODE_80C838
        LDY.W #$C773
CODE_80C838: ; $00C838
        CMP.W #$000F
        BNE CODE_80C847
        LDA.W #$0001
        JSL.L handleCutscene
        LDY.W #$C793
CODE_80C847: ; $00C847
        CMP.W #$0037
        BNE CODE_80C84F
        db $A0,$CB,$C7
CODE_80C84F: ; $00C84F
        CMP.W #$008E
        BNE CODE_80C857
        LDY.W #$C7E3
CODE_80C857: ; $00C857
        CMP.W #$0032
        BNE CODE_80C85F
        LDY.W #$C7FB
CODE_80C85F: ; $00C85F
        CMP.W #$00B6
        BNE CODE_80C867
        LDY.W #$C813
CODE_80C867: ; $00C867
        STY.W $096E
        RTL
        db $C2,$20,$9C,$10,$0A,$9C,$06,$0A,$9C,$1E,$0A,$A9,$02,$00,$8D,$FC
        db $09,$A5,$69,$4A,$4A,$4A,$18,$69,$1E,$00,$29,$1E,$00,$8D,$FE,$09
        db $A9,$1D,$00,$85,$28,$20,$33,$C2,$A7,$22,$29,$FF,$00,$E6,$22,$20
        db $56,$C1,$E8,$E8,$C6,$28,$D0,$F0,$A0,$10,$00,$5A,$E2,$20,$E6,$69
        db $E6,$57,$C2,$20,$A9,$05,$00,$22,$DD,$E3,$00,$7A,$88,$D0,$EC,$6B
; [OAM] Main sprite render pipeline. Calls: clearOamBuffer, clearOamExtTable, buildEntityOam, finalizeOam, setupLargeSprite.
renderSprites: ; $00C8BB
        REP #$20
        JSL.L processScrollDirtyWrapper
        JSR.W clearOamBuffer
        JSR.W clearOamExtTable
        JSR.W buildEntityOam
        JSR.W finalizeOam
        JSL.L setupLargeSprite
        RTL
; [OAM] Fills OAM buffer $0100 with $E0FF (offscreen Y). 32 entries, stride 4.
clearOamBuffer: ; $00C8D2
        LDA.W #$E0FF
        LDX.W #$0000
; [OAM] Fill loop: STA $0100,X / INX*4 / CPX $80 / BNE
clearOamBuffer_Loop: ; $00C8D8
        STA.W $0100,X
        INX
        INX
        INX
        INX
        CPX.W #$0080
        BNE clearOamBuffer_Loop
        RTS
; [OAM] Converts entity table at $1800 (stride $10, max $20) to OAM entries at $1A00. Handles position lerp, screen transform, tile/palette setup.
buildEntityOam: ; $00C8E5
        REP #$20
        LDA.B $80
        AND.W #$00FF
        CLC
        ADC.B $62
        STA.B $1E
        LDY.W #$0000
        LDX.W #$1800
        LDA.W #$0000
        STA.B $1C
        STA.B $0E
        LDA.W $0000,X
        STA.B $0A
        AND.W #$00FF
        BEQ oam_SkipEmpty
        STZ.B $06
        LDA.W $0008,X
        BPL oam_StoreTargetY
        AND.W #$7FFF
        STA.B $06
; [OAM] Store extracted target Y offset (bit15 cleared)
oam_StoreTargetY: ; $00C914
        LDA.B $0A
        AND.W #$0800
        BNE oam_BeginMove
        BRA oam_LoadTileData
; [OAM] Entity slot empty (type=0), skip to next
oam_SkipEmpty: ; $00C91D
        JMP.W $CDB4
; [OAM] Begin entity position lerp toward target X/Y
oam_BeginMove: ; $00C920
        PHY
        LDY.W #$0000
        LDA.W $0000,X
        AND.W #$0007
        STA.B $00
        BNE oam_CalcMoveSpeed
        LDA.B $72
        AND.W #$00FF
        CMP.W #$0004
        BNE oam_CalcMoveSpeed
        db $A5,$54,$29,$03,$00,$F0,$03,$7A,$80,$4C
; [OAM] Compute movement speed from entity type low 3 bits + 1
oam_CalcMoveSpeed: ; $00C942
        INC.B $00
        LDA.W $0002,X
        CMP.W $0006,X
        BEQ oam_CheckYMove
        BCS oam_MoveXNeg
        CLC
        ADC.B $00
        STA.W $0002,X
        LDY.W #$1600
        BRA oam_CheckYMove
; [OAM] Entity X > target X, subtract speed
oam_MoveXNeg: ; $00C959
        SEC
        SBC.B $00
        STA.W $0002,X
        LDY.W #$1400
; [OAM] Compare entity Y to target Y for movement
oam_CheckYMove: ; $00C962
        LDA.W $0004,X
        CMP.W $0008,X
        BEQ oam_CheckArrived
        BCS oam_MoveYNeg
        CLC
        ADC.B $00
        STA.W $0004,X
        LDY.W #$1000
        BRA oam_CheckArrived
; [OAM] Entity Y > target Y, subtract speed
oam_MoveYNeg: ; $00C977
        SEC
        SBC.B $00
        STA.W $0004,X
        LDY.W #$1200
; [OAM] Entity reached target — clear movement flags (bits 0x0807)
oam_CheckArrived: ; $00C980
        TYA
        BNE oam_MoveDone
        LDA.W #$0807
        TRB.B $0A
        LDA.B $0A
        STA.W $0000,X
; [OAM] Movement calculation complete, restore Y register
oam_MoveDone: ; $00C98D
        PLY
; [OAM] Load tile data ptr (entity+0A) and attributes (entity+0E) to DP
oam_LoadTileData: ; $00C98E
        LDA.W $000A,X
        STA.B $04
        LDA.W $000E,X
        STA.B $0C
        LDA.W $000C,X
        BNE oam_ReadAnimCmd
        JMP.W $CA2C
; [OAM] Read animation command byte from tile data stream
oam_ReadAnimCmd: ; $00C9A0
        STA.B $00
; [OAM] Animation command processing loop
oam_AnimCmdLoop: ; $00C9A2
        LDA.B ($00)
        AND.W #$00FF
        STA.B $02
        CMP.W #$0080
        BCC oam_CheckFlipX
        BNE oam_AnimCmd_NewPtr
        INC.B $00
        LDA.B ($00)
        BRA oam_ReadAnimCmd
; [OAM] Cmd $FF: replace tile data pointer from stream
oam_AnimCmd_NewPtr: ; $00C9B6
        CMP.W #$00FF
        BNE oam_AnimCmd_Cond
        INC.B $00
        LDA.B ($00)
        STA.W $000A,X
        INC.B $00
        INC.B $00
        BRA oam_AnimCmdLoop
; [OAM] Cmd $80+: conditional frame display based on $54 flags
oam_AnimCmd_Cond: ; $00C9C8
        AND.W #$007F
        AND.B $54
        BNE oam_AnimCmd_Reread
        INC.B $00
        BRA oam_AnimCmdLoop
; [OAM] Re-read command byte after conditional check
oam_AnimCmd_Reread: ; $00C9D3
        DEC.B $00
        LDA.B ($00)
        AND.W #$00FF
        STA.B $02
; [OAM] Bit6: toggle entity horizontal flip flag
oam_CheckFlipX: ; $00C9DC
        INC.B $00
        AND.W #$0040
        BEQ oam_CheckCountdown
        db $BD,$00,$00,$49,$00,$80,$9D,$00,$00
; [OAM] Bit5: decrement entity Y, increment attributes (animation timer)
oam_CheckCountdown: ; $00C9EC
        LDA.B $02
        AND.W #$0020
        BEQ oam_ApplyXOffset
        db $BD,$04,$00,$3A,$D0,$03,$9D,$00,$00,$9D,$04,$00,$BD,$0E,$00,$1A
        db $9D,$0E,$00
; [OAM] Apply tile X position offset to entity X coordinate
oam_ApplyXOffset: ; $00CA06
        LDA.B $02
        AND.W #$001F
        CMP.W #$0010
        BCC oam_XOffsetPositive
        db $29,$0F,$00,$3A,$49,$FF,$FF,$80,$07
; [OAM] Positive X offset path — sets bit $4000 in tile ptr
oam_XOffsetPositive: ; $00CA19
        PHA
        LDA.W #$4000
        TSB.B $04
        PLA
        CLC
        ADC.W $0002,X
        STA.W $0002,X
        LDA.B $00
        STA.W $000C,X
        LDA.B $0A
        AND.W #$0100
        BEQ oam_MultiTileSetup
        LDA.B $0A
        AND.W #$8000
        BEQ oam_JmpSingleTile
        LDA.B $54
        AND.W #$0010
        BEQ oam_JmpSingleTile
        LDA.B $04
        CLC
        ADC.W #$0002
        STA.B $04
; [OAM] Jump to single-tile OAM path at $CD20
oam_JmpSingleTile: ; $00CA49
        JMP.W $CD20
; [OAM] Begin 2x2 multi-tile sprite layout setup
oam_MultiTileSetup: ; $00CA4C
        LDA.B $0A
        AND.W #$C000
        BEQ oam_LoadTilePtr
        LDA.B $54
        AND.W #$0010
        BEQ oam_LoadTilePtr
        LDA.B $04
        CLC
        ADC.W #$00C0
        STA.B $04
; [OAM] Load tile data pointer for layout computation
oam_LoadTilePtr: ; $00CA62
        LDA.B $04
        AND.W #$4000
        BEQ oam_CalcScreenX
        JMP.W $CBC6
; [OAM] Convert entity X to screen-relative X (subtract camera $60)
oam_CalcScreenX: ; $00CA6C
        LDA.W $0002,X
        SEC
        SBC.B $60
        STA.B $02
        CMP.W #$FFF8
        BCS oam_LayoutWrapLeft
        CMP.W #$FFF0
        BCS oam_LayoutFarLeft
        CMP.W #$00E8
        BCS oam_LayoutNearRight
        JMP.W $CB0A
; [OAM] Tile layout: X in $E8-$F7 (near right edge)
oam_LayoutNearRight: ; $00CA86
        CMP.W #$00F8
        BCC oam_LayoutNormal
        CMP.W #$0100
        BCC oam_LayoutEdgeRight
        JMP.W $CDB4
; [OAM] Tile layout: X >= $FFF8 (wrapping from left side)
oam_LayoutWrapLeft: ; $00CA93
        STA.B $00
        LDA.B $04
        STA.B $40
        CLC
        ADC.W #$1002
        STA.B $42
        CLC
        ADC.W #$E002
        STA.B $46
        LDA.B $04
        CLC
        ADC.W #$E014
        STA.B $44
        JMP.W oam_CalcScreenY
; [OAM] Tile layout: X in $FFF0-$FFF7 (far left wrap)
oam_LayoutFarLeft: ; $00CAB0
        STA.B $00
        LDA.B $04
        CLC
        ADC.W #$1000
        STA.B $40
        CLC
        ADC.W #$0002
        STA.B $42
        CLC
        ADC.W #$E002
        STA.B $46
        LDA.B $04
        CLC
        ADC.W #$E014
        STA.B $44
        BRA oam_CalcScreenY
; [OAM] Tile layout: X in $F8-$FF (right edge)
oam_LayoutEdgeRight: ; $00CAD0
        STA.B $00
        LDA.B $04
        CLC
        ADC.W #$1000
        STA.B $40
        LDA.B $04
        CLC
        ADC.W #$0002
        STA.B $42
        CLC
        ADC.W #$E002
        STA.B $46
        CLC
        ADC.W #$1010
        STA.B $44
        BRA oam_CalcScreenY
; [OAM] Tile layout: X in normal visible range
oam_LayoutNormal: ; $00CAF0
        STA.B $00
        LDA.B $04
        STA.B $40
        CLC
        ADC.W #$0002
        STA.B $42
        CLC
        ADC.W #$E002
        STA.B $46
        CLC
        ADC.W #$1010
        STA.B $44
        BRA oam_CalcScreenY
        STA.B $00
        LDA.B $04
        STA.B $40
        CLC
        ADC.W #$0002
        STA.B $42
        CLC
        ADC.W #$E002
        STA.B $46
        CLC
        ADC.W #$0010
        STA.B $44
; [OAM] Convert entity Y to screen Y (subtract camera $1E). Check bounds.
oam_CalcScreenY: ; $00CB22
        LDA.W $0004,X
        SEC
        SBC.B $1E
        CMP.W #$00E6
        BCC oam_StoreScreenY
        JMP.W $CDB4
; [OAM] Store screen Y, add offsets, clamp to $01F4 max
oam_StoreScreenY: ; $00CB30
        STA.B $01
        CLC
        ADC.B $06
        CLC
        ADC.W #$0012
        ASL A
        CMP.W #$01F4
        BCC oam_ClampY
        db $A9,$F4,$01
; [OAM] Store clamped Y position to $1A
oam_ClampY: ; $00CB42
        STA.B $1A
        TYA
        LSR A
        STA.B $18
        LDA.B $0C
        AND.W #$000F
        BEQ oam_Palette2
        DEC A
        BEQ oam_Palette1
        LDA.B $44
        AND.W #$1000
        ORA.W #$8BEF
        STA.B $44
        BRA oam_Palette2
; [OAM] Palette option 1: OR $C9FF into tile attributes
oam_Palette1: ; $00CB5E
        LDA.B $44
        AND.W #$1000
        ORA.W #$C9FF
        STA.B $44
; [OAM] Palette option 2: check high nibble of entity attribs
oam_Palette2: ; $00CB68
        LDA.B $0D
        AND.W #$000F
        BEQ oam_WriteTilesNormal
        CLC
        ADC.W #$8981
        STA.B $48
        LDA.B $46
        AND.W #$1000
        ORA.B $48
        STA.B $46
; [OAM] Write 4 OAM tile entries to $1C00 buffer (normal orientation)
oam_WriteTilesNormal: ; $00CB7E
        LDA.B $00
        CLC
        ADC.W #$F800
        STA.W $1C04,Y
        CLC
        ADC.W #$F800
        STA.W $1C0C,Y
        SEP #$20
        CLC
        ADC.B #$08
        REP #$20
        STA.W $1C00,Y
        SEP #$20
        CLC
        ADC.B #$08
        REP #$20
        CLC
        ADC.W #$1000
        STA.W $1C08,Y
        LDA.B $40
        STA.W $1C02,Y
        LDA.B $42
        STA.W $1C06,Y
        LDA.B $44
        STA.W $1C0A,Y
        LDA.B $46
        STA.W $1C0E,Y
        TYA
        CLC
        ADC.W #$0010
        TAY
        LDA.W #$0400
        JMP.W $CD7B
        LDA.W $0002,X
        SEC
        SBC.B $60
        STA.B $02
        CMP.W #$FFF8
        BCS oam_LayoutWrapLeft_F
        CMP.W #$FFF0
        BCS oam_LayoutFarLeft_F
        CMP.W #$00E8
        BCS oam_LayoutNearRight_F
        JMP.W $CC66
; [OAM] Flipped tile layout: X in $E8-$F7
oam_LayoutNearRight_F: ; $00CBE0
        CMP.W #$00F8
        BCC oam_LayoutNormal_F
        CMP.W #$0100
        BCC oam_LayoutEdgeRight_F
        JMP.W $CDB4
; [OAM] Flipped tile layout: X >= $FFF8
oam_LayoutWrapLeft_F: ; $00CBED
        STA.B $00
        LDA.B $04
        CLC
        ADC.W #$1000
        STA.B $40
        LDA.B $04
        CLC
        ADC.W #$0002
        STA.B $42
        CLC
        ADC.W #$E002
        STA.B $46
        CLC
        ADC.W #$1010
        STA.B $44
        JMP.W oam_CalcScreenY_F
; [OAM] Flipped tile layout: X in $FFF0-$FFF7
oam_LayoutFarLeft_F: ; $00CC0E
        STA.B $00
        LDA.B $04
        CLC
        ADC.W #$1000
        STA.B $40
        CLC
        ADC.W #$0002
        STA.B $42
        CLC
        ADC.W #$D002
        STA.B $46
        LDA.B $04
        CLC
        ADC.W #$F014
        STA.B $44
        BRA oam_CalcScreenY_F
; [OAM] Flipped tile layout: X in $F8-$FF
oam_LayoutEdgeRight_F: ; $00CC2E
        STA.B $00
        LDA.B $04
        STA.B $40
        CLC
        ADC.W #$1002
        STA.B $42
        CLC
        ADC.W #$E002
        STA.B $46
        LDA.B $04
        CLC
        ADC.W #$E014
        STA.B $44
        BRA oam_CalcScreenY_F
; [OAM] Flipped tile layout: normal visible X range
oam_LayoutNormal_F: ; $00CC4A
        STA.B $00
        LDA.B $04
        STA.B $40
        CLC
        ADC.W #$0002
        STA.B $42
        CLC
        ADC.W #$F002
        STA.B $46
        LDA.B $04
        CLC
        ADC.W #$E014
        STA.B $44
        BRA oam_CalcScreenY_F
        STA.B $00
        LDA.B $04
        STA.B $40
        CLC
        ADC.W #$0002
        STA.B $42
        CLC
        ADC.W #$E002
        STA.B $46
        CLC
        ADC.W #$0010
        STA.B $44
; [OAM] Flipped: convert entity Y to screen Y, check bounds
oam_CalcScreenY_F: ; $00CC7E
        LDA.W $0004,X
        SEC
        SBC.B $1E
        CMP.W #$00E6
        BCC oam_StoreScreenY_F
        JMP.W $CDB4
; [OAM] Flipped: store screen Y with offsets and clamp
oam_StoreScreenY_F: ; $00CC8C
        STA.B $01
        CLC
        ADC.B $06
        CLC
        ADC.W #$0012
        ASL A
        CMP.W #$01F4
        BCC oam_ClampY_F
        LDA.W #$01F4
; [OAM] Flipped: clamp Y to $1A
oam_ClampY_F: ; $00CC9E
        STA.B $1A
        TYA
        LSR A
        STA.B $18
        LDA.B $0C
        AND.W #$000F
        BEQ oam_Palette2_F
        DEC A
        BEQ oam_Palette1_F
        LDA.B $44
        AND.W #$1000
        ORA.W #$8BEF
        STA.B $44
        BRA oam_Palette2_F
; [OAM] Flipped palette 1: OR $C9FF
oam_Palette1_F: ; $00CCBA
        LDA.B $44
        AND.W #$1000
        ORA.W #$C9FF
        STA.B $44
; [OAM] Flipped palette 2: high nibble check
oam_Palette2_F: ; $00CCC4
        LDA.B $0D
        AND.W #$000F
        BEQ oam_WriteTilesFlipped
        db $18,$69,$81,$89,$85,$48,$A5,$46,$29,$00,$10,$05,$48,$85,$46
; [OAM] Write 4 OAM tile entries to $1C00 buffer (flipped orientation)
oam_WriteTilesFlipped: ; $00CCDA
        LDA.B $00
        STA.W $1C08,Y
        CLC
        ADC.W #$F000
        STA.W $1C00,Y
        SEP #$20
        CLC
        ADC.B #$10
        REP #$20
        STA.W $1C0C,Y
        LDA.B $00
        SEP #$20
        CLC
        ADC.B #$08
        REP #$20
        CLC
        ADC.W #$F800
        STA.W $1C04,Y
        LDA.B $40
        STA.W $1C02,Y
        LDA.B $42
        STA.W $1C06,Y
        LDA.B $44
        STA.W $1C0A,Y
        LDA.B $46
        STA.W $1C0E,Y
        TYA
        CLC
        ADC.W #$0010
        TAY
        LDA.W #$0400
        JMP.W $CD7B
        LDA.W $0002,X
        SEC
        SBC.B $60
        CMP.W #$FFF0
        BCS CODE_80CD33
        CMP.W #$0100
        BCC oam_SingleTileVisible
        db $4C,$A2,$CD
CODE_80CD33: ; $00CD33
        db $85,$00,$A9,$00,$10,$04,$04,$80,$02
; [OAM] Single-tile OAM: X in visible range, compute position
oam_SingleTileVisible: ; $00CD3C
        STA.B $00
        LDA.W $0004,X
        SEC
        SBC.B $1E
        DEC A
        CMP.W #$00E6
        BCC oam_SingleTileCalcY
        db $4C,$A2,$CD
; [OAM] Single-tile: compute screen Y from entity Y
oam_SingleTileCalcY: ; $00CD4D
        STA.B $01
        CLC
        ADC.B $0C
        CLC
        ADC.W #$0010
        ASL A
        CMP.W #$01F4
        BCC oam_SingleTileClampY
        db $A9,$F4,$01
; [OAM] Single-tile: clamp Y, write OAM entry
oam_SingleTileClampY: ; $00CD5F
        STA.B $1A
        TYA
        LSR A
        STA.B $18
        LDA.B $00
        STA.W $1C00,Y
        LDA.B $04
        STA.W $1C02,Y
        TYA
        CLC
        ADC.W #$0004
        TAY
        LDA.W #$0100
        JMP.W $CD84
        STA.B $16
        REP #$20
        PHX
        LDX.B $1A
        BRA oam_FindFreeSlot
        STA.B $16
        PHX
        LDX.B $1A
; [OAM] Search $1A00 buffer for empty OAM slot (byte=0)
oam_FindFreeSlot: ; $00CD89
        LDA.W $1A00,X
        AND.W #$00FF
        BEQ oam_WriteSlot
        INX
        INX
        CPX.W #$0200
        BNE oam_FindFreeSlot
        db $FA,$4C,$A2,$CD
; [OAM] Write tile+attrib data to found OAM slot
oam_WriteSlot: ; $00CD9C
        LDA.B $17
        STA.W $1A00,X
        PLX
; [OAM] Advance X by $10 to next entity slot, loop or exit
oam_NextEntity: ; $00CDA2
        TXA
        CLC
        ADC.W #$0010
        TAX
        LDA.B $0E
        INC A
        CMP.W #$0020
        BEQ oam_AllDone
        JMP.W $C8FC
; [OAM] All 32 entities processed, RTS
oam_AllDone: ; $00CDB3
        RTS
        BRA oam_NextEntity
; [OAM] Zeros OAM extended attribute table $1A00-$1C00. Called before buildEntityOam.
clearOamExtTable: ; $00CDB6
        PHP
        SEP #$20
        LDY.W #$0200
        LDA.B #$00
; [OAM] Zero loop: STA $19FE,Y / DEY / BNE
clearOamExtTable_Loop: ; $00CDBE
        STA.W $19FE,Y
        DEY
        DEY
        BNE clearOamExtTable_Loop
        STA.W $1A00
        PLP
        RTS
; [OAM] Post-OAM processing after entity sprites are built.
finalizeOam: ; $00CDCA
        PHP
        REP #$20
        LDA.W #$0308
        STA.B $16
        STZ.B $06
        STZ.B $08
        STZ.B $0A
        SEP #$20
        LDA.B #$01
        STA.B $00
        LDA.B #$AA
        STA.B $02
        LDY.W #$0200
        LDX.W #$0080
; [OAM] Main processing loop for OAM finalization
finalizeOam_Loop: ; $00CDE8
        LDA.W $19FE,Y
        BNE finalizeOam_Entry
        STZ.B $06
        DEY
        DEY
        BNE finalizeOam_Loop
        JMP.W CODE_80CE81
; [OAM] Process non-zero OAM entry
finalizeOam_Entry: ; $00CDF6
        PHY
        PHA
        STZ.B $13
        LDA.W $19FF,Y
        ASL A
        STA.B $12
        ROL.B $13
        LDY.B $12
        INC.B $06
        LDA.B $06
        CMP.B #$09
        BCC CODE_80CE1B
        db $A5,$08,$D0,$0B,$A5,$0A,$CD,$50,$0A,$90,$04,$F0,$02,$85,$08
CODE_80CE1B: ; $00CE1B
        PLA
CODE_80CE1C: ; $00CE1C
        PHA
        LDA.W $1C00,Y
        STA.W $0100,X
        LDA.W $1C01,Y
        STA.W $0101,X
        LDA.W $1C02,Y
        STA.W $0102,X
        LDA.W $1C03,Y
        STA.B $04
        LDA.B #$10
        TRB.B $04
        BEQ CODE_80CE3E
        LDA.B $00
        TSB.B $02
CODE_80CE3E: ; $00CE3E
        ROL.B $00
        LDA.B #$80
        TRB.B $04
        BNE CODE_80CE4A
        LDA.B #$10
        TSB.B $04
CODE_80CE4A: ; $00CE4A
        LDA.B #$20
        TSB.B $04
        BNE CODE_80CE54
        LDA.B $00
        TRB.B $02
CODE_80CE54: ; $00CE54
        ROL.B $00
        BCC CODE_80CE64
        ROL.B $00
        LDA.B $02
        STA.B ($16)
        INC.B $16
        LDA.B #$AA
        STA.B $02
CODE_80CE64: ; $00CE64
        LDA.B $04
        STA.W $0103,X
        INX
        INX
        INX
        INX
        INY
        INY
        INY
        INY
        INC.B $0A
        INC.B $0A
        PLA
        DEC A
        BNE CODE_80CE1C
        PLY
        DEY
        DEY
        BEQ CODE_80CE81
        JMP.W finalizeOam_Loop
CODE_80CE81: ; $00CE81
        LDA.B $02
        STA.B ($16)
        LDA.B $08
        BEQ CODE_80CE8C
        db $18,$69,$40
CODE_80CE8C: ; $00CE8C
        STA.W $0A50
        REP #$20
        LDA.W #$E0FF
CODE_80CE94: ; $00CE94
        STA.W $0100,X
        INX
        INX
        INX
        INX
        CPX.W #$0200
        BNE CODE_80CE94
        PLP
        RTS
        db $B8,$CE,$C8,$CE,$D0,$CE,$DE,$CE,$E8,$CE,$FC,$CE,$0E,$CF,$22,$CF
        db $2B,$CF,$42,$CF,$54,$CF,$01,$00,$87,$01,$00,$87,$40,$00,$9F,$00
        db $9F,$00,$9F,$00,$9F,$40,$00,$9F,$00,$9F,$11,$11,$11,$11,$10,$9F
        db $10,$9F,$50,$10,$9F,$10,$9F,$50,$10,$9F,$10,$9F,$01,$00,$87,$01
        db $00,$87,$80,$B8,$CE,$00,$21,$8F,$21,$8F,$21,$8F,$21,$20,$21,$20
        db $21,$20,$21,$00,$00,$21,$00,$00,$00,$87,$31,$10,$10,$31,$10,$10
        db $31,$30,$31,$30,$31,$30,$31,$8F,$31,$8F,$31,$8F,$31,$30,$31,$30
        db $31,$30,$31,$10,$10,$31,$10,$10,$10,$87,$21,$00,$00,$21,$00,$00
        db $21,$20,$21,$20,$21,$20,$80,$E8,$CE,$FF,$20,$A8,$00,$83,$FF,$25
        db $A8,$00,$83,$FF,$E0,$A8,$00,$83,$FF,$E5,$A8,$00,$83,$80,$2B,$CF
        db $FF,$0A,$AA,$00,$87,$FF,$CA,$AA,$00,$87,$FF,$20,$AA,$00,$87,$80
        db $42,$CF,$FF,$80,$A3,$00,$87,$FF,$85,$A3,$00,$87,$FF,$8A,$A3,$00
        db $87,$FF,$E0,$A3,$00,$87,$80,$54,$CF
; [AI] Updates AI for all entities. Entry: calls entity-specific AI routines based on type.
updateEntityAI: ; $00CF6B
        REP #$20
        CMP.W #$0000
        BNE CODE_80CF75
        JMP.W $D0E8
CODE_80CF75: ; $00CF75
        CMP.W #$0001
        BNE CODE_80CF7D
        JMP.W $D0D4
CODE_80CF7D: ; $00CF7D
        CMP.W #$0002
        BNE CODE_80CF85
        JMP.W $D1A6
CODE_80CF85: ; $00CF85
        CMP.W #$0003
        BNE CODE_80CF8D
        JMP.W $D20D
CODE_80CF8D: ; $00CF8D
        CMP.W #$0004
        BNE CODE_80CF95
        db $4C,$26,$D2
CODE_80CF95: ; $00CF95
        CMP.W #$0005
        BNE CODE_80CF9D
        db $4C,$2E,$D3
CODE_80CF9D: ; $00CF9D
        CMP.W #$0006
        BNE CODE_80CFA5
        db $4C,$DD,$D2
CODE_80CFA5: ; $00CFA5
        CMP.W #$0007
        BNE CODE_80CFAD
        JMP.W $D3C5
CODE_80CFAD: ; $00CFAD
        CMP.W #$0008
        BNE CODE_80CFB5
        db $4C,$F8,$D2
CODE_80CFB5: ; $00CFB5
        CMP.W #$0009
        BNE CODE_80CFBD
        db $4C,$D8,$D3
CODE_80CFBD: ; $00CFBD
        CMP.W #$000A
        BNE CODE_80CFC5
        JMP.W $D425
CODE_80CFC5: ; $00CFC5
        STZ.W $0A7B
        RTL
; [Collision] Checks collisions between entities. Entry: scans entity list, tests bounding boxes.
checkEntityCollision: ; $00CFC9
        PHP
        SEP #$20
        LDA.W $0A5D
        STA.B $02
        LDA.W $0A5B
        STA.B $03
        LDY.B $02
        LDA.W $F4CB,Y
        STA.B $00
        LDA.W $0A66
        BEQ CODE_80D00A
        LDA.W $0A65
        DEC A
        EOR.B #$FF
        STA.W $4202
        LDA.B $00
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDA.W $4217
        REP #$20
        AND.W #$00FF
        STA.B $04
        LDA.W $0A61
        SEC
        SBC.B $04
        STA.B $22
        BRA CODE_80D027
        db $E2,$20
CODE_80D00A: ; $00D00A
        LDA.W $0A65
        STA.W $4202
        LDA.B $00
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDA.W $4217
        REP #$20
        AND.W #$00FF
        CLC
        ADC.W $0A61
        STA.B $22
CODE_80D027: ; $00D027
        SEP #$20
        LDA.W $0A68
        BEQ CODE_80D056
        LDA.W $0A67
        DEC A
        EOR.B #$FF
        STA.W $4202
        LDA.B $00
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDA.W $4217
        REP #$20
        AND.W #$00FF
        STA.B $04
        LDA.W $0A63
        SEC
        SBC.B $04
        STA.B $24
        BRA CODE_80D073
        db $E2,$20
CODE_80D056: ; $00D056
        LDA.W $0A67
        STA.W $4202
        LDA.B $00
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDA.W $4217
        REP #$20
        AND.W #$00FF
        CLC
        ADC.W $0A63
        STA.B $24
CODE_80D073: ; $00D073
        REP #$20
        LDA.W $0A5D
        CLC
        ADC.W $0A5F
        STA.W $0A5D
        CMP.W #$0100
        BCC CODE_80D099
        LDA.W $0A61
        CLC
        ADC.W $0A65
        STA.B $22
        LDA.W $0A63
        CLC
        ADC.W $0A67
        STA.B $24
        STZ.W $0A57
CODE_80D099: ; $00D099
        LDA.W $0A69
        BEQ CODE_80D0D2
        DEC.W $0A6D
        LDA.W $0A6B
        CLC
        ADC.W $0A6D
        STA.W $0A6B
        CMP.W #$8000
        BCC CODE_80D0C3
        LDA.W $0A6D
        DEC A
        EOR.W #$FFFF
        LSR A
        STA.W $0A6D
        BNE CODE_80D0C0
        STZ.W $0A69
CODE_80D0C0: ; $00D0C0
        STZ.W $0A6B
CODE_80D0C3: ; $00D0C3
        LDA.W $0A6B
        LSR A
        LSR A
        LSR A
        STA.B $00
        LDA.B $24
        SEC
        SBC.B $00
        STA.B $24
CODE_80D0D2: ; $00D0D2
        PLP
        RTL
        REP #$20
        LDX.W #$0000
CODE_80D0D9: ; $00D0D9
        LDA.L $7EE600,X
        STA.W $1400,X
        INX
        INX
        CPX.W #$0400
        BNE CODE_80D0D9
        RTL
        REP #$20
        LDX.W #$0000
CODE_80D0ED: ; $00D0ED
        LDA.W $1400,X
        STA.L $7EE600,X
        INX
        INX
        CPX.W #$0400
        BNE CODE_80D0ED
        RTL
; [OAM] Builds OAM attribute words from tile descriptor in $02; palette from $D138,X table
buildEntitySpriteAttribs: ; $00D0FC
        PHX
        STA.B $06
        LDA.B $02
        AND.W #$0400
        BEQ CODE_80D10B
        LDA.W #$4000
        TSB.B $06
CODE_80D10B: ; $00D10B
        LDA.B $02
        AND.W #$FB00
        EOR.W #$80F0
        STA.B $04
        LDA.B $02
        AND.W #$007F
        TAX
        SEP #$20
        LDA.W $D138,X
        AND.B #$03
        ASL A
        ORA.B $07
        STA.B $07
        REP #$20
        PLX
        LDA.B $06
        ORA.W #$A800
        STA.W $000A,X
        LDA.B $04
        STA.W $0000,X
        RTL
        db $00,$00,$01,$00,$01,$00,$00,$01,$00,$00,$00,$00,$01,$00,$02,$00
        db $00,$00,$00,$00,$00,$00,$01,$00,$01,$00,$02,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00,$01,$02,$01,$00
        db $02,$00,$00,$00,$01,$00,$01,$02,$00,$00,$00,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$01,$01,$00,$00,$00,$01,$01,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        LDX.W #$0000
CODE_80D1A9: ; $00D1A9
        STZ.W $1400,X
        INX
        INX
        CPX.W #$0200
        BCC CODE_80D1A9
        LDX.W #$0000
        LDY.W #$0008
CODE_80D1B9: ; $00D1B9
        SEP #$20
        LDA.B [$85]
        STA.W $1403,X
        REP #$20
        LDA.W #$EE00
        STA.W $1400,X
        INC.B $85
        TXA
        CLC
        ADC.W #$0020
        TAX
        DEY
        BNE CODE_80D1B9
        LDX.W #$0000
        LDY.W #$0008
CODE_80D1D9: ; $00D1D9
        SEP #$20
        LDA.B [$85]
        STA.L $7FC028,X
        REP #$20
        LDA.W #$0000
        STA.L $7FC029,X
        INC.B $85
        TXA
        CLC
        ADC.W #$0008
        TAX
        DEY
        BNE CODE_80D1D9
        LDY.W #$000C
CODE_80D1F8: ; $00D1F8
        LDA.W #$0000
        STA.L $7FC028,X
        STA.L $7FC029,X
        TXA
        CLC
        ADC.W #$0008
        TAX
        DEY
        BNE CODE_80D1F8
        RTL
        LDA.B [$85]
        INC.B $85
        INC.B $85
        STA.W $0A7F
        LDA.B [$85]
        INC.B $85
        AND.W #$00FF
        STA.W $0A81
        LDA.W #$0001
        STA.B $82
        RTL
        db $AF,$98,$EA,$7E,$29,$07,$00,$0A,$0A,$0A,$AA,$A0,$00,$00,$BD,$9D
        db $D2,$29,$FF,$00,$99,$00,$10,$E8,$C8,$C8,$C0,$0E,$00,$D0,$EF,$A0
        db $00,$00,$B9,$8F,$D2,$AA,$BF,$00,$90,$7F,$29,$FF,$01,$85,$00,$B9
        db $00,$10,$C5,$00,$F0,$2B,$A9,$00,$00,$99,$00,$10,$A9,$80,$00,$85
        db $24,$A5,$00,$38,$E9,$0A,$00,$F0,$05,$46,$24,$3A,$D0,$FB,$AF,$96
        db $EA,$7E,$45,$24,$8F,$96,$EA,$7E,$AF,$97,$EA,$7E,$3A,$8F,$97,$EA
        db $7E,$C8,$C8,$C0,$0E,$00,$D0,$BA,$6B,$84,$07,$8C,$06,$94,$07,$94
        db $09,$8C,$0A,$84,$09,$8C,$08,$0A,$0B,$0C,$0D,$0E,$0F,$10,$00,$10
        db $0F,$0E,$0D,$0C,$0B,$0A,$00,$0D,$0E,$0F,$10,$0A,$0B,$0C,$00,$0C
        db $0B,$0A,$10,$0F,$0E,$0D,$00,$0B,$0C,$0D,$0E,$0F,$10,$0A,$00,$0F
        db $0E,$0D,$0C,$0B,$0A,$10,$00,$0E,$0F,$10,$0A,$0B,$0C,$0D,$00,$0E
        db $0D,$0C,$0B,$0A,$10,$0F,$00,$A2,$00,$14,$A0,$08,$00,$BD,$00,$00
        db $29,$FF,$00,$D0,$03,$9D,$00,$02,$8A,$18,$69,$20,$00,$AA,$88,$D0
        db $EC,$6B,$AD,$03,$16,$29,$FF,$00,$C9,$2E,$00,$F0,$2A,$A9,$7F,$00
        db $85,$14,$A9,$28,$C0,$85,$12,$A2,$00,$14,$A0,$08,$00,$E2,$20,$BD
        db $03,$00,$87,$12,$C2,$20,$A5,$12,$18,$69,$08,$00,$85,$12,$8A,$18
        db $69,$20,$00,$AA,$88,$D0,$E6,$6B,$A2,$00,$00,$DA,$8A,$4A,$C9,$60
        db $00,$90,$03,$A9,$60,$00,$8D,$85,$0A,$A9,$00,$00,$38,$ED,$85,$0A
        db $20,$9D,$D3,$AD,$85,$0A,$20,$9D,$D3,$FA,$E8,$E0,$20,$01,$D0,$DB
        db $A2,$00,$14,$A0,$08,$00,$E2,$20,$BD,$00,$00,$9D,$00,$02,$F0,$2B
        db $BD,$03,$00,$85,$02,$BD,$06,$00,$85,$00,$A5,$02,$C9,$20,$D0,$06
        db $A9,$61,$85,$02,$80,$0B,$BD,$01,$00,$C9,$03,$D0,$04,$A9,$01,$85
        db $00,$A5,$02,$9D,$03,$02,$A5,$00,$9D,$06,$02,$C2,$20,$8A,$18,$69
        db $20,$00,$AA,$88,$D0,$C0,$6B,$85,$22,$A2,$00,$00,$A0,$08,$00,$BD
        db $00,$18,$F0,$09,$BD,$04,$18,$18,$65,$22,$9D,$04,$18,$8A,$18,$69
        db $10,$00,$AA,$88,$D0,$E9,$22,$BB,$C8,$00,$22,$BE,$E3,$00,$60
        LDA.B [$85]
        INC.B $85
        AND.W #$00FF
        JSL.L dispatchGameMode
        JSL.L updateMinimap
        STZ.W $0A87
        RTL
        db $A9,$00,$F0,$8D,$71,$0A,$A9,$36,$00,$8D,$73,$0A,$AD,$71,$0A,$85
        db $22,$AD,$73,$0A,$85,$24,$A9,$01,$00,$85,$26,$A7,$22,$29,$FF,$00
        db $F0,$2A,$C9,$20,$00,$F0,$06,$38,$E9,$30,$00,$85,$26,$AD,$71,$0A
        db $1A,$85,$22,$AD,$73,$0A,$85,$24,$22,$6B,$C8,$00,$C6,$26,$D0,$ED
        db $AD,$71,$0A,$18,$69,$20,$00,$8D,$71,$0A,$80,$C0,$6B
        LDA.W #$0037
        STA.B $14
        LDA.W #$F000
        STA.B $12
        LDX.W #$1800
        LDY.W #$1000
        JSL.L dmaToVRAMGeneric
        LDA.W #$0003
        STA.B $14
        LDA.W #$A4F2
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L uploadPaletteWrapper
        RTL
        CLC
        XCE
        SEP #$20
        REP #$10
        LDX.W #$0FF0
        TXS
        LDA.B #$00
        PHA
        PLB
        REP #$30
        JSL.L systemInit
        db $4C,$62,$D4
; NMI body: read $4210, dispatch by $10 mode. Mode 0: OAM DMA $0100->$2102, screen brightness $58->$2100.
vblankProcess: ; $00D469
        PHP
        REP #$30
        PHA
        PHX
        PHY
        SEP #$20
        LDA.W $4210
        LDA.B $10
        BEQ CODE_80D482
        CMP.B #$02
        BCS CODE_80D47F
        JMP.W CODE_80D534
CODE_80D47F: ; $00D47F
        JMP.W CODE_80D77A
CODE_80D482: ; $00D482
        INC.B $4A
        LDA.B $58
        STA.W $2100
        LDX.W #$0100
        STX.W $4302
        LDX.W #$0220
        STX.W $4305
        STZ.W $2102
        LDA.B #$01
        STA.W $420B
        LDA.B #$80
        STA.W $2103
        LDA.W $0A50
        STA.W $2102
        LDA.W $05F5
        BEQ CODE_80D4F9
        CLC
        ADC.B #$7F
        STA.W $2115
        LDA.B #$01
        STA.W $4310
        STA.W $4320
        STZ.W $4314
        STZ.W $4324
        REP #$20
        LDX.W #$05F6
        LDA.W $0000,X
        STA.W $4315
        STA.W $4325
        LDA.W $0002,X
        PHA
        CLC
        ADC.W #$E400
        STA.W $2116
        LDA.W #$0680
        STA.W $4312
        LDA.W #$0600
        STA.W $4322
        SEP #$20
        LDA.B #$02
        STA.W $420B
        PLY
        STY.W $2116
        LDA.B #$04
        STA.W $420B
        STZ.W $05F5
CODE_80D4F9: ; $00D4F9
        LDA.B $5E
        BEQ CODE_80D51D
        INC A
        BNE CODE_80D509
        LDA.B $5F
        STA.W $2131
        STZ.B $5E
        BRA CODE_80D51D
CODE_80D509: ; $00D509
        STA.W $4355
        LDA.B $5F
        STA.W $2121
        LDA.B #$C0
        STA.W $4352
        LDA.B #$20
        STA.W $420B
        STZ.B $5E
CODE_80D51D: ; $00D51D
        LDA.B $57
        BEQ CODE_80D534
        INC A
        BEQ CODE_80D52C
        INC A
        BEQ CODE_80D531
        JSR.W dmaTextTileToVRAM
        BRA CODE_80D534
CODE_80D52C: ; $00D52C
        JSR.W dmaOverlayToVRAM
        BRA CODE_80D534
CODE_80D531: ; $00D531
        JSR.W dmaTilemapToVRAM
CODE_80D534: ; $00D534
        LDA.B $6B
        STA.W $210F
        LDA.B $6C
        STA.W $210F
        LDA.B $6D
        STA.W $2110
        LDA.B $6E
        STA.W $2110
        LDA.B $6A
        BEQ CODE_80D589
        LDA.B $60
        STA.W $210D
        STZ.W $210D
        STA.W $2111
        STZ.W $2111
        LDA.B $62
        CLC
        ADC.B $80
        STA.W $210E
        STZ.W $210E
        STA.W $2112
        STZ.W $2112
        LDA.B #$78
        STA.W $2107
        LDA.B #$5C
        STA.W $2109
        LDA.B $74
        STA.W $212C
        LDA.B $75
        STA.W $212D
        LDA.B $71
        CLC
        ADC.B $73
        STA.W $210B
        BRA CODE_80D5B3
CODE_80D589: ; $00D589
        LDA.B $60
        STA.W $210D
        STZ.W $210D
        LDA.B $62
        STA.W $210E
        STZ.W $210E
        LDA.B $68
        STA.W $2111
        STZ.W $2111
        LDA.B $69
        STA.W $2112
        STZ.W $2112
        LDA.B $74
        STA.W $212C
        LDA.B $75
        STA.W $212D
CODE_80D5B3: ; $00D5B3
        LDA.B $58
        CMP.B #$20
        BCC CODE_80D5DB
        AND.B #$10
        BEQ CODE_80D5C3
        LDA.B $54
        AND.B $59
        BNE CODE_80D5DB
CODE_80D5C3: ; $00D5C3
        LDA.B $58
        CMP.B #$40
        BCC CODE_80D5CC
        INC A
        BRA CODE_80D5CD
CODE_80D5CC: ; $00D5CC
        DEC A
CODE_80D5CD: ; $00D5CD
        STA.B $58
        AND.B #$0F
        BEQ CODE_80D5D9
        CMP.B #$0F
        BEQ CODE_80D5D9
        BRA CODE_80D5DB
CODE_80D5D9: ; $00D5D9
        STA.B $58
CODE_80D5DB: ; $00D5DB
        LDA.B $84
        STA.W $420C
        LDA.B $72
        BEQ CODE_80D619
        CMP.B #$04
        BEQ CODE_80D601
        CMP.B #$02
        BNE CODE_80D607
        db $A5,$54,$29,$0F,$D0,$27,$A5,$71,$1A,$29,$0F,$C9,$03,$90,$02,$A9
        db $00,$85,$71,$80,$18
CODE_80D601: ; $00D601
        db $A5,$54,$29,$03,$80,$E9
CODE_80D607: ; $00D607
        REP #$20
        LDA.B $54
        LSR A
        LSR A
        LSR A
        AND.W #$000F
        TAX
        SEP #$20
        LDA.W $E0B7,X
        STA.B $71
CODE_80D619: ; $00D619
        LDA.B $76
        BEQ CODE_80D663
        CMP.B #$01
        BNE CODE_80D626
        db $20,$83,$D7,$80,$3D
CODE_80D626: ; $00D626
        CMP.B #$02
        BNE CODE_80D62F
        JSR.W buildHdmaScrollTable
        BRA CODE_80D663
CODE_80D62F: ; $00D62F
        CMP.B #$03
        BNE CODE_80D638
        db $20,$4E,$D8,$80,$2B
CODE_80D638: ; $00D638
        CMP.B #$0E
        BNE CODE_80D641
        db $20,$CA,$D8,$80,$22
CODE_80D641: ; $00D641
        CMP.B #$0F
        BNE CODE_80D64A
        db $20,$83,$D8,$80,$19
CODE_80D64A: ; $00D64A
        JSR.W initHdmaFromParam
        BRA CODE_80D663
        db $C2,$20,$A5,$62,$C9,$F8,$00,$B0,$06,$38,$E9,$60,$00,$85,$6D,$E2
        db $20,$4C,$DB,$D6
CODE_80D663: ; $00D663
        LDA.B $77
        BEQ CODE_80D6DB
        DEC A
        BEQ CODE_80D678
        DEC A
        BEQ CODE_80D68F
        DEC A
        BEQ CODE_80D6A1
        DEC A
        BEQ CODE_80D6B1
        DEC A
        BEQ CODE_80D6CA
        db $80,$D7
CODE_80D678: ; $00D678
        db $C2,$20,$A5,$54,$4A,$85,$40,$18,$65,$60,$85,$6B,$E2,$20,$A5,$62
        db $38,$E5,$40,$85,$6D,$80,$4C
CODE_80D68F: ; $00D68F
        REP #$20
        LDA.B $60
        STA.B $6B
        LDA.B $62
        SEC
        SBC.W #$0110
        STA.B $6D
        SEP #$20
        BRA CODE_80D6DB
CODE_80D6A1: ; $00D6A1
        db $C2,$20,$A5,$60,$4A,$85,$6B,$A5,$62,$4A,$85,$6D,$E2,$20,$80,$2A
CODE_80D6B1: ; $00D6B1
        REP #$20
        LDA.B $54
        CLC
        ADC.B $60
        STA.B $6B
        LDA.B $54
        LSR A
        STA.B $40
        SEP #$20
        LDA.B $62
        SEC
        SBC.B $40
        STA.B $6D
        BRA CODE_80D6DB
CODE_80D6CA: ; $00D6CA
        INC.B $6B
        LDA.B $54
        ASL A
        ASL A
        STA.B $40
        LDA.B $62
        SEC
        SBC.B $40
        STA.B $6D
        BRA CODE_80D6DB
CODE_80D6DB: ; $00D6DB
        LDA.B $7A
        AND.B #$80
        BEQ CODE_80D72E
        LDA.B $54
        AND.B #$01
        BNE CODE_80D72E
        REP #$20
        LDA.B $7B
        TAY
        INC A
        INC A
        STA.B $7B
        LDA.W $0000,Y
        CMP.W #$FFFF
        BEQ CODE_80D71D
        AND.W #$007F
        ASL A
        TAX
        LDA.W $DAA9,X
        STA.W $0DC2
        LDA.W $0001,Y
        AND.W #$007F
        ASL A
        TAX
        LDA.W $DAA9,X
        STA.W $0DC0
        SEP #$20
        LDA.B #$71
        STA.B $5F
        LDA.B #$04
        STA.B $5E
        BRA CODE_80D72E
CODE_80D71D: ; $00D71D
        db $E2,$20,$A5,$7A,$29,$0F,$F0,$07,$20,$96,$D9,$E2,$20,$80,$02,$64
        db $7A
CODE_80D72E: ; $00D72E
        LDA.B $7F
        BEQ CODE_80D754
        REP #$20
        AND.W #$00FF
        TAY
        LDA.W $E0D7,Y
        SEP #$20
        INC.B $7F
        CMP.B #$FE
        BNE CODE_80D74A
        LDA.B #$01
        STA.B $7F
        DEC A
        BRA CODE_80D752
CODE_80D74A: ; $00D74A
        CMP.B #$FF
        BNE CODE_80D752
        LDA.B #$00
        STA.B $7F
CODE_80D752: ; $00D752
        STA.B $80
CODE_80D754: ; $00D754
        LDA.B $81
        BEQ CODE_80D762
        STZ.B $81
        LDY.W #$0002
        DEC A
        JSL.L spcWritePort2
CODE_80D762: ; $00D762
        LDA.B $4C
        BEQ CODE_80D77A
        LDA.B $10
        PHA
        LDA.B #$02
        STA.B $10
        JSR.W updateAndRenderEntities
        LDA.B $AA
        BEQ CODE_80D777
        db $20,$88,$E6
CODE_80D777: ; $00D777
        PLA
        STA.B $10
CODE_80D77A: ; $00D77A
        REP #$30
        INC.B $54
        PLY
        PLX
        PLA
        PLP
        RTI
        db $E2,$20,$A5,$6D,$18,$65,$54,$0A,$0A,$0A,$85,$3A,$A9,$03,$85,$3C
        db $A9,$80,$85,$3B,$A2,$03,$00,$A0,$54,$00,$C2,$20,$A7,$3A,$18,$65
        db $6B,$9F,$01,$A0,$7E,$E2,$20,$A5,$3A,$18,$69,$10,$85,$3A,$E8,$E8
        db $E8,$88,$D0,$E6,$A9,$00,$9F,$00,$A0,$7E,$60
; [Scrolling] Builds 84-entry HDMA BG scroll table in $7EA000 from base step table at $D83D
buildHdmaScrollTable: ; $00D7BE
        SEP #$20
        LDA.B $54
        CLC
        ADC.B $6D
        CLC
        ADC.B $6D
        AND.B #$FE
        STA.B $3A
        LDA.B #$03
        STA.B $3C
        LDA.B #$81
        STA.B $3B
        LDX.W #$0003
        LDY.W #$0054
CODE_80D7DA: ; $00D7DA
        REP #$20
        LDA.B [$3A]
        CLC
        ADC.B $6B
        STA.L $7EA001,X
        SEP #$20
        LDA.B $3A
        CLC
        ADC.B #$04
        STA.B $3A
        INX
        INX
        INX
        DEY
        BNE CODE_80D7DA
        LDA.B #$00
        STA.L $7EA000,X
        RTS
; AND $00FF, falls into buildHdmaScrollTable.
initHdmaFromParam: ; $00D7FB
        REP #$20
        AND.W #$00FF
        SEC
        SBC.W #$0004
        TAX
        SEP #$20
        LDA.L $00D83D,X
        STA.B $40
        LDA.B $54
        ASL A
        STA.B $3A
        LDA.B #$03
        STA.B $3C
        LDA.B #$80
        STA.B $3B
        LDX.W #$0003
        LDY.W #$0054
CODE_80D820: ; $00D820
        LDA.B [$3A]
        CLC
        ADC.B $6B
        STA.L $7EA001,X
        LDA.B $3A
        CLC
        ADC.B $40
        STA.B $3A
        INX
        INX
        INX
        DEY
        BNE CODE_80D820
        LDA.B #$00
        STA.L $7EA000,X
        RTS
        db $01,$02,$03,$04,$05,$07,$0B,$0D,$0F,$11,$13,$1F,$2F,$37,$3F,$7F
        db $80,$E2,$20,$A5,$54,$0A,$85,$3A,$A9,$03,$85,$3C,$A9,$81,$85,$3B
        db $A5,$6B,$85,$40,$A2,$03,$00,$A0,$54,$00,$A7,$3A,$18,$65,$40,$85
        db $40,$9F,$01,$A0,$7E,$E6,$3A,$E6,$3A,$E8,$E8,$E8,$88,$D0,$EB,$A9
        db $00,$9F,$00,$A0,$7E,$60,$E2,$20,$A5,$54,$0A,$85,$3A,$A9,$03,$85
        db $3C,$A9,$80,$85,$3B,$64,$43,$A7,$3A,$10,$02,$C6,$43,$0A,$0A,$0A
        db $85,$42,$A2,$03,$00,$A0,$54,$00,$64,$40,$64,$41,$C2,$20,$A5,$40
        db $18,$65,$42,$85,$40,$E2,$20,$A5,$41,$18,$65,$6D,$9F,$01,$A0,$7E
        db $E8,$E8,$E8,$88,$D0,$E6,$A9,$00,$9F,$00,$A0,$7E,$60,$E2,$20,$A5
        db $54,$0A,$85,$3A,$A9,$03,$85,$3C,$A9,$80,$85,$3B,$A2,$03,$00,$A0
        db $54,$00,$A7,$3A,$18,$65,$6D,$9F,$01,$A0,$7E,$E6,$3A,$E8,$E8,$E8
        db $88,$D0,$EF,$A9,$00,$9F,$00,$A0,$7E,$60,$E2,$20
; [DMA] DMA ch1: $7E:9000 -> VRAM $7C00. Text tilemap upload.
dmaTextTileToVRAM: ; $00D8F9
        LDA.B #$80
        STA.W $2115
        LDY.W #$7C00
        STY.W $2116
        LDA.B #$01
        STA.W $4310
        LDA.B #$7E
        STA.W $4314
        LDY.W #$9000
        STY.W $4312
        LDA.B #$18
        STA.W $4311
        LDY.W #$0800
        STY.W $4315
        LDA.B #$02
        STA.W $420B
        STZ.B $57
        RTS
; [DMA] DMA ch1: $7F:B000 -> VRAM at [$78]. Tilemap buffer.
dmaTilemapToVRAM: ; $00D927
        LDA.B #$80
        STA.W $2115
        LDY.B $78
        STY.W $2116
        LDA.B #$01
        STA.W $4310
        LDA.B #$7F
        STA.W $4314
        LDY.W #$B000
        STY.W $4312
        LDA.B #$18
        STA.W $4311
        LDY.W #$0800
        STY.W $4315
        LDA.B #$02
        STA.W $420B
        STZ.B $57
        RTS
; [DMA] DMA ch1: $7F:D000 -> VRAM $5C00. Overlay tilemap.
dmaOverlayToVRAM: ; $00D954
        LDA.B #$80
        STA.W $2115
        LDY.W #$5C00
        STY.W $2116
        LDA.B #$01
        STA.W $4310
        LDA.B #$7F
        STA.W $4314
        LDY.W #$D000
        STY.W $4312
        LDA.B #$18
        STA.W $4311
        LDY.W #$0800
        STY.W $4315
        LDA.B #$02
        STA.W $420B
        STZ.B $57
        RTS
        db $08,$C2,$20,$48,$20,$96,$D9,$68,$E2,$20,$4A,$4A,$4A,$4A,$49,$80
        db $85,$7A,$28,$6B,$C2,$20,$29,$0F,$00,$0A,$A8,$B9,$A3,$D9,$85,$7B
        db $60,$B3,$D9,$B7,$D9,$DB,$D9,$0D,$DA,$3F,$DA,$61,$DA,$83,$DA,$97
        db $DA,$00,$00,$FF,$FF,$00,$00,$01,$00,$02,$00,$03,$00,$04,$00,$05
        db $00,$06,$00,$07,$00,$08,$00,$09,$01,$0A,$02,$0B,$03,$0C,$04,$0D
        db $05,$0E,$06,$0F,$07,$10,$08,$FF,$FF,$10,$08,$11,$09,$12,$0A,$13
        db $0B,$14,$0C,$15,$0D,$16,$0E,$17,$0F,$18,$10,$19,$11,$1A,$12,$1B
        db $13,$1C,$14,$1D,$15,$1E,$16,$1F,$17,$1F,$18,$1F,$19,$1F,$1A,$1F
        db $1B,$1F,$1C,$1F,$1D,$1F,$1E,$1F,$1F,$FF,$FF,$1F,$1F,$1F,$1E,$1F
        db $1D,$1F,$1C,$1F,$1B,$1F,$1A,$1F,$19,$1F,$18,$1F,$17,$1E,$16,$1E
        db $15,$1C,$14,$1B,$13,$1A,$12,$19,$11,$18,$10,$17,$0F,$16,$0E,$15
        db $0D,$14,$0C,$13,$0B,$12,$0A,$11,$09,$10,$08,$FF,$FF,$0F,$07,$0E
        db $06,$0D,$05,$0C,$04,$0B,$03,$0A,$02,$09,$01,$08,$00,$07,$00,$06
        db $00,$05,$00,$04,$00,$03,$00,$02,$00,$01,$00,$00,$00,$FF,$FF,$20
        db $00,$21,$00,$22,$00,$23,$00,$24,$00,$25,$00,$26,$00,$27,$00,$28
        db $00,$27,$00,$26,$00,$25,$00,$24,$00,$23,$00,$22,$00,$21,$00,$FF
        db $FF,$20,$00,$21,$00,$22,$00,$23,$00,$24,$00,$25,$00,$26,$00,$27
        db $00,$28,$00,$FF,$FF,$27,$00,$26,$00,$25,$00,$24,$00,$23,$00,$22
        db $00,$21,$00,$20,$00,$FF,$FF,$00,$00,$21,$04,$42,$08,$63,$0C,$84
        db $10,$A5,$14,$C6,$18,$E7,$1C,$08,$21,$29,$25,$4A,$29,$6B,$2D,$8C
        db $31,$AD,$35,$CE,$39,$EF,$3D,$10,$42,$31,$46,$52,$4A,$73,$4E,$94
        db $52,$B5,$56,$D6,$5A,$F7,$5E,$18,$63,$39,$67,$5A,$6B,$7B,$6F,$9C
        db $73,$BD,$77,$DE,$7B,$FF,$7F,$00,$00,$01,$00,$02,$00,$03,$00,$04
        db $00,$05,$00,$06,$00,$07,$00,$08,$00,$09,$00,$0A,$00,$0B,$00,$0C
        db $00,$0D,$00,$0E,$00,$0F,$00,$10,$00,$11,$00,$12,$00,$13,$00,$14
        db $00,$15,$00,$16,$00,$17,$00,$18,$00,$19,$00,$1A,$00,$1B,$00,$1C
        db $00,$1D,$00,$1E,$00,$1F,$00,$00,$00,$00,$04,$00,$08,$00,$0C,$00
        db $10,$00,$14,$00,$18,$00,$1C,$00,$20,$00,$24,$00,$28,$00,$2C,$00
        db $30,$00,$34,$00,$38,$00,$3C,$00,$40,$00,$44,$00,$48,$00,$4C,$00
        db $50,$00,$54,$00,$58,$00,$5C,$00,$60,$00,$64,$00,$68,$00,$6C,$00
        db $70,$00,$74,$00,$78,$00,$7C
; [DMA] Multi-purpose VBlank DMA flush: VRAM upload, palette CGRAM, text/tilemap/overlay dispatch
vblankDMADispatch: ; $00DB69
        PHP
        SEP #$20
        LDA.W $05F5
        BEQ CODE_80DBC6
        CLC
        ADC.B #$7F
        STA.W $2115
        LDA.B #$01
        STA.W $4310
        STA.W $4320
        STZ.W $4314
        STZ.W $4324
        REP #$20
        LDX.W #$05F6
        LDA.W #$2118
        STA.W $4311
        STA.W $4321
        LDA.W $0000,X
        STA.W $4315
        STA.W $4325
        LDA.W $0002,X
        PHA
        CLC
        ADC.W #$E400
        STA.W $2116
        LDA.W #$0680
        STA.W $4312
        LDA.W #$0600
        STA.W $4322
        SEP #$20
        LDA.B #$02
        STA.W $420B
        PLY
        STY.W $2116
        LDA.B #$04
        STA.W $420B
        STZ.W $05F5
CODE_80DBC6: ; $00DBC6
        LDA.B $5E
        BEQ CODE_80DBEA
        INC A
        BNE CODE_80DBD6
        LDA.B $5F
        STA.W $2131
        STZ.B $5E
        BRA CODE_80DBEA
CODE_80DBD6: ; $00DBD6
        db $8D,$55,$43,$A5,$5F,$8D,$21,$21,$A9,$C0,$8D,$52,$43,$A9,$20,$8D
        db $0B,$42,$64,$5E
CODE_80DBEA: ; $00DBEA
        LDA.B $57
        BEQ CODE_80DC06
        CMP.B #$FE
        BEQ CODE_80DBFC
        CMP.B #$FF
        BNE CODE_80DC01
        JSR.W dmaOverlayToVRAM
        JMP.W CODE_80DC06
CODE_80DBFC: ; $00DBFC
        JSR.W dmaTilemapToVRAM
        BRA CODE_80DC06
CODE_80DC01: ; $00DC01
        JSR.W dmaTextTileToVRAM
        BRA CODE_80DC06
CODE_80DC06: ; $00DC06
        PLP
        RTL
; PHA/PHP, if $10==0 poll $4210 bit 7 until VBlank fires, PLP/PLA. Frame sync.
waitForVblank: ; $00DC08
        PHA
        PHP
        SEP #$20
        LDA.B $10
        BNE CODE_80DC15
CODE_80DC10: ; $00DC10
        LDA.W $4210
        BPL CODE_80DC10
CODE_80DC15: ; $00DC15
        PLP
        PLA
        RTL
; [Init] Full PPU ($2101-$212F) + DMA ($4200-$420D) controller hard reset
initHardwareRegisters: ; $00DC18
        PHP
        REP #$30
        SEP #$20
        PHP
        REP #$30
        SEP #$20
        LDA.B #$03
        STA.W $2101
        LDA.B #$00
        STA.W $2102
        LDA.B #$00
        STA.W $2103
        LDA.B #$09
        STA.W $2105
        LDA.B #$00
        STA.W $2106
        LDA.B #$78
        STA.W $2107
        LDA.B #$70
        STA.W $2108
        LDA.B #$7C
        STA.W $2109
        LDA.B #$5C
        STA.W $210A
        LDA.B #$22
        STA.W $210B
        STA.B $73
        LDA.B #$66
        STA.W $210C
        LDA.B #$00
        LDX.W #$210D
        LDY.W #$0010
CODE_80DC63: ; $00DC63
        SEP #$20
        STA.W $0000,X
        STA.W $0000,X
        INX
        DEY
        BNE CODE_80DC63
        SEP #$20
        LDA.B #$80
        STA.W $2115
        REP #$20
        LDA.W #$0000
        STA.W $2116
        SEP #$20
        LDA.B #$00
        STA.W $211A
        LDA.B #$00
        STA.W $211B
        LDA.B #$01
        STA.W $211B
        LDA.B #$00
        STA.W $211C
        LDA.B #$00
        STA.W $211C
        LDA.B #$00
        STA.W $211D
        LDA.B #$00
        STA.W $211D
        LDA.B #$00
        STA.W $211E
        LDA.B #$01
        STA.W $211E
        LDA.B #$00
        STA.W $211F
        LDA.B #$00
        STA.W $211F
        LDA.B #$00
        STA.W $2120
        LDA.B #$00
        STA.W $2120
        LDA.B #$00
        STA.W $2121
        LDA.B #$00
        STA.W $2123
        LDA.B #$00
        STA.W $2124
        LDA.B #$00
        STA.W $2125
        LDA.B #$00
        STA.W $2126
        LDA.B #$00
        STA.W $2127
        LDA.B #$00
        STA.W $2128
        LDA.B #$00
        STA.W $2129
        LDA.B #$00
        STA.W $212A
        LDA.B #$00
        STA.W $212B
        LDA.B #$17
        STA.W $212C
        LDA.B #$00
        STA.W $212D
        LDA.B #$00
        STA.W $212E
        LDA.B #$00
        STA.W $212F
        LDA.B #$32
        STA.W $2130
        LDA.B #$00
        STA.W $2131
        LDA.B #$E0
        STA.W $2132
        LDA.B #$04
        STA.W $2133
        LDA.B #$17
        STA.B $74
        LDA.B #$00
        STA.B $75
        PLP
        REP #$30
        SEP #$20
        LDA.B #$80
        STA.W $4200
        LDA.B #$FF
        STA.W $4201
        LDA.B #$00
        STA.W $4202
        LDA.B #$00
        STA.W $4203
        LDA.B #$00
        STA.W $4204
        LDA.B #$00
        STA.W $4205
        LDA.B #$00
        STA.W $4206
        LDA.B #$00
        STA.W $4207
        LDA.B #$00
        STA.W $4208
        LDA.B #$00
        STA.W $4209
        LDA.B #$00
        STA.W $420A
        LDA.B #$00
        STA.W $420B
        LDA.B #$00
        STA.W $420C
        LDA.B #$00
        STA.W $420D
        PLP
        RTL
        db $08,$18,$C2,$20,$A9,$87,$78,$85,$12,$A9,$10,$00,$85,$00,$A9,$00
        db $18,$85,$02,$C2,$20,$A5,$12,$8D,$16,$21,$E2,$20,$A9,$80,$8D,$15
        db $21,$AD,$15,$21,$C2,$30,$A0,$10,$00,$A5,$02,$8D,$18,$21,$1A,$88
        db $D0,$F9,$85,$02,$A5,$12,$18,$69,$20,$00,$85,$12,$C6,$00,$D0,$D3
        db $28,$6B
; [VRAM] Zeros BG3 tilemap ($7800, $1000 words) and BG1 tilemap ($2000, $0800 words) in VRAM
clearBGTilemapVRAM: ; $00DDB2
        PHP
        CLC
        REP #$20
        LDA.W #$7800
        STA.W $2116
        SEP #$20
        LDA.B #$80
        STA.W $2115
        LDA.W $2115
        REP #$20
        LDY.W #$1000
        LDA.W #$0000
CODE_80DDCE: ; $00DDCE
        STA.W $2118
        DEY
        BNE CODE_80DDCE
        LDA.W #$2000
        STA.W $2116
        LDY.W #$0800
        LDA.W #$0000
CODE_80DDE0: ; $00DDE0
        STA.W $2118
        DEY
        BNE CODE_80DDE0
        PLP
        RTL
; [VRAM] Generic VRAM fill: X=dest addr, A=value, Y=word count
fillVRAMRegion: ; $00DDE8
        PHP
        CLC
        REP #$20
        PHA
        STX.W $2116
        SEP #$20
        LDA.B #$80
        STA.W $2115
        LDA.W $2115
        REP #$20
        PLA
CODE_80DDFD: ; $00DDFD
        STA.W $2118
        DEY
        BNE CODE_80DDFD
        PLP
        RTL
; [Text] Loads font tile data to VRAM - writes each byte to both $2118 and $2119 (2bpp from 1bpp source). Entry: X=VRAM address, Y=tile count, $12/$14=font data pointer.
loadFontTile: ; $00DE05
        PHP
        REP #$20
        STX.W $2116
        STY.B $00
        LDY.W #$0000
        SEP #$20
        LDA.B #$80
        STA.W $2115
        LDA.W $2115
CODE_80DE1A: ; $00DE1A
        PHY
        LDX.W #$0008
CODE_80DE1E: ; $00DE1E
        LDA.B [$12],Y
        STA.W $2118
        STA.W $2119
        INY
        INY
        DEX
        BNE CODE_80DE1E
        PLY
        INY
        LDX.W #$0008
CODE_80DE30: ; $00DE30
        LDA.B [$12],Y
        STA.W $2118
        STA.W $2119
        INY
        INY
        DEX
        BNE CODE_80DE30
        DEY
        DEC.B $00
        BNE CODE_80DE1A
        PLP
        RTL
        db $08,$18,$C2,$20,$A9,$00,$40,$8D,$16,$21,$E2,$20,$A9,$80,$8D,$15
        db $21,$AD,$15,$21,$C2,$20,$A0,$00,$40,$A9,$00,$00,$8D,$18,$21,$88
        db $D0,$FA,$28,$6B
; [OAM] Calls clearHardwareOAM, fills $0100-$01FF with $E000 (offscreen), $0300 with $AA (size table)
clearOAMBuffers: ; $00DE68
        PHY
        PHX
        PHA
        PHP
        SEP #$20
        SEP #$20
        REP #$10
        LDA.B #$00
        STA.W $2101
        JSR.W clearHardwareOAM
        REP #$30
        LDX.W #$0000
        LDY.W #$0100
        LDA.W #$E000
CODE_80DE85: ; $00DE85
        STA.W $0100,X
        INX
        INX
        DEY
        BNE CODE_80DE85
        SEP #$20
        LDY.W #$0020
        LDA.B #$AA
CODE_80DE94: ; $00DE94
        STA.W $0100,X
        INX
        DEY
        BNE CODE_80DE94
        PLP
        PLA
        PLX
        PLY
        RTL
; [OAM] Zeros OAMADD, writes $200 zeros + $20 $FFs to OAMDATA port directly
clearHardwareOAM: ; $00DEA0
        PHY
        PHA
        PHP
        REP #$30
        LDA.W #$0000
        STA.W $2102
        SEP #$20
        LDY.W #$0200
        LDA.B #$00
CODE_80DEB2: ; $00DEB2
        SEP #$20
        STA.W $2104
        DEY
        BNE CODE_80DEB2
        LDY.W #$0020
        SEP #$20
        LDA.B #$FF
CODE_80DEC1: ; $00DEC1
        SEP #$20
        STA.W $2104
        DEY
        BNE CODE_80DEC1
        PLP
        PLA
        PLY
        RTS
        db $5A,$DA,$48,$08,$A5,$14,$48,$A5,$12,$48,$A5,$06,$48,$A5,$04,$48
        db $A5,$02,$48,$C2,$30,$A3,$14,$30,$03,$8D,$02,$21,$A3,$16,$85,$12
        db $E2,$20,$A3,$18,$85,$14,$A0,$00,$00,$E2,$20,$E2,$20,$B7,$12,$85
        db $06,$F0,$31,$C8,$B7,$12,$85,$02,$C8,$B7,$12,$85,$04,$C8,$E2,$20
        db $A5,$02,$8D,$04,$21,$A5,$04,$8D,$04,$21,$B7,$12,$8D,$04,$21,$C8
        db $B7,$12,$8D,$04,$21,$C8,$A5,$02,$18,$69,$10,$85,$02,$C6,$06,$D0
        db $DD,$4C,$F8,$DE,$C2,$20,$68,$85,$02,$68,$85,$04,$68,$85,$06,$68
        db $85,$12,$68,$85,$14,$28,$68,$FA,$7A,$6B
; [Math] STA $4202, INC $52, table lookup, reads $4216. RTL.
hardwareMultiplyRng: ; $00DF47
        PHP
        PHX
        SEP #$20
        STA.W $4202
        INC.B $52
        LDA.B $52
        REP #$20
        AND.W #$00FF
        TAX
        SEP #$20
        LDA.W $DFB7,X
        CLC
        ADC.B $54
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDA.W $4217
        REP #$20
        AND.W #$00FF
        PLX
        PLP
        RTL
; [RNG] INC $52, table at $DFB7,X. PRNG.
getRandomValue: ; $00DF72
        PHP
        PHX
        SEP #$20
        INC.B $52
        LDA.B $52
        REP #$20
        AND.W #$00FF
        TAX
        LDA.W $DFB7,X
        CLC
        ADC.B $54
        AND.W #$00FF
        PLX
        PLP
        RTL
; [DMA] DMA ch1: X=VMADD, Y=size, $14=bank. Generic VRAM DMA.
dmaToVRAMGeneric: ; $00DF8C
        PHP
        SEP #$20
        LDA.B #$80
        STA.W $2115
        STX.W $2116
        STY.W $4315
        LDA.B #$01
        STA.W $4310
        LDA.B $14
        STA.W $4314
        LDY.B $12
        STY.W $4312
        LDA.B #$18
        STA.W $4311
        SEI
        LDA.B #$02
        STA.W $420B
        CLI
        PLP
        RTL
        db $74,$08,$09,$17,$93,$C4,$33,$DC,$40,$FD,$43,$75,$86,$81,$78,$BF
        db $24,$F5,$B8,$2C,$2B,$BB,$D8,$20,$12,$F8,$EB,$57,$D1,$CF,$76,$DD
        db $82,$41,$3E,$68,$95,$21,$6D,$F2,$C2,$4C,$39,$4D,$8C,$48,$5C,$BD
        db $DA,$7F,$55,$5A,$6C,$4A,$0C,$16,$D9,$A5,$28,$29,$11,$64,$6F,$61
        db $79,$36,$E9,$72,$04,$71,$FA,$13,$8E,$B1,$A2,$E7,$3C,$4B,$80,$DE
        db $02,$E6,$05,$0F,$89,$88,$C3,$60,$66,$47,$92,$EC,$CC,$A7,$59,$2E
        db $49,$EF,$E0,$9E,$FB,$73,$32,$D3,$84,$CD,$18,$0B,$C0,$C6,$03,$B0
        db $F6,$9C,$B5,$77,$AE,$90,$CA,$EE,$1B,$FE,$31,$D6,$51,$7C,$C7,$07
        db $0D,$BE,$46,$D4,$23,$15,$BC,$26,$4F,$4E,$1D,$5B,$42,$00,$2F,$F7
        db $10,$DB,$AF,$AD,$27,$1F,$C5,$3A,$54,$F9,$F0,$E3,$38,$FC,$B3,$E4
        db $E5,$35,$EA,$6A,$0E,$44,$30,$45,$7A,$9A,$8B,$DF,$87,$B4,$53,$CB
        db $A0,$25,$3D,$98,$A3,$5E,$C1,$63,$C8,$BA,$2A,$52,$1E,$AA,$6B,$AB
        db $65,$7B,$8A,$B9,$C9,$8D,$70,$01,$56,$FF,$22,$14,$58,$37,$94,$19
        db $E8,$62,$E2,$6E,$8F,$A6,$2D,$D0,$F3,$83,$D2,$B2,$5D,$E1,$3F,$1C
        db $AC,$9D,$D7,$7E,$B7,$0A,$A1,$A4,$91,$A8,$9B,$CE,$5F,$D5,$99,$97
        db $85,$7D,$96,$1A,$ED,$50,$F4,$3B,$67,$34,$A9,$06,$B6,$9F,$F1,$69
        db $00,$00,$01,$01,$02,$02,$01,$01,$00,$00,$01,$01,$02,$02,$01,$01
        db $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$41,$42,$43,$44,$45,$46
        db $00,$00,$00,$02,$02,$FE,$00,$00,$02,$02,$00,$00,$01,$01,$00,$00
        db $01,$01,$FF,$00,$04,$04,$02,$00,$01,$03,$03,$01,$00,$01,$02,$01
        db $00,$00,$01,$01,$00,$00,$01,$01,$00,$00,$FF
; [Interrupt] H-IRQ handler: acks $4211, sets BG bases, scroll, screen designation. RTI.
irqBgSwapHandler: ; $00E102
        SEI
        PHA
        PHP
        SEP #$20
        LDA.W $4211
        LDA.B $6A
        BEQ CODE_80E13A
        LDA.B #$7C
        STA.W $2109
        LDA.B #$7C
        STA.W $2107
        STZ.W $2112
        STZ.W $2112
        STZ.W $2111
        STZ.W $2111
        LDA.B #$58
        STA.W $210E
        STZ.W $210E
        STZ.W $210D
        STZ.W $210D
        LDA.B #$05
        STA.W $212C
        STZ.W $212D
CODE_80E13A: ; $00E13A
        LDA.B $66
        STA.W $4209
        PLP
        PLA
        CLI
        RTI
; Single RTI instruction. Empty interrupt handler stub.
emptyIRQHandler: ; $00E143
        RTI
; [Memory] Word-copy. A=bytes, [$12]=src, [$16]=dst. RTL.
memcpyWords: ; $00E144
        PHP
        REP #$20
        LSR A
        TAX
        LDY.W #$0000
CODE_80E14C: ; $00E14C
        LDA.B [$12],Y
        STA.B [$16],Y
        INY
        INY
        DEX
        BNE CODE_80E14C
        PLP
        RTL
; [Memory] Word-fill. A=bytes, X=fill, [$12]=dst. RTL.
memfillWords: ; $00E157
        PHP
        REP #$20
        PHX
        LSR A
        TAX
        LDY.W #$0000
        PLA
CODE_80E161: ; $00E161
        STA.B [$12],Y
        INY
        INY
        DEX
        BNE CODE_80E161
        PLP
        RTL
        db $85,$04,$08,$C2,$20,$A9,$08,$00,$85,$06,$86,$08,$E2,$20,$A5,$18
        db $85,$14,$A7,$1A,$48,$29,$07,$0A,$85,$00,$68,$C2,$20,$29,$F8,$00
        db $0A,$0A,$18,$65,$00,$0A,$0A,$0A,$0A,$0A,$18,$65,$16,$85,$12,$E6
        db $1A,$DA,$DA,$A0,$40,$00,$22,$8C,$DF,$00,$68,$18,$69,$00,$01,$AA
        db $A5,$12,$18,$69,$00,$02,$85,$12,$A0,$40,$00,$22,$8C,$DF,$00,$68
        db $18,$69,$20,$00,$AA,$C6,$06,$D0,$0E,$A9,$08,$00,$85,$06,$A5,$08
        db $18,$69,$00,$02,$85,$08,$AA,$C6,$04,$D0,$A1,$28,$6B,$08,$C2,$20
        db $85,$08,$E2,$20,$A2,$00,$01,$64,$00,$64,$04,$64,$02,$A5,$02,$18
        db $69,$40,$9D,$00,$00,$A5,$00,$18,$69,$18,$9D,$01,$00,$A5,$04,$9D
        db $02,$00,$A9,$20,$18,$65,$08,$9D,$03,$00,$E8,$E8,$E8,$E8,$E6,$04
        db $E6,$04,$A5,$02,$18,$69,$10,$85,$02,$C9,$80,$D0,$D0,$A5,$04,$29
        db $F0,$18,$69,$10,$85,$04,$A5,$00,$18,$69,$10,$85,$00,$C9,$80,$D0
        db $BA,$28,$6B
; [Init] Scene init: loadMapData, force blank, disable IRQ/DMA, clear state.
initMapScene: ; $00E22D
        PHP
        JSL.L waitForVblank
        SEP #$20
        LDA.B #$02
        STA.B $10
        LDA.B #$8F
        STA.W $2100
        STZ.W $4200
        STZ.W $420B
        STZ.B $84
        STZ.W $420C
        REP #$20
; [Init] Full map mode init: zeros state vars, calls initHardwareRegisters+clearOAMBuffers, configures 7 HDMA channels, sets $10=3
initMapState: ; $00E24A
        STZ.W $0A87
        LDA.W #$0000
        TCD
        STA.W $004A
        STZ.B $60
        STZ.B $62
        STZ.B $6B
        STZ.B $6D
        STZ.B $64
        STZ.B $5E
        STZ.B $4C
        STZ.B $7B
        SEP #$20
        STZ.B $68
        STZ.B $69
        STZ.B $72
        STZ.B $71
        STZ.B $58
        STZ.W $05F5
        STZ.B $57
        STZ.B $6A
        STZ.B $76
        STZ.B $77
        STZ.B $7A
        STZ.W $0A50
        STZ.B $7F
        STZ.B $80
        STZ.B $81
        INC A
        STA.B $56
        STA.B $59
        JSL.L initHardwareRegisters
        JSL.L clearOAMBuffers
        LDA.B #$00
        JSL.L updateDepthEffect
        SEP #$20
        STZ.W $4300
        LDA.B #$04
        STA.W $4301
        STZ.W $4304
        LDA.B #$01
        STA.W $4310
        STA.W $4320
        STA.W $4330
        STA.W $4340
        STZ.W $4350
        LDA.B #$02
        STA.W $4360
        STZ.W $4314
        STZ.W $4324
        LDA.B #$7F
        STA.W $4334
        STZ.W $4344
        STZ.W $4354
        LDA.B #$7E
        STA.W $4364
        LDA.B #$18
        STA.W $4311
        STA.W $4321
        STA.W $4331
        LDA.B #$26
        STA.W $4341
        LDA.B #$22
        STA.W $4351
        LDA.B #$0F
        STA.W $4361
        REP #$20
        LDA.W #$00C8
        STA.W $4209
        LDA.W #$0100
        STA.W $4302
        LDA.W #$0220
        STA.W $4305
        LDA.W #$0DC0
        STA.W $4352
        STZ.W $4355
        LDA.W #$06F0
        STA.W $4342
        LDA.W #$A000
        STA.W $4362
        LDA.W #$0003
        STA.B $10
        PLP
        RTL
; [Scrolling] Updates depth/parallax effect. Entry: adjusts layer scrolling based on Z-depth.
updateDepthEffect: ; $00E31C
        PHP
        REP #$20
        LDX.W #$E353
        AND.W #$00FF
        BEQ CODE_80E336
        CMP.W #$0002
        BEQ CODE_80E331
        db $A2,$63,$E3,$80,$05
CODE_80E331: ; $00E331
        LDX.W #$E373
        BRA CODE_80E336
CODE_80E336: ; $00E336
        STX.B $12
        LDA.W #$0000
        STA.B $14
        LDX.W #$0000
        LDY.W #$0008
CODE_80E343: ; $00E343
        LDA.B [$12]
        STA.W $06F0,X
        INC.B $12
        INC.B $12
        INX
        INX
        DEY
        BNE CODE_80E343
        PLP
        RTL
        db $0F,$FF,$00,$64,$08,$F7,$41,$08,$F7,$02,$FF,$00,$81,$00,$FF,$00
        db $2A,$FF,$00,$58,$20,$DF,$35,$FF,$00,$02,$00,$FF,$81,$FF,$00,$00
        db $1E,$FF,$00,$6A,$10,$F0,$81,$FF,$00,$00,$00,$00,$00,$00,$00,$00
; [Palette] Palette upload: $2121 addr, $2122 data loop.
uploadPaletteCGRAM: ; $00E383
        PHY
        PHP
        LDA.B $14
        PHA
        LDA.B $12
        PHA
        LDA.B $0C,S
        STA.B $12
        SEP #$20
        LDA.B $0E,S
        STA.B $14
        LDA.B $0A,S
        STA.W $2121
        LDA.B $0B,S
        STA.B $15
        LDY.W #$0000
CODE_80E3A1: ; $00E3A1
        SEP #$20
        LDA.B [$12],Y
        STA.W $2122
        INY
        LDA.B [$12],Y
        STA.W $2122
        INY
        DEC.B $15
        BNE CODE_80E3A1
        REP #$20
        PLA
        STA.B $12
        PLA
        STA.B $14
        PLP
        PLY
        RTS
; [Helper] Checks $10 mode, zeros $10/$4A, waits $4A.
waitForModeSync: ; $00E3BE
        PHP
        SEP #$20
        LDA.B $10
        CMP.B #$02
        BEQ CODE_80E3D5
        CMP.B #$03
        BEQ CODE_80E3D7
        STZ.B $10
        STZ.B $4A
CODE_80E3CF: ; $00E3CF
        LDA.B $4A
        BEQ CODE_80E3CF
        INC.B $10
CODE_80E3D5: ; $00E3D5
        PLP
        RTL
CODE_80E3D7: ; $00E3D7
        JSL.L vblankDMADispatch
        BRA CODE_80E3D5
; [Helper] Calls waitForModeSync A times.
repeatModeSync: ; $00E3DD
        PHP
        REP #$20
CODE_80E3E0: ; $00E3E0
        CMP.W #$0000
        BEQ CODE_80E3EE
        PHA
        JSL.L waitForModeSync
        PLA
        DEC A
        BRA CODE_80E3E0
CODE_80E3EE: ; $00E3EE
        PLP
        RTL
; [Input] Reads $4218/$4219, XOR+AND edge detect to $50. RTL.
readJoypadNewPress: ; $00E3F0
        PHP
        REP #$20
        LDA.B $4E
        PHA
        SEP #$20
CODE_80E3F8: ; $00E3F8
        LDA.W $4212
        AND.B #$01
        BNE CODE_80E3F8
        LDA.W $4218
        STA.B $4E
        LDA.W $4219
        STA.B $4F
        REP #$20
        PLA
        EOR.B $4E
        AND.B $4E
        STA.B $50
        PLP
        RTL
        db $08,$E2,$20,$AD,$12,$42,$29,$01,$D0,$F9,$AD,$1A,$42,$85,$4E,$AD
        db $1B,$42,$85,$4F,$28,$6B,$00,$00,$00,$00,$00,$80,$00,$00
; [Entity] Clears $1000 (1KB), builds entries via buildObjectEntry.
initObjectTable: ; $00E432
        PHP
        SEP #$20
        LDY.W #$0400
        LDX.W #$0000
CODE_80E43B: ; $00E43B
        STZ.W $1000,X
        INX
        DEY
        BNE CODE_80E43B
        REP #$20
        STZ.W $0A9F
        STZ.W $0AA1
        LDA.W #$007C
        STA.W $0AA3
        LDA.W #$0000
        STA.B $42
        LDA.W #$E42A
        STA.B $40
        LDX.W #$1000
        JSR.W buildObjectEntry
        LDA.W #$8000
        STA.W $000C,X
        LDA.W $0E03
        JSR.W lookupDataTable
        STA.W $0006,X
        LDA.B $42
        STA.W $0AA9
        LDA.W $0E83
        AND.W #$00FF
        CMP.W #$00FF
        BEQ CODE_80E4A9
        LDA.W #$0000
        STA.B $42
        LDA.W #$E42A
        STA.B $40
        LDX.W #$1200
        JSR.W buildObjectEntry
        LDA.W #$8000
        STA.W $000C,X
        LDA.W #$60FF
        STA.W $0000,X
        LDA.W $0E83
        JSR.W lookupDataTable
        STA.W $0006,X
        LDA.B $42
        STA.W $0AAB
CODE_80E4A9: ; $00E4A9
        LDA.W $0E20
        AND.W #$00FF
        BNE CODE_80E4BF
        LDA.W #$3800
        STA.W $0A9B
        LDA.W #$3D00
        STA.W $0A9D
        BRA CODE_80E4CB
CODE_80E4BF: ; $00E4BF
        LDA.W #$2800
        STA.W $0A9B
        LDA.W #$2D00
        STA.W $0A9D
CODE_80E4CB: ; $00E4CB
        LDA.W #$0001
        STA.B $4C
        STZ.B $A5
        STZ.B $AA
        STZ.W $0A89
        STZ.W $0A91
        STZ.W $0AA5
        STZ.W $0AA7
        PLP
        RTL
; [Entity] Alt variant: clears $1000, different entry set.
initObjectTableAlt: ; $00E4E2
        PHP
        SEP #$20
        LDY.W #$0400
        LDX.W #$0000
CODE_80E4EB: ; $00E4EB
        STZ.W $1000,X
        INX
        DEY
        BNE CODE_80E4EB
        REP #$20
        LDA.B $24
        STA.W $0AA9
        STZ.W $0A9F
        STZ.W $0AA1
        LDA.W #$007C
        STA.W $0AA3
        LDA.W #$0000
        STA.B $42
        LDA.W #$E42A
        STA.B $40
        LDX.W #$1000
        JSR.W buildObjectEntry
        LDA.B $22
        STA.W $0006,X
        LDA.W #$3000
        STA.W $0A9B
        LDA.W #$3000
        STA.W $0A9D
        LDA.W #$0002
        STA.B $4C
        STZ.B $A5
        STZ.B $AA
        STZ.W $0A89
        STZ.W $0A91
        STZ.W $0AA5
        STZ.W $0AA7
        PLP
        RTL
; Zero $1000 buffer (1024 bytes), setup entity from $E42A data table, store params to entity struct.
initEntityObject: ; $00E53D
        PHP
        SEP #$20
        STA.W $0E03
        STZ.B $4C
        LDY.W #$0400
        LDX.W #$0000
CODE_80E54B: ; $00E54B
        STZ.W $1000,X
        INX
        DEY
        BNE CODE_80E54B
        REP #$20
        LDA.W #$0000
        STA.B $42
        LDA.W #$E42A
        STA.B $40
        LDX.W #$1000
        JSR.W buildObjectEntry
        LDA.W #$8000
        STA.W $000C,X
        LDA.W $0E03
        JSR.W lookupDataTable
        STA.W $0006,X
        LDA.B $42
        STA.W $0AA9
        LDA.W #$0001
        STA.B $4C
        STZ.B $A5
        STZ.B $AA
        STZ.W $0A89
        STZ.W $0A91
        LDA.W #$2800
        STA.W $0A9B
        PLP
        RTL
; [Entity] setObjectOffsets + buildObjectEntry.
initSingleObject: ; $00E58F
        PHP
        SEP #$20
        STZ.B $4C
        STZ.W $0E22
        REP #$20
        LDX.W #$0000
        LDY.W #$0000
        JSL.L setObjectOffsets
        LDA.W #$0000
        STA.B $42
        LDA.W #$E42A
        STA.B $40
        LDX.W #$1000
        JSR.W buildObjectEntry
        LDA.W #$8000
        STA.W $000C,X
        LDA.W $0E03
        JSR.W lookupDataTable
        STA.W $0006,X
        LDA.B $42
        STA.W $0AA9
        LDA.W #$2800
        STA.W $0A9B
        LDA.W #$0001
        STA.B $4C
        STZ.B $A5
        PLP
        RTL
; [Entity] X->$0A9F, Y->$0AA1, Y+$7C->$0AA3. RTL.
setObjectOffsets: ; $00E5D6
        STX.W $0A9F
        TYA
        STA.W $0AA1
        CLC
        ADC.W #$007C
        STA.W $0AA3
        RTL
; [Helper] A=idx, ROM table bank $0D/$0C lookup.
lookupDataTable: ; $00E5E5
        AND.W #$003F
        CMP.W #$001E
        BCS CODE_80E5FD
        ASL A
        TAY
        LDA.L $0D8002
        STA.B $40
        LDA.W #$000D
        STA.B $42
        LDA.B [$40],Y
        RTS
CODE_80E5FD: ; $00E5FD
        SEC
        SBC.W #$001E
        ASL A
        TAY
        LDA.L $0C8002
        STA.B $40
        LDA.W #$000C
        STA.B $42
        LDA.B [$40],Y
        RTS
; [Music] A=effect idx, JSR $F104. RTL.
loadDspEffectParams: ; $00E611
        PHP
        REP #$20
        AND.W #$007F
        JSR.W musicDSP_LoadEffectTable
        PLP
        RTL
; [Entity] 32-byte entry at X from [$40] stream. $0A9F/$0AA1 offsets.
buildObjectEntry: ; $00E61C
        PHP
        REP #$20
        LDY.W #$0010
        PHX
CODE_80E623: ; $00E623
        STZ.W $0000,X
        INX
        INX
        DEY
        BNE CODE_80E623
        PLX
        LDA.B [$40]
        INC.B $40
        INC.B $40
        CLC
        ADC.W $0A9F
        STA.W $0004,X
        LDA.B [$40]
        INC.B $40
        INC.B $40
        CLC
        ADC.W $0AA1
        STA.W $0018,X
        LDA.B [$40]
        INC.B $40
        INC.B $40
        STA.W $0006,X
        LDA.B [$40]
        INC.B $40
        AND.W #$00FF
        STA.W $0008,X
        LDA.B [$40]
        INC.B $40
        AND.W #$00FF
        STA.W $000A,X
        LDA.W #$80FF
        STA.W $0000,X
        LDA.W #$0800
        STA.W $001C,X
        LDA.W $0004,X
        CLC
        ADC.W $0018,X
        BNE CODE_80E680
        LDA.W #$8000
        STA.W $000C,X
        BRA CODE_80E686
CODE_80E680: ; $00E680
        LDA.W #$0003
        STA.W $000C,X
CODE_80E686: ; $00E686
        PLP
        RTS
; [Entity] Per-frame loop: updates entity physics + renders sprites for $1000/$1200 slots, flushes OAM
updateAndRenderEntities: ; $00E688
        PHP
        REP #$20
        LDA.W #$0100
        STA.B $3A
        LDA.W #$0300
        STA.B $3C
        LDA.W #$0280
        STA.B $3E
        LDA.W #$8000
        STA.B $9F
        STZ.B $A8
        LDA.W $0A91
        BEQ CODE_80E6D3
        DEC A
        STA.W $0A91
        CMP.W #$0050
        BCS CODE_80E6D3
        CMP.W #$0019
        BCS CODE_80E6B9
        AND.W #$0001
        BEQ CODE_80E6D3
CODE_80E6B9: ; $00E6B9
        LDA.W #$0100
        STA.B $A5
        STZ.B $9D
        LDA.W $0A93
        STA.B $99
        LDA.W $0A95
        STA.B $9B
        LDX.W #$1000
        LDA.W $0A97
        JSR.W musicHelper_WriteSPCRegister
CODE_80E6D3: ; $00E6D3
        LDA.W $0A89
        BEQ CODE_80E703
        INC A
        STA.W $0A89
        CMP.W #$001F
        BCC CODE_80E6E4
        STZ.W $0A89
CODE_80E6E4: ; $00E6E4
        LSR A
        LSR A
        AND.W #$0006
        CLC
        ADC.W $0A8F
        PHA
        STZ.B $A5
        STZ.B $9D
        LDX.W #$1000
        LDA.W $0A8B
        STA.B $99
        LDA.W $0A8D
        STA.B $9B
        PLA
        JSR.W musicHelper_WriteSPCRegister
CODE_80E703: ; $00E703
        LDA.W $0E5A
        BEQ CODE_80E745
        LDA.W $0A9D
        STA.B $A8
        LDA.W $0AAB
        STA.B $8F
        LDA.W #$0020
        STA.B $A5
        LDX.W #$1200
        LDY.W #$0010
CODE_80E71D: ; $00E71D
        LDA.W $0000,X
        BEQ CODE_80E72A
        PHY
        JSR.W updateObjectPhysics
        JSR.W renderObjectList
        PLY
CODE_80E72A: ; $00E72A
        TXA
        CLC
        ADC.W #$0020
        TAX
        DEY
        BNE CODE_80E71D
        LDA.W $0A9B
        STA.B $A8
        LDA.W $0AA9
        STA.B $8F
        LDX.W #$1000
        LDY.W #$0010
        BRA CODE_80E764
CODE_80E745: ; $00E745
        LDA.W $0A9B
        STA.B $A8
        LDA.W $0AA9
        STA.B $8F
        LDX.W #$1000
        LDY.W #$0020
CODE_80E755: ; $00E755
        CPY.W #$0010
        BNE CODE_80E764
        LDA.W $0A9D
        STA.B $A8
        LDA.W $0AAB
        STA.B $8F
CODE_80E764: ; $00E764
        LDA.W $0000,X
        BEQ CODE_80E771
        PHY
        JSR.W updateObjectPhysics
        JSR.W renderObjectList
        PLY
CODE_80E771: ; $00E771
        TXA
        CLC
        ADC.W #$0020
        TAX
        DEY
        BNE CODE_80E755
CODE_80E77A: ; $00E77A
        LSR.B $9F
        LSR.B $9F
        BCC CODE_80E77A
        LDA.B $9F
        STA.B ($3C)
        LDA.W #$F0F0
        LDX.B $3A
CODE_80E789: ; $00E789
        CPX.W #$0280
        BEQ CODE_80E79A
        STA.W $0000,X
        STZ.W $0002,X
        INX
        INX
        INX
        INX
        BRA CODE_80E789
CODE_80E79A: ; $00E79A
        LDA.W $0AA1
        BNE CODE_80E7B5
        LDA.W #$F0F0
        LDX.B $3E
CODE_80E7A4: ; $00E7A4
        CPX.W #$0300
        BEQ CODE_80E7B5
        STA.W $0000,X
        STZ.W $0002,X
        INX
        INX
        INX
        INX
        BRA CODE_80E7A4
CODE_80E7B5: ; $00E7B5
        PLP
        RTS
; [Entity] 2-bit state dispatch, velocity->position with fractional.
updateObjectPhysics: ; $00E7B7
        LDA.W $0001,X
        AND.W #$0003
        BNE CODE_80E7C0
        RTS
CODE_80E7C0: ; $00E7C0
        CMP.W #$0001
        BEQ CODE_80E804
        CMP.W #$0003
        BNE CODE_80E7CD
        JMP.W $E84F
CODE_80E7CD: ; $00E7CD
        LDA.W $0012,X
        BNE CODE_80E7D5
        JMP.W $E845
CODE_80E7D5: ; $00E7D5
        DEC A
        STA.W $0012,X
        LDA.W $0003,X
        CLC
        ADC.W $000E,X
        STA.W $0003,X
        SEP #$20
        CLC
        ADC.W $0005,X
        STA.W $0005,X
        REP #$20
        LDA.W $0017,X
        CLC
        ADC.W $0010,X
        STA.W $0017,X
        SEP #$20
        CLC
        ADC.W $0019,X
        STA.W $0019,X
        REP #$20
        RTS
CODE_80E804: ; $00E804
        LDA.W $0014,X
        CLC
        ADC.W $0012,X
        BCS CODE_80E811
        STA.W $0014,X
        RTS
CODE_80E811: ; $00E811
        LDA.W $0000,X
        AND.W #$0C00
        BEQ CODE_80E833
        db $BD,$02,$00,$9D,$04,$00,$BD,$16,$00,$9D,$18,$00,$22,$72,$DF,$00
        db $48,$22,$72,$DF,$00,$7A,$20,$5C,$F4,$60
CODE_80E833: ; $00E833
        LDA.W $0002,X
        STA.W $0004,X
        LDA.W $0016,X
        STA.W $0018,X
        STZ.W $0012,X
        STZ.W $0014,X
        LDA.W $0000,X
        AND.W #$FCFF
        STA.W $0000,X
        RTS
        LDA.W $0010,X
        CLC
        ADC.W $0012,X
        STA.W $0010,X
        LDA.W $0003,X
        CLC
        ADC.W $000E,X
        STA.W $0003,X
        LDA.W $0010,X
        CMP.W #$8000
        BCC CODE_80E877
        LDA.W $0017,X
        CLC
        ADC.W $0010,X
        STA.W $0017,X
        BRA CODE_80E89E
CODE_80E877: ; $00E877
        LDA.W $0017,X
        CLC
        ADC.W $0010,X
        CMP.W #$8400
        BCC CODE_80E89B
        LDA.W $0010,X
        DEC A
        EOR.W #$FFFF
        CLC
        ADC.W $0014,X
        STA.W $0010,X
        LDA.W $001A,X
        DEC A
        STA.W $001A,X
        LDA.W #$8400
CODE_80E89B: ; $00E89B
        STA.W $0017,X
CODE_80E89E: ; $00E89E
        LDA.W $001A,X
        BNE CODE_80E8A6
        JMP.W $E845
CODE_80E8A6: ; $00E8A6
        RTS
; [OAM] Iterates objects, copies pos to $99/$9B for OAM.
renderObjectList: ; $00E8A7
        SEP #$20
        LDA.W $0001,X
        AND.B #$03
        CMP.B #$01
        BEQ CODE_80E8C1
        REP #$20
        LDA.W $0004,X
        STA.B $99
        LDA.W $0018,X
        STA.B $9B
        JMP.W CODE_80E975
CODE_80E8C1: ; $00E8C1
        SEP #$20
        LDA.W $0015,X
        STA.B $42
        LDA.W $000C,X
        AND.B #$07
        STA.B $43
        LDY.B $42
        LDA.W $F4CB,Y
        STA.B $40
        LDA.W $000F,X
        BEQ CODE_80E900
        LDA.W $000E,X
        STA.W $4202
        LDA.B $40
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDA.W $4217
        REP #$20
        AND.W #$00FF
        STA.B $44
        LDA.W $0004,X
        SEC
        SBC.B $44
        STA.B $99
        BRA CODE_80E91D
        db $E2,$20
CODE_80E900: ; $00E900
        LDA.W $000E,X
        STA.W $4202
        LDA.B $40
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDA.W $4217
        REP #$20
        AND.W #$00FF
        CLC
        ADC.W $0004,X
        STA.B $99
CODE_80E91D: ; $00E91D
        SEP #$20
        LDA.W $000C,X
        LSR A
        LSR A
        LSR A
        STA.B $43
        LDY.B $42
        LDA.W $F4CB,Y
        STA.B $40
        LDA.W $0011,X
        BEQ CODE_80E958
        LDA.W $0010,X
        STA.W $4202
        LDA.B $40
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDA.W $4217
        REP #$20
        AND.W #$00FF
        STA.B $44
        LDA.W $0018,X
        SEC
        SBC.B $44
        STA.B $9B
        BRA CODE_80E975
        db $E2,$20
CODE_80E958: ; $00E958
        LDA.W $0010,X
        STA.W $4202
        LDA.B $40
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDA.W $4217
        REP #$20
        AND.W #$00FF
        CLC
        ADC.W $0018,X
        STA.B $9B
CODE_80E975: ; $00E975
        LDA.W $0000,X
        AND.W #$2000
        BEQ CODE_80E98B
        LDA.B $99
        DEC A
        EOR.W #$FFFF
        CLC
        ADC.W #$0100
        STA.B $99
        INC.B $A7
CODE_80E98B: ; $00E98B
        LDA.W $0006,X
        CMP.W #$8000
        BCS CODE_80E9A3
        STA.B $40
        LDA.B $A8
        PHA
        STZ.B $A8
        LDA.B $40
        JSR.W musicHelper_WriteSPCRegister
        PLA
        STA.B $A8
        RTS
CODE_80E9A3: ; $00E9A3
        STA.B $8D
        LDA.W $0008,X
        LSR A
        STA.B $40
        LDA.B $9B
        SEC
        SBC.W $000A,X
        STA.B $9B
        LDA.W $0000,X
        AND.W #$4000
        BEQ CODE_80E9CD
        LDA.W #$FFF0
        STA.B $9D
        LDA.B $99
        CLC
        ADC.B $40
        SEC
        SBC.W #$0010
        STA.B $99
        BRA CODE_80E9D9
CODE_80E9CD: ; $00E9CD
        LDA.W #$0010
        STA.B $9D
        LDA.B $99
        SEC
        SBC.B $40
        STA.B $99
CODE_80E9D9: ; $00E9D9
        LDA.B $99
        STA.B $91
        STA.B $95
        LDA.B $9B
        STA.B $93
        STA.B $97
        STZ.B $A1
        STZ.B $A3
        LDA.B [$8D]
        STA.B $40
        AND.W #$00FF
        INC.B $8D
        CMP.W #$00F0
        BNE CODE_80E9FA
        JMP.W $EA9E
CODE_80E9FA: ; $00E9FA
        BCC CODE_80E9FF
        JMP.W $EAC8
CODE_80E9FF: ; $00E9FF
        CMP.W #$0080
        BCC CODE_80EA07
        JMP.W $EA6A
CODE_80EA07: ; $00EA07
        CMP.W #$0070
        BCC CODE_80EA80
        SEP #$20
        EOR.B #$02
        ASL A
        ASL A
        ASL A
        ASL A
        STA.B $42
        LDA.B #$10
        TRB.B $42
        BEQ CODE_80EA20
        LDA.B #$02
        TSB.B $42
CODE_80EA20: ; $00EA20
        LDA.B $42
        AND.B #$20
        BEQ CODE_80EA33
        REP #$20
        LDA.B $41
        INC.B $8D
        JSR.W musicHelper_WriteSPCRegister
        BRA CODE_80EA94
        db $E2,$20
CODE_80EA33: ; $00EA33
        LDA.B $A7
        BNE CODE_80EA44
        LDA.B $9D
        CMP.B #$10
        BEQ CODE_80EA44
        LDA.B $99
        CLC
        ADC.B #$08
        STA.B $99
CODE_80EA44: ; $00EA44
        REP #$20
        LDA.B $41
        INC.B $8D
        JSR.W musicHelper_WriteSPCRegister
        LDA.B $9D
        CMP.W #$0010
        BNE CODE_80EA5F
        LDA.B $99
        CLC
        ADC.W #$0008
        STA.B $99
        JMP.W $E9E9
CODE_80EA5F: ; $00EA5F
        LDA.B $99
        SEC
        SBC.W #$0008
        STA.B $99
        JMP.W $E9E9
        PHA
        AND.W #$000F
        STA.B $40
        PLA
        AND.W #$0070
        ASL A
        CLC
        ADC.B $40
        ORA.W #$2200
        JSR.W musicHelper_WriteSPCRegister
        BRA CODE_80EA94
CODE_80EA80: ; $00EA80
        PHA
        AND.W #$000F
        STA.B $40
        PLA
        AND.W #$0070
        ASL A
        CLC
        ADC.B $40
        ORA.W #$2000
        JSR.W musicHelper_WriteSPCRegister
CODE_80EA94: ; $00EA94
        LDA.B $99
        CLC
        ADC.B $9D
        STA.B $99
        JMP.W $E9E9
        LDA.B $9B
        CLC
        ADC.W #$0010
        STA.B $9B
        LDA.B $91
        STA.B $99
        SEP #$20
        STZ.B $A7
        REP #$20
        JMP.W $E9E9
CODE_80EAB3: ; $00EAB3
        LDA.B $9B
        CLC
        ADC.W #$0008
        STA.B $9B
        LDA.B $91
        STA.B $99
        SEP #$20
        STZ.B $A7
        REP #$20
        JMP.W $E9E9
        CMP.W #$00F9
        BEQ CODE_80EAB3
        CMP.W #$00FE
        BNE CODE_80EAD5
        JMP.W musicNote_CheckTimer
CODE_80EAD5: ; $00EAD5
        CMP.W #$00FD
        BNE CODE_80EADD
        JMP.W $EC32
CODE_80EADD: ; $00EADD
        CMP.W #$00FC
        BNE CODE_80EAE5
        JMP.W $ED63
CODE_80EAE5: ; $00EAE5
        CMP.W #$00F1
        BNE CODE_80EAED
        JMP.W $EC75
CODE_80EAED: ; $00EAED
        CMP.W #$00F2
        BNE CODE_80EAF5
        JMP.W $ED34
CODE_80EAF5: ; $00EAF5
        CMP.W #$00F3
        BNE musicCmd_DispatchHigh
        JSR.W musicHelper_GetVoiceSlot
        JMP.W $ED79
; [Music] Dispatch $F4-$FB music commands to handlers
musicCmd_DispatchHigh: ; $00EB00
        CMP.W #$00F4
        BNE musicCmd_CheckF5
        JSR.W musicHelper_GetVoiceSlot
        JMP.W musicCmd_F4_ReadParams
; [Music] Check for $F5 command (set envelope params)
musicCmd_CheckF5: ; $00EB0B
        CMP.W #$00F5
        BNE musicCmd_CheckF6
        JSR.W musicHelper_GetVoiceSlot
        JMP.W musicCmd_F5_ReadParams
; [Music] Check for $F6 command (loop/repeat control)
musicCmd_CheckF6: ; $00EB16
        CMP.W #$00F6
        BNE musicCmd_CheckF7
        JSR.W musicHelper_GetVoiceSlot
        JMP.W musicCmd_F6_Loop
; [Music] Check for $F7 command (note with pitch data)
musicCmd_CheckF7: ; $00EB21
        CMP.W #$00F7
        BNE musicCmd_CheckF8
        JMP.W CODE_80EA94
; [Music] Check for $F8 command (voice setup)
musicCmd_CheckF8: ; $00EB29
        CMP.W #$00F8
        BNE musicCmd_CheckFA
        JMP.W musicCmd_F8_VoiceSetup
; [Music] Check for $FA command (channel setup)
musicCmd_CheckFA: ; $00EB31
        CMP.W #$00FA
        BNE musicCmd_CheckFB
        JMP.W musicCmd_FA_ChannelSetup
; [Music] Check for $FB command (end track/return)
musicCmd_CheckFB: ; $00EB39
        CMP.W #$00FB
        BNE musicCmd_DispatchNote
        JMP.W musicCmd_FB_EndTrack
; [Music] Dispatch by note/command byte range: $E0+, $D0+, $C0+, $B0+, $A0+, $90+, $80+, $70+, $60+
musicCmd_DispatchNote: ; $00EB41
        LDA.B $41
        AND.W #$00FF
        INC.B $8D
        CMP.W #$00E0
        BCC musicCmd_RangeD0
        JMP.W musicCmd_RangeE0
; [Music] Handle $D0-$DF range — write indexed value
musicCmd_RangeD0: ; $00EB50
        CMP.W #$00D0
        BCC musicCmd_RangeC0
        JMP.W $ED10
; [Music] Handle $C0-$CF range — write indexed value
musicCmd_RangeC0: ; $00EB58
        CMP.W #$00C0
        BCC musicCmd_RangeB0
        JMP.W $ECF2
; [Music] Handle $B0-$BF range — spawn sub-voice
musicCmd_RangeB0: ; $00EB60
        CMP.W #$00B0
        BCC musicCmd_RangeA0
        JMP.W $EC9C
; [Music] Handle $A0-$AF range — jump table dispatch
musicCmd_RangeA0: ; $00EB68
        CMP.W #$00A0
        BCC musicCmd_Range90
        JMP.W musicCmd_A0_JumpTable
; [Music] Handle $90-$9F range — pitch adjust (signed)
musicCmd_Range90: ; $00EB70
        CMP.W #$0090
        BCC musicCmd_Range80
        JMP.W musicCmd_F4_PitchAdjust
; [Music] Handle $80-$8F range — multi-byte note data
musicCmd_Range80: ; $00EB78
        CMP.W #$0080
        BCC musicCmd_Range70
        JMP.W $ED76
; [Music] Handle $70-$7F range — check voice status
musicCmd_Range70: ; $00EB80
        CMP.W #$0070
        BCC musicCmd_Range60
        db $4C,$52,$ED
; [Music] Handle $60-$6F range — rest/duration. Store to $1C/$1D.
musicCmd_Range60: ; $00EB88
        CMP.W #$0060
        BCC musicCmd_Range60_Store
        JMP.W musicCmd_F5_SetEnvelope
; [Music] Store duration low 6 bits to voice timer $1C/$1D, set next ptr
musicCmd_Range60_Store: ; $00EB90
        AND.W #$003F
        PHX
        PHA
        JSR.W musicHelper_GetVoiceSlot
        TYX
        PLA
        SEP #$20
        STA.W $001D,X
        STA.W $001C,X
        REP #$20
        PLX
        LDA.B $8D
        STA.W $0006,X
        JMP.W $E9E9
; [Music] Handle $E0-$EB command range dispatch
musicCmd_RangeE0: ; $00EBAD
        CMP.W #$00E1
        BNE musicCmd_E2
        db $4C,$5E,$EC
; [Music] $E2: set loop return address
musicCmd_E2: ; $00EBB5
        CMP.W #$00E2
        BNE musicCmd_E0
        JMP.W $EC8E
; [Music] $E0: jump — load new music data pointer from [$8D]
musicCmd_E0: ; $00EBBD
        CMP.W #$00E0
        BNE musicCmd_E3
        LDA.B [$8D]
        STA.B $8D
        JMP.W $E9E9
; [Music] $E3: call subroutine (via $F174)
musicCmd_E3: ; $00EBC9
        CMP.W #$00E3
        BNE musicCmd_E4
        JMP.W musicStream_ReadVoiceParam
; [Music] $E4: return from subroutine (via $F126)
musicCmd_E4: ; $00EBD1
        CMP.W #$00E4
        BNE musicCmd_E5
        JMP.W musicCmd_E4_Return
; [Music] $E5: loop back (via $F162)
musicCmd_E5: ; $00EBD9
        CMP.W #$00E5
        BNE musicCmd_E6
        JMP.W musicCmd_E5_LoopBack
; [Music] $E6: conditional branch (via $F251)
musicCmd_E6: ; $00EBE1
        CMP.W #$00E6
        BNE musicCmd_E7
        JMP.W musicCmd_E6_CondFlag
; [Music] $E7: set register (via $F26E)
musicCmd_E7: ; $00EBE9
        CMP.W #$00E7
        BNE musicCmd_E8
        JMP.W musicCmd_E7_SetReg
; [Music] $E8: compare/test (via $F2A8)
musicCmd_E8: ; $00EBF1
        CMP.W #$00E8
        BNE musicCmd_E9
        JMP.W musicCmd_E8_Compare
; [Music] $E9: branch on compare (via $F2BF)
musicCmd_E9: ; $00EBF9
        CMP.W #$00E9
        BNE musicCmd_EA
        JMP.W musicCmd_E9_BranchByte
; [Music] $EA: arithmetic op (via $F2CD)
musicCmd_EA: ; $00EC01
        CMP.W #$00EA
        BNE musicCmd_EB
        JMP.W musicCmd_EA_CondJump
; [Music] $EB: bitwise op (via $F2D8)
musicCmd_EB: ; $00EC09
        CMP.W #$00EB
        BNE musicCmd_Unknown
        JMP.W musicCmd_EB_SetTimer
; [Music] Unknown command — skip, jump back to main loop
musicCmd_Unknown: ; $00EC11
        JMP.W $E9E9
; [Music] Check note timer — if zero, reload duration and advance; else decrement
musicNote_CheckTimer: ; $00EC14
        SEP #$20
        LDA.W $001C,X
        BNE musicNote_Reload
        LDA.W $001D,X
        STA.W $001C,X
        BRA musicNote_Advance
; [Music] Timer zero — reload from $1D, set $1C
musicNote_Reload: ; $00EC23
        DEC A
        STA.W $001C,X
        REP #$20
        RTS
; [Music] Advance music data pointer after note completes
musicNote_Advance: ; $00EC2A
        REP #$20
        LDA.B $8D
        STA.W $0006,X
        RTS
        LDA.B $A1
        BNE CODE_80EC4A
        LDA.W $001E,X
        BNE CODE_80EC42
        db $A5,$8D,$3A,$9D,$06,$00,$60
CODE_80EC42: ; $00EC42
        STA.B $8D
        STZ.W $001E,X
        JMP.W $E9E9
CODE_80EC4A: ; $00EC4A
        TAY
        DEY
        DEY
        STY.B $A1
        LDA.W $0F00,Y
        STA.B $8D
        TYA
        BNE CODE_80EC5B
        LDA.B $A3
        BNE musicNote_CheckTimer
CODE_80EC5B: ; $00EC5B
        JMP.W $E9E9
; [Music] $E1: push return address to music stack $0F00, jump to target
musicCmd_E1: ; $00EC5E
        db $A5,$A1,$A8,$1A,$1A,$85,$A1,$A5,$8D,$1A,$1A,$99,$00,$0F,$A7,$8D
        db $85,$8D,$E6,$A3,$4C,$E9,$E9
        LDA.B [$8D]
        PHA
        LDA.B $A1
        TAY
        INC A
        INC A
        STA.B $A1
        LDA.B $8D
        INC A
        INC A
        STA.W $0F00,Y
        PLA
        STA.B $8D
        INC.B $A3
        JMP.W $E9E9
        LDA.B $8D
        INC A
        INC A
        STA.W $001E,X
        LDA.B [$8D]
        STA.B $8D
        JMP.W $E9E9
        PHX
        JSR.W musicHelper_GetVoicePtr
        PHA
        LDA.B $8F
        STA.B $42
        LDA.B $8D
        STA.B $40
        LDA.W $0000,X
        AND.W #$F0FF
        STA.B $44
        TYX
        JSR.W buildObjectEntry
        LDA.B $44
        STA.W $0000,X
        LDA.W $0004,X
        CLC
        ADC.W $0018,X
        STA.B $42
        PLA
        STA.B $40
        SEP #$20
        STA.W $000D,X
        REP #$20
        PLX
        LDA.B $8D
        CLC
        ADC.W #$0008
        STA.B $8D
        LDA.B $42
        BNE CODE_80ECDD
        JMP.W $E9E9
CODE_80ECDD: ; $00ECDD
        SEP #$20
        LDA.W $000D,X
        CMP.B #$80
        BCC CODE_80ECED
        LDA.B $40
        ORA.B #$80
        STA.W $000D,X
CODE_80ECED: ; $00ECED
        REP #$20
        JMP.W $E9E9
        JSR.W musicHelper_GetChannelIndex
        STY.B $40
        LDA.B [$8D]
        PHA
        INC.B $8D
        INC.B $8D
        LDA.B [$8D]
        AND.W #$00FF
        CLC
        ADC.B $40
        TAY
        INC.B $8D
        PLA
        STA.W $0000,Y
        JMP.W $E9E9
        JSR.W musicHelper_GetChannelIndex
        STY.B $40
        LDA.B [$8D]
        STA.B $42
        INC.B $8D
        INC.B $8D
        LDA.B [$8D]
        AND.W #$00FF
        CLC
        ADC.B $40
        TAY
        INC.B $8D
        LDA.W $0000,Y
        CLC
        ADC.B $42
        STA.W $0000,Y
        JMP.W $E9E9
        JSR.W musicHelper_GetVoiceSlot
        STY.B $40
        LDA.B [$8D]
        AND.W #$00FF
        INC.B $8D
        CLC
        ADC.B $40
        TAY
        LDA.B [$8D]
        INC.B $8D
        SEP #$20
        STA.W $0000,Y
        REP #$20
        JMP.W $E9E9
        db $20,$2B,$F3,$B9,$00,$00,$29,$00,$03,$F0,$03,$4C,$D4,$F1,$4C,$E9
        db $E9
        JSR.W musicHelper_GetVoiceSlot
        LDA.W $0000,Y
        AND.W #$0300
        BEQ CODE_80ED73
        INC.B $8D
        JMP.W musicPtr_Rewind
CODE_80ED73: ; $00ED73
        JMP.W $E9E9
        JSR.W musicHelper_GetVoicePtr
        PHX
        TYX
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        PHA
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        TAY
        PLA
CODE_80ED8C: ; $00ED8C
        JSR.W musicVoice_SetTarget
        LDA.B [$8D]
        INC.B $8D
        JSR.W musicHelper_SignExtendNegate
        ASL A
        ASL A
        CLC
        ADC.W $0012,X
        STA.W $0012,X
        PLX
        JMP.W $E9E9
; [Music] $F4/$90+: signed pitch adjustment on voice
musicCmd_F4_PitchAdjust: ; $00EDA3
        JSR.W musicHelper_GetVoicePtr
; [Music] Read pitch adjust params: signed offset + duration
musicCmd_F4_ReadParams: ; $00EDA6
        PHX
        TYX
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        CMP.W #$0080
        BCC CODE_80EDB7
        ORA.W #$FF00
CODE_80EDB7: ; $00EDB7
        CLC
        ADC.W $0004,X
        PHA
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        CMP.W #$0080
        BCC CODE_80EDCB
        db $09,$00,$FF
CODE_80EDCB: ; $00EDCB
        CLC
        ADC.W $0018,X
        TAY
        PLA
        BRA CODE_80ED8C
; [Music] $F5/$60+: set envelope params (attack, decay, sustain rate)
musicCmd_F5_SetEnvelope: ; $00EDD3
        JSR.W musicHelper_GetVoicePtr
; [Music] Read envelope: attack rate ($0E), decay rate ($10), sustain ($12)
musicCmd_F5_ReadParams: ; $00EDD6
        PHX
        TYX
        LDA.B [$8D]
        INC.B $8D
        JSR.W musicHelper_SignExtendNegate
        STA.W $000E,X
        LDA.B [$8D]
        INC.B $8D
        JSR.W musicHelper_SignExtendNegate
        STA.W $0010,X
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        STA.W $0012,X
        STZ.W $0002,X
        STZ.W $0016,X
        LDA.W $0000,X
        ORA.W #$0200
        STA.W $0000,X
        PLX
        JMP.W $E9E9
; [Music] $F6: loop control — decrement counter $1A, repeat or advance
musicCmd_F6_Loop: ; $00EE09
        LDA.W $001A,X
        BEQ musicCmd_F6_Init
        DEC A
        STA.W $001A,X
        BNE musicCmd_F6_Continue
        INC.B $8D
        JMP.W $E9E9
; [Music] Loop counter nonzero — advance and loop back
musicCmd_F6_Continue: ; $00EE19
        INC.B $8D
        JMP.W musicPtr_Rewind
; [Music] Loop counter zero — initialize from stream byte
musicCmd_F6_Init: ; $00EE1E
        LDA.B [$8D]
        AND.W #$00FF
        INC.B $8D
        ASL A
        STA.W $001A,X
        JMP.W musicPtr_Rewind
; [Music] $A0-$AF: indirect jump table dispatch at $EE3A
musicCmd_A0_JumpTable: ; $00EE2C
        AND.W #$001F
        ASL A
        ASL A
        CLC
        ADC.W #$EE3A
        STA.B $40
        JMP.W ($0040)
        db $4C,$7A,$EE,$EA
        JMP.W $F050
        db $EA
        JMP.W $F087
        db $EA
        JMP.W $F099
        db $EA
        JMP.W $F0E3
        db $EA
        JMP.W musicCmd_FB_EndTrack
        db $EA
        JMP.W $F0F9
        db $EA
        JMP.W $F0CB
        db $EA
        JMP.W $F0EB
        db $EA
        JMP.W $F0D7
        db $EA
        JMP.W $EEEF
        db $EA
        JMP.W $EF85
        db $EA
        JMP.W $EFD8
        db $EA,$4C,$22,$F0,$EA
        JMP.W $F221
        db $EA
        JMP.W $F1DC
        db $EA
; [Music] $F8: setup voice — read params, configure channel base + target
musicCmd_F8_VoiceSetup: ; $00EE7A
        JSR.W musicStream_ReadSignedByte
        STA.B $40
        JSR.W musicStream_ReadSignedByte
        CMP.W #$FF81
        BNE CODE_80EE8F
        LDY.W #$0001
        LDA.W $0AA3
        BRA CODE_80EE95
CODE_80EE8F: ; $00EE8F
        CLC
        ADC.B $97
        LDY.W #$0000
CODE_80EE95: ; $00EE95
        STA.B $9B
        STA.B $93
        TYA
        SEP #$20
        STA.B $A6
        STZ.B $A7
        REP #$20
        LDA.B $9D
        CMP.W #$0010
        BNE CODE_80EEB5
        LDA.B $95
        CLC
        ADC.B $40
        STA.B $99
        STA.B $91
        JMP.W $E9E9
CODE_80EEB5: ; $00EEB5
        LDA.B $95
        SEC
        SBC.B $40
        STA.B $99
        STA.B $91
        JMP.W $E9E9
; [Music] $FA: channel setup — clear flags, configure base/target addresses
musicCmd_FA_ChannelSetup: ; $00EEC1
        SEP #$20
        STZ.B $A7
        REP #$20
        JSR.W musicStream_ReadSignedByte
        STA.B $40
        JSR.W musicStream_ReadSignedByte
        CLC
        ADC.B $9B
        STA.B $9B
        LDA.B $9D
        CMP.W #$0010
        BNE CODE_80EEE5
        LDA.B $99
        CLC
        ADC.B $40
        STA.B $99
        JMP.W $E9E9
CODE_80EEE5: ; $00EEE5
        LDA.B $99
        SEC
        SBC.B $40
        STA.B $99
        JMP.W $E9E9
        STZ.B $42
        LDA.W $0000,X
        AND.W #$2000
        BEQ CODE_80EF0A
        LDA.B [$8D]
        INC.B $8D
        STA.B $40
        LDA.W #$0000
        SEC
        SBC.B $40
        AND.W #$00FF
        BRA CODE_80EF1A
CODE_80EF0A: ; $00EF0A
        LDA.W #$4000
        STA.B $42
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        SEC
        SBC.W #$0010
CODE_80EF1A: ; $00EF1A
        STA.B $40
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        BNE CODE_80EF49
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        SEC
        SBC.W #$0010
        STA.W $0A95
        LDA.B $40
        STA.W $0A93
        LDA.W #$0064
        STA.W $0A91
        LDA.W #$21E8
        ORA.B $42
        STA.W $0A97
        JMP.W $E9E9
CODE_80EF49: ; $00EF49
        CMP.W #$00FF
        BNE CODE_80EF6A
        LDY.W #$0E00
        CPX.W #$1200
        BCS CODE_80EF59
        LDY.W #$0E80
CODE_80EF59: ; $00EF59
        LDA.W $0052,Y
        BNE CODE_80EF63
        INC.B $8D
        JMP.W $E9E9
CODE_80EF63: ; $00EF63
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
CODE_80EF6A: ; $00EF6A
        SEC
        SBC.W #$0010
        STA.W $0A8D
        LDA.B $40
        STA.W $0A8B
        LDA.W #$0001
        STA.W $0A89
        LDA.W #$20E8
        STA.W $0A8F
        JMP.W $E9E9
        SEP #$20
        LDA.B [$8D]
        CMP.B #$80
        BCC CODE_80EF93
        AND.B #$7F
        STA.B $5F
        BRA CODE_80EFA4
CODE_80EF93: ; $00EF93
        db $18,$69,$C0,$85,$5F,$A5,$A9,$29,$01,$F0,$06,$A5,$5F,$49,$20,$85
        db $5F
CODE_80EFA4: ; $00EFA4
        REP #$20
        INC.B $8D
        JSR.W musicStream_ReadWord
        STA.W $0DC0
        CMP.W #$FFFF
        BNE CODE_80EFCD
        db $A5,$5F,$29,$3F,$00,$0A,$DA,$AA,$BF,$00,$CF,$7F,$8D,$C1,$0D,$E2
        db $20,$AD,$C2,$0D,$8D,$C0,$0D,$C2,$20,$FA
CODE_80EFCD: ; $00EFCD
        SEP #$20
        LDA.B #$02
        STA.B $5E
        REP #$20
        JMP.W musicCmd_FB_EndTrack
        LDA.W #$0010
        STA.B $44
        JSR.W musicStream_ReadSignedByte
        SEP #$20
        CMP.B #$80
        BCC CODE_80EFEC
        AND.B #$7F
        STA.B $5F
        BRA CODE_80EFFD
CODE_80EFEC: ; $00EFEC
        db $18,$69,$C0,$85,$5F,$A5,$A9,$29,$01,$F0,$06,$A5,$5F,$49,$20,$85
        db $5F
CODE_80EFFD: ; $00EFFD
        REP #$20
        JSR.W musicStream_ReadWord
        CMP.W #$FFFF
        BEQ CODE_80F00F
        STA.B $40
        LDA.B $8F
        STA.B $42
        BRA CODE_80F02C
CODE_80F00F: ; $00F00F
        db $A5,$5F,$29,$3F,$00,$0A,$18,$69,$00,$CF,$85,$40,$A9,$7F,$00,$85
        db $42,$80,$0A,$A9,$20,$00,$85,$44,$A9,$00,$00,$80,$B4
CODE_80F02C: ; $00F02C
        LDA.B $44
        PHX
        PHY
        PHA
        LDX.W #$0000
        TAY
CODE_80F035: ; $00F035
        LDA.B [$40]
        STA.W $0DC0,X
        INC.B $40
        INC.B $40
        INX
        INX
        DEY
        BNE CODE_80F035
        PLA
        PLY
        PLX
        SEP #$20
        ASL A
        STA.B $5E
        REP #$20
        JMP.W musicCmd_FB_EndTrack
        LDA.W $001A,X
        BEQ CODE_80F06B
        DEC A
        STA.W $001A,X
        BNE CODE_80F064
        INC.B $8D
        INC.B $8D
        INC.B $8D
        JMP.W $E9E9
CODE_80F064: ; $00F064
        LDA.B [$8D]
        STA.B $8D
        JMP.W $E9E9
CODE_80F06B: ; $00F06B
        LDA.B [$8D]
        INC.B $8D
        INC.B $8D
        TAY
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        DEC A
        BNE CODE_80F07F
        db $4C,$E9,$E9
CODE_80F07F: ; $00F07F
        STA.W $001A,X
        STY.B $8D
        JMP.W $E9E9
        JSR.W musicHelper_GetVoiceSlot
        LDA.W $0000,Y
        EOR.W #$4000
        STA.W $0000,Y
        LDA.B $8D
        STA.W $0006,X
        RTS
        JSR.W musicHelper_GetVoiceSlot
        LDA.W $0000,Y
        ORA.W #$0300
        STA.W $0000,Y
        JSR.W musicStream_ReadByteThenExtend
        STA.W $000E,Y
        JSR.W musicStream_ReadByteThenExtend
        ASL A
        STA.W $0010,Y
        JSR.W musicStream_ReadByteThenExtend
        STA.W $0012,Y
        JSR.W musicStream_ReadByteThenExtend
        STA.W $0014,Y
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        STA.W $001A,Y
        JMP.W $E9E9
        JSR.W musicStream_ReadSignedByte
        SEP #$20
        STA.B $68
        REP #$20
        JMP.W $E9E9
        JSR.W musicStream_ReadSignedByte
        SEP #$20
        STA.B $69
        REP #$20
        JMP.W $E9E9
        JSR.W musicStream_ReadSignedByte
        STA.B $60
        JMP.W $E9E9
        JSR.W musicStream_ReadSignedByte
        STA.B $62
        JMP.W $E9E9
; [Music] $FB: end track — store final pointer, RTS
musicCmd_FB_EndTrack: ; $00F0F3
        LDA.B $8D
        STA.W $0006,X
        RTS
        PHX
        JSR.W musicStream_ReadSignedByte
        JSR.W musicDSP_LoadEffectTable
        PLX
        JMP.W $E9E9
; [Music] Load DSP effect parameters from table. A=effect index, looks up from $0D8004.
musicDSP_LoadEffectTable: ; $00F104
        ASL A
        TAX
        LDA.L $0D8004,X
        PHA
        LDA.W #$0000
        STA.B $42
        LDA.W #$E42A
        STA.B $40
        LDX.W #$11E0
        JSR.W buildObjectEntry
        LDA.W #$8F00
        STA.W $000C,X
        PLA
        STA.W $0006,X
        RTS
; [Music] $E4: return from music subroutine. Reads return address, dispatches based on value.
musicCmd_E4_Return: ; $00F126
        JSR.W musicStream_ReadWord
        CMP.W #$8000
        BCS musicCmd_E4_Special
        CLC
        ADC.W $0A9B
        STA.B $A8
        JMP.W $E9E9
; [Music] Return value >= $8000 — special dispatch (not normal return)
musicCmd_E4_Special: ; $00F137
        INC A
        BEQ musicCmd_E4_Special3
        INC A
        BEQ musicCmd_E4_Normal
        CPX.W #$1200
        BCC musicCmd_E4_Special2
        db $49,$01,$00
; [Music] Return value == $FFFF — alternate special return
musicCmd_E4_Special2: ; $00F145
        AND.W #$0001
        BNE musicCmd_E4_Normal
; [Music] Return value == $FFFE — third special return type
musicCmd_E4_Special3: ; $00F14A
        LDA.W $0A9B
        EOR.W #$1000
        STA.W $0A9B
        JMP.W $E9E9
; [Music] Normal return: add base $0A9B to offset, set as new music ptr
musicCmd_E4_Normal: ; $00F156
        LDA.W $0A9D
        EOR.W #$1000
        STA.W $0A9D
        JMP.W $E9E9
; [Music] $E5: clear loop flags (high nibble of +$01) and return to main loop
musicCmd_E5_LoopBack: ; $00F162
        JSR.W musicHelper_GetVoiceSlot
        SEP #$20
        LDA.W $0001,Y
        AND.B #$F0
        STA.W $0001,Y
        REP #$20
        JMP.W $E9E9
; [Music] Read voice parameter byte from stream. $FF triggers smoke effect; $29 is special; else used as voice index.
musicStream_ReadVoiceParam: ; $00F174
        LDA.B [$8D]
        AND.W #$00FF
        INC.B $8D
        CMP.W #$00FF
        BNE musicStream_ReadVoiceParam_Check29
        LDA.W #$0064
        JSL.L hardwareMultiplyRng
        BRA musicStream_ReadVoiceParam_Done
; [Music] Check if param == $29 (special voice)
musicStream_ReadVoiceParam_Check29: ; $00F189
        CMP.W #$0029
        BEQ CODE_80F1C9
        TAY
        CPY.W #$0028
        BNE musicStream_ReadVoiceParam_Normal
        LDA.L $7EEA88
        AND.W #$0004
        BRA musicStream_ReadVoiceParam_Done
; [Music] Normal voice param: compute voice table offset
musicStream_ReadVoiceParam_Normal: ; $00F19D
        LDA.W $0000,X
        AND.W #$2000
        BEQ musicStream_ReadVoiceParam_Offset
        TYA
        CLC
        ADC.W #$0080
        TAY
; [Music] Compute final voice offset from param
musicStream_ReadVoiceParam_Offset: ; $00F1AB
        LDA.W $0E00,Y
        AND.W #$00FF
; [Music] Voice param resolved, return Y=voice ptr
musicStream_ReadVoiceParam_Done: ; $00F1B1
        PHA
        LDA.B [$8D]
        AND.W #$00FF
        INC.B $8D
        STA.B $40
        JSR.W musicStream_ReadWord
        TAY
        PLA
        CMP.B $40
        BCC CODE_80F1C6
        STY.B $8D
CODE_80F1C6: ; $00F1C6
        JMP.W $E9E9
CODE_80F1C9: ; $00F1C9
        LDA.W #$0000
        CPX.W #$1200
        BCC musicStream_ReadVoiceParam_Done
        db $1A,$80,$DD
; [Music] Rewind music data pointer by 2 (DEC DEC), store to +$06. Used for loop-back.
musicPtr_Rewind: ; $00F1D4
        LDA.B $8D
        DEC A
        DEC A
        STA.W $0006,X
        RTS
        JSR.W musicHelper_GetVoiceSlot
        PHX
        TYX
        LDA.W $0004,X
        CMP.W #$00C8
        BEQ CODE_80F21D
        BCS CODE_80F1FB
        db $85,$40,$A9,$C8,$00,$38,$E5,$40,$9D,$12,$00,$A9,$00,$01,$80,$0A
CODE_80F1FB: ; $00F1FB
        SEC
        SBC.W #$00C8
        STA.W $0012,X
        LDA.W #$FF00
        STA.W $000E,X
        LDA.W #$0000
        STA.W $0010,X
        STZ.W $0002,X
        STZ.W $0016,X
        LDA.W $0000,X
        ORA.W #$0200
        STA.W $0000,X
CODE_80F21D: ; $00F21D
        PLX
        JMP.W $E9E9
        JSR.W musicStream_ReadWord
        CMP.W #$FFFF
        BNE CODE_80F231
        LDA.W $0A99
        STA.B $8D
        JMP.W musicCmd_FB_EndTrack
CODE_80F231: ; $00F231
        STA.B $40
        PHY
        LDY.W #$0200
        LDA.W $0000,X
        AND.W #$2000
        BEQ CODE_80F242
        db $A0,$00,$00
CODE_80F242: ; $00F242
        LDA.W $1006,Y
        STA.W $0A99
        LDA.B $40
        STA.W $1006,Y
        PLY
        JMP.W $E9E9
; [Music] $E6: conditional flag. $FFFF toggles $0AA5; else stores to $0AA7/$0AAD.
musicCmd_E6_CondFlag: ; $00F251
        JSR.W musicStream_ReadWord
        CMP.W #$FFFF
        BNE musicCmd_E6_StoreFlag
        LDA.W $0AA5
        EOR.W #$0001
        STA.W $0AA5
        JMP.W $E9E9
; [Music] Store conditional flag value
musicCmd_E6_StoreFlag: ; $00F265
        STA.W $0AA7
        STA.W $0AAD
        JMP.W $E9E9
; [Music] $E7: read byte, if nonzero compute screen brightness/fade from $99. Sets $6B/$6D.
musicCmd_E7_SetReg: ; $00F26E
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        STA.B $40
        BNE musicCmd_E7_CalcBrightness
        STZ.B $6B
        STZ.B $6D
        JMP.W $E9E9
; [Music] Compute brightness: $100 - $99, store to display vars
musicCmd_E7_CalcBrightness: ; $00F280
        LDA.W #$0100
        SEC
        SBC.B $99
        AND.W #$01FF
        STA.B $6B
        LDA.W #$0000
        SEC
        SBC.B $9B
        AND.W #$01FF
        STA.B $6D
        LDA.W $0000,X
        AND.W #$4000
        BEQ CODE_80F2A5
        db $A5,$6B,$18,$65,$40,$85,$6B
CODE_80F2A5: ; $00F2A5
        JMP.W $E9E9
; [Music] $E8: read two words, store to $0AA7 (mask) and $0AAD (compare value). $8F to $0AAF.
musicCmd_E8_Compare: ; $00F2A8
        JSR.W musicStream_ReadWord
        ORA.W #$FC00
        STA.W $0AA7
        JSR.W musicStream_ReadWord
        STA.W $0AAD
        LDA.B $8F
        STA.W $0AAF
        JMP.W $E9E9
; [Music] $E9: read byte from stream, store to +$0D as branch offset
musicCmd_E9_BranchByte: ; $00F2BF
        SEP #$20
        LDA.B [$8D]
        STA.W $000D,X
        REP #$20
        INC.B $8D
        JMP.W $E9E9
; [Music] $EA: if $0AA7 flag nonzero, rewind ptr (loop); else skip
musicCmd_EA_CondJump: ; $00F2CD
        LDA.W $0AA7
        BEQ musicCmd_EA_Skip
        JMP.W musicPtr_Rewind
; [Music] Flag zero — skip to main loop
musicCmd_EA_Skip: ; $00F2D5
        JMP.W $E9E9
; [Music] $EB: read byte from stream, store to $81 as timer/counter value
musicCmd_EB_SetTimer: ; $00F2D8
        SEP #$20
        LDA.B [$8D]
        STA.B $81
        REP #$20
        INC.B $8D
        JMP.W $E9E9
; [Music] Read byte from music stream [$8D], sign-extend if >= $80. Returns signed 16-bit in A.
musicStream_ReadSignedByte: ; $00F2E5
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        CMP.W #$0080
        BCC musicStream_ReadSignedByte_Done
        ORA.W #$FF00
; [Music] Return path for signed byte read
musicStream_ReadSignedByte_Done: ; $00F2F4
        RTS
; [Music] Read 16-bit word from music stream [$8D]. Advances pointer by 2.
musicStream_ReadWord: ; $00F2F5
        LDA.B [$8D]
        INC.B $8D
        INC.B $8D
        RTS
; [Music] Read byte from stream, fall through to sign-extend/negate helper
musicStream_ReadByteThenExtend: ; $00F2FC
        LDA.B [$8D]
        INC.B $8D
; [Music] Sign-extend and negate byte: if >= $80, invert and ASL*4; else pass through. For pitch/volume deltas.
musicHelper_SignExtendNegate: ; $00F300
        AND.W #$00FF
        CMP.W #$0080
        BCC musicHelper_SignExtendNegate_Pos
        DEC A
        EOR.W #$00FF
        AND.W #$00FF
        ASL A
        ASL A
        ASL A
        ASL A
        DEC A
        EOR.W #$FFFF
        RTS
; [Music] Positive path: just ASL*4
musicHelper_SignExtendNegate_Pos: ; $00F318
        ASL A
        ASL A
        ASL A
        ASL A
        RTS
; [Music] Extract channel index from A low nibble. If $0E, read extra param via $F374.
musicHelper_GetChannelIndex: ; $00F31D
        REP #$20
        AND.W #$000F
        CMP.W #$000E
        BNE musicHelper_GetVoicePtr
        JSR.W musicHelper_GetVoiceSlot
        RTS
; [Music] Get voice table pointer in Y ($1000 or $1200) from channel index. Checks bit13 of entity flags.
musicHelper_GetVoicePtr: ; $00F32B
        REP #$20
        AND.W #$000F
        STA.B $40
        LDY.W #$1000
        LDA.W $0000,X
        AND.W #$2000
        BEQ musicHelper_GetVoicePtr_Select
        LDY.W #$1200
; [Music] Select voice table offset based on channel
musicHelper_GetVoicePtr_Select: ; $00F340
        LDA.B $40
        CMP.W #$000F
        BNE CODE_80F34C
        TXY
        LDA.W #$000E
        RTS
CODE_80F34C: ; $00F34C
        CMP.W #$000E
        BEQ CODE_80F360
        PHA
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        STA.B $40
        TYA
        CLC
        ADC.B $40
        TAY
        PLA
        RTS
CODE_80F360: ; $00F360
        db $64,$40,$B9,$00,$00,$F0,$0A,$98,$18,$69,$20,$00,$A8,$E6,$40,$80
        db $F1,$A5,$40,$60
; [Music] Get voice slot pointer in Y from $000D,X channel field. Computes Y = (field & 0xF) * 32 + $1000.
musicHelper_GetVoiceSlot: ; $00F374
        REP #$20
        LDA.W $000D,X
        AND.W #$000F
        PHA
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        CLC
        ADC.W #$1000
        TAY
        LDA.W $0000,X
        AND.W #$2000
        BEQ CODE_80F395
        TYA
        CLC
        ADC.W #$0200
        TAY
CODE_80F395: ; $00F395
        PLA
        RTS
; [Music] Write value ($40) to SPC voice register. Handles timing sync with A6/A7 flags.
musicHelper_WriteSPCRegister: ; $00F397
        REP #$20
        STA.B $40
        SEP #$20
        INC.B $A7
        LDA.B $A6
        BEQ CODE_80F3A6
        JMP.W $F40F
CODE_80F3A6: ; $00F3A6
        LDA.W $0001,X
        AND.B #$20
        EOR.B $A5
        BEQ CODE_80F3C3
        LDA.B $99
        SEC
        SBC.B $60
        STA.B ($3A)
        INC.B $3A
        LDA.B $9B
        SEC
        SBC.B $62
        STA.B ($3A)
        INC.B $3A
        BRA CODE_80F3CF
CODE_80F3C3: ; $00F3C3
        LDA.B $99
        STA.B ($3A)
        INC.B $3A
        LDA.B $9B
        STA.B ($3A)
        INC.B $3A
CODE_80F3CF: ; $00F3CF
        REP #$20
        LDA.B $9A
        LSR A
        ROR.B $9F
        LDA.B $40
        AND.W #$3000
        CMP.W #$1000
        ROR.B $9F
        BCC CODE_80F3EF
        LDA.B $9F
        STA.B ($3C)
        LDA.W #$8000
        STA.B $9F
        INC.B $3C
        INC.B $3C
CODE_80F3EF: ; $00F3EF
        LDA.B $9D
        CMP.W #$0010
        BNE CODE_80F401
        LDA.B $40
        ORA.B $A8
        STA.B ($3A)
        INC.B $3A
        INC.B $3A
        RTS
CODE_80F401: ; $00F401
        LDA.B $40
        ORA.B $A8
        EOR.W #$4000
        STA.B ($3A)
        INC.B $3A
        INC.B $3A
        RTS
        SEP #$20
        LDA.W $0001,X
        AND.B #$20
        EOR.B $A5
        BEQ CODE_80F42E
        LDA.B $99
        SEC
        SBC.B $60
        STA.B ($3E)
        INC.B $3E
        LDA.B $9B
        SEC
        SBC.B $62
        STA.B ($3E)
        INC.B $3E
        BRA CODE_80F43A
CODE_80F42E: ; $00F42E
        LDA.B $99
        STA.B ($3E)
        INC.B $3E
        LDA.B $9B
        STA.B ($3E)
        INC.B $3E
CODE_80F43A: ; $00F43A
        REP #$20
        LDA.B $9D
        CMP.W #$0010
        BNE CODE_80F44E
        LDA.B $40
        ORA.B $A8
        STA.B ($3E)
        INC.B $3E
        INC.B $3E
        RTS
CODE_80F44E: ; $00F44E
        LDA.B $40
        ORA.B $A8
        EOR.W #$4000
        STA.B ($3E)
        INC.B $3E
        INC.B $3E
        RTS
; [Music] Set voice target position/pitch. Stores A to +$02, Y to +$16, compares target to +$18 for interpolation.
musicVoice_SetTarget: ; $00F45C
        REP #$20
        STA.W $0002,X
        STA.B $40
        TYA
        STA.W $0016,X
        STA.B $42
        LDA.W $0018,X
        STA.B $44
        LDA.B $42
        CMP.B $44
        BCS CODE_80F480
        LDA.B $44
        SEC
        SBC.B $42
        STA.B $46
        ORA.W #$8000
        BRA CODE_80F485
CODE_80F480: ; $00F480
        SEC
        SBC.B $44
        STA.B $46
CODE_80F485: ; $00F485
        STA.W $0010,X
        LDA.W $0004,X
        STA.B $44
        LDA.B $40
        CMP.B $44
        BCS CODE_80F49F
        LDA.B $44
        SEC
        SBC.B $40
        STA.B $48
        ORA.W #$8000
        BRA CODE_80F4A4
CODE_80F49F: ; $00F49F
        SEC
        SBC.B $44
        STA.B $48
CODE_80F4A4: ; $00F4A4
        STA.W $000E,X
        SEP #$20
        STZ.B $45
        STZ.B $47
        REP #$20
        LDA.B $46
        CLC
        ADC.B $48
        AND.W #$01FE
        TAY
        LDA.W $F9CB,Y
        STA.W $0012,X
        LDA.W $0000,X
        ORA.W #$0100
        STA.W $0000,X
        STZ.W $0014,X
        RTS
        db $01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,$10
        db $11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F,$20
        db $21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F,$30
        db $31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F,$40
        db $41,$42,$43,$44,$45,$46,$47,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F,$50
        db $51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$5B,$5C,$5D,$5E,$5F,$60
        db $61,$62,$63,$64,$65,$66,$67,$68,$69,$6A,$6B,$6C,$6D,$6E,$6F,$70
        db $71,$72,$73,$74,$75,$76,$77,$78,$79,$7A,$7B,$7C,$7D,$7E,$7F,$80
        db $80,$81,$82,$83,$84,$85,$86,$87,$88,$89,$8A,$8B,$8C,$8D,$8E,$8F
        db $90,$91,$92,$93,$94,$95,$96,$97,$98,$99,$9A,$9B,$9C,$9D,$9E,$9F
        db $A0,$A1,$A2,$A3,$A4,$A5,$A6,$A7,$A8,$A9,$AA,$AB,$AC,$AD,$AE,$AF
        db $B0,$B1,$B2,$B3,$B4,$B5,$B6,$B7,$B8,$B9,$BA,$BB,$BC,$BD,$BE,$BF
        db $C0,$C1,$C2,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CA,$CB,$CC,$CD,$CE,$CF
        db $D0,$D1,$D2,$D3,$D4,$D5,$D6,$D7,$D8,$D9,$DA,$DB,$DC,$DD,$DE,$DF
        db $E0,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF
        db $F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01
        db $01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$03,$03
        db $03,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$05,$06,$06,$06,$06
        db $07,$07,$07,$08,$08,$08,$09,$09,$09,$0A,$0A,$0B,$0B,$0B,$0C,$0C
        db $0D,$0D,$0E,$0E,$0F,$0F,$10,$10,$11,$11,$12,$12,$13,$14,$14,$15
        db $15,$16,$17,$17,$18,$19,$19,$1A,$1B,$1C,$1C,$1D,$1E,$1F,$1F,$20
        db $21,$22,$23,$24,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F
        db $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3B,$3C,$3D,$3E,$3F,$40
        db $42,$43,$44,$45,$47,$48,$49,$4A,$4C,$4D,$4E,$50,$51,$52,$54,$55
        db $57,$58,$59,$5B,$5C,$5E,$5F,$61,$62,$64,$65,$67,$68,$6A,$6B,$6D
        db $6E,$70,$72,$73,$75,$76,$78,$7A,$7B,$7D,$7F,$80,$82,$84,$85,$87
        db $89,$8A,$8C,$8E,$90,$91,$93,$95,$97,$98,$9A,$9C,$9E,$A0,$A1,$A3
        db $A5,$A7,$A9,$AB,$AC,$AE,$B0,$B2,$B4,$B6,$B8,$BA,$BB,$BD,$BF,$C1
        db $C3,$C5,$C7,$C9,$CB,$CD,$CF,$D1,$D3,$D4,$D6,$D8,$DA,$DC,$DE,$E0
        db $E2,$E4,$E6,$E8,$EA,$EC,$EE,$F0,$F2,$F4,$F6,$F8,$FA,$FC,$FE,$FF
        db $02,$04,$06,$08,$0A,$0C,$0E,$10,$12,$14,$16,$18,$1A,$1C,$1D,$1F
        db $21,$23,$25,$27,$29,$2B,$2D,$2F,$31,$33,$35,$37,$39,$3B,$3D,$3E
        db $40,$42,$44,$46,$48,$4A,$4C,$4E,$4F,$51,$53,$55,$57,$59,$5B,$5C
        db $5E,$60,$62,$64,$65,$67,$69,$6B,$6D,$6E,$70,$72,$74,$75,$77,$79
        db $7A,$7C,$7E,$7F,$81,$83,$84,$86,$88,$89,$8B,$8C,$8E,$90,$91,$93
        db $94,$96,$97,$99,$9A,$9C,$9D,$9F,$A0,$A2,$A3,$A5,$A6,$A8,$A9,$AA
        db $AC,$AD,$AF,$B0,$B1,$B3,$B4,$B5,$B6,$B8,$B9,$BA,$BB,$BD,$BE,$BF
        db $C0,$C2,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CB,$CC,$CD,$CE,$CF,$D0,$D1
        db $D2,$D3,$D4,$D5,$D6,$D7,$D8,$D8,$D9,$DA,$DB,$DC,$DD,$DE,$DF,$DF
        db $E0,$E1,$E2,$E3,$E3,$E4,$E5,$E5,$E6,$E7,$E8,$E8,$E9,$EA,$EA,$EB
        db $EB,$EC,$ED,$ED,$EE,$EE,$EF,$EF,$F0,$F0,$F1,$F1,$F2,$F2,$F3,$F3
        db $F4,$F4,$F5,$F5,$F5,$F6,$F6,$F7,$F7,$F7,$F8,$F8,$F8,$F9,$F9,$F9
        db $FA,$FA,$FA,$FA,$FB,$FB,$FB,$FB,$FC,$FC,$FC,$FC,$FC,$FD,$FD,$FD
        db $FD,$FD,$FD,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FF,$FF,$FF,$FF
        db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01
        db $02,$02,$02,$03,$03,$04,$04,$05,$05,$06,$07,$07,$08,$09,$0A,$0B
        db $0C,$0D,$0E,$0F,$10,$11,$12,$13,$14,$15,$16,$17,$19,$1A,$1B,$1C
        db $1E,$1F,$20,$21,$23,$24,$25,$26,$27,$29,$2A,$2B,$2C,$2E,$2F,$30
        db $31,$33,$34,$35,$36,$37,$39,$3A,$3B,$3C,$3E,$3F,$40,$41,$43,$44
        db $45,$46,$48,$49,$4A,$4B,$4C,$4E,$4F,$50,$51,$53,$54,$55,$56,$58
        db $59,$5A,$5B,$5D,$5E,$5F,$60,$61,$63,$64,$65,$66,$68,$69,$6A,$6B
        db $6D,$6E,$6F,$70,$72,$73,$74,$75,$76,$78,$79,$7A,$7B,$7D,$7E,$7F
        db $80,$82,$83,$84,$85,$86,$88,$89,$8A,$8B,$8D,$8E,$8F,$90,$92,$93
        db $94,$95,$97,$98,$99,$9A,$9B,$9D,$9E,$9F,$A0,$A2,$A3,$A4,$A5,$A7
        db $A8,$A9,$AA,$AC,$AD,$AE,$AF,$B0,$B2,$B3,$B4,$B5,$B7,$B8,$B9,$BA
        db $BC,$BD,$BE,$BF,$C1,$C2,$C3,$C4,$C5,$C7,$C8,$C9,$CA,$CC,$CD,$CE
        db $CF,$D1,$D2,$D3,$D4,$D5,$D7,$D8,$D9,$DA,$DC,$DD,$DE,$DF,$E1,$E2
        db $E3,$E4,$E6,$E7,$E8,$E9,$EA,$EB,$ED,$EE,$EF,$F0,$F1,$F2,$F3,$F4
        db $F5,$F6,$F6,$F7,$F8,$F9,$F9,$FA,$FB,$FB,$FC,$FC,$FD,$FD,$FD,$FE
        db $FE,$FE,$FE,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db $02,$04,$06,$08,$0A,$0C,$0E,$10,$12,$14,$15,$17,$19,$1B,$1D,$1F
        db $20,$22,$23,$25,$27,$28,$29,$2B,$2C,$2D,$2E,$30,$31,$32,$33,$33
        db $34,$35,$36,$36,$37,$37,$38,$38,$39,$39,$39,$39,$3A,$3A,$3A,$3A
        db $3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3B,$3B
        db $3B,$3B,$3B,$3C,$3C,$3C,$3D,$3D,$3E,$3F,$3F,$40,$41,$42,$43,$44
        db $45,$46,$47,$48,$49,$4B,$4C,$4E,$4F,$51,$52,$54,$56,$57,$59,$5B
        db $5D,$5F,$60,$62,$64,$66,$68,$6A,$6C,$6E,$70,$72,$74,$76,$78,$7A
        db $7C,$7D,$7F,$81,$83,$84,$86,$87,$89,$8A,$8C,$8D,$8F,$90,$91,$92
        db $93,$94,$95,$96,$97,$97,$98,$99,$99,$9A,$9A,$9B,$9B,$9B,$9C,$9C
        db $9C,$9C,$9C,$9C,$9D,$9D,$9D,$9D,$9D,$9D,$9D,$9D,$9D,$9D,$9D,$9D
        db $9D,$9D,$9D,$9D,$9D,$9E,$9E,$9E,$9F,$9F,$9F,$A0,$A0,$A1,$A2,$A2
        db $A3,$A4,$A5,$A6,$A7,$A8,$A9,$AA,$AC,$AD,$AE,$B0,$B1,$B3,$B5,$B6
        db $B8,$BA,$BB,$BD,$BF,$C1,$C3,$C5,$C7,$C9,$CB,$CD,$CF,$D1,$D2,$D4
        db $D6,$D8,$DA,$DC,$DE,$E0,$E2,$E3,$E5,$E7,$E8,$EA,$EB,$ED,$EE,$F0
        db $F1,$F2,$F3,$F4,$F6,$F7,$F7,$F8,$F9,$FA,$FB,$FB,$FC,$FC,$FD,$FD
        db $FE,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        db $FF,$FF,$FF,$FF,$FF,$7F,$55,$55,$FF,$3F,$33,$33,$AA,$2A,$92,$24
        db $FF,$1F,$71,$1C,$99,$19,$45,$17,$55,$15,$B1,$13,$49,$12,$11,$11
        db $FF,$0F,$0F,$0F,$38,$0E,$79,$0D,$CC,$0C,$30,$0C,$A2,$0B,$21,$0B
        db $AA,$0A,$3D,$0A,$D8,$09,$7B,$09,$24,$09,$D3,$08,$88,$08,$42,$08
        db $FF,$07,$C1,$07,$87,$07,$50,$07,$1C,$07,$EB,$06,$BC,$06,$90,$06
        db $66,$06,$3E,$06,$18,$06,$F4,$05,$D1,$05,$B0,$05,$90,$05,$72,$05
        db $55,$05,$39,$05,$1E,$05,$05,$05,$EC,$04,$D4,$04,$BD,$04,$A7,$04
        db $92,$04,$7D,$04,$69,$04,$56,$04,$44,$04,$32,$04,$21,$04,$10,$04
        db $FF,$03,$F0,$03,$E0,$03,$D2,$03,$C3,$03,$B5,$03,$A8,$03,$9B,$03
        db $8E,$03,$81,$03,$75,$03,$69,$03,$5E,$03,$53,$03,$48,$03,$3D,$03
        db $33,$03,$29,$03,$1F,$03,$15,$03,$0C,$03,$03,$03,$FA,$02,$F1,$02
        db $E8,$02,$E0,$02,$D8,$02,$D0,$02,$C8,$02,$C0,$02,$B9,$02,$B1,$02
        db $AA,$02,$A3,$02,$9C,$02,$95,$02,$8F,$02,$88,$02,$82,$02,$7C,$02
        db $76,$02,$70,$02,$6A,$02,$64,$02,$5E,$02,$59,$02,$53,$02,$4E,$02
        db $49,$02,$43,$02,$3E,$02,$39,$02,$34,$02,$30,$02,$2B,$02,$26,$02
        db $22,$02,$1D,$02,$19,$02,$14,$02,$10,$02,$0C,$02,$08,$02,$04,$02
        db $FF,$01,$FC,$01,$F8,$01,$F4,$01,$F0,$01,$EC,$01,$E9,$01,$E5,$01
        db $E1,$01,$DE,$01,$DA,$01,$D7,$01,$D4,$01,$D0,$01,$CD,$01,$CA,$01
        db $C7,$01,$C3,$01,$C0,$01,$BD,$01,$BA,$01,$B7,$01,$B4,$01,$B2,$01
        db $AF,$01,$AC,$01,$A9,$01,$A6,$01,$A4,$01,$A1,$01,$9E,$01,$9C,$01
        db $99,$01,$97,$01,$94,$01,$92,$01,$8F,$01,$8D,$01,$8A,$01,$88,$01
        db $86,$01,$83,$01,$81,$01,$7F,$01,$7D,$01,$7A,$01,$78,$01,$76,$01
        db $74,$01,$72,$01,$70,$01,$6E,$01,$6C,$01,$6A,$01,$68,$01,$66,$01
        db $64,$01,$62,$01,$60,$01,$5E,$01,$5C,$01,$5A,$01,$58,$01,$57,$01
        db $55,$01,$53,$01,$51,$01,$50,$01,$4E,$01,$4C,$01,$4A,$01,$49,$01
        db $47,$01,$46,$01,$44,$01,$42,$01,$41,$01,$3F,$01,$3E,$01,$3C,$01
        db $3B,$01,$39,$01,$38,$01,$36,$01,$35,$01,$33,$01,$32,$01,$30,$01
        db $2F,$01,$2E,$01,$2C,$01,$2B,$01,$29,$01,$28,$01,$27,$01,$25,$01
        db $24,$01,$23,$01,$21,$01,$20,$01,$1F,$01,$1E,$01,$1C,$01,$1B,$01
        db $1A,$01,$19,$01,$18,$01,$16,$01,$15,$01,$14,$01,$13,$01,$12,$01
        db $11,$01,$0F,$01,$0E,$01,$0D,$01,$0C,$01,$0B,$01,$0A,$01,$09,$01
        db $08,$01,$07,$01,$06,$01,$05,$01,$04,$01,$03,$01,$02,$01,$01,$01
        db $03,$01,$02,$01,$01,$01,$34,$33,$35,$82,$35,$D1,$35,$21,$36,$71
        db $36,$C2,$36,$13,$37,$65,$37,$B7,$37,$0A,$38,$5D,$38,$B0,$38,$04
        db $39,$59,$39,$AE,$39,$04,$3A,$5A,$3A,$B0,$3A,$07,$3B,$5F,$3B,$B7
        db $3B,$0F,$3C,$68,$3C,$C2,$3C,$1C,$3D,$77,$3D,$D2,$3D,$2E,$3E,$8A
        db $3E,$E7,$3E,$44,$3F,$A2,$3F,$7F,$55,$9D,$9F,$24,$54,$5F,$6B,$6C
        db $30,$44,$67,$C1,$0D,$A1,$F5,$34,$79,$3D,$FD,$7E,$50,$22,$5E,$56
        db $BC,$DF,$47,$C4,$95,$56,$75,$EE,$79,$13,$1D,$75,$0C,$76,$55,$C5
        db $13,$9D,$56,$E7,$FA,$EE,$05,$55,$D1,$7C,$77,$D7,$65,$CC,$E4,$57
        db $7C,$C2,$53,$95,$62,$D3,$5D,$E4,$77,$CF,$6C,$F7,$42,$5E,$B0,$55
        db $82,$1D,$EE,$65,$D0,$E7,$76,$9D,$81,$95,$6D,$6F,$A1,$F7,$27,$EC
        db $E3,$B9,$66,$FF,$CD,$4C,$D4,$85,$AE,$56,$7D,$75,$57,$47,$D5,$1F
        db $DF,$A5,$DB,$58,$52,$75,$7E,$51,$F0,$04,$59,$41,$77,$0C,$6C,$53
        db $5C,$43,$1A,$34,$64,$58,$77,$36,$75,$83,$1C,$E6,$51,$70,$39,$1F
        db $78,$EE,$D1,$66,$A8,$05,$E4,$04,$5A,$14,$D6,$5C,$CC,$E2,$CC,$20
        db $E3,$40,$05,$55,$52,$82,$F3,$29,$44,$56,$D7,$80,$4F,$4B,$47,$D0
        db $C0,$F4,$F5,$61,$8C,$C2,$94,$0C,$71,$80,$5D,$F4,$C2,$1B,$CB,$C1
        db $72,$2D,$08,$70,$19,$D5,$03,$11,$A4,$E4,$61,$54,$A4,$15,$44,$FD
        db $CF,$A4,$40,$A3,$E1,$24,$42,$26,$90,$16,$7D,$57,$A3,$05,$61,$04
        db $06,$84,$24,$00,$27,$07,$47,$34,$AF,$25,$56,$47,$44,$8C,$5C,$B9
        db $40,$94,$6C,$3C,$E3,$B6,$F3,$83,$DA,$99,$77,$01,$10,$2D,$AF,$A4
        db $8C,$94,$1C,$75,$69,$C6,$E7,$43,$1B,$24,$DA,$F5,$46,$79,$6F,$C3
        db $9B,$69,$0C,$3F,$4B,$68,$4B,$04,$1E,$FA,$47,$2C,$15,$79,$EC,$C6
        db $9A,$5D,$C4,$57,$68,$57,$5F,$6F,$71,$74,$E4,$8F,$0D,$77,$75,$44
        db $7F,$E9,$55,$15,$5E,$46,$D0,$07,$9F,$16,$B5,$B6,$BE,$9D,$DB,$5D
        db $93,$52,$B0,$5C,$1B,$4A,$FB,$17,$16,$60,$11,$CD,$1A,$B6,$0E,$91
        db $C4,$DF,$B7,$52,$57,$4F,$37,$E7,$84,$3E,$F6,$35,$34,$5A,$79,$AB
        db $A0,$B5,$07,$8C,$A7,$17,$35,$55,$4F,$5D,$75,$5E,$D4,$07,$43,$5D
        db $5F,$FB,$D7,$51,$1D,$41,$5A,$9C,$A6,$23,$9C,$CF,$B6,$12,$57,$D1
        db $17,$52,$65,$F6,$9A,$1A,$AE,$11,$A5,$55,$86,$3F,$6E,$94,$53,$46
        db $4B,$95,$FE,$4B,$8E,$00,$6C,$AD,$E6,$74,$0B,$15,$6D,$1C,$B6,$38
        db $E2,$C7,$A1,$84,$20,$11,$4B,$15,$CA,$C1,$D3,$85,$24,$91,$54,$44
        db $80,$F7,$C0,$46,$44,$E3,$A1,$C8,$A1,$76,$71,$94,$86,$45,$A0,$22
        db $DB,$51,$82,$60,$E6,$D1,$7D,$44,$16,$00,$DE,$40,$16,$98,$45,$31
        db $82,$1D,$5C,$50,$34,$C0,$0B,$D4,$14,$86,$0E,$01,$22,$C4,$52,$14
        db $57,$73,$53,$00,$8C,$30,$12,$18,$3D,$F5,$91,$9B,$C3,$C7,$54,$03
        db $72,$4E,$74,$55,$3B,$BE,$70,$F5,$76,$41,$FF,$56,$E6,$A0,$F1,$81
        db $53,$10,$76,$16,$DE,$F1,$40,$7D,$54,$25,$B7,$27,$35,$C6,$ED,$51
        db $6F,$15,$54,$77,$CC,$B3,$57,$67,$19,$7E,$1D,$64,$7C,$7F,$3C,$45
        db $4C,$79,$47,$60,$F7,$37,$47,$C7,$F1,$F5,$F4,$56,$1B,$BC,$6F,$1C
        db $0D,$D8,$0A,$7D,$74,$54,$9D,$34,$88,$5F,$DD,$13,$DD,$57,$5D,$F9
        db $35,$45,$05,$B7,$99,$56,$45,$11,$51,$22,$31,$51,$7F,$BD,$77,$D9
        db $54,$3F,$BF,$DE,$D9,$D0,$47,$54,$AD,$77,$5F,$E7,$67,$70,$F5,$2D
        db $E4,$47,$A1,$BD,$5C,$66,$0F,$6C,$21,$46,$1D,$1D,$FD,$5D,$57,$17
        db $8D,$65,$E7,$E7,$64,$79,$5E,$06,$E8,$28,$03,$64,$36,$21,$C5,$54
        db $07,$80,$D9,$0C,$D7,$F6,$D5,$71,$60,$45,$03,$C8,$4A,$44,$7B,$44
        db $BC,$6A,$20,$05,$CB,$D1,$C4,$43,$A4,$45,$AD,$15,$4A,$C6,$B3,$D5
        db $D4,$CA,$3E,$51,$67,$F7,$A1,$D5,$42,$31,$12,$E4,$C8,$50,$40,$A0
        db $84,$29,$AE,$30,$F5,$6F,$FD,$1D,$15,$54,$45,$5D,$8D,$79,$28,$9C
        db $AD,$55,$05,$11,$CE,$45,$AC,$7F,$0C,$05,$85,$E7,$30,$E0,$E0,$34
        db $A6,$24,$D8,$63,$44,$C4,$5C,$57,$F9,$14,$AF,$14,$4B,$86,$5C,$C0
        db $54,$47,$E1,$A5,$EB,$56,$05,$07,$D3,$C3,$97,$54,$85,$51,$BC,$F1
        db $84,$4B,$19,$06,$8E,$B4,$62,$15,$D7,$3F,$C5,$35,$57,$BD,$91,$BF
        db $5F,$56,$55,$5B,$53,$12,$34,$56,$01,$7C,$CD,$6C,$5D,$B7,$C4,$16
        db $73,$69,$35,$6D,$2D,$7D,$67,$96,$55,$85,$78,$F1,$74,$74,$BE,$55
        db $13,$FC,$1D,$F6,$54,$11,$D1,$73,$95,$04,$27,$40,$35,$69,$D7,$60
        db $D0,$76,$71,$55,$B4,$D2,$D0,$CE,$77,$41,$5F,$7E,$97,$9B,$20,$C7
        db $5D,$D8,$64,$91,$56,$54,$27,$F5,$F3,$2E,$0C,$7C,$15,$5E,$13,$17
        db $2F,$B3,$59,$E5,$FA,$D7,$55,$D4,$53,$C5,$09,$B9,$59,$5F,$53,$6F
        db $C5,$F7,$53,$05,$11,$06,$E5,$07,$1F,$49,$7C,$E7,$29,$88,$52,$17
        db $C0,$F6,$64,$56,$B4,$26,$4C,$F6,$02,$05,$4F,$14,$0A,$08,$15,$05
        db $C7,$1D,$38,$81,$47,$67,$F4,$7D,$9A,$10,$11,$95,$BD,$B9,$4A,$1D
        db $1C,$8A,$8E,$57,$8B,$07,$16,$5C,$C8,$E4,$4D,$45,$3A,$15,$5C,$B4
        db $4D,$47,$3B,$3C,$3E,$38,$36,$41,$4C,$4D,$4A,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$00,$4C,$49,$54,$54,$4C,$45,$20,$4D,$41,$53,$54
        db $45,$52,$20,$20,$20,$20,$20,$20,$20,$20,$20,$02,$0B,$03,$00,$33
        db $00,$62,$BF,$9D,$40,$43,$E1,$43,$E1,$43,$E1,$43,$E1,$43,$E1,$69
        db $D4,$43,$E1,$02,$E1,$43,$E1,$43,$E1,$43,$E1,$43,$E1,$43,$E1,$43
        db $E1,$52,$D4,$02,$E1
