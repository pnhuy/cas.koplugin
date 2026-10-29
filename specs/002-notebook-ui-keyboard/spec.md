# Feature Specification: Notebook Interface and Programming Keyboard

**Feature Branch**: `002-notebook-ui-keyboard`

**Created**: 2026-10-29

**Status**: Draft

**Input**: User description: "Design and implement a Jupyter-inspired notebook user interface and a full programming-oriented on-screen keyboard for the offline, native Lua CAS and graphing plugin for KOReader: scrollable cells with inputs and results shown together, multiline editing, CAS function shortcuts, inline graphs with a full-screen viewer, saved and restorable notebooks, optimized for E Ink, touch and hardware buttons, with no disruption to the reading session."

## Scope

This feature replaces the calculator-and-graph-screens interaction of the first release (specification `001-calculator-cas-graphing`) with a notebook as the primary interface. It builds on the engines already delivered there: expression evaluation, simplification, expansion, and 2D function plotting.

**In scope (this specification)**: the notebook and its cells, the on-screen keyboard and shortcut bar, result and error display, inline graphs and the full-screen graph viewer with button-driven zoom and pan, saving and restoring a notebook, and behavior across orientations and screen sizes.

**Out of scope**: new mathematical capabilities. Commands that the installed engine does not support (for example differentiation, integration, limits, equation solving, factoring, and parametric or polar plotting) are not provided by this feature. Their shortcuts appear only after the engine gains them. Also out of scope: rich equation editing, Markdown text cells, autocomplete, syntax highlighting, automatic re-execution of dependent cells, multiple named notebooks, graph image export, and gesture-driven pan and zoom.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Work through calculations in notebook cells (Priority: P1)

A reader studying a textbook opens the plugin from the Tools menu and sees a notebook: a vertical list of cells. They tap a cell, type an expression, tap Run, and the result appears directly below the input. They add more cells, and names defined in earlier cells (for example `a = 2`) are available to later ones. Every calculation stays on screen until they remove it.

**Why this priority**: The notebook is the primary interface. Without cells that run and show results in place, nothing else in this feature has a home.

**Independent Test**: Open the notebook, add three cells (`a = 2`, `a^2 + 1`, `expand((x+1)^2)`), run them in order, and verify each result appears under its cell and the second uses the value from the first.

**Acceptance Scenarios**:

1. **Given** an empty notebook, **When** the user opens it, **Then** it shows at least one empty input cell and the toolbar with Add cell, Save, Menu and Close.
2. **Given** a cell containing `expand((x+1)^2)`, **When** the user taps Run, **Then** the result `x² + 2x + 1` (or its plain-text equivalent) is shown directly below that cell and the cell shows a completed status.
3. **Given** cell 1 defines `a = 2` and has been run, **When** cell 2 containing `a^2 + 1` is run, **Then** its result is `5`.
4. **Given** a cell is being edited, **When** the user presses Enter on the keyboard, **Then** a new line is inserted and nothing is executed.
5. **Given** a cell containing an invalid expression such as `sin(`, **When** it is run, **Then** a clear error appears directly below the cell, the cell shows an error status, other cells are unchanged, and nothing crashes.
6. **Given** the user edits a cell that already has a result, **When** they have not yet run it, **Then** the previous result is unchanged and is shown as out of date.
7. **Given** a cell has been run and an earlier cell is then edited and run so that a name it defines changes, **When** the change takes effect, **Then** later executed cells are marked stale.
8. **Given** several cells, **When** the user chooses Run all, **Then** cells run one after another in notebook order and each shows its own result or error.
9. **Given** a long-running or limit-exceeding evaluation, **When** it is run, **Then** the interface remains responsive and a clear "limit exceeded" message is shown if it is abandoned.

---

### User Story 2 - Enter any supported expression using only the on-screen keyboard (Priority: P1)

On a device with no physical keyboard, the reader taps a cell and a keyboard docks to the bottom of the screen. It has letters, digits, operators, brackets, comparison and punctuation symbols, cursor keys, and a row of mathematical shortcuts. They can type a multiline definition, move the cursor, correct mistakes, and insert `sin( )` with the cursor placed inside the parentheses.

**Why this priority**: The plugin is unusable on touch-only readers if some syntax cannot be typed. A calculator-style keypad is not enough because expressions use identifiers, assignments, and punctuation.

**Independent Test**: With no hardware keyboard, enter `f(x) = x^2 + a*x`, then on a second line `plot(sin(x), x=-6..6)`, using only the on-screen keyboard, and confirm the text is exactly as intended.

**Acceptance Scenarios**:

1. **Given** the user taps a cell, **When** editing starts, **Then** the keyboard appears docked to the bottom, the notebook area shrinks to fit, and the cell being edited and its text cursor remain visible above the keyboard.
2. **Given** the default layout, **When** the user taps any letter, digit, or operator key, **Then** the matching character is inserted at the cursor.
3. **Given** Shift is tapped once, **When** a letter key is tapped, **Then** one uppercase letter is inserted and the layout returns to lowercase.
4. **Given** the Sym key is tapped, **When** the symbol page is shown, **Then** the characters `{ } < > <= >= == != % _ : ; | & ! ? \ " ' @ # $` are all available without long-press, and tapping Sym again returns to the letters page.
5. **Given** the symbol page's π key, **When** it is tapped, **Then** the text the engine accepts for pi (`pi`) is inserted rather than a character the engine cannot parse; the same applies to ∞ where the engine supports an infinity constant, otherwise the key is not shown.
6. **Given** the text `x^2 + ` with the cursor at the end, **When** the user taps the `sin` shortcut, **Then** the text becomes `x^2 + sin()` with the cursor between the parentheses, and the cell is not run.
7. **Given** multiline text, **When** the user uses Left, Right, Home, End, and Up/Down navigation, **Then** the cursor moves correctly across line boundaries and never splits a multi-byte character.
8. **Given** the user taps Backspace or Delete, **When** the cursor is next to a multi-byte character such as `π` or `²`, **Then** the whole character is removed.
9. **Given** text is selected, **When** the user uses Copy, Cut, Paste, or Select all, **Then** the clipboard and text behave as expected.
10. **Given** the keyboard is shown, **When** the user switches between letters and symbols or dismisses and reopens it, **Then** the text and cursor are preserved.
11. **Given** the shortcut bar, **When** it is displayed, **Then** it contains only commands the engine currently supports.

---

### User Story 3 - See graphs inline and explore them full screen (Priority: P1)

The reader runs a cell such as `plot(sin(x), cos(x))` and a graph appears directly below it, with axes, ticks, and distinguishable curves. They tap the graph to open it full screen, where buttons let them zoom, pan, reset, set exact axis ranges, and toggle the grid and axes. Closing the viewer returns them to the same cell and scroll position.

**Why this priority**: Graphing is a core reason for the plugin, and the notebook must show graphs in context.

**Independent Test**: Run `plot(sin(x), cos(x))`, confirm the inline graph, tap it, zoom in twice and pan right once, set X range to -3..3, close, and confirm the notebook is at the same position.

**Acceptance Scenarios**:

1. **Given** a cell containing `plot(sin(x), x=-6..6)`, **When** it runs, **Then** a graph with axes, tick marks, and the curve is shown directly below the cell with an Expand control and a short viewport description.
2. **Given** `plot(sin(x), cos(x))`, **When** shown, **Then** both curves are visible and distinguishable in grayscale (different line styles), not by color alone.
3. **Given** `plot(1/x)` or `plot(tan(x))`, **When** shown, **Then** no line connects branches across an asymptote and no error is raised for undefined points.
4. **Given** an inline graph, **When** the user taps it or Expand, **Then** the full-screen viewer opens with a title bar, a large canvas, a legend of the plotted functions, and buttons for Zoom in, Zoom out, Pan left, right, up, down, Reset, Range, Grid and Axes.
5. **Given** the viewer, **When** the user taps Zoom in, **Then** the visible range shrinks about its centre and the plot is redrawn once, without a full-screen flash.
6. **Given** the Range dialog, **When** the user enters X and Y limits or turns on automatic Y, **Then** invalid limits (for example min ≥ max or non-numbers) are rejected with a message and the previous range is kept.
7. **Given** the viewer is open, **When** the user closes it, **Then** the notebook returns to the same cell and scroll position, and the inline graph reflects the viewport last chosen in the viewer.
8. **Given** a plot command with an invalid argument, **When** it runs, **Then** an error appears below the cell instead of a graph.
9. **Given** an equal-scale option, **When** the user requests it, **Then** the X and Y scales are equal so circles are not distorted.

---

### User Story 4 - Keep notebooks between sessions and never disturb reading (Priority: P1)

The reader closes the notebook, reads on, and later reopens it to find their cells exactly as they left them. If KOReader is restarted, the notebook is still there. Closing it puts them back on the same book page. A damaged notebook file never causes a crash or loss of other data.

**Why this priority**: Losing work or disturbing the reading session breaks the core promise of a companion tool inside a reader.

**Independent Test**: Create three cells with a plot, save, restart KOReader, reopen the notebook, and verify sources, order, and graph viewport. Then corrupt the file and confirm a clear message and an empty notebook rather than a crash.

**Acceptance Scenarios**:

1. **Given** a notebook with cells, **When** the user taps Save, **Then** the notebook is written to local plugin storage and confirmed with a brief message.
2. **Given** a saved notebook, **When** KOReader is restarted and the notebook is reopened, **Then** cell order, cell sources, notebook title, and graph viewport settings are restored.
3. **Given** a reopened notebook, **When** outputs are shown, **Then** they are either re-computed or marked stale; an output is never shown as current unless it is known to match its source and the names it depends on.
4. **Given** a notebook file that is missing, empty, truncated, or otherwise malformed, **When** it is opened, **Then** a clear message is shown, the unreadable file is left untouched or kept as a backup, and an empty notebook is offered.
5. **Given** a save is interrupted, **When** the device restarts, **Then** the previous good copy of the notebook is still readable.
6. **Given** the user closes the notebook with unsaved changes, **When** they tap Close, **Then** their work is saved automatically or they are asked to save or discard; it is never silently lost.
7. **Given** a book is open, **When** the user opens and closes the notebook, **Then** the book's page, reading position, sidecar data, and annotations are exactly as before.
8. **Given** the user chooses to delete a notebook, **When** they confirm, **Then** it is deleted; without confirmation nothing is deleted.

---

### User Story 5 - Organize cells and reuse results (Priority: P2)

The reader reorders, duplicates, and deletes cells, copies a cell's source or its result, and inserts a result into another cell. A cell's status (idle, editing, running, completed, error, stale) is visible without relying on color.

**Why this priority**: Makes longer sessions practical, but a notebook with add, edit, run, and delete already delivers value.

**Independent Test**: With four cells, duplicate one, move it up, delete another with confirmation, copy a result, and paste it into a new cell.

**Acceptance Scenarios**:

1. **Given** a cell, **When** the user chooses Add above or Add below, **Then** an empty cell is inserted at that position.
2. **Given** a cell, **When** the user chooses Duplicate, **Then** an identical cell (without a result) appears below it.
3. **Given** a cell, **When** the user chooses Move up or Move down, **Then** it changes position and keeps its source; running order is by position.
4. **Given** a cell with content, **When** the user chooses Delete, **Then** they are asked to confirm before it is removed.
5. **Given** a result, **When** the user chooses Copy result or Copy source, **Then** the plain-text result or source is placed on the clipboard.
6. **Given** a result, **When** the user chooses Insert into cell, **Then** its text is inserted at the cursor of the chosen cell.
7. **Given** any cell, **When** its status changes, **Then** the status is shown with a text label or symbol (for example "running", "error", "stale").
8. **Given** the notebook menu, **When** the user chooses Clear all outputs, **Then** outputs are removed after confirmation and sources are untouched.

---

### User Story 6 - Notes and function inspection (Priority: P3)

The reader adds plain-text note cells between calculations, and in the graph viewer enters an x value to see a plotted function's value there.

**Why this priority**: Nice to have; deferred after the MVP.

**Independent Test**: Add a text cell and confirm it is saved and restored without being run; in the viewer enter x = 2 for `x^2` and see 4.

**Acceptance Scenarios**:

1. **Given** a text cell, **When** the notebook is run all, **Then** the text cell is skipped and its text is displayed as plain text.
2. **Given** the graph viewer, **When** the user enters an x value for a plotted function, **Then** the x value, the y value, and the function are shown, or "undefined" where the function has no value.

---

### Edge Cases

- A cell is empty when Run is tapped: nothing is executed and the user is told the cell is empty.
- A very long single line or very many cells: scrolling stays responsive and only visible cells need to be drawn.
- The keyboard is open while the screen is rotated: layout is rebuilt, text and cursor are preserved, and the active cursor stays visible.
- A very small screen: a compact keyboard layout is used with the symbol page, without keys smaller than a usable touch target.
- Tapping Run while another cell is running: the request is queued or rejected with a message; the notebook never runs two cells at once.
- Run all encounters an error: the error is shown under that cell; later cells still run, and the user can see which cells failed.
- Redefining a name used by earlier results: earlier results are not silently changed; they are marked stale.
- Plot with no function defined for any visible x: an empty plot with a notice rather than a crash.
- Names that look like commands (`sin = 3`) or reserved constants (`pi = 3`): rejected with a clear message.
- Pasted text with tabs, CRLF line endings, or invalid UTF-8: normalized or rejected safely; the notebook never stores invalid text.
- Notebook closed while a cell is running: the computation is abandoned and no state is corrupted.
- Out of storage space when saving: a clear message is shown and the previous saved copy is kept.
- A hardware keyboard is attached: typing works in the cell editor; every function remains reachable by touch.

## Requirements *(mandatory)*

### Functional Requirements

**Notebook and cells**

- **FR-001**: The plugin MUST open a notebook as its primary interface from the existing Tools menu entry, with a top toolbar (title, Add cell, Save, Menu, Close), a scrollable cell area, and a bottom keyboard area while editing.
- **FR-002**: The notebook MUST contain an ordered list of code cells, each with an input indicator, editable multiline source, a visible status, and an output area, and MUST keep each cell's results visible until the user clears or removes them.
- **FR-003**: Each cell MUST have a permanent identifier independent of its position; displayed execution numbers MUST reflect execution order only.
- **FR-004**: A visible Run control MUST execute the active cell; a separate Run and add cell action MAY be offered; the Enter key MUST insert a newline and MUST NOT execute.
- **FR-005**: Cells MUST share one evaluation environment so that names defined in one cell are available to later cells; a name defined with the same name as a built-in function or constant MUST be rejected with a message.
- **FR-006**: Execution MUST read the source, evaluate it, capture the result or error, update the cell output, execution number, and status, and refresh only the affected screen regions.
- **FR-007**: Editing a cell MUST NOT change its previous output until it is run; the output MUST then be shown as out of date.
- **FR-008**: When a cell redefines a name, later executed cells MUST be marked stale; the system MAY conservatively mark all later executed cells stale.
- **FR-009**: Run all MUST run cells in notebook order and continue past cells that fail.
- **FR-010**: Each cell MUST show one of the states Idle, Editing, Running, Completed, Error, or Stale, conveyed by text or symbol and not by color alone.
- **FR-011**: Users MUST be able to add a cell above or below, edit, duplicate, delete (with confirmation when the cell has content), move up and down, copy source, copy result, and clear output; the frequent ones MUST be directly visible and the others MAY be in a menu.
- **FR-012**: The notebook menu MUST provide New notebook, Open notebook, Save as, Run all, Clear all outputs, Settings, and Help; a single default notebook is sufficient for the first release if the stored format can hold more than one.
- **FR-013**: Evaluation MUST NOT be triggered by typing; it MUST occur only on an explicit Run action.
- **FR-014**: Evaluation MUST be bounded in time, size, and memory; when a bound is reached the cell MUST show a clear limit message, and the interface MUST stay responsive while a cell runs.

**Editing and keyboard**

- **FR-015**: Tapping a cell MUST start editing, show the keyboard docked to the bottom, resize the notebook area, scroll the cell into view, and keep the text cursor visible above the keyboard.
- **FR-016**: The editor MUST support multiline text, cursor movement (Left, Right, Up, Down, Home, End), Backspace, Delete, Select all, Copy, Cut, and Paste, and MUST keep cursor and selection positions valid for multi-byte (UTF-8) text.
- **FR-017**: The keyboard MUST provide a default page with a mathematical shortcut row, a digit row, three letter rows with Shift and Backspace, an operator row (`( ) [ ] ^ * / + - =`), and an editing row (Sym, comma, left, Space, right, period, Enter); the exact arrangement MAY be adapted to screen size without removing any character.
- **FR-018**: The keyboard MUST provide a symbol page with `{ } < > <= >= == != % _ : ; | & ! ? \ " ' @ # $` and π, and every character the engine's syntax needs MUST be reachable without long-press.
- **FR-019**: Shift MUST support one-shot capitalization and MAY support a lock; Sym MUST toggle the symbol page; switching pages MUST preserve text, cursor, and selection.
- **FR-020**: Symbol keys MUST insert text that the engine accepts (for example π inserts `pi`).
- **FR-021**: Every expression the engine supports MUST be enterable using only the on-screen keyboard.
- **FR-022**: The keyboard MUST occupy a share of the screen sized from the screen dimensions, orientation, and touch-target size (about 35–55% of the height where feasible), MUST use a compact layout with extra pages on very small screens, and MUST work in portrait and landscape.
- **FR-023**: Key presses MUST insert text at the cursor without rebuilding the notebook, MUST NOT lose rapid consecutive presses, and MUST NOT trigger evaluation.

**Shortcuts**

- **FR-024**: A shortcut bar MUST offer grouped common commands (basic mathematics, trigonometry, algebra, graphing), and MUST show only commands the installed engine supports.
- **FR-025**: Tapping a shortcut MUST insert its syntax at the cursor, place the cursor inside the argument list, preserve surrounding text, keep the keyboard open, and not evaluate.
- **FR-026**: The selected shortcut group MUST persist during the editing session; changing group MUST NOT re-run anything.

**Results and errors**

- **FR-027**: Results MUST be shown in readable plain-text notation that is always available (for example `x^2` as `x²`, `x_1` as `x₁`), and MUST support integers, rational numbers, decimals, symbolic expressions, and error messages; equations, solution sets, and matrices MUST be shown when the engine produces them.
- **FR-028**: The canonical result text MUST remain separate from its displayed form, and copying MUST copy the canonical text so it can be pasted back into a cell with the same meaning.
- **FR-029**: Errors MUST appear directly below their cell with a clear description (for example syntax error with position, division by zero, unsupported operation, limit exceeded) and MUST NOT close the notebook or crash KOReader.
- **FR-030**: Long outputs MUST be truncated with an Expand control that shows the full text.

**Graphs**

- **FR-031**: A cell may produce a graph through a plot command taking one or more functions of `x` and an optional x range; the graph MUST appear directly below its cell.
- **FR-032**: Inline graphs MUST show axes, ticks, optional grid, curves, a viewport description, and an Expand control, and MUST be sized to the available width.
- **FR-033**: Multiple functions MUST be distinguishable by line style and not only by color.
- **FR-034**: Plotting MUST reuse the existing plotting rules: no connection across discontinuities, nothing drawn for undefined values, and no error for the plot as a whole on undefined points.
- **FR-035**: Tapping an inline graph MUST open a full-screen viewer with a title bar, a large canvas, a legend, and buttons (not gestures) for Zoom in, Zoom out, Pan in four directions, Reset, Range, Grid toggle, and Axes toggle.
- **FR-036**: The Range dialog MUST allow X min, X max, Y min, Y max, automatic Y, and equal axis scaling, and MUST validate before redrawing, keeping the previous range on error.
- **FR-037**: Closing the viewer MUST return to the same notebook cell and scroll position and carry the chosen viewport back to the inline graph.
- **FR-038**: Graph results MUST be cached and recomputed only when the functions or viewport change, and redrawing MUST refresh only the graph region.

**Persistence and safety**

- **FR-039**: The notebook MUST be stored locally in plugin-specific storage with title, cell order, cell identifiers, cell types, sources, notebook settings, and graph viewport settings; cached outputs MAY be stored but MUST NOT be trusted as current after the source or environment changes.
- **FR-040**: On reopening, the notebook MUST restore order, sources, settings, and (where practical) scroll position, and MUST mark outputs stale unless they can be shown to be valid.
- **FR-041**: Saving MUST not destroy the previous good copy if interrupted, and a malformed or unreadable notebook MUST produce a clear message and MUST NOT crash KOReader or discard the file.
- **FR-042**: Unsaved changes MUST NOT be silently lost when the notebook is closed.
- **FR-043**: The plugin MUST NOT modify any book, its position, its sidecar data, or its annotations, and closing it MUST return the user to the same reading position.
- **FR-044**: Deleting a notebook MUST require explicit confirmation.

**Layout, input, and platform**

- **FR-045**: The interface MUST adapt to portrait and landscape orientations and to small screens, preserving text, cursor, and scroll position when the orientation changes.
- **FR-046**: All essential functions MUST be reachable by touch without long-press, multi-finger, or drag gestures, and MUST also be usable with hardware buttons where the device has them; a hardware keyboard, when present, MUST work for typing.
- **FR-047**: The interface MUST be legible in grayscale and on E Ink: high contrast, no color-only meaning, large enough touch targets, no animation, and no screen refreshes beyond what a change requires.
- **FR-048**: Only the visible part of long notebooks needs to be drawn, and the number of live interface objects MUST NOT grow without bound.
- **FR-049**: All user-visible text MUST use KOReader's localization, and the interface MUST honor KOReader font size and scaling preferences where feasible.
- **FR-050**: The mathematical and plotting engines MUST remain independent of the notebook interface, and the whole feature MUST work offline using only native Lua and KOReader components, with no web, script runtime, or external framework.
- **FR-051**: Any capability that KOReader cannot supply, such as a keyboard or editor that fits these requirements, MUST be covered by the smallest necessary extension and the limitation documented.

### Key Entities

- **Notebook**: A titled, ordered collection of cells with settings and a shared evaluation environment; stored locally.
- **Cell**: A permanent identifier, a type (code, or text in P3), source text, an execution number, a status, and an optional output.
- **Output**: The result of running a cell: a text result (with canonical and displayed forms), an error, or a graph. It records whether it is current or stale.
- **Evaluation Environment**: The names (variables and functions) defined by cells and shared by later cells.
- **Graph**: The functions, x range, and viewport (limits, automatic Y, grid, axes, equal scale) for one plot result.
- **Keyboard Layout**: A page of keys (letters, symbols, shortcuts) and its current modifier state.
- **Shortcut**: A named command with its inserted text and cursor position, available only if the engine supports it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can create a notebook, run three dependent cells and see all three results in under 3 minutes on a touch-only device.
- **SC-002**: 100% of characters needed by the engine's syntax can be typed using only the on-screen keyboard, verified by typing every sample expression from the reference set.
- **SC-003**: Tapping a shortcut places the cursor correctly in 100% of the supported shortcuts, verified by an automated check on the insertion rules.
- **SC-004**: Typing 200 characters with the keyboard never triggers an evaluation and loses no keystrokes.
- **SC-005**: With the keyboard open, the cursor of the edited cell is visible above the keyboard in 100% of tested positions in both orientations.
- **SC-006**: A cell with an invalid expression, a limit-exceeding expression, or a plot with undefined regions never crashes KOReader in a set of at least 50 invalid inputs.
- **SC-007**: Reopening a saved notebook after a KOReader restart restores 100% of the cell sources, order, title, and graph viewports.
- **SC-008**: A corrupted notebook file leads to a clear message and a working empty notebook in 100% of tested corruptions (empty, truncated, wrong type, invalid text).
- **SC-009**: After opening and closing the notebook with a book open, the book page, sidecar file, and annotations are byte-for-byte unchanged.
- **SC-010**: Inline graphs of up to four functions appear within 3 seconds of running a cell on the emulator, and the interface remains responsive (a tap is acknowledged within 1 second) while plotting; timing on a real E Ink device is measured and recorded.
- **SC-011**: Zoom, pan, and reset on a graph each take one tap and redraw only the graph region, with no full-screen refresh.
- **SC-012**: All screens remain legible in a grayscale rendering, and every cell status and curve can be told apart without color.
- **SC-013**: Scrolling a notebook of 100 cells remains responsive, with live interface objects bounded by the visible area rather than the notebook length.

## Assumptions

- Target users are readers on touch-first E Ink devices who may have no hardware keyboard; hardware buttons and keyboards are optional extras.
- The notebook language is the existing expression language plus a thin cell-level layer: assignment (`a = 2`), function definition (`f(x) = x^2 + a*x`), and a `plot(...)` command with optional range (`x=-6..6`). These are part of this feature because the notebook cannot operate without them; they do not add new mathematics.
- The existing engine supports evaluation, simplification, and expansion only. Differentiation, integration, limits, solving, factoring, and parametric, polar, or implicit plotting are not available, so their shortcuts are hidden until the engine supports them. The names in the original brief (`diff`, `solve`, `integrate`, `plot2`, `parametric`, `polar`, `limit`, `factor`, `asin`, `acos`, `atan`, `ln`) are therefore not exposed unless supported at the time of release.
- The notebook becomes the main interface. The first-release Calculator and Graph screens remain available until the notebook reaches parity, and are then retired; the exact retirement point is decided during planning.
- A single default notebook is enough for the first release; the stored format must not prevent several notebooks later.
- Notebook data is stored in a plugin-specific location in KOReader's settings area, separate from books and their sidecar files.
- The target KOReader version stays the one already used by the project; any API this feature relies on must be checked against that version before use.
- Performance on real E Ink devices is measured as part of the feature and recorded; emulator timings are not treated as representative.
- Rotation, physical keys, and real-device behavior are not yet verified for the first-release screens and will be checked for the notebook too.
