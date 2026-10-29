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
