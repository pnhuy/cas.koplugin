# Feature Specification: Offline Calculator with Symbolic Algebra and Function Graphing

**Feature Branch**: `001-calculator-cas-graphing`

**Created**: 2026-10-29

**Status**: Draft

**Input**: User description: "Build a fully native Lua Computer Algebra System (CAS) and 2D graphing calculator as a KOReader plugin. Offline math tool for readers studying mathematics, physics, engineering, and scientific subjects, optimized for E Ink. P1 (MVP): expression engine, symbolic algebra, 2D function plotting, KOReader UI. P2/P3 (polynomial operations, differentiation, graph interaction, integration, matrices, parametric/polar/implicit curves) are developed separately after the MVP."

## Scope

This specification covers the **MVP (P1)** only. The following are explicitly **out of scope** here and will be specified separately after the MVP works: polynomial factorization and equation solving, symbolic differentiation, zoom/pan buttons, point/root/intersection tools (P2); integration, matrices, parametric/polar/implicit curves, graph image export (P3).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Evaluate a Mathematical Expression (Priority: P1)

A reader studying a textbook opens the calculator from the Tools menu, types an expression such as `1/3 + 1/6`, and taps Evaluate to see the result without leaving their book.

**Why this priority**: This is the core value of the plugin and the foundation (shared expression engine) for simplification and graphing.

**Independent Test**: Open the calculator, enter expressions, tap Evaluate, and compare the displayed result against known values.

**Acceptance Scenarios**:

1. **Given** the calculator is open, **When** the user evaluates `2 + 3*4`, **Then** the result `14` is shown.
2. **Given** the calculator is open, **When** the user evaluates `1/3 + 1/6`, **Then** the exact result `1/2` is shown.
3. **Given** the calculator is open, **When** the user evaluates `sqrt(2)`, **Then** an exact form and/or a decimal approximation (≈ 1.41421356) is shown.
4. **Given** an expression containing a variable, **When** the user provides a value for that variable, **Then** the expression is evaluated with that value.
5. **Given** the user enters `2 +* 3`, **When** they tap Evaluate, **Then** a clear message identifies the syntax problem and its position, and nothing crashes.
6. **Given** the user enters `1/0`, **When** they tap Evaluate, **Then** a "division by zero" message is shown instead of a result.
7. **Given** the user enters `-2^2`, **When** evaluated, **Then** the result is `-4` (exponentiation binds tighter than unary minus).

---

### User Story 2 - Simplify and Expand Expressions (Priority: P1)

A student enters an algebraic expression such as `2*x + 3*x` and taps Simplify to get the equivalent, simpler form `5*x`; expanding `(x+1)^2` gives `x^2+2*x+1`.

**Why this priority**: Symbolic manipulation is the differentiator over a basic calculator and is required for MVP acceptance.

**Independent Test**: Enter reference expressions, tap Simplify, and compare against independently prepared expected results.

**Acceptance Scenarios**:

1. **Given** the user enters `2*x + 3*x`, **When** they tap Simplify, **Then** `5*x` is shown.
2. **Given** the user enters `x*1`, **When** they tap Simplify, **Then** `x` is shown.
3. **Given** the user enters `expand((x+1)^2)`, **When** it is evaluated, **Then** `x^2+2*x+1` is shown.
4. **Given** an expression such as `x/x`, **When** simplified, **Then** the result does not silently drop the restriction `x ≠ 0` (it either stays unchanged or is clearly marked as valid only for `x ≠ 0`).
5. **Given** the same expression is simplified twice, **When** results are compared, **Then** the output is identical.
6. **Given** an expression the system cannot simplify, **When** the user taps Simplify, **Then** the expression is returned in its normalized form or a clear "unsupported" message is shown.

---

### User Story 3 - Plot Functions on a Graph (Priority: P1)

A reader opens the Graph view from the calculator, enters `sin(x)` and `x^2` as two functions, and sees both curves on a coordinate system with axes, grid, and tick labels, legible on a grayscale E Ink screen.

**Why this priority**: Visualization is the second pillar of the product and is required for MVP acceptance.

**Independent Test**: Add functions in the Graph view, set the viewport, and inspect the rendered plot for correct shape, labeled axes, and distinguishable curves.

**Acceptance Scenarios**:

1. **Given** the Graph view is open, **When** the user adds `x^2`, **Then** a parabola is drawn with visible X and Y axes, grid lines, and tick labels.
2. **Given** two functions are listed, **When** the graph is shown, **Then** both are drawn on the same coordinate system and can be told apart in monochrome (e.g., by line style or width).
3. **Given** the user sets Xmin, Xmax, Ymin, Ymax, **When** they refresh, **Then** the plot reflects the new ranges.
4. **Given** the user resets the viewport, **When** confirmed, **Then** default ranges are restored.
5. **Given** a function is hidden, **When** the graph is shown, **Then** that curve is not drawn but remains in the list.
6. **Given** a function that cannot be evaluated (e.g., `sin(`), **When** added, **Then** an error is shown for that function and other functions still plot.
7. **Given** `1/x`, `tan(x)`, or `1/(x-1)` is plotted, **When** the graph is shown, **Then** no line connects the branches across the vertical asymptote.
8. **Given** `log(x)` or `sqrt(x)` is plotted over a range including negative x, **When** the graph is shown, **Then** nothing is drawn where the function is undefined and no error is raised for the plot as a whole.
9. **Given** the expression and viewport are unchanged, **When** the user returns to the graph, **Then** it appears without a visible full redraw delay.
10. **Given** the Y range is left on automatic, **When** a suitable continuous function is plotted, **Then** the Y range is chosen so the curve is visible.

---

### User Story 4 - Use the Plugin Inside KOReader Without Disrupting Reading (Priority: P1)

A reader opens the calculator from Tools while reading, works with it using touch or device buttons (no physical keyboard), and closes it to find their book exactly where they left it.

**Why this priority**: The plugin must be a safe, well-behaved part of KOReader; this underpins every other story.

**Independent Test**: Open a book, launch the plugin from Tools, use both views, close it, and confirm the reading position, annotations, and book are unchanged.

**Acceptance Scenarios**:

1. **Given** KOReader is running, **When** the user opens the Tools menu, **Then** a calculator entry is present.
2. **Given** the Calculator view, **When** the user taps the Graph action, **Then** the Graph view opens, and a Return action brings them back with their expression preserved.
3. **Given** the user leaves and reopens the plugin in the same reading session, **When** the Calculator view appears, **Then** the previous expression is still present.
4. **Given** the user closes the plugin, **When** the book is shown, **Then** the reading position is unchanged and no book content or annotations were modified.
5. **Given** the device is rotated, **When** a view is open, **Then** the layout adapts to the new screen size and remains usable.
6. **Given** a device with no hardware keyboard, **When** the user enters expressions, **Then** all input is possible via on-screen input and touch or applicable physical buttons.

---

### Edge Cases

- Division by zero in evaluation (`1/0`, `x/0`) yields a clear error, not infinity or a crash.
- Domain errors (`sqrt(-1)`, `log(0)`, `log(-5)`, `ln(0)`) yield a clear domain message in the calculator; in plots they are treated as undefined points.
- Overflow (e.g., `10^1000`, `9^9^9`) is reported as "result too large" rather than hanging or returning garbage.
- Very long or deeply nested expressions are rejected with a clear "too complex" message once resource limits are exceeded.
- Unsupported syntax or functions (e.g., `foo(x)`, `3 +`, unbalanced parentheses, empty input) produce a specific message.
- Ambiguous syntax: implicit multiplication (`2x`, `2(x+1)`) is either accepted with one documented interpretation or rejected with a hint; `2^3^2` is right-associative (= 2^9); `-x^2` means `-(x^2)`.
- Mathematical input can never execute as program code (e.g., input like `os.execute("...")` is just an invalid expression).
- Plotting a function that is undefined everywhere in the viewport shows an empty plot with a notice, not an error crash.
- Rapidly oscillating functions (e.g., `sin(1/x)` near 0) are bounded by sampling limits and do not freeze the UI.
- Xmin ≥ Xmax or Ymin ≥ Ymax, or non-numeric range values, are rejected with a clear message and the previous valid viewport is kept.
- Many functions (above a documented maximum) are limited with a clear message.
- Plugin closed while a plot is being computed: computation is abandoned and the reading session is unaffected.

## Requirements *(mandatory)*

### Functional Requirements

**Expression handling**

- **FR-001**: The system MUST accept expressions containing integers, rational numbers, decimal numbers, variables, the operators `+ - * / ^`, unary minus, and parentheses.
- **FR-002**: The system MUST support the functions `sin`, `cos`, `tan`, `exp`, `log`, `ln`, `sqrt`, and `abs`, including nested use.
- **FR-003**: The system MUST apply standard operator precedence and associativity, including unary minus and right-associative exponentiation.
- **FR-004**: The system MUST evaluate expressions exactly (as rationals / symbolic forms) where mathematically possible, and approximately (floating point) on request or when exact form is not possible.
- **FR-005**: The system MUST evaluate expressions with user-supplied variable values.
- **FR-006**: The system MUST report parsing errors with a human-readable message and the position of the problem.
- **FR-007**: The system MUST report mathematical errors (division by zero, domain violations, overflow) with a human-readable message.
- **FR-008**: The system MUST NOT execute mathematical input as program code under any circumstance.
- **FR-009**: The system MUST define and document behavior for ambiguous syntax, division by zero, overflow, unsupported expressions, and domain restrictions, and apply it consistently.
- **FR-010**: The system MUST enforce explicit limits on expression size, nesting depth, and computation effort, and report clearly when a limit is exceeded.
- **FR-011**: Parsing and evaluation MUST be deterministic: the same input always yields the same output.

**Symbolic algebra**

- **FR-012**: The system MUST simplify expressions by evaluating constant arithmetic, combining like terms, and removing neutral elements (e.g., `x*1`, `x+0`, `x^1`).
- **FR-013**: The system MUST expand products and integer powers of polynomials.
- **FR-014**: The system MUST apply basic exponent rules only where valid under stated domain assumptions.
- **FR-015**: Every transformation MUST preserve mathematical equivalence; transformations that would alter an expression's domain (e.g., cancelling `x/x`, `sqrt(x^2)` → `x`) MUST NOT be applied silently.
- **FR-016**: Simplified and expanded output MUST be in a deterministic, normalized order.

**Plotting**

- **FR-017**: The system MUST plot real-valued functions `y = f(x)` using the same expression handling as the calculator, including polynomial, rational, trigonometric, exponential, logarithmic, and composite functions.
- **FR-018**: The system MUST plot multiple functions simultaneously on one coordinate system, with curves distinguishable in grayscale.
- **FR-019**: The system MUST draw X and Y axes, configurable grid lines, and tick labels.
- **FR-020**: Users MUST be able to set Xmin, Xmax, Ymin, and Ymax, reset the viewport to defaults, and refresh the plot.
- **FR-021**: The system MUST offer automatic Y-range selection for suitable continuous functions.
- **FR-022**: The system MUST skip undefined, NaN, and infinite values and clip curves to the visible area.
- **FR-023**: The system MUST NOT draw lines connecting separate branches across discontinuities or domain exclusions (e.g., `1/x`, `tan(x)`, `1/(x-1)`), and MUST NOT silently render misleading connections across singularities.
- **FR-024**: The system MUST refine sampling in sharply curved or rapidly changing regions, within explicit sampling and recursion limits.
- **FR-025**: Plot computation MUST be bounded so that it does not freeze KOReader's interface; long computations MUST yield control or be capped.
- **FR-026**: The system MUST reuse a previously computed plot when the functions and viewport have not changed.
- **FR-027**: Users MUST be able to add, edit, remove, and show/hide individual functions, and see an error message for any function that cannot be evaluated while the remaining functions still plot.

**KOReader integration**

- **FR-028**: The plugin MUST appear in KOReader's Tools menu.
- **FR-029**: The Calculator view MUST provide expression input, Evaluate, Simplify, a result display, and navigation to the Graph view, and MUST keep the current expression for the duration of the reading session.
- **FR-030**: The Graph view MUST provide the function list, add/edit/remove actions, the graph canvas with axes and grid, viewport controls, and a return action to the Calculator view.
- **FR-031**: Both views MUST use KOReader's native look and widgets, adapt to screen size and orientation, support touch and applicable physical buttons, and be fully usable without a hardware keyboard.
- **FR-032**: Both views MUST render legibly on grayscale E Ink and avoid unnecessary full-screen refreshes.
- **FR-033**: Closing the plugin MUST return the user to their previous reading position and MUST NOT modify book content, annotations, or reading progress.
- **FR-034**: Plugin settings that persist (e.g., last viewport, grid preference) MUST be stored using KOReader's standard settings storage and MUST NOT corrupt other settings.
- **FR-035**: Invalid input in any view MUST never crash KOReader.

**Architecture and quality constraints**

- **FR-036**: All computation, parsing, symbolic manipulation, and plotting MUST be implemented in native Lua, working fully offline, with no external CAS, scripting runtime, browser, cloud service, or external plotting program.
- **FR-037**: The mathematical engine and the plotting engine MUST be independent of KOReader's UI classes so they can be tested outside the device.
- **FR-038**: The mathematical engine and plotting engine MUST have an automated test suite covering parsing and precedence, exact rational arithmetic, numeric evaluation, simplification, expansion, function evaluation, coordinate transformation, clipping, discontinuity and undefined-region handling, invalid expressions, and computation limits, with results compared to independently prepared reference cases.
- **FR-039**: Plot behavior MUST be tested for `y=x`, `y=x^2`, `y=sin(x)`, `y=1/x`, `y=tan(x)`, `y=log(x)`, `y=sqrt(x)`, and `y=1/(x-1)`.

### Key Entities

- **Expression**: A mathematical formula entered by the user, parsed into a structured tree; has an exact and/or approximate value, and may contain variables.
- **Variable Assignment**: A mapping from variable names to values used for evaluation.
- **Result**: The outcome of evaluating or simplifying an expression: an exact form, an approximate value, a transformed expression, or an error with a message.
- **Function Entry**: A user-defined `y = f(x)` in the graph list, with its expression, visibility, line style, and error state.
- **Viewport**: The visible coordinate window (Xmin, Xmax, Ymin, Ymax) plus grid and auto-scaling settings.
- **Curve**: The set of drawable line segments produced from a Function Entry within a Viewport, split at discontinuities and undefined regions.
- **Session State**: The current expression, function list, and viewport retained while KOReader is running.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can open the calculator from the Tools menu and obtain the result of a basic expression in under 30 seconds from tapping the menu entry.
- **SC-002**: 100% of the reference expression set (arithmetic, rational, function, simplify, and expand cases) produces the independently verified expected result.
- **SC-003**: 100% of the reference invalid-input set (syntax errors, division by zero, domain errors, overflow, unsupported functions, code-injection attempts) produces a clear message with no crash and no code execution.
- **SC-004**: Evaluating or simplifying a typical textbook expression (up to 100 characters) shows a result in under 1 second on a target e-reader.
- **SC-005**: Plotting up to 4 functions over a default viewport completes in under 3 seconds on a target e-reader, and the interface stays responsive (can be cancelled/closed) during computation.
- **SC-006**: In the eight reference plots (`x`, `x^2`, `sin(x)`, `1/x`, `tan(x)`, `log(x)`, `sqrt(x)`, `1/(x-1)`), 100% show the correct shape and zero connecting lines across asymptotes or undefined regions.
- **SC-007**: On a grayscale E Ink screen, a user can tell two simultaneously plotted curves apart and read axis tick labels in 100% of tested reference plots.
- **SC-008**: After closing the plugin, the reading position, book file, and annotations are identical to their state before opening it in 100% of tested sessions.
- **SC-009**: Returning to an unchanged graph does not trigger recomputation visible to the user (appears in under 1 second).
- **SC-010**: All MVP acceptance items (plugin in Tools menu, evaluate, simplify, plot, two functions, axis ranges, grayscale legibility, discontinuity handling, no crash on invalid input, fully offline, reading session unaffected) are verified on at least one real device or emulator before release.

## Assumptions

- Target users are students and professionals reading scientific material on KOReader; they are comfortable with standard math notation typed on an on-screen keyboard.
- Input uses plain-text notation (`^` for powers, `*` for multiplication, `sqrt(x)` for roots); no graphical equation editor in the MVP.
- Implicit multiplication (`2x`) support is a convenience; if not accepted, a clear hint is shown. Explicit `*` is always supported.
- `log` means the natural logarithm unless the documented convention states otherwise; `ln` is always natural. The convention is documented in the README. [Default chosen; can be revisited in clarification.]
- Trigonometric functions use radians.
- Exact results are shown for rational arithmetic; irrational results (e.g., `sqrt(2)`) are shown symbolically and/or as a decimal approximation.
- Only real-valued results are supported in the MVP; complex numbers are treated as domain errors.
- Variable names are single or multi-letter identifiers; `x` is the plot variable.
- Zoom and pan are done by editing range values in the MVP; dedicated buttons come later (P2).
- Settings (viewport, grid) may persist across restarts; the expression and function list are guaranteed only for the current session.
- Target devices are KOReader-supported e-readers (E Ink, touch, limited CPU and memory) and desktop emulator for development; the minimum supported KOReader version will be declared in the implementation plan.
- The project constitution (KOReader-native, offline, simple, data-safe, tested) governs all design and implementation decisions.
