local actions = require("calcnb.cell_actions")
local notebook = require("calcnb.notebook")

local function ran(source)
    local nb = notebook.new("T")
    local id = nb.cells[1].id
    assert(nb:set_source(id, source))
    nb:run_cell(id)
    return nb.cells[1]
end

describe("calcnb.cell_actions", function()
    describe("source_text", function()
        it("returns the source", function()
            assert.are.equal("1 + 1", actions.source_text({ source = "1 + 1" }))
        end)

        it("returns nil for an empty cell", function()
            assert.is_nil(actions.source_text({ source = "" }))
        end)
    end)

    describe("result_text", function()
        it("returns the plain-text value", function()
            assert.are.equal("2", actions.result_text(ran("1 + 1")))
        end)

        it("returns the full text of a truncated value", function()
            local cell = { output = { kind = "value", canonical = "short", full = "the long text", truncated = true } }
            assert.are.equal("the long text", actions.result_text(cell))
        end)

        it("returns the message of an error", function()
            local cell = ran("sin(")
            assert.are.equal(cell.output.canonical, actions.result_text(cell))
        end)

        it("returns nil without output or for an empty output", function()
            assert.is_nil(actions.result_text({}))
            assert.is_nil(actions.result_text({ output = { empty = true } }))
        end)
    end)

    describe("insert_text", function()
        it("offers values but not errors or graphs", function()
            assert.are.equal("2", actions.insert_text(ran("1 + 1")))
            assert.is_nil(actions.insert_text(ran("sin(")))
            assert.is_nil(actions.insert_text({ output = { kind = "graph", canonical = "sin(x)" } }))
            assert.is_nil(actions.insert_text({}))
        end)
    end)

    describe("needs_delete_confirmation", function()
        it("is false for an empty cell without output", function()
            assert.is_false(actions.needs_delete_confirmation({ source = "" }))
        end)

        it("is true when the cell has text", function()
            assert.is_true(actions.needs_delete_confirmation({ source = "x" }))
        end)

        it("is true when the cell only has an output", function()
            assert.is_true(actions.needs_delete_confirmation({ source = "", output = { kind = "value" } }))
        end)
    end)

    describe("has_outputs", function()
        it("tells whether clearing would remove anything", function()
            local nb = notebook.new("T")
            assert.is_false(actions.has_outputs(nb))
            nb:run_cell(nb.cells[1].id)
            assert.is_true(actions.has_outputs(nb))
        end)
    end)
end)
