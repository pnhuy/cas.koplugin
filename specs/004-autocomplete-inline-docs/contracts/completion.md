# Contract: Completion API (pure)

Modules: `calcnb/completion.lua`, `calcnb/completion_session.lua`, `calccas/builtin_docs.lua`. No UI class is required by
any of them. All functions are total: bad input gives `nil` or an empty result, never an error.

## `completion.word_at(text, charpos) -> word | nil`

See data-model "Word at cursor". Examples (cursor shown as `|`):

| Text | Result |
|------|--------|
| `dif|` | `prefix = "dif"` |
| `1 + si| + 2` | `prefix = "si"`, whole word `si` |
| `1 + s|in + 2` | `prefix = "s"`, whole word `sin` (the replaced range covers `sin`) |
| `|` or `x +| ` | `nil` |
| `# dif|` | `nil` (comment) |
| `2e|3` | `nil` (number) |
| `plot(sin(x), x|=-1..1)` | `nil` for `x` as a range variable; the strip works for names elsewhere |
| `a = 1\ndi|` | `prefix = "di"` (cursor line only) |

## `completion.suggest(prefix, names, opts) -> { items, more }`

- `names`: list of Defined name.
- `opts.limit`: how many items to return (default 6); `more` is the count left out.
- Candidates are the registry entries plus `names`. Case-insensitive prefix match. Order as in data-model.
- An exact match is included.
- Each item is a Suggestion (data-model).

## `completion.apply(text, word, suggestion) -> edit`

Replaces characters `word.first .. word.last` with `suggestion.insert` and returns `{ text, charpos, first, last }`. The
new `charpos` is the end of the insert minus `suggestion.back`. Text outside the range is unchanged.

## `session = completion_session.new()`

| Method | Contract |
|--------|----------|
| `session:set_names(names)` | Replaces the defined names; the next `update` uses them |
| `session:update(text, charpos) -> changed` | Recomputes the model. Returns `true` only if the visible model differs from the previous one (items, highlight, more, or shown/hidden) |
| `session:model() -> model \| nil` | `nil` when hidden |
| `session:move(delta) -> changed` | Wraps around the shown items; no-op when hidden |
| `session:select(index) -> changed` | Highlights chip `index` without accepting. Returns `false` if it is already highlighted or out of range |
| `session:dismiss() -> changed` | Hides the strip for the current word without touching text |
| `session:accept() -> edit \| nil` | Edit for the highlighted item, `nil` when hidden. Hides the strip |

Rules: dismissal holds while the cursor stays in the same word (same line and start); starting a new word clears it.
`accept` never evaluates anything. A `suggest` or `word_at` failure inside `update` is caught: the session hides and
returns `changed` for the transition.

## `builtin_docs[name] -> entry | nil`

See data-model "Documentation entry". Complete for every registry name (test).

## Runner and notebook additions

- `runner.run(source, env)` output gains `defined`: list of Defined name for every assignment or function definition of a run that succeeded. An error output has no
  `defined` (the runner restores the environment).
- `Notebook:run_cell` sets `cell.defined = out.defined or {}` when the output is not an error, and leaves it unchanged on an error.
- `Notebook:clear_output`, `clear_all_outputs` and `begin_run_all` set `cell.defined = nil`.
- `Notebook:completion_names() -> list` unions `cell.defined` over code cells in order.
