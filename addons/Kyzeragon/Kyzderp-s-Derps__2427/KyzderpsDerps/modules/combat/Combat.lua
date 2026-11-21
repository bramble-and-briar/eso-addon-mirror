local KD = KyzderpsDerps
KD.Combat = {}
local KDC = KD.Combat

local function OnPlayerActivated()
    if (KD.savedOptions.combat.satiateHunger) then
        KD:dbg("setting priority for insatiable hunger")
        SetSynergyPriorityOverride(33208, 10)
    end
end

function KDC.Initialize()
    EVENT_MANAGER:RegisterForEvent(KD.name .. "CombatActivated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    KDC.PlayerStats.Initialize()
end

function KDC.GetSettings()
    local settings = {
        {
            type = "checkbox",
            name = "Automatic repair kit",
            tooltip = "Automatically use a repair kit to repair gear that drops to 1% durability",
            default = true,
            getFunc = function() return KyzderpsDerps.savedOptions.misc.repair end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.misc.repair = value
                KyzderpsDerps.AutoRepair.Initialize()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Lower Insatiable Hunger priority",
            tooltip = "Sets werewolf's Insatiable Hunger synergy priority to 10, meaning it's lower priority than other default synergy priorities, so you stop randomly devouring corpses when you just want your damage buff. This should NOT be used alongside other synergy priority addons!",
            default = false,
            getFunc = function() return KD.savedOptions.combat.satiateHunger end,
            setFunc = function(value)
                    KyzderpsDerps.savedOptions.combat.satiateHunger = value
                    if (value) then
                        OnPlayerActivated()
                    else
                        ClearSynergyPriorityOverride(33208)
                    end
                end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Print Onslaught penetration",
            tooltip = "For 10 seconds after you hit something with Onslaught, prints changes in your Physical Penetration player stat. Works only for Onslaught IV",
            default = false,
            getFunc = function() return KyzderpsDerps.savedOptions.combat.printOnslaught end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.combat.printOnslaught = value
                KDC.PlayerStats.Initialize()
            end,
            width = "full",
        },
    }

    for _, setting in ipairs(KyzderpsDerps.ScoreFormat.GetSettings()) do
        table.insert(settings, setting)
    end

    return settings
end
