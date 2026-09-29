if not GildedUI then return end

local Addon = GildedUI

-- Unused in apply (kept for existing saves).
local DEFAULT_POS_X = 1645
local DEFAULT_POS_Y = 0
local DEFAULT_SCALE = 1
local SCALE_MIN = 0.5
local SCALE_MAX = 1.5

-- Stock ZO_HUDTrackers (U51): TOPRIGHT to GuiRoot (-15, 90), height 350.
-- Scroll area normally stretches to GuiRoot bottom with this padding.
local ROOT_OFFSET_X = -15
local STOCK_POS_Y = 90
local STOCK_BOTTOM_PAD = 130
local TRACKER_CONTENT_INSET_X = (ZO_SCROLL_BAR_WIDTH or 16) + 2
local PREVIEW_OFFSET_X = ROOT_OFFSET_X - TRACKER_CONTENT_INSET_X
local ROOT_CONTROL_NAME = "ZO_HUDTrackers"
local GHOST_WIDTH = 280

Addon.limits = Addon.limits or {}
Addon.limits.trackerColumnScale = { min = SCALE_MIN, max = SCALE_MAX }

Addon:RegisterDefaults({
    trackerColumnEnabled = true,
    trackerColumnPosX = DEFAULT_POS_X,
    trackerColumnPosY = DEFAULT_POS_Y,
    trackerColumnScale = DEFAULT_SCALE,
})

function Addon:SanitizeTrackerColumn()
    local limits = self.limits
    self:SanitizeSavedBoolean("trackerColumnEnabled")
    self:ClampSavedNumber("trackerColumnPosX", limits.posX)
    self:ClampSavedNumber("trackerColumnPosY", limits.posY)
    self:ClampSavedNumber("trackerColumnScale", limits.trackerColumnScale)
end

local function GetTrackerColumnRoot()
    if HUD_TRACKER_MANAGER and HUD_TRACKER_MANAGER.control then
        return HUD_TRACKER_MANAGER.control
    end
    return _G[ROOT_CONTROL_NAME]
end

local function GetStockPanelHeight()
    return ZO_HUD_TRACKER_MANAGER_HEIGHT or 350
end

local function GetStockPanelWidth()
    return ZO_HUD_TRACKER_MANAGER_WIDTH or ((ZO_HUD_TRACKER_MAX_WIDTH or 350) + (ZO_SCROLL_BAR_WIDTH or 16) + 150)
end

-- How tall the tracker column can be on screen (stock fades near the bottom).
local function GetAvailableVisualHeight(posY)
    local guiHeight = GuiRoot and GuiRoot:GetHeight() or 1080
    local available = guiHeight - (posY or 0) - STOCK_BOTTOM_PAD
    return math.max(GetStockPanelHeight(), available)
end

local function ResetControlScale(control)
    if not control then return end
    control:SetScale(1)
    if control.SetTransformScale then
        control:SetTransformScale(1)
    end
    if control.ClearTransformOffset then
        control:ClearTransformOffset()
    end
    if control.ResetTransformNormalizedOriginPoint then
        control:ResetTransformNormalizedOriginPoint()
    end
end

local function IsTrackerColumnEnabled(sv)
    return sv and sv.trackerColumnEnabled == true
end

local function RestoreStockScrollContainerAnchors(manager)
    if not manager or not manager.OnAnchorStateChanged then return end
    manager.secondaryAnchorPoint = nil
    manager:OnAnchorStateChanged()
end

-- Keep scroll container filling the panel (no SetScale on it). SetScale + TOPLEFT pin
-- made the layout box stick past the panel's right edge, so right-aligned trackers
-- were clipped while empty panel margin showed as a gap.
local function ApplyScrollContainerFillParent(manager)
    local scrollContainer = manager and manager.scrollContainer
    if not scrollContainer then return end
    ResetControlScale(scrollContainer)
    scrollContainer:ClearAnchors()
    scrollContainer:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 0)
    scrollContainer:SetAnchor(BOTTOMRIGHT, nil, BOTTOMRIGHT, 0, 0)
end

-- Scale about TOPRIGHT so top/right stay put without needing control height
-- (GetHeight() is often stale right after a layout change).
local function ApplyRightPinnedTransformScale(control, scale)
    ResetControlScale(control)
    if scale == 1 or not control.SetTransformScale then
        return
    end

    if control.SetTransformNormalizedOriginPoint then
        control:SetTransformNormalizedOriginPoint(1, 0)
    end
    control:SetTransformScale(scale)
end

local function ApplyScrollChildTransformScale(manager, scale)
    local child = manager and manager.scrollChild
    if not child then return end

    if manager.scrollControl then
        ResetControlScale(manager.scrollControl)
    end

    ApplyRightPinnedTransformScale(child, scale)
end

local function GetColumnLayoutHeight(posY, scale)
    local visualHeight = GetAvailableVisualHeight(posY)
    -- When scaled down, grow the layout box so TransformScale still fills down
    -- to the stock bottom fade line.
    if scale < 1 then
        return visualHeight / scale
    end
    return visualHeight
end

function Addon:SetTrackerColumnEnabled(enabled)
    local sv = self.state.sv
    if not sv then return end
    sv.trackerColumnEnabled = enabled == true
    self:ApplyTrackerColumn()
end

function Addon:SetTrackerColumnMenuPreview(enabled)
    self.state.trackerColumnMenuPreview = enabled == true
    self:UpdateTrackerColumnPreview()
end

function Addon:ApplyTrackerColumnRootPosition()
    -- Applied in ApplyTrackerColumnLayout.
end

function Addon:ApplyTrackerColumnScale()
    -- Applied in ApplyTrackerColumnLayout.
end

function Addon:ApplyTrackerColumnLayout()
    local sv = self.state.sv
    local root = GetTrackerColumnRoot()
    if not sv or not root then return end

    ResetControlScale(root)

    if not IsTrackerColumnEnabled(sv) then
        root:SetDimensions(GetStockPanelWidth(), GetStockPanelHeight())
        root:ClearAnchors()
        root:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, ROOT_OFFSET_X, STOCK_POS_Y)
        if HUD_TRACKER_MANAGER then
            if HUD_TRACKER_MANAGER.scrollChild then
                ResetControlScale(HUD_TRACKER_MANAGER.scrollChild)
            end
            if HUD_TRACKER_MANAGER.scrollControl then
                ResetControlScale(HUD_TRACKER_MANAGER.scrollControl)
            end
            if HUD_TRACKER_MANAGER.scrollContainer then
                ResetControlScale(HUD_TRACKER_MANAGER.scrollContainer)
            end
        end
        RestoreStockScrollContainerAnchors(HUD_TRACKER_MANAGER)
        return
    end

    local scale = sv.trackerColumnScale or DEFAULT_SCALE
    if scale <= 0 then
        scale = DEFAULT_SCALE
    end
    local posY = sv.trackerColumnPosY or DEFAULT_POS_Y
    local layoutHeight = GetColumnLayoutHeight(posY, scale)
    local width = GetStockPanelWidth()

    root:SetResizeToFitDescendents(false)
    root:SetDimensions(width, layoutHeight)
    root:ClearAnchors()
    root:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, ROOT_OFFSET_X, posY)
    ApplyScrollContainerFillParent(HUD_TRACKER_MANAGER)
    ApplyScrollChildTransformScale(HUD_TRACKER_MANAGER, scale)
end

function Addon:ScheduleTrackerColumnApply()
    if self.state.trackerColumnApplyId then
        zo_removeCallLater(self.state.trackerColumnApplyId)
        self.state.trackerColumnApplyId = nil
    end
    self.state.trackerColumnApplyId = zo_callLater(function()
        self.state.trackerColumnApplyId = nil
        if not Addon.state.trackerColumnApplying then
            Addon:ApplyTrackerColumn()
        end
    end, 0)
end

function Addon:EnsureTrackerColumnGhosts()
    if self.state.trackerColumnGhostRoot then return end

    local wm = WINDOW_MANAGER
    local name = self.name .. "_TrackerColumnGhost"
    local root = wm:CreateTopLevelWindow(name)
    root:SetMouseEnabled(false)
    root:SetMovable(false)
    root:SetClampedToScreen(false)
    root:SetDrawLayer(DL_OVERLAY)
    root:SetDrawLevel(100)
    root:SetHidden(true)
    root:SetResizeToFitDescendents(false)

    local backdrop = wm:CreateControl(name .. "_BG", root, CT_BACKDROP)
    backdrop:SetAnchorFill(root)
    backdrop:SetCenterColor(0.12, 0.12, 0.14, 0.75)
    backdrop:SetEdgeColor(0.85, 0.75, 0.45, 0.9)
    backdrop:SetEdgeTexture("", 1, 1, 2)

    local label = wm:CreateControl(name .. "_Label", root, CT_LABEL)
    label:SetFont("ZoFontGamepad27")
    label:SetColor(0.95, 0.9, 0.7, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label:SetAnchor(TOPLEFT, root, TOPLEFT, 10, 10)
    label:SetAnchor(TOPRIGHT, root, TOPRIGHT, -10, 10)
    label:SetText("Tracker Column")

    self.state.trackerColumnGhostRoot = root
end

function Addon:UpdateTrackerColumnPreview()
    local sv = self.state.sv
    if not sv then return end

    self:EnsureTrackerColumnGhosts()
    local root = self.state.trackerColumnGhostRoot
    if not root then return end

    local visible = self.state.trackerColumnMenuPreview == true
        and IsTrackerColumnEnabled(sv)
    if not visible then
        ResetControlScale(root)
        root:SetHidden(true)
        return
    end

    local scale = sv.trackerColumnScale or DEFAULT_SCALE
    if scale <= 0 then
        scale = DEFAULT_SCALE
    end
    local posY = sv.trackerColumnPosY or DEFAULT_POS_Y
    local layoutHeight = GetColumnLayoutHeight(posY, scale)

    -- Match live: grow layout when scale < 1, then TransformScale from TOPRIGHT
    -- so the ghost still reaches the bottom fade line.
    ResetControlScale(root)
    root:SetDimensions(GHOST_WIDTH, layoutHeight)
    root:ClearAnchors()
    root:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, PREVIEW_OFFSET_X, posY)
    ApplyRightPinnedTransformScale(root, scale)
    root:SetHidden(false)
end

function Addon:ApplyTrackerColumn()
    if self.state.trackerColumnApplying then return end
    self.state.trackerColumnApplying = true

    local sv = self.state.sv
    if sv then
        self:ApplyTrackerColumnLayout()
        self:UpdateTrackerColumnPreview()
    end

    self.state.trackerColumnApplying = false
end

function Addon:ApplyTrackerColumnDefaults()
    self:ApplyTrackerColumn()
end

function Addon:InitTrackerColumn()
    self:ApplyTrackerColumn()

    if self.state.trackerColumnHooked then return end
    self.state.trackerColumnHooked = true

    if HUD_TRACKER_MANAGER and HUD_TRACKER_MANAGER.RefreshLayout then
        ZO_PostHook(HUD_TRACKER_MANAGER, "RefreshLayout", function()
            if Addon.state.trackerColumnApplying then return end
            Addon:ScheduleTrackerColumnApply()
        end)
    end

    if HUD_TRACKER_MANAGER and HUD_TRACKER_MANAGER.OnAnchorStateChanged then
        ZO_PostHook(HUD_TRACKER_MANAGER, "OnAnchorStateChanged", function()
            if Addon.state.trackerColumnApplying then return end
            if not IsTrackerColumnEnabled(Addon.state.sv) then return end
            ApplyScrollContainerFillParent(HUD_TRACKER_MANAGER)
            local sv = Addon.state.sv
            local scale = sv.trackerColumnScale or DEFAULT_SCALE
            ApplyScrollChildTransformScale(HUD_TRACKER_MANAGER, scale)
        end)
    end

    if HUD_MANAGER then
        HUD_MANAGER:RegisterCallback("PropagateSettings", function()
            if Addon.state.trackerColumnApplying then return end
            Addon:ScheduleTrackerColumnApply()
        end)
        HUD_MANAGER:RegisterCallback("OffsetsChanged", function()
            if Addon.state.trackerColumnApplying then return end
            Addon:ScheduleTrackerColumnApply()
        end)
    end

    EVENT_MANAGER:RegisterForEvent(self.name .. "_TrackerColumn", EVENT_PLAYER_ACTIVATED, function()
        Addon:ScheduleTrackerColumnApply()
    end)
end
