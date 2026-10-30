-- Documentation of the registry's names for the autocomplete strip: the
-- signature, a one-line summary, examples and an optional note. Plain English;
-- the UI translates the summaries and notes by name. Checked against the
-- registry, the evaluator and docs/language/reference-1.0.md by
-- spec/calccas/builtin_docs_spec.lua.

local M = {}

local RESERVED_NOTE = "Reserved for a future version: running it gives the reserved message."

local DOCS = {
    sin = { signature = "sin(x)", summary = "Sine of x, in radians.", examples = { "sin(pi/2)" } },
    cos = { signature = "cos(x)", summary = "Cosine of x, in radians.", examples = { "cos(0)" } },
    tan = { signature = "tan(x)", summary = "Tangent of x, in radians.", examples = { "tan(0)" } },
    sqrt = { signature = "sqrt(x)", summary = "Square root of x.", examples = { "sqrt(9/4)" } },
    plot = {
        signature = "plot(f1[, f2, ...], x=lo..hi)",
        summary = "Plots expressions of x over a range.",
        examples = { "plot(sin(x), x=-5..5)", "plot(x^2, x)" },
    },
    abs = { signature = "abs(x)", summary = "Absolute value of x.", examples = { "abs(-3)" } },
    exp = { signature = "exp(x)", summary = "e raised to the power x.", examples = { "exp(0)" } },
    log = { signature = "log(x)", summary = "Natural logarithm of x.", examples = { "log(1)" } },
    ln = { signature = "ln(x)", summary = "Natural logarithm of x.", examples = { "ln(1)" }, note = "Another name for log." },
    simplify = { signature = "simplify(expr)", summary = "Simplifies an expression.", examples = { "simplify(2*x + 3*x)" } },
    expand = { signature = "expand(expr)", summary = "Expands products and powers.", examples = { "expand((x+1)^2)" } },
    pi = { signature = "pi", summary = "The constant pi, 3.14159...", examples = { "2*pi" } },
    e = { signature = "e", summary = "Euler's number, 2.71828...", examples = { "2*e" } },
    factor = { signature = "factor(expr)", summary = "Factors an expression.", examples = { "factor(x^2 - 1)" }, note = RESERVED_NOTE },
    solve = {
        signature = "solve(eq[, symbol])",
        summary = "Solves an equation for a symbol.",
        examples = { "solve(x^2 == 4, x)" },
        note = RESERVED_NOTE,
    },
    subs = {
        signature = "subs(expr, x, value)",
        summary = "Substitutes a value for a symbol.",
        examples = { "subs(x + 1, x, 2)" },
        note = RESERVED_NOTE,
    },
    approx = { signature = "approx(expr)", summary = "Gives a decimal approximation.", examples = { "approx(pi)" }, note = RESERVED_NOTE },
    diff = {
        signature = "diff(expr[, symbol])",
        summary = "Differentiates an expression.",
        examples = { "diff(x^2, x)" },
        note = RESERVED_NOTE,
    },
    integrate = {
        signature = "integrate(expr[, symbol])",
        summary = "Integrates an expression.",
        examples = { "integrate(x^2, x)" },
        note = RESERVED_NOTE,
    },
}

-- The documentation of a registry name, or nil. Entries are shared; callers must not modify them.
function M.get(name)
    return DOCS[name]
end

-- All entries, keyed by name (for the consistency spec).
function M.all()
    return DOCS
end

return M
