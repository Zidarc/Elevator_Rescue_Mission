WAITING_FLOOR = 4

.code
ResetLoopTestState PROC USES eax ecx esi
    mov  difficulty, DIFF_NORMAL
    mov  elevatorFloor, LOBBY
    mov  energy, 100
    mov  credits, 0
    mov  capacity, START_CAPACITY
    mov  passengersNormal, 0
    mov  passengersCritical, 0
    mov  roundScore, 0
    mov  rescuedNormal, 0
    mov  rescuedCritical, 0
    mov  casualties, 0
    mov  roundOver, 0
    mov  quitRequested, 0

    mov  esi, OFFSET floors
    mov  ecx, NUM_FLOORS
clearFloor:
    mov  (FloorInfo PTR [esi]).civilians, 0
    mov  (FloorInfo PTR [esi]).floorFlags, 0
    mov  (FloorInfo PTR [esi]).ttlLeft, 0
    add  esi, SIZEOF FloorInfo
    loop clearFloor

    mov  esi, OFFSET floors
    mov  eax, WAITING_FLOOR
    mov  (FloorInfo PTR [esi + eax * SIZEOF FloorInfo]).civilians, 2
    mov  (FloorInfo PTR [esi + eax * SIZEOF FloorInfo]).floorFlags, FLAG_CIVILIANS
    ret
ResetLoopTestState ENDP

ClearWaitingFloor PROC USES eax esi
    mov  esi, OFFSET floors
    mov  eax, WAITING_FLOOR
    mov  (FloorInfo PTR [esi + eax * SIZEOF FloorInfo]).civilians, 0
    mov  (FloorInfo PTR [esi + eax * SIZEOF FloorInfo]).floorFlags, FLAG_EXPIRED
    ret
ClearWaitingFloor ENDP

TestRoundStillPlaying PROC USES eax
    call ResetLoopTestState
    call CheckRoundOver
    mAssertEq eax, 0, "civilians waiting: round continues"
    movzx eax, roundOver
    mAssertEq eax, 0, "roundOver stays 0"

    ; nobody waiting but passengers still on board
    call ResetLoopTestState
    call ClearWaitingFloor
    mov  passengersNormal, 1
    call CheckRoundOver
    mAssertEq eax, 0, "passengers on board: round continues"
    ret
TestRoundStillPlaying ENDP

TestRoundAllCleared PROC USES eax
    call ResetLoopTestState
    call ClearWaitingFloor
    call CheckRoundOver
    mAssertEq eax, 1, "nobody waiting and empty car: round over"
    movzx eax, roundOver
    mAssertEq eax, 1, "roundOver is set to 1"
    ret
TestRoundAllCleared ENDP

TestRoundQuit PROC USES eax
    call ResetLoopTestState
    mov  quitRequested, 1
    call CheckRoundOver
    mAssertEq eax, 1, "quit ends the round"
    ret
TestRoundQuit ENDP

TestRoundOutOfEnergy PROC USES eax
    call ResetLoopTestState
    mov  energy, 0
    call CheckRoundOver
    mAssertEq eax, 1, "energy 0 ends the round"

    call ResetLoopTestState
    mov  energy, MOVE_COST - 1
    call CheckRoundOver
    mAssertEq eax, 1, "energy below MOVE_COST ends the round"

    call ResetLoopTestState
    mov  energy, MOVE_COST
    call CheckRoundOver
    mAssertEq eax, 0, "energy equal to MOVE_COST keeps playing"

    ; stranded away from the lobby: passengers lost
    call ResetLoopTestState
    mov  energy, 0
    mov  elevatorFloor, 6
    mov  passengersNormal, 2
    mov  passengersCritical, 1
    call CheckRoundOver
    mAssertEq casualties, 3, "stranded passengers become casualties"
    mAssertEq passengersNormal, 0, "car emptied after stranding"
    mAssertEq passengersCritical, 0, "critical passengers cleared too"

    ; stopped at the lobby: passengers delivered
    call ResetLoopTestState
    mov  energy, 0
    mov  elevatorFloor, LOBBY
    mov  passengersNormal, 2
    call CheckRoundOver
    mAssertEq rescuedNormal, 2, "passengers delivered at the lobby"
    mAssertEq casualties, 0, "no casualties at the lobby"
    ret
TestRoundOutOfEnergy ENDP

TestHandleCommand PROC USES eax
    call ResetLoopTestState
    INVOKE HandleCommand, 'w'
    mAssertEq eax, 1, "w is a command"
    mAssertEq elevatorFloor, 1, "w moves up (lower case)"
    INVOKE HandleCommand, 'W'
    mAssertEq elevatorFloor, 2, "W moves up (upper case)"
    INVOKE HandleCommand, 's'
    mAssertEq elevatorFloor, 1, "s moves down"
    mAssertEq energy, 100 - 3 * MOVE_COST, "three moves cost 3 x MOVE_COST"

    call ResetLoopTestState
    INVOKE HandleCommand, 'X'
    mAssertEq energy, 100 - SCAN_COST, "X runs a scan"

    call ResetLoopTestState
    mov  elevatorFloor, WAITING_FLOOR
    INVOKE HandleCommand, 'a'
    mAssertEq passengersNormal, 2, "a picks up the waiting civilians"

    call ResetLoopTestState
    INVOKE HandleCommand, 'q'
    movzx eax, quitRequested
    mAssertEq eax, 1, "q sets quitRequested"

    call ResetLoopTestState
    mov  elevatorFloor, WAITING_FLOOR
    mov  credits, 100
    INVOKE HandleCommand, 'B'
    mAssertEq eax, 1, "B is a command"
    mAssertEq credits, 100, "B away from the lobby spends nothing"

    call ResetLoopTestState
    INVOKE HandleCommand, 'Z'
    mAssertEq eax, 0, "Z is ignored"
    INVOKE HandleCommand, '7'
    mAssertEq eax, 0, "7 is ignored"
    mAssertEq elevatorFloor, LOBBY, "ignored keys do not move"
    mAssertEq energy, 100, "ignored keys use no energy"
    ret
TestHandleCommand ENDP

TestGameLoop PROC
    mSuite "GameLoop"
    call TestRoundStillPlaying
    call TestRoundAllCleared
    call TestRoundQuit
    call TestRoundOutOfEnergy
    call TestHandleCommand
    call ResetLoopTestState
    ret
TestGameLoop ENDP
