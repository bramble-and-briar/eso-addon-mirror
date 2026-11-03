-- WifeyDPSPositions.lua
WifeyDPSPositions = WifeyDPSPositions or {}
local DDP = WifeyDPSPositions

function WifeyDPSPositions_TogglePanel()
    if DDP.UI and DDP.UI.Toggle then
        DDP.UI:Toggle()
    end
end

local function registerKeybinds()
    ZO_CreateStringId("SI_BINDING_NAME_WIFEYDPSPOSITIONS_PANEL_KEYBIND", "Open/Close Wifey DPS Positions")
end

local hudFragment

-- RCRT interoperability: mirror PUSHes received by RCRT become the visible
-- Wifey DPS Positions mirror board too. RCRT remains the network transport;
-- this addon only mirrors RCRT's committed vLC board into its own HUD state.
local lastRcrtMirrorSignature = nil
local function syncMirrorsFromRCRT()
    local rt = RyticTank
    local board = rt and rt.saved and rt.saved.positions and rt.saved.positions.saved
        and rt.saved.positions.saved[1478] and rt.saved.positions.saved[1478].Mirrors
    if type(board) ~= "table" then return end

    local byPosition = {}
    local sigParts = {}
    for _, row in ipairs(board) do
        local pos = tostring(row.position or "")
        local name = DDP.NormalizeName(row.name or "@Missing") or "@Missing"
        if pos ~= "" then byPosition[pos] = name end
        sigParts[#sigParts + 1] = pos .. "=" .. name
    end
    table.sort(sigParts)
    local signature = table.concat(sigParts, "|")
    if signature == lastRcrtMirrorSignature then return end
    lastRcrtMirrorSignature = signature

    local zoneData = DDP.positions and DDP.positions[1478]
    local positions = zoneData and zoneData.mechanics and zoneData.mechanics.Mirrors
    if type(positions) ~= "table" then return end

    DDP.savedAssignments = DDP.savedAssignments or {}
    DDP.savedAssignments[1478] = DDP.savedAssignments[1478] or {}
    local out = {}
    for i, pos in ipairs(positions) do
        local name = byPosition[pos] or "@Missing"
        out[i] = {name = name, position = pos, override = false}
    end
    DDP.savedAssignments[1478].Mirrors = out
    if DDP.SV then DDP.SV.savedAssignments = DDP.savedAssignments end

    if DDP.UI and DDP.UI.currentMechanic == "Mirrors" and DDP.UI.RefreshAssignments then
        DDP.UI:RefreshAssignments()
    end
end

local function hookSceneVisibility()
    if hudFragment or not DDP.UI or not DDP.UI.window then return end
    if not HUD_SCENE or not HUD_UI_SCENE then return end

    -- Keep the TopLevelControl parented to GuiRoot. The fragment controls visibility
    -- only while the panel is intentionally open, so other scenes (map, inventory,
    -- character, etc.) hide it automatically.
    hudFragment = ZO_HUDFadeSceneFragment:New(DDP.UI.window, nil, 0)
    DDP.UI.hudFragment = hudFragment
end

local function onGroupChanged(eventCode, unitTag, reason, name)
    if not DDP.UI or not DDP.UI.window or DDP.UI.window:IsHidden() then
        return
    end

    if GetGroupSize() == 0 then
        DDP.UI:ClearButtons()
        DDP.UI.panelOpen = false
        if DDP.UI.hudFragment then
            if HUD_SCENE then HUD_SCENE:RemoveFragment(DDP.UI.hudFragment) end
            if HUD_UI_SCENE then HUD_UI_SCENE:RemoveFragment(DDP.UI.hudFragment) end
        end
        DDP.UI.window:SetHidden(true)
		DDP.savedAssignments = {}
		DDP.freeAssignments = {}
		if DDP.SV then
			DDP.SV.savedAssignments = {}
			DDP.SV.freeAssignments = {}
		end
		DDP.lastMechanicShown = nil
		if DDP.ClearChatEntry then
			DDP.ClearChatEntry()
		end
        return
    end

    local currentZoneId = GetZoneId(GetUnitZoneIndex("player"))
    local zoneData = DDP.positions[currentZoneId]
    if not zoneData then return end

    if unitTag and DoesUnitExist(unitTag) then
        local role = DDP.GetUnitRole(unitTag)
        if role ~= LFG_ROLE_TANK and role ~= LFG_ROLE_HEAL and role ~= LFG_ROLE_DPS then
            return
        end
    end

    local savedZone = DDP.savedAssignments and DDP.savedAssignments[currentZoneId]
    if not savedZone then return end

    local currentMechKey
    for key in pairs(savedZone) do currentMechKey = key break end
    if not currentMechKey then return end

    local mechPositions = zoneData.mechanics[currentMechKey]
    local msg = DDP.AssignToPositions(currentZoneId, currentMechKey, mechPositions)
    DDP.UI:PopulateMechanicList()
	
    if DDP.UI and DDP.UI.freeAssignmentsVisible then
        DDP.UI:PopulateFreeAssignments(currentZoneId)
    end
end

local function onAddonLoaded(event, addonName)
    if addonName ~= "WifeyDPSPositions" then return end

    math.randomseed(GetTimeStamp())
    for _ = 1, 3 do math.random() end

    DDP.SV = ZO_SavedVars:NewAccountWide("WifeyDPSPositions_SavedVars", 2, nil, {
        version = 2,
        panelPosition = {x = 500, y = 300},
        savedAssignments = {},
		freeAssignments = {},
    })
	
	if not DDP.SV.freeAssignments then
		DDP.SV.freeAssignments = {}
	end
	
    DDP.savedAssignments = DDP.SV.savedAssignments
    -- Clear legacy assignment flags without clearing saved assignments.
    for _, zoneBoards in pairs(DDP.savedAssignments or {}) do
        if type(zoneBoards) == "table" then
            for _, slots in pairs(zoneBoards) do
                if type(slots) == "table" then
                    for _, slot in ipairs(slots) do
                        if type(slot) == "table" then slot.override = false end
                    end
                end
            end
        end
    end
	DDP.freeAssignments  = DDP.SV.freeAssignments

    if DDP.UI and DDP.UI.Create then DDP.UI:Create() end
    registerKeybinds()
    hookSceneVisibility()

    EVENT_MANAGER:RegisterForUpdate("WifeyDPSPositions_RCRTMirrorHUDSync", 250, syncMirrorsFromRCRT)

    EVENT_MANAGER:RegisterForEvent("WifeyDPSPositions_GroupJoined", EVENT_GROUP_MEMBER_JOINED, onGroupChanged)
    EVENT_MANAGER:RegisterForEvent("WifeyDPSPositions_GroupLeave", EVENT_GROUP_MEMBER_LEFT, onGroupChanged)
    EVENT_MANAGER:RegisterForEvent("WifeyDPSPositions_GroupKick", EVENT_GROUP_MEMBER_KICKED, onGroupChanged)
    EVENT_MANAGER:RegisterForEvent("WifeyDPSPositions_RoleChanged", EVENT_GROUP_MEMBER_ROLE_CHANGED, onGroupChanged)
    EVENT_MANAGER:RegisterForEvent("WifeyDPSPositions_GroupOffline", EVENT_GROUP_MEMBER_CONNECTED_STATUS, onGroupChanged)

    EVENT_MANAGER:UnregisterForEvent("WifeyDPSPositions", EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent("WifeyDPSPositions", EVENT_ADD_ON_LOADED, onAddonLoaded)
