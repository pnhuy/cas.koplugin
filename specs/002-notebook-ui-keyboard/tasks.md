# Tasks: Notebook Interface and Programming Keyboard

**Input**: Design documents from `/specs/002-notebook-ui-keyboard/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (all present)

**Tests**: Busted tests are REQUIRED for all logic in `calcnb/` and pure parts of `calcui/` (Constitution VI) and are written before the code they cover. Widget code is verified by hand in the emulator; results go in `quickstart.md`, and nothing is claimed as tested unless it was run.

**Organization**: Grouped by user story. Story numbers follow spec.md (US1 cells, US2 keyboard, US3 graphs, US4 persistence, US5 organize, US6 notes). Phase order differs from number order: the keyboard (US2) is built before the notebook (US1) because cells cannot be exercised without it.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- Commands run from the repo root with `export PATH=$HOME/.luarocks-luajit/bin:$PATH`; do not use Python.
- Emulator: `.../scratchpad/koreader/run.sh`, restart after every change.

---

## Phase 1: Setup and Spikes

**Purpose**: Resolve the three unverified items from research.md before design is locked.

- [X] T001 Add `calcnb` to the luacheck file list and create empty `calcnb/` and `spec/calcnb/` directories; update the lint command in `README.md` and `specs/002-notebook-ui-keyboard/quickstart.md`
- [X] T002 Spike R2: in `calcui/cell_editor.lua` subclass `ui/widget/inputtext` with an `initKeyboard` override installing a stub (`isVisible`, `showKeyboard`, `hideKeyboard`, `lockVisibility`, `free`, `dimen`); read every use of `self.keyboard` in `<koreader>/frontend/ui/widget/inputtext.lua` and list them in `research.md` R2; show it in a scratch dialog in the emulator and confirm typing via `addChars`, cursor moves, no system keyboard, no errors in `kodev-run.log`; record pass/fail in `quickstart.md`. If it fails, record the fallback decision (plugin-owned editor)
- [X] T003 [P] Spike R5: read `calccas/parser.lua` and `calccas/eval.lua` and record in `research.md` R5 how an unknown call `f(2)` is handled, and pick option (a) or (b)
- [X] T004 [P] Spike R11: render `○ ✎ … ✓ ✕ ◐ ▸ ↑ ↓ ←  → ⏎ ⌫ π` in a scratch widget in the emulator; record which glyphs are missing and the ASCII fallbacks in `research.md` R11

**Checkpoint**: editor approach, user-function approach and glyph set are decided.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Pure model, language layer and engine hooks used by every story.

- [X] T005 [P] Write failing specs `spec/calcnb/statement_spec.lua` for `contracts/notebook-language.md`: classify assign/funcdef/plot/expr, comments and blank lines, line numbers, reserved and invalid names, plot args and `a..b` range, error positions
- [X] T006 Implement `calcnb/statement.lua` (`parse(source)` returning statements or `nil, err`) using the existing `calccas` lexer only, never `load`
- [X] T007 [P] Write failing specs `spec/calcnb/env_spec.lua`: set/get variables and functions, reserved names, 100-name cap, `snapshot()`/`restore()`
- [X] T008 Implement `calcnb/env.lua`
- [X] T009 Per the T003 decision, write failing specs in `spec/calccas/init_spec.lua` (and `spec/calcnb/` if option b) for evaluating `f(2)` and `f(x+1)` with a stored function, then implement it in `calccas.lua`/`calccas/eval.lua` or `calcnb/runner.lua`; engine stays free of KOReader requires
- [X] T010 [P] Add `calccas.functions()` to `calccas.lua` returning the supported function names (R12); spec in `spec/calccas/init_spec.lua`
- [X] T011 [P] Write failing specs `spec/calcnb/output_spec.lua`: value/error/graph outputs, canonical vs display text (`x^2` to `x²`, `x_1` to `x₁`), truncation at 600 chars, canonical text re-parses to the same value
- [X] T012 Implement `calcnb/output.lua`
- [X] T013 [P] Write failing specs `spec/calcnb/runner_spec.lua`: multi-line cell, last statement is the result, assignment visible to later cells, failed line rolls the environment back, empty cell message, limits message, `plot` returns a graph output with at most 6 functions, `sin = 3` and `pi = 3` rejected
- [X] T014 Implement `calcnb/runner.lua` (`run(cell_source, env)` returning an Output; yields between statements so it can be a coroutine)
- [X] T015 [P] Write failing specs `spec/calcnb/notebook_spec.lua`: add above/below, duplicate (no output), delete (last cell leaves one empty cell), move, set_source marks `out_of_date`, ids never reused, 200-cell cap, CRLF/tab normalization, invalid UTF-8 rejected, staleness rules (earlier cell changed a name, reorder, delete)
- [X] T016 Implement `calcnb/notebook.lua` per data-model.md

**Checkpoint**: `busted` and `luacheck` pass for the pure layer.

---

## Phase 3: User Story 2 - On-screen programming keyboard (Priority: P1)

**Goal**: Every supported expression can be typed with the on-screen keyboard; shortcuts place the cursor inside the brackets; nothing runs while typing.

**Independent Test**: In a scratch editor with no hardware keyboard, type `f(x) = x^2 + a*x` and a second line `plot(sin(x), x=-6..6)`, then insert `sin` after `x^2 + `.

### Tests

- [X] T017 [P] [US2] Write failing specs `spec/calcnb/keyboard_layout_spec.lua` for the four invariants in `contracts/keyboard-layout.md` (every printable ASCII except backtick and tilde reachable without long-press, `pi` key, no key with newline except Enter, compact layout keeps the union of keys)
- [X] T018 [P] [US2] Write failing specs `spec/calcnb/shortcuts_spec.lua`: groups built from `calccas.functions()` plus `expand`, `simplify`, `plot`; `diff solve factor integrate limit asin acos atan plot2 parametric polar` absent; each `insert` ends with `()` and `back == 1`; empty groups hidden
- [X] T019 [P] [US2] Write failing specs `spec/calcui/keyboard_sizing_spec.lua` for a pure `calcui/keyboard_sizing.lua`: key height and row count give 35-55% of the height in portrait and landscape for 540x720, 720x540 and a small 300x400 screen, and never below the minimum touch size

### Implementation

- [X] T020 [US2] Implement `calcnb/keyboard_layout.lua` (pages `letters`, `shift`, `symbols`; compact variant)
- [X] T021 [US2] Implement `calcnb/shortcuts.lua`
- [X] T022 [US2] Implement `calcui/keyboard_sizing.lua` (pure)
- [X] T023 [US2] Finish `calcui/cell_editor.lua` from T002: multiline, `onTextInput` disabled paths checked, `insert_shortcut(shortcut)` (`addChars` then `leftChar` x back), selection and clipboard helpers using `Device:hasClipboard()`
- [X] T024 [US2] Implement `calcui/keyboard.lua`: `ButtonTable` per page, Shift one-shot, Sym toggle, shortcut group switch, editing and cursor keys per the contract, state preserved when switching pages, `guard.wrap` on callbacks, rebuilds only the keyboard on page change
- [X] T025 [US2] Scratch harness in `calcui/keyboard_demo.lua` (temporary, opened from a dev-only menu item) showing editor plus docked keyboard; verify in the emulator: all keys, uppercase, multi-byte backspace with `π` text, selection/copy/paste, dismiss and reopen, rapid taps, no evaluation while typing; record in `quickstart.md`. Remove the demo and menu item before US1 is accepted

**Checkpoint**: keyboard verified by hand in the emulator; logic tests green.

---

## Phase 4: User Story 1 - Notebook cells (Priority: P1) 🎯 MVP

**Goal**: A scrollable notebook of code cells that run and show results, errors and status below each cell.

**Independent Test**: Run `a = 2`, `a^2 + 1`, `expand((x+1)^2)` and verify results `2`, `5`, `x² + 2x + 1`, then `sin(` shows an error.

### Tests

- [X] T026 [P] [US1] Write failing specs `spec/calcui/cell_status_spec.lua` for a pure `calcui/cell_status.lua`: status to symbol and text label (with ASCII fallback from T004), editing overlay does not replace a stored status
- [X] T027 [P] [US1] Write failing specs `spec/calcui/notebook_layout_spec.lua` for a pure `calcui/notebook_layout.lua`: given cell heights, viewport height and top index returns the visible cells, page up/down, active cell scrolled into view above the keyboard, top index kept after resize
- [X] T028 [P] [US1] Write failing specs `spec/calcnb/run_queue_spec.lua` for `calcnb/run_queue.lua`: one run at a time, second request rejected, Run all in order continuing past errors, cancel on close

### Implementation

- [X] T029 [US1] Implement `calcui/cell_status.lua`, `calcui/notebook_layout.lua`, `calcnb/run_queue.lua`
- [X] T030 [US1] Implement `calcui/cell_widget.lua`: input indicator `In [n]`, source (editor when active, static text otherwise), status line, output area (value, error, truncated with Expand, out-of-date marker), Run button
- [X] T031 [US1] Implement `calcui/notebook_view.lua`: `TitleBar`/toolbar (title, Add, Save placeholder, Menu, Close), windowed cell list, page buttons and page-turn keys, keyboard docking (notebook area shrinks, active cell and cursor visible), tap cell to edit, Enter inserts newline, Run and Run-and-add, Run all and Clear all outputs in the menu, runs stepped with `UIManager:nextTick` and a 50 ms budget, `guard.wrap` on every callback
- [X] T032 [US1] Update `main.lua` so Tools > Calculator opens the notebook; add "Classic calculator" and "Classic graph" entries inside the notebook Menu so the 001 screens stay reachable (plan: retire later)
- [X] T033 [US1] Emulator check of US1 acceptance scenarios 1-9 and edge cases (empty cell, Run while running, Run all with errors, name redefinition marks stale); record in `quickstart.md`

**Checkpoint**: notebook usable end to end without graphs or persistence.

---

## Phase 5: User Story 3 - Inline graphs and viewer (Priority: P1)

**Goal**: `plot(...)` cells show an inline graph; tapping opens the full-screen viewer with button controls.

**Independent Test**: `plot(sin(x), cos(x))`, expand, zoom twice, pan once, set X -3..3, close, same cell and scroll position.

### Tests

- [X] T034 [P] [US3] Re-read `calcplot/viewport.lua` and list its zoom/pan helpers in `research.md` R9; write failing specs `spec/calcplot/viewport_spec.lua` for any missing helper (zoom about centre, pan by a fraction, equal-scale correction, per-cell viewport round trip)
- [X] T035 [P] [US3] Write failing specs `spec/calcui/graph_model_spec.lua` additions: build a graph state from a plot output (functions, x range), validate range edits, equal-scale option

### Implementation

- [X] T036 [US3] Add the missing viewport helpers to `calcplot/viewport.lua` (no KOReader requires)
- [X] T037 [US3] Implement `calcui/graph_output.lua`: inline canvas sized to cell width using `calcui/graph_canvas.lua`, viewport text, Expand button, plot job stepped from ticks, cached by `graph_model.cache_key`, canvas freed when the cell leaves the viewport
- [X] T038 [US3] Extend `calcui/graph_view.lua`: Zoom in/out, Pan x4, Reset, Range (with Auto Y and equal scale), Grid and Axes toggles, legend of plotted functions; on close return the chosen viewport to the cell and restore notebook scroll position
- [X] T039 [US3] Emulator check of US3 scenarios 1-9 including `1/x`, `tan(x)`, invalid plot argument, grayscale distinguishability of two curves (screenshot); record in `quickstart.md`

---

## Phase 6: User Story 4 - Persistence and lifecycle (Priority: P1)

**Goal**: The notebook survives restarts, damaged files never crash, and reading data is untouched.

**Independent Test**: Create three cells with a plot, save, restart, reopen, corrupt the file, reopen.

### Tests

- [X] T040 [P] [US4] Write failing specs `spec/calcnb/store_logic_spec.lua` for `contracts/notebook-file.md`: round trip of title, order, ids, types, sources, viewports and scroll; wrong type, missing keys, non-string sources, invalid UTF-8, duplicate/missing ids, over-limit cells and text, unknown newer `version`; always returns a usable notebook plus problems; `to_data` yields plain tables only
- [X] T041 [P] [US4] Write failing specs `spec/calcnb/dirty_spec.lua` for `calcnb/dirty.lua`: dirty flag set by edits and structure changes, cleared by a successful save, kept by a failed save

### Implementation

- [X] T042 [US4] Implement `calcnb/store_logic.lua` and `calcnb/dirty.lua`
- [X] T043 [US4] Implement `calcui/notebook_store.lua` (`LuaSettings` load/save with `pcall`, `logger.warn`, failure message, keeps notebook dirty on failure, delete with `ConfirmBox`)
- [X] T044 [US4] Wire Save, autosave on Close and on `onCloseWidget`, problems message on load, restore scroll position, outputs absent after load; Menu items New, Open, Save as map to the single default notebook (or are hidden) per the spec assumption
- [X] T045 [US4] Implement `onScreenResize` in `calcui/notebook_view.lua` (rebuild keyboard and layout, keep text, cursor, top cell) and the Back key close path when `Device:hasKeys()`; closing returns to the reading session
- [X] T046 [US4] Emulator check of US4 scenarios 1-8: save and restart, truncate and empty the file, simulated failed write (read-only settings directory), book `.sdr` checksums before and after, log has no errors; rotation if it can be tested, otherwise state it is unverified in `quickstart.md`

---

## Phase 7: User Story 5 - Organize and reuse (Priority: P2)

**Goal**: Add above/below, duplicate, move, delete with confirmation, copy source/result, insert result, clear outputs.

**Independent Test**: With four cells duplicate one, move it up, delete another with confirmation, copy a result and paste it into a new cell.

- [X] T047 [P] [US5] Write failing specs `spec/calcnb/cell_actions_spec.lua` for `calcnb/cell_actions.lua`: copy source/result text, insert result at the cursor, delete confirmation required only when the cell has content
- [X] T048 [US5] Implement `calcnb/cell_actions.lua` and the per-cell action row and context menu (`ButtonDialog`) in `calcui/cell_widget.lua` and `calcui/notebook_view.lua`, using `Device.input.setClipboardText`
- [X] T049 [US5] Emulator check of US5 scenarios 1-8; record in `quickstart.md`

---

## Phase 8: User Story 6 - Text cells and inspection (Priority: P3)

**Goal**: Plain-text note cells and x-value inspection in the graph viewer. Start only after phases 3-7 are verified.

- [X] T050 [P] [US6] Write failing specs: text cells are skipped by Run all, persisted and restored (`spec/calcnb/notebook_spec.lua`, `spec/calcnb/store_logic_spec.lua`); inspection returns `y` or "undefined" (`spec/calcui/graph_model_spec.lua`)
- [X] T051 [US6] Implement text cells in `calcnb/notebook.lua`, `calcui/cell_widget.lua`, and inspection in `calcnb`/`calcui/graph_view.lua`
- [X] T052 [US6] Emulator check of US6 scenarios 1-2; record in `quickstart.md`

---

## Phase 9: Polish and Cross-Cutting

- [X] T053 [P] Fuzz and limit specs `spec/calcnb/fuzz_spec.lua`: at least 50 invalid or hostile cell sources (SC-006) never throw; 200-char typing never evaluates (SC-004, pure editor-state test)
- [X] T054 [P] Gettext check: run a script (Lua or shell, no Python) listing every `_("...")` in the new files and confirm none are built by concatenation
- [X] T055 Run `busted` and `luacheck` over the whole tree; record the actual counts in `README.md` and `quickstart.md`
- [X] T056 Measure in the emulator: 100-cell scroll responsiveness (SC-013), 4-function plot time (SC-010), tap latency while plotting; record numbers and state that device timing is unmeasured
- [X] T057 Update `README.md`: notebook usage, keyboard, language, file location, limitations (no `diff`/`solve`/etc., no outputs persisted, no gestures), minimum KOReader version; remove stale 001 text
- [X] T058 Decide and record the fate of the 001 Calculator and Graph screens (retire from the notebook Menu or keep) in `plan.md`
- [X] T059 Run the full `quickstart.md` checklist, update its results table honestly, and list what remains unverified (rotation, physical keys, grayscale and refresh behavior, real devices)

---

## Dependencies and Order

- Phase 1 (spikes) gates everything. T002 gates Phase 3; T003 gates T009; T004 gates T026.
- Phase 2 gates Phases 3-8. Within it, each test task precedes its implementation.
- Phase 3 (US2) before Phase 4 (US1). Phase 5 (US3) needs Phase 4. Phase 6 (US4) needs Phase 4 and graph viewports from Phase 5. Phase 7 needs Phase 4. Phase 8 needs Phases 3-7 verified.
- Open feature-001 tasks (T061-T065 and polish in `specs/001-calculator-cas-graphing/tasks.md`) are independent and may be finished before or after this feature; they are not required for it.

## Parallel Examples

- Phase 1: T003 and T004 together after T002 starts.
- Phase 2: T005, T007, T010, T011, T013, T015 are separate spec files and can be written together; implementations follow in file order.
- Phase 3: T017, T018, T019 together.
- Phase 4: T026, T027, T028 together.

## Implementation Strategy

**MVP**: Phases 1-4 give a working notebook with the keyboard; add Phase 5 (graphs) and Phase 6 (persistence) to meet the spec's MVP list, then stop and verify on a device. Phases 7-8 are P2/P3 and optional for the first release. Verify each phase in the emulator before starting the next, and commit per phase.
