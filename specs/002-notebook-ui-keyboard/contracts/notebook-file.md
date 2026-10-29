# Contract: Notebook File

Path: `<DataStorage:getSettingsDir()>/calculator_notebook.lua`, written and read through `LuaSettings` (KOReader's
`.old` backup applies). Keys:

| Key | Type | Notes |
|-----|------|-------|
| `version` | integer | 1; unknown higher versions are refused with a message and the file is left untouched |
| `notebooks` | table `{ [name] = Notebook }` | only `"default"` is used in this release |
| `last_notebook` | string | `"default"` |

Notebook table: `{ title, next_id, cells = { {id, type, source, viewport} ... }, scroll = {top_id, offset} }`
with `viewport = {xmin, xmax, ymin, ymax, auto_y, grid, axes, equal}` (validated through `calcplot.viewport.new`).

## Load rules (`calcnb/store_logic.sanitize`)

- Wrong type, missing keys, non-string sources, invalid UTF-8, duplicate/missing ids, > 200 cells or > 5000 chars: repair
  where unambiguous (renumber ids, truncate with a problem entry) otherwise drop that cell. Always returns a usable notebook
  (one empty cell if everything is dropped) and `problems = { "..." }`.
- Problems are shown once in a message; the unreadable original is not overwritten until the user saves again, and a
  `.bad` copy is not made by the plugin (the `.old` backup from LuaSettings is the recovery path).
- Outputs are not stored; every loaded cell is `idle` without output.

## Save rules

- `to_data(notebook)` produces plain tables only (no functions, no cycles), then `LuaSettings:flush()`.
- Autosave on Close; explicit Save button; both report failure with a message and keep the in-memory notebook dirty.
- Delete notebook: confirmation dialog, then `delSetting` + flush.
