-- Tokenizer (grammar G-01..G-11, G-30..G-33). Positions are 1-based byte
-- offsets into the input text and every token carries its 1-based `line`.
-- Only the characters of the expression grammar are accepted, so input such
-- as `os.execute("x")` fails with a syntax error instead of reaching any
-- interpreter.
--
-- A `newline` token ends a statement. It is emitted only at bracket depth 0
-- and never after a binary operator, `=`, `==` or `,` (the statement
-- continues), and blank or comment-only lines produce none.
--
-- `tokenize(text)` stops at the first bad character and returns `nil, err`.
-- With `{recover = true}` it emits an `error` token instead (the rest of that
-- line is skipped) so a cell can be parsed statement by statement.

local errors = require("calccas.errors")

local M = {}

local OPERATORS = { ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["^"] = true }

-- A line end after one of these token types continues the statement.
local CONTINUES = { op = true, eq = true, eqeq = true, comma = true }

-- `e` is the last byte of the digits. Returns the last byte of the number, and
-- true when a trailing `e` has no exponent digits (`2e`, `2e+`, `2e)`); `2ex`
-- stays the number `2` so the parser can explain the missing `*`.
local function exponent_end(text, e)
    local c = text:sub(e + 1, e + 1)
    if c ~= "e" and c ~= "E" then
        return e
    end
    local _, xe = text:find("^[eE][+-]?[0-9]+", e + 1)
    if xe then
        return xe
    end
    local after = text:sub(e + 2, e + 2)
    if after:match("[A-Za-z0-9_]") then
        return e
    end
    return (after == "+" or after == "-") and e + 2 or e + 1, true
end

function M.tokenize(text, opts)
    local recover = opts and opts.recover
    local tokens = {}
    local i, n, line, depth = 1, #text, 1, 0

    local function push(kind, s, pos)
        tokens[#tokens + 1] = { type = kind, text = s, pos = pos, line = line }
    end

    -- Reports a bad input at `pos`; returns the error when lexing must stop.
    local function problem(message, pos, shown)
        local err = errors.new("syntax", message, pos)
        err.line = line
        if not recover then
            return err
        end
        tokens[#tokens + 1] = { type = "error", text = shown or "", pos = pos, line = line, err = err }
        local stop = text:find("\n", pos, true)
        i = stop or (n + 1)
        return nil
    end

    while i <= n do
        local c = text:sub(i, i)
        local nxt = text:sub(i + 1, i + 1)
        if c == "\n" then
            local last = tokens[#tokens]
            if depth == 0 and last and last.type ~= "newline" and not CONTINUES[last.type] then
                push("newline", "\n", i)
            end
            line = line + 1
            i = i + 1
        elseif c == "#" then
            local stop = text:find("\n", i, true)
            i = stop or (n + 1)
        elseif c:match("%s") then
            i = i + 1
        elseif c == "." and nxt == "." then
            push("dotdot", "..", i)
            i = i + 2
        elseif c:match("[0-9]") or (c == "." and nxt:match("[0-9]")) then
            local s, e = text:find("^[0-9]+%.[0-9]+", i)
            if not s then
                s, e = text:find("^[0-9]+", i)
            end
            if not s then
                s, e = text:find("^%.[0-9]+", i)
            end
            local stop, malformed = exponent_end(text, e)
            if malformed then
                local err = problem("malformed number `" .. text:sub(i, stop) .. "`", i, text:sub(i, stop))
                if err then
                    return nil, err
                end
            else
                push("num", text:sub(s, stop), i)
                i = stop + 1
            end
        elseif c:match("[A-Za-z]") then
            local _, e = text:find("^[A-Za-z][A-Za-z0-9_]*", i)
            push("ident", text:sub(i, e), i)
            i = e + 1
        elseif c == "=" then
            if nxt == "=" then
                push("eqeq", "==", i)
                i = i + 2
            else
                push("eq", "=", i)
                i = i + 1
            end
        elseif OPERATORS[c] then
            push("op", c, i)
            i = i + 1
        elseif c == "(" then
            depth = depth + 1
            push("lparen", c, i)
            i = i + 1
        elseif c == ")" then
            if depth > 0 then
                depth = depth - 1
            end
            push("rparen", c, i)
            i = i + 1
        elseif c == "," then
            push("comma", c, i)
            i = i + 1
        else
            local err = problem("unexpected character '" .. c .. "'", i, c)
            if err then
                return nil, err
            end
        end
    end
    push("eof", "", n + 1)
    return tokens
end

return M
