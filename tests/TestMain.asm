; TestMain.asm - starts the test program.
INCLUDE Irvine32.inc
INCLUDE Elevator.inc
INCLUDE TestFramework.inc

TestStrUtil   PROTO
TestGameState PROTO
TestBuilding  PROTO
TestElevator  PROTO
TestScan      PROTO
TestGameLoop  PROTO
TestRender    PROTO
TestScore     PROTO
TestScoreboard PROTO

.data
headerMsg   BYTE "Elevator Rescue Simulator - test runner", 0Dh, 0Ah, 0
summaryMsg  BYTE 0Dh, 0Ah, "Passed: ", 0
failedMsg   BYTE "   Failed: ", 0
newLine     BYTE 0Dh, 0Ah, 0

.code
; Runs every test group, prints how many passed and failed, and exits
; with the number of failures (0 = everything passed). build.bat reads it.
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
