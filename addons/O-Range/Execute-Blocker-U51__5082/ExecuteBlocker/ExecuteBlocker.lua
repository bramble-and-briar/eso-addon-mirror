--[[
    Execute Blocker
    Author: O-Range
    Version: 2.6.0

    Prevents casting of execute abilities when the target's health
    is above a configurable threshold.

    Uses LibExecuteSkills for the skill database.
    Ranked ability IDs are resolved by name.
]]

local ADDON_NAME = "ExecuteBlocker"
local ADDON_VERSION = "2.6.0"

local ExecuteBlocker = {
    name    = ADDON_NAME,
    version = ADDON_VERSION,
}

---------------------------------------------------------------------------
-- Local overrides (only what the library does not provide)
---------------------------------------------------------------------------
local SKILL_OVERRIDES = {
    -- Templar – slightly lower defaults
    [63029] = { defaultThreshold = 40 }, -- Radiant Destruction
    [63044] = { defaultThreshold = 40 }, -- Radiant Oppression
    [63046] = { defaultThreshold = 40 }, -- Radiant Glory

    -- Dual Wield
    [38891] = {
        defaultEnabled = false,
        tooltip = "Disabled by default because Whirling Blades scales from all enemies hit rather than only your reticle target.",
    },

    -- Warden Guardians (ultimates)
    [85982] = {
        defaultEnabled = false,
        tooltip = "Disabled by default – these are ultimates; the real execute is the secondary activation after the bear is summoned.",
    },
    [85986] = {
        defaultEnabled = false,
        tooltip = "Disabled by default – these are ultimates; the real execute is the secondary activation after the bear is summoned.",
    },
    [85990] = {
        defaultEnabled = false,
        tooltip = "Disabled by default – these are ultimates; the real execute is the secondary activation after the bear is summoned.",
    },
}

---------------------------------------------------------------------------
-- Runtime data
---------------------------------------------------------------------------
local skillList   = {}   -- ordered list for the settings menu
local nameToId    = {}   -- ability name → canonical ID (handles ranked versions)
local defaults    = {
    masterEnabled     = true,
    blockWhenNoTarget = true,
    skills            = {},
}

---------------------------------------------------------------------------
-- Build skill list from LibExecuteSkills
---------------------------------------------------------------------------
local function BuildSkillList()
    skillList = {}
    nameToId  = {}

    local lib = LibExecuteSkills
    if not lib then
        d("[" .. ADDON_NAME .. "] LibExecuteSkills not found!")
        return
    end

    local allSkills = lib:GetAllSkills() or {}

    for id, data in pairs(allSkills) do
        local override = SKILL_OVERRIDES[id] or {}

        local entry = {
            id               = id,
            name             = string.format("%s: %s", data.class or "Unknown", data.name or ("Skill " .. tostring(id))),
            defaultEnabled   = override.defaultEnabled ~= false,
            defaultThreshold = override.defaultThreshold or data.executePercent or 50,
            tooltip          = override.tooltip,
        }

        table.insert(skillList, entry)

        if data.name and data.name ~= "" then
            nameToId[data.name] = id
        end
    end

    table.sort(skillList, function(a, b)
        return a.name < b.name
    end)
end

---------------------------------------------------------------------------
-- Resolve any ability ID (exact match or ranked version by name)
---------------------------------------------------------------------------
local function ResolveSkillConfig(abilityId)
    if not abilityId or abilityId == 0 then
        return nil
    end

    local sv = ExecuteBlocker.savedVars
    if not sv then return nil end

    -- Exact ID match
    local cfg = sv.skills[abilityId]
    if cfg then return cfg end

    -- Ranked abilities keep the same display name
    local name = GetAbilityName(abilityId)
    if name and name ~= "" then
        local canonicalId = nameToId[name]
        if canonicalId then
            return sv.skills[canonicalId]
        end
    end

    return nil
end

---------------------------------------------------------------------------
-- Core block decision
---------------------------------------------------------------------------
local function ShouldBlock(abilityId)
    local sv = ExecuteBlocker.savedVars
    if not sv or not sv.masterEnabled then
        return false
    end

    local cfg = ResolveSkillConfig(abilityId)
    if not cfg or not cfg.enabled then
        return false
    end

    -- No valid hostile target
    if not DoesUnitExist("reticleover") or IsUnitDead("reticleover") then
        return sv.blockWhenNoTarget
    end

    if GetUnitReaction("reticleover") ~= UNIT_REACTION_HOSTILE then
        return sv.blockWhenNoTarget
    end

    local currentHP, _, effectiveMaxHP = GetUnitPower("reticleover", POWERTYPE_HEALTH)
    if not effectiveMaxHP or effectiveMaxHP <= 0 then
        return false
    end

    local hpPercent = (currentHP / effectiveMaxHP) * 100
    return hpPercent > cfg.threshold
end

---------------------------------------------------------------------------
-- Hook (same reliable path used by simple working blockers)
---------------------------------------------------------------------------
local function SetupHooks()
    ZO_PreHook("ZO_ActionBar_CanUseActionSlots", function()
        local slotNum = tonumber(debug.traceback():match("ACTION_BUTTON_(%d)"))
        if not slotNum then
            return false
        end

        local abilityId = GetSlotBoundId(slotNum)
        if not abilityId or abilityId == 0 then
            return false
        end

        if ShouldBlock(abilityId) then
            return true -- block the cast
        end

        return false
    end)
end

---------------------------------------------------------------------------
-- Settings menu
---------------------------------------------------------------------------
local function BuildSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type                = "panel",
        name                = "Execute Blocker",
        displayName         = "Execute Blocker",
        author              = "O-Range",
        version             = ADDON_VERSION,
        registerForRefresh  = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type    = "checkbox",
            name    = "Master Enable / Disable",
            tooltip = "Globally enables or disables Execute Blocker.",
            getFunc = function() return ExecuteBlocker.savedVars.masterEnabled end,
            setFunc = function(value) ExecuteBlocker.savedVars.masterEnabled = value end,
            default = defaults.masterEnabled,
        },
        {
            type    = "checkbox",
            name    = "Block Without Hostile Target",
            tooltip = "Blocks execute abilities when not aiming at a living hostile enemy.",
            getFunc = function() return ExecuteBlocker.savedVars.blockWhenNoTarget end,
            setFunc = function(value) ExecuteBlocker.savedVars.blockWhenNoTarget = value end,
            disabled = function() return not ExecuteBlocker.savedVars.masterEnabled end,
            default = defaults.blockWhenNoTarget,
        },
        {
            type = "header",
            name = "Skill Settings",
        },
        {
            type = "description",
            text = "Enable/disable individual skills and set the health percentage above which the ability is blocked.\nSkill data provided by LibExecuteSkills. Ranked versions are detected automatically.",
        },
    }

    for _, skill in ipairs(skillList) do
        local id = skill.id

        table.insert(optionsData, {
            type    = "checkbox",
            name    = skill.name,
            tooltip = skill.tooltip or "Enable or disable blocking for this skill.",
            getFunc = function() return ExecuteBlocker.savedVars.skills[id].enabled end,
            setFunc = function(value) ExecuteBlocker.savedVars.skills[id].enabled = value end,
            disabled = function() return not ExecuteBlocker.savedVars.masterEnabled end,
            default = skill.defaultEnabled,
        })

        table.insert(optionsData, {
            type    = "slider",
            name    = "Threshold %  (" .. skill.name .. ")",
            tooltip = "Block this ability while target health is above this percentage.",
            min     = 5,
            max     = 100,
            step    = 1,
            getFunc = function() return ExecuteBlocker.savedVars.skills[id].threshold end,
            setFunc = function(value) ExecuteBlocker.savedVars.skills[id].threshold = value end,
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
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    BuildSkillList()

    -- Build defaults from the skill list
    for _, skill in ipairs(skillList) do
        defaults.skills[skill.id] = {
            enabled   = skill.defaultEnabled,
            threshold = skill.defaultThreshold,
        }
    end

    ExecuteBlocker.savedVars = ZO_SavedVars:NewAccountWide(
        "ExecuteBlockerVars",
        6,
        nil,
        defaults
    )

    SetupHooks()
    BuildSettingsMenu()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)