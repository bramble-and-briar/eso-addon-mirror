TeamShadowsBuffs = TeamShadowsBuffs or {}

local TSB = TeamShadowsBuffs
local EM = EVENT_MANAGER
local MODULE_NAME = "MajorEffects"
local EVENT_PREFIX = TSB.name .. MODULE_NAME
local SCAN_UPDATE = EVENT_PREFIX .. "ScanUpdate"
local SPAULDER_EFFECT_KEY = "spaulder_ruin"
local SPAULDER_TOGGLE_ABILITY_ID = 163359
local SET_CATEGORIES = {
    set_stacks = true,
    set_procs = true,
    monster_sets = true,
    dungeon_proc_sets = true,
    overland_crafted_pvp_procs = true,
    mythic_stacks = true,
    trial_proc_sets = true,
}

local Module = {
    name = MODULE_NAME,
    abilityIds = {},
    active = {
        player = {},
        boss = {},
    },
    headActive = {},
    groupActive = {},
    cooldowns = {}, -- un seul état par proc : phase active, puis phase de recharge
    autoEquipped = {},
    spaulderActive = false,
}
local lifecycleActive = false
local lifecycleRefreshQueued = false

local function QueueLifecycleRefresh()
    if not lifecycleActive or lifecycleRefreshQueued then return end
    lifecycleRefreshQueued = true
    zo_callLater(function()
        lifecycleRefreshQueued = false
        if not lifecycleActive then return end
        TSB.SafeCall(MODULE_NAME, "ZoneRefresh", function()
            Module:RefreshAutoEquippedSets()
            Module:Scan()
            if TSB.UI and TSB.UI.ApplySettings then TSB.UI:ApplySettings() end
        end)
    end, 600)
end

-- Les effets viennent désormais du catalogue (TeamShadowsBuffsCatalog.lua),
-- groupés par cible. "player" -> buffs joueur ; "target" -> debuffs cible/boss.
-- Repli sur l'ancien set minimal si le catalogue n'est pas chargé.
local effects = { playerBuffs = {}, bossDebuffs = {} }
if TSB.GetCatalogByTarget then
    local player, target = TSB.GetCatalogByTarget()
    effects.playerBuffs = player or {}
    effects.bossDebuffs = target or {}
else
    effects.playerBuffs = {
        { key = "major_slayer", shortName = "TM", name = "Tueur majeur", ids = { 93109, 93120, 93442 }, color = { r = 0.2, g = 0.72, b = 0.32 }, defaultEnabled = true },
        { key = "major_courage", shortName = "CM", name = "Courage majeur", ids = { 109966 }, color = { r = 0.22, g = 0.56, b = 0.96 }, defaultEnabled = true },
    }
    effects.bossDebuffs = {
        { key = "major_vulnerability", shortName = "VM", name = "Vulnérabilité", ids = { 106754, 122389, 122177 }, color = { r = 0.82, g = 0.18, b = 0.22 }, defaultEnabled = true },
        { key = "off_balance", shortName = "DE", name = "Déséquilibre", ids = { 39077, 63003, 102771 }, color = { r = 0.95, g = 0.86, b = 0.18 }, defaultEnabled = true },
    }
    if TSB.Chat then TSB.Chat("Catalogue absent : charge TeamShadowsBuffsCatalog.lua AVANT MajorEffects dans le fichier .txt.") end
end

local effectsByKey = {}

local effectById = {}

local function NormalizeName(value)
    value = string.lower(tostring(value or ""))
    value = value:gsub("É", "e"):gsub("È", "e"):gsub("Ê", "e"):gsub("Ë", "e")
    value = value:gsub("À", "a"):gsub("Â", "a")
    value = value:gsub("Î", "i"):gsub("Ï", "i")
    value = value:gsub("Ô", "o")
    value = value:gsub("Ù", "u"):gsub("Û", "u")
    value = value:gsub("Ç", "c")
    value = value:gsub("é", "e"):gsub("è", "e"):gsub("ê", "e"):gsub("ë", "e")
    value = value:gsub("à", "a"):gsub("â", "a")
    value = value:gsub("î", "i"):gsub("ï", "i")
    value = value:gsub("ô", "o")
    value = value:gsub("ù", "u"):gsub("û", "u")
    value = value:gsub("ç", "c")
    return value
end

local function NormalizeSetName(value)
    value = NormalizeName(value):gsub("%^.*", "")
    value = value:gsub("perfected", ""):gsub("perfectionne", ""):gsub("perfectionnee", "")
    return value:gsub("[^%w]", "")
end

local function FindEffectByName(effectName)
    local normalized = NormalizeName(effectName)
    if normalized == "" then return nil end

    if normalized:find("prophetie majeure", 1, true) or normalized:find("major prophecy", 1, true) then
        return effectsByKey.major_savagery
    end

    if normalized:find("sauvagerie majeure", 1, true) or normalized:find("major savagery", 1, true) then
        return effectsByKey.major_savagery
    end

    if normalized:find("desequilibre", 1, true) or normalized:find("quilibre", 1, true) or normalized:find("off balance", 1, true) then
        return effectsByKey.off_balance
    end

    return nil
end

local function CopyColor(color)
    color = color or {}
    return {
        r = color.r or 1,
        g = color.g or 1,
        b = color.b or 1,
        a = color.a or 1,
    }
end

function TSB.GetMajorEffectDefinitions()
    return effects
end

function TSB.GetMajorEffectByKey(key)
    return effectsByKey[key]
end

function TSB.GetEffectSettings(key)
    if not TSB.savedVars then return {} end
    TSB.savedVars.effectSettings = TSB.savedVars.effectSettings or {}
    TSB.savedVars.effectSettings[key] = TSB.savedVars.effectSettings[key] or {}
    return TSB.savedVars.effectSettings[key]
end

function TSB.ResetEffectSettings(key)
    if not TSB.savedVars or not TSB.savedVars.effectSettings then return end
    TSB.savedVars.effectSettings[key] = nil
    TSB.NotifyDisplayChanged()
end

function TSB.ResetAllEffectSettings()
    if not TSB.savedVars then return end
    TSB.savedVars.effectSettings = {}
    TSB.NotifyDisplayChanged()
end

function TSB.EnsureEffectSettingsDefaults()
    if not TSB.savedVars then return end
    TSB.savedVars.effectSettings = TSB.savedVars.effectSettings or {}
end

local function GetEffectColor(effect)
    local settings = TSB.GetEffectSettings and TSB.GetEffectSettings(effect.key) or {}
    if settings.color then
        return CopyColor(settings.color)
    end
    return CopyColor(effect.color)
end

local function GetCooldownColor(effect)
    local settings = TSB.GetEffectSettings and TSB.GetEffectSettings(effect.key) or {}
    if settings.cooldownColor then return CopyColor(settings.cooldownColor) end
    if TSB.savedVars and TSB.savedVars.cooldownColor then return CopyColor(TSB.savedVars.cooldownColor) end
    if effect.cooldownColor then return CopyColor(effect.cooldownColor) end
    return { r = 0.88, g = 0.24, b = 0.08, a = 1 }
end

local function IsEffectConfiguredEnabled(effect)
    local settings = TSB.GetEffectSettings and TSB.GetEffectSettings(effect.key) or {}
    -- [FIX] le choix utilisateur passe AVANT l'auto-détection : le bouton
    -- DÉSACTIVER peut désormais éteindre un set détecté automatiquement
    if TSB.AnyTrackerDestinationConfigured and TSB.AnyTrackerDestinationConfigured(effect.key) then
        return TSB.AnyTrackerDestinationEnabled(effect.key)
    end
    if settings.enabled ~= nil then return settings.enabled end
    -- set auto-détecté sans choix utilisateur : affiché par défaut tant qu'il est équipé
    if Module.autoEquipped and Module.autoEquipped[effect.key] == true then return true end
    -- pas de choix utilisateur : seul le set d'origine est ON par défaut
    return effect.defaultEnabled == true
end

local function IsEffectEnabled(effect)
    if SET_CATEGORIES[effect.categoryKey]
        and not (Module.autoEquipped and Module.autoEquipped[effect.key] == true) then
        return false
    end
    return IsEffectConfiguredEnabled(effect)
end

local function TrackerDestinations(effectKey, includeDisabled)
    if TSB.GetTrackerDestinations then return TSB.GetTrackerDestinations(effectKey, includeDisabled) end
    local settings = TSB.GetEffectSettings and TSB.GetEffectSettings(effectKey) or {}
    return settings.destination and { settings.destination } or {}
end

local function HasTrackerDestination(effectKey, destination, includeDisabled)
    if includeDisabled and TSB.IsTrackerDestinationConfigured then
        return TSB.IsTrackerDestinationConfigured(effectKey, destination)
    end
    if TSB.IsTrackerDestinationEnabled then return TSB.IsTrackerDestinationEnabled(effectKey, destination) end
    local settings = TSB.GetEffectSettings and TSB.GetEffectSettings(effectKey) or {}
    return settings.destination == destination
end

-- exposé pour l'UI (même logique de défaut)
function TSB.IsEffectEnabledByKey(key)
    local effect = effectsByKey[key]
    if not effect then return false end
    return IsEffectEnabled(effect)
end

local function GetEffectName(effect)
    local settings = TSB.GetEffectSettings and TSB.GetEffectSettings(effect.key) or {}
    if type(settings.name) == "string" and settings.name ~= "" and settings.name ~= effect.fallbackName then
        return settings.name
    end
    if TSB.savedVars and TSB.savedVars.catalogLanguage == "en" and effect.nameEn and effect.nameEn ~= "" then
        return effect.nameEn
    end
    if TSB.savedVars and TSB.savedVars.catalogLanguage ~= "en" and effect.nameFr and effect.nameFr ~= "" then
        return effect.nameFr
    end
    local savedNames = TSB.savedVars and TSB.savedVars.catalogNamesByLanguage
    if TSB.savedVars and TSB.savedVars.catalogLanguage == "en" and savedNames and savedNames.en and savedNames.en[effect.key] then
        return savedNames.en[effect.key]
    end
    if TSB.savedVars and TSB.savedVars.catalogLanguage ~= "en" and effect.fallbackName and effect.fallbackName ~= "" then
        return effect.fallbackName
    end
    return effect.name
end

local function GetEffectShortName(effect)
    local settings = TSB.GetEffectSettings and TSB.GetEffectSettings(effect.key) or {}
    if type(settings.shortName) == "string" and settings.shortName ~= "" then
        return settings.shortName
    end
    return effect.shortName
end

local function GetDisplayName(effect)
    local name = GetEffectName(effect)
    name = name:gsub("majeure", "MAJ")
    name = name:gsub("majeur", "MAJ")
    return name
end

local function GetEffectIcon(effect)
    if effect.icon then
        return effect.icon
    end
    if GetAbilityIcon then
        for _, abilityId in ipairs(effect.ids or {}) do
            local icon = GetAbilityIcon(abilityId)
            if type(icon) == "string" and icon ~= "" then
                effect.icon = icon
                return icon
            end
        end
    end
    return nil
end

-- correspondance nom localisé -> effet (apprentissage d'ids, cf. OnPlayerAuraLearn)
local effectByLocalizedName = {}
-- ids déjà couverts par un listener filtré (évite les doublons d'événements)
local registeredIds = {}
local seenAuras = {}

local function IndexEffect(effect, targetType)
    effect.targetType = targetType
    effectsByKey[effect.key] = effect
    local auraIds = effect.classMastery and effect.procIds or effect.ids
    for _, abilityId in ipairs(auraIds or {}) do
        if not effectById[abilityId] then
            table.insert(Module.abilityIds, abilityId)
        end
        effectById[abilityId] = effect
    end
    if effect.nameFr and effect.nameFr ~= "" then
        effectByLocalizedName[NormalizeName(effect.nameFr)] = effect
    end
    if effect.nameEn and effect.nameEn ~= "" then
        effectByLocalizedName[NormalizeName(effect.nameEn)] = effect
    end
end

local function IsClassMasteryPurchased(effect)
    if not effect or not effect.classMastery then return false end
    if not GetUnitClassId or GetUnitClassId("player") ~= effect.classId then return false end
    if IsSubclassing and IsSubclassing() then return false end
    if not GetSkillLineIndicesFromSkillLineId or not GetSkillAbilityInfo then return false end

    local _, skillLineIndex = GetSkillLineIndicesFromSkillLineId(effect.skillLineId)
    if not skillLineIndex then return false end
    local _, _, _, _, _, isPurchased = GetSkillAbilityInfo(
        SKILL_TYPE_CLASS, skillLineIndex, effect.passiveIndex
    )
    return isPurchased == true
end

for _, effect in ipairs(effects.playerBuffs) do
    IndexEffect(effect, "player")
end

for _, effect in ipairs(effects.bossDebuffs) do
    IndexEffect(effect, "boss")
end

local AUTO_SET_EFFECTS = {}
for _, effect in pairs(effectsByKey) do
    if SET_CATEGORIES[effect.categoryKey] then
        AUTO_SET_EFFECTS[#AUTO_SET_EFFECTS + 1] = effect
    end
end

local EQUIPPED_BODY_SLOTS = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_HAND, EQUIP_SLOT_NECK,
    EQUIP_SLOT_RING1, EQUIP_SLOT_RING2,
}

local TWO_HANDED_WEAPONS = {
    [WEAPONTYPE_TWO_HANDED_AXE] = true,
    [WEAPONTYPE_TWO_HANDED_HAMMER] = true,
    [WEAPONTYPE_TWO_HANDED_SWORD] = true,
    [WEAPONTYPE_BOW] = true,
    [WEAPONTYPE_FIRE_STAFF] = true,
    [WEAPONTYPE_FROST_STAFF] = true,
    [WEAPONTYPE_LIGHTNING_STAFF] = true,
    [WEAPONTYPE_HEALING_STAFF] = true,
}

local function EquippedSetRecords()
    -- [FIX] presence sur le PERSONNAGE, pas sur la barre active : le corps compte
    -- toujours, et pour les armes on prend la meilleure des deux barres. Un set
    -- complété par les armes de la barre arrière reste donc détecté même quand la
    -- barre avant est active (avant : le tracker disparaissait au changement de barre).
    local records = {}
    local function AddSlot(slot, field)
        if not GetItemLink or not GetItemLinkSetInfo then return end
        local link = GetItemLink(BAG_WORN, slot)
        if not link or link == "" then return end
        local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(link, false)
        setId = tonumber(setId)
        if not hasSet or not setId or setId <= 0 then return end
        local record = records[setId]
        if not record then
            record = { setId = setId, name = tostring(setName or ""), body = 0, front = 0, back = 0 }
            records[setId] = record
        end
        local count = 1
        if field ~= "body" and GetItemWeaponType and TWO_HANDED_WEAPONS[GetItemWeaponType(BAG_WORN, slot)] then
            count = 2 -- une arme a deux mains compte pour 2 pieces de set
        end
        record[field] = record[field] + count
    end

    for _, slot in ipairs(EQUIPPED_BODY_SLOTS) do AddSlot(slot, "body") end
    AddSlot(EQUIP_SLOT_MAIN_HAND, "front")
    AddSlot(EQUIP_SLOT_OFF_HAND, "front")
    AddSlot(EQUIP_SLOT_BACKUP_MAIN, "back")
    AddSlot(EQUIP_SLOT_BACKUP_OFF, "back")

    for _, record in pairs(records) do
        record.pieces = record.body + zo_max(record.front, record.back)
    end
    return records
end

local function EffectMatchesEquippedSet(effect, record)
    for _, setId in ipairs(effect.setIds or {}) do
        if tonumber(setId) == record.setId then return true end
    end
    local equippedName = NormalizeSetName(record.name)
    if equippedName == "" then return false end
    for _, setName in ipairs(effect.setNames or { effect.fallbackName }) do
        if NormalizeSetName(setName) == equippedName then return true end
    end
    local effectName = NormalizeSetName(effect.fallbackName)
    if #effectName >= 4 and (equippedName:find(effectName, 1, true) or effectName:find(equippedName, 1, true)) then
        return true
    end
    return false
end

function Module:RefreshAutoEquippedSets()
    local records = EquippedSetRecords()
    local equipped = {}
    for _, effect in ipairs(AUTO_SET_EFFECTS) do
        local required = tonumber(effect.equipPieces)
            or (effect.categoryKey == "mythic_stacks" and 1)
            or (effect.categoryKey == "monster_sets" and 2)
            or 5
        for _, record in pairs(records) do
            if record.pieces >= required and EffectMatchesEquippedSet(effect, record) then
                equipped[effect.key] = true
                break
            end
        end
    end

    local changed = false
    for key in pairs(self.autoEquipped or {}) do
        if not equipped[key] then changed = true break end
    end
    if not changed then
        for key in pairs(equipped) do
            if not self.autoEquipped[key] then changed = true break end
        end
    end
    self.autoEquipped = equipped
    if not equipped[SPAULDER_EFFECT_KEY] then self.spaulderActive = false end
    if changed then TSB.NotifyDisplayChanged() end
end

function TSB.IsAutoSetTrackerEquipped(key)
    return Module.autoEquipped and Module.autoEquipped[key] == true
end

local function IsPlayerUnitTag(unitTag)
    if unitTag == "player" then return true end
    if unitTag and AreUnitsEqual then
        return AreUnitsEqual("player", unitTag)
    end
    return false
end

local function IsBossUnitTag(unitTag)
    return unitTag == "reticleover" or (type(unitTag) == "string" and unitTag:find("boss", 1, true) == 1)
end

local function IsGroupUnitTag(unitTag)
    return type(unitTag) == "string" and unitTag:match("^group%d+$") ~= nil
end

local function IsFriendlyUnitTag(unitTag)
    return IsPlayerUnitTag(unitTag) or IsGroupUnitTag(unitTag)
end

local function IsExpectedAuraUnit(effect, unitTag)
    if effect.procTargetType == "boss" then return IsBossUnitTag(unitTag) end
    if effect.procTargetType == "friendly" then return IsFriendlyUnitTag(unitTag) end
    if effect.targetType == "boss" then return IsBossUnitTag(unitTag) end
    if effect.targetType == "player" then
        return IsPlayerUnitTag(unitTag)
            or ((HasTrackerDestination(effect.key, "head") or HasTrackerDestination(effect.key, "group"))
                and IsGroupUnitTag(unitTag))
    end
    return false
end

local function GetBucket(targetType)
    Module.active[targetType] = Module.active[targetType] or {}
    return Module.active[targetType]
end

local function Forget(effect, unitTag)
    if HasTrackerDestination(effect.key, "head") and unitTag and Module.headActive[effect.key] then
        Module.headActive[effect.key][unitTag] = nil
        if next(Module.headActive[effect.key]) == nil then Module.headActive[effect.key] = nil end
    end
    if HasTrackerDestination(effect.key, "group") and unitTag and Module.groupActive[effect.key] then
        Module.groupActive[effect.key][unitTag] = nil
        if next(Module.groupActive[effect.key]) == nil then Module.groupActive[effect.key] = nil end
    end
    local bucket = GetBucket(effect.targetType)
    local current = bucket[effect.key]
    local storesFriendlyProc = effect.procTargetType == "friendly" and IsGroupUnitTag(unitTag)
    if unitTag == "player" or not IsGroupUnitTag(unitTag) or storesFriendlyProc then
        if not current or current.unitTag == unitTag then bucket[effect.key] = nil end
    end
end

local function Remember(effect, effectName, unitTag, abilityId, beginTime, endTime, iconName, stackCount)
    local unitName = unitTag and DoesUnitExist(unitTag) and GetUnitName(unitTag) or nil
    local now = GetGameTimeSeconds and GetGameTimeSeconds() or 0
    beginTime = tonumber(beginTime) or 0
    endTime = tonumber(endTime) or 0
    if endTime <= now and effect.procDuration and effect.procDuration > 0 then
        beginTime = now
        endTime = now + effect.procDuration
    end
    if endTime <= now then
        Forget(effect, unitTag)
        return
    end

    local previous = GetBucket(effect.targetType)[effect.key]
    local duration = beginTime > 0 and endTime > beginTime and (endTime - beginTime) or nil
    duration = duration or (previous and previous.duration) or (endTime - now)
    local state = {
        effect = effect,
        effectName = effectName,
        unitTag = unitTag,
        unitName = unitName,
        abilityId = abilityId,
        beginTime = beginTime,
        endTime = endTime,
        duration = duration,
        icon = iconName,
        stackCount = tonumber(stackCount) or 0,
    }
    local isHeadUnit = unitTag == "player" or (type(unitTag) == "string" and unitTag:match("^group%d+$"))
    if HasTrackerDestination(effect.key, "head") and effect.targetType == "player" and isHeadUnit then
        Module.headActive[effect.key] = Module.headActive[effect.key] or {}
        Module.headActive[effect.key][unitTag] = state
    end
    if HasTrackerDestination(effect.key, "group") and effect.targetType == "player" and isHeadUnit then
        Module.groupActive[effect.key] = Module.groupActive[effect.key] or {}
        Module.groupActive[effect.key][unitTag] = state
    end
    if unitTag == "player" or not IsGroupUnitTag(unitTag) or effect.procTargetType == "friendly" then
        GetBucket(effect.targetType)[effect.key] = state
    end
end

local function AbilityDurationSeconds(abilityId)
    if not abilityId or not GetAbilityDuration then return 0 end
    local duration = tonumber(GetAbilityDuration(abilityId)) or 0
    return duration > 0 and duration / 1000 or 0
end

-- Une seule fiche est conservée : l'aura active utilise sa durée ESO, puis la
-- même fiche passe en recharge jusqu'à la fin du cooldown interne du set.
local function StartProc(effect, stackCount, beginTime, endTime, iconName, abilityId)
    local cd = tonumber(effect.cooldown) or 0
    if cd <= 0 then return end
    local now = GetGameTimeSeconds and GetGameTimeSeconds() or 0
    beginTime = tonumber(beginTime) or now
    endTime = tonumber(endTime) or 0
    local activeDuration = endTime > now and (endTime - zo_max(beginTime, now)) or 0
    if activeDuration <= 0 then activeDuration = tonumber(effect.procDuration) or 0 end
    if activeDuration <= 0 then activeDuration = AbilityDurationSeconds(abilityId) end
    local activeEnd = activeDuration > 0 and (now + activeDuration) or now
    local existing = Module.cooldowns[effect.key]
    if existing and existing.cooldownEndTime and existing.cooldownEndTime > now then
        if endTime > (existing.activeEndTime or 0) then
            existing.activeEndTime = endTime
            existing.activeDuration = zo_max(endTime - beginTime, 0.001)
            existing.abilityId = abilityId or existing.abilityId
        end
        existing.stackCount = tonumber(stackCount) or existing.stackCount or 0
        existing.icon = iconName or existing.icon
        return
    end
    Module.cooldowns[effect.key] = {
        effect = effect,
        beginTime = now,
        activeEndTime = activeEnd,
        activeDuration = zo_max(activeDuration, 0.001),
        cooldownEndTime = now + cd,
        cooldownDuration = cd,
        icon = iconName or GetEffectIcon(effect),
        abilityId = abilityId,
        stackCount = tonumber(stackCount) or 0,
    }
end

local function FadeProc(effect, stackCount, abilityId)
    local state = Module.cooldowns[effect.key]
    if not state then return end
    if abilityId and state.abilityId and abilityId ~= state.abilityId then return end
    local now = GetGameTimeSeconds and GetGameTimeSeconds() or 0
    state.activeEndTime = zo_min(state.activeEndTime or now, now)
    state.stackCount = tonumber(stackCount) or state.stackCount or 0
end

local function ProcDisplayState(effect)
    local state = Module.cooldowns[effect.key]
    if not state then return nil, false end
    local now = GetGameTimeSeconds and GetGameTimeSeconds() or 0
    if (state.activeEndTime or 0) > now then
        return {
            effect = effect,
            beginTime = state.beginTime,
            endTime = state.activeEndTime,
            duration = state.activeDuration,
            icon = state.icon,
            stackCount = state.stackCount,
            procPhase = "active",
        }, false
    end
    if (state.cooldownEndTime or 0) > now then
        local phaseStart = zo_max(state.activeEndTime or state.beginTime or now, state.beginTime or now)
        return {
            effect = effect,
            beginTime = phaseStart,
            endTime = state.cooldownEndTime,
            duration = zo_max(state.cooldownEndTime - phaseStart, 0.001),
            icon = state.icon,
            stackCount = state.stackCount,
            procPhase = "cooldown",
        }, true
    end
    Module.cooldowns[effect.key] = nil
    return nil, false
end

-- DÉTECTION VIA JOURNAL DE COMBAT : pour les procs de dégâts purs (Wrath of
-- Elements, etc.) qui ne posent AUCUNE aura, EVENT_EFFECT_CHANGED ne se déclenche
-- jamais. On écoute donc l'event de combat (du jeu de base, comme Combat Metrics) :
-- si une ability du joueur correspond à un proc à cooldown du catalogue, on lance
-- son cooldown. EVENT_COMBAT_EVENT, abilityId = dernier argument.
local seenDmg = {}
local function IsLocalCombatName(value)
    local wanted = NormalizeName(value):gsub("%^.*", "")
    if wanted == "" then return false end
    local characterName = GetUnitName and NormalizeName(GetUnitName("player")):gsub("%^.*", "") or ""
    local displayName = GetUnitDisplayName and NormalizeName(GetUnitDisplayName("player")):gsub("%^.*", "") or ""
    return wanted == characterName or wanted == displayName
end

local function OnCombatEvent(_, result, _, abilityName, _, _, sourceName, _, targetName, _, _, _, _, _, _, _, abilityId)
    if not abilityId or abilityId == 0 then return end
    if abilityId == SPAULDER_TOGGLE_ABILITY_ID
        and Module.autoEquipped and Module.autoEquipped[SPAULDER_EFFECT_KEY]
        and (IsLocalCombatName(sourceName) or IsLocalCombatName(targetName)) then
        if result == ACTION_RESULT_EFFECT_GAINED then
            Module.spaulderActive = true
        elseif result == ACTION_RESULT_EFFECT_FADED then
            Module.spaulderActive = false
        end
        TSB.NotifyDisplayChanged()
        return
    end
    local effect = effectById[abilityId]
    if effect and effect.cooldown and effect.cooldown > 0 then
        StartProc(effect, 0, nil, nil, nil, abilityId)
        TSB.NotifyDisplayChanged()
    end
    -- debug : liste DÉDUPLIQUÉE des abilities de dégâts du joueur, pour récupérer
    -- les IDs manquants (ex. Wrath of Elements). Une ligne par ability, pas de flood.
    if TSB.savedVars and TSB.savedVars.debug and not seenDmg[abilityId] then
        seenDmg[abilityId] = true
        TSB.Chat(string.format("[dmg] %s | id=%s%s", tostring(abilityName), tostring(abilityId),
            effect and (" | catalogue=" .. tostring(effect.key)) or ""))
    end
end

local function OnSpaulderToggle(_, result)
    if not (Module.autoEquipped and Module.autoEquipped[SPAULDER_EFFECT_KEY]) then
        Module.spaulderActive = false
        return
    end
    if result == ACTION_RESULT_EFFECT_GAINED then
        Module.spaulderActive = true
    elseif result == ACTION_RESULT_EFFECT_FADED then
        Module.spaulderActive = false
    else
        return
    end
    TSB.NotifyDisplayChanged()
end

local function OnEffectChanged(_, changeType, _, effectName, unitTag, beginTime, endTime, stackCount, iconName, _, _, _, _, _, _, abilityId, sourceType)
    local effect = (abilityId and effectById[abilityId]) or FindEffectByName(effectName)
    if not effect then return end

    -- DEBUG : logge tout effet du catalogue détecté, AVANT les filtres de cible.
    -- Révèle si l'ID proc bien et sur quelle unité (player vs reticleover/boss...).
    if TSB.savedVars and TSB.savedVars.debug then
        local typ = (changeType == EFFECT_RESULT_GAINED and "GAINED")
            or (changeType == EFFECT_RESULT_FADED and "FADED")
            or (changeType == EFFECT_RESULT_UPDATED and "UPDATED") or tostring(changeType)
        TSB.Chat(string.format("[detect] %s | id=%s | unit=%s | attendu=%s | %s",
            tostring(effect.key), tostring(abilityId), tostring(unitTag), tostring(effect.targetType), typ))
    end

    -- PROC À COOLDOWN : traité AVANT le filtre d'unité strict.
    -- Les procs remontent très souvent avec un unitTag vide (cf. sellistrix id=80545
    -- unit= dans les logs). On accepte donc le tag vide, le tag attendu, mais on
    -- écarte un tag d'unité clairement autre (ex. group1 = proc d'un coéquipier).
    if effect.cooldown and effect.cooldown > 0 then
        local isGroupAura = HasTrackerDestination(effect.key, "group")
            and effect.targetType == "player" and IsFriendlyUnitTag(unitTag)
        local okProcUnit = (unitTag == nil or unitTag == "")
            or (effect.targetType == "player" and IsPlayerUnitTag(unitTag))
            or (effect.targetType == "boss" and IsBossUnitTag(unitTag))
        if isGroupAura then
            if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
                Remember(effect, effectName, unitTag, abilityId, beginTime, endTime, iconName, stackCount)
            elseif changeType == EFFECT_RESULT_FADED then
                Forget(effect, unitTag)
            end
        end
        if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
            if okProcUnit then StartProc(effect, stackCount, beginTime, endTime, iconName, abilityId) end
        elseif changeType == EFFECT_RESULT_FADED and okProcUnit then
            FadeProc(effect, stackCount, abilityId)
        end
        TSB.NotifyDisplayChanged()
        return
    end

    -- effets d'aura classiques : filtres d'unité stricts.
    -- (le Scan 500ms lit directement les buffs de player/boss, donc il rattrape
    --  les events qui arrivent avec un tag vide — pas de perte pour les auras.)
    -- Les maîtrises appliquées à une cible ou à un allié peuvent remonter sans
    -- unitTag. Accepter uniquement celles dont la source est le joueur et leur
    -- attribuer un tag stable pour associer correctement GAINED et FADED.
    if effect.procTargetType and (unitTag == nil or unitTag == "") then
        if COMBAT_UNIT_TYPE_PLAYER and sourceType and sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
        unitTag = effect.procTargetType == "boss" and "reticleover" or "player"
    end
    if not IsExpectedAuraUnit(effect, unitTag) then return end
    if Module.savedVars and Module.savedVars.trackPlayerBuffs == false and effect.targetType == "player" then return end
    if Module.savedVars and Module.savedVars.trackBossDebuffs == false and effect.targetType == "boss" then return end

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        Remember(effect, effectName, unitTag, abilityId, beginTime, endTime, iconName, stackCount)
    elseif changeType == EFFECT_RESULT_FADED then
        Forget(effect, unitTag)
    end

    TSB.NotifyDisplayChanged()
end

local function ScanUnit(unitTag, targetType)
    if not GetNumBuffs or not GetUnitBuffInfo or not DoesUnitExist(unitTag) then return end

    local zenFound = false
    local playerDamageEffects = 0
    for i = 1, GetNumBuffs(unitTag) or 0 do
        local effectName, beginTime, endTime, _, stackCount, iconName, _, _, abilityType, _, abilityId, _, castByPlayer = GetUnitBuffInfo(unitTag, i)
        local effect = (abilityId and effectById[abilityId]) or FindEffectByName(effectName)
        local scannedTargetType = effect and (effect.procTargetType == "boss" and "boss" or effect.targetType)
        if targetType == "boss" and castByPlayer and (tonumber(endTime) or 0) - (tonumber(beginTime) or 0) > 1
            and abilityType == ABILITY_TYPE_DAMAGE then
            playerDamageEffects = playerDamageEffects + 1
        end
        if effect and effect.key == "zens_redress" then zenFound = true end
        if effect and scannedTargetType == targetType then
            if not (effect.cooldown and effect.cooldown > 0) or HasTrackerDestination(effect.key, "group") then
                Remember(effect, effectName, unitTag, abilityId, beginTime, endTime, iconName, stackCount)
            end
            if effect.cooldown and effect.cooldown > 0 and not IsGroupUnitTag(unitTag)
                and (targetType == "player" or castByPlayer) then
                StartProc(effect, stackCount, beginTime, endTime, iconName, abilityId)
            end
        end
    end
    if zenFound and Module.cooldowns.zens_redress then
        Module.cooldowns.zens_redress.stackCount = zo_min(playerDamageEffects, 5)
    end
end

local function UnitHasAbility(unitTag, wantedAbilityId)
    if not GetNumBuffs or not GetUnitBuffInfo or not DoesUnitExist(unitTag) then return false end
    for i = 1, GetNumBuffs(unitTag) or 0 do
        local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo(unitTag, i)
        if abilityId == wantedAbilityId then return true end
    end
    return false
end

local function AddTrialDummyEffects()
    if not DoesUnitExist or not DoesUnitExist("reticleover") then return end
    -- Les mannequins d'épreuve appliquent 120024 au joueur et n'exposent pas
    -- leurs débuffs intégrés sur reticleover. On représente donc la vulnérabilité
    -- majeure intégrée comme permanente, sans inventer de compte à rebours.
    if not UnitHasAbility("player", 120024) then return end
    local effect = effectsByKey.major_vulnerability
    if not effect then return end
    GetBucket("boss").major_vulnerability = {
        effect = effect,
        effectName = GetEffectName(effect),
        unitTag = "reticleover",
        unitName = GetUnitName and GetUnitName("reticleover") or nil,
        abilityId = 106754,
        icon = GetEffectIcon(effect),
        stackCount = 0,
        permanent = true,
        trialDummy = true,
    }
end

local function HasHeadPlayerTrackers()
    for _, effect in ipairs(effects.playerBuffs or {}) do
        if HasTrackerDestination(effect.key, "head") and IsEffectEnabled(effect) then return true end
    end
    return false
end

local function HasGroupPlayerTrackers()
    for _, effect in ipairs(effects.playerBuffs or {}) do
        if HasTrackerDestination(effect.key, "group") and IsEffectEnabled(effect) then return true end
    end
    return false
end

local function HasFriendlyMasteryTrackers()
    for _, effect in ipairs(effects.playerBuffs or {}) do
        if effect.procTargetType == "friendly" and IsEffectEnabled(effect) then return true end
    end
    return false
end

function Module:Scan()
    self.active = { player = {}, boss = {} }
    self.headActive = {}
    self.groupActive = {}

    if self.savedVars.trackPlayerBuffs ~= false then
        ScanUnit("player", "player")
        if HasHeadPlayerTrackers() or HasGroupPlayerTrackers() or HasFriendlyMasteryTrackers() then
            for i = 1, 24 do
                local unitTag = "group" .. tostring(i)
                local isLocalPlayer = AreUnitsEqual and AreUnitsEqual("player", unitTag)
                if DoesUnitExist and DoesUnitExist(unitTag) and not isLocalPlayer then ScanUnit(unitTag, "player") end
            end
        end
    end

    if self.savedVars.trackBossDebuffs ~= false then
        for i = 1, 6 do
            ScanUnit("boss" .. tostring(i), "boss")
        end
        ScanUnit("reticleover", "boss")
        AddTrialDummyEffects()
    end

    TSB.NotifyDisplayChanged()
end

local function RemainingSeconds(state)
    if not state or not state.endTime or state.endTime <= 0 or not GetGameTimeSeconds then return nil end
    local remaining = state.endTime - GetGameTimeSeconds()
    return remaining > 0 and remaining or 0
end

local function BuildLine(targetType, label, definitions)
    local parts = {}
    local active = GetBucket(targetType)

    for _, effect in ipairs(definitions or {}) do
        local state = active[effect.key]
        if state then
            local remaining = RemainingSeconds(state)
            if remaining then
                table.insert(parts, string.format("%s %.1fs", effect.name, remaining))
            else
                table.insert(parts, effect.name)
            end
        end
    end

    if #parts == 0 then
        return label .. " : aucun"
    end

    return label .. " : " .. table.concat(parts, " / ")
end

local function ParseOrder(orderText, fallback)
    local result = {}
    local seen = {}

    for key in tostring(orderText or ""):gmatch("[^,%s]+") do
        if effectsByKey[key] and not seen[key] then
            table.insert(result, key)
            seen[key] = true
        end
    end

    for _, effect in ipairs(fallback or {}) do
        if not seen[effect.key] then
            table.insert(result, effect.key)
            seen[effect.key] = true
        end
    end

    return result
end

local function PanelTrackerOption(settings, key, destination)
    destination = destination or (settings and settings.destination)
    local panelSettings = destination and destination:match("^panel[1-4]$")
        and TSB.savedVars and TSB.savedVars.panelSettings and TSB.savedVars.panelSettings[destination]
    if panelSettings and panelSettings[key] ~= nil then return panelSettings[key] end
    return settings and settings[key]
end

local function GroupStateForUnit(effectKey, unitTag)
    local states = Module.groupActive[effectKey] or {}
    if states[unitTag] then return states[unitTag] end
    if AreUnitsEqual and AreUnitsEqual("player", unitTag) and states.player then return states.player end
    if AreUnitsEqual then
        for storedTag, state in pairs(states) do
            if DoesUnitExist(storedTag) and AreUnitsEqual(storedTag, unitTag) then return state end
        end
    end
    return nil
end

local GROUP_ROLE_ORDER = {
    [LFG_ROLE_TANK] = 1,
    [LFG_ROLE_HEAL] = 2,
    [LFG_ROLE_DPS] = 3,
}

local function GroupRole(unitTag)
    if not unitTag then return nil end
    if unitTag == "player" and GetSelectedLFGRole then
        return GetSelectedLFGRole()
    end
    if GetGroupMemberSelectedRole then
        return GetGroupMemberSelectedRole(unitTag)
    end
    return nil
end

local function SortGroupRoster(members)
    table.sort(members, function(a, b)
        local aOrder = GROUP_ROLE_ORDER[a.role] or 4
        local bOrder = GROUP_ROLE_ORDER[b.role] or 4
        if aOrder ~= bOrder then return aOrder < bOrder end
        return (tonumber(a.rosterIndex) or 99) < (tonumber(b.rosterIndex) or 99)
    end)
    return members
end

local function SpaulderGroupRoster(preview)
    local members = {}
    if preview then
        for i = 1, 5 do
            local role = i == 1 and LFG_ROLE_TANK or (i == 2 and LFG_ROLE_HEAL or LFG_ROLE_DPS)
            members[#members + 1] = {
                name = string.format("Joueur %02d", i),
                active = true,
                remaining = 12.5 - i,
                role = role,
                rosterIndex = i,
            }
        end
        return SortGroupRoster(members)
    end

    local size = GetGroupSize and tonumber(GetGroupSize()) or 0
    local maxIndex = size > 0 and zo_min(size, 12) or 1
    for i = 1, maxIndex do
        local unitTag = size > 0 and ("group" .. tostring(i)) or "player"
        if DoesUnitExist and DoesUnitExist(unitTag) then
            local state = GroupStateForUnit(SPAULDER_EFFECT_KEY, unitTag)
            local remaining = RemainingSeconds(state) or 0
            if remaining > 0 then
                members[#members + 1] = {
                    unitTag = unitTag,
                    name = (GetUnitDisplayName and GetUnitDisplayName(unitTag))
                        or (GetUnitName and GetUnitName(unitTag)) or unitTag,
                    active = true,
                    remaining = remaining,
                    endTime = state and state.endTime,
                    role = GroupRole(unitTag),
                    rosterIndex = i,
                }
                if #members >= 5 then break end
            end
        end
    end
    return SortGroupRoster(members)
end

local function GroupRoster(effectKey, preview)
    if effectKey == SPAULDER_EFFECT_KEY then return SpaulderGroupRoster(preview) end
    local members = {}
    if preview then
        for i = 1, 12 do
            local role = i <= 2 and LFG_ROLE_TANK or (i <= 4 and LFG_ROLE_HEAL or LFG_ROLE_DPS)
            members[#members + 1] = {
                name = string.format("Joueur %02d", i),
                active = i <= 7,
                remaining = i <= 7 and (14.8 - (i * 0.7)) or 0,
                role = role,
                rosterIndex = i,
            }
        end
        return SortGroupRoster(members)
    end

    local size = GetGroupSize and tonumber(GetGroupSize()) or 0
    if size <= 0 then
        local state = GroupStateForUnit(effectKey, "player")
        local remaining = RemainingSeconds(state) or 0
        members[1] = {
            unitTag = "player",
            name = (GetUnitDisplayName and GetUnitDisplayName("player")) or (GetUnitName and GetUnitName("player")) or "Joueur",
            active = remaining > 0 or (state and state.permanent == true),
            remaining = remaining,
            endTime = state and state.endTime,
            role = GroupRole("player"),
            rosterIndex = 1,
        }
        return members
    end

    for i = 1, zo_min(size, 12) do
        local unitTag = "group" .. tostring(i)
        if DoesUnitExist and DoesUnitExist(unitTag) then
            local state = GroupStateForUnit(effectKey, unitTag)
            local remaining = RemainingSeconds(state) or 0
            members[#members + 1] = {
                unitTag = unitTag,
                name = (GetUnitDisplayName and GetUnitDisplayName(unitTag)) or (GetUnitName and GetUnitName(unitTag)) or unitTag,
                active = remaining > 0 or (state and state.permanent == true),
                remaining = remaining,
                endTime = state and state.endTime,
                role = GroupRole(unitTag),
                rosterIndex = i,
            }
        end
    end
    return SortGroupRoster(members)
end

local function AppendGroupDisplayItem(items, key, effect, targetType, settings, preview)
    local groupMembers = GroupRoster(key, preview)
    local specialGroupLayout = key == SPAULDER_EFFECT_KEY
    table.insert(items, {
        key = key,
        renderKey = key .. "@group",
        name = GetDisplayName(effect),
        shortName = GetEffectShortName(effect),
        color = GetEffectColor(effect),
        icon = GetEffectIcon(effect),
        remaining = nil,
        duration = 0,
        ratio = 1,
        targetType = targetType,
        unitTag = "player",
        destination = "group",
        groupMembers = groupMembers,
        specialGroupLayout = specialGroupLayout,
        spaulderActive = specialGroupLayout and (preview == true or Module.spaulderActive == true),
        permanent = true,
        preview = preview == true,
        compact = PanelTrackerOption(settings, "compact", "group"),
        timerNoDecimals = false,
        compactTimerPosition = PanelTrackerOption(settings, "compactTimerPosition", "group") or "above",
    })
end

local function AppendDisplayItem(items, key, effect, state, targetType, settings, isCooldown, renderKey, destination)
    local remaining = RemainingSeconds(state)
    if not state.permanent and (not remaining or remaining <= 0) then return false end
    local duration = tonumber(state.duration) or remaining or 0
    table.insert(items, {
        key = key,
        renderKey = renderKey or key,
        name = GetDisplayName(effect),
        shortName = GetEffectShortName(effect),
        color = isCooldown and GetCooldownColor(effect) or GetEffectColor(effect),
        icon = state.icon or GetEffectIcon(effect),
        remaining = remaining,
        endTime = state.endTime,
        duration = duration,
        ratio = duration > 0 and (remaining / duration) or 1,
        targetType = targetType,
        unitTag = state.unitTag or (targetType == "player" and "player" or "reticleover"),
        stacks = tonumber(state.stackCount) or 0,
        isCooldown = isCooldown or nil,
        procPhase = state.procPhase,
        maxStacks = effect.maxStacks,
        destination = destination or settings.destination,
        compact = PanelTrackerOption(settings, "compact", destination),
        timerNoDecimals = PanelTrackerOption(settings, "timerNoDecimals", destination),
        compactTimerPosition = PanelTrackerOption(settings, "compactTimerPosition", destination) or "above",
        permanent = state.permanent == true,
        trialDummy = state.trialDummy == true,
    })
    return true
end

local function AppendIdleAutoSetItem(items, key, effect, targetType, settings, renderKey, destination)
    table.insert(items, {
        key = key,
        renderKey = renderKey or (key .. "@auto"),
        name = GetDisplayName(effect),
        shortName = GetEffectShortName(effect),
        color = GetEffectColor(effect),
        icon = GetEffectIcon(effect),
        remaining = 0,
        duration = 0,
        ratio = 0,
        targetType = targetType,
        unitTag = targetType == "player" and "player" or "reticleover",
        stacks = 0,
        maxStacks = effect.maxStacks,
        destination = destination or settings.destination,
        compact = PanelTrackerOption(settings, "compact", destination),
        timerNoDecimals = PanelTrackerOption(settings, "timerNoDecimals", destination),
        compactTimerPosition = PanelTrackerOption(settings, "compactTimerPosition", destination) or "above",
        autoEquipped = true,
    })
end

local function AppendClassMasteryItem(items, key, effect, targetType, settings, renderKey, destination)
    table.insert(items, {
        key = key,
        renderKey = renderKey or (key .. "@mastery"),
        name = GetDisplayName(effect),
        shortName = GetEffectShortName(effect),
        color = GetEffectColor(effect),
        icon = GetEffectIcon(effect),
        remaining = nil,
        duration = 0,
        ratio = 1,
        targetType = targetType,
        unitTag = "player",
        stacks = 0,
        destination = destination or settings.destination,
        compact = PanelTrackerOption(settings, "compact", destination),
        timerNoDecimals = PanelTrackerOption(settings, "timerNoDecimals", destination),
        compactTimerPosition = PanelTrackerOption(settings, "compactTimerPosition", destination) or "above",
        permanent = true,
        classMastery = true,
    })
end

local function BuildDisplayItems(targetType, orderText, fallback)
    local items = {}
    local active = GetBucket(targetType)
    for _, key in ipairs(ParseOrder(orderText, fallback)) do
        local effect = effectsByKey[key]
        local hasCooldown = effect and effect.cooldown and effect.cooldown > 0
        local isCooldown = false
        local settings = TSB.GetEffectSettings and TSB.GetEffectSettings(key) or {}
        local destinations = TrackerDestinations(key, false)
        local hasConfiguredDestinations = TSB.AnyTrackerDestinationConfigured and TSB.AnyTrackerDestinationConfigured(key)
        local autoEquipped = Module.autoEquipped and Module.autoEquipped[key] == true
        -- Une maîtrise sélectionnée reste toujours visible. Son aura temporaire,
        -- lorsqu'elle existe, remplace cet état de repos pendant sa durée.
        local state = active[key]
        if hasCooldown then state, isCooldown = ProcDisplayState(effect) end
        local stateRemaining = RemainingSeconds(state)
        if autoEquipped and #destinations == 0 then hasConfiguredDestinations = false end
        if effect and IsEffectEnabled(effect) and HasTrackerDestination(key, "group") and targetType == "player" then
            AppendGroupDisplayItem(items, key, effect, targetType, settings, false)
        end
        if effect and effect.classMastery and (not stateRemaining or stateRemaining <= 0)
            and IsEffectEnabled(effect) and IsClassMasteryPurchased(effect) then
            local masteryDestinations = destinations
            if #masteryDestinations == 0 then masteryDestinations = { false } end
            for _, destination in ipairs(masteryDestinations) do
                if destination ~= "group" then
                    AppendClassMasteryItem(items, key, effect, targetType, settings,
                        key .. "@mastery@" .. tostring(destination or "default"), destination)
                end
            end
        end
        if effect and IsEffectEnabled(effect) and HasTrackerDestination(key, "head") and targetType == "player" and not hasCooldown then
            for unitTag, headState in pairs(Module.headActive[key] or {}) do
                AppendDisplayItem(items, key, effect, headState, targetType, settings, false, key .. "@head@" .. unitTag, "head")
            end
        end
        -- source de la donnée : timer de cooldown (séparé) ou aura (active)
        local masteryAvailable = not effect or not effect.classMastery or IsClassMasteryPurchased(effect)
        if state and effect and masteryAvailable and IsEffectEnabled(effect) then
            local remaining = RemainingSeconds(state)
            if state.permanent or (remaining and remaining > 0) then
                local appended = false
                for _, destination in ipairs(destinations) do
                    if destination ~= "head" and destination ~= "group" then
                        AppendDisplayItem(items, key, effect, state, targetType, settings, isCooldown, key .. "@" .. destination, destination)
                        appended = true
                    end
                end
                if not hasConfiguredDestinations and not appended then
                    AppendDisplayItem(items, key, effect, state, targetType, settings, isCooldown)
                end
            else
                if hasCooldown then Module.cooldowns[key] = nil else active[key] = nil end
            end
        elseif effect and autoEquipped and effect.maxStacks and IsEffectEnabled(effect) then
            local idleDestinations = destinations
            if #idleDestinations == 0 then idleDestinations = { false } end
            for _, destination in ipairs(idleDestinations) do
                if destination ~= "head" and destination ~= "group" then
                    AppendIdleAutoSetItem(items, key, effect, targetType, settings, key .. "@auto@" .. tostring(destination or "default"), destination)
                end
            end
        end
    end

    return items
end

local function BuildPreviewItems(targetType, orderText, fallback)
    local items = {}
    local now = GetGameTimeSeconds and GetGameTimeSeconds() or 0
    local offset = 0

    for _, key in ipairs(ParseOrder(orderText, fallback)) do
        local effect = effectsByKey[key]
        if effect and IsEffectConfiguredEnabled(effect) then
            local duration = effect.cooldown and effect.cooldown > 0 and effect.cooldown
                or effect.procDuration and effect.procDuration > 0 and effect.procDuration or 16
            local remaining = duration - (offset % 5) * (duration * 0.12)
            if remaining < duration * 0.25 then remaining = duration * 0.25 end
            local stacks = 0
            if effect.maxStacks then stacks = 1 + (offset % effect.maxStacks) end
            local settings = TSB.GetEffectSettings and TSB.GetEffectSettings(key) or {}
            local previewDestinations = TrackerDestinations(key, false)
            if #previewDestinations == 0 then previewDestinations = { false } end
            for _, destination in ipairs(previewDestinations) do
            if destination == "group" then
                AppendGroupDisplayItem(items, key, effect, targetType, settings, true)
            else
            table.insert(items, {
                key = key,
                renderKey = destination and (key .. "@" .. destination) or key,
                name = GetDisplayName(effect),
                shortName = GetEffectShortName(effect),
                color = GetEffectColor(effect),
                icon = GetEffectIcon(effect),
                remaining = remaining,
                endTime = now + remaining,
                duration = duration,
                ratio = remaining / duration,
                targetType = targetType,
                unitTag = targetType == "player" and "player" or "reticleover",
                stacks = stacks,
                isCooldown = (effect.cooldown and effect.cooldown > 0) or nil,
                maxStacks = effect.maxStacks,
                preview = true,
                destination = destination or settings.destination,
                compact = PanelTrackerOption(settings, "compact", destination),
                timerNoDecimals = PanelTrackerOption(settings, "timerNoDecimals", destination),
                compactTimerPosition = PanelTrackerOption(settings, "compactTimerPosition", destination) or "above",
            })
            end
            end
            offset = offset + 1
        end
    end

    return items
end

function Module:GetDisplayItems()
    local player = BuildDisplayItems("player", TSB.savedVars and TSB.savedVars.playerOrder, effects.playerBuffs)
    local boss = BuildDisplayItems("boss", TSB.savedVars and TSB.savedVars.bossOrder, effects.bossDebuffs)
    local combined = {}

    for _, item in ipairs(player) do
        table.insert(combined, item)
    end
    for _, item in ipairs(boss) do
        table.insert(combined, item)
    end

    return {
        player = player,
        boss = boss,
        combined = combined,
    }
end

function Module:GetPreviewDisplayItems()
    local player = BuildPreviewItems("player", TSB.savedVars and TSB.savedVars.playerOrder, effects.playerBuffs)
    local boss = BuildPreviewItems("boss", TSB.savedVars and TSB.savedVars.bossOrder, effects.bossDebuffs)
    local combined = {}

    for _, item in ipairs(player) do
        table.insert(combined, item)
    end
    for _, item in ipairs(boss) do
        table.insert(combined, item)
    end

    return {
        player = player,
        boss = boss,
        combined = combined,
    }
end

function TSB.GetDisplayItems()
    if TSB.modules.MajorEffects and TSB.modules.MajorEffects.GetDisplayItems then
        return TSB.modules.MajorEffects:GetDisplayItems()
    end
    return { player = {}, boss = {}, combined = {} }
end

function TSB.GetPreviewDisplayItems()
    if TSB.modules.MajorEffects and TSB.modules.MajorEffects.GetPreviewDisplayItems then
        return TSB.modules.MajorEffects:GetPreviewDisplayItems()
    end
    return { player = {}, boss = {}, combined = {} }
end

function Module:PrintStatus()
    self:Scan()
    TSB.Chat(BuildLine("player", "Buffs du joueur", effects.playerBuffs))
    TSB.Chat(BuildLine("boss", "Débuffs des boss", effects.bossDebuffs))
end

-- Auras du joueur hors filtres d'id : APPRENTISSAGE PAR NOM.
-- Les ids des maîtrises de classe (U50) varient selon le rang/patch et ne sont pas
-- fiables dans le catalogue. Si le nom localisé (FR ou EN) d'une aura du joueur
-- correspond à une entrée, l'id réel est appris, mémorisé dans les SavedVariables
-- et l'événement est traité immédiatement.
local function OnPlayerAuraLearn(...)
    local _, changeType, _, effectName = ...
    local abilityId = select(16, ...)
    if not abilityId or abilityId == 0 or registeredIds[abilityId] then return end
    local effect = effectById[abilityId]
    if not effect then
        effect = effectByLocalizedName[NormalizeName(effectName)]
        if effect then
            effectById[abilityId] = effect
            if TSB.savedVars then
                TSB.savedVars.learnedAbilityIds = TSB.savedVars.learnedAbilityIds or {}
                TSB.savedVars.learnedAbilityIds[abilityId] = effect.key
            end
            if TSB.savedVars and TSB.savedVars.debug then
                TSB.Chat(string.format("[learn] %s <- id=%s (%s)", tostring(effect.key), tostring(abilityId), tostring(effectName)))
            end
        end
    end
    if effect then
        OnEffectChanged(...)
        return
    end
    -- debug : aura du joueur inconnue du catalogue, montrer nom + id pour diagnostic
    if TSB.savedVars and TSB.savedVars.debug and changeType == EFFECT_RESULT_GAINED and not seenAuras[abilityId] then
        seenAuras[abilityId] = true
        TSB.Chat(string.format("[aura] %s | id=%s", tostring(effectName), tostring(abilityId)))
    end
end

function Module:Load(savedVars)
    lifecycleActive = true
    self.savedVars = savedVars or {}
    self.active = { player = {}, boss = {} }
    self.headActive = {}
    self.groupActive = {}
    self.cooldowns = {}
    self.autoEquipped = {}
    self.spaulderActive = false
    seenDmg = {}
    seenAuras = {}

    self:RefreshAutoEquippedSets()

    -- ids appris lors de sessions précédentes (correspondance par nom)
    if TSB.savedVars and TSB.savedVars.learnedAbilityIds then
        for abilityId, key in pairs(TSB.savedVars.learnedAbilityIds) do
            local id, effect = tonumber(abilityId), effectsByKey[key]
            if id and effect and not effectById[id] then
                effectById[id] = effect
                table.insert(self.abilityIds, id)
            end
        end
    end

    for _, abilityId in ipairs(self.abilityIds or {}) do
        local eventName = EVENT_PREFIX .. tostring(abilityId)
        EM:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, function(...)
            TSB.SafeCall(MODULE_NAME, "OnEffectChanged", OnEffectChanged, ...)
        end)
        EM:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
        registeredIds[abilityId] = true
    end

    -- écoute non filtrée par id, restreinte au joueur, pour l'apprentissage par nom
    local learnName = EVENT_PREFIX .. "AuraLearn"
    EM:RegisterForEvent(learnName, EVENT_EFFECT_CHANGED, function(...)
        TSB.SafeCall(MODULE_NAME, "OnPlayerAuraLearn", OnPlayerAuraLearn, ...)
    end)
    EM:AddFilterForEvent(learnName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    -- journal de combat : détecte les procs de dégâts purs sans aura + alimente le
    -- logger debug [dmg]. On écoute la source JOUEUR *et* ses FAMILIERS/INVOCATIONS,
    -- car certains sets (Maarselok, etc.) infligent leurs dégâts via une invocation
    -- dont la source n'est pas le joueur directement.
    local combatSources = { COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET }
    for i, srcType in ipairs(combatSources) do
        if srcType ~= nil then
            local cn = EVENT_PREFIX .. "Combat" .. tostring(i)
            EM:RegisterForEvent(cn, EVENT_COMBAT_EVENT, function(...)
                TSB.SafeCall(MODULE_NAME, "OnCombatEvent", OnCombatEvent, ...)
            end)
            EM:AddFilterForEvent(cn, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, srcType)
        end
    end

    local spaulderEvent = EVENT_PREFIX .. "SpaulderToggle"
    EM:RegisterForEvent(spaulderEvent, EVENT_COMBAT_EVENT, function(...)
        TSB.SafeCall(MODULE_NAME, "OnSpaulderToggle", OnSpaulderToggle, ...)
    end)
    EM:AddFilterForEvent(spaulderEvent, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_ABILITY_ID, SPAULDER_TOGGLE_ABILITY_ID)
    EM:AddFilterForEvent(spaulderEvent, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(EVENT_PREFIX .. "Bosses", EVENT_BOSSES_CHANGED, function()
        TSB.SafeCall(MODULE_NAME, "Scan", function() self:Scan() end)
    end)

    EM:RegisterForEvent(EVENT_PREFIX .. "Reticle", EVENT_RETICLE_TARGET_CHANGED, function()
        TSB.SafeCall(MODULE_NAME, "Scan", function() self:Scan() end)
    end)

    EM:RegisterForEvent(EVENT_PREFIX .. "Equipment", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId)
        if bagId == BAG_WORN then
            TSB.SafeCall(MODULE_NAME, "Equipment", function()
                self:RefreshAutoEquippedSets()
                self:Scan()
            end)
        end
    end)
    EM:AddFilterForEvent(EVENT_PREFIX .. "Equipment", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)

    EM:RegisterForUpdate(SCAN_UPDATE, 500, function()
        TSB.SafeCall(MODULE_NAME, "Scan", function() self:Scan() end)
    end)

    -- À l'entrée d'un champ de bataille, les tags du groupe et le HUD sont
    -- reconstruits après le chargement de zone. Une resynchronisation différée
    -- évite de conserver les anciens tags et réaffiche immédiatement les trackers.
    EM:RegisterForEvent(EVENT_PREFIX .. "PlayerActivated", EVENT_PLAYER_ACTIVATED, QueueLifecycleRefresh)
    if EVENT_GROUP_UPDATE then
        EM:RegisterForEvent(EVENT_PREFIX .. "GroupUpdate", EVENT_GROUP_UPDATE, QueueLifecycleRefresh)
    end
    if EVENT_BATTLEGROUND_STATE_CHANGED then
        EM:RegisterForEvent(EVENT_PREFIX .. "BattlegroundState", EVENT_BATTLEGROUND_STATE_CHANGED, QueueLifecycleRefresh)
    end

    zo_callLater(function()
        TSB.SafeCall(MODULE_NAME, "Scan", function() self:Scan() end)
    end, 800)

    if TSB.savedVars and TSB.savedVars.debug then
        TSB.Chat(string.format("détection debug ACTIVE : %d IDs surveillés. Tape sur une vraie cible (le MODE TEST n'en génère pas).", #(self.abilityIds or {})))
    end
end

function Module:Unload()
    lifecycleActive = false
    lifecycleRefreshQueued = false
    for _, abilityId in ipairs(self.abilityIds or {}) do
        EM:UnregisterForEvent(EVENT_PREFIX .. tostring(abilityId), EVENT_EFFECT_CHANGED)
    end
    EM:UnregisterForEvent(EVENT_PREFIX .. "Bosses", EVENT_BOSSES_CHANGED)
    EM:UnregisterForEvent(EVENT_PREFIX .. "Reticle", EVENT_RETICLE_TARGET_CHANGED)
    EM:UnregisterForEvent(EVENT_PREFIX .. "Equipment", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EM:UnregisterForEvent(EVENT_PREFIX .. "Combat1", EVENT_COMBAT_EVENT)
    EM:UnregisterForEvent(EVENT_PREFIX .. "Combat2", EVENT_COMBAT_EVENT)
    EM:UnregisterForEvent(EVENT_PREFIX .. "SpaulderToggle", EVENT_COMBAT_EVENT)
    EM:UnregisterForEvent(EVENT_PREFIX .. "PlayerActivated", EVENT_PLAYER_ACTIVATED)
    if EVENT_GROUP_UPDATE then
        EM:UnregisterForEvent(EVENT_PREFIX .. "GroupUpdate", EVENT_GROUP_UPDATE)
    end
    if EVENT_BATTLEGROUND_STATE_CHANGED then
        EM:UnregisterForEvent(EVENT_PREFIX .. "BattlegroundState", EVENT_BATTLEGROUND_STATE_CHANGED)
    end
    EM:UnregisterForUpdate(SCAN_UPDATE)
    self.active = { player = {}, boss = {} }
    self.headActive = {}
    self.groupActive = {}
    self.cooldowns = {}
    self.autoEquipped = {}
    self.spaulderActive = false
    TSB.NotifyDisplayChanged()
end

TSB.RegisterModule(Module)
