.code
StrLen PROC USES ecx edi, pStr:PTR BYTE
    mov  edi, pStr
    xor  eax, eax
    mov  ecx, -1
    cld
    repne scasb
    not  ecx
    dec  ecx
    mov  eax, ecx
    ret
StrLen ENDP

StrCopyN PROC USES ecx esi edi, pDest:PTR BYTE, pSrc:PTR BYTE, maxLen:DWORD
    mov  edi, pDest
    mov  esi, pSrc
    mov  ecx, maxLen
    jecxz done
    dec  ecx
    cld
    jecxz terminate
copyLoop:
    lodsb
    test al, al
    jz   terminate
    stosb
    loop copyLoop
terminate:
    mov  BYTE PTR [edi], 0
done:
    mov  eax, edi
    sub  eax, pDest
    ret
StrCopyN ENDP

StrEqual PROC USES ecx esi edi, pStr1:PTR BYTE, pStr2:PTR BYTE
    INVOKE StrLen, pStr1
    mov  ecx, eax
    INVOKE StrLen, pStr2
    cmp  eax, ecx
    jne  notEqual                       ; different lengths

    inc  ecx
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

StrFill PROC USES eax ecx edi, pDest:PTR BYTE, count:DWORD, fillChar:DWORD
    mov  edi, pDest
    mov  ecx, count
    mov  eax, fillChar
    cld
    rep  stosb
    mov  BYTE PTR [edi], 0
    ret
StrFill ENDP

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
    and  al, 11011111b                  ; to uppercase
    mov  [esi], al
skip:
    inc  esi
    jmp  nextChar
finished:
    ret
StrToUpper ENDP

StrPadRight PROC USES eax ecx edi, pStr:PTR BYTE, fieldWidth:DWORD
    INVOKE StrLen, pStr
    mov  ecx, fieldWidth
    cmp  eax, ecx
    jae  finished                       ; already wide enough
    sub  ecx, eax                       ; spaces needed
    mov  edi, pStr
    add  edi, eax
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
