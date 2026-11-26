.data
difficultyTable DiffSetting <45, 75, 120, 1, 10>   ; Easy
                DiffSetting <30, 60, 100, 2, 15>   ; Normal
                DiffSetting <20, 40,  80, 3, 25>   ; Hard

diffNames       BYTE "EASY", DIFF_NAME_SIZE - 4 DUP(0)
                BYTE "NORMAL", DIFF_NAME_SIZE - 6 DUP(0)
                BYTE "HARD", DIFF_NAME_SIZE - 4 DUP(0)
diffUnknown     BYTE "?", 0

; Building
floors          FloorInfo NUM_FLOORS DUP(<>)

; Player and elevator
difficulty          DWORD DIFF_NORMAL
roundNum            DWORD 1
elevatorFloor       DWORD LOBBY
energy              DWORD 0
credits             DWORD 0
capacity            DWORD START_CAPACITY
passengersNormal    DWORD 0
passengersCritical  DWORD 0

; Score and round
roundScore          DWORD 0
totalScore          DWORD 0
rescuedNormal       DWORD 0
rescuedCritical     DWORD 0
casualties          DWORD 0
totalRescued        DWORD 0
totalLost           DWORD 0
lastTickMs          DWORD 0
roundOver           BYTE 0
quitRequested       BYTE 0
statusMsg           BYTE STATUS_SIZE DUP(0)

; High scores
highScores          HighScore MAX_SCORES DUP(<>)
highScoreCount      DWORD 0

.code
GetDiffSetting PROC USES eax edx
    mov  eax, difficulty
    mov  edx, SIZEOF DiffSetting
    mul  edx                            ; EDX:EAX = index * size
    mov  esi, OFFSET difficultyTable
    add  esi, eax
    ret
GetDiffSetting ENDP

GetDiffName PROC USES ebx edx, level:DWORD
    mov  eax, OFFSET diffUnknown
    cmp  level, NUM_DIFFICULTIES
    jae  nameDone
    mov  eax, level
    mov  ebx, DIFF_NAME_SIZE
    mul  ebx                            ; EAX = level * 8
    add  eax, OFFSET diffNames
nameDone:
    ret
GetDiffName ENDP

ResetGameState PROC USES eax esi
    call GetDiffSetting
    mov  eax, (DiffSetting PTR [esi]).startEnergy
    mov  energy, eax

    xor  eax, eax
    mov  credits, eax
    mov  totalScore, eax
    mov  roundScore, eax
    mov  rescuedNormal, eax
    mov  rescuedCritical, eax
    mov  casualties, eax
    mov  totalRescued, eax
    mov  totalLost, eax
    mov  passengersNormal, eax
    mov  passengersCritical, eax
    mov  elevatorFloor, LOBBY
    mov  capacity, START_CAPACITY
    mov  roundNum, 1
    mov  roundOver, 0
    mov  quitRequested, 0
    mov  statusMsg, 0
    ret
ResetGameState ENDP
