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

-- `on_change(self)` is called after every change of the text or the cursor,
-- from any source (virtual keyboard, hardware keys, a tap in the text). The
-- InputText methods call each other, so only the outermost call notifies.
local OBSERVED = {
    "addChars", "delChar", "delNextChar", "delToStartOfLine", "delAll", "leftChar",
    "rightChar", "upLine", "downLine", "goToStartOfLine", "goToEndOfLine", "goToHome",
    "goToEnd", "moveCursorToCharPos", "setText", "resyncPos",
}

function CellEditor:notify_change()
    if self.on_change and (self.change_depth or 0) == 0 then
        self.on_change(self)
    end
end

for _, name in ipairs(OBSERVED) do
    local original = InputText[name]
    CellEditor[name] = function(self, ...)
        self.change_depth = (self.change_depth or 0) + 1
        local ok, err = pcall(original, self, ...)
        self.change_depth = self.change_depth - 1
        if not ok then
            error(err, 0)
        end
        self:notify_change()
    end
end

-- InputText handles Press, Tab and Back itself, and a focused editor sees key
-- presses before its parent. `key_filter(key)` lets the notebook (the
-- suggestion strip) take a key first; returning true consumes it.
function CellEditor:onKeyPress(key)
    if self.key_filter and self.key_filter(key) then
        return true
    end
    return InputText.onKeyPress(self, key)
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

-- Text and cursor position (1-based character position) for the completion session.
function CellEditor:cursor()
    return self:getText(), self.charpos
end

-- Applies an edit from `calcnb.completion` (contracts/strip-ui.md, "Accepting"):
-- replaces the characters `edit.first..edit.last` with the new text and puts
-- the cursor at `edit.charpos`. `on_change` fires once, at the end.
function CellEditor:replace_word(edit)
    self.selected_all = false
    local count = edit.last - edit.first + 1
    local before = self:getText()
    self.change_depth = (self.change_depth or 0) + 1
    local ok, err = pcall(function()
        self:moveCursorToCharPos(edit.last + 1)
        for _ = 1, count do
            self:delChar()
        end
        self:addChars(edit.insert)
        self:moveCursorToCharPos(edit.charpos)
    end)
    self.change_depth = self.change_depth - 1
    if not ok then
        self:setText(before, true)
        error(err, 0)
    end
    self:notify_change()
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
