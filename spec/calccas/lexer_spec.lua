local lexer = require("calccas.lexer")

local function kinds(text)
  local tokens = assert(lexer.tokenize(text))
  local out = {}
  for _, t in ipairs(tokens) do out[#out + 1] = t.type .. ":" .. t.text end
  return table.concat(out, " ")
end

describe("calccas.lexer", function()
  it("tokenizes integers, decimals and leading-dot decimals", function()
    assert.are.equal("num:12 num:3.25 num:.5 eof:", kinds("12 3.25 .5"))
  end)

  it("tokenizes identifiers, operators and parentheses", function()
    assert.are.equal("ident:sin lparen:( ident:x_1 op:^ num:2 rparen:) eof:", kinds("sin(x_1^2)"))
  end)

  it("records 1-based positions and an eof token past the end", function()
    local tokens = assert(lexer.tokenize("2 +x"))
    assert.are.same({ 1, 3, 4, 5 }, { tokens[1].pos, tokens[2].pos, tokens[3].pos, tokens[4].pos })
    assert.are.equal("eof", tokens[4].type)
  end)

  it("splits a second dot into its own number so the parser can reject it", function()
    assert.are.equal("num:1.2 num:.3 eof:", kinds("1.2.3"))
  end)

  it("rejects illegal characters with their position", function()
    local tokens, err = lexer.tokenize("2 # 3")
    assert.is_nil(tokens)
    assert.are.equal("syntax", err.kind)
    assert.are.equal(3, err.pos)
  end)

  it("never accepts Lua syntax: os.execute(\"x\") fails at the dot", function()
    local tokens, err = lexer.tokenize('os.execute("x")')
    assert.is_nil(tokens)
    assert.are.equal("syntax", err.kind)
    assert.are.equal(3, err.pos)
  end)

  it("rejects non-ASCII input", function()
    local tokens, err = lexer.tokenize("2×3")
    assert.is_nil(tokens)
    assert.are.equal("syntax", err.kind)
  end)

  it("accepts empty input as just eof", function()
    assert.are.equal("eof:", kinds(""))
  end)
end)
