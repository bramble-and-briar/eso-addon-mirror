-- Radiant Range
-- Approved non-animated DDS retained; settings are per character and per megaserver.

local ADDON_NAME = "RadiantRange"
local SAVED_VARS_NAME = "RadiantRangeSavedVariables"
local SAVED_VARS_VERSION = 1

local UPDATE_NAME = ADDON_NAME .. "PositionUpdate"
local PLAYER_EVENT = ADDON_NAME .. "PlayerActivated"
local COMBAT_EVENT = ADDON_NAME .. "CombatState"
local UPDATE_MS = 33
local HEIGHT_OFFSET_CM = 8
local GLOW_TEXTURE = "RadiantRange/RadiantRangeCircle.dds"
local GROUP_HEARTBEAT_NAME = ADDON_NAME .. "GroupHeartbeat"
local GROUP_HEARTBEAT_MS = 30000
local STARTUP_RETRY_NAME = ADDON_NAME .. "StartupRetry"

local DEFAULTS = {
    enabled = true,
    radius = 12,
    color = { 0.62, 0.48, 1.00 },
    intensity = 0.85,
    showWhen = "Always",
    shareMyRange = true,
    showGroupRanges = true,
}

local SHOW_CHOICES = { "Always", "In Combat Only", "Out of Combat Only" }

local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local LAM = LibAddonMenu2
local WorldToRender = WorldPositionToGuiRender3DPosition
local GetRawWorldPosition = GetUnitRawWorldPosition
local rad = math.rad

-- Forward declaration: used by combat/runtime callbacks defined before group sharing setup.
local sendGroupState

local PGT = {
    root = nil,
    glow = nil,
    fragment = nil,
    sv = nil,
    inCombat = false,
    groupProtocol = nil,
    groupGlows = {},
    groupData = {},
}

local function copyDefaultsIntoSavedVars()
    PGT.sv.enabled = DEFAULTS.enabled
    PGT.sv.radius = DEFAULTS.radius
    PGT.sv.color = { DEFAULTS.color[1], DEFAULTS.color[2], DEFAULTS.color[3] }
    PGT.sv.intensity = DEFAULTS.intensity
    PGT.sv.showWhen = DEFAULTS.showWhen
    PGT.sv.shareMyRange = DEFAULTS.shareMyRange
    PGT.sv.showGroupRanges = DEFAULTS.showGroupRanges
end

local function shouldShow()
    if not PGT.sv or not PGT.sv.enabled then
        return false
    end

    if PGT.sv.showWhen == "In Combat Only" then
        return PGT.inCombat
    elseif PGT.sv.showWhen == "Out of Combat Only" then
        return not PGT.inCombat
    end

    return true
end

local function stopUpdates()
    EM:UnregisterForUpdate(UPDATE_NAME)
end

local function updatePosition()
    local glow = PGT.glow
    if not glow or not shouldShow() then
        if glow then glow:SetHidden(true) end
        return
    end

    local zoneId, worldX, worldY, worldZ = GetRawWorldPosition("player")
    if not zoneId or zoneId == 0 or not worldX then
        glow:SetHidden(true)
        return
    end

    local renderX, renderY, renderZ = WorldToRender(worldX, worldY + HEIGHT_OFFSET_CM, worldZ)
    if renderX == nil then
        glow:SetHidden(true)
        return
    end

    glow:Set3DRenderSpaceOrigin(renderX, renderY, renderZ)
    glow:SetHidden(false)
end

local function startUpdates()
    stopUpdates()

    if not shouldShow() then
        if PGT.glow then PGT.glow:SetHidden(true) end
        return
    end

    updatePosition()
    EM:RegisterForUpdate(UPDATE_NAME, UPDATE_MS, updatePosition)
end

local function updateCombatRegistration()
    EM:UnregisterForEvent(COMBAT_EVENT, EVENT_PLAYER_COMBAT_STATE)

    if not PGT.sv or not PGT.sv.enabled or PGT.sv.showWhen == "Always" then
        return
    end

    EM:RegisterForEvent(COMBAT_EVENT, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        PGT.inCombat = inCombat == true
        startUpdates()
        sendGroupState()
    end)
end

local function applyVisualSettings()
    local glow = PGT.glow
    if not glow or not PGT.sv then return end

    local diameter = PGT.sv.radius * 2
    glow:Set3DLocalDimensions(diameter, diameter)

    local color = PGT.sv.color
    glow:SetColor(color[1], color[2], color[3], 1)
    glow:SetAlpha(PGT.sv.intensity)
end

local function refreshRuntime()
    applyVisualSettings()
    updateCombatRegistration()
    startUpdates()
end

local function createGlow()
    if PGT.root then return end

    local root = WM:CreateTopLevelWindow("RadiantRangeRoot")
    root:SetAnchorFill(GuiRoot)
    root:SetMouseEnabled(false)
    root:SetMovable(false)

    local glow = WM:CreateControl("RadiantRangeGlow", root, CT_TEXTURE)
    glow:Create3DRenderSpace()
    glow:Set3DRenderSpaceSystem(GUI_RENDER_3D_SPACE_SYSTEM_WORLD)
    glow:Set3DRenderSpaceUsesDepthBuffer(true)
    glow:SetTexture(GLOW_TEXTURE)
    -- Sample slightly inside the DDS edge to reduce border bleed.
    glow:SetTextureCoords(0.001, 0.999, 0.001, 0.999)
    glow:SetTextureReleaseOption(RELEASE_TEXTURE_AT_ZERO_REFERENCES)

    -- Verified working ground-plane orientation. Do not change.
    glow:Set3DRenderSpaceOrientation(rad(90), 0, 0)
    glow:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    glow:SetHidden(true)

    PGT.root = root
    PGT.glow = glow
end

local function setupHudFragment()
    if PGT.fragment or not PGT.root then return end
    if not SCENE_MANAGER or not HUD_SCENE or not HUD_UI_SCENE then return end

    -- Scene objects are intentionally touched only after player activation.
    local fragment = ZO_SimpleSceneFragment:New(PGT.root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    PGT.fragment = fragment
end


-- Group sharing.
-- Uses LibGroupBroadcast only for grouped players who also run Radiant Range.
-- Protocol ID 190 and handler RadiantRangeSharing are the registered Radiant Range identities.

local function hideAllGroupGlows()
    for _, glow in pairs(PGT.groupGlows) do
        glow:SetHidden(true)
    end
end

local function getGroupGlow(unitTag)
    local glow = PGT.groupGlows[unitTag]
    if glow then return glow end
    if not PGT.root then return nil end

    local safeTag = string.gsub(unitTag or "unknown", "[^%w]", "")
    glow = WM:CreateControl("RadiantRangeGroupGlow" .. safeTag, PGT.root, CT_TEXTURE)
    glow:Create3DRenderSpace()
    glow:Set3DRenderSpaceSystem(GUI_RENDER_3D_SPACE_SYSTEM_WORLD)
    glow:Set3DRenderSpaceUsesDepthBuffer(true)
    glow:SetTexture(GLOW_TEXTURE)
    -- Sample slightly inside the DDS edge to reduce border bleed.
    glow:SetTextureCoords(0.001, 0.999, 0.001, 0.999)
    glow:SetTextureReleaseOption(RELEASE_TEXTURE_AT_ZERO_REFERENCES)
    -- Same verified ground-plane orientation as the player's own circle.
    glow:Set3DRenderSpaceOrientation(rad(90), 0, 0)
    glow:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    glow:SetHidden(true)

    PGT.groupGlows[unitTag] = glow
    return glow
end

local function applyGroupVisual(unitTag, data)
    local glow = getGroupGlow(unitTag)
    if not glow or not data then return end

    local radius = zo_clamp(tonumber(data.radius) or 12, 1, 30)
    glow:Set3DLocalDimensions(radius * 2, radius * 2)

    local r = zo_clamp((tonumber(data.red) or 62) / 100, 0, 1)
    local g = zo_clamp((tonumber(data.green) or 48) / 100, 0, 1)
    local b = zo_clamp((tonumber(data.blue) or 100) / 100, 0, 1)
    glow:SetColor(r, g, b, 1)
    glow:SetAlpha(zo_clamp((tonumber(data.intensity) or 85) / 100, 0.10, 1))
end

local function updateGroupPositions()
    if not PGT.sv or not PGT.sv.enabled or not PGT.sv.showGroupRanges or not IsUnitGrouped("player") then
        hideAllGroupGlows()
        return
    end

    for unitTag, data in pairs(PGT.groupData) do
        local glow = PGT.groupGlows[unitTag]
        if not DoesUnitExist(unitTag) or not data.visible then
            if glow then glow:SetHidden(true) end
        else
            local zoneId, worldX, worldY, worldZ = GetRawWorldPosition(unitTag)
            if not zoneId or zoneId == 0 or not worldX then
                if glow then glow:SetHidden(true) end
            else
                local renderX, renderY, renderZ = WorldToRender(worldX, worldY + HEIGHT_OFFSET_CM, worldZ)
                if renderX == nil then
                    if glow then glow:SetHidden(true) end
                else
                    glow = glow or getGroupGlow(unitTag)
                    applyGroupVisual(unitTag, data)
                    glow:Set3DRenderSpaceOrigin(renderX, renderY, renderZ)
                    glow:SetHidden(false)
                end
            end
        end
    end
end

sendGroupState = function(syncRequest, forceHidden)
    if not PGT.groupProtocol or not PGT.sv or not PGT.sv.shareMyRange or not IsUnitGrouped("player") then
        return
    end

    -- Master OFF is a true kill switch. Allow only one forced hidden packet
    -- when switching OFF so peers can immediately remove our old circle.
    if not PGT.sv.enabled and not forceHidden then
        return
    end

    local c = PGT.sv.color
    PGT.groupProtocol:Send({
        radius = zo_clamp(zo_round(PGT.sv.radius), 1, 30),
        red = zo_clamp(zo_round(c[1] * 100), 0, 100),
        green = zo_clamp(zo_round(c[2] * 100), 0, 100),
        blue = zo_clamp(zo_round(c[3] * 100), 0, 100),
        intensity = zo_clamp(zo_round(PGT.sv.intensity * 100), 10, 100),
        visible = forceHidden and false or shouldShow(),
        syncRequest = syncRequest == true,
    })
end

local function setupGroupSharing()
    local LGB = LibGroupBroadcast
    if not LGB then
        d("|cFF5555Radiant Range: LibGroupBroadcast is required for Group Sharing.|r")
        return
    end

    local handler = LGB:RegisterHandler(ADDON_NAME, "RadiantRangeSharing")
    if not handler then
        d("|cFF5555Radiant Range: Group Sharing could not register with LibGroupBroadcast.|r")
        return
    end

    local protocol = handler:DeclareProtocol(190, "RadiantRangeGroupState")
    protocol:AddField(LGB.CreateNumericField("radius", { minValue = 1, maxValue = 30 }))
    protocol:AddField(LGB.CreateNumericField("red", { minValue = 0, maxValue = 100 }))
    protocol:AddField(LGB.CreateNumericField("green", { minValue = 0, maxValue = 100 }))
    protocol:AddField(LGB.CreateNumericField("blue", { minValue = 0, maxValue = 100 }))
    protocol:AddField(LGB.CreateNumericField("intensity", { minValue = 10, maxValue = 100 }))
    protocol:AddField(LGB.CreateFlagField("visible"))
    protocol:AddField(LGB.CreateFlagField("syncRequest"))

    protocol:OnData(function(unitTag, data)
        if not unitTag or unitTag == "player" then return end
        -- Master OFF ignores incoming RR sharing completely.
        if not PGT.sv or not PGT.sv.enabled then return end
        PGT.groupData[unitTag] = data
        applyGroupVisual(unitTag, data)
        updateGroupPositions()

        -- "REMEMBER ME" handshake:
        -- a freshly activated/reloaded RR client requests current state;
        -- peers answer once with a normal state packet, preventing ping-pong.
        if data.syncRequest then
            zo_callLater(function()
                sendGroupState(false)
            end, 250)
        end
    end)

    protocol:Finalize({
        isRelevantInCombat = true,
        replaceQueuedMessages = true,
    })

    PGT.groupProtocol = protocol

    -- Position updates are local only. Never erase valid received group state
    -- just because ESO fires EVENT_GROUP_UPDATE.
    EM:RegisterForUpdate(ADDON_NAME .. "GroupPositionUpdate", UPDATE_MS, updateGroupPositions)

    EM:RegisterForEvent(ADDON_NAME .. "GroupUpdate", EVENT_GROUP_UPDATE, function()
        if IsUnitGrouped("player") then
            zo_callLater(function()
                sendGroupState(true)
            end, 500)
        else
            -- We only clear everything when WE are no longer grouped.
            PGT.groupData = {}
            hideAllGroupGlows()
        end
    end)

    -- Quiet safety rebroadcast. This is state only; no position is transmitted.
    EM:UnregisterForUpdate(GROUP_HEARTBEAT_NAME)
    EM:RegisterForUpdate(GROUP_HEARTBEAT_NAME, GROUP_HEARTBEAT_MS, function()
        sendGroupState(false)
    end)
end

local function createSettings()
    local panelData = {
        type = "panel",
        name = "Radiant Range |t22:22:RadiantRange/star.dds|t",
        displayName = "Radiant Range |t22:22:RadiantRange/star.dds|t",
        author = "WifeyRytic",
        version = "1.0.3",
        registerForRefresh = true,
        registerForDefaults = false,
    }

    local panel = LAM:RegisterAddonPanel(ADDON_NAME .. "Options", panelData)

    local options = {
        {
            type = "checkbox",
            name = "Enable Radiant Range",
            tooltip = "Turns the floor circle on or off for this character.",
            getFunc = function() return PGT.sv.enabled end,
            setFunc = function(value)
                if value then
                    PGT.sv.enabled = true
                    refreshRuntime()
                    -- Restore the saved sharing choices and request fresh peer state.
                    sendGroupState(true)
                else
                    PGT.sv.enabled = false
                    refreshRuntime()
                    hideAllGroupGlows()
                    PGT.groupData = {}
                    -- One final hidden state removes our circle from peers; after this,
                    -- master OFF prevents all normal RR broadcasts and receives.
                    sendGroupState(false, true)
                end
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Radius",
            tooltip = "Distance in meters from you to the outer glowing edge.",
            min = 1,
            max = 30,
            step = 1,
            getFunc = function() return PGT.sv.radius end,
            setFunc = function(value)
                PGT.sv.radius = value
                applyVisualSettings()
                sendGroupState()
            end,
            width = "full",
        },
        {
            type = "description",
            text = "The selected radius is the distance from you to the outer glowing edge. 12m means a 12-meter radius, not a 12-meter-wide circle.",
            width = "full",
        },
        {
            type = "colorpicker",
            name = "Color",
            tooltip = "Choose the circle color for this character.",
            getFunc = function()
                local c = PGT.sv.color
                return c[1], c[2], c[3], 1
            end,
            setFunc = function(r, g, b)
                PGT.sv.color = { r, g, b }
                applyVisualSettings()
                sendGroupState()
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Brightness / Intensity",
            tooltip = "Makes the approved glow duller or brighter without changing its design.",
            min = 10,
            max = 100,
            step = 5,
            getFunc = function() return zo_round(PGT.sv.intensity * 100) end,
            setFunc = function(value)
                PGT.sv.intensity = value / 100
                applyVisualSettings()
                sendGroupState()
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Show When",
            tooltip = "Choose when this character's circle should be visible.",
            choices = SHOW_CHOICES,
            getFunc = function() return PGT.sv.showWhen end,
            setFunc = function(value)
                PGT.sv.showWhen = value
                updateCombatRegistration()
                startUpdates()
                sendGroupState()
            end,
            width = "full",
        },
        {
            type = "header",
            name = "GROUP SHARING",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Share My Radiant Range",
            tooltip = "Allows group members who also have Radiant Range installed to see your circle.",
            getFunc = function() return PGT.sv.shareMyRange end,
            setFunc = function(value)
                PGT.sv.shareMyRange = value
                if value then
                    sendGroupState()
                end
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show Group Radiant Ranges",
            tooltip = "Shows circles from group members who also have Radiant Range installed and have sharing enabled.",
            getFunc = function() return PGT.sv.showGroupRanges end,
            setFunc = function(value)
                PGT.sv.showGroupRanges = value
                if not value then
                    hideAllGroupGlows()
                else
                    updateGroupPositions()
                end
            end,
            width = "full",
        },
        {
            type = "description",
            text = "Both players must have Radiant Range installed for sharing to work.",
            width = "full",
        },
        {
            type = "button",
            name = "Reset This Character",
            tooltip = "Restores only this character to the default 12m purple circle and default brightness.",
            func = function()
                copyDefaultsIntoSavedVars()
                refreshRuntime()
                sendGroupState()
                CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
            end,
            width = "half",
        },
    }

    LAM:RegisterOptionControls(ADDON_NAME .. "Options", options)
end

local function onPlayerActivated()
    setupHudFragment()
    PGT.inCombat = IsUnitInCombat("player")
    refreshRuntime()

    -- Retry local runtime after the world/HUD has settled. This is intentionally
    -- local-only startup insurance for fresh login/reload timing.
    EM:UnregisterForUpdate(STARTUP_RETRY_NAME)
    zo_callLater(function()
        PGT.inCombat = IsUnitInCombat("player")
        refreshRuntime()
    end, 750)

    -- Announce/recover automatically after login, reload, or zoning.
    zo_callLater(function()
        sendGroupState(true)
    end, 1000)
end

local function onAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- CharacterID settings, separated by megaserver so NA/EU/PTS do not overwrite each other.
    PGT.sv = ZO_SavedVars:NewCharacterIdSettings(
        SAVED_VARS_NAME,
        SAVED_VARS_VERSION,
        GetWorldName(),
        DEFAULTS
    )

    createGlow()
    applyVisualSettings()
    createSettings()
    setupGroupSharing()

    EM:RegisterForEvent(PLAYER_EVENT, EVENT_PLAYER_ACTIVATED, onPlayerActivated)
end

EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onAddonLoaded)
