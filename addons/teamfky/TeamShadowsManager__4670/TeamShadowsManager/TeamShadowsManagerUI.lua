TeamShadowsManager = TeamShadowsManager or {}

local PBT = TeamShadowsManager

local UI = {}
PBT.UI = UI

local function L(text)
    return PBT.LocalizeLiteral and PBT.LocalizeLiteral(text) or text
end
local function S(key, ...)
    return PBT.GetString and PBT.GetString(key, ...) or tostring(key or "")
end

local WINDOW_NAME = "TeamShadowsManagerWindow"
local MENU_BUTTON_NAME = "TeamShadowsManagerMenuButton"
local MANAGER_WINDOW_NAME = "TeamShadowsManagerPanel"
local CURSOR_PLACEMENT_UPDATE_NAME = "TeamShadowsManagerCursorPlacement"
local MARKER_DISTANCE_UPDATE_NAME = "TeamShadowsManagerMarkerDistances"
local LEFT_MOUSE_BUTTON = MOUSE_BUTTON_INDEX_LEFT or 1
local RIGHT_MOUSE_BUTTON = MOUSE_BUTTON_INDEX_RIGHT or 2
local MENU_BUTTON_TEXTURE = "TeamShadowsManager/TeamShadowsManagerHeaderLogo.dds"

local function TextureHasNativeText(textureId)
    textureId = tonumber(textureId) or 0
    return textureId >= 8
end


local function Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function CreateLabel(parent, text, font, r, g, b, a)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(font or "ZoFontGame")
    label:SetColor(r or 1, g or 1, b or 1, a or 1)
    label:SetText(text or "")
    return label
end

function UI:EnsureCursorPlacementControls()
    if self.cursorPlacementOverlay and self.cursorPlacementTexture then return end
    local wm = WINDOW_MANAGER

    self.cursorPlacementOverlay = wm:CreateTopLevelWindow("TeamShadowsManagerCursorPlacementOverlay")
    self.cursorPlacementOverlay:SetAnchorFill(GuiRoot)
    self.cursorPlacementOverlay:SetMouseEnabled(true)
    self.cursorPlacementOverlay:SetMovable(false)
    self.cursorPlacementOverlay:SetClampedToScreen(true)
    self.cursorPlacementOverlay:SetDrawTier(DT_MEDIUM)
    self.cursorPlacementOverlay:SetHidden(true)
    self.cursorPlacementOverlay:SetHandler("OnMouseUp", function(_, button)
        if button == LEFT_MOUSE_BUTTON then
            if PBT.PlaceMarkerFromReticle then
                PBT.PlaceMarkerFromReticle()
            end
            self:StopCursorPlacement()
            if self.managerWindow then
                self.managerWindow:SetHidden(false)
            end
            return true
        elseif button == RIGHT_MOUSE_BUTTON then
            self:StopCursorPlacement()
            return true
        end
    end)

    self.cursorPlacementTexture = wm:CreateTopLevelWindow("TeamShadowsManagerCursorPlacementPreview")
    self.cursorPlacementTexture:SetDimensions(54, 54)
    self.cursorPlacementTexture:SetMouseEnabled(false)
    self.cursorPlacementTexture:SetMovable(false)
    self.cursorPlacementTexture:SetClampedToScreen(false)
    self.cursorPlacementTexture:SetDrawTier(DT_HIGH)
    self.cursorPlacementTexture:SetDrawLayer(DL_OVERLAY)
    self.cursorPlacementTexture:SetDrawLevel(10)
    self.cursorPlacementTexture:SetHidden(true)

    local bg = wm:CreateControl(nil, self.cursorPlacementTexture, CT_BACKDROP)
    bg:SetAnchorFill(self.cursorPlacementTexture)
    bg:SetCenterColor(0, 0, 0, 0.55)
    bg:SetEdgeColor(0.42, 0.76, 1, 0.85)
    bg:SetEdgeTexture("", 1, 1, 1)
    bg:SetMouseEnabled(false)
    self.cursorPlacementTexture.bg = bg

    local texture = wm:CreateControl(nil, self.cursorPlacementTexture, CT_TEXTURE)
    texture:SetAnchor(CENTER, self.cursorPlacementTexture, CENTER, 0, 0)
    texture:SetDimensions(42, 42)
    texture:SetMouseEnabled(false)
    self.cursorPlacementTexture.icon = texture

    local label = CreateLabel(self.cursorPlacementTexture, "", "ZoFontGameBold", 1, 1, 1, 1)
    label:SetAnchor(CENTER, self.cursorPlacementTexture, CENTER, 0, 0)
    label:SetDimensions(54, 36)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetMouseEnabled(false)
    self.cursorPlacementTexture.label = label
end

function UI:UpdateCursorPlacementPreview()
    if not self.cursorPlacementActive or not self.cursorPlacementTexture then return end

    local mouseX, mouseY
    if GetUIMousePosition then
        mouseX, mouseY = GetUIMousePosition()
    end
    if not mouseX or not mouseY then
        mouseX = GuiRoot:GetWidth() / 2
        mouseY = GuiRoot:GetHeight() / 2
    end

    self.cursorPlacementTexture:ClearAnchors()
    self.cursorPlacementTexture:SetAnchor(CENTER, GuiRoot, TOPLEFT, mouseX, mouseY)
end

function UI:StopCursorPlacement()
    self.cursorPlacementActive = false
    self.cursorPlacementChoiceKey = nil
    EVENT_MANAGER:UnregisterForUpdate(CURSOR_PLACEMENT_UPDATE_NAME)

    if self.cursorPlacementOverlay then
        self.cursorPlacementOverlay:SetHidden(true)
    end
    if self.cursorPlacementTexture then
        self.cursorPlacementTexture:SetHidden(true)
    end
    self:RefreshManagerWindow()
end

function UI:StartCursorPlacement(choice)
    if not choice then return end
    self:EnsureCursorPlacementControls()

    self.cursorPlacementActive = true
    self.cursorPlacementChoiceKey = tostring(choice.textureId or "") .. ":" .. tostring(choice.label or "")

    local texturePath = LibTeamShadows and LibTeamShadows.GetMarkerTexture and LibTeamShadows.GetMarkerTexture(choice.textureId) or "TeamShadowsManager/icons/markers/square_red.dds"
    self.cursorPlacementTexture.icon:SetTexture(texturePath)
    self.cursorPlacementTexture.icon:SetDimensions(choice.textureId >= 12 and 46 or 40, choice.textureId >= 12 and 46 or 40)
    self.cursorPlacementTexture.label:SetText((choice.label and not TextureHasNativeText(choice.textureId)) and choice.label or "")
    self.cursorPlacementTexture.label:SetColor(0, 0, 0, 1)
    self.cursorPlacementOverlay:SetHidden(false)
    self.cursorPlacementTexture:SetHidden(false)
    self:UpdateCursorPlacementPreview()

    EVENT_MANAGER:RegisterForUpdate(CURSOR_PLACEMENT_UPDATE_NAME, 16, function()
        self:UpdateCursorPlacementPreview()
    end)
    self:RefreshManagerWindow()
end
function UI:Initialize()
    local wm = WINDOW_MANAGER

    self.window = wm:CreateTopLevelWindow(WINDOW_NAME)
    self.window:SetDimensions(280, 108)
    self.window:SetClampedToScreen(true)
    self.window:SetMouseEnabled(true)
    self.window:SetMovable(false)
    self.window:SetHidden(true)
    self.window:SetDrawTier(DT_HIGH)

    self.backdrop = wm:CreateControl(nil, self.window, CT_BACKDROP)
    self.backdrop:SetAnchorFill(self.window)
    self.backdrop:SetCenterColor(0, 0, 0, 0)
    self.backdrop:SetEdgeColor(1, 1, 1, 0)
    self.backdrop:SetEdgeTexture("", 1, 1, 1)

    self.bossLabel = wm:CreateControl(nil, self.window, CT_LABEL)
    self.bossLabel:SetAnchor(TOP, self.window, TOP, 0, 8)
    self.bossLabel:SetDimensions(260, 24)
    self.bossLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.bossLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.bossLabel:SetFont("ZoFontGameBold")
    self.bossLabel:SetColor(1, 1, 1, 0.95)
    self.bossLabel:SetText("Prebuff")

    self.timerLabel = wm:CreateControl(nil, self.window, CT_LABEL)
    self.timerLabel:SetAnchor(TOP, self.bossLabel, BOTTOM, 0, 0)
    self.timerLabel:SetDimensions(260, 44)
    self.timerLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.timerLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.timerLabel:SetFont("ZoFontWinH1")
    self.timerLabel:SetText("")

    self.portalLabel = wm:CreateControl(nil, self.window, CT_LABEL)
    self.portalLabel:SetAnchor(TOP, self.timerLabel, BOTTOM, 0, -2)
    self.portalLabel:SetDimensions(270, 28)
    self.portalLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.portalLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.portalLabel:SetFont("ZoFontGameBold")
    self.portalLabel:SetColor(1, 1, 1, 0.95)
    self.portalLabel:SetText("")

    self.window:SetHandler("OnMoveStop", function(control)
        if not PBT.savedVars then return end
        PBT.savedVars.x = control:GetLeft() + (control:GetWidth() / 2) - GuiRoot:GetWidth() / 2
        PBT.savedVars.y = control:GetTop() + (control:GetHeight() / 2) - GuiRoot:GetHeight() / 2
    end)

    self.menuButton = wm:CreateTopLevelWindow(MENU_BUTTON_NAME)
    self.menuButton:SetClampedToScreen(true)
    self.menuButton:SetMouseEnabled(true)
    self.menuButton:SetMovable(true)
    self.menuButton:SetHidden(true)
    self.menuButton:SetDrawTier(DT_HIGH)

    self.menuButtonBackdrop = wm:CreateControl(nil, self.menuButton, CT_BACKDROP)
    self.menuButtonBackdrop:SetAnchorFill(self.menuButton)
    self.menuButtonBackdrop:SetCenterColor(0, 0, 0, 0)
    self.menuButtonBackdrop:SetEdgeColor(0, 0, 0, 0)
    self.menuButtonBackdrop:SetEdgeTexture("", 1, 1, 1)

    self.menuButtonTexture = wm:CreateControl(nil, self.menuButton, CT_TEXTURE)
    self.menuButtonTexture:SetAnchorFill(self.menuButton)
    self.menuButtonTexture:SetTexture(MENU_BUTTON_TEXTURE)
    self.menuButtonTexture:SetAlpha(1)
    self.menuButtonTexture:SetMouseEnabled(false)

    self.menuButtonFallbackLabel = wm:CreateControl(nil, self.menuButton, CT_LABEL)
    self.menuButtonFallbackLabel:SetAnchor(CENTER, self.menuButton, CENTER, 0, 0)
    self.menuButtonFallbackLabel:SetDimensions(64, 24)
    self.menuButtonFallbackLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.menuButtonFallbackLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.menuButtonFallbackLabel:SetFont("ZoFontGameBold")
    self.menuButtonFallbackLabel:SetColor(1, 1, 1, 0.9)
    self.menuButtonFallbackLabel:SetText("")
    self.menuButtonFallbackLabel:SetMouseEnabled(false)

    self.menuButtonHighlight = wm:CreateControl(nil, self.menuButton, CT_TEXTURE)
    self.menuButtonHighlight:SetAnchorFill(self.menuButton)
    self.menuButtonHighlight:SetTexture(MENU_BUTTON_TEXTURE)
    self.menuButtonHighlight:SetColor(0.30, 0.82, 1.00, 1)
    self.menuButtonHighlight:SetAlpha(0)
    self.menuButtonHighlight:SetMouseEnabled(false)

    self.menuButton:SetHandler("OnMouseEnter", function(control)
        if self.menuButtonHighlight then
            self.menuButtonHighlight:SetAlpha(0.28)
        end
        if InitializeTooltip and SetTooltipText then
            InitializeTooltip(InformationTooltip, control, TOP, 0, -6)
            SetTooltipText(InformationTooltip, "Team Shadows Manager")
        end
    end)

    self.menuButton:SetHandler("OnMouseExit", function()
        if self.menuButtonHighlight then
            self.menuButtonHighlight:SetAlpha(0)
        end
        if ClearTooltip then
            ClearTooltip(InformationTooltip)
        end
    end)

    self.menuButton:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control.dragStartLeft, control.dragStartTop = control:GetLeft(), control:GetTop()
        end
    end)

    self.menuButton:SetHandler("OnMouseUp", function(control, button, upInside)
        if upInside == false then return end
        if button == MOUSE_BUTTON_INDEX_LEFT then
            local startLeft, startTop = control.dragStartLeft, control.dragStartTop
            local moved = startLeft and startTop and (math.abs(control:GetLeft() - startLeft) > 2 or math.abs(control:GetTop() - startTop) > 2)
            control.dragStartLeft, control.dragStartTop = nil, nil
            if not moved then self:ToggleManagerWindow() end
        end
    end)

    self.menuButton:SetHandler("OnMoveStop", function(control)
        if not PBT.savedVars then return end
        PBT.savedVars.menuButtonX = control:GetLeft() + (control:GetWidth() / 2) - GuiRoot:GetWidth() / 2
        PBT.savedVars.menuButtonY = control:GetTop() + (control:GetHeight() / 2) - GuiRoot:GetHeight() / 2
    end)

    self:CreateManagerWindow()
end
function UI:SetBackdropVisible(visible)
    if not self.backdrop then return end

    if visible then
        self.backdrop:SetCenterColor(0, 0, 0, 0.45)
        self.backdrop:SetEdgeColor(1, 1, 1, 0.18)
    else
        self.backdrop:SetCenterColor(0, 0, 0, 0)
        self.backdrop:SetEdgeColor(1, 1, 1, 0)
    end
end

function UI:ApplySettings()
    if not self.window or not PBT.savedVars then return end

    local saved = PBT.savedVars
    local color = saved.color or PBT.defaults.color

    self.window:ClearAnchors()
    self.window:SetAnchor(CENTER, GuiRoot, CENTER, saved.x or 0, saved.y or -220)
    self.window:SetScale(Clamp(saved.scale, 0.5, 2.5))
    self.window:SetMovable(saved.unlocked == true)

    self.timerLabel:SetColor(
        Clamp(color.r, 0, 1),
        Clamp(color.g, 0, 1),
        Clamp(color.b, 0, 1),
        Clamp(color.a or 1, 0, 1)
    )

    if saved.unlocked and self.window:IsHidden() then
        self:ShowIdle()
    end

    self:ApplyMenuButtonSettings()

end

function UI:ApplyMenuButtonSettings()
    if not self.menuButton or not PBT.savedVars then return end

    local saved = PBT.savedVars
    local size = Clamp(saved.menuButtonSize, 28, 96)

    self.menuButton:SetDimensions(size, size)
    self.menuButton:ClearAnchors()
    self.menuButton:SetAnchor(CENTER, GuiRoot, CENTER, saved.menuButtonX or 0, saved.menuButtonY or 0)
    self.menuButton:SetMovable(true)
    self.menuButton:SetHidden(saved.menuButtonEnabled == false)
    self:RefreshPermanentIconButton()
end

function UI:SetUnlocked(unlocked)
    if not PBT.savedVars then return end

    PBT.savedVars.unlocked = unlocked == true
    self:ApplySettings()

    if PBT.savedVars.unlocked then
        self:ShowIdle()
    elseif not PBT.isRunning and not PBT.portalStatusActive then
        self:Hide()
    end
end

function UI:ShowIdle()
    if not self.window then return end
    self:SetBackdropVisible(true)
    self.bossLabel:SetText("Team Shadows Manager")
    self.timerLabel:SetText("MOVE")
    if self.portalLabel then
        self.portalLabel:SetText("")
    end
    self.window:SetHidden(false)
end

function UI:ShowCountdown(bossName, secondsRemaining)
    if not self.window then return end

    local color = (PBT.savedVars and PBT.savedVars.color) or (PBT.defaults and PBT.defaults.color) or { r = 1, g = 0.12, b = 0.08, a = 1 }
    self:SetBackdropVisible(false)
    self.bossLabel:SetText(bossName or "Prebuff")
    self.timerLabel:SetColor(Clamp(color.r, 0, 1), Clamp(color.g, 0, 1), Clamp(color.b, 0, 1), Clamp(color.a or 1, 0, 1))
    self.timerLabel:SetText(tostring(secondsRemaining or ""))
    if self.portalLabel and not PBT.portalStatusActive then
        self.portalLabel:SetText("")
    end
    self.window:SetHidden(false)
end

function UI:ShowGo(bossName)
    if not self.window then return end

    local color = (PBT.savedVars and PBT.savedVars.goColor) or (PBT.defaults and PBT.defaults.goColor) or { r = 0.2, g = 1, b = 0.2, a = 1 }
    self:SetBackdropVisible(false)
    self.bossLabel:SetText(bossName or "Prebuff")
    self.timerLabel:SetColor(Clamp(color.r, 0, 1), Clamp(color.g, 0, 1), Clamp(color.b, 0, 1), Clamp(color.a or 1, 0, 1))
    self.timerLabel:SetText("GO")
    if self.portalLabel and not PBT.portalStatusActive then
        self.portalLabel:SetText("")
    end
    self.window:SetHidden(false)
end

function UI:ShowPortalStatus(text, r, g, b)
    if not self.window or not self.portalLabel then return end

    PBT.portalStatusActive = true
    self:SetBackdropVisible(false)
    self.portalLabel:SetText(text or "")
    self.portalLabel:SetColor(Clamp(r, 0, 1), Clamp(g, 0, 1), Clamp(b, 0, 1), 1)

    if not PBT.isRunning then
        self.bossLabel:SetText("Nahviintaas")
        self.timerLabel:SetText(L("PORTAIL"))
        self.timerLabel:SetColor(1, 1, 1, 0.95)
    end

    self.window:SetHidden(false)
end

function UI:ShowMarkerReadyAlert()
    if not self.window then return end

    self:SetBackdropVisible(false)
    self.bossLabel:SetText("TEAM SHADOWS")
    self.timerLabel:SetColor(0.2, 0.9, 1, 1)
    self.timerLabel:SetText(L("PLACER ICON"))
    if self.portalLabel then
        self.portalLabel:SetText(L("PRET"))
        self.portalLabel:SetColor(0.3, 1, 0.3, 1)
    end
    self.window:SetHidden(false)
end

function UI:HidePortalStatus()
    PBT.portalStatusActive = false

    if self.portalLabel then
        self.portalLabel:SetText("")
    end

    if self.window and not PBT.isRunning and not (PBT.savedVars and PBT.savedVars.unlocked) then
        self.window:SetHidden(true)
    end
end

function UI:Hide()
    if not self.window then return end

    if PBT.portalStatusActive then
        self.window:SetHidden(false)
        return
    end

    self.window:SetHidden(true)
end

function PBT.SetScale(value)
    if not PBT.savedVars then return false end

    local scale = Clamp(value, 0.5, 2.5)
    PBT.savedVars.scale = scale
    UI:ApplySettings()
    return true, scale
end

function PBT.SetColor(r, g, b)
    if not PBT.savedVars then return false end

    PBT.savedVars.color = {
        r = Clamp(r, 0, 1),
        g = Clamp(g, 0, 1),
        b = Clamp(b, 0, 1),
        a = 1,
    }

    UI:ApplySettings()
    return true, PBT.savedVars.color
end


-- =====================================================================
--  FENETRE DE GESTION MODERNE (style BuffsManager)
--  Reutilise les noms de methodes existants (CreateManagerWindow,
--  ShowManagerWindow, ToggleManagerWindow, RefreshManagerWindow) et le
--  champ self.managerWindow : tous les appels existants (logo, /tsm,
--  placement) ouvrent donc directement cette fenetre.
-- =====================================================================
local WM = WINDOW_MANAGER

local MC = {
    panel    = { 0.012, 0.018, 0.028, 0.985 }, card    = { 0.026, 0.036, 0.050, 0.97 },
    cardEdge = { 0.43, 0.34, 0.20, 1.0 },    gold    = { 0.83, 0.68, 0.40, 1.0 },
    cyan     = { 0.27, 0.78, 1.00, 1.0 },    blue    = { 0.16, 0.55, 0.95, 1.0 },
    text     = { 0.91, 0.91, 0.88, 1.0 },    textDim = { 0.64, 0.61, 0.55, 1.0 },
    track    = { 0.12, 0.15, 0.19, 1.0 },    hover   = { 0.08, 0.12, 0.15, 1.0 },
}
local MF_TITLE, MF_HEADER, MF_LABEL, MF_SMALL = "ZoFontWinH2", "ZoFontWinH4", "ZoFontGameBold", "ZoFontGameSmall"

local MTABS = {
    { id = "markers", label = "MARKERS" },
    { id = "pull",    label = "DÉCOMPTE & ANNONCE" },
    { id = "timers",  label = "TIMERS" },
}
local activeManagerTab = "markers"

local QUICK_ICONS = {
    { name = "F", id = 10 }, { name = "FV", id = 11 }, { name = "MT", id = 8 }, { name = "OT", id = 9 },
    { name = "H1", id = 1, label = "H1" }, { name = "H2", id = 1, label = "H2" },
    { name = "1", id = 1, label = "1" }, { name = "2", id = 1, label = "2" }, { name = "3", id = 1, label = "3" },
    { name = "4", id = 1, label = "4" }, { name = "5", id = 1, label = "5" }, { name = "6", id = 1, label = "6" },
    { name = "7", id = 1, label = "7" }, { name = "8", id = 1, label = "8" }, { name = "9", id = 1, label = "9" },
    { name = "10", id = 1, label = "10" }, { name = "S", id = 12 }, { name = "Buche", id = 13 }, { name = "Fish", id = 14 },
    { name = "Hyxtra", id = 15 }, { name = "Lexi", id = 16 }, { name = "Og", id = 17 }, { name = "Ogu", id = 18 },
    { name = "Ray", id = 19 }, { name = "Ronce", id = 20 }, { name = "Sel", id = 21 }, { name = "Sla", id = 22 }, { name = "Tim", id = 23 },
}
local ICON_COLORS = {
    [1] = { r = 0.85, g = 0.05, b = 0.04 }, [2] = { r = 0.05, g = 0.28, b = 0.95 },
    [3] = { r = 1.0, g = 0.86, b = 0.05 },  [4] = { r = 0.05, g = 0.75, b = 0.15 },
    [5] = { r = 1.0, g = 0.5, b = 0.05 },   [6] = { r = 1.0, g = 0.15, b = 0.75 },
    [7] = { r = 0.45, g = 0.85, b = 1.0 },
}
local MLABEL_ORDER = { "auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "H1", "H2", "MT", "OT" }
local MARKER_ROWS = 6
local M_FALLBACK_TEX = "TeamShadowsManager/icons/markers/square_red.dds"

local function unpack4(c) return c[1], c[2], c[3], c[4] end
local function SV() return PBT.savedVars or {} end
local function mclamp(v, lo, hi) v = tonumber(v) or lo; if v < lo then return lo elseif v > hi then return hi else return v end end
local function MarkerTexture(id) return (LibTeamShadows and LibTeamShadows.GetMarkerTexture and LibTeamShadows.GetMarkerTexture(id)) or M_FALLBACK_TEX end
local function MLabelText(labelId) return (LibTeamShadows and LibTeamShadows.GetMarkerLabel and LibTeamShadows.GetMarkerLabel(labelId)) or tostring(labelId) end
local function RefreshWorld() if PBT.RefreshSavedMarkers then PBT.RefreshSavedMarkers() end end

local function OpenContactMail(recipient)
    if not SCENE_MANAGER then return end
    SCENE_MANAGER:Show("mailSend")
    zo_callLater(function()
        if ZO_MailSendToField then ZO_MailSendToField:SetText(recipient or "@TeamFF") end
        if ZO_MailSendSubjectField then ZO_MailSendSubjectField:SetText("Team Shadows Manager") end
        if ZO_MailSendBodyField then
            ZO_MailSendBodyField:SetText("")
            ZO_MailSendBodyField:TakeFocus()
        end
    end, 200)
end

local function TextureDisplayName(textureId, fallback)
    textureId = tonumber(textureId) or 1
    local language = PBT.GetLanguage and PBT.GetLanguage() or "fr"
    local labels = PBT.MarkerTextureLabels and PBT.MarkerTextureLabels[language]
    return labels and labels[textureId] or fallback or ("Icon " .. tostring(textureId))
end

local function QuickIconDisplayName(choice)
    if not choice then return "" end
    if choice.label then return tostring(choice.label) end
    if choice.id >= 12 then return TextureDisplayName(choice.id, choice.name) end
    return tostring(choice.name or TextureDisplayName(choice.id))
end

local function SavedMarkerIconName(marker)
    if type(marker) ~= "table" then return "" end
    local custom = tostring(marker.customLabel or "")
    if custom ~= "" then return custom end
    local textureId = tonumber(marker.textureId) or 1
    if textureId == 1 and marker.labelId then return MLabelText(marker.labelId) end
    for _, choice in ipairs(QUICK_ICONS) do
        if choice.id == textureId and not choice.label then return QuickIconDisplayName(choice) end
    end
    return TextureDisplayName(textureId)
end

local function Backdrop(parent, color, edge)
    local b = WM:CreateControl(nil, parent, CT_BACKDROP)
    b:SetCenterColor(unpack4(color))
    b:SetEdgeColor(edge and edge[1] or 0, edge and edge[2] or 0, edge and edge[3] or 0, edge and edge[4] or 0)
    b:SetEdgeTexture("", 1, 1, 1)
    return b
end
local function MLabel(parent, font, color, text, align)
    local l = WM:CreateControl(nil, parent, CT_LABEL)
    l:SetFont(font); l:SetColor(unpack4(color))
    if text then
        l:SetText(L(text))
        if PBT.HasLocalizedLiteral and PBT.HasLocalizedLiteral(text) then
            UI.localizedControls = UI.localizedControls or {}
            UI.localizedControls[#UI.localizedControls + 1] = { control = l, source = text }
        end
    end
    if align then l:SetHorizontalAlignment(align) end
    return l
end
local function FlatButton(parent, text, w, h, onClick, bgColor, txtColor)
    local btn = WM:CreateControl(nil, parent, CT_CONTROL)
    btn:SetDimensions(w, h); btn:SetMouseEnabled(true)
    btn.bg = Backdrop(btn, bgColor or MC.card, MC.cardEdge); btn.bg:SetAnchorFill(btn)
    btn.label = MLabel(btn, MF_LABEL, txtColor or MC.text, text, TEXT_ALIGN_CENTER)
    btn.label:SetAnchor(CENTER, btn, CENTER, 0, 0)
    btn.baseColor = bgColor or MC.card
    btn:SetHandler("OnMouseEnter", function() btn.bg:SetCenterColor(unpack4(MC.hover)) end)
    btn:SetHandler("OnMouseExit",  function() btn.bg:SetCenterColor(unpack4(btn.baseColor)) end)
    btn:SetHandler("OnMouseUp", function(_, _, upInside) if upInside and onClick then onClick() end end)
    return btn
end
local function MakeCard(parent, title)
    local card = WM:CreateControl(nil, parent, CT_CONTROL)
    card.bg = Backdrop(card, MC.card, MC.cardEdge); card.bg:SetAnchorFill(card)
    card.title = MLabel(card, MF_HEADER, MC.gold, title, TEXT_ALIGN_CENTER)
    card.title:SetAnchor(TOPLEFT, card, TOPLEFT, 18, 10)
    card.title:SetAnchor(TOPRIGHT, card, TOPRIGHT, -18, 10)
    card.titleLine = Backdrop(card, { MC.gold[1], MC.gold[2], MC.gold[3], 0.45 })
    card.titleLine:SetAnchor(TOPLEFT, card, TOPLEFT, 18, 38)
    card.titleLine:SetAnchor(TOPRIGHT, card, TOPRIGHT, -18, 38)
    card.titleLine:SetHeight(1)
    card.content = WM:CreateControl(nil, card, CT_CONTROL)
    card.content:SetAnchor(TOPLEFT, card, TOPLEFT, 18, 46)
    card.content:SetAnchor(BOTTOMRIGHT, card, BOTTOMRIGHT, -18, -12)
    return card
end
local function MakeToggle(parent, getFunc, setFunc)
    local W, H = 44, 22
    local tg = WM:CreateControl(nil, parent, CT_CONTROL)
    tg:SetDimensions(W, H); tg:SetMouseEnabled(true)
    tg.track = Backdrop(tg, MC.track); tg.track:SetAnchorFill(tg)
    tg.knob  = Backdrop(tg, { 0.95, 0.96, 0.98, 1 }); tg.knob:SetDimensions(H - 6, H - 6)
    local function redraw()
        local on = getFunc() == true
        tg.track:SetCenterColor(on and MC.blue[1] or MC.track[1], on and MC.blue[2] or MC.track[2], on and MC.blue[3] or MC.track[3], 1)
        tg.knob:ClearAnchors()
        if on then tg.knob:SetAnchor(RIGHT, tg, RIGHT, -3, 0) else tg.knob:SetAnchor(LEFT, tg, LEFT, 3, 0) end
    end
    tg:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then setFunc(getFunc() ~= true); redraw() end end)
    tg.Redraw = redraw; redraw()
    return tg
end
local function MakeSwatch(parent, getFunc, setFunc)
    local sw = WM:CreateControl(nil, parent, CT_CONTROL)
    sw:SetDimensions(48, 26); sw:SetMouseEnabled(true)
    sw.bg = Backdrop(sw, { 1, 1, 1, 1 }, MC.cardEdge); sw.bg:SetAnchorFill(sw)
    local function redraw()
        local c = getFunc() or {}
        sw.bg:SetCenterColor(c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1, 1)
    end
    sw:SetHandler("OnMouseUp", function(_, _, upInside)
        if not upInside or not COLOR_PICKER then return end
        local c = getFunc() or {}
        COLOR_PICKER:Show(function(r, g, b, a) setFunc(r, g, b, a or 1); redraw() end,
            c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1, c.a or 1, L("Couleur"))
    end)
    sw.Redraw = redraw; redraw()
    return sw
end
local function MakeSlider(parent, width, minV, maxV, step, getFunc, setFunc, suffix)
    local sl = WM:CreateControl(nil, parent, CT_CONTROL)
    sl:SetDimensions(width, 22); sl:SetMouseEnabled(true)
    local trackW = width - 44
    sl.track = Backdrop(sl, MC.track); sl.track:SetDimensions(trackW, 6); sl.track:SetAnchor(LEFT, sl, LEFT, 0, 0)
    sl.fill  = Backdrop(sl.track, MC.blue); sl.fill:SetAnchor(LEFT, sl.track, LEFT, 0, 0); sl.fill:SetHeight(6)
    sl.knob  = Backdrop(sl.track, { 0.95, 0.96, 0.98, 1 }); sl.knob:SetDimensions(13, 13)
    sl.value = MLabel(sl, MF_SMALL, MC.text, "", TEXT_ALIGN_RIGHT); sl.value:SetAnchor(RIGHT, sl, RIGHT, 0, 0); sl.value:SetDimensions(40, 22)
    local function ratioToVal(r) local v = minV + (maxV - minV) * r; if step and step > 0 then v = zo_round(v / step) * step end; return mclamp(v, minV, maxV) end
    local function redraw()
        local v = getFunc() or minV
        local ratio = (maxV > minV) and mclamp((v - minV) / (maxV - minV), 0, 1) or 0
        sl.fill:SetWidth(zo_max(1, trackW * ratio))
        sl.knob:ClearAnchors(); sl.knob:SetAnchor(CENTER, sl.track, LEFT, trackW * ratio, 0)
        sl.value:SetText(((step and step < 1) and string.format("%.2f", v) or tostring(zo_round(v))) .. (suffix or ""))
    end
    local function setFromCursor()
        local mx = GetUIMousePosition and GetUIMousePosition() or 0
        local left = sl.track:GetLeft() or 0
        local w = sl.track:GetWidth() or trackW
        if w <= 0 then w = trackW end
        setFunc(ratioToVal(mclamp((mx - left) / w, 0, 1))); redraw()
    end
    sl:SetHandler("OnMouseDown", function() sl.dragging = true; setFromCursor() end)
    sl:SetHandler("OnMouseUp",   function() sl.dragging = false end)
    sl:SetHandler("OnUpdate",    function() if sl.dragging then setFromCursor() end end)
    sl.Redraw = redraw; redraw()
    return sl
end
local function MakeEditbox(parent, width, getFunc, setFunc, maxChars)
    local box = WM:CreateControl(nil, parent, CT_CONTROL)
    box:SetDimensions(width, 30); box:SetMouseEnabled(true)
    box.bg = Backdrop(box, { 0.04, 0.05, 0.07, 1 }, MC.cardEdge); box.bg:SetAnchorFill(box)
    box.edit = WM:CreateControl(nil, box, CT_EDITBOX)
    box.edit:SetAnchor(TOPLEFT, box, TOPLEFT, 10, 0); box.edit:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, -10, 0)
    box.edit:SetFont(MF_LABEL); box.edit:SetColor(unpack4(MC.text))
    box.edit:SetMaxInputChars(maxChars or 40); box.edit:SetMouseEnabled(true)
    if box.edit.SetEditEnabled then box.edit:SetEditEnabled(true) end
    box.edit:SetText(getFunc() or "")
    local function focus() box.edit:TakeFocus() end
    box.edit:SetHandler("OnMouseUp", focus); box:SetHandler("OnMouseUp", focus)
    box.edit:SetHandler("OnTextChanged", function(self) if setFunc then setFunc(self:GetText() or "") end end)
    box.edit:SetHandler("OnEnter",  function(self) self:LoseFocus() end)
    box.edit:SetHandler("OnEscape", function(self) self:LoseFocus() end)
    box.Redraw = function()
        if box.edit.HasFocus and box.edit:HasFocus() then return end
        box.edit:SetText(getFunc() or "")
    end
    return box
end

-- etat marker edite (nil = valeurs par defaut)
local editIndex, selectedIndex, markerPage = nil, nil, 1
local function EditingMarker()
    local list = SV().groupBeaconSavedMarkers or {}
    if editIndex and list[editIndex] then return list[editIndex] end
    editIndex = nil; return nil
end
local function GetTexId() local m = EditingMarker(); return mclamp((m and m.textureId) or SV().groupBeaconTextureId, 1, 23) end
local function GetCurLabel() local m = EditingMarker(); if m and m.labelId then return MLabelText(m.labelId) end; return SV().groupBeaconLabel or "auto" end
local function GetColor() local m = EditingMarker(); return (m and m.color) or SV().groupBeaconColor or ICON_COLORS[1] end
local function GetSize() local m = EditingMarker(); return (m and m.size) or SV().groupBeaconSize or 112 end
local function GetDuration() local m = EditingMarker(); return (m and m.durationMs and m.durationMs / 1000) or SV().groupBeaconDuration or 8 end
local function GetHeight() local m = EditingMarker(); return (m and m.heightOffset) or SV().groupBeaconHeight or 0 end

local function ApplyQuickIcon(choice)
    if not PBT.savedVars then return end
    local m = EditingMarker()
    local labelId = choice.label and PBT.beaconLabelIds and PBT.beaconLabelIds[choice.label] or nil
    if m and PBT.UpdateSavedMarker then
        PBT.UpdateSavedMarker(editIndex, { textureId = choice.id })
        if labelId then PBT.UpdateSavedMarker(editIndex, { labelId = labelId }) end
        if choice.id >= 12 then PBT.UpdateSavedMarker(editIndex, { size = (PBT.defaults and PBT.defaults.groupBeaconSize) or 112 }) end
    else
        SV().groupBeaconTextureId = choice.id
        SV().groupBeaconLabel = choice.label or "auto"
        if ICON_COLORS[choice.id] then SV().groupBeaconColor = ICON_COLORS[choice.id] end
        if choice.id >= 12 then SV().groupBeaconSize = (PBT.defaults and PBT.defaults.groupBeaconSize) or 112 end
    end
    UI:RefreshManagerWindow()
end
local function CycleLabel()
    local cur, nxt = GetCurLabel(), nil
    for i, v in ipairs(MLABEL_ORDER) do if v == cur then nxt = MLABEL_ORDER[(i % #MLABEL_ORDER) + 1] break end end
    nxt = nxt or "auto"
    local m = EditingMarker()
    if m and PBT.UpdateSavedMarker then
        local labelId = PBT.beaconLabelIds and PBT.beaconLabelIds[nxt] or nil
        if labelId then PBT.UpdateSavedMarker(editIndex, { labelId = labelId }) end
    else
        SV().groupBeaconLabel = nxt
    end
    UI:RefreshManagerWindow()
end
local function SetColorVal(r, g, b)
    local m = EditingMarker()
    if m and PBT.UpdateSavedMarker then PBT.UpdateSavedMarker(editIndex, { color = { r = r, g = g, b = b } })
    else SV().groupBeaconColor = { r = r, g = g, b = b }; RefreshWorld() end
end
local function SetSizeVal(v)
    local m = EditingMarker()
    if m and PBT.UpdateSavedMarker then PBT.UpdateSavedMarker(editIndex, { size = v }) else SV().groupBeaconSize = v; RefreshWorld() end
end
local function SetDurationVal(v)
    local m = EditingMarker()
    if m and PBT.UpdateSavedMarker then PBT.UpdateSavedMarker(editIndex, { durationMs = v * 1000 }) else SV().groupBeaconDuration = v; RefreshWorld() end
end
local function SetHeightVal(v)
    local m = EditingMarker()
    if m and PBT.UpdateSavedMarker then PBT.UpdateSavedMarker(editIndex, { heightOffset = v })
    else SV().groupBeaconHeight = v; for _, mk in ipairs(SV().groupBeaconSavedMarkers or {}) do mk.heightOffset = v end; RefreshWorld() end
end

-- ---------------- onglet MARKERS ----------------
local function BuildMarkersTab(pane)
    pane.widgets = {}
    local function track(w) table.insert(pane.widgets, w); return w end

    local cfg = MakeCard(pane, "MARKER ACTIF")
    -- One-pixel inset keeps the backdrop's left edge inside the tab clipping
    -- area, so the first MARKERS panel is visibly closed on every UI scale.
    cfg:SetAnchor(TOPLEFT, pane, TOPLEFT, 1, 0); cfg:SetDimensions(416, 300)
    local c = cfg.content

    pane.previewBg = Backdrop(c, { 0.015, 0.018, 0.022, 1 }, MC.cardEdge)
    pane.previewBg:SetDimensions(86, 86); pane.previewBg:SetAnchor(TOPLEFT, c, TOPLEFT, 0, 4)
    pane.previewTex = WM:CreateControl(nil, c, CT_TEXTURE)
    pane.previewTex:SetDimensions(70, 70); pane.previewTex:SetAnchor(CENTER, pane.previewBg, CENTER, 0, 0)
    pane.previewLbl = MLabel(c, "ZoFontWinH1", { 1, 1, 1, 1 }, "1", TEXT_ALIGN_CENTER)
    pane.previewLbl:SetAnchor(CENTER, pane.previewTex, CENTER, 0, 0); pane.previewLbl:SetDimensions(80, 50)
    pane.previewLbl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    pane.editBanner = MLabel(c, MF_SMALL, MC.gold, "")
    pane.editBanner:SetAnchor(TOPLEFT, pane.previewBg, BOTTOMLEFT, 0, 8); pane.editBanner:SetWidth(120)

    local rx = 110
    MLabel(c, MF_SMALL, MC.textDim, "Texte / rôle"):SetAnchor(TOPLEFT, c, TOPLEFT, rx, 0)
    pane.labelBtn = track(FlatButton(c, "Auto 1-10", 160, 26, CycleLabel)); pane.labelBtn:SetAnchor(TOPLEFT, c, TOPLEFT, rx, 16)
    MLabel(c, MF_SMALL, MC.textDim, "Couleur"):SetAnchor(TOPLEFT, c, TOPLEFT, rx + 180, 0)
    track(MakeSwatch(c, GetColor, SetColorVal)):SetAnchor(TOPLEFT, c, TOPLEFT, rx + 180, 16)
    MLabel(c, MF_SMALL, MC.textDim, "Taille"):SetAnchor(TOPLEFT, c, TOPLEFT, rx, 50)
    track(MakeSlider(c, 260, 24, 160, 2, GetSize, SetSizeVal)):SetAnchor(TOPLEFT, c, TOPLEFT, rx, 66)
    MLabel(c, MF_SMALL, MC.textDim, "Durée"):SetAnchor(TOPLEFT, c, TOPLEFT, rx, 92)
    track(MakeSlider(c, 260, 1, 60, 1, GetDuration, SetDurationVal, "s")):SetAnchor(TOPLEFT, c, TOPLEFT, rx, 108)
    MLabel(c, MF_SMALL, MC.textDim, "Hauteur"):SetAnchor(TOPLEFT, c, TOPLEFT, rx, 134)
    track(MakeSlider(c, 260, -30, 40, 0.5, GetHeight, SetHeightVal)):SetAnchor(TOPLEFT, c, TOPLEFT, rx, 150)

    MLabel(c, MF_SMALL, MC.text, "Placement activé"):SetAnchor(TOPLEFT, c, TOPLEFT, 0, 180)
    track(MakeToggle(c, function() return SV().groupBeaconPlacementEnabled == true end,
        function(v) SV().groupBeaconPlacementEnabled = v end)):SetAnchor(TOPLEFT, c, TOPLEFT, 150, 178)
    track(FlatButton(c, "PLACER (visée réticule)", 195, 30, function()
        SV().groupBeaconPlacementEnabled = true
        if PBT.PlaceMarkerFromReticle then PBT.PlaceMarkerFromReticle() end
        editIndex = nil; selectedIndex = nil; UI:RefreshManagerWindow()
    end, { 0.12, 0.30, 0.55, 1 }, MC.text)):SetAnchor(TOPLEFT, c, TOPLEFT, 0, 210)
    track(FlatButton(c, "VIDER L'ÉCRAN", 165, 30, function()
        if PBT.ClearSavedMarkers then PBT.ClearSavedMarkers() end
        editIndex = nil; selectedIndex = nil; UI:RefreshManagerWindow()
    end, { 0.30, 0.12, 0.12, 1 }, MC.text)):SetAnchor(TOPLEFT, c, TOPLEFT, 205, 210)

    local grid = MakeCard(pane, "ICÔNES")
    grid:SetAnchor(TOPLEFT, cfg, TOPRIGHT, 14, 0); grid:SetDimensions(531, 300)
    local g = grid.content
    pane.iconCells = {}
    local cols, cw, ch, gap = 9, 52, 50, 3
    for i, choice in ipairs(QUICK_ICONS) do
        local col, rowi = (i - 1) % cols, math.floor((i - 1) / cols)
        local cell = WM:CreateControl(nil, g, CT_CONTROL)
        cell:SetDimensions(cw, ch); cell:SetAnchor(TOPLEFT, g, TOPLEFT, col * (cw + gap), rowi * (ch + gap)); cell:SetMouseEnabled(true)
        cell.bg = Backdrop(cell, { 0.04, 0.05, 0.07, 1 }, MC.cardEdge); cell.bg:SetAnchorFill(cell)
        cell.tex = WM:CreateControl(nil, cell, CT_TEXTURE)
        cell.tex:SetDimensions(28, 28); cell.tex:SetAnchor(TOP, cell, TOP, 0, 4); cell.tex:SetTexture(MarkerTexture(choice.id))
        cell.previewLbl = MLabel(cell, "ZoFontGameBold", { 1, 1, 1, 1 }, "", TEXT_ALIGN_CENTER)
        cell.previewLbl:SetAnchor(CENTER, cell.tex, CENTER, 0, 0); cell.previewLbl:SetDimensions(34, 28)
        cell.lbl = MLabel(cell, MF_SMALL, MC.textDim, choice.name, TEXT_ALIGN_CENTER)
        cell.lbl:SetAnchor(BOTTOM, cell, BOTTOM, 0, -3); cell.lbl:SetWidth(cw)
        cell.choice = choice
        cell:SetHandler("OnMouseEnter", function() if not cell.selected then cell.bg:SetEdgeColor(unpack4(MC.cyan)) end end)
        cell:SetHandler("OnMouseExit",  function() if not cell.selected then cell.bg:SetEdgeColor(unpack4(MC.cardEdge)) end end)
        cell:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then ApplyQuickIcon(choice) end end)
        pane.iconCells[i] = cell
    end

    local listCard = MakeCard(pane, "MARKERS ENREGISTRÉS")
    listCard:SetAnchor(TOPLEFT, cfg, BOTTOMLEFT, 0, 14); listCard:SetDimensions(416, 282)
    local lc = listCard.content
    pane.listInfo = MLabel(lc, MF_SMALL, MC.textDim, "0 marker"); pane.listInfo:SetAnchor(TOPLEFT, lc, TOPLEFT, 0, 0)
    -- pagination en haut a droite (comme l'ancienne fenetre)
    pane.nextBtn = FlatButton(lc, ">", 30, 22, function() markerPage = markerPage + 1; UI:RefreshList() end)
    pane.nextBtn:SetAnchor(TOPRIGHT, lc, TOPRIGHT, 0, -2)
    pane.prevBtn = FlatButton(lc, "<", 30, 22, function() markerPage = math.max(1, markerPage - 1); UI:RefreshList() end)
    pane.prevBtn:SetAnchor(RIGHT, pane.nextBtn, LEFT, -6, 0)
    pane.rows = {}
    for i = 1, MARKER_ROWS do
        local row = WM:CreateControl(nil, lc, CT_CONTROL)
        row:SetDimensions(380, 26); row:SetAnchor(TOPLEFT, lc, TOPLEFT, 0, 20 + (i - 1) * 30); row:SetMouseEnabled(true)
        row.bg = Backdrop(row, { 0.04, 0.05, 0.07, 1 }, MC.cardEdge); row.bg:SetAnchorFill(row)
        row.badge = WM:CreateControl(nil, row, CT_TEXTURE); row.badge:SetDimensions(20, 20); row.badge:SetAnchor(LEFT, row, LEFT, 8, 0)
        row.txt = MLabel(row, MF_SMALL, MC.text, ""); row.txt:SetAnchor(LEFT, row.badge, RIGHT, 8, 0); row.txt:SetWidth(230)
        row.distance = MLabel(row, MF_SMALL, MC.cyan, "", TEXT_ALIGN_RIGHT)
        row.distance:SetAnchor(RIGHT, row, RIGHT, -8, 0); row.distance:SetWidth(92)
        row:SetHandler("OnMouseUp", function(_, _, upInside)
            if not upInside then return end
            local idx = ((markerPage - 1) * MARKER_ROWS) + i
            local list = SV().groupBeaconSavedMarkers or {}
            selectedIndex = list[idx] and idx or nil   -- clic = selection seule
            UI:RefreshList()
        end)
        row:SetHandler("OnMouseWheel", function(_, delta)
            local list = SV().groupBeaconSavedMarkers or {}
            local maxPage = math.max(1, math.ceil(#list / MARKER_ROWS))
            markerPage = mclamp(markerPage - delta, 1, maxPage); UI:RefreshList()
        end)
        pane.rows[i] = row
    end
    -- barre d'actions : MODIFIER / FIN MODIF / SUPPRIMER
    pane.editBtn = FlatButton(lc, "MODIFIER", 120, 26, function()
        local list = SV().groupBeaconSavedMarkers or {}
        if selectedIndex and list[selectedIndex] then editIndex = selectedIndex; UI:RefreshManagerWindow() end
    end, { 0.12, 0.30, 0.55, 1 }, MC.text)
    pane.editBtn:SetAnchor(BOTTOMLEFT, lc, BOTTOMLEFT, 0, 0)
    pane.doneBtn = FlatButton(lc, "FIN MODIF", 120, 26, function()
        editIndex = nil; selectedIndex = nil; UI:RefreshManagerWindow()
    end)
    pane.doneBtn:SetAnchor(LEFT, pane.editBtn, RIGHT, 8, 0)
    pane.delBtn = FlatButton(lc, "SUPPRIMER", 120, 26, function()
        if selectedIndex and PBT.DeleteSavedMarker then PBT.DeleteSavedMarker(selectedIndex) end
        selectedIndex = nil; editIndex = nil; UI:RefreshManagerWindow()
    end, { 0.30, 0.12, 0.12, 1 }, MC.text)
    pane.delBtn:SetAnchor(LEFT, pane.doneBtn, RIGHT, 8, 0)

    local packCard = MakeCard(pane, "PACKS & PARTAGE")
    packCard:SetAnchor(TOPLEFT, grid, BOTTOMLEFT, 0, 14); packCard:SetDimensions(531, 282)
    pane.packCard = packCard
    local pc = packCard.content
    pane.packCells = {}
    for slot = 1, 3 do
        local cell = FlatButton(pc, "Pack " .. slot, 110, 28, function()
            editIndex = nil
            if PBT.ActivateCurrentMarkerSet then PBT.ActivateCurrentMarkerSet(slot) else SV().groupBeaconMarkerSetSlot = slot end
            UI:RefreshManagerWindow()
        end)
        cell:SetAnchor(TOPLEFT, pc, TOPLEFT, (slot - 1) * 120, 0); cell.slot = slot
        pane.packCells[slot] = cell
        local nameBox = track(MakeEditbox(pc, 110, function() return PBT.GetMarkerPackName and PBT.GetMarkerPackName(slot) or ("Pack " .. slot) end, nil, 24))
        nameBox:SetAnchor(TOPLEFT, pc, TOPLEFT, (slot - 1) * 120, 32)
        nameBox.edit:SetHandler("OnFocusLost", function(self)
            if PBT.RenameMarkerPack then PBT.RenameMarkerPack(slot, self:GetText()) end
            UI:RefreshManagerWindow()
        end)
    end
    pane.shareBox = MakeEditbox(pc, 470, function() return "" end, nil, 6000)
    pane.shareBox:SetAnchor(TOPLEFT, pc, TOPLEFT, 0, 72); pane.shareBox:SetHeight(76)
    if pane.shareBox.edit.SetMultiLine then pane.shareBox.edit:SetMultiLine(true) end
    FlatButton(pc, "EXPORTER", 118, 30, function()
        local slot = SV().groupBeaconMarkerSetSlot
        local code = (PBT.ExportCurrentMarkerSet and PBT.ExportCurrentMarkerSet(slot)) or (PBT.ExportSavedMarkers and PBT.ExportSavedMarkers()) or ""
        pane.shareBox.edit:SetText(code); pane.shareBox.edit:TakeFocus()
        if pane.shareBox.edit.SelectAll then pane.shareBox.edit:SelectAll() end
    end, { 0.12, 0.30, 0.55, 1 }, MC.text):SetAnchor(TOPLEFT, pc, TOPLEFT, 0, 156)
    FlatButton(pc, "IMPORTER", 118, 30, function()
        local txt = pane.shareBox.edit:GetText()
        if PBT.ImportCurrentMarkerSet then PBT.ImportCurrentMarkerSet(txt) elseif PBT.ImportSavedMarkers then PBT.ImportSavedMarkers(txt) end
        editIndex = nil; selectedIndex = nil; UI:RefreshManagerWindow()
    end, { 0.12, 0.40, 0.20, 1 }, MC.text):SetAnchor(TOPLEFT, pc, TOPLEFT, 126, 156)
    FlatButton(pc, "SAUVER PACK", 118, 30, function()
        editIndex = nil
        if PBT.SaveCurrentMarkerSet then
            local _, msg = PBT.SaveCurrentMarkerSet()
            if msg then d("|c88ff88TSM:|r " .. (PBT.LocalizeChatMessage and PBT.LocalizeChatMessage(msg) or tostring(msg))) end
        end
        UI:RefreshManagerWindow()
    end, { 0.12, 0.40, 0.20, 1 }, MC.text):SetAnchor(TOPLEFT, pc, TOPLEFT, 252, 156)
    local delPackBtn
    local delPackPending = false
    local function ResetDelPackBtn()
        delPackPending = false
        if delPackBtn then
            delPackBtn.label:SetText(S("button_delete_pack"))
            delPackBtn.bg:SetCenterColor(unpack4(delPackBtn.baseColor))
        end
    end
    pane.ResetDelPackBtn = ResetDelPackBtn
    delPackBtn = FlatButton(pc, "SUPPR. PACK", 118, 30, function()
        if not delPackPending then
            -- premiere pression: demande de confirmation pendant 3 s
            delPackPending = true
            delPackBtn.label:SetText(S("button_confirm"))
            delPackBtn.bg:SetCenterColor(0.55, 0.10, 0.10, 1)
            zo_callLater(function() if delPackPending then ResetDelPackBtn() end end, 3000)
            return
        end
        ResetDelPackBtn()
        editIndex = nil; selectedIndex = nil
        if PBT.DeleteCurrentMarkerSet then
            local _, msg = PBT.DeleteCurrentMarkerSet()
            if msg then d("|cff8888TSM:|r " .. (PBT.LocalizeChatMessage and PBT.LocalizeChatMessage(msg) or tostring(msg))) end
        end
        UI:RefreshManagerWindow()
    end, { 0.30, 0.12, 0.12, 1 }, MC.text)
    delPackBtn:SetAnchor(TOPLEFT, pc, TOPLEFT, 378, 156)
    FlatButton(pc, "ENVOYER AU GROUPE", 496, 28, function()
        if PBT.GroupShare and PBT.GroupShare.SendCurrentSelection then
            PBT.GroupShare:SendCurrentSelection()
        elseif d then
            local message = "partage indisponible : LibGroupBroadcast 91 ou superieur est requis."
            d("|c66ccffTSM:|r " .. (PBT.LocalizeChatMessage and PBT.LocalizeChatMessage(message) or message))
        end
    end, { 0.16, 0.28, 0.48, 1 }, MC.text):SetAnchor(TOPLEFT, pc, TOPLEFT, 0, 194)
end

function UI:EnsureGroupShareDialog()
    if self.groupShareDialog then return end

    local dialog = WM:CreateTopLevelWindow("TeamShadowsManagerGroupShareDialog")
    dialog:SetDimensions(620, 310)
    dialog:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dialog:SetClampedToScreen(true)
    dialog:SetMouseEnabled(true)
    dialog:SetMovable(true)
    dialog:SetDrawTier(DT_HIGH)
    dialog:SetDrawLayer(DL_OVERLAY)
    dialog:SetHidden(true)

    dialog.bg = Backdrop(dialog, { 0.015, 0.02, 0.03, 0.98 }, MC.cyan)
    dialog.bg:SetAnchorFill(dialog)
    dialog.title = MLabel(dialog, "ZoFontWinH2", MC.cyan, "CONFIGURATION RECUE", TEXT_ALIGN_CENTER)
    dialog.title:SetAnchor(TOPLEFT, dialog, TOPLEFT, 20, 18)
    dialog.title:SetDimensions(580, 34)

    dialog.sender = MLabel(dialog, MF_LABEL, MC.text, "", TEXT_ALIGN_CENTER)
    dialog.sender:SetAnchor(TOPLEFT, dialog, TOPLEFT, 24, 62)
    dialog.sender:SetDimensions(572, 28)
    dialog.kind = MLabel(dialog, MF_LABEL, MC.text, "", TEXT_ALIGN_CENTER)
    dialog.kind:SetAnchor(TOPLEFT, dialog, TOPLEFT, 24, 94)
    dialog.kind:SetDimensions(572, 28)
    dialog.destination = MLabel(dialog, MF_SMALL, MC.textDim, "", TEXT_ALIGN_CENTER)
    dialog.destination:SetAnchor(TOPLEFT, dialog, TOPLEFT, 24, 130)
    dialog.destination:SetDimensions(572, 46)
    dialog.warning = MLabel(dialog, MF_SMALL, { 1, 0.35, 0.28, 1 }, "", TEXT_ALIGN_CENTER)
    dialog.warning:SetAnchor(TOPLEFT, dialog, TOPLEFT, 24, 174)
    dialog.warning:SetDimensions(572, 36)

    dialog.saveButton = FlatButton(dialog, "ACCEPTER ET ENREGISTRER", 190, 42, function()
        UI:ResolveGroupMarkerShare("save")
    end, { 0.10, 0.38, 0.20, 1 }, MC.text)
    dialog.saveButton:SetAnchor(BOTTOMLEFT, dialog, BOTTOMLEFT, 14, -18)
    dialog.saveButton.label:SetFont(MF_SMALL); dialog.saveButton.label:SetDimensions(186, 40)
    dialog.sessionButton = FlatButton(dialog, "JUSQU'A DECONNEXION", 190, 42, function()
        UI:ResolveGroupMarkerShare("session")
    end, { 0.12, 0.30, 0.55, 1 }, MC.text)
    dialog.sessionButton:SetAnchor(LEFT, dialog.saveButton, RIGHT, 10, 0)
    dialog.sessionButton.label:SetFont(MF_SMALL); dialog.sessionButton.label:SetDimensions(186, 40)
    dialog.refuseButton = FlatButton(dialog, "REFUSER", 190, 42, function()
        UI:ResolveGroupMarkerShare("refuse")
    end, { 0.38, 0.10, 0.10, 1 }, MC.text)
    dialog.refuseButton:SetAnchor(LEFT, dialog.sessionButton, RIGHT, 10, 0)
    dialog.refuseButton.label:SetFont(MF_SMALL); dialog.refuseButton.label:SetDimensions(186, 40)

    self.groupShareDialog = dialog
end

function UI:ReceiveGroupMarkerShare(share)
    if type(share) ~= "table" then return end
    self.pendingGroupMarkerShares = self.pendingGroupMarkerShares or {}
    self.pendingGroupMarkerShares[#self.pendingGroupMarkerShares + 1] = share
    self:ShowNextGroupMarkerShare()
end

function UI:ShowNextGroupMarkerShare()
    self:EnsureGroupShareDialog()
    if self.currentGroupMarkerShare or not self.pendingGroupMarkerShares or #self.pendingGroupMarkerShares == 0 then return end

    local share = table.remove(self.pendingGroupMarkerShares, 1)
    -- [FIX] "cond and f()" ne renvoie qu'UNE valeur en Lua : replaces/alreadyStored
    -- restaient toujours nil et le dialogue n'affichait jamais l'etat "remplace/deja stocke"
    local slot, replaces, alreadyStored
    if PBT.GetGroupMarkerShareDestination then
        slot, replaces, alreadyStored = PBT.GetGroupMarkerShareDestination(share.directoryKey, share.code)
    end
    if not slot then return self:ShowNextGroupMarkerShare() end

    share.destinationSlot = slot
    share.requiresReplacement = replaces == true
    share.alreadyStored = alreadyStored == true
    self.currentGroupMarkerShare = share
    self:RefreshGroupShareDialog()
    self.groupShareDialog:SetHidden(false)
end

function UI:RefreshGroupShareDialog()
    local share = self.currentGroupMarkerShare
    if not share or not self.groupShareDialog then return end
    local slot = tonumber(share.destinationSlot) or 1
    local replaces = share.requiresReplacement == true
    local alreadyStored = share.alreadyStored == true
    local directoryName = PBT.GetMarkerDirectoryNameForKey and PBT.GetMarkerDirectoryNameForKey(share.directoryKey) or tostring(share.directoryKey)
    local sender = tostring(share.sender or (PBT.GetLanguage and PBT.GetLanguage() == "en" and "Unknown player" or "Joueur inconnu"))
    self.groupShareDialog.sender:SetText(S("sent_by", sender))
    self.groupShareDialog.kind:SetText(tostring(L(share.typeName or S("share_type"))) .. " - " .. tostring(share.packName or S("pack")))
    self.groupShareDialog.destination:SetText(S("destination", directoryName, slot))
    if alreadyStored then
        self.groupShareDialog.warning:SetText(S("already_saved_warning"))
        self.groupShareDialog.saveButton.label:SetText(S("button_accept_present"))
    elseif replaces then
        self.groupShareDialog.warning:SetText(S("replacement_warning"))
        self.groupShareDialog.saveButton.label:SetText(S("button_accept_replace"))
    else
        self.groupShareDialog.warning:SetText(S("waiting_choice"))
        self.groupShareDialog.saveButton.label:SetText(S("button_accept_save"))
    end
end

function UI:ResolveGroupMarkerShare(choice)
    local share = self.currentGroupMarkerShare
    if not share then return end

    if choice == "save" or choice == "session" then
        local ok, message = PBT.AcceptGroupMarkerShare(share, choice == "save", share.requiresReplacement)
        if d then
            local color = ok and "|c88ff88" or "|cff8888"
            local output = tostring(message or (ok and "partage accepte" or "partage refuse"))
            d(color .. "TSM:|r " .. (PBT.LocalizeChatMessage and PBT.LocalizeChatMessage(output) or output))
        end
        if not ok then return end
    elseif d then
        local output = "partage refuse."
        d("|c66ccffTSM:|r " .. (PBT.LocalizeChatMessage and PBT.LocalizeChatMessage(output) or output))
    end

    self.groupShareDialog:SetHidden(true)
    self.currentGroupMarkerShare = nil
    self:RefreshManagerWindow()
    zo_callLater(function() UI:ShowNextGroupMarkerShare() end, 50)
end

-- ---------------- onglet DECOMPTE & ANNONCE ----------------
local function BuildPullTab(pane)
    pane.widgets = {}
    local function track(w) table.insert(pane.widgets, w); return w end
    local function toggleRow(parent, label, x, y, getF, setF)
        local t = track(MakeToggle(parent, getF, setF)); t:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
        MLabel(parent, MF_SMALL, MC.text, label):SetAnchor(LEFT, t, RIGHT, 8, 0)
    end
    local function sliderRow(parent, label, x, y, w, minV, maxV, step, key, suffix)
        MLabel(parent, MF_SMALL, MC.textDim, label):SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
        track(MakeSlider(parent, w, minV, maxV, step, function() return tonumber(SV()[key]) or minV end,
            function(v) SV()[key] = v end, suffix)):SetAnchor(TOPLEFT, parent, TOPLEFT, x, y + 18)
    end

    local pull = MakeCard(pane, "DÉCOMPTE GROUPE")
    pull:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 0); pull:SetDimensions(470, 250)
    local p = pull.content
    toggleRow(p, "Décompte activé", 0, 4, function() return SV().groupCountdownEnabled ~= false end, function(v) SV().groupCountdownEnabled = v end)
    toggleRow(p, "Diffuser au groupe", 240, 4, function() return SV().groupCountdownBroadcast ~= false end, function(v) SV().groupCountdownBroadcast = v end)
    sliderRow(p, "Durée du décompte", 0, 40, 200, 0, 20, 1, "groupCountdownSeconds", "s")
    sliderRow(p, "Mon délai (local)", 240, 40, 200, -10, 10, 0.1, "groupCountdownDpsDelay", "s")
    track(FlatButton(p, "LANCER LE DÉCOMPTE", 220, 34, function()
        if PBT.StartGroupCountdownFromKeybind then PBT.StartGroupCountdownFromKeybind() end
    end, { 0.12, 0.40, 0.20, 1 }, MC.text)):SetAnchor(TOPLEFT, p, TOPLEFT, 0, 96)
    track(FlatButton(p, "TEST 3s", 130, 34, function()
        if PBT.StartNamedCountdown then PBT.StartNamedCountdown("TEST", 3, "uiTest") end
    end)):SetAnchor(TOPLEFT, p, TOPLEFT, 232, 96)
    MLabel(p, MF_SMALL, MC.textDim, "Le décompte est commun au groupe. \"Mon délai\" ne change que ton écran."):SetAnchor(TOPLEFT, p, TOPLEFT, 0, 142)

    local ann = MakeCard(pane, "ANNONCE VISUELLE")
    ann:SetAnchor(TOPLEFT, pull, TOPRIGHT, 16, 0); ann:SetDimensions(470, 250)
    local a = ann.content
    MLabel(a, MF_SMALL, MC.textDim, "Couleur décompte"):SetAnchor(TOPLEFT, a, TOPLEFT, 0, 4)
    track(MakeSwatch(a, function() return SV().color end, function(r, g, b) if PBT.SetColor then PBT.SetColor(r, g, b) end end)):SetAnchor(TOPLEFT, a, TOPLEFT, 0, 22)
    MLabel(a, MF_SMALL, MC.textDim, "Couleur GO"):SetAnchor(TOPLEFT, a, TOPLEFT, 120, 4)
    track(MakeSwatch(a, function() return SV().goColor end, function(r, g, b, al) SV().goColor = { r = r, g = g, b = b, a = al or 1 }; UI:ApplySettings() end)):SetAnchor(TOPLEFT, a, TOPLEFT, 120, 22)
    MLabel(a, MF_SMALL, MC.textDim, "Sons"):SetAnchor(TOPLEFT, a, TOPLEFT, 240, 4)
    track(MakeToggle(a, function() return SV().soundEnabled ~= false end, function(v) SV().soundEnabled = v end)):SetAnchor(TOPLEFT, a, TOPLEFT, 240, 22)
    MLabel(a, MF_SMALL, MC.textDim, "Échelle de l'annonce"):SetAnchor(TOPLEFT, a, TOPLEFT, 0, 64)
    track(MakeSlider(a, 430, 0.5, 2.5, 0.05, function() return tonumber(SV().scale) or 1 end,
        function(v) if PBT.SetScale then PBT.SetScale(v) end end, "x")):SetAnchor(TOPLEFT, a, TOPLEFT, 0, 82)
    toggleRow(a, "Déverrouiller (déplacer)", 0, 120, function() return SV().unlocked == true end,
        function(v) if UI.SetUnlocked then UI:SetUnlocked(v) else SV().unlocked = v; UI:ApplySettings() end end)
    toggleRow(a, "Logo à l'écran", 240, 120, function() return SV().menuButtonEnabled ~= false end,
        function(v) SV().menuButtonEnabled = v; UI:ApplyMenuButtonSettings() end)
    MLabel(a, MF_SMALL, MC.textDim, "Taille du logo"):SetAnchor(TOPLEFT, a, TOPLEFT, 0, 152)
    track(MakeSlider(a, 430, 28, 96, 2, function() return tonumber(SV().menuButtonSize) or 46 end,
        function(v) SV().menuButtonSize = v; UI:ApplyMenuButtonSettings() end)):SetAnchor(TOPLEFT, a, TOPLEFT, 0, 170)
end

-- ---------------- onglet TIMERS ----------------
local function BuildTimersTab(pane)
    pane.widgets = {}
    local function track(w) table.insert(pane.widgets, w); return w end
    local boss = MakeCard(pane, "TIMERS BOSS")
    pane.bossCard = boss
    boss:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 0); boss:SetDimensions(470, 410)
    local b = boss.content
    local t = track(MakeToggle(b, function() return SV().bossSpawnTimers ~= false end,
        function(v) SV().bossSpawnTimers = v; SV().useSamuraiTimers = v; UI:RefreshForm() end)); t:SetAnchor(TOPLEFT, b, TOPLEFT, 0, 4)
    MLabel(b, MF_SMALL, MC.text, "Timers boss automatiques"):SetAnchor(LEFT, t, RIGHT, 8, 0)
    pane.instanceLbl = MLabel(b, MF_LABEL, MC.cyan, "Instance non reconnue"); pane.instanceLbl:SetAnchor(TOPLEFT, b, TOPLEFT, 0, 44); pane.instanceLbl:SetWidth(430)
    pane.instanceToggle = track(MakeToggle(b,
        function()
            return pane.currentTimerZone and PBT.IsInstanceTimerEnabled and PBT.IsInstanceTimerEnabled(pane.currentTimerZone) or false
        end,
        function(v)
            if pane.currentTimerZone and PBT.SetInstanceTimerEnabled then PBT.SetInstanceTimerEnabled(pane.currentTimerZone, v) end
        end))
    pane.instanceToggle:SetAnchor(TOPLEFT, b, TOPLEFT, 0, 72)
    pane.instanceToggleLbl = MLabel(b, MF_SMALL, MC.text, "Timers de cette instance")
    pane.instanceToggleLbl:SetAnchor(LEFT, pane.instanceToggle, RIGHT, 8, 0)
    pane.bossHeading = MLabel(b, MF_SMALL, MC.gold, "Boss pris en compte")
    pane.bossHeading:SetAnchor(TOPLEFT, b, TOPLEFT, 0, 110)
    pane.bossTimerRows = {}
    for i = 1, 4 do
        local row = WM:CreateControl(nil, b, CT_CONTROL)
        row:SetDimensions(430, 28); row:SetAnchor(TOPLEFT, b, TOPLEFT, 0, 132 + (i - 1) * 34)
        row.data = nil
        row.toggle = track(MakeToggle(row,
            function()
                return row.data and PBT.IsBossTimerEnabled and PBT.IsBossTimerEnabled(row.data.zoneKey, row.data.key) or false
            end,
            function(v)
                if row.data and PBT.SetBossTimerEnabled then PBT.SetBossTimerEnabled(row.data.zoneKey, row.data.key, v) end
            end))
        row.toggle:SetAnchor(LEFT, row, LEFT, 0, 0)
        row.label = MLabel(row, MF_SMALL, MC.text, "")
        row.label:SetAnchor(LEFT, row.toggle, RIGHT, 8, 0); row.label:SetWidth(365)
        pane.bossTimerRows[i] = row
    end
    pane.timerHelp = MLabel(b, MF_SMALL, MC.textDim, "")
    pane.timerHelp:SetAnchor(TOPLEFT, b, TOPLEFT, 0, 276); pane.timerHelp:SetWidth(430)
    track(FlatButton(b, "OUVRIR LES RÉGLAGES ESO (détails)", 300, 32, function() if PBT.OpenSettings then PBT.OpenSettings() end end)):SetAnchor(TOPLEFT, b, TOPLEFT, 0, 316)

    local dummy = MakeCard(pane, "MANNEQUIN")
    pane.dummyCard = dummy
    dummy:SetAnchor(TOPLEFT, boss, TOPRIGHT, 16, 0); dummy:SetDimensions(470, 230)
    local d = dummy.content
    MLabel(d, MF_SMALL, MC.textDim, "Durée du timer mannequin"):SetAnchor(TOPLEFT, d, TOPLEFT, 0, 4)
    track(MakeSlider(d, 430, 1, 60, 1, function() return tonumber(SV().practiceSeconds) or 10 end, function(v) SV().practiceSeconds = v end, "s")):SetAnchor(TOPLEFT, d, TOPLEFT, 0, 22)
    local at = track(MakeToggle(d, function() return SV().autoPracticeOnDummyReset ~= false end, function(v) SV().autoPracticeOnDummyReset = v end)); at:SetAnchor(TOPLEFT, d, TOPLEFT, 0, 64)
    MLabel(d, MF_SMALL, MC.text, "Auto-timer après reset mannequin"):SetAnchor(LEFT, at, RIGHT, 8, 0)

    local raid = MakeCard(pane, "OPTIONS ROCHEBOSQUE")
    pane.raidCard = raid
    raid:SetAnchor(TOPLEFT, dummy, BOTTOMLEFT, 0, 16); raid:SetDimensions(470, 194)
    local r = raid.content
    local function raidToggle(y, label, key, onChanged)
        local toggle = track(MakeToggle(r,
            function() return SV()[key] ~= false end,
            function(v)
                SV()[key] = v
                if onChanged then onChanged(v) end
                UI:RefreshForm()
            end))
        toggle:SetAnchor(TOPLEFT, r, TOPLEFT, 0, y)
        MLabel(r, MF_SMALL, MC.text, label):SetAnchor(LEFT, toggle, RIGHT, 8, 0)
        return toggle
    end
    raidToggle(0, "Options du raid activées", "bahseiRaidOptions", function(v)
        if not v and PBT.BahseiPortal then
            PBT.BahseiPortal:RemoveWallArrows()
            PBT.BahseiPortal:ResetPortalState()
        end
    end)
    raidToggle(30, "Flèches murales du portail", "bahseiWallArrows", function(v)
        if not v and PBT.BahseiPortal then PBT.BahseiPortal:RemoveWallArrows() end
    end)
    raidToggle(60, "Compteur partagé des fantômes", "bahseiGhostCounter", function(v)
        if not v and PBT.BahseiPortal then PBT.BahseiPortal:HideGhostCounter() end
    end)
    raidToggle(90, "Appel automatique des renforts", "bahseiGhostCall")
    raidToggle(120, "Recevoir le compteur et l'appel", "bahseiGhostReceive", function(v)
        if not v and PBT.BahseiPortal and not PBT.BahseiPortal.insidePortal then
            PBT.BahseiPortal:HideGhostCounter()
        end
    end)
end

-- ---------------- refresh ----------------
function UI:RefreshForm()
    local pane = self.managerPanes and self.managerPanes.markers
    if not pane then return end
    if pane.widgets then for _, w in ipairs(pane.widgets) do if w.Redraw then w.Redraw() end end end
    local texId, label, col = GetTexId(), GetCurLabel(), GetColor()
    if pane.packCard and pane.packCard.title then
        local zoneName = PBT.GetMarkerDirectoryName and PBT.GetMarkerDirectoryName() or ""
        pane.packCard.title:SetText(S("panel_packs_share_zone", zoneName))
    end
    if pane.previewTex then pane.previewTex:SetTexture(MarkerTexture(texId)) end
    if pane.previewLbl then
        local list = SV().groupBeaconSavedMarkers or {}
        local preview = (label == "auto") and tostring((#list % 10) + 1) or label
        pane.previewLbl:SetText(TextureHasNativeText(texId) and "" or preview)
        local r, gg, bl = col.r or col[1] or 1, col.g or col[2] or 1, col.b or col[3] or 1
        local lum = r * 0.299 + gg * 0.587 + bl * 0.114
        pane.previewLbl:SetColor(lum > 0.5 and 0 or 1, lum > 0.5 and 0 or 1, lum > 0.5 and 0 or 1, 1)
    end
    if pane.labelBtn then pane.labelBtn.label:SetText(S("text_value", label == "auto" and "Auto 1-10" or label)) end
    if pane.editBanner then pane.editBanner:SetText(editIndex and S("edit_number", editIndex) or S("default_values")) end
    if pane.iconCells then
        for _, cell in ipairs(pane.iconCells) do
            local ch = cell.choice
            cell.tex:SetTexture(MarkerTexture(ch.id))
            cell.lbl:SetText(QuickIconDisplayName(ch))
            local preview = ch.label or ""
            cell.previewLbl:SetText(TextureHasNativeText(ch.id) and "" or tostring(preview))
            local iconColor = ICON_COLORS[ch.id] or ICON_COLORS[1]
            local luminance = iconColor.r * 0.299 + iconColor.g * 0.587 + iconColor.b * 0.114
            cell.previewLbl:SetColor(luminance > 0.5 and 0 or 1, luminance > 0.5 and 0 or 1, luminance > 0.5 and 0 or 1, 1)
            local sel = (ch.id == texId) and ((ch.label == nil and (label == "auto")) or ch.label == label)
            cell.selected = sel
            cell.bg:SetEdgeColor(unpack4(sel and MC.cyan or MC.cardEdge))
            cell.bg:SetCenterColor(sel and 0.05 or 0.04, sel and 0.13 or 0.05, sel and 0.19 or 0.07, 1)
        end
    end
    local tp = self.managerPanes and self.managerPanes.timers
    if tp and tp.instanceLbl then
        local isHouse = GetCurrentZoneHouseId and (tonumber(GetCurrentZoneHouseId()) or 0) > 0
        local currentTrial = PBT.GetCurrentTrialKey and PBT.GetCurrentTrialKey() or nil
        local isRockgrove = currentTrial == "rockgrove"
        if tp.bossCard then tp.bossCard:SetHidden(isHouse or not currentTrial) end
        if tp.dummyCard then
            tp.dummyCard:ClearAnchors()
            tp.dummyCard:SetAnchor(TOPLEFT, tp, TOPLEFT, 0, 0)
            tp.dummyCard:SetHidden(not isHouse)
        end
        if tp.raidCard then
            tp.raidCard:ClearAnchors()
            if tp.bossCard then
                tp.raidCard:SetAnchor(TOPLEFT, tp.bossCard, TOPRIGHT, 16, 0)
            else
                tp.raidCard:SetAnchor(TOPLEFT, tp, TOPLEFT, 0, 0)
            end
            tp.raidCard:SetHidden(not isRockgrove)
        end
        if tp.widgets then for _, w in ipairs(tp.widgets) do if w.Redraw then w.Redraw() end end end
        local raids = PBT.GetNativeRaidTimersForCurrentInstance and PBT.GetNativeRaidTimersForCurrentInstance() or {}
        local raid = raids[1]
        if raid then
            local instanceName = PBT.GetLocalizedZoneName and PBT.GetLocalizedZoneName(raid.zoneKey, raid.name) or raid.name or "Instance"
            tp.currentTimerZone = raid.zoneKey
            tp.instanceLbl:SetText(instanceName)
            tp.instanceToggle:SetHidden(false); tp.instanceToggleLbl:SetHidden(false)
            if tp.instanceToggle.Redraw then tp.instanceToggle.Redraw() end
            local definitions = PBT.GetTimerBossDefinitions and PBT.GetTimerBossDefinitions(raid.zoneKey) or {}
            tp.bossHeading:SetHidden(#definitions == 0)
            local language = PBT.GetLanguage and PBT.GetLanguage() or "fr"
            for i, row in ipairs(tp.bossTimerRows or {}) do
                local data = definitions[i]
                row.data = data and { zoneKey = raid.zoneKey, key = data.key } or nil
                row:SetHidden(not data)
                if data then
                    row.label:SetText(data[language] or data.fr or data.en or data.key)
                    if row.toggle.Redraw then row.toggle.Redraw() end
                end
            end
            if raid.zoneKey == "rockgrove" then
                tp.timerHelp:SetText(S("bahsei_menu_instruction")); tp.timerHelp:SetHidden(false)
            elseif #definitions == 0 then
                tp.timerHelp:SetText(S("no_automatic_boss")); tp.timerHelp:SetHidden(false)
            else
                tp.timerHelp:SetText(""); tp.timerHelp:SetHidden(true)
            end
        else
            tp.currentTimerZone = nil
            tp.instanceLbl:SetText(S("unknown_instance"))
            tp.instanceToggle:SetHidden(true); tp.instanceToggleLbl:SetHidden(true); tp.bossHeading:SetHidden(true)
            for _, row in ipairs(tp.bossTimerRows or {}) do row.data = nil; row:SetHidden(true) end
            tp.timerHelp:SetText(S("no_boss_timer")); tp.timerHelp:SetHidden(false)
        end
    end
end

function UI:RefreshMarkerDistances()
    local pane = self.managerPanes and self.managerPanes.markers
    if not pane or not pane.rows or not GetUnitRawWorldPosition then return end
    local playerZone, playerX, _, playerZ = GetUnitRawWorldPosition("player")
    playerZone, playerX, playerZ = tonumber(playerZone), tonumber(playerX), tonumber(playerZ)
    for _, row in ipairs(pane.rows) do
        local marker = row.marker
        local distanceText = "—"
        if marker and playerZone and playerX and playerZ and tonumber(marker.zone) == playerZone then
            local markerX, markerZ = tonumber(marker.x), tonumber(marker.z)
            if markerX and markerZ then
                local dx, dz = markerX - playerX, markerZ - playerZ
                local meters = math.sqrt((dx * dx) + (dz * dz)) / 100
                distanceText = meters < 100 and string.format("%.1f m", meters) or string.format("%.0f m", meters)
            end
        end
        if row.distance then row.distance:SetText(distanceText) end
    end
end

function UI:RefreshList()
    local pane = self.managerPanes and self.managerPanes.markers
    if not pane or not pane.rows then return end
    local list = SV().groupBeaconSavedMarkers or {}
    local total = #list
    -- valider les index courants
    if editIndex and not list[editIndex] then editIndex = nil end
    if selectedIndex and not list[selectedIndex] then selectedIndex = nil end
    local maxPage = math.max(1, math.ceil(total / MARKER_ROWS))
    markerPage = mclamp(markerPage, 1, maxPage)
    local start = (markerPage - 1) * MARKER_ROWS
    if pane.listInfo then pane.listInfo:SetText(S("marker_count", total, total > 1 and "s" or "", markerPage, maxPage)) end
    if pane.prevBtn then pane.prevBtn.label:SetColor(unpack4(markerPage > 1 and MC.text or MC.textDim)) end
    if pane.nextBtn then pane.nextBtn.label:SetColor(unpack4(markerPage < maxPage and MC.text or MC.textDim)) end
    if pane.editBtn then pane.editBtn.label:SetColor(unpack4(selectedIndex and MC.text or MC.textDim)) end
    if pane.doneBtn then pane.doneBtn.label:SetColor(unpack4(editIndex and MC.text or MC.textDim)) end
    if pane.delBtn then pane.delBtn.label:SetColor(unpack4(selectedIndex and MC.text or MC.textDim)) end
    for i, row in ipairs(pane.rows) do
        local idx = start + i
        local m = list[idx]
        if m then
            row:SetHidden(false)
            row.marker = m
            row.badge:SetTexture(MarkerTexture(m.textureId or 1))
            local mark = (idx == editIndex) and S("edit_prefix") or ((idx == selectedIndex) and "> " or "")
            row.txt:SetText(mark .. SavedMarkerIconName(m))
            if idx == editIndex then
                row.bg:SetEdgeColor(unpack4(MC.gold)); row.bg:SetCenterColor(0.12, 0.09, 0.02, 1)
            elseif idx == selectedIndex then
                row.bg:SetEdgeColor(unpack4(MC.cyan)); row.bg:SetCenterColor(0.05, 0.11, 0.16, 1)
            else
                row.bg:SetEdgeColor(unpack4(MC.cardEdge)); row.bg:SetCenterColor(0.04, 0.05, 0.07, 1)
            end
        else
            row.marker = nil
            row:SetHidden(true)
        end
    end
    self:RefreshMarkerDistances()
    if pane.packCells then
        local active = mclamp(SV().groupBeaconMarkerSetSlot, 1, 3)
        for slot, cell in ipairs(pane.packCells) do
            local info = PBT.GetCurrentMarkerSetInfo and PBT.GetCurrentMarkerSetInfo(slot)
            local count = info and info.markers and #info.markers or 0
            local nm = PBT.GetMarkerPackName and PBT.GetMarkerPackName(slot) or ("Pack " .. slot)
            cell.label:SetText(nm .. (count > 0 and (" (" .. count .. ")") or ""))
            cell.baseColor = (slot == active) and { 0.05, 0.13, 0.19, 1 } or MC.card
            cell.bg:SetCenterColor(unpack4(cell.baseColor))
            cell.bg:SetEdgeColor(unpack4(slot == active and MC.cyan or MC.cardEdge))
        end
    end
end

function UI:SetTab(id)
    activeManagerTab = id
    for _, t in ipairs(self.managerTabs or {}) do
        local on = (t.id == id)
        t.bg:SetCenterColor(on and 0.04 or 0.02, on and 0.10 or 0.03, on and 0.14 or 0.05, 1)
        t.bg:SetEdgeColor(unpack4(on and MC.cyan or MC.cardEdge))
        t.label:SetColor(unpack4(on and MC.cyan or MC.gold))
    end
    for name, pane in pairs(self.managerPanes or {}) do pane:SetHidden(name ~= id) end
    self:RefreshForm(); self:RefreshList()
end

function UI:RefreshLanguageButtons()
    local language = PBT.GetLanguage and PBT.GetLanguage() or "fr"
    for code, button in pairs(self.languageButtons or {}) do
        local selected = code == language
        button.bg:SetCenterColor(selected and 0.04 or 0.02, selected and 0.10 or 0.03, selected and 0.14 or 0.05, 1)
        button.bg:SetEdgeColor(unpack4(selected and MC.cyan or MC.cardEdge))
        button.label:SetColor(unpack4(selected and MC.cyan or MC.gold))
    end
end

function UI:RefreshPermanentIconButton()
    local button = self.permanentIconButton
    if not button then return end
    local visible = not PBT.savedVars or PBT.savedVars.menuButtonEnabled ~= false
    button.label:SetText(S(visible and "button_hide_icon" or "button_show_icon"))
    button.bg:SetEdgeColor(unpack4(visible and MC.cyan or MC.cardEdge))
    button.label:SetColor(unpack4(visible and MC.cyan or MC.gold))
end

function UI:ApplyLanguage()
    for _, entry in ipairs(self.localizedControls or {}) do
        if entry.control and entry.control.SetText then
            entry.control:SetText(L(entry.source))
        end
    end
    for _, control in ipairs({ self.bossLabel, self.timerLabel, self.portalLabel }) do
        if control and control.GetText and control.SetText then control:SetText(L(control:GetText())) end
    end
    self:RefreshLanguageButtons()
    self:RefreshPermanentIconButton()
    local markerPane = self.managerPanes and self.managerPanes.markers
    if markerPane and markerPane.ResetDelPackBtn then markerPane.ResetDelPackBtn() end
    self:RefreshForm()
    self:RefreshList()
    self:RefreshGroupShareDialog()
end

-- ---------------- construction / affichage ----------------
local MANAGER_BASE_W, MANAGER_BASE_H = 1050, 744
local MANAGER_MIN_SCALE, MANAGER_MAX_SCALE = 0.6, 1.6

function UI:ApplyManagerScale(scale)
    scale = Clamp(tonumber(scale) or 1, MANAGER_MIN_SCALE, MANAGER_MAX_SCALE)
    if PBT.savedVars then PBT.savedVars.managerScale = scale end
    if self.managerWindow then self.managerWindow:SetScale(scale) end
    return scale
end

function UI:CreateManagerWindow()
    if self.managerWindow then return self.managerWindow end
    local M = WM:CreateTopLevelWindow(MANAGER_WINDOW_NAME)
    M:SetDimensions(MANAGER_BASE_W, MANAGER_BASE_H); M:SetAnchor(CENTER, GuiRoot, CENTER, 0, -10)
    M:SetMovable(true); M:SetMouseEnabled(true); M:SetClampedToScreen(true); M:SetHidden(true); M:SetDrawTier(DT_HIGH)
    -- [UI] fenêtre redimensionnable : tirer un bord/coin agrandit ou rétrécit.
    -- Le redimensionnement est converti en zoom uniforme (mise en page intacte)
    -- et mémorisé dans les SavedVariables.
    M.bg = Backdrop(M, MC.panel, MC.gold); M.bg:SetAnchorFill(M)
    M.innerBorder = Backdrop(M, { 0, 0, 0, 0 }, { 0.30, 0.24, 0.14, 1 })
    M.innerBorder:SetAnchor(TOPLEFT, M, TOPLEFT, 5, 5)
    M.innerBorder:SetAnchor(BOTTOMRIGHT, M, BOTTOMRIGHT, -5, -5)
    self.managerWindow = M

    M.titleBar = WM:CreateControl(nil, M, CT_CONTROL)
    M.titleBar:SetAnchor(TOPLEFT, M, TOPLEFT, 0, 0); M.titleBar:SetAnchor(TOPRIGHT, M, TOPRIGHT, 0, 0); M.titleBar:SetHeight(60); M.titleBar:SetMouseEnabled(true)
    M.titleBar:SetHandler("OnMouseDown", function() M:StartMoving() end)
    M.titleBar:SetHandler("OnMouseUp", function()
        M:StopMovingOrResizing()
        if PBT.savedVars then
            -- centre reel = dimensions de base x zoom (GetWidth renvoie les unites locales)
            local zs = M:GetScale() or 1
            PBT.savedVars.managerWindowX = M:GetLeft() + (MANAGER_BASE_W * zs / 2) - GuiRoot:GetWidth() / 2
            PBT.savedVars.managerWindowY = M:GetTop() + (MANAGER_BASE_H * zs / 2) - GuiRoot:GetHeight() / 2
        end
    end)
    M.headerLine = Backdrop(M, { MC.gold[1], MC.gold[2], MC.gold[3], 0.40 })
    M.headerLine:SetAnchor(TOPLEFT, M, TOPLEFT, 9, 59); M.headerLine:SetAnchor(TOPRIGHT, M, TOPRIGHT, -9, 59); M.headerLine:SetHeight(1)

    M.headerLogo = WM:CreateControl(nil, M, CT_TEXTURE)
    M.headerLogo:SetDimensions(180, 180); M.headerLogo:SetAnchor(TOPLEFT, M, TOPLEFT, -46, -48)
    M.headerLogo:SetTexture("TeamShadowsManager/TeamShadowsManagerHeaderLogo.dds")
    M.headerLogo:SetDrawLayer(DL_OVERLAY); M.headerLogo:SetDrawLevel(3)

    M.title = MLabel(M, MF_TITLE, MC.gold, "TEAM SHADOWS MANAGER", TEXT_ALIGN_CENTER)
    M.title:SetAnchor(TOPLEFT, M, TOPLEFT, 160, 12); M.title:SetAnchor(TOPRIGHT, M, TOPRIGHT, -260, 12)
    local author = MLabel(M, MF_SMALL, MC.textDim, "TeamFF - EyrOn", TEXT_ALIGN_CENTER)
    author:SetAnchor(TOPLEFT, M, TOPLEFT, 160, 39); author:SetAnchor(TOPRIGHT, M, TOPRIGHT, -490, 39)
    local contactTeam = MLabel(M, MF_SMALL, MC.cyan, "CONTACT : @TeamFF", TEXT_ALIGN_CENTER)
    contactTeam:SetAnchor(TOPLEFT, M, TOPLEFT, 570, 39); contactTeam:SetAnchor(TOPRIGHT, M, TOPRIGHT, -350, 39)
    contactTeam:SetMouseEnabled(true)
    contactTeam:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then OpenContactMail("@TeamFF") end end)
    contactTeam:SetHandler("OnMouseEnter", function(control)
        control:SetColor(unpack4(MC.gold))
        ZO_Tooltips_ShowTextTooltip(control, BOTTOM, "Ouvrir un courrier pour @TeamFF")
    end)
    contactTeam:SetHandler("OnMouseExit", function(control)
        control:SetColor(unpack4(MC.cyan))
        ZO_Tooltips_HideTextTooltip()
    end)
    local contactEyron = MLabel(M, MF_SMALL, MC.cyan, "@Eyr0n", TEXT_ALIGN_CENTER)
    contactEyron:SetAnchor(TOPLEFT, M, TOPLEFT, 705, 39); contactEyron:SetAnchor(TOPRIGHT, M, TOPRIGHT, -260, 39)
    contactEyron:SetMouseEnabled(true)
    contactEyron:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then OpenContactMail("@Eyr0n") end end)
    contactEyron:SetHandler("OnMouseEnter", function(control)
        control:SetColor(unpack4(MC.gold))
        ZO_Tooltips_ShowTextTooltip(control, BOTTOM, "Ouvrir un courrier pour @Eyr0n")
    end)
    contactEyron:SetHandler("OnMouseExit", function(control)
        control:SetColor(unpack4(MC.cyan))
        ZO_Tooltips_HideTextTooltip()
    end)
    local close = FlatButton(M, "X", 32, 32, function() self.managerWindow:SetHidden(true) end, MC.panel, MC.gold)
    close:SetAnchor(TOPRIGHT, M, TOPRIGHT, -18, 13)

    self.languageButtons = {}
    local frButton = FlatButton(M, "FR", 34, 28, function() if PBT.SetLanguage then PBT.SetLanguage("fr") end end, MC.panel, MC.gold)
    frButton:SetAnchor(TOPRIGHT, M, TOPRIGHT, -96, 15); self.languageButtons.fr = frButton
    local enButton = FlatButton(M, "EN", 34, 28, function() if PBT.SetLanguage then PBT.SetLanguage("en") end end, MC.panel, MC.gold)
    enButton:SetAnchor(TOPRIGHT, M, TOPRIGHT, -58, 15); self.languageButtons.en = enButton
    self.permanentIconButton = FlatButton(M, "", 112, 28, function()
        if not PBT.savedVars then return end
        PBT.savedVars.menuButtonEnabled = PBT.savedVars.menuButtonEnabled == false
        self:ApplyMenuButtonSettings()
    end, MC.panel, MC.gold)
    self.permanentIconButton:SetAnchor(TOPRIGHT, M, TOPRIGHT, -138, 15)
    self.permanentIconButton.label:SetFont(MF_SMALL); self.permanentIconButton.label:SetDimensions(108, 26)

    self.managerTabs = {}
    local tabW = 275
    for i, t in ipairs(MTABS) do
        local tab = WM:CreateControl(nil, M, CT_CONTROL)
        tab:SetDimensions(tabW, 40); tab:SetAnchor(TOPLEFT, M, TOPLEFT, 185 + (i - 1) * (tabW + 8), 70); tab:SetMouseEnabled(true)
        tab.bg = Backdrop(tab, { 0.02, 0.03, 0.05, 1 }, MC.cardEdge); tab.bg:SetAnchorFill(tab)
        tab.label = MLabel(tab, MF_LABEL, MC.gold, t.label, TEXT_ALIGN_CENTER); tab.label:SetAnchor(CENTER, tab, CENTER, 0, 0)
        tab.id = t.id
        tab:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then self:SetTab(t.id) end end)
        self.managerTabs[i] = tab
    end

    self.managerPanes = {}
    self.managerContent = WM:CreateControl(nil, M, CT_CONTROL)
    self.managerContent:SetAnchor(TOPLEFT, M, TOPLEFT, 44, 124); self.managerContent:SetDimensions(962, 596)
    for _, t in ipairs(MTABS) do
        local pane = WM:CreateControl(nil, self.managerContent, CT_CONTROL)
        pane:SetAnchorFill(self.managerContent); pane:SetHidden(true)
        self.managerPanes[t.id] = pane
    end
    BuildMarkersTab(self.managerPanes.markers)
    BuildPullTab(self.managerPanes.pull)
    BuildTimersTab(self.managerPanes.timers)
    EVENT_MANAGER:RegisterForUpdate(MARKER_DISTANCE_UPDATE_NAME, 500, function()
        if self.managerWindow and not self.managerWindow:IsHidden() and activeManagerTab == "markers" then
            self:RefreshMarkerDistances()
        end
    end)
    -- [UI] BORDS ZOOMABLES : attraper le bord gauche, droit, bas ou un coin bas
    -- et tirer — comme un redimensionnement classique, converti en zoom uniforme.
    local zoomDragging = false
    local function StartZoomDrag(mode)
        if zoomDragging or not GetUIMousePosition then return end
        zoomDragging = true
        local left0, top0 = M:GetLeft() or 0, M:GetTop() or 0
        local right0 = left0 + MANAGER_BASE_W * (M:GetScale() or 1)
        M:ClearAnchors()
        M:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left0, top0)
        EVENT_MANAGER:RegisterForUpdate("TeamShadowsManagerZoomDrag", 15, function()
            local mx, my = GetUIMousePosition()
            local s
            if mode == "left" then
                s = (right0 - mx) / MANAGER_BASE_W
            elseif mode == "right" then
                s = (mx - left0) / MANAGER_BASE_W
            elseif mode == "bottom" then
                s = (my - top0) / MANAGER_BASE_H
            elseif mode == "bottomleft" then
                s = math.max((right0 - mx) / MANAGER_BASE_W, (my - top0) / MANAGER_BASE_H)
            else -- bottomright
                s = math.max((mx - left0) / MANAGER_BASE_W, (my - top0) / MANAGER_BASE_H)
            end
            s = Clamp(s, MANAGER_MIN_SCALE, MANAGER_MAX_SCALE)
            M:SetScale(s)
            if mode == "left" or mode == "bottomleft" then
                M:ClearAnchors()
                M:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, right0 - MANAGER_BASE_W * s, top0)
            end
        end)
    end
    local function StopZoomDrag()
        if not zoomDragging then return end
        zoomDragging = false
        EVENT_MANAGER:UnregisterForUpdate("TeamShadowsManagerZoomDrag")
        local s = M:GetScale() or 1
        -- retour à l'ancrage CENTRE (convention de restauration de la fenêtre TSM)
        local cx = (M:GetLeft() or 0) + (MANAGER_BASE_W * s) / 2 - GuiRoot:GetWidth() / 2
        local cy = (M:GetTop() or 0) + (MANAGER_BASE_H * s) / 2 - GuiRoot:GetHeight() / 2
        M:ClearAnchors()
        M:SetAnchor(CENTER, GuiRoot, CENTER, cx, cy)
        UI:ApplyManagerScale(s)
        if PBT.savedVars then
            PBT.savedVars.managerWindowX = cx
            PBT.savedVars.managerWindowY = cy
        end
    end
    local function MakeZoomEdge(mode)
        local edge = WM:CreateControl(nil, M, CT_CONTROL)
        edge:SetMouseEnabled(true)
        edge.glow = WM:CreateControl(nil, edge, CT_TEXTURE)
        edge.glow:SetAnchorFill(edge)
        edge.glow:SetColor(0.96, 0.76, 0.13, 0)
        edge:SetHandler("OnMouseEnter", function(c)
            c.glow:SetColor(0.96, 0.76, 0.13, 0.30)
            ZO_Tooltips_ShowTextTooltip(c, TOP, "Tirer pour zoomer la fenêtre")
        end)
        edge:SetHandler("OnMouseExit", function(c)
            c.glow:SetColor(0.96, 0.76, 0.13, 0)
            ZO_Tooltips_HideTextTooltip()
        end)
        edge:SetHandler("OnMouseDown", function() ZO_Tooltips_HideTextTooltip(); StartZoomDrag(mode) end)
        edge:SetHandler("OnMouseUp", StopZoomDrag)
        return edge
    end
    local eL = MakeZoomEdge("left")
    eL:SetWidth(10); eL:SetAnchor(TOPLEFT, M, TOPLEFT, 0, 64); eL:SetAnchor(BOTTOMLEFT, M, BOTTOMLEFT, 0, -28)
    local eR = MakeZoomEdge("right")
    eR:SetWidth(10); eR:SetAnchor(TOPRIGHT, M, TOPRIGHT, 0, 64); eR:SetAnchor(BOTTOMRIGHT, M, BOTTOMRIGHT, 0, -28)
    local eB = MakeZoomEdge("bottom")
    eB:SetHeight(10); eB:SetAnchor(BOTTOMLEFT, M, BOTTOMLEFT, 28, 0); eB:SetAnchor(BOTTOMRIGHT, M, BOTTOMRIGHT, -28, 0)
    local eBL = MakeZoomEdge("bottomleft")
    eBL:SetDimensions(28, 28); eBL:SetAnchor(BOTTOMLEFT, M, BOTTOMLEFT, 0, 0)
    local eBR = MakeZoomEdge("bottomright")
    eBR:SetDimensions(28, 28); eBR:SetAnchor(BOTTOMRIGHT, M, BOTTOMRIGHT, 0, 0)
    for _, d in ipairs({ { -4, -4 }, { -11, -4 }, { -4, -11 }, { -18, -4 }, { -11, -11 }, { -4, -18 } }) do
        local px = WM:CreateControl(nil, eBR, CT_TEXTURE)
        px:SetDimensions(4, 4)
        px:SetAnchor(BOTTOMRIGHT, eBR, BOTTOMRIGHT, d[1], d[2])
        px:SetColor(0.96, 0.76, 0.13, 0.9)
    end

    self:RefreshLanguageButtons()
    self:RefreshPermanentIconButton()
    return M
end

function UI:ShowManagerWindow()
    if not self.managerWindow then self:CreateManagerWindow() end
    if PBT.SelectMarkerDirectoryForCurrentZone then
        local _, changed = PBT.SelectMarkerDirectoryForCurrentZone()
        if changed then markerPage, editIndex, selectedIndex = 1, nil, nil end
    end
    local saved = PBT.savedVars or {}
    self.managerWindow:ClearAnchors()
    self.managerWindow:SetAnchor(CENTER, GuiRoot, CENTER, saved.managerWindowX or 0, saved.managerWindowY or -10)
    self:ApplyManagerScale(saved.managerScale or 1)
    self.managerWindow:SetHidden(false)
    self:SetTab(activeManagerTab)
    self:ApplyLanguage()
end

function UI:ToggleManagerWindow()
    if self.managerWindow and not self.managerWindow:IsHidden() then
        self.managerWindow:SetHidden(true)
    else
        self:ShowManagerWindow()
    end
end

function UI:RefreshManagerWindow()
    if not self.managerWindow then return end
    self:RefreshForm(); self:RefreshList()
end
