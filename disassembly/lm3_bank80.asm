        org $808000

        db $00,$00,$58,$39,$59,$39,$59,$39,$59,$39,$59,$39,$59,$39,$59,$39
        db $59,$39,$59,$39,$59,$39,$59,$39,$59,$39,$59,$39,$58,$79,$3F,$35
        db $4F,$35,$58,$39,$59,$39,$59,$39,$59,$39,$59,$39,$59,$39,$59,$39
        db $59,$39,$59,$39,$59,$39,$59,$39,$59,$39,$59,$39,$58,$79,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; [LevelLoad] Loads game data from ROM. Entry: A=data ID to load. Sets up data pointers at $22/$24, stores data at $0958-$095A, handles special cases for values $FFFF. Returns A=0 on success.
loadGameData:
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
        db $A5,$22,$18,$69,$10,$00,$8D,$86,$09
CODE_8080A3:
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
CODE_8080C5:
        LDY.W #$0007
        LDA.B [$22],Y
        CMP.B #$FF
        BEQ CODE_8080D2
        STA.L $7EEA84
CODE_8080D2:
        REP #$20
        LDA.W #$0000
        RTL
; [Memory] Searches data table for matching entry. Entry: $00=search value, $22/$24=data table pointer. Returns A=1 if found (sets $096C=index, $22=entry pointer, $096E=entry data), A=0 if not found.
findDataEntry:
        LDY.W #$0000
        STZ.B $08
CODE_8080DD:
        LDA.B [$22],Y
        BNE CODE_8080E2
        RTS
CODE_8080E2:
        STA.B $02
        INY
        INY
        LDA.B [$22],Y
        INY
        INY
        STA.B $04
        LDA.B [$22],Y
        STA.B $06
        LDA.B $04
        CMP.B $00
        BEQ CODE_8080FE
        INC.B $08
        INY
        INY
        INY
        INY
        BRA CODE_8080DD
CODE_8080FE:
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
setupDataStructure:
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
        JSL.L testGraphics
        LDA.W $098A
        CLC
        ADC.W #$0104
        TAX
        PLA
        CMP.W #$0000
        BEQ CODE_80815F
        LDY.W #$0080
        JSL.L calculateSlope
CODE_80815F:
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
; Draws title screen logo graphics to VRAM. Entry: loads logo tiles and palette.
drawTitleLogo:
        db $C6,$2A,$6B
; [GameState] Game mode dispatcher - jumps to different game mode handlers based on A value (0-5). Entry: A=game mode index. Uses jump table at $8869.
dispatchGameMode:
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
        JMP.W $8A00
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
        JSL.L setupTilemap
        JSL.L clearOAMBuffer
        LDA.W #$0002
        STA.B $00
        LDA.W #$0005
        STA.B $02
        JSL.L enableInterrupts
        JSL.L updateShadowEffect
        REP #$20
        JSR.W calculateTileOffset
        LDA.W #$002E
        STA.B $14
        LDA.W #$F000
        STA.B $12
        LDX.W #$1800
        LDY.W #$1000
        JSL.L updateWeatherParticles
        JSR.W updateOAMEntries
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
        JSL.L cheatMaxStats
        LDA.W $0A4A
        STA.W $0A48
        PLP
        RTL
; [VRAM] Calculates tile offset for graphics data. Entry: X=index. Reads from $7FCE00 table, multiplies by $A0, adds base offset $8000. Returns Y=calculated offset.
calculateTileOffset:
        STZ.B $22
CODE_80891B:
        LDX.B $22
        SEP #$20
        LDA.B #$2C
        STA.B $14
        LDA.L $7FCE00,X
        CMP.B #$80
        BCC CODE_80892F
        INC.B $14
        AND.B #$7F
CODE_80892F:
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
        JSL.L updateWeatherParticles
        LDA.B $12
        CLC
        ADC.W #$00A0
        STA.B $12
        PLA
        CLC
        ADC.W #$0100
        TAX
        LDY.W #$00A0
        JSL.L updateWeatherParticles
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
; [OAM] Clears OAM buffer by setting all entries to off-screen. Entry: none. Sets Y=$F0 for all OAM entries.
clearOAMBuffer:
        REP #$20
        JSR.W updateOAMEntries
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
; [OAM] Updates OAM entries with sprite data. Entry: expects sprite data pointers set. Writes to OAM via $2104.
updateOAMEntries:
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
        PHP
        REP #$20
        STZ.B $6F
        JSR.W mainGameLoop
        SEP #$20
        LDA.B #$02
        STA.W $2130
        LDA.B #$14
        STA.B $74
        LDA.B #$00
        STA.B $75
        REP #$20
        LDX.W #$2000
        LDY.W #$1000
        LDA.W #$0000
        JSL.L executeMapScript
        LDX.W #$7800
        LDY.W #$1000
        LDA.W #$0000
        JSL.L executeMapScript
        LDX.W #$7000
        LDY.W #$0800
        LDA.W #$0000
        JSL.L executeMapScript
        LDX.W #$0000
        LDY.W #$2000
        LDA.W #$0000
        JSL.L executeMapScript
        JSR.W enableScreen
        PLP
        RTL
        PHP
        REP #$20
        STZ.B $6F
        SEP #$20
        JSL.L updateMotionBlur
        JSL.L checkMapTrigger
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
        STA.B $12
        LDX.W #$3000
        LDY.W #$0100
        JSL.L updateTileAnimation
        LDA.W #$0000
        STA.B $14
        LDA.W #$0D80
        STA.B $12
        LDA.W #$0000
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L setupTilemap
        JSL.L setEventFlag
        LDA.W #$E800
        LDX.W #$0000
        LDY.W #$0080
CODE_808AB8:
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
        JSL.L updateWeatherParticles
        LDA.W #$002E
        STA.B $14
        LDA.W #$A000
        STA.B $12
        LDX.W #$5000
        LDY.W #$1000
        JSL.L updateWeatherParticles
        LDA.W #$0003
        STA.B $14
        LDA.W #$A1A0
        STA.B $12
        LDA.W #$0007
        STA.B $00
        LDA.W #$0001
        STA.B $02
        JSL.L setupTilemap
        LDX.W #$2000
        LDY.W #$1000
        LDA.W #$0000
        JSL.L executeMapScript
        JSR.W handleVBlank
        JSR.W enableScreen
        PLP
        RTL
; [Interrupt] V-Blank interrupt handler. Updates scroll registers, transfers OAM, handles DMA transfers. Entry: called from NMI.
handleVBlank:
        REP #$20
        LDX.W #$0000
        LDA.W #$0000
        STA.B $00
        LDY.W #$0020
CODE_808B24:
        PHY
        LDA.W #$0000
        STA.B $02
        LDY.W #$0020
CODE_808B2D:
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
        JSL.L updateShadowEffect
        RTS
        PHP
        REP #$20
        STZ.B $6F
        JSR.W mainGameLoop
        SEP #$20
        LDA.B #$04
        STA.W $2105
        REP #$20
        JSR.W enableScreen
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
        JSR.W waitForVBlank
        REP #$20
        JSR.W calculateTileOffset
        LDA.W #$002E
        STA.B $14
        LDA.W #$F000
        STA.B $12
        LDX.W #$1800
        LDY.W #$1000
        JSL.L updateWeatherParticles
        LDA.W #$0003
        STA.B $14
        LDA.W #$A1D2
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0008
        STA.B $02
        JSL.L setupTilemap
        LDA.W #$0000
        STA.B $14
        LDA.W #$0D80
        STA.B $12
        LDA.W #$0000
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L setupTilemap
        PLP
        RTL
        PHP
        LDA.W #$FFFF
        STA.B $6F
        JSR.W waitForVBlank
        REP #$20
        JSR.W calculateTileOffset
        LDA.W #$002E
        STA.B $14
        LDA.W #$A800
        STA.B $12
        LDX.W #$1800
        LDY.W #$0800
        JSL.L updateWeatherParticles
        LDA.W #$0003
        STA.B $14
        LDA.W #$A2F2
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0008
        STA.B $02
        JSL.L setupTilemap
        LDA.W #$0000
        STA.B $14
        LDA.W #$0D80
        STA.B $12
        LDA.W #$0000
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L setupTilemap
        PLP
        RTL
        PHP
        REP #$20
        JSR.W waitForVBlank
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
        JSL.L updateWeatherParticles
        LDA.W #$0003
        STA.B $14
        LDA.W #$A4F2
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0001
        STA.B $02
        JSL.L setupTilemap
        PLP
        RTL
        PHP
        JSR.W waitForVBlank
        LDA.W #$0001
        STA.W $2105
        REP #$20
        LDA.W #$002E
        STA.B $14
        LDA.W #$E000
        STA.B $12
        LDX.W #$1800
        LDY.W #$1000
        JSL.L updateWeatherParticles
        LDA.W #$0003
        STA.B $14
        LDA.W #$A3F2
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0008
        STA.B $02
        JSL.L setupTilemap
        LDA.W #$0009
        LDX.W #$0300
        LDY.W #$0000
        JSL.L calculateSlope
        LDX.W #$0000
        LDY.W #$02E0
        LDA.W #$1100
        JSR.W setupPPURegisters
        LDX.W #$0540
        LDY.W #$0020
        LDA.W #$3D76
        JSR.W setupPPURegisters
        LDX.W #$0580
        LDY.W #$00E0
        LDA.W #$0900
        JSR.W setupPPURegisters
        LDX.W #$0040
        LDY.W #$0020
        LDA.W #$0900
        JSR.W setupPPURegisters
        LDX.W #$0080
        LDY.W #$0020
        LDA.W #$0900
        JSR.W setupPPURegisters
        LDX.W #$00C0
        LDY.W #$0020
        LDA.W #$0900
        JSR.W setupPPURegisters
        PLP
        RTL
; [Helper] Waits for V-Blank by polling $4212. Entry: none. Loops until V-blank flag is set.
waitForVBlank:
        SEP #$20
        JSL.L updateShadowEffect
        LDA.B $72
        PHA
        JSL.L updateMotionBlur
        JSL.L waitForButton
        LDX.W #$7C00
        LDY.W #$0800
        LDA.B #$00
        JSL.L executeMapScript
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
CODE_808D4B:
        STA.W $0100,X
        INX
        INX
        INX
        INX
        DEY
        BNE CODE_808D4B
        RTS
; [Effects] Enables screen display by setting brightness. Entry: A=brightness value (0-15). Writes to $2100.
enableScreen:
        LDA.W #$E000
        LDX.W #$0000
        LDY.W #$0080
CODE_808D5F:
        STA.W $0100,X
        INX
        INX
        INX
        INX
        DEY
        BNE CODE_808D5F
        LDA.W #$FFFF
        LDY.W #$0010
CODE_808D6F:
        STA.W $0100,X
        INX
        INX
        DEY
        BNE CODE_808D6F
        RTS
; [Init] Initializes PPU registers for graphics mode. Sets BGMODE, tile/screen bases, mosaic, etc. Entry: called during init.
setupPPURegisters:
        REP #$20
CODE_808D7A:
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
        JSL.L setupTilemap
        LDA.W #$0003
        STA.B $14
        LDA.W #$A532
        STA.B $12
        LDA.W #$0002
        STA.B $00
        LDA.W #$0007
        STA.B $02
        JSL.L enableInterrupts
        LDA.W #$0003
        STA.B $14
        LDA.W #$A612
        STA.B $12
        LDX.W #$0000
        LDY.W #$1000
        JSL.L updateWeatherParticles
        LDA.W #$002E
        STA.B $14
        LDA.W #$C000
        STA.B $12
        LDX.W #$2000
        LDY.W #$1800
        JSL.L updateWeatherParticles
        PLP
        RTL
        PHP
        REP #$20
        STZ.B $6F
        JSR.W mainGameLoop
        STZ.B $60
        STZ.B $62
        STZ.B $6B
        JSR.W loadTileData
        LDA.W $096E
        INC A
        LDX.W #$0000
        LDY.W #$0004
        JSL.L cheatMaxStats
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
        JSL.L setupTilemap
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
        JSL.L setupTilemap
        LDA.W #$0000
        STA.B $14
        LDA.W #$0D80
        STA.B $12
        LDA.W #$0000
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L setupTilemap
        JSR.W enableScreen
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
        JSR.W setupDMAChannel
        LDA.W #$007F
        STA.B $18
        LDA.W #$CF00
        STA.B $16
        LDA.W #$0040
        JSL.L updateColorMath
        LDA.W #$000C
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L decompressGraphics
        LDA.W #$001F
        STA.B $14
        LDA.W #$A800
        STA.B $12
        LDA.W $0E83
        JSR.W setupDMAChannel
        LDA.W #$007F
        STA.B $18
        LDA.W #$CF40
        STA.B $16
        LDA.W #$0040
        JSL.L updateColorMath
        LDA.W #$000E
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L decompressGraphics
        REP #$20
        LDA.W $0E03
        AND.W #$003F
        INC A
        LDX.W #$0000
        LDY.W #$0002
        JSL.L cheatMaxStats
        LDA.W $0E83
        AND.W #$003F
        CMP.W #$003F
        BEQ CODE_808F1E
        INC A
        LDX.W #$1000
        LDY.W #$0002
        JSL.L cheatMaxStats
CODE_808F1E:
        JSL.L fadeToBlack
        JSR.W loadTileData
        LDA.W #$0003
        STA.B $14
        LDA.W #$B212
        STA.B $12
        LDX.W #$0E80
        LDY.W #$0100
        JSL.L updateWeatherParticles
        LDA.W #$0003
        STA.B $14
        LDA.W #$B312
        STA.B $12
        LDX.W #$0F80
        LDY.W #$0100
        JSL.L updateWeatherParticles
        LDA.W #$0003
        STA.B $14
        LDA.W #$B432
        STA.B $12
        LDX.W #$1E80
        LDY.W #$0100
        JSL.L updateWeatherParticles
        LDA.W #$0003
        STA.B $14
        LDA.W #$B472
        STA.B $12
        LDX.W #$1F80
        LDY.W #$0100
        JSL.L updateWeatherParticles
        LDA.W #$0003
        STA.B $14
        LDA.W #$B412
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0001
        STA.B $02
        JSL.L setupTilemap
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
CODE_808FBE:
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
        JSL.L executeMapScript
        PLP
        RTL
; [VRAM] Clears VRAM by filling with zeros. Uses DMA channel 0. Entry: none. Clears entire VRAM space.
clearVRAM:
        REP #$20
        LDA.W #$001F
        STA.B $14
        LDA.W #$A800
        STA.B $12
        LDA.W $0E03
        JSR.W setupDMAChannel
        LDA.W #$007F
        STA.B $18
        LDA.W #$CF00
        STA.B $16
        LDA.W #$0040
        JSL.L updateColorMath
        LDA.W #$007F
        STA.B $14
        LDA.W #$CF00
        STA.B $12
        LDA.W #$000C
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSR.W setupHDMA
        JSL.L enableInterrupts
        LDA.W $0E03
        AND.W #$003F
        INC A
        LDX.W #$0000
        LDY.W #$0002
        JSL.L cheatMaxStats
        RTL
; [VRAM] Loads tile graphics data to VRAM. Entry: $12/$14=source pointer, $2116=VRAM destination, $4305=length. Uses DMA.
loadTileData:
        REP #$20
        LDA.W $0958
        CMP.W #$FFFF
        BNE CODE_80905B
        JMP.W $9135
CODE_80905B:
        CMP.W #$0100
        BCC CODE_80907C
        LDX.W #$2104
        LDY.W #$0040
        JSL.L calculateSlope
        LDA.W $095A
        BEQ CODE_809079
        LDX.W #$0104
        LDY.W #$0000
        JSL.L calculateSlope
CODE_809079:
        JMP.W $9135
CODE_80907C:
        LDA.W $0958
        JSR.W startDMA
        STA.W $095C
        STY.W $095E
        LDA.W $095A
        JSR.W startDMA
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
        JSL.L cheatMaxStats
        LDA.W $095E
        INC A
        INC A
        LDY.W #$0003
        LDX.W #$48C0
        JSL.L cheatMaxStats
        LDA.W $0960
        INC A
        LDY.W #$0001
        LDX.W #$3000
        JSL.L cheatMaxStats
        LDA.W $0962
        INC A
        INC A
        LDY.W #$0003
        LDX.W #$38C0
        JSL.L cheatMaxStats
        LDA.W $09D8
        CMP.W #$0080
        BCS CODE_809103
        AND.W #$003F
        CLC
        ADC.W #$0079
        LDY.W #$0003
        LDX.W #$3C00
        JSL.L cheatMaxStats
CODE_809103:
        LDA.W #$0002
        STA.B $00
        LDA.W $095C
        JSR.W loadPaletteData
        LDA.W $095E
        CLC
        ADC.W #$0040
        JSR.W loadPaletteData
        LDA.W $0960
        JSR.W loadPaletteData
        LDA.W $0962
        CLC
        ADC.W #$0040
        JSR.W loadPaletteData
        LDA.W $09D8
        AND.W #$003F
        CLC
        ADC.W #$00B8
        JSR.W loadPaletteData
        RTS
; [Palette] Loads palette data to CGRAM. Entry: $12/$14=source pointer, $2121=CGRAM address, $4305=length. Uses DMA.
loadPaletteData:
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
        JSL.L setupTilemap
        INC.B $00
        RTS
; [DMA] Configures DMA channel for transfer. Entry: A=channel (0-7), X=DMAP/BBAD value, Y=A1T value. Sets up $43x0-$43x3.
setupDMAChannel:
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
; [DMA] Starts DMA transfer on specified channels. Entry: A=channel mask (bits 0-7). Writes to $420B.
startDMA:
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
CODE_809195:
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
; [DMA] Sets up HDMA channel for raster effects. Entry: A=channel, X=table pointer, Y=indirect pointer. Configures $43x0-$43x7.
setupHDMA:
        LDA.B $02
        ASL A
        ASL A
        ASL A
        ASL A
        TAX
        LDY.W #$0000
CODE_8091B4:
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
updateBattleGraphics:
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
CODE_809229:
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
CODE_809260:
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
CODE_8092AB:
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
CODE_8092C2:
        LDX.W #$039E
        LDY.W #$0003
        LDA.W #$59C0
CODE_8092CB:
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
CODE_8092E0:
        LDA.W #$7800
        STA.B $78
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSL.L updateShadowEffect
        PLP
        RTS
; [OAM] Draws a single battle sprite with position and tile data. Entry: A=sprite data index, X=OAM slot, $28=base address.
drawBattleSprite:
        JSR.W getCharacterDataPointer
        LDA.B $24
        STA.B $00
CODE_8092FA:
        LDY.B $22
        STX.B $04
CODE_8092FE:
        LDA.B $28
        INC.B $28
        JSR.W checkCharacterFlag
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
drawCharacterSprite:
        JSR.W getCharacterDataPointer
        LDA.B $24
        STA.B $00
        TXA
        CLC
        ADC.W #$001A
        TAX
CODE_809329:
        LDY.B $22
        STX.B $04
CODE_80932D:
        LDA.B $28
        INC.B $28
        EOR.W #$4000
        JSR.W checkCharacterFlag
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
; [Entity] Calculates pointer to character data table. Entry: A=character ID. Returns $12/$14=pointer to character data (bank $21, base $C000 + ID*$28).
getCharacterDataPointer:
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
; [Entity] Checks character flag bit in data structure. Entry: A=bit mask position, $12/$14=character data pointer. Returns A=adjusted value based on flag (adds $0400 if flag set).
checkCharacterFlag:
        STA.B $08
        LDA.B [$12]
        AND.B $06
        BEQ CODE_8093A7
        LDA.W #$0400
        CLC
        ADC.B $08
        STA.B $08
CODE_8093A7:
        LDA.B $06
        ASL A
        CMP.W #$0100
        BNE CODE_8093B4
        INC.B $12
        LDA.W #$0001
CODE_8093B4:
        STA.B $06
        LDA.B $08
        RTS
; [MainLoop] Main game loop - handles frame updates, input, game logic. Entry: called each frame. Calls input, sound, and game state updates.
mainGameLoop:
        PHP
        SEP #$20
        JSL.L updateMotionBlur
        SEP #$20
        JSL.L checkMapTrigger
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
CODE_8093F5:
        LDX.W #$6000
        LDY.W #$1000
        JSL.L updateWeatherParticles
        LDA.W #$0003
        STA.B $14
        LDA.W #$8340
        STA.B $12
        LDX.W #$6800
        LDY.W #$0800
        JSL.L updateWeatherParticles
        LDA.W #$0000
        STA.B $14
        LDA.W #$0D80
        STA.B $12
        LDA.W #$0000
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L setupTilemap
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
CODE_809442:
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
        JSL.L executeMapScript
        PLP
        RTS
; [VRAM] Decompresses graphics data from ROM to RAM. Entry: $12/$14=source pointer, $16/$18=dest pointer, $02=compression type. Uses RLE-like decompression.
decompressGraphics:
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
CODE_809474:
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
        JSR.W updateLensFlare
        TSC
        CLC
        ADC.W #$0005
        TCS
        PLP
        RTL
; [Tilemap] Sets up background tilemap in VRAM. Entry: $12/$14=tilemap data pointer, $2116=VRAM destination. Writes 32x32 tilemap.
setupTilemap:
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
        JSR.W updateLensFlare
        TSC
        CLC
        ADC.W #$0005
        TCS
        PLP
        RTL
; [Scrolling] Updates BG scroll registers based on camera position. Entry: $00=BG1HOFS, $02=BG1VOFS, etc. Writes to $210D-$2114.
updateScrollRegisters:
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
incrementCounter:
        SEP #$20
        INC A
        STA.B $81
        REP #$20
        RTS
; [AI] Processes enemy AI logic for battle. Entry: reads enemy data from $7EEA8C, processes AI scripts from ROM table $0BE579.
processEnemyAI:
        REP #$20
        LDX.W #$0000
        LDA.L $7EEA8C
        STA.B $22
CODE_809561:
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
        JSR.W playSoundEffect
        LDA.L $7F0000,X
        AND.W #$FC00
        ORA.W #$00A0
        STA.L $7F0000,X
        DEC.B $22
        BRA CODE_8095A3
CODE_809594:
        PHX
        JSR.W playSoundEffect
        LDA.L $7F0000,X
        ORA.W #$2000
        STA.L $7F0000,X
CODE_8095A3:
        PLA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_809561
CODE_8095AB:
        STX.W $09C0
        RTL
; [Physics] Calculates damage in battle based on attacker/defender stats. Entry: A=attacker ID, X=defender ID. Returns A=damage amount.
calculateBattleDamage:
        REP #$20
        LDY.W #$0014
CODE_8095B4:
        PHY
        JSL.L checkSPCBusy
        JSL.L updateShadowEffect
        PLY
        DEY
        BNE CODE_8095B4
        JSL.L processEnemyAI
        TXA
        CLC
        ADC.W #$0004
        TAX
        STX.W $09C4
CODE_8095CE:
        LDA.L $0BE579,X
        STA.B $00
        BEQ CODE_809607
        LDA.L $0BE57B,X
        CMP.W #$8000
        BCS CODE_809607
        PHX
        JSR.W playSoundEffect
        LDA.L $7F0000,X
        ORA.W #$2000
        STA.L $7F0000,X
        JSL.L testPathfinding
        LDA.W #$0003
        JSR.W incrementCounter
        LDA.W #$0003
        JSL.L updateReflection
        PLA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_8095CE
CODE_809607:
        LDA.L $7EEA8C
        INC A
        STA.L $7EEA8C
        JSL.L processEnemyAI
        JSL.L testPathfinding
        LDA.W #$0002
        JSR.W incrementCounter
        LDX.W $09C4
        LDY.W #$0001
        BRA CODE_809634
        db $C2,$20,$5A,$22,$E9,$97,$00,$8A,$18,$69,$04,$00,$AA,$7A
CODE_809634:
        CPY.W #$0002
        BNE CODE_80963E
        LDY.W #$FFFC
        BRA CODE_809641
CODE_80963E:
        LDY.W #$0004
CODE_809641:
        STY.B $22
        STX.W $09D0
CODE_809646:
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
CODE_809668:
        PHX
        JSR.W handleItemUse
        PLA
        CLC
        ADC.B $22
        TAX
        BRA CODE_809646
CODE_809673:
        JSL.L updateMenuCursor
        LDA.B $04
        STA.B $00
        JSR.W handleItemUse
        RTL
; [Menu] Handles item usage in menu or battle. Entry: A=item ID, X=target. Processes item effects, updates inventory.
handleItemUse:
        JSR.W checkCollision
        LDA.B $00
        STA.W $1806
        LDA.B $02
        STA.W $1808
        STZ.B $24
        STZ.B $26
        LDX.B $24
        LDY.B $26
        JSL.L cheatAllKeys
        JSL.L checkSPCBusy
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
CODE_8096BA:
        LDY.W #$0028
        CLC
        ADC.W #$0002
        INC.B $28
CODE_8096C3:
        STA.W $1802
        SEC
        SBC.B $60
        CMP.W #$0049
        BCS CODE_8096D2
        DEC.B $24
        DEC.B $24
CODE_8096D2:
        CMP.W #$008F
        BCC CODE_8096DB
        INC.B $24
        INC.B $24
CODE_8096DB:
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
CODE_8096F5:
        CPY.W #$0028
        BNE CODE_8096FF
        LDY.W #$0024
        BRA CODE_80971A
CODE_8096FF:
        LDY.W #$0020
        BRA CODE_80971A
CODE_809704:
        CLC
        ADC.W #$0002
        INC.B $28
        CPY.W #$0008
        BNE CODE_809712
        LDY.W #$0004
CODE_809712:
        CPY.W #$0028
        BNE CODE_80971A
        LDY.W #$002C
CODE_80971A:
        STA.W $1804
        SEC
        SBC.B $62
        CMP.W #$0048
        BCS CODE_809729
        DEC.B $26
        DEC.B $26
CODE_809729:
        CMP.W #$0071
        BCC CODE_809732
        INC.B $26
        INC.B $26
CODE_809732:
        LDA.B $54
        AND.W #$0004
        STA.B $00
        TYA
        ORA.W #$A000
        LDY.B $00
        BEQ CODE_809745
        CLC
        ADC.W #$0002
CODE_809745:
        STA.W $180A
        JSL.L updateShadowEffect
        LDA.B $28
        BEQ CODE_809753
        JMP.W $9690
CODE_809753:
        RTS
; [SFX] Plays a sound effect via APU. Entry: A=sound effect ID. Writes to APU ports $2140-$2143.
playSoundEffect:
        SEP #$20
        ASL.B $00
        REP #$20
        LDA.B $00
        TAX
        RTS
; [Music] Plays background music. Entry: A=music track ID. Sends command to SPC700 via APU ports.
playBGM:
        JSL.L updateTransparency
        JSL.L checkSPCBusy
        JSL.L updateShadowEffect
        JSL.L updateMenuCursor
        LDA.B $50
        AND.W #$0100
        BEQ CODE_809779
        INC.B $04
        BRA CODE_8097A2
CODE_809779:
        LDA.B $50
        AND.W #$0200
        BEQ CODE_809784
        DEC.B $04
        BRA CODE_8097A2
CODE_809784:
        LDA.B $50
        AND.W #$0400
        BEQ CODE_80978F
        INC.B $05
        BRA CODE_8097A2
CODE_80978F:
        LDA.B $50
        AND.W #$0800
        BEQ CODE_80979A
        DEC.B $05
        BRA CODE_8097A2
CODE_80979A:
        LDA.B $50
        AND.W #$F0F0
        BEQ playBGM
        RTL
CODE_8097A2:
        JSR.W fadeScreen
        CMP.W #$FFFF
        BEQ playBGM
        LDA.W #$01F0
        STA.W $1800
        JSL.L CODE_809634
        LDA.W #$0000
        RTL
; [Effects] Screen fade effect (in/out). Entry: A=0 for fade in, 1 for fade out. Updates $2100 brightness gradually.
fadeScreen:
        REP #$20
        LDX.W #$0000
CODE_8097BD:
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
CODE_8097DD:
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_8097BD
CODE_8097E5:
        LDA.W #$FFFF
        RTS
; [Menu] Updates menu cursor position and animation. Entry: reads controller input, updates cursor sprite OAM.
updateMenuCursor:
        REP #$20
        STZ.W $09B2
        LDA.L $7EEA82
        STA.B $00
        LDX.W #$0000
CODE_8097F7:
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
CODE_80982F:
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_8097F7
CODE_809837:
        LDA.B $04
        STA.B $00
        JSR.W checkCollision
        RTL
; [Collision] Checks collision between two objects. Entry: $00-$03=object1 rect, $04-$07=object2 rect. Returns carry set if collision.
checkCollision:
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
; [Player] Moves character based on input and collision. Entry: A=character ID, reads controller, updates position.
moveCharacter:
        REP #$20
        ASL A
        ASL A
        ASL A
        ASL A
        TAX
        PHX
        LDY.W #$0008
CODE_809869:
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
; [Camera] Updates camera position to follow player. Entry: reads player position, calculates camera bounds, updates scroll.
updateCamera:
        SEP #$20
        LDA.B #$02
        STA.B $81
        REP #$20
        LDX.W #$0000
        LDA.W #$01F0
        STA.W $1800
CODE_8098A2:
        LDA.L $0098CC,X
        AND.W #$00FF
        CMP.W #$00FF
        BEQ CODE_8098C4
        PHX
        ORA.W #$2000
        STA.W $180A
        JSL.L checkSPCBusy
        LDA.W #$0004
        JSL.L updateReflection
        PLX
        INX
        BRA CODE_8098A2
CODE_8098C4:
        LDA.W #$000F
        JSL.L updateReflection
        RTL
        db $00,$04,$08,$0C,$20,$24,$28,$2C,$40,$42,$FF
        REP #$20
        LDA.W $09B4
        CLC
        ADC.W #$0201
        STA.B $00
        JSR.W checkCollision
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
        JSL.L moveCharacter
CODE_8098FC:
        JSL.L updateTransparency
        JSL.L checkSPCBusy
        JSL.L updateShadowEffect
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
CODE_809922:
        TYA
        INC A
        CMP.W $09B8
        BEQ CODE_8098FC
        BRA CODE_80992F
CODE_80992B:
        TYA
        BEQ CODE_8098FC
        DEC A
CODE_80992F:
        STA.W $09B2
        LDA.W #$0000
CODE_809935:
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
drawDialogBox:
        REP #$20
        CPY.W #$0006
        BNE CODE_809A2B
        LDY.W #$00F0
        JMP.W $9D3A
CODE_809A2B:
        CPY.W #$0007
        BNE CODE_809A36
        LDY.W #$0000
        JMP.W $9D3A
CODE_809A36:
        CPY.W #$0008
        BNE CODE_809A3E
        JMP.W $9C26
CODE_809A3E:
        CPY.W #$0009
        BNE CODE_809A46
        JMP.W $9B79
CODE_809A46:
        CPY.W #$000A
        BNE CODE_809A4E
        JMP.W $9C47
CODE_809A4E:
        CPY.W #$000B
        BNE CODE_809A56
        JMP.W $9B19
CODE_809A56:
        CPY.W #$000C
        BNE CODE_809A5E
        JMP.W $9ABB
CODE_809A5E:
        PHX
        STZ.B $24
        LDX.W #$99B6
        CPY.W #$0000
        BNE CODE_809A6C
        LDX.W #$9936
CODE_809A6C:
        CPY.W #$0001
        BNE CODE_809A74
        db $A2,$82,$99
CODE_809A74:
        STX.B $22
        LDA.B [$22]
        AND.W #$00FF
        STA.B $26
        INC.B $22
        INC.B $22
        PLX
CODE_809A82:
        LDY.W #$0000
CODE_809A85:
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
        JSL.L checkSPCBusy
        JSL.L updateShadowEffect
        PLX
        PLY
        BRA CODE_809A85
CODE_809AB6:
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
CODE_809AD1:
        STA.W $1804,X
        LDA.W $1800,X
        ORA.W #$00F0
        STA.W $1800,X
CODE_809ADD:
        JSL.L checkSPCBusy
        JSL.L updateShadowEffect
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
CODE_809B07:
        LDA.W $09CA
        STA.W $1804,X
        STZ.W $1808,X
        JSL.L checkSPCBusy
        JSL.L updateShadowEffect
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
CODE_809B2F:
        STA.W $09CA
CODE_809B32:
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
        JSL.L checkSPCBusy
        JSL.L updateShadowEffect
        BRA CODE_809B32
CODE_809B5E:
        LDA.W $1800,X
        AND.W #$FF00
        STA.W $1800,X
        LDA.W $09CC
        STA.W $1804,X
        STZ.W $1808,X
        JSL.L checkSPCBusy
        JSL.L updateShadowEffect
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
        JSR.W updateHPBar
        LDA.W #$39E0
        LDY.W #$0004
        JSR.W updateHPBar
        LDA.W #$39E5
        LDY.W #$0004
        JSR.W updateHPBar
        LDA.W #$39EA
        LDY.W #$0004
        JSR.W updateHPBar
        JSL.L checkSPCBusy
        JSL.L updateShadowEffect
        RTL
; [HUD] Updates HP bar display for character. Entry: A=character ID, X=current HP, Y=max HP. Draws bar in HUD.
updateHPBar:
        STA.W $09C8
CODE_809BC4:
        PHY
        JSL.L checkSPCBusy
        LDA.W $09CA
        STA.B $00
        LDA.W $09C8
        LDY.W #$0000
        JSR.W setupSpriteOAM
        JSL.L updateShadowEffect
        PLY
        DEY
        BNE CODE_809BC4
        RTS
; [OAM] Sets up OAM entries for a sprite with 4 tiles (2x2). Entry: A=tile number, $00=X pos, Y=OAM slot. Creates 4 OAM entries.
setupSpriteOAM:
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
CODE_809C2B:
        PHY
        LDA.W $1802,X
        EOR.W #$0008
        STA.W $1802,X
        PHX
        JSL.L checkSPCBusy
        LDA.W #$0002
        JSL.L updateReflection
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
CODE_809C67:
        TAY
        SEC
        SBC.W #$0010
        BMI CODE_809C73
        INC.W $096C
        BRA CODE_809C67
CODE_809C73:
        STY.B $01
        LDA.B $00
        STA.W $096E
        LDX.W #$0200
        LDA.W #$AAAA
CODE_809C80:
        STA.W $0100,X
        INX
        INX
        CPX.W #$0208
        BNE CODE_809C80
        LDA.W $096C
        BEQ CODE_809CA9
        LDA.W #$0001
CODE_809C92:
        PHA
        LDY.W #$0001
        JSR.W $9CAE
        PLA
        INC A
        CMP.W $096C
        BCC CODE_809C92
        LDA.W $096C
        LDY.W #$0028
        JSR.W $9CAE
CODE_809CA9:
        JSL.L checkSPCBusy
        RTL
        STY.W $09C8
        STA.W $09CA
CODE_809CB4:
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
CODE_809CD5:
        LDX.W $09CC
        TYA
        STA.W $180A,X
CODE_809CDC:
        JSL.L checkSPCBusy
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
CODE_809CFD:
        LDA.B $02
        STA.W $0100,Y
        CLC
        ADC.W #$1000
        STA.B $02
        JSL.L updateLightningEffect
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
        JSL.L updateReflection
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
CODE_809D48:
        PHX
        LDA.W #$00F0
        CPX.W #$0000
        BNE CODE_809D54
        LDA.W #$0000
CODE_809D54:
        EOR.W $09D0
        STA.B $00
        LDX.W $09D4
        LDA.W $1800,X
        AND.W #$FF00
        ORA.B $00
        STA.W $1800,X
        JSL.L checkSPCBusy
        JSL.L updateShadowEffect
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
CODE_809D84:
        LDA.W $09D2
        CMP.W #$0028
        BNE CODE_809D48
        RTL
; [Effects] Animates battle visual effect (spell, attack). Entry: A=effect type. Updates OAM for effect animation over multiple frames.
animateBattleEffect:
        REP #$20
        LDY.W #$0000
        CMP.W #$000E
        BEQ CODE_809DC7
CODE_809D97:
        LDX.W #$0000
        JSR.W drawEffectTile
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
CODE_809DB6:
        LDX.W #$0000
        JSR.W drawEffectTile
        DEY
        BNE CODE_809DB6
        SEP #$20
        LDA.B #$1D
        STA.B $81
        REP #$20
CODE_809DC7:
        LDA.W $096E
        STA.W $096C
        LDA.W $096C
        SEC
        SBC.W #$0800
        STA.W $096C
        LDX.W #$001F
        LDY.W #$0004
        LDA.W #$0008
        JSL.L updateWeatherEffect
        LDY.W #$0064
CODE_809DE7:
        PHY
        TYA
        AND.W #$0007
        BNE CODE_809E27
        JSL.L updateLightningEffect
        AND.W #$0038
        CLC
        ADC.W #$1200
        TAX
        JSL.L updateLightningEffect
        AND.W #$000F
        STA.B $00
        JSL.L updateLightningEffect
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
CODE_809E27:
        LDX.W #$0008
        JSR.W updateBattleTimer
        PLY
        DEY
        BNE CODE_809DE7
        JSL.L checkSPCBusy
        JSL.L updateShadowEffect
        RTL
; [Timer] Updates battle turn timer. Entry: reads timer value, decrements, checks for turn end. Returns carry set if turn ended.
updateBattleTimer:
        PHX
        JSL.L checkSPCBusy
        PLX
        LDY.W #$0000
        JSL.L handleMenuNavigation
        JSL.L updateShadowEffect
        RTS
; [OAM] Draws a single effect animation tile. Entry: A=tile data, X=OAM slot, Y=animation frame. Updates OAM entry.
drawEffectTile:
        PHY
        PHX
        JSL.L checkSPCBusy
        LDA.W $096C
        STA.B $00
        LDA.W #$3BC0
        STA.B $02
        LDA.B $54
        AND.W #$0001
        BNE CODE_809E66
        PLX
        BRA CODE_809E7B
CODE_809E66:
        LDA.B $54
        AND.W #$0002
        BEQ CODE_809E75
        LDA.B $02
        CLC
        ADC.W #$0005
        STA.B $02
CODE_809E75:
        LDA.B $02
        PLY
        JSR.W setupSpriteOAM
CODE_809E7B:
        JSL.L updateShadowEffect
        PLY
        RTS
; [AI] Processes one battle turn for a unit. Entry: A=unit ID. Handles AI for enemies, input for player, executes actions.
processBattleTurn:
        REP #$20
        LDX.W #$0000
        LDA.W #$03E7
        STA.B $06
        STZ.W $096E
CODE_809E8E:
        LDA.L $7FC0C8,X
        BNE CODE_809E95
        RTL
CODE_809E95:
        STA.B $04
        LDA.L $7FC0CA,X
        CMP.W #$1800
        BEQ CODE_809EA8
CODE_809EA0:
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_809E8E
CODE_809EA8:
        PHX
        LDX.W #$0000
        STZ.B $08
CODE_809EAE:
        LDA.B $08
        CMP.W $091C
        BEQ CODE_809EBF
        LDA.W $1404,X
        CMP.B $04
        BNE CODE_809EBF
        PLX
        BRA CODE_809EA0
CODE_809EBF:
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
CODE_809EE1:
        SEC
        SBC.B $00
CODE_809EE4:
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
CODE_809EF8:
        SEC
        SBC.B $02
CODE_809EFB:
        CLC
        ADC.B $0A
        CMP.B $06
        BCS CODE_809F09
        STA.B $06
        LDA.B $04
        STA.W $096E
CODE_809F09:
        BRA CODE_809EA0
; [Physics] Calculates hit rate for attack. Entry: A=attacker accuracy, X=defender evasion. Returns A=hit chance (0-100).
calculateHitRate:
        PHP
        REP #$20
        STZ.B $06
        LDA.W #$0102
        STA.B $12
CODE_809F15:
        SEP #$20
        LDA.B $02
        CMP.B $06
        BCS CODE_809F24
        LDA.B $06
        SEC
        SBC.B $02
        BRA CODE_809F27
CODE_809F24:
        SEC
        SBC.B $06
CODE_809F27:
        STA.B $14
        STZ.B $04
        LDX.B $12
CODE_809F2D:
        LDA.B $00
        CMP.B $04
        BCS CODE_809F3A
        LDA.B $04
        SEC
        SBC.B $00
        BRA CODE_809F3D
CODE_809F3A:
        SEC
        SBC.B $04
CODE_809F3D:
        CLC
        ADC.B $14
        CMP.B $0A
        BCS CODE_809F52
        CMP.B $08
        BCC CODE_809F52
        LDA.L $7F0001,X
        ORA.B #$20
        STA.L $7F0001,X
CODE_809F52:
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
CODE_809F74:
        PLP
        RTL
; [Entity] Applies status effect to character. Entry: A=character ID, X=status effect type. Updates character status flags.
applyStatusEffect:
        REP #$20
        LDA.W #$007F
        STA.B $14
        LDA.W #$A000
        STA.B $12
        LDA.W #$1000
        LDX.W #$0000
        JSL.L updateBlendEffect
        JSR.W saveGame
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
CODE_809FAD:
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
        JSR.W loadGame
        LDA.W #$0100
        STA.L $7FA000,X
        PLX
CODE_809FD1:
        TXA
        CLC
        ADC.W #$0020
        TAX
        DEC.B $06
        BNE CODE_809FAD
        JSR.W checkPartyAlive
        JSR.W reviveCharacter
        JSR.W checkPartyAlive
        LDA.L $7FC013
        STA.B $06
        STZ.B $00
        STZ.B $02
        STZ.B $0E
        LDX.W #$0000
CODE_809FF3:
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
CODE_80A01A:
        SEP #$20
        LDA.B $01
        STA.B $02
        STZ.B $01
        REP #$20
        PHX
        JSR.W loadGame
        SEP #$20
        LDA.L $7FA000,X
        STA.L $7FA001,X
        LDA.B #$00
        STA.L $7FA000,X
        REP #$20
        PLX
CODE_80A03B:
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
checkPartyAlive:
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
CODE_80A066:
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
        JSR.W loadGame
        LDA.L $7F9000,X
        EOR.W #$8000
        STA.L $7F9000,X
        PLX
CODE_80A099:
        TXA
        CLC
        ADC.W #$0020
        TAX
        DEC.B $06
        BNE CODE_80A066
CODE_80A0A3:
        RTS
; [Entity] Revives a KO'd character with partial HP. Entry: A=character ID. Restores HP to 25% of max.
reviveCharacter:
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
        JSR.W gainExperience
        LDA.W #$FFFE
        JSR.W gainExperience
        LDA.W #$0080
        JSR.W gainExperience
        LDA.W #$FF80
        JSR.W gainExperience
        PLX
CODE_80A0D5:
        INX
        INX
        INC.B $00
        LDA.B $00
        CMP.W #$0029
        BEQ CODE_80A0E3
        JMP.W $A0B1
CODE_80A0E3:
        LDA.B $26
        CLC
        ADC.W #$0080
        TAX
        INC.B $02
        LDA.B $02
        CMP.W #$001F
        BEQ CODE_80A0F6
        JMP.W $A0AB
CODE_80A0F6:
        DEC.B $22
        LDA.B $22
        CMP.W #$0001
        BEQ CODE_80A102
        JMP.W reviveCharacter
CODE_80A102:
        RTS
; [Entity] Awards experience points to character. Entry: A=character ID, X=XP amount. Updates level if threshold reached.
gainExperience:
        CLC
        ADC.B $28
        TAX
        PHX
        LDA.L $7F9000,X
        CMP.W #$8000
        BCS CODE_80A14E
        AND.W #$01FF
        ASL A
        ASL A
        TAX
        LDA.L $7FE000,X
        PHA
        AND.W #$000F
        STA.B $04
        PLA
        AND.W #$00F0
        CMP.B $0C
        BEQ CODE_80A12B
        BCS CODE_80A155
CODE_80A12B:
        LDA.B $0C
        CMP.W #$0020
        BEQ CODE_80A14E
CODE_80A132:
        LDA.B $22
        SEC
        SBC.B $04
        BCS CODE_80A13C
        LDA.W #$0000
CODE_80A13C:
        STA.B $06
        PLX
        LDA.L $7FA000,X
        CMP.B $06
        BCS CODE_80A14D
        LDA.B $06
        STA.L $7FA000,X
CODE_80A14D:
        RTS
CODE_80A14E:
        LDA.W #$0002
        STA.B $04
        BRA CODE_80A132
CODE_80A155:
        PLX
        RTS
; [Entity] Handles character level up. Entry: A=character ID. Increases stats, learns new abilities if any.
levelUpCharacter:
        REP #$20
        TAY
        BNE CODE_80A15D
        RTL
        db $A2,$00,$00,$BF,$00,$F0,$7F,$F0,$3B,$4A,$4A,$4A,$4A,$85,$00,$64
        db $02,$A9,$00,$00,$18,$6D,$3E,$0E,$C6,$01,$D0,$F8,$85,$04,$C0,$03
        db $00,$F0,$1A,$BF,$00,$F0,$7F,$29,$FF,$0F,$38,$E5,$04,$B0,$03,$A9
        db $00,$00,$C0,$02,$00,$D0,$01,$0A,$CD,$08,$0E,$90,$07,$A9,$00,$00
        db $9F,$00,$A0,$7F,$E8,$E8,$E0,$00,$10,$D0,$B8,$6B
; [Menu] Equips item to character. Entry: A=character ID, X=item ID. Updates equipment slots, applies stat bonuses.
equipItem:
        REP #$20
        LDA.W #$007F
        STA.B $14
        LDA.W #$F000
        STA.B $12
        LDA.W #$1000
        LDX.W #$0000
        JSL.L updateBlendEffect
        LDX.W #$0000
        LDY.W #$0010
CODE_80A1C5:
        PHY
        PHX
        TXA
        LDY.W #$0E00
        JSL.L breakpointHandler
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
        JSR.W loadGame
        LDA.B $04
        INC A
        STA.L $7FA000,X
        STA.B $22
        JSR.W reviveCharacter
        LDA.W $0E56
        STA.B $06
        JSR.W buyItemShop
        LDX.W #$0000
CODE_80A215:
        LDA.L $7FB000,X
        BEQ CODE_80A22B
        LDA.L $7FF000,X
        CLC
        ADC.W $0E3A
        CLC
        ADC.W #$1000
        STA.L $7FF000,X
CODE_80A22B:
        INX
        INX
        CPX.W #$1000
        BNE CODE_80A215
CODE_80A232:
        PLX
        PLY
        INX
        DEY
        BNE CODE_80A1C5
        RTL
; [Menu] Unequips item from character. Entry: A=character ID, X=equipment slot. Removes item, recalculates stats.
unequipItem:
        REP #$20
        JSR.W buyItemShop
        LDX.W #$0000
        LDY.W #$0008
        LDA.W #$0000
CODE_80A247:
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
CODE_80A25C:
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
        JSR.W loadGame
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
CODE_80A29D:
        PLX
CODE_80A29E:
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
buyItemShop:
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
        JSL.L updateColorMath
        STZ.W $09AE
        LDX.W #$0082
        STX.B $12
        LDA.W #$001E
        STA.B $00
        LDA.W #$0200
        STA.B $04
CODE_80A2DD:
        LDA.W #$0028
        STA.B $02
CODE_80A2E2:
        LDA.L $7FA000,X
        BEQ CODE_80A2EB
        JSR.W sellItemShop
CODE_80A2EB:
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
sellItemShop:
        LDY.B $04
        LDA.L $7FAFFE,X
        BNE CODE_80A30C
        TYA
        STA.L $7FAFFE,X
CODE_80A30C:
        LDA.L $7FB002,X
        BNE CODE_80A317
        TYA
        STA.L $7FB002,X
CODE_80A317:
        LDA.L $7FAF80,X
        BNE CODE_80A322
        TYA
        STA.L $7FAF80,X
CODE_80A322:
        LDA.L $7FB080,X
        BNE CODE_80A32D
        TYA
        STA.L $7FB080,X
CODE_80A32D:
        LDA.B $06
        CMP.W #$0002
        BCS CODE_80A335
        RTS
CODE_80A335:
        LDA.L $7FAFFC,X
        BNE CODE_80A340
        TYA
        STA.L $7FAFFC,X
CODE_80A340:
        LDA.L $7FB004,X
        BNE CODE_80A34B
        TYA
        STA.L $7FB004,X
CODE_80A34B:
        LDA.L $7FAF82,X
        BNE CODE_80A356
        TYA
        STA.L $7FAF82,X
CODE_80A356:
        LDA.L $7FAF7E,X
        BNE CODE_80A361
        TYA
        STA.L $7FAF7E,X
CODE_80A361:
        LDA.L $7FB07E,X
        BNE CODE_80A36C
        TYA
        STA.L $7FB07E,X
CODE_80A36C:
        LDA.L $7FB082,X
        BNE CODE_80A377
        TYA
        STA.L $7FB082,X
CODE_80A377:
        CPX.W #$0F00
        BCS CODE_80A387
        LDA.L $7FB100,X
        BNE CODE_80A387
        TYA
        STA.L $7FB100,X
CODE_80A387:
        CPX.W #$0100
        BCC CODE_80A397
        LDA.L $7FAF00,X
        BNE CODE_80A397
        TYA
        STA.L $7FAF00,X
CODE_80A397:
        RTS
; [Save] Saves game to SRAM. Entry: copies game state from WRAM to SRAM $700000. Includes checksum.
saveGame:
        JSR.W loadGame
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
; [Save] Loads game from SRAM. Entry: copies from SRAM $700000 to WRAM, verifies checksum.
loadGame:
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
initNewGame:
        REP #$20
        LDA.W #$0008
        STA.B $0A
        LDA.L $7FC016
        AND.W #$00FF
        BEQ CODE_80A3D0
        db $85,$0A
CODE_80A3D0:
        LDX.W #$0000
CODE_80A3D3:
        LDA.L $7FC0C8,X
        BNE CODE_80A3DA
        RTL
CODE_80A3DA:
        STA.B $00
        LDA.L $7FC0CA,X
        CMP.W #$1800
        BNE CODE_80A3EB
        LDA.B $0A
        STA.B $08
        BRA CODE_80A402
CODE_80A3EB:
        AND.W #$00FF
        CMP.W #$0040
        BNE CODE_80A3FA
        db $A9,$04,$00,$85,$08,$80,$08
CODE_80A3FA:
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_80A3D3
CODE_80A402:
        PHX
        SEP #$20
        LDA.B $01
        STA.B $02
        STZ.B $01
        STZ.B $03
        REP #$20
        JSR.W saveGame
        CMP.B $08
        BEQ CODE_80A419
        PLX
        BRA CODE_80A3FA
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
drawMap:
        REP #$20
        JSL.L updateShadowEffect
        LDA.W $0E6A
        CMP.W #$0001
        BEQ CODE_80A571
        LDA.L $7EEA82
        CMP.W #$0004
        BNE CODE_80A53E
        LDA.W #$001E
        LDX.W #$0000
        JSR.W $A5B4
        LDA.W #$0A05
        JSL.L testGraphics
        BRA CODE_80A571
CODE_80A53E:
        CMP.W #$000D
        BNE CODE_80A555
        db $A9,$21,$00,$A2,$00,$00,$20,$B4,$A5,$A9,$20,$09,$22,$55,$E1,$01
        db $80,$1C
CODE_80A555:
        CMP.W #$0012
        BNE CODE_80A56C
        db $A9,$09,$03,$A2,$00,$00,$20,$B4,$A5,$A9,$24,$00,$22,$55,$E1,$01
        db $80,$05
CODE_80A56C:
        CMP.W #$001E
        BEQ CODE_80A572
CODE_80A571:
        RTL
        db $AD,$58,$09,$C9,$BE,$00,$F0,$28,$C9,$BF,$00,$F0,$23,$C9,$C0,$00
        db $F0,$1E,$C9,$C2,$00,$F0,$19,$AD,$5A,$09,$C9,$BE,$00,$F0,$11,$C9
        db $BF,$00,$F0,$0C,$C9,$C0,$00,$F0,$07,$C9,$C2,$00,$F0,$02,$80,$CF
        db $A9,$12,$03,$A2,$00,$01,$20,$B4,$A5,$A9,$20,$09,$22,$55,$E1,$01
        db $80,$BD
        LDY.W #$0000
        JSL.L calculateSlope
        SEP #$20
        LDA.B #$70
        STA.W $2108
        LDA.B #$01
        STA.W $0E20
        STA.W $0EA0
        REP #$20
        RTS
; [HUD] Updates minimap display in corner. Entry: reads player position, draws current area on minimap.
updateMinimap:
        REP #$20
        LDA.W #$0008
        STA.W $09E2
        LDX.W #$1200
        LDA.W #$0000
CODE_80A5DB:
        STZ.W $0000,X
        INX
        INX
        CPX.W #$1340
        BNE CODE_80A5DB
        RTL
; [Dialogue] Handles NPC dialogue interaction. Entry: A=NPC ID. Loads dialogue text, displays choices if any.
handleNPCDialogue:
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
CODE_80A60B:
        LDA.W $0000,X
        BEQ CODE_80A61A
        TXA
        CLC
        ADC.W #$0010
        TAX
        DEY
        BNE CODE_80A60B
        db $6B
CODE_80A61A:
        DEC A
        STA.W $0000,X
        PHX
        INX
        INX
        LDY.W #$0007
CODE_80A624:
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
CODE_80A637:
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
CODE_80A64D:
        RTL
; [OAM] Sets up OAM for large sprite (4x4 tiles). Entry: A=base tile, $00=X pos, Y=OAM slot. Creates 16 OAM entries.
setupLargeSprite:
        REP #$20
        LDA.W $0A87
        BNE CODE_80A656
        RTL
CODE_80A656:
        LDX.W #$1200
        LDY.W #$0000
CODE_80A65C:
        LDA.W $0000,X
        BEQ CODE_80A6B8
        DEC A
        STA.W $0000,X
        CMP.W #$0100
        BCS CODE_80A66F
        db $29,$01,$00,$F0,$49
CODE_80A66F:
        LDA.W $000E,X
        BNE CODE_80A6C4
        LDA.W $0004,X
        CLC
        ADC.W $0008,X
        STA.W $0004,X
        STA.B $02
CODE_80A680:
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
        db $20,$38,$A7
CODE_80A6B0:
        LDA.W $000C,X
        BEQ CODE_80A6B8
        JSR.W animateCharacter
CODE_80A6B8:
        TXA
        CLC
        ADC.W #$0010
        TAX
        CPX.W #$1340
        BNE CODE_80A65C
        RTL
CODE_80A6C4:
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
animateCharacter:
        STA.B $12
        LDA.B ($12)
        BMI CODE_80A70A
        CMP.W #$7000
        BCS CODE_80A72B
        CMP.W #$0010
        BCC CODE_80A6F1
        db $A9,$00,$00,$80,$36
CODE_80A6F1:
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
CODE_80A70A:
        STA.B $00
        LDA.W $0000,X
        CMP.B $00
        BEQ CODE_80A71B
        INC.B $12
        INC.B $12
        LDA.B ($12)
        BRA CODE_80A727
CODE_80A71B:
        LDA.W #$FFFF
        STA.W $0000,X
        LDA.B $12
        CLC
        ADC.W #$0004
CODE_80A727:
        STA.W $000C,X
        RTS
        db $29,$FF,$0F,$25,$54,$D0,$D7,$A5,$12,$1A,$1A,$80,$EF,$C2,$20,$99
        db $06,$01,$18,$69,$02,$00,$99,$0A,$01,$18,$69,$02,$00,$99,$02,$01
        db $18,$69,$10,$00,$99,$0E,$01,$A5,$00,$99,$00,$01,$18,$69,$08,$00
        db $99,$04,$01,$38,$E9,$08,$00,$18,$69,$00,$08,$99,$08,$01,$18,$69
        db $10,$08,$99,$0C,$01,$5A,$98,$4A,$4A,$4A,$4A,$A8,$E2,$20,$A9,$28
        db $99,$00,$03,$C2,$20,$7A,$98,$18,$69,$10,$00,$A8,$60
; [OAM] Sets up battle sprite with special attributes. Entry: A=tile data, $00=X pos, Y=OAM slot. Sets up 4 OAM entries with battle flags.
setupBattleSprite:
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
; [Entity] Calculates stat bonus from equipment. Entry: A=character ID. Sums bonuses from all equipped items.
calculateStatBonus:
        REP #$20
        LDA.L $7EEA82
        CMP.W #$001F
        BNE CODE_80A9B8
        db $A9,$02,$00,$22,$2F,$AA,$00,$80,$0B
CODE_80A9B8:
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
        JSL.L externalEncryptionFunc
        REP #$20
        RTL
; [Entity] Checks if character has learned an ability. Entry: A=character ID, X=ability ID. Returns carry set if learned.
checkAbilityLearned:
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
processAIscript:
        PHP
        REP #$20
        CMP.W $09E4
        BNE CODE_80AA3A
        JMP.W $AAC9
CODE_80AA3A:
        STA.W $09E4
        CMP.W #$0080
        BCS CODE_80AA4D
        ASL A
        TAX
        LDA.W $AB17,X
        STA.B $12
        STZ.B $14
        BRA CODE_80AA80
CODE_80AA4D:
        LDY.W #$AACB
        CMP.W #$0100
        BCC CODE_80AA58
        LDY.W #$AAF4
CODE_80AA58:
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
CODE_80AA6F:
        LDA.B ($16)
        BEQ CODE_80AA7A
        STA.B [$12],Y
        INC.B $16
        INY
        BRA CODE_80AA6F
CODE_80AA7A:
        PLA
        ORA.W #$FF00
        STA.B [$12],Y
CODE_80AA80:
        SEP #$20
        STZ.B $81
        LDY.W #$0000
        JSL.L externalUtilityFunc3
        LDY.W #$0001
        JSL.L externalUtilityFunc3
        JSL.L externalGraphicsFunc2
        LDA.L $7EEA88
        AND.B #$08
        JSL.L externalCRC32Func
        JSL.L externalGraphicsFunc1
        JSL.L externalSoundFunc2
        LDA.B $14
        LDY.B $12
        JSL.L externalMemoryFunc2
        LDY.W #$01F4
CODE_80AAB3:
        LDA.B #$00
        DEY
        BNE CODE_80AAB3
        LDY.W #$0000
        LDA.B #$AE
        JSL.L externalEncryptionFunc
        LDY.W #$01F4
CODE_80AAC4:
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
; [Effects] Updates weather visual effect (rain, snow, etc). Entry: A=weather type. Updates OAM for weather particles.
updateWeatherEffect:
        REP #$20
        STX.W $09EC
        STY.W $09EA
        STZ.W $09E8
        TAY
        LDX.W #$1200
CODE_80ABE4:
        LDA.W #$FFFF
        STA.W $0000,X
        TXA
        CLC
        ADC.W #$0008
        TAX
        DEY
        BNE CODE_80ABE4
        RTL
; [Text] Draws text string to screen. Entry: $12/$14=text pointer, $00/$02=position. Handles font rendering, line breaks.
drawTextString:
        REP #$20
        LDX.W #$000F
        LDY.W #$0002
        LDA.W #$0020
        JSL.L updateWeatherEffect
        LDA.W #$0000
        STA.B $14
        LDA.W #$AC79
        STA.B $12
        LDX.W #$1200
        STZ.B $04
        LDY.W #$0010
CODE_80AC15:
        PHY
        JSL.L updateLightningEffect
        AND.W #$0007
        STA.B $00
        JSL.L updateLightningEffect
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
CODE_80AC59:
        PHY
        JSL.L checkSPCBusy
        LDX.W #$0010
        LDY.W #$0000
        JSL.L handleMenuNavigation
        JSL.L updateShadowEffect
        PLY
        DEY
        BNE CODE_80AC59
        JSL.L checkSPCBusy
        JSL.L updateShadowEffect
        RTL
        db $00,$FE,$01,$FE,$02,$FE,$02,$FF,$02,$00,$02,$01,$02,$02,$01,$02
        db $00,$02,$FF,$02,$FE,$02,$FE,$01,$FE,$00,$FE,$FF,$FE,$FE,$FF,$FE
; [Menu] Handles menu navigation logic. Entry: reads controller, updates cursor, processes selections. Called for all menus.
handleMenuNavigation:
        REP #$20
        TXA
        ASL A
        ASL A
        ASL A
        TAX
CODE_80ACA0:
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
CODE_80ACDF:
        LDA.W $1204,X
        STA.B $00
        SEP #$20
        LDA.W $1202,X
        CLC
        ADC.B $00
        AND.W $09EC
        STA.W $1202,X
        REP #$20
CODE_80ACF4:
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
CODE_80AD0B:
        RTL
        db $A0,$3B,$A0,$3B,$A2,$3B,$A2,$3B,$A4,$3B,$A6,$3B,$A8,$3B,$AA,$3B
        db $A8,$3B,$A6,$3B,$A4,$3B,$A2,$3B,$A2,$3B,$A0,$3B,$A0,$3B,$80,$3B
        db $08,$09,$06,$12,$04,$07,$11,$11,$0F,$0E,$0E,$0D,$0C,$1E,$1C
        REP #$20
        STZ.B $12
        LDA.W #$0002
        STA.W $09E6
        LDA.L $7EEA82
        CMP.W #$0027
        BNE CODE_80AD51
        STZ.W $09E6
CODE_80AD51:
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
CODE_80AD69:
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
CODE_80AD95:
        STA.B $12
        LDX.B $12
        LDA.L $0BE164,X
        AND.W #$00FF
        STA.B $23
        LDY.W #$1000
        JSL.L $00AEDD
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
CODE_80ADC9:
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
CODE_80ADF5:
        STA.B $12
        LDX.B $12
        LDA.L $0BE164,X
        STA.B $25
        LDY.W #$1000
        JSL.L $00AEDD
        LDA.W $104D
        AND.W #$00FF
        STA.B $28
        LDX.B $22
        LDY.B $24
        LDA.B $26
        CMP.B $28
        BCS CODE_80AE1C
        db $A4,$22,$A6,$24
CODE_80AE1C:
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
CODE_80AE39:
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
CODE_80AE50:
        STA.B $24
        REP #$20
        LDA.B $22
        STA.W $1204
        LDA.B $24
        STA.W $1206
        LDY.W #$0000
        LDA.W #$0002
        JSR.W $AEAE
        LDA.W #$0004
        JSR.W $AEAE
        LDA.W #$0006
        JSR.W $AEAE
        LDY.W #$0002
        LDA.W #$0004
        JSR.W $AEAE
        LDA.W #$0006
        JSR.W $AEAE
        LDY.W #$0004
        LDA.W #$0006
        JSR.W $AEAE
        REP #$20
        LDY.W #$0000
        LDX.W #$0000
        STZ.W $1210
CODE_80AE96:
        LDA.W $1200,Y
        CMP.W #$FFFF
        BEQ CODE_80AEA6
        STA.W $1208,X
        INX
        INX
        INC.W $1210
CODE_80AEA6:
        INY
        INY
        CPY.W #$0008
        BNE CODE_80AE96
        RTL
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
CODE_80AEDB:
        PLP
        RTS
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
CODE_80AEF0:
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
        PHP
        SEP #$20
        STA.B $22
        STY.B $24
        LDX.W #$0000
CODE_80AF0B:
        LDA.L $7EEA00,X
        CMP.B #$80
        BCC CODE_80AF21
        db $29,$7F,$C5,$22,$D0,$08,$A5,$24,$09,$80,$9F,$00,$EA,$7E
CODE_80AF21:
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
; [Physics] Calculates MP cost for spell. Entry: A=spell ID. Returns A=MP cost based on spell level and character stats.
calculateSpellCost:
        PHP
        REP #$20
        STZ.B $1C
        LDY.W #$0008
        STA.B $00
CODE_80AF74:
        LDA.B [$12],Y
        BNE CODE_80AF7B
        db $4C,$0A,$B0
CODE_80AF7B:
        CMP.B $00
        BEQ CODE_80AF87
        TYA
        CLC
        ADC.W #$0008
        TAY
        BRA CODE_80AF74
CODE_80AF87:
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
CODE_80AFAF:
        LDA.B [$12]
        INC.B $12
        AND.W #$00FF
        BEQ CODE_80B005
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
        JSR.W castSpell
        BRA CODE_80AFAF
CODE_80AFD9:
        PHA
        LDA.B $0A
        JSR.W castSpell
        INC.B $0A
        PLA
        DEC A
        BNE CODE_80AFD9
        BRA CODE_80AFAF
CODE_80AFE7:
        LDA.B [$12]
        INC.B $12
        AND.W #$00FF
CODE_80AFEE:
        PHA
        LDA.B $06
        JSR.W castSpell
        PLA
        DEC A
        BNE CODE_80AFEE
        BRA CODE_80AFAF
CODE_80AFFA:
        AND.W #$007F
        CLC
        ADC.B $06
        JSR.W castSpell
        BRA CODE_80AFAF
CODE_80B005:
        LDA.W #$0000
        PLP
        RTL
        db $A9,$01,$00,$28,$6B
; [Entity] Casts spell in battle. Entry: A=caster ID, X=spell ID, Y=target. Deducts MP, applies spell effects.
castSpell:
        CMP.W #$1000
        BCC CODE_80B04B
        STA.B $1B
        ASL A
        ASL A
        ASL A
        ASL A
        CMP.W #$8000
        BCS CODE_80B033
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
        BRA CODE_80B06C
CODE_80B033:
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
        BRA CODE_80B06C
CODE_80B04B:
        ASL A
        ASL A
        ASL A
        ASL A
        CMP.W #$8000
        BCS CODE_80B05F
        CLC
        ADC.B $16
        STA.B $1A
        LDA.B $18
        STA.B $1C
        BRA CODE_80B06C
CODE_80B05F:
        AND.W #$7FFF
        CLC
        ADC.B $16
        STA.B $1A
        LDA.B $18
        INC A
        STA.B $1C
CODE_80B06C:
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
updateTurnOrder:
        REP #$20
        LDX.W #$0000
        LDY.W #$0400
        LDA.W #$03FF
CODE_80B0B3:
        STA.L $7FB000,X
        INX
        INX
        DEY
        BNE CODE_80B0B3
        LDX.W #$0040
        LDY.W #$0380
        LDA.W #$0000
CODE_80B0C5:
        STA.L $7FB000,X
        INX
        INX
        INC A
        DEY
        BNE CODE_80B0C5
        LDA.W #$7800
        STA.B $78
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSL.L updateShadowEffect
        SEP #$20
        LDA.B #$60
        STA.W $210B
        STA.B $73
        LDA.B #$7C
        STA.W $2108
        REP #$20
        RTL
; [Script] Parses script/event data from ROM. Entry: $12/$14=script pointer, A=command. Executes script commands.
parseScriptData:
        PHP
        REP #$20
        AND.W #$00FF
        STA.B $02
        LDA.B [$12]
        CMP.W #$4245
        BNE CODE_80B128
        LDY.W #$0003
        LDA.B [$12],Y
        STA.B $08
        LDY.W #$0008
        LDA.W #$0000
        STA.B $00
CODE_80B10F:
        LDA.B [$12],Y
        AND.W #$00FF
        CMP.B $02
        BEQ CODE_80B12D
        TYA
        CLC
        ADC.W #$0004
        TAY
        INC.B $00
        LDA.B $00
        CMP.B $08
        BEQ CODE_80B128
        BRA CODE_80B10F
        db $A2,$00,$00,$28,$6B
CODE_80B12D:
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
        BCC CODE_80B146
        db $09,$00,$80,$E6,$14
CODE_80B146:
        STA.B $12
        LDY.W #$0000
        LDX.W #$0000
        SEP #$20
CODE_80B150:
        LDA.B [$12],Y
        BEQ CODE_80B15C
        INY
        STA.L $7E2000,X
        INX
        BRA CODE_80B150
CODE_80B15C:
        INY
        LDA.B [$12],Y
        BNE CODE_80B164
        JMP.W $B1E9
CODE_80B164:
        CMP.B #$E0
        BCS CODE_80B1B4
        CMP.B #$C0
        BCS CODE_80B18D
        CMP.B #$80
        BCS CODE_80B180
        INY
        STA.B $00
        LDA.B #$00
CODE_80B175:
        STA.L $7E2000,X
        INX
        DEC.B $00
        BNE CODE_80B175
        BRA CODE_80B150
CODE_80B180:
        AND.B #$1F
        STA.B $00
        PHY
        DEY
        DEY
        LDA.B [$12],Y
        PLY
        INY
        BRA CODE_80B175
        db $29,$1F,$85,$00,$5A,$88,$88,$88,$B7,$12,$85,$02,$C8,$B7,$12,$85
        db $03,$7A,$C8,$A5,$02,$9F,$00,$20,$7E,$E8,$A5,$03,$9F,$00,$20,$7E
        db $E8,$C6,$00,$D0,$EE,$80,$9C
        db $29,$1F,$85,$00,$5A,$88,$88,$88,$88,$B7,$12,$85,$02,$C8,$B7,$12
        db $85,$03,$C8,$B7,$12,$85,$04,$7A,$C8,$A5,$02,$9F,$00,$20,$7E,$E8
        db $A5,$03,$9F,$00,$20,$7E,$E8,$A5,$04,$9F,$00,$20,$7E,$E8,$C6,$00
        db $D0,$E7,$4C,$50,$B1
        DEX
        STX.B $00
        LDX.W #$0000
        LDA.B #$00
CODE_80B1F1:
        CLC
        ADC.L $7E2000,X
        STA.L $7E2000,X
        INX
        CPX.B $00
        BNE CODE_80B1F1
        PLP
        RTL
; [GameState] Checks if story event flag is set. Entry: A=flag ID. Returns carry set if flag is true.
checkEventFlag:
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
setEventFlag:
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
        JSL.L monitorParty
        JSR.W absoluteValue
        PLP
        RTL
; [Script] Handles cutscene playback. Entry: A=cutscene ID. Plays script, moves characters, displays dialogue.
handleCutscene:
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
        JSL.L monitorParty
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
        JSL.L monitorParty
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
        JSL.L monitorParty
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
        JSL.L monitorParty
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
fadeToBlack:
        REP #$20
        STZ.B $6F
        LDA.W $0E25
        AND.W #$00FF
        BNE CODE_80B54D
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
        BRA CODE_80B581
CODE_80B54D:
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
CODE_80B581:
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
waitForButton:
        PHP
        REP #$20
        STZ.W $09FC
        STZ.W $09FE
        LDX.W #$0000
        LDA.W #$0000
CODE_80B5C7:
        STA.L $7E9000,X
        INX
        INX
        CPX.W #$0800
        BNE CODE_80B5C7
        STZ.W $0A1C
        PLP
        RTL
; [Menu] Draws window frame for menus/dialogue. Entry: $00/$02=position, $04/$06=size. Renders border tiles.
drawWindow:
        PHP
        REP #$20
        LDA.W $09F0
        STA.W $09FC
        LDA.W $09F2
        STA.W $09FE
        JSR.W clampValue
        TXA
        STA.B $02
        CLC
        ADC.W #$0040
        STA.B $04
        LDY.W #$3101
        LDA.B $6F
        BNE CODE_80B5FC
        LDY.W #$3105
CODE_80B5FC:
        TYA
        STA.B $22
        STA.L $7E9000,X
        INX
        INX
        LDY.W $09F4
        DEY
        DEY
        INC A
CODE_80B60B:
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE CODE_80B60B
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
CODE_80B62A:
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
        BNE CODE_80B62A
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
CODE_80B667:
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE CODE_80B667
        LDA.B $22
        CLC
        ADC.W #$C000
        STA.L $7E9000,X
        PLP
        RTS
; [Menu] Handles inventory management screen. Entry: displays items, allows equip/use/drop. Updates inventory array.
handleInventory:
        STZ.W $0A08
        STZ.W $0A16
        STZ.W $0A18
        SEP #$20
        LDY.W #$0000
        LDX.W #$0000
CODE_80B68D:
        LDA.B [$14],Y
        BNE CODE_80B694
        JMP.W $BBB8
CODE_80B694:
        CMP.B #$09
        BCC CODE_80B6A3
        CMP.B #$FF
        BEQ CODE_80B6D6
        STA.W $0400,X
        INX
        INY
        BRA CODE_80B68D
CODE_80B6A3:
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
        BRA CODE_80B68D
CODE_80B6D6:
        INY
        LDA.B [$14],Y
        DEY
        CMP.B #$80
        BCS CODE_80B6E1
        JMP.W $B775
CODE_80B6E1:
        CMP.B #$F1
        BCC CODE_80B6E8
        JMP.W $B775
CODE_80B6E8:
        CMP.B #$C0
        BCC CODE_80B6EF
        JMP.W $BB33
CODE_80B6EF:
        REP #$20
        AND.W #$003F
        ASL A
        ASL A
        CLC
        ADC.W #$B701
        STA.B $00
        SEP #$20
        JMP.W ($0000)
        JMP.W $B78D
        db $EA
        JMP.W $B79C
        db $EA
        JMP.W $B7AE
        db $EA
        JMP.W $B7CB
        db $EA
        JMP.W $B7DD
        db $EA
        JMP.W $B810
        db $EA
        JMP.W $B94A
        db $EA
        JMP.W $B961
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
        JMP.W $B88B
        db $EA,$4C,$12,$BB,$EA
        JMP.W $B8E8
        db $EA,$4C,$B7,$B8,$EA,$4C,$2D,$B8,$EA,$4C,$F2,$B7,$EA
        JMP.W $BB2A
        db $EA
        JMP.W $B904
        db $EA
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
        JMP.W CODE_80B68D
        JSR.W multiply8x8
        REP #$20
        LDA.B $00
        STA.W $0A08
        SEP #$20
        JMP.W CODE_80B68D
        JSR.W divide16x8
        REP #$20
        LDA.B [$00]
        AND.W #$00FF
        STA.W $0A08
        SEP #$20
        JMP.W CODE_80B68D
        JSR.W multiply8x8
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
        JMP.W CODE_80B68D
        JSR.W divide16x8
        PHY
        REP #$20
        LDA.B [$00]
        TAY
        JSR.W clearMemory
        SEP #$20
        PLY
        JMP.W CODE_80B68D
        JSR.W divide16x8
        PHY
        REP #$20
        LDA.B [$00]
        AND.W #$00FF
        TAY
        JSR.W setMemory
        SEP #$20
        PLY
        JMP.W CODE_80B68D
        db $20,$71,$BB,$5A,$C2,$20,$E6,$00,$A7,$00,$20,$0D,$BD,$C6,$00,$A7
        db $00,$20,$0D,$BD,$E6,$00,$E6,$00,$E2,$20,$7A,$4C,$8D,$B6
        JSR.W divide16x8
        PHY
        REP #$20
        LDA.B [$00]
        AND.W #$00FF
        CMP.W #$0064
        BCC CODE_80B823
        db $A9,$63,$00
CODE_80B823:
        TAY
        JSR.W findMemory
        SEP #$20
        PLY
        JMP.W CODE_80B68D
        db $20,$71,$BB,$5A,$C2,$20,$A0,$20,$00,$A7,$00,$20,$6C,$C2,$85,$04
        db $C0,$00,$00,$F0,$05,$A0,$2D,$00,$80,$03,$A0,$20,$00,$E2,$20,$98
        db $9D,$00,$04,$E8,$C2,$20,$A4,$04,$20,$06,$BD,$E2,$20,$7A,$4C,$8D
        db $B6,$20,$71,$BB,$5A,$C2,$20,$A7,$00,$29,$FF,$00,$C9,$64,$00,$B0
        db $11,$A8,$A9,$25,$00,$9D,$00,$04,$E8,$20,$06,$BD,$E2,$20,$7A,$4C
        db $8D,$B6,$C2,$20,$A8,$20,$FF,$BC,$E2,$20,$7A,$4C,$8D,$B6
        JSR.W divide16x8
        PHY
        REP #$20
        LDA.B [$00]
        CMP.W #$03E8
        BCC CODE_80B89B
        db $A9,$E7,$03
CODE_80B89B:
        TAY
        JSR.W setMemory
        BRA CODE_80B8B1
        db $A8,$20,$06,$BD,$E2,$20,$A9,$20,$9D,$00,$04,$E8,$7A,$4C,$8D,$B6
CODE_80B8B1:
        SEP #$20
        PLY
        JMP.W CODE_80B68D
        db $20,$71,$BB,$5A,$C2,$20,$A0,$20,$00,$A7,$00,$20,$6C,$C2,$85,$04
        db $C0,$00,$00,$F0,$05,$A0,$2D,$00,$80,$03,$A0,$20,$00,$E2,$20,$98
        db $9D,$00,$04,$E8,$C2,$20,$A4,$04,$20,$CF,$BC,$E2,$20,$7A,$4C,$8D
        db $B6
        JSR.W divide16x8
        INC.B $00
        LDA.B [$00]
        PHA
        DEC.B $00
        LDA.B [$00]
        JSR.W initRandomSeed
        LDA.B #$95
        STA.W $0400,X
        INX
        PLA
        JSR.W getRandomNumber
        JMP.W CODE_80B68D
        JSR.W divide16x8
        LDA.B [$00]
        JSR.W initRandomSeed
        JMP.W CODE_80B68D
; [RNG] Initializes random number generator seed. Entry: sets seed based on frame counter.
initRandomSeed:
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
        BRA CODE_80B939
; [RNG] Generates random number. Entry: A=max value. Returns A=random number (0 to max-1). Uses LFSR algorithm.
getRandomNumber:
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
CODE_80B939:
        SEP #$20
CODE_80B93B:
        LDA.B [$00],Y
        INY
        CMP.B #$20
        BEQ CODE_80B948
        STA.W $0400,X
        INX
        BRA CODE_80B93B
CODE_80B948:
        PLY
        RTS
        JSR.W divide16x8
        LDA.B [$00]
        AND.B #$FF
        CMP.B #$0A
        BCC CODE_80B957
        db $A9,$09
CODE_80B957:
        CLC
        ADC.B #$30
        STA.W $0400,X
        INX
        JMP.W CODE_80B68D
        JSR.W divide16x8
CODE_80B964:
        LDA.B [$00]
        BEQ CODE_80B978
        CMP.B #$20
        BEQ CODE_80B978
        STA.W $0400,X
        INX
        REP #$20
        INC.B $00
        SEP #$20
        BRA CODE_80B964
CODE_80B978:
        JMP.W CODE_80B68D
        INY
        INY
        LDA.B [$14],Y
        STA.B $04
        DEY
        JSR.W divide16x8
CODE_80B985:
        LDA.B [$00]
        STA.W $0400,X
        INX
        REP #$20
        INC.B $00
        SEP #$20
        DEC.B $04
        BNE CODE_80B985
        JMP.W CODE_80B68D
        JSR.W copyMemory
        REP #$20
        LDA.W $0A08
        CLC
        ADC.B $00
        STA.W $0A08
        SEP #$20
        JMP.W CODE_80B68D
        db $20,$A7,$BB,$20,$A1,$EE,$C2,$20,$5A,$AC,$0E,$0A,$A5,$00,$99,$00
        db $01,$C8,$C8,$AD,$08,$0A,$99,$00,$01,$C8,$C8,$8C,$0E,$0A,$7A,$E2
        db $20,$4C,$8D,$B6,$20,$A7,$BB,$20,$A1,$EE,$C2,$20,$5A,$AC,$0E,$0A
        db $A5,$00,$99,$00,$01,$C8,$C8,$AD,$08,$0A,$99,$00,$01,$C8,$C8,$A5
        db $00,$18,$69,$10,$00,$99,$00,$01,$C8,$C8,$AD,$08,$0A,$18,$69,$02
        db $00,$99,$00,$01,$C8,$C8,$A5,$00,$18,$69,$00,$10,$99,$00,$01,$C8
        db $C8,$AD,$08,$0A,$18,$69,$20,$00,$99,$00,$01,$C8,$C8,$A5,$00,$18
        db $69,$10,$10,$99,$00,$01,$C8,$C8,$AD,$08,$0A,$18,$69,$22,$00,$99
        db $00,$01,$C8,$C8,$8C,$0E,$0A,$7A,$E2,$20,$4C,$8D,$B6
        JSR.W divide16x8
        LDA.B [$00]
        STA.B $00
        LDA.B [$14],Y
        INY
        CMP.B #$20
        BCC CODE_80BA53
        STA.B $01
        LDA.B $00
        BNE CODE_80BA4F
        JMP.W CODE_80B68D
CODE_80BA4F:
        LDA.B $01
        BRA CODE_80BA62
CODE_80BA53:
        CMP.B $00
        BCS CODE_80BA59
        STA.B $00
CODE_80BA59:
        LDA.B $00
        BNE CODE_80BA60
        JMP.W CODE_80B68D
CODE_80BA60:
        LDA.B #$3E
CODE_80BA62:
        STA.W $0400,X
        INX
        DEC.B $00
        BNE CODE_80BA62
        JMP.W CODE_80B68D
        JSR.W divide16x8
        LDA.B [$00]
        STA.B $00
        LDA.B [$14],Y
        INY
        STA.B $01
        SEC
        SBC.B $00
        BPL CODE_80BA84
        LDA.B $01
        STA.B $00
        LDA.B #$00
CODE_80BA84:
        STA.B $02
        BEQ CODE_80BA92
        LDA.B #$20
CODE_80BA8A:
        STA.W $0400,X
        INX
        DEC.B $02
        BNE CODE_80BA8A
CODE_80BA92:
        LDA.B $00
        BNE CODE_80BA99
        JMP.W CODE_80B68D
CODE_80BA99:
        LDA.B #$3C
CODE_80BA9B:
        STA.W $0400,X
        INX
        DEC.B $00
        BNE CODE_80BA9B
        JMP.W CODE_80B68D
        JSR.W divide16x8
        LDA.B [$00]
        STA.B $00
        LDA.B [$14],Y
        INY
        CLC
        ADC.B $00
        STA.W $0400,X
        INX
        JMP.W CODE_80B68D
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
CODE_80BB07:
        STA.W $0400,X
        INX
        DEC.B $00
        BNE CODE_80BB07
        JMP.W CODE_80B68D
        db $20,$71,$BB,$5A,$C2,$20,$A7,$00,$A8,$E6,$00,$E6,$00,$A7,$00,$20
        db $8E,$BC,$E2,$20,$7A,$4C,$8D,$B6
        JSR.W multiply8x8
        STA.W $0A20
        JMP.W CODE_80B68D
        AND.B #$3F
        STA.B $04
        JSR.W compareStrings
        LDA.B $04
        CMP.B #$30
        BNE CODE_80BB48
        LDA.W $0A08
        BEQ CODE_80BB53
        JMP.W CODE_80B68D
CODE_80BB48:
        LDA.B $54
        AND.B #$3F
        CMP.B $04
        BCS CODE_80BB53
        db $4C,$8D,$B6
CODE_80BB53:
        LDA.B $00
        STA.B $14
        LDA.B $01
        STA.B $15
        LDA.B $02
        STA.B $16
        LDY.W #$0000
        JMP.W CODE_80B68D
; [Math] 8x8 unsigned multiplication. Entry: A=multiplicand, X=multiplier. Returns A=product (16-bit). Uses $4202/$4203.
multiply8x8:
        SEP #$20
        INY
        INY
        STZ.B $01
        LDA.B [$14],Y
        STA.B $00
        INY
        RTS
; [Math] 16÷8 unsigned division. Entry: A=dividend, X=divisor. Returns A=quotient, Y=remainder. Uses $4204-$4206.
divide16x8:
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
compareStrings:
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
; [Memory] Copies memory block. Entry: $12/$14=source, $16/$18=dest, A=length. Uses MVN instruction.
copyMemory:
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
        REP #$20
        STZ.W $0400,X
        INY
        TYA
        CLC
        ADC.B $14
        PHA
        LDA.W $0A18
        BNE CODE_80BBCB
        JMP.W $BC75
CODE_80BBCB:
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
CODE_80BBE9:
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
        BCC CODE_80BC02
        LDY.W #$0005
        AND.W #$7FFF
CODE_80BC02:
        STY.B $1A
        TAY
        LDA.W $0A1C
        BNE CODE_80BC1E
        LDX.W #$0010
CODE_80BC0D:
        LDA.B [$18],Y
        EOR.B $6F
        STA.B [$14]
        INY
        INY
        INC.B $14
        INC.B $14
        DEX
        BNE CODE_80BC0D
        BRA CODE_80BC57
        db $A9,$02,$00,$85,$02,$5A,$A2,$08,$00,$E2,$20,$B7,$18,$87,$14,$E6
        db $14,$87,$14,$C2,$20,$E6,$14,$C8,$C8,$CA,$D0,$ED,$7A,$C8,$A2,$08
        db $00,$E2,$20,$B7,$18,$87,$14,$E6,$14,$87,$14,$C2,$20,$E6,$14,$C8
        db $C8,$CA,$D0,$ED,$88,$C6,$02,$D0,$CC
CODE_80BC57:
        PLY
        CPY.B $00
        BNE CODE_80BBE9
        LDY.W #$6C00
        LDA.W $0A1C
        BEQ CODE_80BC67
        db $A0,$00,$48
CODE_80BC67:
        STY.B $78
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSL.L updateShadowEffect
        LDA.W #$0400
        STA.B $14
        STZ.B $16
        JSR.W calculateChecksum
        REP #$20
        LDA.W $0A16
        BNE CODE_80BC8C
        JSR.W absoluteValue
        STZ.W $0A0E
CODE_80BC8C:
        PLA
        RTL
        db $08,$C2,$20,$64,$00,$84,$06,$85,$08,$A9,$98,$00,$85,$0C,$A9,$80
        db $96,$85,$0A,$20,$5F,$BD,$A9,$0F,$00,$85,$0C,$A9,$40,$42,$85,$0A
        db $20,$5F,$BD,$A9,$01,$00,$85,$0C,$A9,$A0,$86,$85,$0A,$20,$5F,$BD
        db $A9,$00,$00,$85,$0C,$A9,$10,$27,$85,$0A,$20,$5F,$BD,$A4,$06,$80
        db $12,$08,$C2,$20,$64,$00,$80,$0B
; [Memory] Clears memory block to zero. Entry: $12/$14=address, A=length. Uses STZ in loop.
clearMemory:
        PHP
        REP #$20
        STZ.B $00
        LDA.W #$2710
        JSR.W compressData
        LDA.W #$03E8
        JSR.W compressData
CODE_80BCE7:
        LDA.W #$0064
        JSR.W compressData
CODE_80BCED:
        LDA.W #$000A
        JSR.W compressData
        TYA
        SEP #$20
        CLC
        ADC.B #$30
        STA.W $0400,X
        INX
        PLP
        RTS
; [Memory] Fills memory block with value. Entry: $12/$14=address, A=length, X=fill value.
setMemory:
        PHP
        REP #$20
        STZ.B $00
        BRA CODE_80BCE7
; [Memory] Searches memory for value. Entry: $12/$14=address, A=length, X=search value. Returns Y=offset if found.
findMemory:
        PHP
        REP #$20
        STZ.B $00
        BRA CODE_80BCED
        db $C2,$20,$A8,$29,$0F,$00,$48,$98,$4A,$4A,$4A,$4A,$29,$0F,$00,$A8
        db $E2,$20,$B9,$C7,$E0,$9D,$00,$04,$E8,$7A,$B9,$C7,$E0,$9D,$00,$04
        db $E8,$C2,$20,$60
; [Memory] Compresses data using simple RLE. Entry: $12/$14=source, $16/$18=dest. Returns A=compressed size.
compressData:
        STA.B $04
        TYA
        LDY.W #$0000
CODE_80BD37:
        SEC
        SBC.B $04
        BCC CODE_80BD3F
        INY
        BRA CODE_80BD37
CODE_80BD3F:
        CLC
        ADC.B $04
        PHA
        PHP
        SEP #$20
        LDA.B $00
        BNE CODE_80BD54
        TYA
        BNE CODE_80BD52
        LDA.W $0A20
        BRA CODE_80BD58
CODE_80BD52:
        INC.B $00
CODE_80BD54:
        TYA
        CLC
        ADC.B #$30
CODE_80BD58:
        STA.W $0400,X
        INX
        PLP
        PLY
        RTS
        db $A0,$00,$00,$A5,$06,$38,$E5,$0A,$85,$06,$A5,$08,$E5,$0C,$85,$08
        db $90,$03,$C8,$80,$EE,$A5,$06,$18,$65,$0A,$85,$06,$A5,$08,$65,$0C
        db $85,$08,$08,$E2,$20,$A5,$00,$D0,$0A,$98,$D0,$05,$AD,$20,$0A,$80
        db $06,$E6,$00,$98,$18,$69,$30,$9D,$00,$04,$E8,$28,$60
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
CODE_80BDB1:
        LDX.B $02
        LDY.W $09F4
CODE_80BDB6:
        LDA.L $7E9040,X
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE CODE_80BDB6
        LDA.B $02
        CLC
        ADC.W #$0040
        STA.B $02
        DEC.B $00
        BNE CODE_80BDB1
        PLA
        BNE CODE_80BDEF
        LDX.B $02
        LDY.W #$0000
        LDA.B $6F
        BEQ CODE_80BDDE
        LDA.W #$3100
CODE_80BDDE:
        LDY.W $09F4
CODE_80BDE1:
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE CODE_80BDE1
        JSR.W absoluteValue
        PLP
        RTS
        db $AE,$F0,$09,$A8,$20,$40,$C2,$AC,$F4,$09,$A5,$02,$18,$69,$00,$90
        db $85,$02,$A9,$7E,$00,$85,$04,$BF,$00,$90,$7E,$87,$02,$E8,$E8,$E6
        db $02,$E6,$02,$88,$D0,$F1,$20,$0E,$C2,$22,$BE,$E3,$00,$28,$60,$08
        db $C2,$20,$A2
; [Memory] Decompresses RLE-compressed data. Entry: $12/$14=source, $16/$18=dest. Returns A=decompressed size.
decompressData:
        BRK #$00
        LDY.W #$001E
        JSR.W calculateSine
        LDA.W #$0000
        LDY.W #$0080
CODE_80BE30:
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE CODE_80BE30
        PLP
        RTS
; [Memory] Calculates checksum of data block. Entry: $12/$14=data, A=length. Returns A=checksum (16-bit sum).
calculateChecksum:
        REP #$20
        LDA.W $0A0C
        STA.W $0A0A
        STZ.W $0A10
        STZ.W $0A06
        JSR.W clampValue
        STZ.W $0A1E
CODE_80BE4F:
        LDA.B [$14]
        INC.B $14
        AND.W #$00FF
        BNE CODE_80BE5B
        JMP.W $BF5E
CODE_80BE5B:
        CMP.W #$00FF
        BNE CODE_80BE63
        JMP.W $BF7D
CODE_80BE63:
        CMP.W #$0090
        BNE CODE_80BE6B
        JMP.W CODE_80BF01
CODE_80BE6B:
        CMP.W #$00D0
        BEQ CODE_80BEBB
        CMP.W #$00CE
        BEQ CODE_80BE4F
CODE_80BE75:
        JSR.W checkZero
        INC.W $0A10
        LDA.W $0A0A
        BEQ CODE_80BE88
        JSR.W compareValues
        LDA.B $82
        BPL CODE_80BE88
        RTS
CODE_80BE88:
        LDA.W $0A06
        BNE CODE_80BE92
        INX
        INX
        INC.W $09FC
CODE_80BE92:
        LDA.W $09FC
        DEC A
        CMP.W $09F8
        BCC CODE_80BE4F
        LDA.W $0A1E
        BNE CODE_80BE4F
        LDA.B [$14]
        AND.W #$00FF
        CMP.W #$0091
        BEQ CODE_80BEFB
        CMP.W #$0093
        BEQ CODE_80BEFB
        CMP.W #$0094
        BEQ CODE_80BEFB
        CMP.W #$00A0
        BEQ CODE_80BEFB
        BRA CODE_80BF01
CODE_80BEBB:
        LDA.W $0A1C
        BNE CODE_80BEDC
        LDA.B [$14]
        INC.B $14
        AND.W #$00FF
        ASL A
        CLC
        ADC.W #$0180
        PHA
        JSR.W checkZero
        INC.W $0A10
        INX
        INX
        INC.W $09FC
        PLA
        INC A
        BRA CODE_80BE75
        db $A7,$14,$E6,$14,$29,$FF,$00,$0A,$0A,$18,$69,$00,$03,$48,$20,$56
        db $C1,$EE,$10,$0A,$E8,$E8,$EE,$FC,$09,$68,$1A,$1A,$4C,$75,$BE
CODE_80BEFB:
        STA.W $0A06
        JMP.W CODE_80BE4F
CODE_80BF01:
        LDA.W $09FE
        CMP.W #$003E
        BNE CODE_80BF2F
        db $A9,$1E,$00,$20,$9C,$BD,$A9,$1F,$00,$20,$9C,$BD,$20,$1E,$BE,$AD
        db $04,$0A,$18,$69,$02,$00,$8D,$04,$0A,$CD,$F6,$09,$90,$06,$20,$7F
        db $C2,$9C,$04,$0A,$80,$1D
CODE_80BF2F:
        CLC
        ADC.W #$0002
        CMP.W $09FA
        BCC CODE_80BF49
        JSR.W calculateCosine
        LDA.W #$0000
        JSR.W $BD9C
        LDA.W #$0000
        JSR.W $BD9C
        BRA CODE_80BF4C
CODE_80BF49:
        STA.W $09FE
CODE_80BF4C:
        LDA.W $09F0
        STA.W $09FC
        STZ.W $0A06
        STZ.W $0A10
        JSR.W clampValue
        JMP.W CODE_80BE4F
        LDA.W $09FE
        CMP.W #$003E
        BNE CODE_80BF7C
        db $A9,$1E,$00,$20,$9C,$BD,$A9,$1F,$00,$20,$9C,$BD,$AD,$FA,$09,$38
        db $E9,$02,$00,$8D,$FE,$09
CODE_80BF7C:
        RTS
        LDA.B [$14]
        INC.B $14
        AND.W #$00FF
        CMP.W #$00F0
        BCS CODE_80BFF1
        CMP.W #$0080
        BEQ CODE_80BF94
        AND.W #$001F
        STA.W $09FC
CODE_80BF94:
        LDA.B [$14]
        AND.W #$00FF
        CMP.W #$0080
        BCS CODE_80BFA9
        AND.W #$001F
        STA.W $09FE
        STZ.W $0A06
        BRA CODE_80BFBA
CODE_80BFA9:
        AND.W #$003F
        STA.B $00
        LDA.W $09FE
        SEC
        SBC.B $00
        STA.W $09FE
        STZ.W $0A06
CODE_80BFBA:
        INC.B $14
        JSR.W clampValue
        JMP.W CODE_80BE4F
CODE_80BFC2:
        LDA.B [$14]
        AND.W #$00FF
        INC.B $14
        CMP.W #$0001
        BNE CODE_80BFD4
        STZ.W $0A1E
        JMP.W CODE_80BE4F
CODE_80BFD4:
        SEP #$20
        DEC A
        ASL A
        ASL A
        CLC
        ADC.B #$21
        STA.W $0A1F
        REP #$20
        JMP.W CODE_80BE4F
CODE_80BFE4:
        LDA.B [$14]
        AND.W #$00FF
        INC.B $14
        JSR.W compareValues
        JMP.W CODE_80BE4F
CODE_80BFF1:
        CMP.W #$00FF
        BEQ CODE_80C022
        CMP.W #$00FE
        BEQ CODE_80C028
        CMP.W #$00FD
        BEQ CODE_80C02D
        CMP.W #$00FC
        BEQ CODE_80C053
        CMP.W #$00FB
        BEQ CODE_80C041
        CMP.W #$00FA
        BNE CODE_80C015
        INC.W $0A16
        JMP.W $BF5E
CODE_80C015:
        CMP.W #$00F1
        BEQ CODE_80BFC2
        CMP.W #$00F2
        BEQ CODE_80BFE4
        db $4C,$4F,$BE
CODE_80C022:
        JSL.L monitorParty
        BRA CODE_80BFBA
CODE_80C028:
        JSR.W calculateCosine
        BRA CODE_80BFBA
CODE_80C02D:
        LDA.B [$14]
        AND.W #$00FF
        CMP.W #$00FF
        BNE CODE_80C03B
        db $AF,$84,$EA,$7E
CODE_80C03B:
        STA.W $0A0A
        JMP.W CODE_80BFBA
CODE_80C041:
        SEP #$20
        LDA.B [$14]
        ASL A
        ASL A
        ASL A
        CLC
        ADC.B #$20
        STA.W $0A03
        REP #$20
        JMP.W CODE_80BFBA
CODE_80C053:
        LDA.B [$14]
        AND.W #$00FF
        CMP.W #$0080
        BCS CODE_80C0C9
        STA.W $0A12
        LDA.W $09FE
        STA.B $22
        STZ.W $0A08
CODE_80C068:
        LDA.W $0A08
        ASL A
        CLC
        ADC.B $22
        STA.W $09FE
        JSR.W calculateDistance
        LDA.B $50
        AND.W #$0400
        BEQ CODE_80C08D
        JSR.W incrementCounter3
        LDA.W $0A08
        INC A
        CMP.W $0A12
        BEQ CODE_80C08D
        STA.W $0A08
        BRA CODE_80C068
CODE_80C08D:
        LDA.B $50
        AND.W #$0800
        BEQ CODE_80C0A1
        db $20,$47,$C1,$AD,$08,$0A,$F0,$05,$CE,$08,$0A,$80,$C7
CODE_80C0A1:
        LDA.B $50
        AND.W #$8000
        BEQ CODE_80C0B4
        db $A9,$02,$00,$20,$4A,$C1,$9C,$08,$0A,$4C,$BA,$BF
CODE_80C0B4:
        LDA.B $50
        AND.W #$0080
        BNE CODE_80C0BD
        db $80,$AB
CODE_80C0BD:
        LDA.W #$0001
        JSR.W incrementCounter8
        INC.W $0A08
        JMP.W CODE_80BFBA
CODE_80C0C9:
        AND.W #$007F
        STA.W $0A12
        LDA.W $09FC
        STA.B $24
        LDA.W $0A08
        STA.B $22
        STZ.W $0A08
CODE_80C0DC:
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
        JSR.W calculateDistance
        LDA.B $50
        AND.W #$0100
        BEQ CODE_80C114
        JSR.W incrementCounter3
        LDA.W $0A08
        INC A
        CMP.W $0A12
        BEQ CODE_80C114
        STA.W $0A08
        BRA CODE_80C0DC
CODE_80C114:
        LDA.B $50
        AND.W #$0200
        BEQ CODE_80C128
        JSR.W incrementCounter3
        LDA.W $0A08
        BEQ CODE_80C128
        DEC.W $0A08
        BRA CODE_80C0DC
CODE_80C128:
        LDA.B $50
        AND.W #$8000
        BEQ CODE_80C13B
        LDA.W #$0002
        JSR.W incrementCounter8
        STZ.W $0A08
        JMP.W CODE_80BFBA
CODE_80C13B:
        LDA.B $50
        AND.W #$0080
        BEQ CODE_80C145
        JMP.W CODE_80C0BD
CODE_80C145:
        BRA CODE_80C0DC
; [Timer] Increments counter at $81. Entry: A=value. Similar to incrementCounter but with different entry.
incrementCounter3:
        LDA.W #$0003
; [Timer] Increments 8-bit counter at $81. Entry: A=value (8-bit).
incrementCounter8:
        SEP #$20
        INC A
        STA.B $81
        REP #$20
        RTS
; [Helper] Wrapper for checkZero function. Entry: A=value. Returns via RTL.
checkZeroWrapper:
        JSR.W checkZero
        RTL
; [Helper] Checks if value is zero. Entry: A=value. Returns Z flag set if zero.
checkZero:
        CMP.W #$0000
        BNE CODE_80C170
        LDA.B $6F
        BEQ CODE_80C170
        LDA.W $0A1C
        BNE CODE_80C18F
        LDA.W #$0100
        STA.L $7E9000,X
        STA.L $7E9040,X
        RTS
CODE_80C170:
        PHA
        LDA.W $0A1E
        BNE CODE_80C1A6
        LDA.W $0A1C
        BNE CODE_80C18F
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
        db $68,$C9,$80,$01,$B0,$01,$0A,$18,$6D,$02,$0A,$48,$9F,$00,$90,$7E
        db $68,$1A,$9F,$40,$90,$7E,$60
CODE_80C1A6:
        PLA
        SEC
        SBC.W #$0020
        CLC
        ADC.W $0A1E
        STA.L $7E9000,X
        RTS
; [Math] Compares two 16-bit values. Entry: A=value1, X=value2. Returns flags for signed comparison.
compareValues:
        REP #$20
        STA.W $0A2E
        LDA.B $14
        STA.W $0A28
        LDA.B $16
        STA.W $0A2A
        STX.W $0A2C
        JSR.W absoluteValue
CODE_80C1C9:
        DEC.W $0A2E
        LDA.W $0A2E
        BEQ CODE_80C200
        LDA.B $6A
        AND.W #$00FF
        CMP.W #$0001
        BNE CODE_80C1DF
        JSL.L checkSPCBusy
CODE_80C1DF:
        JSL.L updateTransparency
        LDA.B $4E
        AND.W #$0030
        BNE CODE_80C200
        LDA.B $82
        BEQ CODE_80C1F5
        LDA.B $4E
        AND.W #$3000
        BNE CODE_80C1FB
CODE_80C1F5:
        JSL.L updateShadowEffect
        BRA CODE_80C1C9
CODE_80C1FB:
        LDA.W #$FFFF
        STA.B $82
CODE_80C200:
        LDA.W $0A28
        STA.B $14
        LDA.W $0A2A
        STA.B $16
        LDX.W $0A2C
        RTS
; [Math] Calculates absolute value. Entry: A=value (16-bit signed). Returns A=absolute value.
absoluteValue:
        PHP
        SEP #$20
        INC.B $57
        JSL.L updateShadowEffect
        PLP
        RTS
; [Math] Negates value (two's complement). Entry: A=value. Returns A=-value.
negateValue:
        REP #$20
        LDX.W $09FC
        LDA.W $09FE
        CLC
        ADC.W $0A00
        TAY
        CPY.W #$003E
        BNE CODE_80C230
        db $AC,$FA,$09,$88,$88
CODE_80C230:
        JMP.W calculateSine
; [Math] Clamps value to range. Entry: A=value, X=min, Y=max. Returns A=clamped value.
clampValue:
        REP #$20
        LDX.W $09FC
        LDA.W $09FE
        CLC
        ADC.W $0A00
        TAY
; [Math] Calculates sine value using lookup table. Entry: A=angle (0-255). Returns A=sine value (8.8 fixed point).
calculateSine:
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
; [Math] Calculates cosine value (sine of angle+64). Entry: A=angle (0-255). Returns A=cosine value.
calculateCosine:
        LDA.W $0A10
        BNE CODE_80C285
        db $60
CODE_80C285:
        JSR.W interpolateValue
        LDA.W $0A06
        BEQ CODE_80C299
        db $20,$19,$C2,$AD,$06,$0A,$20,$56,$C1,$20,$0E,$C2
CODE_80C299:
        RTS
; [Math] Linear interpolation between values. Entry: A=start, X=end, Y=factor (0-255). Returns A=interpolated value.
interpolateValue:
        PHP
        REP #$20
CODE_80C29D:
        JSR.W calculateDistance
        LDA.B $50
        AND.W #$F0F0
        BEQ CODE_80C29D
        PLP
        RTS
; [Math] Calculates distance between two points. Entry: $00-$01=point1, $02-$03=point2. Returns A=distance.
calculateDistance:
        PHP
        REP #$20
        JSL.L updateTransparency
        STZ.B $0E
CODE_80C2B2:
        JSR.W negateValue
        LDY.W #$003E
        INC.B $0E
        LDA.B $0E
        AND.W #$0010
        BEQ CODE_80C2C4
        LDY.W #$0000
CODE_80C2C4:
        TYA
        JSR.W checkZero
        JSR.W absoluteValue
        JSL.L updateTransparency
        LDA.B $50
        BEQ CODE_80C2B2
        JSR.W negateValue
        LDA.W #$0000
        JSR.W checkZero
        JSR.W absoluteValue
        PLP
        RTS
; [Math] Calculates slope between two points. Entry: A=dx, X=dy. Returns A=slope (fixed point).
calculateSlope:
        REP #$20
        STA.W $0A36
        STX.W $0A38
        STY.W $0A3A
        TYA
        AND.W #$0080
        BEQ CODE_80C327
        INC.W $0A36
        JSR.W readJoypad
        PHA
        DEC.W $0A36
        JSR.W readJoypad
        STA.B $00
        PLA
        SEC
        SBC.B $00
        INC A
        STA.B $16
        JSR.W updateHDMA
        LDX.W #$0000
CODE_80C30E:
        LDA.B [$12]
        STA.L $7E2000,X
        LDA.B $12
        INC A
        INC A
        BNE CODE_80C31F
        INC.B $14
        LDA.W #$8000
CODE_80C31F:
        STA.B $12
        INX
        INX
        CPX.B $16
        BCC CODE_80C30E
CODE_80C327:
        LDA.W $0A3A
        AND.W #$0002
        BNE CODE_80C366
        JSR.W setupHDMATable
        LDY.W #$0006
        LDA.B [$12],Y
        CMP.W #$0020
        BEQ CODE_80C366
        LDX.W #$5000
        LDA.W $0A38
        CMP.W #$2000
        BCC CODE_80C34A
        LDX.W #$2000
CODE_80C34A:
        LDA.W $0A3A
        AND.W #$0010
        BEQ CODE_80C355
        LDX.W #$4000
CODE_80C355:
        LDY.W #$1800
        LDA.W $0A3A
        AND.W #$0040
        BEQ CODE_80C363
        LDY.W #$2000
CODE_80C363:
        JSR.W waitForVBlank2
CODE_80C366:
        LDA.W $0A3A
        AND.W #$0004
        BNE CODE_80C399
        JSR.W readJoypadEdge
        LDA.W #$0007
        STA.B $00
        LDA.W #$0001
        STA.B $02
        LDA.W $0A38
        CMP.W #$2000
        BCC CODE_80C388
        LDA.W #$0002
        STA.B $00
CODE_80C388:
        LDA.W $0A3A
        AND.W #$0001
        BEQ CODE_80C395
        db $A9,$80,$00,$04,$00
CODE_80C395:
        JSL.L enableInterrupts
CODE_80C399:
        LDA.W $0A3A
        AND.W #$0008
        BEQ CODE_80C3A4
        db $4C,$53,$C4
CODE_80C3A4:
        JSR.W readJoypadEdge
        LDA.B $12
        CLC
        ADC.W #$0020
        STA.B $12
        LDA.W $0A3A
        AND.W #$0020
        BNE CODE_80C3BC
        JSR.W acknowledgeIRQ
        BRA CODE_80C3CE
CODE_80C3BC:
        LDX.W #$0000
CODE_80C3BF:
        LDA.L $7FF000,X
        STA.L $7FB000,X
        INX
        INX
        CPX.W #$0800
        BNE CODE_80C3BF
CODE_80C3CE:
        LDA.W #$3F00
        STA.B $06
        LDA.W $0A38
        LDY.W #$7000
        CMP.W #$2000
        BCS CODE_80C3F5
        CMP.W #$0800
        BCC CODE_80C3E6
        LDY.W #$7400
CODE_80C3E6:
        LDA.W $0A3A
        AND.W #$0010
        BEQ CODE_80C3F3
        LDA.W #$3E00
        STA.B $06
CODE_80C3F3:
        BRA CODE_80C3FD
CODE_80C3F5:
        LDY.W #$7800
        LDA.W #$0800
        STA.B $06
CODE_80C3FD:
        LDA.W $0A3A
        AND.W #$0100
        BEQ CODE_80C40A
        db $A9,$00,$20,$14,$06
CODE_80C40A:
        STY.B $78
        LDA.W $0A38
        AND.W #$07FE
        TAX
CODE_80C413:
        PHX
        LDY.B $08
CODE_80C416:
        LDA.B [$12]
        AND.W #$00FF
        INC.B $12
        CMP.W #$00FF
        BNE CODE_80C430
        LDA.B $06
        EOR.W #$4000
        STA.B $06
        LDA.B [$12]
        AND.W #$00FF
        INC.B $12
CODE_80C430:
        ORA.B $06
        STA.L $7FB000,X
        INX
        INX
        DEY
        BNE CODE_80C416
        PLA
        CLC
        ADC.W #$0040
        TAX
        DEC.B $0A
        LDA.B $0A
        BNE CODE_80C413
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSL.L updateShadowEffect
        RTL
; [DMA] Sets up HDMA table for gradient effects. Entry: A=channel, $12/$14=table data. Configures indirect HDMA.
setupHDMATable:
        REP #$20
        LDA.W $0A3A
        AND.W #$0080
        BEQ updateHDMA
        LDA.W #$007E
        STA.B $14
        LDA.W #$2000
        STA.B $12
        RTS
; [DMA] Updates HDMA table values dynamically. Entry: A=channel, X=table offset, Y=new value.
updateHDMA:
        LDA.W #$0024
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.W $0A36
        CMP.W #$0100
        BCC CODE_80C48C
        LDA.W $0A37
        AND.W #$0007
        CLC
        ADC.B $14
        STA.B $14
        LDA.W $0A36
        AND.W #$00FF
CODE_80C48C:
        JSR.W setupNMI
        RTS
; [Input] Reads controller input via auto-read. Entry: none. Returns A=joypad1 state, X=joypad2 state.
readJoypad:
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
; [Input] Reads newly pressed buttons (edge detection). Entry: compares current with previous frame. Returns A=new presses.
readJoypadEdge:
        REP #$20
        JSR.W setupHDMATable
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
waitForVBlank2:
        REP #$20
        STY.B $04
        STZ.B $02
        STX.B $78
        LDY.W #$0000
CODE_80C4E5:
        LDX.W #$0000
CODE_80C4E8:
        LDA.B [$12]
        STA.L $7FB000,X
        INX
        INX
        INC.B $12
        INC.B $12
        CPX.W #$0800
        BNE CODE_80C4E8
        LDA.B $02
        BNE CODE_80C50F
        LDX.W #$0000
        LDY.W #$0010
        LDA.W #$0000
CODE_80C506:
        STA.L $7FB000,X
        INX
        INX
        DEY
        BNE CODE_80C506
CODE_80C50F:
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSL.L updateShadowEffect
        LDA.B $78
        CLC
        ADC.W #$0400
        STA.B $78
        LDA.B $02
        CLC
        ADC.W #$0800
        STA.B $02
        CMP.B $04
        BCC CODE_80C4E5
        RTS
; [Interrupt] Sets up IRQ for raster effects. Entry: A=scanline, X=handler address. Configures $4207-$420A.
setupIRQ:
        REP #$20
        STY.B $04
        STZ.B $02
        STX.B $78
        LDY.W #$0000
CODE_80C53B:
        LDX.W #$0000
CODE_80C53E:
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
        JSL.L updateShadowEffect
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
; [Interrupt] Acknowledges IRQ by reading $4211. Entry: called in IRQ handler. Clears IRQ flag.
acknowledgeIRQ:
        REP #$20
        LDX.W #$0000
        LDA.W #$0000
        LDY.W #$0400
CODE_80C57B:
        STA.L $7FB000,X
        INX
        INX
        DEY
        BNE CODE_80C57B
        RTS
; [Interrupt] Sets up NMI handler. Entry: X=handler address. Stores vector at $00FFEA.
setupNMI:
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
CODE_80C5A3:
        STA.B $12
        PLY
        RTS
; [Interrupt] Enables interrupts (NMI/IRQ). Entry: A=interrupt mask. Writes to $4200.
enableInterrupts:
        REP #$20
        JSR.W setupWRAM
        LDY.W #$0000
CODE_80C5AF:
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
        JSL.L setupTilemap
        BRA CODE_80C5FF
CODE_80C5FC:
        JSR.W setupCGRAM
CODE_80C5FF:
        RTL
; [Interrupt] Disables all interrupts. Entry: writes $00 to $4200.
disableInterrupts:
        REP #$20
        LDA.B $00
        STA.B $22
        LDA.B $02
        STA.B $24
CODE_80C60A:
        LDA.B $22
        STA.B $00
        LDA.B $24
        STA.B $02
        JSR.W setupVRAM
        BEQ CODE_80C61C
        JSR.W setupCGRAM
        BRA CODE_80C60A
CODE_80C61C:
        JSR.W setupCGRAM
        RTL
; [Memory] Sets up WRAM access via $2180. Entry: A=bank, X=address. Configures $2181-$2183.
setupWRAM:
        REP #$20
        LDA.W #$0004
        STA.B $06
        SEP #$20
        STZ.B $04
        LDA.B $00
        CMP.B #$80
        BCS CODE_80C633
        STZ.B $06
CODE_80C633:
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
; [Memory] Copies data to WRAM via $2180. Entry: $12/$14=source, A=length. Uses loop with $2180 writes.
copyToWRAM:
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
CODE_80C663:
        JSR.W readFromWRAM
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
; [Memory] Reads data from WRAM via $2180. Entry: $12/$14=dest, A=length. Uses loop with $2180 reads.
readFromWRAM:
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
; [VRAM] Sets up VRAM address for access. Entry: A=VRAM address. Writes to $2116-$2117.
setupVRAM:
        REP #$20
        JSR.W setupWRAM
        STZ.W $096E
CODE_80C6DE:
        JSR.W uploadSPCProgram
        INX
        JSR.W uploadSPCProgram
        INX
        JSR.W uploadSPCProgram
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
setupCGRAM:
        REP #$20
        LDY.B $02
CODE_80C6FD:
        PHY
        LDA.B $00
        JSR.W copyToWRAM
        JSL.L updateShadowEffect
        PLY
        INC.B $00
        DEY
        BNE CODE_80C6FD
        RTS
; [Music] Uploads SPC700 sound program to APU. Entry: $12/$14=SPC program data. Follows SPC boot protocol.
uploadSPCProgram:
        PHP
        SEP #$20
        LDA.L $7FE800,X
        CMP.L $7FE804,X
        BEQ CODE_80C728
        BCS CODE_80C720
        INC A
        BRA CODE_80C721
CODE_80C720:
        DEC A
CODE_80C721:
        STA.L $7FE800,X
        INC.W $096E
CODE_80C728:
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
sendSPCCommand:
        REP #$20
        LDY.W #$C7AB
        CMP.W #$0019
        BNE CODE_80C838
        LDY.W #$C773
CODE_80C838:
        CMP.W #$000F
        BNE CODE_80C847
        LDA.W #$0001
        JSL.L handleCutscene
        LDY.W #$C793
CODE_80C847:
        CMP.W #$0037
        BNE CODE_80C84F
        db $A0,$CB,$C7
CODE_80C84F:
        CMP.W #$008E
        BNE CODE_80C857
        LDY.W #$C7E3
CODE_80C857:
        CMP.W #$0032
        BNE CODE_80C85F
        LDY.W #$C7FB
CODE_80C85F:
        CMP.W #$00B6
        BNE CODE_80C867
        LDY.W #$C813
CODE_80C867:
        STY.W $096E
        RTL
        db $C2,$20,$9C,$10,$0A,$9C,$06,$0A,$9C,$1E,$0A,$A9,$02,$00,$8D,$FC
        db $09,$A5,$69,$4A,$4A,$4A,$18,$69,$1E,$00,$29,$1E,$00,$8D,$FE,$09
        db $A9,$1D,$00,$85,$28,$20,$33,$C2,$A7,$22,$29,$FF,$00,$E6,$22,$20
        db $56,$C1,$E8,$E8,$C6,$28,$D0,$F0,$A0,$10,$00,$5A,$E2,$20,$E6,$69
        db $E6,$57,$C2,$20,$A9,$05,$00,$22,$DD,$E3,$00,$7A,$88,$D0,$EC,$6B
; [Music] Checks if SPC700 is busy processing. Entry: reads $2140. Returns Z clear if busy.
checkSPCBusy:
        REP #$20
        JSL.L cheatTeleport
        JSR.W waitSPCReady
        JSR.W spawnEntity
        JSR.W processEntityQueue
        JSR.W despawnEntity
        JSL.L setupLargeSprite
        RTL
; [Music] Waits for SPC700 to be ready. Entry: loops until $2140 returns $AA.
waitSPCReady:
        LDA.W #$E0FF
        LDX.W #$0000
CODE_80C8D8:
        STA.W $0100,X
        INX
        INX
        INX
        INX
        CPX.W #$0080
        BNE CODE_80C8D8
        RTS
; [Entity] Processes entity update queue. Entry: scans entity list at $1800, updates positions, animations.
processEntityQueue:
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
        BEQ CODE_80C91D
        STZ.B $06
        LDA.W $0008,X
        BPL CODE_80C914
        AND.W #$7FFF
        STA.B $06
CODE_80C914:
        LDA.B $0A
        AND.W #$0800
        BNE CODE_80C920
        BRA CODE_80C98E
CODE_80C91D:
        JMP.W $CDB4
CODE_80C920:
        PHY
        LDY.W #$0000
        LDA.W $0000,X
        AND.W #$0007
        STA.B $00
        BNE CODE_80C942
        LDA.B $72
        AND.W #$00FF
        CMP.W #$0004
        BNE CODE_80C942
        db $A5,$54,$29,$03,$00,$F0,$03,$7A,$80,$4C
CODE_80C942:
        INC.B $00
        LDA.W $0002,X
        CMP.W $0006,X
        BEQ CODE_80C962
        BCS CODE_80C959
        CLC
        ADC.B $00
        STA.W $0002,X
        LDY.W #$1600
        BRA CODE_80C962
CODE_80C959:
        SEC
        SBC.B $00
        STA.W $0002,X
        LDY.W #$1400
CODE_80C962:
        LDA.W $0004,X
        CMP.W $0008,X
        BEQ CODE_80C980
        BCS CODE_80C977
        CLC
        ADC.B $00
        STA.W $0004,X
        LDY.W #$1000
        BRA CODE_80C980
CODE_80C977:
        SEC
        SBC.B $00
        STA.W $0004,X
        LDY.W #$1200
CODE_80C980:
        TYA
        BNE CODE_80C98D
        LDA.W #$0807
        TRB.B $0A
        LDA.B $0A
        STA.W $0000,X
CODE_80C98D:
        PLY
CODE_80C98E:
        LDA.W $000A,X
        STA.B $04
        LDA.W $000E,X
        STA.B $0C
        LDA.W $000C,X
        BNE CODE_80C9A0
        JMP.W $CA2C
CODE_80C9A0:
        STA.B $00
CODE_80C9A2:
        LDA.B ($00)
        AND.W #$00FF
        STA.B $02
        CMP.W #$0080
        BCC CODE_80C9DC
        BNE CODE_80C9B6
        INC.B $00
        LDA.B ($00)
        BRA CODE_80C9A0
CODE_80C9B6:
        CMP.W #$00FF
        BNE CODE_80C9C8
        INC.B $00
        LDA.B ($00)
        STA.W $000A,X
        INC.B $00
        INC.B $00
        BRA CODE_80C9A2
CODE_80C9C8:
        AND.W #$007F
        AND.B $54
        BNE CODE_80C9D3
        INC.B $00
        BRA CODE_80C9A2
CODE_80C9D3:
        DEC.B $00
        LDA.B ($00)
        AND.W #$00FF
        STA.B $02
CODE_80C9DC:
        INC.B $00
        AND.W #$0040
        BEQ CODE_80C9EC
        db $BD,$00,$00,$49,$00,$80,$9D,$00,$00
CODE_80C9EC:
        LDA.B $02
        AND.W #$0020
        BEQ CODE_80CA06
        db $BD,$04,$00,$3A,$D0,$03,$9D,$00,$00,$9D,$04,$00,$BD,$0E,$00,$1A
        db $9D,$0E,$00
CODE_80CA06:
        LDA.B $02
        AND.W #$001F
        CMP.W #$0010
        BCC CODE_80CA19
        db $29,$0F,$00,$3A,$49,$FF,$FF,$80,$07
CODE_80CA19:
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
        BEQ CODE_80CA4C
        LDA.B $0A
        AND.W #$8000
        BEQ CODE_80CA49
        LDA.B $54
        AND.W #$0010
        BEQ CODE_80CA49
        LDA.B $04
        CLC
        ADC.W #$0002
        STA.B $04
CODE_80CA49:
        JMP.W $CD20
CODE_80CA4C:
        LDA.B $0A
        AND.W #$C000
        BEQ CODE_80CA62
        LDA.B $54
        AND.W #$0010
        BEQ CODE_80CA62
        LDA.B $04
        CLC
        ADC.W #$00C0
        STA.B $04
CODE_80CA62:
        LDA.B $04
        AND.W #$4000
        BEQ CODE_80CA6C
        JMP.W $CBC6
CODE_80CA6C:
        LDA.W $0002,X
        SEC
        SBC.B $60
        STA.B $02
        CMP.W #$FFF8
        BCS CODE_80CA93
        CMP.W #$FFF0
        BCS CODE_80CAB0
        CMP.W #$00E8
        BCS CODE_80CA86
        JMP.W $CB0A
CODE_80CA86:
        CMP.W #$00F8
        BCC CODE_80CAF0
        CMP.W #$0100
        BCC CODE_80CAD0
        JMP.W $CDB4
CODE_80CA93:
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
        JMP.W CODE_80CB22
CODE_80CAB0:
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
        BRA CODE_80CB22
CODE_80CAD0:
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
        BRA CODE_80CB22
CODE_80CAF0:
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
        BRA CODE_80CB22
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
CODE_80CB22:
        LDA.W $0004,X
        SEC
        SBC.B $1E
        CMP.W #$00E6
        BCC CODE_80CB30
        JMP.W $CDB4
CODE_80CB30:
        STA.B $01
        CLC
        ADC.B $06
        CLC
        ADC.W #$0012
        ASL A
        CMP.W #$01F4
        BCC CODE_80CB42
        db $A9,$F4,$01
CODE_80CB42:
        STA.B $1A
        TYA
        LSR A
        STA.B $18
        LDA.B $0C
        AND.W #$000F
        BEQ CODE_80CB68
        DEC A
        BEQ CODE_80CB5E
        LDA.B $44
        AND.W #$1000
        ORA.W #$8BEF
        STA.B $44
        BRA CODE_80CB68
        db $A5,$44,$29,$00,$10,$09,$FF,$C9,$85,$44
CODE_80CB68:
        LDA.B $0D
        AND.W #$000F
        BEQ CODE_80CB7E
        db $18,$69,$81,$89,$85,$48,$A5,$46,$29,$00,$10,$05,$48,$85,$46
CODE_80CB7E:
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
        BCS CODE_80CBED
        CMP.W #$FFF0
        BCS CODE_80CC0E
        CMP.W #$00E8
        BCS CODE_80CBE0
        JMP.W $CC66
CODE_80CBE0:
        CMP.W #$00F8
        BCC CODE_80CC4A
        CMP.W #$0100
        BCC CODE_80CC2E
        JMP.W $CDB4
CODE_80CBED:
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
        JMP.W CODE_80CC7E
CODE_80CC0E:
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
        BRA CODE_80CC7E
CODE_80CC2E:
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
        BRA CODE_80CC7E
CODE_80CC4A:
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
        BRA CODE_80CC7E
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
CODE_80CC7E:
        LDA.W $0004,X
        SEC
        SBC.B $1E
        CMP.W #$00E6
        BCC CODE_80CC8C
        JMP.W $CDB4
CODE_80CC8C:
        STA.B $01
        CLC
        ADC.B $06
        CLC
        ADC.W #$0012
        ASL A
        CMP.W #$01F4
        BCC CODE_80CC9E
        LDA.W #$01F4
CODE_80CC9E:
        STA.B $1A
        TYA
        LSR A
        STA.B $18
        LDA.B $0C
        AND.W #$000F
        BEQ CODE_80CCC4
        DEC A
        BEQ CODE_80CCBA
        LDA.B $44
        AND.W #$1000
        ORA.W #$8BEF
        STA.B $44
        BRA CODE_80CCC4
CODE_80CCBA:
        LDA.B $44
        AND.W #$1000
        ORA.W #$C9FF
        STA.B $44
CODE_80CCC4:
        LDA.B $0D
        AND.W #$000F
        BEQ CODE_80CCDA
        db $18,$69,$81,$89,$85,$48,$A5,$46,$29,$00,$10,$05,$48,$85,$46
CODE_80CCDA:
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
        BCC CODE_80CD3C
        db $4C,$A2,$CD
        db $85,$00,$A9,$00,$10,$04,$04,$80,$02
CODE_80CD3C:
        STA.B $00
        LDA.W $0004,X
        SEC
        SBC.B $1E
        DEC A
        CMP.W #$00E6
        BCC CODE_80CD4D
        db $4C,$A2,$CD
CODE_80CD4D:
        STA.B $01
        CLC
        ADC.B $0C
        CLC
        ADC.W #$0010
        ASL A
        CMP.W #$01F4
        BCC CODE_80CD5F
        db $A9,$F4,$01
CODE_80CD5F:
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
        BRA CODE_80CD89
        STA.B $16
        PHX
        LDX.B $1A
CODE_80CD89:
        LDA.W $1A00,X
        AND.W #$00FF
        BEQ CODE_80CD9C
        INX
        INX
        CPX.W #$0200
        BNE CODE_80CD89
        db $FA,$4C,$A2,$CD
CODE_80CD9C:
        LDA.B $17
        STA.W $1A00,X
        PLX
CODE_80CDA2:
        TXA
        CLC
        ADC.W #$0010
        TAX
        LDA.B $0E
        INC A
        CMP.W #$0020
        BEQ CODE_80CDB3
        JMP.W $C8FC
CODE_80CDB3:
        RTS
        BRA CODE_80CDA2
; [Entity] Spawns new entity in world. Entry: A=entity type, $00/$02=position. Finds free slot in entity list.
spawnEntity:
        PHP
        SEP #$20
        LDY.W #$0200
        LDA.B #$00
CODE_80CDBE:
        STA.W $19FE,Y
        DEY
        DEY
        BNE CODE_80CDBE
        STA.W $1A00
        PLP
        RTS
; [Entity] Removes entity from world. Entry: A=entity ID. Clears entity slot in list.
despawnEntity:
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
CODE_80CDE8:
        LDA.W $19FE,Y
        BNE CODE_80CDF6
        STZ.B $06
        DEY
        DEY
        BNE CODE_80CDE8
        JMP.W CODE_80CE81
CODE_80CDF6:
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
CODE_80CE1B:
        PLA
CODE_80CE1C:
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
CODE_80CE3E:
        ROL.B $00
        LDA.B #$80
        TRB.B $04
        BNE CODE_80CE4A
        LDA.B #$10
        TSB.B $04
CODE_80CE4A:
        LDA.B #$20
        TSB.B $04
        BNE CODE_80CE54
        LDA.B $00
        TRB.B $02
CODE_80CE54:
        ROL.B $00
        BCC CODE_80CE64
        ROL.B $00
        LDA.B $02
        STA.B ($16)
        INC.B $16
        LDA.B #$AA
        STA.B $02
CODE_80CE64:
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
        JMP.W CODE_80CDE8
CODE_80CE81:
        LDA.B $02
        STA.B ($16)
        LDA.B $08
        BEQ CODE_80CE8C
        db $18,$69,$40
CODE_80CE8C:
        STA.W $0A50
        REP #$20
        LDA.W #$E0FF
CODE_80CE94:
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
updateEntityAI:
        REP #$20
        CMP.W #$0000
        BNE CODE_80CF75
        JMP.W $D0E8
CODE_80CF75:
        CMP.W #$0001
        BNE CODE_80CF7D
        JMP.W $D0D4
CODE_80CF7D:
        CMP.W #$0002
        BNE CODE_80CF85
        JMP.W $D1A6
CODE_80CF85:
        CMP.W #$0003
        BNE CODE_80CF8D
        JMP.W $D20D
CODE_80CF8D:
        CMP.W #$0004
        BNE CODE_80CF95
        db $4C,$26,$D2
CODE_80CF95:
        CMP.W #$0005
        BNE CODE_80CF9D
        db $4C,$2E,$D3
CODE_80CF9D:
        CMP.W #$0006
        BNE CODE_80CFA5
        db $4C,$DD,$D2
CODE_80CFA5:
        CMP.W #$0007
        BNE CODE_80CFAD
        JMP.W $D3C5
CODE_80CFAD:
        CMP.W #$0008
        BNE CODE_80CFB5
        db $4C,$F8,$D2
CODE_80CFB5:
        CMP.W #$0009
        BNE CODE_80CFBD
        db $4C,$D8,$D3
CODE_80CFBD:
        CMP.W #$000A
        BNE CODE_80CFC5
        JMP.W $D425
CODE_80CFC5:
        STZ.W $0A7B
        RTL
; [Collision] Checks collisions between entities. Entry: scans entity list, tests bounding boxes.
checkEntityCollision:
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
CODE_80D00A:
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
CODE_80D027:
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
CODE_80D056:
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
CODE_80D073:
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
CODE_80D099:
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
CODE_80D0C0:
        STZ.W $0A6B
CODE_80D0C3:
        LDA.W $0A6B
        LSR A
        LSR A
        LSR A
        STA.B $00
        LDA.B $24
        SEC
        SBC.B $00
        STA.B $24
CODE_80D0D2:
        PLP
        RTL
        REP #$20
        LDX.W #$0000
CODE_80D0D9:
        LDA.L $7EE600,X
        STA.W $1400,X
        INX
        INX
        CPX.W #$0400
        BNE CODE_80D0D9
        RTL
        REP #$20
        LDX.W #$0000
CODE_80D0ED:
        LDA.W $1400,X
        STA.L $7EE600,X
        INX
        INX
        CPX.W #$0400
        BNE CODE_80D0ED
        RTL
; [Physics] Handles damage between entities. Entry: A=attacker ID, X=defender ID. Applies damage, knockback.
handleEntityDamage:
        PHX
        STA.B $06
        LDA.B $02
        AND.W #$0400
        BEQ CODE_80D10B
        LDA.W #$4000
        TSB.B $06
CODE_80D10B:
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
CODE_80D1A9:
        STZ.W $1400,X
        INX
        INX
        CPX.W #$0200
        BCC CODE_80D1A9
        LDX.W #$0000
        LDY.W #$0008
CODE_80D1B9:
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
CODE_80D1D9:
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
CODE_80D1F8:
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
        JSL.L updateWeatherParticles
        LDA.W #$0003
        STA.B $14
        LDA.W #$A4F2
        STA.B $12
        LDA.W #$0008
        STA.B $00
        LDA.W #$0002
        STA.B $02
        JSL.L setupTilemap
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
; [Camera] Updates camera to follow target entity. Entry: A=target entity ID. Smooth scrolling with bounds.
updateCameraFollow:
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
CODE_80D47F:
        JMP.W CODE_80D77A
CODE_80D482:
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
CODE_80D4F9:
        LDA.B $5E
        BEQ CODE_80D51D
        INC A
        BNE CODE_80D509
        LDA.B $5F
        STA.W $2131
        STZ.B $5E
        BRA CODE_80D51D
CODE_80D509:
        STA.W $4355
        LDA.B $5F
        STA.W $2121
        LDA.B #$C0
        STA.W $4352
        LDA.B #$20
        STA.W $420B
        STZ.B $5E
CODE_80D51D:
        LDA.B $57
        BEQ CODE_80D534
        INC A
        BEQ CODE_80D52C
        INC A
        BEQ CODE_80D531
        JSR.W updateParticleSystem
        BRA CODE_80D534
CODE_80D52C:
        JSR.W drawParticles
        BRA CODE_80D534
CODE_80D531:
        JSR.W spawnParticle
CODE_80D534:
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
CODE_80D589:
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
CODE_80D5B3:
        LDA.B $58
        CMP.B #$20
        BCC CODE_80D5DB
        AND.B #$10
        BEQ CODE_80D5C3
        LDA.B $54
        AND.B $59
        BNE CODE_80D5DB
CODE_80D5C3:
        LDA.B $58
        CMP.B #$40
        BCC CODE_80D5CC
        INC A
        BRA CODE_80D5CD
CODE_80D5CC:
        DEC A
CODE_80D5CD:
        STA.B $58
        AND.B #$0F
        BEQ CODE_80D5D9
        CMP.B #$0F
        BEQ CODE_80D5D9
        BRA CODE_80D5DB
CODE_80D5D9:
        STA.B $58
CODE_80D5DB:
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
        db $A5,$54,$29,$03,$80,$E9
CODE_80D607:
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
CODE_80D619:
        LDA.B $76
        BEQ CODE_80D663
        CMP.B #$01
        BNE CODE_80D626
        db $20,$83,$D7,$80,$3D
CODE_80D626:
        CMP.B #$02
        BNE CODE_80D62F
        JSR.W $D7BE
        BRA CODE_80D663
CODE_80D62F:
        CMP.B #$03
        BNE CODE_80D638
        db $20,$4E,$D8,$80,$2B
CODE_80D638:
        CMP.B #$0E
        BNE CODE_80D641
        db $20,$CA,$D8,$80,$22
CODE_80D641:
        CMP.B #$0F
        BNE CODE_80D64A
        db $20,$83,$D8,$80,$19
CODE_80D64A:
        JSR.W drawHealthBars
        BRA CODE_80D663
        db $C2,$20,$A5,$62,$C9,$F8,$00,$B0,$06,$38,$E9,$60,$00,$85,$6D,$E2
        db $20,$4C,$DB,$D6
CODE_80D663:
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
        db $C2,$20,$A5,$54,$4A,$85,$40,$18,$65,$60,$85,$6B,$E2,$20,$A5,$62
        db $38,$E5,$40,$85,$6D,$80,$4C
CODE_80D68F:
        REP #$20
        LDA.B $60
        STA.B $6B
        LDA.B $62
        SEC
        SBC.W #$0110
        STA.B $6D
        SEP #$20
        BRA CODE_80D6DB
        db $C2,$20,$A5,$60,$4A,$85,$6B,$A5,$62,$4A,$85,$6D,$E2,$20,$80,$2A
        db $C2,$20,$A5,$54,$18,$65,$60,$85,$6B,$A5,$54,$4A,$85,$40,$E2,$20
        db $A5,$62,$38,$E5,$40,$85,$6D,$80,$11
CODE_80D6CA:
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
CODE_80D6DB:
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
        db $E2,$20,$A5,$7A,$29,$0F,$F0,$07,$20,$96,$D9,$E2,$20,$80,$02,$64
        db $7A
CODE_80D72E:
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
CODE_80D74A:
        CMP.B #$FF
        BNE CODE_80D752
        LDA.B #$00
        STA.B $7F
CODE_80D752:
        STA.B $80
CODE_80D754:
        LDA.B $81
        BEQ CODE_80D762
        STZ.B $81
        LDY.W #$0002
        DEC A
        JSL.L externalSortFunc
CODE_80D762:
        LDA.B $4C
        BEQ CODE_80D77A
        LDA.B $10
        PHA
        LDA.B #$02
        STA.B $10
        JSR.W updateBloomEffect
        LDA.B $AA
        BEQ CODE_80D777
        db $20,$88,$E6
CODE_80D777:
        PLA
        STA.B $10
CODE_80D77A:
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
CODE_80D7DA:
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
; [HUD] Draws health bars for visible entities. Entry: scans entity list, draws bars above entities.
drawHealthBars:
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
CODE_80D820:
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
; [Effects] Updates particle effects system. Entry: processes particle list, updates positions, lifetimes.
updateParticleSystem:
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
; [Effects] Spawns new particle effect. Entry: A=particle type, $00/$02=position, $04/$06=velocity.
spawnParticle:
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
; [Effects] Draws all active particles to OAM. Entry: scans particle list, creates OAM entries.
drawParticles:
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
; [Transition] Handles map transition (fade out, load new map, fade in). Entry: A=destination map ID.
handleMapTransition:
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
CODE_80DBC6:
        LDA.B $5E
        BEQ CODE_80DBEA
        INC A
        BNE CODE_80DBD6
        LDA.B $5F
        STA.W $2131
        STZ.B $5E
        BRA CODE_80DBEA
        db $8D,$55,$43,$A5,$5F,$8D,$21,$21,$A9,$C0,$8D,$52,$43,$A9,$20,$8D
        db $0B,$42,$64,$5E
CODE_80DBEA:
        LDA.B $57
        BEQ CODE_80DC06
        CMP.B #$FE
        BEQ CODE_80DBFC
        CMP.B #$FF
        BNE CODE_80DC01
        JSR.W drawParticles
        JMP.W CODE_80DC06
CODE_80DBFC:
        JSR.W spawnParticle
        BRA CODE_80DC06
CODE_80DC01:
        JSR.W updateParticleSystem
        BRA CODE_80DC06
CODE_80DC06:
        PLP
        RTL
; [LevelLoad] Loads map data from ROM. Entry: A=map ID. Loads tiles, collision, objects to WRAM.
loadMapData:
        PHA
        PHP
        SEP #$20
        LDA.B $10
        BNE CODE_80DC15
CODE_80DC10:
        LDA.W $4210
        BPL CODE_80DC10
CODE_80DC15:
        PLP
        PLA
        RTL
; [LevelLoad] Sets up objects/NPCs for current map. Entry: reads object data from map, spawns entities.
setupMapObjects:
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
CODE_80DC63:
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
; [Collision] Checks for map triggers (doors, warps, events). Entry: tests player position against trigger areas.
checkMapTrigger:
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
CODE_80DDCE:
        STA.W $2118
        DEY
        BNE CODE_80DDCE
        LDA.W #$2000
        STA.W $2116
        LDY.W #$0800
        LDA.W #$0000
CODE_80DDE0:
        STA.W $2118
        DEY
        BNE CODE_80DDE0
        PLP
        RTL
; [Script] Executes map script when trigger activated. Entry: A=script ID. Runs script commands.
executeMapScript:
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
CODE_80DDFD:
        STA.W $2118
        DEY
        BNE CODE_80DDFD
        PLP
        RTL
; [Animation] Updates animated tiles in tilemap. Entry: cycles through animation frames based on timer.
updateTileAnimation:
        PHP
        REP #$20
        STX.W $2116
        STY.B $00
        LDY.W #$0000
        SEP #$20
        LDA.B #$80
        STA.W $2115
        LDA.W $2115
CODE_80DE1A:
        PHY
        LDX.W #$0008
CODE_80DE1E:
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
CODE_80DE30:
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
; [Effects] Updates water ripple effect. Entry: animates water tiles, applies distortion.
updateWaterEffect:
        PHY
        PHX
        PHA
        PHP
        SEP #$20
        SEP #$20
        REP #$10
        LDA.B #$00
        STA.W $2101
        JSR.W updateFireEffect
        REP #$30
        LDX.W #$0000
        LDY.W #$0100
        LDA.W #$E000
CODE_80DE85:
        STA.W $0100,X
        INX
        INX
        DEY
        BNE CODE_80DE85
        SEP #$20
        LDY.W #$0020
        LDA.B #$AA
CODE_80DE94:
        STA.W $0100,X
        INX
        DEY
        BNE CODE_80DE94
        PLP
        PLA
        PLX
        PLY
        RTL
; [Effects] Updates fire animation effect. Entry: animates flame sprites, light flicker.
updateFireEffect:
        PHY
        PHA
        PHP
        REP #$30
        LDA.W #$0000
        STA.W $2102
        SEP #$20
        LDY.W #$0200
        LDA.B #$00
CODE_80DEB2:
        SEP #$20
        STA.W $2104
        DEY
        BNE CODE_80DEB2
        LDY.W #$0020
        SEP #$20
        LDA.B #$FF
CODE_80DEC1:
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
; [Effects] Updates smoke particle effect. Entry: animates smoke plumes, dissipation.
updateSmokeEffect:
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
; [Effects] Updates lightning flash effect. Entry: random flashes, screen brightening.
updateLightningEffect:
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
; [Effects] Updates weather particles (rain, snow). Entry: moves particles, respawns off-screen.
updateWeatherParticles:
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
; [Effects] Updates day/night cycle lighting. Entry: adjusts palette based on time of day.
updateDayNightCycle:
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
CODE_80E13A:
        LDA.B $66
        STA.W $4209
        PLP
        PLA
        CLI
        RTI
; [Palette] Cycles palette colors for effects. Entry: rotates color values in CGRAM.
updatePaletteCycle:
        RTI
; [Effects] Updates color math for special effects. Entry: adjusts $2130-$2132 registers.
updateColorMath:
        PHP
        REP #$20
        LSR A
        TAX
        LDY.W #$0000
CODE_80E14C:
        LDA.B [$12],Y
        STA.B [$16],Y
        INY
        INY
        DEX
        BNE CODE_80E14C
        PLP
        RTL
; [Effects] Updates screen blend/fade effect. Entry: adjusts transparency levels.
updateBlendEffect:
        PHP
        REP #$20
        PHX
        LSR A
        TAX
        LDY.W #$0000
        PLA
CODE_80E161:
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
; [Effects] Updates motion blur for fast movement. Entry: applies afterimage effect.
updateMotionBlur:
        PHP
        JSL.L loadMapData
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
        JSL.L setupMapObjects
        JSL.L updateWaterEffect
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
updateDepthEffect:
        PHP
        REP #$20
        LDX.W #$E353
        AND.W #$00FF
        BEQ CODE_80E336
        CMP.W #$0002
        BEQ CODE_80E331
        db $A2,$63,$E3,$80,$05
CODE_80E331:
        LDX.W #$E373
        BRA CODE_80E336
CODE_80E336:
        STX.B $12
        LDA.W #$0000
        STA.B $14
        LDX.W #$0000
        LDY.W #$0008
CODE_80E343:
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
; [Effects] Updates lens flare effect for light sources. Entry: calculates flare position, brightness.
updateLensFlare:
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
CODE_80E3A1:
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
; [Effects] Updates dynamic shadow casting. Entry: calculates shadow positions based on light.
updateShadowEffect:
        PHP
        SEP #$20
        LDA.B $10
        CMP.B #$02
        BEQ CODE_80E3D5
        CMP.B #$03
        BEQ CODE_80E3D7
        STZ.B $10
        STZ.B $4A
CODE_80E3CF:
        LDA.B $4A
        BEQ CODE_80E3CF
        INC.B $10
CODE_80E3D5:
        PLP
        RTL
CODE_80E3D7:
        JSL.L handleMapTransition
        BRA CODE_80E3D5
; [Effects] Updates reflection effect on water/mirrors. Entry: renders flipped sprites.
updateReflection:
        PHP
        REP #$20
CODE_80E3E0:
        CMP.W #$0000
        BEQ CODE_80E3EE
        PHA
        JSL.L updateShadowEffect
        PLA
        DEC A
        BRA CODE_80E3E0
CODE_80E3EE:
        PLP
        RTL
; [Effects] Updates transparency levels for objects. Entry: adjusts alpha based on distance/layer.
updateTransparency:
        PHP
        REP #$20
        LDA.B $4E
        PHA
        SEP #$20
CODE_80E3F8:
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
; [Effects] Updates multiple scanline effects. Entry: combines gradient, split, color changes.
updateScanlineEffects:
        PHP
        SEP #$20
        LDY.W #$0400
        LDX.W #$0000
CODE_80E43B:
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
        JSR.W updateCRTEffect
        LDA.W #$8000
        STA.W $000C,X
        LDA.W $0E03
        JSR.W updateVignetteEffect
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
        JSR.W updateCRTEffect
        LDA.W #$8000
        STA.W $000C,X
        LDA.W #$60FF
        STA.W $0000,X
        LDA.W $0E83
        JSR.W updateVignetteEffect
        STA.W $0006,X
        LDA.B $42
        STA.W $0AAB
CODE_80E4A9:
        LDA.W $0E20
        AND.W #$00FF
        BNE CODE_80E4BF
        LDA.W #$3800
        STA.W $0A9B
        LDA.W #$3D00
        STA.W $0A9D
        BRA CODE_80E4CB
CODE_80E4BF:
        LDA.W #$2800
        STA.W $0A9B
        LDA.W #$2D00
        STA.W $0A9D
CODE_80E4CB:
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
; [Effects] Updates raster (per-scanline) effects. Entry: modifies HDMA tables in real-time.
updateRasterEffects:
        PHP
        SEP #$20
        LDY.W #$0400
        LDX.W #$0000
CODE_80E4EB:
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
        JSR.W updateCRTEffect
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
; [Mode7] Updates Mode 7 transformation effects. Entry: rotates, scales background.
updateMode7Effects:
        PHP
        SEP #$20
        STA.W $0E03
        STZ.B $4C
        LDY.W #$0400
        LDX.W #$0000
CODE_80E54B:
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
        JSR.W updateCRTEffect
        LDA.W #$8000
        STA.W $000C,X
        LDA.W $0E03
        JSR.W updateVignetteEffect
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
; [Effects] Updates distortion/warp effect. Entry: applies wave distortion to tilemap.
updateDistortionEffect:
        PHP
        SEP #$20
        STZ.B $4C
        STZ.W $0E22
        REP #$20
        LDX.W #$0000
        LDY.W #$0000
        JSL.L updateChromaEffect
        LDA.W #$0000
        STA.B $42
        LDA.W #$E42A
        STA.B $40
        LDX.W #$1000
        JSR.W updateCRTEffect
        LDA.W #$8000
        STA.W $000C,X
        LDA.W $0E03
        JSR.W updateVignetteEffect
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
; [Effects] Updates chromatic aberration effect. Entry: shifts color channels slightly.
updateChromaEffect:
        STX.W $0A9F
        TYA
        STA.W $0AA1
        CLC
        ADC.W #$007C
        STA.W $0AA3
        RTL
; [Effects] Updates vignette (darkened edges) effect. Entry: adjusts corner darkness.
updateVignetteEffect:
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
CODE_80E5FD:
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
; [Effects] Updates film grain/noise effect. Entry: adds random pixel noise.
updateFilmGrain:
        PHP
        REP #$20
        AND.W #$007F
        JSR.W updateAudioEffects
        PLP
        RTL
; [Effects] Updates CRT screen effect (scanlines, curvature). Entry: simulates old monitor.
updateCRTEffect:
        PHP
        REP #$20
        LDY.W #$0010
        PHX
CODE_80E623:
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
CODE_80E680:
        LDA.W #$0003
        STA.W $000C,X
CODE_80E686:
        PLP
        RTS
; [Effects] Updates bloom/glow effect for bright areas. Entry: blurs bright pixels.
updateBloomEffect:
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
CODE_80E6B9:
        LDA.W #$0100
        STA.B $A5
        STZ.B $9D
        LDA.W $0A93
        STA.B $99
        LDA.W $0A95
        STA.B $9B
        LDX.W #$1000
        LDA.W $0A97
        JSR.W updateInstrument
CODE_80E6D3:
        LDA.W $0A89
        BEQ CODE_80E703
        INC A
        STA.W $0A89
        CMP.W #$001F
        BCC CODE_80E6E4
        STZ.W $0A89
CODE_80E6E4:
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
        JSR.W updateInstrument
CODE_80E703:
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
CODE_80E71D:
        LDA.W $0000,X
        BEQ CODE_80E72A
        PHY
        JSR.W updateDepthOfField
        JSR.W updatePostProcessing
        PLY
CODE_80E72A:
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
CODE_80E745:
        LDA.W $0A9B
        STA.B $A8
        LDA.W $0AA9
        STA.B $8F
        LDX.W #$1000
        LDY.W #$0020
CODE_80E755:
        CPY.W #$0010
        BNE CODE_80E764
        LDA.W $0A9D
        STA.B $A8
        LDA.W $0AAB
        STA.B $8F
CODE_80E764:
        LDA.W $0000,X
        BEQ CODE_80E771
        PHY
        JSR.W updateDepthOfField
        JSR.W updatePostProcessing
        PLY
CODE_80E771:
        TXA
        CLC
        ADC.W #$0020
        TAX
        DEY
        BNE CODE_80E755
CODE_80E77A:
        LSR.B $9F
        LSR.B $9F
        BCC CODE_80E77A
        LDA.B $9F
        STA.B ($3C)
        LDA.W #$F0F0
        LDX.B $3A
CODE_80E789:
        CPX.W #$0280
        BEQ CODE_80E79A
        STA.W $0000,X
        STZ.W $0002,X
        INX
        INX
        INX
        INX
        BRA CODE_80E789
CODE_80E79A:
        LDA.W $0AA1
        BNE CODE_80E7B5
        LDA.W #$F0F0
        LDX.B $3E
CODE_80E7A4:
        CPX.W #$0300
        BEQ CODE_80E7B5
        STA.W $0000,X
        STZ.W $0002,X
        INX
        INX
        INX
        INX
        BRA CODE_80E7A4
CODE_80E7B5:
        PLP
        RTS
; [Effects] Updates depth of field blur. Entry: blurs distant/close objects.
updateDepthOfField:
        LDA.W $0001,X
        AND.W #$0003
        BNE CODE_80E7C0
        RTS
CODE_80E7C0:
        CMP.W #$0001
        BEQ CODE_80E804
        CMP.W #$0003
        BNE CODE_80E7CD
        JMP.W $E84F
CODE_80E7CD:
        LDA.W $0012,X
        BNE CODE_80E7D5
        JMP.W $E845
CODE_80E7D5:
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
CODE_80E804:
        LDA.W $0014,X
        CLC
        ADC.W $0012,X
        BCS CODE_80E811
        STA.W $0014,X
        RTS
CODE_80E811:
        LDA.W $0000,X
        AND.W #$0C00
        BEQ CODE_80E833
        db $BD,$02,$00,$9D,$04,$00,$BD,$16,$00,$9D,$18,$00,$22,$72,$DF,$00
        db $48,$22,$72,$DF,$00,$7A,$20,$5C,$F4,$60
CODE_80E833:
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
CODE_80E877:
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
CODE_80E89B:
        STA.W $0017,X
CODE_80E89E:
        LDA.W $001A,X
        BNE CODE_80E8A6
        JMP.W $E845
CODE_80E8A6:
        RTS
; [Effects] Updates all post-processing effects. Entry: combines multiple visual effects.
updatePostProcessing:
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
CODE_80E8C1:
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
CODE_80E900:
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
CODE_80E91D:
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
CODE_80E958:
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
CODE_80E975:
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
CODE_80E98B:
        LDA.W $0006,X
        CMP.W #$8000
        BCS CODE_80E9A3
        STA.B $40
        LDA.B $A8
        PHA
        STZ.B $A8
        LDA.B $40
        JSR.W updateInstrument
        PLA
        STA.B $A8
        RTS
CODE_80E9A3:
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
CODE_80E9CD:
        LDA.W #$0010
        STA.B $9D
        LDA.B $99
        SEC
        SBC.B $40
        STA.B $99
CODE_80E9D9:
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
CODE_80E9FA:
        BCC CODE_80E9FF
        JMP.W $EAC8
CODE_80E9FF:
        CMP.W #$0080
        BCC CODE_80EA07
        JMP.W $EA6A
CODE_80EA07:
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
CODE_80EA20:
        LDA.B $42
        AND.B #$20
        BEQ CODE_80EA33
        REP #$20
        LDA.B $41
        INC.B $8D
        JSR.W updateInstrument
        BRA CODE_80EA94
        db $E2,$20
CODE_80EA33:
        LDA.B $A7
        BNE CODE_80EA44
        LDA.B $9D
        CMP.B #$10
        BEQ CODE_80EA44
        LDA.B $99
        CLC
        ADC.B #$08
        STA.B $99
CODE_80EA44:
        REP #$20
        LDA.B $41
        INC.B $8D
        JSR.W updateInstrument
        LDA.B $9D
        CMP.W #$0010
        BNE CODE_80EA5F
        LDA.B $99
        CLC
        ADC.W #$0008
        STA.B $99
        JMP.W $E9E9
CODE_80EA5F:
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
        JSR.W updateInstrument
        BRA CODE_80EA94
CODE_80EA80:
        PHA
        AND.W #$000F
        STA.B $40
        PLA
        AND.W #$0070
        ASL A
        CLC
        ADC.B $40
        ORA.W #$2000
        JSR.W updateInstrument
CODE_80EA94:
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
CODE_80EAB3:
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
        JMP.W CODE_80EC14
CODE_80EAD5:
        CMP.W #$00FD
        BNE CODE_80EADD
        JMP.W $EC32
CODE_80EADD:
        CMP.W #$00FC
        BNE CODE_80EAE5
        JMP.W $ED63
CODE_80EAE5:
        CMP.W #$00F1
        BNE CODE_80EAED
        JMP.W $EC75
CODE_80EAED:
        CMP.W #$00F2
        BNE CODE_80EAF5
        JMP.W $ED34
CODE_80EAF5:
        CMP.W #$00F3
        BNE CODE_80EB00
        JSR.W updateTempo
        JMP.W $ED79
CODE_80EB00:
        CMP.W #$00F4
        BNE CODE_80EB0B
        JSR.W updateTempo
        JMP.W $EDA6
CODE_80EB0B:
        CMP.W #$00F5
        BNE CODE_80EB16
        JSR.W updateTempo
        JMP.W $EDD6
CODE_80EB16:
        CMP.W #$00F6
        BNE CODE_80EB21
        JSR.W updateTempo
        JMP.W $EE09
CODE_80EB21:
        CMP.W #$00F7
        BNE CODE_80EB29
        JMP.W CODE_80EA94
CODE_80EB29:
        CMP.W #$00F8
        BNE CODE_80EB31
        JMP.W $EE7A
CODE_80EB31:
        CMP.W #$00FA
        BNE CODE_80EB39
        JMP.W $EEC1
CODE_80EB39:
        CMP.W #$00FB
        BNE CODE_80EB41
        JMP.W $F0F3
CODE_80EB41:
        LDA.B $41
        AND.W #$00FF
        INC.B $8D
        CMP.W #$00E0
        BCC CODE_80EB50
        JMP.W $EBAD
CODE_80EB50:
        CMP.W #$00D0
        BCC CODE_80EB58
        JMP.W $ED10
CODE_80EB58:
        CMP.W #$00C0
        BCC CODE_80EB60
        JMP.W $ECF2
CODE_80EB60:
        CMP.W #$00B0
        BCC CODE_80EB68
        JMP.W $EC9C
CODE_80EB68:
        CMP.W #$00A0
        BCC CODE_80EB70
        JMP.W $EE2C
CODE_80EB70:
        CMP.W #$0090
        BCC CODE_80EB78
        JMP.W $EDA3
CODE_80EB78:
        CMP.W #$0080
        BCC CODE_80EB80
        JMP.W $ED76
CODE_80EB80:
        CMP.W #$0070
        BCC CODE_80EB88
        db $4C,$52,$ED
CODE_80EB88:
        CMP.W #$0060
        BCC CODE_80EB90
        JMP.W $EDD3
CODE_80EB90:
        AND.W #$003F
        PHX
        PHA
        JSR.W updateTempo
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
        CMP.W #$00E1
        BNE CODE_80EBB5
        db $4C,$5E,$EC
CODE_80EBB5:
        CMP.W #$00E2
        BNE CODE_80EBBD
        JMP.W $EC8E
CODE_80EBBD:
        CMP.W #$00E0
        BNE CODE_80EBC9
        LDA.B [$8D]
        STA.B $8D
        JMP.W $E9E9
CODE_80EBC9:
        CMP.W #$00E3
        BNE CODE_80EBD1
        JMP.W $F174
CODE_80EBD1:
        CMP.W #$00E4
        BNE CODE_80EBD9
        JMP.W $F126
CODE_80EBD9:
        CMP.W #$00E5
        BNE CODE_80EBE1
        JMP.W $F162
CODE_80EBE1:
        CMP.W #$00E6
        BNE CODE_80EBE9
        JMP.W $F251
CODE_80EBE9:
        CMP.W #$00E7
        BNE CODE_80EBF1
        JMP.W $F26E
CODE_80EBF1:
        CMP.W #$00E8
        BNE CODE_80EBF9
        JMP.W $F2A8
CODE_80EBF9:
        CMP.W #$00E9
        BNE CODE_80EC01
        JMP.W $F2BF
CODE_80EC01:
        CMP.W #$00EA
        BNE CODE_80EC09
        JMP.W $F2CD
CODE_80EC09:
        CMP.W #$00EB
        BNE CODE_80EC11
        JMP.W $F2D8
CODE_80EC11:
        JMP.W $E9E9
CODE_80EC14:
        SEP #$20
        LDA.W $001C,X
        BNE CODE_80EC23
        LDA.W $001D,X
        STA.W $001C,X
        BRA CODE_80EC2A
CODE_80EC23:
        DEC A
        STA.W $001C,X
        REP #$20
        RTS
CODE_80EC2A:
        REP #$20
        LDA.B $8D
        STA.W $0006,X
        RTS
        LDA.B $A1
        BNE CODE_80EC4A
        LDA.W $001E,X
        BNE CODE_80EC42
        db $A5,$8D,$3A,$9D,$06,$00,$60
CODE_80EC42:
        STA.B $8D
        STZ.W $001E,X
        JMP.W $E9E9
CODE_80EC4A:
        TAY
        DEY
        DEY
        STY.B $A1
        LDA.W $0F00,Y
        STA.B $8D
        TYA
        BNE CODE_80EC5B
        LDA.B $A3
        BNE CODE_80EC14
CODE_80EC5B:
        JMP.W $E9E9
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
        JSR.W updateVolume
        PHA
        LDA.B $8F
        STA.B $42
        LDA.B $8D
        STA.B $40
        LDA.W $0000,X
        AND.W #$F0FF
        STA.B $44
        TYX
        JSR.W updateCRTEffect
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
CODE_80ECDD:
        SEP #$20
        LDA.W $000D,X
        CMP.B #$80
        BCC CODE_80ECED
        LDA.B $40
        ORA.B #$80
        STA.W $000D,X
CODE_80ECED:
        REP #$20
        JMP.W $E9E9
        JSR.W updatePanning
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
        JSR.W updatePanning
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
        JSR.W updateTempo
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
        JSR.W updateTempo
        LDA.W $0000,Y
        AND.W #$0300
        BEQ CODE_80ED73
        INC.B $8D
        JMP.W $F1D4
CODE_80ED73:
        JMP.W $E9E9
        JSR.W updateVolume
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
CODE_80ED8C:
        JSR.W updateSoundEngine
        LDA.B [$8D]
        INC.B $8D
        JSR.W updateFilter
        ASL A
        ASL A
        CLC
        ADC.W $0012,X
        STA.W $0012,X
        PLX
        JMP.W $E9E9
        JSR.W updateVolume
        PHX
        TYX
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        CMP.W #$0080
        BCC CODE_80EDB7
        ORA.W #$FF00
CODE_80EDB7:
        CLC
        ADC.W $0004,X
        PHA
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        CMP.W #$0080
        BCC CODE_80EDCB
        db $09,$00,$FF
CODE_80EDCB:
        CLC
        ADC.W $0018,X
        TAY
        PLA
        BRA CODE_80ED8C
        JSR.W updateVolume
        PHX
        TYX
        LDA.B [$8D]
        INC.B $8D
        JSR.W updateFilter
        STA.W $000E,X
        LDA.B [$8D]
        INC.B $8D
        JSR.W updateFilter
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
        LDA.W $001A,X
        BEQ CODE_80EE1E
        DEC A
        STA.W $001A,X
        BNE CODE_80EE19
        INC.B $8D
        JMP.W $E9E9
CODE_80EE19:
        INC.B $8D
        JMP.W $F1D4
CODE_80EE1E:
        LDA.B [$8D]
        AND.W #$00FF
        INC.B $8D
        ASL A
        STA.W $001A,X
        JMP.W $F1D4
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
        JMP.W $F0F3
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
        JSR.W updateReverb
        STA.B $40
        JSR.W updateReverb
        CMP.W #$FF81
        BNE CODE_80EE8F
        LDY.W #$0001
        LDA.W $0AA3
        BRA CODE_80EE95
CODE_80EE8F:
        CLC
        ADC.B $97
        LDY.W #$0000
CODE_80EE95:
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
CODE_80EEB5:
        LDA.B $95
        SEC
        SBC.B $40
        STA.B $99
        STA.B $91
        JMP.W $E9E9
        SEP #$20
        STZ.B $A7
        REP #$20
        JSR.W updateReverb
        STA.B $40
        JSR.W updateReverb
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
CODE_80EEE5:
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
CODE_80EF0A:
        LDA.W #$4000
        STA.B $42
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        SEC
        SBC.W #$0010
CODE_80EF1A:
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
CODE_80EF49:
        CMP.W #$00FF
        BNE CODE_80EF6A
        LDY.W #$0E00
        CPX.W #$1200
        BCS CODE_80EF59
        LDY.W #$0E80
CODE_80EF59:
        LDA.W $0052,Y
        BNE CODE_80EF63
        INC.B $8D
        JMP.W $E9E9
CODE_80EF63:
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
CODE_80EF6A:
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
        db $18,$69,$C0,$85,$5F,$A5,$A9,$29,$01,$F0,$06,$A5,$5F,$49,$20,$85
        db $5F
CODE_80EFA4:
        REP #$20
        INC.B $8D
        JSR.W updateEcho
        STA.W $0DC0
        CMP.W #$FFFF
        BNE CODE_80EFCD
        db $A5,$5F,$29,$3F,$00,$0A,$DA,$AA,$BF,$00,$CF,$7F,$8D,$C1,$0D,$E2
        db $20,$AD,$C2,$0D,$8D,$C0,$0D,$C2,$20,$FA
CODE_80EFCD:
        SEP #$20
        LDA.B #$02
        STA.B $5E
        REP #$20
        JMP.W $F0F3
        LDA.W #$0010
        STA.B $44
        JSR.W updateReverb
        SEP #$20
        CMP.B #$80
        BCC CODE_80EFEC
        AND.B #$7F
        STA.B $5F
        BRA CODE_80EFFD
        db $18,$69,$C0,$85,$5F,$A5,$A9,$29,$01,$F0,$06,$A5,$5F,$49,$20,$85
        db $5F
CODE_80EFFD:
        REP #$20
        JSR.W updateEcho
        CMP.W #$FFFF
        BEQ CODE_80F00F
        STA.B $40
        LDA.B $8F
        STA.B $42
        BRA CODE_80F02C
        db $A5,$5F,$29,$3F,$00,$0A,$18,$69,$00,$CF,$85,$40,$A9,$7F,$00,$85
        db $42,$80,$0A,$A9,$20,$00,$85,$44,$A9,$00,$00,$80,$B4
CODE_80F02C:
        LDA.B $44
        PHX
        PHY
        PHA
        LDX.W #$0000
        TAY
CODE_80F035:
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
        JMP.W $F0F3
        LDA.W $001A,X
        BEQ CODE_80F06B
        DEC A
        STA.W $001A,X
        BNE CODE_80F064
        INC.B $8D
        INC.B $8D
        INC.B $8D
        JMP.W $E9E9
CODE_80F064:
        LDA.B [$8D]
        STA.B $8D
        JMP.W $E9E9
CODE_80F06B:
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
CODE_80F07F:
        STA.W $001A,X
        STY.B $8D
        JMP.W $E9E9
        JSR.W updateTempo
        LDA.W $0000,Y
        EOR.W #$4000
        STA.W $0000,Y
        LDA.B $8D
        STA.W $0006,X
        RTS
        JSR.W updateTempo
        LDA.W $0000,Y
        ORA.W #$0300
        STA.W $0000,Y
        JSR.W updateChorus
        STA.W $000E,Y
        JSR.W updateChorus
        ASL A
        STA.W $0010,Y
        JSR.W updateChorus
        STA.W $0012,Y
        JSR.W updateChorus
        STA.W $0014,Y
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        STA.W $001A,Y
        JMP.W $E9E9
        JSR.W updateReverb
        SEP #$20
        STA.B $68
        REP #$20
        JMP.W $E9E9
        JSR.W updateReverb
        SEP #$20
        STA.B $69
        REP #$20
        JMP.W $E9E9
        JSR.W updateReverb
        STA.B $60
        JMP.W $E9E9
        JSR.W updateReverb
        STA.B $62
        JMP.W $E9E9
        LDA.B $8D
        STA.W $0006,X
        RTS
        PHX
        JSR.W updateReverb
        JSR.W updateAudioEffects
        PLX
        JMP.W $E9E9
; [Music] Updates audio DSP effects. Entry: sends commands to SPC700 for reverb/echo.
updateAudioEffects:
        ASL A
        TAX
        LDA.L $0D8004,X
        PHA
        LDA.W #$0000
        STA.B $42
        LDA.W #$E42A
        STA.B $40
        LDX.W #$11E0
        JSR.W updateCRTEffect
        LDA.W #$8F00
        STA.W $000C,X
        PLA
        STA.W $0006,X
        RTS
        JSR.W updateEcho
        CMP.W #$8000
        BCS CODE_80F137
        CLC
        ADC.W $0A9B
        STA.B $A8
        JMP.W $E9E9
CODE_80F137:
        INC A
        BEQ CODE_80F14A
        INC A
        BEQ CODE_80F156
        CPX.W #$1200
        BCC CODE_80F145
        db $49,$01,$00
CODE_80F145:
        AND.W #$0001
        BNE CODE_80F156
CODE_80F14A:
        LDA.W $0A9B
        EOR.W #$1000
        STA.W $0A9B
        JMP.W $E9E9
CODE_80F156:
        LDA.W $0A9D
        EOR.W #$1000
        STA.W $0A9D
        JMP.W $E9E9
        JSR.W updateTempo
        SEP #$20
        LDA.W $0001,Y
        AND.B #$F0
        STA.W $0001,Y
        REP #$20
        JMP.W $E9E9
        LDA.B [$8D]
        AND.W #$00FF
        INC.B $8D
        CMP.W #$00FF
        BNE CODE_80F189
        LDA.W #$0064
        JSL.L updateSmokeEffect
        BRA CODE_80F1B1
CODE_80F189:
        CMP.W #$0029
        BEQ CODE_80F1C9
        TAY
        CPY.W #$0028
        BNE CODE_80F19D
        LDA.L $7EEA88
        AND.W #$0004
        BRA CODE_80F1B1
CODE_80F19D:
        LDA.W $0000,X
        AND.W #$2000
        BEQ CODE_80F1AB
        TYA
        CLC
        ADC.W #$0080
        TAY
CODE_80F1AB:
        LDA.W $0E00,Y
        AND.W #$00FF
CODE_80F1B1:
        PHA
        LDA.B [$8D]
        AND.W #$00FF
        INC.B $8D
        STA.B $40
        JSR.W updateEcho
        TAY
        PLA
        CMP.B $40
        BCC CODE_80F1C6
        STY.B $8D
CODE_80F1C6:
        JMP.W $E9E9
CODE_80F1C9:
        LDA.W #$0000
        CPX.W #$1200
        BCC CODE_80F1B1
        db $1A,$80,$DD
        LDA.B $8D
        DEC A
        DEC A
        STA.W $0006,X
        RTS
        JSR.W updateTempo
        PHX
        TYX
        LDA.W $0004,X
        CMP.W #$00C8
        BEQ CODE_80F21D
        BCS CODE_80F1FB
        db $85,$40,$A9,$C8,$00,$38,$E5,$40,$9D,$12,$00,$A9,$00,$01,$80,$0A
CODE_80F1FB:
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
CODE_80F21D:
        PLX
        JMP.W $E9E9
        JSR.W updateEcho
        CMP.W #$FFFF
        BNE CODE_80F231
        LDA.W $0A99
        STA.B $8D
        JMP.W $F0F3
CODE_80F231:
        STA.B $40
        PHY
        LDY.W #$0200
        LDA.W $0000,X
        AND.W #$2000
        BEQ CODE_80F242
        db $A0,$00,$00
CODE_80F242:
        LDA.W $1006,Y
        STA.W $0A99
        LDA.B $40
        STA.W $1006,Y
        PLY
        JMP.W $E9E9
        JSR.W updateEcho
        CMP.W #$FFFF
        BNE CODE_80F265
        LDA.W $0AA5
        EOR.W #$0001
        STA.W $0AA5
        JMP.W $E9E9
CODE_80F265:
        STA.W $0AA7
        STA.W $0AAD
        JMP.W $E9E9
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        STA.B $40
        BNE CODE_80F280
        STZ.B $6B
        STZ.B $6D
        JMP.W $E9E9
CODE_80F280:
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
CODE_80F2A5:
        JMP.W $E9E9
        JSR.W updateEcho
        ORA.W #$FC00
        STA.W $0AA7
        JSR.W updateEcho
        STA.W $0AAD
        LDA.B $8F
        STA.W $0AAF
        JMP.W $E9E9
        SEP #$20
        LDA.B [$8D]
        STA.W $000D,X
        REP #$20
        INC.B $8D
        JMP.W $E9E9
        LDA.W $0AA7
        BEQ CODE_80F2D5
        JMP.W $F1D4
CODE_80F2D5:
        JMP.W $E9E9
        SEP #$20
        LDA.B [$8D]
        STA.B $81
        REP #$20
        INC.B $8D
        JMP.W $E9E9
; [Music] Updates reverb effect parameters. Entry: adjusts echo delay, feedback.
updateReverb:
        LDA.B [$8D]
        INC.B $8D
        AND.W #$00FF
        CMP.W #$0080
        BCC CODE_80F2F4
        ORA.W #$FF00
CODE_80F2F4:
        RTS
; [Music] Updates echo effect parameters. Entry: sets echo delay, volume.
updateEcho:
        LDA.B [$8D]
        INC.B $8D
        INC.B $8D
        RTS
; [Music] Updates chorus effect parameters. Entry: sets modulation depth, rate.
updateChorus:
        LDA.B [$8D]
        INC.B $8D
; [Music] Updates audio filter parameters. Entry: sets low-pass/high-pass cutoff.
updateFilter:
        AND.W #$00FF
        CMP.W #$0080
        BCC CODE_80F318
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
CODE_80F318:
        ASL A
        ASL A
        ASL A
        ASL A
        RTS
; [Music] Updates audio panning (left/right balance). Entry: sets channel pan positions.
updatePanning:
        REP #$20
        AND.W #$000F
        CMP.W #$000E
        BNE updateVolume
        JSR.W updateTempo
        RTS
; [Music] Updates master volume and fade. Entry: adjusts overall sound volume.
updateVolume:
        REP #$20
        AND.W #$000F
        STA.B $40
        LDY.W #$1000
        LDA.W $0000,X
        AND.W #$2000
        BEQ CODE_80F340
        LDY.W #$1200
CODE_80F340:
        LDA.B $40
        CMP.W #$000F
        BNE CODE_80F34C
        TXY
        LDA.W #$000E
        RTS
CODE_80F34C:
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
        db $64,$40,$B9,$00,$00,$F0,$0A,$98,$18,$69,$20,$00,$A8,$E6,$40,$80
        db $F1,$A5,$40,$60
; [Music] Updates music tempo/speed. Entry: adjusts playback rate.
updateTempo:
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
CODE_80F395:
        PLA
        RTS
; [Music] Updates instrument parameters. Entry: modifies sound sample properties.
updateInstrument:
        REP #$20
        STA.B $40
        SEP #$20
        INC.B $A7
        LDA.B $A6
        BEQ CODE_80F3A6
        JMP.W $F40F
CODE_80F3A6:
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
CODE_80F3C3:
        LDA.B $99
        STA.B ($3A)
        INC.B $3A
        LDA.B $9B
        STA.B ($3A)
        INC.B $3A
CODE_80F3CF:
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
CODE_80F3EF:
        LDA.B $9D
        CMP.W #$0010
        BNE CODE_80F401
        LDA.B $40
        ORA.B $A8
        STA.B ($3A)
        INC.B $3A
        INC.B $3A
        RTS
CODE_80F401:
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
CODE_80F42E:
        LDA.B $99
        STA.B ($3E)
        INC.B $3E
        LDA.B $9B
        STA.B ($3E)
        INC.B $3E
CODE_80F43A:
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
CODE_80F44E:
        LDA.B $40
        ORA.B $A8
        EOR.W #$4000
        STA.B ($3E)
        INC.B $3E
        INC.B $3E
        RTS
; [Music] Updates entire sound engine state. Entry: processes all audio channels, effects.
updateSoundEngine:
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
CODE_80F480:
        SEC
        SBC.B $44
        STA.B $46
CODE_80F485:
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
CODE_80F49F:
        SEC
        SBC.B $44
        STA.B $48
CODE_80F4A4:
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
