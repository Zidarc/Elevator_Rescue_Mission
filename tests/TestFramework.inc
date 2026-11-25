; TestFramework.inc - macros used by the test files.
; Example:
;     mSuite    "StrUtil"
;     INVOKE    StrLen, ADDR sHello
;     mAssertEq eax, 5, "StrLen of HELLO is 5"
; Do not use commas inside the description text.
IFNDEF TEST_FRAMEWORK_INC
TEST_FRAMEWORK_INC EQU 1

EXTERNDEF testsPassed:DWORD
EXTERNDEF testsFailed:DWORD

AssertEq   PROTO, actual:DWORD, expected:DWORD, pDesc:PTR BYTE
PrintSuite PROTO, pName:PTR BYTE
TPrint     PROTO, pStr:PTR BYTE         ; prints even when output is redirected
TPrintInt  PROTO, value:SDWORD

; mAssertEq actual, expected, "text": checks that actual = expected.
; The macro puts the text in .data (LOCAL gives it a unique label)
; and calls AssertEq.
mAssertEq MACRO actual:REQ, expected:REQ, desc:REQ
    LOCAL descStr
    .data
    descStr BYTE desc, 0
    .code
    INVOKE AssertEq, actual, expected, ADDR descStr
ENDM

; mSuite "name": prints a heading for a group of tests.
mSuite MACRO suiteName:REQ
    LOCAL nameStr
    .data
    nameStr BYTE suiteName, 0
    .code
    INVOKE PrintSuite, ADDR nameStr
ENDM

ENDIF ; TEST_FRAMEWORK_INC
