-- Calculator dialog built on InputDialog. `state` is session data owned by the
-- caller: { expr = "", vars = "", result = nil }. `handlers.graph(state, back)`
-- is optional; it runs after this dialog closes and calls `back()` to return.
-- When missing the Graph button shows "coming soon".

local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local guard = require("calcui.guard")
local outcome = require("calcui.outcome")
local _ = require("gettext")

local CalculatorView = {}

local KEYPAD = { "^", "(", ")", "/", "sqrt(", "pi" }

local function open(state, handlers)
    local dialog

    local function remember()
        state.expr = dialog:getInputText()
    end

    local function reopen()
        remember()
        UIManager:close(dialog)
        open(state, handlers)
    end

    local function keypad_row()
        local row = {}
        for _, key in ipairs(KEYPAD) do
            table.insert(row, {
                text = key,
                callback = function()
                    dialog:addTextToInput(key)
                end,
            })
        end
        table.insert(row, {
            text = "⌫",
            callback = function()
                dialog._input_widget:delChar()
            end,
        })
        return row
    end

    local function optional_action(handler)
        return function()
            if handler then
                remember()
                UIManager:close(dialog)
                handler(state, function()
                    open(state, handlers)
                end)
            else
                UIManager:show(InfoMessage:new{ text = _("Coming soon") })
            end
        end
    end

    local function edit_variables()
        remember()
        local vars_dialog
        vars_dialog = InputDialog:new{
            title = _("Variables (x=2, y=1/2)"),
            input = state.vars,
            buttons = {{
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(vars_dialog)
                    end,
                },
                {
                    text = _("Set"),
                    is_enter_default = true,
                    callback = function()
                        state.vars = vars_dialog:getInputText()
                        UIManager:close(vars_dialog)
                        UIManager:close(dialog)
                        open(state, handlers)
                    end,
                },
            }},
        }
        UIManager:show(vars_dialog)
        vars_dialog:onShowKeyboard()
    end

    dialog = InputDialog:new{
        title = _("Calculator"),
        input = state.expr,
        input_hint = _("Expression, e.g. 1/3+1/6"),
        description = state.result,
        allow_newline = false,
        buttons = {
            keypad_row(),
            {
                {
                    text = _("Evaluate"),
                    is_enter_default = true,
                    callback = guard.wrap(function()
                        remember()
                        state.result = outcome.evaluate(state.expr, state.vars, _).text
                        reopen()
                    end),
                },
                { text = _("Variables"), callback = edit_variables },
            },
            {
                {
                    text = _("Simplify"),
                    callback = guard.wrap(function()
                        remember()
                        state.result = outcome.simplify(state.expr, _).text
                        reopen()
                    end),
                },
                { text = _("Graph"), callback = optional_action(handlers.graph) },
                {
                    text = _("Close"),
                    callback = function()
                        remember()
                        UIManager:close(dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function CalculatorView.show(state, handlers)
    open(state, handlers or {})
end

return CalculatorView
