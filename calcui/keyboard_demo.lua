-- TEMPORARY (T025): hosts the keyboard and a CellEditor full-screen so Phase 3
-- can be checked in the emulator. Removed before US1 is accepted.

local ButtonTable = require("ui/widget/buttontable")
local CellEditor = require("calcui.cell_editor")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local Keyboard = require("calcui.keyboard")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local Blitbuffer = require("ffi/blitbuffer")

local Screen = Device.screen

local Demo = InputContainer:extend{}

function Demo:init()
    local w, h = Screen:getWidth(), Screen:getHeight()
    self.dimen = Geom:new{ w = w, h = h }
    self.keyboard = Keyboard:new{ dirty_target = self }
    local top = ButtonTable:new{
        buttons = {{ { text = "Close", callback = function() UIManager:close(self) end } }},
        width = w,
        show_parent = self,
    }
    local editor_h = h - self.keyboard:getHeight() - top:getSize().h
    self.editor = CellEditor:new{
        text = "",
        width = w - 40, -- InputText adds its own border and padding
        height = editor_h - 40,
        scroll = true,
        parent = self,
    }
    self.keyboard.editor = self.editor
    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        width = w,
        height = h,
        VerticalGroup:new{
            top,
            FrameContainer:new{ bordersize = 0, padding = 10, self.editor },
            self.keyboard,
        },
    }
end

function Demo.show()
    UIManager:show(Demo:new{})
end

return Demo
