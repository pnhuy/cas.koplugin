-- Full-screen notebook: toolbar, a page of cells, a paging bar and, while a
-- cell is being edited, the programming keyboard docked underneath. The
-- model (calcnb/notebook.lua) owns all data; this view only renders pages of
-- it and forwards actions. Pages are discrete (no kinetic scrolling) for E Ink.

local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local ButtonTable = require("ui/widget/buttontable")
local CellWidget = require("calcui.cell_widget")
local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GraphOutput = require("calcui.graph_output")
local GraphView = require("calcui.graph_view")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local Keyboard = require("calcui.keyboard")
local store = require("calcui.notebook_store")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local cell_actions = require("calcnb.cell_actions")
local graph_model = require("calcui.graph_model")
local guard = require("calcui.guard")
local notebook_layout = require("calcui.notebook_layout")
local completion_session = require("calcnb.completion_session")
local keyboard_layout = require("calcnb.keyboard_layout")
local run_queue = require("calcnb.run_queue")
local strip_keys = require("calcnb.strip_keys")
local strip_sizing = require("calcui.strip_sizing")
local SuggestionStrip = require("calcui.suggestion_strip")
local _ = require("gettext")

local Screen = Device.screen

local ESTIMATED_CELL_H = 140
local STRIP_ROW_H = 34 -- scaled; one row of the suggestion strip
local CHIPS_COMPACT, CHIPS_WIDE = 4, 6

local NotebookView = InputContainer:extend{
    session = nil, -- notebook_store session: { nb, dirty, scroll, problems }
    nb = nil, -- calcnb.notebook (session.nb)
    handlers = nil, -- { calculator = fn, graph = fn } optional entries to the classic screens
}

function NotebookView:init()
    self.nb = self.session.nb
    self.top = 1
    local scroll = self.session.scroll
    if scroll and self.nb:index_of(scroll.top_id) then
        self.top = self.nb:index_of(scroll.top_id)
    end
    self.active = nil -- id of the cell being edited
    self.heights = {}
    self.queue = run_queue.new()
    self.keyboard = Keyboard:new{ dirty_target = self }
    self.completion = completion_session.new()
    if Device:hasKeys() then
        local Input = Device.input
        self.key_events = {
            NextPage = { { Input.group.PgFwd }, event = "NextPage" },
            PrevPage = { { Input.group.PgBack }, event = "PrevPage" },
            CloseNotebook = { { Input.group.Back }, event = "CloseNotebook" },
            AcceptSuggestion = { { "Press" }, { "Tab" }, event = "AcceptSuggestion" },
        }
    end
    self:rebuild()
    if #(self.session.problems or {}) > 0 then
        UIManager:show(InfoMessage:new{
            text = _("The saved notebook had problems and was repaired:") .. "\n- "
                .. table.concat(self.session.problems, "\n- ", 1, math.min(#self.session.problems, 5)),
        })
        self.session.problems = {}
    end
end

-- The first cell of the page, which is what a saved scroll position names.
function NotebookView:scroll_position()
    local cell = self.nb.cells[self.top]
    return cell and { top_id = cell.id, offset = 0 } or nil
end

-- Writes the notebook if it has unsaved changes. Shows a message on failure;
-- the notebook stays in memory and dirty, so nothing is lost.
function NotebookView:autosave()
    if not self.session.dirty:is_dirty() then
        return true
    end
    self:sync()
    local ok, message = store.save(self.session, self:scroll_position())
    if not ok then
        UIManager:show(InfoMessage:new{ text = message })
    end
    return ok
end

function NotebookView:save_now()
    self:sync()
    local ok, message = store.save(self.session, self:scroll_position())
    UIManager:show(InfoMessage:new{ text = ok and _("Notebook saved") or message, timeout = ok and 1 or nil })
end

-- Copies the live editor text into the model; call before anything that
-- rebuilds the page or reads a cell's source.
function NotebookView:sync()
    if self.editor and self.active then
        local ok, err = self.nb:set_source(self.active, self.editor:getText())
        if not ok then
            UIManager:show(InfoMessage:new{ text = err.message })
        end
    end
end

-- Draws the session's current model on the strip; repaints only the strip.
local function strip_model(self)
    if self.strip then
        self.strip:set_model(self.completion:model())
    end
end

local function bar(width, buttons)
    return ButtonTable:new{ width = width, sep_width = 0, buttons = { buttons } }
end

-- Stops inline plots and frees their canvases (page widgets are rebuilt or discarded).
function NotebookView:release_graphs()
    for _, widget in ipairs(self.shown or {}) do
        widget:release()
    end
    self.shown = {}
end

function NotebookView:rebuild()
    self:release_graphs()
    local nb = self.nb
    local w, h = Screen:getWidth(), Screen:getHeight()
    self.dimen = Geom:new{ w = w, h = h }
    self.editor = nil

    local small = Screen:scaleBySize(70)
    local toolbar = bar(w, {
        { text = nb.title ~= "" and nb.title or _("Notebook"), align = "left", callback = function() end },
        { text = "+", width = small, callback = guard.wrap(function() self:add_cell() end) },
        { text = _("Save"), width = Screen:scaleBySize(90), callback = guard.wrap(function() self:save_now() end) },
        { text = "≡", width = small, callback = guard.wrap(function() self:show_menu() end) },
        { text = "✕", width = small, callback = guard.wrap(function() self:close() end) },
    })
    local pagebar_buttons = {
        { text = "▲", callback = guard.wrap(function() self:page(-1) end) },
        { text = "▼", callback = guard.wrap(function() self:page(1) end) },
    }
    if self.active then
        table.insert(pagebar_buttons, { text = _("Hide keyboard"), callback = guard.wrap(function() self:stop_editing() end) })
    end
    local pagebar = bar(w, pagebar_buttons)

    local kb_h = self.active and self.keyboard:getHeight() or 0
    local strip_h, strip_rows = 0, 0
    local line_h = Screen:scaleBySize(STRIP_ROW_H)
    if self.active then
        local fit = strip_sizing.strip_height(h, w, kb_h, toolbar:getSize().h + pagebar:getSize().h, line_h)
        strip_h, strip_rows = fit.height, fit.rows
    end
    local content_h = h - toolbar:getSize().h - pagebar:getSize().h - kb_h - strip_h

    local count = #nb.cells
    self.top = notebook_layout.clamp(self.top, count)
    if self.active then
        local hs = {}
        for i, c in ipairs(nb.cells) do
            hs[i] = self.heights[c.id] or ESTIMATED_CELL_H
        end
        self.top = notebook_layout.reveal(hs, self.top, content_h, (nb:index_of(self.active)))
    end

    local page, used, shown
    local active_index = self.active and nb:index_of(self.active)
    while true do
        page = VerticalGroup:new{ align = "left" }
        used = 0
        shown = {}
        local shown_active = false
        self.editor = nil
        for i = self.top, count do
            local cell = nb.cells[i]
            local active = cell.id == self.active
            local widget = CellWidget:new{
                cell = cell,
                width = w,
                active = active,
                editing = active,
                show_parent = self,
                editor_h = Screen:scaleBySize(130),
                view = {
                    on_edit = function(id) self:start_editing(id) end,
                    on_run = function(id) self:run_cells({ id }) end,
                    on_menu = function(id) self:show_cell_menu(id) end,
                    on_expand = function(id) self:expand(id) end,
                    on_graph = function(id) self:open_graph(id) end,
                },
            }
            local cell_h = widget:getSize().h
            self.heights[cell.id] = cell_h
            if used + cell_h > content_h and #page > 0 then
                break
            end
            page[#page + 1] = widget
            shown[#shown + 1] = widget
            used = used + cell_h
            if active then
                shown_active = true
                self.editor = widget.editor
            end
        end
        -- estimated heights can be off; scroll until the edited cell is really on the page
        if not active_index or shown_active or self.top >= active_index then
            break
        end
        self.top = self.top + 1
    end
    page[#page + 1] = VerticalSpan:new{ width = math.max(0, content_h - used) }
    self.shown = shown
    for _, widget in ipairs(shown) do
        widget:start()
    end

    local column = VerticalGroup:new{ align = "left", toolbar, page, pagebar }
    self.strip = nil
    if self.active then
        self.keyboard.editor = self.editor
        if strip_rows > 0 and self.editor then
            column[#column + 1] = self:build_strip(w, strip_rows, line_h)
        end
        column[#column + 1] = self.keyboard
    end
    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        width = w,
        height = h,
        column,
    }
    UIManager:setDirty(self, "ui")
end

-- A fresh session for each edited cell; a rebuild of the same cell keeps its
-- dismissal and highlight.
function NotebookView:build_strip(w, rows, line_h)
    if self.completion_for ~= self.active then
        self.completion, self.completion_for = completion_session.new(), self.active
    end
    self.completion:set_limit(keyboard_layout.is_compact(w) and CHIPS_COMPACT or CHIPS_WIDE)
    self.completion:set_names(self.nb:completion_names())
    local strip = SuggestionStrip:new{
        width = w,
        rows = rows,
        line_h = line_h,
        on_accept = function() self:accept_suggestion() end,
        on_select = function(index)
            if self.completion:select(index) then
                strip_model(self)
            end
        end,
        on_dismiss = function()
            if self.completion:dismiss() then
                strip_model(self)
            end
        end,
    }
    self.strip = strip
    local editor = self.editor
    editor.on_change = guard.wrap(function() self:update_suggestions() end)
    editor.key_filter = function(key) return self:strip_key(key) end
    self.completion:update(editor:cursor())
    strip:set_model(self.completion:model(), true)
    return strip
end

function NotebookView:update_suggestions()
    if not (self.strip and self.editor) then
        return
    end
    self.completion:set_names(self.nb:completion_names())
    self.completion:update(self.editor:cursor())
    strip_model(self)
end

-- Inserts the highlighted suggestion at the cursor. Nothing is run.
function NotebookView:accept_suggestion()
    local edit = self.editor and self.completion:accept()
    if edit then
        self.editor:replace_word(edit)
        self:sync()
    end
    strip_model(self)
end

function NotebookView:start_editing(id)
    self:sync()
    self.active = id
    self:rebuild()
end

function NotebookView:stop_editing()
    self:sync()
    self.active = nil
    self:rebuild()
end

function NotebookView:page(direction)
    self:sync()
    local hs = {}
    for i, c in ipairs(self.nb.cells) do
        hs[i] = self.heights[c.id] or ESTIMATED_CELL_H
    end
    local content_h = Screen:getHeight() - self.keyboard:getHeight() - Screen:scaleBySize(120)
    local move = direction > 0 and notebook_layout.page_down or notebook_layout.page_up
    self.top = move(hs, self.top, content_h)
    self.active = nil
    self:rebuild()
end

-- True while the suggestion strip is on screen; the keys then belong to it.
function NotebookView:strip_shown()
    return self.strip ~= nil and self.editor ~= nil and self.completion:model() ~= nil
end

-- Keys for the strip while it is shown (see CellEditor:onKeyPress); true when taken.
function NotebookView:strip_key(key)
    local action = strip_keys.action(key, self:strip_shown())
    if action == "accept" then
        return self:onAcceptSuggestion()
    elseif action == "dismiss" then
        return self:onCloseNotebook()
    elseif action == "next" then
        return self:onNextPage()
    elseif action == "prev" then
        return self:onPrevPage()
    end
    return false
end

function NotebookView:onNextPage()
    if self:strip_shown() then
        guard.wrap(function()
            if self.completion:move(1) then
                strip_model(self)
            end
        end)()
        return true
    end
    self:page(1)
    return true
end

function NotebookView:onPrevPage()
    if self:strip_shown() then
        guard.wrap(function()
            if self.completion:move(-1) then
                strip_model(self)
            end
        end)()
        return true
    end
    self:page(-1)
    return true
end

-- Press and Tab accept the highlighted suggestion; with no strip they are not ours.
function NotebookView:onAcceptSuggestion()
    if not self:strip_shown() then
        return false
    end
    guard.wrap(function() self:accept_suggestion() end)()
    return true
end

function NotebookView:add_cell(after_id, cell_type)
    self:sync()
    local nb = self.nb
    local cell, err
    if after_id then
        local _, i = nb:get(after_id)
        cell, err = nb:add((i or #nb.cells) + 1, cell_type)
    else
        cell, err = nb:add(self.active and (nb:index_of(self.active) + 1) or (#nb.cells + 1), cell_type)
    end
    if not cell then
        UIManager:show(InfoMessage:new{ text = err.message })
        return
    end
    self.active = cell.id
    self:rebuild()
end

-- Runs one or more cells, one per UI tick so the screen can update between them.
function NotebookView:run_cells(ids)
    self:sync()
    local ok = self.queue:start(ids)
    if not ok then
        UIManager:show(InfoMessage:new{ text = _("A run is already in progress") })
        return
    end
    self:step()
end

function NotebookView:step()
    self:sync() -- text typed while the previous cell ran
    local id = self.queue:next()
    if not id then
        self:rebuild()
        return
    end
    local cell = self.nb:get(id)
    if cell then
        cell.status = "running"
    end
    self:rebuild()
    UIManager:nextTick(guard.wrap(function()
        if not self.queue:cancelled() then
            self.nb:run_cell(id, { yield = function() return not self.queue:cancelled() end })
        end
        self.queue:done()
        self:step()
    end))
end

-- Full-screen viewer for a plot cell; the viewport the user ends with goes
-- back to the cell. The page (and so the scroll position) is left as it was.
function NotebookView:open_graph(id)
    self:sync()
    local cell = self.nb:get(id)
    if not (cell and cell.output and cell.output.graph) then
        return
    end
    GraphView.show(graph_model.from_graph(cell.output.graph, cell.viewport), nil, {
        on_close = function(state)
            cell.viewport = graph_model.to_viewport(state)
            self.session.dirty:mark()
            self:rebuild()
        end,
    })
end

function NotebookView:expand(id)
    local cell = self.nb:get(id)
    if cell and cell.output and cell.output.full then
        UIManager:show(InfoMessage:new{ text = cell.output.full })
    end
end

local function copy_text(text, what)
    if text and text ~= "" and Device:hasClipboard() then
        Device.input.setClipboardText(text)
        UIManager:show(InfoMessage:new{ text = what .. " " .. _("copied"), timeout = 1 })
    end
end

-- Types the result of cell `id` at the cursor of the cell being edited.
function NotebookView:insert_result(id)
    local cell = self.nb:get(id)
    local text = cell and cell_actions.insert_text(cell)
    if not text then
        UIManager:show(InfoMessage:new{ text = _("This cell has no result to insert"), timeout = 2 })
        return
    end
    if not (self.editor and self.active and self.active ~= id) then
        UIManager:show(InfoMessage:new{ text = _("Tap another cell to edit it, then insert"), timeout = 2 })
        return
    end
    self.editor:type_text(text)
    self:sync()
    UIManager:setDirty(self, "ui")
end

function NotebookView:show_cell_menu(id)
    self:sync()
    local nb = self.nb
    local dialog
    local function item(text, fn)
        return { { text = text, callback = guard.wrap(function()
            UIManager:close(dialog)
            fn()
        end) } }
    end
    dialog = ButtonDialog:new{
        buttons = {
            item(_("Run and add cell"), function()
                self:add_cell(id)
                self:run_cells({ id })
            end),
            item(_("Add cell above"), function()
                local cell, err = nb:add_above(id)
                if not cell then
                    UIManager:show(InfoMessage:new{ text = err.message })
                    return
                end
                self.active = cell.id
                self:rebuild()
            end),
            item(_("Add cell below"), function() self:add_cell(id) end),
            item(_("Add note below"), function() self:add_cell(id, "text") end),
            item(_("Duplicate"), function()
                nb:duplicate(id)
                self:rebuild()
            end),
            item(_("Move up"), function()
                nb:move(id, -1)
                self:rebuild()
            end),
            item(_("Move down"), function()
                nb:move(id, 1)
                self:rebuild()
            end),
            item(_("Copy source"), function()
                local cell = nb:get(id)
                copy_text(cell and cell_actions.source_text(cell), _("Source"))
            end),
            item(_("Copy result"), function()
                local cell = nb:get(id)
                copy_text(cell and cell_actions.result_text(cell), _("Result"))
            end),
            item(_("Insert result into edited cell"), function()
                self:insert_result(id)
            end),
            item(_("Clear output"), function()
                nb:clear_output(id)
                self:rebuild()
            end),
            item(_("Delete"), function()
                local function delete()
                    if self.active == id then
                        self.active = nil
                    end
                    nb:delete(id)
                    self:rebuild()
                end
                local cell = nb:get(id)
                if cell and not cell_actions.needs_delete_confirmation(cell) then
                    delete()
                    return
                end
                UIManager:show(ConfirmBox:new{
                    text = _("Delete this cell?"),
                    ok_text = _("Delete"),
                    ok_callback = guard.wrap(delete),
                })
            end),
        },
    }
    UIManager:show(dialog)
end

function NotebookView:show_menu()
    self:sync()
    local dialog
    local function item(text, fn)
        return { { text = text, callback = guard.wrap(function()
            UIManager:close(dialog)
            fn()
        end) } }
    end
    local rows = {
        item(_("Run all cells"), function()
            self:run_cells(self.nb:begin_run_all())
        end),
        item(_("Clear all outputs"), function()
            local function clear()
                self.nb:clear_all_outputs()
                self:rebuild()
            end
            if not cell_actions.has_outputs(self.nb) then
                return
            end
            UIManager:show(ConfirmBox:new{
                text = _("Clear all outputs? The cells' text is kept."),
                ok_text = _("Clear"),
                ok_callback = guard.wrap(clear),
            })
        end),
    }
    if self.handlers and self.handlers.calculator then
        rows[#rows + 1] = item(_("Classic calculator"), self.handlers.calculator)
    end
    if self.handlers and self.handlers.graph then
        rows[#rows + 1] = item(_("Classic graph"), self.handlers.graph)
    end
    rows[#rows + 1] = item(_("Delete saved notebook"), function()
        store.delete(self.session, function(ok)
            if not ok then
                UIManager:show(InfoMessage:new{ text = _("Could not delete the saved notebook") })
                return
            end
            self.queue:cancel()
            self.nb, self.active, self.top, self.heights = self.session.nb, nil, 1, {}
            self:rebuild()
        end)
    end)
    dialog = ButtonDialog:new{ buttons = rows }
    UIManager:show(dialog)
end

function NotebookView:close()
    self:sync()
    self.queue:cancel()
    UIManager:close(self) -- onCloseWidget saves and frees
end

function NotebookView:onCloseNotebook()
    if self:strip_shown() then
        guard.wrap(function()
            if self.completion:dismiss() then
                strip_model(self)
            end
        end)()
        return true
    end
    self:close()
    return true
end

-- Every way of leaving (Close, Back, KOReader quitting) ends here.
function NotebookView:onCloseWidget()
    self.queue:cancel()
    self:autosave()
    self:release_graphs()
    GraphOutput.clear_cache()
end

-- Suspend and exit: keep the file current without closing.
function NotebookView:onFlushSettings()
    self:autosave()
end

-- Rotation or window resize: sizes were computed for the old screen.
function NotebookView:onScreenResize()
    self.heights = {}
    self.keyboard:relayout(Screen:getWidth(), Screen:getHeight())
    self:rebuild()
end

function NotebookView:onSetDimensions()
    self:onScreenResize()
end

function NotebookView.show(session, handlers)
    UIManager:show(NotebookView:new{ session = session, handlers = handlers })
end

return NotebookView
