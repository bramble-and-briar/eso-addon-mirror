-- DevSandbox3Settings.lua: LibHarvensAddonSettings menu (console). Optional dependency.

local Settings = {}

local function SavedSettings()
    return DevSandbox3.state.savedVars.settings
end

function Settings.Initialize()
    local LAS = _G["LibHarvensAddonSettings"]
    if not (LAS and LAS.AddAddon) then
        DevSandbox3.LogUtils.Debug("LibHarvensAddonSettings not present - no settings menu")
        return false
    end

    local panel = LAS:AddAddon(DevSandbox3.displayName, { allowRefresh = true })
    if not panel then return false end
    panel.author = "clubwratt"
    panel.version = DevSandbox3.version

    -- ---------------------------------------------------------------- alert
    panel:AddSetting({ type = LAS.ST_SECTION, label = "Detection alert" })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Show on-screen alert",
        tooltip = "Big persistent text on the HUD when a war torte recipe (or an unrecognized node) is detected.",
        getFunction = function() return SavedSettings().alertEnabled end,
        setFunction = function(v) SavedSettings().alertEnabled = v; DevSandbox3.AlertActions.Refresh() end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Play sound",
        getFunction = function() return SavedSettings().alertSound end,
        setFunction = function(v) SavedSettings().alertSound = v end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Also alert on unrecognized nodes (testing)",
        tooltip = "Off: the big alert only fires for a confirmed war torte name. On: yellow candidates alert too.",
        getFunction = function() return SavedSettings().alertOnCandidates end,
        setFunction = function(v) SavedSettings().alertOnCandidates = v end,
    })
    panel:AddSetting({
        type = LAS.ST_SLIDER, label = "Alert text size", min = 24, max = 96, step = 4, format = "%d",
        getFunction = function() return SavedSettings().alertFontSize end,
        setFunction = function(v) SavedSettings().alertFontSize = v; DevSandbox3.AlertActions.Refresh() end,
    })
    panel:AddSetting({
        type = LAS.ST_SLIDER, label = "Auto-dismiss after (seconds, 0 = never)", min = 0, max = 600, step = 10, format = "%d",
        getFunction = function() return SavedSettings().alertAutoDismissSeconds end,
        setFunction = function(v) SavedSettings().alertAutoDismissSeconds = v end,
    })
    panel:AddSetting({
        type = LAS.ST_BUTTON, label = "Dismiss current alert", buttonText = "Dismiss",
        clickHandler = function() DevSandbox3.AlertActions.Dismiss() end,
    })
    panel:AddSetting({
        type = LAS.ST_BUTTON, label = "Preview alert", buttonText = "Test",
        clickHandler = function() DevSandbox3.AlertActions.Test() end,
    })

    -- ---------------------------------------------------------------- map
    panel:AddSetting({ type = LAS.ST_SECTION, label = "Map" })
    panel:AddSetting({
        type = LAS.ST_SLIDER, label = "Map pin size (needs /reloadui)", min = 4, max = 32, step = 1, format = "%d",
        tooltip = "Size of the spawn / missing-slot dots on the map. 4-8 = pinpoint, 20+ = stock icon size.",
        getFunction = function() return SavedSettings().mapPinSize end,
        setFunction = function(v) SavedSettings().mapPinSize = v end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Show detection radius around player",
        tooltip = "Draws a circle around you on the Cyrodiil map (one pin, refreshed once a second while the map is open).",
        getFunction = function() return SavedSettings().showPlayerRadius end,
        setFunction = function(v) SavedSettings().showPlayerRadius = v; DevSandbox3.CoverageActions.RefreshAll() end,
    })
    panel:AddSetting({
        type = LAS.ST_SLIDER, label = "Radius (meters)", min = 50, max = 400, step = 25, format = "%d",
        getFunction = function() return SavedSettings().playerRadiusMeters end,
        setFunction = function(v) SavedSettings().playerRadiusMeters = v; DevSandbox3.CoverageActions.RefreshAll() end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Track covered ground (experimental)",
        tooltip = "Every 2 s, marks the 400 m cell you are standing in as covered. Data only; drawing is the next option.",
        getFunction = function() return SavedSettings().trackCoverage end,
        setFunction = function(v) SavedSettings().trackCoverage = v end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Show covered ground on map (experimental)",
        tooltip = "Shades covered cells on the Cyrodiil map. Capped at 500 blobs. Turn off if the map gets slow.",
        getFunction = function() return SavedSettings().showCoverage end,
        setFunction = function(v) SavedSettings().showCoverage = v; DevSandbox3.CoverageActions.RefreshAll() end,
    })
    panel:AddSetting({
        type = LAS.ST_BUTTON, buttonText = "Reset",
        label = function() return string.format("Reset covered ground (%d cells)", DevSandbox3.CoverageActions.CountCoveredCells()) end,
        clickHandler = function() DevSandbox3.CoverageActions.ResetCoverage() end,
    })

    -- ---------------------------------------------------------------- expected slots
    panel:AddSetting({ type = LAS.ST_SECTION, label = "Missing-node candidates" })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Show missing-node candidates on map",
        tooltip = "Orange markers where a known material spawn point was in compass range but had no node - the book replaces a node, so these are where to look.",
        getFunction = function() return SavedSettings().showEmptySlots end,
        setFunction = function(v) SavedSettings().showEmptySlots = v; LibMapPins:RefreshPins(DevSandbox3.emptySlotPinType) end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Keep showing them after leaving range",
        tooltip = "Off: markers only while the slot is within 200 m of you. On: every missing slot stays on the map until it expires.",
        getFunction = function() return SavedSettings().showEmptySlotsOutOfRange end,
        setFunction = function(v) SavedSettings().showEmptySlotsOutOfRange = v; LibMapPins:RefreshPins(DevSandbox3.emptySlotPinType) end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Chat line when a slot is found empty (off by default)",
        getFunction = function() return SavedSettings().logEmptySlots end,
        setFunction = function(v) SavedSettings().logEmptySlots = v end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Big alert on a new empty slot (noisy)",
        getFunction = function() return SavedSettings().alertOnEmptySlots end,
        setFunction = function(v) SavedSettings().alertOnEmptySlots = v end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Also flag slots when NO harvest pins are in range",
        tooltip = "On: a slot within 120 m is marked missing whenever the compass reports zero harvest nodes nearby, without facing it. Off: only slots you actually face are checked.",
        getFunction = function() return SavedSettings().emptyByPinCount end,
        setFunction = function(v) SavedSettings().emptyByPinCount = v end,
    })
    panel:AddSetting({
        type = LAS.ST_SLIDER, label = "Forget an empty slot after (minutes)", min = 15, max = 720, step = 15, format = "%d",
        getFunction = function() return SavedSettings().emptySlotTtlMinutes end,
        setFunction = function(v) SavedSettings().emptySlotTtlMinutes = v end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Show unverified expected slots in range (debug)",
        tooltip = "Grey dots for every known spawn point within 200 m that has not been checked yet. Refreshes once a second while the map is open.",
        getFunction = function() return SavedSettings().showExpectedSlots end,
        setFunction = function(v) SavedSettings().showExpectedSlots = v; LibMapPins:RefreshPins(DevSandbox3.expectedSlotPinType) end,
    })
    panel:AddSetting({
        type = LAS.ST_BUTTON, buttonText = "Clear",
        label = function() return string.format("Clear missing-node candidates (%d)", DevSandbox3.SlotActions.CountEmpties()) end,
        clickHandler = function() DevSandbox3.SlotActions.ClearEmpties() end,
    })

    -- ---------------------------------------------------------------- world / compass markers
    panel:AddSetting({ type = LAS.ST_SECTION, label = "World & compass markers (HarvestMap-style)" })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Show floating dots in the 3D world",
        tooltip = "A dot hovers above every marked spot within range: orange = missing material slot, green = recorded war torte spawn.",
        getFunction = function() return SavedSettings().showWorldMarkers end,
        setFunction = function(v) SavedSettings().showWorldMarkers = v end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Show them on the compass",
        getFunction = function() return SavedSettings().showCompassMarkers end,
        setFunction = function(v) SavedSettings().showCompassMarkers = v end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Include missing material slots (orange)",
        getFunction = function() return SavedSettings().markMissingSlotsInWorld end,
        setFunction = function(v) SavedSettings().markMissingSlotsInWorld = v end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Include recorded war torte spawns (green)",
        getFunction = function() return SavedSettings().markSpawnsInWorld end,
        setFunction = function(v) SavedSettings().markSpawnsInWorld = v end,
    })
    panel:AddSetting({
        type = LAS.ST_SLIDER, label = "Marker range (meters)", min = 25, max = 400, step = 25, format = "%d",
        getFunction = function() return SavedSettings().worldMarkerRangeM end,
        setFunction = function(v) SavedSettings().worldMarkerRangeM = v end,
    })
    panel:AddSetting({
        type = LAS.ST_SLIDER, label = "3D dot size (cm)", min = 10, max = 200, step = 5, format = "%d",
        tooltip = "World size of a dot. With 'same size on screen' this is the size at 10 m.",
        getFunction = function() return math.floor(SavedSettings().worldMarkerSizeM * 100 + 0.5) end,
        setFunction = function(v) SavedSettings().worldMarkerSizeM = v / 100 end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Same size on screen at any distance",
        getFunction = function() return SavedSettings().worldMarkerConstantSize end,
        setFunction = function(v) SavedSettings().worldMarkerConstantSize = v end,
    })

    -- ---------------------------------------------------------------- detection
    panel:AddSetting({ type = LAS.ST_SECTION, label = "Detection" })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Probe all compass pin types (testing, noisy)",
        tooltip = "Also react to LOCATION / VENDOR / TRAINER / NPC_FOLLOWER compass pins: logs when one enters 200 m and records unknown ones as candidates. Leave off unless testing.",
        getFunction = function() return SavedSettings().probeAllTypes end,
        setFunction = function(v) SavedSettings().probeAllTypes = v end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Record unrecognized harvest nodes as candidates",
        getFunction = function() return DevSandbox3.state.savedVars.recordUnknown end,
        setFunction = function(v) DevSandbox3.state.savedVars.recordUnknown = v end,
    })
    panel:AddSetting({
        type = LAS.ST_CHECKBOX, label = "Debug logging",
        getFunction = function() return DevSandbox3.state.savedVars.debug end,
        setFunction = function(v) DevSandbox3.state.savedVars.debug = v end,
    })
    panel:AddSetting({
        type = LAS.ST_BUTTON, buttonText = "Clear",
        label = function() return string.format("Clear all saved spawns (%d)", #DevSandbox3.state.savedVars.nodes) end,
        clickHandler = function() DevSandbox3.NodeActions.ClearAll(); DevSandbox3.LogUtils.Log("All saved spawns cleared") end,
    })

    return true
end

DevSandbox3.Settings = Settings
