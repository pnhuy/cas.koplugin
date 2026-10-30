# Tasks: Autocomplete and Inline Documentation

**Input**: `specs/004-autocomplete-inline-docs/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)
**Tests**: Requested (spec FR-018, SC-010; constitution VI). Each implementation task has its failing test written first.
**Commands** (repo root): `export PATH=$HOME/.luarocks-luajit/bin:$PATH`, then `busted` and
`luacheck --no-color main.lua _meta.lua calccas.lua calcplot.lua calccas calcplot calcnb calcui spec`.
Never run Python. Never claim a pass that was not run. Do not commit unless asked. Emulator steps follow the saved rule:
`pkill -f koreader-emulator; sleep 1` before every launch.

## Format: `- [ ] T### [P?] [US?] Description with file path`

`[P]` = can run in parallel (different files, no unfinished dependency). Stories: US1 complete a name (P1), US2 inline
documentation (P2), US3 user names (P2), US4 physical keys and dismissal (P3).

---

## Phase 1: Setup

- [X] T001 Run `busted` and `luacheck` from the repo root and record the real counts as the baseline in `specs/004-autocomplete-inline-docs/quickstart.md` (the plan quotes 848 successes and 99 files from the end of feature 003; replace with what is actually printed).

**Checkpoint**: baseline recorded.

---

## Phase 2: Foundational (blocks all stories)

- [X] T002 [P] Write the failing spec `spec/calcnb/completion_spec.lua` describe "word_at" using the rows in [contracts/completion.md](contracts/completion.md): `dif|`, `1 + si| + 2`, `1 + s|in + 2`, empty and `x +| `, `# dif|`, `2e|3`, a plot range variable `plot(sin(x), x|=-1..1)`, `a = 1\ndi|` (cursor line only), a comment containing `π` before the cursor (character positions, not bytes), cursor at position 1 and at end of text, and `nil`/out-of-range `charpos` returning `nil`.
- [X] T003 Create `calcnb/completion.lua` with `word_at(text, charpos)` per [data-model.md](data-model.md) ("Word at cursor"): convert the character position to a byte offset (UTF-8 aware), look only at the cursor's line, stop at `#`, reject a word that starts inside a digit run, reject a `name=` range variable inside a call, return `{prefix, first, last, line}`. Pure Lua, no `require` of any `ui/` module.
- [X] T004 Run `busted spec/calcnb/completion_spec.lua` and `luacheck` on the new files; fix until clean.

**Checkpoint**: word detection works for every contract row.

---

## Phase 3: User Story 1 - Complete a command or function name while typing (P1) 🎯 MVP

**Goal**: typing `dif` shows `diff`; tapping it gives `diff()` with the cursor inside; surrounding text is untouched; nothing runs.
**Independent test**: `busted spec/calcnb/completion_spec.lua spec/calcnb/completion_session_spec.lua` passes, and emulator steps 1, 2, 5 and 6 of the quickstart behave as written (or are recorded "not run").

### Tests first

- [X] T005 [P] [US1] In `spec/calcnb/completion_spec.lua` add describe "suggest" (failing): `dif` offers `diff` marked unavailable; `si` offers `sin` before reserved names; case-insensitive (`SIN` finds `sin`); exact match first (`pi`); ordering rule (exact, available built-in, reserved; shorter then alphabetical); constants insert the bare name with `back = 0`; functions and commands insert `name()` with `back = 1`; `limit` and `more` counts (`more` is the number of matches beyond `limit`); empty prefix returns nothing; `ln` is offered as its own entry with an alias note; `si` lists `simplify` within the default chip limit (SC-002).
- [X] T006 [P] [US1] In `spec/calcnb/completion_spec.lua` add describe "apply" (failing): `dif` becomes `diff()` with `charpos` between the brackets; `1 + si + 2` keeps `1 + ` and ` + 2`; mid-word `1 + s|in + 2` replaces the whole word; a constant ends with the cursor after it; multi-line text keeps other lines byte for byte; a seeded loop of 200 random texts, cursors and suggestions checks that the text outside the replaced range is unchanged (SC-005).
- [X] T007 [P] [US1] Create the failing `spec/calcnb/completion_session_spec.lua` per the session table in [contracts/completion.md](contracts/completion.md): `update` returns `true` on first show and `false` when nothing changed; `model()` is `nil` when hidden; `move` wraps; `select(i)` moves the highlight and returns `true`, returns `false` when `i` is already highlighted or out of range, and never produces an edit; `accept()` returns the edit for the highlighted item and hides; typing on narrows the list and resets the highlight; an error thrown inside matching hides the strip instead of raising.

### Implementation

- [X] T008 [US1] In `calcnb/completion.lua` add `suggest(prefix, names, opts)` and `apply(text, word, suggestion)` as specified; candidates come from `calccas/registry.lua` (`kind`, `status`, `alias_of`); keep it free of UI requires.
- [X] T009 [US1] Create `calcnb/completion_session.lua` with `new`, `set_names`, `update`, `model`, `move`, `select`, `accept` (dismissal comes in US4); wrap the matching call in `pcall` so a failure hides the strip.
- [X] T010 [US1] In `calcui/cell_editor.lua` add the `on_change` callback (called after `addChars`, `delChar`, `delNextChar`, `delToStartOfLine`, `delAll`, `leftChar`, `rightChar`, `upLine`, `downLine`, `goToStartOfLine`, `goToEndOfLine`, `goToHome`, `goToEnd`, `moveCursorToCharPos`, `setText`, wrapped once at class level), a suppression flag, `CellEditor:cursor()` returning `(text, charpos)`, and `CellEditor:replace_word(edit)` per [contracts/strip-ui.md](contracts/strip-ui.md) ("Accepting"); clear a whole-cell selection mark first.
- [X] T011 [US1] Create `calcui/suggestion_strip.lua`: fixed-height widget, chip row built from `session:model()` (chips for built-ins; unavailable ones dimmed; a trailing `+N` label when `model.more > 0`, dimmed, not tappable, never replacing a chip), a tap on the highlighted chip calls `on_accept()`, a tap on another chip calls `on_select(index)`, `set_model(model)` replaces children and calls `UIManager:setDirty(self, "ui", self.dimen)` only when the model changed; wrapped in `guard.wrap` like the other callbacks.
- [X] T011a [P] [US1] Write the failing `spec/calcui/strip_sizing_spec.lua` (next to the `keyboard_sizing` spec): portrait and landscape sizes (for example 600x800, 800x600, 1072x1448, 480x320) give `rows` 2, 1 or 0; the page height left above the strip is never below `MIN_PAGE_LINES` editor lines whenever `rows > 0`; equal inputs give equal results (no dependence on the typed word); zero or negative sizes give `rows = 0`.
- [X] T011b [US1] Create `calcui/strip_sizing.lua` (pure, no `ui/` requires): `strip_height(screen_h, screen_w, keyboard_h, other_h, line_h)` returns `{rows, height}`; make `suggestion_strip.lua` take its height and row count from it.
- [X] T012 [US1] In `calcui/notebook_view.lua`: create the session and the strip (skip the strip when `rows` is 0), reserve the height from `strip_sizing` in `content_h` whenever a cell is edited, insert the strip between the page bar and the keyboard in `rebuild()`, set `editor.on_change` to update the session and the strip (never `rebuild()`), `on_select(i)` calls `session:select(i)` and repaints the strip only, and `on_accept()` applies `session:accept()` through `editor:replace_word`. Reset the session when the active cell changes or editing stops.
- [ ] T013 [US1] Run `busted` and `luacheck`; then emulator quickstart steps 1, 2, 5, 6 and record each result under "Results" in `quickstart.md` (or "not run, unverified").

**Checkpoint**: MVP: `dif` → `diff()` by one tap, text preserved, nothing run.

---

## Phase 4: User Story 2 - See what a name does before choosing it (P2)

**Goal**: the highlighted suggestion shows signature, one-line description and example.
**Independent test**: `busted spec/calccas/builtin_docs_spec.lua spec/docs_spec.lua` passes; emulator: type `plot`, the documentation row shows signature, summary and example.

- [X] T014 [P] [US2] Create the failing `spec/calccas/builtin_docs_spec.lua`: every registry name has an entry and no entry lacks a registry name; `summary` is one line; at least one example per entry; examples of implemented names evaluate without error through `calcnb.runner` (use `plot` examples as graph outputs); examples of reserved names give error kind `unsupported`; `ln` carries an alias note; reserved entries carry a note that says running them gives the reserved message; every `signature` appears in `docs/language/reference-1.0.md`.
- [X] T015 [US2] Create `calccas/builtin_docs.lua` with an entry for each of the 19 registry names (sin cos tan sqrt plot abs exp log ln simplify expand pi e factor solve subs approx diff integrate): `signature`, one-line `summary`, `examples`, optional `note`. Signatures follow the registry arity (for example `diff(expr[, symbol])`, `plot(f1[, f2, ...], x=lo..hi)`).
- [X] T016 [US2] Add a Signature column to the registry table in `docs/language/reference-1.0.md` using the same strings (keep the `<!-- registry:begin/end -->` markers and the `<!-- case: G-.. -->` tags intact) and adjust `spec/docs_spec.lua` only as needed to read the new column.
- [X] T017 [US2] Attach `doc` to each built-in suggestion in `calcnb/completion.lua`; in `calcui/suggestion_strip.lua` add the documentation row for the highlighted item (signature, summary, first example when the height allows, "not available yet" text for reserved). Every user-visible string goes through `_()` in a static table in `calcui/suggestion_strip.lua` so the gettext extractor sees them (same pattern as `STATUS_LABELS` in `calcui/cell_widget.lua`): the built-in summaries and the reserved/alias `note` texts (looked up by registry name), the kind labels (function, command, constant, variable, user function), "not available yet", and the `✕` tooltip. Signatures and examples are code and are not translated. `calccas/builtin_docs.lua` keeps plain English strings and stays free of gettext.
- [X] T018 [US2] Run `busted` and `luacheck`; emulator check of the documentation row; record in `quickstart.md`.

**Checkpoint**: documentation is complete, exact, and executable.

---

## Phase 5: User Story 3 - Suggest my own variables and functions (P2)

**Goal**: names defined by the last successful run of each cell are offered, and disappear when their definition is replaced.
**Independent test**: `busted spec/calcnb/runner_spec.lua spec/calcnb/notebook_spec.lua spec/calcnb/completion_spec.lua` passes; emulator step 3 of the quickstart.

- [X] T019 [P] [US3] In `spec/calcnb/runner_spec.lua` add failing rows: `output.defined` lists `{name, kind, params}` for `a = 1`, `f(x, y) = x + y`; a failing run has no `defined` at all, even when an earlier statement of the same cell would have succeeded; plain expressions and plots define nothing.
- [X] T020 [P] [US3] In `spec/calcnb/notebook_spec.lua` add failing rows for the ledger: `run_cell` sets `cell.defined`, and a run that ends in an error leaves it unchanged; re-running a cell with `speed = 5` over `rate = 5` drops `rate` from `completion_names()` even though `env` still holds it; later cells win on duplicates; `clear_output`, `clear_all_outputs` and `begin_run_all` empty it; a restored notebook (`store_logic.from_file`) starts empty; `duplicate` gives the copy no `defined` until it is run; `delete` removes the deleted cell's names from `completion_names()`; `move` keeps the cell's names and only changes which cell wins on a duplicate name; the saved file bytes are unchanged by running.
- [X] T021 [P] [US3] In `spec/calcnb/completion_spec.lua` add failing rows: user variables and functions are suggested after available built-ins and before reserved ones; a function suggestion carries `params` and a `name(x, y)` signature and inserts `name()` with `back = 1`; a variable inserts the bare name; names not in `names` are never offered (so the parameter names of a function being defined, such as `x` in `f(x) = ...`, are not offered unless defined elsewhere).
- [X] T022 [US3] In `calcnb/runner.lua` collect `defined` as `run_assign` and `run_funcdef` succeed and return it on the output (the existing `Output` shape otherwise unchanged; check `calcnb/output.lua` for any copy of the field list).
- [X] T023 [US3] In `calcnb/notebook.lua` set `cell.defined` in `run_cell`, clear it in `clear_output` and `begin_run_all`, add `Notebook:completion_names()`; confirm `store_logic` does not save the field.
- [X] T024 [US3] In `calcnb/completion.lua` merge user names into the candidates with the data-model ordering and build a signature for a user function from its `params`.
- [X] T025 [US3] In `calcui/notebook_view.lua` call `session:set_names(self.nb:completion_names())` in `rebuild()` (a run, a cell switch and a rotation all rebuild), and show the kind in the chip and the documentation row for user names.
- [X] T026 [US3] Run `busted` and `luacheck`; emulator step 3; record in `quickstart.md`.

**Checkpoint**: suggestions follow what was actually run.

---

## Phase 6: User Story 4 - Physical keys and dismissal (P3)

**Goal**: dismiss without changing text; accept and move with the supported keys.
**Independent test**: `busted spec/calcnb/completion_session_spec.lua` passes; emulator steps 4 and 7 of the quickstart.

- [X] T027 [P] [US4] In `spec/calcnb/completion_session_spec.lua` add failing rows: `dismiss()` hides and returns `true`, text untouched by design; the strip stays hidden while the cursor stays in the same word (same line and start); starting a new word shows it again; `dismiss()` when hidden returns `false`.
- [X] T028 [US4] Add `dismiss` and the dismissed-word memory to `calcnb/completion_session.lua`.
- [X] T029 [US4] Add the `✕` button at the end of the chip row in `calcui/suggestion_strip.lua` and call `on_dismiss`; wire it in `calcui/notebook_view.lua` to `session:dismiss()` and a strip repaint.
- [X] T030 [US4] In `calcui/notebook_view.lua` extend the `Device:hasKeys()` key events: while the strip is shown `PgFwd`/`PgBack` move the highlight, `Press` (and `Tab` where the device has a keyboard) accept, `Back` dismisses without closing; when hidden, `onNextPage`, `onPrevPage` and `onCloseNotebook` behave exactly as before. Guard every key path with `guard.wrap`.
- [X] T031 [US4] Run `busted` and `luacheck`; emulator steps 4 and 7; record in `quickstart.md`.

**Checkpoint**: all four stories work, with touch alone sufficient.

---

## Phase 7: Polish and cross-cutting

- [X] T032 [P] In `spec/calcnb/completion_spec.lua` add a timing guard for SC-011: a notebook of 100 cells with 100 defined names, 1000 `update` calls, asserting a generous per-call bound (state the bound and that it is a Mac figure, not an E Ink figure).
- [X] T033 [P] In `spec/calcnb/fuzz_spec.lua` add a describe that drives `word_at`, `suggest`, `apply` and the session with seeded random text (including UTF-8 and empty text, and the hostile strings from `suite.hostile`, where `suite = require("spec.calccas.conformance_cases")` as in the existing `fuzz_spec.lua`) and random `charpos` including out-of-range values: never raises, never loses text outside the replaced range.
- [X] T034 [P] Add an autocomplete paragraph to `README.md` ("Using the notebook"): what the strip shows, tap to accept, `✕` to dismiss, keys, reserved names marked "not available yet", that nothing runs.
- [X] T035 Check that nothing in `calcnb/` or `calccas/` requires a `ui/` module (`grep -rn 'require("ui/' calccas calcnb` must be empty) and that no existing spec changed except the rows named in T016, T019, T020.
- [X] T036 Run the full `busted` and `luacheck`, record the counts and the emulator results (or "not run") in `quickstart.md` "Results", and mark every finished task `[X]` here. Do not commit unless asked.

---

## Dependencies and order

- Phase 1 → Phase 2 → Phase 3 (MVP). Phases 4, 5 and 6 each depend on Phase 3 only; 4 and 5 touch different files except `completion.lua`, `suggestion_strip.lua` and `notebook_view.lua`, so run them one after the other (US2, then US3, then US4).
- Within a phase: tests (`[P]`) first and failing, then implementation in numeric order.
- T010 and T011 are independent of T008 and T009 (UI vs pure logic) but T012 needs all four plus T011b (T011a, the sizing test, comes first).

## Parallel examples

- Phase 3 tests: T005, T006 and T007 together (three spec files or distinct describes).
- Phase 5 tests: T019, T020 and T021 together.
- Polish: T032, T033 and T034 together.

## Implementation strategy

1. **MVP**: Phases 1–3 deliver `dif` → `diff()` with built-in names only, touch only. Stop and verify (T013).
2. Add documentation (US2), then defined names (US3), then keys and dismissal (US4), verifying after each phase.
3. Polish last. Latency on a real E Ink device cannot be measured here; report it as unverified unless run.
