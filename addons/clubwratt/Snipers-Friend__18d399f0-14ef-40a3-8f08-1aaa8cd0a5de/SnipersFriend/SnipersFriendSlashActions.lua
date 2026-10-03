-- SnipersFriendSlashActions.lua: /sf command handler (works without any settings library)

local SnipersFriend = SnipersFriend
local SlashUtils = SnipersFriend.SlashUtils
local ReticleUtils = SnipersFriend.ReticleUtils
local CameraUtils = SnipersFriend.CameraUtils
local RANGES = CameraUtils.RANGES
local LIMITS = CameraUtils.LIMIT_RANGES
local Log = SlashUtils.Log

local SlashActions = {}

---@return SnipersFriendReticleSettings
local function Reticle() return SnipersFriend.state.savedVars.reticle end
---@return SnipersFriendCameraSettings
local function Camera() return SnipersFriend.state.savedVars.camera end
---@return SnipersFriendCameraLimits
local function Limits() return SnipersFriend.state.savedVars.camera.limits end

local function Help()
    Log("/sf dot on|off              toggle the reticle dot")
    Log("/sf style <name>           " .. table.concat(ReticleUtils.STYLE_ORDER, ", "))
    Log("/sf size <px>              dot size (8-128)")
    Log("/sf gt [on|off|log|debug|scan]  ground-target range / line-of-sight indicator")
    Log("/sf line [on|off|depth|range <m>|always|width <m>]  3D aim line to max range")
    Log("-- limits for the game's Settings > Camera sliders (the only path on console) --")
    Log("/sf sensmax <n>            look sensitivity slider max (%.2f-%.2f)", LIMITS.sensitivityMax.min, LIMITS.sensitivityMax.max)
    Log("/sf distmax <n>            camera distance slider max (%.2f-%.2f)", LIMITS.distanceMax.min, LIMITS.distanceMax.max)
    Log("/sf heightrange <min> <max> camera height slider bounds (%.2f..%.2f)", LIMITS.heightMin.min, LIMITS.heightMax.max)
    Log("/sf offsetmax <n>          horizontal offset slider +/- (%.2f-%.2f)", LIMITS.offsetMax.min, LIMITS.offsetMax.max)
    Log("/sf fovrange <min> <max>   field of view slider bounds (%d..%d)", LIMITS.fovMin.min, LIMITS.fovMax.max)
    Log("/sf widen on|off           enable/disable the widened sliders")
    if CameraUtils.CanSetCVar() or CameraUtils.CanSetSetting() then
        Log("-- direct values (allowed on this platform) --")
        Log("/sf sens <x> [y] | dist <n> [siege] | height <n> | offset <n> | fov <n> | lock on|off")
    end
    Log("/sf save | apply | reset | status | probe | debug   (save = remember current camera values)")
end

---@param words string[]
---@param idx number
---@param range {min: number, max: number}
---@return number|nil
local function NumArg(words, idx, range)
    local v = tonumber(words[idx])
    if not v then return nil end
    return CameraUtils.Clamp(v, range.min, range.max)
end

---@param word string|nil
---@return boolean|nil
local function BoolArg(word)
    if word == "on" or word == "1" or word == "true" then return true end
    if word == "off" or word == "0" or word == "false" then return false end
    return nil
end

local function Relimit()
    SnipersFriend.CameraActions.ApplySliderLimits()
    Log("limits applied - adjust the value in Settings > Camera (reopen the menu if it is already open)")
end

local handlers = {}

-- ---------------------------------------------------------------- reticle

handlers.dot = function(words)
    local v = BoolArg(words[1])
    if v == nil then v = not Reticle().enabled end
    SnipersFriend.ReticleActions.SetEnabled(v)
    Log("reticle dot %s", v and "on" or "off")
end

handlers.style = function(words)
    local key = words[1]
    if not (key and ReticleUtils.STYLES[key]) then
        Log("styles: %s", table.concat(ReticleUtils.STYLE_ORDER, ", "))
        return
    end
    Reticle().style = key
    SnipersFriend.ReticleActions.RefreshStyle()
    Log("style = %s", key)
end

handlers.size = function(words)
    local v = NumArg(words, 1, { min = 8, max = 128 })
    if not v then Log("size = %d", Reticle().size) return end
    Reticle().size = v
    SnipersFriend.ReticleActions.RefreshStyle()
    Log("size = %d", v)
end

-- ---------------------------------------------------------------- limits (console path)

handlers.sensmax = function(words)
    local v = NumArg(words, 1, LIMITS.sensitivityMax)
    if not v then Log("sensmax = %.2f", Limits().sensitivityMax) return end
    Limits().sensitivityMax = v
    Relimit()
end

handlers.distmax = function(words)
    local v = NumArg(words, 1, LIMITS.distanceMax)
    if not v then Log("distmax = %.2f", Limits().distanceMax) return end
    Limits().distanceMax = v
    Relimit()
end

handlers.heightrange = function(words)
    local lo = NumArg(words, 1, LIMITS.heightMin)
    local hi = NumArg(words, 2, LIMITS.heightMax)
    if not (lo and hi) then Log("heightrange = %.2f .. %.2f", Limits().heightMin, Limits().heightMax) return end
    Limits().heightMin, Limits().heightMax = lo, hi
    Relimit()
end

handlers.offsetmax = function(words)
    local v = NumArg(words, 1, LIMITS.offsetMax)
    if not v then Log("offsetmax = %.2f", Limits().offsetMax) return end
    Limits().offsetMax = v
    Relimit()
end

handlers.fovrange = function(words)
    local lo = NumArg(words, 1, LIMITS.fovMin)
    local hi = NumArg(words, 2, LIMITS.fovMax)
    if not (lo and hi) then Log("fovrange = %d .. %d", Limits().fovMin, Limits().fovMax) return end
    Limits().fovMin, Limits().fovMax = lo, hi
    Relimit()
end

handlers.widen = function(words)
    local v = BoolArg(words[1])
    if v == nil then v = not Camera().unlockNativeSliders end
    Camera().unlockNativeSliders = v
    if v then SnipersFriend.CameraActions.ApplySliderLimits() else SnipersFriend.CameraActions.RestoreNativeSliders() end
    Log("widened sliders %s", v and "on" or "off")
end

-- ---------------------------------------------------------------- direct values (PC path)

local NO_DIRECT = " (stored only: this platform does not allow addons to set it - use Settings > Camera)"

handlers.sens = function(words)
    local x = NumArg(words, 1, RANGES.sensitivity)
    if not x then Log("sens = %.2f / %.2f", Camera().sensitivityX, Camera().sensitivityY) return end
    local y = NumArg(words, 2, RANGES.sensitivity) or x
    Camera().sensitivityX, Camera().sensitivityY = x, y
    local ok = SnipersFriend.CameraActions.ApplySensitivity()
    Log("sens = %.2f / %.2f%s", x, y, ok and "" or NO_DIRECT)
end

handlers.dist = function(words)
    local v = NumArg(words, 1, RANGES.distance)
    if not v then Log("dist = %.2f (siege %.2f)", Camera().distance, Camera().distanceSiege) return end
    Camera().distance = v
    local siege = NumArg(words, 2, RANGES.distanceSiege)
    if siege then Camera().distanceSiege = siege end
    local ok = SnipersFriend.CameraActions.ApplyDistance()
    Log("dist = %.2f (siege %.2f)%s", Camera().distance, Camera().distanceSiege, ok and "" or NO_DIRECT)
end

handlers.height = function(words)
    local v = NumArg(words, 1, RANGES.height)
    if not v then Log("height = %.2f", Camera().height) return end
    Camera().height = v
    local ok = SnipersFriend.CameraActions.ApplyHeight()
    Log("height = %.2f%s", v, ok and "" or NO_DIRECT)
end

handlers.offset = function(words)
    local v = NumArg(words, 1, RANGES.horizontalOffset)
    if not v then Log("offset = %.2f", Camera().horizontalOffset) return end
    Camera().horizontalOffset = v
    local ok = SnipersFriend.CameraActions.ApplyHorizontalOffset()
    Log("offset = %.2f%s", v, ok and "" or NO_DIRECT)
end

handlers.fov = function(words)
    local v = NumArg(words, 1, RANGES.fov)
    if not v then Log("fov = %d", Camera().fov) return end
    Camera().fov = v
    local ok = SnipersFriend.CameraActions.ApplyFov()
    Log("fov = %d%s", v, ok and "" or NO_DIRECT)
end

handlers.lock = function(words)
    local v = BoolArg(words[1])
    if v == nil then v = not Camera().lockDistance end
    Camera().lockDistance = v
    SnipersFriend.CameraActions.UpdateDistanceLock()
    Log("distance lock %s%s", v and "on" or "off", CameraUtils.CanSetCVar() and "" or " (no effect: SetCVar is private here)")
end

-- ---------------------------------------------------------------- misc

handlers.gt = function(words)
    local GT = SnipersFriend.GroundTargetActions
    local sub = words[1]
    local s = SnipersFriend.state.savedVars.groundTarget
    if sub == "on" or sub == "off" then
        s.enabled = sub == "on"; GT.Refresh(); Log("ground-target indicator %s", sub)
    elseif sub == "log" then
        local log = SnipersFriend.state.gtLog
        if #log == 0 then Log("gt log empty (enable 'Log verdict changes' or /sf gt debug)") end
        for _, line in ipairs(log) do Log(line) end
    elseif sub == "debug" then
        s.debugLog = not s.debugLog; Log("gt logging %s", s.debugLog and "on" or "off")
    elseif sub == "clear" then
        SnipersFriend.state.gtLog = {}; Log("gt log cleared")
    elseif sub == "scan" then
        GT.RefreshAbilities()
        for _, line in ipairs(GT.StatusLines()) do Log(line) end
    else
        for _, line in ipairs(GT.StatusLines()) do Log(line) end
        Log("/sf gt on|off | log | debug | clear | scan")
    end
end

handlers.line = function(words)
    local AL = SnipersFriend.AimLineActions
    local s = SnipersFriend.state.savedVars.aimLine
    local sub = words[1]
    if sub == "on" or sub == "off" then
        s.enabled = sub == "on"; AL.Refresh(); Log("aim line %s", sub)
    elseif sub == "depth" then
        s.depthTest = not s.depthTest; AL.Refresh(); Log("aim line depth test %s", s.depthTest and "on" or "off")
    elseif sub == "range" then
        local v = tonumber(words[2])
        if v then s.rangeOverrideM = CameraUtils.Clamp(v, 0, 60) end
        Log("aim line range override = %d (0 = ability range)", s.rangeOverrideM)
    elseif sub == "always" then
        s.showWithoutGroundAbility = not s.showWithoutGroundAbility
        Log("aim line without ground ability %s (%d m)", s.showWithoutGroundAbility and "on" or "off", s.fallbackRangeM)
    elseif sub == "width" then
        local v = tonumber(words[2])
        if v then s.lineWidthM = CameraUtils.Clamp(v, 0.02, 0.5) end
        Log("aim line width = %.2f m", s.lineWidthM)
    elseif sub == "ticks" then
        local v = tonumber(words[2])
        if v then s.tickIntervalM = CameraUtils.Clamp(v, 0, 10); s.showTicks = v > 0 else s.showTicks = not s.showTicks end
        Log("aim line ticks %s, every %.0f m", s.showTicks and "on" or "off", s.tickIntervalM)
    elseif sub == "ground" then
        s.showGround = not s.showGround; Log("ground marker %s", s.showGround and "on" or "off")
    elseif sub == "mode" then
        s.orientMode = s.orientMode == "basis" and "euler" or "basis"
        Log("aim line orientation mode = %s", s.orientMode)
    elseif sub == "dump" then
        s.debugDump = not s.debugDump
        Log("aim line geometry dump %s (shows in /sf line)", s.debugDump and "on" or "off")
    else
        for _, line in ipairs(AL.StatusLines()) do Log(line) end
        Log("/sf line on|off | depth | range <m> | always | width <m> | ticks [m] | ground | mode | dump")
    end
end

handlers.save = function()
    local changed = SnipersFriend.CameraActions.SnapshotFromEngine()
    Log("current camera values %s - they will be restored after every load", changed and "saved" or "already saved")
end

handlers.apply = function()
    SnipersFriend.CameraActions.ApplyAll()
    SnipersFriend.ReticleActions.Apply()
    Log("applied")
end

handlers.reset = function()
    local d = SnipersFriend.State.Defaults().camera
    local c = Camera()
    for k, v in pairs(d) do
        if k == "limits" then
            for lk, lv in pairs(v) do c.limits[lk] = lv end
        else
            c[k] = v
        end
    end
    SnipersFriend.CameraActions.ApplyAll()
    Log("camera settings and limits reset to defaults")
end

handlers.status = function()
    for _, line in ipairs(SnipersFriend.CameraActions.ReadBackStatus()) do
        Log(line)
    end
    Log("dot: %s, style %s, size %d", Reticle().enabled and "on" or "off", Reticle().style, Reticle().size)
end

handlers.probe = function()
    for _, line in ipairs(CameraUtils.ProbeApi()) do
        Log(line)
    end
end

handlers.debug = function()
    local sv = SnipersFriend.state.savedVars
    sv.debug = not sv.debug
    Log("debug %s", sv.debug and "on" or "off")
end

---@param args string
function SlashActions.HandleCommand(args)
    local command, remaining = SlashUtils.ParseCommand(args)
    local handler = handlers[command]
    if handler then
        handler(SlashUtils.SplitWords(remaining))
    else
        Help()
    end
end

SnipersFriend.SlashActions = SlashActions
