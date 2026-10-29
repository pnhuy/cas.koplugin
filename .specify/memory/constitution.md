<!--
Sync Impact Report
Version change: (template, unversioned) → 1.0.0
Modified principles: none renamed (initial ratification)
Added sections: Core Principles I–IX, Platform & Technology Constraints, Development Workflow, Governance
Removed sections: none
Templates:
  ✅ .specify/templates/tasks-template.md (test tasks now required for business logic, per Principle VI)
  ✅ .specify/templates/plan-template.md (Constitution Check gate is generic; no change needed)
  ✅ .specify/templates/spec-template.md (no change needed)
Follow-up TODOs:
  - TODO(MIN_KOREADER_VERSION): declare the minimum supported KOReader version in the
    first feature plan and README (Principle VII).
-->
# Calculator KOReader Plugin Constitution

## Core Principles

### I. KOReader-Native Development
- The plugin MUST follow KOReader's official plugin architecture, conventions, and lifecycle.
- Code MUST be Lua compatible with KOReader's LuaJIT runtime.
- Existing KOReader APIs, widgets, utilities, and services MUST be preferred over custom
  implementations.
- The plugin MUST use the standard `.koplugin` directory structure with `main.lua` and `_meta.lua`.
- Menu integration, event handling, configuration, and UI management MUST follow KOReader's
  established patterns.
- KOReader core source MUST NOT be modified unless explicitly required and justified.
- APIs MUST be verified against the target KOReader source version; methods MUST NOT be
  invented or assumed to exist.

### II. Simplicity and Maintainability
- KISS, DRY, and YAGNI apply: prefer simple, readable, idiomatic Lua over clever abstractions.
- Only functionality required by the specification MUST be implemented.
- Unnecessary dependencies, frameworks, design patterns, and configuration options MUST be avoided.
- Business logic, UI, persistence, and external integrations SHOULD be separated when beneficial.
- Each module MUST have one responsibility.
- Premature optimization and abstractions for hypothetical future requirements are prohibited.

### III. Performance and Resource Efficiency
- Code MUST be optimized for resource-constrained e-readers (CPU, memory, battery).
- Unnecessary background processing, polling, network requests, and filesystem operations
  MUST be avoided.
- Long-running operations MUST NOT block KOReader's UI event loop.
- Screen refreshes MUST be minimized, especially on E Ink devices.
- Expensive resources MUST be initialized lazily and released when no longer needed.
- Large datasets or files MUST NOT be loaded into memory unnecessarily.
- Complex optimizations MUST be preceded by measurement.

### IV. User Experience Consistency
- The UI MUST use KOReader's existing widgets and interaction patterns.
- The plugin MUST respect KOReader's themes, typography, screen sizes, and input methods.
- Touch interaction and hardware buttons MUST both be supported where applicable.
- Interfaces MUST stay simple and usable on small E Ink screens.
- Operations, errors, and important state changes MUST give clear feedback.
- Unnecessary dialogs, notifications, and interruptions during reading MUST be avoided.
- User-facing text MUST use KOReader's localization infrastructure.

### V. Reliability and Data Safety
- The plugin MUST NOT corrupt or unintentionally overwrite user books, annotations, reading
  progress, or settings.
- External inputs MUST be validated and expected failures handled gracefully.
- KOReader's established persistence mechanisms MUST be used where applicable, and settings
  MUST remain consistent across restarts.
- Destructive operations MUST have appropriate safeguards.
- Interrupted operations, unavailable networks, and missing files MUST be handled.
- Important user data MUST NOT be silently discarded.
- Credentials and sensitive information MUST NOT be stored in logs.

### VI. Testing and Verification
- Meaningful business logic, data transformations, and error handling MUST have automated tests.
- Modules SHOULD minimize dependencies on KOReader's UI runtime so they remain testable.
- Tests MUST use tooling compatible with KOReader: Busted for tests and Luacheck for linting.
- Tests MUST cover both successful operations and realistic failure scenarios.
- KOReader integration behavior SHOULD be verified where practical.
- Functionality MUST NOT be claimed as tested unless the relevant tests were actually executed.
- Every bug fix SHOULD include a regression test when feasible.
- Tests MUST be simple, deterministic, and maintainable.

### VII. Compatibility and Dependencies
- External dependencies MUST be minimized; libraries distributed with KOReader are preferred.
- The plugin MUST be compatible with the declared minimum supported KOReader version.
- Platform-specific assumptions MUST be avoided unless explicitly required.
- Unavailable optional device capabilities MUST be handled gracefully, using feature detection
  where practical rather than assumptions.
- Platform restrictions and external dependencies MUST be documented.

### VIII. Documentation and Code Quality
- A README MUST explain the plugin's purpose, installation, configuration, and usage.
- Non-obvious design decisions and KOReader-specific behavior MUST be documented.
- Names MUST be descriptive and functions small and focused.
- Naming, formatting, and error-handling MUST follow patterns used in the KOReader codebase.
- Redundant comments that merely repeat the code MUST be avoided.
- Documentation MUST be kept synchronized with implemented behavior.
- Unnecessary documentation and boilerplate MUST NOT be generated.

### IX. Incremental Development
- Features MUST be implemented in small, independently verifiable increments.
- A minimal working plugin MUST be delivered before advanced functionality is added.
- Existing working behavior MUST be preserved unless changes are explicitly required.
- Unrelated refactoring MUST NOT be mixed into feature work.
- Changes MUST stay focused and easy to review.
- Speculative features beyond the approved specification MUST NOT be added.

## Platform & Technology Constraints

- Language: Lua (LuaJIT, as bundled with KOReader). Tooling: Busted, Luacheck.
- Deliverable: a `calculator.koplugin` directory installable into KOReader's `plugins/` folder.
- Minimum supported KOReader version: TODO(MIN_KOREADER_VERSION) — MUST be declared in the first
  feature plan and the README before release.

## Development Workflow

- Work flows through Spec Kit: specification → plan → tasks → implementation.
- Every plan MUST include a Constitution Check evaluating the relevant principles before
  research and again after design.
- Reviews MUST verify compliance with this constitution; complexity and deviations MUST be
  justified in the plan's Complexity Tracking section.

## Governance

- This constitution applies to every feature specification, implementation plan, and
  development task.
- Any exception MUST be explicitly justified and documented in the relevant plan.
- The implementation plan MUST evaluate relevant constitution principles before development.
- Amendments MUST be versioned and documented via the Sync Impact Report, using semantic
  versioning: MAJOR for incompatible principle removals or redefinitions, MINOR for added or
  materially expanded principles, PATCH for clarifications and wording.
- The simplest solution that satisfies the specification while respecting these principles
  MUST be preferred.
- When principles conflict, priority is: (1) data safety and correctness, (2) KOReader
  compatibility, (3) user experience, (4) performance, (5) implementation simplicity.

**Version**: 1.0.0 | **Ratified**: 2026-10-29 | **Last Amended**: 2026-10-29
