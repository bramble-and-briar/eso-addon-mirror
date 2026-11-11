-- DevSandbox3Settings.lua: LibHarvensAddonSettings panel (optional)
--
-- Top level: CLEAR CHECKPOINTS, ADD TRACKER, then TRACKER_ROWS rows per tracker (node dropdown, colour, candidates,
-- remove). Everything else is tucked into submenus: on console a section row opens the rows that follow it, up to
-- the next section. So every top-level row comes before the first section, and tracker rows are inserted and
-- removed at an index (AddSettings / RemoveSettings) instead of rebuilding the panel.
local Settings = {}
local PinTypeUtils = DevSandbox3.PinTypeUtils

local function S() return DevSandbox3.state.savedVars.settings end

local FIRST_TRACKER_ROW = 3   -- after CLEAR CHECKPOINTS and ADD TRACKER
local TRACKER_ROWS = 4
-- a new tracker hunts FIRST_NODE, or the first node in the dropdown not hunted yet, in the next of these colours
local FIRST_NODE = "Columbine"
local PALETTE = {
    { r = 0.2, g = 1.0, b = 0.3, a = 0.9 },   -- green
    { r = 1.0, g = 0.3, b = 0.7, a = 0.9 },   -- pink
    { r = 0.3, g = 0.6, b = 1.0, a = 0.9 },   -- blue
    { r = 1.0, g = 1.0, b = 1.0, a = 0.9 },   -- white
    { r = 1.0, g = 0.2, b = 0.2, a = 0.9 },   -- red
}

Settings.panel = nil

---What is marked changed: reload the slots that are now wanted.
local function Apply() DevSandbox3.SlotActions.LoadZone() end

---@param color fun(): DevSandbox3Color
local function Color(LAS, label, color)
    return {
        type = LAS.ST_COLOR, label = label,
        getFunction = function() local c = color(); return c.r, c.g, c.b, c.a end,
        setFunction = function(r, g, b, a) local c = color(); c.r, c.g, c.b, c.a = r, g, b, a or c.a end,
    }
end
local function SettingColor(LAS, label, key)
    return Color(LAS, label, function() return S()[key] end)
end
---@param onChange fun()|nil
local function Check(LAS, label, key, tooltip, onChange)
    return { type = LAS.ST_CHECKBOX, label = label, tooltip = tooltip, getFunction = function() return S()[key] end,
        setFunction = function(v) S()[key] = v; if onChange then onChange() end end }
end
---@param unit string|nil
local function Slider(LAS, label, key, min, max, step, tooltip, unit)
    -- NOTE: LibHarvensAddonSettings (Console/Settings.lua:112) does `#self.unit` BEFORE GetValueOrCallback, so
    -- `unit` must be a plain string - a function throws "operator # is not supported" and leaves the row blank.
    return { type = LAS.ST_SLIDER, label = label, tooltip = tooltip, min = min, max = max, step = step, format = "%d", unit = unit,
        getFunction = function() return S()[key] end, setFunction = function(v) S()[key] = v end }
end
local function Section(LAS, label, tooltip)
    return { type = LAS.ST_SECTION, label = label, tooltip = tooltip }
end

-- the dropdown's entries. `data` must be set: the library's equality test matches any two entries without one.
local NODE_ITEMS = {}
for i, name in ipairs(PinTypeUtils.NAMES) do NODE_ITEMS[i] = { name = name, data = name } end

---@param tracker DevSandbox3Tracker
---@return integer|nil
local function IndexOf(tracker)
    local trackers = S().trackers
    for i = 1, #trackers do if trackers[i] == tracker then return i end end
    return nil
end

---The rows of one tracker. They hold the tracker itself, so they stay right when trackers before it are removed.
---@param tracker DevSandbox3Tracker
local function TrackerRows(LAS, tracker)
    return {
        { type = LAS.ST_DROPDOWN, label = "TRACK", items = NODE_ITEMS,
            tooltip = "The node to hunt. A dot in the color below marks every one of them found, whatever its quality (Lush Columbine counts as Columbine). In every zone.",
            getFunction = function() return tracker.node end,
            setFunction = function(_, name) tracker.node = name; Apply() end },
        Color(LAS, "Dot color", function() return tracker.color end),
        { type = LAS.ST_CHECKBOX, label = "Candidate locations",
            tooltip = "Also mark, in the candidate color, the locations where this node may be: nothing identified there yet. A candidate that turns out to be something else disappears.",
            getFunction = function() return tracker.candidates end,
            setFunction = function(v) tracker.candidates = v; Apply() end },
        { type = LAS.ST_BUTTON, label = "Remove tracker", buttonText = "Remove", clickHandler = function() Settings.RemoveTracker(tracker) end },
    }
end

---Add a tracker: for FIRST_NODE, or the first node in the dropdown not hunted yet.
---@return DevSandbox3Tracker
function Settings.AddTracker()
    local trackers = S().trackers
    local hunted = {}
    for i = 1, #trackers do hunted[trackers[i].node] = true end
    local node = not hunted[FIRST_NODE] and FIRST_NODE or nil
    for _, name in ipairs(PinTypeUtils.NAMES) do
        if not node and not hunted[name] then node = name end
    end
    local c = PALETTE[#trackers % #PALETTE + 1]
    local tracker = { node = node or FIRST_NODE, color = { r = c.r, g = c.g, b = c.b, a = c.a }, candidates = true }
    trackers[#trackers + 1] = tracker
    Apply()
    if Settings.panel then
        Settings.panel:AddSettings(TrackerRows(_G["LibHarvensAddonSettings"], tracker), FIRST_TRACKER_ROW + TRACKER_ROWS * (#trackers - 1))
    end
    return tracker
end

---@param tracker DevSandbox3Tracker
function Settings.RemoveTracker(tracker)
    local i = IndexOf(tracker)
    if not i then return end
    table.remove(S().trackers, i)
    Apply()
    if Settings.panel then Settings.panel:RemoveSettings(FIRST_TRACKER_ROW + TRACKER_ROWS * (i - 1), TRACKER_ROWS) end
end

function Settings.Initialize()
    local LAS = _G["LibHarvensAddonSettings"]
    if not (LAS and LAS.AddAddon) then return end
    local panel = LAS:AddAddon(DevSandbox3.displayName)
    if not panel then return end
    panel.author, panel.version = "clubwratt", DevSandbox3.version
    Settings.panel = panel
    local function Add(row) panel:AddSetting(row) end

    Add({ type = LAS.ST_BUTTON, label = "CLEAR CHECKPOINTS", buttonText = "Clear", tooltip = "Forget every checkpoint and every remembered location, in every zone.", clickHandler = function() DevSandbox3.SlotActions.ClearCheckpoints() end })
    Add({ type = LAS.ST_BUTTON, label = "ADD TRACKER", buttonText = "Add", tooltip = "Hunt a kind of node: pick it, pick its dot color. Add as many as you like.", clickHandler = function() Settings.AddTracker() end })
    for _, tracker in ipairs(S().trackers) do
        for _, row in ipairs(TrackerRows(LAS, tracker)) do Add(row) end
    end

    Add(Section(LAS, "EMPTY SPAWNS", "Locations where a node is missing, so something else may be there: the war torte recipe, a Psijic Portal."))
    Add(Check(LAS, "WAR TORTE SPAWNS", "markWarTorte", "Cyrodiil only. Any harvestable spawn location with no node - the Colovian War Torte recipe spawns in these.", Apply))
    Add(SettingColor(LAS, "War Torte dot color", "warTorteColor"))
    Add(Check(LAS, "PSIJIC PORTAL SPAWNS", "markPsijic", "Every zone. Runestone spawn locations with no node - a possible Psijic Portal.", Apply))
    Add(SettingColor(LAS, "Psijic dot color", "psijicColor"))
    Add(Check(LAS, "Candidate locations", "markUnknown", "Also mark, in the candidate color, the locations too far away to tell yet: no node seen there, but it may just be out of range."))

    Add(Section(LAS, "CANDIDATES", "Locations not determined yet, for trackers and empty spawns alike."))
    Add(SettingColor(LAS, "Candidate dot color", "unknownColor"))
    Add(Slider(LAS, "Confirmed range (m)", "unknownM", 30, 200, 10, "Closer than this a location with no node is confirmed empty; farther it is a candidate. Also never farther than the farthest node the compass has placed."))
    Add(Slider(LAS, "Candidate limit (m)", "unknownLimitM", 50, 200, 10, "Candidate dots are not drawn beyond this distance."))

    Add(Section(LAS, "CHECKPOINTS", "Locations you have already been to."))
    Add(Slider(LAS, "CHECKPOINT DISTANCE (M)", "checkedM", 5, 50, 1, "Coming within this distance of a location marks it as a checkpoint: its dot changes to the checkpoint color."))
    Add(Slider(LAS, "CHECKPOINT DURATION (MIN)", "checkedMin", 0, 600, 15, "How long checkpoints and remembered locations last (survives reload and relog). 0 = until you press CLEAR CHECKPOINTS.", " min"))
    Add(SettingColor(LAS, "Checkpoint dot color", "checkedColor"))

    Add(Section(LAS, "DOTS"))
    Add(Slider(LAS, "CLOSE DOT SIZE", "dotSizeCm", 10, 200, 5, "Apparent size (cm) of a dot 10 m away."))
    Add(Slider(LAS, "FAR DOT SIZE (%)", "farScalePct", 25, 100, 5, "Size of a dot at the far distance below, relative to a close one. 100 = same size everywhere."))
    Add(Slider(LAS, "FAR DISTANCE (M)", "farScaleM", 50, 200, 10))
    Add(Check(LAS, "BLACK OUTLINE", "outline"))

    Add(Section(LAS, "DEBUG"))
    Add({ type = LAS.ST_BUTTON, label = "EXPORT LOG", buttonText = "Export", tooltip = "Send the buffered log to the LibConsoleLogger receiver.", clickHandler = function() DevSandbox3.LogUtils.Export() end })
    Add(Check(LAS, "CYAN NODE DOTS", "debugNodes", "Where the compass says each nearby node is. Must sit on top of real nodes."))
    Add(Check(LAS, "LOGGING", "debug"))
end

DevSandbox3.Settings = Settings
