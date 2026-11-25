; main.asm - where the program starts.
INCLUDE Irvine32.inc
INCLUDE Elevator.inc

.data
consoleTitle BYTE "Elevator Rescue Simulator", 0

.code
; Seeds the random numbers, sets the window title, loads the saved
; high scores and opens the main menu.
main PROC
    call   Randomize                    ; seed RandomRange / Random32
    INVOKE SetConsoleTitle, ADDR consoleTitle
    INVOKE LoadScores
    INVOKE RunMainMenu
    exit
main ENDP

END main
