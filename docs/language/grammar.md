# Grammar: Expression Language 1.0

Notation: EBNF. `|` alternative, `[ ]` optional, `{ }` zero or more, quotes are literal text. Every production and rule has an
ID (`G-nn`). The conformance suite checks that each ID has at least one accepted case and, where a rule can be violated, one
rejected case (conformance suite).

## Lexical rules

```ebnf
G-01  letter      = "A".."Z" | "a".."z" ;
G-01  digit       = "0".."9" ;
G-02  identifier  = letter { letter | digit | "_" } ;        (* at most 32 characters *)
G-03  number      = ( digits [ "." digits ] | "." digits ) [ exponent ] ;
G-03  digits      = digit { digit } ;
G-04  exponent    = ( "e" | "E" ) [ "+" | "-" ] digits ;      (* only directly after the digits, no spaces *)
G-05  operator    = "+" | "-" | "*" | "/" | "^" ;
G-06  punctuation = "(" | ")" | "," | "=" | "==" | ".." ;
G-07  comment     = "#" { any character except newline } ;    (* ends at the line end, produces no token *)
G-08  whitespace  = " " | tab ;                               (* separates tokens, otherwise ignored *)
```

Rules:

- **G-09** `==` is one token; `=` followed by `=` is never two assignments.
- **G-10** `..` is one token; a `.` belongs to a number only when a digit follows it (`1..2` is `1`, `..`, `2`).
- **G-04a** `2e`, `1e+`, `3E-` (exponent with no digits) are syntax errors naming the number; `2*e`, `2 * e` and `e3` are not
  exponents.
- **G-11** Any other character is a syntax error with its position. Input is never passed to a Lua loader.

## Program and statements

```ebnf
G-20  program     = { line_end } [ statement { line_end { line_end } statement } { line_end } ] ;
      (* statements separated by one or more line ends; blank and comment-only lines are skipped *)
G-21  statement   = assignment | funcdef | relation | expression ;
G-22  assignment  = identifier "=" expression ;
G-23  funcdef     = identifier "(" param_list ")" "=" expression ;
G-24  param_list  = identifier { "," identifier } ;           (* 1 to 4 distinct names *)
G-25  relation    = expression "==" expression ;
```

Rules:

- **G-26** A statement starting `identifier "=" ...` is an assignment; `identifier "(" ... ")" "="` with only identifiers
  separated by commas inside the brackets is a function definition. Anything else containing a single `=` is a syntax error.
- **G-27** The target of an assignment or definition is not a reserved name ([registry](reference-1.0.md#12-functions-and-commands)); parameters are distinct
  and not reserved.
- **G-28** `a == b == c` is a syntax error (a relation has exactly two sides, no chaining). A relation is a statement or a
  command argument; it cannot be nested inside arithmetic (`1 + a == b` is `(1 + a) == b`; `a == (b == c)` is rejected).
- **G-29** The right side of `=` may not be a relation (`a = b == c` is an error).

## Line ends and continuation

- **G-30** A line end ends a statement.
- **G-31** A line end inside `(` ... `)` does not end the statement.
- **G-32** A line end after a binary operator (`+ - * / ^`), `=`, `==` or `,` does not end the statement.
- **G-33** Blank lines and comment-only lines between continued lines are skipped. There is no continuation character and a line
  that starts with an operator is a new statement (`-b` after a complete line is its own statement).
- **G-34** A line end after a statement that is incomplete at the end of the cell (open bracket, trailing operator) is a syntax
  error at the end of the cell.

## Expressions

```ebnf
G-40  expression  = sum ;
G-41  sum         = term { ( "+" | "-" ) term } ;
G-42  term        = unary { ( "*" | "/" ) unary } ;
G-43  unary       = ( "+" | "-" ) unary | power ;
G-44  power       = primary [ "^" unary ] ;                    (* right associative; see G-45 *)
G-46  primary     = number | name | call | "(" expression ")" ;
G-47  name        = identifier ;                              (* constant, bound variable or free symbol *)
G-48  call        = identifier "(" [ argument { "," argument } ] ")" ;
G-49  argument    = expression | relation | range ;
G-50  range       = identifier "=" expression ".." expression ;
```

Rules:

- **G-45** `^` is right associative and its right operand is a `unary`, so `2^3^2 = 2^(3^2)`, `2^-1 = 1/2` and
  `-2^2 = -(2^2)`: exponentiation binds tighter than unary minus on its left, and a sign is allowed on its right.
- **G-51** `*` is required between factors. Two adjacent operands (number then identifier or `(`; `)` then identifier, number or
  `(`; non-function identifier then `(`) are a syntax error whose message names the explicit form (`write 2*x`). Examples:
  `2x`, `3(x+1)`, `(a)(b)`, `2pi`, `x(y)` when `x` is not a function.
- **G-52** A call to a name that is neither a registry function or command nor a defined user function is a syntax error
  `unknown function`. A symbol followed directly by `(` is therefore reported as G-51 (missing `*`) when the name is
  not defined as a function and no call could be meant, and as `unknown function` otherwise; the parser picks G-51 when the
  name is a known variable or a single letter, and `unknown function` for longer undefined names.
- **G-53** A call checks arity against the registry or the definition: too few or too many arguments is a syntax error that
  states the expected count.
- **G-54** A `range` is accepted only as the last argument of a call whose registry entry allows it (`plot`). Elsewhere it is a
  syntax error. The range variable is `x` in 1.0.
- **G-55** A `relation` argument is accepted by registry entries that take expressions (for example `simplify(a == b)`); the
  registry entry decides whether the evaluator supports it, the parser only builds the node.
- **G-56** `x = 3` inside a call is a range only if followed by `..`; otherwise it is a syntax error (`=` is not an
  expression operator).

## Evaluation-facing rules (documented in the reference, tested by evaluator specs)

- **G-60** Constants: `pi` and `e`. Both are reserved and print with `≈` when a numeric value is shown.
- **G-61** A symbol with no value stays symbolic (`x + 1` prints `x + 1`).
- **G-62** Number kinds: integers, decimals and scientific notation are exact rationals when within exact range, otherwise
  approximate; results of transcendental functions are approximate; `1e-3` is `1/1000`.
- **G-63** Division by zero, domain errors and overflow use the error kinds in [errors.md](errors.md).
- **G-64** A relation statement prints both sides in canonical form with `==` and is not evaluated to true or false.

## Precedence summary (highest first)

| Level | Operators | Associativity |
|-------|-----------|---------------|
| 1 | `( )`, calls | n/a |
| 2 | `^` | right |
| 3 | unary `+` `-` | right |
| 4 | `*` `/` | left |
| 5 | binary `+` `-` | left |
| 6 | `==` | none (no chaining) |
| 7 | `=` (assignment, definition) | statement level only |
