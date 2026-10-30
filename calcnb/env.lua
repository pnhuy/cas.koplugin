-- Variables and user functions shared by the cells of a notebook.
-- Values are whatever `calccas.evaluate(expr, vars)` accepts; functions are
-- `{params, body}` ASTs usable as `user_funcs` by the engine.

local ast = require("calccas.ast")
local statement = require("calcnb.statement")

local M = {}

local MAX_NAMES = 100

local Env = {}
Env.__index = Env

local function copy(t)
    local out = {}
    for k, v in pairs(t) do
        out[k] = v
    end
    return out
end

function M.new()
    return setmetatable({ vars = {}, funcs = {}, count = 0, version = 0 }, Env)
end

function Env:has(name)
    return self.vars[name] ~= nil or self.funcs[name] ~= nil
end

local function check(self, name)
    if statement.RESERVED[name] then
        return false, { kind = "reserved", message = "Name is reserved" }
    end
    if not self:has(name) and self.count >= MAX_NAMES then
        return false, { kind = "too_complex", message = "Too many names (limit " .. MAX_NAMES .. ")" }
    end
    return true
end

local function same_value(a, b)
    if type(a) == "table" and type(b) == "table" then
        return ast.equal(a, b)
    end
    return a == b
end

local function same_func(a, b)
    if a == nil or b == nil or #a.params ~= #b.params then
        return false
    end
    for i, p in ipairs(a.params) do
        if p ~= b.params[i] then
            return false
        end
    end
    return ast.equal(a.body, b.body)
end

-- `version` counts real changes: redefining a name with an equal value keeps it.
local function define(self, name, vars_value, func_value)
    local ok, err = check(self, name)
    if not ok then
        return false, err
    end
    local unchanged
    if vars_value ~= nil then
        unchanged = self.vars[name] ~= nil and same_value(self.vars[name], vars_value)
    else
        unchanged = same_func(self.funcs[name], func_value)
    end
    if not self:has(name) then
        self.count = self.count + 1
    end
    if not unchanged then
        self.version = self.version + 1
    end
    self.vars[name] = vars_value
    self.funcs[name] = func_value
    return true
end

function Env:set_var(name, value)
    return define(self, name, value, nil)
end

-- `params` is a list of parameter names (or one name).
function Env:set_func(name, params, body)
    if type(params) == "string" then
        params = { params }
    end
    return define(self, name, nil, { params = params, param = params[1], body = body })
end

function Env:names()
    local names = {}
    for name in pairs(self.vars) do
        names[#names + 1] = name
    end
    for name in pairs(self.funcs) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function Env:snapshot()
    return { vars = copy(self.vars), funcs = copy(self.funcs), count = self.count, version = self.version }
end

function Env:restore(snap)
    self.vars = copy(snap.vars)
    self.funcs = copy(snap.funcs)
    self.count = snap.count
    self.version = snap.version
end

function Env:clear()
    if self.count > 0 then
        self.version = self.version + 1
    end
    self.vars, self.funcs, self.count = {}, {}, 0
end

return M
