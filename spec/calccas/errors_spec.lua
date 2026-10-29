local errors = require("calccas.errors")

describe("calccas.errors", function()
  it("builds a typed error with kind, message and position", function()
    local e = errors.new("syntax", "unexpected '*'", 4)
    assert.are.equal("syntax", e.kind)
    assert.are.equal("unexpected '*'", e.message)
    assert.are.equal(4, e.pos)
  end)

  it("position is optional", function()
    assert.is_nil(errors.new("domain", "log of non-positive").pos)
  end)

  it("recognises its own errors", function()
    assert.is_true(errors.is(errors.new("overflow", "too large")))
    assert.is_false(errors.is("boom"))
    assert.is_false(errors.is({}))
  end)

  it("rejects unknown kinds", function()
    assert.has_error(function() errors.new("bogus", "x") end)
  end)
end)
