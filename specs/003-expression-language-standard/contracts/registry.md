# Contract: Function Registry

`calccas/registry.lua` is the only place a function, command or constant is declared. Entry shape in
[data-model.md](../data-model.md).

## Initial contents (language 1.0)

| Name | Kind | Arity | Status | Args convention | Group | Notes |
|------|------|-------|--------|-----------------|-------|-------|
| `sin` `cos` `tan` `sqrt` | function | 1 | implemented | `expr` | common | |
| `exp` `log` | function | 1 | implemented | `expr` | exp | `ln` is an alias of `log` |
| `sqrt` `abs` | function | 1 | implemented | `expr` | alg | |
| `pi` `e` | constant | 0 | implemented | n/a | constants | printed with `≈` |
| `simplify` `expand` | command | 1 | implemented | `expr` | algebra | |
| `plot` | command | 1..6 plus an optional trailing range | implemented | `expr-range` | plot | at most 6 functions |
| `factor` | command | 1 | reserved | `expr` | algebra | |
| `solve` | command | 1..2 | reserved | `expr` | algebra | equation or relation, optional symbol |
| `diff` | command | 1..2 | reserved | `expr-symbol` | calculus | |
| `integrate` | command | 1..2 | reserved | `expr-symbol` | calculus | |
| `subs` | command | 2.. | reserved | `expr` | algebra | |
| `approx` | command | 1 | reserved | `expr` | algebra | |

## Rules

1. **Single source.** `parser`, `eval`, `statement` (reserved-name check), `calccas.FUNCTION_NAMES`, `calcnb/shortcuts` and
   the keyboard command groups read the registry. None keeps its own name list.
2. **Reserved.** Every registry name is reserved, whatever its status: it cannot be assigned, defined or used as a
   parameter. `ln` is reserved through its alias.
3. **Reserved status.** A `reserved` entry parses like an implemented command (arity and argument convention are checked) and
   evaluates to an `unsupported` error whose message names the command and the language version. It never silently returns the
   argument.
4. **Implementation table.** The Lua function implementing an `implemented` function stays in `eval.lua` (or the engine module),
   keyed by registry name. A registry entry marked `implemented` with no implementation, or an implementation with no entry,
   fails the drift test.
5. **Drift test (SC-008).** `spec/calccas/registry_spec.lua` asserts: every registry name is reserved by the notebook layer; every
   name offered by shortcuts and the keyboard exists in the registry; every `implemented` entry has an implementation; the set
   of reserved names equals the registry names plus aliases; the grammar document lists no command that the registry lacks.
6. **Adding a command** is: one registry entry, one implementation, conformance cases, a reference row. Nothing else needs to
   change.
7. **Argument conventions** (requirement 19): the expression first, then optional symbol or range last; commas separate
   arguments; names are lowercase English words without underscores; a command never mutates the symbol table.
