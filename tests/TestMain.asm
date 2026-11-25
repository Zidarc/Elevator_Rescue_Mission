;=====================================================================
; TestMain.asm
; Test runner entry point. Calls every test suite, prints a summary
; and exits with the number of failed assertions (0 = all passed),
; so build.bat can report success or failure.
;
; Adding a suite:
;   1. Create tests/test_<module>.asm with a "Test<Module> PROC".
;   2. Add a PROTO below and a "call Test<Module>" in testMain.
;   build.bat picks up every .asm in tests/ automatically.
;=====================================================================
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

.data
headerMsg   BYTE "Elevator Rescue Simulator - test runner", 0Dh, 0Ah, 0
summaryMsg  BYTE 0Dh, 0Ah, "Passed: ", 0
failedMsg   BYTE "   Failed: ", 0
newLine     BYTE 0Dh, 0Ah, 0

.code
testMain PROC
    INVOKE TPrint, ADDR headerMsg

    call TestStrUtil                    ; Day 1
    call TestGameState                  ; Day 1
    call TestBuilding                   ; Day 2
    call TestElevator                   ; Day 3
    call TestScan                       ; Day 4
    call TestGameLoop                   ; Day 4
    call TestRender
    call TestScore
    ; call TestScoreboard               ; Day 7

    INVOKE TPrint, ADDR summaryMsg
    INVOKE TPrintInt, testsPassed
    INVOKE TPrint, ADDR failedMsg
    INVOKE TPrintInt, testsFailed
    INVOKE TPrint, ADDR newLine

    INVOKE ExitProcess, testsFailed
testMain ENDP

END testMain
