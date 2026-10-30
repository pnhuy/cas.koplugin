# Quickstart: verifying the expression language

Run from the repository root.

## Automated

```sh
export PATH=$HOME/.luarocks-luajit/bin:$PATH
busted
luacheck --no-color main.lua _meta.lua calccas.lua calcplot.lua calccas calcplot calcnb calcui spec
```

Expected after implementation: all specs pass, including `spec/calccas/conformance_spec.lua` (every grammar production
covered), `spec/calccas/registry_spec.lua` (no list drift) and `spec/calcnb/compat_spec.lua` (old corpus). Report the real
counts; do not quote the 002 baseline (641 passes).

## By hand in the notebook (emulator)

Before launching: `pkill -f koreader-emulator; sleep 1`.

| Type in a cell | Expected |
|----------------|----------|
| `simplify(2*x + 3*x)` | `5*x` |
| `-2^2` / `2^3^2` / `2^-1` | `-4` / `512` / `1/2` |
| `1e3` / `1e-3` | `1000` / `1/1000` |
| `2x` | error: missing `*`: write `2*x` |
| `a = 2` newline `a^2` | `4` |
| `f(x, y) = x*y` newline `f(3, 4)` | `12` |
| `x == 1` | `x == 1` (not true/false) |
| `1 + 2 # note` | `3` |
| `1 +` newline `2` | `3` (trailing operator continues) |
| `plot(sin(x), x=-2*pi..2*pi)` | graph |
| `x=-5..5` alone | error: a range is only allowed as the last argument of plot |
| `diff(x^2, x)` | error: `diff` is reserved for a future version |
| `diff = 3` | error: name is reserved |

## Safety check

`os.execute("x")`, `load("x")` and `1e999999999` produce errors quickly and run nothing (covered by the fuzz spec).

## Results (recorded 2026-10-30)

### Automated

- `busted`: 848 successes / 0 failures / 0 errors / 0 pending.
- `luacheck --no-color main.lua _meta.lua calccas.lua calcplot.lua calccas calcplot calcnb calcui spec`: 0 warnings / 0 errors in 99 files.
- Conformance, registry, compatibility, numbers, docs and fuzz specs are all part of that run.

### Parse timing (SC-009)

LuaJIT 2.1 on the development Mac, `os.clock`, 200 repetitions, one cell of 50 lines of about 490 characters each (24,540
characters, the worst case the limits allow), lexing and parsing every statement, no evaluation. The "before" tree is
`git archive HEAD` (commit `fe52281`) extracted into a scratch directory; the "after" tree is the working tree.

| Tree | Per cell |
|------|----------|
| before (fe52281) | 20.95 ms |
| after (language 1.0) | 29 to 34 ms over three runs (31.31 ms in the first) |

Parsing a worst-case cell costs about 10 ms more on this machine (roughly 1.5 times). A typical cell is a few short lines and
is unaffected in practice. **This is a desktop number; no timing was taken on an e-reader.**

### Quickstart rows through the notebook runner (not the emulator)

Each row below was run with `calcnb.runner.run` in a fresh environment; every one gave the expected result and took
under 1 ms.

| Row | Actual |
|-----|--------|
| `simplify(2*x + 3*x)` | `5*x` (via the compatibility corpus) |
| `-2^2`, `2^3^2`, `2^-1` | `-4`, `512`, `1/2` |
| `1e3`, `1e-3` | `1000`, `1/1000` |
| `2x` | error: ``missing `*`: write `2*x` `` |
| `a = 2` newline `a^2` | `4` |
| `f(x, y) = x*y` newline `f(3, 4)` | `12` |
| `x == 1` | `x == 1` |
| `1 + 2 # note` | `3` |
| `1 +` newline `2` | `3` |
| `plot(sin(x), x=-2*pi..2*pi)` | graph |
| `x=-5..5` | error: a range is only allowed as the last argument of plot |
| `diff(x^2, x)` | error: reserved for a future version |
| `diff = 3` | error: `Name is reserved: diff` |
| `os.execute("x")`, `load("x")`, `1e999999999` | errors (`unexpected character '.'`, ``unknown function `load` ``, `number is too large`) |

### Emulator (T038)

**Not run, unverified.** The rows above were exercised through the runner, not by typing into the KOReader emulator, so what
the on-screen keyboard, cell display and graph viewer show for them has not been checked in this feature.
