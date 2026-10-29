# Data Model

All structures are plain Lua tables. Engines never reference KOReader classes.

## Error (`calccas/errors.lua`)

| Field | Type | Notes |
|-------|------|-------|
| `kind` | string | `syntax`, `div_by_zero`, `domain`, `overflow`, `undefined`, `unsupported`, `too_complex`, `unbound_variable` |
| `message` | string | Human-readable, already gettext-ready (UI translates via template keys) |
| `pos` | number? | 1-based character offset for `syntax` errors |

Public functions return `value, nil` or `nil, Error` — they never throw on user input.

## AST node (`calccas/ast.lua`)

| `t` | Fields | Meaning |
|-----|--------|---------|
| `num` | `n`, `d` (doubles, d>0, gcd=1), `approx?` | Exact rational, or float flagged `approx` (then `v`) |
| `const` | `name` (`pi`,`e`) | Named constant |
| `var` | `name` | Variable |
| `add` | `args[]` (≥2) | n-ary sum |
| `mul` | `args[]` (≥2) | n-ary product |
| `pow` | `base`, `exp` | Power |
| `fn` | `name` (`sin cos tan exp log ln sqrt abs`), `arg` | Function application |

Invariants: `add`/`mul` flattened; at most one `num` per `add`/`mul` and placed first; `args` in canonical order;
no `sub`/`div`/`neg` nodes (represented via `-1` coefficient and `pow(…,-1)`). Node count ≤ 2000, depth ≤ 50.

## Result (`calccas.evaluate` / `simplify`)

| Field | Type | Notes |
|-------|------|-------|
| `exact` | AST? | Exact form if available |
| `value` | number? | Float approximation if the expression has no free variables |
| `text` | string | Printed result (exact, plus ` ≈ decimal` when irrational) |
| `assumptions` | string[] | e.g., `x ≠ 0` when a transformation needs a domain note |

## Function Entry (session state in `main.lua`)

| Field | Type | Rules |
|-------|------|-------|
| `id` | number | Monotonic |
| `text` | string | User input, ≤ 500 chars |
| `visible` | boolean | Default true |
| `style` | number | 1..6 assigned by index (see research R8) |
| `fn` | function? | Compiled closure `f(x)`, nil if error |
| `error` | Error? | Set when parse/compile fails |

Limit: ≤ 6 entries; a function using a variable other than `x` is an error (`unbound_variable`).

## Viewport (`calcplot/viewport.lua`)

| Field | Type | Validation |
|-------|------|------------|
| `xmin`, `xmax`, `ymin`, `ymax` | number | finite; `xmin<xmax`, `ymin<ymax`; |value| ≤ 1e9; span ≥ 1e-9 |
| `auto_y` | boolean | When true, `ymin/ymax` are derived from sampled finite values (trimmed to 2–98 percentile, 10% padding) |
| `grid` | boolean | Show grid |

Transform: `px = (x - xmin)/(xmax-xmin) * W`, `py = H - (y - ymin)/(ymax-ymin) * H` (pure functions, tested).

## Curve (`calcplot.plot` output)

`{ id, style, polylines = { { {x,y}, ... }, ... } }` — each polyline is a continuous run in **screen
coordinates**, already clipped; breaks between polylines mark discontinuities/undefined regions.

## Settings (`calcui/settings.lua`)

File `calculator.lua`: `viewport` (table above), `grid` (boolean). Invalid or missing → defaults.

## State transitions

- Function Entry: `new → (parse ok) compiled | (parse error) errored`; editing re-enters `new`; `visible` toggles
  independently.
- Plot job: `idle → computing (ticks) → ready (cached) → stale (functions/viewport changed) → computing`; closing the
  view cancels `computing`.
