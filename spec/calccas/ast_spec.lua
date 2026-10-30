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

describe("calccas.ast.dump", function()
  local a = require("calccas.ast")
  local v = a.var("x")

  it("prints atoms", function()
    assert.are.equal("3", a.dump(a.num(3)))
    assert.are.equal("1/2", a.dump(a.num(1, 2)))
    assert.are.equal("~0.5", a.dump(a.float(0.5)))
    assert.are.equal("x", a.dump(v))
    assert.are.equal("pi", a.dump(a.const("pi")))
  end)

  it("prints operators as named lists", function()
    assert.are.equal("(add 1 (mul 2 x))", a.dump(a.add({ a.num(1), a.mul({ a.num(2), v }) })))
    assert.are.equal("(pow x 2)", a.dump(a.pow(v, a.num(2))))
    assert.are.equal("(sin x)", a.dump(a.fn("sin", v)))
  end)

  it("prints the statement nodes", function()
    assert.are.equal("(rel == x 1)", a.dump(a.rel("==", v, a.num(1))))
    assert.are.equal("(call simplify x)", a.dump(a.call("simplify", { v })))
    assert.are.equal("(call plot x (range x -5 5))",
      a.dump(a.call("plot", { v, a.range("x", a.num(-5), a.num(5)) })))
    assert.are.equal("(assign a 2)", a.dump(a.assign("a", a.num(2))))
    assert.are.equal("(funcdef f (x y) (mul x y))",
      a.dump(a.funcdef("f", { "x", "y" }, a.mul({ v, a.var("y") }))))
  end)

  it("is deterministic", function()
    local tree = a.add({ a.var("y"), v, a.num(2) })
    assert.are.equal(a.dump(tree), a.dump(tree))
  end)
end)

describe("calccas.ast statement nodes", function()
  local a = require("calccas.ast")
  local v = a.var("x")

  it("compares structurally", function()
    assert.is_true(a.equal(a.rel("==", v, a.num(1)), a.rel("==", v, a.num(1))))
    assert.is_false(a.equal(a.rel("==", v, a.num(1)), a.rel("==", v, a.num(2))))
    assert.is_false(a.equal(a.call("simplify", { v }), a.call("expand", { v })))
    assert.is_false(a.equal(a.call("simplify", { v }), a.call("simplify", { v, v })))
    assert.is_true(a.equal(a.range("x", a.num(0), a.num(1)), a.range("x", a.num(0), a.num(1))))
    assert.is_false(a.equal(a.assign("a", v), a.assign("b", v)))
    assert.is_false(a.equal(a.funcdef("f", { "x" }, v), a.funcdef("f", { "y" }, v)))
  end)

  it("counts and measures nested statement nodes", function()
    local tree = a.rel("==", a.add({ v, a.num(1) }), a.num(2))
    assert.are.equal(5, a.count(tree))
    assert.are.equal(3, a.depth(tree))
    local call = a.call("plot", { v, a.range("x", a.num(0), a.num(1)) })
    assert.are.equal(5, a.count(call))
  end)

  it("substitutes inside relations, calls and ranges", function()
    local tree = a.call("simplify", { a.rel("==", v, a.num(1)) })
    local out = a.substitute(tree, "x", a.num(7))
    assert.are.equal("(call simplify (rel == 7 1))", a.dump(out))
    local r = a.substitute(a.range("x", v, a.add({ v, a.num(1) })), "x", a.num(2))
    assert.are.equal("(range x 2 3)", a.dump(r))
  end)

  it("orders mixed expression and statement nodes without erroring", function()
    local sum = a.add({ v, a.call("simplify", { v }), a.rel("==", v, v) })
    assert.is_truthy(a.dump(sum))
  end)
end)
