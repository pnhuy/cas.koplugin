-- Full-screen Graph view: title bar, canvas, status line and button rows.
-- Plotting runs as a resumable job stepped from UIManager ticks so the UI
-- stays responsive; the picture is cached by model.cache_key.

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local ButtonTable = require("ui/widget/buttontable")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local logger = require("logger")
local calcplot = require("calcplot")
local FunctionList = require("calcui.function_list")
local GraphCanvas = require("calcui.graph_canvas")
local guard = require("calcui.guard")
local model = require("calcui.graph_model")
local outcome = require("calcui.outcome")
local settings = require("calcui.settings")
local viewport = require("calcplot.viewport")
local _ = require("gettext")

local Screen = Device.screen

local unpack = table.unpack or unpack -- luacheck: ignore 143

local STEP_BUDGET = 0.05 -- seconds of plotting per tick

local GraphView = InputContainer:extend{
    name = "calculator_graph",
    state = nil, -- graph session state (calcui.graph_model)
    on_calculator = nil, -- called after closing, to return to the Calculator view
    notebook = false, -- opened from a notebook cell: no function list, global settings untouched
    on_close = nil, -- called with the state when the view closes
}

local ZOOM_IN, ZOOM_OUT, PAN = 0.5, 2, 0.25

function GraphView:init()
    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end
    self._tick = guard.wrap(function()
        self:_step()
    end)
    self:_build()
    self:_replot()
end

function GraphView:_build()
    local w, h = Screen:getWidth(), Screen:getHeight()
    local pad = Size.padding.small
    self.dimen = Geom:new{ x = 0, y = 0, w = w, h = h }
    self.title_bar = TitleBar:new{
        width = w,
        title = _("Graph"),
        with_bottom_line = true,
        close_callback = function()
            self:onClose()
        end,
        show_parent = self,
    }
    local function action(fn, ...)
        local args = { ... }
        return guard.wrap(function() fn(self, unpack(args)) end)
    end
    local buttons = {
        {
            { text = _("Zoom +"), callback = action(self._zoom, ZOOM_IN) },
            { text = _("Zoom -"), callback = action(self._zoom, ZOOM_OUT) },
            { text = "1:1", callback = action(self._equal) },
            { text = _("Reset"), callback = action(self._reset) },
        },
        {
            { text = "←", callback = action(self._pan, -PAN, 0) },
            { text = "↑", callback = action(self._pan, 0, PAN) },
            { text = "↓", callback = action(self._pan, 0, -PAN) },
            { text = "→", callback = action(self._pan, PAN, 0) },
        },
        {
            { text = _("Range"), callback = action(self._range) },
            { text = self.state.grid and _("Grid: on") or _("Grid: off"), callback = action(self._toggle, "grid") },
            { text = self.state.axes ~= false and _("Axes: on") or _("Axes: off"), callback = action(self._toggle, "axes") },
        },
    }
    if not self.notebook then
        buttons[#buttons + 1] = {
            { text = _("Functions"), callback = action(self._functions) },
            { text = _("Calculator"), callback = action(self._calculator) },
            { text = _("Close"), callback = function() self:onClose() end },
        }
    end
    self.button_table = ButtonTable:new{ width = w, show_parent = self, buttons = buttons }
    self.status = TextWidget:new{
        text = " ",
        face = Font:getFace("cfont", 16),
        max_width = w - 2 * pad,
    }
    self.legend = TextWidget:new{
        text = " ",
        face = Font:getFace("cfont", 14),
        max_width = w - 2 * pad,
    }
    local status_h = self.status:getSize().h
    local legend_h = self.legend:getSize().h
    local title_h = self.title_bar:getSize().h
    local canvas_h = h - title_h - self.button_table:getSize().h - status_h - legend_h - 4 * pad
    self.canvas = GraphCanvas:new{ width = w - 2 * pad, height = canvas_h }
    self.canvas_region = Geom:new{ x = pad, y = title_h + pad, w = self.canvas.width, h = canvas_h }
    self.status_region = Geom:new{ x = 0, y = title_h + 2 * pad + canvas_h, w = w, h = status_h }
    self.legend_region = Geom:new{ x = 0, y = title_h + 3 * pad + canvas_h + status_h, w = w, h = legend_h }
    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        margin = 0,
        VerticalGroup:new{
            align = "center",
            self.title_bar,
            VerticalSpan:new{ width = pad },
            self.canvas,
            VerticalSpan:new{ width = pad },
            self.status,
            VerticalSpan:new{ width = pad },
            self.legend,
            self.button_table,
        },
    }
end

function GraphView:_set_status(text)
    self.status:setText(text)
    UIManager:setDirty(self, "ui", self.status_region)
end

local function legend_text(state)
    local parts = {}
    for _, row in ipairs(model.legend(state)) do
        parts[#parts + 1] = row.label .. " (" .. row.style .. ")"
    end
    return table.concat(parts, ",  ")
end

function GraphView:_set_legend()
    self.legend:setText(legend_text(self.state))
    UIManager:setDirty(self, "ui", self.legend_region)
end

function GraphView:_cancel_job()
    UIManager:unschedule(self._tick)
    if self.job then
        self.job:cancel()
        self.job = nil
    end
end

-- Recompute the picture unless the cache key says it is already on screen.
function GraphView:_replot()
    local w, h = self.canvas.width, self.canvas.height
    local key = model.cache_key(self.state, w, h)
    if key == self._key and self._ready then
        return
    end
    self:_cancel_job()
    self._key, self._ready = key, false
    local functions, failed = model.plot_functions(self.state)
    self._failed = failed
    self.job = calcplot.new(functions, self.state.viewport, w, h)
    self:_set_status(_("Plotting…"))
    self:_set_legend()
    UIManager:nextTick(self._tick)
end

function GraphView:_step()
    local job = self.job
    if not job then
        return
    end
    if not job:step(STEP_BUDGET) then
        UIManager:nextTick(self._tick)
        return
    end
    self.job = nil
    if job.err then
        logger.warn("calculator: plot job failed:", job.err)
        self:_set_status(_("Plot failed"))
        return
    end
    local used = job:viewport()
    self._used = used
    self.canvas:setPicture(used, job:result(), self.state.grid, self.state.axes)
    self._ready = true
    UIManager:setDirty(self, "ui", self.canvas_region)
    self:_set_status(self:_summary(used))
end

function GraphView:_summary(vp)
    local text = string.format("x %g..%g   y %g..%g", vp.xmin, vp.xmax, vp.ymin, vp.ymax)
    if self._failed > 0 then
        text = string.format(_("%d function(s) could not be plotted"), self._failed) .. "   " .. text
    end
    return text
end

function GraphView:_functions()
    FunctionList.show(self.state, function()
        self:_replot()
    end)
end

-- The classic view remembers its viewport across sessions; a notebook cell
-- gets it back through on_close.
function GraphView:_save()
    if not self.notebook then
        settings.save(self.state.viewport, self.state.grid)
    end
end

function GraphView:_reset()
    self.state.viewport = viewport.copy(self.state.home or viewport.default())
    self:_save()
    self:_replot()
end

-- Applies a viewport.zoom/pan/equal_scale-style change to what is on screen
-- (the plotted range, so auto Y is already resolved). Invalid results are
-- reported and leave the view as it was.
function GraphView:_apply(change, ...)
    local current = self.state.viewport
    local base = viewport.copy(self._used or current)
    base.auto_y = current.auto_y
    local new, err = change(base, ...)
    if not new then
        self:_set_status(outcome.describe("", err, _))
        return
    end
    self.state.viewport = new
    self:_save()
    self:_replot()
end

function GraphView:_zoom(factor)
    self:_apply(viewport.zoom, factor)
end

function GraphView:_pan(fx, fy)
    self:_apply(viewport.pan, fx, fy)
end

function GraphView:_equal()
    self:_apply(viewport.equal_scale, self.canvas.width, self.canvas.height)
end

-- key: "grid" or "axes". The buttons show the state, so rebuild them.
function GraphView:_toggle(key)
    self.state[key] = self.state[key] == false
    self:_save()
    self:_rebuild()
end

function GraphView:_rebuild()
    self:_cancel_job()
    self.canvas:free()
    self._ready = false
    self:_build()
    self:_replot()
    UIManager:setDirty(self, "ui")
end

local function field_text(v)
    return string.format("%.12g", v)
end

-- pending: { texts = {...}, auto_y =, grid = } keeps edits across toggles.
function GraphView:_range(pending)
    local vp = self.state.viewport
    pending = pending or {
        texts = { field_text(vp.xmin), field_text(vp.xmax), field_text(vp.ymin), field_text(vp.ymax) },
        auto_y = vp.auto_y,
        grid = self.state.grid,
    }
    local dialog
    local function remember()
        pending.texts = dialog:getFields()
    end
    local labels = { "Xmin", "Xmax", "Ymin", "Ymax" }
    local fields = {}
    for i, label in ipairs(labels) do
        fields[i] = { description = label, text = pending.texts[i], hint = label }
    end
    dialog = MultiInputDialog:new{
        title = _("Range"),
        fields = fields,
        buttons = {
            {
                {
                    text = pending.auto_y and _("Auto-Y: on") or _("Auto-Y: off"),
                    callback = function()
                        remember()
                        pending.auto_y = not pending.auto_y
                        UIManager:close(dialog)
                        self:_range(pending)
                    end,
                },
                {
                    text = pending.grid and _("Grid: on") or _("Grid: off"),
                    callback = function()
                        remember()
                        pending.grid = not pending.grid
                        UIManager:close(dialog)
                        self:_range(pending)
                    end,
                },
            },
            {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = _("Apply"),
                    is_enter_default = true,
                    callback = function()
                        remember()
                        local new_vp, err = model.parse_range(pending.texts, pending.auto_y)
                        if not new_vp then
                            UIManager:show(InfoMessage:new{ text = outcome.describe("", err, _) })
                            return
                        end
                        UIManager:close(dialog)
                        self.state.viewport = new_vp
                        self.state.grid = pending.grid
                        self:_save()
                        self:_rebuild()
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function GraphView:_calculator()
    local back = self.on_calculator
    UIManager:close(self)
    if back then
        back()
    end
end

-- Orientation or window size changed: relayout and redraw at the new size.
function GraphView:onScreenResize()
    self:_rebuild()
end

function GraphView:onClose()
    UIManager:close(self)
    return true
end

function GraphView:onCloseWidget()
    self:_save()
    self:_cancel_job()
    self.canvas:free()
    if self.on_close then
        self.on_close(self.state)
    end
end

local GraphViewModule = {}

-- state: calcui.graph_model state; on_calculator: optional return hook.
-- opts (optional): { on_close = fn(state) } opens the view for a notebook cell.
function GraphViewModule.show(state, on_calculator, opts)
    local view = GraphView:new{
        state = state,
        on_calculator = on_calculator,
        notebook = opts ~= nil,
        on_close = opts and opts.on_close,
    }
    UIManager:show(view)
    -- opened over the notebook: refresh the whole screen, not just the region its first paint marks
    UIManager:setDirty(view, "ui", Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() })
end

return GraphViewModule
