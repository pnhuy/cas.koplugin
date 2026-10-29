-- Turns CAS results and errors into display text. No KOReader requires, so it
-- is unit-testable; the caller passes gettext as `translate`.

local calccas = require("calccas")

local M = {}

local MESSAGES = {
    syntax = "Syntax error",
    domain = "Not defined for these values",
    div_by_zero = "Division by zero",
    overflow = "Number too large",
    too_complex = "Expression too large",
    unsupported = "Not supported",
    undefined = "Undefined",
    unbound_variable = "A variable needs a value",
    range = "Invalid range",
    limit = "Limit reached",
    internal = "Internal error",
}

local function identity(s)
    return s
end

local function failure(expr, err, translate)
    local text = translate(MESSAGES[err.kind] or MESSAGES.internal)
    if err.kind ~= "internal" and err.message and err.message ~= "" then
        text = text .. ": " .. err.message
    end
    if err.pos and err.pos >= 1 and err.pos <= #expr + 1 then
        text = text .. "\n" .. expr .. "\n" .. string.rep(" ", err.pos - 1) .. "^"
    end
    return { ok = false, text = text, pos = err.pos }
end

local function blank(expr, translate)
    if expr:match("^%s*$") then
        return { ok = false, text = translate("Enter an expression") }
    end
end

-- Display text for an error raised outside evaluate/simplify (graph input).
function M.describe(expr, err, translate)
    return failure(expr or "", err, translate or identity).text
end

function M.evaluate(expr, vars_text, translate)
    translate = translate or identity
    expr = expr or ""
    local empty = blank(expr, translate)
    if empty then
        return empty
    end
    local vars, verr = calccas.parse_assignments(vars_text or "")
    if not vars then
        return failure(vars_text or "", verr, translate)
    end
    local result, err = calccas.evaluate(expr, vars)
    if not result then
        return failure(expr, err, translate)
    end
    return { ok = true, text = result.text }
end

function M.simplify(expr, translate)
    translate = translate or identity
    expr = expr or ""
    local empty = blank(expr, translate)
    if empty then
        return empty
    end
    local result, err = calccas.simplify(expr)
    if not result then
        return failure(expr, err, translate)
    end
    local text = result.text
    if #result.assumptions > 0 then
        text = text .. "\n" .. translate("Assuming") .. ": " .. table.concat(result.assumptions, ", ")
    end
    return { ok = true, text = text }
end

return M
