local env_mod = require("calcnb.env")
local notebook = require("calcnb.notebook")
local runner = require("calcnb.runner")
local store = require("calcnb.store_logic")

local corpus = require("spec.calcnb.compat_corpus")

local function run(source, env)
  return runner.run(source, env or env_mod.new())
end

-- What the language-1.0 runner gives for one corpus source: the old kind and
-- display or error kind for comparison, plus the message of an error.
local function outcome(source)
  local o = run(source)
  if o.kind == "error" then
    return { kind = "error", error_kind = o.error.kind, message = o.error.message }
  elseif o.kind == "graph" then
    return { kind = "graph" }
  end
  return { kind = "value", display = o.display }
end

local function same_as_old(old, new)
  if old.kind ~= new.kind then
    return false
  end
  if old.kind == "value" then
    return old.display == new.display
  elseif old.kind == "error" then
    return old.error_kind == new.error_kind
  end
  return true
end

-- Every source whose result changed in language 1.0, with the change row it
-- belongs to (see contracts/language-reference.md, "Compatibility").
local CHANGED = {
  ["2x"] = "C-1", ["3(x)"] = "C-1", ["(x)(y)"] = "C-1", ["2(x+1)"] = "C-1",
  ["(x+1)(x-1)"] = "C-1", ["1/2x"] = "C-1", ["2pi"] = "C-1", ["3sin(x)"] = "C-1",
  ["2e"] = "C-1",
  ["1e3"] = "C-2", ["1e-3"] = "C-2",
  ["diff = 3"] = "C-3", ["solve = 1"] = "C-3", ["factor(x) = x"] = "C-3",
  ["x == 1"] = "C-4", ["1 + 2 # c"] = "C-4",
  ["diff(x^2, x)"] = "C-4", ["diff(x)"] = "C-4", ["factor(x^2-1)"] = "C-4", ["approx(1/3)"] = "C-4",
}

describe("saved notebook compatibility", function()
  it("keeps the corpus large enough to mean something", function()
    assert.is_true(#corpus >= 200)
  end)

  it("gives the old result for every source, except the listed changes", function()
    local unlisted, stale = {}, {}
    local seen = {}
    for _, case in ipairs(corpus) do
      local new = outcome(case.source)
      local same = same_as_old(case.old, new)
      if not same then
        seen[case.source] = true
        if not CHANGED[case.source] then
          unlisted[#unlisted + 1] = case.source .. " -> " .. tostring(new.display or new.message)
        end
      end
    end
    for source in pairs(CHANGED) do
      if not seen[source] then
        stale[#stale + 1] = source
      end
    end
    table.sort(unlisted)
    table.sort(stale)
    assert.are.same({}, unlisted)
    assert.are.same({}, stale)
  end)

  describe("change rows", function()
    it("C-1: implicit multiplication is rejected with the fix", function()
      local cases = {
        ["2x"] = "write `2*x`", ["3(x)"] = "write `3*(x)`", ["(x)(y)"] = "write `(x)*(y)`",
        ["2pi"] = "write `2*pi`", ["3sin(x)"] = "write `3*sin(x)`", ["2(x+1)"] = "write `2*(x+1)`",
      }
      for source, fragment in pairs(cases) do
        local o = run(source)
        assert.are.equal("error", o.kind, source)
        assert.are.equal("syntax", o.error.kind, source)
        assert.is_truthy(o.error.message:find(fragment, 1, true), source .. ": " .. o.error.message)
      end
      assert.are.equal("syntax", run("2e").error.kind)
    end)

    it("C-1: the explicit forms give the old results", function()
      assert.are.equal("2*x", run("2*x").display)
      assert.are.equal("2*(x+1)", run("2*(x+1)").display)
      assert.are.equal("2*π ≈ 6.28318531", run("2*pi").display)
      assert.are.equal("2*e ≈ 5.43656366", run("2*e").display)
      assert.are.equal("2*e ≈ 5.43656366", run("2 * e").display)
    end)

    it("C-2: scientific notation is exact", function()
      assert.are.equal("1000", run("1e3").display)
      assert.are.equal("1/1000", run("1e-3").display)
    end)

    it("C-3: reserved command names cannot be assigned or defined", function()
      for _, source in ipairs({ "diff = 3", "solve = 1", "factor(x) = x", "integrate = 2", "subs = 1", "approx = 1" }) do
        local o = run(source)
        assert.are.equal("error", o.kind, source)
        assert.are.equal("reserved", o.error.kind, source)
        assert.is_truthy(o.error.message:find("reserved", 1, true), source)
      end
    end)

    it("C-4: relations, comments and reserved calls are accepted or explained", function()
      assert.are.equal("x+1 == 6", run("x + 1 == 6").display:gsub("%s*==%s*", " == "))
      assert.are.equal("3", run("1 + 2 # note").display)
      local o = run("diff(x^2, x)")
      assert.are.equal("unsupported", o.error.kind)
      assert.is_truthy(o.error.message:find("reserved for a future version", 1, true))
    end)

    it("C-5: plot bounds may be constant expressions", function()
      local o = run("plot(sin(x), x=-2*pi..2*pi)")
      assert.are.equal("graph", o.kind)
      assert.are.equal("range", run("plot(x, x=5..-5)").error.kind)
    end)
  end)

  describe("saving", function()
    local function sample()
      local nb = notebook.new("Compat")
      assert(nb:set_source(nb.cells[1].id, "2x + 1\nf(x) = 3(x+1)\n1e3"))
      local c2 = assert(nb:add(2))
      assert(nb:set_source(c2.id, "plot(f(x), x=-1..1)"))
      return nb
    end

    it("never rewrites saved text, and a reload is identical", function()
      local nb = sample()
      local before = store.to_file(nb)
      local reloaded = store.from_file(before)
      assert.are.equal("2x + 1\nf(x) = 3(x+1)\n1e3", reloaded.cells[1].source)
      assert.are.same(before, store.to_file(reloaded))
    end)

    it("does not change a cell's saved text by running it", function()
      local nb = sample()
      local before = store.to_file(nb)
      local e = env_mod.new()
      for _, cell in ipairs(nb.cells) do
        runner.run(cell.source, e)
      end
      assert.are.same(before, store.to_file(nb))
    end)

    it("keeps the source of a 100-cell notebook byte-identical through run, save and reload", function()
      local nb = notebook.new("Big")
      local sources = {}
      for i = 1, 100 do
        local source = corpus[(i - 1) % #corpus + 1].source
        sources[i] = source
        local cell = i == 1 and nb.cells[1] or assert(nb:add(i))
        assert(nb:set_source(cell.id, source))
      end
      local e = env_mod.new()
      for _, cell in ipairs(nb.cells) do
        assert.has_no.errors(function() runner.run(cell.source, e) end)
      end
      local reloaded = store.from_file(store.to_file(nb))
      assert.are.equal(100, #reloaded.cells)
      for i, cell in ipairs(reloaded.cells) do
        assert.are.equal(sources[i], cell.source)
      end
    end)

    it("restores a cell that no longer parses as an error, not as lost text", function()
      local nb = store.from_file(store.to_file(sample()))
      local o = runner.run(nb.cells[1].source, env_mod.new())
      assert.are.equal("error", o.kind)
      assert.are.equal("2x + 1\nf(x) = 3(x+1)\n1e3", nb.cells[1].source)
    end)
  end)
end)
