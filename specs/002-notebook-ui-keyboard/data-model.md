# Data Model: Notebook Interface and Programming Keyboard

All entities live in pure modules under `calcnb/` (no KOReader requires) except where noted.

## Notebook (`calcnb/notebook.lua`)

| Field | Type | Rules |
|-------|------|-------|
| `title` | string | 1-60 chars; default "Notebook"; trimmed |
| `cells` | array of Cell | ordered; at least 1 after load (an empty cell is added if none); max 200 |
| `next_id` | integer | monotonically increasing; never reused |
| `env_version` | integer | starts 0; +1 when a run changes a name (R6) |
| `env` | Environment | rebuilt by Run all; not persisted |
| `viewport_default` | Viewport | from 001 `calcplot.viewport`; default for a new plot |

Operations (all pure, return `ok, err`): `add(index)`, `duplicate(id)`, `delete(id)`, `move(id, delta)`,
`set_source(id, text)`, `clear_output(id)`, `clear_all_outputs()`, `index_of(id)`.
Invariants: ids unique; `delete` of the last cell leaves one empty cell; source text valid UTF-8, `\r\n` and `\t`
normalized to `\n` and two spaces, max 5000 chars.

## Cell

| Field | Type | Rules |
|-------|------|-------|
| `id` | integer | permanent, unique within the notebook |
| `type` | `"code"` \| `"text"` | `text` is P3; ignored by Run |
| `source` | string | see Notebook invariants |
| `exec_number` | integer or nil | order of the most recent run; display only |
| `status` | enum | `idle`, `editing`, `running`, `completed`, `error`, `stale` |
| `out_of_date` | boolean | source edited after the last run |
| `output` | Output or nil | in memory only in the first release |
| `ran_at_env` | integer or nil | `env_version` when last run |
| `viewport` | Viewport or nil | only for cells whose output is a graph; persisted |

### Status transitions

```text
idle --edit--> editing --leave--> idle (source changed => out_of_date if it has an output)
idle|completed|error|stale --run--> running --ok--> completed
                                    running --failure--> error
                                    running --limit/cancel--> error (message "Limit reached"/"Cancelled")
completed --(earlier cell changed a name, reorder, delete)--> stale
stale|error|completed --run--> running
```

`editing` is a view state: it is shown while the editor has focus and does not replace a stored `completed/error/stale`
(the cell returns to its stored status on leaving the editor).

## Output (`calcnb/output.lua`)

| Field | Type | Rules |
|-------|------|-------|
| `kind` | `"value"` \| `"error"` \| `"graph"` | |
| `canonical` | string | engine result text, used for copy and insert (FR-028) |
| `display` | string | `canonical` passed through the superscript/subscript prettifier (plain-text fallback is always `canonical`) |
| `error` | `{kind, message, pos}` or nil | from `calccas.errors`, localized text built by `calcui/outcome.lua` |
| `graph` | `{functions, x_range}` or nil | functions are `{label, ast}` entries; max 6 |
| `truncated` | boolean | display shortened to 600 chars; Expand shows full text |

## Environment (`calcnb/env.lua`)

`vars`: name -> number/rational result accepted by `calccas.evaluate(expr, vars)`.
`funcs`: name -> `{param, ast}` for `f(x) = ...`. Rules: names `[A-Za-z_][A-Za-z0-9_]*` up to 32 chars; may not shadow
built-ins (`sin cos tan exp log ln sqrt abs pi e plot simplify expand`); at most 100 names. `snapshot()`/`restore()` support
rolling back a failed multi-line cell so a failed run never leaves a half-applied environment.

## Statement (`calcnb/statement.lua`)

`{kind = "assign"|"funcdef"|"plot"|"expr", name, param, text, args, range, line}`; produced by `parse(source)` which returns
a list of statements or `nil, err` with a line and column. The cell result is that of the last statement.

## Keyboard Layout (`calcnb/keyboard_layout.lua`)

`pages = { letters = rows, shift = rows, symbols = rows }`; a row is an array of `Key`.
`Key = { label, insert, back = 0, action = nil }`: `insert` is the text added at the cursor, `back` is how many characters
to move left afterwards (puts the cursor inside `()`), `action` is one of `shift`, `sym`, `backspace`, `delete`, `left`,
`right`, `up`, `down`, `home`, `end`, `enter`, `space`, `select_all`, `copy`, `cut`, `paste`, `run`.
Validated by tests: every printable ASCII character the lexer accepts appears on some page without long-press (SC-002);
`pi` key inserts `pi`; unsupported shortcuts are absent.

## Shortcut (`calcnb/shortcuts.lua`)

`{ group, label, insert, back }` with groups `basic`, `trig`, `algebra`, `graphing`. Built from `calccas.functions()` and
runner commands (R12); `insert` for a function is `name()` with `back = 1`.

## Persisted file (`<settings dir>/calculator_notebook.lua`, see `contracts/notebook-file.md`)

Stores `title`, `next_id`, cells `{id, type, source, viewport}`, `scroll = {top_id, offset}`, `version = 1`.
