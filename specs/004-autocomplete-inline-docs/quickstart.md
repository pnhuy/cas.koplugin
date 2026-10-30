# Quickstart: Autocomplete and Inline Documentation

Run from the repository root. Nothing below has been run yet; results are filled in when the feature is implemented.

## Automated

```sh
export PATH=$HOME/.luarocks-luajit/bin:$PATH
busted
luacheck --no-color main.lua _meta.lua calccas.lua calcplot.lua calccas calcplot calcnb calcui spec
```

Expected: the baseline (848 successes, 0 failures, luacheck 0 warnings in 99 files) plus the new specs, with no existing
spec changed except the `runner` and `notebook` rows for `defined`.

| Spec | Proves |
|------|--------|
| `spec/calccas/builtin_docs_spec.lua` | Every registry name documented; examples for implemented names run; reserved examples give `unsupported`; signatures appear in the reference (SC-004) |
| `spec/calcnb/completion_spec.lua` | `dif` offers `diff`; mid-word and mid-text edits keep the surrounding text; 200 randomized edits preserve text outside the range (SC-005); comments, numbers and range variables give no strip; ordering rules |
| `spec/calcui/strip_sizing_spec.lua` | Strip rows (2, 1 or 0) per screen size and orientation; the cursor-line area is never below the minimum (FR-016) |
| `spec/calcnb/completion_session_spec.lua` | Highlight wraps; dismissal holds for the word and clears for a new one; `update` reports no change when nothing changed |
| `spec/calcnb/notebook_spec.lua` | Ledger: define, re-run with a new name drops the old one, a failed run leaves the cell's definitions unchanged, run-all and clear reset it (SC-003) |
| timing guard in `completion_spec.lua` | 100 defined names: one update stays far below the 100 ms budget on the Mac (device figure measured separately) |

## By hand (emulator)

Kill any old emulator first (`pkill -f koreader-emulator; sleep 1`), then launch as in the project notes.

1. Open the notebook, tap a cell, type `dif`. The strip shows `diff()` marked "not available yet". Tap it: the cell reads `diff()`,
   the cursor is between the brackets, no result appears.
2. Type `1 + si + 2`, put the cursor after `si`, tap `sin`: `1 + sin() + 2`, cursor inside the brackets.
3. Cell 1: `rate = 5`, Run. In cell 2 type `ra`: `rate` is offered. Change cell 1 to `speed = 5`, Run: `ra` offers nothing,
   `spe` offers `speed`.
4. Dismiss with `✕`: the text and cursor are unchanged and the strip stays hidden while you finish the word.
5. Rotate: the keyboard and the cursor line stay visible and the strip is still above the keyboard. Also try the smallest
   emulator size if available (the strip may shrink to one row or be off, never cover the cursor line).
6. Watch for page flicker while typing quickly; the page must not repaint, only the strip.
7. On a device or emulator with keys: `PgFwd` moves the highlight, `Press` accepts, `Back` dismisses without closing.

Steps 5, 6 and 7 are the only checks for FR-015 (no page repaint while typing), SC-007, SC-008 and SC-009 (touch alone, physical keys); no automated test covers them, so they stay "unverified" until run.

Record the result of each step, and the device model, in this file under "Results". A step that was not run is marked
"not run, unverified".

## Results

Baseline before this feature (T001): `busted` 848 successes / 0 failures; `luacheck` 0 warnings in 99 files.

After Phase 3 code (US1, T002-T012): `busted` 901 successes / 0 failures; `luacheck` 0 warnings in 105 files.

After Phase 4 code (US2, T014-T017): `busted` 911 successes / 0 failures; `luacheck` 0 warnings in 108 files.

After Phase 5 code (US3, T019-T025): `busted` 927 successes / 0 failures; `luacheck` 0 warnings in 108 files.

After Phase 6 code (US4 and polish, T027-T035): `busted` 935 successes / 0 failures; `luacheck` 0 warnings in 108 files. `grep -rn 'require("ui/' calccas calcnb` is empty. The timing guard (1000 updates, 100 names, under 5 ms each) is a Mac figure; the device figure (SC-011, 100 ms) is not measured.

Emulator run (KOReader desktop emulator, 540x720, 2026-10-30, by the user):
- Step 1 (`dif` shows `diff()*` and "not available yet"; tap inserts it, no result): works.
- Step 2 (`1 + si + 2`, tap `sin`): works.
- Step 3 (`rate = 5`, Run, `ra` offers `rate`): works for the offer. The re-run with `speed = 5` was not reported.
- The documentation row shows signature, summary, "not available yet" and an example on one line: works.
- Step 4 (`✕` dismiss): does NOT work in the emulator; the strip stays. The tap reaches `on_dismiss` and `completion:dismiss()` returns true (seen in the log), so the cause is not found.
- Step 7 (keys): does NOT work in the emulator. Page keys, Tab, Enter (Press) and Esc (Back) did nothing useful. Found and fixed one cause: the strip's ButtonTable is a FocusManager and took Tab and Press, so its key events are now cleared; that fix did not make the keys work. Possibly an emulator key-mapping issue, not confirmed.
- Steps 5 and 6 (rotation and small size, page flicker): not run, unverified.
- Device (E Ink) latency and `MIN_PAGE_LINES = 4`: not run, unverified.

TODO (fix later): `✕` dismiss and the physical-key paths (`CellEditor:onKeyPress` `key_filter`, `NotebookView:strip_key`) are unverified on screen; investigate with logging.
