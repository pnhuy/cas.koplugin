local viewport = require("calcplot.viewport")
local unpack = table.unpack or unpack -- luacheck: ignore 143

describe("calcplot.viewport", function()
    describe("new", function()
        it("accepts a valid range", function()
            local vp = assert(viewport.new(-1, 1, -2, 2))
            assert.are.same({ -1, 1, -2, 2 }, { vp.xmin, vp.xmax, vp.ymin, vp.ymax })
            assert.is_false(vp.auto_y)
        end)

        it("keeps the auto_y flag", function()
            assert.is_true(assert(viewport.new(0, 1, 0, 1, true)).auto_y)
        end)

        local bad = {
            { "reversed x", { 1, -1, 0, 1 } },
            { "equal x", { 1, 1, 0, 1 } },
            { "reversed y", { 0, 1, 1, 0 } },
            { "NaN", { 0 / 0, 1, 0, 1 } },
            { "infinite", { 0, math.huge, 0, 1 } },
            { "tiny span", { 0, 1e-12, 0, 1 } },
            { "huge value", { -2e9, 1, 0, 1 } },
            { "non-number", { "a", 1, 0, 1 } },
        }
        for _, case in ipairs(bad) do
            it("rejects " .. case[1], function()
                local vp, err = viewport.new(unpack(case[2]))
                assert.is_nil(vp)
                assert.are.equal("range", err.kind)
            end)
        end
    end)

    describe("default", function()
        it("is -10..10 with auto_y on", function()
            local vp = viewport.default()
            assert.are.same({ -10, 10, -10, 10 }, { vp.xmin, vp.xmax, vp.ymin, vp.ymax })
            assert.is_true(vp.auto_y)
        end)

        it("returns a fresh table each time", function()
            local a = viewport.default()
            a.xmin = -99
            assert.are.equal(-10, viewport.default().xmin)
        end)
    end)

    describe("transforms", function()
        local vp = assert(viewport.new(-10, 10, -5, 5))

        it("maps the corners", function()
            local px, py = viewport.to_screen(vp, 400, 200, -10, 5)
            assert.are.same({ 0, 0 }, { px, py })
            px, py = viewport.to_screen(vp, 400, 200, 10, -5)
            assert.are.same({ 400, 200 }, { px, py })
            px, py = viewport.to_screen(vp, 400, 200, 0, 0)
            assert.are.same({ 200, 100 }, { px, py })
        end)

        it("round-trips within 1e-9", function()
            for _, p in ipairs({ { 3.25, -1.5 }, { -9.99, 4.99 }, { 0, 0 }, { 7.7, 0.001 } }) do
                local px, py = viewport.to_screen(vp, 321, 123, p[1], p[2])
                local x, y = viewport.to_math(vp, 321, 123, px, py)
                assert.is_true(math.abs(x - p[1]) < 1e-9)
                assert.is_true(math.abs(y - p[2]) < 1e-9)
            end
        end)
    end)

    describe("auto_y", function()
        local vp = assert(viewport.new(-10, 10, -10, 10, true))

        it("covers the bulk of the samples with padding and ignores outliers", function()
            local samples = {}
            for i = 1, 100 do
                samples[i] = i
            end
            samples[101] = 1e9
            local out = viewport.auto_y(vp, samples)
            assert.is_true(out.ymin < 3 and out.ymax > 99)
            assert.is_true(out.ymax < 1000)
            assert.is_true(out.auto_y)
        end)

        it("skips undefined and non-finite samples", function()
            local out = viewport.auto_y(vp, { 1, false, 2, 0 / 0, math.huge, 3 })
            assert.is_true(out.ymin <= 1 and out.ymax >= 3)
        end)

        it("returns the viewport unchanged with fewer than two finite samples", function()
            assert.are.equal(vp, viewport.auto_y(vp, { 5 }))
            assert.are.equal(vp, viewport.auto_y(vp, {}))
        end)

        it("gives a flat function a visible range", function()
            local out = viewport.auto_y(vp, { 2, 2, 2, 2 })
            assert.is_true(out.ymin < 2 and out.ymax > 2)
        end)

        it("does not change x or the input table", function()
            local out = viewport.auto_y(vp, { 0, 1 })
            assert.are.same({ -10, 10 }, { out.xmin, out.xmax })
            assert.are.same({ -10, 10 }, { vp.ymin, vp.ymax })
        end)
    end)
end)

describe("calcplot.viewport navigation", function()
    local base = assert(viewport.new(-10, 10, -10, 10))

    it("zooms about the centre", function()
        local vp = assert(viewport.zoom(base, 0.5))
        assert.are.same({ -5, 5, -5, 5 }, { vp.xmin, vp.xmax, vp.ymin, vp.ymax })
        local out = assert(viewport.zoom(base, 2))
        assert.are.same({ -20, 20, -20, 20 }, { out.xmin, out.xmax, out.ymin, out.ymax })
    end)

    it("zooms about an off-centre viewport and keeps the auto_y flag", function()
        local vp = assert(viewport.new(0, 4, 10, 20, true))
        local z = assert(viewport.zoom(vp, 0.5))
        assert.are.same({ 1, 3, 12.5, 17.5 }, { z.xmin, z.xmax, z.ymin, z.ymax })
        assert.is_true(z.auto_y)
    end)

    it("refuses a zoom that leaves the valid range", function()
        local vp, err = viewport.zoom(base, 1e-12)
        assert.is_nil(vp)
        assert.are.equal("range", err.kind)
        local big, err2 = viewport.zoom(assert(viewport.new(-5e8, 5e8, -1, 1)), 10)
        assert.is_nil(big)
        assert.are.equal("range", err2.kind)
    end)

    it("pans by a fraction of the span", function()
        local vp = assert(viewport.pan(base, 0.25, 0))
        assert.are.same({ -5, 15, -10, 10 }, { vp.xmin, vp.xmax, vp.ymin, vp.ymax })
        local up = assert(viewport.pan(base, 0, 0.5))
        assert.are.same({ -10, 10, 0, 20 }, { up.xmin, up.xmax, up.ymin, up.ymax })
    end)

    it("a horizontal pan keeps auto_y, a vertical pan turns it off", function()
        local vp = assert(viewport.new(0, 1, 0, 1, true))
        assert.is_true(assert(viewport.pan(vp, 0.5, 0)).auto_y)
        assert.is_false(assert(viewport.pan(vp, 0, 0.5)).auto_y)
    end)

    it("refuses a pan beyond the limits", function()
        local vp, err = viewport.pan(assert(viewport.new(9e8, 9.5e8, 0, 1)), 10, 0)
        assert.is_nil(vp)
        assert.are.equal("range", err.kind)
    end)

    it("does not modify its input", function()
        viewport.zoom(base, 0.5)
        viewport.pan(base, 1, 1)
        assert.are.same({ -10, 10, -10, 10 }, { base.xmin, base.xmax, base.ymin, base.ymax })
    end)

    it("equal scale makes one unit the same length on both axes", function()
        local vp = assert(viewport.equal_scale(base, 400, 200))
        assert.are.same({ -10, 10, -5, 5 }, { vp.xmin, vp.xmax, vp.ymin, vp.ymax })
        assert.is_false(vp.auto_y)
        local tall = assert(viewport.equal_scale(assert(viewport.new(0, 10, 100, 110)), 100, 200))
        assert.are.same({ 0, 10, 95, 115 }, { tall.xmin, tall.xmax, tall.ymin, tall.ymax })
    end)

    it("equal scale rejects an impossible canvas", function()
        local vp, err = viewport.equal_scale(base, 0, 100)
        assert.is_nil(vp)
        assert.are.equal("range", err.kind)
    end)
end)

describe("calcplot.viewport persistence helpers", function()
    it("copy is independent and keeps extra flags", function()
        local vp = assert(viewport.new(-1, 1, -2, 2, true))
        vp.grid, vp.axes = false, true
        local c = viewport.copy(vp)
        assert.are.same(vp, c)
        c.xmin = 0
        assert.are.equal(-1, vp.xmin)
    end)

    it("from_table round-trips a saved viewport", function()
        local vp = assert(viewport.new(-3, 3, -1, 1, false))
        vp.grid, vp.axes = false, false
        assert.are.same(vp, assert(viewport.from_table(viewport.copy(vp))))
    end)

    it("from_table ignores unknown fields and non-boolean flags", function()
        local vp = assert(viewport.from_table({ xmin = 0, xmax = 1, ymin = 0, ymax = 1, auto_y = true,
            grid = "yes", evil = function() end }))
        assert.is_nil(vp.grid)
        assert.is_nil(vp.evil)
    end)

    it("from_table rejects malformed data", function()
        for _, bad in ipairs({ "x", 5, {}, { xmin = 1, xmax = 0, ymin = 0, ymax = 1 },
            { xmin = "a", xmax = 1, ymin = 0, ymax = 1 } }) do
            local vp, err = viewport.from_table(bad)
            assert.is_nil(vp)
            assert.are.equal("range", err.kind)
        end
    end)
end)
