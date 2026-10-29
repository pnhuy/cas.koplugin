# Contract: Notebook Cell Language

A cell's source is split into lines; blank lines and lines starting with `#` are ignored. Each remaining line is one
statement, classified in this order. Nothing is ever passed to `load`/`loadstring`/`dofile`.

| Kind | Form | Effect | Cell result |
|------|------|--------|-------------|
| funcdef | `name(var) = expr` | stores the function | `name(var) = <printed expr>` |
| assign | `name = expr` | evaluates `expr` with the environment, stores the value | `name = <value>` |
| plot | `plot(f1, f2, ..., x=a..b)` | builds a graph; `x=a..b` optional (default viewport) | graph |
| expr | anything else | `calccas.evaluate` (or `simplify(...)`/`expand(...)` wrappers) | value |

The last statement's result is the cell's output. Errors report the line number and the engine's column.

## Rules

- `name`: `[A-Za-z][A-Za-z0-9_]*` (the lexer does not accept a leading underscore), <= 32 characters, not a built-in (`sin cos tan exp log ln sqrt abs pi e plot simplify
  expand`). Violations: error "Name is reserved" / "Invalid name".
- `==`, `<=`, `>=`, `!=`, `<`, `>` typed on the keyboard are text only; the engine has no relations, so a statement using them
  returns the engine's Syntax error. They are on the symbol page because the spec requires every ASCII symbol to be typable;
  they gain meaning when the engine does.
- `plot` arguments are expressions in `x` and previously defined functions (`plot(f)` or `plot(f(x))`); at most 6; range
  `a..b` with numeric `a < b`, else error "Invalid range" (reuses 001 range validation).
- A multi-line cell is atomic for the environment: if any statement fails, assignments made earlier in the same run are
  rolled back and the error is shown for the failing line.
- Limits (reused from 001): 500 characters per statement, 2000 AST nodes, 100 names, 6 plot functions, 4000 samples per
  function.

## Not available (hidden from the keyboard)

`diff solve factor integrate limit asin acos atan plot2 parametric polar`, matrices, equations and solution sets. The engine
rejects them with the existing "Not supported" error if typed.
