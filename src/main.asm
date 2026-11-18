;=====================================================================
; main.asm
; Program entry point. Kept deliberately small: it seeds the random
; number generator, sets the console title and hands over to the menu.
;=====================================================================
INCLUDE Irvine32.inc
INCLUDE Elevator.inc

.data
consoleTitle BYTE "Elevator Rescue Simulator", 0

.code
main PROC
    call   Randomize                    ; seed RandomRange / Random32
    INVOKE SetConsoleTitle, ADDR consoleTitle
    INVOKE RunMainMenu
    exit
main ENDP

END main
