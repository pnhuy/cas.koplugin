-- Axis tick positions and labels.

local M = {}

local floor, ceil, abs, log10 = math.floor, math.ceil, math.abs, math.log10
local MAX_TICKS = 1000

local function finite(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Returns { value, ..., step = step } with step in {1,2,5} x 10^k, or {} for
-- an invalid range. Values are rounded to the step's precision.
function M.nice(min, max, target_count)
    local ticks = {}
    if not (finite(min) and finite(max)) or max <= min then
        return ticks
    end
    local raw = (max - min) / math.max(target_count or 5, 1)
    local exponent = floor(log10(raw) + 1e-9)
    local mag = tonumber("1e" .. exponent)
    local norm = raw / mag
    local factor = 10
    if norm <= 1 + 1e-9 then
        factor = 1
    elseif norm <= 2 + 1e-9 then
        factor = 2
    elseif norm <= 5 + 1e-9 then
        factor = 5
    end
    local step = tonumber(string.format("%.15g", factor * mag))
    ticks.step = step
    local decimals = string.format("%d", math.max(0, -floor(log10(step) + 1e-9)))
    local fmt = "%." .. decimals .. "f"
    local k = ceil(min / step - 1e-9)
    while #ticks < MAX_TICKS do
        local v = tonumber(string.format(fmt, k * step))
        if v > max + step * 1e-9 then
            break
        end
        if v >= min - step * 1e-9 then
            ticks[#ticks + 1] = v
        end
        k = k + 1
    end
    return ticks
end

function M.label(value, step)
    if value == 0 then
        return "0"
    end
    if abs(value) >= 1e7 or abs(value) < 1e-4 then
        return string.format("%g", value)
    end
    local decimals = string.format("%d", math.max(0, ceil(-log10(step) - 1e-9)))
    local text = string.format("%." .. decimals .. "f", value)
    if tonumber(text) == 0 then
        return "0"
    end
    return text
end

return M
