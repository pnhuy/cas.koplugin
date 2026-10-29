-- Splits a notebook cell into statements (see contracts/notebook-language.md).
-- Pure text classification; nothing is ever passed to load/loadstring.

local limits = require("calccas.limits")

local M = {}

local MAX_NAME = 32
local RESERVED = {
    sin = true, cos = true, tan = true, exp = true, log = true, ln = true, sqrt = true, abs = true,
    pi = true, e = true, plot = true, simplify = true, expand = true,
}

M.RESERVED = RESERVED
M.MAX_NAME = MAX_NAME

local function fail(kind, message, line)
    return nil, { kind = kind, message = message, line = line }
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Returns true, or false plus an error kind and message.
local function check_name(name)
    if not name:match("^[A-Za-z][A-Za-z0-9_]*$") then
        return false, "name", "Invalid name"
    elseif #name > MAX_NAME then
        return false, "name", "Name is longer than " .. MAX_NAME .. " characters"
    elseif RESERVED[name] then
        return false, "reserved", "Name is reserved"
    end
    return true
end

-- Splits on commas that are not inside brackets.
local function split_args(text)
    local args, depth, start = {}, 0, 1
    for i = 1, #text do
        local c = text:sub(i, i)
        if c == "(" then
            depth = depth + 1
        elseif c == ")" then
            depth = depth - 1
        elseif c == "," and depth == 0 then
            args[#args + 1] = trim(text:sub(start, i - 1))
            start = i + 1
        end
    end
    args[#args + 1] = trim(text:sub(start))
    return args
end

local function plot_statement(inner, line)
    local args = split_args(inner)
    local range
    local lo, hi = args[#args]:match("^x%s*=%s*(.-)%.%.(.*)$")
    if lo then
        args[#args] = nil
        lo, hi = trim(lo), trim(hi)
        -- Bounds are plain numbers; the order is checked here, evaluation
        -- of the functions happens in the runner.
        local a, b = tonumber(lo), tonumber(hi)
        if not (a and b and a == a and b == b and a < b) then
            return fail("range", "Invalid range", line)
        end
        range = { lo = lo, hi = hi }
    end
    if #args == 0 or args[1] == "" then
        return fail("syntax", "plot needs at least one function", line)
    end
    for _, a in ipairs(args) do
        if a == "" then
            return fail("syntax", "empty plot argument", line)
        end
    end
    if #args > limits.max_functions then
        return fail("too_complex", "plot takes at most " .. limits.max_functions .. " functions", line)
    end
    return { kind = "plot", args = args, range = range, line = line }
end

local function classify(text, line)
    local inner = text:match("^plot%s*%((.*)%)$")
    if inner then
        return plot_statement(inner, line)
    end

    local fname, param, body = text:match("^([%a][%w_]*)%s*%(%s*([%a][%w_]*)%s*%)%s*=([^=].*)$")
    if not fname then
        fname, param = text:match("^([%a][%w_]*)%s*%(%s*([%a][%w_]*)%s*%)%s*=$")
        body = ""
    end
    if fname then
        local ok, kind, message = check_name(fname)
        if not ok then
            return fail(kind, message, line)
        end
        local pok, pkind, pmessage = check_name(param)
        if not pok and pkind ~= "reserved" then
            return fail(pkind, pmessage, line)
        end
        body = trim(body)
        if body == "" then
            return fail("syntax", "expected an expression after '='", line)
        end
        return { kind = "funcdef", name = fname, param = param, text = body, line = line }
    end

    local name, rhs = text:match("^([%w_]+)%s*=([^=].*)$")
    if not name then
        name = text:match("^([%w_]+)%s*=$")
        rhs = ""
    end
    if name then
        local ok, kind, message = check_name(name)
        if not ok then
            return fail(kind, message, line)
        end
        rhs = trim(rhs)
        if rhs == "" then
            return fail("syntax", "expected an expression after '='", line)
        end
        return { kind = "assign", name = name, text = rhs, line = line }
    end

    -- "sin(x) = 1" style definitions of reserved names.
    local rname = text:match("^([%a][%w_]*)%s*%([^()]*%)%s*=[^=]")
    if rname then
        local _, kind, message = check_name(rname)
        if kind then
            return fail(kind, message, line)
        end
    end

    return { kind = "expr", text = text, line = line }
end

-- Returns a list of statements or `nil, {kind, message, line}`.
function M.parse(source)
    local list = {}
    local line = 0
    for raw in (source .. "\n"):gmatch("([^\n]*)\n") do
        line = line + 1
        local text = trim(raw)
        if text ~= "" and text:sub(1, 1) ~= "#" then
            if #text > limits.max_chars then
                return fail("too_complex", "Statement is longer than " .. limits.max_chars .. " characters", line)
            end
            local stmt, err = classify(text, line)
            if not stmt then
                return nil, err
            end
            list[#list + 1] = stmt
        end
    end
    return list
end

return M
