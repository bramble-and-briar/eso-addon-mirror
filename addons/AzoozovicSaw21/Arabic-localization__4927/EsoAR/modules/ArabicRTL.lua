-- ESO Arabic 1.3.2. Source text -> final font -> measured lines -> native layout.
local R = ESO_ARABIC_TEXT
local REGULAR = "EsoAR/fonts/ArabicUI.slug"
local BOLD = "EsoAR/fonts/ArabicUIBold.slug"
local states = setmetatable({}, {__mode = "k"})
local managed = setmetatable({}, {__mode = "k"})
local writing = setmetatable({}, {__mode = "k"})
local processing = setmetatable({}, {__mode = "k"})
local busy = false
local config = { keyboardScale = 1.18, gamepadScale = 1.0, keyboardMinimum = 22, gamepadMinimum = 26 }
local function active() return GetCVar("Language.2") == "ar" end
R.IsActive = active
R.Metrics = {rendered = 0, measured = 0, discovered = 0, maxBatchMs = 0}
local function call(c, method, ...)
    if c and type(c[method]) == "function" then
        local ok, a, b, d, e = pcall(c[method], c, ...)
        if ok then return a, b, d, e end
    end
end

local function gamepad()
    return type(IsInGamepadPreferredMode) == "function" and IsInGamepadPreferredMode()
end

local function fontStyleName(style)
    if type(style) == "string" then return style end
    -- Accept both style strings and FontStyle enums exposed by font APIs.
    -- SetFont descriptors require names; appending '|0'/'|5' is invalid.
    for name, value in pairs({
        ["outline"] = FONT_STYLE_OUTLINE,
        ["outline-shadow"] = FONT_STYLE_OUTLINE_SHADOW,
        ["outline-shadow-thick"] = FONT_STYLE_OUTLINE_SHADOW_THICK,
        ["outline-thick"] = FONT_STYLE_OUTLINE_THICK,
        ["shadow"] = FONT_STYLE_SHADOW,
        ["soft-shadow-thick"] = FONT_STYLE_SOFT_SHADOW_THICK,
        ["soft-shadow-thin"] = FONT_STYLE_SOFT_SHADOW_THIN,
    }) do
        if style == value then return name end
    end
    return ""
end

local function fontInfo(c)
    -- GetFontInfo belongs to FontObject, not LabelControl.
    local descriptor = call(c, "GetFont")
    local path, size, style
    if type(descriptor) == "string" then
        path, size, style = descriptor:match("^([^|]+)|(%d+)|?(.*)$")
        size = tonumber(size)
        if not size and _G[descriptor] then path, size, style = call(_G[descriptor], "GetFontInfo") end
    end
    if not size then
        path, size, style = call(c, "GetFontFaceName"), call(c, "GetFontSize"), call(c, "GetFontStyle")
    end
    if type(path) ~= "string" or type(size) ~= "number" or size <= 0 then return nil end
    return path, size, fontStyleName(style), descriptor
end

local function face(path)
    path = path:lower()
    if path:find("bold", 1, true) or path:find("univers67", 1, true) or path:find("ftn87", 1, true) then return BOLD end
    return REGULAR
end

local function descriptor(path, size, style)
    return path .. "|" .. math.floor(size + 0.5) .. ((style and style ~= "") and "|" .. style or "")
end

local function effectiveFont(c)
    local path, size, style = fontInfo(c)
    return path and descriptor(path, size, style) or nil
end

local function applyFont(c, state, desired)
    local font = descriptor(face(state.basePath), desired, state.baseStyle)
    if effectiveFont(c) ~= font then call(c, "SetFont", font) end
    state.applied = font
    state.appliedSize = desired
    return font
end

local function establish(c)
    local path, size, style, current = fontInfo(c)
    if not path then return nil end
    -- In the live client GetFont can return only the font face path, without
    -- the size/style passed to SetFont. Cache its actual resolved properties.
    current = descriptor(path, size, style)
    local state = states[c]
    if not state then state = {}; states[c] = state end
    if not state.applied or (current ~= state.applied and (size ~= state.appliedSize or path ~= face(state.basePath) or style ~= state.baseStyle)) then
        state.basePath, state.baseSize, state.baseStyle = path, size, style
        state.originalFont = current or descriptor(path, size, style)
    end
    if state.originalAlignment == nil then state.originalAlignment = call(c, "GetHorizontalAlignment") end
    return state
end

local function targetSize(state)
    local gp = gamepad()
    local scale = gp and config.gamepadScale or config.keyboardScale
    local minimum = gp and config.gamepadMinimum or config.keyboardMinimum
    if not gp and (state.basePath == REGULAR or state.basePath == BOLD) and state.baseSize >= 22 then scale = 1 end
    -- Large headings retain their designed hierarchy. Small keyboard text gets
    -- a real size increase; repeated scans always use the original size.
    if state.baseSize >= 32 then return math.floor(state.baseSize * math.min(scale, 1.05) + 0.5) end
    return math.max(minimum, math.floor(state.baseSize * scale + 0.5))
end

local probe
local function getProbe()
    if not probe and WINDOW_MANAGER then
        probe = WINDOW_MANAGER:CreateControl("ESOArabicMeasureLabel", GuiRoot, CT_LABEL)
        probe:SetHidden(true)
        -- A zero-width TRUNCATE label can report a zero text extent in the
        -- client. Use an explicitly unconstrained measuring surface instead.
        probe:SetWidth(100000)
        probe:SetMaxLineCount(0)
        if probe.SetWrapMode then probe:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE) end
        managed[probe] = true
    end
    return probe
end

local function measurer(c)
    local p = getProbe()
    local font = effectiveFont(c)
    if p and font then
        p:SetFont(font)
        return function(s)
            R.Metrics.measured = R.Metrics.measured + 1
            p:SetText(s)
            return p:GetTextWidth()
        end
    end
    -- GetStringWidth returns scaled native units. An unconstrained label and
    -- GetTextWidth above avoid the UI-scale mismatch whenever possible.
    local scale = type(GetGlobalUIScale) == "function" and GetGlobalUIScale() or 1
    return function(s) return (call(c, "GetStringWidth", s) or 0) / math.max(scale, 0.01) end
end

local function availableWidth(c, explicit)
    -- An owner-supplied width is already the available content box. A parent
    -- that resizes to its children cannot provide an independent clamp.
    if explicit and explicit > 0 then return math.max(0, explicit - 6) end
    local width = explicit or call(c, "GetWidth") or 0
    local _, _, maxWidth = call(c, "GetDimensionConstraints")
    if (width <= 1) and type(maxWidth) == "number" then width = maxWidth end
    local parent = call(c, "GetParent")
    local left, parentRight = call(c, "GetLeft"), call(parent, "GetRight")
    if type(left) == "number" and type(parentRight) == "number" and parentRight - left > 20 then
        if width <= 1 then width = parentRight - left end
    end
    return math.max(0, width - 6)
end
R.AvailableWidth = availableWidth

local function writeText(c, text)
    local p = getProbe()
    -- SetText on ESO's font-adjusting labels changes the font again. Use the
    -- underlying label method after our font and line breaks are final.
    writing[c] = true
    local ok, err = pcall(p and p.SetText or c.SetText, c, text)
    writing[c] = nil
    if not ok then error(err) end
end
R.WriteText = writeText
R.IsWriting = function(c) return writing[c] end
R.Manage = function(c) if c then managed[c] = true end end
R.IsManaged = function(c) return managed[c] end

local function restore(c, state)
    if not state then return end
    if effectiveFont(c) == state.applied then call(c, "SetFont", state.originalFont) end
    if state.originalAlignment ~= nil then call(c, "SetHorizontalAlignment", state.originalAlignment) end
    states[c] = nil
end

local function process(c, options)
    options = options or {}
    if managed[c] and not options.managed then return end
    if CT_LABEL and call(c, "GetType") ~= CT_LABEL then return end
    local text = options.text or call(c, "GetText")
    if type(text) ~= "string" then return end
    if not R.HasArabic(text) then restore(c, states[c]); return end
    local state = establish(c)
    if not state then return end
    local source = (text == state.rendered and state.source) or text
    local width = options.autoWidth and 0 or availableWidth(c, options.width)
    local mode = gamepad()
    local current = effectiveFont(c)
    local profile = table.concat({tostring(options.size), tostring(options.minimum), tostring(options.face),
        tostring(options.height), tostring(options.flow), tostring(options.single), tostring(options.align), tostring(options.autoWidth), tostring(options.multiline), tostring(options.reflowVisual)}, ":")
    if not options.force and (text == state.rendered or text == state.source) and current == state.applied
        and state.width == width and state.mode == mode and state.profile == profile then
        -- Reticle/quest UI can assign the identical unwrapped source every
        -- frame. Reuse the measured result instead of measuring it each time.
        if text ~= state.rendered then writeText(c, state.rendered) end
        return state.rendered
    end
    local height = call(c, "GetHeight") or 0
    local textHeight = call(c, "GetTextHeight") or height
    R.Metrics.rendered = R.Metrics.rendered + 1
    local prepared = R.Prepare(source)
    if options.reflowVisual then prepared = R.JoinVisualLines(prepared) end
    local size = options.size or targetSize(state)
    if options.face then state.basePath = options.face end
    applyFont(c, state, size)
    local name = (call(c, "GetName") or ""):lower()
    local fontHeight = call(c, "GetFontHeight") or size
    local _, _, _, maxHeight = call(c, "GetDimensionConstraints")
    local fixedHeight = options.height or ((type(maxHeight) == "number" and maxHeight > 0) and maxHeight or nil)
    local single = options.single or name:find("keybind", 1, true) or name:find("button", 1, true)
    local anchorCount = call(c, "GetNumAnchors") or 0
    if not options.flow and not fixedHeight and height > 1 and (anchorCount > 1 or height > textHeight + 2) then fixedHeight = height end
    if not options.multiline and fixedHeight and fixedHeight < fontHeight * 1.55 then single = true end
    if options.flow then single, fixedHeight = false, nil end
    local output = prepared
    if width > 10 then
        local minSize = options.minimum or (mode and 20 or 16)
        local measured = {}
        local function layout()
            local rawMeasure = measurer(c)
            local measure = function(s)
                local key = tostring(size) .. ":" .. s
                if measured[key] == nil then measured[key] = rawMeasure(s) end
                return measured[key]
            end
            if single then return prepared, measure(prepared) <= width end
            local wrapped = R.WrapVisual(prepared, width, measure)
            local _, breaks = wrapped:gsub("\n", "")
            local fh = call(c, "GetFontHeight") or size
            return wrapped, not fixedHeight or ((breaks + 1) * fh <= fixedHeight + 1)
        end
        local fits
        output, fits = layout()
        while not fits and size > minSize do
            size = size - 1; applyFont(c, state, size)
            output, fits = layout()
        end
        -- Preserve all text. Text that cannot fit even at the minimum can be
        -- inspected with /archeck; no ellipses or character deletion are added.
        state.overflow = not fits
    end
    local alignment = call(c, "GetHorizontalAlignment")
    local desiredAlignment = options.align or (alignment == TEXT_ALIGN_LEFT and TEXT_ALIGN_RIGHT)
    if desiredAlignment and desiredAlignment ~= alignment then call(c, "SetHorizontalAlignment", desiredAlignment) end
    if output ~= call(c, "GetText") then writeText(c, output) end
    state.source, state.rendered = source, output
    state.width, state.height, state.mode = width, call(c, "GetHeight") or height, mode
    state.profile = profile
    return output
end
local unguardedProcess = process
process = function(c, options)
    if not c or processing[c] then return end
    processing[c] = true
    local ok, result = pcall(unguardedProcess, c, options)
    processing[c] = nil
    if not ok then error(result) end
    return result
end
R.ProcessControl = process
R.GetMeasure = measurer

local function installBooks()
    local reader = LORE_READER
    if not reader or reader.esoArabicInstalled then return end
    reader.esoArabicInstalled = true
    local originalSetup, originalLayout, originalMedium = reader.SetupBook, reader.LayoutText, reader.ApplyMedium
    reader.SetupBook = function(self, title, body, ...)
        self.esoArabicBook = active() and (R.HasArabic(title) or R.HasArabic(body))
        self.esoArabicBodySource, self.esoArabicTitleSource = body, title
        self.esoArabicBodyRendered, self.esoArabicTitleRendered = nil, nil
        if not self.esoArabicBook then
            for _, c in ipairs({self.title, self.firstPage.body, self.secondPage.body, self.overrideImageTitle}) do
                managed[c] = nil; restore(c, states[c])
            end
            self.firstPage.body:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            self.secondPage.body:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        end
        return originalSetup(self, title, body, ...)
    end
    reader.ApplyMedium = function(self, medium, ...)
        local result = originalMedium(self, medium, ...)
        if self.esoArabicBook and not self.useOverrideImage and self.numPagesPerGrouping > 1 then
            local _, _, _, _, y, leftX, rightX = GetBookMediumInfo(medium)
            self.firstPage:ClearAnchors(); self.secondPage:ClearAnchors()
            self.firstPage:SetAnchor(RIGHT, nil, RIGHT, rightX, y)
            self.secondPage:SetAnchor(LEFT, nil, LEFT, leftX, y)
        end
        return result
    end
    reader.LayoutText = function(self, ...)
        if not active() or not self.esoArabicBook then return originalLayout(self, ...) end
        if self.bodyText ~= self.esoArabicBodyRendered then self.esoArabicBodySource = self.bodyText end
        if self.titleText ~= self.esoArabicTitleRendered then self.esoArabicTitleSource = self.titleText end
        if self.useOverrideImage then
            local title = self.overrideImageTitle
            managed[title] = true
            self.titleText = process(title, {managed = true, text = self.esoArabicTitleSource, width = self.overrideImageTexture:GetWidth() - 40, flow = true, force = true}) or self.titleText
        else
            local first, second, title = self.firstPage.body, self.secondPage.body, self.title
            managed[first], managed[second], managed[title] = true, true, true
            local body = self.esoArabicBodySource
            self.bodyText = process(first, {managed = true, text = body, width = first:GetWidth(), flow = true, force = true}) or body
            local firstFont = effectiveFont(first)
            if firstFont then second:SetFont(firstFont) end
            second:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            self.titleText = process(title, {managed = true, text = self.esoArabicTitleSource, width = title:GetWidth(), flow = true, force = true}) or self.titleText
            -- Keep the native scrolling/pagination algorithm, but let it measure
            -- the final Arabic text and fonts. Both page bodies must stay identical.
        end
        self.esoArabicBodyRendered, self.esoArabicTitleRendered = self.bodyText, self.titleText
        return originalLayout(self, ...)
    end
end

local function installGamepadTooltips()
    if not ZO_TooltipSection or ZO_TooltipSection.esoArabicInstalled then return end
    ZO_TooltipSection.esoArabicInstalled = true
    local original = ZO_TooltipSection.AddCustomLabelInternal
    ZO_TooltipSection.AddCustomLabelInternal = function(self, label, customFunction, ...)
        local width = self:GetWidthProperty(...)
        if width == "auto" or (width == nil and not self:IsVertical()) then
            width = 0
        elseif width == nil then
            width = self:GetInnerSecondaryDimension()
        end
        local height = self:GetHeightProperty(...)
        if type(height) ~= "number" or height <= 0 then height = nil end
        local function prepareLabel(c, ...)
            customFunction(c, ...)
            -- These pooled labels must finish reflowing before the native
            -- section measures them. Do not let the background pass reflow
            -- them again after their positions have already been calculated.
            managed[c] = true
            if active() then
                c:SetWidth(width)
                local path, size = fontInfo(c)
                process(c, {managed = true, width = width, autoWidth = width == 0,
                    size = math.max(26, math.min(size or 30, 32)), minimum = 24,
                    height = height, flow = height == nil, reflowVisual = IsInGamepadPreferredMode(), force = true,
                    align = TEXT_ALIGN_RIGHT})
            else
                restore(c, states[c])
            end
        end
        return original(self, label, prepareLabel, ...)
    end
end

local nativeHooked = setmetatable({}, {__mode = "k"})
local function installNativeTooltip(t)
    if not t or nativeHooked[t] or type(t.AddLine) ~= "function" then return end
    nativeHooked[t] = true
    if active() then call(t, "SetFont", REGULAR .. "|22|soft-shadow-thin") end
    local original = t.AddLine
    t.AddLine = function(self, text, font, r, g, b, anchor, modify, alignment, full, minWidth, spacing)
        if active() and R.HasArabic(text) then
            local p = getProbe()
            if p then
                p:SetFont((font and font ~= "") and font or "ZoFontGame")
                local path, size, style = fontInfo(p)
                if path then
                    local state = {basePath = path, baseSize = size, baseStyle = style}
                    font = descriptor(face(path), targetSize(state), style)
                    p:SetFont(font)
                    -- Tooltip GetWidth is the result of its previous content,
                    -- including immediately after ClearLines. Using it here
                    -- shrinks reused mail/stat tips on every hover.
                    local width = call(self, "GetDesiredWidth") or 0
                    local _, _, maxWidth = call(self, "GetDimensionConstraints")
                    if width <= 1 then width = (type(maxWidth) == "number" and maxWidth > 1) and maxWidth or 400 end
                    if minWidth and minWidth > width then width = minWidth end
                    text = R.WrapVisual(R.Prepare(text), math.max(40, width - 32), measurer(p))
                    if alignment == nil or alignment == TEXT_ALIGN_LEFT then alignment = TEXT_ALIGN_RIGHT end
                end
            end
        end
        return original(self, text, font, r, g, b, anchor, modify, alignment, full, minWidth, spacing)
    end
end

-- Countdown labels must not use the client's fallback-language abbreviations.
-- Colons, clock displays and return values controlling refresh timing remain native.
function R.FormatDuration(seconds, limit)
    local left = math.max(0, math.floor(tonumber(seconds) or 0))
    local units = {
        {86400, "يوم", "أيام"}, {3600, "ساعة", "ساعات"},
        {60, "دقيقة", "دقائق"}, {1, "ثانية", "ثوان"},
    }
    local parts = {}
    for _, unit in ipairs(units) do
        local n = math.floor(left / unit[1]); left = left % unit[1]
        if n > 0 or (#parts == 0 and unit[1] == 1) then
            local word = (n >= 3 and n <= 10) and unit[3] or unit[2]
            parts[#parts + 1] = tostring(n) .. " " .. word
            if #parts >= (limit or 2) then break end
        end
    end
    return R.ShapeLogical(table.concat(parts, "، "))
end

function R.FormatCompactDuration(seconds)
    local value = math.max(0, tonumber(seconds) or 0)
    -- Icon captions get one short unit; full words cannot fit an ability slot.
    for _, unit in ipairs({{86400, "ي"}, {3600, "س"}, {60, "د"}, {1, "ث"}}) do
        if value >= unit[1] or unit[1] == 1 then
            return R.ShapeLogical(tostring(math.floor(value / unit[1])) .. unit[2])
        end
    end
end

local timeInstalled = false
local function installTime()
    if not timeInstalled and type(ZO_FormatTime) == "function" then
        timeInstalled = true
        local original = ZO_FormatTime
        ZO_FormatTime = function(seconds, style, precision, direction)
            local text, nextUpdate = original(seconds, style, precision, direction)
            if active() then
                local two = (TIME_FORMAT_STYLE_SHOW_LARGEST_TWO_UNITS ~= nil and style == TIME_FORMAT_STYLE_SHOW_LARGEST_TWO_UNITS)
                    or (TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL ~= nil and style == TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL)
                    or (TIME_FORMAT_STYLE_DESCRIPTIVE ~= nil and style == TIME_FORMAT_STYLE_DESCRIPTIVE)
                local one = (TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT ~= nil and style == TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT)
                    or (TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT_DESCRIPTIVE ~= nil and style == TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT_DESCRIPTIVE)
                if TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT ~= nil and style == TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT then
                    text = R.FormatCompactDuration(seconds)
                elseif two or one then text = R.FormatDuration(seconds, one and 1 or 2) end
            end
            return text, nextUpdate
        end
    end
    if ZO_EventAnnouncementTile and not ZO_EventAnnouncementTile.esoArabicTime then
        ZO_EventAnnouncementTile.esoArabicTime = true
        local original = ZO_EventAnnouncementTile.GetTimeRemainingText
        ZO_EventAnnouncementTile.GetTimeRemainingText = function(self, seconds)
            if active() then
                return R.FormatDuration(seconds, 2) .. " :" .. R.ShapeLogical("الوقت المتبقي")
            end
            return original(self, seconds)
        end
    end
end

local stack = {}
local nextPass = 0
local function update()
    if busy or not GuiRoot then return end
    if not active() then
        for c, state in pairs(states) do restore(c, state) end
        stack = {}; return
    end
    busy = true
    local started = type(GetGameTimeMilliseconds) == "function" and GetGameTimeMilliseconds() or 0
    if #stack == 0 then
        if started < nextPass then busy = false; return end
        stack[1] = {control = GuiRoot, index = 0}
    end
    local visited = 0
    -- Count each child enumeration against the budget too. GuiRoot can own
    -- thousands of pooled controls; pushing all its children used to be unbounded.
    while #stack > 0 and visited < 60 do
        local frame = stack[#stack]
        local c = frame.control
        visited = visited + 1
        if frame.index == 0 then
            if c ~= GuiRoot and call(c, "IsHidden") then
                table.remove(stack)
            else
                if CT_TOOLTIP and call(c, "GetType") == CT_TOOLTIP then installNativeTooltip(c) end
                local ok, err = pcall(R.BindDiscoveredControl or process, c)
                if not ok then
                    -- One third-party control must not permanently lock the
                    -- discovery loop or flood the chat on every update.
                    R.lastError = tostring(err)
                    if not R.discoveryErrorReported then
                        R.discoveryErrorReported = true
                        d("ESO Arabic: " .. tostring(err))
                    end
                end
                frame.count = call(c, "GetNumChildren") or 0
                frame.index = 1
            end
        elseif frame.index <= frame.count then
            local child = call(c, "GetChild", frame.index)
            frame.index = frame.index + 1
            if child then stack[#stack + 1] = {control = child, index = 0} end
        else
            table.remove(stack)
        end
        if type(GetGameTimeMilliseconds) == "function" and GetGameTimeMilliseconds() - started >= 2 then break end
    end
    local elapsed = type(GetGameTimeMilliseconds) == "function" and GetGameTimeMilliseconds() - started or 0
    R.Metrics.maxBatchMs = math.max(R.Metrics.maxBatchMs, elapsed)
    if #stack == 0 then nextPass = started + 1500 end
    busy = false
end

local savedInitialized = false
local function initialize()
    if not savedInitialized and ZO_SavedVars then
        config = ZO_SavedVars:NewAccountWide("ESOArabicSavedVariables", 1, nil, config)
        savedInitialized = true
    end
    installBooks(); installGamepadTooltips(); installTime()
    if R.InstallLayouts then R.InstallLayouts() end
    if R.InstallCompatibility then R.InstallCompatibility() end
    for _, name in ipairs({"InformationTooltip", "ItemTooltip", "PopupTooltip", "ComparativeTooltip1", "ComparativeTooltip2", "AchievementTooltip", "SkillTooltip", "AbilityTooltip"}) do installNativeTooltip(_G[name]) end
    getProbe()
    EVENT_MANAGER:RegisterForUpdate("ESOArabicVisibleText", 30, update)
end

if EVENT_MANAGER then
    EVENT_MANAGER:RegisterForEvent("ESOArabicInitialize", EVENT_PLAYER_ACTIVATED, initialize)
    EVENT_MANAGER:RegisterForEvent("ESOArabicLoaded", EVENT_ADD_ON_LOADED, function(_, name)
        if name == "EsoAR" or name == "ESO_Arabic" then initialize() end
    end)
end

if SLASH_COMMANDS then
    SLASH_COMMANDS["/arsize"] = function(value)
        local size = tonumber(value)
        if size and size >= 16 and size <= 36 then
            if gamepad() then config.gamepadMinimum = size else config.keyboardMinimum = size end
            for _, state in pairs(states) do state.width = nil end
            d("ESO Arabic: minimum text size = " .. size)
        else d("ESO Arabic: /arsize 22 (16-36, current input mode)") end
    end
    SLASH_COMMANDS["/archeck"] = function()
        local count = 0
        for c, state in pairs(states) do
            if state.overflow and not call(c, "IsHidden") then
                count = count + 1
                d("ESO Arabic overflow: " .. (call(c, "GetName") or "unnamed") .. " width=" .. tostring(state.width))
            end
        end
        d("ESO Arabic 1.3.2: " .. count .. " visible labels exceed the available space.")
    end
    SLASH_COMMANDS["/arstatus"] = function()
        d("ESO Arabic 1.3.2 | active=" .. tostring(active()) .. " | rendered=" .. R.Metrics.rendered
            .. " | measurements=" .. R.Metrics.measured .. " | max discovery batch ms=" .. R.Metrics.maxBatchMs)
    end
end
