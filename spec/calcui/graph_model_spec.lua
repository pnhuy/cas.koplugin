local model = require("calcui.graph_model")

describe("calcui.graph_model", function()
    local state
    before_each(function()
        state = model.new_state()
    end)

    describe("functions", function()
        it("adds a valid function visible, with the first free style", function()
            local a = assert(model.add(state, "  sin(x) "))
            local b = assert(model.add(state, "x^2"))
            assert.are.equal("sin(x)", a.text)
            assert.is_true(a.visible)
            assert.are.same({ 1, 2 }, { a.style, b.style })
            assert.are_not.equal(a.id, b.id)
        end)

        it("rejects blank and invalid text without changing the list", function()
            for _, text in ipairs({ "", "   ", "2 +* 3", "x + y", "os.execute(\"x\")" }) do
                local entry, err = model.add(state, text)
                assert.is_nil(entry, text)
                assert.is_table(err)
            end
            assert.are.equal(0, #state.functions)
        end)

        it("limits the number of functions", function()
            for i = 1, model.MAX_FUNCTIONS do
                assert(model.add(state, "x+" .. i))
            end
            local entry, err = model.add(state, "x")
            assert.is_nil(entry)
            assert.are.equal("limit", err.kind)
        end)

        it("reuses the style of a removed function", function()
            local a = assert(model.add(state, "x"))
            assert(model.add(state, "2*x"))
            assert.is_true(model.remove(state, a.id))
            assert.are.equal(1, assert(model.add(state, "3*x")).style)
            assert.is_false(model.remove(state, 999))
        end)

        it("edits in place and keeps the old text on error", function()
            local a = assert(model.add(state, "x"))
            assert(model.edit(state, a.id, "x^3"))
            assert.are.equal("x^3", a.text)
            assert.is_nil(model.edit(state, a.id, "x^^"))
            assert.are.equal("x^3", a.text)
        end)

        it("toggles visibility", function()
            local a = assert(model.add(state, "x"))
            assert.is_false(model.toggle(state, a.id))
            assert.is_true(model.toggle(state, a.id))
        end)
    end)

    describe("plot_functions", function()
        it("returns compiled visible functions only", function()
            local a = assert(model.add(state, "x"))
            assert(model.add(state, "x^2"))
            model.toggle(state, a.id)
            local list, failed = model.plot_functions(state)
            assert.are.equal(1, #list)
            assert.are.equal(4, list[1].fn(2))
            assert.are.equal(0, failed)
        end)

        it("counts functions that cannot be plotted", function()
            state.functions[1] = { id = 1, text = "x + y", visible = true, style = 1 }
            local list, failed = model.plot_functions(state)
            assert.are.equal(0, #list)
            assert.are.equal(1, failed)
            assert.are.equal("unbound_variable", state.functions[1].error.kind)
        end)
    end)

    describe("cache_key", function()
        it("is stable and changes with anything that changes the picture", function()
            local a = assert(model.add(state, "x"))
            local base = model.cache_key(state, 100, 80)
            assert.are.equal(base, model.cache_key(state, 100, 80))
            assert.are_not.equal(base, model.cache_key(state, 101, 80))
            state.grid = false
            assert.are_not.equal(base, model.cache_key(state, 100, 80))
            state.grid = true
            state.viewport = assert(require("calcplot.viewport").new(-5, 5, -5, 5))
            assert.are_not.equal(base, model.cache_key(state, 100, 80))
            state.viewport = require("calcplot.viewport").default()
            assert.are.equal(base, model.cache_key(state, 100, 80))
            assert(model.edit(state, a.id, "x+1"))
            assert.are_not.equal(base, model.cache_key(state, 100, 80))
        end)

        it("ignores hidden functions", function()
            local a = assert(model.add(state, "x"))
            model.toggle(state, a.id)
            local hidden = model.cache_key(state, 100, 80)
            state.functions = {}
            assert.are.equal(hidden, model.cache_key(state, 100, 80))
        end)
    end)

    describe("parse_range", function()
        it("accepts numbers and constant expressions", function()
            local vp = assert(model.parse_range({ "-2*pi", "2*pi", "-2", "1/2" }, false))
            assert.is_true(math.abs(vp.xmin + 2 * math.pi) < 1e-12)
            assert.are.same({ -2, 0.5 }, { vp.ymin, vp.ymax })
            assert.is_false(vp.auto_y)
        end)

        it("ignores blank Y fields with auto Y", function()
            local vp = assert(model.parse_range({ "-5", "5", "", "" }, true))
            assert.is_true(vp.auto_y)
            assert.are.same({ -5, 5 }, { vp.xmin, vp.xmax })
        end)

        it("rejects text, reversed and huge ranges", function()
            for _, texts in ipairs({
                { "a", "5", "0", "1" },
                { "5", "-5", "0", "1" },
                { "0", "1", "", "" },
                { "0", "1e12", "0", "1" },
                { "x", "1", "0", "1" },
            }) do
                local vp, err = model.parse_range(texts, false)
                assert.is_nil(vp, table.concat(texts, ","))
                assert.are.equal("range", err.kind)
            end
        end)
    end)
end)
