---------------------------------------------------------------------------
-- GroupFrames.lua - the frames themselves
--
-- Builds one frame per group member and keeps it up to date. This file owns
-- everything that is drawn; the other files only supply data or settings:
--
--   Buffs.lua     which effects count as tracked, and the user's own list
--   Share.lua     sending/receiving that list through LibGroupBroadcast
--   Stats.lua     ultimate, DPS/HPS and front/back bar of each member
--   Settings.lua  the options menu (LibAddonMenu on PC, LibHarvens on console)
--
-- How it works: the frames are plain controls created in Lua (no XML). A
-- timer (OnTick) runs ten times a second, works out who is in the group,
-- and refreshes each frame by polling the game and the libraries. The only
-- event that matters is EVENT_EFFECT_CHANGED, which marks a member's buffs
-- as needing a rescan.
--
-- A "frame" is a Lua table holding its controls and current state:
--   control      the frame's container control
--   unitTag      who it shows right now ("group3", "player") or nil if unused
--   icons        buff icon controls, created on demand
--   buffs        the tracked effects currently on the member (sorted)
--   forceRefresh set when everything must be redrawn (layout or member changed)
---------------------------------------------------------------------------

GroupFrames = GroupFrames or {}
local GF = GroupFrames

GF.name = "GroupFrames" -- must match the folder / manifest name
GF.version = "1.2.0" -- shown in the settings; keep in step with the manifest

local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER

local MAX_FRAMES = 12 -- largest group (a trial)
local PAD = 5 -- space between the frame border and its contents
local NAME_HEIGHT = 20 -- height of the name row
local ROLE_ICON_SIZE = 18
local LEADER_ICON_SIZE = 16
local FRAME_SPACING = 6 -- gap between neighbouring frames
local TICK_MS = 100 -- how often OnTick runs

-- Built-in game textures.
local LEADER_ICON = "EsoUI/Art/UnitFrames/groupIcon_leader.dds"
local ROLE_ICONS = {
    [LFG_ROLE_TANK] = "EsoUI/Art/LFG/LFG_icon_tank.dds",
    [LFG_ROLE_HEAL] = "EsoUI/Art/LFG/LFG_icon_healer.dds",
    [LFG_ROLE_DPS] = "EsoUI/Art/LFG/LFG_icon_dps.dds",
}

-- { dark end (left), bright end (right) } of each bar's gradient
local BAR_COLORS = {
    health = { { 0.48, 0.05, 0.07 }, { 0.90, 0.20, 0.18 } },
    magicka = { { 0.08, 0.22, 0.62 }, { 0.30, 0.62, 1.00 } },
    stamina = { { 0.10, 0.42, 0.12 }, { 0.45, 0.88, 0.32 } },
    ult = { { 0.50, 0.34, 0.05 }, { 0.92, 0.72, 0.22 } },
    ultReady = { { 1.00, 0.72, 0.10 }, { 1.00, 0.97, 0.60 } },
}

local STATS_HEIGHT = 15 -- height of the FRONT/BACK + DPS/HPS text line
local COLOR_FRONT_BAR = "7fd3ff" -- text colours (hex) of the weapon bar label
local COLOR_BACK_BAR = "ffa64d"

-- Frame border: gold for your own frame, black for everyone else.
local COLOR_SELF_EDGE = { 0.90, 0.74, 0.32, 0.95 }
local COLOR_EDGE = { 0, 0, 0, 0.9 }

-- Default settings. ZO_SavedVars copies these into GF.sv for every key the
-- player has not changed, so GF.sv always has a value for each of them.
GF.defaults = {
    -- position and layout
    left = 40, -- top-left corner of the frames on screen
    top = 300,
    locked = true, -- false = draggable with the mouse (PC)
    scale = 1,
    width = 200, -- width of one frame before adaptive shrinking
    orientation = "vertical", -- "vertical" stacks downwards, "horizontal" sideways
    wrapAfter = 6, -- frames per column/row (12 players = 6 left, 6 right), 0 = auto wrap at the screen edge
    balanceWrap = true, -- split wrapped members evenly (4 + 4 instead of 6 + 2)
    adaptiveSize = true, -- shrink the frames in large groups...
    compactAbove = 4, -- ...once there are more members than this...
    compactFactor = 0.8, -- ...to this fraction of their normal size
    showSolo = false, -- show your own frame while not grouped
    replaceDefault = true, -- hide the game's own group frames
    sortMode = "default", -- order of the buff icons, see SORT_MODES
    useDisplayName = false, -- @account names instead of character names

    -- appearance
    bgAlpha = 0.6,
    showRoleIcons = true,
    highlightSelf = true,
    smoothBars = true,
    showShields = true,

    -- what each frame shows
    showHealth = true,
    showMagicka = true,
    showStamina = true,
    showHealthText = true,
    showUlt = true,
    showDps = true,
    showHps = true,
    showBar = true, -- FRONT / BACK weapon bar label
    shareBar = true, -- tell groupmates which bar you are on
    ultHeight = 18,
    healthHeight = 18,
    resourceHeight = 6, -- magicka and stamina bars

    -- buffs
    showBuffs = true,
    trackMajor = true, -- master switches for the two lists in sv.buffs
    trackMinor = true,
    trackOtherMajorMinor = false, -- Major/Minor buffs missing from the lists
    trackDebuffs = false, -- Major/Minor debuffs
    trackedEffects = {}, -- user-added effects, see Buffs.lua
    blacklist = {}, -- effects never shown, same keys as trackedEffects
    effectIds = {}, -- lower-case effect name -> an ability id with that name (for sharing)
    autoAcceptShared = false, -- add effects groupmates share without asking
    buffs = {}, -- "Major Resolve" -> true/false, filled from Buffs.lua below
    iconSize = 24,
    maxIcons = 7,
    showTimers = true,
}

-- Every known Major and Minor buff is tracked until the player unticks it.
for _, name in ipairs(GF.MAJOR_BUFFS) do GF.defaults.buffs[name] = true end
for _, name in ipairs(GF.MINOR_BUFFS) do GF.defaults.buffs[name] = true end

local frames = {} -- [1..MAX_FRAMES], all created up front and reused
local dirtyBuffs = {} -- unitTag -> true: buffs changed since the last tick
local groupResources -- LibGroupResources handler api, nil when not installed
local root -- top level window: position, scale, dragging, HUD visibility
local container -- child of root that the frames are anchored to

---------------------------------------------------------------------------
-- Control creation
--
-- Everything is layered with draw levels (higher is on top):
--   0 frame background   1 bar/icon backgrounds   2 bar fills and icons
--   3 shield overlay, names and icon texts        4 bar gloss   5 bar texts
---------------------------------------------------------------------------

-- Creates a white, vertically centred label that truncates with "...".
local function CreateLabel(name, parent, font)
    local label = WM:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font)
    label:SetColor(1, 1, 1, 1)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

-- A bar is: a dark inset with a 1px black rim, a gradient fill and a soft
-- highlight over the top half that gives it a glossy look.
-- `colors` is one entry of BAR_COLORS. The returned status bar carries two
-- extra fields: `bg` (its background, hidden together with it) and `noData`
-- (true while there is nothing to show, see SetBar).
local function CreateBar(name, parent, colors)
    local dark, bright = colors[1], colors[2]

    local bg = WM:CreateControl(name .. "BG", parent, CT_BACKDROP)
    bg:SetCenterColor(dark[1] * 0.3, dark[2] * 0.3, dark[3] * 0.3, 0.9)
    bg:SetEdgeColor(0, 0, 0, 1)
    bg:SetEdgeTexture("", 1, 1, 1)
    bg:SetDrawLevel(1)

    local bar = WM:CreateControl(name, parent, CT_STATUSBAR)
    bar:SetGradientColors(dark[1], dark[2], dark[3], 1, bright[1], bright[2], bright[3], 1)
    bar:SetMinMax(0, 1)
    bar:SetValue(0)
    bar:SetDrawLevel(2)

    bg:SetAnchor(TOPLEFT, bar, TOPLEFT, -1, -1)
    bg:SetAnchor(BOTTOMRIGHT, bar, BOTTOMRIGHT, 1, 1)

    local gloss = WM:CreateControl(name .. "Gloss", bar, CT_TEXTURE)
    gloss:SetColor(1, 1, 1, 0.12)
    gloss:SetAnchor(TOPLEFT, bar, TOPLEFT, 0, 0)
    gloss:SetAnchor(BOTTOMRIGHT, bar, RIGHT, 0, 0)
    gloss:SetDrawLevel(4)

    bar.bg = bg
    bar.noData = true
    return bar
end

-- Shows or hides a bar together with its background.
local function SetBarShown(bar, shown)
    bar:SetHidden(not shown)
    bar.bg:SetHidden(not shown)
end

-- Creates the index-th buff icon of a frame: a bordered ability icon with
-- the remaining time at the bottom and the stack count in the top right.
-- Icons are only created when a frame first needs that many.
local function CreateIcon(frame, index)
    local name = frame.control:GetName() .. "Buff" .. index
    local icon = WM:CreateControl(name, frame.control, CT_CONTROL)

    icon.border = WM:CreateControl(name .. "Border", icon, CT_BACKDROP)
    icon.border:SetAnchorFill(icon)
    icon.border:SetCenterColor(0, 0, 0, 1)
    icon.border:SetEdgeColor(0, 0, 0, 1)
    icon.border:SetEdgeTexture("", 1, 1, 1)
    icon.border:SetDrawLevel(1)

    icon.texture = WM:CreateControl(name .. "Texture", icon, CT_TEXTURE)
    icon.texture:SetAnchor(TOPLEFT, icon, TOPLEFT, 1, 1)
    icon.texture:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT, -1, -1)
    -- trim the frame that is baked into ability icons
    icon.texture:SetTextureCoords(0.07, 0.93, 0.07, 0.93)
    icon.texture:SetDrawLevel(2)

    icon.timer = CreateLabel(name .. "Timer", icon, "$(BOLD_FONT)|$(KB_13)|soft-shadow-thick")
    icon.timer:SetAnchor(BOTTOM, icon, BOTTOM, 0, 4)
    icon.timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    icon.timer:SetDrawLevel(3)

    icon.stacks = CreateLabel(name .. "Stacks", icon, "$(BOLD_FONT)|$(KB_12)|soft-shadow-thick")
    icon.stacks:SetAnchor(TOPRIGHT, icon, TOPRIGHT, 1, -4)
    icon.stacks:SetColor(1, 0.9, 0.5, 1)
    icon.stacks:SetDrawLevel(3)

    frame.icons[index] = icon
    return icon
end

-- Creates all controls of one frame. Only what never changes is set here;
-- sizes and positions are applied later by LayoutFrame, because they depend
-- on the settings and on the group size.
local function CreateFrame(index)
    local name = "GroupFramesUnit" .. index
    local control = WM:CreateControl(name, container, CT_CONTROL)

    local frame = { control = control, icons = {}, buffs = {}, index = index }

    -- dark panel behind everything, with the 1px border
    frame.bg = WM:CreateControl(name .. "BG", control, CT_BACKDROP)
    frame.bg:SetAnchorFill(control)
    frame.bg:SetEdgeTexture("", 1, 1, 1)
    frame.bg:SetDrawLevel(0)

    -- name row: role (or class) icon, name, leader crown
    frame.role = WM:CreateControl(name .. "Role", control, CT_TEXTURE)
    frame.role:SetDimensions(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
    frame.role:SetAnchor(TOPLEFT, control, TOPLEFT, PAD - 1, PAD - 1)
    frame.role:SetDrawLevel(3)

    frame.leader = WM:CreateControl(name .. "Leader", control, CT_TEXTURE)
    frame.leader:SetDimensions(LEADER_ICON_SIZE, LEADER_ICON_SIZE)
    frame.leader:SetAnchor(TOPRIGHT, control, TOPRIGHT, -PAD, PAD)
    frame.leader:SetTexture(LEADER_ICON)
    frame.leader:SetColor(1, 0.85, 0.4, 1)
    frame.leader:SetDrawLevel(3)
    frame.leader:SetHidden(true)

    frame.name = CreateLabel(name .. "Name", control, "$(BOLD_FONT)|$(KB_16)|soft-shadow-thick")
    frame.name:SetDrawLevel(3)

    frame.health = CreateBar(name .. "Health", control, BAR_COLORS.health)

    -- translucent pale blue bar on top of the health bar for damage shields
    frame.shield = WM:CreateControl(name .. "Shield", control, CT_STATUSBAR)
    frame.shield:SetAnchorFill(frame.health)
    frame.shield:SetGradientColors(0.55, 0.75, 1, 0.35, 0.9, 0.97, 1, 0.6)
    frame.shield:SetMinMax(0, 1)
    frame.shield:SetValue(0)
    frame.shield:SetDrawLevel(3)
    frame.shield:SetHidden(true)

    -- "87%", "Dead" or "Offline" in the middle of the health bar
    frame.healthText =CreateLabel(name .. "HealthText", control, "$(BOLD_FONT)|$(KB_14)|soft-shadow-thick")
    frame.healthText:SetAnchor(CENTER, frame.health, CENTER, 0, 0)
    frame.healthText:SetDrawLevel(5)

    frame.magicka = CreateBar(name .. "Magicka", control, BAR_COLORS.magicka)
    frame.stamina = CreateBar(name .. "Stamina", control, BAR_COLORS.stamina)
    frame.ult = CreateBar(name .. "Ult", control, BAR_COLORS.ult)

    -- icon of the current ultimate, sitting at the left end of the ult bar
    frame.ultIconBg = WM:CreateControl(name .. "UltIconBG", control, CT_BACKDROP)
    frame.ultIconBg:SetCenterColor(0, 0, 0, 0.9)
    frame.ultIconBg:SetEdgeColor(0, 0, 0, 1)
    frame.ultIconBg:SetEdgeTexture("", 1, 1, 1)
    frame.ultIconBg:SetDrawLevel(1)
    frame.ultIcon = WM:CreateControl(name .. "UltIcon", control, CT_TEXTURE)
    frame.ultIcon:SetAnchor(TOPLEFT, frame.ultIconBg, TOPLEFT, 1, 1)
    frame.ultIcon:SetAnchor(BOTTOMRIGHT, frame.ultIconBg, BOTTOMRIGHT, -1, -1)
    frame.ultIcon:SetTextureCoords(0.07, 0.93, 0.07, 0.93)
    frame.ultIcon:SetDrawLevel(2)

    -- "current / needed" ultimate points in the middle of the ult bar
    frame.ultText =CreateLabel(name .. "UltText", control, "$(BOLD_FONT)|$(KB_13)|soft-shadow-thick")
    frame.ultText:SetAnchor(CENTER, frame.ult, CENTER, 0, 0)
    frame.ultText:SetDrawLevel(5)

    -- line below the bars: weapon bar on the left, DPS / HPS on the right
    frame.barLabel = CreateLabel(name .. "Bar", control, "$(BOLD_FONT)|$(KB_13)|soft-shadow-thick")
    frame.barLabel:SetDrawLevel(3)
    frame.stats = CreateLabel(name .. "Stats", control, "$(BOLD_FONT)|$(KB_13)|soft-shadow-thick")
    frame.stats:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    frame.stats:SetDrawLevel(3)

    frames[index] = frame
    return frame
end

---------------------------------------------------------------------------
-- Layout
--
-- Two steps: LayoutFrame sizes one frame and stacks its rows from top to
-- bottom, Arrange places the frames next to each other and wraps them.
-- Both run again whenever a setting or the group size changes.
---------------------------------------------------------------------------

-- Effective sizes for the current group size (see UpdateMetrics).
local metrics = { width = 200, healthHeight = 18, resourceHeight = 6, ultHeight = 18, iconSize = 24 }
local lastCount = 1 -- number of members the frames are currently laid out for

-- Adaptive size: shrink the frames once the group is larger than the
-- configured threshold so a full trial group still fits comfortably.
local function UpdateMetrics(count)
    local sv = GF.sv
    local factor = (sv.adaptiveSize and count > sv.compactAbove) and sv.compactFactor or 1
    metrics.width = zo_floor(sv.width * factor)
    metrics.healthHeight = zo_max(6, zo_floor(sv.healthHeight * factor))
    metrics.resourceHeight = sv.resourceHeight
    metrics.ultHeight = zo_max(10, zo_floor(sv.ultHeight * factor))
    metrics.iconSize = zo_max(12, zo_floor(sv.iconSize * factor))
end

-- Positions the rows of one frame and returns the frame's height. `y` is
-- the running top offset: each visible row is placed at y and then moves y
-- down by its own height, so hidden rows simply take no space.
-- Row order: name, health, magicka, stamina, ultimate, stats line, buffs.
local function LayoutFrame(frame)
    local sv = GF.sv
    local control = frame.control
    local width = metrics.width
    local inner = width - PAD * 2 -- usable width inside the padding
    local y = PAD

    frame.bg:SetCenterColor(0.04, 0.04, 0.06, sv.bgAlpha)

    -- the name row is anchored by UpdateHeader, which knows the icons
    frame.nameY = y
    y = y + NAME_HEIGHT + 2

    -- places a full-width bar at the current y, or hides it
    local function Place(bar, shown, height)
        SetBarShown(bar, shown)
        if shown then
            bar:ClearAnchors()
            bar:SetAnchor(TOPLEFT, control, TOPLEFT, PAD, y)
            bar:SetDimensions(inner, height)
            y = y + height + 3
        end
    end

    Place(frame.health, sv.showHealth, metrics.healthHeight)
    Place(frame.magicka, sv.showMagicka, metrics.resourceHeight)
    Place(frame.stamina, sv.showStamina, metrics.resourceHeight)
    -- ult row: square ability icon, then the bar
    SetBarShown(frame.ult, sv.showUlt)
    frame.ultIconBg:SetHidden(not sv.showUlt)
    frame.ultIcon:SetHidden(not sv.showUlt)
    frame.ultText:SetHidden(not sv.showUlt)
    if sv.showUlt then
        local size = metrics.ultHeight
        frame.ultIconBg:ClearAnchors()
        frame.ultIconBg:SetAnchor(TOPLEFT, control, TOPLEFT, PAD - 1, y - 1)
        frame.ultIconBg:SetDimensions(size + 2, size + 2)
        frame.ult:ClearAnchors()
        frame.ult:SetAnchor(TOPLEFT, control, TOPLEFT, PAD + size + 4, y)
        frame.ult:SetDimensions(inner - size - 4, size)
        y = y + size + 3
    end

    -- stats line: weapon bar label on the left, DPS / HPS right-aligned
    local showStats = sv.showDps or sv.showHps or sv.showBar
    frame.barLabel:SetHidden(not showStats)
    frame.stats:SetHidden(not showStats)
    if showStats then
        local barWidth = 44
        frame.barLabel:ClearAnchors()
        frame.barLabel:SetAnchor(TOPLEFT, control, TOPLEFT, PAD, y - 1)
        frame.barLabel:SetDimensions(barWidth, STATS_HEIGHT)
        frame.stats:ClearAnchors()
        frame.stats:SetAnchor(TOPLEFT, control, TOPLEFT, PAD + barWidth, y - 1)
        frame.stats:SetDimensions(inner - barWidth, STATS_HEIGHT)
        y = y + STATS_HEIGHT + 1
    end
    frame.healthText:SetHidden(not (sv.showHealth and sv.showHealthText))
    if not (sv.showHealth and sv.showShields) then
        frame.shield:SetHidden(true)
    end

    -- buff icons are positioned by ScanBuffs; only reserve their row here
    frame.buffY = y + 1
    if sv.showBuffs then
        y = y + metrics.iconSize + 6
    end

    y = y + PAD - 3
    control:SetDimensions(width, y)
    return y
end

-- Sizes every frame for `count` members and arranges them. Frames stack in
-- the configured direction and wrap into a new column/row either after a
-- fixed number or, with auto wrap, when they would run off the screen.
local function Arrange(count)
    local sv = GF.sv
    count = zo_max(count, 1)
    UpdateMetrics(count)

    -- all frames get the same size, so the height of the last one will do
    local height = 0
    for i = 1, MAX_FRAMES do
        height = LayoutFrame(frames[i])
        frames[i].forceRefresh = true
    end
    local width = metrics.width
    local vertical = sv.orientation ~= "horizontal"

    -- A "line" is a column when vertical and a row when horizontal;
    -- perLine is how many frames go into one before the next is started.
    local perLine = sv.wrapAfter
    if perLine <= 0 then
        -- auto wrap: as many as fit between the anchor and the screen edge
        if vertical then
            local available = (GuiRoot:GetHeight() - sv.top) / sv.scale
            perLine = zo_floor((available + FRAME_SPACING) / (height + FRAME_SPACING))
        else
            local available = (GuiRoot:GetWidth() - sv.left) / sv.scale
            perLine = zo_floor((available + FRAME_SPACING) / (width + FRAME_SPACING))
        end
    end
    perLine = zo_clamp(perLine, 1, count)
    local lines = zo_ceil(count / perLine)
    if sv.balanceWrap then
        -- 12 members with room for 8 become 6 + 6 instead of 8 + 4
        perLine = zo_ceil(count / lines)
    end

    for i = 1, MAX_FRAMES do
        local line = zo_floor((i - 1) / perLine)
        local position = (i - 1) % perLine
        local column, row = line, position
        if not vertical then column, row = position, line end
        local control = frames[i].control
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, container, TOPLEFT,
            column * (width + FRAME_SPACING), row * (height + FRAME_SPACING))
    end

    -- shrink the window to what is used, so dragging and clamping to the
    -- screen work on the visible area only
    local columns, rows = lines, perLine
    if not vertical then columns, rows = perLine, lines end
    root:SetDimensions(columns * (width + FRAME_SPACING) - FRAME_SPACING,
        rows * (height + FRAME_SPACING) - FRAME_SPACING)
end

-- Applies every setting that affects how the frames look or where they are.
-- Called once at start-up and after each change in the settings menu.
function GF.ApplyLayout()
    local sv = GF.sv
    root:SetScale(sv.scale)
    root:ClearAnchors()
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.left, sv.top)
    root:SetMovable(not sv.locked)
    root:SetMouseEnabled(not sv.locked)
    GF.unlockHint:SetHidden(sv.locked)
    GF.unlockBg:SetHidden(sv.locked)
    GF.ApplyDefaultFrames()
    Arrange(lastCount)
end

-- Shows `count` copies of your own frame so the layout can be set up
-- without a group. Pass nil to turn the preview off.
function GF.SetPreview(count)
    GF.previewCount = count
end

---------------------------------------------------------------------------
-- Header (role icon, name, leader crown, frame border)
---------------------------------------------------------------------------

local getClassIcon = ZO_GetClassIcon or GetClassIcon

-- Returns the texture shown left of the name: the member's selected group
-- role, or their class icon when no role is set (e.g. while solo).
local function GetHeaderIcon(unitTag)
    if not GF.sv.showRoleIcons then return nil end
    local texture = ROLE_ICONS[GetGroupMemberSelectedRole(unitTag)]
    if not texture and getClassIcon then
        texture = getClassIcon(GetUnitClassId(unitTag))
    end
    return texture
end

-- Updates role icon, leader crown, name position and border colour. These
-- rarely change, so the work is skipped unless something actually differs
-- from last time (compared through `key`).
local function UpdateHeader(frame)
    local sv = GF.sv
    local unitTag = frame.unitTag
    local control = frame.control

    local texture = GetHeaderIcon(unitTag)
    local isLeader = IsUnitGroupLeader(unitTag)
    local isSelf = AreUnitsEqual(unitTag, "player")
    local key = (texture or "") .. (isLeader and "L" or "") .. (isSelf and "S" or "")
    if frame.headerKey == key and not frame.forceRefresh then return end
    frame.headerKey = key

    local nameLeft = PAD
    if texture then
        frame.role:SetTexture(texture)
        nameLeft = PAD + ROLE_ICON_SIZE + 3
    end
    frame.role:SetHidden(texture == nil)
    frame.leader:SetHidden(not isLeader)

    -- the name takes whatever width the icons on either side leave over
    local nameWidth = metrics.width - nameLeft - PAD - (isLeader and (LEADER_ICON_SIZE + 3) or 0)
    frame.name:ClearAnchors()
    frame.name:SetAnchor(TOPLEFT, control, TOPLEFT, nameLeft, frame.nameY)
    frame.name:SetDimensions(nameWidth, NAME_HEIGHT)

    local edge = (isSelf and sv.highlightSelf) and COLOR_SELF_EDGE or COLOR_EDGE
    frame.bg:SetEdgeColor(edge[1], edge[2], edge[3], edge[4])
    frame.isSelf = isSelf
end

---------------------------------------------------------------------------
-- Buffs
---------------------------------------------------------------------------

-- sortMode -> { entry field, descending }. Sorting by `ending` is the same
-- as sorting by remaining time. Permanent effects count as infinitely long.
local SORT_MODES = {
    remainingAsc = { "ending", false },
    remainingDesc = { "ending", true },
    durationAsc = { "duration", false },
    durationDesc = { "duration", true },
}

-- Comparison for table.sort. With a sort mode the chosen field decides;
-- ties, and the "default" mode, fall back to type (Major, Minor, added)
-- and then name, so the order never jumps around between scans.
local function SortBuffs(a, b)
    local mode = SORT_MODES[GF.sv.sortMode]
    if mode then
        local valueA, valueB = a[mode[1]], b[mode[1]]
        if valueA ~= valueB then
            if mode[2] then return valueA > valueB end
            return valueA < valueB
        end
    end
    if a.priority ~= b.priority then return a.priority < b.priority end
    return a.name < b.name
end

-- Hides (or restores) the game's own group and raid frames.
local function ApplyDefaultFrames()
    local default = ZO_UnitFramesGroups
    if default then default:SetHidden(GF.sv.replaceDefault) end
end
GF.ApplyDefaultFrames = ApplyDefaultFrames

-- Reads every effect on the frame's member, keeps the tracked ones and
-- shows them as icons. Also records each effect name it comes across so the
-- settings can offer it in the "effects seen" picker.
--   list    the tracked effects, in display order
--   byName  the same entries by name, to merge duplicates
local function ScanBuffs(frame)
    local sv = GF.sv
    local unitTag = frame.unitTag
    local list, byName = {}, {}

    if sv.showBuffs and unitTag then
        local seen = GF.GetSeenTable(unitTag)
        for i = 1, GetNumBuffs(unitTag) do
            local buffName, timeStarted, timeEnding, _, stackCount, iconFile, _, effectType, _, _, abilityId =
                GetUnitBuffInfo(unitTag, i)
            buffName = zo_strformat("<<1>>", buffName)
            if buffName ~= "" then
                seen[buffName] = abilityId
                GF.seenEffects[buffName] = abilityId
            end
            -- nil priority = not tracked (see GF.GetBuffPriority in Buffs.lua)
            local priority = GF.GetBuffPriority(buffName, abilityId, effectType)
            if priority then
                -- permanent effects report no (or a zero length) duration
                local ending = (timeEnding and timeEnding > timeStarted) and timeEnding or math.huge
                local duration = ending ~= math.huge and (timeEnding - timeStarted) or math.huge
                local existing = byName[buffName]
                if existing then
                    -- same buff from several sources: keep the longest one
                    if ending > existing.ending then
                        existing.ending = ending
                        existing.duration = duration
                    end
                    if stackCount > existing.stacks then existing.stacks = stackCount end
                else
                    local entry = {
                        name = buffName,
                        priority = priority,
                        ending = ending,
                        duration = duration,
                        stacks = stackCount or 0,
                        icon = iconFile,
                        isDebuff = effectType == BUFF_EFFECT_TYPE_DEBUFF,
                    }
                    byName[buffName] = entry
                    list[#list + 1] = entry
                end
            end
        end
        table.sort(list, SortBuffs)
    end

    frame.buffs = list
    if frame.isSelf then
        -- shown in the settings' Diagnostics section
        GF.selfBuffInfo = string.format("%d effects on you, %d tracked",
            (sv.showBuffs and unitTag) and GetNumBuffs(unitTag) or 0, #list)
    end

    -- never let the row spill past the frame
    local iconSize = metrics.iconSize
    local fit = zo_floor((metrics.width - PAD * 2 + 3) / (iconSize + 3))
    local shown = zo_min(#list, sv.maxIcons, fit)
    for i = 1, shown do
        local entry = list[i]
        local icon = frame.icons[i] or CreateIcon(frame, i)
        icon:ClearAnchors()
        icon:SetAnchor(TOPLEFT, frame.control, TOPLEFT, PAD + (i - 1) * (iconSize + 3), frame.buffY)
        icon:SetDimensions(iconSize, iconSize)
        icon.texture:SetTexture(entry.icon)
        icon:SetAlpha(1)
        icon:SetHidden(false)
        icon.entry = entry
        icon.stacks:SetText(entry.stacks > 1 and entry.stacks or "")
        if entry.isDebuff then
            icon.border:SetEdgeColor(0.85, 0.15, 0.15, 1)
        else
            icon.border:SetEdgeColor(0, 0, 0, 1)
        end
    end
    -- hide icons left over from a scan that had more effects
    for i = shown + 1, #frame.icons do
        frame.icons[i]:SetHidden(true)
        frame.icons[i].entry = nil
    end
    frame.shownIcons = shown
end

-- Updates the countdown on each visible icon; runs every tick, unlike
-- ScanBuffs. `now` is the game time in seconds, the same clock the effect
-- end times use. Returns true when an effect has run out, so the caller can
-- rescan and drop its icon.
local function UpdateTimers(frame, now)
    local showTimers = GF.sv.showTimers
    local expired = false
    for i = 1, frame.shownIcons or 0 do
        local icon = frame.icons[i]
        local entry = icon.entry
        local text = ""
        local alpha = 1
        if entry and entry.ending ~= math.huge then
            local remaining = entry.ending - now
            if remaining <= 0 then
                expired = true
            else
                if remaining < 3 then
                    -- pulse when about to run out
                    alpha = 0.55 + 0.45 * math.abs(math.sin(now * 5))
                    icon.timer:SetColor(1, 0.35, 0.3, 1)
                elseif remaining < 6 then
                    icon.timer:SetColor(1, 0.85, 0.3, 1)
                else
                    icon.timer:SetColor(1, 1, 1, 1)
                end
                if showTimers then
                    if remaining >= 60 then
                        text = zo_floor(remaining / 60) .. "m"
                    else
                        text = zo_ceil(remaining)
                    end
                end
            end
        end
        icon:SetAlpha(alpha)
        icon.timer:SetText(text)
    end
    return expired
end

---------------------------------------------------------------------------
-- Resources
---------------------------------------------------------------------------

-- Sets a bar to current/maximum. Called without values it empties and dims
-- the bar, which is how "no data for this member" is shown.
local function SetBar(bar, current, maximum)
    local smooth = GF.sv.smoothBars and ZO_StatusBar_SmoothTransition
    if current and maximum and maximum > 0 then
        current = zo_min(current, maximum)
        if smooth then
            -- snap instead of animating when the bar had no data before
            smooth(bar, current, maximum, bar.noData)
        else
            bar:SetMinMax(0, maximum)
            bar:SetValue(current)
        end
        bar.noData = false
        bar:SetAlpha(1)
    else
        -- no data (member does not run LibGroupResources / sharing disabled)
        if not bar.noData then
            if smooth then
                smooth(bar, 0, 1, true)
            else
                bar:SetMinMax(0, 1)
                bar:SetValue(0)
            end
            bar.noData = true
        end
        bar:SetAlpha(0.35)
    end
end

-- Returns current and maximum magicka or stamina of a unit. The game only
-- tells you your own, so for everyone else the values come from
-- LibGroupResources (nil when the member does not share them).
local function GetSharedResource(unitTag, powerType)
    if AreUnitsEqual(unitTag, "player") then
        local current, maximum = GetUnitPower("player", powerType)
        return current, maximum
    end
    if not groupResources then return nil end
    if powerType == COMBAT_MECHANIC_FLAGS_MAGICKA then
        return groupResources:GetMagicka(unitTag)
    end
    return groupResources:GetStamina(unitTag)
end

-- Shows the member's damage shield as an overlay on the health bar, on the
-- same scale as health (a shield worth half their health covers half).
local function UpdateShield(frame, unitTag, maximum, visible)
    local value
    if visible and GF.sv.showShields and maximum > 0 then
        value = GetUnitAttributeVisualizerEffectInfo(unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING,
            STAT_MITIGATION, ATTRIBUTE_HEALTH, COMBAT_MECHANIC_FLAGS_HEALTH)
    end
    if value and value > 0 then
        frame.shield:SetMinMax(0, maximum)
        frame.shield:SetValue(zo_min(value, maximum))
        frame.shield:SetHidden(false)
    else
        frame.shield:SetHidden(true)
    end
end

-- Refreshes everything on a frame that is a number: health, shield,
-- magicka, stamina, ultimate, weapon bar and DPS/HPS. Runs every tick.
-- Texts are only pushed to their labels when they actually changed.
local function UpdateResources(frame)
    local sv = GF.sv
    local unitTag = frame.unitTag
    local online = IsUnitOnline(unitTag)
    local dead = IsUnitDead(unitTag)

    -- health comes straight from the game for every group member
    if sv.showHealth then
        local current, maximum = GetUnitPower(unitTag, COMBAT_MECHANIC_FLAGS_HEALTH)
        if not online then
            SetBar(frame.health, nil)
            frame.healthText:SetText("Offline")
            frame.healthText:SetColor(0.7, 0.7, 0.7, 1)
        elseif dead then
            SetBar(frame.health, 0, zo_max(maximum, 1))
            frame.healthText:SetText("Dead")
            frame.healthText:SetColor(1, 0.35, 0.3, 1)
        else
            SetBar(frame.health, current, maximum)
            if maximum > 0 then
                local percent = current / maximum
                frame.healthText:SetText(zo_round(percent * 100) .. "%")
                if percent < 0.3 then
                    frame.healthText:SetColor(1, 0.8, 0.3, 1)
                else
                    frame.healthText:SetColor(1, 1, 1, 1)
                end
            else
                frame.healthText:SetText("")
            end
        end
        UpdateShield(frame, unitTag, maximum, online and not dead)
    end

    if sv.showMagicka then
        if online then
            SetBar(frame.magicka, GetSharedResource(unitTag, COMBAT_MECHANIC_FLAGS_MAGICKA))
        else
            SetBar(frame.magicka, nil)
        end
    end
    if sv.showStamina then
        if online then
            SetBar(frame.stamina, GetSharedResource(unitTag, COMBAT_MECHANIC_FLAGS_STAMINA))
        else
            SetBar(frame.stamina, nil)
        end
    end

    -- ultimate bar: fills towards the cost of the slotted ultimate and
    -- lights up once it can be cast
    local ultValue, ultCost, ultId
    if online then ultValue, ultCost, ultId = GF.GetUlt(unitTag) end
    if sv.showUlt then
        -- graphic of the current ultimate; swaps with the member's bar
        if ultId ~= frame.ultId or frame.forceRefresh then
            frame.ultId = ultId
            local texture = ultId and GetAbilityIcon(ultId)
            if texture and texture ~= "" then
                frame.ultIcon:SetTexture(texture)
                frame.ultIcon:SetHidden(false)
            else
                frame.ultIcon:SetHidden(true)
            end
        end

        -- "current / needed"
        local ultText = ""
        if ultValue then
            ultText = ultCost and (ultValue .. " / " .. ultCost) or tostring(ultValue)
        end
        if ultText ~= frame.ultTextValue then
            frame.ultTextValue = ultText
            frame.ultText:SetText(ultText)
        end

        if ultValue then
            local maximum = ultCost or 500
            SetBar(frame.ult, ultValue, maximum)
            local ready = ultCost ~= nil and ultValue >= ultCost
            if ready ~= frame.ultReady then
                frame.ultReady = ready
                local colors = ready and BAR_COLORS.ultReady or BAR_COLORS.ult
                local dark, bright = colors[1], colors[2]
                frame.ult:SetGradientColors(dark[1], dark[2], dark[3], 1, bright[1], bright[2], bright[3], 1)
            end
        else
            SetBar(frame.ult, nil)
        end
    end

    -- weapon bar: GF.GetBar returns true (back), false (front) or nil (unknown)
    local barText = ""
    if sv.showBar and online then
        local onBack = GF.GetBar(unitTag)
        if onBack == true then
            barText = "|c" .. COLOR_BACK_BAR .. "BACK|r"
        elseif onBack == false then
            barText = "|c" .. COLOR_FRONT_BAR .. "FRONT|r"
        end
    end
    if barText ~= frame.barText then
        frame.barText = barText
        frame.barLabel:SetText(barText)
    end

    -- DPS (red) and HPS (green) in thousands, only while there is any
    local statsText = ""
    if online then
        local dps, hps = GF.GetCombat(unitTag)
        if dps then
            if sv.showDps and dps > 0 then
                statsText = statsText .. "  |cff7a66" .. dps .. "k|r"
            end
            if sv.showHps and hps > 0 then
                statsText = statsText .. "  |c7de87d" .. hps .. "k|r"
            end
        end
    end
    if statsText ~= frame.statsText then
        frame.statsText = statsText
        frame.stats:SetText(statsText)
    end

    -- fade members who are offline or too far away to be healed or buffed
    local inRange = frame.isSelf or unitTag == "player" or IsUnitInGroupSupportRange(unitTag)
    frame.control:SetAlpha((online and inRange) and 1 or 0.45)
    if not online or dead then
        frame.name:SetColor(0.6, 0.6, 0.6, 1)
    elseif frame.isSelf and sv.highlightSelf then
        frame.name:SetColor(1, 0.9, 0.6, 1)
    else
        frame.name:SetColor(0.95, 0.95, 0.92, 1)
    end
end

---------------------------------------------------------------------------
-- Update loop
---------------------------------------------------------------------------

-- Consoles have no error popup: a Lua error in the update loop would just
-- silently stop everything after it. There each part runs protected, so one
-- failing part cannot take the others down, and the first error is kept for
-- the Diagnostics section of the settings. On PC errors surface as usual.
local guarded = IsConsoleUI()

-- Runs fn(...) and returns true plus its result, or false if it failed.
-- `section` names the part of the update for the error message.
local function Call(section, fn, ...)
    if not guarded then return true, fn(...) end
    local ok, result = pcall(fn, ...)
    if ok then return true, result end
    GF.errorCount = (GF.errorCount or 0) + 1
    if not GF.firstError then
        GF.firstError = section .. ": " .. tostring(result)
    end
    return false
end

-- Returns the multi-line text of the settings' Diagnostics section: version,
-- which libraries were found, a buff count for yourself and the first error.
function GF.GetDiagnostics()
    local text = "Version " .. GF.version
        .. "\nLibGroupResources: " .. (GF.hasGroupResources and "found" or "missing")
        .. "\nLibGroupCombatStats: " .. (GF.hasCombatStats and "found" or "missing")
        .. "\nEffect sharing: " .. (GF.canShare and "ready" or (GF.shareError or "unavailable"))
        .. "\nBuffs: " .. (GF.selfBuffInfo or "not scanned yet")
    if GF.firstError then
        text = text .. "\n|cff5555Error (" .. GF.errorCount .. "x)|r " .. GF.firstError
    else
        text = text .. "\nNo errors."
    end
    return text
end

local unitTags = {} -- reused every tick to avoid creating garbage

-- Returns the unit tags to show, in frame order:
--   preview on  -> "player" repeated (copies of your own frame)
--   in a group  -> "group1".."groupN" in the game's group order
--   solo        -> "player", if "show when not grouped" is on or the frames
--                  are unlocked (so there is something to drag)
local function CollectUnitTags()
    ZO_ClearNumericallyIndexedTable(unitTags)
    if GF.previewCount then
        for i = 1, zo_min(GF.previewCount, MAX_FRAMES) do
            unitTags[i] = "player"
        end
    elseif IsUnitGrouped("player") then
        for i = 1, zo_min(GetGroupSize(), MAX_FRAMES) do
            local unitTag = GetGroupUnitTagByIndex(i)
            if unitTag and DoesUnitExist(unitTag) then
                unitTags[#unitTags + 1] = unitTag
            end
        end
    elseif GF.sv.showSolo or not GF.sv.locked then
        unitTags[1] = "player"
    end
    return unitTags
end

-- The heart of the addon, run every TICK_MS: assigns members to frames and
-- refreshes each one. Does nothing while the HUD (and so the frames) is
-- hidden, e.g. in menus.
local function OnTick()
    if root:IsHidden() then return end

    local sv = GF.sv
    local now = GetFrameTimeSeconds()
    local tags = CollectUnitTags()

    -- group size changed: re-size and re-wrap
    if #tags ~= lastCount and #tags > 0 then
        lastCount = #tags
        Arrange(lastCount)
    end

    for i = 1, MAX_FRAMES do
        local frame = frames[i]
        local unitTag = tags[i]
        if unitTag then
            -- Unit tags are reshuffled when people join or leave, so the name
            -- is compared too: a new name means a different member.
            local name = sv.useDisplayName and GetUnitDisplayName(unitTag) or GetUnitName(unitTag)
            if frame.unitTag ~= unitTag or frame.unitName ~= name then
                frame.unitTag = unitTag
                frame.unitName = name
                frame.name:SetText(zo_strformat("<<1>>", name))
                frame.forceRefresh = true
                -- a different member now owns this frame: snap the bars
                frame.health.noData = true
                frame.magicka.noData = true
                frame.stamina.noData = true
                frame.ult.noData = true
            end
            frame.control:SetHidden(false)
            Call("header", UpdateHeader, frame)

            -- rescan on changes, and once a second in case an event was missed
            if frame.forceRefresh or dirtyBuffs[unitTag] or now >= (frame.nextScan or 0) then
                frame.nextScan = now + 1
                Call("buffs", ScanBuffs, frame)
            end
            Call("resources", UpdateResources, frame)
            frame.forceRefresh = nil

            local ok, expired = Call("timers", UpdateTimers, frame, now)
            if ok and expired then
                frame.forceRefresh = true -- something ran out, rescan next tick
            end
        else
            -- more frames than members: this one is unused
            frame.unitTag = nil
            frame.unitName = nil
            frame.control:SetHidden(true)
        end
    end

    ZO_ClearTable(dirtyBuffs)
end

-- EVENT_EFFECT_CHANGED: an effect was gained, lost or refreshed. Only notes
-- whose buffs changed; the rescan happens on the next tick, so a burst of
-- events for one member costs a single scan.
local function OnEffectChanged(_, _, _, _, unitTag)
    dirtyBuffs[unitTag] = true
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------

-- Creates the top level window, the drag/scale handling, the unlock
-- outline and all frames, and ties the window to the HUD scenes so it is
-- only visible during normal play.
local function CreateRoot()
    local sv = GF.sv

    root = WM:CreateTopLevelWindow("GroupFramesRoot")
    root:SetClampedToScreen(true)
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.left, sv.top)
    root:SetHandler("OnMoveStop", function(control)
        sv.left, sv.top = control:GetLeft(), control:GetTop()
        Arrange(lastCount) -- the room up to the screen edge changed
    end)
    -- while unlocked: wheel scales, shift + wheel changes the frame width
    root:SetHandler("OnMouseWheel", function(_, delta)
        if sv.locked then return end
        if IsShiftKeyDown() then
            sv.width = zo_clamp(sv.width + delta * 5, 100, 400)
        else
            sv.scale = zo_clamp(zo_roundToNearest(sv.scale + delta * 0.05, 0.05), 0.5, 2)
        end
        GF.ApplyLayout()
    end)
    GF.root = root

    -- outline of the draggable area, only visible while unlocked
    GF.unlockBg = WM:CreateControl("GroupFramesUnlockBG", root, CT_BACKDROP)
    GF.unlockBg:SetAnchor(TOPLEFT, root, TOPLEFT, -4, -4)
    GF.unlockBg:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, 4, 4)
    GF.unlockBg:SetCenterColor(1, 0.85, 0.3, 0.08)
    GF.unlockBg:SetEdgeColor(1, 0.85, 0.3, 0.8)
    GF.unlockBg:SetEdgeTexture("", 1, 1, 1)
    GF.unlockBg:SetDrawLayer(DL_BACKGROUND)

    container = WM:CreateControl("GroupFramesContainer", root, CT_CONTROL)
    container:SetAnchorFill(root)

    GF.unlockHint = CreateLabel("GroupFramesUnlockHint", root, "$(BOLD_FONT)|$(KB_15)|soft-shadow-thick")
    GF.unlockHint:SetAnchor(BOTTOMLEFT, root, TOPLEFT, 0, -8)
    GF.unlockHint:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
    GF.unlockHint:SetText("Drag to move  |  Wheel: scale  |  Shift+Wheel: width")
    GF.unlockHint:SetColor(1, 0.85, 0.3, 1)

    EM:RegisterForEvent(GF.name .. "Resize", EVENT_SCREEN_RESIZED, function() Arrange(lastCount) end)

    for i = 1, MAX_FRAMES do
        CreateFrame(i).control:SetHidden(true)
    end

    -- show with the HUD (combat view and cursor mode), hide in menus
    local fragment = ZO_SimpleSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

-- Locks or unlocks dragging of the frames.
function GF.SetLocked(locked)
    GF.sv.locked = locked
    GF.ApplyLayout()
end

-- Start-up. EVENT_ADD_ON_LOADED fires once for every addon, so wait for our
-- own; by then the saved variables and all libraries we depend on exist.
-- Order matters: settings first, then the libraries, then the controls,
-- and the update timer last so it never runs against half-built frames.
local function OnAddOnLoaded(_, addonName)
    if addonName ~= GF.name then return end
    EM:UnregisterForEvent(GF.name, EVENT_ADD_ON_LOADED)

    -- account-wide settings, stored in SavedVariables/GroupFrames.lua
    GF.sv =ZO_SavedVars:NewAccountWide("GroupFrames_SV", 1, nil, GF.defaults)
    GF.MigrateCustomEffects()
    -- one-time switch of existing installs to the two-column layout
    if GF.sv.layoutVersion ~= 2 then
        GF.sv.layoutVersion = 2
        GF.sv.orientation = "vertical"
        GF.sv.wrapAfter = 6
    end
    GF.InitSharing()
    GF.InitStats()

    -- LibGroupResources is reached through LibGroupBroadcast, not a global
    if LibGroupBroadcast and LibGroupBroadcast.GetHandlerApi then
        groupResources =LibGroupBroadcast:GetHandlerApi("GroupResources")
    end
    GF.hasGroupResources = groupResources ~= nil

    CreateRoot()
    GF.ApplyLayout()
    if IsConsoleUI() then
        -- a problem in the menu must not stop the frames from starting
        local ok, err = pcall(GF.CreateSettings)
        if not ok then
            GF.firstError = "settings: " .. tostring(err)
            GF.errorCount = 1
        end
    else
        GF.CreateSettings()
    end

    -- Buff changes, filtered so the handler only runs for group members and
    -- yourself. Each registration needs its own name to carry its own filter.
    EM:RegisterForEvent(GF.name .. "Group", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:AddFilterForEvent(GF.name .. "Group", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
    EM:RegisterForEvent(GF.name .. "Player", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:AddFilterForEvent(GF.name .. "Player", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    EM:RegisterForUpdate(GF.name .. "Tick", TICK_MS, OnTick)
    -- the default frames are rebuilt on zone changes, hide them again
    EM:RegisterForEvent(GF.name .. "Default", EVENT_PLAYER_ACTIVATED, ApplyDefaultFrames)

    -- /groupframes [lock|unlock|test [count]]; no argument toggles the lock
    SLASH_COMMANDS["/groupframes"] = function(arg)
        if arg == "lock" then
            GF.SetLocked(true)
        elseif arg == "unlock" then
            GF.SetLocked(false)
        elseif arg:find("^test") then
            -- "/groupframes test 12" previews 12 frames, "/groupframes test" turns it off
            local count = tonumber(arg:match("%d+"))
            if not count and not GF.previewCount then count = MAX_FRAMES end
            GF.SetPreview(count)
            d("GroupFrames preview " .. (count and ("showing " .. count .. " frames") or "off"))
            return
        else
            GF.SetLocked(not GF.sv.locked)
        end
        d("GroupFrames " .. (GF.sv.locked and "locked" or "unlocked"))
    end

    -- one chat line after login when the resource library is missing (chat
    -- is not ready yet while addons load, hence the wait)
    if not groupResources then
        EM:RegisterForEvent(GF.name .. "Notice", EVENT_PLAYER_ACTIVATED, function()
            EM:UnregisterForEvent(GF.name .. "Notice", EVENT_PLAYER_ACTIVATED)
            d("GroupFrames: LibGroupResources is not installed - magicka and stamina of group members cannot be shown.")
        end)
    end
end

EM:RegisterForEvent(GF.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
