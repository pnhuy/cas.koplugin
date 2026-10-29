-- Spec helper: renders an AST as a compact s-expression so tests can assert on
-- readable strings instead of nested tables.

local M = {}

local function sexp(node)
    local t = node.t
    if t == "num" then
        if node.approx then
            return "~" .. tostring(node.v)
        end
        if node.d == 1 then
            return string.format("%d", node.n)
        end
        return string.format("%d/%d", node.n, node.d)
    elseif t == "const" or t == "var" then
        return node.name
    elseif t == "pow" then
        return "(^ " .. sexp(node.base) .. " " .. sexp(node.exp) .. ")"
    elseif t == "fn" then
        return "(" .. node.name .. " " .. sexp(node.arg) .. ")"
    end
    local parts = {}
    for _, a in ipairs(node.args) do
        parts[#parts + 1] = sexp(a)
    end
    return "(" .. (t == "add" and "+" or "*") .. " " .. table.concat(parts, " ") .. ")"
end

M.sexp = sexp

return M
