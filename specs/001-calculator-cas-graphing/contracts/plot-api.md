# Contract: Plotting Engine (`require("calcplot")`)

Pure Lua. No KOReader requires. Consumes compiled closures from `calccas.compile`; produces screen-space polylines.
Rendering (pixels, fonts, widgets) is the UI layer's job.

## Viewport

| Function | Purpose |
|----------|---------|
| `viewport.new(xmin,xmax,ymin,ymax)` | Validated viewport or `nil, err` (`xmin<xmax`, finite, spans ≥ 1e-9, ≤ 1e9) |
| `viewport.default()` | `-10..10` both axes, `auto_y=true` |
| `viewport.to_screen(vp, W, H, x, y)` | → `px, py` |
| `viewport.to_math(vp, W, H, px, py)` | inverse; round-trips to within 1e-9 |
| `viewport.auto_y(vp, samples)` | percentile-trimmed Y range with 10% padding; unchanged if < 2 finite samples |

## Ticks

`ticks.nice(min, max, target_count)` → `{values..., step}` with step ∈ {1,2,5}×10^k; labels formatted without
trailing noise (`0.1+0.2` problem avoided by rounding to step precision).

## Plot job (resumable, non-blocking)

```lua
local job = plot.new(functions, vp, W, H)   -- functions = { {id=, fn=, visible=, style=}, ... }
repeat
  local done = job:step(budget_seconds)     -- does at most ~budget of work, returns true when finished
until done
local curves = job:result()                 -- { {id=, style=, polylines={ { {px,py},... }, ... }}, ... }
```

Guarantees:

- Total evaluations per function ≤ 4000; refinement depth ≤ 8; no recursion deeper than that.
- `nil`, NaN, ±inf from `fn` are undefined points → break the polyline.
- Pole-like jumps (|Δy| large and magnitude growing toward the gap after refinement) → break the polyline.
- Output points are clipped to `[0,W]×[0,H]` (Liang–Barsky); fully outside segments are dropped.
- `job:cancel()` releases state; `step` after cancel returns `true` with empty result.
- When `vp.auto_y`, the job first samples to derive Y range (reported in `job:viewport()`).
- Deterministic: same input → same polylines.

## Required reference plots (test fixtures)

| Function | Expectation |
|----------|-------------|
| `x` | one polyline, 45° |
| `x^2` | one polyline, vertex at origin |
| `sin(x)` | one polyline, period 2π, amplitude 1 |
| `1/x` | exactly two polylines split at x=0 |
| `tan(x)` on [-2π,2π] | polylines split at each odd multiple of π/2 (4 breaks) |
| `log(x)` on [-5,5] | nothing for x ≤ 0, one polyline for x>0 |
| `sqrt(x)` on [-5,5] | nothing for x < 0, one polyline for x ≥ 0 |
| `1/(x-1)` | exactly two polylines split at x=1 |
