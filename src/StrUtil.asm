; StrUtil.asm - our own string functions, built with the x86 string
; instructions (SCASB, CMPSB, LODSB, STOSB, REP / REPE / REPNE).
; Every string ends with a 0 byte.
INCLUDE Irvine32.inc
INCLUDE Elevator.inc

.code
; Counts the characters in a string and returns the count in EAX.
; REPNE SCASB searches for the 0 byte; ECX tells how far it went.
StrLen PROC USES ecx edi, pStr:PTR BYTE
    mov  edi, pStr
    xor  eax, eax                       ; AL = 0, the byte we look for
    mov  ecx, -1                        ; scan "forever"
    cld
    repne scasb                         ; ECX = -(length + 2) afterwards
    not  ecx                            ; ECX = length + 1
    dec  ecx
    mov  eax, ecx
    ret
StrLen ENDP

; Copies a string into a buffer of maxLen bytes without overflowing it.
; Copies at most maxLen - 1 characters and always adds the 0 at the end.
; Uses LODSB (read a char) and STOSB (write a char). EAX = chars copied.
StrCopyN PROC USES ecx esi edi, pDest:PTR BYTE, pSrc:PTR BYTE, maxLen:DWORD
    mov  edi, pDest
    mov  esi, pSrc
    mov  ecx, maxLen
    jecxz done                          ; no room at all
    dec  ecx                            ; keep one byte for the null
    cld
    jecxz terminate
copyLoop:
    lodsb
    test al, al                         ; end of source?
    jz   terminate
    stosb
    loop copyLoop
terminate:
    mov  BYTE PTR [edi], 0
done:
    mov  eax, edi
    sub  eax, pDest                     ; characters written (null excluded)
    ret
StrCopyN ENDP

; Checks if two strings are the same. EAX = 1 same, 0 different.
; First compares lengths, then REPE CMPSB compares byte by byte.
StrEqual PROC USES ecx esi edi, pStr1:PTR BYTE, pStr2:PTR BYTE
    INVOKE StrLen, pStr1
    mov  ecx, eax
    INVOKE StrLen, pStr2
    cmp  eax, ecx
    jne  notEqual                       ; different lengths

    inc  ecx                            ; also compare the null (handles "")
    mov  esi, pStr1
    mov  edi, pStr2
    cld
    repe cmpsb
    jne  notEqual
    mov  eax, 1
    ret
notEqual:
    xor  eax, eax
    ret
StrEqual ENDP

; Fills a buffer with "count" copies of one character, then a 0.
; REP STOSB writes AL into memory ECX times. Used to draw the ---- lines.
StrFill PROC USES eax ecx edi, pDest:PTR BYTE, count:DWORD, fillChar:DWORD
    mov  edi, pDest
    mov  ecx, count
    mov  eax, fillChar
    cld
    rep  stosb
    mov  BYTE PTR [edi], 0
    ret
StrFill ENDP

; Changes a-z to A-Z inside the string.
; In ASCII, lower and upper case differ only in bit 5,
; so AND with 11011111b clears that bit and makes the letter capital.
StrToUpper PROC USES eax esi, pStr:PTR BYTE
    mov  esi, pStr
nextChar:
    mov  al, [esi]
    test al, al
    jz   finished
    cmp  al, 'a'
    jb   skip
    cmp  al, 'z'
    ja   skip
    and  al, 11011111b                  ; clear bit 5: lower -> upper
    mov  [esi], al
skip:
    inc  esi
    jmp  nextChar
finished:
    ret
StrToUpper ENDP

; Adds spaces at the end of a string until it is fieldWidth long.
; Used to line up the names in the high-score table.
StrPadRight PROC USES eax ecx edi, pStr:PTR BYTE, fieldWidth:DWORD
    INVOKE StrLen, pStr
    mov  ecx, fieldWidth
    cmp  eax, ecx
    jae  finished                       ; already wide enough
    sub  ecx, eax                       ; spaces needed
    mov  edi, pStr
    add  edi, eax                       ; point at the old null
    mov  al, ' '
    cld
    rep  stosb
    mov  BYTE PTR [edi], 0
finished:
    ret
StrPadRight ENDP

; Turns a number into text (for example 125 -> "125").
; Keeps dividing by 10 (DIV); each remainder is one digit. The digits come
; out backwards, so they are PUSHed and then POPped in the right order.
; EAX = number of digits.
StrFromUInt PROC USES ebx ecx edx edi, value:DWORD, pDest:PTR BYTE
    mov  eax, value
    mov  edi, pDest
    mov  ebx, 10
    xor  ecx, ecx
pushDigit:
    xor  edx, edx
    div  ebx
    add  dl, '0'
    push edx
    inc  ecx
    test eax, eax
    jnz  pushDigit
    mov  eax, ecx
popDigit:
    pop  edx
    mov  [edi], dl
    inc  edi
    loop popDigit
    mov  BYTE PTR [edi], 0
    ret
StrFromUInt ENDP

END
