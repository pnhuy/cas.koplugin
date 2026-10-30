-- Tracks whether a notebook has changes that are not saved yet. `watch`
-- wraps the mutating notebook operations on one instance; running cells and
-- clearing outputs do not count because outputs are never stored.

local M = {}

local Dirty = {}
Dirty.__index = Dirty

function M.new()
    return setmetatable({ dirty = false }, Dirty)
end

function Dirty:is_dirty()
    return self.dirty
end

function Dirty:mark()
    self.dirty = true
end

-- Records the outcome of a save: only a successful one clears the flag.
function Dirty:saved(ok)
    if ok then
        self.dirty = false
    end
end

-- Runs `writer` (returns true on success); an error counts as a failure.
function Dirty:save(writer)
    local ok, result = pcall(writer)
    local done = ok and result == true
    self:saved(done)
    return done
end

-- Wraps `name` so a result that `changed(result)` accepts marks the flag.
local function wrap(self, nb, name, changed)
    local original = nb[name]
    nb[name] = function(this, ...)
        local first, second = original(this, ...)
        if changed(first) then
            self:mark()
        end
        return first, second
    end
end

function Dirty:watch(nb)
    local function truthy(result)
        return result ~= nil and result ~= false
    end
    for _, name in ipairs({ "add", "add_above", "add_below", "duplicate", "delete", "move" }) do
        wrap(self, nb, name, truthy)
    end

    local set_source = nb.set_source
    nb.set_source = function(this, id, text)
        local cell = this:get(id)
        local before = cell and cell.source
        local ok, err = set_source(this, id, text)
        if ok and cell.source ~= before then
            self:mark()
        end
        return ok, err
    end

    local set_title = nb.set_title
    nb.set_title = function(this, title)
        local before = this.title
        set_title(this, title)
        if this.title ~= before then
            self:mark()
        end
    end
end

return M
