local ticks = require("calcplot.ticks")
local unpack = table.unpack or unpack -- luacheck: ignore 143

local function mantissa(step)
    local m = step / 10 ^ math.floor(math.log10(step) + 1e-9)
    return math.floor(m + 0.5)
end

describe("calcplot.ticks", function()
    it("chooses a step of 1, 2 or 5 times a power of ten", function()
        for _, r in ipairs({ { 0, 10 }, { -1, 1 }, { 0, 0.5 }, { 3, 97 }, { 0, 1e9 }, { 0, 1e-6 }, { -123, 456 } }) do
            local t = ticks.nice(r[1], r[2], 5)
            assert.is_truthy(({ [1] = true, [2] = true, [5] = true })[mantissa(t.step)], tostring(t.step))
        end
    end)

    it("spans 0..10 in steps of 2", function()
        local t = ticks.nice(0, 10, 5)
        assert.are.equal(2, t.step)
        assert.are.same({ 0, 2, 4, 6, 8, 10 }, { unpack(t) })
    end)

    it("keeps every value inside the range", function()
        local t = ticks.nice(-3.3, 7.1, 6)
        for _, v in ipairs(t) do
            assert.is_true(v >= -3.3 and v <= 7.1)
        end
    end)

    it("avoids floating point noise", function()
        local t = ticks.nice(0, 0.5, 5)
        assert.are.equal(0.1, t.step)
        assert.are.equal(0.3, t[4])
    end)

    it("keeps the tick count near the target", function()
        for _, target in ipairs({ 3, 5, 8, 12 }) do
            local t = ticks.nice(-17.3, 91.2, target)
            assert.is_true(#t >= 2 and #t <= 2 * target + 2, #t)
        end
    end)

    it("handles tiny and huge ranges", function()
        local tiny = ticks.nice(0, 1e-6, 5)
        assert.is_true(#tiny >= 3)
        local huge = ticks.nice(0, 1e9, 5)
        assert.are.equal(2e8, huge.step)
    end)

    it("returns no ticks for an invalid range", function()
        assert.are.equal(0, #ticks.nice(1, 1, 5))
        assert.are.equal(0, #ticks.nice(2, 1, 5))
        assert.are.equal(0, #ticks.nice(0 / 0, 1, 5))
    end)

    describe("label", function()
        it("prints integers without decimals", function()
            assert.are.equal("2", ticks.label(2, 1))
            assert.are.equal("-40", ticks.label(-40, 20))
        end)

        it("prints the decimals the step needs", function()
            assert.are.equal("0.3", ticks.label(0.3, 0.1))
            assert.are.equal("1.5", ticks.label(1.5, 0.5))
            assert.are.equal("0.25", ticks.label(0.25, 0.05))
        end)

        it("never prints negative zero", function()
            assert.are.equal("0", ticks.label(-0.0, 1))
            assert.are.equal("0", ticks.label(0, 0.1))
        end)

        it("uses exponent form for very large and very small values", function()
            assert.are.equal("2e+08", ticks.label(2e8, 2e8))
            assert.are.equal("5e-07", ticks.label(5e-7, 1e-7))
        end)
    end)
end)
