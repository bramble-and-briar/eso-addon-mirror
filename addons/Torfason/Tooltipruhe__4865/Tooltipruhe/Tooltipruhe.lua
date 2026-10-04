Tooltipruhe = Tooltipruhe or {}
local TR = Tooltipruhe
local L = TR.L or {}

TR.name = "Tooltipruhe"
TR.version = "2.0.0"
TR.savedVariableName = "TooltipruheSavedVariables"
TR.savedVariableVersion = 1
TR.tooltipsEnabled = false
TR.editMode = false
TR.markers = {}
TR.suppressed = {}
TR.tooltipKeys = {}

local FALLBACK_MARKER_WIDTH = 416
local MARKER_HEIGHT = 150
local POSITION_MARGIN = 20
local PRESET_GAP = 20
-- Die Markerbreite wird zur Laufzeit direkt vom jeweiligen ESO-Tooltip übernommen.
-- 416 dient nur als Sicherheitswert, falls ESO beim sehr frühen Initialisieren noch keine Breite liefert.

local defaults =
{
    permanentEnabled = false,
    chatMessages = true,
    usePositioning = true,
    positions =
    {
        item = { x = nil, y = nil, anchor = "TOPLEFT" },
        compare1 = { x = nil, y = nil, anchor = "TOPLEFT" },
        compare2 = { x = nil, y = nil, anchor = "TOPLEFT" },
    },
}

local markerData =
{
    item =
    {
        name = "TooltipruhePositionItem",
        titleKey = "MARKER_ITEM",
        hintKey = "MARKER_HINT",
    },
    compare1 =
    {
        name = "TooltipruhePositionCompare1",
        titleKey = "MARKER_COMPARE1",
        hintKey = "MARKER_HINT",
    },
    compare2 =
    {
        name = "TooltipruhePositionCompare2",
        titleKey = "MARKER_COMPARE2",
        hintKey = "MARKER_HINT",
    },
}

local presetOrder = { "item", "compare1", "compare2" }

local function Round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function TR:Message(text)
    if self.savedVariables and self.savedVariables.chatMessages == false then
        return
    end
    d(string.format("|c7FC7FFTooltipruhe|r: %s", text))
end

function TR:IsTrackedTooltip(control)
    return control ~= nil and self.tooltipKeys[control] ~= nil
end

local VALID_ANCHORS =
{
    TOPLEFT = true,
    TOPRIGHT = true,
    BOTTOMLEFT = true,
    BOTTOMRIGHT = true,
}

local ANCHOR_POINTS =
{
    TOPLEFT = TOPLEFT,
    TOPRIGHT = TOPRIGHT,
    BOTTOMLEFT = BOTTOMLEFT,
    BOTTOMRIGHT = BOTTOMRIGHT,
}

function TR:NormalizeAnchor(anchor)
    if VALID_ANCHORS[anchor] then
        return anchor
    end
    return "TOPLEFT"
end

function TR:GetTooltipControl(key)
    if key == "item" then
        return ItemTooltip
    elseif key == "compare1" then
        return ComparativeTooltip1
    elseif key == "compare2" then
        return ComparativeTooltip2
    end
    return nil
end

function TR:GetTooltipWidth(key)
    local control = self:GetTooltipControl(key)
    if control then
        local width = control:GetWidth()
        if width and width > 0 then
            return width
        end
    end

    local marker = self.markers and self.markers[key]
    if marker then
        local width = marker:GetWidth()
        if width and width > 0 then
            return width
        end
    end

    return FALLBACK_MARKER_WIDTH
end

function TR:RefreshMarkerDimensions()
    for key, marker in pairs(self.markers) do
        marker:SetDimensions(self:GetTooltipWidth(key), MARKER_HEIGHT)
    end
end

function TR:GetDefaultPosition(key)
    local rootWidth = GuiRoot:GetWidth()
    local rootHeight = GuiRoot:GetHeight()
    local y = math.max(POSITION_MARGIN, math.floor((rootHeight - MARKER_HEIGHT) * 0.28))
    local itemWidth = self:GetTooltipWidth("item")
    local compare1Width = self:GetTooltipWidth("compare1")
    local compare2Width = self:GetTooltipWidth("compare2")
    local rightMargin = 50

    local itemX = math.max(POSITION_MARGIN, rootWidth - itemWidth - rightMargin)
    local compare1X = math.max(POSITION_MARGIN, itemX - PRESET_GAP - compare1Width)
    local compare2X = math.max(POSITION_MARGIN, compare1X - PRESET_GAP - compare2Width)

    if key == "item" then
        return itemX, y, "TOPLEFT"
    elseif key == "compare1" then
        return compare1X, y, "TOPLEFT"
    else
        return compare2X, y, "TOPLEFT"
    end
end

function TR:EnsurePosition(key)
    local position = self.savedVariables.positions[key]
    if position.x == nil or position.y == nil then
        position.x, position.y, position.anchor = self:GetDefaultPosition(key)
    end
    position.anchor = self:NormalizeAnchor(position.anchor)
end

function TR:GetPositionTopLeft(key)
    self:EnsurePosition(key)

    local position = self.savedVariables.positions[key]
    local rootWidth = GuiRoot:GetWidth()
    local rootHeight = GuiRoot:GetHeight()
    local x = position.x
    local y = position.y
    local markerWidth = self:GetTooltipWidth(key)

    if position.anchor == "TOPRIGHT" then
        x = rootWidth + position.x - markerWidth
    elseif position.anchor == "BOTTOMLEFT" then
        y = rootHeight + position.y - MARKER_HEIGHT
    elseif position.anchor == "BOTTOMRIGHT" then
        x = rootWidth + position.x - markerWidth
        y = rootHeight + position.y - MARKER_HEIGHT
    end

    return x, y
end

function TR:SetPositionFromTopLeft(key, left, top, anchor)
    self:EnsurePosition(key)

    local position = self.savedVariables.positions[key]
    local rootWidth = GuiRoot:GetWidth()
    local rootHeight = GuiRoot:GetHeight()
    local markerWidth = self:GetTooltipWidth(key)
    local maxX = math.max(0, rootWidth - markerWidth)
    local maxY = math.max(0, rootHeight - MARKER_HEIGHT)

    left = zo_clamp(left, 0, maxX)
    top = zo_clamp(top, 0, maxY)

    anchor = self:NormalizeAnchor(anchor or position.anchor)
    position.anchor = anchor

    if anchor == "TOPLEFT" then
        position.x = Round(left)
        position.y = Round(top)
    elseif anchor == "TOPRIGHT" then
        position.x = Round((left + markerWidth) - rootWidth)
        position.y = Round(top)
    elseif anchor == "BOTTOMLEFT" then
        position.x = Round(left)
        position.y = Round((top + MARKER_HEIGHT) - rootHeight)
    else -- BOTTOMRIGHT
        position.x = Round((left + markerWidth) - rootWidth)
        position.y = Round((top + MARKER_HEIGHT) - rootHeight)
    end
end

function TR:ClampPosition(key)
    local left, top = self:GetPositionTopLeft(key)
    self:SetPositionFromTopLeft(key, left, top)
end

function TR:ApplyPosition(control)
    if not self.savedVariables or self.savedVariables.usePositioning == false then
        return
    end

    local key = self.tooltipKeys[control]
    if not key or not self.savedVariables then
        return
    end

    self:EnsurePosition(key)
    local position = self.savedVariables.positions[key]
    local point = ANCHOR_POINTS[position.anchor] or TOPLEFT

    -- Wichtig: Den Tooltip-Owner NICHT verändern. ESO benutzt den Owner der
    -- Vergleichs-Tooltips intern weiter (z. B. beim Waffenwechsel). Wir ersetzen
    -- ausschließlich die sichtbaren Anker und lassen die interne Besitzstruktur intakt.
    control:ClearAnchors()
    control:SetAnchor(point, GuiRoot, point, position.x, position.y)
end

function TR:EnforceVisibleTooltipPosition(control)
    if not self:IsTrackedTooltip(control) or control:IsHidden() then
        return
    end

    -- ESO ordnet ComparativeTooltip1/2 teils NACH dem eigentlichen Aufbau erneut
    -- neben dem Haupttooltip an. Deshalb setzen wir den gespeicherten Bildschirmanker
    -- im sichtbaren Zustand fortlaufend zurück. Bei nur drei Controls ist das sehr klein
    -- und vermeidet ein zeitabhängiges Wettrennen mit der Standard-UI.
    self:ApplyPosition(control)

    if not self.tooltipsEnabled or self.editMode then
        self.suppressed[control] = true
        control:SetHidden(true)
    end
end

function TR:ApplyAllPositions()
    for control in pairs(self.tooltipKeys) do
        self:ApplyPosition(control)
    end
end

function TR:SuppressTooltip(control)
    if not control or control:IsHidden() then
        return
    end

    self.suppressed[control] = true
    control:SetHidden(true)
end

function TR:HideTrackedTooltips()
    for control in pairs(self.tooltipKeys) do
        self:SuppressTooltip(control)
    end
end

function TR:RestoreSuppressedTooltips()
    for control, wasSuppressed in pairs(self.suppressed) do
        if wasSuppressed and self:IsTrackedTooltip(control) then
            self:ApplyPosition(control)
            control:SetHidden(false)
        end
        self.suppressed[control] = nil
    end
end

function TR:HandleTooltipShown(control)
    if not self:IsTrackedTooltip(control) then
        return
    end

    self:ApplyPosition(control)

    if not self.tooltipsEnabled or self.editMode then
        self.suppressed[control] = true
        control:SetHidden(true)
    end
end

function TR:QueueTooltipPosition(control)
    if not self:IsTrackedTooltip(control) then
        return
    end

    local function ApplyQueuedPosition()
        if not self:IsTrackedTooltip(control) then
            return
        end

        self:ApplyPosition(control)
        if not self.tooltipsEnabled or self.editMode then
            if not control:IsHidden() then
                self.suppressed[control] = true
                control:SetHidden(true)
            end
        end
    end

    -- Einmal direkt nach dem aktuellen UI-Durchlauf und noch einmal kurz danach.
    -- Einige ESO-Fenster richten Vergleichs-Tooltips erst nach dem Haupttooltip aus.
    zo_callLater(ApplyQueuedPosition, 0)
    zo_callLater(ApplyQueuedPosition, 25)
end

function TR:QueueAllTooltipPositions()
    for control in pairs(self.tooltipKeys) do
        self:QueueTooltipPosition(control)
    end
end

function TR:SetTooltipsEnabled(enabled, announce, restoreCurrent)
    self.tooltipsEnabled = enabled == true

    if self.tooltipsEnabled then
        if restoreCurrent and not self.editMode then
            self:RestoreSuppressedTooltips()
        else
            -- Im normalen ESO-Verhalten wird kein altes/statisches Tooltip-Fenster erzwungen.
            -- Der nächste reguläre Hover lässt ESO den Tooltip selbst wieder anzeigen.
            ZO_ClearTable(self.suppressed)
        end
        if announce then
            self:Message(L.MSG_SHOWN)
        end
    else
        self:HideTrackedTooltips()
        if announce then
            self:Message(L.MSG_HIDDEN)
        end
    end
end

function TR:ToggleVisibility()
    -- Die Taste darf einen aktuell unterdrückten Hover sofort wieder einblenden.
    self:SetTooltipsEnabled(not self.tooltipsEnabled, true, true)
end

function TR:SetPermanentEnabled(enabled)
    -- 'An' bedeutet normales ESO-Verhalten: Tooltip nur anzeigen, solange ESO ihn anzeigen will.
    self.savedVariables.permanentEnabled = enabled == true
    self:SetTooltipsEnabled(self.savedVariables.permanentEnabled, false, false)
end

function TR:SetUsePositioning(enabled)
    enabled = enabled == true
    if self.savedVariables.usePositioning == enabled then
        return
    end

    if not enabled and self.editMode then
        self:SetEditMode(false, true)
    end

    self.savedVariables.usePositioning = enabled
    if enabled then
        self:ApplyAllPositions()
        self:QueueAllTooltipPositions()
        self:Message(L.MSG_POSITIONING_ON)
    else
        -- Existing anchors are no longer enforced. ESO may rebuild its normal anchors
        -- the next time a tooltip is shown. Visibility control remains active.
        self:Message(L.MSG_POSITIONING_OFF)
    end
end

function TR:SaveMarkerPosition(key, marker)
    if not self.savedVariables or not self.savedVariables.positions[key] then
        return
    end

    local left = marker:GetLeft()
    local top = marker:GetTop()
    if left == nil or top == nil then
        return
    end

    local anchor = self.savedVariables.positions[key].anchor
    self:SetPositionFromTopLeft(key, left, top, anchor)
    self:PositionMarker(key)
    self:ApplyAllPositions()
    self:UpdateMarkerCoordinates()
end

function TR:PositionMarker(key)
    local marker = self.markers[key]
    if not marker then
        return
    end

    self:ClampPosition(key)
    local position = self.savedVariables.positions[key]
    local point = ANCHOR_POINTS[position.anchor] or TOPLEFT

    marker:ClearAnchors()
    marker:SetAnchor(point, GuiRoot, point, position.x, position.y)
end

function TR:BeginMarkerDrag(key, marker)
    if not self.editMode or self.draggingMarker then
        return
    end

    local mouseX, mouseY = GetUIMousePosition()
    local left = marker:GetLeft()
    local top = marker:GetTop()
    if left == nil or top == nil then
        return
    end

    self.draggingKey = key
    self.draggingMarker = marker
    self.dragOffsetX = mouseX - left
    self.dragOffsetY = mouseY - top
end

function TR:UpdateMarkerDrag(marker)
    if self.draggingMarker ~= marker or not self.draggingKey then
        return
    end

    local mouseX, mouseY = GetUIMousePosition()
    local rootWidth = GuiRoot:GetWidth()
    local rootHeight = GuiRoot:GetHeight()
    local markerWidth = marker:GetWidth()
    local maxX = math.max(0, rootWidth - markerWidth)
    local maxY = math.max(0, rootHeight - MARKER_HEIGHT)
    local left = zo_clamp(mouseX - self.dragOffsetX, 0, maxX)
    local top = zo_clamp(mouseY - self.dragOffsetY, 0, maxY)

    marker:ClearAnchors()
    marker:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    marker.coordinatesLabel:SetText(string.format("X: %d   Y: %d", Round(left), Round(top)))
end

function TR:EndMarkerDrag()
    local marker = self.draggingMarker
    local key = self.draggingKey
    if not marker or not key then
        return
    end

    self.draggingMarker = nil
    self.draggingKey = nil
    self.dragOffsetX = nil
    self.dragOffsetY = nil
    self:SaveMarkerPosition(key, marker)
end

function TR:CreateMarker(key)
    local data = markerData[key]
    local marker = WINDOW_MANAGER:CreateTopLevelWindow(data.name)
    marker:SetDimensions(self:GetTooltipWidth(key), MARKER_HEIGHT)
    -- Kein ESO-Standard-Move: das reagiert je nach Control auf die rechte Maustaste.
    -- Tooltipruhe verschiebt die Marker selbst und ausschließlich mit links.
    marker:SetMovable(false)
    marker:SetMouseEnabled(true)
    marker:SetClampedToScreen(true)
    marker:SetDrawLayer(DL_OVERLAY)
    marker:SetDrawTier(DT_HIGH)
    marker:SetHidden(true)

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(data.name .. "Backdrop", marker, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(marker)
    backdrop:SetCenterColor(0.03, 0.05, 0.08, 0.92)
    backdrop:SetEdgeColor(0.50, 0.78, 1.00, 1.00)

    local title = WINDOW_MANAGER:CreateControl(data.name .. "Title", marker, CT_LABEL)
    title:SetFont("ZoFontWinH2")
    title:SetColor(0.50, 0.78, 1.00, 1.00)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetAnchor(TOPLEFT, marker, TOPLEFT, 10, 28)
    title:SetAnchor(TOPRIGHT, marker, TOPRIGHT, -10, 28)
    title:SetText(L[data.titleKey] or data.titleKey)

    local hint = WINDOW_MANAGER:CreateControl(data.name .. "Hint", marker, CT_LABEL)
    hint:SetFont("ZoFontGame")
    hint:SetColor(0.90, 0.90, 0.90, 1.00)
    hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    hint:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 16)
    hint:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 16)
    hint:SetText(L[data.hintKey] or data.hintKey)

    local coordinates = WINDOW_MANAGER:CreateControl(data.name .. "Coordinates", marker, CT_LABEL)
    coordinates:SetFont("ZoFontGameSmall")
    coordinates:SetColor(0.72, 0.72, 0.72, 1.00)
    coordinates:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    coordinates:SetAnchor(BOTTOMLEFT, marker, BOTTOMLEFT, 10, -18)
    coordinates:SetAnchor(BOTTOMRIGHT, marker, BOTTOMRIGHT, -10, -18)
    marker.coordinatesLabel = coordinates

    marker:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            self:BeginMarkerDrag(key, control)
        end
    end)

    marker:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            self:EndMarkerDrag()
        end
    end)

    marker:SetHandler("OnUpdate", function(control)
        self:UpdateMarkerDrag(control)
    end)

    self.markers[key] = marker
    self:PositionMarker(key)
end

function TR:UpdateMarkerCoordinates()
    for key, marker in pairs(self.markers) do
        local left, top = self:GetPositionTopLeft(key)
        marker.coordinatesLabel:SetText(string.format("X: %d   Y: %d", Round(left), Round(top)))
    end
end

function TR:CreateMarkers()
    self:CreateMarker("item")
    self:CreateMarker("compare1")
    self:CreateMarker("compare2")
    self:UpdateMarkerCoordinates()
end

function TR:SetEditMode(enabled, silent)
    enabled = enabled == true

    if enabled and self.savedVariables and self.savedVariables.usePositioning == false then
        if not silent then
            self:Message(L.MSG_POSITIONING_DISABLED)
        end
        return
    end

    if self.editMode == enabled then
        return
    end

    self.editMode = enabled

    if self.editMode then
        self:HideTrackedTooltips()
        self:RefreshMarkerDimensions()
        for key, marker in pairs(self.markers) do
            self:PositionMarker(key)
            marker:SetHidden(false)
        end
        self:UpdateMarkerCoordinates()
        if not silent then
            self:Message(L.MSG_EDIT_ON)
        end
    else
        -- Einen laufenden Links-Drag zuerst sauber abschließen.
        self:EndMarkerDrag()
        -- Noch einmal sichern, falls der Mauszeiger beim Schließen außerhalb eines Markers lag.
        for key, marker in pairs(self.markers) do
            if not marker:IsHidden() then
                self:SaveMarkerPosition(key, marker)
            end
            marker:SetHidden(true)
        end
        self:ApplyAllPositions()
        if self.tooltipsEnabled then
            -- Nicht künstlich sichtbar machen; danach gilt wieder das normale ESO-Hoververhalten.
            ZO_ClearTable(self.suppressed)
        end
        if not silent then
            self:Message(L.MSG_EDIT_OFF)
        end
    end
end

function TR:ToggleEditMode()
    self:SetEditMode(not self.editMode)
end

function TR:ResetPositions()
    if self.savedVariables.usePositioning == false then
        self:Message(L.MSG_POSITIONING_DISABLED)
        return
    end

    for key in pairs(self.savedVariables.positions) do
        local x, y, anchor = self:GetDefaultPosition(key)
        self.savedVariables.positions[key].x = x
        self.savedVariables.positions[key].y = y
        self.savedVariables.positions[key].anchor = anchor
        self:PositionMarker(key)
    end

    self:ApplyAllPositions()
    self:UpdateMarkerCoordinates()
    self:Message(L.MSG_RESET_POSITIONS)
end

function TR:GetPresetGap()
    local rootWidth = GuiRoot:GetWidth()
    local totalWidths = 0
    for _, key in ipairs(presetOrder) do
        totalWidths = totalWidths + self:GetTooltipWidth(key)
    end

    local freeSpace = rootWidth - (POSITION_MARGIN * 2) - totalWidths
    if freeSpace <= 0 then
        return 0
    end

    return math.min(PRESET_GAP, math.floor(freeSpace / 2))
end

function TR:ApplyCornerPreset(horizontal, vertical)
    if self.savedVariables.usePositioning == false then
        self:Message(L.MSG_POSITIONING_DISABLED)
        return
    end

    self:RefreshMarkerDimensions()
    local gap = self:GetPresetGap()
    local anchor

    if horizontal == "left" and vertical == "top" then
        anchor = "TOPLEFT"
    elseif horizontal == "right" and vertical == "top" then
        anchor = "TOPRIGHT"
    elseif horizontal == "left" and vertical == "bottom" then
        anchor = "BOTTOMLEFT"
    else
        anchor = "BOTTOMRIGHT"
    end

    local offsetX = POSITION_MARGIN
    for _, key in ipairs(presetOrder) do
        local position = self.savedVariables.positions[key]
        position.anchor = anchor

        if horizontal == "left" then
            -- Sichtbare Reihenfolge von links nach rechts: 1 2 3.
            position.x = offsetX
        else
            -- Sichtbare Reihenfolge von links nach rechts: 3 2 1.
            -- Jeder weitere Tooltip rückt exakt um die gemessene Breite des vorherigen Fensters nach innen.
            position.x = -offsetX
        end

        if vertical == "top" then
            position.y = POSITION_MARGIN
        else
            -- Unten verankerte Tooltips wachsen nach oben und bleiben im Bild.
            position.y = -POSITION_MARGIN
        end

        self:PositionMarker(key)
        offsetX = offsetX + self:GetTooltipWidth(key) + gap
    end

    self:ApplyAllPositions()
    self:QueueAllTooltipPositions()
    self:UpdateMarkerCoordinates()

    local names = {
        left = { top = L.PRESET_TOP_LEFT, bottom = L.PRESET_BOTTOM_LEFT },
        right = { top = L.PRESET_TOP_RIGHT, bottom = L.PRESET_BOTTOM_RIGHT },
    }
    self:Message(string.format(L.MSG_PRESET_APPLIED, names[horizontal][vertical]))
end

function TR:RegisterTrackedTooltips()
    if ItemTooltip then
        self.tooltipKeys[ItemTooltip] = "item"
    end
    if ComparativeTooltip1 then
        self.tooltipKeys[ComparativeTooltip1] = "compare1"
    end
    if ComparativeTooltip2 then
        self.tooltipKeys[ComparativeTooltip2] = "compare2"
    end
end

function TR:InstallHooks()
    for control in pairs(self.tooltipKeys) do
        ZO_PostHookHandler(control, "OnShow", function(shownControl)
            self:HandleTooltipShown(shownControl)
        end)

        ZO_PostHookHandler(control, "OnEffectivelyShown", function(shownControl)
            self:HandleTooltipShown(shownControl)
        end)

        -- ComparativeTooltip1/2 werden von ESO nachträglich dynamisch neu verankert.
        -- Ein OnUpdate-PostHook ist absichtlich der letzte Schutz: Owner bleibt original,
        -- nur die sichtbare Position wird auf Tooltipruhes gespeicherten Punkt gesetzt.
        ZO_PostHookHandler(control, "OnUpdate", function(updatedControl)
            self:EnforceVisibleTooltipPosition(updatedControl)
        end)
    end

    ZO_PostHook("InitializeTooltip", function(tooltipControl)
        self:QueueTooltipPosition(tooltipControl)
    end)

    -- ESO richtet Item- und Vergleichs-Tooltips oft erst nach InitializeTooltip dynamisch aus.
    -- Dieser PostHook läuft nach dieser Standardausrichtung und setzt unsere gespeicherten Bildschirmanker zurück.
    if ZO_Tooltips_SetupDynamicTooltipAnchors then
        ZO_PostHook("ZO_Tooltips_SetupDynamicTooltipAnchors", function(tooltipControl, _, comparativeTooltip1, comparativeTooltip2)
            self:QueueTooltipPosition(tooltipControl)
            self:QueueTooltipPosition(comparativeTooltip1)
            self:QueueTooltipPosition(comparativeTooltip2)
        end)
    end

    ZO_PostHook("ClearTooltip", function(tooltipControl)
        if self:IsTrackedTooltip(tooltipControl) then
            self.suppressed[tooltipControl] = nil
        end
    end)
end

function TR:RegisterSlashCommand()
    SLASH_COMMANDS["/tooltipruhe"] = function(arguments)
        local command = zo_strlower(zo_strtrim(arguments or ""))

        if command == "" or command == "settings" or command == "config" then
            if self.OpenSettings then
                self:OpenSettings()
            end
        elseif command == "toggle" then
            self:ToggleVisibility()
        elseif command == "edit" or command == "position" then
            self:ToggleEditMode()
        elseif command == "reset" then
            self:ResetPositions()
        elseif command == "on" then
            self:SetTooltipsEnabled(true, true, true)
        elseif command == "off" then
            self:SetTooltipsEnabled(false, true, false)
        else
            self:Message(L.MSG_COMMANDS)
        end
    end
end

function TR:Initialize()
    local worldName = GetWorldName()
    self.savedVariables = ZO_SavedVars:NewAccountWide(
        self.savedVariableName,
        self.savedVariableVersion,
        worldName,
        defaults
    )

    self.tooltipsEnabled = self.savedVariables.permanentEnabled == true
    self.editMode = false

    self:RegisterTrackedTooltips()

    for key in pairs(markerData) do
        self:EnsurePosition(key)
        self:ClampPosition(key)
    end

    self:CreateMarkers()

    EVENT_MANAGER:RegisterForEvent(self.name .. "GlobalMouseUp", EVENT_GLOBAL_MOUSE_UP, function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            self:EndMarkerDrag()
        end
    end)

    self:InstallHooks()
    if self.InstallAddonManagerGear then
        self:InstallAddonManagerGear()
    end
    if self.InstallSettingsCloseBehavior then
        self:InstallSettingsCloseBehavior()
    end
    self:RegisterSlashCommand()

    if self.tooltipsEnabled then
        self:ApplyAllPositions()
    else
        self:HideTrackedTooltips()
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= TR.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(TR.name, EVENT_ADD_ON_LOADED)
    TR:Initialize()
end

EVENT_MANAGER:RegisterForEvent(TR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

ZO_CreateStringId("SI_BINDING_NAME_TOOLTIPRUHE_TOGGLE_VISIBILITY", L.BIND_TOGGLE_VISIBILITY)
ZO_CreateStringId("SI_BINDING_NAME_TOOLTIPRUHE_TOGGLE_EDIT", L.BIND_TOGGLE_EDIT)

function Tooltipruhe_ToggleVisibility()
    TR:ToggleVisibility()
end

function Tooltipruhe_ToggleEditMode()
    TR:ToggleEditMode()
end
