# Error Catalog (language 1.0)

Error shape: `{kind, message, pos, line}`. Messages are English text passed through gettext by the UI; the fragments below are
what tests match. Positions are byte offsets in the cell, lines are 1-based.

| Kind | When | Message fragment (tested) |
|------|------|---------------------------|
| `syntax` | Unknown character | `unexpected character '...'` |
| `syntax` | Missing `*` (implicit multiplication) | ``missing `*`: write `2*x` `` (built from the actual operands) |
| `syntax` | Malformed number | ``malformed number `2e` `` |
| `syntax` | Unbalanced bracket | `missing ')'` / `unexpected ')'` |
| `syntax` | Chained or nested relation | ``a relation `==` has exactly two sides`` |
| `syntax` | Bare `=` inside an expression | ```=` is only for assignment and definitions; use `==` for an equation`` |
| `syntax` | Range outside plot | ``a range such as `x=-5..5` is only allowed as the last argument of plot`` |
| `syntax` | Wrong range variable | ``the range variable must be `x` `` |
| `syntax` | Wrong argument count | `takes 1 argument` / `takes 2 arguments` (stated from the registry or the definition) |
| `syntax` | Unknown function | ``unknown function `foo` `` |
| `syntax` | Incomplete at end of cell | `unexpected end of input` |
| `reserved` | Assigning or defining a registry name | `Name is reserved: <name>` |
| `unsupported` | Evaluating a `reserved` command, or a command inside arithmetic | ``` `diff` is reserved for a future version; not available in language 1.0 ``` |
| `domain` | Outside the function's domain (`sqrt(-1)`, `log(0)`, `tan(pi/2)`, ...) | unchanged from 001 |
| `div_by_zero` | Division by exact zero | unchanged |
| `undefined` | `0^0` | `0^0 is undefined` |
| `overflow` | Result or number beyond the double range | `too large` / `too small` |
| `too_complex` | Limits exceeded, or more than 6 plot functions | `plot takes at most 6 functions` |
| `range` | Plot range bounds not numbers, not finite, or `lo >= hi` | `Invalid range` |
| `unbound_variable` | Numeric evaluation needs a value for a free symbol | unchanged |

Rules:

1. A message names the construct and, where one exists, the replacement. It never shows internal table names.
2. An error in one statement of a cell reports that statement's line; statements before it keep their effect.
3. Position and line refer to the original text, including lines that were continued.
4. Messages for a given input are stable inside a language major version; tests match fragments, not whole strings, so wording
   can be improved without a version bump.
