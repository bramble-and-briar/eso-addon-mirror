-- Skill Point Finder: a short panel when you arrive in a zone or a group dungeon.

local SP = ESOC_SkillPointFinder
local Panel = {}
SP.Panel = Panel

local PANEL_WIDTH, PADDING = 560, 16
local panel, lastZone, hideToken = nil, nil, 0

local function create()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("ESOCSkillPointFinderPanel")
    window:SetDimensions(PANEL_WIDTH, 100)
    window:SetMouseEnabled(false)
    window:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -40, 220)
    window:SetHidden(true)
    local background = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    background:SetAnchorFill(window)
    background:SetColor(0, 0, 0, 0.6)
    local label = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    label:SetFont("ZoFontGamepad27")
    label:SetColor(0.95, 0.94, 0.88, 1)
    label:SetAnchor(TOPLEFT, window, TOPLEFT, PADDING, PADDING)
    label:SetWidth(PANEL_WIDTH - PADDING * 2)
    panel = { window = window, label = label, fragment = ZO_SimpleSceneFragment:New(window) }
end

local function show(text)
    if not panel then create() end
    panel.label:SetText(text)
    local height = SP.Safe(function() return panel.label:GetTextHeight() end) or 120
    panel.window:SetDimensions(PANEL_WIDTH, height + PADDING * 2)
    if HUD_SCENE then HUD_SCENE:AddFragment(panel.fragment) end
    if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(panel.fragment) end
    hideToken = hideToken + 1
    local token = hideToken
    zo_callLater(function()
        if token ~= hideToken then return end
        if HUD_SCENE then HUD_SCENE:RemoveFragment(panel.fragment) end
        if HUD_UI_SCENE then HUD_UI_SCENE:RemoveFragment(panel.fragment) end
        panel.window:SetHidden(true)
    end, (SP.sv.options.panelSeconds or 15) * 1000)
end

-- The panel text for where you are now, or nil when there's nothing to say.
function Panel.Text(state)
    local C = SP.Colour
    local here = SP.PlayerZoneId()
    local dungeon = state.dungeonByZone[here]
    if dungeon then
        if dungeon.questDone then return nil end
        if dungeon.inJournal then
            return C(SP.GOLD, dungeon.name) .. "\nThe dungeon quest is in your journal. Finish it for 1 skill point."
        end
        return C(SP.GOLD, dungeon.name) .. "\nThis character hasn't done the dungeon quest. Pick it up from the quest giver near the start: it's worth 1 skill point."
    end
    local zone = state.zones[SP.RootZone(here)]
    if not zone then return nil end
    local left = SP.Scan.ZoneLeft(zone)
    if left.points <= 0 then return nil end
    local lines = { C(SP.GOLD, zone.name .. ": skill points still here") }
    if left.shards > 0 then
        local p = left.shards / 3
        lines[#lines + 1] = "Skyshards: " .. left.shards .. " left (" .. (p == math.floor(p) and string.format("%d", p) or string.format("%.1f", p)) .. " points)"
    end
    for _, public in ipairs(zone.publics) do
        if not public.done then lines[#lines + 1] = "Group event: " .. public.name .. " (1 point)" end
    end
    if left.story > 0 then lines[#lines + 1] = "Storyline: up to " .. left.story .. " points" end
    return table.concat(lines, "\n")
end

function Panel.OnZone()
    if not SP.sv.options.showPanel then return end
    -- Waits until the achievements have been read, so done group events aren't shown as waiting
    zo_callLater(function() SP.Scan.StartIndex(function()
        local state = SP.Scan.Get()
        local here = SP.PlayerZoneId()
        -- Delves and towns count as their zone, so the panel shows once per zone, not at every door
        local place = state.dungeonByZone[here] and here or SP.RootZone(here)
        if place == lastZone then return end
        lastZone = place
        local ok, text = pcall(Panel.Text, state)
        if ok and text then show(text) end
    end) end, 2000)
end
