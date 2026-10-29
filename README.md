# Calculator (KOReader plugin)

Offline algebra calculator and function grapher in native Lua (LuaJIT). No Python, external CAS, browser or network.

Status: MVP in progress. The expression engine (`calccas/`) is implemented and unit-tested. The KOReader UI has
not yet been run in the emulator or on a device.

## Install

Copy or symlink this directory to `<koreader>/plugins/calculator.koplugin`, then restart KOReader. Open
**Tools → Calculator**.

Minimum KOReader version: **v2025.10 (provisional)**. The APIs used were checked by reading KOReader `master`
(commit 54eb77e), not by running older releases.

## Syntax

- Numbers: `3`, `2.5`, `.5`. Operators: `+ - * / ^` and parentheses. `^` is right-associative and binds tighter
  than unary minus: `-2^2 = -4`, `2^3^2 = 512`.
- Implicit multiplication: `2x`, `2(x+1)`, `(x+1)(x-1)`. `1/2x` means `(1/2)*x`.
- Functions: `sin cos tan exp log ln sqrt abs`. Constants: `pi`, `e`.
- Variables: `x=2, y=1/2` in the variables field.
- Input is parsed, never executed as Lua. Limits: 500 characters, nesting depth 50, 2000 nodes.

## Development

```sh
export PATH=$HOME/.luarocks-luajit/bin:$PATH
busted                  # engine tests
luacheck main.lua _meta.lua calccas calcplot calcui spec
```

Engine modules (`calccas/`, `calcplot/`) do not require KOReader; UI code lives in `calcui/` and `main.lua`.
