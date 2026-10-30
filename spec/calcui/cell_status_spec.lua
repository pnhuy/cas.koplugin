local cell_status = require("calcui.cell_status")

describe("calcui.cell_status", function()
    it("gives every status a distinct symbol and a text label", function()
        local seen = {}
        for _, s in ipairs({ "idle", "running", "completed", "error", "stale" }) do
            local d = cell_status.describe(s, false)
            assert.is_string(d.symbol)
            assert.is_string(d.label)
            assert.is_nil(seen[d.symbol], s)
            seen[d.symbol] = true
        end
    end)

    it("shows Editing over any stored status without replacing it", function()
        local cell = { status = "error" }
        local d = cell_status.describe(cell.status, true)
        assert.are.equal("Editing", d.label)
        assert.are.equal("error", cell.status)
        assert.are_not.equal(cell_status.describe("error", false).symbol, d.symbol)
    end)

    it("has an ASCII fallback for every status", function()
        for _, s in ipairs({ "idle", "running", "completed", "error", "stale", "editing" }) do
            local d = cell_status.describe(s == "editing" and "idle" or s, s == "editing", true)
            assert.is_truthy(d.symbol:match("^[%w%.~%-%*!]+$"), s)
        end
    end)

    it("treats an unknown status as idle", function()
        assert.are.equal(cell_status.describe("idle", false).label, cell_status.describe("bogus", false).label)
    end)

    it("labels the input with the execution number or blank", function()
        assert.are.equal("In [3]:", cell_status.input_label({ exec_number = 3 }))
        assert.are.equal("In [ ]:", cell_status.input_label({}))
    end)

    it("marks outputs that no longer match the source", function()
        assert.is_true(cell_status.is_out_of_date({ out_of_date = true }))
        assert.is_false(cell_status.is_out_of_date({}))
    end)
end)
