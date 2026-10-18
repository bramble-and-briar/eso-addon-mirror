-- The countdown on screen: a small list with each boss and the time until it respawns, soonest first. It shows on the
-- HUD only (not in menus), while there are timers and Show Countdown is on, and also while the Timer Settings page is
-- open, so players can see where it goes. It sits next to a part of the game's console HUD: at the top left, under the
-- group list; at the top right, under the quest tracker; or in the middle, above the player's buffs or health bar. It
-- moves with that part, and stays where it would be while it is hidden or missing. Or it sits wherever the player
-- puts it.
-- Each row starts with the map's world boss pin and, for a boss in a delve, a group delve or a public dungeon, that
-- place's map pin. The times sit just after the longest name, and the window is only as wide as its rows, so next to a
-- part of the HUD it stays close to it.

local addon = SlayansBossTimer
local Settings = addon.Settings
local Timers = addon.Timers

local Countdown = {}
addon.Countdown = Countdown

local ICON_GAP = 4 -- Between the two icons.
local NAME_GAP = 8 -- Between the icons and the name.
local TIME_GAP = 16 -- Between the longest name and the times.
local MAX_ROWS = 8
local TIME_COLOR = ZO_ColorDef:New("FFD54F") -- Harvest gold, from the add-on's fall colours.

-- The text sizes Font Size offers, in the order Timer Settings lists them, each with its name there (the owner, 18
-- October 2026). Each is one of the game's gamepad font sizes (fontstrings/western/defaultfontstrings_western.xml),
-- with the rows and icons in step; Medium is the first version's size. At Medium a row is 32 high, its icons 28 square,
-- and names longer than 300 end in "..."; the other sizes scale these with the text.
Countdown.FONT_SIZES = { "small", "medium", "large", "xLarge" }
Countdown.FONT_SIZE_NAMES = {
    small = SI_SBT_FONT_SIZE_SMALL,
    medium = SI_SBT_FONT_SIZE_MEDIUM,
    large = SI_SBT_FONT_SIZE_LARGE,
    xLarge = SI_SBT_FONT_SIZE_X_LARGE,
}
local FONT_HEIGHTS = { small = 22, medium = 27, large = 34, xLarge = 42 }
local MEDIUM_HEIGHT = FONT_HEIGHTS.medium

-- Returns a length at Medium scaled to a text height, rounded.
local function Scale(length, height)
    return zo_floor(length * height / MEDIUM_HEIGHT + 0.5)
end

-- Returns the countdown's measurements for a Font Size.
local layouts = {}
local function GetLayout(fontSize)
    local height = FONT_HEIGHTS[fontSize] or MEDIUM_HEIGHT
    local layout = layouts[height]
    if not layout then
        local iconSize = Scale(28, height)
        layout = {
            nameFont = string.format("$(GAMEPAD_MEDIUM_FONT)|$(GP_%d)|soft-shadow-thick", height),
            timeFont = string.format("$(GAMEPAD_BOLD_FONT)|$(GP_%d)|soft-shadow-thick", height),
            rowHeight = Scale(32, height),
            iconSize = iconSize,
            nameX = 2 * iconSize + ICON_GAP + NAME_GAP,
            maxNameWidth = Scale(300, height), -- Longer names end in "...".
            fallbackTimeWidth = Scale(80, height), -- Room for "10:00", if the game can't measure it.
        }
        layouts[height] = layout
    end
    return layout
end
Countdown.GetLayout = GetLayout

local function GetCurrentLayout()
    return GetLayout(Settings.Get("fontSize"))
end

-- The icons are the map's pins for places the player has finished, chosen by the owner (18 October 2026). The game
-- gives them to the map through GetPOIMapInfo, and the map that draws them (ingame/map/mappin.lua) is shared by the
-- keyboard and gamepad interfaces, so they exist on console.
Countdown.BOSS_ICON = "/esoui/art/icons/poi/poi_groupboss_complete.dds"
-- By the kind of place the boss died in (Detector.GetPlaceKind). A boss in the open world, or in a timer saved before
-- there were kinds, has the boss icon alone; its row keeps the gap, so the names line up.
Countdown.PLACE_ICONS = {
    delve = "/esoui/art/icons/poi/poi_delve_complete.dds",
    groupDelve = "/esoui/art/icons/poi/poi_groupdelve_complete.dds",
    publicDungeon = "/esoui/art/icons/poi/poi_dungeon_complete.dds",
    -- Inside, but not in a delve or public dungeon the game names, such as a quest's own cave.
    dungeon = "/esoui/art/icons/poi/poi_dungeon_complete.dds",
}

-- Each icon's drawn part, in pixels of its 64-pixel picture: left, top and the side of the square around it. The icons
-- leave different margins, so each is cut to its square and they all show the same size. Measured from UESP's copies
-- of the icons (esoicons.uesp.net), 18 October 2026.
Countdown.ICON_SQUARES = {
    ["/esoui/art/icons/poi/poi_groupboss_complete.dds"] = { 2, 2, 60 },
    ["/esoui/art/icons/poi/poi_delve_complete.dds"] = { 5, 6, 53 },
    ["/esoui/art/icons/poi/poi_groupdelve_complete.dds"] = { 6, 6, 53 },
    ["/esoui/art/icons/poi/poi_dungeon_complete.dds"] = { 7, 7.5, 50 },
}
local ICON_PIXELS = 64

-- Shows an icon cut to its drawn part.
local function SetIcon(texture, path)
    texture:SetTexture(path)
    local square = Countdown.ICON_SQUARES[path]
    if square then
        local left, top, side = square[1], square[2], square[3]
        texture:SetTextureCoords(left / ICON_PIXELS, (left + side) / ICON_PIXELS, top / ICON_PIXELS,
            (top + side) / ICON_PIXELS)
    else
        texture:SetTextureCoords(0, 1, 0, 1)
    end
end

-- The places in the order Timer Settings lists them, each with its name there (the owner, 18 October 2026). Top Right
-- and Custom keep the keys they had in the first version ("questTracker" and "free"), so players keep their choice.
Countdown.POSITIONS = { "topLeft", "questTracker", "center", "free" }
Countdown.POSITION_NAMES = {
    topLeft = SI_SBT_POSITION_TOP_LEFT,
    questTracker = SI_SBT_POSITION_TOP_RIGHT,
    center = SI_SBT_POSITION_CENTER,
    free = SI_SBT_POSITION_CUSTOM,
}

local HUD_GAP = 20 -- Between the countdown and the part of the HUD it goes under.
local CENTER_GAP = 10 -- Between the countdown and the buffs or health bar it goes above.
local SAME_ROW = 1 -- Group frames whose bottoms are this close sit in one row.

-- The lowest frame of the group list on screen (ingame/unitframes): the group's members and their companions, or the
-- player's own companion while not grouped. A big group's list has two columns, so of two frames side by side, the
-- one on the left.
local function FindLowestGroupFrame()
    if not (UNIT_FRAMES and UNIT_FRAMES.GetFrame) then
        return nil
    end
    local lowest, lowestBottom, lowestLeft
    local function Consider(unitTag)
        local unitFrame = unitTag and UNIT_FRAMES:GetFrame(unitTag)
        local control = unitFrame and unitFrame.frame
        if not control or control:IsHidden() then
            return
        end
        local bottom, left = control:GetBottom() or 0, control:GetLeft() or 0
        if not lowest or bottom > lowestBottom + SAME_ROW
                or (bottom >= lowestBottom - SAME_ROW and left < lowestLeft) then
            lowest, lowestBottom, lowestLeft = control, bottom, left
        end
    end
    Consider("companion")
    for index = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(index)
        Consider(unitTag)
        Consider(unitTag and GetCompanionUnitTagByGroupUnitTag(unitTag))
    end
    return lowest
end

-- The player's buffs and debuffs (ingame/buffdebuff), while any show. Each of their two rows of icons is hidden while
-- it is empty, and by default the rows show only in combat.
local function FindBuffs()
    local buffs = GetControl("ZO_BuffDebuffTopLevelSelfContainer")
    if not buffs or buffs:IsHidden() then
        return nil
    end
    for _, rowName in ipairs({ "Container1", "Container2" }) do
        local row = buffs:GetNamedChild(rowName)
        if row and not row:IsHidden() then
            return buffs
        end
    end
end

-- Where the countdown goes next to the game's console HUD. Each place lists the parts of the HUD it can go next to,
-- the first on screen winning: the countdown's point, the game's control (or a function that finds it) and its point,
-- and the offsets. Each control is from the game's shared or gamepad UI code, so it exists on console. The fallback is
-- where that part of the HUD sits in the gamepad interface, used while none is on screen.
local ANCHORS = {
    -- Under the group list, or where it starts while there is none (ZO_SmallGroupAnchorFrame, 70 across and 55 down).
    topLeft = {
        { point = TOPLEFT, target = FindLowestGroupFrame, relativePoint = BOTTOMLEFT, x = 0, y = HUD_GAP },
        { point = TOPLEFT, target = "ZO_SmallGroupAnchorFrame", relativePoint = TOPLEFT, x = 0, y = 0 },
        fallback = { point = TOPLEFT, relativePoint = TOPLEFT, x = 70, y = 55 },
    },
    -- Under the trackers' list (ingame/hud/hudtracker_manager.xml), which grows with the tracked quest.
    questTracker = {
        { point = TOPRIGHT, target = "ZO_HUDTrackersScrollContainerScrollChild", relativePoint = BOTTOMRIGHT, x = 0,
            y = HUD_GAP },
        fallback = { point = TOPRIGHT, relativePoint = TOPRIGHT, x = -15, y = 90 },
    },
    -- Above the buffs, or above the health bar (ingame/playerattributebars) while there are none, growing upwards. The
    -- health bar's top is about 149 above the bottom of the screen.
    center = {
        { point = BOTTOM, target = FindBuffs, relativePoint = TOP, x = 0, y = -CENTER_GAP },
        { point = BOTTOM, target = "ZO_PlayerAttributeHealth", relativePoint = TOP, x = 0, y = -CENTER_GAP },
        fallback = { point = BOTTOM, relativePoint = BOTTOM, x = 0, y = -149 - CENTER_GAP },
    },
}
Countdown.ANCHORS = ANCHORS

local window
local rows = {}
local hudScenes = {} -- Whether each HUD scene is showing.
local previewing = false
local currentAnchor -- What the window is anchored to now, so it is only anchored again when that changes.

---------------------------------------------------------------------------------------------------
-- Placing the countdown
---------------------------------------------------------------------------------------------------

-- Returns the chosen place, or the default for a place this version doesn't offer, such as the first version's
-- "Beside the Skill Bar" and "Beside the Chat Window".
function Countdown.GetPosition()
    local position = Settings.Get("countdownPosition")
    if position == "free" or ANCHORS[position] then
        return position
    end
    return Settings.DEFAULTS.countdownPosition
end

local function FindTarget(target)
    if type(target) == "function" then
        return target()
    end
    return GetControl(target)
end

-- Returns where the countdown goes now: its point, the control, the control's point and the offsets.
function Countdown.GetAnchor()
    local spec = ANCHORS[Countdown.GetPosition()]
    if not spec then
        -- Custom: a share of the space the countdown can move in, from the left and from the top, so it stays on the
        -- screen however wide it is, and even the longest list fits.
        local x = zo_clamp(Settings.Get("countdownX") or 0, 0, 100) / 100
        local y = zo_clamp(Settings.Get("countdownY") or 0, 0, 100) / 100
        local width, height = GuiRoot:GetWidth() or 0, GuiRoot:GetHeight() or 0
        local ownWidth = window and window:GetWidth() or 0
        return TOPLEFT, GuiRoot, TOPLEFT, zo_floor(x * zo_max(0, width - ownWidth)),
            zo_floor(y * zo_max(0, height - MAX_ROWS * GetCurrentLayout().rowHeight))
    end
    for _, anchor in ipairs(spec) do
        local target = FindTarget(anchor.target)
        if target and not target:IsHidden() then
            return anchor.point, target, anchor.relativePoint, anchor.x, anchor.y
        end
    end
    local fallback = spec.fallback
    return fallback.point, GuiRoot, fallback.relativePoint, fallback.x, fallback.y
end

local function ApplyAnchor()
    local point, relativeTo, relativePoint, offsetX, offsetY = Countdown.GetAnchor()
    local key = string.format("%s %s %s %s %s", tostring(point), tostring(relativeTo), tostring(relativePoint),
        tostring(offsetX), tostring(offsetY))
    if key ~= currentAnchor then
        currentAnchor = key
        window:ClearAnchors()
        window:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
    end
end

---------------------------------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------------------------------

local function AddLabel(name, alignment)
    local label = WINDOW_MANAGER:CreateControl(name, window, CT_LABEL)
    label:SetHorizontalAlignment(alignment)
    label:SetMaxLineCount(1)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return label
end

local function PlaceIcon(icon, size, x, middle)
    icon:SetDimensions(size, size)
    icon:ClearAnchors()
    icon:SetAnchor(LEFT, window, TOPLEFT, x, middle)
end

-- Sizes and places a row's parts for a layout. Everything is centred on the row's middle, so the icons line up with
-- the text.
local function LayOutRow(row, index, layout)
    local middle = (index - 1) * layout.rowHeight + layout.rowHeight / 2
    PlaceIcon(row.boss, layout.iconSize, 0, middle)
    PlaceIcon(row.place, layout.iconSize, layout.iconSize + ICON_GAP, middle)
    row.name:SetFont(layout.nameFont)
    row.name:ClearAnchors()
    row.name:SetAnchor(LEFT, window, TOPLEFT, layout.nameX, middle)
    row.time:SetFont(layout.timeFont)
end

-- Each row: the boss icon, the place icon, the name, and the time just after the name column.
local function GetRow(index, layout)
    local row = rows[index]
    if not row then
        local name = window:GetName() .. "Row" .. index
        row = {
            boss = WINDOW_MANAGER:CreateControl(name .. "Boss", window, CT_TEXTURE),
            place = WINDOW_MANAGER:CreateControl(name .. "Place", window, CT_TEXTURE),
            name = AddLabel(name .. "Name", TEXT_ALIGN_LEFT),
            time = AddLabel(name .. "Time", TEXT_ALIGN_RIGHT),
        }
        SetIcon(row.boss, Countdown.BOSS_ICON)
        row.name:SetColor(ZO_WHITE:UnpackRGBA())
        row.time:SetColor(TIME_COLOR:UnpackRGBA())
        row.time:SetAnchor(LEFT, row.name, RIGHT, TIME_GAP, 0)
        LayOutRow(row, index, layout)
        rows[index] = row
    end
    return row
end

local function SetRowHidden(row, hidden)
    row.boss:SetHidden(hidden)
    row.place:SetHidden(hidden or row.placeIcon == nil)
    row.name:SetHidden(hidden)
    row.time:SetHidden(hidden)
end

local function SetPlaceIcon(row, kind)
    local icon = Countdown.PLACE_ICONS[kind]
    if icon ~= row.placeIcon then
        row.placeIcon = icon
        if icon then
            SetIcon(row.place, icon)
        end
    end
end

-- Hidden labels, one per font, that measure text without a width to cut it short. A little extra keeps the text whole
-- after rounding, and if the game measures nothing, the fallback width is used instead.
local TEXT_SLACK = 2
local measures = {}
local measureCount = 0
local function MeasureText(font, text, fallback)
    local label = measures[font]
    if not label then
        measureCount = measureCount + 1
        label = WINDOW_MANAGER:CreateControl(window:GetName() .. "Measure" .. measureCount, window, CT_LABEL)
        label:SetFont(font)
        label:SetMaxLineCount(1)
        label:SetHidden(true)
        measures[font] = label
    end
    label:SetText(text)
    local width = label:GetTextWidth() or 0
    return width > 0 and zo_ceil(width) + TEXT_SLACK or fallback
end

local function GetWindow()
    if not window then
        window = WINDOW_MANAGER:CreateTopLevelWindow("SlayansBossTimerCountdown")
        window:SetHidden(true)
        window:SetMouseEnabled(false)
        local layout = GetCurrentLayout()
        window:SetDimensions(layout.nameX, layout.rowHeight)
    end
    return window
end

-- Returns the lines to show: each timer's boss names, kind of place and seconds left, or while placing the countdown
-- with no timers, an example line.
local function GetLines()
    local now = GetTimeStamp()
    local lines = {}
    for _, timer in ipairs(Timers.GetAll()) do
        table.insert(lines, { name = timer.name, kind = timer.kind, seconds = timer.respawnAt - now })
    end
    if previewing and #lines == 0 then
        table.insert(lines, { name = GetString(SI_SBT_COUNTDOWN_EXAMPLE), kind = "overland",
            seconds = Timers.DEFAULT_RESPAWN_SECONDS })
    end
    return lines
end

-- Whether the countdown is on screen: on the HUD while there are timers, and while placing it in the settings.
function Countdown.IsShown()
    return window ~= nil and not window:IsControlHidden()
end

-- Draws the list again: called once a second while there are timers, and whenever a timer, a setting or the screen
-- changes.
local rowsLayout -- The layout the rows were last sized for.

function Countdown.Refresh()
    GetWindow()
    local layout = GetCurrentLayout()
    if layout ~= rowsLayout then
        rowsLayout = layout
        for index, row in ipairs(rows) do
            LayOutRow(row, index, layout)
        end
    end
    local lines = GetLines()
    local count = zo_min(#lines, MAX_ROWS)
    -- The name column is as wide as the longest name, and the time column as wide as the longest time with every
    -- digit a 0, so the times don't shift as their digits change.
    local nameWidth, timeWidth = 0, 0
    for index = 1, count do
        local line = lines[index]
        local time = Timers.FormatTime(line.seconds)
        local row = GetRow(index, layout)
        row.name:SetText(line.name)
        row.time:SetText(time)
        SetPlaceIcon(row, line.kind)
        SetRowHidden(row, false)
        nameWidth = zo_max(nameWidth, MeasureText(layout.nameFont, line.name, layout.maxNameWidth))
        timeWidth = zo_max(timeWidth, MeasureText(layout.timeFont, (time:gsub("%d", "0")), layout.fallbackTimeWidth))
    end
    nameWidth = zo_min(nameWidth, layout.maxNameWidth)
    for index = 1, count do
        rows[index].name:SetWidth(nameWidth)
        rows[index].time:SetWidth(timeWidth)
    end
    for index = count + 1, #rows do
        SetRowHidden(rows[index], true)
    end
    window:SetDimensions(layout.nameX + nameWidth + TIME_GAP + timeWidth, zo_max(1, count) * layout.rowHeight)
    ApplyAnchor()
    local onHUD = hudScenes[HUD_SCENE] or hudScenes[HUD_UI_SCENE]
    local show = Settings.Get("showCountdown") and count > 0 and (previewing or onHUD)
    window:SetHidden(not show)
end

-- Shows the countdown while the Timer Settings page is open, with an example line if no timer is running.
function Countdown.SetPreview(on)
    on = on == true
    if previewing ~= on then
        previewing = on
        Countdown.Refresh()
    end
end

function Countdown.IsPreviewing()
    return previewing
end

local function WatchScene(scene)
    if scene then
        scene:RegisterCallback("StateChange", function(_, newState)
            hudScenes[scene] = newState == SCENE_SHOWING or newState == SCENE_SHOWN
            Countdown.Refresh()
        end)
    end
end

function Countdown.Initialize()
    GetWindow()
    -- The HUD while playing, and the HUD with the cursor (HUD_UI_SCENE); the countdown hides with them in menus.
    WatchScene(HUD_SCENE)
    WatchScene(HUD_UI_SCENE)
    Countdown.Refresh()
end
