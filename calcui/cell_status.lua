-- Cell status to symbol and text (FR-012: never colour alone). Pure.
-- Editing is an overlay shown while a cell has focus; it does not replace the
-- status stored on the cell.

local M = {}

local STATES = {
    idle = { symbol = "○", ascii = "-", label = "Idle" },
    editing = { symbol = "✎", ascii = "e", label = "Editing" },
    running = { symbol = "…", ascii = "...", label = "Running" },
    completed = { symbol = "✓", ascii = "ok", label = "Done" },
    error = { symbol = "✕", ascii = "x", label = "Error" },
    stale = { symbol = "◐", ascii = "~", label = "Stale" },
}

function M.describe(status, editing, ascii)
    local s = STATES[editing and "editing" or status] or STATES.idle
    return { symbol = ascii and s.ascii or s.symbol, label = s.label }
end

function M.input_label(cell)
    return "In [" .. (cell.exec_number and tostring(cell.exec_number) or " ") .. "]:"
end

function M.is_out_of_date(cell)
    return cell.out_of_date == true
end

return M
