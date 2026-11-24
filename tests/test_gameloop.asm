;=====================================================================
; test_gameloop.asm
; Tests for CheckRoundOver (README section 17, "Scan and round end").
;=====================================================================
INCLUDE Irvine32.inc
INCLUDE Elevator.inc
INCLUDE TestFramework.inc

WAITING_FLOOR = 4

.code
;---------------------------------------------------------------------
; ResetLoopTestState  (helper)
; Empty building except WAITING_FLOOR (2 civilians), elevator at the
; lobby, empty, full energy, not quitting.
;---------------------------------------------------------------------
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

;---------------------------------------------------------------------
; ClearWaitingFloor  (helper)  -  nobody waits anywhere any more
;---------------------------------------------------------------------
ClearWaitingFloor PROC USES eax esi
    mov  esi, OFFSET floors
    mov  eax, WAITING_FLOOR
    mov  (FloorInfo PTR [esi + eax * SIZEOF FloorInfo]).civilians, 0
    mov  (FloorInfo PTR [esi + eax * SIZEOF FloorInfo]).floorFlags, FLAG_EXPIRED
    ret
ClearWaitingFloor ENDP

;---------------------------------------------------------------------
; TestRoundStillPlaying
;---------------------------------------------------------------------
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

;---------------------------------------------------------------------
; TestRoundAllCleared
;---------------------------------------------------------------------
TestRoundAllCleared PROC USES eax
    call ResetLoopTestState
    call ClearWaitingFloor
    call CheckRoundOver
    mAssertEq eax, 1, "nobody waiting and empty car: round over"
    movzx eax, roundOver
    mAssertEq eax, 1, "roundOver is set to 1"
    ret
TestRoundAllCleared ENDP

;---------------------------------------------------------------------
; TestRoundQuit
;---------------------------------------------------------------------
TestRoundQuit PROC USES eax
    call ResetLoopTestState
    mov  quitRequested, 1
    call CheckRoundOver
    mAssertEq eax, 1, "quit ends the round"
    ret
TestRoundQuit ENDP

;---------------------------------------------------------------------
; TestRoundOutOfEnergy
; Energy below MOVE_COST ends the round; passengers are delivered at
; the lobby and lost anywhere else.
;---------------------------------------------------------------------
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

;---------------------------------------------------------------------
; TestGameLoop  -  suite entry point (called from TestMain.asm)
;---------------------------------------------------------------------
TestGameLoop PROC
    mSuite "GameLoop"
    call TestRoundStillPlaying
    call TestRoundAllCleared
    call TestRoundQuit
    call TestRoundOutOfEnergy
    call ResetLoopTestState
    ret
TestGameLoop ENDP

END
