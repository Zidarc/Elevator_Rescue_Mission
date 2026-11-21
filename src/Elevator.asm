;=====================================================================
; Elevator.asm
; Elevator movement, the action key and the TTL countdown.
;
;   MoveElevator    moves the elevator up or down one floor
;   PerformAction   pick up civilians, collect energy, or drop off
;   TickFloors      decrements every active floor's TTL by one second
;
; Logic modules never print. Status messages are written to statusMsg
; using StrCopyN; Render.asm draws them.
;=====================================================================
INCLUDE Irvine32.inc
INCLUDE Elevator.inc

.data
msgMoveUp       BYTE "Moved up.", 0
msgMoveDown     BYTE "Moved down.", 0
msgNoEnergy     BYTE "Not enough energy to move.", 0
msgAtTop        BYTE "Already at the top floor.", 0
msgAtBottom     BYTE "Already at the lobby.", 0
msgDropOff      BYTE "Passengers delivered to the lobby!", 0
msgNoPassDrop   BYTE "No passengers on board.", 0
msgPickedUp     BYTE "Picked up civilians.", 0
msgCapFull      BYTE "Elevator is full.", 0
msgEnergyPack   BYTE "Collected energy pack!", 0
msgNothingHere  BYTE "Nothing to do on this floor.", 0
msgFloorExpired BYTE "This floor has already expired.", 0

.code
;---------------------------------------------------------------------
; CopyStatus  (private helper)
; Copies a message string into the global statusMsg buffer.
; Receives: ESI = OFFSET of null-terminated source string
; Returns:  nothing
;---------------------------------------------------------------------
CopyStatus PROC USES eax
    INVOKE StrCopyN, ADDR statusMsg, esi, STATUS_SIZE
    ret
CopyStatus ENDP

;---------------------------------------------------------------------
; MoveElevator
; Moves the elevator one floor if it is in range and energy allows.
; Receives: direction = +1 (up) or -1 (down)
; Returns:  EAX = 1 if moved, 0 if refused
;---------------------------------------------------------------------
MoveElevator PROC USES ebx esi, direction:SDWORD
    ; --- check energy first ---
    mov  eax, energy
    cmp  eax, MOVE_COST
    jb   notEnoughEnergy

    ; --- check bounds ---
    mov  ebx, elevatorFloor
    mov  eax, direction
    cmp  eax, 0
    jl   goingDown

    ; direction >= 0: going up
    cmp  ebx, TOP_FLOOR
    jae  atTopFloor
    inc  ebx                            ; new floor
    mov  esi, OFFSET msgMoveUp
    jmp  applyMove

goingDown:
    cmp  ebx, LOBBY
    jbe  atBottomFloor
    dec  ebx                            ; new floor
    mov  esi, OFFSET msgMoveDown
    jmp  applyMove

applyMove:
    mov  elevatorFloor, ebx
    mov  eax, energy
    sub  eax, MOVE_COST
    mov  energy, eax

    ; --- reveal the floor we arrived at ---
    mov  eax, ebx
    mov  ebx, SIZEOF FloorInfo
    mul  ebx                            ; EAX = floor * sizeof
    mov  ebx, OFFSET floors
    add  ebx, eax                       ; EBX = &floors[new floor]
    mov  al, (FloorInfo PTR [ebx]).floorFlags
    or   al, FLAG_SCANNED
    mov  (FloorInfo PTR [ebx]).floorFlags, al

    call CopyStatus
    mov  eax, 1
    ret

notEnoughEnergy:
    mov  esi, OFFSET msgNoEnergy
    call CopyStatus
    xor  eax, eax
    ret

atTopFloor:
    mov  esi, OFFSET msgAtTop
    call CopyStatus
    xor  eax, eax
    ret

atBottomFloor:
    mov  esi, OFFSET msgAtBottom
    call CopyStatus
    xor  eax, eax
    ret
MoveElevator ENDP

;---------------------------------------------------------------------
; PerformAction
; At the lobby: drops off all passengers (scores points and credits).
; On upper floors: collects an energy pack if present, picks up
;   civilians up to the remaining capacity.
; Receives: nothing (reads globals)
; Returns:  nothing (all registers preserved)
;---------------------------------------------------------------------
PerformAction PROC USES eax ebx ecx edx esi edi
    mov  eax, elevatorFloor
    cmp  eax, LOBBY
    je   actionLobby

    ; --- upper floor: get the floor pointer ---
    mov  ecx, SIZEOF FloorInfo
    mul  ecx                            ; EAX = floor * sizeof
    mov  edi, OFFSET floors
    add  edi, eax                       ; EDI = &floors[elevatorFloor]

    ; --- reveal the floor ---
    mov  al, (FloorInfo PTR [edi]).floorFlags
    or   al, FLAG_SCANNED
    mov  (FloorInfo PTR [edi]).floorFlags, al

    ; --- check if floor has expired ---
    test al, FLAG_EXPIRED
    jnz  floorExpired

    ; --- energy pack? ---
    test al, FLAG_ENERGY
    jnz  collectEnergy

    ; --- civilians? ---
    test al, FLAG_CIVILIANS
    jnz  pickUpCivilians

    ; --- nothing on this floor ---
    mov  esi, OFFSET msgNothingHere
    call CopyStatus
    jmp  actionDone

floorExpired:
    mov  esi, OFFSET msgFloorExpired
    call CopyStatus
    jmp  actionDone

collectEnergy:
    mov  eax, energy
    add  eax, ENERGY_PACK
    cmp  eax, MAX_ENERGY
    jbe  storeEnergy
    mov  eax, MAX_ENERGY
storeEnergy:
    mov  energy, eax
    ; clear the energy flag
    mov  al, (FloorInfo PTR [edi]).floorFlags
    and  al, NOT FLAG_ENERGY
    mov  (FloorInfo PTR [edi]).floorFlags, al
    mov  esi, OFFSET msgEnergyPack
    call CopyStatus
    jmp  actionDone

pickUpCivilians:
    ; --- calculate free capacity ---
    mov  eax, capacity
    sub  eax, passengersNormal
    sub  eax, passengersCritical        ; EAX = free cap
    cmp  eax, 0
    jbe  elevatorFull

    ; EAX = free capacity, civilians on floor in BL
    movzx ebx, (FloorInfo PTR [edi]).civilians
    ; take = min(free, civilians)
    cmp  eax, ebx
    jbe  takeIsFree
    mov  eax, ebx                       ; take all civilians
takeIsFree:
    ; EAX = number to take
    mov  ecx, eax                       ; ECX = taken count

    ; subtract taken from floor
    sub  bl, cl
    mov  (FloorInfo PTR [edi]).civilians, bl

    ; are they critical?
    mov  al, (FloorInfo PTR [edi]).floorFlags
    test al, FLAG_CRITICAL
    jnz  pickCritical

    ; normal civilians
    add  passengersNormal, ecx
    jmp  pickDoneCheck

pickCritical:
    add  passengersCritical, ecx

pickDoneCheck:
    ; if no civilians remain, clear civilian and critical flags
    cmp  bl, 0
    ja   pickSetStatus
    mov  al, (FloorInfo PTR [edi]).floorFlags
    and  al, NOT (FLAG_CIVILIANS OR FLAG_CRITICAL)
    mov  (FloorInfo PTR [edi]).floorFlags, al

pickSetStatus:
    mov  esi, OFFSET msgPickedUp
    call CopyStatus
    jmp  actionDone

elevatorFull:
    mov  esi, OFFSET msgCapFull
    call CopyStatus
    jmp  actionDone

actionLobby:
    ; --- drop off passengers at the lobby ---
    mov  eax, passengersNormal
    or   eax, passengersCritical
    jz   noPassengers

    ; --- score normal ---
    mov  eax, passengersNormal
    mov  ebx, NORMAL_POINTS
    mul  ebx                            ; EAX = normal * 100
    add  roundScore, eax

    ; --- credits for normal ---
    mov  eax, passengersNormal
    mov  ebx, NORMAL_CREDITS
    mul  ebx                            ; EAX = normal * 10
    add  credits, eax

    ; --- rescued normal counter ---
    mov  eax, passengersNormal
    add  rescuedNormal, eax

    ; --- score critical ---
    mov  eax, passengersCritical
    mov  ebx, CRITICAL_POINTS
    mul  ebx                            ; EAX = critical * 300
    add  roundScore, eax

    ; --- credits for critical ---
    mov  eax, passengersCritical
    mov  ebx, CRITICAL_CREDITS
    mul  ebx                            ; EAX = critical * 25
    add  credits, eax

    ; --- rescued critical counter ---
    mov  eax, passengersCritical
    add  rescuedCritical, eax

    ; --- clear passengers ---
    mov  passengersNormal, 0
    mov  passengersCritical, 0

    mov  esi, OFFSET msgDropOff
    call CopyStatus
    jmp  actionDone

noPassengers:
    mov  esi, OFFSET msgNoPassDrop
    call CopyStatus

actionDone:
    ret
PerformAction ENDP

;---------------------------------------------------------------------
; TickFloors
; Called once per second by the game loop. Decrements ttlLeft on every
; floor that still has civilians waiting. When a floor's TTL reaches 0
; the civilians are lost (added to casualties), FLAG_EXPIRED is set
; and the civilian flags are cleared.
; Receives: nothing (reads/writes globals)
; Returns:  nothing (all registers preserved)
;---------------------------------------------------------------------
TickFloors PROC USES eax ecx esi
    mov  esi, OFFSET floors
    add  esi, SIZEOF FloorInfo          ; skip the lobby (floor 0)
    mov  ecx, NUM_FLOORS - 1            ; floors 1..9

tickLoop:
    mov  al, (FloorInfo PTR [esi]).floorFlags
    test al, FLAG_CIVILIANS
    jz   tickNext                       ; no civilians: skip

    ; --- decrement TTL ---
    movzx eax, (FloorInfo PTR [esi]).ttlLeft
    cmp  eax, 0
    je   tickNext                       ; already at 0 (should not happen)
    dec  eax
    mov  (FloorInfo PTR [esi]).ttlLeft, ax
    cmp  eax, 0
    jne  tickNext                       ; still has time

    ; --- TTL reached 0: civilians lost ---
    movzx eax, (FloorInfo PTR [esi]).civilians
    add  casualties, eax
    mov  (FloorInfo PTR [esi]).civilians, 0

    mov  al, (FloorInfo PTR [esi]).floorFlags
    and  al, NOT (FLAG_CIVILIANS OR FLAG_CRITICAL)
    or   al, FLAG_EXPIRED
    mov  (FloorInfo PTR [esi]).floorFlags, al

tickNext:
    add  esi, SIZEOF FloorInfo
    dec  ecx
    jnz  tickLoop

    ret
TickFloors ENDP

END
