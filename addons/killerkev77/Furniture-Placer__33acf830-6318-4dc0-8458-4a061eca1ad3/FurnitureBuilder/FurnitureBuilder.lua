-- FurnitureBuilder.lua ("Furniture Placer")
--
-- Precision alignment tools for the Housing Editor: read exact furniture
-- coordinates and move items to match, instead of eyeballing placement.
--
-- v0.5.5 (2026-10-27): still gaps with Leyawiin walls. Fit now measures the
--   item's own box turned to match the item (the box around it in the world is
--   too big for anything standing at an angle to the house), and a
--   "Tighten / loosen" setting nudges the step by a few cm.
-- v0.5.4 (2026-10-27): after "Fit this item to row", items are placed exactly
--   one item-length apart from the row start (edge to edge) instead of being
--   stretched to the end mark, which left gaps (seen with Leyawiin walls).
--   Changing "Items in row" by hand goes back to even spreading.
-- v0.5.3 (2026-10-27): "Fit this item to row" -- aim at an item and Placer
--   works out how many of it fit edge to edge between the row marks, then
--   sets "Items in row" to that. Items in row now goes up to 50.
-- v0.5.2 (2026-10-27): Align X/Z split into separate "Match X" and
--   "Match Z" actions (/fbalign still does both together).
-- v0.5.1 (2026-10-27): "Match height" -- move the item up or down to the
--   reference's height, keeping its own X/Z position and rotation.
-- v0.5.0 (2026-10-27): Placer mode. The separate menu screen is gone: it
--   closed the Housing Editor, losing the camera view and the highlighted item.
--   Hold X now swaps the editor's button bar for Placer buttons and shows the
--   action list on screen. The editor stays open throughout, and each action
--   works on the item under the reticle when you press A.
--   No longer needs LibConsoleDialogs or LibHarvensAddonSettings.
-- v0.4.2 (2026-10-27): closing the menu (B, or after an action) closed the
--   Housing Editor too. Placer now puts you straight back into the editor in
--   aiming mode, and runs the chosen action once the editor is back.
-- v0.4.0 / v0.4.1 (2026-10-27) -- console controls, no typing needed:
--   * A "Furniture Placer" button on the Housing Editor's own button bar
--     (selection mode), on Hold X. The Quickslot Wheel can't be used: it
--     doesn't open inside the Housing Editor (confirmed in game).
--     v0.4.0 test result (2026-10-27): of three routes tried, only the
--     editor's 6th action slot (HOUSING_EDITOR_SENARY_ACTION) showed on
--     console, as Hold X. LibConsoleDialogs:RegisterKeybind on the HUD scene
--     and the 4th action slot did not show. v0.4.1 keeps only the 6th slot.
--   * The item you are aiming at is captured when the button is pressed, so
--     menu actions work on it even though the menu covers the screen.
--   * Results show on screen (toast + inspect panel) instead of in chat.
--   * The menu closes after an action, ready to aim at the next item.
--   * Undo last move, and a small status panel while the editor is open.
--   Slash commands still work (PC / keyboard) and act on the live target.
--
-- Core functions confirmed against real, working, currently-maintained
-- addon source (github.com/WetWiredU/HomesteadEng) and API 101051 docs:
--   HousingEditorGetTargetInfo (replaces the old select + mode-reset
--     pattern that broke in U41)
--   HousingEditorGetFurnitureWorldPosition / GetFurnitureOrientation
--   HousingEditorRequestChangePositionAndOrientation

FurnitureBuilder = FurnitureBuilder or {}
local FB = FurnitureBuilder
FB.name = "FurnitureBuilder"
FB.SavedVars = nil -- initialized in OnAddOnLoaded

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

local function IsZeroId(id)
    if id == nil then return true end
    if CompareId64ToNumber then
        local ok, result = pcall(CompareId64ToNumber, id, 0)
        if ok then return result == 0 end
    end
    return id == 0
end

local function FurnitureName(furnId)
    if IsZeroId(furnId) then return nil end
    local ok, name = pcall(GetPlacedHousingFurnitureInfo, furnId)
    if ok and name and name ~= "" then
        return zo_strformat("<<1>>", name)
    end
    return "that item"
end

local function InEditor()
    return GetHousingEditorMode and GetHousingEditorMode() ~= HOUSING_EDITOR_MODE_DISABLED
end

-- ---------------------------------------------------------------------------
-- On-screen feedback: a toast at the top and an inspect panel at the bottom right
-- ---------------------------------------------------------------------------

local toast, inspectPanel, statusPanel
local toastGeneration = 0

local function MakeLabel(parent, font, r, g, b)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(font)
    label:SetColor(r or 1, g or 1, b or 1, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    return label
end

local function MakePanel(name, width)
    local panel = WINDOW_MANAGER:CreateTopLevelWindow(name)
    panel:SetDimensions(width, 60)
    panel:SetHidden(true)
    panel:SetMouseEnabled(false)
    panel:SetDrawTier(DT_HIGH)
    local bg = WINDOW_MANAGER:CreateControl(nil, panel, CT_BACKDROP)
    bg:SetAnchorFill(panel)
    bg:SetCenterColor(0.08, 0.09, 0.11, 0.94)
    bg:SetEdgeColor(0.29, 0.25, 0.19, 1)
    bg:SetEdgeTexture("", 2, 2, 2)
    panel.bg = bg
    return panel
end

local function BuildFeedbackControls()
    if toast then return end

    toast = MakePanel("FurnitureBuilder_Toast", 620)
    toast:SetAnchor(TOP, GuiRoot, TOP, 0, 60)
    toast.title = MakeLabel(toast, "ZoFontGamepad34")
    toast.title:SetAnchor(TOPLEFT, toast, TOPLEFT, 20, 12)
    toast.title:SetWidth(580)
    toast.detail = MakeLabel(toast, "ZoFontGamepad27", 0.79, 0.76, 0.71)
    toast.detail:SetAnchor(TOPLEFT, toast.title, BOTTOMLEFT, 0, 4)
    toast.detail:SetWidth(580)

    inspectPanel = MakePanel("FurnitureBuilder_Inspect", 460)
    inspectPanel:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, -40, -140)
    inspectPanel:SetHeight(190)
    inspectPanel.title = MakeLabel(inspectPanel, "ZoFontGamepad27", 0.85, 0.71, 0.42)
    inspectPanel.title:SetAnchor(TOPLEFT, inspectPanel, TOPLEFT, 20, 14)
    inspectPanel.title:SetWidth(420)
    inspectPanel.body = MakeLabel(inspectPanel, "ZoFontGamepad25")
    inspectPanel.body:SetAnchor(TOPLEFT, inspectPanel.title, BOTTOMLEFT, 0, 8)
    inspectPanel.body:SetWidth(420)

    statusPanel = MakePanel("FurnitureBuilder_Status", 380)
    statusPanel:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -40, 40)
    statusPanel:SetHeight(150)
    statusPanel.title = MakeLabel(statusPanel, "ZoFontGamepad27", 0.85, 0.71, 0.42)
    statusPanel.title:SetAnchor(TOPLEFT, statusPanel, TOPLEFT, 18, 12)
    statusPanel.title:SetText("Furniture Placer")
    statusPanel.body = MakeLabel(statusPanel, "ZoFontGamepad22")
    statusPanel.body:SetAnchor(TOPLEFT, statusPanel.title, BOTTOMLEFT, 0, 6)
    statusPanel.body:SetWidth(344)
end

-- ok = true (green tick feel) / false (red)
local function Notify(ok, title, detail)
    BuildFeedbackControls()
    if ok then
        toast.title:SetColor(0.49, 0.77, 0.35, 1)
        toast.bg:SetEdgeColor(0.35, 0.64, 0.24, 1)
    else
        toast.title:SetColor(0.9, 0.42, 0.36, 1)
        toast.bg:SetEdgeColor(0.83, 0.28, 0.23, 1)
    end
    toast.title:SetText(title)
    toast.detail:SetText(detail or "")
    toast:SetHeight(detail and detail ~= "" and 104 or 64)
    toast:SetHidden(false)

    toastGeneration = toastGeneration + 1
    local mine = toastGeneration
    zo_callLater(function()
        if toastGeneration == mine and toast then
            toast:SetHidden(true)
        end
    end, 4000)
end

-- ---------------------------------------------------------------------------
-- Screen-locked visual grid (rough alignment guide, not tied to 3D position)
-- ---------------------------------------------------------------------------

local gridWindow = nil
local gridVisible = false
local GRID_LINE_COUNT = 6
local GRID_LINE_THICKNESS = 2

local function BuildGrid()
    if gridWindow then return end

    local ok, err = pcall(function()
        gridWindow = WINDOW_MANAGER:CreateTopLevelWindow("FurnitureBuilder_Grid")
        gridWindow:SetAnchorFill(GuiRoot)
        gridWindow:SetHidden(true)
        gridWindow:SetMouseEnabled(false)

        local screenW = GuiRoot:GetWidth()
        local screenH = GuiRoot:GetHeight()

        for i = 1, GRID_LINE_COUNT do
            local x = (screenW / (GRID_LINE_COUNT + 1)) * i
            local line = WINDOW_MANAGER:CreateControl(nil, gridWindow, CT_BACKDROP)
            line:SetDimensions(GRID_LINE_THICKNESS, screenH)
            line:SetAnchor(TOPLEFT, gridWindow, TOPLEFT, x, 0)
            line:SetCenterColor(1, 1, 0, 0.45)
            line:SetEdgeColor(0, 0, 0, 0)
        end

        for i = 1, GRID_LINE_COUNT do
            local y = (screenH / (GRID_LINE_COUNT + 1)) * i
            local line = WINDOW_MANAGER:CreateControl(nil, gridWindow, CT_BACKDROP)
            line:SetDimensions(screenW, GRID_LINE_THICKNESS)
            line:SetAnchor(TOPLEFT, gridWindow, TOPLEFT, 0, y)
            line:SetCenterColor(1, 1, 0, 0.45)
            line:SetEdgeColor(0, 0, 0, 0)
        end
    end)

    if not ok then
        Notify(false, "Grid could not be drawn", tostring(err))
    end
end

local function SetGridVisible(visible)
    BuildGrid()
    if not gridWindow then return end
    gridVisible = visible
    gridWindow:SetHidden(not gridVisible)
end

local function ToggleGrid()
    SetGridVisible(not gridVisible)
end
SLASH_COMMANDS["/fbgrid"] = ToggleGrid

-- ---------------------------------------------------------------------------
-- Targeting
--
-- HousingEditorGetTargetInfo() (API 101051) reads the targeted item's ID
-- directly -- no pickup, camera lock or mode change. The old select +
-- mode-reset pattern broke in Update 41.
-- ---------------------------------------------------------------------------

local function GetLiveTargetId()
    if not InEditor() then
        return nil, "Open the Housing Editor first"
    end
    local ok, furnId = pcall(HousingEditorGetTargetInfo)
    if not ok or IsZeroId(furnId) then
        return nil, "Point at a placed furnishing first"
    end
    return furnId
end

local function ReadTransform(furnId)
    local okPos, x, y, z = pcall(HousingEditorGetFurnitureWorldPosition, furnId)
    local okRot, pitch, yaw, roll = pcall(HousingEditorGetFurnitureOrientation, furnId)
    if not okPos or not okRot or x == nil or pitch == nil then
        return nil
    end
    return { x = x, y = y, z = z, pitch = pitch, yaw = yaw, roll = roll }
end

-- ---------------------------------------------------------------------------
-- Moving, with a one-step undo
-- ---------------------------------------------------------------------------

local lastMove = nil -- { furnId, before = transform }

local function MoveTo(furnId, t)
    local before = ReadTransform(furnId)
    local ok, result = pcall(HousingEditorRequestChangePositionAndOrientation,
        furnId, t.x, t.y, t.z, t.pitch, t.yaw, t.roll)
    if not ok then
        return false, tostring(result)
    end
    if result ~= nil and HOUSING_REQUEST_RESULT_SUCCESS ~= nil and result ~= HOUSING_REQUEST_RESULT_SUCCESS then
        return false, GetString("SI_HOUSINGREQUESTRESULT", result)
    end
    if before then
        lastMove = { furnId = furnId, before = before }
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Actions. Each takes the furniture id to act on (captured target for the
-- menu, live target for slash commands) and reports on screen.
-- ---------------------------------------------------------------------------

local FB_reference = nil -- { name, t }
local FB_pointA, FB_pointB = nil, nil
local FB_lastFit = nil -- how many fit, from "Fit this item to row"
local FB_fitStep = nil -- that item's length along the row, in cm
local FB_fitRaw = nil -- the same, before the tighten / loosen tweak
local FB_spaceIndex = 0

local UpdateStatusPanel -- forward declaration

local function NeedTarget(furnId, why)
    if IsZeroId(furnId) then
        Notify(false, "No item selected", why or "Aim at a placed furnishing first")
        return false
    end
    return true
end

local function DoInspect(furnId)
    if not NeedTarget(furnId) then return end
    local t = ReadTransform(furnId)
    if not t then
        Notify(false, "Couldn't read that item's position")
        return
    end
    BuildFeedbackControls()
    inspectPanel.title:SetText("Inspect: " .. FurnitureName(furnId))
    inspectPanel.body:SetText(string.format(
        "X %d   Y (height) %d   Z %d\nPitch %.0f°   Yaw %.0f°   Roll %.0f°\n|c9e9a8ePositions in centimetres|r",
        zo_round(t.x), zo_round(t.y), zo_round(t.z), math.deg(t.pitch), math.deg(t.yaw), math.deg(t.roll)))
    inspectPanel:SetHidden(false)
end

local function DoMark(furnId)
    if not NeedTarget(furnId) then return end
    local t = ReadTransform(furnId)
    if not t then
        Notify(false, "Couldn't read that item's position")
        return
    end
    FB_reference = { name = FurnitureName(furnId), t = t }
    Notify(true, "Reference marked", FB_reference.name)
    UpdateStatusPanel()
end

-- mode: "x"  = match X only, keep Z, height and rotation
--       "z"  = match Z only, keep X, height and rotation
--       "y"  = match height only, keep X/Z and rotation
--       "xz" = match X/Z, keep height and rotation
--       "xyz" = match position, keep rotation
--       "all" = match position and rotation
local function DoAlign(furnId, mode)
    if not FB_reference then
        Notify(false, "No reference yet", "Aim at the item to line up with and choose 'Mark as reference'")
        return
    end
    if not NeedTarget(furnId) then return end
    local t = ReadTransform(furnId)
    if not t then
        Notify(false, "Couldn't read that item's position")
        return
    end
    local ref = FB_reference.t
    local target = { x = ref.x, y = t.y, z = ref.z, pitch = t.pitch, yaw = t.yaw, roll = t.roll }
    local title = "Aligned X/Z to reference"
    if mode == "x" then
        target.z = t.z
        title = "Matched X to reference"
    elseif mode == "z" then
        target.x = t.x
        title = "Matched Z to reference"
    elseif mode == "y" then
        target.x, target.z = t.x, t.z
        target.y = ref.y
        title = "Matched height to reference"
    elseif mode == "xyz" then
        target.y = ref.y
        title = "Aligned full position"
    elseif mode == "all" then
        target.y, target.pitch, target.yaw, target.roll = ref.y, ref.pitch, ref.yaw, ref.roll
        title = "Matched position and rotation"
    end
    local ok, err = MoveTo(furnId, target)
    if ok then
        Notify(true, title, string.format("%s now lines up with %s", FurnitureName(furnId), FB_reference.name))
    else
        Notify(false, "Couldn't move that item", err)
    end
end

local function DoMarkA(furnId)
    if not NeedTarget(furnId) then return end
    local t = ReadTransform(furnId)
    if not t then
        Notify(false, "Couldn't read that item's position")
        return
    end
    FB_pointA = t
    FB_spaceIndex = 0
    FB_lastFit = nil
    FB_fitStep = nil
    Notify(true, "Row start marked", FurnitureName(furnId))
    UpdateStatusPanel()
end

local function DoMarkB(furnId)
    if not NeedTarget(furnId) then return end
    local t = ReadTransform(furnId)
    if not t then
        Notify(false, "Couldn't read that item's position")
        return
    end
    FB_pointB = t
    FB_lastFit = nil
    FB_fitStep = nil
    Notify(true, "Row end marked", FurnitureName(furnId))
    UpdateStatusPanel()
end

local function DoSpace(furnId, count)
    if not FB_pointA or not FB_pointB then
        Notify(false, "Mark both ends of the row first", "Use 'Mark row start' and 'Mark row end'")
        return
    end
    count = tonumber(count)
    if not count or count < 2 then
        Notify(false, "Items in row must be 2 or more")
        return
    end
    if not NeedTarget(furnId) then return end
    if FB_spaceIndex > count - 1 then
        FB_spaceIndex = 0
    end

    local a, b = FB_pointA, FB_pointB
    -- after "Fit this item to row", items go exactly one item-length apart
    -- from the start mark (edge to edge); otherwise they spread evenly from
    -- start to end
    local f = FB_spaceIndex / (count - 1)
    if FB_fitStep and count == FB_lastFit then
        local rowLength = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 + (b.z - a.z) ^ 2)
        f = FB_spaceIndex * FB_fitStep / rowLength
    end
    local target = {
        x = a.x + (b.x - a.x) * f,
        y = a.y + (b.y - a.y) * f,
        z = a.z + (b.z - a.z) * f,
        pitch = a.pitch, yaw = a.yaw, roll = a.roll,
    }
    local ok, err = MoveTo(furnId, target)
    if ok then
        Notify(true, string.format("Placed at slot %d of %d", FB_spaceIndex + 1, count), FurnitureName(furnId))
        FB_spaceIndex = FB_spaceIndex + 1
        UpdateStatusPanel()
    else
        Notify(false, "Couldn't move that item", err)
    end
end

-- How many of the aimed-at item fit edge to edge between the row marks.
-- Uses the item's box in the world (HousingEditorGetFurnitureWorldBounds),
-- measured along the row, and sets "Items in row" to match.
-- The item's length along the row (cm). Uses the item's own box
-- (HousingEditorGetFurnitureLocalBounds) turned to match the item, so an item
-- standing at an angle to the house isn't over-measured. Falls back to the
-- box around it in the world if the item's own box can't be read.
local function MeasureAlongRow(furnId, ux, uy, uz)
    local okW, wMinX, wMinY, wMinZ, wMaxX, wMaxY, wMaxZ = pcall(HousingEditorGetFurnitureWorldBounds, furnId)
    local worldLength = nil
    if okW and wMinX ~= nil then
        worldLength = math.abs(ux) * (wMaxX - wMinX) + math.abs(uy) * (wMaxY - wMinY) + math.abs(uz) * (wMaxZ - wMinZ)
    end
    local okL, lMinX, lMinY, lMinZ, lMaxX, lMaxY, lMaxZ = pcall(HousingEditorGetFurnitureLocalBounds, furnId)
    local t = ReadTransform(furnId)
    if not okL or lMinX == nil or not t then
        return worldLength
    end
    local sx, sy, sz = lMaxX - lMinX, lMaxY - lMinY, lMaxZ - lMinZ
    local c, sn = math.cos(t.yaw), math.sin(t.yaw)
    -- the game's turning direction isn't documented: try both and use the one
    -- where the row runs most squarely along one of the item's sides
    local best, bestAlign = nil, -1
    for _, dir in ipairs({ 1, -1 }) do
        local ex = ux * c - dir * uz * sn   -- row along the item's width
        local ez = dir * ux * sn + uz * c   -- row along the item's depth
        local align = math.max(math.abs(ex), math.abs(ez))
        if align > bestAlign + 0.0001 then
            bestAlign = align
            best = math.abs(ex) * sx + math.abs(ez) * sz + math.abs(uy) * sy
        end
    end
    -- sanity check against the world box (same units, never bigger)
    if worldLength and (best > worldLength + 1 or best < worldLength / 4) then
        return worldLength
    end
    return best
end

local function DoFit(furnId)
    if not FB_pointA or not FB_pointB then
        Notify(false, "Mark both ends of the row first", "Use 'Mark row start' and 'Mark row end'")
        return
    end
    if not NeedTarget(furnId) then return end
    local a, b = FB_pointA, FB_pointB
    local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
    local rowLength = math.sqrt(dx * dx + dy * dy + dz * dz)
    if rowLength < 1 then
        Notify(false, "Row start and end are in the same place", "Mark the first and last item of the row")
        return
    end
    local itemLength = MeasureAlongRow(furnId, dx / rowLength, dy / rowLength, dz / rowLength)
    if not itemLength or itemLength < 1 then
        Notify(false, "Couldn't measure that item")
        return
    end
    FB_fitRaw = itemLength
    itemLength = itemLength + (FB.SavedVars.stepTweak or 0)
    if itemLength < 1 then itemLength = 1 end
    local count = math.floor(rowLength / itemLength + 0.001) + 1
    if count < 2 then
        FB_lastFit = 1
        Notify(false, "Only one fits", string.format("Each item is %.2f m along the row; the row is %.2f m",
            itemLength / 100, rowLength / 100))
        return
    end
    if count > 50 then count = 50 end
    FB_lastFit = count
    FB_fitStep = itemLength
    FB.SavedVars.spaceCount = count
    FB_spaceIndex = 0
    local spare = rowLength - (count - 1) * itemLength
    local detail
    if spare >= 1 then
        detail = string.format("Placed edge to edge from the row start. The last one stops %.2f m short of the end mark. Each item is %.2f m.",
            spare / 100, itemLength / 100)
    else
        detail = string.format("Placed edge to edge from the row start. Each item is %.2f m.", itemLength / 100)
    end
    Notify(true, string.format("%d fit in this row", count), detail)
    UpdateStatusPanel()
end

-- Tighten (minus) or loosen (plus) the gap between fitted items, in cm.
-- For pieces like walls whose box is a little wider than they look.
local STEP_TWEAKS = { 0, -1, -2, -3, -5, -8, -10, -15, -20, -30, 2, 5 }
function FB.CycleStepTweak()
    local current = FB.SavedVars.stepTweak or 0
    local nextValue = STEP_TWEAKS[1]
    for i, v in ipairs(STEP_TWEAKS) do
        if v == current then
            nextValue = STEP_TWEAKS[i % #STEP_TWEAKS + 1]
            break
        end
    end
    FB.SavedVars.stepTweak = nextValue
    if FB_fitRaw and FB_fitStep then
        FB_fitStep = math.max(1, FB_fitRaw + nextValue)
        FB_spaceIndex = 0
        Notify(true, string.format("Gap set to %+d cm", nextValue),
            string.format("Each item now steps %.2f m. Placing starts again from slot 1.", FB_fitStep / 100))
    else
        Notify(true, string.format("Gap set to %+d cm", nextValue), "Used the next time you fit an item to the row")
    end
end

local function DoSnap(furnId, increment)
    increment = tonumber(increment)
    if not increment or increment <= 0 then
        Notify(false, "Snap size must be more than 0")
        return
    end
    if not NeedTarget(furnId) then return end
    local t = ReadTransform(furnId)
    if not t then
        Notify(false, "Couldn't read that item's position")
        return
    end
    local incCm = increment * 100
    local target = {
        x = zo_round(t.x / incCm) * incCm, y = t.y, z = zo_round(t.z / incCm) * incCm,
        pitch = t.pitch, yaw = t.yaw, roll = t.roll,
    }
    local ok, err = MoveTo(furnId, target)
    if ok then
        Notify(true, string.format("Snapped to nearest %.1f m", increment), FurnitureName(furnId))
    else
        Notify(false, "Couldn't move that item", err)
    end
end

local function DoUndo()
    if not lastMove then
        Notify(false, "Nothing to undo")
        return
    end
    local move = lastMove
    local b = move.before
    local ok, result = pcall(HousingEditorRequestChangePositionAndOrientation,
        move.furnId, b.x, b.y, b.z, b.pitch, b.yaw, b.roll)
    if ok then
        lastMove = nil
        Notify(true, "Last move undone", FurnitureName(move.furnId))
    else
        Notify(false, "Couldn't undo", tostring(result))
    end
end

-- ---------------------------------------------------------------------------
-- Status panel (top right, only while the Housing Editor is open)
-- ---------------------------------------------------------------------------

UpdateStatusPanel = function()
    BuildFeedbackControls()
    local show = FB.SavedVars and FB.SavedVars.showStatus ~= false and HOUSING_EDITOR_HUD_SCENE ~= nil
        and HOUSING_EDITOR_HUD_SCENE:IsShowing() and not (FB.IsPlacerMode and FB.IsPlacerMode())
    if not show then
        statusPanel:SetHidden(true)
        return
    end
    local refText = FB_reference and FB_reference.name or "|c9e9a8enot set|r"
    local rowText
    if FB_pointA and FB_pointB then
        rowText = string.format("ready · next slot %d of %d", FB_spaceIndex + 1, FB.SavedVars.spaceCount)
    elseif FB_pointA then
        rowText = "start set · end not set"
    else
        rowText = "|c9e9a8enot set|r"
    end
    statusPanel.body:SetText(string.format("Reference: %s\nRow: %s\nSnap: %.1f m", refText, rowText, FB.SavedVars.snapIncrement))
    statusPanel:SetHidden(false)
end

-- ---------------------------------------------------------------------------
-- Slash commands (PC / keyboard). These act on the item under the cursor now.
-- ---------------------------------------------------------------------------

local function WithLiveTarget(fn, ...)
    local furnId, why = GetLiveTargetId()
    if not furnId then
        Notify(false, "No item selected", why)
        return
    end
    fn(furnId, ...)
end

SLASH_COMMANDS["/fbtarget"] = function() WithLiveTarget(DoInspect) end
SLASH_COMMANDS["/fbmark"] = function() WithLiveTarget(DoMark) end
SLASH_COMMANDS["/fbalign"] = function() WithLiveTarget(DoAlign, "xz") end
SLASH_COMMANDS["/fbalignx"] = function() WithLiveTarget(DoAlign, "x") end
SLASH_COMMANDS["/fbalignz"] = function() WithLiveTarget(DoAlign, "z") end
SLASH_COMMANDS["/fbalignheight"] = function() WithLiveTarget(DoAlign, "y") end
SLASH_COMMANDS["/fbalignfull"] = function() WithLiveTarget(DoAlign, "xyz") end
SLASH_COMMANDS["/fbalignrot"] = function() WithLiveTarget(DoAlign, "all") end
SLASH_COMMANDS["/fbmarka"] = function() WithLiveTarget(DoMarkA) end
SLASH_COMMANDS["/fbmarkb"] = function() WithLiveTarget(DoMarkB) end
SLASH_COMMANDS["/fbfit"] = function() WithLiveTarget(DoFit) end
SLASH_COMMANDS["/fbspace"] = function(arg) WithLiveTarget(DoSpace, tonumber(arg) or FB.SavedVars.spaceCount) end
SLASH_COMMANDS["/fbsnap"] = function(arg) WithLiveTarget(DoSnap, tonumber(arg) or FB.SavedVars.snapIncrement) end
SLASH_COMMANDS["/fbundo"] = DoUndo

-- ---------------------------------------------------------------------------
-- Placer mode (v0.5.0)
--
-- Everything happens inside the Housing Editor: Hold X swaps the editor's
-- button bar for Placer buttons and shows the action list. No separate menu
-- screen, so the editor never closes, the camera stays where it is and the
-- game keeps highlighting the item you're aiming at. Every action works on
-- whatever is under the reticle at the moment you press the button.
-- ---------------------------------------------------------------------------

local placerMode = false
local enterAdded, placerAdded, exitRemoved = false, false, false
local selectedRow = 2
local listPanel = nil
local listRows = {}
local ROW_HEIGHT = 40
local placerKeybindGroup -- defined further down
local SNAP_STEPS = { 0.1, 0.25, 0.5, 1.0, 2.0 }

local function InSelectionMode()
    return GetHousingEditorMode and GetHousingEditorMode() == HOUSING_EDITOR_MODE_SELECTION
end

local function EditorHudShowing()
    return HOUSING_EDITOR_HUD_SCENE ~= nil and HOUSING_EDITOR_HUD_SCENE:IsShowing()
end

local function OnTarget(fn, ...)
    local args = { ... }
    return function()
        local furnId, why = GetLiveTargetId()
        if not furnId then
            Notify(false, "No item selected", why)
            return
        end
        fn(furnId, unpack(args))
    end
end

local function NextSnapSize()
    local current = FB.SavedVars.snapIncrement
    for _, step in ipairs(SNAP_STEPS) do
        if step > current + 0.001 then
            return step
        end
    end
    return SNAP_STEPS[1]
end

-- header rows have no run function. value() returns the text on the right.
local ACTIONS = {
    { label = "Align" },
    { label = "Mark as reference", run = OnTarget(DoMark),
      value = function() return FB_reference and "set" or "" end },
    { label = "Match X", run = OnTarget(DoAlign, "x") },
    { label = "Match Z", run = OnTarget(DoAlign, "z") },
    { label = "Match height", run = OnTarget(DoAlign, "y") },
    { label = "Align full position", run = OnTarget(DoAlign, "xyz") },
    { label = "Match position + rotation", run = OnTarget(DoAlign, "all") },
    { label = "Spacing" },
    { label = "Mark row start", run = OnTarget(DoMarkA),
      value = function() return FB_pointA and "set" or "not set" end },
    { label = "Mark row end", run = OnTarget(DoMarkB),
      value = function() return FB_pointB and "set" or "not set" end },
    { label = "Fit this item to row", run = OnTarget(DoFit),
      value = function() return FB_lastFit and ("fits " .. FB_lastFit) or "" end },
    { label = "Tighten / loosen",
      run = function() FB.CycleStepTweak() end,
      value = function()
          local v = FB.SavedVars.stepTweak or 0
          if v == 0 then return "0 cm  (A = change)" end
          return string.format("%+d cm  (A = change)", v)
      end },
    { label = "Items in row",
      run = function()
          local n = FB.SavedVars.spaceCount + 1
          if n > 50 then n = 2 end
          FB.SavedVars.spaceCount = n
      end,
      value = function() return tostring(FB.SavedVars.spaceCount) .. "  (A = +1)" end },
    { label = "Place at next slot",
      run = function()
          local furnId, why = GetLiveTargetId()
          if not furnId then
              Notify(false, "No item selected", why)
              return
          end
          DoSpace(furnId, FB.SavedVars.spaceCount)
      end,
      value = function() return string.format("%d of %d", FB_spaceIndex + 1, FB.SavedVars.spaceCount) end },
    { label = "Other" },
    { label = "Snap this item",
      run = function()
          local furnId, why = GetLiveTargetId()
          if not furnId then
              Notify(false, "No item selected", why)
              return
          end
          DoSnap(furnId, FB.SavedVars.snapIncrement)
      end,
      value = function() return string.format("%.2g m", FB.SavedVars.snapIncrement) end },
    { label = "Snap size",
      run = function() FB.SavedVars.snapIncrement = NextSnapSize() end,
      value = function() return string.format("%.2g m  (A = change)", FB.SavedVars.snapIncrement) end },
    { label = "Inspect", run = OnTarget(DoInspect) },
    { label = "Undo last move", run = function() DoUndo() end },
    { label = "Screen grid", run = function() ToggleGrid() end,
      value = function() return gridVisible and "on" or "off" end },
}

local function BuildList()
    if listPanel then return end
    listPanel = MakePanel("FurnitureBuilder_PlacerList", 470)
    listPanel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 40, 40)

    listPanel.title = MakeLabel(listPanel, "ZoFontGamepad34", 0.85, 0.71, 0.42)
    listPanel.title:SetAnchor(TOPLEFT, listPanel, TOPLEFT, 20, 12)
    listPanel.title:SetText("Placer mode")

    local y = 60
    for i, action in ipairs(ACTIONS) do
        local row = {}
        if action.run then
            row.highlight = WINDOW_MANAGER:CreateControl(nil, listPanel, CT_BACKDROP)
            row.highlight:SetAnchor(TOPLEFT, listPanel, TOPLEFT, 12, y)
            row.highlight:SetDimensions(446, ROW_HEIGHT - 4)
            row.highlight:SetCenterColor(0.16, 0.14, 0.09, 1)
            row.highlight:SetEdgeColor(0.85, 0.71, 0.42, 1)
            row.highlight:SetEdgeTexture("", 2, 2, 2)
            row.highlight:SetHidden(true)
            row.label = MakeLabel(listPanel, "ZoFontGamepad27")
            row.label:SetAnchor(TOPLEFT, listPanel, TOPLEFT, 26, y + 4)
            row.value = MakeLabel(listPanel, "ZoFontGamepad22", 0.7, 0.68, 0.62)
            row.value:SetAnchor(TOPRIGHT, listPanel, TOPLEFT, 446, y + 8)
            row.value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            y = y + ROW_HEIGHT
        else
            row.label = MakeLabel(listPanel, "ZoFontGamepad22", 0.7, 0.68, 0.62)
            row.label:SetAnchor(TOPLEFT, listPanel, TOPLEFT, 20, y + 8)
            y = y + ROW_HEIGHT - 4
        end
        row.label:SetText(action.label)
        listRows[i] = row
    end

    listPanel.footer = MakeLabel(listPanel, "ZoFontGamepad22", 0.7, 0.68, 0.62)
    listPanel.footer:SetAnchor(TOPLEFT, listPanel, TOPLEFT, 20, y + 10)
    listPanel.footer:SetWidth(430)
    listPanel:SetHeight(y + 56)
end

local function RefreshList()
    BuildList()
    for i, action in ipairs(ACTIONS) do
        local row = listRows[i]
        if action.run then
            local selected = (i == selectedRow)
            row.highlight:SetHidden(not selected)
            row.label:SetColor(1, 1, 1, 1)
            row.value:SetText(action.value and action.value() or "")
        end
    end
    local refText = FB_reference and FB_reference.name or "not set"
    listPanel.footer:SetText("Reference: " .. refText)
    if placerAdded then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(placerKeybindGroup)
    end
end

local function ShowList(show)
    BuildList()
    if show then
        RefreshList()
    end
    listPanel:SetHidden(not show)
end

local function MoveSelection(step)
    local count = #ACTIONS
    local i = selectedRow
    for _ = 1, count do
        i = i + step
        if i > count then i = 1 end
        if i < 1 then i = count end
        if ACTIONS[i].run then break end
    end
    selectedRow = i
    RefreshList()
end

local function RunSelected()
    local action = ACTIONS[selectedRow]
    if action and action.run then
        if inspectPanel and action.label ~= "Inspect" then inspectPanel:SetHidden(true) end
        action.run()
        RefreshList()
        UpdateStatusPanel()
    end
end

-- ---------------------------------------------------------------------------
-- Button bar. Outside Placer mode: one "Furniture Placer" button (Hold X)
-- next to the editor's own buttons. In Placer mode: the editor's buttons come
-- off and these take their place.
-- ---------------------------------------------------------------------------

local EnterPlacerMode, LeavePlacerMode -- forward declarations

local enterKeybindGroup = {
    alignment = KEYBIND_STRIP_ALIGN_RIGHT,
    {
        name = "Furniture Placer",
        keybind = "HOUSING_EDITOR_SENARY_ACTION",
        callback = function() EnterPlacerMode() end,
        visible = InSelectionMode,
    },
}

placerKeybindGroup = {
    alignment = KEYBIND_STRIP_ALIGN_CENTER,
    {
        name = "Previous action",
        keybind = "HOUSING_EDITOR_UNDO_ACTION",
        callback = function() MoveSelection(-1) end,
        order = 10,
    },
    {
        name = "Next action",
        keybind = "HOUSING_EDITOR_REDO_ACTION",
        callback = function() MoveSelection(1) end,
        order = 20,
    },
    {
        name = function()
            local action = ACTIONS[selectedRow]
            return action and action.label or "Do it"
        end,
        keybind = "HOUSING_EDITOR_PRIMARY_ACTION",
        callback = RunSelected,
        order = 30,
    },
    {
        name = "Leave Placer",
        keybind = "DISABLE_HOUSING_EDITOR",
        callback = function() LeavePlacerMode() end,
        order = 40,
    },
    -- spare buttons in case undo/redo turn out awkward on a controller:
    -- the editor's 2nd and 3rd action buttons also step through the list
    {
        name = "Next action (spare)",
        keybind = "HOUSING_EDITOR_SECONDARY_ACTION",
        callback = function() MoveSelection(1) end,
        ethereal = true,
    },
    {
        name = "Previous action (spare)",
        keybind = "HOUSING_EDITOR_TERTIARY_ACTION",
        callback = function() MoveSelection(-1) end,
        ethereal = true,
    },
}


local function RemoveOurButtons()
    if enterAdded then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(enterKeybindGroup)
        enterAdded = false
    end
    if placerAdded then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(placerKeybindGroup)
        placerAdded = false
    end
end

-- Take the editor's own buttons off the bar (they share A, B, X, Y with ours)
local function HideEditorButtons()
    local hud = HOUSING_EDITOR_SHARED
    if hud.currentKeybindDescriptor then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(hud.currentKeybindDescriptor)
    end
    if HOUSING_EDITOR_KEYBIND_PALETTE then
        HOUSING_EDITOR_KEYBIND_PALETTE:RemoveKeybinds()
    end
    if hud.exitKeybindButtonStripDescriptor and not exitRemoved then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(hud.exitKeybindButtonStripDescriptor)
        exitRemoved = true
    end
end

-- put the editor's Exit button back (the editor only adds it when its screen
-- opens, so after Placer mode we have to)
local function RestoreExitButton()
    if not exitRemoved then return end
    local exitGroup = HOUSING_EDITOR_SHARED.exitKeybindButtonStripDescriptor
    if EditorHudShowing() then
        KEYBIND_STRIP:AddKeybindButtonGroup(exitGroup)
        exitRemoved = false
    elseif not InEditor() then
        exitRemoved = false -- editor closed; it re-adds Exit itself next time
    end
end

local function RefreshEditorButtons()
    local showing = EditorHudShowing()
    if placerMode and not (showing and InSelectionMode()) then
        -- the editor moved on (picked something up, browsing, closed):
        -- step out of Placer mode quietly
        if not InEditor() or (showing and not InSelectionMode()) then
            placerMode = false
        end
    end

    if placerMode and showing then
        HideEditorButtons()
        if enterAdded then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(enterKeybindGroup)
            enterAdded = false
        end
        if not placerAdded then
            KEYBIND_STRIP:AddKeybindButtonGroup(placerKeybindGroup)
            placerAdded = true
        else
            KEYBIND_STRIP:UpdateKeybindButtonGroup(placerKeybindGroup)
        end
        ShowList(true)
    else
        if placerAdded then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(placerKeybindGroup)
            placerAdded = false
        end
        if listPanel then listPanel:SetHidden(true) end
        RestoreExitButton()
        local wanted = showing and InSelectionMode()
        if wanted and not enterAdded then
            KEYBIND_STRIP:AddKeybindButtonGroup(enterKeybindGroup)
            enterAdded = true
        elseif not wanted and enterAdded then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(enterKeybindGroup)
            enterAdded = false
        end
    end
    UpdateStatusPanel()
end

EnterPlacerMode = function()
    if not (EditorHudShowing() and InSelectionMode()) then
        Notify(false, "Open the Housing Editor first", "Placer mode works while you're aiming at items")
        return
    end
    placerMode = true
    if inspectPanel then inspectPanel:SetHidden(true) end
    HOUSING_EDITOR_SHARED:UpdateKeybinds() -- our hook swaps the buttons
end

LeavePlacerMode = function()
    placerMode = false
    if listPanel then listPanel:SetHidden(true) end
    if inspectPanel then inspectPanel:SetHidden(true) end
    HOUSING_EDITOR_SHARED:UpdateKeybinds()
end

FB.EnterPlacerMode = function() EnterPlacerMode() end
FB.LeavePlacerMode = function() LeavePlacerMode() end
FB.IsPlacerMode = function() return placerMode end

SLASH_COMMANDS["/fbmenu"] = function()
    if placerMode then LeavePlacerMode() else EnterPlacerMode() end
end
SLASH_COMMANDS["/fbhelp"] = SLASH_COMMANDS["/fbmenu"]

local function InstallEditorButtons()
    if HOUSING_EDITOR_SHARED and HOUSING_EDITOR_SHARED.UpdateKeybinds then
        ZO_PreHook(HOUSING_EDITOR_SHARED, "UpdateKeybinds", function()
            RemoveOurButtons()
        end)
        ZO_PostHook(HOUSING_EDITOR_SHARED, "UpdateKeybinds", function()
            RefreshEditorButtons()
        end)
    end
    if HOUSING_EDITOR_HUD_SCENE then
        HOUSING_EDITOR_HUD_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWN or newState == SCENE_HIDDEN then
                RefreshEditorButtons()
            end
        end)
    end
    EVENT_MANAGER:RegisterForEvent(FB.name, EVENT_HOUSING_EDITOR_MODE_CHANGED, function()
        zo_callLater(RefreshEditorButtons, 50)
    end)
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

local function OnAddOnLoaded(_, addonName)
    if addonName ~= FB.name then return end
    EVENT_MANAGER:UnregisterForEvent(FB.name, EVENT_ADD_ON_LOADED)
    FB.SavedVars = ZO_SavedVars:NewAccountWide("FurnitureBuilder_SavedVars", 1, nil, {
        spaceCount = 5,
        snapIncrement = 0.5,
        showStatus = true,
        stepTweak = 0,
    })
    InstallEditorButtons()
end

EVENT_MANAGER:RegisterForEvent(FB.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
