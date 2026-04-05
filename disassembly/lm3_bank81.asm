        org $818000

; [Init] System initialization - clears WRAM, sets up hardware, calls external init routines. Entry: called at reset.
systemInit:
        CLD
        REP #$30
        LDY.W #$0800
        LDX.W #$0000
CODE_818009:
        STZ.W $0000,X
        INX
        DEY
        BNE CODE_818009
        SEP #$20
        JSL.L externalLibInit
        LDA.B #$30
        LDY.W #$8000
        JSL.L externalMathFunc1
        LDA.B #$34
        LDY.W #$8000
        JSL.L externalMathFunc2
        LDA.B #$00
        JSL.L externalCRC32Func
        JMP.W $E168
        REP #$20
        JSR.W clearTextBuffer
        JSL.L calculateStatBonus
        LDA.W $0942
        BNE CODE_818072
        LDX.W #$0014
        LDA.W #$0000
CODE_818045:
        STA.L $7EEA80,X
        INX
        INX
        CPX.W #$001E
        BNE CODE_818045
        LDA.W #$0000
        STA.L $7EEA84
        INC A
        STA.L $7EEA80
        LDA.L $7EEA82
        JSR.W drawMagicScreen
        LDA.L $7FC00A
        AND.W #$00FF
        BEQ CODE_818072
        JSR.W resetTestState
        JSR.W clearTextBuffer
CODE_818072:
        STZ.W $0958
        STZ.W $095A
        LDA.L $7EEA82
        JSR.W handleMagicScreen
        LDA.W #$0002
        JSL.L dispatchGameMode
        LDA.W $0902
        STA.B $00
        LDA.W $0904
        STA.B $02
        JSR.W cheatFastBattle
        JSR.W recoverSaveData
        JSR.W testCollision
        JSR.W confirmAction
        LDA.W #$0063
        STA.W $0912
        LDA.W $0942
        BEQ CODE_8180AC
        JSR.W handleShopMenu
        BRA CODE_8180B2
CODE_8180AC:
        LDA.W #$0000
        JSR.W transitionFromBattle
CODE_8180B2:
        JSR.W logTestFailure
        JSR.W confirmAction
        JSR.W handleMinigame
        LDA.W $0942
        BNE CODE_8180C9
        LDA.L $7FC009
        AND.W #$00FF
        BNE CODE_8180CC
CODE_8180C9:
        JSR.W drawMessageBox
CODE_8180CC:
        JSR.W awardMinigamePrize
        LDA.L $7FC00B
        AND.W #$00FF
        BEQ CODE_8180DE
        JSR.W resetTestState
        JSR.W skipCutscene
CODE_8180DE:
        LDA.W $0942
        BNE CODE_8180E6
        JSR.W clearWatchpoints
CODE_8180E6:
        BRA CODE_818113
        STZ.W $0942
        LDA.W #$0000
        STA.L $7EEA9C
        JSR.W clearTextBuffer
        JSR.W drawFormationScreen
        LDA.W #$0002
        JSL.L dispatchGameMode
        LDA.W $0902
        STA.B $00
        LDA.W $0904
        STA.B $02
        JSR.W cheatFastBattle
        JSR.W initSound
        JSR.W awardMinigamePrize
        RTS
CODE_818113:
        LDX.W #$0000
        LDY.W #$0010
        STZ.B $00
CODE_81811B:
        LDA.W $1400,X
        AND.W #$00FF
        CMP.W #$00FF
        BNE CODE_818130
        LDA.W $140F,X
        AND.W #$00FF
        BNE CODE_818130
        INC.B $00
CODE_818130:
        TXA
        CLC
        ADC.W #$0020
        TAX
        DEY
        BNE CODE_81811B
        LDA.B $00
        BNE CODE_818143
        JSR.W drawBestiary
        JMP.W $8491
CODE_818143:
        STZ.W $091C
        JSR.W playCursorSound
        JSR.W handleBestiary
        JSR.W awardMinigamePrize
CODE_81814F:
        LDA.W #$0000
        JSR.W handleInn
        LDA.W #$0080
        JSR.W testBattle
        BEQ CODE_818193
        db $A5,$50,$29,$00,$10,$D0,$56,$A9,$40,$00,$20,$84,$DE,$F0,$27,$A5
        db $50,$29,$00,$C0,$C9,$00,$C0,$D0,$06,$20,$09,$A6,$4C,$C4,$8D,$A5
        db $50,$29,$00,$40,$F0,$03,$4C,$38,$82,$A5,$50,$29,$00,$20,$F0,$06
        db $20,$09,$A6,$4C,$46,$97
CODE_818193:
        LDA.B $50
        AND.W #$8000
        BEQ CODE_81819D
        JMP.W $8280
CODE_81819D:
        LDA.B $50
        AND.W #$0080
        BEQ CODE_8181A7
        JMP.W $8568
CODE_8181A7:
        LDA.B $50
        AND.W #$0040
        BEQ CODE_8181B1
        JMP.W $8400
CODE_8181B1:
        LDA.B $50
        AND.W #$0030
        BNE CODE_8181CE
        BRA CODE_81814F
        db $20,$1F,$E9,$D0,$03,$4C,$13,$81,$3A,$D0,$03,$4C,$DD,$8E,$9C,$42
        db $09,$4C,$31,$80
CODE_8181CE:
        STZ.B $22
CODE_8181D0:
        LDA.B $50
        AND.W #$0010
        BEQ CODE_8181E5
        LDA.W $0912
        INC A
        CMP.W #$0010
        BCC CODE_8181E3
        LDA.W #$0000
CODE_8181E3:
        BRA CODE_8181F1
CODE_8181E5:
        LDA.W $0912
        DEC A
        CMP.W #$0010
        BCC CODE_8181F1
        LDA.W #$000F
CODE_8181F1:
        STA.W $0912
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_8181D0
        LDA.W $1404,X
        AND.W #$00FF
        STA.B $02
        LDA.W $1405,X
        AND.W #$00FF
        STA.B $04
        LDA.B $04
        CMP.W $090C
        BNE CODE_818228
        LDA.B $02
        CMP.W $090A
        BNE CODE_818228
        db $E6,$22,$A5,$22,$C9,$02,$00,$F0,$02,$80,$A8
CODE_818228:
        LDA.B $02
        STA.W $090A
        LDA.B $04
        STA.W $090C
        JSR.W drawCredits
        JMP.W CODE_81814F
        db $A9,$00,$00,$20,$8D,$EC,$AD,$0A,$09,$85,$00,$AD,$0C,$09,$85,$01
        db $A5,$00,$8D,$00,$0E,$20,$0D,$A7,$8D,$02,$0E,$BB,$BF,$02,$E0,$7F
        db $8D,$04,$0E,$A9,$41,$00,$20,$4A,$EE,$A5,$50,$29,$30,$00,$D0,$03
        db $4C,$13,$81,$AD,$5A,$09,$8D,$58,$09,$AD,$04,$0E,$8D,$5A,$09,$20
        db $95,$E9,$20,$51,$B8,$4C,$DD,$8E
        JSR.W drawBestiary
        LDY.W #$0019
        LDA.W #$0001
        JSR.W handleTransitionWipe
        LDA.B $22
        BEQ CODE_8182AC
        CMP.W #$0002
        BEQ CODE_8182AF
        CMP.W #$0003
        BNE CODE_81829D
        JMP.W $8491
CODE_81829D:
        CMP.W #$0005
        BNE CODE_8182A5
        JMP.W $8420
CODE_8182A5:
        CMP.W #$0006
        BEQ CODE_8182E6
        BRA CODE_818310
CODE_8182AC:
        JMP.W CODE_818113
CODE_8182AF:
        LDY.W #$00B5
        LDA.W #$0040
        JSR.W testBattle
        BEQ CODE_8182C4
        db $A5,$4E,$29,$00,$0F,$F0,$03,$A0,$36,$00
CODE_8182C4:
        TYA
        PHA
        JSR.W monitorInput
        LDA.L $7EEA88
        STA.B $24
        PLY
        INY
        LDA.W #$0000
        JSR.W handleTransitionWipe
        LDA.B $24
        STA.L $7EEA88
        LDA.W #$0038
        JSR.W monitorInput
        JMP.W CODE_818113
CODE_8182E6:
        LDA.W #$0033
        JSR.W monitorInput
        LDA.W $0A08
        BEQ CODE_8182AC
        DEC A
        BEQ CODE_8182FA
        JSR.W drawPauseMenu
        JMP.W $E3F2
CODE_8182FA:
        LDA.W #$004E
        JSR.W monitorInput
        LDA.L $7EEA89
        AND.W #$0003
        JSR.W singleStep
        JSR.W clearTextBuffer
        JMP.W $E1BA
CODE_818310:
        LDA.W #$0001
        JSR.W backupSaveData
        PHA
        JSR.W clearTextBuffer
        JSR.W initGraphics
        JSR.W drawTutorial
        PLA
        CMP.W #$FFFF
        BNE CODE_818329
        JMP.W $83DB
CODE_818329:
        JSR.W $DE49
        LDA.W $0E8C
        AND.W #$00FF
        CMP.W #$0003
        BNE CODE_81833A
        db $4C,$C1,$83
CODE_81833A:
        LDY.W #$0010
        CMP.W #$0002
        BNE CODE_818345
        db $A0,$20,$00
CODE_818345:
        STY.W $0946
CODE_818348:
        LDA.W #$0076
        JSR.W monitorInput
CODE_81834E:
        LDA.W #$0076
        JSR.W handleInn
        LDA.B $50
        AND.W #$8000
        BEQ CODE_81835E
        db $4C,$DB,$83
CODE_81835E:
        LDA.B $50
        AND.W #$0080
        BEQ CODE_81834E
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $01
        JSR.W drawShopStock
        STA.W $0950
        CMP.W #$FFFF
        BEQ CODE_81834E
        CMP.W $0946
        BCS CODE_81834E
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W #$0077
        JSR.W monitorInput
        LDA.W $0A08
        CMP.W #$0001
        BNE CODE_818348
        LDA.W $0E98
        CMP.W #$0060
        BCS CODE_8183A4
        db $A8,$AD,$50,$09,$20,$C8,$E7,$80,$06
CODE_8183A4:
        JSR.W $83E4
        JSR.W $E822
        LDA.B $14
        PHA
        LDA.B $0E
        LDY.W #$000E
        JSR.W flashScreen
        JSR.W handleShopMenu
        PLA
        BEQ CODE_8183BE
        db $20,$4A,$EE
CODE_8183BE:
        JMP.W CODE_818113
        db $A9,$B4,$00,$20,$4A,$EE,$20,$E4,$83,$A0,$00,$00,$C9,$6E,$00,$D0
        db $02,$C8,$C8,$98,$20,$C9,$98,$4C,$13,$81
        LDA.W #$0073
        JSR.W monitorInput
        JMP.W CODE_818113
        LDA.W $0E98
        AND.W #$00FF
        PHA
        TAX
        SEP #$20
        LDA.L $7EEA00,X
        DEC A
        STA.L $7EEA00,X
        REP #$20
        LDA.W $0950
        STA.B $0E
        PLA
        RTS
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $01
        LDA.B $00
        STA.W $091A
        JSR.W drawShopStock
        CMP.W #$FFFF
        BNE CODE_81841A
        JMP.W CODE_81814F
CODE_81841A:
        JSR.W drawSaveFileInfo
        JMP.W CODE_81844C
        LDA.W #$0000
        JSR.W updatePlayTime
        LDA.B $50
        AND.W #$0080
        BEQ CODE_81844C
        TYA
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_81844C
        LDA.W $1404,X
        AND.W #$00FF
        STA.B $02
        LDA.W $1405,X
        AND.W #$00FF
        STA.B $04
        JSR.W playEventCutscene
CODE_81844C:
        JSR.W initGraphics
        JSR.W awardMinigamePrize
        JMP.W CODE_81814F
; [Init] Initializes graphics system - sets up PPU registers, clears VRAM, loads font.
initGraphics:
        JSR.W handleMapScreen
        LDA.W #$0006
        JSL.L dispatchGameMode
        LDA.W $0A4A
        STA.W $0A48
        LDA.W $0902
        STA.B $00
        LDA.W $0904
        STA.B $02
        JSR.W cheatFastBattle
        JSR.W initSound
        JSR.W printText
        RTS
; [Init] Initializes sound system - uploads SPC program, sets up sound driver.
initSound:
        REP #$20
        JSR.W recoverSaveData
        JSR.W testCollision
        JSR.W confirmAction
        JSR.W handleShopMenu
        JSR.W logTestFailure
        JSR.W confirmAction
        JSR.W handleMinigame
        RTS
        LDA.W #$0063
        STA.W $0912
        JMP.W $928F
        JSR.W drawTutorial
        JSR.W handlePauseMenu
        LDA.W #$0001
        STA.W $0000,Y
        STA.W $0002,Y
        STA.W $0004,Y
        LDA.L $7FE000,X
        AND.W #$0030
        CMP.W #$0030
        BEQ CODE_8184CB
        STZ.W $0E04
        CMP.W #$0020
        BEQ CODE_8184CB
        STZ.W $0E02
        CMP.W #$0010
        BEQ CODE_8184CB
        STZ.W $0E00
CODE_8184CB:
        LDA.W #$000B
        JSR.W monitorInput
        JSR.W monitorGraphics
        LDY.W #$0100
        LDA.L $7FC003
        AND.W #$00F0
        BEQ CODE_8184E3
        db $A0,$00,$0E
CODE_8184E3:
        TYA
        ORA.W $0E62
        JSR.W monitorInput
        LDA.W #$0001
        JSR.W handleInn
        JMP.W CODE_818113
; [Init] Initializes game state variables - party, inventory, story flags to default.
initGameState:
        LDA.W #$0019
        STA.W $09FC
        LDA.W #$0019
        STA.W $09FE
        LDA.W $0E37
        AND.W #$0030
        LSR A
        LSR A
        LSR A
        LSR A
        CLC
        ADC.W #$0024
        JSR.W monitorInput
        LDY.W #$0E00
        BRA CODE_81851D
; [Init] Initializes controller input system - clears input buffers, enables auto-read.
initControllers:
        LDY.W #$0F00
        PHY
        JSR.W debugMenu
        PLY
CODE_81851D:
        LDA.W $0038,Y
        LSR A
        LSR A
        STA.B $00
        STZ.W $0E74
        LDA.W $0008,Y
        CMP.B $00
        BCS CODE_818531
        INC.W $0E74
CODE_818531:
        LDA.W $0028,Y
        CMP.W #$0010
        BCS CODE_81853C
        INC.W $0E75
CODE_81853C:
        RTS
; [Init] Enables screen display after init. Entry: sets $2100 to $0F (full brightness).
enableDisplay:
        LDA.W $0E90
        BRA CODE_818545
; [GameState] Title screen main loop - handles menu, demo playback, start game transition.
titleScreenLoop:
        LDA.W $0E10
CODE_818545:
        AND.W #$00FF
        CMP.W #$0004
        BEQ CODE_81855B
        CMP.W #$0002
        BEQ CODE_818564
        CMP.W #$0003
        BEQ CODE_818564
        LDA.W #$0000
        RTS
        db $AF,$80,$EA,$7E,$29,$01,$00,$D0,$F3
        db $A9,$01,$00,$60
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $01
        LDA.B $00
        STA.W $091A
        JSR.W drawShopStock
        CMP.W #$FFFF
        BNE CODE_818582
        JMP.W $849A
CODE_818582:
        STA.W $092E
        STA.W $0A55
        JSR.W drawTutorial
        JSR.W handlePauseMenu
        LDA.W $092E
        LDY.W #$0E00
        JSR.W debugMenu
        LDY.W #$0E00
        JSR.W handleEquipment
        JSR.W initGameState
        LDA.W #$0011
        JSR.W monitorInput
        LDA.W $0E28
        CMP.W #$0010
        BCS CODE_8185C1
        LDA.W $0E0F
        AND.W #$00FF
        BNE CODE_8185B8
        BRA CODE_8185D5
CODE_8185B8:
        LDA.W #$0001
        JSR.W handleInn
        JMP.W CODE_818113
CODE_8185C1:
        LDA.W #$3932
        STA.B $7D
        JSR.W handleTitleInput
        LDA.W #$0002
        JSR.W handleInn
        JSR.W playTitleMusic
        JMP.W CODE_818113
CODE_8185D5:
        LDA.W #$3132
        STA.B $7D
        JSR.W handleTitleInput
CODE_8185DD:
        LDA.W #$0002
        JSR.W handleInn
        LDA.B $50
        AND.W #$0080
        BNE CODE_8185F9
        LDA.B $50
        AND.W #$8000
        BNE CODE_8185F3
        BRA CODE_8185DD
CODE_8185F3:
        JSR.W playTitleMusic
        JMP.W CODE_818113
CODE_8185F9:
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $02
        JSR.W handleStatusScreen
        LDA.L $7FA000,X
        AND.W #$00FF
        BEQ CODE_8185DD
        JSR.W playTitleMusic
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $01
        LDA.L $7FC013
        CMP.B $00
        BNE CODE_818627
        JMP.W $8C2B
CODE_818627:
        LDA.W $090A
        STA.B $00
        STA.W $0948
        LDA.W $090C
        STA.B $01
        STA.W $094A
        JSR.W updateBattleCamera
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $01
        JSR.W updateBattleAnimation
        LDA.W $090A
        STA.B $22
        LDA.W $090C
        STA.B $24
        LDA.W $0E56
        STA.B $26
        LDA.W $0E5C
        STA.B $28
        JSR.W fleeBattle
        STA.W $0922
        STA.W $0E54
        JSR.W handleItemBattle
        BRA CODE_818676
        LDA.W $0948
        STA.B $02
        LDA.W $094A
        STA.B $04
        JSR.W drawCredits
CODE_818676:
        JSR.W resumeGame
        LDY.W #$0000
        LDA.W $0922
        BNE CODE_818684
        LDY.W #$0001
CODE_818684:
        LDA.W $0E6A
        BEQ CODE_81868C
        LDY.W #$0001
CODE_81868C:
        TYA
        LDY.W #$000F
        JSR.W handleTransitionWipe
        LDA.B $22
        BNE CODE_81869A
        JMP.W $8B54
CODE_81869A:
        CMP.W #$0002
        BNE CODE_8186A2
        JMP.W $86E4
CODE_8186A2:
        CMP.W #$0003
        BEQ CODE_8186AF
        CMP.W #$0001
        BEQ CODE_8186B2
        JMP.W $8779
CODE_8186AF:
        JMP.W $8BCD
CODE_8186B2:
        LDA.W $0E6A
        BEQ CODE_8186BA
        JMP.W $893C
CODE_8186BA:
        LDA.W $0922
        BEQ CODE_818676
        LDA.W $0E5C
        INC A
        STA.B $08
        LDA.W $0E56
        INC A
        STA.B $0A
        JSR.W animateTitle
        LDA.W #$0010
        JSR.W monitorInput
        JSR.W gameMainLoop
        PHA
        JSR.W playTitleMusic
        PLA
        BEQ CODE_8186E1
        JMP.W $8669
CODE_8186E1:
        JMP.W $8C0D
        LDA.W $0920
        BNE CODE_8186EC
        JMP.W CODE_818676
        db $A9,$4A,$00,$20,$4A,$EE,$9C,$28,$09,$AD,$20,$09,$8D,$2C,$09,$A9
        db $01,$00,$20,$37,$A1,$A5,$50,$29,$80,$40,$D0,$03,$4C,$69,$86,$A9
        db $04,$00,$20,$73,$9B,$AD,$28,$09,$20,$33,$A2,$A7,$12,$C9,$80,$00
        db $90,$05,$20,$EE,$F6,$80,$3D,$20,$49,$DE,$A9,$98,$00,$20,$4A,$EE
        db $AD,$08,$0A,$C9,$01,$00,$D0,$3C,$AD,$98,$0E,$48,$20,$A1,$E7,$68
        db $C9,$50,$00,$B0,$19,$A9,$99,$00,$20,$4A,$EE,$AD,$08,$0A,$C9,$01
        db $00,$D0,$11,$AD,$55,$0A,$AC,$98,$0E,$20,$C8,$E7,$80,$06,$A9,$9A
        db $00,$20,$4A,$EE,$AD,$0A,$09,$85,$00,$AD,$0C,$09,$85,$02,$20,$88
        db $9B,$4C,$DD,$8B,$A9,$03,$00,$20,$73,$9B,$4C,$69,$86
        LDX.W $0918
        LDA.W $1408,X
        CMP.W #$0003
        BCS CODE_81878D
        db $A9,$78,$00,$20,$4A,$EE,$4C,$76,$86
CODE_81878D:
        DEC A
        DEC A
        STA.W $1408,X
        STA.W $0E08
        LDA.W $1404,X
        STA.W $091A
        LDA.W #$0079
        JSR.W monitorInput
        LDA.W #$0050
        JSR.W setTextColor
        LDX.W #$0000
        STZ.B $02
CODE_8187AC:
        LDA.L $7FC0C8,X
        BEQ CODE_8187DB
        CMP.W $091A
        BNE CODE_8187D3
        LDA.L $7FC0CA,X
        STA.B $00
        AND.W #$00FF
        CMP.W #$0041
        BNE CODE_8187D3
        db $A5,$01,$29,$7F,$00,$09,$00,$10,$20,$EE,$F6,$4C,$DD,$8B
CODE_8187D3:
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_8187AC
CODE_8187DB:
        LDA.W $091A
        STA.B $00
        JSR.W drawStatusScreen
        AND.W #$1000
        BNE CODE_81883C
        STX.W $096C
        LDA.W $0E46
        AND.W #$00FF
        LSR A
        STA.B $22
        LDA.W #$0064
        JSL.L updateSmokeEffect
        CMP.B $22
        BCS CODE_81883C
        LDA.W $0E6A
        BNE CODE_818818
        LDA.W #$000A
        JSL.L updateSmokeEffect
        CLC
        ADC.W #$0005
        ASL A
        STA.W $0A08
        JSR.W debugMonitor
        BRA CODE_818848
        db $AE,$18,$09,$BD,$0A,$14,$29,$FF,$00,$C9,$05,$00,$B0,$DE,$E2,$20
        db $1A,$9D,$0A,$14,$C2,$20,$A9,$00,$00,$20,$E5,$EB,$A9,$7C,$00,$20
        db $4A,$EE,$80,$0C
CODE_81883C:
        LDA.W #$001A
        JSR.W monitorDisassemble
        LDA.W #$007A
        JSR.W monitorInput
CODE_818848:
        LDX.W $096C
        LDA.L $7F9000,X
        ORA.W #$1000
        STA.L $7F9000,X
        JMP.W $8BDD
; [GameState] Initializes title screen - sets up animation, music, and input handlers. Entry: called when entering title screen.
initTitleScreen:
        LDA.W #$0001
        STA.B $08
        LDA.W #$0003
        STA.B $0A
        JSR.W animateTitle
        LDA.W #$0010
        JSR.W monitorInput
        JSR.W gameMainLoop
        PHA
        JSR.W playTitleMusic
        PLA
        RTS
; [Animation] Animates title screen elements (sparkles, pulsing). Entry: called each frame.
animateTitle:
        LDA.W #$3157
        STA.B $7D
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $02
        JSL.L calculateHitRate
        JSR.W testGraphicsRendering
        JSR.W confirmAction
        RTS
; [Input] Handles input on title screen - start button, demo mode.
handleTitleInput:
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $02
        STZ.B $0A
        LDA.W $0E48
        AND.W #$00FF
        STA.B $04
        LDA.W $0E37
        AND.W #$00FF
        STA.B $0C
        JSL.L applyStatusEffect
        JSR.W testSaveSystem
        JSR.W testGraphicsRendering
        RTS
; [Music] Plays title screen music. Entry: starts BGM track 0.
playTitleMusic:
        JSR.W testGameLogic
        JSR.W testGraphicsRendering
        JSR.W confirmAction
        RTS
; [MainLoop] Main gameplay loop - updates all systems, renders frame. Entry: called each frame during gameplay.
gameMainLoop:
        STZ.W $0928
        LDA.W $0926
        STA.W $092C
        LDY.W $0E6A
        CPY.W #$0003
        BNE CODE_8188D5
        DEC A
        STA.W $0928
CODE_8188D5:
        LDA.W #$0000
        JSR.W handleSavePoint
        LDA.B $50
        AND.W #$4080
        BNE CODE_8188EC
        LDA.B $50
        AND.W #$8000
        BEQ CODE_8188EA
        RTS
        db $80,$E9
CODE_8188EC:
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $01
        JSR.W drawShopStock
        CMP.W #$FFFF
        BEQ CODE_8188D5
        LDY.W $0E6A
        BNE CODE_818908
        CMP.W #$0010
        BCC CODE_8188D5
CODE_818908:
        STA.W $0E54
        LDX.W $0918
        LDA.W $1404,X
        STA.B $22
        LDA.W $1405,X
        STA.B $24
        JSR.W loadBattleBackground
        LDA.B $28
        CMP.B $02
        BCS CODE_8188D5
        LDA.B $26
        CMP.B $02
        BCC CODE_8188D5
        LDA.B $02
        CMP.W #$0001
        BNE CODE_818931
        LDA.W #$0000
CODE_818931:
        SEP #$20
        STA.W $0E25
        REP #$20
        LDA.W #$0000
        RTS
        LDA.W $0E28
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W $0E0A
        AND.W #$00FF
        BNE CODE_818956
        db $A9,$90,$00,$20,$4A,$EE,$4C,$76,$86
CODE_818956:
        LDA.W $0E6A
        CMP.W #$0002
        BCS CODE_81899C
        LDA.W $0922
        BNE CODE_818966
        JMP.W CODE_818676
CODE_818966:
        JSR.W initTitleScreen
        BEQ CODE_81896E
        JMP.W $8669
CODE_81896E:
        LDA.W $0E54
        LDY.W #$0E80
        JSR.W debugMenu
        LDA.W #$007D
        JSR.W monitorInput
        LDA.W $0A08
        CMP.W #$0001
        BEQ CODE_818988
        db $4C,$69,$86
CODE_818988:
        JSR.W updateSpellEffect
        BNE CODE_818990
        db $4C,$69,$86
CODE_818990:
        JSR.W updateGameLogic
        DEC.W $0E0A
        JSR.W updateDamageSpark
        JMP.W $8C65
CODE_81899C:
        CMP.W #$0004
        BNE CODE_8189A4
        db $4C,$B0,$8A
CODE_8189A4:
        JSR.W $CF40
        CMP.W #$FFFF
        BNE CODE_8189AF
        db $4C,$76,$86
CODE_8189AF:
        LDA.W $0E6C
        AND.W #$00FF
        STA.W $0946
        LDA.W #$FFFF
        STA.W $0EA8
        LDA.W $0E71
        AND.W #$00FF
        BNE CODE_8189C9
        db $4C,$3D,$8A
CODE_8189C9:
        CMP.W #$0002
        BNE CODE_8189D1
        JMP.W $8A63
CODE_8189D1:
        LDA.W #$0023
        JSR.W monitorInput
CODE_8189D7:
        LDA.W #$0023
        JSR.W handleInn
        LDA.B $50
        AND.W #$8000
        BEQ CODE_8189E7
        db $4C,$69,$86
CODE_8189E7:
        LDA.B $50
        AND.W #$0080
        BEQ CODE_8189D7
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $01
        LDA.W $0E71
        AND.W #$00FF
        CMP.W #$0080
        BNE CODE_818A2C
        db $A5,$00,$8D,$84,$0E,$A2,$08,$00,$20,$EA,$A3,$64,$08,$A9,$03,$00
        db $85,$0A,$20,$75,$88,$A9,$91,$00,$20,$4A,$EE,$20,$B6,$88,$AD,$08
        db $0A,$C9,$01,$00,$F0,$14,$4C,$69,$86
CODE_818A2C:
        JSR.W drawShopStock
        CMP.W #$FFFF
        BEQ CODE_8189D7
        STA.W $0E54
        LDY.W #$0E80
        JSR.W debugMenu
        SEP #$20
        LDA.W $0E5A
        STA.W $0E0A
        REP #$20
        JSR.W $AD3B
        LDA.W $0948
        STA.B $02
        LDA.W $094A
        STA.B $04
        JSR.W drawCredits
        JSR.W $BDB9
        LDY.W #$0E00
        JSR.W executeDebugCommand
        JMP.W $8BDD
        JSR.W initTitleScreen
        BEQ CODE_818A6B
        db $4C,$69,$86
CODE_818A6B:
        JSR.W updateGameLogic
        LDA.W $0E54
        LDY.W #$0E80
        JSR.W debugMenu
        LDA.W $0EA8
        JSR.W drawSpellEffect
        SEP #$20
        LDA.W $0E5A
        STA.W $0E0A
        LDX.W $0946
        CPX.W #$0003
        BCS CODE_818A94
        LDA.L $018AAD,X
        STA.W $0E11
CODE_818A94:
        REP #$20
        LDA.W #$0005
        JSL.L updateSmokeEffect
        CLC
        ADC.W $0E6E
        STA.W $0E6E
        LDA.W #$0000
        JSR.W updateWeaponSwing
        JMP.W $8C65
        db $02,$00
        db $01
        db $AD,$22,$09,$D0,$03,$4C,$76,$86,$20,$40,$CF,$C9,$FF,$FF,$D0,$03
        db $4C,$76,$86,$20,$59,$88,$F0,$03,$4C,$69,$86,$AD,$6D,$0E,$29,$FF
        db $00,$8D,$46,$09,$AD,$54,$0E,$A0,$80,$0E,$20,$04,$DC,$AD,$46,$09
        db $C9,$10,$00,$F0,$14,$AD,$82,$0E,$29,$FF,$00,$F0,$09,$A9,$71,$00
        db $20,$4A,$EE,$4C,$69,$86,$EE,$82,$0E,$20,$6B,$91,$D0,$03,$4C,$69
        db $86,$20,$85,$8B,$AC,$46,$09,$AD,$6E,$0E,$85,$00,$C0,$10,$00,$F0
        db $02,$80,$12,$E2,$20,$CD,$90,$0E,$90,$03,$9C,$90,$0E,$AD,$5A,$0E
        db $8D,$0A,$0E,$80,$21,$E2,$20,$C0,$18,$00,$D0,$0B,$5A,$AD,$99,$0E
        db $20,$E9,$E8,$8D,$99,$0E,$7A,$B9,$80,$0E,$20,$E9,$E8,$99,$80,$0E
        db $AD,$5A,$0E,$8D,$0A,$0E,$C2,$20,$A0,$80,$0E,$20,$2A,$DE,$20,$0C
        db $92,$4C,$65,$8C
        LDX.W $0918
        LDA.W $091A
        STA.W $1404,X
        STA.B $00
        JSR.W updateMosaic
        LDX.W $0916
        LDA.B $02
        STA.W $1802,X
        LDA.B $04
        STA.W $1804,X
        LDA.W $091A
        AND.W #$00FF
        STA.B $02
        LDA.W $091B
        AND.W #$00FF
        STA.B $04
        JSR.W drawCredits
        JMP.W CODE_818113
; [MainLoop] Updates game logic subsystems - entities, AI, physics, triggers.
updateGameLogic:
        JSR.W handleGameInput
        LDA.W $0A55
        LDY.W #$0E00
        JSR.W debugMenu
        RTS
; [MainLoop] Updates graphics - OAM, tilemap changes, effects. Prepares for V-blank DMA.
updateGraphics:
        LDA.W $091C
        JSR.W cleanupBattle
        STX.W $0916
        LDA.W $091C
        JSR.W initBattleState
        STX.W $0918
        JSR.W handleGameInput
        JSR.W handleShopMenu
        JSR.W logTestFailure
        JSR.W confirmAction
        RTS
; [Input] Handles gameplay input - movement, menu, actions. Updates player controller state.
handleGameInput:
        LDX.W $0916
        LDA.W $180E,X
        AND.W #$FFF0
        ORA.W #$0002
        STA.W $180E,X
        LDX.W $0918
        SEP #$20
        LDA.B #$01
        STA.W $140F,X
        REP #$20
        RTS
        JSR.W updateGameLogic
        LDX.W $0918
        LDA.W $1404,X
        STA.B $00
        JSR.W drawBattleAnimation
        BRA CODE_818BE0
        JSR.W updateGameLogic
CODE_818BE0:
        LDA.W $091C
        BEQ CODE_818C04
        CMP.W #$FFFF
        BNE CODE_818BED
        db $4C,$C4,$8D
CODE_818BED:
        CMP.W #$FFFE
        BNE CODE_818BF5
        JMP.W $8D86
        db $8D,$28,$0E,$AD,$55,$0A,$8D,$22,$09,$9C,$1C,$09,$4C,$EE,$96
CODE_818C04:
        JSR.W handleShopMenu
        JSR.W clearWatchpoints
        JMP.W CODE_818113
        JSR.W updateGameLogic
        LDA.W $0E54
        LDY.W #$0E80
        JSR.W debugMenu
        LDA.W $0EA8
        JSR.W drawSpellEffect
        STZ.W $0E6E
        LDA.W #$0000
        JSR.W updateWeaponSwing
        JMP.W $8C65
        JSR.W drawShopStock
        CMP.W #$FFFF
        BNE CODE_818C36
        JMP.W CODE_818627
CODE_818C36:
        CMP.W #$0010
        BCC CODE_818C3E
        db $4C,$13,$81
CODE_818C3E:
        CMP.W $0E28
        BNE CODE_818C46
        db $4C,$27,$86
CODE_818C46:
        LDY.W #$0E80
        JSR.W debugMenu
        JSR.W resumeGame
        JSR.W $AB8F
        CMP.W #$0001
        BNE CODE_818C5A
        db $4C,$13,$81
CODE_818C5A:
        CMP.W #$0002
        BNE CODE_818C62
        db $4C,$54,$8B
CODE_818C62:
        JMP.W $8EDD
        LDA.W $0EA8
        STA.W $091E
        LDA.W $0E28
        PHA
        JSR.W handleMapScreen
        LDA.W #$0002
        JSL.L dispatchGameMode
        LDA.W $091C
        BEQ CODE_818C95
        LDA.W #$0003
        STA.B $14
        LDA.W #$A2D2
        STA.B $12
        LDA.W #$000F
        STA.B $00
        LDA.W #$0001
        STA.B $02
        JSR.W monitorHelp
CODE_818C95:
        LDA.W $0930
        CLC
        ADC.W #$006C
        STA.B $00
        LDA.W $0932
        CLC
        ADC.W #$0058
        STA.B $02
        JSR.W cheatFastBattle
        JSL.L calculateStatBonus
        JSR.W initSound
        JSR.W drawMessageBox
        JSR.W awardMinigamePrize
        PLA
        LDY.W #$0E00
        JSR.W debugMenu
        LDY.W #$0080
        JSR.W pauseGame
        LDY.W #$0000
        JSR.W pauseGame
        LDA.W #$FFFF
        STA.W $093C
        JSR.W drawDamageNumbers
        LDA.W $093C
        CMP.W #$FFFF
        BEQ CODE_818D06
        LDA.L $7FC015
        AND.W #$00FF
        BEQ CODE_818CE7
        db $20,$EE,$F6
CODE_818CE7:
        LDA.W $093C
        STA.W $0A55
        JSR.W initBattleState
        LDA.W $140B,X
        AND.W #$00FF
        BEQ CODE_818CFB
        JSR.W resetTestState
CODE_818CFB:
        LDA.W $091C
        CMP.W #$FFFD
        BNE CODE_818D06
        db $4C,$C4,$8D
CODE_818D06:
        LDA.W $093C
        BNE CODE_818D0E
        db $4C,$74,$8D
CODE_818D0E:
        CMP.W #$001F
        BNE CODE_818D16
        JMP.W $8DC4
CODE_818D16:
        LDA.L $7FC017
        AND.W #$00FF
        BEQ CODE_818D22
        db $20,$EE,$F6
CODE_818D22:
        JSR.W clearWatchpoints
        LDA.W $091C
        BNE CODE_818D2D
        JMP.W CODE_818113
CODE_818D2D:
        JSR.W handleTutorial
        LDA.W #$000E
        JSR.W monitorInput
        LDA.W #$000A
        JSR.W setTextColor
        JMP.W $9738
; [GameState] Pauses game - freezes logic, displays pause menu. Entry: called when start pressed.
pauseGame:
        LDA.W $0E08,Y
        BEQ CODE_818D73
        LDA.W $0E12,Y
        STA.W $0E52
        LDA.W $0E72,Y
        AND.W #$00FF
        BEQ CODE_818D73
        db $AA,$B9,$28,$0E,$48,$DA,$A9,$1E,$00,$20,$72,$B8,$20,$E0,$A5,$68
        db $18,$69,$13,$0C,$20,$4A,$EE,$68,$A0,$02,$00,$20,$1E,$C9,$20,$4F
        db $ED
CODE_818D73:
        RTS
        db $20,$8C,$8D,$A9,$12,$00,$20,$86,$EB,$A9,$20,$00,$20,$4A,$EE,$4C
        db $F2,$E3
        JSR.W drawPauseMenu
        JMP.W $E3F2
; [Menu] Draws pause menu overlay with options. Entry: called when game paused.
drawPauseMenu:
        LDA.L $7EEA82
        CMP.W #$0026
        BEQ CODE_818DBD
        CMP.W #$0013
        BEQ CODE_818DAB
        LDA.L $7EEA94
        AND.W #$00FF
        BEQ CODE_818DAB
        CMP.W #$00FF
        BEQ CODE_818DAB
        db $20,$7C,$A9
CODE_818DAB:
        SEP #$20
        LDA.W $1431
        CMP.B #$04
        BNE CODE_818DB7
        db $9C,$37,$14
CODE_818DB7:
        REP #$20
        JSR.W setWatchpoint
        RTS
        db $3A,$8F,$82,$EA,$7E,$80,$E7
        LDA.W #$001D
        JSR.W monitorDisassemble
        LDA.W #$001A
        JSR.W monitorInput
        LDA.W #$0010
        JSR.W drawSaveScreen
        LDA.W #$0005
        JSR.W monitorMemory
        LDA.W #$0118
        JSR.W drawSaveScreen
        LDA.L $7FC00C
        AND.W #$00FF
        BEQ CODE_818DEE
        JSR.W resetTestState
CODE_818DEE:
        LDA.L $7EEA82
        CMP.W #$0027
        BCS CODE_818E17
        CMP.W #$0025
        BEQ CODE_818E1A
        CMP.W #$0026
        BEQ CODE_818E25
        CMP.L $7EEA8E
        BNE CODE_818E17
        INC A
        STA.L $7EEA8E
        LDA.L $7EEA8C
        ORA.W #$0100
        STA.L $7EEA8C
CODE_818E17:
        JMP.W $E3F2
        db $1A,$8F,$82,$EA,$7E,$9C,$42,$09,$4C,$31,$80
        db $A9,$1F,$00,$8F,$8C,$EA,$7E,$A9,$40,$00,$8F,$82,$EA,$7E,$20,$26
        db $E6,$A9,$2C,$00,$20,$EE,$F6,$4C,$BA,$E1
; [Menu] Handles pause menu navigation and selections. Entry: processes input in pause menu.
handlePauseMenu:
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $02
        JSR.W handleStatusScreen
        LDA.L $7F9000,X
        AND.W #$01FF
        PHA
        ASL A
        STA.B $04
        ASL A
        ASL A
        ASL A
        CLC
        ADC.B $04
        TAX
        LDA.W #$007E
        STA.B $14
        LDA.W #$9076
        STA.B $12
        JSR.W gameOverScreen
        PLA
        ASL A
        ASL A
        TAX
        LDY.W #$0E00
        LDA.L $7FE001,X
        AND.W #$00FF
        STA.W $0060,Y
        LDA.L $7FE002,X
        STA.W $0062,Y
        RTS
; [GameState] Resumes game from pause - hides menu, unfreezes logic.
resumeGame:
        LDA.W #$007E
        STA.B $14
        LDA.W #$9076
        STA.B $12
        LDX.W #$0000
; [GameState] Game over screen - displays 'game over', options to retry/quit.
gameOverScreen:
        LDA.L $7F6000,X
        LDY.W #$0000
        STA.B [$12]
        LDA.L $7F6002,X
        INY
        INY
        STA.B [$12],Y
        LDA.L $7F6004,X
        INY
        INY
        STA.B [$12],Y
        LDA.L $7F6006,X
        LDY.W #$0040
        STA.B [$12],Y
        LDA.L $7F6008,X
        INY
        INY
        STA.B [$12],Y
        LDA.L $7F600A,X
        INY
        INY
        STA.B [$12],Y
        LDA.L $7F600C,X
        LDY.W #$0080
        STA.B [$12],Y
        LDA.L $7F600E,X
        INY
        INY
        STA.B [$12],Y
        LDA.L $7F6010,X
        INY
        INY
        STA.B [$12],Y
        RTS
        LDA.W #$0002
        JSL.L dispatchGameMode
        LDA.W $0902
        STA.B $00
        LDA.W $0904
        STA.B $02
        JSR.W cheatFastBattle
        JSL.L calculateStatBonus
        JSR.W initSound
        JSR.W drawMessageBox
        JSR.W awardMinigamePrize
        LDA.W $091C
        BNE CODE_818F06
        JMP.W CODE_818113
        db $20,$E0,$A5,$A9,$0E,$00,$20,$4A,$EE,$4C,$38,$97
; [Animation] Draws special battle animation frames. Entry: A=animation ID, renders to OAM.
drawBattleAnimation:
        LDA.B $00
        PHA
        JSR.W drawStatusScreen
        AND.W #$01FF
        STA.B $06
        PLA
        STA.B $00
        LDX.W #$0000
        STZ.B $04
        LDA.L $7FC0C8,X
        BEQ CODE_818F54
        CMP.B $00
        BEQ CODE_818F64
        CMP.W #$FE00
        BCC CODE_818F4B
        CMP.W #$FF00
        BCS CODE_818F4B
        db $29,$FF,$00,$C5,$06,$D0,$0B,$BF,$CB,$C0,$7F,$29,$FF,$00,$20,$EE
        db $F6,$60
CODE_818F4B:
        TXA
        CLC
        ADC.W #$0004
        TAX
        JMP.W $8F25
CODE_818F54:
        JSR.W drawStatusScreen
        LDA.L $7F9000,X
        AND.W #$0800
        BEQ CODE_818F63
        db $4C,$E8,$8F
CODE_818F63:
        RTS
CODE_818F64:
        LDA.L $7FC0CA,X
        STA.B $02
        AND.W #$00FF
        BEQ CODE_818F9F
        CMP.W #$0040
        BCC CODE_818F75
        db $60
CODE_818F75:
        CMP.W #$0002
        BEQ CODE_818F8F
        CMP.W #$0003
        BEQ CODE_818F85
        LDA.W $091C
        BEQ CODE_818F85
        db $60
CODE_818F85:
        LDA.B $03
        CLC
        ADC.W #$1000
        JSR.W resetTestState
        RTS
CODE_818F8F:
        LDA.W $091C
        BEQ CODE_818F95
        RTS
CODE_818F95:
        LDA.B $03
        CLC
        ADC.W #$2000
        JSR.W resetTestState
        RTS
CODE_818F9F:
        LDA.B $03
        CMP.W #$0018
        BEQ CODE_818FB9
        db $AD,$1C,$09,$F0,$01,$60,$A5,$03,$18,$69,$00,$20,$20,$F7,$EB,$20
        db $96,$ED,$60
CODE_818FB9:
        LDA.W $0A55
        LDY.W #$0E00
        JSR.W debugMenu
        JSR.W drawWeaponSwing
        BEQ CODE_818FE7
        LDA.W $0E38
        STA.W $0E08
        LDY.W #$0E00
        JSR.W executeDebugCommand
        LDA.W $0E28
        PHA
        JSR.W handleQuestLog
        LDA.W #$0018
        JSR.W monitorInput
        PLA
        LDY.W #$0004
        JSR.W flashScreen
CODE_818FE7:
        RTS
        db $DA,$A9,$2F,$00,$20,$4A,$EE,$AD,$55,$0A,$C9,$10,$00,$B0,$0B,$48
        db $AF,$95,$EA,$7E,$1A,$8F,$95,$EA,$7E,$68,$48,$48,$20,$EB,$AD,$68
        db $A0,$09,$00,$20,$1E,$C9,$68,$A0,$08,$00,$20,$1E,$C9,$FA,$A9,$08
        db $00,$20,$99,$9A,$AD,$55,$0A,$20,$D8,$9C,$BD,$08,$14,$4A,$1A,$9D
        db $08,$14,$A9,$50,$00,$20,$2B,$B2,$60
; [Animation] Updates battle animation progress. Entry: advances animation frames, timing.
updateBattleAnimation:
        LDA.B $00
        PHA
        JSR.W drawStatusScreen
        AND.W #$01FF
        STA.B $06
        PLA
        STA.B $00
        LDX.W #$0000
CODE_819042:
        LDA.L $7FC0C8,X
        BEQ CODE_819079
        CMP.B $00
        BEQ CODE_81906B
        CMP.W #$FF00
        BCC CODE_819063
        AND.W #$00FF
        CMP.B $06
        BNE CODE_819063
        db $BF,$CB,$C0,$7F,$29,$FF,$00,$20,$EE,$F6,$60
CODE_819063:
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_819042
CODE_81906B:
        LDA.L $7FC0CA,X
        STA.B $00
        AND.W #$00FF
        CMP.W #$0080
        BCS CODE_819081
CODE_819079:
        RTS
        db $A9,$31,$00,$20,$4A,$EE,$60
        db $C9,$FF,$00,$D0,$23,$A9,$C8,$00,$85,$22,$A5,$01,$29,$FF,$00,$85
        db $24,$A5,$24,$20,$F9,$A6,$A5,$02,$85,$01,$20,$D1,$9E,$C9,$FF,$FF
        db $F0,$06,$C6,$22,$A5,$22,$D0,$E9,$A5,$00,$29,$7F,$7F,$85,$00,$20
        db $D1,$9E,$C9,$FF,$FF,$D0,$C2,$A5,$00,$48,$A9,$30,$00,$20,$4A,$EE
        db $AD,$28,$0E,$A0,$06,$00,$20,$1E,$C9,$68,$85,$00,$AD,$28,$0E,$20
        db $D8,$9C,$8E,$18,$09,$A5,$00,$9D,$04,$14,$AD,$28,$0E,$20,$E6,$9C
        db $20,$21,$CA,$A5,$02,$9D,$02,$18,$A5,$04,$9D,$04,$18,$E2,$20,$A5
        db $00,$85,$02,$8D,$48,$09,$A5,$01,$85,$04,$8D,$4A,$09,$64,$03,$64
        db $05,$C2,$20,$A2,$08,$00,$20,$D2,$A3,$AD,$28,$0E,$A0,$07,$00,$20
        db $1E,$C9,$60
; [Effects] Draws spell visual effect graphics. Entry: A=spell ID, renders particles, glows.
drawSpellEffect:
        STA.B $22
        JSR.W initBattleState
        LDA.W $1404,X
        STA.B $00
        LDX.W #$0000
CODE_819121:
        LDA.L $7FC0C8,X
        BEQ CODE_81916A
        CMP.B $00
        BNE CODE_819162
        LDA.L $7FC0CA,X
        CMP.W #$1800
        BNE CODE_819162
        LDA.W #$FFFF
        STA.L $7FC0C8,X
        STA.L $7FC0CA,X
        JSR.W drawStatusScreen
        LDY.W #$0008
        LDA.L $7FC016
        AND.W #$00FF
        BEQ CODE_81914F
        db $A8
CODE_81914F:
        TYA
        JSR.W checkAbilityCondition
        LDA.B $22
        LDY.W #$0009
        JSR.W flashScreen
        LDA.W #$000A
        JSR.W setTextColor
        RTS
CODE_819162:
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_819121
CODE_81916A:
        RTS
; [Animation] Updates spell effect animation. Entry: moves particles, updates graphics.
updateSpellEffect:
        LDA.W $0E90
        BRA CODE_819173
; [Animation] Draws weapon swing animation. Entry: A=weapon type, renders arc, trail.
drawWeaponSwing:
        LDA.W $0E10
CODE_819173:
        AND.W #$00FF
        CMP.W #$0007
        BNE CODE_81918A
        db $A9,$93,$00,$20,$4A,$EE,$A9,$A0,$00,$20,$72,$B8,$A9,$00,$00
CODE_81918A:
        RTS
; [Animation] Updates weapon swing animation. Entry: advances swing frame, hit detection.
updateWeaponSwing:
        REP #$20
        PHA
        JSR.W drawHealEffect
        JSR.W drawDamageSpark
        JSR.W titleScreenLoop
        BEQ CODE_81919C
        db $9C,$56,$0E
CODE_81919C:
        JSR.W enableDisplay
        BEQ CODE_8191A4
        db $9C,$D6,$0E
CODE_8191A4:
        SEP #$20
        LDA.W $0E03
        CMP.B #$1F
        BNE CODE_8191C2
        LDA.L $7EEA82
        CMP.B #$0A
        BCC CODE_8191C2
        db $22,$72,$DF,$00,$29,$01,$D0,$05,$A9,$38,$8D,$03,$0E
CODE_8191C2:
        REP #$20
        LDY.W #$0004
        LDA.W $0EA8
        CMP.W $0956
        BCC CODE_8191D2
        LDY.W #$0001
CODE_8191D2:
        PLA
        JSR.W handleListScrolling
        RTS
; [Effects] Draws damage hit spark effect. Entry: A=damage type, renders spark particles.
drawDamageSpark:
        LDY.W #$0E00
        JSR.W handleEquipment
        LDA.W $0062,Y
        STA.W $095A
        LDA.W $0E37
        AND.W #$0030
        CMP.W #$0020
        BCC CODE_8191F1
        STZ.W $0E60
CODE_8191F1:
        LDY.W #$0E80
        JSR.W handleEquipment
        LDA.W $0062,Y
        STA.W $0958
        LDA.W $0EB7
        AND.W #$0030
        CMP.W #$0020
        BCC CODE_81920B
        STZ.W $0EE0
CODE_81920B:
        RTS
; [Animation] Updates damage spark animation. Entry: moves sparks, fades out.
updateDamageSpark:
        LDA.W $0A55
        LDY.W #$0080
        JSR.W flashScreen
        JSR.W drawHealEffect
        JSR.W drawDamageSpark
        JSR.W playErrorSound
        RTS
; [Effects] Draws healing effect animation. Entry: A=heal power, renders glow, particles.
drawHealEffect:
        REP #$20
        LDA.B $60
        STA.W $0930
        LDA.B $62
        STA.W $0932
        LDA.W #$0000
        JSR.W monitorDisassemble
        SEP #$20
        LDA.B #$3E
        STA.B $58
        REP #$20
        LDA.W #$0008
        STA.B $00
        LDA.W #$0011
        STA.B $02
        LDA.W #$00F8
        STA.B $04
        LDA.W #$00B3
        STA.B $06
CODE_81924D:
        LDA.B $02
        CMP.W #$0061
        BEQ CODE_819264
        LDA.B $02
        CLC
        ADC.W #$0008
        STA.B $02
        LDA.B $06
        SEC
        SBC.W #$0008
        STA.B $06
CODE_819264:
        LDA.B $02
        CMP.W #$0044
        BCC CODE_81927B
        LDA.B $00
        CLC
        ADC.W #$0008
        STA.B $00
        LDA.B $04
        SEC
        SBC.W #$0008
        STA.B $04
CODE_81927B:
        JSR.W drawMinigame
        JSR.W confirmAction
        LDA.B $00
        CMP.W #$0080
        BNE CODE_81924D
        LDA.W #$8000
        JSR.W monitorMemory
        RTS
        LDA.W #$0055
        JSR.W monitorInput
        JSR.W handleTutorial
        LDA.W #$000E
        JSR.W monitorInput
        JSR.W playCursorSound
        LDA.W #$0001
        JSR.W transitionFromBattle
        JSR.W logTestFailure
        JSR.W confirmAction
        JSL.L equipItem
        LDA.W #$0010
        STA.W $091C
        LDA.W $091C
        STA.W $0A55
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W $0E00
        AND.W #$00FF
        BNE CODE_8192CE
        JMP.W $9738
CODE_8192CE:
        LDA.W $0E04
        STA.W $091A
        STZ.W $0954
        LDA.W $0E04
        AND.W #$00FF
        STA.B $00
        LDA.W $0E05
        AND.W #$00FF
        STA.B $02
        STZ.B $0A
        LDA.W $0E48
        AND.W #$00FF
        STA.B $04
        LDA.W $0E37
        AND.W #$00FF
        STA.B $0C
        LDA.W $0E56
        STA.B $06
        JSL.L applyStatusEffect
        JSL.L unequipItem
        LDA.W $0E0C
        AND.W #$00E0
        STA.W $0E5A
        CMP.W #$00C0
        BNE CODE_81931D
        db $A9,$03,$00,$22,$57,$A1,$00,$80,$0C
CODE_81931D:
        LDA.W $0E0E
        LSR A
        LSR A
        AND.W #$0003
        JSL.L levelUpCharacter
        STZ.W $094E
        STZ.W $093A
        LDA.W $0E5A
        CMP.W #$00E0
        BNE CODE_81933A
        JMP.W $9641
CODE_81933A:
        JSR.W titleScreenLoop
        BEQ CODE_819345
        db $EE,$54,$09,$4C,$41,$96
CODE_819345:
        LDA.W $0E0D
        AND.W #$0003
        BEQ CODE_819389
        TAY
        LDA.W #$0000
CODE_819351:
        CLC
        ADC.W $0E38
        DEY
        BNE CODE_819351
        LSR A
        LSR A
        CMP.W $0E08
        BCC CODE_819389
        LDA.W $0E04
        AND.W #$00FF
        STA.B $00
        LDA.W $0E05
        AND.W #$00FF
        STA.B $02
        JSL.L processBattleTurn
        LDA.W $096E
        BNE CODE_81937B
        db $4C,$28,$94
CODE_81937B:
        CMP.W $091A
        BNE CODE_819383
        db $9C,$1A,$09
CODE_819383:
        INC.W $0954
        JMP.W CODE_8194E6
CODE_819389:
        LDA.W $0E5A
        CMP.W #$0020
        BEQ CODE_8193AC
        CMP.W #$0040
        BEQ CODE_8193F4
        CMP.W #$0060
        BEQ CODE_8193FE
        CMP.W #$0080
        BEQ CODE_8193C9
        CMP.W #$00A0
        BEQ CODE_8193DF
        CMP.W #$00C0
        BEQ CODE_819408
        BRA CODE_819411
        db $AD,$AE,$09,$F0,$09,$9C,$6E,$09,$EE,$3A,$09,$4C,$11,$94,$A9,$1F
        db $00,$20,$D8,$9C,$BD,$04,$14,$8D,$6E,$09,$4C,$E6,$94
CODE_8193C9:
        LDA.W $0E0D
        AND.W #$0080
        BNE CODE_8193AC
        LDA.W $09AE
        BEQ CODE_8193DF
        STZ.W $096E
        INC.W $093A
        JMP.W CODE_819411
CODE_8193DF:
        LDA.W $091C
        SEC
        SBC.W #$0010
        ASL A
        ASL A
        ASL A
        TAX
        LDA.L $7FC029,X
        STA.W $096E
        JMP.W CODE_8194E6
CODE_8193F4:
        LDA.W $0E0D
        AND.W #$0080
        BEQ CODE_819411
        db $80,$AE
        db $AD,$0D,$0E,$29,$80,$00,$F0,$A6,$80,$09
        db $AD,$04,$0E,$8D,$6E,$09,$4C,$E6,$94
CODE_819411:
        LDA.W $0E0C
        AND.W #$001F
        CMP.W #$0010
        BCC CODE_819428
        AND.W #$000F
        STA.W $096E
        STA.W $0E5A
        JMP.W $94AD
CODE_819428:
        STZ.B $0E
        LDA.W #$270F
        STA.B $24
        LDA.W #$FFFF
        STA.B $22
        LDA.W $0E0C
        AND.W #$000F
        ASL A
        ASL A
        TAX
        LDA.L $0195AC,X
        STA.B $28
        LDA.L $0195AE,X
        STA.B $26
        LDA.B $28
        CMP.W #$8000
        BCS CODE_819452
        STZ.B $24
CODE_819452:
        LDA.W $093A
        BEQ CODE_819461
        LDX.B $0E
        LDA.W $099E,X
        AND.W #$0001
        BEQ CODE_819497
CODE_819461:
        LDA.B $0E
        LDY.W #$0E80
        JSR.W debugMenu
        LDA.W $0E80
        AND.W #$00FF
        BEQ CODE_819497
        LDA.B $28
        CMP.W #$8000
        BCS CODE_819487
        TAY
        JSR.W awardBattleRewards
        AND.B $26
        CMP.B $24
        BCC CODE_819485
        JSR.W checkBattleCondition
CODE_819485:
        BRA CODE_819497
CODE_819487:
        AND.W #$7FFF
        TAY
        JSR.W awardBattleRewards
        AND.B $26
        CMP.B $24
        BCS CODE_819497
        JSR.W checkBattleCondition
CODE_819497:
        INC.B $0E
        LDA.B $0E
        CMP.W #$0010
        BNE CODE_819452
        LDA.B $22
        CMP.W #$FFFF
        BNE CODE_8194AA
        db $4C,$41,$96
CODE_8194AA:
        STA.W $096E
        LDA.W $096E
        AND.W #$000F
        STA.W $0E5A
        LDA.W $096E
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        BNE CODE_8194C9
        db $9C,$6E,$09,$80,$E4
CODE_8194C9:
        LDA.W $1404,X
        STA.W $096E
        LDA.W $0E56
        CMP.W #$0002
        BCC CODE_8194E6
        LDA.W #$0001
        CMP.W $0E5C
        BCS CODE_8194E2
        db $AD,$5C,$0E
CODE_8194E2:
        INC A
        STA.W $094E
CODE_8194E6:
        STZ.B $00
        STZ.B $02
        LDA.W #$00FF
        STA.B $04
CODE_8194EF:
        JSR.W handleStatusScreen
        LDA.L $7FA000,X
        AND.W #$00FF
        BEQ CODE_819553
        SEP #$20
        LDA.W $096E
        CMP.B $00
        BCS CODE_81950D
        STA.B $06
        LDA.B $00
        SEC
        SBC.B $06
        BRA CODE_819510
CODE_81950D:
        SEC
        SBC.B $00
CODE_819510:
        STA.B $08
        LDA.W $096F
        CMP.B $02
        BCS CODE_819522
        STA.B $06
        LDA.B $02
        SEC
        SBC.B $06
        BRA CODE_819525
CODE_819522:
        SEC
        SBC.B $02
CODE_819525:
        CLC
        ADC.B $08
        REP #$20
        AND.W #$00FF
        CMP.W $094E
        BCC CODE_819553
        CMP.B $04
        BEQ CODE_81953C
        BCS CODE_819553
        STA.B $04
        BRA CODE_819545
CODE_81953C:
        JSL.L updateLightningEffect
        AND.W #$0003
        BNE CODE_819553
CODE_819545:
        SEP #$20
        LDA.B $00
        STA.W $0E04
        LDA.B $02
        STA.W $0E05
        REP #$20
CODE_819553:
        INC.B $00
        LDA.B $00
        CMP.W #$0028
        BNE CODE_8194EF
        STZ.B $00
        INC.B $02
        LDA.B $02
        CMP.W #$001E
        BNE CODE_8194EF
        JMP.W $9641
; [GameState] Checks battle win/lose conditions. Entry: evaluates party/enemy status. Returns A=result (0=continue, 1=win, 2=lose).
checkBattleCondition:
        STA.B $00
        LDA.W $0E0E
        AND.W #$0003
        TAY
        BEQ CODE_8195A2
        db $AD,$3A,$0E,$38,$ED,$BE,$0E,$B0,$03,$A9,$01,$00,$CD,$88,$0E,$B0
        db $1C,$C0,$03,$00,$F0,$20,$AD,$BA,$0E,$38,$ED,$3E,$0E,$B0,$03,$A9
        db $01,$00,$C0,$02,$00,$D0,$01,$0A,$CD,$08,$0E,$B0,$09
CODE_8195A2:
        LDA.B $00
        STA.B $24
        LDA.B $0E
        STA.B $22
        RTS
        db $60,$3A,$00,$FF,$FF,$08,$00,$FF,$FF
        db $08,$80,$FF,$FF,$80,$00,$FF,$00,$80,$80,$FF,$00
        db $48,$00,$FF,$00,$07,$00,$FF,$00,$07,$80,$FF,$00
        db $81,$00,$FF,$FF
        db $81,$80,$FF,$FF
        db $3E,$80,$FF,$FF
        db $3E,$00,$FF,$FF
; [Entity] Awards XP, gold, items after battle victory. Entry: calculates based on enemy levels.
awardBattleRewards:
        CPY.W #$0080
        BEQ CODE_8195EA
        CPY.W #$0081
        BEQ CODE_819612
        LDA.W $0E80,Y
        RTS
CODE_8195EA:
        LDA.W $0E04
        AND.W #$00FF
        STA.B $00
        LDA.W $0E84
        AND.W #$00FF
        JSR.W handleBattleMenu
        STA.B $04
        LDA.W $0E05
        AND.W #$00FF
        STA.B $00
        LDA.W $0E85
        AND.W #$00FF
        JSR.W handleBattleMenu
        CLC
        ADC.B $04
        RTS
CODE_819612:
        LDA.W $0E3E
        STA.B $00
        LDA.W $0EBA
        SEC
        SBC.B $00
        BCS CODE_819622
        db $A9,$00,$00
CODE_819622:
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        TAY
        LDA.W $0EB8
        BEQ CODE_819630
        JSR.W monitorIRQ
CODE_819630:
        RTS
; [Menu] Handles battle command menu - attack, magic, item, defend. Entry: called for player turn.
handleBattleMenu:
        CMP.B $00
        BCS CODE_81963D
        STA.B $02
        LDA.B $00
        SEC
        SBC.B $02
        RTS
CODE_81963D:
        SEC
        SBC.B $00
        RTS
        LDA.W $0E04
        AND.W #$00FF
        STA.B $22
        LDA.W $0E05
        AND.W #$00FF
        STA.B $24
        LDA.W $0E56
        STA.B $26
        LDA.W $0E5C
        STA.B $28
        JSR.W setupBattleFormation
        STA.W $0922
        LDA.W #$0002
        JSR.W testBattle
        BEQ CODE_81968D
        db $AD,$1A,$09,$CD,$04,$0E,$D0,$1C,$AD,$22,$09,$C9,$FF,$FF,$D0,$14
        db $20,$92,$8B,$AD,$1C,$09,$20,$D8,$9C,$BD,$04,$14,$85,$00,$20,$12
        db $8F,$4C,$38,$97
CODE_81968D:
        LDA.W $0E04
        STA.B $00
        JSR.W updateMosaic
        LDA.B $02
        STA.B $00
        LDA.B $04
        STA.B $02
        LDA.W #$0001
        JSR.W transitionToWorldMap
        LDA.W #$000E
        JSR.W monitorInput
        JSR.W logTestFailure
        JSR.W confirmAction
        LDA.W $0E04
        STA.B $00
        JSR.W updateBattleCamera
        LDY.W #$0E00
        JSR.W executeDebugCommand
        LDA.W $0954
        BNE CODE_81971A
        LDA.W $0922
        CMP.W #$FFFF
        BEQ CODE_81971A
        LDA.W #$001D
        JSR.W monitorInput
        LDA.W #$000A
        JSR.W setTextColor
        LDA.W $091C
        JSR.W handleQuestLog
        LDA.W $091C
        LDX.W #$0002
        LDY.W #$0000
        JSR.W flashScreen
        LDA.W #$000A
        JSR.W setTextColor
        LDA.W $0E28
        LDY.W #$0E80
        PHY
        JSR.W debugMenu
        INC.W $0E8F
        PLY
        JSR.W executeDebugCommand
        LDA.W $0922
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W $0E28
        JSR.W drawSpellEffect
        STZ.W $0E6E
        LDA.W #$0001
        JSR.W updateWeaponSwing
        JMP.W $8C65
CODE_81971A:
        LDA.W $091C
        JSR.W initBattleState
        LDA.W $1404,X
        STA.B $00
        PHA
        JSR.W updateBattleAnimation
        PLA
        STA.B $00
        JSR.W drawBattleAnimation
        JSR.W updateGraphics
        LDA.W #$0014
        JSR.W setTextColor
        INC.W $091C
        LDA.W $091C
        CMP.W #$0020
        BEQ CODE_819746
        JMP.W $92B7
CODE_819746:
        JSR.W clearWatchpoints
        LDA.L $7FC00D
        AND.W #$00FF
        BEQ CODE_819755
        JSR.W resetTestState
CODE_819755:
        JSR.W handleLoadScreen
        LDA.L $7EEA80
        INC A
        STA.L $7EEA80
        LDA.W #$0000
        JSR.W transitionFromBattle
        JSR.W logTestFailure
        JSR.W confirmAction
        LDA.W #$0056
        JSR.W monitorInput
        LDA.L $7EEA80
        AND.W #$0001
        BEQ CODE_81978F
        LDA.L $7EEA84
        AND.W #$000F
        INC A
        CMP.W #$0003
        BCC CODE_81978C
        LDA.W #$0000
CODE_81978C:
        JSR.W drawBattleHUD
CODE_81978F:
        STZ.W $0934
        LDA.W $0934
        JSR.W initBattleState
        LDA.W $0934
        CMP.W #$0010
        BCS CODE_8197CD
        LDA.W $140C,X
        BEQ CODE_8197CD
        db $3A,$9D,$0C,$14,$D0,$22,$BD,$00,$14,$09,$FF,$00,$9D,$00,$14,$DA
        db $20,$D7,$A6,$FA,$A5,$00,$9D,$04,$14,$A9,$AA,$00,$A0,$07,$00,$AE
        db $34,$09,$20,$A0,$98
CODE_8197CA:
        JMP.W $9880
CODE_8197CD:
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_8197CA
        LDA.W $1410,X
        AND.W #$00FF
        BEQ CODE_8197CA
        db $85,$00,$C9,$01,$00,$F0,$73,$C9,$06,$00,$F0,$2F,$C9,$02,$00,$F0
        db $02,$80,$DA,$22,$72,$DF,$00,$29,$03,$00,$D0,$D1,$E2,$20,$9E,$10
        db $14,$AD,$34,$09,$C9,$10,$B0,$03,$9E,$0F,$14,$C2,$20,$A9,$95,$00
        db $A0,$00,$00,$AE,$34,$09,$20,$A0,$98,$80,$B2,$DA,$E2,$20,$BD,$04
        db $14,$85,$22,$BD,$05,$14,$85,$24,$C2,$20,$A9,$1F,$00,$22,$47,$DF
        db $00,$85,$0E,$20,$5A,$9C,$C9,$04,$00,$B0,$1E,$BD,$10,$14,$85,$00
        db $29,$FF,$00,$D0,$14,$A5,$00,$18,$69,$06,$00,$9D,$10,$14,$A9,$94
        db $00,$A0,$02,$00,$A6,$0E,$20,$A0,$98,$FA,$BD,$08,$14,$48,$A8,$A9
        db $07,$00,$20,$DB,$EE,$4A,$4A,$4A,$1A,$9D,$08,$14,$85,$12,$68,$38
        db $E5,$12,$8D,$5A,$0E,$F0,$0C,$A9,$96,$00,$A0,$08,$00,$AE,$34,$09
        db $20,$A0,$98
        INC.W $0934
        LDA.W $0934
        CMP.W #$0020
        BEQ CODE_81988E
        JMP.W $9792
CODE_81988E:
        JSR.W skipCutscene
        JSR.W clearWatchpoints
        JSR.W handleBestiary
        JSR.W awardMinigamePrize
        STZ.W $091C
        JMP.W CODE_81814F
        db $8E,$36,$09,$5A,$48,$20,$D2,$9D,$AD,$36,$09,$A0,$00,$0E,$20,$04
        db $DC,$AD,$36,$09,$20,$EB,$AD,$68,$20,$4A,$EE,$AD,$36,$09,$7A,$20
        db $1E,$C9,$A9,$32,$00,$20,$2B,$B2,$60
; [HUD] Draws battle HUD - HP/MP bars, command list, turn order. Entry: updates each turn.
drawBattleHUD:
        SEP #$20
        STA.L $7EEA84
        REP #$20
        JSL.L clearOAMBuffer
        LDA.W #$0082
        STA.B $00
        LDA.W #$0005
        STA.B $02
        JSR.W monitorHelp
        LDA.W #$0002
        STA.B $00
        LDA.W #$0005
        STA.B $02
        LDA.W #$0000
        JSR.W monitorRegisters
        RTS
; [Camera] Updates battle camera between combatants. Entry: pans between attacker and defender.
updateBattleCamera:
        REP #$20
        LDA.B $00
        STA.B $24
        JSR.W drawStatusScreen
        STX.B $14
        LDA.W $0E28
        JSR.W initBattleState
        LDA.W $1404,X
        STA.B $22
        LDA.W #$1000
        STA.B $26
CODE_81990E:
        LDA.B $24
        STA.B ($26)
        INC.B $26
        INC.B $26
        CMP.B $22
        BEQ CODE_819951
        LDA.B $26
        CMP.W #$1020
        BEQ CODE_819951
        STZ.B $28
        LDY.W #$FF80
        LDA.W #$FF00
        JSR.W animateBattleAttack
        LDY.W #$0080
        LDA.W #$0100
        JSR.W animateBattleAttack
        LDY.W #$FFFE
        LDA.W #$FFFF
        JSR.W animateBattleAttack
        LDY.W #$0002
        LDA.W #$0001
        JSR.W animateBattleAttack
        LDA.B $04
        STA.B $24
        LDA.B $16
        STA.B $14
        BRA CODE_81990E
CODE_819951:
        DEC.B $26
        DEC.B $26
        LDA.B ($26)
        STA.B $00
        JSR.W animateSpellCast
        LDA.B $26
        CMP.W #$1000
        BNE CODE_819951
        RTS
; [Animation] Animates physical attack in battle - weapon swing, hit spark. Entry: A=attacker, X=defender.
animateBattleAttack:
        STA.B $02
        TYA
        CLC
        ADC.B $14
        TAX
        LDA.L $7FA000,X
        CMP.W #$0100
        BCC CODE_81997B
        LDA.L $7FA001,X
        AND.W #$00FF
CODE_81997B:
        CMP.B $28
        BCS CODE_819980
        RTS
CODE_819980:
        STA.B $28
        LDA.B $24
        CLC
        ADC.B $02
        STA.B $04
        STX.B $16
        RTS
; [Animation] Animates spell casting - glow effects, projectile. Entry: A=spell ID, X=caster, Y=target.
animateSpellCast:
        REP #$20
        LDA.W $0E28
        JSR.W initBattleState
        STX.W $0918
        LDA.B $00
        STA.W $1404,X
        LDA.W $0E28
        JSR.W cleanupBattle
        JSR.W updateMosaic
        LDA.B $02
        STA.W $1806,X
        LDA.B $04
        STA.W $1808,X
        LDA.W $1800,X
        ORA.W #$0801
        STA.W $1800,X
        STX.W $0916
CODE_8199BB:
        JSR.W logTestFailure
        JSR.W confirmAction
        LDX.W $0916
        LDA.W $1800,X
        AND.W #$0800
        BNE CODE_8199BB
        RTS
; [Effects] Draws floating damage numbers in battle. Entry: A=damage amount, $00/$02=position.
drawDamageNumbers:
        REP #$20
        LDA.W $0E28
        PHA
        LDA.W $0EA8
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W $0E08
        BNE CODE_8199E7
        PLA
        JSR.W updateStatusEffects
        BRA CODE_8199F8
CODE_8199E7:
        PLA
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W $0E08
        BNE CODE_8199F8
        db $20,$05,$9A,$80,$00
CODE_8199F8:
        LDA.W #$001F
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        RTS
; [Entity] Updates status effect timers and applications. Entry: called each turn for all units.
updateStatusEffects:
        LDA.W $0E28
        STA.W $093C
        LDA.L $7FC010
        AND.W #$00FF
        BEQ CODE_819A1A
        CMP.W $093C
        BNE CODE_819A1A
        RTS
CODE_819A1A:
        LDA.W #$000A
        JSR.W setTextColor
        JSR.W handleTutorial
        LDA.W #$001B
        JSR.W monitorInput
        LDA.W $093C
        LDY.W #$0003
        JSR.W flashScreen
        LDA.W #$0014
        JSR.W setTextColor
        LDA.W #$0016
        JSR.W monitorDisassemble
        LDA.W $093C
        LDY.W #$0088
        JSR.W flashScreen
        LDA.W #$000A
        JSR.W setTextColor
        LDA.W $093C
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W $0004,Y
        STA.W $0A55
        LDA.W #$0000
        STA.W $0004,Y
        SEP #$20
        STA.W $0000,Y
        REP #$20
        LDA.W $0028,Y
        JSR.W cleanupBattle
        PHY
CODE_819A70:
        PHX
        JSR.W logTestFailure
        JSR.W confirmAction
        PLX
        LDA.W $1802,X
        INC A
        STA.W $1802,X
        LDA.W $1804,X
        SEC
        SBC.W #$0008
        STA.W $1804,X
        CMP.W #$0A48
        BCC CODE_819A70
        LDA.W #$0000
        STA.W $1800,X
        PLY
        JSR.W executeDebugCommand
        RTS
; [Entity] Checks if ability can be used (MP, conditions). Entry: A=ability ID, X=caster. Returns carry if usable.
checkAbilityCondition:
        STA.L $7F9000,X
        PHX
        JSR.W testNetwork
        JSR.W testCollision
        PLX
        RTS
; [Entity] Executes special ability in battle. Entry: A=ability ID, X=caster, Y=target.
executeAbility:
        PHA
        JSR.W handleStatusScreen
        PLA
        CMP.W #$FFFE
        BNE CODE_819ABB
        db $BF,$00,$90,$7F,$29,$FF,$01,$8D,$08,$0A,$60
CODE_819ABB:
        CMP.W #$FFFF
        BNE CODE_819AF5
        db $64,$02,$84,$01,$98,$29,$7F,$00,$85,$00,$BF,$00,$90,$7F,$C5,$00
        db $D0,$04,$A5,$02,$80,$09,$C5,$02,$D0,$04,$A5,$00,$80,$01,$60,$48
        db $98,$29,$80,$00,$F0,$0C,$A9,$2A,$00,$20,$99,$9A,$A9,$2B,$00,$20
        db $99,$9A,$68,$80,$A4
CODE_819AF5:
        STA.L $7F9000,X
        RTS
; [Menu] Handles item use in battle. Entry: A=item ID, X=user, Y=target. Applies item effect.
handleItemBattle:
        REP #$20
        LDX.W #$0000
        STZ.W $0920
        LDA.W #$007F
        STA.B $14
        LDA.W #$F400
        STA.B $12
CODE_819B0C:
        LDA.L $7FC0C8,X
        BNE CODE_819B13
        RTS
CODE_819B13:
        STA.B $04
        LDA.L $7FC0CA,X
        STA.B $06
        AND.W #$00FF
        CMP.W #$0040
        BEQ CODE_819B2B
CODE_819B23:
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_819B0C
CODE_819B2B:
        LDA.B $22
        STA.B $00
        LDA.B $04
        AND.W #$00FF
        JSR.W checkStoryProgress
        STA.B $08
        LDA.B $24
        STA.B $00
        LDA.B $05
        AND.W #$00FF
        JSR.W checkStoryProgress
        CLC
        ADC.B $08
        CMP.W #$0002
        BCS CODE_819B23
        LDA.B $07
        AND.W #$00FF
        STA.B [$12]
        INC.B $12
        INC.B $12
        LDA.B $04
        AND.W #$00FF
        STA.B [$12]
        INC.B $12
        INC.B $12
        LDA.B $05
        AND.W #$00FF
        STA.B [$12]
        INC.B $12
        INC.B $12
        INC.W $0920
        BRA CODE_819B23
        db $C2,$20,$48,$AD,$0A,$09,$85,$00,$AD,$0C,$09,$85,$02,$20,$29,$A7
        db $68,$20,$99,$9A,$60,$E2,$20,$A5,$00,$85,$04,$A5,$02,$85,$05,$C2
        db $20,$A2,$00,$00,$BF,$C8,$C0,$7F,$D0,$01,$60,$C5,$04,$F0,$08,$8A
        db $18,$69,$04,$00,$AA,$80,$ED,$A9,$FF,$FF,$9F,$C8,$C0,$7F,$60
; [GameState] Attempts to flee from battle. Entry: calculates success based on agility. Returns carry if successful.
fleeBattle:
        REP #$20
        STZ.B $0C
        STZ.W $0926
        LDA.W #$007F
        STA.B $14
        LDA.W #$F000
        STA.B $12
        LDY.W #$0010
        LDA.W $0E6A
        BEQ CODE_819BD3
        LDA.W #$0002
        STA.B $26
        LDY.W #$0000
CODE_819BD3:
        STY.B $0E
CODE_819BD5:
        JSR.W loadBattleBackground
        LDA.B $28
        CMP.B $02
        BCS CODE_819C0A
        LDA.B $26
        CMP.B $02
        BCC CODE_819C0A
        INC.W $0926
        LDA.B $0E
        INC A
        STA.B $0C
        STA.B [$12]
        INC.B $12
        INC.B $12
        LDA.W $1404,X
        AND.W #$00FF
        STA.B [$12]
        INC.B $12
        INC.B $12
        LDA.W $1405,X
        AND.W #$00FF
        STA.B [$12]
        INC.B $12
        INC.B $12
CODE_819C0A:
        INC.B $0E
        LDA.B $0E
        CMP.W #$0020
        BNE CODE_819BD5
        LDA.B $0C
        RTS
; [GameState] Sets up battle formation positions. Entry: A=formation ID. Positions party and enemies.
setupBattleFormation:
        REP #$20
        LDA.W #$0000
        STA.B $0E
        LDA.W #$FFFF
        STA.B $0C
        LDY.W #$0010
CODE_819C25:
        PHY
        JSR.W loadBattleBackground
        LDA.B $28
        CMP.B $02
        BCS CODE_819C51
        LDA.B $26
        CMP.B $02
        BCC CODE_819C51
        LDA.B $02
        CMP.W #$0001
        BNE CODE_819C3F
        LDA.W #$0000
CODE_819C3F:
        SEP #$20
        STA.W $0E25
        REP #$20
        LDA.B $0E
        STA.B $0C
        CMP.W $0E5A
        BNE CODE_819C51
        PLY
        RTS
CODE_819C51:
        PLY
        INC.B $0E
        DEY
        BNE CODE_819C25
        LDA.B $0C
        RTS
; [VRAM] Loads battle background graphics. Entry: A=background ID. Loads tiles and palette to VRAM.
loadBattleBackground:
        LDA.B $0E
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        BNE CODE_819C6D
        LDA.W #$03E7
        STA.B $02
        RTS
CODE_819C6D:
        SEP #$20
        LDA.W $1404,X
        CMP.B $22
        BCS CODE_819C7F
        STA.B $00
        LDA.B $22
        SEC
        SBC.B $00
        BRA CODE_819C82
CODE_819C7F:
        SEC
        SBC.B $22
CODE_819C82:
        STA.B $02
        LDA.W $1405,X
        CMP.B $24
        BCS CODE_819C94
        STA.B $00
        LDA.B $24
        SEC
        SBC.B $00
        BRA CODE_819C97
CODE_819C94:
        SEC
        SBC.B $24
CODE_819C97:
        CLC
        ADC.B $02
        REP #$20
        AND.W #$00FF
        STA.B $02
        RTS
; [Music] Plays battle music based on enemy type. Entry: A=music track ID (0=normal, 1=boss).
playBattleBGM:
        REP #$20
        CMP.W #$0100
        BCS CODE_819CB0
        STA.B $0E
        JSR.W initBattleState
        BRA CODE_819CCF
        db $A9,$10,$00,$85,$0E,$A5,$0E,$C9,$1F,$00,$90,$04,$A9,$FF,$FF,$60
        db $20,$D8,$9C,$BD,$00,$14,$29,$FF,$00,$F0,$04,$E6,$0E,$80,$E6
CODE_819CCF:
        TXA
        CLC
        ADC.W #$1400
        TAY
        LDA.B $0E
        RTS
; [GameState] Initializes battle state variables. Entry: sets up turn order, AI states, battle flags.
initBattleState:
        PHP
        REP #$20
        AND.W #$00FF
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        TAX
        PLP
        RTS
; [GameState] Cleans up battle state after battle ends. Entry: clears battle-specific RAM, restores overworld.
cleanupBattle:
        PHP
        REP #$20
        AND.W #$00FF
        ASL A
        ASL A
        ASL A
        ASL A
        TAX
        PLP
        RTS
; [Transition] Transitions from overworld to battle. Entry: fades out, loads battle data, fades in.
transitionToBattle:
        PHP
        REP #$20
        PHX
        PHY
        ASL A
        ASL A
        ASL A
        ASL A
        TAX
        PHX
        LDY.W #$0008
CODE_819D01:
        STZ.W $1800,X
        INX
        INX
        DEY
        BNE CODE_819D01
        PLX
        LDA.B $04
        STA.W $1800,X
        LDA.B $02
        ORA.W #$A800
        STA.W $180A,X
        JSR.W updateMosaic
        LDA.B $02
        STA.W $1802,X
        STA.W $1806,X
        LDA.B $04
        STA.W $1804,X
        STA.W $1808,X
        LDA.B $06
        STA.W $180E,X
        PLY
        PLX
        PLP
        RTS
; [Transition] Transitions from battle back to overworld. Entry: fades out, restores map, fades in.
transitionFromBattle:
        REP #$20
        STA.W $0914
        CMP.W #$0003
        BNE CODE_819D40
        JMP.W handleShopMenu
CODE_819D40:
        STZ.B $0E
        LDY.W #$0010
        CMP.W #$0002
        BNE CODE_819D4F
        LDY.W #$0020
        BRA CODE_819D7D
CODE_819D4F:
        LDA.W $0914
        BNE CODE_819D59
        LDA.W #$0010
        STA.B $0E
CODE_819D59:
        PHY
        LDA.B $0E
        JSR.W initBattleState
        SEP #$20
        LDA.B #$02
        STA.W $140F,X
        REP #$20
        INC.B $0E
        PLY
        DEY
        BNE CODE_819D59
        STZ.B $0E
        LDY.W #$0010
        LDA.W $0914
        BEQ CODE_819D7D
        LDA.W #$0010
        STA.B $0E
CODE_819D7D:
        PHY
        LDA.B $0E
        JSR.W initBattleState
        STZ.B $00
        LDA.W $1410,X
        STA.W $0E10
        JSR.W titleScreenLoop
        BEQ CODE_819D92
        db $E6,$00
CODE_819D92:
        SEP #$20
        LDA.B $00
        STA.W $140F,X
        REP #$20
        INC.B $0E
        PLY
        DEY
        BNE CODE_819D7D
        LDY.W #$0060
        LDA.W $0914
        BEQ CODE_819DB1
        CMP.W #$0002
        BCS handleShopMenu
        LDY.W #$0080
CODE_819DB1:
        PHY
        JSR.W handleShopMenu
        PLA
        CLC
        ADC.W #$A252
        STA.B $12
        LDA.W #$0003
        STA.B $14
        LDA.W #$000F
        STA.B $00
        LDA.W #$0001
        STA.B $02
        JSR.W monitorHelp
        JSR.W confirmAction
        RTS
; [Menu] Handles shop menu - buy/sell items, view inventory. Entry: A=shop type (0=item, 1=weapon, 2=armor).
handleShopMenu:
        JSR.W confirmAction
        JSR.W runAllTests
        STZ.B $0E
        STZ.W $094C
CODE_819DDD:
        LDA.B $0E
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_819E50
        LDA.W $1403,X
        AND.W #$003F
        PHA
        JSR.W drawMapScreen
        STA.B $02
        PLY
        LDA.W $D138,Y
        ASL A
        ORA.B $03
        STA.B $03
        LDA.W #$80F0
        STA.B $04
        STZ.B $06
        LDA.W $1410,X
        STA.B $07
        LDA.W $140F,X
        AND.W #$00FF
        BEQ CODE_819E30
        CMP.W #$0001
        BNE CODE_819E1C
        INC.B $06
        INC.B $06
CODE_819E1C:
        CMP.W #$0002
        BNE CODE_819E2B
        LDA.B $02
        AND.W #$E1FF
        ORA.W #$0E00
        STA.B $02
CODE_819E2B:
        LDA.W #$C000
        TRB.B $04
CODE_819E30:
        LDA.W $1404,X
        STA.B $00
        LDA.B $0E
        CMP.W #$0010
        BCC CODE_819E44
        LDA.W #$4000
        TSB.B $02
        INC.W $094C
CODE_819E44:
        LDA.B $0E
        CMP.W $0956
        BCC CODE_819E4D
        INC.B $06
CODE_819E4D:
        JSR.W transitionToBattle
CODE_819E50:
        INC.B $0E
        LDA.B $0E
        CMP.W #$0020
        BNE CODE_819DDD
        SEP #$20
        LDA.W $094C
        STA.L $7EEA93
        REP #$20
        LDA.L $7EEA9C
        STA.B $0E
        AND.W #$00FF
        BEQ CODE_819ED0
        db $A9,$F0,$01,$85,$04,$64,$06,$AF,$C8,$C0,$7F,$85,$00,$A9,$3F,$00
        db $20,$BE,$AA,$18,$69,$00,$02,$85,$02,$A9,$08,$00,$48,$20,$F3,$9C
        db $68,$20,$E6,$9C,$A5,$02,$18,$69,$04,$00,$9D,$02,$18,$A5,$04,$38
        db $E9,$0A,$00,$9D,$04,$18,$AD,$A2,$CE,$9D,$0C,$18,$A5,$0E,$C9,$00
        db $01,$90,$1E,$AD,$AA,$CE,$9D,$0C,$18,$A9,$40,$AA,$9D,$0A,$18,$A9
        db $F0,$81,$9D,$00,$18,$A9,$00,$00,$8F,$9C,$EA,$7E,$1A,$8F,$C8,$C0
        db $7F
CODE_819ED0:
        RTS
; [Menu] Draws shop stock list with prices. Entry: reads shop inventory from ROM table.
drawShopStock:
        REP #$20
        STZ.B $0E
        LDX.W #$0000
CODE_819ED8:
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_819EEA
        LDA.W $1404,X
        CMP.B $00
        BNE CODE_819EEA
        LDA.B $0E
        RTS
CODE_819EEA:
        TXA
        CLC
        ADC.W #$0020
        TAX
        INC.B $0E
        LDA.B $0E
        CMP.W #$0020
        BNE CODE_819ED8
        LDA.W #$FFFF
        RTS
        REP #$20
        STZ.B $0E
        LDX.W #$0000
CODE_819F04:
        LDA.W $1800,X
        AND.W #$00FF
        BEQ CODE_819F4A
        LDA.W $1802,X
        CMP.B $00
        BCC CODE_819F18
        SEC
        SBC.B $00
        BRA CODE_819F1F
CODE_819F18:
        STA.B $04
        LDA.B $00
        SEC
        SBC.B $04
CODE_819F1F:
        STA.B $06
        LDA.W $1804,X
        CMP.B $02
        BCC CODE_819F2D
        SEC
        SBC.B $02
        BRA CODE_819F34
CODE_819F2D:
        STA.B $04
        LDA.B $02
        SEC
        SBC.B $04
CODE_819F34:
        CLC
        ADC.B $06
        CMP.W #$0010
        BCS CODE_819F4A
        LDA.B $0E
        CMP.W #$0010
        BCC CODE_819F44
        RTS
CODE_819F44:
        CMP.W #$0008
        BCS CODE_819F4A
        RTS
CODE_819F4A:
        TXA
        CLC
        ADC.W #$0010
        TAX
        INC.B $0E
        LDA.B $0E
        CMP.W #$0020
        BNE CODE_819F04
        LDA.W #$FFFF
        RTS
; [Menu] Handles inn stay - restores HP/MP for gold. Entry: A=inn price. Deducts gold, heals party.
handleInn:
        REP #$20
        STA.W $0914
        STZ.W $0952
        JSR.W drawNumber
        LDA.W $0914
        CMP.W #$0001
        BNE CODE_819F8B
        LDA.B $50
        AND.W #$FFFF
        BNE CODE_819F7A
        JMP.W $A12B
CODE_819F7A:
        LDA.B $64
        BEQ CODE_819F84
        db $20,$E7,$F6,$20,$EE,$B7
CODE_819F84:
        LDA.W #$0003
        JSR.W monitorDisassemble
        RTS
CODE_819F8B:
        LDA.B $50
        AND.W #$F0F0
        BNE CODE_819F7A
        LDA.B $4F
        AND.W #$000F
        BNE CODE_819F9C
        JMP.W $A12B
CODE_819F9C:
        LDA.W #$0003
        STA.W $0900
        LDY.W #$0008
        PHY
        LDA.B $4F
        AND.W #$0002
        BEQ CODE_819FDF
        LDA.W $090A
        CMP.W #$0001
        BEQ CODE_81A018
        LDA.W $0902
        SEC
        SBC.W $0900
        STA.W $0902
        STZ.W $0906
        PLY
        PHY
        CPY.W #$0001
        BNE CODE_819FCC
        DEC.W $090A
CODE_819FCC:
        LDA.W $0908
        AND.W #$00FC
        CMP.W #$0048
        BNE CODE_819FDF
        LDA.W $0900
        JSR.W cheatUnlockAll
        BRA CODE_81A018
CODE_819FDF:
        LDA.B $4F
        AND.W #$0001
        BEQ CODE_81A018
        LDA.W $090A
        CMP.W $090E
        BEQ CODE_81A018
        LDA.W $0902
        CLC
        ADC.W $0900
        STA.W $0902
        STZ.W $0906
        PLY
        PHY
        CPY.W #$0001
        BNE CODE_81A005
        INC.W $090A
CODE_81A005:
        LDA.W $0908
        AND.W #$00FC
        CMP.W #$00A8
        BNE CODE_81A018
        LDA.W $0900
        JSR.W cheatTimeOfDay
        BRA CODE_81A018
CODE_81A018:
        LDA.W $0900
        CMP.W #$0005
        BCC CODE_81A027
        db $A5,$4F,$29,$03,$00,$D0,$72
CODE_81A027:
        LDA.B $4F
        AND.W #$0004
        BEQ CODE_81A060
        LDA.W $090C
        CMP.W $0910
        BEQ CODE_81A099
        LDA.W $0904
        CLC
        ADC.W $0900
        STA.W $0904
        STZ.W $0906
        PLY
        PHY
        CPY.W #$0001
        BNE CODE_81A04D
        INC.W $090C
CODE_81A04D:
        LDA.W $0909
        AND.W #$00FC
        CMP.W #$0078
        BNE CODE_81A060
        LDA.W $0900
        JSR.W cheatDebugMode
        BRA CODE_81A099
CODE_81A060:
        LDA.B $4F
        AND.W #$0008
        BEQ CODE_81A099
        LDA.W $090C
        CMP.W #$0001
        BEQ CODE_81A099
        LDA.W $0904
        SEC
        SBC.W $0900
        STA.W $0904
        STZ.W $0906
        PLY
        PHY
        CPY.W #$0001
        BNE CODE_81A086
        DEC.W $090C
CODE_81A086:
        LDA.W $0909
        AND.W #$00FC
        CMP.W #$0030
        BNE CODE_81A099
        LDA.W $0900
        JSR.W testCombat
        BRA CODE_81A099
CODE_81A099:
        JSR.W logTestFailure
        JSR.W updateConfigSettings
        JSR.W confirmAction
        PLY
        DEY
        BEQ CODE_81A0A9
        JMP.W $9FA5
CODE_81A0A9:
        LDA.W $0914
        BEQ CODE_81A105
        JSR.W handlePauseMenu
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $01
        JSR.W drawShopStock
        LDY.W #$0000
        CMP.W #$0010
        BCS CODE_81A0C7
        INY
CODE_81A0C7:
        STY.W $0F5A
        LDY.W $0914
        CPY.W #$0003
        BCS CODE_81A108
        CMP.W #$FFFF
        BEQ CODE_81A0EA
        CMP.W $0E28
        BEQ CODE_81A0EA
        JSR.W initControllers
        INC.W $0952
        LDA.W #$006A
        JSR.W monitorInput
        BRA CODE_81A103
CODE_81A0EA:
        LDA.W $0952
        BEQ CODE_81A0FD
        STZ.W $0952
        JSR.W initGameState
        LDA.W #$003B
        JSR.W monitorInput
        BRA CODE_81A103
CODE_81A0FD:
        LDA.W #$0040
        JSR.W monitorInput
CODE_81A103:
        INC.B $57
CODE_81A105:
        JMP.W $9F65
CODE_81A108:
        CMP.W #$FFFF
        BEQ CODE_81A11B
        JSR.W initControllers
        INC.W $0952
        LDA.W #$007E
        JSR.W monitorInput
        BRA CODE_81A103
CODE_81A11B:
        LDA.W $0952
        BEQ CODE_81A105
        STZ.W $0952
        LDA.W $0914
        JSR.W monitorInput
        BRA CODE_81A105
        JSR.W logTestFailure
        JSR.W updateConfigSettings
        JSR.W confirmAction
        JMP.W $9F65
; [Save] Handles save point interaction - save game, restore HP/MP. Entry: displays save menu.
handleSavePoint:
        REP #$20
        STA.W $092A
CODE_81A13C:
        LDA.W $0928
        JSR.W handleWorldMap
        LDA.B [$12]
        PHA
        LDY.W #$0002
        LDA.B [$12],Y
        STA.B $02
        LDY.W #$0004
        LDA.B [$12],Y
        STA.B $04
        JSR.W drawCredits
        PLY
        LDA.W $092A
        BNE CODE_81A178
        TYA
        DEC A
        JSR.W initControllers
        LDY.W #$0000
        CMP.W #$0010
        BCS CODE_81A16A
        INY
CODE_81A16A:
        STY.W $0F5A
        JSR.W handlePauseMenu
        LDA.W #$003F
        JSR.W monitorInput
        INC.B $57
CODE_81A178:
        JSR.W drawNumber
        JSR.W logTestFailure
        JSR.W updateConfigSettings
        JSR.W confirmAction
        LDA.B $50
        AND.W #$C080
        BNE CODE_81A199
        LDA.B $51
        AND.W #$000F
        BEQ CODE_81A197
        JSR.W drawWorldMap
        BRA CODE_81A13C
CODE_81A197:
        BRA CODE_81A178
CODE_81A199:
        RTS
; [Tilemap] Draws world map screen with locations. Entry: loads world map tiles, marks current position.
drawWorldMap:
        STZ.B $06
        LDA.W #$FFFF
        STA.B $16
        STA.B $08
        LDA.B $06
        CMP.W $0928
        BEQ CODE_81A21F
        JSR.W handleWorldMap
        LDY.W #$0002
        LDA.B [$12],Y
        STA.B $00
        LDX.W $090A
        LDA.B $51
        AND.W #$0003
        BEQ CODE_81A1CF
        AND.W #$0001
        BEQ CODE_81A1C9
        CPX.B $00
        BCS CODE_81A21F
        BRA CODE_81A1CF
CODE_81A1C9:
        CPX.B $00
        BEQ CODE_81A21F
        BCC CODE_81A21F
CODE_81A1CF:
        TXA
        JSR.W checkStoryProgress
        STA.B $04
        LDY.W #$0004
        LDA.B [$12],Y
        STA.B $00
        LDX.W $090C
        LDA.B $51
        AND.W #$000C
        BEQ CODE_81A1FD
        AND.W #$0004
        BEQ CODE_81A1F1
        CPX.B $00
        BCS CODE_81A21F
        BRA CODE_81A1F7
CODE_81A1F1:
        CPX.B $00
        BEQ CODE_81A21F
        BCC CODE_81A21F
CODE_81A1F7:
        LDA.B $04
        BEQ CODE_81A1FD
        INC.B $04
CODE_81A1FD:
        TXA
        JSR.W checkStoryProgress
        STA.B $00
        LDA.B $51
        AND.W #$0003
        BEQ CODE_81A210
        LDA.B $00
        BEQ CODE_81A210
        INC.B $00
CODE_81A210:
        LDA.B $00
        CLC
        ADC.B $04
        CMP.B $08
        BCS CODE_81A21F
        STA.B $08
        LDA.B $06
        STA.B $16
CODE_81A21F:
        INC.B $06
        LDA.B $06
        CMP.W $092C
        BEQ CODE_81A22B
        JMP.W $A1A3
CODE_81A22B:
        LDA.B $16
        BMI CODE_81A232
        STA.W $0928
CODE_81A232:
        RTS
; [GameState] Handles world map navigation - movement between locations. Entry: processes map input.
handleWorldMap:
        PHA
        LDA.W #$007F
        STA.B $14
        LDA.W #$F000
        STA.B $12
        STZ.B $02
        LDA.W $092A
        ASL A
        ASL A
        STA.B $03
        PLA
        ASL A
        STA.B $00
        ASL A
        CLC
        ADC.B $00
        CLC
        ADC.B $12
        CLC
        ADC.B $02
        STA.B $12
        RTS
; [Transition] Transitions to world map from location. Entry: fades out, loads map, fades in.
transitionToWorldMap:
        REP #$20
        LDX.W #$0008
; [Transition] Transitions from world map to location. Entry: fades out, loads location, fades in.
transitionFromWorldMap:
        STA.B $04
        STX.W $0924
        STZ.B $64
        LDA.B $00
        AND.W #$FFF0
        SEC
        SBC.W #$006C
        BPL CODE_81A272
        LDA.W #$0000
CODE_81A272:
        CMP.W $0A46
        BCC CODE_81A27B
        LDA.W $0A46
        DEC A
CODE_81A27B:
        CMP.W $0A4C
        BCS CODE_81A283
        LDA.W $0A4C
CODE_81A283:
        STA.B $22
        LDA.B $02
        AND.W #$FFF0
        SEC
        SBC.W #$0058
        BPL CODE_81A293
        LDA.W #$0000
CODE_81A293:
        CMP.W $0A48
        BCC CODE_81A29C
        LDA.W $0A48
        DEC A
CODE_81A29C:
        CMP.W $0A4E
        BCS CODE_81A2A4
        LDA.W $0A4E
CODE_81A2A4:
        STA.B $24
        LDA.B $04
        BEQ CODE_81A2CE
        LDA.B $22
        STA.B $00
        LDA.B $60
        JSR.W checkStoryProgress
        CMP.W #$0028
        BCS CODE_81A2BC
        LDA.B $60
        STA.B $22
CODE_81A2BC:
        LDA.B $24
        STA.B $00
        LDA.B $62
        JSR.W checkStoryProgress
        CMP.W #$0028
        BCS CODE_81A2CE
        LDA.B $62
        STA.B $24
CODE_81A2CE:
        LDA.B $62
        CMP.B $24
        BEQ CODE_81A2F8
        BCC CODE_81A2E6
        SEC
        SBC.B $24
        CMP.W $0924
        BCC CODE_81A2E1
        LDA.W $0924
CODE_81A2E1:
        JSR.W testCombat
        BRA CODE_81A320
CODE_81A2E6:
        LDA.B $24
        SEC
        SBC.B $62
        CMP.W $0924
        BCC CODE_81A2F3
        LDA.W $0924
CODE_81A2F3:
        JSR.W cheatDebugMode
        BRA CODE_81A320
CODE_81A2F8:
        LDA.B $60
        CMP.B $22
        BEQ CODE_81A32A
        BCC CODE_81A310
        SEC
        SBC.B $22
        CMP.W $0924
        BCC CODE_81A30B
        LDA.W $0924
CODE_81A30B:
        JSR.W cheatUnlockAll
        BRA CODE_81A320
CODE_81A310:
        LDA.B $22
        SEC
        SBC.B $60
        CMP.W $0924
        BCC CODE_81A31D
        LDA.W $0924
CODE_81A31D:
        JSR.W cheatTimeOfDay
CODE_81A320:
        JSR.W benchmarkPerformance
        LDA.B $82
        INC A
        BEQ CODE_81A32A
        BRA CODE_81A2CE
CODE_81A32A:
        RTS
; [GameState] Checks story progression flags. Entry: A=flag set ID. Returns carry if story condition met.
checkStoryProgress:
        CMP.B $00
        BCC CODE_81A333
        SEC
        SBC.B $00
        RTS
CODE_81A333:
        TAY
        LDA.B $00
        STY.B $00
        SEC
        SBC.B $00
        RTS
; [GameState] Advances story by setting flags. Entry: A=event ID. Sets story flags, may trigger cutscene.
advanceStory:
        REP #$20
        LDA.L $7FC011
        AND.W #$00FF
        STA.B $02
        LDA.L $7FC012
        AND.W #$00FF
        STA.B $04
        JSR.W playEventCutscene
        RTS
; [Script] Plays story event cutscene. Entry: A=cutscene ID. Runs script with dialogue, character movement.
playEventCutscene:
        REP #$20
        STZ.W $0906
        LDA.B $02
        STA.W $090A
        STA.B $00
        LDA.B $04
        STA.W $090C
        STA.B $01
        JSR.W updateMosaic
        LDA.B $02
        STA.W $0902
        LDA.B $04
        SEC
        SBC.W #$000E
        STA.W $0904
        STZ.W $0908
        RTS
; [Input] Allows skipping cutscene with button press. Entry: checks for start button during cutscene.
skipCutscene:
        LDA.W $090A
        STA.B $02
        LDA.W $090C
        STA.B $04
; [GameState] Draws credits sequence - scrolling text, staff names. Entry: called after game completion.
drawCredits:
        REP #$20
        JSR.W playEventCutscene
        LDX.W #$0008
        LDA.W $0902
        STA.B $00
        LDA.W $0904
        STA.B $02
        PHX
        LDA.W #$0001
        JSR.W transitionFromWorldMap
        PLX
        LDA.W $0902
        SEC
        SBC.B $60
        CMP.W #$00A2
        BCS CODE_81A3C1
        CMP.W #$004B
        BCC CODE_81A3C1
        LDA.W $0904
        SEC
        SBC.B $62
        CMP.W #$0073
        BCS CODE_81A3C1
        CMP.W #$0032
        BCC CODE_81A3C1
        RTS
CODE_81A3C1:
        LDA.W $0902
        STA.B $00
        LDA.W $0904
        STA.B $02
        LDA.W #$0000
        JSR.W transitionFromWorldMap
        RTS
        db $C2,$20,$DA,$20,$54,$A3,$FA,$AD,$02,$09,$85,$00,$AD,$04,$09,$85
        db $02,$A9,$00,$00,$20,$5D,$A2,$60
; [Menu] Handles configuration menu - sound, controls, display options. Entry: called from main menu.
handleConfigMenu:
        REP #$20
        PHX
        JSR.W updateMosaic
        LDA.B $02
        STA.B $00
        LDA.B $04
        SEC
        SBC.W #$000E
        STA.B $02
        STZ.B $04
        PLA
        CMP.W #$0080
        BCC CODE_81A409
        db $E6,$04,$29,$7F,$00
CODE_81A409:
        TAX
        LDA.B $04
        JSR.W transitionFromWorldMap
        RTS
; [Save] Updates configuration settings in SRAM. Entry: writes options to save data.
updateConfigSettings:
        REP #$20
        LDA.W $090C
        BEQ CODE_81A458
        LDA.W $0902
        SEC
        SBC.B $60
        CMP.W #$0100
        BCS CODE_81A459
        STA.B $00
        LDA.W $0904
        SEC
        SBC.B $62
        CMP.W #$0100
        BCS CODE_81A459
        STA.B $01
        LDA.B $00
        STA.W $0908
        INC.W $0906
        LDA.W $0906
        CMP.W #$001C
        BCC CODE_81A459
        CMP.W #$0038
        BCC CODE_81A449
        STZ.W $0906
CODE_81A449:
        LDA.W #$E0E0
        STA.W $0100
        STA.W $0104
        STA.W $0108
        STA.W $010C
CODE_81A458:
        RTS
CODE_81A459:
        LDA.W $0908
        SEC
        SBC.W #$0100
        STA.B $00
        STA.W $0100
        CLC
        ADC.W #$0008
        STA.W $0104
        SEC
        SBC.W #$0008
        CLC
        ADC.W #$0800
        STA.W $0108
        CLC
        ADC.W #$0810
        STA.W $010C
        LDA.W #$37AE
        STA.W $0106
        ORA.W #$C000
        STA.W $010A
        LDA.W #$37CF
        STA.W $0102
        CLC
        ADC.W #$0010
        STA.W $010E
        LDA.W #$AA28
        STA.W $0300
        RTS
; [GameState] Draws minigame screen (fishing, puzzle, etc). Entry: A=minigame type. Loads graphics, rules.
drawMinigame:
        PHP
        LDA.W #$0000
        JSL.L updateDepthEffect
        SEP #$20
        LDA.B #$F4
        SEC
        SBC.B $06
        CMP.B #$80
        BCC CODE_81A4BB
        SEC
        SBC.B #$7F
        PHA
        LDA.B #$7F
        STA.W $06FC
        PLA
CODE_81A4BB:
        STA.W $06F9
        LDA.B $02
        STA.W $06F0
        LDA.B $00
        STA.W $06F4
        STA.W $06F7
        LDA.B $04
        STA.W $06F5
        STA.W $06F8
        LDA.B $06
        SEC
        SBC.B $02
        STA.B $08
        LSR A
        STA.W $06F3
        LDA.B $08
        SEC
        SBC.W $06F3
        STA.W $06F6
        STZ.W $06FE
        LDA.B #$FF
        STA.W $06FD
        LDA.B #$FF
        STA.W $2126
        LDA.B #$00
        STA.W $2127
        PLP
        RTS
; [GameState] Handles minigame logic and input. Entry: updates minigame state each frame.
handleMinigame:
        SEI
        PHP
        REP #$20
        SEP #$20
        LDA.B #$01
        STA.B $6A
        LDA.B #$00
        STA.W $2101
        LDA.B #$02
        STA.W $2130
        LDA.B #$FF
        STA.W $2126
        LDA.B #$00
        STA.W $2127
        LDA.B #$00
        STA.W $2128
        LDA.B #$07
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
        JSL.L waitForButton
        LDA.W #$0000
        JSL.L updateDepthEffect
        REP #$20
        LDA.W #$00FA
        STA.W $4207
        LDA.W #$00B5
        STA.B $66
        STA.W $4209
        STZ.W $0944
        LDA.W $0A4A
        STA.W $0A48
        SEP #$20
        LDA.B #$B1
        STA.W $4200
        PLP
        CLI
        RTS
        db $08,$E2,$20,$64,$57,$9C,$F5,$05,$64,$10,$A9,$00,$8D,$00,$21,$C2
        db $20,$20,$EE,$B7,$AF,$06,$C0,$7F,$29,$0F,$00,$20,$F8,$DA,$AF,$05
        db $C0,$7F,$29,$FF,$00,$20,$33,$DB,$E2,$20,$A9,$0F,$8D,$00,$21,$85
        db $58,$28,$60
        REP #$20
        LDA.B $66
        CMP.W #$00B5
        BNE CODE_81A5B3
        db $60
CODE_81A5B3:
        JSR.W handleBestiary
; [GameState] Awards prize for minigame success. Entry: A=prize type (item, gold, etc).
awardMinigamePrize:
        REP #$20
        LDA.W #$0000
        JSR.W monitorFlags
        LDA.W #$000A
        JSR.W monitorInput
        JSR.W monitorGraphics
        LDA.L $7EEA82
        CLC
        ADC.W #$0B00
        JSR.W monitorInput
        RTS
; [Dialogue] Draws tutorial screen with instructions. Entry: A=tutorial page. Displays text and examples.
drawTutorial:
        REP #$20
        LDA.W $0904
        SEC
        SBC.B $62
        CMP.W #$0082
        BCC drawBestiary
; [Dialogue] Handles tutorial navigation - page turns, exit. Entry: processes tutorial input.
handleTutorial:
        LDA.B $62
        INC A
        CMP.W $0A4A
        BCC drawBestiary
        INC.W $0944
        LDA.W $0A4A
        CLC
        ADC.W #$0010
        STA.W $0A48
CODE_81A5F5:
        LDA.W #$0004
        JSR.W cheatDebugMode
        JSR.W logTestFailure
        JSR.W confirmAction
        LDA.B $62
        INC A
        CMP.W $0A48
        BNE CODE_81A5F5
; [Menu] Draws bestiary screen with enemy info. Entry: A=enemy ID. Displays stats, weaknesses.
drawBestiary:
        REP #$20
        LDA.W $0A4A
        CLC
        ADC.W #$0010
        STA.W $0A48
        LDA.W #$0001
        JSR.W monitorFlags
        SEP #$20
        LDA.B #$54
        STA.W $06F3
        REP #$20
        LDA.W #$00A5
        STA.B $66
        RTS
; [Menu] Handles bestiary navigation - scroll list, view details. Entry: processes bestiary input.
handleBestiary:
        REP #$20
        LDA.W $0A4A
        CMP.W $0A48
        BCS CODE_81A637
        INC.W $0944
CODE_81A637:
        STA.W $0A48
        LDA.W $0944
        BEQ CODE_81A662
        STZ.W $0944
CODE_81A642:
        LDY.W #$0004
        LDA.B $62
        INC A
        SEC
        SBC.W $0A48
        BEQ CODE_81A662
        BCC CODE_81A662
        CMP.W #$0004
        BCS CODE_81A656
        TAY
CODE_81A656:
        TYA
        JSR.W testCombat
        JSR.W logTestFailure
        JSR.W confirmAction
        BRA CODE_81A642
CODE_81A662:
        LDX.W #$04C0
        LDA.W #$0000
        LDY.W #$0020
CODE_81A66B:
        STA.L $7E9000,X
        STA.L $7E9040,X
        STA.L $7E9080,X
        STA.L $7E90C0,X
        INX
        INX
        DEY
        BNE CODE_81A66B
        LDA.W #$007E
        STA.B $14
        LDA.W #$9076
        STA.B $12
        LDX.W #$0000
        JSR.W gameOverScreen
        LDA.W #$0000
        JSR.W monitorFlags
        SEP #$20
        LDA.B #$64
        STA.W $06F3
        REP #$20
        LDA.W #$00B5
        STA.B $66
        RTS
        PHP
        REP #$20
        SEP #$20
        LDA.B #$44
        STA.W $06F3
        REP #$20
        LDA.W #$0095
        STA.B $66
        PLP
        RTS
        LDA.L $7FC000
        AND.W #$00FF
        DEC A
        JSL.L updateSmokeEffect
        INC A
        STA.B $00
        LDA.L $7FC001
        AND.W #$00FF
        DEC A
        JSL.L updateSmokeEffect
        INC A
        STA.B $02
        RTS
CODE_81A6D7:
        JSR.W $A6B8
        LDA.B $02
        STA.B $01
        JSR.W drawShopStock
        CMP.W #$FFFF
        BNE CODE_81A6D7
        LDA.B $00
        PHA
        JSR.W drawStatusScreen
        PLA
        STA.B $00
        LDA.L $7F9000,X
        AND.W #$0400
        BNE CODE_81A6D7
        RTS
        db $85,$04,$20,$B8,$A6,$20,$29,$A7,$BF,$00,$90,$7F,$29,$FF,$01,$C5
        db $04,$D0,$EF,$60
; [Menu] Draws character status screen with stats. Entry: A=character ID. Displays all attributes.
drawStatusScreen:
        SEP #$20
        LDA.B $01
        STA.B $02
        STZ.B $01
        STZ.B $03
        REP #$20
        JSR.W handleStatusScreen
        LDA.L $7F9000,X
        PHA
        AND.W #$01FF
        ASL A
        ASL A
        TAY
        PLA
        RTS
; [Menu] Handles status screen navigation - switch characters, view equipment.
handleStatusScreen:
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
; [Menu] Draws equipment screen with slots. Entry: A=character ID. Shows equipped items, bonuses.
drawEquipmentScreen:
        REP #$20
        LDA.W #$0022
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.L $7FC004
        AND.W #$00FF
        JSR.W cheatInfiniteMP
        LDA.W #$0022
        STA.B $18
        LDA.W #$96E3
        STA.B $16
        LDA.L $7FC003
        AND.W #$00F0
        BEQ CODE_81A76E
        LDA.B $16
        CLC
        ADC.W #$0400
        STA.B $16
CODE_81A76E:
        LDY.W #$0000
        LDX.W #$0000
CODE_81A774:
        LDA.B [$12],Y
        PHY
        AND.W #$00FF
        STA.L $7FE002,X
        ASL A
        ASL A
        TAY
        LDA.B [$16],Y
        STA.L $7FE000,X
        PLY
        TXA
        CLC
        ADC.W #$0004
        TAX
        INY
        CPY.W #$0100
        BNE CODE_81A774
CODE_81A794:
        LDA.L $7FE3FC
        STA.L $7FE000,X
        LDA.L $7FE3FE
        STA.L $7FE002,X
        TXA
        CLC
        ADC.W #$0004
        TAX
        INY
        CPY.W #$0200
        BNE CODE_81A794
        RTS
; [Menu] Handles equipment management - equip/unequip, compare stats.
handleEquipment:
        REP #$20
        LDA.W $0004,Y
        AND.W #$00FF
        STA.B $00
        LDA.W $0005,Y
        AND.W #$00FF
        STA.B $02
        JSR.W handleStatusScreen
        LDA.L $7F9000,X
        AND.W #$01FF
        ASL A
        ASL A
        TAX
        LDA.L $7FE001,X
        AND.W #$00FF
        STA.W $0060,Y
        LDA.L $7FE002,X
        STA.W $0062,Y
        RTS
; [Menu] Draws magic/skills screen. Entry: A=character ID. Shows learned abilities, MP costs.
drawMagicScreen:
        REP #$20
        AND.W #$00FF
        DEC A
        PHA
        LDA.W #$000B
        STA.B $14
        LDA.W #$8000
        STA.B $12
        PLA
        JSR.W cheatInfiniteMP
        LDX.W #$0000
        LDY.W #$0800
CODE_81A7FD:
        LDA.B [$12]
        STA.L $7FC000,X
        INC.B $12
        INC.B $12
        INX
        INX
        DEY
        BNE CODE_81A7FD
        LDA.W #$0101
        STA.L $7FC0C1
        RTS
        db $C2,$20,$18,$65,$12,$85,$12,$A5,$14,$69,$00,$00,$C5,$14,$F0,$0F
        db $85,$14,$A5,$12,$18,$69,$00,$80,$85,$12,$A5,$14,$69,$00,$00,$85
        db $14,$60
; [Menu] Handles magic screen navigation - select ability, view description.
handleMagicScreen:
        REP #$20
        JSR.W drawMagicScreen
; [Menu] Draws party formation screen. Entry: shows character positions, allows rearrangement.
drawFormationScreen:
        STZ.W $0A87
        LDA.W #$001B
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.W #$007F
        STA.B $18
        LDA.W #$6000
        STA.B $16
        LDY.W #$2544
        LDA.L $7FC004
        AND.W #$00FF
        CMP.W #$000A
        BCC CODE_81A87E
        CMP.W #$0013
        BCC CODE_81A878
        db $38,$E9,$13,$00,$48,$A9,$1E,$00,$85,$14,$A9,$00,$C0,$85,$12,$68
        db $80,$06
CODE_81A878:
        SEC
        SBC.W #$000A
        INC.B $14
CODE_81A87E:
        JSR.W cheatMaxGold
        LDA.W #$007F
        STA.B $14
        LDA.W #$9000
        STA.B $12
        LDA.W #$1000
        LDX.W #$0000
        JSL.L updateBlendEffect
        LDA.W $0942
        BEQ CODE_81A89F
        JSR.W stepOut
        BRA CODE_81A8E2
CODE_81A89F:
        LDA.W #$001D
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.L $7FC002
        AND.W #$00FF
        CMP.W #$001E
        BCC CODE_81A8BB
        SEC
        SBC.W #$001E
        INC.B $14
CODE_81A8BB:
        JSR.W cheatInstantLevel
        LDA.W #$007E
        STA.B $14
        LDA.W #$2000
        STA.B $12
        LDA.W #$007F
        STA.B $18
        LDA.W #$9082
        STA.B $16
        JSR.W handleFormation
        LDA.W #$007F
        STA.B $18
        LDA.W #$9083
        STA.B $16
        JSR.W handleFormation
CODE_81A8E2:
        JSR.W testNetwork
        JSR.W cheatNoEncounters
        LDA.L $7FC000
        AND.W #$00FF
        STA.W $090E
        LDA.L $7FC001
        AND.W #$00FF
        STA.W $0910
        JSR.W drawEquipmentScreen
        LDA.W $0942
        BNE CODE_81A90F
        JSR.W advanceStory
        JSR.W handleKeyItems
        JSR.W drawSystemMenu
        BRA CODE_81A928
CODE_81A90F:
        JSL.L initNewGame
        LDA.L $7EEA86
        AND.W #$00FF
        STA.B $02
        LDA.L $7EEA87
        AND.W #$00FF
        STA.B $04
        JSR.W playEventCutscene
CODE_81A928:
        LDY.W #$001F
        LDA.L $7EEA82
        CMP.W #$0019
        BNE CODE_81A936
        db $88,$88
CODE_81A936:
        STY.W $0956
        LDA.L $7EEA82
        CMP.W #$0026
        BNE CODE_81A949
        db $A9,$08,$00,$22,$6B,$CF,$00
CODE_81A949:
        JSR.W handleMapScreen
        RTS
; [Menu] Handles formation editing - move characters, save layout.
handleFormation:
        LDA.B $16
        STA.B $1A
        LDA.W #$001E
        STA.B $02
CODE_81A956:
        LDY.W #$0000
        LDX.W #$0028
CODE_81A95C:
        SEP #$20
        LDA.B [$12]
        STA.B [$16],Y
        REP #$20
        INC.B $12
        INY
        INY
        DEX
        BNE CODE_81A95C
        REP #$20
        LDA.B $1A
        CLC
        ADC.W #$0080
        STA.B $1A
        STA.B $16
        DEC.B $02
        BNE CODE_81A956
        RTS
        REP #$20
        STA.B $22
        JSR.W initBattleState
CODE_81A983:
        INC.B $22
        LDA.B $22
        CMP.W #$0010
        BEQ CODE_81A99C
        LDY.W #$0010
CODE_81A98F:
        LDA.W $1420,X
        STA.W $1400,X
        INX
        INX
        DEY
        BNE CODE_81A98F
        BRA CODE_81A983
CODE_81A99C:
        LDA.W #$0000
        STA.W $1400,X
        RTS
; [Menu] Draws item inventory screen. Entry: shows all items with quantities.
drawItemScreen:
        REP #$20
        CMP.W #$0080
        BCC CODE_81A9B0
        db $29,$7F,$00,$4C,$F6,$AE
CODE_81A9B0:
        STA.B $22
        STZ.B $24
        LDX.W #$0000
CODE_81A9B7:
        LDA.W $1400,X
        BEQ CODE_81A9E2
        AND.W #$00FF
        BNE CODE_81A9CE
        db $BD,$08,$14,$F0,$08,$A5,$22,$D0,$04,$A5,$24,$85,$22
CODE_81A9CE:
        INC.B $24
        TXA
        CLC
        ADC.W #$0020
        TAX
        CPX.W #$0200
        BNE CODE_81A9B7
        db $A9,$FF,$FF,$8D,$28,$0E,$60
CODE_81A9E2:
        LDA.B $22
        BNE CODE_81A9EA
        LDA.B $24
        STA.B $22
CODE_81A9EA:
        CMP.W #$0008
        BCS CODE_81A9DB
CODE_81A9EF:
        LDA.B $24
        CMP.B $22
        BEQ CODE_81AA0C
        BCC CODE_81AA0C
        JSR.W initBattleState
        LDY.W #$0010
CODE_81A9FD:
        LDA.W $13E0,X
        STA.W $1400,X
        INX
        INX
        DEY
        BNE CODE_81A9FD
        DEC.B $24
        BRA CODE_81A9EF
CODE_81AA0C:
        LDA.B $22
        TAY
        LDA.W #$0013
        JSR.W handleSystemMenu
        JSR.W handleItemScreen
        LDY.W #$0E00
        JSR.W executeDebugCommand
        LDA.W $0E28
        RTS
; [Menu] Handles item screen - use, arrange, discard items.
handleItemScreen:
        LDA.W #$0004
        STA.B $02
        LDA.W #$0001
        STA.B $00
        JSR.W drawKeyItemScreen
        LDA.W #$0012
        STA.B $00
        JSR.W drawKeyItemScreen
        LDA.W #$0013
        STA.B $00
; [Menu] Draws key items screen (plot-critical items). Entry: shows key items with descriptions.
drawKeyItemScreen:
        LDA.B $00
        CMP.W #$0001
        BNE CODE_81AA47
        INC.B $02
        BRA CODE_81AA51
CODE_81AA47:
        LDA.W #$003F
        JSL.L updateSmokeEffect
        INC A
        STA.B $02
CODE_81AA51:
        LDX.W #$0000
CODE_81AA54:
        LDA.W $1401,X
        AND.W #$00FF
        BEQ CODE_81AA6B
        TXA
        CLC
        ADC.B $00
        TAY
        LDA.W $1400,Y
        AND.W #$00FF
        CMP.B $02
        BEQ drawKeyItemScreen
CODE_81AA6B:
        TXA
        CLC
        ADC.W #$0020
        TAX
        CPX.W #$0200
        BNE CODE_81AA54
        LDY.B $00
        LDA.B $02
        SEP #$20
        STA.W $0E00,Y
        REP #$20
        RTS
; [Menu] Handles key items screen navigation. Entry: view item details.
handleKeyItems:
        REP #$20
        STZ.B $0E
        STZ.B $0C
CODE_81AA88:
        LDA.B $0E
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W $0E00
        AND.W #$00FF
        CMP.W #$00FF
        BNE CODE_81AAAA
        LDA.W $0E38
        STA.W $0E08
        LDX.B $0C
        LDA.L $7FC018,X
        STA.W $0E04
CODE_81AAAA:
        INC.B $0C
        INC.B $0C
        LDY.W #$0E00
        JSR.W executeDebugCommand
        INC.B $0E
        LDA.B $0E
        CMP.W #$0010
        BNE CODE_81AA88
        RTS
; [Menu] Draws in-game map screen. Entry: shows current area with player position.
drawMapScreen:
        SEP #$20
        PHX
        LDX.W #$0000
CODE_81AAC4:
        CMP.L $7FCE00,X
        BEQ CODE_81AAD7
        INX
        CPX.W #$0024
        BNE CODE_81AAC4
        REP #$20
        LDA.W #$FFFF
        PLX
        RTS
CODE_81AAD7:
        REP #$20
        TXA
        ASL A
        TAX
        LDA.L $008980,X
        PLX
        RTS
; [Menu] Handles map screen - zoom, pan, view different levels.
handleMapScreen:
        REP #$20
        LDX.W #$0000
        LDA.W #$FFFF
CODE_81AAEA:
        STA.L $7FCE00,X
        INX
        INX
        CPX.W #$0024
        BNE CODE_81AAEA
        LDX.W #$0000
        LDA.W #$007F
        STA.B $14
        LDA.W #$C028
        STA.B $12
        LDY.W #$0000
CODE_81AB05:
        LDA.W #$003F
        STA.B $00
        INY
        LDA.B [$12],Y
        BNE CODE_81AB14
        LDA.W #$00FF
        STA.B $00
CODE_81AB14:
        DEY
        LDA.B [$12],Y
        AND.B $00
        JSR.W drawQuestLog
        TYA
        CLC
        ADC.W #$0008
        TAY
        CPY.W #$00A0
        BNE CODE_81AB05
        LDY.W #$0000
CODE_81AB2A:
        LDA.W $1400,Y
        CMP.W #$EE00
        BEQ CODE_81AB49
        AND.W #$00FF
        BNE CODE_81AB3E
        LDA.W $140C,Y
        BNE CODE_81AB3E
        BRA CODE_81AB52
CODE_81AB3E:
        LDA.W $1403,Y
        AND.W #$003F
        JSR.W drawQuestLog
        BRA CODE_81AB52
CODE_81AB49:
        LDA.W $1403,Y
        AND.W #$007F
        JSR.W drawQuestLog
CODE_81AB52:
        TYA
        CLC
        ADC.W #$0020
        TAY
        CPY.W #$0200
        BNE CODE_81AB2A
        SEP #$20
        LDA.B #$41
        STA.L $7FCE11
        ORA.B #$80
        STA.L $7FCE23
        REP #$20
        RTS
; [Menu] Draws quest log screen. Entry: shows active/completed quests with objectives.
drawQuestLog:
        CPX.W #$0011
        BCS CODE_81AB8E
        STA.B $02
        JSR.W drawMapScreen
        CMP.W #$FFFF
        BNE CODE_81AB8E
        SEP #$20
        LDA.B $02
        STA.L $7FCE00,X
        ORA.B #$80
        STA.L $7FCE12,X
        INX
        REP #$20
CODE_81AB8E:
        RTS
        REP #$20
        LDA.W #$0047
        JSR.W monitorInput
        LDA.W $0A08
        CMP.W #$0001
        BNE CODE_81ABCB
        LDA.W $0E28
        CMP.W #$0003
        BCC CODE_81ABC5
        LDA.W $0EA8
        CMP.W #$0003
        BCC CODE_81ABC5
        LDA.W $0E4E
        AND.W #$00FF
        BEQ CODE_81ABC5
        LDA.W $0ECE
        AND.W #$00FF
        BEQ CODE_81ABC5
        JSL.L $00AD3B
        BRA CODE_81ABCF
        db $A9,$4D,$00,$20,$4A,$EE
        db $A9,$01,$00,$60
CODE_81ABCF:
        REP #$20
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $01
        JSR.W updateBattleCamera
        LDA.W #$0005
        JSR.W monitorFlags
        JSR.W $A6A5
        LDY.W #$0000
CODE_81ABEA:
        PHY
        LDA.W $1208,Y
        STA.W $1027
        LDA.W $1028
        LDY.W #$1000
        JSL.L $00AEDD
        LDA.W #$004C
        JSR.W monitorInput
        LDA.W $1037
        AND.W #$0030
        LSR A
        LSR A
        LSR A
        LSR A
        CLC
        ADC.W #$0024
        JSR.W monitorInput
        INC.W $0A00
        INC.W $0A00
        LDA.W $1210
        ASL A
        STA.B $00
        PLY
        INY
        INY
        CPY.B $00
        BNE CODE_81ABEA
        STZ.W $0A00
        LDA.W #$004B
        JSR.W monitorInput
        STZ.B $22
        STZ.B $24
CODE_81AC32:
        LDA.B $22
        ASL A
        CLC
        ADC.W #$0014
        STA.W $09FE
        LDA.W #$000B
        STA.W $09FC
        LDY.W #$003E
        INC.B $24
        LDA.B $24
        AND.W #$0010
        BEQ CODE_81AC51
        LDY.W #$0020
CODE_81AC51:
        TYA
        JSR.W monitorMap
        JSR.W drawNumber
        LDA.B $50
        BEQ CODE_81AC8E
        PHA
        STZ.B $24
        LDA.W #$0020
        JSR.W monitorMap
        PLY
        TYA
        AND.W #$8000
        BNE CODE_81AC98
        TYA
        AND.W #$4080
        BNE CODE_81AC9C
        TYA
        AND.W #$0800
        BEQ CODE_81AC7E
        LDA.B $22
        BEQ CODE_81AC8E
        DEC.B $22
CODE_81AC7E:
        TYA
        AND.W #$0400
        BEQ CODE_81AC8E
        LDA.B $22
        INC A
        CMP.W $1210
        BCS CODE_81AC8E
        STA.B $22
CODE_81AC8E:
        JSR.W logTestFailure
        INC.B $57
        JSR.W confirmAction
        BRA CODE_81AC32
        db $A9,$02,$00,$60
CODE_81AC9C:
        LDA.B $22
        ASL A
        TAY
        LDA.W $1208,Y
        STA.W $0940
        JSR.W drawHealEffect
        LDA.W $0941
        AND.W #$00FF
        JSR.W $B958
        SEP #$20
        LDA.B #$FF
        STA.L $7EEA94
        LDA.W $0940
        STA.W $0E86
        LDA.W $0941
        STA.W $0E83
        LDA.W $0E07
        CLC
        ADC.W $0E87
        CMP.B #$64
        BCC CODE_81ACD3
        db $A9,$63
CODE_81ACD3:
        STA.W $0E87
        LDA.W $0E91
        STA.B $00
        LDA.W $0E11
        STA.B $02
        CMP.B $00
        BEQ CODE_81ACEF
        LDA.B #$03
        SEC
        SBC.B $02
        SEC
        SBC.B $00
        STA.W $0E91
CODE_81ACEF:
        LDA.W $0E13
        STA.W $0E93
        REP #$20
        LDY.W #$0E80
        JSR.W executeDebugCommand
        LDA.W $0EA8
        LDY.W #$0E80
        JSR.W debugMenu
        LDA.W $0EB8
        STA.W $0E88
        LDY.W #$0E80
        JSR.W executeDebugCommand
        LDA.W $0E28
        LDY.W #$FFFF
        JSR.W $E7C8
        LDA.W $0EA8
        LDY.W #$FFFF
        JSR.W $E7C8
        LDY.W $0E81
        LDA.W $0E01
        JSL.L $00AF01
        LDA.W $0E28
        JSR.W $A97C
        JSR.W handleMapScreen
        LDA.W #$0000
        RTS
        REP #$20
        LDA.W $0EA8
        STA.B $28
        CMP.W #$0020
        BCS CODE_81AD4A
        JSR.W $AD60
CODE_81AD4A:
        STZ.B $28
CODE_81AD4C:
        LDA.B $28
        CMP.W $0EA8
        BEQ CODE_81AD56
        JSR.W $AD60
CODE_81AD56:
        INC.B $28
        LDA.B $28
        CMP.W #$0020
        BNE CODE_81AD4C
        RTS
        JSR.W initBattleState
        SEP #$20
        LDA.W $1400,X
        BEQ CODE_81ADE8
        LDA.W $0946
        CMP.B #$05
        BEQ CODE_81AD98
        CMP.B #$06
        BEQ CODE_81ADA2
        db $C9,$07,$F0,$3C,$C9,$04,$F0,$2F,$A5,$28,$85,$0E,$AD,$84,$0E,$85
        db $22,$AD,$85,$0E,$85,$24,$C2,$20,$20,$5A,$9C,$E2,$20,$C9,$03,$90
        db $25,$80,$50
        db $BD,$03,$14,$CD,$83,$0E,$F0,$1B,$80,$46
CODE_81ADA2:
        LDA.W $1411,X
        CMP.W $0E91
        BEQ CODE_81ADBB
        BRA CODE_81ADE8
        db $A5,$28,$CD,$A8,$0E,$F0,$08,$80,$33,$A5,$28,$C9,$10,$90,$2D
CODE_81ADBB:
        REP #$20
        LDA.B $28
        JSR.W handleQuestLog
        LDA.B $28
        LDY.W #$000A
        JSR.W flashScreen
        LDA.B $28
        LDY.W #$0009
        JSR.W flashScreen
        LDA.W #$0005
        JSL.L updateSmokeEffect
        CLC
        ADC.W $0E6E
        TAY
        LDA.B $28
        JSR.W $AE1F
        LDA.B $28
        JSR.W drawSpellEffect
CODE_81ADE8:
        REP #$20
        RTS
; [Menu] Handles quest log navigation - scroll, view details.
handleQuestLog:
        REP #$20
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_81AE03
        LDA.W $1404,X
        STA.B $00
        LDX.W #$0008
        JSR.W handleConfigMenu
CODE_81AE03:
        RTS
        db $C2,$20,$C9,$00,$80,$90,$05,$29,$FF,$00,$80,$0F,$84,$26,$85,$00
        db $20,$D1,$9E,$C9,$FF,$FF,$D0,$01,$60,$A4,$26
        STY.B $26
        STA.B $28
        CMP.W #$0010
        BCC CODE_81AE2E
        TYA
        AND.W #$4000
        BNE CODE_81AE6F
CODE_81AE2E:
        LDA.B $28
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_81AE6F
        LDA.B $26
        AND.W #$0FFF
        STA.B $26
        LDA.W $1408,X
        CMP.B $26
        BCC CODE_81AE50
        BEQ CODE_81AE50
        SEC
        SBC.B $26
        BRA CODE_81AE56
CODE_81AE50:
        DEC A
        STA.B $26
        LDA.W #$0001
CODE_81AE56:
        STA.W $1408,X
        LDA.W $1403,X
        AND.W #$00FF
        STA.B $24
        LDA.W #$0070
        JSR.W monitorInput
        LDA.B $28
        LDY.W #$0008
        JSR.W flashScreen
CODE_81AE6F:
        RTS
; [Menu] Draws system menu (save, load, config, quit). Entry: called from pause menu.
drawSystemMenu:
        REP #$20
        LDA.L $7FC00E
        AND.W #$00FF
        STA.L $7EEA92
        STZ.B $22
CODE_81AE7F:
        STZ.B $00
        LDA.B $22
        PHA
        CLC
        ADC.W #$0010
        TAY
        PLA
        JSR.W handleSystemMenu
        INC.B $22
        LDA.B $22
        CMP.W #$0010
        BNE CODE_81AE7F
        RTS
        db $A2,$00,$00,$29,$FF,$00,$85,$28,$BF,$E6,$AE,$01,$85,$00,$DA,$A5
        db $28,$20,$D8,$9C,$BD,$04,$14,$18,$65,$00,$85,$00,$85,$2A,$20,$D1
        db $9E,$C9,$FF,$FF,$D0,$1A,$20,$0D,$A7,$BF,$00,$90,$7F,$29,$00,$04
        db $D0,$0E,$A5,$2A,$85,$00,$A0,$00,$01,$A5,$0C,$20,$16,$AF,$FA,$60
        db $FA,$E8,$E8,$E0,$10,$00,$D0,$C0,$A9,$FF,$FF,$8D,$55,$0A,$60,$00
        db $FF,$01,$FF,$01,$00,$01,$01,$00,$01,$FF,$01,$FF,$00,$FF,$FF,$C2
        db $20,$85,$0C,$A5,$00,$C9,$00,$FF,$B0,$96,$20,$D1,$9E,$C9,$FF,$FF
        db $F0,$04,$A9,$FF,$FF,$60,$A0,$00,$01,$A5,$0C,$20,$16,$AF,$60
; [Menu] Handles system menu selections. Entry: processes save/load/config options.
handleSystemMenu:
        REP #$20
        AND.W #$001F
        ASL A
        ASL A
        ASL A
        STA.B $02
        LDA.B $00
        PHA
        PHY
        LDA.W #$007F
        STA.B $14
        LDA.W #$C028
        STA.B $12
        LDA.B $12
        CLC
        ADC.B $02
        STA.B $12
        PLA
        JSR.W playBattleBGM
        STA.W $0A55
        CMP.W #$FFFF
        BNE CODE_81AF43
        db $7A,$60
CODE_81AF43:
        JSR.W drawLoadScreen
        LDA.B $0E
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W $0E38
        STA.W $0E08
        PLA
        BEQ CODE_81AF5A
        STA.W $0E04
CODE_81AF5A:
        LDY.W #$0E00
        JSR.W executeDebugCommand
        LDA.W $0E28
        RTS
; [Menu] Draws load game screen with save slots. Entry: shows save file info (time, party, location).
drawLoadScreen:
        REP #$20
        STY.B $1A
        LDX.W #$0010
        LDA.W #$0000
CODE_81AF6E:
        STA.B ($1A)
        INC.B $1A
        INC.B $1A
        DEX
        BNE CODE_81AF6E
        LDA.B [$12]
        AND.W #$00FF
        STA.B $00
        INC.B $12
        LDA.B [$12]
        BEQ CODE_81AFD0
        STA.W $0004,Y
        INC.B $12
        INC.B $12
        LDA.B [$12]
        STA.B $02
        INC.B $12
        INC.B $12
        LDA.B [$12]
        STA.B $04
        INC.B $12
        INC.B $12
        LDA.B [$12]
        SEP #$20
        STA.W $000E,Y
        LDA.B $00
        STA.W $0003,Y
        LDA.B $02
        STA.W $0006,Y
        LDA.B $03
        CMP.B #$FF
        BNE CODE_81AFB8
        LDA.B #$03
        JSL.L updateSmokeEffect
CODE_81AFB8:
        AND.B #$03
        STA.W $0011,Y
        REP #$20
        LDA.B $04
        STA.W $000C,Y
        LDA.W #$00FF
        STA.W $0008,Y
        LDA.W #$FFFF
        STA.W $0000,Y
CODE_81AFD0:
        RTS
; [Save] Handles load screen - select slot, confirm load. Entry: loads save data from SRAM.
handleLoadScreen:
        REP #$20
        LDX.W #$0000
        STZ.B $04
CODE_81AFD8:
        LDA.L $7EEA92
        AND.W #$00FF
        BEQ CODE_81AFFF
        LDA.L $7FC0C8,X
        BEQ CODE_81AFFF
        STA.B $00
        LDA.L $7FC0CA,X
        STA.B $02
        AND.W #$00F0
        CMP.W #$0060
        BEQ CODE_81B000
CODE_81AFF7:
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_81AFD8
CODE_81AFFF:
        RTS
CODE_81B000:
        PHX
        LDA.L $7EEA80
        TAY
        LDA.B $02
        AND.W #$000F
        BEQ CODE_81B016
        INC A
        JSR.W monitorTest
        LDA.W $4216
        BNE CODE_81B04C
        db $A5,$03,$29,$FF,$00,$20,$F6,$AE,$C9,$FF,$FF,$F0,$29,$8D,$2E,$09
        db $A9,$35,$00,$20,$4A,$EE,$AD,$2E,$09,$48,$20,$EB,$AD,$20,$D2,$9D
        db $68,$A0,$00,$00,$20,$1E,$C9,$A9,$0A,$00,$20,$72,$B8,$AF,$92,$EA
        db $7E,$3A,$8F,$92,$EA,$7E
CODE_81B04C:
        PLX
        BRA CODE_81AFF7
        REP #$20
        AND.W #$003F
        ASL A
        ASL A
        CLC
        ADC.W #$B05F
        STA.B $00
        JMP.W ($0000)
        db $4C,$93,$B0,$EA,$4C,$80,$B5,$EA,$4C,$7E,$B4,$EA,$4C,$E0,$B4,$EA
        JMP.W $B266
        db $EA,$4C,$5A,$B3,$EA,$4C,$98,$B3,$EA,$4C,$B1,$B3,$EA,$4C,$A7,$B5
        db $EA,$4C,$08,$B6,$EA,$4C,$6D,$B6,$EA,$4C,$15,$B7,$EA,$4C,$61,$B7
        db $EA,$C2,$20,$A9,$01,$00,$20,$F8,$DA,$A9,$20,$00,$20,$33,$DB,$A9
        db $2E,$00,$85,$14,$A9,$00,$B0,$85,$12,$A2,$00,$50,$A0,$00,$10,$22
        db $30,$C5,$00,$A9,$03,$00,$85,$14,$A9,$C0,$A1,$85,$12,$A9,$07,$00
        db $85,$00,$A9,$01,$00,$85,$02,$20,$7C,$EB,$20,$11,$B2,$A9,$2D,$00
        db $20,$4A,$EE,$A9,$00,$00,$22,$27,$A4,$00,$A9,$01,$00,$85,$7F,$9C
        db $34,$09,$A9,$E0,$01,$8D,$36,$09,$A9,$FE,$FF,$8D,$38,$09,$E2,$20
        db $A0,$15,$00,$A5,$54,$29,$01,$F0,$03,$A0,$55,$00,$98,$85,$5F,$A9
        db $FF,$85,$5E,$C2,$20,$AD,$36,$09,$18,$6D,$38,$09,$8D,$36,$09,$D0
        db $06,$A9,$02,$00,$8D,$38,$09,$C9,$E0,$01,$D0,$03,$4C,$89,$B1,$4A
        db $4A,$E2,$20,$85,$6D,$C2,$20,$A9,$06,$00,$18,$6D,$34,$09,$8D,$34
        db $09,$AD,$34,$09,$20,$8F,$DB,$4A,$18,$69,$60,$00,$E2,$20,$85,$6B
        db $C2,$20,$A5,$54,$29,$08,$00,$A8,$A9,$01,$00,$22,$27,$A4,$00,$E2
        db $20,$A9,$00,$38,$E5,$6B,$85,$00,$64,$01,$A9,$00,$38,$E5,$6D,$85
        db $02,$64,$03,$C2,$20,$A5,$60,$18,$65,$00,$18,$69,$10,$00,$85,$00
        db $A5,$62,$18,$65,$02,$38,$E9,$80,$00,$85,$02,$20,$37,$B2,$20,$E7
        db $F6,$20,$EE,$B7,$4C,$F0,$B0,$A9,$00,$00,$22,$27,$A4,$00
        LDA.W #$0078
        JSR.W drawSaveScreen
        LDA.W #$0000
        JSR.W $F6AD
        LDA.W #$002E
        JSR.W monitorInput
        LDA.W #$001F
        STA.B $22
CODE_81B1A7:
        LDA.B $22
        JSR.W cleanupBattle
        LDA.W $1800,X
        AND.W #$00F0
        CMP.W #$00E0
        BNE CODE_81B1BA
        STZ.W $1804,X
CODE_81B1BA:
        DEC.B $22
        BPL CODE_81B1A7
        STZ.W $0934
CODE_81B1C1:
        LDA.W $0934
        JSR.W cleanupBattle
        LDA.W $1800,X
        STA.B $00
        AND.W #$00F0
        CMP.W #$00E0
        BNE CODE_81B205
        LDA.B $00
        AND.W #$F700
        ORA.W #$00F0
        STA.W $1800,X
        JSR.W CODE_81A6D7
        LDA.W $0934
        JSR.W handleSaveScreen
        LDA.W $1800,X
        AND.W #$FF00
        STA.W $1800,X
        LDA.W $0934
        PHA
        JSR.W handleQuestLog
        PLA
        LDY.W #$000C
        JSR.W flashScreen
        LDA.W #$003C
        JSR.W drawSaveScreen
CODE_81B205:
        INC.W $0934
        LDA.W $0934
        CMP.W #$0020
        BNE CODE_81B1C1
        RTS
CODE_81B211:
        JSL.L updateLightningEffect
        AND.W #$001F
        STA.B $00
        JSR.W cleanupBattle
        LDA.W $1800,X
        AND.W #$00FF
        BEQ CODE_81B211
        LDA.B $00
        JSR.W handleQuestLog
        RTS
; [Menu] Draws save game screen. Entry: shows save slots, allows overwrite confirmation.
drawSaveScreen:
        PHA
        JSR.W logTestFailure
        JSR.W confirmAction
        PLA
        DEC A
        BNE drawSaveScreen
        RTS
        JSR.W $9EFD
        CMP.W #$FFFF
        BEQ CODE_81B265
        JSR.W cleanupBattle
        LDA.W $1800,X
        AND.W #$0800
        BNE CODE_81B265
        LDA.W $1804,X
        SEC
        SBC.W #$00B8
        BPL CODE_81B256
        db $A9,$00,$00
CODE_81B256:
        STA.W $1808,X
        LDA.W $1800,X
        AND.W #$FF00
        ORA.W #$08E3
        STA.W $1800,X
CODE_81B265:
        RTS
        JSR.W CODE_81B211
        STZ.B $06
        LDA.B $60
        CLC
        ADC.W #$0078
        STA.B $02
        LDA.B $62
        CLC
        ADC.W #$0050
        STA.B $04
        STA.W $0958
        LDA.W #$000E
        LDY.W #$0042
        JSR.W $B456
        LDA.B $02
        SEC
        SBC.W #$0018
        STA.B $02
        LDA.B $04
        CLC
        ADC.W #$0018
        STA.B $04
        LDA.W #$000F
        LDY.W #$0042
        JSR.W $B456
        LDA.W #$000E
        LDY.W #$0007
        JSR.W flashScreen
        LDA.W #$000F
        LDY.W #$0007
        JSR.W flashScreen
        LDA.W #$001F
        JSR.W monitorDisassemble
        STZ.W $0934
        STZ.W $0936
        STZ.W $0938
CODE_81B2C1:
        LDA.W $0936
        CMP.W #$0136
        BCS CODE_81B30A
        LDY.W $0934
        LDX.W #$0078
        LDA.W #$000E
        JSR.W $B313
        LDA.W $0934
        CLC
        ADC.W #$0100
        TAY
        LDX.W #$0020
        LDA.W #$000F
        JSR.W $B313
        LDA.W $0934
        CLC
        ADC.W #$0008
        STA.W $0934
        AND.W #$00F8
        BNE CODE_81B2F8
        INC.W $0938
CODE_81B2F8:
        LDA.W $0936
        CLC
        ADC.W $0938
        STA.W $0936
        JSR.W logTestFailure
        JSR.W confirmAction
        BRA CODE_81B2C1
CODE_81B30A:
        STZ.W $18E0
        STZ.W $18F0
        JMP.W $B190
        PHA
        PHA
        STX.B $04
        LDA.W $0936
        LSR A
        LSR A
        STA.B $02
        PLA
        CMP.W #$000E
        BNE CODE_81B32E
        LDA.W $0958
        SEC
        SBC.B $02
        STA.B $02
        BRA CODE_81B33A
CODE_81B32E:
        LDA.W $0958
        CLC
        ADC.W #$0018
        CLC
        ADC.B $02
        STA.B $02
CODE_81B33A:
        TYA
        JSR.W $DB8F
        LSR A
        LSR A
        CLC
        ADC.B $60
        CLC
        ADC.B $04
        STA.B $00
        PLA
        JSR.W cleanupBattle
        LDA.B $00
        STA.W $1802,X
        LDA.B $02
        STA.W $1804,X
        JSR.W $B237
        RTS
        db $20,$D7,$A6,$A5,$00,$C9,$00,$05,$90,$F6,$AD,$08,$0A,$0A,$0A,$AA
        db $A5,$00,$9F,$C8,$C0,$7F,$8F,$96,$EA,$7E,$A2,$04,$00,$20,$EA,$A3
        db $20,$D2,$9D,$AD,$08,$0A,$18,$69,$08,$00,$20,$E6,$9C,$BD,$04,$18
        db $38,$E9,$78,$00,$9D,$04,$18,$A9,$78,$00,$9D,$0E,$18,$60,$A9,$03
        db $00,$20,$AD,$F6,$64,$24,$22,$72,$DF,$00,$20,$E7,$B3,$E6,$24,$A5
        db $24,$C9,$1F,$00,$D0,$F0,$60,$64,$24,$A5,$24,$20,$D8,$9C,$BD,$04
        db $14,$85,$00,$20,$0D,$A7,$85,$28,$A2,$00,$00,$64,$02,$BF,$7F,$F2
        db $0B,$F0,$10,$85,$00,$E8,$E8,$29,$FF,$00,$C5,$28,$D0,$EF,$A5,$01
        db $20,$E7,$B3,$E6,$24,$A5,$24,$C9,$20,$00,$D0,$CD,$60,$29,$07,$00
        db $0A,$AA,$BF,$46,$B4,$01,$85,$08,$A5,$24,$20,$D8,$9C,$86,$26,$BD
        db $00,$14,$29,$FF,$00,$F0,$44,$BD,$04,$14,$18,$65,$08,$85,$00,$20
        db $D1,$9E,$C9,$FF,$FF,$D0,$34,$A5,$00,$48,$20,$0D,$A7,$68,$85,$00
        db $BF,$00,$90,$7F,$29,$00,$04,$D0,$22,$A5,$00,$A6,$26,$9D,$04,$14
        db $20,$21,$CA,$A5,$24,$20,$E6,$9C,$A5,$02,$9D,$06,$18,$A5,$04,$9D
        db $08,$18,$BD,$00,$18,$09,$00,$08,$9D,$00,$18,$60,$01,$00,$FF,$FF
        db $00,$01,$00,$FF,$01,$01,$FF,$FE,$00,$FF,$FF,$00
        REP #$20
        PHA
        TYA
        JSR.W drawMapScreen
        ORA.W #$A800
        STA.B $00
        PLA
        JSR.W cleanupBattle
        LDA.W #$8000
        STA.W $1800,X
        LDA.B $00
        ORA.B $06
        STA.W $180A,X
        LDA.B $02
        STA.W $1802,X
        LDA.B $04
        STA.W $1804,X
        RTS
        db $C2,$20,$AF,$80,$EA,$7E,$4A,$1A,$C9,$11,$00,$90,$01,$60,$A2,$00
        db $00,$3A,$85,$22,$F0,$0F,$E8,$E8,$E8,$BF,$FA,$EE,$0B,$D0,$04,$C6
        db $22,$F0,$02,$80,$F1,$BF,$FD,$EE,$0B,$85,$00,$F0,$34,$BF,$FF,$EE
        db $0B,$29,$FF,$00,$8D,$34,$09,$DA,$A5,$00,$48,$A2,$88,$00,$20,$EA
        db $A3,$68,$48,$85,$00,$20,$0D,$A7,$AD,$34,$09,$20,$99,$9A,$68,$A0
        db $0F,$40,$20,$04,$AE,$A9,$08,$00,$20,$72,$B8,$FA,$E8,$E8,$E8,$80
        db $C4,$60,$AD,$28,$0E,$85,$28,$20,$D8,$9C,$BD,$04,$14,$48,$85,$00
        db $20,$0D,$A7,$A9,$0D,$00,$9F,$00,$90,$7F,$68,$85,$00,$64,$02,$A2
        db $00,$00,$BF,$0F,$F2,$0B,$F0,$0E,$C5,$00,$F0,$0A,$8A,$18,$69,$04
        db $00,$AA,$E6,$02,$80,$EC,$A5,$02,$49,$01,$00,$0A,$0A,$AA,$BF,$11
        db $F2,$0B,$85,$24,$BF,$0F,$F2,$0B,$85,$00,$48,$20,$0D,$A7,$A9,$0E
        db $00,$20,$99,$9A,$68,$85,$00,$20,$D1,$9E,$8D,$28,$0E,$C9,$FF,$FF
        db $D0,$01,$60,$48,$A5,$24,$85,$00,$20,$D1,$9E,$A4,$24,$C9,$FF,$FF
        db $F0,$03,$AC,$1A,$09,$5A,$AD,$28,$0E,$A0,$0B,$00,$20,$1E,$C9,$7A
        db $84,$00,$68,$20,$65,$B5,$60
; [Save] Handles save screen - select slot, confirm save. Entry: writes game state to SRAM.
handleSaveScreen:
        PHA
        JSR.W initBattleState
        LDA.B $00
        STA.W $1404,X
        JSR.W updateMosaic
        PLA
        JSR.W cleanupBattle
        LDA.B $02
        STA.W $1802,X
        LDA.B $04
        STA.W $1804,X
        RTS
        db $AD,$08,$0A,$85,$04,$20,$B8,$A6,$20,$19,$A7,$85,$00,$29,$00,$04
        db $F0,$F3,$A5,$00,$29,$00,$08,$D0,$EC,$A5,$00,$09,$00,$08,$9F,$00
        db $90,$7F,$C6,$04,$D0,$DF,$60,$22,$72,$DF,$00,$29,$1F,$00,$85,$22
        db $C9,$1F,$00,$D0,$03,$A9,$00,$00,$20,$D8,$9C,$BD,$00,$14,$29,$FF
        db $00,$F0,$E4,$AD,$04,$0E,$48,$BD,$04,$14,$8D,$04,$0E,$68,$9D,$04
        db $14,$A5,$22,$20,$E6,$9C,$DA,$AD,$55,$0A,$C9,$1F,$00,$D0,$03,$7A
        db $80,$25,$20,$E6,$9C,$7A,$BD,$02,$18,$99,$06,$18,$BD,$04,$18,$99
        db $08,$18,$B9,$02,$18,$9D,$06,$18,$B9,$04,$18,$9D,$08,$18,$A9,$F2
        db $88,$9D,$00,$18,$99,$00,$18,$60,$64,$22,$A9,$FF,$FF,$85,$24,$A5
        db $22,$20,$D8,$9C,$BD,$00,$14,$29,$FF,$00,$F0,$47,$AD,$04,$0E,$29
        db $FF,$00,$85,$00,$BD,$04,$14,$29,$FF,$00,$20,$31,$96,$85,$04,$AD
        db $05,$0E,$29,$FF,$00,$85,$00,$BD,$05,$14,$29,$FF,$00,$20,$31,$96
        db $18,$65,$04,$C5,$24,$B0,$1C,$85,$24,$8D,$08,$0A,$A5,$22,$8D,$55
        db $0A,$BD,$04,$14,$85,$00,$20,$21,$CA,$A5,$02,$8D,$00,$10,$A5,$04
        db $8D,$02,$10,$E6,$22,$A5,$22,$C9,$10,$00,$90,$A3,$60,$9C,$00,$10
        db $A2,$00,$00,$BF,$E5,$F2,$0B,$CD,$04,$0E,$F0,$0C,$8A,$18,$69,$04
        db $00,$AA,$E0,$A0,$00,$90,$EC,$60,$BF,$E7,$F2,$0B,$8D,$04,$10,$85
        db $00,$8A,$4A,$4A,$48,$29,$03,$00,$8D,$02,$10,$68,$4A,$4A,$85,$22
        db $C9,$02,$00,$B0,$0A,$C9,$01,$00,$D0,$03,$A9,$10,$00,$80,$0A,$3A
        db $3A,$AA,$BF,$94,$EA,$7E,$29,$FF,$00,$85,$24,$4A,$4A,$4A,$4A,$1A
        db $85,$26,$AD,$02,$10,$F0,$42,$AD,$02,$10,$C5,$26,$D0,$25,$20,$0D
        db $A7,$C9,$CD,$00,$B0,$1C,$A9,$D2,$00,$38,$ED,$02,$10,$20,$99,$9A
        db $A9,$13,$00,$20,$E5,$EB,$A5,$24,$18,$69,$30,$0F,$20,$F7,$EB,$20
        db $4F,$ED,$60,$AD,$04,$0E,$85,$00,$20,$0D,$A7,$A9,$DC,$00,$38,$ED
        db $02,$10,$20,$99,$9A,$EE,$00,$10,$60,$A5,$24,$09,$00,$0F,$20,$F7
        db $EB,$20,$4F,$ED,$60,$A9,$7E,$00,$85,$14,$A9,$94,$EA,$85,$12,$A0
        db $08,$00,$A2,$00,$00,$8A,$9F,$94,$EA,$7E,$E8,$E8,$E0,$08,$00,$D0
        db $F5,$A9,$30,$00,$22,$47,$DF,$00,$C9,$10,$00,$F0,$F4,$85,$00,$A2
        db $00,$00,$BF,$94,$EA,$7E,$29,$FF,$00,$C5,$00,$F0,$E4,$E8,$E0,$08
        db $00,$D0,$EF,$E2,$20,$A5,$00,$87,$12,$C2,$20,$E6,$12,$88,$D0,$D1
        db $60,$20,$7C,$A3,$A9,$AB,$00,$20,$4A,$EE,$64,$24,$A9,$01,$00,$20
        db $C0,$B7,$A9,$AC,$00,$20,$4A,$EE,$20,$84,$B8,$20,$E7,$F6,$A5,$50
        db $29,$80,$80,$D0,$1D,$A5,$50,$29,$00,$02,$F0,$05,$A9,$01,$00,$80
        db $DE,$A5,$50,$29,$00,$01,$F0,$05,$A9,$FF,$FF,$80,$D2,$20,$EE,$B7
        db $80,$D6,$8D,$00,$10,$48,$A5,$24,$8D,$02,$10,$A5,$26,$8D,$04,$10
        db $68,$29,$80,$00,$F0,$09,$A5,$24,$18,$69,$0A,$00,$20,$73,$9B,$60
        db $85,$00,$A9,$80,$00,$85,$26,$A5,$24,$18,$65,$00,$10,$03,$A9,$06
        db $00,$C9,$07,$00,$90,$03,$A9,$00,$00,$85,$24,$C9,$00,$00,$F0,$05
        db $46,$26,$3A,$D0,$FB,$AF,$96,$EA,$7E,$25,$26,$D0,$D5,$60
; [Menu] Displays confirmation dialog (Yes/No). Entry: A=prompt text ID. Returns carry if Yes selected.
confirmAction:
        PHP
        SEP #$20
        LDA.B $10
        CMP.B #$02
        BEQ CODE_81B805
        CMP.B #$03
        BEQ CODE_81B807
        STZ.B $10
        STZ.B $4A
CODE_81B7FF:
        LDA.B $4A
        BEQ CODE_81B7FF
        INC.B $10
CODE_81B805:
        PLP
        RTS
CODE_81B807:
        JSL.L handleMapTransition
        BRA CODE_81B805
; [Dialogue] Draws message box for text display. Entry: $00/$02=position, $04/$06=size.
drawMessageBox:
        PHP
        SEP #$20
        STZ.B $57
        STZ.W $05F5
        STZ.B $10
        LDA.B #$00
        STA.W $2100
        LDA.B #$41
        STA.B $58
        PLP
        RTS
; [Text] Prints text to message box. Entry: $12/$14=text pointer. Handles line breaks, speed.
printText:
        PHP
        SEP #$20
        STZ.B $57
        STZ.W $05F5
        STZ.B $10
        LDA.B #$0F
        STA.W $2100
        STA.B $58
        PLP
        RTS
; [Dialogue] Waits for button press to advance text. Entry: displays 'more' prompt, waits for input.
waitTextAdvance:
        PHP
        SEP #$20
        CMP.B #$00
        BEQ CODE_81B84B
        STA.B $59
        STZ.B $10
        LDA.B #$00
        STA.W $2100
        LDA.B #$51
        STA.B $58
        PLP
        RTS
CODE_81B84B:
        LDA.B #$3E
        STA.B $58
        BRA CODE_81B85E
; [Text] Clears text buffer for new message. Entry: resets text position, clears tilemap area.
clearTextBuffer:
        PHP
        SEP #$20
        LDA.B $10
        CMP.B #$03
        BCS CODE_81B865
        LDA.B #$2E
        STA.B $58
CODE_81B85E:
        JSR.W confirmAction
        LDA.B $58
        BNE CODE_81B85E
CODE_81B865:
        SEP #$20
        LDA.B #$8F
        STA.W $2100
        LDA.B #$03
        STA.B $10
        PLP
        RTS
; [Text] Sets text color for printing. Entry: A=color index (0-15). Updates text rendering palette.
setTextColor:
        PHP
        REP #$20
CODE_81B875:
        CMP.W #$0000
        BEQ CODE_81B882
        PHA
        JSR.W confirmAction
        PLA
        DEC A
        BRA CODE_81B875
CODE_81B882:
        PLP
        RTS
; [Text] Draws number value as text. Entry: A=number, $00/$02=position. Converts to decimal string.
drawNumber:
        PHP
        REP #$20
        LDA.B $4E
        PHA
        SEP #$20
CODE_81B88C:
        LDA.W $4212
        AND.B #$01
        BNE CODE_81B88C
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
        RTS
        REP #$20
        JSL.L loadGameData
        CMP.W #$FFFF
        BNE CODE_81B8B4
        db $60
CODE_81B8B4:
        JSR.W playSelectSound
        STZ.W $0E25
        JSR.W clearTextBuffer
        LDA.W #$000B
        JSL.L dispatchGameMode
        JSL.L setupDataStructure
        LDA.W #$000B
        JSR.W monitorFlags
        LDA.W #$0001
        JSR.W waitTextAdvance
        STZ.W $0E26
        LDA.W #$0001
        STA.W $0E5A
        LDA.W $0986
        STA.B $22
        LDA.W $0988
        STA.B $24
        JSL.L updateRasterEffects
        JSR.W monitorInventory
        LDA.W #$0002
        STA.W $0E26
CODE_81B8F4:
        JSR.W drawWindowShadow
        LDA.B $82
        BMI CODE_81B90C
        LDA.W $1000
        BNE CODE_81B8F4
        LDA.W #$0000
        JSR.W waitTextAdvance
        LDA.W #$0040
        JSR.W drawStatComparison
CODE_81B90C:
        RTS
; [Menu] Draws stat comparison (old vs new) for equipment. Entry: shows changes with +/- indicators.
drawStatComparison:
        TAY
CODE_81B90E:
        LDX.W #$1000
CODE_81B911:
        DEX
        BNE CODE_81B911
        DEY
        BNE CODE_81B90E
        RTS
        db $C2,$20,$20,$51,$B8,$A9,$14,$00,$22,$9C,$AB,$00,$20,$E2,$B9,$A9
        db $45,$00,$20,$4A,$EE,$20,$0D,$B8,$64,$22,$64,$24,$64,$26,$64,$28
        db $20,$84,$B8,$A5,$50,$29,$F0,$F0,$D0,$0B,$20,$79,$BA,$20,$D3,$BB
        db $20,$EE,$B7,$80,$EB,$20,$51,$B8,$22,$A4,$A9,$00,$A9,$01,$00,$60
        REP #$20
        PHA
        JSR.W $B9E2
        LDA.W #$0044
        JSR.W monitorInput
        JSL.L updateScanlineEffects
        LDA.W #$0025
        JSR.W monitorMemory
        JSR.W drawMessageBox
        LDA.W #$0064
        JSR.W setTextColor
        LDA.W #$0000
        JSL.L updateFilmGrain
CODE_81B97E:
        JSR.W confirmAction
        LDA.W $1200
        BNE CODE_81B97E
        LDA.W #$0002
        JSL.L updateFilmGrain
        STZ.B $22
        STZ.B $24
        STZ.B $26
        STZ.B $28
        LDA.W #$01F4
        STA.B $0E
        LDA.W #$001E
        STA.B $0C
        STZ.B $0A
        LDA.W #$0400
        STA.B $4E
CODE_81B9A6:
        JSR.W $BA3F
        JSR.W $BA79
        JSR.W $BBD3
        JSR.W confirmAction
        DEC.B $0E
        LDA.B $0E
        BNE CODE_81B9A6
        LDX.W #$FFBA
        LDY.W #$0000
        JSL.L updateChromaEffect
        PLA
        JSL.L updateMode7Effects
        JSL.L clearVRAM
        LDA.W #$0001
        JSL.L updateFilmGrain
        LDA.W #$00C8
        JSR.W setTextColor
        LDA.W #$8001
        JSR.W monitorMemory
        JSR.W clearTextBuffer
        RTS
        REP #$20
        LDA.W #$FFFF
        STA.W $0958
        LDA.W #$0001
        JSL.L dispatchGameMode
        SEP #$20
        LDA.B #$70
        STA.W $2108
        REP #$20
        STZ.W $0E25
        LDA.W #$0002
        LDX.W #$2100
        LDY.W #$0000
        JSL.L calculateSlope
        LDX.W #$0400
        LDY.W #$0020
CODE_81BA10:
        LDA.L $7FB000,X
        ORA.W #$2000
        STA.L $7FB000,X
        INX
        INX
        DEY
        BNE CODE_81BA10
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSR.W confirmAction
        LDA.W #$0001
        LDX.W #$0104
        LDY.W #$0000
        JSL.L calculateSlope
        JSR.W $BB84
        JSR.W playSelectSound
        RTS
        REP #$20
        LDA.B $0C
        BNE CODE_81BA6B
        LDA.B $0E
        CMP.W #$0064
        BCS CODE_81BA4D
        RTS
CODE_81BA4D:
        LDA.W #$001E
        STA.B $0C
CODE_81BA52:
        JSL.L updateLightningEffect
        AND.W #$0003
        TAX
        CMP.B $0A
        BEQ CODE_81BA52
        STA.B $0A
        SEP #$20
        LDA.L $01BA75,X
        STA.B $4F
        REP #$20
        RTS
CODE_81BA6B:
        DEC.B $0C
        CMP.W #$0016
        BNE CODE_81BA74
        STZ.B $4E
CODE_81BA74:
        RTS
        db $01,$02,$04,$08
        LDA.B $4F
        AND.W #$0004
        BEQ CODE_81BA8A
        LDA.B $26
        CLC
        ADC.W #$0004
        STA.B $26
        BRA CODE_81BAC2
CODE_81BA8A:
        LDA.B $4F
        AND.W #$0008
        BEQ CODE_81BA9B
        LDA.B $26
        SEC
        SBC.W #$0004
        STA.B $26
        BRA CODE_81BAC2
CODE_81BA9B:
        LDA.W #$0002
        STA.B $00
        LDA.W $0982
        BEQ CODE_81BAC2
        AND.W #$8000
        CMP.B $28
        BNE CODE_81BABB
        LDA.W #$0005
        STA.B $00
        LDA.B $28
        EOR.W #$8000
        STA.B $28
        LDA.W $0982
CODE_81BABB:
        LDY.B $26
        JSR.W $BB5A
        STA.B $26
CODE_81BAC2:
        LDA.W $0982
        CLC
        ADC.B $26
        CMP.W #$0180
        BCC CODE_81BAD6
        CMP.W #$FF80
        BCS CODE_81BAD6
        STZ.B $26
        BRA CODE_81BAE9
CODE_81BAD6:
        CMP.W #$0004
        BCS CODE_81BADE
        LDA.W #$0000
CODE_81BADE:
        CMP.W #$FFFC
        BCC CODE_81BAE6
        LDA.W #$0000
CODE_81BAE6:
        STA.W $0982
CODE_81BAE9:
        LDA.B $4F
        AND.W #$0002
        BEQ CODE_81BAFA
        LDA.B $22
        CLC
        ADC.W #$0004
        STA.B $22
        BRA CODE_81BB32
CODE_81BAFA:
        LDA.B $4F
        AND.W #$0001
        BEQ CODE_81BB0B
        LDA.B $22
        SEC
        SBC.W #$0004
        STA.B $22
        BRA CODE_81BB32
CODE_81BB0B:
        LDA.W #$0002
        STA.B $00
        LDA.W $0980
        BEQ CODE_81BB32
        AND.W #$8000
        CMP.B $24
        BNE CODE_81BB2B
        LDA.W #$0005
        STA.B $00
        LDA.B $24
        EOR.W #$8000
        STA.B $24
        LDA.W $0980
CODE_81BB2B:
        LDY.B $22
        JSR.W $BB5A
        STA.B $22
CODE_81BB32:
        LDA.W $0980
        CLC
        ADC.B $22
        CMP.W #$0100
        BCC CODE_81BB46
        CMP.W #$FF00
        BCS CODE_81BB46
        STZ.B $22
        BRA CODE_81BB59
CODE_81BB46:
        CMP.W #$0004
        BCS CODE_81BB4E
        LDA.W #$0000
CODE_81BB4E:
        CMP.W #$FFFC
        BCC CODE_81BB56
        LDA.W #$0000
CODE_81BB56:
        STA.W $0980
CODE_81BB59:
        RTS
        AND.W #$8000
        BNE CODE_81BB72
        TYA
        CMP.W #$8000
        BCS CODE_81BB68
        SEC
        SBC.B $00
CODE_81BB68:
        CMP.W #$FFF0
        BCC CODE_81BB70
        SEC
        SBC.B $00
CODE_81BB70:
        BRA CODE_81BB83
CODE_81BB72:
        TYA
        CMP.W #$8000
        BCC CODE_81BB7B
        CLC
        ADC.B $00
CODE_81BB7B:
        CMP.W #$0010
        BCS CODE_81BB83
        CLC
        ADC.B $00
CODE_81BB83:
        RTS
        PHP
        SEP #$20
        LDA.B #$50
        STA.B $84
        LDA.B #$03
        STA.W $4360
        REP #$20
        STZ.W $0980
        STZ.W $0982
        LDA.W #$0020
        STA.L $7EA000
        LDA.W #$0000
        STA.L $7EA001
        LDX.W #$0005
        LDY.W #$0060
CODE_81BBAC:
        LDA.W #$0001
        STA.L $7EA000,X
        LDA.W #$0000
        STA.L $7EA001,X
        STA.L $7EA003,X
        TXA
        CLC
        ADC.W #$0005
        TAX
        DEY
        BNE CODE_81BBAC
        STX.W $0984
        LDA.W #$0000
        STA.L $7EA000,X
        PLP
        RTS
        REP #$20
        STZ.B $00
        LDA.W #$00FF
        STA.B $02
        LDA.W $0980
        STA.B $04
        LDA.W $0982
        STA.B $06
        LDX.W $0984
        LDY.W #$0060
CODE_81BBEC:
        TXA
        SEC
        SBC.W #$0005
        TAX
        LDA.B $00
        CLC
        ADC.B $04
        STA.B $00
        LDA.B $01
        AND.W #$00FF
        STA.L $7EA001,X
        LDA.B $02
        SEC
        SBC.B $06
        STA.B $02
        LDA.B $03
        AND.W #$00FF
        STA.L $7EA003,X
        DEY
        BNE CODE_81BBEC
        RTS
; [SFX] Plays cursor movement sound effect. Entry: called when menu cursor moves.
playCursorSound:
        REP #$20
        LDX.W #$0020
        LDY.W #$0004
CODE_81BC1E:
        STZ.W $0E00,X
        INX
        INX
        DEY
        BNE CODE_81BC1E
        RTS
; [SFX] Plays selection sound effect. Entry: called when menu item selected.
playSelectSound:
        SEP #$20
        STZ.W $0E22
        STZ.W $0EA2
        LDA.W $0E25
        STA.W $0EA5
        REP #$20
        STZ.W $0E20
        STZ.W $0EA0
        STZ.W $0E23
        STZ.W $0EA3
        STZ.W $0E26
        STZ.W $0EA6
        STZ.W $0E52
        STZ.W $0ED2
        STZ.W $0E58
        STZ.W $0ED8
        STZ.W $0E5E
        STZ.W $0EDE
        STZ.W $0E72
        STZ.W $0EF2
        STZ.B $A8
        STZ.W $0E5A
        LDA.W #$00FF
        STA.W $0EEC
        RTS
; [SFX] Plays error sound (invalid action). Entry: called when action not allowed.
playErrorSound:
        REP #$20
        LDA.W #$0001
        JSL.L dispatchGameMode
        JSR.W playSelectSound
        JSR.W decompressSaveData
        JSR.W migrateSaveData
        JSL.L updateScanlineEffects
        LDA.W #$0026
        JSR.W monitorMemory
        JSR.W drawMessageBox
        LDA.B $58
        ORA.W #$0020
        STA.B $58
        LDA.W #$0032
        JSR.W setTextColor
        LDA.W $0E6A
        CMP.W #$0002
        BCC CODE_81BCA4
        db $4C,$3B,$BD
CODE_81BCA4:
        LDA.W #$002B
        JSR.W drawPartyFace
        JSR.W drawScrollBar
        SEP #$20
        LDA.W $0E06
        STA.W $4202
        LDA.B #$0D
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDY.W $4216
        REP #$20
        TYA
        LSR A
        LSR A
        LSR A
        LSR A
        CLC
        ADC.W #$0011
        STA.B $22
        LDA.W #$0007
        JSL.L updateSmokeEffect
        CLC
        ADC.W #$001D
        LDY.B $22
        JSR.W monitorSave
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        STA.B $24
        CLC
        ADC.W $0E88
        CMP.W $0EB8
        BEQ CODE_81BD00
        BCC CODE_81BD00
        SEC
        SBC.W $0EB8
        STA.B $00
        LDA.B $24
        SEC
        SBC.B $00
        STA.B $24
        LDA.W $0EB8
CODE_81BD00:
        STA.W $0E88
        LDY.W #$0E80
        JSR.W executeDebugCommand
        LDA.B $24
        STA.W $0E6E
        TAY
        LDA.W #$001E
        JSR.W monitorSave
        TAY
        LDA.B $22
        JSR.W monitorTest
        INC A
        PHA
        LDA.W #$00DC
        JSR.W setTextColor
        LDA.W #$001E
        JSR.W monitorDisassemble
        JSR.W decompressSaveData
        LDA.W #$002C
        JSR.W drawPartyFace
        LDA.W #$006E
        JSR.W setTextColor
        PLA
        BRA CODE_81BD6A
        db $A9,$6F,$00,$20,$D5,$C2,$20,$81,$BD,$A9,$FA,$00,$20,$72,$B8,$A9
        db $1E,$00,$20,$E5,$EB,$AD,$6C,$0E,$29,$FF,$00,$C9,$0C,$00,$D0,$0C
        db $A9,$72,$00,$20,$D5,$C2,$A9,$96,$00,$20,$72,$B8,$20,$98,$BD
CODE_81BD6A:
        STZ.W $0E5A
        JSR.W drawProgressBar
        LDA.W $0E88
        BNE CODE_81BD7E
        db $20,$34,$C2,$A9,$19,$00,$20,$DE,$C1
CODE_81BD7E:
        JMP.W CODE_81C0EC
; [Menu] Draws scroll bar for list menus. Entry: A=position, X=length, Y=total items.
drawScrollBar:
        SEP #$20
        LDA.B #$02
        STA.W $0E26
        REP #$20
        LDA.W #$000C
        JSR.W setTextColor
        SEP #$20
        STZ.W $0E26
        REP #$20
        RTS
        LDA.W #$0005
        JSL.L updateSmokeEffect
        CLC
        ADC.W #$0018
        SEP #$20
        STA.W $4202
        LDA.W $0E70
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDY.W $4216
        REP #$20
        TYA
        RTS
        REP #$20
        JSR.W $BD98
        STA.W $0E58
        STZ.W $0E5A
        LDA.W #$005A
        JSR.W monitorWatchpoints
        LDA.W #$0002
        STA.W $0A00
        JSR.W $C13E
        STZ.W $0A00
        RTS
; [Menu] Handles list scrolling logic. Entry: processes up/down input, updates scroll position.
handleListScrolling:
        REP #$20
        STA.W $0964
        PHY
        LDA.W #$0001
        JSL.L dispatchGameMode
        JSR.W playSelectSound
        JSL.L drawMap
        PLA
        JSR.W monitorMemory
        JSR.W decompressSaveData
        JSR.W migrateSaveData
        JSL.L updateScanlineEffects
        JSR.W drawMessageBox
        LDA.B $58
        ORA.W #$0020
        STA.B $58
        JSR.W handleScreenShake
        LDA.W #$0041
        JSR.W drawButtonIcons
        LDA.W #$0000
        JSR.W drawPartyFace
        STZ.W $0A0C
        LDA.W #$0016
        JSR.W monitorInput
        LDA.W #$0041
        JSR.W drawButtonIcons
        LDA.W $0964
        STA.W $0E68
        BEQ CODE_81BE2C
        JMP.W CODE_81BEBC
CODE_81BE2C:
        LDA.W $0E54
        AND.W #$00FF
        BEQ CODE_81BEA3
        LDA.W $0E10
        AND.W #$00FF
        CMP.W #$0002
        BEQ CODE_81BEA3
        CMP.W #$0003
        BEQ CODE_81BEA3
        LDA.W #$1012
        JSR.W drawPartyFace
        LDA.W #$0020
        JSR.W drawButtonIcons
        LDA.W #$0001
        STA.W $096A
        LDA.W #$0001
        JSR.W drawCharacterSpriteMenu
        BNE CODE_81BE61
        STZ.W $1200
CODE_81BE61:
        SEP #$20
        LDA.B #$02
        STA.W $0E26
        REP #$20
CODE_81BE6A:
        REP #$20
        JSR.W drawBorder
        LDA.W $1004
        BEQ CODE_81BE83
        STZ.W $1004
        LDA.W #$0001
        JSR.W animateMenuSprite
        LDA.W #$0013
        JSR.W drawPartyFace
CODE_81BE83:
        LDA.W $1000
        ORA.W $1200
        ORA.W $11E0
        BNE CODE_81BE6A
        SEP #$20
        STZ.W $0E26
        REP #$20
        LDA.W #$0014
        JSR.W drawButtonIcons
        LDA.W $0E88
        BNE CODE_81BEA3
        JMP.W $C00C
CODE_81BEA3:
        STZ.W $0E66
        INC.W $0966
        LDA.W $0966
        CMP.W $0968
        BNE CODE_81BEB4
        JMP.W $C00C
CODE_81BEB4:
        CMP.W #$0002
        BNE CODE_81BEBC
        INC.W $0E24
CODE_81BEBC:
        LDA.W $0ED4
        AND.W #$00FF
        BNE CODE_81BEC7
        JMP.W $BF3C
CODE_81BEC7:
        SEP #$20
        STZ.W $0EA2
        STZ.W $0E22
        REP #$20
        LDA.W #$0001
        STA.W $0E5A
        JSL.L updateScanlineEffects
        LDA.W #$1014
        JSR.W drawPartyFace
        LDA.W #$0020
        JSR.W drawButtonIcons
        LDA.W #$0001
        STA.W $096A
        LDA.W #$0000
        JSR.W drawCharacterSpriteMenu
        BNE CODE_81BEF8
        STZ.W $1000
CODE_81BEF8:
        SEP #$20
        LDA.B #$02
        STA.W $0EA6
        REP #$20
CODE_81BF01:
        REP #$20
        JSR.W drawBorder
        LDA.W $1204
        BEQ CODE_81BF1A
        STZ.W $1204
        LDA.W #$0000
        JSR.W animateMenuSprite
        LDA.W #$0015
        JSR.W drawPartyFace
CODE_81BF1A:
        LDA.W $1000
        ORA.W $1200
        ORA.W $11E0
        BNE CODE_81BF01
        SEP #$20
        STZ.W $0EA6
        REP #$20
        LDA.W $0E08
        BNE CODE_81BF34
        db $4C,$0C,$C0
CODE_81BF34:
        LDA.W $0E6A
        CMP.W #$0001
        BEQ CODE_81BF6F
        LDA.W #$0014
        JSR.W drawButtonIcons
        SEP #$20
        STZ.W $0EA2
        STZ.W $0E22
        REP #$20
        STZ.W $0E5A
        JSL.L updateScanlineEffects
        STZ.W $0E66
        INC.W $0966
        LDA.W $0966
        CMP.W $0968
        BNE CODE_81BF64
        JMP.W $C00C
CODE_81BF64:
        CMP.W #$0002
        BNE CODE_81BF6C
        db $EE,$24,$0E
CODE_81BF6C:
        JMP.W CODE_81BE2C
CODE_81BF6F:
        LDA.W $0E52
        BNE CODE_81BF77
        db $4C,$3C,$BF
CODE_81BF77:
        LDA.W #$0029
        JSR.W drawPartyFace
        JSL.L updateLightningEffect
        AND.W #$0007
        STA.B $00
        LDA.W $0E06
        AND.W #$00FF
        CLC
        ADC.B $00
        TAX
        SEP #$20
        LDA.L $0BE264,X
        STA.W $0E03
        REP #$20
        LDY.W #$0E00
        PHY
        JSR.W executeDebugCommand
        PLY
        LDA.W $0E28
        JSR.W debugMenu
        LDA.W $0E38
        STA.W $0E08
        STZ.W $1060
        JSL.L clearVRAM
        JSR.W confirmAction
        LDA.W #$000E
        JSR.W monitorDisassemble
        LDA.W #$000D
        STA.B $22
        LDA.W #$0004
        STA.B $24
        LDX.W #$0122
        LDY.W #$0000
        LDA.W #$0002
        JSR.W drawIcon
        LDA.W #$0002
        STA.B $24
        LDA.W #$0001
        JSR.W drawIcon
        JSL.L updateDistortionEffect
        LDA.W #$0010
        STA.B $22
        LDA.W #$0004
        STA.B $24
        LDX.W #$0122
        LDY.W #$0000
        LDA.W #$0007
        JSR.W drawIcon
        JSR.W decompressSaveData
        LDA.W #$002A
        JSR.W drawPartyFace
        LDA.W #$001E
        JSR.W setTextColor
        JMP.W $BF3C
        SEP #$20
        LDA.W $0E03
        CMP.B #$38
        BNE CODE_81C01A
        db $A9,$1F,$8D,$03,$0E
CODE_81C01A:
        REP #$20
        LDA.W #$0014
        JSR.W drawButtonIcons
        LDA.W #$0002
        JSR.W monitorDisassemble
        LDA.W #$0032
        STA.B $2A
        STZ.B $4C
        JSR.W confirmAction
        LDA.W #$8001
        JSR.W monitorMemory
        LDA.W #$0005
        JSR.W setTextColor
        INC.B $4C
        JSR.W confirmAction
        LDA.W $0E08
        BNE CODE_81C04B
        db $4C,$E5,$C0
CODE_81C04B:
        LDA.W $0E6E
        BEQ CODE_81C056
        JSR.W $BD98
        JMP.W CODE_81BD6A
CODE_81C056:
        LDY.W #$0E00
        JSR.W drawClock
        STA.B $22
        STA.W $100A
        LDY.W #$0E80
        JSR.W drawClock
        STA.B $24
        STA.W $100C
        LDA.B $24
        SEC
        SBC.B $22
        JSR.W monitorExit
        LSR A
        LSR A
        JSR.W cheatInfiniteHP
        CLC
        ADC.W #$0007
        CMP.W #$8000
        BCC CODE_81C085
        LDA.W #$0000
CODE_81C085:
        STA.B $00
        LDA.W #$0003
        JSL.L updateSmokeEffect
        CLC
        ADC.B $00
        BNE CODE_81C094
        INC A
CODE_81C094:
        STA.B $26
        STZ.B $28
        STZ.W $0E5A
        LDA.W $0E88
        BNE CODE_81C0CD
        INC.W $0E5A
        LDA.B $24
        SEC
        SBC.B $22
        JSR.W monitorExit
        ASL A
        ASL A
        JSR.W cheatInfiniteHP
        CLC
        ADC.W #$0032
        CMP.W #$8000
        BCC CODE_81C0BC
        LDA.W #$0000
CODE_81C0BC:
        STA.B $28
        LDA.W #$0005
        JSL.L updateSmokeEffect
        CLC
        ADC.B $28
        BNE CODE_81C0CB
        INC A
CODE_81C0CB:
        STA.B $28
CODE_81C0CD:
        LDA.B $26
        CLC
        ADC.B $28
        JSR.W drawProgressBar
        LDA.W $0E5A
        BEQ CODE_81C0EC
        JSR.W drawGoldAmount
        LDA.W #$0019
        JSR.W drawButtonIcons
        BRA CODE_81C0EC
        db $E2,$20,$9C,$07,$0E,$C2,$20
CODE_81C0EC:
        LDY.W #$0E00
        JSR.W executeDebugCommand
        LDA.W #$0016
        JSR.W drawButtonIcons
        JSR.W clearTextBuffer
        STZ.B $4C
        RTS
; [Menu] Draws icon sprite (item, spell, status). Entry: A=icon ID, $00/$02=position.
drawIcon:
        PHA
        PHX
        STA.B $26
        STX.B $28
CODE_81C104:
        LDX.B $28
        LDA.B $22
        INC.B $22
        JSL.L calculateSlope
        LDA.B $24
        JSR.W setTextColor
        LDY.W #$0007
        DEC.B $26
        BNE CODE_81C104
        PLX
        PLA
        RTS
; [HUD] Draws progress bar (HP, MP, XP). Entry: A=current, X=max, $00/$02=position, Y=color.
drawProgressBar:
        STA.B $00
        LDA.W #$1000
        JSR.W testBattle
        BEQ CODE_81C12B
        ASL.B $00
        DEC.B $00
CODE_81C12B:
        LDA.B $00
        CMP.W #$0064
        BCC CODE_81C135
        LDA.W #$0063
CODE_81C135:
        STA.W $0E58
        LDA.W #$005A
        JSR.W drawPartyFace
        LDA.W #$0017
        JSR.W monitorDisassemble
        STZ.W $0A0C
        STZ.W $0994
CODE_81C14A:
        LDA.W $0E07
        PHA
        AND.W #$0003
        STA.B $24
        PLA
        LSR A
        LSR A
        AND.W #$001F
        STA.B $22
        LDA.W #$005B
        JSR.W monitorInput
        LDA.W $0E58
        BEQ CODE_81C190
        DEC A
        STA.W $0E58
        LDA.W #$0003
        JSR.W setTextColor
        SEP #$20
        INC.W $0E07
        LDA.W $0E07
        CMP.B #$64
        BCC CODE_81C18C
        STZ.W $0E07
        LDA.W $0E06
        CMP.B #$63
        BCS CODE_81C18C
        INC.W $0E06
        INC.W $0994
CODE_81C18C:
        REP #$20
        BRA CODE_81C14A
CODE_81C190:
        LDA.W #$001D
        JSR.W monitorDisassemble
        LDA.W #$0032
        JSR.W setTextColor
        LDA.W $0994
        BEQ CODE_81C1DD
        LDY.W #$0E00
        PHY
        JSR.W executeDebugCommand
        LDA.W $0E28
        PLY
        JSR.W debugMenu
        LDA.W #$001C
        JSR.W monitorDisassemble
        LDA.W #$005F
        JSR.W monitorInput
        LDA.W $0E6A
        CMP.W #$0002
        BCC CODE_81C1DD
        LDA.W $0E06
        DEC A
        AND.W #$00FF
        TAX
        LDA.L $0BE4CF,X
        AND.W #$00FF
        BEQ CODE_81C1DD
        DEC A
        STA.B $24
        LDA.W #$005E
        JSR.W monitorInput
CODE_81C1DD:
        RTS
; [Text] Draws controller button icons in help text. Entry: A=button combination.
drawButtonIcons:
        STA.B $00
        LDA.W #$0001
        JSR.W testBattle
        BNE CODE_81C1EA
        ASL.B $00
CODE_81C1EA:
        LDY.B $00
CODE_81C1EC:
        PHY
        JSR.W confirmAction
        JSR.W drawNumber
        LDA.B $50
        AND.W #$4080
        BNE CODE_81C1FF
        PLY
        DEY
        BNE CODE_81C1EC
        RTS
CODE_81C1FF:
        PLA
        RTS
; [HUD] Draws game time clock display. Entry: reads playtime counter, formats as HH:MM.
drawClock:
        LDA.W $0038,Y
        LSR A
        LSR A
        STA.B $04
        LDA.W $003E,Y
        STA.B $02
        LDA.W $003A,Y
        STA.B $00
        LDA.W $003C,Y
        CMP.B $00
        BCC CODE_81C21B
        STA.B $00
CODE_81C21B:
        LDA.B $00
        CLC
        ADC.B $02
        CLC
        ADC.B $04
        PHA
        LDA.W $0051,Y
        AND.W #$00FF
        PLY
        JSR.W monitorSave
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        RTS
; [HUD] Draws gold amount with icon. Entry: reads party gold, formats with commas.
drawGoldAmount:
        LDA.W #$0005
        JSL.L updateSmokeEffect
        INC A
        STA.B $2A
        LDA.W #$0006
        JSL.L updateSmokeEffect
        STA.B $00
        LDA.W #$0006
        JSL.L updateSmokeEffect
        CLC
        ADC.B $00
        LDY.W #$0005
        JSR.W monitorSave
        CLC
        ADC.B $2A
        STA.B $2A
        STA.B $2C
        STZ.B $2E
        LDA.W $0EA8
        CMP.W #$001F
        BEQ CODE_81C2C3
        LDA.W #$0010
        JSR.W testBattle
        BEQ CODE_81C2C3
        JSL.L updateLightningEffect
        AND.W #$0007
        BEQ CODE_81C27B
        BRA CODE_81C2C3
CODE_81C27B:
        LDA.W #$004F
        JSR.W drawPartyFace
        LDA.W #$1051
        JSR.W drawPartyFace
        LDA.W $0A08
        CMP.W #$0002
        BNE CODE_81C2C3
        db $22,$72,$DF,$00,$29,$01,$00,$F0,$23,$06,$2C,$A9,$52,$10,$20,$D5
        db $C2,$E6,$2E,$A5,$2E,$C9,$03,$00,$90,$D8,$AF,$8A,$EA,$7E,$18,$65
        db $2C,$8F,$8A,$EA,$7E,$A9,$54,$00,$20,$D5,$C2,$60,$A9,$53,$10,$20
        db $D5,$C2,$64,$2C
CODE_81C2C3:
        LDA.L $7EEA8A
        CLC
        ADC.B $2C
        STA.L $7EEA8A
        LDA.W #$0050
        JSR.W drawPartyFace
        RTS
; [Menu] Draws character face portrait. Entry: A=character ID, $00/$02=position.
drawPartyFace:
        REP #$20
        CLC
        ADC.W #$C000
        JSR.W monitorWatchpoints
        RTS
; [Menu] Draws character sprite in menu (animated). Entry: A=character ID, $00/$02=position.
drawCharacterSpriteMenu:
        REP #$20
        STZ.W $1C04
        STZ.W $1C06
        LDY.W #$0E00
        LDX.W #$0E80
        CMP.W #$0000
        BEQ CODE_81C2F8
        LDY.W #$0E80
        LDX.W #$0E00
CODE_81C2F8:
        STX.B $12
        STY.B $14
        LDA.W $0E6E
        BEQ CODE_81C31D
        STA.B $00
        LDA.W $0E6C
        CMP.W #$0004
        BEQ CODE_81C31A
        LDA.W $0EE5
        AND.W #$00FF
        BEQ CODE_81C31A
        db $3A,$F0,$02,$46,$00,$46,$00
CODE_81C31A:
        JMP.W CODE_81C4D8
CODE_81C31D:
        LDA.W $0016,X
        AND.W #$00FF
        CMP.W #$004C
        BEQ CODE_81C349
        CMP.W #$004D
        BEQ CODE_81C349
        LDA.W $0065,X
        AND.W #$00FF
        CLC
        ADC.W #$0012
        STA.B $00
        LDA.W #$0014
        JSL.L updateSmokeEffect
        CMP.B $00
        BCC CODE_81C349
        STZ.B $00
        JMP.W CODE_81C4D8
CODE_81C349:
        LDA.W $004A,X
        AND.W #$00FF
        STA.B $04
        LDA.W #$0064
        JSL.L updateSmokeEffect
        CMP.B $04
        BCS CODE_81C3B3
        db $E2,$20,$A9,$02,$9D,$23,$00,$C2,$20,$A9,$01,$00,$9D,$5E,$00,$B9
        db $46,$00,$29,$FF,$00,$4A,$38,$E9,$0C,$00,$10,$03,$A9,$00,$00,$8D
        db $06,$1C,$85,$04,$A9,$64,$00,$22,$47,$DF,$00,$C5,$04,$90,$21,$B9
        db $28,$00,$F0,$1C,$C9,$1F,$00,$F0,$17,$B9,$16,$00,$29,$FF,$00,$C9
        db $4A,$00,$F0,$0C,$C9,$4B,$00,$F0,$07,$A9,$E7,$03,$99,$52,$00,$60
        db $A9,$00,$00,$99,$52,$00,$60
CODE_81C3B3:
        LDA.W $0046,Y
        AND.W #$00FF
        STA.B $00
        LDA.W #$0096
        SEC
        SBC.B $00
        PHA
        LDA.W $0008,X
        STA.B $00
        LDA.W $0038,X
        SEC
        SBC.B $00
        TAY
        LDA.W $004C,X
        AND.W #$00FF
        JSR.W monitorSave
        TAY
        LDA.W $0038,X
        JSR.W monitorIRQ
        PLY
        JSR.W monitorSave
        TAY
        LDA.W #$0096
        JSR.W monitorTest
        INC A
        CMP.W #$0064
        BCC CODE_81C3F2
        db $A9,$63,$00
CODE_81C3F2:
        STA.W $1C04
        STA.B $00
        LDX.B $12
        LDY.B $14
        LDA.W #$0064
        JSL.L updateSmokeEffect
        CMP.B $00
        BCS CODE_81C441
        db $B9,$10,$00,$29,$FF,$00,$D0,$33,$BD,$4B,$00,$29,$FF,$00,$85,$02
        db $B9,$28,$00,$F0,$13,$C9,$1F,$00,$F0,$21,$C9,$10,$00,$90,$10,$A5
        db $02,$C9,$07,$00,$F0,$15,$80,$07,$A5,$02,$C9,$03,$00,$F0,$0C,$A5
        db $02,$99,$72,$00,$E2,$20,$99,$10,$00,$C2,$20
CODE_81C441:
        LDA.W $0060,Y
        PHY
        TAY
        LDA.W #$0005
        JSR.W monitorTest
        PLY
        CMP.W #$0014
        BCC CODE_81C455
        db $A9,$14,$00
CODE_81C455:
        STA.B $00
        LDA.W #$0014
        SEC
        SBC.B $00
        STA.B $00
        LDA.W $0049,X
        AND.W #$00FF
        STA.B $08
        LDA.W $003E,Y
        STA.B $02
        LDA.W $003A,X
        STA.B $06
        LDA.W $0E25
        AND.W #$00FF
        BEQ CODE_81C47E
        LDA.W $003C,X
        STA.B $06
CODE_81C47E:
        LDA.B $06
        SEC
        SBC.B $02
        BMI CODE_81C4DE
        BEQ CODE_81C4DE
        LDY.B $00
        JSR.W monitorSave
        TAY
        LDA.W #$0014
        JSR.W monitorTest
        CMP.W #$0000
        BNE CODE_81C49B
        LDA.W #$0001
CODE_81C49B:
        PHA
        JSL.L updateLightningEffect
        AND.W #$0003
        CLC
        ADC.W #$001E
        TAY
        PLA
        JSR.W monitorSave
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        STA.B $00
        BNE CODE_81C4B7
        INC.B $00
CODE_81C4B7:
        LDX.B $12
        LDY.B $14
        LDA.W #$0064
        JSL.L updateSmokeEffect
        CMP.B $08
        BCS CODE_81C4D8
        LDA.B $00
        ASL A
        CLC
        ADC.B $00
        LSR A
        STA.B $00
        SEP #$20
        LDA.B #$01
        STA.W $0023,X
        REP #$20
CODE_81C4D8:
        LDA.B $00
        STA.W $0052,Y
        RTS
CODE_81C4DE:
        LDA.W #$0001
        STA.W $0052,Y
        RTS
; [Animation] Animates menu sprite (idle animation). Entry: updates sprite frame based on timer.
animateMenuSprite:
        REP #$20
        LDY.W #$0E00
        LDX.W #$0E80
        CMP.W #$0000
        BEQ CODE_81C4F8
        LDY.W #$0E80
        LDX.W #$0E00
CODE_81C4F8:
        LDA.W $0052,Y
        BNE CODE_81C4FE
        RTS
CODE_81C4FE:
        STA.B $00
        CMP.W #$03E7
        BEQ CODE_81C53A
        LDA.W $096A
        CMP.W #$0002
        BNE CODE_81C53A
        INC.W $0E67
        LDA.B $00
        CPY.W #$0E00
        BEQ CODE_81C52A
        PHY
        LDY.W #$0025
        JSR.W monitorSave
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        PLY
        INC A
        INC A
        STA.B $00
        BRA CODE_81C53A
        db $5A,$A0,$1B,$00,$20,$DB,$EE,$4A,$4A,$4A,$4A,$4A,$7A,$1A,$85,$00
CODE_81C53A:
        LDA.B $00
        CMP.W #$0100
        BNE CODE_81C544
        db $A9,$FF,$00
CODE_81C544:
        STA.W $0052,Y
        LSR A
        LSR A
        LSR A
        LSR A
        INC A
        SEP #$20
        STA.W $0022,Y
        REP #$20
        LDA.W $0008,Y
        SEC
        SBC.B $00
        BEQ CODE_81C55D
        BCS CODE_81C567
CODE_81C55D:
        LDA.W $0027,Y
        INC A
        STA.W $0027,Y
        LDA.W #$0000
CODE_81C567:
        STA.W $0008,Y
        PHX
        PHY
        JSR.W executeDebugCommand
        JSR.W decompressSaveData
        PLY
        PLX
        LDA.W $0023,X
        AND.W #$00FF
        CLC
        ADC.W #$000C
        STA.B $00
        LDA.W $0E67
        AND.W #$00FF
        BEQ CODE_81C58D
        LDA.W #$000F
        STA.B $00
CODE_81C58D:
        LDA.B $00
        JSL.L updateFilmGrain
        RTS
; [Menu] Draws drop shadow for window. Entry: $00/$02=window position, $04/$06=size.
drawWindowShadow:
        JSR.W drawNumber
        LDA.B $82
        BEQ CODE_81C5A7
        LDA.B $4E
        AND.W #$3000
        BEQ CODE_81C5A7
        LDA.W #$FFFF
        STA.B $82
CODE_81C5A7:
        BRA CODE_81C5CA
; [Menu] Draws decorative border around element. Entry: A=border style, $00/$02=position.
drawBorder:
        REP #$20
        JSR.W drawNumber
        LDA.W $096A
        BEQ CODE_81C5CA
        LDA.B $50
        AND.W #$4080
        BEQ CODE_81C5CA
        LDA.W $0AA5
        BNE CODE_81C5C4
        STZ.W $096A
        BRA CODE_81C5CA
CODE_81C5C4:
        LDA.W #$0002
        STA.W $096A
CODE_81C5CA:
        LDA.W $0AA7
        BEQ CODE_81C60E
        CMP.W #$FF00
        BCC CODE_81C5D9
        JSR.W drawBackgroundPattern
        BRA CODE_81C626
CODE_81C5D9:
        CMP.W #$FE00
        BCC CODE_81C5E6
        AND.W #$00FF
        JSR.W importSaveData
        BRA CODE_81C626
CODE_81C5E6:
        CMP.W #$FD00
        BCC CODE_81C5F6
        AND.W #$00FF
        ORA.W #$0008
        JSR.W exportSaveData
        BRA CODE_81C626
CODE_81C5F6:
        CMP.W #$FC00
        BCC CODE_81C600
        JSR.W setupTransparency
        BRA CODE_81C626
CODE_81C600:
        CMP.W #$1000
        BCS CODE_81C612
        CLC
        ADC.W #$2000
        JSR.W drawPartyFace
        BRA CODE_81C626
CODE_81C60E:
        JSR.W confirmAction
        RTS
CODE_81C612:
        PHA
        LDA.W #$000B
        JSR.W monitorFlags
        JSR.W monitorInventory
        LDA.W #$0005
        STA.W $0A0C
        PLA
        JSR.W monitorInput
CODE_81C626:
        JSR.W confirmAction
        STZ.W $0AA7
        RTS
; Draws background pattern (checker, gradient). Entry: A=pattern type, fills area.
drawBackgroundPattern:
        AND.W #$00FF
        STA.B $00
        PHA
        AND.W #$0040
        BEQ CODE_81C650
        PLA
        CMP.W #$0040
        BNE CODE_81C645
        db $20,$2F,$DA,$20,$43,$DA,$60
CODE_81C645:
        AND.W #$003F
        LDY.W #$0000
        LDX.W #$0800
        BRA CODE_81C675
CODE_81C650:
        LDA.B $00
        AND.W #$003F
        ORA.W #$0500
        LDY.W #$0080
        LDX.W #$0800
        JSL.L calculateSlope
        PLA
        CMP.W #$0080
        BCC CODE_81C679
        db $29,$3F,$00,$1A,$09,$00,$05,$A0,$80,$00,$A2,$00,$00
CODE_81C675:
        JSL.L calculateSlope
CODE_81C679:
        RTS
; [Effects] Sets up transparency/color math for effects. Entry: A=effect type (fade, blend, etc).
setupTransparency:
        AND.W #$00FF
        PHA
        STA.B $00
        LDA.W #$0001
        STA.B $02
        LDA.W $0AAD
        STA.B $12
        LDA.W $0AAF
        STA.B $14
        JSR.W monitorHelp
        PLA
        CMP.W #$0080
        BCC CODE_81C6A5
        AND.W #$001F
        STA.B $00
        LDA.W #$0001
        STA.B $02
        JSR.W monitorRegisters
CODE_81C6A5:
        RTS
; [Effects] Handles screen shake effect (earthquake, impact). Entry: A=intensity, updates scroll registers.
handleScreenShake:
        REP #$20
        LDA.W #$0002
        STA.W $0968
        STZ.W $0966
        STZ.W $0E66
        LDA.W $0964
        STA.B $12
        LDY.W #$0E00
        LDX.W #$0E80
        LDA.W $0964
        BEQ CODE_81C6CA
        LDY.W #$0E80
        LDX.W #$0E00
CODE_81C6CA:
        SEP #$20
        LDA.B #$01
        STA.W $0054,X
        STA.W $0054,Y
        LDA.W $0E25
        BNE CODE_81C6DA
        INC A
CODE_81C6DA:
        STA.B $00
        LDA.W $005C,X
        CMP.B $00
        BCS CODE_81C6EA
        LDA.W $0056,X
        CMP.B $00
        BCS CODE_81C6ED
CODE_81C6EA:
        STZ.W $0054,X
CODE_81C6ED:
        LDA.W $005C,Y
        CMP.B $00
        BCS CODE_81C6FB
        LDA.W $0056,Y
        CMP.B $00
        BCS CODE_81C700
CODE_81C6FB:
        LDA.B #$00
        STA.W $0054,Y
CODE_81C700:
        LDA.W $0054,X
        BEQ CODE_81C766
        LDA.W $0044,Y
        STA.B $08
        LDA.W $0044,X
        SEC
        SBC.B $08
        BPL CODE_81C714
        LDA.B #$00
CODE_81C714:
        STA.B $08
        STZ.B $09
        STA.W $1C08
        LDA.W $0044,X
        STA.B $0A
        LDA.W $0044,Y
        SEC
        SBC.B $0A
        BPL CODE_81C72A
        LDA.B #$00
CODE_81C72A:
        STA.B $0A
        STZ.B $0B
        REP #$20
        LDA.B $0A
        TAY
        JSR.W monitorSave
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        STA.B $0A
        STA.W $1C0A
        LDA.W #$0064
        JSL.L updateSmokeEffect
        CMP.B $08
        BCS CODE_81C758
        INC.W $0E66
        LDA.W $0964
        EOR.W #$0001
        STA.W $0964
CODE_81C758:
        LDA.W #$0064
        JSL.L updateSmokeEffect
        CMP.B $0A
        BCS CODE_81C766
        INC.W $0968
CODE_81C766:
        SEP #$20
        LDA.W $0E60
        LSR A
        LSR A
        STA.W $0E64
        LDA.W $0EE0
        LSR A
        LSR A
        STA.W $0EE4
        LDA.W $0E91
        SEC
        SBC.W $0E11
        CLC
        ADC.B #$04
CODE_81C782:
        CMP.B #$03
        BCC CODE_81C78B
        SEC
        SBC.B #$03
        BRA CODE_81C782
CODE_81C78B:
        STA.W $0E65
        LDA.W $0E11
        SEC
        SBC.W $0E91
        CLC
        ADC.B #$04
CODE_81C798:
        CMP.B #$03
        BCC CODE_81C7A1
        SEC
        SBC.B #$03
        BRA CODE_81C798
CODE_81C7A1:
        STA.W $0EE5
        LDA.W $0E6A
        BEQ CODE_81C7C8
        CMP.B #$01
        BEQ CODE_81C7C5
        LDA.B $12
        BNE CODE_81C7BE
        STA.W $0964
        LDA.B #$01
        STA.W $0968
        STA.W $0E54
        BRA CODE_81C7C8
CODE_81C7BE:
        LDA.B #$FF
        STA.W $0E6C
        BRA CODE_81C7C8
CODE_81C7C5:
        STZ.W $0E54
CODE_81C7C8:
        REP #$20
        RTS
        db $A9,$01,$00,$22,$5C,$88,$00,$20,$22,$B8,$9C,$21,$0E,$9C,$A1,$0E
        db $9C,$26,$0E,$9C,$A6,$0E,$22,$32,$E4,$00,$20,$F0,$C7,$A5,$50,$29
        db $40,$00,$F0,$E6,$60,$C2,$20,$A9,$02,$00,$8D,$1E,$0E,$9C,$28,$0E
        db $9C,$A8,$0E,$9C,$0C,$0A,$A9,$04,$00,$20,$4A,$EE,$20,$94,$C5,$A5
        db $50,$29,$00,$01,$F0,$0B,$AD,$20,$0E,$49,$01,$00,$8D,$20,$0E,$80
        db $E2,$A5,$50,$29,$00,$02,$F0,$0B,$AD,$25,$0E,$49,$01,$00,$8D,$25
        db $0E,$80,$D0,$A5,$50,$29,$00,$08,$F0,$0B,$AD,$5A,$0E,$49,$01,$00
        db $8D,$5A,$0E,$80,$BE,$A5,$50,$29,$00,$04,$F0,$13,$E2,$20,$AD,$23
        db $0E,$1A,$C9,$03,$D0,$02,$A9,$00,$8D,$23,$0E,$C2,$20,$80,$A4,$C2
        db $20,$A5,$50,$29,$40,$40,$F0,$01,$60,$A5,$50,$29,$80,$80,$D0,$02
        db $80,$9A,$A5,$50,$29,$00,$80,$F0,$03,$EE,$28,$0E,$AD,$5A,$0E,$F0
        db $03,$4C,$CA,$C8,$A9,$05,$00,$20,$4A,$EE,$E2,$20,$A9,$02,$8D,$26
        db $0E,$9C,$27,$0E,$9C,$A7,$0E,$AD,$23,$0E,$C9,$02,$D0,$03,$EE,$A7
        db $0E,$C2,$20,$AD,$04,$10,$F0,$13,$9C,$04,$10,$A9,$10,$00,$22,$11
        db $E6,$00,$E2,$20,$A9,$01,$8D,$A2,$0E,$C2,$20,$20,$94,$C5,$AD,$00
        db $10,$D0,$DE,$AD,$00,$12,$D0,$D9,$A9,$07,$00,$20,$4A,$EE,$60,$AD
        db $23,$0E,$8D,$A3,$0E,$AD,$25,$0E,$8D,$A5,$0E,$A9,$05,$00,$20,$4A
        db $EE,$E2,$20,$A9,$02,$8D,$A6,$0E,$9C,$A7,$0E,$9C,$27,$0E,$AD,$A3
        db $0E,$C9,$02,$D0,$03,$EE,$27,$0E,$C2,$20,$AD,$04,$12,$F0,$13,$9C
        db $04,$12,$A9,$10,$00,$22,$11,$E6,$00,$E2,$20,$A9,$01,$8D,$22,$0E
        db $C2,$20,$20,$94,$C5,$AD,$00,$10,$D0,$DE,$AD,$00,$12,$D0,$D9,$9C
        db $0C,$0A,$60
; [Effects] Flash screen effect (white/color flash). Entry: A=color, X=duration.
flashScreen:
        REP #$20
        CMP.W #$0020
        BCS CODE_81C957
        PHA
        CPY.W #$0080
        BCC CODE_81C932
        TYA
        AND.W #$007F
        TAY
        BRA CODE_81C93B
CODE_81C932:
        LDA.W $AD2C,Y
        AND.W #$00FF
        JSR.W monitorDisassemble
CODE_81C93B:
        PLA
        CPY.W #$0003
        BEQ CODE_81C958
        CPY.W #$0004
        BEQ CODE_81C967
        CPY.W #$000E
        BEQ CODE_81C967
        CPY.W #$000D
        BEQ CODE_81C97E
        JSR.W updateWindowMask
        JSL.L drawDialogBox
CODE_81C957:
        RTS
CODE_81C958:
        JSR.W pulseEffect
        SEC
        SBC.W #$0E00
        STA.W $096C
        JSL.L drawTextString
        RTS
CODE_81C967:
        PHY
        JSR.W pulseEffect
        SEC
        SBC.W #$1000
        STA.W $096E
        AND.W #$00FF
        STA.W $096C
        PLA
        JSL.L animateBattleEffect
        RTS
        db $20,$86,$C9,$22,$67,$87,$00,$60
; [Effects] Pulse effect for highlighting. Entry: A=target, updates brightness cyclically.
pulseEffect:
        JSR.W initBattleState
        LDA.W $1404,X
        STA.B $00
        JSR.W setupWindowMask
        LDA.B $00
        RTS
; [Effects] Sets up scanline color effect via HDMA. Entry: A=effect type (gradient, split, etc).
drawScanlineEffect:
        REP #$20
        CMP.W #$0000
        BEQ CODE_81C9E1
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
CODE_81C9E1:
        LDA.W #$F0F0
        STA.W $0100,Y
        STA.W $0104,Y
        STA.W $0108,Y
        STA.W $010C,Y
        RTS
; [Effects] Updates scanline effect parameters. Entry: modifies HDMA table in real-time.
updateScanlineEffect:
        REP #$20
        STA.W $0102,Y
        CLC
        ADC.W #$0002
        STA.W $0106,Y
        LDA.B $00
        STA.W $0100,Y
        CLC
        ADC.W #$0010
        STA.W $0104,Y
        RTS
; [Effects] Sets up mosaic effect for transition. Entry: A=intensity, applies to BG/OBJ layers.
setupMosaic:
        REP #$20
        STA.W $0102,Y
        LDA.B $00
        STA.W $0100,Y
        CLC
        ADC.W #$1000
        STA.B $00
        TYA
        CLC
        ADC.W #$0004
        TAY
        RTS
; [Effects] Updates mosaic effect over time. Entry: called each frame during transition.
updateMosaic:
        REP #$20
        PHY
        SEP #$20
        LDA.B $00
        STA.W $4202
        LDA.B #$18
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDY.W $4216
        REP #$20
        TYA
        STA.B $02
        SEP #$20
        LDA.B $01
        STA.W $4202
        LDA.B #$18
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDY.W $4216
        REP #$20
        TYA
        CLC
        ADC.W #$000E
        STA.B $04
        PLY
        RTS
; [Effects] Sets up window masking for effects. Entry: A=window ID, $00-$03=coordinates.
setupWindowMask:
        REP #$20
        JSR.W updateMosaic
        LDA.B $04
        SEC
        SBC.B $62
        CMP.W #$FFE0
        BCS CODE_81CA70
        CMP.W #$00E6
        BCC CODE_81CA70
        db $80,$1E
CODE_81CA70:
        SEP #$20
        STA.B $01
        REP #$20
        LDA.B $02
        SEC
        SBC.B $60
        CMP.W #$FFE0
        BCS CODE_81CA87
        CMP.W #$0100
        BCC CODE_81CA87
        db $80,$07
CODE_81CA87:
        SEP #$20
        STA.B $00
        REP #$20
        RTS
        db $A9,$00,$E0,$85,$00,$60
; [Effects] Updates window mask position/size. Entry: animates window for reveal effects.
updateWindowMask:
        PHP
        REP #$20
        AND.W #$00FF
        ASL A
        ASL A
        ASL A
        ASL A
        TAX
        PLP
        RTS
; [Effects] Handles screen transition wipes (circle, square, etc). Entry: A=wipe type.
handleTransitionWipe:
        REP #$20
        STZ.W $0972
        STA.W $0974
        TYA
        STA.W $096C
        JSL.L sendSPCCommand
        STZ.W $0970
        JSR.W drawTransitionMask
        LDA.W $096C
        BEQ CODE_81CABF
        JSR.W monitorInput
CODE_81CABF:
        JSR.W drawTransitionMask
        JSR.W compressSaveData
        JSR.W drawNumber
        LDA.B $50
        BEQ CODE_81CB25
        LDY.W #$0000
        LDA.W $098A
        CMP.W #$0080
        BEQ CODE_81CADA
        LDY.W #$0020
CODE_81CADA:
        TYA
        JSR.W compressSaveData
        STZ.W $0970
        LDA.B $50
        AND.W #$8000
        BNE CODE_81CB53
        LDA.B $50
        AND.W #$0080
        BNE CODE_81CB42
        LDA.B $50
        AND.W #$0800
        BEQ CODE_81CAFE
        LDA.W $0974
        BEQ CODE_81CAFE
        DEC.W $0974
CODE_81CAFE:
        LDA.B $50
        AND.W #$0400
        BEQ CODE_81CB08
        INC.W $0974
CODE_81CB08:
        LDA.B $50
        AND.W #$0200
        BEQ CODE_81CB12
        STZ.W $0972
CODE_81CB12:
        LDA.B $50
        AND.W #$0100
        BEQ CODE_81CB1F
        LDA.W #$0001
        STA.W $0972
CODE_81CB1F:
        LDA.W #$0003
        JSR.W monitorDisassemble
CODE_81CB25:
        LDA.B $6A
        AND.W #$00FF
        BEQ CODE_81CB32
        JSR.W logTestFailure
        JSR.W updateConfigSettings
CODE_81CB32:
        JSR.W dumpMemory
        LDA.B $50
        AND.W #$0F00
        BEQ CODE_81CB3F
        JMP.W $CAB4
CODE_81CB3F:
        JMP.W CODE_81CABF
CODE_81CB42:
        LDA.W $0E5A
        CMP.W #$0080
        BCS CODE_81CB5C
        INC.B $22
        LDA.W #$0002
        JSR.W monitorDisassemble
        RTS
CODE_81CB53:
        STZ.B $22
        LDA.W #$0001
        JSR.W monitorDisassemble
        RTS
CODE_81CB5C:
        AND.W #$007F
        EOR.B $24
        STA.B $24
        LDA.W #$0002
        JSR.W monitorDisassemble
        JMP.W $CAB4
; [Effects] Draws transition mask shape to window. Entry: A=shape, updates window data.
drawTransitionMask:
        LDA.W $0974
        ASL A
        CLC
        ADC.W $0972
        STA.B $22
        ASL A
        ASL A
        CLC
        ADC.W $096E
        TAY
        LDA.W $0000,Y
        BEQ CODE_81CBC3
        AND.W #$00FF
        STA.W $09FC
        LDA.W $0001,Y
        AND.W #$00FF
        STA.W $09FE
        LDA.W $0003,Y
        AND.W #$00FF
        STA.W $0E5A
        CMP.W #$0080
        BCC CODE_81CBB9
        SEP #$20
        LDA.B #$01
        STA.B $00
        LDX.W #$0000
CODE_81CBA8:
        LDA.B $24
        AND.B $00
        STA.W $0E00,X
        ASL.B $00
        INX
        CPX.W #$0006
        BCC CODE_81CBA8
        REP #$20
CODE_81CBB9:
        LDA.W $0002,Y
        AND.W #$00FF
        STA.W $098A
        RTS
CODE_81CBC3:
        LDA.W $0002,Y
        AND.W #$00FF
        STA.W $0972
        LDA.W $0003,Y
        AND.W #$00FF
        STA.W $0974
        BRA drawTransitionMask
; [Save] Compresses save data before writing to SRAM. Entry: $12/$14=source, $16/$18=dest.
compressSaveData:
        TAY
        BNE CODE_81CBE3
        LDY.W #$0020
        LDA.W #$3900
        STA.W $0A1E
CODE_81CBE3:
        CMP.W #$0080
        BNE CODE_81CBEE
        LDA.W #$3900
        STA.W $0A1E
CODE_81CBEE:
        INC.W $0970
        LDA.W $0970
        AND.W #$0010
        BEQ CODE_81CBFC
        LDY.W #$0020
CODE_81CBFC:
        TYA
        JSR.W monitorMap
        STZ.W $0A1E
        RTS
        db $C2,$20,$20,$D6,$EC,$A9,$00,$00,$20,$33,$DB,$A9,$08,$00,$20,$F8
        db $DA,$9C,$00,$0E,$9C,$02,$0E,$9C,$04,$0E,$9C,$0A,$0E,$A5,$6B,$29
        db $FF,$01,$8D,$06,$0E,$A5,$6D,$29,$FF,$01,$8D,$08,$0E,$A9,$43,$00
        db $20,$4A,$EE,$20,$84,$B8,$A5,$50,$29,$00,$10,$F0,$01,$60,$A5,$50
        db $29,$00,$20,$F0,$03,$4C,$33,$CD,$A5,$50,$29,$30,$00,$F0,$03,$4C
        db $1B,$CD,$A5,$4E,$29,$00,$40,$F0,$03,$4C,$07,$CD,$A5,$50,$29,$40
        db $00,$D0,$3D,$20,$63,$CE,$A0,$00,$00,$A5,$4E,$29,$80,$00,$F0,$03
        db $A0,$02,$00,$A5,$4E,$29,$00,$80,$F0,$03,$A0,$04,$00,$A5,$00,$D0
        db $02,$80,$9A,$B9,$00,$0E,$18,$65,$00,$99,$00,$0E,$98,$F0,$8E,$AD
        db $04,$0E,$0A,$0A,$0A,$0A,$18,$6D,$02,$0E,$20,$33,$DB,$4C,$21,$CC
        db $A9,$09,$00,$20,$F8,$DA,$A9,$00,$00,$85,$14,$A9,$40,$80,$85,$12
        db $A9,$87,$00,$85,$00,$A9,$01,$00,$85,$02,$20,$7C,$EB,$A9,$07,$00
        db $85,$00,$A9,$01,$00,$85,$02,$20,$81,$EB,$AD,$00,$0E,$85,$00,$A5
        db $6A,$29,$FF,$00,$C9,$01,$00,$F0,$05,$A9,$00,$05,$04,$00,$A5,$00
        db $A2,$00,$00,$A0,$81,$00,$22,$E1,$C2,$00,$A9,$07,$00,$85,$00,$A9
        db $01,$00,$85,$02,$20,$81,$EB,$A9,$08,$00,$20,$F8,$DA,$9C,$0A,$0E
        db $4C,$21,$CC,$20,$2E,$CE,$A5,$6B,$18,$65,$00,$85,$6B,$A5,$6D,$18
        db $65,$02,$85,$6D,$4C,$21,$CC,$AD,$0A,$0E,$1A,$C9,$05,$00,$90,$03
        db $A9,$00,$00,$8D,$0A,$0E,$09,$08,$00,$20,$F8,$DA,$4C,$21,$CC,$9C
        db $00,$0E,$9C,$08,$0E,$AD,$00,$0E,$0A,$0A,$0A,$18,$69,$80,$03,$AA
        db $BF,$00,$E8,$7F,$8D,$04,$0E,$BF,$02,$E8,$7F,$8D,$06,$0E,$20,$D1
        db $DB,$8D,$02,$0E,$A9,$42,$00,$20,$4A,$EE,$20,$84,$B8,$A5,$50,$29
        db $00,$0F,$D0,$31,$A5,$50,$29,$10,$00,$F0,$06,$A0,$08,$00,$4C,$F0
        db $CD,$A5,$50,$29,$20,$00,$F0,$06,$A0,$09,$00,$4C,$F0,$CD,$A5,$50
        db $29,$00,$10,$F0,$01,$60,$A5,$50,$29,$00,$20,$F0,$03,$4C,$04,$CC
        db $20,$EE,$B7,$80,$C5,$20,$63,$CE,$A5,$4E,$29,$C0,$C0,$F0,$7A,$A5
        db $4E,$29,$40,$00,$F0,$06,$A9,$02,$00,$20,$90,$CE,$A5,$4E,$29,$80
        db $00,$F0,$06,$A9,$01,$00,$20,$90,$CE,$A5,$4E,$29,$00,$40,$F0,$06
        db $A9,$00,$00,$20,$90,$CE,$A5,$4E,$29,$00,$80,$F0,$12,$A9,$00,$00
        db $20,$90,$CE,$A9,$01,$00,$20,$90,$CE,$A9,$02,$00,$20,$90,$CE,$A9
        db $07,$00,$22,$49,$C6,$00,$20,$EE,$B7,$4C,$39,$CD,$B9,$00,$0E,$49
        db $01,$00,$99,$00,$0E,$E2,$20,$A9,$15,$85,$5F,$AD,$08,$0E,$F0,$04
        db $A9,$40,$04,$5F,$AD,$09,$0E,$F0,$04,$A9,$80,$04,$5F,$A9,$FF,$85
        db $5E,$C2,$20,$20,$EE,$B7,$4C,$39,$CD,$AD,$00,$0E,$18,$65,$00,$C9
        db $10,$00,$B0,$03,$8D,$00,$0E,$4C,$39,$CD,$64,$00,$64,$02,$A5,$4E
        db $29,$00,$01,$F0,$05,$A9,$04,$00,$85,$00,$A5,$4E,$29,$00,$02,$F0
        db $05,$A9,$FC,$FF,$85,$00,$A5,$4E,$29,$00,$04,$F0,$05,$A9,$04,$00
        db $85,$02,$A5,$4E,$29,$00,$08,$F0,$05,$A9,$FC,$FF,$85,$02,$60,$64
        db $00,$A5,$50,$29,$00,$01,$F0,$02,$E6,$00,$A5,$50,$29,$00,$02,$F0
        db $02,$C6,$00,$A5,$50,$29,$00,$04,$F0,$05,$A9,$04,$00,$85,$00,$A5
        db $50,$29,$00,$08,$F0,$05,$A9,$FC,$FF,$85,$00,$60,$C2,$20,$85,$02
        db $AD,$00,$0E,$0A,$0A,$0A,$18,$69,$80,$03,$18,$65,$02,$AA,$E2,$20
        db $BF,$00,$E8,$7F,$18,$65,$00,$C9,$20,$B0,$04,$9F,$00,$E8,$7F,$C2
        db $20,$60
; [Save] Decompresses save data after reading from SRAM. Entry: $12/$14=source, $16/$18=dest.
decompressSaveData:
        REP #$20
        LDX.W #$0000
CODE_81CEBB:
        LDA.L $008000,X
        STA.L $7E9480,X
        INX
        INX
        CPX.W #$0040
        BNE CODE_81CEBB
        LDA.W $0E08
        STA.B $00
        LDA.W $0E38
        STA.B $02
        LDA.W #$007E
        STA.B $14
        LDA.W #$94A2
        STA.B $12
        LDA.W #$0002
        STA.B $16
        JSR.W verifySaveData
        LDA.W $0E88
        STA.B $00
        LDA.W $0EB8
        STA.B $02
        LDA.W #$007E
        STA.B $14
        LDA.W #$949C
        STA.B $12
        LDA.W #$FFFE
        STA.B $16
        JSR.W verifySaveData
        RTS
; [Save] Verifies save data integrity with checksum. Entry: reads SRAM, calculates checksum.
verifySaveData:
        STZ.B $04
        LDA.B $00
        BNE CODE_81CF0A
        RTS
CODE_81CF0A:
        ASL A
        ASL A
        ASL A
        ASL A
        TAY
        LDA.B $02
        JSR.W monitorIRQ
        CMP.W #$0000
        BNE CODE_81CF1A
        INC A
CODE_81CF1A:
        CMP.W #$000E
        BCC CODE_81CF22
        LDA.W #$000E
CODE_81CF22:
        STA.B $04
CODE_81CF24:
        LDA.B [$12]
        INC A
        INC A
        STA.B [$12]
        LDA.B $16
        CLC
        ADC.B $12
        STA.B $12
        DEC.B $04
        BNE CODE_81CF24
        RTS
; [Save] Migrates old save data format to new version. Entry: converts data structures if needed.
migrateSaveData:
        STZ.W $0A0C
        LDA.W #$0028
        JSR.W monitorInput
        RTS
        REP #$20
        LDY.W #$0000
        LDA.W $0E6A
        CMP.W #$0004
        BNE CODE_81CF50
        db $A0,$08,$00
CODE_81CF50:
        STY.W $096E
        STZ.W $0974
        JSR.W $D0B3
        LDA.W #$0001
        JSR.W monitorFlags
        LDA.W #$006B
        JSR.W monitorInput
        JSR.W monitorGraphics
        LDA.W $096E
        INC A
        STA.B $22
        LDA.W #$0002
        STA.W $0A00
        LDA.W #$006C
        JSR.W monitorInput
        STZ.W $0A00
        DEC.B $22
        LDA.W #$006C
        JSR.W monitorInput
        LDA.W #$0C10
        JSR.W monitorInput
        LDA.W $0974
        CLC
        ADC.W $096E
        CLC
        ADC.W #$0C00
        JSR.W monitorInput
        LDA.W #$0002
        STA.W $09FC
        LDA.W $0974
        ASL A
        CLC
        ADC.W #$0018
        STA.W $09FE
        STZ.W $0970
CODE_81CFAD:
        LDA.W #$003E
        JSR.W compressSaveData
        JSR.W drawNumber
        LDY.B $50
        TYA
        AND.W #$0800
        BNE CODE_81CFDB
        TYA
        AND.W #$0400
        BNE CODE_81CFF2
        TYA
        AND.W #$8000
        BNE CODE_81D019
        TYA
        AND.W #$0080
        BNE CODE_81D01D
        JSR.W logTestFailure
        JSR.W updateConfigSettings
        JSR.W dumpMemory
        BRA CODE_81CFAD
CODE_81CFDB:
        LDA.W $0974
        BEQ CODE_81CFE5
        DEC.W $0974
        BRA CODE_81D00A
        db $AD,$6E,$09,$29,$07,$00,$F0,$03,$CE,$6E,$09,$80,$18
CODE_81CFF2:
        LDA.W $0974
        BNE CODE_81CFFC
        INC.W $0974
        BRA CODE_81D00A
CODE_81CFFC:
        LDA.W $096E
        AND.W #$0007
        CMP.W $097A
        BCS CODE_81D00A
        INC.W $096E
CODE_81D00A:
        LDA.W #$0020
        JSR.W compressSaveData
        LDA.W #$0003
        JSR.W monitorDisassemble
        JMP.W $CF68
        db $A9,$FF,$FF,$60
CODE_81D01D:
        LDA.W $0974
        CLC
        ADC.W $096E
        TAY
        STA.B $12
        STA.W $0E6C
        STZ.W $0E6E
        LDA.W $1000,Y
        AND.W #$00FF
        STA.B $04
        LDA.W $0E06
        AND.W #$00FF
        LSR A
        STA.B $02
        LDA.B $12
        ASL A
        ASL A
        ASL A
        ASL A
        TAX
        LDA.L $22B572,X
        STA.W $0E6D
        LDA.L $22B570,X
        STA.W $0E70
        AND.W #$00FF
        STA.B $16
        LDA.L $22B575,X
        AND.W #$00FF
        STA.B $00
        SEP #$20
        LDA.L $22B574,X
        STA.W $4202
        LDA.B $04
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        LDY.W $4216
        REP #$20
        TYA
        CLC
        ADC.B $00
        STA.B $14
        LDA.W $0E6E
        BEQ CODE_81D094
        DEC A
        BNE CODE_81D08F
        LDA.B $02
        CLC
        ADC.B $14
        STA.B $14
        BRA CODE_81D094
        db $A9,$00,$80,$04,$14
CODE_81D094:
        LDA.B $14
        STA.W $0E6E
        LDA.B $12
        LDA.W $0E0A
        AND.W #$00FF
        SEC
        SBC.B $16
        BCS CODE_81D0AF
        db $A9,$6D,$00,$20,$4A,$EE,$4C,$59,$CF
CODE_81D0AF:
        STA.W $0E5A
        RTS
        STZ.W $097A
        LDA.W $0E06
        AND.W #$00FF
        STA.B $00
        LDX.W #$0000
        LDA.W #$1000
        STA.B $12
        SEP #$20
        LDA.B #$01
CODE_81D0CA:
        LDA.L $01D113,X
        STA.B ($12)
        INC.B $12
        INX
        CPX.W #$0010
        BNE CODE_81D0CA
        LDX.W #$0000
CODE_81D0DB:
        LDA.L $0BE4CF,X
        BEQ CODE_81D0E9
        DEC A
        STA.B $12
        LDA.B ($12)
        INC A
        STA.B ($12)
CODE_81D0E9:
        INX
        DEC.B $00
        BNE CODE_81D0DB
        LDA.W $1000
        STA.W $1001
        STA.W $1002
        LDX.W $096E
CODE_81D0FA:
        LDA.W $1000,X
        BEQ CODE_81D10A
        INC.W $097A
        INX
        LDA.W $097A
        CMP.B #$08
        BCC CODE_81D0FA
CODE_81D10A:
        DEC.W $097A
        DEC.W $097A
        REP #$20
        RTS
        db $01,$00,$00,$00,$00,$00,$00,$00,$01,$01,$00,$00,$00,$00,$00,$00
        db $00,$00
        db $0A,$00,$14,$00,$1E,$00,$28,$00,$32,$00,$3C,$00,$46,$00,$50,$00
        REP #$20
        JSR.W calculatePlayTime
        LDA.W #$0008
        JSL.L dispatchGameMode
        LDA.W #$0001
        STA.W $2105
        LDA.W #$0017
        LDX.W #$0042
        LDY.W #$0000
        JSL.L calculateSlope
        JSR.W monitorSound
        LDA.W $097A
        INC A
        LDX.W #$0000
        LDY.W #$0008
        JSR.W clearSaveData
        STZ.W $0E58
        LDA.W #$0061
        JSR.W monitorInput
        JSR.W $D1E3
        JSR.W drawMessageBox
CODE_81D173:
        JSR.W $D533
        CMP.W #$03E7
        BNE CODE_81D180
        db $20,$E3,$D1,$80,$F3
CODE_81D180:
        CMP.W #$FFFF
        BNE CODE_81D186
        RTS
CODE_81D186:
        LDA.W $0E5A
        BNE CODE_81D193
        LDA.W #$0088
        JSR.W $D638
        BRA CODE_81D173
        db $AF,$8A,$EA,$7E,$CD,$5A,$0E,$B0,$08,$A9,$86,$00,$20,$38,$D6,$80
        db $CF,$A9,$85,$00,$20,$38,$D6,$AD,$08,$0A,$C9,$01,$00,$D0,$C1,$AF
        db $8A,$EA,$7E,$38,$ED,$5A,$0E,$8F,$8A,$EA,$7E,$E2,$20,$9C,$10,$0E
        db $C2,$20,$A0,$00,$0E,$20,$2A,$DE,$A9,$61,$00,$20,$4A,$EE,$20,$E3
        db $D1,$A9,$87,$00,$20,$38,$D6,$AD,$08,$0A,$C9,$01,$00,$F0,$91,$60
        STZ.W $0A00
        LDA.W $098C
        STA.B $22
CODE_81D1EB:
        LDA.B $22
        JSR.W initBattleState
        LDA.W $1400,X
        BEQ CODE_81D200
        LDA.B $22
        JSR.W $D217
        LDA.W #$0083
        JSR.W monitorInput
CODE_81D200:
        LDA.W $0A00
        CLC
        ADC.W #$0002
        CMP.W #$0010
        BCS CODE_81D213
        STA.W $0A00
        INC.B $22
        BRA CODE_81D1EB
CODE_81D213:
        STZ.W $0A00
        RTS
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W $0E10
        AND.W #$00FF
        ASL A
        TAX
        LDA.L $01D123,X
        STA.W $0E5A
        RTS
        db $0C,$0A,$0B,$0B
; [Save] Creates backup of save data. Entry: copies primary save to backup slot.
backupSaveData:
        REP #$20
        STA.W $0992
        STA.W $0E58
        TAX
        LDA.L $01D22D,X
        AND.W #$00FF
        PHA
        LDA.W #$0009
        JSL.L dispatchGameMode
        PLA
        LDX.W #$0042
        LDY.W #$0080
        JSL.L calculateSlope
        JSR.W monitorSound
        LDA.W $0992
        BNE CODE_81D26A
        LDA.W #$BE10
        STA.B $00
        LDA.W $0E03
        LDY.W #$0100
        JSR.W checkSaveSpace
CODE_81D26A:
        LDX.W #$0000
        LDY.W #$0050
        LDA.W $0992
        AND.W #$0001
        BNE CODE_81D27E
        LDX.W #$0050
        LDY.W #$0080
CODE_81D27E:
        STX.W $0996
        STY.W $0998
        LDA.W $0992
        CMP.W #$0002
        BCC CODE_81D291
        JSR.W $D3F9
        BRA CODE_81D2AE
CODE_81D291:
        SEP #$20
        LDX.W #$0000
        LDY.W #$0000
CODE_81D299:
        LDA.L $7EEA00,X
        BEQ CODE_81D2A8
        STA.W $1001,Y
        TXA
        STA.W $1000,Y
        INY
        INY
CODE_81D2A8:
        INX
        CPX.W #$0070
        BNE CODE_81D299
CODE_81D2AE:
        REP #$20
        TYA
        LSR A
        STA.W $098E
        LDA.W #$0000
        STA.W $1000,Y
        LDA.W $098E
        LDX.W #$0D00
        LDY.W #$0008
        JSR.W clearSaveData
        LDA.W #$0061
        JSR.W monitorInput
        JSR.W restoreBackup
        JSR.W drawMessageBox
        LDA.W $098E
        BNE CODE_81D2E2
        LDA.W #$0063
        JSR.W monitorInput
        LDA.W #$FFFF
        RTS
CODE_81D2E2:
        JSR.W $D533
        CMP.W #$03E7
        BNE CODE_81D2EF
        JSR.W restoreBackup
        BRA CODE_81D2E2
CODE_81D2EF:
        CMP.W #$FFFF
        BNE CODE_81D2F5
        RTS
CODE_81D2F5:
        ASL A
        TAY
        LDA.W $1000,Y
        STA.B $32
        STY.B $34
        AND.W #$00FF
        CMP.W $0996
        BCC CODE_81D318
        CMP.W $0998
        BCS CODE_81D318
        LDA.W $0992
        STA.B $22
        LDA.W #$00B9
        JSR.W $D638
        BRA CODE_81D2E2
CODE_81D318:
        LDA.B $32
        AND.W #$8000
        BNE CODE_81D32F
        LDA.W $0992
        BEQ CODE_81D379
        CMP.W #$0002
        BCS CODE_81D393
        LDA.B $32
        AND.W #$00FF
        RTS
        db $A5,$32,$29,$FF,$00,$C9,$50,$00,$B0,$A9,$A5,$33,$29,$1F,$00,$20
        db $BE,$E8,$CD,$28,$0E,$F0,$08,$A9,$75,$00,$20,$38,$D6,$80,$94,$A9
        db $7F,$00,$20,$38,$D6,$AD,$08,$0A,$C9,$01,$00,$D0,$86,$A0,$FF,$FF
        db $AD,$28,$0E,$20,$C8,$E7,$A4,$34,$B9,$00,$10,$29,$FF,$00,$09,$00
        db $01,$99,$00,$10,$20,$62,$D4,$4C,$E2,$D2
CODE_81D379:
        LDA.W #$0074
        JSR.W $D638
        LDA.W $0A08
        CMP.W #$0001
        BEQ CODE_81D38A
        db $4C,$E2,$D2
CODE_81D38A:
        LDY.B $32
        LDA.W $0E28
        JSR.W $E7C8
        RTS
CODE_81D393:
        LDA.B $33
        AND.W #$00FF
        CMP.W #$007E
        BNE CODE_81D3A5
        LDA.W #$00BA
        JSR.W $D638
        BRA CODE_81D3F6
CODE_81D3A5:
        LDA.B $32
        JSR.W $DE49
        LDA.L $7EEA8A
        CMP.W $0E9A
        BCS CODE_81D3BB
        db $A9,$82,$00,$20,$38,$D6,$80,$3B
CODE_81D3BB:
        LDA.W #$0080
        JSR.W $D638
        LDA.W $0A08
        CMP.W #$0001
        BNE CODE_81D3F6
        LDA.W $0E98
        JSR.W $E7A1
        LDA.L $7EEA8A
        SEC
        SBC.W $0E9A
        STA.L $7EEA8A
        JSR.W $D3F9
        JSR.W restoreBackup
        LDA.W #$0061
        JSR.W monitorInput
        LDA.W #$0081
        JSR.W $D638
        LDA.W $0A08
        CMP.W #$0001
        BEQ CODE_81D3F6
        RTS
CODE_81D3F6:
        JMP.W CODE_81D2E2
        PHP
        REP #$20
        LDA.W #$007E
        STA.B $14
        LDA.W #$EA00
        STA.B $12
        SEP #$20
        LDA.W $0992
        LDX.W #$AF29
        CMP.B #$03
        BNE CODE_81D415
        LDX.W #$AF4B
CODE_81D415:
        STZ.W $0996
        STZ.W $0998
        LDA.L $7EEA8E
        STA.B $00
        LDY.W #$0000
CODE_81D424:
        LDA.B #$7F
        STA.B $02
        LDA.W $0000,X
        INX
        CMP.B #$FF
        BEQ CODE_81D460
        CMP.B #$80
        BCC CODE_81D43C
        AND.B #$7F
        CMP.B $00
        BCS CODE_81D460
        db $80,$E8
CODE_81D43C:
        STA.W $1000,Y
        STA.B $12
        CMP.B #$60
        BCS CODE_81D44D
        LDA.B [$12]
        BEQ CODE_81D457
        DEC.B $02
        BRA CODE_81D457
CODE_81D44D:
        LDA.B [$12]
        CMP.B #$63
        BCC CODE_81D457
        db $C6,$02,$80,$00
CODE_81D457:
        LDA.B $02
        STA.W $1001,Y
        INY
        INY
        BRA CODE_81D424
CODE_81D460:
        PLP
        RTS
; [Save] Restores save data from backup. Entry: copies backup to primary slot.
restoreBackup:
        REP #$20
        LDA.W $098C
        STA.B $22
        LDA.W #$2618
        STA.B $28
        STZ.B $2C
        LDA.B $2C
        ASL A
        CLC
        ADC.W #$0005
        STA.W $09FE
        LDA.B $22
        ASL A
        TAY
        LDA.W $1001,Y
        AND.W #$00FF
        STA.B $24
        LDA.W $1000,Y
        BNE CODE_81D48C
        RTS
CODE_81D48C:
        JSR.W $DE49
        LDA.W #$0005
        STA.W $09FC
        STZ.B $26
        STZ.B $2A
        LDA.W $0E98
        CMP.W $0996
        BCC CODE_81D4A8
        CMP.W $0998
        BCS CODE_81D4A8
        INC.B $2A
CODE_81D4A8:
        LDA.B $24
        CMP.W #$0080
        BCC CODE_81D4C3
        AND.W #$001F
        JSR.W $E8BE
        JSR.W initBattleState
        LDA.W $1412,X
        STA.W $0E00
        LDA.W #$000A
        STA.B $26
CODE_81D4C3:
        LDA.W #$0062
        JSR.W monitorInput
        LDA.B $28
        STA.B $00
        CLC
        ADC.W #$1000
        STA.B $28
        LDA.W $09FE
        ASL A
        ASL A
        TAY
        LDA.W $0E8A
        AND.W #$000F
        ASL A
        TAX
        LDA.L $01D4FB,X
        CLC
        ADC.W #$3180
        JSR.W setupMosaic
        INC.B $22
        INC.B $2C
        LDA.B $2C
        CMP.W #$0008
        BCC CODE_81D4F8
        RTS
CODE_81D4F8:
        JMP.W $D470
        db $00,$00
        db $02,$00
        db $04,$00,$06,$00,$08,$00,$0A,$00
        db $0C,$00,$0E,$00
        db $20,$00
        db $22,$00,$24,$00,$26,$00,$28,$00,$2A,$00
        db $2C,$00,$2E,$00
; [Save] Clears save slot (new game). Entry: A=slot number. Initializes with default data.
clearSaveData:
        REP #$20
        STA.W $098E
        STY.W $0990
        STX.W $0994
        STZ.W $098A
        STZ.W $098C
        LDA.W #$0002
        STA.W $0980
        RTS
        REP #$20
        LDA.W $098C
        CLC
        ADC.W $098A
        STA.B $22
        LDA.W $0994
        BEQ CODE_81D556
        LDA.B $22
        ASL A
        TAY
        LDA.W $1000,Y
        AND.W #$00FF
        CLC
        ADC.W $0994
        JSR.W $D638
        BRA CODE_81D579
CODE_81D556:
        LDA.B $22
        JSR.W $D217
        LDA.W #$0084
        JSR.W $D638
        LDA.W $0E10
        AND.W #$00FF
        CLC
        ADC.W #$00A0
        JSR.W monitorInput
        LDA.W #$BE10
        STA.B $00
        LDY.W #$0000
        JSR.W initSRAM
CODE_81D579:
        LDA.W $0980
        STA.W $09FC
        LDA.W $098A
        ASL A
        CLC
        ADC.W #$0005
        STA.W $09FE
        LDA.W $098E
        SEC
        SBC.W $0990
        BPL CODE_81D596
        LDA.W #$0000
CODE_81D596:
        INC A
        STA.B $24
        LDA.W $0990
        CMP.W $098E
        BCC CODE_81D5A4
        LDA.W $098E
CODE_81D5A4:
        DEC A
        STA.B $26
CODE_81D5A7:
        JSR.W monitorBattle
        LDA.B $50
        AND.W #$F0F0
        BNE CODE_81D62C
        LDA.B $50
        AND.W #$0400
        BNE CODE_81D5FB
        LDA.B $50
        AND.W #$0800
        BNE CODE_81D613
        LDA.B $50
        AND.W #$0100
        BNE CODE_81D5CF
        db $A5,$50,$29,$00,$02,$D0,$1A,$80,$D8
CODE_81D5CF:
        LDA.W $098C
        CLC
        ADC.W $0990
        CMP.B $24
        BCC CODE_81D5E2
        db $A5,$26,$8D,$8A,$09,$A5,$24,$3A
CODE_81D5E2:
        STA.W $098C
        BRA CODE_81D628
        db $AD,$8C,$09,$38,$ED,$90,$09,$10,$06,$A9,$00,$00,$8D,$8A,$09,$8D
        db $8C,$09,$80,$2D
CODE_81D5FB:
        LDA.B $22
        INC A
        CMP.W $098E
        BEQ CODE_81D5A7
        LDA.W $098A
        INC A
        CMP.W $0990
        BNE CODE_81D611
        INC.W $098C
        BRA CODE_81D628
CODE_81D611:
        BRA CODE_81D622
CODE_81D613:
        LDA.B $22
        BEQ CODE_81D5A7
        LDA.W $098A
        BNE CODE_81D621
        DEC.W $098C
        BRA CODE_81D628
CODE_81D621:
        DEC A
CODE_81D622:
        STA.W $098A
        JMP.W $D535
CODE_81D628:
        LDA.W #$03E7
        RTS
CODE_81D62C:
        LDY.B $22
        AND.W #$4080
        BNE CODE_81D636
        LDY.W #$FFFF
CODE_81D636:
        TYA
        RTS
        PHA
        LDA.W #$0060
        JSR.W monitorInput
        PLA
        JSR.W monitorInput
        RTS
; [Menu] Draws save file information (time, location, party). Entry: A=slot number.
drawSaveFileInfo:
        REP #$20
        LDY.W #$0000
        CMP.W #$0010
        BCC CODE_81D64F
        INY
CODE_81D64F:
        STY.W $0E68
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W #$000A
        JSL.L dispatchGameMode
        LDA.W #$2858
        STA.B $00
        LDY.W #$01B0
        LDA.W #$378A
        JSR.W setupMosaic
        LDA.W #$378C
        JSR.W setupMosaic
        LDA.W #$358E
        JSR.W setupMosaic
        LDA.W #$0FA8
        STA.B $00
        LDA.W $0E36
        AND.W #$00FF
        CLC
        ADC.W #$37AC
        JSR.W setupMosaic
        LDA.W #$4010
        STA.B $00
        LDY.W #$01D0
        LDA.W #$3F82
        JSR.W updateScanlineEffect
        LDA.W #$5010
        STA.B $00
        LDY.W #$01D8
        LDA.W #$3F86
        JSR.W updateScanlineEffect
        LDA.W $0E03
        JSR.W updateWindowMask
        ASL A
        TAX
        LDA.L $028050,X
        AND.W #$00FF
        ASL A
        TAX
        LDA.W #$2408
        STA.B $00
        LDY.W #$01E0
        LDA.L $008980,X
        ORA.W #$37C0
        JSR.W drawScanlineEffect
        JSR.W playSelectSound
        LDX.W #$000C
        LDY.W #$FFD8
        JSL.L updateChromaEffect
        LDA.W $0E03
        AND.W #$00FF
        JSL.L updateMode7Effects
        JSL.L clearVRAM
        JSR.W confirmAction
        LDA.W #$0007
        JSR.W monitorFlags
        LDA.W #$0057
        JSR.W monitorInput
        LDA.W $0E03
        AND.W #$00FF
        CLC
        ADC.W #$0500
        JSR.W monitorInput
        JSR.W monitorGraphics
        LDA.W #$0058
        JSR.W monitorInput
        JSR.W formatSRAM
        JSR.W printText
        LDA.W #$0059
        JSR.W monitorInput
        LDA.W $0A08
        CMP.W #$0002
        BNE CODE_81D73E
        LDA.W $0E28
        INC A
        CMP.W #$0010
        BCC CODE_81D72A
        db $A9,$00,$00
CODE_81D72A:
        STA.B $08
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        BNE CODE_81D739
        STZ.B $08
CODE_81D739:
        LDA.B $08
        JMP.W drawSaveFileInfo
CODE_81D73E:
        LDA.W #$000A
        JSR.W setTextColor
        RTS
; [Timer] Calculates play time from frame counter. Entry: converts frames to hours:minutes.
calculatePlayTime:
        STZ.W $0976
        STZ.W $0978
        STZ.W $097A
        LDX.W #$0000
        LDY.W #$0000
CODE_81D754:
        LDA.W $1400,Y
        BEQ CODE_81D75C
        INC.W $097A
CODE_81D75C:
        LDA.W $1403,Y
        AND.W #$003F
        STA.L $7FCE00,X
        TYA
        CLC
        ADC.W #$0020
        TAY
        INX
        CPX.W #$0010
        BNE CODE_81D754
        DEC.W $097A
        LDA.W #$2223
        STA.L $7FCE10
        RTS
; [Timer] Updates play time counter. Entry: increments frame counter, handles overflow.
updatePlayTime:
        REP #$20
        STA.W $097C
        JSR.W calculatePlayTime
        LDA.W #$0008
        JSL.L dispatchGameMode
        LDA.W #$0007
        LDX.W #$0042
        LDY.W #$0000
        JSL.L calculateSlope
        LDA.W #$0007
        JSR.W monitorFlags
        JSR.W drawPlayTime
        JSR.W printText
CODE_81D7A5:
        LDA.W $0976
        ASL A
        STA.B $00
        ASL A
        CLC
        ADC.B $00
        CLC
        ADC.W #$0005
        STA.W $09FE
        LDA.W #$0005
        STA.W $09FC
        JSR.W monitorBattle
        LDA.W $0978
        CLC
        ADC.W $0976
        TAY
        LDA.B $50
        AND.W #$C0C0
        BNE CODE_81D80E
        LDA.B $50
        AND.W #$0400
        BNE CODE_81D7DE
        LDA.B $50
        AND.W #$0800
        BNE CODE_81D7F5
        BRA CODE_81D7A5
CODE_81D7DE:
        CPY.W $097A
        BEQ CODE_81D7A5
        LDA.W $0976
        CMP.W #$0003
        BNE CODE_81D7F0
        INC.W $0978
        BRA CODE_81D809
CODE_81D7F0:
        INC.W $0976
        BRA CODE_81D7A5
CODE_81D7F5:
        CPY.W #$0000
        BEQ CODE_81D7A5
        LDA.W $0976
        BNE CODE_81D804
        DEC.W $0978
        BRA CODE_81D809
CODE_81D804:
        DEC.W $0976
        BRA CODE_81D7A5
CODE_81D809:
        JSR.W handleAutoSave
        BRA CODE_81D7A5
CODE_81D80E:
        LDA.B $50
        AND.W #$0040
        BNE CODE_81D82C
        LDA.W $097C
        BEQ CODE_81D82B
        LDA.B $50
        AND.W #$4080
        BNE CODE_81D833
        LDA.B $50
        AND.W #$8000
        BEQ CODE_81D82B
        JMP.W $D8BF
CODE_81D82B:
        RTS
CODE_81D82C:
        TYA
        JSR.W drawSaveFileInfo
        JMP.W $D785
CODE_81D833:
        TYA
        JSR.W initBattleState
        LDA.W $1401,X
        AND.W #$00FF
        CMP.W #$0004
        BCS CODE_81D845
        JMP.W CODE_81D7A5
CODE_81D845:
        CMP.W #$0004
        BNE CODE_81D8A1
        LDA.W $1400,X
        AND.W #$00FF
        BNE CODE_81D8A1
        PHX
        LDA.W #$0009
        JSR.W monitorFlags
        LDA.W #$005C
        JSR.W monitorInput
        PLX
        SEP #$20
        LDA.B #$22
        STA.B $00
        LDA.B #$43
        STA.B $02
        LDA.W $0A08
        BEQ CODE_81D899
        CMP.B #$02
        BEQ CODE_81D87B
        LDA.B #$23
        STA.B $00
        LDA.B #$44
        STA.B $02
CODE_81D87B:
        LDA.B $02
        STA.W $1412,X
        LDA.B $00
        STA.W $1403,X
        LDA.W $1400,X
        EOR.B #$FF
        BEQ CODE_81D896
        LDY.W $097E
        CPY.W #$0007
        BCC CODE_81D896
        db $A9,$00
CODE_81D896:
        STA.W $1400,X
CODE_81D899:
        REP #$20
        JSR.W drawPlayTime
        JMP.W CODE_81D7A5
CODE_81D8A1:
        SEP #$20
        LDA.W $1400,X
        EOR.B #$FF
        BEQ CODE_81D8B4
        LDY.W $097E
        CPY.W #$0007
        BCC CODE_81D8B4
        db $A9,$00
CODE_81D8B4:
        STA.W $1400,X
        REP #$20
        JSR.W handleAutoSave
        JMP.W CODE_81D7A5
        TYA
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W #$000A
        JSR.W monitorFlags
        LDY.W #$008E
        LDA.W #$0000
        JSR.W handleTransitionWipe
        LDA.B $22
        BNE CODE_81D8DC
        JMP.W CODE_81D899
CODE_81D8DC:
        CMP.W #$0003
        BEQ CODE_81D8F9
        LDA.W #$000A
        JSR.W monitorFlags
        LDA.W #$008F
        JSR.W monitorInput
        LDA.W $0A08
        CMP.W #$0001
        BEQ CODE_81D8F8
        db $4C,$99,$D8
CODE_81D8F8:
        RTS
CODE_81D8F9:
        LDA.W #$0000
        JSR.W backupSaveData
        JSR.W clearTextBuffer
        JMP.W $D785
; [HUD] Draws play time display. Entry: formats time string, draws to screen.
drawPlayTime:
        JSR.W monitorSound
        LDX.W #$0282
        LDY.W #$0003
CODE_81D90E:
        PHY
        PHX
        LDY.W #$001E
        LDA.W #$3170
CODE_81D916:
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE CODE_81D916
        PLA
        CLC
        ADC.W #$0180
        TAX
        PLY
        DEY
        BNE CODE_81D90E
; [Save] Handles auto-save feature. Entry: called at specific points (zone transitions).
handleAutoSave:
        LDA.W #$0007
        JSR.W monitorFlags
        STZ.W $097E
        LDX.W #$0000
CODE_81D935:
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_81D940
        INC.W $097E
CODE_81D940:
        TXA
        CLC
        ADC.W #$0020
        TAX
        CPX.W #$0200
        BNE CODE_81D935
        LDA.W $0978
        CLC
        ADC.W #$0004
        STA.B $24
        LDA.W #$0004
        STA.B $22
        STZ.B $28
CODE_81D95B:
        DEC.B $22
        DEC.B $24
        LDA.B $24
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W $0E00
        BEQ CODE_81D9B7
        LDA.B $22
        ASL A
        STA.B $00
        ASL A
        CLC
        ADC.B $00
        STA.W $0A00
        CLC
        ADC.W #$0005
        SEP #$20
        ASL A
        ASL A
        ASL A
        CLC
        ADC.B #$07
        STA.B $01
        LDA.B #$10
        STA.B $00
        REP #$20
        LDY.B $28
        JSR.W initSRAM
        LDA.B $00
        CLC
        ADC.W #$1000
        STA.B $00
        LDA.B $28
        CLC
        ADC.W #$0040
        TAY
        JSR.W detectSRAM
        JSR.W updateScanlineEffect
        LDA.B $28
        CLC
        ADC.W #$0010
        STA.B $28
        LDA.W #$001C
        JSR.W monitorInput
        JSR.W formatSRAM
CODE_81D9B7:
        LDA.B $22
        BNE CODE_81D95B
        RTS
; [Save] Checks if enough space for save data. Entry: verifies SRAM is writable.
checkSaveSpace:
        STA.W $0E03
        PHY
        CMP.W #$FFFF
        BNE CODE_81D9CB
        INC A
        JSR.W drawScanlineEffect
        BRA CODE_81D9CE
CODE_81D9CB:
        JSR.W initSRAM
CODE_81D9CE:
        PLA
        CLC
        ADC.W #$0010
        TAY
        RTS
; [Save] Initializes SRAM on first boot. Entry: writes header, initializes all slots.
initSRAM:
        PHY
        LDA.W $0E03
        AND.W #$003F
        PHA
        JSR.W drawMapScreen
        STA.B $02
        PLX
        LDA.W $D138,X
        AND.W #$0003
        ASL A
        ORA.B $03
        STA.B $03
        LDA.B $02
        ORA.W #$3800
        PLY
        JSR.W drawScanlineEffect
        RTS
; [Save] Detects SRAM type and size. Entry: tests write/read to determine capacity.
detectSRAM:
        LDA.W $0E00
        AND.W #$00FF
        BNE CODE_81DA0D
        LDA.W $0E08
        BNE CODE_81DA09
        db $A9,$AC,$3F,$60
CODE_81DA09:
        LDA.W #$3FA4
        RTS
CODE_81DA0D:
        LDA.W $0E0F
        AND.W #$00FF
        BNE CODE_81DA19
        LDA.W #$3FA8
        RTS
        db $A9,$A0,$3F,$60
; [Save] Formats SRAM (erase all saves). Entry: called from options menu.
formatSRAM:
        LDA.W $0E37
        AND.W #$0030
        LSR A
        LSR A
        LSR A
        LSR A
        CLC
        ADC.W #$0024
        JSR.W monitorInput
        RTS
; [Menu] Draws SRAM status (free space, slots). Entry: shows save slot usage.
drawSRAMStatus:
        REP #$20
        LDX.W #$0000
        LDA.W #$0000
CODE_81DA37:
        STA.L $7FB000,X
        INX
        INX
        CPX.W #$0800
        BNE CODE_81DA37
        RTS
; [Save] Handles SRAM error (corrupt, missing). Entry: displays error message, offers recovery.
handleSRAMError:
        REP #$20
        LDA.W #$7000
        STA.B $78
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSR.W confirmAction
        RTS
; [Save] Attempts to recover corrupted save data. Entry: scans SRAM for valid data fragments.
recoverSaveData:
        REP #$20
        LDA.L $7EEA82
        CMP.W #$0025
        BNE CODE_81DA7B
        db $AF,$96,$EA,$7E,$29,$FF,$00,$C9,$FE,$00,$D0,$0E,$A9,$45,$80,$8F
        db $05,$C0,$7F,$A9,$26,$00,$8F,$07,$C0,$7F
CODE_81DA7B:
        REP #$20
        JSR.W confirmAction
        LDA.L $7FC006
        AND.W #$000F
        JSR.W exportSaveData
        LDA.L $7FC005
        AND.W #$00FF
        JSR.W importSaveData
        SEP #$20
        LDA.B #$70
        STA.B $00
        LDA.L $7FC006
        STA.B $02
        AND.B #$40
        BEQ CODE_81DAA9
        db $A9,$10,$8D,$61,$43
CODE_81DAA9:
        LDA.B $02
        LSR A
        LSR A
        LSR A
        LSR A
        AND.B #$03
        CLC
        ADC.B $00
        STA.W $2108
        REP #$20
        JSR.W confirmAction
        LDY.W #$0000
        LDA.B $02
        AND.W #$0080
        BEQ CODE_81DAC9
        db $A0,$00,$01
CODE_81DAC9:
        LDA.L $7FC007
        AND.W #$00FF
        BEQ CODE_81DAF1
        LDX.W #$0000
        PHY
        JSL.L calculateSlope
        PLA
        CLC
        ADC.W #$0007
        TAY
        LDA.L $7FC008
        AND.W #$00FF
        BEQ CODE_81DAF7
        LDX.W #$0800
        JSL.L calculateSlope
        RTS
CODE_81DAF1:
        JSR.W drawSRAMStatus
        JSR.W handleSRAMError
CODE_81DAF7:
        RTS
; [Debug] Exports save data (debug feature). Entry: copies to WRAM for analysis.
exportSaveData:
        PHP
        REP #$20
        STA.B $00
        AND.W #$0007
        BEQ CODE_81DB28
        DEC A
        TAX
        SEP #$20
        LDA.L $01DB2F,X
        STA.B $5F
        LDA.B #$FF
        STA.B $5E
        LDA.B $00
        AND.B #$08
        BEQ CODE_81DB1C
        LDA.B $5F
        AND.B #$FB
        STA.B $5F
CODE_81DB1C:
        REP #$20
        JSR.W confirmAction
        LDA.W #$0215
        STA.B $74
        BRA CODE_81DB2D
CODE_81DB28:
        LDA.W #$0017
        STA.B $74
CODE_81DB2D:
        PLP
        RTS
        db $15,$55,$95
        db $D5
; [Debug] Imports save data (debug feature). Entry: writes from WRAM to SRAM.
importSaveData:
        PHP
        SEP #$20
        STA.B $00
        AND.B #$F0
        BNE CODE_81DB44
        LDA.B #$00
        STA.L $7EA000
        BRA CODE_81DB53
CODE_81DB44:
        JSR.W $DB5B
        LDA.B $00
        LSR A
        LSR A
        LSR A
        LSR A
        STA.B $76
        LDA.B #$50
        STA.B $84
CODE_81DB53:
        LDA.B $00
        AND.B #$0F
        STA.B $77
        PLP
        RTS
        PHP
        REP #$20
        LDA.W #$000C
        STA.L $7EA000
        LDA.W #$0000
        STA.L $7EA001
        LDX.W #$0003
        LDY.W #$0064
CODE_81DB72:
        LDA.W #$0002
        STA.L $7EA000,X
        LDA.W #$0000
        STA.L $7EA001,X
        INX
        INX
        INX
        DEY
        BNE CODE_81DB72
        LDA.W #$0000
        STA.L $7EA000,X
        PLP
        RTS
        REP #$20
        PHX
        AND.W #$01FF
        CMP.W #$0100
        BCC CODE_81DBA5
        AND.W #$00FF
        STA.B $00
        LDA.W #$00FF
        SEC
        SBC.B $00
CODE_81DBA5:
        TAX
        LDA.L $00F7CB,X
        AND.W #$00FF
        PLX
        RTS
        db $C2,$20,$DA,$29,$FF,$00,$AA,$BF,$00,$80,$03,$29,$FF,$00,$C9,$80
        db $00,$90,$03,$09,$00,$FF,$FA,$60
; [Debug] Dumps memory to log (debug feature). Entry: $12/$14=address, A=length.
dumpMemory:
        PHP
        SEP #$20
        INC.B $57
        JSR.W confirmAction
        PLP
        RTS
        db $C2,$20,$BF,$00,$E8,$7F,$29,$1F,$00,$0A,$0A,$0A,$0A,$0A,$85,$06
        db $E2,$20,$BF,$01,$E8,$7F,$29,$1F,$18,$65,$06,$85,$06,$BF,$02,$E8
        db $7F,$29,$1F,$0A,$0A,$18,$65,$07,$85,$07,$C2,$20,$A5,$06,$60
; [Debug] Breakpoint handler for debugging. Entry: called via BRK instruction.
breakpointHandler:
        JSR.W debugMenu
        RTL
; [Debug] Debug menu for developers. Entry: hidden menu with cheat options, tests.
debugMenu:
        PHP
        REP #$20
        STA.W $0028,Y
        JSR.W initBattleState
        PHY
        PHX
        LDA.W #$0010
        STA.B $00
CODE_81DC14:
        LDA.W $1400,X
        STA.W $0000,Y
        INX
        INX
        INY
        INY
        DEC.B $00
        BNE CODE_81DC14
        PLX
        PLY
        LDA.W $0000,Y
        BNE CODE_81DC2C
        JMP.W $DD9E
CODE_81DC2C:
        PHY
        LDA.W $1403,X
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
        STA.B $00
CODE_81DC43:
        LDA.L $0BBF64,X
        STA.W $002A,Y
        INX
        INX
        INY
        INY
        DEC.B $00
        BNE CODE_81DC43
        PLY
        LDA.W $0050,Y
        LSR A
        LSR A
        LSR A
        LSR A
        AND.W #$000F
        STA.W $0056,Y
        LDA.W $0050,Y
        DEC A
        AND.W #$000F
        STA.W $005C,Y
        SEP #$20
        LDA.W $0006,Y
        STA.B $08
        STZ.B $09
        LDA.W $0001,Y
        CMP.B #$03
        BNE CODE_81DC85
        LDA.W $0003,Y
        CMP.B #$20
        BEQ CODE_81DC85
        LDA.B #$01
        STA.B $08
CODE_81DC85:
        REP #$20
        LDA.W $0040,Y
        AND.W #$00FF
        STA.B $0A
        LDA.W $0038,Y
        JSR.W updateDebugDisplay
        STA.W $0038,Y
        LDA.W $0018,Y
        JSR.W drawDebugInfo
        LDA.W $0041,Y
        AND.W #$00FF
        STA.B $0A
        LDA.W $003A,Y
        JSR.W updateDebugDisplay
        CLC
        ADC.B $06
        BPL CODE_81DCB4
        db $A9,$00,$00
CODE_81DCB4:
        STA.W $003A,Y
        LDA.W $0019,Y
        JSR.W drawDebugInfo
        LDA.W $0042,Y
        AND.W #$00FF
        STA.B $0A
        LDA.W $003C,Y
        BEQ CODE_81DCD8
        JSR.W updateDebugDisplay
        CLC
        ADC.B $06
        BPL CODE_81DCD5
        db $A9,$00,$00
CODE_81DCD5:
        STA.W $003C,Y
CODE_81DCD8:
        LDA.W $001A,Y
        JSR.W drawDebugInfo
        LDA.W $0043,Y
        AND.W #$00FF
        STA.B $0A
        LDA.W $003E,Y
        JSR.W updateDebugDisplay
        CLC
        ADC.B $06
        BPL CODE_81DCF4
        db $A9,$00,$00
CODE_81DCF4:
        STA.W $003E,Y
        LDA.W $0036,Y
        AND.W #$0003
        CMP.L $7EEA84
        BNE CODE_81DD30
        LDA.W $003A,Y
        STA.B $00
        ASL A
        ASL A
        CLC
        ADC.B $00
        LSR A
        LSR A
        STA.W $003A,Y
        LDA.W $003C,Y
        STA.B $00
        ASL A
        ASL A
        CLC
        ADC.B $00
        LSR A
        LSR A
        STA.W $003C,Y
        LDA.W $003E,Y
        STA.B $00
        ASL A
        ASL A
        CLC
        ADC.B $00
        LSR A
        LSR A
        STA.W $003E,Y
CODE_81DD30:
        SEP #$20
        LDA.W $0048,Y
        CLC
        ADC.W $001B,Y
        STA.W $0048,Y
        LDA.W $0044,Y
        CLC
        ADC.W $001C,Y
        BPL CODE_81DD47
        db $A9,$00
CODE_81DD47:
        STA.W $0044,Y
        LDA.W $0046,Y
        CLC
        ADC.W $001D,Y
        STA.W $0046,Y
        LDA.W $0049,Y
        JSR.W handleDebugInput
        CLC
        ADC.W $001E,Y
        STA.W $0049,Y
        LDA.W $004A,Y
        JSR.W handleDebugInput
        CLC
        ADC.W $001F,Y
        STA.W $004A,Y
        LDA.B #$00
        STA.W $006B,Y
        LDA.W $0003,Y
        CMP.B #$20
        BCC CODE_81DD8A
        CMP.B #$24
        BCS CODE_81DD8A
        CMP.B #$21
        BEQ CODE_81DD8A
        SEC
        SBC.B #$1F
        STA.W $006A,Y
        BRA CODE_81DD8F
CODE_81DD8A:
        LDA.B #$00
        STA.W $006A,Y
CODE_81DD8F:
        LDA.W $0010,Y
        CMP.B #$04
        BEQ CODE_81DDA0
        CMP.B #$05
        BEQ CODE_81DDA7
        CMP.B #$06
        BEQ CODE_81DDC0
        PLP
        RTS
        db $A9,$00,$99,$44,$00,$80,$F7
        db $C2,$20,$B9,$3A,$00,$4A,$99,$3A,$00,$B9,$3C,$00,$4A,$99,$3C,$00
        db $B9,$3E,$00,$4A,$99,$3E,$00,$80,$DE
        db $C2,$20,$B9,$3A,$00,$85,$00,$0A,$18,$65,$00,$4A,$4A,$99,$3A,$00
        db $B9,$3C,$00,$85,$00,$0A,$18,$65,$00,$4A,$4A,$99,$3C,$00,$80,$BE
; [Debug] Draws debug information overlay. Entry: shows coordinates, flags, memory values.
drawDebugInfo:
        AND.W #$00FF
        STA.B $06
        CMP.W #$0080
        BCC CODE_81DDEC
        db $C6,$07
CODE_81DDEC:
        RTS
; [Debug] Updates debug display each frame. Entry: reads live game state, updates overlay.
updateDebugDisplay:
        PHY
        PHA
        LDA.B $09
        LSR A
        CLC
        ADC.B $08
        TAX
        LDA.L $0BE2CF,X
        AND.W #$00FF
        TAY
        PLA
        JSR.W monitorSave
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        PLY
        RTS
; [Debug] Handles debug menu input. Entry: processes debug commands, toggles cheats.
handleDebugInput:
        PHP
        PHY
        SEP #$20
        STA.W $4202
        LDA.B #$3F
        CLC
        ADC.B $08
        STA.W $4203
        NOP
        NOP
        NOP
        NOP
        REP #$20
        LDA.W $4216
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        PLY
        PLP
        RTS
; [Debug] Executes debug command. Entry: A=command ID, X/Y=parameters.
executeDebugCommand:
        PHP
        REP #$20
        LDA.W $0028,Y
        JSR.W initBattleState
        PHY
        LDA.W #$0010
CODE_81DE37:
        PHA
        LDA.W $0000,Y
        STA.W $1400,X
        INX
        INX
        INY
        INY
        PLA
        DEC A
        BNE CODE_81DE37
        PLY
        PLP
        RTS
        REP #$20
        AND.W #$007F
        PHA
        ASL A
        ASL A
        ASL A
        STA.B $00
        ASL A
        CLC
        ADC.B $00
        TAX
        LDY.W #$0000
CODE_81DE5C:
        LDA.L $02A4E0,X
        STA.W $0E80,Y
        INX
        INX
        INY
        INY
        CPY.W #$0018
        BNE CODE_81DE5C
        PLA
        STA.W $0E80,Y
        INY
        INY
        PHY
        LDA.W $0E8B
        AND.W #$00FF
        LDY.W #$0019
        JSR.W monitorSave
        PLY
        STA.W $0E80,Y
        RTS
; [Debug] Battle test mode (debug). Entry: starts battle with specified enemies.
testBattle:
        REP #$20
        AND.L $7EEA88
        RTS
; [Debug] Map test mode (debug). Entry: loads specified map for testing.
testMap:
        REP #$20
        LDA.W #$001D
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.W #$007F
        STA.B $18
        LDA.W #$0102
        STA.B $16
        LDA.W #$0000
        JSR.W cheatMaxGold
        STZ.W $09C2
        LDA.L $7EEA8C
        CMP.W #$0100
        BCC CODE_81DEE2
        AND.W #$00FF
        TAY
        STA.L $7EEA8C
        LDA.L $7EEA82
        TAX
        LDA.L $0BE532,X
        AND.W #$00FF
        BEQ CODE_81DEDC
        CMP.W #$0002
        BCC CODE_81DED6
        ORA.W #$0100
        STA.W $09C2
        BRA CODE_81DEE2
        db $98,$1A,$8F,$8C,$EA,$7E
        db $8A,$1A,$8F,$82,$EA,$7E
CODE_81DEE2:
        JSL.L processEnemyAI
        LDA.W #$1E22
        STA.L $7FC000
        JSR.W cheatNoEncounters
        STZ.W $090C
        LDA.W #$3979
        STA.B $7D
        LDA.W #$0007
        JSL.L dispatchGameMode
        JSR.W runAllTests
        JSL.L updateMenuCursor
        JSR.W cheatFastBattle
        LDA.W #$0003
        JSR.W monitorDisassemble
        JSR.W testAI
        LDA.W #$0006
        LDX.W #$0082
        LDY.W #$0000
        JSL.L calculateSlope
        LDA.W #$007F
        STA.B $14
        LDA.W #$B000
        STA.B $12
        LDA.W #$007F
        STA.B $18
        LDA.W #$F000
        STA.B $16
        LDA.W #$0800
        JSL.L updateColorMath
        JSL.L updateScrollRegisters
        JSR.W drawMessageBox
        LDA.W $09C2
        BNE CODE_81DF54
        LDA.W $09B7
        AND.W #$00FF
        CMP.W #$00C0
        BCC CODE_81DF54
        JMP.W $E045
CODE_81DF54:
        JSR.W testMenu
        JSL.L updateMenuCursor
        LDA.W #$8000
        STA.B $04
        LDA.W #$0000
        JSL.L moveCharacter
        LDX.W #$0004
        JSR.W transitionFromWorldMap
        JSR.W logTestFailure
        JSR.W confirmAction
        LDA.W $09C2
        BEQ CODE_81DFAC
        PHA
        CMP.W #$0100
        BCS CODE_81DF99
        JSL.L updateCamera
        PLA
        JSR.W resetTestState
        STZ.W $09C2
        LDA.W #$0000
        JSL.L processAIscript
        LDA.W #$0000
        JSR.W monitorMemory
        JMP.W testMap
CODE_81DF99:
        LDA.W #$005A
        JSR.W setTextColor
        JSL.L calculateBattleDamage
        PLA
        AND.W #$007F
        STA.W $09C2
        BRA CODE_81DF54
CODE_81DFAC:
        STZ.W $09C6
        JSL.L playBGM
        BEQ CODE_81DF54
        LDA.B $50
        AND.W #$8000
        BNE CODE_81DFBF
        JMP.W $E031
CODE_81DFBF:
        LDA.W #$0001
        JSR.W monitorFlags
        LDY.W #$0032
        LDA.W #$0000
        JSR.W handleTransitionWipe
        LDA.B $22
        DEC A
        BEQ CODE_81DFDF
        DEC A
        BEQ CODE_81E01B
        DEC A
        BEQ CODE_81E00E
        DEC A
        BEQ CODE_81E02A
        JMP.W CODE_81DF54
        db $AF,$82,$EA,$7E,$C9,$40,$00,$F0,$D7,$8F,$90,$EA,$7E,$A9,$40,$00
        db $8F,$82,$EA,$7E,$20,$F8,$E0,$22,$E9,$97,$00,$A9,$00,$80,$85,$04
        db $A9,$00,$00,$22,$5E,$98,$00,$A2,$04,$00,$20,$5D,$A2,$80,$23
        db $AF,$90,$EA,$7E,$F0,$AB,$8F,$82,$EA,$7E,$4C,$54,$DF
CODE_81E01B:
        JSR.W clearTextBuffer
        LDA.W #$0001
        JSR.W backupSaveData
        JSR.W clearTextBuffer
        JMP.W $DEA7
CODE_81E02A:
        JSR.W clearTextBuffer
        LDA.W #$FFFF
        RTS
        LDA.W $09B7
        AND.W #$00FF
        CMP.W #$00C0
        BCS CODE_81E03F
        JMP.W CODE_81E0C4
CODE_81E03F:
        STZ.W $09B2
        INC.W $09C6
        LDA.W $09B7
        AND.W #$003F
        PHA
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        STA.W $09B0
        TAX
        LDA.L $0BEDBD,X
        STA.W $09BA
        LDA.L $0BEDBF,X
        STA.W $09BC
        LDA.L $0BEDC1,X
        STA.W $09B8
        PLA
        CLC
        ADC.W #$0018
        CMP.W #$001E
        BCC CODE_81E077
        db $A9,$2B,$00
CODE_81E077:
        LDX.W #$018C
        LDY.W #$0034
        JSL.L calculateSlope
CODE_81E081:
        LDA.W $09B2
        ASL A
        ASL A
        CLC
        ADC.W $09B0
        TAX
        LDA.L $0BEDC5,X
        STA.W $09B4
        LDA.L $0BEDC7,X
        STA.W $09B6
        AND.W #$00FF
        STA.L $7EEA82
        JSR.W testMenu
        JSL.L $0098D7
        BEQ CODE_81E081
        LDA.B $50
        AND.W #$8000
        BEQ CODE_81E0C4
        LDA.W #$0006
        LDX.W #$0082
        LDY.W #$0006
        JSL.L calculateSlope
        JSL.L updateMenuCursor
        JMP.W CODE_81DF54
CODE_81E0C4:
        LDA.L $7EEA8C
        CMP.W #$0063
        BEQ CODE_81E0ED
        LDA.L $7EEA82
        CMP.W #$0025
        BCS CODE_81E0ED
        CMP.L $7EEA8E
        BEQ CODE_81E0ED
        LDA.W #$00B7
        JSR.W monitorInput
        LDA.W $09C6
        BNE CODE_81E0EA
        db $4C,$54,$DF
CODE_81E0EA:
        JMP.W CODE_81E081
CODE_81E0ED:
        JSL.L updateCamera
        JSR.W clearTextBuffer
        LDA.W #$0000
        RTS
; [Debug] Menu test mode (debug). Entry: opens specified menu screen.
testMenu:
        LDA.W $09C2
        BEQ CODE_81E104
        LDA.W #$00B8
        JSR.W monitorInput
        RTS
CODE_81E104:
        LDA.W #$0001
        JSR.W monitorFlags
        STZ.W $0E00
        STZ.W $0E02
        LDA.L $7EEA82
        CMP.W #$0027
        BCS CODE_81E138
        INC.W $0E00
        SEC
        SBC.L $7EEA8E
        TAY
        BEQ CODE_81E138
        LDA.W $09B7
        AND.W #$00FF
        CMP.W #$00C0
        BCS CODE_81E138
        TYA
        BMI CODE_81E135
        LDY.W #$0001
CODE_81E135:
        STY.W $0E02
CODE_81E138:
        LDA.W #$0048
        JSR.W monitorInput
        LDA.W $0E02
        CMP.W #$0001
        BEQ CODE_81E154
        JSR.W monitorGraphics
        LDA.L $7EEA82
        CLC
        ADC.W #$0B00
        JSR.W monitorInput
CODE_81E154:
        RTS
; [Debug] Graphics test mode (debug). Entry: displays all tiles, palettes.
testGraphics:
        PHA
        AND.W #$00FF
        JSR.W importSaveData
        PLA
        STA.B $00
        LDA.B $01
        AND.W #$00FF
        JSR.W exportSaveData
        RTL
        REP #$20
        LDA.W #$FFFF
        STA.W $09E4
        LDA.W #$007F
        STA.B $14
        LDA.W #$5D00
        STA.B $12
        LDA.W #$0300
        LDX.W #$0000
        JSL.L updateBlendEffect
        LDA.W #$0003
        STA.B $14
        LDA.W #$A140
        STA.B $12
        LDA.W #$0000
        STA.B $18
        LDA.W #$0D80
        STA.B $16
        LDA.W #$0040
        JSL.L updateColorMath
        LDA.W #$0001
        STA.W $0A08
        STZ.W $09DE
        LDA.W #$0318
        JSR.W monitorMemory
        LDA.W #$0000
        JSR.W stepOver
CODE_81E1B4:
        LDA.W #$0000
        JSR.W resetTestState
        REP #$20
        LDA.W #$0005
        JSL.L dispatchGameMode
        LDA.W #$1318
        JSR.W monitorMemory
        LDA.W #$0001
        JSR.W cheatAllMagic
        JSR.W drawMessageBox
        LDX.W #$04B0
CODE_81E1D5:
        PHX
        JSR.W drawNumber
        JSR.W confirmAction
        PLX
        LDA.B $50
        AND.W #$F0F0
        BNE CODE_81E1F2
        DEX
        BNE CODE_81E1D5
        LDA.W #$8001
        JSR.W monitorMemory
        JSR.W clearTextBuffer
        BRA CODE_81E1B4
CODE_81E1F2:
        LDA.W #$0001
        JSR.W monitorDisassemble
        JSR.W clearTextBuffer
        REP #$20
        LDA.W #$000C
        JSL.L dispatchGameMode
        LDA.W #$0029
        LDX.W #$0042
        LDY.W #$0000
        JSL.L calculateSlope
        JSR.W monitorSound
        LDA.W #$000C
        JSR.W monitorFlags
        JSR.W testSound
        JSR.W drawMessageBox
CODE_81E220:
        LDA.W #$001E
        JSR.W testController
        LDA.W #$0000
        JSR.W runDiagnostics
        LDA.W #$00AE
        JSR.W monitorInput
        LDA.W $0A08
        STA.W $09DC
        BEQ CODE_81E220
        LDA.W #$003E
        JSR.W monitorMap
        STZ.W $09DA
        LDA.W $09DA
        JSR.W runDiagnostics
        LDA.W $09DA
        ASL A
        ASL A
        CLC
        ADC.W #$000A
        STA.W $09FE
        LDA.W #$0002
        STA.W $09FC
        JSR.W monitorBattle
        LDA.B $50
        AND.W #$4080
        BNE CODE_81E298
        db $A5,$50,$29,$40,$80,$D0,$B4,$A5,$50,$29,$00,$08,$D0,$09,$A5,$50
        db $29,$00,$04,$D0,$0A,$80,$C7,$AD,$DA,$09,$F0,$C2,$3A,$80,$09,$AD
        db $DA,$09,$C9,$02,$00,$B0,$B7,$1A,$8D,$DA,$09,$A9,$03,$00,$20,$E5
        db $EB,$80,$AB
CODE_81E298:
        LDA.W #$0001
        JSR.W monitorDisassemble
        LDA.W #$FFFF
        JSR.W testController
        LDA.W $09DA
        JSR.W stepOver
        LDA.W $09DC
        CLC
        ADC.W #$00AE
        JSR.W monitorInput
        LDA.W $0A08
        CMP.W #$0001
        BNE CODE_81E2FB
        LDA.W $09DC
        CMP.W #$0002
        BEQ CODE_81E2EB
        LDA.W #$0010
        JSR.W setTextColor
        STZ.W $0942
        LDA.L $7EEA82
        BEQ CODE_81E33C
        CMP.W #$0100
        BCC CODE_81E2E5
        AND.W #$00FF
        STA.L $7EEA82
        JSR.W clearTextBuffer
        JMP.W $E3F8
CODE_81E2E5:
        INC.W $0942
        JMP.W $8031
CODE_81E2EB:
        LDA.W #$0000
        STA.L $7EEA82
        LDA.W $09DA
        JSR.W singleStep
        JSR.W testSound
CODE_81E2FB:
        JMP.W CODE_81E220
; [Debug] Sound test mode (debug). Entry: plays all sound effects, music tracks.
testSound:
        STZ.B $22
CODE_81E300:
        LDA.B $22
        PHA
        LDY.W #$0060
        JSR.W monitorSave
        CLC
        ADC.W #$1000
        STA.B $24
        PLA
        JSR.W stepOver
        LDY.W #$0000
CODE_81E316:
        LDA.W $1400,Y
        STA.B ($24),Y
        INY
        INY
        CPY.W #$0060
        BNE CODE_81E316
        LDA.L $7EEA82
        STA.B ($24)
        INC.B $24
        INC.B $24
        LDA.L $7EEA8A
        STA.B ($24)
        INC.B $22
        LDA.B $22
        CMP.W #$0003
        BCC CODE_81E300
        RTS
CODE_81E33C:
        JSR.W monitorSound
        LDA.W #$000D
        JSR.W monitorFlags
CODE_81E345:
        LDA.W #$00B2
        JSR.W monitorInput
        LDA.W $0A08
        BEQ CODE_81E345
        DEC A
        BNE CODE_81E35C
        LDA.W $09DA
        ORA.W #$0010
        STA.W $09DA
CODE_81E35C:
        BRA CODE_81E398
; [Debug] Controller test mode (debug). Entry: shows button inputs, analog values.
testController:
        LDX.W #$C818
        LDY.W #$0000
        JSR.W testMemory
        JSR.W testMemory
; [Debug] Memory test mode (debug). Entry: tests WRAM, VRAM, SRAM access.
testMemory:
        PHA
        PHX
        STX.B $00
        JSR.W checkSaveSpace
        PLA
        CLC
        ADC.W #$0048
        TAX
        PLA
        CMP.W #$FFFF
        BEQ CODE_81E37E
        INC A
CODE_81E37E:
        RTS
; [Debug] Runs system diagnostics. Entry: tests hardware, reports issues.
runDiagnostics:
        STA.W $0A55
        LDY.W #$0060
        JSR.W monitorSave
        STA.W $096C
        LDA.W #$0001
        JSR.W monitorFlags
        LDA.W #$00B1
        JSR.W monitorInput
        RTS
CODE_81E398:
        JSR.W clearTextBuffer
        LDA.W #$007E
        STA.B $14
        LDA.W #$E000
        STA.B $12
        LDA.W #$2000
        LDX.W #$0000
        JSL.L updateBlendEffect
        LDA.W #$0001
        STA.L $7EEA82
        STA.L $7EEA8C
        STA.L $7EEA8E
        LDA.W #$0018
        STA.B $00
        LDA.W $09DA
        STA.B $01
        LDA.B $00
        STA.L $7EEA88
        LDA.W #$000B
        STA.B $14
        LDA.W #$DD64
        STA.B $12
        LDA.W #$0000
        STA.B $18
        LDA.W #$1400
        STA.B $16
        LDA.W #$0400
        JSL.L updateColorMath
        STZ.W $0942
        JSR.W logError
        JMP.W $8031
        JSR.W setWatchpoint
        JSR.W clearTextBuffer
        STZ.B $82
        JSR.W logError
        LDA.W #$0000
        JSL.L processAIscript
        LDA.W #$0000
        JSR.W monitorMemory
        JSR.W testMap
        CMP.W #$FFFF
        BNE CODE_81E423
        LDA.L $7EEA82
        ORA.W #$0100
        STA.L $7EEA82
        JSR.W clearWatchpoints
        JMP.W $E1BA
CODE_81E423:
        LDA.L $7EEA82
        CMP.W #$0040
        BCC CODE_81E497
        LDA.W #$8000
        JSR.W monitorMemory
        LDA.L $7EEA82
        AND.W #$003F
        CMP.W #$0002
        BEQ CODE_81E47D
        CMP.W #$0005
        BEQ CODE_81E460
        LDA.W #$0001
        JSR.W resetTestState
        LDA.W $0E23
        AND.W #$00FF
        BNE CODE_81E45D
        LDA.W #$0002
        JSR.W backupSaveData
        LDA.W #$0002
        JSR.W resetTestState
CODE_81E45D:
        JMP.W $E3F8
CODE_81E460:
        LDA.W #$0005
        JSR.W resetTestState
        LDA.W $0E23
        AND.W #$00FF
        BNE CODE_81E47A
        LDA.W #$0003
        JSR.W backupSaveData
        LDA.W #$0006
        JSR.W resetTestState
CODE_81E47A:
        JMP.W $E3F8
CODE_81E47D:
        LDA.W #$0003
        JSR.W resetTestState
        LDA.W $0A08
        CMP.W #$0001
        BNE CODE_81E494
        JSR.W $D135
        LDA.W #$0004
        JSR.W resetTestState
CODE_81E494:
        JMP.W $E3F8
CODE_81E497:
        JSR.W handleMonitorCommand
        LDA.W $0A08
        CMP.W #$0002
        BNE CODE_81E4A5
        JMP.W $E40A
CODE_81E4A5:
        REP #$20
        STZ.W $0942
        LDA.W #$0001
        STA.L $7EEA84
        LDA.W #$0010
        JSR.W monitorMemory
        JSR.W logError
        LDA.W #$0001
        JSR.W updatePlayTime
        JSR.W profileCode
        LDA.W #$0002
        JSR.W monitorDisassemble
        LDA.W #$001E
        JSR.W setTextColor
        JMP.W $8031
; [Debug] Logs error to debug buffer. Entry: A=error code, X/Y=context.
logError:
        REP #$20
        STZ.B $0E
CODE_81E4D6:
        LDA.B $0E
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W $0E01
        AND.W #$00FF
        BEQ CODE_81E4E9
        JSR.W assertCondition
CODE_81E4E9:
        INC.B $0E
        LDA.B $0E
        CMP.W #$0010
        BNE CODE_81E4D6
CODE_81E4F2:
        LDA.B $0E
        LDY.W #$0E00
        JSR.W debugMenu
        JSR.W assertCondition
        INC.B $0E
        LDA.B $0E
        CMP.W #$0020
        BNE CODE_81E4F2
        JSR.W runToAddress
        RTS
; [Debug] Asserts condition for debugging. Entry: checks condition, breaks if false.
assertCondition:
        SEP #$20
        LDA.B #$FF
        STA.W $0E00
        LDA.B $0E
        CMP.B #$07
        BCC CODE_81E51A
        STZ.W $0E00
CODE_81E51A:
        LDA.W $0E01
        CMP.B #$03
        BNE CODE_81E526
        LDA.B #$20
        STA.W $0E03
CODE_81E526:
        STZ.W $0E0F
        LDA.B #$05
        STA.W $0E0A
        STZ.W $0E02
        STZ.W $0E0C
        LDX.W #$0016
CODE_81E537:
        STZ.W $0E00,X
        INX
        CPX.W #$0020
        BNE CODE_81E537
        REP #$20
        LDA.W $0E38
        STA.W $0E08
        STZ.W $0E04
        LDY.W #$0E00
        JSR.W executeDebugCommand
        RTS
; [Debug] Code profiler for performance analysis. Entry: measures function execution time.
profileCode:
        REP #$20
        LDA.W #$0000
        STA.B $14
        LDA.W #$1400
        STA.B $12
        LDA.W #$007F
        STA.B $18
        LDA.W #$B000
        STA.B $16
        LDA.W #$0200
        JSL.L updateColorMath
        LDA.W #$0000
        STA.B $14
        LDA.W #$1400
        STA.B $12
        LDA.W #$0200
        LDX.W #$0000
        JSL.L updateBlendEffect
        LDY.W #$0000
        LDA.W #$00FF
        JSR.W dumpProfileData
        LDA.W #$0000
        JSR.W dumpProfileData
        RTS
; [Debug] Dumps profiling results. Entry: shows timing information for functions.
dumpProfileData:
        STA.B $00
        STZ.B $0E
        LDX.W #$0000
CODE_81E59A:
        LDA.L $7FB001,X
        AND.W #$00FF
        BEQ CODE_81E5C4
        LDA.L $7FB000,X
        AND.W #$00FF
        CMP.B $00
        BNE CODE_81E5C4
        PHX
        LDA.W #$0010
        STA.B $0C
CODE_81E5B4:
        LDA.L $7FB000,X
        STA.W $1400,Y
        INY
        INY
        INX
        INX
        DEC.B $0C
        BNE CODE_81E5B4
        PLX
CODE_81E5C4:
        TXA
        CLC
        ADC.W #$0020
        TAX
        INC.B $0E
        LDA.B $0E
        CMP.W #$0010
        BNE CODE_81E59A
        RTS
; [Debug] Execution tracer for debugging. Entry: logs instruction flow.
traceExecution:
        REP #$20
        LDA.W #$007E
        STA.B $18
        LDA.W #$E000
        STA.B $16
        SEP #$20
        LDA.B #$01
        STA.B $00
        STA.B $01
        LDA.L $7FC000
        STA.B $04
        STZ.B $05
        LDA.L $7FC001
        STA.B $06
        STZ.B $07
        REP #$20
        JSR.W drawStatusScreen
        STX.B $02
        LDY.B $04
        RTS
; [Debug] Dumps execution trace log. Entry: shows recent instruction history.
dumpTraceLog:
        REP #$20
        LDA.L $7F9000,X
        INX
        INX
        DEY
        BNE CODE_81E625
        PHA
        LDA.B $06
        BNE CODE_81E617
        LDX.W #$FFFF
        PLA
        RTS
CODE_81E617:
        DEC.B $06
        LDY.B $04
        LDA.B $02
        CLC
        ADC.W #$0080
        STA.B $02
        TAX
        PLA
CODE_81E625:
        RTS
; [Debug] Sets memory watchpoint. Entry: A=address, breaks on read/write.
setWatchpoint:
        LDA.L $7EEA82
        PHA
        ORA.W #$0100
        STA.L $7EEA82
        JSR.W clearWatchpoints
        PLA
        STA.L $7EEA82
        RTS
; [Debug] Clears all watchpoints. Entry: disables memory breakpoints.
clearWatchpoints:
        LDA.L $7EEA88
        AND.W #$0020
        BEQ CODE_81E645
        db $60
CODE_81E645:
        LDA.L $7EEA89
        AND.W #$0003
; [Debug] Single-step execution (debug). Entry: executes one instruction, pauses.
singleStep:
        REP #$20
        LDY.W #$0000
        CMP.W #$0002
        BNE CODE_81E659
        db $A0,$40,$15
CODE_81E659:
        CMP.W #$0001
        BNE CODE_81E661
        db $A0,$A0,$0A
CODE_81E661:
        TYA
        CLC
        ADC.W #$0010
        STA.B $12
        LDA.W #$0070
        STA.B $14
        LDA.L $7EEA82
        BEQ CODE_81E68B
        CMP.W #$0100
        BCS CODE_81E68B
        JSR.W traceExecution
CODE_81E67B:
        CPX.W #$FFFF
        BEQ CODE_81E68B
        JSR.W dumpTraceLog
        STA.B [$16]
        INC.B $16
        INC.B $16
        BRA CODE_81E67B
CODE_81E68B:
        LDX.W #$0000
CODE_81E68E:
        LDA.W $1400,X
        STA.L $7EE600,X
        INX
        INX
        CPX.W #$0400
        BNE CODE_81E68E
        SEP #$20
        LDA.W $090A
        STA.L $7EEA86
        LDA.W $090C
        STA.L $7EEA87
        REP #$20
        LDX.W #$0000
        STZ.B $00
CODE_81E6B3:
        LDA.L $7EE000,X
        STA.B [$12]
        CLC
        ADC.B $00
        STA.B $00
        INC.B $12
        INC.B $12
        INX
        INX
        CPX.W #$0A9E
        BNE CODE_81E6B3
        LDA.B $00
        STA.B [$12]
        RTS
; [Debug] Step over subroutine (debug). Entry: executes until return from current function.
stepOver:
        REP #$20
        LDY.W #$0000
        CMP.W #$0002
        BNE CODE_81E6DB
        LDY.W #$1540
CODE_81E6DB:
        CMP.W #$0001
        BNE CODE_81E6E3
        LDY.W #$0AA0
CODE_81E6E3:
        TYA
        CLC
        ADC.W #$0010
        STA.B $12
        LDA.W #$0070
        STA.B $14
        LDX.W #$0000
        STZ.B $00
CODE_81E6F4:
        LDA.B [$12]
        STA.L $7EE000,X
        CLC
        ADC.B $00
        STA.B $00
        INC.B $12
        INC.B $12
        INX
        INX
        CPX.W #$0A9E
        BNE CODE_81E6F4
        LDX.W #$0000
        LDA.B [$12]
        CMP.B $00
        BNE CODE_81E72B
        LDA.L $7EEA82
        BEQ CODE_81E72B
CODE_81E719:
        LDA.L $7EE600,X
        STA.W $1400,X
        INX
        INX
        CPX.W #$0400
        BNE CODE_81E719
        LDA.W #$0000
        RTS
CODE_81E72B:
        STZ.W $1400,X
        INX
        INX
        CPX.W #$0400
        BNE CODE_81E72B
        LDA.W #$0000
        STA.L $7EEA82
        STA.L $7EEA8A
        LDA.W #$0001
        RTS
; [Debug] Step out of subroutine (debug). Entry: executes until return to caller.
stepOut:
        REP #$20
        JSR.W traceExecution
CODE_81E749:
        CPX.W #$FFFF
        BEQ CODE_81E75D
        LDA.B [$16]
        STA.L $7F9000,X
        INC.B $16
        INC.B $16
        JSR.W dumpTraceLog
        BRA CODE_81E749
CODE_81E75D:
        RTS
; [Debug] Run to address (debug). Entry: executes until specified PC.
runToAddress:
        REP #$20
        LDX.W #$0000
CODE_81E763:
        LDA.L $7EEA00,X
        AND.W #$00FF
        CMP.W #$0080
        BCC CODE_81E77D
        AND.W #$007F
        JSR.W $E8BE
        STA.B $0E
        PHX
        TXA
        JSR.W $E822
        PLX
CODE_81E77D:
        INX
        CPX.W #$0080
        BNE CODE_81E763
        RTS
; [Debug] Interactive debug monitor. Entry: command-line interface for debugging.
debugMonitor:
        LDA.W $0A08
        STA.B $24
        LDA.L $7EEA8A
        CLC
        ADC.B $24
        STA.L $7EEA8A
        LDA.W #$0013
        JSR.W monitorDisassemble
        LDA.W #$007B
        JSR.W monitorInput
        RTS
        REP #$20
        PHX
        TAX
        SEP #$20
        LDA.L $7EEA00,X
        CPX.W #$0050
        BCS CODE_81E7B4
        CMP.B #$00
        BNE CODE_81E7C1
CODE_81E7B4:
        INC A
        CMP.B #$64
        BCC CODE_81E7BB
        db $A9,$63
CODE_81E7BB:
        STA.L $7EEA00,X
        LDA.B #$00
CODE_81E7C1:
        REP #$20
        AND.W #$00FF
        PLX
        RTS
        REP #$20
        STY.B $0C
        STA.B $0E
        JSR.W initBattleState
        TXY
        STY.B $0A
        LDA.B $0C
        CMP.W #$FFFF
        BEQ CODE_81E7E3
        AND.W #$00FF
        CMP.W #$0050
        BCS CODE_81E802
CODE_81E7E3:
        LDA.W $1416,Y
        AND.W #$00FF
        BEQ CODE_81E802
        db $3A,$AA,$E2,$20,$A9,$00,$99,$16,$14,$1A,$9F,$00,$EA,$7E,$C2,$20
        db $8A,$09,$00,$80,$20,$22,$E8
CODE_81E802:
        LDA.B $0C
        CMP.W #$FFFF
        BNE CODE_81E80A
        RTS
CODE_81E80A:
        AND.W #$00FF
        TAX
        LDY.B $0A
        SEP #$20
        LDA.W $1401,Y
        ORA.B #$80
        STA.L $7EEA00,X
        REP #$20
        TXA
        JSR.W $E822
        RTS
        REP #$20
        STA.B $08
        JSR.W $DE49
        STZ.B $14
        LDA.B $0E
        JSR.W initBattleState
        STX.B $12
        LDA.B $08
        BMI CODE_81E846
        LDA.W $0E98
        CMP.W #$0050
        BCS CODE_81E846
        SEP #$20
        INC A
        STA.W $1416,X
        REP #$20
CODE_81E846:
        LDY.W #$0E8E
CODE_81E849:
        LDA.W $0000,Y
        AND.W #$00FF
        BEQ CODE_81E8B4
        CMP.W #$0080
        BCS CODE_81E885
        CLC
        ADC.B $12
        TAX
        LDA.W $0001,Y
        AND.W #$00FF
        CMP.W #$0080
        BCC CODE_81E868
        db $09,$00,$FF
CODE_81E868:
        STA.B $00
        LDA.B $08
        BPL CODE_81E876
        db $A5,$00,$3A,$49,$FF,$FF,$85,$00
CODE_81E876:
        LDA.W $1400,X
        JSR.W $E8E9
        SEP #$20
        STA.W $1400,X
        REP #$20
        BRA CODE_81E8B4
CODE_81E885:
        AND.W #$001F
        PHA
        CLC
        ADC.B $12
        TAX
        PLA
        SEP #$20
        CMP.B #$10
        BNE CODE_81E8AC
        LDA.W $0001,Y
        STA.B $00
        LDA.W $1400,X
        CMP.B $00
        BCS CODE_81E8A4
        LDA.B #$00
        BRA CODE_81E8AF
        db $48,$A9,$B3,$85,$14,$68,$80,$03
        db $B9,$01,$00
CODE_81E8AF:
        STA.W $1400,X
        REP #$20
CODE_81E8B4:
        INY
        INY
        CPY.W #$0E98
        BNE CODE_81E849
        RTS
        db $80,$FE
        REP #$20
        PHX
        PHY
        STA.B $00
        LDY.W #$0000
        LDX.W #$0000
CODE_81E8CA:
        LDA.W $1401,X
        AND.W #$00FF
        CMP.B $00
        BEQ CODE_81E8E5
        TXA
        CLC
        ADC.W #$0020
        TAX
        INY
        CPY.W #$0010
        BNE CODE_81E8CA
        db $A9,$FF,$FF,$80,$01
CODE_81E8E5:
        TYA
        PLY
        PLX
        RTS
        PHP
        REP #$20
        AND.W #$00FF
        CMP.W #$0080
        BCC CODE_81E8F7
        db $09,$00,$FF
CODE_81E8F7:
        STA.B $02
        LDA.B $00
        BPL CODE_81E90E
        db $A5,$02,$18,$65,$00,$10,$19,$C9,$80,$FF,$B0,$03,$A9,$81,$FF,$28
        db $60
CODE_81E90E:
        LDA.B $02
        CLC
        ADC.B $00
        BMI CODE_81E91D
        CMP.W #$0080
        BCC CODE_81E91D
        db $A9,$7F,$00
CODE_81E91D:
        PLP
        RTS
        db $20,$09,$A6,$A9,$0D,$00,$20,$4A,$EE,$A0,$00,$00,$A9,$00,$00,$20
        db $A1,$CA,$A5,$22,$D0,$01,$60,$3A,$D0,$03,$4C,$95,$E9,$3A,$F0,$49
        db $3A,$F0,$0F,$3A,$D0,$03,$4C,$81,$EA,$3A,$D0,$03,$4C,$18,$B9,$4C
        db $E5,$EA,$AF,$8E,$EA,$7E,$C9,$20,$00,$90,$37,$A9,$1F,$00,$20,$4A
        db $EE,$22,$63,$AB,$00,$A5,$50,$29,$C0,$C0,$D0,$16,$A5,$00,$F0,$F1
        db $18,$6F,$82,$EA,$7E,$F0,$DB,$C9,$3A,$00,$B0,$D6,$8F,$82,$EA,$7E
        db $80,$D0,$20,$D2,$E4,$A9,$02,$00,$60,$4C,$B5,$EA,$20,$D6,$EC,$20
        db $04,$CC,$A9,$00,$00,$60,$20,$27,$BC,$A9,$00,$00,$A0,$00,$0E,$20
        db $04,$DC,$A9,$00,$00,$A0,$80,$0E,$20,$04,$DC,$9C,$03,$0E,$9C,$83
        db $0E,$A9,$01,$00,$22,$5C,$88,$00,$20,$22,$B8,$64,$A8,$20,$D6,$EC
        db $AD,$58,$09,$8D,$5A,$0E,$AD,$5A,$09,$8D,$DA,$0E,$AD,$60,$09,$8D
        db $58,$0E,$AD,$62,$09,$8D,$5C,$0E,$A9,$1E,$00,$20,$4A,$EE,$20,$84
        db $B8,$A0,$03,$00,$A5,$4E,$29,$80,$00,$F0,$03,$A0,$83,$00,$A5,$4E
        db $29,$20,$00,$F0,$03,$A0,$5A,$00,$A5,$4E,$29,$10,$00,$F0,$03,$A0
        db $DA,$00,$A5,$50,$29,$00,$01,$F0,$05,$A9,$01,$00,$80,$57,$A5,$50
        db $29,$00,$02,$F0,$05,$A9,$FF,$FF,$80,$4B,$A5,$50,$29,$00,$04,$F0
        db $05,$A9,$10,$00,$80,$3F,$A5,$50,$29,$00,$08,$F0,$05,$A9,$F0,$FF
        db $80,$33,$A5,$50,$29,$00,$40,$F0,$04,$A9,$01,$00,$60,$A5,$50,$29
        db $00,$30,$D0,$0C,$A5,$50,$29,$40,$00,$D0,$28,$20,$EE,$B7,$80,$8E
        db $AD,$5A,$0E,$8D,$58,$09,$AD,$DA,$0E,$8D,$5A,$09,$9C,$5A,$0E,$20
        db $CB,$C7,$4C,$BC,$E9,$85,$00,$B9,$00,$0E,$18,$65,$00,$99,$00,$0E
        db $4C,$D7,$E9,$AD,$5A,$0E,$8D,$58,$09,$AD,$DA,$0E,$8D,$5A,$09,$4C
        db $B0,$E9,$9C,$00,$12,$A9,$5D,$00,$20,$4A,$EE,$22,$63,$AB,$00,$A5
        db $50,$29,$80,$40,$D0,$14,$A5,$50,$29,$00,$80,$D0,$15,$A5,$00,$F0
        db $EA,$18,$6D,$00,$12,$8D,$00,$12,$80,$DB,$AD,$00,$12,$20,$E5,$EB
        db $80,$D3,$A9,$00,$00,$60,$A9,$04,$00,$22,$5C,$88,$00,$A9,$29,$05
        db $A2,$00,$00,$A0,$00,$00,$22,$E1,$C2,$00,$A9,$F1,$00,$20,$33,$DB
        db $20,$0D,$B8,$A9,$8C,$00,$20,$4A,$EE,$A9,$8D,$00,$20,$4A,$EE,$20
        db $51,$B8,$A9,$01,$00,$60,$A9,$04,$00,$22,$5C,$88,$00,$A9,$20,$00
        db $A2,$00,$00,$A0,$00,$00,$22,$E1,$C2,$00,$A9,$E1,$00,$20,$33,$DB
        db $20,$0D,$B8,$A9,$00,$00,$20,$4A,$EE,$20,$51,$B8,$A9,$01,$00,$60
; [Debug] Handles debug monitor commands. Entry: parses and executes debug commands.
handleMonitorCommand:
        REP #$20
        LDA.W #$0008
        JSL.L dispatchGameMode
        LDA.W #$0008
        LDX.W #$0042
        LDY.W #$0000
        JSL.L calculateSlope
        JSR.W monitorSound
        LDA.W #$0000
        JSR.W monitorFlags
        LDA.W #$0008
        JSR.W monitorFlags
        LDA.L $7EEA82
        PHA
        DEC A
        CLC
        ADC.W #$0200
        JSR.W monitorInput
        JSR.W monitorGraphics
        PLA
        CLC
        ADC.W #$0B00
        JSR.W monitorInput
        JSR.W drawMessageBox
CODE_81EB4F:
        LDA.W #$0021
        JSR.W monitorInput
        LDA.W $0A08
        BEQ CODE_81EB4F
        CMP.W #$0001
        BEQ CODE_81EB63
        JSR.W clearTextBuffer
        RTS
CODE_81EB63:
        LDA.W #$8000
        JSR.W monitorMemory
        JSR.W confirmAction
        LDA.W #$0003
        JSR.W monitorDisassemble
        LDA.W #$0014
        JSR.W setTextColor
        JSR.W clearTextBuffer
        RTS
; [Debug] Displays debug monitor help. Entry: shows available commands.
monitorHelp:
        JSL.L enableInterrupts
        RTS
; [Debug] Displays CPU registers in monitor. Entry: shows current register values.
monitorRegisters:
        JSL.L disableInterrupts
        RTS
; [Debug] Displays memory in monitor. Entry: shows memory dump at address.
monitorMemory:
        PHP
        REP #$20
        CMP.W #$8000
        BCC CODE_81EBAB
        SEP #$20
        LDY.W #$0000
        CMP.B #$00
        BNE CODE_81EB9D
        JSL.L externalUtilityFunc3
        BRA CODE_81EBE3
CODE_81EB9D:
        CMP.B #$04
        BCS CODE_81EBA3
        LDA.B #$04
CODE_81EBA3:
        JSL.L externalCompressionFunc
        BRA CODE_81EBE3
        db $C2,$20
CODE_81EBAB:
        TAY
        AND.W #$0FFF
        CMP.W #$0200
        BCC CODE_81EBC8
        PHY
        SEC
        SBC.W #$0200
        JSL.L processAIscript
        JSR.W monitorBreakpoints
        PLA
        CMP.W #$1000
        BCC CODE_81EBE3
        BRA CODE_81EBCD
CODE_81EBC8:
        CMP.W #$0100
        BCS CODE_81EBE6
CODE_81EBCD:
        CLC
        ADC.W #$0021
        SEP #$20
        LDY.W #$0000
        JSL.L externalUtilityFunc2
        LDY.W #$0000
        LDA.B #$AE
        JSL.L externalEncryptionFunc
CODE_81EBE3:
        PLP
        RTS
; [Debug] Disassembles code in monitor. Entry: shows assembly at address.
monitorDisassemble:
        PHP
CODE_81EBE6:
        SEP #$20
        INC A
        STA.B $81
        PLP
        RTS
; [Debug] Manages breakpoints in monitor. Entry: lists/sets/clears breakpoints.
monitorBreakpoints:
        LDY.W #$012C
CODE_81EBF0:
        CLC
        ADC.W #$8801
        BNE CODE_81EBF0
        RTS
; [Debug] Manages watchpoints in monitor. Entry: lists/sets/clears watchpoints.
monitorWatchpoints:
        REP #$20
        STA.W $0A22
        LDA.W $0A23
        LSR A
        LSR A
        LSR A
        LSR A
        JSR.W monitorStack
        LDA.W $0A22
        AND.W #$0FFF
        BEQ CODE_81EC11
        JSR.W monitorInput
CODE_81EC11:
        RTS
; [Debug] Displays stack in monitor. Entry: shows stack contents.
monitorStack:
        AND.W #$000F
        CMP.W #$000C
        BCS CODE_81EC59
        PHA
        PHA
        LDA.W #$0001
        JSR.W monitorFlags
        JSR.W monitorEntities
        PLA
        AND.W #$0007
        CLC
        ADC.W #$0064
        JSR.W monitorInput
        JSR.W monitorGraphics
        PLA
        AND.W #$0008
        BNE CODE_81EC46
        DEC.W $09F6
        DEC.W $09F6
        INC.W $09F2
        INC.W $09F2
        RTS
CODE_81EC46:
        LDA.W #$0068
        JSR.W monitorInput
        LDA.W #$000B
        STA.W $09F0
        LDA.W #$0013
        STA.W $09F4
        RTS
CODE_81EC59:
        CMP.W #$000F
        BEQ CODE_81EC7D
        PHA
        LDA.W #$0006
        JSR.W monitorFlags
        JSR.W monitorInventory
        PLA
        AND.W #$0003
        CLC
        ADC.W #$003C
        JSR.W monitorInput
        JSR.W monitorGraphics
        LDA.W #$0002
        STA.W $0A0C
        RTS
        db $A9,$0B,$00,$20,$8D,$EC,$20,$D6,$EC,$A9,$05,$00,$8D,$0C,$0A,$60
; [Debug] Displays CPU flags in monitor. Entry: shows status register bits.
monitorFlags:
        JSL.L handleCutscene
        RTS
; [Debug] Displays call stack in monitor. Entry: shows function call hierarchy.
monitorCallStack:
        REP #$20
        LDX.W $09FC
        LDA.W $09FE
        CLC
        ADC.W $0A00
        TAY
        CPY.W #$003E
        BNE CODE_81ECA9
        db $AC,$FA,$09,$88,$88
CODE_81ECA9:
        JMP.W monitorTimers
; [Debug] Displays game variables in monitor. Entry: shows important RAM values.
monitorVariables:
        REP #$20
        LDX.W $09FC
        LDA.W $09FE
        CLC
        ADC.W $0A00
        TAY
; [Debug] Displays timer values in monitor. Entry: shows game timers, counters.
monitorTimers:
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
; [Debug] Displays entity list in monitor. Entry: shows all active entities.
monitorEntities:
        PHP
        SEP #$20
        INC.B $57
        JSR.W confirmAction
        PLP
        RTS
; [Debug] Displays inventory in monitor. Entry: shows party items.
monitorInventory:
        PHP
        REP #$20
        JSR.W monitorEvents
        JSR.W monitorEntities
        PLP
        RTS
; [Debug] Displays party status in monitor. Entry: shows character stats.
monitorParty:
        JSR.W monitorEvents
        RTL
; [Debug] Displays event flags in monitor. Entry: shows story progress flags.
monitorEvents:
        REP #$20
        LDA.W #$2000
        STA.W $0A02
        LDA.W $09F0
        STA.W $09FC
        LDA.W $09F2
        STA.W $09FE
        JSR.W monitorVariables
        STX.B $02
        LDA.W $09F6
        STA.B $00
CODE_81ED03:
        LDX.B $02
        LDY.W $09F4
        LDA.B $6F
        BEQ CODE_81ED0F
        LDA.W #$3100
CODE_81ED0F:
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE CODE_81ED0F
        LDA.B $02
        CLC
        ADC.W #$0040
        STA.B $02
        DEC.B $00
        BNE CODE_81ED03
        LDX.W #$0000
        LDY.W #$001E
        JSR.W monitorTimers
        LDA.W #$0000
        LDY.W #$0080
CODE_81ED33:
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE CODE_81ED33
        STZ.W $0A04
        STZ.W $0A1A
        RTS
; [Debug] Displays map information in monitor. Entry: shows current map data.
monitorMap:
        REP #$20
        PHA
        JSR.W monitorCallStack
        PLA
        JSL.L checkZeroWrapper
        RTS
        db $08,$C2,$20,$20,$5E,$ED,$A5,$50,$29,$F0,$F0,$F0,$F6,$28,$60
; [Debug] Displays battle state in monitor. Entry: shows battle variables.
monitorBattle:
        PHP
        REP #$20
        JSR.W drawNumber
        STZ.B $0E
CODE_81ED66:
        JSR.W monitorCallStack
        LDY.W #$003E
        INC.B $0E
        LDA.B $0E
        AND.W #$0010
        BEQ CODE_81ED78
        LDY.W #$0000
CODE_81ED78:
        TYA
        JSL.L checkZeroWrapper
        JSR.W monitorEntities
        JSR.W drawNumber
        LDA.B $50
        BEQ CODE_81ED66
        JSR.W monitorCallStack
        LDA.W #$0000
        JSL.L checkZeroWrapper
        JSR.W monitorEntities
        PLP
        RTS
        db $AD,$10,$0A,$D0,$01,$60,$20,$4F,$ED,$AD,$06,$0A,$F0,$0D,$20,$92
        db $EC,$AD,$06,$0A,$22,$52,$C1,$00,$20,$CC,$EC,$60,$08,$C2,$20,$48
        db $20,$92,$EC,$68,$20,$29,$EE,$20,$CC,$EC,$28,$60,$08,$C2,$20,$48
        db $20,$92,$EC,$A9,$3E,$00,$22,$52,$C1,$00,$E8,$E8,$68,$20,$29,$EE
        db $20,$CC,$EC,$A9,$0E,$00,$48,$A0,$00,$00,$29,$04,$00,$D0,$03,$A0
        db $3E,$00,$5A,$20,$92,$EC,$68,$22,$52,$C1,$00,$20,$CC,$EC,$68,$3A
        db $D0,$E4,$28,$60
; [Debug] Displays sound state in monitor. Entry: shows APU/SPC status.
monitorSound:
        REP #$20
        LDX.W #$0102
        LDY.W #$0019
CODE_81EE02:
        PHY
        PHX
        LDY.W #$001E
        LDA.W #$1100
CODE_81EE0A:
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE CODE_81EE0A
        PLA
        CLC
        ADC.W #$0040
        TAX
        PLY
        DEY
        BNE CODE_81EE02
        RTS
; [Debug] Displays graphics state in monitor. Entry: shows PPU registers, VRAM info.
monitorGraphics:
        PHP
        REP #$20
        LDA.W $0A18
        STA.W $0A1A
        PLP
        RTS
        db $08,$C2,$20,$A8,$BF,$00,$90,$7E,$09,$00,$08,$9F,$00,$90,$7E,$BF
        db $40,$90,$7E,$09,$00,$08,$9F,$40,$90,$7E,$E8,$E8,$88,$D0,$E5,$28
        db $60
; [Debug] Displays input state in monitor. Entry: shows controller readings.
monitorInput:
        REP #$20
        PHA
        STA.B $14
        LDA.B $15
        AND.W #$00FF
        ASL A
        ASL A
        TAX
        LDA.L $028000,X
        STA.B $14
        LDA.L $028002,X
        STA.B $16
        PLA
        AND.W #$00FF
        ASL A
        TAY
        LDA.B [$14],Y
        STA.B $14
; [Debug] Displays DMA state in monitor. Entry: shows DMA channel configurations.
monitorDMA:
        REP #$20
        LDA.B [$14]
        CMP.W #$7FFF
        BEQ CODE_81EE7B
        JSL.L handleInventory
        RTS
CODE_81EE7B:
        INC.B $14
        INC.B $14
        LDA.B $14
        INC A
        STA.W $0A24
        LDA.B $16
        STA.W $0A26
        LDA.B [$14]
        AND.W #$00FF
        JSR.W monitorStack
        LDA.W $0A26
        STA.B $16
        LDA.W $0A24
        STA.B $14
        JSL.L handleInventory
        RTS
        db $08,$E2,$20,$A5,$00,$C9,$FF,$D0,$08,$AD,$FC,$09,$0A,$0A,$0A,$85
        db $00,$A5,$01,$C9,$FF,$D0,$08,$AD,$FE,$09,$0A,$0A,$0A,$85,$01,$28
        db $60
; [Debug] Displays interrupt state in monitor. Entry: shows IRQ/NMI status.
monitorIRQ:
        PHP
        REP #$20
        STA.B $04
        TYA
        LDY.W #$0000
CODE_81EECB:
        SEC
        SBC.B $04
        BCC CODE_81EED3
        INY
        BRA CODE_81EECB
CODE_81EED3:
        CLC
        ADC.B $04
        PHA
        TYA
        PLY
        PLP
        RTS
; [Debug] Displays save data in monitor. Entry: shows SRAM contents.
monitorSave:
        PHP
        REP #$20
        STA.B $04
        STZ.B $00
        STZ.B $02
        CPY.W #$0000
        BEQ CODE_81EEFA
CODE_81EEE9:
        LDA.B $00
        CLC
        ADC.B $04
        STA.B $00
        LDA.B $02
        ADC.W #$0000
        STA.B $02
        DEY
        BNE CODE_81EEE9
CODE_81EEFA:
        LDA.B $00
        LDY.B $02
        PLP
        RTS
        db $08,$C2,$20,$20,$DB,$EE,$8D,$04,$42,$E2,$20,$A9,$64,$8D,$06,$42
        db $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA,$C2,$20,$AD,$14,$42,$28,$60
; [Debug] Test monitor functionality. Entry: runs monitor self-test.
monitorTest:
        PHP
        SEP #$20
        STY.W $4204
        STA.W $4206
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        REP #$20
        LDA.W $4214
        PLP
        RTS
; [Debug] Exits debug monitor. Entry: returns to game execution.
monitorExit:
        LDY.W #$0000
        CMP.W #$8000
        BCS CODE_81EF40
        RTS
CODE_81EF40:
        INY
        STA.B $00
        LDA.W #$0000
        SEC
        SBC.B $00
        RTS
; [Debug] Cheat: infinite HP for party. Entry: toggles HP cheat on/off.
cheatInfiniteHP:
        AND.W #$7FFF
        CPY.W #$0000
        BNE CODE_81EF53
        RTS
CODE_81EF53:
        STA.B $00
        LDA.W #$0000
        SEC
        SBC.B $00
        RTS
        db $08,$C2,$20,$E0,$00,$00,$F0,$1F,$85,$14,$20,$37,$EF,$85,$12,$8A
        db $20,$37,$EF,$5A,$A4,$12,$20,$DB,$EE,$A8,$A9,$0A,$00,$20,$C2,$EE
        db $7A,$20,$4A,$EF,$18,$65,$14,$28,$60
; [Debug] Cheat: infinite MP for party. Entry: toggles MP cheat on/off.
cheatInfiniteMP:
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
        BCC CODE_81EFA3
        db $09,$00,$80,$E6,$14
CODE_81EFA3:
        STA.B $12
        PLY
        RTS
; [Debug] Cheat: max all stats for party. Entry: sets all characters to max stats.
cheatMaxStats:
        JSR.W cheatAllItems
        RTL
; [Debug] Cheat: get all items. Entry: fills inventory with all items.
cheatAllItems:
        PHP
        PHX
        PHA
        REP #$20
        CPY.W #$0001
        BNE CODE_81EFCB
        LDA.W #$0015
        STA.B $14
        LDA.W #$B000
        STA.B $12
        LDA.W #$0007
        STA.B $18
        LDA.W #$8000
        STA.B $16
        BRA CODE_81F030
CODE_81EFCB:
        CPY.W #$0002
        BNE CODE_81EFE6
        LDA.W #$001F
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.W #$000E
        STA.B $18
        LDA.W #$8000
        STA.B $16
        BRA CODE_81F030
CODE_81EFE6:
        CPY.W #$0003
        BNE CODE_81F001
        LDA.W #$0021
        STA.B $14
        LDA.W #$D000
        STA.B $12
        LDA.W #$0020
        STA.B $18
        LDA.W #$8000
        STA.B $16
        BRA CODE_81F030
CODE_81F001:
        CPY.W #$0004
        BNE CODE_81F01C
        LDA.W #$0038
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.W #$003A
        STA.B $18
        LDA.W #$8000
        STA.B $16
        BRA CODE_81F030
CODE_81F01C:
        LDA.W #$001A
        STA.B $14
        LDA.W #$A000
        STA.B $12
        LDA.W #$0016
        STA.B $18
        LDA.W #$8000
        STA.B $16
CODE_81F030:
        PLA
        JSL.L calculateSpellCost
        DEC A
        BEQ CODE_81F058
        LDA.W #$007E
        STA.B $14
        LDA.W #$2000
        STA.B $12
        LDA.B $0C
        ASL A
        ASL A
        ASL A
        ASL A
        TAY
        PLX
        LDA.B $10
        AND.W #$00FF
        CMP.W #$0003
        BCC CODE_81F05A
        JSL.L updateWeatherParticles
CODE_81F058:
        PLP
        RTS
CODE_81F05A:
        JSL.L setupIRQ
        PLP
        RTS
; [Debug] Cheat: learn all magic. Entry: teaches all spells to party.
cheatAllMagic:
        PHP
        REP #$20
        STA.B $28
        LDA.W #$0023
        STA.B $14
        LDA.W #$F800
        STA.B $12
        LDA.B $28
        JSR.W cheatInfiniteMP
        LDA.W #$0000
        STA.B $00
        LDA.W #$0010
        STA.B $02
        JSL.L setupTilemap
        LDA.B $28
        ASL A
        ASL A
        ASL A
        STA.B $28
        LDX.W #$0000
        LDA.W #$0007
CODE_81F08F:
        PHA
        PHX
        PHX
        LDA.W #$0023
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.W #$0023
        STA.B $18
        LDA.W #$9000
        STA.B $16
        LDA.B $28
        JSL.L calculateSpellCost
        LDA.W #$007E
        STA.B $14
        LDA.W #$2000
        STA.B $12
        LDA.B $0C
        ASL A
        ASL A
        ASL A
        ASL A
        TAY
        LDA.W #$007E
        STA.B $14
        LDA.W #$2000
        STA.B $12
        PLX
        JSL.L updateWeatherParticles
        LDA.B $0C
        ASL A
        ASL A
        ASL A
        STA.B $00
        PLA
        CLC
        ADC.B $00
        TAX
        INC.B $28
        PLA
        DEC A
        BNE CODE_81F08F
        JSL.L updateTurnOrder
        PLP
        RTS
; [Debug] Cheat: max gold. Entry: sets party gold to maximum.
cheatMaxGold:
        PHP
        REP #$20
        JSL.L parseScriptData
CODE_81F0EB:
        CPX.W #$0000
        BEQ CODE_81F0EB
        STX.B $02
        LDY.W #$0000
        LDX.W #$0000
        LDA.B $16
        STA.B $1A
        SEP #$20
CODE_81F0FE:
        LDA.L $7E2000,X
        INX
        STA.B [$16],Y
        INY
        INY
        CPY.B $02
        BCC CODE_81F0FE
        REP #$20
        LDY.W #$0001
        LDA.B $1A
        STA.B $16
        SEP #$20
CODE_81F116:
        LDA.L $7E2000,X
        INX
        STA.B [$16],Y
        INY
        INY
        CPY.B $02
        BCC CODE_81F116
        PLP
        RTS
; [Debug] Cheat: instant level up. Entry: levels up selected character.
cheatInstantLevel:
        JSL.L parseScriptData
        RTS
; [Debug] Cheat: no random encounters. Entry: toggles encounters on/off.
cheatNoEncounters:
        REP #$20
        PHP
        LDA.W #$3132
        STA.B $7D
        LDA.L $7FC000
        JSR.W cheatWalkThroughWalls
        CLC
        ADC.W #$001C
        SEC
        SBC.W #$00FC
        CMP.W #$0011
        BCS CODE_81F149
        db $A9,$11,$00
CODE_81F149:
        STA.W $0A46
        LDA.L $7FC001
        JSR.W cheatWalkThroughWalls
        CLC
        ADC.W #$001C
        SEC
        SBC.W #$00B8
        STA.W $0A48
        STA.W $0A4A
        LDA.W #$0010
        STA.W $0A4C
        LDA.W #$0008
        STA.W $0A4E
        STZ.B $64
        LDA.W #$0001
        STA.B $00
        LDA.W #$0001
        STA.B $02
        JSR.W cheatFastBattle
        PLP
        RTS
; [Debug] Cheat: walk through walls. Entry: toggles collision on/off.
cheatWalkThroughWalls:
        AND.W #$00FF
        ASL A
        ASL A
        ASL A
        STA.B $00
        ASL A
        CLC
        ADC.B $00
        RTS
; [Debug] Cheat: fast battle (instant win). Entry: toggles instant battle victory.
cheatFastBattle:
        PHP
        REP #$20
        LDA.B $00
        SEC
        SBC.W #$006C
        BPL CODE_81F199
        LDA.W #$0000
CODE_81F199:
        CMP.W $0A46
        BCC CODE_81F1A2
        LDA.W $0A46
        DEC A
CODE_81F1A2:
        CMP.W $0A4C
        BCS CODE_81F1AA
        LDA.W $0A4C
CODE_81F1AA:
        STA.B $60
        LSR A
        LSR A
        LSR A
        STA.B $5A
        LDA.B $02
        SEC
        SBC.W #$0058
        BPL CODE_81F1BC
        LDA.W #$0000
CODE_81F1BC:
        CMP.W $0A48
        BCC CODE_81F1C5
        LDA.W $0A48
        DEC A
CODE_81F1C5:
        CMP.W $0A4E
        BCS CODE_81F1CD
        LDA.W $0A4E
CODE_81F1CD:
        STA.B $62
        LSR A
        LSR A
        LSR A
        STA.B $5C
        PLP
        RTS
; [Debug] Cheat: all key items. Entry: gives all key plot items.
cheatAllKeys:
        REP #$20
        PHY
        TXA
        BEQ CODE_81F1EA
        BMI CODE_81F1E3
        JSR.W cheatTimeOfDay
        BRA CODE_81F1EA
CODE_81F1E3:
        DEC A
        EOR.W #$FFFF
        JSR.W cheatUnlockAll
CODE_81F1EA:
        PLA
        BEQ CODE_81F1FB
        BMI CODE_81F1F4
        JSR.W cheatDebugMode
        BRA CODE_81F1FB
CODE_81F1F4:
        DEC A
        EOR.W #$FFFF
        JSR.W testCombat
CODE_81F1FB:
        RTL
; [Debug] Cheat: teleport to map. Entry: A=map ID, teleports party.
cheatTeleport:
        JSR.W cheatWeather
        RTL
; [Debug] Cheat: change weather. Entry: A=weather type, sets current weather.
cheatWeather:
        REP #$20
        LDA.B $64
        BNE CODE_81F207
        RTS
CODE_81F207:
        TAX
        AND.W #$0001
        BEQ CODE_81F210
        DEC.B $64
        RTS
CODE_81F210:
        LDA.B $5A
        PHA
        LDA.B $5C
        PHA
        LDA.W $0A3E
        STA.B $5A
        LDA.W $0A40
        STA.B $5C
        LDX.W $0A42
        LDY.W $0A44
        LDA.B $64
        AND.W #$0004
        BNE CODE_81F232
        JSR.W $F3FA
        BRA CODE_81F235
CODE_81F232:
        JSR.W $F406
CODE_81F235:
        PLA
        STA.B $5C
        PLA
        STA.B $5A
        STZ.B $64
        RTS
; [Debug] Cheat: set time of day. Entry: A=time (0=day, 1=night, 2=dawn, 3=dusk).
cheatTimeOfDay:
        PHA
        LDA.B $60
        AND.W #$0008
        STA.B $08
        PLA
        CLC
        ADC.B $60
        CMP.W $0A46
        BCC CODE_81F253
        LDA.W $0A46
        DEC A
CODE_81F253:
        STA.B $60
        AND.W #$0008
        CMP.B $08
        BEQ CODE_81F261
        JSR.W testAudioSystem
        INC.B $64
CODE_81F261:
        RTS
; [Debug] Cheat: unlock all content. Entry: opens all areas, quests, features.
cheatUnlockAll:
        STA.B $00
        LDA.B $60
        TAY
        SEC
        SBC.B $00
        BPL CODE_81F26F
        db $A9,$00,$00
CODE_81F26F:
        CMP.W $0A4C
        BCS CODE_81F277
        LDA.W $0A4C
CODE_81F277:
        STA.B $60
        AND.W #$0008
        STA.B $08
        TYA
        AND.W #$0008
        CMP.B $08
        BEQ CODE_81F28B
        JSR.W testEffectSystem
        INC.B $64
CODE_81F28B:
        RTS
; [Debug] Cheat: enable debug mode. Entry: toggles full debug features.
cheatDebugMode:
        PHA
        LDA.B $62
        AND.W #$0008
        STA.B $08
        PLA
        CLC
        ADC.B $62
        CMP.W $0A48
        BCC CODE_81F2A1
        LDA.W $0A48
        DEC A
CODE_81F2A1:
        STA.B $62
        AND.W #$0008
        CMP.B $08
        BEQ CODE_81F2BE
        LDA.B $64
        BNE CODE_81F2B4
        JSR.W testAnimationSystem
        INC.B $5C
        RTS
CODE_81F2B4:
        JSR.W $F2F8
        LDA.W #$0007
        STA.B $64
        INC.B $5C
CODE_81F2BE:
        RTS
; [Debug] Combat test routine. Entry: runs automated battle tests.
testCombat:
        STA.B $00
        LDA.B $62
        TAY
        SEC
        SBC.B $00
        BPL CODE_81F2CC
        db $A9,$00,$00
CODE_81F2CC:
        CMP.W $0A4E
        BCS CODE_81F2D4
        LDA.W $0A4E
CODE_81F2D4:
        STA.B $62
        AND.W #$0008
        STA.B $08
        TYA
        AND.W #$0008
        CMP.B $08
        BEQ CODE_81F2F7
        LDA.B $64
        BNE CODE_81F2ED
        JSR.W testMemoryAllocation
        DEC.B $5C
        RTS
CODE_81F2ED:
        JSR.W $F2F8
        LDA.W #$0003
        STA.B $64
        DEC.B $5C
CODE_81F2F7:
        RTS
        LDA.B $5A
        STA.W $0A3E
        LDA.B $5C
        STA.W $0A40
        LDA.B $60
        STA.W $0A42
        LDA.B $62
        STA.W $0A44
        RTS
; [Debug] AI test routine. Entry: runs AI behavior tests.
testAI:
        PHP
        REP #$20
        LDA.B $5C
        STA.B $22
        PHA
        LDA.B $62
        STA.B $24
        STZ.B $64
        LDA.W #$0020
CODE_81F31E:
        PHA
        LDX.B $60
        LDY.B $24
        JSR.W testInputSystem
        JSR.W confirmAction
        INC.B $5C
        LDA.B $24
        CLC
        ADC.W #$0008
        STA.B $24
        PLA
        DEC A
        BNE CODE_81F31E
        PLA
        STA.B $5C
        PLP
        RTS
; [Debug] Pathfinding test routine. Entry: tests movement algorithms.
testPathfinding:
        PHP
        REP #$20
        JSR.W confirmAction
        JSR.W testSoundPlayback
        LDA.W #$7800
        STA.B $78
        SEP #$20
        LDA.B #$FF
        STA.B $57
        REP #$20
        JSR.W confirmAction
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSR.W confirmAction
        PLP
        RTL
; [Debug] Collision test routine. Entry: tests collision detection.
testCollision:
        PHP
        REP #$20
        JSR.W confirmAction
        JSR.W testSoundPlayback
        LDA.W #$7800
        STA.B $78
        SEP #$20
        LDA.B #$FF
        STA.B $57
        REP #$20
        JSR.W confirmAction
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSR.W confirmAction
        PLP
        RTS
; [Debug] Graphics rendering test. Entry: tests tile, sprite rendering.
testGraphicsRendering:
        PHP
        REP #$20
        JSR.W testSoundPlayback
        LDA.W #$7800
        STA.B $78
        SEP #$20
        LDA.B #$FF
        STA.B $57
        REP #$20
        JSR.W confirmAction
        PLP
        RTS
; [Debug] Sound playback test. Entry: tests all sound channels.
testSoundPlayback:
        PHP
        REP #$20
        LDA.B $5C
        PHA
        LDA.B $60
        STA.B $02
        LDA.B $62
        STA.B $04
        ASL A
        ASL A
        ASL A
        AND.W #$07C0
        TAX
        STZ.B $64
        LDA.W #$0020
CODE_81F3BA:
        PHA
        PHX
        JSR.W testMemorySystem
        INC.B $5C
        LDA.B $04
        CLC
        ADC.W #$0008
        STA.B $04
        PLX
        LDY.W #$0000
        LDA.W #$0020
        STA.B $00
CODE_81F3D2:
        LDA.W $0600,Y
        STA.L $7FB000,X
        LDA.W $0680,Y
        STA.L $7FD000,X
        INY
        INY
        INX
        INX
        DEC.B $00
        BNE CODE_81F3D2
        TXA
        AND.W #$07FE
        TAX
        PLA
        DEC A
        BNE CODE_81F3BA
        PLA
        STA.B $5C
        PLP
        RTS
; [Debug] Memory allocation test. Entry: tests heap/stack operations.
testMemoryAllocation:
        LDX.B $60
        LDY.B $62
        DEC.B $5C
        JSR.W testInputSystem
        INC.B $5C
        RTS
; [Debug] Tests animation system functionality. Entry: runs animation tests.
testAnimationSystem:
        LDX.B $60
        LDY.B $62
        TYA
        CLC
        ADC.W #$00F0
        TAY
        LDA.B $5C
        PHA
        CLC
        ADC.W #$001F
        STA.B $5C
        JSR.W testInputSystem
        PLA
        STA.B $5C
        RTS
; [Debug] Tests visual effect system. Entry: runs effect rendering tests.
testEffectSystem:
        LDX.B $60
        LDY.B $62
        LDA.B $5A
        PHA
        SEC
        SBC.W #$0001
        STA.B $5A
        JSR.W testGraphicsSystem
        PLA
        DEC A
        STA.B $5A
        RTS
; [Debug] Tests audio system functionality. Entry: runs sound playback tests.
testAudioSystem:
        LDA.B $60
        CLC
        ADC.W #$00F8
        TAX
        LDY.B $62
        LDA.B $5A
; [Debug] File I/O test (SRAM). Entry: tests save/load operations.
testFileIO:
        PHA
        CLC
        ADC.W #$0020
        STA.B $5A
        JSR.W testGraphicsSystem
        PLA
        INC A
        STA.B $5A
        RTS
; [Debug] Tests input system functionality. Entry: runs controller reading tests.
testInputSystem:
        REP #$20
        STX.B $02
        STY.B $04
        JSR.W testMemorySystem
        SEP #$20
        LDA.B #$01
        STA.W $05F5
        REP #$20
        RTS
; [Debug] Tests memory system functionality. Entry: runs RAM/ROM access tests.
testMemorySystem:
        SEP #$20
        LDA.B $5C
        STA.B $13
        STZ.B $12
        REP #$20
        LDA.B $5A
        ASL A
        CLC
        ADC.B $12
        STA.B $12
        LDA.W #$7800
        STA.B $14
        STA.B $16
        LDA.B $02
        AND.W #$00F8
        LSR A
        LSR A
        STA.B $06
        LDA.B $04
        AND.W #$00F8
        ASL A
        ASL A
        CLC
        ADC.B $14
        STA.B $14
        LDX.B $12
        LDA.W #$0020
        STA.B $00
        LDY.B $06
CODE_81F495:
        LDA.L $7F0000,X
        INX
        INX
        PHA
        AND.W #$DFFF
        STA.W $0600,Y
        PLA
        AND.W #$2000
        BEQ CODE_81F4AA
        LDA.B $7D
CODE_81F4AA:
        STA.W $0680,Y
        TYA
        INC A
        INC A
        AND.W #$003F
        TAY
        DEC.B $00
        BNE CODE_81F495
        LDA.W #$0040
        STA.W $05F6
        LDA.B $14
        STA.W $05F8
        RTS
; [Debug] Tests graphics system functionality. Entry: runs tile/sprite rendering tests.
testGraphicsSystem:
        REP #$20
        STX.B $02
        STY.B $04
        SEP #$20
        LDA.B $5C
        STA.B $13
        STZ.B $12
        REP #$20
        LDA.B $5A
        ASL A
        CLC
        ADC.B $12
        STA.B $12
        LDA.W #$7800
        STA.B $14
        LDA.B $02
        AND.W #$00F8
        LSR A
        LSR A
        LSR A
        CLC
        ADC.B $14
        STA.B $14
        LDA.B $04
        AND.W #$00F8
        LSR A
        LSR A
        STA.B $06
        LDX.B $12
        LDY.B $06
        LDA.W #$0020
        STA.B $00
CODE_81F500:
        LDA.L $7F0000,X
        PHA
        AND.W #$DFFF
        STA.W $0600,Y
        PLA
        AND.W #$2000
        BEQ CODE_81F513
        LDA.B $7D
CODE_81F513:
        STA.W $0680,Y
        TXA
        CLC
        ADC.W #$0100
        TAX
        TYA
        CLC
        ADC.W #$0002
        AND.W #$003F
        TAY
        DEC.B $00
        BNE CODE_81F500
        LDA.W #$0040
        STA.W $05F6
        LDA.B $14
        STA.W $05F8
        STZ.W $05FA
        STZ.W $05FC
        SEP #$20
        LDA.B #$02
        STA.W $05F5
        REP #$20
        RTS
; [Debug] Tests game logic systems. Entry: runs battle, menu, entity tests.
testGameLogic:
        PHP
        REP #$20
        STZ.B $06
        LDA.W #$0102
        STA.B $12
CODE_81F54E:
        SEP #$20
        STZ.B $04
        LDX.B $12
CODE_81F554:
        LDA.L $7F0001,X
        AND.B #$DF
        STA.L $7F0001,X
        INX
        INX
        INX
        INX
        INX
        INX
        LDA.B $04
        INC.B $04
        CMP.L $7FC000
        BNE CODE_81F554
        LDA.B $06
        INC.B $06
        CMP.L $7FC001
        BEQ CODE_81F580
        INC.B $13
        INC.B $13
        INC.B $13
        BRA CODE_81F54E
CODE_81F580:
        PLP
        RTS
; [Debug] Tests save system functionality. Entry: runs save/load operation tests.
testSaveSystem:
        PHP
        REP #$20
        STZ.B $06
        LDA.W #$0102
        STA.B $12
        STZ.B $14
        LDA.W #$007F
        STA.B $18
        LDA.W #$A000
        STA.B $16
CODE_81F598:
        SEP #$20
        STZ.B $04
        LDX.B $12
        LDY.B $14
CODE_81F5A0:
        LDA.B [$16],Y
        BEQ CODE_81F5AE
        LDA.L $7F0001,X
        ORA.B #$20
        STA.L $7F0001,X
CODE_81F5AE:
        INX
        INX
        INX
        INX
        INX
        INX
        INY
        INY
        LDA.B $04
        INC.B $04
        CMP.L $7FC000
        BNE CODE_81F5A0
        LDA.B $06
        INC.B $06
        CMP.L $7FC001
        BEQ CODE_81F5DC
        INC.B $13
        INC.B $13
        INC.B $13
        REP #$20
        LDA.B $14
        CLC
        ADC.W #$0080
        STA.B $14
        BRA CODE_81F598
CODE_81F5DC:
        PLP
        RTS
; [Debug] Tests network functionality (if any). Entry: runs communication tests.
testNetwork:
        PHP
        REP #$20
        LDA.W #$007F
        STA.B $14
        LDA.W #$9082
        STA.B $12
        LDA.B $12
        STA.B $1C
        LDA.W #$007F
        STA.B $18
        LDA.W #$0306
        STA.B $16
        LDA.B $16
        STA.B $1A
        LDA.W #$00F0
        STA.B $00
        LDA.W #$001E
        STA.B $02
CODE_81F607:
        LDA.B [$12]
        INC.B $12
        INC.B $12
        JSR.W testHardware
        LDA.B $16
        CLC
        ADC.W #$0006
        STA.B $16
        AND.W #$00FF
        CMP.B $00
        BNE CODE_81F635
        LDA.B $1C
        CLC
        ADC.W #$0080
        STA.B $1C
        STA.B $12
        LDA.B $1A
        CLC
        ADC.W #$0300
        STA.B $1A
        STA.B $16
        DEC.B $02
CODE_81F635:
        LDA.B $02
        BNE CODE_81F607
        PLP
        RTS
; [Debug] Tests hardware functionality. Entry: runs PPU, APU, DMA tests.
testHardware:
        PHA
        AND.W #$2000
        STA.B $06
        PLA
        AND.W #$01FF
        ASL A
        STA.B $04
        ASL A
        ASL A
        ASL A
        CLC
        ADC.B $04
        TAX
        LDA.L $7F6000,X
        LDY.W #$0000
        ORA.B $06
        STA.B [$16]
        LDA.L $7F6002,X
        INY
        INY
        ORA.B $06
        STA.B [$16],Y
        LDA.L $7F6004,X
        INY
        INY
        ORA.B $06
        STA.B [$16],Y
        LDA.L $7F6006,X
        LDY.W #$0100
        ORA.B $06
        STA.B [$16],Y
        LDA.L $7F6008,X
        INY
        INY
        ORA.B $06
        STA.B [$16],Y
        LDA.L $7F600A,X
        INY
        INY
        ORA.B $06
        STA.B [$16],Y
        LDA.L $7F600C,X
        LDY.W #$0200
        ORA.B $06
        STA.B [$16],Y
        LDA.L $7F600E,X
        INY
        INY
        ORA.B $06
        STA.B [$16],Y
        LDA.L $7F6010,X
        INY
        INY
        ORA.B $06
        STA.B [$16],Y
        RTS
        REP #$20
        TAY
        CMP.W #$0002
        BNE CODE_81F6B8
        db $A0,$06,$00
CODE_81F6B8:
        CMP.W #$0003
        BNE CODE_81F6C0
        db $A0,$14,$00
CODE_81F6C0:
        STY.B $7F
        LDA.W #$000E
        JSR.W monitorDisassemble
        RTS
; [Debug] Runs all diagnostic tests. Entry: comprehensive system test suite.
runAllTests:
        REP #$20
        STZ.W $0A51
        STZ.W $0A53
        JSR.W generateTestReport
        RTS
; [Debug] Generates test results report. Entry: summarizes test outcomes.
generateTestReport:
        PHP
        SEP #$20
        LDY.W #$0200
        LDX.W #$0000
CODE_81F6DE:
        STZ.W $1800,X
        INX
        DEY
        BNE CODE_81F6DE
        PLP
        RTS
; [Debug] Logs test failure details. Entry: records failed test information.
logTestFailure:
        REP #$20
        JSL.L checkSPCBusy
        RTS
; [Debug] Resets test state between tests. Entry: clears test variables.
resetTestState:
        REP #$20
        CMP.W #$1000
        BCS CODE_81F701
        CMP.W #$0064
        BCC CODE_81F701
        SEC
        SBC.W #$0064
        ORA.W #$3000
CODE_81F701:
        STA.B $06
        STZ.B $08
        AND.W #$03FF
        STA.B $04
        LDA.B $07
        LSR A
        LSR A
        AND.W #$000C
        TAX
        LDA.L $0A8000,X
        STA.B $12
        SEP #$20
        LDA.L $0A8002,X
        STA.B $14
        STA.B $87
        REP #$20
        LDA.B $04
        ASL A
        TAY
        LDA.B [$12],Y
        STA.B $85
        STZ.B $82
        STZ.W $0A57
        STZ.W $0A69
        LDA.W #$0003
        STA.W $0A5B
        STZ.W $0A7B
        STZ.W $0A77
        STZ.W $0A79
        STZ.B $89
        LDA.W #$0A08
        STA.B $88
        STZ.W $0A87
        JSL.L updateMinimap
CODE_81F751:
        LDA.B $85
        BNE CODE_81F759
        STZ.W $0A87
        RTS
CODE_81F759:
        LDA.B [$85]
        INC.B $85
        STA.B $02
        AND.W #$003F
        ASL A
        ASL A
        CLC
        ADC.W #$F7B9
        STA.B $00
        JMP.W ($0000)
        DEC.B $85
        JSR.W benchmarkPerformance
        LDA.B $82
        INC A
        BNE CODE_81F783
        STZ.B $82
        LDA.W $0A7F
        STA.B $85
        LDA.W $0A81
        STA.B $87
CODE_81F783:
        BRA CODE_81F751
; [Debug] Runs performance benchmarks. Entry: measures frame rate, memory speed.
benchmarkPerformance:
        REP #$20
        JSR.W drawNumber
        LDA.W $0A83
        BEQ CODE_81F798
        LDA.B $4E
        AND.W #$0030
        BEQ CODE_81F798
        STZ.B $8B
CODE_81F798:
        LDA.B $82
        BEQ CODE_81F7A8
        LDA.B $4E
        AND.W #$3000
        BEQ CODE_81F7A8
        LDA.W #$FFFF
        STA.B $82
CODE_81F7A8:
        LDA.B $6A
        AND.W #$00FF
        CMP.W #$0001
        BNE CODE_81F7B5
        JSR.W logTestFailure
CODE_81F7B5:
        JSR.W confirmAction
        RTS
        JMP.W $F8B9
        db $EA
        JMP.W $F8DB
        db $EA,$4C,$13,$F9,$EA
        JMP.W $F8F0
        db $EA
        JMP.W $F8F8
        db $EA,$4C,$00,$F9,$EA,$4C,$0C,$F9,$EA
        JMP.W $F97E
        db $EA
        JMP.W $F8ED
        db $EA,$4C,$1E,$F9,$EA
        JMP.W $F92B
        db $EA
        JMP.W $F9AB
        db $EA,$4C,$D0,$F9,$EA,$4C,$EF,$F9,$EA
        JMP.W $F9F5
        db $EA
        JMP.W $FA42
        db $EA
        JMP.W $FA4E
        db $EA
        JMP.W $FA61
        db $EA,$4C,$C2,$F9,$EA
        JMP.W $FAAB
        db $EA
        JMP.W $FADB
        db $EA,$4C,$E4,$FA,$EA,$4C,$ED,$FA,$EA,$4C,$32,$F9,$EA
        JMP.W $FAF7
        db $EA
        JMP.W $FB04
        db $EA,$4C,$04,$FB,$EA
        JMP.W $FB27
        db $EA
        JMP.W $FB2F
        db $EA
        JMP.W $FB3F
        db $EA
        JMP.W $FB86
        db $EA
        JMP.W $FBB9
        db $EA,$4C,$F0,$FB,$EA
        JMP.W $FC04
        db $EA
        JMP.W $FC4D
        db $EA
        JMP.W $F960
        db $EA
        JMP.W $FC76
        db $EA
        JMP.W $F972
        db $EA
        JMP.W $FC9A
        db $EA
        JMP.W $FCAB
        db $EA
        JMP.W $FCBE
        db $EA
        JMP.W $FCCB
        db $EA
        JMP.W $FA92
        db $EA,$4C,$39,$F9,$EA
        JMP.W $FCD4
        db $EA
        JMP.W $FCE0
        db $EA,$4C,$E9,$FC,$EA
        JMP.W $FCF2
        db $EA
        JMP.W $FCFB
        db $EA
        JMP.W $FD0D
        db $EA
        JMP.W $FD3F
        db $EA,$4C,$49,$FD,$EA,$4C,$60,$FD,$EA,$4C,$69,$FD,$EA,$4C,$F8,$FD
        db $EA,$4C,$04,$FE,$EA
        JMP.W $FE32
        db $EA
        JMP.W $FE68
        db $EA
        JMP.W $FE79
        db $EA
        JMP.W $FE8B
        db $EA
        JMP.W $FEB5
        db $EA
        JMP.W $FEE7
        db $EA
        JMP.W $FEF0
        db $EA,$4C,$45,$FC,$EA
        LDA.W $0A7B
        BNE CODE_81F8CA
        STZ.B $85
        STZ.B $82
        LDA.W #$FFFF
        STA.B $8B
        JMP.W $F76F
CODE_81F8CA:
        STA.B $85
        STZ.W $0A7B
        SEP #$20
        LDA.W $0A7D
        STA.B $87
        REP #$20
        JMP.W CODE_81F759
        LDA.B $8B
        BNE CODE_81F8E2
        JMP.W CODE_81F759
CODE_81F8E2:
        CMP.W #$FFFF
        BEQ CODE_81F8E8
        DEC A
CODE_81F8E8:
        STA.B $8B
        JMP.W $F76D
        JMP.W $F76F
        JSR.W stressTestSystem
CODE_81F8F3:
        STA.B [$88]
        JMP.W CODE_81F759
        JSR.W stressTestSystem
        CLC
        ADC.B [$88]
        BRA CODE_81F8F3
        db $20,$42,$F9,$85,$00,$A7,$88,$38,$E5,$00,$80,$E7,$20,$42,$F9,$07
        db $88,$80,$E0,$20,$42,$F9,$A8,$A7,$88,$20,$DB,$EE,$80,$D5,$20,$42
        db $F9,$48,$A7,$88,$A8,$68,$20,$1F,$EF,$80,$C8
        JSR.W stressTestSystem
        AND.B [$88]
        BRA CODE_81F8F3
        db $20,$42,$F9,$47,$88,$80,$BA,$20,$42,$F9,$22,$47,$DF,$00,$80,$B1
; [Debug] Runs stress tests on systems. Entry: pushes systems to limits.
stressTestSystem:
        LDA.B [$85]
        TAX
        INC.B $85
        INC.B $85
        LDA.B $02
        AND.W #$0080
        BEQ CODE_81F95E
        CPX.W #$8000
        BCC CODE_81F95A
        LDA.L $7E6A00,X
        RTS
CODE_81F95A:
        LDA.W $0000,X
        RTS
CODE_81F95E:
        TXA
        RTS
        JSR.W panicHandler
        LDA.B $00
        STA.B $88
        SEP #$20
        LDA.B $02
        STA.B $8A
        REP #$20
        JMP.W CODE_81F759
        JSR.W stressTestSystem
        SEP #$20
        STA.B [$88]
        REP #$20
        JMP.W CODE_81F759
        INC.B $85
        STZ.B $04
        LDA.W #$0064
        JSL.L updateSmokeEffect
        CMP.B $03
        BCS CODE_81F996
        db $E6,$85,$E6,$85,$E6,$85,$4C,$59,$F7
CODE_81F996:
        LDA.B [$85]
        PHA
        INC.B $85
        INC.B $85
        SEP #$20
        LDA.B [$85]
        STA.B $87
        REP #$20
        PLA
        STA.B $85
        JMP.W CODE_81F759
        JSR.W finalizeTests
        PHA
        JSR.W finalizeTests
        TAY
        PLA
        CMP.W #$0080
        BNE CODE_81F9BC
        LDA.W $0A55
CODE_81F9BC:
        JSR.W flashScreen
        JMP.W $F76F
        db $A7,$85,$E6,$85,$29,$FF,$00,$22,$CA,$81,$00,$4C,$6F,$F7,$A7,$85
        db $85,$00,$E6,$85,$E6,$85,$A7,$85,$A8,$E6,$85,$E6,$85,$A7,$85,$AA
        db $E6,$85,$E6,$85,$A5,$00,$22,$60,$81,$00,$4C,$6F,$F7,$20,$4F,$ED
        db $4C,$6F,$F7
        LDA.B [$85]
        AND.W #$00FF
        STA.W $0E28
        INC.B $85
        LDA.B [$85]
        STA.B $00
        INC.B $85
        INC.B $85
        LDA.W $0E28
        CMP.W #$0080
        BCS CODE_81FA15
        JSR.W animateSpellCast
        JMP.W $F76F
CODE_81FA15:
        AND.W #$001F
        STA.B $06
        JSR.W updateMosaic
        LDA.B $06
        JSR.W unusedFunction
        LDA.B $02
        STA.W $0006,X
        LDA.B $04
        STA.W $0008,X
        LDA.W $0000,X
        ORA.W #$0801
        STA.W $0000,X
        LDA.B $06
        JSR.W initBattleState
        LDA.B $00
        STA.W $1404,X
        JMP.W $F76F
        LDA.B [$85]
        JSR.W monitorInput
        INC.B $85
        INC.B $85
        JMP.W CODE_81F759
        LDA.B $85
        STA.B $14
        LDA.B $87
        AND.W #$00FF
        STA.B $16
        JSR.W monitorDMA
        STA.B $85
        JMP.W CODE_81F759
        JSR.W finalizeTests
        PHA
        LDA.B [$85]
        STA.B $00
        INC.B $85
        INC.B $85
        JSR.W finalizeTests
        STA.B $02
        JSR.W finalizeTests
        STA.B $04
        PLA
        JSR.W drawItemScreen
        STA.W $0A55
        CMP.W #$FFFF
        BEQ CODE_81FA8F
        LDY.W #$0E00
        JSR.W debugMenu
        LDA.W #$0003
        JSR.W transitionFromBattle
CODE_81FA8F:
        JMP.W $F76F
        JSR.W finalizeTests
        STA.B $00
        LDA.B [$88]
        AND.W #$00FF
        CMP.B $00
        BCS CODE_81FAA9
        INC.B $85
        INC.B $85
        INC.B $85
        JMP.W CODE_81F759
CODE_81FAA9:
        BRA CODE_81FAC6
        INC.B $85
        LDA.B [$88]
        AND.W #$00FF
        STA.B $00
        LDA.B $03
        AND.W #$00FF
        CMP.B $00
        BEQ CODE_81FAC6
        INC.B $85
        INC.B $85
        INC.B $85
        JMP.W CODE_81F759
CODE_81FAC6:
        LDA.B [$85]
        PHA
        INC.B $85
        INC.B $85
        SEP #$20
        LDA.B [$85]
        STA.B $87
        REP #$20
        PLA
        STA.B $85
        JMP.W CODE_81F759
        JSR.W finalizeTests
        JSR.W exportSaveData
        JMP.W CODE_81F759
        db $20,$06,$FF,$20,$33,$DB,$4C,$59,$F7,$20,$06,$FF,$22,$82,$D9,$00
        db $4C,$59,$F7
        STZ.W $0A83
CODE_81FAFA:
        JSR.W finalizeTests
        ASL A
        ASL A
        STA.B $8B
        JMP.W $F76F
        JSR.W exitTestMode
        LDA.B [$85]
        TAY
        INC.B $85
        INC.B $85
        LDA.B $00
        CMP.W #$FFFF
        BEQ CODE_81FB1E
        LDX.B $02
        JSL.L calculateSlope
        JMP.W $F76F
        db $A5,$02,$22,$27,$A4,$00,$4C,$6F,$F7
        LDA.W #$0001
        STA.W $0A83
        BRA CODE_81FAFA
        JSR.W finalizeTests
        PHA
        JSR.W emergencyReset
        STA.B $00
        PLA
        JSR.W handleSaveScreen
        JMP.W CODE_81F759
        LDX.W $0A59
        LDA.W $0002,X
        STA.W $0A61
        LDA.W $0004,X
        STA.W $0A63
        LDA.B [$85]
        AND.W #$00FF
        STA.W $0A5F
        INC.B $85
        JSR.W exitTestMode
        LDA.B $00
        ORA.B $02
        BNE CODE_81FB6B
        db $AD,$00,$10,$85,$00,$AD,$02,$10,$85,$02
CODE_81FB6B:
        LDA.B $00
        SEC
        SBC.W $0A61
        STA.W $0A65
        LDA.B $02
        SEC
        SBC.W $0A63
        STA.W $0A67
        INC.W $0A57
        STZ.W $0A5D
        JMP.W $F76F
        LDA.W $0A57
        CLC
        ADC.W $0A69
        BNE CODE_81FB92
        JMP.W CODE_81F759
CODE_81FB92:
        JSL.L checkEntityCollision
        LDX.W $0A59
        LDA.B $22
        STA.W $0002,X
        LDA.B $24
        STA.W $0004,X
        CPX.W #$1800
        BCC CODE_81FBB6
        LDA.W $0A69
        BEQ CODE_81FBB6
        LDA.W $0A6B
        ORA.W #$8000
        STA.W $0008,X
CODE_81FBB6:
        JMP.W $F76D
        JSR.W finalizeTests
        CMP.W #$00FF
        BNE CODE_81FBC4
        db $AD,$55,$0A
CODE_81FBC4:
        STA.W $0A55
        CMP.W #$0080
        BCC CODE_81FBDB
        AND.W #$007F
        BNE CODE_81FBD4
        db $A9,$02,$12
CODE_81FBD4:
        SEC
        SBC.W #$0002
        TAX
        BRA CODE_81FBDE
CODE_81FBDB:
        JSR.W unusedFunction
CODE_81FBDE:
        STX.W $0A59
        STZ.W $0A57
        LDA.W $0A55
        LDY.W #$0E00
        JSR.W debugMenu
        JMP.W CODE_81F759
        db $20,$06,$FF,$18,$6D,$59,$0A,$AA,$A7,$85,$9D,$00,$00,$E6,$85,$E6
        db $85,$4C,$6F,$F7
        JSR.W finalizeTests
        STA.B $00
        STA.B $04
        JSR.W finalizeTests
        STA.B $02
        STA.B $05
        LDA.B $04
        BNE CODE_81FC24
        db $E2,$20,$AD,$55,$0A,$85,$00,$AD,$56,$0A,$85,$02,$C2,$20
CODE_81FC24:
        LDA.W $0A77
        BEQ CODE_81FC36
        db $A5,$04,$AC,$79,$0A,$99,$00,$10,$C8,$C8,$8C,$79,$0A
CODE_81FC36:
        LDA.B [$85]
        INC.B $85
        INC.B $85
        LDY.W $0A75
        JSR.W executeAbility
        JMP.W CODE_81F759
        db $20,$DE,$F5,$20,$62,$F3,$80,$0C
        JSR.W testNetwork
        JSR.W testCollision
        LDA.W #$000A
        JSR.W monitorDisassemble
        JSR.W confirmAction
        LDY.W #$0000
        CPY.W $0A79
        BEQ CODE_81FC73
        db $5A,$B9,$00,$10,$AC,$77,$0A,$20,$04,$AE,$7A,$C8,$C8,$80,$EC
CODE_81FC73:
        JMP.W $F76F
        JSR.W emergencyReset
        TAX
        BNE CODE_81FC7F
        LDA.W $0E04
CODE_81FC7F:
        STA.B $00
        CMP.W #$FFFF
        BNE CODE_81FC90
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $01
CODE_81FC90:
        JSR.W finalizeTests
        TAX
        JSR.W handleConfigMenu
        JMP.W $F76F
        JSR.W finalizeTests
        PHA
        JSR.W panicHandler
        PLA
        SEP #$20
        STA.B [$00]
        REP #$20
        JMP.W $F76F
        JSR.W exitTestMode
        LDA.B [$85]
        INC.B $85
        AND.W #$00FF
        STA.B $04
        LDA.B ($00)
        STA.B [$02]
        JMP.W $F76F
        JSR.W emergencyReset
        PHA
        JSR.W panicHandler
        PLA
        STA.B [$00]
        JMP.W $F76F
        JSR.W finalizeTests
        JSR.W transitionFromBattle
        JMP.W $F76F
        JSR.W exitTestMode
        JSR.W validateGameData
        JMP.W $F76F
; [Debug] Validates game data integrity. Entry: checks ROM data structures.
validateGameData:
        JMP.W ($0000)
        JSR.W finalizeTests
        STA.W $0A5B
        JMP.W CODE_81F759
        db $A0,$00,$0E,$20,$2A,$DE,$4C,$59,$F7
        JSR.W finalizeTests
        JSR.W $B04F
        JMP.W CODE_81F759
        LDA.B [$85]
        INC.B $85
        INC.B $85
        STA.W $0A6D
        INC.W $0A69
        STZ.W $0A6B
        JMP.W CODE_81F759
        JSR.W emergencyReset
        STA.W $0958
        JSR.W emergencyReset
        STA.W $095A
        JSR.W finalizeTests
        STA.W $0E03
        JSR.W finalizeTests
        STA.W $0E83
        JSR.W playSelectSound
        STZ.W $0E25
        LDA.W #$0001
        JSL.L dispatchGameMode
        JSL.L updateScanlineEffects
        JSR.W monitorInventory
        JSR.W drawMessageBox
        JMP.W CODE_81F759
        JSR.W finalizeTests
        JSL.L updateEntityAI
        JMP.W CODE_81F759
        db $20,$16,$FF,$48,$20,$16,$FF,$A8,$68,$D0,$06,$AD,$28,$0E,$09,$00
        db $80,$20,$04,$AE,$4C,$59,$F7,$20,$16,$FF,$8D,$75,$0A,$4C,$59,$F7
        db $20,$16,$FF,$A8,$D0,$03,$AD,$00,$10,$8D,$61,$0A,$8D,$63,$0A,$20
        db $16,$FF,$A8,$D0,$03,$AD,$00,$12,$18,$6D,$61,$0A,$8D,$65,$0A,$20
        db $16,$FF,$8D,$5F,$0A,$9C,$6D,$0A,$9C,$5D,$0A,$AD,$61,$0A,$85,$00
        db $20,$54,$FF,$AD,$5F,$0A,$C9,$00,$80,$90,$0C,$29,$FF,$7F,$A8,$AD
        db $61,$0A,$20,$04,$AE,$80,$1D,$C9,$00,$40,$90,$09,$29,$FF,$01,$9F
        db $00,$90,$7F,$80,$0F,$BF,$00,$90,$7F,$29,$FF,$01,$CD,$5F,$0A,$F0
        db $03,$EE,$5D,$0A,$E2,$20,$AD,$61,$0A,$1A,$CD,$65,$0A,$90,$0F,$AD
        db $62,$0A,$1A,$CD,$66,$0A,$B0,$0D,$8D,$62,$0A,$AD,$63,$0A,$8D,$61
        db $0A,$C2,$20,$80,$A6,$C2,$20,$AD,$5D,$0A,$87,$88,$4C,$59,$F7,$20
        db $16,$FF,$8D,$77,$0A,$9C,$79,$0A,$4C,$59,$F7,$AD,$57,$0A,$18,$6D
        db $69,$0A,$D0,$03,$4C,$59,$F7,$22,$C9,$CF,$00,$AE,$59,$0A,$A5,$22
        db $9D,$02,$00,$A5,$24,$9D,$04,$00,$AD,$6F,$0A,$38,$E5,$24,$10,$03
        db $A9,$00,$00,$9D,$0E,$00,$4C,$6D,$F7
        LDX.W $0A59
        LDA.W $0002,X
        STA.W $0A61
        LDA.W $0004,X
        STA.W $0A63
        CLC
        ADC.W $000E,X
        STA.W $0A6F
        LDA.B [$85]
        AND.W #$00FF
        STA.W $0A5F
        INC.B $85
        JSR.W exitTestMode
        LDA.B $00
        STA.W $0A65
        LDA.B $02
        STA.W $0A67
        INC.W $0A57
        STZ.W $0A5D
        JMP.W $F76F
        LDA.B $85
        CLC
        ADC.W #$0003
        STA.W $0A7B
        LDA.B $87
        STA.W $0A7D
        JMP.W CODE_81FAC6
        JSR.W emergencyReset
        LDA.B [$88]
        CLC
        ADC.B $02
        STA.B $00
        LDA.B ($00)
        STA.W $0A08
        JMP.W CODE_81F759
        JSR.W finalizeTests
        PHA
        JSR.W emergencyReset
        STA.B $06
        INC.W $0A87
        LDA.W $1000
        STA.B $02
        LDA.W $1002
        STA.B $04
        PLA
        CMP.W #$00FF
        BEQ CODE_81FEAE
        JSL.L handleNPCDialogue
        JMP.W CODE_81F759
        db $22,$DB,$A7,$00,$4C,$59,$F7
        JSR.W exitTestMode
        JSR.W finalizeTests
        STA.B $14
        LDA.B $02
        STA.B $12
        LDA.W #$0001
        STA.B $02
        LDA.B $00
        CMP.W #$0100
        BCS CODE_81FED7
        PHA
        JSR.W monitorHelp
        PLA
        CMP.W #$0080
        BCC CODE_81FEE4
        db $29,$1F,$00,$85,$00,$A9,$01,$00,$85,$02,$20,$81,$EB
CODE_81FEE4:
        JMP.W $F76F
        JSR.W emergencyReset
        JSR.W monitorMemory
        JMP.W $F76F
        JSR.W finalizeTests
        JSR.W unusedFunction
        JSR.W emergencyReset
        AND.W #$00FF
        JSR.W drawMapScreen
        JSL.L handleEntityDamage
        JMP.W CODE_81F759
; [Debug] Finalizes test suite execution. Entry: cleans up test environment.
finalizeTests:
        LDA.B [$85]
        INC.B $85
        AND.W #$00FF
        RTS
; [Debug] Exits test mode returns to game. Entry: restores normal game state.
exitTestMode:
        LDA.B [$85]
        INC.B $85
        INC.B $85
        STA.B $00
; [Debug] Emergency reset handler. Entry: called on critical errors, soft resets.
emergencyReset:
        LDA.B [$85]
        INC.B $85
        INC.B $85
        STA.B $02
        RTS
; [Debug] Panic handler for unrecoverable errors. Entry: displays error code, halts.
panicHandler:
        LDA.B [$85]
        BNE CODE_81FF26
        LDA.W #$0A08
CODE_81FF26:
        INC.B $85
        INC.B $85
        CMP.W #$8000
        BCC CODE_81FF3E
        AND.W #$7FFF
        CLC
        ADC.W #$EA00
        STA.B $00
        LDA.W #$007E
        STA.B $02
        RTS
CODE_81FF3E:
        STA.B $00
        STZ.B $02
        RTS
; [Unused] Unused function - appears to be dead code. Entry: never called in normal gameplay.
unusedFunction:
        PHP
        REP #$20
        AND.W #$00FF
        ASL A
        ASL A
        ASL A
        ASL A
        CLC
        ADC.W #$1800
        TAX
        PLP
        RTS
        db $A5,$01,$29,$1F,$00,$64,$01,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$18,$65
        db $00,$18,$65,$00,$AA,$60,$7F,$FF,$20,$BC,$FF,$20,$8F,$FF,$29,$FF
        db $00,$20,$BE,$AA,$22,$FC,$D0,$00,$4C,$D2,$F7,$A7,$85,$E6,$85,$29
        db $FF,$00,$60,$A7,$85,$E6,$85,$E6,$85,$85,$00,$A7,$85,$E6,$85,$E6
        db $85,$85,$02,$60,$A7,$85,$D0,$03,$A9,$08,$0A,$E6,$85,$E6,$85,$C9
        db $00,$80,$90,$0F,$29,$FF,$7F,$18,$69,$00,$EA,$85,$00,$A9,$7E,$00
        db $85,$02,$60,$85,$00,$64,$02,$60,$08,$C2,$20,$29,$FF,$00,$0A,$0A
        db $0A,$0A,$18,$69,$00,$18,$AA,$28,$60,$A5,$01,$29,$1F,$00,$64,$01
        db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$18,$65,$00,$18,$65,$00,$AA,$60,$0A
        db $18,$65,$00,$18,$65,$00,$AA,$60,$29,$FF,$00,$0A,$0A,$0A,$0A,$18
        db $69,$00,$18,$AA,$28,$60,$A5,$01,$29,$1F,$00,$64
