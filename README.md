# Elevator Rescue Simulator

**A real-time elevator rescue game written entirely in x86 MASM Assembly with the Irvine32 library.**

Computer Organization and Assembly Language (COAL) Lab project, FAST-NUCES Karachi.

A building is in trouble. Civilians are trapped on floors 1–9, and every floor has a countdown timer (TTL, Time-To-Live). The player drives an elevator, picks civilians up and brings them down to the lobby before their timer runs out, while managing energy, passenger capacity and credits.

| Symbol | Meaning |
|--------|---------|
| `N` | Normal civilians: 1–4 people, 100 points each |
| `!` | Critical civilians: 1–2 people, half the timer, 300 points each |
| `+` | Energy pack: +25 energy |
| `?` | Not scanned yet: contents unknown |
| `x` | Timer ran out: civilians lost |

All game logic, data handling, rendering, scoring and file storage are written in **32-bit assembly**. The only library is Irvine32 (console I/O, colours, cursor, random numbers, timing, files).

---

## Table of Contents

1. [Team](#1-team)
2. [Project Purpose](#2-project-purpose)
3. [Proposal and Reference](#3-proposal-and-reference)
4. [Changes from the Proposal](#4-changes-from-the-proposal)
5. [Features](#5-features)
6. [Assembly Concepts Used](#6-assembly-concepts-used)
7. [Course Topic Coverage](#7-course-topic-coverage)
8. [Program Architecture](#8-program-architecture)
9. [Game Flow](#9-game-flow)
10. [Game Rules](#10-game-rules)
11. [Screen Layout](#11-screen-layout)
12. [Project Folder Structure](#12-project-folder-structure)
13. [Development Environment](#13-development-environment)
14. [Building, Running and Testing](#14-building-running-and-testing)
15. [Git Branch Strategy](#15-git-branch-strategy)
16. [9-Day Schedule](#16-9-day-schedule)
17. [Testing Requirements](#17-testing-requirements)
18. [Final Demonstration](#18-final-demonstration)
19. [Out of Scope](#19-out-of-scope)
20. [Learning Outcomes](#20-learning-outcomes)
21. [Credits and License](#21-credits-and-license)

---

## 1. Team

| Roll No. | Name |
|----------|------|
| 25K-2513 | Ali Hussain |
| 25K-3011 | Ali |
| 25K-0906 | M. Abbas |

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow, coding rules and daily handoff format.

---

## 2. Project Purpose

Elevator Rescue Simulator shows that a complete, real-time, interactive game can be built directly on the processor's instruction set:

- Store a building as an **array of structures** and walk it with indexed addressing.
- Pack floor state into **bit flags** and read them with `TEST`, `AND` and `OR`.
- Run a **real-time loop**: poll the keyboard without blocking and tick timers with millisecond clock readings.
- Make decisions with **CMP and conditional jumps only** (no `.IF` / `.WHILE` directives).
- Do all scoring with integer **MUL / DIV and shifts**.
- Use **recursion** with explicit stack frames.
- Sort and save a high-score table with **string primitives** and **file I/O**.

The game is the vehicle. **The assembly concepts are the point.**

---

## 3. Proposal and Reference

The project is based on the proposal document [Resources/Elevator Rescue Mission - COAL Group Project.pdf](Resources/), which describes an elevator rescue game in MASM with:

- Elevator movement controlled by `W`, `S`, `A`, `X`, `B`, `Q`
- A TTL countdown per floor, with expiry
- Energy management and energy packs
- Critical (VIP) civilians worth bonus points
- A shop in the lobby (capacity, energy, upgrades)
- A recursive floor scan
- Multi-round scoring and a sorted high-score table stored in arrays

**All code in this repository is written by our team.** The document is used for the game idea and feature list only.

### Limitations we address

| In the proposal | In this project |
|-----------------|-----------------|
| *"MASM doesn't support struct-like data"*: names and scores are kept in separate parallel arrays with hand-calculated offsets | MASM **does** support `STRUCT`. Floors, difficulty settings and high scores are structures, accessed with `(FloorInfo PTR [esi]).ttlLeft` style operands |
| High scores live in arrays only and are lost when the program closes | High scores are **saved to and loaded from a file** (`data/highscores.dat`) |
| A single difficulty | **Easy / Normal / Hard** from a difficulty table (listed as future work in the proposal) |
| Turn-based input | **Real-time** loop: `ReadKey` polls without blocking, `GetMseconds` ticks the timers every second |
| Floor state in several separate variables | One **bit-flag byte** per floor (`FLAG_CIVILIANS`, `FLAG_CRITICAL`, `FLAG_ENERGY`, …) |
| Manual testing only | An **automated test runner** written in assembly (`build.bat test`) |
| One large source file | **Multi-module** program: one `.asm` per feature, shared `Elevator.inc` with `EXTERNDEF` and `PROTO` |

---

## 4. Changes from the Proposal

| Proposal | Current plan | Reason |
|----------|--------------|--------|
| Parallel arrays for names and scores | `HighScore STRUCT` array | Shows structures (a course topic) and removes manual offset bugs |
| Scores kept in memory | Saved in `data/highscores.dat` | File handling is a course topic; scores survive a restart |
| One difficulty | Three, from `difficultyTable` | The proposal's own future work; cheap to add with a table |
| Scan reports totals only | Scan **reveals** each floor's contents (unscanned floors show `?`) | Gives the scan a real gameplay purpose |
| One source file, manual tests | Multiple modules, `build.bat`, automated tests | Lets three people work in parallel without merge conflicts |
| Visual Studio project | `build.bat` (calls Visual Studio's MASM) | One command builds on every team member's machine, nothing machine-specific is committed |

Everything stays in MASM with Irvine32, as the proposal describes.

---

## 5. Features

### Game
- A 10-floor building (lobby + floors 1–9) generated randomly each round.
- Elevator moved with `W` / `S`. Every move costs energy.
- `A` (action): pick civilians up (up to capacity), collect an energy pack, or drop passengers off at the lobby.
- `X` (scan): recursive scan up and down the building that reveals every floor's contents. Costs energy.
- `B` (shop, lobby only): buy capacity, energy or a time freeze with credits.
- `Q` (quit): ends the game early, but the score is still recorded.
- Real-time TTL countdown, with colour warnings when a floor is running out of time.
- Three rounds per game. Each round gets shorter timers.
- Three difficulty levels.

### Scores
- Round score and total score with a difficulty multiplier.
- End-of-game summary screen.
- Top 10 high-score table with player names, sorted highest first, saved to a file.

---

## 6. Assembly Concepts Used

| Concept | Where |
|---------|-------|
| **Data definition**: `BYTE`, `WORD`, `DWORD`, `DUP`, strings, symbolic constants (`=`, `EQU`) | `Elevator.inc`, every `.data` section |
| **STRUCT** | `FloorInfo`, `DiffSetting`, `HighScore` |
| **Array of structures** + base-index-scale addressing | `floors[esi + ecx * SIZEOF FloorInfo]`, `highScores` |
| **OFFSET, PTR, TYPE, SIZEOF, LENGTHOF** | Table indexing, buffer sizes |
| **Bit flags**: `AND`, `OR`, `NOT`, `TEST` | `floorFlags` per floor, `StrToUpper` (clear bit 5) |
| **CMP + conditional jumps** (signed and unsigned) | All decisions. `.IF` / `.WHILE` / `.REPEAT` are not used |
| **Loops**: `LOOP`, `JECXZ`, counter loops, nested loops | Floor generation, rendering, timers, sorting |
| **Shifts**: `SHL`, `SHR` | Critical TTL = TTL `SHR 1`, quick multiply / divide by 2 |
| **MUL / DIV** | Scoring, difficulty multiplier, table indexing, percentage rolls |
| **Stack**: `PUSH`, `POP`, `PUSHAD`, `POPAD` | Saving registers, passing parameters |
| **Procedures**: `PROC`, `USES`, `PROTO`, `INVOKE`, `ADDR` | Every module |
| **Explicit stack frames**: `EBP`-based parameters, `RET n` | `ScanFloorsRecursive` |
| **Recursion** | `ScanFloorsRecursive` walks up and down the building |
| **String primitives**: `MOVSB`, `CMPSB`, `SCASB`, `STOSB`, `LODSB` with `REP` / `REPE` / `REPNE` | `StrUtil.asm`, moving whole high-score records |
| **Macros** with `LOCAL` labels | Test framework (`mAssertEq`, `mSuite`), drawing helpers |
| **Conditional assembly**: `IFNDEF` | Include guards |
| **Multi-module programs**: `EXTERNDEF`, `PROTO`, separate assembly and linking | `src/*.asm` + `include/Elevator.inc` |
| **Irvine32**: `ReadKey`, `ReadChar`, `ReadString`, `Gotoxy`, `SetTextColor`, `Clrscr`, `Delay`, `GetMseconds`, `Randomize`, `RandomRange`, `WriteDec` | Input, rendering, timing, randomness |
| **Win32 API**: `SetConsoleTitle`, `GetStdHandle`, `WriteFile`, `SetConsoleCursorInfo` | Console setup, test output |
| **File I/O**: `CreateOutputFile`, `WriteToFile`, `OpenInputFile`, `ReadFromFile`, `CloseFile` | High-score file |
| **Insertion sort with array shifting** | Inserting a new score into the sorted table |

---

## 7. Course Topic Coverage

How each topic from the course textbook (Kip Irvine, *Assembly Language for x86 Processors*) is used, or why it is not.

| Ch. | Topic | Used? | Where |
|-----|-------|-------|-------|
| 3 | Assembly fundamentals: data types, constants, strings, `DUP` | ✅ | `Elevator.inc`, all `.data` sections |
| 4 | Data transfer, addressing modes, `OFFSET` / `PTR` / `TYPE` / `LENGTHOF` / `SIZEOF`, `JMP`, `LOOP` | ✅ | Indexed access to `floors`, `highScores`, `difficultyTable` |
| 5 | Procedures, the runtime stack, `PUSH` / `POP`, `USES`, the Irvine32 library | ✅ | Every module |
| 6 | Boolean instructions (`AND`, `OR`, `XOR`, `NOT`, `TEST`), `CMP`, conditional jumps, conditional loops, finite-state machines | ✅ | Floor flags, every decision, the input dispatcher. `.IF` directives deliberately **not** used, so every branch is a visible `CMP` + `Jcc` |
| 7 | Shift and rotate, `MUL` / `IMUL` / `DIV` / `IDIV` | ✅ / ❌ | Shifts and `MUL` / `DIV` for scoring and timers. Extended-precision (`ADC` / `SBB`) and BCD arithmetic: scores fit in 32 bits, so not needed |
| 8 | Stack frames, stack parameters, `LOCAL`, recursion, `INVOKE` / `PROTO`, multi-module programs | ✅ | `ScanFloorsRecursive` (manual `EBP` frame, `RET 8`), all modules linked separately |
| 9 | String primitives, two-dimensional arrays, searching and sorting arrays | ✅ / ⚠️ | `StrUtil.asm`, insertion sort for the score table. Arrays are 1-D arrays of structures (row = record, column = field). A separate 2-D array isn't needed |
| 10 | Structures, macros, conditional-assembly directives | ✅ / ❌ | `STRUCT`, macros with `LOCAL`, `IFNDEF` guards. `UNION`: no natural use |
| 11 | MS-Windows programming: Win32 console functions, file I/O | ✅ | Console title / cursor, `WriteFile`, high-score file |
| 12 | Floating-point (FPU) | ❌ | The game only needs integers |
| 13 | High-level language interface | ❌ | The whole program is assembly, by design |

### Stretch goal: Sound

If time allows after Day 8, short beeps (Win32 `Beep` from kernel32) on rescue, expiry and round end. Started only once the core game is complete and stable.

---

## 8. Program Architecture

```
                        main.asm  (entry point: Randomize, title, menu)
                            |
                        Menu.asm  (New Game / High Scores / How to Play / Quit)
                     ┌──────┴───────────────────────────────┐
                     |                                      |
               GameLoop.asm                           Scoreboard.asm
        RunGame -> RunRound (real time)         Load / Save / Insert / Show
        ReadKey + GetMseconds tick                  data/highscores.dat
                     |
   ┌──────────┬──────┼───────────┬────────────┬───────────┐
   |          |      |           |            |           |
Building   Elevator  Scan      Shop         Score       Render
 .asm       .asm     .asm      .asm         .asm        .asm
generate   move,    recursive  lobby       MUL / DIV   Gotoxy,
floors,    action,  scan       upgrades    round score colours,
TTL by     TTL                             summary     HUD
difficulty tick
   |          |      |           |            |           |
   └──────────┴──────┴─────┬─────┴────────────┴───────────┘
                           |
               GameState.asm  (all globals + difficulty table)
               StrUtil.asm    (string primitives)
                           |
               include/Elevator.inc  (constants, STRUCTs, EXTERNDEF, PROTO)
```

- **One module per feature.** Each team member's day touches its own file, so merge conflicts are rare.
- **All shared data lives in `GameState.asm`** and is declared once in `Elevator.inc` with `EXTERNDEF`.
- **Every procedure is declared with `PROTO` in `Elevator.inc`** before it exists, so the interfaces are fixed from Day 1.
- **Rendering is separate from logic.** `Building`, `Elevator`, `Scan`, `Shop` and `Score` never print. They update state and call `SetStatus`. Only `Render.asm` draws. That is what makes them testable.

---

## 9. Game Flow

```
Program start
     |
     ↓
Randomize, load high scores (file)
     |
     ↓
Main menu ──► How to Play / High Scores / Quit
     |
  New Game
     ↓
Select difficulty ──► ResetGameState
     |
     ↓
┌──► Round N: InitializeGame (random floors, TTL by difficulty and round)
│        |
│        ↓
│    Real-time loop  ◄────────────────────────────────────┐
│        |                                                │
│        ├── ReadKey (non-blocking)                       │
│        │     W/S move · A action · X scan · B shop · Q quit
│        │                                                │
│        ├── 1000 ms passed? ──► TickFloors (TTL − 1,     │
│        │                       expiry = casualties)     │
│        │                                                │
│        ├── DrawGameState                                │
│        │                                                │
│        └── CheckRoundOver ── no ────────────────────────┘
│               |
│              yes
│               ↓
│        CalcRoundScore ──► totalScore
│               |
└── more rounds and not quit? ── yes
                |
                no
                ↓
         ShowSummary ──► qualifies for top 10? ──► enter name
                                    |
                     InsertScoreSorted ──► SaveScores ──► ShowScores
                                    |
                                    ↓
                                Main menu
```

---

## 10. Game Rules

### Building
- 10 floors: floor 0 is the **lobby**, floors 1–9 can hold civilians or an energy pack.
- Each round, every floor 1–9 is rolled (`RandomRange 100`):

| Roll | Floor type | Contents | TTL |
|------|-----------|----------|-----|
| first `criticalPct` % | Critical `!` | 1–2 civilians | half of a normal TTL (`SHR 1`) |
| next 20 % | Energy `+` | one pack, +25 energy | none |
| next 15 % | Empty | nothing | none |
| rest | Normal `N` | 1–4 civilians | random in `[ttlMin, ttlMax]` |

- From round 2, every TTL is reduced by `5 × (round − 1)` seconds, but never below 10.
- A floor's contents show as `?` until it is **scanned** or **visited**. Its TTL is always visible.

### Difficulty levels

| Level | TTL range (s) | Start energy | Critical floors | Score multiplier |
|-------|---------------|--------------|-----------------|------------------|
| Easy | 45–75 | 120 | 10 % | ×1 |
| Normal | 30–60 | 100 | 15 % | ×2 |
| Hard | 20–40 | 80 | 25 % | ×3 |

### Controls

| Key | Action | Cost |
|-----|--------|------|
| `W` | Move up one floor | 2 energy |
| `S` | Move down one floor | 2 energy |
| `A` | Lobby: drop off all passengers. Civilians floor: pick up as many as capacity allows. Energy floor: collect the pack (max 150 energy). | free |
| `X` | Scan: recursively visits every floor above and below, reveals their contents and reports the counts | 5 energy |
| `B` | Shop (lobby only) | credits |
| `Q` | Quit the game. The score so far is still recorded | — |

### Timers
- Every **1000 ms** (`GetMseconds`), each floor with waiting civilians loses 1 second of TTL.
- When a TTL reaches 0, the civilians still on that floor are **lost** (casualties) and the floor is marked `x`.
- Civilians already in the elevator are safe from their floor's timer.

### Energy
- Start energy depends on the difficulty. Rounds 2 and 3 add +40 (max 150).
- When energy reaches 0 the elevator stops and the round ends. If it stopped at the lobby, passengers on board are delivered. Anywhere else they are lost.

### Shop (lobby, `B`)

| Item | Cost | Effect |
|------|------|--------|
| Capacity upgrade | 30 credits | +2 capacity (max 10) |
| Energy refill | 20 credits | +40 energy (max 150) |
| Time freeze | 50 credits | +10 s on every floor that still has civilians waiting |

Credits: **10** per normal civilian and **25** per critical civilian delivered to the lobby. Credits, capacity and energy carry over between rounds.

### Round end
A round ends when **any** of these happens:
1. No civilians are waiting on any floor and none are in the elevator (all rescued or lost).
2. Energy reaches 0.
3. The player presses `Q` (this also ends the game).

### Scoring

```
roundScore = ( rescuedNormal   × 100
             + rescuedCritical × 300
             + energyLeft      × 2
             − casualties      × 50 ) × multiplier

roundScore never goes below 0.     totalScore = sum of all round scores
```

Example: Normal (×2), 8 normal and 2 critical civilians rescued, 3 lost, 40 energy left:

```
(8 × 100 + 2 × 300 + 40 × 2 − 3 × 50) × 2 = (800 + 600 + 80 − 150) × 2 = 2660
```

### High scores
- After the game, if `totalScore > 0` and it beats the 10th entry (or the table isn't full), the player enters a name (max 15 characters, stored in upper case).
- The entry is placed by **insertion sort**: records below it are shifted down one slot (whole 24-byte records moved with `REP MOVSB`), and the table is saved to `data/highscores.dat`.
- Equal scores keep their original order (the new entry goes below existing equal scores).

---

## 11. Screen Layout

80 × 25 console. Only the parts that change are redrawn, to avoid flicker.

```
 ELEVATOR RESCUE SIMULATOR          Round 2/3       Difficulty: NORMAL
 ───────────────────────────────────────────────────────────────────────
  9 │       │  ?  ?        TTL 41     │   Energy      78 / 150
  8 │       │  N  3        TTL 12     │   Credits     45
  7 │       │  +           ---        │   Capacity    2 / 4
  6 │ [===] │  !  1        TTL 08     │   Passengers  N:2  !:0
  5 │       │  x           ---        │
  4 │       │  ?  ?        TTL 37     │   Round score 1240
  3 │       │              ---        │   Total score 2900
  2 │       │  N  2        TTL 22     │
  1 │       │  ?  ?        TTL 30     │   Rescued 6   Lost 3
  0 │ LOBBY │  [B] SHOP               │
 ───────────────────────────────────────────────────────────────────────
  W up   S down   A action   X scan   B shop   Q quit
  > Picked up 2 civilians on floor 6.
```

TTL colours: **green** > 50 % left, **yellow** 25–50 %, **red** < 25 %. Critical floors are magenta.

---

## 12. Project Folder Structure

```
COALProject/
│
├── include/
│   └── Elevator.inc            # Constants, STRUCTs, EXTERNDEF globals, PROTOs (the contract)
│
├── src/
│   ├── main.asm                # Entry point only; kept small
│   ├── GameState.asm           # All global variables + difficulty table       [Day 1]
│   ├── StrUtil.asm             # String primitives (SCASB, CMPSB, STOSB, ...)  [Day 1]
│   ├── Menu.asm                # Main menu, How to Play                        [Day 1]
│   ├── Building.asm            # Difficulty select, floor generation           [Day 2]
│   ├── Elevator.asm            # Move, action, TTL tick                        [Day 3]
│   ├── Scan.asm                # Recursive scan                                [Day 4]
│   ├── GameLoop.asm            # Real-time loop, input dispatch, rounds        [Day 4]
│   ├── Render.asm              # All drawing: intro, building, HUD             [Day 5]
│   ├── Shop.asm                # Lobby shop                                    [Day 6]
│   ├── Score.asm               # Round score, summary screen                   [Day 6]
│   └── Scoreboard.asm          # High-score table, sorting, file I/O           [Day 7]
│
├── tests/
│   ├── TestFramework.inc       # mAssertEq / mSuite macros
│   ├── TestFramework.asm       # Counters, AssertEq, output that works when redirected
│   ├── TestMain.asm            # Test runner entry point (exit code = failures)
│   ├── test_strutil.asm
│   ├── test_gamestate.asm
│   ├── test_building.asm       # Day 2
│   ├── test_elevator.asm       # Day 3
│   ├── test_scan.asm           # Day 4
│   ├── test_score.asm          # Day 6 (with the shop)
│   └── test_scoreboard.asm     # Day 7
│
├── data/
│   └── highscores.dat          # Created at runtime, not committed
│
├── docs/
│   ├── DESIGN.md               # Module and procedure reference, memory layout  [Day 8]
│   ├── REPORT.md               # Final project report                           [Day 8–9]
│   └── DEMO.md                 # Demo script                                    [Day 9]
│
├── Resources/
│   └── Elevator Rescue Mission - COAL Group Project.pdf   # Proposal
│
├── build.bat                   # Build / run / test / clean
├── .gitignore
├── .gitattributes
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

---

## 13. Development Environment

**Operating system:** Windows

| Tool | Purpose |
|------|---------|
| Git | Version control |
| Visual Studio 2022 or newer with **Desktop development with C++** | Provides MASM (`ml.exe`) and the linker |
| Irvine32 library in `C:\Irvine` | Console I/O, colours, timing, random numbers, files |
| VS Code (optional: *MASM/TASM* extension) | Editing |

If Irvine32 is somewhere else, set `IRVINE_DIR` before building:

```bat
set IRVINE_DIR=D:\Irvine
```

---

## 14. Building, Running and Testing

`build.bat` finds Visual Studio's MASM by itself (through `vswhere`). It works from a normal Command Prompt, PowerShell or the VS Code terminal.

```bat
build.bat            :: assemble + link  -> build\ElevatorRescue.exe
build.bat run        :: build, then run the game from the project root
build.bat test       :: build and run the test runner -> build\RunTests.exe
build.bat clean      :: delete build\
```

From PowerShell, use `.\build.bat test`.

Expected test output:

```
== StrUtil
  [PASS] StrLen of HELLO is 5
  ...
Passed: 33   Failed: 0

ALL TESTS PASSED
```

**Debugging with registers and memory:** the build includes debug info (`/Zi`, `/DEBUG`). In Visual Studio choose *File → Open → Project/Solution*, select `build\ElevatorRescue.exe`, then press F11 to step through the assembly with the Registers and Memory windows.

The `build/` folder and `data/highscores.dat` are generated and must **not** be committed.

---

## 15. Git Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, tested, submission-ready code |
| `develop` | Integrated team development |
| `feature/*` | New functionality, e.g. `feature/building`, `feature/game-loop` |
| `fix/*` | Bug fixes, e.g. `fix/ttl-underflow` |
| `docs/*` | Documentation-only changes |

```
feature/your-feature ──► Pull Request ──► review ──► develop ──► (release) ──► main
```

The full workflow, Pull Request requirements and commit style are in [CONTRIBUTING.md](CONTRIBUTING.md).

---

## 16. 9-Day Schedule

**Start:** Wednesday, 18 November 2026 (Day 1)
**Submission:** Thursday, 26 November 2026 (Day 9)

The team uses a **daily rotation**. The owner of each day completes that day's task, opens a Pull Request into `develop`, and writes a handoff note for the next owner (format in [CONTRIBUTING.md](CONTRIBUTING.md#10-daily-handoff)).

Rotation order: **Ali Hussain → Ali → M. Abbas**, repeating.

| Day | Date | Owner | Task | Branch |
|-----|------|-------|------|--------|
| 1 ✅ | Wed 18 Nov | Ali Hussain | Docs, `.gitignore`, folder structure, `build.bat`, `Elevator.inc` (constants, STRUCTs, `EXTERNDEF`, every `PROTO`), `GameState.asm`, `StrUtil.asm`, `Menu.asm` (menu + How to Play), test framework + tests, create `develop` | `feature/project-setup` |
| 2 | Thu 19 Nov | Ali | `Building.asm`: `SelectDifficulty`, `RollFloorType`, `GenerateFloor`, `InitializeGame` (TTL by difficulty and round, critical TTL `SHR 1`, round energy refill) + `test_building.asm`. *Kept light: DSA is due the same day.* | `feature/building` |
| 3 | Fri 20 Nov | M. Abbas | `Elevator.asm`: `MoveElevator` (bounds, energy), `PerformAction` (pick up up to capacity, collect energy, drop off at lobby with points and credits), `TickFloors` (TTL countdown, expiry → casualties) + `test_elevator.asm` | `feature/elevator` |
| 4 | Sat 21 Nov | Ali Hussain | `Scan.asm`: `ScanAction`, `ScanFloorsRecursive` (manual `EBP` frame). `GameLoop.asm`: `RunGame`, `RunRound` (`ReadKey` + `GetMseconds`), `HandleCommand`, `CheckRoundOver`, rounds 1–3. Wire **New Game** in the menu. Temporary plain-text `DrawGameState` in `Render.asm` so the game is playable + `test_scan.asm` | `feature/game-loop` |
| 5 | Sun 22 Nov | Ali | `Render.asm` (replaces the temporary one): `DrawIntro`, `DrawGameState`, `DrawFloor`, `DrawHud`, `SetStatus`. `Gotoxy` layout from Section 11, TTL colours, elevator car, hidden cursor, redraw only what changed | `feature/render` |
| 6 | Mon 23 Nov | M. Abbas | `Shop.asm`: `BuyInLobby` (3 items, credit checks). `Score.asm`: `CalcRoundScore` (`MUL`, multiplier, never below 0), `ShowSummary`. Wire both into the game loop + `test_score.asm` | `feature/shop-score` |
| 7 | Tue 24 Nov | Ali Hussain | `Scoreboard.asm`: `InsertScoreSorted` (insertion sort, records shifted with `REP MOVSB`), `RecordScore` (name entry, `StrToUpper`), `ShowScores` (`StrPadRight` table), `LoadScores` / `SaveScores` (`data/highscores.dat`). Wire **High Scores** in the menu + `test_scoreboard.asm` | `feature/scoreboard` |
| 8 | Wed 25 Nov | Ali | Full test pass, play-testing on all 3 difficulties, bug fixes, balance the constants in `Elevator.inc`. `docs/DESIGN.md` (every procedure: receives / returns / registers changed). Draft `docs/REPORT.md`. *Stretch: sound* | `fix/*` / `docs/design` |
| 9 | Thu 26 Nov | M. Abbas | UI polish, finish `docs/REPORT.md`, `docs/DEMO.md` + rehearsal with the whole team, final regression test, merge `develop` → `main`, tag `v1.0`, **submit** | `main` |

### Build order

The order is deliberate. Each step depends on the one before it.

```
1. Elevator.inc, GameState, StrUtil, test framework
   ↓
2. Building           (fills floors[] from the difficulty table)
   ↓
3. Elevator           (moves through floors[], changes energy / passengers)
   ↓
4. Scan + Game loop   (uses 2 and 3; first playable version)
   ↓
5. Render             (draws the state that 2–4 produce)
   ↓
6. Shop + Score       (needs the loop and the lobby)
   ↓
7. Scoreboard         (needs the final score from 6)
   ↓
8. Testing, balancing, documentation
   ↓
9. Polish, report, demo, release
```

If a day's task is not finished, the owner says so in the handoff, and the next owner finishes it before starting their own. **A broken feature is never merged just to stay on schedule.**

---

## 17. Testing Requirements

Every logic module has a test file in `tests/`, and `build.bat test` must report **ALL TESTS PASSED** before a Pull Request is merged. Rendering and keyboard input are checked by hand (they need a real console).

To make logic testable, tests set the globals directly (for example `mov elevatorFloor, 5`), call the procedure, and check the result. Random procedures are tested on their **range** (call many times, check the bounds), not on exact values.

**StrUtil and GameState (Day 1)**
- Length of normal and empty strings
- Equal / different length / different text / two empty strings
- Copy, truncated copy (always null-terminated), copy with size 0
- Upper-case conversion changes only `a`–`z`
- Padding to a width, never shortening
- Structure sizes, difficulty table lookup, `ResetGameState` resets everything except the difficulty

**Building (Day 2)**
- `RollFloorType` only returns `FT_EMPTY`…`FT_ENERGY` (1000 calls)
- Normal floors: 1–4 civilians, TTL inside `[ttlMin, ttlMax]` minus the round penalty
- Critical floors: 1–2 civilians, TTL halved, `FLAG_CRITICAL` set
- Energy floors: `FLAG_ENERGY` set, no civilians
- TTL never below `MIN_TTL` in round 3 on Hard
- Lobby is always empty; every floor starts unscanned
- Round 2 adds energy, capped at `MAX_ENERGY`

**Elevator (Day 3)**
- Up from floor 9 and down from floor 0 are refused, with no energy used
- Each move costs `MOVE_COST`; a move with too little energy is refused
- Pick up with enough capacity / with partial capacity (the rest stay on the floor)
- Critical civilians are counted as critical passengers
- Energy pack: +25, capped at 150, flag cleared
- Drop off at the lobby: points, credits and rescued counters correct, elevator empty
- `TickFloors`: TTL −1 only on floors with civilians; at 0 → casualties added, `FLAG_EXPIRED` set, civilians cleared; never goes below 0

**Scan and round end (Day 4)**
- Scan from the lobby, the top floor and the middle gives the same total
- Scan sets `FLAG_SCANNED` on every floor and costs `SCAN_COST`
- Registers and stack are the same after the recursive call (`ESP` checked before and after)
- `CheckRoundOver`: all rescued / energy 0 / quit / still playing

**Shop and Score (Day 6)**
- Each item: enough credits / not enough credits / already at the maximum
- Shop refused outside the lobby
- Score for the README example is 2660
- Each difficulty multiplier; the score never goes below 0

**Scoreboard (Day 7)**
- Insert into an empty table, at the top, in the middle, at the bottom
- An 11th score lower than all 10 is rejected (rank 0)
- Equal scores: the new one goes below
- Long names are cut to 15 characters
- Save, clear, load gives the same table; a missing file gives an empty table

---

## 18. Final Demonstration

1. Run `build.bat test` and show **ALL TESTS PASSED**.
2. Start the game. Show the intro screen and the **How to Play** page.
3. Choose **Normal**. Show the building: unscanned floors show `?`, TTLs counting down in **real time**.
4. Press `X` to scan. Explain the **recursion** and the stack frame in `ScanFloorsRecursive`.
5. Move to a **critical** floor (`!`), pick up civilians, and show the capacity limit.
6. Collect an **energy pack** (`+`).
7. Let one floor's TTL run out. Show the colour changing green → yellow → red, then the casualty.
8. Return to the lobby, drop off passengers, and show points and credits.
9. Open the **shop** and buy a capacity upgrade.
10. Finish the round. Show the round score and the **MUL** for the multiplier.
11. Quit with `Q` in round 2. Show the summary, enter a name, and see the **sorted** high-score table.
12. Restart the program. Show that the high scores were **loaded from the file**.
13. Open the code: `STRUCT` definitions, the bit flags, a `CMP`/`Jcc` decision, the string primitives in `StrUtil.asm`, and the insertion sort.
14. Walk through the course topic table (Section 7).

---

## 19. Out of Scope

The following are intentionally **not** part of this project:

- Graphics outside the text console (no GDI / DirectX windows)
- Mouse input
- Multiple elevators or multiplayer
- 64-bit assembly
- Floating-point arithmetic
- Calling C / C++ code
- Saving a game in progress (only high scores are saved)

Major scope changes need agreement from the whole team and the instructor.

---

## 20. Learning Outcomes

By completing this project, the team will have practised:

- Data definition, symbolic constants and memory layout
- All 32-bit addressing modes, including base + index × scale + displacement
- Structures and arrays of structures
- Bit manipulation with Boolean instructions
- Conditional processing with `CMP` and conditional jumps
- Integer multiplication, division and shifts
- Procedures, the runtime stack and stack frames
- Recursion in assembly
- String primitives with repeat prefixes
- Macros and conditional assembly
- Multi-module programs and linking
- Real-time input and timing on the Win32 console
- File I/O through Irvine32 / Win32
- Insertion sort on records
- Writing automated tests in assembly
- Git branching, Pull Requests and code review

---

## 21. Credits and License

- Game idea and feature list: the project proposal in `Resources/`.
- [Irvine32 library](http://asmirvine.com/) by Kip Irvine, used for console I/O. It is installed separately and is not included in this repository.

This project is licensed under the MIT License. See [LICENSE](LICENSE).
