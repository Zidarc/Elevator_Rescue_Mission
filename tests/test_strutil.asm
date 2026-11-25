;=====================================================================
; test_strutil.asm  -  tests for src/StrUtil.asm
;=====================================================================
INCLUDE Irvine32.inc
INCLUDE Elevator.inc
INCLUDE TestFramework.inc

.data
sHello      BYTE "HELLO", 0
sHello2     BYTE "HELLO", 0
sHelp       BYTE "HELP", 0
sEmpty      BYTE 0
sEmpty2     BYTE 0
sMixed      BYTE "aLi 25k!", 0
sMixedUp    BYTE "ALI 25K!", 0
sZero       BYTE "0", 0
s12345      BYTE "12345", 0
sMaxDword   BYTE "4294967295", 0
buffer      BYTE 32 DUP(?)

.code
TestStrUtil PROC
    mSuite "StrUtil"

    ; --- StrLen ---
    INVOKE StrLen, ADDR sHello
    mAssertEq eax, 5, "StrLen of HELLO is 5"
    INVOKE StrLen, ADDR sEmpty
    mAssertEq eax, 0, "StrLen of an empty string is 0"

    ; --- StrEqual ---
    INVOKE StrEqual, ADDR sHello, ADDR sHello2
    mAssertEq eax, 1, "StrEqual: identical strings"
    INVOKE StrEqual, ADDR sHello, ADDR sHelp
    mAssertEq eax, 0, "StrEqual: different length"
    INVOKE StrEqual, ADDR sHelp, ADDR sMixed
    mAssertEq eax, 0, "StrEqual: different text"
    INVOKE StrEqual, ADDR sEmpty, ADDR sEmpty2
    mAssertEq eax, 1, "StrEqual: two empty strings"

    ; --- StrCopyN ---
    INVOKE StrCopyN, ADDR buffer, ADDR sHello, SIZEOF buffer
    mAssertEq eax, 5, "StrCopyN copies the whole string"
    INVOKE StrEqual, ADDR buffer, ADDR sHello
    mAssertEq eax, 1, "StrCopyN result equals the source"
    INVOKE StrCopyN, ADDR buffer, ADDR sHello, 4
    mAssertEq eax, 3, "StrCopyN truncates to maxLen - 1"
    INVOKE StrLen, ADDR buffer
    mAssertEq eax, 3, "StrCopyN truncated copy is null-terminated"
    INVOKE StrCopyN, ADDR buffer, ADDR sHello, 0
    mAssertEq eax, 0, "StrCopyN with maxLen 0 copies nothing"

    ; --- StrToUpper ---
    INVOKE StrCopyN, ADDR buffer, ADDR sMixed, SIZEOF buffer
    INVOKE StrToUpper, ADDR buffer
    INVOKE StrEqual, ADDR buffer, ADDR sMixedUp
    mAssertEq eax, 1, "StrToUpper changes only a-z"

    ; --- StrPadRight ---
    INVOKE StrCopyN, ADDR buffer, ADDR sHelp, SIZEOF buffer
    INVOKE StrPadRight, ADDR buffer, 8
    INVOKE StrLen, ADDR buffer
    mAssertEq eax, 8, "StrPadRight pads to the field width"
    movzx eax, buffer[4]
    mAssertEq eax, ' ', "StrPadRight pads with spaces"
    INVOKE StrPadRight, ADDR buffer, 2
    INVOKE StrLen, ADDR buffer
    mAssertEq eax, 8, "StrPadRight never shortens a string"

    ; --- StrFill ---
    INVOKE StrFill, ADDR buffer, 3, '*'
    INVOKE StrLen, ADDR buffer
    mAssertEq eax, 3, "StrFill writes count characters"
    movzx eax, buffer[2]
    mAssertEq eax, '*', "StrFill uses the fill character"

    INVOKE StrFromUInt, 0, ADDR buffer
    mAssertEq eax, 1, "StrFromUInt 0 has 1 digit"
    INVOKE StrEqual, ADDR buffer, ADDR sZero
    mAssertEq eax, 1, "StrFromUInt 0 is the text 0"
    INVOKE StrFromUInt, 12345, ADDR buffer
    INVOKE StrEqual, ADDR buffer, ADDR s12345
    mAssertEq eax, 1, "StrFromUInt 12345"
    INVOKE StrFromUInt, 0FFFFFFFFh, ADDR buffer
    mAssertEq eax, 10, "StrFromUInt largest DWORD has 10 digits"
    INVOKE StrEqual, ADDR buffer, ADDR sMaxDword
    mAssertEq eax, 1, "StrFromUInt 4294967295"
    ret
TestStrUtil ENDP

END
