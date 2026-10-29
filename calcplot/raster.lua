-- Pixel stepping for polylines with the six line styles. Pure: drawing goes
-- through paint(x, y, size), which fills a size x size square at its top-left.

local M = {}

local floor, abs = math.floor, math.abs

local MARKER_SIZE = 5

-- Index = function slot. Distinguishable without grey levels: thickness and
-- dash pattern, not shade.
M.STYLES = {
    { name = "solid", thick = 3 },
    { name = "dashed", thick = 2, pattern = { 10, 6 } },
    { name = "dotted", thick = 2, pattern = { 2, 6 } },
    { name = "dash-dot", thick = 2, pattern = { 10, 4, 2, 4 } },
    { name = "marked", thick = 1, markers = 14 },
    { name = "double", thick = 1, double = 3 },
}

local function round(v)
    return floor(v + 0.5)
end

local function line(x0, y0, x1, y1, visit)
    local dx, dy = abs(x1 - x0), -abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx + dy
    while true do
        visit(x0, y0)
        if x0 == x1 and y0 == y1 then
            return
        end
        local e2 = 2 * err
        if e2 >= dy then
            err = err + dy
            x0 = x0 + sx
        end
        if e2 <= dx then
            err = err + dx
            y0 = y0 + sy
        end
    end
end

local function is_on(pattern, period, d)
    local m = d % period
    for i, length in ipairs(pattern) do
        if m < length then
            return i % 2 == 1
        end
        m = m - length
    end
    return true
end

local function pattern_period(pattern)
    local total = 0
    for _, length in ipairs(pattern) do
        total = total + length
    end
    return total
end

local function trace(points, style, ox, oy, paint)
    local thick = style.thick
    local half = floor(thick / 2)
    local pattern = style.pattern
    local period = pattern and pattern_period(pattern)
    local marker_half = floor(MARKER_SIZE / 2)
    local d = 0
    local function visit(x, y)
        if not pattern or is_on(pattern, period, d) then
            paint(x + ox - half, y + oy - half, thick)
        end
        if style.markers and d % style.markers == 0 then
            paint(x + ox - marker_half, y + oy - marker_half, MARKER_SIZE)
        end
        d = d + 1
    end
    local px, py = round(points[1][1]), round(points[1][2])
    visit(px, py)
    for i = 2, #points do
        local nx, ny = round(points[i][1]), round(points[i][2])
        local first = true
        line(px, py, nx, ny, function(x, y)
            if first then
                first = false
            else
                visit(x, y)
            end
        end)
        px, py = nx, ny
    end
end

-- points: { {x, y}, ... } in canvas pixels; style: an entry of M.STYLES.
function M.polyline(points, style, paint)
    if #points == 0 then
        return
    end
    if style.double then
        local a, b = points[1], points[#points]
        local steep = abs(b[2] - a[2]) > abs(b[1] - a[1])
        local gap = style.double
        trace(points, style, steep and -gap or 0, steep and 0 or -gap, paint)
        trace(points, style, steep and gap or 0, steep and 0 or gap, paint)
    else
        trace(points, style, 0, 0, paint)
    end
end

return M
