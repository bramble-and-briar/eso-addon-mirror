-- Arclight Taunt 1.0.3 | HUD module
-- Loaded in manifest order; requires Core.lua and uses its shared namespace.
local A = ArclightTaunt
local T = A.T
local BOSS_ICON_TEXTURE = A.BOSS_ICON_TEXTURE
local BOSS_WARNING_TEXTURE = A.BOSS_WARNING_TEXTURE
local BOSS_EARLY_TEXTURE = A.BOSS_EARLY_TEXTURE
local C = A.C
local COLUMN_GAP = A.COLUMN_GAP
local Clamp = A.Clamp
local FONT_HEADER = A.FONT_HEADER
local FONT_MORE = A.FONT_MORE
local FONT_NAME = A.FONT_NAME
local FONT_TIME = A.FONT_TIME
local FOOTER_HEIGHT = A.FOOTER_HEIGHT
local HEADER_HEIGHT = A.HEADER_HEIGHT
local Label = A.Label
local MAX_PER_COLUMN = A.MAX_PER_COLUMN
local MEDIA_TRACK_PATH = A.MEDIA_TRACK_PATH
local Now = A.Now
local RETICLE_SCAN_INTERVAL = A.RETICLE_SCAN_INTERVAL
local ROW_HEIGHT = A.ROW_HEIGHT
local SMART_TIME_DECIMAL_AT = A.SMART_TIME_DECIMAL_AT
local SetColor = A.SetColor
local Solid = A.Solid
local WM = A.WM

local function GetHeaderHeight()
    -- No header needs to appear suddenly when positioning the HUD. The full
    -- HUD is draggable and the existing move hint remains below the entries.
    return A.saved.header and HEADER_HEIGHT or 0
end
local function GetColumnWidth()
    return A.saved.width or 280
end
local function GetWidth()
    return GetColumnWidth() * A.saved.columns + COLUMN_GAP * (A.saved.columns - 1)
end
-- Saved x/y are intentionally never clamped to one person's monitor. The
-- temporary screen position may differ at smaller resolutions, but switching
-- back restores the original saved layout.
local function Layout()
    if not A.root then return end
    A.root:ClearAnchors()
    local anchor = A.saved.growUp and BOTTOMLEFT or TOPLEFT
    A.root:SetAnchor(anchor, GuiRoot, TOPLEFT,
        A.screenX or A.saved.x, A.screenY or A.saved.y)
    A.root:SetScale(A.renderScale or A.saved.scale)
end
local function ScreenBounds(width, height)
    local sw = GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth()
    local sh = GuiRoot and GuiRoot.GetHeight and GuiRoot:GetHeight()
    if type(sw) ~= "number" or type(sh) ~= "number" or sw <= 0 or sh <= 0 then
        return
    end
    -- Fit the complete two-column view when possible, not only its origin.
    local scale = A.saved.scale
    if A.saved.fitToScreen then
        scale = math.min(scale, (sw - 8) / math.max(1, width),
            (sh - 8) / math.max(1, height))
    end
    scale = math.max(0.1, scale)
    local x = Clamp(A.saved.x, 0, math.max(0, sw - width * scale))
    local y = A.saved.growUp
        and Clamp(A.saved.y, height * scale, sh)
        or Clamp(A.saved.y, 0, math.max(0, sh - height * scale))
    if A.screenX ~= x or A.screenY ~= y or A.renderScale ~= scale then
        local changedScale = A.renderScale ~= scale
        A.screenX, A.screenY, A.renderScale = x, y, scale
        Layout()
        if changedScale then A.ApplyMedia() end
    end
end
local function SavePosition()
    A.root:StopMovingOrResizing()
    A.saved.x = math.floor(A.root:GetLeft() + 0.5)
    local bottom = A.root.GetBottom and A.root:GetBottom()
    A.saved.y = math.floor((A.saved.growUp and (bottom or A.root:GetTop())
        or A.root:GetTop()) + 0.5)
    A.screenX, A.screenY = nil, nil
    Layout()
end
-- In edit mode the *whole* HUD is an explicit drag surface. Unlike the old
-- click-once-and-auto-lock approach, the user can reposition it repeatedly.
-- The LAM checkbox remains checked until the user intentionally locks it.
local function SetMoving(moving)
    if A.moving == moving then return end
    A.moving = moving
    A.root:SetMouseEnabled(moving)
    A.root:SetMovable(moving)
    A.dragSurface:SetMouseEnabled(moving)
    A.SetHidden(A.dragSurface, not moving)
    A.SetHidden(A.moveTint, not moving)
    if not moving then
        if A.dragActive then
            SavePosition()
            A.dragActive = false
        end
    end
end

local function NewRow()
    local box = WM:CreateControl(nil, A.root, CT_CONTROL)
    box:SetDimensions(GetColumnWidth(), ROW_HEIGHT)
    A.SetHidden(box, true)

    local bg = Solid(box, C.row)
    bg:SetAnchorFill(box)

    local bgTexture = WM:CreateControl(nil, box, CT_TEXTURE)
    bgTexture:SetAnchorFill(box)
    A.SetHidden(bgTexture, true)

    -- Optional large progress display: the coloured portion spans the row's
    -- entire height and drains left-to-right. It is a tint, not a bright solid
    -- plate, so all white/gold names and warning-coloured timers stay legible.
    local fullFill = Solid(box, C.fullSafe)
    fullFill:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0)
    fullFill:SetDimensions(GetColumnWidth(), ROW_HEIGHT)
    if fullFill.SetPixelRoundingEnabled then fullFill:SetPixelRoundingEnabled(true) end
    A.SetHidden(fullFill, true)

    -- The pronounced focus style draws a subtle blue wash and two fine outline
    -- edges behind row content. Unlike a solid highlight, this preserves the
    -- red/yellow/turquoise urgency accent and timer colour.
    local focusWash = Solid(box, C.focusWash)
    focusWash:SetAnchorFill(box)
    A.SetHidden(focusWash, true)

    local focusTop = Solid(box, C.focusLine)
    focusTop:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0)
    focusTop:SetDimensions(GetColumnWidth(), 1)
    A.SetHidden(focusTop, true)

    local focusBottom = Solid(box, C.focusLine)
    focusBottom:SetAnchor(BOTTOMLEFT, box, BOTTOMLEFT, 0, -5)
    focusBottom:SetDimensions(GetColumnWidth(), 1)
    A.SetHidden(focusBottom, true)

    local accent = Solid(box, C.safe)
    accent:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0)
    accent:SetDimensions(5, ROW_HEIGHT - 4)

    local chosen = Solid(box, C.selected)
    chosen:SetAnchor(TOPRIGHT, box, TOPRIGHT, 0, 0)
    chosen:SetDimensions(5, ROW_HEIGHT - 4)
    A.SetHidden(chosen, true)

    -- A tiny self-contained skull icon; no extra dependency or world marker.
    local bossIcon = WM:CreateControl(nil, box, CT_TEXTURE)
    bossIcon:SetTexture(BOSS_ICON_TEXTURE)
    SetColor(bossIcon, C.bossIcon)
    bossIcon:SetAnchor(TOPLEFT, box, TOPLEFT, 10, 3)
    bossIcon:SetDimensions(18, 18)
    if bossIcon.SetPixelRoundingEnabled then bossIcon:SetPixelRoundingEnabled(true) end
    A.SetHidden(bossIcon, true)

    local name = Label(box, FONT_NAME, C.white)
    name:SetAnchor(TOPLEFT, box, TOPLEFT, 12, 1)
    name:SetDimensions(GetColumnWidth() - 79, ROW_HEIGHT - 4)

    -- The timer sits directly on the row background, without a separate plate.
    -- Leave a fixed-width column so lengthy enemy names cannot overlap the clock.
    local time = Label(box, FONT_TIME, C.safe, TEXT_ALIGN_RIGHT)
    time:SetAnchor(TOPRIGHT, box, TOPRIGHT, -9, 1)
    time:SetDimensions(53, ROW_HEIGHT - 4)

    -- Auxiliary badge occupies space *between* enemy name and countdown.
    -- No background plate: compact and legible at high target counts.
    local badge = Label(box, FONT_MORE, C.immunity, TEXT_ALIGN_RIGHT)
    badge:SetAnchor(TOPRIGHT, box, TOPRIGHT, -66, 1)
    badge:SetDimensions(49, ROW_HEIGHT - 4)
    A.SetHidden(badge, true)

    local track = Solid(box, C.track)
    -- ESO rounds the texture's final screen rectangle to device pixels.
    -- Avoid differently sized strips in adjacent rows at 110% HUD scaling.
    if track.SetPixelRoundingEnabled then track:SetPixelRoundingEnabled(true) end
    track:SetAnchor(BOTTOMLEFT, box, BOTTOMLEFT, 0, 0)
    track:SetDimensions(GetColumnWidth(), 4)

    local trackTexture = WM:CreateControl(nil, box, CT_TEXTURE)
    trackTexture:SetTexture(MEDIA_TRACK_PATH)
    if trackTexture.SetPixelRoundingEnabled then trackTexture:SetPixelRoundingEnabled(true) end
    trackTexture:SetAnchor(BOTTOMLEFT, box, BOTTOMLEFT, 0, 0)
    trackTexture:SetDimensions(GetColumnWidth(), 4)
    A.SetHidden(trackTexture, true)

    local fill = Solid(box, C.safe)
    if fill.SetPixelRoundingEnabled then fill:SetPixelRoundingEnabled(true) end
    fill:SetAnchor(BOTTOMLEFT, box, BOTTOMLEFT, 0, 0)
    fill:SetDimensions(GetColumnWidth(), 4)

    -- Kept separate from the existing solid bar. Do not SetTexture("") on
    -- a previously textured control; ESO can expose a white fallback.
    local mediaFill = Solid(box, C.safe)
    if mediaFill.SetPixelRoundingEnabled then mediaFill:SetPixelRoundingEnabled(true) end
    mediaFill:SetAnchor(BOTTOMLEFT, box, BOTTOMLEFT, 0, 0)
    mediaFill:SetDimensions(GetColumnWidth(), 4)
    A.SetHidden(mediaFill, true)

    -- Full-row focus outline is intentionally created last, above the coloured
    -- fill and text. Its 2px edges remain discernible at 110% UI scaling.
    local fullFocusTop = Solid(box, C.focusLineFull)
    fullFocusTop:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0)
    fullFocusTop:SetDimensions(GetColumnWidth(), 2)
    A.SetHidden(fullFocusTop, true)
    local fullFocusBottom = Solid(box, C.focusLineFull)
    fullFocusBottom:SetAnchor(BOTTOMLEFT, box, BOTTOMLEFT, 0, 0)
    fullFocusBottom:SetDimensions(GetColumnWidth(), 2)
    A.SetHidden(fullFocusBottom, true)
    local fullFocusRight = Solid(box, C.focusLineFull)
    fullFocusRight:SetAnchor(TOPRIGHT, box, TOPRIGHT, 0, 0)
    fullFocusRight:SetDimensions(3, ROW_HEIGHT)
    A.SetHidden(fullFocusRight, true)
    local fullFocusLeft = Solid(box, C.focusLineFull)
    fullFocusLeft:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0)
    fullFocusLeft:SetDimensions(3, ROW_HEIGHT)
    A.SetHidden(fullFocusLeft, true)
    for _, outline in ipairs({ fullFocusTop, fullFocusBottom, fullFocusRight, fullFocusLeft }) do
        if outline.SetPixelRoundingEnabled then outline:SetPixelRoundingEnabled(true) end
    end

    return {box = box, bg = bg, bgTexture = bgTexture, fullFill = fullFill, accent = accent, chosen = chosen,
            bossIcon = bossIcon, focusWash = focusWash, focusTop = focusTop,
            focusBottom = focusBottom, name = name, time = time, badge = badge,
            track = track, trackTexture = trackTexture, fill = fill,
            fullFocusTop = fullFocusTop, fullFocusBottom = fullFocusBottom,
            fullFocusRight = fullFocusRight, fullFocusLeft = fullFocusLeft,
            mediaFill = mediaFill, useMediaFill = false}
end

-- Two controls are created once and reused. The compact early slot has a fixed
-- position below the red slot, so neither warning jumps when the other changes.
local function MakeBossAlert(kind)
    local compact = kind == "early"
    local alert = A.bossAlerts[kind]
    alert.width, alert.height = 458, compact and 56 or 88
    alert.offsetY, alert.introSlide = compact and 96 or 0, compact and 0 or 12
    alert.revealDistance = compact and 64 or nil
    alert.textWidth = compact and 390 or 370
    alert.titleSize, alert.subtitleSize = compact and 16 or 20, compact and 14 or 17
    alert.titleMinimum, alert.subtitleMinimum = 10, compact and 10 or 11
    local root = WM:CreateTopLevelWindow(compact and "ArclightTauntBossEarlyAlert" or "ArclightTauntBossAlert")
    alert.root = root
    root:SetDimensions(alert.width, alert.height)
    root:SetDrawTier(DT_HIGH)
    root:SetMouseEnabled(false)
    A.SetHidden(root, true)
    root:SetHandler("OnUpdate", function(_, time)
        if kind == "expired" then A.ProcessBossPreview(time or Now()) end
        if alert.visibleUntil then A.UpdateBossAlert(time or Now(), kind) end
    end)
    local body = root
    if compact then
        root:SetAutoRectClipChildren(true)
        body = WM:CreateControl(nil, root, CT_CONTROL)
        body:SetDimensions(alert.width, alert.height)
        body:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
        alert.content, alert.contentOffset = body, 0
    end
    local background = WM:CreateControl(nil, body, CT_TEXTURE)
    background:SetTexture(compact and BOSS_EARLY_TEXTURE or BOSS_WARNING_TEXTURE)
    background:SetAnchorFill(body)
    SetColor(background, C.alertBackground, A.saved.bossAlertOpacity / 100)
    alert.backgroundControl = background

    local edgeColor = compact and C.safe or C.alertEdge
    local hairColor = compact and C.alertEarlyHairline or C.alertHairline
    alert.edge = Solid(body, edgeColor)
    alert.edge:SetAnchor(TOPLEFT, body, TOPLEFT, 0, 0)
    alert.edge:SetDimensions(7, alert.height)
    alert.icon = WM:CreateControl(nil, body, CT_TEXTURE)
    alert.icon:SetTexture(BOSS_ICON_TEXTURE)
    alert.icon:SetAnchor(TOPLEFT, body, TOPLEFT, 17, compact and 15 or 23)
    alert.icon:SetDimensions(compact and 26 or 40, compact and 26 or 40)
    SetColor(alert.icon, C.bossIcon)

    alert.title = Label(body, FONT_HEADER, compact and C.alertEarlyTitle or C.alertTitle)
    alert.title:SetAnchor(TOPLEFT, body, TOPLEFT, compact and 56 or 73, compact and 6 or 13)
    alert.title:SetDimensions(alert.textWidth, compact and 22 or 32)
    alert.title:SetText("")
    alert.subtitle = Label(body, FONT_NAME, C.bossName)
    alert.subtitle:SetAnchor(TOPLEFT, body, TOPLEFT, compact and 56 or 73, compact and 29 or 47)
    alert.subtitle:SetDimensions(alert.textWidth, compact and 20 or 27)
    alert.subtitle:SetText("")
    alert.measure = WM:CreateControl(nil, root, CT_LABEL)
    alert.measure:SetDimensions(10000, 1000)
    A.SetHidden(alert.measure, true)
    local divider = Solid(body, compact and C.alertEarlyHairline or {0.57, 0.37, 0.43, 0.55})
    divider:SetAnchor(TOPLEFT, body, TOPLEFT, compact and 49 or 67, compact and 8 or 13)
    divider:SetDimensions(1, compact and 40 or 63)
    alert.topLine = Solid(body, hairColor)
    alert.topLine:SetAnchor(TOPLEFT, body, TOPLEFT, 0, 0)
    alert.topLine:SetDimensions(alert.width, 2)
    alert.bottomLine = Solid(body, hairColor)
    alert.bottomLine:SetAnchor(BOTTOMLEFT, body, BOTTOMLEFT, 0, 0)
    alert.bottomLine:SetDimensions(alert.width, 1)
    local track = Solid(body, compact and {0.10, 0.30, 0.27, 0.65} or {0.33, 0.16, 0.22, 0.65})
    track:SetAnchor(BOTTOMLEFT, body, BOTTOMLEFT, 0, -3)
    track:SetDimensions(alert.width, 3)
    alert.timerFill = Solid(body, edgeColor)
    alert.timerFill:SetAnchor(BOTTOMLEFT, body, BOTTOMLEFT, 0, -3)
    alert.timerFill:SetDimensions(alert.width, 3)
end
local function MakeUI()
    local root = WM:CreateTopLevelWindow("ArclightTauntHUD")
    A.root = root
    root:SetDimensions(GetWidth(), HEADER_HEIGHT)
    root:SetDrawTier(DT_HIGH)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetMovable(false)
    A.SetHidden(root, true)
    Layout()

    A.headerBG = Solid(root, C.header)
    A.headerBG:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
    A.headerBG:SetDimensions(GetWidth(), HEADER_HEIGHT)

    A.headerStripe = Solid(root, C.safe)
    A.headerStripe:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
    A.headerStripe:SetDimensions(3, HEADER_HEIGHT)

    A.heading = Label(root, FONT_HEADER, C.white)
    A.heading:SetAnchor(TOPLEFT, root, TOPLEFT, 10, 0)
    A.heading:SetDimensions(88, HEADER_HEIGHT)
    A.heading:SetText("ARCLIGHT")

    A.counter = Label(root, FONT_HEADER, C.muted, TEXT_ALIGN_RIGHT)
    A.counter:SetAnchor(TOPRIGHT, root, TOPRIGHT, -7, 0)
    A.counter:SetDimensions(139, HEADER_HEIGHT)

    A.footer = Solid(root, C.header)
    A.SetHidden(A.footer, true)
    A.footer:SetDimensions(GetWidth(), FOOTER_HEIGHT)
    A.more = Label(root, FONT_MORE, C.muted)
    A.SetHidden(A.more, true)
    A.more:SetDimensions(GetWidth() - 14, FOOTER_HEIGHT)

    for i = 1, 2 * MAX_PER_COLUMN do
        A.rows[i] = NewRow()
    end

    -- Keep the working drag behavior; create a separate full-size mouse target
    -- *last* so the text/row textures never consume the dragging gestures.
    A.moveTint = Solid(root, C.moveTint)
    A.moveTint:SetAnchorFill(root)
    A.SetHidden(A.moveTint, true)

    A.dragSurface = WM:CreateControl(nil, root, CT_CONTROL)
    A.dragSurface:SetAnchorFill(root)
    A.dragSurface:SetMouseEnabled(false)
    A.SetHidden(A.dragSurface, true)
    A.dragSurface:SetHandler("OnMouseDown", function(_, button)
        if A.moving and button == MOUSE_BUTTON_INDEX_LEFT then
            A.dragActive = true
            root:StartMoving()
        end
    end)
    A.dragSurface:SetHandler("OnMouseUp", function(_, button)
        if A.moving and A.dragActive and button == MOUSE_BUTTON_INDEX_LEFT then
            SavePosition() -- StopMovingOrResizing, persist X/Y and re-anchor
            A.dragActive = false
        end
    end)

    A.moveHint = Label(root, FONT_MORE, C.white, TEXT_ALIGN_CENTER)
    A.moveHint:SetDimensions(GetWidth(), 18)
    A.SetHidden(A.moveHint, true)
    A.moveHint:SetText(T("HOLD LEFT CLICK + DRAG   |   LOCK IN SETTINGS"))

    MakeBossAlert("expired")
    MakeBossAlert("early")
    A.PositionBossAlerts()
end

local function InWorldHUD()
    if A.moving or A.demo or not A.saved.hideInMenus then return true end
    if not SCENE_MANAGER or type(SCENE_MANAGER.IsShowing) ~= "function" then
        return true -- be permissive on clients where scene support is absent
    end
    return SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
end
local function RenderRow(r, t, i, rowsPerCol, headerHeight, columnWidth, now, saved, fullMode)
    local col = math.floor((i - 1) / rowsPerCol)
    local line = (i - 1) % rowsPerCol
    if r.lastCol ~= col or r.lastLine ~= line or r.lastHeader ~= headerHeight or r.lastWidth ~= columnWidth
        or r.lastGap ~= saved.rowGap then
        r.box:ClearAnchors()
        r.box:SetAnchor(TOPLEFT, A.root, TOPLEFT,
            col * (columnWidth + COLUMN_GAP), headerHeight + line * (ROW_HEIGHT + saved.rowGap))
        r.lastCol, r.lastLine, r.lastHeader, r.lastWidth, r.lastGap = col, line, headerHeight, columnWidth, saved.rowGap
    end
    local expired = A.IsLost(t, now)
    local remaining = math.max(0, t.endTime - now)
    local full = math.max(0.1, t.endTime - t.startTime)
    local fraction = Clamp(remaining / full, 0, 1)
    local warning = expired or remaining <= saved.warningAt
    local danger = expired or remaining <= saved.dangerAt
    local color = danger and C.danger or (warning and C.warning or C.safe)
    local selected = saved.highlightTarget and (t.unitId == A.activeTarget or (A.demo and t.unitId == "demo3"))
    local immune = saved.showImmunity and t.immuneUntil and t.immuneUntil > now
    local stacks = saved.showTauntStacks and t.tauntStacks and t.counterEnd and t.counterEnd > now
        and t.tauntStacks >= 2

    local rowColor = C.row
    -- In full-row mode the fill itself indicates urgency; avoid a
    -- competing background tint on the unfilled part of the row.
    if saved.subtleWarningBg and not fullMode then
        rowColor = danger and C.dangerRow or (warning and C.warningRow or C.row)
    end
    if r.lastRowColor ~= rowColor or r.lastOpacity ~= saved.opacity then
        SetColor(r.bg, rowColor, saved.opacity)
        r.lastRowColor, r.lastOpacity = rowColor, saved.opacity
    end
    -- Only issue native SetColor calls when the urgency band changes.
    -- Remaining time still updates and bar widths still animate at 100 ms.
    if r.lastUrgencyColor ~= color then
        SetColor(r.accent, color)
        SetColor(r.time, color)
        SetColor(r.fill, color)
        SetColor(r.mediaFill, color)
        r.lastUrgencyColor = color
    end
    local accentWidth = danger and 7 or (warning and 5 or 3)
    if r.lastAccentWidth ~= accentWidth then
        r.accent:SetWidth(accentWidth)
        r.lastAccentWidth = accentWidth
    end
    -- The boss name uses an independent, constant high-contrast
    -- colour. Red/yellow/turquoise remain exclusive to taunt urgency.
    -- This also holds when the boss is the selected target.
    local boss = A.BossVisible(t)
    local specialBossName = boss and saved.highlightBossNames
    local nameColor = specialBossName and C.bossName or (selected and C.focus or C.white)
    if r.lastNameColor ~= nameColor then
        SetColor(r.name, nameColor)
        r.lastNameColor = nameColor
    end
    if immune then
        A.SetHidden(r.badge, false)
        if r.lastBadgeText ~= T("IMMUNE") then
            r.badge:SetText(T("IMMUNE"))
            r.lastBadgeText = T("IMMUNE")
        end
    elseif stacks then
        A.SetHidden(r.badge, false)
        local badgeText = tostring(t.tauntStacks) .. "/5"
        if r.lastBadgeText ~= badgeText then
            r.badge:SetText(badgeText)
            r.lastBadgeText = badgeText
        end
    else
        A.SetHidden(r.badge, true)
    end
    -- The focus marking stays visually separate from the severity
    -- colour: no replacing the red/yellow/turquoise countdown.
    local strongFocus = selected and saved.focusStyle == "strong"
    A.SetHidden(r.focusWash, not strongFocus)
    local focusColor = fullMode and C.focusWashFull or C.focusWash
    if r.lastFocusColor ~= focusColor then
        SetColor(r.focusWash, focusColor)
        r.lastFocusColor = focusColor
    end
    -- Retain the original thin outline in compact mode; use the new
    -- brighter three-edge outline when the whole row drains.
    A.SetHidden(r.focusTop, not strongFocus or fullMode)
    A.SetHidden(r.focusBottom, not strongFocus or fullMode)
    local fullFocus = strongFocus and fullMode
    A.SetHidden(r.fullFocusTop, not fullFocus)
    A.SetHidden(r.fullFocusBottom, not fullFocus)
    A.SetHidden(r.fullFocusRight, not fullFocus)
    A.SetHidden(r.fullFocusLeft, not fullFocus)
    A.SetHidden(r.chosen, fullMode or not selected)
    local showBoss = saved.showBossIcon and boss
    A.SetHidden(r.bossIcon, not showBoss)
    -- The skull texture and its constant bone-ivory tint do not
    -- change when a taunt's remaining time changes.
    -- Re-anchor only when boss status toggles; avoid needless work on
    -- every 100-ms update, and reserve 18px for the skull.
    if r.lastBossIcon ~= showBoss then
        r.name:ClearAnchors()
        r.name:SetAnchor(TOPLEFT, r.box, TOPLEFT, showBoss and 30 or 12, 1)
        r.lastBossIcon = showBoss
    end
    local nameWidth = columnWidth - ((immune or stacks) and 126 or 79) - (showBoss and 18 or 0)
    if r.lastNameWidth ~= nameWidth then
        r.name:SetWidth(nameWidth)
        r.lastNameWidth = nameWidth
    end
    if r.lastColumnWidth ~= columnWidth then
        r.box:SetWidth(columnWidth)
        r.track:SetWidth(columnWidth)
        r.trackTexture:SetWidth(columnWidth)
        r.focusTop:SetWidth(columnWidth)
        r.focusBottom:SetWidth(columnWidth)
        r.fullFocusTop:SetWidth(columnWidth)
        r.fullFocusBottom:SetWidth(columnWidth)
        r.lastColumnWidth = columnWidth
    end
    local barWidth = expired and 0 or math.floor(columnWidth * fraction + 0.5)
    local barHidden = expired or remaining <= 0
    -- Full-height fill OR the traditional narrow Signal strip. Never
    -- show both: duplicate visual progress becomes hard to interpret.
    if fullMode and r.lastFullBarWidth ~= barWidth then
        r.fullFill:SetWidth(barWidth)
        r.lastFullBarWidth = barWidth
    end
    local fillColor = danger and C.fullDanger or (warning and C.fullWarning or C.fullSafe)
    if r.lastFullColor ~= fillColor then
        SetColor(r.fullFill, fillColor)
        r.lastFullColor = fillColor
    end
    A.SetHidden(r.fullFill, not fullMode or barHidden or barWidth <= 0)
    A.SetHidden(r.accent, fullMode)
    A.SetHidden(r.track, fullMode or saved.texturedTrack)
    A.SetHidden(r.trackTexture, fullMode or not saved.texturedTrack)
    if not fullMode and r.lastThinBarWidth ~= barWidth then
        r.fill:SetWidth(barWidth)
        r.mediaFill:SetWidth(barWidth)
        r.lastThinBarWidth = barWidth
    end
    A.SetHidden(r.fill, fullMode or barHidden or r.useMediaFill)
    A.SetHidden(r.mediaFill, fullMode or barHidden or not r.useMediaFill)
    -- Always show numerical seconds, including expired (0,0).
    -- Explicit decimal comma avoids depending on ESO/client locale.
    local displayTime
    if expired then
        displayTime = "0,0"
    elseif saved.smartTime and remaining > SMART_TIME_DECIMAL_AT then
        displayTime = tostring(math.ceil(remaining))
    else
        -- Never prematurely show 0,0 before an actual expiration.
        displayTime = string.format("%.1f", math.ceil(remaining * 10) / 10):gsub("%.", ",")
    end
    -- Names and clock text change less often than the 100 ms HUD refresh.
    -- Skip redundant label updates to reduce UI work in large pulls.
    if r.lastDisplayTime ~= displayTime then
        r.time:SetText(displayTime)
        r.lastDisplayTime = displayTime
    end
    local displayName = t.name or T("Unknown enemy")
    if r.lastDisplayName ~= displayName then
        r.name:SetText(displayName)
        r.lastDisplayName = displayName
    end
end

local function ObserveTargets(now)
    if not A.demo and (A.reticleDirty or not A.lastReticleScan or now - A.lastReticleScan >= RETICLE_SCAN_INTERVAL) then
        A.lastReticleScan = now
        if next(A.targets) then
            A.TargetChanged()
        elseif A.activeTarget then
            A.activeTarget = nil
        end
    end
end

-- Scratch list only: QueueBossLosses retains target/generation records, never
-- this array. Clear references after consumption; returned Gather lists stay owned
-- by their caller and are deliberately not recycled.
local expiredCandidates = {}
local function UpdateTargets(now, skipSort)
    -- Catch overdue timers before Gather reaps them. A frame hitch longer
    -- than the normal two-second linger must not silently lose a boss alert.
    if not A.demo then
        for _, target in pairs(A.targets) do
            if target.endTime <= now then
                if not target.expiredAt then target.expiredAt = now end
                if not target.bossWarnQueued then
                    expiredCandidates[#expiredCandidates + 1] = target
                end
            end
        end
    end
    A.QueueBossLosses(expiredCandidates, now)
    for i = #expiredCandidates, 1, -1 do expiredCandidates[i] = nil end
    -- Pending warnings still refer to their original target/generation. Process
    -- them before Gather can remove a two-second-old loss after a frame hitch.
    A.ProcessBossWarnings(now)
    local active, lost = A.Gather(now, skipSort)
    A.ExpireBossAlert(now)
    A.CheckEarlyBossWarnings(now)
    A.ProcessBossPreview(now)
    return active, lost
end

local function RenderList(now, active, lost, items, saved)
    local total = #active + #lost
    local visible = #items
    local hidden = total - visible

    local width = GetWidth()
    local headerHeight = GetHeaderHeight()
    local rowsPerCol = (saved.columns == 2) and math.ceil(visible / 2) or saved.limit
    local rowCount = math.min(rowsPerCol, visible)
    local rowRegionHeight = rowCount * (ROW_HEIGHT + saved.rowGap)
    local footerY = headerHeight + rowRegionHeight
    local moveExtra = A.moving and 18 or 0
    local hudHeight = headerHeight + rowRegionHeight + (hidden > 0 and FOOTER_HEIGHT or 0) + moveExtra
    if A.lastRootWidth ~= width or A.lastRootHeight ~= hudHeight then
        A.root:SetDimensions(width, hudHeight)
        A.lastRootWidth, A.lastRootHeight = width, hudHeight
    end
    ScreenBounds(width, hudHeight)

    local headerShown = headerHeight > 0
    A.SetHidden(A.headerBG, not headerShown)
    A.SetHidden(A.headerStripe, not headerShown)
    A.SetHidden(A.heading, not headerShown)
    A.SetHidden(A.counter, not headerShown)
    if A.lastHeaderWidth ~= width then
        A.headerBG:SetWidth(width)
        A.lastHeaderWidth = width
    end

    local columnWidth = GetColumnWidth()
    if headerShown and (A.lastHeaderActive ~= #active or A.lastHeaderLost ~= #lost) then
        A.counter:SetText(string.format("%d %s  |  %d %s", #active, T("ACTIVE"), #lost, T("EXPIRED")))
        A.lastHeaderActive, A.lastHeaderLost = #active, #lost
    end
    if headerShown then
        local shortest = math.huge
        for _, t in ipairs(active) do shortest = math.min(shortest, t.endTime - now) end
        local headerColor = (#lost > 0 or shortest <= saved.dangerAt) and C.danger
            or (shortest <= saved.warningAt and C.warning or C.safe)
        if A.lastHeaderColor ~= headerColor then
            SetColor(A.headerStripe, headerColor)
            A.lastHeaderColor = headerColor
        end
    end

    A.SetHidden(A.footer, hidden == 0)
    A.SetHidden(A.more, hidden == 0)
    if hidden > 0 then
        if A.lastFooterWidth ~= width or A.lastFooterY ~= footerY then
            A.footer:SetWidth(width)
            A.footer:ClearAnchors()
            A.footer:SetAnchor(TOPLEFT, A.root, TOPLEFT, 0, footerY)
            A.more:ClearAnchors()
            A.more:SetAnchor(TOPLEFT, A.root, TOPLEFT, 9, footerY)
            A.more:SetWidth(width - 14)
            A.lastFooterWidth, A.lastFooterY = width, footerY
        end
        local shownLost = 0
        for _, t in ipairs(items) do if A.IsLost(t, now) then shownLost = shownLost + 1 end end
        local hiddenActive, hiddenLost = #active - (visible - shownLost), #lost - shownLost
        if A.lastHiddenActive ~= hiddenActive or A.lastHiddenLost ~= hiddenLost
            or A.lastFooterLanguage ~= A.language then
            local footerText = string.format("+%d %s (%d %s, %d %s)", hidden, T("more"),
                hiddenActive, T("active"), hiddenLost, T("expired"))
            A.more:SetText(footerText)
            A.lastFooterText = footerText
            A.lastHiddenActive, A.lastHiddenLost = hiddenActive, hiddenLost
            A.lastFooterLanguage = A.language
        end
    end
    A.SetHidden(A.moveHint, not A.moving)
    if A.moving then
        A.moveHint:SetWidth(width)
        A.moveHint:ClearAnchors()
        A.moveHint:SetAnchor(BOTTOMLEFT, A.root, BOTTOMLEFT, 0, 0)
    end

    local fullMode = saved.barDisplay == "full"
    for i = 1, #A.rows do
        local row = A.rows[i]
        A.SetHidden(row.box, i > visible)
        if i <= visible then
            RenderRow(row, items[i], i, rowsPerCol, headerHeight, columnWidth, now, saved, fullMode)
        end
    end
end

local function Tick()
    if not A.root then return end
    A.effectTickPending = nil
    local now, saved = Now(), A.saved
    local inWorld = InWorldHUD()
    ObserveTargets(now)
    local active, lost = UpdateTargets(now, not inWorld)
    local show = A.demo or A.moving or #active + #lost > 0
    local hideRoot = not show or not inWorld
    A.SetHidden(A.root, hideRoot)
    A.RefreshUpdateState()
    -- Model/warnings above keep running in menus. Selection and all enemy-row
    -- rendering resume from current data on the first visible tick.
    if hideRoot then return end
    local items = A.SelectVisible(active, lost, saved.columns * saved.limit)
    RenderList(now, active, lost, items, saved)
end


-- Public entry points used across modules.
A.GetHeaderHeight = GetHeaderHeight
A.GetColumnWidth = GetColumnWidth
A.GetWidth = GetWidth
A.Layout = Layout
A.ScreenBounds = ScreenBounds
A.SavePosition = SavePosition
A.SetMoving = SetMoving
A.NewRow = NewRow
A.MakeUI = MakeUI
A.InWorldHUD = InWorldHUD
A.Tick = Tick
