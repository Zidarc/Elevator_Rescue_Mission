INCLUDE Irvine32.inc
INCLUDE Elevator.inc
INCLUDE TestFramework.inc

SHOP_FLOOR_A = 3
SHOP_FLOOR_B = 6

.code
ResetScoreTestState PROC USES ecx esi
    mov  difficulty, DIFF_NORMAL
    mov  elevatorFloor, LOBBY
    mov  energy, 100
    mov  credits, 0
    mov  capacity, START_CAPACITY
    mov  passengersNormal, 0
    mov  passengersCritical, 0
    mov  rescuedNormal, 0
    mov  rescuedCritical, 0
    mov  casualties, 0
    mov  roundScore, 0
    mov  statusMsg, 0
    mov  esi, OFFSET floors
    mov  ecx, NUM_FLOORS
clearFloors:
    mov  (FloorInfo PTR [esi]).civilians, 0
    mov  (FloorInfo PTR [esi]).floorFlags, 0
    mov  (FloorInfo PTR [esi]).ttlLeft, 0
    mov  (FloorInfo PTR [esi]).ttlStart, 0
    add  esi, SIZEOF FloorInfo
    loop clearFloors
    ret
ResetScoreTestState ENDP

TestRoundScore PROC USES eax
    call ResetScoreTestState
    mov  rescuedNormal, 8
    mov  rescuedCritical, 2
    mov  casualties, 3
    mov  energy, 40
    call CalcRoundScore
    mAssertEq eax, 2660, "README example scores 2660"
    mAssertEq roundScore, 2660, "CalcRoundScore stores roundScore"

    mov  difficulty, DIFF_EASY
    call CalcRoundScore
    mAssertEq eax, 1330, "Easy multiplier x1"
    mov  difficulty, DIFF_HARD
    call CalcRoundScore
    mAssertEq eax, 3990, "Hard multiplier x3"

    mov  difficulty, DIFF_NORMAL
    mov  roundScore, 600
    call CalcRoundScore
    call CalcRoundScore
    mAssertEq eax, 2660, "calling it twice gives the same score"

    call ResetScoreTestState
    mov  rescuedNormal, 1
    mov  energy, 0
    mov  casualties, 10
    call CalcRoundScore
    mAssertEq eax, 0, "more penalty than points scores 0"

    call ResetScoreTestState
    mov  rescuedNormal, 1
    mov  energy, 0
    mov  casualties, 2
    call CalcRoundScore
    mAssertEq eax, 0, "penalty equal to points scores 0"

    call ResetScoreTestState
    mov  energy, 50
    call CalcRoundScore
    mAssertEq eax, 200, "50 energy on Normal is 200"

    call ResetScoreTestState
    ret
TestRoundScore ENDP

TestShopCapacity PROC USES eax
    call ResetScoreTestState
    mov  credits, SHOP_CAPACITY_COST
    INVOKE BuyItem, SHOP_ITEM_CAPACITY
    mAssertEq eax, 1, "capacity: bought with exactly enough credits"
    mAssertEq capacity, START_CAPACITY + SHOP_CAPACITY_GAIN, "capacity: +2"
    mAssertEq credits, 0, "capacity: 30 credits taken"

    call ResetScoreTestState
    mov  credits, SHOP_CAPACITY_COST - 1
    INVOKE BuyItem, SHOP_ITEM_CAPACITY
    mAssertEq eax, 0, "capacity: refused without enough credits"
    mAssertEq capacity, START_CAPACITY, "capacity: unchanged when refused"
    mAssertEq credits, SHOP_CAPACITY_COST - 1, "capacity: credits kept when refused"

    call ResetScoreTestState
    mov  capacity, MAX_CAPACITY
    mov  credits, 100
    INVOKE BuyItem, SHOP_ITEM_CAPACITY
    mAssertEq eax, 0, "capacity: refused at the maximum"
    mAssertEq credits, 100, "capacity: no credits taken at the maximum"

    call ResetScoreTestState
    mov  capacity, MAX_CAPACITY - 1
    mov  credits, 100
    INVOKE BuyItem, SHOP_ITEM_CAPACITY
    mAssertEq capacity, MAX_CAPACITY, "capacity: capped at MAX_CAPACITY"
    ret
TestShopCapacity ENDP

TestShopEnergy PROC USES eax
    call ResetScoreTestState
    mov  energy, 50
    mov  credits, 25
    INVOKE BuyItem, SHOP_ITEM_ENERGY
    mAssertEq eax, 1, "energy: bought"
    mAssertEq energy, 50 + SHOP_ENERGY_GAIN, "energy: +40"
    mAssertEq credits, 25 - SHOP_ENERGY_COST, "energy: 20 credits taken"

    call ResetScoreTestState
    mov  energy, 130
    mov  credits, 20
    INVOKE BuyItem, SHOP_ITEM_ENERGY
    mAssertEq energy, MAX_ENERGY, "energy: capped at MAX_ENERGY"

    call ResetScoreTestState
    mov  energy, MAX_ENERGY
    mov  credits, 100
    INVOKE BuyItem, SHOP_ITEM_ENERGY
    mAssertEq eax, 0, "energy: refused when already full"
    mAssertEq credits, 100, "energy: no credits taken when full"

    call ResetScoreTestState
    mov  energy, 50
    mov  credits, SHOP_ENERGY_COST - 1
    INVOKE BuyItem, SHOP_ITEM_ENERGY
    mAssertEq eax, 0, "energy: refused without enough credits"
    mAssertEq energy, 50, "energy: unchanged when refused"
    ret
TestShopEnergy ENDP

TestShopFreeze PROC USES eax
    call ResetScoreTestState
    mov  floors[SHOP_FLOOR_A * SIZEOF FloorInfo].civilians, 2
    mov  floors[SHOP_FLOOR_A * SIZEOF FloorInfo].floorFlags, FLAG_CIVILIANS
    mov  floors[SHOP_FLOOR_A * SIZEOF FloorInfo].ttlLeft, 7
    mov  floors[SHOP_FLOOR_B * SIZEOF FloorInfo].floorFlags, FLAG_ENERGY
    mov  credits, 60
    INVOKE BuyItem, SHOP_ITEM_FREEZE
    mAssertEq eax, 1, "freeze: bought"
    movzx eax, floors[SHOP_FLOOR_A * SIZEOF FloorInfo].ttlLeft
    mAssertEq eax, 7 + SHOP_FREEZE_GAIN, "freeze: waiting floor gets +10 s"
    movzx eax, floors[SHOP_FLOOR_B * SIZEOF FloorInfo].ttlLeft
    mAssertEq eax, 0, "freeze: floor without civilians unchanged"
    mAssertEq credits, 60 - SHOP_FREEZE_COST, "freeze: 50 credits taken"

    mov  credits, SHOP_FREEZE_COST - 1
    INVOKE BuyItem, SHOP_ITEM_FREEZE
    mAssertEq eax, 0, "freeze: refused without enough credits"
    movzx eax, floors[SHOP_FLOOR_A * SIZEOF FloorInfo].ttlLeft
    mAssertEq eax, 7 + SHOP_FREEZE_GAIN, "freeze: TTL unchanged when refused"

    call ResetScoreTestState
    mov  credits, 100
    INVOKE BuyItem, SHOP_ITEM_FREEZE
    mAssertEq eax, 0, "freeze: refused when nobody is waiting"
    mAssertEq credits, 100, "freeze: no credits wasted"
    ret
TestShopFreeze ENDP

TestShopRefusals PROC USES eax
    call ResetScoreTestState
    mov  elevatorFloor, SHOP_FLOOR_A
    mov  credits, 100
    INVOKE BuyItem, SHOP_ITEM_CAPACITY
    mAssertEq eax, 0, "capacity refused outside the lobby"
    INVOKE BuyItem, SHOP_ITEM_ENERGY
    mAssertEq eax, 0, "energy refused outside the lobby"
    INVOKE BuyItem, SHOP_ITEM_FREEZE
    mAssertEq eax, 0, "freeze refused outside the lobby"
    mAssertEq credits, 100, "nothing spent outside the lobby"
    call BuyInLobby
    mAssertEq eax, 0, "BuyInLobby refused outside the lobby"

    call ResetScoreTestState
    mov  credits, 100
    INVOKE BuyItem, 0
    mAssertEq eax, 0, "item 0 is not for sale"
    INVOKE BuyItem, SHOP_ITEM_FREEZE + 1
    mAssertEq eax, 0, "item 4 is not for sale"
    mAssertEq credits, 100, "unknown items cost nothing"

    call ResetScoreTestState
    ret
TestShopRefusals ENDP

TestScore PROC
    mSuite "Score and Shop"
    call TestRoundScore
    call TestShopCapacity
    call TestShopEnergy
    call TestShopFreeze
    call TestShopRefusals
    ret
TestScore ENDP

END
