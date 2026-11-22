-- Assistants from your quickslots (formerly part of EssentialSnugpodTools).
--
-- Using an assistant collectible (banker, merchant, deconstruction, smuggler, armory) or the
-- Aetherial Well from the quickslot wheel inside a house brings the placed one in front of
-- you; using it again sends it back. In your own house, if none is placed, it is placed in
-- front of you and removed again on the next use.
--
-- Essential Housing Tools has its own version of this, so the module is not loaded when EHT
-- is enabled.

local SHT = SchrodisHousingTools

local AETHERIAL_WELL_ID = 8006
local AETHERIAL_WELL_NAME = "Aetherial Well" -- fallback match, see FindAetherialWell
local SUMMON_DISTANCE = 200
local QUICKSLOT_COOLDOWN_S = 2

-- /script for id=1,50000 do if GetCollectibleCategoryType(id)==COLLECTIBLE_CATEGORY_TYPE_ASSISTANT then d(id.." - "..GetCollectibleName(id)) end end
local ASSISTANT_CATEGORIES =
{
    -- Bankers
    [267] = "banker", [6376] = "banker", [8994] = "banker", [9743] = "banker", [12413] = "banker", [13517] = "banker",
    -- Merchants
    [301] = "merchant", [6378] = "merchant", [8995] = "merchant", [9744] = "merchant", [396] = "merchant", [397] = "merchant",
    [11059] = "merchant", [13063] = "merchant", [13066] = "merchant", [14204] = "merchant",
    -- Deconstruction
    [10184] = "deconstructor", [10617] = "deconstructor", [11097] = "deconstructor", [11877] = "deconstructor",
    [12414] = "deconstructor", [14018] = "deconstructor",
    -- Smuggling
    [300] = "smuggler",
    -- Armory
    [9745] = "armorer", [10618] = "armorer", [11876] = "armorer", [13518] = "armorer",
}

-- category -> saved original position (or autoPlaced) while summoned
local summoned = {}
local cooldownUntil = 0

local function PlacedFurnitureIterator()
    local fid
    return function()
        local nextFid = GetNextPlacedHousingFurnitureId(fid)
        if nextFid == fid then return nil end
        fid = nextFid
        return fid
    end
end

local function FindFurnitureForCollectible(collectibleId)
    for fid in PlacedFurnitureIterator() do
        if GetCollectibleIdFromFurnitureId(fid) == collectibleId then
            return fid
        end
    end
end

local function FindFurnitureForCategory(category)
    for fid in PlacedFurnitureIterator() do
        local cid = GetCollectibleIdFromFurnitureId(fid)
        if cid and ASSISTANT_CATEGORIES[cid] == category then
            return fid, cid
        end
    end
end

local function FindAetherialWell()
    local fid = FindFurnitureForCollectible(AETHERIAL_WELL_ID)
    if fid then return fid end
    for placedId in PlacedFurnitureIterator() do
        if GetPlacedHousingFurnitureInfo(placedId) == AETHERIAL_WELL_NAME then
            return placedId
        end
    end
end

local function SavePosition(fid)
    local x, y, z = HousingEditorGetFurnitureWorldPosition(fid)
    local pitch, yaw, roll = HousingEditorGetFurnitureOrientation(fid)
    return { x = x, y = y, z = z, pitch = pitch, yaw = yaw, roll = roll }
end

local function RestorePosition(fid, saved)
    return HousingEditorRequestChangePositionAndOrientation(fid, saved.x, saved.y, saved.z, saved.pitch, saved.yaw, saved.roll)
end

-- A spot in front of the player, facing the player.
local function GetSummonSpot()
    local px, py, pz, pyaw = GetPlayerWorldPositionInHouse()
    local x = px - math.sin(pyaw) * SUMMON_DISTANCE
    local z = pz - math.cos(pyaw) * SUMMON_DISTANCE
    local yaw = (pyaw + math.pi) % (2 * math.pi)
    return x, py, z, yaw
end

local function MoveToPlayer(fid)
    local x, y, z, yaw = GetSummonSpot()
    return HousingEditorRequestChangePositionAndOrientation(fid, x, y, z, 0, yaw, 0)
end

local function ToggleAetherialWell()
    local wellId = FindAetherialWell()
    if not wellId then
        SHT.Msg("Aetherial Well not found in this house.")
        return
    end
    local saved = summoned.well
    if not saved then
        local position = SavePosition(wellId)
        local result = MoveToPlayer(wellId)
        if result == HOUSING_REQUEST_RESULT_SUCCESS then
            summoned.well = position
            SHT.Msg("Summoning Aetherial Well.")
        else
            SHT.Msg("Failed to summon Aetherial Well. " .. SHT.FormatHousingResult(result))
        end
    else
        local result = RestorePosition(wellId, saved)
        if result == HOUSING_REQUEST_RESULT_SUCCESS then
            summoned.well = nil
            SHT.Msg("Sending Aetherial Well back.")
        else
            SHT.Msg("Failed to send Aetherial Well back. " .. SHT.FormatHousingResult(result))
        end
    end
end

-- Returns false when nothing could be done here, so the game uses the collectible as usual
-- (a temporary assistant next to you).
local function SummonAssistant(collectibleId, category)
    local fid, foundId = FindFurnitureForCategory(category)
    if fid then
        local position = SavePosition(fid)
        position.collectibleId = foundId
        local result = MoveToPlayer(fid)
        if result == HOUSING_REQUEST_RESULT_SUCCESS then
            summoned[category] = position
            SHT.Msg("Summoning " .. category .. ".")
        else
            SHT.Msg("Failed to summon " .. category .. ". " .. SHT.FormatHousingResult(result))
        end
        return true
    end

    if not IsOwnerOfCurrentHouse() then
        return false
    end

    local x, y, z, yaw = GetSummonSpot()
    local result = HousingEditorRequestCollectiblePlacement(collectibleId, x, y, z, 0, yaw, 0)
    if result ~= HOUSING_REQUEST_RESULT_SUCCESS then
        SHT.Msg("Failed to place " .. category .. ". " .. SHT.FormatHousingResult(result))
        return false
    end
    SHT.Msg("Placing " .. category .. ".")
    zo_callLater(function()
        local placedId, placedCollectibleId = FindFurnitureForCategory(category)
        if placedId then
            summoned[category] = { collectibleId = placedCollectibleId, autoPlaced = true }
        else
            SHT.Msg("Failed to place " .. category .. ". Not found after placement.")
        end
    end, 500)
    return true
end

local function DismissAssistant(category, saved)
    local fid = FindFurnitureForCollectible(saved.collectibleId)
    if not fid then
        summoned[category] = nil
        return
    end
    local result
    if saved.autoPlaced then
        result = HousingEditorRequestRemoveFurniture(fid)
        SHT.Msg("Removing " .. category .. ".")
    else
        result = RestorePosition(fid, saved)
        SHT.Msg("Sending " .. category .. " back.")
    end
    if result == HOUSING_REQUEST_RESULT_SUCCESS then
        summoned[category] = nil
    else
        SHT.Msg("Failed to send " .. category .. " back. " .. SHT.FormatHousingResult(result))
    end
end

-- Returns true if the quickslot use was handled here (the game's own use is then skipped).
local function OnQuickslotRelease(button)
    if GetCurrentZoneHouseId() == 0 then return false end

    local link = GetSlotItemLink(button:GetSlot(), button:GetHotbarCategory())
    if link == "" then return false end
    local collectibleId = GetCollectibleIdFromLink(link)
    if not collectibleId then return false end

    local category = ASSISTANT_CATEGORIES[collectibleId]
    if collectibleId ~= AETHERIAL_WELL_ID and not category then return false end

    local now = GetFrameTimeSeconds()
    if now < cooldownUntil then return true end

    local handled = true
    if collectibleId == AETHERIAL_WELL_ID then
        ToggleAetherialWell()
    elseif summoned[category] then
        DismissAssistant(category, summoned[category])
    else
        handled = SummonAssistant(collectibleId, category)
    end
    if handled then
        cooldownUntil = now + QUICKSLOT_COOLDOWN_S
    end
    return handled
end

function SHT.InitializeAssistants()
    ZO_PreHook(QuickslotActionButton, "OnRelease", OnQuickslotRelease)
    -- Positions are only valid in the house they were saved in.
    EVENT_MANAGER:RegisterForEvent(SHT.ADDON_NAME .. "Assistants", EVENT_PLAYER_ACTIVATED, function()
        ZO_ClearTable(summoned)
    end)
end
