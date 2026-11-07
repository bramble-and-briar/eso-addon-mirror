InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- DAILY WRIT: the backpack pieces a crafting writ in your journal is asking for, gathered in one
-- place, so a writ piece made this morning is not sold with the rest this evening.
--
-- DAILY WRIT is where such a piece lives while the writ wants it, not a copy of it: the
-- classifier files it here above every AUTOMATE rule and above GARBAGE, below only a move made
-- by hand (ClassifyWith in Classify.lua). So no rule sends it to SELL or DECONSTRUCT, and the
-- merchant's auto-sell never sees it either (Trading.lua asks again).
--
-- The question is the game's own: DoesItemFulfillJournalQuestCondition(bagId, slotIndex,
-- journalQuestIndex, stepIndex, conditionIndex) (ESOUIDocumentation, API 101041), the same call
-- DolgubonsLazyWritCreator asks (BankWithdraw.lua:143), over every quest whose
-- GetJournalQuestType is QUEST_TYPE_CRAFTING (WritCreater.lua:527). Master writs are crafting
-- quests too, so they are asked the same way.
--
-- A piece once matched is remembered by its unique id against the quest's name until that quest
-- leaves the journal: when the writ moves on to "deliver" the craft condition may no longer
-- answer for it, and the piece is still needed for the turn-in, which is what takes it away.

local NAME = "InventoryGroupingDailyWrit"
local REFRESH_MS = 250  -- one list rebuild for a burst of quest updates

-- Only what a writ can ask for; everything else in the bag is never asked.
local WRIT_TYPES = {}
for _, name in ipairs({ "ITEMTYPE_WEAPON", "ITEMTYPE_ARMOR", "ITEMTYPE_GLYPH_ARMOR",
    "ITEMTYPE_GLYPH_JEWELRY", "ITEMTYPE_GLYPH_WEAPON", "ITEMTYPE_POTION", "ITEMTYPE_POISON",
    "ITEMTYPE_FOOD", "ITEMTYPE_DRINK" }) do
    if _G[name] then WRIT_TYPES[_G[name]] = true end
end

local matched = {}      -- [pieceId] = true, this build's answer
-- [pieceId] = true/false: the journal's answer for a piece, kept until a quest changes or the
-- piece's slot does. A bag change used to ask every piece against every condition again on the
-- next build (the inventory opening after any loot); now only the pieces not asked yet are.
local answers = {}
local dirty = true
local remembered        -- [pieceId] = quest name; this character's saved table, once loaded

local function Enabled()
    return IG.sv ~= nil and IG.sv.dailyWritEnabled == true
end

-- The crafting quests in the journal: { index, name } each.
local function CraftingQuests()
    local quests = {}
    if not (GetNumJournalQuests and QUEST_TYPE_CRAFTING) then return quests end
    for index = 1, MAX_JOURNAL_QUESTS or 25 do
        if IsValidQuestIndex(index) and GetJournalQuestType(index) == QUEST_TYPE_CRAFTING then
            quests[#quests + 1] = { index = index, name = GetJournalQuestName(index) }
        end
    end
    return quests
end

local function Rebuild()
    dirty = false
    ZO_ClearTable(matched)
    if not Enabled() then return end
    local quests = CraftingQuests()

    -- What was remembered for a quest no longer in the journal is let go.
    if remembered then
        local open = {}
        for _, quest in ipairs(quests) do open[quest.name] = true end
        for pieceId, questName in pairs(remembered) do
            if not open[questName] then remembered[pieceId] = nil end
        end
    end
    if #quests == 0 then return end

    -- Every condition of every step, done or not: a finished one still wants its piece handed in.
    local conditions = {}
    for _, quest in ipairs(quests) do
        for step = 1, GetJournalQuestNumSteps(quest.index) do
            for condition = 1, GetJournalQuestNumConditions(quest.index, step) do
                conditions[#conditions + 1] = { quest.index, step, condition, quest.name }
            end
        end
    end

    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if HasItemInSlot(BAG_BACKPACK, slotIndex) and WRIT_TYPES[GetItemType(BAG_BACKPACK, slotIndex)] then
            local pieceId = IG.PieceId(BAG_BACKPACK, slotIndex)
            if pieceId then
                if remembered and remembered[pieceId] then
                    matched[pieceId] = true
                elseif answers[pieceId] == nil then
                    answers[pieceId] = false
                    for _, c in ipairs(conditions) do
                        if DoesItemFulfillJournalQuestCondition(BAG_BACKPACK, slotIndex, c[1], c[2], c[3]) then
                            matched[pieceId] = true
                            answers[pieceId] = true
                            if remembered then remembered[pieceId] = c[4] end
                            break
                        end
                    end
                elseif answers[pieceId] then
                    matched[pieceId] = true
                end
            end
        end
    end
end

local function PieceIdOf(slotData)
    if slotData.uniqueId then return Id64ToString(slotData.uniqueId) end
    return IG.PieceId(slotData.bagId, slotData.slotIndex)
end

-- Whether a writ in the journal is waiting for this piece. Asked by the classifier for every
-- piece a rule would send away, so it answers from the table built above.
function IG.IsDailyWritItem(slotData)
    if not (slotData and slotData.bagId == BAG_BACKPACK and slotData.slotIndex) then return false end
    if not Enabled() then return false end
    if dirty then Rebuild() end
    if not next(matched) then return false end
    local pieceId = PieceIdOf(slotData)
    return pieceId ~= nil and matched[pieceId] == true
end

-- A quest arriving, leaving or moving on changes which pieces live in DAILY WRIT. The answer is
-- asked outside the classifier's caches, so a rebuild is all it takes for pieces to move.
local function RefreshSoon()
    dirty = true
    ZO_ClearTable(answers)
    if not Enabled() then return end
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Refresh")
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Refresh", REFRESH_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(NAME .. "Refresh")
        if IG.RefreshLists then IG.RefreshLists() end
    end)
end

-- The bag changing is answered by the game's own rebuild, which asks again; only the answer is
-- marked stale here.
local function OnSlotUpdate(_, bagId, slotIndex)
    dirty = true
    -- Only this slot's piece is asked again; the rest keep their answer.
    local pieceId = slotIndex and IG.PieceId and IG.PieceId(BAG_BACKPACK, slotIndex)
    if pieceId then answers[pieceId] = nil end
end

local function OnLoaded(_, addonName)
    if addonName ~= IG.name then return end
    EVENT_MANAGER:UnregisterForEvent(NAME .. "Load", EVENT_ADD_ON_LOADED)
    local saved = ZO_SavedVars:NewCharacterIdSettings("InventoryGrouping_SV", 1, "DailyWrit", { pieces = {} })
    saved.pieces = saved.pieces or {}
    remembered = saved.pieces
    ZO_ClearTable(answers)
    dirty = true
end

-- One-shot, loads this character's remembered pieces: stays registered either way, it is cheap
-- and only ever fires once.
EVENT_MANAGER:RegisterForEvent(NAME .. "Load", EVENT_ADD_ON_LOADED, OnLoaded)

-- The quest and slot watchers fire all session long (a quest ticking, any bag change), so they
-- are registered only while the module itself is on (IG.MODULE_APPLY, called from
-- IG.SetModuleEnabled and once at load).
local registered = false

local function ApplyEnabled(on)
    if on == registered then return end
    registered = on
    if on then
        EVENT_MANAGER:RegisterForEvent(NAME .. "Added", EVENT_QUEST_ADDED, RefreshSoon)
        EVENT_MANAGER:RegisterForEvent(NAME .. "Removed", EVENT_QUEST_REMOVED, RefreshSoon)
        EVENT_MANAGER:RegisterForEvent(NAME .. "Counter", EVENT_QUEST_CONDITION_COUNTER_CHANGED, RefreshSoon)
        EVENT_MANAGER:RegisterForEvent(NAME .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
        EVENT_MANAGER:AddFilterForEvent(NAME .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    else
        EVENT_MANAGER:UnregisterForEvent(NAME .. "Added", EVENT_QUEST_ADDED)
        EVENT_MANAGER:UnregisterForEvent(NAME .. "Removed", EVENT_QUEST_REMOVED)
        EVENT_MANAGER:UnregisterForEvent(NAME .. "Counter", EVENT_QUEST_CONDITION_COUNTER_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(NAME .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        ZO_ClearTable(matched)
        ZO_ClearTable(answers)
        dirty = true
    end
end

IG.MODULE_APPLY = IG.MODULE_APPLY or {}
IG.MODULE_APPLY.dailyWritEnabled = ApplyEnabled
