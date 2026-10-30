# Feature Specification: Autocomplete and Inline Documentation

**Feature Branch**: `004-autocomplete-inline-docs`

**Created**: 2026-10-30

**Status**: Draft

**Input**: User description: "Add context-aware autocomplete and inline mathematical documentation to the existing KOReader native Lua CAS notebook. Preserve the existing notebook interface, full programming keyboard, symbolic engine, and graph plotting functionality."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Complete a command or function name while typing (Priority: P1)

While editing a cell, the user types the start of a name, for example `dif`. A strip of suggestions appears directly above the on-screen keyboard. Tapping a suggestion replaces the partly typed name with the full call template, with the cursor placed inside the parentheses ready for the first argument. Text before and after the name is untouched, and nothing is run.

**Why this priority**: This is the core value: fewer keystrokes on a slow, small keyboard. Everything else builds on it, and it is a usable MVP by itself with the built-in names only.

**Independent Test**: Open a cell, type `dif`, confirm `diff` is offered, tap it, and confirm the cell reads `diff()` with the cursor between the parentheses and no result shown. Repeat with `si` in the middle of `1 + si + 2`, and confirm the surrounding text survives.

**Acceptance Scenarios**:

1. **Given** an empty cell being edited, **When** the user types `dif`, **Then** a suggestion for `diff` appears above the keyboard and the cell text is still `dif`.
2. **Given** `dif` typed and the `diff` suggestion visible, **When** the user taps it, **Then** the cell text becomes `diff()` and the cursor sits inside the parentheses.
3. **Given** the text `1 + si + 2` with the cursor right after `si`, **When** the user selects `sin`, **Then** the text becomes `1 + sin() + 2`, the cursor is inside the parentheses, and `1 + ` and ` + 2` are unchanged.
4. **Given** a suggestion for a name that takes no arguments, such as the constant `pi`, **When** the user selects it, **Then** only the name is inserted, with no parentheses, and the cursor ends after it.
5. **Given** a selection was made, **When** the insertion finishes, **Then** the cell has not been run and its previous result, if any, is unchanged.
6. **Given** suggestions are visible, **When** the user keeps typing, **Then** the list narrows to the new prefix, and when nothing matches the strip disappears.

---

### User Story 2 - See what a name does before choosing it (Priority: P2)

Each suggestion shows enough to choose it with confidence: the signature, a one-line description, and an example. The user can read this without leaving the cell or running anything.

**Why this priority**: The calculator has a language of its own (explicit `*`, ranges in `plot`, reserved commands), so users benefit from seeing how a name is used. It depends on User Story 1 for the place to show it.

**Independent Test**: Type `plot`, and confirm the highlighted suggestion shows its signature with the optional range argument, a short description, and an example that can be pasted into a cell and run successfully.

**Acceptance Scenarios**:

1. **Given** suggestions are visible, **When** one is highlighted, **Then** its signature, description and example are shown together with it, without hiding the keyboard or the cursor line.
2. **Given** every built-in function, command and constant, **When** its documentation is examined, **Then** each has a signature, a description of at most one line and at least one example.
3. **Given** a documented example for an implemented name, **When** it is run in a cell, **Then** it succeeds, so documentation never contradicts the engine.
4. **Given** an alias such as `ln`, **When** it is shown, **Then** the entry says it is the same as `log`.

---

### User Story 3 - Suggest my own variables and functions (Priority: P2)

Names the user has defined in the notebook, such as `rate = 5` or `f(x) = x^2`, are offered like built-in names. Defined functions are offered with their parameter names. After a cell is run again, the list reflects what is currently defined, and a name that is no longer defined is no longer offered.

**Why this priority**: This makes the autocomplete "context-aware" and is part of the MVP acceptance criteria, but it needs the basic strip from User Story 1 to exist first.

**Independent Test**: Run a cell `rate = 5`, edit another cell, type `ra`, and confirm `rate` is offered. Change the first cell to `speed = 5`, run it, and confirm `rate` is gone and `spe` offers `speed`.

**Acceptance Scenarios**:

1. **Given** a cell defining `rate = 5` has run, **When** the user types `ra` in any cell, **Then** `rate` is suggested and is marked as a variable.
2. **Given** `f(x) = x^2` has run, **When** the user types `f`, **Then** `f(x)` is suggested as a user function, and selecting it inserts `f()` with the cursor inside the parentheses.
3. **Given** a defined name that has since been removed or renamed and its cell re-run, **When** the user types its prefix, **Then** it is no longer suggested.
4. **Given** a cell that was edited but not yet run, **When** the user types in another cell, **Then** suggestions reflect the last run, not unsaved text.
5. **Given** a name that has never been defined, **When** the user types its prefix, **Then** it is not suggested.
6. **Given** a cell where one statement failed, **When** suggestions are built, **Then** nothing from that run is offered (a failed run leaves the environment as it was before the run, so its earlier statements are not defined either), and the cell's definitions from its last successful run stay offered.

---

### User Story 4 - Use it without a touch screen and dismiss it (Priority: P3)

The user can choose a suggestion with touch alone, and also with the supported physical keys: move through the list, accept, and dismiss. Dismissing hides the strip and leaves the text exactly as it was.

**Why this priority**: Touch-only is already covered by the earlier stories. Physical key support and dismissal widen who can use the feature and give an escape from unwanted suggestions.

**Independent Test**: With suggestions showing, dismiss them and confirm the text and cursor are unchanged and nothing ran; reopen by typing another character. On a device with page-turn or direction keys, move through and accept a suggestion without touching the screen.

**Acceptance Scenarios**:

1. **Given** suggestions are visible, **When** the user dismisses them by touch or by the supported key, **Then** the strip hides and the cell text and cursor are unchanged.
2. **Given** suggestions were dismissed for the current word, **When** the user continues typing that word, **Then** they stay hidden until a new word is started.
3. **Given** a device with physical keys, **When** the user moves the highlight and accepts it, **Then** the result is the same as tapping that suggestion.
4. **Given** a device with no physical keys, **When** the feature is used, **Then** every action is reachable by touch.

---

### Edge Cases

- **Reserved commands** (`diff`, `integrate`, `solve`, `factor`, `subs`, `approx`): they are suggested, after available names, and marked "not available yet". Selecting one still inserts its template so a user can start writing it. Its documentation says that running it today gives the "reserved for a future version" message. The feature does not make these commands work.
- **Exact match**: when the typed word already equals a name (for example `sin`), the name is still offered so the user can add the parentheses.
- **Cursor in the middle of a word**: the word is taken up to the cursor, and the text after the cursor stays. If the remainder of the word follows the cursor, the whole word is replaced by the selection.
- **Inside a comment** (after `#`), inside a number such as `2e3`, or directly after a digit run: no suggestions are shown.
- **Plot range variables**: `x=` in `plot(sin(x), x=-1..1)` is a range variable and is not suggested as a notebook name.
- **Parameter names of a function being defined** (`f(x) = ...`) are not offered as notebook variables outside the body.
- **No match**: the strip is hidden, with no empty box and no layout shift.
- **Many matches**: the strip shows a limited number, best matches first, and says how many more there are.
- **Name clashes**: a user variable cannot reuse a built-in name (those are reserved), so no two entries share a name.
- **Long defined name or large notebook** (up to 100 defined names): suggestions remain responsive and long names are shortened for display but inserted in full.
- **Multi-line cells**: the word is found on the cursor's line, and only that line's text is considered.
- **Cell never saved or empty**: suggestions work without any prior run.
- **Environment unavailable** (nothing has run yet): only built-in names are offered.
- **Editor closed or cell changed** while suggestions are showing: suggestions disappear and nothing is inserted.
- **Language setting or interface language**: names stay as written in the language, because they are part of the language and not translated; descriptions follow the interface language where translations exist.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: While a cell is being edited, the system MUST offer suggestions for the word at the cursor, drawn from built-in functions and commands, built-in constants, notebook variables, and user-defined functions.
- **FR-002**: Suggestions MUST be matched by prefix on the typed word, ignoring letter case for matching and keeping the name's own case on insertion. Matching rules MUST be replaceable later without changing the rest of the feature.
- **FR-003**: Suggestions MUST be shown directly above the on-screen keyboard, MUST NOT cover the keyboard or the line being edited, and MUST NOT change the existing keyboard layout.
- **FR-004**: Each suggestion MUST show its name and kind (function, command, constant, variable or user function). The highlighted suggestion MUST also show its signature, a short description and an example for built-in names, and for a user function its signature built from its parameter names. A user variable has no description or example, so it shows its kind only.
- **FR-005**: Every built-in name MUST have a signature, a one-line description and at least one example. The documentation MUST agree with the language registry and MUST be the same text wherever it appears.
- **FR-006**: The user MUST be able to choose a suggestion by touch alone.
- **FR-007**: Where the device has physical keys, the user MUST be able to move the highlight, accept it and dismiss the suggestions with them. Their use MUST NOT conflict with existing key handling.
- **FR-008**: Accepting a suggestion MUST replace only the word being completed and MUST preserve all other text, including text after the cursor and other lines.
- **FR-009**: Accepting a function, command or user function MUST insert its call template with empty parentheses, and the cursor MUST be placed inside the parentheses at the first argument. Accepting a constant or variable MUST insert only the name, with the cursor after it.
- **FR-010**: Suggestions MUST include only names that are built in or currently defined in the notebook's run environment. Undefined names MUST NOT be offered.
- **FR-011**: The set of defined names MUST update when cells are run again, and MUST reflect removed or renamed definitions. Unsaved edits to other cells MUST NOT change it.
- **FR-012**: Reserved commands MUST be offered after available names, MUST be clearly marked as not yet available, and their documentation MUST state what running them does today. They MUST NOT be run, simulated or implemented by this feature.
- **FR-013**: The user MUST be able to dismiss suggestions without changing the cell text or cursor. A dismissed list MUST stay hidden for the current word.
- **FR-014**: The feature MUST NOT run, evaluate or save any cell as a result of showing, choosing or dismissing suggestions.
- **FR-015**: Showing or updating suggestions MUST redraw only the suggestion strip and the edited cell. It MUST NOT redraw the whole notebook or the keyboard keys, and MUST NOT cause extra screen flashes on E Ink.
- **FR-016**: The keyboard and the line holding the cursor MUST remain visible whenever suggestions are shown, on every supported screen size and orientation. On a screen too small to show both the suggestions and the cursor line, the suggestions shrink, and are turned off if needed, before the cursor line or the keyboard is covered.
- **FR-017**: The feature MUST work fully offline and MUST NOT use a network service, language server or model.
- **FR-018**: The choice and ranking of suggestions, the documentation and the text edit produced by accepting one MUST be computable without any on-screen element, so they can be tested without a device or emulator.
- **FR-019**: Existing behaviour MUST be preserved: the notebook layout, the full keyboard and its groups, cell execution, symbolic results, graph plotting, saved notebooks and their format. Notebooks saved before this feature MUST open and run identically.
- **FR-020**: With no match, no word at the cursor, or the cursor in a comment or inside a number, the strip MUST NOT be shown.
- **FR-021**: The number of suggestions shown at once MUST be limited, ordered best match first (exact match, then available built-ins, then user names, then reserved commands), and the remainder MUST be reachable or counted.
- **FR-022**: A failure in building suggestions MUST NOT interrupt editing: the strip is hidden and the cell remains editable.

### Key Entities

- **Completion context**: the text of the cell, the cursor position, and the set of names currently defined in the notebook. It contains everything needed to decide what to suggest.
- **Suggestion**: a candidate name with its kind, its availability (available or reserved), the template to insert, and where the cursor goes after insertion.
- **Documentation entry**: for each built-in name, its signature, one-line description, examples, alias information and availability. It has one source, shared with the language reference.
- **Edit result**: the new text and cursor position that follow from accepting a suggestion, with the range that was replaced.
- **Defined names**: the variables and functions known after the last run, with a function's parameter names.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Typing `dif` shows a `diff` suggestion, and selecting it yields `diff()` with the cursor between the parentheses in one tap, with no result produced.
- **SC-002**: A user can complete a function call such as `simplify(` in at most 2 key presses and 1 tap, where it previously needed one key press per letter.
- **SC-003**: After a variable is defined and its cell run, its name is suggested from any cell after typing 1 to 3 letters; after the definition is removed and the cell re-run, it is never suggested. This holds in 100 out of 100 scripted checks.
- **SC-004**: 100% of built-in names have a signature, description and example, and 100% of examples for available names run without error.
- **SC-005**: Accepting a suggestion preserves all text outside the completed word, verified in 200 randomized edits with no difference.
- **SC-006**: The suggestion strip appears or updates within 100 ms of a keystroke on the reference E Ink device, and typing latency with suggestions enabled is no more than 10% above latency with suggestions turned off.
- **SC-007**: Showing, updating or dismissing suggestions triggers no full-screen refresh and no redraw of the notebook list or keyboard keys.
- **SC-008**: The keyboard and the cursor line remain fully visible in every test of the supported screen sizes and orientations.
- **SC-009**: All choices of a suggestion are possible with touch alone, and with the supported physical keys on devices that have them.
- **SC-010**: The selection, ranking, documentation and edit logic are covered by automated tests that run without any device or on-screen element, and the existing test suite still passes unchanged.
- **SC-011**: Typing with suggestions in a notebook of 100 cells and 100 defined names stays within the latency limit in SC-006.

## Assumptions

- Reserved commands (`diff`, `integrate`, `solve`, `factor`, `subs`, `approx`) are offered and inserted, marked "not available yet", because the acceptance criteria require `diff` to be suggested and because showing them tells users what is planned. The alternative (hiding them) can be chosen later without changing the rest of the feature.
- "Defined or available in the active notebook environment" means built-in names plus names defined by cells that have been run successfully in the open notebook. Unsaved text in other cells does not count.
- A user-defined function is inserted with empty parentheses and the cursor inside, the same as a built-in. Its parameter names are shown in the signature, not inserted.
- Only the word the cursor is in is completed. Multi-word or fuzzy matching, learning from past use and ranking by frequency are out of scope for this version.
- Matching is by prefix only, as requested. Case is ignored when matching.
- The 100 ms and 10% limits are measured against the reference device used for the earlier notebook features. If none is available, the limits are verified on the emulator and flagged as unverified on hardware, as was done for feature 003.
- Physical-key support covers the keys the notebook already responds to, and the specific key mapping is a planning decision.
- Descriptions are written in English and go through the existing translation mechanism. Names and examples are not translated.
- The notebook file format does not change. The feature stores no new user data.
- The existing language registry and language reference remain the authority for what exists and what is available. This feature adds documentation text to them and does not add new commands to the language.
