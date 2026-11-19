-- PC: a small draggable button on the HUD that opens Battleground records.
-- Shown with the HUD scenes only ("hud" and "hudui"), never in gamepad mode, and
-- turned off with the "Records button on screen" setting. Its position is saved.
local SBR = ScoreboardRemastered
local L = {}
SBR.Launcher = L

local ICON = "EsoUI/Art/Battlegrounds/battlegrounds_tabIcon_battlegrounds_up.dds"
local ICON_OVER = "EsoUI/Art/Battlegrounds/battlegrounds_tabIcon_battlegrounds_over.dds"
local SIZE = 48

function L:Create()
    if self.control then return end
    local WM = WINDOW_MANAGER
    local tlw = WM:CreateTopLevelWindow("ScoreboardRemasteredLauncher")
    tlw:SetDimensions(SIZE, SIZE)
    tlw:SetClampedToScreen(true)
    tlw:SetMouseEnabled(true)
    tlw:SetMovable(true)
    tlw:SetHidden(true)
    local icon = WM:CreateControl("ScoreboardRemasteredLauncherIcon", tlw, CT_TEXTURE)
    icon:SetAnchorFill(tlw)
    icon:SetTexture(ICON)
    self.icon = icon
    tlw:SetHandler("OnMouseEnter", function(control)
        icon:SetTexture(ICON_OVER)
        InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -4)
        SetTooltipText(InformationTooltip, "Battleground records\n(click to open, drag to move)")
    end)
    tlw:SetHandler("OnMouseExit", function()
        icon:SetTexture(ICON)
        ClearTooltip(InformationTooltip)
    end)
    tlw:SetHandler("OnMoveStop", function(control)
        SBR.sv.launcherPos = { left = control:GetLeft(), top = control:GetTop() }
        L.moved = true
    end)
    tlw:SetHandler("OnMouseUp", function(_, button, upInside)
        -- a drag ends with a mouse up too: only a click opens
        if L.moved then L.moved = false return end
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then SBR.MatchBrowser:Open("matches") end
    end)
    self.control = tlw
    self:Place()
end

function L:Place()
    local pos = SBR.sv.launcherPos
    self.control:ClearAnchors()
    if pos and pos.left then
        self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.left, pos.top)
    else
        self.control:SetAnchor(RIGHT, GuiRoot, RIGHT, -24, -120)
    end
end

function L:Install()
    if self.installed or not SCENE_MANAGER or not ZO_SimpleSceneFragment then return end
    local hud, hudui = SCENE_MANAGER:GetScene("hud"), SCENE_MANAGER:GetScene("hudui")
    if not hud then return end
    self.installed = true
    self:Create()
    self.fragment = ZO_SimpleSceneFragment:New(self.control)
    -- the fragment shows the button with the HUD; Refresh() hides it when it's off
    self.fragment:SetConditional(function() return L:ShouldShow() end)
    hud:AddFragment(self.fragment)
    if hudui then hudui:AddFragment(self.fragment) end
end

function L:ShouldShow()
    return SBR.sv.showLauncher ~= false and not SBR.IsGamepad()
end

function L:Refresh()
    if self.fragment and self.fragment.Refresh then self.fragment:Refresh() end
    if self.control and not self:ShouldShow() then self.control:SetHidden(true) end
end

ScoreboardRemastered.Mark("UI/Launcher.lua")
