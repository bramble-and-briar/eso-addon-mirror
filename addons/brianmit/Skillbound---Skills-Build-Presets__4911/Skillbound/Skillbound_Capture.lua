-- Skillbound_Capture.lua : reads what you wear now into a build.
--
-- A build (sv.builds[id]):
--   id, name, folder, icon (texture, nil = automatic), note, classId, owner (character name),
--   parent (id: this build is a "layer" on top of that one), created, updated,
--   parts = { gear, skills, cp, food, quick, outfit, title, collect, companion } (true = wearing the
--           build changes that part),
--   gear[equipSlot] = piece (see Items.Info, + uid); a slot that's missing isn't touched,
--   skills[0 front / 1 back][3..8] = { id, name, line, crafted },
--   cp = { slots = { [1..12] = star id } } (One Click Champion Points setups were removed in 0.6.5),
--   food = { id, link }, quick[1..8] = { kind = "item"|"simple", id, link, type },
--   outfit = { index, name }, title = { name }, collect = { [category type] = collectible id },
--   mundus = { ability ids }, companion = { gear = {...}, skills = { [3..8] = {...} } },
--   stats = { hp, mag, stam, dmg, pen, res, t } (recorded the last time it was worn).

local B = Skillbound
local L = B.L
local Items = B.Items
local Capture = {}
B.Capture = Capture

Capture.PARTS = { "gear", "skills", "cp", "food", "quick", "outfit", "title", "collect", "companion" }
-- what a new build changes when you wear it (the rest is saved too and can be turned on)
Capture.DEFAULT_PARTS = { gear = true, skills = true, cp = true, food = true }

Capture.BARS = { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }
Capture.FIRST_SLOT, Capture.ULT_SLOT = 3, 8   -- skill slots 3-7 + ultimate 8 (live client numbering)

-- Mundus stone buffs (ability ids): Warrior, Mage, Serpent, Thief, Lady, Steed, Lord,
-- Apprentice, Ritual, Lover, Atronach, Shadow, Tower
Capture.MUNDUS = {
    [13940] = true, [13943] = true, [13974] = true, [13975] = true, [13976] = true, [13977] = true,
    [13978] = true, [13979] = true, [13980] = true, [13981] = true, [13982] = true, [13984] = true, [13985] = true,
}

Capture.COLLECT = {
    { type = COLLECTIBLE_CATEGORY_TYPE_MOUNT, key = "COLLECT_MOUNT" },
    { type = COLLECTIBLE_CATEGORY_TYPE_VANITY_PET, key = "COLLECT_PET" },
    { type = COLLECTIBLE_CATEGORY_TYPE_COSTUME, key = "COLLECT_COSTUME" },
}

local ACTOR = GAMEPLAY_ACTOR_CATEGORY_PLAYER

-- ---------------------------------------------------------------------------

function Capture.Piece(bag, slot)
    local link = GetItemLink(bag, slot)
    if link == "" then return nil end
    local p = Items.Info(link)
    p.uid = Items.Uid(bag, slot)
    return p
end

function Capture.Gear(bag)
    bag = bag or BAG_WORN
    local gear = {}
    for _, s in ipairs(Items.SLOTS) do
        gear[s] = Capture.Piece(bag, s)
    end
    return gear
end

-- skill line name of an ability, nil when this character doesn't have it
function Capture.LineOf(abilityId)
    local p = SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(abilityId)
    if not p then return nil end
    local ok, name = pcall(function() return p:GetSkillData():GetSkillLineData():GetName() end)
    return ok and name or nil
end

function Capture.SlotSkill(cat, slot)
    local id = GetSlotBoundId(slot, cat)
    local slotType = GetSlotType(slot, cat)
    if not id or id == 0 or slotType == ACTION_TYPE_NOTHING then return nil end
    local e = { id = id }
    if ACTION_TYPE_CRAFTED_ABILITY and slotType == ACTION_TYPE_CRAFTED_ABILITY then
        -- scribed skill: the slot holds the crafted ability; keep both ids
        e.crafted = id
        if GetAbilityIdForCraftedAbilityId then e.id = GetAbilityIdForCraftedAbilityId(id) end
    end
    e.name = B.Name(GetAbilityName(e.id))
    if e.crafted and GetCraftedAbilityDisplayName then
        local ok, n = pcall(GetCraftedAbilityDisplayName, e.crafted)
        if ok and n and n ~= "" then e.name = B.Name(n) end
    end
    e.line = Capture.LineOf(e.id)
    return e
end

function Capture.Skills()
    local skills = {}
    for _, cat in ipairs(Capture.BARS) do
        local bar = {}
        for slot = Capture.FIRST_SLOT, Capture.ULT_SLOT do
            bar[slot] = Capture.SlotSkill(cat, slot)
        end
        skills[cat] = bar
    end
    return skills
end

function Capture.CP()
    local slots = {}
    for i = 1, 12 do
        local id = GetSlotBoundId(i, HOTBAR_CATEGORY_CHAMPION)
        if id and id ~= 0 then slots[i] = id end
    end
    return { slots = slots }
end

-- the food whose buff is running (learned buffs first), else the last food you ate
function Capture.Food()
    local known = {}
    for itemId, abilityId in pairs(B.sv.foodBuffs) do known[abilityId] = itemId end
    for i = 1, GetNumBuffs("player") do
        local abilityId = select(11, GetUnitBuffInfo("player", i))
        local itemId = known[abilityId]
        if itemId then
            local last = B.Char().lastFood
            return { id = itemId, link = last and last.id == itemId and last.link or nil }
        end
    end
    local last = B.Char().lastFood
    if last then return { id = last.id, link = last.link } end
    return nil
end

function Capture.Quick()
    if not HOTBAR_CATEGORY_QUICKSLOT_WHEEL then return nil end
    local cat = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
    local quick = {}
    for i = 1, (ACTION_BAR_UTILITY_BAR_SIZE or 8) do
        local slotType = GetSlotType(i, cat)
        if slotType == ACTION_TYPE_ITEM then
            local link = GetSlotItemLink and GetSlotItemLink(i, cat) or ""
            if link ~= "" then quick[i] = { kind = "item", id = GetItemLinkItemId(link), link = link } end
        elseif slotType and slotType ~= ACTION_TYPE_NOTHING then
            local id = GetSlotBoundId(i, cat)
            if id and id ~= 0 then quick[i] = { kind = "simple", type = slotType, id = id } end
        end
    end
    return quick
end

function Capture.Outfit()
    if not GetEquippedOutfitIndex then return nil end
    local index = GetEquippedOutfitIndex(ACTOR)
    if not index then return { index = 0 } end
    return { index = index, name = GetOutfitName and GetOutfitName(ACTOR, index) or nil }
end

function Capture.Title()
    if not GetCurrentTitleIndex then return nil end
    local index = GetCurrentTitleIndex()
    if not index or index == 0 then return { name = "" } end
    return { name = GetTitle(index) }
end

function Capture.Collect()
    if not GetActiveCollectibleByType then return nil end
    local t = {}
    for _, c in ipairs(Capture.COLLECT) do
        if c.type then
            local ok, id = pcall(GetActiveCollectibleByType, c.type, ACTOR)
            if ok and id and id ~= 0 then t[c.type] = id end
        end
    end
    return t
end

function Capture.Mundus()
    local list = {}
    for i = 1, GetNumBuffs("player") do
        local abilityId = select(11, GetUnitBuffInfo("player", i))
        if Capture.MUNDUS[abilityId] then list[#list + 1] = abilityId end
    end
    table.sort(list)
    return list
end

function Capture.Companion()
    if not (HasActiveCompanion and HasActiveCompanion()) or not BAG_COMPANION_WORN then return nil end
    local c = { gear = {}, skills = {} }
    for _, s in ipairs(Items.SLOTS) do
        if not Items.POISON[s] and not Items.BACK[s] then
            c.gear[s] = Capture.Piece(BAG_COMPANION_WORN, s)
        end
    end
    if HOTBAR_CATEGORY_COMPANION then
        for slot = Capture.FIRST_SLOT, Capture.ULT_SLOT do
            local id = GetSlotBoundId(slot, HOTBAR_CATEGORY_COMPANION)
            if id and id ~= 0 then c.skills[slot] = { id = id, name = B.Name(GetAbilityName(id)) } end
        end
    end
    local ok, name = pcall(function() return B.Name(GetCompanionName(GetActiveCompanionDefId())) end)
    c.name = ok and name or nil
    return c
end

function Capture.Stats()
    local function S(stat) return stat and GetPlayerStat(stat) or 0 end
    return {
        hp = S(STAT_HEALTH_MAX), mag = S(STAT_MAGICKA_MAX), stam = S(STAT_STAMINA_MAX),
        dmg = math.max(S(STAT_SPELL_POWER), S(STAT_POWER)),
        pen = math.max(S(STAT_SPELL_PENETRATION), S(STAT_PHYSICAL_PENETRATION)),
        res = math.floor((S(STAT_SPELL_RESIST) + S(STAT_PHYSICAL_RESIST)) / 2),
        t = GetTimeStamp(),
    }
end

-- ---------------------------------------------------------------------------

-- Reads one part; pcall so one failing game call never loses the whole build.
local READERS = {
    gear = Capture.Gear, skills = Capture.Skills, cp = Capture.CP, food = Capture.Food,
    quick = Capture.Quick, outfit = Capture.Outfit, title = Capture.Title,
    collect = Capture.Collect, companion = Capture.Companion,
}

function Capture.Read(part)
    local ok, value = pcall(READERS[part])
    if not ok then
        B.Print(L("CAPTURE_FAILED", L("PART_" .. string.upper(part))))
        return nil
    end
    return value
end

-- a new build from what you wear now. only = read just the parts that are on (the save
-- window: "only my skills" leaves gear etc. empty, so wearing it never touches them)
function Capture.Build(name, parts, only)
    local b = {
        id = B.NewId(),
        name = name,
        classId = GetUnitClassId("player"),
        owner = B.Char().name,
        created = GetTimeStamp(),
        parts = {},
    }
    for k, v in pairs(parts or Capture.DEFAULT_PARTS) do b.parts[k] = v end
    Capture.Refresh(b, not only)
    return b
end

-- Pieces and skills picked by hand in the window (b.picked.gear[slot], b.picked.skills[cat][slot])
-- are what you chose for this build, not what you happen to wear: Overwrite keeps them
-- (it used to read the worn piece over a picked one, so the pick "removed itself").
function Capture.MarkPicked(b, kind, slot, cat, on)
    b.picked = b.picked or {}
    local t = b.picked[kind] or {}
    b.picked[kind] = t
    if kind == "skills" then
        t[cat] = t[cat] or {}
        t = t[cat]
    end
    t[slot] = on and true or nil
end

local function KeepPicked(b)
    local keep = { gear = {}, skills = {} }
    local picked = b.picked
    if not picked then return keep end
    for slot in pairs(picked.gear or {}) do
        if b.gear and b.gear[slot] then keep.gear[slot] = b.gear[slot] end
    end
    for cat, slots in pairs(picked.skills or {}) do
        for slot in pairs(slots) do
            local e = b.skills and b.skills[cat] and b.skills[cat][slot]
            if e then
                keep.skills[cat] = keep.skills[cat] or {}
                keep.skills[cat][slot] = e
            end
        end
    end
    return keep
end

local function PutPickedBack(b, keep)
    for slot, p in pairs(keep.gear) do
        b.gear = b.gear or {}
        local now = b.gear[slot]
        if now and p.uid and now.uid == p.uid then
            b.picked.gear[slot] = nil   -- you wear that very piece now: nothing to keep apart
        else
            b.gear[slot] = p
        end
    end
    for cat, slots in pairs(keep.skills) do
        b.skills = b.skills or {}
        b.skills[cat] = b.skills[cat] or {}
        for slot, e in pairs(slots) do b.skills[cat][slot] = e end
    end
end

-- read everything again into an existing build (name, folder, icon, parts stay).
-- all = also the parts that are turned off (they keep a current copy to turn on later).
function Capture.Refresh(b, all)
    local keep = KeepPicked(b)
    for _, part in ipairs(Capture.PARTS) do
        if all or b.parts[part] then
            local value = Capture.Read(part)
            if value ~= nil or part ~= "companion" then b[part] = value end
        end
    end
    PutPickedBack(b, keep)
    b.mundus = Capture.Mundus()
    b.stats = Capture.Stats()
    b.classId = GetUnitClassId("player")
    b.updated = GetTimeStamp()
    if B.sv.lockGear and b.gear then
        for slot in pairs(b.gear) do
            if not Items.POISON[slot] and not IsItemPlayerLocked(BAG_WORN, slot) then
                SetItemIsPlayerLocked(BAG_WORN, slot, true)
            end
        end
    end
end

-- Layer: keep only what differs from the parent build (e.g. a boss swap: two rings
-- and one skill). Everything else is left out, so wearing the layer only changes that.
function Capture.KeepDifferences(layer, parent)
    if layer.gear and parent.gear then
        for _, s in ipairs(Items.SLOTS) do
            local a, p = layer.gear[s], parent.gear[s]
            if a and p and ((a.uid and a.uid == p.uid) or (Items.POISON[s] and a.id == p.id)) then
                layer.gear[s] = nil
            end
        end
    end
    if layer.skills and parent.skills then
        for _, cat in ipairs(Capture.BARS) do
            local bar, pbar = layer.skills[cat] or {}, parent.skills[cat] or {}
            for slot = Capture.FIRST_SLOT, Capture.ULT_SLOT do
                if bar[slot] and pbar[slot] and bar[slot].id == pbar[slot].id then bar[slot] = nil end
            end
        end
    end
    local function SameCP(a, b)
        if not (a and b and a.slots and b.slots) then return false end
        for i = 1, 12 do
            if a.slots[i] ~= b.slots[i] then return false end
        end
        return true
    end
    if SameCP(layer.cp, parent.cp) then layer.parts.cp = false end
    if layer.food and parent.food and layer.food.id == parent.food.id then layer.parts.food = false end
    layer.parts.quick, layer.parts.outfit, layer.parts.title, layer.parts.collect = false, false, false, false
end

-- how many gear slots / skills a build holds (for "4 pieces, 3 skills")
function Capture.Count(b)
    local gear, skills = 0, 0
    for _ in pairs(b.gear or {}) do gear = gear + 1 end
    for _, bar in pairs(b.skills or {}) do
        for _ in pairs(bar) do skills = skills + 1 end
    end
    return gear, skills
end

-- Learn which buff each food gives: when a food or drink leaves the bag, the next long
-- buff you gain within a few seconds is its buff (no food list to keep up to date).
local foodSlots = {}   -- backpack slot -> link of food / drink seen there
local eaten            -- { id, link, t }

local function ScanFood()
    foodSlots = {}
    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        local t = GetItemType(BAG_BACKPACK, slot)
        if t == ITEMTYPE_FOOD or t == ITEMTYPE_DRINK then
            foodSlots[slot] = GetItemLink(BAG_BACKPACK, slot)
        end
    end
end

-- a food was just eaten (by you or by Skillbound): its buff runs foodDur seconds from now
function Capture.FoodEaten(itemId)
    local dur = B.sv.foodDur and B.sv.foodDur[itemId]
    if not dur then return end
    -- (only one food buff runs at a time: eating one ends the others)
    B.Char().foodTimes = { [itemId] = { at = GetTimeStamp(), dur = dur } }
end

-- this buff belongs to this food (learned for good, see below)
function Capture.LearnFoodBuff(itemId, link, abilityId, duration)
    if not itemId or not abilityId or Capture.MUNDUS[abilityId] then return end
    if B.sv.foodBuffs[itemId] == nil then B.sv.foodBuffs[itemId] = abilityId end
    B.sv.foodBuffSet = B.sv.foodBuffSet or {}
    B.sv.foodBuffSet[itemId] = B.sv.foodBuffSet[itemId] or {}
    B.sv.foodBuffSet[itemId][abilityId] = true
    if duration and duration > 0 then
        B.sv.foodDur = B.sv.foodDur or {}
        B.sv.foodDur[itemId] = math.floor(duration)
    end
    Capture.FoodEaten(itemId)
    B.Char().lastFood = { id = itemId, link = link }
end

-- 1.0.0 fix: the game starts the food's buff a moment BEFORE the item leaves the bag, so
-- "item gone, then a long buff" never matched and nothing was ever learned (sv.foodBuffs stayed
-- empty: the running buff wasn't recognized and the food was eaten again on every build switch).
-- Now both orders count: long buffs gained in the last 4 s are kept, and so is the food eaten
-- in the last 4 s; whichever comes second makes the match.
local recentBuffs = {}   -- { id, t, dur } long buffs gained / renewed lately

local function Match()
    if not eaten then return end
    local now = GetFrameTimeSeconds()
    if now - eaten.t > 4 then
        eaten = nil
        return
    end
    for _, r in ipairs(recentBuffs) do
        if math.abs(r.t - eaten.t) <= 4 then Capture.LearnFoodBuff(eaten.id, eaten.link, r.id, r.dur) end
    end
end

function Capture.Init()
    ScanFood()
    B.EM:RegisterForEvent("Skillbound_Food", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function(_, bagId, slotId, _, _, _, stackCountChange)
            if bagId ~= BAG_BACKPACK then return end
            local before = foodSlots[slotId]
            if before and stackCountChange and stackCountChange < 0 and not IsUnitInCombat("player") then
                eaten = { id = GetItemLinkItemId(before), link = before, t = GetFrameTimeSeconds() }
                Match()
            end
            local t = GetItemType(BAG_BACKPACK, slotId)
            foodSlots[slotId] = (t == ITEMTYPE_FOOD or t == ITEMTYPE_DRINK) and GetItemLink(BAG_BACKPACK, slotId) or nil
        end)
    B.EM:RegisterForEvent("Skillbound_FoodBuff", EVENT_EFFECT_CHANGED,
        function(_, changeType, _, _, unitTag, beginTime, endTime, _, _, _, _, _, _, _, _, abilityId)
            if unitTag ~= "player" then return end
            if changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_UPDATED then return end
            if not (endTime and beginTime and endTime - beginTime >= 20 * 60) or Capture.MUNDUS[abilityId] then return end
            local now = GetFrameTimeSeconds()
            for i = #recentBuffs, 1, -1 do
                if now - recentBuffs[i].t > 4 then table.remove(recentBuffs, i) end
            end
            recentBuffs[#recentBuffs + 1] = { id = abilityId, t = now, dur = endTime - beginTime }
            Match()
        end)
    B.EM:AddFilterForEvent("Skillbound_FoodBuff", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    B.EM:RegisterForEvent("Skillbound_FoodScan", EVENT_PLAYER_ACTIVATED, ScanFood)
end
