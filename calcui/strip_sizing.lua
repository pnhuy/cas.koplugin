-- Height of the suggestion strip (contracts/strip-ui.md, "Layout"). Pure: no
-- KOReader classes. The strip has two rows (chips, documentation), one row
-- (chips only) or none, fixed for a screen size so the page never shifts while
-- typing; it gives way before fewer than MIN_PAGE_LINES editor lines remain.

local M = {}

M.MIN_PAGE_LINES = 4
M.MAX_ROWS = 2

-- screen_h, screen_w: screen size; keyboard_h: height of the keyboard;
-- other_h: toolbar and page bar; line_h: height of one text line and one strip row.
-- Returns `{ rows, height }`.
function M.strip_height(screen_h, _, keyboard_h, other_h, line_h)
    line_h = tonumber(line_h) or 0
    screen_h = tonumber(screen_h) or 0
    if line_h <= 0 or screen_h <= 0 then
        return { rows = 0, height = 0 }
    end
    local free = screen_h - math.max(0, tonumber(keyboard_h) or 0) - math.max(0, tonumber(other_h) or 0)
    for rows = M.MAX_ROWS, 1, -1 do
        if free - rows * line_h >= M.MIN_PAGE_LINES * line_h then
            return { rows = rows, height = rows * line_h }
        end
    end
    return { rows = 0, height = 0 }
end

return M
