-- ErrorCatcherGameUtils.lua: thin, guarded reads of the game API (no side effects)
local GameUtils = {}

---Whether IsTrustedFunction can be called. A private function raises an error pcall cannot catch when it
---is so much as named, so the name is asked about first.
---@return boolean
function GameUtils.DetectTrustApi()
    if type(IsPrivateFunction) == "function" and IsPrivateFunction("IsTrustedFunction") then
        return false
    end
    if type(IsProtectedFunction) == "function" and IsProtectedFunction("IsTrustedFunction") then
        return false
    end
    return type(IsTrustedFunction) == "function"
end

---@param fn function
---@return boolean|nil trusted nil when the game cannot be asked
function GameUtils.IsTrusted(fn)
    if not ErrorCatcher.state.trustApi then
        return nil
    end
    local ok, trusted = pcall(IsTrustedFunction, fn)
    if not ok then
        return nil
    end
    return trusted == true
end

---@return boolean
function GameUtils.HasTraceback()
    return type(debug) == "table" and type(debug.traceback) == "function"
end

---The stack at the call, as text; "" when the game offers no traceback.
---@return string
function GameUtils.Traceback()
    if not GameUtils.HasTraceback() then
        return ""
    end
    local ok, trace = pcall(debug.traceback)
    if ok and type(trace) == "string" then
        return trace
    end
    return ""
end

---@return string
function GameUtils.SceneName()
    if not (SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName) then
        return "?"
    end
    local ok, name = pcall(SCENE_MANAGER.GetCurrentSceneName, SCENE_MANAGER)
    if ok and type(name) == "string" and name ~= "" then
        return name
    end
    return "?"
end

---Wrap a hook body so an error in it never reaches the game call it follows.
---@param label string
---@param fn function
---@return function
function GameUtils.Guard(label, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            ErrorCatcher.LogUtils.Once("guard:" .. label, "internal error in %s: %s", label, tostring(err))
        end
    end
end

---Follow a game function with a SecurePostHook: fn runs after it has returned, with its arguments, and
---leaves nothing of this add-on on its stack. Never ZO_PostHook, whose wrapper is the fault this add-on
---looks for.
---@param target any The table holding the function (a class, or _G)
---@param name string
---@param label string
---@param fn function
---@return boolean placed
function GameUtils.SecureHook(target, name, label, fn)
    if type(SecurePostHook) ~= "function" or type(target) ~= "table" or type(target[name]) ~= "function" then
        return false
    end
    return (pcall(SecurePostHook, target, name, GameUtils.Guard(label, fn)))
end

-- Global game functions already looked up: the function, or false when there is none to call.
local globals = {}

---A global game function by name; nil when the game has none or keeps it private. A private function
---raises an error pcall cannot catch when it is so much as named, so the name is asked about first.
---@param name string
---@return function|nil
function GameUtils.Global(name)
    local known = globals[name]
    if known == nil then
        known = false
        if not (type(IsPrivateFunction) == "function" and IsPrivateFunction(name)) then
            local value = rawget(_G, name)
            if type(value) == "function" then
                known = value
            end
        end
        globals[name] = known
    end
    return known or nil
end

---Whether a global of that name exists, of any kind; false for a name the game keeps private.
---@param name any
---@return boolean
function GameUtils.HasGlobal(name)
    if type(name) ~= "string" or (type(IsPrivateFunction) == "function" and IsPrivateFunction(name)) then
        return false
    end
    return rawget(_G, name) ~= nil
end

---Call a global game function that only reads. Returns its first two results; nil when it is missing or fails.
---@param name string
---@param ... any
---@return any, any
function GameUtils.Read(name, ...)
    local fn = GameUtils.Global(name)
    if not fn then
        return nil
    end
    local ok, first, second = pcall(fn, ...)
    if ok then
        return first, second
    end
    return nil
end

---Follow a global game function (see SecureHook); nothing is placed on one the game keeps private.
---@param name string
---@param label string
---@param fn function
---@return boolean placed
function GameUtils.SecureHookGlobal(name, label, fn)
    if not GameUtils.Global(name) then
        return false
    end
    return GameUtils.SecureHook(_G, name, label, fn)
end

---The add-on memory pool every add-on shares, in MB.
---@return number|nil used, number|nil capacity
function GameUtils.Pool()
    local used = GameUtils.Read("GetTotalUserAddOnMemoryPoolUsageMB")
    local capacity = GameUtils.Read("GetTotalUserAddOnMemoryPoolCapacityMB")
    if type(used) ~= "number" then
        return nil, nil
    end
    return used, type(capacity) == "number" and capacity or nil
end

---The whole Lua heap in MB, the game's own UI included.
---@return number|nil
function GameUtils.HeapMB()
    if type(collectgarbage) ~= "function" then
        return nil
    end
    local ok, kilobytes = pcall(collectgarbage, "count")
    if ok and type(kilobytes) == "number" then
        return kilobytes / 1024
    end
    return nil
end

---@param getManager function
---@return number active, number built
local function ReadPins(getManager)
    local manager = getManager()
    return manager:GetActiveObjectCount(), manager:GetTotalObjectCount()
end

---The world map's pins: the ones shown now, and every pin control built since the UI loaded (shown or
---waiting for reuse). Add-ons that draw pins draw them through this pool.
---@return number|nil active, number|nil built
function GameUtils.PinCounts()
    local getManager = GameUtils.Global("ZO_WorldMap_GetPinManager")
    if not getManager then
        return nil, nil
    end
    local ok, active, built = pcall(ReadPins, getManager)
    if ok and type(active) == "number" and type(built) == "number" then
        return active, built
    end
    return nil, nil
end

---A name as the game hands it out, without its grammar suffix ("Grahtwood^N").
---@param name any
---@return string|nil
local function PlainName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return (string.gsub(name, "%^.*$", ""))
end

---@return string
function GameUtils.ZoneName()
    return PlainName(GameUtils.Read("GetPlayerActiveSubzoneName"))
        or PlainName(GameUtils.Read("GetPlayerActiveZoneName"))
        or "?"
end

---@return string
function GameUtils.CharacterName()
    return PlainName(GameUtils.Read("GetUnitName", "player")) or "?"
end

---@return string|nil
function GameUtils.CharacterId()
    local id = GameUtils.Read("GetCurrentCharacterId")
    if id == nil then
        return nil
    end
    return tostring(id)
end

---Seconds of wall clock, as the game counts them.
---@return number
function GameUtils.WallNow()
    local stamp = GameUtils.Read("GetTimeStamp")
    return type(stamp) == "number" and stamp or 0
end

---Seconds since the game itself started: it runs on through a UI reload and restarts with the game.
---@return number
function GameUtils.GameClock()
    local milliseconds = GameUtils.Read("GetGameTimeMilliseconds")
    return type(milliseconds) == "number" and milliseconds / 1000 or 0
end

---@param stamp number
---@return string
function GameUtils.WallClock(stamp)
    local utils = LibConsoleLogger and LibConsoleLogger.Utils
    if type(utils) == "table" and type(utils.WallClock) == "function" then
        local ok, formatted = pcall(utils.WallClock, stamp)
        if ok and type(formatted) == "string" then
            return formatted
        end
    end
    -- This add-on loads ahead of the library, so at its own load it words the clock itself.
    local osLib = rawget(_G, "os")
    if type(osLib) == "table" and type(osLib.date) == "function" then
        local ok, formatted = pcall(osLib.date, "%Y-%m-%d %H:%M:%S", stamp)
        if ok and type(formatted) == "string" then
            return formatted
        end
    end
    return "t=" .. tostring(stamp)
end

---The game's add-on manager; nil when it gives none.
---@return table|nil
function GameUtils.AddOnManager()
    local manager = GameUtils.Read("GetAddOnManager")
    if type(manager) == "table" or type(manager) == "userdata" then
        return manager
    end
    return nil
end

---Call a method of the add-on manager that only reads. Returns its first three results; nil when the
---manager has no such method or it fails.
---@param manager any
---@param method string
---@param ... any
---@return any, any, any
function GameUtils.ManagerRead(manager, method, ...)
    local ok, first, second, third = pcall(function(...)
        return manager[method](manager, ...)
    end, ...)
    if ok then
        return first, second, third
    end
    return nil
end

ErrorCatcher.GameUtils = GameUtils
