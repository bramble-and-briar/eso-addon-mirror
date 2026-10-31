Nirnsteel_UI = Nirnsteel_UI or {}
local Nirnsteel_UI = Nirnsteel_UI
local Themes = {}
Nirnsteel_UI.Themes = Themes

Themes.choices = { "Minimal", "Nirnsteel", "Bronze" }
Themes.values = { "minimal", "nirnsteel", "bronze" }
local VALID = { nirnsteel = true, bronze = true, minimal = true }
local BRONZE =
{
    rim = { 0.63, 0.43, 0.23 },
    highlight = { 0.88, 0.70, 0.43 },
    face = { 0.39, 0.25, 0.13 },
    recess = { 0.10, 0.065, 0.035 },
    text = { 0.95, 0.83, 0.56 },
    body = { 0.88, 0.85, 0.77 },
}
local BRONZE_ASSETS =
{
    ["ui/borders/rail_dxt5.dds"] = "bar_rail",
    ["ui/borders/cap_dxt5.dds"] = "bar_cap",
    ["ui/actionbar/nirnsteel_socket_v3_dxt5.dds"] = "socket",
    ["ui/actionbar/ultimate_iron_v3_dxt5.dds"] = "ultimate",
    ["ui/actionbar/ultimate_ready_v3_dxt5.dds"] = "ultimate_ready",
    ["ui/compass/rail_v3_dxt5.dds"] = "compass_rail",
    ["ui/compass/cap_v4_dxt5.dds"] = "compass_cap",
    ["ui/compass/heading_v3_dxt5.dds"] = "heading",
}

function Themes:Normalize(value)
    if value == "none" then return "minimal" end
    return VALID[value] and value or "nirnsteel"
end

function Themes:GetId()
    local settings = Nirnsteel_UI.Settings
    return self:Normalize(settings and settings.GetTheme and settings:GetTheme())
end

function Themes:HasBorders(enabled)
    return enabled ~= false
end

function Themes:IsMinimal()
    return self:GetId() == "minimal"
end

function Themes:HasDecorations(enabled)
    return self:HasBorders(enabled) and not self:IsMinimal()
end

function Themes:GetAssetPath(path)
    if self:IsMinimal() and (path == "ui/actionbar/nirnsteel_socket_v3_dxt5.dds"
        or path == "ui/actionbar/ultimate_iron_v3_dxt5.dds"
        or path == "ui/actionbar/ultimate_ready_v3_dxt5.dds") then
        return Nirnsteel_UI:GetAssetPath("ui/themes/minimal/socket_dxt5.dds")
    end
    local asset = self:GetId() == "bronze" and BRONZE_ASSETS[path]
    return Nirnsteel_UI:GetAssetPath(asset and ("ui/themes/bronze/" .. asset .. "_dxt5.dds") or path)
end

-- Solid one-pixel lines resize with their parent; no atlas or bevel is involved.
function Themes:ApplyMinimalBorder(control, enabled, layer, tier)
    if not control then return end
    enabled = enabled ~= false and self:IsMinimal()
    local pieces = control.nirnsteelMinimalBorder
    if not pieces and enabled then
        pieces = {}
        local edges = { { TOPLEFT, TOPRIGHT, true }, { BOTTOMLEFT, BOTTOMRIGHT, true },
            { TOPLEFT, BOTTOMLEFT, false }, { TOPRIGHT, BOTTOMRIGHT, false } }
        for _, edge in ipairs(edges) do
            local line = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
            line:SetMouseEnabled(false)
            line:SetDrawLayer(layer or DL_OVERLAY)
            line:SetDrawLevel(6)
            if tier then line:SetDrawTier(tier) end
            line:SetColor(0, 0, 0, 1)
            line:SetAnchor(edge[1], control, edge[1], 0, 0)
            line:SetAnchor(edge[2], control, edge[2], 0, 0)
            if edge[3] then line:SetHeight(1) else line:SetWidth(1) end
            pieces[#pieces + 1] = line
        end
        control.nirnsteelMinimalBorder = pieces
    end
    for _, line in ipairs(pieces or {}) do line:SetHidden(not enabled) end
end

function Themes:Color(role, r, g, b, a)
    local color = self:GetId() == "bronze" and BRONZE[role]
    if color then return color[1], color[2], color[3], a or 1 end
    return r, g, b, a or 1
end

function Themes:StyleRim(control, role, r, g, b, a)
    if not control then return end
    self:ApplyMinimalBorder(control, role ~= "recess")
    if self:IsMinimal() then
        control:SetEdgeColor(0, 0, 0, 0)
    else
        control:SetEdgeColor(self:Color(role, r, g, b, a))
    end
end

function Themes:ApplySocket(control)
    if not control then return end
    local bronze = self:GetId() == "bronze"
    local socket = control.nirnsteelThemeSocket
    if not socket and bronze then
        socket = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
        socket:SetAnchorFill(control)
        socket:SetDrawLayer(DL_OVERLAY)
        socket:SetDrawLevel(6)
        socket:SetMouseEnabled(false)
        socket:SetTexture(self:GetAssetPath("ui/actionbar/nirnsteel_socket_v3_dxt5.dds"))
        control.nirnsteelThemeSocket = socket
    end
    if socket then socket:SetHidden(not bronze) end
end


-- Only theme-aware modules are refreshed. Saved layout, combat colors and
-- module enable switches are independent of this account-wide appearance.
function Themes:Refresh()
    for _, name in ipairs({ "ResourceBars", "GroupFrames", "TargetFrame", "ActionBarFrames",
        "Compass", "Minimap", "QuestTracker", "CastBar", "ExperienceTracker", "InteractionPrompt",
        "SynergyAlert", "AchievementAlert", "GroupCallouts" }) do
        local module = Nirnsteel_UI[name]
        if module then
            if module.RefreshTheme then module:RefreshTheme()
            elseif module.RefreshSettings then module:RefreshSettings() end
        end
    end
end
