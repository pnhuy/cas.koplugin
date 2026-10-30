# Implementation Plan: Expression Language Standard

**Branch**: `003-expression-language-standard` | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-expression-language-standard/spec.md`

## Summary

Make the expression language a defined, versioned thing instead of the sum of a lexer, a parser, three function tables and
a set of Lua patterns in the notebook layer. The audit ([audit.md](audit.md)) shows the engine already covers most of the
requested syntax. The work is:

1. **Move all syntax into `calccas/`.** The lexer gains `,`, `=`, `==`, `..`, trailing `#` comments, newlines and scientific
   notation. The parser gains a program level (statements, continuation rules), assignment, function definition,
   relation, call and range productions. `calcnb/statement.lua` stops using patterns and becomes a thin adapter over the
   parser.
2. **One function registry** (`calccas/registry.lua`) that holds every function, command and constant with its arity,
   status (`implemented` or `reserved`) and argument convention. The parser, evaluator, reserved-name check, shortcuts and
   `calccas.FUNCTION_NAMES` read from it. A test fails if any list drifts.
3. **Reject implicit multiplication** with a message that names the replacement, and make `1e3`/`1e-3` exact numbers
   (user decision, 2026-10-30). Saved text is never rewritten.
4. **Document and test**: a versioned language reference (v1.0), a formal grammar with numbered productions, an error
   catalog, and a data-driven parser conformance suite that proves every production is covered and that the old notebook
   corpus either behaves the same or fails with a replacement message.

No new commands are implemented. `diff`, `solve`, `factor`, `integrate`, `subs` and `approx` are registered as
`reserved`: they parse, and evaluating one gives an `unsupported` error that says so.

## Technical Context

**Language/Version**: LuaJIT 2.1 (KOReader's runtime), plain Lua 5.1 idiom. No `load`/`loadstring`/`dofile` on user text.

**Primary Dependencies**: none new. Engine modules stay free of KOReader UI classes.

**Storage**: unchanged. The notebook file format (version 1) is unchanged; cell `source` stays plain text.

**Testing**: Busted and Luacheck from `$HOME/.luarocks-luajit/bin`. Baseline before this feature: 641 successes, 0 failures,
luacheck clean over 90 files. New conformance suite is data-driven; existing parser, statement, evaluator, reference-case and
fuzz specs stay green except for rows listed in the compatibility list.

**Target Platform**: KOReader on e-ink devices (Kindle, Kobo, Android) and the desktop emulator.

**Project Type**: single Lua plugin (library layers plus UI).

**Performance Goals**: parsing a cell of 50 lines stays imperceptible (no measurable regression against the 002 timings;
the new lexer is one pass). No evaluation while typing (unchanged).

**Constraints**: offline, no external CAS, no Python. Limits unchanged (500 characters per statement, depth 50, 2000 nodes,
100 names, 32-character names, 6 plot functions). The language never reaches Lua's interpreter.

**Scale/Scope**: about 6 source files changed (`lexer`, `parser`, `ast`, `eval`, `printer`, `statement`), 1 added
(`registry`), 3 consumers re-pointed (`calccas.lua`, `calcnb/runner`, `calcnb/shortcuts`), 1 README section, and docs.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | How the plan satisfies it |
|---|-----------|--------|---------------------------|
| I | KOReader-Native | PASS | No UI or KOReader API change. Pure Lua inside the existing `calccas/` and `calcnb/` layers; the top-level facade `calccas.lua` stays (KOReader's `package.path` lacks `?/init.lua`). |
| II | Simplicity | PASS | One registry replaces three hand-synced tables; one lexer/parser replaces regex classification. Unimplemented commands are not built. No pluggable grammar, no per-cell language mode, no compatibility switch. |
| III | Performance | PASS | Single-pass lexer, same recursive descent; no new work during typing. Limits unchanged. |
| IV | UX consistency | PASS | Errors keep the existing kinds and line/position display. Implicit multiplication gets a replacement hint instead of silent acceptance. Keyboard shortcuts are generated from the registry so keys and language agree. |
| V | Reliability and data safety | PASS | Saved text is never rewritten; notebook format unchanged; old cells that no longer parse fail with a message and keep their source. Language never executes input as Lua (existing fuzz spec extended). Env atomicity for multi-line cells unchanged. |
| VI | Testing | PASS | Conformance cases are written before the parser changes (failing first). Every grammar production has at least one accepted and one rejected case, enforced by a test. Results are only claimed after running Busted and Luacheck. |
| VII | Compatibility | PASS | Old-notebook corpus test (US4). Deliberate incompatibilities are listed in the compatibility list, each with a replacement message. Min KOReader version unchanged. |
| VIII | Documentation | PASS | Versioned language reference, grammar, error catalog and README section are deliverables. Future features are documented separately. |
| IX | Incremental | PASS | Phases keep the suite green at each step: registry first (no behaviour change), then lexer/parser additions, then the implicit-multiplication change last and alone. |

**Post-design re-check**: unchanged. The one deliberate behaviour break (implicit multiplication) is a user decision, is
isolated in its own phase, and is justified by the request (requirement 5). No violations, so Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/003-expression-language-standard/
├── plan.md              # This file
├── spec.md              # Feature specification
├── audit.md             # Audit of the language as implemented (before any change)
├── research.md          # Phase 0: decisions with rationale and alternatives
├── data-model.md        # Phase 1: tokens, AST nodes, registry entries, statements, errors
├── quickstart.md        # Phase 1: how to verify the feature by hand and by test
├── contracts/
│   ├── grammar.md       # Formal grammar, numbered productions (G-01 ...)
│   ├── language-reference.md  # Outline and normative tables of the versioned reference (v1.0)
│   ├── registry.md      # Registry entry contract and derived-list rules
│   └── errors.md        # Error catalog: kinds, messages, replacement hints
├── checklists/requirements.md
└── tasks.md             # Created by /speckit-tasks (not by this command)
```

### Source Code (repository root)

```text
calccas/
├── lexer.lua        # CHANGED: , = == .. # newline, scientific notation, token line numbers
├── parser.lua       # CHANGED: program/statement/relation/call/range productions, continuation, implicit-mult rejection
├── ast.lua          # CHANGED: nodes assign, funcdef, rel, call, range
├── eval.lua         # CHANGED: reads functions from registry; rel and call handling
├── printer.lua      # CHANGED: prints rel (a == b), exact/approximate markers unchanged
├── registry.lua     # NEW: single table of functions, commands and constants
├── errors.lua       # CHANGED: add `reserved` kind only if research R7 says so (see errors.md)
└── limits.lua       # unchanged
calccas.lua          # CHANGED: FUNCTION_NAMES and wrapper recognition derived from the registry; exposes LANGUAGE_VERSION
calcnb/
├── statement.lua    # CHANGED: adapter over parser; RESERVED derived from the registry; same output shape as today
├── runner.lua       # CHANGED: multi-parameter functions, relation results, reserved-command message
├── env.lua          # CHANGED: functions hold a parameter list
└── shortcuts.lua    # CHANGED: command list and groups derived from the registry
spec/
├── calccas/
│   ├── conformance_spec.lua       # NEW: data-driven, one case per grammar production and rule
│   ├── conformance_cases.lua      # NEW: the cases (source, expected AST dump or error kind + message fragment)
│   └── registry_spec.lua          # NEW: drift test (SC-008)
├── calcnb/compat_spec.lua         # NEW: old-notebook corpus (US4)
└── (existing specs)               # parser_spec, statement_spec, shortcuts_spec updated only for listed rows
docs/language/                     # NEW (shipped docs): reference-1.0.md, grammar.md, errors.md, future.md
README.md                          # CHANGED: language section points at docs/language/reference-1.0.md
```

**Structure Decision**: keep the three-layer split from 002 (`calcnb/` pure, engines `calccas/`, UI `calcui/`). Syntax
belongs to `calccas/`; `calcnb/` only classifies results for the notebook. `docs/language/` is new so the shipped plugin
carries its own reference; the spec folder keeps the contracts as the design record and `docs/language/` is generated by
copying them at implementation time, not rewritten.

## Complexity Tracking

No constitution violations. Nothing to justify.
