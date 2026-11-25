;=====================================================================
; GameLoop.asm
; The real-time game loop, input dispatch and round control.
;
;   CheckRoundOver   decides whether the current round has ended
;   HandleCommand    W/S/A/X/B/Q key dispatcher
;   RunRound         real-time loop: ReadKey + GetMseconds tick
;   RunGame          difficulty, then rounds 1..MAX_ROUNDS
;=====================================================================
INCLUDE Irvine32.inc
INCLUDE Elevator.inc

KEY_UP     = 'W'
KEY_DOWN   = 'S'
KEY_ACTION = 'A'
KEY_SCAN   = 'X'
KEY_SHOP   = 'B'
KEY_QUIT   = 'Q'
CASE_MASK  = 11011111b                  ; clears bit 5: lower -> upper case

.data
msgShopClosed   BYTE "The shop is not open yet.", 0
msgOutOfEnergy  BYTE "Out of energy. The round is over.", 0
msgAllCleared   BYTE "Building cleared. The round is over.", 0

.code
;---------------------------------------------------------------------
; AnyCiviliansWaiting  (private helper)
; Walks floors 1..TOP_FLOOR looking for waiting civilians.
; Receives: nothing
; Returns:  EAX = 1 if any floor still has FLAG_CIVILIANS and at
;           least one civilian, else 0
;---------------------------------------------------------------------
AnyCiviliansWaiting PROC USES ecx esi
    mov  esi, OFFSET floors
    add  esi, SIZEOF FloorInfo          ; skip the lobby
    mov  ecx, NUM_FLOORS - 1
checkFloor:
    test (FloorInfo PTR [esi]).floorFlags, FLAG_CIVILIANS
    jz   nextFloor
    cmp  (FloorInfo PTR [esi]).civilians, 0
    ja   foundWaiting
nextFloor:
    add  esi, SIZEOF FloorInfo
    loop checkFloor
    xor  eax, eax
    ret
foundWaiting:
    mov  eax, 1
    ret
AnyCiviliansWaiting ENDP

;---------------------------------------------------------------------
; CheckRoundOver
; Sets roundOver to 1 when any end condition holds:
;   1. the player pressed Q (quitRequested = 1)
;   2. energy is below MOVE_COST: the elevator cannot move any more.
;      Passengers on board are delivered if it stopped at the lobby
;      (PerformAction), otherwise they are counted as casualties.
;   3. nobody is waiting on any floor and the elevator is empty.
; Using "below MOVE_COST" instead of "= 0" stops the round from
; getting stuck at 1 energy after an odd-sized energy pack.
; Receives: nothing (reads globals)
; Returns:  EAX = roundOver (1 = over, 0 = keep playing)
;---------------------------------------------------------------------
CheckRoundOver PROC USES ebx
    ; --- 1. quit ---
    cmp  quitRequested, 0
    jne  roundEnded

    ; --- 2. out of energy ---
    cmp  energy, MOVE_COST
    jb   outOfEnergy

    ; --- 3. everyone rescued or lost ---
    mov  eax, passengersNormal
    add  eax, passengersCritical
    jnz  stillPlaying                   ; people on board
    call AnyCiviliansWaiting
    test eax, eax
    jnz  stillPlaying
    INVOKE StrCopyN, ADDR statusMsg, ADDR msgAllCleared, STATUS_SIZE
    jmp  roundEnded

outOfEnergy:
    mov  ebx, passengersNormal
    add  ebx, passengersCritical        ; EBX = people on board
    jz   reportOutOfEnergy
    cmp  elevatorFloor, LOBBY
    jne  passengersLost
    call PerformAction                  ; at the lobby: deliver them
    jmp  reportOutOfEnergy
passengersLost:
    add  casualties, ebx
    mov  passengersNormal, 0
    mov  passengersCritical, 0
reportOutOfEnergy:
    INVOKE StrCopyN, ADDR statusMsg, ADDR msgOutOfEnergy, STATUS_SIZE

roundEnded:
    mov  roundOver, 1
    mov  eax, 1
    ret

stillPlaying:
    mov  roundOver, 0
    xor  eax, eax
    ret
CheckRoundOver ENDP

;---------------------------------------------------------------------
; HandleCommand
; Dispatches one key press to the matching game action.
; Lower-case letters are folded to upper case by clearing bit 5
; (AND CASE_MASK), so 'w' and 'W' do the same thing.
;   W up   S down   A action   X scan   B shop   Q quit
; Receives: key = ASCII code of the key pressed
; Returns:  EAX = 1 if the key was a game command, 0 if ignored
;---------------------------------------------------------------------
HandleCommand PROC USES ebx, key:DWORD
    mov  ebx, key
    cmp  bl, 'a'
    jb   dispatchKey
    cmp  bl, 'z'
    ja   dispatchKey
    and  bl, CASE_MASK                  ; 'a'..'z' -> 'A'..'Z'

dispatchKey:
    cmp  bl, KEY_UP
    je   cmdUp
    cmp  bl, KEY_DOWN
    je   cmdDown
    cmp  bl, KEY_ACTION
    je   cmdAction
    cmp  bl, KEY_SCAN
    je   cmdScan
    cmp  bl, KEY_SHOP
    je   cmdShop
    cmp  bl, KEY_QUIT
    je   cmdQuit
    xor  eax, eax                       ; not a command
    ret

cmdUp:
    INVOKE MoveElevator, 1
    jmp  commandDone
cmdDown:
    INVOKE MoveElevator, -1
    jmp  commandDone
cmdAction:
    call PerformAction
    jmp  commandDone
cmdScan:
    call ScanAction
    jmp  commandDone
cmdShop:
    INVOKE StrCopyN, ADDR statusMsg, ADDR msgShopClosed, STATUS_SIZE
    jmp  commandDone
cmdQuit:
    mov  quitRequested, 1
commandDone:
    mov  eax, 1
    ret
HandleCommand ENDP

;---------------------------------------------------------------------
; RunRound
; The real-time loop for one round. Never blocks:
;   - ReadKey polls the keyboard (ZF = 1 when no key is waiting)
;   - GetMseconds is compared with lastTickMs; every TICK_MS one
;     second is taken off every waiting floor (TickFloors)
;   - the screen is redrawn only after a key or a tick
; Receives: a building prepared by InitializeGame
; Returns:  when CheckRoundOver reports the round has ended
;---------------------------------------------------------------------
RunRound PROC USES eax ebx edx
    call ClearGameScreen
    call GetMseconds
    mov  lastTickMs, eax
    call CalcRoundScore
    call DrawGameState

frameLoop:
    xor  ebx, ebx                       ; EBX = 1 when a redraw is needed
    mov  eax, FRAME_DELAY_MS
    call Delay

    ; --- keyboard ---
    call ReadKey
    jz   checkTimer                     ; no key waiting
    movzx eax, al
    INVOKE HandleCommand, eax
    or   ebx, eax                       ; redraw if it was a command

checkTimer:
    call GetMseconds
    mov  edx, eax
    sub  eax, lastTickMs                ; ms since the last tick
    jb   clockWrapped
    cmp  eax, TICK_MS
    jb   checkEnd
    add  lastTickMs, TICK_MS
    call TickFloors
    mov  ebx, 1
    jmp  checkEnd

clockWrapped:
    mov  lastTickMs, edx

checkEnd:
    call CheckRoundOver
    test eax, eax
    jnz  roundFinished
    test ebx, ebx
    jz   frameLoop
    call CalcRoundScore
    call DrawGameState
    jmp  frameLoop

roundFinished:
    ret
RunRound ENDP

;---------------------------------------------------------------------
; RunGame
; One full game: choose a difficulty, then play up to MAX_ROUNDS
; rounds. Q ends the game after the current round.
; Receives: nothing   Returns: nothing
;---------------------------------------------------------------------
RunGame PROC USES eax
    call Clrscr
    call SelectDifficulty
    call ResetGameState

roundLoop:
    call InitializeGame
    call RunRound
    call CalcRoundScore
    add  totalScore, eax
    mov  eax, rescuedNormal
    add  eax, rescuedCritical
    add  totalRescued, eax
    mov  eax, casualties
    add  totalLost, eax
    call ShowRoundOver
    cmp  quitRequested, 0
    jne  gameOver
    mov  eax, roundNum
    cmp  eax, MAX_ROUNDS
    jae  gameOver
    inc  roundNum
    jmp  roundLoop

gameOver:
    INVOKE SetCursorVisible, 1
    call ShowSummary
    call WaitMsg
    ret
RunGame ENDP

END
