; Elevator.asm - what the elevator does: moving up and down (W / S),
; the action key A (pick up, drop off, energy pack) and the timers
; counting down every second.
; This file never prints. It writes a message into statusMsg and
; Render.asm shows it on the screen.
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
; Puts the message at ESI into statusMsg (the line under the game).
CopyStatus PROC USES eax
    INVOKE StrCopyN, ADDR statusMsg, esi, STATUS_SIZE
    ret
CopyStatus ENDP

; Moves the elevator one floor up (+1) or down (-1).
; Refused if there is not enough energy or we are at the top / lobby.
; Each move costs 2 energy and reveals the floor we arrive at.
; EAX = 1 if it moved, 0 if refused.
MoveElevator PROC USES ebx edx esi, direction:SDWORD
    ; check energy first
    mov  eax, energy
    cmp  eax, MOVE_COST
    jb   notEnoughEnergy

    ; check bounds
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

    ; reveal the floor we arrived at
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

; The A key. What happens depends on where the elevator is:
;   lobby:        drop off all passengers -> points, credits, rescued count
;   energy floor: collect the pack (+25 energy, max 150)
;   people floor: pick up as many as the free space in the elevator allows
PerformAction PROC USES eax ebx ecx edx esi edi
    mov  eax, elevatorFloor
    cmp  eax, LOBBY
    je   actionLobby

    ; upper floor: get the floor pointer
    mov  ecx, SIZEOF FloorInfo
    mul  ecx                            ; EAX = floor * sizeof
    mov  edi, OFFSET floors
    add  edi, eax                       ; EDI = &floors[elevatorFloor]

    ; reveal the floor
    mov  al, (FloorInfo PTR [edi]).floorFlags
    or   al, FLAG_SCANNED
    mov  (FloorInfo PTR [edi]).floorFlags, al

    ; check if floor has expired
    test al, FLAG_EXPIRED
    jnz  floorExpired

    ; energy pack?
    test al, FLAG_ENERGY
    jnz  collectEnergy

    ; civilians?
    test al, FLAG_CIVILIANS
    jnz  pickUpCivilians

    ; nothing on this floor
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
    ; calculate free capacity
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
    ; drop off passengers at the lobby
    mov  eax, passengersNormal
    or   eax, passengersCritical
    jz   noPassengers

    ; score normal
    mov  eax, passengersNormal
    mov  ebx, NORMAL_POINTS
    mul  ebx                            ; EAX = normal * 100
    add  roundScore, eax

    ; credits for normal
    mov  eax, passengersNormal
    mov  ebx, NORMAL_CREDITS
    mul  ebx                            ; EAX = normal * 10
    add  credits, eax

    ; rescued normal counter
    mov  eax, passengersNormal
    add  rescuedNormal, eax

    ; score critical
    mov  eax, passengersCritical
    mov  ebx, CRITICAL_POINTS
    mul  ebx                            ; EAX = critical * 300
    add  roundScore, eax

    ; credits for critical
    mov  eax, passengersCritical
    mov  ebx, CRITICAL_CREDITS
    mul  ebx                            ; EAX = critical * 25
    add  credits, eax

    ; rescued critical counter
    mov  eax, passengersCritical
    add  rescuedCritical, eax

    ; clear passengers
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

; Called once every second. Takes 1 second off the timer of every floor
; that still has people waiting. When a timer hits 0, those people are
; lost: they are added to casualties and the floor is marked expired (x).
TickFloors PROC USES eax ecx esi
    mov  esi, OFFSET floors
    add  esi, SIZEOF FloorInfo          ; skip the lobby (floor 0)
    mov  ecx, NUM_FLOORS - 1            ; floors 1..9

tickLoop:
    mov  al, (FloorInfo PTR [esi]).floorFlags
    test al, FLAG_CIVILIANS
    jz   tickNext                       ; no civilians: skip

    ; decrement TTL
    movzx eax, (FloorInfo PTR [esi]).ttlLeft
    cmp  eax, 0
    je   tickNext                       ; already at 0 (should not happen)
    dec  eax
    mov  (FloorInfo PTR [esi]).ttlLeft, ax
    cmp  eax, 0
    jne  tickNext                       ; still has time

    ; TTL reached 0: civilians lost
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
