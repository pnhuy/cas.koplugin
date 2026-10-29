# Quickstart (developer)

## Prerequisites

- LuaJIT 2.1 and Luacheck 1.2 (present). Busted: `brew install luarocks && luarocks install busted`
  (not yet installed here).
- A KOReader checkout or desktop build for the emulator (needed for task T0 API verification and UI testing).

## Run engine tests (no KOReader needed)

```sh
busted            # uses .busted: lpath = ./?.lua;./?/init.lua, runs spec/
luacheck .        # lint
```

## Try the plugin in the emulator

```sh
ln -s "$PWD" /path/to/koreader/plugins/calculator.koplugin
cd /path/to/koreader && ./kodev run
```

In the emulator: open a book → Tools menu → **Calculator**.

## Smoke checklist (maps to MVP acceptance)

1. Tools menu shows **Calculator**.
2. Evaluate `1/3 + 1/6` → `1/2`; `-2^2` → `-4`; `1/0` → division-by-zero message.
3. Simplify `2*x + 3*x` → `5*x`; `expand((x+1)^2)` → `x^2+2*x+1`.
4. Graph → add `sin(x)` and `x^2`; both visible and distinguishable in grayscale.
5. Add `1/x`, `tan(x)`, `1/(x-1)`: no lines across asymptotes. Add `log(x)`, `sqrt(x)`: nothing for undefined x.
6. Range → set Xmin=-5, Xmax=5, Ymin=-2, Ymax=2 → plot updates; Reset restores defaults.
7. Enter `sin(` and `os.execute("x")` → clear error, no crash.
8. Close the plugin → same page, same position, no annotation changes.
9. Rotate the screen → layout adapts.

## Verification notes

- **US1, emulator (2026-10-29)**: KOReader master `54eb77e`, desktop emulator on macOS arm64. Smoke steps 1, 2 and 7 plus
  variables and session persistence checked by hand and reported working. Simplify and Graph show "Coming soon".
  Not yet checked: grayscale/refresh behaviour, orientation, physical keys, or any real device.
- Build notes (macOS): `./kodev build` needs GNU getopt and `flock` (`brew install discoteq/discoteq/flock`). Do not
  put GNU `sed` or GNU binutils ahead of the system tools on `PATH`; they break the LuaJIT patch step and produce
  static libraries that Apple's linker rejects.
- KOReader's plugin `package.path` has `<plugin>/?.lua` but not `?/init.lua`, so the CAS facade is `calccas.lua`.
- **US2, emulator (2026-10-29)**: Simplify button and `expand(...)`/`simplify(...)` wrappers checked by hand and reported
  working: `2*x+3*x` → `5*x`; `x/x` unchanged with `Assuming: x ≠ 0`; `expand((x+1)^2)` → `x^2+2*x+1`;
  `expand((a+b)^3)` → `a^3+3*a^2*b+3*a*b^2+b^3`. Variables are not applied by Simplify.
- **US3, emulator (2026-10-29)**: Graph view checked by hand (quickstart steps 4–6) and reported working: add, edit,
  hide/show and remove functions, `sin(x)` with `x^2`, the asymptote and undefined-domain cases, Range
  and Reset, and returning to the Calculator. A grayscale rendering was only seen in the desktop emulator.
  Not yet checked: grayscale/refresh behaviour on E Ink, orientation, physical keys, or any real device.
- **US4 (partial), emulator (2026-10-29)**: Reported working by hand: Range and Grid survive a full emulator restart,
  and the reading position is unchanged after closing the plugin. No Lua errors or "Internal error" messages in the
  log. Not checked: rotation (the resize handler in the Graph view is untested and the Calculator dialog's
  behaviour is unknown), physical keys, the book's sidecar file and annotations (before/after comparison), and
  real devices. Page-key scrolling is not implemented.
