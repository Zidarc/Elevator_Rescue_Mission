;=====================================================================
; Render.asm  (TEMPORARY plain-text version, Day 4)
; Just enough drawing to make the game playable. Day 5 replaces this
; file with the full layout from README section 11 (colours, HUD,
; elevator car, redraw only what changed).
;
;   DrawGameState   draws the whole building, the stats and statusMsg
;   SetStatus       copies a message into statusMsg
;=====================================================================
INCLUDE Irvine32.inc
INCLUDE Elevator.inc

LINE_WIDTH  = 60                        ; status line padding
ERASE_WIDTH = 20                        ; spaces after each line to erase old text

.data
txtRound    BYTE " ROUND ", 0
txtOf       BYTE "/", 0
txtEnergy   BYTE "   Energy ", 0
txtCredits  BYTE "   Credits ", 0
txtCap      BYTE "   Car ", 0
txtTtl      BYTE "  TTL ", 0
txtCar      BYTE " [===] ", 0
txtShaft    BYTE " |   | ", 0
txtLobby    BYTE " LOBBY", 0
txtKeys     BYTE " W up  S down  A action  X scan  B shop  Q quit", 0
txtPrompt   BYTE " > ", 0
lineBuffer  BYTE LINE_WIDTH + 1 DUP(0)

.code
;---------------------------------------------------------------------
; ClearToLineEnd  (private helper)
; Writes spaces up to LINE_WIDTH so a shorter line erases a longer
; one from the previous frame, then moves to the next line.
; Receives: nothing   Returns: nothing
;---------------------------------------------------------------------
ClearToLineEnd PROC USES eax edx
    INVOKE StrFill, ADDR lineBuffer, ERASE_WIDTH, ' '
    mov  edx, OFFSET lineBuffer
    call WriteString
    call Crlf
    ret
ClearToLineEnd ENDP

;---------------------------------------------------------------------
; DrawFloorLine  (private helper)
; One text line for a floor: number, car or shaft, contents, TTL.
; Receives: ECX = floor index
; Returns:  nothing
;---------------------------------------------------------------------
DrawFloorLine PROC USES eax edx esi
    mov  eax, ecx
    call WriteDec                       ; floor number

    mov  edx, OFFSET txtShaft
    cmp  ecx, elevatorFloor
    jne  drawShaft
    mov  edx, OFFSET txtCar
drawShaft:
    call WriteString

    cmp  ecx, LOBBY
    jne  upperFloor
    mov  edx, OFFSET txtLobby
    call WriteString
    jmp  floorLineDone

upperFloor:
    mov  esi, OFFSET floors
    mov  al, (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).floorFlags
    test al, FLAG_EXPIRED
    jnz  showExpired
    test al, FLAG_SCANNED
    jz   showUnknown
    test al, FLAG_ENERGY
    jnz  showEnergy
    test al, FLAG_CIVILIANS
    jz   floorLineDone                  ; scanned and empty
    test al, FLAG_CRITICAL
    mov  al, 'N'
    jz   showPeople
    mov  al, '!'
showPeople:
    call WriteChar
    mov  al, ' '
    call WriteChar
    movzx eax, (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).civilians
    call WriteDec
    jmp  showTtl

showUnknown:
    mov  al, '?'
    call WriteChar
    test (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).floorFlags, FLAG_CIVILIANS
    jz   floorLineDone
    mov  al, ' '
    call WriteChar
    call WriteChar
showTtl:
    mov  edx, OFFSET txtTtl
    call WriteString
    movzx eax, (FloorInfo PTR [esi + ecx * SIZEOF FloorInfo]).ttlLeft
    call WriteDec
    jmp  floorLineDone

showEnergy:
    mov  al, '+'
    call WriteChar
    jmp  floorLineDone

showExpired:
    mov  al, 'x'
    call WriteChar

floorLineDone:
    call ClearToLineEnd
    ret
DrawFloorLine ENDP

;---------------------------------------------------------------------
; DrawGameState
; Redraws the whole screen from the top-left corner (no Clrscr, so
; the picture does not flicker).
; Receives: nothing (reads globals)   Returns: nothing
;---------------------------------------------------------------------
DrawGameState PROC USES eax ecx edx
    mov  dh, 0
    mov  dl, 0
    call Gotoxy

    ; --- stats line ---
    mov  edx, OFFSET txtRound
    call WriteString
    mov  eax, roundNum
    call WriteDec
    mov  edx, OFFSET txtOf
    call WriteString
    mov  eax, MAX_ROUNDS
    call WriteDec
    mov  edx, OFFSET txtEnergy
    call WriteString
    mov  eax, energy
    call WriteDec
    mov  edx, OFFSET txtCredits
    call WriteString
    mov  eax, credits
    call WriteDec
    mov  edx, OFFSET txtCap
    call WriteString
    mov  eax, passengersNormal
    add  eax, passengersCritical
    call WriteDec
    mov  edx, OFFSET txtOf
    call WriteString
    mov  eax, capacity
    call WriteDec
    call ClearToLineEnd
    call Crlf

    ; --- floors, top to bottom ---
    mov  ecx, TOP_FLOOR
floorLoop:
    call DrawFloorLine
    dec  ecx
    jns  floorLoop                      ; stop after floor 0 (signed: -1 ends)

    call Crlf
    mov  edx, OFFSET txtKeys
    call WriteString
    call ClearToLineEnd
    mov  edx, OFFSET txtPrompt
    call WriteString
    mov  edx, OFFSET statusMsg
    call WriteString
    INVOKE StrFill, ADDR lineBuffer, LINE_WIDTH, ' '
    mov  edx, OFFSET lineBuffer
    call WriteString
    ret
DrawGameState ENDP

;---------------------------------------------------------------------
; SetStatus
; Copies a message into statusMsg for the next DrawGameState.
; Receives: pMsg = OFFSET of a null-terminated string
; Returns:  nothing
;---------------------------------------------------------------------
SetStatus PROC USES eax, pMsg:PTR BYTE
    INVOKE StrCopyN, ADDR statusMsg, pMsg, STATUS_SIZE
    ret
SetStatus ENDP

END
