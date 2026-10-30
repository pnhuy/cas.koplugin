local calccas = require("calccas")
local registry = require("calccas.registry")
local suite = require("spec.calccas.conformance_cases")

local function read(path)
  local f = assert(io.open(path), path)
  local text = f:read("*a")
  f:close()
  return text
end

local reference = read("docs/language/reference-1.0.md")

local function arity_text(entry)
  local lo, hi = entry.arity[1], entry.arity[2]
  return lo == hi and tostring(lo) or (lo .. " to " .. hi)
end

describe("language reference", function()
  it("states the version the engine reports", function()
    local version = reference:match("%*%*Language version ([%d%.]+)%*%*")
    assert.are.equal(calccas.LANGUAGE_VERSION, version)
    assert.are.equal(registry.VERSION, version)
  end)

  it("has a function table equal to the registry", function()
    local block = reference:match("<!%-%- registry:begin %-%->(.-)<!%-%- registry:end %-%->")
    assert.is_truthy(block, "registry markers")
    local rows = {}
    for name, kind, args, status in block:gmatch("\n| `([%w_]+)` | (%a+) | ([^|]-) | (%a+) |") do
      rows[name] = { kind = kind, args = args, status = status }
    end
    local expected = registry.reserved_names()
    for _, name in ipairs(expected) do
      local entry = registry.get(name)
      local row = rows[name]
      assert.is_truthy(row, name .. " missing from the reference")
      assert.are.equal(entry.kind, row.kind, name)
      assert.are.equal(arity_text(entry), row.args, name)
      assert.are.equal(entry.status, row.status, name)
      rows[name] = nil
    end
    assert.are.same({}, rows)
  end)

  it("lists every reserved name in the reserved-names section", function()
    local section = reference:match("## 13%. Reserved names(.-)## 14%.")
    assert.is_truthy(section)
    for _, name in ipairs(registry.reserved_names()) do
      assert.is_truthy(section:find("%f[%w_]" .. name .. "%f[^%w_]"), name)
    end
  end)

  it("tags examples only with conformance case ids", function()
    local known = {}
    for _, case in ipairs(suite.cases) do
      known[case.id] = true
    end
    local count = 0
    for id in reference:gmatch("<!%-%- case: (G%-[%w%-]+) %-%->") do
      count = count + 1
      assert.is_true(known[id], id)
    end
    for id in reference:gmatch("| (G%-%d%d%a?%-%a) |") do
      assert.is_true(known[id], id)
    end
    assert.is_true(count >= 40)
  end)

  it("has all 17 sections", function()
    for n = 1, 17 do
      assert.is_truthy(reference:find("\n## " .. n .. "%. "), "section " .. n)
    end
  end)
end)

describe("future features", function()
  local future = read("docs/language/future.md")

  it("says none of them is available and names the reserved commands", function()
    assert.is_truthy(future:find("None of the features below is available", 1, true))
    for _, name in ipairs(registry.reserved_names()) do
      local entry = registry.get(name)
      if entry.status == "reserved" then
        assert.is_truthy(future:find("`" .. name .. "`", 1, true), name)
      end
    end
  end)

  it("is linked from the reference, which never lists a reserved command as implemented", function()
    assert.is_truthy(reference:find("future.md", 1, true))
    for _, name in ipairs(registry.reserved_names()) do
      if registry.get(name).status == "reserved" then
        assert.is_nil(reference:find("| `" .. name .. "` | %a+ | [^|]+ | implemented"), name)
      end
    end
  end)
end)

describe("grammar and error documents", function()
  it("ship with the reference, using the contract's rule ids", function()
    local grammar = read("docs/language/grammar.md")
    local contract = read("specs/003-expression-language-standard/contracts/grammar.md")
    for id in contract:gmatch("G%-%d%d%a?") do
      assert.is_truthy(grammar:find(id, 1, true), id)
    end
    local errors_doc = read("docs/language/errors.md")
    for _, kind in ipairs({ "syntax", "reserved", "unsupported", "domain", "div_by_zero", "overflow", "too_complex", "range" }) do
      assert.is_truthy(errors_doc:find("`" .. kind .. "`", 1, true), kind)
    end
  end)
end)
