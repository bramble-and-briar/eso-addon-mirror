local A = ChillItemShare
local pairs, ipairs, type = pairs, ipairs, type
local GetHouseId, GetOwner = GetCurrentZoneHouseId, GetCurrentHouseOwner
local GetPreview = GetCurrentHousePreviewTemplateId
local GetHouseCollectible, GetCollectibleName = GetCollectibleIdForHouse, GetCollectibleName
local NextFurniture, FurnitureLink = GetNextPlacedHousingFurnitureId, GetPlacedFurnitureLink
local FurnitureInfo = GetPlacedHousingFurnitureInfo
local GetPlacedCollectible = GetCollectibleIdFromFurnitureId
local IdToString = Id64ToString
local STYLE = LINK_STYLE_BRACKETS
local format = string.format
function A.HouseScope()
    local houseId, owner = GetHouseId(), GetOwner()
    -- Actual visited houses only: not purchase previews or another owner's copy.
    if not houseId or houseId == 0 or not owner or owner == "" or GetPreview() ~= 0 then return end
    local collectible = GetHouseCollectible(houseId)
    local name = collectible and collectible ~= 0 and GetCollectibleName(collectible) or ("House " .. houseId)
    return "house:" .. houseId .. ":" .. owner, name .. " / " .. owner
end
function A.ScanHouse()
    local key, name = A.HouseScope()
    local items, current, skipped = {}, {}, 0
    if not key then return items, current, skipped end
    local furnitureId = NextFurniture(nil)
    while furnitureId do
        local itemLink, collectibleLink = FurnitureLink(furnitureId, STYLE)
        local link = itemLink and itemLink ~= "" and itemLink or collectibleLink
        if link and link ~= "" then
            local itemName = FurnitureInfo(furnitureId)
            local uid = key .. ":" .. IdToString(furnitureId)
            local item = {uid = uid, kind = "house", houseKey = key, link = link,
                collectibleId = (not itemLink or itemLink == "") and GetPlacedCollectible(furnitureId) or nil,
                name = itemName and itemName ~= "" and itemName or "Furnishing", count = 1, source = "Placed: " .. name}
            -- Persist only plain strings/numbers; never save id64 userdata.
            items[#items+1] = item; current[uid] = item
        else skipped = skipped + 1 end
        furnitureId = NextFurniture(furnitureId)
    end
    return items, current, skipped
end
function A.SelectHouse(selected)
    local key, name = A.HouseScope()
    if not key then A.Say("Enter an actual furnished house first. Purchase previews are not supported."); return end
    if selected then
        local items, _, skipped = A.ScanHouse()
        A.SetItems(items, true, "Placed furnishings in " .. name)
        if skipped > 0 then A.Say(format("%d placed object(s) have no shareable item or collectible link and were skipped.", skipped)) end
    else
        A.Invalidate()
        for uid, record in pairs(A.saved.selected) do
            if type(record) == "table" and record.kind == "house" and record.houseKey == key then
                A.saved.selected[uid] = nil
            end
        end
        A.Update()
    end
end
