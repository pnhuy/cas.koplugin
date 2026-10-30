local shortcuts = require("calcnb.shortcuts")
local calccas = require("calccas")

local function names(groups)
  local set = {}
  for _, g in ipairs(groups) do
    for _, item in ipairs(g.items) do
      set[item.label] = true
    end
  end
  return set
end

describe("calcnb.shortcuts", function()
  it("offers the engine's functions plus the cell commands", function()
    local got = names(shortcuts.groups())
    local want = { expand = true, simplify = true, plot = true }
    for _, f in ipairs(calccas.functions()) do
      want[f] = true
    end
    assert.are.same(want, got)
  end)

  it("never offers unsupported commands", function()
    local got = names(shortcuts.groups())
    for _, name in ipairs({ "diff", "solve", "factor", "integrate", "limit", "asin", "acos", "atan",
                            "plot2", "parametric", "polar" }) do
      assert.is_nil(got[name], name)
    end
  end)

  it("inserts name() with the cursor one step back", function()
    for _, g in ipairs(shortcuts.groups()) do
      for _, item in ipairs(g.items) do
        assert.are.equal(item.label .. "()", item.insert)
        assert.are.equal(1, item.back)
      end
    end
  end)

  it("hides groups that have no supported entry", function()
    local groups = shortcuts.groups({ "sin", "cos" })
    local ids = {}
    for _, g in ipairs(groups) do
      ids[#ids + 1] = g.id
      assert.is_true(#g.items > 0)
    end
    assert.is_nil(names(groups).sqrt)
    for _, id in ipairs(ids) do
      assert.are_not.equal("basic", id)
    end
  end)

  it("starts with a common group of at most six keys", function()
    local first = shortcuts.groups()[1]
    assert.are.equal("common", first.id)
    assert.is_true(#first.items <= 6)
    assert.are.equal("sin", first.items[1].label)
  end)

  describe("slides", function()
    it("pages a group when it does not fit the row", function()
      local slides = shortcuts.slides(shortcuts.groups(), 4)
      for _, s in ipairs(slides) do
        assert.is_true(#s.items <= 4)
        assert.is_true(#s.items >= 1)
      end
      local seen = {}
      for _, s in ipairs(slides) do
        for _, item in ipairs(s.items) do
          seen[item.label] = true
        end
      end
      assert.are.same(names(shortcuts.groups()), seen)
    end)

    it("keeps the group id and a label on every slide", function()
      for _, s in ipairs(shortcuts.slides(shortcuts.groups(), 4)) do
        assert.is_string(s.id)
        assert.is_string(s.label)
      end
    end)
  end)
end)
