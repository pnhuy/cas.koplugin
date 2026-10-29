local raster = require("calcplot.raster")

local function paint_set(points, style)
    local seen, count = {}, 0
    raster.polyline(points, style, function(x, y, s)
        for dy = 0, s - 1 do
            for dx = 0, s - 1 do
                local key = (x + dx) .. "," .. (y + dy)
                if not seen[key] then
                    seen[key] = true
                    count = count + 1
                end
            end
        end
    end)
    return seen, count
end

describe("calcplot.raster", function()
    it("has six styles with different looks", function()
        assert.are.equal(6, #raster.STYLES)
        local looks = {}
        for _, s in ipairs(raster.STYLES) do
            local key = table.concat({ s.thick, table.concat(s.pattern or {}, ","), tostring(s.markers), tostring(s.double) }, "/")
            assert.is_nil(looks[key])
            looks[key] = true
        end
    end)

    it("draws every pixel of a thin horizontal line", function()
        local seen, count = paint_set({ { 0, 5 }, { 9, 5 } }, { thick = 1 })
        assert.are.equal(10, count)
        for x = 0, 9 do
            assert.is_true(seen[x .. ",5"])
        end
    end)

    it("steps diagonally without gaps", function()
        local _, count = paint_set({ { 0, 0 }, { 5, 5 } }, { thick = 1 })
        assert.are.equal(6, count)
    end)

    it("draws the same number of pixels in either direction", function()
        assert.are.equal(9, select(2, paint_set({ { 0, 0 }, { 8, 3 } }, { thick = 1 })))
        assert.are.equal(9, select(2, paint_set({ { 8, 3 }, { 0, 0 } }, { thick = 1 })))
    end)

    it("leaves gaps in a dashed line", function()
        local seen, count = paint_set({ { 0, 0 }, { 11, 0 } }, { thick = 1, pattern = { 4, 2 } })
        assert.are.equal(8, count)
        assert.is_true(seen["3,0"] and seen["6,0"])
        assert.is_nil(seen["4,0"] or seen["5,0"] or seen["10,0"])
    end)

    it("continues the dash phase across segments", function()
        local _, one = paint_set({ { 0, 0 }, { 11, 0 } }, { thick = 1, pattern = { 4, 2 } })
        local _, two = paint_set({ { 0, 0 }, { 5, 0 }, { 11, 0 } }, { thick = 1, pattern = { 4, 2 } })
        assert.are.equal(one, two)
    end)

    it("centres a thick line on the path", function()
        local seen = paint_set({ { 0, 5 }, { 9, 5 } }, { thick = 3 })
        assert.is_true(seen["4,4"] and seen["4,5"] and seen["4,6"])
        assert.is_nil(seen["4,3"] or seen["4,7"])
    end)

    it("adds markers", function()
        local _, plain = paint_set({ { 0, 5 }, { 40, 5 } }, { thick = 1 })
        local _, marked = paint_set({ { 0, 5 }, { 40, 5 } }, { thick = 1, markers = 10 })
        assert.is_true(marked > plain)
    end)

    it("draws a double line as two parallel lines", function()
        local seen = paint_set({ { 0, 10 }, { 9, 10 } }, { thick = 1, double = 3 })
        assert.is_true(seen["4,7"] and seen["4,13"])
        assert.is_nil(seen["4,10"])
    end)

    it("handles a single point and an empty list", function()
        assert.are.equal(1, select(2, paint_set({ { 3, 3 } }, { thick = 1 })))
        assert.are.equal(0, select(2, paint_set({}, { thick = 1 })))
    end)
end)
