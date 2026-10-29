local calccas = require("calccas")
local plot = require("calcplot")
local viewport = require("calcplot.viewport")

local W, H = 400, 400

local function plot_of(text, xmin, xmax, ymin, ymax)
    local fn = assert(calccas.compile(text, "x"))
    local vp = assert(viewport.new(xmin, xmax, ymin, ymax))
    local job = plot.new({ { id = 1, fn = fn, visible = true } }, vp, W, H)
    while not job:step(math.huge) do end
    return job:result()[1].polylines, vp
end

local function sx(vp, x)
    return (viewport.to_screen(vp, W, H, x, 0))
end

describe("reference plots", function()
    it("y = x is one 45 degree line", function()
        local lines = plot_of("x", -10, 10, -10, 10)
        assert.are.equal(1, #lines)
        for _, p in ipairs(lines[1]) do
            assert.is_true(math.abs(p[1] + p[2] - H) < 1e-6)
        end
    end)

    it("y = x^2 is one curve with its vertex at the origin", function()
        local lines, vp = plot_of("x^2", -10, 10, -10, 10)
        assert.are.equal(1, #lines)
        local lowest
        for _, p in ipairs(lines[1]) do
            if not lowest or p[2] > lowest[2] then
                lowest = p
            end
        end
        assert.is_true(math.abs(lowest[1] - sx(vp, 0)) < 2)
        assert.is_true(math.abs(lowest[2] - H / 2) < 1)
    end)

    it("y = sin(x) has amplitude 1 and period 2pi", function()
        local lines, vp = plot_of("sin(x)", -10, 10, -2, 2)
        assert.are.equal(1, #lines)
        local top, bottom = math.huge, -math.huge
        for _, p in ipairs(lines[1]) do
            top, bottom = math.min(top, p[2]), math.max(bottom, p[2])
        end
        local _, y_one = viewport.to_screen(vp, W, H, 0, 1)
        local _, y_minus = viewport.to_screen(vp, W, H, 0, -1)
        assert.is_true(math.abs(top - y_one) < 1)
        assert.is_true(math.abs(bottom - y_minus) < 1)
        local x0 = sx(vp, 0)
        local x1 = sx(vp, 2 * math.pi)
        local function py_at(px)
            local best
            for _, p in ipairs(lines[1]) do
                if not best or math.abs(p[1] - px) < math.abs(best[1] - px) then
                    best = p
                end
            end
            return best[2]
        end
        assert.is_true(math.abs(py_at(x0) - py_at(x1)) < 2)
    end)

    it("y = 1/x is split at x = 0", function()
        local lines, vp = plot_of("1/x", -10, 10, -10, 10)
        assert.are.equal(2, #lines)
        local zero = sx(vp, 0)
        for _, p in ipairs(lines[1]) do
            assert.is_true(p[1] < zero)
        end
        for _, p in ipairs(lines[2]) do
            assert.is_true(p[1] > zero)
        end
    end)

    it("y = tan(x) is split at every pole", function()
        local lines, vp = plot_of("tan(x)", -2 * math.pi, 2 * math.pi, -10, 10)
        assert.are.equal(5, #lines)
        for _, k in ipairs({ -3, -1, 1, 3 }) do
            local pole = sx(vp, k * math.pi / 2)
            for _, line in ipairs(lines) do
                local before, after = false, false
                for _, p in ipairs(line) do
                    before = before or p[1] < pole - 0.5
                    after = after or p[1] > pole + 0.5
                end
                assert.is_false(before and after, "a polyline crosses the pole at " .. k .. "pi/2")
            end
        end
    end)

    it("y = log(x) draws nothing for x <= 0", function()
        local lines, vp = plot_of("log(x)", -5, 5, -10, 10)
        assert.are.equal(1, #lines)
        local zero = sx(vp, 0)
        for _, p in ipairs(lines[1]) do
            assert.is_true(p[1] >= zero)
        end
    end)

    it("y = sqrt(x) draws nothing for x < 0", function()
        local lines, vp = plot_of("sqrt(x)", -5, 5, -10, 10)
        assert.are.equal(1, #lines)
        local zero = sx(vp, 0)
        for _, p in ipairs(lines[1]) do
            assert.is_true(p[1] >= zero - 1e-9)
        end
    end)

    it("y = 1/(x-1) is split at x = 1", function()
        local lines, vp = plot_of("1/(x-1)", -10, 10, -10, 10)
        assert.are.equal(2, #lines)
        local pole = sx(vp, 1)
        for _, p in ipairs(lines[1]) do
            assert.is_true(p[1] < pole)
        end
        for _, p in ipairs(lines[2]) do
            assert.is_true(p[1] > pole)
        end
    end)

    it("keeps every point inside the canvas", function()
        for _, text in ipairs({ "tan(x)", "1/x", "x^5", "exp(x)", "log(x)", "1/(x-1)" }) do
            for _, line in ipairs((plot_of(text, -10, 10, -10, 10))) do
                for _, p in ipairs(line) do
                    assert.is_true(p[1] >= 0 and p[1] <= W and p[2] >= 0 and p[2] <= H, text)
                end
            end
        end
    end)
end)
