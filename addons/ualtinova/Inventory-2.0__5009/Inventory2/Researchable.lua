InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- RESEARCHABLE: gear (armour, weapons, jewellery) carrying a trait the character you are playing
-- can still research and is not researching right now. One of DISPOSAL's categories: the piece
-- is on its way to a research bench, which is one more way of getting rid of it.
--
-- Where it stands (ClassifyWith in Classify.lua): below NEW, STOLEN, DAILY WRIT, UNCOLLECTED and
-- a move made by hand; above every AUTOMATE rule, so no rule files a researchable piece into
-- SELL or DECONSTRUCT. A locked piece, a worn one and an unbound bind-on-equip piece (still
-- tradeable: UNCOLLECTED lists it, and it keeps its set) are never filed here.
--
-- The question is the game's own: GetItemTraitInformation(bagId, slotIndex) ==
-- ITEM_TRAIT_INFORMATION_CAN_BE_RESEARCHED (TTCCompanion_Inventory.lua:155 reads the slot form;
-- LibCharacterKnowledge/Internal.lua:1487-1488 compares the link form to this constant). Whether
-- the trait is being researched right now is asked of LibCharacterKnowledge where it is
-- installed: CanItemLinkBeTraitResearchedByCharacter (Public.lua:338-345) is "unknown and no
-- research timer running" for the current character (Internal.lua:1450-1452). Optional, not a
-- dependency; without it the game's answer stands alone.

local NAME = "InventoryGroupingResearchable"
local REFRESH_MS = 250

-- [itemInstanceId] = true / false. Same item, same trait, same answer; only research starting,
-- finishing or being cancelled changes it, and those events forget them all.
local researchable = {}

local GEAR_TYPES = { [ITEMTYPE_ARMOR] = true, [ITEMTYPE_WEAPON] = true }

local function CanResearch(slotData)
    local bagId, slotIndex = slotData.bagId, slotData.slotIndex
    local instanceId = slotData.itemInstanceId
    local known = instanceId and researchable[instanceId]
    if known ~= nil then return known end

    local answer = GetItemTraitInformation(bagId, slotIndex) == ITEM_TRAIT_INFORMATION_CAN_BE_RESEARCHED
    if answer then
        local lck = LibCharacterKnowledge
        if lck and lck.CanItemLinkBeTraitResearchedByCharacter then
            local link = GetItemLink(bagId, slotIndex)
            if link and link ~= "" then
                answer = lck.CanItemLinkBeTraitResearchedByCharacter(link) == true
            end
        end
    end
    if instanceId then researchable[instanceId] = answer end
    return answer
end

-- Whether the classifier files this row under RESEARCHABLE (Classify.lua, ClassifyWith).
function IG.IsResearchableItem(slotData)
    if not (IG.sv and IG.sv.researchableEnabled) then return false end
    local bagId, slotIndex = slotData.bagId, slotData.slotIndex
    if not bagId or not slotIndex or bagId == BAG_WORN then return false end
    local itemType = slotData.itemType
    if itemType == nil then itemType = GetItemType(bagId, slotIndex) end
    if not GEAR_TYPES[itemType] then return false end
    if IG.IsSlotLocked(slotData) then return false end
    -- UNCOLLECTED wins: a piece that can still be traded is not one to research away.
    if IG.IsUnboundBindOnEquip and IG.IsUnboundBindOnEquip(slotData) then return false end
    return CanResearch(slotData)
end

function IG.ClearResearchableCache()
    ZO_ClearTable(researchable)
end

-- Starting research spends one piece, and the bag's own update rebuilds the list for that; every
-- other piece with the same trait stops being researchable without the bag changing, and one
-- finishing or being cancelled changes the answer the same way. So each asks for one rebuild.
local function OnResearchChanged()
    ZO_ClearTable(researchable)
    if not (IG.sv and IG.sv.researchableEnabled) then return end
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Refresh")
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Refresh", REFRESH_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(NAME .. "Refresh")
        if IG.RefreshLists then IG.RefreshLists() end
    end)
end

-- The three LibCharacterKnowledge refreshes on (Internal.lua:872-874). Registered only while the
-- module itself is on (IG.MODULE_APPLY, called from IG.SetModuleEnabled and once at load) rather
-- than left registered forever and asked to do nothing -- a switch somebody left off should not
-- keep listening for research events for the rest of the session.
local registered = false

local function ApplyEnabled(on)
    if on == registered then return end
    registered = on
    if on then
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_SMITHING_TRAIT_RESEARCH_STARTED, OnResearchChanged)
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED, OnResearchChanged)
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_SMITHING_TRAIT_RESEARCH_CANCELED, OnResearchChanged)
    else
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_SMITHING_TRAIT_RESEARCH_STARTED)
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED)
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_SMITHING_TRAIT_RESEARCH_CANCELED)
        ZO_ClearTable(researchable)
    end
end

IG.MODULE_APPLY = IG.MODULE_APPLY or {}
IG.MODULE_APPLY.researchableEnabled = ApplyEnabled
