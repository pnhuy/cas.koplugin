local layout = require("calcnb.keyboard_layout")

local ACTIONS = {
  shift = true, sym = true, backspace = true, delete = true, left = true, right = true, up = true,
  down = true, home = true, ["end"] = true, enter = true, space = true, select_all = true,
  copy = true, cut = true, paste = true, run = true, group = true,
}

local function each_key(pages, fn)
  for page, rows in pairs(pages) do
    for r, row in ipairs(rows) do
      for k, key in ipairs(row) do
        fn(key, page, r, k)
      end
    end
  end
end

local function union(pages)
  local set = {}
  each_key(pages, function(key)
    set[(key.label or "") .. "|" .. (key.insert or "") .. "|" .. (key.action or "")] = true
  end)
  return set
end

describe("calcnb.keyboard_layout", function()
  for _, compact in ipairs({ false, true }) do
    local pages = layout.pages(compact)
    local tag = compact and "compact" or "full"

    it(tag .. ": has letters, shift and symbols pages", function()
      assert.is_table(pages.letters)
      assert.is_table(pages.shift)
      assert.is_table(pages.symbols)
    end)

    it(tag .. ": every printable ASCII except ` and ~ is a key without long-press", function()
      local have = {}
      each_key(pages, function(key)
        if key.insert and #key.insert == 1 then
          have[key.insert] = true
        end
        if key.action == "space" then
          have[" "] = true
        end
      end)
      for b = 32, 126 do
        local c = string.char(b)
        if c ~= "`" and c ~= "~" then
          assert.is_true(have[c] == true, "missing " .. c)
        end
      end
    end)

    it(tag .. ": pi inserts pi", function()
      local found
      each_key(pages, function(key)
        if key.label == "π" then
          found = key
        end
      end)
      assert.is_truthy(found)
      assert.are.equal("pi", found.insert)
    end)

    it(tag .. ": multi-character comparison keys exist", function()
      local have = {}
      each_key(pages, function(key)
        if key.insert then
          have[key.insert] = true
        end
      end)
      for _, op in ipairs({ "<=", ">=", "==", "!=" }) do
        assert.is_true(have[op] == true, op)
      end
    end)

    it(tag .. ": only Enter inserts a newline, and only by action", function()
      each_key(pages, function(key)
        assert.is_nil(key.insert and key.insert:find("\n", 1, true))
      end)
      local enter = 0
      each_key(pages, function(key)
        if key.action == "enter" then
          enter = enter + 1
        end
      end)
      assert.is_true(enter >= 3) -- one on every page
    end)

    it(tag .. ": every key has a label and either insert or a known action", function()
      each_key(pages, function(key)
        assert.is_string(key.label)
        assert.is_true((key.insert ~= nil) ~= (key.action ~= nil))
        if key.action then
          assert.is_true(ACTIONS[key.action], tostring(key.action))
        end
        assert.is_true((key.back or 0) >= 0)
      end)
    end)

    it(tag .. ": every page can reach Backspace, Sym or letters, Shift and Space", function()
      local function has(page, action)
        local found
        for _, row in ipairs(pages[page]) do
          for _, key in ipairs(row) do
            found = found or key.action == action
          end
        end
        return found
      end
      for _, page in ipairs({ "letters", "shift", "symbols" }) do
        assert.is_truthy(has(page, "backspace"), page)
        assert.is_truthy(has(page, "sym"), page)
        assert.is_truthy(has(page, "space") or page == "symbols", page)
      end
      assert.is_truthy(has("letters", "shift"))
      assert.is_truthy(has("shift", "shift"))
    end)

    it(tag .. ": editing keys are available on the symbols page", function()
      local got = {}
      for _, row in ipairs(pages.symbols) do
        for _, key in ipairs(row) do
          got[key.action or "-"] = true
        end
      end
      for _, a in ipairs({ "home", "end", "up", "down", "delete", "select_all", "copy", "cut", "paste" }) do
        assert.is_true(got[a] == true, a)
      end
    end)

    it(tag .. ": the shift page has capital letters", function()
      local have = {}
      each_key({ shift = pages.shift }, function(key)
        if key.insert then
          have[key.insert] = true
        end
      end)
      for b = string.byte("A"), string.byte("Z") do
        assert.is_true(have[string.char(b)] == true, string.char(b))
      end
    end)
  end

  it("compact keeps the union of keys of the full layout", function()
    local full, compact = union(layout.pages(false)), union(layout.pages(true))
    for k in pairs(full) do
      assert.is_true(compact[k] == true, k)
    end
    for k in pairs(compact) do
      assert.is_true(full[k] == true, k)
    end
  end)

  it("compact has fewer keys on the operator row of the letters page", function()
    local function count(pages)
      local n = 0
      for _, row in ipairs(pages.letters) do
        n = n + #row
      end
      return n
    end
    assert.is_true(count(layout.pages(true)) < count(layout.pages(false)))
  end)

  it("builds the shortcut row with a group switch key", function()
    local slide = { id = "trig", label = "trig", items = { { label = "sin", insert = "sin()", back = 1 } } }
    local row = layout.shortcut_row(slide)
    assert.are.equal("sin", row[1].label)
    assert.are.equal("sin()", row[1].insert)
    assert.are.equal(1, row[1].back)
    assert.are.equal("group", row[#row].action)
  end)

  it("tells compact from full by width", function()
    assert.is_true(layout.is_compact(400))
    assert.is_false(layout.is_compact(540))
  end)
end)
