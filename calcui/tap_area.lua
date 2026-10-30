-- A tappable wrapper around any widget.

local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")

local TapArea = InputContainer:extend{ callback = nil }

function TapArea:init()
    self.dimen = Geom:new{ w = self[1]:getSize().w, h = self[1]:getSize().h }
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = function() return self.dimen end } },
    }
end

function TapArea:onTap()
    if self.callback then
        self.callback()
    end
    return true
end

return TapArea
