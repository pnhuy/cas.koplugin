# Implementation Plan: Offline Calculator with Symbolic Algebra and Function Graphing

**Branch**: `001-calculator-cas-graphing` | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-calculator-cas-graphing/spec.md`; planning directive: "implement the koreader plugin with native lua"

## Summary

Deliver the P1 MVP as a KOReader plugin written entirely in LuaJIT-compatible Lua. Three layers, as the spec
requires:

1. **CAS core** (`calccas/`): lexer → recursive-descent parser → canonical n-ary AST → exact rational / float
   evaluation → domain-safe simplify/expand → deterministic printer. Pure Lua, no KOReader requires.
2. **Plotting engine** (`calcplot/`): AST compiled to a Lua closure (never `load`ed from text), uniform sampling
   plus bounded adaptive refinement, discontinuity detection, clipping, viewport transforms, auto-Y, nice tick
   generation, and a renderer-agnostic list of polylines. Pure Lua, no KOReader requires.
3. **KOReader integration** (`main.lua`, `calcui/`): Tools-menu entry, Calculator view, Graph view, a canvas
   widget that rasterizes polylines into a cached `Blitbuffer` with distinguishable line styles, and settings
   persistence via `LuaSettings`.

Plot computation is chunked across UI ticks under a time budget so the event loop never blocks.

## Technical Context

**Language/Version**: Lua 5.1 semantics as provided by LuaJIT 2.1 (KOReader runtime). No `goto`-dependent or 5.3-only
features (no integer division `//`, no bit operators; use `bit` library if needed).

**Primary Dependencies**: KOReader only (`ui/widget/*`, `ui/uimanager`, `ffi/blitbuffer`, `luasettings`,
`datastorage`, `gettext`, `device`, `ui/geometry`, `ui/font`). Zero third-party Lua libraries.

**Storage**: One `LuaSettings` file `<settings dir>/calculator.lua` holding the viewport and grid preference.
Expression and function list are session state in memory (spec assumption).

**Testing**: Busted for `calccas/` and `calcplot/` (run on desktop LuaJIT, no KOReader needed); Luacheck for lint
(`.luacheckrc` with LuaJIT std and KOReader globals `G_reader_settings`, `_`). UI verified in the KOReader desktop
emulator plus a manual device checklist. Busted is **not installed** in this environment (no `luarocks`); it is a
setup task (see research R9). Luacheck 1.2.0 and LuaJIT 2.1 are available.

**Target Platform**: KOReader on E Ink devices (Kindle, Kobo, PocketBook, reMarkable, Android) and the Linux/macOS
emulator. Minimum supported KOReader: **v2025.10 (provisional)**; to be confirmed against source in task T0 and
lowered only if the used APIs are verified in older releases. This resolves `TODO(MIN_KOREADER_VERSION)`.

**Project Type**: KOReader plugin (the repository root *is* `calculator.koplugin`).

**Performance Goals**: Evaluate/simplify typical ≤100-char expression < 1 s; plot ≤4 functions over the default
viewport < 3 s on a low-end e-reader; per-tick work ≤ ~50 ms; unchanged graph re-shown < 1 s (cache hit).

**Constraints**: No `load`/`loadstring`/`dofile` on user input; exact integer arithmetic limited to |n| ≤ 2^53
(overflow falls back to float and is flagged, never silently wrong); input ≤ 500 chars, nesting ≤ 50, ≤ 2000 AST
nodes, expansion result ≤ 500 terms; sampling ≤ 4000 evaluations per function, refinement depth ≤ 8; ≤ 6 functions.

**Scale/Scope**: Single user, in-memory; MVP = P1 only (P2/P3 excluded).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | How the plan satisfies it |
|---|-----------|--------|---------------------------|
| I | KOReader-Native | PASS (pending T0 verification) | Standard `.koplugin` layout, `WidgetContainer` plugin, `addToMainMenu` under Tools, `LuaSettings`, `gettext`, KOReader widgets. APIs listed in research R3 MUST be verified against the KOReader source before use. |
| II | Simplicity | PASS | No bignum, no generic rewrite engine, no config beyond spec'd viewport/grid. Rationals on doubles (≤ 2^53). Canonical AST is the one abstraction, required by simplify. |
| III | Performance | PASS | Chunked plotting, render cache, lazy loading of CAS/plot modules on first open, partial refresh of the canvas region only, release buffers on close. |
| IV | UX Consistency | PASS | Native widgets, on-screen keypad for `^ ( ) / sqrt`, touch + key navigation, gettext for all strings. |
| V | Reliability/Data Safety | PASS | Plugin never touches the document or its sidecar; settings written atomically by `LuaSettings:flush`; every user-input path wrapped in `pcall` with typed errors; resource limits. |
| VI | Testing | PASS | Busted suite on pure modules with independent reference cases; Luacheck; manual device checklist. Test claims only after execution. |
| VII | Compatibility | PASS | Provisional min version declared; feature detection for optional APIs (e.g., `Device:hasKeys()`). |
| VIII | Documentation | PASS | README + `docs` limited to quickstart; ambiguity rules documented once (research R2, README). |
| IX | Incremental | PASS | Milestones M1–M5 each independently verifiable (see below). |

**Post-design re-check**: PASS. No violations; Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-calculator-cas-graphing/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── cas-api.md        # CAS core public module contract
│   ├── plot-api.md       # Plotting engine public module contract
│   └── ui-contract.md    # Views, actions, settings keys
├── checklists/requirements.md
└── tasks.md              # produced by /speckit-tasks
```

### Source Code (repository root = the plugin directory)

```text
_meta.lua                 # name, fullname, description
main.lua                  # Plugin lifecycle, Tools menu entry, session state, settings
calccas/                  # CAS core — NO KOReader requires
├── errors.lua            # typed errors {kind, message, pos}
├── limits.lua            # input/node/depth/term/work limits
├── rational.lua          # exact rationals on doubles, overflow detection
├── lexer.lua
├── parser.lua            # precedence climbing, implicit multiplication rule
├── ast.lua               # constructors, canonical ordering, structural equality
├── eval.lua              # exact + float evaluation, compile-to-closure
├── simplify.lua          # simplify + expand (domain-safe)
├── printer.lua           # deterministic infix output
└── init.lua              # facade: parse / evaluate / simplify / expand / compile
calcplot/                 # Plotting engine — NO KOReader requires
├── viewport.lua          # ranges, validation, math<->pixel transform, auto-Y
├── ticks.lua             # "nice" tick/grid step generation
├── sampler.lua           # uniform + adaptive sampling, discontinuity detection
├── clip.lua              # segment clipping to viewport
├── plot.lua              # compute(functions, viewport, budget) → polylines (resumable)
└── init.lua
calcui/                   # KOReader-dependent code
├── calculator_view.lua
├── graph_view.lua
├── graph_canvas.lua      # widget: cached Blitbuffer, line styles, axes/grid/labels
├── function_list.lua     # add/edit/hide/remove dialogs
└── settings.lua          # LuaSettings wrapper (viewport, grid)
spec/                     # Busted tests (mirror calccas/, calcplot/)
.busted  .luacheckrc  README.md
```

**Structure Decision**: The repository root is the `.koplugin` directory so it can be symlinked/copied into
KOReader's `plugins/` folder as `calculator.koplugin`. Top-level module folders are prefixed (`calc*`) because the
plugin directory is added to `package.path` and generic names (`lib`, `ui`) could collide with KOReader modules.
Engines have zero KOReader requires (FR-037) and are testable with plain `luajit`/Busted.

## Milestones (incremental, each independently verifiable)

- **M1 – Plugin skeleton**: `_meta.lua`, `main.lua`, Tools entry opens an empty view; Luacheck clean.
- **M2 – Expression engine**: lexer/parser/AST/eval/printer + error model + limits; Busted green (Story 1).
- **M3 – Calculator view**: input, keypad, Evaluate, result, session-kept expression (Stories 1, 4).
- **M4 – Simplify/expand**: domain-safe rules + tests; wire Simplify button (Story 2).
- **M5 – Plot engine + Graph view**: sampler/discontinuities/clipping/ticks tests for the eight reference
  functions; canvas widget; function list; range dialog; cache; settings (Story 3, 4). Device/emulator checklist.

## Complexity Tracking

No constitution violations to justify.
