local ME = MyExtras
local QoL = ME.QualityOfLife
local QT = {}
ME.QuestTracker = QT

--------------------------------------------------
-- Config
--------------------------------------------------
local MOVE_SPEED  = 500
local SCALE_SPEED = 40
local SCALE_MIN   = 50
local SCALE_MAX   = 150
local BOX_CORNER  = 16
local OUTLINE_PAD = 8

local TRACKER_FRAGMENTS = {
    "FOCUSED_QUEST_TRACKER_FRAGMENT",
    "ENDLESS_DUNGEON_HUD_TRACKER_FRAGMENT",
    "TIMED_ACTIVITY_TRACKER_FRAGMENT",
    "ACTIVITY_TRACKER_FRAGMENT",
    "READY_CHECK_TRACKER_FRAGMENT",
    "ZONE_STORY_TRACKER_FRAGMENT",
    "ACHIEVEMENT_TRACKER_FRAGMENT",
    "ADVENTURE_ZONE_HUD_TRACKER_FRAGMENT",
    "DYNAMIC_EVENTS_TRACKER_FRAGMENT",
    "HOUSE_INFORMATION_TRACKER_FRAGMENT",
    "GENERIC_SELECTOR_HUD_TRACKER_FRAGMENT",
}

local DEFAULTS = {
    questTrackerEnabled = false,
    questTrackerPosX    = -15,
    questTrackerPosY    = 90,
    questTrackerScale   = 100,
    questTrackerStretch = 100,
}
QoL:AddDefaults(DEFAULTS)

QT.moving = false
QT.preview = false

local applied  = false
local applying = false
local hooked   = false
local ready    = false

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return QoL:Settings()
end

local function Manager()
    local manager = rawget(_G, "HUD_TRACKER_MANAGER")
    if manager and manager.control then return manager end
    return nil
end

local function IsOn()
    return SV().questTrackerEnabled == true
end

local DEFAULT_X = -15
local DEFAULT_Y = 90

local function TrackerList(manager)
    if type(manager.trackers) == "table" then return manager.trackers end
    return {}
end

local function IsActive(owner)
    if not (owner and owner.IsActive) then return false end
    local ok, active = pcall(owner.IsActive, owner)
    return ok and active == true
end

local function StackAll(manager)
    local child = manager.scrollChild
    if not child then return end
    local previous
    for _, trackerData in ipairs(TrackerList(manager)) do
        local control = trackerData.control
        if control and IsActive(trackerData.owner) then
            control:SetParent(child)
            control:ClearAnchors()
            if previous then
                control:SetAnchor(TOPRIGHT, previous, BOTTOMRIGHT, 0, 0)
            else
                control:SetAnchor(TOPRIGHT, child, TOPRIGHT, -2, 10)
            end
            previous = control
        end
    end
end

local function InheritScale(control)
    if not control then return end
    if control.GetInheritsScale and not control:GetInheritsScale() then control:SetInheritScale(true) end
    local count = control.GetNumChildren and control:GetNumChildren() or 0
    for i = 1, count do
        InheritScale(control:GetChild(i))
    end
end

local function ScaleTracker(control, scale, stretch)
    if not control then return end
    stretch = stretch or 1
    if scale ~= 1 or stretch ~= 1 then pcall(InheritScale, control) end
    if control.SetTransformNormalizedOriginPoint then pcall(control.SetTransformNormalizedOriginPoint, control, 1, 0) end
    if control.SetTransformScale then pcall(control.SetTransformScale, control, scale) end
    if control.SetTransformScaleX then pcall(control.SetTransformScaleX, control, scale * stretch) end
end

local function CurrentScale()
    return zo_clamp(tonumber(SV().questTrackerScale) or DEFAULTS.questTrackerScale, SCALE_MIN, SCALE_MAX) / 100
end

local function CurrentStretch()
    return zo_clamp(tonumber(SV().questTrackerStretch) or 100, ME.STRETCH_MIN, ME.STRETCH_MAX) / 100
end

local function SplitKeys(manager)
    local keys = {}
    for _, trackerData in ipairs(TrackerList(manager)) do
        local owner = trackerData.owner
        if owner and owner.GetHUDElementOptionKeys then
            local ok, key = pcall(owner.GetHUDElementOptionKeys, owner)
            if ok and key then keys[#keys + 1] = key end
        end
    end
    return keys
end

local function ClearSplits(manager)
    if ZO_IsConsoleOrGameCoreUI and not ZO_IsConsoleOrGameCoreUI() then return end
    if not manager.GetHUDElement then return end
    local keys = SplitKeys(manager)
    for _, gamepad in ipairs({ true, false }) do
        local element = manager:GetHUDElement(gamepad)
        if element and element.GetCustomOptionValue and element.SetCustomOptionValue then
            for i = 1, #keys do
                local ok, split = pcall(element.GetCustomOptionValue, element, "SeparatedTrackers", keys[i])
                if ok and split == true then
                    pcall(element.SetCustomOptionValue, element, "SeparatedTrackers", keys[i], false)
                end
            end
        end
    end
end

local function ReleaseAll(manager)
    for _, trackerData in ipairs(TrackerList(manager)) do
        if trackerData.control then trackerData.control:ClearAnchors() end
    end
end

local function AccentColor()
    local sv = ME.savedVariables
    if sv and sv.settingsHighlight == "Custom" and type(sv.settingsHighlightColor) == "table" then
        local c = sv.settingsHighlightColor
        return c.r or 1, c.g or 1, c.b or 1
    end
    local c = GetAllianceColor(GetUnitAlliance("player"))
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

--------------------------------------------------
-- Position
--------------------------------------------------
function QT:GetPin()
    if self.pin then return self.pin end
    local pin = WINDOW_MANAGER:CreateTopLevelWindow("MyExtras_QuestTrackerPin")
    pin:SetDimensions(1, 1)
    pin:SetMouseEnabled(false)
    pin:SetHidden(false)
    self.pin = pin
    return pin
end

function QT:ApplyPin()
    local sv = SV()
    local pin = self:GetPin()
    pin:ClearAnchors()
    pin:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, sv.questTrackerPosX, sv.questTrackerPosY)
end

local function AnchoredToPin(control)
    if not (control and QT.pin) then return false end
    local _, _, relativeTo = control:GetAnchor(0)
    return relativeTo == QT.pin
end

local function PlaceAtHome(manager)
    local control = manager.control
    control:ClearAnchors()
    control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, DEFAULT_X, DEFAULT_Y)
end

function QT:TurnOn(manager)
    local control = manager.control
    self:ApplyPin()
    control:ClearAnchors()
    control:SetAnchor(TOPRIGHT, self:GetPin(), TOPRIGHT, 0, 0)
    local scroll = manager.scrollContainer
    if scroll then
        scroll:ClearAnchors()
        scroll:SetAnchor(TOPLEFT)
        scroll:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, 0, ANCHOR_CONSTRAINS_Y)
    end
    StackAll(manager)
    ScaleTracker(control, CurrentScale(), CurrentStretch())
end

function QT:TurnOff(manager)
    local control = manager.control
    ScaleTracker(control, 1)
    PlaceAtHome(manager)
    ReleaseAll(manager)
    manager.secondaryAnchorPoint = nil
    if manager.OnAnchorStateChanged then pcall(manager.OnAnchorStateChanged, manager) end
    if manager.RefreshLayout then pcall(manager.RefreshLayout, manager) end
    if AnchoredToPin(control) then PlaceAtHome(manager) end
end

function QT:Apply()
    if applying or not ready then return end
    local manager = Manager()
    if not manager then return end
    applying = true
    if IsOn() or self.moving then
        applied = true
        pcall(self.TurnOn, self, manager)
    elseif applied or AnchoredToPin(manager.control) then
        applied = false
        pcall(self.TurnOff, self, manager)
    end
    applying = false
end

local function Reapply()
    if applied or QT.moving then
        QT:Apply()
    elseif not applying then
        local manager = Manager()
        if manager and AnchoredToPin(manager.control) then PlaceAtHome(manager) end
    end
end

function QT:Hook()
    if hooked then return end
    local manager = Manager()
    if not manager then return end
    hooked = true
    if manager.OnAnchorStateChanged then SecurePostHook(manager, "OnAnchorStateChanged", Reapply) end
    if manager.RefreshLayout then SecurePostHook(manager, "RefreshLayout", Reapply) end
    if HUD_MANAGER and HUD_MANAGER.PropagateSettings then SecurePostHook(HUD_MANAGER, "PropagateSettings", Reapply) end
    if manager.GetHUDElement then
        for _, gamepad in ipairs({ true, false }) do
            local element = manager:GetHUDElement(gamepad)
            if element and element.RevertOffsetModifications then
                SecurePostHook(element, "RevertOffsetModifications", Reapply)
            end
        end
    end
end

--------------------------------------------------
-- Outline
--------------------------------------------------
function QT:GetOutline()
    if self.outline then return self.outline end
    local outline = WINDOW_MANAGER:CreateTopLevelWindow("MyExtras_QuestTrackerOutline")
    outline:SetDrawLayer(DL_BACKGROUND)
    outline:SetDrawTier(DT_LOW)
    outline:SetMouseEnabled(false)
    outline:SetHidden(true)
    local box = ME:CreateRoundBox("MyExtras_QuestTrackerOutlineBox", outline, 0)
    box.control:SetAnchorFill(outline)
    box:SetCorner(BOX_CORNER)
    box:SetFillColor(0, 0, 0, 0.35)
    local label = WINDOW_MANAGER:CreateControl(nil, outline, CT_LABEL)
    label:SetFont("ZoFontGamepad34")
    label:SetText("Quest Tracker")
    label:SetAnchor(TOP, outline, TOP, 0, 10)
    label:SetDrawLevel(5)
    self.outline = outline
    self.outlineBox = box
    self.outlineLabel = label
    return outline
end

function QT:ShowOutline(show)
    local outline = self:GetOutline()
    local manager = Manager()
    if not (show and manager) then
        outline:SetHidden(true)
        return
    end
    local r, g, b = AccentColor()
    self.outlineBox:SetEdgeColor(r, g, b, 1)
    self.outlineLabel:SetColor(r, g, b, 1)
    local scale = CurrentScale()
    local width, height = manager.control:GetDimensions()
    outline:ClearAnchors()
    outline:SetAnchor(TOPRIGHT, manager.control, TOPRIGHT, OUTLINE_PAD, -OUTLINE_PAD)
    outline:SetDimensions(width * scale * CurrentStretch() + OUTLINE_PAD * 2, height * scale + OUTLINE_PAD * 2)
    outline:SetHidden(false)
end

--------------------------------------------------
-- Move
--------------------------------------------------
function QT:StartMove()
    if self.moving or not Manager() then return end
    self.moving = true
    local started = LibUser562:StartMove({
        inputControl = self:GetOutline(),
        moveSpeed    = MOVE_SPEED,
        scaleSpeed   = SCALE_SPEED,
        sizeMin      = SCALE_MIN,
        sizeMax      = SCALE_MAX,
        bounds       = function()
            local screenW, screenH = GuiRoot:GetDimensions()
            return -screenW + 50, 0, 0, screenH - 50
        end,
        defaults     = {
            x    = DEFAULTS.questTrackerPosX,
            y    = DEFAULTS.questTrackerPosY,
            size = DEFAULTS.questTrackerScale,
        },
        getPosition = function() return SV().questTrackerPosX, SV().questTrackerPosY end,
        setPosition = function(x, y)
            local sv = SV()
            sv.questTrackerPosX, sv.questTrackerPosY = x, y
            QT:ApplyPin()
        end,
        getSize    = function() return SV().questTrackerScale end,
        setSize    = function(size)
            SV().questTrackerScale = size
            QT:Apply()
            if QT.moving then QT:ShowOutline(true) end
        end,
        getStretch = function() return SV().questTrackerStretch or 100 end,
        setStretch = function(percent)
            SV().questTrackerStretch = percent
            QT:Apply()
            if QT.moving then QT:ShowOutline(true) end
        end,
        onShow = function()
            QT:Apply()
            QT:ShowOutline(true)
            ME:SetPlacing(true)
        end,
        onHide = function()
            QT.moving = false
            QT:ShowOutline(false)
            ME:SetPlacing(false)
            QT:Apply()
        end,
    })
    if not started then self.moving = false end
end

--------------------------------------------------
-- Preview
--------------------------------------------------
function QT:SetPreview(value)
    value = value == true
    if self.preview == value then return end
    self.preview = value
    local scene = ME.settingsPanel and ME.settingsPanel.scene
    if scene then
        for i = 1, #TRACKER_FRAGMENTS do
            local fragment = rawget(_G, TRACKER_FRAGMENTS[i])
            if fragment then
                if value then scene:AddFragment(fragment) else scene:RemoveFragment(fragment) end
            end
        end
    end
    self:Apply()
    self:ShowOutline(value)
end

function QT:GetPreviewControls()
    local manager = Manager()
    if manager and manager.control then return { manager.control, self:GetOutline() } end
    return {}
end

function QT:OnSettingsState(newState)
    if newState == SCENE_HIDDEN and self.preview then self:SetPreview(false) end
end

--------------------------------------------------
-- Settings
--------------------------------------------------
function QT:SubmenuOption()
    return {
        type    = "submenu",
        name    = "Quest Tracker",
        tooltip = "Moves your quest tracker along with everything shown with it.",
        options = {
            {
                type    = "toggle",
                name    = "Enabled",
                preset  = "YES_NO",
                default = DEFAULTS.questTrackerEnabled,
                tooltip = "Moves your quest tracker along with everything shown with it, like Infinite Archive, "
                       .. "Golden Pursuits, Tamriel Tomes and your house info. Off puts it back where the game has it.",
                getFunc = function() return SV().questTrackerEnabled end,
                setFunc = function(val)
                    SV().questTrackerEnabled = val
                    QT:Apply()
                end,
            },
            {
                type    = "toggle",
                name    = "Preview",
                tooltip = "Shows your quest tracker here so you can see your changes. "
                       .. "Stays on until you turn it off or leave the settings.",
                getFunc = function() return QT.preview end,
                setFunc = function(val) QT:SetPreview(val) end,
            },
            {
                type       = "button",
                name       = "Move / Scale",
                buttonText = "Move / Scale",
                tooltip    = "Move it with the left stick. Right stick up and down scales it, left and right stretches it wider or narrower.",
                func       = function() QT:StartMove() end,
            },
        },
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function QT:Init()
end

function QT:OnPlayerActivated()
    ready = true
    if not self.splitsCleared then
        self.splitsCleared = true
        local manager = Manager()
        if manager then ClearSplits(manager) end
    end
    self:Hook()
    self:Apply()
end

function QT:OnReset()
    self:Apply()
end

ME:RegisterFeature(QT)
