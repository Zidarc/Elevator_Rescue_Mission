;=====================================================================
; TestFramework.asm
; Pass / fail counters, AssertEq (used by mAssertEq) and output helpers.
;
; Test output goes through WriteFile on the standard output handle,
; not Irvine's WriteString (which uses WriteConsole and prints nothing
; when the output is redirected to a file or a pipe).
;=====================================================================
INCLUDE Irvine32.inc
INCLUDE Elevator.inc
INCLUDE TestFramework.inc

.data
testsPassed DWORD 0
testsFailed DWORD 0
stdOutHandle DWORD 0
bytesWritten DWORD 0
passTag     BYTE "  [PASS] ", 0
failTag     BYTE "  [FAIL] ", 0
expectedTag BYTE "   (expected ", 0
gotTag      BYTE ", got ", 0
closeTag    BYTE ")", 0
suiteTag    BYTE 0Dh, 0Ah, "== ", 0
newLine     BYTE 0Dh, 0Ah, 0
numBuffer   BYTE 12 DUP(0)

.code
;---------------------------------------------------------------------
; TPrint - writes a null-terminated string to standard output.
; Receives: pStr.  Preserves all registers.
;---------------------------------------------------------------------
TPrint PROC USES eax ecx edx, pStr:PTR BYTE
    cmp  stdOutHandle, 0
    jne  haveHandle
    INVOKE GetStdHandle, STD_OUTPUT_HANDLE
    mov  stdOutHandle, eax
haveHandle:
    INVOKE StrLen, pStr
    INVOKE WriteFile, stdOutHandle, pStr, eax, ADDR bytesWritten, 0
    ret
TPrint ENDP

;---------------------------------------------------------------------
; TPrintInt - writes a signed DWORD in decimal.
; Converts by repeated division by 10, filling numBuffer from the end.
; Receives: value.  Preserves all registers.
;---------------------------------------------------------------------
TPrintInt PROC USES eax ebx ecx edx edi, value:SDWORD
    mov  edi, OFFSET numBuffer + (SIZEOF numBuffer - 1)
    mov  BYTE PTR [edi], 0              ; terminator
    mov  eax, value
    xor  ecx, ecx                       ; ECX = 1 if negative
    test eax, eax
    jns  convert
    neg  eax
    mov  ecx, 1
convert:
    mov  ebx, 10
digitLoop:
    xor  edx, edx
    div  ebx                            ; EAX = quotient, EDX = digit
    add  dl, '0'
    dec  edi
    mov  [edi], dl
    test eax, eax
    jnz  digitLoop
    jecxz printIt
    dec  edi
    mov  BYTE PTR [edi], '-'
printIt:
    INVOKE TPrint, edi
    ret
TPrintInt ENDP

;---------------------------------------------------------------------
; AssertEq
; Compares two DWORDs, prints PASS / FAIL and updates the counters.
; Preserves every general-purpose register.
;---------------------------------------------------------------------
AssertEq PROC USES eax, actual:DWORD, expected:DWORD, pDesc:PTR BYTE
    mov  eax, actual
    cmp  eax, expected
    jne  failed

    inc  testsPassed
    mov  eax, lightGreen + (black * 16)
    call SetTextColor
    INVOKE TPrint, ADDR passTag
    jmp  printDesc

failed:
    inc  testsFailed
    mov  eax, lightRed + (black * 16)
    call SetTextColor
    INVOKE TPrint, ADDR failTag

printDesc:
    mov  eax, lightGray + (black * 16)
    call SetTextColor
    INVOKE TPrint, pDesc

    mov  eax, actual
    cmp  eax, expected
    je   finished
    INVOKE TPrint, ADDR expectedTag     ; show both values on failure
    INVOKE TPrintInt, expected
    INVOKE TPrint, ADDR gotTag
    INVOKE TPrintInt, actual
    INVOKE TPrint, ADDR closeTag
finished:
    INVOKE TPrint, ADDR newLine
    ret
AssertEq ENDP

;---------------------------------------------------------------------
; PrintSuite - prints "== name" in yellow.
;---------------------------------------------------------------------
PrintSuite PROC USES eax, pName:PTR BYTE
    mov  eax, yellow + (black * 16)
    call SetTextColor
    INVOKE TPrint, ADDR suiteTag
    INVOKE TPrint, pName
    INVOKE TPrint, ADDR newLine
    mov  eax, lightGray + (black * 16)
    call SetTextColor
    ret
PrintSuite ENDP

END
