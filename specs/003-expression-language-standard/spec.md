# Feature Specification: Expression Language Standard

**Feature Branch**: `003-expression-language-standard`

**Created**: 2026-10-30

**Status**: Draft

**Input**: User description: "Define and standardize the expression language for the native Lua KOReader CAS plugin: mathematics-oriented, inspired by SymPy and Math.js, on the existing parser and AST; audit first, then produce a versioned language reference, a formal grammar and parser conformance tests; never execute user input as Lua; do not implement unsupported commands to satisfy examples."

The audit of what exists today is in [audit.md](audit.md). Read it first: it records the current behaviour and the incompatibilities this
feature must settle.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One written language reference (Priority: P1)

A user, a contributor, or a later feature author opens one document and learns exactly what can be typed in a notebook cell: the
forms of an expression, the order of operations, how statements and comments are written, which names are reserved, which commands
exist today and which are only planned. Today these rules are scattered across the README, two contracts and several code tables, and
they disagree in places (for example the reserved-name list, and the claim that `diff` is a command).

**Why this priority**: every other change in this feature, and every keyboard shortcut or help text, depends on one agreed
definition. It is also the part that carries no risk to saved notebooks.

**Independent Test**: Give the reference to someone who has not seen the code and ask them to predict the result of 20 sample cells
(valid, invalid, and edge cases). The predictions match the actual results for all 20.

**Acceptance Scenarios**:

1. **Given** the language reference, **When** a reader looks up any construct the plugin accepts, **Then** its meaning, its result and its error cases are stated, with a version number for the reference.
2. **Given** a command name that is not yet supported (for example `solve`), **When** the reader looks it up, **Then** it is listed as reserved and planned, never as available.
3. **Given** the formal grammar, **When** any line of the reference's worked examples is checked against it, **Then** the grammar accepts exactly the examples marked valid and rejects those marked invalid.

---

### User Story 2 - Predictable parsing, checked by conformance tests (Priority: P1)

A user types expressions and statements and gets the result the reference promises: operator precedence, right-associative `^`,
unary minus looser than `^`, parentheses, assignments, function definitions, calls with several comma-separated arguments,
relations written with `==`, plot ranges, comments and multi-line input. An invalid input always produces a clear message with
its line and position, never a crash and never any execution of the text as program code.

**Why this priority**: this is the user-visible behaviour the standard exists to guarantee. The conformance tests are what keep it
guaranteed.

**Independent Test**: Run the conformance suite. Every valid example parses to the documented structure, every invalid example
fails with the documented error kind and position, and a hostile-input set (program-code-like text, control characters, very long
or deeply nested input) never throws.

**Acceptance Scenarios**:

1. **Given** `-2^2` and `2^3^2`, **When** evaluated, **Then** the results are `-4` and `512`.
2. **Given** `f(x) = x^2` and then `f(3)`, **When** run, **Then** the second statement gives `9`.
3. **Given** `x^2 - 4 == 0`, **When** parsed, **Then** it is kept as an equation between two expressions, and is not evaluated to true or false.
4. **Given** `plot(sin(x), cos(x), x=-5..5)`, **When** parsed, **Then** the final argument is a range for `x` and the other arguments are functions; **Given** `y = -5..5` as an ordinary statement, **Then** it is an error, because ranges exist only where a command asks for one.
5. **Given** `a = 2  # width`, **When** run, **Then** the comment is ignored and `a` is 2.
6. **Given** an expression split over lines inside open brackets or after a trailing operator, **When** run, **Then** it is read as one statement; **Given** a line that ends complete, **Then** the next line starts a new statement.
7. **Given** text such as `os.execute("x")` or `print(1)`, **When** run, **Then** a syntax or unknown-name error is shown and nothing else happens.

---

### User Story 3 - Exact and approximate results stay distinct (Priority: P2)

A user sees at a glance whether a result is exact (`1/3`, `sqrt(2)`, `pi`) or approximate (`0.3333333333`, `1.41421356`).
Exact rational arithmetic stays exact while the numbers are within range; approximation happens only where the user asks for it
or where no exact form exists, and is marked as such. Symbols that are not defined stay symbolic rather than being an error.

**Why this priority**: it is the part of the language that affects the correctness a user relies on, but it largely formalises
what the engine already does.

**Independent Test**: A table of 30 inputs with expected exact/approximate classification and printed form, run by the suite.

**Acceptance Scenarios**:

1. **Given** `1/3 + 1/6`, **When** evaluated, **Then** the result is the exact `1/2`.
2. **Given** `sin(1)`, **When** evaluated, **Then** the exact form is kept and an approximate value is shown beside it, marked as approximate.
3. **Given** `x + 1` with `x` undefined, **When** evaluated, **Then** the result is the symbolic `x+1`, not an error.
4. **Given** `1/0`, `sqrt(-1)` or `log(0)`, **When** evaluated, **Then** a named domain or division error is shown, not a numeric infinity or NaN.

---

### User Story 4 - Old notebooks keep working or fail clearly (Priority: P2)

A user who saved a notebook with the current version reopens it and runs it. Every cell either gives the same result as before or,
where this standard deliberately tightens the language, shows a clear message that says what to change; saved text is never
silently rewritten or lost.

**Why this priority**: constitution priority one is data safety. Any tightening of the language must not corrupt or discard
saved work.

**Independent Test**: A fixed set of saved-cell sources taken from the current behaviour (the audit's probe table plus the
existing reference cases) is run before and after; every difference is on a list of documented, deliberate changes.

**Acceptance Scenarios**:

1. **Given** a saved cell the old language accepted, **When** it is run under the new language, **Then** it gives the same result or a message that names the exact construct and the replacement (for example `2x` fails with "write 2*x").
2. **Given** `1e3` and `1e-3`, **When** evaluated, **Then** the results are `1000` and `1/1000` (the previous language silently read them as `e3` and `e-3`).
3. **Given** a saved notebook, **When** it is opened and saved again without edits, **Then** the cell sources are unchanged byte for byte.

---

### Edge Cases

- An empty cell, a cell of only comments, and a cell with a trailing comment on the last line.
- `x=-5..5` outside a command (an ordinary statement, or inside `simplify`), and ranges with reversed or non-numeric bounds.
- A line that ends with an operator or comma as the last line of the cell (a continuation with nothing to continue).
- A name that is a command (`solve = 2`), a constant (`pi = 3`), or a function name used as a variable (`sin + 1`).
- `=` versus `==` mistakes: `x == 2` as a statement, `f(x) == x^2`, `a = b = 2`, `2 = x`.
- Calling a supported function with the wrong number of arguments, with an empty argument (`f(1,)`), or with a relation as an argument where a value is needed.
- Numbers: very large integers, decimals with many digits, a leading or trailing `.`, scientific notation with a huge exponent (`1e999`, `1e-999`), a missing exponent (`1e`, `1e+`), `2e` and `2*e`, and results that exceed exact range.
- Expressions at the size limits (500 characters, depth 50, 2000 nodes) and just over them.
- Non-ASCII text, control characters and a byte-order mark in a cell.
- Undefined symbol used inside a function body, then defined later (the function must see the new value or the documented snapshot rule).

## Requirements *(mandatory)*

### Functional Requirements

**The reference and the grammar**

- **FR-001**: The project MUST contain one versioned language reference describing every supported construct, with the reference's own version number (starting at 1.0) and a changelog.
- **FR-002**: The project MUST contain a formal grammar for every supported construct, and every example in the reference MUST be marked valid or invalid against it.
- **FR-003**: Planned and unsupported features MUST be documented in a separate "future" section that is clearly not part of the supported language, and nothing in the reference's supported sections MAY describe them as available.
- **FR-004**: The audit of the current language (audit.md) MUST be kept with the feature and updated with the final list of deliberate behaviour changes.

**Expressions**

- **FR-005**: The language MUST support conventional infix expressions with `+`, `-`, `*`, `/`, `^`, unary `+` and unary `-`, and parentheses.
- **FR-006**: `^` MUST be right-associative and MUST bind more tightly than unary minus on its left (`-2^2 = -4`, `2^3^2 = 512`); a unary minus in the exponent (`2^-1`) MUST be accepted.
- **FR-007**: `*` MUST be required between factors. Implicit multiplication (`2x`, `3(x+1)`, `(a)(b)`, `2pi`), accepted by the previous language, MUST be a syntax error whose message names the construct and suggests the explicit form (for example "write `2*x`"). Saved text is never rewritten (FR-027).
- **FR-008**: Numbers MUST be integers, decimals (`2.5`, `.5`), scientific notation and rationals formed by division. Scientific notation is a number followed immediately (no spaces) by `e` or `E`, an optional sign and digits: `1e3` is 1000 and `1e-3` is 1/1000, both exact. `2*e` and `2 * e` remain the constant `e`, and a name such as `e3` that is not preceded by a digit stays a name; a number with more digits than exact arithmetic supports MUST become an approximate number, not an error, unless it exceeds the representable range.
- **FR-009**: Identifiers MUST be letters followed by letters, digits and underscores, at most 32 characters. An identifier that is not defined MUST stay symbolic.
- **FR-010**: The named constants `pi` and `e` MUST be supported, MUST be reserved, and MUST print exactly with an approximate value beside them where a numeric value is wanted.

**Statements**

- **FR-011**: `name = expression` MUST define a variable with the value of the expression, and `name(param, ...) = expression` MUST define a function; both MUST refuse reserved names with a clear message.
- **FR-012**: `==` MUST form an equation or equality between two expressions, held as a relation in the syntax tree and not evaluated to true or false. A relation MUST be rejected wherever a plain value is required, with a message saying so.
- **FR-013**: A single `=` MUST mean assignment or definition only, and only as the whole statement's top-level form; `=` MUST NOT be accepted inside an expression or call.
- **FR-014**: A function call MUST take comma-separated arguments. Each supported function MUST state how many arguments it takes, and a wrong count MUST give an error that names the function, the expected and the actual count.
- **FR-015**: Newlines MUST separate statements, except where the reference's continuation rules say a line continues: inside open brackets, and after a line that ends with a binary operator or a comma. A continuation with nothing following MUST be an error naming the line.
- **FR-016**: `#` MUST start a comment that runs to the end of the line, both at the start of a line and after a statement; text inside a comment MUST never be interpreted.

**Commands**

- **FR-017**: The names `simplify`, `expand`, `factor`, `solve`, `diff`, `integrate`, `subs`, `approx` and `plot` MUST be reserved so that notebooks cannot define them. Only the commands the engine actually supports MUST work; calling a reserved but unsupported command MUST give an "unsupported" error that says it is planned, and MUST NOT be offered as a keyboard shortcut.
- **FR-018**: All commands MUST follow one argument convention: the expression is the first argument, then the variable or option arguments, and ranges and options come last. The reference MUST state this convention once and apply it to every command.
- **FR-019**: A plot range `variable=lo..hi` MUST be recognised only where a command declares a range argument (today only `plot`), and anywhere else MUST give an error naming the construct. The bounds MUST be numeric constants; reversed, equal or non-finite bounds MUST give the existing range error.

**Numbers, domains and errors**

- **FR-020**: Exact rational arithmetic MUST be used wherever the values fit the exact range, and a result MUST be marked as exact or approximate, in the same way everywhere results are shown.
- **FR-021**: The reference MUST state the domain of every supported function and operator (division by zero, `0^0`, negative roots and logarithms, `tan` poles, overflow) and the error each violation gives, and the implementation MUST follow it.
- **FR-022**: Every failure MUST be reported as an error with a kind, a message, and the line and position where known; no input may crash the plugin or leave the environment partly changed.
- **FR-023**: The reference MUST list all reserved names (constants, functions, commands) in one place, and the list used by the program MUST be the same list.

**Safety and compatibility**

- **FR-024**: User input MUST never be executed as program code in any form; it is only read as text by the language's own reader.
- **FR-025**: The language MUST keep the current limits (500 characters per statement, depth 50, 2000 nodes, 100 names, 6 plot functions) unless the reference states and justifies a change.
- **FR-026**: Every deliberate change that makes a previously accepted input fail MUST be listed in the reference's compatibility section with the old behaviour, the new behaviour and the replacement text, and MUST show a message that names the replacement.
- **FR-027**: Saved notebook cell sources MUST NOT be rewritten by this feature; compatibility is handled when a cell is read, never by editing the saved text.
- **FR-028**: A conformance suite MUST cover every grammar rule and every listed error, plus a hostile-input set, and MUST run with the existing automated tests.
- **FR-029**: Result display and the keyboard shortcut list MUST use the names in the reference, so that no shortcut can insert text the language rejects.

### Key Entities

- **Language reference**: the versioned document; has a version, a supported-features section, a compatibility section and a future section.
- **Grammar**: the formal definition of the supported text; every reference example is classified against it.
- **Statement**: one assignment, function definition, command call or expression, with its line number; a cell is a list of statements.
- **Expression**: a mathematical expression tree: numbers (exact or approximate), constants, symbols, sums, products, powers, function calls.
- **Relation**: an equation or equality between two expressions, kept unevaluated.
- **Reserved name**: a constant, function or command name that user definitions cannot reuse.
- **Range argument**: `variable=lo..hi`, valid only in a command argument that declares a range.
- **Error**: a kind, message and location, shared by every stage.
- **Conformance case**: an input, its expected structure or error, and the grammar rule it exercises.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A reader given only the reference correctly predicts the outcome (value, exact or approximate, or error kind) of at least 19 of 20 unseen sample cells.
- **SC-002**: 100% of the reference's examples are covered by an automated conformance case, and every case passes.
- **SC-003**: Every grammar rule has at least one accepting and one rejecting case.
- **SC-004**: A hostile-input set of at least 100 inputs, plus every input in the existing fuzz set, never crashes the plugin and never changes a saved notebook.
- **SC-005**: 100% of cell sources in the pre-change reference set either give the same result as before or appear in the documented list of deliberate changes with a replacement message.
- **SC-006**: Opening and saving a saved notebook leaves every cell source byte-identical.
- **SC-007**: Every name offered by the keyboard shortcuts is accepted by the language, and no unsupported command is offered.
- **SC-008**: The reserved-name list, the supported-function list and the keyboard list are one list: a single automated check fails if any two differ.
- **SC-009**: Typing, evaluating and plotting remain as responsive as before on the emulator (no added noticeable delay on a 100-cell notebook).

## Assumptions

- The language reference starts at version 1.0 and describes what this feature ships; later language features bump the version.
- Typed decimals and scientific notation stay exact rational numbers (`0.5` is `1/2`, `1e-3` is `1/1000`) when they fit exact range, otherwise they become approximate numbers, because that keeps saved results unchanged and honours exact arithmetic; approximate numbers arise from functions that have no exact form, from numbers beyond exact range, and from the planned `approx` command. The reference states this explicitly.
- Implicit multiplication is rejected (decision of the user, 2026-10-30), with a replacement message; no deprecation period and no per-cell mode.
- Continuation rules are: a line continues inside open brackets and after a trailing binary operator or comma; there is no continuation character.
- `diff`, `solve`, `factor`, `integrate`, `subs` and `approx` are reserved by this feature but not implemented; implementing them is a separate feature. `simplify`, `expand` and `plot` are the only working commands.
- Multi-parameter function definitions are parsed and documented; calling a user function with several parameters is supported only if the current evaluation by substitution makes it free, otherwise it is future work.
- Relations other than `==` (`<`, `>`, `<=`, `>=`, `!=`) are future; they stay typable and give a syntax error until then, as today.
- The existing limits, error kinds and the notebook's atomic multi-line behaviour are kept.
- The pure engine layers (`calccas`, `calcnb`) carry all of this and remain free of KOReader classes; the keyboard and results screens only consume the reference's names.
- Saved notebooks are plain text per cell; the notebook file format does not change.
