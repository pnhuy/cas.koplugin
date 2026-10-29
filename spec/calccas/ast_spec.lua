local ast = require("calccas.ast")
local sexp = require("spec.calccas.helpers").sexp

local x, y, z = ast.var("x"), ast.var("y"), ast.var("z")

describe("calccas.ast", function()
  it("normalizes exact numbers", function()
    assert.are.equal("1/2", sexp(ast.num(2, 4)))
    assert.are.equal("-1/2", sexp(ast.num(1, -2)))
  end)

  it("flattens nested sums and products", function()
    assert.are.equal("(+ x y z)", sexp(ast.add({ x, ast.add({ y, z }) })))
    assert.are.equal("(* x y z)", sexp(ast.mul({ ast.mul({ x, y }), z })))
  end)

  it("orders arguments canonically regardless of input order", function()
    assert.are.equal("(+ x y)", sexp(ast.add({ y, x })))
    assert.are.equal("(* x y)", sexp(ast.mul({ y, x })))
  end)

  it("folds numeric constants into one leading number", function()
    assert.are.equal("(+ 3 x)", sexp(ast.add({ ast.num(1), x, ast.num(2) })))
    assert.are.equal("(* 6 x)", sexp(ast.mul({ ast.num(2), x, ast.num(3) })))
    assert.are.equal("1/2", sexp(ast.add({ ast.num(1, 3), ast.num(1, 6) })))
  end)

  it("keeps neutral elements for the simplifier", function()
    assert.are.equal("(* 1 x)", sexp(ast.mul({ x, ast.num(1) })))
    assert.are.equal("(+ 0 x)", sexp(ast.add({ x, ast.num(0) })))
  end)

  it("collapses degenerate sums and products", function()
    assert.are.equal("x", sexp(ast.add({ x })))
    assert.are.equal("x", sexp(ast.mul({ x })))
    assert.are.equal("0", sexp(ast.add({})))
    assert.are.equal("1", sexp(ast.mul({})))
  end)

  it("falls back to a flagged float when exact folding overflows", function()
    local r = ast.mul({ ast.num(2 ^ 52), ast.num(4) })
    assert.is_true(r.approx)
    assert.are.equal(2 ^ 54, r.v)
  end)

  it("folds integer powers of exact numbers only", function()
    assert.are.equal("8", sexp(ast.pow(ast.num(2), ast.num(3))))
    assert.are.equal("1/4", sexp(ast.pow(ast.num(2), ast.num(-2))))
    assert.are.equal("(^ x 2)", sexp(ast.pow(x, ast.num(2))))
    assert.are.equal("(^ 2 1/2)", sexp(ast.pow(ast.num(2), ast.num(1, 2))))
  end)

  it("leaves division by zero, overflow and 0^0 unfolded", function()
    assert.are.equal("(^ 0 -1)", sexp(ast.pow(ast.num(0), ast.num(-1))))
    assert.are.equal("(^ 0 0)", sexp(ast.pow(ast.num(0), ast.num(0))))
    assert.are.equal("(^ 10 1000)", sexp(ast.pow(ast.num(10), ast.num(1000))))
  end)

  it("builds neg, sub and div from add/mul/pow", function()
    assert.are.equal("(* -1 x)", sexp(ast.neg(x)))
    assert.are.equal("(+ x (* -1 y))", sexp(ast.sub(x, y)))
    assert.are.equal("(* x (^ y -1))", sexp(ast.div(x, y)))
    assert.are.equal("-3", sexp(ast.neg(ast.num(3))))
  end)

  it("orders node kinds: num < const < var < pow < fn < mul < add", function()
    local nodes = {
      ast.add({ x, y }), ast.mul({ x, y }), ast.fn("sin", x), ast.pow(x, ast.num(2)),
      x, ast.const("pi"), ast.num(5),
    }
    table.sort(nodes, function(a, b) return ast.compare(a, b) < 0 end)
    local out = {}
    for _, n in ipairs(nodes) do out[#out + 1] = sexp(n) end
    assert.are.same({ "5", "pi", "x", "(^ x 2)", "(sin x)", "(* x y)", "(+ x y)" }, out)
  end)

  it("compares structurally", function()
    assert.is_true(ast.equal(ast.add({ x, y }), ast.add({ y, x })))
    assert.is_false(ast.equal(x, y))
    assert.is_false(ast.equal(ast.num(1, 2), ast.float(0.5)))
  end)

  it("counts nodes and measures depth", function()
    local tree = ast.add({ x, ast.mul({ ast.num(2), y }) })
    assert.are.equal(5, ast.count(tree))
    assert.are.equal(3, ast.depth(tree))
  end)
end)

describe("calccas.ast integer-power normalization", function()
  local ast2 = require("calccas.ast")
  local sexp2 = require("spec.calccas.helpers").sexp
  local a, b = ast2.var("y"), ast2.var("z")

  it("distributes integer powers over products", function()
    assert.are.equal("(* (^ y -1) (^ z -1))", sexp2(ast2.pow(ast2.mul({ a, b }), ast2.num(-1))))
    assert.are.equal("(* 4 (^ y 2))", sexp2(ast2.pow(ast2.mul({ ast2.num(2), a }), ast2.num(2))))
  end)

  it("merges nested integer powers", function()
    assert.are.equal("(^ y -2)", sexp2(ast2.pow(ast2.pow(a, ast2.num(2)), ast2.num(-1))))
  end)

  it("leaves zero, fractional and symbolic exponents alone", function()
    assert.are.equal("(^ (* y z) 0)", sexp2(ast2.pow(ast2.mul({ a, b }), ast2.num(0))))
    assert.are.equal("(^ (* y z) 1/2)", sexp2(ast2.pow(ast2.mul({ a, b }), ast2.num(1, 2))))
    assert.are.equal("(^ (^ y 2) 1/2)", sexp2(ast2.pow(ast2.pow(a, ast2.num(2)), ast2.num(1, 2))))
  end)
end)
