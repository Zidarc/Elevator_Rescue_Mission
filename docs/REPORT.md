# Elevator Rescue Simulator: Final Project Report

**Course:** Computer Organization and Assembly Language (COAL) Lab, FAST-NUCES Karachi
**Language:** 32-bit x86 MASM with the Irvine32 library
**Team:** Ali Hussain (25K-2513) · Ali (25K-3011) · M. Abbas (25K-0906)
**Submission:** Thursday, 26 November 2026

---

## 1. Abstract

Elevator Rescue Simulator is a real-time console game written entirely in x86 assembly. Civilians are trapped on floors 1–9 of a building, each floor with its own countdown. The player drives an elevator to collect them and bring them to the lobby, while managing energy, passenger capacity and credits across three rounds and three difficulty levels. Scores are calculated with integer arithmetic and kept in a sorted top-10 table that is saved to a file.

The game is the vehicle for the course content. It uses structures and arrays of structures, bit flags, scaled-index addressing, conditional processing with `CMP` and conditional jumps only, `MUL`/`DIV` and shifts, explicit stack frames and recursion, string primitives with repeat prefixes, macros, conditional assembly, multi-module linking, Win32 console functions and file I/O. The project includes an automated test runner written in assembly: **274 checks, all passing**.

## 2. Objectives

| Objective | Result |
|---|---|
| A complete, real-time, interactive game on the instruction set | Non-blocking `ReadKey` loop, one-second ticks from `GetMseconds` |
| Building as an array of structures, walked with indexed addressing | `floors[ebx * SIZEOF FloorInfo]`; `FloorInfo` is 8 bytes so the CPU's scale factor applies |
| Floor state in bit flags | One byte per floor, five flags, `TEST`/`AND`/`OR`/`NOT` |
| Decisions with `CMP` + `Jcc` only | No `.IF`/`.WHILE`/`.REPEAT` anywhere |
| Scoring with `MUL`/`DIV` and shifts | Round score and multiplier with `MUL`, TTL halving with `SHR`, colour thresholds with `SHL`, number printing with `DIV` |
| Recursion with an explicit stack frame | `ScanFloorsRecursive`: manual `EBP` frame, `RET 8` |
| A sorted, saved high-score table | Insertion sort that moves whole records with `STD` + `REP MOVSB`, binary file |
| Testable logic | Logic modules never print; 274 automated checks |

## 3. Improvements over the proposal

| Proposal | This project | Why |
|---|---|---|
| Parallel arrays ("MASM doesn't support struct-like data") | `FloorInfo`, `DiffSetting`, `HighScore` structures | Structures are a course topic and remove hand-calculated offsets |
| High scores only in memory | `data\highscores.dat`, checked on load | File I/O; scores survive a restart |
| One difficulty | Easy / Normal / Hard from a table | Future work in the proposal |
| Turn-based input | Real-time loop | Non-blocking input and timing |
| Several variables per floor | One bit-flag byte per floor | Boolean instructions |
| Scan reports totals only | Scan reveals each floor | Gives the scan a gameplay purpose |
| One source file, manual testing | 12 modules, `build.bat`, automated tests | Three people could work in parallel |

## 4. Design

The program is split into 12 modules, one per feature. All of them share one contract, `include/Elevator.inc`, which holds the constants, structures, `EXTERNDEF` globals and every `PROTO`. Every global is defined once, in `GameState.asm`. Logic modules only change state and set a status message. All drawing is in `Render.asm` and the screen modules, which is what makes the logic testable without a console. The full procedure reference is in [DESIGN.md](DESIGN.md).

Game flow: menu → difficulty → for each of 3 rounds: generate the building, run the real-time loop until the round ends, add the round's score → summary → name entry if the score reaches the top 10 → sorted table → menu.

## 5. Implementation highlights

**Real-time loop.** Every 30 ms `RunRound` checks the keyboard with `ReadKey`, which never waits, and compares `GetMseconds` with the time of the last tick. Adding exactly 1000 ms to the last-tick time keeps the timers accurate when a frame runs late. Because `GetMseconds` counts from midnight, a borrow in the subtraction restarts the clock.

**Recursive scan.** `ScanFloorsRecursive` takes its floor and direction on the stack, builds an `EBP` frame, saves the registers it uses and calls itself for the next floor. Below the lobby, 0 − 1 becomes `0FFFFFFFFh`, so one unsigned `JA` is the stopping condition at both ends. The tests check that `ESP` and the saved registers are unchanged after 11 levels of recursion.

**Drawing.** The screen is cleared only when a round starts and after the shop. During play every line is rewritten in place with `Gotoxy` into fixed-width fields, so there is no flicker. TTL colours come from shifts: `2·now > start` is green, `4·now ≥ start` is yellow, otherwise red.

**Insertion sort on records.** A new score walks down the table while the stored score is greater than or equal to it, so ties keep their order. The records below move down one slot as whole 24-byte blocks. Source and destination overlap, so the copy runs backwards (`STD` + `REP MOVSB` from the last byte, then `CLD`).

**File I/O.** The score file is the entry count followed by the whole table (244 bytes). Loading clears the table first and clears it again if the file is short or the count is impossible, so a damaged file never leaves half-loaded data.

**Scoring.** `CalcRoundScore` multiplies with `MUL` and compares the penalty before subtracting, so unsigned arithmetic can't wrap below 0. It always rebuilds the score from the counters, so it can safely run every frame for the live HUD.

**Sound.** Win32 `Beep`: a high tone when civilians are delivered, a low one when a floor is lost, and a longer one at the end of a round.

## 6. Testing

`build.bat test` assembles every module except `main.asm` together with `tests/*.asm` and runs the result. The `mAssertEq` and `mSuite` macros write through `WriteFile`, so the output also works when redirected. The runner's exit code is the number of failures.

| Suite | Checks |
|---|---|
| StrUtil | 22 |
| GameState | 21 |
| Building | 24 |
| Elevator | 72 |
| Scan | 19 |
| GameLoop | 28 |
| Render | 8 |
| Score and Shop | 41 |
| Scoreboard | 39 |
| **Total** | **274 passed, 0 failed** |

Random procedures are tested on their **range** (1000 rolls, 800 generated floors), never on exact values. The scoreboard tests write to `build\`, never to the real score file. Menus, timing, the screens, the shop loop, name entry and sound need a real console and are checked by hand.

## 7. Problems found and how they were solved

| Problem | Solution |
|---|---|
| With 1 energy left the elevator could neither move nor end the round | The round ends when energy drops below the cost of one move, not at exactly 0 |
| Delivery points were added during play and the formula would add them again at the end | `CalcRoundScore` rebuilds the round score from the counters instead of adding to it |
| Moving high-score records down overwrote the records being copied | Copy backwards with `STD` + `REP MOVSB` from the last byte, then `CLD` |
| `LENGTHOF`/`SIZEOF` of an `EXTERNDEF` array is one element outside its module | Loops use `NUM_FLOORS` / `MAX_SCORES` |
| `MUL` changes EDX, which `MoveElevator` didn't save | Added to `USES`; a test now checks EDX |
| Irvine's `CloseFile` (Win32 `CloseHandle`) changes ECX, which broke a byte count in `SaveScoresTo` | Found by the save/load test; the count is kept in ESI, which Win32 preserves |
| `GetMseconds` wraps at midnight | A borrow on the subtraction restarts the clock |
| Timers kept running behind the shop screen | The shop is a pause: the clock restarts when it closes |
| Clearing the screen every frame flickered | Lines are rewritten in place into fixed-width fields |

## 8. Limitations and future work

- The display assumes an 80 × 25 console.
- The high-score file is read from the folder the game starts in; `build.bat run` always starts it from the project root.
- `Beep` pauses the game for its duration (60 ms), which is barely noticeable.
- Possible extensions: more floors, several elevators, saving a game in progress.

## 9. Team contributions

| Member | Work (from the project schedule) |
|---|---|
| Ali Hussain | Project setup, `Elevator.inc` contract, `GameState`, `StrUtil`, `Menu`, test framework (Day 1); recursive scan and game loop (Day 4); scoreboard (Day 7) |
| Ali | Building generation and difficulty (Day 2); rendering (Day 5); testing and balancing (Day 8) |
| M. Abbas | Elevator movement, actions and TTL tick (Day 3); shop and scoring (Day 6); polish and release (Day 9) |

> **TODO (team):** Check this table against who actually wrote each part before submitting, and state any outside help as the course requires.

## 10. Conclusion

The project shows that a complete real-time game is practical in plain 32-bit assembly once the work is split into well-defined modules. The hardest parts were the low-level details rather than the game rules: preserving registers across library and Win32 calls, overlapping memory copies, unsigned edge cases at 0, and timing. The automated tests caught these early, including one register bug that would otherwise have reached the final build.
