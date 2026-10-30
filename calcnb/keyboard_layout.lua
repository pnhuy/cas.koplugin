-- Key pages for the programming keyboard (contracts/keyboard-layout.md). Pure
-- data: a key is `{label, insert[, back]}` or `{label, action}`. The compact
-- layout moves `[ ] =` to the symbol page and keeps the union of keys.

local M = {}

local COMPACT_WIDTH = 480

function M.is_compact(width)
    return width < COMPACT_WIDTH
end

local function ch(c)
    return { label = c, insert = c }
end

local function act(label, action)
    return { label = label, action = action }
end

local function chars(s)
    local row = {}
    for c in s:gmatch(".") do
        row[#row + 1] = ch(c)
    end
    return row
end

local function append(row, tail)
    for _, key in ipairs(tail) do
        row[#row + 1] = key
    end
    return row
end

local function letter_page(upper, compact)
    local function case(s)
        return upper and s:upper() or s
    end
    local row4 = { act("⇧", "shift") }
    append(row4, chars(case("zxcvbnm")))
    row4[#row4 + 1] = act("⌫", "backspace")
    local ops = compact and "()^*/+-" or "()[]^*/+-="
    return {
        chars("1234567890"),
        chars(case("qwertyuiop")),
        chars(case("asdfghjkl")),
        row4,
        chars(ops),
        { act("Sym", "sym"), ch(","), act("←", "left"), act("Space", "space"), act("→", "right"),
          ch("."), act("⏎", "enter") },
    }
end

local function symbol_page()
    return {
        { ch("{"), ch("}"), ch("<"), ch(">"), { label = "<=", insert = "<=" }, { label = ">=", insert = ">=" },
          { label = "==", insert = "==" }, { label = "!=", insert = "!=" } },
        chars("%_:;|&!?"),
        append(chars("[]=\\\"'@#$"), { { label = "π", insert = "pi" } }),
        { act("Home", "home"), act("End", "end"), act("↑", "up"), act("↓", "down"), act("Del", "delete") },
        { act("All", "select_all"), act("Copy", "copy"), act("Cut", "cut"), act("Paste", "paste") },
        { act("ABC", "sym"), act("⌫", "backspace"), act("Space", "space"), act("⏎", "enter") },
    }
end

function M.pages(compact)
    return {
        letters = letter_page(false, compact),
        shift = letter_page(true, compact),
        symbols = symbol_page(),
    }
end

-- One row of shortcut keys for a slide from calcnb.shortcuts, ending with the
-- group switch.
function M.shortcut_row(slide)
    local row = {}
    for _, it in ipairs(slide.items) do
        row[#row + 1] = { label = it.label, insert = it.insert, back = it.back }
    end
    row[#row + 1] = { label = slide.label .. " ▸", action = "group" }
    return row
end

-- Shortcut keys per slide, excluding the group switch.
function M.shortcut_slots(compact)
    return compact and 3 or 5
end

return M
