local registry = require("calccas.registry")
local calccas = require("calccas")
local eval = require("calccas.eval")
local statement = require("calcnb.statement")
local shortcuts = require("calcnb.shortcuts")

local function sorted(set)
  local list = {}
  for name in pairs(set) do
    list[#list + 1] = name
  end
  table.sort(list)
  return list
end

describe("calccas.registry", function()
  it("reserves every registry name and alias in the notebook layer", function()
    for _, name in ipairs(registry.reserved_names()) do
      assert.is_true(statement.RESERVED[name], name)
    end
    local reserved = {}
    for name in pairs(statement.RESERVED) do
      reserved[#reserved + 1] = name
    end
    table.sort(reserved)
    assert.are.same(registry.reserved_names(), reserved)
  end)

  it("reserves the planned command names without implementing them", function()
    for _, name in ipairs({ "factor", "solve", "diff", "integrate", "subs", "approx" }) do
      local entry = registry.get(name)
      assert.are.equal("reserved", entry.status, name)
      assert.are.equal("command", entry.kind, name)
      assert.is_true(registry.is_reserved(name), name)
    end
  end)

  it("has an implementation for every implemented function and no stray implementation", function()
    local implemented = {}
    for _, name in ipairs(registry.canonical_functions()) do
      assert.is_function(eval.IMPLEMENTATIONS[name], name)
      implemented[name] = true
    end
    for name in pairs(eval.IMPLEMENTATIONS) do
      assert.is_true(implemented[name], name)
    end
  end)

  it("gives the facade the same function list", function()
    assert.are.same(registry.functions(), calccas.functions())
  end)

  it("offers only registered, implemented names on the keyboard", function()
    for _, group in ipairs(shortcuts.groups()) do
      for _, item in ipairs(group.items) do
        local entry = registry.get(item.label)
        assert.is_not_nil(entry, item.label)
        assert.are.equal("implemented", entry.status, item.label)
      end
    end
  end)

  it("resolves ln to log", function()
    assert.are.equal("log", registry.canonical("ln"))
    assert.are.equal("log", registry.canonical("log"))
    assert.is_nil(registry.canonical("diff"))
    assert.are.same({ "abs", "cos", "exp", "ln", "log", "sin", "sqrt", "tan" }, sorted(registry.function_set()))
  end)
end)
