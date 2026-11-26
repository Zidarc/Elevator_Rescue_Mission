INCLUDE Irvine32.inc
INCLUDE Constants.inc       ; fixed numbers and STRUCTs

INCLUDE GameState.asm       ; all game variables
INCLUDE StrUtil.asm         ; string functions
INCLUDE Render.asm          ; drawing the screen
INCLUDE Building.asm        ; random building each round
INCLUDE Elevator.asm        ; move, pick up, drop off, timers
INCLUDE Scan.asm            ; X key: recursive scan
INCLUDE Shop.asm            ; B key: lobby shop
INCLUDE GameLoop.asm        ; real-time loop and rounds
INCLUDE Score.asm           ; round score and game-over screen
INCLUDE Scoreboard.asm      ; top 10 high scores (bubble sort, file)
INCLUDE Menu.asm            ; main menu

.data
consoleTitle BYTE "Elevator Rescue Simulator", 0

.code
main PROC
    call   Randomize
    INVOKE SetConsoleTitle, ADDR consoleTitle
    call   LoadScores
    call   RunMainMenu
    exit
main ENDP

END main
