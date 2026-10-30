# Research: Autocomplete and Inline Documentation

Facts below were read from this repository and from the emulator's KOReader source
(`koreader/frontend/ui/widget/inputtext.lua`). Nothing was run for this document.

## R1. Where the logic lives

**Decision**: `calcnb/completion.lua` (word at cursor, candidates, ranking, edit result) and
`calcnb/completion_session.lua` (highlight, dismissal, change detection). Both are plain Lua with no `require` of any
`ui/` module. Documentation text is data in `calccas/builtin_docs.lua`.

**Rationale**: the spec demands logic testable without widgets (FR-018). `calcnb/` already holds the pure notebook
rules (`shortcuts`, `keyboard_layout`), and `calccas/` already owns names (`registry`).

**Alternatives**: logic inside `calcui/` (rejected: not testable under Busted without stubs); one module for everything
(rejected: the session state would blur the pure ranking rules).

## R2. Cursor and text model

**Decision**: the pure layer takes `(text, charpos)` where `charpos` is the editor's own value: the 1-based index, in
UTF-8 characters, of the character a new one would be inserted before (`InputText.charpos`). It converts to bytes
internally and returns the same unit. Only the cursor's line is searched for a word.

**Rationale**: verified in `inputtext.lua`: `charpos` is a character position, `moveCursorToCharPos(char_pos)` and
`addChars` / `delChar` / `delNextChar` work on characters. Using the editor's unit avoids a conversion in the UI and keeps
comments with non-ASCII text correct.

**Alternatives**: byte offsets (rejected: need conversion in the widget, easy to get wrong with `π` or accented comments).

## R3. Which names count as "defined"

**Finding**: `calcnb/env.lua` only ever adds or overwrites (`set_var`, `set_func`); it removes nothing except in `clear()`,
which `begin_run_all` calls. So after `rate = 5` and then re-running the same cell as `speed = 5`, the environment still
holds `rate`. Using `env:names()` would break SC-003 and spec story 3 scenario 3.

**Decision**: the runner reports `output.defined`, a list of `{name, kind = "var" | "func", params}` for the statements that
succeeded in that run. `Notebook:run_cell` stores it as `cell.defined` (replacing the previous list), and `clear_output`,
`clear_all_outputs` and `begin_run_all` clear it. `Notebook:completion_names()` returns the union over code cells in order
(a later definition of the same name wins). `cell.defined` is not saved.

**Consequences**: `runner.run` is atomic per cell: when a statement fails it restores the environment to its pre-run
snapshot. So a failed run defines nothing at all, including earlier statements of the same cell, and the environment is
exactly as it was before. The error output therefore carries no `defined`, and `run_cell` leaves `cell.defined` unchanged
on an error (the previous successful run's definitions are still in the environment). Spec story 3 scenario 6 says this.
Editing a cell without running it keeps its last-run definitions; this matches the environment and the "unsaved edits do
not count" rule. A restored notebook starts with an empty ledger.

Cell actions: `Notebook:duplicate` makes a fresh cell, so the copy has no ledger until it is run. `Notebook:delete` removes
the cell and its ledger, so its names stop being offered at once, although `env` still holds them until the next Run all
(the same gap as a replaced definition). `Notebook:move` carries the ledger with the cell, so only the "later cell wins"
order of the union changes. None of these needs a code change beyond the ledger itself.

**Alternatives**: read `env:names()` (rejected: stale names); reparse every cell on each keystroke (rejected: cost, and it
would offer names that never ran, against FR-010); give `Env` a remove operation (rejected: changes execution semantics of
feature 002/003 for a UI feature).

## R4. Matching and ranking

**Decision**: case-insensitive prefix match on the word before the cursor. A word of one letter is enough to show the
strip; an empty word shows nothing. Order: (1) exact match, (2) available built-ins, (3) the user's variables and
functions, (4) reserved commands. Within a group: shorter name first, then alphabetical. At most 4 chips on a compact
screen and 6 otherwise; the rest are counted as `+N`.

**Rationale**: prefix only is the request. Putting built-ins before user names keeps results stable while typing; the
exact match first lets `pi` be accepted straight away. Reserved commands last follows the spec assumption.

**Alternatives**: user names first (rejected: unstable between notebooks, and with 100 names it would push built-ins away);
frequency ranking (out of scope, YAGNI).

## R5. Insertion form and cursor

**Decision**: the replacement is `name .. "()"` with the cursor one character back for functions, commands and user
functions, and `name` with the cursor after it for constants and variables. A user function with several parameters is
still `name()`; its parameter names appear in the signature line. The replaced range runs from the start of the word to
its end, including the part after the cursor when it continues the same word (spec edge case).

**Rationale**: matches what the keyboard shortcuts already insert (`name()` with `back = 1`), so both paths agree.

**Alternatives**: inserting placeholders such as `diff(expr, x)` (rejected: placeholder text would have to be selected and
removed, and the editor has no selection model beyond "all").

## R6. Where the strip goes and how it is repainted

**Finding**: `NotebookView:rebuild()` stacks `toolbar`, `page`, `pagebar` and the keyboard in one `VerticalGroup` and fills
the page with a spacer sized `content_h - used`. `Keyboard:rebuild()` and `NotebookView:rebuild()` both repaint everything.

**Decision**: while a cell is edited, the strip sits between the page bar and the keyboard and its height is subtracted
from `content_h` always (shown or empty), so the page never moves when the strip appears. The strip is two rows:
chips and the documentation line(s) of the highlighted entry. Typing never calls `rebuild()`; the strip replaces its
own children and calls `UIManager:setDirty(strip, "ui", strip.dimen)` only when the session reports a change.

**Rationale**: FR-003, FR-015, FR-016. A fixed height removes the layout shift that a variable one would cause, which on
E Ink would mean a full repaint of the page.

**Alternatives**: floating popup over the page (rejected: covers the cursor line, needs its own focus handling); variable
height strip (rejected: shifts the page); showing documentation in an `InfoMessage` (rejected: interrupts typing).

## R7. How the editor reports changes

**Decision**: `CellEditor` gets an `on_change` callback. It is called after `addChars`, `delChar`, `delNextChar`,
`delToStartOfLine`, `delAll`, `leftChar`, `rightChar`, `upLine`, `downLine`, `goToStartOfLine`, `goToEndOfLine`,
`goToHome`, `goToEnd`, `moveCursorToCharPos` and `setText`, by wrapping those methods once at class level. A guard flag
suppresses the callback during a compound edit (`replace_word`) so it fires once at the end.

**Rationale**: the on-screen keyboard and any physical key both end in these `InputText` methods, so one hook covers
both without touching `Keyboard`. Checked: the keyboard calls `type_text`, `backspace`, `move`, which call these.

**Alternatives**: calling the strip from `Keyboard:press` (rejected: misses physical keyboards and touch placement of the
cursor); polling the editor (rejected: forbidden by principle III).

## R8. Physical keys

**Finding**: `NotebookView` reads `PgFwd`, `PgBack` (page) and `Back` (close) when `Device:hasKeys()`. The cell editor has
an empty `key_events`, so no key types text on the page itself.

**Decision**: only while the strip is shown: `PgFwd` / `PgBack` move the highlight, `Press` accepts, `Back` dismisses (and
does not close the notebook). When the strip is hidden these keys behave as today. A hardware `Tab` also accepts where the
device has a keyboard. All of it is behind `Device:hasKeys()`, and touch needs none of it.

**Rationale**: reuses existing keys, adds no new conflict, and gives the escape from the list FR-013 requires.

**Alternatives**: arrow keys for the highlight (rejected: they move the cursor, which the user needs); a new key map
(rejected: not discoverable, device specific).

## R9. Documentation data

**Decision**: `calccas/builtin_docs.lua` returns `{ name = { signature, summary, examples = { "..." }, note? } }` for every
registry name. Tests: every registry name has an entry and every entry a registry name; `summary` has no newline; each
example of an implemented name evaluates without error through the runner; each example of a reserved name evaluates to
`unsupported`; each signature appears in `docs/language/reference-1.0.md`. Texts are wrapped with `_()` where the UI shows
them, the table itself holds the English source.

**Rationale**: FR-005 (one text, everywhere) and SC-004, with drift caught by tests as the registry was in 003.

**Alternatives**: put the fields on registry entries (rejected: the registry is read by the parser and evaluator and should
not carry prose); generate docs from the reference (rejected: parsing Markdown at runtime).

## R10. Performance approach

**Decision**: no cache of results. Names are gathered once per page rebuild (`Notebook:completion_names()`) and handed to
the session. A keystroke does one `word_at`, one scan of at most 19 built-ins and 100 user names, and a comparison with the
previous model. The strip is repainted only when the model differs. A Busted guard asserts the logic cost for a 100-name
notebook; device latency is measured by hand and reported with the caveat that the Mac figure is not the E Ink figure.

**Alternatives**: a trie (rejected: 119 candidates at most; measure before optimizing).

## R11. Reserved commands

**Decision**: offered last, labelled "not available yet", and insertable. Their documentation `note` says what running them
does. See spec assumptions. Hiding them is a one-line change in the ranking rule if the answer changes.
