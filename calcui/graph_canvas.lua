-- Canvas widget: renders axes, grid, tick labels and curves into an off-screen
-- Blitbuffer once per picture and blits it on paint, so repainting the view
-- (status changes, dialogs closing) never re-rasterises the plot.

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local RenderText = require("ui/rendertext")
local Widget = require("ui/widget/widget")
local raster = require("calcplot.raster")
local ticks = require("calcplot.ticks")
local viewport = require("calcplot.viewport")

local Screen = Device.screen

local TARGET_TICKS = 6
local LABEL_GAP = 4

local GraphCanvas = Widget:extend{
    width = 0,
    height = 0,
    vp = nil,
    curves = nil,
    grid = true,
    axes = true, -- axis lines and tick labels
}

function GraphCanvas:init()
    self.dimen = Geom:new{ w = self.width, h = self.height }
    self.face = Font:getFace("cfont", 14)
    self.curves = self.curves or {}
end

-- vp is the viewport actually plotted (auto Y already applied).
function GraphCanvas:setPicture(vp, curves, grid, axes)
    self.vp, self.curves, self.grid, self.axes = vp, curves, grid, axes ~= false
    self:free()
end

function GraphCanvas:free()
    if self._buf then
        self._buf:free()
        self._buf = nil
    end
end

function GraphCanvas:_text_width(text)
    return RenderText:sizeUtf8Text(0, self.width, self.face, text, true, false).x
end

function GraphCanvas:_draw_grid_and_labels(buf)
    local vp, w, h = self.vp, self.width, self.height
    local xt = ticks.nice(vp.xmin, vp.xmax, TARGET_TICKS)
    local yt = ticks.nice(vp.ymin, vp.ymax, TARGET_TICKS)
    if self.grid then
        for _, x in ipairs(xt) do
            local px = viewport.to_screen(vp, w, h, x, 0)
            buf:paintRect(math.floor(px + 0.5), 0, 1, h, Blitbuffer.COLOR_LIGHT_GRAY)
        end
        for _, y in ipairs(yt) do
            local _, py = viewport.to_screen(vp, w, h, 0, y)
            buf:paintRect(0, math.floor(py + 0.5), w, 1, Blitbuffer.COLOR_LIGHT_GRAY)
        end
    end
    if not self.axes then
        return
    end
    if vp.ymin <= 0 and vp.ymax >= 0 then
        local _, py = viewport.to_screen(vp, w, h, 0, 0)
        buf:paintRect(0, math.floor(py + 0.5) - 1, w, 2, Blitbuffer.COLOR_BLACK)
    end
    if vp.xmin <= 0 and vp.xmax >= 0 then
        local px = viewport.to_screen(vp, w, h, 0, 0)
        buf:paintRect(math.floor(px + 0.5) - 1, 0, 2, h, Blitbuffer.COLOR_BLACK)
    end

    local text_h = self.face.size
    local baseline = h - LABEL_GAP
    local last_end = -math.huge
    for _, x in ipairs(xt) do
        local text = ticks.label(x, xt.step)
        local tw = self:_text_width(text)
        local px = viewport.to_screen(vp, w, h, x, 0)
        local left = math.max(2, math.min(px - tw / 2, w - tw - 2))
        if left > last_end + LABEL_GAP then
            RenderText:renderUtf8Text(buf, math.floor(left), baseline, self.face, text, true)
            last_end = left + tw
        end
    end
    for _, y in ipairs(yt) do
        local _, py = viewport.to_screen(vp, w, h, 0, y)
        local base = math.floor(py + text_h / 3)
        if base > text_h and base < h - text_h - LABEL_GAP then
            RenderText:renderUtf8Text(buf, LABEL_GAP, base, self.face, ticks.label(y, yt.step), true)
        end
    end
end

function GraphCanvas:_render()
    local buf = Blitbuffer.new(self.width, self.height, Screen.bb:getType())
    buf:fill(Blitbuffer.COLOR_WHITE)
    if self.vp then
        self:_draw_grid_and_labels(buf)
        local function paint(x, y, size)
            buf:paintRect(x, y, size, size, Blitbuffer.COLOR_BLACK)
        end
        for _, curve in ipairs(self.curves) do
            local style = raster.STYLES[curve.style] or raster.STYLES[1]
            for _, line in ipairs(curve.polylines) do
                raster.polyline(line, style, paint)
            end
        end
    end
    buf:paintBorder(0, 0, self.width, self.height, 1, Blitbuffer.COLOR_BLACK)
    self._buf = buf
end

function GraphCanvas:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    if not self._buf then
        self:_render()
    end
    bb:blitFrom(self._buf, x, y, 0, 0, self.width, self.height)
end

return GraphCanvas
