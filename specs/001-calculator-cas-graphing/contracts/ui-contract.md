# Contract: KOReader UI

KOReader class names below are **expected** and must be verified in task T0 (see research R3).

## Entry point

- Tools menu item `Calculator` (`sorting_hint = "tools"`), present in FileManager and Reader. Opening it shows the
  Calculator view. Plugin never registers document hooks and never reads or writes the document or its sidecar.

## Calculator view (full-width dialog)

| Element | Behavior |
|---------|----------|
| Expression field | Multi-char text input with on-screen keyboard; content kept in session state when view closes |
| Variables field | Optional `x=2, y=3` list (secondary field, collapsed by default) |
| Keypad row | `^  (  )  /  sqrt(  pi  ⌫` inserts text at cursor (keyboards often lack `^`) |
| Buttons | **Evaluate**, **Simplify**, **Graph**, **Close** |
| Result area | Scrollable text; shows result, or error message (with caret position for syntax errors), or assumptions note |

Actions: Evaluate → `calccas.evaluate`; Simplify → `calccas.simplify`; Graph → opens Graph view (Calculator view
hidden, state kept). Each action runs inside `pcall`; an unexpected Lua error shows "Internal error" and is logged
without user data beyond the expression length.

## Graph view (full screen)

| Element | Behavior |
|---------|----------|
| Title bar | "Graph" + close (✕) |
| Canvas | Axes, grid (toggle), tick labels, curves with per-function line styles; redraws only its region |
| Function list | Opened by **Functions** button: rows `[✓/·] y = <expr>` (+ error marker); tap → Edit / Show-Hide / Remove; **Add** row |
| Range | **Range** button → dialog with Xmin, Xmax, Ymin, Ymax, Auto-Y toggle, Grid toggle; validates and keeps old values on error |
| Buttons | **Functions**, **Range**, **Reset**, **Calculator**, **Close** |
| Status line | "Plotting…" while computing; error summary like "1 function could not be plotted" |

Physical keys (feature-detected via `Device:hasKeys()`): Back closes the current view; Page keys scroll the result
or function list. Touch: all actions reachable by tap; no gestures required.

Orientation/resize: views rebuild layout on screen-size change; canvas cache invalidated by size change.

Closing the Graph/Calculator view calls `UIManager:close` on the widget, cancels pending plot ticks, frees the
canvas buffer, flushes settings, and issues a refresh of the previously shown screen (reader position unchanged).

## Settings keys (`<settings>/calculator.lua`)

`viewport` = `{xmin, xmax, ymin, ymax, auto_y}`, `grid` = boolean. Invalid values → defaults.

## Strings

All user-visible strings use `gettext`; error `kind` values map to translatable templates.
