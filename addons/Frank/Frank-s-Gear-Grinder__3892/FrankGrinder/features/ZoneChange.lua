------------------------------------------------------------
-- Zone Change Tracker -> ElmsMarkers injection (icon 38)
-- + Distance Tracker UI (merged; auto-start on enable)
------------------------------------------------------------

local ZONE_TRACK_ICON = 38

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function MarkersEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

------------------------------------------------------------
-- Distance Tracker (merged from MeasureDistance.lua)
------------------------------------------------------------
FrankGrinder.DistanceTracker = FrankGrinder.DistanceTracker or {}
local dist = FrankGrinder.DistanceTracker

-- Use unique update name to avoid collisions with other addons
dist.updateName = dist.updateName or "FrankGrinderDistanceTrackerUpdate"
dist.windowName = dist.windowName or "FrankGrinderDistanceTrackerWindow"

dist.startZoneId = dist.startZoneId or nil
dist.startX = dist.startX or nil
dist.startY = dist.startY or nil
dist.startZ = dist.startZ or nil

local function PositionDistanceWindow()
    if not dist.window or not GuiRoot then return end
    local w = GuiRoot:GetWidth()
    local h = GuiRoot:GetHeight()

    -- Centre of top-right quadrant:
    -- x = 75% of width, y = 25% of height (offset from TOPLEFT)
    dist.window:ClearAnchors()
    dist.window:SetAnchor(CENTER, GuiRoot, TOPLEFT, w * 0.75, h * 0.25)
end

local function ResetDistanceStart()
    local zoneId, x, y, z = GetUnitRawWorldPosition("player")
    dist.startZoneId = zoneId
    dist.startX = x
    dist.startY = y
    dist.startZ = z

    if dist.label then
        dist.label:SetText("Distance: 0.0")
    end

    if dist.headingLabel then
        local heading = GetPlayerCameraHeading()
        dist.headingLabel:SetText(string.format("Heading: %.4f", heading))
    end

    if dist.posLabel then
        dist.posLabel:SetText(string.format("Pos: %.0f, %.0f, %.0f", x, y, z))
    end
end

local function DistanceOnUpdate()
    if not dist.startX then return end

    local zoneId, x, y, z = GetUnitRawWorldPosition("player")
    local dx = x - dist.startX
    local dy = y - dist.startY
    local dz = z - dist.startZ

    -- Your original code divides by 100; retained as-is
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz) / 100

    if dist.label then
        dist.label:SetText(string.format("Distance: %.1f", distance))
    end

    local heading = GetPlayerCameraHeading()
    if dist.headingLabel then
        dist.headingLabel:SetText(string.format("Heading: %.4f", heading))
    end

    if dist.posLabel then
        dist.posLabel:SetText(string.format("Pos: %.0f, %.0f, %.0f", x, y, z))
    end
end

local function CreateDistanceUIIfNeeded()
    if dist.window then return end

    local wm = WINDOW_MANAGER
    local win = wm:CreateTopLevelWindow(dist.windowName)
    win:SetDimensions(260, 170)
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetHidden(true)

    -- Place at top-right quadrant centre (also re-positioned each show)
    PositionDistanceWindow()

    -- Background
    local bg = wm:CreateControl(nil, win, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0, 0, 0, 0.6)
    bg:SetEdgeColor(1, 1, 1, 0.8)

    -- Close Button (acts as "disable zone tracker" in merged design)
    local close = wm:CreateControl(nil, win, CT_BUTTON)
    close:SetDimensions(24, 24)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, 6)
    close:SetText("X")
    close:SetHandler("OnClicked", function()
        -- Keep UI + tracker in sync: closing disables zone-change tracking
        if FrankGrinder and FrankGrinder.SetZoneChangeEnabled then
            FrankGrinder:SetZoneChangeEnabled(false)
        else
            win:SetHidden(true)
            EVENT_MANAGER:UnregisterForUpdate(dist.updateName)
        end
    end)

    win:SetHandler("OnHide", function()
        EVENT_MANAGER:UnregisterForUpdate(dist.updateName)
    end)

    -- Distance Label
    local label = wm:CreateControl(nil, win, CT_LABEL)
    label:SetAnchor(TOP, win, TOP, 0, 35)
    label:SetFont("ZoFontGameLarge")
    label:SetText("Distance: --")

    -- Heading Label
    local headingLabel = wm:CreateControl(nil, win, CT_LABEL)
    headingLabel:SetAnchor(TOP, win, TOP, 0, 70)
    headingLabel:SetFont("ZoFontGameLarge")
    headingLabel:SetText("Heading: --")

    -- Position Label
    local posLabel = wm:CreateControl(nil, win, CT_LABEL)
    posLabel:SetAnchor(TOP, win, TOP, 0, 105)
    posLabel:SetFont("ZoFontGameLarge")
    posLabel:SetText("Pos: --, --, --")

    dist.window = win
    dist.label = label
    dist.headingLabel = headingLabel
    dist.posLabel = posLabel
end

function FrankGrinder:StartDistanceTracker()
    CreateDistanceUIIfNeeded()
    if not dist.window then return end

    -- Reposition every time it opens (covers resolution/UI scale changes)
    PositionDistanceWindow()

    -- Auto-start measuring (equivalent to old "Set Start")
    ResetDistanceStart()

    dist.window:SetHidden(false)
    EVENT_MANAGER:RegisterForUpdate(dist.updateName, 100, DistanceOnUpdate)
end

function FrankGrinder:StopDistanceTracker()
    EVENT_MANAGER:UnregisterForUpdate(dist.updateName)

    if dist.window then
        dist.window:SetHidden(true)
    end

    -- Clear start so updates do nothing until restarted
    dist.startZoneId = nil
    dist.startX = nil
    dist.startY = nil
    dist.startZ = nil
end

------------------------------------------------------------
-- ElmsMarkers injection + removal (unchanged logic)
------------------------------------------------------------
-- The record of what we injected lives in SavedVars, not just in memory, so
-- that markers can still be cleaned up after a crash or an exit-to-desktop.
function FrankGrinder:GetZoneTrackMarkerRecord()
    if not self.SV then return {} end
    self.SV.elmsZoneTrackMarkers = self.SV.elmsZoneTrackMarkers or {}
    return self.SV.elmsZoneTrackMarkers
end

function FrankGrinder:AddZoneTrackMarkerToElms(zoneId, x, y, z)
    if not self:GetSettingEnableElmsInjection() then return end

    if not (ElmsMarkers and ElmsMarkers.savedVars and ElmsMarkers.savedVars.positions) then
        -- ElmsMarkers not installed/ready
        return
    end

    ElmsMarkers.savedVars.positions[zoneId] = ElmsMarkers.savedVars.positions[zoneId] or {}
    local marker = { x, y, z, ZONE_TRACK_ICON }
    table.insert(ElmsMarkers.savedVars.positions[zoneId], marker)

    local record = self:GetZoneTrackMarkerRecord()
    record[zoneId] = record[zoneId] or {}
    table.insert(record[zoneId], { x, y, z, ZONE_TRACK_ICON })

    ElmsMarkers.CheckActivation()
end

function FrankGrinder:RemoveZoneTrackMarkersFromElms()
    local record = self:GetZoneTrackMarkerRecord()

    if not (ElmsMarkers and ElmsMarkers.savedVars and ElmsMarkers.savedVars.positions) then
        -- Nothing to remove from; drop the record so it can't go stale
        for k in pairs(record) do record[k] = nil end
        return
    end

    for zoneId, injectedList in pairs(record) do
        local zoneList = ElmsMarkers.savedVars.positions[zoneId]
        if type(zoneList) == "table" and type(injectedList) == "table" then
            for _, marker in ipairs(injectedList) do
                for i = #zoneList, 1, -1 do
                    if MarkersEqual(zoneList[i], marker) then
                        table.remove(zoneList, i)
                    end
                end
            end

            if next(zoneList) == nil then
                ElmsMarkers.savedVars.positions[zoneId] = nil
            end
        end

        -- CheckActivation only clears icons for zones still present in
        -- positions, so a zone we just emptied would keep its icons drawn.
        -- Discard them here; CheckActivation re-places whatever remains.
        if ElmsMarkers.RemovePositionIcons then
            ElmsMarkers.RemovePositionIcons(zoneId)
        end
    end

    for k in pairs(record) do record[k] = nil end
    ElmsMarkers.CheckActivation()
end

------------------------------------------------------------
-- Event handler (unchanged)
------------------------------------------------------------
local MAX_LOCATION_HISTORY = 500

function FrankGrinder:ZoneChanger(eventCode, ...)
    local zoneId, x, y, z = GetUnitRawWorldPosition("player")

    self._locationHistory = self._locationHistory or {}
    self._locationHistory[#self._locationHistory + 1] = {
        zoneId = zoneId,
        x = x,
        y = y,
        z = z,
    }

    -- Subzone changes fire constantly while running around; keep this bounded
    while #self._locationHistory > MAX_LOCATION_HISTORY do
        table.remove(self._locationHistory, 1)
    end

    self:AddZoneTrackMarkerToElms(zoneId, x, y, z)
end

------------------------------------------------------------
-- Enable/Disable (refactored so UI stays in sync)
------------------------------------------------------------
function FrankGrinder:SetZoneChangeEnabled(enabled)
    enabled = (enabled == true)

    if self._isZoneChangeOn == enabled then
        return
    end

    self._isZoneChangeOn = enabled

    if not self._zoneChangeCallback then
        self._zoneChangeCallback = function(...) self:ZoneChanger(...) end
    end

    if self._isZoneChangeOn then
        EVENT_MANAGER:RegisterForEvent(
            self.name,
            EVENT_CURRENT_SUBZONE_LIST_CHANGED,
            self._zoneChangeCallback
        )

        self._locationHistory = self._locationHistory or {}

        -- Show + auto-start measuring
        self:StartDistanceTracker()

        self:ChatMsg(GetString(GG_LOCATION_ENABLED))
    else
        EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_CURRENT_SUBZONE_LIST_CHANGED)

        self:RemoveZoneTrackMarkersFromElms()
        self._locationHistory = {}

        -- Close measurement window when disabled
        self:StopDistanceTracker()

        self:ChatMsg(GetString(GG_LOCATION_DISABLED))
    end
end

function FrankGrinder:ToggleZoneChange()
    if FrankGrinder.A() then
        self:SetZoneChangeEnabled(not self._isZoneChangeOn)
    end
end
