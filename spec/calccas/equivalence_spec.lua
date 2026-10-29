local calccas = require("calccas")

local EXPRESSIONS = {
    "2*x+3*x", "x*1", "x+0", "x^1", "x-x", "x*x*x", "x^2+x+2*x", "(x+1)*(x-1)",
    "sin(x)+sin(x)", "1/x+1/x", "x/(x+1)+x/(x+1)", "(x+2)^3", "3*(x-2)+2*x",
    "sqrt(x^2)+x", "exp(x)*exp(x)", "(x+1)^2-(x-1)^2",
}

local SAMPLES = {}
for i = 1, 20 do
    SAMPLES[i] = -4.75 + (i - 1) * 0.5
end

local function agree(a, b, x)
    local fa, fb = calccas.compile(a, "x"), calccas.compile(b, "x")
    local va, vb = fa(x), fb(x)
    if va == nil or vb == nil then
        return true -- the transformation may only differ where one side is undefined
    end
    return math.abs(va - vb) <= 1e-9 * math.max(1, math.abs(va))
end

describe("simplify/expand equivalence and determinism", function()
    for _, text in ipairs(EXPRESSIONS) do
        it("simplify keeps " .. text .. " equivalent and stable", function()
            local once = assert(calccas.simplify(text))
            local twice = assert(calccas.simplify(once.text))
            assert.are.equal(once.text, twice.text)
            assert.are.equal(once.text, assert(calccas.simplify(text)).text)
            for _, x in ipairs(SAMPLES) do
                assert.is_true(agree(text, once.text, x), text .. " vs " .. once.text .. " at " .. x)
            end
        end)

        it("expand keeps " .. text .. " equivalent", function()
            local res = assert(calccas.expand(text))
            for _, x in ipairs(SAMPLES) do
                assert.is_true(agree(text, res.text, x), text .. " vs " .. res.text .. " at " .. x)
            end
        end)
    end

    it("accepts the simplify/expand text wrappers", function()
        assert.are.equal("x^2+2*x+1", assert(calccas.evaluate("expand((x+1)^2)")).text)
        assert.are.equal("5*x", assert(calccas.evaluate("simplify(2*x+3*x)")).text)
    end)

    it("rejects wrappers that do not span the whole input", function()
        local res, err = calccas.evaluate("expand(x)+expand(y)")
        assert.is_nil(res)
        assert.are.equal("syntax", err.kind)
    end)
end)
