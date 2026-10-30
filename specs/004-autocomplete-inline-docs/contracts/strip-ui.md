# Contract: Suggestion strip (UI)

## Layout

While a cell is being edited the view stacks, top to bottom: toolbar, page, page bar, **suggestion strip**, keyboard.

- The strip height is fixed for a given screen size and orientation: two rows (chips, documentation), one row (chips
  only) or none, chosen by `calcui/strip_sizing.lua` so that at least `MIN_PAGE_LINES` editor lines remain above it.
  It is included in the page height budget whether or not it shows anything. When empty it is blank, not collapsed,
  so the page never shifts while typing. With zero rows, autocomplete is off for that layout and the keyboard is
  unchanged.
- Chip row: up to 4 chips on a compact screen, 6 otherwise, plus `+N` when more match. Each chip shows the name, with
  `()` for callable names. A reserved command is shown dimmed with a trailing mark and "not available yet" text in its documentation
  row. The highlighted chip is drawn in the existing selected-button style.
- Documentation row: for the highlighted suggestion, the signature and the summary, and the first example on a second
  line when the screen height allows it. Text is wrapped and cut to the row; a long name is shortened for display only.
- The keyboard is unchanged, and the strip never overlaps it or the line that holds the cursor (the existing reveal logic
  is given the reduced `content_h`).

## Repaint rules

1. Typing, cursor movement and highlight changes never call `NotebookView:rebuild()` and never `setDirty` the whole view.
2. The strip repaints with `UIManager:setDirty(strip, "ui", strip.dimen)` and only when `session:update` or a
   move/select/dismiss returned `changed = true`.
3. The edited cell repaints through the editor's own update, as it does today.
4. `rebuild()` (after a run, a cell switch, a rotation) rebuilds the strip once and passes it the current names.

## Touch

- Tap the highlighted chip: accept it. Tap any other chip: move the highlight to it (its documentation shows in the
  documentation row) and do not accept. The first chip is highlighted when the list appears, so the common case
  (`dif`, then tap `diff()`) is one tap. The `+N` count is informational and not tappable.
- Dismiss: a small `✕` at the end of the chip row. It hides the strip for the current word and leaves text and cursor
  as they are.
- A tap on the documentation row does nothing.

## Keys (only where `Device:hasKeys()`, and only while the strip is shown)

| Key | Action |
|-----|--------|
| `PgFwd` / `PgBack` | Move the highlight (replaces paging for that moment) |
| `Press` (and `Tab` on devices with a keyboard) | Accept the highlighted suggestion |
| `Back` | Dismiss without closing the notebook |

When the strip is hidden these keys do what they do now. A device without keys loses nothing.

## Accepting

1. The view asks `session:accept()` for the edit.
2. `CellEditor:replace_word(edit)` moves to `edit.last + 1`, deletes `edit.last - edit.first + 1` characters backwards,
   types the insert with a suppressed `on_change`, and places the cursor with `moveCursorToCharPos(edit.charpos)`. A
   whole-cell selection mark is cleared first.
3. `on_change` fires once at the end; the strip is then hidden by the session and repainted.
4. Nothing is run, saved or marked as run. The cell's dirty state follows the normal text-change path.

## Failure behaviour

Any error while updating or drawing the strip is caught by the existing `guard` wrapper pattern: the strip is cleared and
editing continues. The editor, the keyboard and the notebook are never left in a half-updated state by it.
