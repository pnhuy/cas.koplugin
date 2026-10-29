-- Function list dialogs for the Graph view: list, add, edit, show/hide, remove.

local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local model = require("calcui.graph_model")
local outcome = require("calcui.outcome")
local _ = require("gettext")

local FunctionList = {}

local function row_label(entry)
    local mark = entry.error and "⚠ " or (entry.visible and "✓ " or "· ")
    return mark .. "y = " .. entry.text
end

local show

-- entry == nil adds a new function.
local function prompt(state, entry, on_change)
    local dialog
    dialog = InputDialog:new{
        title = entry and _("Edit function") or _("Add function"),
        input = entry and entry.text or "",
        input_hint = _("y = e.g. x^2 - 1"),
        allow_newline = false,
        buttons = {{
            {
                text = _("Cancel"),
                callback = function()
                    UIManager:close(dialog)
                    show(state, on_change)
                end,
            },
            {
                text = _("Save"),
                is_enter_default = true,
                callback = function()
                    local text = dialog:getInputText()
                    local saved, err
                    if entry then
                        saved, err = model.edit(state, entry.id, text)
                    else
                        saved, err = model.add(state, text)
                    end
                    if not saved then
                        UIManager:show(InfoMessage:new{ text = outcome.describe(text, err, _) })
                        return
                    end
                    UIManager:close(dialog)
                    on_change()
                    show(state, on_change)
                end,
            },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

local function actions(state, entry, on_change)
    local dialog
    local function done()
        UIManager:close(dialog)
        on_change()
        show(state, on_change)
    end
    dialog = ButtonDialog:new{
        title = "y = " .. entry.text,
        buttons = {
            {{
                text = _("Edit"),
                callback = function()
                    UIManager:close(dialog)
                    prompt(state, entry, on_change)
                end,
            }},
            {{
                text = entry.visible and _("Hide") or _("Show"),
                callback = function()
                    model.toggle(state, entry.id)
                    done()
                end,
            }},
            {{
                text = _("Remove"),
                callback = function()
                    model.remove(state, entry.id)
                    done()
                end,
            }},
            {{
                text = _("Back"),
                callback = function()
                    UIManager:close(dialog)
                    show(state, on_change)
                end,
            }},
        },
    }
    UIManager:show(dialog)
end

-- on_change() is called after any change to the list so the plot can refresh.
function show(state, on_change)
    local dialog
    local buttons = {}
    for _, entry in ipairs(state.functions) do
        buttons[#buttons + 1] = {{
            text = row_label(entry),
            callback = function()
                UIManager:close(dialog)
                actions(state, entry, on_change)
            end,
        }}
    end
    buttons[#buttons + 1] = {{
        text = _("Add function"),
        enabled = #state.functions < model.MAX_FUNCTIONS,
        callback = function()
            UIManager:close(dialog)
            prompt(state, nil, on_change)
        end,
    }}
    buttons[#buttons + 1] = {{
        text = _("Close"),
        callback = function()
            UIManager:close(dialog)
        end,
    }}
    dialog = ButtonDialog:new{ title = _("Functions"), buttons = buttons }
    UIManager:show(dialog)
end

FunctionList.show = show

return FunctionList
