PERCENT_RANGE = 100

.data
diffMenu    BYTE "  =========================================", 0Dh, 0Ah
            BYTE "              SELECT DIFFICULTY", 0Dh, 0Ah
            BYTE "  =========================================", 0Dh, 0Ah, 0Dh, 0Ah
            BYTE "    1. Easy    (long timers,  120 energy, x1)", 0Dh, 0Ah
            BYTE "    2. Normal  (medium timers, 100 energy, x2)", 0Dh, 0Ah
            BYTE "    3. Hard    (short timers,   80 energy, x3)", 0Dh, 0Ah, 0Dh, 0Ah
            BYTE "  Select a level: ", 0

.code
SelectDifficulty PROC USES eax edx
selectLoop:
    call Clrscr
    mov  edx, OFFSET diffMenu
    call WriteString
    call ReadChar                       ; AL = key, no echo

    cmp  al, '1'
    je   pickEasy
    cmp  al, '2'
    je   pickNormal
    cmp  al, '3'
    je   pickHard
    jmp  selectLoop                     ; ignore any other key

pickEasy:
    mov  difficulty, DIFF_EASY
    jmp  selectDone
pickNormal:
    mov  difficulty, DIFF_NORMAL
    jmp  selectDone
pickHard:
    mov  difficulty, DIFF_HARD
selectDone:
    ret
SelectDifficulty ENDP

RollFloorType PROC USES ebx esi
    call GetDiffSetting                 ; ESI = current DiffSetting
    mov  ebx, (DiffSetting PTR [esi]).criticalPct   ; EBX = running limit
    mov  eax, PERCENT_RANGE
    call RandomRange                    ; EAX = 0..99

    cmp  eax, ebx
    jb   rolledCritical
    add  ebx, ENERGY_FLOOR_PCT
    cmp  eax, ebx
    jb   rolledEnergy
    add  ebx, EMPTY_FLOOR_PCT
    cmp  eax, ebx
    jb   rolledEmpty

    mov  eax, FT_NORMAL
    jmp  rollDone
rolledCritical:
    mov  eax, FT_CRITICAL
    jmp  rollDone
rolledEnergy:
    mov  eax, FT_ENERGY
    jmp  rollDone
rolledEmpty:
    mov  eax, FT_EMPTY
rollDone:
    ret
RollFloorType ENDP

RandomBaseTtl PROC USES esi
    call GetDiffSetting                 ; ESI = current DiffSetting
    mov  eax, (DiffSetting PTR [esi]).ttlMax
    sub  eax, (DiffSetting PTR [esi]).ttlMin
    inc  eax                            ; number of possible values
    call RandomRange                    ; 0 .. ttlMax - ttlMin
    add  eax, (DiffSetting PTR [esi]).ttlMin
    ret
RandomBaseTtl ENDP

ApplyRoundPenalty PROC USES ebx ecx edx
    mov  ebx, eax                       ; EBX = TTL
    mov  eax, roundNum
    dec  eax                            ; rounds already played
    mov  ecx, ROUND_TTL_STEP
    mul  ecx                            ; EAX = penalty in seconds
    cmp  ebx, eax
    jbe  useMinimum
    sub  ebx, eax
    cmp  ebx, MIN_TTL
    jae  penaltyDone
useMinimum:
    mov  ebx, MIN_TTL
penaltyDone:
    mov  eax, ebx
    ret
ApplyRoundPenalty ENDP

GenerateFloor PROC USES eax ebx ecx edx esi edi, floorIndex:DWORD
    mov  eax, floorIndex
    mov  ecx, SIZEOF FloorInfo
    mul  ecx                            ; EAX = index * size
    mov  edi, OFFSET floors
    add  edi, eax                       ; EDI = &floors[floorIndex]

    mov  (FloorInfo PTR [edi]).civilians, 0
    mov  (FloorInfo PTR [edi]).floorFlags, 0
    mov  (FloorInfo PTR [edi]).ttlLeft, 0
    mov  (FloorInfo PTR [edi]).ttlStart, 0

    cmp  floorIndex, LOBBY
    je   generateDone

    call RollFloorType
    cmp  eax, FT_NORMAL
    je   normalFloor
    cmp  eax, FT_CRITICAL
    je   criticalFloor
    cmp  eax, FT_ENERGY
    je   energyFloor
    jmp  generateDone                   ; FT_EMPTY

normalFloor:
    mov  eax, NORMAL_CIV_MAX - NORMAL_CIV_MIN + 1
    call RandomRange
    add  eax, NORMAL_CIV_MIN
    mov  (FloorInfo PTR [edi]).civilians, al
    mov  (FloorInfo PTR [edi]).floorFlags, FLAG_CIVILIANS
    call RandomBaseTtl
    jmp  storeTtl

criticalFloor:
    mov  eax, CRITICAL_CIV_MAX - CRITICAL_CIV_MIN + 1
    call RandomRange
    add  eax, CRITICAL_CIV_MIN
    mov  (FloorInfo PTR [edi]).civilians, al
    mov  (FloorInfo PTR [edi]).floorFlags, FLAG_CIVILIANS OR FLAG_CRITICAL
    call RandomBaseTtl
    shr  eax, 1                         ; half TTL
    jmp  storeTtl

energyFloor:
    mov  (FloorInfo PTR [edi]).floorFlags, FLAG_ENERGY
    jmp  generateDone

storeTtl:
    call ApplyRoundPenalty
    mov  (FloorInfo PTR [edi]).ttlLeft, ax
    mov  (FloorInfo PTR [edi]).ttlStart, ax

generateDone:
    ret
GenerateFloor ENDP

InitializeGame PROC USES eax ecx
    xor  ecx, ecx                       ; ECX = floor index
buildLoop:
    cmp  ecx, NUM_FLOORS
    jae  buildDone
    INVOKE GenerateFloor, ecx
    inc  ecx
    jmp  buildLoop
buildDone:
    mov  elevatorFloor, LOBBY

    xor  eax, eax
    mov  roundScore, eax
    mov  rescuedNormal, eax
    mov  rescuedCritical, eax
    mov  casualties, eax
    mov  passengersNormal, eax
    mov  passengersCritical, eax
    mov  roundOver, 0
    mov  statusMsg, 0

    cmp  roundNum, 1
    jbe  initDone
    mov  eax, energy
    add  eax, ROUND_ENERGY_REFILL
    cmp  eax, MAX_ENERGY
    jbe  storeEnergy
    mov  eax, MAX_ENERGY                ; cap
storeEnergy:
    mov  energy, eax
initDone:
    ret
InitializeGame ENDP
