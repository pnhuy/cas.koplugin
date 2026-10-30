# Tasks: Offline Calculator with Symbolic Algebra and Function Graphing

**Input**: Design documents from `/specs/001-calculator-cas-graphing/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required by the constitution (Principle VI) for the pure engines (`calccas/`, `calcplot/`): Busted specs are written **before** the implementation they cover and must fail first. UI glue (`calcui/`, `main.lua`) is verified in the KOReader emulator/device via the quickstart checklist. Do not report any test as passing unless it was actually run.

**Organization**: Grouped by user story. Paths are relative to the repository root (the repo root *is* the plugin directory).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelizable (different files, no dependency on incomplete tasks)
- **[Story]**: US1 evaluate, US2 simplify/expand, US3 plot, US4 KOReader integration/session safety

## Phase 1: Setup

- [X] T001 Create directories `calccas/`, `calcplot/`, `calcui/`, `spec/calccas/`, `spec/calcplot/` and add `.busted` (lpath `./?.lua;./?/init.lua`, root `spec`) at `.busted`
- [X] T002 [P] Add Luacheck config (std `luajit`, globals `G_reader_settings`, `_`, read-only; exclude nothing else) at `.luacheckrc`
- [X] T003 [P] Install Busted (`brew install luarocks && luarocks install busted`) and confirm `busted --version` and `luacheck .` run; record the result in `README.md` "Development" section
- [X] T004 Obtain a KOReader source checkout (record its path and git tag in `specs/001-calculator-cas-graphing/research.md` under a new "T0 findings" heading) and verify every API in research R3 against it; update R3 rows with confirmed signatures and correct any that differ
- [X] T005 Confirm and record the minimum supported KOReader version based on T004 findings in `specs/001-calculator-cas-graphing/plan.md` (Technical Context) and `README.md`
- [X] T006 [P] Create `README.md` skeleton: purpose, install (copy/symlink to `plugins/calculator.koplugin`), syntax rules from research R2, limits, development commands

---

## Phase 2: Foundational (blocks all user stories)

**Purpose**: Plugin skeleton and the engine primitives every story uses.

- [X] T007 [P] Create `_meta.lua` returning `name = "calculator"`, `fullname`, `description` via gettext in `_meta.lua`
- [X] T008 Create `main.lua`: `WidgetContainer:extend{name="calculator", is_doc_only=false}`, `init()`, `addToMainMenu` adding a `Calculator` item under Tools that opens a placeholder `InfoMessage`, per verified APIs from T004, in `main.lua`
- [X] T009 [P] Write failing Busted spec for error constructors and kinds in `spec/calccas/errors_spec.lua`
- [X] T010 [P] Implement typed errors `{kind, message, pos}` and helper `err(kind, msg, pos)` in `calccas/errors.lua`
- [X] T011 [P] Implement limits constants (max chars 500, depth 50, nodes 2000, terms 500, evals 4000, refine depth 8, max functions 6) in `calccas/limits.lua`
- [X] T012 [P] Write failing Busted spec for rationals (normalization, add/sub/mul/div, pow with integer exponent, gcd, overflow beyond 2^53 → flagged float, division by zero) in `spec/calccas/rational_spec.lua`
- [X] T013 Implement exact rationals on doubles with overflow detection in `calccas/rational.lua`
- [X] T014 [P] Write failing Busted spec for the lexer (numbers incl. decimals, identifiers, operators, positions, illegal characters, `os.execute("x")`) in `spec/calccas/lexer_spec.lua`
- [X] T015 Implement lexer producing tokens with positions in `calccas/lexer.lua`
- [X] T016 [P] Write failing Busted spec for AST constructors, canonical ordering, flattening, structural equality in `spec/calccas/ast_spec.lua`
- [X] T017 Implement AST node constructors, canonical ordering and equality (per data-model) in `calccas/ast.lua`
- [X] T018 [P] Write failing Busted spec for the parser: precedence (`-2^2`, `2^3^2`, `2^-1`, `-x^2`), implicit multiplication rules, nested functions, parentheses, error positions (`2 +* 3` → pos 4, unbalanced parens, empty input), limit violations (long, deep, many nodes → `too_complex`) in `spec/calccas/parser_spec.lua`
- [X] T019 Implement recursive-descent parser per the grammar in `specs/001-calculator-cas-graphing/contracts/cas-api.md` in `calccas/parser.lua`
- [X] T020 [P] Create Busted fixtures of independently prepared reference cases (expression → expected value/text, computed by hand or with an external calculator and cited in comments) in `spec/calccas/reference_cases.lua`

**Checkpoint**: Skeleton plugin appears in Tools; parser tests green; Luacheck clean.

---

## Phase 3: User Story 1 - Evaluate a Mathematical Expression (P1) 🎯 MVP

**Goal**: Type an expression in the Calculator view and get an exact or approximate result, or a clear error.

**Independent Test**: Open Calculator from Tools; evaluate `2 + 3*4`, `1/3 + 1/6`, `sqrt(2)`, `-2^2`, `1/0`, `2 +* 3`, `os.execute("x")`.

### Tests for User Story 1

- [X] T021 [P] [US1] Write failing Busted spec for exact/approx evaluation using `reference_cases.lua`: arithmetic, rationals, decimals, constants `pi`/`e`, functions, variable assignments, unbound variable error in `spec/calccas/eval_spec.lua`
- [X] T022 [P] [US1] Write failing Busted spec for math errors: `1/0`, `0^0`, `0^-1`, `sqrt(-1)`, `log(0)`, `tan(pi/2)`, `10^1000`, `9^9^9` (each with correct `kind`, no hang) in `spec/calccas/eval_errors_spec.lua`
- [X] T023 [P] [US1] Write failing Busted spec for the printer (deterministic output, minimal parentheses, rational and `≈` decimal format) in `spec/calccas/printer_spec.lua`
- [X] T024 [P] [US1] Write failing Busted spec for the facade `calccas` (`parse`, `evaluate`, `compile`, `tostring`; no function throws on arbitrary garbage strings, including fuzzed input) in `spec/calccas/init_spec.lua`

### Implementation for User Story 1

- [X] T025 [US1] Implement exact + float evaluation, math error mapping, and `compile(ast, varname)` closure builder (no `load`) in `calccas/eval.lua`
- [X] T026 [US1] Implement deterministic infix printer in `calccas/printer.lua`
- [X] T027 [US1] Implement facade (`parse`, `evaluate`, `compile`, `tostring`, `pcall`-guarded, limits enforced) in `calccas/init.lua`
- [X] T028 [US1] Implement Calculator view: expression input, variables field, keypad row (`^ ( ) / sqrt( pi ⌫`), Evaluate/Simplify/Graph/Close buttons, scrollable result area, error display with caret position, in `calcui/calculator_view.lua`
- [X] T029 [US1] Wire Tools menu item to open the Calculator view and wire Evaluate to `calccas.evaluate` (Simplify and Graph buttons disabled with "coming soon" until US2/US3) in `main.lua`
- [X] T030 [US1] Verify US1 in the emulator using the quickstart steps 1–2 and 7; record outcome in `specs/001-calculator-cas-graphing/quickstart.md` notes

**Checkpoint**: US1 independently functional and demonstrable.

---

## Phase 4: User Story 2 - Simplify and Expand Expressions (P1)

**Goal**: Simplify and expand algebraic expressions with domain-safe, deterministic results.

**Independent Test**: `simplify(2*x+3*x) → 5*x`, `simplify(x*1) → x`, `expand((x+1)^2) → x^2+2*x+1`, `x/x` keeps its restriction, repeated runs identical.

### Tests for User Story 2

- [X] T031 [P] [US2] Write failing Busted spec for constant folding, neutral elements (`x*1`, `x+0`, `x^1`, `x^0` with domain note), like-term collection in `spec/calccas/simplify_spec.lua`
- [X] T032 [P] [US2] Write failing Busted spec for expansion (`(x+1)^2`, `(x+1)*(x-1)`, `(a+b)^3`, term-limit → `too_complex`) in `spec/calccas/expand_spec.lua`
- [X] T033 [P] [US2] Write failing Busted spec for domain safety (`x/x` not cancelled and flagged `x ≠ 0`, `sqrt(x^2)` not rewritten to `x`, `(x^a)^b` only with integer `b`) in `spec/calccas/domain_safety_spec.lua`
- [X] T034 [P] [US2] Write failing Busted spec for determinism and equivalence (simplify twice → identical; numeric spot-check original vs simplified at 20 fixed sample points within 1e-9) in `spec/calccas/equivalence_spec.lua`

### Implementation for User Story 2

- [X] T035 [US2] Implement simplify passes (fold → flatten → collect like terms → neutral elements → canonical sort) with assumptions list in `calccas/simplify.lua`
- [X] T036 [US2] Implement polynomial expansion with result-size limit in `calccas/simplify.lua`
- [X] T037 [US2] Expose `simplify`, `expand`, and top-level `simplify(...)`/`expand(...)` text wrappers in `calccas/init.lua`
- [X] T038 [US2] Wire Simplify button and assumptions note display in `calcui/calculator_view.lua` and `main.lua`
- [X] T039 [US2] Verify US2 in the emulator (quickstart step 3) and record outcome in `specs/001-calculator-cas-graphing/quickstart.md` notes

**Checkpoint**: US1 and US2 work independently.

---

## Phase 5: User Story 3 - Plot Functions on a Graph (P1)

**Goal**: Plot several y=f(x) curves with axes, grid, ticks, configurable ranges, correct handling of undefined regions and discontinuities.

**Independent Test**: Reference plots (`x`, `x^2`, `sin(x)`, `1/x`, `tan(x)`, `log(x)`, `sqrt(x)`, `1/(x-1)`) match the expectations in `contracts/plot-api.md`; in the emulator two functions are distinguishable and ranges can be changed.

### Tests for User Story 3

- [X] T040 [P] [US3] Write failing Busted spec for viewport validation, math↔screen transforms (round-trip within 1e-9), reset/default, invalid ranges (`xmin>=xmax`, NaN, huge) in `spec/calcplot/viewport_spec.lua`
- [X] T041 [P] [US3] Write failing Busted spec for nice ticks (steps 1/2/5×10^k, label formatting, tiny and huge ranges) in `spec/calcplot/ticks_spec.lua`
- [X] T042 [P] [US3] Write failing Busted spec for segment clipping (inside, outside, crossing, touching edges, degenerate) in `spec/calcplot/clip_spec.lua`
- [X] T043 [P] [US3] Write failing Busted spec for sampling: undefined/NaN/inf skipped, adaptive refinement on `sin(1/x)` bounded by 4000 evals and depth 8, determinism in `spec/calcplot/sampler_spec.lua`
- [X] T044 [P] [US3] Write failing Busted spec for the eight reference plots with break counts and shape checks per `contracts/plot-api.md` in `spec/calcplot/reference_plots_spec.lua`
- [X] T045 [P] [US3] Write failing Busted spec for the resumable job (step budget respected, cancel, result stable across step sizes, auto-Y with percentile trim) in `spec/calcplot/plot_spec.lua`

### Implementation for User Story 3

- [X] T046 [P] [US3] Implement viewport validation, transforms, defaults, auto-Y in `calcplot/viewport.lua`
- [X] T047 [P] [US3] Implement nice tick generation in `calcplot/ticks.lua`
- [X] T048 [P] [US3] Implement Liang–Barsky segment clipping in `calcplot/clip.lua`
- [X] T049 [US3] Implement uniform + adaptive sampling and pole/domain discontinuity detection in `calcplot/sampler.lua`
- [X] T050 [US3] Implement resumable plot job producing clipped screen-space polylines in `calcplot/plot.lua`
- [X] T051 [US3] Implement engine facade in top-level `calcplot.lua` (KOReader has no `?/init.lua` on the plugin path)
- [X] T052 [US3] Implement graph canvas widget: cached `Blitbuffer`, Bresenham line drawing over `paintRect`, six line styles, axes, grid, tick labels, region-only refresh, cache key per research R7, buffer freed on close, in `calcui/graph_canvas.lua`
- [X] T053 [US3] Implement function list dialogs: add, edit, show/hide, remove, per-function error marker, max 6 functions, in `calcui/function_list.lua`
- [X] T054 [US3] Implement Graph view: title bar, canvas, button row (Functions, Range, Reset, Calculator, Close), range dialog with validation and Auto-Y/Grid toggles, "Plotting…" status, tick-driven job stepping with cancel, in `calcui/graph_view.lua`
- [X] T055 [US3] Wire the Graph button in the Calculator view and keep function list in session state in `calcui/calculator_view.lua` and `main.lua`
- [X] T056 [US3] Verify US3 in the emulator (quickstart steps 4–6) and on a grayscale rendering; record outcome in `specs/001-calculator-cas-graphing/quickstart.md` notes

**Checkpoint**: All three engines-backed stories work independently.

---

## Phase 6: User Story 4 - Use the Plugin Inside KOReader Without Disrupting Reading (P1)

**Goal**: Well-behaved lifecycle, persistence, orientation, input methods, and zero impact on the reading session.

**Independent Test**: Open a book, launch the plugin, use both views, rotate, close; reading position, book file and annotations unchanged; settings survive restart.

- [X] T057 [P] [US4] Write failing Busted spec for settings load/save fallback with corrupt or missing values (pure logic part extracted so it runs without KOReader) in `spec/calcplot/settings_logic_spec.lua`
- [X] T058 [US4] Implement settings wrapper (`LuaSettings`, viewport + grid, defaults on invalid data, `flush` on change and close) in `calcui/settings.lua`
- [X] T059 [US4] Persist and restore viewport and grid from Graph view via `calcui/settings.lua` in `calcui/graph_view.lua`
- [X] T060 [US4] Keep expression, variables, and function list in session state across closing and reopening in `main.lua`
- [ ] T061 [US4] Handle screen-size/orientation change by rebuilding layout and invalidating the canvas cache in `calcui/calculator_view.lua` and `calcui/graph_view.lua`
- [ ] T062 [US4] Add physical-key support (feature-detected with `Device:hasKeys()`): Back closes view, page keys scroll result/list in `calcui/calculator_view.lua` and `calcui/graph_view.lua`
- [ ] T063 [US4] Ensure close paths cancel pending ticks, free buffers, flush settings, and refresh the underlying screen without touching the document or its sidecar, in `calcui/graph_view.lua`, `calcui/calculator_view.lua`, and `main.lua`
- [ ] T064 [US4] Wrap all user-triggered actions in `pcall` showing an "Internal error" message and logging only non-sensitive info (e.g., expression length) in `main.lua`
- [ ] T065 [US4] Run the full emulator checklist (quickstart steps 1–9), including a before/after comparison of the book's page, sidecar file, and annotations; record results in `specs/001-calculator-cas-graphing/quickstart.md` notes

**Checkpoint**: All MVP acceptance criteria (spec §13) verifiable.

---

## Phase 7: Polish & Cross-Cutting

- [ ] T066 [P] Add large-expression and resource-limit tests (500-char, deeply nested, 10^6-term expansion attempt, pathological `sin(1/x)` plot) with time ceilings in `spec/calccas/limits_spec.lua` and `spec/calcplot/limits_spec.lua`
- [X] T067 [P] Add fuzz-style no-throw test for `calccas` over 2000 deterministic pseudo-random strings in `spec/calccas/init_spec.lua`
- [X] T068 [P] Run `luacheck .` and fix all warnings across the repository
- [X] T069 [P] Run the whole Busted suite, then record the actual pass/fail counts in `README.md` "Development" section
- [ ] T070 [P] Measure evaluate/simplify and 4-function plot timings against SC-004/SC-005 on the emulator and, if available, a real device; record in `specs/001-calculator-cas-graphing/quickstart.md` notes
- [ ] T071 Finalize `README.md` (purpose, install, usage, syntax and ambiguity rules, limits, supported KOReader version, platform notes) so it matches implemented behavior
- [ ] T072 Add gettext template extraction note and ensure all user strings are wrapped in `_()` across `calcui/` and `main.lua`

---

## Dependencies & Execution Order

- **Phase 1 → Phase 2 → stories.** T004/T005 (API verification) gate every `calcui/` and `main.lua` task.
- **US1** depends only on Phase 2. **US2** depends on Phase 2 and the facade from US1 (T027); simplify engine files are otherwise independent. **US3** needs `compile` from US1 (T025) but not US2. **US4** tasks refine views from US1/US3 and can start once those views exist (T028, T054).
- Within a story: tests first (must fail) → engine modules → UI wiring → emulator verification.
- US1 → {US2, US3} can run in parallel after US1 engine tasks (T025–T027); US4 last.

## Parallel Examples

```text
# After Phase 2, US1 tests together:
T021, T022, T023, T024
# US3 engine tests together, then independent modules together:
T040–T045  →  T046, T047, T048
# Polish checks together:
T066, T067, T068, T069, T070
```

## Implementation Strategy

1. **MVP slice**: Phase 1 + 2 + US1 (evaluate) — a working calculator in Tools.
2. Add US2 (simplify) and US3 (graph) in either order; both are separately demonstrable.
3. Finish with US4 hardening and Polish; run the full acceptance checklist before declaring the MVP done.
4. P2/P3 features from the original description are **not** in this task list; specify and plan them separately after the MVP works.

## Notes

- Do not claim a test passes until it has been run (constitution VI). T003 must succeed before any "tests pass" statement.
- Commit after each task or logical group; keep changes focused (constitution IX).
