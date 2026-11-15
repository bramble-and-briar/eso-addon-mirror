--[[
    HUD view: icon + timer controls, the movable window and its saved position.
]]

local ADDON = "WeylandHuntsmansWarmaskTracker"
local HMK = _G[ADDON]
local T = HMK.T
local FONTS, OUTLINES = HMK.FONTS, HMK.OUTLINES
local ICON_U_LEFT, ICON_U_RIGHT = HMK.ICON_U_LEFT, HMK.ICON_U_RIGHT
local ICON_V_TOP, ICON_V_BOTTOM = HMK.ICON_V_TOP, HMK.ICON_V_BOTTOM
local ICONS, FindById = HMK.ICONS, HMK.FindById

local function IconPath(cfg)
    return FindById(ICONS, cfg.icon).path
end

-- Timer placement, shared by the HUD element and the settings preview.
--   inside : centred on the icon
--   edge   : centred horizontally, its vertical middle sits on the icon's bottom edge,
--            so the digits climb onto the icon by half of their height
local function AnchorTimer(timer, icon, cfg, scale)
    timer:ClearAnchors()
    local dy = (cfg.timerOffsetY or 0) * scale
    if cfg.timerMode == "edge" then
        timer:SetAnchor(CENTER, icon, BOTTOM, 0, dy)
    else
        timer:SetAnchor(CENTER, icon, CENTER, 0, dy)
    end
end

local function BuildFont(fontId, size, outlineId)
    local f = FindById(FONTS, fontId)
    local o = FindById(OUTLINES, outlineId)
    if o.value == "" then
        return string.format("%s|%d", f.path, size)
    end
    return string.format("%s|%d|%s", f.path, size, o.value)
end

-- One lightweight view implementation is shared by the HUD and the LAM preview.
local function CreateMarkView(parent)
    local icon = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    icon:SetAnchorFill(parent)
    icon:SetTextureCoords(ICON_U_LEFT, ICON_U_RIGHT, ICON_V_TOP, ICON_V_BOTTOM)

    local timer = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    return { icon = icon, timer = timer }
end

local function ApplyViewStyle(view, cfg, scale)
    scale = scale or 1
    view.icon:SetTexture(IconPath(cfg))
    view.icon:SetTextureCoords(ICON_U_LEFT, ICON_U_RIGHT, ICON_V_TOP, ICON_V_BOTTOM)
    view.timer:SetFont(BuildFont(cfg.font, math.max(8, zo_round(cfg.fontSize * scale)), cfg.outline))
    AnchorTimer(view.timer, view.icon, cfg, scale)
end

local function ApplyViewColors(view, cfg, warning)
    local iconColor = (warning and cfg.warnIcon) and cfg.warnColor or cfg.color
    local timerColor = (warning and cfg.warnTimer) and cfg.warnColor or cfg.timerColor
    view.icon:SetColor(iconColor.r, iconColor.g, iconColor.b, iconColor.a)
    view.timer:SetColor(timerColor.r, timerColor.g, timerColor.b, timerColor.a)
end

local ui = {}

local function ApplyPosition(win, cfg)
    win:ClearAnchors()
    win:SetAnchor(CENTER, GuiRoot, CENTER, cfg.x, cfg.y)
end

local function SavePosition(win, cfg)
    local left, top = win:GetLeft(), win:GetTop()
    local width, height = win:GetWidth(), win:GetHeight()
    if type(left) ~= "number" or type(top) ~= "number"
        or type(width) ~= "number" or type(height) ~= "number" then
        return false
    end
    local cx = left + width / 2
    local cy = top + height / 2
    cfg.x = zo_round(cx - GuiRoot:GetWidth() / 2)
    cfg.y = zo_round(cy - GuiRoot:GetHeight() / 2)
    cfg.positionValid = true
    ApplyPosition(win, cfg)   -- re-anchor to CENTER so saved values match
    return true
end

-- A container window that is registered with the HUD scenes (so it hides in menus).
-- Visibility of the real content is controlled by win.content, because the scene
-- fragment owns the visibility of the window itself.
local function CreateWindow(suffix, cfgGetter)
    local win = WINDOW_MANAGER:CreateTopLevelWindow(ADDON .. "_" .. suffix)
    win:SetClampedToScreen(true)
    win:SetDrawTier(DT_HIGH)
    win:SetMouseEnabled(false)
    win:SetMovable(false)

    local content = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    content:SetAnchorFill(win)
    content:SetHidden(true)
    win.content = content

    win:SetHandler("OnMoveStop", function(self)
        SavePosition(self, cfgGetter())
    end)

    local fragment = ZO_SimpleSceneFragment:New(win)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    win.fragment = fragment

    return win
end

local function CreateUI()
    -- Mark icon + timer
    local mark = CreateWindow("MarkWin", function() return HMK.sv.mark end)

    mark.view = CreateMarkView(mark.content)
    mark.icon = mark.view.icon
    mark.timer = mark.view.timer

    -- A gold outline is always shown in move mode, even if the icon itself is transparent.
    local frame = WINDOW_MANAGER:CreateControl(nil, mark.content, CT_CONTROL)
    frame:SetAnchorFill(mark.content)
    frame:SetMouseEnabled(false)
    frame:SetDrawLevel(20)
    frame:SetHidden(true)
    local top = WINDOW_MANAGER:CreateControl(nil, frame, CT_TEXTURE)
    top:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    top:SetAnchor(TOPRIGHT, frame, TOPRIGHT, 0, 0)
    top:SetHeight(2)
    top:SetColor(1, 0.78, 0.22, 1)
    local bottom = WINDOW_MANAGER:CreateControl(nil, frame, CT_TEXTURE)
    bottom:SetAnchor(BOTTOMLEFT, frame, BOTTOMLEFT, 0, 0)
    bottom:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    bottom:SetHeight(2)
    bottom:SetColor(1, 0.78, 0.22, 1)
    local left = WINDOW_MANAGER:CreateControl(nil, frame, CT_TEXTURE)
    left:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    left:SetAnchor(BOTTOMLEFT, frame, BOTTOMLEFT, 0, 0)
    left:SetWidth(2)
    left:SetColor(1, 0.78, 0.22, 1)
    local right = WINDOW_MANAGER:CreateControl(nil, frame, CT_TEXTURE)
    right:SetAnchor(TOPRIGHT, frame, TOPRIGHT, 0, 0)
    right:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    right:SetWidth(2)
    right:SetColor(1, 0.78, 0.22, 1)
    mark.frame = frame

    -- shown only in move mode, so you never have to remember the command
    local hint = WINDOW_MANAGER:CreateControl(nil, mark.content, CT_LABEL)
    hint:SetFont("ZoFontGameBold")
    hint:SetColor(1, 0.82, 0.3, 1)
    hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    hint:SetAnchor(BOTTOM, mark.content, TOP, 0, -6)
    hint:SetText(T("MOVE_HINT"))
    hint:SetHidden(true)
    mark.hint = hint
    ui.mark = mark

end

HMK.ui = ui
HMK.CreateMarkView = CreateMarkView
HMK.ApplyViewStyle = ApplyViewStyle
HMK.ApplyViewColors = ApplyViewColors
HMK.ApplyPosition = ApplyPosition
HMK.SavePosition = SavePosition
HMK.CreateUI = CreateUI
