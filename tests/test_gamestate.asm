;=====================================================================
; test_gamestate.asm  -  tests for src/GameState.asm
;=====================================================================
INCLUDE Irvine32.inc
INCLUDE Elevator.inc
INCLUDE TestFramework.inc

.code
TestGameState PROC
    mSuite "GameState"

    ; --- structure sizes the rest of the code relies on ---
    mAssertEq SIZEOF FloorInfo, 8, "FloorInfo is 8 bytes"
    mAssertEq SIZEOF HighScore, 24, "HighScore is 24 bytes"
    mAssertEq SIZEOF DiffSetting, 20, "DiffSetting is 20 bytes"
    ; NOTE: LENGTHOF / SIZEOF of an EXTERNDEF array is only one element
    ; outside GameState.asm, so loops must use NUM_FLOORS / MAX_SCORES.

    ; --- base + index * scale addressing reaches the last floor ---
    mov  floors[TOP_FLOOR * SIZEOF FloorInfo].civilians, 7
    mov  esi, OFFSET floors
    mov  ecx, TOP_FLOOR
    movzx eax, (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).civilians
    mAssertEq eax, 7, "indexed addressing reaches floors[TOP_FLOOR]"
    mov  floors[TOP_FLOOR * SIZEOF FloorInfo].civilians, 0

    ; --- GetDiffSetting indexes the table correctly ---
    mov  difficulty, DIFF_EASY
    call GetDiffSetting
    mAssertEq esi, OFFSET difficultyTable, "Easy setting is the first entry"
    mov  difficulty, DIFF_HARD
    call GetDiffSetting
    mov  eax, (DiffSetting PTR [esi]).multiplier
    mAssertEq eax, 3, "Hard multiplier is 3"

    ; --- ResetGameState ---
    mov  difficulty, DIFF_NORMAL
    mov  credits, 999                   ; dirty some state first
    mov  totalScore, 1234
    mov  roundNum, 3
    mov  elevatorFloor, 7
    mov  capacity, 9
    mov  passengersCritical, 2
    mov  quitRequested, 1
    call ResetGameState
    mAssertEq energy, 100, "Normal starts with 100 energy"
    mAssertEq credits, 0, "credits reset to 0"
    mAssertEq totalScore, 0, "totalScore reset to 0"
    mAssertEq roundNum, 1, "roundNum reset to 1"
    mAssertEq elevatorFloor, LOBBY, "elevator starts at the lobby"
    mAssertEq capacity, START_CAPACITY, "capacity reset to START_CAPACITY"
    mAssertEq passengersCritical, 0, "no passengers on board"
    movzx eax, quitRequested
    mAssertEq eax, 0, "quit flag cleared"
    mAssertEq difficulty, DIFF_NORMAL, "difficulty is kept"

    mov  difficulty, DIFF_EASY
    call ResetGameState
    mAssertEq energy, 120, "Easy starts with 120 energy"
    mov  difficulty, DIFF_NORMAL
    ret
TestGameState ENDP

END
