-- Graph view state and rules, without any widgets: the function list, the
-- range text parser and the cache key. `state` is session data:
-- { functions = { {id, text, visible, style} }, viewport = {...}, grid = true }.

local calccas = require("calccas")
local viewport = require("calcplot.viewport")

local M = {}

M.MAX_FUNCTIONS = 6

function M.new_state()
    return { functions = {}, viewport = viewport.default(), grid = true, next_id = 1 }
end

local function find(state, id)
    for i, f in ipairs(state.functions) do
        if f.id == id then
            return f, i
        end
    end
end

local function lowest_free_style(state)
    local used = {}
    for _, f in ipairs(state.functions) do
        used[f.style] = true
    end
    for style = 1, M.MAX_FUNCTIONS do
        if not used[style] then
            return style
        end
    end
end

-- The compiled function of an entry, cached on it. nil + error if it cannot
-- be plotted.
function M.compiled(entry)
    if entry.fn == nil and entry.error == nil then
        local fn, err = calccas.compile(entry.text, "x")
        if fn then
            entry.fn = fn
        else
            entry.error = err
        end
    end
    return entry.fn, entry.error
end

local function check(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then
        return nil, { kind = "syntax", message = "Enter an expression" }
    end
    local fn, err = calccas.compile(text, "x")
    if not fn then
        return nil, err
    end
    return text, nil, fn
end

-- Returns the new entry, or nil plus an error ({kind, message, pos?}).
function M.add(state, text)
    if #state.functions >= M.MAX_FUNCTIONS then
        return nil, { kind = "limit", message = "At most " .. M.MAX_FUNCTIONS .. " functions" }
    end
    local clean, err, fn = check(text)
    if not clean then
        return nil, err
    end
    local entry = { id = state.next_id, text = clean, visible = true, style = lowest_free_style(state), fn = fn }
    state.next_id = state.next_id + 1
    state.functions[#state.functions + 1] = entry
    return entry
end

function M.edit(state, id, text)
    local entry = find(state, id)
    if not entry then
        return nil, { kind = "internal", message = "no such function" }
    end
    local clean, err, fn = check(text)
    if not clean then
        return nil, err
    end
    entry.text, entry.fn, entry.error = clean, fn, nil
    return entry
end

function M.remove(state, id)
    local _, index = find(state, id)
    if index then
        table.remove(state.functions, index)
        return true
    end
    return false
end

function M.toggle(state, id)
    local entry = find(state, id)
    if entry then
        entry.visible = not entry.visible
        return entry.visible
    end
end

-- Functions ready for calcplot.new, and how many visible ones cannot be plotted.
function M.plot_functions(state)
    local out, failed = {}, 0
    for _, entry in ipairs(state.functions) do
        if entry.visible then
            local fn = M.compiled(entry)
            if fn then
                out[#out + 1] = { id = entry.id, fn = fn, visible = true, style = entry.style }
            else
                failed = failed + 1
            end
        end
    end
    return out, failed
end

-- Same key <=> same picture (research R7).
function M.cache_key(state, w, h)
    local parts = {}
    for _, entry in ipairs(state.functions) do
        if entry.visible then
            parts[#parts + 1] = entry.style .. "=" .. entry.text
        end
    end
    local vp = state.viewport
    return table.concat({
        table.concat(parts, "|"),
        string.format("%.17g,%.17g,%.17g,%.17g", vp.xmin, vp.xmax, vp.ymin, vp.ymax),
        tostring(vp.auto_y),
        tostring(state.grid),
        w .. "x" .. h,
    }, ";")
end

-- A number or a constant expression such as "2*pi"; nil if it is neither.
local function number_of(text)
    local n = tonumber(text)
    if n then
        return n
    end
    local result = calccas.evaluate(text)
    return result and result.value
end

-- texts: { xmin, xmax, ymin, ymax } as typed. With auto_y the Y texts may be
-- blank and are ignored. Returns a viewport or nil + error.
function M.parse_range(texts, auto_y)
    local names = { "Xmin", "Xmax", "Ymin", "Ymax" }
    local values = {}
    for i = 1, 4 do
        local text = (texts[i] or ""):match("^%s*(.-)%s*$")
        if (i <= 2 or not auto_y) or text ~= "" then
            values[i] = number_of(text)
            if values[i] == nil then
                return nil, { kind = "range", message = names[i] .. " is not a number" }
            end
        end
    end
    return viewport.new(values[1], values[2], values[3] or -10, values[4] or 10, auto_y)
end

return M
