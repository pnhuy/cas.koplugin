-- KOReader side of notebook persistence: reads and writes
-- <settings dir>/calculator_notebook.lua through LuaSettings (which keeps a
-- .old backup). The format rules live in calcnb/store_logic.lua. Nothing here
-- touches books, sidecars or annotations.

local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local UIManager = require("ui/uimanager")
local dirty_mod = require("calcnb.dirty")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local notebook = require("calcnb.notebook")
local store_logic = require("calcnb.store_logic")
local _ = require("gettext")

local Store = {}

local function path()
    return DataStorage:getSettingsDir() .. "/calculator_notebook.lua"
end

local function watched(nb)
    local dirty = dirty_mod.new()
    dirty:watch(nb)
    return dirty
end

-- A session is { nb, dirty, scroll, problems, refused } and lives for the
-- KOReader process; the view reads and replaces its fields.
function Store.load()
    local ok, nb, problems, scroll, state = pcall(function()
        local existed = lfs.attributes(path(), "mode") == "file"
        local file = LuaSettings:open(path()).data
        local n, p, s, st = store_logic.from_file(file)
        if st == "empty" and existed and next(file) == nil then
            p = { _("the saved notebook could not be read") }
        end
        return n, p, s, st
    end)
    if not ok then
        logger.warn("calculator: could not read notebook:", nb)
        nb, problems, scroll, state = nil, { _("the saved notebook could not be read") }, nil, "repaired"
    end
    nb = nb or notebook.new(_("Notebook"))
    for _, p in ipairs(problems) do
        logger.warn("calculator: notebook problem:", p)
    end
    return {
        nb = nb,
        dirty = watched(nb),
        scroll = scroll,
        problems = problems,
        refused = state == "newer",
    }
end

-- Returns true, or false and a message. The notebook stays dirty on failure.
function Store.save(session, scroll)
    if session.refused then
        return false, _("The saved notebook was made by a newer version; it was left untouched.")
    end
    local nb = session.nb
    local message
    local ok = session.dirty:save(function()
        local wrote, err = pcall(function()
            local file = store_logic.to_file(nb, scroll)
            local settings = LuaSettings:open(path())
            for key, value in pairs(file) do
                settings:saveSetting(key, value)
            end
            settings:flush()
        end)
        if not wrote then
            message = tostring(err)
            return false
        end
        -- LuaSettings:flush hides write errors, so read the file back
        local read, stored = pcall(dofile, path())
        local back = read and type(stored) == "table" and stored.notebooks and stored.notebooks[store_logic.NAME]
        if not (back and back.title == nb.title and #back.cells == #nb.cells) then
            message = _("the file could not be written")
            return false
        end
        return true
    end)
    if not ok then
        logger.warn("calculator: could not save notebook:", message)
        return false, _("Could not save the notebook") .. (message and (": " .. message) or "")
    end
    session.scroll = scroll
    return true
end

-- Asks first; `done(true)` runs once the saved file is gone and the session
-- holds a fresh empty notebook.
function Store.delete(session, done)
    UIManager:show(ConfirmBox:new{
        text = _("Delete the saved notebook and start a new one?"),
        ok_text = _("Delete"),
        ok_callback = function()
            local ok, err = pcall(function()
                local settings = LuaSettings:open(path())
                for _, key in ipairs({ "version", "notebooks", "last_notebook" }) do
                    settings:delSetting(key)
                end
                settings:flush()
            end)
            if not ok then
                logger.warn("calculator: could not delete notebook:", err)
                done(false)
                return
            end
            local nb = notebook.new(_("Notebook"))
            session.nb, session.dirty, session.scroll, session.refused = nb, watched(nb), nil, false
            done(true)
        end,
    })
end

return Store
