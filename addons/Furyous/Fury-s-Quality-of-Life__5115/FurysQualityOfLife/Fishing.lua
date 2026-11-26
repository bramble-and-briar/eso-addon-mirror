-- Fury's Quality of Life - fishing
-- Four comforts, each with its own switch:
--   Bite alert   a sound and a flash on screen the moment a fish is on the line
--   Right bait   when you look at a fishing hole, the bait that fits its water is chosen, and
--                of the baits that fit, the one you have the most of
--   Bag warning  a line and a sound when the bag is nearly full at a bite
--   Rare fish    a callout when a rare fish lands in the bag
--
-- How the bite is seen: the game uses up one bait at the moment a fish bites. The bait can be
-- in the backpack or in the craft bag, so it is watched two ways: the count of the chosen bait
-- is read several times a second, and bag changes of a bait are listened for. Either one
-- dropping by one while the game world is on screen (no menu open) is the bite.
-- /qol fishdebug prints what both see while it is on, to check this in game.

local QOL = FurysQualityOfLife

-- Which baits fit which water. Names as the English game shows them, in small letters.
local WATERS = {
    { id = "foul", name = "Foul", holes = { "foul", "oily" }, baits = { "crawlers", "fish roe" } },
    { id = "river", name = "River", holes = { "river" }, baits = { "insect parts", "shad" } },
    { id = "lake", name = "Lake", holes = { "lake" }, baits = { "guts", "minnow" } },
    { id = "salt", name = "Salt", holes = { "saltwater", "salt water", "ocean" }, baits = { "worms", "chub" } },
}
local ANY_WATER_BAIT = "simple bait"

local function Plain(text)
    return zo_strlower(zo_strformat("<<1>>", text))
end

local function Contains(text, list)
    for _, word in ipairs(list) do
        if string.find(text, word, 1, true) then return true end
    end
    return false
end

local function WaterOf(holeName)
    local text = Plain(holeName)
    for _, water in ipairs(WATERS) do
        if Contains(text, water.holes) then return water end
    end
    return nil
end

------------------------------------------------------------------------------
-- Right bait
------------------------------------------------------------------------------
-- The bait to use for a water: of the baits that fit, the one with the most in the bag. With
-- none of them, Simple Bait if there is any. Returns lure index, name, count, isSimple.
local function BestBait(water)
    local best, bestName, bestCount = nil, nil, 0
    local simple, simpleName, simpleCount = nil, nil, 0
    for index = 1, GetNumFishingLures() do
        local name, _, stack = GetFishingLureInfo(index)
        if stack > 0 then
            local text = Plain(name)
            if Contains(text, water.baits) then
                if stack > bestCount then best, bestName, bestCount = index, name, stack end
            elseif string.find(text, ANY_WATER_BAIT, 1, true) then
                simple, simpleName, simpleCount = index, name, stack
            end
        end
    end
    if best then return best, bestName, bestCount, false end
    return simple, simpleName, simpleCount, true
end
QOL.BestBait = BestBait

local lookingAt = nil     -- the fishing hole under the crosshair, nil when there is none
local told = {}           -- chat lines already said this session, so none repeats

local function TellOnce(key, text)
    if told[key] then return end
    told[key] = true
    QOL.Msg(text)
end

local function ChooseBait(holeName)
    local water = WaterOf(holeName)
    if not water then
        TellOnce("hole:" .. holeName, "I don't know which bait fits \"" .. zo_strformat("<<1>>", holeName) .. "\", so your bait stays as it is.")
        return
    end
    local index, name, count, isSimple = BestBait(water)
    if not index then
        TellOnce("none:" .. water.id, "No bait for " .. zo_strlower(water.name) .. " water in your bag.")
        return
    end
    if isSimple then
        TellOnce("simple:" .. water.id, "No " .. zo_strlower(water.name) .. " bait in your bag, so Simple Bait is used.")
    end
    if GetFishingLure() ~= index then
        SetFishingLure(index)
        QOL.Msg(water.name .. " water: bait set to " .. zo_strformat("<<1>>", name) .. " (" .. count .. " left).")
    end
end

-- When the crosshair was last on a fishing hole. A bite only counts shortly after that, so bait
-- or anything else leaving the bags somewhere else (a writ handed in, a sale) is never a bite.
local lastHole = nil
local FISHING_WINDOW = 90000   -- a cast waits well under a minute for its bite

local function AtFishingHole()
    return lastHole ~= nil and GetGameTimeMilliseconds() - lastHole <= FISHING_WINDOW
end

-- Runs a few times a second while the switch is on. The bait is chosen once each time the
-- crosshair lands on a fishing hole, so a bait picked by hand afterwards stays.
local function WatchCrosshair()
    local _, name, _, _, additionalInfo = GetGameCameraInteractableActionInfo()
    if additionalInfo ~= ADDITIONAL_INTERACT_INFO_FISHING_NODE or name == nil then
        lookingAt = nil
        return
    end
    lastHole = GetGameTimeMilliseconds()
    if not QOL.SV().fishBait then return end   -- only here to note the fishing hole
    if GetInteractionType() == INTERACTION_FISH then return end   -- line is out: leave the bait
    if lookingAt == name then return end
    lookingAt = name
    ChooseBait(name)
end
QOL.WatchCrosshair = WatchCrosshair

------------------------------------------------------------------------------
-- Bite alert
------------------------------------------------------------------------------
function QOL.FishAlert()
    QOL.Alert("Fish on the line!", QOL.SV().fishSound)
end

local debugOn = false
local lastAlert = 0       -- so the two ways of seeing one bite alert once

local function InWorld()
    return SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
end

local BAG_WARN_SLOTS = 5   -- "nearly full" means this many free slots or fewer
local bagWarned = false

local function Bite()
    local sv = QOL.SV()
    local now = GetGameTimeMilliseconds()
    if now - lastAlert < 2000 then return end
    lastAlert = now
    if sv.fishAlert then QOL.FishAlert() end
    if sv.fishBagWarn then
        local free = GetNumBagFreeSlots(BAG_BACKPACK)
        if free > BAG_WARN_SLOTS then
            bagWarned = false
        elseif not bagWarned then
            -- said once, and again only after the bag had room in between
            bagWarned = true
            if free == 0 then
                QOL.Msg("Your bag is full. The next fish won't fit.")
            elseif free == 1 then
                QOL.Msg("Your bag is nearly full: 1 slot left.")
            else
                QOL.Msg("Your bag is nearly full: " .. free .. " slots left.")
            end
            PlaySound(SOUNDS.NEW_NOTIFICATION)
        end
    end
end

-- A rare fish landed in the backpack.
local function RareFish(bag, slot)
    local name = zo_strformat("<<1>>", GetItemName(bag, slot))
    QOL.Alert("Rare fish: " .. name .. "!", QOL.SV().fishSound, 2500)
    QOL.Msg("Rare fish caught: " .. GetItemLink(bag, slot) .. ".")
end

local function OnSlotUpdate(_, bag, slot, isNew, _, reason, stackCountChange)
    if bag ~= BAG_BACKPACK and bag ~= BAG_VIRTUAL then return end
    local itemType, specialType = GetItemType(bag, slot)
    local inWorld = InWorld()
    if isNew and bag == BAG_BACKPACK and inWorld and QOL.SV().fishRare
        and specialType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH then
        RareFish(bag, slot)
    end
    if debugOn then
        QOL.Msg("Bag change: bag " .. bag .. ", item type " .. itemType .. ", count " .. tostring(stackCountChange) .. ", reason " .. tostring(reason)
            .. ", new " .. tostring(isNew) .. ", interaction " .. GetInteractionType() .. ", in world " .. tostring(inWorld))
    end
    if stackCountChange ~= -1 or not inWorld or not AtFishingHole() then return end
    -- One bait gone. 0.5.5: an emptied backpack slot no longer counts, because a writ handed in
    -- empties one too; the last bait of a stack is seen by WatchLure below.
    if itemType == ITEMTYPE_LURE then Bite() end
end

-- Reads the count of the chosen bait several times a second.
local watchedLure, watchedCount = nil, 0

local function WatchLure()
    -- The bait watched so far, even when the game has just unselected it because it ran out.
    if watchedLure then
        local _, _, count = GetFishingLureInfo(watchedLure)
        count = count or 0
        if count ~= watchedCount then
            local inWorld, atHole = InWorld(), AtFishingHole()
            if debugOn then
                QOL.Msg("Bait count: " .. watchedCount .. " to " .. count .. ", interaction " .. GetInteractionType() .. ", in world " .. tostring(inWorld)
                    .. ", at a fishing hole " .. tostring(atHole))
            end
            if count == watchedCount - 1 and inWorld and atHole then Bite() end
        end
    end
    local lure = GetFishingLure()
    if not lure or lure == 0 then
        watchedLure = nil
        return
    end
    local _, _, count = GetFishingLureInfo(lure)
    watchedLure, watchedCount = lure, count or 0
end
QOL.WatchLure = WatchLure

-- /qol fishdebug: prints every bag change until it is typed again or the UI reloads.
function QOL.FishDebug()
    debugOn = not debugOn
    QOL.RefreshFishing()
    if debugOn then
        QOL.Msg("Fishing check is on: every change in your bags and in your bait count is printed here. Catch a fish, then type /qol fishdebug again to turn it off.")
    else
        QOL.Msg("Fishing check is off.")
    end
end

------------------------------------------------------------------------------
-- Switches
------------------------------------------------------------------------------
local BITE_EVENT = QOL.name .. "FishBite"
local BAIT_UPDATE = QOL.name .. "FishBait"
local LURE_UPDATE = QOL.name .. "FishLure"

-- Listens only for what is turned on.
function QOL.RefreshFishing()
    local sv = QOL.SV()
    EVENT_MANAGER:UnregisterForEvent(BITE_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForUpdate(BAIT_UPDATE)
    EVENT_MANAGER:UnregisterForUpdate(LURE_UPDATE)
    if sv.fishAlert or sv.fishBagWarn or sv.fishRare or debugOn then
        EVENT_MANAGER:RegisterForEvent(BITE_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
    end
    if sv.fishAlert or sv.fishBagWarn or debugOn then
        watchedLure = nil
        EVENT_MANAGER:RegisterForUpdate(LURE_UPDATE, 100, WatchLure)
    end
    if sv.fishBait or sv.fishAlert or sv.fishBagWarn or debugOn then
        lookingAt = nil
        EVENT_MANAGER:RegisterForUpdate(BAIT_UPDATE, 250, WatchCrosshair)
    end
end

function QOL.InitFishing()
    QOL.RefreshFishing()
end
