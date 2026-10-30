# Data Model: Expression Language Standard

Pure in-memory structures. Nothing here is persisted; saved notebooks keep plain-text `source` only.

## Token (lexer output)

| Field | Type | Notes |
|-------|------|-------|
| `type` | string | `num`, `ident`, `op` (`+ - * / ^`), `lparen`, `rparen`, `comma`, `eq`, `eqeq`, `dotdot`, `newline`, `eof` |
| `text` | string | Source text of the token (`""` for `eof`). |
| `pos` | integer | 1-based byte offset in the cell (unchanged meaning). |
| `line` | integer | 1-based line in the cell. New. |

Rules: comments produce no token; a `newline` token is emitted only where the continuation rules (grammar G-30..G-33) say a
statement ends; bracket depth is tracked by the lexer so the parser sees no newline inside brackets.

## AST node (`calccas/ast.lua`)

Existing: `num` (exact `n`/`d` or approximate `v`), `const`, `var`, `add`, `mul`, `pow`, `fn`.

| Node | Fields | Appears | Notes |
|------|--------|---------|-------|
| `rel` | `op` (`"=="`), `lhs`, `rhs` | statement level or as a command argument | Never reduced to true/false. |
| `call` | `name`, `args` (list of nodes) | statement level or as an argument | Registry commands (`simplify`, `expand`, `plot`, reserved commands). |
| `range` | `var`, `lo`, `hi` | only as the last argument of a registry entry that allows a range | `var` is `x` in 1.0. |
| `assign` | `name`, `value` | statement level only | `name` is not reserved. |
| `funcdef` | `name`, `params` (1..4 distinct names), `body` | statement level only | Body is parsed with parameters as free variables. |

Common rules: nodes are immutable, built by constructors, compared structurally, counted by `ast.count`/`ast.depth`
against the limits. New nodes take part in `children`, `substitute`, `count` and `depth`.

## Statement (parser program output)

| Field | Type | Notes |
|-------|------|-------|
| `line` | integer | First source line of the statement. |
| `node` | AST node | `assign`, `funcdef`, `call`, `rel` or an expression. |
| `kind` | string | Derived for the notebook: `assign`, `funcdef`, `plot`, `simplify`, `expand`, `command` (reserved or other registry command), `relation`, `expr`. |

`calcnb/statement.lua` returns the same record shape the runner uses today (`kind`, `text`, `name`, `param`, `line`...), with
`params` added for `funcdef` and `args`/`range` for `plot`.

## Registry entry (`calccas/registry.lua`)

| Field | Type | Notes |
|-------|------|-------|
| `name` | string | Canonical name. `ln` is an alias recorded in `alias_of = "log"`. |
| `kind` | string | `function` (pure value function), `command` (acts on an expression), `constant`. |
| `arity` | `{min, max}` | For functions and commands. |
| `status` | string | `implemented` or `reserved`. |
| `args` | string | Argument convention: `expr` (all arguments expressions), `expr-range` (last argument may be a range; `plot`), `expr-symbol` (reserved: second argument is a symbol, e.g. `diff(f, x)`). |
| `group` | string | Keyboard group (`trig`, `calculus`, `algebra`, `plot`, `constants`). |
| `since` | string | Language version that introduced the name (`1.0` for all current entries). |

Derived: reserved-name set, function-name set, command list, shortcut groups. See [contracts/registry.md](contracts/registry.md).

## Symbol table (`calcnb/env.lua`)

Unchanged limits (100 names). Function entries change from `{param, body}` to `{params, body}`; a one-parameter definition has
a one-element list. Snapshot and restore are unchanged, so a multi-line cell is still atomic.

## Error (`calccas/errors.lua`)

Unchanged shape `{kind, message, pos, line}`. Kinds: `syntax`, `domain`, `div_by_zero`, `overflow`, `too_complex`,
`unsupported`, `undefined`, `unbound_variable`, `internal`, `range`. Catalog and replacement messages in
[contracts/errors.md](contracts/errors.md).

## Compatibility entry (documentation and `compat_spec.lua`)

| Field | Notes |
|-------|-------|
| `id` | `C-1`, `C-2`... |
| `old_input` | A construct the previous language accepted. |
| `new_result` | Same result, a different result, or an error kind plus the message fragment. |
| `replacement` | What the user should write. |

## State transitions

None new. A cell still goes Idle, Running, Done, Error or Stale; the language only changes what parses and what the error
text says.
