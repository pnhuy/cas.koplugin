-- Liang–Barsky segment clipping against an axis-aligned box.

local M = {}

local function clamp(v, lo, hi)
    return v < lo and lo or (v > hi and hi or v)
end

-- Returns the clipped segment x1, y1, x2, y2, or nil if it misses the box.
function M.segment(x1, y1, x2, y2, xmin, ymin, xmax, ymax)
    local dx, dy = x2 - x1, y2 - y1
    local t0, t1 = 0, 1
    local p = { -dx, dx, -dy, dy }
    local q = { x1 - xmin, xmax - x1, y1 - ymin, ymax - y1 }
    for i = 1, 4 do
        if p[i] == 0 then
            if q[i] < 0 then
                return nil
            end
        else
            local t = q[i] / p[i]
            if p[i] < 0 then
                if t > t1 then
                    return nil
                end
                if t > t0 then
                    t0 = t
                end
            else
                if t < t0 then
                    return nil
                end
                if t < t1 then
                    t1 = t
                end
            end
        end
    end
    local ax, ay, bx, by = x1, y1, x2, y2
    if t0 > 0 then
        ax, ay = x1 + t0 * dx, y1 + t0 * dy
    end
    if t1 < 1 then
        bx, by = x1 + t1 * dx, y1 + t1 * dy
    end
    return clamp(ax, xmin, xmax), clamp(ay, ymin, ymax), clamp(bx, xmin, xmax), clamp(by, ymin, ymax)
end

return M
