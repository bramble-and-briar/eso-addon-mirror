--[[
    Execute Blocker
    Author: O-Range
    Version: 2.4.0

    Prevents casting of execute abilities when the target's health is above
    a configurable threshold. Uses LibExecuteSkills for the core skill database.
    Supports Nightblade, Templar, Sorcerer, weapon skills, and Warden Guardians.

    Changes in 2.4.0:
    - Integrated LibExecuteSkills library
    - Skill data now primarily comes from the shared library
    - Only minimal local overrides remain (default thresholds, enabled state, special tooltips)
]]

local ExecuteBlocker = {}
ExecuteBlocker.name = "ExecuteBlocker"
ExecuteBlocker.version = "2.4.0"

-- Only override what the library does not provide
local SKILL_OVERRIDES = {
    -- Templar – slightly lower default thresholds than the pure execute %
    [63029] = { defaultThreshold = 40 },   -- Radiant Destruction
    [63044] = { defaultThreshold = 40 },   -- Radiant Oppression
    [63046] = { defaultThreshold = 40 },   -- Radiant Glory

    -- Dual Wield – Whirling Blades
    [38891] = {
        defaultEnabled = false,
        tooltip = "Disabled by default because Whirling Blades scales from all enemies hit rather than only your reticle target.",
    },

    -- Warden Guardians (ultimates)
    [85982] = {
        defaultEnabled = false,
        tooltip = "Disabled by default – these are ultimates; the real execute is the secondary activation after the bear is summoned. Blocking the ultimate prevents summoning the guardian when the target is above the threshold.",
    },
    [85986] = {
        defaultEnabled = false,
        tooltip = "Disabled by default – these are ultimates; the real execute is the secondary activation after the bear is summoned. Blocking the ultimate prevents summoning the guardian when the target is above the threshold.",
    },
    [85990] = {
        defaultEnabled = false,
        tooltip = "Disabled by default – these are ultimates; the real execute is the secondary activation after the bear is summoned. Blocking the ultimate prevents summoning the guardian when the target is above the threshold.",
    },
}

local SKILL_LIST = {}

local DEFAULTS = {
    masterEnabled     = true,
    blockWhenNoTarget = true,
    showFlash         = true,
    skills            = {},
}

local VALID_SLOTS = {
    [ACTION_BAR_FIRST_NORMAL_SLOT_INDEX]     = true,
    [ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1] = true,
    [ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 2] = true,
    [ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 3] = true,
    [ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 4] = true,
    [ACTION_BAR_ULTIMATE_SLOT_INDEX]        = true,
}

---------------------------------------------------------------------------
-- Build skill list from LibExecuteSkills + minimal overrides
---------------------------------------------------------------------------
local function BuildSkillList()
    SKILL_LIST = {}

    local lib = LibExecuteSkills
    if not lib then
        d("[Execute Blocker] LibExecuteSkills not found! Please install the library.")
        return
    end

    local allSkills = lib:GetAllSkills() or lib:GetExecuteSkillIds() or {}

    for id, data in pairs(allSkills) do
        local override = SKILL_OVERRIDES[id] or {}

        table.insert(SKILL_LIST, {
            id               = id,
            name             = string.format("%s: %s", data.class or "Unknown", data.name or ("Skill " .. tostring(id))),
            defaultEnabled   = override.defaultEnabled ~= false,   -- true unless explicitly set to false
            defaultThreshold = override.defaultThreshold or data.executePercent or 50,
            tooltip          = override.tooltip,
        })
    end

    -- Stable alphabetical order for the settings menu
    table.sort(SKILL_LIST, function(a, b)
        return a.name < b.name
    end)
end

---------------------------------------------------------------------------
-- Visual Flash Feedback
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
    bg:SetCenterColor(0.85, 0.15, 0.10, 0.35)
    bg:SetEdgeColor(0, 0, 0, 0)
    bg:SetEdgeTexture("", 1, 1, 0)
    bg:SetCenterTexture("")
    bg:SetAlpha(1)

    flashTimeline = ANIMATION_MANAGER:CreateTimeline()
    flashTimeline:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT)

    local fadeIn = flashTimeline:InsertAnimation(ANIMATION_ALPHA, flashControl, 0)
    fadeIn:SetAlphaValues(0, 1)
    fadeIn:SetDuration(60)

    local fadeOut = flashTimeline:InsertAnimation(ANIMATION_ALPHA, flashControl, 80)
    fadeOut:SetAlphaValues(1, 0)
    fadeOut:SetDuration(180)

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

    local abilityId = GetSlotBoundId(slotNum, hotbarCategory)
    if not abilityId or abilityId == 0 then
        return false
    end

    local skillConfig = ExecuteBlocker.savedVars.skills[abilityId]
    if not skillConfig or not skillConfig.enabled then
        return false
    end

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
    local function PreHookHandler(slotNum, hotbarCategory)
        if ShouldBlockSlot(slotNum, hotbarCategory) then
            PlayBlockFlash()
            return true
        end
    end

    ZO_PreHook("ZO_ActionBar_OnActionButtonDown", PreHookHandler)
    ZO_PreHook("ZO_ActionBar_OnActionButtonUp",   PreHookHandler)
end

---------------------------------------------------------------------------
-- Settings Menu
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
            tooltip = "Plays a quick soft red-orange fade-in/fade-out flash when an execute is blocked.",
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
            text = "Enable/disable individual skills and set the health percentage above which the ability is blocked.\nSkill database provided by LibExecuteSkills.",
        },
    }

    for _, skill in ipairs(SKILL_LIST) do
        local id = skill.id

        table.insert(optionsData, {
            type    = "checkbox",
            name    = skill.name,
            tooltip = skill.tooltip or "Enable or disable blocking for this skill.",
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

    -- Build skill list from LibExecuteSkills
    BuildSkillList()

    -- Create defaults from the built list
    for _, skill in ipairs(SKILL_LIST) do
        DEFAULTS.skills[skill.id] = {
            enabled   = skill.defaultEnabled,
            threshold = skill.defaultThreshold,
        }
    end

    ExecuteBlocker.savedVars = ZO_SavedVars:NewAccountWide(
        "ExecuteBlockerVars",
        4,          -- bumped for LibExecuteSkills integration
        nil,
        DEFAULTS
    )

    -- Safety for older saved variables
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