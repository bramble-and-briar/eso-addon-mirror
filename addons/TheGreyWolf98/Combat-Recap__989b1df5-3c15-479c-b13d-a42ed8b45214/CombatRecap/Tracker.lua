local C = CombatRecap
local T = { pending = {}, lightIds = {} }
C.Tracker = T
local function now() return GetGameTimeMilliseconds() end
local function clean(name)
    return zo_strformat("<<1>>", name or "Unknown")
end

function T:DiscoverLightAttacks()
    self.lightIds = {}
    self.lightNames = {}
    for _, bar in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        local id = GetSlotBoundId(1, bar)
        if id and id > 0 then
            self.lightIds[id] = true
            local name = clean(GetAbilityName(id)):lower()
            if name ~= "" then self.lightNames[name] = true end
        end
    end
end

function T:SnapshotEffects()
    if not self.fight then return end
    for i = 1, GetNumBuffs("player") do
        local name, _, _, slot, _, _, _, effectType, _, _, id = GetUnitBuffInfo("player", i)
        if id and id > 0 then
            C.EffectChange(self.fight, now(), slot, id, clean(name),
                effectType == BUFF_EFFECT_TYPE_DEBUFF and "Debuff" or "Buff", true)
        end
    end
end

function T:SnapshotGear()
    local gear = {}
    local slots = {
        {EQUIP_SLOT_MAIN_HAND, "Front weapon"}, {EQUIP_SLOT_OFF_HAND, "Front off-hand"},
        {EQUIP_SLOT_BACKUP_MAIN, "Back weapon"}, {EQUIP_SLOT_BACKUP_OFF, "Back off-hand"},
        {EQUIP_SLOT_HEAD, "Head"}, {EQUIP_SLOT_SHOULDERS, "Shoulders"},
        {EQUIP_SLOT_CHEST, "Chest"}, {EQUIP_SLOT_HAND, "Hands"},
        {EQUIP_SLOT_WAIST, "Waist"}, {EQUIP_SLOT_LEGS, "Legs"}, {EQUIP_SLOT_FEET, "Feet"},
        {EQUIP_SLOT_NECK, "Neck"}, {EQUIP_SLOT_RING1, "Ring 1"}, {EQUIP_SLOT_RING2, "Ring 2"},
    }
    for _, spec in ipairs(slots) do
        local link = GetItemLink(BAG_WORN, spec[1], LINK_STYLE_DEFAULT)
        local trait, enchant, name = "—", "—", "Empty"
        if link and link ~= "" then
            name = clean(GetItemLinkName(link))
            local traitId = GetItemLinkTraitInfo(link)
            trait = GetString("SI_ITEMTRAITTYPE", traitId)
            local _, header = GetItemLinkEnchantInfo(link)
            enchant = clean(header)
        end
        gear[#gear + 1] = { slot = spec[2], name = name, trait = trait, enchant = enchant }
    end
    return gear
end

-- Classify only when ESO exposes a matching live unit tag. Never infer a boss
-- from damage or duration; unknown targets remain manually accessible via /recap.
local function sameTarget(tag, targetName)
    if not DoesUnitExist or not DoesUnitExist(tag) then return false end
    local unitName = GetUnitName(tag)
    return unitName and unitName ~= "" and clean(unitName):lower() == clean(targetName):lower()
end

function T:QualifyingTarget(targetName)
    for i = 1, 6 do
        if sameTarget("boss" .. i, targetName) then return true end
    end
    if sameTarget("reticleover", targetName) then
        if IsUnitBoss and IsUnitBoss("reticleover") then return true end
        if GetUnitClassification then
            local classification = GetUnitClassification("reticleover")
            if (UNIT_CLASSIFICATION_ELITE and classification == UNIT_CLASSIFICATION_ELITE)
                or (UNIT_CLASSIFICATION_CHAMPION and classification == UNIT_CLASSIFICATION_CHAMPION)
                or (UNIT_CLASSIFICATION_BOSS and classification == UNIT_CLASSIFICATION_BOSS) then
                return true
            end
        end
        if IsUnitAttackable and not IsUnitAttackable("reticleover") then return false end
    end
    -- ESO training dummies are furnishing NPCs with varying localized names.
    -- Detect only explicit dummy/training-target names; others remain manual.
    local n = clean(targetName):lower()
    return n:find("target dummy", 1, true) ~= nil
        or n:find("training dummy", 1, true) ~= nil
        or n:find("trial dummy", 1, true) ~= nil
end

function T:Start(time)
    if self.suspended then return false end
    self.fight = C.NewFight(time, {
        timestamp = GetTimeStamp(), character = clean(GetUnitName("player")),
        zone = clean(GetUnitZone("player")),
    })
    self.fight.gear = self:SnapshotGear()
    self.fight.build = CombatRecapBuild.Capture()
    self:DiscoverLightAttacks()
    self:SnapshotEffects()
    -- A tiny input lookback captures the opening attack before its damage lands.
    -- These totals are labelled observations, not a cast success count.
    for _, e in ipairs(self.pending) do
        if time - e.time <= 1500 then C.RecordInput(self.fight, e.time, e.kind, e.duration) end
    end
    self.pending = {}
    EVENT_MANAGER:RegisterForUpdate("CombatRecap_EndCheck", 500, function() self:Tick() end)
    return true
end

function T:Finish(reason)
    if not self.fight then return end
    local f = self.fight
    self.fight = nil
    EVENT_MANAGER:UnregisterForUpdate("CombatRecap_EndCheck")
    self.pending = {}
    if f.damage <= 0 then return end
    local eligible = f.qualifyingTarget == true
    C.SaveFight(C.saved.history, C.FinishFight(f, reason))
    local duration = C.saved.history[1].duration
    if eligible and C.saved.automaticChat ~= false then
        d(string.format("|cD85757Combat Recap|r: %.0f DPS / %.1fs. Type /recap.", f.damage / duration, duration))
    end
end

function T:EncounterInProgress()
    if IsUnitInCombat("player") then return true end
    -- This only keeps a personal encounter together while dead or during phases;
    -- no group performance or group combat events are collected.
    for i = 1, GetGroupSize() do
        local tag = ZO_Group_GetUnitTagForGroupIndex(i)
        if tag and IsUnitOnline(tag) and IsUnitInCombat(tag) then return true end
    end
    for i = 1, 6 do
        local tag = "boss" .. i
        if DoesUnitExist(tag) and not IsUnitDeadOrReincarnating(tag) and IsUnitInCombat(tag) then return true end
    end
    return false
end

function T:Tick()
    if not self.fight then return end
    if not self:EncounterInProgress() and now() - self.fight.lastMs >= 1500 then
        self:Finish("Combat ended")
    end
end

function T:Damage(_, result, isError, abilityName, _, slotType, _, sourceType,
    targetName, targetType, hitValue, _, _, _, _, targetId, abilityId)
    if isError or not hitValue or hitValue <= 0 or self.suspended then return end
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET then return end
    if not self.damageResults[result] then return end
    if targetType == COMBAT_UNIT_TYPE_PLAYER or targetType == COMBAT_UNIT_TYPE_PLAYER_PET or
        targetType == COMBAT_UNIT_TYPE_PLAYER_COMPANION or targetType == COMBAT_UNIT_TYPE_GROUP then return end
    local time = now()
    if not self.fight and not self:Start(time) then return end
    local pet = sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
    local eventName = clean(abilityName):lower()
    local nameMatch = self.lightNames and self.lightNames[eventName]
    if not nameMatch then
        for base in pairs(self.lightNames or {}) do
            if eventName:sub(1, #base + 2) == base .. " (" then nameMatch = true; break end
        end
    end
    local attack
    if not pet then
        if slotType == ACTION_SLOT_TYPE_LIGHT_ATTACK or self.lightIds[abilityId] or nameMatch then attack = "light"
        elseif slotType == ACTION_SLOT_TYPE_HEAVY_ATTACK then attack = "heavy" end
    end
    local name = clean(abilityName)
    if name == "" then name = clean(GetAbilityName(abilityId or 0)) end
    if name == "" then name = "Ability " .. tostring(abilityId) end
    if pet then name = name .. " (pet)" end
    local target = clean(targetName)
    if target == "" then target = "Unknown target" end
    local targetKey = targetId and targetId ~= 0 and tostring(targetId) or target
    if not self.fight.qualifyingTarget and self:QualifyingTarget(target) then
        self.fight.qualifyingTarget = true
    end
    C.RecordDamage(self.fight, time, tostring(abilityId or name) .. (pet and ":pet" or ":player"),
        name, targetKey, target, hitValue, self.critResults[result], self.dotResults[result], pet, attack)
end

function T:Input(_, slot)
    if self.suspended or type(slot) ~= "number" then return end
    local kind, duration
    if slot == 1 then
        kind = "light"
        local id = GetSlotBoundId(1)
        if id and id > 0 then self.lightIds[id] = true end
    elseif slot == 2 then kind = "heavy"
    elseif slot == 8 then kind = "ultimate"
    elseif slot >= 3 and slot <= 7 then
        kind = "skill"
        local id = GetSlotBoundId(slot)
        if GetSlotType(slot) == ACTION_TYPE_CRAFTED_ABILITY then
            id = GetAbilityIdForCraftedAbilityId(id)
        end
        if id and id > 0 then _, duration = GetAbilityCastInfo(id, nil, "player") end
    end
    if not kind then return end
    if self.fight then C.RecordInput(self.fight, now(), kind, duration)
    else
        self.pending[#self.pending + 1] = { time = now(), kind = kind, duration = duration }
        while #self.pending > 16 do table.remove(self.pending, 1) end
    end
end

function T:Effect(_, change, slot, name, unitTag, _, _, _, _, _, effectType, _, _, _, _, id)
    if not self.fight or unitTag ~= "player" or not id or id <= 0 then return end
    C.EffectChange(self.fight, now(), slot, id, clean(name),
        effectType == BUFF_EFFECT_TYPE_DEBUFF and "Debuff" or "Buff", change ~= EFFECT_RESULT_FADED)
end

function T:Initialize()
    self.damageResults, self.critResults, self.dotResults = {}, {}, {}
    local damage = { ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE,
        ACTION_RESULT_DOT_TICK, ACTION_RESULT_DOT_TICK_CRITICAL, ACTION_RESULT_BLOCKED_DAMAGE,
        ACTION_RESULT_PRECISE_DAMAGE, ACTION_RESULT_WRECKING_DAMAGE }
    self.critResults[ACTION_RESULT_CRITICAL_DAMAGE] = true
    self.critResults[ACTION_RESULT_DOT_TICK_CRITICAL] = true
    self.dotResults[ACTION_RESULT_DOT_TICK] = true
    self.dotResults[ACTION_RESULT_DOT_TICK_CRITICAL] = true
    for index, result in ipairs(damage) do
        self.damageResults[result] = true
        for sourceIndex, source in ipairs({ COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET }) do
            local key = "CombatRecap_Damage_" .. index .. "_" .. sourceIndex
            EVENT_MANAGER:RegisterForEvent(key, EVENT_COMBAT_EVENT, function(...) self:Damage(...) end)
            EVENT_MANAGER:AddFilterForEvent(key, EVENT_COMBAT_EVENT,
                REGISTER_FILTER_COMBAT_RESULT, result,
                REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, source,
                REGISTER_FILTER_IS_ERROR, false)
        end
    end
    EVENT_MANAGER:RegisterForEvent("CombatRecap_Input", EVENT_ACTION_SLOT_ABILITY_USED, function(...) self:Input(...) end)
    EVENT_MANAGER:RegisterForEvent("CombatRecap_Effects", EVENT_EFFECT_CHANGED, function(...) self:Effect(...) end)
    EVENT_MANAGER:AddFilterForEvent("CombatRecap_Effects", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent("CombatRecap_EffectsSync", EVENT_EFFECTS_FULL_UPDATE, function()
        if self.fight then
            local slots = {}
            for slot, id in pairs(self.fight.activeSlots or {}) do slots[#slots + 1] = {slot, id} end
            for _, e in ipairs(slots) do C.EffectChange(self.fight, now(), e[1], e[2], "", "", false) end
            self:SnapshotEffects()
        end
    end)
    EVENT_MANAGER:RegisterForEvent("CombatRecap_Combat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat then self.suspended = false; self:Tick()
        else self:DiscoverLightAttacks() end
    end)
    EVENT_MANAGER:RegisterForEvent("CombatRecap_Activated", EVENT_PLAYER_ACTIVATED, function()
        self:Finish("Zone/load boundary"); self.suspended = false; self.pending = {}; self:DiscoverLightAttacks()
    end)
    EVENT_MANAGER:RegisterForEvent("CombatRecap_Deactivated", EVENT_PLAYER_DEACTIVATED, function()
        self:Finish("Zone/logout boundary")
    end)
    self:DiscoverLightAttacks()
end
