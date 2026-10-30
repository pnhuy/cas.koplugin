# Quickstart: Verifying the Notebook

Nothing here has been run yet; results are recorded below as each phase is verified.

## Automated (pure Lua)

```sh
export PATH=$HOME/.luarocks-luajit/bin:$PATH
busted
luacheck main.lua _meta.lua calccas.lua calcplot.lua calccas calcplot calcnb calcui spec
```

## Emulator

Run `.../scratchpad/koreader/run.sh` (restart after every code change; plugins load once). Open Tools → Calculator.

1. Notebook opens with one empty cell and the toolbar (title, add, save, menu, close).
2. Tap the cell: the keyboard docks at the bottom and the cursor stays visible.
3. Type `a = 2`, Run. Add cell, `a^2 + 1`, Run. Result `5` under the second cell.
4. Enter inserts a newline; typing 200 characters runs nothing.
5. Symbols page: every character in FR-018 is present; `pi` inserts `pi`.
6. Tap `sin`: `sin()` with the cursor between the brackets.
7. `sin(` then Run: error under the cell, notebook still works.
8. `plot(sin(x), cos(x))`: inline graph; tap it; Zoom, Pan, Range, Grid, Axes, Reset; Close returns to the same cell.
9. Save, restart KOReader, reopen: sources, order, title and graph viewports are back; outputs are absent (Idle).
10. Corrupt `calculator_notebook.lua` (truncate it): a message and an empty notebook, no crash.
11. With a book open, record the book's `.sdr` file checksums before and after opening/closing the notebook.
12. Rotate the window (or `Device` rotation) with the keyboard open: text and cursor preserved.
13. Check the log (`kodev-run.log`) for errors.

## Device (not yet checked)

Grayscale legibility, refresh behavior, physical keys, page-turn buttons, and timing on real E Ink hardware.

## Recorded results

| Date | What | Result |
|------|------|--------|
| 2026-10-30 | T002 spike: `CellEditor` (InputText + stub keyboard) in the desktop emulator: system keyboard stays hidden; `addChars`, `leftChar`, `rightChar`, `delChar`, newline and `sin()` with cursor inside work; `isKeyboardVisible()` false | Pass. First run crashed on tapping the editor (needed `parent:getFocusableWidgetXY`, fixed in `CellEditor:init`) |
| 2026-10-30 | T004 spike: `○ ✎ … ✓ ✕ ◐ ▸ ↑ ↓ ← → ⏎ ⌫ π ∞ ≤ ≥ ≠` in the emulator (NotoSans) | All render; `⌫` and `▸` small. Device fonts not checked |
| 2026-10-30 | T025 keyboard demo in the emulator (540×720): digits, letters, Shift one-shot, Sym page, `<= >= == != π`, shortcuts (`sin()` with cursor inside, group switch), Enter, Backspace, arrows, Home/End/↑/↓/Del, clipboard keys | Pass per user ("all works"). First run froze on the group switch: the repaint targeted a nested widget; fixed by repainting the host. The keyboard was taller than computed (ButtonTable row gaps); it now measures itself. Demo editor overflowed the right/bottom edge (InputText adds its own border); demo-only, adjusted. Landscape, rotation and device fonts unchecked |
