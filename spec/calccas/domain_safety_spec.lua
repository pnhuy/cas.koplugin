local calccas = require("calccas")
local cases = require("spec.calccas.reference_cases")

local function simplified(text)
    local res, err = calccas.simplify(text)
    assert.is_nil(err, err and tostring(err))
    return res
end

describe("simplify domain safety", function()
    for _, case in ipairs(cases.domain_notes) do
        it(case[1] .. " is unchanged and flagged", function()
            local res = simplified(case[1])
            assert.are.equal(case[2], res.text)
            assert.are.same(case[3], res.assumptions)
        end)
    end

    it("does not cancel a factor against its reciprocal", function()
        assert.are.equal("x^2/x", simplified("x^2/x").text)
        assert.are.same({ "x ≠ 0" }, simplified("x^2/x").assumptions)
    end)

    it("does not rewrite sqrt(x^2) to x", function()
        assert.are.equal("sqrt(x^2)", simplified("sqrt(x^2)").text)
    end)

    it("does not rewrite (x^a)^b with a symbolic exponent", function()
        assert.are.equal("(x^a)^b", simplified("(x^a)^b").text)
    end)

    it("does not rewrite exp(log(x)) to x", function()
        assert.are.equal("exp(log(x))", simplified("exp(log(x))").text)
    end)

    it("has no assumptions for ordinary results", function()
        assert.are.same({}, simplified("2*x+3*x").assumptions)
    end)
end)

describe("evaluation domains (language reference)", function()
    local rows = {
        { "1/0", "div_by_zero" }, { "0/0", "div_by_zero" }, { "x/0", "div_by_zero" }, { "0^-1", "div_by_zero" },
        { "sqrt(-1)", "domain" }, { "log(0)", "domain" }, { "log(-1)", "domain" }, { "ln(0)", "domain" },
        { "tan(pi/2)", "domain" }, { "(-8)^(1/3)", "domain" }, { "0^0", "undefined" },
        { "exp(1000)", "overflow" }, { "10^400", "overflow" },
    }
    for _, row in ipairs(rows) do
        it(row[1] .. " is a " .. row[2] .. " error", function()
            local res, err = calccas.evaluate(row[1])
            assert.is_nil(res)
            assert.are.equal(row[2], err.kind)
        end)
    end

    for _, src in ipairs({ "sqrt(0)", "0^2", "tan(0)", "log(1)", "(-8)^3", "(-1)^(1/1)" }) do
        it(src .. " is inside the domain", function()
            assert.is_truthy(calccas.evaluate(src))
        end)
    end
end)
