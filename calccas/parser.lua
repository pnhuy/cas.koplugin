-- Recursive-descent parser for the grammar in docs/language/grammar.md.
-- Never throws: every failure is returned as `nil, err`. Internally errors are
-- raised as typed error tables and unwound with pcall.
--
-- Two entry points:
--   parse(text, overrides)          one expression, relation or command call
--   parse_program(text, overrides)  a whole cell: statements, one per entry
--
-- Behaviors worth knowing:
--   * `-2^2` is -4 and `2^3^2` is 512 (unary minus binds looser than `^`,
--     which is right-associative).
--   * Multiplication is always written: `2x`, `3(x+1)` and `(a)(b)` are
--     syntax errors that name the explicit form (`write 2*x`).
--   * `==` builds a `rel` node and is never reduced to true or false.
--   * `ln` is stored as `log` (both are the natural logarithm).
--   * Calls of user functions are substituted at parse time, so a definition
--     earlier in the same cell is visible to the statements after it.
--   * A statement that fails to parse carries its error (`err`); the parser
--     recovers at the next line end so one bad line does not hide the rest.

local errors = require("calccas.errors")
local ast = require("calccas.ast")
local lexer = require("calccas.lexer")
local limits = require("calccas.limits")
local R = require("calccas.rational")
local registry = require("calccas.registry")

local M = {}

local CONSTANTS = { pi = true, e = true }
local MAX_NAME = 32
local MAX_PARAMS = 4
local MAX_EXPONENT = 400 -- larger exponents are decided without building the power

local RANGE_MESSAGE = "a range such as `x=-5..5` is only allowed as the last argument of plot"
local EQ_MESSAGE = "`=` is only for assignment and definitions; use `==` for an equation"
local RELATION_MESSAGE = "a relation `==` has exactly two sides"

local function fail(kind, message, tok)
    local err = errors.new(kind, message, tok and tok.pos)
    err.line = tok and tok.line
    error(err, 0)
end

local function describe(tok)
    if tok.type == "eof" or tok.type == "newline" then
        return "end of input"
    elseif tok.type == "num" then
        return "number '" .. tok.text .. "'"
    end
    return "'" .. tok.text .. "'"
end

local function shorten(s)
    if #s > 24 then
        return "..." .. s:sub(-21)
    end
    return s
end

-- Exact value of a number token. `1e3` is 1000 and `1e-3` is 1/1000 while the
-- result fits the exact range; otherwise the value is approximate, and a
-- number beyond the range of a double is an overflow error.
local function number_node(tok)
    local text = tok.text
    local mantissa, sign, digits = text:match("^([%d%.]+)[eE]([+-]?)(%d+)$")
    local exponent = 0
    if mantissa then
        exponent = tonumber(digits)
        if sign == "-" then
            exponent = -exponent
        end
    else
        mantissa = text
    end
    local r, kind = R.from_decimal(mantissa)
    if r and r.n == 0 then
        return ast.num(0)
    end
    if r and math.abs(exponent) <= MAX_EXPONENT then
        local power = R.pow_int({ n = 10, d = 1 }, math.abs(exponent))
        if power then
            local scaled = exponent >= 0 and R.mul(r, power) or R.div(r, power)
            if scaled then
                return ast.from_rational(scaled)
            end
        end
    end
    if not r and kind ~= "overflow" then
        fail("syntax", "invalid number '" .. text .. "'", tok)
    end
    -- LuaJIT answers nil for an exponent that does not fit a double.
    local v = tonumber(text)
    if v == nil then
        v = exponent < 0 and 0 or math.huge
    end
    if v == math.huge then
        fail("overflow", "number is too large", tok)
    elseif v == 0 then
        fail("overflow", "number is too small", tok)
    end
    return ast.float(v)
end

-- Replaces every parameter with its argument at once (a parameter name that
-- appears inside an argument must not be substituted again).
local function inline_call(entry, args)
    local params = entry.params or { entry.param }
    local body = entry.body
    for k, p in ipairs(params) do
        body = ast.substitute(body, p, ast.var("\0" .. k))
    end
    for k in ipairs(params) do
        body = ast.substitute(body, "\0" .. k, args[k])
    end
    return body
end

local function make_parser(tokens, text, lim, funcs, known)
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

    local function slice(from, to)
        local last = tokens[to]
        return text:sub(tokens[from].pos, last.pos + #last.text - 1)
    end

    -- Index of the `)` matching the `(` at index `open`, or nil.
    local function matching(open)
        local d = 0
        for j = open, #tokens do
            local t = tokens[j].type
            if t == "lparen" then
                d = d + 1
            elseif t == "rparen" then
                d = d - 1
                if d == 0 then
                    return j
                end
            elseif t == "newline" or t == "eof" then
                return nil
            end
        end
        return nil
    end

    -- Source text of the operand that starts at token `j` (for error hints).
    local function operand_text(j)
        local tok = tokens[j]
        local to = j
        if tok.type == "ident" and tokens[j + 1].type == "lparen" then
            to = matching(j + 1) or (j + 1)
        elseif tok.type == "lparen" then
            to = matching(j) or j
        end
        return slice(j, to)
    end

    local function missing_times(left_from)
        local left = slice(left_from, i - 1)
        local right = operand_text(i)
        fail("syntax", "missing `*`: write `" .. shorten(left) .. "*" .. shorten(right) .. "`", peek())
    end

    local function unexpected(tok)
        if tok.type == "error" then
            error(tok.err, 0)
        elseif tok.type == "eq" then
            fail("syntax", EQ_MESSAGE, tok)
        elseif tok.type == "dotdot" then
            fail("syntax", RANGE_MESSAGE, tok)
        elseif tok.type == "eqeq" then
            fail("syntax", RELATION_MESSAGE, tok)
        end
        fail("syntax", "unexpected " .. describe(tok), tok)
    end

    local function expect_rparen()
        local tok = peek()
        if tok.type == "rparen" then
            advance()
        elseif tok.type == "eof" or tok.type == "newline" then
            fail("syntax", "missing ')': unexpected end of input", tok)
        elseif tok.type == "eqeq" then
            fail("syntax", RELATION_MESSAGE .. " and cannot be nested", tok)
        elseif tok.type == "error" then
            error(tok.err, 0)
        else
            fail("syntax", "expected ')' but found " .. describe(tok), tok)
        end
    end

    local parse_expr, parse_unary, parse_relation

    local function arity_check(name, count, min, max, tok)
        if count >= min and count <= max then
            return
        end
        if name == "plot" and count > max then
            fail("too_complex", "plot takes at most " .. max .. " functions", tok)
        end
        local expected = min == max and tostring(min) or (min .. " to " .. max)
        fail("syntax", "`" .. name .. "` takes " .. expected .. (max == 1 and " argument" or " arguments"), tok)
    end

    -- One call argument: an expression, a relation or (last only) a range.
    local function parse_argument(entry)
        local tok = peek()
        if tok.type == "ident" and tokens[i + 1].type == "eq" then
            if not (entry and entry.args == "expr-range") then
                fail("syntax", RANGE_MESSAGE, tok)
            end
            advance()
            advance()
            if tok.text ~= "x" then
                fail("syntax", "the range variable must be `x`", tok)
            end
            local lo = parse_expr()
            if peek().type ~= "dotdot" then
                fail("syntax", "a range needs `..` between its bounds, such as `x=-5..5`", peek())
            end
            advance()
            local hi = parse_expr()
            if peek().type ~= "rparen" then
                fail("syntax", RANGE_MESSAGE, peek())
            end
            return ast.range("x", lo, hi), true
        end
        local node = parse_relation()
        if node.t == "rel" and not (entry and entry.kind == "command") then
            fail("syntax", "an equation `==` cannot be used here", tok)
        end
        return node
    end

    -- After the `(`: parses the arguments and the `)`.
    local function parse_args(entry)
        local args, has_range = {}, false
        if peek().type == "rparen" then
            advance()
            return args, has_range
        end
        while true do
            local node, is_range = parse_argument(entry)
            args[#args + 1] = node
            has_range = has_range or is_range
            local tok = peek()
            if tok.type == "comma" then
                advance()
            elseif tok.type == "rparen" then
                advance()
                return args, has_range
            elseif tok.type == "eof" or tok.type == "newline" then
                fail("syntax", "missing ')': unexpected end of input", tok)
            else
                unexpected(tok)
            end
        end
    end

    local function parse_atom()
        local tok = advance()
        if tok.type == "num" then
            return number_node(tok)
        elseif tok.type == "ident" then
            local name = tok.text
            local nxt = peek()
            local entry = registry.get(name)
            if entry and entry.kind ~= "constant" then
                if nxt.type ~= "lparen" then
                    fail("syntax", "expected '(' after '" .. name .. "'", nxt)
                end
                advance()
                local args, has_range = parse_args(entry)
                arity_check(name, #args - (has_range and 1 or 0), entry.arity[1], entry.arity[2], tok)
                if entry.kind == "function" then
                    return ast.fn(registry.canonical(name), args[1])
                end
                return ast.call(name, args)
            end
            local user = nxt.type == "lparen" and funcs[name]
            if user then
                advance()
                local args = parse_args(nil)
                local params = user.params or { user.param }
                arity_check(name, #args, #params, #params, tok)
                for _, a in ipairs(args) do
                    if a.t == "range" then
                        fail("syntax", RANGE_MESSAGE, tok)
                    end
                end
                local call = inline_call(user, args)
                if ast.count(call) > lim.max_nodes then
                    fail("too_complex", "expression has too many parts", tok)
                end
                return call
            end
            if nxt.type == "lparen" then
                if CONSTANTS[name] or known[name] or #name == 1 then
                    i = i - 1
                    local from = i
                    i = i + 1
                    missing_times(from)
                end
                fail("syntax", "unknown function `" .. name .. "`", tok)
            end
            if CONSTANTS[name] then
                return ast.const(name)
            end
            return ast.var(name)
        elseif tok.type == "lparen" then
            local inner = parse_expr()
            expect_rparen()
            return inner
        end
        unexpected(tok)
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
            fail("too_complex", "expression is nested too deeply", peek())
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

    -- Two operands side by side: a number then a name or `(`, or `)` then a
    -- name, number or `(`.
    local function adjacent_operands()
        local prev, cur = tokens[i - 1], peek()
        if prev.type == "num" then
            return cur.type == "ident" or cur.type == "lparen"
        elseif prev.type == "rparen" then
            return cur.type == "ident" or cur.type == "lparen" or cur.type == "num"
        end
        return false
    end

    local function parse_term()
        local from = i
        local factors = { parse_unary() }
        while true do
            local tok = peek()
            if is_op(tok, "*") then
                advance()
                from = i
                factors[#factors + 1] = parse_unary()
            elseif is_op(tok, "/") then
                advance()
                from = i
                factors[#factors + 1] = ast.pow(parse_unary(), ast.num(-1))
            elseif adjacent_operands() then
                missing_times(from)
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

    function parse_relation()
        local lhs = parse_expr()
        if peek().type == "eqeq" then
            advance()
            local rhs = parse_expr()
            if peek().type == "eqeq" then
                fail("syntax", RELATION_MESSAGE, peek())
            end
            return ast.rel("==", lhs, rhs)
        end
        return lhs
    end

    local function check_defined_name(tok)
        if #tok.text > MAX_NAME then
            fail("name", "Name is longer than " .. MAX_NAME .. " characters", tok)
        elseif registry.is_reserved(tok.text) then
            fail("reserved", "Name is reserved: " .. tok.text, tok)
        end
    end

    local function end_of_statement()
        local rest = peek()
        if rest.type ~= "newline" and rest.type ~= "eof" then
            unexpected(rest)
        end
    end

    local function parse_value()
        local value = parse_expr()
        if peek().type == "eqeq" then
            fail("syntax", "the right side of `=` cannot be an equation", peek())
        end
        return value
    end

    -- `name ( params ) =` ?
    local function is_funcdef()
        local close = matching(i + 1)
        return close ~= nil and tokens[close + 1].type == "eq"
    end

    local function parse_params()
        local params, seen = {}, {}
        advance() -- (
        while true do
            local tok = advance()
            if tok.type ~= "ident" then
                fail("syntax", "a function definition needs parameter names, such as `f(x) = x^2`", tok)
            end
            check_defined_name(tok)
            if seen[tok.text] then
                fail("syntax", "parameter names must be different: `" .. tok.text .. "`", tok)
            end
            seen[tok.text] = true
            params[#params + 1] = tok.text
            local nxt = advance()
            if nxt.type == "rparen" then
                break
            elseif nxt.type ~= "comma" then
                fail("syntax", "a function definition needs parameter names, such as `f(x) = x^2`", nxt)
            end
        end
        if #params > MAX_PARAMS then
            fail("syntax", "a function takes 1 to " .. MAX_PARAMS .. " parameters", tokens[i - 1])
        end
        return params
    end

    -- One statement; returns its node and the index of the first token of its
    -- right-hand side (assignments and definitions).
    local function parse_statement()
        local tok = peek()
        local nxt = tokens[i + 1]
        local node, rhs_from
        if tok.type == "ident" and nxt.type == "eq" then
            check_defined_name(tok)
            advance()
            advance()
            rhs_from = i
            node = ast.assign(tok.text, parse_value())
            funcs[tok.text] = nil
            known[tok.text] = true
        elseif tok.type == "ident" and nxt.type == "lparen" and is_funcdef() then
            check_defined_name(tok)
            advance()
            local params = parse_params()
            advance() -- =
            rhs_from = i
            local body = parse_value()
            node = ast.funcdef(tok.text, params, body)
            funcs[tok.text] = { params = params, body = body }
            known[tok.text] = nil
        else
            node = parse_relation()
        end
        end_of_statement()
        return node, rhs_from
    end

    local P = {}

    function P.single()
        if peek().type == "eof" then
            fail("syntax", "empty expression", peek())
        end
        local node = parse_relation()
        local rest = peek()
        if rest.type ~= "eof" then
            unexpected(rest)
        end
        if ast.count(node) > lim.max_nodes then
            fail("too_complex", "expression has too many parts", tokens[1])
        end
        return node
    end

    local function arg_sources(first, last)
        if tokens[first].type ~= "ident" or tokens[first + 1].type ~= "lparen" or matching(first + 1) ~= last then
            return nil
        end
        local out, from, d = {}, first + 2, 0
        for j = first + 2, last - 1 do
            local t = tokens[j].type
            if t == "lparen" then
                d = d + 1
            elseif t == "rparen" then
                d = d - 1
            elseif t == "comma" and d == 0 then
                out[#out + 1] = slice(from, j - 1)
                from = j + 1
            end
        end
        if from <= last - 1 then
            out[#out + 1] = slice(from, last - 1)
        end
        return out
    end

    function P.program()
        local list = {}
        while true do
            while peek().type == "newline" do
                advance()
            end
            if peek().type == "eof" then
                break
            end
            local first = i
            local stmt = { line = tokens[first].line, pos = tokens[first].pos }
            local stop = first
            while tokens[stop].type ~= "newline" and tokens[stop].type ~= "eof" do
                stop = stop + 1
            end
            local last = stop - 1
            stmt.src = slice(first, last)
            if #stmt.src > lim.max_chars then
                local err = errors.new("too_complex", "Statement is longer than " .. lim.max_chars .. " characters", stmt.pos)
                err.line = stmt.line
                stmt.err = err
                i = stop
            else
                depth = 0
                local ok, node, rhs_from = pcall(parse_statement)
                if ok then
                    if ast.count(node) > lim.max_nodes then
                        local err = errors.new("too_complex", "expression has too many parts", stmt.pos)
                        err.line = stmt.line
                        stmt.err = err
                    else
                        stmt.node = node
                        stmt.rhs_src = rhs_from and slice(rhs_from, last) or nil
                        if node.t == "call" then
                            stmt.arg_srcs = arg_sources(first, last)
                        end
                    end
                else
                    stmt.err = errors.is(node) and node or errors.new("internal", tostring(node))
                    stmt.err.line = stmt.err.line or stmt.line
                    i = stop
                end
            end
            list[#list + 1] = stmt
        end
        return list
    end

    return P
end

local function prepare(overrides)
    local lim = setmetatable(overrides or {}, { __index = limits })
    local funcs = {}
    for name, entry in pairs(lim.user_funcs or {}) do
        funcs[name] = entry
    end
    local known = {}
    for name, value in pairs(lim.vars or {}) do
        if value ~= nil then
            known[name] = true
        end
    end
    return lim, funcs, known
end

local function run(fn)
    local ok, result = pcall(fn)
    if ok then
        return result
    end
    if errors.is(result) then
        return nil, result
    end
    return nil, errors.new("internal", tostring(result))
end

-- `overrides` may replace individual limits (used by tests and callers that
-- need tighter bounds). `overrides.user_funcs` maps a name to `{params, body}`
-- (or `{param, body}`); a call `name(a, b)` then parses to `body` with the
-- parameters replaced by the arguments. `overrides.vars` names known variables.
function M.parse(text, overrides)
    if type(text) ~= "string" then
        return nil, errors.new("syntax", "expression must be text")
    end
    local lim, funcs, known = prepare(overrides)
    if #text > lim.max_chars then
        return nil, errors.new("too_complex",
            "expression is longer than " .. lim.max_chars .. " characters")
    end
    local tokens, err = lexer.tokenize(text)
    if not tokens then
        return nil, err
    end
    local flat = {}
    for _, tok in ipairs(tokens) do
        if tok.type ~= "newline" then
            flat[#flat + 1] = tok
        end
    end
    return run(function()
        return make_parser(flat, text, lim, funcs, known).single()
    end)
end

-- Parses a whole cell. Returns a list of statements
-- `{line, pos, src, node | err, rhs_src?, arg_srcs?}`; never raises.
function M.parse_program(text, overrides)
    if type(text) ~= "string" then
        return nil, errors.new("syntax", "cell source must be text")
    end
    local lim, funcs, known = prepare(overrides)
    local tokens = lexer.tokenize(text, { recover = true })
    return run(function()
        return make_parser(tokens, text, lim, funcs, known).program()
    end)
end

return M
