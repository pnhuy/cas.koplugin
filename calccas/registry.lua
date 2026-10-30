-- The one list of functions, commands and constants (contracts/registry.md).
-- The parser, evaluator, notebook layer and keyboard read their names from here.
-- `reserved` entries are claimed for a future version: they cannot be used as
-- variable names and evaluating one is an `unsupported` error.

local M = {}

-- Display order matters: the keyboard offers entries in this order.
-- args: "expr" = expressions; "expr-range" = a trailing range argument is allowed;
--       "expr-symbol" = the second argument names a symbol.
local ENTRIES = {
    { name = "sin", kind = "function", arity = { 1, 1 }, status = "implemented", args = "expr", group = "common" },
    { name = "cos", kind = "function", arity = { 1, 1 }, status = "implemented", args = "expr", group = "common" },
    { name = "tan", kind = "function", arity = { 1, 1 }, status = "implemented", args = "expr", group = "common" },
    { name = "sqrt", kind = "function", arity = { 1, 1 }, status = "implemented", args = "expr", group = "common" },
    { name = "plot", kind = "command", arity = { 1, 6 }, status = "implemented", args = "expr-range", group = "common" },
    { name = "abs", kind = "function", arity = { 1, 1 }, status = "implemented", args = "expr", group = "basic" },
    { name = "exp", kind = "function", arity = { 1, 1 }, status = "implemented", args = "expr", group = "basic" },
    { name = "log", kind = "function", arity = { 1, 1 }, status = "implemented", args = "expr", group = "basic" },
    { name = "ln", kind = "function", arity = { 1, 1 }, status = "implemented", args = "expr", group = "basic", alias_of = "log" },
    { name = "simplify", kind = "command", arity = { 1, 1 }, status = "implemented", args = "expr", group = "algebra" },
    { name = "expand", kind = "command", arity = { 1, 1 }, status = "implemented", args = "expr", group = "algebra" },
    { name = "pi", kind = "constant", arity = { 0, 0 }, status = "implemented", args = "expr", group = "constants" },
    { name = "e", kind = "constant", arity = { 0, 0 }, status = "implemented", args = "expr", group = "constants" },
    { name = "factor", kind = "command", arity = { 1, 1 }, status = "reserved", args = "expr", group = "algebra" },
    { name = "solve", kind = "command", arity = { 1, 2 }, status = "reserved", args = "expr-symbol", group = "algebra" },
    { name = "subs", kind = "command", arity = { 2, 8 }, status = "reserved", args = "expr", group = "algebra" },
    { name = "approx", kind = "command", arity = { 1, 1 }, status = "reserved", args = "expr", group = "algebra" },
    { name = "diff", kind = "command", arity = { 1, 2 }, status = "reserved", args = "expr-symbol", group = "calculus" },
    { name = "integrate", kind = "command", arity = { 1, 2 }, status = "reserved", args = "expr-symbol", group = "calculus" },
}

M.VERSION = "1.0"

local BY_NAME = {}
for _, entry in ipairs(ENTRIES) do
    entry.since = "1.0"
    BY_NAME[entry.name] = entry
end

-- The entries in display order. The list and its entries are shared; callers must not modify them.
function M.entries()
    return ENTRIES
end

-- Entry for a name, or nil. Entries are shared; callers must not modify them.
function M.get(name)
    return BY_NAME[name]
end

function M.is_reserved(name)
    return BY_NAME[name] ~= nil
end

-- Canonical implementation name of an implemented function (`ln` -> `log`), else nil.
function M.canonical(name)
    local entry = BY_NAME[name]
    if entry and entry.kind == "function" and entry.status == "implemented" then
        return entry.alias_of or entry.name
    end
    return nil
end

local function collect(pred)
    local list = {}
    for _, entry in ipairs(ENTRIES) do
        if pred(entry) then
            list[#list + 1] = entry.name
        end
    end
    return list
end

local function implemented_function(entry)
    return entry.kind == "function" and entry.status == "implemented"
end

-- Sorted names of the implemented functions, aliases included.
function M.functions()
    local list = collect(implemented_function)
    table.sort(list)
    return list
end

-- Set of the same names, for lookups.
function M.function_set()
    local set = {}
    for _, name in ipairs(M.functions()) do
        set[name] = true
    end
    return set
end

-- Sorted names that need an implementation (aliases excluded).
function M.canonical_functions()
    local list = collect(function(e) return implemented_function(e) and not e.alias_of end)
    table.sort(list)
    return list
end

-- Implemented commands in keyboard order.
function M.commands()
    return collect(function(e) return e.kind == "command" and e.status == "implemented" end)
end

-- Implemented names (functions and commands) of a keyboard group, in order.
function M.group(group)
    return collect(function(e)
        return e.group == group and e.status == "implemented" and e.kind ~= "constant"
    end)
end

-- Sorted list of every reserved name.
function M.reserved_names()
    local list = collect(function() return true end)
    table.sort(list)
    return list
end

-- Fresh set of every reserved name.
function M.reserved_set()
    local set = {}
    for name in pairs(BY_NAME) do
        set[name] = true
    end
    return set
end

return M
