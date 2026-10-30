-- Prefix completion for the cell editor: finds the word at the cursor, ranks
-- the names that start with it, and builds the text edit for a chosen one.
-- Pure Lua: no UI class, no evaluation, no I/O. Positions are 1-based UTF-8
-- character positions, as `charpos` is in KOReader's InputText.

local builtin_docs = require("calccas.builtin_docs")
local registry = require("calccas.registry")

local M = {}

local DEFAULT_LIMIT = 6

local WORD = "[A-Za-z0-9_]"

-- Byte offset where character `charpos` starts, or `#text + 1` at the end;
-- nil when `charpos` is not a position in the text.
local function byte_of(text, charpos)
    if type(charpos) ~= "number" or charpos < 1 or charpos % 1 ~= 0 then
        return nil
    end
    local count, i, n = 1, 1, #text
    while count < charpos do
        if i > n then
            return nil
        end
        i = i + 1
        while i <= n do
            local b = text:byte(i)
            if b < 0x80 or b >= 0xC0 then
                break
            end
            i = i + 1
        end
        count = count + 1
    end
    return i
end

-- Parentheses still open at the end of `text`, comments left out.
local function open_depth(text)
    local depth = 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local code = line:gsub("#.*$", "")
        for c in code:gmatch("[()]") do
            depth = depth + (c == "(" and 1 or -1)
        end
    end
    return depth
end

-- The word the cursor is in or at the end of, or nil when no completion
-- applies (nothing typed, a comment, a number, a plot range variable).
-- Returns `{ prefix, first, last, line }`: `prefix` is the part before the
-- cursor, `first..last` the character range of the whole word.
function M.word_at(text, charpos)
    if type(text) ~= "string" then
        return nil
    end
    local at = byte_of(text, charpos)
    if not at then
        return nil
    end
    local before = text:sub(1, at - 1)
    local line_before = before:match("[^\n]*$")
    if line_before:find("#", 1, true) then
        return nil
    end
    local prefix = line_before:match(WORD .. "*$")
    if prefix == "" or not prefix:find("^[A-Za-z]") then
        return nil
    end
    local tail = text:match("^" .. WORD .. "*", at)
    local rest = text:sub(at + #tail)
    if rest:find("^[ \t]*=") and not rest:find("^[ \t]*==") and open_depth(before:sub(1, #before - #prefix)) > 0 then
        return nil
    end
    local line = select(2, before:gsub("\n", "")) + 1
    local first = charpos - #prefix
    return { prefix = prefix, first = first, last = first + #prefix + #tail - 1, line = line }
end

-- Number of UTF-8 characters in `s`.
local function char_count(s)
    return select(2, s:gsub("[^\128-\191]", ""))
end

local function builtin_item(entry)
    local callable = entry.kind ~= "constant"
    return {
        name = entry.name,
        source = "builtin",
        kind = entry.kind,
        available = entry.status == "implemented",
        insert = callable and entry.name .. "()" or entry.name,
        back = callable and 1 or 0,
        doc = builtin_docs.get(entry.name),
    }
end

local function user_item(def)
    local callable = def.kind == "func"
    return {
        name = def.name,
        source = "user",
        kind = def.kind,
        available = true,
        insert = callable and def.name .. "()" or def.name,
        back = callable and 1 or 0,
        params = def.params,
    }
end

-- Rank: exact match, then available built-ins, then user names, then
-- reserved commands; then shorter names; then alphabetical.
local function rank(item, prefix)
    local group = 2
    if item.source == "builtin" then
        group = item.available and 1 or 3
    end
    return item.name:lower() == prefix and 0 or group
end

-- Candidates whose name starts with `prefix` (any case): the registry plus
-- `names` (the defined names of the notebook: `{ name, kind, params }`).
-- Returns `{ items, more }`; `more` counts the matches left out by `opts.limit`.
function M.suggest(prefix, names, opts)
    if type(prefix) ~= "string" or prefix == "" then
        return { items = {}, more = 0 }
    end
    local limit = opts and tonumber(opts.limit) or DEFAULT_LIMIT
    local lowered = prefix:lower()
    local found = {}
    local function consider(item)
        if item.name:sub(1, #lowered):lower() == lowered then
            found[#found + 1] = item
        end
    end
    for _, entry in ipairs(registry.entries()) do
        consider(builtin_item(entry))
    end
    for _, def in ipairs(type(names) == "table" and names or {}) do
        if type(def) == "table" and type(def.name) == "string" and (def.kind == "var" or def.kind == "func") then
            consider(user_item(def))
        end
    end
    local keys = {}
    for _, item in ipairs(found) do
        keys[item] = rank(item, lowered)
    end
    table.sort(found, function(a, b)
        if keys[a] ~= keys[b] then
            return keys[a] < keys[b]
        end
        if #a.name ~= #b.name then
            return #a.name < #b.name
        end
        return a.name < b.name
    end)
    local items = {}
    for i = 1, math.min(#found, limit) do
        items[i] = found[i]
    end
    return { items = items, more = #found - #items }
end

-- The edit that replaces `word` (from `word_at`) in `text` with the
-- suggestion: `{ text, insert, charpos, first, last }`. Text outside the replaced
-- range is unchanged; the cursor goes `suggestion.back` characters before the
-- end of the insert. nil when the word does not fit the text.
function M.apply(text, word, suggestion)
    if type(text) ~= "string" or type(word) ~= "table" or type(suggestion) ~= "table" then
        return nil
    end
    local insert = suggestion.insert
    if type(insert) ~= "string" or type(word.first) ~= "number" or type(word.last) ~= "number" then
        return nil
    end
    local from = byte_of(text, word.first)
    local to = byte_of(text, word.last + 1)
    if not from or not to or from > to then
        return nil
    end
    return {
        text = text:sub(1, from - 1) .. insert .. text:sub(to),
        insert = insert,
        charpos = word.first + char_count(insert) - (suggestion.back or 0),
        first = word.first,
        last = word.last,
    }
end

return M
