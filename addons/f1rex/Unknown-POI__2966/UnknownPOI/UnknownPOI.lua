local UnknownPOI = {}

UnknownPOI.name = 'UnknownPOI'

UnknownPOI.pinTypeName = 'Unknown POI'

function UnknownPOI.Updated(...)
    LibMapPins:RefreshPins(UnknownPOI.pinTypeName)
end

function UnknownPOI.Callback(...)
    if not IsPlayerActivated() then
        return
    end

    local zoneIndex = GetCurrentMapZoneIndex()

    for i = 1, GetNumPOIs(zoneIndex) do
        local x, y, _, texture, _, _, known, nearby = GetPOIMapInfo(zoneIndex, i)
        local tag = { texture = texture }

        if not known and not nearby then
            LibMapPins:CreatePin(UnknownPOI.pinTypeName, tag, x, y, nil)
        end
    end
end

function UnknownPOI.Texture(pin)
    local _, pin_tag = pin:GetPinTypeAndTag()

    return pin_tag.texture
end

function UnknownPOI.Initialize(arg1, addOnName)
    if addOnName ~= UnknownPOI.name then
        return
    end

    local layoutData = { level = 40, size = 40, texture = UnknownPOI.Texture, tint = ZO_ColorDef:New(1, 1, 1, 0.5) }

    LibMapPins:AddPinType(UnknownPOI.pinTypeName, UnknownPOI.Callback, nil, layoutData, nil)
    LibMapPins:AddPinFilter(UnknownPOI.pinTypeName, nil, nil, nil, nil, nil, nil)

    EVENT_MANAGER:RegisterForEvent(UnknownPOI.name, EVENT_POI_UPDATED, UnknownPOI.Updated)
end

EVENT_MANAGER:RegisterForEvent(UnknownPOI.name, EVENT_ADD_ON_LOADED, UnknownPOI.Initialize)
