-- Pure side of notebook persistence: turns a notebook into plain tables and
-- back, repairing or dropping whatever a damaged file holds. It never raises
-- and always yields a usable notebook (see contracts/notebook-file.md).

local notebook = require("calcnb.notebook")
local viewport = require("calcplot.viewport")

local M = {}

local VERSION = 1
local NAME = "default"

local function is_number(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Cuts `text` to `max` bytes without splitting a UTF-8 character.
local function truncate(text, max)
    text = text:sub(1, max)
    while #text > 0 and not notebook.valid_utf8(text) do
        text = text:sub(1, -2)
    end
    return text
end

local function viewport_data(vp)
    if not vp then
        return nil
    end
    local out = {}
    for _, key in ipairs({ "xmin", "xmax", "ymin", "ymax", "auto_y", "grid", "axes", "equal" }) do
        out[key] = vp[key]
    end
    return out
end

-- Plain tables only; outputs are not stored.
function M.to_data(nb, scroll)
    local cells = {}
    for i, c in ipairs(nb.cells) do
        cells[i] = { id = c.id, type = c.type, source = c.source, viewport = viewport_data(c.viewport) }
    end
    local data = { title = nb.title, next_id = nb.next_id, cells = cells }
    if scroll and is_number(scroll.top_id) and is_number(scroll.offset) then
        data.scroll = { top_id = scroll.top_id, offset = scroll.offset }
    end
    return data
end

function M.to_file(nb, scroll)
    return { version = VERSION, notebooks = { [NAME] = M.to_data(nb, scroll) }, last_notebook = NAME }
end

-- Returns the repaired cell, or nil and a problem text.
local function clean_cell(raw, index)
    if type(raw) ~= "table" then
        return nil, "cell " .. index .. " is not a cell and was dropped"
    end
    local problems = {}
    local cell_type = raw.type
    if cell_type ~= "code" and cell_type ~= "text" then
        cell_type = "code"
        problems[#problems + 1] = "cell " .. index .. " has an unknown type and was read as code"
    end
    local source = raw.source
    if type(source) ~= "string" then
        source = ""
        problems[#problems + 1] = "cell " .. index .. " had no readable text"
    elseif not notebook.valid_utf8(source) then
        return nil, "cell " .. index .. " has invalid text and was dropped"
    elseif #source > notebook.MAX_SOURCE then
        source = truncate(source, notebook.MAX_SOURCE)
        problems[#problems + 1] = "cell " .. index .. " was too long and was shortened"
    end
    local vp
    if raw.viewport ~= nil then
        vp = viewport.from_table(raw.viewport)
        if not vp then
            problems[#problems + 1] = "the graph range of cell " .. index .. " was invalid and was reset"
        elseif type(raw.viewport.equal) == "boolean" then
            vp.equal = raw.viewport.equal
        end
    end
    return { id = raw.id, type = cell_type, source = source, viewport = vp }, problems
end

local function clean_scroll(raw, nb)
    if type(raw) ~= "table" or not is_number(raw.top_id) or not is_number(raw.offset) or raw.offset < 0 then
        return nil
    end
    if nb:get(raw.top_id) then
        return { top_id = raw.top_id, offset = raw.offset }
    end
end

-- Returns notebook, problems (list of texts), scroll (or nil).
function M.sanitize(data)
    local nb = notebook.new()
    local problems = {}
    if type(data) ~= "table" then
        problems[1] = "the saved notebook could not be read"
        return nb, problems, nil
    end

    if type(data.title) == "string" then
        nb:set_title(data.title)
    else
        problems[#problems + 1] = "the notebook title was missing"
    end

    nb.cells = {}
    local raw_cells = type(data.cells) == "table" and data.cells or {}
    if type(data.cells) ~= "table" then
        problems[#problems + 1] = "the notebook had no cells"
    end

    local highest = is_number(data.next_id) and data.next_id - 1 or 0
    local kept = {}
    for i = 1, #raw_cells do
        if #kept >= notebook.MAX_CELLS then
            problems[#problems + 1] = "only the first " .. notebook.MAX_CELLS .. " cells were kept"
            break
        end
        local cell, extra = clean_cell(raw_cells[i], i)
        if cell then
            kept[#kept + 1] = cell
            if is_number(cell.id) and cell.id > highest then
                highest = cell.id
            end
            for _, p in ipairs(extra) do
                problems[#problems + 1] = p
            end
        else
            problems[#problems + 1] = extra
        end
    end

    local seen = {}
    local renumbered = false
    for _, cell in ipairs(kept) do
        if not is_number(cell.id) or cell.id < 1 or cell.id ~= math.floor(cell.id) or seen[cell.id] then
            highest = highest + 1
            cell.id = highest
            renumbered = true
        end
        seen[cell.id] = true
        cell.status, cell.out_of_date = "idle", false
        nb.cells[#nb.cells + 1] = cell
    end
    if renumbered then
        problems[#problems + 1] = "some cell numbers were repeated or missing and were renumbered"
    end
    nb.next_id = highest + 1

    if #nb.cells == 0 then
        nb.cells = {}
        nb:add(1)
    end
    return nb, problems, clean_scroll(data.scroll, nb)
end

-- Reads a whole settings table. Returns notebook, problems, scroll, state:
-- "ok", "repaired", "empty" (no notebook stored, notebook is nil) or
-- "newer" (written by a newer version, notebook is nil, file left alone).
function M.from_file(file)
    if type(file) ~= "table" then
        return nil, {}, nil, "empty"
    end
    if is_number(file.version) and file.version > VERSION then
        return nil, { "the saved notebook was made by a newer version of the plugin" }, nil, "newer"
    end
    local file_problems = {}
    if file.version ~= nil and file.version ~= VERSION then
        file_problems[#file_problems + 1] = "the saved notebook has an unknown version"
    end
    if file.notebooks ~= nil and type(file.notebooks) ~= "table" then
        file_problems[#file_problems + 1] = "the saved notebook list could not be read"
        local nb = notebook.new()
        return nb, file_problems, nil, "repaired"
    end
    local stored = file.notebooks and file.notebooks[NAME]
    if stored == nil then
        if #file_problems > 0 then
            return notebook.new(), file_problems, nil, "repaired"
        end
        return nil, {}, nil, "empty"
    end
    local nb, problems, scroll = M.sanitize(stored)
    for _, p in ipairs(file_problems) do
        problems[#problems + 1] = p
    end
    return nb, problems, scroll, #problems > 0 and "repaired" or "ok"
end

M.VERSION, M.NAME = VERSION, NAME

return M
