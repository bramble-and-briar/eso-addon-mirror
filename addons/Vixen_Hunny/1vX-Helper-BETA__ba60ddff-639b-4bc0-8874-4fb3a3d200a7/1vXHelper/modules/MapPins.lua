-- 1vX Helper - Map pins: kite spots, safe places, choke points
-- Pins are placed at your current position (keybind / gamepad screen / slash command) and are
-- stored per map (account-wide). Each pin also stores raw world coords for the tracker.
local addon = OneVXHelper
local P = {}
addon.Pins = P

local TEXTURE = "/esoui/art/mappins/ui_worldmap_pin_customdestination.dds"

P.ORDER = { "kite", "safe", "choke" }
P.TYPES = {
    kite  = { pinName = "OneVXHelper_Pin_Kite",  label = "Kite Spot",   hex = "33FF4D", color = ZO_ColorDef:New(0.2, 1, 0.3, 1) },
    safe  = { pinName = "OneVXHelper_Pin_Safe",  label = "Safe Place",  hex = "4DB8FF", color = ZO_ColorDef:New(0.3, 0.72, 1, 1) },
    choke = { pinName = "OneVXHelper_Pin_Choke", label = "Choke Point", hex = "FF8C1A", color = ZO_ColorDef:New(1, 0.55, 0.1, 1) },
}

local layouts = {}

-- Pull the user's colors into the shared ZO_ColorDef objects. The map pin layouts
-- hold references to these same objects, so a refresh is enough to recolor them.
function P.ApplyColors()
    local colors = addon.sv.pins.colors
    for key, def in pairs(P.TYPES) do
        local c = colors[key] or addon.defaults.pins.colors[key]
        def.color:SetRGBA(c.r, c.g, c.b, c.a or 1)
        def.hex = def.color:ToHex()
    end
end

function P.ColorText(key, text)
    return string.format("|c%s%s|r", P.TYPES[key].hex, text)
end

local function S() return addon.sv.pins end

function P.IsTypeShown(key)
    return S().enabled and S()[key]
end

function P.GetMapData(mapId, create)
    local data = S().data
    if not data[mapId] and create then data[mapId] = {} end
    return data[mapId]
end

-- iterate every pin of every map: fn(entry, mapId, index)
function P.ForEach(fn)
    for mapId, list in pairs(S().data) do
        for i, entry in ipairs(list) do fn(entry, mapId, i) end
    end
end

---------------------------------------------------------------------------
-- Map pin backend: LibMapPins-1.0 if installed, otherwise the game's own
-- world map pin manager (global helpers were removed in newer game versions).
---------------------------------------------------------------------------
local registered = false

local function GetLMP()
    return LibMapPins or (LibStub and LibStub("LibMapPins-1.0", true))
end

local function GetNativeManager()
    if ZO_WorldMap_GetPinManager then return ZO_WorldMap_GetPinManager() end
    return nil
end

local Backend = {}

function Backend.Add(name, layoutFn, layoutData, tooltip)
    local LMP = GetLMP()
    if LMP and LMP.AddPinType then
        LMP:AddPinType(name, function(pinManager) layoutFn(pinManager) end, nil, layoutData, tooltip)
        return true
    end
    if ZO_WorldMap_AddCustomPin then
        ZO_WorldMap_AddCustomPin(name, layoutFn, nil, layoutData, tooltip)
        return true
    end
    local pm = GetNativeManager()
    if pm and pm.AddCustomPin then
        pm:AddCustomPin(name, layoutFn, nil, layoutData, tooltip)
        return true
    end
    return false
end

function Backend.CreatePin(pinManager, name, tag, x, y)
    local LMP = GetLMP()
    if LMP and LMP.CreatePin then
        LMP:CreatePin(name, tag, x, y)
    else
        local pm = pinManager or GetNativeManager()
        if pm then pm:CreatePin(_G[name], tag, x, y) end
    end
end

function Backend.SetEnabled(name, enabled)
    local LMP = GetLMP()
    if LMP and LMP.SetEnabled then LMP:SetEnabled(name, enabled) return end
    local pinType = _G[name]
    if not pinType then return end
    if ZO_WorldMap_SetCustomPinEnabled then
        ZO_WorldMap_SetCustomPinEnabled(pinType, enabled)
    else
        local pm = GetNativeManager()
        if pm and pm.SetCustomPinEnabled then pm:SetCustomPinEnabled(pinType, enabled) end
    end
end

function Backend.Refresh(name)
    local LMP = GetLMP()
    if LMP and LMP.RefreshPins then LMP:RefreshPins(name) return end
    local pinType = _G[name]
    if not pinType then return end
    if ZO_WorldMap_RefreshCustomPinsOfType then
        ZO_WorldMap_RefreshCustomPinsOfType(pinType)
    else
        local pm = GetNativeManager()
        if pm and pm.RefreshCustomPins then pm:RefreshCustomPins(pinType) end
    end
end

-- bumped on every pin change / toggle so the tracker knows to rebuild its cache
P.revision = 0

function P.Refresh()
    P.revision = P.revision + 1
    if addon.Blips and addon.Blips.Apply and addon.sv then pcall(addon.Blips.Apply) end
    if not registered then return end
    for _, key in ipairs(P.ORDER) do
        local name = P.TYPES[key].pinName
        layouts[key].size = S().size
        local ok, err = pcall(function()
            Backend.SetEnabled(name, P.IsTypeShown(key))
            Backend.Refresh(name)
        end)
        if not ok then addon.Print("Map pin refresh failed: " .. tostring(err)) return end
    end
end

local function LayoutPins(key, pinManager)
    if not P.IsTypeShown(key) then return end
    local mapId = GetCurrentMapId()
    local list = P.GetMapData(mapId)
    if not list then return end
    local name = P.TYPES[key].pinName
    for i, entry in ipairs(list) do
        if entry.type == key then
            Backend.CreatePin(pinManager, name, { key = key, mapId = mapId, index = i }, entry.x, entry.y)
        end
    end
end

local tooltipCreator = {
    creator = function(pin)
        local _, tag = pin:GetPinTypeAndTag()
        if type(tag) ~= "table" then return end
        local list = P.GetMapData(tag.mapId)
        local entry = list and list[tag.index]
        local def = P.TYPES[tag.key]
        if not entry or not def then return end
        local title = string.format("|c%s1vX %s|r", def.hex, def.label)
        if IsInGamepadPreferredMode() then
            local tt = ZO_MapLocationTooltip_Gamepad
            local section = tt and tt.tooltip
            if section then
                tt:LayoutIconStringLine(section, nil, zo_strformat("1vX <<1>>", def.label),
                    section:GetStyle("mapLocationTooltipContentHeader"))
                if entry.note and entry.note ~= "" then
                    tt:LayoutIconStringLine(section, nil, entry.note,
                        section:GetStyle("mapLocationTooltipContentName"))
                end
            end
        else
            InformationTooltip:AddLine(title, "ZoFontGameOutline")
            if entry.note and entry.note ~= "" then
                InformationTooltip:AddLine(entry.note, "ZoFontGame", 0.85, 0.85, 0.85)
            end
        end
    end,
    tooltip = (ZO_MAP_TOOLTIP_MODE and ZO_MAP_TOOLTIP_MODE.INFORMATION) or 1,
}

local function EnsurePlayerMap()
    if not (ZO_WorldMap_IsWorldMapShowing and ZO_WorldMap_IsWorldMapShowing()) then
        if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
            CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
        end
    end
end

function P.GetPlayerWorldPos()
    if GetUnitRawWorldPosition then
        return GetUnitRawWorldPosition("player")
    end
    return GetUnitWorldPosition("player")
end

function P.AddAtPlayer(key, note)
    local def = P.TYPES[key]
    if not def then return end
    EnsurePlayerMap()
    local x, y = GetMapPlayerPosition("player")
    local mapId = GetCurrentMapId()
    if not mapId or mapId == 0 or not x then
        addon.Print("Can't place a pin here (no map).")
        return
    end
    local zoneId, wx, wy, wz = P.GetPlayerWorldPos()
    local list = P.GetMapData(mapId, true)

    local n = 1
    for _, e in ipairs(list) do if e.type == key then n = n + 1 end end
    note = zo_strtrim(note or "")
    if note == "" then note = string.format("%s #%d", def.label, n) end

    list[#list + 1] = {
        type = key, x = x, y = y, zoneId = zoneId, wx = wx, wy = wy, wz = wz,
        note = note, t = GetTimeStamp(),
    }
    P.Refresh()
    local msg = string.format("Added |c%s%s|r on %s: %s%s", def.hex, def.label,
        zo_strformat("<<1>>", GetMapNameById(mapId)), note,
        P.IsTypeShown(key) and "" or " |c999999(pins of this type are hidden in settings)|r")
    addon.Print(msg)
    return msg
end

function P.CountCurrentMap()
    EnsurePlayerMap()
    local mapId = GetCurrentMapId()
    local list = P.GetMapData(mapId) or {}
    return #list, zo_strformat("<<1>>", GetMapNameById(mapId))
end

-- distance in meters between the player and an entry (nil if other zone)
function P.DistanceTo(entry, zoneId, px, pz)
    if entry.zoneId ~= zoneId or not entry.wx then return nil end
    local dx, dz = entry.wx - px, entry.wz - pz
    return math.sqrt(dx * dx + dz * dz) / 100, dx, dz
end

function P.RemoveNearest(maxMeters)
    maxMeters = maxMeters or 60
    local zoneId, px, _, pz = P.GetPlayerWorldPos()
    local best, bestMap, bestIdx, bestDist
    P.ForEach(function(entry, mapId, i)
        local dist = P.DistanceTo(entry, zoneId, px, pz)
        if dist and dist <= maxMeters and (not bestDist or dist < bestDist) then
            best, bestMap, bestIdx, bestDist = entry, mapId, i, dist
        end
    end)
    if not best then
        local msg = string.format("No 1vX pin within %dm.", maxMeters)
        addon.Print(msg)
        return msg
    end
    table.remove(S().data[bestMap], bestIdx)
    if #S().data[bestMap] == 0 then S().data[bestMap] = nil end
    P.Refresh()
    local msg = string.format("Removed %s (%dm away).", best.note or P.TYPES[best.type].label, zo_round(bestDist))
    addon.Print(msg)
    return msg
end

function P.ClearCurrentMap()
    EnsurePlayerMap()
    local mapId = GetCurrentMapId()
    S().data[mapId] = nil
    P.Refresh()
    addon.Print("Cleared all 1vX pins on " .. zo_strformat("<<1>>", GetMapNameById(mapId)))
end

function P.ClearAll()
    S().data = {}
    P.Refresh()
    addon.Print("Cleared all 1vX pins on every map.")
end

function P.ListCurrentMap()
    EnsurePlayerMap()
    local mapId = GetCurrentMapId()
    local list = P.GetMapData(mapId) or {}
    addon.Print(string.format("%d pin(s) on %s:", #list, zo_strformat("<<1>>", GetMapNameById(mapId))))
    for _, e in ipairs(list) do
        local def = P.TYPES[e.type]
        if def then addon.Print(string.format("  |c%s%s|r - %s", def.hex, def.label, e.note or "")) end
    end
end

function P.Apply()
    P.Refresh()
end

local function RegisterPinTypes()
    if registered then return true end
    local ok, result = pcall(function()
        for i, key in ipairs(P.ORDER) do
            local def = P.TYPES[key]
            layouts[key] = layouts[key] or { level = 160 + i, texture = TEXTURE, size = S().size, tint = def.color }
            if not Backend.Add(def.pinName, function(pinManager) LayoutPins(key, pinManager) end,
                    layouts[key], tooltipCreator) then
                return false
            end
        end
        return true
    end)
    if ok and result then
        registered = true
        P.Refresh()
        return true
    end
    if not ok then addon.Print("Couldn't register map pins: " .. tostring(result)) end
    return false
end

function P.Init()
    P.ApplyColors()
    if RegisterPinTypes() then return end
    -- world map not ready yet: try again once the player is in the world
    EVENT_MANAGER:RegisterForEvent("OneVXHelper_PinsRetry", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent("OneVXHelper_PinsRetry", EVENT_PLAYER_ACTIVATED)
        if not RegisterPinTypes() then
            addon.Print("Map pins unavailable on this game version - install LibMapPins-1.0 and /reloadui.")
        end
    end)
end
