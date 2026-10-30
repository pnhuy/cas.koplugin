-- Pre-change behaviour (feature 003, task T002). Data only.
-- Captured with the previous language; see specs/003-expression-language-standard/audit.md.
return {
  { source = "2 + 3*4", old = { kind = "value", display = "14" } },
  { source = "1/3 + 1/6", old = { kind = "value", display = "1/2" } },
  { source = "-2^2", old = { kind = "value", display = "-4" } },
  { source = "2^3^2", old = { kind = "value", display = "512" } },
  { source = "0.25 + 1/4", old = { kind = "value", display = "1/2" } },
  { source = "2^-1", old = { kind = "value", display = "1/2" } },
  { source = "(1/2)^2", old = { kind = "value", display = "1/4" } },
  { source = "sqrt(9/4)", old = { kind = "value", display = "3/2" } },
  { source = "abs(-3)", old = { kind = "value", display = "3" } },
  { source = "1/0", old = { kind = "error", error_kind = "div_by_zero" } },
  { source = "sqrt(-1)", old = { kind = "error", error_kind = "domain" } },
  { source = "log(0)", old = { kind = "error", error_kind = "domain" } },
  { source = "10^1000", old = { kind = "error", error_kind = "overflow" } },
  { source = "2 +* 3", old = { kind = "error", error_kind = "syntax" } },
  { source = "os.execute(\"x\")", old = { kind = "error", error_kind = "syntax" } },
  { source = "simplify(2*x + 3*x)", old = { kind = "value", display = "5*x" } },
  { source = "simplify(x*1)", old = { kind = "value", display = "x" } },
  { source = "simplify(x + 0)", old = { kind = "value", display = "x" } },
  { source = "simplify(x*0)", old = { kind = "value", display = "0" } },
  { source = "simplify(x^1)", old = { kind = "value", display = "x" } },
  { source = "simplify(x - x)", old = { kind = "value", display = "0" } },
  { source = "expand((x+1)^2)", old = { kind = "value", display = "x²+2*x+1" } },
  { source = "expand((x+1)*(x-1))", old = { kind = "value", display = "x²-1" } },
  { source = "expand((x+2)*(x+3))", old = { kind = "value", display = "x²+5*x+6" } },
  { source = "simplify(x/x)", old = { kind = "value", display = "x/x" } },
  { source = "0.5", old = { kind = "value", display = "1/2" } },
  { source = "0.1+0.2", old = { kind = "value", display = "3/10" } },
  { source = ".5", old = { kind = "value", display = "1/2" } },
  { source = "3", old = { kind = "value", display = "3" } },
  { source = "sin(1)", old = { kind = "value", display = "sin(1) ≈ 0.841470985" } },
  { source = "cos(0)", old = { kind = "value", display = "1" } },
  { source = "tan(0)", old = { kind = "value", display = "0" } },
  { source = "exp(0)", old = { kind = "value", display = "1" } },
  { source = "log(1)", old = { kind = "value", display = "0" } },
  { source = "ln(1)", old = { kind = "value", display = "0" } },
  { source = "sqrt(16)", old = { kind = "value", display = "4" } },
  { source = "abs(-2)", old = { kind = "value", display = "2" } },
  { source = "pi", old = { kind = "value", display = "π ≈ 3.14159265" } },
  { source = "e", old = { kind = "value", display = "e ≈ 2.71828183" } },
  { source = "2*pi", old = { kind = "value", display = "2*π ≈ 6.28318531" } },
  { source = "x + 1", old = { kind = "value", display = "x+1" } },
  { source = "x*x", old = { kind = "value", display = "x*x" } },
  { source = "x^2*x", old = { kind = "value", display = "x*x²" } },
  { source = "(x+1)^3", old = { kind = "value", display = "(x+1)³" } },
  { source = "1/3", old = { kind = "value", display = "1/3" } },
  { source = "7/3 - 1/3", old = { kind = "value", display = "2" } },
  { source = "2x", old = { kind = "value", display = "2*x" } },
  { source = "3(x)", old = { kind = "value", display = "3*x" } },
  { source = "(x)(y)", old = { kind = "value", display = "x*y" } },
  { source = "2(x+1)", old = { kind = "value", display = "2*(x+1)" } },
  { source = "(x+1)(x-1)", old = { kind = "value", display = "(x-1)*(x+1)" } },
  { source = "1/2x", old = { kind = "value", display = "x/2" } },
  { source = "2pi", old = { kind = "value", display = "2*π ≈ 6.28318531" } },
  { source = "3sin(x)", old = { kind = "value", display = "3*sin(x)" } },
  { source = "2e", old = { kind = "value", display = "2*e ≈ 5.43656366" } },
  { source = "2 3", old = { kind = "error", error_kind = "syntax" } },
  { source = "x y", old = { kind = "error", error_kind = "syntax" } },
  { source = "1e3", old = { kind = "value", display = "e3" } },
  { source = "1e-3", old = { kind = "value", display = "e-3 ≈ -0.281718172" } },
  { source = "2*e", old = { kind = "value", display = "2*e ≈ 5.43656366" } },
  { source = "2 * e", old = { kind = "value", display = "2*e ≈ 5.43656366" } },
  { source = "e3", old = { kind = "value", display = "e3" } },
  { source = "x == 1", old = { kind = "error", error_kind = "syntax" } },
  { source = "1 + 2 # c", old = { kind = "error", error_kind = "syntax" } },
  { source = "f(1, 2)", old = { kind = "error", error_kind = "syntax" } },
  { source = "diff(x^2, x)", old = { kind = "error", error_kind = "syntax" } },
  { source = "diff(x)", old = { kind = "error", error_kind = "syntax" } },
  { source = "solve(x^2-4=0, x)", old = { kind = "error", error_kind = "syntax" } },
  { source = "factor(x^2-1)", old = { kind = "error", error_kind = "syntax" } },
  { source = "approx(1/3)", old = { kind = "error", error_kind = "syntax" } },
  { source = "a = 2", old = { kind = "value", display = "a = 2" } },
  { source = "a = 2\
a^2 + 1", old = { kind = "value", display = "5" } },
  { source = "a = 2\
b = a + 1\
b * 10", old = { kind = "value", display = "30" } },
  { source = "f(x) = x^2 + 1\
f(3)", old = { kind = "value", display = "10" } },
  { source = "f(x) = x^2\
f(f(2))", old = { kind = "value", display = "16" } },
  { source = "# only a comment\
2 + 2", old = { kind = "value", display = "4" } },
  { source = "\
\
  \
", old = { kind = "value", display = "" } },
  { source = "a = 1\
b = 1/0", old = { kind = "error", error_kind = "div_by_zero" } },
  { source = "a = 1\
sin(", old = { kind = "error", error_kind = "syntax" } },
  { source = "b = x + 1", old = { kind = "error", error_kind = "unbound_variable" } },
  { source = "diff = 3", old = { kind = "value", display = "diff = 3" } },
  { source = "solve = 1", old = { kind = "value", display = "solve = 1" } },
  { source = "factor(x) = x", old = { kind = "value", display = "factor(x) = x" } },
  { source = "sin = 2", old = { kind = "error", error_kind = "reserved" } },
  { source = "pi = 3", old = { kind = "error", error_kind = "reserved" } },
  { source = "plot = 1", old = { kind = "error", error_kind = "reserved" } },
  { source = "simplify(x + x)", old = { kind = "value", display = "2*x" } },
  { source = "expand((x+y)^2)", old = { kind = "value", display = "x²+2*x*y+y²" } },
  { source = "plot(sin(x))", old = { kind = "graph", n = 1, lo = nil, hi = nil } },
  { source = "plot(sin(x), cos(x), x=-6..6)", old = { kind = "graph", n = 2, lo = -6, hi = 6 } },
  { source = "plot(x^2, x=-2..2)", old = { kind = "graph", n = 1, lo = -2, hi = 2 } },
  { source = "plot(f)", old = { kind = "error", error_kind = "unbound_variable" } },
  { source = "f(x) = x^2\
plot(f)", old = { kind = "graph", n = 1, lo = nil, hi = nil } },
  { source = "plot(x,x,x,x,x,x,x)", old = { kind = "error", error_kind = "too_complex" } },
  { source = "plot(x, x=5..-5)", old = { kind = "error", error_kind = "range" } },
  { source = "plot(x, x=a..3)", old = { kind = "error", error_kind = "range" } },
  { source = "plot(sin(x), y=-1..1)", old = { kind = "error", error_kind = "syntax" } },
  { source = "os.execute('true')", old = { kind = "error", error_kind = "syntax" } },
  { source = "load('x')", old = { kind = "error", error_kind = "syntax" } },
  { source = "a = (function() end)()", old = { kind = "error", error_kind = "syntax" } },
  { source = "1 +", old = { kind = "error", error_kind = "syntax" } },
  { source = "(1", old = { kind = "error", error_kind = "syntax" } },
  { source = "1)", old = { kind = "error", error_kind = "syntax" } },
  { source = "", old = { kind = "value", display = "" } },
  { source = "   ", old = { kind = "value", display = "" } },
  { source = "(-8)^(1/3)", old = { kind = "error", error_kind = "domain" } },
  { source = "0^0", old = { kind = "error", error_kind = "undefined" } },
  { source = "sqrt(-4)", old = { kind = "error", error_kind = "domain" } },
  { source = "log(-1)", old = { kind = "error", error_kind = "domain" } },
  { source = "0/0", old = { kind = "error", error_kind = "div_by_zero" } },
  { source = "a1 = 1\
a1^2 + 1", old = { kind = "value", display = "2" } },
  { source = "a2 = 2\
a2^2 + 1", old = { kind = "value", display = "5" } },
  { source = "f3(x) = x^2 + 3*x\
expand((x+3)^2)", old = { kind = "value", display = "x²+6*x+9" } },
  { source = "a4 = 4\
a4^2 + 1", old = { kind = "value", display = "17" } },
  { source = "a5 = 5\
a5^2 + 1", old = { kind = "value", display = "26" } },
  { source = "f6(x) = x^2 + 6*x\
expand((x+6)^2)", old = { kind = "value", display = "x²+12*x+36" } },
  { source = "a7 = 7\
a7^2 + 1", old = { kind = "value", display = "50" } },
  { source = "a8 = 8\
a8^2 + 1", old = { kind = "value", display = "65" } },
  { source = "f9(x) = x^2 + 9*x\
expand((x+9)^2)", old = { kind = "value", display = "x²+18*x+81" } },
  { source = "plot(sin(x) + 10, x^2 / 10)", old = { kind = "graph", n = 2, lo = nil, hi = nil } },
  { source = "a11 = 11\
a11^2 + 1", old = { kind = "value", display = "122" } },
  { source = "f12(x) = x^2 + 12*x\
expand((x+12)^2)", old = { kind = "value", display = "x²+24*x+144" } },
  { source = "a13 = 13\
a13^2 + 1", old = { kind = "value", display = "170" } },
  { source = "a14 = 14\
a14^2 + 1", old = { kind = "value", display = "197" } },
  { source = "f15(x) = x^2 + 15*x\
expand((x+15)^2)", old = { kind = "value", display = "x²+30*x+225" } },
  { source = "a16 = 16\
a16^2 + 1", old = { kind = "value", display = "257" } },
  { source = "a17 = 17\
a17^2 + 1", old = { kind = "value", display = "290" } },
  { source = "f18(x) = x^2 + 18*x\
expand((x+18)^2)", old = { kind = "value", display = "x²+36*x+324" } },
  { source = "a19 = 19\
a19^2 + 1", old = { kind = "value", display = "362" } },
  { source = "plot(sin(x) + 20, x^2 / 20)", old = { kind = "graph", n = 2, lo = nil, hi = nil } },
  { source = "f21(x) = x^2 + 21*x\
expand((x+21)^2)", old = { kind = "value", display = "x²+42*x+441" } },
  { source = "a22 = 22\
a22^2 + 1", old = { kind = "value", display = "485" } },
  { source = "a23 = 23\
a23^2 + 1", old = { kind = "value", display = "530" } },
  { source = "f24(x) = x^2 + 24*x\
expand((x+24)^2)", old = { kind = "value", display = "x²+48*x+576" } },
  { source = "a25 = 25\
a25^2 + 1", old = { kind = "value", display = "626" } },
  { source = "a26 = 26\
a26^2 + 1", old = { kind = "value", display = "677" } },
  { source = "f27(x) = x^2 + 27*x\
expand((x+27)^2)", old = { kind = "value", display = "x²+54*x+729" } },
  { source = "a28 = 28\
a28^2 + 1", old = { kind = "value", display = "785" } },
  { source = "a29 = 29\
a29^2 + 1", old = { kind = "value", display = "842" } },
  { source = "plot(sin(x) + 30, x^2 / 30)", old = { kind = "graph", n = 2, lo = nil, hi = nil } },
  { source = "a31 = 31\
a31^2 + 1", old = { kind = "value", display = "962" } },
  { source = "a32 = 32\
a32^2 + 1", old = { kind = "value", display = "1025" } },
  { source = "f33(x) = x^2 + 33*x\
expand((x+33)^2)", old = { kind = "value", display = "x²+66*x+1089" } },
  { source = "a34 = 34\
a34^2 + 1", old = { kind = "value", display = "1157" } },
  { source = "a35 = 35\
a35^2 + 1", old = { kind = "value", display = "1226" } },
  { source = "f36(x) = x^2 + 36*x\
expand((x+36)^2)", old = { kind = "value", display = "x²+72*x+1296" } },
  { source = "a37 = 37\
a37^2 + 1", old = { kind = "value", display = "1370" } },
  { source = "a38 = 38\
a38^2 + 1", old = { kind = "value", display = "1445" } },
  { source = "f39(x) = x^2 + 39*x\
expand((x+39)^2)", old = { kind = "value", display = "x²+78*x+1521" } },
  { source = "plot(sin(x) + 40, x^2 / 40)", old = { kind = "graph", n = 2, lo = nil, hi = nil } },
  { source = "a41 = 41\
a41^2 + 1", old = { kind = "value", display = "1682" } },
  { source = "f42(x) = x^2 + 42*x\
expand((x+42)^2)", old = { kind = "value", display = "x²+84*x+1764" } },
  { source = "a43 = 43\
a43^2 + 1", old = { kind = "value", display = "1850" } },
  { source = "a44 = 44\
a44^2 + 1", old = { kind = "value", display = "1937" } },
  { source = "f45(x) = x^2 + 45*x\
expand((x+45)^2)", old = { kind = "value", display = "x²+90*x+2025" } },
  { source = "a46 = 46\
a46^2 + 1", old = { kind = "value", display = "2117" } },
  { source = "a47 = 47\
a47^2 + 1", old = { kind = "value", display = "2210" } },
  { source = "f48(x) = x^2 + 48*x\
expand((x+48)^2)", old = { kind = "value", display = "x²+96*x+2304" } },
  { source = "a49 = 49\
a49^2 + 1", old = { kind = "value", display = "2402" } },
  { source = "plot(sin(x) + 50, x^2 / 50)", old = { kind = "graph", n = 2, lo = nil, hi = nil } },
  { source = "f51(x) = x^2 + 51*x\
expand((x+51)^2)", old = { kind = "value", display = "x²+102*x+2601" } },
  { source = "a52 = 52\
a52^2 + 1", old = { kind = "value", display = "2705" } },
  { source = "a53 = 53\
a53^2 + 1", old = { kind = "value", display = "2810" } },
  { source = "f54(x) = x^2 + 54*x\
expand((x+54)^2)", old = { kind = "value", display = "x²+108*x+2916" } },
  { source = "a55 = 55\
a55^2 + 1", old = { kind = "value", display = "3026" } },
  { source = "a56 = 56\
a56^2 + 1", old = { kind = "value", display = "3137" } },
  { source = "f57(x) = x^2 + 57*x\
expand((x+57)^2)", old = { kind = "value", display = "x²+114*x+3249" } },
  { source = "a58 = 58\
a58^2 + 1", old = { kind = "value", display = "3365" } },
  { source = "a59 = 59\
a59^2 + 1", old = { kind = "value", display = "3482" } },
  { source = "plot(sin(x) + 60, x^2 / 60)", old = { kind = "graph", n = 2, lo = nil, hi = nil } },
  { source = "a61 = 61\
a61^2 + 1", old = { kind = "value", display = "3722" } },
  { source = "a62 = 62\
a62^2 + 1", old = { kind = "value", display = "3845" } },
  { source = "f63(x) = x^2 + 63*x\
expand((x+63)^2)", old = { kind = "value", display = "x²+126*x+3969" } },
  { source = "a64 = 64\
a64^2 + 1", old = { kind = "value", display = "4097" } },
  { source = "a65 = 65\
a65^2 + 1", old = { kind = "value", display = "4226" } },
  { source = "f66(x) = x^2 + 66*x\
expand((x+66)^2)", old = { kind = "value", display = "x²+132*x+4356" } },
  { source = "a67 = 67\
a67^2 + 1", old = { kind = "value", display = "4490" } },
  { source = "a68 = 68\
a68^2 + 1", old = { kind = "value", display = "4625" } },
  { source = "f69(x) = x^2 + 69*x\
expand((x+69)^2)", old = { kind = "value", display = "x²+138*x+4761" } },
  { source = "plot(sin(x) + 70, x^2 / 70)", old = { kind = "graph", n = 2, lo = nil, hi = nil } },
  { source = "a71 = 71\
a71^2 + 1", old = { kind = "value", display = "5042" } },
  { source = "f72(x) = x^2 + 72*x\
expand((x+72)^2)", old = { kind = "value", display = "x²+144*x+5184" } },
  { source = "a73 = 73\
a73^2 + 1", old = { kind = "value", display = "5330" } },
  { source = "a74 = 74\
a74^2 + 1", old = { kind = "value", display = "5477" } },
  { source = "f75(x) = x^2 + 75*x\
expand((x+75)^2)", old = { kind = "value", display = "x²+150*x+5625" } },
  { source = "a76 = 76\
a76^2 + 1", old = { kind = "value", display = "5777" } },
  { source = "a77 = 77\
a77^2 + 1", old = { kind = "value", display = "5930" } },
  { source = "f78(x) = x^2 + 78*x\
expand((x+78)^2)", old = { kind = "value", display = "x²+156*x+6084" } },
  { source = "a79 = 79\
a79^2 + 1", old = { kind = "value", display = "6242" } },
  { source = "plot(sin(x) + 80, x^2 / 80)", old = { kind = "graph", n = 2, lo = nil, hi = nil } },
  { source = "f81(x) = x^2 + 81*x\
expand((x+81)^2)", old = { kind = "value", display = "x²+162*x+6561" } },
  { source = "a82 = 82\
a82^2 + 1", old = { kind = "value", display = "6725" } },
  { source = "a83 = 83\
a83^2 + 1", old = { kind = "value", display = "6890" } },
  { source = "f84(x) = x^2 + 84*x\
expand((x+84)^2)", old = { kind = "value", display = "x²+168*x+7056" } },
  { source = "a85 = 85\
a85^2 + 1", old = { kind = "value", display = "7226" } },
  { source = "a86 = 86\
a86^2 + 1", old = { kind = "value", display = "7397" } },
  { source = "f87(x) = x^2 + 87*x\
expand((x+87)^2)", old = { kind = "value", display = "x²+174*x+7569" } },
  { source = "a88 = 88\
a88^2 + 1", old = { kind = "value", display = "7745" } },
  { source = "a89 = 89\
a89^2 + 1", old = { kind = "value", display = "7922" } },
  { source = "plot(sin(x) + 90, x^2 / 90)", old = { kind = "graph", n = 2, lo = nil, hi = nil } },
  { source = "a91 = 91\
a91^2 + 1", old = { kind = "value", display = "8282" } },
  { source = "a92 = 92\
a92^2 + 1", old = { kind = "value", display = "8465" } },
  { source = "f93(x) = x^2 + 93*x\
expand((x+93)^2)", old = { kind = "value", display = "x²+186*x+8649" } },
  { source = "a94 = 94\
a94^2 + 1", old = { kind = "value", display = "8837" } },
  { source = "a95 = 95\
a95^2 + 1", old = { kind = "value", display = "9026" } },
  { source = "f96(x) = x^2 + 96*x\
expand((x+96)^2)", old = { kind = "value", display = "x²+192*x+9216" } },
  { source = "a97 = 97\
a97^2 + 1", old = { kind = "value", display = "9410" } },
  { source = "a98 = 98\
a98^2 + 1", old = { kind = "value", display = "9605" } },
  { source = "f99(x) = x^2 + 99*x\
expand((x+99)^2)", old = { kind = "value", display = "x²+198*x+9801" } },
  { source = "plot(sin(x) + 100, x^2 / 100)", old = { kind = "graph", n = 2, lo = nil, hi = nil } },
}
