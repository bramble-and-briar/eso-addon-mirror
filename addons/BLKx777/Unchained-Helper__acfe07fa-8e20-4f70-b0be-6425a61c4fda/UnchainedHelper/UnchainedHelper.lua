UnchainedHelper = UnchainedHelper or { }
local UnchainedHelper = UnchainedHelper

UnchainedHelper.name		= "UnchainedHelper"
UnchainedHelper.version = "1.0.11"
UnchainedHelper.varVersion 	= "9"

UnchainedHelper.defaults	= {
	["enabled"] = true,
    ["previewOnEntry"] = false,
    ["blockBlackroseSigils"] = false,
    ["sigilBlockNotice"] = true,
    ["showProgressCallouts"] = true,
    ["showSpawnCallout"] = true,
    ["spawnCalloutDuration"] = 4,
    ["spawnCalloutScale"] = 100,
    ["spawnCalloutOffsetX"] = 0,
    ["spawnCalloutOffsetY"] = -150,
    ["showTotemAlert"] = true,
    ["totemAlertDuration"] = 3,
    ["totemAbilityId"] = 0,
    ["showTotemSmartTimer"] = true,
	["showRaisedMarkers"] = true,
    ["showCardinalMarkers"] = false,
	["markerSize"] = 175,
	["markerHeight"] = 280,
	["showMarkerLegend"] = false,
	["legendOnlyActive"] = true,
	["legendHideWhenNoMarkers"] = true,
	["legendScale"] = 80,
	["legendOffsetX"] = 1640,
	["legendOffsetY"] = 460,
	["legendBackgroundAlpha"] = 72,
	["showPriorityMarkers"] = true,
	["showInterruptMarkers"] = true,
	["showDangerMarkers"] = true,
	["wavesInChat"]	= false,
	["hintsInChatArena1"] = false,
	["hintsInChatArena2"] = false,
	["hintsInChatArena3"] = false,
	["hintsInChatArena4"] = false,
	["hintsInChatArena5"] = false,
	["tankHints"] = false,
	["healerHints"] = false,
	["dpsHints"] = false,
	["tankPosition"] = true,
	["dpsPosition"] = true,
	["nonchainAddsPosition"] = true,
	["chainAddsPosition"] = true,
	["miniPosition"] = true,
	["bossPosition"] = true,
	["removeMarkerSeconds"] = 8,
	["nextMarkerSeconds"] = 15,
	["displayPurge"] = true,
	["offsetX"]	= 1500,
	["offsetY"]	= 350,
	["soundEffectPurge"] = "Duel_Boundary_Warning",
    ["wardenPortals"] = false,
    ["spawnNumbers"] = false,

    ["bossColor"] = "red",
    ["nochainColor"] = "green",
    ["chainColor"] = "blue",
    ["wardenPortalColor"] = "white",
    ["highDps332"] = true,
}



UnchainedHelper.inCombat = false

UnchainedHelper.currentPurgeable=0 -- how many people need purges

UnchainedHelper.eraseIconTime = 0
UnchainedHelper.icon1 = nil
UnchainedHelper.icon2 = nil
UnchainedHelper.icon3 = nil
UnchainedHelper.icon4 = nil
UnchainedHelper.icon5 = nil
UnchainedHelper.icon6 = nil
UnchainedHelper.icon7 = nil
UnchainedHelper.icon8 = nil
UnchainedHelper.icon9 = nil
UnchainedHelper.icon10 = nil
UnchainedHelper.activeIcons = {}
UnchainedHelper.activeMarkerRequests = {}
UnchainedHelper.replayingMarkers = false

UnchainedHelper.currentRound = 0
UnchainedHelper.currentWave = 0

UnchainedHelper.lastPortalSpawn = 0
UnchainedHelper.lastTotemAlert = 0
UnchainedHelper.totemAlertHideAt = 0
UnchainedHelper.totemFirstSpawnAt = 0
UnchainedHelper.totemLastSpawnAt = 0
UnchainedHelper.totemLearnedInterval = 0
UnchainedHelper.totemNextPredictedAt = 0
UnchainedHelper.totemSpawnCount = 0
UnchainedHelper.totemLastTimerText = nil
UnchainedHelper.cardinalMarkers = {}
UnchainedHelper.cardinalStage = 0


UnchainedHelper.drawNextFightIconTime = 0
UnchainedHelper.nextStage = 0
UnchainedHelper.nextRound = 0
UnchainedHelper.nextWave = 0


function UnchainedHelper.savePos()
	UnchainedHelper.savedVars.offsetX = UnchainedHelperFrame:GetLeft()
	UnchainedHelper.savedVars.offsetY = UnchainedHelperFrame:GetTop()
end

function UnchainedHelper.setPos()
	local x, y = UnchainedHelper.savedVars.offsetX, UnchainedHelper.savedVars.offsetY
	UnchainedHelperFrame:ClearAnchors()
	UnchainedHelperFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

local UH_LEGEND_ORDER = { "priority", "interrupt", "tank", "group", "danger" }
local UH_LEGEND_INFO = {
    priority = { texture = "UnchainedHelper/icons/raised_priority.dds", label = "Priority Kill" },
    interrupt = { texture = "UnchainedHelper/icons/raised_interrupt.dds", label = "Interrupt" },
    tank = { texture = "UnchainedHelper/icons/raised_tank.dds", label = "Tank Position" },
    group = { texture = "UnchainedHelper/icons/raised_group.dds", label = "Stack Point" },
    danger = { texture = "UnchainedHelper/icons/raised_danger.dds", label = "Dangerous Add" },
}

function UnchainedHelper.GetLegendCategory(markerType, portal)
    if markerType == "group" then
        return "group"
    elseif markerType == "tank" then
        return "tank"
    elseif markerType == "chain" or portal == true then
        return "interrupt"
    elseif markerType == "boss" or markerType == "elite" then
        return "priority"
    elseif markerType == "nochain" then
        return "danger"
    end
    return nil
end

function UnchainedHelper.UpdateLegendPosition()
    if not UnchainedHelperLegend or not UnchainedHelper.savedVars then return end
    local x = UnchainedHelper.savedVars.legendOffsetX or 1640
    local y = UnchainedHelper.savedVars.legendOffsetY or 460
    UnchainedHelperLegend:ClearAnchors()
    UnchainedHelperLegend:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    local scale = (UnchainedHelper.savedVars.legendScale or 80) / 100
    UnchainedHelperLegend:SetScale(scale)
    if UnchainedHelperLegendBg and UnchainedHelperLegendBg.SetCenterColor then
        local a = math.max(0, math.min(100, UnchainedHelper.savedVars.legendBackgroundAlpha or 72)) / 100
        UnchainedHelperLegendBg:SetCenterColor(0, 0, 0, a * 0.72)
        UnchainedHelperLegendBg:SetEdgeColor(0.79, 0.64, 0.29, math.min(1, a + 0.12))
    end
end

function UnchainedHelper.HideLegend()
    if not UnchainedHelperLegend then return end
    for i = 1, 5 do
        local row = _G["UnchainedHelperLegendRow" .. tostring(i)]
        if row then row:SetHidden(true) end
    end
    UnchainedHelperLegend:SetHidden(true)
end

function UnchainedHelper.RefreshLegend()
    if not UnchainedHelperLegend or not UnchainedHelper.savedVars then return end

    if not UnchainedHelper.savedVars.showMarkerLegend then
        UnchainedHelper.HideLegend()
        return
    end

    if not UnchainedHelper.IsInBlackrose or not UnchainedHelper.IsInBlackrose() then
        UnchainedHelper.HideLegend()
        return
    end

    local activeTypes = {}
    local activeCount = 0
    for _, icon in ipairs(UnchainedHelper.activeIcons or {}) do
        if icon and icon.legendType and icon.control and not icon.control:IsHidden() then
            activeTypes[icon.legendType] = true
            activeCount = activeCount + 1
        end
    end

    if activeCount == 0 then
        UnchainedHelper.HideLegend()
        return
    end

    local showOnlyActive = UnchainedHelper.savedVars.legendOnlyActive ~= false
    local rowIndex = 0

    for i = 1, 5 do
        local row = _G["UnchainedHelperLegendRow" .. tostring(i)]
        if row then row:SetHidden(true) end
    end

    for _, key in ipairs(UH_LEGEND_ORDER) do
        local include = showOnlyActive and activeTypes[key] or true
        if include then
            rowIndex = rowIndex + 1
            local info = UH_LEGEND_INFO[key]
            local row = _G["UnchainedHelperLegendRow" .. tostring(rowIndex)]
            if row and info then
                row:ClearAnchors()
                row:SetAnchor(TOPLEFT, UnchainedHelperLegend, TOPLEFT, 12, 36 + ((rowIndex - 1) * 26))
                row:SetDimensions(210, 24)

                local icon = _G[row:GetName() .. "Icon"]
                if icon then
                    icon:ClearAnchors()
                    icon:SetAnchor(LEFT, row, LEFT, 0, 0)
                    icon:SetDimensions(20, 20)
                    icon:SetTexture(info.texture)
                    icon:SetHidden(false)
                end

                local label = _G[row:GetName() .. "Label"]
                if label then
                    label:ClearAnchors()
                    label:SetAnchor(LEFT, row, LEFT, 28, 0)
                    label:SetDimensions(178, 24)
                    label:SetText(info.label)
                    if label.SetMaxLineCount then label:SetMaxLineCount(1) end
                    if label.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
                end
                row:SetHidden(false)
            end
        end
    end

    if rowIndex == 0 and UnchainedHelper.savedVars.legendHideWhenNoMarkers ~= false then
        UnchainedHelper.HideLegend()
        return
    end

    if UnchainedHelperLegendTitle then
        UnchainedHelperLegendTitle:SetText("Marker Key")
    end

    local h = 46 + (rowIndex > 0 and rowIndex or 1) * 26
    UnchainedHelperLegend:SetDimensions(232, h)
    UnchainedHelper.UpdateLegendPosition()
    UnchainedHelperLegend:SetHidden(false)
end


-- Blackrose sigil protection.
-- This deliberately targets Blackrose arena sigils only. It does not blanket-disable player synergies.
UnchainedHelper.sigilNames = {
    ["sigil"] = true,
    ["sigil of power"] = true,
    ["sigil of defense"] = true,
    ["sigil of healing"] = true,
    ["sigil of haste"] = true,
}

function UnchainedHelper.IsInBlackrose()
    return GetZoneId and GetUnitZoneIndex and GetZoneId(GetUnitZoneIndex("player")) == 1082
end

local function UH_Lower(value)
    if value == nil then return "" end
    return zo_strlower and zo_strlower(tostring(value)) or string.lower(tostring(value))
end

function UnchainedHelper.GetCurrentSynergyText()
    local texts = {}

    local function collectValues(...)
        local values = { ... }
        for _, value in ipairs(values) do
            if type(value) == "string" and value ~= "" then
                table.insert(texts, value)
            end
        end
    end

    local currentInfo = UnchainedHelper.originalGetCurrentSynergyInfo or GetCurrentSynergyInfo
    if type(currentInfo) == "function" then
        local ok, hasSynergy, synergyName, iconFilename, prompt = pcall(currentInfo)
        if ok and hasSynergy then
            collectValues(synergyName, prompt, iconFilename)
        end
    end

    local function collectFrom(fn)
        if type(fn) ~= "function" then return end
        local ok, a, b, c, d, e, f, g, h = pcall(fn)
        if not ok then return end
        collectValues(a, b, c, d, e, f, g, h)
    end

    collectFrom(GetSynergyInfo)
    collectFrom(GetSynergyAbilityInfo)

    return table.concat(texts, " ")
end

function UnchainedHelper.IsBlackroseSigilSynergy()
    if not UnchainedHelper.savedVars or not UnchainedHelper.savedVars.blockBlackroseSigils then return false end
    if not UnchainedHelper.savedVars.enabled then return false end
    if not UnchainedHelper.IsInBlackrose() then return false end

    local text = UH_Lower(UnchainedHelper.GetCurrentSynergyText())
    if text == "" then return false end

    local playerSynergyTerms = {
        "orb", "shard", "combustion", "conduit", "atronach", "berserk", "altar", "blood", "grave", "boneyard",
        "purify", "harvest", "bone", "spider", "passage", "runebreak", "radiate", "ignite", "liquid lightning",
        "hidden refresh", "soul leech", "bone shield", "undaunted", "necrotic", "mystic"
    }
    for _, term in ipairs(playerSynergyTerms) do
        if string.find(text, term, 1, true) then
            return false
        end
    end

    -- Blackrose sigils may surface as either full sigil names or short prompt labels.
    if string.find(text, "sigil", 1, true)
        or string.find(text, "power", 1, true)
        or string.find(text, "haste", 1, true)
        or string.find(text, "defense", 1, true)
        or string.find(text, "defence", 1, true)
        or string.find(text, "healing", 1, true)
    then
        return true
    end

    return false
end

function UnchainedHelper.IsSigilBlockingEnabled()
    return UnchainedHelper.savedVars and UnchainedHelper.savedVars.enabled and UnchainedHelper.savedVars.blockBlackroseSigils and UnchainedHelper.IsInBlackrose()
end

function UnchainedHelper.ShouldBlockSigilActivation()
    if not UnchainedHelper.IsSigilBlockingEnabled() then return false end
    if UnchainedHelper.IsBlackroseSigilSynergy() then return true end
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    if UnchainedHelper.sigilBlockedUntil and now < UnchainedHelper.sigilBlockedUntil then
        return true
    end
    return false
end

function UnchainedHelper.StartSigilSuppressionWindow()
    UnchainedHelper.sigilBlockedUntil = (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0) + 1000
end

function UnchainedHelper.HideCurrentSynergyPrompt()
    -- Do not call SHARED_INFORMATION_AREA:SetHidden() directly on console.
    -- It can throw from the base UI when its internal control reference is nil.
    -- The activation block itself is handled by the synergy hooks below; this only attempts
    -- to hide the visible prompt safely when the control exists.
    local function safeHide(control)
        if control and control.SetHidden then
            pcall(function() control:SetHidden(true) end)
        end
    end

    safeHide(SYNERGY)
    if SYNERGY then safeHide(SYNERGY.control) end
    if ZO_Synergy then safeHide(ZO_Synergy.control) end
end

function UnchainedHelper.NotifySigilBlocked()
    if not UnchainedHelper.savedVars or not UnchainedHelper.savedVars.sigilBlockNotice then return end
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    if UnchainedHelper.lastSigilBlockNotice and now - UnchainedHelper.lastSigilBlockNotice < 2500 then return end
    UnchainedHelper.lastSigilBlockNotice = now
    d("Unchained Helper: Blackrose sigil blocked.")
end

function UnchainedHelper.BlockCurrentSigilIfNeeded()
    if UnchainedHelper.IsBlackroseSigilSynergy() then
        UnchainedHelper.HideCurrentSynergyPrompt()
        UnchainedHelper.NotifySigilBlocked()
        UnchainedHelper.StartSigilSuppressionWindow()
        return true
    end
    return false
end

function UnchainedHelper.InstallSigilBlocker()
    if UnchainedHelper.sigilBlockerInstalled then return end
    UnchainedHelper.sigilBlockerInstalled = true

    if type(GetCurrentSynergyInfo) == "function" and not UnchainedHelper.originalGetCurrentSynergyInfo then
        UnchainedHelper.originalGetCurrentSynergyInfo = GetCurrentSynergyInfo
        GetCurrentSynergyInfo = function(...)
            local hasSynergy, synergyName, iconFilename, prompt = UnchainedHelper.originalGetCurrentSynergyInfo(...)
            if hasSynergy and UnchainedHelper.IsInBlackrose and UnchainedHelper.IsInBlackrose() and UnchainedHelper.savedVars and UnchainedHelper.savedVars.blockBlackroseSigils then
                local text = UH_Lower(table.concat({ tostring(synergyName or ""), tostring(prompt or ""), tostring(iconFilename or "") }, " "))
                local isPlayerSynergy = false
                local playerTerms = { "orb", "shard", "combustion", "conduit", "atronach", "berserk", "altar", "blood", "grave", "boneyard", "purify", "harvest", "bone", "spider", "passage", "runebreak", "radiate", "ignite", "liquid lightning", "hidden refresh", "soul leech", "bone shield", "undaunted", "necrotic", "mystic" }
                for _, term in ipairs(playerTerms) do
                    if string.find(text, term, 1, true) then isPlayerSynergy = true break end
                end
                if not isPlayerSynergy and (string.find(text, "sigil", 1, true) or string.find(text, "power", 1, true) or string.find(text, "haste", 1, true) or string.find(text, "defense", 1, true) or string.find(text, "defence", 1, true) or string.find(text, "healing", 1, true)) then
                    UnchainedHelper.StartSigilSuppressionWindow()
                    UnchainedHelper.NotifySigilBlocked()
                    return false, nil, nil, nil
                end
            end
            return hasSynergy, synergyName, iconFilename, prompt
        end
    end

    if not ZO_PreHook then return end

    if ZO_Synergy and ZO_Synergy.OnSynergyAbilityChanged then
        ZO_PreHook(ZO_Synergy, "OnSynergyAbilityChanged", function(...)
            if UnchainedHelper.BlockCurrentSigilIfNeeded() then
                return true
            end
        end)
    end

    if ZO_Synergy and ZO_Synergy.ActivateSynergy then
        ZO_PreHook(ZO_Synergy, "ActivateSynergy", function(...)
            if UnchainedHelper.ShouldBlockSigilActivation() then
                UnchainedHelper.HideCurrentSynergyPrompt()
                UnchainedHelper.NotifySigilBlocked()
                UnchainedHelper.StartSigilSuppressionWindow()
                return true
            end
        end)
    end

    if SYNERGY and SYNERGY.Activate then
        ZO_PreHook(SYNERGY, "Activate", function(...)
            if UnchainedHelper.ShouldBlockSigilActivation() then
                UnchainedHelper.HideCurrentSynergyPrompt()
                UnchainedHelper.NotifySigilBlocked()
                UnchainedHelper.StartSigilSuppressionWindow()
                return true
            end
        end)
    end

    if type(UseSynergy) == "function" then
        local originalUseSynergy = UseSynergy
        UseSynergy = function(...)
            if UnchainedHelper.ShouldBlockSigilActivation() then
                UnchainedHelper.HideCurrentSynergyPrompt()
                UnchainedHelper.NotifySigilBlocked()
                UnchainedHelper.StartSigilSuppressionWindow()
                return
            end
            return originalUseSynergy(...)
        end
    end

    if SYNERGY and SYNERGY.IsVisible then
        ZO_PreHook(SYNERGY, "IsVisible", function(...)
            if UnchainedHelper.ShouldBlockSigilActivation() then
                UnchainedHelper.HideCurrentSynergyPrompt()
                return true
            end
        end)
    end

    if EVENT_MANAGER and EVENT_SYNERGY_ABILITY_CHANGED then
        EVENT_MANAGER:RegisterForEvent(UnchainedHelper.name .. "_SigilSynergyChanged", EVENT_SYNERGY_ABILITY_CHANGED, function()
            UnchainedHelper.BlockCurrentSigilIfNeeded()
        end)
    end

    if EVENT_MANAGER and EVENT_MANAGER.RegisterForUpdate then
        EVENT_MANAGER:RegisterForUpdate(UnchainedHelper.name .. "_SigilBlockPoll", 50, function()
            if UnchainedHelper.ShouldBlockSigilActivation() then
                UnchainedHelper.HideCurrentSynergyPrompt()
            end
        end)
    end
end


-- World-marker runtime.
UnchainedHelper.SpaceMarkers = UnchainedHelper.SpaceMarkers or {
    active = {},
    counter = 0,
    updating = false,
    lastError = "",
}

local function UH_Bool(value)
    return value and "Y" or "N"
end

function UnchainedHelper.SpaceMarkers.IsAvailable()
    return WINDOW_MANAGER ~= nil
        and GuiRoot ~= nil
        and WorldPositionToGuiRender3DPosition ~= nil
        and UnchainedHelperSpaceRoot ~= nil
        and UnchainedHelperSpaceRoot.Create3DRenderSpace ~= nil
end

function UnchainedHelper.SpaceMarkers.Diagnostics()
    local root = UnchainedHelperSpaceRoot
    local line = string.format(
        "Unchained Helper markers: root=%s create3D=%s worldTo3D=%s playerWorld=%s cameraHeading=%s",
        UH_Bool(root ~= nil),
        UH_Bool(root ~= nil and root.Create3DRenderSpace ~= nil),
        UH_Bool(WorldPositionToGuiRender3DPosition ~= nil),
        UH_Bool(GetUnitWorldPosition ~= nil),
        UH_Bool(GetPlayerCameraHeading ~= nil)
    )
    d(line)
    if UnchainedHelper.SpaceMarkers.lastError ~= "" then
        d("Unchained Helper marker detail: " .. UnchainedHelper.SpaceMarkers.lastError)
    end
end

function UnchainedHelper.SpaceMarkers.EnsureRoot()
    if not WINDOW_MANAGER or not GuiRoot then
        UnchainedHelper.SpaceMarkers.lastError = "UI root unavailable"
        return false
    end

    local root = UnchainedHelper.SpaceMarkers.root or _G["UnchainedHelperSpaceRoot"]
    if not root then
        root = WINDOW_MANAGER:CreateTopLevelWindow("UnchainedHelperSpaceRoot")
    end
    if not root then
        UnchainedHelper.SpaceMarkers.lastError = "could not create root"
        return false
    end

    root:SetHidden(false)
    root:SetMouseEnabled(false)
    if root.ClearAnchors then root:ClearAnchors() end
    if root.SetAnchor then root:SetAnchor(CENTER, GuiRoot, CENTER) end
    if root.SetDrawTier and DT_HIGH then root:SetDrawTier(DT_HIGH) end

    if root.Create3DRenderSpace then
        if (not root.Has3DRenderSpace) or (not root:Has3DRenderSpace()) then
            root:Create3DRenderSpace()
        end
        if root.Set3DRenderSpaceUsesDepthBuffer then root:Set3DRenderSpaceUsesDepthBuffer(false) end
        if root.Set3DRenderSpaceOrigin then root:Set3DRenderSpaceOrigin(0, 0, 0) end
    end

    UnchainedHelper.SpaceMarkers.root = root

    if not UnchainedHelper.SpaceMarkers.fragment and ZO_SimpleSceneFragment then
        local fragment = ZO_SimpleSceneFragment:New(root)
        UnchainedHelper.SpaceMarkers.fragment = fragment
        if HUD_SCENE then HUD_SCENE:AddFragment(fragment) end
        if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(fragment) end
    end

    return true
end

local function UH_SetMarkerPosition(control, x, y, z)
    if not WorldPositionToGuiRender3DPosition then
        UnchainedHelper.SpaceMarkers.lastError = "WorldPositionToGuiRender3DPosition missing"
        return false
    end
    local gx, gy, gz = WorldPositionToGuiRender3DPosition(x, y, z)
    if not gx or not gy or not gz then
        UnchainedHelper.SpaceMarkers.lastError = "world coordinate conversion returned nil"
        return false
    end
    if not control.Set3DRenderSpaceOrigin then
        UnchainedHelper.SpaceMarkers.lastError = "Set3DRenderSpaceOrigin missing on marker"
        return false
    end
    control:Set3DRenderSpaceOrigin(gx, gy, gz)
    return true
end

local function UH_UpdateMarkerOrientation(marker)
    local control = marker.control
    if not control or not control.Set3DRenderSpaceOrientation then return end

    if marker.facing ~= false and GetPlayerCameraHeading then
        local heading = GetPlayerCameraHeading() or 0
        local pitch = 0
        if GetPlayerCameraPitch then pitch = GetPlayerCameraPitch() or 0 end
        -- Keep the marker upright while roughly facing the player camera.
        control:Set3DRenderSpaceOrientation(pitch, heading, 0)
    else
        control:Set3DRenderSpaceOrientation(0, 0, 0)
    end
end

function UnchainedHelper.SpaceMarkers.UpdateFacing()
    local markers = UnchainedHelper.SpaceMarkers.active
    if #markers == 0 then
        EVENT_MANAGER:UnregisterForUpdate(UnchainedHelper.name .. "SpaceMarkerFacing")
        UnchainedHelper.SpaceMarkers.updating = false
        return
    end

    local cullCm = (UnchainedHelper.savedVars.markerCullingDistance or 0) * 100
    local zoneId, px, py, pz = nil, nil, nil, nil
    if GetUnitWorldPosition then
        zoneId, px, py, pz = GetUnitWorldPosition("player")
    end

    for _, marker in ipairs(markers) do
        local c = marker.control
        if c then
            UH_UpdateMarkerOrientation(marker)
            UH_SetMarkerPosition(c, marker.x, marker.y, marker.z)

            c:SetHidden(false)
        end
    end
end

function UnchainedHelper.SpaceMarkers.StartUpdating()
    if UnchainedHelper.SpaceMarkers.updating then return end
    EVENT_MANAGER:RegisterForUpdate(UnchainedHelper.name .. "SpaceMarkerFacing", 100, UnchainedHelper.SpaceMarkers.UpdateFacing)
    UnchainedHelper.SpaceMarkers.updating = true
end

function UnchainedHelper.SpaceMarkers.Create(x, y, z, texture, sizeMeters, colour, text, facing, heightMeters)
    if not UnchainedHelper.SpaceMarkers.IsAvailable() then
        UnchainedHelper.SpaceMarkers.lastError = "required 3D render functions unavailable"
        return nil
    end
    if not UnchainedHelper.SpaceMarkers.EnsureRoot() then return nil end

    UnchainedHelper.SpaceMarkers.counter = UnchainedHelper.SpaceMarkers.counter + 1
    local name = "UnchainedHelperSpaceMarker" .. tostring(UnchainedHelper.SpaceMarkers.counter)
    local root = UnchainedHelper.SpaceMarkers.root
    local control = WINDOW_MANAGER:CreateControlFromVirtual(name, root, "UnchainedHelperSpaceMarkerTextureTemplate")

    if not control then
        UnchainedHelper.SpaceMarkers.lastError = "marker texture control not created"
        return nil
    end

    control:SetHidden(false)
    control:SetMouseEnabled(false)
    control:SetTexture(texture)
    if control.SetBlendMode and TEX_BLEND_MODE_ALPHA then control:SetBlendMode(TEX_BLEND_MODE_ALPHA) end
    if control.SetDrawLevel then control:SetDrawLevel(100) end
    if control.SetAlpha then control:SetAlpha(1) end
    if colour then control:SetColor(unpack(colour)) end

    if control.Create3DRenderSpace then
        if (not control.Has3DRenderSpace) or (not control:Has3DRenderSpace()) then
            control:Create3DRenderSpace()
        end
        if control.Set3DRenderSpaceUsesDepthBuffer then control:Set3DRenderSpaceUsesDepthBuffer(false) end
    else
        UnchainedHelper.SpaceMarkers.lastError = "Create3DRenderSpace missing on marker texture"
        control:SetHidden(true)
        return nil
    end

    if control.Set3DLocalDimensions then
        local size = sizeMeters or 2.0
        control:Set3DLocalDimensions(size, heightMeters or size)
    end

    local marker = {
        control = control,
        x = x,
        y = y,
        z = z,
        facing = facing ~= false,
    }

    if not UH_SetMarkerPosition(control, x, y, z) then
        control:SetHidden(true)
        return nil
    end

    UH_UpdateMarkerOrientation(marker)
    table.insert(UnchainedHelper.SpaceMarkers.active, marker)
    UnchainedHelper.SpaceMarkers.StartUpdating()
    UnchainedHelper.SpaceMarkers.lastError = ""
    return marker
end

function UnchainedHelper.SpaceMarkers.Clear()
    EVENT_MANAGER:UnregisterForUpdate(UnchainedHelper.name .. "SpaceMarkerFacing")
    UnchainedHelper.SpaceMarkers.updating = false

    for _, marker in ipairs(UnchainedHelper.SpaceMarkers.active) do
        if marker.control then
            marker.control:SetHidden(true)
            marker.control:SetHandler("OnUpdate", nil)
            if marker.control.Destroy3DRenderSpace then marker.control:Destroy3DRenderSpace() end
            if WINDOW_MANAGER.DestroyControl then
                WINDOW_MANAGER:DestroyControl(marker.control)
            end
        end
    end

    UnchainedHelper.SpaceMarkers.active = {}
end

function UnchainedHelper.SpaceMarkers.RefreshPositions()
    for _, marker in ipairs(UnchainedHelper.SpaceMarkers.active) do
        if marker.control then
            UH_SetMarkerPosition(marker.control, marker.x, marker.y, marker.z)
        end
    end
end

function UnchainedHelper.HasMarkerRuntime()
    return UnchainedHelper.SpaceMarkers and UnchainedHelper.SpaceMarkers.IsAvailable()
end

function UnchainedHelper.WarnMissingMarkerRuntime(force)
    if UnchainedHelper.HasMarkerRuntime() then return end
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    if force or not UnchainedHelper.lastMissingMarkerRuntimeWarn or now - UnchainedHelper.lastMissingMarkerRuntimeWarn > 10000 then
        d("Unchained Helper: marker layer unavailable. Logic loaded; world markers cannot draw on this client yet.")
        UnchainedHelper.SpaceMarkers.Diagnostics()
        UnchainedHelper.lastMissingMarkerRuntimeWarn = now
    end
end

function UnchainedHelper.MarkerSelfCheck()
    if not UnchainedHelper.HasMarkerRuntime() then
        UnchainedHelper.WarnMissingMarkerRuntime(true)
        return
    end
    if not GetUnitWorldPosition then
        d("Unchained Helper: player world position unavailable.")
        return
    end
    UnchainedHelper.ClearIcons()
    local zoneId, x, y, z = GetUnitWorldPosition("player")
    if not x then
        d("Unchained Helper: could not read player world position.")
        return
    end
    local texture = "UnchainedHelper/icons/raised_priority.dds"
    local sizeMeters = (UnchainedHelper.savedVars.markerSize or 220) / 100
    local height = UnchainedHelper.savedVars.markerHeight or 280
    local icon = UnchainedHelper.SpaceMarkers.Create(x, y + height, z + 500, texture, sizeMeters, {1, 0.18, 0.16, 1}, "", true)
    if icon then
        table.insert(UnchainedHelper.activeIcons, icon)
        d("Unchained Helper: marker self-check placed near your character.")
    else
        UnchainedHelper.WarnMissingMarkerRuntime(true)
    end
end


function UnchainedHelper.addPurgable(targetUnitId, abilityId)
    if UnchainedHelper.currentPurgeable == 0 then
        if UnchainedHelper.savedVars.soundEffectPurge and UnchainedHelper.savedVars.soundEffectPurge ~= "No Sound Effect" then
            PlaySound(UnchainedHelper.savedVars.soundEffectPurge)
        end
    end
    UnchainedHelper.currentPurgeable = UnchainedHelper.currentPurgeable + 1
    UnchainedHelperFramePurge:SetText(string.format("Purge %d", UnchainedHelper.currentPurgeable))
    if UnchainedHelper.savedVars.displayPurge then
        UnchainedHelperFrame:SetHidden(false)
    else
        UnchainedHelperFrame:SetHidden(true)
    end
end



function UnchainedHelper.removePurgable(targetUnitId, abilityId)
    UnchainedHelper.currentPurgeable=UnchainedHelper.currentPurgeable-1
    if UnchainedHelper.currentPurgeable<=0 then
        UnchainedHelper.currentPurgeable=0

        UnchainedHelperFramePurge:SetText("")
        UnchainedHelperFrame:SetHidden(true)
 	else
 	    UnchainedHelperFramePurge:SetText(string.format("Purge %d", UnchainedHelper.currentPurgeable))
        if UnchainedHelper.savedVars.displayPurge then
            UnchainedHelperFrame:SetHidden(false)
        else
            UnchainedHelperFrame:SetHidden(true)
        end
    end
end







function UnchainedHelper.combatEvent(eventCode,result,isError,abilityName,abilityGraphic,abilityActionSlotType,sourceName,sourceType,targetName,targetType,hitValue,powerType,damageType,combatEventLog,sourceUnitId,targetUnitId,abilityId)
    local desc = nil
    if abilityId == 109992 then -- poison bloom - vBRP -- AUTO PURGE
        desc = "POISONBLOOM"
    elseif abilityId == 113150 then -- ARROWPOISON - vBRP -- AUTO PURGE
        desc = "ARROWPOISON"
    end

    if not desc then return end

    if ACTION_RESULT_EFFECT_GAINED_DURATION == result then
        UnchainedHelper.addPurgable(targetUnitId, abilityId)
    elseif ACTION_RESULT_EFFECT_FADED == result then
        UnchainedHelper.removePurgable(targetUnitId, abilityId)
    end
end


function UnchainedHelper.OnPlayerCombatState(event, inCombat)
    if inCombat ~= UnchainedHelper.inCombat then
        UnchainedHelper.inCombat = inCombat
        if not inCombat then
            UnchainedHelper.currentPurgeable=0
            UnchainedHelperFramePurge:SetText("")
            UnchainedHelperFrame:SetHidden(true)
        end
    end
end

function UnchainedHelper.hideFrame()
	UnchainedHelperFramePurge:SetHidden(IsReticleHidden())
end


function UnchainedHelper.GetMarkerTexture(markerType, portal)
    if markerType == "group" then
        return "UnchainedHelper/icons/raised_group.dds"
    elseif markerType == "tank" then
        return "UnchainedHelper/icons/raised_tank.dds"
    elseif markerType == "chain" then
        return "UnchainedHelper/icons/raised_interrupt.dds"
    elseif markerType == "boss" or markerType == "elite" then
        return "UnchainedHelper/icons/raised_priority.dds"
    elseif markerType == "nochain" then
        return "UnchainedHelper/icons/raised_danger.dds"
    elseif portal == true then
        return "UnchainedHelper/icons/raised_interrupt.dds"
    end
    return "UnchainedHelper/icons/raised_default.dds"
end

function UnchainedHelper.ShouldShowMarker(markerType, portal)
    if not UnchainedHelper.savedVars.enabled then return false end
    if not UnchainedHelper.HasMarkerRuntime() then return false end

    if markerType == "group" then
        return UnchainedHelper.savedVars.dpsPosition
    elseif markerType == "tank" then
        return UnchainedHelper.savedVars.tankPosition
    elseif markerType == "chain" then
        return UnchainedHelper.savedVars.chainAddsPosition and UnchainedHelper.savedVars.showInterruptMarkers
    elseif markerType == "boss" then
        return UnchainedHelper.savedVars.bossPosition and UnchainedHelper.savedVars.showPriorityMarkers
    elseif markerType == "elite" then
        return UnchainedHelper.savedVars.miniPosition and UnchainedHelper.savedVars.showPriorityMarkers
    elseif markerType == "nochain" then
        return UnchainedHelper.savedVars.nonchainAddsPosition and UnchainedHelper.savedVars.showDangerMarkers
    elseif portal == true then
        return UnchainedHelper.savedVars.wardenPortals and UnchainedHelper.savedVars.showInterruptMarkers
    end
    return true
end

function UnchainedHelper.GetMarkerColour(markerType, portal)
    return nil
end

function UnchainedHelper.marker(x, y, z, markerType, number, portal)
    if not UnchainedHelper.replayingMarkers then
        UnchainedHelper.activeMarkerRequests = UnchainedHelper.activeMarkerRequests or {}
        table.insert(UnchainedHelper.activeMarkerRequests, { x = x, y = y, z = z, markerType = markerType, number = number, portal = portal })
    end

    if not UnchainedHelper.ShouldShowMarker(markerType, portal) then return end

    local texture = UnchainedHelper.GetMarkerTexture(markerType, portal)
    local sizeMeters = (UnchainedHelper.savedVars.markerSize or 175) / 100
    local height = UnchainedHelper.savedVars.markerHeight or 280
    local colour = UnchainedHelper.GetMarkerColour(markerType, portal)
    local facing = true

    local icon = UnchainedHelper.SpaceMarkers.Create(x, y + height, z, texture, sizeMeters, colour, number, facing, sizeMeters)

    if icon then
        icon.legendType = UnchainedHelper.GetLegendCategory(markerType, portal)
        table.insert(UnchainedHelper.activeIcons, icon)
        UnchainedHelper.RefreshLegend()
    else
        UnchainedHelper.WarnMissingMarkerRuntime(false)
    end
end

function UnchainedHelper.RedrawActiveMarkers()
    if not UnchainedHelper.activeMarkerRequests or #UnchainedHelper.activeMarkerRequests == 0 then
        UnchainedHelper.RefreshLegend()
        return
    end

    local reqs = UnchainedHelper.activeMarkerRequests
    UnchainedHelper.ClearIcons(true)
    UnchainedHelper.replayingMarkers = true
    for _, req in ipairs(reqs) do
        UnchainedHelper.marker(req.x, req.y, req.z, req.markerType, req.number, req.portal)
    end
    UnchainedHelper.replayingMarkers = false
    UnchainedHelper.activeMarkerRequests = reqs
    UnchainedHelper.RefreshLegend()
end



UnchainedHelper.SpawnCallouts = {
    [1] = {
        [1] = {
            [1] = "3 Footsoldiers + 3 Archers",
            [2] = "Cleaver + 3 Archers",
            [3] = "Dreadknight + 3 Archers",
        },
        [2] = {
            [1] = "2 Footsoldiers + 2 Archers + Mage",
            [2] = "2 Archers + 6 Footsoldiers",
            [3] = "4 Archers + Dreadknight",
        },
        [3] = {
            [1] = "4 Archers + Cleaver",
            [2] = "2 Archers + Cleaver + Mage",
            [3] = "3 Archers + Dreadknight + Mage",
        },
        [4] = {
            [1] = "2 Cleavers + Archer",
            [2] = "2 Mages + Cleaver + 2 Archers",
            [3] = "2 Dreadknights + 2 Archers",
        },
        [5] = {
            [1] = "Boss",
        },
    },
    [2] = {
        [1] = {
            [1] = "3 Spiders + 2 Hackwings",
            [2] = "2 Crocodiles + 2 Hoarvors + 2 Spiders",
            [3] = "Beastmaster + 3 Hackwings",
        },
        [2] = {
            [1] = "3 Spiders + 3 Hoarvors",
            [2] = "Haj Mota + Crocodile + 3 Spiders",
            [3] = "3 Spiders + Beastmaster",
        },
        [3] = {
            [1] = "2 Hackwings + 2 Spiders + Troll",
            [2] = "Troll + 2 Crocodiles",
            [3] = "Troll + Beastmaster",
        },
        [4] = {
            [1] = "4 Spiders + 2 Crocodiles",
            [2] = "2 Beastmasters + Wamasu + 3 Spiders",
        },
        [5] = {
            [1] = "Tames-the-Beast",
        },
    },
    [3] = {
        [1] = {
            [1] = "4 Bloodfiends + Cold Mage",
            [2] = "3 Infusers",
            [3] = "2 Infusers + Gargoyle",
        },
        [2] = {
            [1] = "6 Bloodfiends + 2 Infusers",
            [2] = "2 Cold Mages",
            [3] = "Gargoyle + 2 Bats",
        },
        [3] = {
            [1] = "2 Cold Mages + 2 Infusers",
            [2] = "Gargoyle + 2 Cold Mages + Infuser + 3 Bloodfiends",
            [3] = "2 Cold Mages + Infuser + 3 Bloodfiends",
        },
        [4] = {
            [1] = "4 Infusers + 2 Bats + 2 Bloodfiends",
            [2] = "2 Cold Mages",
            [3] = "2 Gargoyles",
        },
        [5] = {
            [1] = "Lady Minara",
        },
    },
    [4] = {
        [1] = {
            [1] = "2 Footsoldiers + 2 Spiders + Cleaver",
            [2] = "Infuser + Crocodile + 2 Incinerators",
            [3] = "2 Hoarvors + 2 Bloodfiends + Beastmaster",
        },
        [2] = {
            [1] = "2 Archers + Cleaver + Incinerator",
            [2] = "2 Footsoldiers + Archer + Dreadknight",
            [3] = "2 Incinerators + Boss",
        },
        [3] = {
            [1] = "4 Hackwings + Beastmaster",
            [2] = "4 Spiders + Haj Mota",
            [3] = "Tames-the-Beast + 2 Crocodiles",
        },
        [4] = {
            [1] = "Cold Mage + 2 Bloodfiends + 2 Bats",
            [2] = "2 Infusers + Gargoyle",
            [3] = "Infuser + Cold Mage + Lady Minara",
        },
        [5] = {
            [1] = "Boss",
            [2] = "Tames-the-Beast",
            [3] = "Lady Minara",
        },
    },
    [5] = {
        [1] = {
            [1] = "2 Convicts + 2 Prisoners",
            [2] = "2 Convicts + Soul Void",
            [3] = "Vengeful Revenant",
        },
        [2] = {
            [1] = "2 Prisoners + Soul Void",
            [2] = "Prisoner + Vengeful Revenant",
            [3] = "2 Convicts + Soul Void",
        },
        [3] = {
            [1] = "Prisoner + 2 Convicts + Soul Void",
            [2] = "2 Soul Voids + Convict",
            [3] = "Prisoner + Convict + Vengeful Revenant",
        },
        [4] = {
            [1] = "2 Convicts + 2 Prisoners + Soul Void",
            [2] = "2 Prisoners + 2 Soul Voids",
            [3] = "Prisoner + 2 Convicts + Boss",
        },
        [5] = {
            [1] = "Boss",
        },
    },
}

function UnchainedHelper.GetSpawnCallout(stage, round, wave)
    local stageData = UnchainedHelper.SpawnCallouts[stage]
    local roundData = stageData and stageData[round]
    return roundData and roundData[wave] or nil
end

function UnchainedHelper.UpdateSpawnCalloutPosition()
    if not UnchainedHelperSpawnCallout or not UnchainedHelper.savedVars then return end
    UnchainedHelperSpawnCallout:ClearAnchors()
    UnchainedHelperSpawnCallout:SetAnchor(CENTER, GuiRoot, CENTER, UnchainedHelper.savedVars.spawnCalloutOffsetX or 0, UnchainedHelper.savedVars.spawnCalloutOffsetY or -150)
    UnchainedHelperSpawnCallout:SetScale((UnchainedHelper.savedVars.spawnCalloutScale or 100) / 100)
end

function UnchainedHelper.HideSpawnCallout()
    EVENT_MANAGER:UnregisterForUpdate(UnchainedHelper.name .. "SpawnCalloutHide")
    if UnchainedHelperSpawnCallout then UnchainedHelperSpawnCallout:SetHidden(true) end
end

function UnchainedHelper.ShowSpawnCallout(stage, round, wave)
    if not UnchainedHelper.savedVars or UnchainedHelper.savedVars.showSpawnCallout == false then return end
    if not UnchainedHelper.IsInBlackrose or not UnchainedHelper.IsInBlackrose() then
        UnchainedHelper.HideSpawnCallout()
        return
    end

    local actualStage = UnchainedHelper.GetCurrentStage and (UnchainedHelper.GetCurrentStage() or 0) or 0
    if actualStage <= 0 or stage ~= actualStage then
        UnchainedHelper.HideSpawnCallout()
        return
    end

    local spawnText = UnchainedHelper.GetSpawnCallout(stage, round, wave)
    if not spawnText then return end

    local key = string.format("%d.%d.%d", stage, round, wave)
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    if UnchainedHelper.lastSpawnCalloutKey == key and UnchainedHelper.lastSpawnCalloutTime and now - UnchainedHelper.lastSpawnCalloutTime < 1000 then return end
    UnchainedHelper.lastSpawnCalloutKey = key
    UnchainedHelper.lastSpawnCalloutTime = now

    UnchainedHelper.UpdateSpawnCalloutPosition()
    if UnchainedHelperSpawnCalloutProgress then
        UnchainedHelperSpawnCalloutProgress:SetText(string.format("Round: %d/5 - Stage: %d/5", round, stage))
    end
    if UnchainedHelperSpawnCalloutText then
        UnchainedHelperSpawnCalloutText:SetText("Spawning: " .. spawnText)
    end
    if UnchainedHelperSpawnCallout then UnchainedHelperSpawnCallout:SetHidden(false) end

    EVENT_MANAGER:UnregisterForUpdate(UnchainedHelper.name .. "SpawnCalloutHide")
    local duration = math.max(1, math.min(8, UnchainedHelper.savedVars.spawnCalloutDuration or 4)) * 1000
    EVENT_MANAGER:RegisterForUpdate(UnchainedHelper.name .. "SpawnCalloutHide", duration, function()
        UnchainedHelper.HideSpawnCallout()
    end)
end

function UnchainedHelper.NotifyNewWave(nextFight)
    --d("nextFlight:",nextFight)
	local s = UnchainedHelper.GetCurrentStage()
	local r = UnchainedHelper.currentRound
	local w = UnchainedHelper.currentWave

    if nextFight==1 then
    	s = UnchainedHelper.nextStage
	    r = UnchainedHelper.nextRound
	    w = UnchainedHelper.nextWave
	    --d(string.format("Unchained Next Arena: %s. Round: %s. Wave: %s.", s, r, w))

	    UnchainedHelper.drawNextFightIconTime = 0
        UnchainedHelper.nextStage = 0
        UnchainedHelper.nextRound = 0
        UnchainedHelper.nextWave = 0
    else
        UnchainedHelper.nextStage = s
        if UnchainedHelper.savedVars.wavesInChat then
            if s==0 then
            else
    	    d(string.format("BRP: %s.%s.%s", s, r, w))
    	    end
    	end
    end

    UnchainedHelper.ShowSpawnCallout(s, r, w)
    UnchainedHelper.ClearIcons()

    if s == 1 and r == 1 and w == 1 then
        UnchainedHelper.marker(104111,60951,70730,"nochain", "1",false) -- footsoldier
        UnchainedHelper.marker(104147,60951,66109,"nochain", "2",false) -- footsoldier
        UnchainedHelper.marker(102946,60951,66175,"nochain", "3",false) -- footsoldier


        UnchainedHelper.marker(102637,60951,66181,"chain", "4",true) -- archer
        UnchainedHelper.marker(103023,60951,70699, "chain", "5",true) -- archer
        UnchainedHelper.marker(102669,60951,70674,"chain", "6",true) -- archer

        UnchainedHelper.marker(103307,60951,68357,"group", "",false) -- group



        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 2
        end
    elseif s == 1 and r == 1 and w == 2 then
        UnchainedHelper.marker(105911,60951,68075,"elite", "1",false) -- cleaver
        UnchainedHelper.marker(104147,60951,66109,"chain", "2",true) -- archer
        UnchainedHelper.marker(102669,60951,70674, "chain", "3",false) -- archer
        UnchainedHelper.marker(102637,60951,66181, "chain", "4",false) -- archer
        UnchainedHelper.marker(105916,60951,67793, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 3
        end
    elseif s == 1 and r == 1 and w == 3 then

        UnchainedHelper.marker(105786,60955,67598,"elite", "1",false) -- dreadknight
        UnchainedHelper.marker(102842,60950,66256,"chain", "2",false) -- archer
        UnchainedHelper.marker(104111,60951,70730, "chain", "3",true) -- archer
        UnchainedHelper.marker(103023,60951,70699, "chain", "4",false) -- archer
        UnchainedHelper.marker(105916,60951,67793, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 1
            if UnchainedHelper.savedVars.hintsInChatArena1 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UG1.1.3: dps stay against gate until tank chains in archers, else they may start taking aim out of chain range, this strat repeats several times in this arena")
            end
        end
    elseif s == 1 and r == 2 and w == 1 then

        UnchainedHelper.marker(102637,60951,66181,"nochain", "1",false) -- footsoldier
        UnchainedHelper.marker(102669,60951,70674,"nochain", "2",false) -- footsoldier
        UnchainedHelper.marker(103023,60951,70699,"chain", "3",true) -- archer
        UnchainedHelper.marker(105786,60955,67598, "chain", "4",true) -- archer
        UnchainedHelper.marker(104111,60951,70730, "elite", "5",false) -- mage
        UnchainedHelper.marker(104082,60951,70087, "group", "",false) -- group




        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 2
        end
    elseif s == 1 and r == 2 and w == 2 then

        UnchainedHelper.marker(102669,60951,70674, "chain", "1",true) -- archer
        UnchainedHelper.marker(104147,60951,66109, "chain", "2",true) -- archer
        UnchainedHelper.marker(104111,60951,70730,"nochain", "3",false) -- footsoldier
        UnchainedHelper.marker(103023,60951,70699, "nochain", "4",false) -- footsoldier
        UnchainedHelper.marker(102946,60951,66175, "nochain", "5",false) -- footsoldier
        UnchainedHelper.marker(102637,60951,66181, "nochain", "6",false) -- footsoldier
        UnchainedHelper.marker(105786,60955,67598, "nochain", "7",false) -- footsoldier
        UnchainedHelper.marker(105911,60951,68075, "nochain", "8",false) -- footsoldier
        UnchainedHelper.marker(103307,60951,68357, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 3
        end

    elseif s == 1 and r == 2 and w == 3 then


        UnchainedHelper.marker(104111,60951,70730,"chain", "1",true) -- archer
        UnchainedHelper.marker(102669,60951,70674, "chain", "2",false) -- archer
        UnchainedHelper.marker(104147,60951,66109,"chain", "3",true) -- archer
        UnchainedHelper.marker(102637,60951,66181, "chain", "4",false) -- archer

        UnchainedHelper.marker(105911,60951,68075, "elite", "5",false) -- dreadknight

        UnchainedHelper.marker(103307,60951,68357, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 1
        end
    elseif s == 1 and r == 3 and w == 1 then

        UnchainedHelper.marker(104111,60951,70730,"chain", "1",true) -- archer
        UnchainedHelper.marker(102669,60951,70674, "chain", "2",false) -- archer
        UnchainedHelper.marker(104147,60951,66109,"chain", "3",true) -- archer
        UnchainedHelper.marker(102637,60951,66181, "chain", "4",false) -- archer

        UnchainedHelper.marker(105786,60955,67598, "elite", "5",false) -- cleaver

        UnchainedHelper.marker(105916,60951,67793, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 2
        end
    elseif s == 1 and r == 3 and w == 2 then

        UnchainedHelper.marker(104111,60951,70730, "chain", "1",false) -- archer
        UnchainedHelper.marker(104147,60951,66109, "chain", "2",true) -- archer
        UnchainedHelper.marker(102669,60951,70674, "elite", "3",false) -- cleaver
        UnchainedHelper.marker(102946,60951,66175, "elite", "4",false) -- mage

        UnchainedHelper.marker(102962,60951,66815, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 3

        end

    elseif s == 1 and r == 3 and w == 3 then

        UnchainedHelper.marker(102669,60951,70674, "chain", "1",false) -- archer
        UnchainedHelper.marker(105911,60951,68075, "chain", "2",true) -- archer
        UnchainedHelper.marker(102637,60951,66181, "chain", "3",true) -- archer
        UnchainedHelper.marker(105786,60955,67598, "elite", "4",false) -- dreadknight
        UnchainedHelper.marker(104147,60951,66109, "elite", "5",false) -- mage

        UnchainedHelper.marker(104158,60950,66667, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 1
            if UnchainedHelper.savedVars.hintsInChatArena1 and (UnchainedHelper.savedVars.tankHints) then
                d("UG1.3.3: tank stack everything on mage")
            end
            if UnchainedHelper.savedVars.hintsInChatArena1 and (UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UG1.3.3: dps ult on mage and dreadknight")
            end
        end

    elseif s == 1 and r == 4 and w == 1 then

        UnchainedHelper.marker(103023,60951,70699, "elite", "1",false) -- cleaver
        UnchainedHelper.marker(102946,60951,66175, "elite", "2",false) -- cleaver
        UnchainedHelper.marker(105911,60951,68075, "chain", "3",true) -- archer
        UnchainedHelper.marker(103307,60951,68357, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 2
        end


    elseif s == 1 and r == 4 and w == 2 then


        UnchainedHelper.marker(102669,60951,70674, "elite", "1",false) -- mage
        UnchainedHelper.marker(102637,60951,66181, "elite", "2",false) -- mage
        UnchainedHelper.marker(105911,60951,68075, "elite", "3",false) -- cleaver

        UnchainedHelper.marker(104111,60951,70730, "chain", "4",false) -- archer
        UnchainedHelper.marker(104147,60951,66109, "chain", "5",true) -- archer

        UnchainedHelper.marker(102817,60951,69539, "tank", "",false) -- tank

        UnchainedHelper.marker(102815,60951,66762, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 3
            if UnchainedHelper.savedVars.hintsInChatArena1 and (UnchainedHelper.savedVars.tankHints) then
                d("UG1.4.2: tank chain archer to dps's mage, no taunt, move to other mage/cleaver build 2nd stack")
            end
        end


    elseif s == 1 and r == 4 and w == 3 then

        UnchainedHelper.marker(104111,60951,70730, "elite", "1",false) -- dreadknight
        UnchainedHelper.marker(104147,60951,66109, "elite", "2",false) -- dreadnight

        UnchainedHelper.marker(102669,60951,70674, "chain", "3",true) -- archer
        UnchainedHelper.marker(105786,60955,67598, "chain", "4",true) -- archer

        UnchainedHelper.marker(103307,60951,68357, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 5
            UnchainedHelper.nextWave = 1
        end


    elseif s == 1 and r == 5 and w == 1 then

        UnchainedHelper.marker(103753,60951,68455, "boss", "1",false) -- boss

        UnchainedHelper.marker(103500,60951,68410, "tank", "",false) -- tank

        UnchainedHelper.marker(104089,60951,68447, "group", "",false) -- healer
        UnchainedHelper.marker(103738,60951,68016, "group", "",false) -- right dps
        UnchainedHelper.marker(103772,60951,68887, "group", "",false) -- left dps

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds/2)*1000 -- remove icons after X/2 seconds

            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds

            UnchainedHelper.nextStage = 2
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 1
        end



    elseif s == 2 and r == 1 and w == 1 then

        UnchainedHelper.marker(90086,57147,61117, "chain", "1",false) -- spider
        UnchainedHelper.marker(92896,57158,62884, "chain", "2",false) -- spider
        UnchainedHelper.marker(88236,57144,62666, "chain", "3",true) -- spider

        UnchainedHelper.marker(92962,57149,64405, "nochain", "4",false) -- hackwing
        UnchainedHelper.marker(88345,57153,64110, "nochain", "5",false) -- hackwing

        UnchainedHelper.marker(89653,57151,61676, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 2
        end


    elseif s == 2 and r == 1 and w == 2 then


        UnchainedHelper.marker(88236,57144,62666, "elite", "1",false) -- crocadile
        UnchainedHelper.marker(92896,57158,62884, "elite", "2",false) -- crocodile

        UnchainedHelper.marker(90086,57147,61117, "chain", "3",false) -- hover
        UnchainedHelper.marker(88345,57153,64110, "chain", "4",false) -- spider

        UnchainedHelper.marker(92962,57149,64405, "chain", "5",false) -- spider

        UnchainedHelper.marker(88304,57154,63792, "chain", "6",false) -- hover


        UnchainedHelper.marker(89653,57151,61676, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 3
        end

    elseif s == 2 and r == 1 and w == 3 then

        UnchainedHelper.marker(90086,57147,61117, "elite", "1",false) -- beastmaster

        UnchainedHelper.marker(88345,57153,64110, "nochain", "2",false) -- hackwing
        UnchainedHelper.marker(92962,57149,64405, "nochain", "3",false) -- hackwing
        UnchainedHelper.marker(92896,57158,62884, "nochain", "4",false) -- hackwing

        UnchainedHelper.marker(89653,57151,61676, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 1
        end

    elseif s == 2 and r == 2 and w == 1 then

        UnchainedHelper.marker(92967,57153,63974, "chain", "1",false) -- spider
        UnchainedHelper.marker(90086,57147,61117, "chain", "2",false) -- spider
        UnchainedHelper.marker(88236,57144,62666, "chain", "3",false) -- hover
        UnchainedHelper.marker(92896,57158,62884, "chain", "4",false) -- hover
        UnchainedHelper.marker(88304,57154,63792, "chain", "5",true) -- Spider
        UnchainedHelper.marker(89784,57152,61143, "chain", "6",false) -- hover

        UnchainedHelper.marker(89653,57151,61676, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 2
        end

    elseif s == 2 and r == 2 and w == 2 then


        UnchainedHelper.marker(90086,57147,61117, "elite", "1",false) -- Haj
        UnchainedHelper.marker(92962,57149,64405, "elite", "2",false) -- crocodile

        UnchainedHelper.marker(88345,57153,64110, "chain", "3",true) -- spider
        UnchainedHelper.marker(88236,57144,62666, "chain", "4",true) -- spider

        UnchainedHelper.marker(92896,57158,62884, "chain", "5",false) -- spider

        UnchainedHelper.marker(89653,57151,61676, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 3
            if UnchainedHelper.savedVars.hintsInChatArena2 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UH2.2.2: dps Haj from front, ults")
            end
        end

    elseif s == 2 and r == 2 and w == 3 then

        UnchainedHelper.marker(92967,57153,63974, "chain", "1",false) -- spider
        UnchainedHelper.marker(88236,57144,62666, "chain", "2",true) -- spider
        UnchainedHelper.marker(88304,57154,63792, "chain", "3",true) -- spider

        UnchainedHelper.marker(89784,57152,61143, "elite", "4",false) -- beastmaster

        UnchainedHelper.marker(89653,57151,61676, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 1
        end

    elseif s == 2 and r == 3 and w == 1 then

        UnchainedHelper.marker(92967,57153,63974, "nochain", "1",false) -- hackwing
        UnchainedHelper.marker(88304,57154,63792, "nochain", "2",false) -- hackwing

        UnchainedHelper.marker(88345,57153,64110, "chain", "3",true) -- spider
        UnchainedHelper.marker(92962,57149,64405, "chain", "4",false) -- spider

        UnchainedHelper.marker(89784,57152,61143, "elite", "5",false) -- troll

        UnchainedHelper.marker(89653,57151,61676, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 2
        end

    elseif s == 2 and r == 3 and w == 2 then

        UnchainedHelper.marker(90086,57147,61117, "elite", "1",false) -- troll
        UnchainedHelper.marker(88345,57153,64110, "elite", "2",false) -- crocodile
        UnchainedHelper.marker(92962,57149,64405, "elite", "3",false) -- crocodile

        UnchainedHelper.marker(89653,57151,61676, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 3
        end


    elseif s == 2 and r == 3 and w == 3 then

        UnchainedHelper.marker(88236,57144,62666, "elite", "1",false) -- troll
        UnchainedHelper.marker(92896,57158,62884, "elite", "2",false) -- beastmaster

        UnchainedHelper.marker(90671,57145,63240, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 1
        end


    elseif s == 2 and r == 4 and w == 1 then

        UnchainedHelper.marker(90086,57147,61117, "chain", "1",false) -- spider
        UnchainedHelper.marker(88345,57153,64110, "chain", "2",true) -- spider
        UnchainedHelper.marker(92962,57149,64405, "chain", "3",false) -- Spider
        UnchainedHelper.marker(89784,57152,61143, "chain", "4",false) -- spider

        UnchainedHelper.marker(92896,57158,62884, "elite", "5",false) -- croc
        UnchainedHelper.marker(88236,57144,62666, "elite", "6",false) -- croc

        UnchainedHelper.marker(89653,57151,61676, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 2
        end

    elseif s == 2 and r == 4 and w == 2 then

        UnchainedHelper.marker(92967,57153,63974, "elite", "1",false) -- beastmaster
        UnchainedHelper.marker(90086,57147,61117, "elite", "2",false) -- wama
        UnchainedHelper.marker(88304,57154,63792, "elite", "3",false) -- beastmaster

        UnchainedHelper.marker(88345,57153,64110, "chain", "4",false) -- spider
        UnchainedHelper.marker(92962,57149,64405, "chain", "5",false) -- spider

        UnchainedHelper.marker(89784,57152,61143, "chain", "6",false) -- spider

        UnchainedHelper.marker(90578,57147,63146, "tank", "",false) -- MT

        UnchainedHelper.marker(89653,57151,61676, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 5
            UnchainedHelper.nextWave = 1
            if UnchainedHelper.savedVars.hintsInChatArena2 and (UnchainedHelper.savedVars.tankHints) then
                d("UH2.4.2: tank - no taunt wama, stack beastmasters in middle")
            end
            if UnchainedHelper.savedVars.hintsInChatArena2 and (UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UH2.4.2: dps kill wama, then join tank, no ultimates")
            end
        end

    elseif s == 2 and r == 5 and w == 1 then

        UnchainedHelper.marker(90143,57142,63344, "boss", "1",false) -- tames

        UnchainedHelper.marker(90162,57143,63171,  "tank", "",false) -- MT

        UnchainedHelper.marker(90140,57150,63755, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds/2) * 1000 -- remove icons after X seconds

            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds

            UnchainedHelper.nextStage = 3
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 1

        end

    elseif s == 3 and r == 1 and w == 1 then

        UnchainedHelper.marker(97750,53899,47033, "nochain", "1",false) -- Bloodfiend
        UnchainedHelper.marker(96204,53905,47039, "nochain", "2",false) -- Bloodfiend

        UnchainedHelper.marker(97440,53909,51627, "nochain", "3",false) -- Bloodfiend
        UnchainedHelper.marker(96027,53908,51601, "nochain", "4",false) -- Bloodfiend

        UnchainedHelper.marker(99234,53909,49000, "chain", "5",true) -- Cold Mage

        UnchainedHelper.marker(97037,53906,49474, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 2
        end
    elseif s == 3 and r == 1 and w == 2 then

        UnchainedHelper.marker(99271,53908,48506, "chain", "1",true) -- Infuser
        UnchainedHelper.marker(96599,53917,47065, "chain", "2",true) -- Infuser
        UnchainedHelper.marker(96337,53916,51631, "chain", "3",true) -- Infuser

        UnchainedHelper.marker(97037,53906,49474, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 3
        end

    elseif s == 3 and r == 1 and w == 3 then

        UnchainedHelper.marker(96204,53905,47039, "chain", "1",true) -- Infuserws
        UnchainedHelper.marker(96027,53908,51601, "chain", "2",true) -- Infuser

        UnchainedHelper.marker(99234,53909,49000, "elite", "3",false) -- Gargoyle



        UnchainedHelper.marker(97037,53906,49474, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 1


        end

    elseif s == 3 and r == 2 and w == 1 then

        UnchainedHelper.marker(97698,53898,47113, "nochain", "1",false) -- bloodfiend
        UnchainedHelper.marker(96204,53905,47039, "nochain", "2",false) -- bloodfiend
        UnchainedHelper.marker(99234,53909,49000, "nochain", "3",false) -- bloodfiend
        UnchainedHelper.marker(97440,53909,51627, "nochain", "4",false) -- bloodfiend
        UnchainedHelper.marker(96027,53908,51601, "nochain", "5",false) -- bloodfiend
        UnchainedHelper.marker(99271,53908,48506, "nochain", "6",false) -- bloodfiend

        UnchainedHelper.marker(96599,53917,47065, "chain", "7",true) -- Infuser
        UnchainedHelper.marker(96337,53916,51631, "chain", "8",true) -- INfuser

        UnchainedHelper.marker(97037,53906,49474, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 2
        end

    elseif s == 3 and r == 2 and w == 2 then

        UnchainedHelper.marker(96599,53917,47065, "chain", "1",true) -- cold mage
        UnchainedHelper.marker(96337,53916,51631, "chain", "2",true) -- cold mage

        UnchainedHelper.marker(97037,53906,49474, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 3
        end

    elseif s == 3 and r == 2 and w == 3 then

        UnchainedHelper.marker(97698,53898,47113, "elite", "1",false) -- gargoyle

        UnchainedHelper.marker(97440,53909,51627, "nochain", "2",false) -- bat
        UnchainedHelper.marker(96027,53908,51601, "nochain", "3",false) -- bat

        UnchainedHelper.marker(97037,53906,49474, "group", "",false) -- group
        UnchainedHelper.marker(97694,53907,47613, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 1
            if UnchainedHelper.savedVars.hintsInChatArena3 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UH:3.2.3: Gargoyle leave AOE under your feet, stay out of combat area until AOE's drop then move to stack locations. This strat repeats in arena 3")
            end
        end


    elseif s == 3 and r == 3 and w == 1 then

        UnchainedHelper.marker(97698,53898,47113, "chain", "1",true) -- cold mage
        UnchainedHelper.marker(99234,53909,49000, "chain", "2",true) -- infuser
        UnchainedHelper.marker(96027,53908,51601, "chain", "3",false) -- cold mage
        UnchainedHelper.marker(96599,53917,47065, "chain", "4",true) -- infuser

        UnchainedHelper.marker(97037,53906,49474, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 2
        end
    elseif s == 3 and r == 3 and w == 2 then

        UnchainedHelper.marker(99271,53908,48506, "elite", "6",false) -- Gargoyle

        if UnchainedHelper.savedVars.highDps332 then
            -- note: techically these sawns are part of 3.3.3 however with high dps they spawn almost at the same time as 3.3.2
            UnchainedHelper.marker(97698,53898,47113, "chain", "1",true) -- cold mage
            UnchainedHelper.marker(97440,53909,51627, "chain", "2",true) -- coldmage
            UnchainedHelper.marker(96599,53917,47065, "chain", "3",true) -- infuser

            UnchainedHelper.marker(96204,53905,47039, "nochain", "4",false) -- bloodfiend
            UnchainedHelper.marker(99234,53909,49000, "nochain", "5",false) -- bloodfiend
            UnchainedHelper.marker(96027,53908,51601, "nochain", "6",false) -- bloodfiend
        end

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 3

        end

    elseif s == 3 and r == 3 and w == 3 then

        UnchainedHelper.marker(97698,53898,47113, "chain", "1",true) -- cold mage
        UnchainedHelper.marker(97440,53909,51627, "chain", "2",true) -- coldmage
        UnchainedHelper.marker(96599,53917,47065, "chain", "3",true) -- infuser

        UnchainedHelper.marker(96204,53905,47039, "nochain", "4",false) -- bloodfiend
        UnchainedHelper.marker(99234,53909,49000, "nochain", "5",false) -- bloodfiend
        UnchainedHelper.marker(96027,53908,51601, "nochain", "6",false) -- bloodfiend



        UnchainedHelper.marker(97037,53906,49474, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 1
        end



    elseif s == 3 and r == 4 and w == 1 then

        UnchainedHelper.marker(96204,53905,47039, "chain", "1",true) -- Infuser
        UnchainedHelper.marker(99234,53909,49000, "chain", "2",true) -- Infuser
        UnchainedHelper.marker(97440,53909,51627, "chain", "3",true) -- Infuser
        UnchainedHelper.marker(96027,53908,51601, "chain", "4",false) -- Infuser

        UnchainedHelper.marker(97698,53898,47113, "nochain", "5",false) -- Bat
        UnchainedHelper.marker(99271,53908,48506, "nochain", "6",false) -- Bloodfiend
        UnchainedHelper.marker(96599,53917,47065, "nochain", "7",false) -- Bat
        UnchainedHelper.marker(96337,53916,51631, "nochain", "8",false) -- Bloodfiend

        UnchainedHelper.marker(97037,53906,49474, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 2
            if UnchainedHelper.savedVars.hintsInChatArena3 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UH:3.4.1: dps AOE 4 Infuser stack, ulti, bash")
            end
        end


    elseif s == 3 and r == 4 and w == 2 then

        UnchainedHelper.marker(99271,53908,48506, "chain", "1",true) -- cold mage
        UnchainedHelper.marker(96599,53917,47065, "chain", "2",true) -- cold mage

        UnchainedHelper.marker(97037,53906,49474, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 3
        end


    elseif s == 3 and r == 4 and w == 3 then


        UnchainedHelper.marker(96204,53905,47039, "elite", "1",false) -- gargoyle
        UnchainedHelper.marker(97440,53909,51627, "elite", "2",false) -- gargoyle

        UnchainedHelper.marker(96754,53893,47759, "group", "",false) -- group
        UnchainedHelper.marker(97037,53906,49474, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 5
            UnchainedHelper.nextWave = 1
            if UnchainedHelper.savedVars.hintsInChatArena3 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UG3.4.3: charge left gargoyle after AOE drops, no big ult")
            end
        end


    elseif s == 3 and r == 5 and w == 1 then

        UnchainedHelper.marker(97038,53900,49381, "boss", "1",false) -- lady minara

        UnchainedHelper.marker(97471,53903,49410, "tank", "",false) -- group

        UnchainedHelper.marker(96759,53912,49394, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds/2) * 1000 -- remove icons after X seconds

            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds

            UnchainedHelper.nextStage = 4
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 1

            if UnchainedHelper.savedVars.hintsInChatArena3 and (UnchainedHelper.savedVars.tankHints) then
                d("UG3.5.1: tank take swarm out of center then return directly to stack, turn Minara around quickly as she cleaves")
                d("UG3.5.1: tank chaining adds in priority over colosus taunt")
            end
            if UnchainedHelper.savedVars.hintsInChatArena3 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UG3.5.1: dps help bash Minara, dodge colosus heavy and focus, save ultimates for the moment the 3rd colosus dies (or nearly dead), burn ~35% to 0 before 4th colosus")
            end
        end
    elseif s == 4 and r == 1 and w == 1 then

        UnchainedHelper.marker(106159,50675,38636, "nochain", "1",false) -- footsoldier
        UnchainedHelper.marker(110637,50693,38991, "nochain", "2",false) -- foot

        UnchainedHelper.marker(106210,50675,37042, "chain", "3",true) -- spider

        UnchainedHelper.marker(110767,50694,37519, "chain", "4",true) -- spider

        UnchainedHelper.marker(108147,50695,35527, "elite", "5",false) -- cleaver

        UnchainedHelper.marker(108360,50675,36934, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 2
        end

    elseif s == 4 and r == 1 and w == 2 then


        UnchainedHelper.marker(110767,50694,37519, "chain", "1",false) -- Infuser

        UnchainedHelper.marker(107711,50682,35435, "nochain", "2",false) -- Crocodile

        UnchainedHelper.marker(110684,50676,38578, "elite", "3",false) -- Incenerator
        UnchainedHelper.marker(106222,50677,38148, "elite", "4",false) -- Incenerator

        UnchainedHelper.marker(109838,50675,38169, "tank", "",false) -- tank

        UnchainedHelper.marker(106826,50675,38114, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 3
        end


    elseif s == 4 and r == 1 and w == 3 then

        UnchainedHelper.marker(106210,50675,37042, "chain", "1",true) -- Hover

        UnchainedHelper.marker(110767,50694,37519, "chain", "2",true) -- Horver

        UnchainedHelper.marker(110684,50676,38578, "nochain", "3",false) -- Bloodfiend
        UnchainedHelper.marker(106222,50677,38148, "nochain", "4",false) -- Bloodfiend

        UnchainedHelper.marker(108147,50695,35527, "boss", "5",false) -- Beastmaster

        UnchainedHelper.marker(108369,50675,37029, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 1
        end

    elseif s == 4 and r == 2 and w == 1 then


        UnchainedHelper.marker(106210,50675,37042, "nochain", "1",false) -- archer

        UnchainedHelper.marker(110767,50694,37519, "nochain", "2",false) -- archer

        UnchainedHelper.marker(108147,50695,35527, "elite", "3",false) -- cleaver
        UnchainedHelper.marker(106159,50675,38636, "elite", "4",false) -- incinerator

        UnchainedHelper.marker(108638,50675,37960, "tank", "",false) -- tank

        UnchainedHelper.marker(106807,50675,38642, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 2
            if UnchainedHelper.savedVars.hintsInChatArena4 and (UnchainedHelper.savedVars.tankHints) then
                d("UG4.2.1: tank stay mid, taunt archers, cleaver but do not chain")
            end
            if UnchainedHelper.savedVars.hintsInChatArena4 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints) then
                d("UG4.2.1: dps single target Mage, then single target cleaver avoid archers")
            end
        end

    elseif s == 4 and r == 2 and w == 2 then

        UnchainedHelper.marker(106159,50675,38636, "nochain", "1",false) -- footsoldier
        UnchainedHelper.marker(108147,50695,35527, "nochain", "2",false) -- footsoldier

        UnchainedHelper.marker(107711,50682,35435, "nochain", "3",true) -- archer

        UnchainedHelper.marker(110767,50694,37519, "elite", "4",false) -- dreadknight

        UnchainedHelper.marker(108656,50675,37895, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 3
            if UnchainedHelper.savedVars.hintsInChatArena4 and (UnchainedHelper.savedVars.tankHints) then
                d("UG4.2.2: taunt dreadnight and footsoldiers as possible, wait for dreadknight to be around 50% to chain in archers")
            end
            if UnchainedHelper.savedVars.hintsInChatArena4 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UG4.2.2: dps/tank - goal is to kill the dreadknight and archers at the same time as the archer deaths triggers the boss spawn")
            end
        end
    elseif s == 4 and r == 2 and w == 3 then

        UnchainedHelper.marker(106159,50675,38636, "elite", "1",false) -- incinerator

        UnchainedHelper.marker(108484,50676,37765,"boss", "2",false) -- boss spawn

        UnchainedHelper.marker(108737,50675,37764, "group", "",false) -- three
        UnchainedHelper.marker(108319,50675,37783, "group", "",false) -- four
        UnchainedHelper.marker(108494,50675,37944, "group", "",false) -- group

        UnchainedHelper.marker(110684,50676,38578, "elite", "3",false) -- incinerator

        if UnchainedHelper.savedVars.tankPosition then
        UnchainedHelper.marker(108472,50675,37441, "tank", "",false) -- tank
        end


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds/2) * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 1
            if UnchainedHelper.savedVars.hintsInChatArena4 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UH4.2.3: strat1: tank or healer stand facing both mages and interrupt both mages, until boss dies")
                d("UH4.2.3: strat2: dps burn boss at spawn fast, healer heals thru the mage channels")
                d("UH4.2.3: strat3: tank bring boss to right mage, where dps + tank kill it, while healer goes to left mage and bashes")
                d("UH4.2.3: strat4: healer taunts mages and drags them over the boss spawn where it dies")
            end
        end


    elseif s == 4 and r == 3 and w == 1 then

        UnchainedHelper.marker(106159,50675,38636, "nochain", "1",false) -- hackwing
        UnchainedHelper.marker(106210,50675,37042, "nochain", "2",false) -- hackwing

        UnchainedHelper.marker(110767,50694,37519, "nochain", "3",false) -- hackwing
        UnchainedHelper.marker(110637,50693,38991, "nochain", "4",false) -- hackwing

        UnchainedHelper.marker(108147,50695,35527, "elite", "5",false) -- beastmaster



        UnchainedHelper.marker(108375,50675,36853, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 2
        end
    elseif s == 4 and r == 3 and w == 2 then


        UnchainedHelper.marker(108147,50695,35527, "chain", "1",true) -- spider
        UnchainedHelper.marker(110767,50694,37519, "chain", "2",false) -- spider
        UnchainedHelper.marker(110637,50693,38991, "chain", "3",false) -- spider
        UnchainedHelper.marker(107711,50682,35435, "chain", "4",true) -- spider

        UnchainedHelper.marker(106159,50675,38636, "elite", "5",false) -- Haj

        UnchainedHelper.marker(108656,50675,37895, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 3
            if UnchainedHelper.savedVars.hintsInChatArena4 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UH4.3.2: dps burn Haj, if ult wait for charge, face Haj for 50% more damage")
            end
        end
    elseif s == 4 and r == 3 and w == 3 then

        UnchainedHelper.marker(108525,50675,37765, "boss", "1",false) -- tames

        UnchainedHelper.marker(108147,50695,35527, "nochain", "2",false) -- crocodile
        UnchainedHelper.marker(110684,50676,38578, "nochain", "3",false) -- crocodile

        UnchainedHelper.marker(108491,50675,37475,  "tank", "",false) -- tank

        UnchainedHelper.marker(108514,50675,37902, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds/2) * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 1
            if UnchainedHelper.savedVars.hintsInChatArena4 and (UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UH4.3.2: dps burn tames ignore all others")
            end
        end



    elseif s == 4 and r == 4 and w == 1 then

        UnchainedHelper.marker(108147,50695,35527, "chain", "1",true) -- cold mage

        UnchainedHelper.marker(106159,50675,38636, "nochain", "2",false) -- bloodfiend
        UnchainedHelper.marker(106210,50675,37042, "nochain", "3",false) -- bat

        UnchainedHelper.marker(110767,50694,37519, "nochain", "4",false) -- bat
        UnchainedHelper.marker(110637,50693,38991, "nochain", "5",false) -- bloodfiend

        UnchainedHelper.marker(108656,50675,37895, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 2
        end
    elseif s == 4 and r == 4 and w == 2 then

        UnchainedHelper.marker(106210,50675,37042, "chain", "1",true) -- Infuser
        UnchainedHelper.marker(108147,50695,35527, "chain", "2",true) -- Infuser

        UnchainedHelper.marker(110637,50693,38991, "elite", "3",false) -- gargoyle

        UnchainedHelper.marker(108656,50675,37895, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 3
        end
    elseif s == 4 and r == 4 and w == 3 then

        UnchainedHelper.marker(106159,50675,38636, "chain", "1",true) -- infuser

        UnchainedHelper.marker(110637,50693,38991, "chain", "2",true) -- coldmage

        UnchainedHelper.marker(108525,50675,37765, "elite", "3",false) -- minara

        UnchainedHelper.marker(108491,50675,37475,  "tank", "",false) -- tank

        UnchainedHelper.marker(108514,50675,37902, "group", "",false) -- group



        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 5
            UnchainedHelper.nextWave = 1
            if UnchainedHelper.savedVars.hintsInChatArena4 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UH4.4.3: tank chain in adds, dps burn Minara")
            end
        end

   elseif s == 4 and r == 5 and w == 1 then

        UnchainedHelper.marker(108126,50675,37531,"boss", "1",false) -- boss spawn

        UnchainedHelper.marker(107872,50675,37583, "group", "",false) -- group

        UnchainedHelper.marker(109218,50675,37836, "tank", "",false) -- tank



        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds/2) * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 5
            UnchainedHelper.nextWave = 2
            if UnchainedHelper.savedVars.hintsInChatArena4 and (UnchainedHelper.savedVars.tankHints) then
                d("UH4.5.1: tank move boss 1 to next to Tames spawm")
            end
            if UnchainedHelper.savedVars.hintsInChatArena4 and (UnchainedHelper.savedVars.dpsHints) then
                d("UH4.5.1: dps Battlemage such that Tames will be in AOE")
            end
        end
   elseif s == 4 and r == 5 and w == 2 then

        UnchainedHelper.marker(109032,50675,37540,"boss", "",false) -- tames spawn


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds/2) * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 5
            UnchainedHelper.nextWave = 3
            if UnchainedHelper.savedVars.hintsInChatArena4 and (UnchainedHelper.savedVars.tankHints) then
                d("UH4.5.2: tank try to hold adds mid, if possible face Haj away from group")
            end
            if UnchainedHelper.savedVars.hintsInChatArena4 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UH4.5.2: dps on Tames spawn tab target, all ultimates, cleave Battlemage before second meteor")
            end
        end
   elseif s == 4 and r == 5 and w == 3 then

        UnchainedHelper.marker(108524,50675,37267,"boss", "",false) -- minara spawn



        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds/2) * 1000 -- remove icons after X seconds

            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds

            UnchainedHelper.nextStage = 5
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 1


            if UnchainedHelper.savedVars.hintsInChatArena4 and (UnchainedHelper.savedVars.tankHints) then
                d("UH4.5.3: tank taunt Minara, hopefully your dps will be done with Tames soon")
                d("UH4.5.3: tank chain Minara's adds, prevent Minara from spawning colosus")
            end
        end


   elseif s == 5 and r == 1 and w == 1 then

        UnchainedHelper.marker(96253,48130,32732, "chain", "1",true) -- convict
        UnchainedHelper.marker(96371,48125,28909, "chain", "2",true) -- convict

        UnchainedHelper.marker(95348,48132,32684, "nochain", "3",false) -- prisoner
        UnchainedHelper.marker(95566,48112,28918, "nochain", "4",false) -- prisoner



        UnchainedHelper.marker(95631,48088,30679, "tank", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 2
            if UnchainedHelper.savedVars.hintsInChatArena5 and (UnchainedHelper.savedVars.tankHints) then
                d("UH5.1.1: taunt prisoner x2, use chain on convicts as they channel to interrupt x2 (this strat repeats)")
            end

        end


   elseif s == 5 and r == 1 and w == 2 then

        UnchainedHelper.marker(95858,48142,32705, "chain", "1",true) -- convict
        UnchainedHelper.marker(95910,48142,28889, "chain", "2",true) -- convict

        UnchainedHelper.marker(96755,48120,30730, "elite", "3",false) -- soul void

        UnchainedHelper.marker(95631,48088,30679, "tank", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 3
        end
   elseif s == 5 and r == 1 and w == 3 then


        UnchainedHelper.marker(95588,48095,31201, "boss", "1",false) -- vengefull revenant boss

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds/2) * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 1
            if UnchainedHelper.savedVars.hintsInChatArena5 and (UnchainedHelper.savedVars.dpsHints) then
                d("UH5.1.3: dps burn boss/adds, ignore totem")
            end
        end
   elseif s == 5 and r == 2 and w == 1 then

        UnchainedHelper.marker(96253,48130,32732, "nochain", "1",false) -- prisoner
        UnchainedHelper.marker(96371,48125,28909, "nochain", "2",false) -- prisoner

        UnchainedHelper.marker(95631,48091,30258, "elite", "3",false) -- soul void

        UnchainedHelper.marker(95631,48088,30679, "tank", "",false) -- group



        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 2
        end
   elseif s == 5 and r == 2 and w == 2 then

        UnchainedHelper.marker(96253,48130,32732, "nochain", "1",false) -- prisoner

        UnchainedHelper.marker(96755,48120,30730, "boss", "2",false) -- vengefull revenant boss


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds/2) * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 2
            UnchainedHelper.nextWave = 3
        end
   elseif s == 5 and r == 2 and w == 3 then

        UnchainedHelper.marker(95858,48142,32705, "chain", "1",true) -- convict
        UnchainedHelper.marker(95910,48142,28889, "chain", "2",true) -- convict

        UnchainedHelper.marker(95588,48095,31201, "elite", "3",false) -- soul void

        UnchainedHelper.marker(95631,48088,30679, "tank", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 1
            if UnchainedHelper.savedVars.hintsInChatArena5 and (UnchainedHelper.savedVars.dpsHints) then
                d("UH5.2.3: dps burn adds, ignore totem")
            end
        end

   elseif s == 5 and r == 3 and w == 1 then

        UnchainedHelper.marker(95566,48112,28918, "nochain", "1",false) -- prisoner

        UnchainedHelper.marker(95858,48142,32705, "chain", "2",true) -- convict
        UnchainedHelper.marker(95910,48142,28889, "chain", "3",true) -- convict

        UnchainedHelper.marker(95631,48091,30258, "elite", "4",false) -- soul void

        UnchainedHelper.marker(95631,48088,30679, "tank", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 2
        end
   elseif s == 5 and r == 3 and w == 2 then

        UnchainedHelper.marker(95858,48142,32705, "elite", "1",false) -- soul void
        UnchainedHelper.marker(95910,48142,28889, "elite", "2",false) -- soul void

        UnchainedHelper.marker(96755,48120,30730, "chain", "3",true) -- convict

        UnchainedHelper.marker(95631,48088,30679, "tank", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 3
            UnchainedHelper.nextWave = 3
        end


   elseif s == 5 and r == 3 and w == 3 then

        UnchainedHelper.marker(96253,48130,32732, "nochain", "1",false) -- prisoner

        UnchainedHelper.marker(96371,48125,28909, "chain", "2",true) -- convict

        UnchainedHelper.marker(95588,48095,31201, "boss", "3",false) -- vengefull


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 1
            if UnchainedHelper.savedVars.hintsInChatArena5 and (UnchainedHelper.savedVars.dpsHints) then
                d("UH5.3.3: dps boss/adds, ignore totem")
            end
        end

   elseif s == 5 and r == 4 and w == 1 then

        UnchainedHelper.marker(95348,48132,32684, "chain", "1",true) -- convict
        UnchainedHelper.marker(95566,48112,28918, "chain", "2",true) -- convict

        UnchainedHelper.marker(95858,48142,32705, "nochain", "3",false) -- prisoner
        UnchainedHelper.marker(95910,48142,28889, "nochain", "4",false) -- prisoner

        UnchainedHelper.marker(95631,48091,30258, "elite", "5",false) -- soul void

        UnchainedHelper.marker(95631,48088,30679, "tank", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 2
        end
   elseif s == 5 and r == 4 and w == 2 then

        UnchainedHelper.marker(96371,48125,28909, "nochain", "1",false) -- prisoner
        UnchainedHelper.marker(96253,48130,32732, "nochain", "2",false) -- prisoner

        UnchainedHelper.marker(95348,48132,32684, "elite", "3",false) -- soul void
        UnchainedHelper.marker(95566,48112,28918, "elite", "4",false) -- soul void


        UnchainedHelper.marker(95631,48088,30679, "tank", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 3
        end



   elseif s == 5 and r == 4 and w == 3 then

        UnchainedHelper.marker(95566,48112,28918, "nochain", "1",false) -- prisoner

        UnchainedHelper.marker(95858,48142,32705, "chain", "2",true) -- convict
        UnchainedHelper.marker(95910,48142,28889, "chain", "3",true) -- convict

        UnchainedHelper.marker(95588,48095,31201, "boss", "4",false) -- boss


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 5
            UnchainedHelper.nextWave = 1
            if UnchainedHelper.savedVars.hintsInChatArena5 and (UnchainedHelper.savedVars.dpsHints) then
                d("UH5.4.3: dps boss/adds, ignore totem")
            end
        end
   elseif s == 5 and r == 5 and w == 1 then

        UnchainedHelper.marker(96014,48098,30701, "boss", "1",false) -- boss

        UnchainedHelper.marker(95666,48090,30661, "tank", "",false) -- tank

        UnchainedHelper.marker(96171,48097,30710, "group", "",false) -- group


        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds/2) * 1000 -- remove icons after X seconds
            if UnchainedHelper.savedVars.hintsInChatArena5 and (UnchainedHelper.savedVars.dpsHints) then
                d("UH5.5.1: one dps range totems, other dps stay on boss")
            end
            if UnchainedHelper.savedVars.hintsInChatArena5 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UH5.5.1: Drakeeh jumps are brought to middle, everyone get out then go back in (except for jumps during ghost phase)")
            end
            if UnchainedHelper.savedVars.hintsInChatArena5 and (UnchainedHelper.savedVars.tankHints or UnchainedHelper.savedVars.dpsHints or UnchainedHelper.savedVars.healerHints) then
                d("UH5.5.1: healer if you have one, let Drakeeh channel for more dps, just stand in voids, major breach totems")
            end
        end
   end
end





-- Optional permanent cardinal navigation markers.
-- These are independent of wave marker semantics and never appear in the marker legend.
local UH_CARDINAL_DATA = {
    [1] = { x = 104277, y = 60952, z = 68420, radius = 2200 },
    [2] = { x = 90602,  y = 57151, z = 62761, radius = 2200 },
    [3] = { x = 97649,  y = 53908, z = 49332, radius = 2200 },
    [4] = { x = 108463, y = 50685, z = 37213, radius = 2200 },
    [5] = { x = 96052,  y = 48116, z = 30811, radius = 2200 },
}

local UH_CARDINAL_TEXTURES = {
    N = "UnchainedHelper/icons/cardinal_n.dds",
    E = "UnchainedHelper/icons/cardinal_e.dds",
    S = "UnchainedHelper/icons/cardinal_s.dds",
    W = "UnchainedHelper/icons/cardinal_w.dds",
}

function UnchainedHelper.ClearCardinalMarkerRefs()
    UnchainedHelper.cardinalMarkers = {}
    UnchainedHelper.cardinalStage = 0
end

function UnchainedHelper.DestroyCardinalMarkers()
    local cardinalSet = {}
    for _, marker in ipairs(UnchainedHelper.cardinalMarkers or {}) do
        cardinalSet[marker] = true
        if marker and marker.control then
            marker.control:SetHidden(true)
            marker.control:SetHandler("OnUpdate", nil)
            if marker.control.Destroy3DRenderSpace then marker.control:Destroy3DRenderSpace() end
            if WINDOW_MANAGER and WINDOW_MANAGER.DestroyControl then
                WINDOW_MANAGER:DestroyControl(marker.control)
            end
            marker.control = nil
        end
    end

    if UnchainedHelper.SpaceMarkers and UnchainedHelper.SpaceMarkers.active then
        local kept = {}
        for _, marker in ipairs(UnchainedHelper.SpaceMarkers.active) do
            if not cardinalSet[marker] then
                table.insert(kept, marker)
            end
        end
        UnchainedHelper.SpaceMarkers.active = kept
    end

    UnchainedHelper.ClearCardinalMarkerRefs()
end

function UnchainedHelper.RefreshCardinalMarkers(force)
    if not UnchainedHelper.savedVars or not UnchainedHelper.savedVars.enabled or not UnchainedHelper.savedVars.showCardinalMarkers then
        UnchainedHelper.DestroyCardinalMarkers()
        return
    end
    if not UnchainedHelper.IsInBlackrose or not UnchainedHelper.IsInBlackrose() then
        UnchainedHelper.DestroyCardinalMarkers()
        return
    end
    if not UnchainedHelper.HasMarkerRuntime or not UnchainedHelper.HasMarkerRuntime() then return end

    local stage = UnchainedHelper.GetCurrentStage and (UnchainedHelper.GetCurrentStage() or 0) or 0
    local data = UH_CARDINAL_DATA[stage]
    if not data then
        UnchainedHelper.DestroyCardinalMarkers()
        return
    end

    if not force and UnchainedHelper.cardinalStage == stage and #UnchainedHelper.cardinalMarkers == 4 then
        local allLive = true
        for _, marker in ipairs(UnchainedHelper.cardinalMarkers) do
            if not marker or not marker.control then
                allLive = false
                break
            end
        end
        if allLive then return end
    end

    UnchainedHelper.DestroyCardinalMarkers()

    local r = data.radius or 2200
    local height = UnchainedHelper.savedVars.markerHeight or 280
    local sizeMeters = ((UnchainedHelper.savedVars.markerSize or 175) / 100) * 1.15
    local facing = true
    local positions = {
        -- ESO map coordinates increase downward; in BRP world coordinates lower Z tracks north.
        N = { data.x,     data.y + height, data.z - r },
        E = { data.x + r, data.y + height, data.z     },
        S = { data.x,     data.y + height, data.z + r },
        W = { data.x - r, data.y + height, data.z     },
    }

    for _, key in ipairs({ "N", "E", "S", "W" }) do
        local p = positions[key]
        local marker = UnchainedHelper.SpaceMarkers.Create(p[1], p[2], p[3], UH_CARDINAL_TEXTURES[key], sizeMeters, nil, "", facing)
        if marker then
            marker.isCardinal = true
            marker.cardinalKey = key
            table.insert(UnchainedHelper.cardinalMarkers, marker)
        end
    end
    UnchainedHelper.cardinalStage = stage
end

function UnchainedHelper.GetCurrentStage()

	local x, y = GetMapPlayerPosition('player');

	if x > 0.54 and x < 0.64 and y > 0.79 and y < 0.89 then
		return 1
	elseif x > 0.3 and x < 0.4 and y > 0.69 and y < 0.8 then
		return 2
	elseif x > 0.41 and x < 0.52 and y > 0.43 and y < 0.53 then
		return 3
	elseif x > 0.63 and x < 0.73 and y > 0.22 and y < 0.32 then
		return 4
	elseif x > 0.4 and x < 0.5 and y > 0.08 and y < 0.18 then
		return 5
	else
		return 0
	end

end


function UnchainedHelper.ShowProgressCallout()
    if not UnchainedHelper.savedVars or not UnchainedHelper.savedVars.enabled then return end
    if UnchainedHelper.savedVars.showProgressCallouts == false then return end
    if UnchainedHelper.IsInBlackrose and not UnchainedHelper.IsInBlackrose() then return end

    local stage = 0
    if UnchainedHelper.GetCurrentStage then
        stage = UnchainedHelper.GetCurrentStage() or 0
    end
    local round = UnchainedHelper.currentRound or 0
    if stage <= 0 or round <= 0 then return end

    local key = tostring(stage) .. ":" .. tostring(round)
    if UnchainedHelper.lastProgressKey == key then return end
    UnchainedHelper.lastProgressKey = key

    d(string.format("Round: %d/5 - Stage: %d/5", round, stage))
end

function UnchainedHelper.Announcement(_, title, _)

	if title == 'Final Round' or title == 'Letzte Runde' or title == 'Dernière manche' or title == 'Последний раунд' or title == '最終ラウンド' then
		UnchainedHelper.currentRound = 5
		UnchainedHelper.currentWave = 0
	else
		local round = string.match(title, '^.+%s(%d)$')
		if round then
			UnchainedHelper.currentRound = tonumber(round)
			UnchainedHelper.currentWave = 0
		end
	end

    UnchainedHelper.ShowProgressCallout()
end



function UnchainedHelper.PortalSpawn(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)

	if result == ACTION_RESULT_EFFECT_GAINED then
		local t = GetGameTimeMilliseconds()
		if t - UnchainedHelper.lastPortalSpawn > 4000 then
			UnchainedHelper.currentWave = UnchainedHelper.currentWave + 1
			UnchainedHelper.NotifyNewWave(0)

        -- change from 4000 to 1000 because of 3.3.2 -> 3.3.3 transition which is very fast
        elseif UnchainedHelper.GetCurrentStage()==3 and UnchainedHelper.currentRound == 3 and UnchainedHelper.currentWave==2 and t - UnchainedHelper.lastPortalSpawn > 1000 then
            UnchainedHelper.currentWave = UnchainedHelper.currentWave + 1
			UnchainedHelper.NotifyNewWave(0)

		end
		UnchainedHelper.lastPortalSpawn = t
	end
end


function UnchainedHelper.ClearIcons(keepRequests, skipCardinals)
    UnchainedHelper.eraseIconTime = 0
    UnchainedHelper.iconsUp = false

    if UnchainedHelper.SpaceMarkers and UnchainedHelper.SpaceMarkers.Clear then
        UnchainedHelper.SpaceMarkers.Clear()
    end
    UnchainedHelper.ClearCardinalMarkerRefs()

    UnchainedHelper.activeIcons = {}
    if not keepRequests then
        UnchainedHelper.activeMarkerRequests = {}
    end
    UnchainedHelper.replayingMarkers = false
    UnchainedHelper.icon1 = nil
    UnchainedHelper.icon2 = nil
    UnchainedHelper.icon3 = nil
    UnchainedHelper.icon4 = nil
    UnchainedHelper.icon5 = nil
    UnchainedHelper.icon6 = nil
    UnchainedHelper.icon7 = nil
    UnchainedHelper.icon8 = nil
    UnchainedHelper.icon9 = nil
    UnchainedHelper.icon10 = nil
    if keepRequests then
        UnchainedHelper.RefreshLegend()
    else
        UnchainedHelper.HideLegend()
    end
    if not skipCardinals and UnchainedHelper.RefreshCardinalMarkers then
        UnchainedHelper.RefreshCardinalMarkers(true)
    end
end

function UnchainedHelper.HideTotemAlert()
    UnchainedHelper.totemAlertHideAt = 0
    if UnchainedHelperTotemAlert then
        UnchainedHelperTotemAlert:SetHidden(true)
    end
end

function UnchainedHelper.HideTotemTimer()
    UnchainedHelper.totemLastTimerText = nil
    if UnchainedHelperTotemTimer then
        UnchainedHelperTotemTimer:SetHidden(true)
    end
end

function UnchainedHelper.ResetTotemSmartTimer()
    UnchainedHelper.totemFirstSpawnAt = 0
    UnchainedHelper.totemLastSpawnAt = 0
    UnchainedHelper.totemLearnedInterval = 0
    UnchainedHelper.totemNextPredictedAt = 0
    UnchainedHelper.totemSpawnCount = 0
    UnchainedHelper.HideTotemTimer()
end

function UnchainedHelper.SetTotemTimerText(text, urgent)
    if not UnchainedHelper.savedVars or UnchainedHelper.savedVars.showTotemSmartTimer == false then
        UnchainedHelper.HideTotemTimer()
        return
    end
    if not UnchainedHelperTotemTimerText or not UnchainedHelperTotemTimer then return end
    if UnchainedHelper.totemLastTimerText ~= text then
        UnchainedHelper.totemLastTimerText = text
        UnchainedHelperTotemTimerText:SetText(text)
    end
    if UnchainedHelperTotemTimerText.SetColor then
        if urgent then
            UnchainedHelperTotemTimerText:SetColor(1.0, 0.56, 0.25, 1)
        else
            UnchainedHelperTotemTimerText:SetColor(0.96, 0.81, 0.45, 1)
        end
    end
    UnchainedHelperTotemTimer:SetHidden(false)
end

function UnchainedHelper.ShowTotemAlert(abilityId)
    if not UnchainedHelper.savedVars or UnchainedHelper.savedVars.showTotemAlert == false then return end
    if not UnchainedHelper.IsInBlackrose or not UnchainedHelper.IsInBlackrose() then return end

    if abilityId and abilityId > 0 and (UnchainedHelper.savedVars.totemAbilityId or 0) == 0 then
        UnchainedHelper.savedVars.totemAbilityId = abilityId
    end

    if UnchainedHelperTotemAlertText then
        UnchainedHelperTotemAlertText:SetText("TOTEM ACTIVE")
    end
    if UnchainedHelperTotemAlert then
        UnchainedHelperTotemAlert:SetHidden(false)
    end

    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    local seconds = UnchainedHelper.savedVars.totemAlertDuration or 3
    UnchainedHelper.totemAlertHideAt = now + (seconds * 1000)
end

function UnchainedHelper.RecordTotemSpawn(abilityId)
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0

    -- Barrage of Stone can generate multiple combat events from a single Totem.
    -- Treat events inside this window as one spawn.
    if UnchainedHelper.totemLastSpawnAt and UnchainedHelper.totemLastSpawnAt > 0 and now - UnchainedHelper.totemLastSpawnAt < 4000 then
        return
    end

    UnchainedHelper.lastTotemAlert = now
    UnchainedHelper.ShowTotemAlert(abilityId)

    if not UnchainedHelper.savedVars or UnchainedHelper.savedVars.showTotemSmartTimer == false then
        UnchainedHelper.totemLastSpawnAt = now
        return
    end

    UnchainedHelper.totemSpawnCount = (UnchainedHelper.totemSpawnCount or 0) + 1

    if not UnchainedHelper.totemFirstSpawnAt or UnchainedHelper.totemFirstSpawnAt == 0 then
        UnchainedHelper.totemFirstSpawnAt = now
        UnchainedHelper.totemLastSpawnAt = now
        UnchainedHelper.SetTotemTimerText("TOTEM TIMER: LEARNING 1/2", false)
        return
    end

    if not UnchainedHelper.totemLearnedInterval or UnchainedHelper.totemLearnedInterval <= 0 then
        local sample = now - UnchainedHelper.totemFirstSpawnAt
        -- Reject impossible/accidental samples, then restart learning from this Totem.
        if sample < 5000 or sample > 120000 then
            UnchainedHelper.totemFirstSpawnAt = now
            UnchainedHelper.totemLastSpawnAt = now
            UnchainedHelper.totemSpawnCount = 1
            UnchainedHelper.SetTotemTimerText("TOTEM TIMER: LEARNING 1/2", false)
            return
        end

        UnchainedHelper.totemLearnedInterval = sample
        UnchainedHelper.totemLastSpawnAt = now
        UnchainedHelper.totemNextPredictedAt = now + sample
        UnchainedHelper.SetTotemTimerText(string.format("NEXT TOTEM: ~%ds", math.max(1, math.floor(sample / 1000 + 0.5))), false)
        return
    end

    -- Every real Totem resynchronizes the forecast. If its spacing is close to the
    -- learned cadence, gently refine the interval instead of replacing it outright.
    local measured = now - (UnchainedHelper.totemLastSpawnAt or now)
    local learned = UnchainedHelper.totemLearnedInterval
    if measured >= learned * 0.70 and measured <= learned * 1.30 then
        learned = math.floor((learned * 0.75) + (measured * 0.25) + 0.5)
        UnchainedHelper.totemLearnedInterval = learned
    end
    UnchainedHelper.totemLastSpawnAt = now
    UnchainedHelper.totemNextPredictedAt = now + learned
end

function UnchainedHelper.UpdateTotemSmartTimer(now)
    if not UnchainedHelper.savedVars or UnchainedHelper.savedVars.showTotemSmartTimer == false then
        UnchainedHelper.HideTotemTimer()
        return
    end
    if not UnchainedHelper.IsInBlackrose or not UnchainedHelper.IsInBlackrose() then
        UnchainedHelper.ResetTotemSmartTimer()
        return
    end

    -- Totem of Stone belongs to Drakeeh's Cage (Stage 5). Keep the learned timer
    -- invisible everywhere else so an old sample cannot leak into another arena.
    local stage = UnchainedHelper.GetCurrentStage and (UnchainedHelper.GetCurrentStage() or 0) or 0
    if stage ~= 5 then
        if (UnchainedHelper.totemFirstSpawnAt or 0) > 0 then
            UnchainedHelper.ResetTotemSmartTimer()
        else
            UnchainedHelper.HideTotemTimer()
        end
        return
    end

    local first = UnchainedHelper.totemFirstSpawnAt or 0
    local interval = UnchainedHelper.totemLearnedInterval or 0
    if first <= 0 then
        UnchainedHelper.HideTotemTimer()
        return
    end

    if interval <= 0 then
        -- Do not leave a stale half-learned state forever if the second Totem never appears.
        if now - first > 120000 then
            UnchainedHelper.ResetTotemSmartTimer()
        else
            UnchainedHelper.SetTotemTimerText("TOTEM TIMER: LEARNING 1/2", false)
        end
        return
    end

    local nextAt = UnchainedHelper.totemNextPredictedAt or 0
    if nextAt <= 0 then
        nextAt = (UnchainedHelper.totemLastSpawnAt or now) + interval
        UnchainedHelper.totemNextPredictedAt = nextAt
    end

    local remainingMs = nextAt - now
    if remainingMs < -3000 then
        repeat
            nextAt = nextAt + interval
        until nextAt > now - 3000
        UnchainedHelper.totemNextPredictedAt = nextAt
        remainingMs = nextAt - now
    end

    if remainingMs <= 0 then
        UnchainedHelper.SetTotemTimerText("TOTEM EXPECTED", true)
    else
        local seconds = math.max(1, math.ceil(remainingMs / 1000))
        UnchainedHelper.SetTotemTimerText(string.format("NEXT TOTEM: ~%ds", seconds), seconds <= 5)
    end
end

function UnchainedHelper.TotemCombatEvent(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, combatEventLog, sourceUnitId, targetUnitId, abilityId)
    if not UnchainedHelper.savedVars then return end
    if UnchainedHelper.savedVars.showTotemAlert == false and UnchainedHelper.savedVars.showTotemSmartTimer == false then return end
    if not UnchainedHelper.IsInBlackrose or not UnchainedHelper.IsInBlackrose() then return end

    local learnedId = UnchainedHelper.savedVars.totemAbilityId or 0
    if learnedId > 0 then
        if abilityId == learnedId then
            UnchainedHelper.RecordTotemSpawn(abilityId)
        end
        return
    end

    local ability = zo_strlower and zo_strlower(abilityName or "") or string.lower(abilityName or "")
    local source = zo_strlower and zo_strlower(sourceName or "") or string.lower(sourceName or "")

    if string.find(ability, "barrage of stone", 1, true)
        or (string.find(source, "totem of stone", 1, true) and string.find(ability, "barrage", 1, true)) then
        if abilityId and abilityId > 0 then
            UnchainedHelper.savedVars.totemAbilityId = abilityId
        end
        UnchainedHelper.RecordTotemSpawn(abilityId)
    end
end

function UnchainedHelper.RegisterTotemDetector()
    local eventName = UnchainedHelper.name .. "TotemDetector"
    EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_COMBAT_EVENT)
    if not UnchainedHelper.savedVars then return end
    if UnchainedHelper.savedVars.showTotemAlert == false and UnchainedHelper.savedVars.showTotemSmartTimer == false then return end

    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, UnchainedHelper.TotemCombatEvent)
    EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)

    local learnedId = UnchainedHelper.savedVars.totemAbilityId or 0
    if learnedId > 0 then
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, learnedId)
    end
end

function UnchainedHelper.UpdateTimer()
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    if UnchainedHelper.totemAlertHideAt and UnchainedHelper.totemAlertHideAt > 0 and now >= UnchainedHelper.totemAlertHideAt then
        UnchainedHelper.HideTotemAlert()
    end
    UnchainedHelper.UpdateTotemSmartTimer(now)

    if UnchainedHelper.eraseIconTime==0 or UnchainedHelper.eraseIconTime > GetGameTimeMilliseconds() then
    else
       UnchainedHelper.ClearIcons()
    end

    if UnchainedHelper.drawNextFightIconTime==0 or UnchainedHelper.drawNextFightIconTime > GetGameTimeMilliseconds() then
    else
       UnchainedHelper.NotifyNewWave(1)
    end

    if UnchainedHelper.RefreshCardinalMarkers then
        UnchainedHelper.RefreshCardinalMarkers(false)
    end
end


function UnchainedHelper.UnregisterZoneEvents()
    UnchainedHelper.HideSpawnCallout()
    EVENT_MANAGER:UnregisterForEvent(UnchainedHelper.name .. "Ability" .. 114578, EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent(UnchainedHelper.name .. "Announcement", EVENT_DISPLAY_ANNOUNCEMENT)
    EVENT_MANAGER:UnregisterForUpdate(UnchainedHelper.name.."Update")
    EVENT_MANAGER:UnregisterForEvent(UnchainedHelper.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE)
    EVENT_MANAGER:UnregisterForEvent(UnchainedHelper.name.."ECE"..109992, EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent(UnchainedHelper.name.."ECE"..113150, EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent(UnchainedHelper.name .. "TotemDetector", EVENT_COMBAT_EVENT)
    UnchainedHelper.HideTotemAlert()
    UnchainedHelper.ResetTotemSmartTimer()
    UnchainedHelper.ClearIcons(false, true)
end

function UnchainedHelper.PlayerActivated()
    -- PlayerActivated can fire more than once on console. Always reset our registrations first
    -- so we do not duplicate chat output, combat-event callbacks, or marker timers.
    UnchainedHelper.UnregisterZoneEvents()

	if GetZoneId(GetUnitZoneIndex("player")) == 1082 and UnchainedHelper.savedVars.enabled then
	    d("Unchained Helper Active "..UnchainedHelper.version)

        if not UnchainedHelper.HasMarkerRuntime() then
            UnchainedHelper.WarnMissingMarkerRuntime(true)
        end

        EVENT_MANAGER:RegisterForEvent(UnchainedHelper.name .. "Ability" .. 114578, EVENT_COMBAT_EVENT, UnchainedHelper.PortalSpawn)
	    EVENT_MANAGER:AddFilterForEvent(UnchainedHelper.name .. "Ability" .. 114578, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 114578)

        EVENT_MANAGER:RegisterForEvent(UnchainedHelper.name .. "Announcement", EVENT_DISPLAY_ANNOUNCEMENT, UnchainedHelper.Announcement)
        EVENT_MANAGER:RegisterForUpdate(UnchainedHelper.name.."Update", 1000, UnchainedHelper.UpdateTimer)
      	EVENT_MANAGER:RegisterForEvent(UnchainedHelper.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, UnchainedHelper.OnPlayerCombatState)

        EVENT_MANAGER:RegisterForEvent(UnchainedHelper.name.."ECE"..109992, EVENT_COMBAT_EVENT, UnchainedHelper.combatEvent)
        EVENT_MANAGER:AddFilterForEvent(UnchainedHelper.name.."ECE"..109992, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 109992, REGISTER_FILTER_IS_ERROR, false)

        EVENT_MANAGER:RegisterForEvent(UnchainedHelper.name.."ECE"..113150, EVENT_COMBAT_EVENT, UnchainedHelper.combatEvent)
        EVENT_MANAGER:AddFilterForEvent(UnchainedHelper.name.."ECE"..113150, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 113150, REGISTER_FILTER_IS_ERROR, false)

        UnchainedHelper.RegisterTotemDetector()


        UnchainedHelperFramePurge:SetText("")
        UnchainedHelperFrame:SetHidden(true)



        -- Normal Blackrose uses the same zone and fixed world-coordinate table.
        -- Normal Blackrose marker preview is allowed when enabled.
        if UnchainedHelper.savedVars.previewOnEntry then
            UnchainedHelper.nextStage = 1
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 1
            UnchainedHelper.NotifyNewWave(1)
        end

        if UnchainedHelper.RefreshCardinalMarkers then
            UnchainedHelper.RefreshCardinalMarkers(true)
        end

    else

        UnchainedHelper.UnregisterZoneEvents()

        UnchainedHelperFramePurge:SetText("")
        UnchainedHelperFrame:SetHidden(true)
        if UnchainedHelperLegend then UnchainedHelperLegend:SetHidden(true) end


    end
end

function UnchainedHelper.Init(event, addon)
	if addon ~= UnchainedHelper.name then return end

	UnchainedHelper.inCombat = IsUnitInCombat("player")

	UnchainedHelper.currentPurgeable=0

    UnchainedHelper.savedVars = ZO_SavedVars:New(UnchainedHelper.name.."SavedVars", UnchainedHelper.varVersion, nil, UnchainedHelper.defaults)
    UnchainedHelper.setPos()
    UnchainedHelper.UpdateSpawnCalloutPosition()
    UnchainedHelper.InstallSigilBlocker()
    UnchainedHelper.UpdateLegendPosition()
    UnchainedHelper.RefreshLegend()
	UnchainedHelper.setupMenu()

	EVENT_MANAGER:UnregisterForEvent(UnchainedHelper.name.."Load", EVENT_ADD_ON_LOADED)
	EVENT_MANAGER:RegisterForEvent(UnchainedHelper.name .. "_PlayerActivated", EVENT_PLAYER_ACTIVATED, UnchainedHelper.PlayerActivated)
    EVENT_MANAGER:RegisterForEvent(UnchainedHelper.name .. "_ZoneChanged", EVENT_ZONE_CHANGED, function()
        if UnchainedHelper.SpaceMarkers and UnchainedHelper.SpaceMarkers.RefreshPositions then
            UnchainedHelper.SpaceMarkers.RefreshPositions()
        end
        if not UnchainedHelper.IsInBlackrose or not UnchainedHelper.IsInBlackrose() then
            if UnchainedHelper.HideLegend then UnchainedHelper.HideLegend() end
        end
    end)
end

EVENT_MANAGER:RegisterForEvent(UnchainedHelper.name.."Load", EVENT_ADD_ON_LOADED, UnchainedHelper.Init)











--[[
    --------------- ARENA 5 TEMPLATE ----------------
    elseif s == 5 and r == 6 and w == 6 then

        UnchainedHelper.marker(96253,48130,32732, "1",false) -- one
        UnchainedHelper.marker(95348,48132,32684, "2",false) -- two
        UnchainedHelper.marker(95566,48112,28918, "3",false) -- three
        UnchainedHelper.marker(96371,48125,28909, "4",false) -- four
        UnchainedHelper.marker(95858,48142,32705, "5",false) -- five
        UnchainedHelper.marker(95910,48142,28889, "6",false) -- six
        UnchainedHelper.marker(96755,48120,30730, "7",false) -- seven
        UnchainedHelper.marker(95588,48095,31201, "8",false) -- eight
        UnchainedHelper.marker(95631,48091,30258, "9",false) -- nine
        UnchainedHelper.marker(96244,48099,30895, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 2
        end





    --------------- ARENA 4 TEMPLATE ----------------
    elseif s == 4 and r == 6 and w == 6 then

        UnchainedHelper.marker(106159,50675,38636, "1",false) -- one
        UnchainedHelper.marker(106210,50675,37042, "2",false) -- two
        UnchainedHelper.marker(108147,50695,35527, "3",false) -- three
        UnchainedHelper.marker(110767,50694,37519, "4",false) -- four
        UnchainedHelper.marker(110637,50693,38991, "5",false) -- five
        UnchainedHelper.marker(110684,50676,38578, "6",false) -- six
        UnchainedHelper.marker(106222,50677,38148, "7",false) -- seven
        UnchainedHelper.marker(107711,50682,35435, "8",false) -- eight
        UnchainedHelper.marker(0,53916,51631, "9",false) -- nine
        UnchainedHelper.marker(108656,50675,37895, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 2
        end



    --------------- ARENA 3 TEMPLATE ----------------
    elseif s == 3 and r == 6 and w == 6 then

        UnchainedHelper.marker(97698,53898,47113, "1","",false) -- one
        UnchainedHelper.marker(96204,53905,47039, "2","",false) -- two
        UnchainedHelper.marker(99234,53909,49000, "3","",false) -- three
        UnchainedHelper.marker(97440,53909,51627, "4","",false) -- four
        UnchainedHelper.marker(96027,53908,51601, "5","",false) -- five
        UnchainedHelper.marker(99271,53908,48506, "6","",false) -- six
        UnchainedHelper.marker(96599,53917,47065, "7","",false) -- seven
        UnchainedHelper.marker(96579,53925,51589, "8","",false) -- eight
        UnchainedHelper.marker(96337,53916,51631, "9","",false) -- nine
        UnchainedHelper.marker(97037,53906,49474, "group", "",false) -- group

        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 2
        end




    --------------- ARENA 2 TEMPLATE ----------------
    elseif s == 2 and r == 6 and w == 6 then
        UnchainedHelper.marker(92967,57153,63974, "1",false) -- one
        UnchainedHelper.marker(90086,57147,61117, "2",false) -- two
        UnchainedHelper.marker(88345,57153,64110, "3",false) -- three
        UnchainedHelper.marker(88236,57144,62666, "4",false) -- four
        UnchainedHelper.marker(92962,57149,64405, "5",false) -- five
        UnchainedHelper.marker(92896,57158,62884, "6",false) -- six
        UnchainedHelper.marker(88304,57154,63792, "7",false) -- seven
        UnchainedHelper.marker(89784,57152,61143, "8",false) -- eight
        UnchainedHelper.marker(89653,57151,61676, "group", "",false) -- group
        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 1
            UnchainedHelper.nextWave = 2
        end


    --------------- ARENA 1 TEMPLATE ----------------
    elseif s == 1 and r == 6 and w == 6 then
        UnchainedHelper.marker(104111,60951,70730, "1",false) -- one
        UnchainedHelper.marker(103023,60951,70699, "2",false) -- two
        UnchainedHelper.marker(102669,60951,70674, "3",false) -- three
        UnchainedHelper.marker(104147,60951,66109, "4",false) -- four
        UnchainedHelper.marker(102946,60951,66175, "5",false) -- five
        UnchainedHelper.marker(102637,60951,66181, "6",false) -- six
        UnchainedHelper.marker(105786,60955,67598, "7",false) -- seven
        UnchainedHelper.marker(105911,60951,68075, "8",false) -- eight
        UnchainedHelper.marker(104158,60950,66667, "group", "",false) -- group
        if nextFight==0 then
            UnchainedHelper.eraseIconTime = GetGameTimeMilliseconds() + UnchainedHelper.savedVars.removeMarkerSeconds * 1000 -- remove icons after X seconds
            UnchainedHelper.drawNextFightIconTime= GetGameTimeMilliseconds() + (UnchainedHelper.savedVars.removeMarkerSeconds+UnchainedHelper.savedVars.nextMarkerSeconds) * 1000  -- display next fight after 15 seconds
            UnchainedHelper.nextRound = 4
            UnchainedHelper.nextWave = 2
        end
    end
    --]]