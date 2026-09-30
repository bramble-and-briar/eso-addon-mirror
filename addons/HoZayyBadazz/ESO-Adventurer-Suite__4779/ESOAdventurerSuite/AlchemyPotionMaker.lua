-- ESO Adventurer Suite
-- Floating Alchemy Potion & Poison Maker
-- v0.29.353

local EPC = ESOProgressionCoach
EPC.AlchemyPotionMaker = EPC.AlchemyPotionMaker or {}
local A = EPC.AlchemyPotionMaker
local wm = WINDOW_MANAGER

local PREFIX = "ESOAdventurerSuite_AlchemyPotionMaker"
local ICON_TEXTURE = "/esoui/art/crafting/alchemy_tabicon_reagent_up.dds"
local NORMAL_W, NORMAL_H = 64, 64
local PANEL_W, PANEL_H = 900, 900
local ROW_COUNT = 7
local EFFECT_POPUP_W, EFFECT_POPUP_H = 590, 620
local EFFECT_POPUP_ROWS = 17

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e,f,g,h = pcall(fn, ...)
    if not ok then return fallback end
    return a,b,c,d,e,f,g,h
end

local function num(v, fallback)
    v = tonumber(v)
    if v == nil then return fallback or 0 end
    return v
end

local function trim(v)
    local s = tostring(v or "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function normalize(v)
    local s = string.lower(trim(v))
    s = s:gsub("[’`]", "'")
    s = s:gsub("[^%w']+", " ")
    s = s:gsub("%s+", " ")
    return trim(s)
end

local function notify(text, good)
    if EPC and type(EPC.Print) == "function" then EPC:Print(text) end
    if type(ZO_Alert) == "function" then
        pcall(ZO_Alert, good == false and UI_ALERT_CATEGORY_ERROR or UI_ALERT_CATEGORY_ALERT, nil, text)
    end
end

local FX = {
    BREACH = 1,
    INCREASE_ARMOR = 2,
    PROTECTION = 3,
    VITALITY = 4,
    RESTORE_STAMINA = 5,
    RAVAGE_HEALTH = 6,
    INCREASE_WEAPON_POWER = 7,
    SPEED = 8,
    RAVAGE_MAGICKA = 9,
    RESTORE_HEALTH = 10,
    COWARDICE = 11,
    INVISIBLE = 12,
    INCREASE_SPELL_RESIST = 13,
    RESTORE_MAGICKA = 14,
    LINGERING_HEALTH = 15,
    UNCERTAINTY = 16,
    TIMIDITY = 17,
    DETECTION = 18,
    HINDRANCE = 19,
    VULNERABILITY = 20,
    DEFILE = 21,
    UNSTOPPABLE = 22,
    SPELL_CRITICAL = 23,
    GRADUAL_RAVAGE_HEALTH = 24,
    HEROISM = 25,
    ENERVATION = 26,
    FRACTURE = 27,
    WEAPON_CRITICAL = 28,
    RAVAGE_STAMINA = 29,
    MAIM = 30,
    ENTRAPMENT = 31,
    INCREASE_SPELL_POWER = 32,
}

-- Display-only fallback labels. Recipe identity remains numeric/API-based.
-- ESO may intentionally hide an undiscovered reagent trait name; in that case
-- use a readable label rather than leaking the internal effect id into the UI.
local EFFECT_FALLBACK_NAMES = {
    [1] = "Breach",
    [2] = "Increase Armor",
    [3] = "Protection",
    [4] = "Vitality",
    [5] = "Restore Stamina",
    [6] = "Ravage Health",
    [7] = "Increase Weapon Power",
    [8] = "Speed",
    [9] = "Ravage Magicka",
    [10] = "Restore Health",
    [11] = "Cowardice",
    [12] = "Invisible",
    [13] = "Increase Spell Resist",
    [14] = "Restore Magicka",
    [15] = "Lingering Health",
    [16] = "Uncertainty",
    [17] = "Timidity",
    [18] = "Detection",
    [19] = "Hindrance",
    [20] = "Vulnerability",
    [21] = "Defile",
    [22] = "Unstoppable",
    [23] = "Spell Critical",
    [24] = "Gradual Ravage Health",
    [25] = "Heroism",
    [26] = "Enervation",
    [27] = "Fracture",
    [28] = "Weapon Critical",
    [29] = "Ravage Stamina",
    [30] = "Maim",
    [31] = "Entrapment",
    [32] = "Increase Spell Power",
}

-- Planner identity is itemId/effectId based. Names are never used to decide
-- reagent ownership, recipe compatibility, ranking, or routing.
local REAGENT_CATALOG = {
    {77583,  {FX.BREACH, FX.INCREASE_ARMOR, FX.PROTECTION, FX.VITALITY}, "ALCHEMY"},
    {30157,  {FX.RESTORE_STAMINA, FX.RAVAGE_HEALTH, FX.INCREASE_WEAPON_POWER, FX.SPEED}, "FLOWER"},
    {30148,  {FX.RAVAGE_MAGICKA, FX.RESTORE_HEALTH, FX.COWARDICE, FX.INVISIBLE}, "MUSHROOM"},
    {30160,  {FX.INCREASE_SPELL_RESIST, FX.COWARDICE, FX.RESTORE_HEALTH, FX.RESTORE_MAGICKA}, "FLOWER"},
    {77585,  {FX.RESTORE_HEALTH, FX.LINGERING_HEALTH, FX.UNCERTAINTY, FX.VITALITY}, "ALCHEMY", "DYNAMIC"},
    {150669, {FX.TIMIDITY, FX.RAVAGE_MAGICKA, FX.RESTORE_STAMINA, FX.DETECTION}, "ALCHEMY"},
    {139020, {FX.INCREASE_SPELL_RESIST, FX.HINDRANCE, FX.VULNERABILITY, FX.DEFILE}, "CLAM"},
    {30164,  {FX.RESTORE_HEALTH, FX.RESTORE_STAMINA, FX.RESTORE_MAGICKA, FX.UNSTOPPABLE}, "FLOWER"},
    {30161,  {FX.RESTORE_MAGICKA, FX.RAVAGE_HEALTH, FX.INCREASE_SPELL_POWER, FX.DETECTION}, "FLOWER"},
    {150672, {FX.TIMIDITY, FX.SPELL_CRITICAL, FX.GRADUAL_RAVAGE_HEALTH, FX.RESTORE_HEALTH}, "WATERPLANT"},
    {150671, {FX.RESTORE_MAGICKA, FX.HEROISM, FX.ENERVATION, FX.SPEED}, "ALCHEMY", "DYNAMIC"},
    {150789, {FX.HEROISM, FX.VULNERABILITY, FX.INVISIBLE, FX.VITALITY}, "ALCHEMY", "DYNAMIC"},
    {150731, {FX.LINGERING_HEALTH, FX.RESTORE_STAMINA, FX.HEROISM, FX.DEFILE}, "ALCHEMY", "DYNAMIC"},
    {30162,  {FX.INCREASE_WEAPON_POWER, FX.FRACTURE, FX.RESTORE_STAMINA, FX.WEAPON_CRITICAL}, "FLOWER"},
    {30151,  {FX.RAVAGE_HEALTH, FX.RAVAGE_STAMINA, FX.RAVAGE_MAGICKA, FX.ENTRAPMENT}, "MUSHROOM"},
    {77587,  {FX.RAVAGE_STAMINA, FX.GRADUAL_RAVAGE_HEALTH, FX.VULNERABILITY, FX.VITALITY}, "ALCHEMY", "DYNAMIC"},
    {30156,  {FX.MAIM, FX.INCREASE_ARMOR, FX.RAVAGE_STAMINA, FX.ENERVATION}, "MUSHROOM"},
    {30158,  {FX.INCREASE_SPELL_POWER, FX.BREACH, FX.RESTORE_MAGICKA, FX.SPELL_CRITICAL}, "FLOWER"},
    {30155,  {FX.RAVAGE_STAMINA, FX.RESTORE_HEALTH, FX.MAIM, FX.HINDRANCE}, "MUSHROOM"},
    {30163,  {FX.INCREASE_ARMOR, FX.MAIM, FX.RESTORE_HEALTH, FX.RESTORE_STAMINA}, "FLOWER"},
    {77591,  {FX.INCREASE_SPELL_RESIST, FX.PROTECTION, FX.INCREASE_ARMOR, FX.DEFILE}, "ALCHEMY", "DYNAMIC"},
    {30153,  {FX.SPELL_CRITICAL, FX.INVISIBLE, FX.SPEED, FX.UNSTOPPABLE}, "MUSHROOM"},
    {77590,  {FX.RAVAGE_HEALTH, FX.GRADUAL_RAVAGE_HEALTH, FX.PROTECTION, FX.DEFILE}, "FLOWER"},
    {30165,  {FX.RAVAGE_HEALTH, FX.ENERVATION, FX.UNCERTAINTY, FX.INVISIBLE}, "WATERPLANT"},
    {139019, {FX.LINGERING_HEALTH, FX.SPEED, FX.VITALITY, FX.PROTECTION}, "CLAM"},
    {77589,  {FX.RAVAGE_MAGICKA, FX.VULNERABILITY, FX.SPEED, FX.LINGERING_HEALTH}, "ALCHEMY", "DYNAMIC"},
    {77584,  {FX.HINDRANCE, FX.LINGERING_HEALTH, FX.INVISIBLE, FX.DEFILE}, "ALCHEMY", "DYNAMIC"},
    {30149,  {FX.FRACTURE, FX.INCREASE_WEAPON_POWER, FX.RAVAGE_HEALTH, FX.RAVAGE_STAMINA}, "MUSHROOM"},
    {77581,  {FX.FRACTURE, FX.DETECTION, FX.ENERVATION, FX.VITALITY}, "ALCHEMY", "DYNAMIC"},
    {150670, {FX.TIMIDITY, FX.RAVAGE_HEALTH, FX.RESTORE_MAGICKA, FX.PROTECTION}, "ALCHEMY", "DYNAMIC"},
    {30152,  {FX.BREACH, FX.INCREASE_SPELL_POWER, FX.RAVAGE_HEALTH, FX.RAVAGE_MAGICKA}, "MUSHROOM"},
    {30166,  {FX.RESTORE_HEALTH, FX.WEAPON_CRITICAL, FX.SPELL_CRITICAL, FX.ENTRAPMENT}, "WATERPLANT"},
    {30154,  {FX.COWARDICE, FX.INCREASE_SPELL_RESIST, FX.RAVAGE_MAGICKA, FX.DETECTION}, "MUSHROOM"},
    {30159,  {FX.WEAPON_CRITICAL, FX.DETECTION, FX.HINDRANCE, FX.UNSTOPPABLE}, "FLOWER"},
}

local REAGENT_BY_ID = {}
for _, row in ipairs(REAGENT_CATALOG) do REAGENT_BY_ID[row[1]] = row end

local COUNTER_FX = {
    [FX.RESTORE_HEALTH] = FX.RAVAGE_HEALTH, [FX.RAVAGE_HEALTH] = FX.RESTORE_HEALTH,
    [FX.RESTORE_MAGICKA] = FX.RAVAGE_MAGICKA, [FX.RAVAGE_MAGICKA] = FX.RESTORE_MAGICKA,
    [FX.RESTORE_STAMINA] = FX.RAVAGE_STAMINA, [FX.RAVAGE_STAMINA] = FX.RESTORE_STAMINA,
    [FX.INCREASE_ARMOR] = FX.FRACTURE, [FX.FRACTURE] = FX.INCREASE_ARMOR,
    [FX.INCREASE_SPELL_RESIST] = FX.BREACH, [FX.BREACH] = FX.INCREASE_SPELL_RESIST,
    [FX.INCREASE_WEAPON_POWER] = FX.MAIM, [FX.MAIM] = FX.INCREASE_WEAPON_POWER,
    [FX.INCREASE_SPELL_POWER] = FX.COWARDICE, [FX.COWARDICE] = FX.INCREASE_SPELL_POWER,
    [FX.WEAPON_CRITICAL] = FX.ENERVATION, [FX.ENERVATION] = FX.WEAPON_CRITICAL,
    [FX.SPELL_CRITICAL] = FX.UNCERTAINTY, [FX.UNCERTAINTY] = FX.SPELL_CRITICAL,
    [FX.SPEED] = FX.HINDRANCE, [FX.HINDRANCE] = FX.SPEED,
    [FX.INVISIBLE] = FX.DETECTION, [FX.DETECTION] = FX.INVISIBLE,
    [FX.UNSTOPPABLE] = FX.ENTRAPMENT, [FX.ENTRAPMENT] = FX.UNSTOPPABLE,
    [FX.LINGERING_HEALTH] = FX.GRADUAL_RAVAGE_HEALTH, [FX.GRADUAL_RAVAGE_HEALTH] = FX.LINGERING_HEALTH,
    [FX.VITALITY] = FX.DEFILE, [FX.DEFILE] = FX.VITALITY,
    [FX.PROTECTION] = FX.VULNERABILITY, [FX.VULNERABILITY] = FX.PROTECTION,
    [FX.HEROISM] = FX.TIMIDITY, [FX.TIMIDITY] = FX.HEROISM,
}

local POTION_SOLVENT_IDS = {883, 1187, 4570, 23265, 23266, 23267, 23268, 64500, 64501}
local POISON_SOLVENT_IDS = {75357, 75358, 75359, 75360, 75361, 75362, 75363, 75364, 75365}

local function makeItemLinkFromItemId(itemId)
    itemId = tonumber(itemId) or 0
    local itemStyleNone = tonumber(rawget(_G, "ITEMSTYLE_NONE")) or 0
    return string.format("|H1:item:%d:%d:50:0:0:0:0:0:0:0:0:0:0:0:0:%d:%d:0:0:%d:0|h|h", itemId, 0, itemStyleNone, 0, 10000)
end

local function localizedItemName(itemId)
    local link = makeItemLinkFromItemId(itemId)
    local name = tostring(safe(GetItemLinkName, "", link) or "")
    if name ~= "" and type(zo_strformat) == "function" then
        name = zo_strformat("<<C:1>>", name)
    end
    return name ~= "" and name or ("Item " .. tostring(itemId)), link
end

local function solventIdForRank(mode, rank)
    local list = mode == "POISON" and POISON_SOLVENT_IDS or POTION_SOLVENT_IDS
    rank = math.max(1, math.min(#list, tonumber(rank) or 1))
    return list[rank]
end

function A:EnsureSaved()
    EPC.saved = EPC.saved or {}
    local s = EPC.saved
    if s.alchemyPotionMakerEnabled == nil then s.alchemyPotionMakerEnabled = true end
    if s.alchemyPotionMakerIncludeBank == nil then s.alchemyPotionMakerIncludeBank = true end
    if s.alchemyPotionMakerIncludeCraftBag == nil then s.alchemyPotionMakerIncludeCraftBag = true end
    if s.alchemyPotionMakerUseThreeReagents == nil then s.alchemyPotionMakerUseThreeReagents = true end
    if s.alchemyPotionMakerMode == nil then s.alchemyPotionMakerMode = "POTION" end
    if s.alchemyPotionMakerEffect1 == nil then s.alchemyPotionMakerEffect1 = FX.RESTORE_HEALTH end
    if s.alchemyPotionMakerEffect2 == nil then s.alchemyPotionMakerEffect2 = 0 end
    if s.alchemyPotionMakerEffect3 == nil then s.alchemyPotionMakerEffect3 = 0 end
    if s.alchemyPotionMakerLeft == nil then s.alchemyPotionMakerLeft = -1 end
    if s.alchemyPotionMakerTop == nil then s.alchemyPotionMakerTop = -1 end
    if s.alchemyPotionMakerPanelLeft == nil then s.alchemyPotionMakerPanelLeft = -1 end
    if s.alchemyPotionMakerPanelTop == nil then s.alchemyPotionMakerPanelTop = -1 end
    if s.alchemyPotionMakerAutoCraft == nil then s.alchemyPotionMakerAutoCraft = false end
    if s.alchemyPotionMakerAutoCraftMode == nil then s.alchemyPotionMakerAutoCraftMode = "ONE" end
    if s.alchemyPotionMakerAutoCraftQuantity == nil then s.alchemyPotionMakerAutoCraftQuantity = 1 end
end

function A:IsAtAlchemyStation()
    local craftingType = safe(GetCraftingInteractionType, nil)
    local alchemy = rawget(_G, "CRAFTING_TYPE_ALCHEMY")
    return alchemy ~= nil and craftingType == alchemy
end

function A:IsThirdSlotUnlocked()
    if EPC.saved and EPC.saved.alchemyPotionMakerUseThreeReagents == false then return false end
    if type(ZO_Alchemy_IsThirdAlchemySlotUnlocked) == "function" then
        return safe(ZO_Alchemy_IsThirdAlchemySlotUnlocked, false) == true
    end
    -- If the API is absent, keep the planner conservative instead of preparing
    -- a three-reagent recipe that the character may not be able to slot.
    return false
end

function A:RestorePosition()
    if not self.button or not GuiRoot then return end
    self:EnsureSaved()
    local x = num(EPC.saved.alchemyPotionMakerLeft, -1)
    local y = num(EPC.saved.alchemyPotionMakerTop, -1)
    self.button:ClearAnchors()
    self.button:SetDimensions(NORMAL_W, NORMAL_H)
    if x >= 0 and y >= 0 then
        self.button:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    else
        self.button:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -184, 245)
    end
end

function A:SavePosition()
    if not self.button or not EPC.saved then return end
    EPC.saved.alchemyPotionMakerLeft = math.max(0, num(self.button:GetLeft(), 0))
    EPC.saved.alchemyPotionMakerTop = math.max(0, num(self.button:GetTop(), 0))
end

function A:RestorePanelPosition()
    if not self.window or not GuiRoot then return end
    self:EnsureSaved()
    local x = num(EPC.saved.alchemyPotionMakerPanelLeft, -1)
    local y = num(EPC.saved.alchemyPotionMakerPanelTop, -1)
    self.window:ClearAnchors()
    if x >= 0 and y >= 0 then
        self.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    else
        self.window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
end

function A:SavePanelPosition()
    if not self.window or not EPC.saved then return end
    EPC.saved.alchemyPotionMakerPanelLeft = math.max(0, num(self.window:GetLeft(), 0))
    EPC.saved.alchemyPotionMakerPanelTop = math.max(0, num(self.window:GetTop(), 0))
end

function A:ResetPosition()
    self:EnsureSaved()
    EPC.saved.alchemyPotionMakerLeft = -1
    EPC.saved.alchemyPotionMakerTop = -1
    EPC.saved.alchemyPotionMakerPanelLeft = -1
    EPC.saved.alchemyPotionMakerPanelTop = -1
    self:RestorePosition()
    self:RestorePanelPosition()
end

function A:ForEachBagSlot(bagId, callback)
    if bagId == nil or type(callback) ~= "function" then return end

    -- BAG_VIRTUAL is not a normal indexed bag: its slot id is the item's itemId.
    -- Prefer ESO's already-maintained inventory cache so opening/switching the
    -- Potion Maker does not walk the entire craft bag through thousands of API
    -- calls.  This is both faster and more reliable on ESO+ craft-bag entries.
    if rawget(_G, "BAG_VIRTUAL") ~= nil and bagId == BAG_VIRTUAL then
        local shared = rawget(_G, "SHARED_INVENTORY")
        if shared and type(shared.GetOrCreateBagCache) == "function" then
            local ok, cache = pcall(shared.GetOrCreateBagCache, shared, bagId)
            if ok and type(cache) == "table" then
                for cacheKey, slotData in pairs(cache) do
                    if type(slotData) == "table" then
                        local slotIndex = slotData.slotIndex or slotData.itemId or cacheKey
                        if slotIndex ~= nil then callback(bagId, slotIndex, slotData) end
                    end
                end
                return
            end
        end

        -- Compatibility fallback for unusual UI states/older API builds.
        if type(GetNextVirtualBagSlotId) == "function" then
            local last, guard = nil, 0
            while guard < 10000 do
                local slotIndex = safe(GetNextVirtualBagSlotId, nil, last)
                if slotIndex == nil then break end
                callback(bagId, slotIndex, nil)
                last = slotIndex
                guard = guard + 1
            end
        end
        return
    end

    local size = num(safe(GetBagSize, 0, bagId), 0)
    for slotIndex = 0, size - 1 do callback(bagId, slotIndex, nil) end
end

function A:GetSlotCount(bagId, slotIndex, slotData)
    if type(slotData) == "table" and slotData.stackCount ~= nil then
        return math.max(0, num(slotData.stackCount, 0))
    end
    local stack = safe(GetSlotStackSize, nil, bagId, slotIndex)
    if stack ~= nil then return math.max(0, num(stack, 0)) end
    local _, stackCount = safe(GetItemInfo, nil, bagId, slotIndex)
    return math.max(0, num(stackCount, 0))
end

function A:EnsurePlannerCatalog()
    if self.plannerCatalog and self.effectNames and self.effectNameToId and self.effectChoices then
        return self.plannerCatalog
    end

    local catalog, effectNames, effectNameToId = {}, {}, {}
    for catalogIndex, row in ipairs(REAGENT_CATALOG) do
        local itemId, effectIds, kind, sourceKind = row[1], row[2], row[3], row[4]
        local name, link = localizedItemName(itemId)
        local entry = {
            itemId = itemId,
            key = "id:" .. tostring(itemId),
            name = name,
            link = link,
            effectIds = effectIds,
            kind = kind,
            sourceKind = sourceKind,
            catalogIndex = catalogIndex,
        }
        catalog[#catalog + 1] = entry

        if type(GetItemLinkReagentTraitInfo) == "function" then
            for traitIndex, effectId in ipairs(effectIds) do
                local _, traitName = safe(GetItemLinkReagentTraitInfo, nil, link, traitIndex)
                traitName = trim(traitName)
                if traitName ~= "" then
                    if not effectNames[effectId] or effectNames[effectId] == "" then effectNames[effectId] = traitName end
                    effectNameToId[normalize(traitName)] = effectId
                end
            end
        end
    end

    local choices = {}
    local seen = {}
    for _, row in ipairs(REAGENT_CATALOG) do
        for _, effectId in ipairs(row[2]) do
            if not seen[effectId] then
                seen[effectId] = true
                choices[#choices + 1] = effectId
            end
        end
    end
    table.sort(choices, function(a, b)
        local an = tostring(effectNames[a] or EFFECT_FALLBACK_NAMES[a] or "Unknown Effect")
        local bn = tostring(effectNames[b] or EFFECT_FALLBACK_NAMES[b] or "Unknown Effect")
        return an < bn
    end)

    self.plannerCatalog = catalog
    self.effectNames = effectNames
    self.effectNameToId = effectNameToId
    self.effectChoices = choices
    return catalog
end

function A:GetEffectName(effectId)
    self:EnsurePlannerCatalog()
    effectId = tonumber(effectId)
    if effectId and self.effectNames and trim(self.effectNames[effectId]) ~= "" then
        return self.effectNames[effectId]
    end
    if effectId and EFFECT_FALLBACK_NAMES[effectId] then
        return EFFECT_FALLBACK_NAMES[effectId]
    end
    return "Unknown Effect"
end

function A:GetEffectIdFromName(name)
    self:EnsurePlannerCatalog()
    local key = normalize(name)
    if key == "" then return nil end
    return self.effectNameToId and self.effectNameToId[key] or nil
end

function A:GetEffectNames(effectIds)
    local names = {}
    for _, effectId in ipairs(effectIds or {}) do names[#names + 1] = self:GetEffectName(effectId) end
    return names
end

function A:GetLiveTraitRecords(bagId, slotIndex, link, itemId)
    self:EnsurePlannerCatalog()
    local records = {}
    local row = REAGENT_BY_ID[tonumber(itemId) or 0]
    local staticEffectIds = row and row[2] or nil

    if type(GetAlchemyItemTraits) == "function" and bagId ~= nil and slotIndex ~= nil then
        local ok,
            t1, i1, m1, c1, x1,
            t2, i2, m2, c2, x2,
            t3, i3, m3, c3, x3,
            t4, i4, m4, c4, x4 = pcall(GetAlchemyItemTraits, bagId, slotIndex)
        if ok then
            local raw = {
                {t1, c1}, {t2, c2}, {t3, c3}, {t4, c4},
            }
            for index, pair in ipairs(raw) do
                local effectId = staticEffectIds and staticEffectIds[index] or self:GetEffectIdFromName(pair[1])
                local traitName = trim(pair[1])
                if effectId and traitName ~= "" then
                    self.effectNames[effectId] = traitName
                    self.effectNameToId[normalize(traitName)] = effectId
                end
                local cancelId = self:GetEffectIdFromName(pair[2]) or (effectId and COUNTER_FX[effectId])
                if effectId then records[#records + 1] = { effectId = effectId, cancelsId = cancelId } end
            end
        end
    end

    if #records == 0 and type(GetItemLinkReagentTraitInfo) == "function" and link and link ~= "" then
        for index = 1, 4 do
            local _, traitName = safe(GetItemLinkReagentTraitInfo, nil, link, index)
            local effectId = staticEffectIds and staticEffectIds[index] or self:GetEffectIdFromName(traitName)
            if effectId then records[#records + 1] = { effectId = effectId, cancelsId = COUNTER_FX[effectId] } end
        end
    end
    return records
end

function A:ScanMaterials(force)
    self:EnsureSaved()
    if not force and self.reagentList and self.reagentsByName and self.solvents then
        return self.reagentList, self.solvents
    end
    self.traitCounters = {}
    local reagentsByName, solvents = {}, { POTION = {}, POISON = {} }
    local reagentType = rawget(_G, "ITEMTYPE_REAGENT")
    local potionBase = rawget(_G, "ITEMTYPE_POTION_BASE")
    local poisonBase = rawget(_G, "ITEMTYPE_POISON_BASE")
    local bags, seenBags = {}, {}
    local function addBag(id)
        if id ~= nil and not seenBags[id] then seenBags[id] = true bags[#bags + 1] = id end
    end
    addBag(rawget(_G, "BAG_BACKPACK"))
    if EPC.saved.alchemyPotionMakerIncludeBank ~= false then
        addBag(rawget(_G, "BAG_BANK"))
        addBag(rawget(_G, "BAG_SUBSCRIBER_BANK"))
    end
    if EPC.saved.alchemyPotionMakerIncludeCraftBag ~= false then addBag(rawget(_G, "BAG_VIRTUAL")) end

    for _, bagId in ipairs(bags) do
        self:ForEachBagSlot(bagId, function(bag, slot, slotData)
            local link = ""
            if type(slotData) == "table" then
                link = tostring(slotData.itemLink or slotData.link or "")
            end
            if link == "" then link = tostring(safe(GetItemLink, "", bag, slot, LINK_STYLE_DEFAULT or 0) or "") end

            -- Prefer direct bag data for real inventory slots, especially BAG_VIRTUAL.
            -- Item links are a fallback, not the identity source.
            local itemType, specializedType
            if type(slotData) == "table" then
                itemType = slotData.itemType
                specializedType = slotData.specializedItemType
            end
            if itemType == nil and type(GetItemType) == "function" then
                itemType, specializedType = safe(GetItemType, nil, bag, slot)
            end
            if itemType == nil and link ~= "" then
                itemType, specializedType = safe(GetItemLinkItemType, nil, link)
            end
            itemType = num(itemType, -1)

            local count = self:GetSlotCount(bag, slot, slotData)
            if count <= 0 then return end

            local name = type(slotData) == "table" and tostring(slotData.name or "") or ""
            if name == "" and link ~= "" then name = tostring(safe(GetItemLinkName, "", link) or "") end
            if name == "" then name = tostring(safe(GetItemName, "", bag, slot) or "") end

            local itemId = type(slotData) == "table" and num(slotData.itemId, 0) or 0
            if itemId <= 0 then itemId = num(safe(GetItemId, 0, bag, slot), 0) end
            if itemId <= 0 and link ~= "" then itemId = num(safe(GetItemLinkItemId, 0, link), 0) end
            local key = itemId > 0 and ("id:" .. tostring(itemId)) or ("bag:" .. tostring(bag) .. ":" .. tostring(slot))

            local isSolvent = type(IsAlchemySolvent) == "function" and safe(IsAlchemySolvent, false, itemType) == true
            local potionSpecial = rawget(_G, "SPECIALIZED_ITEMTYPE_POTION_BASE")
            local poisonSpecial = rawget(_G, "SPECIALIZED_ITEMTYPE_POISON_BASE")
            if reagentType ~= nil and itemType == reagentType then
                local entry = reagentsByName[key]
                if not entry then
                    entry = { name = name, key = key, itemId = itemId, count = 0, locations = {}, effectIds = {} }
                    reagentsByName[key] = entry
                end
                entry.count = entry.count + count
                entry.locations[#entry.locations + 1] = { bagId = bag, slotIndex = slot, count = count, link = link }
                local liveRecords = self:GetLiveTraitRecords(bag, slot, link, itemId)
                local live = {}
                for _, record in ipairs(liveRecords) do
                    live[#live + 1] = record.effectId
                    if record.effectId and record.cancelsId then
                        self.traitCounters[record.effectId] = record.cancelsId
                    end
                end
                if #live > #entry.effectIds then entry.effectIds = live end
            elseif (potionBase ~= nil and itemType == potionBase) or (isSolvent and potionSpecial ~= nil and specializedType == potionSpecial) then
                solvents.POTION[#solvents.POTION + 1] = { name = name, key = key, count = count, bagId = bag, slotIndex = slot, link = link }
            elseif (poisonBase ~= nil and itemType == poisonBase) or (isSolvent and poisonSpecial ~= nil and specializedType == poisonSpecial) then
                solvents.POISON[#solvents.POISON + 1] = { name = name, key = key, count = count, bagId = bag, slotIndex = slot, link = link }
            end
        end)
    end

    local reagentList = {}
    for _, entry in pairs(reagentsByName) do
        reagentList[#reagentList + 1] = entry
    end
    table.sort(reagentList, function(a,b) return tostring(a.name) < tostring(b.name) end)

    for _, mode in ipairs({"POTION", "POISON"}) do
        table.sort(solvents[mode], function(a,b)
            local ar = num(safe(GetItemLinkRequiredChampionPoints, 0, a.link), 0) * 100 + num(safe(GetItemLinkRequiredLevel, 0, a.link), 0)
            local br = num(safe(GetItemLinkRequiredChampionPoints, 0, b.link), 0) * 100 + num(safe(GetItemLinkRequiredLevel, 0, b.link), 0)
            if ar == br then return a.count > b.count end
            return ar > br
        end)
    end

    -- Effect labels come from generated item links, while recipe identity stays numeric.

    self.reagentsByName = reagentsByName
    self.reagentList = reagentList
    self.solvents = solvents
    self.resultCache = {}
    self.cachedReadyResults = nil
    self.lastScanAt = num(safe(GetFrameTimeMilliseconds, 0), 0)
    return reagentList, solvents
end

function A:GetSolventProficiencyIndex()
    -- NON_COMBAT_BONUS_ALCHEMY_LEVEL is zero-based for solvent proficiency.
    -- Convert it to the 1..9 indices used by our solvent tables.
    local bonusType = rawget(_G, "NON_COMBAT_BONUS_ALCHEMY_LEVEL")
    local bonus = num(safe(GetNonCombatBonus, 0, bonusType), 0)
    return math.max(1, math.min(9, bonus + 1))
end

function A:IsSolventLevelUsable(solvent)
    if not solvent then return false end

    -- A character can own account/bank solvents above the level that character
    -- can actually use. Filter those before presenting a recipe as READY.
    local requiredCP = num(safe(GetItemLinkRequiredChampionPoints, 0, solvent.link), 0)
    local requiredLevel = num(safe(GetItemLinkRequiredLevel, 0, solvent.link), 0)
    local playerCP = num(safe(GetUnitChampionPoints, 0, "player"), 0)
    local playerLevel = num(safe(GetUnitLevel, 1, "player"), 1)
    if requiredCP > 0 then
        if playerCP < requiredCP then return false end
    elseif requiredLevel > 0 and playerLevel < requiredLevel then
        return false
    end
    return true
end

function A:GetUsableSolvents(mode)
    mode = mode == "POISON" and "POISON" or "POTION"
    if not self.solvents then self:ScanMaterials() end
    local list = self.solvents and self.solvents[mode] or {}
    local out = {}
    for _, solvent in ipairs(list) do
        if self:IsSolventLevelUsable(solvent) then out[#out + 1] = solvent end
    end
    return out
end

function A:GetBestSolvent(mode)
    local list = self:GetUsableSolvents(mode)
    return list[1]
end

function A:GetExpectedSolventName(mode)
    local rank = self:GetSolventProficiencyIndex()
    local itemId = solventIdForRank(mode, rank)
    local name = localizedItemName(itemId)
    return name
end

function A:GetCatalogWithOwnership()
    if not self.reagentList then self:ScanMaterials() end
    local planner = self:EnsurePlannerCatalog()
    local ownedByItemId = {}
    for _, live in ipairs(self.reagentList or {}) do
        if tonumber(live.itemId) and tonumber(live.itemId) > 0 then ownedByItemId[tonumber(live.itemId)] = live end
    end

    local out, matched = {}, {}
    for _, base in ipairs(planner or {}) do
        local owned = ownedByItemId[base.itemId]
        if owned then matched[base.itemId] = true end
        out[#out + 1] = {
            name = owned and owned.name or base.name,
            key = base.key,
            itemId = base.itemId,
            link = base.link,
            effectIds = base.effectIds,
            kind = base.kind,
            sourceKind = base.sourceKind,
            owned = owned,
            catalogIndex = base.catalogIndex,
        }
    end

    -- Future reagents whose itemIds are not in the bundled ID catalog can still
    -- participate if the live API maps their traits to existing effect IDs.
    for _, live in ipairs(self.reagentList or {}) do
        local itemId = tonumber(live.itemId) or 0
        if itemId > 0 and not matched[itemId] and type(live.effectIds) == "table" and #live.effectIds > 0 then
            out[#out + 1] = {
                name = live.name,
                key = live.key,
                itemId = itemId,
                effectIds = live.effectIds,
                owned = live,
                apiOnly = true,
                kind = "ALCHEMY",
            }
        end
    end

    table.sort(out, function(a,b) return tostring(a.name) < tostring(b.name) end)
    return out
end

function A:GetActiveEffects(combo)
    local counts, all = {}, {}
    for _, reagent in ipairs(combo or {}) do
        for _, effectId in ipairs(reagent.effectIds or {}) do
            effectId = tonumber(effectId)
            if effectId then
                counts[effectId] = (counts[effectId] or 0) + 1
                all[effectId] = true
            end
        end
    end
    local active = {}
    for effectId, count in pairs(counts) do
        if count >= 2 then
            local counter = (self.traitCounters and self.traitCounters[effectId]) or COUNTER_FX[effectId]
            if not counter or not all[counter] then active[#active + 1] = effectId end
        end
    end
    table.sort(active, function(a, b) return self:GetEffectName(a) < self:GetEffectName(b) end)
    return active
end

function A:HasDesiredEffects(active, desired)
    local set = {}
    for _, effectId in ipairs(active or {}) do set[tonumber(effectId)] = true end
    for _, effectId in ipairs(desired or {}) do
        effectId = tonumber(effectId)
        if effectId and not set[effectId] then return false end
    end
    return true
end

function A:GetOwnedLocation(reagent)
    if not reagent then return nil end
    local owned = reagent.owned or (self.reagentsByName and self.reagentsByName[reagent.key])
    if not owned or not owned.locations then return nil end
    -- Prefer backpack, then craft bag, then bank. All are valid crafting sources
    -- at a normal Alchemy station, but backpack gives the most predictable UI.
    local backpack = rawget(_G, "BAG_BACKPACK")
    local virtual = rawget(_G, "BAG_VIRTUAL")
    local best
    for _, loc in ipairs(owned.locations) do
        if loc.count and loc.count > 0 then
            if loc.bagId == backpack then return loc end
            if not best or (loc.bagId == virtual and best.bagId ~= backpack) then best = loc end
        end
    end
    return best
end

function A:BuildResult(combo, active, mode, selectedCount)
    local solvent = self:GetBestSolvent(mode)
    local missing, maxCraftable = {}, solvent and solvent.count or 0
    for _, reagent in ipairs(combo) do
        local owned = reagent.owned or (self.reagentsByName and self.reagentsByName[reagent.key])
        if not owned or num(owned.count, 0) < 1 then
            missing[#missing + 1] = reagent.name .. " x1"
        else
            maxCraftable = math.min(maxCraftable, num(owned.count, 0))
        end
    end
    if not solvent then missing[#missing + 1] = self:GetExpectedSolventName(mode) .. " x1 (solvent)" end
    local names = {}
    for _, reagent in ipairs(combo) do names[#names + 1] = reagent.name end
    local activeCount = #active
    return {
        combo = combo,
        effects = active,
        effectsText = table.concat(self:GetEffectNames(active), " + "),
        reagentsText = table.concat(names, " + "),
        mode = mode,
        solvent = solvent,
        ready = #missing == 0,
        missing = missing,
        missingCount = #missing,
        maxCraftable = #missing == 0 and math.max(0, maxCraftable) or 0,
        extraCount = math.max(0, activeCount - num(selectedCount, activeCount)),
    }
end

function A:BuildCanMakeResults()
    self:ScanMaterials()
    local mode = EPC.saved.alchemyPotionMakerMode == "POISON" and "POISON" or "POTION"
    local cacheKey = "READY:" .. mode .. ":" .. (self:IsThirdSlotUnlocked() and "3" or "2")
    self.resultCache = self.resultCache or {}
    if self.resultCache[cacheKey] then return self.resultCache[cacheKey] end
    local solvent = self:GetBestSolvent(mode)
    if not solvent then return {} end
    local list = self.reagentList or {}
    local wrappers = {}
    for _, entry in ipairs(list) do wrappers[#wrappers + 1] = { name = entry.name, key = entry.key, itemId = entry.itemId, effectIds = entry.effectIds, owned = entry } end
    local bestByEffects = {}
    local allowThree = self:IsThirdSlotUnlocked()
    local function consider(combo)
        local active = self:GetActiveEffects(combo)
        if #active == 0 then return end
        local result = self:BuildResult(combo, active, mode, #active)
        if not result.ready or result.maxCraftable < 1 then return end
        local key = table.concat(active, "|")
        local old = bestByEffects[key]
        if not old or result.maxCraftable > old.maxCraftable or (result.maxCraftable == old.maxCraftable and #combo < #old.combo) then
            bestByEffects[key] = result
        end
    end
    for i = 1, #wrappers - 1 do
        for j = i + 1, #wrappers do consider({wrappers[i], wrappers[j]}) end
    end
    if allowThree then
        for i = 1, #wrappers - 2 do
            for j = i + 1, #wrappers - 1 do
                for k = j + 1, #wrappers do consider({wrappers[i], wrappers[j], wrappers[k]}) end
            end
        end
    end
    local out = {}
    for _, result in pairs(bestByEffects) do out[#out + 1] = result end
    table.sort(out, function(a,b)
        if #a.effects ~= #b.effects then return #a.effects > #b.effects end
        if a.maxCraftable ~= b.maxCraftable then return a.maxCraftable > b.maxCraftable end
        return a.effectsText < b.effectsText
    end)
    self.resultCache[cacheKey] = out
    if mode == (EPC.saved.alchemyPotionMakerMode == "POISON" and "POISON" or "POTION") then
        self.cachedReadyResults = out
    end
    return out
end

function A:GetDesiredEffects()
    self:EnsureSaved()
    self:EnsurePlannerCatalog()
    local out, seen = {}, {}
    for _, key in ipairs({"alchemyPotionMakerEffect1", "alchemyPotionMakerEffect2", "alchemyPotionMakerEffect3"}) do
        local rawValue = EPC.saved[key]
        local effectId = tonumber(rawValue)
        if not effectId and type(rawValue) == "string" and trim(rawValue) ~= "" then
            -- One-time migration for saved selections from pre-ID builds. The
            -- current client's localized API label is the only string consulted.
            effectId = self:GetEffectIdFromName(rawValue)
            EPC.saved[key] = effectId or 0
        end
        if effectId and effectId > 0 and not seen[effectId] then
            seen[effectId] = true
            out[#out + 1] = effectId
        end
    end
    return out
end

function A:BuildExactResults()
    self:ScanMaterials()
    local desired = self:GetDesiredEffects()
    if #desired == 0 then return {} end
    local mode = EPC.saved.alchemyPotionMakerMode == "POISON" and "POISON" or "POTION"
    local desiredKey = table.concat(desired, "|")
    local cacheKey = "EXACT:" .. mode .. ":" .. (self:IsThirdSlotUnlocked() and "3" or "2") .. ":" .. desiredKey
    self.resultCache = self.resultCache or {}
    if self.resultCache[cacheKey] then return self.resultCache[cacheKey] end
    local catalog = self:GetCatalogWithOwnership()
    local allowThree = self:IsThirdSlotUnlocked()
    local out = {}
    local function consider(combo)
        local active = self:GetActiveEffects(combo)
        if #active == 0 or not self:HasDesiredEffects(active, desired) then return end
        out[#out + 1] = self:BuildResult(combo, active, mode, #desired)
    end
    for i = 1, #catalog - 1 do
        for j = i + 1, #catalog do consider({catalog[i], catalog[j]}) end
    end
    if allowThree then
        for i = 1, #catalog - 2 do
            for j = i + 1, #catalog - 1 do
                for k = j + 1, #catalog do consider({catalog[i], catalog[j], catalog[k]}) end
            end
        end
    end
    table.sort(out, function(a,b)
        if a.ready ~= b.ready then return a.ready end
        if a.extraCount ~= b.extraCount then return a.extraCount < b.extraCount end
        if a.missingCount ~= b.missingCount then return a.missingCount < b.missingCount end
        if #a.combo ~= #b.combo then return #a.combo < #b.combo end
        if a.maxCraftable ~= b.maxCraftable then return a.maxCraftable > b.maxCraftable end
        return a.reagentsText < b.reagentsText
    end)
    if #out > 160 then
        local limited = {}
        for i = 1, 160 do limited[i] = out[i] end
        out = limited
    end
    self.resultCache[cacheKey] = out
    return out
end


-- Recommendation engine for new and experienced players.
-- Identity is still effectId/itemId based. These profiles only decide which
-- recipe is presented as the best fit for a combat goal; ownership never hides
-- a recommendation.
local BEST_POTION_EFFECT_SCORE = {
    [FX.HEROISM] = 135,
    [FX.INCREASE_WEAPON_POWER] = 120,
    [FX.INCREASE_SPELL_POWER] = 120,
    [FX.WEAPON_CRITICAL] = 112,
    [FX.SPELL_CRITICAL] = 112,
    [FX.UNSTOPPABLE] = 108,
    [FX.PROTECTION] = 96,
    [FX.VITALITY] = 94,
    [FX.SPEED] = 88,
    [FX.RESTORE_HEALTH] = 84,
    [FX.RESTORE_MAGICKA] = 78,
    [FX.RESTORE_STAMINA] = 78,
    [FX.INCREASE_ARMOR] = 72,
    [FX.INCREASE_SPELL_RESIST] = 72,
    [FX.LINGERING_HEALTH] = 70,
    [FX.INVISIBLE] = 62,
    [FX.DETECTION] = 44,
}

local BEST_POISON_EFFECT_SCORE = {
    [FX.GRADUAL_RAVAGE_HEALTH] = 140,
    [FX.RAVAGE_HEALTH] = 132,
    [FX.BREACH] = 120,
    [FX.FRACTURE] = 120,
    [FX.DEFILE] = 114,
    [FX.VULNERABILITY] = 112,
    [FX.MAIM] = 102,
    [FX.COWARDICE] = 102,
    [FX.ENERVATION] = 96,
    [FX.UNCERTAINTY] = 96,
    [FX.HINDRANCE] = 92,
    [FX.ENTRAPMENT] = 88,
    [FX.RAVAGE_STAMINA] = 84,
    [FX.RAVAGE_MAGICKA] = 84,
    [FX.TIMIDITY] = 78,
    [FX.DETECTION] = 42,
}

local function EffectSet(effects)
    local set = {}
    for _, effectId in ipairs(effects or {}) do set[tonumber(effectId)] = true end
    return set
end

local function BestRecipeScore(mode, effects)
    local weights = mode == "POISON" and BEST_POISON_EFFECT_SCORE or BEST_POTION_EFFECT_SCORE
    local score, useful = 0, 0
    for _, effectId in ipairs(effects or {}) do
        effectId = tonumber(effectId)
        local value = effectId and weights[effectId] or nil
        if value then
            score = score + value
            useful = useful + 1
        else
            return 0, 0
        end
    end
    if useful < 2 then return 0, useful end

    local set = EffectSet(effects)
    if mode == "POTION" then
        if set[FX.INCREASE_WEAPON_POWER] and set[FX.WEAPON_CRITICAL] then score = score + 78 end
        if set[FX.INCREASE_SPELL_POWER] and set[FX.SPELL_CRITICAL] then score = score + 78 end
        if set[FX.HEROISM] then score = score + 55 end
        if set[FX.UNSTOPPABLE] and (set[FX.RESTORE_MAGICKA] or set[FX.RESTORE_STAMINA] or set[FX.RESTORE_HEALTH]) then score = score + 42 end
        if set[FX.RESTORE_HEALTH] and (set[FX.RESTORE_MAGICKA] or set[FX.RESTORE_STAMINA]) then score = score + 30 end
        if set[FX.PROTECTION] and set[FX.VITALITY] then score = score + 28 end
    else
        if set[FX.RAVAGE_HEALTH] and set[FX.GRADUAL_RAVAGE_HEALTH] then score = score + 82 end
        if (set[FX.BREACH] or set[FX.FRACTURE]) and (set[FX.RAVAGE_HEALTH] or set[FX.GRADUAL_RAVAGE_HEALTH]) then score = score + 58 end
        if (set[FX.DEFILE] or set[FX.VULNERABILITY]) and (set[FX.RAVAGE_HEALTH] or set[FX.GRADUAL_RAVAGE_HEALTH]) then score = score + 52 end
        if set[FX.HINDRANCE] and (set[FX.RAVAGE_HEALTH] or set[FX.GRADUAL_RAVAGE_HEALTH]) then score = score + 34 end
    end
    if useful >= 3 then score = score + 36 end
    return score, useful
end

local POTION_RECOMMENDATION_PROFILES = {
    { key="OVERALL", title="BEST OVERALL", why="Strongest all-around combat value for a new player.", weights={
        [FX.HEROISM]=155, [FX.RESTORE_HEALTH]=100, [FX.RESTORE_MAGICKA]=92, [FX.RESTORE_STAMINA]=92,
        [FX.UNSTOPPABLE]=85, [FX.INCREASE_SPELL_POWER]=82, [FX.INCREASE_WEAPON_POWER]=82,
        [FX.SPELL_CRITICAL]=76, [FX.WEAPON_CRITICAL]=76, [FX.SPEED]=52,
    }},
    { key="MAGICKA", title="MAGICKA DPS", why="Prioritizes spell damage, spell critical and Magicka sustain.", weights={
        [FX.INCREASE_SPELL_POWER]=185, [FX.SPELL_CRITICAL]=175, [FX.RESTORE_MAGICKA]=145,
        [FX.HEROISM]=110, [FX.RESTORE_HEALTH]=55, [FX.UNSTOPPABLE]=45,
    }},
    { key="STAMINA", title="STAMINA DPS", why="Prioritizes weapon damage, weapon critical and Stamina sustain.", weights={
        [FX.INCREASE_WEAPON_POWER]=185, [FX.WEAPON_CRITICAL]=175, [FX.RESTORE_STAMINA]=145,
        [FX.HEROISM]=110, [FX.RESTORE_HEALTH]=55, [FX.UNSTOPPABLE]=45,
    }},
    { key="TANK", title="TANK", why="Prioritizes survival, resources and control resistance.", weights={
        [FX.RESTORE_HEALTH]=180, [FX.RESTORE_STAMINA]=135, [FX.RESTORE_MAGICKA]=120,
        [FX.PROTECTION]=150, [FX.VITALITY]=140, [FX.UNSTOPPABLE]=125,
        [FX.INCREASE_ARMOR]=95, [FX.INCREASE_SPELL_RESIST]=95, [FX.LINGERING_HEALTH]=90,
    }},
    { key="HEALER", title="HEALER", why="Prioritizes Magicka sustain, healing support and spell output.", weights={
        [FX.RESTORE_MAGICKA]=180, [FX.VITALITY]=155, [FX.INCREASE_SPELL_POWER]=135,
        [FX.SPELL_CRITICAL]=125, [FX.RESTORE_HEALTH]=95, [FX.LINGERING_HEALTH]=105,
        [FX.HEROISM]=90,
    }},
    { key="SOLO", title="SOLO / SURVIVAL", why="Balances healing, sustain and staying alive while alone.", weights={
        [FX.RESTORE_HEALTH]=190, [FX.RESTORE_MAGICKA]=115, [FX.RESTORE_STAMINA]=115,
        [FX.UNSTOPPABLE]=145, [FX.PROTECTION]=120, [FX.VITALITY]=110, [FX.LINGERING_HEALTH]=105,
        [FX.SPEED]=65,
    }},
    { key="PVP", title="PVP", why="Prioritizes mobility, control resistance, recovery and utility.", weights={
        [FX.UNSTOPPABLE]=190, [FX.SPEED]=150, [FX.RESTORE_HEALTH]=145,
        [FX.RESTORE_MAGICKA]=105, [FX.RESTORE_STAMINA]=105, [FX.INVISIBLE]=95,
        [FX.DETECTION]=85, [FX.PROTECTION]=75,
    }},
    { key="BEGINNER", title="BEGINNER / CHEAP", why="Useful two-reagent option that avoids rare/dynamic ingredients when possible.", beginner=true, weights={
        [FX.RESTORE_HEALTH]=145, [FX.RESTORE_MAGICKA]=110, [FX.RESTORE_STAMINA]=110,
        [FX.INCREASE_SPELL_POWER]=95, [FX.INCREASE_WEAPON_POWER]=95,
        [FX.SPELL_CRITICAL]=88, [FX.WEAPON_CRITICAL]=88, [FX.UNSTOPPABLE]=70,
    }},
    { key="ENDGAME", title="ENDGAME", why="Highest raw combat score available from the planner catalog.", endgame=true },
}

local POISON_RECOMMENDATION_PROFILES = {
    { key="OVERALL", title="BEST OVERALL", why="Strongest general-purpose offensive poison in the planner.", weights={
        [FX.GRADUAL_RAVAGE_HEALTH]=190, [FX.RAVAGE_HEALTH]=180, [FX.VULNERABILITY]=145,
        [FX.BREACH]=125, [FX.FRACTURE]=125, [FX.DEFILE]=105, [FX.HINDRANCE]=80,
    }},
    { key="DAMAGE", title="MAX DAMAGE", why="Prioritizes direct and lingering health pressure.", weights={
        [FX.GRADUAL_RAVAGE_HEALTH]=220, [FX.RAVAGE_HEALTH]=210, [FX.VULNERABILITY]=135,
        [FX.BREACH]=105, [FX.FRACTURE]=105,
    }},
    { key="PVP", title="PVP PRESSURE", why="Combines damage with healing reduction, vulnerability or movement pressure.", weights={
        [FX.DEFILE]=190, [FX.VULNERABILITY]=175, [FX.RAVAGE_HEALTH]=145,
        [FX.GRADUAL_RAVAGE_HEALTH]=145, [FX.HINDRANCE]=135, [FX.MAIM]=105,
        [FX.COWARDICE]=105,
    }},
    { key="MAGICKA", title="MAGICKA PRESSURE", why="Targets Magicka users with resource and spell-pressure effects.", weights={
        [FX.RAVAGE_MAGICKA]=195, [FX.COWARDICE]=165, [FX.UNCERTAINTY]=150,
        [FX.RAVAGE_HEALTH]=90, [FX.VULNERABILITY]=90,
    }},
    { key="STAMINA", title="STAMINA PRESSURE", why="Targets Stamina users with resource and weapon-pressure effects.", weights={
        [FX.RAVAGE_STAMINA]=195, [FX.MAIM]=165, [FX.ENERVATION]=150,
        [FX.RAVAGE_HEALTH]=90, [FX.VULNERABILITY]=90,
    }},
    { key="CONTROL", title="CONTROL", why="Prioritizes slows, immobilization-style pressure and combat disruption.", weights={
        [FX.HINDRANCE]=200, [FX.ENTRAPMENT]=190, [FX.TIMIDITY]=155,
        [FX.COWARDICE]=135, [FX.MAIM]=120, [FX.DEFILE]=95,
    }},
    { key="BEGINNER", title="BEGINNER / CHEAP", why="Useful two-reagent poison that avoids rare/dynamic ingredients when possible.", beginner=true, weights={
        [FX.RAVAGE_HEALTH]=175, [FX.RAVAGE_STAMINA]=120, [FX.RAVAGE_MAGICKA]=120,
        [FX.HINDRANCE]=95, [FX.FRACTURE]=85, [FX.BREACH]=85,
    }},
    { key="ENDGAME", title="ENDGAME", why="Highest raw offensive/debuff score available from the planner catalog.", endgame=true },
}

local function ProfileRecipeScore(mode, result, profile)
    if not result or not profile then return -1000000 end
    local score = 0
    local matched = 0
    if profile.endgame then
        local base, useful = BestRecipeScore(mode, result.effects)
        if useful < 2 then return -1000000 end
        score = base * 10
        matched = useful
    else
        for _, effectId in ipairs(result.effects or {}) do
            local w = profile.weights and profile.weights[tonumber(effectId)] or nil
            if w then score = score + w; matched = matched + 1 else score = score - 18 end
        end
        if matched < 2 then return -1000000 end
        score = score + (#(result.effects or {}) >= 3 and 55 or 0)
    end

    if profile.beginner then
        if #(result.combo or {}) == 2 then score = score + 130 else score = score - 85 end
        for _, reagent in ipairs(result.combo or {}) do
            if reagent.sourceKind == "DYNAMIC" then score = score - 120 end
            if reagent.kind == "CLAM" then score = score - 65 end
        end
    end
    -- Recommendation quality is independent of what the player currently owns.
    -- Ownership is only a small tie-breaker so "best" never becomes "whatever is in my bag".
    if result.ready then score = score + 2 end
    return score
end

function A:BuildBestResults()
    self:ScanMaterials()
    local mode = EPC.saved.alchemyPotionMakerMode == "POISON" and "POISON" or "POTION"
    local cacheKey = "RECOMMENDED:" .. mode .. ":" .. (self:IsThirdSlotUnlocked() and "3" or "2")
    self.resultCache = self.resultCache or {}
    if self.resultCache[cacheKey] then return self.resultCache[cacheKey] end

    local catalog = self:GetCatalogWithOwnership()
    local allowThree = self:IsThirdSlotUnlocked()
    local candidates = {}
    local bestByEffects = {}
    local function consider(combo)
        local active = self:GetActiveEffects(combo)
        if #active < 2 then return end
        local result = self:BuildResult(combo, active, mode, #active)
        result.bestScore = select(1, BestRecipeScore(mode, active))
        local key = table.concat(active, "|")
        local old = bestByEffects[key]
        if not old
            or #combo < #old.combo
            or (#combo == #old.combo and result.missingCount < old.missingCount)
            or (#combo == #old.combo and result.missingCount == old.missingCount and result.maxCraftable > old.maxCraftable)
        then
            bestByEffects[key] = result
        end
    end

    for i = 1, #catalog - 1 do
        for j = i + 1, #catalog do consider({catalog[i], catalog[j]}) end
    end
    if allowThree then
        for i = 1, #catalog - 2 do
            for j = i + 1, #catalog - 1 do
                for k = j + 1, #catalog do consider({catalog[i], catalog[j], catalog[k]}) end
            end
        end
    end
    for _, result in pairs(bestByEffects) do candidates[#candidates + 1] = result end

    local profiles = mode == "POISON" and POISON_RECOMMENDATION_PROFILES or POTION_RECOMMENDATION_PROFILES
    local out, usedSignature = {}, {}
    for rank, profile in ipairs(profiles) do
        local best, bestScore
        for _, result in ipairs(candidates) do
            local score = ProfileRecipeScore(mode, result, profile)
            local sig = result.effectsText .. "|" .. result.reagentsText
            -- Prefer a distinct recipe for each category, but allow reuse if no
            -- genuinely suitable alternate exists.
            if usedSignature[sig] then score = score - 35 end
            if not best or score > bestScore
                or (score == bestScore and #result.effects > #best.effects)
                or (score == bestScore and #result.effects == #best.effects and #result.combo < #best.combo)
            then
                best, bestScore = result, score
            end
        end
        if best and bestScore and bestScore > -1000000 then
            local copy = {}
            for k,v in pairs(best) do copy[k]=v end
            copy.recommendationRank = rank
            copy.recommendationKey = profile.key
            copy.recommendationTitle = profile.title
            copy.recommendationWhy = profile.why
            copy.recommendationScore = bestScore
            out[#out + 1] = copy
            usedSignature[best.effectsText .. "|" .. best.reagentsText] = true
        end
    end

    self.resultCache[cacheKey] = out
    return out
end

function A:GetAutoCraftLabel()
    self:EnsureSaved()
    if EPC.saved.alchemyPotionMakerAutoCraft ~= true then return "OFF" end
    local mode = tostring(EPC.saved.alchemyPotionMakerAutoCraftMode or "ONE")
    if mode == "MAX" then return "ON / MAX" end
    if mode == "CUSTOM" then
        return "ON / x" .. tostring(math.max(1, math.floor(num(EPC.saved.alchemyPotionMakerAutoCraftQuantity, 1))))
    end
    return "ON / x1"
end

function A:GetStatusText()
    self:EnsureSaved()
    if not self.reagentList or not self.solvents then self:ScanMaterials() end
    local mode = EPC.saved.alchemyPotionMakerMode == "POISON" and "POISON" or "POTION"
    local solvent = self:GetBestSolvent(mode)
    local solventText = solvent and string.format("%s x%d", solvent.name, solvent.count) or ("NONE (need " .. self:GetExpectedSolventName(mode) .. ")")
    return string.format("%s | Solvent: %s | Reagents: %d | 3rd: %s | Auto: %s",
        mode == "POISON" and "POISON" or "POTION",
        solventText,
        #(self.reagentList or {}),
        self:IsThirdSlotUnlocked() and "YES" or "NO",
        self:GetAutoCraftLabel())
end

function A:GetMissingTrackingMaterials(result)
    local materials = {}
    local seen = {}
    if not result then return materials end

    for _, reagent in ipairs(result.combo or {}) do
        local owned = reagent.owned or (self.reagentsByName and self.reagentsByName[reagent.key])
        if not owned or num(owned.count, 0) < 1 then
            local itemId = tonumber(reagent.itemId) or 0
            local identity = itemId > 0 and ("id:" .. tostring(itemId)) or tostring(reagent.key or reagent.name or "")
            if not seen[identity] then
                seen[identity] = true
                materials[#materials + 1] = {
                    name = tostring(reagent.name or ("Item " .. tostring(itemId))),
                    key = identity,
                    itemId = itemId,
                    kind = tostring(reagent.kind or "ALCHEMY"),
                    dynamicHint = reagent.sourceKind == "DYNAMIC" and "dynamic source" or nil,
                }
            end
        end
    end

    if not result.solvent then
        local rank = self:GetSolventProficiencyIndex()
        local itemId = solventIdForRank(result.mode, rank)
        local identity = "id:" .. tostring(itemId)
        if not seen[identity] then
            seen[identity] = true
            materials[#materials + 1] = {
                name = self:GetExpectedSolventName(result.mode),
                key = identity,
                itemId = itemId,
                kind = result.mode == "POISON" and "ALCHEMY" or "WATER",
                dynamicHint = result.mode == "POISON" and "dynamic source" or nil,
                solvent = true,
            }
        end
    end
    return materials
end

function A:GetMissingRouteInfo(result)
    if not result or result.ready then return nil end
    local materials = self:GetMissingTrackingMaterials(result)
    local signature = {}
    for _, material in ipairs(materials) do signature[#signature + 1] = tostring(material.key or material.name or "") end
    table.sort(signature)
    signature = table.concat(signature, "|")
    if result.easMissingRouteSignature == signature and type(result.easMissingRoute) == "table" then
        return result.easMissingRoute
    end
    local pins = EPC and EPC.ResourcePins
    local route = nil
    if pins and type(pins.GetMissingAlchemyRoute) == "function" then
        route = pins:GetMissingAlchemyRoute(materials)
    end
    result.easMissingRouteSignature = signature
    result.easMissingRoute = route
    return route
end

function A:GetMissingRouteDetails(result)
    if not result or result.ready then return {} end
    local materials = self:GetMissingTrackingMaterials(result)
    local signatureParts = {}
    for _, material in ipairs(materials) do signatureParts[#signatureParts + 1] = tostring(material.key or material.name or "") end
    table.sort(signatureParts)
    local signature = table.concat(signatureParts, "|")
    if result.easMissingRouteDetailsSignature == signature and type(result.easMissingRouteDetails) == "table" then
        return result.easMissingRouteDetails
    end

    local details = {}
    local pins = EPC and EPC.ResourcePins
    for _, material in ipairs(materials) do
        local entry = { material = material, route = nil }
        if pins and type(pins.GetMissingAlchemyRoute) == "function" then
            entry.route = pins:GetMissingAlchemyRoute({ material })
        end
        details[#details + 1] = entry
    end
    result.easMissingRouteDetailsSignature = signature
    result.easMissingRouteDetails = details
    return details
end

function A:GetMissingRouteSummaryText(result)
    local details = self:GetMissingRouteDetails(result)
    if type(details) ~= "table" or #details == 0 then
        return "Missing: " .. table.concat(result and result.missing or {}, ", ")
    end
    local parts = {}
    for i = 1, math.min(2, #details) do
        local detail = details[i]
        local materialName = tostring(detail.material and detail.material.name or "material")
        local route = type(detail.route) == "table" and detail.route or nil
        if route then
            parts[#parts + 1] = string.format("%s • %s • %s", materialName, tostring(route.zoneName or "Unknown zone"), tostring(route.locationText or "known area"))
        else
            parts[#parts + 1] = materialName
        end
    end
    if #details > 2 then parts[#parts + 1] = string.format("+%d more", #details - 2) end
    return table.concat(parts, "   |   ")
end

function A:TravelToMissing(result)
    if not result or result.ready then return false end
    local pins = EPC and EPC.ResourcePins
    if not pins or type(pins.TravelToMissingAlchemyMaterials) ~= "function" then
        notify("Alchemy material travel is unavailable.", false)
        return false
    end

    local details = self:GetMissingRouteDetails(result)
    if type(details) == "table" and #details > 1 then
        result.easTravelRouteIndex = ((tonumber(result.easTravelRouteIndex) or 0) % #details) + 1
        local detail = details[result.easTravelRouteIndex]
        if detail and detail.material then
            local route = type(detail.route) == "table" and detail.route or nil
            notify(string.format("TRAVEL TARGET: %s%s", tostring(detail.material.name or "Missing material"), route and (" in " .. tostring(route.zoneName or "Unknown zone")) or ""), true)
            return pins:TravelToMissingAlchemyMaterials({ detail.material })
        end
    end

    local materials = self:GetMissingTrackingMaterials(result)
    return pins:TravelToMissingAlchemyMaterials(materials)
end

function A:ReportMissing(result)
    if not result or result.ready then return end
    local missingText = #result.missing > 0 and table.concat(result.missing, ", ") or "unknown materials"
    local materials = self:GetMissingTrackingMaterials(result)
    local pins = EPC and EPC.ResourcePins

    if pins and type(pins.TrackMissingAlchemyMaterials) == "function" and #materials > 0 then
        local tracked, unsupported, route = pins:TrackMissingAlchemyMaterials(materials)
        tracked = tonumber(tracked) or 0
        unsupported = type(unsupported) == "table" and unsupported or {}
        route = type(route) == "table" and route or self:GetMissingRouteInfo(result)
        if route then
            local shrine = route.wayshrineName or "no discovered wayshrine"
            notify(string.format("ALCHEMY ROUTE: %s at %s in %s. Closest wayshrine: %s.", tostring(route.resourceName or "resource area"), tostring(route.locationText or "known location"), tostring(route.zoneName or "Unknown zone"), tostring(shrine)), true)
        end
        local details = self:GetMissingRouteDetails(result)
        if type(details) == "table" and #details > 0 then
            for i, detail in ipairs(details) do
                local detailRoute = type(detail.route) == "table" and detail.route or nil
                if detailRoute then
                    notify(string.format("Need %s: %s • %s • %s", tostring(detail.material and detail.material.name or ("material " .. tostring(i))), tostring(detailRoute.zoneName or "Unknown zone"), tostring(detailRoute.locationText or "known area"), tostring(detailRoute.wayshrineName or "no discovered wayshrine")), true)
                elseif detail and detail.material then
                    notify(string.format("Need %s: no fixed route found.", tostring(detail.material.name or ("material " .. tostring(i)))), false)
                end
            end
        end
        if tracked > 0 then
            notify(string.format("ALCHEMY HUNT: %d known spawn pin%s marked. If more than one ingredient is missing, TRAVEL cycles through each missing material one press at a time; after arrival the bright 3D hunt pin will guide you to the resource area.", tracked, tracked == 1 and "" or "s"), true)
            if type(pins.ShowMissingAlchemyMap) == "function" then
                pins:ShowMissingAlchemyMap()
            end
            if #unsupported > 0 then
                notify("No fixed node for: " .. table.concat(unsupported, ", ") .. ". Dynamic drops cannot be given fake 3D coordinates.", false)
            end
            return
        end
    end

    notify("ALCHEMY MAKER missing: " .. missingText .. ". Recipe: " .. tostring(result.reagentsText), false)
end

function A:PrepareResult(result, quietSuccess)
    if not result then return false, nil end
    if not result.ready then self:ReportMissing(result) return false, nil end
    if not self:IsAtAlchemyStation() then
        notify("Open an Alchemy Station before preparing ingredients.", false)
        return false, nil
    end
    local alchemy = rawget(_G, "ALCHEMY")
    if type(alchemy) ~= "table" or type(alchemy.AddItemToCraft) ~= "function" then
        notify("Alchemy crafting UI is not available.", false)
        return false, nil
    end

    if type(alchemy.ClearSelections) == "function" then
        local ok = pcall(alchemy.ClearSelections, alchemy)
        if not ok then notify("Could not clear the current Alchemy slots.", false) return false, nil end
    end

    local function canAdd(bagId, slotIndex)
        if bagId == nil or slotIndex == nil then return false end
        if type(alchemy.CanItemBeAddedToCraft) == "function" then
            local ok, allowed = pcall(alchemy.CanItemBeAddedToCraft, alchemy, bagId, slotIndex)
            if ok then return allowed ~= false end
        end
        return true
    end

    local function add(bagId, slotIndex, label, quiet)
        if bagId == nil or slotIndex == nil then return false end
        if not canAdd(bagId, slotIndex) then
            if not quiet then notify("Alchemy cannot slot " .. tostring(label) .. " for this character/station.", false) end
            return false
        end
        local ok, added = pcall(alchemy.AddItemToCraft, alchemy, bagId, slotIndex)
        if not ok or added == false then
            if not quiet then notify("Could not add " .. tostring(label) .. " to the Alchemy table.", false) end
            return false
        end
        return true
    end

    local solvent
    local candidates = self:GetUsableSolvents(result.mode)
    if result.solvent and self:IsSolventLevelUsable(result.solvent) then
        local preferred = result.solvent
        local reordered = { preferred }
        for _, candidate in ipairs(candidates) do
            if candidate ~= preferred then reordered[#reordered + 1] = candidate end
        end
        candidates = reordered
    end
    for _, candidate in ipairs(candidates) do
        if add(candidate.bagId, candidate.slotIndex, candidate.name, true) then
            solvent = candidate
            break
        end
    end
    if not solvent then
        notify("No usable " .. string.lower(result.mode == "POISON" and "poison" or "potion") .. " solvent could be slotted. Need a solvent your character's level and Solvent Proficiency can use (up to " .. self:GetExpectedSolventName(result.mode) .. ").", false)
        return false, nil
    end

    local reagentLocations = {}
    for _, reagent in ipairs(result.combo or {}) do
        local loc = self:GetOwnedLocation(reagent)
        if not loc or not add(loc.bagId, loc.slotIndex, reagent.name) then return false, nil end
        reagentLocations[#reagentLocations + 1] = { bagId = loc.bagId, slotIndex = loc.slotIndex, name = reagent.name }
    end

    if type(alchemy.OnSlotChanged) == "function" then pcall(alchemy.OnSlotChanged, alchemy) end
    local craftable = type(alchemy.IsCraftable) ~= "function" or safe(alchemy.IsCraftable, false, alchemy) == true
    local craftInfo = {
        result = result,
        solvent = solvent,
        reagents = reagentLocations,
    }
    self.lastPreparedCraft = craftInfo
    if craftable then
        if not quietSuccess then notify("ALCHEMY MAKER loaded: " .. result.reagentsText .. ". Press ESO's CRAFT button to make it.", true) end
    else
        notify("Ingredients were loaded, but ESO does not consider this mixture craftable yet. Check Alchemy passives/solvent requirements.", false)
    end
    return craftable, craftInfo
end

function A:GetMaxCraftIterations(craftInfo)
    if not craftInfo or not craftInfo.solvent or type(GetMaxIterationsPossibleForAlchemyItem) ~= "function" then return 0 end
    local r1, r2, r3 = craftInfo.reagents[1], craftInfo.reagents[2], craftInfo.reagents[3]
    if not r1 or not r2 then return 0 end
    local ok, maximum = pcall(GetMaxIterationsPossibleForAlchemyItem,
        craftInfo.solvent.bagId, craftInfo.solvent.slotIndex,
        r1.bagId, r1.slotIndex,
        r2.bagId, r2.slotIndex,
        r3 and r3.bagId or nil, r3 and r3.slotIndex or nil)
    if not ok then return 0 end
    return math.max(0, math.floor(num(maximum, 0)))
end

function A:GetRequestedAutoCraftIterations(maximum)
    self:EnsureSaved()
    maximum = math.max(0, math.floor(num(maximum, 0)))
    if maximum <= 0 then return 0 end
    local mode = tostring(EPC.saved.alchemyPotionMakerAutoCraftMode or "ONE")
    if mode == "MAX" then return maximum end
    if mode == "CUSTOM" then
        return math.min(maximum, math.max(1, math.floor(num(EPC.saved.alchemyPotionMakerAutoCraftQuantity, 1))))
    end
    return 1
end

function A:AutoCraftResult(result)
    self:EnsureSaved()
    if EPC.saved.alchemyPotionMakerAutoCraft ~= true then return self:PrepareResult(result) end
    if type(ZO_CraftingUtils_IsPerformingCraftProcess) == "function" and safe(ZO_CraftingUtils_IsPerformingCraftProcess, false) == true then
        notify("Alchemy is already crafting. Wait for the current craft to finish.", false)
        return false
    end
    if type(CraftAlchemyItem) ~= "function" then
        notify("ESO's Alchemy craft function is unavailable. Ingredients were not crafted automatically.", false)
        return self:PrepareResult(result)
    end

    local craftable, info = self:PrepareResult(result, true)
    if not craftable or not info then return false end
    local maximum = self:GetMaxCraftIterations(info)
    local iterations = self:GetRequestedAutoCraftIterations(maximum)
    if iterations < 1 then
        notify("This mixture cannot be crafted with the currently slotted materials.", false)
        return false
    end
    local r1, r2, r3 = info.reagents[1], info.reagents[2], info.reagents[3]
    local ok, err = pcall(CraftAlchemyItem,
        info.solvent.bagId, info.solvent.slotIndex,
        r1.bagId, r1.slotIndex,
        r2.bagId, r2.slotIndex,
        r3 and r3.bagId or nil, r3 and r3.slotIndex or nil,
        iterations)
    if not ok then
        notify("Auto Craft could not start: " .. tostring(err or "unknown Alchemy error"), false)
        return false
    end
    notify(string.format("ALCHEMY AUTO CRAFT: started %d iteration%s of %s.", iterations, iterations == 1 and "" or "s", tostring(result.effectsText ~= "" and result.effectsText or result.reagentsText)), true)
    return true
end

function A:ActivateResult(result)
    if not result then return false end
    self:EnsureSaved()
    if EPC.saved.alchemyPotionMakerAutoCraft == true then return self:AutoCraftResult(result) end
    return self:PrepareResult(result)
end

function A:SetMode(mode)
    self:EnsureSaved()
    EPC.saved.alchemyPotionMakerMode = mode == "POISON" and "POISON" or "POTION"
    self.currentPage = 1
    -- Mode changes do not change inventory. Reuse the material scan and any
    -- already-built result set instead of rescanning BAG_VIRTUAL synchronously.
    self:RefreshWindow(false)
    self:RefreshStatus()
end

function A:ToggleMode()
    self:SetMode(EPC.saved.alchemyPotionMakerMode == "POISON" and "POTION" or "POISON")
end

function A:SetView(view)
    if view == "EXACT" then
        self.currentView = "EXACT"
    elseif view == "BEST" then
        self.currentView = "BEST"
    else
        self.currentView = "READY"
    end
    self.currentPage = 1
    self:RefreshWindow(false)
end

function A:SetEffect(slot, value)
    self:EnsureSaved()
    slot = math.max(1, math.min(3, num(slot, 1)))
    EPC.saved["alchemyPotionMakerEffect" .. slot] = tonumber(value) or 0
    self.currentPage = 1
    self:RefreshWindow(false)
end

function A:CreateEffectPopup()
    if self.effectPopup or not wm or not GuiRoot then return end
    local popup = wm:CreateTopLevelWindow("EAS_AlchemyPotionMakerEffectPopup")
    popup:SetDimensions(EFFECT_POPUP_W, EFFECT_POPUP_H)
    popup:SetMouseEnabled(true)
    popup:SetMovable(false)
    popup:SetClampedToScreen(true)
    if popup.SetDrawTier then popup:SetDrawTier(rawget(_G, "DT_HIGH") or DT_HIGH) end
    if popup.SetDrawLayer then popup:SetDrawLayer(rawget(_G, "DL_OVERLAY") or DL_OVERLAY) end
    if popup.SetDrawLevel then popup:SetDrawLevel(12000) end
    popup:SetHidden(true)
    self.effectPopup = popup

    local bg = wm:CreateControl(nil, popup, CT_BACKDROP)
    bg:SetAnchorFill(popup)
    bg:SetCenterColor(0.008, 0.014, 0.024, 0.995)
    bg:SetEdgeColor(0.82, 0.62, 0.18, 1)
    bg:SetEdgeTexture(nil, 2, 2, 1)

    local title = wm:CreateControl(nil, popup, CT_LABEL)
    title:SetFont("ZoFontWinH2")
    title:SetAnchor(TOPLEFT, popup, TOPLEFT, 18, 12)
    title:SetDimensions(EFFECT_POPUP_W - 80, 36)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    title:SetColor(0.94, 0.84, 0.38, 1)
    self.effectPopupTitle = title

    local close = wm:CreateControl(nil, popup, CT_BUTTON)
    close:SetDimensions(38, 38)
    close:SetAnchor(TOPRIGHT, popup, TOPRIGHT, -10, 8)
    close:SetFont("ZoFontWinH3")
    close:SetText("X")
    close:SetHandler("OnClicked", function() popup:SetHidden(true) end)

    self.effectPopupButtons = {}
    local colW = math.floor((EFFECT_POPUP_W - 54) / 2)
    for i = 1, EFFECT_POPUP_ROWS * 2 do
        local col = i > EFFECT_POPUP_ROWS and 2 or 1
        local row = ((i - 1) % EFFECT_POPUP_ROWS) + 1
        local btn = wm:CreateControl(nil, popup, CT_BUTTON)
        btn:SetDimensions(colW, 30)
        btn:SetAnchor(TOPLEFT, popup, TOPLEFT, 18 + (col - 1) * (colW + 12), 58 + (row - 1) * 31)
        btn:SetFont("ZoFontGame")
        btn:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        btn:SetHandler("OnClicked", function(control)
            local value = control.effectValue
            if value ~= nil then self:SetEffect(self.effectPopupSlot or 1, value) end
            popup:SetHidden(true)
        end)
        self.effectPopupButtons[i] = btn
    end

    local note = wm:CreateControl(nil, popup, CT_LABEL)
    note:SetFont("ZoFontGameSmall")
    note:SetAnchor(BOTTOMLEFT, popup, BOTTOMLEFT, 18, -10)
    note:SetDimensions(EFFECT_POPUP_W - 36, 24)
    note:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    note:SetColor(0.68, 0.76, 0.84, 1)
    note:SetText("This selector is a separate top-level overlay so it always stays above the Crafting Assistant.")
end

function A:ShowEffectMenu(owner, slot)
    self:CreateEffectPopup()
    self:EnsurePlannerCatalog()
    if not self.effectPopup then return end
    self.effectPopupSlot = math.max(1, math.min(3, num(slot, 1)))
    if self.effectPopupTitle then self.effectPopupTitle:SetText("SELECT EFFECT " .. tostring(self.effectPopupSlot)) end

    local choices = {}
    if self.effectPopupSlot == 1 then
        choices[#choices + 1] = { label = self:GetEffectName(FX.RESTORE_HEALTH) .. " (Default)", value = FX.RESTORE_HEALTH }
    else
        choices[#choices + 1] = { label = "-- NONE --", value = 0 }
    end
    for _, effectId in ipairs(self.effectChoices or {}) do
        if not (self.effectPopupSlot == 1 and effectId == FX.RESTORE_HEALTH) then
            choices[#choices + 1] = { label = self:GetEffectName(effectId), value = effectId }
        end
    end

    for i, btn in ipairs(self.effectPopupButtons or {}) do
        local choice = choices[i]
        btn.effectValue = choice and choice.value or nil
        btn:SetHidden(choice == nil)
        if choice then
            btn:SetText(choice.label)
            local current = tonumber(EPC.saved["alchemyPotionMakerEffect" .. self.effectPopupSlot]) or 0
            if current == choice.value then btn:SetFont("ZoFontGameBold") else btn:SetFont("ZoFontGame") end
        end
    end

    self.effectPopup:ClearAnchors()
    self.effectPopup:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    self.effectPopup:SetHidden(false)
    if self.effectPopup.BringWindowToTop then self.effectPopup:BringWindowToTop() end
end

function A:RefreshStatus()
    if not self.button then return end
    if not self:IsAtAlchemyStation() and not self.layoutMode then
        if self.countLabel then self.countLabel:SetText("0") end
        return
    end
    local count = 0
    if self:IsAtAlchemyStation() then
        local ok, results = pcall(function() return self:BuildCanMakeResults() end)
        if ok and type(results) == "table" then
            count = #results
            self.cachedReadyResults = results
        end
    end
    if self.countLabel then self.countLabel:SetText(count > 99 and "99+" or tostring(count)) end
    if self.glow then
        if self.layoutMode then self.glow:SetEdgeColor(1.00, 0.72, 0.22, 1)
        elseif count > 0 then self.glow:SetEdgeColor(0.20, 0.85, 0.62, 1)
        else self.glow:SetEdgeColor(0.28, 0.36, 0.46, 0.9) end
    end
end

function A:RefreshVisibility()
    self:EnsureSaved()
    self:CreateIcon()
    if not self.button then return end
    local layout = self.layoutMode == true or (EPC and EPC.unitFramesMoveMode == true)
    local show = layout or (EPC.saved.alchemyPotionMakerEnabled ~= false and self:IsAtAlchemyStation())
    self.button:SetHidden(not show)
    if show then
        if layout then
            if self.countLabel then self.countLabel:SetText("MOVE") end
            if self.glow then self.glow:SetEdgeColor(1.00, 0.72, 0.22, 1) end
        else
            self:RefreshStatus()
        end
    end
    if self.window and not self.window:IsHidden() then
        if EPC.saved.alchemyPotionMakerEnabled == false then
            self:CloseWindow(true)
        elseif not show then
            local sceneShowing = false
            if SCENE_MANAGER and type(SCENE_MANAGER.IsShowing) == "function" then
                sceneShowing = safe(SCENE_MANAGER.IsShowing, false, SCENE_MANAGER, "ESOAdventurerSuitePotionMaker") == true
            end
            -- The station icon may be hidden while the full maker was opened
            -- from the top menu or a gameplay hotkey. Do not let icon visibility
            -- tear down that full UI.
            if self.directHotkeyOpen ~= true and not sceneShowing then self.window:SetHidden(true) end
        end
    end
end

function A:SetLayoutMode(active)
    active = active == true
    self:EnsureSaved()
    self:CreateIcon()
    self.layoutMode = active
    if not self.button then return end
    self.button:SetDimensions(NORMAL_W, NORMAL_H)
    self.button:SetMovable(true)
    self.button:SetMouseEnabled(true)
    if self.layoutDragHandle then
        self.layoutDragHandle:SetMouseEnabled(active)
        self.layoutDragHandle:SetHidden(not active)
    end
    if active then
        self.button:SetHidden(false)
        if self.button.SetTopLevel then self.button:SetTopLevel(true) end
        if self.button.SetDrawTier and DT_HIGH then self.button:SetDrawTier(DT_HIGH) end
        if self.button.SetDrawLayer and DL_OVERLAY then self.button:SetDrawLayer(DL_OVERLAY) end
        if self.button.SetDrawLevel then self.button:SetDrawLevel(950) end
        if self.button.BringWindowToTop then self.button:BringWindowToTop() end
        if self.countLabel then self.countLabel:SetText("MOVE") end
        if self.glow then self.glow:SetEdgeColor(1.00, 0.72, 0.22, 1) end
        if self.window and not self.window:IsHidden() then self.window:SetHidden(true) end
    else
        self:RefreshVisibility()
    end
end

function A:RaiseForLayout()
    if self.layoutMode ~= true or not self.button or self.button:IsHidden() then return end
    if self.button.SetTopLevel then self.button:SetTopLevel(true) end
    if self.button.SetDrawTier and DT_HIGH then self.button:SetDrawTier(DT_HIGH) end
    if self.button.SetDrawLayer and DL_OVERLAY then self.button:SetDrawLayer(DL_OVERLAY) end
    if self.button.SetDrawLevel then self.button:SetDrawLevel(950) end
    if self.button.BringWindowToTop then self.button:BringWindowToTop() end
end

function A:CreateIcon()
    if self.button or not wm or not GuiRoot then return end
    local b = wm:CreateTopLevelWindow("EAS_AlchemyPotionMakerIcon")
    b:SetDimensions(NORMAL_W, NORMAL_H)
    b:SetMouseEnabled(true)
    b:SetMovable(true)
    b:SetClampedToScreen(true)
    b:SetDrawTier(DT_HIGH)
    b:SetDrawLayer(DL_OVERLAY)
    b:SetDrawLevel(900)
    b:SetHidden(true)
    self.button = b

    local bg = wm:CreateControl(nil, b, CT_BACKDROP)
    bg:SetAnchorFill(b)
    bg:SetCenterColor(0.018, 0.026, 0.040, 0.96)
    bg:SetEdgeColor(0.28, 0.36, 0.46, 0.9)
    bg:SetEdgeTexture(nil, 1, 1, 1)
    self.glow = bg

    local icon = wm:CreateControl(nil, b, CT_TEXTURE)
    icon:SetDimensions(46, 46)
    icon:SetAnchor(CENTER, b, CENTER, 0, 0)
    icon:SetTexture(ICON_TEXTURE)
    self.icon = icon

    local count = wm:CreateControl(nil, b, CT_LABEL)
    count:SetFont("ZoFontGameBold")
    count:SetAnchor(BOTTOMRIGHT, bg, BOTTOMRIGHT, -3, -1)
    count:SetDimensions(34, 20)
    count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    count:SetColor(0.70, 1.00, 0.75, 1)
    count:SetText("0")
    self.countLabel = count

    b:SetHandler("OnMouseDown", function(control, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if self.layoutMode == true or (EPC and EPC.unitFramesMoveMode == true) then return end
        self.pressLeft = num(control:GetLeft(), 0)
        self.pressTop = num(control:GetTop(), 0)
        if control.StartMoving then control:StartMoving() end
    end)
    b:SetHandler("OnMouseUp", function(control, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if self.layoutMode == true or (EPC and EPC.unitFramesMoveMode == true) then return end
        if control.StopMoving then control:StopMoving() end
        local left, top = num(control:GetLeft(), 0), num(control:GetTop(), 0)
        self:SavePosition()
        local moved = math.abs(left - num(self.pressLeft, left)) > 4 or math.abs(top - num(self.pressTop, top)) > 4
        self.pressLeft, self.pressTop = nil, nil
        if upInside ~= false and not moved then self:ToggleWindow() end
    end)
    b:SetHandler("OnMoveStop", function(control)
        if control.StopMoving then control:StopMoving() end
        self:SavePosition()
    end)

    local handle = wm:CreateControl(nil, b, CT_CONTROL)
    handle:SetAnchorFill(b)
    handle:SetMouseEnabled(false)
    handle:SetHidden(true)
    if handle.SetDrawLayer and DL_OVERLAY then handle:SetDrawLayer(DL_OVERLAY) end
    if handle.SetDrawLevel then handle:SetDrawLevel(2000) end
    handle:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if self.layoutMode ~= true and not (EPC and EPC.unitFramesMoveMode == true) then return end
        self.layoutDragging = true
        if b.BringWindowToTop then b:BringWindowToTop() end
        if b.StartMoving then b:StartMoving() end
    end)
    handle:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or self.layoutDragging ~= true then return end
        self.layoutDragging = false
        if b.StopMoving then b:StopMoving() end
        self:SavePosition()
    end)
    self.layoutDragHandle = handle

    b:SetHandler("OnMouseEnter", function(control)
        if InformationTooltip and type(InitializeTooltip) == "function" then
            InitializeTooltip(InformationTooltip, control, TOPRIGHT, 0, 0, TOPLEFT)
            InformationTooltip:AddLine("CRAFTING ASSISTANT", "ZoFontWinH4")
            InformationTooltip:AddLine("At an Alchemy Station, click to see mixtures you can make now or choose exact effects and see the reagents/solvent you need.", "ZoFontGame")
            InformationTooltip:AddLine("Click a READY recipe to auto-slot the solvent and reagents. You still press ESO's Craft button.", "ZoFontGameSmall")
        end
    end)
    b:SetHandler("OnMouseExit", function() if InformationTooltip and type(ClearTooltip)=="function" then ClearTooltip(InformationTooltip) end end)
    self:RestorePosition()
end

local function setButtonText(button, text)
    if not button then return end
    if type(button.SetText) == "function" then button:SetText(text) end
end

function A:CloseWindow(returnToGame)
    if self.effectPopup then self.effectPopup:SetHidden(true) end
    if self.window then self.window:SetHidden(true) end

    -- v0.29.270: gameplay hotkeys can open this same window without routing
    -- through LibMainMenu. Tear down that direct-hotkey UI mode here as well,
    -- including when the X button is used, so closing never leaves the player
    -- stuck with the mouse/UI camera active.
    if self.directHotkeyOpen == true then
        self.directHotkeyOpen = false
        self.hotkeyOpenPending = false
        self:SetHotkeyActionLayer(false)
        if self.hotkeyOwnsUIMode == true then self:SetHotkeyUIMode(false) end
        self.hotkeyOwnsUIMode = false
    end

    -- When Potion Maker was opened from its top main-menu icon, hiding only
    -- the custom window leaves the dedicated scene active. That makes the UI
    -- disappear but keeps the player stuck in menu mode. Close that scene too
    -- so the X button behaves like the normal ESO menu close and returns to play.
    if returnToGame ~= false and SCENE_MANAGER then
        local sceneName = "ESOAdventurerSuitePotionMaker"
        local showing = false
        if type(SCENE_MANAGER.IsShowing) == "function" then
            showing = safe(SCENE_MANAGER.IsShowing, false, SCENE_MANAGER, sceneName) == true
        end
        if not showing and self.mainMenuScene and type(self.mainMenuScene.IsShowing) == "function" then
            showing = safe(self.mainMenuScene.IsShowing, false, self.mainMenuScene) == true
        end
        if showing then
            if type(SCENE_MANAGER.ShowBaseScene) == "function" then
                pcall(SCENE_MANAGER.ShowBaseScene, SCENE_MANAGER)
            elseif type(SCENE_MANAGER.HideCurrentScene) == "function" then
                pcall(SCENE_MANAGER.HideCurrentScene, SCENE_MANAGER)
            end
        end
    end
end

function A:CreateWindow()
    if self.window or not wm or not GuiRoot then return end
    local w = wm:CreateTopLevelWindow("EAS_AlchemyPotionMakerWindow")
    w:SetDimensions(PANEL_W, PANEL_H)
    w:SetMouseEnabled(true)
    w:SetMovable(true)
    w:SetClampedToScreen(true)
    if w.SetDrawTier then w:SetDrawTier(rawget(_G, "DT_MEDIUM") or rawget(_G, "DT_LOW") or DT_HIGH) end
    if w.SetDrawLayer then w:SetDrawLayer(rawget(_G, "DL_CONTROLS") or DL_CONTROLS) end
    if w.SetDrawLevel then w:SetDrawLevel(120) end
    w:SetHidden(true)
    self.window = w

    local bg = wm:CreateControl(nil, w, CT_BACKDROP)
    bg:SetAnchorFill(w)
    bg:SetCenterColor(0.010, 0.015, 0.026, 0.988)
    bg:SetEdgeColor(0.24, 0.68, 0.88, 0.95)
    bg:SetEdgeTexture(nil, 2, 2, 1)

    local function makeButton(parent, width, height, font)
        local b = wm:CreateControl(nil, parent, CT_BUTTON)
        b:SetDimensions(width, height)
        b:SetFont(font or "ZoFontGameBold")
        b:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        b:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        local bb = wm:CreateControl(nil, b, CT_BACKDROP)
        bb:SetAnchorFill(b)
        bb:SetCenterColor(0.035, 0.050, 0.070, 0.96)
        bb:SetEdgeColor(0.22, 0.34, 0.44, 0.95)
        bb:SetEdgeTexture(nil, 1, 1, 1)
        b.easBg = bb
        b:SetHandler("OnMouseEnter", function(control)
            if control.easBg then control.easBg:SetCenterColor(0.06, 0.09, 0.12, 0.98) end
        end)
        b:SetHandler("OnMouseExit", function(control)
            if control.easBg then control.easBg:SetCenterColor(0.035, 0.050, 0.070, 0.96) end
        end)
        return b
    end

    local titleBar = wm:CreateControl(nil, w, CT_CONTROL)
    titleBar:SetDimensions(PANEL_W - 54, 50)
    titleBar:SetAnchor(TOPLEFT, w, TOPLEFT, 8, 4)
    titleBar:SetMouseEnabled(true)
    titleBar:SetHandler("OnMouseDown", function(_, button) if button==MOUSE_BUTTON_INDEX_LEFT and w.StartMoving then w:StartMoving() end end)
    titleBar:SetHandler("OnMouseUp", function(_, button) if button==MOUSE_BUTTON_INDEX_LEFT then if w.StopMoving then w:StopMoving() end self:SavePanelPosition() end end)

    local title = wm:CreateControl(nil, titleBar, CT_LABEL)
    title:SetFont("ZoFontWinH2")
    title:SetAnchor(TOPLEFT, titleBar, TOPLEFT, 14, 4)
    title:SetDimensions(PANEL_W - 120, 28)
    title:SetColor(0.96, 0.84, 0.36, 1)
    title:SetText("CRAFTING ASSISTANT")

    local subtitle = wm:CreateControl(nil, titleBar, CT_LABEL)
    subtitle:SetFont("ZoFontGameSmall")
    subtitle:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 2, -2)
    subtitle:SetDimensions(PANEL_W - 140, 20)
    subtitle:SetColor(0.68, 0.77, 0.86, 1)
    subtitle:SetText("Alchemy recipe planning plus shared material hunting for every supported craft.")

    local close = makeButton(w, 38, 38, "ZoFontWinH3")
    close:SetAnchor(TOPRIGHT, w, TOPRIGHT, -10, 8)
    close:SetText("X")
    close:SetHandler("OnClicked", function() self:CloseWindow(true) end)

    -- STEP 1: potion / poison selection
    local step1 = wm:CreateControl(nil, w, CT_LABEL)
    step1:SetFont("ZoFontGameBold")
    step1:SetAnchor(TOPLEFT, w, TOPLEFT, 22, 62)
    step1:SetDimensions(110, 28)
    step1:SetColor(0.72, 0.82, 0.92, 1)
    step1:SetText("1. ALCHEMY")

    local potionMode = makeButton(w, 150, 38)
    potionMode:SetAnchor(LEFT, step1, RIGHT, 8, 0)
    potionMode:SetText("POTION")
    potionMode:SetHandler("OnClicked", function() self:SetMode("POTION") end)
    self.potionModeButton = potionMode

    local poisonMode = makeButton(w, 150, 38)
    poisonMode:SetAnchor(LEFT, potionMode, RIGHT, 8, 0)
    poisonMode:SetText("POISON")
    poisonMode:SetHandler("OnClicked", function() self:SetMode("POISON") end)
    self.poisonModeButton = poisonMode
    self.modeButton = potionMode -- compatibility with older refresh paths

    -- STEP 2: recipe filters get their own row so each choice is obvious.
    local step2 = wm:CreateControl(nil, w, CT_LABEL)
    step2:SetFont("ZoFontGameBold")
    step2:SetAnchor(TOPLEFT, w, TOPLEFT, 22, 108)
    step2:SetDimensions(110, 28)
    step2:SetColor(0.72, 0.82, 0.92, 1)
    step2:SetText("2. RECIPE")

    local readyTab = makeButton(w, 200, 38)
    readyTab:SetAnchor(LEFT, step2, RIGHT, 8, 0)
    readyTab:SetText("WHAT CAN I MAKE?")
    readyTab:SetHandler("OnClicked", function() self:SetView("READY") end)
    self.readyTab = readyTab

    local bestTab = makeButton(w, 190, 38)
    bestTab:SetAnchor(LEFT, readyTab, RIGHT, 8, 0)
    bestTab:SetText("BEST BUFFS")
    bestTab:SetHandler("OnClicked", function() self:SetView("BEST") end)
    bestTab:SetHandler("OnMouseEnter", function(control)
        if InformationTooltip and type(InitializeTooltip) == "function" then
            InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -8, TOP)
            InformationTooltip:AddLine("Best Combat Recipes", "ZoFontWinH4")
            InformationTooltip:AddLine("Potion mode: strongest multi-buff potions. Poison mode: strongest damage/debuff poisons. READY recipes are listed first.", "ZoFontGame")
        end
    end)
    bestTab:SetHandler("OnMouseExit", function() if InformationTooltip and type(ClearTooltip) == "function" then ClearTooltip(InformationTooltip) end end)
    self.bestTab = bestTab

    local exactTab = makeButton(w, 180, 38)
    exactTab:SetAnchor(LEFT, bestTab, RIGHT, 8, 0)
    exactTab:SetText("CHOOSE EFFECTS")
    exactTab:SetHandler("OnClicked", function() self:SetView("EXACT") end)
    self.exactTab = exactTab

    -- Large status card: tells the user what they can do right now.
    local statusCard = wm:CreateControl(nil, w, CT_BACKDROP)
    statusCard:SetDimensions(PANEL_W - 44, 58)
    statusCard:SetAnchor(TOPLEFT, w, TOPLEFT, 22, 158)
    statusCard:SetCenterColor(0.025, 0.040, 0.055, 0.96)
    statusCard:SetEdgeColor(0.14, 0.34, 0.44, 0.9)
    statusCard:SetEdgeTexture(nil, 1, 1, 1)
    self.statusCard = statusCard

    local statusTitle = wm:CreateControl(nil, statusCard, CT_LABEL)
    statusTitle:SetFont("ZoFontGameBold")
    statusTitle:SetAnchor(TOPLEFT, statusCard, TOPLEFT, 12, 7)
    statusTitle:SetDimensions(PANEL_W - 260, 22)
    statusTitle:SetColor(0.88, 0.94, 1, 1)
    self.statusTitle = statusTitle

    local status = wm:CreateControl(nil, statusCard, CT_LABEL)
    status:SetFont("ZoFontGameSmall")
    status:SetAnchor(TOPLEFT, statusTitle, BOTTOMLEFT, 0, 0)
    status:SetDimensions(PANEL_W - 270, 22)
    status:SetColor(0.66, 0.76, 0.84, 1)
    self.statusLabel = status

    local rescan = makeButton(statusCard, 118, 34, "ZoFontGame")
    rescan:SetAnchor(RIGHT, statusCard, RIGHT, -12, 0)
    rescan:SetText("REFRESH")
    rescan:SetHandler("OnClicked", function() self:RefreshWindow(true) self:RefreshStatus() end)

    local autoCraft = makeButton(statusCard, 150, 34, "ZoFontGameBold")
    autoCraft:SetAnchor(RIGHT, rescan, LEFT, -8, 0)
    autoCraft:SetHandler("OnClicked", function()
        EPC.saved.alchemyPotionMakerAutoCraft = EPC.saved.alchemyPotionMakerAutoCraft ~= true
        self:RefreshWindow(false)
    end)
    autoCraft:SetHandler("OnMouseEnter", function(control)
        if InformationTooltip and type(InitializeTooltip) == "function" then
            InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -8, TOP)
            InformationTooltip:AddLine("Auto Craft", "ZoFontWinH4")
            InformationTooltip:AddLine("OFF: clicking a ready recipe only loads the ingredients. ON: it loads and crafts automatically.", "ZoFontGame")
        end
    end)
    autoCraft:SetHandler("OnMouseExit", function() if InformationTooltip and type(ClearTooltip) == "function" then ClearTooltip(InformationTooltip) end end)
    self.autoCraftButton = autoCraft

    -- Shared crafting-source hunt bar. This is the same control surface used
    -- at Provisioning, Enchanting, Jewelry, Woodworking, Blacksmithing, and Clothing stations.
    if EPC.CraftingMaterialHunt and EPC.CraftingMaterialHunt.AttachPotionMaker029765
        and (not EPC.saved or EPC.saved.craftingMaterialHuntBarEnabled029765 ~= false) then
        EPC.CraftingMaterialHunt:AttachPotionMaker029765(w)
    end

    -- Exact-effect selector card. Hidden in the easy 'What can I make?' view.
    local exactBar = wm:CreateControl(nil, w, CT_BACKDROP)
    exactBar:SetDimensions(PANEL_W - 44, 74)
    exactBar:SetAnchor(TOPLEFT, w, TOPLEFT, 22, 314)
    exactBar:SetCenterColor(0.020, 0.030, 0.045, 0.96)
    exactBar:SetEdgeColor(0.22, 0.34, 0.44, 0.9)
    exactBar:SetEdgeTexture(nil, 1, 1, 1)
    self.exactBar = exactBar

    local exactHelp = wm:CreateControl(nil, exactBar, CT_LABEL)
    exactHelp:SetFont("ZoFontGameSmall")
    exactHelp:SetAnchor(TOPLEFT, exactBar, TOPLEFT, 12, 6)
    exactHelp:SetDimensions(PANEL_W - 70, 20)
    exactHelp:SetColor(0.68, 0.78, 0.88, 1)
    exactHelp:SetText("Pick up to 3 effects. We will show the reagent combinations that create them.")

    local effectButtons = {}
    for i = 1, 3 do
        local btn = makeButton(exactBar, 235, 34, "ZoFontGame")
        if i == 1 then btn:SetAnchor(BOTTOMLEFT, exactBar, BOTTOMLEFT, 12, -7) else btn:SetAnchor(LEFT, effectButtons[i-1], RIGHT, 8, 0) end
        btn:SetHandler("OnClicked", function(control) self:ShowEffectMenu(control, i) end)
        effectButtons[i] = btn
    end
    self.effectButtons = effectButtons

    local clearEffects = makeButton(exactBar, 95, 34, "ZoFontGame")
    clearEffects:SetAnchor(LEFT, effectButtons[3], RIGHT, 8, 0)
    clearEffects:SetText("CLEAR")
    clearEffects:SetHandler("OnClicked", function()
        EPC.saved.alchemyPotionMakerEffect1 = 0
        EPC.saved.alchemyPotionMakerEffect2 = 0
        EPC.saved.alchemyPotionMakerEffect3 = 0
        self.currentPage = 1
        self:RefreshWindow(false)
    end)

    local recipesTitle = wm:CreateControl(nil, w, CT_LABEL)
    recipesTitle:SetFont("ZoFontWinH3")
    recipesTitle:SetAnchor(TOPLEFT, w, TOPLEFT, 22, 402)
    recipesTitle:SetDimensions(300, 30)
    recipesTitle:SetColor(0.94, 0.84, 0.38, 1)
    recipesTitle:SetText("RECIPES")
    self.recipesTitle = recipesTitle

    local recipesHint = wm:CreateControl(nil, w, CT_LABEL)
    recipesHint:SetFont("ZoFontGameSmall")
    recipesHint:SetAnchor(LEFT, recipesTitle, RIGHT, 8, 1)
    recipesHint:SetDimensions(520, 24)
    recipesHint:SetColor(0.62, 0.72, 0.82, 1)
    recipesHint:SetText("Green = ready. Missing recipes show the needed zones/locations. MAP + 3D marks the hunt pins; TRAVEL cycles through each missing ingredient using its closest discovered wayshrine.")
    self.recipesHint = recipesHint

    self.rows = {}
    local firstY = 436
    for i = 1, ROW_COUNT do
        local row = wm:CreateControl(nil, w, CT_BUTTON)
        row:SetDimensions(PANEL_W - 44, 46)
        row:SetAnchor(TOPLEFT, w, TOPLEFT, 22, firstY + (i - 1) * 48)
        row:SetMouseEnabled(true)

        local rowBg = wm:CreateControl(nil, row, CT_BACKDROP)
        rowBg:SetAnchorFill(row)
        rowBg:SetCenterColor(i % 2 == 0 and 0.025 or 0.018, i % 2 == 0 and 0.038 or 0.030, i % 2 == 0 and 0.052 or 0.044, 0.96)
        rowBg:SetEdgeColor(0.10, 0.18, 0.24, 0.8)
        rowBg:SetEdgeTexture(nil, 1, 1, 1)

        local state = wm:CreateControl(nil, row, CT_LABEL)
        state:SetFont("ZoFontGameBold")
        state:SetAnchor(LEFT, row, LEFT, 10, 0)
        state:SetDimensions(105, 40)
        state:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        state:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        row.stateLabel = state

        local main = wm:CreateControl(nil, row, CT_LABEL)
        main:SetFont("ZoFontGameBold")
        main:SetAnchor(TOPLEFT, row, TOPLEFT, 126, 5)
        main:SetDimensions(390, 20)
        row.mainLabel = main

        local sub = wm:CreateControl(nil, row, CT_LABEL)
        sub:SetFont("ZoFontGameSmall")
        sub:SetAnchor(TOPLEFT, main, BOTTOMLEFT, 0, -2)
        sub:SetDimensions(500, 18)
        sub:SetColor(0.64, 0.74, 0.84, 1)
        row.subLabel = sub

        local travelButton = makeButton(row, 104, 30, "ZoFontGameBold")
        travelButton:SetAnchor(RIGHT, row, RIGHT, -10, 0)
        travelButton:SetText("TRAVEL")
        travelButton:SetHidden(true)
        travelButton:SetHandler("OnClicked", function(control)
            if control.result then self:TravelToMissing(control.result) end
        end)
        row.travelButton = travelButton

        local action = wm:CreateControl(nil, row, CT_LABEL)
        action:SetFont("ZoFontGameBold")
        action:SetAnchor(RIGHT, travelButton, LEFT, -10, 0)
        action:SetDimensions(126, 38)
        action:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        action:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        row.actionLabel = action

        row.bg = rowBg
        row:SetHandler("OnMouseEnter", function(control)
            if control.bg then control.bg:SetCenterColor(0.05, 0.075, 0.095, 0.98) end
            if control.result and InformationTooltip and type(InitializeTooltip)=="function" then
                InitializeTooltip(InformationTooltip, control, LEFT, -8, 0, RIGHT)
                InformationTooltip:AddLine(control.result.ready and "READY" or "MISSING MATERIALS", "ZoFontWinH4")
                if control.result.recommendationTitle then
                    InformationTooltip:AddLine("Recommended: " .. tostring(control.result.recommendationTitle), "ZoFontGameBold")
                    if control.result.recommendationWhy then InformationTooltip:AddLine(tostring(control.result.recommendationWhy), "ZoFontGameSmall") end
                end
                InformationTooltip:AddLine("Effects: " .. tostring(control.result.effectsText), "ZoFontGame")
                InformationTooltip:AddLine("Reagents: " .. tostring(control.result.reagentsText), "ZoFontGame")
                local sol = control.result.solvent and control.result.solvent.name or self:GetExpectedSolventName(control.result.mode)
                InformationTooltip:AddLine("Solvent: " .. tostring(sol), "ZoFontGame")
                if control.result.ready then
                    InformationTooltip:AddLine("You can make at least " .. tostring(control.result.maxCraftable) .. ". Click to " .. (EPC.saved.alchemyPotionMakerAutoCraft == true and "craft it." or "load the ingredients."), "ZoFontGameSmall")
                else
                    InformationTooltip:AddLine("Still needed: " .. table.concat(control.result.missing or {}, ", "), "ZoFontGameSmall")
                    local details = self:GetMissingRouteDetails(control.result)
                    if type(details) == "table" and #details > 0 then
                        for _, detail in ipairs(details) do
                            local materialName = tostring(detail.material and detail.material.name or "material")
                            local route = type(detail.route) == "table" and detail.route or nil
                            if route then
                                InformationTooltip:AddLine(string.format("%s: %s • %s • %s", materialName, tostring(route.zoneName or "Unknown"), tostring(route.locationText or "known resource area"), tostring(route.wayshrineName or "None discovered")), "ZoFontGameSmall")
                            else
                                InformationTooltip:AddLine(materialName .. ": no fixed route", "ZoFontGameSmall")
                            end
                        end
                    end
                    InformationTooltip:AddLine("Click the row for Map + 3D pins. TRAVEL cycles through each missing ingredient.", "ZoFontGameSmall")
                end
            end
        end)
        row:SetHandler("OnMouseExit", function(control)
            if control.bg then control.bg:SetCenterColor(0.020, 0.032, 0.046, 0.96) end
            if InformationTooltip and type(ClearTooltip)=="function" then ClearTooltip(InformationTooltip) end
        end)
        row:SetHandler("OnClicked", function(control)
            if not control.result then return end
            if control.result.ready then self:ActivateResult(control.result) else self:ReportMissing(control.result) end
        end)
        self.rows[i] = row
    end

    local prev = makeButton(w, 90, 34, "ZoFontGameBold")
    prev:SetAnchor(BOTTOMLEFT, w, BOTTOMLEFT, 22, -16)
    prev:SetText("< PREV")
    prev:SetHandler("OnClicked", function() self.currentPage = math.max(1, num(self.currentPage,1)-1) self:RefreshRows() end)
    self.prevButton = prev

    local page = wm:CreateControl(nil, w, CT_LABEL)
    page:SetDimensions(250, 34)
    page:SetAnchor(LEFT, prev, RIGHT, 10, 0)
    page:SetFont("ZoFontGame")
    page:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    page:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.pageLabel = page

    local nextBtn = makeButton(w, 90, 34, "ZoFontGameBold")
    nextBtn:SetAnchor(LEFT, page, RIGHT, 10, 0)
    nextBtn:SetText("NEXT >")
    nextBtn:SetHandler("OnClicked", function()
        local pages = math.max(1, math.ceil(#(self.currentResults or {}) / self:GetRowsPerPage()))
        self.currentPage = math.min(pages, num(self.currentPage,1)+1)
        self:RefreshRows()
    end)
    self.nextButton = nextBtn

    local help = wm:CreateControl(nil, w, CT_LABEL)
    help:SetDimensions(390, 36)
    help:SetAnchor(BOTTOMRIGHT, w, BOTTOMRIGHT, -22, -14)
    help:SetFont("ZoFontGameSmall")
    help:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    help:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    help:SetColor(0.62, 0.72, 0.80, 1)
    help:SetText("Tip: BEST starts with clear recommendations for new players.\nHover a pick to see why, ingredients, solvent and missing-material routes.")

    w:SetHandler("OnMoveStop", function(control) if control.StopMoving then control:StopMoving() end self:SavePanelPosition() end)
    self:RestorePanelPosition()
end

function A:GetRowsPerPage()
    -- BEST rows are intentionally taller so recommendation text remains readable.
    -- Keep READY/EXACT at the denser seven-row layout.
    return self.currentView == "BEST" and 6 or ROW_COUNT
end

function A:RefreshRows()
    if not self.rows then return end
    local results = self.currentResults or {}
    local rowsPerPage = self:GetRowsPerPage()
    local pages = math.max(1, math.ceil(#results / rowsPerPage))
    self.currentPage = math.max(1, math.min(pages, num(self.currentPage, 1)))
    local startIndex = (self.currentPage - 1) * rowsPerPage + 1
    for i, row in ipairs(self.rows) do
        local result = (i <= rowsPerPage) and results[startIndex + i - 1] or nil
        row.result = result
        row:SetHidden(result == nil)
        if result then
            local ready = result.ready == true
            local effectText = result.effectsText ~= "" and result.effectsText or "Unknown effect"
            local solvent = result.solvent and result.solvent.name or self:GetExpectedSolventName(result.mode)
            if self.currentView == "BEST" then
                -- BEST is guidance, not a leaderboard. Keep the status simple.
                row.stateLabel:SetText(ready and "READY" or "MISSING")
            else
                row.stateLabel:SetText(ready and ("READY\nx" .. tostring(result.maxCraftable or 0)) or "MISSING")
            end
            row.stateLabel:SetColor(ready and 0.36 or 1.00, ready and 0.92 or 0.45, ready and 0.68 or 0.34, 1)
            if self.currentView == "BEST" and result.recommendationTitle then
                row.mainLabel:SetText(tostring(result.recommendationTitle) .. " — " .. effectText)
            else
                row.mainLabel:SetText(effectText)
            end
            row.mainLabel:SetColor(0.92, 0.94, 0.98, 1)
            if ready then
                if self.currentView == "BEST" and result.recommendationWhy then
                    row.subLabel:SetText(tostring(result.recommendationWhy))
                else
                    row.subLabel:SetText(string.format("%s  •  %s", tostring(result.reagentsText or ""), tostring(solvent or "")))
                end
                row.actionLabel:SetText(EPC.saved.alchemyPotionMakerAutoCraft == true and "CRAFT" or "LOAD")
                row.actionLabel:SetColor(0.36, 0.92, 0.68, 1)
                if row.travelButton then row.travelButton:SetHidden(true); row.travelButton.result = nil end
                if row.bg then row.bg:SetEdgeColor(0.12, 0.58, 0.40, 0.95) end
            else
                local route = self:GetMissingRouteInfo(result)
                if self.currentView == "BEST" and result.recommendationWhy then
                    row.subLabel:SetText(tostring(result.recommendationWhy))
                else
                    row.subLabel:SetText(self:GetMissingRouteSummaryText(result))
                end
                row.actionLabel:SetText("MAP + 3D")
                row.actionLabel:SetColor(1.00, 0.55, 0.38, 1)
                if row.travelButton then
                    row.travelButton.result = result
                    row.travelButton:SetHidden(false)
                    local canTravel = route and route.wayshrineNodeIndex ~= nil
                    row.travelButton:SetEnabled(canTravel == true)
                    local routeCount = #(self:GetMissingRouteDetails(result) or {})
                    if canTravel then
                        row.travelButton:SetText(routeCount > 1 and ("TRAVEL " .. tostring(routeCount)) or "TRAVEL")
                    else
                        row.travelButton:SetText("NO SHRINE")
                    end
                end
                if row.bg then row.bg:SetEdgeColor(0.58, 0.25, 0.20, 0.95) end
            end
        end
    end
    if self.pageLabel then self.pageLabel:SetText(string.format("Page %d of %d  •  %d recipe%s", self.currentPage, pages, #results, #results == 1 and "" or "s")) end
    if self.prevButton then self.prevButton:SetEnabled(self.currentPage > 1) end
    if self.nextButton then self.nextButton:SetEnabled(self.currentPage < pages) end
end

function A:RefreshWindow(forceScan)
    self:EnsureSaved()
    self:CreateWindow()
    if not self.window then return end
    if forceScan then self.reagentList, self.reagentsByName, self.solvents = nil, nil, nil end

    local mode = EPC.saved.alchemyPotionMakerMode == "POISON" and "POISON" or "POTION"
    if self.currentView ~= "EXACT" and self.currentView ~= "BEST" then self.currentView = "READY" end

    local function selectButton(button, selected)
        if not button or not button.easBg then return end
        if selected then
            button.easBg:SetCenterColor(0.10, 0.19, 0.23, 0.98)
            button.easBg:SetEdgeColor(0.38, 0.84, 0.92, 1)
        else
            button.easBg:SetCenterColor(0.035, 0.050, 0.070, 0.96)
            button.easBg:SetEdgeColor(0.22, 0.34, 0.44, 0.95)
        end
    end

    selectButton(self.potionModeButton, mode == "POTION")
    selectButton(self.poisonModeButton, mode == "POISON")
    selectButton(self.readyTab, self.currentView == "READY")
    selectButton(self.bestTab, self.currentView == "BEST")
    selectButton(self.exactTab, self.currentView == "EXACT")
    if self.bestTab then
        setButtonText(self.bestTab, mode == "POISON" and "BEST POISONS" or "BEST BUFFS")
    end

    if self.statusTitle then
        if self:IsAtAlchemyStation() then
            self.statusTitle:SetText("ALCHEMY STATION READY — choose a recipe below")
            self.statusTitle:SetColor(0.36, 0.92, 0.68, 1)
            if self.statusCard then self.statusCard:SetEdgeColor(0.12, 0.58, 0.40, 0.95) end
        else
            self.statusTitle:SetText("PLANNER MODE — open an Alchemy Station to load or craft")
            self.statusTitle:SetColor(0.95, 0.78, 0.38, 1)
            if self.statusCard then self.statusCard:SetEdgeColor(0.52, 0.40, 0.16, 0.95) end
        end
    end
    if self.statusLabel then self.statusLabel:SetText(self:GetStatusText()) end
    if self.autoCraftButton then
        setButtonText(self.autoCraftButton, EPC.saved.alchemyPotionMakerAutoCraft == true and "AUTO CRAFT: ON" or "AUTO CRAFT: OFF")
        if self.autoCraftButton.easBg then
            if EPC.saved.alchemyPotionMakerAutoCraft == true then
                self.autoCraftButton.easBg:SetEdgeColor(0.36, 0.86, 0.62, 1)
            else
                self.autoCraftButton.easBg:SetEdgeColor(0.34, 0.38, 0.44, 1)
            end
        end
    end

    if self.recipesTitle then
        if self.currentView == "BEST" then
            self.recipesTitle:SetText(mode == "POISON" and "TOP POISON RECOMMENDATIONS" or "TOP POTION RECOMMENDATIONS")
        else
            self.recipesTitle:SetText("RECIPES")
        end
    end
    if self.recipesHint then
        if self.currentView == "BEST" then
            self.recipesHint:SetText(mode == "POISON"
                and "New-player guide: best overall, damage, PvP pressure, resource pressure, control, beginner and endgame picks."
                or "New-player guide: best overall, Magicka DPS, Stamina DPS, tank, healer, solo, PvP, beginner and endgame picks.")
        else
            self.recipesHint:SetText("Green = ready. Missing recipes show the needed zones/locations. MAP + 3D marks the hunt pins; TRAVEL cycles through each missing ingredient using its closest discovered wayshrine.")
        end
    end

    if self.exactBar then self.exactBar:SetHidden(self.currentView ~= "EXACT") end
    if self.recipesTitle then
        self.recipesTitle:ClearAnchors()
        if self.currentView == "EXACT" and self.exactBar then
            self.recipesTitle:SetAnchor(TOPLEFT, self.exactBar, BOTTOMLEFT, 0, 12)
        elseif self.statusCard then
            self.recipesTitle:SetAnchor(TOPLEFT, self.statusCard, BOTTOMLEFT, 0, 18)
        end
    end
    if self.recipesHint and self.recipesTitle then
        self.recipesHint:ClearAnchors()
        self.recipesHint:SetAnchor(LEFT, self.recipesTitle, RIGHT, 8, 1)
    end

    if self.effectButtons then
        self:EnsurePlannerCatalog()
        for i, btn in ipairs(self.effectButtons) do
            local effectId = tonumber(EPC.saved["alchemyPotionMakerEffect" .. i]) or 0
            local label
            if effectId > 0 then label = self:GetEffectName(effectId)
            elseif i == 1 then label = "Choose primary effect"
            else label = "Optional effect " .. tostring(i) end
            setButtonText(btn, label)
        end
    end

    if self.currentView == "EXACT" then
        self.currentResults = self:BuildExactResults()
    elseif self.currentView == "BEST" then
        self.currentResults = self:BuildBestResults()
    else
        if not forceScan and self.cachedReadyResults then self.currentResults = self.cachedReadyResults else self.currentResults = self:BuildCanMakeResults() end
    end

    -- BEST recommendations use taller rows and real wrapping so titles, effects and
    -- explanations remain readable. READY/EXACT stay compact.
    local isBest = self.currentView == "BEST"
    local rowStartY = self.currentView == "EXACT" and 390 or 300
    local rowHeight = isBest and 68 or 46
    local rowStep = isBest and 70 or 48
    for i, row in ipairs(self.rows or {}) do
        row:ClearAnchors()
        row:SetDimensions(PANEL_W - 44, rowHeight)
        row:SetAnchor(TOPLEFT, self.window, TOPLEFT, 22, rowStartY + (i - 1) * rowStep)
        if row.stateLabel then
            row.stateLabel:SetDimensions(isBest and 94 or 105, isBest and 62 or 40)
        end
        if row.mainLabel then
            row.mainLabel:ClearAnchors()
            row.mainLabel:SetAnchor(TOPLEFT, row, TOPLEFT, isBest and 108 or 126, isBest and 6 or 5)
            row.mainLabel:SetDimensions(isBest and 470 or 390, isBest and 32 or 20)
            if row.mainLabel.SetMaxLineCount then row.mainLabel:SetMaxLineCount(isBest and 2 or 1) end
            if row.mainLabel.SetLineSpacing then row.mainLabel:SetLineSpacing(isBest and 1 or 0) end
        end
        if row.subLabel and row.mainLabel then
            row.subLabel:ClearAnchors()
            row.subLabel:SetAnchor(TOPLEFT, row.mainLabel, BOTTOMLEFT, 0, isBest and 0 or -2)
            row.subLabel:SetDimensions(isBest and 470 or 500, isBest and 26 or 18)
            if row.subLabel.SetMaxLineCount then row.subLabel:SetMaxLineCount(isBest and 2 or 1) end
            if row.subLabel.SetLineSpacing then row.subLabel:SetLineSpacing(isBest and 1 or 0) end
        end
    end
    self:RefreshRows()
end

function A:OpenWindow()
    self:EnsureSaved()
    if EPC.saved.alchemyPotionMakerEnabled == false then
        notify("Crafting Assistant is disabled in Suite Settings.", false)
        return
    end

    -- v0.29.237: the Potion Maker can now be opened from the main ESO menu at
    -- any time, just like the standalone PotionMaker addon. Recipe planning and
    -- inventory checks work outside a station; loading/crafting a result still
    -- correctly requires an active Alchemy Station through PrepareResult().
    self:CreateWindow()
    self.currentView = self.currentView or "BEST"
    self.currentPage = 1
    self:RefreshWindow(true)
    self.window:SetHidden(false)
    if self.window.BringWindowToTop then self.window:BringWindowToTop() end
end

function A:ToggleWindow()
    self:CreateWindow()
    if not self.window then return end
    if self.window:IsHidden() then
        self:OpenWindow()
    else
        self:CloseWindow(true)
    end
end

function A:ScheduleRefresh(delay)
    if not EVENT_MANAGER then return end
    EPC.Runtime:UnregisterUpdate("AlchemyPotionMaker", "Refresh")
    EPC.Runtime:RegisterUpdate("AlchemyPotionMaker", "Refresh", math.max(80, num(delay, 250)), function()
        EPC.Runtime:UnregisterUpdate("AlchemyPotionMaker", "Refresh")
        self.reagentList, self.reagentsByName, self.solvents = nil, nil, nil
        self.resultCache, self.cachedReadyResults = nil, nil
        self:RefreshVisibility()
        if self.window and not self.window:IsHidden() and self:IsAtAlchemyStation() then self:RefreshWindow(true) end
    end)
end

function A:RegisterEvents()
    if self.eventsRegistered or not EVENT_MANAGER then return end
    self.eventsRegistered = true
    if rawget(_G, "EVENT_CRAFTING_STATION_INTERACT") then
        EPC.Runtime:RegisterEvent("AlchemyPotionMaker", "StationOpen", EVENT_CRAFTING_STATION_INTERACT, function(_, craftingType)
            if craftingType == rawget(_G, "CRAFTING_TYPE_ALCHEMY") then
                if type(zo_callLater)=="function" then zo_callLater(function() self:RefreshVisibility() end, 120) else self:RefreshVisibility() end
            end
        end)
    end
    if rawget(_G, "EVENT_END_CRAFTING_STATION_INTERACT") then
        EPC.Runtime:RegisterEvent("AlchemyPotionMaker", "StationClose", EVENT_END_CRAFTING_STATION_INTERACT, function()
            self:CloseWindow(false)
            if type(zo_callLater)=="function" then zo_callLater(function() self:RefreshVisibility() end, 80) else self:RefreshVisibility() end
        end)
    end
    if rawget(_G, "EVENT_INVENTORY_SINGLE_SLOT_UPDATE") then
        EPC.Runtime:RegisterEvent("AlchemyPotionMaker", "Inventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId)
            local backpack = rawget(_G, "BAG_BACKPACK")
            local bank = rawget(_G, "BAG_BANK")
            local subBank = rawget(_G, "BAG_SUBSCRIBER_BANK")
            local virtual = rawget(_G, "BAG_VIRTUAL")
            if bagId ~= backpack and bagId ~= bank and bagId ~= subBank and bagId ~= virtual then return end
            -- Only alchemy source bags can invalidate Potion Maker ownership.
            -- Debounce the refresh so looting/crafting stack changes collapse into
            -- one rebuild rather than repeatedly rescanning and recomputing recipes.
            if self:IsAtAlchemyStation() or (self.window and not self.window:IsHidden()) then
                self:ScheduleRefresh(450)
            else
                self.reagentList, self.reagentsByName, self.solvents = nil, nil, nil
                self.resultCache, self.cachedReadyResults = nil, nil
            end
        end)
    end
    if rawget(_G, "EVENT_CRAFT_COMPLETED") then
        EPC.Runtime:RegisterEvent("AlchemyPotionMaker", "CraftComplete", EVENT_CRAFT_COMPLETED, function(_, craftingType)
            if craftingType == rawget(_G, "CRAFTING_TYPE_ALCHEMY") then self:ScheduleRefresh(250) end
        end)
    end
end

function A:SetHotkeyActionLayer(active)
    local layerName = "ESOAdventurerSuitePotionMakerLayer"
    if active then
        if self.hotkeyActionLayerPushed or type(PushActionLayerByName) ~= "function" then return end
        local ok = pcall(PushActionLayerByName, layerName)
        self.hotkeyActionLayerPushed = ok == true
    else
        if not self.hotkeyActionLayerPushed then return end
        if type(RemoveActionLayerByName) == "function" then pcall(RemoveActionLayerByName, layerName) end
        self.hotkeyActionLayerPushed = false
    end
end

function A:SetHotkeyUIMode(active)
    active = active == true
    if type(SetGameCameraUIMode) == "function" then pcall(SetGameCameraUIMode, active) end
    if SCENE_MANAGER and type(SCENE_MANAGER.SetInUIMode) == "function" then
        pcall(SCENE_MANAGER.SetInUIMode, SCENE_MANAGER, active)
    end
end

function A:ToggleMainMenuPage()
    self:EnsureSaved()

    -- v0.29.268: a key press that opens this scene can still be propagating when
    -- the scene pushes its inherited close-key action layer.  Without a short
    -- debounce ESO can deliver the same physical press twice and immediately
    -- close the page, making it look like the hotkey needs two presses.
    local now = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds()
        or (type(GetGameTimeMilliseconds) == "function" and GetGameTimeMilliseconds()) or 0
    if now > 0 and self.lastHotkeyToggleMs and (now - self.lastHotkeyToggleMs) < 220 then
        return true
    end
    self.lastHotkeyToggleMs = now

    if EPC.saved.alchemyPotionMakerEnabled == false then
        notify("Crafting Assistant is disabled in Suite Settings.", false)
        return false
    end
    if not self:RegisterMainMenuIcon() or not SCENE_MANAGER then
        notify("Crafting Assistant top-menu page requires LibMainMenu-2.0.", false)
        return false
    end
    local sceneName = "ESOAdventurerSuitePotionMaker"
    local showing = type(SCENE_MANAGER.IsShowing) == "function" and safe(SCENE_MANAGER.IsShowing, false, SCENE_MANAGER, sceneName) == true
    if showing then
        self:CloseWindow(true)
    elseif type(SCENE_MANAGER.Show) == "function" then
        pcall(SCENE_MANAGER.Show, SCENE_MANAGER, sceneName)
    end
    return true
end

function ESOAdventurerSuite_TogglePotionMaker()
    if EPC and EPC.AlchemyPotionMaker and type(EPC.AlchemyPotionMaker.ToggleMainMenuPage) == "function" then
        return EPC.AlchemyPotionMaker:ToggleMainMenuPage()
    end
    return false
end

-- v0.29.270: the gameplay hotkey uses a direct launcher instead of asking
-- LibMainMenu to enter/select the scene during the same key-down. The exact
-- same Potion Maker window is used; only the launch path is separate. This
-- removes the first-press scene-selection race completely.
function A:OpenFromHotkey()
    self:EnsureSaved()
    if EPC.saved.alchemyPotionMakerEnabled == false then
        notify("Crafting Assistant is disabled in Suite Settings.", false)
        return true
    end

    -- If Turbo Learner owns the current Suite tool page/window, close it first
    -- so switching tools with their two hotkeys still behaves like changing a
    -- single menu page instead of stacking both windows.
    local learner = EPC and EPC.RecipeStyleLearner
    if learner and type(learner.CloseWindow) == "function" then
        local learnerShowing = false
        if type(learner.IsLearnerSceneShowing) == "function" then
            learnerShowing = safe(learner.IsLearnerSceneShowing, false, learner) == true
        end
        if learnerShowing or (learner.window and not learner.window:IsHidden()) then
            pcall(learner.CloseWindow, learner)
        end
    end

    self.hotkeyOpenPending = false
    self:SetHotkeyActionLayer(false)

    local alreadyInUIMode = type(IsGameCameraUIModeActive) == "function"
        and safe(IsGameCameraUIModeActive, false) == true
    self.hotkeyOwnsUIMode = not alreadyInUIMode
    self:SetHotkeyUIMode(true)
    self.directHotkeyOpen = true

    -- Open immediately in this key-down so the first press always produces the
    -- visible UI. Only arming the inherited close binding is delayed until the
    -- opening key event has fully finished propagating.
    self:OpenWindow()
    if not self.window or self.window:IsHidden() then
        self.directHotkeyOpen = false
        if self.hotkeyOwnsUIMode == true then self:SetHotkeyUIMode(false) end
        self.hotkeyOwnsUIMode = false
        return true
    end
    if self.window.BringWindowToTop then self.window:BringWindowToTop() end

    local function armCloseLayer()
        if A.directHotkeyOpen == true and A.window and not A.window:IsHidden() then
            A:SetHotkeyActionLayer(true)
        end
    end
    if type(zo_callLater) == "function" then zo_callLater(armCloseLayer, 120) else armCloseLayer() end
    return true
end

function A:CloseFromHotkey()
    self.hotkeyOpenPending = false
    self:CloseWindow(true)
    return true
end

function ESOAdventurerSuite_OpenPotionMakerHotkey()
    if EPC and EPC.AlchemyPotionMaker and type(EPC.AlchemyPotionMaker.OpenFromHotkey) == "function" then
        return EPC.AlchemyPotionMaker:OpenFromHotkey()
    end
    return true
end

function ESOAdventurerSuite_ClosePotionMakerHotkey()
    if EPC and EPC.AlchemyPotionMaker and type(EPC.AlchemyPotionMaker.CloseFromHotkey) == "function" then
        return EPC.AlchemyPotionMaker:CloseFromHotkey()
    end
    return true
end

function A:RegisterMainMenuIcon()
    if self.mainMenuRegistered then return true end

    local lmm = rawget(_G, "LibMainMenu2")
    if type(lmm) ~= "table" or type(lmm.AddMenuItem) ~= "function" then
        return false
    end
    if not SCENE_MANAGER or type(ZO_Scene) ~= "table" or type(ZO_Scene.New) ~= "function" then
        return false
    end

    if type(lmm.Init) == "function" then pcall(lmm.Init, lmm) end

    local descriptor = "ESOAdventurerSuitePotionMaker"
    local sceneName = "ESOAdventurerSuitePotionMaker"

    if type(ZO_CreateStringId) == "function" and rawget(_G, "SI_EAS_ALCHEMY_POTION_MAKER_MAIN_MENU") == nil then
        pcall(ZO_CreateStringId, "SI_EAS_ALCHEMY_POTION_MAKER_MAIN_MENU", "Crafting Assistant")
    end
    local categoryName = rawget(_G, "SI_EAS_ALCHEMY_POTION_MAKER_MAIN_MENU") or rawget(_G, "SI_BINDING_NAME_POTIONMAKER")
    if categoryName == nil and type(ZO_CreateStringId) == "function" then
        pcall(ZO_CreateStringId, "SI_EAS_ALCHEMY_POTION_MAKER_MAIN_MENU_FALLBACK", "Crafting Assistant")
        categoryName = rawget(_G, "SI_EAS_ALCHEMY_POTION_MAKER_MAIN_MENU_FALLBACK")
    end

    local scene = self.mainMenuScene
    if not scene then
        scene = ZO_Scene:New(sceneName, SCENE_MANAGER)
        self.mainMenuScene = scene

        -- Match other top-menu pages: mouse-driven UI, normal right-panel shade,
        -- then show the existing Suite Potion Maker window on top.
        if rawget(_G, "FRAGMENT_GROUP") and FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW and scene.AddFragmentGroup then
            pcall(scene.AddFragmentGroup, scene, FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
        end
        if rawget(_G, "RIGHT_PANEL_BG_FRAGMENT") and scene.AddFragment then
            pcall(scene.AddFragment, scene, RIGHT_PANEL_BG_FRAGMENT)
        end

        scene:RegisterCallback("StateChange", function(_, state)
            if state == SCENE_SHOWING or state == SCENE_SHOWN then
                A:OpenWindow()
                -- Do not push the inherited hotkey layer inside the same key-down
                -- stack that opened the scene.  Waiting one tick prevents that
                -- original press from being interpreted as the close action too.
                if type(zo_callLater) == "function" then
                    zo_callLater(function()
                        if SCENE_MANAGER and type(SCENE_MANAGER.IsShowing) == "function"
                            and SCENE_MANAGER:IsShowing(sceneName) then
                            A:SetHotkeyActionLayer(true)
                        end
                    end, 90)
                else
                    A:SetHotkeyActionLayer(true)
                end
            elseif state == SCENE_HIDING or state == SCENE_HIDDEN then
                A:SetHotkeyActionLayer(false)
                if A.window then A.window:SetHidden(true) end
                if A.effectPopup then A.effectPopup:SetHidden(true) end
            end
        end)
    end

    local categoryLayoutInfo = {
        binding = "EAS_ALCHEMY_POTION_MAKER",
        categoryName = categoryName,
        callback = function()
            if SCENE_MANAGER:IsShowing(sceneName) then
                SCENE_MANAGER:ShowBaseScene()
            else
                SCENE_MANAGER:Show(sceneName)
            end
        end,
        visible = function()
            return not EPC.saved or EPC.saved.alchemyPotionMakerEnabled ~= false
        end,
        normal = "esoui/art/inventory/inventory_tabicon_consumables_up.dds",
        pressed = "esoui/art/inventory/inventory_tabicon_consumables_down.dds",
        highlight = "esoui/art/inventory/inventory_tabicon_consumables_over.dds",
        disabled = "esoui/art/inventory/inventory_tabicon_consumables_disabled.dds",
    }

    local ok = pcall(lmm.AddMenuItem, lmm, descriptor, sceneName, categoryLayoutInfo, nil)
    if ok then
        self.mainMenuRegistered = true
        return true
    end
    return false
end

function A:Initialize()
    self:EnsureSaved()
    self:CreateIcon()
    self:RegisterEvents()
    self.currentView = "READY"
    self.currentPage = 1
    self:RefreshVisibility()

    -- Register after startup so LibMainMenu2 and ESO's keyboard main menu have
    -- finished initializing. Retry a few times if addon/library load order is late.
    local attempts = 0
    local function tryMainMenu()
        attempts = attempts + 1
        if A:RegisterMainMenuIcon() or attempts >= 8 then return end
        if type(zo_callLater) == "function" then zo_callLater(tryMainMenu, 500) end
    end
    if type(zo_callLater) == "function" then zo_callLater(tryMainMenu, 250) else tryMainMenu() end
end
