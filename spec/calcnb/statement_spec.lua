local statement = require("calcnb.statement")

local function one(src)
  local list, err = statement.parse(src)
  assert.is_nil(err, err and err.message)
  assert.are.equal(1, #list)
  return list[1]
end

describe("calcnb.statement", function()
  it("classifies an expression", function()
    local s = one("x^2 + 1")
    assert.are.equal("expr", s.kind)
    assert.are.equal("x^2 + 1", s.text)
    assert.are.equal(1, s.line)
  end)

  it("classifies an assignment", function()
    local s = one("a = 2 + 3")
    assert.are.equal("assign", s.kind)
    assert.are.equal("a", s.name)
    assert.are.equal("2 + 3", s.text)
  end)

  it("classifies a function definition", function()
    local s = one("f(x) = x^2 + a*x")
    assert.are.equal("funcdef", s.kind)
    assert.are.equal("f", s.name)
    assert.are.equal("x", s.param)
    assert.are.equal("x^2 + a*x", s.text)
  end)

  it("classifies plot with and without a range", function()
    local s = one("plot(sin(x), cos(x), x=-6..6)")
    assert.are.equal("plot", s.kind)
    assert.are.same({ "sin(x)", "cos(x)" }, s.args)
    assert.are.same({ lo = "-6", hi = "6" }, s.range)
    local t = one("plot(f)")
    assert.are.same({ "f" }, t.args)
    assert.is_nil(t.range)
  end)

  it("keeps commas inside brackets within one plot argument", function()
    local s = one("plot(sin(2*x), x=0..1.5)")
    assert.are.same({ "sin(2*x)" }, s.args)
    assert.are.same({ lo = "0", hi = "1.5" }, s.range)
  end)

  it("does not treat == or <= as assignment", function()
    assert.are.equal("expr", one("a == 2").kind)
    assert.are.equal("expr", one("a <= 2").kind)
  end)

  it("skips blank lines and comments and numbers lines", function()
    local list = assert(statement.parse("# note\n\na = 1\n  \nb = a + 1\n"))
    assert.are.equal(2, #list)
    assert.are.equal(3, list[1].line)
    assert.are.equal(5, list[2].line)
  end)

  it("returns an empty list for an empty cell", function()
    assert.are.same({}, assert(statement.parse("")))
    assert.are.same({}, assert(statement.parse("# only a comment")))
  end)

  it("rejects reserved and invalid names", function()
    for _, src in ipairs({ "sin = 3", "pi = 3", "e = 1", "plot = 1", "sin(x) = x", "1a = 2" }) do
      local list, err = statement.parse(src)
      assert.is_nil(list, src)
      assert.is_truthy(err, src)
      assert.are.equal(1, err.line)
    end
    local _, err = statement.parse("sin = 3")
    assert.are.equal("reserved", err.kind)
  end)

  it("rejects names longer than 32 characters", function()
    local _, err = statement.parse(string.rep("a", 33) .. " = 1")
    assert.are.equal("name", err.kind)
  end)

  it("rejects empty right-hand sides", function()
    for _, src in ipairs({ "a =", "f(x) =", "a = " }) do
      local list, err = statement.parse(src)
      assert.is_nil(list, src)
      assert.are.equal("syntax", err.kind)
    end
  end)

  it("validates plot arguments", function()
    local _, e1 = statement.parse("plot()")
    assert.are.equal("syntax", e1.kind)
    local _, e2 = statement.parse("plot(x, x=5..1)")
    assert.are.equal("range", e2.kind)
    local _, e3 = statement.parse("plot(x, x=a..2)")
    assert.are.equal("range", e3.kind)
    local _, e4 = statement.parse("plot(1,2,3,4,5,6,7)")
    assert.are.equal("too_complex", e4.kind)
  end)

  it("reports the failing line", function()
    local _, err = statement.parse("a = 1\nb =\nc = 3")
    assert.are.equal(2, err.line)
  end)

  it("rejects statements longer than 500 characters", function()
    local _, err = statement.parse("a = " .. string.rep("1+", 300) .. "1")
    assert.are.equal("too_complex", err.kind)
  end)

  it("never executes input as Lua", function()
    _G.__calcnb_pwned = nil
    statement.parse("a = (function() __calcnb_pwned = true end)()")
    statement.parse("os.execute('true')")
    assert.is_nil(_G.__calcnb_pwned)
  end)
end)
