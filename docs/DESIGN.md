# Elevator Rescue Simulator: Design Reference

Module and procedure reference for the final program. It lists what each procedure receives, what it returns and which registers it changes, followed by the memory layout and the main algorithms. For the rules and the build instructions, see the [README](../README.md).

**Conventions used by every procedure**

- Parameters are passed with `INVOKE` (stack, `STDCALL`), except where a register is named under *Receives*.
- A procedure changes **only** the registers listed under *Changes*. Everything else is saved with `USES` or `PUSH`/`POP`. "—" means no register changes. Win32 and some Irvine calls (`CloseFile`, `ReadKeyFlush`, `Beep`, `SetConsoleCursorInfo`) change EAX, ECX and EDX, so the procedures that call them save those registers.
- Logic modules (`Building`, `Elevator`, `Scan`, `Shop`, `CalcRoundScore`) never print. They report through `statusMsg`. The screens live in `Render`, `Menu`, `ShowSummary` and `Scoreboard`.
- Every decision is a `CMP`/`TEST` followed by a conditional jump. There are no `.IF`/`.WHILE` directives. Unsigned jumps (`JA`/`JB`/`JAE`/`JBE`) are used for counts, energy, TTL and addresses.
- The direction flag is clear (`CLD`) everywhere except during the backwards record copy in `InsertScoreSorted`, which sets it back with `CLD` straight after.

---

## 1. Modules

```
main.asm ─► Menu.asm ─┬─► GameLoop.asm ─┬─► Building  Elevator  Scan  Shop  Score
                      │                 └─► Render (all game drawing)
                      └─► Scoreboard.asm (table, file I/O)
            all of them ─► GameState.asm (globals) · StrUtil.asm (strings)
                           include/Elevator.inc (constants, STRUCTs, EXTERNDEF, PROTO)
```

| Module | Responsibility |
|---|---|
| `main.asm` | Seeds the random generator, sets the console title, loads the high scores, starts the menu |
| `GameState.asm` | Every global, the difficulty table and names, difficulty lookup, new-game reset |
| `StrUtil.asm` | String helpers on `SCASB` / `CMPSB` / `LODSB` / `STOSB`; number to text |
| `Menu.asm` | Main menu, How to Play |
| `Building.asm` | Difficulty selection, floor generation for a round |
| `Elevator.asm` | Moving, the action key, the one-second TTL tick |
| `Scan.asm` | The recursive scan (manual `EBP` frame) |
| `GameLoop.asm` | Real-time loop, key dispatcher, round-end rules, the rounds of a game, sound |
| `Render.asm` | Everything drawn during play, the shop screen, the intro, TTL colours |
| `Shop.asm` | Lobby purchases |
| `Score.asm` | Round score formula, end-of-game summary |
| `Scoreboard.asm` | Sorted top-10 table, name entry, `data\highscores.dat` |

---

## 2. Procedure reference

### GameState.asm

| Procedure | Receives | Returns | Changes |
|---|---|---|---|
| `GetDiffSetting` | `difficulty` | `ESI` = address of the current `DiffSetting` | ESI |
| `GetDiffName` | `level` | `EAX` = address of `"EASY"` / `"NORMAL"` / `"HARD"`, or `"?"` if out of range | EAX |
| `ResetGameState` | `difficulty` | New game: energy from the table; score, credits, counters and game totals 0; round 1; lobby; `START_CAPACITY` | — |

### StrUtil.asm

| Procedure | Receives | Returns | Changes |
|---|---|---|---|
| `StrLen` | `pStr` | `EAX` = length (`REPNE SCASB`) | EAX |
| `StrCopyN` | `pDest`, `pSrc`, `maxLen` = destination size | `EAX` = characters copied; always null-terminated if `maxLen` > 0 (`LODSB`/`STOSB`) | EAX |
| `StrEqual` | `pStr1`, `pStr2` | `EAX` = 1 equal / 0 (`REPE CMPSB`) | EAX |
| `StrFill` | `pDest`, `count`, `fillChar` | `count` characters + null (`REP STOSB`) | — |
| `StrToUpper` | `pStr` | In place; `a`–`z` only, by clearing bit 5 | — |
| `StrPadRight` | `pStr`, `fieldWidth` | Pads with spaces; never shortens | — |
| `StrFromUInt` | `value`, `pDest` (≥ `NUM_BUF_SIZE` bytes) | Decimal text; `EAX` = digit count. Repeated `DIV` by 10, with the digits reversed through the stack | EAX |

### Menu.asm

| Procedure | Receives | Returns | Changes |
|---|---|---|---|
| `RunMainMenu` | — | `DrawIntro`, then the menu until Quit | — |
| `ShowHowToPlay` | — | Rules screen, waits for a key | — |

### Building.asm

| Procedure | Receives | Returns | Changes |
|---|---|---|---|
| `SelectDifficulty` | keyboard `1`/`2`/`3` | `difficulty` | — |
| `RollFloorType` | `difficulty` | `EAX` = `FT_CRITICAL` (first `criticalPct` %), `FT_ENERGY` (next 20 %), `FT_EMPTY` (next 15 %), else `FT_NORMAL` | EAX |
| `GenerateFloor` | `floorIndex` | Fills `floors[floorIndex]`. Critical TTL = base `SHR 1`, then the round penalty (minimum 10). `ttlStart` = `ttlLeft`. The lobby is always empty | — |
| `InitializeGame` | `roundNum`, `difficulty` | New building; per-round counters cleared; lobby; rounds 2–3 add 40 energy (max 150) | — |

### Elevator.asm

| Procedure | Receives | Returns | Changes |
|---|---|---|---|
| `MoveElevator` | `direction` = +1 / −1 | `EAX` = 1 moved / 0 refused (top, lobby, energy < `MOVE_COST`). Reveals the floor it arrives on | EAX |
| `PerformAction` | globals | Lobby: deliver everyone (points, credits, rescued counters). Upper floor: reveal; energy pack; or pick up as many as capacity allows | — |
| `TickFloors` | globals | One second off every floor with civilians; at 0 they become casualties and `FLAG_EXPIRED` is set | — |

### Scan.asm

| Procedure | Receives | Returns | Changes |
|---|---|---|---|
| `ScanFloorsRecursive` | **stack**: `[EBP+8]` = floor, `[EBP+12]` = direction | `EAX` = civilians on this floor and beyond. Marks floors `FLAG_SCANNED`. Removes its own 8 bytes of parameters (`RET 8`) | EAX |
| `ScanAction` | `elevatorFloor`, `energy` | `EAX` = civilians in the building, or `0FFFFFFFFh` if refused; costs `SCAN_COST` | EAX |

### GameLoop.asm

| Procedure | Receives | Returns | Changes |
|---|---|---|---|
| `AnyCiviliansWaiting` | `floors` | `EAX` = 1 if any floor still has civilians (also used by the shop) | EAX |
| `CheckRoundOver` | globals | `EAX` = `roundOver` = 1 on quit; on energy < `MOVE_COST` (deliver at the lobby, otherwise passengers are lost); or when nobody is left anywhere | EAX |
| `HandleCommand` | `key` (either case) | `EAX` = 1 if it was W/S/A/X/B/Q. After the shop: `ClearGameScreen` and the TTL clock restarts, so the shop is a pause | EAX |
| `PlayEventSounds` | rescued / lost counters | A high beep when someone was delivered, a low one when someone was lost | — |
| `RunRound` | a building from `InitializeGame` | Returns when the round is over (see 4.1) | — |
| `RunGame` | — | Difficulty → rounds 1–3. After each round: beep, final `CalcRoundScore` added to `totalScore`, rescued / lost added to the game totals, `ShowRoundOver`. Q stops after the current round. Then `ShowSummary` and `RecordScore` | — |

### Render.asm

| Procedure | Receives | Returns | Changes |
|---|---|---|---|
| `DrawIntro` | — | Title screen, waits for a key | — |
| `DrawGameState` | globals | Frame, all 10 floor lines and the HUD, written in place | — |
| `DrawFloor` | `floorIndex` | One floor line: number, car, contents, coloured TTL | — |
| `DrawHud` | globals | Round, difficulty, energy (red below 20), credits, capacity, passengers, scores, rescued / lost, status line | — |
| `DrawShop` | globals | The shop screen | — |
| `ShowRoundOver` | `roundScore`, `totalScore` | Final frame + "ROUND OVER" line, flushes held keys, waits | — |
| `ClearGameScreen` | — | `Clrscr` and hides the cursor | — |
| `SetCursorVisible` | `visible` = 1 / 0 | Win32 `SetConsoleCursorInfo` | — |
| `GetTtlColor` | `ttlNow`, `ttlFull` | `EAX` = green if 2·now > full, yellow if 4·now ≥ full, else red | EAX |
| `SetStatus` | `pMsg` | Copies into `statusMsg` | — |
| `PaintPadded`, `PaintNumber`, `PaintText`, `HudLabel`, `DrawFrame` | see the source | Fixed-width fields, colours, frame | — |

### Shop.asm

| Procedure | Receives | Returns | Changes |
|---|---|---|---|
| `BuyItem` | `item` = `SHOP_ITEM_CAPACITY` / `ENERGY` / `FREEZE` | `EAX` = 1 bought / 0 refused. Checks, in order: lobby → valid item → not at maximum (freeze: someone waiting) → enough credits | EAX |
| `BuyInLobby` | keyboard | `EAX` = 1 the shop was open / 0 refused (not in the lobby; never waits for a key then) | EAX |
| `FreezeTimers` | — | +10 s on every floor with civilians | — |

### Score.asm

| Procedure | Receives | Returns | Changes |
|---|---|---|---|
| `CalcRoundScore` | `rescuedNormal`, `rescuedCritical`, `energy`, `casualties`, `difficulty` | `EAX` = `roundScore` = (N·100 + C·300 + E·2 − L·50) × multiplier, at least 0. Rebuilt every call, never added to | EAX |
| `ShowSummary` | game totals | End-of-game screen (does not wait) | — |

### Scoreboard.asm

| Procedure | Receives | Returns | Changes |
|---|---|---|---|
| `ClearScores` | — | Every record zeroed (`REP STOSB`), count 0 | — |
| `InsertScoreSorted` | `pName`, `scoreValue`, `levelValue`, `roundsValue` | `EAX` = rank 1–10, or 0 if it does not qualify (see 4.4) | EAX |
| `ScoreQualifies` | `EAX` = score | `EAX` = 1 if it would enter the table | EAX |
| `RecordScore` | `totalScore`, `difficulty`, `roundNum` | `EAX` = rank or 0. Name entry (empty → `PLAYER`, cut to 15, upper case), insert, save, show | EAX |
| `ShowScores` | the table | Table screen with `StrPadRight` columns; waits | — |
| `SaveScoresTo` / `SaveScores` | `pFile` / — | `EAX` = 1 saved / 0 failed | EAX |
| `LoadScoresFrom` / `LoadScores` | `pFile` / — | `EAX` = 1 loaded / 0 (table left empty) | EAX |
| `WriteCell` | `ESI` = text, `ECX` = width | One padded column | — |

---

## 3. Memory layout

### Structures (`include/Elevator.inc`)

```
FloorInfo  (8 bytes)            DiffSetting (20 bytes)        HighScore (24 bytes)
+0 civilians   BYTE             +0  ttlMin      DWORD         +0  playerName BYTE[16]
+1 floorFlags  BYTE             +4  ttlMax      DWORD         +16 points     DWORD
+2 ttlLeft     WORD             +8  startEnergy DWORD         +20 level      BYTE
+4 ttlStart    WORD             +12 multiplier  DWORD         +21 roundsDone BYTE
+6 floorPad    WORD             +16 criticalPct DWORD         +22 scorePad   WORD
```

8 bytes per floor lets `floors[ebx * SIZEOF FloorInfo]` use a hardware scale factor (scales can only be 1, 2, 4 or 8). The 24-byte record keeps `points` DWORD-aligned. The tests check all three sizes.

### Floor flags (one byte per floor)

| Bit | Constant | Meaning |
|---|---|---|
| 0 | `FLAG_CIVILIANS` | Civilians waiting |
| 1 | `FLAG_CRITICAL` | They are critical (300 points, half TTL) |
| 2 | `FLAG_ENERGY` | Energy pack here |
| 3 | `FLAG_EXPIRED` | Timer ran out |
| 4 | `FLAG_SCANNED` | Contents revealed |

Set with `OR`, cleared with `AND NOT`, tested with `TEST`.

### Globals (`GameState.asm`)

| Name | Type | Notes |
|---|---|---|
| `floors` | `FloorInfo` × 10 | Index 0 = lobby |
| `difficultyTable` | `DiffSetting` × 3 | Easy / Normal / Hard |
| `diffNames` | 3 × 8 bytes | Padded names |
| `highScores` | `HighScore` × 10 | Highest first; `highScoreCount` entries used |
| `difficulty`, `roundNum`, `elevatorFloor`, `energy`, `credits`, `capacity` | DWORD | |
| `passengersNormal`, `passengersCritical` | DWORD | On board |
| `rescuedNormal`, `rescuedCritical`, `casualties`, `roundScore` | DWORD | This round |
| `totalRescued`, `totalLost`, `totalScore` | DWORD | This game |
| `lastTickMs` | DWORD | `GetMseconds` of the last tick |
| `roundOver`, `quitRequested` | BYTE | 0 / 1 |
| `statusMsg` | BYTE × 64 | Message line |

### `data\highscores.dat` (244 bytes)

```
+0   DWORD      highScoreCount   (0..10)
+4   HighScore  x 10             (the whole table, 240 bytes)
```

The file is rejected (empty table) if it is missing, shorter than 244 bytes, or the count is above 10.

---

## 4. Algorithms

### 4.1 Real-time loop (`RunRound`)

```
lastTickMs = GetMseconds
loop:
    Delay 30 ms
    if ReadKey has a key:  HandleCommand, redraw = 1
    elapsed = GetMseconds - lastTickMs
        borrow (past midnight)  -> lastTickMs = now
        elapsed >= 1000         -> lastTickMs += 1000, TickFloors, redraw = 1
    if CheckRoundOver: return
    if redraw: PlayEventSounds, CalcRoundScore, DrawGameState
```

Adding exactly 1000 to `lastTickMs`, rather than setting it to "now", keeps the timers accurate even when a frame runs late.

### 4.2 Recursive scan (`ScanFloorsRecursive`)

```
push ebp / mov ebp, esp / push ebx ecx esi
if floor > TOP_FLOOR (unsigned; also catches -1): EAX = 0
else: mark scanned, EBX = civilians here
      push direction, push floor + direction, call self
      EAX += EBX
pop esi ecx ebx / mov esp, ebp / pop ebp / ret 8
```

Below the lobby, 0 − 1 becomes `0FFFFFFFFh`, so one unsigned `JA` stops the recursion at both ends. The deepest call is 11 levels. The tests check that `ESP`, `EBX`, `ECX` and `ESI` are unchanged afterwards.

### 4.3 Drawing without flicker

The screen is cleared only at the start of a round and after the shop. In between, `DrawGameState` moves the cursor with `Gotoxy` and rewrites every line in place. Each value goes into a fixed-width field padded with spaces, so a shorter value covers a longer one and nothing needs clearing.

### 4.4 Insertion into the score table (`InsertScoreSorted`)

```
i = 0
while i < count and table[i].points >= score: i++      ; ties go below
if i >= 10: return 0                                    ; not good enough
n = min(count, 9) - i                                   ; records to move
copy n * 24 bytes from &table[i] to &table[i+1]         ; STD + REP MOVSB from the
                                                        ; last byte: the blocks overlap
clear table[i] (REP STOSB), write name / points / level / rounds
if count < 10: count++
return i + 1
```

### 4.5 Score

```
positive = N*100 + C*300 + energy*2
penalty  = lost*50
score    = positive > penalty ? (positive - penalty) * multiplier : 0
```

The penalty is compared before subtracting, so unsigned arithmetic can't wrap below 0. During play `PerformAction` adds the raw delivery points so the HUD moves at once, and `CalcRoundScore` then rebuilds the value from the counters, so nothing is counted twice.

---

## 5. Tests

`build.bat test` links every module except `main.asm` with `tests/*.asm`. The runner's exit code is the number of failed checks.

| Suite | Checks | What it covers |
|---|---|---|
| StrUtil | 22 | Length, compare, copy and truncate, upper case, padding, fill, number to text |
| GameState | 21 | Structure sizes, scaled addressing, difficulty lookup, reset, names |
| Building | 24 | Roll range and mix, floor contents, TTL rules per level and round, lobby, round reset |
| Elevator | 72 | Moves and limits, EDX preserved, reveal on arrival, pick-up and capacity, energy pack, delivery, every tick case |
| Scan | 19 | Same total from 3 starting floors, flags, cost, refusal, recursion limits, stack and register balance |
| GameLoop | 28 | Every round-end path, every key, shop refused away from the lobby |
| Render | 8 | TTL colour thresholds |
| Score and Shop | 41 | README example (2660), multipliers, clamp at 0, each shop item: bought, short of credits, at maximum, outside the lobby |
| Scoreboard | 39 | Insert at each position, full table, ties, long names, save / load, missing and damaged files |
| **Total** | **274** | |

Checked by hand (they need a real console): menus, difficulty selection, real-time timing, every screen, the shop loop, name entry, sound.
