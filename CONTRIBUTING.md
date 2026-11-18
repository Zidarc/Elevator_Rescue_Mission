# Contributing to Elevator Rescue Simulator

## 1. Team Members

| Roll No. | Name |
|----------|------|
| 25K-2513 | Ali Hussain |
| 25K-3011 | Ali |
| 25K-0906 | M. Abbas |

Daily rotation order: **Ali Hussain → Ali → M. Abbas**, repeating. See the [9-Day Schedule](README.md#16-9-day-schedule) in the README for who owns which day.

---

## 2. Branch Structure

```
main
develop
feature/*
fix/*
docs/*
```

### `main`
Stable, tested, submission-ready code. Only updated from `develop` at release (Day 9).

### `develop`
The integrated team development branch. All Pull Requests target `develop`.

### `feature/*`
New functionality, one branch per day:

```
feature/project-setup
feature/building
feature/elevator
feature/game-loop
feature/render
feature/shop-score
feature/scoreboard
```

### `fix/*`
Bug fixes. Examples:

```
fix/ttl-underflow
fix/capacity-overflow
fix/scoreboard-missing-file
```

### `docs/*`
Documentation-only changes. Examples:

```
docs/design
docs/report
docs/demo
```

---

## 3. Standard Workflow

Start from the latest `develop`:

```bash
git switch develop
git pull origin develop
```

Create a feature branch:

```bash
git switch -c feature/your-feature
```

Work, build and test locally:

```bat
build.bat test
build.bat run
```

Check your changes:

```bash
git status
git diff
```

Stage only the files you intended to change:

```bash
git add src/Building.asm tests/test_building.asm tests/TestMain.asm
```

Commit:

```bash
git commit -m "Describe the change"
```

Push:

```bash
git push -u origin feature/your-feature
```

Open a Pull Request:

```
feature/your-feature  →  develop
```

Another team member reviews it. After approval and a passing `build.bat test`, merge it into `develop`.

---

## 4. Before Starting New Work

Always sync your local `develop` first:

```bash
git switch develop
git pull origin develop
```

Then create the new branch. This keeps you from building on an outdated version and reduces merge conflicts.

---

## 5. Pull Request Requirements

A Pull Request must have:

- A clear title.
- A description of the changes.
- A list of the files changed.
- The tests performed (paste the `build.bat test` summary).
- Any known issues.
- Handoff information for the next developer.

Example:

```
Title:
Implement building generation with difficulty-based TTL

Changes:
- Added SelectDifficulty, RollFloorType, GenerateFloor, InitializeGame.
- Floor type rolled with RandomRange 100 against the difficulty's criticalPct.
- Critical TTL = normal TTL SHR 1; round penalty 5 s per round, minimum 10 s.
- Added tests/test_building.asm and registered it in TestMain.asm.

Files changed:
- src/Building.asm
- tests/test_building.asm
- tests/TestMain.asm

Testing:
- build.bat test: Passed 58, Failed 0
- 1000 rolls stay in FT_EMPTY..FT_ENERGY
- Normal / critical / energy floor contents and flags
- TTL never below MIN_TTL on Hard round 3

Known issues:
- None

Handoff:
- InitializeGame leaves elevatorFloor = LOBBY and clears all FLAG_SCANNED bits.
- GenerateFloor uses ESI as the floor pointer; it is preserved with USES.
```

### Review checklist

The reviewer checks that:

- [ ] `build.bat` and `build.bat test` succeed, with **ALL TESTS PASSED**.
- [ ] The change matches the day's task and does not touch unrelated files.
- [ ] Every procedure has a header comment (what it does, Receives, Returns).
- [ ] Every procedure preserves the registers it does not return (`USES` or `PUSH`/`POP`).
- [ ] No `.IF` / `.ELSE` / `.WHILE` / `.REPEAT` / `.BREAK` directives.
- [ ] No magic numbers: constants come from `Elevator.inc`.
- [ ] Logic modules do not print (only `Render.asm`, `Menu.asm`, the summary and the scoreboard screens draw).
- [ ] No build output (`build/`, `*.obj`, `*.exe`, `*.pdb`) or `data/highscores.dat` is included.

---

## 6. Coding Rules

### General
- Do not develop directly on `main`.
- Do not commit directly to `develop`. Use a Pull Request.
- Never commit build files (`build/`, `*.obj`, `*.exe`, `*.pdb`, `*.ilk`, `*.lst`).
- Do not change unrelated files.
- Do not change another member's code without discussing it with them first.
- Test your changes before opening a Pull Request.
- Do not add features outside the agreed scope without team agreement.

### Assembly
- **32-bit MASM with Irvine32.** Every `.asm` file starts with:
  ```asm
  INCLUDE Irvine32.inc
  INCLUDE Elevator.inc
  ```
  and ends with `END` (only `main.asm` has `END main`, and `TestMain.asm` has `END testMain`).
- **`include/Elevator.inc` is the contract.** All constants, structures, global variables (`EXTERNDEF`) and procedure prototypes (`PROTO`) live there. To change a prototype or a structure, tell the team first: it affects everybody.
- **All global variables are defined in `src/GameState.asm`.** Other modules may have their own private `.data` (messages, buffers).
- **No high-level control directives.** `.IF`, `.ELSE`, `.ELSEIF`, `.WHILE`, `.REPEAT`, `.UNTIL`, `.BREAK` and `.CONTINUE` are not used. Every decision is a visible `CMP` / `TEST` + conditional jump. This is a COAL project.
- **Use unsigned jumps (`JA`, `JB`, `JAE`, `JBE`) for unsigned values** (counts, energy, TTL, addresses) and signed jumps (`JG`, `JL`, `JGE`, `JLE`) only for signed values (directions, differences that can be negative).
- **Preserve registers.** A procedure changes only the registers it returns values in. Use `USES` or `PUSH` / `POP`.
- **Procedure header comment** on every procedure:
  ```asm
  ;---------------------------------------------------------------------
  ; MoveElevator
  ; Moves the elevator one floor if it is in range and energy allows.
  ; Receives: direction = +1 (up) or -1 (down)
  ; Returns:  EAX = 1 if moved, 0 if refused
  ;---------------------------------------------------------------------
  ```
- **No magic numbers.** Use the constants in `Elevator.inc` (`MOVE_COST`, not `2`).
- **Use structure field names**, not hand-calculated offsets:
  ```asm
  mov  ax, (FloorInfo PTR [esi]).ttlLeft      ; good
  mov  ax, [esi + 2]                          ; avoid
  ```
- **`LENGTHOF` / `SIZEOF` of an `EXTERNDEF` array is only ONE element** outside the module that defines it (array sizes are not passed between modules). Loop over `floors` with `NUM_FLOORS` and over `highScores` with `MAX_SCORES`, never with `LENGTHOF`. (`SIZEOF FloorInfo`, the size of the structure type, is fine everywhere.)
- **Logic modules never print.** `Building`, `Elevator`, `Scan`, `Shop` and the scoring part of `Score` update state and call `SetStatus` with a message. Drawing belongs in `Render.asm`. This keeps the logic testable.
- **Randomness only through Irvine32** (`RandomRange`, `Random32`). `Randomize` is called once, in `main.asm`.
- Meaningful names: `TickFloors`, not `tf`. Labels inside procedures describe the step: `notEnoughEnergy:`, not `L3:`.
- Keep procedures short. If a procedure is longer than about 60 lines, split it.
- Keep `main.asm` small. It only seeds the random generator, sets the title and starts the menu.

### Tests
- Every logic procedure gets tests in `tests/test_<module>.asm`, and a `call Test<Module>` in `TestMain.asm`.
- Use `mAssertEq actual, expected, "description"` (no commas inside the description).
- Tests may set globals directly before calling a procedure.
- Leave the globals the way you found them if other suites depend on them (for example, put `difficulty` back to `DIFF_NORMAL`).

---

## 7. Commit Message Style

Use descriptive, imperative messages:

```
Add project folder structure and build script
Implement string helpers with SCASB, CMPSB and STOSB
Implement floor generation with difficulty-based TTL
Implement elevator movement and energy cost
Add TTL tick with casualty handling
Implement recursive floor scan with manual stack frame
Add real-time game loop with ReadKey and GetMseconds
Draw building and HUD with Gotoxy and colours
Add lobby shop with credit checks
Implement round score with difficulty multiplier
Insert high scores with insertion sort and save to file
```

Avoid:

```
Update
Done
Final
Changes
test
fix
asdf
```

---

## 8. Build Before Pull Request

The project must build and pass its tests before you request a review:

```bat
build.bat test
build.bat run
```

If MASM is not found, install Visual Studio with **Desktop development with C++**, or run the command from a *Developer Command Prompt for VS (x86)*. If Irvine32 is not in `C:\Irvine`, `set IRVINE_DIR=<path>` first.

---

## 9. Merge Conflicts

If a merge conflict happens:

1. Do not delete someone else's work without checking it.
2. Read both versions.
3. Decide which code should stay. Ask the other author if you are unsure.
4. Remove the Git conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
5. Build and test again.
6. Commit the resolution.

Most conflicts will be in `Elevator.inc` and `TestMain.asm`, the two shared files. Keep your additions to them small and in the right section.

```bash
git status
git add <resolved-files>
git commit -m "Resolve merge conflict in <file>"
git push
```

---

## 10. Daily Handoff

At the end of each day, the owner adds a handoff note to the Pull Request description **and** posts it in the team group chat:

```
DAY:
DATE:
OWNER:

COMPLETED:

FILES CHANGED:

TESTS PERFORMED:

KNOWN ISSUES:

NEXT DEVELOPER:

NEXT TASK:

NOTES FOR NEXT DEVELOPER:
```

Example:

```
DAY: 1
DATE: Wed 18 Nov 2026
OWNER: Ali Hussain

COMPLETED:
- Folder structure, build.bat (game / run / test / clean), .gitignore, docs
- Elevator.inc: all constants, FloorInfo / DiffSetting / HighScore, EXTERNDEF globals, every PROTO
- GameState.asm: globals, difficulty table, GetDiffSetting, ResetGameState
- StrUtil.asm: StrLen, StrCopyN, StrEqual, StrFill, StrToUpper, StrPadRight
- Menu.asm: main menu + How to Play (New Game / High Scores are placeholders)
- Test framework (mAssertEq, mSuite) and TestMain runner

FILES CHANGED:
- include/Elevator.inc, src/*.asm, tests/*, build.bat, README.md, CONTRIBUTING.md

TESTS PERFORMED:
- build.bat test: Passed 33, Failed 0
- build.bat: ElevatorRescue.exe builds and the menu runs

KNOWN ISSUES:
- None

NEXT DEVELOPER: Ali
NEXT TASK: Day 2 - Building.asm

NOTES FOR NEXT DEVELOPER:
- Read the difficulty with "call GetDiffSetting", then (DiffSetting PTR [esi]).ttlMin etc.
- Loop over floors with NUM_FLOORS, not LENGTHOF floors (see CONTRIBUTING 6).
- RandomRange: EAX = n in, EAX = 0..n-1 out.
```

If a task is not finished, say so clearly. The next owner finishes it before starting their own task.

---

## 11. Scope Protection

Elevator Rescue Simulator is a **COAL** project. The assembly concepts are the focus, not the size of the game.

Do not add:

- Graphics outside the text console
- Mouse input
- Multiplayer or multiple elevators
- C / C++ code or extra libraries beyond Irvine32 and kernel32 / user32
- Floating-point arithmetic
- Features that don't demonstrate a course concept or improve the game in a visible way

unless the whole team, and the instructor where needed, agrees to the scope change.

The core project must stay stable.
