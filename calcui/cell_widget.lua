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
local LineWidget = require("ui/widget/linewidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local GraphOutput = require("calcui.graph_output")
local TapArea = require("calcui.tap_area")
local cell_status = require("calcui.cell_status")
local guard = require("calcui.guard")
local _ = require("gettext")

local Screen = Device.screen

-- cell_status is pure and holds the English labels; listing them here lets the
-- gettext extractor see each one.
local STATUS_LABELS = {
    Idle = _("Idle"), Editing = _("Editing"), Running = _("Running"),
    Done = _("Done"), Error = _("Error"), Stale = _("Stale"),
}

local CellWidget = VerticalGroup:extend{
    cell = nil,
    width = nil,
    active = false, -- show the editor
    editing = false, -- show the Editing status (same as active today)
    view = nil, -- { on_edit, on_run, on_menu, on_expand, on_graph } callbacks taking the cell id
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

    -- a note has no run, status or output: just a label and the menu
    local is_note = cell.type == "text"
    local row = {
        {
            text = is_note and _("Note") or (cell_status.input_label(cell) .. "  " .. status.symbol .. " " .. (STATUS_LABELS[status.label] or status.label)),
            align = "left",
            callback = guard.wrap(function() view.on_edit(cell.id) end),
        },
    }
    if not is_note then
        row[#row + 1] = { text = _("Run"), width = Screen:scaleBySize(80), callback = guard.wrap(function() view.on_run(cell.id) end) }
    end
    row[#row + 1] = { text = "⋯", width = Screen:scaleBySize(60), callback = guard.wrap(function() view.on_menu(cell.id) end) }
    local header = ButtonTable:new{
        width = inner,
        sep_width = 0,
        show_parent = self.show_parent,
        buttons = { row },
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
        local text = cell.source ~= "" and cell.source or (is_note and _("(empty note)") or _("(empty cell)"))
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

    local text = not is_note and output_text(cell) or nil
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
    local out = cell.output
    if out and out.kind == "graph" then
        self.graph = GraphOutput:new{
            cell = cell, width = inner, show_parent = self.show_parent, on_open = view.on_graph,
        }
        group[#group + 1] = VerticalSpan:new{ width = Screen:scaleBySize(4) }
        group[#group + 1] = FrameContainer:new{ bordersize = 0, padding = 0, padding_left = pad, self.graph }
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

-- Starts background work (inline plot) once the widget is known to be shown.
function CellWidget:start()
    if self.graph then
        self.graph:start()
    end
end

-- Stops that work and frees buffers; call when the widget is discarded.
function CellWidget:release()
    if self.graph then
        self.graph:release()
    end
end

return CellWidget
