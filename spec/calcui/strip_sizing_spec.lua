local sizing = require("calcui.strip_sizing")

local LINE_H = 40
local OTHER_H = 120

local function size(w, h, keyboard_h)
    return sizing.strip_height(h, w, keyboard_h, OTHER_H, LINE_H)
end

describe("calcui.strip_sizing", function()
    it("gives two rows when the screen is tall enough (portrait)", function()
        local s = size(600, 800, 360)
        assert.are.equal(2, s.rows)
        assert.are.equal(2 * LINE_H, s.height)
        local s2 = size(1072, 1448, 652)
        assert.are.equal(2, s2.rows)
    end)

    it("gives one row when two would leave too little page (landscape)", function()
        local s = size(800, 600, 270)
        assert.are.equal(1, s.rows)
        assert.are.equal(LINE_H, s.height)
    end)

    it("turns the strip off on a very small screen", function()
        local s = size(480, 320, 144)
        assert.are.equal(0, s.rows)
        assert.are.equal(0, s.height)
    end)

    it("never leaves fewer than MIN_PAGE_LINES editor lines above the strip", function()
        for _, case in ipairs({
            { 600, 800, 360 }, { 800, 600, 270 }, { 1072, 1448, 652 }, { 480, 320, 144 },
            { 540, 720, 324 }, { 800, 400, 220 }, { 1264, 1680, 756 },
        }) do
            local s = size(case[1], case[2], case[3])
            if s.rows > 0 then
                local page = case[2] - case[3] - OTHER_H - s.height
                assert.is_true(page >= sizing.MIN_PAGE_LINES * LINE_H)
            end
            assert.are.equal(s.rows * LINE_H, s.height)
        end
    end)

    it("gives equal results for equal inputs", function()
        assert.are.same(size(600, 800, 360), size(600, 800, 360))
    end)

    it("gives no rows for zero or negative sizes", function()
        assert.are.equal(0, sizing.strip_height(0, 0, 0, 0, 0).rows)
        assert.are.equal(0, sizing.strip_height(-5, 600, 100, 50, 40).rows)
        assert.are.equal(0, sizing.strip_height(800, 600, 100, 50, -1).rows)
        assert.are.equal(0, sizing.strip_height(nil, nil, nil, nil, nil).rows)
        assert.are.equal(0, sizing.strip_height(800, 600, 900, 50, 40).rows)
    end)
end)
