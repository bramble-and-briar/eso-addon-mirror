local CAE = CrutchAlertsExtensions
local Crutch = CrutchAlerts


---------------------------------------------------------------------
-- DoM Scavenging Maw
---------------------------------------------------------------------
local function OnScavengingMawHide()
    Crutch.dbgOther("hiding boss bar")
    COMPASS_FRAME:SetBossBarHiddenForReason("CAEScavengingMawHide", true)
end

local function OnScavengingMawUnhide()
    Crutch.dbgOther("showing boss bar")
    COMPASS_FRAME:SetBossBarHiddenForReason("CAEScavengingMawHide", false)
end

local function UnregisterScavengingEvents()
    Crutch.UnregisterForCombatEvent("CAEScavengingMawHide")
    Crutch.UnregisterForCombatEvent("CAEScavengingMawDevour")
    Crutch.UnregisterExitedGroupCombatListener("CAEScavengingMawExitedCombat")
    OnScavengingMawUnhide()
end

-- Register events for Scavenging Maw only when in DoM
local function MaybeRegisterScavenging()
    if (GetZoneId(GetUnitZoneIndex("player")) == 1081) then
        Crutch.RegisterForCombatEvent("CAEScavengingMawHide", OnScavengingMawHide, ACTION_RESULT_BEGIN, 113923)
        Crutch.RegisterForCombatEvent("CAEScavengingMawDevour", OnScavengingMawUnhide, ACTION_RESULT_BEGIN, 113940)
        Crutch.RegisterExitedGroupCombatListener("CAEScavengingMawExitedCombat", OnScavengingMawUnhide)
    else
        UnregisterScavengingEvents()
    end
end


---------------------------------------------------------------------
---------------------------------------------------------------------
local function InitializeBossTriggers()
    local profile = CAE.profiles[CAE.csvs.currentProfile]

    if (profile.hideBossBarScavengingMaw) then
        EVENT_MANAGER:RegisterForEvent("CAEBossTriggersPlayerActivated", EVENT_PLAYER_ACTIVATED, MaybeRegisterScavenging)
        MaybeRegisterScavenging()
    else
        EVENT_MANAGER:UnregisterForEvent("CAEBossTriggersPlayerActivated", EVENT_PLAYER_ACTIVATED)
        UnregisterScavengingEvents()
    end
end
CAE.InitializeBossTriggers = InitializeBossTriggers


---------------------------------------------------------------------
---------------------------------------------------------------------
function CAE.GetBossTriggersSettings()
    return {
        {
            type = "description",
            title = "|c08BD1DSpecific Bosses|r",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Hide boss bar at the Scavenging Maw",
            tooltip = "Hides the base game boss health bar when the Scavenging Maw starts to hide in Depths of Malatar, so that the compass will be visible for identifying enemy location",
            default = false,
            getFunc = function() return CAE.profiles[CAE.csvs.currentProfile].hideBossBarScavengingMaw end,
            setFunc = function(value)
                CAE.profiles[CAE.csvs.currentProfile].hideBossBarScavengingMaw = value
                InitializeBossTriggers()
            end,
            width = "full",
        },
    }
end
