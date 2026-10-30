# Data Model: Autocomplete and Inline Documentation

All entities are plain Lua tables. None is saved to the notebook file.

## Completion context (input)

| Field | Type | Notes |
|-------|------|-------|
| `text` | string | Live text of the edited cell |
| `charpos` | integer | 1-based character index where a typed character would go (`1 .. #chars + 1`) |
| `names` | list of Defined name | From `Notebook:completion_names()`; empty when nothing has run |

## Word at cursor

`word_at(text, charpos)` returns `nil` (no strip) or:

| Field | Notes |
|-------|-------|
| `prefix` | Letters, digits, `_` from the word start up to the cursor; starts with a letter |
| `first`, `last` | Character range of the whole word (includes the part after the cursor) |
| `line` | Line number of the cursor, for tests |

`nil` when: the prefix is empty, the cursor is in a `#` comment, the word begins with a digit run (`2e3`), the cursor is
at a position that is inside a number, or the word is the left side of a `name=` plot range variable (`x=` inside a
call). The part of the line before the cursor decides, never other lines.

## Defined name

| Field | Notes |
|-------|-------|
| `name` | At most 32 characters (existing limit) |
| `kind` | `"var"` or `"func"` |
| `params` | List of parameter names, for `func` only |

Ledger: `cell.defined` is a list of these for the last run of the cell. Unique by `name` within the union, later cells
win. Names equal to a registry name cannot occur (reserved).

## Documentation entry

| Field | Notes |
|-------|-------|
| `signature` | Text such as `plot(f1[, f2, ...], x=lo..hi)` |
| `summary` | One line, no newline |
| `examples` | One or more source strings valid in a cell |
| `note` | Optional: alias (`ln` is `log`), or what a reserved command does today |

Keyed by registry name. Coverage with the registry is exact in both directions.

## Suggestion

| Field | Notes |
|-------|-------|
| `name` | Text to match and insert |
| `source` | `"builtin"`, `"user"` |
| `kind` | `function`, `command`, `constant`, `var`, `func` |
| `available` | `false` for reserved commands |
| `insert` | `name .. "()"` or `name` |
| `back` | `1` when the cursor goes inside the brackets, else `0` |
| `doc` | Documentation entry for built-ins; for a user `func`, a signature built from `name(params)`; for a `var`, `nil` |

Ranking key: exact match, then `available` built-ins, then user names, then reserved; then length; then name.

## Edit result

`apply(text, word, suggestion)` returns `{ text, charpos, first, last }`: the new text, the new cursor position, and
the replaced character range. All text outside `first .. last` is byte-for-byte unchanged.

## Session

| Field | Notes |
|-------|-------|
| `names` | Defined names, set by the view on each rebuild |
| `highlight` | Index into the shown chips, 1 when a list appears |
| `dismissed` | `{ first, line }` of the word dismissed, or `nil` |
| `model` | Last result: `{ items, more, highlight }` or `nil` |

Transitions: `update(text, charpos)` → recompute, reset `highlight` when the prefix changed, honour `dismissed`, and return
whether the model differs from before. `move(delta)` wraps within the shown chips. `dismiss()` records the word and hides.
`accept()` returns the edit result for the highlighted item. A new word start clears `dismissed`.

## Relationships

`Notebook:completion_names()` ← `cell.defined` ← `runner.run` output. `Session` uses `completion` and `builtin_docs`.
`SuggestionStrip` shows `session.model`. `CellEditor` supplies `(text, charpos)` and applies the edit result.
