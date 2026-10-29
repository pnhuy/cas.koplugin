# Research: Notebook Interface and Programming Keyboard

All KOReader facts below were read from the source clone at commit `54eb77e` (the same one used for feature 001):
`<koreader>/frontend/ui/widget/{inputtext,inputdialog,virtualkeyboard,textboxwidget}.lua`, `ui/widget/container/*`,
`luasettings.lua`, `util.lua`. Anything not read there is marked **unverified** and gets a spike task.

## R1. Multiline editor

**Decision**: Reuse `InputText` (`ui/widget/inputtext.lua`) as the cell editor, in a thin subclass (`calcui/cell_editor.lua`).

**Rationale**: It already provides multiline text (`scroll`/height, newline insertion), a UTF-8 `charlist` with a valid
`charpos`, and the editing methods the keyboard needs: `addChars`, `delChar`, `delNextChar`, `leftChar`, `rightChar`,
`upLine`, `downLine`, `goToStartOfLine`, `goToEndOfLine`, `goToHome`, `goToEnd`, `getText`, `setText`,
`moveCursorToCharPos`, and clipboard access through `Device.input.getClipboardText/setClipboardText`. Cursor and selection
are therefore UTF-8 safe by construction (FR-016) and no editor has to be written.

**Alternatives**: (a) `InputDialog` per cell: single modal field with its own keyboard, cannot be embedded in a scrolling
notebook. (b) A new editor on `TextBoxWidget`: 2700-line dependency to re-implement cursor logic; rejected as Principle I/II
violation unless the spike (R2) fails.

## R2. Replacing KOReader's keyboard

**Finding**: `InputText:init` calls `initKeyboard()` unless `readonly`; `initKeyboard` builds `Keyboard:new{ inputbox = self,
keyboard_layer = ... }` where `Keyboard` is `VirtualKeyboard` or `PhysicalKeyboard`. `VirtualKeyboard:init` picks its layout
from the fixed `lang_to_keyboard_layout` table and `require("ui/data/keyboardlayouts/<lang>_keyboard")`; its height is
`keys_height * #KEYS` with `keys_height` 48 or 64 scaled. There is no supported way to hand it a custom page set (shortcut
row, symbol page with `<= >= == !=`), and `readonly = true` disables editing (`addChars` returns early).

**Decision**: Subclass `InputText` and override `initKeyboard` to install a small stub (`isVisible`, `showKeyboard`,
`hideKeyboard`, `lockVisibility`, `free`, `dimen`) so KOReader's own keyboard never appears; our `calcui/keyboard.lua`
drives the editor through the methods in R1. **Spike (first task)**: confirm in the emulator that no code path in
`InputText` touches other fields of `self.keyboard` (taps, hold, `onCloseWidget`, `getKeyboardDimen`).

**Fallback if the spike fails**: copy the minimum of `InputText` into a plugin-owned editor (documented limitation,
FR-051). The decision and the result get recorded in `quickstart.md`.

**Alternatives**: patch/subclass `VirtualKeyboard` and add a layout file to `ui/data/keyboardlayouts` (modifies KOReader
core, rejected by Principle I); use the system keyboard plus a shortcut bar (cannot provide `{ } <= !=` pages reliably, and
layout varies by language, so FR-018/FR-021 could not be guaranteed).

## R3. Keyboard widget

**Decision**: Own `calcui/keyboard.lua`, built from `ButtonTable` rows (one table per page: letters, letters-shifted,
symbols), docked in a `BottomContainer`. Layout data lives in a pure module `calcnb/keyboard_layout.lua`
(page → rows → keys `{label, insert, cursor_back}`), so every key and every character reachable is unit-tested without
KOReader.

**Rationale**: `ButtonTable` is already used and verified in feature 001, provides tap feedback and sizing, and avoids
`VirtualKey` internals (which need a `VirtualKeyboard` parent). A page switch rebuilds one table, not the notebook (FR-023).

**Sizing**: key height = max(Screen:scaleBySize(44), screen_height × 0.38 / rows) so the keyboard lands in 35–55 % of the
height; compact layout (fewer shortcut keys per row, symbol page for the rest) when width < ~480 px. Exact values are tuned
in the emulator (540×720) and recorded.

## R4. Notebook view and scrolling

**Decision**: A windowed list. The view holds the cell index of the top cell and builds widgets only for the cells that fit
the viewport (the active cell is an editor, the others are static text widgets). Scrolling is by page with Up/Down page
buttons and page-turn keys, not continuous drag. Scroll position is the top cell index plus an offset inside a tall cell.

**Rationale**: Bounds live widgets by screen size (FR-048, SC-013), is discrete (E Ink), and needs no gesture. `Menu`
does the same for lists.

**Unverified**: `ScrollableContainer` (`ui/widget/container/scrollablecontainer.lua`) exists but was not read; it is not
needed for this design. Tall single outputs use the Expand control (FR-030) instead of inner scrolling.

## R5. Notebook language

**Finding**: The engine evaluates expressions only (001). It has no assignment, user functions, `plot(...)`, or ranges.

**Decision**: A pure statement layer `calcnb/statement.lua` classifies each non-empty line of a cell as one of
`assign` (`name = expr`), `funcdef` (`name(var) = expr`), `plot` (`plot(f1, f2, ..., x=a..b)`), or `expr`. The cell result
is the result of its last statement; earlier statements only change the environment. Assignment evaluates the right side
with the environment and stores the result; `funcdef` stores the parsed AST and parameter.

**User functions**: The parser must accept a call `f(2)`/`f(x+1)` for a defined name. **Unverified**: how
`calccas.parser` treats unknown function names. The spike reads the parser and then chooses the smaller of (a) a
`calccas` option to pass user functions into parse/eval, or (b) AST substitution in the runner before evaluation. Either
keeps the engine free of UI dependencies. Name rules: not a built-in (`sin`, ..., `pi`, `e`) and not `plot`.

**Never executed as Lua**: statements are tokenized by the existing lexer, never `load`ed (Constitution constraint from 001).

## R6. Dependencies and staleness

**Decision**: Conservative model (allowed by FR-008). Each cell records the `version` of the environment it ran under; the
environment version increments whenever a run changes a name. After a run, every executed cell positioned after the
changed cell and whose recorded version is older gets `stale`. Editing a cell marks its own output `out_of_date`.
Reordering or deleting marks all executed cells stale. No dependency graph.

## R7. Execution without blocking

**Decision**: Reuse the 001 pattern: the runner is a coroutine stepped from `UIManager:nextTick` with a time budget;
plots already run that way. Evaluate has built-in limits (500 chars, 2000 nodes), so a single evaluation is short; the
runner yields between statements and during plot sampling. Run all schedules one cell per tick. Only one run at a time;
a second Run while busy is rejected with a message (spec edge case).

## R8. Persistence

**Finding**: `LuaSettings:open/flush` writes through KOReader's `util.writeToFile` and keeps a `.old` backup that `open`
falls back to (`luasettings.lua` lines ~21-45). This is KOReader's established safe-write mechanism.

**Decision**: Store the notebook in `<settings dir>/calculator_notebook.lua` via `LuaSettings`, using the schema in
`contracts/notebook-file.md`. All reading goes through `calcnb/store_logic.lua` `sanitize()` (pure, tested) which rejects or
repairs malformed data and always returns a usable notebook plus a list of problems. Outputs are not stored in the first
release; a reopened notebook shows sources with outputs absent and status Idle, which satisfies "never shown as current
unless known to match" (FR-040) without a trust model. Autosave on Close (FR-042) plus an explicit Save.

**Alternatives**: write per-notebook files and a manifest: not needed for one notebook; the schema carries a `notebooks`
map so several can be added later without a format break.

## R9. Graph reuse

**Decision**: Inline graph = `calcui/graph_canvas.lua` (001) sized to the cell width, drawn from a plot job started by the
runner. Tap/Expand opens the existing `graph_view` with the cell's own viewport state. New: Pan ×4 and Zoom ± buttons,
Axes toggle, equal-scale option. Reuse of `calcplot.viewport` (zoom/pan helpers verified to exist in 001; the plan task list
re-reads the module before use). Viewport per graph cell is stored in the notebook file; the global 001 viewport setting is
used as the default for a new plot.

## R10. Orientation and resize

**Finding (from 001)**: `SetDimensions`/`ScreenResize` are broadcast; only some classes implement handlers. Handling in a
plugin widget is therefore our job (`onScreenResize` on the notebook view rebuilds layout and keeps text/cursor/top cell).

**Risk**: the user could not verify rotation in 001. It is verified for both screens together under task T-rotation in this
feature, and stays marked unverified until then.

## R11. Localization, fonts, accessibility

**Decision**: All strings through `gettext`. Fonts via `ui/font` face names already used in 001 (`cfont`, `infofont`);
font size follows `G_reader_settings` through the face helpers. Status symbols: `○` idle, `✎` editing, `…` running,
`✓` completed, `✕` error, `◐` stale, always with a text label in the status line, never color-only. Glyph availability in
the bundled fonts is **unverified**; the spike renders each symbol in the emulator and falls back to ASCII (`o`, `e`, `...`,
`ok`, `x`, `~`) if any is missing.

## R12. Engine capability list for shortcuts

**Finding**: `calccas.lua` keeps `FUNCTION_NAMES = {sin, cos, tan, exp, log, ln, sqrt, abs}` locally.

**Decision**: Export it (`calccas.functions()`), and build the shortcut groups from that list plus the cell-level commands
the runner supports (`expand`, `simplify`, `plot`). Groups with no supported entry are hidden, so `diff`, `solve`,
`integrate`, `limit`, `factor`, `asin`, `acos`, `atan`, `plot2`, `parametric`, `polar` never appear (FR-024).

## Open questions

None blocking. Items marked **unverified** (R2 stub completeness, R5 parser behavior, R11 glyphs) are resolved by the
first-phase spike tasks, and each has a stated fallback.

## Spike results

### T003 (R5): user-function calls — decided, implemented

`calccas/parser.lua` `parse_atom` raised "unknown function 'f'" for any identifier followed by `(` that is not a built-in, so
AST substitution in the runner (option b) alone cannot work: `f(2)` never parses. **Chosen: option (a).**
`parser.parse(text, overrides)` accepts `overrides.user_funcs`, a map name -> `{param, body}`. A call `name(arg)` parses to
`ast.substitute(body, param, arg)`, checked against `max_nodes` after each substitution (nested calls cannot blow up
exponentially). `calccas.parse(text, overrides)`, `calccas.evaluate/simplify/expand(input, ..., user_funcs)` pass it
through. Variables in a body other than `param` stay free and are bound at call time. Covered by
`spec/calccas/user_funcs_spec.lua`. The engine has no KOReader dependency.
