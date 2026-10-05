CompanionRoster = CompanionRoster or {}
local CompanionRoster = CompanionRoster -- local reference, faster than repeated _G lookups

-- Shows each companion's Role tag (Tank/Healer/DPS) as a small icon, and
-- their current rapport as a number under the portrait, on their tile in the
-- Collections screen. Keyboard/mouse UI only - the gamepad UI lists
-- collectibles as rows, not tiles, and isn't touched.
--
-- Every collectible tile (not just companions) is filled in by
-- ZO_CollectibleTile_Keyboard:LayoutPlatform, and tiles are pooled and
-- reused as the list scrolls or the category changes, so the hook has to
-- hide the icon on any tile that isn't showing a tagged companion rather
-- than only ever showing it.

local ROLE_ICON_SIZE = 24
-- Anchored to the tile's own portrait icon (not the tile corner) so it sits
-- at the portrait's lower right, beside the figure's foot. Negative X pulls
-- it back inside the portrait's right edge, since the figure itself is
-- narrower than its square.
local ROLE_ICON_OFFSET_X = -12
local ROLE_ICON_OFFSET_Y = -2

local function GetCompanionIdForCollectible(collectibleId)
    for _, companion in ipairs(CompanionRoster.Data.GetAllCompanions()) do
        if GetCompanionCollectibleId(companion.id) == collectibleId then
            return companion.id
        end
    end
    return nil
end

local function GetOrCreateRoleIcon(tile)
    if tile.companionRosterRoleIcon == nil then
        local tileControl = tile:GetControl()
        local icon = CreateControl(tileControl:GetName() .. "CompanionRosterRole", tileControl, CT_TEXTURE)
        icon:SetDimensions(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
        icon:SetAnchor(BOTTOMLEFT, tile:GetIconTexture(), BOTTOMRIGHT, ROLE_ICON_OFFSET_X, ROLE_ICON_OFFSET_Y)
        icon:SetDrawLevel(5)
        tile.companionRosterRoleIcon = icon
    end
    return tile.companionRosterRoleIcon
end

-- Same colors as the roster window's Rapport column: green once maxed,
-- orange while still in progress.
local RAPPORT_COLOR_MAXED = { 0.4, 1, 0.4, 1 }
local RAPPORT_COLOR_IN_PROGRESS = { 1, 0.8, 0.4, 1 }
local RAPPORT_OFFSET_Y = 0 -- below the portrait, above the name label

local function GetOrCreateRapportLabel(tile)
    if tile.companionRosterRapportLabel == nil then
        local tileControl = tile:GetControl()
        local label = CreateControl(tileControl:GetName() .. "CompanionRosterRapport", tileControl, CT_LABEL)
        label:SetFont("ZoFontWinH5")
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetAnchor(TOP, tile:GetIconTexture(), BOTTOM, 0, RAPPORT_OFFSET_Y)
        tile.companionRosterRapportLabel = label
    end
    return tile.companionRosterRapportLabel
end

-- The current character's last recorded rapport for this companion, or nil
-- if none has been captured yet (rapport is only readable while a companion
-- is summoned, so it can legitimately be missing).
local function GetRecordedRapport(companionId)
    local recorded = CompanionRoster.Data.GetCompanionsForCharacter(CompanionRoster.Data.GetCurrentCharacterName())[companionId]
    if recorded == nil or recorded.rapportValue == nil then
        return nil
    end
    return recorded.rapportValue, recorded.rapportMax
end

local function OnTileLayout(tile)
    local collectibleData = tile.collectibleData
    local companionId = nil
    if collectibleData and collectibleData:IsCategoryType(COLLECTIBLE_CATEGORY_TYPE_COMPANION) then
        companionId = GetCompanionIdForCollectible(collectibleData:GetId())
    end

    local role = companionId and CompanionRoster.Data.GetShowRoleOnCollections() and CompanionRoster.Data.GetCompanionRole(companionId)
    if role then
        local icon = GetOrCreateRoleIcon(tile)
        icon:SetTexture(ZO_GetRoleIcon(role))
        icon:SetHidden(false)
    elseif tile.companionRosterRoleIcon then
        tile.companionRosterRoleIcon:SetHidden(true)
    end

    local rapportValue, rapportMax
    if companionId and CompanionRoster.Data.GetShowRapportOnCollections() then
        rapportValue, rapportMax = GetRecordedRapport(companionId)
    end
    if rapportValue then
        local label = GetOrCreateRapportLabel(tile)
        label:SetText(tostring(rapportValue))
        label:SetColor(unpack((rapportMax and rapportValue >= rapportMax) and RAPPORT_COLOR_MAXED or RAPPORT_COLOR_IN_PROGRESS))
        label:SetHidden(false)
    elseif tile.companionRosterRapportLabel then
        tile.companionRosterRapportLabel:SetHidden(true)
    end
end

SecurePostHook(ZO_CollectibleTile_Keyboard, "LayoutPlatform", OnTileLayout)
