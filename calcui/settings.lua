-- Persists the graph viewport and grid flag in <settings dir>/calculator.lua.
-- Never touches the document or its sidecar.

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local logger = require("logger")
local logic = require("calcui.settings_logic")

local Settings = {}

local store

local function open()
    if not store then
        store = LuaSettings:open(DataStorage:getSettingsDir() .. "/calculator.lua")
    end
    return store
end

-- Returns { viewport =, grid = }; defaults when missing or invalid.
function Settings.load()
    local ok, result = pcall(function()
        local s = open()
        return logic.sanitize({ viewport = s:readSetting("viewport"), grid = s:readSetting("grid") })
    end)
    if ok then
        return result
    end
    logger.warn("calculator: could not read settings:", result)
    return logic.defaults()
end

function Settings.save(vp, grid)
    local ok, err = pcall(function()
        local data = logic.to_data(vp, grid)
        local s = open()
        s:saveSetting("viewport", data.viewport)
        s:saveSetting("grid", data.grid)
        s:flush()
    end)
    if not ok then
        logger.warn("calculator: could not save settings:", err)
    end
end

return Settings
