local notebook = require("calcnb.notebook")
local store = require("calcnb.store_logic")

local function sample()
    local nb = notebook.new("Physics")
    local c1 = nb.cells[1]
    assert(nb:set_source(c1.id, "a = 2\nf(x) = x^2"))
    local c2 = assert(nb:add(2))
    assert(nb:set_source(c2.id, "plot(sin(x))"))
    c2.viewport = { xmin = -3, xmax = 3, ymin = -2, ymax = 2, auto_y = false, grid = false, axes = true }
    local c3 = assert(nb:add(3, "text"))
    assert(nb:set_source(c3.id, "notes"))
    return nb
end

local function plain(v, seen)
    seen = seen or {}
    local t = type(v)
    if t == "function" or t == "userdata" or t == "thread" then
        return false
    end
    if t == "table" then
        if seen[v] then
            return false
        end
        seen[v] = true
        for k, x in pairs(v) do
            if not plain(k, seen) or not plain(x, seen) then
                return false
            end
        end
        seen[v] = nil
    end
    return true
end

describe("calcnb.store_logic round trip", function()
    it("keeps title, order, ids, types, sources, viewports and scroll", function()
        local nb = sample()
        local data = store.to_data(nb, { top_id = nb.cells[2].id, offset = 12 })
        local back, problems, scroll = store.sanitize(data)
        assert.are.same({}, problems)
        assert.are.equal("Physics", back.title)
        assert.are.equal(3, #back.cells)
        for i, c in ipairs(nb.cells) do
            assert.are.equal(c.id, back.cells[i].id)
            assert.are.equal(c.type, back.cells[i].type)
            assert.are.equal(c.source, back.cells[i].source)
        end
        assert.are.same(nb.cells[2].viewport, back.cells[2].viewport)
        assert.are.equal(nb.next_id, back.next_id)
        assert.are.same({ top_id = nb.cells[2].id, offset = 12 }, scroll)
    end)

    it("loads cells idle without output", function()
        local nb = sample()
        nb:run_cell(nb.cells[1].id)
        local back = store.sanitize(store.to_data(nb))
        for _, c in ipairs(back.cells) do
            assert.are.equal("idle", c.status)
            assert.is_nil(c.output)
        end
    end)

    it("produces plain tables only", function()
        local nb = sample()
        nb:run_cell(nb.cells[1].id)
        assert.is_true(plain(store.to_data(nb, { top_id = 1, offset = 0 })))
    end)

    it("restored notebook keeps working", function()
        local back = store.sanitize(store.to_data(sample()))
        local c = assert(back:add(#back.cells + 1))
        assert.is_true(c.id >= back.next_id - 1)
        assert.is_not_nil(back:run_cell(back.cells[1].id))
    end)
end)

describe("calcnb.store_logic sanitize", function()
    local function data(cells)
        return { title = "T", next_id = 10, cells = cells }
    end

    it("accepts a non-table as an empty usable notebook", function()
        for _, bad in ipairs({ 5, "x", false }) do
            local nb, problems = store.sanitize(bad)
            assert.are.equal(1, #nb.cells)
            assert.is_true(#problems > 0)
        end
    end)

    it("repairs a wrong title and a missing next_id", function()
        local nb, problems = store.sanitize({ title = 7, cells = { { id = 4, type = "code", source = "1" } } })
        assert.are.equal("Notebook", nb.title)
        assert.is_true(nb.next_id > 4)
        assert.is_true(#problems > 0)
    end)

    it("drops a non-table cell entry", function()
        local nb, problems = store.sanitize(data({ 5, { id = 1, type = "code", source = "a" } }))
        assert.are.equal(1, #nb.cells)
        assert.are.equal("a", nb.cells[1].source)
        assert.is_true(#problems > 0)
    end)

    it("treats an unknown type as code", function()
        local nb, problems = store.sanitize(data({ { id = 1, type = "chart", source = "a" } }))
        assert.are.equal("code", nb.cells[1].type)
        assert.is_true(#problems > 0)
    end)

    it("replaces a non-string source with empty text", function()
        local nb, problems = store.sanitize(data({ { id = 1, type = "code", source = 12 } }))
        assert.are.equal("", nb.cells[1].source)
        assert.is_true(#problems > 0)
    end)

    it("replaces a missing source silently-empty but reports it", function()
        local nb, problems = store.sanitize(data({ { id = 1, type = "code" } }))
        assert.are.equal("", nb.cells[1].source)
        assert.is_true(#problems > 0)
    end)

    it("drops a cell with invalid UTF-8", function()
        local nb, problems = store.sanitize(data({
            { id = 1, type = "code", source = "ok" },
            { id = 2, type = "code", source = "bad\xff" },
        }))
        assert.are.equal(1, #nb.cells)
        assert.are.equal("ok", nb.cells[1].source)
        assert.is_true(#problems > 0)
    end)

    it("renumbers duplicate and missing ids", function()
        local nb, problems = store.sanitize(data({
            { id = 1, type = "code", source = "a" },
            { id = 1, type = "code", source = "b" },
            { type = "code", source = "c" },
        }))
        local seen = {}
        for _, c in ipairs(nb.cells) do
            assert.is_number(c.id)
            assert.is_nil(seen[c.id])
            seen[c.id] = true
            assert.is_true(c.id < nb.next_id)
        end
        assert.are.equal(3, #nb.cells)
        assert.are.equal("b", nb.cells[2].source)
        assert.is_true(#problems > 0)
    end)

    it("truncates over-long text and reports it", function()
        local long = string.rep("a", notebook.MAX_SOURCE + 50)
        local nb, problems = store.sanitize(data({ { id = 1, type = "code", source = long } }))
        assert.are.equal(notebook.MAX_SOURCE, #nb.cells[1].source)
        assert.is_true(#problems > 0)
    end)

    it("does not cut a UTF-8 character when truncating", function()
        local long = string.rep("é", notebook.MAX_SOURCE)
        local nb = store.sanitize(data({ { id = 1, type = "code", source = long } }))
        assert.is_true(notebook.valid_utf8(nb.cells[1].source))
        assert.is_true(#nb.cells[1].source <= notebook.MAX_SOURCE)
    end)

    it("keeps at most the cell limit", function()
        local cells = {}
        for i = 1, notebook.MAX_CELLS + 5 do
            cells[i] = { id = i, type = "code", source = "" }
        end
        local nb, problems = store.sanitize(data(cells))
        assert.are.equal(notebook.MAX_CELLS, #nb.cells)
        assert.is_true(#problems > 0)
    end)

    it("yields one empty cell when everything is dropped", function()
        local nb = store.sanitize(data({ 1, 2, "x" }))
        assert.are.equal(1, #nb.cells)
        assert.are.equal("", nb.cells[1].source)
    end)

    it("drops an invalid viewport but keeps the cell", function()
        local nb, problems = store.sanitize(data({
            { id = 1, type = "code", source = "a", viewport = { xmin = 5, xmax = 1, ymin = 0, ymax = 1 } },
        }))
        assert.is_nil(nb.cells[1].viewport)
        assert.are.equal("a", nb.cells[1].source)
        assert.is_true(#problems > 0)
    end)

    it("ignores a scroll that names no cell", function()
        local d = data({ { id = 1, type = "code", source = "" } })
        d.scroll = { top_id = 99, offset = 3 }
        local _, _, scroll = store.sanitize(d)
        assert.is_nil(scroll)
    end)

    it("ignores a malformed scroll", function()
        local d = data({ { id = 1, type = "code", source = "" } })
        d.scroll = { top_id = "x", offset = {} }
        local _, _, scroll = store.sanitize(d)
        assert.is_nil(scroll)
    end)
end)

describe("calcnb.store_logic file level", function()
    it("round trips through to_file and from_file", function()
        local nb = sample()
        local file = store.to_file(nb, { top_id = nb.cells[1].id, offset = 0 })
        assert.are.equal(1, file.version)
        assert.are.equal("default", file.last_notebook)
        assert.is_true(plain(file))
        local back, problems = store.from_file(file)
        assert.are.same({}, problems)
        assert.are.equal("Physics", back.title)
    end)

    it("reports an empty file as no notebook", function()
        local nb, problems, _, state = store.from_file({})
        assert.is_nil(nb)
        assert.are.same({}, problems)
        assert.are.equal("empty", state)
    end)

    it("refuses an unknown newer version without a notebook", function()
        local nb, problems, _, state = store.from_file({ version = 2, notebooks = {} })
        assert.is_nil(nb)
        assert.are.equal("newer", state)
        assert.is_true(#problems > 0)
    end)

    it("reports a malformed version or notebooks table", function()
        local nb, problems, _, state = store.from_file({ version = "1", notebooks = 3 })
        assert.is_not_nil(nb)
        assert.are.equal("repaired", state)
        assert.is_true(#problems > 0)
    end)

    it("reads the default notebook and ignores others", function()
        local file = { version = 1, notebooks = {
            default = { title = "D", next_id = 2, cells = { { id = 1, type = "code", source = "x" } } },
            other = { title = "O" },
        } }
        local nb, problems, _, state = store.from_file(file)
        assert.are.equal("ok", state)
        assert.are.same({}, problems)
        assert.are.equal("D", nb.title)
    end)
end)
