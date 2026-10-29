local sampler = require("calcplot.sampler")

local function run(fn, xmin, xmax, opts)
    opts = opts or {}
    opts.ymin = opts.ymin or -10
    opts.ymax = opts.ymax or 10
    return sampler.sample(fn, xmin, xmax, opts)
end

describe("calcplot.sampler", function()
    describe("values", function()
        it("samples n+1 evenly spaced points, false where undefined", function()
            local ys = sampler.values(function(x) return x >= 0 and x or nil end, -1, 1, 4)
            assert.are.same({ false, false, 0, 0.5, 1 }, ys)
        end)

        it("treats NaN and infinity as undefined", function()
            local ys = sampler.values(function(x) return x == 0 and 0 / 0 or math.huge end, -1, 1, 2)
            assert.are.same({ false, false, false }, ys)
        end)

        it("survives a function that raises", function()
            local ys = sampler.values(function() error("boom") end, 0, 1, 2)
            assert.are.same({ false, false, false }, ys)
        end)
    end)

    describe("sample", function()
        it("returns one polyline for a continuous function", function()
            local r = run(function(x) return x end, -5, 5, { samples = 50 })
            assert.are.equal(1, #r.polylines)
            local line = r.polylines[1]
            assert.are.same({ -5, -5 }, line[1])
            assert.are.same({ 5, 5 }, line[#line])
        end)

        it("orders points left to right", function()
            local r = run(math.sin, -5, 5, { samples = 100 })
            local line = r.polylines[1]
            for i = 2, #line do
                assert.is_true(line[i][1] > line[i - 1][1])
            end
        end)

        it("splits at a hole and stops at the domain edge", function()
            local r = run(function(x) return x ~= 0 and 1 / x or nil end, -5, 5, { samples = 200 })
            assert.are.equal(2, #r.polylines)
            local left, right = r.polylines[1], r.polylines[2]
            assert.is_true(left[#left][1] < 0 and right[1][1] > 0)
        end)

        it("refines toward the edge of a domain", function()
            local r = run(function(x) return x > 0.001 and math.log(x) or nil end, -1, 1, { samples = 20 })
            assert.are.equal(1, #r.polylines)
            assert.is_true(r.polylines[1][1][1] < 0.01)
        end)

        it("splits at a pole even when no sample lands on it", function()
            local r = run(function(x) return 1 / (x - 0.1234567) end, -5, 5, { samples = 100 })
            assert.are.equal(2, #r.polylines)
        end)

        it("does not split a steep but continuous function", function()
            local r = run(function(x) return 200 * x end, -5, 5, { samples = 20, ymin = -10, ymax = 10 })
            assert.are.equal(1, #r.polylines)
        end)

        it("returns nothing when every sample is undefined", function()
            local r = run(function() return nil end, -5, 5, { samples = 50 })
            assert.are.equal(0, #r.polylines)
        end)

        it("never exceeds the evaluation limit", function()
            local calls = 0
            local r = run(function(x)
                calls = calls + 1
                return 1 / math.sin(x * 37)
            end, -50, 50, { samples = 1000, max_evals = 4000 })
            assert.is_true(calls <= 4000, calls)
            assert.are.equal(calls, r.evals)
        end)

        it("is deterministic", function()
            local f = function(x) return math.tan(x) end
            assert.are.same(run(f, -6, 6, { samples = 300 }), run(f, -6, 6, { samples = 300 }))
        end)

        it("calls on_eval so a caller can yield", function()
            local n = 0
            run(function(x) return x end, 0, 1, { samples = 10, on_eval = function() n = n + 1 end })
            assert.is_true(n >= 11)
        end)

        it("survives a function that raises", function()
            local r = run(function() error("boom") end, 0, 1, { samples = 10 })
            assert.are.equal(0, #r.polylines)
        end)
    end)
end)
