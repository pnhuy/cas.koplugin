-- Which suggestion-strip action a physical key means (contracts/strip-ui.md,
-- "Keys"). Pure: the view maps the action to a call. `key` is KOReader's key
-- table (`key["Press"]`, ...). Returns "accept", "dismiss", "next", "prev" or nil.

local M = {}

function M.action(key, strip_shown)
    if not strip_shown or type(key) ~= "table" then
        return nil
    end
    if key["Press"] or key["Tab"] then
        return "accept"
    elseif key["Back"] then
        return "dismiss"
    elseif key["RPgFwd"] or key["LPgFwd"] then
        return "next"
    elseif key["RPgBack"] or key["LPgBack"] then
        return "prev"
    end
    return nil
end

return M
