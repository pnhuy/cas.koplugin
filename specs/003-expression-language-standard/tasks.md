# Tasks: Expression Language Standard

**Input**: `specs/003-expression-language-standard/` (plan.md, spec.md, audit.md, research.md, data-model.md, contracts/, quickstart.md)
**Tests**: Requested (spec FR-028, SC-002..SC-005; constitution VI). Every implementation task has its failing test written first.
**Commands** (repo root): `export PATH=$HOME/.luarocks-luajit/bin:$PATH`, then `busted` and
`luacheck --no-color main.lua _meta.lua calccas.lua calcplot.lua calccas calcplot calcnb calcui spec`.
Never run Python. Never claim a pass that was not run. Do not commit unless asked.

**Order note**: the spec lists US1 (reference) first, but a reference can only be written once the grammar is implemented, so the
phases run US2, US1, US3, US4. All four stories stay independently testable.

## Format: `- [ ] T### [P?] [US?] Description with file path`

---

## Phase 1: Setup

- [X] T001 Run `busted` and `luacheck` from the repo root and record the real counts as the baseline in `specs/003-expression-language-standard/quickstart.md` (replace the "do not quote 641" note with the recorded numbers).
- [X] T002 Capture the pre-change behaviour corpus BEFORE any code change: write a scratchpad luajit script that runs every source from `spec/calccas/reference_cases.lua`, the sources in `spec/calcnb/statement_spec.lua`, `spec/calcnb/runner_spec.lua`, the README examples and the 100-cell generator (`$S/gen100.lua` patterns) through `calcnb.runner` with the old code, and writes `spec/calcnb/compat_corpus.lua` as `{ {source=..., old={kind="ok", display=...} | {kind="error", error_kind=...}}, ... }`. Commit-free; file is data only.

**Checkpoint**: baseline numbers recorded; corpus file exists and loads with `dofile`.

---

## Phase 2: Foundational (blocks all stories)

The registry lands first with no syntax change, so each later step keeps the suite green.

- [X] T003 [P] Write the failing drift test `spec/calccas/registry_spec.lua` per [contracts/registry.md](contracts/registry.md) rule 5: every registry name is reserved by the notebook layer; every shortcut and keyboard command exists in the registry; every `implemented` function has an implementation in `calccas/eval.lua`; reserved-name set equals registry names plus aliases (`ln`).
- [X] T004 Create `calccas/registry.lua` with the entries in the contract table (fields `name, kind, arity, status, args, group, since, alias_of`) and the views `functions()`, `commands()`, `reserved_names()`, `get(name)`.
- [X] T005 Re-point the name lists to the registry: `parser.FUNCTIONS` in `calccas/parser.lua`, the function table keys in `calccas/eval.lua`, `FUNCTION_NAMES` in `calccas.lua`, and `RESERVED` in `calcnb/statement.lua` (this adds `factor solve diff integrate subs approx` to the reserved set, compatibility row C-3). Update the one assertion in `spec/calcnb/statement_spec.lua` that lists reserved names.
- [X] T006 Derive the command list and groups in `calcnb/shortcuts.lua` from `registry.commands()`; update `spec/calcnb/shortcuts_spec.lua` so reserved commands are offered only if the registry says so (decision: reserved commands are NOT offered on the keyboard, SC-007).
- [X] T007 Run `busted` and `luacheck`; fix regressions. Checkpoint: only the T005/T006 spec rows changed.

---

## Phase 3: User Story 2 - Predictable parsing, checked by conformance tests (P1)

**Goal**: the lexer, parser and AST implement the grammar in [contracts/grammar.md](contracts/grammar.md), and the notebook layer uses them.
**Independent test**: `busted spec/calccas/conformance_spec.lua` passes, and the coverage check reports every `G-nn` with an accepted case and (where violable) a rejected case.

### Tests first (must fail before T015)

- [X] T008 [P] [US2] Add `ast.dump(node)` to `calccas/ast.lua` (S-expression text such as `(add 1 (mul 2 x))`, deterministic) with unit tests in `spec/calccas/ast_spec.lua`. Needed so conformance cases compare structure without a printer.
- [X] T009 [P] [US2] Write `spec/calccas/conformance_cases.lua`: `{ id = "G-45-a", source = "2^3^2", expect = "(pow 2 (pow 3 2))" }` or `expect = { error = "syntax", fragment = "..." }`, one accepted case per rule and one rejected case for every rule that can be violated in [grammar.md](contracts/grammar.md) (G-01 to G-64, the evaluation-facing rules G-60..G-64 as evaluator-level cases flagged `eval = true`). Include the examples from the spec's edge cases and every reference example.
- [X] T010 [US2] Write `spec/calccas/conformance_spec.lua`: runs each case through `calccas.parse_program`; reads `contracts/grammar.md` and fails if any `G-nn` has no accepted case, or (for rules marked violable in the case file's `rejects` list) no rejected case. Depends on T009.
- [X] T011 [P] [US2] Add hostile-input cases to the conformance file (at least 100 distinct inputs: stray `=`, `..`, `#` in odd places, unbalanced brackets over newlines, 400-character exponents, control characters, invalid UTF-8) with `expect = { error = any }` and a runner in `spec/calccas/conformance_spec.lua` that asserts none raises a Lua error and none returns a result with a statement kind it should not.

### Implementation

- [X] T012 [US2] Extend `calccas/lexer.lua` (G-01..G-11): tokens `comma`, `eq`, `eqeq`, `dotdot`, `newline`; `#` comments; `line` on every token; number tokens with exponent (`1e3`, `1E-3`, `.5e2`); malformed exponent (`2e`, `1e+`) is a syntax error; `1..2` lexes as `1`, `..`, `2`. Update `spec/calccas/lexer_spec.lua`.
- [X] T013 [US2] Add nodes `rel`, `call`, `range`, `assign`, `funcdef` to `calccas/ast.lua` with constructors, structural equality, and support in `children`, `substitute`, `count`, `depth` (data-model.md). Tests in `spec/calccas/ast_spec.lua`.
- [X] T014 [US2] Implement continuation in the lexer (G-30..G-34): track bracket depth; suppress `newline` inside brackets and after a binary operator, `=`, `==` or `,`; skip blank and comment-only lines; unterminated brackets or operators at end of cell give `unexpected end of input`.
- [X] T015 [US2] Parser, program and statements in `calccas/parser.lua` (G-20..G-29): `parse_program(text, overrides)` returns `{ {line, node}, ... }`; classify assignment, function definition (1 to 4 distinct non-reserved parameters), relation, expression; reject `a == b == c`, `a = b == c`, a lone `=` in an expression, reserved targets (G-27). Keep `parse(text, overrides)` for single expressions.
- [X] T016 [US2] Parser, calls and arguments (G-48..G-56): comma-separated arguments; arity from the registry or the user definition; unknown function error; `rel` allowed as a call argument; `range` accepted only as the last argument of a registry entry with `args = "expr-range"` and only with variable `x`, anywhere else the range-outside-plot error ([errors.md](contracts/errors.md)). User functions substitute all parameters by name, bounded by the existing node and depth limits.
- [X] T017 [US2] Evaluator and printer for the new nodes: `calccas/eval.lua` evaluates both sides of a `rel` and never reduces it to a boolean; a reserved command call returns `unsupported` with ``` `name` is reserved for a future version; not available in language 1.0 ```; `calccas/printer.lua` prints `lhs == rhs` deterministically. Tests in `spec/calccas/eval_spec.lua` and `spec/calccas/printer_spec.lua`.
- [X] T018 [US2] Expose the new API in `calccas.lua`: `M.parse_program`, `M.LANGUAGE_VERSION = "1.0"`; replace `split_wrapper` text matching for `simplify`/`expand` with the parsed `call` node (same results).
- [X] T019 [US2] Replace pattern classification in `calcnb/statement.lua` with an adapter over `calccas.parse_program`, returning the same record shape (`kind, text, name, param, line`) plus `params`, `args`, `range`; keep `M.RESERVED`, `M.MAX_NAME`. Update `calcnb/env.lua` so functions store `params` (list) and snapshot/restore still work; update `calcnb/runner.lua` for multi-parameter calls and relation results. Tests: `spec/calcnb/statement_spec.lua`, `spec/calcnb/env_spec.lua`, `spec/calcnb/runner_spec.lua`, `spec/calccas/user_funcs_spec.lua`.
- [X] T020 [US2] Plot command from the parsed `range` node in `calcnb/runner.lua` (and `calccas.lua` if it holds the plot entry): bounds are constant expressions evaluated to approximate numbers (`x=-2*pi..2*pi`); errors use kind `range`; `plot(f)` and `plot(f, x=-5..5)` behave exactly as before. Update plot rows in `spec/calcnb/runner_spec.lua`.
- [X] T021 [US2] Scientific notation value: in the parser's number conversion, `1e3` is exactly 1000 and `1e-3` exactly 1/1000; magnitude of exponent above 400 is decided without building the integer power (approximate if representable as a double, `overflow` otherwise). Cases `G-03`, `G-04`, `G-04a`, `G-62` in the conformance file must pass.
- [X] T022 [US2] Implicit multiplication rejection, done last and alone (G-51, research R4): number then identifier or `(`; `)` then identifier, number or `(`; non-function identifier then `(` give ``missing `*`: write `2*x` `` built from the actual operands; `2 3` and `x y` keep the generic syntax error. Update the four existing parser/reference rows that relied on implicit multiplication to the new expectation (list them in the commit message and in the compatibility list C-1).
- [X] T023 [US2] Run `busted` and `luacheck`. Checkpoint: conformance spec fully passing; the only changed existing rows are those named in T005, T006 and T022.

---

## Phase 4: User Story 1 - One written language reference (P1)

**Goal**: a versioned reference, grammar, error catalog and future list ship with the plugin and match the implementation.
**Independent test**: `busted spec/docs_spec.lua` passes; a reader can follow the reference without opening the code (SC-001, judged by reading the examples against the conformance cases).

- [X] T024 [P] [US1] Write the failing doc test `spec/docs_spec.lua`: `docs/language/reference-1.0.md` states `Language version 1.0` and equals `calccas.LANGUAGE_VERSION`; every name in the reference's function table equals the registry (name, arity, status); every example id (`<!-- case: G-45-a -->`) exists in `conformance_cases.lua`; `docs/language/future.md` exists and no future name appears in the reference's "available" tables.
- [X] T025 [P] [US1] Write `docs/language/reference-1.0.md` from [contracts/language-reference.md](contracts/language-reference.md): all 17 sections, changelog, compatibility list C-1..C-5, examples tagged with case ids.
- [X] T026 [P] [US1] Copy the grammar to `docs/language/grammar.md` (same `G-nn` ids) and the catalog to `docs/language/errors.md`; any wording changed during implementation is edited in both the spec contract and the shipped copy.
- [X] T027 [P] [US1] Write `docs/language/future.md` listing reserved commands, comparison operators, multi-variable ranges, continuation character, per-cell versions, with the sentence that none are available (FR-003).
- [X] T028 [US1] Update the language section of `README.md` to link `docs/language/reference-1.0.md` and replace the implicit-multiplication wording; state the keyboard list equals the registry. Run `busted spec/docs_spec.lua`.

---

## Phase 5: User Story 3 - Exact and approximate results stay distinct (P2)

**Goal**: every result is clearly exact or approximate and the number rules in the reference are verified.
**Independent test**: `busted spec/calccas/numbers_spec.lua` passes.

- [X] T029 [P] [US3] Write `spec/calccas/numbers_spec.lua` (tests first): `0.1+0.2` is `3/10`; `1e-3` is `1/1000`; `1e3/7` stays exact; `sin(1)` is approximate and shows `≈`; `pi` and `e` show `≈`; exact range overflow promotes to approximate, beyond double range is `overflow`; `1e999` and `1e-999` follow G-62; relation sides keep their own exactness; `approx(1/3)` gives the reserved `unsupported` error rather than a value.
- [X] T030 [US3] Fix any gap T029 finds in `calccas/eval.lua` and `calccas/printer.lua`; add a regression test for each fix (constitution VI). If T029 passes unchanged, record that in the commit message instead of editing code.
- [X] T031 [US3] Cover FR-021 domains: one case per function and operator domain (division by zero, `sqrt` of negative, `log` of zero or negative, `tan` poles where the engine reports them, `0^0`, negative base with fractional exponent) extending `spec/calccas/domain_safety_spec.lua`, matching the domain table in the reference; fix mismatches or correct the reference.

---

## Phase 6: User Story 4 - Old notebooks keep working or fail clearly (P2)

**Goal**: every pre-change cell gives the same result or a message that names the replacement, and saved text is untouched.
**Independent test**: `busted spec/calcnb/compat_spec.lua` passes.

- [X] T032 [P] [US4] Write `spec/calcnb/compat_spec.lua` from `spec/calcnb/compat_corpus.lua` (T002): each source either gives the same display as before, or appears in the compatibility list with the new result and replacement fragment. Any corpus source that changes without a listed row fails the test (SC-005).
- [X] T033 [P] [US4] Add one test per compatibility row in the same file: C-1 (`2x`, `3(x+1)`, `(a)(b)`, `2pi`, `3sin(x)` give the `*` hint), C-2 (`1e3`, `1e-3`), C-3 (assign or define each reserved name), C-4 (`x == 1`, `f(1, 2)`, `1 + 2 # note` accepted), C-5 (constant-expression plot bounds).
- [X] T034 [US4] Write the byte-identity test (SC-006) in `spec/calcnb/compat_spec.lua`: load the 100-cell notebook in the saved-file format, run all cells (including ones now failing), save, reload, and assert every `source` is byte-identical.
- [X] T035 [US4] Fix gaps found by T032..T034 in `calcnb/runner.lua`, `calcnb/store_logic.lua` or the parser messages. A failed old cell must keep its source, show the error with line, and leave the notebook openable.

---

## Phase 7: Polish and cross-cutting

- [X] T036 [P] Extend `spec/calcnb/fuzz_spec.lua` with the new tokens and constructs and replace `load`, `loadstring`, `dofile`, `require`, `os.execute`, `io.open` with failing stubs for the run; assert 200 random edits plus the 100 hostile inputs call none of them (SC-004, FR-024).
- [X] T037 [P] Time lexing and parsing a 50-line, 500-character-per-line cell on LuaJIT with `os.clock` over 200 repetitions before and after (use `git stash` or the T002 baseline commit) and record both numbers in `specs/003-expression-language-standard/quickstart.md` (SC-009). Report what was measured; do not claim device timing.
- [X] T038 Run the quickstart manual table in the emulator (`pkill -f koreader-emulator; sleep 1`, then `(nohup $S/koreader/run.sh > $S/kodev-run.log 2>&1 &)`); record each row's actual result in `quickstart.md`, marking anything not tried as unverified.
- [X] T039 Update `specs/003-expression-language-standard/audit.md` with an "After" section: each gap row, how it was resolved, and the deviations from the plan.
- [X] T040 Run the final `busted` and `luacheck`, record real counts in `quickstart.md`, mark every task above `[X]`.

---

## Dependencies and order

- Phase 1 then Phase 2 (blocks everything).
- Phase 3 (US2) blocks Phase 4 (US1 needs the final grammar and case ids), Phase 5 (US3 reuses the number work) and Phase 6 (US4 needs the final messages).
- Phases 4, 5 and 6 are independent of each other after Phase 3.
- Phase 7 after all stories.
- Inside Phase 3: T008 to T011 (tests) before T012 onward; T012 then T013, T014, T015 in order (same files); T016 after T015; T017 after T013 and T016; T019 after T015..T017; T022 strictly last before the checkpoint.

## Parallel opportunities

- Phase 2: T003 alongside nothing else touching the same file; T004 follows it.
- Phase 3 tests: T008, T009, T011 in parallel (different files); T010 after T009.
- Phase 4: T024 to T027 in parallel (different files); T028 after.
- After Phase 3: Phases 4, 5 and 6 can be worked in parallel by file (`docs/`, `spec/calccas/numbers_spec.lua`, `spec/calcnb/compat_spec.lua`).
- Phase 7: T036 and T037 in parallel.

## Implementation strategy

1. **MVP = Phases 1 to 3**: the language is parsed by one grammar, conformance-tested, with explicit multiplication enforced. This is the part that changes behaviour.
2. Then Phase 4 (reference), Phase 5 and 6 (verification of numbers and old notebooks), then polish.
3. Keep the suite green after every task; the implicit-multiplication change (T022) is its own step so it can be reverted alone.
4. No new commands are implemented; reserved ones only parse and report `unsupported`.
