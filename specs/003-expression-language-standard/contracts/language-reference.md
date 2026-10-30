# Contract: Language Reference (versioned)

The shipped reference is `docs/language/reference-1.0.md`, written during implementation from this outline and the other
contracts. This file fixes what it must contain so the deliverable can be checked (spec SC-001, SC-007).

## Header

- Title, **Language version 1.0**, date, applies to plugin versions from this feature on.
- Changelog table: version, date, change, compatible (yes/no). First row: 1.0, the baseline defined by this feature, with the
  list of changes against the unversioned language (the compatibility list).

## Required sections

1. **Overview**: what the language is for, that it is never run as Lua, and the notebook statement model.
2. **Lexical elements**: identifiers, numbers (including scientific notation), operators, punctuation, comments (G-01..G-11).
3. **Statements**: expression, assignment, function definition, relation, commands (G-20..G-29).
4. **Line ends and continuation** (G-30..G-34) with examples of each rule and the counter-example for each.
5. **Expressions and precedence**: the precedence table, associativity, `-2^2`, `2^3^2`, `2^-1` (G-40..G-45).
6. **Explicit multiplication** (G-51) with the replacement table (`2x` to `2*x`, `3(x+1)` to `3*(x+1)`, `(a)(b)` to `(a)*(b)`,
   `2pi` to `2*pi`).
7. **Calls and arguments**: comma-separated arguments, arity, argument conventions, user functions with 1 to 4 parameters
   (G-48..G-53).
8. **Relations**: `==` builds an equation node and is not evaluated; `=` is not comparison (G-25, G-28, G-64).
9. **Plot ranges**: `plot(f, g, x=-5..5)`, last argument only, variable `x`, bounds are constant expressions (G-50, G-54).
10. **Numbers**: exact and approximate results, decimal and scientific input stay exact, how `≈` marks an approximate value,
    exact range and what happens beyond it (G-62).
11. **Symbols and constants**: free symbols stay symbolic, `pi` and `e`, assignment of values (G-60, G-61).
12. **Functions and commands**: the registry table (generated from `registry.lua` by the docs test), each with arity, domain,
    status (implemented or reserved), and an example.
13. **Reserved names**: the full list and why.
14. **Domains and errors**: domain of each function, the error catalog ([errors.md](errors.md)), what each kind looks like.
15. **Limits**: characters, depth, nodes, names, plot functions, parameters.
16. **Saved notebooks**: the compatibility list (every deliberate incompatibility with replacement), the rule that saved text is
    never rewritten.
17. **Examples**: a runnable list, each example is also a conformance case (the reference examples and `conformance_cases.lua`
    share ids).

## Separate document: future features

`docs/language/future.md` lists, without promising a date: `diff`, `solve`, `factor`, `integrate`, `subs`, `approx`
(reserved today), comparison operators `<` `>` `<=` `>=` `!=`, multi-variable ranges, implicit multiplication (explicitly not
planned), a continuation character, per-cell language versions. The reference links to it and never describes these as
available.

## Compatibility list (initial)

| ID | Old input | Result in 1.0 | Replacement |
|----|-----------|---------------|-------------|
| C-1 | `2x`, `3(x+1)`, `(a)(b)`, `2pi`, `3sin(x)` | syntax error, missing `*` | write the `*` |
| C-2 | `1e3`, `1e-3` | `1000`, `1/1000` (was `e3` and `e-3 ≈ -0.2817`) | none, now correct |
| C-3 | assigning or defining `diff`, `solve`, `factor`, `integrate`, `subs`, `approx` | error: name is reserved | rename the variable |
| C-4 | `x == 1`, `f(1, 2)`, `1 + 2 # note` | were syntax errors, now accepted | none |
| C-5 | `plot(f, x = 2*pi..3)` style bounds | were range errors, now accepted | none |

Everything else in the 001 and 002 reference cases keeps its result. `compat_spec.lua` enforces this list: each row has a test,
and the existing corpus is run to prove nothing else changed.
