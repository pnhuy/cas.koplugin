# Calculator (KOReader plugin)

Offline notebook-style algebra calculator and function grapher in native Lua (LuaJIT). No Python, external CAS,
browser or network.

Status: the notebook UI has been run in the KOReader desktop emulator (see
`specs/002-notebook-ui-keyboard/quickstart.md` for what was and was not checked). It has not been run on a real
e-reader: grayscale legibility, refresh behavior, physical keys, device fonts and device timing are unverified.

## Install

Copy or symlink this directory to `<koreader>/plugins/calculator.koplugin`, then restart KOReader. Open
**Tools → Calculator**.

Minimum KOReader version: **v2025.10 (provisional)**. The APIs used were checked by reading KOReader `master`
(commit 54eb77e), not by running older releases.

## Using the notebook

- The notebook is a list of cells. Tap a cell to edit it; the on-screen keyboard docks at the bottom. Enter inserts
  a newline. Nothing runs until you tap **Run**.
- The top bar has Add cell, Save, the notebook menu and Close. The `⋯` button on a cell opens its actions: add above
  or below, add note, duplicate, move, delete (confirmed when it has content), copy source, copy result, clear output.
- The notebook menu has Run all (note cells are skipped), Clear all outputs, Delete saved notebook,
  and **Classic calculator** / **Classic graph**, the earlier single-screen views.
- A cell is marked Idle, Editing, Running, Done, Error or Stale by a symbol and a word. A cell is Stale when a
  variable or function it may depend on was redefined later.
- Keyboard: letters with one-shot Shift, digits, operators, a symbols page (`{ } < > <= >= == != % _ : ; | & ? \ " ' @ # $ π ∞`),
  arrows, Home/End, Delete, clipboard keys, and shortcut groups (common: `sin cos tan sqrt plot`; basic:
  `abs exp log ln`; algebra: `simplify expand`). A shortcut inserts `name()` with the cursor inside the brackets.
- Suggestions: while you type a word in a cell, a strip above the keyboard offers built-in functions, constants and
  the variables and functions your cells have defined (matching the start of the word). The highlighted one shows its
  signature, a short description and an example. Tap the highlighted chip to insert it at the cursor (a function
  becomes `name()` with the cursor inside the brackets); tap another chip to highlight it. `✕` dismisses the strip for
  that word without changing the text. With keys: Page forward/back move the highlight, Press or Tab insert, Back
  dismisses. Reserved names such as `diff` are offered last, marked `*` and "not available yet". Accepting a
  suggestion never runs anything. A name is offered only after the cell that defines it has run; re-running that cell
  with other names drops the old ones.
- `plot(...)` draws inline. Tap the graph for the full-screen viewer: zoom, pan, reset, Range, Grid, Axes, 1:1 (equal axis
  scale) and **Inspect** (evaluate the plotted functions at an x value). Buttons only; no gestures are required.
- **Insert result** into another cell works only while that cell is being edited.

## Language

The full definition is the versioned [language reference](docs/language/reference-1.0.md) (language 1.0), with the
[grammar](docs/language/grammar.md), the [error catalog](docs/language/errors.md) and the list of
[future features](docs/language/future.md).

- Numbers: `3`, `2.5`, `.5`, `1e3` (exact: `1e-3` is `1/1000`). Operators: `+ - * / ^` and parentheses. `^` is right-associative and binds tighter
  than unary minus: `-2^2 = -4`, `2^3^2 = 512`.
- Multiplication is always written `*`: `2*x`, `2*(x+1)`, `(x+1)*(x-1)`. `2x` is an error that shows the fix.
- Assignment `a = 2`; function definition `f(x) = x^2 + a`; equation `x^2 == 4` (shown, not evaluated); `#` starts a
  comment; several statements per cell, one per line, and a line ending in an operator or comma, or inside brackets,
  continues.
- Functions: `sin cos tan exp log ln sqrt abs`, `simplify`, `expand`, `plot`. Constants: `pi`, `e`. These names
  are reserved, as are the future commands `diff solve factor integrate subs approx`. The keyboard offers exactly the
  implemented names of the function registry.
- Input is parsed, never executed as Lua. Limits: 500 characters per expression, nesting depth 50, 2000 nodes,
  200 cells, 5000 characters per cell.

### Not supported

`diff`, `solve`, `factor`, `integrate`, `subs`, `approx` (reserved: they report an error), `limit`,
`asin`/`acos`/`atan`, comparison operators, `plot2`, parametric and polar plots. These do not appear as keyboard shortcuts.

## Saved data

The notebook is saved to `calculator_notebook.lua` in KOReader's settings directory when you tap Save, close the
notebook, or KOReader suspends or exits. Titles, cell order, ids, types, sources and graph viewports are stored.
**Outputs are not stored**: reopened cells are Idle and need Run. A damaged file is repaired where possible, or
replaced by an empty notebook, with a message; a file written by a newer version is left untouched and Save is
refused. A failed save keeps the notebook in memory with a message. Books, `.sdr` data and annotations are never
touched.

## Limitations

- No touch-drag or other gestures; page buttons and on-screen buttons only.
- Single default notebook (the file format allows several).
- Landscape and rotation were not checked; device performance is unmeasured.

## Development

```sh
export PATH=$HOME/.luarocks-luajit/bin:$PATH
busted
luacheck main.lua _meta.lua calccas.lua calcplot.lua calccas calcplot calcnb calcui spec
```

Last run: `busted` 971 successes / 0 failures / 0 errors; `luacheck` 0 warnings / 0 errors in 113 files.

Layers: pure `calcnb/` (notebook model, statements, persistence logic) → engines `calccas/` and `calcplot/` →
`calcui/` widgets and `main.lua`. The engines and `calcnb/` do not require KOReader.
