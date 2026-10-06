-- DevSandbox3Settings.lua: LibHarvensAddonSettings panel (optional). One flat list.
local Settings = {}
local function S() return DevSandbox3.state.savedVars.settings end

local function Color(LAS, label, key)
    return {
        type = LAS.ST_COLOR, label = label,
        getFunction = function() local c = S()[key]; return c.r, c.g, c.b, c.a end,
        setFunction = function(r, g, b, a) local c = S()[key]; c.r, c.g, c.b, c.a = r, g, b, a or c.a end,
    }
end
local function Check(LAS, label, key, tooltip)
    return { type = LAS.ST_CHECKBOX, label = label, tooltip = tooltip, getFunction = function() return S()[key] end, setFunction = function(v) S()[key] = v end }
end
local function Slider(LAS, label, key, min, max, step, tooltip)
    return { type = LAS.ST_SLIDER, label = label, tooltip = tooltip, min = min, max = max, step = step, format = "%d", getFunction = function() return S()[key] end, setFunction = function(v) S()[key] = v end }
end

function Settings.Initialize()
    local LAS = _G["LibHarvensAddonSettings"]
    if not (LAS and LAS.AddAddon) then return end
    local panel = LAS:AddAddon(DevSandbox3.displayName)
    if not panel then return end
    panel.author, panel.version = "clubwratt", DevSandbox3.version
    panel:AddSetting({ type = LAS.ST_BUTTON, label = "CLEAR CHECKPOINTS", buttonText = "Clear", tooltip = "Forget every checkpoint and held verdict, in every zone.", clickHandler = function() DevSandbox3.SlotActions.ClearCheckpoints() end })
    panel:AddSetting({ type = LAS.ST_BUTTON, label = "EXPORT LOG", buttonText = "Export", tooltip = "Send the buffered log to the LibConsoleLogger receiver.", clickHandler = function() DevSandbox3.LogUtils.Export() end })
    panel:AddSetting(Slider(LAS, "CLOSE DOT SIZE", "dotSizeCm", 10, 200, 5, "Apparent size (cm) of a dot 10 m away."))
    panel:AddSetting(Slider(LAS, "FAR DOT SIZE (%)", "farScalePct", 25, 100, 5, "Size of a dot at the far distance below, relative to a close one. 100 = same size everywhere."))
    panel:AddSetting(Slider(LAS, "FAR DISTANCE (M)", "farScaleM", 50, 200, 10))
    panel:AddSetting(Check(LAS, "BLACK OUTLINE", "outline"))
    panel:AddSetting(Check(LAS, "WAR TORTE SPAWNS", "markWarTorte", "Any harvestable spawn location in Cyrodiil with no node - the Colovian War Torte recipe spawns in these."))
    panel:AddSetting(Color(LAS, "War Torte dot color", "warTorteColor"))
    panel:AddSetting(Check(LAS, "PSIJIC PORTAL SPAWNS", "markPsijic", "Runestone spawn locations with no node, in every zone - a possible Psijic Portal."))
    panel:AddSetting(Color(LAS, "Psijic dot color", "psijicColor"))
    panel:AddSetting(Check(LAS, "UNKNOWN (FAR)", "markUnknown", "No node seen there yet, but it is farther than the compass reliably reports nodes - may just be out of range."))
    panel:AddSetting(Color(LAS, "Unknown dot color", "unknownColor"))
    panel:AddSetting(Slider(LAS, "Unknown start (m)", "unknownM", 30, 200, 10, "Closer than this a location with no node is confirmed empty; farther it is unknown. Also never farther than the farthest node the compass has placed."))
    panel:AddSetting(Slider(LAS, "Unknown limit (m)", "unknownLimitM", 50, 200, 10, "Unknown dots are not drawn beyond this distance."))
    panel:AddSetting(Slider(LAS, "CHECKPOINT DISTANCE (M)", "checkedM", 5, 50, 1, "Coming within this distance of a location marks it as a checkpoint: its dot changes to the checkpoint color."))
    panel:AddSetting({ type = LAS.ST_SLIDER, label = "CHECKPOINT DURATION (MIN)", tooltip = "How long checkpoints and resolved locations are remembered (survives reload and relog). 0 = until you press CLEAR CHECKPOINTS.", min = 0, max = 600, step = 15, format = "%d",
        unit = function() return S().checkedMin == 0 and " = until cleared" or " min" end,
        getFunction = function() return S().checkedMin end, setFunction = function(v) S().checkedMin = v end })
    panel:AddSetting(Color(LAS, "Checkpoint dot color", "checkedColor"))
    panel:AddSetting(Check(LAS, "DEBUG: CYAN NODE DOTS", "debugNodes", "Where the compass says each nearby node is. Must sit on top of real nodes."))
    panel:AddSetting(Check(LAS, "DEBUG: LOGGING", "debug"))
end

DevSandbox3.Settings = Settings
