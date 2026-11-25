INCLUDE Irvine32.inc
INCLUDE Elevator.inc
INCLUDE TestFramework.inc

.code
ResetScoreTestState PROC USES ecx esi
    mov  difficulty, DIFF_NORMAL
    mov  elevatorFloor, LOBBY
    mov  energy, 100
    mov  credits, 0
    mov  capacity, START_CAPACITY
    mov  passengersNormal, 0
    mov  passengersCritical, 0
    mov  rescuedNormal, 0
    mov  rescuedCritical, 0
    mov  casualties, 0
    mov  roundScore, 0
    mov  statusMsg, 0
    mov  esi, OFFSET floors
    mov  ecx, NUM_FLOORS
clearFloors:
    mov  (FloorInfo PTR [esi]).civilians, 0
    mov  (FloorInfo PTR [esi]).floorFlags, 0
    mov  (FloorInfo PTR [esi]).ttlLeft, 0
    mov  (FloorInfo PTR [esi]).ttlStart, 0
    add  esi, SIZEOF FloorInfo
    loop clearFloors
    ret
ResetScoreTestState ENDP

TestRoundScore PROC USES eax
    call ResetScoreTestState
    mov  rescuedNormal, 8
    mov  rescuedCritical, 2
    mov  casualties, 3
    mov  energy, 40
    call CalcRoundScore
    mAssertEq eax, 2660, "README example scores 2660"
    mAssertEq roundScore, 2660, "CalcRoundScore stores roundScore"

    mov  difficulty, DIFF_EASY
    call CalcRoundScore
    mAssertEq eax, 1330, "Easy multiplier x1"
    mov  difficulty, DIFF_HARD
    call CalcRoundScore
    mAssertEq eax, 3990, "Hard multiplier x3"

    mov  difficulty, DIFF_NORMAL
    mov  roundScore, 600
    call CalcRoundScore
    call CalcRoundScore
    mAssertEq eax, 2660, "calling it twice gives the same score"

    call ResetScoreTestState
    mov  rescuedNormal, 1
    mov  energy, 0
    mov  casualties, 10
    call CalcRoundScore
    mAssertEq eax, 0, "more penalty than points scores 0"

    call ResetScoreTestState
    mov  rescuedNormal, 1
    mov  energy, 0
    mov  casualties, 2
    call CalcRoundScore
    mAssertEq eax, 0, "penalty equal to points scores 0"

    call ResetScoreTestState
    mov  energy, 50
    call CalcRoundScore
    mAssertEq eax, 200, "50 energy on Normal is 200"

    call ResetScoreTestState
    ret
TestRoundScore ENDP

TestScore PROC
    mSuite "Score and Shop"
    call TestRoundScore
    ret
TestScore ENDP

END
