TTL_GREEN  = lightGreen + (black * 16)
TTL_YELLOW = yellow + (black * 16)
TTL_RED    = lightRed + (black * 16)

.code
TestRender PROC USES eax
    mSuite "Render"
    INVOKE GetTtlColor, 40, 40
    mAssertEq eax, TTL_GREEN, "full timer is green"
    INVOKE GetTtlColor, 21, 40
    mAssertEq eax, TTL_GREEN, "just over 50 percent is green"
    INVOKE GetTtlColor, 20, 40
    mAssertEq eax, TTL_YELLOW, "exactly 50 percent is yellow"
    INVOKE GetTtlColor, 10, 40
    mAssertEq eax, TTL_YELLOW, "exactly 25 percent is yellow"
    INVOKE GetTtlColor, 9, 40
    mAssertEq eax, TTL_RED, "under 25 percent is red"
    INVOKE GetTtlColor, 0, 40
    mAssertEq eax, TTL_RED, "zero is red"
    INVOKE GetTtlColor, 50, 40
    mAssertEq eax, TTL_GREEN, "above the start after a time freeze is green"
    INVOKE GetTtlColor, 5, 0
    mAssertEq eax, TTL_GREEN, "no starting value is green"
    ret
TestRender ENDP
