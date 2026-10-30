local registry = require("calccas.registry")
local builtin_docs = require("calccas.builtin_docs")
local runner = require("calcnb.runner")
local env_mod = require("calcnb.env")

local function read(path)
  local f = assert(io.open(path, "r"))
  local text = f:read("*a")
  f:close()
  return text
end

describe("calccas.builtin_docs", function()
  it("has an entry for every registry name and no other", function()
    for _, name in ipairs(registry.reserved_names()) do
      assert.is_table(builtin_docs.get(name), name)
    end
    for name in pairs(builtin_docs.all()) do
      assert.is_truthy(registry.get(name), name .. " is not in the registry")
    end
  end)

  it("gives each entry a signature, a one-line summary and an example", function()
    for _, name in ipairs(registry.reserved_names()) do
      local doc = builtin_docs.get(name)
      assert.is_string(doc.signature, name)
      assert.is_truthy(doc.signature:find(name, 1, true), name)
      assert.is_string(doc.summary, name)
      assert.is_nil(doc.summary:find("\n"), name)
      assert.is_true(#doc.summary > 0 and #doc.summary <= 60, name)
      assert.is_table(doc.examples, name)
      assert.is_true(#doc.examples >= 1, name)
    end
  end)

  it("makes the examples of implemented names evaluate without error", function()
    for _, name in ipairs(registry.reserved_names()) do
      if registry.get(name).status == "implemented" then
        for _, example in ipairs(builtin_docs.get(name).examples) do
          local out = runner.run(example, env_mod.new())
          assert.is_not.equal("error", out.kind, name .. ": " .. example)
        end
      end
    end
  end)

  it("gives plot examples that draw a graph", function()
    for _, example in ipairs(builtin_docs.get("plot").examples) do
      assert.are.equal("graph", runner.run(example, env_mod.new()).kind, example)
    end
  end)

  it("makes the examples of reserved names give the reserved error", function()
    for _, name in ipairs(registry.reserved_names()) do
      if registry.get(name).status == "reserved" then
        for _, example in ipairs(builtin_docs.get(name).examples) do
          local out = runner.run(example, env_mod.new())
          assert.are.equal("error", out.kind, example)
          assert.are.equal("unsupported", out.error.kind, example)
        end
      end
    end
  end)

  it("notes the alias and the reserved status", function()
    assert.is_truthy(builtin_docs.get("ln").note:find("log", 1, true))
    for _, name in ipairs(registry.reserved_names()) do
      if registry.get(name).status == "reserved" then
        assert.is_truthy(builtin_docs.get(name).note:find("reserved", 1, true), name)
      end
    end
  end)

  it("lists every signature in the language reference", function()
    local reference = read("docs/language/reference-1.0.md")
    for _, name in ipairs(registry.reserved_names()) do
      assert.is_truthy(reference:find("`" .. builtin_docs.get(name).signature .. "`", 1, true), name)
    end
  end)

  it("returns nil for an unknown name", function()
    assert.is_nil(builtin_docs.get("nosuch"))
    assert.is_nil(builtin_docs.get(nil))
  end)
end)
