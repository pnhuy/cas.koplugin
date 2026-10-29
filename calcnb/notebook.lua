-- Notebook model: ordered cells, a shared environment and conservative
-- staleness. Pure Lua; every operation returns a value or `nil, err`.

local env_mod = require("calcnb.env")
local runner = require("calcnb.runner")

local M = {}

local MAX_CELLS = 200
local MAX_SOURCE = 5000
local MAX_TITLE = 60
local DEFAULT_TITLE = "Notebook"

local Notebook = {}
Notebook.__index = Notebook

-- True if `s` is well-formed UTF-8.
local function valid_utf8(s)
    local i, n = 1, #s
    while i <= n do
        local b = s:byte(i)
        local len
        if b < 0x80 then
            len = 1
        elseif b >= 0xC2 and b <= 0xDF then
            len = 2
        elseif b >= 0xE0 and b <= 0xEF then
            len = 3
        elseif b >= 0xF0 and b <= 0xF4 then
            len = 4
        else
            return false
        end
        for k = 1, len - 1 do
            local c = s:byte(i + k)
            if not c or c < 0x80 or c > 0xBF then
                return false
            end
        end
        i = i + len
    end
    return true
end

local function copy(t)
    if type(t) ~= "table" then
        return t
    end
    local out = {}
    for k, v in pairs(t) do
        out[k] = copy(v)
    end
    return out
end

function M.new(title)
    local nb = setmetatable({
        title = DEFAULT_TITLE,
        cells = {},
        next_id = 1,
        exec_counter = 0,
        env = env_mod.new(),
    }, Notebook)
    nb:set_title(title)
    nb:add(1)
    return nb
end

function Notebook:set_title(title)
    local t = (title or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if t == "" then
        t = DEFAULT_TITLE
    end
    self.title = t:sub(1, MAX_TITLE)
end

function Notebook:index_of(id)
    for i, c in ipairs(self.cells) do
        if c.id == id then
            return i
        end
    end
end

function Notebook:get(id)
    local i = self:index_of(id)
    return i and self.cells[i] or nil, i
end

local function new_cell(self, cell_type)
    local cell = {
        id = self.next_id,
        type = cell_type or "code",
        source = "",
        status = "idle",
        out_of_date = false,
    }
    self.next_id = self.next_id + 1
    return cell
end

local function full(self)
    if #self.cells >= MAX_CELLS then
        return { kind = "limit", message = "A notebook holds at most " .. MAX_CELLS .. " cells" }
    end
end

-- Executed cells no longer reflect the current order or environment.
local function mark_all_stale(self)
    for _, c in ipairs(self.cells) do
        if c.status == "completed" then
            c.status = "stale"
        end
    end
end

-- Inserts an empty cell at `index` (1..#cells + 1).
function Notebook:add(index, cell_type)
    local err = full(self)
    if err then
        return nil, err
    end
    index = math.max(1, math.min(index or #self.cells + 1, #self.cells + 1))
    local cell = new_cell(self, cell_type)
    table.insert(self.cells, index, cell)
    return cell
end

function Notebook:add_above(id)
    local _, i = self:get(id)
    return self:add(i or 1)
end

function Notebook:add_below(id)
    local _, i = self:get(id)
    return self:add((i or #self.cells) + 1)
end

function Notebook:duplicate(id)
    local src, i = self:get(id)
    if not src then
        return nil, { kind = "internal", message = "no such cell" }
    end
    local err = full(self)
    if err then
        return nil, err
    end
    local cell = new_cell(self, src.type)
    cell.source = src.source
    cell.viewport = copy(src.viewport)
    table.insert(self.cells, i + 1, cell)
    return cell
end

function Notebook:delete(id)
    local _, i = self:get(id)
    if not i then
        return false
    end
    table.remove(self.cells, i)
    if #self.cells == 0 then
        self:add(1)
    end
    mark_all_stale(self)
    return true
end

function Notebook:move(id, delta)
    local cell, i = self:get(id)
    local j = i and i + delta
    if not i or j < 1 or j > #self.cells or j == i then
        return false
    end
    table.remove(self.cells, i)
    table.insert(self.cells, j, cell)
    mark_all_stale(self)
    return true
end

local function normalize(text)
    return (text:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\t", "  "))
end

function Notebook:set_source(id, text)
    local cell = self:get(id)
    if not cell then
        return nil, { kind = "internal", message = "no such cell" }
    end
    if not valid_utf8(text) then
        return nil, { kind = "encoding", message = "Text is not valid UTF-8" }
    end
    text = normalize(text)
    if #text > MAX_SOURCE then
        return nil, { kind = "limit", message = "A cell holds at most " .. MAX_SOURCE .. " characters" }
    end
    if text ~= cell.source then
        cell.source = text
        if cell.output then
            cell.out_of_date = true
        end
    end
    return true
end

function Notebook:clear_output(id)
    local cell = self:get(id)
    if cell then
        cell.output, cell.exec_number, cell.ran_at_env = nil, nil, nil
        cell.out_of_date = false
        cell.status = "idle"
    end
end

function Notebook:clear_all_outputs()
    for _, c in ipairs(self.cells) do
        self:clear_output(c.id)
    end
end

-- Runs one code cell against the shared environment. `opts` goes to the
-- runner (`yield`). Returns the Output, or nil for non-code cells.
function Notebook:run_cell(id, opts)
    local cell, i = self:get(id)
    if not cell or cell.type ~= "code" then
        return nil
    end
    local before = self.env.version
    cell.status = "running"
    local out = runner.run(cell.source, self.env, opts)
    self.exec_counter = self.exec_counter + 1
    cell.output = out
    cell.exec_number = self.exec_counter
    cell.ran_at_env = self.env.version
    cell.out_of_date = false
    cell.status = out.kind == "error" and "error" or "completed"
    if self.env.version ~= before then
        for j = i + 1, #self.cells do
            local later = self.cells[j]
            if later.status == "completed" and (later.ran_at_env or 0) < self.env.version then
                later.status = "stale"
            end
        end
    end
    return out
end

-- Resets the environment and returns the ids of the code cells in order; the
-- caller runs them one by one (one per UI tick).
function Notebook:begin_run_all()
    self.env:clear()
    local ids = {}
    for _, c in ipairs(self.cells) do
        if c.type == "code" then
            ids[#ids + 1] = c.id
        end
    end
    return ids
end

M.MAX_CELLS, M.MAX_SOURCE, M.valid_utf8 = MAX_CELLS, MAX_SOURCE, valid_utf8

return M
