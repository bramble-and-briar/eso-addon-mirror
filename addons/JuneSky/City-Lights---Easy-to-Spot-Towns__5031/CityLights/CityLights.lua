-- City Lights: permanently show the map "hover blobs" (towns) on the world map.
local ADDON = "CityLights"
local CL = {}

local DEFAULTS = {
    enabled = true,
    labels = true,
    outline = true,
    fill    = { 1.00, 1.00, 0.00, 1.00 }, -- yellow, like city lights (additive, like the game's own hover)
    glow    = { 1.00, 1.00, 1.00, 1.00 }, -- white halo behind = "outline" (additive, so it can never darken)
    label   = { 1.00, 1.00, 1.00, 1.00 }, -- white
    labelSize = 20,
}
local GRID = 80                       -- sample points per axis when scanning for blobs
local GLOW_SCALE = 1.10
local function Font() return "$(BOLD_FONT)|" .. (CL.sv.labelSize or 20) .. "|soft-shadow-thick" end

local container, blobs, pool = nil, {}, {}

local function Acquire(i)
    local e = pool[i]
    if not e then
        e = {}
        e.glow = WINDOW_MANAGER:CreateControl(nil, container, CT_TEXTURE)
        e.glow:SetDrawLevel(1)
        e.glow:SetBlendMode(TEX_BLEND_MODE_ADD)
        e.glow:SetPixelRoundingEnabled(false)

        e.fill = WINDOW_MANAGER:CreateControl(nil, container, CT_TEXTURE)
        e.fill:SetDrawLevel(2)
        e.fill:SetBlendMode(TEX_BLEND_MODE_ADD)
        e.fill:SetPixelRoundingEnabled(false)

        e.label = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
        e.label:SetDrawTier(DT_HIGH)
        e.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        pool[i] = e
    end
    return e
end

local function HideAll()
    for _, e in ipairs(pool) do
        e.glow:SetHidden(true); e.fill:SetHidden(true); e.label:SetHidden(true)
    end
end

-- Position everything for the current container size (called on scan and on zoom).
local function Layout()
    HideAll()
    if not CL.sv.enabled then return end
    local w, h = ZO_WorldMapContainer:GetDimensions()
    local sv, font = CL.sv, Font()
    for i, b in ipairs(blobs) do
        local e = Acquire(i)
        local bw, bh = b.w * w, b.h * h
        local x, y = b.x * w, b.y * h

        e.fill:SetColor(unpack(sv.fill))
        e.fill:SetTexture(b.tex)
        e.fill:SetDimensions(bw, bh)
        e.fill:ClearAnchors()
        e.fill:SetAnchor(TOPLEFT, container, TOPLEFT, x, y)
        e.fill:SetHidden(false)

        e.glow:SetColor(unpack(sv.glow))
        e.glow:SetTexture(b.tex)
        e.glow:SetDimensions(bw * GLOW_SCALE, bh * GLOW_SCALE)
        e.glow:ClearAnchors()
        e.glow:SetAnchor(CENTER, container, TOPLEFT, x + bw / 2, y + bh / 2)
        e.glow:SetHidden(not sv.outline)

        if CL.sv.labels then
            e.label:SetFont(font)
            e.label:SetColor(unpack(sv.label))
            e.label:SetText(zo_strformat(SI_WORLD_MAP_LOCATION_NAME, b.name))
            e.label:ClearAnchors()
            e.label:SetAnchor(CENTER, container, TOPLEFT, x + bw / 2, y + bh / 2)
            e.label:SetHidden(false)
        end
    end
end

-- Find every hover blob on the current map by sampling a grid of points.
local function Scan()
    blobs = {}
    local mapType = GetMapType()
    if mapType == MAPTYPE_WORLD or mapType == MAPTYPE_COSMIC then Layout() return end

    local mapName, seen = GetMapName(), {}
    for gx = 0, GRID do
        for gy = 0, GRID do
            local name, tex, wN, hN, xN, yN = GetMapMouseoverInfo(gx / GRID, gy / GRID)
            if tex and tex ~= "" and name and name ~= "" and name ~= mapName then
                local key = tex .. "|" .. name
                if not seen[key] and wN and wN < 0.95 then
                    seen[key] = true
                    blobs[#blobs + 1] = { name = name, tex = tex, w = wN, h = hN, x = xN, y = yN }
                end
            end
        end
    end
    Layout()
end

local function Refresh()
    if CL.sv.enabled then Scan() else HideAll() end
end

-- Settings panel (needs LibAddonMenu-2.0; optional - slash commands work without it)
local panel
local function ColorOption(key, name, tooltip, disabledFn)
    return {
        type = "colorpicker", name = name, tooltip = tooltip, disabled = disabledFn,
        getFunc = function() return unpack(CL.sv[key]) end,
        setFunc = function(r, g, b, a) CL.sv[key] = { r, g, b, a or 1 }; Layout() end,
        default = { r = DEFAULTS[key][1], g = DEFAULTS[key][2], b = DEFAULTS[key][3], a = DEFAULTS[key][4] },
    }
end

local function BuildSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end
    panel = LAM:RegisterAddonPanel("CityLightsSettings", {
        type = "panel", name = "City Lights", displayName = "|cc9a44cCity Lights|r",
        author = "JuneSky", version = "1.1.0", slashCommand = "/citylightsset",
        registerForRefresh = true, registerForDefaults = true,
    })
    local off = function() return not CL.sv.enabled end
    LAM:RegisterOptionControls("CityLightsSettings", {
        { type = "description", text = "Keeps towns on the zone map highlighted and labelled so they are easy to spot. Colours are additive (they brighten the map), so darker colours look fainter; use the alpha slider for strength." },
        { type = "checkbox", name = "Show highlights", tooltip = "Turn the map highlights on or off (/citylights).",
          getFunc = function() return CL.sv.enabled end,
          setFunc = function(v) CL.sv.enabled = v; Refresh() end, default = DEFAULTS.enabled },
        { type = "header", name = "Highlight" },
        ColorOption("fill", "Highlight colour", "Colour of the town shapes.", off),
        { type = "checkbox", name = "Show outline glow", tooltip = "A slightly larger halo behind each shape.",
          getFunc = function() return CL.sv.outline end,
          setFunc = function(v) CL.sv.outline = v; Layout() end, default = DEFAULTS.outline, disabled = off },
        ColorOption("glow", "Outline colour", "Colour of the halo behind each shape.",
          function() return not CL.sv.enabled or not CL.sv.outline end),
        { type = "header", name = "Labels" },
        { type = "checkbox", name = "Show names", tooltip = "Write each town's name on the map (/citylights labels).",
          getFunc = function() return CL.sv.labels end,
          setFunc = function(v) CL.sv.labels = v; Layout() end, default = DEFAULTS.labels, disabled = off },
        ColorOption("label", "Name colour", "Colour of the town names.",
          function() return not CL.sv.enabled or not CL.sv.labels end),
        { type = "slider", name = "Name size", min = 12, max = 28, step = 1,
          getFunc = function() return CL.sv.labelSize end,
          setFunc = function(v) CL.sv.labelSize = v; Layout() end, default = DEFAULTS.labelSize,
          disabled = function() return not CL.sv.enabled or not CL.sv.labels end },
    })
end

local function Slash(arg)
    arg = zo_strlower(zo_strtrim(arg or ""))
    if arg == "debug" then
        d("|cc9a44cCity Lights|r " .. GetMapName() .. ": " .. #blobs .. " towns")
        for _, b in ipairs(blobs) do d(string.format("  %s  %s", b.name, b.tex)) end
        return
    elseif arg == "settings" then
        if panel then LibAddonMenu2:OpenToPanel(panel) else d("|cc9a44cCity Lights|r: settings need LibAddonMenu-2.0") end
        return
    elseif arg == "labels" then
        CL.sv.labels = not CL.sv.labels
        d("|cc9a44cCity Lights|r labels " .. (CL.sv.labels and "ON" or "OFF"))
    elseif arg == "on" or arg == "off" or arg == "" then
        if arg == "" then CL.sv.enabled = not CL.sv.enabled else CL.sv.enabled = (arg == "on") end
        d("|cc9a44cCity Lights|r " .. (CL.sv.enabled and "ON" or "OFF"))
    else
        d("|cc9a44cCity Lights|r: /citylights [on|off|labels|settings|debug]")
        return
    end
    Refresh()
end

local function OnLoaded(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    CL.sv = ZO_SavedVars:NewAccountWide("CityLightsSV", 1, nil, DEFAULTS)
    BuildSettings()

    container = WINDOW_MANAGER:CreateControl("CityLightsContainer", ZO_WorldMapContainer, CT_CONTROL)
    container:SetAnchorFill(ZO_WorldMapContainer)

    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", Refresh)
    ZO_PostHook(ZO_WorldMapContainer, "SetDimensions", function() if #blobs > 0 then Layout() end end)
    local function OnScene(_, newState) if newState == SCENE_SHOWING then Refresh() end end
    WORLD_MAP_SCENE:RegisterCallback("StateChange", OnScene)
    if GAMEPAD_WORLD_MAP_SCENE then GAMEPAD_WORLD_MAP_SCENE:RegisterCallback("StateChange", OnScene) end

    SLASH_COMMANDS["/citylights"] = Slash
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnLoaded)
