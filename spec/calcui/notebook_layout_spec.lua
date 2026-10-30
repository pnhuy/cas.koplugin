local layout = require("calcui.notebook_layout")

describe("calcui.notebook_layout", function()
    local heights = { 100, 100, 100, 100, 100 }

    it("lists the cells that fit from the top index", function()
        local v = layout.visible(heights, 2, 250)
        assert.are.equal(2, v.first)
        assert.are.equal(4, v.last) -- the third cell is cut but still visible
        assert.are.same({ 2, 3, 4 }, v.indices)
    end)

    it("always shows the top cell even when taller than the viewport", function()
        local v = layout.visible({ 900, 50 }, 1, 300)
        assert.are.same({ 1 }, v.indices)
    end)

    it("handles an empty notebook", function()
        assert.are.same({}, layout.visible({}, 1, 300).indices)
    end)

    it("pages down to the first cell that was not fully shown", function()
        assert.are.equal(3, layout.page_down(heights, 1, 250))
    end)

    it("always makes progress and never passes the last cell", function()
        assert.are.equal(2, layout.page_down({ 900, 50 }, 1, 300))
        assert.are.equal(5, layout.page_down(heights, 5, 250))
    end)

    it("pages up by one viewport", function()
        assert.are.equal(3, layout.page_up(heights, 5, 250))
        assert.are.equal(1, layout.page_up(heights, 2, 250))
        assert.are.equal(1, layout.page_up(heights, 1, 250))
    end)

    it("scrolls the active cell into view above the keyboard", function()
        assert.are.equal(1, layout.reveal(heights, 3, 250, 1)) -- above: top moves up
        assert.are.equal(3, layout.reveal(heights, 1, 250, 4)) -- below: smallest top that fits
        assert.are.equal(1, layout.reveal(heights, 1, 250, 2)) -- already visible
    end)

    it("reveals a cell taller than the viewport at its top edge", function()
        assert.are.equal(2, layout.reveal({ 50, 900, 50 }, 1, 300, 2))
    end)

    it("keeps the top index after a resize, clamped to the cell count", function()
        assert.are.equal(3, layout.clamp(3, 5))
        assert.are.equal(5, layout.clamp(9, 5))
        assert.are.equal(1, layout.clamp(0, 5))
        assert.are.equal(1, layout.clamp(4, 0))
    end)
end)
