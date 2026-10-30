# Research: Expression Language Standard

All unknowns from the spec's assumptions are settled here. Facts about current behaviour come from [audit.md](audit.md).

## R1. One tokenizer and parser for the whole cell

- **Decision**: The lexer tokenizes a whole cell (not one line). The parser has a program level that returns a list of
  statements, each with its starting line. `calcnb/statement.lua` calls it and maps nodes to the statement records the
  runner already uses (`kind = "assign" | "funcdef" | "expr" | "plot" | "simplify" | "expand"`).
- **Rationale**: Statement kinds, plot ranges and comments are syntax. Today they live in Lua patterns that disagree with the
  lexer (a `#` is legal to the pattern layer but not to the lexer; `x = lo..hi` bounds use `tonumber`). One grammar means one
  place to document and test.
- **Alternatives**: keep regex classification and only add tests (rejected: cannot express `==`, trailing comments or
  continuation, and the two layers keep diverging); a separate "command parser" module per command (rejected: more code, no gain).

## R2. Tokens added

- **Decision**: `comma`, `eq` (`=`), `eqeq` (`==`), `dotdot` (`..`), `newline`; `#` starts a comment to the end of the line
  and produces no token. Each token carries `pos` (byte offset in the cell, as today) and `line`. A number token is
  `digits [. digits] [(e|E) [+|-] digits]` or `. digits [exponent]`. The exponent is part of the number only when the digits
  follow immediately; `2e` and `1e+` give a syntax error naming the malformed number, `2*e` and `2 * e` lex as number, `*`,
  identifier.
- **Rationale**: Matches the user decision on scientific notation. `1..2` must not lex as `1.` then `.2`: a `.` is part of a
  number only when a digit follows it, so `1..2` is `1`, `..`, `2`.
- **Alternatives**: treat `e` after a number as the constant (the status quo, rejected: silent mis-parse of `1e-3`); accept
  `1.e3` (rejected: ambiguous with `..`).

## R3. Continuation rules

- **Decision**: A newline ends a statement unless (a) it is inside `(`...`)`, or (b) the last token before it is a binary
  operator (`+ - * / ^`), `=`, `==` or `,`. Blank and comment-only lines between continued lines are skipped. No continuation character (`\`) and no leading-operator
  continuation.
- **Rationale**: Trailing operator and open bracket are the two rules every math tool agrees on, and both are decidable by
  the lexer from the previous token. A leading-operator rule makes `a\n-b` two different things depending on intent
  (two statements versus subtraction) and is the classic source of surprise.
- **Alternatives**: backslash continuation (rejected: needs a key that is awkward on the on-screen keyboard); leading
  operator continues (rejected, above); no continuation (rejected: requirement 14).

## R4. Implicit multiplication becomes an error, with a hint

- **Decision**: The parser reports a syntax error at the second factor when two operands are adjacent: number then identifier
  or `(`, `)` then identifier, number or `(`, identifier (non-function) then `(`. The message is built from the two source
  spans: ``missing `*`: write `2*x` ``. The check runs only where the old parser accepted the construct, so
  `2 3` and `x y` keep today's generic error.
- **Rationale**: User decision (2026-10-30). Naming the replacement fixes saved cells in one edit. Never rewriting text keeps
  saved data safe (constitution V).
- **Alternatives**: accept with a deprecation warning (rejected by the user); rewrite saved text on load (rejected: silent
  edit of user data); per-notebook "legacy mode" (rejected: two languages to document and test).

## R5. AST additions

- **Decision**: New nodes `assign{name, value}`, `funcdef{name, params, body}`, `rel{op="==", lhs, rhs}`,
  `call{name, args}` (for registry commands and any call the evaluator must see), `range{var, lo, hi}`. Statement nodes only
  appear at the top of a statement; `rel`, `call` and `range` follow the node-shape rules in `ast.lua` (immutable tables,
  constructors, structural equality). `rel` is never simplified to a boolean; the evaluator evaluates and prints both sides.
- **Rationale**: Requirement 9 and 10. Keeping `fn` for built-in one-argument functions avoids touching `simplify.lua` and
  every existing test; `call` is for registry commands. The parser emits `fn` when the registry marks a name as a
  built-in function and `call` for commands.
- **Alternatives**: one node `call` for everything (rejected: rewrites `simplify.lua`, `eval.lua` and their tests for no user
  benefit).

## R6. Function registry

- **Decision**: `calccas/registry.lua` holds entries `{name, kind = "function"|"command"|"constant", arity = {min, max},
  status = "implemented"|"reserved", args = "expr"|"range-last"|..., group, since}`. See
  [contracts/registry.md](contracts/registry.md). Derived views: `registry.functions()`, `registry.reserved_names()`,
  `registry.commands()`. `parser.FUNCTIONS`, `eval.FUNCTIONS` (the implementation table stays in `eval.lua`, keyed by the
  registry name), `statement.RESERVED`, `calccas.FUNCTION_NAMES` and the shortcut groups are rebuilt from it.
- **Rationale**: Requirements 18 and 19; SC-008. The audit found five lists that must be edited together today.
- **Alternatives**: a comment saying "keep in sync" (status quo, rejected); generating code (rejected: no build step on the
  plugin).

## R7. Reserved but unimplemented commands

- **Decision**: `diff solve factor integrate subs approx` are registry entries with `status = "reserved"`. They are reserved
  names (cannot be assigned or defined), parse as calls with comma arguments, and evaluating one returns error kind
  `unsupported` with the message ```diff` is reserved for a future version; not available in language 1.0``. No new error
  kind is needed; the `errors.lua` entry in the plan stays unchanged unless implementation finds the message cannot be carried by
  `unsupported`.
- **Rationale**: "Do not implement unsupported commands merely to satisfy examples." Reserving now prevents a future command
  from silently breaking a notebook that used the name as a variable. The cost today is that a saved cell with `diff = 3`
  now fails with a clear message (compatibility list row C-3).
- **Alternatives**: reserve only in call position, so `diff = 3` keeps working (rejected: two rules for one name, and
  `diff(x)` then means a variable or a command depending on context); do not reserve (rejected: requirement 18).

## R8. Plot ranges

- **Decision**: The parser recognizes `IDENT = expr .. expr` only as an argument of a registry entry whose `args` contract
  allows a range, and only in the last argument position (today: `plot`). Elsewhere it is a syntax error ``a range such
  as `x=-5..5` is only allowed as the last argument of plot``. The variable stays `x` in version 1.0. Bounds are
  arbitrary constant expressions (so `x=-2*pi..2*pi` works) evaluated to approximate numbers by the plot command; a bound
  that mentions an undefined symbol is a `range` error.
- **Rationale**: Requirement 12 and the audit (the regex only accepted `tonumber` literals). `=` and `..` have no meaning
  inside an ordinary expression, so a range cannot be confused with assignment or relation.
- **Alternatives**: allow any variable name (rejected: plotting is one-variable and a different name would need parameter
  renaming rules not asked for); keep literal-only bounds (rejected: `pi` is the first thing users type).

## R9. Multi-parameter functions

- **Decision**: `funcdef` takes 1 to 4 parameter names. `f(x, y) = x*y`; a call must give exactly that many arguments
  (arity error otherwise). Substitution at parse time stays (it already substitutes by name); parameters are distinct,
  non-reserved names. The limit of 4 keeps expansion within the existing node and depth limits.
- **Rationale**: Requirement 10 makes `f(1, 2)` a legal call, so either it works or it fails with an arity error. Multiple
  parameters are the smallest feature that makes comma arguments meaningful for user functions, and `substitute` is already
  per-name.
- **Alternatives**: one parameter only, arity error for commas (rejected: makes requirement 8 and 10 meet awkwardly); unbounded
  parameters (rejected: needs limit analysis for no demand).

## R10. Exact and approximate results

- **Decision**: Keep the current representation (`num` exact rational, `num` approximate float). Scientific notation is exact
  when numerator and denominator fit the exact range already enforced by `eval.lua` (`overflow` otherwise promotes to
  approximate; beyond double range is `overflow`). Printing keeps exact output first and `≈` for approximate values.
  `approx(...)` stays reserved.
- **Rationale**: Requirements 16 and 17 are already met by `num`; the spec assumption says typed decimals stay exact.
- **Alternatives**: parse `2.5` as approximate (rejected: breaks `0.1+0.2 = 3/10` and saved results).

## R11. Conformance testing

- **Decision**: [contracts/grammar.md](contracts/grammar.md) numbers every production and rule (`G-01 ...`). A single cases
  file lists `{id, source, expect}` where `expect` is either a printed AST dump (`(add 1 (mul 2 x))`) or
  `{error = kind, fragment = "..."}`. `conformance_spec.lua` runs them and also reads the grammar file to assert each
  `G-nn` appears in at least one accepted and, where the rule can be violated, one rejected case. Cases are written first
  and fail until the parser change lands.
- **Rationale**: SC-001 to SC-004 need evidence that does not depend on someone remembering to add a test; data files are
  also the base for the versioned reference's examples.
- **Alternatives**: hand-written `it` blocks per rule (rejected: no coverage check, harder to diff); property/fuzz only
  (rejected: fuzz proves safety, not meaning; the 002 fuzz spec stays and is extended).

## R12. Versioning

- **Decision**: `calccas.LANGUAGE_VERSION = "1.0"`. The reference states the version at the top and has a changelog table. A
  change that makes previously valid input invalid or changes a result bumps the major version; additions bump the minor
  version. The notebook file version stays `1`; cells do not record a language version.
- **Rationale**: Saved cells are plain text and the plugin has one language at a time; recording a version per cell would
  need a migration story nobody asked for.
- **Alternatives**: per-cell version (rejected, above).

## R13. Safety of the new surface

- **Decision**: The fuzz spec gains the new tokens and constructs (`==`, `..`, `#`, commas, huge exponents, deep brackets over
  newlines) and still asserts that no input reaches `load`, `loadstring`, `dofile`, `require` or `os`/`io` (checked by replacing
  those globals with failing stubs for the duration of the run). Scientific notation exponents are capped (|exp| > 400 is
  decided without building the integer power) so `1e999999999` cannot allocate.
- **Rationale**: Constitution V and requirement 18; huge exponents are the one new resource hazard.
- **Alternatives**: none worth recording.
