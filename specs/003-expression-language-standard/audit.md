# Audit: Expression Language as Implemented (before any change)

**Audited**: 2026-10-30, branch `003-expression-language-standard`, commit `fe52281`.
**Method**: read `calccas/{lexer,parser,eval,ast,printer,limits}.lua`, `calccas.lua`, `calcnb/{statement,runner,env}.lua`, the
001 `cas-api.md` and 002 `notebook-language.md` contracts, and ran the probes in the table below against `calccas.evaluate`.
Nothing was changed.

## 1. How the language is built today

| Stage | Where | What it does |
|-------|-------|--------------|
| Statement splitting | `calcnb/statement.lua` | Splits a cell on newlines. Skips blank lines and lines whose first character is `#`. Classifies each line with Lua patterns: `plot(...)`, `name(param) = expr`, `name = expr`, otherwise an expression. |
| Lexer | `calccas/lexer.lua` | Numbers, identifiers (`[A-Za-z][A-Za-z0-9_]*`), `+ - * / ^`, `(`, `)`. Anything else is a syntax error with a position. |
| Parser | `calccas/parser.lua` | Recursive descent to the AST. Handles implicit multiplication, the 8 built-in functions (one argument each) and user-function calls by substitution at parse time. |
| AST | `calccas/ast.lua` | Node types `num` (exact rational, or approximate float), `const`, `var`, `add`, `mul`, `pow`, `fn`. No relation, assignment, call-with-several-arguments or range nodes. |
| Evaluator | `calccas/eval.lua` | Exact reduction (rationals, integer roots), then a float stage. Raises typed errors (`domain`, `div_by_zero`, `undefined`, `overflow`, ...). |
| Symbol table | `calcnb/env.lua` | Variables and one-parameter user functions, at most 100 names, snapshot and restore for atomic cells. |
| Function registry | `parser.lua` (`FUNCTIONS`), `eval.lua` (`FUNCTIONS`), `calcnb/statement.lua` (`RESERVED`) | Three separate tables that must be kept in step by hand. |
| Symbolic engine | `calccas/simplify.lua`, `calccas.lua` | `simplify(...)` and `expand(...)`, recognised by text matching on the whole statement (`split_wrapper`), not by the parser. |
| Plot parsing | `calcnb/statement.lua` (`plot_statement`) | Text matching: the last comma-separated argument of the form `x = lo..hi` is the range; bounds must be plain decimal numbers that `tonumber` accepts. |
| Pretty printer | `calccas/printer.lua` | Deterministic infix output, `≈` for the approximate value next to a non-numeric exact result. |

User input is never passed to `load`, `loadstring` or `dofile` anywhere in this path.

## 2. What is implemented

- Infix `+ - * / ^`, unary `+` and `-`, parentheses. `^` is right-associative and binds tighter than unary minus
  (`-2^2 = -4`, `2^3^2 = 512`, `2^-1 = 1/2`).
- Numbers: `3`, `2.5`, `.5`. **Decimals are exact rationals** (`0.5` is `1/2`, `0.1+0.2` is `3/10`). A value is approximate only
  when it comes from a transcendental function (`sin(1) ≈ 0.841470985`) or a number too large for exact arithmetic.
- Constants `pi` and `e` (printed with `≈`). Any other identifier is a symbolic variable; undefined symbols stay symbolic.
- Functions `sin cos tan exp log ln sqrt abs`, exactly one argument. `ln` is stored as `log`.
- Statements: assignment `a = 2`, one-parameter function definition `f(x) = x^2 + a`, expression, `plot(...)`, `simplify(...)`,
  `expand(...)`. A multi-line cell is atomic for the environment.
- Comments: a line whose first non-blank character is `#`.
- Limits: 500 characters per statement, depth 50, 2000 nodes, 100 names, names up to 32 characters, 6 plot functions.
- Reserved names: `sin cos tan exp log ln sqrt abs pi e plot simplify expand`.

## 3. Probe results

| Input | Result today |
|-------|--------------|
| `0.5` | `1/2` (exact) |
| `0.1+0.2` | `3/10` (exact) |
| `sin(1)` | `sin(1) ≈ 0.841470985` |
| `2x`, `3(x)`, `(x)(y)` | `2*x`, `3*x`, `x*y` (implicit multiplication accepted) |
| `1/2x` | `(1/2)*x` |
| `2 3`, `x y` | syntax error (implicit multiplication is only after a number or `)`) |
| `1e3` | `e3`, that is `1` times a variable named `e3`; there is no exponent notation |
| `x == 1` | syntax error: `unexpected character '='` |
| `1 + 2 # c` | syntax error: `unexpected character '#'` (comments only at the start of a line) |
| `f(1, 2)`, `diff(x^2, x)` | syntax error: `unexpected character ','` (no commas in the lexer) |
| `diff(x)` | syntax error: unknown function `diff` |

## 4. Gaps against the requested language

| # | Requested | Today | Class |
|---|-----------|-------|-------|
| 5 | Explicit multiplication only | Implicit multiplication accepted after a number or `)`; documented in the README and relied on by `1/2x`-style input | **Incompatible change** |
| 6, 17 | Approximate decimals distinguished from exact | Typed decimals are exact rationals; approximation only arises from functions and overflow | Needs a decision (kept exact in the spec's assumptions) |
| 9 | `==` as a relation node | No relation node type; `=` and `==` handled by text matching or rejected | New |
| 10 | Comma-separated call arguments | Lexer rejects `,`; only `plot` splits arguments, by text | New |
| 11 | `simplify expand factor solve diff integrate subs approx plot` | Only `simplify`, `expand`, `plot` exist; the others are unknown functions | Partly new; the rest are future |
| 12 | `x=-5..5` only in range-argument contexts | Matches today, but by regex on the whole statement, only variable `x`, only numeric literal bounds (no `2*pi`) | Same behaviour, different mechanism |
| 13 | `#` comments | Line-leading only; trailing comments are a syntax error | Extension |
| 14 | Continuation rules | None: every line is a statement | New |
| 8 | `f(x) = x^2` | One identifier parameter, by regex; defined with the reserved-name rule | Compatible; multi-parameter is new |
| 18 | Domains, errors, reserved names, constants | Behaviour exists in code and 001/002 contracts but in several places; reserved list lacks the new command names | Consolidate |
| 19 | Consistent names and argument conventions | Three function tables, text-matched wrappers | Consolidate |
| 20 | Saved-notebook compatibility | Saved sources are plain text; any change to what parses can change what old cells do | Constraint |

## 5. Compatibility hazards to settle before changing behaviour

1. Decision (2026-10-30): reject implicit multiplication and add scientific notation (`1e3`, `1e-3`). Implicit multiplication (`2x`, `3(x+1)`, `(a)(b)`) is valid today. Making multiplication explicit turns every such saved cell
   into a syntax error on the next run.
2. `1e3`, `1e-3`, `2pi`, `3sin(x)` currently parse (as `1*e3`, `1*e-3` = `e-3 ≈ -0.2817`, `2*pi`, `3*sin(x)`); the first two are silent mis-parses that scientific notation fixes.
3. Any new reserved command name (`diff`, `solve`, `factor`, `integrate`, `subs`, `approx`) makes an existing assignment or
   function definition with that name fail; saved notebooks may already use them as variable names.
4. Plot ranges are matched before the generic parser; moving them into the parser must keep `plot(f, x=-5..5)` and `plot(f)`
   behaving identically.

## After (2026-10-30)

How each gap in section 4 was resolved. `busted` 848 passes, `luacheck` clean.

| # | Resolution |
|---|------------|
| 5 | Implicit multiplication is rejected with ``missing `*`: write `2*x` ``; saved text is not rewritten (compat row C-1). README updated. |
| 6, 17 | Decimals and scientific notation stay exact rationals; approximate values come from functions, constants and values beyond the exact range, and carry `≈` (reference section 10). |
| 9 | `rel` node; `==` is parsed as a relation, printed with both sides canonical, never evaluated to a boolean. `simplify`, `expand` and `compile` of a relation give `unsupported`. |
| 10 | The lexer has `,`; the parser builds `call` nodes with arity checked from the registry or the definition. |
| 11 | `calccas/registry.lua` is the single list. `simplify`, `expand`, `plot` are implemented; `factor solve subs approx diff integrate` are reserved: they parse and evaluate to `unsupported`. |
| 12 | `range` node, accepted only as the last argument of `plot`, variable `x`, constant-expression bounds (C-5). |
| 13 | `#` starts a comment anywhere on a line. |
| 14 | Continuation inside brackets and after a trailing operator, `=`, `==` or `,`; no continuation character. |
| 8 | Function definitions take 1 to 4 distinct parameters; functions are inlined at parse time with simultaneous substitution. |
| 18 | `docs/language/reference-1.0.md`, `grammar.md`, `errors.md`, `future.md`; checked by `spec/docs_spec.lua`. |
| 19 | One registry read by the parser, evaluator, notebook layer and keyboard (`registry_spec.lua` guards drift). |
| 20 | `spec/calcnb/compat_spec.lua` runs the 210-entry corpus: only the listed C-rows change; a 100-cell notebook's sources are byte-identical after run, save and reload. |

Deviations from the plan:

- `statement.lua` became a thin adapter over `calccas.parse_program`; the grammar lives in the parser only.
- Assigning or defining a reserved name reports the existing `reserved` error kind rather than a new `name` kind; `name` exists in
  `errors.lua` but the notebook layer reports `reserved`.
- `2e` is reported as a malformed number rather than as a missing `*` (the lexer treats an exponent marker with no digits as a
  number error).
- Plot with more than 6 functions is `too_complex`; the plot arity message reads "plot takes at most 6 functions".
- Parse time for a worst-case cell is about 1.5 times the old time (quickstart.md); not measured on a device.
- The emulator check (T038) was not performed.
