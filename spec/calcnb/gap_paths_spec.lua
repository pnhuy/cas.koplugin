local notebook = require("calcnb.notebook")
local shortcuts = require("calcnb.shortcuts")
local statement = require("calcnb.statement")
local store = require("calcnb.store_logic")

-- Defensive branches: damaged saved data, engine names with no keyboard group,
-- and a plot with only a range.
describe("calcnb.store_logic damaged data", function()
    local function cell(extra)
        local c = { id = 1, type = "code", source = "1+1" }
        for k, v in pairs(extra or {}) do c[k] = v end
        return c
    end

    it("reports a notebook with no cells list", function()
        local nb, problems = store.sanitize({ title = "t", cells = "nope" })
        assert.is_not_nil(nb)
        assert.is_true(#problems > 0)
    end)

    it("shortens an over-long cell without splitting a UTF-8 character", function()
        local source = string.rep("é", notebook.MAX_SOURCE) -- 2 bytes each, so it must be cut mid-way
        local nb, problems = store.sanitize({ title = "t", cells = { cell({ source = source }) } })
        assert.is_true(notebook.valid_utf8(nb.cells[1].source))
        assert.is_true(#nb.cells[1].source <= notebook.MAX_SOURCE)
        assert.is_true(#problems > 0)
    end)

    it("keeps the equal-scale flag of a valid saved graph range", function()
        local vp = { xmin = -3, xmax = 3, ymin = -2, ymax = 2, auto_y = false, grid = true, axes = true, equal = true }
        local nb = store.sanitize({ title = "t", cells = { cell({ viewport = vp }) } })
        assert.is_true(nb.cells[1].viewport.equal)
    end)

    it("resets an invalid graph range and says so", function()
        local nb, problems = store.sanitize({ title = "t", cells = { cell({ viewport = { xmin = 5, xmax = 1 } }) } })
        assert.is_nil(nb.cells[1].viewport)
        assert.is_true(#problems > 0)
    end)

    it("from_file handles non-table input, a bad list and a missing notebook", function()
        local nb, _, _, state = store.from_file("junk")
        assert.is_nil(nb)
        assert.are.equal("empty", state)

        nb, _, _, state = store.from_file({ version = store.VERSION, notebooks = "x" })
        assert.is_not_nil(nb)
        assert.are.equal("repaired", state)

        nb, _, _, state = store.from_file({ version = store.VERSION + 1 })
        assert.is_nil(nb)
        assert.are.equal("newer", state)

        nb, _, _, state = store.from_file({ version = 0 })
        assert.is_not_nil(nb)
        assert.are.equal("repaired", state)

        nb, _, _, state = store.from_file({ version = store.VERSION, notebooks = {} })
        assert.is_nil(nb)
        assert.are.equal("empty", state)
    end)

    it("from_file adds file-level problems to the notebook's own", function()
        local file = { version = 0, notebooks = { [store.NAME] = { title = "t", cells = { cell() } } } }
        local nb, problems, _, state = store.from_file(file)
        assert.is_not_nil(nb)
        assert.are.equal("repaired", state)
        assert.is_true(#problems >= 1)
    end)
end)

describe("calcnb.shortcuts", function()
    it("puts engine names without a keyboard group under 'more'", function()
        local groups = shortcuts.groups({ "sin", "zzzfake", "aaafake" })
        local last = groups[#groups]
        assert.are.equal("more", last.id)
        local labels = {}
        for _, it in ipairs(last.items) do labels[#labels + 1] = it.label end
        assert.are.same({ "aaafake", "zzzfake" }, { labels[1], labels[2] })
    end)
end)

describe("calcnb.statement errors", function()
    it("rejects a plot that has only a range", function()
        local res, err = statement.parse("plot(x=-1..1)")
        assert.is_nil(res)
        assert.are.equal("syntax", err.kind)
    end)

    it("returns a program parse error, or a per-statement error record when lazy", function()
        local res, err = statement.parse("(")
        assert.is_nil(res)
        assert.are.equal("syntax", err.kind)
        local lazy = statement.parse("(", { lazy = true })
        assert.are.equal("error", lazy[1].kind)
    end)
end)
