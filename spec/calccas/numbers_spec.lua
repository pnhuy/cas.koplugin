local calccas = require("calccas")

local function text(src)
  local r, err = calccas.evaluate(src)
  assert.is_truthy(r, src .. ": " .. tostring(err and err.message))
  return r.text, r
end

local function fails(src)
  local r, err = calccas.evaluate(src)
  assert.is_nil(r, src)
  return err
end

describe("exact and approximate numbers", function()
  it("reads decimals as exact rationals", function()
    assert.are.equal("3/10", text("0.1+0.2"))
    assert.are.equal("1/2", text("0.5"))
    assert.are.equal("5/6", text("1/3+0.5"))
  end)

  it("reads scientific notation exactly when it fits", function()
    assert.are.equal("1000", text("1e3"))
    assert.are.equal("1/1000", text("1e-3"))
    assert.are.equal("1000/7", text("1e3/7"))
  end)

  it("shows approximate values with a ≈", function()
    for _, src in ipairs({ "sin(1)", "pi", "e", "2^0.5" }) do
      local shown, result = text(src)
      assert.is_truthy(shown:find("≈", 1, true), src .. " -> " .. shown)
      assert.is_number(result.value, src)
    end
  end)

  it("keeps exact results free of ≈", function()
    for _, src in ipairs({ "1/3", "sqrt(9/4)", "cos(0)", "2^-1", "0.25+1/4" }) do
      assert.is_nil(text(src):find("≈", 1, true), src)
    end
  end)

  it("promotes an exact value that outgrows the rationals to approximate", function()
    local shown = text("1e30")
    assert.are.equal("1e+30", shown)
    assert.are.equal("1e+60", text("1e30*1e30"))
  end)

  it("reports overflow beyond the double range", function()
    assert.are.equal("overflow", fails("1e999").kind)
    assert.are.equal("overflow", fails("1e-999").kind)
    assert.are.equal("overflow", fails("1e300*1e300").kind)
    assert.are.equal("overflow", fails("10^400").kind)
  end)

  it("keeps each side of a relation as exact as it is", function()
    assert.are.equal("x+1 == 6", text("x + 1 == 2*3"))
    assert.are.equal("1/2 == 1/2", text("0.5 == 1/2"))
    assert.is_truthy(text("sin(1) == 1"):find("sin(1)", 1, true))
  end)

  it("does not give approx a value in language 1.0", function()
    local err = fails("approx(1/3)")
    assert.are.equal("unsupported", err.kind)
  end)
end)
