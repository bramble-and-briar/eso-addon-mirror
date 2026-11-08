-- Effect store: upsert/remove/expire, filtering, list management and sorting.
local BEV = BetterEffectViewer

---------------------------------------------------------------------------
-- Filter lists
---------------------------------------------------------------------------

function BEV:GetListSize(listName)
    self.listSizes = self.listSizes or {}
    local size = self.listSizes[listName]
    if not size then
        size = NonContiguousCount(self.sv[listName])
        self.listSizes[listName] = size
    end
    return size
end

-- Adds or removes ability ids from "whitelist" / "blacklist". Returns how many changed.
function BEV:EditList(listName, ids, add)
    local list = self.sv[listName]
    local changed = 0
    for _, id in ipairs(ids) do
        if add and not list[id] then
            list[id] = true
            changed = changed + 1
        elseif not add and list[id] then
            list[id] = nil
            changed = changed + 1
        end
    end
    if changed > 0 then
        self.listSizes = nil
        self:OnFilterChanged()
    end
    return changed
end

function BEV:ClearList(listName)
    ZO_ClearTable(self.sv[listName])
    self.listSizes = nil
    self:OnFilterChanged()
end

-- Drops tracked effects the current filter no longer allows, then rescans so
-- newly allowed ones appear straight away.
function BEV:OnFilterChanged()
    for key, effect in pairs(self.effects) do
        if not self:IsEffectAllowed(effect.abilityId) then
            self:RemoveEffect(key)
        end
    end
    self.needsRedraw = true
    self:RequestRescan(0)
end

function BEV:ParseAbilityIds(text)
    local ids = {}
    for token in tostring(text or ""):gmatch("%d+") do
        ids[#ids + 1] = tonumber(token)
    end
    return ids
end

function BEV:IsEffectAllowed(abilityId)
    local mode = self.sv.filterMode
    if mode == "whitelist" then
        return self.sv.whitelist[abilityId] == true
    elseif mode == "blacklist" then
        return not self.sv.blacklist[abilityId]
    end
    return true
end

function BEV:TryAutoWhitelist(abilityId, startTime, endTime)
    local sv = self.sv
    if not sv.autoWhitelist or sv.filterMode ~= "whitelist" or sv.whitelist[abilityId] then
        return
    end
    if not startTime or not endTime or endTime == 0 then
        return
    end
    if endTime - startTime < sv.autoWhitelistDuration then
        return
    end
    if self:GetListSize("whitelist") >= sv.maxWhitelistSize then
        return
    end

    sv.whitelist[abilityId] = true
    self.listSizes.whitelist = self.listSizes.whitelist + 1
end

---------------------------------------------------------------------------
-- Effect store
---------------------------------------------------------------------------

function BEV:ResetEffects()
    ZO_ClearTable(self.effects)
    self.effectCount = 0
    self.needsRedraw = true
end

function BEV:RemoveEffect(key)
    if self.effects[key] == nil then
        return false
    end
    self.effects[key] = nil
    self.effectCount = math.max(0, self.effectCount - 1)
    return true
end

-- Inserts or refreshes an effect. `scanId` is set when called from a full rescan.
-- Returns true when something that affects the display changed.
function BEV:UpsertEffect(name, abilityId, iconName, effectType, startTime, endTime, stackCount, castByPlayer, now, scanId)
    if effectType ~= BUFF_EFFECT_TYPE_BUFF and effectType ~= BUFF_EFFECT_TYPE_DEBUFF then
        return false
    end

    castByPlayer = castByPlayer == true
    local key = self:MakeEffectKey(abilityId, effectType)
    local effect = self.effects[key]
    local changed

    if effect then
        -- When several sources apply the same ability, prefer the player's copy.
        if effect.castByPlayer and not castByPlayer then
            if scanId and effect.scanId == scanId then
                return false
            end
            if not scanId and not effect.isPermanent and effect.endTime > now then
                return false
            end
        end

        changed = effect.endTime ~= endTime
            or effect.stackCount ~= stackCount
            or effect.castByPlayer ~= castByPlayer
            or effect.iconName ~= iconName
    else
        self:TryAutoWhitelist(abilityId, startTime, endTime)
        if not self:IsEffectAllowed(abilityId) then
            return false
        end
        local cap = self.runtime.effectCap
        if cap and self.effectCount >= cap then
            return false
        end

        effect = { key = key }
        self.effects[key] = effect
        self.effectCount = self.effectCount + 1
        changed = true
    end

    effect.name = name
    effect.abilityId = abilityId
    effect.iconName = iconName
    effect.effectType = effectType
    effect.startTime = startTime or 0
    effect.endTime = endTime or 0
    effect.stackCount = stackCount or 0
    effect.castByPlayer = castByPlayer
    effect.isPermanent = self:IsPermanentEffect(startTime, endTime)
    effect.lastSeen = now
    effect.scanId = scanId or effect.scanId

    return changed
end

-- Drops timed effects that ran out more than half a second ago.
function BEV:CleanupExpiredEffects(now)
    local changed = false
    for key, effect in pairs(self.effects) do
        if not effect.isPermanent and now > effect.endTime + 0.5 then
            self.effects[key] = nil
            self.effectCount = math.max(0, self.effectCount - 1)
            changed = true
        end
    end
    return changed
end

---------------------------------------------------------------------------
-- Colors
---------------------------------------------------------------------------

function BEV:GetColorsForEffect(effect)
    local sv = self.sv
    local timerColor
    if effect.isPermanent then
        timerColor = sv.permanentTimerColor
    elseif effect.effectType == BUFF_EFFECT_TYPE_BUFF then
        timerColor = sv.buffTimerColor
    else
        timerColor = sv.debuffTimerColor
    end

    if effect.castByPlayer then
        return sv.playerEffectBorderColor, timerColor
    elseif effect.isPermanent then
        return sv.permanentBorderColor, timerColor
    elseif effect.effectType == BUFF_EFFECT_TYPE_BUFF then
        return sv.buffBorderColor, timerColor
    end
    return sv.debuffBorderColor, timerColor
end

---------------------------------------------------------------------------
-- Sorting (comparators are built once; ties fall back to the key so icons
-- never swap places between redraws)
---------------------------------------------------------------------------

local sortNow = 0

local function remainingOf(effect)
    if effect.isPermanent then
        return math.huge
    end
    return effect.endTime - sortNow
end

local COMPARATORS = {
    shortest = function(a, b)
        local ra, rb = remainingOf(a), remainingOf(b)
        if ra ~= rb then
            return ra < rb
        end
        return a.key < b.key
    end,
    longest = function(a, b)
        local ra, rb = remainingOf(a), remainingOf(b)
        if ra ~= rb then
            return ra > rb
        end
        return a.key < b.key
    end,
    newest = function(a, b)
        if a.startTime ~= b.startTime then
            return a.startTime > b.startTime
        end
        return a.key < b.key
    end,
    oldest = function(a, b)
        if a.startTime ~= b.startTime then
            return a.startTime < b.startTime
        end
        return a.key < b.key
    end,
}

local activeComparator = COMPARATORS.shortest

local function playerFirstComparator(a, b)
    if a.castByPlayer ~= b.castByPlayer then
        return a.castByPlayer
    end
    return activeComparator(a, b)
end

function BEV:SortEffects(list, now)
    sortNow = now
    activeComparator = COMPARATORS[self.sv.sortMode] or COMPARATORS.shortest
    table.sort(list, self.sv.playerEffectsFirst and playerFirstComparator or activeComparator)
end
