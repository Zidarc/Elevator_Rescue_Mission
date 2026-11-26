DIR_UP   = 1
DIR_DOWN = -1

.data
msgScanNoEnergy BYTE "Not enough energy to scan.", 0
msgScanPrefix   BYTE "Scan complete: ", 0
msgScanSuffix   BYTE " civilians waiting.", 0
numBuffer       BYTE 12 DUP(0)

.code
ScanFloorsRecursive PROC
    push ebp
    mov  ebp, esp
    push ebx
    push ecx
    push esi

    mov  ecx, [ebp+8]                   ; ECX = floorIndex
    cmp  ecx, TOP_FLOOR
    ja   offTheBuilding                 ; base case

    ; mark floor as scanned
    mov  esi, OFFSET floors
    or   (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).floorFlags, FLAG_SCANNED

    xor  ebx, ebx                       ; EBX = civilians on this floor
    test (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).floorFlags, FLAG_CIVILIANS
    jz   recurseNext
    movzx ebx, (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).civilians

recurseNext:
    ; recursive call
    mov  eax, [ebp+12]                  ; direction
    push eax                            ; param 2: direction
    add  eax, ecx                       ; next floor
    push eax                            ; param 1: floorIndex
    call ScanFloorsRecursive            ; EAX = civilians beyond this floor
    add  eax, ebx                       ; + this floor
    jmp  scanReturn

offTheBuilding:
    xor  eax, eax

scanReturn:
    pop  esi
    pop  ecx
    pop  ebx
    mov  esp, ebp
    pop  ebp
    ret  8                              ; remove floorIndex and direction
ScanFloorsRecursive ENDP

ScanAction PROC USES ebx esi edi
    mov  eax, energy
    cmp  eax, SCAN_COST
    jb   scanNoEnergy
    sub  eax, SCAN_COST
    mov  energy, eax

    ; scan up
    push DIR_UP
    push elevatorFloor
    call ScanFloorsRecursive
    mov  ebx, eax                       ; EBX = running total

    ; scan down
    push DIR_DOWN
    mov  eax, elevatorFloor
    dec  eax
    push eax
    call ScanFloorsRecursive
    add  ebx, eax

    ; build status message
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
