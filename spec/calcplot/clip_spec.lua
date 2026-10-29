local clip = require("calcplot.clip")

local function seg(x1, y1, x2, y2)
    return clip.segment(x1, y1, x2, y2, 0, 0, 100, 50)
end

describe("calcplot.clip.segment", function()
    it("keeps a segment that is fully inside", function()
        assert.are.same({ 10, 10, 20, 20 }, { seg(10, 10, 20, 20) })
    end)

    it("drops a segment fully outside", function()
        assert.is_nil(seg(-10, -10, -5, -1))
        assert.is_nil(seg(110, 0, 200, 50))
        assert.is_nil(seg(-10, 60, 110, 60))
    end)

    it("clips a segment that crosses one edge", function()
        local x1, y1, x2, y2 = seg(50, 25, 150, 25)
        assert.are.same({ 50, 25, 100, 25 }, { x1, y1, x2, y2 })
    end)

    it("clips both ends of a segment that crosses the whole box", function()
        local x1, y1, x2, y2 = seg(-50, 25, 150, 25)
        assert.are.same({ 0, 25, 100, 25 }, { x1, y1, x2, y2 })
    end)

    it("clips a diagonal at the corner region", function()
        local x1, y1, x2, y2 = seg(-10, -10, 60, 60)
        assert.is_true(math.abs(x1) < 1e-9 and math.abs(y1) < 1e-9)
        assert.is_true(math.abs(x2 - 50) < 1e-9 and math.abs(y2 - 50) < 1e-9)
    end)

    it("keeps segments that touch an edge", function()
        assert.are.same({ 0, 0, 100, 0 }, { seg(0, 0, 100, 0) })
        assert.are.same({ 100, 10, 100, 40 }, { seg(100, 10, 100, 40) })
    end)

    it("misses a segment that only passes near a corner", function()
        assert.is_nil(seg(-10, 10, 10, -10.5))
    end)

    it("handles a degenerate point", function()
        assert.are.same({ 5, 5, 5, 5 }, { seg(5, 5, 5, 5) })
        assert.is_nil(seg(-5, 5, -5, 5))
    end)

    it("handles vertical segments", function()
        assert.are.same({ 10, 0, 10, 50 }, { seg(10, -100, 10, 100) })
    end)

    it("copes with very large coordinates", function()
        local x1, y1, x2, y2 = seg(50, 25, 60, 1e7)
        assert.is_truthy(x1)
        assert.is_true(y2 <= 50 and x2 >= 50 and x2 <= 60)
        assert.is_true(y1 == 25 and x1 == 50)
    end)
end)
