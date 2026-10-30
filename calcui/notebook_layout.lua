-- Windowing of the cell list: which cells are on screen for a top index and a
-- viewport height, and how paging and "keep the active cell visible" move the
-- top index. Pure; heights are pixel heights per cell.

local M = {}

function M.clamp(top, count)
    return math.max(1, math.min(top, math.max(count, 1)))
end

-- Cells from `top` until the viewport is full; the last one may be cut off.
function M.visible(heights, top, viewport_h)
    local indices = {}
    local used = 0
    for i = top, #heights do
        if used >= viewport_h and #indices > 0 then
            break
        end
        indices[#indices + 1] = i
        used = used + heights[i]
    end
    return { first = indices[1], last = indices[#indices], indices = indices }
end

-- First cell that was not completely shown on this page (at least top + 1).
function M.page_down(heights, top, viewport_h)
    local used = 0
    local i = top
    while i <= #heights and used + heights[i] <= viewport_h do
        used = used + heights[i]
        i = i + 1
    end
    if i == top then
        i = top + 1
    end
    return M.clamp(i, #heights)
end

-- Top index of the page that ends just above `top`.
function M.page_up(heights, top, viewport_h)
    local used = 0
    local i = top
    while i > 1 and used + heights[i - 1] <= viewport_h do
        i = i - 1
        used = used + heights[i]
    end
    if i == top then
        i = top - 1
    end
    return M.clamp(i, #heights)
end

-- New top index so cell `index` is fully visible; a cell taller than the
-- viewport is shown from its top edge.
function M.reveal(heights, top, viewport_h, index)
    if index <= top then
        return index
    end
    local used = 0
    local t = index
    while t >= top and used + heights[t] <= viewport_h do
        used = used + heights[t]
        t = t - 1
    end
    if t == index then
        return index
    end
    return math.max(top, t + 1)
end

return M
