; GameLoop.asm - runs the game: the real-time loop, the keys,
; the sounds, checking when a round ends, and playing the 3 rounds.

KEY_UP     = 'W'
KEY_DOWN   = 'S'
KEY_ACTION = 'A'
KEY_SCAN   = 'X'
KEY_SHOP   = 'B'
KEY_QUIT   = 'Q'
CASE_MASK  = 11011111b                  ; clears bit 5: lower -> upper case

TONE_RESCUE = 880
TONE_LOST   = 220
TONE_ROUND  = 660
TONE_SHORT  = 60
TONE_LONG   = 250

; Beep is a Windows function that is not part of Irvine32. This one line
; tells MASM its name and its two numbers (frequency, length in ms).
Beep PROTO, dwFreq:DWORD, dwDuration:DWORD

.data
msgOutOfEnergy  BYTE "Out of energy. The round is over.", 0
msgAllCleared   BYTE "Building cleared. The round is over.", 0
heardRescued    DWORD 0
heardLost       DWORD 0

.code
; Looks through floors 1-9. EAX = 1 if anyone is still waiting, else 0.
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

; Decides if the round is finished. It ends when:
;   1. the player pressed Q
;   2. energy is too low to move (below 2). If the elevator stopped in
;      the lobby the passengers are saved, anywhere else they are lost.
;   3. nobody is waiting on any floor and the elevator is empty
; EAX = 1 if the round is over, 0 to keep playing.
CheckRoundOver PROC USES ebx
    ; 1. quit
    cmp  quitRequested, 0
    jne  roundEnded

    ; 2. out of energy
    cmp  energy, MOVE_COST
    jb   outOfEnergy

    ; 3. everyone rescued or lost
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

; Takes one key and runs the matching action:
;   W up   S down   A action   X scan   B shop   Q quit
; Small letters are made capital first (AND clears bit 5),
; so 'w' and 'W' do the same thing.
; EAX = 1 if it was a game key, 0 if the key is ignored.
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
    call BuyInLobby
    test eax, eax
    jz   commandDone
    call ClearGameScreen
    call GetMseconds
    mov  lastTickMs, eax                ; restart the clock: time in the shop is not counted
    jmp  commandDone
cmdQuit:
    mov  quitRequested, 1
commandDone:
    mov  eax, 1
    ret
HandleCommand ENDP

; Beeps when something happened since the last check:
; a high beep when people were rescued, a low beep when people were lost.
; Beep is a Win32 function: Beep(frequency in Hz, length in ms).
PlayEventSounds PROC USES eax ecx edx
    mov  eax, rescuedNormal
    add  eax, rescuedCritical
    cmp  eax, heardRescued
    je   checkLost
    mov  heardRescued, eax
    INVOKE Beep, TONE_RESCUE, TONE_SHORT
checkLost:
    mov  eax, casualties
    cmp  eax, heardLost
    je   soundsDone
    mov  heardLost, eax
    INVOKE Beep, TONE_LOST, TONE_SHORT
soundsDone:
    ret
PlayEventSounds ENDP

; The real-time loop of one round. It never stops to wait for a key:
;   - ReadKey checks if a key was pressed (ZF = 1 means no key)
;   - GetMseconds gives the time in ms; every 1000 ms TickFloors runs
;   - the screen is redrawn only when something changed
; Loops until CheckRoundOver says the round is over.
RunRound PROC USES eax ebx edx
    mov  heardRescued, 0
    mov  heardLost, 0
    call ClearGameScreen
    call GetMseconds
    mov  lastTickMs, eax                ; start the 1 second clock
    call CalcRoundScore
    call DrawGameState

frameLoop:
    xor  ebx, ebx                       ; EBX = 1 when a redraw is needed
    mov  eax, FRAME_DELAY_MS
    call Delay

    ; keyboard
    call ReadKey
    jz   checkTimer                     ; no key waiting
    movzx eax, al
    INVOKE HandleCommand, eax
    or   ebx, eax                       ; redraw if it was a command

checkTimer:
    call GetMseconds
    mov  edx, eax
    sub  eax, lastTickMs                ; ms since the last tick
    jb   clockWrapped                   ; clock went back to 0 (after midnight)
    cmp  eax, TICK_MS
    jb   checkEnd
    add  lastTickMs, TICK_MS
    call TickFloors
    mov  ebx, 1
    jmp  checkEnd

clockWrapped:
    mov  lastTickMs, edx                ; start counting again from now

checkEnd:
    call CheckRoundOver
    test eax, eax
    jnz  roundFinished
    test ebx, ebx
    jz   frameLoop
    call PlayEventSounds                ; beep if someone was rescued or lost
    call CalcRoundScore
    call DrawGameState
    jmp  frameLoop

roundFinished:
    ret
RunRound ENDP

; One full game: choose difficulty, then play up to 3 rounds.
; After each round the score is calculated and added to the total.
; Q ends the game early. At the end: summary, then the high-score table.
RunGame PROC USES eax ecx edx
    call Clrscr
    call SelectDifficulty
    call ResetGameState

roundLoop:
    call InitializeGame
    call RunRound
    INVOKE Beep, TONE_ROUND, TONE_LONG  ; round over sound
    call CalcRoundScore
    add  totalScore, eax                ; add the round score to the total
    mov  eax, rescuedNormal
    add  eax, rescuedCritical
    add  totalRescued, eax
    mov  eax, casualties
    add  totalLost, eax
    call ShowRoundOver                  ; show the round result, wait for a key
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
    call RecordScore
    ret
RunGame ENDP
