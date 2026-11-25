; Menu.asm - the main menu and the How to Play page.
INCLUDE Irvine32.inc
INCLUDE Elevator.inc

.data
menuTitle   BYTE "  =========================================", 0Dh, 0Ah
            BYTE "        ELEVATOR RESCUE SIMULATOR", 0Dh, 0Ah
            BYTE "  =========================================", 0Dh, 0Ah, 0Dh, 0Ah, 0
menuOptions BYTE "    1. New Game", 0Dh, 0Ah
            BYTE "    2. High Scores", 0Dh, 0Ah
            BYTE "    3. How to Play", 0Dh, 0Ah
            BYTE "    4. Quit", 0Dh, 0Ah, 0Dh, 0Ah
            BYTE "  Select an option: ", 0

howToPlay   BYTE "  HOW TO PLAY", 0Dh, 0Ah
            BYTE "  -----------", 0Dh, 0Ah
            BYTE "  A building is in trouble. Civilians are trapped on floors 1-9", 0Dh, 0Ah
            BYTE "  and every floor has a timer (TTL). Bring them down to the", 0Dh, 0Ah
            BYTE "  lobby (floor 0) before their timer reaches zero.", 0Dh, 0Ah, 0Dh, 0Ah
            BYTE "  CONTROLS", 0Dh, 0Ah
            BYTE "    W  Move up one floor           (costs energy)", 0Dh, 0Ah
            BYTE "    S  Move down one floor         (costs energy)", 0Dh, 0Ah
            BYTE "    A  Action: pick up civilians, collect an energy pack,", 0Dh, 0Ah
            BYTE "       or drop passengers off at the lobby", 0Dh, 0Ah
            BYTE "    X  Scan the building for waiting civilians (costs energy)", 0Dh, 0Ah
            BYTE "    B  Shop (lobby only): capacity, energy, time freeze.", 0Dh, 0Ah
            BYTE "       Timers are paused while the shop is open.", 0Dh, 0Ah
            BYTE "    Q  Quit: the game ends and your score is still recorded", 0Dh, 0Ah, 0Dh, 0Ah
            BYTE "  FLOORS", 0Dh, 0Ah
            BYTE "    Normal    1-4 civilians, 100 points each", 0Dh, 0Ah
            BYTE "    Critical  1-2 civilians, short timer, 300 points each", 0Dh, 0Ah
            BYTE "    Energy    an energy pack worth +25 energy", 0Dh, 0Ah, 0Dh, 0Ah
            BYTE "  Each lost civilian costs 50 points. Leftover energy is worth 2", 0Dh, 0Ah
            BYTE "  points each. Easy x1, Normal x2, Hard x3 score multiplier.", 0Dh, 0Ah
            BYTE "  Delivered civilians earn credits: 10 normal, 25 critical.", 0Dh, 0Ah
            BYTE "  A game has 3 rounds, each with shorter timers.", 0Dh, 0Ah, 0Dh, 0Ah, 0

.code
; Shows the intro screen, then the main menu:
; 1 New Game, 2 High Scores, 3 How to Play, 4 Quit.
; Keeps showing the menu until the player picks Quit.
RunMainMenu PROC USES eax edx
    INVOKE DrawIntro
menuLoop:
    call Clrscr
    mov  edx, OFFSET menuTitle
    call WriteString
    mov  edx, OFFSET menuOptions
    call WriteString
    call ReadChar                       ; AL = key, no echo

    cmp  al, '1'
    je   optNewGame
    cmp  al, '2'
    je   optScores
    cmp  al, '3'
    je   optHelp
    cmp  al, '4'
    je   optQuit
    cmp  al, 'q'
    je   optQuit
    cmp  al, 'Q'
    je   optQuit
    jmp  menuLoop                       ; ignore any other key

optNewGame:
    INVOKE RunGame
    jmp  menuLoop

optScores:
    INVOKE ShowScores
    jmp  menuLoop

optHelp:
    INVOKE ShowHowToPlay
    jmp  menuLoop

optQuit:
    call Clrscr
    ret
RunMainMenu ENDP

; Prints the game rules and controls, waits for a key.
ShowHowToPlay PROC USES edx
    call Clrscr
    mov  edx, OFFSET howToPlay
    call WriteString
    call WaitMsg
    ret
ShowHowToPlay ENDP

END
