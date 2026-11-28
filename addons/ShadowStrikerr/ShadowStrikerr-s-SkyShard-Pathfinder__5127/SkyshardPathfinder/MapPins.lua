local addon = SkyshardPathfinder
local eventName = "SkyshardPathfinderMapPins"
local groups = {
    { name = "SkyshardPathfinderUncollectedPin", visibility = "showUncollected", color = "uncollectedColor", visible = false },
    { name = "SkyshardPathfinderCollectedPin", visibility = "showCollected", color = "collectedColor", visible = false, collected = true },
}
local manager
local listening = false
local styles = { ESO = true, Chevron = true, Arrowhead = true, Shard = true,
    RingedDiamond = true, BeaconCrystal = true, DelveMarker = true }

function addon.InvalidateMapTooltip()
    if manager and manager.InvalidateTooltip then manager:InvalidateTooltip() end
end

function addon.GetMapPinAppearance(settings, collected)
    if settings.mapIcon == "ESO" then
        local texture = collected and "skyshard_complete.dds" or "skyshard_seen.dds"
        return "EsoUI/Art/MapPins/" .. texture, 1, 1, 1
    end
    local color = collected and settings.collectedColor or settings.uncollectedColor
    local black = color[1] == 0 and color[2] == 0 and color[3] == 0
    local variant = black and "Uncollected" or "Collected"
    local texture = "SkyshardPathfinder/Pins/" .. settings.mapIcon .. variant .. ".dds"
    if black then return texture, 1, 1, 1 end
    return texture, unpack(color)
end

local function refreshGroup(group, settings)
    local texture, r, g, b = addon.GetMapPinAppearance(settings, group.collected)
    group.texture = texture
    group.tint = ZO_ColorDef:New(r, g, b, 1)
    group.layout.level = settings.pinLayer
    group.layout.size = settings.pinSize
    manager:RefreshCustomPins(group.id)
end

function addon.RefreshMapPins(settings, colorKey)
    if not manager or settings.arrowsOnly then return end
    for _, group in ipairs(groups) do
        if settings[group.visibility] and (not colorKey or group.color == colorKey) then
            refreshGroup(group, settings)
        end
    end
end

function addon.UpdateMapPinVisibility(settings)
    if not manager then return end
    for _, group in ipairs(groups) do
        local visible = not settings.arrowsOnly and settings[group.visibility]
        if group.visible ~= visible then
            group.visible = visible
            manager:SetCustomPinEnabled(group.id, visible)
            refreshGroup(group, settings)
        end
    end
    local shouldListen = not settings.arrowsOnly and (settings.showUncollected == true or settings.showCollected == true)
    if listening == shouldListen then return end
    listening = shouldListen
    if shouldListen then
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_SKYSHARDS_UPDATED, function()
            addon.RefreshMapPins(settings)
        end)
    else
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_SKYSHARDS_UPDATED)
    end
end

local function layoutPins(pinManager, group)
    local zoneIndex = GetCurrentMapZoneIndex()
    if not zoneIndex or zoneIndex <= 0 then return end
    local entrances = addon.GetShardEntrances(zoneIndex)
    addon.VisitZoneShards(GetZoneId(zoneIndex), function(id, collected, ordinal, zone)
        if collected ~= (group.collected == true) then return end
        local entrance = entrances[id]
        local x, y
        if entrance then
            -- Offset the marker slightly so the native delve icon remains accessible.
            local offset = entrance.x < .98 and .008 or -.008
            x, y = entrance.x + offset, entrance.y
        else
            x, y = addon.GetShardMapPosition(id)
        end
        if x then
            pinManager:CreatePin(group.id, { id = id, ordinal = ordinal, zone = zone,
                entrance = entrance, collected = collected }, x, y)
        end
    end)
end

local function getShardLocationType(zoneIndex, id)
    if not zoneIndex or zoneIndex <= 0 then return end
    for poi = 1, GetNumPOIs(zoneIndex) do
        if GetPOISkyshardId(zoneIndex, poi) == id then
            local kind = GetPOIZoneCompletionType(zoneIndex, poi)
            if kind == ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS then return "Public dungeon" end
            if kind == ZONE_COMPLETION_TYPE_DELVES then return "Delve" end
            if kind == ZONE_COMPLETION_TYPE_GROUP_DELVES then return "Group delve" end
        end
    end
end

local function getTargetTag(pin)
    local _, tag = pin:GetPinTypeAndTag()
    if type(tag) ~= "table" then return end
    if tag.id then return tag.id, tag end
    -- Map Pins stores the ESO SkyShard ID in slot four.
    if tag[1] == 3 or tag[1] == 4 then
        local id = tag[4]
        if type(id) == "number" and id > 0 then return id end
    end
end

local followAction = {
    name = "SkyShard Pathfinder - Set SkyShard target",
    show = function(pin) return getTargetTag(pin) ~= nil end,
    duplicates = function(pin, otherPin)
        return getTargetTag(pin) == getTargetTag(otherPin)
    end,
    callback = function(pin)
        local id, tag = getTargetTag(pin)
        if not id then return end
        local zoneIndex = GetCurrentMapZoneIndex()
        if tag then
            addon.FollowShard(id, tag.collected, tag.entrance, zoneIndex)
        else
            local entrance = zoneIndex and zoneIndex > 0 and addon.GetShardEntrances(zoneIndex)[id]
            local collected = GetSkyshardDiscoveryStatus(id) == SKYSHARD_DISCOVERY_STATUS_ACQUIRED
            addon.FollowShard(id, collected, entrance, zoneIndex)
        end
    end,
}

local function registerGroup(group, settings)
    group.layout = {
        level = settings.pinLayer,
        size = settings.pinSize,
        texture = function() return group.texture end,
        tint = function() return group.tint end,
    }
    manager:AddCustomPin(group.name, function(pinManager)
        layoutPins(pinManager, group)
    end, nil, group.layout, {
        tooltip = ZO_MAP_TOOLTIP_MODE.INFORMATION,
        creator = function(pin)
            local _, tag = pin:GetPinTypeAndTag()
            local tooltip = ZO_WorldMap_GetTooltipForMode(ZO_MAP_TOOLTIP_MODE.INFORMATION)
            if IsInGamepadPreferredMode() then
                tooltip:AppendSkyshardHint(tag.id)
                return
            end
            local zoneIndex = GetZoneIndex(tag.zone)
            local zoneName = zoneIndex and zoneIndex > 0 and GetZoneNameByIndex(zoneIndex)
            local title = zoneName and zoneName ~= "" and zo_strformat("<<1>> SkyShards", zoneName) or "SkyShards"
            tooltip:AddLine(title, "ZoFontGameOutline", 1, 1, 1)
            local hint = GetSkyshardHint(tag.id)
            if hint and hint ~= "" then
                tooltip:AddLine(string.format("(%d) %s", tag.ordinal, hint), "ZoFontGame", 1, 0.95, 0.8)
            end
            local status = group.collected and "Collected" or "Uncollected"
            local kind = getShardLocationType(zoneIndex, tag.id)
            tooltip:AddLine(kind and (kind .. " / " .. status) or status, "ZoFontGame", .88, .88, .88)
            if tag.entrance then
                tooltip:AddLine(tag.entrance.name or "Entrance", "ZoFontGame", .65, .87, .9)
            end
            if addon.IsFollowingShard(tag.id) then
                tooltip:AddLine("SkyShard Pathfinder - Following", "ZoFontGame", .96, .82, .47)
            else
                tooltip:AddLine("SkyShard Pathfinder - Click to set target", "ZoFontGame", .65, .87, .9)
            end
        end,
    })
    group.id = _G[group.name]
    local clickHandlers = ZO_MapPin and ZO_MapPin.PIN_CLICK_HANDLERS
    local left = clickHandlers and clickHandlers[MOUSE_BUTTON_INDEX_LEFT]
    if left then
        left[group.id] = { followAction }
    end
end

function addon.RegisterCompatiblePinClicks()
    local clickHandlers = ZO_MapPin and ZO_MapPin.PIN_CLICK_HANDLERS
    local left = clickHandlers and clickHandlers[MOUSE_BUTTON_INDEX_LEFT]
    if not left then return end
    for _, name in ipairs({ "pinType_Skyshards", "pinType_Skyshards_done" }) do
        local id = _G[name]
        if id then
            local actions = left[id] or {}
            local registered = false
            for _, action in ipairs(actions) do
                if action == followAction then registered = true end
            end
            if not registered then
                actions[#actions + 1] = followAction
                left[id] = actions
            end
        end
    end
end

function addon.RegisterMapPins(settings)
    if not styles[settings.mapIcon] then settings.mapIcon = "Shard" end
    manager = ZO_WorldMap_GetPinManager()
    if not manager then return end
    for _, group in ipairs(groups) do registerGroup(group, settings) end
    addon.UpdateMapPinVisibility(settings)
end
