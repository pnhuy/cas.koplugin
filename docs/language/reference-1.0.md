# Expression Language Reference

**Language version 1.0** · applies to the notebook and the calculator from plugin feature 003 on.

| Version | Date | Change | Compatible |
|---------|------|--------|------------|
| 1.0 | 2026-10-30 | Baseline. Defines the grammar, the function registry, `#` comments, line continuation, `==` relations, scientific notation and reserved names. Implicit multiplication is no longer accepted (see [Saved notebooks](#16-saved-notebooks)). | no, with the changes C-1 to C-5 |

The formal grammar is [grammar.md](grammar.md), the error catalog is [errors.md](errors.md), and features that do not exist yet
are in [future.md](future.md). Every example below that carries a case id is also a conformance test
(`spec/calccas/conformance_cases.lua`).

## 1. Overview

The language is a small mathematics notation for the notebook: infix expressions, variables, functions you define, equations,
and a few commands. A cell holds one or more statements. Every statement is tokenised and parsed by the plugin's own lexer and
parser into a tree and evaluated by the plugin's own evaluator. **Input is never run as Lua**: there is no `load`, no
`loadstring`, and no access to Lua names. Text such as `os.execute("x")` is a syntax error.

Statements run top to bottom. A variable or function defined by a statement is visible to the statements after it, and to
later cells. If a statement fails, the statements before it keep their effect, the failing line is reported, and nothing after
it runs.

## 2. Lexical elements

- **Identifiers**: a letter, then letters, digits or `_`; at most 32 characters when you define them (`x`, `x_1`, `rate2`).
  Case matters. <!-- case: G-02-a -->
- **Numbers**: digits with an optional fraction, or a leading `.`: `12`, `3.25`, `.5`. An optional exponent follows
  directly, with no spaces: `1e3`, `2.5E+2`, `1e-3`. <!-- case: G-03-c --> <!-- case: G-03-d --> <!-- case: G-03-f -->
- **Operators**: `+ - * / ^`. <!-- case: G-05-a -->
- **Punctuation**: `( ) , = == ..`. `==` and `..` are single tokens. <!-- case: G-09-a -->
- **Comments**: `#` to the end of the line. <!-- case: G-07-a -->
- **Whitespace**: spaces and tabs separate tokens and are otherwise ignored. <!-- case: G-08-a -->
- Any other character (`$`, `;`, `<`, `>`, `.` alone) is a syntax error with its position. <!-- case: G-11-a -->

An exponent needs digits: `2e` and `1e+` are errors, while `2*e` and `2 * e` are the number 2 times the constant `e`.
<!-- case: G-04a-a --> <!-- case: G-04a-c -->

## 3. Statements

| Form | Example | Meaning |
|------|---------|---------|
| Expression | `x^2 + 1` | Evaluate and show the result |
| Assignment | `a = 2 + 3` | Bind a name to a value |
| Function definition | `f(x, y) = x - y` | Define a function of 1 to 4 distinct parameters |
| Relation | `x^2 + 1 == 5` | An equation, shown but not evaluated |
| Command | `plot(sin(x))`, `expand((x+1)^2)` | A registry command ([section 12](#12-functions-and-commands)) |

<!-- case: G-22-a --> <!-- case: G-23-b --> <!-- case: G-25-a -->

`name = expression` is an assignment. `name(p1, p2) = expression` with only names between the brackets is a definition. Any
other use of a single `=` is an error: ``` `=` is only for assignment and definitions; use `==` for an equation```.
<!-- case: G-29-b --> The target and the parameters must not be reserved names ([section 13](#13-reserved-names)).
<!-- case: G-27-a --> Parameters must be distinct. <!-- case: G-24-c -->

A user function is expanded where it is called, so `f(x) = x + 1` followed by `f(2)` is `3`, and `f(y, x)` swaps the
arguments by position. <!-- case: G-48-c --> <!-- case: G-48-d --> The assigned value is evaluated when the assignment runs.

## 4. Line ends and continuation

1. A line end ends a statement. <!-- case: G-30-a -->
2. A line end inside `( )` does not. <!-- case: G-31-a --> <!-- case: G-31-b -->
3. A line end after `+ - * / ^`, `=`, `==` or `,` does not. <!-- case: G-32-a --> <!-- case: G-32-b --> <!-- case: G-32-c -->
4. Blank and comment-only lines are skipped, including between continued lines. <!-- case: G-33-a -->
5. There is no continuation character. A line that **starts** with an operator is a new statement, so `1` then `* 2` on the next
   line is an error rather than `2`. <!-- case: G-32-d -->
6. Input that ends while still open (unclosed bracket, trailing operator) is an error at the end of the cell.
   <!-- case: G-34-a --> <!-- case: G-34-b -->

Error line numbers count the original lines, including continued ones.

## 5. Expressions and precedence

| Level | Operators | Associativity |
|-------|-----------|---------------|
| 1 | `( )`, calls | |
| 2 | `^` | right |
| 3 | unary `+` `-` | right |
| 4 | `*` `/` | left |
| 5 | binary `+` `-` | left |
| 6 | `==` | none |
| 7 | `=` | statement level only |

- `2^3^2` is `2^(3^2)` = 512. <!-- case: G-45-a -->
- `-2^2` is `-(2^2)` = -4: exponentiation binds tighter than unary minus. <!-- case: G-44-a -->
- `2^-1` is 1/2: a sign is allowed on the right of `^`. <!-- case: G-45-c -->
- `1 + 2 * 3` is 7. <!-- case: G-40-a -->

## 6. Explicit multiplication

Multiplication is always written `*`. Two operands side by side are a syntax error that shows the fix:

| You wrote | Write |
|-----------|-------|
| `2x` | `2*x` <!-- case: G-51-a --> |
| `3(x+1)` | `3*(x+1)` <!-- case: G-51-b --> |
| `(a)(b)` | `(a)*(b)` <!-- case: G-51-c --> |
| `2pi` | `2*pi` <!-- case: G-51-d --> |
| `(x+1)3` | `(x+1)*3` <!-- case: G-51-e --> |

`2 3` is reported as an unexpected number. <!-- case: G-51-f --> Implicit multiplication is not planned
([future.md](future.md)).

## 7. Calls and arguments

Arguments are separated by commas: `sin(x)`, `plot(sin(x), cos(x), x=-5..5)`. The argument count is checked: `sin()` and
`sin(1, 2)` are errors that state how many arguments are expected. <!-- case: G-53-a --> <!-- case: G-53-b -->
A name that is not a function, command or user function cannot be called: `foo(2)` is ``unknown function `foo` ``.
<!-- case: G-52-a --> A lone symbol followed by `(`, such as `x(2)`, is reported as a missing `*`. A function name without
brackets (`sin`) is an error. <!-- case: G-52-b -->

Conventions: the expression comes first, then an optional symbol or range; names are lowercase English words; a command never
changes your variables.

## 8. Relations

`==` builds an equation from two expressions. It is **not** evaluated to true or false: `x + 1 == 2*3` shows
`x+1 == 6`, each side in canonical form. <!-- case: G-64-b --> `=` is never a comparison. A relation has exactly two sides
(`a == b == c` is an error), cannot be nested in arithmetic and cannot be the right side of `=`.
<!-- case: G-28-a --> <!-- case: G-29-a --> Commands accept a relation as an argument (`solve(x == 1, x)` parses) and the
command decides whether it is supported. <!-- case: G-55-b -->

## 9. Plot ranges

```
plot(sin(x), cos(x), x=-2*pi..2*pi)
```

A range `x=lo..hi` is accepted only as the **last** argument of `plot`; its variable must be `x`; `lo` and `hi` are constant
expressions (numbers, `pi`, arithmetic on them) with `lo < hi`. Anywhere else a range is a syntax error.
<!-- case: G-50-a --> <!-- case: G-54-a --> <!-- case: G-54-b --> <!-- case: G-54-d --> `plot` takes 1 to 6 functions;
more is a `too_complex` error. <!-- case: G-53-c -->

## 10. Numbers

- Integers, decimals and scientific notation are read as **exact rationals**: `0.1 + 0.2` is `3/10`, `1e-3` is `1/1000`,
  `1e3` is `1000`. <!-- case: G-62-a --> <!-- case: G-62-b -->
- Arithmetic on exact values stays exact. Results of `sin`, `cos`, `tan`, `exp`, `log` and the constants are approximate and
  shown with `≈`, for example `pi ≈ 3.14159265`. <!-- case: G-60-a -->
- A value too large for the exact range becomes approximate (`1e30` is shown as `1e+30`). Beyond the range of a double
  (`1e400`, `10^400`) the result is an `overflow` error. <!-- case: G-62-c -->
- The two sides of a relation are exact or approximate independently.

## 11. Symbols and constants

A name with no value stays symbolic: `x + 1` shows `x+1`. <!-- case: G-61-a --> After `a = 2`, `a` evaluates to 2. The
constants are `pi` and `e`; they are reserved, and `2*pi` shows `2*pi ≈ 6.28318531`. <!-- case: G-60-b -->

## 12. Functions and commands

Generated from the function registry (`calccas/registry.lua`) and checked against it by `spec/docs_spec.lua`.

<!-- registry:begin -->
| Name | Kind | Arguments | Status | Example |
|------|------|-----------|--------|---------|
| `sin` | function | 1 | implemented | `sin(pi/2)` |
| `cos` | function | 1 | implemented | `cos(0)` |
| `tan` | function | 1 | implemented | `tan(0)` |
| `sqrt` | function | 1 | implemented | `sqrt(9/4)` |
| `plot` | command | 1 to 6 | implemented | `plot(sin(x), x=-5..5)` |
| `abs` | function | 1 | implemented | `abs(-3)` |
| `exp` | function | 1 | implemented | `exp(0)` |
| `log` | function | 1 | implemented | `log(1)` |
| `ln` | function | 1 | implemented | `ln(1)` |
| `simplify` | command | 1 | implemented | `simplify(2*x + 3*x)` |
| `expand` | command | 1 | implemented | `expand((x+1)^2)` |
| `pi` | constant | 0 | implemented | `pi` |
| `e` | constant | 0 | implemented | `e` |
| `factor` | command | 1 | reserved | |
| `solve` | command | 1 to 2 | reserved | |
| `subs` | command | 2 to 8 | reserved | |
| `approx` | command | 1 | reserved | |
| `diff` | command | 1 to 2 | reserved | |
| `integrate` | command | 1 to 2 | reserved | |
<!-- registry:end -->

`ln` is another name for `log` (natural logarithm). `simplify` and `expand` take one expression. A **reserved** command parses
and checks its argument count, then reports ``` `diff` is reserved for a future version; not available in language 1.0```
instead of a value. <!-- case: G-63-c --> They are listed in [future.md](future.md).

## 13. Reserved names

Every name in the table above is reserved, whatever its status, so it cannot be assigned, defined or used as a parameter:
`sin cos tan sqrt plot abs exp log ln simplify expand pi e factor solve subs approx diff integrate`. Reserving the future
commands now means a notebook written today cannot clash with them later. <!-- case: G-27-b --> <!-- case: G-27-c -->
Names that merely contain a reserved word (`myfunc`) are free. <!-- case: G-27-e -->

## 14. Domains and errors

| Input | Error kind |
|-------|-----------|
| `1/0`, `0/0`, `0^-1` | `div_by_zero` <!-- case: G-63-a --> |
| `sqrt(-1)` | `domain` <!-- case: G-63-b --> |
| `log(0)`, `log(-1)` | `domain` |
| `tan(pi/2)` | `domain` (tan has a pole) |
| `(-8)^(1/3)` | `domain` (fractional power of a negative number) |
| `0^0` | `undefined` |
| `exp(1000)`, `10^400`, `1e400` | `overflow` |

`sin`, `cos`, `exp`, `abs` are defined for every number; `sqrt` for values of 0 and above; `log` and `ln` for values above 0.
The full list of error kinds and messages is in [errors.md](errors.md). An error always names the construct and, where one
exists, the fix, and carries the position and the line.

## 15. Limits

| Limit | Value |
|-------|-------|
| Characters per statement | 500 |
| Nesting depth | 50 |
| Expression nodes | 2000 |
| Defined name length | 32 |
| Functions in one `plot` | 6 |
| Parameters of a function definition | 4 |

Exceeding a limit is a `too_complex` error, never a hang.

## 16. Saved notebooks

Saved text is **never rewritten**. A cell saved by an earlier version is loaded as it was written and run with this
language; if it no longer parses it shows an error with its line and keeps its text so you can edit it. Everything else in the
earlier reference cases keeps its result. The deliberate differences:

| ID | Old input | Result in 1.0 | Replacement |
|----|-----------|---------------|-------------|
| C-1 | `2x`, `3(x+1)`, `(a)(b)`, `2pi`, `3sin(x)` | syntax error, missing `*` | write the `*` |
| C-2 | `1e3`, `1e-3` | `1000`, `1/1000` (was `e3` and `e-3 ≈ -0.2817`) | none, now correct |
| C-3 | assigning or defining `diff`, `solve`, `factor`, `integrate`, `subs`, `approx` | error: name is reserved | rename the variable |
| C-4 | `x == 1`, `1 + 2 # note`, a call with several arguments | were syntax errors, now accepted | none |
| C-5 | `plot(f, x = 2*pi..3)` style bounds | were range errors, now accepted | none |

## 17. Examples

Each line is a conformance case.

| Input | Result | Case |
|-------|--------|------|
| `1 + 2 * 3` | `7` | G-40-a |
| `2^3^2` | `512` | G-45-a |
| `0.1 + 0.2` | `3/10` | G-62-a |
| `1e-3` | `1/1000` | G-62-b |
| `x + 1` | `x+1` | G-61-a |
| `x + 1 == 2*3` | `x+1 == 6` | G-64-b |
| `pi` | `pi ≈ 3.14159265` | G-60-a |
| `2x` | error: write `2*x` | G-51-a |
| `1/0` | error: `div_by_zero` | G-63-a |
| `diff(x)` | error: reserved for a future version | G-63-c |
| `a = 1` newline `f(x) = a*x` newline `x == 1` | assignment, definition, relation | G-21-a |
| `plot(sin(x), cos(x), x=-2*pi..2*pi)` | a graph | G-50-a |
