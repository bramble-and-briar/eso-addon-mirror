-- Arclight Taunt 1.1.0 | HUD module
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
local BOSS_ICON_HEIGHT_RATIO = 0.88
local FOCUS_BORDER = {0.83, 0.94, 1, 1}

local function DrawOrder(control, layer, level)
    control:SetDrawLayer(layer)
    control:SetDrawLevel(level)
end

local function GetListTopInset()
    return A.capHeight or 2
end
local function GetColumnWidth()
    return A.saved.width or 280
end
local function GetWidth()
    return GetColumnWidth() * A.saved.columns + COLUMN_GAP * (A.saved.columns - 1)
end
local function FocusEdge(horizontal)
    return A.saved.highlightTarget and (A.focusPadding or 2) or 0
end
local function MinimumRowHeight(fullMode)
    local first = A.rows[1]
    local barHeight = fullMode and 0 or (first and first.barHeight or A.saved.barHeight)
    return (A.minRowContentHeight or 0) + (fullMode and 2 or math.ceil(barHeight))
end
local function GetRowHeight(fullMode)
    return MinimumRowHeight(fullMode) + (A.saved.rowHeightExtra or 0)
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
local function ScreenBounds(width, height, resolvedScale)
    local sw = GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth()
    local sh = GuiRoot and GuiRoot.GetHeight and GuiRoot:GetHeight()
    if type(sw) ~= "number" or type(sh) ~= "number" or sw <= 0 or sh <= 0 then
        return
    end
    -- Fit the complete two-column view when possible, not only its origin.
    local scale = resolvedScale or A.saved.scale
    if A.saved.fitToScreen and not resolvedScale then
        scale = math.min(scale, (sw - 8) / math.max(1, width + 2 * FocusEdge(true)),
            (sh - 8) / math.max(1, height + 2 * FocusEdge()))
    end
    scale = math.max(0.1, scale)
    local pad, padX = FocusEdge() * scale, FocusEdge(true) * scale
    local x = Clamp(A.saved.x, padX, math.max(padX, sw - width * scale - padX))
    local y = A.saved.growUp
        and Clamp(A.saved.y, height * scale + pad, sh - pad)
        or Clamp(A.saved.y, pad, math.max(pad, sh - height * scale - pad))
    if A.screenX ~= x or A.screenY ~= y or A.renderScale ~= scale then
        local changedScale = A.renderScale ~= scale
        A.screenX, A.screenY, A.renderScale = x, y, scale
        Layout()
        if changedScale then A.ApplyMedia() end
    end
end
-- Start from the saved preference, never the preceding progress style's scale.
-- Pixel-rounded bars depend on the final scale; shrink monotonically until the
-- measured row layout fits. Pure bounded layout arithmetic, no control writes.
local function ResolveListScale(width, rowCount, full, footerHeight, moveExtra)
    local saved, scale = A.saved, A.saved.scale
    if not saved.fitToScreen then return scale end
    local sw, sh = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    if sw <= 0 or sh <= 0 then return scale end
    for _ = 1, 8 do
        local barHeight, pixelUnit = A.PixelAlignedBarHeight(scale)
        local pad = saved.highlightTarget and math.max(saved.highContrast and 3 or 2, pixelUnit) or 0
        local rowHeight = (A.minRowContentHeight or 0) + (full and 2 or math.ceil(barHeight)) + (saved.rowHeightExtra or 0)
        local height = math.max(2, pixelUnit)
            + rowCount * (rowHeight + math.max(saved.rowGap, pad)) + footerHeight + moveExtra
        local nextScale = math.max(0.1, math.min(scale, (sw - 8) / math.max(1, width + 2 * pad),
            (sh - 8) / math.max(1, height + 2 * pad)))
        if nextScale >= scale then break end
        scale = nextScale
    end
    return scale
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
    bgTexture:SetResizeToFitFile(false)
    bgTexture:SetAnchorFill(box)
    A.SetHidden(bgTexture, true)

    -- Optional large progress display: the coloured portion spans the row's
    -- entire height. Its anchor determines which edge retreats as time passes.
    -- It is a tint, not a bright solid
    -- plate, so all white/gold names and warning-coloured timers stay legible.
    local fullFill = Solid(box, C.fullSafe)
    fullFill:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0)
    fullFill:SetDimensions(GetColumnWidth(), ROW_HEIGHT)
    if fullFill.SetPixelRoundingEnabled then fullFill:SetPixelRoundingEnabled(false) end
    A.SetHidden(fullFill, true)

    -- Fixed-width surface shading gives the whole row depth, independently
    -- of the shrinking countdown fill. Existing DDS contains its own alpha.
    local surface = WM:CreateControl(nil, box, CT_TEXTURE)
    surface:SetResizeToFitFile(false)
    surface:SetTexture(A.MEDIA_BG_OBSIDIAN_PATH)
    surface:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0)
    surface:SetDimensions(GetColumnWidth(), ROW_HEIGHT)
    surface:SetColor(1, 1, 1, 1)
    A.SetHidden(surface, true)


    local accent = Solid(box, C.safe)
    accent:SetPixelRoundingEnabled(false)
    accent:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0)
    accent:SetDimensions(5, ROW_HEIGHT - 4)


    -- A tiny self-contained skull icon; no extra dependency or world marker.
    local bossIcon = WM:CreateControl(nil, box, CT_TEXTURE)
    bossIcon:SetResizeToFitFile(false)
    bossIcon:SetTexture(BOSS_ICON_TEXTURE)
    -- Trim only transparent margins at draw time; keep the skull aspect ratio.
    bossIcon:SetTextureCoords(0.125, 0.875, 0.125, 0.875)
    SetColor(bossIcon, C.bossIcon)
    bossIcon:SetAnchor(TOPLEFT, box, TOPLEFT, 10, 3)
    bossIcon:SetDimensions(18, 18 * BOSS_ICON_HEIGHT_RATIO)
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

    -- A clipped, fixed-height region keeps the narrow strip independent of
    -- texture-file dimensions and all full-height row decoration.
    local barRegion = WM:CreateControl(nil, box, CT_CONTROL)
    barRegion:SetAnchor(BOTTOMLEFT, box, BOTTOMLEFT, 0, 0)
    barRegion:SetDimensions(GetColumnWidth(), 4)
    barRegion:SetAutoRectClipChildren(true)
    local track = Solid(barRegion, C.track)
    -- ESO rounds the texture's final screen rectangle to device pixels.
    -- Avoid differently sized strips in adjacent rows at 110% HUD scaling.
    if track.SetPixelRoundingEnabled then track:SetPixelRoundingEnabled(true) end
    track:SetAnchor(BOTTOMLEFT, barRegion, BOTTOMLEFT, 0, 0)
    track:SetDimensions(GetColumnWidth(), 4)

    local trackTexture = WM:CreateControl(nil, barRegion, CT_TEXTURE)
    trackTexture:SetResizeToFitFile(false)
    trackTexture:SetTexture(MEDIA_TRACK_PATH)
    if trackTexture.SetPixelRoundingEnabled then trackTexture:SetPixelRoundingEnabled(true) end
    trackTexture:SetAnchor(BOTTOMLEFT, barRegion, BOTTOMLEFT, 0, 0)
    trackTexture:SetDimensions(GetColumnWidth(), 4)
    A.SetHidden(trackTexture, true)

    local fill = Solid(barRegion, C.safe)
    fill:SetResizeToFitFile(false)
    if fill.SetPixelRoundingEnabled then fill:SetPixelRoundingEnabled(false) end
    fill:SetAnchor(BOTTOMLEFT, barRegion, BOTTOMLEFT, 0, 0)
    fill:SetDimensions(GetColumnWidth(), 4)

    -- Kept separate from the existing solid bar. Do not SetTexture("") on
    -- a previously textured control; ESO can expose a white fallback.
    local mediaFill = Solid(barRegion, C.safe)
    mediaFill:SetResizeToFitFile(false)
    if mediaFill.SetPixelRoundingEnabled then mediaFill:SetPixelRoundingEnabled(false) end
    mediaFill:SetAnchor(BOTTOMLEFT, barRegion, BOTTOMLEFT, 0, 0)
    mediaFill:SetDimensions(GetColumnWidth(), 4)
    A.SetHidden(mediaFill, true)

    local contrastEdge = Solid(box, C.highDivider)
    if contrastEdge.SetPixelRoundingEnabled then contrastEdge:SetPixelRoundingEnabled(true) end
    contrastEdge:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0)
    contrastEdge:SetDimensions(GetColumnWidth(), 1)
    A.SetHidden(contrastEdge, true)

    -- Keep the author's preferred pale outline permanently at full strength.
    local focusOutline = {}
    for _, side in ipairs({"top", "bottom", "left", "right"}) do
        local edge = Solid(box, FOCUS_BORDER)
        if edge.SetPixelRoundingEnabled then edge:SetPixelRoundingEnabled(true) end
        DrawOrder(edge, DL_OVERLAY, 1)
        A.SetHidden(edge, true)
        focusOutline[side] = edge
    end

    -- A short light sweep runs only on the external top/bottom outline.
    -- The pale base outline never dims and the clipped glint cannot tint a bar.
    local focusViewport = WM:CreateControl(nil, box, CT_CONTROL)
    focusViewport:SetAnchor(TOPLEFT, box, TOPLEFT, -2, -2)
    focusViewport:SetAutoRectClipChildren(true)
    focusViewport:SetMouseEnabled(false)
    DrawOrder(focusViewport, DL_OVERLAY, 2)
    A.SetHidden(focusViewport, true)
    local focusSweep = WM:CreateControl(nil, focusViewport, CT_CONTROL)
    focusSweep:SetDimensions(64, ROW_HEIGHT + 4)
    local focusGlints = {}
    for i = 1, 4 do
        local glint = Solid(focusSweep, C.focusLight)
        local left = i % 2 == 1
        local first, last = left and 0 or 1, left and 1 or 0
        glint:SetGradientColors(ORIENTATION_HORIZONTAL, 1, 1, 0.98, first, 1, 1, 0.98, last)
        glint:SetAnchor(i <= 2 and TOPLEFT or BOTTOMLEFT, focusSweep, i <= 2 and TOPLEFT or BOTTOMLEFT, left and 0 or 32, 0)
        glint:SetDimensions(32, 2)
        DrawOrder(glint, DL_OVERLAY, 2)
        focusGlints[i] = glint
    end
    local progressRegion = WM:CreateControl(nil, box, CT_CONTROL)
    progressRegion:SetDimensions(GetColumnWidth(), ROW_HEIGHT)

    -- Equal default texture levels are ambiguous in ESO. Explicit ordering
    -- keeps the fill behind the fixed surface, urgency stripe, icon and text.
    DrawOrder(bg, DL_BACKGROUND, 0)
    DrawOrder(bgTexture, DL_BACKGROUND, 1)
    DrawOrder(fullFill, DL_BACKGROUND, 2)
    DrawOrder(surface, DL_BACKGROUND, 3)
    DrawOrder(barRegion, DL_CONTROLS, 0)
    DrawOrder(track, DL_CONTROLS, 0)
    DrawOrder(trackTexture, DL_CONTROLS, 1)
    DrawOrder(fill, DL_CONTROLS, 2)
    DrawOrder(mediaFill, DL_CONTROLS, 3)
    DrawOrder(accent, DL_CONTROLS, 4)
    DrawOrder(contrastEdge, DL_CONTROLS, 6)
    DrawOrder(name, DL_TEXT, 0)
    DrawOrder(time, DL_TEXT, 0)
    DrawOrder(bossIcon, DL_TEXT, 1)

    return {box = box, bg = bg, bgTexture = bgTexture, fullFill = fullFill, accent = accent,
            focusViewport = focusViewport, focusSweep = focusSweep, focusGlints = focusGlints, focusOutline = focusOutline,
            progressRegion = progressRegion,
            bossIcon = bossIcon, name = name, time = time,
            barRegion = barRegion, track = track, trackTexture = trackTexture, fill = fill,
            mediaFill = mediaFill, surface = surface,
            useMediaFill = false, contrastEdge = contrastEdge}
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
    alert.icon:SetResizeToFitFile(false)
    alert.icon:SetTexture(BOSS_ICON_TEXTURE)
    alert.icon:SetTextureCoords(0.125, 0.875, 0.125, 0.875)
    local iconWidth = compact and 32 or 48
    local iconHeight = iconWidth * BOSS_ICON_HEIGHT_RATIO
    alert.icon:SetAnchor(TOPLEFT, body, TOPLEFT, 12, (alert.height - iconHeight) / 2)
    alert.icon:SetDimensions(iconWidth, iconHeight)
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
    alert.timerFill:SetPixelRoundingEnabled(false)
end
local function MakeUI()
    local root = WM:CreateTopLevelWindow("ArclightTauntHUD")
    A.root = root
    root:SetDimensions(GetWidth(), GetListTopInset())
    root:SetDrawTier(DT_HIGH)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetMovable(false)
    A.SetHidden(root, true)
    Layout()

    -- A quiet, text-free cap above each populated column; no status header.
    A.columnCaps = {}
    for i = 1, 2 do
        local cap = WM:CreateControl(nil, root, CT_CONTROL)
        cap:SetDimensions(GetColumnWidth(), 2)
        local background = Solid(cap, C.header)
        background:SetAnchorFill(cap)
        local rails = {}
        for half = 1, 2 do
            local rail = Solid(cap, C.muted)
            local first, last = half == 1 and 0.08 or 0.5, half == 1 and 0.5 or 0.08
            rail:SetGradientColors(ORIENTATION_HORIZONTAL, 0.67, 0.73, 0.79, first, 0.67, 0.73, 0.79, last)
            rail:SetAnchor(TOPLEFT, cap, TOPLEFT, 0, 0)
            rails[half] = rail
        end
        A.columnCaps[i] = {root = cap, rails = rails}
        A.SetHidden(cap, true)
    end

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
local function RenderRow(r, t, i, rowsPerCol, topInset, columnWidth, now, saved, fullMode, rowGap, rowHeight)
    local col = math.floor((i - 1) / rowsPerCol)
    local mirrored, highContrast = saved.mirrorTauntList == true, saved.highContrast == true
    if mirrored then col = saved.columns - 1 - col end
    local line = (i - 1) % rowsPerCol
    if r.lastCol ~= col or r.lastLine ~= line or r.lastTopInset ~= topInset or r.lastWidth ~= columnWidth
        or r.lastGap ~= rowGap or r.lastRowHeight ~= rowHeight then
        r.box:ClearAnchors()
        r.box:SetAnchor(TOPLEFT, A.root, TOPLEFT,
            col * (columnWidth + COLUMN_GAP), topInset + line * (rowHeight + rowGap))
        r.box:SetHeight(rowHeight)
        r.lastRowHeight = rowHeight
        r.lastCol, r.lastLine, r.lastTopInset, r.lastWidth, r.lastGap = col, line, topInset, columnWidth, rowGap
    end
    if r.lastMirrored ~= mirrored then
        local nameSide = mirrored and TOPRIGHT or TOPLEFT
        local timerSide = mirrored and TOPLEFT or TOPRIGHT
        local sign = mirrored and -1 or 1
        r.accent:ClearAnchors(); r.accent:SetAnchor(nameSide, r.box, nameSide, 0, 0)
        r.time:ClearAnchors(); r.time:SetAnchor(timerSide, r.box, timerSide, -sign * 9, 0)
        r.name:SetHorizontalAlignment(mirrored and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT)
        r.time:SetHorizontalAlignment(mirrored and TEXT_ALIGN_LEFT or TEXT_ALIGN_RIGHT)
        local fillSide = mirrored and BOTTOMRIGHT or BOTTOMLEFT
        r.fill:ClearAnchors(); r.fill:SetAnchor(fillSide, r.barRegion, fillSide, 0, 0)
        r.mediaFill:ClearAnchors(); r.mediaFill:SetAnchor(fillSide, r.barRegion, fillSide, 0, 0)
        -- Only texture coordinates change, never glyphs or saved media paths.
        r.mediaFill:SetTextureCoords(mirrored and 1 or 0, mirrored and 0 or 1, 0, 1)
        r.lastMirrored, r.lastBossIcon = mirrored, nil
    end
    if r.lastHighContrast ~= highContrast then
        A.SetHidden(r.contrastEdge, not highContrast)
        r.lastHighContrast = highContrast
    end
    local contentHeight = fullMode and rowHeight or rowHeight - (r.barHeight or saved.barHeight)
    if r.lastContentHeight ~= contentHeight or r.lastContentWidth ~= columnWidth
        or r.lastContentContrast ~= highContrast or r.lastContentRowHeight ~= rowHeight
        or r.lastFocusThickness ~= r.focusThickness or r.lastFocusPadding ~= A.focusPadding then
        r.name:SetHeight(contentHeight)
        r.time:SetHeight(contentHeight)
        r.fullFill:SetHeight(rowHeight)
        -- Continue the urgency stripe through the narrow countdown's corner.
        r.accent:SetHeight(rowHeight)
        r.surface:SetDimensions(columnWidth, contentHeight)
        r.progressRegion:SetHeight(rowHeight)
        local focusPad = A.focusPadding or 2
        r.focusViewport:ClearAnchors()
        r.focusViewport:SetAnchor(TOPLEFT, r.box, TOPLEFT, -focusPad, -focusPad)
        r.focusViewport:SetDimensions(columnWidth + 2 * focusPad, rowHeight + 2 * focusPad)
        r.focusSweep:SetHeight(rowHeight + 2 * focusPad)
        for _, glint in ipairs(r.focusGlints) do glint:SetHeight(focusPad) end
        r.focusTravelWidth = columnWidth + 2 * focusPad
        local edge = r.focusThickness or (highContrast and 2 or 1)
        for side, outline in pairs(r.focusOutline) do
            local x, y, w, h = -edge, -edge, columnWidth + 2 * edge, edge
            if side == "bottom" then y = rowHeight
            elseif side == "left" then y, w, h = 0, edge, rowHeight
            elseif side == "right" then x, y, w, h = columnWidth, 0, edge, rowHeight end
            outline:ClearAnchors()
            outline:SetAnchor(TOPLEFT, r.box, TOPLEFT, x, y)
            outline:SetDimensions(w, h)
        end
        r.lastContentHeight, r.lastContentWidth, r.lastContentContrast = contentHeight, columnWidth, highContrast
        r.lastContentRowHeight = rowHeight
        r.lastFocusThickness = edge
        r.lastFocusPadding = focusPad
        r.lastBossIcon = nil
    end
    local expired = A.IsLost(t, now)
    local remaining = math.max(0, t.endTime - now)
    local warning = expired or remaining <= saved.warningAt
    local danger = expired or remaining <= saved.dangerAt
    local color = danger and (highContrast and C.highDanger or C.danger) or (warning and C.warning or C.safe)
    local focusId = A.demo and A.demoFocusId or A.activeTarget
    local selected = saved.highlightTarget and t.unitId == focusId

    local rowColor = C.row
    -- In full-row mode the fill itself indicates urgency; avoid a
    -- competing background tint on the unfilled part of the row.
    if saved.subtleWarningBg and not fullMode and not highContrast then
        rowColor = danger and C.dangerRow or (warning and C.warningRow or C.row)
    end
    if highContrast then
        rowColor = fullMode and C.highRow or (danger and C.highDangerRow or (warning and C.highWarningRow or C.highSafeRow))
    end
    local opacity = highContrast and 1 or saved.opacity
    if r.lastRowColor ~= rowColor or r.lastOpacity ~= opacity then
        SetColor(r.bg, rowColor, opacity)
        r.lastRowColor, r.lastOpacity = rowColor, opacity
    end
    -- Only issue native SetColor calls when the urgency band changes.
    -- Native size animations move the fills independently of this model tick.
    if r.lastUrgencyColor ~= color then
        SetColor(r.accent, color)
        SetColor(r.fill, color)
        SetColor(r.mediaFill, color)
        r.lastUrgencyColor = color
    end
    A.SetHidden(r.surface, not highContrast)
    local accentWidth = danger and 7 or (warning and 5 or (highContrast and 4 or 3))

    -- Standard 15-second danger fills end before the clock. If a short effect
    -- fills behind it, white text keeps the stronger crimson surface readable.
    local timeColor = color
    if fullMode and highContrast and danger then
        local duration = math.max(0.1, t.endTime - t.startTime)
        local fraction = Clamp(remaining / duration, 0, 1)
        if accentWidth + math.floor((columnWidth-accentWidth)*fraction+0.5)>columnWidth-62 then timeColor=C.white end
    end
    if r.lastTimeColor~=timeColor then SetColor(r.time,timeColor);r.lastTimeColor=timeColor end
    -- The boss name uses an independent, constant high-contrast
    -- colour. Red/yellow/turquoise remain exclusive to taunt urgency.
    -- This also holds when the boss is the selected target.
    local boss = A.BossVisible(t)
    local specialBossName = boss and saved.highlightBossNames
    local nameColor = specialBossName and C.bossName or C.white
    if r.lastNameColor ~= nameColor then
        SetColor(r.name, nameColor)
        r.lastNameColor = nameColor
    end
    -- The focus marking stays visually separate from the severity
    -- colour: no replacing the red/yellow/turquoise countdown.
    A.AnimateRowFocus(r, selected, now)
    A.AnimateRowEntry(r, t, now, selected)
    local showBoss = saved.showBossIcon and boss
    A.SetHidden(r.bossIcon, not showBoss)
    -- The skull texture and its constant bone-ivory tint do not
    -- change when a taunt's remaining time changes.
    local displayName = t.name or T("Unknown enemy")
    if r.lastDisplayName ~= displayName then
        r.name:SetText(displayName)
        r.lastDisplayName = displayName
    end
    -- Mirror the group around its fixed urgency-side icon; short names never
    -- move the skull away from the stripe.
    if r.lastBossIcon ~= showBoss then
        r.name:ClearAnchors()
        local side = mirrored and TOPRIGHT or TOPLEFT
        local inset = showBoss and 30 or 12
        r.name:SetAnchor(side, r.box, side, mirrored and -inset or inset, 0)
        r.lastBossIcon = showBoss
    end
    local nameWidth = columnWidth - 79 - (showBoss and 18 or 0)
    if r.lastNameWidth ~= nameWidth then
        r.name:SetWidth(nameWidth)
        r.lastNameWidth = nameWidth
    end
    if r.lastIconContentHeight ~= contentHeight or r.lastIconMirrored ~= mirrored then
        r.bossIcon:ClearAnchors()
        local size = math.min(18, contentHeight - 2)
        local iconHeight = size * BOSS_ICON_HEIGHT_RATIO
        r.bossIcon:SetDimensions(size, iconHeight)
        local y = (contentHeight - iconHeight) / 2
        if mirrored then
            r.bossIcon:SetAnchor(TOPRIGHT, r.box, TOPRIGHT, -10, y)
        else
            r.bossIcon:SetAnchor(TOPLEFT, r.box, TOPLEFT, 10, y)
        end
        r.lastIconContentHeight, r.lastIconMirrored = contentHeight, mirrored
    end
    if r.lastColumnWidth ~= columnWidth then
        r.box:SetWidth(columnWidth)
        r.lastColumnWidth = columnWidth
    end
    -- The persistent urgency stripe is outside the countdown's usable distance.
    -- Scale time over that distance, rather than hiding the final seconds under it.
    local progressWidth = columnWidth - accentWidth
    if r.lastProgressMirrored ~= mirrored then
        local fullSide = mirrored and TOPRIGHT or TOPLEFT
        local farSide = mirrored and TOPLEFT or TOPRIGHT
        local stripSide = mirrored and BOTTOMRIGHT or BOTTOMLEFT
        r.progressRegion:ClearAnchors(); r.progressRegion:SetAnchor(farSide, r.box, farSide, 0, 0)
        r.fullFill:ClearAnchors(); r.fullFill:SetAnchor(fullSide, r.progressRegion, fullSide, 0, 0)
        r.barRegion:ClearAnchors(); r.barRegion:SetAnchor(stripSide, r.progressRegion, stripSide, 0, 0)
        r.contrastEdge:ClearAnchors(); r.contrastEdge:SetAnchor(fullSide, r.progressRegion, fullSide, 0, 0)
        r.lastProgressMirrored = mirrored
    end
    A.AnimateRowAccent(r, t, now, columnWidth, accentWidth, fullMode, highContrast)
    r.lastProgressWidth, r.lastProgressInset = progressWidth, accentWidth
    local barHidden = expired or remaining <= 0
    A.AnimateRowProgress(r, t, now, progressWidth, fullMode, highContrast, expired)
    local fillColor = danger and C.fullDanger or (warning and C.fullWarning or C.fullSafe)
    if highContrast then
        fillColor = danger and C.highFullDanger or (warning and C.highFullWarning or C.highFullSafe)
    end
    if r.lastFullColor ~= fillColor then
        SetColor(r.fullFill, fillColor)
        r.lastFullColor = fillColor
    end
    A.SetHidden(r.fullFill, not fullMode or barHidden)
    -- Full-row and narrow modes share the same persistent urgency marker.
    A.SetHidden(r.accent, false)
    A.SetHidden(r.barRegion, fullMode)
    local texturedTrack = saved.texturedTrack and not highContrast
    A.SetHidden(r.track, fullMode or texturedTrack)
    A.SetHidden(r.trackTexture, fullMode or not texturedTrack)
    A.SetHidden(r.fill, fullMode or barHidden or (r.useMediaFill and not highContrast))
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
    return active, lost
end

local function UpdateDemoFocus(now, items)
    if not A.demo then return end
    now = A.DemoNow(now)
    local currentVisible = false
    for _, t in ipairs(items) do
        if t.unitId == A.demoFocusId then currentVisible = true; break end
    end
    if currentVisible and A.demoFocusUntil and now < A.demoFocusUntil then return end
    -- Select from the actual rendered rows, including after overflow/sorting.
    -- Prefer a different active target; keep a remaining expired row if needed.
    local candidate, firstActive, fallback
    for _, t in ipairs(items) do
        fallback = fallback or t
        if t.endTime > now and t.unitId ~= A.demoFocusId then
            if not firstActive or t.order < firstActive.order then firstActive = t end
            if t.order > (A.demoFocusOrder or 0) and (not candidate or t.order < candidate.order) then
                candidate = t
            end
        end
    end
    candidate = candidate or firstActive or fallback
    A.demoFocusId = candidate and candidate.unitId or nil
    A.demoFocusOrder = candidate and candidate.order or 0
    A.demoFocusUntil = candidate and now + 7 or nil
end

local function RenderList(now, active, lost, items, saved)
    UpdateDemoFocus(now, items)
    local focusId = saved.highlightTarget
        and (A.demo and A.demoFocusId or A.activeTarget) or nil
    local visibleFocus
    for _, target in ipairs(items) do if target.unitId == focusId then visibleFocus = focusId; break end end
    A.ObserveFocus(visibleFocus, now)
    A.rowVisualsSuspended = false
    local total = #active + #lost
    local visible = #items
    local hidden = total - visible

    local width = GetWidth()
    local mirrored = saved.mirrorTauntList == true
    if A.lastListMirrored ~= mirrored then
        A.more:SetHorizontalAlignment(mirrored and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT)
        A.lastListMirrored = mirrored
    end
    local rowsPerCol = (saved.columns == 2) and math.ceil(visible / 2) or saved.limit
    local rowCount = math.min(rowsPerCol, visible)
    local fullMode = saved.barDisplay == "full"
    local moveExtra = A.moving and 18 or 0
    local resolvedScale = ResolveListScale(width, rowCount, fullMode, hidden > 0 and FOOTER_HEIGHT or 0, moveExtra)
    if A.renderScale ~= resolvedScale then
        A.renderScale = resolvedScale
        Layout()
        A.ApplyMedia()
    end
    local topInset = GetListTopInset()
    -- Reserve room for an external outline even if a saved profile uses zero
    -- spacing. Do not change its preference or make rows jump on target changes.
    local rowGap = math.max(saved.rowGap, FocusEdge())
    local rowHeight = GetRowHeight(fullMode)
    local rowRegionHeight = rowCount * (rowHeight + rowGap)
    local footerY = topInset + rowRegionHeight
    local hudHeight = topInset + rowRegionHeight + (hidden > 0 and FOOTER_HEIGHT or 0) + moveExtra
    if A.lastRootWidth ~= width or A.lastRootHeight ~= hudHeight then
        A.root:SetDimensions(width, hudHeight)
        A.lastRootWidth, A.lastRootHeight = width, hudHeight
    end
    ScreenBounds(width, hudHeight, resolvedScale)

    local columnWidth = GetColumnWidth()
    local columnsUsed = visible > rowsPerCol and 2 or (visible > 0 and 1 or 0)
    for i, cap in ipairs(A.columnCaps) do
        local column = i - 1
        local occupied = column < saved.columns and (mirrored and column >= saved.columns - columnsUsed
            or not mirrored and column < columnsUsed)
        A.SetHidden(cap.root, not occupied)
        if occupied and cap.width ~= columnWidth then
            cap.root:ClearAnchors()
            cap.root:SetAnchor(TOPLEFT, A.root, TOPLEFT, column * (columnWidth + COLUMN_GAP), 0)
            cap.root:SetWidth(columnWidth)
            for half, rail in ipairs(cap.rails) do
                rail:ClearAnchors()
                rail:SetAnchor(TOPLEFT, cap.root, TOPLEFT, (half - 1) * columnWidth / 2, 0)
                rail:SetWidth(columnWidth / 2)
            end
            cap.width = columnWidth
        end
    end

    A.SetHidden(A.footer, hidden == 0)
    A.SetHidden(A.more, hidden == 0)
    if hidden > 0 then
        if A.lastFooterWidth ~= width or A.lastFooterY ~= footerY or A.lastFooterMirrored ~= mirrored then
            A.footer:SetWidth(width)
            A.footer:ClearAnchors()
            A.footer:SetAnchor(TOPLEFT, A.root, TOPLEFT, 0, footerY)
            A.more:ClearAnchors()
            local side = mirrored and TOPRIGHT or TOPLEFT
            A.more:SetAnchor(side, A.root, side, mirrored and -9 or 9, footerY)
            A.more:SetWidth(width - 14)
            A.lastFooterWidth, A.lastFooterY = width, footerY
            A.lastFooterMirrored = mirrored
        end
        if A.lastHiddenCount ~= hidden or A.lastFooterLanguage ~= A.language then
            local footerText = string.format("+%d %s", hidden, T("more"))
            A.more:SetText(footerText)
            A.lastFooterText, A.lastHiddenCount, A.lastFooterLanguage = footerText, hidden, A.language
        end
    end
    A.SetHidden(A.moveHint, not A.moving)
    if A.moving then
        A.moveHint:SetWidth(width)
        A.moveHint:ClearAnchors()
        A.moveHint:SetAnchor(BOTTOMLEFT, A.root, BOTTOMLEFT, 0, 0)
    end

    for i = 1, #A.rows do
        local row = A.rows[i]
        A.SetHidden(row.box, i > visible)
        if i <= visible then
            RenderRow(row, items[i], i, rowsPerCol, topInset, columnWidth, now, saved, fullMode, rowGap, rowHeight)
        elseif row.progressTarget or row.focusRunning or row.focusSerial then
            A.StopRowAnimations(row)
        end
    end
end

local function Tick()
    if not A.root then return end
    A.effectTickPending = nil
    local now, saved = Now(), A.saved
    local canRenderList = InWorldHUD() and (saved.showTauntList ~= false or A.demo or A.moving)
    ObserveTargets(now)
    local active, lost = UpdateTargets(now, not canRenderList)
    local show = A.demo or A.moving or #active + #lost > 0
    local hideRoot = not show or not canRenderList
    A.SetHidden(A.root, hideRoot)
    A.RefreshUpdateState()
    -- Model/warnings keep running in menus and with the list switched off.
    -- Selection and all enemy-row
    -- rendering resume from current data on the first visible tick.
    if hideRoot then
        if not A.rowVisualsSuspended then
            A.ObserveFocus(nil, A.DemoNow(now))
            for _, row in ipairs(A.rows) do A.StopRowAnimations(row) end
            A.rowVisualsSuspended = true
        end
        return
    end
    local items = A.SelectVisible(active, lost, saved.columns * saved.limit)
    RenderList(A.DemoNow(now), active, lost, items, saved)
end


-- Public entry points used across modules.
A.GetListTopInset = GetListTopInset
A.GetColumnWidth = GetColumnWidth
A.GetWidth = GetWidth
A.MinimumRowHeight = MinimumRowHeight
A.Layout = Layout
A.ScreenBounds = ScreenBounds
A.SavePosition = SavePosition
A.SetMoving = SetMoving
A.NewRow = NewRow
A.MakeUI = MakeUI
A.InWorldHUD = InWorldHUD
A.Tick = Tick
