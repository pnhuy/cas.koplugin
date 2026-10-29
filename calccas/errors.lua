-- Typed errors for the CAS and plotting engines.
-- Engines return `nil, err` instead of throwing; `err` is built here.

local M = {}

local KINDS = {
    syntax = true,       -- malformed input; `pos` is the 1-based character position
    domain = true,       -- math domain violation (sqrt(-1), log(0))
    div_by_zero = true,
    overflow = true,     -- exact arithmetic or magnitude limit exceeded
    too_complex = true,  -- a resource limit (length, depth, nodes, terms) was hit
    unsupported = true,  -- valid syntax the engine does not handle
    undefined = true,    -- value undefined at this point (e.g. 0^0)
    unbound_variable = true, -- free variable with no value where one is required
    internal = true,     -- unexpected failure caught at a boundary
    range = true,        -- invalid plot range (non-finite, reversed, too small or too large)
}

local Error = {}
Error.__index = Error

function Error:__tostring()
    if self.pos then
        return string.format("%s error at %d: %s", self.kind, self.pos, self.message)
    end
    return string.format("%s error: %s", self.kind, self.message)
end

function M.new(kind, message, pos)
    assert(KINDS[kind], "unknown error kind: " .. tostring(kind))
    return setmetatable({ kind = kind, message = message, pos = pos }, Error)
end

function M.is(value)
    return getmetatable(value) == Error
end

return M
