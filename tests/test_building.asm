;=====================================================================
; test_building.asm  -  tests for src/Building.asm
;
; Random procedures are checked on their RANGE (many calls, count the
; ones that fall outside), never on exact values.
; SelectDifficulty reads the keyboard, so it is tested by hand.
;=====================================================================
INCLUDE Irvine32.inc
INCLUDE Elevator.inc
INCLUDE TestFramework.inc

TEST_FLOOR   = 3                        ; any floor 1..TOP_FLOOR
ROLL_COUNT   = 1000
FLOOR_COUNT  = 800
TTL_COUNT    = 500

.data
bldSeenMask     DWORD 0                 ; bit 0 normal, 1 critical, 2 energy, 3 empty
bldBadNormal    DWORD 0
bldBadCritical  DWORD 0
bldBadEnergy    DWORD 0
bldBadEmpty     DWORD 0

.code
;---------------------------------------------------------------------
; TestRollFloorType
; 1000 rolls on Normal: all results are valid and all four types occur.
;---------------------------------------------------------------------
TestRollFloorType PROC USES eax ebx ecx edx
    mov  difficulty, DIFF_NORMAL
    xor  ebx, ebx                       ; EBX = results out of range
    xor  edx, edx                       ; EDX = bit mask of types seen
    mov  ecx, ROLL_COUNT
rollLoop:
    call RollFloorType
    cmp  eax, FT_ENERGY
    ja   rollBad
    bts  edx, eax                       ; remember this type
    jmp  rollNext
rollBad:
    inc  ebx
rollNext:
    dec  ecx
    jnz  rollLoop

    mAssertEq ebx, 0, "1000 rolls stay in FT_EMPTY..FT_ENERGY"
    mAssertEq edx, 1111b, "all four floor types are rolled"
    ret
TestRollFloorType ENDP

;---------------------------------------------------------------------
; TestFloorContents
; 800 generated floors on Normal, round 1. Every floor must match its
; type: flags, civilian count and TTL range (Normal table: 30..60,
; critical = half of that = 15..30).
;---------------------------------------------------------------------
TestFloorContents PROC USES eax ebx ecx edx esi
    mov  difficulty, DIFF_NORMAL
    mov  roundNum, 1
    mov  bldSeenMask, 0
    mov  bldBadNormal, 0
    mov  bldBadCritical, 0
    mov  bldBadEnergy, 0
    mov  bldBadEmpty, 0

    mov  esi, OFFSET floors
    add  esi, TEST_FLOOR * SIZEOF FloorInfo
    mov  ecx, FLOOR_COUNT
floorLoop:
    INVOKE GenerateFloor, TEST_FLOOR
    movzx eax, (FloorInfo PTR [esi]).floorFlags
    movzx ebx, (FloorInfo PTR [esi]).civilians
    movzx edx, (FloorInfo PTR [esi]).ttlLeft

    test al, FLAG_CRITICAL
    jnz  checkCritical
    test al, FLAG_CIVILIANS
    jnz  checkNormal
    test al, FLAG_ENERGY
    jnz  checkEnergy

    ; --- empty floor: no flags, no civilians, no TTL ---
    or   bldSeenMask, 1000b
    or   eax, ebx
    or   eax, edx
    jz   floorNext
    inc  bldBadEmpty
    jmp  floorNext

checkNormal:
    or   bldSeenMask, 0001b
    cmp  eax, FLAG_CIVILIANS            ; exactly this flag, nothing else
    jne  normalBad
    cmp  ebx, NORMAL_CIV_MIN
    jb   normalBad
    cmp  ebx, NORMAL_CIV_MAX
    ja   normalBad
    cmp  edx, 30
    jb   normalBad
    cmp  edx, 60
    ja   normalBad
    movzx eax, (FloorInfo PTR [esi]).ttlStart
    cmp  eax, edx                       ; ttlStart equals ttlLeft
    jne  normalBad
    jmp  floorNext
normalBad:
    inc  bldBadNormal
    jmp  floorNext

checkCritical:
    or   bldSeenMask, 0010b
    cmp  eax, FLAG_CIVILIANS OR FLAG_CRITICAL
    jne  criticalBad
    cmp  ebx, CRITICAL_CIV_MIN
    jb   criticalBad
    cmp  ebx, CRITICAL_CIV_MAX
    ja   criticalBad
    cmp  edx, 15                        ; 30 SHR 1
    jb   criticalBad
    cmp  edx, 30                        ; 60 SHR 1
    ja   criticalBad
    movzx eax, (FloorInfo PTR [esi]).ttlStart
    cmp  eax, edx
    jne  criticalBad
    jmp  floorNext
criticalBad:
    inc  bldBadCritical
    jmp  floorNext

checkEnergy:
    or   bldSeenMask, 0100b
    cmp  eax, FLAG_ENERGY
    jne  energyBad
    or   ebx, edx                       ; civilians and TTL must both be 0
    jnz  energyBad
    jmp  floorNext
energyBad:
    inc  bldBadEnergy

floorNext:
    dec  ecx
    jnz  floorLoop

    mAssertEq bldSeenMask, 1111b, "normal critical energy and empty floors all generated"
    mAssertEq bldBadNormal, 0, "normal floors: 1-4 civilians and TTL 30-60"
    mAssertEq bldBadCritical, 0, "critical floors: 1-2 civilians and TTL halved"
    mAssertEq bldBadEnergy, 0, "energy floors: flag set and no civilians"
    mAssertEq bldBadEmpty, 0, "empty floors hold nothing"
    ret
TestFloorContents ENDP

;---------------------------------------------------------------------
; CountTtlOutOfRange  (private helper)
; Generates TTL_COUNT floors and counts those with a TTL (not 0)
; outside [lowTtl, highTtl].
; Receives: lowTtl, highTtl, difficulty and roundNum (globals)
; Returns:  EAX = number of floors out of range
;---------------------------------------------------------------------
CountTtlOutOfRange PROC USES ebx ecx esi, lowTtl:DWORD, highTtl:DWORD
    mov  esi, OFFSET floors
    add  esi, TEST_FLOOR * SIZEOF FloorInfo
    xor  ebx, ebx                       ; EBX = floors out of range
    mov  ecx, TTL_COUNT
countLoop:
    INVOKE GenerateFloor, TEST_FLOOR
    movzx eax, (FloorInfo PTR [esi]).ttlLeft
    test eax, eax
    jz   countNext                      ; energy or empty floor: no TTL
    cmp  eax, lowTtl
    jb   countBad
    cmp  eax, highTtl
    jbe  countNext
countBad:
    inc  ebx
countNext:
    dec  ecx
    jnz  countLoop
    mov  eax, ebx
    ret
CountTtlOutOfRange ENDP

;---------------------------------------------------------------------
; TestTtlRules
; Difficulty ranges, the per-round penalty and the MIN_TTL floor.
;---------------------------------------------------------------------
TestTtlRules PROC USES eax
    ; Easy, round 1: normal 45..75, critical 22..37 -> 22..75
    mov  difficulty, DIFF_EASY
    mov  roundNum, 1
    INVOKE CountTtlOutOfRange, 22, 75
    mAssertEq eax, 0, "Easy round 1: every TTL is 22-75"

    ; Normal, round 2: normal 25..55, critical 10..25 -> MIN_TTL..55
    mov  difficulty, DIFF_NORMAL
    mov  roundNum, 2
    INVOKE CountTtlOutOfRange, MIN_TTL, 55
    mAssertEq eax, 0, "Normal round 2: TTL shrinks by 5 and stays at least MIN_TTL"

    ; Hard, round 3: penalty 10 -> normal 10..30, critical clamped to 10
    mov  difficulty, DIFF_HARD
    mov  roundNum, MAX_ROUNDS
    INVOKE CountTtlOutOfRange, MIN_TTL, 40 - ROUND_TTL_STEP * (MAX_ROUNDS - 1)
    mAssertEq eax, 0, "Hard round 3: TTL never below MIN_TTL and never above 30"

    mov  difficulty, DIFF_NORMAL        ; leave the globals as found
    mov  roundNum, 1
    ret
TestTtlRules ENDP

;---------------------------------------------------------------------
; TestLobbyEmpty
; The lobby is cleared even if it held something before.
;---------------------------------------------------------------------
TestLobbyEmpty PROC USES eax ebx ecx
    mov  difficulty, DIFF_NORMAL
    mov  roundNum, 1
    xor  ebx, ebx                       ; EBX = times the lobby was not empty
    mov  ecx, 200
lobbyLoop:
    mov  floors[LOBBY * SIZEOF FloorInfo].civilians, 5   ; dirty it first
    mov  floors[LOBBY * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS OR FLAG_SCANNED
    INVOKE GenerateFloor, LOBBY
    movzx eax, floors[LOBBY * SIZEOF FloorInfo].civilians
    or   al, floors[LOBBY * SIZEOF FloorInfo].floorFlags
    jz   lobbyNext
    inc  ebx
lobbyNext:
    dec  ecx
    jnz  lobbyLoop
    mAssertEq ebx, 0, "lobby is always empty with no flags"
    ret
TestLobbyEmpty ENDP

;---------------------------------------------------------------------
; TestInitializeGame
; New building, per-round reset, and the energy refill of rounds 2-3.
;---------------------------------------------------------------------
TestInitializeGame PROC USES eax ebx ecx esi
    mov  difficulty, DIFF_NORMAL
    mov  roundNum, 1

    ; --- dirty every floor and the round state first ---
    mov  esi, OFFSET floors
    mov  ecx, NUM_FLOORS
dirtyLoop:
    mov  (FloorInfo PTR [esi]).floorFlags, FLAG_SCANNED OR FLAG_EXPIRED
    mov  (FloorInfo PTR [esi]).civilians, 9
    add  esi, SIZEOF FloorInfo
    dec  ecx
    jnz  dirtyLoop
    mov  elevatorFloor, 7
    mov  rescuedNormal, 5
    mov  rescuedCritical, 2
    mov  casualties, 3
    mov  roundScore, 900
    mov  passengersNormal, 2
    mov  passengersCritical, 1
    mov  roundOver, 1
    mov  energy, 100

    call InitializeGame

    ; --- count floors that still look dirty ---
    mov  esi, OFFSET floors
    xor  ebx, ebx                       ; EBX = leftovers
    mov  ecx, NUM_FLOORS
checkLoop:
    movzx eax, (FloorInfo PTR [esi]).floorFlags
    test al, FLAG_SCANNED OR FLAG_EXPIRED
    jnz  leftover
    movzx eax, (FloorInfo PTR [esi]).civilians
    cmp  eax, NORMAL_CIV_MAX
    jbe  checkNext
leftover:
    inc  ebx
checkNext:
    add  esi, SIZEOF FloorInfo
    dec  ecx
    jnz  checkLoop
    mAssertEq ebx, 0, "every floor is rebuilt and starts unscanned"

    movzx eax, floors[LOBBY * SIZEOF FloorInfo].civilians
    mAssertEq eax, 0, "lobby has no civilians after InitializeGame"
    mAssertEq elevatorFloor, LOBBY, "elevator is back at the lobby"
    mAssertEq rescuedNormal, 0, "rescuedNormal reset"
    mAssertEq rescuedCritical, 0, "rescuedCritical reset"
    mAssertEq casualties, 0, "casualties reset"
    mAssertEq roundScore, 0, "roundScore reset"
    mAssertEq passengersNormal, 0, "no normal passengers on board"
    mAssertEq passengersCritical, 0, "no critical passengers on board"
    movzx eax, roundOver
    mAssertEq eax, 0, "roundOver cleared"
    mAssertEq energy, 100, "round 1 keeps the starting energy"

    ; --- energy refill in later rounds ---
    mov  roundNum, 2
    mov  energy, 100
    call InitializeGame
    mAssertEq energy, 100 + ROUND_ENERGY_REFILL, "round 2 adds the energy refill"

    mov  roundNum, 3
    call InitializeGame                 ; energy was 140, refill would reach 180
    mAssertEq energy, MAX_ENERGY, "round 3 energy is capped at MAX_ENERGY"

    mov  roundNum, 1                    ; leave the globals as found
    mov  difficulty, DIFF_NORMAL
    ret
TestInitializeGame ENDP

;---------------------------------------------------------------------
; TestBuilding  -  runs every Building suite
;---------------------------------------------------------------------
TestBuilding PROC
    mSuite "Building"
    call TestRollFloorType
    call TestFloorContents
    call TestTtlRules
    call TestLobbyEmpty
    call TestInitializeGame
    ret
TestBuilding ENDP

END
