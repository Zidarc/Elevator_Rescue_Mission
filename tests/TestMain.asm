INCLUDE Irvine32.inc
INCLUDE Constants.inc

INCLUDE GameState.asm
INCLUDE StrUtil.asm
INCLUDE Render.asm
INCLUDE Building.asm
INCLUDE Elevator.asm
INCLUDE Scan.asm
INCLUDE Shop.asm
INCLUDE GameLoop.asm
INCLUDE Score.asm
INCLUDE Scoreboard.asm
INCLUDE Menu.asm

INCLUDE TestFramework.inc   ; mAssertEq and mSuite macros
INCLUDE TestFramework.asm
INCLUDE test_strutil.asm
INCLUDE test_gamestate.asm
INCLUDE test_building.asm
INCLUDE test_elevator.asm
INCLUDE test_scan.asm
INCLUDE test_gameloop.asm
INCLUDE test_render.asm
INCLUDE test_score.asm
INCLUDE test_scoreboard.asm

.data
headerMsg   BYTE "Elevator Rescue Simulator - test runner", 0Dh, 0Ah, 0
summaryMsg  BYTE 0Dh, 0Ah, "Passed: ", 0
failedMsg   BYTE "   Failed: ", 0

.code
testMain PROC
    INVOKE TPrint, ADDR headerMsg

    call TestStrUtil
    call TestGameState
    call TestBuilding
    call TestElevator
    call TestScan
    call TestGameLoop
    call TestRender
    call TestScore
    call TestScoreboard

    INVOKE TPrint, ADDR summaryMsg
    INVOKE TPrintInt, testsPassed
    INVOKE TPrint, ADDR failedMsg
    INVOKE TPrintInt, testsFailed
    INVOKE TPrint, ADDR newLine

    INVOKE ExitProcess, testsFailed
testMain ENDP

END testMain
