# Contract: Keyboard Layout and Shortcuts

## Pages (portrait, full)

Letters: shortcut row (`sin cos tan sqrt` + `expand plot` when supported, 6 keys max, group switch `▸` pages the row),
digits `1-0`, `q-p`, `a-l`, `Shift z-m ⌫`, operators `( ) [ ] ^ * / + - =`, editing row `Sym , ← Space → . ⏎`.
Shift: one-shot capitals (tap again cancels; long-press lock is not used, FR-019 allows it as optional).
Symbols: `{ } < > <= >= == != % _ : ; | & ! ? \ " ' @ # $ pi ∞`, plus navigation row `Home End ↑ ↓ Del`, plus
`All Copy Cut Paste`. `∞` is shown only if the engine has an infinity constant (not in 001), so it is omitted.

Compact (width < ~480 px): the shortcut row shows 4 keys, the operator row moves `[ ] =` to the symbol page, nothing is
removed from the union of pages.

## Key semantics

| Key | Effect |
|-----|--------|
| character | `editor:addChars(insert)` |
| shortcut | `addChars(name .. "()")` then `leftChar` once; never runs the cell |
| `pi` | inserts `pi` |
| Enter | `addChars("\n")` (never runs) |
| Backspace / Del | `delChar` / `delNextChar` |
| ← → ↑ ↓ Home End | `leftChar rightChar upLine downLine goToStartOfLine goToEndOfLine` |
| All / Copy / Cut / Paste | selection and `Device.input.get/setClipboardText` through the editor |

## Invariants (tested without KOReader)

1. Every ASCII printable character except `` ` `` and `~` appears on some page without long-press.
2. No shortcut name outside `calccas.functions()` + runner commands appears.
3. For every shortcut: `insert` ends with `()` and `back == 1`.
4. No key has `insert` containing a newline except Enter.
