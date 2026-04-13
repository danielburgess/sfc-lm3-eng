        org $818000

; [Init] System initialization - clears WRAM, sets up hardware, calls external init routines. Entry: called at reset.
systemInit: ; $018000
        CLD
        REP #$30
        LDY.W #$0800
        LDX.W #$0000
CODE_818009: ; $018009
        STZ.W $0000,X
        INX
        DEY
        BNE CODE_818009
        SEP #$20
        JSL.L externalLibInit
        LDA.B #$30
        LDY.W #$8000
        JSL.L spcSetSourceAddr
        LDA.B #$34
        LDY.W #$8000
        JSL.L spcSetDestAddr
        LDA.B #$00
        JSL.L spcPlayMusic
        JMP.W $E168
        REP #$20
        JSR.W clearTextBuffer
        JSL.L scenarioDispatch
        LDA.W $0942
        BNE CODE_818072
        LDX.W #$0014
        LDA.W #$0000
CODE_818045: ; $018045
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
        JSR.W evtEntityInitFromScript
        JSR.W clearTextBuffer
CODE_818072: ; $018072
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
        JSR.W centerCameraOnPosition
        JSR.W sceneEntityInit
        JSR.W evtScrollInitFull
        JSR.W confirmAction
        LDA.W #$0063
        STA.W $0912
        LDA.W $0942
        BEQ CODE_8180AC
        JSR.W handleShopMenu
        BRA CODE_8180B2
CODE_8180AC: ; $0180AC
        LDA.W #$0000
        JSR.W evtBattleDispatch
CODE_8180B2: ; $0180B2
        JSR.W evtCallRenderSprites
        JSR.W confirmAction
        JSR.W initDisplayMode
        LDA.W $0942
        BNE CODE_8180C9
        LDA.L $7FC009
        AND.W #$00FF
        BNE CODE_8180CC
CODE_8180C9: ; $0180C9
        JSR.W drawMessageBox
CODE_8180CC: ; $0180CC
        JSR.W initScenarioDisplay
        LDA.L $7FC00B
        AND.W #$00FF
        BEQ CODE_8180DE
        JSR.W evtEntityInitFromScript
        JSR.W skipCutscene
CODE_8180DE: ; $0180DE
        LDA.W $0942
        BNE CODE_8180E6
        JSR.W checkScenarioTransition
CODE_8180E6: ; $0180E6
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
        JSR.W centerCameraOnPosition
        JSR.W initSceneAfterLoad
        JSR.W initScenarioDisplay
        RTS
CODE_818113: ; $018113
        LDX.W #$0000
        LDY.W #$0010
        STZ.B $00
CODE_81811B: ; $01811B
        LDA.W $1400,X
        AND.W #$00FF
        CMP.W #$00FF
        BNE CODE_818130
        LDA.W $140F,X
        AND.W #$00FF
        BNE CODE_818130
        INC.B $00
CODE_818130: ; $018130
        TXA
        CLC
        ADC.W #$0020
        TAX
        DEY
        BNE CODE_81811B
        LDA.B $00
        BNE CODE_818143
        JSR.W initScrollCounter
        JMP.W $8491
CODE_818143: ; $018143
        STZ.W $091C
        JSR.W clearBattleDataSlot
        JSR.W checkScrollLimit
        JSR.W initScenarioDisplay
CODE_81814F: ; $01814F
        LDA.W #$0000
        JSR.W handleInn
        LDA.W #$0080
        JSR.W getScenarioFlags
        BEQ CODE_818193
        db $A5,$50,$29,$00,$10,$D0,$56,$A9,$40,$00,$20,$84,$DE,$F0,$27,$A5
        db $50,$29,$00,$C0,$C9,$00,$C0,$D0,$06,$20,$09,$A6,$4C,$C4,$8D,$A5
        db $50,$29,$00,$40,$F0,$03,$4C,$38,$82,$A5,$50,$29,$00,$20,$F0,$06
        db $20,$09,$A6,$4C,$46,$97
CODE_818193: ; $018193
        LDA.B $50
        AND.W #$8000
        BEQ CODE_81819D
        JMP.W $8280
CODE_81819D: ; $01819D
        LDA.B $50
        AND.W #$0080
        BEQ CODE_8181A7
        JMP.W $8568
CODE_8181A7: ; $0181A7
        LDA.B $50
        AND.W #$0040
        BEQ CODE_8181B1
        JMP.W $8400
CODE_8181B1: ; $0181B1
        LDA.B $50
        AND.W #$0030
        BNE CODE_8181CE
        BRA CODE_81814F
        db $20,$1F,$E9,$D0,$03,$4C,$13,$81,$3A,$D0,$03,$4C,$DD,$8E,$9C,$42
        db $09,$4C,$31,$80
CODE_8181CE: ; $0181CE
        STZ.B $22
CODE_8181D0: ; $0181D0
        LDA.B $50
        AND.W #$0010
        BEQ CODE_8181E5
        LDA.W $0912
        INC A
        CMP.W #$0010
        BCC CODE_8181E3
        LDA.W #$0000
CODE_8181E3: ; $0181E3
        BRA CODE_8181F1
CODE_8181E5: ; $0181E5
        LDA.W $0912
        DEC A
        CMP.W #$0010
        BCC CODE_8181F1
        LDA.W #$000F
CODE_8181F1: ; $0181F1
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
CODE_818228: ; $018228
        LDA.B $02
        STA.W $090A
        LDA.B $04
        STA.W $090C
        JSR.W checkEntityScreenBounds
        JMP.W CODE_81814F
        db $A9,$00,$00,$20,$8D,$EC,$AD,$0A,$09,$85,$00,$AD,$0C,$09,$85,$01
        db $A5,$00,$8D,$00,$0E,$20,$0D,$A7,$8D,$02,$0E,$BB,$BF,$02,$E0,$7F
        db $8D,$04,$0E,$A9,$41,$00,$20,$4A,$EE,$A5,$50,$29,$30,$00,$D0,$03
        db $4C,$13,$81,$AD,$5A,$09,$8D,$58,$09,$AD,$04,$0E,$8D,$5A,$09,$20
        db $95,$E9,$20,$51,$B8,$4C,$DD,$8E
        JSR.W initScrollCounter
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
CODE_81829D: ; $01829D
        CMP.W #$0005
        BNE CODE_8182A5
        JMP.W $8420
CODE_8182A5: ; $0182A5
        CMP.W #$0006
        BEQ CODE_8182E6
        BRA CODE_818310
CODE_8182AC: ; $0182AC
        JMP.W CODE_818113
CODE_8182AF: ; $0182AF
        LDY.W #$00B5
        LDA.W #$0040
        JSR.W getScenarioFlags
        BEQ CODE_8182C4
        db $A5,$4E,$29,$00,$0F,$F0,$03,$A0,$36,$00
CODE_8182C4: ; $0182C4
        TYA
        PHA
        JSR.W textMetaLookup
        LDA.L $7EEA88
        STA.B $24
        PLY
        INY
        LDA.W #$0000
        JSR.W handleTransitionWipe
        LDA.B $24
        STA.L $7EEA88
        LDA.W #$0038
        JSR.W textMetaLookup
        JMP.W CODE_818113
CODE_8182E6: ; $0182E6
        LDA.W #$0033
        JSR.W textMetaLookup
        LDA.W $0A08
        BEQ CODE_8182AC
        DEC A
        BEQ CODE_8182FA
        JSR.W drawPauseMenu
        JMP.W $E3F2
CODE_8182FA: ; $0182FA
        LDA.W #$004E
        JSR.W textMetaLookup
        LDA.L $7EEA89
        AND.W #$0003
        JSR.W saveAndLoadTilemap
        JSR.W clearTextBuffer
        JMP.W $E1BA
CODE_818310: ; $018310
        LDA.W #$0001
        JSR.W $D231
        PHA
        JSR.W clearTextBuffer
        JSR.W initGraphics
        JSR.W checkScrollBoundaryY
        PLA
        CMP.W #$FFFF
        BNE CODE_818329
        JMP.W $83DB
CODE_818329: ; $018329
        JSR.W loadTileTemplate
        LDA.W $0E8C
        AND.W #$00FF
        CMP.W #$0003
        BNE CODE_81833A
        db $4C,$C1,$83
CODE_81833A: ; $01833A
        LDY.W #$0010
        CMP.W #$0002
        BNE CODE_818345
        db $A0,$20,$00
CODE_818345: ; $018345
        STY.W $0946
CODE_818348: ; $018348
        LDA.W #$0076
        JSR.W textMetaLookup
CODE_81834E: ; $01834E
        LDA.W #$0076
        JSR.W handleInn
        LDA.B $50
        AND.W #$8000
        BEQ CODE_81835E
        db $4C,$DB,$83
CODE_81835E: ; $01835E
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
        JSR.W updateEntity
        LDA.W #$0077
        JSR.W textMetaLookup
        LDA.W $0A08
        CMP.W #$0001
        BNE CODE_818348
        LDA.W $0E98
        CMP.W #$0060
        BCS CODE_8183A4
        db $A8,$AD,$50,$09,$20,$C8,$E7,$80,$06
CODE_8183A4: ; $0183A4
        JSR.W decrementEventFlag
        JSR.W initEntityWithTile
        LDA.B $14
        PHA
        LDA.B $0E
        LDY.W #$000E
        JSR.W flashScreen
        JSR.W handleShopMenu
        PLA
        BEQ CODE_8183BE
        db $20,$4A,$EE
CODE_8183BE: ; $0183BE
        JMP.W CODE_818113
        db $A9,$B4,$00,$20,$4A,$EE,$20,$E4,$83,$A0,$00,$00,$C9,$6E,$00,$D0
        db $02,$C8,$C8,$98,$20,$C9,$98,$4C,$13,$81
        LDA.W #$0073
        JSR.W textMetaLookup
        JMP.W CODE_818113
; [GameState] Reads $0E98 index; decrements $7E:EA00+X byte by 1
decrementEventFlag: ; $0183E4
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
CODE_81841A: ; $01841A
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
CODE_81844C: ; $01844C
        JSR.W initGraphics
        JSR.W initScenarioDisplay
        JMP.W CODE_81814F
; [Init] Initializes graphics system - sets up PPU registers, clears VRAM, loads font.
initGraphics: ; $018455
        JSR.W handleMapScreen
        LDA.W #$0006
        JSL.L dispatchGameMode
        LDA.W $0A4A
        STA.W $0A48
        LDA.W $0902
        STA.B $00
        LDA.W $0904
        STA.B $02
        JSR.W centerCameraOnPosition
        JSR.W initSceneAfterLoad
        JSR.W printText
        RTS
; Calls sceneEntityInit, evtScrollInitFull, scene setup.
initSceneAfterLoad: ; $018479
        REP #$20
        JSR.W sceneEntityInit
        JSR.W evtScrollInitFull
        JSR.W confirmAction
        JSR.W handleShopMenu
        JSR.W evtCallRenderSprites
        JSR.W confirmAction
        JSR.W initDisplayMode
        RTS
        LDA.W #$0063
        STA.W $0912
        JMP.W $928F
        JSR.W checkScrollBoundaryY
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
CODE_8184CB: ; $0184CB
        LDA.W #$000B
        JSR.W textMetaLookup
        JSR.W commitDmaFlag
        LDY.W #$0100
        LDA.L $7FC003
        AND.W #$00F0
        BEQ CODE_8184E3
        db $A0,$00,$0E
CODE_8184E3: ; $0184E3
        TYA
        ORA.W $0E62
        JSR.W textMetaLookup
        LDA.W #$0001
        JSR.W handleInn
        JMP.W CODE_818113
; [Init] Initializes game state variables - party, inventory, story flags to default.
initGameState: ; $0184F3
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
        JSR.W textMetaLookup
        LDY.W #$0E00
        BRA CODE_81851D
; [Init] Initializes controller input system - clears input buffers, enables auto-read.
initControllers: ; $018515
        LDY.W #$0F00
        PHY
        JSR.W updateEntity
        PLY
CODE_81851D: ; $01851D
        LDA.W $0038,Y
        LSR A
        LSR A
        STA.B $00
        STZ.W $0E74
        LDA.W $0008,Y
        CMP.B $00
        BCS CODE_818531
        INC.W $0E74
CODE_818531: ; $018531
        LDA.W $0028,Y
        CMP.W #$0010
        BCS CODE_81853C
        INC.W $0E75
CODE_81853C: ; $01853C
        RTS
; [Init] Enables screen display after init. Entry: sets $2100 to $0F (full brightness).
enableDisplay: ; $01853D
        LDA.W $0E90
        BRA CODE_818545
; [GameState] Title screen main loop - handles menu, demo playback, start game transition.
titleScreenLoop: ; $018542
        LDA.W $0E10
CODE_818545: ; $018545
        AND.W #$00FF
        CMP.W #$0004
        BEQ CODE_81855B
        CMP.W #$0002
        BEQ CODE_818564
        CMP.W #$0003
        BEQ CODE_818564
        LDA.W #$0000
        RTS
CODE_81855B: ; $01855B
        db $AF,$80,$EA,$7E,$29,$01,$00,$D0,$F3
CODE_818564: ; $018564
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
CODE_818582: ; $018582
        STA.W $092E
        STA.W $0A55
        JSR.W checkScrollBoundaryY
        JSR.W handlePauseMenu
        LDA.W $092E
        LDY.W #$0E00
        JSR.W updateEntity
        LDY.W #$0E00
        JSR.W handleEquipment
        JSR.W initGameState
        LDA.W #$0011
        JSR.W textMetaLookup
        LDA.W $0E28
        CMP.W #$0010
        BCS CODE_8185C1
        LDA.W $0E0F
        AND.W #$00FF
        BNE CODE_8185B8
        BRA CODE_8185D5
CODE_8185B8: ; $0185B8
        LDA.W #$0001
        JSR.W handleInn
        JMP.W CODE_818113
CODE_8185C1: ; $0185C1
        LDA.W #$3932
        STA.B $7D
        JSR.W handleTitleInput
        LDA.W #$0002
        JSR.W handleInn
        JSR.W playTitleMusic
        JMP.W CODE_818113
CODE_8185D5: ; $0185D5
        LDA.W #$3132
        STA.B $7D
        JSR.W handleTitleInput
CODE_8185DD: ; $0185DD
        LDA.W #$0002
        JSR.W handleInn
        LDA.B $50
        AND.W #$0080
        BNE CODE_8185F9
        LDA.B $50
        AND.W #$8000
        BNE CODE_8185F3
        BRA CODE_8185DD
CODE_8185F3: ; $0185F3
        JSR.W playTitleMusic
        JMP.W CODE_818113
CODE_8185F9: ; $0185F9
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
CODE_818627: ; $018627
        LDA.W $090A
        STA.B $00
        STA.W $0948
        LDA.W $090C
        STA.B $01
        STA.W $094A
        JSR.W lookupBattleEntityTile
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
        JSR.W checkEntityScreenBounds
CODE_818676: ; $018676
        JSR.W copyBufferToWram
        LDY.W #$0000
        LDA.W $0922
        BNE CODE_818684
        LDY.W #$0001
CODE_818684: ; $018684
        LDA.W $0E6A
        BEQ CODE_81868C
        LDY.W #$0001
CODE_81868C: ; $01868C
        TYA
        LDY.W #$000F
        JSR.W handleTransitionWipe
        LDA.B $22
        BNE CODE_81869A
        JMP.W $8B54
CODE_81869A: ; $01869A
        CMP.W #$0002
        BNE CODE_8186A2
        JMP.W $86E4
CODE_8186A2: ; $0186A2
        CMP.W #$0003
        BEQ CODE_8186AF
        CMP.W #$0001
        BEQ CODE_8186B2
        JMP.W $8779
CODE_8186AF: ; $0186AF
        JMP.W $8BCD
CODE_8186B2: ; $0186B2
        LDA.W $0E6A
        BEQ CODE_8186BA
        JMP.W $893C
CODE_8186BA: ; $0186BA
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
        JSR.W textMetaLookup
        JSR.W gameMainLoop
        PHA
        JSR.W playTitleMusic
        PLA
        BEQ CODE_8186E1
        JMP.W $8669
CODE_8186E1: ; $0186E1
        JMP.W $8C0D
        LDA.W $0920
        BNE CODE_8186EC
        JMP.W CODE_818676
CODE_8186EC: ; $0186EC
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
CODE_81878D: ; $01878D
        DEC A
        DEC A
        STA.W $1408,X
        STA.W $0E08
        LDA.W $1404,X
        STA.W $091A
        LDA.W #$0079
        JSR.W textMetaLookup
        LDA.W #$0050
        JSR.W setTextColor
        LDX.W #$0000
        STZ.B $02
CODE_8187AC: ; $0187AC
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
CODE_8187D3: ; $0187D3
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_8187AC
CODE_8187DB: ; $0187DB
        LDA.W $091A
        STA.B $00
        JSR.W lookupTilemapTile
        AND.W #$1000
        BNE CODE_81883C
        STX.W $096C
        LDA.W $0E46
        AND.W #$00FF
        LSR A
        STA.B $22
        LDA.W #$0064
        JSL.L hardwareMultiplyRng
        CMP.B $22
        BCS CODE_81883C
        LDA.W $0E6A
        BNE CODE_818818
        LDA.W #$000A
        JSL.L hardwareMultiplyRng
        CLC
        ADC.W #$0005
        ASL A
        STA.W $0A08
        JSR.W advanceScenarioTimer
        BRA CODE_818848
CODE_818818: ; $018818
        db $AE,$18,$09,$BD,$0A,$14,$29,$FF,$00,$C9,$05,$00,$B0,$DE,$E2,$20
        db $1A,$9D,$0A,$14,$C2,$20,$A9,$00,$00,$20,$E5,$EB,$A9,$7C,$00,$20
        db $4A,$EE,$80,$0C
CODE_81883C: ; $01883C
        LDA.W #$001A
        JSR.W setTimerValue
        LDA.W #$007A
        JSR.W textMetaLookup
CODE_818848: ; $018848
        LDX.W $096C
        LDA.L $7F9000,X
        ORA.W #$1000
        STA.L $7F9000,X
        JMP.W $8BDD
; [GameState] Initializes title screen - sets up animation, music, and input handlers. Entry: called when entering title screen.
initTitleScreen: ; $018859
        LDA.W #$0001
        STA.B $08
        LDA.W #$0003
        STA.B $0A
        JSR.W animateTitle
        LDA.W #$0010
        JSR.W textMetaLookup
        JSR.W gameMainLoop
        PHA
        JSR.W playTitleMusic
        PLA
        RTS
; [Animation] Animates title screen elements (sparkles, pulsing). Entry: called each frame.
animateTitle: ; $018875
        LDA.W #$3157
        STA.B $7D
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $02
        JSL.L markCellsInRange
        JSR.W evtScrollInitPartial
        JSR.W confirmAction
        RTS
; [Input] Handles input on title screen - start button, demo mode.
handleTitleInput: ; $01888F
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
        JSL.L clearObjectBuffer
        JSR.W evtTileSetPriority
        JSR.W evtScrollInitPartial
        RTS
; [Music] Plays title screen music. Entry: starts BGM track 0.
playTitleMusic: ; $0188B6
        JSR.W evtTileClearPriority
        JSR.W evtScrollInitPartial
        JSR.W confirmAction
        RTS
; [MainLoop] Main gameplay loop - updates all systems, renders frame. Entry: called each frame during gameplay.
gameMainLoop: ; $0188C0
        STZ.W $0928
        LDA.W $0926
        STA.W $092C
        LDY.W $0E6A
        CPY.W #$0003
        BNE CODE_8188D5
        DEC A
        STA.W $0928
CODE_8188D5: ; $0188D5
        LDA.W #$0000
        JSR.W handleSavePoint
        LDA.B $50
        AND.W #$4080
        BNE CODE_8188EC
        LDA.B $50
        AND.W #$8000
        BEQ CODE_8188EA
        RTS
CODE_8188EA: ; $0188EA
        db $80,$E9
CODE_8188EC: ; $0188EC
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
CODE_818908: ; $018908
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
CODE_818931: ; $018931
        SEP #$20
        STA.W $0E25
        REP #$20
        LDA.W #$0000
        RTS
        LDA.W $0E28
        LDY.W #$0E00
        JSR.W updateEntity
        LDA.W $0E0A
        AND.W #$00FF
        BNE CODE_818956
        db $A9,$90,$00,$20,$4A,$EE,$4C,$76,$86
CODE_818956: ; $018956
        LDA.W $0E6A
        CMP.W #$0002
        BCS CODE_81899C
        LDA.W $0922
        BNE CODE_818966
        JMP.W CODE_818676
CODE_818966: ; $018966
        JSR.W initTitleScreen
        BEQ CODE_81896E
        JMP.W $8669
CODE_81896E: ; $01896E
        LDA.W $0E54
        LDY.W #$0E80
        JSR.W updateEntity
        LDA.W #$007D
        JSR.W textMetaLookup
        LDA.W $0A08
        CMP.W #$0001
        BEQ CODE_818988
        db $4C,$69,$86
CODE_818988: ; $018988
        JSR.W updateSpellEffect
        BNE CODE_818990
        db $4C,$69,$86
CODE_818990: ; $018990
        JSR.W updateGameLogic
        DEC.W $0E0A
        JSR.W updateDamageSpark
        JMP.W $8C65
CODE_81899C: ; $01899C
        CMP.W #$0004
        BNE CODE_8189A4
        db $4C,$B0,$8A
CODE_8189A4: ; $0189A4
        JSR.W setupGameSequence
        CMP.W #$FFFF
        BNE CODE_8189AF
        db $4C,$76,$86
CODE_8189AF: ; $0189AF
        LDA.W $0E6C
        AND.W #$00FF
        STA.W $0946
        LDA.W #$FFFF
        STA.W $0EA8
        LDA.W $0E71
        AND.W #$00FF
        BNE CODE_8189C9
        JMP.W $8A3D
CODE_8189C9: ; $0189C9
        CMP.W #$0002
        BNE CODE_8189D1
        JMP.W $8A63
CODE_8189D1: ; $0189D1
        LDA.W #$0023
        JSR.W textMetaLookup
CODE_8189D7: ; $0189D7
        LDA.W #$0023
        JSR.W handleInn
        LDA.B $50
        AND.W #$8000
        BEQ CODE_8189E7
        db $4C,$69,$86
CODE_8189E7: ; $0189E7
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
CODE_818A2C: ; $018A2C
        JSR.W drawShopStock
        CMP.W #$FFFF
        BEQ CODE_8189D7
        STA.W $0E54
        LDY.W #$0E80
        JSR.W updateEntity
        SEP #$20
        LDA.W $0E5A
        STA.W $0E0A
        REP #$20
        JSR.W processEntityLoop
        LDA.W $0948
        STA.B $02
        LDA.W $094A
        STA.B $04
        JSR.W checkEntityScreenBounds
        JSR.W setupEffectTimer
        LDY.W #$0E00
        JSR.W saveEntityToBuffer
        JMP.W $8BDD
        JSR.W initTitleScreen
        BEQ CODE_818A6B
        JMP.W $8669
CODE_818A6B: ; $018A6B
        JSR.W updateGameLogic
        LDA.W $0E54
        LDY.W #$0E80
        JSR.W updateEntity
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
CODE_818A94: ; $018A94
        REP #$20
        LDA.W #$0005
        JSL.L hardwareMultiplyRng
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
        JSR.W checkEntityScreenBounds
        JMP.W CODE_818113
; [MainLoop] Updates game logic subsystems - entities, AI, physics, triggers.
updateGameLogic: ; $018B85
        JSR.W handleGameInput
        LDA.W $0A55
        LDY.W #$0E00
        JSR.W updateEntity
        RTS
; [MainLoop] Updates graphics - OAM, tilemap changes, effects. Prepares for V-blank DMA.
updateGraphics: ; $018B92
        LDA.W $091C
        JSR.W cleanupBattle
        STX.W $0916
        LDA.W $091C
        JSR.W initBattleState
        STX.W $0918
        JSR.W handleGameInput
        JSR.W handleShopMenu
        JSR.W evtCallRenderSprites
        JSR.W confirmAction
        RTS
; [Input] Handles gameplay input - movement, menu, actions. Updates player controller state.
handleGameInput: ; $018BB1
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
CODE_818BE0: ; $018BE0
        LDA.W $091C
        BEQ CODE_818C04
        CMP.W #$FFFF
        BNE CODE_818BED
        db $4C,$C4,$8D
CODE_818BED: ; $018BED
        CMP.W #$FFFE
        BNE CODE_818BF5
        JMP.W $8D86
CODE_818BF5: ; $018BF5
        db $8D,$28,$0E,$AD,$55,$0A,$8D,$22,$09,$9C,$1C,$09,$4C,$EE,$96
CODE_818C04: ; $018C04
        JSR.W handleShopMenu
        JSR.W checkScenarioTransition
        JMP.W CODE_818113
        JSR.W updateGameLogic
        LDA.W $0E54
        LDY.W #$0E80
        JSR.W updateEntity
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
CODE_818C36: ; $018C36
        CMP.W #$0010
        BCC CODE_818C3E
        db $4C,$13,$81
CODE_818C3E: ; $018C3E
        CMP.W $0E28
        BNE CODE_818C46
        db $4C,$27,$86
CODE_818C46: ; $018C46
        LDY.W #$0E80
        JSR.W updateEntity
        JSR.W copyBufferToWram
        JSR.W checkGameProgress
        CMP.W #$0001
        BNE CODE_818C5A
        db $4C,$13,$81
CODE_818C5A: ; $018C5A
        CMP.W #$0002
        BNE CODE_818C62
        db $4C,$54,$8B
CODE_818C62: ; $018C62
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
        JSR.W enableInterrupts
CODE_818C95: ; $018C95
        LDA.W $0930
        CLC
        ADC.W #$006C
        STA.B $00
        LDA.W $0932
        CLC
        ADC.W #$0058
        STA.B $02
        JSR.W centerCameraOnPosition
        JSL.L scenarioDispatch
        JSR.W initSceneAfterLoad
        JSR.W drawMessageBox
        JSR.W initScenarioDisplay
        PLA
        LDY.W #$0E00
        JSR.W updateEntity
        LDY.W #$0080
        JSR.W readUnitBattleStats
        LDY.W #$0000
        JSR.W readUnitBattleStats
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
CODE_818CE7: ; $018CE7
        LDA.W $093C
        STA.W $0A55
        JSR.W initBattleState
        LDA.W $140B,X
        AND.W #$00FF
        BEQ CODE_818CFB
        JSR.W evtEntityInitFromScript
CODE_818CFB: ; $018CFB
        LDA.W $091C
        CMP.W #$FFFD
        BNE CODE_818D06
        db $4C,$C4,$8D
CODE_818D06: ; $018D06
        LDA.W $093C
        BNE CODE_818D0E
        db $4C,$74,$8D
CODE_818D0E: ; $018D0E
        CMP.W #$001F
        BNE CODE_818D16
        JMP.W $8DC4
CODE_818D16: ; $018D16
        LDA.L $7FC017
        AND.W #$00FF
        BEQ CODE_818D22
        db $20,$EE,$F6
CODE_818D22: ; $018D22
        JSR.W checkScenarioTransition
        LDA.W $091C
        BNE CODE_818D2D
        JMP.W CODE_818113
CODE_818D2D: ; $018D2D
        JSR.W advanceScrollPosition
        LDA.W #$000E
        JSR.W textMetaLookup
        LDA.W #$000A
        JSR.W setTextColor
        JMP.W $9738
; Reads unit data $0E08+Y, $0E12+Y, $0E72+Y.
readUnitBattleStats: ; $018D3F
        LDA.W $0E08,Y
        BEQ CODE_818D73
        LDA.W $0E12,Y
        STA.W $0E52
        LDA.W $0E72,Y
        AND.W #$00FF
        BEQ CODE_818D73
        TAX
        LDA.W $0E28,Y
        PHA
        PHX
        LDA.W #$001E
        JSR.W setTextColor
        JSR.W advanceScrollPosition
        PLA
        CLC
        ADC.W #$0C13
        JSR.W textMetaLookup
        PLA
        LDY.W #$0002
        JSR.W flashScreen
        JSR.W waitForDpadInput
CODE_818D73: ; $018D73
        RTS
        db $20,$8C,$8D,$A9,$12,$00,$20,$86,$EB,$A9,$20,$00,$20,$4A,$EE,$4C
        db $F2,$E3
        JSR.W drawPauseMenu
        JMP.W $E3F2
; [Menu] Draws pause menu overlay with options. Entry: called when game paused.
drawPauseMenu: ; $018D8C
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
CODE_818DAB: ; $018DAB
        SEP #$20
        LDA.W $1431
        CMP.B #$04
        BNE CODE_818DB7
        db $9C,$37,$14
CODE_818DB7: ; $018DB7
        REP #$20
        JSR.W loadScenarioPreserving
        RTS
CODE_818DBD: ; $018DBD
        db $3A,$8F,$82,$EA,$7E,$80,$E7
        LDA.W #$001D
        JSR.W setTimerValue
        LDA.W #$001A
        JSR.W textMetaLookup
        LDA.W #$0010
        JSR.W drawSaveScreen
        LDA.W #$0005
        JSR.W soundDispatcher
        LDA.W #$0118
        JSR.W drawSaveScreen
        LDA.L $7FC00C
        AND.W #$00FF
        BEQ CODE_818DEE
        JSR.W evtEntityInitFromScript
CODE_818DEE: ; $018DEE
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
CODE_818E17: ; $018E17
        JMP.W $E3F2
CODE_818E1A: ; $018E1A
        db $1A,$8F,$82,$EA,$7E,$9C,$42,$09,$4C,$31,$80
CODE_818E25: ; $018E25
        db $A9,$1F,$00,$8F,$8C,$EA,$7E,$A9,$40,$00,$8F,$82,$EA,$7E,$20,$26
        db $E6,$A9,$2C,$00,$20,$EE,$F6,$4C,$BA,$E1
; [Menu] Handles pause menu navigation and selections. Entry: processes input in pause menu.
handlePauseMenu: ; $018E3F
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
        JSR.W copyBufferLoop
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
; Copies $7F:6000 to $7E:9076 via [$12].
copyBufferToWram: ; $018E84
        LDA.W #$007E
        STA.B $14
        LDA.W #$9076
        STA.B $12
        LDX.W #$0000
; Data copy loop from $7F:6000+X.
copyBufferLoop: ; $018E91
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
        JSR.W centerCameraOnPosition
        JSL.L scenarioDispatch
        JSR.W initSceneAfterLoad
        JSR.W drawMessageBox
        JSR.W initScenarioDisplay
        LDA.W $091C
        BNE CODE_818F06
        JMP.W CODE_818113
CODE_818F06: ; $018F06
        db $20,$E0,$A5,$A9,$0E,$00,$20,$4A,$EE,$4C,$38,$97
; [Animation] Draws special battle animation frames. Entry: A=animation ID, renders to OAM.
drawBattleAnimation: ; $018F12
        LDA.B $00
        PHA
        JSR.W lookupTilemapTile
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
CODE_818F4B: ; $018F4B
        TXA
        CLC
        ADC.W #$0004
        TAX
        JMP.W $8F25
CODE_818F54: ; $018F54
        JSR.W lookupTilemapTile
        LDA.L $7F9000,X
        AND.W #$0800
        BEQ CODE_818F63
        db $4C,$E8,$8F
CODE_818F63: ; $018F63
        RTS
CODE_818F64: ; $018F64
        LDA.L $7FC0CA,X
        STA.B $02
        AND.W #$00FF
        BEQ CODE_818F9F
        CMP.W #$0040
        BCC CODE_818F75
        db $60
CODE_818F75: ; $018F75
        CMP.W #$0002
        BEQ CODE_818F8F
        CMP.W #$0003
        BEQ CODE_818F85
        LDA.W $091C
        BEQ CODE_818F85
        db $60
CODE_818F85: ; $018F85
        LDA.B $03
        CLC
        ADC.W #$1000
        JSR.W evtEntityInitFromScript
        RTS
CODE_818F8F: ; $018F8F
        LDA.W $091C
        BEQ CODE_818F95
        RTS
CODE_818F95: ; $018F95
        LDA.B $03
        CLC
        ADC.W #$2000
        JSR.W evtEntityInitFromScript
        RTS
CODE_818F9F: ; $018F9F
        LDA.B $03
        CMP.W #$0018
        BEQ CODE_818FB9
        db $AD,$1C,$09,$F0,$01,$60,$A5,$03,$18,$69,$00,$20,$20,$F7,$EB,$20
        db $96,$ED,$60
CODE_818FB9: ; $018FB9
        LDA.W $0A55
        LDY.W #$0E00
        JSR.W updateEntity
        JSR.W drawWeaponSwing
        BEQ CODE_818FE7
        LDA.W $0E38
        STA.W $0E08
        LDY.W #$0E00
        JSR.W saveEntityToBuffer
        LDA.W $0E28
        PHA
        JSR.W processEntityAction
        LDA.W #$0018
        JSR.W textMetaLookup
        PLA
        LDY.W #$0004
        JSR.W flashScreen
CODE_818FE7: ; $018FE7
        RTS
        db $DA,$A9,$2F,$00,$20,$4A,$EE,$AD,$55,$0A,$C9,$10,$00,$B0,$0B,$48
        db $AF,$95,$EA,$7E,$1A,$8F,$95,$EA
; [Text]
textTileBufferTop: ; $019000
        db $7E,$68,$48,$48,$20,$EB,$AD,$68,$A0,$09,$00,$20,$1E,$C9,$68,$A0
        db $08,$00,$20,$1E,$C9,$FA,$A9,$08,$00,$20,$99,$9A,$AD,$55,$0A,$20
        db $D8,$9C,$BD,$08,$14,$4A,$1A,$9D,$08,$14,$A9,$50,$00,$20,$2B,$B2
        db $60
; [Animation] Updates battle animation progress. Entry: advances animation frames, timing.
updateBattleAnimation: ; $019031
        LDA.B $00
        PHA
        JSR.W lookupTilemapTile
        AND.W #$01FF
        STA.B $06
        PLA
        STA.B $00
        LDX.W #$0000
CODE_819042: ; $019042
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
CODE_819063: ; $019063
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_819042
CODE_81906B: ; $01906B
        LDA.L $7FC0CA,X
        STA.B $00
        AND.W #$00FF
        CMP.W #$0080
        BCS CODE_819081
CODE_819079: ; $019079
        RTS
        db $A9,$31,$00,$20,$4A,$EE,$60
CODE_819081: ; $019081
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
drawSpellEffect: ; $019114
        STA.B $22
        JSR.W initBattleState
        LDA.W $1404,X
        STA.B $00
        LDX.W #$0000
CODE_819121: ; $019121
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
        JSR.W lookupTilemapTile
        LDY.W #$0008
        LDA.L $7FC016
        AND.W #$00FF
        BEQ CODE_81914F
        db $A8
CODE_81914F: ; $01914F
        TYA
        JSR.W checkAbilityCondition
        LDA.B $22
        LDY.W #$0009
        JSR.W flashScreen
        LDA.W #$000A
        JSR.W setTextColor
        RTS
CODE_819162: ; $019162
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_819121
CODE_81916A: ; $01916A
        RTS
; [Animation] Updates spell effect animation. Entry: moves particles, updates graphics.
updateSpellEffect: ; $01916B
        LDA.W $0E90
        BRA CODE_819173
; [Animation] Draws weapon swing animation. Entry: A=weapon type, renders arc, trail.
drawWeaponSwing: ; $019170
        LDA.W $0E10
CODE_819173: ; $019173
        AND.W #$00FF
        CMP.W #$0007
        BNE CODE_81918A
        db $A9,$93,$00,$20,$4A,$EE,$A9,$A0,$00,$20,$72,$B8,$A9,$00,$00
CODE_81918A: ; $01918A
        RTS
; [Animation] Updates weapon swing animation. Entry: advances swing frame, hit detection.
updateWeaponSwing: ; $01918B
        REP #$20
        PHA
        JSR.W drawHealEffect
        JSR.W drawDamageSpark
        JSR.W titleScreenLoop
        BEQ CODE_81919C
        db $9C,$56,$0E
CODE_81919C: ; $01919C
        JSR.W enableDisplay
        BEQ CODE_8191A4
        db $9C,$D6,$0E
CODE_8191A4: ; $0191A4
        SEP #$20
        LDA.W $0E03
        CMP.B #$1F
        BNE CODE_8191C2
        LDA.L $7EEA82
        CMP.B #$0A
        BCC CODE_8191C2
        db $22,$72,$DF,$00,$29,$01,$D0,$05,$A9,$38,$8D,$03,$0E
CODE_8191C2: ; $0191C2
        REP #$20
        LDY.W #$0004
        LDA.W $0EA8
        CMP.W $0956
        BCC CODE_8191D2
        LDY.W #$0001
CODE_8191D2: ; $0191D2
        PLA
        JSR.W handleListScrolling
        RTS
; [Effects] Draws damage hit spark effect. Entry: A=damage type, renders spark particles.
drawDamageSpark: ; $0191D7
        LDY.W #$0E00
        JSR.W handleEquipment
        LDA.W $0062,Y
        STA.W $095A
        LDA.W $0E37
        AND.W #$0030
        CMP.W #$0020
        BCC CODE_8191F1
        STZ.W $0E60
CODE_8191F1: ; $0191F1
        LDY.W #$0E80
        JSR.W handleEquipment
        LDA.W $0062,Y
        STA.W $0958
        LDA.W $0EB7
        AND.W #$0030
        CMP.W #$0020
        BCC CODE_81920B
        STZ.W $0EE0
CODE_81920B: ; $01920B
        RTS
; [Animation] Updates damage spark animation. Entry: moves sparks, fades out.
updateDamageSpark: ; $01920C
        LDA.W $0A55
        LDY.W #$0080
        JSR.W flashScreen
        JSR.W drawHealEffect
        JSR.W drawDamageSpark
        JSR.W initBattleSequence
        RTS
; [Effects] Draws healing effect animation. Entry: A=heal power, renders glow, particles.
drawHealEffect: ; $01921F
        REP #$20
        LDA.B $60
        STA.W $0930
        LDA.B $62
        STA.W $0932
        LDA.W #$0000
        JSR.W setTimerValue
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
CODE_81924D: ; $01924D
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
CODE_819264: ; $019264
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
CODE_81927B: ; $01927B
        JSR.W clampSpriteY
        JSR.W confirmAction
        LDA.B $00
        CMP.W #$0080
        BNE CODE_81924D
        LDA.W #$8000
        JSR.W soundDispatcher
        RTS
        LDA.W #$0055
        JSR.W textMetaLookup
        JSR.W advanceScrollPosition
        LDA.W #$000E
        JSR.W textMetaLookup
        JSR.W clearBattleDataSlot
        LDA.W #$0001
        JSR.W evtBattleDispatch
        JSR.W evtCallRenderSprites
        JSR.W confirmAction
        JSL.L equipItem
        LDA.W #$0010
        STA.W $091C
        LDA.W $091C
        STA.W $0A55
        LDY.W #$0E00
        JSR.W updateEntity
        LDA.W $0E00
        AND.W #$00FF
        BNE CODE_8192CE
        JMP.W $9738
CODE_8192CE: ; $0192CE
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
        JSL.L clearObjectBuffer
        JSL.L unequipItem
        LDA.W $0E0C
        AND.W #$00E0
        STA.W $0E5A
        CMP.W #$00C0
        BNE CODE_81931D
        db $A9,$03,$00,$22,$57,$A1,$00,$80,$0C
CODE_81931D: ; $01931D
        LDA.W $0E0E
        LSR A
        LSR A
        AND.W #$0003
        JSL.L skipIfZero
        STZ.W $094E
        STZ.W $093A
        LDA.W $0E5A
        CMP.W #$00E0
        BNE CODE_81933A
        JMP.W $9641
CODE_81933A: ; $01933A
        JSR.W titleScreenLoop
        BEQ CODE_819345
        db $EE,$54,$09,$4C,$41,$96
CODE_819345: ; $019345
        LDA.W $0E0D
        AND.W #$0003
        BEQ CODE_819389
        TAY
        LDA.W #$0000
CODE_819351: ; $019351
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
CODE_81937B: ; $01937B
        CMP.W $091A
        BNE CODE_819383
        db $9C,$1A,$09
CODE_819383: ; $019383
        INC.W $0954
        JMP.W CODE_8194E6
CODE_819389: ; $019389
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
CODE_8193AC: ; $0193AC
        db $AD,$AE,$09,$F0,$09,$9C,$6E,$09,$EE,$3A,$09,$4C,$11,$94,$A9,$1F
        db $00,$20,$D8,$9C,$BD,$04,$14,$8D,$6E,$09,$4C,$E6,$94
CODE_8193C9: ; $0193C9
        LDA.W $0E0D
        AND.W #$0080
        BNE CODE_8193AC
        LDA.W $09AE
        BEQ CODE_8193DF
        STZ.W $096E
        INC.W $093A
        JMP.W CODE_819411
CODE_8193DF: ; $0193DF
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
CODE_8193F4: ; $0193F4
        LDA.W $0E0D
        AND.W #$0080
        BEQ CODE_819411
        db $80,$AE
CODE_8193FE: ; $0193FE
        db $AD,$0D,$0E,$29,$80,$00,$F0,$A6,$80,$09
CODE_819408: ; $019408
        db $AD,$04,$0E,$8D,$6E,$09,$4C,$E6,$94
CODE_819411: ; $019411
        LDA.W $0E0C
        AND.W #$001F
        CMP.W #$0010
        BCC CODE_819428
        AND.W #$000F
        STA.W $096E
        STA.W $0E5A
        JMP.W $94AD
CODE_819428: ; $019428
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
CODE_819452: ; $019452
        LDA.W $093A
        BEQ CODE_819461
        LDX.B $0E
        LDA.W $099E,X
        AND.W #$0001
        BEQ CODE_819497
CODE_819461: ; $019461
        LDA.B $0E
        LDY.W #$0E80
        JSR.W updateEntity
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
CODE_819485: ; $019485
        BRA CODE_819497
CODE_819487: ; $019487
        AND.W #$7FFF
        TAY
        JSR.W awardBattleRewards
        AND.B $26
        CMP.B $24
        BCS CODE_819497
        JSR.W checkBattleCondition
CODE_819497: ; $019497
        INC.B $0E
        LDA.B $0E
        CMP.W #$0010
        BNE CODE_819452
        LDA.B $22
        CMP.W #$FFFF
        BNE CODE_8194AA
        db $4C,$41,$96
CODE_8194AA: ; $0194AA
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
CODE_8194C9: ; $0194C9
        LDA.W $1404,X
        STA.W $096E
        LDA.W $0E56
        CMP.W #$0002
        BCC CODE_8194E6
        LDA.W #$0001
        CMP.W $0E5C
        BCS CODE_8194E2
        db $AD,$5C,$0E
CODE_8194E2: ; $0194E2
        INC A
        STA.W $094E
CODE_8194E6: ; $0194E6
        STZ.B $00
        STZ.B $02
        LDA.W #$00FF
        STA.B $04
CODE_8194EF: ; $0194EF
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
CODE_81950D: ; $01950D
        SEC
        SBC.B $00
CODE_819510: ; $019510
        STA.B $08
        LDA.W $096F
        CMP.B $02
        BCS CODE_819522
        STA.B $06
        LDA.B $02
        SEC
        SBC.B $06
        BRA CODE_819525
CODE_819522: ; $019522
        SEC
        SBC.B $02
CODE_819525: ; $019525
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
CODE_81953C: ; $01953C
        JSL.L getRandomValue
        AND.W #$0003
        BNE CODE_819553
CODE_819545: ; $019545
        SEP #$20
        LDA.B $00
        STA.W $0E04
        LDA.B $02
        STA.W $0E05
        REP #$20
CODE_819553: ; $019553
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
checkBattleCondition: ; $01956A
        STA.B $00
        LDA.W $0E0E
        AND.W #$0003
        TAY
        BEQ CODE_8195A2
        db $AD,$3A,$0E,$38,$ED,$BE,$0E,$B0,$03,$A9,$01,$00,$CD,$88,$0E,$B0
        db $1C,$C0,$03,$00,$F0,$20,$AD,$BA,$0E,$38,$ED,$3E,$0E,$B0,$03,$A9
        db $01,$00,$C0,$02,$00,$D0,$01,$0A,$CD,$08,$0E,$B0,$09
CODE_8195A2: ; $0195A2
        LDA.B $00
        STA.B $24
        LDA.B $0E
        STA.B $22
        RTS
        db $60,$3A,$00,$FF,$FF
        db $08,$00,$FF,$FF,$08,$80,$FF,$FF,$80,$00,$FF,$00,$80,$80,$FF,$00
        db $48,$00,$FF,$00,$07,$00,$FF,$00,$07,$80,$FF,$00
        db $81,$00,$FF,$FF
        db $81,$80,$FF,$FF
        db $3E,$80,$FF,$FF
        db $3E,$00,$FF,$FF
; [Entity] Awards XP, gold, items after battle victory. Entry: calculates based on enemy levels.
awardBattleRewards: ; $0195DC
        CPY.W #$0080
        BEQ CODE_8195EA
        CPY.W #$0081
        BEQ CODE_819612
        LDA.W $0E80,Y
        RTS
CODE_8195EA: ; $0195EA
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
CODE_819612: ; $019612
        LDA.W $0E3E
        STA.B $00
        LDA.W $0EBA
        SEC
        SBC.B $00
        BCS CODE_819622
        LDA.W #$0000
CODE_819622: ; $019622
        ASL A
        ASL A
        ASL A
        ASL A
        ASL A
        TAY
        LDA.W $0EB8
        BEQ CODE_819630
        JSR.W divideUnsigned16
CODE_819630: ; $019630
        RTS
; [Menu] Handles battle command menu - attack, magic, item, defend. Entry: called for player turn.
handleBattleMenu: ; $019631
        CMP.B $00
        BCS CODE_81963D
        STA.B $02
        LDA.B $00
        SEC
        SBC.B $02
        RTS
CODE_81963D: ; $01963D
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
        JSR.W getScenarioFlags
        BEQ CODE_81968D
        db $AD,$1A,$09,$CD,$04,$0E,$D0,$1C,$AD,$22,$09,$C9,$FF,$FF,$D0,$14
        db $20,$92,$8B,$AD,$1C,$09,$20,$D8,$9C,$BD,$04,$14,$85,$00,$20,$12
        db $8F,$4C,$38,$97
CODE_81968D: ; $01968D
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
        JSR.W textMetaLookup
        JSR.W evtCallRenderSprites
        JSR.W confirmAction
        LDA.W $0E04
        STA.B $00
        JSR.W lookupBattleEntityTile
        LDY.W #$0E00
        JSR.W saveEntityToBuffer
        LDA.W $0954
        BNE CODE_81971A
        LDA.W $0922
        CMP.W #$FFFF
        BEQ CODE_81971A
        LDA.W #$001D
        JSR.W textMetaLookup
        LDA.W #$000A
        JSR.W setTextColor
        LDA.W $091C
        JSR.W processEntityAction
        LDA.W $091C
        LDX.W #$0002
        LDY.W #$0000
        JSR.W flashScreen
        LDA.W #$000A
        JSR.W setTextColor
        LDA.W $0E28
        LDY.W #$0E80
        PHY
        JSR.W updateEntity
        INC.W $0E8F
        PLY
        JSR.W saveEntityToBuffer
        LDA.W $0922
        LDY.W #$0E00
        JSR.W updateEntity
        LDA.W $0E28
        JSR.W drawSpellEffect
        STZ.W $0E6E
        LDA.W #$0001
        JSR.W updateWeaponSwing
        JMP.W $8C65
CODE_81971A: ; $01971A
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
CODE_819746: ; $019746
        JSR.W checkScenarioTransition
        LDA.L $7FC00D
        AND.W #$00FF
        BEQ CODE_819755
        JSR.W evtEntityInitFromScript
CODE_819755: ; $019755
        JSR.W handleLoadScreen
        LDA.L $7EEA80
        INC A
        STA.L $7EEA80
        LDA.W #$0000
        JSR.W evtBattleDispatch
        JSR.W evtCallRenderSprites
        JSR.W confirmAction
        LDA.W #$0056
        JSR.W textMetaLookup
        LDA.L $7EEA80
        AND.W #$0001
        BEQ CODE_81978F
        LDA.L $7EEA84
        AND.W #$000F
        INC A
        CMP.W #$0003
        BCC CODE_81978C
        LDA.W #$0000
CODE_81978C: ; $01978C
        JSR.W drawBattleHUD
CODE_81978F: ; $01978F
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
CODE_8197CA: ; $0197CA
        JMP.W CODE_819880
CODE_8197CD: ; $0197CD
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_8197CA
        LDA.W $1410,X
        AND.W #$00FF
        BEQ CODE_8197CA
        STA.B $00
        CMP.W #$0001
        BEQ CODE_819857
        db $C9,$06,$00,$F0,$2F,$C9,$02,$00,$F0,$02,$80,$DA,$22,$72,$DF,$00
        db $29,$03,$00,$D0,$D1,$E2,$20,$9E,$10,$14,$AD,$34,$09,$C9,$10,$B0
        db $03,$9E,$0F,$14,$C2,$20,$A9,$95,$00,$A0,$00,$00,$AE,$34,$09,$20
        db $A0,$98,$80,$B2,$DA,$E2,$20,$BD,$04,$14,$85,$22,$BD,$05,$14,$85
        db $24,$C2,$20,$A9,$1F,$00,$22,$47,$DF,$00,$85,$0E,$20,$5A,$9C,$C9
        db $04,$00,$B0,$1E,$BD,$10,$14,$85,$00,$29,$FF,$00,$D0,$14,$A5,$00
        db $18,$69,$06,$00,$9D,$10,$14,$A9,$94,$00,$A0,$02,$00,$A6,$0E,$20
        db $A0,$98,$FA
CODE_819857: ; $019857
        LDA.W $1408,X
        PHA
        TAY
        LDA.W #$0007
        JSR.W multiplyUnsigned16
        LSR A
        LSR A
        LSR A
        INC A
        STA.W $1408,X
        STA.B $12
        PLA
        SEC
        SBC.B $12
        STA.W $0E5A
        BEQ CODE_819880
        LDA.W #$0096
        LDY.W #$0008
        LDX.W $0934
        JSR.W setupShopEntity
CODE_819880: ; $019880
        INC.W $0934
        LDA.W $0934
        CMP.W #$0020
        BEQ CODE_81988E
        JMP.W $9792
CODE_81988E: ; $01988E
        JSR.W skipCutscene
        JSR.W checkScenarioTransition
        JSR.W checkScrollLimit
        JSR.W initScenarioDisplay
        STZ.W $091C
        JMP.W CODE_81814F
; [Entity] Stores X to $0936; entity update+text meta+draw; waits 50 frames
setupShopEntity: ; $0198A0
        STX.W $0936
        PHY
        PHA
        JSR.W handleShopMenu
        LDA.W $0936
        LDY.W #$0E00
        JSR.W updateEntity
        LDA.W $0936
        JSR.W processEntityAction
        PLA
        JSR.W textMetaLookup
        LDA.W $0936
        PLY
        JSR.W flashScreen
        LDA.W #$0032
        JSR.W drawSaveScreen
        RTS
; [HUD] Draws battle HUD - HP/MP bars, command list, turn order. Entry: updates each turn.
drawBattleHUD: ; $0198C9
        SEP #$20
        STA.L $7EEA84
        REP #$20
        JSL.L clearOAMBuffer
        LDA.W #$0082
        STA.B $00
        LDA.W #$0005
        STA.B $02
        JSR.W enableInterrupts
        LDA.W #$0002
        STA.B $00
        LDA.W #$0005
        STA.B $02
        LDA.W #$0000
        JSR.W disableInterrupts
        RTS
; Calls lookupTilemapTile ($A70D), reads $0E28 battle data, accesses $1404 entity buffer.
lookupBattleEntityTile: ; $0198F3
        REP #$20
        LDA.B $00
        STA.B $24
        JSR.W lookupTilemapTile
        STX.B $14
        LDA.W $0E28
        JSR.W initBattleState
        LDA.W $1404,X
        STA.B $22
        LDA.W #$1000
        STA.B $26
CODE_81990E: ; $01990E
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
CODE_819951: ; $019951
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
animateBattleAttack: ; $019964
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
CODE_81997B: ; $01997B
        CMP.B $28
        BCS CODE_819980
        RTS
CODE_819980: ; $019980
        STA.B $28
        LDA.B $24
        CLC
        ADC.B $02
        STA.B $04
        STX.B $16
        RTS
; [Animation] Animates spell casting - glow effects, projectile. Entry: A=spell ID, X=caster, Y=target.
animateSpellCast: ; $01998C
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
CODE_8199BB: ; $0199BB
        JSR.W evtCallRenderSprites
        JSR.W confirmAction
        LDX.W $0916
        LDA.W $1800,X
        AND.W #$0800
        BNE CODE_8199BB
        RTS
; [Effects] Draws floating damage numbers in battle. Entry: A=damage amount, $00/$02=position.
drawDamageNumbers: ; $0199CD
        REP #$20
        LDA.W $0E28
        PHA
        LDA.W $0EA8
        LDY.W #$0E00
        JSR.W updateEntity
        LDA.W $0E08
        BNE CODE_8199E7
        PLA
        JSR.W updateStatusEffects
        BRA CODE_8199F8
CODE_8199E7: ; $0199E7
        PLA
        LDY.W #$0E00
        JSR.W updateEntity
        LDA.W $0E08
        BNE CODE_8199F8
        db $20,$05,$9A,$80,$00
CODE_8199F8: ; $0199F8
        LDA.W #$001F
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        RTS
; [Entity] Updates status effect timers and applications. Entry: called each turn for all units.
updateStatusEffects: ; $019A05
        LDA.W $0E28
        STA.W $093C
        LDA.L $7FC010
        AND.W #$00FF
        BEQ CODE_819A1A
        CMP.W $093C
        BNE CODE_819A1A
        RTS
CODE_819A1A: ; $019A1A
        LDA.W #$000A
        JSR.W setTextColor
        JSR.W advanceScrollPosition
        LDA.W #$001B
        JSR.W textMetaLookup
        LDA.W $093C
        LDY.W #$0003
        JSR.W flashScreen
        LDA.W #$0014
        JSR.W setTextColor
        LDA.W #$0016
        JSR.W setTimerValue
        LDA.W $093C
        LDY.W #$0088
        JSR.W flashScreen
        LDA.W #$000A
        JSR.W setTextColor
        LDA.W $093C
        LDY.W #$0E00
        JSR.W updateEntity
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
CODE_819A70: ; $019A70
        PHX
        JSR.W evtCallRenderSprites
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
        JSR.W saveEntityToBuffer
        RTS
; [Entity] Checks if ability can be used (MP, conditions). Entry: A=ability ID, X=caster. Returns carry if usable.
checkAbilityCondition: ; $019A99
        STA.L $7F9000,X
        PHX
        JSR.W evtTileDecompressMap
        JSR.W evtScrollInitFull
        PLX
        RTS
; [Entity] Executes special ability in battle. Entry: A=ability ID, X=caster, Y=target.
executeAbility: ; $019AA6
        PHA
        JSR.W handleStatusScreen
        PLA
        CMP.W #$FFFE
        BNE CODE_819ABB
        LDA.L $7F9000,X
        AND.W #$01FF
        STA.W $0A08
        RTS
CODE_819ABB: ; $019ABB
        CMP.W #$FFFF
        BNE CODE_819AF5
        db $64,$02,$84,$01,$98,$29,$7F,$00,$85,$00,$BF,$00,$90,$7F,$C5,$00
        db $D0,$04,$A5,$02,$80,$09,$C5,$02,$D0,$04,$A5,$00,$80,$01,$60,$48
        db $98,$29,$80,$00,$F0,$0C,$A9,$2A,$00,$20,$99,$9A,$A9,$2B,$00,$20
        db $99,$9A,$68,$80,$A4
CODE_819AF5: ; $019AF5
        STA.L $7F9000,X
        RTS
; [Menu] Handles item use in battle. Entry: A=item ID, X=user, Y=target. Applies item effect.
handleItemBattle: ; $019AFA
        REP #$20
        LDX.W #$0000
        STZ.W $0920
        LDA.W #$007F
        STA.B $14
        LDA.W #$F400
        STA.B $12
CODE_819B0C: ; $019B0C
        LDA.L $7FC0C8,X
        BNE CODE_819B13
        RTS
CODE_819B13: ; $019B13
        STA.B $04
        LDA.L $7FC0CA,X
        STA.B $06
        AND.W #$00FF
        CMP.W #$0040
        BEQ CODE_819B2B
CODE_819B23: ; $019B23
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_819B0C
CODE_819B2B: ; $019B2B
        LDA.B $22
        STA.B $00
        LDA.B $04
        AND.W #$00FF
        JSR.W subtractClamped
        STA.B $08
        LDA.B $24
        STA.B $00
        LDA.B $05
        AND.W #$00FF
        JSR.W subtractClamped
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
fleeBattle: ; $019BB2
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
CODE_819BD3: ; $019BD3
        STY.B $0E
CODE_819BD5: ; $019BD5
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
CODE_819C0A: ; $019C0A
        INC.B $0E
        LDA.B $0E
        CMP.W #$0020
        BNE CODE_819BD5
        LDA.B $0C
        RTS
; [GameState] Sets up battle formation positions. Entry: A=formation ID. Positions party and enemies.
setupBattleFormation: ; $019C16
        REP #$20
        LDA.W #$0000
        STA.B $0E
        LDA.W #$FFFF
        STA.B $0C
        LDY.W #$0010
CODE_819C25: ; $019C25
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
CODE_819C3F: ; $019C3F
        SEP #$20
        STA.W $0E25
        REP #$20
        LDA.B $0E
        STA.B $0C
        CMP.W $0E5A
        BNE CODE_819C51
        PLY
        RTS
CODE_819C51: ; $019C51
        PLY
        INC.B $0E
        DEY
        BNE CODE_819C25
        LDA.B $0C
        RTS
; [VRAM] Loads battle background graphics. Entry: A=background ID. Loads tiles and palette to VRAM.
loadBattleBackground: ; $019C5A
        LDA.B $0E
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        BNE CODE_819C6D
        LDA.W #$03E7
        STA.B $02
        RTS
CODE_819C6D: ; $019C6D
        SEP #$20
        LDA.W $1404,X
        CMP.B $22
        BCS CODE_819C7F
        STA.B $00
        LDA.B $22
        SEC
        SBC.B $00
        BRA CODE_819C82
CODE_819C7F: ; $019C7F
        SEC
        SBC.B $22
CODE_819C82: ; $019C82
        STA.B $02
        LDA.W $1405,X
        CMP.B $24
        BCS CODE_819C94
        STA.B $00
        LDA.B $24
        SEC
        SBC.B $00
        BRA CODE_819C97
CODE_819C94: ; $019C94
        SEC
        SBC.B $24
CODE_819C97: ; $019C97
        CLC
        ADC.B $02
        REP #$20
        AND.W #$00FF
        STA.B $02
        RTS
; [Music] Plays battle music based on enemy type. Entry: A=music track ID (0=normal, 1=boss).
playBattleBGM: ; $019CA2
        REP #$20
        CMP.W #$0100
        BCS CODE_819CB0
        STA.B $0E
        JSR.W initBattleState
        BRA CODE_819CCF
CODE_819CB0: ; $019CB0
        LDA.W #$0010
        STA.B $0E
CODE_819CB5: ; $019CB5
        LDA.B $0E
        CMP.W #$001F
        BCC CODE_819CC0
        db $A9,$FF,$FF,$60
CODE_819CC0: ; $019CC0
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_819CCF
        INC.B $0E
        BRA CODE_819CB5
CODE_819CCF: ; $019CCF
        TXA
        CLC
        ADC.W #$1400
        TAY
        LDA.B $0E
        RTS
; [GameState] Initializes battle state variables. Entry: sets up turn order, AI states, battle flags.
initBattleState: ; $019CD8
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
cleanupBattle: ; $019CE6
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
transitionToBattle: ; $019CF3
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
CODE_819D01: ; $019D01
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
; [Script] Battle dispatcher. If A==3, JMP handleShopMenu. Else sets up battle with Y=$10 (A==2) or other formations. Called by evtCmd29.
evtBattleDispatch: ; $019D33
        REP #$20
        STA.W $0914
        CMP.W #$0003
        BNE CODE_819D40
        JMP.W handleShopMenu
CODE_819D40: ; $019D40
        STZ.B $0E
        LDY.W #$0010
        CMP.W #$0002
        BNE CODE_819D4F
        LDY.W #$0020
        BRA CODE_819D7D
CODE_819D4F: ; $019D4F
        LDA.W $0914
        BNE CODE_819D59
        LDA.W #$0010
        STA.B $0E
CODE_819D59: ; $019D59
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
CODE_819D7D: ; $019D7D
        PHY
        LDA.B $0E
        JSR.W initBattleState
        STZ.B $00
        LDA.W $1410,X
        STA.W $0E10
        JSR.W titleScreenLoop
        BEQ CODE_819D92
        db $E6,$00
CODE_819D92: ; $019D92
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
CODE_819DB1: ; $019DB1
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
        JSR.W enableInterrupts
        JSR.W confirmAction
        RTS
; [Menu] Handles shop menu - buy/sell items, view inventory. Entry: A=shop type (0=item, 1=weapon, 2=armor).
handleShopMenu: ; $019DD2
        JSR.W confirmAction
        JSR.W evtEntityInitScene
        STZ.B $0E
        STZ.W $094C
CODE_819DDD: ; $019DDD
        LDA.B $0E
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_819E50
        LDA.W $1403,X
        AND.W #$003F
        PHA
        JSR.W searchDataTable
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
CODE_819E1C: ; $019E1C
        CMP.W #$0002
        BNE CODE_819E2B
        LDA.B $02
        AND.W #$E1FF
        ORA.W #$0E00
        STA.B $02
CODE_819E2B: ; $019E2B
        LDA.W #$C000
        TRB.B $04
CODE_819E30: ; $019E30
        LDA.W $1404,X
        STA.B $00
        LDA.B $0E
        CMP.W #$0010
        BCC CODE_819E44
        LDA.W #$4000
        TSB.B $02
        INC.W $094C
CODE_819E44: ; $019E44
        LDA.B $0E
        CMP.W $0956
        BCC CODE_819E4D
        INC.B $06
CODE_819E4D: ; $019E4D
        JSR.W transitionToBattle
CODE_819E50: ; $019E50
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
CODE_819ED0: ; $019ED0
        RTS
; [Menu] Draws shop stock list with prices. Entry: reads shop inventory from ROM table.
drawShopStock: ; $019ED1
        REP #$20
        STZ.B $0E
        LDX.W #$0000
CODE_819ED8: ; $019ED8
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_819EEA
        LDA.W $1404,X
        CMP.B $00
        BNE CODE_819EEA
        LDA.B $0E
        RTS
CODE_819EEA: ; $019EEA
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
; [Entity] Iterates entity $1800; finds nearest to ($00,$02) by abs distance
searchEntityByPosition: ; $019EFD
        REP #$20
        STZ.B $0E
        LDX.W #$0000
CODE_819F04: ; $019F04
        LDA.W $1800,X
        AND.W #$00FF
        BEQ CODE_819F4A
        LDA.W $1802,X
        CMP.B $00
        BCC CODE_819F18
        SEC
        SBC.B $00
        BRA CODE_819F1F
CODE_819F18: ; $019F18
        STA.B $04
        LDA.B $00
        SEC
        SBC.B $04
CODE_819F1F: ; $019F1F
        STA.B $06
        LDA.W $1804,X
        CMP.B $02
        BCC CODE_819F2D
        SEC
        SBC.B $02
        BRA CODE_819F34
CODE_819F2D: ; $019F2D
        STA.B $04
        LDA.B $02
        SEC
        SBC.B $04
CODE_819F34: ; $019F34
        CLC
        ADC.B $06
        CMP.W #$0010
        BCS CODE_819F4A
        LDA.B $0E
        CMP.W #$0010
        BCC CODE_819F44
        RTS
CODE_819F44: ; $019F44
        CMP.W #$0008
        BCS CODE_819F4A
        RTS
CODE_819F4A: ; $019F4A
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
handleInn: ; $019F5D
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
CODE_819F7A: ; $019F7A
        LDA.B $64
        BEQ CODE_819F84
        db $20,$E7,$F6,$20,$EE,$B7
CODE_819F84: ; $019F84
        LDA.W #$0003
        JSR.W setTimerValue
        RTS
CODE_819F8B: ; $019F8B
        LDA.B $50
        AND.W #$F0F0
        BNE CODE_819F7A
        LDA.B $4F
        AND.W #$000F
        BNE CODE_819F9C
        JMP.W $A12B
CODE_819F9C: ; $019F9C
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
CODE_819FCC: ; $019FCC
        LDA.W $0908
        AND.W #$00FC
        CMP.W #$0048
        BNE CODE_819FDF
        LDA.W $0900
        JSR.W scrollLeftByDelta
        BRA CODE_81A018
CODE_819FDF: ; $019FDF
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
CODE_81A005: ; $01A005
        LDA.W $0908
        AND.W #$00FC
        CMP.W #$00A8
        BNE CODE_81A018
        LDA.W $0900
        JSR.W scrollRightByDelta
        BRA CODE_81A018
CODE_81A018: ; $01A018
        LDA.W $0900
        CMP.W #$0005
        BCC CODE_81A027
        db $A5,$4F,$29,$03,$00,$D0,$72
CODE_81A027: ; $01A027
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
CODE_81A04D: ; $01A04D
        LDA.W $0909
        AND.W #$00FC
        CMP.W #$0078
        BNE CODE_81A060
        LDA.W $0900
        JSR.W scrollDownByDelta
        BRA CODE_81A099
CODE_81A060: ; $01A060
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
CODE_81A086: ; $01A086
        LDA.W $0909
        AND.W #$00FC
        CMP.W #$0030
        BNE CODE_81A099
        LDA.W $0900
        JSR.W evtScrollClampY
        BRA CODE_81A099
CODE_81A099: ; $01A099
        JSR.W evtCallRenderSprites
        JSR.W updateConfigSettings
        JSR.W confirmAction
        PLY
        DEY
        BEQ CODE_81A0A9
        JMP.W $9FA5
CODE_81A0A9: ; $01A0A9
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
CODE_81A0C7: ; $01A0C7
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
        JSR.W textMetaLookup
        BRA CODE_81A103
CODE_81A0EA: ; $01A0EA
        LDA.W $0952
        BEQ CODE_81A0FD
        STZ.W $0952
        JSR.W initGameState
        LDA.W #$003B
        JSR.W textMetaLookup
        BRA CODE_81A103
CODE_81A0FD: ; $01A0FD
        LDA.W #$0040
        JSR.W textMetaLookup
CODE_81A103: ; $01A103
        INC.B $57
CODE_81A105: ; $01A105
        JMP.W $9F65
CODE_81A108: ; $01A108
        CMP.W #$FFFF
        BEQ CODE_81A11B
        JSR.W initControllers
        INC.W $0952
        LDA.W #$007E
        JSR.W textMetaLookup
        BRA CODE_81A103
CODE_81A11B: ; $01A11B
        LDA.W $0952
        BEQ CODE_81A105
        STZ.W $0952
        LDA.W $0914
        JSR.W textMetaLookup
        BRA CODE_81A105
        JSR.W evtCallRenderSprites
        JSR.W updateConfigSettings
        JSR.W confirmAction
        JMP.W $9F65
; [Save] Handles save point interaction - save game, restore HP/MP. Entry: displays save menu.
handleSavePoint: ; $01A137
        REP #$20
        STA.W $092A
CODE_81A13C: ; $01A13C
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
        JSR.W checkEntityScreenBounds
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
CODE_81A16A: ; $01A16A
        STY.W $0F5A
        JSR.W handlePauseMenu
        LDA.W #$003F
        JSR.W textMetaLookup
        INC.B $57
CODE_81A178: ; $01A178
        JSR.W drawNumber
        JSR.W evtCallRenderSprites
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
CODE_81A197: ; $01A197
        BRA CODE_81A178
CODE_81A199: ; $01A199
        RTS
; [Tilemap] Draws world map screen with locations. Entry: loads world map tiles, marks current position.
drawWorldMap: ; $01A19A
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
CODE_81A1C9: ; $01A1C9
        CPX.B $00
        BEQ CODE_81A21F
        BCC CODE_81A21F
CODE_81A1CF: ; $01A1CF
        TXA
        JSR.W subtractClamped
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
CODE_81A1F1: ; $01A1F1
        CPX.B $00
        BEQ CODE_81A21F
        BCC CODE_81A21F
CODE_81A1F7: ; $01A1F7
        LDA.B $04
        BEQ CODE_81A1FD
        INC.B $04
CODE_81A1FD: ; $01A1FD
        TXA
        JSR.W subtractClamped
        STA.B $00
        LDA.B $51
        AND.W #$0003
        BEQ CODE_81A210
        LDA.B $00
        BEQ CODE_81A210
        INC.B $00
CODE_81A210: ; $01A210
        LDA.B $00
        CLC
        ADC.B $04
        CMP.B $08
        BCS CODE_81A21F
        STA.B $08
        LDA.B $06
        STA.B $16
CODE_81A21F: ; $01A21F
        INC.B $06
        LDA.B $06
        CMP.W $092C
        BEQ CODE_81A22B
        JMP.W $A1A3
CODE_81A22B: ; $01A22B
        LDA.B $16
        BMI CODE_81A232
        STA.W $0928
CODE_81A232: ; $01A232
        RTS
; [GameState] Handles world map navigation - movement between locations. Entry: processes map input.
handleWorldMap: ; $01A233
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
transitionToWorldMap: ; $01A258
        REP #$20
        LDX.W #$0008
; [Transition] Transitions from world map to location. Entry: fades out, loads location, fades in.
transitionFromWorldMap: ; $01A25D
        STA.B $04
        STX.W $0924
        STZ.B $64
        LDA.B $00
        AND.W #$FFF0
        SEC
        SBC.W #$006C
        BPL CODE_81A272
        LDA.W #$0000
CODE_81A272: ; $01A272
        CMP.W $0A46
        BCC CODE_81A27B
        LDA.W $0A46
        DEC A
CODE_81A27B: ; $01A27B
        CMP.W $0A4C
        BCS CODE_81A283
        LDA.W $0A4C
CODE_81A283: ; $01A283
        STA.B $22
        LDA.B $02
        AND.W #$FFF0
        SEC
        SBC.W #$0058
        BPL CODE_81A293
        LDA.W #$0000
CODE_81A293: ; $01A293
        CMP.W $0A48
        BCC CODE_81A29C
        LDA.W $0A48
        DEC A
CODE_81A29C: ; $01A29C
        CMP.W $0A4E
        BCS CODE_81A2A4
        LDA.W $0A4E
CODE_81A2A4: ; $01A2A4
        STA.B $24
        LDA.B $04
        BEQ CODE_81A2CE
        LDA.B $22
        STA.B $00
        LDA.B $60
        JSR.W subtractClamped
        CMP.W #$0028
        BCS CODE_81A2BC
        LDA.B $60
        STA.B $22
CODE_81A2BC: ; $01A2BC
        LDA.B $24
        STA.B $00
        LDA.B $62
        JSR.W subtractClamped
        CMP.W #$0028
        BCS CODE_81A2CE
        LDA.B $62
        STA.B $24
CODE_81A2CE: ; $01A2CE
        LDA.B $62
        CMP.B $24
        BEQ CODE_81A2F8
        BCC CODE_81A2E6
        SEC
        SBC.B $24
        CMP.W $0924
        BCC CODE_81A2E1
        LDA.W $0924
CODE_81A2E1: ; $01A2E1
        JSR.W evtScrollClampY
        BRA CODE_81A320
CODE_81A2E6: ; $01A2E6
        LDA.B $24
        SEC
        SBC.B $62
        CMP.W $0924
        BCC CODE_81A2F3
        LDA.W $0924
CODE_81A2F3: ; $01A2F3
        JSR.W scrollDownByDelta
        BRA CODE_81A320
CODE_81A2F8: ; $01A2F8
        LDA.B $60
        CMP.B $22
        BEQ CODE_81A32A
        BCC CODE_81A310
        SEC
        SBC.B $22
        CMP.W $0924
        BCC CODE_81A30B
        LDA.W $0924
CODE_81A30B: ; $01A30B
        JSR.W scrollLeftByDelta
        BRA CODE_81A320
CODE_81A310: ; $01A310
        LDA.B $22
        SEC
        SBC.B $60
        CMP.W $0924
        BCC CODE_81A31D
        LDA.W $0924
CODE_81A31D: ; $01A31D
        JSR.W scrollRightByDelta
CODE_81A320: ; $01A320
        JSR.W evtCheckDelay
        LDA.B $82
        INC A
        BEQ CODE_81A32A
        BRA CODE_81A2CE
CODE_81A32A: ; $01A32A
        RTS
; CMP $00; if >=, subtract; else TAY.
subtractClamped: ; $01A32B
        CMP.B $00
        BCC CODE_81A333
        SEC
        SBC.B $00
        RTS
CODE_81A333: ; $01A333
        TAY
        LDA.B $00
        STY.B $00
        SEC
        SBC.B $00
        RTS
; Reads $7FC011/$7FC012, calls playEventCutscene.
loadMapEventParams: ; $01A33C
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
playEventCutscene: ; $01A354
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
skipCutscene: ; $01A37C
        LDA.W $090A
        STA.B $02
        LDA.W $090C
        STA.B $04
; Checks entity at $0902/$0904 against visible screen rect.
checkEntityScreenBounds: ; $01A386
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
CODE_81A3C1: ; $01A3C1
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
handleConfigMenu: ; $01A3EA
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
CODE_81A409: ; $01A409
        TAX
        LDA.B $04
        JSR.W transitionFromWorldMap
        RTS
; [Save] Updates configuration settings in SRAM. Entry: writes options to save data.
updateConfigSettings: ; $01A410
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
CODE_81A449: ; $01A449
        LDA.W #$E0E0
        STA.W $0100
        STA.W $0104
        STA.W $0108
        STA.W $010C
CODE_81A458: ; $01A458
        RTS
CODE_81A459: ; $01A459
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
; [OAM] Clamps Y: $F4-$06, writes $06F0-$06FE.
clampSpriteY: ; $01A49E
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
CODE_81A4BB: ; $01A4BB
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
; [Init] SEI, OBSEL/CGWSEL/window/H-IRQ/enable.
initDisplayMode: ; $01A4FB
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
CODE_81A5B3: ; $01A5B3
        JSR.W checkScrollLimit
; [Script] cutsceneHandler(0), textMeta(#$0A), scenario intro.
initScenarioDisplay: ; $01A5B6
        REP #$20
        LDA.W #$0000
        JSR.W callCutsceneHandler
        LDA.W #$000A
        JSR.W textMetaLookup
        JSR.W commitDmaFlag
        LDA.L $7EEA82
        CLC
        ADC.W #$0B00
        JSR.W textMetaLookup
        RTS
; Checks $0904-$62 vs #$0082 scroll limit.
checkScrollBoundaryY: ; $01A5D3
        REP #$20
        LDA.W $0904
        SEC
        SBC.B $62
        CMP.W #$0082
        BCC initScrollCounter
; Increments $62 scroll, compares to $0A4A map limit.
advanceScrollPosition: ; $01A5E0
        LDA.B $62
        INC A
        CMP.W $0A4A
        BCC initScrollCounter
        INC.W $0944
        LDA.W $0A4A
        CLC
        ADC.W #$0010
        STA.W $0A48
CODE_81A5F5: ; $01A5F5
        LDA.W #$0004
        JSR.W scrollDownByDelta
        JSR.W evtCallRenderSprites
        JSR.W confirmAction
        LDA.B $62
        INC A
        CMP.W $0A48
        BNE CODE_81A5F5
; [Scrolling] $0A48=$0A4A+$10, cutsceneHandler(1), $06F3=#$54.
initScrollCounter: ; $01A609
        REP #$20
        LDA.W $0A4A
        CLC
        ADC.W #$0010
        STA.W $0A48
        LDA.W #$0001
        JSR.W callCutsceneHandler
        SEP #$20
        LDA.B #$54
        STA.W $06F3
        REP #$20
        LDA.W #$00A5
        STA.B $66
        RTS
; [Scrolling] $0A4A vs $0A48, INC $0944 if less.
checkScrollLimit: ; $01A62A
        REP #$20
        LDA.W $0A4A
        CMP.W $0A48
        BCS CODE_81A637
        INC.W $0944
CODE_81A637: ; $01A637
        STA.W $0A48
        LDA.W $0944
        BEQ CODE_81A662
        STZ.W $0944
CODE_81A642: ; $01A642
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
CODE_81A656: ; $01A656
        TYA
        JSR.W evtScrollClampY
        JSR.W evtCallRenderSprites
        JSR.W confirmAction
        BRA CODE_81A642
CODE_81A662: ; $01A662
        LDX.W #$04C0
        LDA.W #$0000
        LDY.W #$0020
CODE_81A66B: ; $01A66B
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
        JSR.W copyBufferLoop
        LDA.W #$0000
        JSR.W callCutsceneHandler
        SEP #$20
        LDA.B #$64
        STA.W $06F3
        REP #$20
        LDA.W #$00B5
        STA.B $66
        RTS
; [Tilemap] Stores #$44→$06F3 tile attr; #$0095→$66 cursor offset
setupCursorTile: ; $01A6A5
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
; [Tilemap] Reads $7F:C000/$C001 width/height; adjusts; stores $00/$02
readMapDimensions: ; $01A6B8
        LDA.L $7FC000
        AND.W #$00FF
        DEC A
        JSL.L hardwareMultiplyRng
        INC A
        STA.B $00
        LDA.L $7FC001
        AND.W #$00FF
        DEC A
        JSL.L hardwareMultiplyRng
        INC A
        STA.B $02
        RTS
; [Tilemap] Searches tilemap via $9ED1 until FFFF; checks $7F:9000 passability
findEmptyMapTile: ; $01A6D7
        JSR.W readMapDimensions
        LDA.B $02
        STA.B $01
        JSR.W drawShopStock
        CMP.W #$FFFF
        BNE findEmptyMapTile
        LDA.B $00
        PHA
        JSR.W lookupTilemapTile
        PLA
        STA.B $00
        LDA.L $7F9000,X
        AND.W #$0400
        BNE findEmptyMapTile
        RTS
        db $85,$04,$20,$B8,$A6,$20,$29,$A7,$BF,$00,$90,$7F,$29,$FF,$01,$C5
        db $04,$D0,$EF,$60
; Reads tile from $7F:9000, extracts tile# AND $01FF, returns VRAM offset in Y.
lookupTilemapTile: ; $01A70D
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
handleStatusScreen: ; $01A729
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
drawEquipmentScreen: ; $01A73D
        REP #$20
        LDA.W #$0022
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.L $7FC004
        AND.W #$00FF
        JSR.W advanceDataPointer
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
CODE_81A76E: ; $01A76E
        LDY.W #$0000
        LDX.W #$0000
CODE_81A774: ; $01A774
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
CODE_81A794: ; $01A794
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
handleEquipment: ; $01A7B1
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
drawMagicScreen: ; $01A7E2
        REP #$20
        AND.W #$00FF
        DEC A
        PHA
        LDA.W #$000B
        STA.B $14
        LDA.W #$8000
        STA.B $12
        PLA
        JSR.W advanceDataPointer
        LDX.W #$0000
        LDY.W #$0800
CODE_81A7FD: ; $01A7FD
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
handleMagicScreen: ; $01A836
        REP #$20
        JSR.W drawMagicScreen
; [Menu] Draws party formation screen. Entry: shows character positions, allows rearrangement.
drawFormationScreen: ; $01A83B
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
CODE_81A878: ; $01A878
        SEC
        SBC.W #$000A
        INC.B $14
CODE_81A87E: ; $01A87E
        JSR.W copyTilemapFromWram
        LDA.W #$007F
        STA.B $14
        LDA.W #$9000
        STA.B $12
        LDA.W #$1000
        LDX.W #$0000
        JSL.L memfillWords
        LDA.W $0942
        BEQ CODE_81A89F
        JSR.W writeTilemapToBuffer
        BRA CODE_81A8E2
CODE_81A89F: ; $01A89F
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
CODE_81A8BB: ; $01A8BB
        JSR.W lookupTableEntryWrapper
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
CODE_81A8E2: ; $01A8E2
        JSR.W evtTileDecompressMap
        JSR.W initScrollLimits
        LDA.L $7FC000
        AND.W #$00FF
        STA.W $090E
        LDA.L $7FC001
        AND.W #$00FF
        STA.W $0910
        JSR.W drawEquipmentScreen
        LDA.W $0942
        BNE CODE_81A90F
        JSR.W loadMapEventParams
        JSR.W initEntityBatch
        JSR.W drawSystemMenu
        BRA CODE_81A928
CODE_81A90F: ; $01A90F
        JSL.L initNewGame
        LDA.L $7EEA86
        AND.W #$00FF
        STA.B $02
        LDA.L $7EEA87
        AND.W #$00FF
        STA.B $04
        JSR.W playEventCutscene
CODE_81A928: ; $01A928
        LDY.W #$001F
        LDA.L $7EEA82
        CMP.W #$0019
        BNE CODE_81A936
        db $88,$88
CODE_81A936: ; $01A936
        STY.W $0956
        LDA.L $7EEA82
        CMP.W #$0026
        BNE CODE_81A949
        db $A9,$08,$00,$22,$6B,$CF,$00
CODE_81A949: ; $01A949
        JSR.W handleMapScreen
        RTS
; [Menu] Handles formation editing - move characters, save layout.
handleFormation: ; $01A94D
        LDA.B $16
        STA.B $1A
        LDA.W #$001E
        STA.B $02
CODE_81A956: ; $01A956
        LDY.W #$0000
        LDX.W #$0028
CODE_81A95C: ; $01A95C
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
; [Entity] Shifts unit list $1400 down by $20-byte slot; clears last
removeUnitFromList: ; $01A97C
        REP #$20
        STA.B $22
        JSR.W initBattleState
CODE_81A983: ; $01A983
        INC.B $22
        LDA.B $22
        CMP.W #$0010
        BEQ CODE_81A99C
        LDY.W #$0010
CODE_81A98F: ; $01A98F
        LDA.W $1420,X
        STA.W $1400,X
        INX
        INX
        DEY
        BNE CODE_81A98F
        BRA CODE_81A983
CODE_81A99C: ; $01A99C
        LDA.W #$0000
        STA.W $1400,X
        RTS
; [Menu] Draws item inventory screen. Entry: shows all items with quantities.
drawItemScreen: ; $01A9A3
        REP #$20
        CMP.W #$0080
        BCC CODE_81A9B0
        AND.W #$007F
        JMP.W $AEF6
CODE_81A9B0: ; $01A9B0
        STA.B $22
        STZ.B $24
        LDX.W #$0000
CODE_81A9B7: ; $01A9B7
        LDA.W $1400,X
        BEQ CODE_81A9E2
        AND.W #$00FF
        BNE CODE_81A9CE
        db $BD,$08,$14,$F0,$08,$A5,$22,$D0,$04,$A5,$24,$85,$22
CODE_81A9CE: ; $01A9CE
        INC.B $24
        TXA
        CLC
        ADC.W #$0020
        TAX
        CPX.W #$0200
        BNE CODE_81A9B7
CODE_81A9DB: ; $01A9DB
        db $A9,$FF,$FF,$8D,$28,$0E,$60
CODE_81A9E2: ; $01A9E2
        LDA.B $22
        BNE CODE_81A9EA
        LDA.B $24
        STA.B $22
CODE_81A9EA: ; $01A9EA
        CMP.W #$0008
        BCS CODE_81A9DB
CODE_81A9EF: ; $01A9EF
        LDA.B $24
        CMP.B $22
        BEQ CODE_81AA0C
        BCC CODE_81AA0C
        JSR.W initBattleState
        LDY.W #$0010
CODE_81A9FD: ; $01A9FD
        LDA.W $13E0,X
        STA.W $1400,X
        INX
        INX
        DEY
        BNE CODE_81A9FD
        DEC.B $24
        BRA CODE_81A9EF
CODE_81AA0C: ; $01AA0C
        LDA.B $22
        TAY
        LDA.W #$0013
        JSR.W handleSystemMenu
        JSR.W handleItemScreen
        LDY.W #$0E00
        JSR.W saveEntityToBuffer
        LDA.W $0E28
        RTS
; [Menu] Handles item screen - use, arrange, discard items.
handleItemScreen: ; $01AA22
        LDA.W #$0004
        STA.B $02
        LDA.W #$0001
        STA.B $00
        JSR.W checkEntityFlag
        LDA.W #$0012
        STA.B $00
        JSR.W checkEntityFlag
        LDA.W #$0013
        STA.B $00
; [Entity] $00=1: INC $02. Else smoke(#$3F), INC->$02.
checkEntityFlag: ; $01AA3C
        LDA.B $00
        CMP.W #$0001
        BNE CODE_81AA47
        INC.B $02
        BRA CODE_81AA51
CODE_81AA47: ; $01AA47
        LDA.W #$003F
        JSL.L hardwareMultiplyRng
        INC A
        STA.B $02
CODE_81AA51: ; $01AA51
        LDX.W #$0000
CODE_81AA54: ; $01AA54
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
        BEQ checkEntityFlag
CODE_81AA6B: ; $01AA6B
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
; [Entity] 16x updateEntity+setupEntityParameter.
initEntityBatch: ; $01AA82
        REP #$20
        STZ.B $0E
        STZ.B $0C
CODE_81AA88: ; $01AA88
        LDA.B $0E
        LDY.W #$0E00
        JSR.W updateEntity
        LDA.W $0E00
        AND.W #$00FF
        CMP.W #$00FF
        BNE CODE_81AAAA
        LDA.W $0E38
        STA.W $0E08
        LDX.B $0C
        LDA.L $7FC018,X
        STA.W $0E04
CODE_81AAAA: ; $01AAAA
        INC.B $0C
        INC.B $0C
        LDY.W #$0E00
        JSR.W saveEntityToBuffer
        INC.B $0E
        LDA.B $0E
        CMP.W #$0010
        BNE CODE_81AA88
        RTS
; [Helper] $7FCE00, $24 entries, byte match. X or $FFFF.
searchDataTable: ; $01AABE
        SEP #$20
        PHX
        LDX.W #$0000
CODE_81AAC4: ; $01AAC4
        CMP.L $7FCE00,X
        BEQ CODE_81AAD7
        INX
        CPX.W #$0024
        BNE CODE_81AAC4
        REP #$20
        LDA.W #$FFFF
        PLX
        RTS
CODE_81AAD7: ; $01AAD7
        REP #$20
        TXA
        ASL A
        TAX
        LDA.L $008980,X
        PLX
        RTS
; [Menu] Handles map screen - zoom, pan, view different levels.
handleMapScreen: ; $01AAE2
        REP #$20
        LDX.W #$0000
        LDA.W #$FFFF
CODE_81AAEA: ; $01AAEA
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
CODE_81AB05: ; $01AB05
        LDA.W #$003F
        STA.B $00
        INY
        LDA.B [$12],Y
        BNE CODE_81AB14
        LDA.W #$00FF
        STA.B $00
CODE_81AB14: ; $01AB14
        DEY
        LDA.B [$12],Y
        AND.B $00
        JSR.W addToDataTable
        TYA
        CLC
        ADC.W #$0008
        TAY
        CPY.W #$00A0
        BNE CODE_81AB05
        LDY.W #$0000
CODE_81AB2A: ; $01AB2A
        LDA.W $1400,Y
        CMP.W #$EE00
        BEQ CODE_81AB49
        AND.W #$00FF
        BNE CODE_81AB3E
        LDA.W $140C,Y
        BNE CODE_81AB3E
        BRA CODE_81AB52
CODE_81AB3E: ; $01AB3E
        LDA.W $1403,Y
        AND.W #$003F
        JSR.W addToDataTable
        BRA CODE_81AB52
CODE_81AB49: ; $01AB49
        LDA.W $1403,Y
        AND.W #$007F
        JSR.W addToDataTable
CODE_81AB52: ; $01AB52
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
; [Helper] CPX#$11, searchDataTable, A->$7FCE00/12,X.
addToDataTable: ; $01AB6E
        CPX.W #$0011
        BCS CODE_81AB8E
        STA.B $02
        JSR.W searchDataTable
        CMP.W #$FFFF
        BNE CODE_81AB8E
        SEP #$20
        LDA.B $02
        STA.L $7FCE00,X
        ORA.B #$80
        STA.L $7FCE12,X
        INX
        REP #$20
CODE_81AB8E: ; $01AB8E
        RTS
; [GameState] Checks game progress flags for special events. Entry: checks $0A08, $0E28, $0EA8, $0E4E, $0ECE for progression conditions.
checkGameProgress: ; $01AB8F
        REP #$20
        LDA.W #$0047
        JSR.W textMetaLookup
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
        JSL.L calculateGameProgress
        BRA CODE_81ABCF
CODE_81ABC5: ; $01ABC5
        db $A9,$4D,$00,$20,$4A,$EE
CODE_81ABCB: ; $01ABCB
        db $A9,$01,$00,$60
CODE_81ABCF: ; $01ABCF
        REP #$20
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $01
        JSR.W lookupBattleEntityTile
        LDA.W #$0005
        JSR.W callCutsceneHandler
        JSR.W setupCursorTile
        LDY.W #$0000
CODE_81ABEA: ; $01ABEA
        PHY
        LDA.W $1208,Y
        STA.W $1027
        LDA.W $1028
; [Text] Draws text string instantly (static renderer). Entry: $12/$14=text pointer, $00/$02=position. Renders entire text block at once without timing delays. Used for menus, HUD, between-level text, item/spell names. Part of dual-renderer system's static renderer.
drawTextString: ; $01ABF4
        LDY.W #$1000
        JSL.L maskAndProcessValue
        LDA.W #$004C
        JSR.W textMetaLookup
        LDA.W $1037
        AND.W #$0030
        LSR A
        LSR A
        LSR A
        LSR A
        CLC
        ADC.W #$0024
        JSR.W textMetaLookup
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
        JSR.W textMetaLookup
        STZ.B $22
        STZ.B $24
CODE_81AC32: ; $01AC32
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
CODE_81AC51: ; $01AC51
        TYA
        JSR.W writeTilemapChar
        JSR.W drawNumber
        LDA.B $50
        BEQ CODE_81AC8E
        PHA
        STZ.B $24
        LDA.W #$0020
        JSR.W writeTilemapChar
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
CODE_81AC7E: ; $01AC7E
        TYA
        AND.W #$0400
        BEQ CODE_81AC8E
        LDA.B $22
        INC A
        CMP.W $1210
        BCS CODE_81AC8E
        STA.B $22
CODE_81AC8E: ; $01AC8E
        JSR.W evtCallRenderSprites
        INC.B $57
        JSR.W confirmAction
        BRA CODE_81AC32
CODE_81AC98: ; $01AC98
        db $A9,$02,$00,$60
CODE_81AC9C: ; $01AC9C
        LDA.B $22
        ASL A
        TAY
        LDA.W $1208,Y
        STA.W $0940
        JSR.W drawHealEffect
        LDA.W $0941
        AND.W #$00FF
        JSR.W runScreenEffect
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
CODE_81ACD3: ; $01ACD3
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
CODE_81ACEF: ; $01ACEF
        LDA.W $0E13
        STA.W $0E93
        REP #$20
        LDY.W #$0E80
        JSR.W saveEntityToBuffer
        LDA.W $0EA8
        LDY.W #$0E80
        JSR.W updateEntity
        LDA.W $0EB8
        STA.W $0E88
        LDY.W #$0E80
        JSR.W saveEntityToBuffer
        LDA.W $0E28
        LDY.W #$FFFF
        JSR.W spawnEntityWithFlag
        LDA.W $0EA8
        LDY.W #$FFFF
        JSR.W spawnEntityWithFlag
        LDY.W $0E81
        LDA.W $0E01
        JSL.L updateFlagTable
        LDA.W $0E28
        JSR.W removeUnitFromList
        JSR.W handleMapScreen
        LDA.W #$0000
        RTS
; [Entity] Processes entity loop for values 0-31. Entry: $0EA8=entity count, calls sub_00AD60 for each entity.
processEntityLoop: ; $01AD3B
        REP #$20
        LDA.W $0EA8
        STA.B $28
        CMP.W #$0020
        BCS CODE_81AD4A
        JSR.W $AD60
CODE_81AD4A: ; $01AD4A
        STZ.B $28
CODE_81AD4C: ; $01AD4C
        LDA.B $28
        CMP.W $0EA8
        BEQ CODE_81AD56
        JSR.W $AD60
CODE_81AD56: ; $01AD56
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
        CMP.B #$07
        BEQ CODE_81ADB5
        db $C9,$04,$F0,$2F,$A5,$28,$85,$0E,$AD,$84,$0E,$85,$22,$AD,$85,$0E
        db $85,$24,$C2,$20,$20,$5A,$9C,$E2,$20,$C9,$03,$90,$25,$80,$50
CODE_81AD98: ; $01AD98
        db $BD,$03,$14,$CD,$83,$0E,$F0,$1B,$80,$46
CODE_81ADA2: ; $01ADA2
        LDA.W $1411,X
        CMP.W $0E91
        BEQ CODE_81ADBB
        BRA CODE_81ADE8
        db $A5,$28,$CD,$A8,$0E,$F0,$08,$80,$33
CODE_81ADB5: ; $01ADB5
        LDA.B $28
        CMP.B #$10
        BCC CODE_81ADE8
CODE_81ADBB: ; $01ADBB
        REP #$20
        LDA.B $28
        JSR.W processEntityAction
        LDA.B $28
        LDY.W #$000A
        JSR.W flashScreen
        LDA.B $28
        LDY.W #$0009
        JSR.W flashScreen
        LDA.W #$0005
        JSL.L hardwareMultiplyRng
        CLC
        ADC.W $0E6E
        TAY
        LDA.B $28
        JSR.W applyDamageToUnit
        LDA.B $28
        JSR.W drawSpellEffect
CODE_81ADE8: ; $01ADE8
        REP #$20
        RTS
; [Entity] initBattleState, $1400,X, handleConfigMenu(X=$08).
processEntityAction: ; $01ADEB
        REP #$20
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_81AE03
        LDA.W $1404,X
        STA.B $00
        LDX.W #$0008
        JSR.W handleConfigMenu
CODE_81AE03: ; $01AE03
        RTS
        db $C2,$20,$C9,$00,$80,$90,$05,$29,$FF,$00,$80,$0F,$84,$26,$85,$00
        db $20,$D1,$9E,$C9,$FF,$FF,$D0,$01,$60,$A4,$26
; [Entity] Subtracts damage ($26 masked 12-bit) from HP $1408+X; text display
applyDamageToUnit: ; $01AE1F
        STY.B $26
        STA.B $28
        CMP.W #$0010
        BCC CODE_81AE2E
        TYA
        AND.W #$4000
        BNE CODE_81AE6F
CODE_81AE2E: ; $01AE2E
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
CODE_81AE50: ; $01AE50
        DEC A
        STA.B $26
        LDA.W #$0001
CODE_81AE56: ; $01AE56
        STA.W $1408,X
        LDA.W $1403,X
        AND.W #$00FF
        STA.B $24
        LDA.W #$0070
        JSR.W textMetaLookup
        LDA.B $28
        LDY.W #$0008
        JSR.W flashScreen
CODE_81AE6F: ; $01AE6F
        RTS
; [Menu] Draws system menu (save, load, config, quit). Entry: called from pause menu.
drawSystemMenu: ; $01AE70
        REP #$20
        LDA.L $7FC00E
        AND.W #$00FF
        STA.L $7EEA92
        STZ.B $22
CODE_81AE7F: ; $01AE7F
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
CODE_81AE97: ; $01AE97
        db $A2,$00,$00,$29,$FF,$00,$85,$28,$BF,$E6,$AE,$01,$85,$00,$DA,$A5
        db $28,$20,$D8,$9C,$BD,$04,$14,$18,$65,$00,$85,$00,$85,$2A,$20,$D1
        db $9E,$C9,$FF,$FF,$D0,$1A,$20,$0D,$A7,$BF,$00,$90,$7F,$29,$00,$04
        db $D0,$0E,$A5,$2A,$85,$00,$A0,$00,$01,$A5,$0C,$20,$16,$AF,$FA,$60
        db $FA,$E8,$E8,$E0,$10,$00,$D0,$C0,$A9,$FF,$FF,$8D,$55,$0A,$60,$00
        db $FF,$01,$FF,$01,$00,$01,$01,$00,$01,$FF,$01,$FF,$00,$FF,$FF
        REP #$20
        STA.B $0C
        LDA.B $00
        CMP.W #$FF00
        BCS CODE_81AE97
        JSR.W drawShopStock
        CMP.W #$FFFF
        BEQ CODE_81AF0D
        db $A9,$FF,$FF,$60
CODE_81AF0D: ; $01AF0D
        LDY.W #$0100
        LDA.B $0C
        JSR.W handleSystemMenu
        RTS
; [Menu] Handles system menu selections. Entry: processes save/load/config options.
handleSystemMenu: ; $01AF16
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
CODE_81AF43: ; $01AF43
        JSR.W drawLoadScreen
        LDA.B $0E
        LDY.W #$0E00
        JSR.W updateEntity
        LDA.W $0E38
        STA.W $0E08
        PLA
        BEQ CODE_81AF5A
        STA.W $0E04
CODE_81AF5A: ; $01AF5A
        LDY.W #$0E00
        JSR.W saveEntityToBuffer
        LDA.W $0E28
        RTS
; [Menu] Draws load game screen with save slots. Entry: shows save file info (time, party, location).
drawLoadScreen: ; $01AF64
        REP #$20
        STY.B $1A
        LDX.W #$0010
        LDA.W #$0000
CODE_81AF6E: ; $01AF6E
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
        JSL.L hardwareMultiplyRng
CODE_81AFB8: ; $01AFB8
        AND.B #$03
        STA.W $0011,Y
        REP #$20
        LDA.B $04
        STA.W $000C,Y
        LDA.W #$00FF
        STA.W $0008,Y
        LDA.W #$FFFF
        STA.W $0000,Y
CODE_81AFD0: ; $01AFD0
        RTS
; [Save] Handles load screen - select slot, confirm load. Entry: loads save data from SRAM.
handleLoadScreen: ; $01AFD1
        REP #$20
        LDX.W #$0000
        STZ.B $04
CODE_81AFD8: ; $01AFD8
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
CODE_81AFF7: ; $01AFF7
        TXA
        CLC
        ADC.W #$0004
        TAX
        BRA CODE_81AFD8
CODE_81AFFF: ; $01AFFF
        RTS
CODE_81B000: ; $01B000
        PHX
        LDA.L $7EEA80
        TAY
        LDA.B $02
        AND.W #$000F
        BEQ CODE_81B016
        INC A
        JSR.W divideHardware8
        LDA.W $4216
        BNE CODE_81B04C
CODE_81B016: ; $01B016
        db $A5,$03,$29,$FF,$00,$20,$F6,$AE,$C9,$FF,$FF,$F0,$29,$8D,$2E,$09
        db $A9,$35,$00,$20,$4A,$EE,$AD,$2E,$09,$48,$20,$EB,$AD,$20,$D2,$9D
        db $68,$A0,$00,$00,$20,$1E,$C9,$A9,$0A,$00,$20,$72,$B8,$AF,$92,$EA
        db $7E,$3A,$8F,$92,$EA,$7E
CODE_81B04C: ; $01B04C
        PLX
        BRA CODE_81AFF7
; [Entity] Masks A to 6 bits; indexes 64-entry jump table at $B05F
dispatchBattleAction: ; $01B04F
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
        JSR.W selectMapVariant
        LDA.W #$002E
        JSR.W textMetaLookup
        LDA.W #$001F
        STA.B $22
CODE_81B1A7: ; $01B1A7
        LDA.B $22
        JSR.W cleanupBattle
        LDA.W $1800,X
        AND.W #$00F0
        CMP.W #$00E0
        BNE CODE_81B1BA
        STZ.W $1804,X
CODE_81B1BA: ; $01B1BA
        DEC.B $22
        BPL CODE_81B1A7
        STZ.W $0934
CODE_81B1C1: ; $01B1C1
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
        JSR.W findEmptyMapTile
        LDA.W $0934
        JSR.W handleSaveScreen
        LDA.W $1800,X
        AND.W #$FF00
        STA.W $1800,X
        LDA.W $0934
        PHA
        JSR.W processEntityAction
        PLA
        LDY.W #$000C
        JSR.W flashScreen
        LDA.W #$003C
        JSR.W drawSaveScreen
CODE_81B205: ; $01B205
        INC.W $0934
        LDA.W $0934
        CMP.W #$0020
        BNE CODE_81B1C1
        RTS
; [Entity] Gets random entity from pool. Entry: calls updateLightningEffect for random value, checks $1800 table.
getRandomEntity: ; $01B211
        JSL.L getRandomValue
        AND.W #$001F
        STA.B $00
        JSR.W cleanupBattle
        LDA.W $1800,X
        AND.W #$00FF
        BEQ getRandomEntity
        LDA.B $00
        JSR.W processEntityAction
        RTS
; [Menu] Draws save game screen. Entry: shows save slots, allows overwrite confirmation.
drawSaveScreen: ; $01B22B
        PHA
        JSR.W evtCallRenderSprites
        JSR.W confirmAction
        PLA
        DEC A
        BNE drawSaveScreen
        RTS
; [Entity] Finds available entity slot. Entry: calls sub_009EFD, checks for $FFFF, reads $1800 table.
findAvailableEntity: ; $01B237
        JSR.W searchEntityByPosition
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
CODE_81B256: ; $01B256
        STA.W $1808,X
        LDA.W $1800,X
        AND.W #$FF00
        ORA.W #$08E3
        STA.W $1800,X
CODE_81B265: ; $01B265
        RTS
        JSR.W getRandomEntity
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
        JSR.W setupEntityData
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
        JSR.W setupEntityData
        LDA.W #$000E
        LDY.W #$0007
        JSR.W flashScreen
        LDA.W #$000F
        LDY.W #$0007
        JSR.W flashScreen
        LDA.W #$001F
        JSR.W setTimerValue
        STZ.W $0934
        STZ.W $0936
        STZ.W $0938
CODE_81B2C1: ; $01B2C1
        LDA.W $0936
        CMP.W #$0136
        BCS CODE_81B30A
        LDY.W $0934
        LDX.W #$0078
        LDA.W #$000E
        JSR.W calculatePositionOffset
        LDA.W $0934
        CLC
        ADC.W #$0100
        TAY
        LDX.W #$0020
        LDA.W #$000F
        JSR.W calculatePositionOffset
        LDA.W $0934
        CLC
        ADC.W #$0008
        STA.W $0934
        AND.W #$00F8
        BNE CODE_81B2F8
        INC.W $0938
CODE_81B2F8: ; $01B2F8
        LDA.W $0936
        CLC
        ADC.W $0938
        STA.W $0936
        JSR.W evtCallRenderSprites
        JSR.W confirmAction
        BRA CODE_81B2C1
CODE_81B30A: ; $01B30A
        STZ.W $18E0
        STZ.W $18F0
        JMP.W $B190
; [Physics] Calculates position offset for entity. Entry: A=type, X=base, Y=offset. Uses $0936, $0958 for calculations.
calculatePositionOffset: ; $01B313
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
CODE_81B32E: ; $01B32E
        LDA.W $0958
        CLC
        ADC.W #$0018
        CLC
        ADC.B $02
        STA.B $02
CODE_81B33A: ; $01B33A
        TYA
        JSR.W lookupSineTable
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
        JSR.W findAvailableEntity
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
; [Entity] Sets up entity data structure. Entry: A=entity type, Y=parameter. Writes to $1800-$180A structure.
setupEntityData: ; $01B456
        REP #$20
        PHA
        TYA
        JSR.W searchDataTable
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
handleSaveScreen: ; $01B565
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
confirmAction: ; $01B7EE
        PHP
        SEP #$20
        LDA.B $10
        CMP.B #$02
        BEQ CODE_81B805
        CMP.B #$03
        BEQ CODE_81B807
        STZ.B $10
        STZ.B $4A
CODE_81B7FF: ; $01B7FF
        LDA.B $4A
        BEQ CODE_81B7FF
        INC.B $10
CODE_81B805: ; $01B805
        PLP
        RTS
CODE_81B807: ; $01B807
        JSL.L setupVramDMATransfer
        BRA CODE_81B805
; [Dialogue] Draws message box for text display. Entry: $00/$02=position, $04/$06=size.
drawMessageBox: ; $01B80D
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
; [Dialogue] Prints text to message box with per-character timing (dialog boxes). Entry: $12/$14=text pointer. Handles line breaks, character-by-character display speed, calls waitTextAdvance for button press continuation. Part of per-character renderer for cinematic dialog. Used for story dialog boxes and NPC conversations.
printText: ; $01B822
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
; [Dialogue] Waits for button press to advance text. Entry: displays 'more' prompt, waits for input. Used after printText for dialog boxes where player controls text flow.
waitTextAdvance: ; $01B835
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
CODE_81B84B: ; $01B84B
        LDA.B #$3E
        STA.B $58
        BRA CODE_81B85E
; [Text] Clears text buffer for new message. Entry: resets text position variables ($09FC/$09FE), clears tilemap buffer area ($7E9000-$7E907F). Sets up for new message in dual-renderer system. Called before rendering any text block.
clearTextBuffer: ; $01B851
        PHP
        SEP #$20
        LDA.B $10
        CMP.B #$03
        BCS CODE_81B865
        LDA.B #$2E
        STA.B $58
CODE_81B85E: ; $01B85E
        JSR.W confirmAction
        LDA.B $58
        BNE CODE_81B85E
CODE_81B865: ; $01B865
        SEP #$20
        LDA.B #$8F
        STA.W $2100
        LDA.B #$03
        STA.B $10
        PLP
        RTS
; [Text] Sets text color palette for rendering. Entry: A=color index (0-15). Updates $0A02 priority/palette bits. Affects all subsequent character rendering until changed. Used for emphasis, different text types (dialog, menu, system messages).
setTextColor: ; $01B872
        PHP
        REP #$20
CODE_81B875: ; $01B875
        CMP.W #$0000
        BEQ CODE_81B882
        PHA
        JSR.W confirmAction
        PLA
        DEC A
        BRA CODE_81B875
CODE_81B882: ; $01B882
        PLP
        RTS
; [Text] Draws numeric value as decimal string. Entry: A=number (0-9999), $00/$02=screen position. Converts to decimal digits, renders using text system. Used for stats, gold, HP/MP values in HUD and menus.
drawNumber: ; $01B884
        PHP
        REP #$20
        LDA.B $4E
        PHA
        SEP #$20
CODE_81B88C: ; $01B88C
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
CODE_81B8B4: ; $01B8B4
        JSR.W clearBattleUnitState
        STZ.W $0E25
        JSR.W clearTextBuffer
        LDA.W #$000B
        JSL.L dispatchGameMode
        JSL.L setupDataStructure
        LDA.W #$000B
        JSR.W callCutsceneHandler
        LDA.W #$0001
        JSR.W waitTextAdvance
        STZ.W $0E26
        LDA.W #$0001
        STA.W $0E5A
        LDA.W $0986
        STA.B $22
        LDA.W $0988
        STA.B $24
        JSL.L initObjectTableAlt
        JSR.W initTilemapAndSync
        LDA.W #$0002
        STA.W $0E26
CODE_81B8F4: ; $01B8F4
        JSR.W drawWindowShadow
        LDA.B $82
        BMI CODE_81B90C
        LDA.W $1000
        BNE CODE_81B8F4
        LDA.W #$0000
        JSR.W waitTextAdvance
        LDA.W #$0040
        JSR.W drawStatComparison
CODE_81B90C: ; $01B90C
        RTS
; [Menu] Draws stat comparison (old vs new) for equipment. Entry: shows changes with +/- indicators.
drawStatComparison: ; $01B90D
        TAY
CODE_81B90E: ; $01B90E
        LDX.W #$1000
CODE_81B911: ; $01B911
        DEX
        BNE CODE_81B911
        DEY
        BNE CODE_81B90E
        RTS
        db $C2,$20,$20,$51,$B8,$A9,$14,$00,$22,$9C,$AB,$00,$20,$E2,$B9,$A9
        db $45,$00,$20,$4A,$EE,$20,$0D,$B8,$64,$22,$64,$24,$64,$26,$64,$28
        db $20,$84,$B8,$A5,$50,$29,$F0,$F0,$D0,$0B,$20,$79,$BA,$20,$D3,$BB
        db $20,$EE,$B7,$80,$EB,$20,$51,$B8,$22,$A4,$A9,$00,$A9,$01,$00,$60
; [Effects] Runs screen effect with timers and visual updates. Entry: sets up effect parameters, calls updateFilmGrain, updateScanlineEffects.
runScreenEffect: ; $01B958
        REP #$20
        PHA
        JSR.W initScreenTransition
        LDA.W #$0044
        JSR.W textMetaLookup
        JSL.L initObjectTable
        LDA.W #$0025
        JSR.W soundDispatcher
        JSR.W drawMessageBox
        LDA.W #$0064
        JSR.W setTextColor
        LDA.W #$0000
        JSL.L loadDspEffectParams
CODE_81B97E: ; $01B97E
        JSR.W confirmAction
        LDA.W $1200
        BNE CODE_81B97E
        LDA.W #$0002
        JSL.L loadDspEffectParams
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
CODE_81B9A6: ; $01B9A6
        JSR.W updateRandomEffect
        JSR.W handleInputEffect
        JSR.W buildHDMATable
        JSR.W confirmAction
        DEC.B $0E
        LDA.B $0E
        BNE CODE_81B9A6
        LDX.W #$FFBA
        LDY.W #$0000
        JSL.L setObjectOffsets
        PLA
        JSL.L initEntityObject
        JSL.L clearVRAM
        LDA.W #$0001
        JSL.L loadDspEffectParams
        LDA.W #$00C8
        JSR.W setTextColor
        LDA.W #$8001
        JSR.W soundDispatcher
        JSR.W clearTextBuffer
        RTS
; [Effects] Initializes screen transition effect. Entry: sets $0958=$FFFF, calls dispatchGameMode, sets up graphics.
initScreenTransition: ; $01B9E2
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
        JSL.L setTextScrollParams
        LDX.W #$0400
        LDY.W #$0020
CODE_81BA10: ; $01BA10
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
        JSL.L setTextScrollParams
        JSR.W setupHDMAEffect
        JSR.W clearBattleUnitState
        RTS
; [Effects] Updates random visual effect. Entry: uses $0C/$0E timers, calls updateLightningEffect for random value, updates $4F.
updateRandomEffect: ; $01BA3F
        REP #$20
        LDA.B $0C
        BNE CODE_81BA6B
        LDA.B $0E
        CMP.W #$0064
        BCS CODE_81BA4D
        RTS
CODE_81BA4D: ; $01BA4D
        LDA.W #$001E
        STA.B $0C
CODE_81BA52: ; $01BA52
        JSL.L getRandomValue
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
CODE_81BA6B: ; $01BA6B
        DEC.B $0C
        CMP.W #$0016
        BNE CODE_81BA74
        STZ.B $4E
CODE_81BA74: ; $01BA74
        RTS
        db $01,$02,$04,$08
; [Effects] Handles input-based effect movement. Entry: reads $4F for direction flags, updates $26 position based on input.
handleInputEffect: ; $01BA79
        LDA.B $4F
        AND.W #$0004
        BEQ CODE_81BA8A
        LDA.B $26
        CLC
        ADC.W #$0004
        STA.B $26
        BRA CODE_81BAC2
CODE_81BA8A: ; $01BA8A
        LDA.B $4F
        AND.W #$0008
        BEQ CODE_81BA9B
        LDA.B $26
        SEC
        SBC.W #$0004
        STA.B $26
        BRA CODE_81BAC2
CODE_81BA9B: ; $01BA9B
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
CODE_81BABB: ; $01BABB
        LDY.B $26
        JSR.W clampValue
        STA.B $26
CODE_81BAC2: ; $01BAC2
        LDA.W $0982
        CLC
        ADC.B $26
        CMP.W #$0180
        BCC CODE_81BAD6
        CMP.W #$FF80
        BCS CODE_81BAD6
        STZ.B $26
        BRA CODE_81BAE9
CODE_81BAD6: ; $01BAD6
        CMP.W #$0004
        BCS CODE_81BADE
        LDA.W #$0000
CODE_81BADE: ; $01BADE
        CMP.W #$FFFC
        BCC CODE_81BAE6
        LDA.W #$0000
CODE_81BAE6: ; $01BAE6
        STA.W $0982
CODE_81BAE9: ; $01BAE9
        LDA.B $4F
        AND.W #$0002
        BEQ CODE_81BAFA
        LDA.B $22
        CLC
        ADC.W #$0004
        STA.B $22
        BRA CODE_81BB32
CODE_81BAFA: ; $01BAFA
        LDA.B $4F
        AND.W #$0001
        BEQ CODE_81BB0B
        LDA.B $22
        SEC
        SBC.W #$0004
        STA.B $22
        BRA CODE_81BB32
CODE_81BB0B: ; $01BB0B
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
CODE_81BB2B: ; $01BB2B
        LDY.B $22
        JSR.W clampValue
        STA.B $22
CODE_81BB32: ; $01BB32
        LDA.W $0980
        CLC
        ADC.B $22
        CMP.W #$0100
        BCC CODE_81BB46
        CMP.W #$FF00
        BCS CODE_81BB46
        STZ.B $22
        BRA CODE_81BB59
CODE_81BB46: ; $01BB46
        CMP.W #$0004
        BCS CODE_81BB4E
        LDA.W #$0000
CODE_81BB4E: ; $01BB4E
        CMP.W #$FFFC
        BCC CODE_81BB56
        LDA.W #$0000
CODE_81BB56: ; $01BB56
        STA.W $0980
CODE_81BB59: ; $01BB59
        RTS
; [Math] Clamps value within boundaries. Entry: A=sign flag, Y=value, $00=step. Returns clamped value.
clampValue: ; $01BB5A
        AND.W #$8000
        BNE CODE_81BB72
        TYA
        CMP.W #$8000
        BCS CODE_81BB68
        SEC
        SBC.B $00
CODE_81BB68: ; $01BB68
        CMP.W #$FFF0
        BCC CODE_81BB70
        SEC
        SBC.B $00
CODE_81BB70: ; $01BB70
        BRA CODE_81BB83
CODE_81BB72: ; $01BB72
        TYA
        CMP.W #$8000
        BCC CODE_81BB7B
        CLC
        ADC.B $00
CODE_81BB7B: ; $01BB7B
        CMP.W #$0010
        BCS CODE_81BB83
        CLC
        ADC.B $00
CODE_81BB83: ; $01BB83
        RTS
; [Effects] Sets up HDMA effect table. Entry: configures $4360 HDMA channel, builds table at $7EA000.
setupHDMAEffect: ; $01BB84
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
CODE_81BBAC: ; $01BBAC
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
; [Effects] Builds HDMA table for screen effect. Entry: uses $0980-$0986 parameters, writes to $7EA000 table.
buildHDMATable: ; $01BBD3
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
CODE_81BBEC: ; $01BBEC
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
; Zero 8 bytes at $0E20-$0E27 (4 words). Battle unit data partial clear.
clearBattleDataSlot: ; $01BC16
        REP #$20
        LDX.W #$0020
        LDY.W #$0004
CODE_81BC1E: ; $01BC1E
        STZ.W $0E00,X
        INX
        INX
        DEY
        BNE CODE_81BC1E
        RTS
; Zero fields across $0E00-$0EDE for two battle units. Copy $0E25->$0EA5.
clearBattleUnitState: ; $01BC27
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
; dispatchGameMode(1), clearBattleUnitState, initObjectTable, setup battle params via $EB86/$B80D.
initBattleSequence: ; $01BC6D
        REP #$20
        LDA.W #$0001
        JSL.L dispatchGameMode
        JSR.W clearBattleUnitState
        JSR.W loadRomHeaderToWram
        JSR.W clearAndDispatchText
        JSL.L initObjectTable
        LDA.W #$0026
        JSR.W soundDispatcher
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
CODE_81BCA4: ; $01BCA4
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
        JSL.L hardwareMultiplyRng
        CLC
        ADC.W #$001D
        LDY.B $22
        JSR.W multiplyUnsigned16
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
CODE_81BD00: ; $01BD00
        STA.W $0E88
        LDY.W #$0E80
        JSR.W saveEntityToBuffer
        LDA.B $24
        STA.W $0E6E
        TAY
        LDA.W #$001E
        JSR.W multiplyUnsigned16
        TAY
        LDA.B $22
        JSR.W divideHardware8
        INC A
        PHA
        LDA.W #$00DC
        JSR.W setTextColor
        LDA.W #$001E
        JSR.W setTimerValue
        JSR.W loadRomHeaderToWram
        LDA.W #$002C
        JSR.W drawPartyFace
        LDA.W #$006E
        JSR.W setTextColor
        PLA
        BRA CODE_81BD6A
        db $A9,$6F,$00,$20,$D5,$C2,$20,$81,$BD,$A9,$FA,$00,$20,$72,$B8,$A9
        db $1E,$00,$20,$E5,$EB,$AD,$6C,$0E,$29,$FF,$00,$C9,$0C,$00,$D0,$0C
        db $A9,$72,$00,$20,$D5,$C2,$A9,$96,$00,$20,$72,$B8,$20,$98,$BD
CODE_81BD6A: ; $01BD6A
        STZ.W $0E5A
        JSR.W drawProgressBar
        LDA.W $0E88
        BNE CODE_81BD7E
        db $20,$34,$C2,$A9,$19,$00,$20,$DE,$C1
CODE_81BD7E: ; $01BD7E
        JMP.W CODE_81C0EC
; [Menu] Draws scroll bar for list menus. Entry: A=position, X=length, Y=total items.
drawScrollBar: ; $01BD81
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
; Calculates (random(5)+24) * $0E70 via hardware multiply.
calcBattleEffectDamage: ; $01BD98
        LDA.W #$0005
        JSL.L hardwareMultiplyRng
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
; [Effects] Sets up effect timer with calculations. Entry: calls calculateEffectValue, stores in $0E58, sets $0A00.
setupEffectTimer: ; $01BDB9
        REP #$20
        JSR.W calcBattleEffectDamage
        STA.W $0E58
        STZ.W $0E5A
        LDA.W #$005A
        JSR.W dispatchSceneText
        LDA.W #$0002
        STA.W $0A00
        JSR.W updateEffectAnimation
        STZ.W $0A00
        RTS
; [Menu] Handles list scrolling logic. Entry: processes up/down input, updates scroll position.
handleListScrolling: ; $01BDD7
        REP #$20
        STA.W $0964
        PHY
        LDA.W #$0001
        JSL.L dispatchGameMode
        JSR.W clearBattleUnitState
        JSL.L drawMap
        PLA
        JSR.W soundDispatcher
        JSR.W loadRomHeaderToWram
        JSR.W clearAndDispatchText
        JSL.L initObjectTable
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
        JSR.W textMetaLookup
        LDA.W #$0041
        JSR.W drawButtonIcons
        LDA.W $0964
        STA.W $0E68
        BEQ CODE_81BE2C
        JMP.W CODE_81BEBC
CODE_81BE2C: ; $01BE2C
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
CODE_81BE61: ; $01BE61
        SEP #$20
        LDA.B #$02
        STA.W $0E26
        REP #$20
CODE_81BE6A: ; $01BE6A
        REP #$20
        JSR.W drawBorder
        LDA.W $1004
        BEQ CODE_81BE83
        STZ.W $1004
        LDA.W #$0001
        JSR.W animateMenuSprite
        LDA.W #$0013
        JSR.W drawPartyFace
CODE_81BE83: ; $01BE83
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
CODE_81BEA3: ; $01BEA3
        STZ.W $0E66
        INC.W $0966
        LDA.W $0966
        CMP.W $0968
        BNE CODE_81BEB4
        JMP.W $C00C
CODE_81BEB4: ; $01BEB4
        CMP.W #$0002
        BNE CODE_81BEBC
        INC.W $0E24
CODE_81BEBC: ; $01BEBC
        LDA.W $0ED4
        AND.W #$00FF
        BNE CODE_81BEC7
        JMP.W $BF3C
CODE_81BEC7: ; $01BEC7
        SEP #$20
        STZ.W $0EA2
        STZ.W $0E22
        REP #$20
        LDA.W #$0001
        STA.W $0E5A
        JSL.L initObjectTable
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
CODE_81BEF8: ; $01BEF8
        SEP #$20
        LDA.B #$02
        STA.W $0EA6
        REP #$20
CODE_81BF01: ; $01BF01
        REP #$20
        JSR.W drawBorder
        LDA.W $1204
        BEQ CODE_81BF1A
        STZ.W $1204
        LDA.W #$0000
        JSR.W animateMenuSprite
        LDA.W #$0015
        JSR.W drawPartyFace
CODE_81BF1A: ; $01BF1A
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
CODE_81BF34: ; $01BF34
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
        JSL.L initObjectTable
        STZ.W $0E66
        INC.W $0966
        LDA.W $0966
        CMP.W $0968
        BNE CODE_81BF64
        JMP.W $C00C
CODE_81BF64: ; $01BF64
        CMP.W #$0002
        BNE CODE_81BF6C
        db $EE,$24,$0E
CODE_81BF6C: ; $01BF6C
        JMP.W CODE_81BE2C
CODE_81BF6F: ; $01BF6F
        LDA.W $0E52
        BNE CODE_81BF77
        db $4C,$3C,$BF
CODE_81BF77: ; $01BF77
        LDA.W #$0029
        JSR.W drawPartyFace
        JSL.L getRandomValue
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
        JSR.W saveEntityToBuffer
        PLY
        LDA.W $0E28
        JSR.W updateEntity
        LDA.W $0E38
        STA.W $0E08
        STZ.W $1060
        JSL.L clearVRAM
        JSR.W confirmAction
        LDA.W #$000E
        JSR.W setTimerValue
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
        JSL.L initSingleObject
        LDA.W #$0010
        STA.B $22
        LDA.W #$0004
        STA.B $24
        LDX.W #$0122
        LDY.W #$0000
        LDA.W #$0007
        JSR.W drawIcon
        JSR.W loadRomHeaderToWram
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
CODE_81C01A: ; $01C01A
        REP #$20
        LDA.W #$0014
        JSR.W drawButtonIcons
        LDA.W #$0002
        JSR.W setTimerValue
        LDA.W #$0032
        STA.B $2A
        STZ.B $4C
        JSR.W confirmAction
        LDA.W #$8001
        JSR.W soundDispatcher
        LDA.W #$0005
        JSR.W setTextColor
        INC.B $4C
        JSR.W confirmAction
        LDA.W $0E08
        BNE CODE_81C04B
        db $4C,$E5,$C0
CODE_81C04B: ; $01C04B
        LDA.W $0E6E
        BEQ CODE_81C056
        JSR.W calcBattleEffectDamage
        JMP.W CODE_81BD6A
CODE_81C056: ; $01C056
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
        JSR.W absOrZero
        LSR A
        LSR A
        JSR.W absValue
        CLC
        ADC.W #$0007
        CMP.W #$8000
        BCC CODE_81C085
        LDA.W #$0000
CODE_81C085: ; $01C085
        STA.B $00
        LDA.W #$0003
        JSL.L hardwareMultiplyRng
        CLC
        ADC.B $00
        BNE CODE_81C094
        INC A
CODE_81C094: ; $01C094
        STA.B $26
        STZ.B $28
        STZ.W $0E5A
        LDA.W $0E88
        BNE CODE_81C0CD
        INC.W $0E5A
        LDA.B $24
        SEC
        SBC.B $22
        JSR.W absOrZero
        ASL A
        ASL A
        JSR.W absValue
        CLC
        ADC.W #$0032
        CMP.W #$8000
        BCC CODE_81C0BC
        LDA.W #$0000
CODE_81C0BC: ; $01C0BC
        STA.B $28
        LDA.W #$0005
        JSL.L hardwareMultiplyRng
        CLC
        ADC.B $28
        BNE CODE_81C0CB
        INC A
CODE_81C0CB: ; $01C0CB
        STA.B $28
CODE_81C0CD: ; $01C0CD
        LDA.B $26
        CLC
        ADC.B $28
        JSR.W drawProgressBar
        LDA.W $0E5A
        BEQ CODE_81C0EC
        JSR.W calcRandomBattleParam
        LDA.W #$0019
        JSR.W drawButtonIcons
        BRA CODE_81C0EC
        db $E2,$20,$9C,$07,$0E,$C2,$20
CODE_81C0EC: ; $01C0EC
        LDY.W #$0E00
        JSR.W saveEntityToBuffer
        LDA.W #$0016
        JSR.W drawButtonIcons
        JSR.W clearTextBuffer
        STZ.B $4C
        RTS
; [Menu] Draws icon sprite (item, spell, status). Entry: A=icon ID, $00/$02=position.
drawIcon: ; $01C0FE
        PHA
        PHX
        STA.B $26
        STX.B $28
CODE_81C104: ; $01C104
        LDX.B $28
        LDA.B $22
        INC.B $22
        JSL.L setTextScrollParams
        LDA.B $24
        JSR.W setTextColor
        LDY.W #$0007
        DEC.B $26
        BNE CODE_81C104
        PLX
        PLA
        RTS
; [HUD] Draws progress bar (HP, MP, XP). Entry: A=current, X=max, $00/$02=position, Y=color.
drawProgressBar: ; $01C11D
        STA.B $00
        LDA.W #$1000
        JSR.W getScenarioFlags
        BEQ CODE_81C12B
        ASL.B $00
        DEC.B $00
CODE_81C12B: ; $01C12B
        LDA.B $00
        CMP.W #$0064
        BCC CODE_81C135
        LDA.W #$0063
CODE_81C135: ; $01C135
        STA.W $0E58
        LDA.W #$005A
        JSR.W drawPartyFace
; [Animation] Updates effect animation frame. Entry: processes $0E07 counter, updates animation based on $0E58 timer.
updateEffectAnimation: ; $01C13E
        LDA.W #$0017
        JSR.W setTimerValue
        STZ.W $0A0C
        STZ.W $0994
CODE_81C14A: ; $01C14A
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
        JSR.W textMetaLookup
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
CODE_81C18C: ; $01C18C
        REP #$20
        BRA CODE_81C14A
CODE_81C190: ; $01C190
        LDA.W #$001D
        JSR.W setTimerValue
        LDA.W #$0032
        JSR.W setTextColor
        LDA.W $0994
        BEQ CODE_81C1DD
        LDY.W #$0E00
        PHY
        JSR.W saveEntityToBuffer
        LDA.W $0E28
        PLY
        JSR.W updateEntity
        LDA.W #$001C
        JSR.W setTimerValue
        LDA.W #$005F
        JSR.W textMetaLookup
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
        JSR.W textMetaLookup
CODE_81C1DD: ; $01C1DD
        RTS
; [Text] Draws controller button icons in help text. Entry: A=button combination. Renders button graphics using special character codes ($D0 control code). Used in tutorials and help screens.
drawButtonIcons: ; $01C1DE
        STA.B $00
        LDA.W #$0001
        JSR.W getScenarioFlags
        BNE CODE_81C1EA
        ASL.B $00
CODE_81C1EA: ; $01C1EA
        LDY.B $00
CODE_81C1EC: ; $01C1EC
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
CODE_81C1FF: ; $01C1FF
        PLA
        RTS
; [HUD] Draws game time clock display. Entry: reads playtime counter, formats as HH:MM.
drawClock: ; $01C201
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
CODE_81C21B: ; $01C21B
        LDA.B $00
        CLC
        ADC.B $02
        CLC
        ADC.B $04
        PHA
        LDA.W $0051,Y
        AND.W #$00FF
        PLY
        JSR.W multiplyUnsigned16
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        RTS
; hardwareMultiplyRng(5) + hardwareMultiplyRng(6) -> $2A.
calcRandomBattleParam: ; $01C234
        LDA.W #$0005
        JSL.L hardwareMultiplyRng
        INC A
        STA.B $2A
        LDA.W #$0006
        JSL.L hardwareMultiplyRng
        STA.B $00
        LDA.W #$0006
        JSL.L hardwareMultiplyRng
        CLC
        ADC.B $00
        LDY.W #$0005
        JSR.W multiplyUnsigned16
        CLC
        ADC.B $2A
        STA.B $2A
        STA.B $2C
        STZ.B $2E
        LDA.W $0EA8
        CMP.W #$001F
        BEQ CODE_81C2C3
        LDA.W #$0010
        JSR.W getScenarioFlags
        BEQ CODE_81C2C3
        JSL.L getRandomValue
        AND.W #$0007
        BEQ CODE_81C27B
        BRA CODE_81C2C3
CODE_81C27B: ; $01C27B
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
CODE_81C2C3: ; $01C2C3
        LDA.L $7EEA8A
        CLC
        ADC.B $2C
        STA.L $7EEA8A
        LDA.W #$0050
        JSR.W drawPartyFace
        RTS
; [Menu] Draws character face portrait. Entry: A=character ID, $00/$02=position.
drawPartyFace: ; $01C2D5
        REP #$20
        CLC
        ADC.W #$C000
        JSR.W dispatchSceneText
        RTS
; [Menu] Draws character sprite in menu (animated). Entry: A=character ID, $00/$02=position.
drawCharacterSpriteMenu: ; $01C2DF
        REP #$20
        STZ.W $1C04
        STZ.W $1C06
        LDY.W #$0E00
        LDX.W #$0E80
        CMP.W #$0000
        BEQ CODE_81C2F8
        LDY.W #$0E80
        LDX.W #$0E00
CODE_81C2F8: ; $01C2F8
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
CODE_81C31A: ; $01C31A
        JMP.W CODE_81C4D8
CODE_81C31D: ; $01C31D
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
        JSL.L hardwareMultiplyRng
        CMP.B $00
        BCC CODE_81C349
        STZ.B $00
        JMP.W CODE_81C4D8
CODE_81C349: ; $01C349
        LDA.W $004A,X
        AND.W #$00FF
        STA.B $04
        LDA.W #$0064
        JSL.L hardwareMultiplyRng
        CMP.B $04
        BCS CODE_81C3B3
        SEP #$20
        LDA.B #$02
        STA.W $0023,X
        REP #$20
        LDA.W #$0001
        STA.W $005E,X
        LDA.W $0046,Y
        AND.W #$00FF
        LSR A
        SEC
        SBC.W #$000C
        BPL CODE_81C37B
        db $A9,$00,$00
CODE_81C37B: ; $01C37B
        STA.W $1C06
        STA.B $04
        LDA.W #$0064
        JSL.L hardwareMultiplyRng
        CMP.B $04
        BCC CODE_81C3AC
        db $B9,$28,$00,$F0,$1C,$C9,$1F,$00,$F0,$17,$B9,$16,$00,$29,$FF,$00
        db $C9,$4A,$00,$F0,$0C,$C9,$4B,$00,$F0,$07,$A9,$E7,$03,$99,$52,$00
        db $60
CODE_81C3AC: ; $01C3AC
        LDA.W #$0000
        STA.W $0052,Y
        RTS
CODE_81C3B3: ; $01C3B3
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
        JSR.W multiplyUnsigned16
        TAY
        LDA.W $0038,X
        JSR.W divideUnsigned16
        PLY
        JSR.W multiplyUnsigned16
        TAY
        LDA.W #$0096
        JSR.W divideHardware8
        INC A
        CMP.W #$0064
        BCC CODE_81C3F2
        db $A9,$63,$00
CODE_81C3F2: ; $01C3F2
        STA.W $1C04
        STA.B $00
        LDX.B $12
        LDY.B $14
        LDA.W #$0064
        JSL.L hardwareMultiplyRng
        CMP.B $00
        BCS CODE_81C441
        LDA.W $0010,Y
        AND.W #$00FF
        BNE CODE_81C441
        LDA.W $004B,X
        AND.W #$00FF
        STA.B $02
        LDA.W $0028,Y
        BEQ CODE_81C42E
        CMP.W #$001F
        BEQ CODE_81C441
        CMP.W #$0010
        BCC CODE_81C435
        LDA.B $02
        CMP.W #$0007
        BEQ CODE_81C441
        BRA CODE_81C435
CODE_81C42E: ; $01C42E
        db $A5,$02,$C9,$03,$00,$F0,$0C
CODE_81C435: ; $01C435
        LDA.B $02
        STA.W $0072,Y
        SEP #$20
        STA.W $0010,Y
        REP #$20
CODE_81C441: ; $01C441
        LDA.W $0060,Y
        PHY
        TAY
        LDA.W #$0005
        JSR.W divideHardware8
        PLY
        CMP.W #$0014
        BCC CODE_81C455
        db $A9,$14,$00
CODE_81C455: ; $01C455
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
CODE_81C47E: ; $01C47E
        LDA.B $06
        SEC
        SBC.B $02
        BMI CODE_81C4DE
        BEQ CODE_81C4DE
        LDY.B $00
        JSR.W multiplyUnsigned16
        TAY
        LDA.W #$0014
        JSR.W divideHardware8
        CMP.W #$0000
        BNE CODE_81C49B
        LDA.W #$0001
CODE_81C49B: ; $01C49B
        PHA
        JSL.L getRandomValue
        AND.W #$0003
        CLC
        ADC.W #$001E
        TAY
        PLA
        JSR.W multiplyUnsigned16
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        STA.B $00
        BNE CODE_81C4B7
        INC.B $00
CODE_81C4B7: ; $01C4B7
        LDX.B $12
        LDY.B $14
        LDA.W #$0064
        JSL.L hardwareMultiplyRng
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
CODE_81C4D8: ; $01C4D8
        LDA.B $00
        STA.W $0052,Y
        RTS
CODE_81C4DE: ; $01C4DE
        LDA.W #$0001
        STA.W $0052,Y
        RTS
; [Animation] Animates menu sprite (idle animation). Entry: updates sprite frame based on timer.
animateMenuSprite: ; $01C4E5
        REP #$20
        LDY.W #$0E00
        LDX.W #$0E80
        CMP.W #$0000
        BEQ CODE_81C4F8
        LDY.W #$0E80
        LDX.W #$0E00
CODE_81C4F8: ; $01C4F8
        LDA.W $0052,Y
        BNE CODE_81C4FE
        RTS
CODE_81C4FE: ; $01C4FE
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
        JSR.W multiplyUnsigned16
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
CODE_81C52A: ; $01C52A
        db $5A,$A0,$1B,$00,$20,$DB,$EE,$4A,$4A,$4A,$4A,$4A,$7A,$1A,$85,$00
CODE_81C53A: ; $01C53A
        LDA.B $00
        CMP.W #$0100
        BNE CODE_81C544
        db $A9,$FF,$00
CODE_81C544: ; $01C544
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
CODE_81C55D: ; $01C55D
        LDA.W $0027,Y
        INC A
        STA.W $0027,Y
        LDA.W #$0000
CODE_81C567: ; $01C567
        STA.W $0008,Y
        PHX
        PHY
        JSR.W saveEntityToBuffer
        JSR.W loadRomHeaderToWram
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
CODE_81C58D: ; $01C58D
        LDA.B $00
        JSL.L loadDspEffectParams
        RTS
; [Menu] Draws drop shadow for window. Entry: $00/$02=window position, $04/$06=size.
drawWindowShadow: ; $01C594
        JSR.W drawNumber
        LDA.B $82
        BEQ CODE_81C5A7
        LDA.B $4E
        AND.W #$3000
        BEQ CODE_81C5A7
        LDA.W #$FFFF
        STA.B $82
CODE_81C5A7: ; $01C5A7
        BRA CODE_81C5CA
; [Menu] Draws decorative border around element. Entry: A=border style, $00/$02=position.
drawBorder: ; $01C5A9
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
CODE_81C5C4: ; $01C5C4
        LDA.W #$0002
        STA.W $096A
CODE_81C5CA: ; $01C5CA
        LDA.W $0AA7
        BEQ CODE_81C60E
        CMP.W #$FF00
        BCC CODE_81C5D9
        JSR.W drawBackgroundPattern
        BRA CODE_81C626
CODE_81C5D9: ; $01C5D9
        CMP.W #$FE00
        BCC CODE_81C5E6
        AND.W #$00FF
        JSR.W entityStateConfig
        BRA CODE_81C626
CODE_81C5E6: ; $01C5E6
        CMP.W #$FD00
        BCC CODE_81C5F6
        AND.W #$00FF
        ORA.W #$0008
        JSR.W setScreenEffect
        BRA CODE_81C626
CODE_81C5F6: ; $01C5F6
        CMP.W #$FC00
        BCC CODE_81C600
        JSR.W setupTransparency
        BRA CODE_81C626
CODE_81C600: ; $01C600
        CMP.W #$1000
        BCS CODE_81C612
        CLC
        ADC.W #$2000
        JSR.W drawPartyFace
        BRA CODE_81C626
CODE_81C60E: ; $01C60E
        JSR.W confirmAction
        RTS
CODE_81C612: ; $01C612
        PHA
        LDA.W #$000B
        JSR.W callCutsceneHandler
        JSR.W initTilemapAndSync
        LDA.W #$0005
        STA.W $0A0C
        PLA
        JSR.W textMetaLookup
CODE_81C626: ; $01C626
        JSR.W confirmAction
        STZ.W $0AA7
        RTS
; [VRAM]
drawBackgroundPattern: ; $01C62D
        AND.W #$00FF
        STA.B $00
        PHA
        AND.W #$0040
        BEQ CODE_81C650
        PLA
        CMP.W #$0040
        BNE CODE_81C645
        db $20,$2F,$DA,$20,$43,$DA,$60
CODE_81C645: ; $01C645
        AND.W #$003F
        LDY.W #$0000
        LDX.W #$0800
        BRA CODE_81C675
CODE_81C650: ; $01C650
        LDA.B $00
        AND.W #$003F
        ORA.W #$0500
        LDY.W #$0080
        LDX.W #$0800
        JSL.L setTextScrollParams
        PLA
        CMP.W #$0080
        BCC CODE_81C679
        db $29,$3F,$00,$1A,$09,$00,$05,$A0,$80,$00,$A2,$00,$00
CODE_81C675: ; $01C675
        JSL.L setTextScrollParams
CODE_81C679: ; $01C679
        RTS
; [Effects] Sets up transparency/color math for effects. Entry: A=effect type (fade, blend, etc).
setupTransparency: ; $01C67A
        AND.W #$00FF
        PHA
        STA.B $00
        LDA.W #$0001
        STA.B $02
        LDA.W $0AAD
        STA.B $12
        LDA.W $0AAF
        STA.B $14
        JSR.W enableInterrupts
        PLA
        CMP.W #$0080
        BCC CODE_81C6A5
        AND.W #$001F
        STA.B $00
        LDA.W #$0001
        STA.B $02
        JSR.W disableInterrupts
CODE_81C6A5: ; $01C6A5
        RTS
; [Effects] Handles screen shake effect (earthquake, impact). Entry: A=intensity, updates scroll registers.
handleScreenShake: ; $01C6A6
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
CODE_81C6CA: ; $01C6CA
        SEP #$20
        LDA.B #$01
        STA.W $0054,X
        STA.W $0054,Y
        LDA.W $0E25
        BNE CODE_81C6DA
        INC A
CODE_81C6DA: ; $01C6DA
        STA.B $00
        LDA.W $005C,X
        CMP.B $00
        BCS CODE_81C6EA
        LDA.W $0056,X
        CMP.B $00
        BCS CODE_81C6ED
CODE_81C6EA: ; $01C6EA
        STZ.W $0054,X
CODE_81C6ED: ; $01C6ED
        LDA.W $005C,Y
        CMP.B $00
        BCS CODE_81C6FB
        LDA.W $0056,Y
        CMP.B $00
        BCS CODE_81C700
CODE_81C6FB: ; $01C6FB
        LDA.B #$00
        STA.W $0054,Y
CODE_81C700: ; $01C700
        LDA.W $0054,X
        BEQ CODE_81C766
        LDA.W $0044,Y
        STA.B $08
        LDA.W $0044,X
        SEC
        SBC.B $08
        BPL CODE_81C714
        LDA.B #$00
CODE_81C714: ; $01C714
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
CODE_81C72A: ; $01C72A
        STA.B $0A
        STZ.B $0B
        REP #$20
        LDA.B $0A
        TAY
        JSR.W multiplyUnsigned16
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        STA.B $0A
        STA.W $1C0A
        LDA.W #$0064
        JSL.L hardwareMultiplyRng
        CMP.B $08
        BCS CODE_81C758
        INC.W $0E66
        LDA.W $0964
        EOR.W #$0001
        STA.W $0964
CODE_81C758: ; $01C758
        LDA.W #$0064
        JSL.L hardwareMultiplyRng
        CMP.B $0A
        BCS CODE_81C766
        INC.W $0968
CODE_81C766: ; $01C766
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
CODE_81C782: ; $01C782
        CMP.B #$03
        BCC CODE_81C78B
        SEC
        SBC.B #$03
        BRA CODE_81C782
CODE_81C78B: ; $01C78B
        STA.W $0E65
        LDA.W $0E11
        SEC
        SBC.W $0E91
        CLC
        ADC.B #$04
CODE_81C798: ; $01C798
        CMP.B #$03
        BCC CODE_81C7A1
        SEC
        SBC.B #$03
        BRA CODE_81C798
CODE_81C7A1: ; $01C7A1
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
CODE_81C7BE: ; $01C7BE
        LDA.B #$FF
        STA.W $0E6C
        BRA CODE_81C7C8
CODE_81C7C5: ; $01C7C5
        STZ.W $0E54
CODE_81C7C8: ; $01C7C8
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
flashScreen: ; $01C91E
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
CODE_81C932: ; $01C932
        LDA.W $AD2C,Y
        AND.W #$00FF
        JSR.W setTimerValue
CODE_81C93B: ; $01C93B
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
CODE_81C957: ; $01C957
        RTS
CODE_81C958: ; $01C958
        JSR.W pulseEffect
        SEC
        SBC.W #$0E00
        STA.W $096C
        JSL.L updateWeatherEffect
        RTS
CODE_81C967: ; $01C967
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
CODE_81C97E: ; $01C97E
        db $20,$86,$C9,$22,$67,$87,$00,$60
; [Effects] Pulse effect for highlighting. Entry: A=target, updates brightness cyclically.
pulseEffect: ; $01C986
        JSR.W initBattleState
        LDA.W $1404,X
        STA.B $00
        JSR.W setupWindowMask
        LDA.B $00
        RTS
; [Effects] Sets up scanline color effect via HDMA. Entry: A=effect type (gradient, split, etc).
drawScanlineEffect: ; $01C994
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
CODE_81C9E1: ; $01C9E1
        LDA.W #$F0F0
        STA.W $0100,Y
        STA.W $0104,Y
        STA.W $0108,Y
        STA.W $010C,Y
        RTS
; [Effects] Updates scanline effect parameters. Entry: modifies HDMA table in real-time.
updateScanlineEffect: ; $01C9F1
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
setupMosaic: ; $01CA0A
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
updateMosaic: ; $01CA21
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
setupWindowMask: ; $01CA5A
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
CODE_81CA70: ; $01CA70
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
CODE_81CA87: ; $01CA87
        SEP #$20
        STA.B $00
        REP #$20
        RTS
        db $A9,$00,$E0,$85,$00,$60
; [Effects] Updates window mask position/size. Entry: animates window for reveal effects.
updateWindowMask: ; $01CA94
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
handleTransitionWipe: ; $01CAA1
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
        JSR.W textMetaLookup
CODE_81CABF: ; $01CABF
        JSR.W drawTransitionMask
        JSR.W configMapMonitor
        JSR.W drawNumber
        LDA.B $50
        BEQ CODE_81CB25
        LDY.W #$0000
        LDA.W $098A
        CMP.W #$0080
        BEQ CODE_81CADA
        LDY.W #$0020
CODE_81CADA: ; $01CADA
        TYA
        JSR.W configMapMonitor
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
CODE_81CAFE: ; $01CAFE
        LDA.B $50
        AND.W #$0400
        BEQ CODE_81CB08
        INC.W $0974
CODE_81CB08: ; $01CB08
        LDA.B $50
        AND.W #$0200
        BEQ CODE_81CB12
        STZ.W $0972
CODE_81CB12: ; $01CB12
        LDA.B $50
        AND.W #$0100
        BEQ CODE_81CB1F
        LDA.W #$0001
        STA.W $0972
CODE_81CB1F: ; $01CB1F
        LDA.W #$0003
        JSR.W setTimerValue
CODE_81CB25: ; $01CB25
        LDA.B $6A
        AND.W #$00FF
        BEQ CODE_81CB32
        JSR.W evtCallRenderSprites
        JSR.W updateConfigSettings
CODE_81CB32: ; $01CB32
        JSR.W requestVblankUpdate
        LDA.B $50
        AND.W #$0F00
        BEQ CODE_81CB3F
        JMP.W $CAB4
CODE_81CB3F: ; $01CB3F
        JMP.W CODE_81CABF
CODE_81CB42: ; $01CB42
        LDA.W $0E5A
        CMP.W #$0080
        BCS CODE_81CB5C
        INC.B $22
        LDA.W #$0002
        JSR.W setTimerValue
        RTS
CODE_81CB53: ; $01CB53
        STZ.B $22
        LDA.W #$0001
        JSR.W setTimerValue
        RTS
CODE_81CB5C: ; $01CB5C
        AND.W #$007F
        EOR.B $24
        STA.B $24
        LDA.W #$0002
        JSR.W setTimerValue
        JMP.W $CAB4
; [Effects] Draws transition mask shape to window. Entry: A=shape, updates window data.
drawTransitionMask: ; $01CB6C
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
CODE_81CBA8: ; $01CBA8
        LDA.B $24
        AND.B $00
        STA.W $0E00,X
        ASL.B $00
        INX
        CPX.W #$0006
        BCC CODE_81CBA8
        REP #$20
CODE_81CBB9: ; $01CBB9
        LDA.W $0002,Y
        AND.W #$00FF
        STA.W $098A
        RTS
CODE_81CBC3: ; $01CBC3
        LDA.W $0002,Y
        AND.W #$00FF
        STA.W $0972
        LDA.W $0003,Y
        AND.W #$00FF
        STA.W $0974
        BRA drawTransitionMask
; [Helper] Sets $0A1E=$3900, INC $0970, calls monitorMap.
configMapMonitor: ; $01CBD7
        TAY
        BNE CODE_81CBE3
        LDY.W #$0020
        LDA.W #$3900
        STA.W $0A1E
CODE_81CBE3: ; $01CBE3
        CMP.W #$0080
        BNE CODE_81CBEE
        LDA.W #$3900
        STA.W $0A1E
CODE_81CBEE: ; $01CBEE
        INC.W $0970
        LDA.W $0970
        AND.W #$0010
        BEQ CODE_81CBFC
        LDY.W #$0020
CODE_81CBFC: ; $01CBFC
        TYA
        JSR.W writeTilemapChar
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
; [Memory] 64B ROM $00:8000 -> $7E:9480, calls iterateSlotEntries x2.
loadRomHeaderToWram: ; $01CEB6
        REP #$20
        LDX.W #$0000
CODE_81CEBB: ; $01CEBB
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
        JSR.W iterateSlotEntries
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
        JSR.W iterateSlotEntries
        RTS
; [Helper] INC word at [$12] x2 per entry, $16 stride.
iterateSlotEntries: ; $01CF03
        STZ.B $04
        LDA.B $00
        BNE CODE_81CF0A
        RTS
CODE_81CF0A: ; $01CF0A
        ASL A
        ASL A
        ASL A
        ASL A
        TAY
        LDA.B $02
        JSR.W divideUnsigned16
        CMP.W #$0000
        BNE CODE_81CF1A
        INC A
CODE_81CF1A: ; $01CF1A
        CMP.W #$000E
        BCC CODE_81CF22
        LDA.W #$000E
CODE_81CF22: ; $01CF22
        STA.B $04
CODE_81CF24: ; $01CF24
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
; [Text] STZ $0A0C, textMetaLookup(#$28).
clearAndDispatchText: ; $01CF36
        STZ.W $0A0C
        LDA.W #$0028
        JSR.W textMetaLookup
        RTS
; [GameState] Sets up game sequence based on $0E6A. Entry: sets $096E, calls sub_00D0B3, runs sequence with $0A00 timing.
setupGameSequence: ; $01CF40
        REP #$20
        LDY.W #$0000
        LDA.W $0E6A
        CMP.W #$0004
        BNE CODE_81CF50
        db $A0,$08,$00
CODE_81CF50: ; $01CF50
        STY.W $096E
        STZ.W $0974
        JSR.W copyDataTable
        LDA.W #$0001
        JSR.W callCutsceneHandler
        LDA.W #$006B
        JSR.W textMetaLookup
        JSR.W commitDmaFlag
        LDA.W $096E
        INC A
        STA.B $22
        LDA.W #$0002
        STA.W $0A00
        LDA.W #$006C
        JSR.W textMetaLookup
        STZ.W $0A00
        DEC.B $22
        LDA.W #$006C
        JSR.W textMetaLookup
        LDA.W #$0C10
        JSR.W textMetaLookup
        LDA.W $0974
        CLC
        ADC.W $096E
        CLC
        ADC.W #$0C00
        JSR.W textMetaLookup
        LDA.W #$0002
        STA.W $09FC
        LDA.W $0974
        ASL A
        CLC
        ADC.W #$0018
        STA.W $09FE
        STZ.W $0970
CODE_81CFAD: ; $01CFAD
        LDA.W #$003E
        JSR.W configMapMonitor
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
        JSR.W evtCallRenderSprites
        JSR.W updateConfigSettings
        JSR.W requestVblankUpdate
        BRA CODE_81CFAD
CODE_81CFDB: ; $01CFDB
        LDA.W $0974
        BEQ CODE_81CFE5
        DEC.W $0974
        BRA CODE_81D00A
CODE_81CFE5: ; $01CFE5
        LDA.W $096E
        AND.W #$0007
        BEQ CODE_81CFF0
        DEC.W $096E
CODE_81CFF0: ; $01CFF0
        BRA CODE_81D00A
CODE_81CFF2: ; $01CFF2
        LDA.W $0974
        BNE CODE_81CFFC
        INC.W $0974
        BRA CODE_81D00A
CODE_81CFFC: ; $01CFFC
        LDA.W $096E
        AND.W #$0007
        CMP.W $097A
        BCS CODE_81D00A
        INC.W $096E
CODE_81D00A: ; $01D00A
        LDA.W #$0020
        JSR.W configMapMonitor
        LDA.W #$0003
        JSR.W setTimerValue
        JMP.W $CF68
CODE_81D019: ; $01D019
        db $A9,$FF,$FF,$60
CODE_81D01D: ; $01D01D
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
CODE_81D08F: ; $01D08F
        db $A9,$00,$80,$04,$14
CODE_81D094: ; $01D094
        LDA.B $14
        STA.W $0E6E
        LDA.B $12
        LDA.W $0E0A
        AND.W #$00FF
        SEC
        SBC.B $16
        BCS CODE_81D0AF
        LDA.W #$006D
        JSR.W textMetaLookup
        JMP.W $CF59
CODE_81D0AF: ; $01D0AF
        STA.W $0E5A
        RTS
; [Memory] Copies data table from ROM to RAM. Entry: uses $0E06 count, copies from $01D113 to $1000, processes $0BE4CF table.
copyDataTable: ; $01D0B3
        STZ.W $097A
        LDA.W $0E06
        AND.W #$00FF
        STA.B $00
        LDX.W #$0000
        LDA.W #$1000
        STA.B $12
        SEP #$20
        LDA.B #$01
CODE_81D0CA: ; $01D0CA
        LDA.L $01D113,X
        STA.B ($12)
        INC.B $12
        INX
        CPX.W #$0010
        BNE CODE_81D0CA
        LDX.W #$0000
CODE_81D0DB: ; $01D0DB
        LDA.L $0BE4CF,X
        BEQ CODE_81D0E9
        DEC A
        STA.B $12
        LDA.B ($12)
        INC A
        STA.B ($12)
CODE_81D0E9: ; $01D0E9
        INX
        DEC.B $00
        BNE CODE_81D0DB
        LDA.W $1000
        STA.W $1001
        STA.W $1002
        LDX.W $096E
CODE_81D0FA: ; $01D0FA
        LDA.W $1000,X
        BEQ CODE_81D10A
        INC.W $097A
        INX
        LDA.W $097A
        CMP.B #$08
        BCC CODE_81D0FA
CODE_81D10A: ; $01D10A
        DEC.W $097A
        DEC.W $097A
        REP #$20
        RTS
        db $01,$00,$00,$00,$00,$00,$00,$00,$01,$01,$00,$00,$00,$00,$00,$00
        db $00,$00
        db $0A,$00,$14,$00,$1E,$00,$28,$00,$32,$00,$3C,$00,$46,$00,$50,$00
; [GameState] Runs game mode sequence. Entry: calls dispatchGameMode mode 8, sets up graphics, calls animation functions.
runGameModeSequence: ; $01D135
        REP #$20
        JSR.W calculatePlayTime
        LDA.W #$0008
        JSL.L dispatchGameMode
        LDA.W #$0001
        STA.W $2105
        LDA.W #$0017
        LDX.W #$0042
        LDY.W #$0000
        JSL.L setTextScrollParams
        JSR.W clearTilemapRows
        LDA.W $097A
        INC A
        LDX.W #$0000
        LDY.W #$0008
        JSR.W clearSaveData
        STZ.W $0E58
        LDA.W #$0061
        JSR.W textMetaLookup
        JSR.W processEntityBatch
        JSR.W drawMessageBox
CODE_81D173: ; $01D173
        JSR.W calculateEntityValue
        CMP.W #$03E7
        BNE CODE_81D180
        db $20,$E3,$D1,$80,$F3
CODE_81D180: ; $01D180
        CMP.W #$FFFF
        BNE CODE_81D186
        RTS
CODE_81D186: ; $01D186
        LDA.W $0E5A
        BNE CODE_81D193
        LDA.W #$0088
        JSR.W callEffectFunction
        BRA CODE_81D173
CODE_81D193: ; $01D193
        db $AF,$8A,$EA,$7E,$CD,$5A,$0E,$B0,$08,$A9,$86,$00,$20,$38,$D6,$80
        db $CF,$A9,$85,$00,$20,$38,$D6,$AD,$08,$0A,$C9,$01,$00,$D0,$C1,$AF
        db $8A,$EA,$7E,$38,$ED,$5A,$0E,$8F,$8A,$EA,$7E,$E2,$20,$9C,$10,$0E
        db $C2,$20,$A0,$00,$0E,$20,$2A,$DE,$A9,$61,$00,$20,$4A,$EE,$20,$E3
        db $D1,$A9,$87,$00,$20,$38,$D6,$AD,$08,$0A,$C9,$01,$00,$F0,$91,$60
; [Entity] Processes batch of entities. Entry: $098C=start index, processes up to 8 entities, calls sub_00D217 for each.
processEntityBatch: ; $01D1E3
        STZ.W $0A00
        LDA.W $098C
        STA.B $22
CODE_81D1EB: ; $01D1EB
        LDA.B $22
        JSR.W initBattleState
        LDA.W $1400,X
        BEQ CODE_81D200
        LDA.B $22
        JSR.W setupEntityParameter
        LDA.W #$0083
        JSR.W textMetaLookup
CODE_81D200: ; $01D200
        LDA.W $0A00
        CLC
        ADC.W #$0002
        CMP.W #$0010
        BCS CODE_81D213
        STA.W $0A00
        INC.B $22
        BRA CODE_81D1EB
CODE_81D213: ; $01D213
        STZ.W $0A00
        RTS
; [Entity] Sets up entity parameter from table. Entry: Y=$0E00 base, calls sub_00DC04, reads $0E10, looks up in $01D123 table.
setupEntityParameter: ; $01D217
        LDY.W #$0E00
        JSR.W updateEntity
        LDA.W $0E10
        AND.W #$00FF
        ASL A
        TAX
        LDA.L $01D123,X
        STA.W $0E5A
        RTS
        db $0C,$0A,$0B,$0B
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
        JSL.L setTextScrollParams
        JSR.W clearTilemapRows
        LDA.W $0992
        BNE CODE_81D26A
        LDA.W #$BE10
        STA.B $00
        LDA.W $0E03
        LDY.W #$0100
        JSR.W setupEntityTile
CODE_81D26A: ; $01D26A
        LDX.W #$0000
        LDY.W #$0050
        LDA.W $0992
        AND.W #$0001
        BNE CODE_81D27E
        LDX.W #$0050
        LDY.W #$0080
CODE_81D27E: ; $01D27E
        STX.W $0996
        STY.W $0998
        LDA.W $0992
        CMP.W #$0002
        BCC CODE_81D291
        JSR.W parseScriptData
        BRA CODE_81D2AE
CODE_81D291: ; $01D291
        SEP #$20
        LDX.W #$0000
        LDY.W #$0000
CODE_81D299: ; $01D299
        LDA.L $7EEA00,X
        BEQ CODE_81D2A8
        STA.W $1001,Y
        TXA
        STA.W $1000,Y
        INY
        INY
CODE_81D2A8: ; $01D2A8
        INX
        CPX.W #$0070
        BNE CODE_81D299
CODE_81D2AE: ; $01D2AE
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
        JSR.W textMetaLookup
        JSR.W restoreBackup
        JSR.W drawMessageBox
        LDA.W $098E
        BNE CODE_81D2E2
        LDA.W #$0063
        JSR.W textMetaLookup
        LDA.W #$FFFF
        RTS
CODE_81D2E2: ; $01D2E2
        JSR.W calculateEntityValue
        CMP.W #$03E7
        BNE CODE_81D2EF
        JSR.W restoreBackup
        BRA CODE_81D2E2
CODE_81D2EF: ; $01D2EF
        CMP.W #$FFFF
        BNE CODE_81D2F5
        RTS
CODE_81D2F5: ; $01D2F5
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
        JSR.W callEffectFunction
        BRA CODE_81D2E2
CODE_81D318: ; $01D318
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
CODE_81D32F: ; $01D32F
        db $A5,$32,$29,$FF,$00,$C9,$50,$00,$B0,$A9,$A5,$33,$29,$1F,$00,$20
        db $BE,$E8,$CD,$28,$0E,$F0,$08,$A9,$75,$00,$20,$38,$D6,$80,$94,$A9
        db $7F,$00,$20,$38,$D6,$AD,$08,$0A,$C9,$01,$00,$D0,$86,$A0,$FF,$FF
        db $AD,$28,$0E,$20,$C8,$E7,$A4,$34,$B9,$00,$10,$29,$FF,$00,$09,$00
        db $01,$99,$00,$10,$20,$62,$D4,$4C,$E2,$D2
CODE_81D379: ; $01D379
        LDA.W #$0074
        JSR.W callEffectFunction
        LDA.W $0A08
        CMP.W #$0001
        BEQ CODE_81D38A
        db $4C,$E2,$D2
CODE_81D38A: ; $01D38A
        LDY.B $32
        LDA.W $0E28
        JSR.W spawnEntityWithFlag
        RTS
CODE_81D393: ; $01D393
        LDA.B $33
        AND.W #$00FF
        CMP.W #$007E
        BNE CODE_81D3A5
        LDA.W #$00BA
        JSR.W callEffectFunction
        BRA CODE_81D3F6
CODE_81D3A5: ; $01D3A5
        LDA.B $32
        JSR.W loadTileTemplate
        LDA.L $7EEA8A
        CMP.W $0E9A
        BCS CODE_81D3BB
        db $A9,$82,$00,$20,$38,$D6,$80,$3B
CODE_81D3BB: ; $01D3BB
        LDA.W #$0080
        JSR.W callEffectFunction
        LDA.W $0A08
        CMP.W #$0001
        BNE CODE_81D3F6
        LDA.W $0E98
        JSR.W incrementEventFlag
        LDA.L $7EEA8A
        SEC
        SBC.W $0E9A
        STA.L $7EEA8A
        JSR.W parseScriptData
        JSR.W restoreBackup
        LDA.W #$0061
        JSR.W textMetaLookup
        LDA.W #$0081
        JSR.W callEffectFunction
        LDA.W $0A08
        CMP.W #$0001
        BEQ CODE_81D3F6
        RTS
CODE_81D3F6: ; $01D3F6
        JMP.W CODE_81D2E2
; [Script] Parses script/data from ROM table. Entry: $0992=type, reads from $AF29/$AF4B table, processes with $7EEA8E.
parseScriptData: ; $01D3F9
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
CODE_81D415: ; $01D415
        STZ.W $0996
        STZ.W $0998
        LDA.L $7EEA8E
        STA.B $00
        LDY.W #$0000
CODE_81D424: ; $01D424
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
CODE_81D43C: ; $01D43C
        STA.W $1000,Y
        STA.B $12
        CMP.B #$60
        BCS CODE_81D44D
        LDA.B [$12]
        BEQ CODE_81D457
        DEC.B $02
        BRA CODE_81D457
CODE_81D44D: ; $01D44D
        LDA.B [$12]
        CMP.B #$63
        BCC CODE_81D457
        db $C6,$02,$80,$00
CODE_81D457: ; $01D457
        LDA.B $02
        STA.W $1001,Y
        INY
        INY
        BRA CODE_81D424
CODE_81D460: ; $01D460
        PLP
        RTS
; [Save] Restores save data from backup. Entry: copies backup to primary slot.
restoreBackup: ; $01D462
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
CODE_81D48C: ; $01D48C
        JSR.W loadTileTemplate
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
CODE_81D4A8: ; $01D4A8
        LDA.B $24
        CMP.W #$0080
        BCC CODE_81D4C3
        AND.W #$001F
        JSR.W findEntityByType
        JSR.W initBattleState
        LDA.W $1412,X
        STA.W $0E00
        LDA.W #$000A
        STA.B $26
CODE_81D4C3: ; $01D4C3
        LDA.W #$0062
        JSR.W textMetaLookup
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
CODE_81D4F8: ; $01D4F8
        JMP.W $D470
        db $00,$00
        db $02,$00
        db $04,$00,$06,$00,$08,$00,$0A,$00
        db $0C,$00,$0E,$00
        db $20,$00
        db $22,$00,$24,$00,$26,$00,$28,$00,$2A,$00
        db $2C,$00,$2E,$00
; [Save] Clears save slot (new game). Entry: A=slot number. Initializes with default data.
clearSaveData: ; $01D51B
        REP #$20
        STA.W $098E
        STY.W $0990
        STX.W $0994
        STZ.W $098A
        STZ.W $098C
        LDA.W #$0002
        STA.W $0980
        RTS
; [Entity] Calculates entity value with offset. Entry: $098C=base, $098A=offset, $0994=adjustment, reads $1000 table.
calculateEntityValue: ; $01D533
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
        JSR.W callEffectFunction
        BRA CODE_81D579
CODE_81D556: ; $01D556
        LDA.B $22
        JSR.W setupEntityParameter
        LDA.W #$0084
        JSR.W callEffectFunction
        LDA.W $0E10
        AND.W #$00FF
        CLC
        ADC.W #$00A0
        JSR.W textMetaLookup
        LDA.W #$BE10
        STA.B $00
        LDY.W #$0000
        JSR.W lookupTileFromTable
CODE_81D579: ; $01D579
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
CODE_81D596: ; $01D596
        INC A
        STA.B $24
        LDA.W $0990
        CMP.W $098E
        BCC CODE_81D5A4
        LDA.W $098E
CODE_81D5A4: ; $01D5A4
        DEC A
        STA.B $26
CODE_81D5A7: ; $01D5A7
        JSR.W processFrame
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
CODE_81D5CF: ; $01D5CF
        LDA.W $098C
        CLC
        ADC.W $0990
        CMP.B $24
        BCC CODE_81D5E2
        db $A5,$26,$8D,$8A,$09,$A5,$24,$3A
CODE_81D5E2: ; $01D5E2
        STA.W $098C
        BRA CODE_81D628
        db $AD,$8C,$09,$38,$ED,$90,$09,$10,$06,$A9,$00,$00,$8D,$8A,$09,$8D
        db $8C,$09,$80,$2D
CODE_81D5FB: ; $01D5FB
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
CODE_81D611: ; $01D611
        BRA CODE_81D622
CODE_81D613: ; $01D613
        LDA.B $22
        BEQ CODE_81D5A7
        LDA.W $098A
        BNE CODE_81D621
        DEC.W $098C
        BRA CODE_81D628
CODE_81D621: ; $01D621
        DEC A
CODE_81D622: ; $01D622
        STA.W $098A
        JMP.W $D535
CODE_81D628: ; $01D628
        LDA.W #$03E7
        RTS
CODE_81D62C: ; $01D62C
        LDY.B $22
        AND.W #$4080
        BNE CODE_81D636
        LDY.W #$FFFF
CODE_81D636: ; $01D636
        TYA
        RTS
; [Effects] Calls effect function with parameter. Entry: A=function ID, calls $EE4A twice with different parameters.
callEffectFunction: ; $01D638
        PHA
        LDA.W #$0060
        JSR.W textMetaLookup
        PLA
        JSR.W textMetaLookup
        RTS
; [Menu] Draws save file information (time, location, party). Entry: A=slot number.
drawSaveFileInfo: ; $01D644
        REP #$20
        LDY.W #$0000
        CMP.W #$0010
        BCC CODE_81D64F
        INY
CODE_81D64F: ; $01D64F
        STY.W $0E68
        LDY.W #$0E00
        JSR.W updateEntity
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
        JSR.W clearBattleUnitState
        LDX.W #$000C
        LDY.W #$FFD8
        JSL.L setObjectOffsets
        LDA.W $0E03
        AND.W #$00FF
        JSL.L initEntityObject
        JSL.L clearVRAM
        JSR.W confirmAction
        LDA.W #$0007
        JSR.W callCutsceneHandler
        LDA.W #$0057
        JSR.W textMetaLookup
        LDA.W $0E03
        AND.W #$00FF
        CLC
        ADC.W #$0500
        JSR.W textMetaLookup
        JSR.W commitDmaFlag
        LDA.W #$0058
        JSR.W textMetaLookup
        JSR.W sceneTextDisplay
        JSR.W printText
        LDA.W #$0059
        JSR.W textMetaLookup
        LDA.W $0A08
        CMP.W #$0002
        BNE CODE_81D73E
        LDA.W $0E28
        INC A
        CMP.W #$0010
        BCC CODE_81D72A
        db $A9,$00,$00
CODE_81D72A: ; $01D72A
        STA.B $08
        JSR.W initBattleState
        LDA.W $1400,X
        AND.W #$00FF
        BNE CODE_81D739
        STZ.B $08
CODE_81D739: ; $01D739
        LDA.B $08
        JMP.W drawSaveFileInfo
CODE_81D73E: ; $01D73E
        LDA.W #$000A
        JSR.W setTextColor
        RTS
; [Timer] Calculates play time from frame counter. Entry: converts frames to hours:minutes.
calculatePlayTime: ; $01D745
        STZ.W $0976
        STZ.W $0978
        STZ.W $097A
        LDX.W #$0000
        LDY.W #$0000
CODE_81D754: ; $01D754
        LDA.W $1400,Y
        BEQ CODE_81D75C
        INC.W $097A
CODE_81D75C: ; $01D75C
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
updatePlayTime: ; $01D77D
        REP #$20
        STA.W $097C
        JSR.W calculatePlayTime
        LDA.W #$0008
        JSL.L dispatchGameMode
        LDA.W #$0007
        LDX.W #$0042
        LDY.W #$0000
        JSL.L setTextScrollParams
        LDA.W #$0007
        JSR.W callCutsceneHandler
        JSR.W drawPlayTime
        JSR.W printText
CODE_81D7A5: ; $01D7A5
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
        JSR.W processFrame
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
CODE_81D7DE: ; $01D7DE
        CPY.W $097A
        BEQ CODE_81D7A5
        LDA.W $0976
        CMP.W #$0003
        BNE CODE_81D7F0
        INC.W $0978
        BRA CODE_81D809
CODE_81D7F0: ; $01D7F0
        INC.W $0976
        BRA CODE_81D7A5
CODE_81D7F5: ; $01D7F5
        CPY.W #$0000
        BEQ CODE_81D7A5
        LDA.W $0976
        BNE CODE_81D804
        DEC.W $0978
        BRA CODE_81D809
CODE_81D804: ; $01D804
        DEC.W $0976
        BRA CODE_81D7A5
CODE_81D809: ; $01D809
        JSR.W countActiveEntities
        BRA CODE_81D7A5
CODE_81D80E: ; $01D80E
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
CODE_81D82B: ; $01D82B
        RTS
CODE_81D82C: ; $01D82C
        TYA
        JSR.W drawSaveFileInfo
        JMP.W $D785
CODE_81D833: ; $01D833
        TYA
        JSR.W initBattleState
        LDA.W $1401,X
        AND.W #$00FF
        CMP.W #$0004
        BCS CODE_81D845
        JMP.W CODE_81D7A5
CODE_81D845: ; $01D845
        CMP.W #$0004
        BNE CODE_81D8A1
        LDA.W $1400,X
        AND.W #$00FF
        BNE CODE_81D8A1
        PHX
        LDA.W #$0009
        JSR.W callCutsceneHandler
        LDA.W #$005C
        JSR.W textMetaLookup
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
CODE_81D87B: ; $01D87B
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
CODE_81D896: ; $01D896
        STA.W $1400,X
CODE_81D899: ; $01D899
        REP #$20
        JSR.W drawPlayTime
        JMP.W CODE_81D7A5
CODE_81D8A1: ; $01D8A1
        SEP #$20
        LDA.W $1400,X
        EOR.B #$FF
        BEQ CODE_81D8B4
        LDY.W $097E
        CPY.W #$0007
        BCC CODE_81D8B4
        db $A9,$00
CODE_81D8B4: ; $01D8B4
        STA.W $1400,X
        REP #$20
        JSR.W countActiveEntities
        JMP.W CODE_81D7A5
        TYA
        LDY.W #$0E00
        JSR.W updateEntity
        LDA.W #$000A
        JSR.W callCutsceneHandler
        LDY.W #$008E
        LDA.W #$0000
        JSR.W handleTransitionWipe
        LDA.B $22
        BNE CODE_81D8DC
        JMP.W CODE_81D899
CODE_81D8DC: ; $01D8DC
        CMP.W #$0003
        BEQ CODE_81D8F9
        LDA.W #$000A
        JSR.W callCutsceneHandler
        LDA.W #$008F
        JSR.W textMetaLookup
        LDA.W $0A08
        CMP.W #$0001
        BEQ CODE_81D8F8
        db $4C,$99,$D8
CODE_81D8F8: ; $01D8F8
        RTS
CODE_81D8F9: ; $01D8F9
        LDA.W #$0000
        JSR.W $D231
        JSR.W clearTextBuffer
        JMP.W $D785
; [HUD] Draws play time display. Entry: formats time string, draws to screen.
drawPlayTime: ; $01D905
        JSR.W clearTilemapRows
        LDX.W #$0282
        LDY.W #$0003
CODE_81D90E: ; $01D90E
        PHY
        PHX
        LDY.W #$001E
        LDA.W #$3170
CODE_81D916: ; $01D916
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
; [Entity] Counts non-zero in $1400 ($20 stride) -> $097E.
countActiveEntities: ; $01D929
        LDA.W #$0007
        JSR.W callCutsceneHandler
        STZ.W $097E
        LDX.W #$0000
CODE_81D935: ; $01D935
        LDA.W $1400,X
        AND.W #$00FF
        BEQ CODE_81D940
        INC.W $097E
CODE_81D940: ; $01D940
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
CODE_81D95B: ; $01D95B
        DEC.B $22
        DEC.B $24
        LDA.B $24
        LDY.W #$0E00
        JSR.W updateEntity
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
        JSR.W lookupTileFromTable
        LDA.B $00
        CLC
        ADC.W #$1000
        STA.B $00
        LDA.B $28
        CLC
        ADC.W #$0040
        TAY
        JSR.W getEntityBaseAddr
        JSR.W updateScanlineEffect
        LDA.B $28
        CLC
        ADC.W #$0010
        STA.B $28
        LDA.W #$001C
        JSR.W textMetaLookup
        JSR.W sceneTextDisplay
CODE_81D9B7: ; $01D9B7
        LDA.B $22
        BNE CODE_81D95B
        RTS
; [Entity] A->$0E03. $FFFF: scanline. Else: lookupTileFromTable.
setupEntityTile: ; $01D9BC
        STA.W $0E03
        PHY
        CMP.W #$FFFF
        BNE CODE_81D9CB
        INC A
        JSR.W drawScanlineEffect
        BRA CODE_81D9CE
CODE_81D9CB: ; $01D9CB
        JSR.W lookupTileFromTable
CODE_81D9CE: ; $01D9CE
        PLA
        CLC
        ADC.W #$0010
        TAY
        RTS
; [Tilemap] $0E03&#$3F, ROM $D138,X, AND #$03, ORA $03.
lookupTileFromTable: ; $01D9D5
        PHY
        LDA.W $0E03
        AND.W #$003F
        PHA
        JSR.W searchDataTable
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
; [Entity] $0E00/$0E08 -> #$3FAC or #$3FA4.
getEntityBaseAddr: ; $01D9F8
        LDA.W $0E00
        AND.W #$00FF
        BNE CODE_81DA0D
        LDA.W $0E08
        BNE CODE_81DA09
        db $A9,$AC,$3F,$60
CODE_81DA09: ; $01DA09
        LDA.W #$3FA4
        RTS
CODE_81DA0D: ; $01DA0D
        LDA.W $0E0F
        AND.W #$00FF
        BNE CODE_81DA19
        LDA.W #$3FA8
        RTS
CODE_81DA19: ; $01DA19
        db $A9,$A0,$3F,$60
; [Text] Reads $0E37 bits 4-5, adds $24, calls textMetaLookup
sceneTextDisplay: ; $01DA1D
        LDA.W $0E37
        AND.W #$0030
        LSR A
        LSR A
        LSR A
        LSR A
        CLC
        ADC.W #$0024
        JSR.W textMetaLookup
        RTS
; [Memory] Zero-fills $7F:B000, 2KB
clearBuffer7FB000: ; $01DA2F
        REP #$20
        LDX.W #$0000
        LDA.W #$0000
CODE_81DA37: ; $01DA37
        STA.L $7FB000,X
        INX
        INX
        CPX.W #$0800
        BNE CODE_81DA37
        RTS
; [Entity] Sets $78=$7000 scroll, $57=$FE flags, calls $B7EE
entityScreenSetup: ; $01DA43
        REP #$20
        LDA.W #$7000
        STA.B $78
        SEP #$20
        LDA.B #$FE
        STA.B $57
        REP #$20
        JSR.W confirmAction
        RTS
; [Entity] Reads $7E:EA82 scenario#; sets $7F:C005 graphics
sceneEntityInit: ; $01DA56
        REP #$20
        LDA.L $7EEA82
        CMP.W #$0025
        BNE CODE_81DA7B
        db $AF,$96,$EA,$7E,$29,$FF,$00,$C9,$FE,$00,$D0,$0E,$A9,$45,$80,$8F
        db $05,$C0,$7F,$A9,$26,$00,$8F,$07,$C0,$7F
CODE_81DA7B: ; $01DA7B
        REP #$20
        JSR.W confirmAction
        LDA.L $7FC006
        AND.W #$000F
        JSR.W setScreenEffect
        LDA.L $7FC005
        AND.W #$00FF
        JSR.W entityStateConfig
        SEP #$20
        LDA.B #$70
        STA.B $00
        LDA.L $7FC006
        STA.B $02
        AND.B #$40
        BEQ CODE_81DAA9
        db $A9,$10,$8D,$61,$43
CODE_81DAA9: ; $01DAA9
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
CODE_81DAC9: ; $01DAC9
        LDA.L $7FC007
        AND.W #$00FF
        BEQ CODE_81DAF1
        LDX.W #$0000
        PHY
        JSL.L setTextScrollParams
        PLA
        CLC
        ADC.W #$0007
        TAY
        LDA.L $7FC008
        AND.W #$00FF
        BEQ CODE_81DAF7
        LDX.W #$0800
        JSL.L setTextScrollParams
        RTS
CODE_81DAF1: ; $01DAF1
        JSR.W clearBuffer7FB000
        JSR.W entityScreenSetup
CODE_81DAF7: ; $01DAF7
        RTS
; [GameState] Sets PPU effect bitmask from low 3 bits of A; stores to $5E/$5F; mode $74
setScreenEffect: ; $01DAF8
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
CODE_81DB1C: ; $01DB1C
        REP #$20
        JSR.W confirmAction
        LDA.W #$0215
        STA.B $74
        BRA CODE_81DB2D
CODE_81DB28: ; $01DB28
        LDA.W #$0017
        STA.B $74
CODE_81DB2D: ; $01DB2D
        PLP
        RTS
        db $15,$55,$95
        db $D5
; [Entity] High nibble->$76, low->$77; sets $84=$50
entityStateConfig: ; $01DB33
        PHP
        SEP #$20
        STA.B $00
        AND.B #$F0
        BNE CODE_81DB44
        LDA.B #$00
        STA.L $7EA000
        BRA CODE_81DB53
CODE_81DB44: ; $01DB44
        JSR.W initHDMATable
        LDA.B $00
        LSR A
        LSR A
        LSR A
        LSR A
        STA.B $76
        LDA.B #$50
        STA.B $84
CODE_81DB53: ; $01DB53
        LDA.B $00
        AND.B #$0F
        STA.B $77
        PLP
        RTS
; [DMA] Builds HDMA table at $7E:A000; 12-scanline header + 100 2-scanline entries
initHDMATable: ; $01DB5B
        PHP
        REP #$20
        LDA.W #$000C
        STA.L $7EA000
        LDA.W #$0000
        STA.L $7EA001
        LDX.W #$0003
        LDY.W #$0064
CODE_81DB72: ; $01DB72
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
; [Math] Folds 9-bit angle; looks up sine from ROM $00:F7CB; returns 8-bit
lookupSineTable: ; $01DB8F
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
CODE_81DBA5: ; $01DBA5
        TAX
        LDA.L $00F7CB,X
        AND.W #$00FF
        PLX
        RTS
        db $C2,$20,$DA,$29,$FF,$00,$AA,$BF,$00,$80,$03,$29,$FF,$00,$C9,$80
        db $00,$90,$03,$09,$00,$FF,$FA,$60
; [Helper] INC $57 + vblank wait ($B7EE); triggers display refresh
requestVblankUpdate: ; $01DBC7
        PHP
        SEP #$20
        INC.B $57
        JSR.W confirmAction
        PLP
        RTS
        db $C2,$20,$BF,$00,$E8,$7F,$29,$1F,$00,$0A,$0A,$0A,$0A,$0A,$85,$06
        db $E2,$20,$BF,$01,$E8,$7F,$29,$1F,$18,$65,$06,$85,$06,$BF,$02,$E8
        db $7F,$29,$1F,$0A,$0A,$18,$65,$07,$85,$07,$C2,$20,$A5,$06,$60
; [Entity] JSL wrapper into updateEntity; RTL
updateEntityWrapper: ; $01DC00
        JSR.W updateEntity
        RTL
; [Entity] Core entity tick: loads anim from $0B:BF64, applies velocity/accel, dispatches by state
updateEntity: ; $01DC04
        PHP
        REP #$20
        STA.W $0028,Y
        JSR.W initBattleState
        PHY
        PHX
        LDA.W #$0010
        STA.B $00
CODE_81DC14: ; $01DC14
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
CODE_81DC2C: ; $01DC2C
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
CODE_81DC43: ; $01DC43
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
CODE_81DC85: ; $01DC85
        REP #$20
        LDA.W $0040,Y
        AND.W #$00FF
        STA.B $0A
        LDA.W $0038,Y
        JSR.W applyMovementCurve
        STA.W $0038,Y
        LDA.W $0018,Y
        JSR.W signExtendByte
        LDA.W $0041,Y
        AND.W #$00FF
        STA.B $0A
        LDA.W $003A,Y
        JSR.W applyMovementCurve
        CLC
        ADC.B $06
        BPL CODE_81DCB4
        db $A9,$00,$00
CODE_81DCB4: ; $01DCB4
        STA.W $003A,Y
        LDA.W $0019,Y
        JSR.W signExtendByte
        LDA.W $0042,Y
        AND.W #$00FF
        STA.B $0A
        LDA.W $003C,Y
        BEQ CODE_81DCD8
        JSR.W applyMovementCurve
        CLC
        ADC.B $06
        BPL CODE_81DCD5
        db $A9,$00,$00
CODE_81DCD5: ; $01DCD5
        STA.W $003C,Y
CODE_81DCD8: ; $01DCD8
        LDA.W $001A,Y
        JSR.W signExtendByte
        LDA.W $0043,Y
        AND.W #$00FF
        STA.B $0A
        LDA.W $003E,Y
        JSR.W applyMovementCurve
        CLC
        ADC.B $06
        BPL CODE_81DCF4
        db $A9,$00,$00
CODE_81DCF4: ; $01DCF4
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
CODE_81DD30: ; $01DD30
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
CODE_81DD47: ; $01DD47
        STA.W $0044,Y
        LDA.W $0046,Y
        CLC
        ADC.W $001D,Y
        STA.W $0046,Y
        LDA.W $0049,Y
        JSR.W multiplyByFrameRate
        CLC
        ADC.W $001E,Y
        STA.W $0049,Y
        LDA.W $004A,Y
        JSR.W multiplyByFrameRate
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
CODE_81DD8A: ; $01DD8A
        LDA.B #$00
        STA.W $006A,Y
CODE_81DD8F: ; $01DD8F
        LDA.W $0010,Y
        CMP.B #$04
        BEQ CODE_81DDA0
        CMP.B #$05
        BEQ CODE_81DDA7
        CMP.B #$06
        BEQ CODE_81DDC0
        PLP
        RTS
CODE_81DDA0: ; $01DDA0
        db $A9,$00,$99,$44,$00,$80,$F7
CODE_81DDA7: ; $01DDA7
        db $C2,$20,$B9,$3A,$00,$4A,$99,$3A,$00,$B9,$3C,$00,$4A,$99,$3C,$00
        db $B9,$3E,$00,$4A,$99,$3E,$00,$80,$DE
CODE_81DDC0: ; $01DDC0
        db $C2,$20,$B9,$3A,$00,$85,$00,$0A,$18,$65,$00,$4A,$4A,$99,$3A,$00
        db $B9,$3C,$00,$85,$00,$0A,$18,$65,$00,$4A,$4A,$99,$3C,$00,$80,$BE
; [Math] Masks A to $00FF, sign-extends if >= $80
signExtendByte: ; $01DDE0
        AND.W #$00FF
        STA.B $06
        CMP.W #$0080
        BCC CODE_81DDEC
        db $C6,$07
CODE_81DDEC: ; $01DDEC
        RTS
; [Entity] Indexes curve table $0B:E2CF, scales via multiply, >>5
applyMovementCurve: ; $01DDED
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
        JSR.W multiplyUnsigned16
        LSR A
        LSR A
        LSR A
        LSR A
        LSR A
        PLY
        RTS
; [Math] Hardware multiply $4202/$4203; scales by ($3F+$08), >>6
multiplyByFrameRate: ; $01DE09
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
; [Entity] Copies 16 words from entity struct to $1400,X
saveEntityToBuffer: ; $01DE2A
        PHP
        REP #$20
        LDA.W $0028,Y
        JSR.W initBattleState
        PHY
        LDA.W #$0010
CODE_81DE37: ; $01DE37
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
; [Tilemap] 7-bit tile idx * 24; copies from $02:A4E0 to $0E80 buffer
loadTileTemplate: ; $01DE49
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
CODE_81DE5C: ; $01DE5C
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
        JSR.W multiplyUnsigned16
        PLY
        STA.W $0E80,Y
        RTS
; [GameState] AND $7E:EA88; bit-test scenario flags
getScenarioFlags: ; $01DE84
        REP #$20
        AND.L $7EEA88
        RTS
; [GameState] Full battle init: DMA tilemap, processEnemyAI, color math, mode 7
initBattleScene: ; $01DE8B
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
        JSR.W copyTilemapFromWram
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
CODE_81DED6: ; $01DED6
        TYA
        INC A
        STA.L $7EEA8C
CODE_81DEDC: ; $01DEDC
        TXA
        INC A
        STA.L $7EEA82
CODE_81DEE2: ; $01DEE2
        JSL.L processEnemyAI
        LDA.W #$1E22
        STA.L $7FC000
        JSR.W initScrollLimits
        STZ.W $090C
        LDA.W #$3979
        STA.B $7D
        LDA.W #$0007
        JSL.L dispatchGameMode
        JSR.W evtEntityInitScene
        JSL.L updateMenuCursor
        JSR.W centerCameraOnPosition
        LDA.W #$0003
        JSR.W setTimerValue
        JSR.W evtScrollRefreshAllRows
        LDA.W #$0006
        LDX.W #$0082
        LDY.W #$0000
        JSL.L setTextScrollParams
        LDA.W #$007F
        STA.B $14
        LDA.W #$B000
        STA.B $12
        LDA.W #$007F
        STA.B $18
        LDA.W #$F000
        STA.B $16
        LDA.W #$0800
        JSL.L memcpyWords
        JSL.L updateScrollRegisters
        JSR.W drawMessageBox
        LDA.W $09C2
        BNE CODE_81DF54
        LDA.W $09B7
        AND.W #$00FF
        CMP.W #$00C0
        BCC CODE_81DF54
        JMP.W $E045
CODE_81DF54: ; $01DF54
        JSR.W displayScenarioText
        JSL.L updateMenuCursor
        LDA.W #$8000
        STA.B $04
        LDA.W #$0000
        JSL.L clearEntityEntry
        LDX.W #$0004
        JSR.W transitionFromWorldMap
        JSR.W evtCallRenderSprites
        JSR.W confirmAction
        LDA.W $09C2
        BEQ CODE_81DFAC
        PHA
        CMP.W #$0100
        BCS CODE_81DF99
        JSL.L playEntityAnimation
        PLA
        JSR.W evtEntityInitFromScript
        STZ.W $09C2
        LDA.W #$0000
        JSL.L processAIscript
        LDA.W #$0000
        JSR.W soundDispatcher
        JMP.W initBattleScene
CODE_81DF99: ; $01DF99
        LDA.W #$005A
        JSR.W setTextColor
        JSL.L calculateBattleDamage
        PLA
        AND.W #$007F
        STA.W $09C2
        BRA CODE_81DF54
CODE_81DFAC: ; $01DFAC
        STZ.W $09C6
        JSL.L playBGM
        BEQ CODE_81DF54
        LDA.B $50
        AND.W #$8000
        BNE CODE_81DFBF
        JMP.W $E031
CODE_81DFBF: ; $01DFBF
        LDA.W #$0001
        JSR.W callCutsceneHandler
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
CODE_81DFDF: ; $01DFDF
        db $AF,$82,$EA,$7E,$C9,$40,$00,$F0,$D7,$8F,$90,$EA,$7E,$A9,$40,$00
        db $8F,$82,$EA,$7E,$20,$F8,$E0,$22,$E9,$97,$00,$A9,$00,$80,$85,$04
        db $A9,$00,$00,$22,$5E,$98,$00,$A2,$04,$00,$20,$5D,$A2,$80,$23
CODE_81E00E: ; $01E00E
        db $AF,$90,$EA,$7E,$F0,$AB,$8F,$82,$EA,$7E,$4C,$54,$DF
CODE_81E01B: ; $01E01B
        JSR.W clearTextBuffer
        LDA.W #$0001
        JSR.W $D231
        JSR.W clearTextBuffer
        JMP.W $DEA7
CODE_81E02A: ; $01E02A
        JSR.W clearTextBuffer
        LDA.W #$FFFF
        RTS
        LDA.W $09B7
        AND.W #$00FF
        CMP.W #$00C0
        BCS CODE_81E03F
        JMP.W CODE_81E0C4
CODE_81E03F: ; $01E03F
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
CODE_81E077: ; $01E077
        LDX.W #$018C
        LDY.W #$0034
        JSL.L setTextScrollParams
CODE_81E081: ; $01E081
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
        JSR.W displayScenarioText
        JSL.L checkMovementCollision
        BEQ CODE_81E081
        LDA.B $50
        AND.W #$8000
        BEQ CODE_81E0C4
        LDA.W #$0006
        LDX.W #$0082
        LDY.W #$0006
        JSL.L setTextScrollParams
        JSL.L updateMenuCursor
        JMP.W CODE_81DF54
CODE_81E0C4: ; $01E0C4
        LDA.L $7EEA8C
        CMP.W #$0063
        BEQ CODE_81E0ED
        LDA.L $7EEA82
        CMP.W #$0025
        BCS CODE_81E0ED
        CMP.L $7EEA8E
        BEQ CODE_81E0ED
        LDA.W #$00B7
        JSR.W textMetaLookup
        LDA.W $09C6
        BNE CODE_81E0EA
        db $4C,$54,$DF
CODE_81E0EA: ; $01E0EA
        JMP.W CODE_81E081
CODE_81E0ED: ; $01E0ED
        JSL.L playEntityAnimation
        JSR.W clearTextBuffer
        LDA.W #$0000
        RTS
; [Script] Dispatches text meta-table $48/$B8; nav arrows; secondary table
displayScenarioText: ; $01E0F8
        LDA.W $09C2
        BEQ CODE_81E104
        LDA.W #$00B8
        JSR.W textMetaLookup
        RTS
CODE_81E104: ; $01E104
        LDA.W #$0001
        JSR.W callCutsceneHandler
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
CODE_81E135: ; $01E135
        STY.W $0E02
CODE_81E138: ; $01E138
        LDA.W #$0048
        JSR.W textMetaLookup
        LDA.W $0E02
        CMP.W #$0001
        BEQ CODE_81E154
        JSR.W commitDmaFlag
        LDA.L $7EEA82
        CLC
        ADC.W #$0B00
        JSR.W textMetaLookup
CODE_81E154: ; $01E154
        RTS
; [Entity] Unpacks entity type+props from A; calls entityStateConfig + evtEntityPropertySet; RTL
initEntityFromData: ; $01E155
        PHA
        AND.W #$00FF
        JSR.W entityStateConfig
        PLA
        STA.B $00
        LDA.B $01
        AND.W #$00FF
        JSR.W setScreenEffect
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
        JSL.L memfillWords
        LDA.W #$0003
        STA.B $14
        LDA.W #$A140
        STA.B $12
        LDA.W #$0000
        STA.B $18
        LDA.W #$0D80
        STA.B $16
        LDA.W #$0040
        JSL.L memcpyWords
        LDA.W #$0001
        STA.W $0A08
        STZ.W $09DE
        LDA.W #$0318
        JSR.W soundDispatcher
        LDA.W #$0000
        JSR.W loadAndVerifyTilemap
CODE_81E1B4: ; $01E1B4
        LDA.W #$0000
        JSR.W evtEntityInitFromScript
        REP #$20
        LDA.W #$0005
        JSL.L dispatchGameMode
        LDA.W #$1318
        JSR.W soundDispatcher
        LDA.W #$0001
        JSR.W buildSpellMenuTilemap
        JSR.W drawMessageBox
        LDX.W #$04B0
CODE_81E1D5: ; $01E1D5
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
        JSR.W soundDispatcher
        JSR.W clearTextBuffer
        BRA CODE_81E1B4
CODE_81E1F2: ; $01E1F2
        LDA.W #$0001
        JSR.W setTimerValue
        JSR.W clearTextBuffer
        REP #$20
        LDA.W #$000C
        JSL.L dispatchGameMode
        LDA.W #$0029
        LDX.W #$0042
        LDY.W #$0000
        JSL.L setTextScrollParams
        JSR.W clearTilemapRows
        LDA.W #$000C
        JSR.W callCutsceneHandler
        JSR.W buildSaveSlotPreview
        JSR.W drawMessageBox
CODE_81E220: ; $01E220
        LDA.W #$001E
        JSR.W loadTwoSaveSlots
        LDA.W #$0000
        JSR.W initSaveScreen
        LDA.W #$00AE
        JSR.W textMetaLookup
        LDA.W $0A08
        STA.W $09DC
        BEQ CODE_81E220
        LDA.W #$003E
        JSR.W writeTilemapChar
        STZ.W $09DA
CODE_81E243: ; $01E243
        LDA.W $09DA
        JSR.W initSaveScreen
        LDA.W $09DA
        ASL A
        ASL A
        CLC
        ADC.W #$000A
        STA.W $09FE
        LDA.W #$0002
        STA.W $09FC
        JSR.W processFrame
        LDA.B $50
        AND.W #$4080
        BNE CODE_81E298
        LDA.B $50
        AND.W #$8040
        BNE CODE_81E220
        LDA.B $50
        AND.W #$0800
        BNE CODE_81E27C
        LDA.B $50
        AND.W #$0400
        BNE CODE_81E284
        db $80,$C7
        db $AD,$DA,$09,$F0,$C2,$3A,$80,$09
CODE_81E284: ; $01E284
        LDA.W $09DA
        CMP.W #$0002
        BCS CODE_81E243
        INC A
        STA.W $09DA
        LDA.W #$0003
        JSR.W setTimerValue
        BRA CODE_81E243
CODE_81E298: ; $01E298
        LDA.W #$0001
        JSR.W setTimerValue
        LDA.W #$FFFF
        JSR.W loadTwoSaveSlots
        LDA.W $09DA
        JSR.W loadAndVerifyTilemap
        LDA.W $09DC
        CLC
        ADC.W #$00AE
        JSR.W textMetaLookup
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
CODE_81E2E5: ; $01E2E5
        INC.W $0942
        JMP.W $8031
CODE_81E2EB: ; $01E2EB
        LDA.W #$0000
        STA.L $7EEA82
        LDA.W $09DA
        JSR.W saveAndLoadTilemap
        JSR.W buildSaveSlotPreview
CODE_81E2FB: ; $01E2FB
        JMP.W CODE_81E220
; [Save] Loops 3 slots: copies $60 bytes + scenario per slot
buildSaveSlotPreview: ; $01E2FE
        STZ.B $22
CODE_81E300: ; $01E300
        LDA.B $22
        PHA
        LDY.W #$0060
        JSR.W multiplyUnsigned16
        CLC
        ADC.W #$1000
        STA.B $24
        PLA
        JSR.W loadAndVerifyTilemap
        LDY.W #$0000
CODE_81E316: ; $01E316
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
CODE_81E33C: ; $01E33C
        JSR.W clearTilemapRows
        LDA.W #$000D
        JSR.W callCutsceneHandler
CODE_81E345: ; $01E345
        LDA.W #$00B2
        JSR.W textMetaLookup
        LDA.W $0A08
        BEQ CODE_81E345
        DEC A
        BNE CODE_81E35C
        LDA.W $09DA
        ORA.W #$0010
        STA.W $09DA
CODE_81E35C: ; $01E35C
        BRA CODE_81E398
; [Save] Reads 2 slots from SRAM at $C818
loadTwoSaveSlots: ; $01E35E
        LDX.W #$C818
        LDY.W #$0000
        JSR.W loadSaveSlot
        JSR.W loadSaveSlot
; [Save] Reads one SRAM slot; validates; $48 stride
loadSaveSlot: ; $01E36A
        PHA
        PHX
        STX.B $00
        JSR.W setupEntityTile
        PLA
        CLC
        ADC.W #$0048
        TAX
        PLA
        CMP.W #$FFFF
        BEQ CODE_81E37E
        INC A
CODE_81E37E: ; $01E37E
        RTS
; [Save] Sets save mode $0A55; dispatches meta-table $B1
initSaveScreen: ; $01E37F
        STA.W $0A55
        LDY.W #$0060
        JSR.W multiplyUnsigned16
        STA.W $096C
        LDA.W #$0001
        JSR.W callCutsceneHandler
        LDA.W #$00B1
        JSR.W textMetaLookup
        RTS
CODE_81E398: ; $01E398
        JSR.W clearTextBuffer
        LDA.W #$007E
        STA.B $14
        LDA.W #$E000
        STA.B $12
        LDA.W #$2000
        LDX.W #$0000
        JSL.L memfillWords
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
        JSL.L memcpyWords
        STZ.W $0942
        JSR.W populateEntityGrid
        JMP.W $8031
        JSR.W loadScenarioPreserving
        JSR.W clearTextBuffer
        STZ.B $82
        JSR.W populateEntityGrid
        LDA.W #$0000
        JSL.L processAIscript
        LDA.W #$0000
        JSR.W soundDispatcher
        JSR.W initBattleScene
        CMP.W #$FFFF
        BNE CODE_81E423
        LDA.L $7EEA82
        ORA.W #$0100
        STA.L $7EEA82
        JSR.W checkScenarioTransition
        JMP.W $E1BA
CODE_81E423: ; $01E423
        LDA.L $7EEA82
        CMP.W #$0040
        BCC CODE_81E497
        LDA.W #$8000
        JSR.W soundDispatcher
        LDA.L $7EEA82
        AND.W #$003F
        CMP.W #$0002
        BEQ CODE_81E47D
        CMP.W #$0005
        BEQ CODE_81E460
        LDA.W #$0001
        JSR.W evtEntityInitFromScript
        LDA.W $0E23
        AND.W #$00FF
        BNE CODE_81E45D
        LDA.W #$0002
        JSR.W $D231
        LDA.W #$0002
        JSR.W evtEntityInitFromScript
CODE_81E45D: ; $01E45D
        JMP.W $E3F8
CODE_81E460: ; $01E460
        LDA.W #$0005
        JSR.W evtEntityInitFromScript
        LDA.W $0E23
        AND.W #$00FF
        BNE CODE_81E47A
        LDA.W #$0003
        JSR.W $D231
        LDA.W #$0006
        JSR.W evtEntityInitFromScript
CODE_81E47A: ; $01E47A
        JMP.W $E3F8
CODE_81E47D: ; $01E47D
        LDA.W #$0003
        JSR.W evtEntityInitFromScript
        LDA.W $0A08
        CMP.W #$0001
        BNE CODE_81E494
        JSR.W runGameModeSequence
        LDA.W #$0004
        JSR.W evtEntityInitFromScript
CODE_81E494: ; $01E494
        JMP.W $E3F8
CODE_81E497: ; $01E497
        JSR.W showScenarioIntro
        LDA.W $0A08
        CMP.W #$0002
        BNE CODE_81E4A5
        JMP.W $E40A
CODE_81E4A5: ; $01E4A5
        REP #$20
        STZ.W $0942
        LDA.W #$0001
        STA.L $7EEA84
        LDA.W #$0010
        JSR.W soundDispatcher
        JSR.W populateEntityGrid
        LDA.W #$0001
        JSR.W updatePlayTime
        JSR.W initSaveSlotTilemap
        LDA.W #$0002
        JSR.W setTimerValue
        LDA.W #$001E
        JSR.W setTextColor
        JMP.W $8031
; [Entity] Fills 32-entry entity grid from $1400; first 16 conditional
populateEntityGrid: ; $01E4D2
        REP #$20
        STZ.B $0E
CODE_81E4D6: ; $01E4D6
        LDA.B $0E
        LDY.W #$0E00
        JSR.W updateEntity
        LDA.W $0E01
        AND.W #$00FF
        BEQ CODE_81E4E9
        JSR.W initEntitySlot
CODE_81E4E9: ; $01E4E9
        INC.B $0E
        LDA.B $0E
        CMP.W #$0010
        BNE CODE_81E4D6
CODE_81E4F2: ; $01E4F2
        LDA.B $0E
        LDY.W #$0E00
        JSR.W updateEntity
        JSR.W initEntitySlot
        INC.B $0E
        LDA.B $0E
        CMP.W #$0020
        BNE CODE_81E4F2
        JSR.W spawnEntitiesFromFlags
        RTS
; [Entity] Sets active flag, type config, clears fields, flushes to buffer
initEntitySlot: ; $01E50A
        SEP #$20
        LDA.B #$FF
        STA.W $0E00
        LDA.B $0E
        CMP.B #$07
        BCC CODE_81E51A
        STZ.W $0E00
CODE_81E51A: ; $01E51A
        LDA.W $0E01
        CMP.B #$03
        BNE CODE_81E526
        LDA.B #$20
        STA.W $0E03
CODE_81E526: ; $01E526
        STZ.W $0E0F
        LDA.B #$05
        STA.W $0E0A
        STZ.W $0E02
        STZ.W $0E0C
        LDX.W #$0016
CODE_81E537: ; $01E537
        STZ.W $0E00,X
        INX
        CPX.W #$0020
        BNE CODE_81E537
        REP #$20
        LDA.W $0E38
        STA.W $0E08
        STZ.W $0E04
        LDY.W #$0E00
        JSR.W saveEntityToBuffer
        RTS
; [Save] DMA $1400->$7F:B000; filters entities by team
initSaveSlotTilemap: ; $01E552
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
        JSL.L memcpyWords
        LDA.W #$0000
        STA.B $14
        LDA.W #$1400
        STA.B $12
        LDA.W #$0200
        LDX.W #$0000
        JSL.L memfillWords
        LDY.W #$0000
        LDA.W #$00FF
        JSR.W filterEntitiesByTeam
        LDA.W #$0000
        JSR.W filterEntitiesByTeam
        RTS
; [Entity] Scans 16 entries in $7F:B000; copies matching team to $1400
filterEntitiesByTeam: ; $01E593
        STA.B $00
        STZ.B $0E
        LDX.W #$0000
CODE_81E59A: ; $01E59A
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
CODE_81E5B4: ; $01E5B4
        LDA.L $7FB000,X
        STA.W $1400,Y
        INY
        INY
        INX
        INX
        DEC.B $0C
        BNE CODE_81E5B4
        PLX
CODE_81E5C4: ; $01E5C4
        TXA
        CLC
        ADC.W #$0020
        TAX
        INC.B $0E
        LDA.B $0E
        CMP.W #$0010
        BNE CODE_81E59A
        RTS
; [Tilemap] Reads $7F:C000 params; calls drawStatusScreen for decode
setupTilemapReader: ; $01E5D4
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
        JSR.W lookupTilemapTile
        STX.B $02
        LDY.B $04
        RTS
; [Tilemap] Streams words from $7F:9000; row boundaries; X=$FFFF=done
readTilemapStream: ; $01E602
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
CODE_81E617: ; $01E617
        DEC.B $06
        LDY.B $04
        LDA.B $02
        CLC
        ADC.W #$0080
        STA.B $02
        TAX
        PLA
CODE_81E625: ; $01E625
        RTS
; [Save] Saves $EA82, calls checkScenarioTransition, restores
loadScenarioPreserving: ; $01E626
        LDA.L $7EEA82
        PHA
        ORA.W #$0100
        STA.L $7EEA82
        JSR.W checkScenarioTransition
        PLA
        STA.L $7EEA82
        RTS
; [GameState] Checks $EA88 bit 5; falls into saveAndLoadTilemap
checkScenarioTransition: ; $01E63B
        LDA.L $7EEA88
        AND.W #$0020
        BEQ CODE_81E645
        db $60
CODE_81E645: ; $01E645
        LDA.L $7EEA89
        AND.W #$0003
; [Save] Selects SRAM slot by map type; backs up $1400; writes tilemap+checksum
saveAndLoadTilemap: ; $01E64C
        REP #$20
        LDY.W #$0000
        CMP.W #$0002
        BNE CODE_81E659
        db $A0,$40,$15
CODE_81E659: ; $01E659
        CMP.W #$0001
        BNE CODE_81E661
        LDY.W #$0AA0
CODE_81E661: ; $01E661
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
        JSR.W setupTilemapReader
CODE_81E67B: ; $01E67B
        CPX.W #$FFFF
        BEQ CODE_81E68B
        JSR.W readTilemapStream
        STA.B [$16]
        INC.B $16
        INC.B $16
        BRA CODE_81E67B
CODE_81E68B: ; $01E68B
        LDX.W #$0000
CODE_81E68E: ; $01E68E
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
CODE_81E6B3: ; $01E6B3
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
; [Save] Loads from SRAM, verifies checksum; restores entities if valid
loadAndVerifyTilemap: ; $01E6CE
        REP #$20
        LDY.W #$0000
        CMP.W #$0002
        BNE CODE_81E6DB
        LDY.W #$1540
CODE_81E6DB: ; $01E6DB
        CMP.W #$0001
        BNE CODE_81E6E3
        LDY.W #$0AA0
CODE_81E6E3: ; $01E6E3
        TYA
        CLC
        ADC.W #$0010
        STA.B $12
        LDA.W #$0070
        STA.B $14
        LDX.W #$0000
        STZ.B $00
CODE_81E6F4: ; $01E6F4
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
CODE_81E719: ; $01E719
        LDA.L $7EE600,X
        STA.W $1400,X
        INX
        INX
        CPX.W #$0400
        BNE CODE_81E719
        LDA.W #$0000
        RTS
CODE_81E72B: ; $01E72B
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
; [Tilemap] Reads [$16] to $7F:9000 via page tracking
writeTilemapToBuffer: ; $01E744
        REP #$20
        JSR.W setupTilemapReader
CODE_81E749: ; $01E749
        CPX.W #$FFFF
        BEQ CODE_81E75D
        LDA.B [$16]
        STA.L $7F9000,X
        INC.B $16
        INC.B $16
        JSR.W readTilemapStream
        BRA CODE_81E749
CODE_81E75D: ; $01E75D
        RTS
; [Entity] Iterates $7E:EA00-EA7F; flag >= $80 spawns entity
spawnEntitiesFromFlags: ; $01E75E
        REP #$20
        LDX.W #$0000
CODE_81E763: ; $01E763
        LDA.L $7EEA00,X
        AND.W #$00FF
        CMP.W #$0080
        BCC CODE_81E77D
        AND.W #$007F
        JSR.W findEntityByType
        STA.B $0E
        PHX
        TXA
        JSR.W initEntityWithTile
        PLX
CODE_81E77D: ; $01E77D
        INX
        CPX.W #$0080
        BNE CODE_81E763
        RTS
; [Script] Adds $0A08 to $EA8A; sets timer $13; dispatches text $7B
advanceScenarioTimer: ; $01E784
        LDA.W $0A08
        STA.B $24
        LDA.L $7EEA8A
        CLC
        ADC.B $24
        STA.L $7EEA8A
        LDA.W #$0013
        JSR.W setTimerValue
        LDA.W #$007B
        JSR.W textMetaLookup
        RTS
; [GameState] Reads $7E:EA00+X; if <$50 and ==0 returns nonzero; else increments (max 99)
incrementEventFlag: ; $01E7A1
        REP #$20
        PHX
        TAX
        SEP #$20
        LDA.L $7EEA00,X
        CPX.W #$0050
        BCS CODE_81E7B4
        CMP.B #$00
        BNE CODE_81E7C1
CODE_81E7B4: ; $01E7B4
        INC A
        CMP.B #$64
        BCC CODE_81E7BB
        db $A9,$63
CODE_81E7BB: ; $01E7BB
        STA.L $7EEA00,X
        LDA.B #$00
CODE_81E7C1: ; $01E7C1
        REP #$20
        AND.W #$00FF
        PLX
        RTS
; [Entity] Sets entity params; links to event flag at $1416; calls initEntityWithTile
spawnEntityWithFlag: ; $01E7C8
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
CODE_81E7E3: ; $01E7E3
        LDA.W $1416,Y
        AND.W #$00FF
        BEQ CODE_81E802
        db $3A,$AA,$E2,$20,$A9,$00,$99,$16,$14,$1A,$9F,$00,$EA,$7E,$C2,$20
        db $8A,$09,$00,$80,$20,$22,$E8
CODE_81E802: ; $01E802
        LDA.B $0C
        CMP.W #$FFFF
        BNE CODE_81E80A
        RTS
CODE_81E80A: ; $01E80A
        AND.W #$00FF
        TAX
        LDY.B $0A
        SEP #$20
        LDA.W $1401,Y
        ORA.B #$80
        STA.L $7EEA00,X
        REP #$20
        TXA
        JSR.W initEntityWithTile
        RTS
; [Entity] Calls loadTileTemplate; populates entity subtable from $0E8E buffer
initEntityWithTile: ; $01E822
        REP #$20
        STA.B $08
        JSR.W loadTileTemplate
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
CODE_81E846: ; $01E846
        LDY.W #$0E8E
CODE_81E849: ; $01E849
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
CODE_81E868: ; $01E868
        STA.B $00
        LDA.B $08
        BPL CODE_81E876
        db $A5,$00,$3A,$49,$FF,$FF,$85,$00
CODE_81E876: ; $01E876
        LDA.W $1400,X
        JSR.W addSignedOffset
        SEP #$20
        STA.W $1400,X
        REP #$20
        BRA CODE_81E8B4
CODE_81E885: ; $01E885
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
CODE_81E8A4: ; $01E8A4
        db $48,$A9,$B3,$85,$14,$68,$80,$03
CODE_81E8AC: ; $01E8AC
        db $B9,$01,$00
CODE_81E8AF: ; $01E8AF
        STA.W $1400,X
        REP #$20
CODE_81E8B4: ; $01E8B4
        INY
        INY
        CPY.W #$0E98
        BNE CODE_81E849
        RTS
        db $80,$FE
; [Entity] Searches $1401+X type byte across 16 entries (stride $20); returns idx or $FFFF
findEntityByType: ; $01E8BE
        REP #$20
        PHX
        PHY
        STA.B $00
        LDY.W #$0000
        LDX.W #$0000
CODE_81E8CA: ; $01E8CA
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
CODE_81E8E5: ; $01E8E5
        TYA
        PLY
        PLX
        RTS
; [Math] Sign-extends 8-bit→16-bit; adds to $00 clamped [-127,+127]
addSignedOffset: ; $01E8E9
        PHP
        REP #$20
        AND.W #$00FF
        CMP.W #$0080
        BCC CODE_81E8F7
        db $09,$00,$FF
CODE_81E8F7: ; $01E8F7
        STA.B $02
        LDA.B $00
        BPL CODE_81E90E
        db $A5,$02,$18,$65,$00,$10,$19,$C9,$80,$FF,$B0,$03,$A9,$81,$FF,$28
        db $60
CODE_81E90E: ; $01E90E
        LDA.B $02
        CLC
        ADC.B $00
        BMI CODE_81E91D
        CMP.W #$0080
        BCC CODE_81E91D
        db $A9,$7F,$00
CODE_81E91D: ; $01E91D
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
; [Script] Game mode 8; scenario name text (EA82+$200); briefing screen
showScenarioIntro: ; $01EB0F
        REP #$20
        LDA.W #$0008
        JSL.L dispatchGameMode
        LDA.W #$0008
        LDX.W #$0042
        LDY.W #$0000
        JSL.L setTextScrollParams
        JSR.W clearTilemapRows
        LDA.W #$0000
        JSR.W callCutsceneHandler
        LDA.W #$0008
        JSR.W callCutsceneHandler
        LDA.L $7EEA82
        PHA
        DEC A
        CLC
        ADC.W #$0200
        JSR.W textMetaLookup
        JSR.W commitDmaFlag
        PLA
        CLC
        ADC.W #$0B00
        JSR.W textMetaLookup
        JSR.W drawMessageBox
CODE_81EB4F: ; $01EB4F
        LDA.W #$0021
        JSR.W textMetaLookup
        LDA.W $0A08
        BEQ CODE_81EB4F
        CMP.W #$0001
        BEQ CODE_81EB63
        JSR.W clearTextBuffer
        RTS
CODE_81EB63: ; $01EB63
        LDA.W #$8000
        JSR.W soundDispatcher
        JSR.W confirmAction
        LDA.W #$0003
        JSR.W setTimerValue
        LDA.W #$0014
        JSR.W setTextColor
        JSR.W clearTextBuffer
        RTS
; [Helper] Single JSL wrapper to enable IRQ/NMI
enableInterrupts: ; $01EB7C
        JSL.L unpackTileProperties
        RTS
; [Helper] Single JSL wrapper to disable IRQ/NMI
disableInterrupts: ; $01EB81
        JSL.L processScrollLoop
        RTS
; [Music] Routes: >=$8000=SPC direct, $200-$FFF=music, $100-$1FF=SPC reg, <$100=timer
soundDispatcher: ; $01EB86
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
CODE_81EB9D: ; $01EB9D
        CMP.B #$04
        BCS CODE_81EBA3
        LDA.B #$04
CODE_81EBA3: ; $01EBA3
        JSL.L spcSetDspRegister
        BRA CODE_81EBE3
        db $C2,$20
CODE_81EBAB: ; $01EBAB
        TAY
        AND.W #$0FFF
        CMP.W #$0200
        BCC CODE_81EBC8
        PHY
        SEC
        SBC.W #$0200
        JSL.L processAIscript
        JSR.W busyWaitDelay
        PLA
        CMP.W #$1000
        BCC CODE_81EBE3
        BRA CODE_81EBCD
CODE_81EBC8: ; $01EBC8
        CMP.W #$0100
        BCS CODE_81EBE6
CODE_81EBCD: ; $01EBCD
        CLC
        ADC.W #$0021
        SEP #$20
        LDY.W #$0000
        JSL.L externalUtilityFunc2
        LDY.W #$0000
        LDA.B #$AE
        JSL.L spcPlaySfx
CODE_81EBE3: ; $01EBE3
        PLP
        RTS
; [Helper] INC A, store to $81; sets frame/delay timer
setTimerValue: ; $01EBE5
        PHP
CODE_81EBE6: ; $01EBE6
        SEP #$20
        INC A
        STA.B $81
        PLP
        RTS
; [Helper] 300-iteration busy-wait loop; short CPU delay
busyWaitDelay: ; $01EBED
        LDY.W #$012C
CODE_81EBF0: ; $01EBF0
        CLC
        ADC.W #$8801
        BNE CODE_81EBF0
        RTS
; [Text] Stores index $0A22; high nybble→sceneTextDispatch; low 12→textMetaLookup
dispatchSceneText: ; $01EBF7
        REP #$20
        STA.W $0A22
        LDA.W $0A23
        LSR A
        LSR A
        LSR A
        LSR A
        JSR.W sceneTextDispatch
        LDA.W $0A22
        AND.W #$0FFF
        BEQ CODE_81EC11
        JSR.W textMetaLookup
CODE_81EC11: ; $01EC11
        RTS
; [Text] Main scene text dispatcher; masks nibble, dispatches table
sceneTextDispatch: ; $01EC12
        AND.W #$000F
        CMP.W #$000C
        BCS CODE_81EC59
        PHA
        PHA
        LDA.W #$0001
        JSR.W callCutsceneHandler
        JSR.W waitVBlankAndSetup
        PLA
        AND.W #$0007
        CLC
        ADC.W #$0064
        JSR.W textMetaLookup
        JSR.W commitDmaFlag
        PLA
        AND.W #$0008
        BNE CODE_81EC46
        DEC.W $09F6
        DEC.W $09F6
        INC.W $09F2
        INC.W $09F2
        RTS
CODE_81EC46: ; $01EC46
        LDA.W #$0068
        JSR.W textMetaLookup
        LDA.W #$000B
        STA.W $09F0
        LDA.W #$0013
        STA.W $09F4
        RTS
CODE_81EC59: ; $01EC59
        CMP.W #$000F
        BEQ CODE_81EC7D
        PHA
        LDA.W #$0006
        JSR.W callCutsceneHandler
        JSR.W initTilemapAndSync
        PLA
        AND.W #$0003
        CLC
        ADC.W #$003C
        JSR.W textMetaLookup
        JSR.W commitDmaFlag
        LDA.W #$0002
        STA.W $0A0C
        RTS
CODE_81EC7D: ; $01EC7D
        db $A9,$0B,$00,$20,$8D,$EC,$20,$D6,$EC,$A9,$05,$00,$8D,$0C,$0A,$60
; [Script] JSL $00:B26B jump table dispatch
callCutsceneHandler: ; $01EC8D
        JSL.L handleCutscene
        RTS
; [Tilemap] $09FC+$09FE+$0A00; wraps at row 62
calcTilemapOffset_WithWrap: ; $01EC92
        REP #$20
        LDX.W $09FC
        LDA.W $09FE
        CLC
        ADC.W $0A00
        TAY
        CPY.W #$003E
        BNE CODE_81ECA9
        db $AC,$FA,$09,$88,$88
CODE_81ECA9: ; $01ECA9
        JMP.W calcTilemapXY
; [Tilemap] Simpler variant without wrap
calcTilemapOffset: ; $01ECAC
        REP #$20
        LDX.W $09FC
        LDA.W $09FE
        CLC
        ADC.W $0A00
        TAY
; [Tilemap] X*2 + (Y&$1F)<<6 -> $7E:9000 index
calcTilemapXY: ; $01ECB9
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
; [Helper] INC $57, JSR $B7EE; VBlank sync
waitVBlankAndSetup: ; $01ECCC
        PHP
        SEP #$20
        INC.B $57
        JSR.W confirmAction
        PLP
        RTS
; [Tilemap] initTilemapRegion + waitVBlankAndSetup
initTilemapAndSync: ; $01ECD6
        PHP
        REP #$20
        JSR.W initTilemapRegion
        JSR.W waitVBlankAndSetup
        PLP
        RTS
; [Tilemap] RTL wrapper for initTilemapAndSync
initTilemapAndSync_Long: ; $01ECE1
        JSR.W initTilemapRegion
        RTL
; [Tilemap] Sets $0A02=$2000; fills $7E:9000 blank tiles; $09F4/$09F6=cols/rows
initTilemapRegion: ; $01ECE5
        REP #$20
        LDA.W #$2000
        STA.W $0A02
        LDA.W $09F0
        STA.W $09FC
        LDA.W $09F2
        STA.W $09FE
        JSR.W calcTilemapOffset
        STX.B $02
        LDA.W $09F6
        STA.B $00
CODE_81ED03: ; $01ED03
        LDX.B $02
        LDY.W $09F4
        LDA.B $6F
        BEQ CODE_81ED0F
        LDA.W #$3100
CODE_81ED0F: ; $01ED0F
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
        JSR.W calcTilemapXY
        LDA.W #$0000
        LDY.W #$0080
CODE_81ED33: ; $01ED33
        STA.L $7E9000,X
        INX
        INX
        DEY
        BNE CODE_81ED33
        STZ.W $0A04
        STZ.W $0A1A
        RTS
; [Text] calcTilemapOffset_WithWrap + JSL writeTextCharacter
writeTilemapChar: ; $01ED43
        REP #$20
        PHA
        JSR.W calcTilemapOffset_WithWrap
        PLA
        JSL.L checkZeroWrapper
        RTS
; [Helper] Loops processFrame until joypad $50 has D-pad/button ($F0F0 mask)
waitForDpadInput: ; $01ED4F
        PHP
        REP #$20
CODE_81ED52: ; $01ED52
        JSR.W processFrame
        LDA.B $50
        AND.W #$F0F0
        BEQ CODE_81ED52
        PLP
        RTS
; [Text] Joypad read, cursor blink, writeTextCharacter, VBlank loop
processFrame: ; $01ED5E
        PHP
        REP #$20
        JSR.W drawNumber
        STZ.B $0E
CODE_81ED66: ; $01ED66
        JSR.W calcTilemapOffset_WithWrap
        LDY.W #$003E
        INC.B $0E
        LDA.B $0E
        AND.W #$0010
        BEQ CODE_81ED78
        LDY.W #$0000
CODE_81ED78: ; $01ED78
        TYA
        JSL.L checkZeroWrapper
        JSR.W waitVBlankAndSetup
        JSR.W drawNumber
        LDA.B $50
        BEQ CODE_81ED66
        JSR.W calcTilemapOffset_WithWrap
        LDA.W #$0000
        JSL.L checkZeroWrapper
        JSR.W waitVBlankAndSetup
        PLP
        RTS
        db $AD,$10,$0A,$D0,$01,$60,$20,$4F,$ED,$AD,$06,$0A,$F0,$0D,$20,$92
        db $EC,$AD,$06,$0A,$22,$52,$C1,$00,$20,$CC,$EC,$60,$08,$C2,$20,$48
        db $20,$92,$EC,$68,$20,$29,$EE,$20,$CC,$EC,$28,$60,$08,$C2,$20,$48
        db $20,$92,$EC,$A9,$3E,$00,$22,$52,$C1,$00,$E8,$E8,$68,$20,$29,$EE
        db $20,$CC,$EC,$A9,$0E,$00,$48,$A0,$00,$00,$29,$04,$00,$D0,$03,$A0
        db $3E,$00,$5A,$20,$92,$EC,$68,$22,$52,$C1,$00,$20,$CC,$EC,$68,$3A
        db $D0,$E4,$28,$60
; [Tilemap] Fills $7E:9000 with $1100; $19 rows x $1E cols
clearTilemapRows: ; $01EDFA
        REP #$20
        LDX.W #$0102
        LDY.W #$0019
CODE_81EE02: ; $01EE02
        PHY
        PHX
        LDY.W #$001E
        LDA.W #$1100
CODE_81EE0A: ; $01EE0A
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
; [DMA] Copies $0A18 -> $0A1A; triggers VRAM DMA
commitDmaFlag: ; $01EE1E
        PHP
        REP #$20
        LDA.W $0A18
        STA.W $0A1A
        PLP
        RTS
        db $08,$C2,$20,$A8,$BF,$00,$90,$7E,$09,$00,$08,$9F,$00,$90,$7E,$BF
        db $40,$90,$7E,$09,$00,$08,$9F,$40,$90,$7E,$E8,$E8,$88,$D0,$E5,$28
        db $60
; [Text] High byte -> meta-table at $02:8000; low byte -> entry index
textMetaLookup: ; $01EE4A
        REP #$20
        PHA
        STA.B $14
        LDA.B $15
        AND.W #$00FF
        ASL A
        ASL A
        TAX
        LDA.L textMetaTable,X
        STA.B $14
        LDA.L $028002,X
        STA.B $16
        PLA
        AND.W #$00FF
; [Text] JSL TextPtrDispatch hook site
monitorInput_textDispatch: ; $01EE67
        ASL A
        TAY
        LDA.B [$14],Y
        STA.B $14
; [Text] Loads [$14]; $7FFF sentinel = event script redirect
loadTextFromPtr: ; $01EE6D
        REP #$20
        LDA.B [$14]
        CMP.W #$7FFF
        BEQ CODE_81EE7B
        JSL.L fillTextBuffer_Phase1
        RTS
CODE_81EE7B: ; $01EE7B
        INC.B $14
        INC.B $14
        LDA.B $14
        INC A
        STA.W $0A24
        LDA.B $16
        STA.W $0A26
        LDA.B [$14]
        AND.W #$00FF
        JSR.W sceneTextDispatch
        LDA.W $0A26
        STA.B $16
        LDA.W $0A24
        STA.B $14
        JSL.L fillTextBuffer_Phase1
        RTS
        db $08,$E2,$20,$A5,$00,$C9,$FF,$D0,$08,$AD,$FC,$09,$0A,$0A,$0A,$85
        db $00,$A5,$01,$C9,$FF,$D0,$08,$AD,$FE,$09,$0A,$0A,$0A,$85,$01,$28
        db $60
; [Math] Software Y/A division; quotient in A, remainder in Y
divideUnsigned16: ; $01EEC2
        PHP
        REP #$20
        STA.B $04
        TYA
        LDY.W #$0000
CODE_81EECB: ; $01EECB
        SEC
        SBC.B $04
        BCC CODE_81EED3
        INY
        BRA CODE_81EECB
CODE_81EED3: ; $01EED3
        CLC
        ADC.B $04
        PHA
        TYA
        PLY
        PLP
        RTS
; [Math] Software A*Y; low in A, high in Y
multiplyUnsigned16: ; $01EEDB
        PHP
        REP #$20
        STA.B $04
        STZ.B $00
        STZ.B $02
        CPY.W #$0000
        BEQ CODE_81EEFA
CODE_81EEE9: ; $01EEE9
        LDA.B $00
        CLC
        ADC.B $04
        STA.B $00
        LDA.B $02
        ADC.W #$0000
        STA.B $02
        DEY
        BNE CODE_81EEE9
CODE_81EEFA: ; $01EEFA
        LDA.B $00
        LDY.B $02
        PLP
        RTS
        db $08,$C2,$20,$20,$DB,$EE,$8D,$04,$42,$E2,$20,$A9,$64,$8D,$06,$42
        db $EA,$EA,$EA,$EA,$EA,$EA,$EA,$EA,$C2,$20,$AD,$14,$42,$28,$60
; [Math] Uses $4204/$4206; reads $4214 after NOPs
divideHardware8: ; $01EF1F
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
; [Math] A<$8000 unchanged; A>=$8000 negated; Y=1 if negative
absOrZero: ; $01EF37
        LDY.W #$0000
        CMP.W #$8000
        BCS CODE_81EF40
        RTS
CODE_81EF40: ; $01EF40
        INY
        STA.B $00
        LDA.W #$0000
        SEC
        SBC.B $00
        RTS
; [Math] AND #$7FFF; negate if Y!=0
absValue: ; $01EF4A
        AND.W #$7FFF
        CPY.W #$0000
        BNE CODE_81EF53
        RTS
CODE_81EF53: ; $01EF53
        STA.B $00
        LDA.W #$0000
        SEC
        SBC.B $00
        RTS
        db $08,$C2,$20,$E0,$00,$00,$F0,$1F,$85,$14,$20,$37,$EF,$85,$12,$8A
        db $20,$37,$EF,$5A,$A4,$12,$20,$DB,$EE,$A8,$A9,$0A,$00,$20,$C2,$EE
        db $7A,$20,$4A,$EF,$18,$65,$14,$28,$60
; [Helper] Walks 4-byte records; advances 24-bit ptr [$12]:$14
advanceDataPointer: ; $01EF85
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
CODE_81EFA3: ; $01EFA3
        STA.B $12
        PLY
        RTS
; [Tilemap] RTL wrapper for setupTilemapSource
setupTilemapSource_Long: ; $01EFA7
        JSR.W setupTilemapSource
        RTL
; [Tilemap] Configures DMA src by mode in Y; dispatches evtTilemap_ProcessEntry
setupTilemapSource: ; $01EFAB
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
        BRA evtTilemap_ProcessEntry
CODE_81EFCB: ; $01EFCB
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
        BRA evtTilemap_ProcessEntry
CODE_81EFE6: ; $01EFE6
        CPY.W #$0003
        BNE evtTilemap_SetPtr4
        LDA.W #$0021
        STA.B $14
        LDA.W #$D000
        STA.B $12
        LDA.W #$0020
        STA.B $18
        LDA.W #$8000
        STA.B $16
        BRA evtTilemap_ProcessEntry
; [Script] CPY #4 branch: sets $14=#$0038 for tilemap pointer variant.
evtTilemap_SetPtr4: ; $01F001
        CPY.W #$0004
        BNE evtTilemap_SetPtrDefault
        LDA.W #$0038
        STA.B $14
        LDA.W #$8000
        STA.B $12
        LDA.W #$003A
        STA.B $18
        LDA.W #$8000
        STA.B $16
        BRA evtTilemap_ProcessEntry
; [Script] Default tilemap pointer: $14=#$001A, $12=#$A000.
evtTilemap_SetPtrDefault: ; $01F01C
        LDA.W #$001A
        STA.B $14
        LDA.W #$A000
        STA.B $12
        LDA.W #$0016
        STA.B $18
        LDA.W #$8000
        STA.B $16
; [Script] PLA, JSL calculateSpellCost, DEC. Process tilemap entry count.
evtTilemap_ProcessEntry: ; $01F030
        PLA
        JSL.L calculateSpellCost
        DEC A
        BEQ evtTilemap_Done
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
        BCC evtTilemap_SetupIRQ
        JSL.L dmaToVRAMGeneric
; [Script] PLP RTS — tilemap processing complete.
evtTilemap_Done: ; $01F058
        PLP
        RTS
; [Script] JSL setupIRQ, PLP, RTS. Configures IRQ for tilemap raster effects.
evtTilemap_SetupIRQ: ; $01F05A
        JSL.L copyToTileBuffer
        PLP
        RTS
; [Tilemap] Sets up tilemap at bank $23:$F800; spell menu layout
buildSpellMenuTilemap: ; $01F060
        PHP
        REP #$20
        STA.B $28
        LDA.W #$0023
        STA.B $14
        LDA.W #$F800
        STA.B $12
        LDA.B $28
        JSR.W advanceDataPointer
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
; [Script] PHA PHX PHX, LDA #$0023. Tilemap initialization setup.
evtTilemap_Init: ; $01F08F
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
        JSL.L dmaToVRAMGeneric
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
        BNE evtTilemap_Init
        JSL.L updateTurnOrder
        PLP
        RTS
; [Tilemap] Lookup table entry, copy $7E:2000 to dest (even/odd interleave)
copyTilemapFromWram: ; $01F0E4
        PHP
        REP #$20
        JSL.L lookupTableEntry
; [Script] CPX #0, BEQ self (wait loop). Waits for X to become nonzero.
evtTilemap_WaitNonZero: ; $01F0EB
        CPX.W #$0000
        BEQ evtTilemap_WaitNonZero
        STX.B $02
        LDY.W #$0000
        LDX.W #$0000
        LDA.B $16
        STA.B $1A
        SEP #$20
; [Script] LDA $7E2000,X, STA [$16],Y. Copies tilemap data from WRAM $7E2000 to destination.
evtTilemap_CopyFromWRAM: ; $01F0FE
        LDA.L $7E2000,X
        INX
        STA.B [$16],Y
        INY
        INY
        CPY.B $02
        BCC evtTilemap_CopyFromWRAM
        REP #$20
        LDY.W #$0001
        LDA.B $1A
        STA.B $16
        SEP #$20
; [Script] Second copy loop: LDA $7E2000,X, STA [$16],Y. Alternate tilemap copy path.
evtTilemap_CopyFromWRAM2: ; $01F116
        LDA.L $7E2000,X
        INX
        STA.B [$16],Y
        INY
        INY
        CPY.B $02
        BCC evtTilemap_CopyFromWRAM2
        PLP
        RTS
; [Helper] JSL lookupTableEntry + RTS wrapper
lookupTableEntryWrapper: ; $01F125
        JSL.L lookupTableEntry
        RTS
; [Scrolling] Reads $7F:C000 map dims; computes scroll bounds $0A46-$0A4E; sets camera
initScrollLimits: ; $01F12A
        REP #$20
        PHP
        LDA.W #$3132
        STA.B $7D
        LDA.L $7FC000
        JSR.W multiplyBy24
        CLC
        ADC.W #$001C
        SEC
        SBC.W #$00FC
        CMP.W #$0011
        BCS evtScroll_StoreLimit
        db $A9,$11,$00
; [Script] STA $0A46, reads $7FC001. Stores scroll limit value, reads map dimension.
evtScroll_StoreLimit: ; $01F149
        STA.W $0A46
        LDA.L $7FC001
        JSR.W multiplyBy24
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
        JSR.W centerCameraOnPosition
        PLP
        RTS
; [Math] AND #$FF; A*8+A*16=A*24; map tile stride
multiplyBy24: ; $01F17E
        AND.W #$00FF
        ASL A
        ASL A
        ASL A
        STA.B $00
        ASL A
        CLC
        ADC.B $00
        RTS
; [Scrolling] Clamps $00/$02 to scroll limits; stores $60/$62 pixel, $5A tile scroll
centerCameraOnPosition: ; $01F18B
        PHP
        REP #$20
        LDA.B $00
        SEC
        SBC.W #$006C
        BPL evtScroll_ClampMax
        LDA.W #$0000
; [Script] CMP $0A46, BCC. Clamps scroll value to max limit $0A46.
evtScroll_ClampMax: ; $01F199
        CMP.W $0A46
        BCC evtScroll_ClampMinX
        LDA.W $0A46
        DEC A
; [Script] CMP $0A4C, BCS. Clamps X scroll to min $0A4C, stores to $60.
evtScroll_ClampMinX: ; $01F1A2
        CMP.W $0A4C
        BCS evtScroll_StoreX
        LDA.W $0A4C
; [Script] STA $60, LSR*3. Stores X scroll and computes tile column.
evtScroll_StoreX: ; $01F1AA
        STA.B $60
        LSR A
        LSR A
        LSR A
        STA.B $5A
        LDA.B $02
        SEC
        SBC.W #$0058
        BPL evtScroll_ClampMaxY
        LDA.W #$0000
; [Script] CMP $0A48, BCC. Clamps Y scroll to max limit $0A48.
evtScroll_ClampMaxY: ; $01F1BC
        CMP.W $0A48
        BCC evtScroll_ClampMinY
        LDA.W $0A48
        DEC A
; [Script] CMP $0A4E, BCS. Clamps Y scroll to min $0A4E, stores to $62.
evtScroll_ClampMinY: ; $01F1C5
        CMP.W $0A4E
        BCS evtScroll_StoreY
        LDA.W $0A4E
; [Script] STA $62, LSR*3. Stores Y scroll and computes tile row.
evtScroll_StoreY: ; $01F1CD
        STA.B $62
        LSR A
        LSR A
        LSR A
        STA.B $5C
        PLP
        RTS
; [Scrolling] Dispatches X/Y deltas to pos/neg scroll subs; RTL entry
scrollByDelta: ; $01F1D6
        REP #$20
        PHY
        TXA
        BEQ evtScroll_ApplyDelta
        BMI evtScroll_NegDelta
        JSR.W scrollRightByDelta
        BRA evtScroll_ApplyDelta
; [Script] DEC, EOR #$FFFF (negate), JSR $F262. Negative scroll delta path.
evtScroll_NegDelta: ; $01F1E3
        DEC A
        EOR.W #$FFFF
        JSR.W scrollLeftByDelta
; [Script] PLA, BEQ done, BMI negative. Applies scroll delta — positive or negative path.
evtScroll_ApplyDelta: ; $01F1EA
        PLA
        BEQ evtScroll_Return
        BMI evtScroll_NegDeltaY
        JSR.W scrollDownByDelta
        BRA evtScroll_Return
; [Script] DEC, EOR #$FFFF, JSR $F2BF. Negative Y scroll delta.
evtScroll_NegDeltaY: ; $01F1F4
        DEC A
        EOR.W #$FFFF
        JSR.W evtScrollClampY
; [Script] RTL — scroll computation complete.
evtScroll_Return: ; $01F1FB
        RTL
; [Scrolling] JSR processScrollDirty + RTL
processScrollDirtyWrapper: ; $01F1FC
        JSR.W processScrollDirty
        RTL
; [Scrolling] Checks dirty $64; handles deferred tilemap row/col updates
processScrollDirty: ; $01F200
        REP #$20
        LDA.B $64
        BNE evtScroll_CheckOdd
        RTS
; [Script] TAX, AND #1, BEQ skip, DEC $64. Checks odd/even for sub-tile scroll.
evtScroll_CheckOdd: ; $01F207
        TAX
        AND.W #$0001
        BEQ evtScroll_SaveRestore
        DEC.B $64
        RTS
; [Script] LDA $5A PHA, LDA $5C PHA. Saves scroll state before modification.
evtScroll_SaveRestore: ; $01F210
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
        BNE evtScroll_CallAndRestore
        JSR.W renderScrollRowTop
        BRA evtScroll_RestoreState
; [Script] JSR $F406, PLA. Calls scroll offset fn, restores saved state.
evtScroll_CallAndRestore: ; $01F232
        JSR.W renderScrollRowBottom
; [Script] PLA STA $5C, PLA STA $5A. Restores saved scroll X/Y.
evtScroll_RestoreState: ; $01F235
        PLA
        STA.B $5C
        PLA
        STA.B $5A
        STZ.B $64
        RTS
; [Scrolling] Adds A to $60 X scroll; clamps max; marks column dirty
scrollRightByDelta: ; $01F23E
        PHA
        LDA.B $60
        AND.W #$0008
        STA.B $08
        PLA
        CLC
        ADC.B $60
        CMP.W $0A46
        BCC evtScroll_CheckDirtyX
        LDA.W $0A46
        DEC A
; [Script] STA $60, AND #8, CMP $08. Checks if tile column boundary crossed (dirty flag).
evtScroll_CheckDirtyX: ; $01F253
        STA.B $60
        AND.W #$0008
        CMP.B $08
        BEQ evtScroll_RTS
        JSR.W evtTileBufferRowRight
        INC.B $64
; [Script] RTS — scroll sub-function return.
evtScroll_RTS: ; $01F261
        RTS
; [Scrolling] Subtracts A from $60; clamps min; marks column dirty
scrollLeftByDelta: ; $01F262
        STA.B $00
        LDA.B $60
        TAY
        SEC
        SBC.B $00
        BPL evtScroll_ClampMinX2
        db $A9,$00,$00
; [Script] CMP $0A4C, BCS. Second X min clamp path.
evtScroll_ClampMinX2: ; $01F26F
        CMP.W $0A4C
        BCS evtScroll_StoreDirtyX
        LDA.W $0A4C
; [Script] STA $60, AND #8, STA $08. Stores X scroll with dirty bit tracking.
evtScroll_StoreDirtyX: ; $01F277
        STA.B $60
        AND.W #$0008
        STA.B $08
        TYA
        AND.W #$0008
        CMP.B $08
        BEQ evtScroll_RTS2
        JSR.W evtTileBufferRowLeft
        INC.B $64
; [Script] RTS — alternate return point.
evtScroll_RTS2: ; $01F28B
        RTS
; [Scrolling] Adds A to $62 Y scroll; clamps max; marks row dirty
scrollDownByDelta: ; $01F28C
        PHA
        LDA.B $62
        AND.W #$0008
        STA.B $08
        PLA
        CLC
        ADC.B $62
        CMP.W $0A48
        BCC evtScroll_CheckDirtyY
        LDA.W $0A48
        DEC A
; [Script] STA $62, AND #8, CMP $08. Checks if tile row boundary crossed.
evtScroll_CheckDirtyY: ; $01F2A1
        STA.B $62
        AND.W #$0008
        CMP.B $08
        BEQ evtScroll_RTS3
        LDA.B $64
        BNE evtScroll_UpdateRowDown
        JSR.W evtTileBufferRowBottom
        INC.B $5C
        RTS
; [Script] JSR saveScrollState, STA $64=#7, INC $5C. Update tilemap row after scrolling down.
evtScroll_UpdateRowDown: ; $01F2B4
        JSR.W saveScrollState
        LDA.W #$0007
        STA.B $64
        INC.B $5C
; [Script] RTS — Y scroll return.
evtScroll_RTS3: ; $01F2BE
        RTS
; [Scrolling] Clamps Y scroll ($62) to min, checks 8px boundary, triggers row update
evtScrollClampY: ; $01F2BF
        STA.B $00
        LDA.B $62
        TAY
        SEC
        SBC.B $00
        BPL evtScroll_ClampMinY2
        db $A9,$00,$00
; [Script] CMP $0A4E, BCS. Second Y min clamp path.
evtScroll_ClampMinY2: ; $01F2CC
        CMP.W $0A4E
        BCS evtScroll_StoreDirtyY
        LDA.W $0A4E
; [Script] STA $62, AND #8, STA $08. Stores Y scroll with dirty bit.
evtScroll_StoreDirtyY: ; $01F2D4
        STA.B $62
        AND.W #$0008
        STA.B $08
        TYA
        AND.W #$0008
        CMP.B $08
        BEQ evtScroll_RTS4
        LDA.B $64
        BNE evtScroll_UpdateRowUp
        JSR.W evtTileBufferRowDown
        DEC.B $5C
        RTS
; [Script] JSR saveScrollState, STA $64=#3, DEC $5C. Update tilemap row after scrolling up.
evtScroll_UpdateRowUp: ; $01F2ED
        JSR.W saveScrollState
        LDA.W #$0003
        STA.B $64
        DEC.B $5C
; [Script] RTS — scroll update return.
evtScroll_RTS4: ; $01F2F7
        RTS
; [Scrolling] Saves $5A/$5C/$60/$62 to $0A3E-$0A44
saveScrollState: ; $01F2F8
        LDA.B $5A
        STA.W $0A3E
        LDA.B $5C
        STA.W $0A40
        LDA.B $60
        STA.W $0A42
        LDA.B $62
        STA.W $0A44
        RTS
; [Scrolling] Saves/restores $5C; loops 32 rows calling tile column builder + vblank
evtScrollRefreshAllRows: ; $01F30D
        PHP
        REP #$20
        LDA.B $5C
        STA.B $22
        PHA
        LDA.B $62
        STA.B $24
        STZ.B $64
        LDA.W #$0020
; [Script] PHA, LDX $60, LDY $24, JSR $F44B. Updates tilemap column at scroll position.
evtScroll_UpdateColumn: ; $01F31E
        PHA
        LDX.B $60
        LDY.B $24
        JSR.W evtTileBufferColumn
        JSR.W confirmAction
        INC.B $5C
        LDA.B $24
        CLC
        ADC.W #$0008
        STA.B $24
        PLA
        DEC A
        BNE evtScroll_UpdateColumn
        PLA
        STA.B $5C
        PLP
        RTS
; [Scrolling] RTL entry; builds tile buffer, sets $78=#$7800, $57=#$FF/#$FE with vblank
evtScrollInitFullLong: ; $01F33C
        PHP
        REP #$20
        JSR.W confirmAction
        JSR.W evtTileBufferAllRows
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
; [Scrolling] RTS version; calls $B7EE, $F3A0, sets $78/$57 with vblank waits
evtScrollInitFull: ; $01F362
        PHP
        REP #$20
        JSR.W confirmAction
        JSR.W evtTileBufferAllRows
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
; [Scrolling] Partial init: calls $F3A0, sets $78=#$7800, $57=#$FF, one vblank
evtScrollInitPartial: ; $01F388
        PHP
        REP #$20
        JSR.W evtTileBufferAllRows
        LDA.W #$7800
        STA.B $78
        SEP #$20
        LDA.B #$FF
        STA.B $57
        REP #$20
        JSR.W confirmAction
        PLP
        RTS
; [Tilemap] Buffers all 32 rows; copies $0600/$0680 to $7F:B000/$7F:D000
evtTileBufferAllRows: ; $01F3A0
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
; [Script] PHA PHX, JSR $F45E, INC $5C. Buffers one tilemap row for DMA.
evtTile_BufferRow: ; $01F3BA
        PHA
        PHX
        JSR.W evtTileReadRow
        INC.B $5C
        LDA.B $04
        CLC
        ADC.W #$0008
        STA.B $04
        PLX
        LDY.W #$0000
        LDA.W #$0020
        STA.B $00
; [Script] LDA $0600,Y STA $7FB000,X; LDA $0680,Y STA $7FD000,X. Copies tile data to WRAM buffers.
evtTile_CopyToBuffer: ; $01F3D2
        LDA.W $0600,Y
        STA.L $7FB000,X
        LDA.W $0680,Y
        STA.L $7FD000,X
        INY
        INY
        INX
        INX
        DEC.B $00
        BNE evtTile_CopyToBuffer
        TXA
        AND.W #$07FE
        TAX
        PLA
        DEC A
        BNE evtTile_BufferRow
        PLA
        STA.B $5C
        PLP
        RTS
; [Tilemap] Decrements $5C, calls column builder, restores $5C
evtTileBufferRowDown: ; $01F3F6
        LDX.B $60
        LDY.B $62
; [Scrolling] Decrements $5C; calls $F44B for row above view; restores
renderScrollRowTop: ; $01F3FA
        DEC.B $5C
        JSR.W evtTileBufferColumn
        INC.B $5C
        RTS
; [Tilemap] Adds Y+#$F0, $5C+#$1F offset, calls $F44B, restores $5C
evtTileBufferRowBottom: ; $01F402
        LDX.B $60
        LDY.B $62
; [Scrolling] Adds $F0+$1F offsets; calls $F44B for row at bottom edge; restores
renderScrollRowBottom: ; $01F406
        TYA
        CLC
        ADC.W #$00F0
        TAY
        LDA.B $5C
        PHA
        CLC
        ADC.W #$001F
        STA.B $5C
        JSR.W evtTileBufferColumn
        PLA
        STA.B $5C
        RTS
; [Tilemap] Decrements $5A by 1, calls $F4C4, restores
evtTileBufferRowLeft: ; $01F41C
        LDX.B $60
        LDY.B $62
        LDA.B $5A
        PHA
        SEC
        SBC.W #$0001
        STA.B $5A
        JSR.W evtTileReadColumn
        PLA
        DEC A
        STA.B $5A
        RTS
; [Tilemap] Adds #$F8 to $60 for X; falls through to evtTileBufferRowWithOffset
evtTileBufferRowRight: ; $01F431
        LDA.B $60
        CLC
        ADC.W #$00F8
        TAX
        LDY.B $62
        LDA.B $5A
; [Tilemap] Pushes A, adds #$20 to $5A, calls $F4C4, restores
evtTileBufferRowWithOffset: ; $01F43C
        PHA
        CLC
        ADC.W #$0020
        STA.B $5A
        JSR.W evtTileReadColumn
        PLA
        INC A
        STA.B $5A
        RTS
; [Tilemap] Stores X->$02, Y->$04; calls $F45E, sets $05F5=#$01 dirty flag
evtTileBufferColumn: ; $01F44B
        REP #$20
        STX.B $02
        STY.B $04
        JSR.W evtTileReadRow
        SEP #$20
        LDA.B #$01
        STA.W $05F5
        REP #$20
        RTS
; [Tilemap] Computes WRAM addr from $5A/$5C, reads $7F:0000, splits into $0600/$0680
evtTileReadRow: ; $01F45E
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
; [Script] LDA $7F0000,X INX INX PHA. Reads tilemap entry from WRAM $7F bank.
evtTile_ReadWRAM: ; $01F495
        LDA.L $7F0000,X
        INX
        INX
        PHA
        AND.W #$DFFF
        STA.W $0600,Y
        PLA
        AND.W #$2000
        BEQ evtTile_WriteBuffer680
        LDA.B $7D
; [Script] STA $0680,Y, advance. Writes to bottom tilemap buffer $0680.
evtTile_WriteBuffer680: ; $01F4AA
        STA.W $0680,Y
        TYA
        INC A
        INC A
        AND.W #$003F
        TAY
        DEC.B $00
        BNE evtTile_ReadWRAM
        LDA.W #$0040
        STA.W $05F6
        LDA.B $14
        STA.W $05F8
        RTS
; [Tilemap] Reads vertical column from $7F:0000 into $0600/$0680 buffers
evtTileReadColumn: ; $01F4C4
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
; [Script] LDA $7F0000,X, AND #$DFFF, STA $0600,Y. Reads tilemap, clears priority bit, stores to buffer.
evtTile_ReadMask: ; $01F500
        LDA.L $7F0000,X
        PHA
        AND.W #$DFFF
        STA.W $0600,Y
        PLA
        AND.W #$2000
        BEQ evtTile_WriteAndAdvance
        LDA.B $7D
; [Script] STA $0680,Y, TXA CLC ADC #$0100. Writes tile and advances by $100 (next tilemap row).
evtTile_WriteAndAdvance: ; $01F513
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
        BNE evtTile_ReadMask
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
; [Tilemap] Clears BG priority bit (AND #$DF) across $7F:0000 tilemap
evtTileClearPriority: ; $01F544
        PHP
        REP #$20
        STZ.B $06
        LDA.W #$0102
        STA.B $12
; [Script] SEP #$20, STZ $04, LDX $12. 8-bit mode priority bit clearing loop setup.
evtTile_ClearPriority: ; $01F54E
        SEP #$20
        STZ.B $04
        LDX.B $12
; [Script] LDA $7F0001,X AND #$DF STA back. Clears bit 5 (priority) in each tilemap entry.
evtTile_ClearPriorityLoop: ; $01F554
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
        BNE evtTile_ClearPriorityLoop
        LDA.B $06
        INC.B $06
        CMP.L $7FC001
        BEQ evtTile_EndClear
        INC.B $13
        INC.B $13
        INC.B $13
        BRA evtTile_ClearPriority
; [Script] PLP RTS — end of priority clearing.
evtTile_EndClear: ; $01F580
        PLP
        RTS
; [Tilemap] Sets BG priority (ORA #$20) where $7F:A000 overlay mask nonzero
evtTileSetPriority: ; $01F582
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
; [Script] SEP #$20, STZ $04, LDX $12, LDY $14. Priority bit setting loop setup.
evtTile_SetPriority: ; $01F598
        SEP #$20
        STZ.B $04
        LDX.B $12
        LDY.B $14
; [Script] LDA [$16],Y, BEQ skip, ORA #$20 into $7F0001. Sets priority bit where source is nonzero.
evtTile_SetPriorityLoop: ; $01F5A0
        LDA.B [$16],Y
        BEQ evtTile_NextEntry
        LDA.L $7F0001,X
        ORA.B #$20
        STA.L $7F0001,X
; [Script] INX*4 — advance to next tilemap entry (4 bytes per entry).
evtTile_NextEntry: ; $01F5AE
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
        BNE evtTile_SetPriorityLoop
        LDA.B $06
        INC.B $06
        CMP.L $7FC001
        BEQ evtTile_EndSet
        INC.B $13
        INC.B $13
        INC.B $13
        REP #$20
        LDA.B $14
        CLC
        ADC.W #$0080
        STA.B $14
        BRA evtTile_SetPriority
; [Script] PLP RTS — end of priority setting.
evtTile_EndSet: ; $01F5DC
        PLP
        RTS
; [Tilemap] Decompresses tile indices from $7F:9082 to $7F:0306 via evtTileExpandEntry
evtTileDecompressMap: ; $01F5DE
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
; [Script] LDA [$12], INC $12*2, JSR $F63B. Tilemap decompression — reads word, processes tile.
evtTile_DecompLoop: ; $01F607
        LDA.B [$12]
        INC.B $12
        INC.B $12
        JSR.W evtTileExpandEntry
        LDA.B $16
        CLC
        ADC.W #$0006
        STA.B $16
        AND.W #$00FF
        CMP.B $00
        BNE evtTile_DecompCheck
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
; [Script] LDA $02, BNE loop, PLP RTS. Checks remaining count, continues or returns.
evtTile_DecompCheck: ; $01F635
        LDA.B $02
        BNE evtTile_DecompLoop
        PLP
        RTS
; [Tilemap] Expands 9-bit tile index to 3x3 metatile from $7F:6000
evtTileExpandEntry: ; $01F63B
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
; [Tilemap] Maps input 0-3→offset; calls setTimerValue with #$000E
selectMapVariant: ; $01F6AD
        REP #$20
        TAY
        CMP.W #$0002
        BNE evtScene_SetTimerParam
        db $A0,$06,$00
; [Script] CMP #3 -> Y=#$14 else keep Y. Stores Y to $7F, calls evtSetTimer with #$0E.
evtScene_SetTimerParam: ; $01F6B8
        CMP.W #$0003
        BNE evtScene_StoreAndSetTimer
        db $A0,$14,$00
; [Script] STY $7F, LDA #$000E, JSR evtSetTimer, RTS. Final scene timer setup.
evtScene_StoreAndSetTimer: ; $01F6C0
        STY.B $7F
        LDA.W #$000E
        JSR.W setTimerValue
        RTS
; [Entity] Zeros $0A51/$0A53 counters, calls evtEntityClearTable
evtEntityInitScene: ; $01F6C9
        REP #$20
        STZ.W $0A51
        STZ.W $0A53
        JSR.W evtEntityClearTable
        RTS
; [Entity] Clears $1800-$19FF (entity table, 512 bytes) to zero
evtEntityClearTable: ; $01F6D5
        PHP
        SEP #$20
        LDY.W #$0200
        LDX.W #$0000
; [Script] STZ $1800,X INX DEY BNE. Zeros entity table entries at $1800.
evtEntity_ClearLoop: ; $01F6DE
        STZ.W $1800,X
        INX
        DEY
        BNE evtEntity_ClearLoop
        PLP
        RTS
; [OAM] JSL wrapper to renderSprites ($00:C8BB)
evtCallRenderSprites: ; $01F6E7
        REP #$20
        JSL.L renderSprites
        RTS
; [Entity] Decodes entity flags from A; looks up script meta-table $0A:8000; inits entity state
evtEntityInitFromScript: ; $01F6EE
        REP #$20
        CMP.W #$1000
        BCS evtEntity_StoreFlags
        CMP.W #$0064
        BCC evtEntity_StoreFlags
        SEC
        SBC.W #$0064
        ORA.W #$3000
; [Script] STA $06, STZ $08, AND #$03FF STA $04. Stores entity flags, masks to 10 bits.
evtEntity_StoreFlags: ; $01F701
        STA.B $06
        STZ.B $08
        AND.W #$03FF
        STA.B $04
        LDA.B $07
        LSR A
        LSR A
        AND.W #$000C
        TAX
        LDA.L scriptMetaTable,X
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
; [Script] Event script main loop entry. Jumped to from evtNextCmd after counter check.
evtMainLoop: ; $01F751
        LDA.B $85
        BNE evtDispatch
        STZ.W $0A87
        RTS
; [Script] Event script main dispatcher. Reads bytecode from [$85], masks to 6 bits (0-63), indexes into JMP table at $F7B9. [$85] is the script program counter (24-bit long pointer).
evtDispatch: ; $01F759
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
; [Script] DEC $85 — rewinds script PC by 1 byte, then falls into evtNextCmd.
evtRewind1: ; $01F76D
        DEC.B $85
; [Script] Post-command handler. Calls evtCheckDelay, checks $82 counter; if expired, restores saved PC from $0A7F/$0A81. Loops back to evtDispatch.
evtNextCmd: ; $01F76F
        JSR.W evtCheckDelay
        LDA.B $82
        INC A
        BNE evtLoop_BRA
        STZ.B $82
        LDA.W $0A7F
        STA.B $85
        LDA.W $0A81
        STA.B $87
; [Script] BRA evtMainLoop — unconditional branch back to main event loop.
evtLoop_BRA: ; $01F783
        BRA evtMainLoop
; [Script] Checks delay $0A83, input $4E, mode $6A; dispatches event pre-dispatch
evtCheckDelay: ; $01F785
        REP #$20
        JSR.W drawNumber
        LDA.W $0A83
        BEQ evtCheckInput
        LDA.B $4E
        AND.W #$0030
        BEQ evtCheckInput
        STZ.B $8B
; [Script] LDA $82, BEQ skip. Checks input state $4E & $3000 during event execution.
evtCheckInput: ; $01F798
        LDA.B $82
        BEQ evtCheckMode
        LDA.B $4E
        AND.W #$3000
        BEQ evtCheckMode
        LDA.W #$FFFF
        STA.B $82
; [Script] LDA $6A & $FF, CMP #1. Checks game mode byte for event processing variant.
evtCheckMode: ; $01F7A8
        LDA.B $6A
        AND.W #$00FF
        CMP.W #$0001
        BNE evtPreDispatch
        JSR.W evtCallRenderSprites
; [Script] JSR $B7EE (confirmAction), RTS. Pre-dispatch confirmation check, then falls into JMP table.
evtPreDispatch: ; $01F7B5
        JSR.W confirmAction
        RTS
; [Script] 64-entry event command jump table. Each entry is JMP $handler + NOP (4 bytes). Indexed by bytecode & $3F.
evtJmpTable: ; $01F7B9
        JMP.W evtCmd00_End
        db $EA
        JMP.W evtCmd01_Wait
        db $EA,$4C,$13,$F9,$EA
        JMP.W evtCmd03_Store
        db $EA
        JMP.W evtCmd04_Add
        db $EA,$4C,$00,$F9,$EA,$4C,$0C,$F9,$EA
        JMP.W evtCmd07_Random
        db $EA
        JMP.W evtCmd08_Nop
        db $EA,$4C,$1E,$F9,$EA
        JMP.W evtCmd0A_And
        db $EA
        JMP.W evtCmd0B_Compare
        db $EA,$4C,$D0,$F9,$EA
        JMP.W evtCmd0D_WaitInput
        db $EA
        JMP.W evtCmd0E_SetVar
        db $EA
        JMP.W evtCmd0F_TextMeta
        db $EA
        JMP.W evtCmd10_InlineText
        db $EA
        JMP.W evtCmd11_ShowMsg
        db $EA,$4C,$C2,$F9,$EA
        JMP.W evtCmd13_ReadVar
        db $EA
        JMP.W evtCmd14_SetEntity
        db $EA,$4C,$E4,$FA,$EA,$4C,$ED,$FA,$EA,$4C,$32,$F9,$EA
        JMP.W evtCmd18_MoveEntity
        db $EA
        JMP.W evtCmd19_ReadParams
        db $EA,$4C,$04,$FB,$EA
        JMP.W evtCmd1B_SetFlag
        db $EA
        JMP.W evtCmd1C_EntityOp
        db $EA
        JMP.W evtCmd1D_LoadEntity
        db $EA
        JMP.W evtCmd1E_EntityMove
        db $EA
        JMP.W evtCmd1F_Conditional
        db $EA,$4C,$F0,$FB,$EA
        JMP.W evtCmd21_SetPosXY
        db $EA
        JMP.W evtCmd22_SceneSetup
        db $EA
        JMP.W evtCmd23_SetTarget
        db $EA
        JMP.W evtCmd24_CheckEntity
        db $EA
        JMP.W evtCmd25_StoreByte
        db $EA
        JMP.W evtCmd26_CallParam
        db $EA
        JMP.W evtCmd27_EntityByte
        db $EA
        JMP.W evtCmd28_CallWord
        db $EA
        JMP.W evtCmd29_Battle
        db $EA
        JMP.W evtCmd2A_VarByteOp
        db $EA,$4C,$39,$F9,$EA
        JMP.W evtCmd2C_IndirectCall
        db $EA
        JMP.W evtCmd2D_SetScriptVar
        db $EA,$4C,$E9,$FC,$EA
        JMP.W evtCmd2F_DispatchAlt
        db $EA
        JMP.W evtCmd30_SetLongVar
        db $EA
        JMP.W evtCmd31_SetCoords
        db $EA
        JMP.W evtCmd32_AICommand
        db $EA,$4C,$49,$FD,$EA,$4C,$60,$FD,$EA,$4C,$69,$FD,$EA,$4C,$F8,$FD
        db $EA,$4C,$04,$FE,$EA
        JMP.W evtCmd38_LoadEntityData
        db $EA
        JMP.W evtCmd39_SetReturn
        db $EA
        JMP.W evtCmd3A_IndirectAdd
        db $EA
        JMP.W evtCmd3B_Debug
        db $EA
        JMP.W evtCmd3C_TextPtr
        db $EA
        JMP.W evtCmd3D_Sound
        db $EA
        JMP.W evtCmd3E_Effect
        db $EA,$4C,$45,$FC,$EA
; [Script] Cmd $00: End script. Checks $0A7B; if nonzero, does subroutine return. Otherwise STZ $85/$82 to halt script execution.
evtCmd00_End: ; $01F8B9
        LDA.W $0A7B
        BNE evtCmd00_Restore
        STZ.B $85
        STZ.B $82
        LDA.W #$FFFF
        STA.B $8B
        JMP.W evtNextCmd
; [Script] STA $85, STZ $0A7B. Restores script PC from subroutine return, clears call depth.
evtCmd00_Restore: ; $01F8CA
        STA.B $85
        STZ.W $0A7B
        SEP #$20
        LDA.W $0A7D
        STA.B $87
        REP #$20
        JMP.W evtDispatch
; [Script] Cmd $01: Wait/yield. Checks $8B; if zero, loops to dispatcher. If $FFFF, handles specially. Otherwise waits for condition.
evtCmd01_Wait: ; $01F8DB
        LDA.B $8B
        BNE evtCmd01_CheckFFFF
        JMP.W evtDispatch
; [Script] CMP #$FFFF, BEQ store, DEC. Wait counter check — $FFFF means infinite wait.
evtCmd01_CheckFFFF: ; $01F8E2
        CMP.W #$FFFF
        BEQ evtCmd01_StoreWait
        DEC A
; [Script] STA $8B, JMP evtRewind1. Stores wait counter to $8B, rewinds PC to retry.
evtCmd01_StoreWait: ; $01F8E8
        STA.B $8B
        JMP.W evtRewind1
; [Script] Cmd $08: No-op. JMP evtNextCmd immediately.
evtCmd08_Nop: ; $01F8ED
        JMP.W evtNextCmd
; [Script] Cmd $03: Store value. JSR evtReadOperand, STA [$88]. Direct memory write.
evtCmd03_Store: ; $01F8F0
        JSR.W evtReadOperand
; [Script] STA [$88], JMP evtDispatch. Common store-and-continue path for memory write commands.
evtCmd_StoreAndDispatch: ; $01F8F3
        STA.B [$88]
        JMP.W evtDispatch
; [Script] Cmd $04: Add. Reads operand, adds to [$88] (CLC ADC), stores result.
evtCmd04_Add: ; $01F8F8
        JSR.W evtReadOperand
        CLC
        ADC.B [$88]
        BRA evtCmd_StoreAndDispatch
; [Script] Cmd $05: Multiply. Reads operand, multiplies with [$88].
evtCmd05_Mul: ; $01F900
        db $20,$42,$F9,$85,$00,$A7,$88,$38,$E5,$00,$80,$E7
; [Script] Cmd $06: Divide. Reads operand, divides [$88] by it.
evtCmd06_Div: ; $01F90C
        db $20,$42,$F9,$07,$88,$80,$E0
; [Script] Cmd $02: Subtract. Reads operand, subtracts from [$88], stores result.
evtCmd02_Sub: ; $01F913
        db $20,$42,$F9,$A8,$A7,$88,$20,$DB,$EE,$80,$D5
; [Script] Cmd $09: OR. Reads operand, ORs with [$88], stores result.
evtCmd09_Or: ; $01F91E
        db $20,$42,$F9,$48,$A7,$88,$A8,$68,$20,$1F,$EF,$80,$C8
; [Script] Cmd $0A: AND. Reads operand, ANDs with [$88], stores result.
evtCmd0A_And: ; $01F92B
        JSR.W evtReadOperand
        AND.B [$88]
        BRA evtCmd_StoreAndDispatch
; [Script] Cmd $17: Load variable. Falls through to evtReadOperand at $F942.
evtCmd17_LoadVar: ; $01F932
        db $20,$42,$F9,$47,$88,$80,$BA
; [Script] Cmd $2B: Load variable alternate. Falls through to evtReadOperand at $F942.
evtCmd2B_LoadVarAlt: ; $01F939
        db $20,$42,$F9,$22,$47,$DF,$00,$80,$B1
; [Script] Reads 16-bit from [$85]; bit7 $02 = dereference as WRAM address
evtReadOperand: ; $01F942
        LDA.B [$85]
        TAX
        INC.B $85
        INC.B $85
        LDA.B $02
        AND.W #$0080
        BEQ evtOperand_ReturnX
        CPX.W #$8000
        BCC evtOperand_ReadDirect
        LDA.L $7E6A00,X
        RTS
; [Script] LDA $0000,X RTS. Reads direct page value at X offset.
evtOperand_ReadDirect: ; $01F95A
        LDA.W $0000,X
        RTS
; [Script] TXA RTS. Returns X as immediate value (operand is literal).
evtOperand_ReturnX: ; $01F95E
        TXA
        RTS
; [Script] Cmd $23: Set target address. Calls evtReadAddress, stores result to $88 (indirect data pointer). Sets bank byte.
evtCmd23_SetTarget: ; $01F960
        JSR.W evtReadAddress
        LDA.B $00
        STA.B $88
        SEP #$20
        LDA.B $02
        STA.B $8A
        REP #$20
        JMP.W evtDispatch
; [Script] Cmd $25: Store byte. Reads operand, SEP #$20, STA [$88] (8-bit write to target address).
evtCmd25_StoreByte: ; $01F972
        JSR.W evtReadOperand
        SEP #$20
        STA.B [$88]
        REP #$20
        JMP.W evtDispatch
; [Script] Cmd $07: Random number. INC $85, generates random value 0-99 via updateSmokeEffect (RNG), modulo operand.
evtCmd07_Random: ; $01F97E
        INC.B $85
        STZ.B $04
        LDA.W #$0064
        JSL.L hardwareMultiplyRng
        CMP.B $03
        BCS evtCmd0B_ReadBranch
        db $E6,$85,$E6,$85,$E6,$85,$4C,$59,$F7
; [Script] LDA [$85] PHA, INC $85*2. Reads branch offset word from script.
evtCmd0B_ReadBranch: ; $01F996
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
        JMP.W evtDispatch
; [Script] Cmd $0B: Compare and branch. Reads two values via evtReadByte, compares (condition in Y), branches based on result.
evtCmd0B_Compare: ; $01F9AB
        JSR.W evtReadByte
        PHA
        JSR.W evtReadByte
        TAY
        PLA
        CMP.W #$0080
        BNE evtCmd12_FlashScreen
        LDA.W $0A55
; [Script] JSR flashScreen ($C91E), JMP evtNextCmd. Triggers screen flash effect.
evtCmd12_FlashScreen: ; $01F9BC
        JSR.W flashScreen
        JMP.W evtNextCmd
; [Script] Cmd $12: Wait for animation completion. Polls until animation finished.
evtCmd12_WaitAnim: ; $01F9C2
        db $A7,$85,$E6,$85,$29,$FF,$00,$22,$CA,$81,$00,$4C,$6F,$F7
; [Script] Cmd $0C: Delay/sleep. Waits using evtCheckDelay system.
evtCmd0C_Delay: ; $01F9D0
        db $A7,$85,$85,$00,$E6,$85,$E6,$85,$A7,$85,$A8,$E6,$85,$E6,$85,$A7
        db $85,$AA,$E6,$85,$E6,$85,$A5,$00,$22,$60,$81,$00,$4C,$6F,$F7
; [Script] Cmd $0D: Wait for input. Calls waitForInputMask ($ED4F), then evtNextCmd.
evtCmd0D_WaitInput: ; $01F9EF
        JSR.W waitForDpadInput
        JMP.W evtNextCmd
; [Script] Cmd $0E: Set variable. Reads byte, stores to $0E28, advances PC.
evtCmd0E_SetVar: ; $01F9F5
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
        BCS evtCmd0F_SetupMosaic
        JSR.W animateSpellCast
        JMP.W evtNextCmd
; [Script] AND #$1F STA $06, JSR updateMosaic ($CA21). Mosaic effect during text transition.
evtCmd0F_SetupMosaic: ; $01FA15
        AND.W #$001F
        STA.B $06
        JSR.W updateMosaic
        LDA.B $06
        JSR.W evtEntitySlotPtr
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
        JMP.W evtNextCmd
; [Script] Cmd $0F: Text via meta-table. Reads word from [$85], calls $EE4A (textMetaTable lookup). Sets up text pointer for display.
evtCmd0F_TextMeta: ; $01FA42
        LDA.B [$85]
        JSR.W textMetaLookup
        INC.B $85
        INC.B $85
        JMP.W evtDispatch
; [Script] Cmd $10: Inline text display. Sets $14=$85 (current PC as text pointer), $16=$87 (bank). Text follows bytecode inline. This is the [P] command.
evtCmd10_InlineText: ; $01FA4E
        LDA.B $85
        STA.B $14
        LDA.B $87
        AND.W #$00FF
        STA.B $16
        JSR.W loadTextFromPtr
        STA.B $85
        JMP.W evtDispatch
; [Script] Cmd $11: Show message. Reads byte + word, sets up message display with parameters.
evtCmd11_ShowMsg: ; $01FA61
        JSR.W evtReadByte
        PHA
        LDA.B [$85]
        STA.B $00
        INC.B $85
        INC.B $85
        JSR.W evtReadByte
        STA.B $02
        JSR.W evtReadByte
        STA.B $04
        PLA
        JSR.W drawItemScreen
        STA.W $0A55
        CMP.W #$FFFF
        BEQ evtCmd_JmpNextCmd
        LDY.W #$0E00
        JSR.W updateEntity
        LDA.W #$0003
        JSR.W evtBattleDispatch
; [Script] JMP evtNextCmd — common return-to-next-command jump point.
evtCmd_JmpNextCmd: ; $01FA8F
        JMP.W evtNextCmd
; [Script] Cmd $2A: Variable byte operation. Reads byte into $00, reads [$88] masked $FF, compares/processes.
evtCmd2A_VarByteOp: ; $01FA92
        JSR.W evtReadByte
        STA.B $00
        LDA.B [$88]
        AND.W #$00FF
        CMP.B $00
        BCS evtCmd13_BranchToStore
        INC.B $85
        INC.B $85
        INC.B $85
        JMP.W evtDispatch
; [Script] BRA to store path. Part of variable read logic.
evtCmd13_BranchToStore: ; $01FAA9
        BRA evtCmd_ReadAndStore
; [Script] Cmd $13: Read variable. INC $85, reads byte from [$88], masks $00FF, stores to $00. Memory read operation.
evtCmd13_ReadVar: ; $01FAAB
        INC.B $85
        LDA.B [$88]
        AND.W #$00FF
        STA.B $00
        LDA.B $03
        AND.W #$00FF
        CMP.B $00
        BEQ evtCmd_ReadAndStore
        INC.B $85
        INC.B $85
        INC.B $85
        JMP.W evtDispatch
; [Script] LDA [$85] PHA, INC $85*2. Reads word parameter from script stream.
evtCmd_ReadAndStore: ; $01FAC6
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
        JMP.W evtDispatch
; [Script] Cmd $14: Set entity property. Reads byte, calls $DAF8 (entity property dispatch). Modifies entity state.
evtCmd14_SetEntity: ; $01FADB
        JSR.W evtReadByte
        JSR.W setScreenEffect
        JMP.W evtDispatch
; [Script] Cmd $15: Entity control. Falls through to STZ $0A83 + entity operations.
evtCmd15_EntityCtl: ; $01FAE4
        db $20,$06,$FF,$20,$33,$DB,$4C,$59,$F7
; [Script] Cmd $16: Entity control 2. Falls through to $0A83 clear + entity setup.
evtCmd16_EntityCtl2: ; $01FAED
        db $20,$06,$FF,$22,$82,$D9,$00,$4C,$59,$F7
; [Script] Cmd $18: Move entity. STZ $0A83, reads params, computes movement (*4), stores to entity via evtEntitySlotPtr.
evtCmd18_MoveEntity: ; $01FAF7
        STZ.W $0A83
; [Script] JSR evtReadByte, ASL*2, STA $8B. Reads entity index, multiplies by 4.
evtCmd18_ReadAndShift: ; $01FAFA
        JSR.W evtReadByte
        ASL A
        ASL A
        STA.B $8B
        JMP.W evtNextCmd
; [Script] Cmd $19/$1A: Read params. Calls evtReadTwoWords, reads byte from [$85] into Y, advances PC.
evtCmd19_ReadParams: ; $01FB04
        JSR.W evtReadTwoWords
        LDA.B [$85]
        TAY
        INC.B $85
        INC.B $85
        LDA.B $00
        CMP.W #$FFFF
        BEQ evtCmd1B_SetOne
        LDX.B $02
        JSL.L setTextScrollParams
        JMP.W evtNextCmd
; [Script] Falls through to LDA #1, STA $0A83. Sets flag to 1.
evtCmd1B_SetOne: ; $01FB1E
        db $A5,$02,$22,$27,$A4,$00,$4C,$6F,$F7
; [Script] Cmd $1B: Set flag. Stores 1 to $0A83, then branches to entity read at $FAFA.
evtCmd1B_SetFlag: ; $01FB27
        LDA.W #$0001
        STA.W $0A83
        BRA evtCmd18_ReadAndShift
; [Script] Cmd $1C: Entity operation. Reads byte + word params via evtReadByte + evtReadWord.
evtCmd1C_EntityOp: ; $01FB2F
        JSR.W evtReadByte
        PHA
        JSR.W evtReadWord
        STA.B $00
        PLA
        JSR.W handleSaveScreen
        JMP.W evtDispatch
; [Script] Cmd $1D: Load entity data. Reads from $0A59 pointer, loads entity fields $0A61/$0A63/$0A65/$0A67.
evtCmd1D_LoadEntity: ; $01FB3F
        LDX.W $0A59
        LDA.W $0002,X
        STA.W $0A61
        LDA.W $0004,X
        STA.W $0A63
        LDA.B [$85]
        AND.W #$00FF
        STA.W $0A5F
        INC.B $85
        JSR.W evtReadTwoWords
        LDA.B $00
        ORA.B $02
        BNE evtCmd1E_CalcDelta
        db $AD,$00,$10,$85,$00,$AD,$02,$10,$85,$02
; [Script] LDA $00 SEC SBC $0A61, STA $0A65. Calculates movement delta from current to target.
evtCmd1E_CalcDelta: ; $01FB6B
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
        JMP.W evtNextCmd
; [Script] Cmd $1E: Entity movement. Reads $0A57, adds $0A69, processes entity pathfinding.
evtCmd1E_EntityMove: ; $01FB86
        LDA.W $0A57
        CLC
        ADC.W $0A69
        BNE evtCmd1E_Collision
        JMP.W evtDispatch
; [Script] JSL checkEntityCollision, LDX $0A59, stores $22 to entity field. Collision check + position update.
evtCmd1E_Collision: ; $01FB92
        JSL.L checkEntityCollision
        LDX.W $0A59
        LDA.B $22
        STA.W $0002,X
        LDA.B $24
        STA.W $0004,X
        CPX.W #$1800
        BCC evtCmd_JmpRewind
        LDA.W $0A69
        BEQ evtCmd_JmpRewind
        LDA.W $0A6B
        ORA.W #$8000
        STA.W $0008,X
; [Script] JMP evtRewind1 — rewinds script PC by 1 and re-dispatches.
evtCmd_JmpRewind: ; $01FBB6
        JMP.W evtRewind1
; [Script] Cmd $1F: Conditional. Reads byte, if $FF reads $0A55 instead. Branch/compare operation.
evtCmd1F_Conditional: ; $01FBB9
        JSR.W evtReadByte
        CMP.W #$00FF
        BNE evtCmd1F_StoreAndCheck
        db $AD,$55,$0A
; [Script] STA $0A55, CMP #$80, BCC entity path. Stores target, checks if entity index or special.
evtCmd1F_StoreAndCheck: ; $01FBC4
        STA.W $0A55
        CMP.W #$0080
        BCC evtCmd1F_EntityLookup
        AND.W #$007F
        BNE evtCmd1F_SpecialIdx
        db $A9,$02,$12
; [Script] SEC SBC #2, TAX. Converts special index (>=$80) to offset, skips entity lookup.
evtCmd1F_SpecialIdx: ; $01FBD4
        SEC
        SBC.W #$0002
        TAX
        BRA evtCmd1F_StoreEntity
; [Script] JSR evtEntitySlotPtr. Converts entity index to table pointer via * 16 + $1800.
evtCmd1F_EntityLookup: ; $01FBDB
        JSR.W evtEntitySlotPtr
; [Script] STX $0A59, STZ $0A57. Stores entity pointer and clears movement counter.
evtCmd1F_StoreEntity: ; $01FBDE
        STX.W $0A59
        STZ.W $0A57
        LDA.W $0A55
        LDY.W #$0E00
        JSR.W updateEntity
        JMP.W evtDispatch
; [Script] Cmd $20: Set position. Falls through to cmd21 parameter reading.
evtCmd20_SetPos: ; $01FBF0
        db $20,$06,$FF,$18,$6D,$59,$0A,$AA,$A7,$85,$9D,$00,$00,$E6,$85,$E6
        db $85,$4C,$6F,$F7
; [Script] Cmd $21: Set X/Y position. Reads two bytes into $00/$04, sets position coords.
evtCmd21_SetPosXY: ; $01FC04
        JSR.W evtReadByte
        STA.B $00
        STA.B $04
        JSR.W evtReadByte
        STA.B $02
        STA.B $05
        LDA.B $04
        BNE evtCmd20_CheckAlt
        db $E2,$20,$AD,$55,$0A,$85,$00,$AD,$56,$0A,$85,$02,$C2,$20
; [Script] LDA $0A77, BEQ normal. Checks alternate position mode flag.
evtCmd20_CheckAlt: ; $01FC24
        LDA.W $0A77
        BEQ evtCmd20_ReadPos
        db $A5,$04,$AC,$79,$0A,$99,$00,$10,$C8,$C8,$8C,$79,$0A
; [Script] LDA [$85], INC $85*2, LDY $0A75. Reads position word from script.
evtCmd20_ReadPos: ; $01FC36
        LDA.B [$85]
        INC.B $85
        INC.B $85
        LDY.W $0A75
        JSR.W executeAbility
        JMP.W evtDispatch
; [Script] Cmd $3F: Alternate scene setup. Falls through to evtCmd22_SceneSetup.
evtCmd3F_SceneAlt: ; $01FC45
        db $20,$DE,$F5,$20,$62,$F3,$80,$0C
; [Script] Cmd $22: Scene/tilemap setup. Calls $F5DE (WRAM $7F:9082 setup), $F362 (graphics init), sets $81 timer via $EBE5.
evtCmd22_SceneSetup: ; $01FC4D
        JSR.W evtTileDecompressMap
        JSR.W evtScrollInitFull
        LDA.W #$000A
        JSR.W setTimerValue
        JSR.W confirmAction
        LDY.W #$0000
        CPY.W $0A79
        BEQ evtCmd22_JmpNext
        db $5A,$B9,$00,$10,$AC,$77,$0A,$20,$04,$AE,$7A,$C8,$C8,$80,$EC
; [Script] JMP evtNextCmd — scene setup complete, continue.
evtCmd22_JmpNext: ; $01FC73
        JMP.W evtNextCmd
; [Script] Cmd $24: Check entity. Reads word, if zero reads $0E04. Tests entity condition.
evtCmd24_CheckEntity: ; $01FC76
        JSR.W evtReadWord
        TAX
        BNE evtCmd24_CheckFFFF
        LDA.W $0E04
; [Script] STA $00, CMP #$FFFF, BNE continue. Reads entity, $FFFF means read $090A instead.
evtCmd24_CheckFFFF: ; $01FC7F
        STA.B $00
        CMP.W #$FFFF
        BNE evtCmd24_CallConfig
        LDA.W $090A
        STA.B $00
        LDA.W $090C
        STA.B $01
; [Script] JSR evtReadByte, TAX, JSR handleConfigMenu ($A3EA). Entity config via menu system.
evtCmd24_CallConfig: ; $01FC90
        JSR.W evtReadByte
        TAX
        JSR.W handleConfigMenu
        JMP.W evtNextCmd
; [Script] Cmd $26: Call with parameters. Reads byte + address, passes to subroutine.
evtCmd26_CallParam: ; $01FC9A
        JSR.W evtReadByte
        PHA
        JSR.W evtReadAddress
        PLA
        SEP #$20
        STA.B [$00]
        REP #$20
        JMP.W evtNextCmd
; [Script] Cmd $27: Entity byte operation. Reads two words, reads byte from [$85], masks $FF. Entity field access.
evtCmd27_EntityByte: ; $01FCAB
        JSR.W evtReadTwoWords
        LDA.B [$85]
        INC.B $85
        AND.W #$00FF
        STA.B $04
        LDA.B ($00)
        STA.B [$02]
        JMP.W evtNextCmd
; [Script] Cmd $28: Call with word param. Reads word + address, passes to subroutine.
evtCmd28_CallWord: ; $01FCBE
        JSR.W evtReadWord
        PHA
        JSR.W evtReadAddress
        PLA
        STA.B [$00]
        JMP.W evtNextCmd
; [Script] Cmd $29: Start battle/transition. Reads byte, calls $9D33 (battle setup dispatcher). JMP evtNextCmd.
evtCmd29_Battle: ; $01FCCB
        JSR.W evtReadByte
        JSR.W evtBattleDispatch
        JMP.W evtNextCmd
; [Script] Cmd $2C: Indirect call. Reads two words, calls via JMP ($0000) indirect. Dynamic dispatch.
evtCmd2C_IndirectCall: ; $01FCD4
        JSR.W evtReadTwoWords
        JSR.W evtJmpIndirect
        JMP.W evtNextCmd
; [Script] JMP ($0000); trampoline after target loaded to DP $00
evtJmpIndirect: ; $01FCDD
        JMP.W ($0000)
; [Script] Cmd $2D: Set script variable. Reads byte, stores to $0A5B.
evtCmd2D_SetScriptVar: ; $01FCE0
        JSR.W evtReadByte
        STA.W $0A5B
        JMP.W evtDispatch
; [Script] Cmd $2E: Dispatch to sub-handler. Falls through to cmd2F.
evtCmd2E_Dispatch: ; $01FCE9
        db $A0,$00,$0E,$20,$2A,$DE,$4C,$59,$F7
; [Script] Cmd $2F: Dispatch alternate. Reads byte, calls dispatchByIndex64 ($B04F). Sub-command system.
evtCmd2F_DispatchAlt: ; $01FCF2
        JSR.W evtReadByte
        JSR.W dispatchBattleAction
        JMP.W evtDispatch
; [Script] Cmd $30: Set 16-bit variable. Reads word from [$85], stores to $0A6D. Advances PC by 2.
evtCmd30_SetLongVar: ; $01FCFB
        LDA.B [$85]
        INC.B $85
        INC.B $85
        STA.W $0A6D
        INC.W $0A69
        STZ.W $0A6B
        JMP.W evtDispatch
; [Script] Cmd $31: Set coordinates. Reads two words via evtReadWord, stores to $0958/$095A.
evtCmd31_SetCoords: ; $01FD0D
        JSR.W evtReadWord
        STA.W $0958
        JSR.W evtReadWord
        STA.W $095A
        JSR.W evtReadByte
        STA.W $0E03
        JSR.W evtReadByte
        STA.W $0E83
        JSR.W clearBattleUnitState
        STZ.W $0E25
        LDA.W #$0001
        JSL.L dispatchGameMode
        JSL.L initObjectTable
        JSR.W initTilemapAndSync
        JSR.W drawMessageBox
        JMP.W evtDispatch
; [Script] Cmd $32: AI command. Reads byte, calls updateEntityAI (JSL). Entity AI trigger from script.
evtCmd32_AICommand: ; $01FD3F
        JSR.W evtReadByte
        JSL.L updateEntityAI
        JMP.W evtDispatch
; [Script] Cmd $33: Entity state. Complex entity state manipulation.
evtCmd33_EntityState: ; $01FD49
        db $20,$16,$FF,$48,$20,$16,$FF,$A8,$68,$D0,$06,$AD,$28,$0E,$09,$00
        db $80,$20,$04,$AE,$4C,$59,$F7
; [Script] Cmd $34: Entity state 2. Additional entity state operations.
evtCmd34_EntityState2: ; $01FD60
        db $20,$16,$FF,$8D,$75,$0A,$4C,$59,$F7
; [Script] Cmd $35: Entity state 3. Further entity manipulation.
evtCmd35_EntityState3: ; $01FD69
        db $20,$16,$FF,$A8,$D0,$03,$AD,$00,$10,$8D,$61,$0A,$8D,$63,$0A,$20
        db $16,$FF,$A8,$D0,$03,$AD,$00,$12,$18,$6D,$61,$0A,$8D,$65,$0A,$20
        db $16,$FF,$8D,$5F,$0A,$9C,$6D,$0A,$9C,$5D,$0A,$AD,$61,$0A,$85,$00
        db $20,$54,$FF,$AD,$5F,$0A,$C9,$00,$80,$90,$0C,$29,$FF,$7F,$A8,$AD
        db $61,$0A,$20,$04,$AE,$80,$1D,$C9,$00,$40,$90,$09,$29,$FF,$01,$9F
        db $00,$90,$7F,$80,$0F,$BF,$00,$90,$7F,$29,$FF,$01,$CD,$5F,$0A,$F0
        db $03,$EE,$5D,$0A,$E2,$20,$AD,$61,$0A,$1A,$CD,$65,$0A,$90,$0F,$AD
        db $62,$0A,$1A,$CD,$66,$0A,$B0,$0D,$8D,$62,$0A,$AD,$63,$0A,$8D,$61
        db $0A,$C2,$20,$80,$A6,$C2,$20,$AD,$5D,$0A,$87,$88,$4C,$59,$F7
; [Script] Cmd $36: Entity state 4. Entity configuration.
evtCmd36_EntityState4: ; $01FDF8
        db $20,$16,$FF,$8D,$77,$0A,$9C,$79,$0A,$4C,$59,$F7
; [Script] Cmd $37: Entity state 5. Entity parameter setup.
evtCmd37_EntityState5: ; $01FE04
        db $AD,$57,$0A,$18,$6D,$69,$0A,$D0,$03,$4C,$59,$F7,$22,$C9,$CF,$00
        db $AE,$59,$0A,$A5,$22,$9D,$02,$00,$A5,$24,$9D,$04,$00,$AD,$6F,$0A
        db $38,$E5,$24,$10,$03,$A9,$00,$00,$9D,$0E,$00,$4C,$6D,$F7
; [Script] Cmd $38: Load entity data. LDX $0A59, reads entity fields at +$02/+$04 to $0A61/$0A63.
evtCmd38_LoadEntityData: ; $01FE32
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
        JSR.W evtReadTwoWords
        LDA.B $00
        STA.W $0A65
        LDA.B $02
        STA.W $0A67
        INC.W $0A57
        STZ.W $0A5D
        JMP.W evtNextCmd
; [Script] Cmd $39: Set subroutine return. Stores $85+3 to $0A7B (return address for script call).
evtCmd39_SetReturn: ; $01FE68
        LDA.B $85
        CLC
        ADC.W #$0003
        STA.W $0A7B
        LDA.B $87
        STA.W $0A7D
        JMP.W evtCmd_ReadAndStore
; [Script] Cmd $3A: Indirect add. Reads word, reads [$88], adds $02, stores back.
evtCmd3A_IndirectAdd: ; $01FE79
        JSR.W evtReadWord
        LDA.B [$88]
        CLC
        ADC.B $02
        STA.B $00
        LDA.B ($00)
        STA.W $0A08
        JMP.W evtDispatch
; [Script] Cmd $3B: Debug/system command. Reads byte + word params, stores to $06/$08. Multi-purpose system dispatch.
evtCmd3B_Debug: ; $01FE8B
        JSR.W evtReadByte
        PHA
        JSR.W evtReadWord
        STA.B $06
        INC.W $0A87
        LDA.W $1000
        STA.B $02
        LDA.W $1002
        STA.B $04
        PLA
        CMP.W #$00FF
        BEQ evtCmd3C_ReadParams
        JSL.L handleNPCDialogue
        JMP.W evtDispatch
; [Script] Falls to JSR evtReadTwoWords + evtReadByte. Reads 3 params for text pointer setup.
evtCmd3C_ReadParams: ; $01FEAE
        db $22,$DB,$A7,$00,$4C,$59,$F7
; [Script] Cmd $3C: Set text pointer. Reads two words + byte, configures text display from ROM pointer.
evtCmd3C_TextPtr: ; $01FEB5
        JSR.W evtReadTwoWords
        JSR.W evtReadByte
        STA.B $14
        LDA.B $02
        STA.B $12
        LDA.W #$0001
        STA.B $02
        LDA.B $00
        CMP.W #$0100
        BCS evtCmd3C_SetupBits
        PHA
        JSR.W enableInterrupts
        PLA
        CMP.W #$0080
        BCC evtCmd3C_Finish
; [Script] AND #$1F STA $00, LDA #1 STA $02. Extracts 5-bit field and sets flag.
evtCmd3C_SetupBits: ; $01FED7
        db $29,$1F,$00,$85,$00,$A9,$01,$00,$85,$02,$20,$81,$EB
; [Script] JMP evtNextCmd — text pointer setup complete.
evtCmd3C_Finish: ; $01FEE4
        JMP.W evtNextCmd
; [Script] Cmd $3D: Play sound/music. Reads word, calls $EB86. Audio trigger from script.
evtCmd3D_Sound: ; $01FEE7
        JSR.W evtReadWord
        JSR.W soundDispatcher
        JMP.W evtNextCmd
; [Script] Cmd $3E: Visual effect. Reads byte + evtEntitySlotPtr + word. Triggers visual effect on entity.
evtCmd3E_Effect: ; $01FEF0
        JSR.W evtReadByte
        JSR.W evtEntitySlotPtr
        JSR.W evtReadWord
        AND.W #$00FF
        JSR.W searchDataTable
        JSL.L handleEntityDamage
        JMP.W evtDispatch
; [Script] Reads one byte from [$85], advances by 1, masks $00FF
evtReadByte: ; $01FF06
        LDA.B [$85]
        INC.B $85
        AND.W #$00FF
        RTS
; [Script] Reads word to $00, falls through to evtReadWord for $02; advances by 4
evtReadTwoWords: ; $01FF0E
        LDA.B [$85]
        INC.B $85
        INC.B $85
        STA.B $00
; [Script] Reads 16-bit from [$85], advances by 2, stores to $02
evtReadWord: ; $01FF16
        LDA.B [$85]
        INC.B $85
        INC.B $85
        STA.B $02
        RTS
; [Script] Reads 16-bit; 0=default $0A08, >=$8000=WRAM $7E:EA00; resolves 24-bit ptr
evtReadAddress: ; $01FF1F
        LDA.B [$85]
        BNE evtReadAddr_Advance
        LDA.W #$0A08
; [Script] INC $85*2, CMP #$8000, BCC low. Address reader: advances PC, checks high/low address range.
evtReadAddr_Advance: ; $01FF26
        INC.B $85
        INC.B $85
        CMP.W #$8000
        BCC evtReadAddr_Low
        AND.W #$7FFF
        CLC
        ADC.W #$EA00
        STA.B $00
        LDA.W #$007E
        STA.B $02
        RTS
; [Script] STA $00, STZ $02, RTS. Low address path: stores direct, bank $00.
evtReadAddr_Low: ; $01FF3E
        STA.B $00
        STZ.B $02
        RTS
; [Script] Converts entity index (A & $FF) to entity table pointer: X = (A * 16) + $1800. Stride $10, entity table at $1800.
evtEntitySlotPtr: ; $01FF43
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
