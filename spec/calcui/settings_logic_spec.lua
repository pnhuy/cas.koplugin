local logic = require("calcui.settings_logic")
local viewport = require("calcplot.viewport")

describe("calcui.settings_logic", function()
    local function is_default(s)
        local d = viewport.default()
        return s.viewport.xmin == d.xmin and s.viewport.xmax == d.xmax and s.viewport.ymin == d.ymin
            and s.viewport.ymax == d.ymax and s.viewport.auto_y == d.auto_y and s.grid == true
    end

    it("falls back to defaults for missing or non-table data", function()
        for _, raw in ipairs({ {}, "x", 42, true }) do
            assert.is_true(is_default(logic.sanitize(raw)))
        end
        assert.is_true(is_default(logic.sanitize(nil)))
    end)

    it("round-trips a valid viewport and grid flag", function()
        local vp = assert(viewport.new(-5, 5, -2, 2, false))
        local s = logic.sanitize(logic.to_data(vp, false))
        assert.are.same({ -5, 5, -2, 2, false }, { s.viewport.xmin, s.viewport.xmax, s.viewport.ymin, s.viewport.ymax, s.viewport.auto_y })
        assert.is_false(s.grid)
    end)

    it("rejects an invalid viewport but keeps a valid grid flag", function()
        local s = logic.sanitize({ viewport = { xmin = 5, xmax = 5, ymin = 0, ymax = 1 }, grid = false })
        assert.is_true(s.viewport.xmin == -10 and s.viewport.xmax == 10)
        assert.is_false(s.grid)
    end)

    it("rejects wrong types, NaN and infinity", function()
        local bad = {
            { xmin = "a", xmax = 1, ymin = 0, ymax = 1 },
            { xmin = 0 / 0, xmax = 1, ymin = 0, ymax = 1 },
            { xmin = -math.huge, xmax = 1, ymin = 0, ymax = 1 },
            { xmin = 0, xmax = 1e12, ymin = 0, ymax = 1 },
        }
        for _, v in ipairs(bad) do
            assert.is_true(is_default(logic.sanitize({ viewport = v, grid = "yes" })))
        end
    end)

    it("stores only plain data", function()
        local d = logic.to_data(viewport.default(), true)
        for _, v in pairs(d.viewport) do
            assert.is_not.equal("table", type(v))
        end
        assert.is_nil(getmetatable(d))
    end)
end)
