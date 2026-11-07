InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- JUNK: the pieces you marked as junk yourself.
--
-- Every other group rearranges rows the game handed us. This one cannot: the game keeps junk on
-- a tab of its own and takes it out of all the others, so a piece marked as junk is gone from
-- the list we group -- and with auto-junk running, most of what would have stood under GARBAGE
-- is never seen again. That is the whole reason for this module. The rows are read straight out
-- of the bag instead, the same way ARMORY reads the pieces you are wearing.

local function IsJunk(slotData)
    if slotData.isJunk ~= nil then return slotData.isJunk == true end
    if not (slotData.bagId and slotData.slotIndex) then return false end
    return IsItemJunk(slotData.bagId, slotData.slotIndex) == true
end

-- The tab filter is deliberately not asked. On every tab but Junk the game's own answer for a
-- junk slot is "leave it out", which is exactly the thing this module exists to undo. The search
-- box still applies: that is the player asking, not the game.
local function Matches(slotData, searchText)
    if searchText == "" then return true end
    return zo_strlower(slotData.name or ""):find(searchText, 1, true) ~= nil
end

-- One row per junked item, under a group of its own. Backpack only: junk is a mark the bag
-- carries, and the bank has no tab for it.
function IG.CollectJunkEntries(inventory, inventoryType, rawEntries, searchText)
    local result = {}
    if not (IG.sv and IG.sv.junkEnabled) then return result end
    if inventoryType ~= INVENTORY_BACKPACK then return result end

    -- On the game's own Junk tab these rows are in the list already, and a row listed twice is
    -- the same item in two places.
    local listed = {}
    for _, entry in ipairs(rawEntries) do
        local data = entry.data
        if data.bagId == BAG_BACKPACK and data.slotIndex then listed[data.slotIndex] = true end
    end

    local bag = SHARED_INVENTORY and SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
    if not bag then return result end

    -- The group is only made once something is going in it, so an empty one never shows.
    --
    -- Every row goes straight under it. Breaking the group into what each piece is was this
    -- module's own switch once, and it is nobody's own now: every category with no headings of
    -- its own answers that question the same way, from the setting in General or from its own
    -- right click menu, and JUNK is one of those categories like any other.
    local root = nil
    for slotIndex, slotData in pairs(bag) do
        if not listed[slotIndex] and IsJunk(slotData) and Matches(slotData, searchText) then
            root = root or IG.MakeGroupNode("JUNK")
            result[#result + 1] = {
                data = setmetatable({ igJunk = true }, { __index = slotData }),
                path = { root },
            }
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Junking stolen rubbish as it arrives
---------------------------------------------------------------------------

-- Nothing else in this addon puts a mark on your items; this does, which is why it is off until
-- you ask for it. Stealing fills a bag faster than anything else you do, and most of what comes
-- out of a drawer is worth the few coins the fence gives and nothing more. The game's own auto
-- junk knows what an item is but not where it came from, so it cannot be told "the stolen ones".
-- Here that is the only thing asked: anything the game stamps stolen, from a pocket or a crate
-- or a safebox alike, is junked the moment it lands if it is under the quality you picked.

-- Three names for the same question, one of them on its way out. The displayed quality is the
-- one to ask: it is the colour the piece wears in the bag, so it is the colour the player had in
-- mind when they set the threshold. Functional quality is what a piece does in combat, which a
-- stolen candlestick does not do at all -- on trash the two usually agree, but where they part
-- the displayed one is the one that was meant. Older clients may be missing either, so each
-- falls through to the next, and if none of them answers nothing is junked.
local function StolenQuality(bagId, slotIndex)
    if GetItemDisplayQuality then return GetItemDisplayQuality(bagId, slotIndex) end
    if GetItemFunctionalQuality then return GetItemFunctionalQuality(bagId, slotIndex) end
    if GetItemQuality then return GetItemQuality(bagId, slotIndex) end
    return nil
end

-- The mark is asked for the careful way, the same as locking is in Overrides.lua. Where the call
-- comes from the game's own event the stack is clean and the plain call stands; where it comes
-- from a menu we drew it does not, and if a client counts this among the functions only it may
-- call, the protected road is there. Shared, so that every place in the addon that puts the mark
-- on a piece puts it on the same way rather than each keeping its own copy of this decision.
function IG.MarkItemAsJunk(bagId, slotIndex)
    -- Noted before the mark goes on, and only while a press of yours has a step open: the two
    -- sweeps below run off the game's own arrival event, and nothing you did is what they undo.
    IG.NoteJunk(bagId, slotIndex)
    if IsProtectedFunction and IsProtectedFunction("SetItemIsJunk") then
        CallSecureProtected("SetItemIsJunk", bagId, slotIndex, true)
    else
        SetItemIsJunk(bagId, slotIndex, true)
    end
end

-- And taken off again the same careful way. A key that puts the mark on has to be able to take
-- it back, and the mark comes off down the road it went on: a client that counts SetItemIsJunk
-- among the functions only it may call does not stop counting it because the answer is false.
function IG.UnmarkItemAsJunk(bagId, slotIndex)
    IG.NoteJunk(bagId, slotIndex)
    if IsProtectedFunction and IsProtectedFunction("SetItemIsJunk") then
        CallSecureProtected("SetItemIsJunk", bagId, slotIndex, false)
    else
        SetItemIsJunk(bagId, slotIndex, false)
    end
end

local MarkAsJunk = IG.MarkItemAsJunk

-- Only pieces arriving in the backpack, and only ones the game calls new: a slot update also
-- fires when a stack is split, moved or spent, and none of those is a theft.
local function OnStolenArrival(_, bagId, slotIndex, isNewItem)
    if not isNewItem or bagId ~= BAG_BACKPACK then return end
    if not (IG.sv and IG.sv.junkStolenEnabled) then return end
    if not IsItemStolen(bagId, slotIndex) then return end
    if IsItemJunk(bagId, slotIndex) then return end
    if not CanItemBeMarkedAsJunk(bagId, slotIndex) then return end

    local quality = StolenQuality(bagId, slotIndex)
    local floor = IG.sv.junkStolenBelow or ITEM_QUALITY_MAGIC
    if not quality or quality >= floor then return end

    MarkAsJunk(bagId, slotIndex)
    -- No list is rebuilt from here. The game rebuilds after a junk mark itself, and a list built
    -- from inside our own frame is the whole of the insecure callstack trouble.
end

local STOLEN_NAME = "InventoryGroupingJunkStolen"

-- Registered only while junkStolenEnabled itself is on, same reasoning as every other
-- all-session listener in this addon (Researchable.lua and the rest): a switch nobody turned on
-- should not keep watching every arrival in the backpack for the rest of the session. The switch
-- on the settings page has its own onToggle that calls this the moment it moves (it is not one
-- of IG.MODULE_GROUPS, so IG.SetModuleEnabled and IG.MODULE_APPLY never see it); the call at the
-- foot of this file catches the state the save was already in when the addon loads.
local stolenRegistered = false

function IG.ApplyJunkStolenEnabled(on)
    on = on == true
    if on == stolenRegistered then return end
    stolenRegistered = on
    if on then
        EVENT_MANAGER:RegisterForEvent(STOLEN_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnStolenArrival)
        EVENT_MANAGER:AddFilterForEvent(STOLEN_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    else
        EVENT_MANAGER:UnregisterForEvent(STOLEN_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    end
end

---------------------------------------------------------------------------
-- Junking what lands in GARBAGE
---------------------------------------------------------------------------

-- The same bargain as above, made with a different pile. GARBAGE is where the classifier puts
-- what it can see no reason to keep, and a player who agrees with it for one kind of piece
-- agrees with it every time that kind lands. So each kind is a switch of its own: the heading
-- the classifier worked out on the way in is asked for, and if that kind is switched on the
-- piece is junked as it arrives.
--
-- Intricate and ornate pieces are not here, and cannot be. They are not "worthless": they are
-- the two the classifier tells you to keep a piece for -- intricate is worth more at a crafting
-- station, ornate is worth more at a merchant -- so they stand in DECONSTRUCT and SELL, out of
-- GARBAGE altogether, and the classifier answers nothing at all when asked what kind of garbage
-- one is. Turn either of those rules off and the piece is back in GARBAGE reading under a
-- heading no switch below names, so it is still never junked. What is left is the four kinds
-- that are what they look like: trinkets, and plain setless gear.
local GARBAGE_KEYS = {
    Treasure = "junkGarbageTreasure",
    Weapons = "junkGarbageWeapons",
    Armor = "junkGarbageArmor",
    Jewelry = "junkGarbageJewelry",
}

-- A piece you locked is one you said something about, and this has nothing to say over that.
-- The game is asked as well, but its own answer does not always cover a lock, and a junked
-- lock is a lock that did not hold.
local function IsLocked(bagId, slotIndex)
    return IsItemPlayerLocked and IsItemPlayerLocked(bagId, slotIndex) == true
end

-- Nothing is done about the NEW mark, and that is a decision rather than an oversight: the mark
-- is on everything that arrives, so honouring it would mean this never fires at all. Arrival is
-- the only moment the answer is cheap to give and the bag is not yet full of it. The switches
-- are off until asked for, and a junk mark is taken back with one click.
local function OnGarbageArrival(_, bagId, slotIndex, isNewItem)
    if not isNewItem or bagId ~= BAG_BACKPACK then return end
    if not IG.sv then return end
    if IsItemJunk(bagId, slotIndex) then return end
    if IsLocked(bagId, slotIndex) then return end
    if not CanItemBeMarkedAsJunk(bagId, slotIndex) then return end
    -- Nor a piece a crafting writ is waiting for (DailyWrit.lua).
    if IG.IsDailyWritItem and IG.IsDailyWritItem({ bagId = bagId, slotIndex = slotIndex }) then return end

    local kind = IG.GarbageKind(bagId, slotIndex)
    local key = kind and GARBAGE_KEYS[kind]
    if not key or IG.sv[key] ~= true then return end

    MarkAsJunk(bagId, slotIndex)
    -- No list is rebuilt from here either, for the reason given above.
end

local GARBAGE_NAME = "InventoryGroupingJunkGarbage"

-- One event feeds all four GARBAGE_KEYS switches, since OnGarbageArrival itself works out which
-- of the four a piece is (or whether it is none of them, most of the time). So it only needs
-- unregistering once every one of the four is off -- any single one of them still on keeps the
-- whole arrival watch alive. Each of the four switches shares this same onToggle.
local garbageRegistered = false

function IG.ApplyJunkGarbageEnabled()
    local on = IG.sv ~= nil and (IG.sv.junkGarbageTreasure == true or IG.sv.junkGarbageWeapons == true
        or IG.sv.junkGarbageArmor == true or IG.sv.junkGarbageJewelry == true)
    if on == garbageRegistered then return end
    garbageRegistered = on
    if on then
        EVENT_MANAGER:RegisterForEvent(GARBAGE_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnGarbageArrival)
        EVENT_MANAGER:AddFilterForEvent(GARBAGE_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    else
        EVENT_MANAGER:UnregisterForEvent(GARBAGE_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    end
end

-- The state the save was already in when the addon loads; IG.sv exists by the time this file's
-- own InventoryGrouping.lua caller reaches it (see the Startup section there), well after both
-- functions above are defined.
function IG.ApplyJunkEventGates()
    IG.ApplyJunkStolenEnabled(IG.sv and IG.sv.junkStolenEnabled)
    IG.ApplyJunkGarbageEnabled()
end
