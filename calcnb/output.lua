-- Cell outputs: a value, an error or a graph. `canonical` is the engine's
-- text (what Copy and Insert use); `display` is the same text prettified for
-- reading and never fed back to the engine.

local calccas = require("calccas")
local limits = require("calccas.limits")

local M = {}

local MAX_DISPLAY = 600

local SUPER = {
    ["0"] = "⁰", ["1"] = "¹", ["2"] = "²", ["3"] = "³", ["4"] = "⁴",
    ["5"] = "⁵", ["6"] = "⁶", ["7"] = "⁷", ["8"] = "⁸", ["9"] = "⁹", ["-"] = "⁻",
}
local SUB = {
    ["0"] = "₀", ["1"] = "₁", ["2"] = "₂", ["3"] = "₃", ["4"] = "₄",
    ["5"] = "₅", ["6"] = "₆", ["7"] = "₇", ["8"] = "₈", ["9"] = "₉",
}

-- `x^2` -> `x²`, `x_1` -> `x₁`, constant `pi` -> `π`. Anything else (`x^y`,
-- `x^(a+1)`, `a_b`) is left as typed.
function M.prettify(text)
    -- Exponents/subscripts must end at a character that cannot continue them.
    local out = text:gsub("%^(%-?%d+)%f[^%w_]", function(digits)
        return (digits:gsub(".", SUPER))
    end)
    out = out:gsub("_(%d+)%f[^%w_]", function(digits)
        return (digits:gsub(".", SUB))
    end)
    out = out:gsub("%f[%a]pi%f[^%w_]", "π")
    return out
end

local function shorten(text)
    if #text <= MAX_DISPLAY then
        return text, false
    end
    local cut = MAX_DISPLAY
    -- back off to the start of a UTF-8 character
    while cut > 0 do
        local b = text:byte(cut + 1)
        if not b or b < 0x80 or b >= 0xC0 then
            break
        end
        cut = cut - 1
    end
    return text:sub(1, cut) .. "…", true
end

local function build(canonical, display)
    local short, truncated = shorten(display)
    local out = { kind = "value", canonical = canonical, display = short, truncated = truncated }
    if truncated then
        out.full = display
    end
    return out
end

-- From a `calccas.evaluate` result.
function M.value(result)
    local canonical = result.exact and calccas.tostring(result.exact) or tostring(result.value)
    return build(canonical, M.prettify(result.text or canonical))
end

-- Plain text output (messages such as assignment confirmations).
function M.text(text)
    return build(text, text)
end

-- `err` is a calccas error or a statement-layer `{kind, message, line}`;
-- `line` overrides err.line when given.
function M.error(err, line)
    local message = err.message or ""
    return {
        kind = "error",
        canonical = message,
        display = message,
        truncated = false,
        error = { kind = err.kind, message = message, pos = err.pos, line = line or err.line },
    }
end

-- `functions`: array of `{label, ast}`, at most `limits.max_functions`.
function M.graph(functions, x_range)
    if #functions > limits.max_functions then
        return nil, { kind = "too_complex", message = "at most " .. limits.max_functions .. " functions can be plotted" }
    end
    local labels = {}
    for i, f in ipairs(functions) do
        labels[i] = f.label
    end
    local text = table.concat(labels, ", ")
    return {
        kind = "graph",
        canonical = text,
        display = text,
        truncated = false,
        graph = { functions = functions, x_range = x_range },
    }
end

return M
