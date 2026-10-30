local dirty = require("calcnb.dirty")
local notebook = require("calcnb.notebook")

describe("calcnb.dirty", function()
    local nb, d

    before_each(function()
        nb = notebook.new("T")
        d = dirty.new()
        d:watch(nb)
    end)

    it("starts clean", function()
        assert.is_false(d:is_dirty())
    end)

    it("is set by an edit that changes the text", function()
        assert(nb:set_source(nb.cells[1].id, "x"))
        assert.is_true(d:is_dirty())
    end)

    it("is not set by an edit that changes nothing", function()
        assert(nb:set_source(nb.cells[1].id, ""))
        assert.is_false(d:is_dirty())
    end)

    it("is not set by a rejected edit", function()
        assert.is_nil(nb:set_source(nb.cells[1].id, "bad\xff"))
        assert.is_false(d:is_dirty())
    end)

    it("is set by structure changes", function()
        local ops = {
            function() nb:add(2) end,
            function() nb:add_above(nb.cells[1].id) end,
            function() nb:add_below(nb.cells[1].id) end,
            function() nb:duplicate(nb.cells[1].id) end,
            function() nb:set_title("New") end,
        }
        for _, op in ipairs(ops) do
            d:saved(true)
            op()
            assert.is_true(d:is_dirty())
        end
        nb:add(1)
        d:saved(true)
        assert(nb:move(nb.cells[1].id, 1))
        assert.is_true(d:is_dirty())
        d:saved(true)
        nb:delete(nb.cells[1].id)
        assert.is_true(d:is_dirty())
    end)

    it("is not set by a move that does nothing", function()
        assert.is_false(nb:move(nb.cells[1].id, -1))
        assert.is_false(d:is_dirty())
    end)

    it("is not set by running or clearing outputs", function()
        nb:run_cell(nb.cells[1].id)
        nb:clear_all_outputs()
        assert.is_false(d:is_dirty())
    end)

    it("is set by mark", function()
        d:mark()
        assert.is_true(d:is_dirty())
    end)

    it("is cleared by a successful save", function()
        d:mark()
        d:saved(true)
        assert.is_false(d:is_dirty())
    end)

    it("is kept by a failed save", function()
        d:mark()
        d:saved(false)
        assert.is_true(d:is_dirty())
    end)

    it("save runs the writer, clears on true and keeps on false", function()
        d:mark()
        assert.is_true(d:save(function() return true end))
        assert.is_false(d:is_dirty())
        d:mark()
        assert.is_false(d:save(function() return false end))
        assert.is_true(d:is_dirty())
        assert.is_false(d:save(function() error("disk full") end))
        assert.is_true(d:is_dirty())
    end)
end)
