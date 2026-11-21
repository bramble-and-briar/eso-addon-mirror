--[[
    Execute Blocker
    Author: O-Range
    Version: 2.3.0

    Prevents casting of execute abilities when the target's health is above
    a configurable threshold. Supports Nightblade, Templar, Sorcerer,
    weapon skills, and Warden Guardians.

    Changes in 2.3.0:
    - Fixed hotbarCategory handling for GetSlotBoundId (front/back bar correctness)
    - Added fast fade-in / fade-out visual flash feedback when an execute is blocked
    - Author consistently set to O-Range
    - Improved settings organization and tooltips
    - Cleaner code structure and comments
]]

local ExecuteBlocker = {}
ExecuteBlocker.name = "ExecuteBlocker"
ExecuteBlocker.version = "2.3.0"

-- Ordered list of all managed execute skills for the Settings Menu
local SKILL_LIST = {
    -- Nightblade
    { id = 33386, name = "Nightblade: Assassin's Blade", defaultEnabled = true,  defaultThreshold = 25 },
    { id = 34843, name = "Nightblade: Killer's Blade",   defaultEnabled = true,  defaultThreshold = 50 },
    { id = 34851, name = "Nightblade: Impale",           defaultEnabled = true,  defaultThreshold = 25 },

    -- Templar
    { id = 63029, name = "Templar: Radiant Destruction", defaultEnabled = true,  defaultThreshold = 40 },
    { id = 63044, name = "Templar: Radiant Oppression",  defaultEnabled = true,  defaultThreshold = 40 },
    { id = 63046, name = "Templar: Radiant Glory",       defaultEnabled = true,  defaultThreshold = 40 },

    -- Sorcerer
    { id = 18718, name = "Sorcerer: Mages' Fury",        defaultEnabled = true,  defaultThreshold = 20 },
    { id = 19123, name = "Sorcerer: Mages' Wrath",       defaultEnabled = true,  defaultThreshold = 20 },
    { id = 19109, name = "Sorcerer: Endless Fury",       defaultEnabled = true,  defaultThreshold = 20 },

    -- Two-Handed
    { id = 28279, name = "2H: Reverse Slash",            defaultEnabled = true,  defaultThreshold = 50 },
    { id = 38814, name = "2H: Executioner",              defaultEnabled = true,  defaultThreshold = 50 },
    { id = 38807, name = "2H: Reverse Slice",            defaultEnabled = true,  defaultThreshold = 50 },

    -- Dual Wield
    { id = 28591, name = "Dual Wield: Whirlwind",        defaultEnabled = true,  defaultThreshold = 50 },
    { id = 38891, name = "Dual Wield: Whirling Blades",  defaultEnabled = false, defaultThreshold = 50 },
    { id = 38861, name = "Dual Wield: Steel Tornado",    defaultEnabled = true,  defaultThreshold = 50 },

    -- Bow
    { id = 38660, name = "Bow: Poison Injection",        defaultEnabled = true,  defaultThreshold = 50 },

    -- Warden (Animal Companions ultimates – disabled by default)
    -- Note: The true execute is the secondary activation (Guardian's Wrath / Savagery)
    -- after the bear is summoned. Blocking the ultimate itself prevents summoning
    -- when the target is above threshold.
    { id = 85982, name = "Warden: Feral Guardian",       defaultEnabled = false, defaultThreshold = 25 },
    { id = 85986, name = "Warden: Eternal Guardian",     defaultEnabled = false, defaultThreshold = 25 },
    { id = 85990, name = "Warden: Wild Guardian",        defaultEnabled = false, defaultThreshold = 25 },
}

local DEFAULTS = {
    masterEnabled     = true,
    blockWhenNoTarget = true,
    showFlash         = true,   -- visual feedback when blocked
    skills            = {},
}

for _, skill in ipairs(SKILL_LIST) do
    DEFAULTS.skills[skill.id] = {
        enabled   = skill.defaultEnabled,
        threshold = skill.defaultThreshold,
    }
end

local VALID_SLOTS = {
    [ACTION_BAR_FIRST_NORMAL_SLOT_INDEX]     = true,
    [ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1] = true,
    [ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 2] = true,
    [ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 3] = true,
    [ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 4] = true,
    [ACTION_BAR_ULTIMATE_SLOT_INDEX]        = true,
}

---------------------------------------------------------------------------
-- Visual Flash Feedback (fast fade-in / fade-out)
---------------------------------------------------------------------------
local flashControl = nil
local flashTimeline = nil

local function CreateFlashControl()
    if flashControl then return end

    flashControl = WINDOW_MANAGER:CreateTopLevelControl("ExecuteBlockerFlash", GuiRoot)
    flashControl:SetAnchorFill(GuiRoot)
    flashControl:SetDrawLayer(DL_OVERLAY)
    flashControl:SetDrawTier(DT_HIGH)
    flashControl:SetMouseEnabled(false)
    flashControl:SetHidden(true)
    flashControl:SetAlpha(0)

    local bg = WINDOW_MANAGER:CreateControl("$(parent)Bg", flashControl, CT_BACKDROP)
    bg:SetAnchorFill(flashControl)
    bg:SetCenterColor(0.85, 0.15, 0.10, 0.35)   -- soft red-orange, low opacity
    bg:SetEdgeColor(0, 0, 0, 0)
    bg:SetEdgeTexture("", 1, 1, 0)
    bg:SetCenterTexture("")
    bg:SetAlpha(1)

    -- Animation timeline: quick fade in → hold briefly → fade out
    flashTimeline = ANIMATION_MANAGER:CreateTimeline()
    flashTimeline:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT)

    local fadeIn = flashTimeline:InsertAnimation(ANIMATION_ALPHA, flashControl, 0)
    fadeIn:SetAlphaValues(0, 1)
    fadeIn:SetDuration(60)          -- very fast in

    local fadeOut = flashTimeline:InsertAnimation(ANIMATION_ALPHA, flashControl, 80)
    fadeOut:SetAlphaValues(1, 0)
    fadeOut:SetDuration(180)        -- slightly longer out for smooth feel

    flashTimeline:SetHandler("OnStop", function()
        flashControl:SetHidden(true)
        flashControl:SetAlpha(0)
    end)
end

local function PlayBlockFlash()
    if not ExecuteBlocker.savedVars or not ExecuteBlocker.savedVars.showFlash then
        return
    end

    CreateFlashControl()

    if flashTimeline:IsPlaying() then
        flashTimeline:Stop()
    end

    flashControl:SetHidden(false)
    flashControl:SetAlpha(0)
    flashTimeline:PlayFromStart()
end

---------------------------------------------------------------------------
-- Core Logic
---------------------------------------------------------------------------
local function ShouldBlockSlot(slotNum, hotbarCategory)
    if not ExecuteBlocker.savedVars then
        return false
    end

    if not ExecuteBlocker.savedVars.masterEnabled then
        return false
    end

    if not VALID_SLOTS[slotNum] then
        return false
    end

    -- Critical: pass hotbarCategory so front/back bar (and other categories) are correct
    local abilityId = GetSlotBoundId(slotNum, hotbarCategory)
    if not abilityId or abilityId == 0 then
        return false
    end

    local skillConfig = ExecuteBlocker.savedVars.skills[abilityId]
    if not skillConfig or not skillConfig.enabled then
        return false
    end

    -- No living hostile target → respect blockWhenNoTarget
    if not DoesUnitExist("reticleover") or IsUnitDead("reticleover") then
        return ExecuteBlocker.savedVars.blockWhenNoTarget
    end

    local reaction = GetUnitReaction("reticleover")
    if reaction ~= UNIT_REACTION_HOSTILE then
        return ExecuteBlocker.savedVars.blockWhenNoTarget
    end

    local currentHP, _, effectiveMaxHP = GetUnitPower("reticleover", POWERTYPE_HEALTH)
    if not effectiveMaxHP or effectiveMaxHP <= 0 then
        return false
    end

    local hpPercent = (currentHP / effectiveMaxHP) * 100
    return hpPercent > skillConfig.threshold
end

local function SetupHooks()
    -- Return true from the pre-hook to suppress the original function
    local function PreHookHandler(slotNum, hotbarCategory)
        if ShouldBlockSlot(slotNum, hotbarCategory) then
            PlayBlockFlash()
            return true
        end
    end

    -- Cover both press and release (keybinds, mouse, most gamepad paths)
    ZO_PreHook("ZO_ActionBar_OnActionButtonDown", PreHookHandler)
    ZO_PreHook("ZO_ActionBar_OnActionButtonUp",   PreHookHandler)
end

---------------------------------------------------------------------------
-- Settings Menu (LibAddonMenu-2.0)
---------------------------------------------------------------------------
local function BuildSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type                = "panel",
        name                = "Execute Blocker",
        displayName         = "Execute Blocker",
        author              = "O-Range",
        version             = ExecuteBlocker.version,
        registerForRefresh  = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type    = "checkbox",
            name    = "Master Enable / Disable",
            tooltip = "Globally enables or disables Execute Blocker.",
            getFunc = function()
                return ExecuteBlocker.savedVars.masterEnabled
            end,
            setFunc = function(val)
                ExecuteBlocker.savedVars.masterEnabled = val
            end,
            default = DEFAULTS.masterEnabled,
        },
        {
            type    = "checkbox",
            name    = "Block Without Hostile Target",
            tooltip = "Blocks execute abilities when not aiming at a living hostile enemy.",
            getFunc = function()
                return ExecuteBlocker.savedVars.blockWhenNoTarget
            end,
            setFunc = function(val)
                ExecuteBlocker.savedVars.blockWhenNoTarget = val
            end,
            disabled = function()
                return not ExecuteBlocker.savedVars.masterEnabled
            end,
            default = DEFAULTS.blockWhenNoTarget,
        },
        {
            type    = "checkbox",
            name    = "Show Block Flash",
            tooltip = "Plays a quick soft red-orange fade-in/fade-out flash when an execute is blocked. Non-intrusive visual feedback.",
            getFunc = function()
                return ExecuteBlocker.savedVars.showFlash
            end,
            setFunc = function(val)
                ExecuteBlocker.savedVars.showFlash = val
            end,
            disabled = function()
                return not ExecuteBlocker.savedVars.masterEnabled
            end,
            default = DEFAULTS.showFlash,
        },
        {
            type = "header",
            name = "Skill Settings",
        },
        {
            type = "description",
            text = "Enable/disable individual skills and set the health percentage above which the ability is blocked. Threshold is checked against the reticle target.",
        },
    }

    for _, skill in ipairs(SKILL_LIST) do
        local id = skill.id

        table.insert(optionsData, {
            type    = "checkbox",
            name    = skill.name,
            tooltip = (id == 38891)
                and "Disabled by default because Whirling Blades scales from all enemies hit rather than only your reticle target."
                or (id == 85982 or id == 85986 or id == 85990)
                and "Disabled by default – these are ultimates; the real execute is the secondary activation after the bear is summoned. Blocking the ultimate prevents summoning the guardian when the target is above the threshold."
                or "Enable or disable blocking for this skill.",
            getFunc = function()
                return ExecuteBlocker.savedVars.skills[id].enabled
            end,
            setFunc = function(val)
                ExecuteBlocker.savedVars.skills[id].enabled = val
            end,
            disabled = function()
                return not ExecuteBlocker.savedVars.masterEnabled
            end,
            default = skill.defaultEnabled,
        })

        table.insert(optionsData, {
            type    = "slider",
            name    = "Threshold %  (" .. skill.name .. ")",
            tooltip = "Block this ability while target health is above this percentage.",
            min     = 5,
            max     = 100,
            step    = 1,
            getFunc = function()
                return ExecuteBlocker.savedVars.skills[id].threshold
            end,
            setFunc = function(val)
                ExecuteBlocker.savedVars.skills[id].threshold = val
            end,
            disabled = function()
                return not ExecuteBlocker.savedVars.masterEnabled
                    or not ExecuteBlocker.savedVars.skills[id].enabled
            end,
            default = skill.defaultThreshold,
        })
    end

    LAM:RegisterAddonPanel("ExecuteBlockerSettingsPanel", panelData)
    LAM:RegisterOptionControls("ExecuteBlockerSettingsPanel", optionsData)
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
local function OnAddOnLoaded(_, addonName)
    if addonName ~= ExecuteBlocker.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ExecuteBlocker.name, EVENT_ADD_ON_LOADED)

    ExecuteBlocker.savedVars = ZO_SavedVars:NewAccountWide(
        "ExecuteBlockerVars",
        3,          -- bumped for showFlash + structure cleanup
        nil,
        DEFAULTS
    )

    -- Ensure newer defaults exist for players upgrading from older versions
    if ExecuteBlocker.savedVars.showFlash == nil then
        ExecuteBlocker.savedVars.showFlash = DEFAULTS.showFlash
    end

    SetupHooks()
    BuildSettingsMenu()
end

EVENT_MANAGER:RegisterForEvent(
    ExecuteBlocker.name,
    EVENT_ADD_ON_LOADED,
    OnAddOnLoaded
)
