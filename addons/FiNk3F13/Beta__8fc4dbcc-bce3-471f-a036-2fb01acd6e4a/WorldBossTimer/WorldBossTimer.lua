-- Author: FiNk3--F13--
-- PS5-oriented prototype. Uses shared UI controls, no PC-only compatibility aliases.
local NAME = "WorldBossTimer"
local C = FiNk3WBTCore
local state = C.New(306)
local markers = {}
local observedTags = {}
local activeKey
local suspended = false

local function Time()
    return GetFrameTimeSeconds()
end

local function IsWorldBoss(zone, poi)
    return zone and poi and zone > 0 and poi > 0
        and GetPOIZoneCompletionType(zone, poi) == ZONE_COMPLETION_TYPE_GROUP_BOSSES
end

local function CurrentBossKey()
    local zone, poi = GetCurrentSubZonePOIIndices()
    if IsWorldBoss(zone, poi) then return C.Key(zone, poi) end
    -- Do not guess the nearest boss: that could assign a death to the wrong site.
end

local function ObserveBosses()
    if suspended then return end
    local key = CurrentBossKey()
    if key ~= activeKey then
        activeKey = key
        state.encounter = nil
        observedTags = {}
    end
    if not key then return end
    -- Boss unit tags are visible according to the client, independent of damage.
    for i = 1, 12 do
        local tag = "boss" .. i
        if DoesUnitExist(tag) then
            local name = GetUnitName(tag)
            observedTags[tag] = { key = key, name = name, lastSeen = Time() }
            C.Observe(state, key, tag, name, IsUnitDead(tag), Time())
        end
    end
    C.Finish(state)
end

local function OnDeath(_, tag, dead)
    if suspended then return end
    if not dead or not string.match(tag or "", "^boss%d+$") then return end
    local seen = observedTags[tag]
    if not seen or seen.key ~= CurrentBossKey() or Time() - seen.lastSeen > 2 then return end
    -- A cached name is used only for a previously observed boss unit.
    local name = DoesUnitExist(tag) and GetUnitName(tag) or seen.name
    if name ~= seen.name then return end
    C.Observe(state, seen.key, tag, name, true, Time())
    -- Scan the complete currently exposed boss set before evaluating completion.
    ObserveBosses()
end

local function OnCombatDeath(_, result, isError, _, _, _, _, _, targetName, targetType)
    if suspended or isError or targetType ~= COMBAT_UNIT_TYPE_OTHER then return end
    if result ~= ACTION_RESULT_DIED and result ~= ACTION_RESULT_KILLING_BLOW then return end
    local key = CurrentBossKey()
    if not key then return end
    -- The combat stream is local, not a zone scan. Only names from recently
    -- observed boss slots are accepted; no player-damage/kill-credit requirement.
    local matchedTag, matched
    for tag, seen in pairs(observedTags) do
        if seen.key == key and seen.name == targetName and Time() - seen.lastSeen <= 2 then
            if matched then return end -- Identical names are ambiguous: don't guess.
            matchedTag, matched = tag, seen
        end
    end
    if matched then
        C.Observe(state, key, matchedTag, matched.name, true, Time())
        C.Finish(state)
    end
end

local function CreateMarker(index, pinControl)
    local root = WINDOW_MANAGER:CreateControl(NAME .. "Timer" .. index, pinControl, CT_CONTROL)
    root:SetDimensions(150, 44)
    root:SetMouseEnabled(false)
    root:SetDrawTier(DT_HIGH)
    root:SetInheritScale(false)
    root:SetAnchor(BOTTOM, pinControl, TOP, 0, -5)
    local timer = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
    timer:SetFont("ZoFontGamepadBold34")
    timer:SetAnchorFill(root)
    timer:SetDrawLayer(DL_TEXT)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    local marker = { root = root, timer = timer, parent = pinControl }
    markers[index] = marker
    return marker
end

local function MapShowing()
    return SCENE_MANAGER:IsShowing("worldMap") or SCENE_MANAGER:IsShowing("gamepad_worldMap")
end

local function HideMarkers()
    for _, marker in ipairs(markers) do marker.root:SetHidden(true) end
end

local function RefreshMap()
    -- Never create a second boss icon or compute its pixel position ourselves.
    -- Native pins follow pan/zoom and are recycled when changing maps.
    if suspended or not MapShowing() then HideMarkers() return end
    local manager = ZO_WorldMap_GetPinManager()
    if not manager then HideMarkers() return end
    local used = 0
    for _, pin in pairs(manager:GetActiveObjects()) do
        if pin:IsPOI() then
            local zone, poi = pin:GetPOIZoneIndex(), pin:GetPOIIndex()
            local pinControl = pin:GetControl()
            if IsWorldBoss(zone, poi) and not pinControl:IsHidden() then
                used = used + 1
                local marker = markers[used] or CreateMarker(used, pinControl)
                if marker.parent ~= pinControl then
                    marker.root:SetParent(pinControl)
                    marker.parent = pinControl
                    marker.root:ClearAnchors()
                    marker.root:SetAnchor(BOTTOM, pinControl, TOP, 0, -5)
                end
                local text, r, g, b = C.Text(state, C.Key(zone, poi), Time())
                if text == "Zeit unbekannt" then text = "--:--" end
                if text == "Spawn erwartet?" then text = "0:00" end
                if marker.text ~= text then
                    marker.timer:SetText(text)
                    marker.timer:SetColor(r, g, b, 1)
                    marker.text = text
                end
                if marker.root:IsHidden() then marker.root:SetHidden(false) end
            end
        end
    end
    for index = used + 1, #markers do markers[index].root:SetHidden(true) end
end

local function ClearObservation()
    -- Unit tags belong to the current location; deadlines remain valid estimates
    -- for the previously observed location and continue through loading screens.
    state.encounter = nil
    observedTags = {}
    activeKey = nil
    HideMarkers()
end

local function Reset()
    C.Reset(state)
    ClearObservation()
end

local function Initialize(_, addon)
    if addon ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_UNIT_DEATH_STATE_CHANGED, OnDeath)
    EVENT_MANAGER:AddFilterForEvent(NAME, EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "boss")
    for _, result in ipairs({ ACTION_RESULT_DIED, ACTION_RESULT_KILLING_BLOW }) do
        local eventName = NAME .. "CombatDeath" .. tostring(result)
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, OnCombatDeath)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, result)
    end
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_BOSSES_CHANGED, ObserveBosses)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEACTIVATED, function()
        suspended = true
        ClearObservation()
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
        ClearObservation()
        suspended = false
    end)
    EVENT_MANAGER:RegisterForUpdate(NAME, 250, function()
        ObserveBosses()
    end)
    -- Rebind every rendered frame: pooled POI pins can change between timer ticks.
    local updater = WINDOW_MANAGER:CreateControl(NAME .. "Updater", GuiRoot, CT_CONTROL)
    updater:SetHandler("OnUpdate", RefreshMap)
    SLASH_COMMANDS["/finkwb"] = function(argument)
        local seconds = tonumber(argument)
        if seconds and seconds >= 30 and seconds <= 3600 then
            state.seconds = math.floor(seconds)
            Reset()
            d("FiNk3 WBT: Schaetzung auf " .. state.seconds .. " Sekunden gesetzt.")
        elseif argument == "reset" then
            Reset()
            d("FiNk3 WBT: Beobachtungen geloescht.")
        else
            d("FiNk3 WBT | FiNk3--F13-- | /finkwb 306: Schaetzdauer | /finkwb reset")
        end
    end
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
