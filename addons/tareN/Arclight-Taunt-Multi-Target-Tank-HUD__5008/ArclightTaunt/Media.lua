-- Arclight Taunt 1.1.1 | Media module
-- Loaded in manifest order; requires Core.lua and uses its shared namespace.
local A = ArclightTaunt
local MEDIA_BAR_FLAT = A.MEDIA_BAR_FLAT
local MEDIA_BG_NONE = A.MEDIA_BG_NONE
local MEDIA_FONT_DEFAULT = A.MEDIA_FONT_DEFAULT
local MEDIA_TIMER_INHERIT = A.MEDIA_TIMER_INHERIT
local SetColor = A.SetColor
local appliedFonts = setmetatable({}, {__mode="k"})
local function SetStableFont(control, descriptor)
    if appliedFonts[control] ~= descriptor then
        control:SetFont(descriptor)
        appliedFonts[control] = descriptor
    end
end

local function RegisteredMediaPath(mediaType, key)
    if not A.LMP or not key or type(key) ~= "string" then return nil end
    if not A.LMP:IsValid(mediaType, key) then return nil end
    local path = A.LMP:Fetch(mediaType, key)
    return (type(path) == "string" and path ~= "") and path or nil
end

-- Drop any custom font size/style embedded in a registration: our HUD keeps
-- independent and bounded type sizes. A.LMP supplies the font *family* only.
local function FontFor(baseSize, medium, timer)
    local pct = (A.saved and A.saved.fontSize) or 100
    local size = math.floor(baseSize * pct / 100 + 0.5)
    local fallback = medium and "$(MEDIUM_FONT)" or "$(BOLD_FONT)"
    -- The timer may have its own LibMediaProvider font. By default it follows
    -- the name font, so upgrading cannot unexpectedly change existing typography.
    local key = A.saved and A.saved.fontKey or MEDIA_FONT_DEFAULT
    if timer and A.saved and A.saved.timerFontKey ~= MEDIA_TIMER_INHERIT then
        key = A.saved.timerFontKey
    end
    local font = (key ~= MEDIA_FONT_DEFAULT) and RegisteredMediaPath("font", key) or nil
    -- Built-in ESO fonts follow the client language and support Cyrillic.
    -- Keep the saved media key; custom numeric timer fonts remain available.
    if A.language == "ru" and not timer then font = nil end
    if font then font = font:match("^[^|]+") end
    return (font or fallback) .. "|" .. tostring(size)
        .. "|soft-shadow-thin"
end

local function SelectedBarPath()
    -- The old untextured fill stays available as an explicit alternative.
    if not A.saved then return nil end
    if A.saved.highContrast then return A.MEDIA_TEXTURE_SIGNATURE end
    if A.saved.barKey == MEDIA_BAR_FLAT then return nil end
    return RegisteredMediaPath("statusbar", A.saved.barKey)
        or RegisteredMediaPath("statusbar", A.MEDIA_BAR_DEFAULT)
end

local function BuildMediaChoices(mediaType, first, alternative, selected)
    local choices, known = { first }, { [first] = true }
    -- The old flat fill is not A.LMP-registered, but must remain selectable.
    if alternative and not known[alternative] then
        choices[#choices + 1], known[alternative] = alternative, true
    end
    -- Keep an unavailable saved preference visible without changing its key.
    if type(selected) == "string" and selected ~= "" and not known[selected] then
        choices[#choices + 1], known[selected] = selected, true
    end
    if A.LMP then
        for _, name in ipairs(A.LMP:List(mediaType) or {}) do
            if not known[name] and RegisteredMediaPath(mediaType, name) then
                choices[#choices + 1], known[name] = name, true
            end
        end
    end
    return choices
end

local function ChoicePresent(choices, value)
    for _, name in ipairs(choices) do if name == value then return true end end
    return false
end

-- The HUD uses its own scale on top of ESO's global UI scale.  With a
-- fractional combined scale, the same 4 UI-unit bar can cover 3, 4 or 5
-- physical pixels depending on the row's sub-pixel position.  Choose an
-- integer *physical* height, and opt into ESO's texture pixel rounding.
-- Both the background track and the colour fill must use the same height.
local function PixelAlignedBarHeight(scale)
    local globalScale = type(GetUIGlobalScale) == "function" and GetUIGlobalScale() or 1
    if type(globalScale) ~= "number" or globalScale ~= globalScale
        or globalScale <= 0 or globalScale == math.huge or globalScale > 10 then
        globalScale = 1
    end
    local combinedScale = (scale or A.renderScale or A.saved.scale) * globalScale
    local height = A.saved.highContrast and math.max(5, A.saved.barHeight) or A.saved.barHeight
    local pixelHeight = math.max(1, math.floor(height * combinedScale + 0.5))
    return pixelHeight / combinedScale, 1 / combinedScale
end

-- Outer screen/sweep reserve and inter-row clearance serve different purposes.
-- Only the actual frame must fit between rows, not its extra sweep viewport.
local function FocusMetrics(pixelUnit)
    local highContrast = A.saved.highContrast
    local subtlePad = math.max(highContrast and 3 or 2, pixelUnit)
    local extra = A.saved.targetHighlightStyle == "strong" and 2 * pixelUnit or 0
    local thickness = math.max(highContrast and 2 or 1, pixelUnit) + extra
    return subtlePad + extra, math.max(subtlePad, thickness), thickness
end

local function ApplyMedia()
    if not A.root then return end
    local highContrast = A.saved.highContrast
    SetStableFont(A.more, FontFor(12, true))
    SetStableFont(A.moveHint, FontFor(12, true))
    SetColor(A.footer, highContrast and A.C.highRow or A.C.header)
    SetColor(A.more, highContrast and A.C.white or A.C.muted)
    for kind, alert in pairs(A.bossAlerts) do
        if alert.title then
            alert.title:SetFont(FontFor(alert.titleSize, false))
            alert.subtitle:SetFont(FontFor(alert.subtitleSize, false))
            if alert.titleText then A.SetAlertText(kind, alert.titleText, alert.subtitleText) end
        end
    end
    local barPath = SelectedBarPath()
    local bgPath = not highContrast and (A.saved.backgroundKey ~= MEDIA_BG_NONE)
        and (RegisteredMediaPath("background", A.saved.backgroundKey)
            or RegisteredMediaPath("background", A.MEDIA_BG_OBSIDIAN)) or nil
    local barHeight, pixelUnit = PixelAlignedBarHeight()
    local focusThickness
    A.focusPadding, A.focusRowGap, focusThickness = FocusMetrics(pixelUnit)
    A.capHeight = math.max(2, pixelUnit)
    for _, cap in ipairs(A.columnCaps or {}) do
        cap.root:SetHeight(A.capHeight)
        for _, rail in ipairs(cap.rails) do rail:SetHeight(pixelUnit) end
    end
    -- Font selections do not change per enemy. Resolve them once instead of
    -- querying LibMediaProvider for every row and every label.
    local nameFont = FontFor(14)
    local timerFont = FontFor(15, false, true)
    local fullMode = A.saved.barDisplay == "full"
    local texturedTrack = A.saved.texturedTrack and not highContrast
    for _, row in ipairs(A.rows) do
        SetStableFont(row.name, nameFont)
        SetStableFont(row.time, timerFont)
        row.name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        row.time:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        row.barHeight = barHeight
        row.barRegion:SetHeight(barHeight)
        row.contrastEdge:SetHeight(pixelUnit)
        row.contrastHeight = pixelUnit
        -- A one-UI-unit edge can round away at small combined UI/HUD scales.
        row.focusThickness = focusThickness
        A.SetHidden(row.barRegion, fullMode)
        A.SetHidden(row.track, fullMode or texturedTrack)
        A.SetHidden(row.trackTexture, fullMode or not texturedTrack)
        SetColor(row.track, highContrast and A.C.highTrack or A.C.track)
        if bgPath and row.backgroundTexturePath ~= bgPath then
            row.bgTexture:SetTexture(bgPath)
            row.backgroundTexturePath = bgPath
        end
        A.SetHidden(row.bgTexture, bgPath == nil)
        A.SetHidden(row.surface, not highContrast)
        -- The actual urgency tint stays on the solid base. Subtle translucent
        -- texture detail does not change taunt severity or obscure the labels.
        row.bgTexture:SetColor(1, 1, 1, A.saved.opacity)
        -- A second, optional textured control avoids a texture-clearing bug
        -- when switching back to the original solid-colour bar.
        if barPath and row.mediaTexturePath ~= barPath then
            row.mediaFill:SetTexture(barPath)
            row.mediaTexturePath = barPath
        end
        -- Assign dimensions after textures too. Native file-size changes must
        -- never turn a narrow progress strip into a full-height row.
        row.track:SetHeight(barHeight)
        row.trackTexture:SetHeight(barHeight)
        row.fill:SetHeight(barHeight)
        row.mediaFill:SetHeight(barHeight)
        row.useMediaFill = barPath ~= nil
        A.SetHidden(row.fill, fullMode or (row.useMediaFill and not highContrast))
        A.SetHidden(row.mediaFill, fullMode or not row.useMediaFill)
    end
    -- Measure native font metrics only when media/settings change, never per tick.
    -- Numeric timers may use a different font family from enemy names.
    local first = A.rows[1]
    if first then
        A.minRowContentHeight = math.ceil(math.max(first.name:GetFontHeight(), first.time:GetFontHeight()))
        if A.saved.rowHeightExtra == nil then
            local baseline = fullMode and A.ROW_HEIGHT or A.COMPACT_ROW_HEIGHT
            local legacy = A.FiniteBoundedNumber(A.saved.rowHeight, 100, 80, 160)
            local requested = math.floor(baseline * legacy / 100 + 0.5)
            A.saved.rowHeightExtra = A.Clamp(requested - A.MinimumRowHeight(fullMode), 0, 40)
        end
        A.saved.rowHeight = nil -- migration only; no inactive percentage setting
    end
end

-- Public entry points used across modules.
A.RegisteredMediaPath = RegisteredMediaPath
A.FontFor = FontFor
A.SelectedBarPath = SelectedBarPath
A.PixelAlignedBarHeight = PixelAlignedBarHeight
A.FocusMetrics = FocusMetrics
A.BuildMediaChoices = BuildMediaChoices
A.ChoicePresent = ChoicePresent
A.ApplyMedia = ApplyMedia

-- Fit only when text or selected media changes, never on every HUD tick.
function A.SetAlertText(kind, title, subtitle)
    local alert = A.bossAlerts[kind]
    alert.titleText, alert.subtitleText = title, subtitle
    local function fit(label, text, preferred, minimum)
        label:SetText(text)
        local font = FontFor(preferred, false)
        if alert.measure then
            for size = preferred, minimum, -1 do
                font = FontFor(size, false)
                alert.measure:SetFont(font)
                alert.measure:SetText(text)
                local width = alert.measure:GetTextDimensions()
                if width <= alert.textWidth then break end
            end
        end
        label:SetFont(font)
    end
    fit(alert.title, title, alert.titleSize or 20, alert.titleMinimum or 10)
    fit(alert.subtitle, subtitle, alert.subtitleSize or 17, alert.subtitleMinimum or 11)
end
