FIXTURE_TOTAL = 5
MIDDLE_FLOOR  = 5

.code
FloorPtr PROC USES eax edx
    mov  edx, SIZEOF FloorInfo
    mul  edx
    mov  esi, OFFSET floors
    add  esi, eax
    ret
FloorPtr ENDP

ResetScanTestState PROC USES eax ecx esi
    mov  difficulty, DIFF_NORMAL
    mov  elevatorFloor, LOBBY
    mov  energy, 100

    mov  esi, OFFSET floors
    mov  ecx, NUM_FLOORS
clearFloor:
    mov  (FloorInfo PTR [esi]).civilians, 0
    mov  (FloorInfo PTR [esi]).floorFlags, 0
    mov  (FloorInfo PTR [esi]).ttlLeft, 0
    mov  (FloorInfo PTR [esi]).ttlStart, 0
    add  esi, SIZEOF FloorInfo
    loop clearFloor

    mov  eax, 2
    call FloorPtr
    mov  (FloorInfo PTR [esi]).civilians, 3
    mov  (FloorInfo PTR [esi]).floorFlags, FLAG_CIVILIANS

    mov  eax, 5
    call FloorPtr
    mov  (FloorInfo PTR [esi]).civilians, 2
    mov  (FloorInfo PTR [esi]).floorFlags, FLAG_CIVILIANS OR FLAG_CRITICAL

    mov  eax, 7
    call FloorPtr
    mov  (FloorInfo PTR [esi]).floorFlags, FLAG_EXPIRED

    mov  eax, 8
    call FloorPtr
    mov  (FloorInfo PTR [esi]).floorFlags, FLAG_ENERGY
    ret
ResetScanTestState ENDP

CountScannedFloors PROC USES ecx esi
    xor  eax, eax
    mov  esi, OFFSET floors
    mov  ecx, NUM_FLOORS
countLoop:
    test (FloorInfo PTR [esi]).floorFlags, FLAG_SCANNED
    jz   notScanned
    inc  eax
notScanned:
    add  esi, SIZEOF FloorInfo
    loop countLoop
    ret
CountScannedFloors ENDP

TestScanTotals PROC USES eax
    call ResetScanTestState
    mov  elevatorFloor, LOBBY
    call ScanAction
    mAssertEq eax, FIXTURE_TOTAL, "scan from the lobby finds 5"

    call ResetScanTestState
    mov  elevatorFloor, TOP_FLOOR
    call ScanAction
    mAssertEq eax, FIXTURE_TOTAL, "scan from the top floor finds 5"

    call ResetScanTestState
    mov  elevatorFloor, MIDDLE_FLOOR
    call ScanAction
    mAssertEq eax, FIXTURE_TOTAL, "scan from the middle finds 5"
    ret
TestScanTotals ENDP

TestScanFlagsAndCost PROC USES eax
    call ResetScanTestState
    mov  elevatorFloor, MIDDLE_FLOOR
    mov  energy, 100
    call ScanAction
    call CountScannedFloors
    mAssertEq eax, NUM_FLOORS, "scan sets FLAG_SCANNED on all 10 floors"
    mAssertEq energy, 100 - SCAN_COST, "scan costs SCAN_COST energy"

    mov  eax, 5
    call FloorPtr
    movzx eax, (FloorInfo PTR [esi]).floorFlags
    and  eax, FLAG_CRITICAL
    mAssertEq eax, FLAG_CRITICAL, "scan keeps FLAG_CRITICAL"
    ret
TestScanFlagsAndCost ENDP

TestScanNoEnergy PROC USES eax
    call ResetScanTestState
    mov  energy, SCAN_COST - 1
    call ScanAction
    mAssertEq eax, 0FFFFFFFFh, "scan refused without enough energy"
    mAssertEq energy, SCAN_COST - 1, "refused scan uses no energy"
    call CountScannedFloors
    mAssertEq eax, 0, "refused scan reveals nothing"

    call ResetScanTestState
    mov  energy, SCAN_COST
    call ScanAction
    mAssertEq eax, FIXTURE_TOTAL, "scan allowed with exactly SCAN_COST"
    mAssertEq energy, 0, "energy is 0 after that scan"
    ret
TestScanNoEnergy ENDP

TestScanRecursiveDirect PROC USES eax ebx ecx edx esi edi
    call ResetScanTestState

    push 1                              ; up from floor 3: floor 5 only
    push 3
    call ScanFloorsRecursive
    mAssertEq eax, 2, "recursive scan up from floor 3 finds 2"

    push -1                             ; down from floor 5: floors 5 and 2
    push 5
    call ScanFloorsRecursive
    mAssertEq eax, 5, "recursive scan down from floor 5 finds 5"

    push -1                             ; base case below the lobby
    push -1
    call ScanFloorsRecursive
    mAssertEq eax, 0, "recursive scan below the lobby returns 0"

    push 1                              ; base case above the top floor
    push NUM_FLOORS
    call ScanFloorsRecursive
    mAssertEq eax, 0, "recursive scan above the top returns 0"

    mov  ebx, 11111111h
    mov  ecx, 22222222h
    mov  esi, 33333333h
    mov  edi, esp                       ; ESP before
    push 1
    push LOBBY
    call ScanFloorsRecursive
    mov  edx, esp
    mAssertEq edx, edi, "ESP is the same after the recursive call"
    mAssertEq ebx, 11111111h, "EBX preserved by the recursion"
    mAssertEq ecx, 22222222h, "ECX preserved by the recursion"
    mAssertEq esi, 33333333h, "ESI preserved by the recursion"
    ret
TestScanRecursiveDirect ENDP

TestScan PROC
    mSuite "Scan"
    call TestScanTotals
    call TestScanFlagsAndCost
    call TestScanNoEnergy
    call TestScanRecursiveDirect
    call ResetScanTestState
    ret
TestScan ENDP
