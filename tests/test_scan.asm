; test_scan.asm - tests for the recursive scan.
; Test building used by every test (5 people waiting in total):
;   floor 2  normal,   3 people
;   floor 5  critical, 2 people
;   floor 7  expired   (people lost, must not be counted)
;   floor 8  energy pack

FIXTURE_TOTAL = 5
MIDDLE_FLOOR  = 5

.code
; ESI = address of floor number EAX.
FloorPtr PROC USES eax edx
    mov  edx, SIZEOF FloorInfo
    mul  edx
    mov  esi, OFFSET floors
    add  esi, eax
    ret
FloorPtr ENDP

; Clears the building and builds the test building described above.
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

; EAX = how many floors are marked as scanned.
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

; The scan finds the same 5 people from any starting floor.
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

; Every floor gets revealed and the scan costs 5 energy once.
TestScanFlagsAndCost PROC USES eax
    call ResetScanTestState
    mov  elevatorFloor, MIDDLE_FLOOR
    mov  energy, 100
    call ScanAction
    call CountScannedFloors
    mAssertEq eax, NUM_FLOORS, "scan sets FLAG_SCANNED on all 10 floors"
    mAssertEq energy, 100 - SCAN_COST, "scan costs SCAN_COST energy"

    ; flags that were already there survive the scan
    mov  eax, 5
    call FloorPtr
    movzx eax, (FloorInfo PTR [esi]).floorFlags
    and  eax, FLAG_CRITICAL
    mAssertEq eax, FLAG_CRITICAL, "scan keeps FLAG_CRITICAL"
    ret
TestScanFlagsAndCost ENDP

; With less than 5 energy the scan is refused and reveals nothing.
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

; Calls the recursive function directly and checks that ESP and the registers
; are the same afterwards, so the stack is balanced after the recursion.
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

    ; ESP and the preserved registers are unchanged
    mov  ebx, 11111111h
    mov  ecx, 22222222h
    mov  esi, 33333333h
    mov  edi, esp                       ; ESP before
    push 1
    push LOBBY
    call ScanFloorsRecursive            ; deepest recursion: 11 levels
    mov  edx, esp
    mAssertEq edx, edi, "ESP is the same after the recursive call"
    mAssertEq ebx, 11111111h, "EBX preserved by the recursion"
    mAssertEq ecx, 22222222h, "ECX preserved by the recursion"
    mAssertEq esi, 33333333h, "ESI preserved by the recursion"
    ret
TestScanRecursiveDirect ENDP

; Runs all Scan tests.
TestScan PROC
    mSuite "Scan"
    call TestScanTotals
    call TestScanFlagsAndCost
    call TestScanNoEnergy
    call TestScanRecursiveDirect
    call ResetScanTestState             ; leave a clean building behind
    ret
TestScan ENDP
