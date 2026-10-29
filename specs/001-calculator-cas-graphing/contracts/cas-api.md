# Contract: CAS Core (`require("calccas")`)

Pure Lua. No KOReader requires. Every function returns `result, nil` or `nil, err` (Error table, see data-model);
none throws on any string input.

## Grammar (EBNF)

```text
expr     = term { ("+" | "-") term } ;
term     = unary { ("*" | "/" | implicit) unary } ;
unary    = ("-" | "+") unary | power ;
power    = atom [ "^" unary ] ;          (* right-assoc; exponent may carry unary minus *)
atom     = number | ident | func "(" expr ")" | "(" expr ")" ;
number   = digits [ "." digits ] | "." digits ;
func     = "sin" | "cos" | "tan" | "exp" | "log" | "ln" | "sqrt" | "abs" ;
ident    = letter { letter | digit | "_" } ;    (* "pi", "e" are constants *)
implicit = (* number before ident/"(" ; ")" before "(" / ident / number *) ;
```

Whitespace is insignificant. Any other character → `syntax` error with position.

## API

| Function | Returns | Notes |
|----------|---------|-------|
| `parse(text)` | `ast` | Enforces limits (500 chars, depth 50, 2000 nodes) |
| `evaluate(text_or_ast, vars?)` | `Result` | `vars` = `{x = number\|rational-string}`; exact when possible, `value` always set when no free variables |
| `simplify(text_or_ast)` | `Result` | Domain-safe; deterministic |
| `expand(text_or_ast)` | `Result` | Result ≤ 500 terms else `too_complex` |
| `compile(text_or_ast, varname)` | `function(x) → number\|nil` | `nil` = undefined point; used by plotting |
| `tostring(ast)` | string | Deterministic infix, minimal parentheses |

The text form also accepts the wrappers `simplify(...)` and `expand(...)` at the top level so
`expand((x+1)^2)` works from the Calculator input (handled by the facade, not the grammar's function table).

## Reference behaviors (normative test vectors)

| Input | Output |
|-------|--------|
| `2 + 3*4` | `14` |
| `1/3 + 1/6` | `1/2` |
| `sqrt(2)` | `sqrt(2) ≈ 1.41421356` |
| `-2^2` | `-4` |
| `2^3^2` | `512` |
| `0.25 + 1/4` | `1/2` |
| `simplify(2*x + 3*x)` | `5*x` |
| `simplify(x*1)` | `x` |
| `expand((x+1)^2)` | `x^2+2*x+1` |
| `1/0` | error `div_by_zero` |
| `sqrt(-1)`, `log(0)` | error `domain` |
| `10^1000` | error `overflow` |
| `2 +* 3` | error `syntax`, pos 4 |
| `os.execute("x")` | error `syntax` (never executed) |
| `x/x` simplify | unchanged `x/x`, `assumptions = {"x ≠ 0"}` |
