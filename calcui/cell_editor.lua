-- Multiline cell editor: KOReader's InputText with its own on-screen keyboard
-- replaced by a stub, so the notebook keyboard (calcui/keyboard.lua) can drive
-- it through addChars/delChar/leftChar/... See research.md R2 for the list of
-- `self.keyboard` uses in InputText that the stub has to answer.

local Geom = require("ui/geometry")
local InputText = require("ui/widget/inputtext")

local function new_stub()
    return {
        dimen = Geom:new{ w = 0, h = 0 },
        visible = false,
        isVisible = function(self) return self.visible end,
        showKeyboard = function(self) self.visible = true end,
        hideKeyboard = function(self) self.visible = false end,
        lockVisibility = function() end,
        free = function() end,
    }
end

local CellEditor = InputText:extend{
    scroll = false,
    focused = true,
}

-- InputText:onTapTextBox calls parent:getFocusableWidgetXY() on devices with a
-- D-pad (the emulator is one); a plain container does not have it and the tap
-- would crash KOReader. We have no focus grid, so the parent answers "none".
function CellEditor:init()
    local parent = self.parent
    if parent and not parent.getFocusableWidgetXY then
        parent.getFocusableWidgetXY = function() return nil end
    end
    InputText.init(self)
end

-- Overrides InputText:initKeyboard, which would build a VirtualKeyboard.
function CellEditor:initKeyboard()
    self.key_events = {}
    self.keyboard = new_stub()
end

-- Selection is whole-cell only: "All" marks the text, and the next typed
-- character, Backspace, Cut or Paste acts on all of it; any other key clears
-- the mark. Copy/Cut use KOReader's clipboard.

function CellEditor:select_all()
    self.selected_all = #self.charlist > 0
end

function CellEditor:clear_selection()
    self.selected_all = false
end

local function take_selection(self)
    if self.selected_all then
        self.selected_all = false
        self:delAll()
        return true
    end
    return false
end

-- Types `text` at the cursor, replacing a whole-cell selection.
function CellEditor:type_text(text)
    take_selection(self)
    self:addChars(text)
end

-- Inserts a shortcut such as "sin()" and steps back so the cursor sits inside
-- the brackets.
function CellEditor:insert_shortcut(text, back)
    self:type_text(text)
    for _ = 1, back or 0 do
        self:leftChar()
    end
end

function CellEditor:backspace()
    if not take_selection(self) then
        self:delChar()
    end
end

function CellEditor:delete_forward()
    if not take_selection(self) then
        self:delNextChar()
    end
end

-- Moves the cursor and drops any whole-cell selection.
function CellEditor:move(name)
    self.selected_all = false
    local methods = {
        left = "leftChar", right = "rightChar", up = "upLine", down = "downLine",
        home = "goToStartOfLine", ["end"] = "goToEndOfLine",
    }
    self[methods[name]](self)
end

function CellEditor:copy()
    local Device = require("device")
    if not Device:hasClipboard() then
        return false
    end
    local text = self:getText()
    if text == "" then
        return false
    end
    Device.input.setClipboardText(text)
    return true
end

function CellEditor:cut()
    if self:copy() then
        self.selected_all = false
        self:delAll()
        return true
    end
    return false
end

function CellEditor:paste()
    local Device = require("device")
    if not Device:hasClipboard() then
        return false
    end
    local text = Device.input.getClipboardText()
    if not text or text == "" then
        return false
    end
    self:type_text((text:gsub("\r\n?", "\n")))
    return true
end

return CellEditor
