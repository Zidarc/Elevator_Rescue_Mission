; Render.asm - draws everything: the intro, the building, the elevator,
; the stats panel, the message line and the shop screen.
; Gotoxy moves the cursor to a row and column and we draw over the old
; picture, instead of clearing the screen every time, so it does not flicker.
INCLUDE Irvine32.inc
INCLUDE Elevator.inc

ROW_TITLE       = 0
ROW_RULE_TOP    = 1
ROW_TOP_FLOOR   = 2
ROW_RULE_BOTTOM = ROW_TOP_FLOOR + NUM_FLOORS
ROW_KEYS        = ROW_RULE_BOTTOM + 1
ROW_STATUS      = ROW_KEYS + 1
ROW_PROMPT      = ROW_STATUS + 2

COL_LEFT        = 1
COL_ROUND       = 36
COL_LEVEL       = 52
COL_HUD         = 34

COUNT_WIDTH     = 5
TTL_WIDTH       = 6
HUD_WIDTH       = 8
RULE_WIDTH      = 72
STATUS_FIELD    = STATUS_SIZE + 4
LOW_ENERGY      = 20
CURSOR_SIZE     = 25

COLOR_TEXT      = lightGray + (black * 16)
COLOR_TITLE     = white + (black * 16)
COLOR_CAR       = yellow + (black * 16)
COLOR_NORMAL    = white + (black * 16)
COLOR_CRITICAL  = lightMagenta + (black * 16)
COLOR_ENERGY    = lightCyan + (black * 16)
COLOR_EXPIRED   = lightRed + (black * 16)
COLOR_UNKNOWN   = gray + (black * 16)
COLOR_STATUS    = lightCyan + (black * 16)
COLOR_TTL_OK    = lightGreen + (black * 16)
COLOR_TTL_LOW   = yellow + (black * 16)
COLOR_TTL_CRIT  = lightRed + (black * 16)

.data
cursorInfo      CONSOLE_CURSOR_INFO <CURSOR_SIZE, 1>
numText         BYTE NUM_BUF_SIZE DUP(0)
ruleLine        BYTE RULE_WIDTH + 1 DUP(0)

txtGameName     BYTE "ELEVATOR RESCUE SIMULATOR", 0
txtRound        BYTE "Round ", 0
txtSlash        BYTE "/", 0
txtLevel        BYTE "Difficulty: ", 0
txtKeys         BYTE "W up   S down   A action   X scan   B shop   Q quit", 0
txtPrompt       BYTE "> ", 0

txtShaftLeft    BYTE " |", 0
txtCar          BYTE " [===] ", 0
txtNoCar        BYTE "       ", 0
txtShaftRight   BYTE "| ", 0
txtBar          BYTE "|", 0
txtLobby        BYTE "LOBBY   [B] SHOP  ", 0
txtUnknown      BYTE "?  ?    ", 0
txtExpired      BYTE "x       ", 0
txtEnergy       BYTE "+       ", 0
txtBlank        BYTE "        ", 0
txtTwoSpaces    BYTE "  ", 0
txtTtl          BYTE "TTL ", 0
txtNoTtl        BYTE "---       ", 0

hudEnergy       BYTE "Energy      ", 0
hudCredits      BYTE "Credits     ", 0
hudCapacity     BYTE "Capacity    ", 0
hudPassengers   BYTE "Passengers  N:", 0
hudCritical     BYTE "  !:", 0
hudRoundScore   BYTE "Round score ", 0
hudTotalScore   BYTE "Total score ", 0
hudRescued      BYTE "Rescued ", 0
hudLost         BYTE "  Lost ", 0

txtRoundOver    BYTE "ROUND OVER  -  round score ", 0
txtTotalNow     BYTE "   total ", 0

shopTitle       BYTE "  =========================================", 0Dh, 0Ah
                BYTE "                 LOBBY SHOP", 0Dh, 0Ah
                BYTE "  =========================================", 0Dh, 0Ah, 0Dh, 0Ah, 0
shopCredits     BYTE "    Credits: ", 0
shopItem1       BYTE "    1. Capacity upgrade   30 credits   +2 capacity    (now ", 0
shopItem2       BYTE "    2. Energy refill      20 credits   +40 energy     (now ", 0
shopItem3       BYTE "    3. Time freeze        50 credits   +10 s on every waiting floor", 0Dh, 0Ah, 0Dh, 0Ah, 0
shopClose       BYTE ")", 0Dh, 0Ah, 0
shopLeave       BYTE "    B. Back to the elevator   (timers are paused while you shop)", 0Dh, 0Ah, 0Dh, 0Ah, 0
shopPrompt      BYTE "  > ", 0

introArt        BYTE 0Dh, 0Ah, 0Dh, 0Ah
                BYTE "     ################################################", 0Dh, 0Ah
                BYTE "     #                                              #", 0Dh, 0Ah
                BYTE "     #       E L E V A T O R    R E S C U E         #", 0Dh, 0Ah
                BYTE "     #              S I M U L A T O R               #", 0Dh, 0Ah
                BYTE "     #                                              #", 0Dh, 0Ah
                BYTE "     ################################################", 0Dh, 0Ah, 0Dh, 0Ah, 0
introText       BYTE "       Civilians are trapped on floors 1-9 and every", 0Dh, 0Ah
                BYTE "       floor's timer is running. Bring them down to", 0Dh, 0Ah
                BYTE "       the lobby before time runs out.", 0Dh, 0Ah, 0Dh, 0Ah
                BYTE "       x86 MASM + Irvine32   -   COAL Lab Project", 0Dh, 0Ah
                BYTE "       FAST-NUCES Karachi", 0Dh, 0Ah
                BYTE "       Ali Hussain  -  Ali  -  M. Abbas", 0Dh, 0Ah, 0Dh, 0Ah, 0Dh, 0Ah, 0
introPress      BYTE "             Press any key to start...", 0

.code
; Prints the string at ESI, then spaces until ECX characters are filled.
; The spaces wipe out longer old text that was there before.
PaintPadded PROC USES eax ecx edx
    INVOKE StrLen, esi
    mov  edx, esi
    call WriteString
    sub  ecx, eax
    jbe  paddedDone
    mov  al, ' '
padLoop:
    call WriteChar
    loop padLoop
paddedDone:
    ret
PaintPadded ENDP

; Prints the number in EAX in a field ECX characters wide.
PaintNumber PROC USES eax esi
    INVOKE StrFromUInt, eax, ADDR numText
    mov  esi, OFFSET numText
    call PaintPadded
    ret
PaintNumber ENDP

; Prints the string at EDX in colour EAX, then goes back to normal grey.
PaintText PROC USES eax
    call SetTextColor
    call WriteString
    mov  eax, COLOR_TEXT
    call SetTextColor
    ret
PaintText ENDP

; Moves to row DH of the stats panel and prints the label at ESI.
HudLabel PROC USES edx
    mov  dl, COL_HUD
    call Gotoxy
    mov  edx, esi
    call WriteString
    ret
HudLabel ENDP

; Picks the timer colour by comparing time left with the starting time:
;   left x 2 > start   -> green  (more than half left)
;   left x 4 >= start  -> yellow (25% to 50% left)
;   otherwise          -> red    (less than 25% left)
; SHL 1 = x2 and SHL 2 = x4, so no division is needed. EAX = colour.
GetTtlColor PROC USES ebx, ttlNow:DWORD, ttlFull:DWORD
    mov  ebx, ttlFull
    test ebx, ebx
    jz   ttlGreen
    mov  eax, ttlNow
    shl  eax, 1                         ; left x 2
    cmp  eax, ebx
    ja   ttlGreen                       ; more than half left
    mov  eax, ttlNow
    shl  eax, 2                         ; left x 4
    cmp  eax, ebx
    jae  ttlYellow                      ; 25% to 50% left
    mov  eax, COLOR_TTL_CRIT
    ret
ttlYellow:
    mov  eax, COLOR_TTL_LOW
    ret
ttlGreen:
    mov  eax, COLOR_TTL_OK
    ret
GetTtlColor ENDP

; Shows (1) or hides (0) the blinking cursor using the Win32 function
; SetConsoleCursorInfo. It is hidden while playing.
SetCursorVisible PROC USES eax ecx edx, visible:DWORD
    mov  eax, visible
    mov  cursorInfo.bVisible, eax
    INVOKE GetStdHandle, STD_OUTPUT_HANDLE
    INVOKE SetConsoleCursorInfo, eax, ADDR cursorInfo
    ret
SetCursorVisible ENDP

; Clears the screen and hides the cursor before drawing the game.
ClearGameScreen PROC
    call Clrscr
    INVOKE SetCursorVisible, 0
    ret
ClearGameScreen ENDP

; The title screen shown once when the program starts. Waits for a key.
DrawIntro PROC USES eax edx
    call Clrscr
    INVOKE SetCursorVisible, 0
    mov  edx, OFFSET introArt
    mov  eax, yellow + (black * 16)
    call PaintText
    mov  edx, OFFSET introText
    call WriteString
    mov  edx, OFFSET introPress
    mov  eax, COLOR_STATUS
    call PaintText
    call ReadChar
    INVOKE SetCursorVisible, 1
    ret
DrawIntro ENDP

; Draws the parts that never change: the title, the two ---- lines
; and the keys line.
DrawFrame PROC USES eax edx
    INVOKE StrFill, ADDR ruleLine, RULE_WIDTH, '-'
    mov  dh, ROW_RULE_TOP
    mov  dl, COL_LEFT
    call Gotoxy
    mov  edx, OFFSET ruleLine
    call WriteString
    mov  dh, ROW_RULE_BOTTOM
    mov  dl, COL_LEFT
    call Gotoxy
    mov  edx, OFFSET ruleLine
    call WriteString
    mov  dh, ROW_KEYS
    mov  dl, COL_LEFT
    call Gotoxy
    mov  edx, OFFSET txtKeys
    call WriteString
    mov  dh, ROW_TITLE
    mov  dl, COL_LEFT
    call Gotoxy
    mov  edx, OFFSET txtGameName
    mov  eax, COLOR_TITLE
    call PaintText
    ret
DrawFrame ENDP

; Draws one floor line: floor number, the elevator [===] if it is here,
; what is on the floor and its timer.
;   ?  not scanned yet     N  normal people     !  critical people (magenta)
;   +  energy pack         x  time ran out
DrawFloor PROC USES eax ebx ecx edx esi, floorIndex:DWORD
    mov  ebx, floorIndex
    mov  eax, ROW_TOP_FLOOR + TOP_FLOOR ; floor 9 is drawn at the top, floor 0 at the bottom
    sub  eax, ebx
    mov  dh, al
    mov  dl, COL_LEFT
    call Gotoxy
    mov  eax, COLOR_TEXT
    call SetTextColor
    mov  eax, ebx
    call WriteDec
    mov  edx, OFFSET txtShaftLeft
    call WriteString

    mov  edx, OFFSET txtNoCar
    mov  eax, COLOR_TEXT
    cmp  ebx, elevatorFloor
    jne  drawShaft
    mov  edx, OFFSET txtCar
    mov  eax, COLOR_CAR
drawShaft:
    call PaintText
    mov  edx, OFFSET txtShaftRight
    call WriteString

    cmp  ebx, LOBBY
    je   drawLobby
    lea  esi, floors[ebx * SIZEOF FloorInfo] ; ESI = address of this floor
    mov  bl, (FloorInfo PTR [esi]).floorFlags ; BL = flags of this floor
    test bl, FLAG_EXPIRED
    jnz  drawExpired
    test bl, FLAG_SCANNED
    jz   drawUnknown
    test bl, FLAG_ENERGY
    jnz  drawEnergy
    test bl, FLAG_CIVILIANS
    jnz  drawPeople
    mov  edx, OFFSET txtBlank
    mov  eax, COLOR_TEXT
    jmp  drawWithoutTtl

drawLobby:
    mov  edx, OFFSET txtLobby
    mov  eax, COLOR_NORMAL
    call PaintText
    jmp  lineEnd

drawExpired:
    mov  edx, OFFSET txtExpired
    mov  eax, COLOR_EXPIRED
    jmp  drawWithoutTtl

drawEnergy:
    mov  edx, OFFSET txtEnergy
    mov  eax, COLOR_ENERGY
    jmp  drawWithoutTtl

drawUnknown:
    mov  edx, OFFSET txtUnknown
    mov  eax, COLOR_UNKNOWN
    test bl, FLAG_CIVILIANS
    jz   drawWithoutTtl
    call PaintText
    jmp  drawTtl

drawPeople:
    mov  eax, COLOR_NORMAL
    mov  cl, 'N'
    test bl, FLAG_CRITICAL
    jz   peopleColor
    mov  eax, COLOR_CRITICAL
    mov  cl, '!'
peopleColor:
    call SetTextColor
    mov  al, cl
    call WriteChar
    mov  edx, OFFSET txtTwoSpaces
    call WriteString
    movzx eax, (FloorInfo PTR [esi]).civilians
    mov  ecx, COUNT_WIDTH
    call PaintNumber

drawTtl:
    movzx eax, (FloorInfo PTR [esi]).ttlLeft
    movzx ecx, (FloorInfo PTR [esi]).ttlStart
    INVOKE GetTtlColor, eax, ecx
    call SetTextColor
    mov  edx, OFFSET txtTtl
    call WriteString
    movzx eax, (FloorInfo PTR [esi]).ttlLeft
    mov  ecx, TTL_WIDTH
    call PaintNumber
    jmp  lineEnd

drawWithoutTtl:
    call PaintText
    mov  edx, OFFSET txtNoTtl
    call WriteString

lineEnd:
    mov  eax, COLOR_TEXT
    call SetTextColor
    mov  edx, OFFSET txtBar
    call WriteString
    ret
DrawFloor ENDP

; Draws the round and difficulty at the top, the stats panel on the right
; (energy, credits, capacity, passengers, scores, rescued, lost)
; and the message line at the bottom.
DrawHud PROC USES eax ecx edx esi
    mov  dh, ROW_TITLE
    mov  dl, COL_ROUND
    call Gotoxy
    mov  edx, OFFSET txtRound
    call WriteString
    mov  eax, roundNum
    call WriteDec
    mov  edx, OFFSET txtSlash
    call WriteString
    mov  eax, MAX_ROUNDS
    call WriteDec
    mov  dh, ROW_TITLE
    mov  dl, COL_LEVEL
    call Gotoxy
    mov  edx, OFFSET txtLevel
    call WriteString
    INVOKE GetDiffName, difficulty
    mov  esi, eax
    mov  ecx, DIFF_NAME_SIZE
    call PaintPadded

    mov  dh, ROW_TOP_FLOOR
    mov  esi, OFFSET hudEnergy
    call HudLabel
    mov  eax, COLOR_NORMAL
    cmp  energy, LOW_ENERGY
    jae  energyColor
    mov  eax, COLOR_EXPIRED
energyColor:
    call SetTextColor
    mov  eax, energy
    call WriteDec
    mov  eax, COLOR_TEXT
    call SetTextColor
    mov  edx, OFFSET txtSlash
    call WriteString
    mov  eax, MAX_ENERGY
    mov  ecx, HUD_WIDTH
    call PaintNumber

    mov  dh, ROW_TOP_FLOOR + 1
    mov  esi, OFFSET hudCredits
    call HudLabel
    mov  eax, credits
    mov  ecx, HUD_WIDTH
    call PaintNumber

    mov  dh, ROW_TOP_FLOOR + 2
    mov  esi, OFFSET hudCapacity
    call HudLabel
    mov  eax, passengersNormal
    add  eax, passengersCritical
    call WriteDec
    mov  edx, OFFSET txtSlash
    call WriteString
    mov  eax, capacity
    mov  ecx, HUD_WIDTH
    call PaintNumber

    mov  dh, ROW_TOP_FLOOR + 3
    mov  esi, OFFSET hudPassengers
    call HudLabel
    mov  eax, passengersNormal
    call WriteDec
    mov  edx, OFFSET hudCritical
    call WriteString
    mov  eax, passengersCritical
    mov  ecx, HUD_WIDTH
    call PaintNumber

    mov  dh, ROW_TOP_FLOOR + 5
    mov  esi, OFFSET hudRoundScore
    call HudLabel
    mov  eax, roundScore
    mov  ecx, HUD_WIDTH
    call PaintNumber

    mov  dh, ROW_TOP_FLOOR + 6
    mov  esi, OFFSET hudTotalScore
    call HudLabel
    mov  eax, totalScore
    mov  ecx, HUD_WIDTH
    call PaintNumber

    mov  dh, ROW_TOP_FLOOR + 8
    mov  esi, OFFSET hudRescued
    call HudLabel
    mov  eax, rescuedNormal
    add  eax, rescuedCritical
    call WriteDec
    mov  edx, OFFSET hudLost
    call WriteString
    mov  eax, casualties
    mov  ecx, HUD_WIDTH
    call PaintNumber

    mov  dh, ROW_STATUS
    mov  dl, COL_LEFT
    call Gotoxy
    mov  edx, OFFSET txtPrompt
    call WriteString
    mov  eax, COLOR_STATUS
    call SetTextColor
    mov  esi, OFFSET statusMsg
    mov  ecx, STATUS_FIELD
    call PaintPadded
    mov  eax, COLOR_TEXT
    call SetTextColor
    ret
DrawHud ENDP

; Draws the whole game screen: frame, all 10 floors, then the stats panel.
DrawGameState PROC USES ecx edx
    call DrawFrame
    xor  ecx, ecx
floorLoop:
    INVOKE DrawFloor, ecx
    inc  ecx
    cmp  ecx, NUM_FLOORS
    jb   floorLoop
    call DrawHud
    mov  dh, ROW_PROMPT
    mov  dl, 0
    call Gotoxy
    ret
DrawGameState ENDP

; Shown when a round ends: the final picture plus the round score
; and total score. Waits for a key.
ShowRoundOver PROC USES eax ecx edx
    call DrawGameState
    mov  dh, ROW_PROMPT
    mov  dl, COL_LEFT
    call Gotoxy
    mov  eax, COLOR_CAR
    call SetTextColor
    mov  edx, OFFSET txtRoundOver
    call WriteString
    mov  eax, roundScore
    call WriteDec
    mov  edx, OFFSET txtTotalNow
    call WriteString
    mov  eax, totalScore
    call WriteDec
    mov  eax, COLOR_TEXT
    call SetTextColor
    call Crlf
    call Crlf
    call ReadKeyFlush                   ; ignore keys pressed during the round
    call WaitMsg
    ret
ShowRoundOver ENDP

; Draws the shop screen: credits, the 3 items with their prices and the
; current capacity and energy, and the last message.
DrawShop PROC USES eax edx
    call Clrscr
    mov  edx, OFFSET shopTitle
    mov  eax, COLOR_CAR
    call PaintText
    mov  edx, OFFSET shopCredits
    call WriteString
    mov  eax, credits
    call WriteDec
    call Crlf
    call Crlf
    mov  edx, OFFSET shopItem1
    call WriteString
    mov  eax, capacity
    call WriteDec
    mov  edx, OFFSET txtSlash
    call WriteString
    mov  eax, MAX_CAPACITY
    call WriteDec
    mov  edx, OFFSET shopClose
    call WriteString
    mov  edx, OFFSET shopItem2
    call WriteString
    mov  eax, energy
    call WriteDec
    mov  edx, OFFSET txtSlash
    call WriteString
    mov  eax, MAX_ENERGY
    call WriteDec
    mov  edx, OFFSET shopClose
    call WriteString
    mov  edx, OFFSET shopItem3
    call WriteString
    mov  edx, OFFSET shopLeave
    call WriteString
    mov  edx, OFFSET shopPrompt
    call WriteString
    mov  edx, OFFSET statusMsg
    mov  eax, COLOR_STATUS
    call PaintText
    ret
DrawShop ENDP

; Saves a message to show on the message line.
SetStatus PROC USES eax, pMsg:PTR BYTE
    INVOKE StrCopyN, ADDR statusMsg, pMsg, STATUS_SIZE
    ret
SetStatus ENDP

END
