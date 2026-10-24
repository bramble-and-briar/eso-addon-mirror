local CAE = CrutchAlertsExtensions
local Crutch = CrutchAlerts


---------------------------------------------------------------------
-- Hook synergy change to hide if synergy is Insatiable Hunger and
-- the modifier key is not held
local HUNGER_ID = 33208
local HUNGER_TEXTURE = GetAbilityIcon(HUNGER_ID)
local modifyDown = false
local origOnSynergyAbilityChanged

local hintUI

local function ShouldRequireModifier()
    return CAE.profiles[CAE.csvs.currentProfile].hungerRequireModifier and not IsInGamepadPreferredMode()
end

local function MyOnSynergyChanged(self)
    local hasSynergy, _, iconFilename = GetCurrentSynergyInfo()
    if (ShouldRequireModifier()
        and hasSynergy
        and iconFilename == HUNGER_TEXTURE
        and not modifyDown) then
        SHARED_INFORMATION_AREA:SetHidden(self, true)
        if (hintUI) then
            hintUI:SetHidden(false)
        end
    else
        if (hintUI) then -- might not be initialized if starting in gamepad mode
            hintUI:SetHidden(true)
            origOnSynergyAbilityChanged(self)
        end
    end
end

local hooked = false
local function HookSynergy()
    if (not ShouldRequireModifier()) then return end
    if (hooked) then return end
    hooked = true
    origOnSynergyAbilityChanged = SYNERGY.OnSynergyAbilityChanged
    SYNERGY.OnSynergyAbilityChanged = MyOnSynergyChanged

    hintUI = WINDOW_MANAGER:CreateControlFromVirtual(
        "CAEWWSynergy",
        CrutchAlertsExtensionsContainer,
        "CAEWWSynergy_Template",
        "")
    MyOnSynergyChanged(SYNERGY)
    -- hintUI:SetAnchor(CENTER, ZO_SynergyTopLevelContainer, CENTER)
end

-- Custom keybind, refresh synergy when modifier changes too
function CAE.ModifyKeyDown()
    modifyDown = true
    if (not ShouldRequireModifier()) then return end
    MyOnSynergyChanged(SYNERGY)
end

function CAE.ModifyKeyUp()
    modifyDown = false
    if (not ShouldRequireModifier()) then return end
    MyOnSynergyChanged(SYNERGY)
end


---------------------------------------------------------------------
local FRENZY_ID = 58775
local CHARGED_LIGHTNING_ID = 48076

local function OnPlayerActivated()
    local profile = CAE.profiles[CAE.csvs.currentProfile]
    if (profile.lowerHunger) then
        Crutch.dbgSpam("setting priority 10 for insatiable hunger")
        SetSynergyPriorityOverride(HUNGER_ID, 10)
    end

    if (profile.higherFrenzyAndAtro) then
        local frenzyPriority = profile.evenHigherFrenzy and 6 or 7
        Crutch.dbgSpam(string.format("setting priority %d for feeding frenzy and 7 for charged lightning", frenzyPriority))
        SetSynergyPriorityOverride(FRENZY_ID, frenzyPriority)
        SetSynergyPriorityOverride(CHARGED_LIGHTNING_ID, 7)
    end
end


---------------------------------------------------------------------
local function InitializeSynergy()
    HookSynergy()

    EVENT_MANAGER:UnregisterForEvent(CAE.name .. "SynPlayerActivated", EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:RegisterForEvent(CAE.name .. "SynPlayerActivated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    -- Since we're not doing the modifier key in gamepad mode, the hook doesn't get initialized when starting
    -- in gamepad. Need to listen for mode change and initialize hook if user changes to M+KB later.
    EVENT_MANAGER:UnregisterForEvent(CAE.name .. "SynGamepadChanged", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED)
    EVENT_MANAGER:RegisterForEvent(CAE.name .. "SynGamepadChanged", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, HookSynergy)
end
CAE.InitializeSynergy = InitializeSynergy



---------------------------------------------------------------------
function CAE.GetSynergySettings()
    return {
        {
            type = "description",
            title = "|c08BD1DSynergy Tools|r",
            text = "Some dedicated options for synergies. For advanced synergy blocking and priority configuration, use a dedicated addon instead.",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Modifier keybind for Insatiable Hunger",
            tooltip = "As a werewolf, requires you to hold another key to make the Insatiable Hunger synergy usable. Other synergies are unaffected. This prevents accidental corpse-eating but still gives you the choice to activate it deliberately. Set your keybind in the controls menu to use this. Does not apply to gamepad mode, since it already has very few keys available",
            default = false,
            getFunc = function() return CAE.profiles[CAE.csvs.currentProfile].hungerRequireModifier end,
            setFunc = function(value)
                CAE.profiles[CAE.csvs.currentProfile].hungerRequireModifier = value
                InitializeSynergy()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Lower Insatiable Hunger priority",
            tooltip = "Sets werewolf's Insatiable Hunger synergy priority to 10, meaning it's lower priority than other default synergy priorities",
            default = false,
            getFunc = function() return CAE.profiles[CAE.csvs.currentProfile].lowerHunger end,
            setFunc = function(value)
                CAE.profiles[CAE.csvs.currentProfile].lowerHunger = value
                if (value) then
                    OnPlayerActivated()
                else
                    ClearSynergyPriorityOverride(HUNGER_ID)
                end
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Higher Feeding Frenzy / Charged Lightning priority",
            tooltip = "Sets Feeding Frenzy and Charged Lightning synergy priorities to 7, meaning it's the same priority as the defaults for Healing Combustion, Purify, etc.",
            default = false,
            getFunc = function() return CAE.profiles[CAE.csvs.currentProfile].higherFrenzyAndAtro end,
            setFunc = function(value)
                CAE.profiles[CAE.csvs.currentProfile].higherFrenzyAndAtro = value
                if (value) then
                    OnPlayerActivated()
                else
                    ClearSynergyPriorityOverride(FRENZY_ID)
                    ClearSynergyPriorityOverride(CHARGED_LIGHTNING_ID)
                end
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "    Even higher Feeding Frenzy priority",
            tooltip = "Sets Feeding Frenzy synergy priority to 6, meaning it's even higher priority than the defaults for Healing Combustion, Purify, etc.",
            default = false,
            getFunc = function() return CAE.profiles[CAE.csvs.currentProfile].evenHigherFrenzy end,
            setFunc = function(value)
                CAE.profiles[CAE.csvs.currentProfile].evenHigherFrenzy = value
                if (value) then
                    OnPlayerActivated()
                else
                    ClearSynergyPriorityOverride(FRENZY_ID)
                    ClearSynergyPriorityOverride(CHARGED_LIGHTNING_ID)
                end
            end,
            width = "full",
            disabled = function() return not CAE.profiles[CAE.csvs.currentProfile].higherFrenzyAndAtro end,
        },
    }
end
