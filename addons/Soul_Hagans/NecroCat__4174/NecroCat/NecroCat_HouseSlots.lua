NecroCat = NecroCat or {}
local NC = NecroCat

local function RecordCurrentHouseCounts()
    if not NC.savedVars then return end
    if not IsOwnerOfCurrentHouse or not IsOwnerOfCurrentHouse() then return end

    local houseId = GetCurrentZoneHouseId and GetCurrentZoneHouseId() or 0
    if not houseId or houseId <= 0 then return end

    NC.savedVars.housePlacedCounts = NC.savedVars.housePlacedCounts or {}
    local counts = {}
    for limitType = 0, 3 do
        counts[limitType] = GetNumHouseFurnishingsPlaced(limitType) or 0
    end
    NC.savedVars.housePlacedCounts[houseId] = counts
    return houseId
end

local function BuildHouseSlotsText(houseId)
    if not houseId or houseId == 0 then
        return ""
    end

    local hasPlus = IsESOPlusSubscriber()
    local baseColor = hasPlus and "|c999999" or "|cffffff"
    local plusColor = hasPlus and "|cffd700" or "|c9e8744"

    local savedCounts = NC.savedVars and NC.savedVars.housePlacedCounts and NC.savedVars.housePlacedCounts[houseId]

    local lines = {}
    for limitType = 0, 3 do
        local stringId = _G["SI_HOUSINGFURNISHINGLIMITTYPE" .. limitType]
        local limitName = stringId and GetString(stringId) or tostring(limitType)
        local limitValue = GetHouseFurnishingPlacementLimit(houseId, limitType)

        local baseLimit = hasPlus and math.floor(limitValue / 2) or limitValue
        local plusLimit = hasPlus and limitValue or (limitValue * 2)

        local placed = savedCounts and savedCounts[limitType]
        if placed ~= nil then
            local placedColor = (placed > limitValue) and "|cff4444" or "|cffffff"
            lines[#lines + 1] = string.format(
                "%s: %s%d|r |cffffff/|r %s%d|r %s(%d)|r",
                limitName, placedColor, placed, baseColor, baseLimit, plusColor, plusLimit
            )
        else
            lines[#lines + 1] = string.format(
                "%s: %s%d|r %s(%d)|r",
                limitName, baseColor, baseLimit, plusColor, plusLimit
            )
        end
    end

    return table.concat(lines, "\n")
end

local function UpdateHouseSlotsLabel()
    local label = NC.HouseSlotsLabel
    local refLabel = HOUSING_BOOK_KEYBOARD and HOUSING_BOOK_KEYBOARD.supportsWeatherControlLabel
    if not label or not refLabel then
        return
    end

    -- Копируем стиль каждый раз, чтобы подхватить изменения от Perfect Pixel
    label:SetFont(refLabel:GetFont())
    label:SetColor(refLabel:GetColor())
    label:SetWidth(refLabel:GetWidth())

    local selectedId = HOUSING_BOOK_KEYBOARD.selectedId
    if not selectedId then
        label:SetText("")
        return
    end

    local houseId = GetCollectibleReferenceId(selectedId)
    RecordCurrentHouseCounts()
    label:SetText(BuildHouseSlotsText(houseId))
end

local function SetupHouseSlotsHook()
    if NC.houseSlotsHooked then
        return
    end
    NC.houseSlotsHooked = true

    local refLabel = HOUSING_BOOK_KEYBOARD.supportsWeatherControlLabel
    local hintLabel = HOUSING_BOOK_KEYBOARD.hintLabel
    if not refLabel then
        return
    end

    local parent = refLabel:GetParent()
    local label = WINDOW_MANAGER:CreateControl("NecroCat_HouseSlotsLabel", parent, CT_LABEL)
    label:SetAnchor(TOPLEFT, refLabel, BOTTOMLEFT, 0, 5)
    NC.HouseSlotsLabel = label

    if hintLabel then
        local hasSecondAnchor, p2, r2, rp2, x2, y2 = hintLabel:GetAnchor(1)
        hintLabel:ClearAnchors()
        hintLabel:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, 5)
        if hasSecondAnchor then
            hintLabel:SetAnchor(p2, r2, rp2, x2, y2)
        end
    end

    ZO_PostHook(HOUSING_BOOK_KEYBOARD, "RefreshDetails", UpdateHouseSlotsLabel)
    UpdateHouseSlotsLabel()
end

local function OnHouseStateChanged()
    local recordedHouseId = RecordCurrentHouseCounts()
    if recordedHouseId and NC.HouseSlotsLabel and HOUSING_BOOK_KEYBOARD and HOUSING_BOOK_KEYBOARD.selectedId then
        if GetCollectibleReferenceId(HOUSING_BOOK_KEYBOARD.selectedId) == recordedHouseId then
            UpdateHouseSlotsLabel()
        end
    end
end

local function OnFurnitureChanged()
    zo_callLater(OnHouseStateChanged, 100)
end

function NC.InitHouseSlotsInfo()
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_HouseSlots_Act", EVENT_PLAYER_ACTIVATED, OnHouseStateChanged)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_HouseSlots_Placed", EVENT_HOUSING_FURNITURE_PLACED, OnFurnitureChanged)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_HouseSlots_Removed", EVENT_HOUSING_FURNITURE_REMOVED, OnFurnitureChanged)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_HouseSlots_Editor", EVENT_HOUSING_EDITOR_MODE_CHANGED, OnHouseStateChanged)

    if not HOUSING_BOOK_KEYBOARD then
        return
    end

    if HOUSING_BOOK_KEYBOARD.initialized then
        SetupHouseSlotsHook()
    else
        ZO_PostHook(HOUSING_BOOK_KEYBOARD, "OnDeferredInitialize", SetupHouseSlotsHook)
    end
end