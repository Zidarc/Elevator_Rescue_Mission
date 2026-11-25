;=====================================================================
; Scan.asm
; The X key: a recursive scan that walks up and down the building,
; reveals every floor's contents and reports how many civilians are
; still waiting.
;
;   ScanAction           checks / charges energy, runs both scans,
;                        writes the result into statusMsg
;   ScanFloorsRecursive  scans one floor, then calls itself for the
;                        next floor in the same direction
;
; Logic module: never prints. The result goes to statusMsg.
;=====================================================================
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
;---------------------------------------------------------------------
; ScanFloorsRecursive
; Scans floorIndex, then recursively scans floorIndex + direction
; until it walks off the building. Uses a manual EBP stack frame.
;
; Stack parameters (pushed by the caller, right to left):
;   [ebp+8]  floorIndex : DWORD  floor to scan (0..TOP_FLOOR)
;   [ebp+12] direction  : SDWORD +1 (up) or -1 (down)
; Returns:  EAX = civilians waiting on this floor and every floor
;           beyond it in that direction. Floors are marked
;           FLAG_SCANNED. All other registers preserved.
;           The procedure removes its own parameters (RET 8).
;
; Base case: floorIndex > TOP_FLOOR. Going below the lobby turns
; 0 - 1 into 0FFFFFFFFh, so one unsigned compare (JA) catches both
; ends of the building.
;---------------------------------------------------------------------
ScanFloorsRecursive PROC
    push ebp
    mov  ebp, esp
    push ebx
    push ecx
    push esi

    mov  ecx, [ebp+8]                   ; ECX = floorIndex
    cmp  ecx, TOP_FLOOR
    ja   offTheBuilding                 ; base case

    ; --- reveal this floor: floors[ecx * SIZEOF FloorInfo] ---
    mov  esi, OFFSET floors
    or   (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).floorFlags, FLAG_SCANNED

    ; --- count its civilians if they are still waiting ---
    xor  ebx, ebx                       ; EBX = civilians on this floor
    test (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).floorFlags, FLAG_CIVILIANS
    jz   recurseNext
    movzx ebx, (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).civilians

recurseNext:
    ; --- ScanFloorsRecursive(floorIndex + direction, direction) ---
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

;---------------------------------------------------------------------
; ScanAction
; The X key. Costs SCAN_COST energy, scans from the elevator's floor
; upwards and from the floor below it downwards, and reports the
; number of civilians still waiting in statusMsg.
; Receives: nothing (reads elevatorFloor, energy)
; Returns:  EAX = civilians waiting in the whole building,
;           or 0FFFFFFFFh if refused (not enough energy)
;---------------------------------------------------------------------
ScanAction PROC USES ebx esi edi
    mov  eax, energy
    cmp  eax, SCAN_COST
    jb   scanNoEnergy
    sub  eax, SCAN_COST
    mov  energy, eax

    ; --- upward: elevator floor .. TOP_FLOOR ---
    push DIR_UP
    push elevatorFloor
    call ScanFloorsRecursive
    mov  ebx, eax                       ; EBX = running total

    ; --- downward: elevator floor - 1 .. LOBBY ---
    push DIR_DOWN
    mov  eax, elevatorFloor
    dec  eax                            ; from the lobby this is -1 (base case)
    push eax
    call ScanFloorsRecursive
    add  ebx, eax

    ; --- statusMsg = prefix + number + suffix ---
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
