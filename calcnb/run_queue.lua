-- Sequencing of cell runs: one at a time, in order, errors do not stop the
-- queue (the caller records them on the cell). Pure; the UI pulls the next id
-- once per tick.

local M = {}

local Queue = {}
Queue.__index = Queue

function M.new()
    return setmetatable({ ids = {}, first = 1, current = nil, was_cancelled = false }, Queue)
end

function Queue:busy()
    return self.current ~= nil or self.first <= #self.ids
end

function Queue:pending()
    return #self.ids - self.first + 1
end

function Queue:cancelled()
    return self.was_cancelled
end

function Queue:start(ids)
    if self:busy() then
        return nil, "busy"
    end
    local copy = {}
    for i, id in ipairs(ids) do
        copy[i] = id
    end
    self.ids, self.first, self.was_cancelled = copy, 1, false
    return true
end

-- Next id to run, or nil when the queue is empty or a cell is still running.
function Queue:next()
    if self.current or self.first > #self.ids then
        return nil
    end
    self.current = self.ids[self.first]
    self.first = self.first + 1
    return self.current
end

function Queue:done()
    self.current = nil
end

-- Drops every cell that has not started; the running one finishes via done().
function Queue:cancel()
    self.ids, self.first, self.was_cancelled = {}, 1, true
end

return M
