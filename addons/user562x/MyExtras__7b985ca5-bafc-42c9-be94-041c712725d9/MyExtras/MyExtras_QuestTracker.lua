local ME = MyExtras
local QoL = ME.QualityOfLife
local QT = {}
ME.QuestTracker = QT

--------------------------------------------------
-- Config
--------------------------------------------------
local MOVE_SCENE  = "MyExtras_QuestTrackerMove"
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
}
QoL:AddDefaults(DEFAULTS)

QT.moving = false

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

local function ScaleTracker(control, scale)
    if not control then return end
    if scale ~= 1 then pcall(InheritScale, control) end
    if control.SetTransformNormalizedOriginPoint then pcall(control.SetTransformNormalizedOriginPoint, control, 1, 0) end
    if control.SetTransformScale then pcall(control.SetTransformScale, control, scale) end
end

local function CurrentScale()
    return zo_clamp(tonumber(SV().questTrackerScale) or DEFAULTS.questTrackerScale, SCALE_MIN, SCALE_MAX) / 100
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
    ScaleTracker(control, CurrentScale())
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
    outline:SetDimensions(width * scale + OUTLINE_PAD * 2, height * scale + OUTLINE_PAD * 2)
    outline:SetHidden(false)
end

--------------------------------------------------
-- Move
--------------------------------------------------
QT.mover = {}

function QT.mover:UpdateDirectionalInput(deltaS)
    local x, y = DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)
    if x ~= 0 or y ~= 0 then
        QT:SetPosition(QT.moveX + x * MOVE_SPEED * deltaS, QT.moveY - y * MOVE_SPEED * deltaS)
    end
    local _, scaleY = DIRECTIONAL_INPUT:GetXY(ZO_DI_RIGHT_STICK)
    if scaleY ~= 0 then
        QT:SetScale(QT.moveScale + scaleY * SCALE_SPEED * deltaS)
    end
end

QT.moveKeybinds = {
    alignment = KEYBIND_STRIP_ALIGN_CENTER,
    {
        name     = "Save",
        keybind  = "UI_SHORTCUT_PRIMARY",
        callback = function() QT:EndMove(true) end,
    },
    {
        name     = "Default",
        keybind  = "UI_SHORTCUT_TERTIARY",
        callback = function() QT:MoveToDefault() end,
    },
    {
        name     = "Cancel",
        keybind  = "UI_SHORTCUT_NEGATIVE",
        callback = function() QT:EndMove(false) end,
    },
}

function QT:SetPosition(x, y)
    local screenW, screenH = GuiRoot:GetDimensions()
    self.moveX = zo_clamp(x, -screenW + 50, 0)
    self.moveY = zo_clamp(y, 0, screenH - 50)
    local sv = SV()
    sv.questTrackerPosX = zo_floor(self.moveX + 0.5)
    sv.questTrackerPosY = zo_floor(self.moveY + 0.5)
    self:ApplyPin()
end

function QT:SetScale(value)
    self.moveScale = zo_clamp(value, SCALE_MIN, SCALE_MAX)
    local rounded = zo_floor(self.moveScale + 0.5)
    local sv = SV()
    if sv.questTrackerScale ~= rounded then
        sv.questTrackerScale = rounded
        self:Apply()
        if self.moving then self:ShowOutline(true) end
    end
end

function QT:MoveToDefault()
    self:SetScale(DEFAULTS.questTrackerScale)
    self:SetPosition(DEFAULTS.questTrackerPosX, DEFAULTS.questTrackerPosY)
end

function QT:GetMoveScene()
    if self.moveScene then return self.moveScene end
    local scene = ZO_Scene:New(MOVE_SCENE, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_NO_KEYBIND_BACKGROUND_WINDOW)
    ME:AddPlacementFragments(scene)
    for i = 1, #TRACKER_FRAGMENTS do
        local fragment = rawget(_G, TRACKER_FRAGMENTS[i])
        if fragment then scene:AddFragment(fragment) end
    end
    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            QT:OnMoveShowing()
        elseif newState == SCENE_HIDDEN then
            QT:OnMoveHidden()
        end
    end)
    self.moveScene = scene
    return scene
end

function QT:StartMove()
    if self.moving or not Manager() then return end
    self.moveSaved = false
    self.moving = true
    self:GetMoveScene()
    SCENE_MANAGER:Push(MOVE_SCENE)
end

function QT:OnMoveShowing()
    local sv = SV()
    self.moving = true
    self.moveStartX, self.moveStartY = sv.questTrackerPosX, sv.questTrackerPosY
    self.moveStartScale = sv.questTrackerScale
    self.moveX, self.moveY = sv.questTrackerPosX, sv.questTrackerPosY
    self.moveScale = sv.questTrackerScale
    self:Apply()
    self:ShowOutline(true)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.moveKeybinds)
    DIRECTIONAL_INPUT:Activate(self.mover, self:GetOutline())
    ME:SetPlacing(true)
end

function QT:OnMoveHidden()
    DIRECTIONAL_INPUT:Deactivate(self.mover)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.moveKeybinds)
    if not self.moveSaved then
        self:SetScale(self.moveStartScale)
        self:SetPosition(self.moveStartX, self.moveStartY)
    end
    self.moving = false
    self:ShowOutline(false)
    ME:SetPlacing(false)
    self:Apply()
end

function QT:EndMove(save)
    if not self.moving then return end
    self.moveSaved = save == true
    if save then
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    else
        PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
    end
    SCENE_MANAGER:HideCurrentScene()
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
                type       = "button",
                name       = "Move / Scale",
                buttonText = "Move / Scale",
                tooltip    = "Move it with the left stick and scale it with the right stick.",
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
