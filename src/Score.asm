; Score.asm - calculates the round score and shows the game-over summary.
INCLUDE Irvine32.inc
INCLUDE Elevator.inc

.data
sumTitle    BYTE "  =========================================", 0Dh, 0Ah
            BYTE "                 GAME OVER", 0Dh, 0Ah
            BYTE "  =========================================", 0Dh, 0Ah, 0Dh, 0Ah, 0
sumQuit     BYTE "    You left the building early.", 0Dh, 0Ah, 0Dh, 0Ah, 0
sumLevel    BYTE "    Difficulty        ", 0
sumMultOpen BYTE "  (x", 0
sumMultEnd  BYTE ")", 0Dh, 0Ah, 0
sumRounds   BYTE "    Rounds played     ", 0
sumOf       BYTE " / ", 0
sumRescued  BYTE "    Civilians rescued ", 0
sumLost     BYTE "    Civilians lost    ", 0
sumTotal    BYTE "    TOTAL SCORE       ", 0

.code
; Round score formula (MUL for every multiplication):
;   (normal x 100 + critical x 300 + energy left x 2 - lost x 50) x multiplier
; Multiplier: Easy 1, Normal 2, Hard 3. The score never goes below 0.
; EAX = round score (also saved in roundScore).
CalcRoundScore PROC USES ebx ecx edx esi
    mov  eax, rescuedNormal
    mov  ebx, NORMAL_POINTS
    mul  ebx
    mov  ecx, eax                       ; ECX = normal x 100

    mov  eax, rescuedCritical
    mov  ebx, CRITICAL_POINTS
    mul  ebx
    add  ecx, eax                       ; + critical x 300

    mov  eax, energy
    mov  ebx, ENERGY_BONUS
    mul  ebx
    add  ecx, eax

    mov  eax, casualties
    mov  ebx, CASUALTY_PENALTY
    mul  ebx
    cmp  ecx, eax
    jbe  scoreIsZero                    ; penalty too big: score is 0
    sub  ecx, eax                       ; - lost x 50

    call GetDiffSetting
    mov  eax, ecx
    mul  (DiffSetting PTR [esi]).multiplier ; x difficulty multiplier
    jmp  storeScore

scoreIsZero:
    xor  eax, eax
storeScore:
    mov  roundScore, eax
    ret
CalcRoundScore ENDP

; Game-over screen: difficulty, rounds played, total rescued and lost,
; and the final total score.
ShowSummary PROC USES eax edx esi
    call Clrscr
    mov  eax, yellow + (black * 16)
    call SetTextColor
    mov  edx, OFFSET sumTitle
    call WriteString
    mov  eax, lightGray + (black * 16)
    call SetTextColor

    cmp  quitRequested, 0
    je   printLevel
    mov  edx, OFFSET sumQuit
    call WriteString

printLevel:
    mov  edx, OFFSET sumLevel
    call WriteString
    INVOKE GetDiffName, difficulty
    mov  edx, eax
    call WriteString
    mov  edx, OFFSET sumMultOpen
    call WriteString
    call GetDiffSetting
    mov  eax, (DiffSetting PTR [esi]).multiplier
    call WriteDec
    mov  edx, OFFSET sumMultEnd
    call WriteString

    mov  edx, OFFSET sumRounds
    call WriteString
    mov  eax, roundNum
    call WriteDec
    mov  edx, OFFSET sumOf
    call WriteString
    mov  eax, MAX_ROUNDS
    call WriteDec
    call Crlf

    mov  edx, OFFSET sumRescued
    call WriteString
    mov  eax, totalRescued
    call WriteDec
    call Crlf

    mov  edx, OFFSET sumLost
    call WriteString
    mov  eax, totalLost
    call WriteDec
    call Crlf
    call Crlf

    mov  eax, white + (black * 16)
    call SetTextColor
    mov  edx, OFFSET sumTotal
    call WriteString
    mov  eax, totalScore
    call WriteDec
    call Crlf
    call Crlf
    mov  eax, lightGray + (black * 16)
    call SetTextColor
    ret
ShowSummary ENDP

END
