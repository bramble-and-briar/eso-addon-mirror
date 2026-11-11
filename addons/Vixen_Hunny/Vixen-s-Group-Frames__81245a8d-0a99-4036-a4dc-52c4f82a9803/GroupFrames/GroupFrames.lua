GroupFrames = GroupFrames or {}
local GF = GroupFrames

GF.name = "GroupFrames"
GF.version = "1.2.0"

local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER

local MAX_FRAMES = 12
local PAD = 5
local NAME_HEIGHT = 20
local ROLE_ICON_SIZE = 18
local LEADER_ICON_SIZE = 16
local FRAME_SPACING = 6
local TICK_MS = 100

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

local STATS_HEIGHT = 15
local COLOR_FRONT_BAR = "7fd3ff"
local COLOR_BACK_BAR = "ffa64d"

local COLOR_SELF_EDGE = { 0.90, 0.74, 0.32, 0.95 }
local COLOR_EDGE = { 0, 0, 0, 0.9 }

GF.defaults = {
    left = 40,
    top = 300,
    locked = true,
    scale = 1,
    width = 200,
    orientation = "vertical", -- "vertical" stacks downwards, "horizontal" sideways
    wrapAfter = 6, -- frames per column/row (12 players = 6 left, 6 right), 0 = auto wrap at the screen edge
    balanceWrap = true,
    adaptiveSize = true,
    compactAbove = 4,
    compactFactor = 0.8,
    showSolo = false,
    replaceDefault = true,
    sortMode = "default",
    useDisplayName = false,

    bgAlpha = 0.6,
    showRoleIcons = true,
    highlightSelf = true,
    smoothBars = true,
    showShields = true,

    showHealth = true,
    showMagicka = true,
    showStamina = true,
    showHealthText = true,
    showUlt = true,
    showDps = true,
    showHps = true,
    showBar = true,
    shareBar = true,
    ultHeight = 18,
    healthHeight = 18,
    resourceHeight = 6,

    showBuffs = true,
    trackMajor = true,
    trackMinor = true,
    trackOtherMajorMinor = false,
    trackDebuffs = false,
    trackedEffects = {}, -- user-added effects, see Buffs.lua
    effectIds = {}, -- lower-case effect name -> an ability id with that name (for sharing)
    autoAcceptShared = false,
    buffs = {}, -- filled from Buffs.lua below
    iconSize = 24,
    maxIcons = 7,
    showTimers = true,
}

for _, name in ipairs(GF.MAJOR_BUFFS) do GF.defaults.buffs[name] = true end
for _, name in ipairs(GF.MINOR_BUFFS) do GF.defaults.buffs[name] = true end

local frames = {}
local dirtyBuffs = {} -- unitTag -> true
local groupResources -- LibGroupResources handler api, nil when not installed
local root, container

---------------------------------------------------------------------------
-- Control creation
---------------------------------------------------------------------------

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

local function SetBarShown(bar, shown)
    bar:SetHidden(not shown)
    bar.bg:SetHidden(not shown)
end

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

local function CreateFrame(index)
    local name = "GroupFramesUnit" .. index
    local control = WM:CreateControl(name, container, CT_CONTROL)

    local frame = { control = control, icons = {}, buffs = {}, index = index }

    frame.bg = WM:CreateControl(name .. "BG", control, CT_BACKDROP)
    frame.bg:SetAnchorFill(control)
    frame.bg:SetEdgeTexture("", 1, 1, 1)
    frame.bg:SetDrawLevel(0)

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

    frame.shield = WM:CreateControl(name .. "Shield", control, CT_STATUSBAR)
    frame.shield:SetAnchorFill(frame.health)
    frame.shield:SetGradientColors(0.55, 0.75, 1, 0.35, 0.9, 0.97, 1, 0.6)
    frame.shield:SetMinMax(0, 1)
    frame.shield:SetValue(0)
    frame.shield:SetDrawLevel(3)
    frame.shield:SetHidden(true)

    frame.healthText = CreateLabel(name .. "HealthText", control, "$(BOLD_FONT)|$(KB_14)|soft-shadow-thick")
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

    frame.ultText = CreateLabel(name .. "UltText", control, "$(BOLD_FONT)|$(KB_13)|soft-shadow-thick")
    frame.ultText:SetAnchor(CENTER, frame.ult, CENTER, 0, 0)
    frame.ultText:SetDrawLevel(5)

    -- line below the bars: weapon bar on the left, ult points / DPS / HPS on the right
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
---------------------------------------------------------------------------

-- Effective sizes for the current group size (see UpdateMetrics).
local metrics = { width = 200, healthHeight = 18, resourceHeight = 6, iconSize = 24 }
local lastCount = 1

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

local function LayoutFrame(frame)
    local sv = GF.sv
    local control = frame.control
    local width = metrics.width
    local inner = width - PAD * 2
    local y = PAD

    frame.bg:SetCenterColor(0.04, 0.04, 0.06, sv.bgAlpha)

    frame.nameY = y
    y = y + NAME_HEIGHT + 2

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

    local height = 0
    for i = 1, MAX_FRAMES do
        height = LayoutFrame(frames[i])
        frames[i].forceRefresh = true
    end
    local width = metrics.width
    local vertical = sv.orientation ~= "horizontal"

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

    local columns, rows = lines, perLine
    if not vertical then columns, rows = perLine, lines end
    root:SetDimensions(columns * (width + FRAME_SPACING) - FRAME_SPACING,
        rows * (height + FRAME_SPACING) - FRAME_SPACING)
end

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

local function GetHeaderIcon(unitTag)
    if not GF.sv.showRoleIcons then return nil end
    local texture = ROLE_ICONS[GetGroupMemberSelectedRole(unitTag)]
    if not texture and getClassIcon then
        texture = getClassIcon(GetUnitClassId(unitTag))
    end
    return texture
end

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
    for i = shown + 1, #frame.icons do
        frame.icons[i]:SetHidden(true)
        frame.icons[i].entry = nil
    end
    frame.shownIcons = shown
end

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

local function UpdateResources(frame)
    local sv = GF.sv
    local unitTag = frame.unitTag
    local online = IsUnitOnline(unitTag)
    local dead = IsUnitDead(unitTag)

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

local unitTags = {}

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
            frame.unitTag = nil
            frame.unitName = nil
            frame.control:SetHidden(true)
        end
    end

    ZO_ClearTable(dirtyBuffs)
end

local function OnEffectChanged(_, _, _, _, unitTag)
    dirtyBuffs[unitTag] = true
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------

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

    local fragment = ZO_SimpleSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

function GF.SetLocked(locked)
    GF.sv.locked = locked
    GF.ApplyLayout()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= GF.name then return end
    EM:UnregisterForEvent(GF.name, EVENT_ADD_ON_LOADED)

    GF.sv = ZO_SavedVars:NewAccountWide("GroupFrames_SV", 1, nil, GF.defaults)
    GF.MigrateCustomEffects()
    -- one-time switch of existing installs to the two-column layout
    if GF.sv.layoutVersion ~= 2 then
        GF.sv.layoutVersion = 2
        GF.sv.orientation = "vertical"
        GF.sv.wrapAfter = 6
    end
    GF.InitSharing()
    GF.InitStats()

    if LibGroupBroadcast and LibGroupBroadcast.GetHandlerApi then
        groupResources = LibGroupBroadcast:GetHandlerApi("GroupResources")
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

    EM:RegisterForEvent(GF.name .. "Group", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:AddFilterForEvent(GF.name .. "Group", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
    EM:RegisterForEvent(GF.name .. "Player", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:AddFilterForEvent(GF.name .. "Player", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    EM:RegisterForUpdate(GF.name .. "Tick", TICK_MS, OnTick)
    -- the default frames are rebuilt on zone changes, hide them again
    EM:RegisterForEvent(GF.name .. "Default", EVENT_PLAYER_ACTIVATED, ApplyDefaultFrames)

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

    if not groupResources then
        EM:RegisterForEvent(GF.name .. "Notice", EVENT_PLAYER_ACTIVATED, function()
            EM:UnregisterForEvent(GF.name .. "Notice", EVENT_PLAYER_ACTIVATED)
            d("GroupFrames: LibGroupResources is not installed - magicka and stamina of group members cannot be shown.")
        end)
    end
end

EM:RegisterForEvent(GF.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
