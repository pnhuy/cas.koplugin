-- Independently prepared reference cases. Expected values were worked out by
-- hand (rational arithmetic / textbook identities) and match the normative
-- vectors in specs/001-calculator-cas-graphing/contracts/cas-api.md. They are
-- data only: the evaluator, simplifier and printer specs consume them.

return {
  -- evaluate(input) -> printed text
  evaluate = {
    { "2 + 3*4", "14" },                 -- 2 + 12
    { "1/3 + 1/6", "1/2" },              -- 2/6 + 1/6 = 3/6
    { "-2^2", "-4" },                    -- unary minus applies after the power
    { "2^3^2", "512" },                  -- 2^(3^2) = 2^9
    { "0.25 + 1/4", "1/2" },             -- 1/4 + 1/4
    { "2^-1", "1/2" },
    { "(1/2)^2", "1/4" },
    { "sqrt(9/4)", "3/2" },              -- perfect-square rational stays exact
    { "abs(-3)", "3" },
  },

  -- evaluate(input) -> error kind (and position for syntax errors)
  errors = {
    { "1/0", "div_by_zero" },
    { "sqrt(-1)", "domain" },
    { "log(0)", "domain" },
    { "10^1000", "overflow" },
    { "2 +* 3", "syntax", 4 },           -- `*` is the unexpected token, 4th character
    { 'os.execute("x")', "syntax", 3 },  -- never executed; '.' is the first illegal character
  },

  -- simplify(input) -> printed text
  simplify = {
    { "2*x + 3*x", "5*x" },
    { "x*1", "x" },
    { "x + 0", "x" },
    { "x*0", "0" },
    { "x^1", "x" },
    { "x - x", "0" },
  },

  -- expand(input) -> printed text, highest degree first
  expand = {
    { "(x+1)^2", "x^2+2*x+1" },          -- (x+1)(x+1) = x^2 + 2x + 1
    { "(x+1)*(x-1)", "x^2-1" },          -- difference of squares
    { "(x+2)*(x+3)", "x^2+5*x+6" },
  },

  -- simplify must not cancel across a possible zero: result unchanged + note
  domain_notes = {
    { "x/x", "x/x", { "x ≠ 0" } },
  },
}
