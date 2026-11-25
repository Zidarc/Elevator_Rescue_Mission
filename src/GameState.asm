; GameState.asm - every global variable of the game lives here
; (building, elevator, energy, score, high scores, difficulty table).
; Other files reach these variables through EXTERNDEF in Elevator.inc.
INCLUDE Irvine32.inc
INCLUDE Elevator.inc

.data
; Difficulty table: one DiffSetting per level, indexed by difficulty
;                 ttlMin ttlMax energy  mult  critical%
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

; High scores (sorted, highest first)
highScores          HighScore MAX_SCORES DUP(<>)
highScoreCount      DWORD 0

.code
; Gives the address of the current difficulty's settings in ESI.
; address = start of difficultyTable + difficulty * size of one entry (MUL)
GetDiffSetting PROC USES eax edx
    mov  eax, difficulty
    mov  edx, SIZEOF DiffSetting
    mul  edx                            ; EDX:EAX = index * size
    mov  esi, OFFSET difficultyTable
    add  esi, eax
    ret
GetDiffSetting ENDP

; Gives the text "EASY", "NORMAL" or "HARD" for a level in EAX.
; Every name takes 8 bytes, so address = diffNames + level * 8.
; A wrong level gives "?".
GetDiffName PROC, level:DWORD
    mov  eax, OFFSET diffUnknown
    cmp  level, NUM_DIFFICULTIES
    jae  nameDone
    mov  eax, level
    imul eax, eax, DIFF_NAME_SIZE
    add  eax, OFFSET diffNames
nameDone:
    ret
GetDiffName ENDP

; Starts a fresh game: energy from the difficulty, score, credits and
; passengers to 0, round 1, elevator in the lobby.
; Difficulty and high scores are kept.
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
    mov  statusMsg, 0                   ; empty message
    ret
ResetGameState ENDP

END
