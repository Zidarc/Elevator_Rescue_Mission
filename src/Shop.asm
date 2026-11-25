; Shop.asm - the shop in the lobby (B key). Credits come from
; rescuing people and are spent here on upgrades.
INCLUDE Irvine32.inc
INCLUDE Elevator.inc

KEY_ESCAPE = 1Bh

.data
msgNotLobby     BYTE "The shop is only open in the lobby.", 0
msgNoCredits    BYTE "Not enough credits.", 0
msgCapMax       BYTE "Capacity is already at the maximum.", 0
msgEnergyMax    BYTE "Energy is already full.", 0
msgNobodyWaits  BYTE "Nobody is waiting: a time freeze would be wasted.", 0
msgBadItem      BYTE "Unknown shop item.", 0
msgBoughtCap    BYTE "Bought: +2 capacity.", 0
msgBoughtEnergy BYTE "Bought: +40 energy.", 0
msgBoughtFreeze BYTE "Bought: +10 s on every waiting floor.", 0
msgShopWelcome  BYTE "Welcome to the shop. Press 1, 2 or 3 to buy, B to leave.", 0
msgShopClosed   BYTE "Shop closed. Timers are running again.", 0

.code
; Time freeze: adds 10 seconds to every floor that still has people waiting.
FreezeTimers PROC USES ecx esi
    mov  esi, OFFSET floors
    add  esi, SIZEOF FloorInfo
    mov  ecx, NUM_FLOORS - 1
freezeLoop:
    test (FloorInfo PTR [esi]).floorFlags, FLAG_CIVILIANS
    jz   freezeNext
    add  (FloorInfo PTR [esi]).ttlLeft, SHOP_FREEZE_GAIN
freezeNext:
    add  esi, SIZEOF FloorInfo
    loop freezeLoop
    ret
FreezeTimers ENDP

; Buys one item if the elevator is in the lobby and there are enough credits:
;   1 capacity +2 (30 credits)   2 energy +40 (20)   3 time freeze +10 s (50)
; Capacity and energy can not go past their maximum, and a freeze is
; refused if nobody is waiting.
; EAX = 1 if bought, 0 if refused (the reason goes into statusMsg).
BuyItem PROC USES ebx, item:DWORD
    mov  ebx, OFFSET msgNotLobby
    cmp  elevatorFloor, LOBBY
    jne  refused

    mov  eax, item
    cmp  eax, SHOP_ITEM_CAPACITY
    je   buyCapacity
    cmp  eax, SHOP_ITEM_ENERGY
    je   buyEnergy
    cmp  eax, SHOP_ITEM_FREEZE
    je   buyFreeze
    mov  ebx, OFFSET msgBadItem
    jmp  refused

buyCapacity:
    mov  ebx, OFFSET msgCapMax
    cmp  capacity, MAX_CAPACITY
    jae  refused
    mov  ebx, OFFSET msgNoCredits
    cmp  credits, SHOP_CAPACITY_COST
    jb   refused
    sub  credits, SHOP_CAPACITY_COST
    add  capacity, SHOP_CAPACITY_GAIN
    cmp  capacity, MAX_CAPACITY
    jbe  capacityDone
    mov  capacity, MAX_CAPACITY
capacityDone:
    mov  ebx, OFFSET msgBoughtCap
    jmp  bought

buyEnergy:
    mov  ebx, OFFSET msgEnergyMax
    cmp  energy, MAX_ENERGY
    jae  refused
    mov  ebx, OFFSET msgNoCredits
    cmp  credits, SHOP_ENERGY_COST
    jb   refused
    sub  credits, SHOP_ENERGY_COST
    add  energy, SHOP_ENERGY_GAIN
    cmp  energy, MAX_ENERGY
    jbe  energyDone
    mov  energy, MAX_ENERGY
energyDone:
    mov  ebx, OFFSET msgBoughtEnergy
    jmp  bought

buyFreeze:
    mov  ebx, OFFSET msgNobodyWaits
    call AnyCiviliansWaiting
    test eax, eax
    jz   refused
    mov  ebx, OFFSET msgNoCredits
    cmp  credits, SHOP_FREEZE_COST
    jb   refused
    sub  credits, SHOP_FREEZE_COST
    call FreezeTimers
    mov  ebx, OFFSET msgBoughtFreeze

bought:
    INVOKE SetStatus, ebx
    mov  eax, 1
    ret

refused:
    INVOKE SetStatus, ebx
    xor  eax, eax
    ret
BuyItem ENDP

; The shop screen. Keys 1, 2, 3 buy an item, B or Esc leaves.
; Only opens in the lobby. While the shop is open the game loop is not
; running, so the timers are paused.
; EAX = 1 if the shop was opened, 0 if refused (not in the lobby).
BuyInLobby PROC
    cmp  elevatorFloor, LOBBY
    je   openShop
    INVOKE SetStatus, ADDR msgNotLobby
    xor  eax, eax
    ret

openShop:
    INVOKE SetStatus, ADDR msgShopWelcome
shopLoop:
    call DrawShop                       ; redraw the shop after every key
    call ReadChar
    cmp  al, '1'
    jb   checkLeave
    cmp  al, '3'
    ja   checkLeave
    sub  al, '0'                        ; key '1'..'3' -> item number 1..3
    movzx eax, al
    INVOKE BuyItem, eax
    jmp  shopLoop

checkLeave:
    cmp  al, 'b'
    je   leaveShop
    cmp  al, 'B'
    je   leaveShop
    cmp  al, KEY_ESCAPE
    jne  shopLoop

leaveShop:
    INVOKE SetStatus, ADDR msgShopClosed
    mov  eax, 1
    ret
BuyInLobby ENDP

END
