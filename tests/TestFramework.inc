;=====================================================================
; TestFramework.inc
; A tiny assertion framework for the test runner (no external tools).
;
; Usage inside a test procedure:
;     mSuite    "StrUtil"
;     INVOKE    StrLen, ADDR sHello
;     mAssertEq eax, 5, "StrLen of HELLO is 5"
;
; Do not put commas inside the description string.
;=====================================================================
IFNDEF TEST_FRAMEWORK_INC
TEST_FRAMEWORK_INC EQU 1

EXTERNDEF testsPassed:DWORD
EXTERNDEF testsFailed:DWORD

AssertEq   PROTO, actual:DWORD, expected:DWORD, pDesc:PTR BYTE
PrintSuite PROTO, pName:PTR BYTE
TPrint     PROTO, pStr:PTR BYTE         ; prints even when output is redirected
TPrintInt  PROTO, value:SDWORD

;---------------------------------------------------------------------
; mAssertEq actual, expected, "description"
; actual and expected may be registers, memory DWORDs or constants.
; Preserves all registers and flags-independent state.
;---------------------------------------------------------------------
mAssertEq MACRO actual:REQ, expected:REQ, desc:REQ
    LOCAL descStr
    .data
    descStr BYTE desc, 0
    .code
    INVOKE AssertEq, actual, expected, ADDR descStr
ENDM

;---------------------------------------------------------------------
; mSuite "name"  -  prints a heading for a group of tests
;---------------------------------------------------------------------
mSuite MACRO suiteName:REQ
    LOCAL nameStr
    .data
    nameStr BYTE suiteName, 0
    .code
    INVOKE PrintSuite, ADDR nameStr
ENDM

ENDIF ; TEST_FRAMEWORK_INC
