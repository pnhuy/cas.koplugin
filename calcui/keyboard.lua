-- On-screen programming keyboard docked under the notebook (contracts/
-- keyboard-layout.md). It drives a CellEditor; key data comes from the pure
-- calcnb.keyboard_layout and calcnb.shortcuts modules.

local ButtonTable = require("ui/widget/buttontable")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local UIManager = require("ui/uimanager")
local guard = require("calcui.guard")
local keyboard_layout = require("calcnb.keyboard_layout")
local keyboard_sizing = require("calcui.keyboard_sizing")
local shortcuts = require("calcnb.shortcuts")

local Screen = Device.screen

local Keyboard = FrameContainer:extend{
    editor = nil, -- CellEditor to drive
    dirty_target = nil, -- widget to repaint after a page change (default: everything)
    bordersize = 0,
    padding = 0,
    margin = 0,
}

function Keyboard:init()
    self.page = "letters" -- letters | shift | symbols
    self.slide_index = 1
    self:relayout(Screen:getWidth(), Screen:getHeight())
end

-- Recomputes sizes and key sets; call again after a rotation or resize.
function Keyboard:relayout(screen_w, screen_h)
    self.screen_w = screen_w
    self.compact = keyboard_layout.is_compact(screen_w)
    self.pages = keyboard_layout.pages(self.compact)
    self.slides = shortcuts.slides(shortcuts.groups(), keyboard_layout.shortcut_slots(self.compact))
    self.slide_index = math.min(self.slide_index, math.max(1, #self.slides))
    -- the shortcut row plus the letter rows decide the height; the symbol page has as many
    self.sizing = keyboard_sizing.compute(screen_w, screen_h, #self.pages.letters + 1)
    self:rebuild()
end

-- Real height: ButtonTable adds a gap above every row on top of the key height.
function Keyboard:getHeight()
    return self[1]:getSize().h
end

local function after_char(self)
    -- one-shot Shift: back to lowercase after one character
    if self.page == "shift" then
        self.page = "letters"
        self:rebuild()
    end
end

function Keyboard:press(key)
    local editor = self.editor
    if key.insert then
        editor:type_text(key.insert)
        for _ = 1, key.back or 0 do
            editor:leftChar()
        end
        after_char(self)
        return
    end
    local action = key.action
    if action == "shift" then
        self.page = self.page == "shift" and "letters" or "shift"
        self:rebuild()
    elseif action == "sym" then
        self.page = self.page == "symbols" and "letters" or "symbols"
        self:rebuild()
    elseif action == "group" then
        self.slide_index = self.slide_index % #self.slides + 1
        self:rebuild()
    elseif action == "space" then
        editor:type_text(" ")
    elseif action == "enter" then
        editor:type_text("\n")
    elseif action == "backspace" then
        editor:backspace()
    elseif action == "delete" then
        editor:delete_forward()
    elseif action == "select_all" then
        editor:select_all()
    elseif action == "copy" then
        editor:copy()
    elseif action == "cut" then
        editor:cut()
    elseif action == "paste" then
        editor:paste()
    else
        editor:move(action) -- left right up down home end
    end
end

local function build(self, key_h)
    local rows = {}
    if self.page ~= "symbols" and #self.slides > 0 then
        rows[1] = keyboard_layout.shortcut_row(self.slides[self.slide_index])
    end
    for _, row in ipairs(self.pages[self.page]) do
        rows[#rows + 1] = row
    end

    local buttons = {}
    for r, row in ipairs(rows) do
        buttons[r] = {}
        for c, key in ipairs(row) do
            buttons[r][c] = {
                text = key.label,
                height = key_h,
                font_size = math.max(12, math.floor(key_h * 0.4)),
                callback = guard.wrap(function() self:press(key) end),
            }
        end
    end

    return ButtonTable:new{
        buttons = buttons,
        width = self.screen_w,
        sep_width = 0,
        show_parent = self,
    }, #rows
end

function Keyboard:rebuild()
    local key_h = self.sizing.key_h
    local table_widget, rows = build(self, key_h)
    local excess = table_widget:getSize().h - self.sizing.height
    if excess > 0 then
        -- shrink the keys by the gaps ButtonTable added, so the 55% cap holds
        key_h = math.max(1, key_h - math.ceil(excess / rows))
        table_widget = build(self, key_h)
    end
    self[1] = table_widget
    -- the keyboard is nested in the host, so ask for a repaint of the whole stack
    UIManager:setDirty(self.dirty_target or "all", "ui")
end

return Keyboard
