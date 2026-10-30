# Implementation Plan: Autocomplete and Inline Documentation

**Branch**: `004-autocomplete-inline-docs` | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/004-autocomplete-inline-docs/spec.md`

## Summary

While a cell is edited, a one-row strip above the keyboard offers names that start like the word at the cursor: built-in
functions, commands and constants, plus the variables and functions the notebook has defined. The highlighted suggestion
also shows its signature, a one-line description and an example. Tapping (or a physical key) replaces only that word with
a call template and puts the cursor inside the parentheses. Nothing is run or saved by this.

The approach, from [research.md](research.md):

1. **A pure completion layer** in `calcnb/`: finds the word at the cursor, builds and ranks the candidates, and computes
   the text edit. A small session object holds the highlight, the "dismissed for this word" memory and a change check, so
   the UI repaints only when the list really changed. No KOReader class is required anywhere in it.
2. **One documentation table** in `calccas/` (`builtin_docs.lua`), keyed by registry name. A test fails if a registry
   entry has no documentation, if an example for an implemented name does not run, or if the language reference
   disagrees with a signature.
3. **A per-cell ledger of definitions** (`cell.defined`) written by the runner and kept on the notebook, because the shared
   environment only grows: re-running `speed = 5` over `rate = 5` leaves `rate` in the environment. The ledger is what
   makes "removed or renamed definitions disappear" true.
4. **A thin UI**: a fixed-height suggestion strip between the page bar and the keyboard, an `on_change` hook on the cell
   editor, and a `replace_word` edit. The strip repaints its own rectangle only. The page is never rebuilt while typing.

No new language feature is added. `diff` and the other reserved commands are suggested, marked "not available yet", and
still end in the existing `unsupported` message when run.

## Technical Context

**Language/Version**: LuaJIT 2.1 (KOReader's runtime), plain Lua 5.1 idiom. No `load`/`loadstring` on user text.

**Primary Dependencies**: none new. KOReader widgets only in `calcui/`. `calccas/` and `calcnb/` stay free of UI classes.

**Storage**: none. The notebook file format is unchanged: `cell.defined` is runtime state like `cell.output` and is not
saved. After a restore, only built-in names are offered until cells are run (as the environment itself is empty then).

**Testing**: Busted and Luacheck from `$HOME/.luarocks-luajit/bin`. Baseline: 848 successes, 0 failures, luacheck clean
over 99 files. New specs cover word detection, ranking, edit results, session behaviour, the definitions ledger and the
documentation table. UI wiring is checked by hand in the emulator (quickstart) and reported as unverified until run.

**Target Platform**: KOReader on e-ink devices (Kindle, Kobo, Android) and the desktop emulator. Minimum KOReader
v2025.10 (provisional), unchanged.

**Project Type**: single Lua plugin (library layers plus UI).

**Performance Goals**: strip update within 100 ms of a keystroke on the reference device, typing latency at most 10% above
the same session with suggestions off (SC-006). Candidate search over about 20 built-ins and 100 defined names is a linear
scan, measured by a Busted timing guard on the Mac and by hand on the device.

**Constraints**: offline, no external service, no Python. No full-page `rebuild()` per keystroke. The strip has a fixed
height while editing so showing or hiding it never moves the page. The keyboard and the cursor line stay visible.

**Scale/Scope**: 3 new pure modules (`calccas/builtin_docs`, `calcnb/completion`, `calcnb/completion_session`), 1 new
widget (`calcui/suggestion_strip`), changes in `calcnb/runner`, `calcnb/notebook`, `calcui/cell_editor`,
`calcui/notebook_view`, README and the language reference.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | How the plan satisfies it |
|---|-----------|--------|---------------------------|
| I | KOReader-Native | PASS | Uses the existing widgets (`ButtonTable`, `FrameContainer`, `UIManager:setDirty` with a region) and the existing `InputText` cursor methods (`charpos`, `moveCursorToCharPos`, `addChars`, `delChar`), all read in the emulator's KOReader source. Keys use `Device.input.group` and `Device:hasKeys()` like the notebook already does. |
| II | Simplicity | PASS | Prefix match only, one ranking rule, one documentation table. No plugin points for matchers, no fuzzy search, no usage statistics. The ledger is one table per cell. |
| III | Performance | PASS | Work per keystroke is one linear scan and one change comparison. The strip repaints only its rectangle. Names are collected once per page rebuild, not per keystroke. No timers or polling. |
| IV | UX consistency | PASS | Strip uses the same button style and font as the rest. Touch always works. Physical keys act only while the strip is shown and reuse keys the notebook already reads. Descriptions go through `gettext`. |
| V | Reliability and data safety | PASS | Accepting a suggestion edits the live editor text only; it never runs, saves or rewrites a cell. A failure while building suggestions hides the strip (guarded) and leaves the editor usable. File format untouched. |
| VI | Testing | PASS | All decision logic is in modules without UI classes and is tested first. Examples in the documentation are executed by a test. Hardware claims are made only after a run. |
| VII | Compatibility | PASS | No new KOReader API beyond those already used. Feature detection for keys. Saved notebooks load and run unchanged. |
| VIII | Documentation | PASS | README "Using the notebook" gains an autocomplete paragraph. The language reference gains a signature column that a test keeps in sync with `builtin_docs`. |
| IX | Incremental | PASS | Phases deliver in order: documentation table, completion logic, ledger, strip with touch, physical keys. Each leaves the suite green. No refactoring of the keyboard or the page layout beyond reserving the strip's height. |

**Post-design re-check**: unchanged. The one structural addition outside the new modules is the per-cell `defined`
ledger, justified in research R3 by a verified behaviour of the environment. No violations, so Complexity Tracking is
empty.

## Project Structure

### Documentation (this feature)

```text
specs/004-autocomplete-inline-docs/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: decisions with rationale and alternatives
├── data-model.md        # Phase 1: completion context, suggestion, docs entry, edit result, ledger
├── quickstart.md        # Phase 1: how to verify by test and by hand
├── contracts/
│   ├── completion.md    # Pure API: word_at, suggest, apply, session
│   └── strip-ui.md      # UI contract: layout, repaint rules, touch and key behaviour
├── checklists/requirements.md
└── tasks.md             # Created by /speckit-tasks (not by this command)
```

### Source Code (repository root)

```text
calccas/
└── builtin_docs.lua            # NEW: signature, summary, examples per registry name (pure)
calcnb/
├── completion.lua              # NEW: word_at, suggest (match + rank), apply (pure)
├── completion_session.lua      # NEW: highlight, dismissal, change detection, accept (pure)
├── runner.lua                  # CHANGED: output.defined = names this run defined
└── notebook.lua                # CHANGED: cell.defined ledger, Notebook:completion_names(), cleared with outputs/run-all
calcui/
├── suggestion_strip.lua        # NEW: fixed-height strip widget, region repaint
├── strip_sizing.lua            # NEW: pure strip height (2, 1 or 0 rows) per screen size
├── cell_editor.lua             # CHANGED: on_change hook, replace_word(), cursor accessors
└── notebook_view.lua           # CHANGED: reserves strip height, wires editor -> session -> strip, key events while shown
docs/language/reference-1.0.md  # CHANGED: signature column for the registry table
README.md                       # CHANGED: autocomplete paragraph
spec/
├── calccas/builtin_docs_spec.lua        # NEW: coverage, examples run, reference agrees
├── calcnb/completion_spec.lua           # NEW: word detection, ranking, apply, randomized edit preservation
├── calcnb/completion_session_spec.lua   # NEW: highlight, dismissal, change detection
├── calcnb/notebook_spec.lua             # CHANGED: ledger rows
└── calcnb/runner_spec.lua               # CHANGED: defined rows
```

**Structure Decision**: keep the existing three layers. Decisions live in `calccas/` (what the names mean) and `calcnb/`
(what to offer and what edit follows). `calcui/` only draws the strip, reads the cursor and applies the edit.

## Complexity Tracking

No constitution violations to justify.
