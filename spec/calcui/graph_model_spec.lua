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

describe("calcui.graph_model notebook graphs", function()
    local calccas = require("calccas")
    local function graph(x_range)
        return {
            functions = {
                { label = "sin(x)", ast = assert(calccas.parse("sin(x)")) },
                { label = "cos(x)", ast = assert(calccas.parse("cos(x)")) },
            },
            x_range = x_range,
        }
    end

    it("builds a state from a plot output", function()
        local state = model.from_graph(graph({ lo = -3, hi = 3 }))
        assert.are.equal(2, #state.functions)
        assert.are.same({ 1, 2 }, { state.functions[1].style, state.functions[2].style })
        assert.are.equal("sin(x)", state.functions[1].label)
        assert.are.equal(calccas.tostring(assert(calccas.parse("sin(x)"))), state.functions[1].text)
        assert.is_true(state.functions[1].visible)
        assert.are.same({ -3, 3, true }, { state.viewport.xmin, state.viewport.xmax, state.viewport.auto_y })
        assert.is_true(state.grid)
        assert.is_true(state.axes)
        assert.are.same(state.viewport, state.home)
    end)

    it("uses the default x range when the plot gives none", function()
        local state = model.from_graph(graph(nil))
        assert.are.same({ -10, 10 }, { state.viewport.xmin, state.viewport.xmax })
    end)

    it("the compiled functions can be plotted", function()
        local fns, failed = model.plot_functions(model.from_graph(graph(nil)))
        assert.are.equal(2, #fns)
        assert.are.equal(0, failed)
        assert.is_true(math.abs(fns[1].fn(0)) < 1e-12)
    end)

    it("restores a saved viewport with grid and axes flags", function()
        local saved = { xmin = -1, xmax = 1, ymin = -2, ymax = 2, auto_y = false, grid = false, axes = false }
        local state = model.from_graph(graph({ lo = -3, hi = 3 }), saved)
        assert.are.same({ -1, 1, -2, 2 }, { state.viewport.xmin, state.viewport.xmax, state.viewport.ymin, state.viewport.ymax })
        assert.is_false(state.grid)
        assert.is_false(state.axes)
        assert.are.equal(-3, state.home.xmin)
    end)

    it("falls back to the plot range when the saved viewport is invalid", function()
        local state = model.from_graph(graph({ lo = -3, hi = 3 }), { xmin = 5, xmax = 1, ymin = 0, ymax = 1 })
        assert.are.equal(-3, state.viewport.xmin)
    end)

    it("to_viewport returns what the cell should store", function()
        local state = model.from_graph(graph(nil))
        state.grid, state.axes = false, true
        state.viewport = assert(require("calcplot.viewport").new(-2, 2, -1, 1))
        local vp = model.to_viewport(state)
        assert.are.same({ -2, 2, -1, 1, false, true }, { vp.xmin, vp.xmax, vp.ymin, vp.ymax, vp.grid, vp.axes })
        local again = model.from_graph(graph(nil), vp)
        assert.are.same(state.viewport, again.viewport)
        assert.is_false(again.grid)
    end)

    it("the cache key changes with the axes option and the plotted expression", function()
        local state = model.from_graph(graph(nil))
        local k1 = model.cache_key(state, 300, 200)
        state.axes = false
        assert.are_not.equal(k1, model.cache_key(state, 300, 200))
        local other = model.from_graph({ functions = { { label = "f", ast = assert(calccas.parse("2*x")) } } })
        local other2 = model.from_graph({ functions = { { label = "f", ast = assert(calccas.parse("3*x")) } } })
        assert.are_not.equal(model.cache_key(other, 300, 200), model.cache_key(other2, 300, 200))
    end)

    it("describes each curve for the legend with its line style", function()
        local legend = model.legend(model.from_graph(graph(nil)))
        assert.are.same({ { label = "sin(x)", style = "solid" }, { label = "cos(x)", style = "dashed" } }, legend)
    end)
end)

describe("calcui.graph_model inspection", function()
    local calccas = require("calccas")
    local function state_of(...)
        local fns = {}
        for i, text in ipairs({ ... }) do
            fns[i] = { label = text, ast = assert(calccas.parse(text)) }
        end
        return model.from_graph({ functions = fns })
    end

    it("gives x, y and the function for a value", function()
        local rows = assert(model.inspect(state_of("x^2"), "2"))
        assert.are.equal(1, #rows)
        assert.are.equal("x^2", rows[1].label)
        assert.are.equal(2, rows[1].x)
        assert.are.equal(4, rows[1].y)
        assert.are.equal("4", rows[1].text)
    end)

    it("accepts a constant expression for x", function()
        local rows = assert(model.inspect(state_of("x"), "2*pi"))
        assert.is_true(math.abs(rows[1].y - 2 * math.pi) < 1e-9)
    end)

    it("reports undefined where the function has no value", function()
        local rows = assert(model.inspect(state_of("1/x", "sqrt(x)"), "0"))
        assert.are.equal("undefined", rows[1].text)
        assert.is_nil(rows[1].y)
        local neg = assert(model.inspect(state_of("sqrt(x)"), "-1"))
        assert.are.equal("undefined", neg[1].text)
    end)

    it("covers every visible function and skips hidden ones", function()
        local state = state_of("x", "2*x")
        model.toggle(state, state.functions[1].id)
        local rows = assert(model.inspect(state, "3"))
        assert.are.equal(1, #rows)
        assert.are.equal(6, rows[1].y)
    end)

    it("rejects an x that is not a number", function()
        local rows, err = model.inspect(state_of("x"), "abc")
        assert.is_nil(rows)
        assert.are.equal("range", err.kind)
        assert.is_nil(model.inspect(state_of("x"), ""))
    end)

    it("returns no rows when nothing is plotted", function()
        local rows = assert(model.inspect(model.new_state(), "1"))
        assert.are.same({}, rows)
    end)
end)
