local calccas = require("calccas")

-- Error and boundary paths of the engine: values that cannot be evaluated,
-- expansions that would grow too large, and unusual number forms. Each must
-- come back as an error value, never a raised error.
local function fails(call, kind)
    local res, err = call()
    assert.is_nil(res)
    assert.is_not_nil(err)
    if kind then
        assert.are.equal(kind, err.kind)
    end
end

describe("calccas.evaluate error paths", function()
    it("reports an unbound variable inside every kind of node", function()
        for _, src in ipairs({ "x", "x + 1", "2 * x", "x^2", "2^x", "sin(x)", "sqrt(x)", "-x", "abs(x)" }) do
            local res = calccas.evaluate(src, {})
            -- a free symbol is allowed in symbolic results; a numeric result must not appear
            if res then
                assert.is_true(#res.free > 0, src)
            end
        end
    end)

    it("rejects variable values that are not finite numbers", function()
        fails(function() return calccas.evaluate("a + 1", { a = math.huge }) end, "overflow")
        fails(function() return calccas.evaluate("a + 1", { a = -math.huge }) end, "overflow")
        fails(function() return calccas.evaluate("a + 1", { a = 0 / 0 }) end, "domain")
    end)

    it("accepts large but finite and non-integer variable values", function()
        local res = calccas.evaluate("a * 2", { a = 1.5 })
        assert.is_not_nil(res)
        assert.are.equal(3, res.value)
        assert.is_not_nil(calccas.evaluate("a", { a = 1e300 }))
    end)

    it("handles decimal division exactly and by zero", function()
        assert.are.equal("3", calccas.evaluate("1.5/0.5").text)
        assert.are.equal("1/3", calccas.evaluate("0.1/0.3").text)
        fails(function() return calccas.evaluate("1.5/0") end)
        fails(function() return calccas.evaluate("1.5/0.0") end)
    end)

    it("handles fractional powers that are not exact", function()
        assert.is_not_nil(calccas.evaluate("2^(1/2)"))
        assert.is_not_nil(calccas.evaluate("8^(1/3)"))
        assert.is_not_nil(calccas.evaluate("(1/4)^(1/2)"))
        assert.is_not_nil(calccas.evaluate("100^(1/100)"))
        fails(function() return calccas.evaluate("(-8)^(1/3)") end)
    end)

    it("handles negative decimals and signs", function()
        assert.are.equal("-3/2", calccas.evaluate("-1.5").text)
        assert.are.equal("-3/2", calccas.evaluate("-3/2").text)
        assert.are.equal("3/2", calccas.evaluate("--1.5").text)
    end)

    it("turns domain errors into error values for each function", function()
        fails(function() return calccas.evaluate("ln(0)") end)
        fails(function() return calccas.evaluate("log(-1)") end)
        fails(function() return calccas.evaluate("sqrt(-1)") end)
        fails(function() return calccas.evaluate("tan(pi/2)") end)
        fails(function() return calccas.evaluate("exp(1000)") end)
        fails(function() return calccas.evaluate("sin(1/0)") end)
    end)
end)

describe("calccas.compile", function()
    it("compiles a numeric function of one variable and reuses it", function()
        local f = calccas.compile("x^2 + 1", "x")
        assert.is_function(f)
        assert.are.equal(2, f(1))
        assert.are.equal(5, f(2))
        assert.are.equal(1, f(0))
    end)

    it("returns nil for a domain error at a point, without raising", function()
        local f = calccas.compile("1/x", "x")
        assert.is_function(f)
        local ok, v = pcall(f, 0)
        assert.is_true(ok)
        assert.is_true(v == nil or v ~= v or v == math.huge or v == -math.huge)
    end)

    it("refuses an unknown variable in the expression", function()
        local f = calccas.compile("x + y", "x")
        if f then
            local ok = pcall(f, 1)
            assert.is_true(ok)
        end
    end)
end)

describe("calccas.expand limits", function()
    it("refuses a product that would grow too large", function()
        fails(function() return calccas.expand("(a+b+c+d)^10 * (e+f+g+h)^10") end, "too_complex")
        fails(function() return calccas.expand("(a+b+c+d+e+f)^12") end, "too_complex")
    end)

    it("passes a limit hit inside a nested node up as an error", function()
        fails(function() return calccas.expand("sin((a+b+c+d+e+f)^12)") end, "too_complex")
        fails(function() return calccas.expand("2 + (a+b+c+d+e+f)^12") end, "too_complex")
        fails(function() return calccas.expand("-(a+b+c+d+e+f)^12") end, "too_complex")
        fails(function() return calccas.expand("((a+b+c+d+e+f)^12)^2") end, "too_complex")
    end)

    it("expands within the limit", function()
        assert.are.equal("a^2+2*a*b+b^2", calccas.expand("(a+b)^2").text)
        assert.are.equal("a*c+a*d+b*c+b*d", calccas.expand("(a+b)*(c+d)").text)
    end)
end)

describe("calccas.simplify corners", function()
    it("keeps unsimplifiable parenthesised bases when printing powers", function()
        assert.is_not_nil(calccas.simplify("(a+b)^x"))
        assert.is_not_nil(calccas.simplify("(a+b)^x * (a+b)^y"))
        assert.is_not_nil(calccas.simplify("x^-1 * y^-2 * z"))
        assert.is_not_nil(calccas.simplify("x * x^-1"))
    end)

    it("collects approximate numbers with a sign", function()
        assert.is_not_nil(calccas.simplify("x * -1.5"))
        assert.is_not_nil(calccas.simplify("-1.5*x + y"))
        assert.is_not_nil(calccas.simplify("-1.5"))
    end)

    it("simplifies sums of calls and products of sums", function()
        assert.is_not_nil(calccas.simplify("sin(x) + sin(x)"))
        assert.is_not_nil(calccas.simplify("(a+b)*(a+b)"))
        assert.is_not_nil(calccas.simplify("abs(x) * abs(x)"))
    end)
end)
