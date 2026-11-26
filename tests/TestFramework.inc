mAssertEq MACRO actual:REQ, expected:REQ, desc:REQ
    LOCAL descStr
    .data
    descStr BYTE desc, 0
    .code
    INVOKE AssertEq, actual, expected, ADDR descStr
ENDM

mSuite MACRO suiteName:REQ
    LOCAL nameStr
    .data
    nameStr BYTE suiteName, 0
    .code
    INVOKE PrintSuite, ADDR nameStr
ENDM
