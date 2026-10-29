-- Runs a user-triggered action so an unexpected Lua error shows a message
-- instead of propagating into KOReader. Logs only the error text, never the
-- user's expression.

local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local _ = require("gettext")

local M = {}

-- Returns a function that calls fn(...) under pcall.
function M.wrap(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            logger.warn("calculator: internal error:", err)
            UIManager:show(InfoMessage:new{ text = _("Internal error") })
        end
    end
end

return M
