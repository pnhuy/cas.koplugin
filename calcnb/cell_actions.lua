-- Pure decisions behind the cell menu: what text a copy or insert yields and
-- when a destructive action needs a confirmation.

local M = {}

function M.source_text(cell)
    if cell.source and cell.source ~= "" then
        return cell.source
    end
end

-- Plain text of the output: the full text when the display was shortened.
function M.result_text(cell)
    local out = cell.output
    if not out or out.empty then
        return nil
    end
    local text = out.full or out.canonical
    if text and text ~= "" then
        return text
    end
end

-- Only values are inserted into other cells; an error message or a plot
-- label is not an expression.
function M.insert_text(cell)
    if cell.output and cell.output.kind == "value" then
        return M.result_text(cell)
    end
end

function M.needs_delete_confirmation(cell)
    return (cell.source or "") ~= "" or cell.output ~= nil
end

function M.has_outputs(nb)
    for _, c in ipairs(nb.cells) do
        if c.output then
            return true
        end
    end
    return false
end

return M
