-- CAS shortcut groups for the keyboard's shortcut row (FR-026..FR-029).
-- Only names the engine supports, plus the cell commands the runner handles,
-- are offered; unsupported commands (diff, solve, ...) never appear.

local calccas = require("calccas")

local M = {}

local COMMANDS = { "expand", "simplify", "plot" }

-- Display order. Names the engine adds later land in "more".
local GROUPS = {
    { id = "common", label = "common", names = { "sin", "cos", "tan", "sqrt", "plot" } },
    { id = "basic", label = "basic", names = { "abs", "exp", "log", "ln" } },
    { id = "algebra", label = "algebra", names = { "simplify", "expand" } },
}

local function item(name)
    return { label = name, insert = name .. "()", back = 1 }
end

-- `supported` is a list of engine function names (default: calccas.functions()).
function M.groups(supported)
    local available = {}
    for _, name in ipairs(supported or calccas.functions()) do
        available[name] = true
    end
    for _, name in ipairs(COMMANDS) do
        available[name] = true
    end

    local placed, groups = {}, {}
    for _, def in ipairs(GROUPS) do
        local items = {}
        for _, name in ipairs(def.names) do
            if available[name] then
                items[#items + 1] = item(name)
                placed[name] = true
            end
        end
        if #items > 0 then
            groups[#groups + 1] = { id = def.id, label = def.label, items = items }
        end
    end

    local rest = {}
    for name in pairs(available) do
        if not placed[name] then
            rest[#rest + 1] = name
        end
    end
    table.sort(rest)
    if #rest > 0 then
        local items = {}
        for _, name in ipairs(rest) do
            items[#items + 1] = item(name)
        end
        groups[#groups + 1] = { id = "more", label = "more", items = items }
    end
    return groups
end

-- Splits groups into slides of at most `per_slide` keys; a slide is one step of
-- the group switch key.
function M.slides(groups, per_slide)
    per_slide = math.max(1, per_slide)
    local slides = {}
    for _, g in ipairs(groups) do
        for first = 1, #g.items, per_slide do
            local items = {}
            for i = first, math.min(first + per_slide - 1, #g.items) do
                items[#items + 1] = g.items[i]
            end
            slides[#slides + 1] = { id = g.id, label = g.label, items = items }
        end
    end
    return slides
end

return M
