# Implementation Plan: Notebook Interface and Programming Keyboard

**Branch**: `002-notebook-ui-keyboard` | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-notebook-ui-keyboard/spec.md`

## Summary

Replace the Calculator and Graph screens as the main entry point with a notebook: a windowed list of code cells, each
with a multiline editor, status, and output (text, error, or inline graph). A custom on-screen keyboard docked at the
bottom drives KOReader's `InputText` editor, so the editing logic and UTF-8 cursor handling are reused. A thin pure-Lua
statement layer (assignment, function definition, `plot(...)`) sits between the cell text and the existing engines
(`calccas`, `calcplot`), which stay unchanged except for two small, UI-free additions (exporting the supported function
list, and user-function calls). The notebook persists through `LuaSettings`. The 001 graph viewer is reused and extended
with pan, zoom, axes and equal-scale controls.

Layers (dependencies point downward only):

1. `calcnb/` (new, pure Lua, no KOReader requires): notebook model, cells, statement parser, environment, runner,
   keyboard layout, shortcuts, persistence logic. Busted-tested.
2. `calccas/`, `calcplot/` (existing engines).
3. `calcui/` (KOReader widgets): notebook view, cell widget, cell editor (InputText subclass), keyboard, graph output,
   notebook store (`LuaSettings`), plus the existing 001 views.

## Technical Context

**Language/Version**: LuaJIT 2.1 (Lua 5.1 semantics), as in 001. `local unpack = table.unpack or unpack`.

**Primary Dependencies**: KOReader only: `ui/widget/inputtext`, `buttontable`, `button`, `titlebar`, `textboxwidget`/
`textwidget`, `container/bottomcontainer`, `framecontainer`, `verticalgroup`, `confirmbox`, `infomessage`, `uimanager`,
`luasettings`, `datastorage`, `device`, `gettext`, `ffi/blitbuffer`. No third-party libraries.

**Storage**: `<settings dir>/calculator_notebook.lua` via `LuaSettings` (contract: `contracts/notebook-file.md`). The 001
`calculator.lua` settings file is untouched.

**Testing**: Busted + Luacheck for everything under `calcnb/` and the pure parts of `calcui/` (same commands as 001,
`luacheck ... calcnb`). Widgets are verified by hand in the desktop emulator and on a device; those results are recorded in
`quickstart.md` and are not claimed as automated tests.

**Target Platform**: KOReader on E Ink devices and the desktop emulator. Minimum KOReader version stays **v2025.10
(provisional)** from 001; APIs used here are verified in the `54eb77e` source clone (see `research.md`).

**Project Type**: KOReader plugin (repository root is `calculator.koplugin`).

**Performance Goals**: typing never triggers evaluation (SC-004); a plot of up to 4 functions appears < 3 s on the
emulator (SC-010) with taps acknowledged < 1 s; scrolling 100 cells keeps live widgets bounded by the viewport (SC-013).
Device timing is measured on hardware and recorded, not assumed.

**Constraints**: no `load` on user input; statement length 500, AST nodes 2000, 200 cells, 5000 chars per cell, 100 names,
6 plotted functions; one run at a time; no animation; discrete page scrolling.

**Scale/Scope**: one default notebook, single user. P1 stories first; P2 (organize, copy/insert) next; P3 (text cells,
function inspection) only after P1/P2 are verified.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | How the plan satisfies it |
|---|-----------|--------|---------------------------|
| I | KOReader-Native | PASS | Standard plugin; reuses `InputText`, `ButtonTable`, `LuaSettings`, `gettext`. All APIs read from the `54eb77e` source (research R1-R3, R8). The one risk, stubbing `InputText`'s keyboard, has a spike task and a documented fallback. KOReader core is not modified. |
| II | Simplicity | PASS | Windowed list instead of a virtual-scroll framework; conservative staleness instead of a dependency graph; one notebook file. The statement layer is the minimum the notebook needs. |
| III | Performance | PASS | No evaluation while typing; run and plot are tick-stepped; visible-cells-only widgets; cached graph canvases; repaint only the changed region. |
| IV | UX consistency | PASS | Buttons and `TitleBar` like 001; page buttons and page-turn keys; confirmations on destructive actions; status shown by symbol and text. |
| V | Reliability | PASS | `sanitize` on load; `LuaSettings` flush with `.old` backup; failed multi-line run rolls back the environment; guard wrappers on every callback; the plugin never touches book data. |
| VI | Testing | PASS | All business logic in `calcnb/` has Busted tests written before the code; UI results recorded honestly. |
| VII | Compatibility | PASS | Feature detection for clipboard (`Device:hasClipboard()`) and keys (`Device:hasKeys()`); no platform assumptions. |
| VIII | Documentation | PASS | README updated at the end; research decisions kept in `research.md`. |
| IX | Incremental | PASS | Phase order below keeps 001 screens working until the notebook reaches parity. |

**Post-design re-check**: unchanged. No violations, so Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/002-notebook-ui-keyboard/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── notebook-language.md
│   ├── notebook-file.md
│   └── keyboard-layout.md
├── checklists/requirements.md
└── tasks.md              # produced by /speckit-tasks
```

### Source Code (repository root)

```text
main.lua                      # Tools menu entry now opens the notebook (001 screens reachable from its menu)
calccas.lua                   # + functions() export; user-function support per research R5
calccas/                      # unchanged except for R5 hook
calcnb/                       # NEW, pure
├── notebook.lua              # model operations, staleness
├── statement.lua             # cell source -> statements
├── env.lua                   # variables, functions, snapshot/restore
├── runner.lua                # statement execution -> Output (coroutine friendly)
├── output.lua                # Output construction, truncation, pretty printer
├── keyboard_layout.lua       # pages and keys
├── shortcuts.lua             # supported shortcut groups
└── store_logic.lua           # sanitize / to_data
calcui/
├── notebook_view.lua         # toolbar, windowed list, page buttons, keyboard docking, resize
├── cell_widget.lua           # one cell: indicator, source, status, output, actions
├── cell_editor.lua           # InputText subclass with stubbed keyboard
├── keyboard.lua              # ButtonTable pages driving the editor
├── graph_output.lua          # inline graph (graph_canvas) + Expand
├── graph_view.lua            # 001 viewer + pan/zoom/axes/equal controls
├── notebook_store.lua        # LuaSettings load/save
└── (001 files kept)
spec/calcnb/                  # Busted specs for calcnb
spec/calcui/                  # pure-logic specs (status labels, layout sizing)
```

**Structure Decision**: single plugin tree, flat modules per existing 001 convention (`calcnb/` joins `calccas/`,
`calcplot/`, `calcui/`). A top-level facade file is added only if a `calcnb/init.lua` would otherwise be required, because
KOReader's plugin `package.path` lacks `?/init.lua` (001 finding); `calcnb` is required by file path
(`require("calcnb.notebook")`) so no facade is needed.

## Phasing (input to `/speckit-tasks`)

0. **Spikes** (before design is locked): stub keyboard in `InputText` (R2), parser behavior for user functions (R5),
   status glyph availability (R11), `calccas.functions()` export (R12).
1. **calcnb core + tests** (statement, env, runner, notebook, store_logic, keyboard_layout, shortcuts).
2. **US2 keyboard + editor** (editor subclass, keyboard widget, docking, shortcuts).
3. **US1 notebook cells** (view, cell widget, run, Run all, errors, staleness).
4. **US3 inline graphs + viewer controls**.
5. **US4 persistence and lifecycle** (store, autosave, malformed-file handling, resize, close paths, book data untouched).
6. **US5 organize/reuse** (P2), then **US6** (P3) only if time allows.
7. **Polish**: README, limits and fuzz tests, timings, gettext check, retirement decision for the 001 screens.

Phase 2 and 3 are both P1; keyboard comes first because the notebook cannot be exercised without it.

## Complexity Tracking

No constitution violations to justify.
