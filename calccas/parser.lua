-- Recursive-descent parser for the grammar in contracts/cas-api.md.
-- Never throws: every failure is returned as `nil, err`. Internally errors are
-- raised as typed error tables and unwound with pcall.
--
-- Behaviors worth knowing:
--   * `-2^2` is -4 and `2^3^2` is 512 (unary minus binds looser than `^`,
--     which is right-associative).
--   * Implicit multiplication applies only after a number or `)` when
--     followed by an identifier or `(` (and `)` before a number). `1/2x` is
--     therefore (1/2)*x, evaluated left to right.
--   * `ln` is stored as `log` (both are the natural logarithm).

local errors = require("calccas.errors")
local ast = require("calccas.ast")
local lexer = require("calccas.lexer")
local limits = require("calccas.limits")
local R = require("calccas.rational")

local M = {}

local FUNCTIONS = {
    sin = "sin", cos = "cos", tan = "tan", exp = "exp",
    log = "log", ln = "log", sqrt = "sqrt", abs = "abs",
}

local CONSTANTS = { pi = true, e = true }

local function fail(kind, message, pos)
    error(errors.new(kind, message, pos), 0)
end

local function describe(tok)
    if tok.type == "eof" then
        return "end of expression"
    elseif tok.type == "num" then
        return "number '" .. tok.text .. "'"
    end
    return "'" .. tok.text .. "'"
end

local function number_node(tok)
    local r, kind = R.from_decimal(tok.text)
    if r then
        return ast.from_rational(r)
    end
    if kind == "overflow" then
        local v = tonumber(tok.text)
        if v == math.huge then
            fail("overflow", "number is too large", tok.pos)
        end
        return ast.float(v)
    end
    fail("syntax", "invalid number '" .. tok.text .. "'", tok.pos)
end

local function parse_tokens(tokens, lim)
    local i, depth = 1, 0

    local function peek()
        return tokens[i]
    end

    local function advance()
        local tok = tokens[i]
        i = i + 1
        return tok
    end

    local function is_op(tok, ...)
        if tok.type ~= "op" then
            return false
        end
        for _, c in ipairs({ ... }) do
            if tok.text == c then
                return true
            end
        end
        return false
    end

    local function expect_rparen()
        local tok = peek()
        if tok.type ~= "rparen" then
            fail("syntax", "expected ')' but found " .. describe(tok), tok.pos)
        end
        advance()
    end

    local parse_expr, parse_unary

    local function parse_atom()
        local tok = advance()
        if tok.type == "num" then
            return number_node(tok)
        elseif tok.type == "ident" then
            local fname = FUNCTIONS[tok.text]
            local nxt = peek()
            if fname then
                if nxt.type ~= "lparen" then
                    fail("syntax", "expected '(' after '" .. tok.text .. "'", nxt.pos)
                end
                advance()
                local arg = parse_expr()
                expect_rparen()
                return ast.fn(fname, arg)
            end
            local user = nxt.type == "lparen" and lim.user_funcs and lim.user_funcs[tok.text]
            if user then
                advance()
                local arg = parse_expr()
                expect_rparen()
                local call = ast.substitute(user.body, user.param, arg)
                if ast.count(call) > lim.max_nodes then
                    fail("too_complex", "expression has too many parts", tok.pos)
                end
                return call
            end
            if nxt.type == "lparen" then
                fail("syntax", "unknown function '" .. tok.text .. "'", tok.pos)
            end
            if CONSTANTS[tok.text] then
                return ast.const(tok.text)
            end
            return ast.var(tok.text)
        elseif tok.type == "lparen" then
            local inner = parse_expr()
            expect_rparen()
            return inner
        end
        fail("syntax", "unexpected " .. describe(tok), tok.pos)
    end

    local function parse_power()
        local base = parse_atom()
        if is_op(peek(), "^") then
            advance()
            return ast.pow(base, parse_unary())
        end
        return base
    end

    function parse_unary()
        depth = depth + 1
        if depth > lim.max_depth then
            fail("too_complex", "expression is nested too deeply", peek().pos)
        end
        local result
        local tok = peek()
        if is_op(tok, "-") then
            advance()
            result = ast.neg(parse_unary())
        elseif is_op(tok, "+") then
            advance()
            result = parse_unary()
        else
            result = parse_power()
        end
        depth = depth - 1
        return result
    end

    local function starts_implicit_factor()
        local prev, cur = tokens[i - 1], peek()
        if prev.type == "num" then
            return cur.type == "ident" or cur.type == "lparen"
        elseif prev.type == "rparen" then
            return cur.type == "ident" or cur.type == "lparen" or cur.type == "num"
        end
        return false
    end

    local function parse_term()
        local factors = { parse_unary() }
        while true do
            local tok = peek()
            if is_op(tok, "*") then
                advance()
                factors[#factors + 1] = parse_unary()
            elseif is_op(tok, "/") then
                advance()
                factors[#factors + 1] = ast.pow(parse_unary(), ast.num(-1))
            elseif starts_implicit_factor() then
                factors[#factors + 1] = parse_unary()
            else
                break
            end
        end
        return ast.mul(factors)
    end

    function parse_expr()
        local terms = { parse_term() }
        while is_op(peek(), "+", "-") do
            local op = advance().text
            local term = parse_term()
            terms[#terms + 1] = op == "-" and ast.neg(term) or term
        end
        return ast.add(terms)
    end

    if peek().type == "eof" then
        fail("syntax", "empty expression", 1)
    end
    local node = parse_expr()
    local rest = peek()
    if rest.type ~= "eof" then
        fail("syntax", "unexpected " .. describe(rest), rest.pos)
    end
    if ast.count(node) > lim.max_nodes then
        fail("too_complex", "expression has too many parts", 1)
    end
    return node
end

-- `overrides` may replace individual limits (used by tests and callers that
-- need tighter bounds). `overrides.user_funcs` maps a name to `{param, body}`;
-- a call `name(arg)` then parses to `body` with `param` replaced by `arg`.
function M.parse(text, overrides)
    if type(text) ~= "string" then
        return nil, errors.new("syntax", "expression must be text")
    end
    local lim = setmetatable(overrides or {}, { __index = limits })
    if #text > lim.max_chars then
        return nil, errors.new("too_complex",
            "expression is longer than " .. lim.max_chars .. " characters")
    end
    local tokens, err = lexer.tokenize(text)
    if not tokens then
        return nil, err
    end
    local ok, result = pcall(parse_tokens, tokens, lim)
    if ok then
        return result
    end
    if errors.is(result) then
        return nil, result
    end
    return nil, errors.new("internal", tostring(result))
end

return M
