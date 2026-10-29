local plot = require("calcplot")
local viewport = require("calcplot.viewport")

local W, H = 200, 100
local function vp10() return assert(viewport.new(-10, 10, -10, 10)) end

local function finish(job)
    while not job:step(math.huge) do end
    return job:result()
end

describe("calcplot.new", function()
    it("plots several functions and keeps their ids and styles", function()
        local job = plot.new({
            { id = "a", fn = function(x) return x end, visible = true, style = "solid" },
            { id = "b", fn = function(x) return -x end, visible = true, style = "dashed" },
        }, vp10(), W, H)
        local curves = finish(job)
        assert.are.equal(2, #curves)
        assert.are.equal("a", curves[1].id)
        assert.are.equal("dashed", curves[2].style)
        assert.are.equal(1, #curves[1].polylines)
    end)

    it("omits hidden functions", function()
        local job = plot.new({
            { id = 1, fn = function(x) return x end, visible = false },
            { id = 2, fn = function(x) return x end, visible = true },
        }, vp10(), W, H)
        local curves = finish(job)
        assert.are.equal(1, #curves)
        assert.are.equal(2, curves[1].id)
    end)

    it("returns an empty curve for a function with no defined points", function()
        local curves = finish(plot.new({ { id = 1, fn = function() return nil end, visible = true } }, vp10(), W, H))
        assert.are.equal(0, #curves[1].polylines)
    end)

    it("does not crash when a function raises", function()
        local curves = finish(plot.new({ { id = 1, fn = function() error("boom") end, visible = true } }, vp10(), W, H))
        assert.are.equal(0, #curves[1].polylines)
    end)

    it("gives the same result however the work is sliced", function()
        local fns = { { id = 1, fn = function(x) return math.tan(x) end, visible = true } }
        local whole = finish(plot.new(fns, vp10(), W, H))
        local job = plot.new(fns, vp10(), W, H)
        local steps = 0
        while not job:step(0) do
            steps = steps + 1
            assert.is_true(steps < 100000)
        end
        assert.is_true(steps > 1)
        assert.are.same(whole, job:result())
    end)

    it("limits evaluations per function", function()
        local calls = 0
        local fns = { { id = 1, visible = true, fn = function(x)
            calls = calls + 1
            return 1 / math.sin(x * 40)
        end } }
        finish(plot.new(fns, vp10(), 1000, 800))
        assert.is_true(calls <= 4000, calls)
    end)

    describe("auto y", function()
        it("derives the Y range from the visible curves and reports it", function()
            local vp = assert(viewport.new(-10, 10, -1, 1, true))
            local job = plot.new({ { id = 1, fn = function(x) return 50 * x end, visible = true } }, vp, W, H)
            finish(job)
            local used = job:viewport()
            assert.is_true(used.ymax > 400 and used.ymin < -400)
            assert.is_true(used.auto_y)
        end)

        it("is not applied when auto_y is off", function()
            local vp = vp10()
            local job = plot.new({ { id = 1, fn = function(x) return 50 * x end, visible = true } }, vp, W, H)
            finish(job)
            assert.are.same({ -10, 10 }, { job:viewport().ymin, job:viewport().ymax })
        end)

        it("ignores a pole when choosing the range", function()
            local vp = assert(viewport.new(-10, 10, -1, 1, true))
            local job = plot.new({ { id = 1, fn = function(x) return x ~= 0 and 1 / x or nil end, visible = true } }, vp, W, H)
            finish(job)
            assert.is_true(job:viewport().ymax < 1000)
        end)
    end)

    describe("cancel", function()
        it("finishes immediately with an empty result", function()
            local job = plot.new({ { id = 1, fn = function(x) return x end, visible = true } }, vp10(), W, H)
            job:cancel()
            assert.is_true(job:step(0))
            assert.are.same({}, job:result())
        end)

        it("can cancel part way", function()
            local job = plot.new({ { id = 1, fn = function(x) return x end, visible = true } }, vp10(), W, H)
            job:step(0)
            job:cancel()
            assert.is_true(job:step(1))
        end)
    end)

    it("rejects bad arguments", function()
        assert.has_error(function() plot.new({}, vp10(), 0, 100) end)
        assert.has_error(function() plot.new({}, nil, 100, 100) end)
    end)
end)
