local CAE = CrutchAlertsExtensions
local Crutch = CrutchAlerts
CAE.AchievementDebug = {}
local Achieve = CAE.AchievementDebug

---------------------------------------------------------------------
local stalwart
local function StalwartSisterhood()
    if (stalwart) then
        stalwart = false
        CAE.msg("Stopping " .. GetAchievementLink(2310, LINK_STYLE_BRACKETS) .. " debug.")
        Crutch.UnregisterForEffectChanged("BearAura")
        Crutch.UnregisterForEffectChanged("StagAura")
        Crutch.UnregisterForEffectChanged("OwlAura")
    else
        stalwart = true
        CAE.msg("Starting " .. GetAchievementLink(2310, LINK_STYLE_BRACKETS) .. " debug. This will persist for this session only (does not stay on through reloads or relogs). You can use the command again to turn this off.")
        local auras = {
            [107466] = "boss1", -- Strigidae
            [108554] = "boss2", -- Rangifer
            [108556] = "boss3", -- Ursus
        }
        local function WyressAura(_, changeType, _, _, unitTag, _, _, _, _, _, _, _, _, _, _, abilityId)
            if (changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_FADED) then return end
            if (auras[abilityId] == unitTag) then return end -- Self aura
            CAE.msg(string.format("|c%s%s %s %s",
                (changeType == EFFECT_RESULT_GAINED) and "FF0000" or "882222",
                GetUnitName(unitTag),
                (changeType == EFFECT_RESULT_GAINED) and "gained" or "faded",
                GetAbilityName(abilityId)))
        end
        Crutch.RegisterForEffectChanged("BearAura", WyressAura, 108556, "boss")
        Crutch.RegisterForEffectChanged("StagAura", WyressAura, 108554, "boss")
        Crutch.RegisterForEffectChanged("OwlAura", WyressAura, 107466, "boss")
    end
end
Achieve.StalwartSisterhood = StalwartSisterhood
