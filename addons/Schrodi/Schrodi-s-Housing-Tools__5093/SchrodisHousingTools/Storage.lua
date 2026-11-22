-- /storage (formerly part of EssentialSnugpodTools): brings every storage chest and coffer
-- in the house in front of you, in rows of four (coffers first). Run it again to send them
-- all back to where they were.

local SHT = SchrodisHousingTools

local CHESTS =
{
    [4674] = true, -- Storage Chest, Fortified
    [4678] = true, -- Storage Chest, Oaken
    [4679] = true, -- Storage Chest, Secure
    [4680] = true, -- Storage Chest, Sturdy
}
local COFFERS =
{
    [4673] = true, -- Storage Coffer, Fortified
    [4675] = true, -- Storage Coffer, Oaken
    [4676] = true, -- Storage Coffer, Secure
    [4677] = true, -- Storage Coffer, Sturdy
}

local DISTANCE = 200
local COLUMNS = 4
local COLUMN_SPACING = 165
local ROW_SPACING = 120

-- collectibleId -> { fid, original position } while summoned
local summoned = {}

local function FindStorage()
    local found = {}
    local fid
    while true do
        local nextFid = GetNextPlacedHousingFurnitureId(fid)
        if not nextFid or nextFid == fid then break end
        fid = nextFid
        local cid = GetCollectibleIdFromFurnitureId(fid)
        if cid and (CHESTS[cid] or COFFERS[cid]) then
            found[#found + 1] = { fid = fid, cid = cid }
        end
    end
    -- Coffers in front, chests behind; stable by collectible id.
    table.sort(found, function(a, b)
        local aChest, bChest = CHESTS[a.cid] == true, CHESTS[b.cid] == true
        if aChest ~= bChest then return bChest end
        return a.cid < b.cid
    end)
    return found
end

local function SendBack()
    local count = 0
    for _, saved in pairs(summoned) do
        HousingEditorRequestChangePositionAndOrientation(saved.fid, saved.x, saved.y, saved.z, saved.pitch, saved.yaw, saved.roll)
        count = count + 1
    end
    ZO_ClearTable(summoned)
    SHT.Msg(string.format("Sending %d storage container%s back.", count, count == 1 and "" or "s"))
end

local function Summon()
    local storage = FindStorage()
    if #storage == 0 then
        SHT.Msg("No storage chests or coffers placed in this house.")
        return
    end

    local px, py, pz, pyaw = GetPlayerWorldPositionInHouse()
    local sinYaw, cosYaw = math.sin(pyaw), math.cos(pyaw)
    local placed, lastResult = 0, nil
    for i, item in ipairs(storage) do
        local x, y, z = HousingEditorGetFurnitureWorldPosition(item.fid)
        local pitch, yaw, roll = HousingEditorGetFurnitureOrientation(item.fid)

        local row = zo_floor((i - 1) / COLUMNS)
        local column = (i - 1) % COLUMNS
        local sideways = (column - (COLUMNS - 1) / 2) * COLUMN_SPACING
        local back = DISTANCE + row * ROW_SPACING
        local sx = px - sinYaw * back + cosYaw * sideways
        local sz = pz - cosYaw * back - sinYaw * sideways

        lastResult = HousingEditorRequestChangePositionAndOrientation(item.fid, sx, py, sz, 0, pyaw, 0)
        if lastResult == HOUSING_REQUEST_RESULT_SUCCESS then
            summoned[item.cid] = { fid = item.fid, x = x, y = y, z = z, pitch = pitch, yaw = yaw, roll = roll }
            placed = placed + 1
        end
    end

    if placed > 0 then
        SHT.Msg(string.format("Summoning %d storage container%s.", placed, placed == 1 and "" or "s"))
    else
        SHT.Msg("Failed to summon storage. " .. SHT.FormatHousingResult(lastResult))
    end
end

function SHT.InitializeStorage()
    SLASH_COMMANDS["/storage"] = function()
        if GetCurrentZoneHouseId() == 0 then
            SHT.Msg("You need to be in a house.")
        elseif next(summoned) then
            SendBack()
        else
            Summon()
        end
    end
    EVENT_MANAGER:RegisterForEvent(SHT.ADDON_NAME .. "Storage", EVENT_PLAYER_ACTIVATED, function()
        ZO_ClearTable(summoned)
    end)
end
