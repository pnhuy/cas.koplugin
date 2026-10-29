# Phase 0 Research: Calculator CAS and Graphing Plugin

No `NEEDS CLARIFICATION` remained in the Technical Context. The items below record decisions and the facts that
**must be verified against the KOReader source** during task T0 (no KOReader checkout exists locally; the APIs
below come from knowledge of KOReader and are therefore unverified until then — Constitution I).

## R1. Number representation

- **Decision**: Exact rationals as a pair of Lua doubles (num, den) kept normalized (gcd, positive denominator),
  valid while |value| ≤ 2^53. Any operation that would exceed 2^53 returns a float result flagged `approx`
  instead of a wrong exact value. Decimals such as `0.25` parse exactly to rationals (`1/4`).
- **Rationale**: LuaJIT has no 64-bit integer in the Lua number type; bignums are YAGNI for an MVP and add size.
- **Alternatives**: Bignum module (rejected: complexity, memory, speed); floats only (rejected: `1/3+1/6 → 1/2`
  requirement).

## R2. Syntax rules for ambiguity (documented in README)

- Precedence high→low: function call/parentheses; `^` (right-assoc); unary `-`/`+`; `* /` (left-assoc); `+ -`.
  So `-2^2 = -4`, `2^3^2 = 512`, `2^-1 = 1/2`, `-x^2 = -(x^2)`.
- Implicit multiplication accepted only for: number followed by identifier or `(` (`2x`, `2(x+1)`), `)` followed by
  `(` or identifier/number. Identifier-identifier (`xy`) is a single variable name, not `x*y`. `2x^2 = 2*(x^2)`.
- `log` = natural log (spec assumption); `ln` identical. Trig in radians. `e` and `pi` are constants.
- Variable names: `[A-Za-z_][A-Za-z0-9_]*`; function names reserved. Assignment form for the calculator is an
  explicit variable list (`x=2, y=3`) entered in a secondary field, not statements, to avoid a statement grammar.
- Division by zero → `math` error `div_by_zero`; `0^0` → error `undefined`; `0^-1` → div_by_zero.
- Domain: `sqrt(neg)`, `log(≤0)` → `domain` error (no complex numbers). `tan` at odd multiples of π/2 → `domain`.
  In plotting all error kinds in sampling mean "undefined point", never a thrown error.
- Overflow: float result `inf`/`nan` or exact > 2^53 on `^` → `overflow` error ("result too large") in calculator.

## R3. KOReader APIs to verify in T0

| Need | Expected API | Notes |
|------|--------------|-------|
| Plugin class | `WidgetContainer:extend{name="calculator", is_doc_only=false}` with `init()` | Works in FileManager and Reader. |
| `_meta.lua` | returns `{name, fullname, description}` | Bookshelf plugin (local) shows `name` is load-bearing on stable releases. |
| Tools menu | `self.ui.menu:registerToMainMenu(self)`; `addToMainMenu(menu_items)` sets `menu_items.calculator = {text=_("Calculator"), sorting_hint="tools", callback=...}` | Verify for both FileManager and Reader menus. |
| Full-screen views | `InputContainer`/`WidgetContainer` + `FrameContainer`, `TitleBar`, `ButtonTable`, `UIManager:show/close` | Follow `InputDialog` composition. |
| Text input | `InputText` (summons on-screen `VirtualKeyboard`) or `InputDialog` / `MultiInputDialog` | Verify keyboard layout lacks `^`; keypad row compensates. |
| Result text | `TextBoxWidget` / `ScrollTextWidget` | |
| Lists | `Menu` or `ButtonDialog` | Function list. |
| Drawing | `Blitbuffer.new(w,h,type)`, `bb:paintRect(x,y,w,h,color)`, `bb:blitFrom`, `Blitbuffer.COLOR_*`, `Blitbuffer.gray()`/`ColorRGB32` | No line primitive assumed: lines drawn via Bresenham over `paintRect`. Verify. |
| Text on canvas | `RenderText:renderUtf8Text` or `TextWidget` painted at coordinates | Tick labels. Verify API. |
| Refresh | `UIManager:setDirty(widget, "ui", region)` / `"partial"` / `"fast"` | Canvas redraw uses region refresh, not full. |
| Deferred work | `UIManager:nextTick(fn)` / `UIManager:scheduleIn(sec, fn)` / `UIManager:unschedule(fn)` | Chunked plotting. |
| Settings | `LuaSettings:open(DataStorage:getSettingsDir().."/calculator.lua")`, `readSetting`, `saveSetting`, `flush` | |
| i18n | `local _ = require("gettext")` | |
| Screen | `Device.screen:getWidth()/getHeight()`, `Screen:scaleBySize`, `onSetDimensions`/`onScreenResize` | Orientation changes. |
| Keys | `Device:hasKeys()`, `key_events` table on `InputContainer` | Physical-button support, feature-detected. |

## R4. Evaluation strategy

- **Decision**: `compile(ast)` returns a Lua closure `f(x) → number|nil` built by recursive closure construction
  (no source generation, no `load`). Plot hot path avoids table allocation and `pcall` per sample; undefined points
  return `nil`. Exact evaluation walks the AST using `rational`.
- **Rationale**: Satisfies "never execute input as Lua" structurally and is fast enough on low-end CPUs.

## R5. Simplification design

- **Decision**: Canonical n-ary `add`/`mul` nodes; subtraction = `add` with `mul(-1, …)`; division =
  `mul(a, pow(b,-1))`. Passes: constant folding → flatten → collect like terms (coefficient × term) → neutral
  elements → integer-power expansion for `expand` → deterministic sort (degree, then name, then structure).
- **Domain safety**: never cancel `x/x`, `x^a * x^-a`, nor rewrite `sqrt(x^2)`, `(x^a)^b → x^(ab)` unless `b` is an
  integer; `x*x^-1` is left as `x/x` (printed as `x/x`) with a note flag `requires: x ≠ 0` available to the UI.
  `x^a*x^b → x^(a+b)` only when both exponents are rationals with the same sign or `x` is a number (no domain
  change since negative exponents already exclude 0 in both forms).
- **Alternatives**: Rule-based rewrite engine with pattern language (rejected: YAGNI, harder to prove safe).

## R6. Discontinuity and sampling algorithm

1. Sample `N = min(plot pixel width, 4000)` uniform x values; mark undefined/non-finite samples as breaks.
2. For consecutive defined samples with large |Δy| (> 0.5× viewport Y-range or sign change with |y| growing toward
   the gap), bisect the interval up to depth 8 (adaptive refinement also applied where the turning angle between
   segments exceeds ~10°, capped by the per-function evaluation budget of 4000).
3. After refinement, if |Δy| still exceeds the threshold **and** magnitudes grow toward the gap (pole-like), insert a
   break (no connection). Detects `1/x`, `tan(x)`, `1/(x-1)` without symbolic analysis.
4. A break is also inserted at any undefined sample, so `log(x)`/`sqrt(x)` draw nothing outside their domain.
5. Segments are clipped (Liang–Barsky) to the viewport; values beyond ±1e9×range clamp to avoid float issues.
- **Alternative**: Symbolic pole detection (rejected for MVP: needs solver; numeric method is reliable enough and
  is validated by the eight reference tests).

## R7. Non-blocking computation and caching

- Plot computed per function in resumable steps (`plot.step(state, budget_seconds)`), driven by
  `UIManager:nextTick`; budget ≈ 50 ms/tick using `os.clock()`; cancellation by closing the view
  (`UIManager:unschedule`). Result polylines cached by key `hash(function strings + visibility + viewport + canvas
  size + grid)`; rendered `Blitbuffer` cached with the same key; freed in `onCloseWidget`.
- Only the canvas rectangle is refreshed (`"ui"` region); no full-screen flash during edits.

## R8. Rendering for grayscale E Ink

- Axes 2 px black, grid 1 px light gray (dotted if the device lacks gray), curves 2–3 px; styles per function index:
  solid-thick, dashed, dotted, dash-dot, solid-thin+markers, double. Pure black/white device fallback relies on
  pattern, not shade. Tick labels use KOReader's default UI face at small size.

## R9. Tooling

- LuaJIT 2.1 and Luacheck 1.2.0 present; `luarocks`/`busted` absent. Plan: `brew install luarocks && luarocks
  install busted` (documented in README); alternatively KOReader's `./kodev test` environment bundles busted if a
  KOReader checkout is used for integration. Until busted runs, no test-passing claim is made.

## R10. Settings persistence

- Keys: `viewport = {xmin,xmax,ymin,ymax,auto_y}`, `grid = true|false`. Loaded lazily at first open, saved on
  explicit viewport change and on close with `flush()`. Corrupt/absent values fall back to defaults
  (xmin=-10,xmax=10,ymin=-10,ymax=10, auto_y=true). Never touches the document's sidecar.

## T0 findings (KOReader API verification)

Source checked: KOReader `master`, commit `54eb77e09dc0` (2026-10-29), cloned read-only; no release tag was
available (`git describe` fails), so the minimum version in `plan.md` stays provisional.

| Area | Verified |
|------|----------|
| Plugin files | `_meta.lua` returns `{fullname, description}` only; a `name` field is ignored with a deprecation warning, so it is NOT set. `main.lua` extends `WidgetContainer` with `name`, `is_doc_only=false`; `init()` calls `self.ui.menu:registerToMainMenu(self)`; `addToMainMenu(menu_items)` sets `menu_items.<key> = {text, sorting_hint, callback}`. |
| Menu hint | `"tools"` is a valid top-level tab id (`menusorter.lua` attaches items by `sorting_hint` to any menu id). Items not named in `*_menu_order.lua` are appended at the end of that menu. In-tree plugins use `"more_tools"` (submenu). Decision: keep `"tools"` per spec so Calculator is one tap from the Tools tab. |
| UIManager | `show(widget, refreshtype, refreshregion, x, y, refreshdither)`, `close`, `scheduleIn`, `nextTick`, `tickAfterNext`, `unschedule`, `setDirty(widget, refreshtype, refreshregion, refreshdither)` (nil widget = refresh only). |
| Widgets | `TitleBar` (`title`, `subtitle`, `close_callback`, `with_bottom_line`, `fullscreen`), `ButtonTable` (`buttons` rows, `width`, `shrink_unneeded_width`, `sep_width`), `Button` (`text`, `callback`, `enabled`, `enable/disable/setText`), `ButtonDialog`, `MultiInputDialog` (`fields`, `getFields()`). |
| Input | `InputDialog` has `getInputText`, `setInputText(text, edited_state, cursor_at_start_or_end)`, `addTextToInput(text)`, `allow_newline`, `enter_callback`. `InputText` has `addChars`, `delChar`, `getText`, `setText`. |
| Scrolling text | `ScrollTextWidget` has `scrollText`, `scrollToTop/Bottom/Ratio`, `resetScroll`, `scroll_callback`; `TextBoxWidget:setText(text)` updates content. |
| Settings | `LuaSettings`: `open`, `readSetting`, `saveSetting`, `delSetting`, `has`, `isTrue`, `flush`, `close`; `require("datastorage"):getSettingsDir()`. |
| Graphics | `Blitbuffer`: `new`, `setPixel`, `paintRect`, `fill`, `blitFrom`, `free`, `gray(level)`. `RenderText:renderUtf8Text(dest_bb, x, baseline, face, text, ...)`; `Font:getFace(name, size)`. |
| Device | Capability flags `hasKeys`, `hasDPad`, `hasKeyboard`, `hasFewKeys`, `isTouchDevice` exist. |

Not verified by running anything: all of the above is from reading source. Nothing has run in the emulator.
