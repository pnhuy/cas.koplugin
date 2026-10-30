-- Keyboard dimensions from the screen size (FR-019). Pure: no KOReader classes.
-- Aims for 45% of the height, within 35-55%; when the touch minimum cannot fit
-- under the 55% cap (landscape), keys shrink and `tight` is reported.

local keyboard_layout = require("calcnb.keyboard_layout")

local M = {}

M.MIN_KEY_H = 40
M.MAX_KEY_H = 96
M.TARGET = 0.45
M.CAP = 0.55

-- rows: number of key rows including the shortcut row.
function M.compute(screen_w, screen_h, rows)
    rows = math.max(1, rows or 1)
    screen_h = math.max(0, screen_h or 0)
    local key_h = math.floor(M.TARGET * screen_h / rows)
    key_h = math.min(M.MAX_KEY_H, math.max(M.MIN_KEY_H, key_h))
    local tight = false
    if key_h * rows > M.CAP * screen_h then
        key_h = math.max(1, math.floor(M.CAP * screen_h / rows))
        tight = true
    end
    local height = key_h * rows
    return {
        compact = keyboard_layout.is_compact(screen_w or 0),
        key_h = key_h,
        height = height,
        free_h = screen_h - height,
        tight = tight,
    }
end

return M
