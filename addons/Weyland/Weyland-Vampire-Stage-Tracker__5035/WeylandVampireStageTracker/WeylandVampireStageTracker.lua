-- Weyland Vampire Stage Tracker 1.2.0
-- Tracks the player's current vampirism stage and remaining time.
-- The live player buff is the single source of truth for the stage.
-- Unlock with: /vst unlock
-- Lock with:   /vst lock
-- Reset with:  /vst reset
-- Debug with:  /vst debug

local ADDON_NAME = "WeylandVampireStageTracker"
local DISPLAY_NAME = "Weyland Vampire Stage Tracker"

-- Texts live in lang/*.lua (English is the base and the fallback). A key that is
-- missing everywhere is shown as the key itself instead of raising an error.
local STRINGS = WeylandVampireStageTracker_Strings or {}
local function T(key)
    return STRINGS[key] or key
end
local VST = {}

-- ESO vampire stage effect ability IDs.
-- These are the actual Vampire Stage buff abilities, so stage detection
-- does not depend on localized buff names or icon filenames.
local STAGE_BY_ABILITY_ID = {
    [135397] = 1,
    [135399] = 2,
    [135400] = 3,
    [135402] = 4,
}

local ROMAN_STAGE = {
    [1] = "I",
    [2] = "II",
    [3] = "III",
    [4] = "IV",
}

-- Stage colors. "blood" (default) is a gothic palette: bone -> rose -> crimson -> blood red.
-- "classic" is the old traffic-light palette. Switch with /vst colors.
local PALETTES = {
    blood = {
        [1] = { 0.92, 0.88, 0.80, 1.0 }, -- bone
        [2] = { 0.93, 0.52, 0.48, 1.0 }, -- rose
        [3] = { 0.80, 0.12, 0.14, 1.0 }, -- crimson
        [4] = { 1.00, 0.12, 0.08, 1.0 }, -- blood red
    },
    classic = {
        [1] = { 0.25, 1.00, 0.25, 1.0 }, -- green
        [2] = { 0.10, 1.00, 0.90, 1.0 }, -- turquoise
        [3] = { 1.00, 0.85, 0.10, 1.0 }, -- yellow
        [4] = { 1.00, 0.05, 0.05, 1.0 }, -- alert red
    },
}
local FALLBACK_COLOR = { 0.80, 0.12, 0.14, 1.0 }

local DEFAULTS = {
    unlocked = false,
    palette = "blood",
    scale = 1.0,
    iconSize = 62,
    timerFontSize = 22,
    backgroundOpacity = 0.90,
    frameOpacity = 1.0,
    showFrame = true,
    showBackground = true,
    showIcon = true,
    showTimer = true,
    showBloodDrops = true,
    showWhenNotVampire = false,
    warningMinutes = 10,
    timerFormat = "compact",
    position = {
        x = 0.50,
        y = 0.50,
        valid = false,
    },
    timer = {
        stage = nil,
        remaining = nil,
    },
}

local MEDIA = ADDON_NAME .. "/Media/"
local TEX = {
    fill  = MEDIA .. "plate_fill.dds",
    frame = MEDIA .. "plate_frame.dds",
    drop  = MEDIA .. "drop.dds",
    -- One icon per vampire stage (the Roman numeral is part of the art).
    stage = {
        [1] = MEDIA .. "stage1.dds",
        [2] = MEDIA .. "stage2.dds",
        [3] = MEDIA .. "stage3.dds",
        [4] = MEDIA .. "stage4.dds",
    },
}

-- UI layout (units = UI pixels).
-- [stage icon] | timer / blood drops / thin bar
-- The plate size is NOT fixed: it is computed from the icon size and the timer
-- font size (see GetLayoutMetrics), so a bigger icon really makes a bigger HUD.
local ICON_SIZE = 62                      -- default icon HEIGHT
local PLATE_H_MIN = 72                    -- the plate never gets lower than this
local PLATE_PAD = 5                       -- space above/below the icon
local ICON_X = 10                         -- space left of the icon
local TEXT_GAP = 4                        -- icon -> text column
local TEXT_PAD_RIGHT = 10                 -- text column -> right frame edge
local COL_W_BASE = 98                     -- base width of the text column
local DROP_W, DROP_H, DROP_GAP = 9, 12, 3
local BAR_H = 2
local BLOCK_GAP = 5                       -- vertical gap timer / drops / bar
local BLOCK_PAD = 9                       -- minimal space above/below the text block

-- The stage textures are 256x256, but the art is a tall emblem that leaves
-- ~12% fully transparent columns on the left and right. Instead of drawing
-- those empty pixels, only the visible region is mapped onto the icon control
-- (SetTextureCoords). Region: x 32..224, y 4..252 of 256 (the union of all
-- four stage icons, so every stage keeps the same scale).
local ICON_U_LEFT, ICON_U_RIGHT = 32 / 256, 224 / 256
local ICON_V_TOP, ICON_V_BOTTOM = 4 / 256, 252 / 256
local ICON_ASPECT = (ICON_U_RIGHT - ICON_U_LEFT) / (ICON_V_BOTTOM - ICON_V_TOP)  -- width / height

local FONT_DIR     = ADDON_NAME .. "/fonts/"
local FONT_TIMER   = FONT_DIR .. "Cinzel-Bold.slug|22|soft-shadow-thick"

local FRAME_COLOR  = { 0.50, 0.07, 0.09, 1.0 }   -- dark crimson frame
local TEXT_COLOR   = { 0.92, 0.88, 0.80, 1.0 }   -- bone
local WARN_COLOR   = { 1.00, 0.30, 0.25, 1.0 }   -- last 10 minutes
local DIM_DROP     = { 0.28, 0.09, 0.10, 0.95 }

-- ESO confirms that each vampire stage lasts four hours. The live buff's
-- timeStarted can be reinitialized after /reloadui, while timeEnding remains
-- the reliable source for the actual remaining time. Use the documented stage
-- duration as the progress range so the bar cannot jump back to 100% on reload.
local STAGE_DURATION_SECONDS = 4 * 60 * 60
local UPDATE_INTERVAL_MS = 500

-- Sample used for the preview and for move mode when you are not a vampire.
local SAMPLE_REMAINING = 2 * 3600 + 36 * 60
local SAMPLE_FRACTION = SAMPLE_REMAINING / STAGE_DURATION_SECONDS

local savedVars
local control               -- top-level window; its visibility is owned by the HUD scene fragment
local content               -- everything we draw; this is what we hide/show ourselves
local hint                  -- "drag me" text, only visible in move mode
local hudView               -- the plate on screen
local panelPreview          -- the plate replica inside the settings panel
local previewStage = 3      -- stage shown by the settings preview / the sample HUD (not saved)
local settingsPanel
local RefreshWidget
local updateTimerName = ADDON_NAME .. "_Timer"
local eventName = ADDON_NAME .. "_Effects"
local fullUpdateEventName = ADDON_NAME .. "_FullUpdate"
local activatedEventName = ADDON_NAME .. "_Activated"
local deactivatedEventName = ADDON_NAME .. "_Deactivated"

local current = {
    stage = nil,
    abilityId = nil,
    buffName = nil,
    iconPath = nil,
    timeStarted = nil,
    timeEnding = nil,
}

-- Visibility rules are shared by settings, SavedVariables migration and layout.
-- Blood drops and the progress bar are one inseparable display group.
local function GetVisibilityConfig()
    return {
        showIcon = savedVars.showIcon,
        showTimer = savedVars.showTimer,
        showBloodDrops = savedVars.showBloodDrops,
    }
end

local function IsVisibilityConfigurationValid(stage, config)
    local hasStageIndicator = config.showIcon or config.showBloodDrops
    if not hasStageIndicator then
        return false
    end

    -- Stage I has no timer, so only a stage indicator is required there.
    if stage ~= 1 then
        local hasTimeIndicator = config.showTimer or config.showBloodDrops
        if not hasTimeIndicator then
            return false
        end
    end

    return true
end

local function IsVisibilityConfigurationValidForAllStages(config)
    return IsVisibilityConfigurationValid(1, config)
        and IsVisibilityConfigurationValid(2, config)
end

local VISIBILITY_KEYS = {
    icon = "showIcon",
    timer = "showTimer",
    drops = "showBloodDrops",
}

local function CanSetVisibility(option, value)
    local key = VISIBILITY_KEYS[option]
    if not key then
        return false
    end

    local config = GetVisibilityConfig()
    config[key] = value

    -- Keep the saved configuration valid when the player advances from
    -- Stage I to Stage II, even while the settings preview currently shows I.
    return IsVisibilityConfigurationValidForAllStages(config)
end

local function CanToggleVisibility(option)
    local key = VISIBILITY_KEYS[option]
    if not key then
        return false
    end
    return CanSetVisibility(option, not savedVars[key])
end

local function SetVisibilityOption(option, value)
    if option == "timer" and previewStage == 1 then
        return false
    end
    if not CanSetVisibility(option, value) then
        return false
    end

    savedVars[VISIBILITY_KEYS[option]] = value
    RefreshWidget()
    return true
end

local function GetVisibilityTooltip(option)
    if option == "icon" then
        if savedVars.showIcon and not CanToggleVisibility("icon") then
            return T("SHOW_ICON_LOCKED_TT")
        end
        return T("SHOW_ICON_TT")
    end

    if option == "timer" then
        if previewStage == 1 then
            return T("SHOW_TIMER_STAGE1_TT")
        end
        if savedVars.showTimer and not CanToggleVisibility("timer") then
            return T("SHOW_TIMER_LOCKED_TT")
        end
        return T("SHOW_TIMER_TT")
    end

    if option == "drops" then
        if savedVars.showBloodDrops and not CanToggleVisibility("drops") then
            return T("SHOW_DROPS_LOCKED_TT")
        end
        return T("SHOW_DROPS_TT")
    end

    return ""
end

local function StageColor(stage)
    local palette = PALETTES[savedVars and savedVars.palette] or PALETTES.blood
    return palette[stage] or FALLBACK_COLOR
end

local function Normalize(value)
    return string.lower(value or "")
end

local function StageFromIcon(iconPath)
    local s = Normalize(iconPath)
    if s == "" then
        return nil
    end

    if string.find(s, "vampire_infection_stage1", 1, true) or string.find(s, "vampirism_stage1", 1, true) then
        return 1
    end
    if string.find(s, "vampire_infection_stage2", 1, true) or string.find(s, "vampirism_stage2", 1, true) then
        return 2
    end
    if string.find(s, "vampire_infection_stage3", 1, true) or string.find(s, "vampirism_stage3", 1, true) then
        return 3
    end
    if string.find(s, "vampire_infection_stage4", 1, true) or string.find(s, "vampirism_stage4", 1, true) then
        return 4
    end

    -- Historical stage 4 icon fallback.
    if string.find(s, "ability_vampire_007.dds", 1, true) then
        return 4
    end

    return nil
end

local function StageFromBuffName(buffName)
    local s = Normalize(buffName)
    local n = string.match(s, "stage%s*([1-4])")
    if n then
        return tonumber(n)
    end
    return nil
end

local function GetVampireStageBuff()
    local numBuffs = GetNumBuffs("player")
    if not numBuffs then
        return nil
    end

    local fallback

    -- Keep the inclusive form used by established ESO vampire buff scanners.
    for index = 0, numBuffs do
        local buffName, timeStarted, timeEnding, _, _, iconFilename, _, _, _, _, abilityId = GetUnitBuffInfo("player", index)

        local stage = STAGE_BY_ABILITY_ID[abilityId]
        if not stage then
            stage = StageFromIcon(iconFilename)
        end
        if not stage then
            stage = StageFromBuffName(buffName)
        end

        if stage then
            local candidate = {
                stage = stage,
                abilityId = abilityId,
                buffName = buffName,
                iconPath = iconFilename,
                timeStarted = timeStarted,
                timeEnding = timeEnding,
            }

            -- Prefer the exact stage ability ID whenever it is available.
            if STAGE_BY_ABILITY_ID[abilityId] then
                return candidate
            end

            -- Otherwise prefer a timed candidate.
            if timeEnding and timeStarted and timeEnding > timeStarted then
                return candidate
            end

            fallback = fallback or candidate
        end
    end

    return fallback
end

local function GetGameTimeSeconds()
    -- GetUnitBuffInfo() timeStarted/timeEnding values are expressed in
    -- game-time seconds. Use the same clock as the ESO buff API.
    return GetGameTimeMilliseconds() / 1000
end

local function ResolveRemainingSeconds(timeEnding)
    if type(timeEnding) ~= "number" or timeEnding <= 0 then
        return nil
    end

    return math.max(0, timeEnding - GetGameTimeSeconds())
end

local function FormatRemaining(seconds)
    if seconds == nil then
        return "--"
    end

    seconds = math.max(0, math.floor(seconds + 0.5))

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if savedVars.timerFormat == "clock" then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    end

    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    end

    if minutes > 0 then
        return string.format("%dm %02ds", minutes, secs)
    end

    return string.format("%ds", secs)
end

local function ClearCurrent()
    current.stage = nil
    current.abilityId = nil
    current.buffName = nil
    current.iconPath = nil
    current.timeStarted = nil
    current.timeEnding = nil
end

local function ApplyStoredPosition()
    local root = GuiRoot
    if not root or not control then
        return false
    end

    if savedVars.position.valid and root:GetWidth() > 0 and root:GetHeight() > 0 then
        local x = savedVars.position.x * root:GetWidth()
        local y = savedVars.position.y * root:GetHeight()

        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, root, TOPLEFT, x, y)
        return true
    end

    return false
end

local function ApplyDefaultPosition()
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
end

local function SavePosition()
    if not control or not GuiRoot then
        return
    end

    local rootWidth = GuiRoot:GetWidth()
    local rootHeight = GuiRoot:GetHeight()
    if rootWidth <= 0 or rootHeight <= 0 then
        return
    end

    local left = control:GetLeft()
    local top = control:GetTop()
    if not left or not top then
        return
    end

    savedVars.position.x = left / rootWidth
    savedVars.position.y = top / rootHeight
    savedVars.position.valid = true
end

local function UpdateEditorVisuals()
    if not control then
        return
    end

    -- Native ESO dragging (left mouse button) works only while unlocked.
    control:SetMouseEnabled(savedVars.unlocked and true or false)
    control:SetMovable(savedVars.unlocked and true or false)
end

local function GetLayoutMetrics(stage)
    stage = stage or previewStage or 3

    local iconH = savedVars.iconSize or ICON_SIZE
    local iconW = math.floor(iconH * ICON_ASPECT + 0.5)
    local fontSize = savedVars.timerFontSize or 22

    -- The drops and progress bar always appear/disappear as one group.
    local visibility = GetVisibilityConfig()
    if not IsVisibilityConfigurationValid(stage, visibility) then
        -- Defensive fallback for unexpected external SavedVariables edits.
        if not (visibility.showIcon or visibility.showBloodDrops) then
            visibility.showBloodDrops = true
        end
        if stage ~= 1 and not (visibility.showTimer or visibility.showBloodDrops) then
            visibility.showTimer = true
        end
    end

    local showIcon = visibility.showIcon
    local showTimer = stage ~= 1 and visibility.showTimer
    local showDrops = visibility.showBloodDrops
    local showBar = showDrops

    local timerH = math.max(28, fontSize + 6)
    local blockY = {}
    local blockH = 0
    local blockCount = 0

    local function AddBlock(key, height)
        if blockCount > 0 then
            blockH = blockH + BLOCK_GAP
        end
        blockY[key] = blockH
        blockH = blockH + height
        blockCount = blockCount + 1
    end

    if showTimer then AddBlock("timer", timerH) end
    if showDrops then AddBlock("drops", DROP_H) end
    if showBar then AddBlock("bar", BAR_H) end

    local textX = showIcon and (ICON_X + iconW + TEXT_GAP) or ICON_X
    -- Add room for wide clock-format timer text at larger font sizes.
    local fontExtraWidth = math.max(0, fontSize - 22) * 5
    local columnWidth = COL_W_BASE + fontExtraWidth
    local hasText = showTimer or showDrops or showBar
    local dropGroupWidth = 4 * DROP_W + 3 * DROP_GAP
    local dropX = textX + math.floor((columnWidth - dropGroupWidth) / 2)

    local width
    if hasText then
        width = textX + columnWidth + TEXT_PAD_RIGHT
    elseif showIcon then
        width = ICON_X + iconW + TEXT_PAD_RIGHT
    else
        -- Keep an intentional plate width even when every content toggle is off.
        width = ICON_X + COL_W_BASE + TEXT_PAD_RIGHT
    end

    local iconRequiredHeight = showIcon and (iconH + 2 * PLATE_PAD) or 0
    local textRequiredHeight = blockH + 2 * BLOCK_PAD
    local height = math.max(PLATE_H_MIN, iconRequiredHeight, textRequiredHeight)
    local blockTop = math.floor((height - blockH) / 2)

    return {
        width = width,
        height = height,
        iconWidth = iconW,
        iconHeight = iconH,
        iconY = math.floor((height - iconH) / 2),
        textX = textX,
        columnWidth = columnWidth,
        timerY = blockTop + (blockY.timer or 0),
        dropY = blockTop + (blockY.drops or 0),
        dropX = dropX,
        barY = blockTop + (blockY.bar or 0),
        timerHeight = timerH,
        showIcon = showIcon,
        showTimer = showTimer,
        showDrops = showDrops,
        showBar = showBar,
    }
end

---------------------------------------------------------------------------
-- Plate "view": one copy of the plate (background, frame, icon, drops,
-- timer and bar). The HUD and preview share this renderer.
---------------------------------------------------------------------------
local function CreateView(parent, namePrefix)
    local wm = WINDOW_MANAGER
    local function N(suffix)
        return namePrefix and (namePrefix .. suffix) or nil
    end

    local v = { parent = parent, drops = {} }

    local function Tex(suffix, path, level)
        local t = wm:CreateControl(N(suffix), parent, CT_TEXTURE)
        t:SetDrawLevel(level)
        t:SetDimensions(1, 1)
        t:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
        if path then
            t:SetTexture(path)
        end
        return t
    end

    v.fill = Tex("Fill", TEX.fill, 1)
    v.frame = Tex("Frame", TEX.frame, 2)
    v.frame:SetColor(unpack(FRAME_COLOR))

    v.icon = Tex("StageIcon", TEX.stage[3], 4)
    v.icon:SetColor(1, 1, 1, 1)

    for i = 1, 4 do
        v.drops[i] = Tex("Drop" .. i, TEX.drop, 6)
        v.drops[i]:SetColor(unpack(DIM_DROP))
    end

    v.timer = wm:CreateControl(N("Timer"), parent, CT_LABEL)
    v.timer:SetDrawLevel(6)
    v.timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    v.timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    v.timer:SetFont(FONT_TIMER)
    v.timer:SetColor(unpack(TEXT_COLOR))

    v.barTrack = Tex("BarTrack", nil, 6)
    v.barTrack:SetColor(0.16, 0.055, 0.065, 0.95)
    v.barFill = Tex("BarFill", nil, 7)
    v.barFill:SetColor(1, 1, 1, 1)

    return v
end

local function Round(value, k)
    return math.floor(value * k + 0.5)
end

local function Size(value, k)
    return math.max(1, Round(value, k))
end

-- Anchors and sizes. Only redone when geometry or visibility changes.
local function LayoutView(v, m, k)
    local fontSize = math.max(8, Round(savedVars.timerFontSize or 22, k))
    local key = table.concat({
        m.width, m.height, m.iconWidth, m.iconHeight, m.textX, m.columnWidth,
        m.timerY, m.dropY, m.dropX, m.barY, fontSize, string.format("%.3f", k),
        m.showIcon and "i" or "-", m.showTimer and "t" or "-",
        m.showDrops and "d" or "-", m.showBar and "b" or "-",
    }, "|")
    if v.layoutKey == key then
        return
    end
    v.layoutKey = key

    local parent = v.parent
    local plateW, plateH = Size(m.width, k), Size(m.height, k)
    v.fill:SetDimensions(plateW, plateH)
    v.frame:SetDimensions(plateW, plateH)

    v.icon:ClearAnchors()
    v.icon:SetAnchor(TOPLEFT, parent, TOPLEFT, Round(ICON_X, k), Round(m.iconY, k))
    v.icon:SetDimensions(Size(m.iconWidth, k), Size(m.iconHeight, k))
    v.icon:SetTextureCoords(ICON_U_LEFT, ICON_U_RIGHT, ICON_V_TOP, ICON_V_BOTTOM)

    local colW = Size(m.columnWidth, k)
    v.timer:ClearAnchors()
    v.timer:SetAnchor(TOPLEFT, parent, TOPLEFT, Round(m.textX, k), Round(m.timerY, k))
    v.timer:SetDimensions(colW, Size(m.timerHeight, k))
    v.timer:SetFont(FONT_DIR .. "Cinzel-Bold.slug|" .. tostring(fontSize) .. "|soft-shadow-thick")

    v.barW, v.barH = colW, Size(BAR_H, k)
    for _, bar in ipairs({ v.barTrack, v.barFill }) do
        bar:ClearAnchors()
        bar:SetAnchor(TOPLEFT, parent, TOPLEFT, Round(m.textX, k), Round(m.barY, k))
        bar:SetDimensions(v.barW, v.barH)
    end

    for i = 1, 4 do
        v.drops[i]:ClearAnchors()
        v.drops[i]:SetAnchor(TOPLEFT, parent, TOPLEFT,
            Round(m.dropX + (i - 1) * (DROP_W + DROP_GAP), k), Round(m.dropY, k))
        v.drops[i]:SetDimensions(Size(DROP_W, k), Size(DROP_H, k))
    end
end

-- Stage I keeps its no-timer behavior. The large icon is independent, while
-- blood drops and the progress bar are always rendered as a single group.
local function RenderView(v, k, stage, remaining, fraction, gold)
    local m = GetLayoutMetrics(stage)
    local stageColor = StageColor(stage)
    local urgent = type(remaining) == "number" and remaining <= (savedVars.warningMinutes or 10) * 60

    LayoutView(v, m, k)

    v.fill:SetHidden(not savedVars.showBackground)
    v.fill:SetColor(0.04, 0.013, 0.018, savedVars.backgroundOpacity or 0.90)

    v.frame:SetHidden(not savedVars.showFrame)
    local frameAlpha = savedVars.frameOpacity or 1.0
    if gold then
        v.frame:SetColor(1.0, 0.82, 0.2, frameAlpha)
    else
        v.frame:SetColor(FRAME_COLOR[1], FRAME_COLOR[2], FRAME_COLOR[3], frameAlpha)
    end

    v.icon:SetHidden(not m.showIcon)
    v.icon:SetTexture(TEX.stage[stage] or TEX.stage[3])

    for i = 1, 4 do
        v.drops[i]:SetHidden(not m.showDrops)
        if i <= (stage or 0) then
            v.drops[i]:SetColor(unpack(stageColor))
        else
            v.drops[i]:SetColor(unpack(DIM_DROP))
        end
    end

    v.timer:SetHidden(not m.showTimer)
    v.barTrack:SetHidden(not m.showBar)
    v.barFill:SetHidden(true)

    if m.showTimer then
        v.timer:SetText(FormatRemaining(remaining))
        v.timer:SetColor(unpack(urgent and WARN_COLOR or TEXT_COLOR))
    end

    if fraction and m.showBar then
        v.barFill:SetDimensions(math.max(1, math.floor(v.barW * fraction + 0.5)), v.barH)
        v.barFill:SetColor(unpack(urgent and WARN_COLOR or stageColor))
        v.barFill:SetHidden(false)
    end

    return m
end

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------
local hudWidth, hudHeight, hudScale

local function UpdateDisplay()
    if not control then
        return
    end

    local data = GetVampireStageBuff()

    if data then
        current.stage = data.stage
        current.abilityId = data.abilityId
        current.buffName = data.buffName
        current.iconPath = data.iconPath
        current.timeStarted = data.timeStarted
        current.timeEnding = data.timeEnding
    else
        ClearCurrent()
    end

    -- The window itself is shown/hidden by the HUD scene fragment. We only
    -- toggle its content here.
    local shouldShow = savedVars.unlocked or data ~= nil or savedVars.showWhenNotVampire
    content:SetHidden(not shouldShow)
    hint:SetHidden(not savedVars.unlocked)

    if not shouldShow then
        return
    end

    local stage, remaining, fraction
    if data then
        stage = current.stage
        remaining = ResolveRemainingSeconds(current.timeEnding)
        -- timeEnding remains the source of truth after reload. The documented
        -- stage duration provides a stable full range for the progress bar.
        if remaining ~= nil then
            fraction = math.min(1, math.max(0, remaining / STAGE_DURATION_SECONDS))
        end
    else
        stage, remaining, fraction = previewStage, SAMPLE_REMAINING, SAMPLE_FRACTION
    end

    -- Plate size and overall scale are recalculated for the currently visible
    -- set of blocks, so hiding the icon/timer does not leave empty geometry.
    local m = GetLayoutMetrics(stage)
    if hudWidth ~= m.width or hudHeight ~= m.height then
        hudWidth, hudHeight = m.width, m.height
        control:SetDimensions(m.width, m.height)
    end

    local scale = savedVars.scale or 1.0
    if hudScale ~= scale then
        hudScale = scale
        control:SetScale(scale)
    end

    RenderView(hudView, 1, stage, remaining, fraction, savedVars.unlocked)
end

---------------------------------------------------------------------------
-- Settings preview: a replica of the plate inside the settings panel
---------------------------------------------------------------------------
local PREVIEW_HEIGHT = 210
local PREVIEW_AREA_W, PREVIEW_AREA_H = 480, 150   -- the replica is shrunk to fit this box

local function RefreshPreview()
    local p = panelPreview
    if not p or not savedVars then
        return
    end

    local m = GetLayoutMetrics(previewStage)
    local userScale = savedVars.scale or 1.0
    local fit = math.min(1, PREVIEW_AREA_W / (m.width * userScale), PREVIEW_AREA_H / (m.height * userScale))
    local k = userScale * fit

    p.host:SetDimensions(Size(m.width, k), Size(m.height, k))
    RenderView(p.view, k, previewStage, SAMPLE_REMAINING, SAMPLE_FRACTION, false)

    local shrunk = fit < 1 and string.format(T("PREVIEW_SHRUNK"), math.floor(fit * 100 + 0.5)) or ""
    p.info:SetText(string.format(T("PREVIEW_INFO"),
        ROMAN_STAGE[previewStage] or "?", savedVars.iconSize or ICON_SIZE, userScale, shrunk))
end

local function CreatePreview(ctl)
    local wm = WINDOW_MANAGER

    local bg = wm:CreateControl(nil, ctl, CT_TEXTURE)   -- no texture file = solid colour
    bg:SetAnchorFill(ctl)
    -- A lighter neutral backdrop makes the dark plate fill and crimson frame
    -- distinguishable instead of blending into the preview canvas.
    bg:SetColor(0.15, 0.14, 0.17, 0.95)

    local info = wm:CreateControl(nil, ctl, CT_LABEL)
    info:SetFont("ZoFontGame")
    info:SetColor(0.8, 0.8, 0.8, 1)
    info:SetAnchor(TOP, ctl, TOP, 0, 8)

    local host = wm:CreateControl(nil, ctl, CT_CONTROL)
    host:SetDimensions(1, 1)
    host:SetAnchor(CENTER, ctl, CENTER, 0, 12)

    panelPreview = { host = host, info = info, view = CreateView(host, nil) }
    RefreshPreview()
end

local function SetUnlocked(enabled)
    savedVars.unlocked = enabled
    UpdateEditorVisuals()
    UpdateDisplay()

    if enabled then
        -- Like Weyland Huntsman Mark: close menus and switch the game into
        -- cursor mode, so the plate can be dragged with the mouse right away.
        SCENE_MANAGER:ShowBaseScene()
        zo_callLater(function()
            if savedVars.unlocked then
                SetGameCameraUIMode(true)
            end
        end, 200)
        d(DISPLAY_NAME .. ": " .. T("MSG_MOVE_MODE"))
    else
        SetGameCameraUIMode(false)
        -- OnMoveStop already saves a real drag. Merely locking at the default
        -- center must not convert that default anchor into a custom position.
        d(DISPLAY_NAME .. ": " .. T("MSG_LOCKED"))
    end
end

local function ResetPosition()
    savedVars.position.valid = false
    savedVars.position.x = DEFAULTS.position.x
    savedVars.position.y = DEFAULTS.position.y
    ApplyDefaultPosition()
    UpdateDisplay()
    RefreshPreview()
    d(DISPLAY_NAME .. ": " .. T("MSG_RESET"))
end

local function DebugInfo()
    local data = GetVampireStageBuff()
    if not data then
        d(DISPLAY_NAME .. ": " .. T("MSG_NO_STAGE"))
        return
    end

    local remaining = ResolveRemainingSeconds(data.timeEnding)
    d(string.format(
        "%s: stage=%s abilityId=%s remaining=%s timeStarted=%s timeEnding=%s icon=%s buff=%s",
        DISPLAY_NAME,
        tostring(data.stage),
        tostring(data.abilityId),
        FormatRemaining(remaining),
        tostring(data.timeStarted),
        tostring(data.timeEnding),
        tostring(data.iconPath),
        tostring(data.buffName)
    ))
end

local function HandleSlashCommand(command)
    command = Normalize(command)

    if command == "settings" or command == "options" then
        if LibAddonMenu2 and settingsPanel then
            LibAddonMenu2:OpenToPanel(settingsPanel)
        else
            d(DISPLAY_NAME .. ": " .. T("MSG_NEED_LAM"))
        end
        return
    end

    if command == "unlock" or command == "move" or command == "on" then
        SetUnlocked(true)
        return
    end

    if command == "lock" or command == "off" then
        SetUnlocked(false)
        return
    end

    if command == "reset" then
        ResetPosition()
        return
    end

    if command == "debug" then
        DebugInfo()
        return
    end

    if string.sub(command, 1, 6) == "colors" then
        local wanted = string.match(command, "^colors%s+(%S+)")
        if wanted ~= "blood" and wanted ~= "classic" then
            wanted = (savedVars.palette == "classic") and "blood" or "classic"
        end
        savedVars.palette = wanted
        UpdateDisplay()
        RefreshPreview()
        d(DISPLAY_NAME .. ": " .. string.format(T("MSG_COLORS"), wanted))
        return
    end

    if command == "" or command == "toggle" then
        SetUnlocked(not savedVars.unlocked)
        return
    end

    d(DISPLAY_NAME .. ": " .. T("MSG_USAGE"))
end

local function CreateUI()
    local wm = WINDOW_MANAGER

    control = wm:CreateTopLevelWindow(ADDON_NAME .. "Control")
    control:SetDimensions(1, 1)  -- real size is set by UpdateDisplay()
    control:SetDrawLevel(250)
    control:SetMouseEnabled(false)
    control:SetMovable(false)
    control:SetClampedToScreen(true)

    -- Everything visible lives in `content`: the scene fragment owns the
    -- visibility of `control`, we own the visibility of `content`.
    content = wm:CreateControl(ADDON_NAME .. "Content", control, CT_CONTROL)
    content:SetAnchorFill(control)
    content:SetHidden(true)

    hudView = CreateView(content, ADDON_NAME)

    -- Shown only in move mode, so you never have to remember the command.
    hint = wm:CreateControl(ADDON_NAME .. "Hint", content, CT_LABEL)
    hint:SetFont("ZoFontGameBold")
    hint:SetColor(1, 0.82, 0.3, 1)
    hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    hint:SetAnchor(BOTTOM, content, TOP, 0, -6)
    hint:SetText(T("HINT_DRAG"))
    hint:SetHidden(true)

    -- Dragging uses ESO's own SetMovable (see UpdateEditorVisuals); when the
    -- move ends, ESO tells us here and we save the position.
    control:SetHandler("OnMoveStop", function()
        SavePosition()
    end)

    -- Only show the plate in the HUD (and the HUD with the cursor, e.g. chat).
    -- Menus, inventory, map, settings... are other scenes, so it hides there.
    local fragment = ZO_SimpleSceneFragment:New(control)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

local function StartTimer()
    EVENT_MANAGER:RegisterForUpdate(updateTimerName, UPDATE_INTERVAL_MS, UpdateDisplay)
end

local function RegisterEvents()
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, function(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId)
        if unitTag ~= "player" then
            return
        end

        -- Vampire stage changed/gained/faded. Re-read the live buff list instead
        -- of trusting the event payload alone, so the displayed stage always
        -- reflects the current state after transitions and reloads.
        if STAGE_BY_ABILITY_ID[abilityId] then
            UpdateDisplay()
            return
        end

        -- A stage may have disappeared while another stage is already being
        -- inserted. A complete rescan handles that transition safely.
        UpdateDisplay()
    end)

    EVENT_MANAGER:RegisterForEvent(fullUpdateEventName, EVENT_EFFECTS_FULL_UPDATE, function()
        UpdateDisplay()
    end)

    EVENT_MANAGER:RegisterForEvent(deactivatedEventName, EVENT_PLAYER_DEACTIVATED, function()
        -- Persist only an actual saved/user position. A fresh default remains
        -- center-anchored across reloads and zone transitions.
        if savedVars.position.valid then
            SavePosition()
        end
    end)

    EVENT_MANAGER:RegisterForEvent(activatedEventName, EVENT_PLAYER_ACTIVATED, function()
        if not savedVars.position.valid then
            ApplyDefaultPosition()
        else
            ApplyStoredPosition()
        end

        UpdateEditorVisuals()

        -- Some UI/layout anchors settle just after player activation. Reapply
        -- the saved top-left point once the new zone's UI has finished settling.
        zo_callLater(function()
            if savedVars.position.valid then
                ApplyStoredPosition()
            else
                ApplyDefaultPosition()
            end
        end, 100)

        -- Do several immediate scans after activation. Some long-term player
        -- buffs are populated slightly after EVENT_PLAYER_ACTIVATED on reload.
        UpdateDisplay()
        zo_callLater(UpdateDisplay, 250)
        zo_callLater(UpdateDisplay, 750)
        zo_callLater(UpdateDisplay, 1500)
    end)

end

local function ClampNumber(value, minValue, maxValue, fallback)
    if type(value) ~= "number" then
        return fallback
    end
    return math.max(minValue, math.min(maxValue, value))
end

local function NormalizeSavedVars()
    -- Existing account settings are preserved; missing keys receive safe defaults.
    savedVars.scale = ClampNumber(savedVars.scale, 0.75, 1.50, DEFAULTS.scale)
    savedVars.iconSize = ClampNumber(savedVars.iconSize, 32, 120, DEFAULTS.iconSize)
    savedVars.timerFontSize = ClampNumber(savedVars.timerFontSize, 16, 28, DEFAULTS.timerFontSize)
    savedVars.backgroundOpacity = ClampNumber(savedVars.backgroundOpacity, 0, 1, DEFAULTS.backgroundOpacity)
    savedVars.frameOpacity = ClampNumber(savedVars.frameOpacity, 0, 1, DEFAULTS.frameOpacity)
    savedVars.warningMinutes = ClampNumber(savedVars.warningMinutes, 1, 30, DEFAULTS.warningMinutes)

    if savedVars.palette ~= "blood" and savedVars.palette ~= "classic" then
        savedVars.palette = DEFAULTS.palette
    end
    if savedVars.timerFormat ~= "compact" and savedVars.timerFormat ~= "clock" then
        savedVars.timerFormat = DEFAULTS.timerFormat
    end
    if type(savedVars.showFrame) ~= "boolean" then savedVars.showFrame = DEFAULTS.showFrame end
    if type(savedVars.showBackground) ~= "boolean" then savedVars.showBackground = DEFAULTS.showBackground end
    if type(savedVars.showIcon) ~= "boolean" then savedVars.showIcon = DEFAULTS.showIcon end
    if type(savedVars.showTimer) ~= "boolean" then savedVars.showTimer = DEFAULTS.showTimer end
    if type(savedVars.showBloodDrops) ~= "boolean" then savedVars.showBloodDrops = DEFAULTS.showBloodDrops end
    if type(savedVars.showWhenNotVampire) ~= "boolean" then savedVars.showWhenNotVampire = DEFAULTS.showWhenNotVampire end
    if type(savedVars.unlocked) ~= "boolean" then savedVars.unlocked = DEFAULTS.unlocked end

    -- v1.1.x stored the bar separately. v1.2.0 intentionally uses the blood
    -- drops toggle as the single source of truth for both drops and the bar.
    savedVars.showProgressBar = nil

    local visibility = GetVisibilityConfig()
    local repaired = false
    if not (visibility.showIcon or visibility.showBloodDrops) then
        savedVars.showBloodDrops = true
        visibility.showBloodDrops = true
        repaired = true
    end
    if not IsVisibilityConfigurationValidForAllStages(visibility) then
        -- Preserve the user's icon/drop choice where possible; restore only
        -- the missing timer preference when drops are disabled.
        if not visibility.showBloodDrops and not visibility.showTimer then
            savedVars.showTimer = true
            visibility.showTimer = true
            repaired = true
        end
    end

    return repaired
end

RefreshWidget = function()
    UpdateEditorVisuals()
    UpdateDisplay()
    RefreshPreview()
end

local function RegisterSettings()
    if not LibAddonMenu2 then
        return   -- optional library: the tracker works without a settings panel
    end

    local panelId = ADDON_NAME .. "Options"
    settingsPanel = LibAddonMenu2:RegisterAddonPanel(panelId, {
        type = "panel",
        name = DISPLAY_NAME,
        displayName = DISPLAY_NAME,
        author = "Weyland",
        version = "1.2.0",
        slashCommand = "/vstsettings",
        registerForRefresh = true,
        registerForDefaults = true,
        resetFunc = function()
            -- LAM's global "Reset to defaults" also resets the widget position.
            ResetPosition()
        end,
    })

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
        if panel == settingsPanel then
            RefreshPreview()
        end
    end)

    local options = {
        {
            type = "description",
            text = T("DESC"),
        },
        {   -- live preview: the same plate as on screen, drawn by the same code
            type = "custom", reference = ADDON_NAME .. "_Preview", width = "full",
            minHeight = function() return PREVIEW_HEIGHT end,
            maxHeight = function() return PREVIEW_HEIGHT end,
            createFunc = CreatePreview,
            refreshFunc = RefreshPreview,
        },
        {
            type = "dropdown",
            name = T("PREVIEW_STAGE"),
            tooltip = T("PREVIEW_STAGE_TT"),
            choices = { T("STAGE_1"), T("STAGE_2"), T("STAGE_3"), T("STAGE_4") },
            choicesValues = { 1, 2, 3, 4 },
            default = 3,
            getFunc = function() return previewStage end,
            setFunc = function(value)
                previewStage = value
                RefreshWidget()
                if settingsPanel then
                    CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", settingsPanel)
                end
            end,
        },
        { type = "header", name = T("HDR_POSITION") },
        {
            type = "button",
            name = function()
                return savedVars.unlocked and T("BTN_LOCK") or T("BTN_UNLOCK")
            end,
            tooltip = T("BTN_MOVE_TT"),
            func = function()
                SetUnlocked(not savedVars.unlocked)
            end,
        },
        {
            type = "button",
            name = T("BTN_RESET"),
            tooltip = T("BTN_RESET_TT"),
            func = ResetPosition,
        },
        {
            type = "slider",
            name = T("SCALE"),
            tooltip = T("SCALE_TT"),
            min = 0.75, max = 1.50, step = 0.05, decimals = 2,
            default = DEFAULTS.scale,
            getFunc = function() return savedVars.scale end,
            setFunc = function(value)
                savedVars.scale = value
                RefreshWidget()
            end,
        },
        {
            type = "slider",
            name = T("ICON"),
            tooltip = T("ICON_TT"),
            min = 32, max = 120, step = 2,
            default = DEFAULTS.iconSize,
            getFunc = function() return savedVars.iconSize end,
            setFunc = function(value)
                savedVars.iconSize = value
                RefreshWidget()
            end,
        },
        { type = "header", name = T("HDR_APPEARANCE") },
        {
            type = "dropdown",
            name = T("PALETTE"),
            tooltip = T("PALETTE_TT"),
            choices = { T("PALETTE_BLOOD"), T("PALETTE_CLASSIC") },
            choicesValues = { "blood", "classic" },
            default = DEFAULTS.palette,
            getFunc = function() return savedVars.palette end,
            setFunc = function(value)
                savedVars.palette = value
                RefreshWidget()
            end,
        },
        {
            type = "checkbox",
            name = T("SHOW_BACKGROUND"),
            tooltip = T("SHOW_BACKGROUND_TT"),
            default = DEFAULTS.showBackground,
            getFunc = function() return savedVars.showBackground end,
            setFunc = function(value)
                savedVars.showBackground = value
                RefreshWidget()
            end,
        },
        {
            type = "slider",
            name = T("BG_OPACITY"),
            tooltip = T("BG_OPACITY_TT"),
            min = 0, max = 1, step = 0.05, decimals = 2,
            default = DEFAULTS.backgroundOpacity,
            disabled = function() return not savedVars.showBackground end,
            getFunc = function() return savedVars.backgroundOpacity end,
            setFunc = function(value)
                savedVars.backgroundOpacity = value
                RefreshWidget()
            end,
        },
        {
            type = "slider",
            name = T("FONT_SIZE"),
            tooltip = T("FONT_SIZE_TT"),
            min = 16, max = 28, step = 1,
            default = DEFAULTS.timerFontSize,
            getFunc = function() return savedVars.timerFontSize end,
            setFunc = function(value)
                savedVars.timerFontSize = value
                RefreshWidget()
            end,
        },
        {
            type = "checkbox",
            name = T("SHOW_FRAME"),
            tooltip = T("SHOW_FRAME_TT"),
            default = DEFAULTS.showFrame,
            getFunc = function() return savedVars.showFrame end,
            setFunc = function(value)
                savedVars.showFrame = value
                RefreshWidget()
            end,
        },
        {
            type = "slider",
            name = T("FRAME_OPACITY"),
            tooltip = T("FRAME_OPACITY_TT"),
            min = 0, max = 1, step = 0.05, decimals = 2,
            default = DEFAULTS.frameOpacity,
            disabled = function() return not savedVars.showFrame end,
            getFunc = function() return savedVars.frameOpacity end,
            setFunc = function(value)
                savedVars.frameOpacity = value
                RefreshWidget()
            end,
        },
        { type = "header", name = T("HDR_ELEMENTS") },
        { type = "description", text = T("VISIBILITY_RULES") },
        {
            type = "checkbox",
            name = T("SHOW_ICON"),
            tooltip = function() return GetVisibilityTooltip("icon") end,
            default = DEFAULTS.showIcon,
            disabled = function()
                return savedVars.showIcon and not CanToggleVisibility("icon")
            end,
            getFunc = function() return savedVars.showIcon end,
            setFunc = function(value)
                SetVisibilityOption("icon", value)
            end,
        },
        {
            type = "checkbox",
            name = T("SHOW_TIMER"),
            tooltip = function() return GetVisibilityTooltip("timer") end,
            default = DEFAULTS.showTimer,
            disabled = function()
                return previewStage == 1 or (savedVars.showTimer and not CanToggleVisibility("timer"))
            end,
            getFunc = function() return savedVars.showTimer end,
            setFunc = function(value)
                SetVisibilityOption("timer", value)
            end,
        },
        {
            type = "checkbox",
            name = T("SHOW_DROPS"),
            tooltip = function() return GetVisibilityTooltip("drops") end,
            default = DEFAULTS.showBloodDrops,
            disabled = function()
                return savedVars.showBloodDrops and not CanToggleVisibility("drops")
            end,
            getFunc = function() return savedVars.showBloodDrops end,
            setFunc = function(value)
                SetVisibilityOption("drops", value)
            end,
        },
        {
            type = "dropdown",
            name = T("TIMER_FORMAT"),
            tooltip = T("TIMER_FORMAT_TT"),
            choices = { T("FORMAT_COMPACT"), T("FORMAT_CLOCK") },
            choicesValues = { "compact", "clock" },
            default = DEFAULTS.timerFormat,
            getFunc = function() return savedVars.timerFormat end,
            setFunc = function(value)
                savedVars.timerFormat = value
                RefreshWidget()
            end,
        },
        {
            type = "slider",
            name = T("WARN"),
            tooltip = T("WARN_TT"),
            min = 1, max = 30, step = 1,
            default = DEFAULTS.warningMinutes,
            getFunc = function() return savedVars.warningMinutes end,
            setFunc = function(value)
                savedVars.warningMinutes = value
                RefreshWidget()
            end,
        },
        { type = "header", name = T("HDR_BEHAVIOR") },
        {
            type = "checkbox",
            name = T("SHOW_SAMPLE"),
            tooltip = T("SHOW_SAMPLE_TT"),
            default = DEFAULTS.showWhenNotVampire,
            getFunc = function() return savedVars.showWhenNotVampire end,
            setFunc = function(value)
                savedVars.showWhenNotVampire = value
                RefreshWidget()
            end,
        },
        { type = "header", name = T("HDR_SUPPORT") },
        { type = "description", text = T("SUPPORT_TEXT") },
    }

    LibAddonMenu2:RegisterOptionControls(panelId, options)
end

local function Initialize()
    savedVars = ZO_SavedVars:NewAccountWide("WeylandVampireStageTrackerSavedVars", 1, nil, DEFAULTS)
    local visibilityWasRepaired = NormalizeSavedVars()

    -- Timer values from pre-0.1.11 builds are legacy and must not be used:
    -- the ESO buff API is now the single source of truth for the stage timer.
    if savedVars.timer then
        savedVars.timer.stage = nil
        savedVars.timer.remaining = nil
    end

    CreateUI()
    RegisterSettings()

    if visibilityWasRepaired then
        zo_callLater(function()
            d(DISPLAY_NAME .. ": " .. T("MSG_VISIBILITY_REPAIRED"))
        end, 1000)
    end

    SLASH_COMMANDS["/vst"] = HandleSlashCommand
    SLASH_COMMANDS["/vampirestage"] = HandleSlashCommand

    RegisterEvents()
    StartTimer()

    if savedVars.position.valid then
        ApplyStoredPosition()
    else
        -- Keep the default center anchor until the user actually moves the HUD.
        ApplyDefaultPosition()
    end

    UpdateEditorVisuals()
    UpdateDisplay()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Load", EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "Load", EVENT_ADD_ON_LOADED)
    Initialize()
end)
