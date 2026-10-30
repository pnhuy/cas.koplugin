local session_mod = require("calcnb.completion_session")

local function names(model)
    local list = {}
    for i, item in ipairs(model.items) do
        list[i] = item.name
    end
    return list
end

describe("calcnb.completion_session", function()
    local s

    before_each(function()
        s = session_mod.new()
    end)

    it("is hidden until a word is typed", function()
        assert.is_nil(s:model())
        assert.is_false(s:update("", 1))
        assert.is_nil(s:model())
    end)

    it("reports a change on first show and none when nothing changed", function()
        assert.is_true(s:update("dif", 4))
        assert.are.same({ "diff" }, names(s:model()))
        assert.is_false(s:update("dif", 4))
        assert.is_false(s:update("di", 3)) -- same single suggestion: nothing to redraw
        assert.is_true(s:update("s", 2))
        assert.is_true(s:update("", 1))
        assert.is_nil(s:model())
        assert.is_false(s:update("", 1))
    end)

    it("narrows the list as more is typed and resets the highlight", function()
        s:update("s", 2)
        assert.are.equal("sin", s:model().items[1].name)
        s:move(1)
        assert.are.equal(2, s:model().highlight)
        s:update("si", 3)
        assert.are.same({ "sin", "simplify" }, names(s:model()))
        assert.are.equal(1, s:model().highlight)
    end)

    it("keeps the highlight when the cursor and text stay as they are", function()
        s:update("s", 2)
        s:move(1)
        assert.is_false(s:update("s", 2))
        assert.are.equal(2, s:model().highlight)
    end)

    it("wraps the highlight with move", function()
        s:update("si", 3)
        assert.is_true(s:move(1))
        assert.are.equal(2, s:model().highlight)
        assert.is_true(s:move(1))
        assert.are.equal(1, s:model().highlight)
        assert.is_true(s:move(-1))
        assert.are.equal(2, s:model().highlight)
    end)

    it("does not report a change when move has nothing to move to", function()
        assert.is_false(s:move(1))
        s:update("dif", 4)
        assert.is_false(s:move(1))
        assert.are.equal(1, s:model().highlight)
    end)

    it("select moves the highlight without accepting", function()
        s:update("si", 3)
        assert.is_true(s:select(2))
        assert.are.equal(2, s:model().highlight)
        assert.is_false(s:select(2))
        assert.is_false(s:select(0))
        assert.is_false(s:select(3))
        assert.is_false(s:select("1"))
        assert.is_false(s:select(1.5))
        assert.are.equal(2, s:model().highlight)
        assert.are.same({ "sin", "simplify" }, names(s:model()))
    end)

    it("accept returns the edit for the highlighted item and hides the strip", function()
        s:update("1 + si + 2", 7)
        s:select(2)
        local edit = s:accept()
        assert.are.equal("1 + simplify() + 2", edit.text)
        assert.are.equal(14, edit.charpos)
        assert.is_nil(s:model())
        assert.is_nil(s:accept())
    end)

    it("accept gives diff() with the cursor inside the brackets", function()
        s:update("dif", 4)
        local edit = s:accept()
        assert.are.equal("diff()", edit.text)
        assert.are.equal(6, edit.charpos)
    end)

    it("stays hidden for a constant just accepted, until a new word starts", function()
        s:update("2 * p", 6)
        local edit = s:accept()
        assert.are.equal("2 * pi", edit.text)
        assert.is_false(s:update(edit.text, edit.charpos))
        assert.is_nil(s:model())
        assert.is_true(s:update("2 * pi + s", 11))
    end)

    it("offers the names it was given", function()
        s:set_names({ { name = "rate", kind = "var" } })
        s:update("ra", 3)
        assert.are.same({ "rate" }, names(s:model()))
        s:set_names({ { name = "speed", kind = "var" } })
        assert.is_true(s:update("ra", 3))
        assert.is_nil(s:model())
        s:update("spe", 4)
        assert.are.same({ "speed" }, names(s:model()))
    end)

    it("honours the chip limit", function()
        s:set_limit(2)
        s:update("s", 2)
        assert.are.equal(2, #s:model().items)
        assert.are.equal(3, s:model().more)
    end)

    it("hides the strip instead of raising when matching fails", function()
        local failing = false
        local real = require("calcnb.completion").suggest
        local bad = session_mod.new({
            suggest = function(...)
                if failing then
                    error("boom")
                end
                return real(...)
            end,
        })
        assert.is_true(bad:update("si", 3))
        failing = true
        local ok, changed = pcall(bad.update, bad, "sin", 4)
        assert.is_true(ok)
        assert.is_true(changed)
        assert.is_nil(bad:model())
        assert.is_false(bad:update("sin", 4))
        failing = false
        assert.is_true(bad:update("sin", 4))
    end)
end)

describe("calcnb.completion_session dismissal", function()
    local s

    before_each(function()
        s = session_mod.new()
    end)

    it("hides the strip and returns true; the text is the caller's and stays as it is", function()
        s:update("dif", 4)
        assert.is_true(s:dismiss())
        assert.is_nil(s:model())
    end)

    it("returns false when nothing is shown", function()
        assert.is_false(s:dismiss())
        s:update("zzz", 4)
        assert.is_false(s:dismiss())
    end)

    it("stays hidden while the cursor stays in the same word", function()
        s:update("dif", 4)
        s:dismiss()
        assert.is_false(s:update("dif", 4))
        assert.is_false(s:update("difx", 5))
        assert.is_false(s:update("dif", 2))
        assert.is_nil(s:model())
    end)

    it("shows again for a new word", function()
        s:update("dif", 4)
        s:dismiss()
        assert.is_true(s:update("dif + si", 9))
        assert.are.same({ "sin", "simplify" }, names(s:model()))
    end)

    it("shows again for the same text on another line", function()
        s:update("di\ndi", 3)
        s:dismiss()
        assert.is_true(s:update("di\ndi", 6))
        assert.are.same({ "diff" }, names(s:model()))
    end)

    it("shows again once the cursor has left the word, even for the same word", function()
        s:update("dif + 1", 4)
        s:dismiss()
        assert.is_false(s:update("dif + 1", 8)) -- no word under the cursor
        assert.is_true(s:update("dif + 1", 4))
    end)
end)
