-- BloodHungerTracker
-- Displays your Werewolf Blood Hunger stacks on-screen while transformed.

local ADDON_NAME = "BloodHungerTracker"
local ADDON_VERSION = 1
local ADDON_DISPLAY_VERSION = "1.0.5"

local BloodHungerTracker = {}
local addon = BloodHungerTracker

local defaults = {
    isEnabled = true,
    onlyShowInForm = true,
    lockPosition = false,
    hideWhenNoStacks = false,
}

local positionDefaults = {
    point = CENTER,
    relativePoint = CENTER,
    offsetX = 0,
    offsetY = 220,
    scale = 1.0,
}

local BASE_WIDTH = 170
local BASE_HEIGHT = 96
local MIN_SCALE = 0.3
local MAX_SCALE = 1.5

--------------------------------------------------------------------------------
-- Core display logic
--------------------------------------------------------------------------------

-- Blood Hunger's ability id — locale-independent, unlike matching on the buff's
-- (English-only) display name. Kept as a table/loop per item 6, so any additional
-- related ids discovered later can simply be added here.
local BLOOD_HUNGER_ABILITY_IDS = { 267744 }
local NUM_PIPS = 4

local window, content, timerText, pips = nil, nil, nil, {}

local isBloodHungerAbilityId = {}
for _, id in ipairs(BLOOD_HUNGER_ABILITY_IDS) do
    isBloodHungerAbilityId[id] = true
end

local function ScanBloodHunger()
    local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, deprecatedBuffType, effectType, abilityType, statusEffectType, abilityId = GetUnitBuffInfo("player", i)
        if isBloodHungerAbilityId[abilityId] then
            return stackCount or 1, timeEnding
        end
    end
    return 0, 0
end

local TIMER_UPDATE_NAME = ADDON_NAME .. "Timer"
local TIMER_UPDATE_INTERVAL_MS = 100

local function StopTimerLoop()
    EVENT_MANAGER:UnregisterForUpdate(TIMER_UPDATE_NAME)
end

local function OnTimerUpdate()
    local remaining = addon.buffEndTime - GetFrameTimeSeconds()
    if remaining <= 0 then
        timerText:SetText("")
        StopTimerLoop()
        return
    end
    timerText:SetText(string.format("%.1fs", remaining))
end

local function HideDisplay()
    window:SetHidden(true)
    timerText:SetText("")
    StopTimerLoop()
end

local function RefreshBloodHunger()
    if not addon.savedVariables.isEnabled then
        HideDisplay()
        return
    end

    local inForm = IsPlayerInWerewolfForm()

    if addon.savedVariables.onlyShowInForm and not inForm then
        HideDisplay()
        return
    end

    local stacks, endTime = ScanBloodHunger()

    if stacks == 0 and addon.savedVariables.hideWhenNoStacks then
        HideDisplay()
        return
    end

    window:SetHidden(false)

    for i = 1, NUM_PIPS do
        pips[i]:SetHidden(i > stacks)
    end

    if stacks > 0 and endTime and endTime > 0 then
        addon.buffEndTime = endTime
        OnTimerUpdate()
        EVENT_MANAGER:RegisterForUpdate(TIMER_UPDATE_NAME, TIMER_UPDATE_INTERVAL_MS, OnTimerUpdate)
    else
        timerText:SetText("")
        StopTimerLoop()
    end
end

local function OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, deprecatedBuffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
    -- unitTag and abilityId are already guaranteed by the engine-side filters
    -- registered below, so this callback only ever fires for exactly the events
    -- we care about — no conditional checks needed here.
    RefreshBloodHunger()
end

local function OnWerewolfStateChanged(eventCode, isWerewolf)
    RefreshBloodHunger()
end

local function OnPlayerActivated(eventCode)
    -- Covers the case of /reloadui or login while already transformed
    RefreshBloodHunger()
end

--------------------------------------------------------------------------------
-- Window setup (position, lock/unlock, color)
--------------------------------------------------------------------------------

local function ApplySavedPosition()
    local pv = addon.positionVariables

    -- Defensive check: guard against any stale/corrupted saved value
    -- (e.g. from an older addon version) that isn't a valid AnchorPosition.
    if type(pv.point) ~= "number" or type(pv.relativePoint) ~= "number" then
        pv.point = positionDefaults.point
        pv.relativePoint = positionDefaults.relativePoint
        pv.offsetX = positionDefaults.offsetX
        pv.offsetY = positionDefaults.offsetY
    end

    window:ClearAnchors()
    window:SetAnchor(pv.point, GuiRoot, pv.relativePoint, pv.offsetX, pv.offsetY)
end

local function ApplySavedScale()
    local pv = addon.positionVariables

    if type(pv.scale) ~= "number" then
        pv.scale = positionDefaults.scale
    end

    window:SetDimensions(BASE_WIDTH * pv.scale, BASE_HEIGHT * pv.scale)
    content:SetScale(pv.scale)
end

local function OnResizeStop(control)
    local width, height = control:GetDimensions()

    -- Derive a single scale fraction from the width the user dragged to, and
    -- set the window's raw Dimensions directly to that fraction of the base
    -- size (not reset back to base) -- this keeps the window's actual size
    -- and what the resize grip tracks for the next drag always in sync.
    -- SetScale is applied only to the separate "content" wrapper (title,
    -- pips, timer), never to the window itself, so it can't fight with the
    -- resize grip's own tracking of the window's raw dimensions -- the same
    -- lag bug fixed the same way in DarkConvergenceTracker.
    local scale = width / BASE_WIDTH
    scale = zo_clamp(scale, MIN_SCALE, MAX_SCALE)

    control:SetDimensions(BASE_WIDTH * scale, BASE_HEIGHT * scale)
    content:SetScale(scale)

    addon.positionVariables.scale = scale
end

local function ApplyLockState()
    local locked = addon.savedVariables.lockPosition
    window:SetMovable(not locked)
    window:SetMouseEnabled(not locked)
end

local function OnMoveStop()
    local isValid, point, _, relativePoint, offsetX, offsetY = window:GetAnchor(0)
    if not isValid then return end
    local pv = addon.positionVariables
    pv.point = point
    pv.relativePoint = relativePoint
    pv.offsetX = offsetX
    pv.offsetY = offsetY
end

--------------------------------------------------------------------------------
-- Settings panel (LibAddonMenu-2.0)
--------------------------------------------------------------------------------

function addon:InitializeSettings()
    local LAM = LibAddonMenu2

    local panelData = {
        type = "panel",
        name = "Blood Hunger Tracker",
        author = "Irreverend",
        version = ADDON_DISPLAY_VERSION,
        registerForRefresh = true,
    }

    local optionsData = {
        {
            type = "checkbox",
            name = "Enable Addon",
            tooltip = "Turn the Blood Hunger display on or off entirely.",
            getFunc = function() return addon.savedVariables.isEnabled end,
            setFunc = function(value)
                addon.savedVariables.isEnabled = value
                RefreshBloodHunger()
            end,
            default = defaults.isEnabled,
        },
        {
            type = "checkbox",
            name = "Only Show While Transformed",
            tooltip = "Hide the display whenever you are not in Werewolf form.",
            getFunc = function() return addon.savedVariables.onlyShowInForm end,
            setFunc = function(value)
                addon.savedVariables.onlyShowInForm = value
                RefreshBloodHunger()
            end,
            default = defaults.onlyShowInForm,
        },
        {
            type = "checkbox",
            name = "Hide window when no stacks",
            tooltip = "Hide the display whenever you have zero Blood Hunger stacks, even if you are transformed.",
            width = "full",
            getFunc = function() return addon.savedVariables.hideWhenNoStacks end,
            setFunc = function(value)
                addon.savedVariables.hideWhenNoStacks = value
                RefreshBloodHunger()
            end,
            default = defaults.hideWhenNoStacks,
        },
        {
            type = "checkbox",
            name = "Lock Position",
            tooltip = "Lock the display so it can no longer be dragged.",
            getFunc = function() return addon.savedVariables.lockPosition end,
            setFunc = function(value)
                addon.savedVariables.lockPosition = value
                ApplyLockState()
            end,
            default = defaults.lockPosition,
        },
        {
            type = "button",
            name = "Reset Position",
            tooltip = "Move the display back to the default screen position for this character.",
            func = function()
                local pv = addon.positionVariables
                pv.point = positionDefaults.point
                pv.relativePoint = positionDefaults.relativePoint
                pv.offsetX = positionDefaults.offsetX
                pv.offsetY = positionDefaults.offsetY
                ApplySavedPosition()
            end,
        },
        {
            type = "button",
            name = "Reset Size",
            tooltip = "Reset the display back to its default size for this character.",
            func = function()
                addon.positionVariables.scale = positionDefaults.scale
                ApplySavedScale()
            end,
        },
    }

    LAM:RegisterAddonPanel(ADDON_NAME .. "Options", panelData)
    LAM:RegisterOptionControls(ADDON_NAME .. "Options", optionsData)
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function OnAddonLoaded(eventCode, loadedAddonName)
    if loadedAddonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- Note: this used to be account-wide (intentionally not passing a "profile"
    -- argument, e.g. GetWorldName(), which per ZO_SavedVars' own source keeps
    -- data shared across NA/EU/PTS rather than split per server). Now switched
    -- to character-specific, matching positionVariables below, so every setting
    -- can be configured independently per character.
    addon.savedVariables = ZO_SavedVars:NewCharacterIdSettings("BloodHungerTrackerSavedVariables", ADDON_VERSION, nil, defaults)
    addon.positionVariables = ZO_SavedVars:NewCharacterIdSettings("BloodHungerTrackerPosition", ADDON_VERSION, nil, positionDefaults)
    addon.buffEndTime = 0

    window = BloodHungerTracker_Window
    content = BloodHungerTracker_WindowContent
    timerText = BloodHungerTracker_WindowContentTimerText
    pips[1] = BloodHungerTracker_WindowContentPip1
    pips[2] = BloodHungerTracker_WindowContentPip2
    pips[3] = BloodHungerTracker_WindowContentPip3
    pips[4] = BloodHungerTracker_WindowContentPip4

    ApplySavedPosition()
    ApplySavedScale()
    ApplyLockState()

    window:SetHandler("OnMoveStop", OnMoveStop)
    window:SetHandler("OnResizeStop", OnResizeStop)

    addon:InitializeSettings()

    for _, abilityId in ipairs(BLOOD_HUNGER_ABILITY_IDS) do
        local eventNamespace = ADDON_NAME .. "_EffectChanged_" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventNamespace, EVENT_EFFECT_CHANGED, OnEffectChanged)
        EVENT_MANAGER:AddFilterForEvent(eventNamespace, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_WEREWOLF_STATE_CHANGED, OnWerewolfStateChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    RefreshBloodHunger()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
