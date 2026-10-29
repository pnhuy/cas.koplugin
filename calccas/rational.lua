-- Exact rational arithmetic on doubles.
-- Numerators and denominators stay integers with |value| <= 2^53 - 1; any
-- operation that would exceed that returns `nil, "overflow"` rather than a
-- silently rounded result. Division by zero returns `nil, "div_by_zero"`.

local M = {}

local MAX = 9007199254740991 -- 2^53 - 1

local floor, abs, sqrt = math.floor, math.abs, math.sqrt

local function gcd(a, b)
    a, b = abs(a), abs(b)
    while b ~= 0 do
        a, b = b, a % b
    end
    return a
end

local function make(n, d)
    if d == 0 then
        return nil, "div_by_zero"
    end
    if abs(n) > MAX or abs(d) > MAX then
        return nil, "overflow"
    end
    if d < 0 then
        n, d = -n, -d
    end
    local g = gcd(n, d)
    if g > 1 then
        n, d = n / g, d / g
    end
    if n == 0 then
        d = 1
    end
    return { n = n, d = d }
end

M.new = make

function M.add(a, b)
    local g = gcd(a.d, b.d)
    local n = a.n * (b.d / g) + b.n * (a.d / g)
    local d = (a.d / g) * b.d
    return make(n, d)
end

function M.sub(a, b)
    return M.add(a, { n = -b.n, d = b.d })
end

function M.mul(a, b)
    return make(a.n * b.n, a.d * b.d)
end

function M.div(a, b)
    if b.n == 0 then
        return nil, "div_by_zero"
    end
    return make(a.n * b.d, a.d * b.n)
end

function M.pow_int(base, k)
    if k < 0 then
        local inv, kind = M.div({ n = 1, d = 1 }, base)
        if not inv then
            return nil, kind
        end
        base, k = inv, -k
    end
    local result = { n = 1, d = 1 }
    while k > 0 do
        if k % 2 == 1 then
            local r, kind = M.mul(result, base)
            if not r then
                return nil, kind
            end
            result = r
        end
        k = floor(k / 2)
        if k > 0 then
            local b, kind = M.mul(base, base)
            if not b then
                return nil, kind
            end
            base = b
        end
    end
    return result
end

-- "12", "0.25" and ".5" are accepted; anything else returns nil.
function M.from_decimal(text)
    local int_part, frac_part = text:match("^(%d*)%.?(%d*)$")
    if not int_part or (int_part == "" and frac_part == "") then
        return nil, "syntax"
    end
    local digits = (int_part .. frac_part):gsub("^0+", "")
    if #digits > 15 then
        return nil, "overflow"
    end
    local n = tonumber(int_part .. frac_part)
    return make(n, 10 ^ #frac_part)
end

function M.eq(a, b)
    return a.n == b.n and a.d == b.d
end

function M.lt(a, b)
    local l, r = a.n * b.d, b.n * a.d
    if abs(l) <= MAX and abs(r) <= MAX then
        return l < r
    end
    return a.n / a.d < b.n / b.d
end

function M.to_number(a)
    return a.n / a.d
end

function M.is_integer(a)
    return a.d == 1
end

local function int_sqrt(n)
    local s = floor(sqrt(n) + 0.5)
    if s * s == n then
        return s
    end
end

-- Exact root of a perfect-square rational; nil otherwise (including negatives).
function M.sqrt(a)
    if a.n < 0 then
        return nil
    end
    local sn, sd = int_sqrt(a.n), int_sqrt(a.d)
    if sn and sd then
        return make(sn, sd)
    end
end

return M
