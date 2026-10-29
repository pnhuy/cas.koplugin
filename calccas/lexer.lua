-- Tokenizer. Positions are 1-based byte offsets into the input text.
-- Only the characters of the expression grammar are accepted, so input such
-- as `os.execute("x")` fails with a syntax error instead of reaching any
-- interpreter.

local errors = require("calccas.errors")

local M = {}

local OPERATORS = { ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["^"] = true }

function M.tokenize(text)
    local tokens = {}
    local i, n = 1, #text
    while i <= n do
        local c = text:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c:match("[0-9]") or (c == "." and text:sub(i + 1, i + 1):match("[0-9]")) then
            local s, e = text:find("^[0-9]+%.[0-9]+", i)
            if not s then
                s, e = text:find("^[0-9]+", i)
            end
            if not s then
                s, e = text:find("^%.[0-9]+", i)
            end
            tokens[#tokens + 1] = { type = "num", text = text:sub(s, e), pos = i }
            i = e + 1
        elseif c:match("[A-Za-z]") then
            local _, e = text:find("^[A-Za-z][A-Za-z0-9_]*", i)
            tokens[#tokens + 1] = { type = "ident", text = text:sub(i, e), pos = i }
            i = e + 1
        elseif OPERATORS[c] then
            tokens[#tokens + 1] = { type = "op", text = c, pos = i }
            i = i + 1
        elseif c == "(" then
            tokens[#tokens + 1] = { type = "lparen", text = c, pos = i }
            i = i + 1
        elseif c == ")" then
            tokens[#tokens + 1] = { type = "rparen", text = c, pos = i }
            i = i + 1
        else
            return nil, errors.new("syntax", "unexpected character '" .. c .. "'", i)
        end
    end
    tokens[#tokens + 1] = { type = "eof", text = "", pos = n + 1 }
    return tokens
end

return M
