-- Inline graph under a plot cell: a small canvas, the visible range, an Expand
-- button. The plot job is stepped from ticks; finished pictures are cached per
-- cell (keyed like the full-screen view) so rebuilding the page does not
-- replot, and the canvas buffer is freed as soon as the cell leaves the page.

local ButtonTable = require("ui/widget/buttontable")
local Device = require("device")
local Font = require("ui/font")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local calcplot = require("calcplot")
local GraphCanvas = require("calcui.graph_canvas")
local TapArea = require("calcui.tap_area")
local guard = require("calcui.guard")
local logger = require("logger")
local model = require("calcui.graph_model")
local _ = require("gettext")

local Screen = Device.screen

local STEP_BUDGET = 0.05 -- seconds of plotting per tick
local ASPECT = 0.55 -- canvas height / width
local MAX_PICTURES = 8

local pictures, picture_count = {}, 0 -- cell id -> { key, vp, curves, failed }

local GraphOutput = VerticalGroup:extend{
    cell = nil,
    width = nil,
    show_parent = nil, -- the top-level widget to repaint
    on_open = nil, -- called with the cell id
}

function GraphOutput.clear_cache()
    pictures, picture_count = {}, 0
end

local function remember(id, picture)
    if not pictures[id] then
        if picture_count >= MAX_PICTURES then
            GraphOutput.clear_cache()
        end
        picture_count = picture_count + 1
    end
    pictures[id] = picture
end

function GraphOutput:init()
    local cell, w = self.cell, self.width
    self.state = model.from_graph(cell.output.graph, cell.viewport)
    local h = math.floor(w * ASPECT)
    self.canvas = GraphCanvas:new{ width = w, height = h }
    self.info = TextWidget:new{ text = " ", face = Font:getFace("cfont", 14), max_width = w }
    local open = function()
        if self.on_open then
            self.on_open(cell.id)
        end
    end
    self.align = "left"
    self[1] = TapArea:new{ callback = guard.wrap(open), self.canvas }
    self[2] = self.info
    self[3] = ButtonTable:new{
        width = Screen:scaleBySize(140), sep_width = 0, show_parent = self.show_parent,
        buttons = {{ { text = _("Expand"), callback = guard.wrap(open) } }},
    }
    self._tick = guard.wrap(function() self:_step() end)
end

local function range_text(vp)
    return string.format("x %g..%g   y %g..%g", vp.xmin, vp.xmax, vp.ymin, vp.ymax)
end

function GraphOutput:_show(picture)
    self.canvas:setPicture(picture.vp, picture.curves, self.state.grid, self.state.axes)
    local text = range_text(picture.vp)
    if picture.failed > 0 then
        text = string.format(_("%d function(s) could not be plotted"), picture.failed) .. "   " .. text
    end
    self.info:setText(text)
end

-- Called once the widget is on the page (widgets built only to measure
-- their height must not start work).
function GraphOutput:start()
    local w, h = self.canvas.width, self.canvas.height
    self.key = model.cache_key(self.state, w, h)
    local cached = pictures[self.cell.id]
    if cached and cached.key == self.key then
        self:_show(cached)
        return
    end
    local functions, failed = model.plot_functions(self.state)
    self.failed = failed
    self.job = calcplot.new(functions, self.state.viewport, w, h)
    self.info:setText(_("Plotting…"))
    UIManager:nextTick(self._tick)
end

function GraphOutput:_step()
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
        logger.warn("calculator: inline plot failed:", job.err)
        self.info:setText(_("Plot failed"))
    else
        local picture = { key = self.key, vp = job:viewport(), curves = job:result(), failed = self.failed }
        remember(self.cell.id, picture)
        self:_show(picture)
    end
    -- the info line below the canvas changed too, so repaint the whole host
    UIManager:setDirty(self.show_parent or "all", "ui")
end

-- Cancels the plot and frees the canvas buffer.
function GraphOutput:release()
    UIManager:unschedule(self._tick)
    if self.job then
        self.job:cancel()
        self.job = nil
    end
    self.canvas:free()
end

return GraphOutput
