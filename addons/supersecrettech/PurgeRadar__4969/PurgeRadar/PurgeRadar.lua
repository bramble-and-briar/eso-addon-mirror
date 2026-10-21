-- ============================================================================
-- PurgeRadar 1.5.1
-- Group purge / heal-check radar for Elder Scrolls Online
-- ============================================================================

local EVENT_MANAGER = EVENT_MANAGER
local WINDOW_MANAGER = WINDOW_MANAGER
local CENTER_SCREEN_ANNOUNCE = CENTER_SCREEN_ANNOUNCE
local IsUnitOnline = IsUnitOnline
local IsUnitInGroupZone = IsUnitInGroupZone
local IsUnitInCastRange = IsUnitInCastRange
local PlaySound = PlaySound
local ZO_CachedStrFormat = ZO_CachedStrFormat
local pairs = pairs
local ipairs = ipairs
local next = next
local type = type
local tostring = tostring
local table_sort = table.sort
local GetGroupMemberSelectedRole = GetGroupMemberSelectedRole
local GetUnitZone = GetUnitZone
local IsUnitGrouped = IsUnitGrouped

-- Fully local table (ESOUI best practice – no global pollution)
local PurgeRadar = {}
PurgeRadar.name = "PurgeRadar"
PurgeRadar.version = "1.5.1"
PurgeRadar.variableVersion = 2

-- Alert categories
local ALERT_PURGE      = 1  -- Must be purged/cleansed
local ALERT_HEAL       = 2  -- Cannot be purged – heal through
local ALERT_HEAL_RANGE = 3  -- Heal-check; range critical; tanks excluded

-- LFG roles
local ROLE_DPS  = LFG_ROLE_DPS
local ROLE_TANK = LFG_ROLE_TANK
local ROLE_HEAL = LFG_ROLE_HEAL

-- Reference ability for purge range (~28m)
local PURGE_SPELL_ID = 22265

-- Display names for settings toggles
local AbilityDisplayNames = {
    [27748]  = "Spindleclutch II: Enervating Seal",
    [84221]  = "Cradle of Shadows: Sickening Poison (Vet)",
    [84222]  = "Cradle of Shadows: Sickening Poison (Normal)",
    [84224]  = "Cradle of Shadows: Delirium Poison (Normal)",
    [84225]  = "Cradle of Shadows: Delirium Poison (Vet)",
    [84227]  = "Cradle of Shadows: Enfeebling Poison (Vet)",
    [84228]  = "Cradle of Shadows: Enfeebling Poison (Normal)",
    [73244]  = "Maw of Lorkhaj: Ruthless Salvo Bleed",
    [73807]  = "Maw of Lorkhaj: Lunar Flare (Rage of S'Kinrai)",
    [75738]  = "Maw of Lorkhaj: Lunar Flare (S'kinrai)",
    [87741]  = "Halls of Fabrication: Shattered",
    [90409]  = "Halls of Fabrication: Melting Point",
    [90698]  = "Halls of Fabrication: Phlebotomize",
    [90854]  = "Halls of Fabrication: Gaping Wound",
    [93669]  = "Halls of Fabrication: Greater Defile",
    [95230]  = "Halls of Fabrication: Venom Injection",
    [95430]  = "Asylum Sanctorium: Overheated",
    [96315]  = "Asylum Sanctorium: Defiled",
    [101101] = "Asylum Sanctorium: Trial by Fire",
    [109992] = "Blackrose Prison: Poisonbloom",
    [113150] = "Blackrose Prison: Arrow Spray Poison",
    [123662] = "Sunspire: Storm Bound",
    [126417] = "Moongrave Fane: Drain Vitality",
    [123210] = "Lair of Maarselok: Azure Blaze",
    [124441] = "Lair of Maarselok: Spit",
    [126595] = "Lair of Maarselok: Blight Burst",
    [126700] = "Lair of Maarselok: Dark Talons",
    [116584] = "Sunspire: Frigid Cold / Frozen Tomb",
    [183790] = "Sanity's Edge: Frost Bomb",
    [185399] = "Sanity's Edge: Frost Bomb (related)",
    [181234] = "Scrivener's Hall: Blood Boil (Oazan HM)",
    [185456] = "Exiled Redoubt: Deafening Gaze Condemn",
    [190789] = "Lep Seclusa: Wild Sports DoT",
    [101234] = "Fang Lair: Cadaverous Infection (Bear Stack)",
    [112345] = "March of Sacrifices: Strangler Poison",
    [45678]  = "Sanctum Ophidia: Shattered (Armor Fracture)",
    [142345] = "Kyne's Aegis: Frostbite Bleed",
    [100001] = "Lucent Citadel: Hindered (Orphic Mirror)",
    [233997] = "Ossein Cage: Disease Leak",
}

local COLOR_PRESETS = {
    { name = "Green (in-range purge)",      r = 0.20, g = 1.00, b = 0.40, a = 1 },
    { name = "Orange (out-of-range purge)", r = 0.80, g = 0.40, b = 0.00, a = 1 },
    { name = "Cyan (heal in-range)",        r = 0.20, g = 0.60, b = 1.00, a = 1 },
    { name = "Purple (heal out-of-range)",  r = 0.60, g = 0.00, b = 0.80, a = 1 },
    { name = "Blue (Ice Tomb / heal)",      r = 0.00, g = 0.40, b = 1.00, a = 1 },
    { name = "Red",                         r = 1.00, g = 0.15, b = 0.15, a = 1 },
    { name = "Yellow",                      r = 1.00, g = 0.90, b = 0.20, a = 1 },
    { name = "White",                       r = 1.00, g = 1.00, b = 1.00, a = 1 },
    { name = "Magenta",                     r = 1.00, g = 0.20, b = 0.80, a = 1 },
}

local function ColorPresetChoices()
    local names = {}
    for i = 1, #COLOR_PRESETS do
        names[i] = COLOR_PRESETS[i].name
    end
    return names
end

local function ColorFromPresetIndex(index)
    local p = COLOR_PRESETS[index] or COLOR_PRESETS[1]
    return { p.r, p.g, p.b, p.a }
end

PurgeRadar.defaultSettings = {
    enableSound = true,
    soundVolume = 3,
    enableZoneWarning = true,
    enableScreenAlerts = true,
    enableFloatingIcons = true,
    enableOneFrameColors = true,
    purgeInRangeColor  = 1,
    purgeOutRangeColor = 2,
    healInRangeColor   = 3,
    healOutRangeColor  = 4,
    healIconColor      = 5,
    enabledAbilities = {},
}

local PurgeableTrialAbilities = {
    [27748] = ALERT_PURGE,
    [84221] = ALERT_PURGE,
    [84222] = ALERT_PURGE,
    [84224] = ALERT_PURGE,
    [84225] = ALERT_PURGE,
    [84227] = ALERT_PURGE,
    [84228] = ALERT_PURGE,
    [73244] = ALERT_PURGE,
    [73807] = ALERT_PURGE,
    [75738] = ALERT_PURGE,
    [87741] = ALERT_PURGE,
    [90409] = ALERT_PURGE,
    [90698] = ALERT_PURGE,
    [90854] = ALERT_PURGE,
    [93669] = ALERT_PURGE,
    [95230] = ALERT_PURGE,
    [95430] = ALERT_PURGE,
    [96315] = ALERT_PURGE,
    [101101] = ALERT_PURGE,
    [109992] = ALERT_PURGE,
    [113150] = ALERT_PURGE,
    [123662] = ALERT_PURGE,
    [126417] = ALERT_PURGE,
    [123210] = ALERT_PURGE,
    [124441] = ALERT_PURGE,
    [126595] = ALERT_PURGE,
    [126700] = ALERT_PURGE,
    [116584] = ALERT_HEAL,
    [183790] = ALERT_HEAL,
    [185399] = ALERT_HEAL,
    [181234] = ALERT_HEAL,
    [185456] = ALERT_HEAL,
    [190789] = ALERT_HEAL,
    [101234] = ALERT_HEAL,
    [112345] = ALERT_HEAL,
    [45678]  = ALERT_HEAL,
    [142345] = ALERT_HEAL,
    [100001] = ALERT_HEAL,
    [233997] = ALERT_HEAL_RANGE,
}

local ZonesWithDeadlyPurgeableDots = {
    ["spindleclutch ii"] = true,
    ["cradle of shadows"] = true,
    ["maw of lorkhaj"] = true,
    ["halls of fabrication"] = true,
    ["asylum sanctorium"] = true,
    ["blackrose prison"] = true,
    ["sunspire"] = true,
    ["moongrave fane"] = true,
    ["lair of maarselok"] = true,
}

local activePurges = {}
local isTrackingRanges = false
local lastWarnedZone = nil

local function IsAbilityEnabled(abilityId)
    local map = PurgeRadar.settings and PurgeRadar.settings.enabledAbilities
    if not map then return true end
    local v = map[abilityId]
    if v == nil then return true end
    return v and true or false
end

local function GetPlayerRole()
    if not IsUnitGrouped("player") then return nil end
    return GetGroupMemberSelectedRole("player")
end

local function IsPlayerTank()
    return GetPlayerRole() == ROLE_TANK
end

local function IsPlayerDpsOrTank()
    local role = GetPlayerRole()
    if not role then return true end
    return role == ROLE_DPS or role == ROLE_TANK
end

local function UnitHasHealCheck(unitTag)
    if not activePurges[unitTag] then return false end
    for id, _ in pairs(activePurges[unitTag]) do
        local t = PurgeableTrialAbilities[id]
        if t == ALERT_HEAL or t == ALERT_HEAL_RANGE then
            return true
        end
    end
    return false
end

function PurgeRadar.SlashCommand(args)
    args = args and zo_strtrim(args) or ""
    if args == "status" or args == "" then
        local n = 0
        for _ in pairs(PurgeableTrialAbilities) do n = n + 1 end
        CHAT_ROUTER:AddSystemMessage(string.format(
            "[PurgeRadar] v%s loaded | %d abilities tracked | LAM=%s | Icons=%s",
            PurgeRadar.version, n,
            LibAddonMenu2 and "yes" or "no",
            LibFloatingIcons and "yes" or "no"
        ))
        if LibAddonMenu2 then
            CHAT_ROUTER:AddSystemMessage("[PurgeRadar] Settings: ESC > Settings > Addons > PurgeRadar")
        else
            CHAT_ROUTER:AddSystemMessage("[PurgeRadar] Install LibAddonMenu-2.0 for the settings panel.")
        end
    elseif args == "reset" then
        PurgeRadar.ResetAllIndicators()
        CHAT_ROUTER:AddSystemMessage("[PurgeRadar] Indicators cleared.")
    else
        CHAT_ROUTER:AddSystemMessage("[PurgeRadar] Commands: /purgeradar | /purgeradar status | /purgeradar reset")
    end
end

function PurgeRadar.Initialize(eventCode, addOnName)
    if addOnName ~= PurgeRadar.name then return end
    EVENT_MANAGER:UnregisterForEvent(PurgeRadar.name, EVENT_ADD_ON_LOADED)

    PurgeRadar.settings = ZO_SavedVars:NewAccountWide(
        "PurgeRadarSavedVars",
        PurgeRadar.variableVersion,
        GetWorldName(),
        PurgeRadar.defaultSettings
    )
    if type(PurgeRadar.settings.enabledAbilities) ~= "table" then
        PurgeRadar.settings.enabledAbilities = {}
    end

    PurgeRadar.CreateSettingsMenu()
    SLASH_COMMANDS["/purgeradar"] = PurgeRadar.SlashCommand
    SLASH_COMMANDS["/pr"] = PurgeRadar.SlashCommand

    for abilityId, _ in pairs(PurgeableTrialAbilities) do
        local filterName = PurgeRadar.name .. "_eff_" .. tostring(abilityId)
        EVENT_MANAGER:RegisterForEvent(filterName, EVENT_EFFECT_CHANGED, PurgeRadar.OnEffectChanged)
        EVENT_MANAGER:AddFilterForEvent(filterName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
        EVENT_MANAGER:AddFilterForEvent(filterName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
    end

    EVENT_MANAGER:RegisterForEvent(PurgeRadar.name .. "_activated", EVENT_PLAYER_ACTIVATED, PurgeRadar.OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(PurgeRadar.name .. "_loadedmsg", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(PurgeRadar.name .. "_loadedmsg", EVENT_PLAYER_ACTIVATED)
        CHAT_ROUTER:AddSystemMessage("|c33FF66[PurgeRadar]|r v" .. PurgeRadar.version .. " active. Type /purgeradar for status.")
    end)
end

function PurgeRadar.OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
    local alertType = PurgeableTrialAbilities[abilityId]
    if not alertType then return end
    if not IsAbilityEnabled(abilityId) then return end
    if alertType == ALERT_HEAL_RANGE and IsPlayerTank() then return end

    if changeType == EFFECT_RESULT_GAINED then
        if not activePurges[unitTag] then activePurges[unitTag] = {} end
        if not activePurges[unitTag][abilityId] then
            if PurgeRadar.settings.enableSound then PurgeRadar.PlayAlertSound() end
            if PurgeRadar.settings.enableScreenAlerts then
                local cleanName = ZO_CachedStrFormat(SI_UNIT_NAME, unitName)
                local playerIsDpsOrTank = IsPlayerDpsOrTank()
                if alertType == ALERT_HEAL_RANGE then
                    CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE,
                        "|cFF4400[DISEASE LEAK]|r " .. cleanName .. " – Stack on the healing circles!")
                elseif playerIsDpsOrTank then
                    CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE,
                        "|cFFAA00[RANGE CHECK]|r " .. cleanName .. " – Stack on the healing circles!")
                else
                    if alertType == ALERT_PURGE then
                        CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE,
                            "|c00FFFF[PURGE NOW]|r " .. cleanName .. " needs a cleanse!")
                    elseif alertType == ALERT_HEAL then
                        if abilityId == 183790 or abilityId == 185399 or abilityId == 116584 then
                            CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE,
                                "|c66CCFF[ICE TOMB]|r " .. cleanName .. " – HEAL TO FULL before they freeze!")
                        else
                            CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE,
                                "|cFF6600[HEAL CHECK]|r " .. cleanName .. " – HEAL THROUGH (cannot purge)!")
                        end
                    end
                end
            end
        end
        activePurges[unitTag][abilityId] = true
        PurgeRadar.StartRangeTrackingLoop()
    elseif changeType == EFFECT_RESULT_UPDATED then
        if activePurges[unitTag] then activePurges[unitTag][abilityId] = true end
    elseif changeType == EFFECT_RESULT_FADED then
        if activePurges[unitTag] then
            activePurges[unitTag][abilityId] = nil
            if next(activePurges[unitTag]) == nil then
                activePurges[unitTag] = nil
                PurgeRadar.UpdateIndicator(unitTag, false, false)
            end
        end
        if next(activePurges) == nil then PurgeRadar.StopRangeTrackingLoop() end
    end
end

function PurgeRadar.UpdateRangeTracking()
    if next(activePurges) == nil then
        PurgeRadar.StopRangeTrackingLoop()
        return
    end
    for unitTag, _ in pairs(activePurges) do
        if IsUnitOnline(unitTag) and IsUnitInGroupZone(unitTag) then
            PurgeRadar.UpdateIndicator(unitTag, true, IsUnitInCastRange(unitTag, PURGE_SPELL_ID))
        else
            PurgeRadar.UpdateIndicator(unitTag, false, false)
        end
    end
end

function PurgeRadar.StartRangeTrackingLoop()
    if not isTrackingRanges then
        isTrackingRanges = true
        EVENT_MANAGER:RegisterForUpdate(PurgeRadar.name .. "RangeLoop", 200, PurgeRadar.UpdateRangeTracking)
    end
end

function PurgeRadar.StopRangeTrackingLoop()
    isTrackingRanges = false
    EVENT_MANAGER:UnregisterForUpdate(PurgeRadar.name .. "RangeLoop")
end

function PurgeRadar.UpdateIndicator(unitTag, shouldShow, inRange)
    if PurgeRadar.settings.enableOneFrameColors then
        PurgeRadar.ApplyOneFrameColorOverride(unitTag, shouldShow, inRange)
    elseif not shouldShow then
        PurgeRadar.ApplyOneFrameColorOverride(unitTag, false, false)
    end
    if not LibFloatingIcons then return end
    if not PurgeRadar.settings.enableFloatingIcons then
        LibFloatingIcons.RemoveIconFromUnit(unitTag)
        return
    end
    if shouldShow then
        if UnitHasHealCheck(unitTag) then
            local col = ColorFromPresetIndex(PurgeRadar.settings.healIconColor)
            LibFloatingIcons.AddIconToUnit(unitTag, "esoui/art/compass/compass_objective_green.dds", {
                size = 46, offsetY = -230, color = col,
            })
        elseif inRange then
            local col = ColorFromPresetIndex(PurgeRadar.settings.purgeInRangeColor)
            LibFloatingIcons.AddIconToUnit(unitTag, "esoui/art/compass/compass_objective_green.dds", {
                size = 46, offsetY = -230, color = col,
            })
        else
            LibFloatingIcons.RemoveIconFromUnit(unitTag)
        end
    else
        LibFloatingIcons.RemoveIconFromUnit(unitTag)
    end
end

function PurgeRadar.ApplyOneFrameColorOverride(unitTag, shouldShow, inRange)
    local rawTag = unitTag:gsub("group", "")
    local unitFrame = WINDOW_MANAGER:GetControlByName("ZO_RaidRosterGroup" .. rawTag .. "UnitFrame")
        or WINDOW_MANAGER:GetControlByName("ZO_GroupUnitFrame" .. rawTag)
    if not unitFrame then return end
    local healthBar = unitFrame:GetNamedChild("HpBar") or unitFrame:GetNamedChild("Health")
    if not healthBar or not healthBar.SetColor then return end
    if shouldShow and PurgeRadar.settings.enableOneFrameColors then
        if not healthBar.originalColorR then
            healthBar.originalColorR, healthBar.originalColorG, healthBar.originalColorB = healthBar:GetColor()
        end
        local col
        if UnitHasHealCheck(unitTag) then
            col = ColorFromPresetIndex(inRange and PurgeRadar.settings.healInRangeColor or PurgeRadar.settings.healOutRangeColor)
        else
            col = ColorFromPresetIndex(inRange and PurgeRadar.settings.purgeInRangeColor or PurgeRadar.settings.purgeOutRangeColor)
        end
        healthBar:SetColor(col[1], col[2], col[3], col[4] or 1)
    else
        if healthBar.originalColorR then
            healthBar:SetColor(healthBar.originalColorR, healthBar.originalColorG, healthBar.originalColorB, 1)
            healthBar.originalColorR = nil
            healthBar.originalColorG = nil
            healthBar.originalColorB = nil
        end
    end
end

function PurgeRadar.PlayAlertSound()
    local volumeSteps = PurgeRadar.settings.soundVolume
    if volumeSteps <= 0 then return end
    for i = 1, volumeSteps do
        PlaySound(SOUNDS.BATTLEGROUND_NEARING_VICTORY)
    end
end

function PurgeRadar.ResetAllIndicators()
    for unitTag, _ in pairs(activePurges) do
        PurgeRadar.UpdateIndicator(unitTag, false, false)
    end
    activePurges = {}
    PurgeRadar.StopRangeTrackingLoop()
end

function PurgeRadar.OnPlayerActivated(eventCode, initial)
    if not PurgeRadar.settings.enableZoneWarning then return end
    local zoneName = GetUnitZone("player")
    if not zoneName or zoneName == "" then return end
    local lowerZone = zoneName:lower()
    local isDangerous = false
    for knownZone, _ in pairs(ZonesWithDeadlyPurgeableDots) do
        if lowerZone:find(knownZone, 1, true) then
            isDangerous = true
            break
        end
    end
    if isDangerous and lastWarnedZone ~= lowerZone then
        lastWarnedZone = lowerZone
        CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_LARGE_TEXT, SOUNDS.NONE,
            "|cFF3333This zone contains a deadly DoT – please have Purge equipped!|r")
        if PurgeRadar.settings.enableSound then
            PlaySound(SOUNDS.BATTLEGROUND_NEARING_VICTORY)
        end
    elseif not isDangerous then
        lastWarnedZone = nil
    end
end

function PurgeRadar.CreateSettingsMenu()
    if not LibAddonMenu2 then return end

    local panelData = {
        type = "panel",
        name = "PurgeRadar",
        displayName = "|c33FF66PurgeRadar|r Settings",
        author = "SuperSecretTech",
        version = PurgeRadar.version,
        slashCommand = "/purgeradarsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    local colorChoices = ColorPresetChoices()
    local optionsData = {
        { type = "header", name = "Audio" },
        {
            type = "checkbox",
            name = "Enable Sound Alerts",
            getFunc = function() return PurgeRadar.settings.enableSound end,
            setFunc = function(value) PurgeRadar.settings.enableSound = value end,
            default = PurgeRadar.defaultSettings.enableSound,
        },
        {
            type = "slider",
            name = "Alert Playback Volume",
            min = 1, max = 5, step = 1,
            getFunc = function() return PurgeRadar.settings.soundVolume end,
            setFunc = function(value)
                PurgeRadar.settings.soundVolume = value
                PlaySound(SOUNDS.BATTLEGROUND_NEARING_VICTORY)
            end,
            disabled = function() return not PurgeRadar.settings.enableSound end,
            default = PurgeRadar.defaultSettings.soundVolume,
        },
        { type = "header", name = "Alerts & Indicators" },
        {
            type = "checkbox",
            name = "Enable Screen Alerts (CSA)",
            getFunc = function() return PurgeRadar.settings.enableScreenAlerts end,
            setFunc = function(value) PurgeRadar.settings.enableScreenAlerts = value end,
            default = PurgeRadar.defaultSettings.enableScreenAlerts,
        },
        {
            type = "checkbox",
            name = "Enable Floating Icons",
            getFunc = function() return PurgeRadar.settings.enableFloatingIcons end,
            setFunc = function(value)
                PurgeRadar.settings.enableFloatingIcons = value
                if not value then PurgeRadar.ResetAllIndicators() end
            end,
            default = PurgeRadar.defaultSettings.enableFloatingIcons,
        },
        {
            type = "checkbox",
            name = "Enable OneFrame / Group Frame Colors",
            getFunc = function() return PurgeRadar.settings.enableOneFrameColors end,
            setFunc = function(value)
                PurgeRadar.settings.enableOneFrameColors = value
                if not value then
                    for unitTag, _ in pairs(activePurges) do
                        PurgeRadar.ApplyOneFrameColorOverride(unitTag, false, false)
                    end
                end
            end,
            default = PurgeRadar.defaultSettings.enableOneFrameColors,
        },
        {
            type = "checkbox",
            name = "Enable Zone DoT Warning",
            getFunc = function() return PurgeRadar.settings.enableZoneWarning end,
            setFunc = function(value) PurgeRadar.settings.enableZoneWarning = value end,
            default = PurgeRadar.defaultSettings.enableZoneWarning,
        },
        { type = "header", name = "Colors" },
        {
            type = "dropdown",
            name = "Purge – In Range (icon & frame)",
            choices = colorChoices,
            getFunc = function() return colorChoices[PurgeRadar.settings.purgeInRangeColor] or colorChoices[1] end,
            setFunc = function(choice)
                for i, name in ipairs(colorChoices) do
                    if name == choice then PurgeRadar.settings.purgeInRangeColor = i break end
                end
            end,
            default = colorChoices[PurgeRadar.defaultSettings.purgeInRangeColor],
        },
        {
            type = "dropdown",
            name = "Purge – Out of Range (frame)",
            choices = colorChoices,
            getFunc = function() return colorChoices[PurgeRadar.settings.purgeOutRangeColor] or colorChoices[2] end,
            setFunc = function(choice)
                for i, name in ipairs(colorChoices) do
                    if name == choice then PurgeRadar.settings.purgeOutRangeColor = i break end
                end
            end,
            default = colorChoices[PurgeRadar.defaultSettings.purgeOutRangeColor],
        },
        {
            type = "dropdown",
            name = "Heal-Check – In Range (frame)",
            choices = colorChoices,
            getFunc = function() return colorChoices[PurgeRadar.settings.healInRangeColor] or colorChoices[3] end,
            setFunc = function(choice)
                for i, name in ipairs(colorChoices) do
                    if name == choice then PurgeRadar.settings.healInRangeColor = i break end
                end
            end,
            default = colorChoices[PurgeRadar.defaultSettings.healInRangeColor],
        },
        {
            type = "dropdown",
            name = "Heal-Check – Out of Range (frame)",
            choices = colorChoices,
            getFunc = function() return colorChoices[PurgeRadar.settings.healOutRangeColor] or colorChoices[4] end,
            setFunc = function(choice)
                for i, name in ipairs(colorChoices) do
                    if name == choice then PurgeRadar.settings.healOutRangeColor = i break end
                end
            end,
            default = colorChoices[PurgeRadar.defaultSettings.healOutRangeColor],
        },
        {
            type = "dropdown",
            name = "Heal-Check / Ice Tomb – Floating Icon",
            choices = colorChoices,
            getFunc = function() return colorChoices[PurgeRadar.settings.healIconColor] or colorChoices[5] end,
            setFunc = function(choice)
                for i, name in ipairs(colorChoices) do
                    if name == choice then PurgeRadar.settings.healIconColor = i break end
                end
            end,
            default = colorChoices[PurgeRadar.defaultSettings.healIconColor],
        },
        { type = "header", name = "Tracked Abilities" },
        { type = "description", text = "Uncheck any ability you do not want tracked. Changes apply immediately." },
    }

    local sortedIds = {}
    for abilityId, _ in pairs(PurgeableTrialAbilities) do
        sortedIds[#sortedIds + 1] = abilityId
    end
    table_sort(sortedIds, function(a, b)
        return (AbilityDisplayNames[a] or tostring(a)) < (AbilityDisplayNames[b] or tostring(b))
    end)

    for _, abilityId in ipairs(sortedIds) do
        local displayName = AbilityDisplayNames[abilityId] or ("Ability " .. tostring(abilityId))
        local alertType = PurgeableTrialAbilities[abilityId]
        local typeLabel = (alertType == ALERT_PURGE and "[Purge] ")
            or (alertType == ALERT_HEAL_RANGE and "[Heal-Range] ")
            or "[Heal] "
        optionsData[#optionsData + 1] = {
            type = "checkbox",
            name = typeLabel .. displayName,
            tooltip = "Track ability ID " .. tostring(abilityId) .. ".",
            getFunc = function() return IsAbilityEnabled(abilityId) end,
            setFunc = function(value)
                PurgeRadar.settings.enabledAbilities[abilityId] = value and true or false
                if not value then
                    for unitTag, abilities in pairs(activePurges) do
                        if abilities[abilityId] then
                            abilities[abilityId] = nil
                            if next(abilities) == nil then
                                activePurges[unitTag] = nil
                                PurgeRadar.UpdateIndicator(unitTag, false, false)
                            end
                        end
                    end
                    if next(activePurges) == nil then PurgeRadar.StopRangeTrackingLoop() end
                end
            end,
            default = true,
        }
    end

    LibAddonMenu2:RegisterAddonPanel("PurgeRadar_SettingsPanel", panelData)
    LibAddonMenu2:RegisterOptionControls("PurgeRadar_SettingsPanel", optionsData)
end

EVENT_MANAGER:RegisterForEvent(PurgeRadar.name, EVENT_ADD_ON_LOADED, PurgeRadar.Initialize)
