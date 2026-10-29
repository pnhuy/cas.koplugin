local calccas = require("calccas")
local cases = require("spec.calccas.reference_cases")

local function simplified(text)
    local res, err = calccas.simplify(text)
    assert.is_nil(err, err and tostring(err))
    return res
end

describe("calccas.simplify", function()
    for _, case in ipairs(cases.simplify) do
        it("simplifies " .. case[1] .. " -> " .. case[2], function()
            assert.are.equal(case[2], simplified(case[1]).text)
        end)
    end

    it("folds constants", function()
        assert.are.equal("5", simplified("2+3").text)
        assert.are.equal("1/2", simplified("1/3+1/6").text)
    end)

    it("collects like terms across different orders", function()
        assert.are.equal("5*x", simplified("2*x+x*3").text)
        assert.are.equal("3*x*y", simplified("x*y+2*y*x").text)
        assert.are.equal("x^2+3*x", simplified("x^2+x+2*x").text)
    end)

    it("drops terms whose coefficients cancel", function()
        assert.are.equal("y", simplified("x+y-x").text)
        assert.are.equal("0", simplified("sin(x)-sin(x)").text)
    end)

    it("combines repeated factors with same-sign integer exponents", function()
        assert.are.equal("x^2", simplified("x*x").text)
        assert.are.equal("x^5", simplified("x^2*x^3").text)
    end)

    it("simplifies x^0 to 1 and notes the restriction", function()
        local res = simplified("x^0")
        assert.are.equal("1", res.text)
        assert.are.same({ "x ≠ 0" }, res.assumptions)
    end)

    it("keeps x*0 only when the other factor is defined everywhere", function()
        assert.are.equal("0", simplified("x*0").text)
        assert.are_not.equal("0", simplified("(1/x)*0").text)
    end)

    it("simplifies nested arguments", function()
        assert.are.equal("sin(2*x)", simplified("sin(x+x)").text)
    end)

    it("reports syntax errors", function()
        local res, err = calccas.simplify("2 +* 3")
        assert.is_nil(res)
        assert.are.equal("syntax", err.kind)
    end)
end)
