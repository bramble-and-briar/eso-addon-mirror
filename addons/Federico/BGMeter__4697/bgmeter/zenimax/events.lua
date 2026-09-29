
BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.zenimax = BGMeter.zenimax or {}

local EM = EVENT_MANAGER
local M = {}

function M.register_addon_loaded(addon_name, callback)
    local token = addon_name .. "_OnLoaded"
    EM:RegisterForEvent(token, EVENT_ADD_ON_LOADED, function(_, loaded_name)
        if loaded_name ~= addon_name then return end
        EM:UnregisterForEvent(token, EVENT_ADD_ON_LOADED)
        local ok, err = pcall(callback)
        if not ok and BGMeter.Log then BGMeter.Log.error("on_addon_loaded failed: %s", tostring(err)) end
    end)
end

function M.register(name, event_code, handler)
    EM:RegisterForEvent(name, event_code, function(...)
        local ok, err = pcall(handler, ...)
        if not ok then
            if BGMeter.Log then BGMeter.Log.error("handler '%s' failed: %s", name, tostring(err)) end
            if BGMeter.Validate then BGMeter.Validate.fail("handler." .. name, err) end
        end
    end)
end

function M.unregister(name, event_code)
    EM:UnregisterForEvent(name, event_code)
end

function M.add_filter(name, event_code, ...)
    EM:AddFilterForEvent(name, event_code, ...)
end

function M.register_update(name, interval_ms, handler)
    EM:RegisterForUpdate(name, interval_ms, function(...)
        local ok, err = pcall(handler, ...)
        if not ok then
            if BGMeter.Log then BGMeter.Log.error("update '%s' failed: %s", name, tostring(err)) end
            if BGMeter.Validate then BGMeter.Validate.fail("update." .. name, err) end
        end
    end)
end

function M.unregister_update(name)
    EM:UnregisterForUpdate(name)
end

BGMeter.zenimax.events = M
