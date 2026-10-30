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
local graph_model = require("calcui.graph_model")
local guard = require("calcui.guard")
local notebook_layout = require("calcui.notebook_layout")
local run_queue = require("calcnb.run_queue")
local _ = require("gettext")

local Screen = Device.screen

local ESTIMATED_CELL_H = 140

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
    if Device:hasKeys() then
        local Input = Device.input
        self.key_events = {
            NextPage = { { Input.group.PgFwd }, event = "NextPage" },
            PrevPage = { { Input.group.PgBack }, event = "PrevPage" },
            CloseNotebook = { { Input.group.Back }, event = "CloseNotebook" },
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
    local content_h = h - toolbar:getSize().h - pagebar:getSize().h - kb_h

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
    if self.active then
        self.keyboard.editor = self.editor
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

function NotebookView:onNextPage()
    self:page(1)
    return true
end

function NotebookView:onPrevPage()
    self:page(-1)
    return true
end

function NotebookView:add_cell(after_id)
    self:sync()
    local nb = self.nb
    local cell, err
    if after_id then
        cell, err = nb:add_below(after_id)
    else
        cell, err = nb:add(self.active and (nb:index_of(self.active) + 1) or (#nb.cells + 1))
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
                copy_text(cell and cell.source, _("Source"))
            end),
            item(_("Copy result"), function()
                local cell = nb:get(id)
                copy_text(cell and cell.output and (cell.output.full or cell.output.canonical), _("Result"))
            end),
            item(_("Clear output"), function()
                nb:clear_output(id)
                self:rebuild()
            end),
            item(_("Delete"), function()
                UIManager:show(ConfirmBox:new{
                    text = _("Delete this cell?"),
                    ok_text = _("Delete"),
                    ok_callback = guard.wrap(function()
                        if self.active == id then
                            self.active = nil
                        end
                        nb:delete(id)
                        self:rebuild()
                    end),
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
            self.nb:clear_all_outputs()
            self:rebuild()
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
