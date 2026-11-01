-- Arclight Taunt 1.0.3 | Media module
-- Loaded in manifest order; requires Core.lua and uses its shared namespace.
local A = ArclightTaunt
local MEDIA_BAR_FLAT = A.MEDIA_BAR_FLAT
local MEDIA_BG_NONE = A.MEDIA_BG_NONE
local MEDIA_FONT_DEFAULT = A.MEDIA_FONT_DEFAULT
local MEDIA_TIMER_INHERIT = A.MEDIA_TIMER_INHERIT
local SetColor = A.SetColor

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
    return (font or fallback) .. "|" .. tostring(size) .. "|soft-shadow-thin"
end

local function SelectedBarPath()
    -- The old untextured fill stays available as an explicit alternative.
    if not A.saved or A.saved.barKey == MEDIA_BAR_FLAT then return nil end
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
local function PixelAlignedBarHeight()
    local globalScale = type(GetUIGlobalScale) == "function" and GetUIGlobalScale() or 1
    if type(globalScale) ~= "number" or globalScale ~= globalScale
        or globalScale <= 0 or globalScale == math.huge or globalScale > 10 then
        globalScale = 1
    end
    local combinedScale = (A.renderScale or A.saved.scale) * globalScale
    local pixelHeight = math.max(1, math.floor(A.saved.barHeight * combinedScale + 0.5))
    return pixelHeight / combinedScale
end

local function ApplyMedia()
    if not A.root then return end
    A.heading:SetFont(FontFor(13, false))
    A.counter:SetFont(FontFor(13, false))
    A.more:SetFont(FontFor(12, true))
    A.moveHint:SetFont(FontFor(12, true))
    for kind, alert in pairs(A.bossAlerts) do
        if alert.title then
            alert.title:SetFont(FontFor(alert.titleSize, false))
            alert.subtitle:SetFont(FontFor(alert.subtitleSize, false))
            if alert.titleText then A.SetAlertText(kind, alert.titleText, alert.subtitleText) end
        end
    end
    local barPath = SelectedBarPath()
    local bgPath = (A.saved.backgroundKey ~= MEDIA_BG_NONE)
        and (RegisteredMediaPath("background", A.saved.backgroundKey)
            or RegisteredMediaPath("background", A.MEDIA_BG_OBSIDIAN)) or nil
    local barHeight = PixelAlignedBarHeight()
    -- Font selections do not change per enemy. Resolve them once instead of
    -- querying LibMediaProvider for every row and every label.
    local nameFont = FontFor(14, false)
    local timerFont = FontFor(15, false, true)
    local badgeFont = FontFor(12, true)
    local fullMode = A.saved.barDisplay == "full"
    for _, row in ipairs(A.rows) do
        row.name:SetFont(nameFont)
        row.time:SetFont(timerFont)
        row.badge:SetFont(badgeFont)
        row.track:SetHeight(barHeight)
        row.trackTexture:SetHeight(barHeight)
        A.SetHidden(row.track, fullMode or A.saved.texturedTrack)
        A.SetHidden(row.trackTexture, fullMode or not A.saved.texturedTrack)
        if bgPath and row.backgroundTexturePath ~= bgPath then
            row.bgTexture:SetTexture(bgPath)
            row.backgroundTexturePath = bgPath
        end
        A.SetHidden(row.bgTexture, bgPath == nil)
        -- The actual urgency tint stays on the solid base. Subtle translucent
        -- texture detail does not change taunt severity or obscure the labels.
        row.bgTexture:SetColor(1, 1, 1, A.saved.opacity)
        row.fill:SetHeight(barHeight)
        row.mediaFill:SetHeight(barHeight)
        -- A second, optional textured control avoids a texture-clearing bug
        -- when switching back to the original solid-colour bar.
        if barPath and row.mediaTexturePath ~= barPath then
            row.mediaFill:SetTexture(barPath)
            row.mediaTexturePath = barPath
        end
        row.useMediaFill = barPath ~= nil
        A.SetHidden(row.fill, fullMode or row.useMediaFill)
        A.SetHidden(row.mediaFill, fullMode or not row.useMediaFill)
    end
end

-- Public entry points used across modules.
A.RegisteredMediaPath = RegisteredMediaPath
A.FontFor = FontFor
A.SelectedBarPath = SelectedBarPath
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
