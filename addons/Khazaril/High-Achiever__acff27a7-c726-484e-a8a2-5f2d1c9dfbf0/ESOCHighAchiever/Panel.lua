-- High Achiever: a short panel when you arrive somewhere new.

local HA = ESOC_HighAchiever
local Panel = {}
HA.Panel = Panel

local PANEL_WIDTH, PADDING = 600, 16
local SHOW_CLOSEST = 3
local panel, lastPlace, hideToken = nil, nil, 0

local function create()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("ESOCHighAchieverPanel")
    window:SetDimensions(PANEL_WIDTH, 100)
    window:SetMouseEnabled(false)
    -- Left side, so it doesn't sit on top of Skill Point Finder's panel on the right
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 40, 220)
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
    local height = HA.Safe(function() return panel.label:GetTextHeight() end) or 120
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
    end, (HA.sv.options.panelSeconds or 15) * 1000)
end

-- The panel text for where you are now, or nil when there's nothing left to do here.
function Panel.Text(state)
    if #state.todo == 0 then return nil end
    local C = HA.Colour
    local lines = { C(HA.GOLD, HA.Lists.Summary(state)) }
    for i = 1, math.min(SHOW_CLOSEST, #state.todo) do
        local entry = state.todo[i]
        local line = entry.name
        if entry.progressText then line = line .. " (" .. entry.progressText .. ")" end
        lines[#lines + 1] = line
    end
    local reward = state.rewards[1]
    if reward then
        local text = reward.reward.text ~= "" and (reward.reward.kind .. ": " .. reward.reward.text) or reward.reward.kind
        lines[#lines + 1] = C(HA.YELLOW, text) .. " from " .. reward.name
    end
    if HA.sv.options.autoPin and HA.Pinned() == state.todo[1].id then
        lines[#lines + 1] = C(HA.GREEN, "Pinned: " .. state.todo[1].name)
    end
    return table.concat(lines, "\n")
end

function Panel.OnZone()
    -- Waits until the achievements have been read, so the counts are right
    zo_callLater(function() HA.Index.Start(function()
        local state = HA.Place.Get()
        local place = state.place.id
        -- Towns count as their zone, so the panel shows once per place, not at every door
        if place == lastPlace then return end
        lastPlace = place
        if HA.sv.options.autoPin and state.todo[1] then HA.Pin(state.todo[1].id) end
        if not HA.sv.options.showPanel then return end
        local ok, text = pcall(Panel.Text, state)
        if ok and text then show(text) end
    end) end, 2000)
end
