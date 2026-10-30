local calccas = require("calccas")
local notebook = require("calcnb.notebook")

local function evaluated(text)
    local res, err = calccas.evaluate(text)
    assert.is_nil(err, text)
    return res.text
end

describe("exact values of trigonometric and related functions", function()
    it("gives exact sin, cos and tan at multiples of pi/12 with a rational value", function()
        local cases = {
            ["sin(pi)"] = "0", ["sin(2*pi)"] = "0", ["sin(pi/6)"] = "1/2", ["sin(pi/2)"] = "1",
            ["sin(7*pi/6)"] = "-1/2", ["sin(-pi/6)"] = "-1/2", ["sin(13*pi/6)"] = "1/2", ["sin(3*pi/2)"] = "-1",
            ["cos(pi)"] = "-1", ["cos(pi/2)"] = "0", ["cos(pi/3)"] = "1/2", ["cos(2*pi/3)"] = "-1/2",
            ["cos(5*pi/3)"] = "1/2", ["cos(0)"] = "1", ["tan(pi/4)"] = "1", ["tan(3*pi/4)"] = "-1",
            ["tan(pi)"] = "0", ["tan(-pi/4)"] = "-1", ["sin(0.5*pi)"] = "1",
        }
        for src, want in pairs(cases) do
            assert.are.equal(want, evaluated(src), src)
        end
    end)

    it("keeps irrational values approximate", function()
        for _, src in ipairs({ "sin(pi/4)", "sin(pi/12)", "cos(pi/6)", "sin(1)" }) do
            assert.is_truthy(evaluated(src):find("≈", 1, true), src)
        end
    end)

    it("still reports the pole of tan", function()
        local res, err = calccas.evaluate("tan(pi/2)")
        assert.is_nil(res)
        assert.are.equal("domain", err.kind)
    end)

    it("simplify gives the same exact values", function()
        assert.are.equal("0", calccas.simplify("sin(pi)").text)
        assert.are.equal("1/2", calccas.simplify("cos(pi/3)").text)
    end)

    it("gives log(e) = 1 and e^1 = e", function()
        assert.are.equal("1", evaluated("ln(e)"))
        assert.are.equal("1", evaluated("log(e)"))
        assert.is_truthy(evaluated("e^1"):find("^e "))
    end)

    it("gives sqrt(a)^2 = a for an exact positive a, and leaves symbols alone", function()
        assert.are.equal("2", evaluated("sqrt(2)^2"))
        assert.are.equal("1/2", evaluated("sqrt(2)^-2"))
        assert.are.equal("1/2", evaluated("sqrt(1/2)^2"))
        assert.are.equal("sqrt(x)^2", evaluated("sqrt(x)^2"))
        assert.is_truthy(evaluated("sqrt(2)^3"):find("≈", 1, true))
        assert.are.equal("2", calccas.simplify("sqrt(2)^2").text)
    end)
end)

describe("calling a function that is not defined", function()
    local function run(source)
        local nb = notebook.new("t")
        local cell = nb.cells[1]
        nb:set_source(cell.id, source)
        return nb:run_cell(cell.id)
    end

    it("says the function is unknown rather than suggesting a multiplication", function()
        for _, src in ipairs({ "f(2)", "f(x) = f(x)", "g(x) = h(x)\nh(x) = 1" }) do
            local out = run(src)
            assert.are.equal("error", out.kind)
            assert.is_truthy(out.canonical:find("unknown function", 1, true), src)
            assert.is_nil(out.canonical:find("missing", 1, true), src)
        end
    end)

    it("still suggests `*` after a variable or a constant", function()
        assert.is_truthy(run("x = 3\nx(2)").canonical:find("missing `*`", 1, true))
        assert.is_truthy(run("pi(2)").canonical:find("missing `*`", 1, true))
    end)
end)
