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
- `plot(...)` draws inline. Tap the graph for the full-screen viewer: zoom, pan, reset, Range, Grid, Axes, 1:1 (equal axis
  scale) and **Inspect** (evaluate the plotted functions at an x value). Buttons only; no gestures are required.
- **Insert result** into another cell works only while that cell is being edited.

## Language

- Numbers: `3`, `2.5`, `.5`. Operators: `+ - * / ^` and parentheses. `^` is right-associative and binds tighter
  than unary minus: `-2^2 = -4`, `2^3^2 = 512`.
- Implicit multiplication: `2x`, `2(x+1)`, `(x+1)(x-1)`. `1/2x` means `(1/2)*x`.
- Assignment `a = 2`; function definition `f(x) = x^2 + a`; several statements per cell, one per line.
- Functions: `sin cos tan exp log ln sqrt abs`, `simplify`, `expand`, `plot`. Constants: `pi`, `e`. These names
  are reserved.
- Input is parsed, never executed as Lua. Limits: 500 characters per expression, nesting depth 50, 2000 nodes,
  200 cells, 5000 characters per cell.

### Not supported

`diff`, `solve`, `factor`, `integrate`, `limit`, `asin`/`acos`/`atan`, relations and equations as values,
`plot2`, parametric and polar plots. These do not appear as keyboard shortcuts.

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

Last run: `busted` 641 successes / 0 failures / 0 errors; `luacheck` 0 warnings / 0 errors in 90 files.

Layers: pure `calcnb/` (notebook model, statements, persistence logic) → engines `calccas/` and `calcplot/` →
`calcui/` widgets and `main.lua`. The engines and `calcnb/` do not require KOReader.
