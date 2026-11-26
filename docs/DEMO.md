# Elevator Rescue Simulator: Demo Script

This is the final demonstration from README Section 18, as a script to rehearse. It takes about **12 minutes**. Each step says what to do, what the audience should see, and what to say.

## Before the demo

1. Open a terminal in the project root (VS Code terminal or Command Prompt).
2. **For an empty high-score table at the start**, delete `data\highscores.dat`. Keep the `data` folder.
3. Run `build.bat clean`, so the build happens from scratch in front of the audience.
4. Make the console window at least **80 × 25**, and turn the sound on.
5. Open these files in the editor, ready for step 13: `src\Constants.inc`, `src\Scan.asm`, `src\Scoreboard.asm`, `src\StrUtil.asm`.

Suggested speakers (each one presents the modules they built, following the README schedule):

| Part | Steps | Speaker |
|---|---|---|
| Build, tests, menus | 1–3 | Ali Hussain |
| Scan, elevator, timers | 4–8 | M. Abbas / Ali Hussain |
| Shop, score, high scores | 9–12 | M. Abbas / Ali Hussain |
| Code tour, course topics | 13–14 | All three |

---

## Script

### 1. Automated tests (1 min)

**Do:** `build.bat test`
**See:** nine suites in green, ending with `Passed: 274   Failed: 0` and `ALL TESTS PASSED`.
**Say:** "The test runner is written in assembly too. `mAssertEq` is a macro with a `LOCAL` label, and the runner's exit code is the number of failures, which `build.bat` checks."

### 2. Intro and How to Play (1 min)

**Do:** `build.bat run`. Press any key on the title screen, then `3`.
**See:** the title screen, the menu, the rules page.

### 3. Start a game on Normal (30 s)

**Do:** `1` (New Game), then `2` (Normal).
**See:** the building. Unscanned floors show `?  ?`, TTLs **count down every second**, the car `[===]` is at the lobby, and the stats panel is on the right.
**Say:** "This is a real-time loop. `ReadKey` checks the keyboard without waiting, and `GetMseconds` ticks every 1000 ms."

### 4. Scan (1 min)

**Do:** `X`
**See:** every floor revealed (`N`, `!`, `+`, empty), energy −5, and the status line: *Scan complete: n civilians waiting.*
**Say:** "`ScanFloorsRecursive` builds its own `EBP` stack frame, calls itself once per floor, and removes its parameters with `RET 8`. One unsigned `JA` stops it at both ends of the building."

### 5. Critical civilians and capacity (1 min)

**Do:** `W` up to a magenta `!` floor, then `A`. If possible, also pick up from an `N` floor with more people than free seats.
**See:** the Passengers line (`N:` / `!:`) goes up. Capacity stops at 4. A floor keeps the civilians who didn't fit.

### 6. Energy pack (30 s)

**Do:** go to a cyan `+` floor and press `A`.
**See:** energy +25 (never above 150). The `+` disappears.

### 7. A timer runs out (1 min)

**Do:** ignore one floor (on Normal, choose the one with the lowest TTL).
**See:** its TTL goes **green → yellow (≤ 50 %) → red (< 25 %)**, then turns into a red `x`. A low beep sounds and Lost goes up.
**Say:** "`GetTtlColor` uses shifts instead of division: `2·now > start` is green, `4·now ≥ start` is yellow."

### 8. Delivery (30 s)

**Do:** `S` down to floor 0, then `A`.
**See:** a high beep, *Passengers delivered to the lobby!*, and Round score and Credits go up (10 per normal, 25 per critical civilian).

> You need **30 credits** for step 9. Three normal civilians, or two critical ones, are enough.

### 9. Shop (1 min)

**Do:** `B` in the lobby. Press `1` (capacity), try `3` with too few credits, then press `B` to leave.
**See:** the shop screen. Capacity 4 → 6. A refused purchase shows a message and costs nothing. Back in the game, the timers carry on from where they paused.

### 10. Finish the round (1 min)

**Do:** rescue the rest, or wait until every floor is empty or expired.
**See:** the round-end beep, then *ROUND OVER – round score X total Y*. Press a key, and round 2 starts with shorter timers and +40 energy.
**Say:** "Round score = (rescued normal × 100 + critical × 300 + energy × 2 − lost × 50) × the difficulty multiplier, all with `MUL`. On Normal the multiplier is 2."

### 11. Quit, summary, high score (1 min)

**Do:** in round 2 press `Q`, then a key. Type a name and press Enter.
**See:** the GAME OVER summary (difficulty, rounds, rescued, lost, total), then *NEW HIGH SCORE!*, then the **sorted** top-10 table with your name in upper case.

### 12. Scores survive a restart (30 s)

**Do:** `4` (Quit). Run `build.bat run` again, then `2` (High Scores).
**See:** the same table, loaded from `data\highscores.dat`.

### 13. Code tour (2 min)

| Show | Where |
|---|---|
| `STRUCT` definitions | [src/Constants.inc:80](../src/Constants.inc#L80) (`FloorInfo`), [:96](../src/Constants.inc#L96) (`HighScore`) |
| Bit flags | [src/Constants.inc:13](../src/Constants.inc#L13) |
| A `CMP` / `Jcc` decision | [src/Elevator.asm:35](../src/Elevator.asm#L35) (energy check), [:45](../src/Elevator.asm#L45) (top floor) |
| String primitives | [src/StrUtil.asm:13](../src/StrUtil.asm#L13) (`REPNE SCASB`), [:58](../src/StrUtil.asm#L58) (`REPE CMPSB`) |
| Recursion + stack frame | [src/Scan.asm:24](../src/Scan.asm#L24), `RET 8` at [:64](../src/Scan.asm#L64) |
| Bubble sort | [src/Scoreboard.asm:66](../src/Scoreboard.asm#L66) (`SortScores`), swap at [:49](../src/Scoreboard.asm#L49) |
| File I/O | [src/Scoreboard.asm:167](../src/Scoreboard.asm#L167) (save), [:199](../src/Scoreboard.asm#L199) (load) |
| `MUL` with the multiplier | [src/Score.asm:47](../src/Score.asm#L47) |
| TTL colour with shifts | [src/Render.asm:153](../src/Render.asm#L153) |
| Real-time loop | [src/GameLoop.asm:190](../src/GameLoop.asm#L190) |

### 14. Course topics (1 min)

Walk through the table in README Section 7. Each row is a chapter of the textbook, with where it is used or why it isn't.

---

## If something goes wrong

| Problem | Fix |
|---|---|
| `Irvine32 not found` | Put Irvine32 in `C:\Irvine` or `C:\Irvine32-master`, or `set IRVINE_DIR=<path>` |
| `ml.exe not found` | Use the *Developer Command Prompt for VS (x86)* |
| Screen looks broken | Make the window at least 80 × 25 and restart the game |
| *Could not save data\highscores.dat* | Run from the project root (`build.bat run` does this). The `data` folder must exist |
| No credits for the shop | Deliver 3 normal civilians first (30 credits) |
