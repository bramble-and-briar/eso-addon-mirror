-- Screen adapters. Bind text at assignment time, before the owning UI measures it.
local R = ESO_ARABIC_TEXT
local REGULAR, BOLD = "EsoAR/fonts/ArabicUI.slug", "EsoAR/fonts/ArabicUIBold.slug"
local bound = setmetatable({}, {__mode = "k"})
local pending = setmetatable({}, {__mode = "k"})
local refreshRunning = false
local function reportError(b, err)
    R.lastError = tostring(err)
    if not b.reported then b.reported = true; d("ESO Arabic: " .. tostring(err)) end
end
local function queueRefresh(c)
    local b = bound[c]
    if b and not b.busy and not R.IsWriting(c) then pending[c] = true end
end
function R.FlushLayoutRefreshes()
    if refreshRunning then return end
    refreshRunning = true
    local count = 0
    local started = GetGameTimeMilliseconds and GetGameTimeMilliseconds()
    for c in pairs(pending) do
        pending[c] = nil
        local b = bound[c]
        if b then
            local ok, err = pcall(function() if not c:IsHidden() then b.refresh() end end)
            if not ok then reportError(b, err) end
        end
        count = count + 1
        if count >= 8 or (started and GetGameTimeMilliseconds() - started >= 2) then break end
    end
    refreshRunning = false
end
if EVENT_MANAGER then
    EVENT_MANAGER:RegisterForUpdate("ESOArabicLayoutRefresh", 30, R.FlushLayoutRefreshes)
end
local function child(c, name) return c and c.GetNamedChild and c:GetNamedChild(name) end
local function hook(object, key, before, after)
    if not object or type(object[key]) ~= "function" then return end
    local marker = "esoArabic131_" .. key
    if object[marker] then return end
    object[marker] = true
    local original = object[key]
    object[key] = function(self, ...)
        if before then before(self, ...) end
        local result = original(self, ...)
        if after then after(self, ...) end
        return result
    end
end

function R.BindLabel(c, options)
    if not c or not c.GetText or not c.SetText or c:GetType() ~= CT_LABEL then return end
    if bound[c] then
        if options then bound[c].options = options end
        return bound[c].refresh
    end
    local b = {original = c.SetText, options = options or {flow = true}}
    bound[c] = b
    R.Manage(c)
    local function render(text)
        if b.busy or R.IsWriting(c) or not R.IsActive() or not R.HasArabic(text) then return end
        b.busy = true
        local ok, err = pcall(function()
            local sourceOptions = type(b.options) == "function" and b.options(c) or b.options
            local opts = {}
            for k, v in pairs(sourceOptions) do opts[k] = v end
            opts.text, opts.managed = text, true
            if opts.size and (not c:GetFont() or c:GetFont() == "" or c:GetFontSize() == 0) then
                c:SetFont((opts.face or REGULAR) .. "|" .. opts.size .. "|soft-shadow-thin")
            end
            -- LabelControl has SetMaxLineCount but no GetMaxLineCount in ESO.
            -- Adaptive dialogue labels otherwise retain their native 11-line
            -- cap, even when our measured font fits more lines in the space.
            if (opts.flow or opts.unlimited) and not opts.autoWidth and not b.lineLimitCleared then
                c:SetMaxLineCount(0)
                b.lineLimitCleared = true
            end
            R.ProcessControl(c, opts)
        end)
        b.busy = false
        if not ok then reportError(b, err) end
    end
    b.refresh = function() render(c:GetText()) end
    c.SetText = function(self, text)
        if b.busy then return R.WriteText(self, text) end
        if R.IsActive() and R.HasArabic(text) then
            -- Avoid ESO's font-adjusting SetText override in Arabic. It chooses
            -- another font after each assignment and invalidates the line widths.
            b.busy = true
            local ok, err = pcall(R.WriteText, self, text)
            b.busy = false
            if not ok then reportError(b, err); return end
            render(text)
        else
            b.original(self, text)
            R.ProcessControl(self, {managed = true})
        end
    end
    if ZO_PostHookHandler then
        -- Native UI code can assign text without calling the Lua SetText
        -- override. Use the same guarded path for those assignments.
        -- Native rect notifications can run while ESO is resolving an auto-
        -- sized label. Measuring/mutating that same rect from the callback can
        -- make the native layout engine loop before Lua regains control.
        -- Lua SetText assignments above still reflow before owner measurement.
        local changed = function() queueRefresh(c) end
        ZO_PostHookHandler(c, "OnTextChanged", changed)
        ZO_PostHookHandler(c, "OnRectWidthChanged", changed)
        ZO_PostHookHandler(c, "OnEffectivelyShown", changed)
    end
    -- FontAdjustingWrapLabel also changes the font from OnUpdate. Keep that
    -- callback for non-Arabic text and suppress only its Arabic font selection.
    if c.GetFonts and c.GetHandler then
        local onUpdate = c:GetHandler("OnUpdate")
        if onUpdate then c:SetHandler("OnUpdate", function(self, ...)
            if R.IsActive() and R.HasArabic(self:GetText()) then return end
            return onUpdate(self, ...)
        end) end
    end
    b.refresh()
    return b.refresh
end

local function dialogueOptions(c)
    local gp = IsInGamepadPreferredMode()
    local name = c:GetName() or ""
    local isBody = c.GetFonts or name:find("BodyText", 1, true)
    local bottom = isBody and c.GetBottom and c:GetBottom()
    local height = bottom and math.max(160, bottom - 50) or nil
    return {size = gp and 36 or 30, minimum = gp and 26 or 24,
        face = REGULAR, flow = height == nil, height = height, unlimited = isBody,
        align = TEXT_ALIGN_RIGHT}
end
local function bindKeyboard(self)
    R.BindLabel(child(self.control, "TargetAreaBodyText"), dialogueOptions)
    for _, c in ipairs(self.optionControls or {}) do R.BindLabel(c, dialogueOptions) end
end
local function bindGamepad(self)
    R.BindLabel(self.textControl, dialogueOptions)
    local list = self.itemList
    if list and list.dataTypes then
        for name, info in pairs(list.dataTypes) do
            if (name == "ZO_ChatterOption_Gamepad" or name == "ZO_InteractWindow_GamepadBodyTextItem") and not info.esoArabic131 then
                info.esoArabic131 = true
                local original = info.setupFunction
                info.setupFunction = function(control, ...)
                    local label = child(control, "Text") or child(child(control, "TargetArea"), "BodyText")
                    local refresh = R.BindLabel(label, dialogueOptions)
                    original(control, ...)
                    if refresh then refresh() end
                    if name == "ZO_ChatterOption_Gamepad" and label then control:SetHeight(label:GetTextHeight()) end
                end
            end
        end
    end
end

local function statsRow(row)
    if not row then return end
    local name, value = row.name or row.nameLabel, row.value or row.valueLabel
    if not name or not value or not R.HasArabic(name:GetText()) then return end
    local reserve = math.max(65, value:GetTextWidth())
    for _, key in ipairs({"pendingBonus", "comparisonValue"}) do
        local extra = row[key]
        if extra and not extra:IsHidden() then reserve = reserve + extra:GetTextWidth() + 8 end
    end
    local width = math.max(50, row:GetWidth() - reserve - 36)
    name:ClearAnchors()
    name:SetAnchor(LEFT, row, LEFT, 0, 0)
    name:SetWidth(width)
    name:SetMaxLineCount(1)
    R.Manage(name)
    R.ProcessControl(name, {managed = true, single = true, width = width,
        size = 20, minimum = 14, align = TEXT_ALIGN_RIGHT})
end
R.LayoutStatsRow = statsRow

local function horizontalPoint(point)
    if point == LEFT or point == TOPLEFT or point == BOTTOMLEFT then return 0 end
    if point == RIGHT or point == TOPRIGHT or point == BOTTOMRIGHT then return 2 end
    return 1
end

local function stretchesHorizontally(c)
    if c:GetNumAnchors() < 2 then return false end
    if not c.GetAnchor then return true end
    local first
    for i = 0, c:GetNumAnchors() - 1 do
        local valid, point, _, _, _, _, constraint = c:GetAnchor(i)
        if valid and constraint ~= ANCHOR_CONSTRAINS_Y then
            local x = horizontalPoint(point)
            if first ~= nil and first ~= x then return true end
            first = x
        end
    end
    return false
end

local function discoveredOptions(c)
    local name = (c:GetName() or ""):lower()
    local single = name:find("keybind", 1, true) or name:find("button", 1, true)
    local opts = {flow = not single, single = single, align = TEXT_ALIGN_RIGHT}
    local parent = c:GetParent()
    -- Tree rows have fixed native spacing. Keep their navigation caption on
    -- one measured line instead of spilling into the following menu entry.
    if parent and parent.node and parent.text == c then
        opts.flow, opts.single = false, true
        opts.size, opts.minimum = IsInGamepadPreferredMode() and 28 or 22, 16
    end
    if name:find("buff", 1, true) and name:find("duration", 1, true) then
        opts.flow, opts.single, opts.align = false, true, TEXT_ALIGN_CENTER
        opts.size, opts.minimum = 20, 14
    end
    if name:find("gamepadplayerprogressbar", 1, true) or name:find("genericfooter_gamepad", 1, true) then
        opts.flow, opts.single = false, true
        opts.size, opts.minimum = 30, 22
    end
    if parent and name:find("inventory", 1, true) and name:match("name$") and parent.GetDesiredHeight then
        local rowHeight = parent:GetDesiredHeight()
        if rowHeight and rowHeight > 0 then
            opts.flow, opts.height, opts.minimum = false, math.max(20, rowHeight - 4), 16
            opts.multiline = true
            opts.unlimited = true
            opts.size = 20
        end
    end
    if c.GetDesiredHeight then
        local height = c:GetDesiredHeight()
        if height > 0 and not opts.multiline then opts.flow, opts.height = false, height end
    end
    if c.GetDesiredWidth and c:GetDesiredWidth() <= 0 and not stretchesHorizontally(c) then
        local _, _, maximum = c:GetDimensionConstraints()
        if maximum and maximum > 0 then
            -- Quest headers have a maximum width but shrink to the rendered
            -- glyphs. Reusing that glyph extent loses padding on every pass.
            opts.width = maximum
        else
            opts.autoWidth = true
        end
    end
    return opts
end

local function buttonOptions(c, button)
    return {single = true, flow = false, width = math.max(40, button:GetWidth() - 16),
        size = IsInGamepadPreferredMode() and 26 or 22, minimum = 14,
        align = TEXT_ALIGN_CENTER}
end

local function bindButton(c)
    -- A ButtonControl owns a native LabelControl which is not necessarily a
    -- child returned by GetChild. Use the documented label accessor.
    if not c.GetLabelControl then return end
    local label = c:GetLabelControl()
    if not label or not R.HasArabic(label:GetText()) then return end
    local refresh = R.BindLabel(label, function(l) return buttonOptions(l, c) end)
    if not c.esoArabicButtonHook and ZO_PostHook then
        c.esoArabicButtonHook = true
        ZO_PostHook(c, "SetText", function() queueRefresh(label) end)
    end
    if refresh then refresh() end
end

local function headerOptions(c)
    -- ESO stretches the caption across the whole row and anchors its value
    -- to that row's right edge. Right-aligning that caption overlays the value.
    local key = (c:GetName() or ""):match("(Data[1-4])Header$")
    local value = key and child(c:GetParent(), key)
    local opts = {single = true, align = TEXT_ALIGN_LEFT, size = 26, minimum = 20}
    if value and not value:IsHidden() and stretchesHorizontally(c) then
        opts.width = math.max(40, c:GetWidth() - value:GetTextWidth() - 20)
    elseif not stretchesHorizontally(c) then
        opts.autoWidth = true
    end
    return opts
end

local function bindHeader(control)
    for i = 1, 4 do
        local c = child(control, "Data" .. i .. "Header")
        if c then
            local refresh = R.BindLabel(c, headerOptions)
            if refresh then refresh() end
        end
    end
end

function R.BindDiscoveredControl(c)
    if CT_BUTTON and c:GetType() == CT_BUTTON then bindButton(c); return end
    if c:GetType() ~= CT_LABEL then return end
    if bound[c] then bound[c].refresh(); return end
    if R.IsManaged(c) then return end
    local text = c:GetText()
    if not R.HasArabic(text) then return end
    local name = c:GetName() or ""
    -- Existing specialized layouts (books/tooltips) remain under their owners.
    if name:find("ESOArabic", 1, true) then return end
    local parent = c:GetParent()
    if parent and ((parent.name == c and parent.value) or (parent.nameLabel == c and parent.valueLabel)) then
        statsRow(parent); return
    end
    R.Metrics.discovered = R.Metrics.discovered + 1
    -- GetWidth on a natural-width title is its current text extent, not an
    -- available text box. Feeding that extent back as a wrap limit continually
    -- shrinks the label and splits short headings into individual glyphs.
    R.BindLabel(c, name:match("Data[1-4]Header$") and headerOptions or discoveredOptions)
end

function R.InstallLayouts()
    hook(_G, "ZO_GamepadGenericHeader_RefreshData", bindHeader, bindHeader)
    hook(ZO_Interaction, "ResetInteraction", bindKeyboard)
    hook(ZO_Interaction, "PopulateChatterOption", bindKeyboard)
    hook(ZO_GamepadInteraction, "ResetInteraction", bindGamepad)
    hook(ZO_GamepadInteraction, "FinalizeChatterOptions", bindGamepad)
    if INTERACTION then bindKeyboard(INTERACTION) end
    if GAMEPAD_INTERACTION then bindGamepad(GAMEPAD_INTERACTION) end
    local sub = ZO_SUBTITLE_MANAGER
    if sub then R.BindLabel(sub.messageText, dialogueOptions) end
    hook(ZO_SubtitleManager, "OnShowSubtitle", function(self) R.BindLabel(self.messageText, dialogueOptions) end)
    for _, screen in ipairs({LoadingScreen, GamepadLoadingScreen}) do
        if screen and screen.zoneDescription then
            R.BindLabel(screen.zoneDescription, {flow = true, size = 30, face = REGULAR, align = TEXT_ALIGN_RIGHT})
        end
    end
    hook(LoadingScreen_Base, "SetZoneDescription", function(self)
        R.BindLabel(self.zoneDescription, {flow = true, size = 30, face = REGULAR, align = TEXT_ALIGN_RIGHT})
    end)
    hook(ZO_StatEntry_Keyboard, "UpdateStatValue", nil, function(self) statsRow(self.control) end)
    hook(ZO_StatEntry_Keyboard, "ShowComparisonValue", nil, function(self) statsRow(self.control) end)
    if STATS and STATS.statEntries then
        for _, entry in pairs(STATS.statEntries) do statsRow(entry.control) end
    end
    -- All parametric gamepad list items are measured just after this function.
    hook(ZO_ParametricScrollList, "RunSetupOnControl", nil, function(self, control)
        if not R.IsActive() then return end
        local function visit(c, depth)
            if not c or depth > 3 then return end
            if c:GetType() == CT_LABEL then
                if not bound[c] and not R.IsManaged(c) and R.HasArabic(c:GetText()) then
                    R.BindLabel(c, function(label)
                        local opts = discoveredOptions(label)
                        opts.size, opts.minimum = 28, 20
                        return opts
                    end)
                elseif bound[c] then bound[c].refresh() end
            end
            for i = 1, c:GetNumChildren() do visit(c:GetChild(i), depth + 1) end
        end
        visit(control, 0)
    end)
end
