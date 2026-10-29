-- Pure part of settings persistence: turns whatever was read from the settings
-- file into a valid viewport and grid flag. No KOReader requires.

local viewport = require("calcplot.viewport")

local M = {}

function M.defaults()
    return { viewport = viewport.default(), grid = true }
end

-- data: the raw stored value (any type). Always returns a usable table.
function M.sanitize(data)
    local out = M.defaults()
    if type(data) ~= "table" then
        return out
    end
    local v = data.viewport
    if type(v) == "table" then
        local vp = viewport.new(v.xmin, v.xmax, v.ymin, v.ymax, v.auto_y == true)
        if vp then
            out.viewport = vp
        end
    end
    if type(data.grid) == "boolean" then
        out.grid = data.grid
    end
    return out
end

-- Plain table to store (no functions or metatables).
function M.to_data(vp, grid)
    return {
        viewport = { xmin = vp.xmin, xmax = vp.xmax, ymin = vp.ymin, ymax = vp.ymax, auto_y = vp.auto_y == true },
        grid = grid ~= false,
    }
end

return M
