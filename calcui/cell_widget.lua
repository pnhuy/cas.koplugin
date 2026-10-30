-- One notebook cell: header (input label, status, Run, menu), source (live
-- editor when active, static text otherwise) and output. Built fresh whenever
-- the page is rebuilt; typing does not rebuild it.

local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CellEditor = require("calcui.cell_editor")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local cell_status = require("calcui.cell_status")
local guard = require("calcui.guard")
local _ = require("gettext")

local Screen = Device.screen

-- A tappable wrapper around any widget.
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

local CellWidget = VerticalGroup:extend{
    cell = nil,
    width = nil,
    active = false, -- show the editor
    editing = false, -- show the Editing status (same as active today)
    view = nil, -- { on_edit, on_run, on_menu, on_expand } callbacks taking the cell id
    editor_h = nil,
}

local function output_text(cell)
    local out = cell.output
    if not out or out.empty then
        return nil
    end
    local text = out.display
    if out.kind == "error" then
        local line = out.error and out.error.line
        text = "✕ " .. text .. (line and (" (" .. _("line") .. " " .. line .. ")") or "")
    end
    if cell_status.is_out_of_date(cell) then
        text = "(" .. _("out of date") .. ") " .. text
    end
    return text
end

function CellWidget:init()
    local cell, view, width = self.cell, self.view, self.width
    local pad = Screen:scaleBySize(8)
    local inner = width - 2 * pad
    local face = Font:getFace("cfont", 20)
    local status = cell_status.describe(cell.status, self.editing)

    local header = ButtonTable:new{
        width = inner,
        sep_width = 0,
        show_parent = self.show_parent,
        buttons = {{
            {
                text = cell_status.input_label(cell) .. "  " .. status.symbol .. " " .. _(status.label),
                align = "left",
                callback = guard.wrap(function() view.on_edit(cell.id) end),
            },
            { text = _("Run"), width = Screen:scaleBySize(80), callback = guard.wrap(function() view.on_run(cell.id) end) },
            { text = "⋯", width = Screen:scaleBySize(60), callback = guard.wrap(function() view.on_menu(cell.id) end) },
        }},
    }

    local source
    if self.active then
        local function new_editor(w)
            return CellEditor:new{
                text = cell.source,
                width = w,
                height = self.editor_h,
                scroll = true,
                parent = self.show_parent,
                face = face,
            }
        end
        -- InputText adds its own border and padding; shrink so it fits the cell
        local editor = new_editor(inner)
        local extra = editor:getSize().w - inner
        if extra > 0 then
            editor = new_editor(inner - extra)
        end
        self.editor = editor
        source = editor
    else
        local text = cell.source ~= "" and cell.source or _("(empty cell)")
        source = TapArea:new{
            callback = guard.wrap(function() view.on_edit(cell.id) end),
            FrameContainer:new{
                bordersize = 0,
                padding = 0,
                TextBoxWidget:new{ text = text, face = face, width = inner,
                    fgcolor = cell.source ~= "" and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_DARK_GRAY },
            },
        }
    end

    local group = { width = width, align = "left" }
    group[#group + 1] = VerticalSpan:new{ width = Screen:scaleBySize(4) }
    group[#group + 1] = FrameContainer:new{ bordersize = 0, padding = 0, padding_left = pad, header }
    group[#group + 1] = FrameContainer:new{ bordersize = 0, padding = 0, padding_left = pad, source }

    local text = output_text(cell)
    if text then
        group[#group + 1] = VerticalSpan:new{ width = Screen:scaleBySize(6) }
        group[#group + 1] = FrameContainer:new{
            bordersize = 0, padding = 0, padding_left = pad,
            TextBoxWidget:new{ text = "Out: " .. text, face = face, width = inner },
        }
        if cell.output.truncated then
            group[#group + 1] = FrameContainer:new{
                bordersize = 0, padding = 0, padding_left = pad,
                ButtonTable:new{
                    width = Screen:scaleBySize(140), sep_width = 0, show_parent = self.show_parent,
                    buttons = {{ { text = _("Expand"), callback = guard.wrap(function() view.on_expand(cell.id) end) } }},
                },
            }
        end
    end
    group[#group + 1] = VerticalSpan:new{ width = Screen:scaleBySize(6) }
    group[#group + 1] = LineWidget:new{
        dimen = Geom:new{ w = width, h = Screen:scaleBySize(1) },
        background = Blitbuffer.COLOR_GRAY,
    }
    for i, w in ipairs(group) do
        self[i] = w
    end
    self.align = "left"
end

return CellWidget
