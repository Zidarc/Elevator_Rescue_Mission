;=====================================================================
; StrUtil.asm
; String helpers built on the x86 string primitives
; (SCASB, CMPSB, LODSB, STOSB with REP / REPE / REPNE).
; All strings are null-terminated BYTE arrays.
;=====================================================================
INCLUDE Irvine32.inc
INCLUDE Elevator.inc

.code
;---------------------------------------------------------------------
; StrLen
; Length of a null-terminated string, using REPNE SCASB.
; Receives: pStr
; Returns:  EAX = number of characters before the null
;---------------------------------------------------------------------
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

;---------------------------------------------------------------------
; StrCopyN
; Copies at most maxLen - 1 characters from pSrc to pDest and always
; writes a null terminator (unless maxLen is 0). Uses LODSB / STOSB.
; Receives: pDest, pSrc, maxLen = size of the destination buffer
; Returns:  EAX = number of characters copied
;---------------------------------------------------------------------
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

;---------------------------------------------------------------------
; StrEqual
; Compares two strings with REPE CMPSB.
; Receives: pStr1, pStr2
; Returns:  EAX = 1 if equal, 0 otherwise
;---------------------------------------------------------------------
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

;---------------------------------------------------------------------
; StrFill
; Writes count copies of fillChar followed by a null, using REP STOSB.
; Receives: pDest, count, fillChar (low byte used)
; Returns:  nothing
;---------------------------------------------------------------------
StrFill PROC USES eax ecx edi, pDest:PTR BYTE, count:DWORD, fillChar:DWORD
    mov  edi, pDest
    mov  ecx, count
    mov  eax, fillChar
    cld
    rep  stosb
    mov  BYTE PTR [edi], 0
    ret
StrFill ENDP

;---------------------------------------------------------------------
; StrToUpper
; Converts a-z to A-Z in place by clearing bit 5 (AND 11011111b).
; Other characters are left alone.
; Receives: pStr
; Returns:  nothing
;---------------------------------------------------------------------
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

;---------------------------------------------------------------------
; StrPadRight
; Appends spaces until the string is fieldWidth characters long.
; Does nothing if the string is already that long or longer.
; The buffer must hold at least fieldWidth + 1 bytes.
; Receives: pStr, fieldWidth
; Returns:  nothing
;---------------------------------------------------------------------
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
