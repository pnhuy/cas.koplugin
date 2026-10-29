-- Turns f(x) into math-space polylines. Undefined points (nil, NaN, ±inf)
-- split a polyline; domain edges are refined by bisection; a jump larger than
-- the visible height is refined and, if it persists, treated as a pole.

local M = {}

local abs, huge = math.abs, math.huge

local DEFAULT_SAMPLES, DEFAULT_MAX_EVALS, DEFAULT_MAX_DEPTH = 400, 4000, 8

-- f(x) as a finite number, or nil. A raising function is just undefined.
local function evaluate(fn, x)
    local ok, v = pcall(fn, x)
    if ok and type(v) == "number" and v == v and v ~= huge and v ~= -huge then
        return v
    end
end

-- n + 1 evenly spaced samples; false where undefined.
function M.values(fn, xmin, xmax, n, on_eval)
    local ys = {}
    for i = 0, n do
        if on_eval then
            on_eval()
        end
        ys[i + 1] = evaluate(fn, xmin + (xmax - xmin) * i / n) or false
    end
    return ys
end

-- opts: samples, ymin, ymax (visible range, sets the pole threshold),
-- max_evals, max_depth, on_eval (called before every evaluation).
-- Returns { polylines = { { {x, y}, ... }, ... }, evals = n }.
function M.sample(fn, xmin, xmax, opts)
    local max_evals = opts.max_evals or DEFAULT_MAX_EVALS
    local max_depth = opts.max_depth or DEFAULT_MAX_DEPTH
    local n = math.min(opts.samples or DEFAULT_SAMPLES, math.floor(max_evals / 2))
    local jump = opts.ymax - opts.ymin
    local on_eval = opts.on_eval
    local evals = 0

    local function ev(x)
        evals = evals + 1
        if on_eval then
            on_eval(evals)
        end
        return evaluate(fn, x)
    end

    -- From a defined point toward an undefined one: the defined points found
    -- on the way, nearest to the start first.
    local function bound(xd, xu)
        local pts = {}
        for _ = 1, max_depth do
            if evals >= max_evals then
                break
            end
            local m = (xd + xu) / 2
            local y = ev(m)
            if y then
                xd = m
                pts[#pts + 1] = { m, y }
            else
                xu = m
            end
        end
        return pts
    end

    -- Narrow a large jump between two defined points. Returns the points
    -- gained on each side and whether the jump is a discontinuity.
    local function refine(xa, ya, xb, yb)
        local left, right = {}, {}
        for _ = 1, max_depth do
            if evals >= max_evals then
                break
            end
            local m = (xa + xb) / 2
            local ym = ev(m)
            if not ym then
                return left, right, true
            end
            if abs(ym - ya) >= abs(yb - ym) then
                xb, yb = m, ym
                right[#right + 1] = { m, ym }
            else
                xa, ya = m, ym
                left[#left + 1] = { m, ym }
            end
            if abs(yb - ya) <= jump then
                return left, right, false
            end
        end
        return left, right, abs(yb - ya) > jump
    end

    local xs, ys = {}, {}
    for i = 0, n do
        xs[i] = xmin + (xmax - xmin) * i / n
        ys[i] = ev(xs[i]) or false
    end

    local polylines, cur = {}, nil
    local function flush()
        if cur and #cur >= 2 then
            polylines[#polylines + 1] = cur
        end
        cur = nil
    end
    local function append(points)
        for _, p in ipairs(points) do
            cur[#cur + 1] = p
        end
    end
    local function append_reversed(points)
        for k = #points, 1, -1 do
            cur[#cur + 1] = points[k]
        end
    end

    for i = 1, n do
        local xa, ya, xb, yb = xs[i - 1], ys[i - 1], xs[i], ys[i]
        if ya and not cur then
            cur = { { xa, ya } }
        end
        if ya and yb then
            if abs(yb - ya) > jump then
                local left, right, broke = refine(xa, ya, xb, yb)
                append(left)
                if broke then
                    flush()
                    cur = {}
                end
                append_reversed(right)
            end
            cur[#cur + 1] = { xb, yb }
        elseif ya then
            append(bound(xa, xb))
            flush()
        elseif yb then
            cur = {}
            append_reversed(bound(xb, xa))
            cur[#cur + 1] = { xb, yb }
        end
    end
    flush()
    return { polylines = polylines, evals = evals }
end

return M
