; Scan.asm - the X key. Scans the whole building using RECURSION:
; it reveals every floor and counts how many people are still waiting.
INCLUDE Irvine32.inc
INCLUDE Elevator.inc

DIR_UP   = 1
DIR_DOWN = -1

.data
msgScanNoEnergy BYTE "Not enough energy to scan.", 0
msgScanPrefix   BYTE "Scan complete: ", 0
msgScanSuffix   BYTE " civilians waiting.", 0
numBuffer       BYTE 12 DUP(0)              ; up to 10 digits + null

.code
; Recursive function. Scans one floor, then calls ITSELF for the next
; floor in the same direction, and adds up the people it finds.
; Parameters are pushed on the stack by the caller and read with EBP:
;   [ebp+8]  = floor number
;   [ebp+12] = direction (+1 up, -1 down)
; Base case (stop): the floor number is past floor 9. Going below the
; lobby gives 0 - 1 = FFFFFFFFh, which is also "past 9" as an unsigned
; number, so one compare stops both ends.
; Returns EAX = people on this floor + all floors after it.
; RET 8 removes the two parameters from the stack.
ScanFloorsRecursive PROC
    push ebp
    mov  ebp, esp
    push ebx
    push ecx
    push esi

    mov  ecx, [ebp+8]                   ; ECX = floorIndex
    cmp  ecx, TOP_FLOOR
    ja   offTheBuilding                 ; base case

    ; reveal this floor: floors[ecx * SIZEOF FloorInfo]
    mov  esi, OFFSET floors
    or   (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).floorFlags, FLAG_SCANNED

    ; count its civilians if they are still waiting
    xor  ebx, ebx                       ; EBX = civilians on this floor
    test (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).floorFlags, FLAG_CIVILIANS
    jz   recurseNext
    movzx ebx, (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).civilians

recurseNext:
    ; ScanFloorsRecursive(floorIndex + direction, direction)
    mov  eax, [ebp+12]                  ; direction
    push eax                            ; param 2: direction
    add  eax, ecx                       ; next floor
    push eax                            ; param 1: floorIndex
    call ScanFloorsRecursive            ; EAX = civilians beyond this floor
    add  eax, ebx                       ; + this floor
    jmp  scanReturn

offTheBuilding:
    xor  eax, eax                       ; nothing past the edge

scanReturn:
    pop  esi
    pop  ecx
    pop  ebx
    mov  esp, ebp
    pop  ebp
    ret  8                              ; remove floorIndex and direction
ScanFloorsRecursive ENDP

; The X key. Costs 5 energy. Calls the recursive scan twice:
; once going up from the elevator, once going down from the floor below.
; Shows "Scan complete: N civilians waiting." in the status line.
ScanAction PROC USES ebx esi edi
    mov  eax, energy
    cmp  eax, SCAN_COST
    jb   scanNoEnergy
    sub  eax, SCAN_COST
    mov  energy, eax

    ; upward: elevator floor .. TOP_FLOOR
    push DIR_UP
    push elevatorFloor
    call ScanFloorsRecursive
    mov  ebx, eax                       ; EBX = running total

    ; downward: elevator floor - 1 .. LOBBY
    push DIR_DOWN
    mov  eax, elevatorFloor
    dec  eax                            ; from the lobby this is -1 (base case)
    push eax
    call ScanFloorsRecursive
    add  ebx, eax

    ; statusMsg = prefix + number + suffix
    INVOKE StrCopyN, ADDR statusMsg, ADDR msgScanPrefix, STATUS_SIZE
    INVOKE StrFromUInt, ebx, ADDR numBuffer
    INVOKE StrLen, ADDR statusMsg
    mov  esi, OFFSET statusMsg
    add  esi, eax                       ; ESI = end of the prefix
    mov  edi, STATUS_SIZE
    sub  edi, eax                       ; room left
    INVOKE StrCopyN, esi, ADDR numBuffer, edi
    INVOKE StrLen, ADDR statusMsg
    mov  esi, OFFSET statusMsg
    add  esi, eax
    mov  edi, STATUS_SIZE
    sub  edi, eax
    INVOKE StrCopyN, esi, ADDR msgScanSuffix, edi

    mov  eax, ebx
    ret

scanNoEnergy:
    INVOKE StrCopyN, ADDR statusMsg, ADDR msgScanNoEnergy, STATUS_SIZE
    mov  eax, 0FFFFFFFFh
    ret
ScanAction ENDP

END
