-- Visible math rectangle and the math <-> screen transform.
-- Screen y grows downward, so py = 0 is ymax.

local errors = require("calccas.errors")

local M = {}

local MIN_SPAN, MAX_ABS = 1e-9, 1e9
local TRIM = 0.02 -- fraction of samples ignored at each end by auto_y
local PAD = 0.1

local function finite(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function bad(message)
    return nil, errors.new("range", message)
end

function M.new(xmin, xmax, ymin, ymax, auto_y)
    for _, v in ipairs({ xmin, xmax, ymin, ymax }) do
        if not finite(v) then
            return bad("range values must be finite numbers")
        end
        if math.abs(v) > MAX_ABS then
            return bad("range values must be within ±1e9")
        end
    end
    if xmax - xmin < MIN_SPAN then
        return bad("Xmax must be greater than Xmin")
    end
    if ymax - ymin < MIN_SPAN then
        return bad("Ymax must be greater than Ymin")
    end
    return { xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, auto_y = auto_y == true }
end

function M.default()
    return { xmin = -10, xmax = 10, ymin = -10, ymax = 10, auto_y = true }
end

function M.to_screen(vp, w, h, x, y)
    return (x - vp.xmin) * w / (vp.xmax - vp.xmin), (vp.ymax - y) * h / (vp.ymax - vp.ymin)
end

function M.to_math(vp, w, h, px, py)
    return vp.xmin + px * (vp.xmax - vp.xmin) / w, vp.ymax - py * (vp.ymax - vp.ymin) / h
end

-- samples may contain false/nil/NaN/inf for undefined points.
function M.auto_y(vp, samples)
    local ys = {}
    for i = 1, #samples do
        if finite(samples[i]) then
            ys[#ys + 1] = samples[i]
        end
    end
    local n = #ys
    if n < 2 then
        return vp
    end
    table.sort(ys)
    local lo = ys[1 + math.floor(TRIM * (n - 1))]
    local hi = ys[1 + math.ceil((1 - TRIM) * (n - 1))]
    local pad = (hi - lo) * PAD
    if pad < 1e-9 then
        pad = math.max(math.abs(lo) * PAD, 1)
    end
    return {
        xmin = vp.xmin,
        xmax = vp.xmax,
        ymin = math.max(lo - pad, -MAX_ABS),
        ymax = math.min(hi + pad, MAX_ABS),
        auto_y = true,
    }
end

return M
