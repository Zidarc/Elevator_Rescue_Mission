; Constants.inc - every fixed number of the game (floors, costs, points)
; and the structures (STRUCT) used for floors, difficulty levels and scores.
; main.asm includes this file first, so every part of the game can use it.

; Building
NUM_FLOORS        = 10              ; floor 0 = lobby, floors 1..9
LOBBY             = 0
TOP_FLOOR         = NUM_FLOORS - 1
MAX_ROUNDS        = 3

; Floor flags: every floor has one BYTE where each bit means something.
; Checked with TEST, set with OR, cleared with AND NOT.
FLAG_CIVILIANS    = 00000001b       ; civilians are waiting
FLAG_CRITICAL     = 00000010b       ; civilians are critical (bonus, short TTL)
FLAG_ENERGY       = 00000100b       ; energy pack on this floor
FLAG_EXPIRED      = 00001000b       ; TTL ran out, civilians lost
FLAG_SCANNED      = 00010000b       ; contents revealed (scanned or visited)

; Floor types returned by RollFloorType
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

; Elevator, energy and shop
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
SHOP_ITEM_CAPACITY  = 1
SHOP_ITEM_ENERGY    = 2
SHOP_ITEM_FREEZE    = 3

; Scoring
NORMAL_POINTS     = 100             ; per normal civilian delivered to lobby
CRITICAL_POINTS   = 300             ; per critical civilian delivered
CASUALTY_PENALTY  = 50              ; per civilian lost
ENERGY_BONUS      = 2               ; per energy point left at round end
NORMAL_CREDITS    = 10
CRITICAL_CREDITS  = 25

; Timing and difficulty
TICK_MS           = 1000            ; one TTL tick per second
FRAME_DELAY_MS    = 30              ; input polling delay in the game loop

DIFF_EASY         = 0
DIFF_NORMAL       = 1
DIFF_HARD         = 2
NUM_DIFFICULTIES  = 3
DIFF_NAME_SIZE    = 8
NUM_BUF_SIZE      = 12

; Scoreboard
NAME_SIZE         = 16              ; 15 characters + null terminator
MAX_SCORES        = 10
STATUS_SIZE       = 64

; Structures (like a struct in C). Field names are all different on purpose.
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
