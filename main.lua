local CalculatorView = require("calcui.calculator_view")
local GraphView = require("calcui.graph_view")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local graph_model = require("calcui.graph_model")
local guard = require("calcui.guard")
local settings = require("calcui.settings")
local _ = require("gettext")

local Calculator = WidgetContainer:extend{
    name = "calculator",
    is_doc_only = false,
}

-- Kept for the life of the KOReader process so the expression, variables and
-- function list survive closing and reopening the views.
local session = { expr = "", vars = "", result = nil }
local graph

-- The viewport and grid are the only state that also persists across restarts;
-- they are read lazily the first time the Graph view is needed.
local function graph_state()
    if not graph then
        graph = graph_model.new_state()
        local saved = settings.load()
        graph.viewport, graph.grid = saved.viewport, saved.grid
    end
    return graph
end

local handlers = {
    graph = guard.wrap(function(_state, back)
        GraphView.show(graph_state(), back)
    end),
}

local showCalculator = guard.wrap(function()
    CalculatorView.show(session, handlers)
end)

function Calculator:init()
    self.ui.menu:registerToMainMenu(self)
end

function Calculator:addToMainMenu(menu_items)
    menu_items.calculator = {
        text = _("Calculator"),
        sorting_hint = "tools",
        callback = showCalculator,
    }
end

return Calculator
