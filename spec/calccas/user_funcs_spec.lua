local ast = require("calccas.ast")
local calccas = require("calccas")

local function funcs(spec)
  local out = {}
  for name, def in pairs(spec) do
    out[name] = { param = def[1], body = assert(calccas.parse(def[2])) }
  end
  return out
end

describe("ast.substitute", function()
  it("replaces every occurrence of a variable", function()
    local body = assert(calccas.parse("x^2 + 3*x + y"))
    local out = ast.substitute(body, "x", ast.num(2))
    assert.are.equal("y+10", calccas.tostring(calccas.simplify(out).exact))
  end)

  it("leaves other variables and constants alone", function()
    local body = assert(calccas.parse("sin(y) + pi"))
    local out = ast.substitute(body, "x", ast.num(2))
    assert.is_true(ast.equal(body, out))
  end)
end)

describe("user function calls", function()
  it("parses a call to a defined function", function()
    local node = calccas.parse("f(2)", { user_funcs = funcs({ f = { "x", "x^2 + 1" } }) })
    assert.is_truthy(node)
  end)

  it("evaluates f(2) and f(x+1)", function()
    local fs = funcs({ f = { "x", "x^2 + 1" } })
    assert.are.equal("5", assert(calccas.evaluate("f(2)", nil, fs)).text)
    local res = assert(calccas.evaluate("expand(f(x+1))", nil, fs))
    assert.are.equal("x^2+2*x+2", res.text)
  end)

  it("uses variables bound at call time", function()
    local fs = funcs({ f = { "x", "x^2 + a*x" } })
    assert.are.equal("10", assert(calccas.evaluate("f(2)", { a = 3 }, fs)).text)
  end)

  it("allows functions calling other functions", function()
    local fs = funcs({ f = { "x", "x + 1" }, g = { "t", "2*t" } })
    assert.are.equal("8", assert(calccas.evaluate("g(f(3))", nil, fs)).text)
  end)

  it("still rejects unknown functions", function()
    local res, err = calccas.evaluate("h(2)", nil, funcs({ f = { "x", "x" } }))
    assert.is_nil(res)
    assert.are.equal("syntax", err.kind)
  end)

  it("rejects nested calls that grow past the node limit", function()
    local fs = funcs({ f = { "x", "x + x + x + x + x" } })
    local text = string.rep("f(", 20) .. "y" .. string.rep(")", 20)
    local res, err = calccas.evaluate(text, nil, fs)
    assert.is_nil(res)
    assert.are.equal("too_complex", err.kind)
  end)

  it("does not change behavior when no functions are given", function()
    local res, err = calccas.evaluate("f(2)")
    assert.is_nil(res)
    assert.are.equal("syntax", err.kind)
  end)
end)

describe("calccas.functions", function()
  it("lists the supported built-in functions sorted", function()
    assert.are.same({ "abs", "cos", "exp", "ln", "log", "sin", "sqrt", "tan" }, calccas.functions())
  end)
end)
