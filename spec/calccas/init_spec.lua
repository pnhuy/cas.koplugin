local calccas = require("calccas")
local cases = require("spec.calccas.reference_cases")

describe("calccas facade", function()
  describe("reference evaluation cases", function()
    for _, case in ipairs(cases.evaluate) do
      it("evaluates " .. case[1] .. " -> " .. case[2], function()
        local res, err = calccas.evaluate(case[1])
        assert.is_nil(err, err and tostring(err))
        assert.are.equal(case[2], res.text)
      end)
    end
  end)

  describe("reference error cases", function()
    for _, case in ipairs(cases.errors) do
      it("rejects " .. case[1] .. " with " .. case[2], function()
        local res, err = calccas.evaluate(case[1])
        assert.is_nil(res)
        assert.are.equal(case[2], err.kind)
        if case[3] then
          assert.are.equal(case[3], err.pos)
        end
      end)
    end
  end)

  it("formats irrational results with a decimal approximation", function()
    assert.are.equal("sqrt(2) ≈ 1.41421356", assert(calccas.evaluate("sqrt(2)")).text)
    assert.are.equal("pi ≈ 3.14159265", assert(calccas.evaluate("pi")).text)
  end)

  it("returns the symbolic form while variables are free", function()
    local res = assert(calccas.evaluate("2*x + 3*x"))
    assert.are.equal("2*x+3*x", res.text)
    assert.is_nil(res.value)
  end)

  it("evaluates with variable bindings", function()
    assert.are.equal("10", assert(calccas.evaluate("x^2 + 1", { x = 3 })).text)
  end)

  it("accepts an already parsed AST", function()
    local node = assert(calccas.parse("1/3 + 1/6"))
    assert.are.equal("1/2", assert(calccas.evaluate(node)).text)
    assert.are.equal("1/2", calccas.tostring(node))
  end)

  it("compiles a function for plotting", function()
    local f = assert(calccas.compile("x^2 - 1"))
    assert.are.equal(8, f(3))
    local g, err = calccas.compile("x + y")
    assert.is_nil(g)
    assert.are.equal("unbound_variable", err.kind)
    local h, err2 = calccas.compile("2 +* 3")
    assert.is_nil(h)
    assert.are.equal("syntax", err2.kind)
  end)

  describe("parse_assignments", function()
    it("parses a comma-separated list into bindings", function()
      local vars = assert(calccas.parse_assignments("x=2, y = 1/2; z=0.25"))
      assert.are.equal("14", assert(calccas.evaluate("x*7 + y*0 + z*0", vars)).text)
      assert.are.equal("1/2", assert(calccas.evaluate("y", vars)).text)
      assert.are.equal("1/4", assert(calccas.evaluate("z", vars)).text)
    end)
    it("treats blank input as no bindings", function()
      assert.are.same({}, assert(calccas.parse_assignments("  ")))
    end)
    it("accepts expressions as values", function()
      local vars = assert(calccas.parse_assignments("x = 1+2"))
      assert.are.equal("3", assert(calccas.evaluate("x", vars)).text)
    end)
    it("rejects malformed assignments", function()
      for _, bad in ipairs({ "x", "x=", "=2", "2=x", "pi=3", "sin=1", "x=y", "x=1/0", "x=2,,y=3", "x=1=2" }) do
        local vars, err = calccas.parse_assignments(bad)
        assert.is_nil(vars, bad)
        assert.is_table(err, bad)
      end
    end)
  end)

  describe("robustness", function()
    it("never throws for non-text input", function()
      for _, bad in ipairs({ 42, true, {}, function() end }) do
        local res, err = calccas.evaluate(bad)
        assert.is_nil(res)
        assert.is_table(err)
        assert.is_nil((calccas.compile(bad)))
        assert.is_nil((calccas.parse(bad)))
      end
      assert.is_nil((calccas.evaluate(nil)))
    end)

    it("never throws or reports an internal error for fuzzed strings", function()
      math.randomseed(20260101)
      local alphabet = "0123456789+-*/^()xyzpieansctolgbq.,= \t_%#\"'\\é×"
      local chars = {}
      for c in alphabet:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = c end
      local tokens = { "sin(", "cos(", "sqrt(", "log(", "x", "pi", "2", "^", "(", ")", "/", "*", "-", "0", "e" }
      for i = 1, 3000 do
        local parts = {}
        local n = math.random(0, 40)
        for j = 1, n do
          if i % 2 == 0 then
            parts[j] = tokens[math.random(#tokens)]
          else
            parts[j] = chars[math.random(#chars)]
          end
        end
        local text = table.concat(parts)
        local res, err = calccas.evaluate(text, { x = 2 })
        assert.is_true((res ~= nil) ~= (err ~= nil), text)
        if err then assert.are_not.equal("internal", err.kind, text) end
        local f, ferr = calccas.compile(text)
        assert.is_true((f ~= nil) ~= (ferr ~= nil), text)
        if ferr then assert.are_not.equal("internal", ferr.kind, text) end
        if f then
          local v = f(math.random() * 20 - 10)
          assert.is_true(v == nil or (v == v and v ~= math.huge and v ~= -math.huge), text)
        end
      end
    end)

    it("handles very long and very deep input", function()
      assert.are.equal("too_complex", select(2, calccas.evaluate(string.rep("1+", 400))).kind)
      assert.are.equal("too_complex", select(2, calccas.evaluate(string.rep("(", 200) .. "1" .. string.rep(")", 200))).kind)
    end)
  end)
end)
