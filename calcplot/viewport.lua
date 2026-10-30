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
    local limits = { xmin, xmax, ymin, ymax }
    for i = 1, 4 do -- not ipairs: a missing limit is nil
        local v = limits[i]
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

function M.copy(vp)
    local out = {}
    for k, v in pairs(vp) do
        out[k] = v
    end
    return out
end

-- Validates data read from a saved file. Only the four limits, `auto_y` and
-- the boolean display flags `grid`/`axes` are kept.
function M.from_table(t)
    if type(t) ~= "table" then
        return bad("viewport must be a table")
    end
    local vp, err = M.new(t.xmin, t.xmax, t.ymin, t.ymax, t.auto_y)
    if not vp then
        return nil, err
    end
    for _, flag in ipairs({ "grid", "axes" }) do
        if type(t[flag]) == "boolean" then
            vp[flag] = t[flag]
        end
    end
    return vp
end

-- Rebuilds `vp` with new limits, keeping auto_y and the display flags.
local function with_limits(vp, xmin, xmax, ymin, ymax, auto_y)
    local out, err = M.new(xmin, xmax, ymin, ymax, auto_y)
    if not out then
        return nil, err
    end
    out.grid, out.axes = vp.grid, vp.axes
    return out
end

-- factor < 1 zooms in, > 1 zooms out, about the centre.
function M.zoom(vp, factor)
    local cx, cy = (vp.xmin + vp.xmax) / 2, (vp.ymin + vp.ymax) / 2
    local hx, hy = (vp.xmax - vp.xmin) * factor / 2, (vp.ymax - vp.ymin) * factor / 2
    return with_limits(vp, cx - hx, cx + hx, cy - hy, cy + hy, vp.auto_y)
end

-- fx, fy: fractions of the span (positive = right / up). A vertical pan turns
-- auto_y off, otherwise the next plot would undo it.
function M.pan(vp, fx, fy)
    local dx, dy = (vp.xmax - vp.xmin) * fx, (vp.ymax - vp.ymin) * fy
    return with_limits(vp, vp.xmin + dx, vp.xmax + dx, vp.ymin + dy, vp.ymax + dy,
        vp.auto_y and fy == 0)
end

-- Keeps the X range and the Y centre; Y gets the same units per pixel as X.
function M.equal_scale(vp, w, h)
    if not (finite(w) and finite(h) and w > 0 and h > 0) then
        return bad("canvas size must be positive")
    end
    local half = (vp.xmax - vp.xmin) / w * h / 2
    local cy = (vp.ymin + vp.ymax) / 2
    return with_limits(vp, vp.xmin, vp.xmax, cy - half, cy + half, false)
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
