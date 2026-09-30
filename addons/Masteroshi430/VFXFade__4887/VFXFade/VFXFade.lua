local ADDON = "VFXFade"

local defaults = {
    intervalMin = 45,
    resetOnLogin = true,
    self = true,
    friendly = true,
    enemy = true,
}

local SETTINGS = {
    self     = GRAPHICS_SETTING_VFX_SELF_INTENSITY,
    friendly = GRAPHICS_SETTING_VFX_FRIENDLY_INTENSITY,
    enemy    = GRAPHICS_SETTING_VFX_ENEMY_INTENSITY,
}
local ORDER = { "self", "friendly", "enemy" }

local STEPS = {
    [0] = { value = VFX_INTENSITY_VALUE_NORMAL,  name = "Normal" },
    [1] = { value = VFX_INTENSITY_VALUE_LOW,     name = "Low" },
    [2] = { value = VFX_INTENSITY_VALUE_MINIMAL, name = "Minimal" },
}
local MAX_STEP = 2
local CHECK_MS = 10000

local sv
local sessionStart
local currentStep = -1

local function Say(s) d("|c66CCFF[VFXFade]|r " .. s) end

local function ElapsedMin()
    return sessionStart and (GetGameTimeMilliseconds() - sessionStart) / 60000 or 0
end

local function Apply(step)
    for _, which in ipairs(ORDER) do
        if sv[which] then
            SetSetting(SETTING_TYPE_GRAPHICS, SETTINGS[which], tostring(STEPS[step].value))
        end
    end
    currentStep = step
    Say("VFX intensity -> |cFFFFFF" .. STEPS[step].name .. "|r")
end

local function Tick()
    if not sessionStart then return end
    local step = zo_min(MAX_STEP, zo_floor(ElapsedMin() / zo_max(1, sv.intervalMin)))
    if step > currentStep then Apply(step) end
end

local function OnSlash(text)
    local cmd, arg = zo_strmatch(text or "", "^(%S*)%s*(%S*)")
    cmd = (cmd or ""):lower()
    if cmd == "reset" then
        sessionStart = GetGameTimeMilliseconds()
        Apply(0)
    elseif cmd == "interval" and tonumber(arg) then
        sv.intervalMin = zo_max(1, tonumber(arg))
        Say("interval = " .. sv.intervalMin .. " min")
    else
        local rem = currentStep >= MAX_STEP and "-" or
            string.format("%.0f min", zo_max(0, (currentStep + 1) * sv.intervalMin - ElapsedMin()))
        Say(string.format("%s | session %.0f min | next step: %s",
            STEPS[currentStep] and STEPS[currentStep].name or "?", ElapsedMin(), rem))
        Say("/vfxfade reset | interval <min>")
    end
end

local function BuildMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end
    local panel = LAM:RegisterAddonPanel(ADDON .. "Panel", {
        type = "panel", name = "|cf49b42VFX Fade|r", author = "|c3CB371@Masteroshi430|r", version = "2026.09.29",
    })
    LAM:RegisterOptionControls(ADDON .. "Panel", {
        { type = "slider", name = "Minutes per step", min = 1, max = 180, step = 1,
          getFunc = function() return sv.intervalMin end,
          setFunc = function(v) sv.intervalMin = v end, default = defaults.intervalMin },
        { type = "checkbox", name = GetString(SI_GRAPHICS_OPTIONS_VIDEO_VFX_SELF_INTENSITY),
          getFunc = function() return sv.self end, setFunc = function(v) sv.self = v end },
        { type = "checkbox", name = GetString(SI_GRAPHICS_OPTIONS_VIDEO_VFX_FRIENDLY_INTENSITY),
          getFunc = function() return sv.friendly end, setFunc = function(v) sv.friendly = v end },
        { type = "checkbox", name = GetString(SI_GRAPHICS_OPTIONS_VIDEO_VFX_ENEMY_INTENSITY),
          getFunc = function() return sv.enemy end, setFunc = function(v) sv.enemy = v end },
        { type = "checkbox", name = "Reset to Normal at login",
          getFunc = function() return sv.resetOnLogin end,
          setFunc = function(v) sv.resetOnLogin = v end, default = defaults.resetOnLogin },
    })
end

local function OnPlayerActivated()
    if sessionStart then return end
    sessionStart = GetGameTimeMilliseconds()
    if sv.resetOnLogin then Apply(0) else currentStep = 0 end
    EVENT_MANAGER:RegisterForUpdate(ADDON .. "_Tick", CHECK_MS, Tick)
end

local function OnAddonLoaded(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    sv = ZO_SavedVars:NewAccountWide("VFXFade_SV", 1, nil, defaults)
    SLASH_COMMANDS["/vfxfade"] = OnSlash
    BuildMenu()
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnAddonLoaded)
