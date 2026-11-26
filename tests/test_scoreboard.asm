; test_scoreboard.asm - tests for the high-score table and the file.

.data
tsFile      BYTE "build\test_scores.dat", 0
tsBadFile   BYTE "build\test_scores_bad.dat", 0
tsMissing   BYTE "build\no_such_scores_file.dat", 0
tsNameA     BYTE "ALICE", 0
tsNameB     BYTE "BOB", 0
tsNameC     BYTE "CARA", 0
tsNameD     BYTE "DAN", 0
tsLongName  BYTE "ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0
tsJunk      BYTE "this is not a score file at all", 0

.code
; Fills the table with 10 scores.
FillTenScores PROC USES eax ecx
    call ClearScores
    mov  ecx, 1000
fillLoop:
    INVOKE AddHighScore, ADDR tsNameB, ecx, DIFF_NORMAL, 1
    sub  ecx, 100
    jnz  fillLoop
    ret
FillTenScores ENDP

; New scores go to the right place and whole records move with their names.
TestInsertPositions PROC USES eax
    call ClearScores
    INVOKE AddHighScore, ADDR tsNameA, 500, DIFF_EASY, 3
    mAssertEq eax, 1, "first score goes to rank 1"
    mAssertEq highScoreCount, 1, "count is 1"
    mAssertEq highScores[0].points, 500, "points stored"
    movzx eax, highScores[0].level
    mAssertEq eax, DIFF_EASY, "level stored"
    movzx eax, highScores[0].roundsDone
    mAssertEq eax, 3, "rounds stored"
    INVOKE StrEqual, ADDR highScores[0].playerName, ADDR tsNameA
    mAssertEq eax, 1, "name stored"

    INVOKE AddHighScore, ADDR tsNameB, 900, DIFF_HARD, 2
    mAssertEq eax, 1, "higher score goes to the top"
    mAssertEq highScores[0].points, 900, "top is now 900"
    mAssertEq highScores[1 * SIZEOF HighScore].points, 500, "old top moved down"
    INVOKE StrEqual, ADDR highScores[1 * SIZEOF HighScore].playerName, ADDR tsNameA
    mAssertEq eax, 1, "whole record moved with its name"

    INVOKE AddHighScore, ADDR tsNameC, 700, DIFF_NORMAL, 3
    mAssertEq eax, 2, "middle score goes to rank 2"
    mAssertEq highScores[2 * SIZEOF HighScore].points, 500, "lower score pushed to rank 3"

    INVOKE AddHighScore, ADDR tsNameD, 100, DIFF_NORMAL, 1
    mAssertEq eax, 4, "lowest score goes to the bottom"
    mAssertEq highScoreCount, 4, "count is 4"
    ret
TestInsertPositions ENDP

; Full table: low scores are rejected, a new best pushes out the 10th,
; equal scores go below, long names are cut to 15 letters.
TestInsertFullTable PROC USES eax
    call FillTenScores
    mAssertEq highScoreCount, MAX_SCORES, "table holds 10"

    INVOKE AddHighScore, ADDR tsNameA, 50, DIFF_NORMAL, 1
    mAssertEq eax, 0, "11th score lower than all 10 is rejected"
    mAssertEq highScoreCount, MAX_SCORES, "count stays 10"
    mAssertEq highScores[9 * SIZEOF HighScore].points, 100, "last entry unchanged"

    INVOKE AddHighScore, ADDR tsNameA, 100, DIFF_NORMAL, 1
    mAssertEq eax, 0, "a tie with the 10th entry does not qualify"

    INVOKE AddHighScore, ADDR tsNameA, 2000, DIFF_NORMAL, 1
    mAssertEq eax, 1, "new best into a full table is rank 1"
    mAssertEq highScoreCount, MAX_SCORES, "count still 10"
    mAssertEq highScores[1 * SIZEOF HighScore].points, 1000, "others moved down one"
    mAssertEq highScores[9 * SIZEOF HighScore].points, 200, "old 10th entry dropped off"

    call ClearScores
    INVOKE AddHighScore, ADDR tsNameA, 500, DIFF_NORMAL, 1
    INVOKE AddHighScore, ADDR tsNameB, 500, DIFF_NORMAL, 1
    mAssertEq eax, 2, "equal score goes below the existing one"
    INVOKE StrEqual, ADDR highScores[0].playerName, ADDR tsNameA
    mAssertEq eax, 1, "the older equal score stays on top"

    call ClearScores
    INVOKE AddHighScore, ADDR tsLongName, 10, DIFF_NORMAL, 1
    INVOKE StrLen, ADDR highScores[0].playerName
    mAssertEq eax, NAME_SIZE - 1, "long names are cut to 15 characters"
    ret
TestInsertFullTable ENDP

; Save then load gives the same table; a missing or damaged file gives an empty table.
TestScoreFile PROC USES eax ebx ecx edx
    call FillTenScores
    INVOKE AddHighScore, ADDR tsNameC, 950, DIFF_HARD, 3
    INVOKE SaveScoresTo, ADDR tsFile
    mAssertEq eax, 1, "save succeeds"

    call ClearScores
    mAssertEq highScoreCount, 0, "table cleared"
    INVOKE LoadScoresFrom, ADDR tsFile
    mAssertEq eax, 1, "load succeeds"
    mAssertEq highScoreCount, MAX_SCORES, "same count after load"
    mAssertEq highScores[0].points, 1000, "same top score after load"
    mAssertEq highScores[1 * SIZEOF HighScore].points, 950, "same second score after load"
    movzx eax, highScores[1 * SIZEOF HighScore].level
    mAssertEq eax, DIFF_HARD, "level survives the file"
    INVOKE StrEqual, ADDR highScores[1 * SIZEOF HighScore].playerName, ADDR tsNameC
    mAssertEq eax, 1, "name survives the file"
    mAssertEq highScores[9 * SIZEOF HighScore].points, 200, "same last score after load"

    INVOKE LoadScoresFrom, ADDR tsMissing
    mAssertEq eax, 0, "missing file is reported"
    mAssertEq highScoreCount, 0, "missing file gives an empty table"

    mov  edx, OFFSET tsBadFile
    call CreateOutputFile
    mov  ebx, eax
    mov  edx, OFFSET tsJunk
    mov  ecx, SIZEOF tsJunk
    call WriteToFile
    mov  eax, ebx
    call CloseFile
    call FillTenScores
    INVOKE LoadScoresFrom, ADDR tsBadFile
    mAssertEq eax, 0, "damaged file is rejected"
    mAssertEq highScoreCount, 0, "damaged file gives an empty table"

    call ClearScores
    ret
TestScoreFile ENDP

; Runs all Scoreboard tests.
TestScoreboard PROC
    mSuite "Scoreboard"
    call TestInsertPositions
    call TestInsertFullTable
    call TestScoreFile
    ret
TestScoreboard ENDP
