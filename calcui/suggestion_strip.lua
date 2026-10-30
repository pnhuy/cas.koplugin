-- Suggestion strip docked above the keyboard (contracts/strip-ui.md): a chip
-- row and, when there is room, a documentation row for the highlighted chip.
-- It has a fixed height, so it never moves the page, and repaints only its own
-- region. It draws what `calcnb.completion_session:model()` says and reports
-- taps; it keeps no completion state of its own.

local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local guard = require("calcui.guard")
local _ = require("gettext")

local Screen = Device.screen

-- calccas.builtin_docs holds the English texts; listing them here lets the
-- gettext extractor see each one. Signatures and examples are code, not translated.
local SUMMARIES = {
    sin = _("Sine of x, in radians."), cos = _("Cosine of x, in radians."),
    tan = _("Tangent of x, in radians."), sqrt = _("Square root of x."),
    plot = _("Plots expressions of x over a range."), abs = _("Absolute value of x."),
    exp = _("e raised to the power x."), log = _("Natural logarithm of x."),
    ln = _("Natural logarithm of x."), simplify = _("Simplifies an expression."),
    expand = _("Expands products and powers."), pi = _("The constant pi, 3.14159..."),
    e = _("Euler's number, 2.71828..."), factor = _("Factors an expression."),
    solve = _("Solves an equation for a symbol."), subs = _("Substitutes a value for a symbol."),
    approx = _("Gives a decimal approximation."), diff = _("Differentiates an expression."),
    integrate = _("Integrates an expression."),
}
local NOTES = {
    ln = _("Another name for log."),
    reserved = _("Reserved for a future version: running it gives the reserved message."),
}
local KINDS = {
    ["function"] = _("function"), command = _("command"), constant = _("constant"),
    var = _("variable"), func = _("user function"),
}
local NOT_AVAILABLE = _("not available yet")

local SuggestionStrip = FrameContainer:extend{
    width = nil,
    rows = 2, -- 2: chips and documentation, 1: chips only (from calcui.strip_sizing)
    line_h = nil, -- height of one row
    on_accept = nil, -- function() for a tap on the highlighted chip
    on_select = nil, -- function(index) for a tap on another chip
    on_dismiss = nil, -- function() for the ✕ button
    background = Blitbuffer.COLOR_WHITE,
    bordersize = 0,
    padding = 0,
    margin = 0,
}

function SuggestionStrip:init()
    self.dimen = Geom:new{ w = self.width, h = self.rows * self.line_h }
    self.model = nil
    self.shown_key = ""
    self:render()
end

-- What the strip draws for a model; equal keys need no repaint.
local function key_of(model)
    if not model then
        return ""
    end
    local names = {}
    for i, item in ipairs(model.items) do
        names[i] = item.name
    end
    return table.concat(names, ";") .. "|" .. model.highlight .. "|" .. model.more
end

local function chip_label(item)
    local label = item.insert:find("%(%)$") and (item.name .. "()") or item.name
    if not item.available then
        label = label .. "*" -- reserved: offered, not available yet
    end
    return label
end

-- The documentation line for an item: signature, summary and the first
-- example, cut to the row. A reserved command says it is not available yet.
local function doc_text(item)
    local doc = item.doc
    if not doc then
        local label = KINDS[item.kind] or item.kind
        if item.kind == "func" and item.params then
            return item.name .. "(" .. table.concat(item.params, ", ") .. ")  " .. label
        end
        return item.name .. "  " .. label
    end
    local parts = { doc.signature, SUMMARIES[item.name] or doc.summary }
    if not item.available then
        parts[#parts + 1] = NOT_AVAILABLE
    elseif doc.note and item.name == "ln" then
        parts[#parts + 1] = NOTES.ln
    end
    if doc.examples and doc.examples[1] then
        parts[#parts + 1] = _("e.g.") .. " " .. doc.examples[1]
    end
    return table.concat(parts, "  ")
end

local function chip_row(self, model)
    local font_size = math.max(12, math.floor(self.line_h * 0.4))
    local entries = {}
    if model then
        local chips = #model.items
        local fixed = Screen:scaleBySize(56) -- the ✕ button
        if model.more > 0 then
            fixed = fixed + Screen:scaleBySize(56)
        end
        local chip_w = math.floor((self.width - fixed) / math.max(chips, 1))
        for i, item in ipairs(model.items) do
            entries[#entries + 1] = {
                text = chip_label(item),
                width = chip_w,
                height = self.line_h,
                font_size = font_size,
                font_bold = i == model.highlight,
                background = i == model.highlight and Blitbuffer.COLOR_LIGHT_GRAY or Blitbuffer.COLOR_WHITE,
                callback = guard.wrap(function()
                    if i == model.highlight then
                        if self.on_accept then self.on_accept() end
                    elseif self.on_select then
                        self.on_select(i)
                    end
                end),
            }
        end
        if model.more > 0 then
            entries[#entries + 1] = {
                text = "+" .. model.more,
                width = Screen:scaleBySize(56),
                height = self.line_h,
                font_size = font_size,
                callback = function() end, -- informational only
            }
        end
        entries[#entries + 1] = {
            text = "✕",
            width = Screen:scaleBySize(56),
            height = self.line_h,
            font_size = font_size,
            callback = guard.wrap(function()
                if self.on_dismiss then self.on_dismiss() end
            end),
        }
    else
        entries[1] = { text = "", width = self.width, height = self.line_h, font_size = font_size, enabled = false, callback = function() end }
    end
    local row = ButtonTable:new{ width = self.width, sep_width = 0, buttons = { entries }, show_parent = self }
    -- Touch only: a ButtonTable is a FocusManager and would take Tab, Press and
    -- the arrows from the notebook's key handling (NotebookView:strip_key).
    row.key_events = {}
    return row
end

function SuggestionStrip:render()
    local model = self.model
    local group = VerticalGroup:new{ align = "left", chip_row(self, model) }
    if self.rows >= 2 then
        local text = ""
        if model then
            local item = model.items[model.highlight]
            text = item and doc_text(item) or ""
        end
        group[#group + 1] = TextWidget:new{
            text = text,
            face = Font:getFace("cfont", math.max(12, math.floor(self.line_h * 0.4))),
            max_width = self.width - Screen:scaleBySize(16),
            height = self.line_h,
        }
    end
    self[1] = group
end

-- Shows `model` (or nothing when nil). Repaints only the strip's region, and
-- only when what it draws changed (`quiet`: the caller repaints). Returns true
-- when it did.
function SuggestionStrip:set_model(model, quiet)
    local key = key_of(model)
    if key == self.shown_key then
        return false
    end
    self.shown_key = key
    self.model = model
    self:render()
    if not quiet then
        UIManager:setDirty(self, "ui", self.dimen)
    end
    return true
end

return SuggestionStrip
