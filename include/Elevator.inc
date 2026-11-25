;=====================================================================
; Elevator.inc
; Shared constants, structures, global variables and procedure
; prototypes for Elevator Rescue Simulator.
;
; Every .asm module includes this file AFTER Irvine32.inc:
;     INCLUDE Irvine32.inc
;     INCLUDE Elevator.inc
;
; Globals are declared with EXTERNDEF here and DEFINED in
; src/GameState.asm. EXTERNDEF works in both the defining and the
; using module, so this one file serves everybody.
;=====================================================================
IFNDEF ELEVATOR_INC
ELEVATOR_INC EQU 1

;---------------------------------------------------------------------
; Building
;---------------------------------------------------------------------
NUM_FLOORS        = 10              ; floor 0 = lobby, floors 1..9
LOBBY             = 0
TOP_FLOOR         = NUM_FLOORS - 1
MAX_ROUNDS        = 3

;---------------------------------------------------------------------
; Floor flags (bit field, one BYTE per floor)
;---------------------------------------------------------------------
FLAG_CIVILIANS    = 00000001b       ; civilians are waiting
FLAG_CRITICAL     = 00000010b       ; civilians are critical (bonus, short TTL)
FLAG_ENERGY       = 00000100b       ; energy pack on this floor
FLAG_EXPIRED      = 00001000b       ; TTL ran out, civilians lost
FLAG_SCANNED      = 00010000b       ; contents revealed (scanned or visited)

;---------------------------------------------------------------------
; Floor types returned by RollFloorType
;---------------------------------------------------------------------
FT_EMPTY          = 0
FT_NORMAL         = 1
FT_CRITICAL       = 2
FT_ENERGY         = 3

ENERGY_FLOOR_PCT  = 20              ; % chance a floor holds an energy pack
EMPTY_FLOOR_PCT   = 15              ; % chance a floor is empty
                                    ; critical % comes from the difficulty table,
                                    ; the rest are normal floors
NORMAL_CIV_MIN    = 1
NORMAL_CIV_MAX    = 4
CRITICAL_CIV_MIN  = 1
CRITICAL_CIV_MAX  = 2
ROUND_TTL_STEP    = 5               ; TTL shrinks by 5 s per extra round
MIN_TTL           = 10

;---------------------------------------------------------------------
; Elevator, energy and shop
;---------------------------------------------------------------------
MOVE_COST         = 2               ; energy per floor moved
SCAN_COST         = 5               ; energy per scan
ENERGY_PACK       = 25              ; energy gained from a pack
MAX_ENERGY        = 150
ROUND_ENERGY_REFILL = 40            ; energy added at the start of rounds 2 and 3
START_CAPACITY    = 4
MAX_CAPACITY      = 10

SHOP_CAPACITY_COST  = 30            ; +2 capacity
SHOP_CAPACITY_GAIN  = 2
SHOP_ENERGY_COST    = 20            ; +40 energy
SHOP_ENERGY_GAIN    = 40
SHOP_FREEZE_COST    = 50            ; +10 s TTL on every waiting floor
SHOP_FREEZE_GAIN    = 10

;---------------------------------------------------------------------
; Scoring
;---------------------------------------------------------------------
NORMAL_POINTS     = 100             ; per normal civilian delivered to lobby
CRITICAL_POINTS   = 300             ; per critical civilian delivered
CASUALTY_PENALTY  = 50              ; per civilian lost
ENERGY_BONUS      = 2               ; per energy point left at round end
NORMAL_CREDITS    = 10
CRITICAL_CREDITS  = 25

;---------------------------------------------------------------------
; Timing and difficulty
;---------------------------------------------------------------------
TICK_MS           = 1000            ; one TTL tick per second
FRAME_DELAY_MS    = 30              ; input polling delay in the game loop

DIFF_EASY         = 0
DIFF_NORMAL       = 1
DIFF_HARD         = 2
NUM_DIFFICULTIES  = 3
DIFF_NAME_SIZE    = 8
NUM_BUF_SIZE      = 12

;---------------------------------------------------------------------
; Scoreboard
;---------------------------------------------------------------------
NAME_SIZE         = 16              ; 15 characters + null terminator
MAX_SCORES        = 10
STATUS_SIZE       = 64

;---------------------------------------------------------------------
; Structures
; Field names are unique across all structures on purpose.
;---------------------------------------------------------------------
FloorInfo STRUCT
    civilians   BYTE 0              ; people waiting on this floor
    floorFlags  BYTE 0              ; FLAG_* bits
    ttlLeft     WORD 0              ; seconds left before they are lost
    ttlStart    WORD 0              ; starting TTL (for the colour thresholds)
    floorPad    WORD 0              ; keeps the structure 8 bytes
FloorInfo ENDS

DiffSetting STRUCT
    ttlMin       DWORD ?            ; normal floor TTL range (seconds)
    ttlMax       DWORD ?
    startEnergy  DWORD ?
    multiplier   DWORD ?            ; final score multiplier
    criticalPct  DWORD ?            ; % chance a floor is critical
DiffSetting ENDS

HighScore STRUCT
    playerName  BYTE NAME_SIZE DUP(0)
    points      DWORD 0
    level       BYTE 0              ; DIFF_EASY / DIFF_NORMAL / DIFF_HARD
    roundsDone  BYTE 0
    scorePad    WORD 0              ; keeps the structure 24 bytes
HighScore ENDS

;---------------------------------------------------------------------
; Global game state (defined in src/GameState.asm)
;---------------------------------------------------------------------
EXTERNDEF floors:FloorInfo
EXTERNDEF difficultyTable:DiffSetting
EXTERNDEF highScores:HighScore

EXTERNDEF difficulty:DWORD          ; DIFF_*
EXTERNDEF roundNum:DWORD            ; 1..MAX_ROUNDS
EXTERNDEF elevatorFloor:DWORD       ; 0..TOP_FLOOR
EXTERNDEF energy:DWORD
EXTERNDEF credits:DWORD
EXTERNDEF capacity:DWORD
EXTERNDEF passengersNormal:DWORD    ; on board, normal
EXTERNDEF passengersCritical:DWORD  ; on board, critical
EXTERNDEF roundScore:DWORD
EXTERNDEF totalScore:DWORD
EXTERNDEF rescuedNormal:DWORD       ; delivered this round
EXTERNDEF rescuedCritical:DWORD
EXTERNDEF casualties:DWORD          ; lost this round
EXTERNDEF lastTickMs:DWORD          ; GetMseconds value of the last TTL tick
EXTERNDEF roundOver:BYTE            ; 1 when the current round has ended
EXTERNDEF quitRequested:BYTE        ; 1 when the player pressed Q
EXTERNDEF highScoreCount:DWORD
EXTERNDEF statusMsg:BYTE            ; message line shown under the HUD

;---------------------------------------------------------------------
; Procedure prototypes
; The day in brackets is when the procedure is implemented
; (see README, section 15). Do not CALL a procedure before its day.
;---------------------------------------------------------------------

; --- GameState.asm [Day 1] ---
ResetGameState      PROTO                           ; new game: score, credits, round 1, energy from difficulty
GetDiffSetting      PROTO                           ; returns ESI = OFFSET of current DiffSetting
GetDiffName         PROTO, level:DWORD

; --- StrUtil.asm [Day 1] ---  (string primitives)
StrLen              PROTO, pStr:PTR BYTE            ; EAX = length
StrCopyN            PROTO, pDest:PTR BYTE, pSrc:PTR BYTE, maxLen:DWORD  ; EAX = chars copied
StrEqual            PROTO, pStr1:PTR BYTE, pStr2:PTR BYTE              ; EAX = 1 / 0
StrFill             PROTO, pDest:PTR BYTE, count:DWORD, fillChar:DWORD ; count chars + null
StrToUpper          PROTO, pStr:PTR BYTE            ; in place, a-z only
StrPadRight         PROTO, pStr:PTR BYTE, fieldWidth:DWORD  ; pad with spaces to fieldWidth
StrFromUInt         PROTO, value:DWORD, pDest:PTR BYTE

; --- Menu.asm [Day 1, wired up on later days] ---
RunMainMenu         PROTO
ShowHowToPlay       PROTO

; --- Building.asm [Day 2] ---
SelectDifficulty    PROTO                           ; asks the player, sets difficulty
RollFloorType       PROTO                           ; EAX = FT_*
GenerateFloor       PROTO, floorIndex:DWORD
InitializeGame      PROTO                           ; builds a new building for roundNum

; --- Elevator.asm [Day 3] ---
MoveElevator        PROTO, direction:SDWORD         ; +1 up, -1 down
PerformAction       PROTO                           ; pick up / drop off / collect energy
TickFloors          PROTO                           ; one second passes on every floor

; --- Scan.asm and GameLoop.asm [Day 4] ---
ScanAction          PROTO
ScanFloorsRecursive PROTO                           ; stack params, see Scan.asm
RunGame             PROTO                           ; difficulty -> rounds -> summary
RunRound            PROTO
HandleCommand       PROTO, key:DWORD
CheckRoundOver      PROTO                           ; sets roundOver

; --- Render.asm [Day 5] ---
DrawIntro           PROTO
DrawGameState       PROTO
DrawFloor           PROTO, floorIndex:DWORD
DrawHud             PROTO
SetStatus           PROTO, pMsg:PTR BYTE

; --- Shop.asm and Score.asm [Day 6] ---
BuyInLobby          PROTO
CalcRoundScore      PROTO                           ; EAX = score for this round
ShowSummary         PROTO

; --- Scoreboard.asm [Day 7] ---
LoadScores          PROTO
SaveScores          PROTO
InsertScoreSorted   PROTO, pName:PTR BYTE, scoreValue:DWORD, levelValue:DWORD, roundsValue:DWORD ; EAX = rank (1-based) or 0
RecordScore         PROTO                           ; asks for a name if the score qualifies
ShowScores          PROTO

ENDIF ; ELEVATOR_INC
