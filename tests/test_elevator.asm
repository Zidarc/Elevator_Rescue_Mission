; test_elevator.asm - tests for MoveElevator, PerformAction and TickFloors.

.code

; Puts every variable back to a known starting state before each test.
ResetElevatorTestState PROC USES eax ecx esi
    mov  difficulty, DIFF_NORMAL
    mov  roundNum, 1
    mov  elevatorFloor, LOBBY
    mov  energy, 100
    mov  credits, 0
    mov  capacity, START_CAPACITY
    mov  passengersNormal, 0
    mov  passengersCritical, 0
    mov  roundScore, 0
    mov  totalScore, 0
    mov  rescuedNormal, 0
    mov  rescuedCritical, 0
    mov  casualties, 0
    mov  roundOver, 0
    mov  quitRequested, 0

    ; clear all floors
    mov  esi, OFFSET floors
    mov  ecx, NUM_FLOORS
clearLoop:
    mov  (FloorInfo PTR [esi]).civilians, 0
    mov  (FloorInfo PTR [esi]).floorFlags, 0
    mov  (FloorInfo PTR [esi]).ttlLeft, 0
    mov  (FloorInfo PTR [esi]).ttlStart, 0
    add  esi, SIZEOF FloorInfo
    dec  ecx
    jnz  clearLoop
    ret
ResetElevatorTestState ENDP

; MoveElevator tests

; Moving up from the lobby works and costs energy.
TestMoveUp PROC USES eax edx
    call ResetElevatorTestState
    mov  elevatorFloor, LOBBY
    mov  energy, 100

    mov  edx, 5A5A5A5Ah
    INVOKE MoveElevator, 1              ; up
    mAssertEq eax, 1, "move up from lobby succeeds"
    mAssertEq edx, 5A5A5A5Ah, "MoveElevator preserves EDX"
    mAssertEq elevatorFloor, 1, "elevator is now on floor 1"
    mAssertEq energy, 100 - MOVE_COST, "energy reduced by MOVE_COST"
    movzx eax, floors[1 * SIZEOF FloorInfo].floorFlags
    and  eax, FLAG_SCANNED
    mAssertEq eax, FLAG_SCANNED, "arriving on a floor reveals it"
    ret
TestMoveUp ENDP

; Moving down from floor 5 works.
TestMoveDown PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, 5
    mov  energy, 100

    INVOKE MoveElevator, -1             ; down
    mAssertEq eax, 1, "move down from floor 5 succeeds"
    mAssertEq elevatorFloor, 4, "elevator is now on floor 4"
    mAssertEq energy, 100 - MOVE_COST, "energy reduced by MOVE_COST after move down"
    ret
TestMoveDown ENDP

; Moving up from the top floor is refused and uses no energy.
TestMoveUpFromTop PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, TOP_FLOOR
    mov  energy, 50

    INVOKE MoveElevator, 1
    mAssertEq eax, 0, "move up from top floor is refused"
    mAssertEq elevatorFloor, TOP_FLOOR, "elevator stays at top floor"
    mAssertEq energy, 50, "energy unchanged when move refused at top"
    ret
TestMoveUpFromTop ENDP

; Moving down from the lobby is refused and uses no energy.
TestMoveDownFromLobby PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, LOBBY
    mov  energy, 50

    INVOKE MoveElevator, -1
    mAssertEq eax, 0, "move down from lobby is refused"
    mAssertEq elevatorFloor, LOBBY, "elevator stays at lobby"
    mAssertEq energy, 50, "energy unchanged when move refused at lobby"
    ret
TestMoveDownFromLobby ENDP

; Moving with too little energy is refused.
TestMoveNoEnergy PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, 3
    mov  energy, 1                      ; less than MOVE_COST (2)

    INVOKE MoveElevator, 1
    mAssertEq eax, 0, "move with insufficient energy is refused"
    mAssertEq elevatorFloor, 3, "elevator stays when energy is too low"
    mAssertEq energy, 1, "energy unchanged when move refused for low energy"
    ret
TestMoveNoEnergy ENDP

; Moving with 0 energy is refused.
TestMoveZeroEnergy PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, 5
    mov  energy, 0

    INVOKE MoveElevator, -1
    mAssertEq eax, 0, "move with zero energy is refused"
    mAssertEq energy, 0, "energy stays at zero"
    ret
TestMoveZeroEnergy ENDP

; Moving with exactly 2 energy works and leaves 0.
TestMoveExactEnergy PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, 3
    mov  energy, MOVE_COST

    INVOKE MoveElevator, 1
    mAssertEq eax, 1, "move with exact MOVE_COST energy succeeds"
    mAssertEq elevatorFloor, 4, "elevator moved to floor 4"
    mAssertEq energy, 0, "energy is exactly 0 after the move"
    ret
TestMoveExactEnergy ENDP

; PerformAction tests

; Picking up normal people when there is space.
TestPickUpNormal PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, 3
    ; set floor 3 to have 2 normal civilians
    mov  floors[3 * SIZEOF FloorInfo].civilians, 2
    mov  floors[3 * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS
    mov  floors[3 * SIZEOF FloorInfo].ttlLeft, 30
    mov  floors[3 * SIZEOF FloorInfo].ttlStart, 30

    call PerformAction
    mAssertEq passengersNormal, 2, "picked up 2 normal civilians"
    movzx eax, floors[3 * SIZEOF FloorInfo].civilians
    mAssertEq eax, 0, "floor has 0 civilians remaining"
    movzx eax, floors[3 * SIZEOF FloorInfo].floorFlags
    test eax, FLAG_CIVILIANS
    mov  eax, 0
    jnz  pickNFlagStillSet
    mov  eax, 1
pickNFlagStillSet:
    mAssertEq eax, 1, "FLAG_CIVILIANS cleared when all picked up"
    ret
TestPickUpNormal ENDP

; Only as many people as the free space are taken; the rest stay on the floor.
TestPickUpPartialCapacity PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, 5
    mov  capacity, 4
    mov  passengersNormal, 3            ; 1 free slot

    ; floor 5: 3 normal civilians
    mov  floors[5 * SIZEOF FloorInfo].civilians, 3
    mov  floors[5 * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS
    mov  floors[5 * SIZEOF FloorInfo].ttlLeft, 20

    call PerformAction
    mAssertEq passengersNormal, 4, "took 1 civilian (3+1=4 = capacity)"
    movzx eax, floors[5 * SIZEOF FloorInfo].civilians
    mAssertEq eax, 2, "2 civilians remain on the floor"
    movzx eax, floors[5 * SIZEOF FloorInfo].floorFlags
    and  eax, FLAG_CIVILIANS
    mAssertEq eax, FLAG_CIVILIANS, "FLAG_CIVILIANS still set when civilians remain"
    ret
TestPickUpPartialCapacity ENDP

; Critical people are counted as critical passengers.
TestPickUpCritical PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, 7
    ; floor 7: 2 critical civilians
    mov  floors[7 * SIZEOF FloorInfo].civilians, 2
    mov  floors[7 * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS OR FLAG_CRITICAL
    mov  floors[7 * SIZEOF FloorInfo].ttlLeft, 15

    call PerformAction
    mAssertEq passengersCritical, 2, "picked up 2 critical civilians"
    mAssertEq passengersNormal, 0, "normal passengers unchanged"
    movzx eax, floors[7 * SIZEOF FloorInfo].floorFlags
    and  eax, FLAG_CIVILIANS OR FLAG_CRITICAL
    mAssertEq eax, 0, "civilian and critical flags cleared"
    ret
TestPickUpCritical ENDP

; Nobody is picked up when the elevator is full.
TestPickUpFullElevator PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, 2
    mov  capacity, 4
    mov  passengersNormal, 3
    mov  passengersCritical, 1          ; 3 + 1 = 4 = capacity

    mov  floors[2 * SIZEOF FloorInfo].civilians, 2
    mov  floors[2 * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS

    call PerformAction
    mAssertEq passengersNormal, 3, "normal passengers unchanged when full"
    mAssertEq passengersCritical, 1, "critical passengers unchanged when full"
    movzx eax, floors[2 * SIZEOF FloorInfo].civilians
    mAssertEq eax, 2, "floor civilians unchanged when elevator full"
    ret
TestPickUpFullElevator ENDP

; Energy pack gives +25 and is removed from the floor.
TestCollectEnergyPack PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, 4
    mov  energy, 80

    mov  floors[4 * SIZEOF FloorInfo].floorFlags, FLAG_ENERGY

    call PerformAction
    mAssertEq energy, 80 + ENERGY_PACK, "energy increased by ENERGY_PACK"
    movzx eax, floors[4 * SIZEOF FloorInfo].floorFlags
    and  eax, FLAG_ENERGY
    mAssertEq eax, 0, "FLAG_ENERGY cleared after collection"
    ret
TestCollectEnergyPack ENDP

; Energy pack can not take energy above 150.
TestCollectEnergyCapped PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, 4
    mov  energy, 140                    ; 140 + 25 = 165 > MAX_ENERGY (150)

    mov  floors[4 * SIZEOF FloorInfo].floorFlags, FLAG_ENERGY

    call PerformAction
    mAssertEq energy, MAX_ENERGY, "energy capped at MAX_ENERGY"
    ret
TestCollectEnergyCapped ENDP

; Dropping off in the lobby gives the right points and credits.
TestDropOffAtLobby PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, LOBBY
    mov  passengersNormal, 3
    mov  passengersCritical, 1

    call PerformAction

    ; roundScore should be 3*100 + 1*300 = 600
    mAssertEq roundScore, 3 * NORMAL_POINTS + 1 * CRITICAL_POINTS, "round score after drop-off is 600"
    ; credits should be 3*10 + 1*25 = 55
    mAssertEq credits, 3 * NORMAL_CREDITS + 1 * CRITICAL_CREDITS, "credits after drop-off is 55"
    mAssertEq rescuedNormal, 3, "rescuedNormal is 3"
    mAssertEq rescuedCritical, 1, "rescuedCritical is 1"
    mAssertEq passengersNormal, 0, "normal passengers cleared after drop-off"
    mAssertEq passengersCritical, 0, "critical passengers cleared after drop-off"
    ret
TestDropOffAtLobby ENDP

; Dropping off with nobody on board changes nothing.
TestDropOffEmpty PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, LOBBY
    mov  passengersNormal, 0
    mov  passengersCritical, 0

    call PerformAction
    mAssertEq roundScore, 0, "round score stays 0 with no passengers"
    mAssertEq credits, 0, "credits stay 0 with no passengers"
    mAssertEq rescuedNormal, 0, "rescuedNormal stays 0"
    mAssertEq rescuedCritical, 0, "rescuedCritical stays 0"
    ret
TestDropOffEmpty ENDP

; Two drop-offs add up correctly.
TestDropOffAccumulates PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, LOBBY
    mov  passengersNormal, 2
    mov  passengersCritical, 0
    call PerformAction                  ; first: 2 normal -> 200 pts, 20 credits

    mov  passengersNormal, 1
    mov  passengersCritical, 1
    call PerformAction                  ; second: 1N+1C -> +400 pts, +35 credits

    mAssertEq roundScore, 2 * NORMAL_POINTS + 1 * NORMAL_POINTS + 1 * CRITICAL_POINTS, "accumulated round score is 600"
    mAssertEq credits, 2 * NORMAL_CREDITS + 1 * NORMAL_CREDITS + 1 * CRITICAL_CREDITS, "accumulated credits is 55"
    mAssertEq rescuedNormal, 3, "total rescuedNormal is 3"
    mAssertEq rescuedCritical, 1, "total rescuedCritical is 1"
    ret
TestDropOffAccumulates ENDP

; Action on an empty floor changes nothing.
TestActionOnEmptyFloor PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, 6
    ; floor 6 is already clear from reset

    call PerformAction
    mAssertEq passengersNormal, 0, "no passengers picked up on empty floor"
    mAssertEq energy, 100, "energy unchanged on empty floor"
    ret
TestActionOnEmptyFloor ENDP

; Action on an expired floor does nothing.
TestActionOnExpiredFloor PROC USES eax
    call ResetElevatorTestState
    mov  elevatorFloor, 8
    mov  floors[8 * SIZEOF FloorInfo].floorFlags, FLAG_EXPIRED

    call PerformAction
    mAssertEq passengersNormal, 0, "no pickup on expired floor"
    ret
TestActionOnExpiredFloor ENDP

; TickFloors tests

; One tick takes 1 second off a floor with people.
TestTickDecrement PROC USES eax
    call ResetElevatorTestState
    mov  floors[2 * SIZEOF FloorInfo].civilians, 3
    mov  floors[2 * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS
    mov  floors[2 * SIZEOF FloorInfo].ttlLeft, 20
    mov  floors[2 * SIZEOF FloorInfo].ttlStart, 20

    call TickFloors
    movzx eax, floors[2 * SIZEOF FloorInfo].ttlLeft
    mAssertEq eax, 19, "ttlLeft decremented from 20 to 19"
    mAssertEq casualties, 0, "no casualties when TTL > 0"
    ret
TestTickDecrement ENDP

; A floor with nobody waiting is not ticked.
TestTickNoDecrementEmpty PROC USES eax
    call ResetElevatorTestState
    ; floor 3: energy pack, no civilians
    mov  floors[3 * SIZEOF FloorInfo].floorFlags, FLAG_ENERGY
    mov  floors[3 * SIZEOF FloorInfo].ttlLeft, 12

    call TickFloors
    movzx eax, floors[3 * SIZEOF FloorInfo].ttlLeft
    mAssertEq eax, 12, "ttlLeft unchanged on floor without civilians"
    ret
TestTickNoDecrementEmpty ENDP

; When the timer reaches 0 the people become casualties and the floor is expired.
TestTickExpiry PROC USES eax
    call ResetElevatorTestState
    ; floor 1: 3 civilians, TTL = 1 (will hit 0 on this tick)
    mov  floors[1 * SIZEOF FloorInfo].civilians, 3
    mov  floors[1 * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS
    mov  floors[1 * SIZEOF FloorInfo].ttlLeft, 1
    mov  floors[1 * SIZEOF FloorInfo].ttlStart, 30

    call TickFloors
    mAssertEq casualties, 3, "3 casualties when TTL expires"
    movzx eax, floors[1 * SIZEOF FloorInfo].civilians
    mAssertEq eax, 0, "civilians cleared after expiry"
    movzx eax, floors[1 * SIZEOF FloorInfo].floorFlags
    and  eax, FLAG_EXPIRED
    mAssertEq eax, FLAG_EXPIRED, "FLAG_EXPIRED is set"
    movzx eax, floors[1 * SIZEOF FloorInfo].floorFlags
    and  eax, FLAG_CIVILIANS
    mAssertEq eax, 0, "FLAG_CIVILIANS cleared after expiry"
    movzx eax, floors[1 * SIZEOF FloorInfo].ttlLeft
    mAssertEq eax, 0, "ttlLeft is 0 after expiry"
    ret
TestTickExpiry ENDP

; A critical floor that expires loses both the people and the critical flag.
TestTickCriticalExpiry PROC USES eax
    call ResetElevatorTestState
    mov  floors[4 * SIZEOF FloorInfo].civilians, 2
    mov  floors[4 * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS OR FLAG_CRITICAL
    mov  floors[4 * SIZEOF FloorInfo].ttlLeft, 1

    call TickFloors
    mAssertEq casualties, 2, "2 critical casualties"
    movzx eax, floors[4 * SIZEOF FloorInfo].floorFlags
    and  eax, FLAG_CIVILIANS OR FLAG_CRITICAL
    mAssertEq eax, 0, "both FLAG_CIVILIANS and FLAG_CRITICAL cleared"
    movzx eax, floors[4 * SIZEOF FloorInfo].floorFlags
    and  eax, FLAG_EXPIRED
    mAssertEq eax, FLAG_EXPIRED, "FLAG_EXPIRED set on critical expiry"
    ret
TestTickCriticalExpiry ENDP

; Two floors ticked together: one expires, one survives.
TestTickMultipleFloors PROC USES eax
    call ResetElevatorTestState
    ; floor 1: about to expire
    mov  floors[1 * SIZEOF FloorInfo].civilians, 2
    mov  floors[1 * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS
    mov  floors[1 * SIZEOF FloorInfo].ttlLeft, 1

    ; floor 5: plenty of time
    mov  floors[5 * SIZEOF FloorInfo].civilians, 4
    mov  floors[5 * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS
    mov  floors[5 * SIZEOF FloorInfo].ttlLeft, 40

    call TickFloors
    mAssertEq casualties, 2, "only floor 1 civilians are casualties"
    movzx eax, floors[5 * SIZEOF FloorInfo].ttlLeft
    mAssertEq eax, 39, "floor 5 TTL decremented to 39"
    movzx eax, floors[5 * SIZEOF FloorInfo].civilians
    mAssertEq eax, 4, "floor 5 still has 4 civilians"
    ret
TestTickMultipleFloors ENDP

; The lobby is never ticked.
TestTickLobbyIgnored PROC USES eax
    call ResetElevatorTestState
    ; dirty the lobby (should never happen, but defensive test)
    mov  floors[LOBBY * SIZEOF FloorInfo].civilians, 5
    mov  floors[LOBBY * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS
    mov  floors[LOBBY * SIZEOF FloorInfo].ttlLeft, 10

    call TickFloors
    movzx eax, floors[LOBBY * SIZEOF FloorInfo].ttlLeft
    mAssertEq eax, 10, "lobby TTL is not decremented"
    mAssertEq casualties, 0, "lobby civilians are not counted as casualties"
    ret
TestTickLobbyIgnored ENDP

; Casualties from several floors add up.
TestTickCasualtiesAccumulate PROC USES eax
    call ResetElevatorTestState
    ; floor 2: expires on first tick
    mov  floors[2 * SIZEOF FloorInfo].civilians, 1
    mov  floors[2 * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS
    mov  floors[2 * SIZEOF FloorInfo].ttlLeft, 1
    ; floor 6: expires on second tick
    mov  floors[6 * SIZEOF FloorInfo].civilians, 3
    mov  floors[6 * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS
    mov  floors[6 * SIZEOF FloorInfo].ttlLeft, 2

    call TickFloors                     ; tick 1: floor 2 expires
    mAssertEq casualties, 1, "1 casualty after first tick"
    call TickFloors                     ; tick 2: floor 6 expires
    mAssertEq casualties, 4, "4 total casualties after second tick"
    ret
TestTickCasualtiesAccumulate ENDP

; Runs all Elevator tests.
TestElevator PROC
    mSuite "Elevator"
    ; MoveElevator
    call TestMoveUp
    call TestMoveDown
    call TestMoveUpFromTop
    call TestMoveDownFromLobby
    call TestMoveNoEnergy
    call TestMoveZeroEnergy
    call TestMoveExactEnergy
    ; PerformAction
    call TestPickUpNormal
    call TestPickUpPartialCapacity
    call TestPickUpCritical
    call TestPickUpFullElevator
    call TestCollectEnergyPack
    call TestCollectEnergyCapped
    call TestDropOffAtLobby
    call TestDropOffEmpty
    call TestDropOffAccumulates
    call TestActionOnEmptyFloor
    call TestActionOnExpiredFloor
    ; TickFloors
    call TestTickDecrement
    call TestTickNoDecrementEmpty
    call TestTickExpiry
    call TestTickCriticalExpiry
    call TestTickMultipleFloors
    call TestTickLobbyIgnored
    call TestTickCasualtiesAccumulate
    ret
TestElevator ENDP
