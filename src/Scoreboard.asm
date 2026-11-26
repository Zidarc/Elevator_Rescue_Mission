TABLE_BYTES  = MAX_SCORES * SIZEOF HighScore
NAME_INPUT   = 64
NAME_COLUMN  = NAME_SIZE + 2
LEVEL_COLUMN = DIFF_NAME_SIZE + 2

.data
scoreFile    BYTE "data\highscores.dat", 0
fileCount    DWORD 0
defaultName  BYTE "PLAYER", 0
nameInput    BYTE NAME_INPUT DUP(0)
nameBuffer   BYTE NAME_SIZE DUP(0)
cellBuffer   BYTE NAME_COLUMN + 1 DUP(0)

msgNewHigh   BYTE "  NEW HIGH SCORE!  Enter your name (max 15 letters): ", 0
msgNoHigh    BYTE "  Your score did not reach the top 10.", 0Dh, 0Ah, 0Dh, 0Ah, 0
msgZero      BYTE "  No points scored, so nothing to record.", 0Dh, 0Ah, 0Dh, 0Ah, 0
msgSaveFail  BYTE "  Could not save data\highscores.dat", 0Dh, 0Ah, 0

tblTitle     BYTE "  =========================================", 0Dh, 0Ah
             BYTE "             TOP 10 HIGH SCORES", 0Dh, 0Ah
             BYTE "  =========================================", 0Dh, 0Ah, 0Dh, 0Ah, 0
tblHeader    BYTE "  RANK  NAME              LEVEL     ROUNDS   SCORE", 0Dh, 0Ah
             BYTE "  ----  ----------------  --------  ------   ----------", 0Dh, 0Ah, 0
tblEmpty     BYTE "  No high scores yet. Play a game!", 0Dh, 0Ah, 0
tblIndent    BYTE "  ", 0
tblSpace     BYTE " ", 0
tblDot       BYTE ".   ", 0
tblRoundsGap BYTE "        ", 0

.code
ClearScores PROC USES eax ecx edi
    mov  edi, OFFSET highScores
    mov  ecx, TABLE_BYTES
    xor  eax, eax
    cld
    rep  stosb
    mov  highScoreCount, 0
    ret
ClearScores ENDP

SwapRecords PROC USES eax ebx ecx esi
    mov  ecx, SIZEOF HighScore
swapByte:
    mov  al, [esi]
    mov  bl, [esi + SIZEOF HighScore]
    mov  [esi], bl
    mov  [esi + SIZEOF HighScore], al
    inc  esi
    loop swapByte
    ret
SwapRecords ENDP

SortScores PROC USES eax ecx esi
    mov  ecx, highScoreCount
    cmp  ecx, 1
    jbe  sortDone
    dec  ecx                            ; passes = count - 1
outerLoop:
    push ecx
    mov  esi, OFFSET highScores
innerLoop:
    mov  eax, (HighScore PTR [esi]).points
    cmp  eax, (HighScore PTR [esi + SIZEOF HighScore]).points
    jae  noSwap
    call SwapRecords
noSwap:
    add  esi, SIZEOF HighScore
    loop innerLoop
    pop  ecx
    loop outerLoop
sortDone:
    ret
SortScores ENDP

AddHighScore PROC USES ebx ecx edx esi edi,
        pName:PTR BYTE, scoreValue:DWORD, levelValue:DWORD, roundsValue:DWORD
    mov  eax, highScoreCount            ; EAX = first empty slot
    cmp  eax, MAX_SCORES
    jb   haveSlot                       ; table not full yet
    mov  esi, OFFSET highScores + (MAX_SCORES - 1) * SIZEOF HighScore
    mov  ebx, (HighScore PTR [esi]).points
    cmp  scoreValue, ebx
    jbe  notAdded                       ; not better than the 10th score
    mov  eax, MAX_SCORES - 1            ; replace the 10th record
    dec  highScoreCount
haveSlot:
    inc  highScoreCount

    mov  ebx, SIZEOF HighScore
    mul  ebx
    mov  edi, OFFSET highScores
    add  edi, eax

    ; fill in the record
    INVOKE StrFill, edi, SIZEOF HighScore - 1, 0
    INVOKE StrCopyN, edi, pName, NAME_SIZE
    mov  eax, scoreValue
    mov  (HighScore PTR [edi]).points, eax
    mov  eax, levelValue
    mov  (HighScore PTR [edi]).level, al
    mov  eax, roundsValue
    mov  (HighScore PTR [edi]).roundsDone, al

    call SortScores

    xor  eax, eax
    mov  ecx, highScoreCount
    mov  esi, OFFSET highScores
countRank:
    mov  ebx, (HighScore PTR [esi]).points
    cmp  ebx, scoreValue
    jb   nextRecord
    inc  eax
nextRecord:
    add  esi, SIZEOF HighScore
    loop countRank
    ret

notAdded:
    xor  eax, eax
    ret
AddHighScore ENDP

ScoreQualifies PROC USES esi
    test eax, eax
    jz   notQualified
    cmp  highScoreCount, MAX_SCORES
    jb   qualified
    mov  esi, OFFSET highScores + (MAX_SCORES - 1) * SIZEOF HighScore
    cmp  eax, (HighScore PTR [esi]).points
    ja   qualified
notQualified:
    xor  eax, eax
    ret
qualified:
    mov  eax, 1
    ret
ScoreQualifies ENDP

SaveScoresTo PROC USES ebx ecx edx esi, pFile:PTR BYTE
    mov  edx, pFile
    call CreateOutputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   saveFailed
    mov  ebx, eax

    mov  edx, OFFSET highScoreCount
    mov  ecx, SIZEOF fileCount
    call WriteToFile
    mov  eax, ebx
    mov  edx, OFFSET highScores
    mov  ecx, TABLE_BYTES
    call WriteToFile
    mov  esi, eax
    mov  eax, ebx
    call CloseFile

    xor  eax, eax
    cmp  esi, TABLE_BYTES
    jne  saveDone
    inc  eax
saveDone:
    ret
saveFailed:
    xor  eax, eax
    ret
SaveScoresTo ENDP

LoadScoresFrom PROC USES ebx ecx edx esi, pFile:PTR BYTE
    call ClearScores
    mov  edx, pFile
    call OpenInputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   loadFailed
    mov  ebx, eax

    mov  edx, OFFSET fileCount
    mov  ecx, SIZEOF fileCount
    call ReadFromFile
    mov  eax, ebx
    mov  edx, OFFSET highScores
    mov  ecx, TABLE_BYTES
    call ReadFromFile
    mov  esi, eax
    mov  eax, ebx
    call CloseFile

    cmp  esi, TABLE_BYTES
    jne  loadBad
    cmp  fileCount, MAX_SCORES
    ja   loadBad

    mov  esi, OFFSET highScores
    mov  ecx, MAX_SCORES
terminateNames:
    mov  BYTE PTR [esi + NAME_SIZE - 1], 0
    add  esi, SIZEOF HighScore
    loop terminateNames

    mov  eax, fileCount
    mov  highScoreCount, eax
    mov  eax, 1
    ret

loadBad:
    call ClearScores
loadFailed:
    xor  eax, eax
    ret
LoadScoresFrom ENDP

SaveScores PROC
    INVOKE SaveScoresTo, ADDR scoreFile
    ret
SaveScores ENDP

LoadScores PROC
    INVOKE LoadScoresFrom, ADDR scoreFile
    ret
LoadScores ENDP

WriteCell PROC USES eax edx
    INVOKE StrCopyN, ADDR cellBuffer, esi, SIZEOF cellBuffer
    INVOKE StrPadRight, ADDR cellBuffer, ecx
    mov  edx, OFFSET cellBuffer
    call WriteString
    ret
WriteCell ENDP

ShowScores PROC USES eax ebx ecx edx esi
    call Clrscr
    mov  eax, yellow + (black * 16)
    call SetTextColor
    mov  edx, OFFSET tblTitle
    call WriteString
    mov  eax, lightGray + (black * 16)
    call SetTextColor

    cmp  highScoreCount, 0
    jne  printTable
    mov  edx, OFFSET tblEmpty
    call WriteString
    jmp  scoresDone

printTable:
    mov  edx, OFFSET tblHeader
    call WriteString
    mov  esi, OFFSET highScores
    xor  ebx, ebx
rowLoop:
    cmp  ebx, highScoreCount
    jae  scoresDone

    mov  edx, OFFSET tblIndent
    call WriteString
    mov  eax, ebx                       ; rank = index + 1
    inc  eax
    cmp  eax, 10
    jae  wideRank
    mov  edx, OFFSET tblSpace
    call WriteString
wideRank:
    call WriteDec
    mov  edx, OFFSET tblDot
    call WriteString

    push esi
    mov  ecx, NAME_COLUMN
    call WriteCell
    movzx eax, (HighScore PTR [esi]).level
    INVOKE GetDiffName, eax
    mov  esi, eax
    mov  ecx, LEVEL_COLUMN
    call WriteCell
    pop  esi

    movzx eax, (HighScore PTR [esi]).roundsDone
    call WriteDec
    mov  edx, OFFSET tblRoundsGap
    call WriteString
    mov  eax, (HighScore PTR [esi]).points
    call WriteDec
    call Crlf

    inc  ebx
    add  esi, SIZEOF HighScore
    jmp  rowLoop

scoresDone:
    call Crlf
    call WaitMsg
    ret
ShowScores ENDP

RecordScore PROC USES ebx ecx edx
    mov  edx, OFFSET msgZero
    mov  eax, totalScore
    test eax, eax
    jz   waitAndLeave
    mov  edx, OFFSET msgNoHigh
    call ScoreQualifies
    test eax, eax
    jz   waitAndLeave

    call ReadKeyFlush
    mov  eax, lightGreen + (black * 16)
    call SetTextColor
    mov  edx, OFFSET msgNewHigh
    call WriteString
    mov  eax, white + (black * 16)
    call SetTextColor
    mov  edx, OFFSET nameInput
    mov  ecx, SIZEOF nameInput
    call ReadString
    mov  eax, lightGray + (black * 16)
    call SetTextColor

    INVOKE StrCopyN, ADDR nameBuffer, ADDR nameInput, NAME_SIZE
    test eax, eax
    jnz  haveName
    INVOKE StrCopyN, ADDR nameBuffer, ADDR defaultName, NAME_SIZE
haveName:
    INVOKE StrToUpper, ADDR nameBuffer
    INVOKE AddHighScore, ADDR nameBuffer, totalScore, difficulty, roundNum
    mov  ebx, eax

    call SaveScores
    test eax, eax
    jnz  showTable
    mov  edx, OFFSET msgSaveFail
    call WriteString
    call WaitMsg
showTable:
    call ShowScores
    mov  eax, ebx
    ret

waitAndLeave:
    call WriteString
    call WaitMsg
    xor  eax, eax
    ret
RecordScore ENDP
