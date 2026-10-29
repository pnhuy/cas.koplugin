local calccas = require("calccas")
local cases = require("spec.calccas.reference_cases")

local function expanded(text)
    local res, err = calccas.expand(text)
    assert.is_nil(err, err and tostring(err))
    return res.text
end

describe("calccas.expand", function()
    for _, case in ipairs(cases.expand) do
        it("expands " .. case[1] .. " -> " .. case[2], function()
            assert.are.equal(case[2], expanded(case[1]))
        end)
    end

    it("expands cubes", function()
        assert.are.equal("a^3+3*a^2*b+3*a*b^2+b^3", expanded("(a+b)^3"))
    end)

    it("distributes numbers and variables over sums", function()
        assert.are.equal("2*x+2*y", expanded("2*(x+y)"))
        assert.are.equal("x^2+x*y", expanded("x*(x+y)"))
    end)

    it("expands inside function arguments", function()
        assert.are.equal("sin(x^2+2*x+1)", expanded("sin((x+1)^2)"))
    end)

    it("leaves negative powers of sums alone", function()
        assert.are.equal("1/(x+1)", expanded("1/(x+1)"))
    end)

    it("returns too_complex when the result has too many terms", function()
        local res, err = calccas.expand("(a+b+c+d+e)^12")
        assert.is_nil(res)
        assert.are.equal("too_complex", err.kind)
    end)

    it("returns too_complex for an absurd exponent without hanging", function()
        local res, err = calccas.expand("(x+1)^100000")
        assert.is_nil(res)
        assert.are.equal("too_complex", err.kind)
    end)
end)
