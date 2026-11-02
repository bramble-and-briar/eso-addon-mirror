InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- UNCOLLECTED: what is still yours to collect, gathered in one place. Two kinds of thing:
--   1. every piece that binds on equip and is not bound yet -- still free to sell, trade or mail;
--   2. a crafting motif, a provisioning recipe, a furnishing plan or an outfit style page this
--      account has not learned or unlocked yet (each of the four can be left out from the
--      module's settings). A collectible container (a runebox and the like) is not one of them:
--      it stays under REWARDS whatever it holds.
--
-- The group was called BIND ON EQUIP before it took in the second kind. Its key (BINDONEQUIP),
-- this file and the saved switches (bindOnEquip*) keep the old name, so everything saved against
-- them -- order, section, colour, glow, animation, the switch itself -- reads the same as before;
-- only what the heading says changed (Colors.lua).
--
-- The two kinds stand here differently.
--   1. An unbound piece is listed here as well as wherever else it already stands, never instead
--      of it: it stays under its set, and while it is still new, or still part of the last run,
--      it stands in those too. So NEW and RECENT LOOT are not stages it leaves this group for --
--      they are simply the other place it is, for as long as it is there.
--   2. A motif, recipe, plan or style page still to learn lives here instead of MOTIFS or CRAFT:
--      the classifier sends its own row here (Classify.lua, ClassifyWith; IG.IsUnlearnedItem
--      below).
--      Only where something outranks that -- NEW, STOLEN, DAILY WRIT, a move made by hand, the
--      LOCKED gathering -- is the row somewhere else, and then this group lists it a second
--      time, the way it lists an unbound piece.
--
-- Wearing a piece binds it, and learning a book or a recipe teaches it, and using a style page
-- unlocks its style; either way it drops out on its own the next time the list is built (the
-- learning events at the foot of this file ask for that build, since a second copy of what was
-- just learned does not change the bag).

-- The bind type is a property of the kind of item, so it is asked once per item id; whether this
-- one is bound yet is not, and is asked of the slot every time.
local bindTypes = {} -- [itemInstanceId] = bind type

local function IsBindOnEquip(slotData)
    local bagId, slotIndex = slotData.bagId, slotData.slotIndex
    if not bagId or not slotIndex then return false end

    local instanceId = slotData.itemInstanceId
    local bindType = instanceId and bindTypes[instanceId]
    if not bindType then
        bindType = GetItemBindType(bagId, slotIndex)
        if instanceId then bindTypes[instanceId] = bindType end
    end
    if bindType ~= BIND_TYPE_ON_EQUIP then return false end

    -- Worn once and it is bound for good; this group is about what can still be handed on.
    return not IsItemBound(bagId, slotIndex)
end

-- Read by RESEARCHABLE (Researchable.lua): a piece that can still be traded stays out of it.
IG.IsUnboundBindOnEquip = IsBindOnEquip

-- Whether this character knows what a book or a recipe teaches, kept per item instance id: every
-- copy of the same thing has the same answer, and only learning it changes that answer, which
-- the events below meet by forgetting them all.
local learned = {} -- [itemInstanceId] = true (known) / false (still to learn)

-- Whether this is an outfit style page: an item that unlocks an outfit style collectible when
-- used. The game files them under two specialized types, both named "Style Page" -- the page
-- itself (ITEMTYPE_COLLECTIBLE) and the container one comes in (ITEMTYPE_CONTAINER) -- and the
-- classifier keeps the list (Classify.lua, STYLE_PAGE_SPECIALIZED). A runebox is a plain
-- container (SPECIALIZED_ITEMTYPE_CONTAINER) that happens to hold a collectible too, so what it
-- holds does not make it one: only the specialized type does.
local function IsStylePage(specializedType)
    local pages = IG.STYLE_PAGE_SPECIALIZED
    return pages ~= nil and pages[specializedType] == true
end

-- Which of the four kinds this item is, and whether that kind is asked for (Settings: the
-- module's own switches, read as "not switched off" so a save from before them reads ON).
local function KindAsked(itemType, specializedType)
    local sv = IG.sv
    if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then return sv.bindOnEquipMotifs ~= false end
    if itemType == ITEMTYPE_RECIPE then
        -- A furnishing plan is a recipe whose result is a furnishing; the classifier keeps the
        -- list of their specialized types (Classify.lua, FURNISHING_PLAN_SPECIALIZED).
        local plans = IG.FURNISHING_PLAN_SPECIALIZED
        if plans and plans[specializedType] then return sv.bindOnEquipPlans ~= false end
        return sv.bindOnEquipRecipes ~= false
    end
    if IsStylePage(specializedType) then return sv.bindOnEquipStylePages ~= false end
    return false
end

-- Whether the collectible this item adds is already in the collection. The collectible an item
-- grants is asked of its link (itemtooltips.lua:759: GetItemLinkContainerCollectibleId, 0 when
-- it grants none), and owned is the rule the game's own tooltip uses to print "already in
-- collection" or "add to collection" (itemtooltips.lua:763-768: IsCollectibleOwnedByDefId).
-- Collectibles belong to the account, so unlike a recipe this is the same for every character.
-- Returns nil when the item names no collectible, which leaves the row where its kind puts it.
local function IsCollectibleOwned(itemLink)
    local collectibleId = GetItemLinkContainerCollectibleId(itemLink)
    -- Only one id is offered per item; where it is missing, the link's own collectible is tried.
    if not collectibleId or collectibleId == 0 then
        collectibleId = GetCollectibleIdFromLink and GetCollectibleIdFromLink(itemLink)
    end
    if not collectibleId or collectibleId == 0 then return nil end
    return IsCollectibleOwnedByDefId(collectibleId) == true
end

-- A motif (a whole book or one chapter), a recipe, a furnishing plan or an outfit style page this
-- character has still to learn or unlock. Known by THIS character is the rule for books and
-- recipes, the one the game's own tooltip uses (itemtooltips.lua: IsItemLinkRecipeKnown for
-- recipes, IsItemLinkBookKnown for books): the bank is shared, and what an alt knows says nothing
-- about what this one can still read. A style page is the account's, not the character's.
local function IsUnlearned(slotData)
    local bagId, slotIndex = slotData.bagId, slotData.slotIndex
    if not bagId or not slotIndex then return false end
    -- The game's slot data carries both types (sharedinventory.lua); asked of the slot otherwise.
    local itemType, specializedType = slotData.itemType, slotData.specializedItemType
    if itemType == nil then itemType, specializedType = GetItemType(bagId, slotIndex) end
    if not KindAsked(itemType, specializedType) then return false end

    local instanceId = slotData.itemInstanceId
    local known
    if instanceId then known = learned[instanceId] end
    if known == nil then
        local itemLink = GetItemLink(bagId, slotIndex)
        if not itemLink or itemLink == "" then return false end
        local settled = true
        if itemType == ITEMTYPE_RECIPE then
            known = IsItemLinkRecipeKnown(itemLink) == true
        elseif IsStylePage(specializedType) then
            known = IsCollectibleOwned(itemLink)
            -- A page that names no collectible has nothing to collect: it stays under MOTIFS,
            -- and the answer is not kept in case the game names one later.
            if known == nil then return false end
        else
            known = IsItemLinkBookKnown(itemLink) == true
            -- The game now and then calls a whole motif book unknown when every chapter in it is
            -- known (LibCharacterKnowledge/Internal.lua:1012-1015). LibCharacterKnowledge works
            -- around that from the chapters (Internal.lua:980-982, 1016-1040), so where it is
            -- installed its word is asked too (Public.lua:121-125; current character by default).
            -- Optional, not a dependency. Until it has scanned (KNOWLEDGE_NODATA, the first
            -- seconds after login) the answer is not kept, so it is asked again on the next build.
            local lck = LibCharacterKnowledge
            if not known and lck and lck.GetItemKnowledgeForCharacter then
                local state = lck.GetItemKnowledgeForCharacter(itemLink)
                if state == lck.KNOWLEDGE_KNOWN then
                    known = true
                elseif state == lck.KNOWLEDGE_NODATA then
                    settled = false
                end
            end
        end
        if instanceId and settled then learned[instanceId] = known end
    end
    return not known
end

-- Whether the classifier sends this row here rather than to MOTIFS or CRAFT (Classify.lua,
-- ClassifyWith): a motif, recipe or plan still to learn, while the group is on and its kind is
-- asked for. Off, every one of them stands where its kind puts it.
function IG.IsUnlearnedItem(slotData)
    if not (IG.sv and IG.sv.bindOnEquipEnabled) then return false end
    return IsUnlearned(slotData)
end

-- One row per piece, under a group of its own: the real items seen a second time, the same way
-- ARMORY and RECENT LOOT show theirs -- all of them, including the ones you have already
-- decided about, which stand here the way they stand at home: down, and saying where they have
-- gone.
function IG.CollectBindOnEquipEntries(inventory, inventoryType, rawEntries)
    local result = {}
    if not (IG.sv and IG.sv.bindOnEquipEnabled) then return result end
    -- Not on the game's Junk tab: everything it hands us is junked, so this group would ask its
    -- question of junk alone and answer it over the whole tab.
    if IG.OnJunkTab and IG.OnJunkTab(inventory) then return result end

    -- The group is only made once something is going in it, so an empty one never shows.
    local root
    -- Hide Moved is about the copies, not about the pieces. This row is not a copy of another
    -- row -- it is the only place this group lists the piece at all, and the question the group
    -- asks is still answered by a piece you have decided to sell. So the row stays either way;
    -- what goes with the switch is the stood-down look, which is what the switch is there to be
    -- rid of. The fact itself stays, in the quietest form there is: a few words after the name.
    local moved = IG.MovedShown(IG.InventoryKey(inventoryType))
    for _, entry in ipairs(rawEntries) do
        local data = entry.data
        -- Everything that is still yours to collect, wherever else it happens to stand. This
        -- group answers one question about the whole bag, and a piece you have decided to sell
        -- is the likeliest answer there is: leaving it out was leaving out the ones the question
        -- is really about. The same holds for a motif or a recipe you sent somewhere by hand.
        -- SELL [GUILD STORE] is the exception, unless asked for: a piece kept there to list later
        -- already has its answer, and seeing it again here is only noise. SetAsideKey says
        -- GUILDSELL only while that category is on, so switching it off brings them back.
        -- A row the classifier already put here (a motif, recipe or plan still to learn, or
        -- anything sent here by hand) is not listed a second time under the same heading.
        local home = entry.igPath and entry.igPath[1]
        local wanted = not (home and home.id == "BINDONEQUIP")
            and (IsBindOnEquip(data) or IsUnlearned(data))
        local aside = wanted and IG.SetAsideKey(data)
        if aside == "GUILDSELL" and not IG.sv.bindOnEquipShowGuild then aside = false end
        if aside ~= false then
            root = root or IG.MakeGroupNode("BINDONEQUIP")
            result[#result + 1] = {
                -- A piece already sent to SELL, DECONSTRUCT or one of your own is still an
                -- answer to what this group asks, and still a decision you have made: the row
                -- says both, the same way the row at home does.
                data = setmetatable({ igBindOnEquip = true,
                    igSetAside = moved and aside or nil,
                    -- And with the switch off, where it went is all that is left of it: no
                    -- standing down, just the words beside the name, because the row itself
                    -- is what the switch was never about.
                    igMovedNote = (not moved) and aside or nil },
                    { __index = data }),
                path = { root },
            }
        end
    end
    return result
end

-- Equipping something changes whether it is bound, and the answer above is only kept per item
-- id for the part that cannot change. Cleared with the rest of what the lists remember, and the
-- learned answers with it.
function IG.ClearBindOnEquipCache()
    ZO_ClearTable(bindTypes)
    ZO_ClearTable(learned)
end

---------------------------------------------------------------------------
-- Learning something: the copies still in the bag drop out
---------------------------------------------------------------------------

-- Reading a book or a recipe uses it up, and the bag's own update rebuilds the list. A second
-- copy of the same thing is left exactly where it was, though, and nothing about the bag says
-- it is no longer something to learn -- so learning asks for one rebuild of its own, after the
-- burst (a whole motif book announces each chapter it teaches). Unlocking a style does the same.
local LEARN_EVENT = "InventoryGroupingUncollected"
local REFRESH_MS = 250

local function OnLearned()
    ZO_ClearTable(learned)
    if not (IG.sv and IG.sv.bindOnEquipEnabled) then return end
    EVENT_MANAGER:UnregisterForUpdate(LEARN_EVENT .. "Refresh")
    EVENT_MANAGER:RegisterForUpdate(LEARN_EVENT .. "Refresh", REFRESH_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(LEARN_EVENT .. "Refresh")
        if IG.RefreshLists then IG.RefreshLists() end
    end)
end

-- Using a style page unlocks a collectible. The game's collection reads two events for that
-- (collectibledatamanager.lua:1159-1162): EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED for an
-- ownership change (a reward, the crown store, a page used), and EVENT_COLLECTION_UPDATED for
-- the whole collection coming up or being redone. EVENT_COLLECTIBLE_UPDATED is not one of them: it
-- only follows a nickname or an active/inactive change and says nothing about unlocking. Only
-- asked while style pages are, since nothing else here depends on the collection.
local function OnCollectionChanged()
    if not (IG.sv and IG.sv.bindOnEquipStylePages ~= false) then return end
    OnLearned()
end

-- The three events the game's own provisioner and alerts listen to for exactly this
-- (provisioner_manager.lua, alerthandlers.lua); LibCharacterKnowledge refreshes on the same three.
-- Registered only while UNCOLLECTED itself is on (IG.MODULE_APPLY, called from
-- IG.SetModuleEnabled and once at load).
local registered = false

local function ApplyEnabled(on)
    if on == registered then return end
    registered = on
    if on then
        EVENT_MANAGER:RegisterForEvent(LEARN_EVENT, EVENT_RECIPE_LEARNED, OnLearned)
        EVENT_MANAGER:RegisterForEvent(LEARN_EVENT, EVENT_MULTIPLE_RECIPES_LEARNED, OnLearned)
        EVENT_MANAGER:RegisterForEvent(LEARN_EVENT, EVENT_STYLE_LEARNED, OnLearned)
        EVENT_MANAGER:RegisterForEvent(LEARN_EVENT, EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED, OnCollectionChanged)
        EVENT_MANAGER:RegisterForEvent(LEARN_EVENT, EVENT_COLLECTION_UPDATED, OnCollectionChanged)
    else
        EVENT_MANAGER:UnregisterForEvent(LEARN_EVENT, EVENT_RECIPE_LEARNED)
        EVENT_MANAGER:UnregisterForEvent(LEARN_EVENT, EVENT_MULTIPLE_RECIPES_LEARNED)
        EVENT_MANAGER:UnregisterForEvent(LEARN_EVENT, EVENT_STYLE_LEARNED)
        EVENT_MANAGER:UnregisterForEvent(LEARN_EVENT, EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(LEARN_EVENT, EVENT_COLLECTION_UPDATED)
        ZO_ClearTable(learned)
    end
end

IG.MODULE_APPLY = IG.MODULE_APPLY or {}
IG.MODULE_APPLY.bindOnEquipEnabled = ApplyEnabled
