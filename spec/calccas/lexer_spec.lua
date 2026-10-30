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
    local tokens, err = lexer.tokenize("2 $ 3")
    assert.is_nil(tokens)
    assert.are.equal("syntax", err.kind)
    assert.are.equal(3, err.pos)
  end)

  it("treats # as a comment to the end of the line", function()
    assert.are.equal("num:2 newline:\n num:3 eof:", kinds("2 # note\n3"))
  end)

  it("emits comma, eq, eqeq and dotdot", function()
    assert.are.equal("ident:f lparen:( num:1 comma:, num:2 rparen:) eof:", kinds("f(1,2)"))
    assert.are.equal("ident:a eq:= num:1 eof:", kinds("a=1"))
    assert.are.equal("ident:a eqeq:== num:1 eof:", kinds("a==1"))
    assert.are.equal("ident:x eq:= op:- num:5 dotdot:.. num:5 eof:", kinds("x=-5..5"))
  end)

  it("continues a statement inside brackets and after a trailing operator, = or ,", function()
    assert.are.equal("num:1 op:+ num:2 eof:", kinds("1 +\n2"))
    assert.are.equal("ident:a eq:= num:1 eof:", kinds("a =\n1"))
    assert.are.equal("lparen:( num:1 op:+ num:2 rparen:) eof:", kinds("(1\n+2)"))
    assert.are.equal("num:1 newline:\n op:+ num:2 eof:", kinds("1\n+2"))
  end)

  it("reads scientific notation as one number", function()
    assert.are.equal("num:1e3 eof:", kinds("1e3"))
    assert.are.equal("num:2.5E-4 eof:", kinds("2.5E-4"))
    assert.are.equal("num:2 ident:ex eof:", kinds("2ex"))
    local tokens, err = lexer.tokenize("2e+")
    assert.is_nil(tokens)
    assert.are.equal("syntax", err.kind)
  end)

  it("numbers the lines and recovers per line", function()
    local tokens = assert(lexer.tokenize("a\n\nb"))
    assert.are.equal(1, tokens[1].line)
    assert.are.equal(3, tokens[3].line)
    local rec = assert(lexer.tokenize("1 $ 2\nz", { recover = true }))
    assert.are.equal("error", rec[2].type)
    assert.are.equal("z", rec[4].text)
    assert.are.equal(2, rec[4].line)
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
