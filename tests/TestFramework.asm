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
testNumBuffer   BYTE 12 DUP(0)

.code
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

TPrintInt PROC USES eax ebx ecx edx edi, value:SDWORD
    mov  edi, OFFSET testNumBuffer + (SIZEOF testNumBuffer - 1)
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
    INVOKE TPrint, ADDR expectedTag
    INVOKE TPrintInt, expected
    INVOKE TPrint, ADDR gotTag
    INVOKE TPrintInt, actual
    INVOKE TPrint, ADDR closeTag
finished:
    INVOKE TPrint, ADDR newLine
    ret
AssertEq ENDP

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
