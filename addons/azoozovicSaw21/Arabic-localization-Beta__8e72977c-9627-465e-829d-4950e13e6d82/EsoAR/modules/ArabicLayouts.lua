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
    return {size = gp and 36 or 26, minimum = gp and 26 or 22,
        face = REGULAR, flow = height == nil, height = height, unlimited = isBody,
        reflowVisual = true, align = TEXT_ALIGN_RIGHT}
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
    local text = c:GetText()
    local visualLines = IsInGamepadPreferredMode() and type(text) == "string" and text:find("\n", 1, true) ~= nil
    local opts = {flow = not single, single = single, align = TEXT_ALIGN_RIGHT, reflowVisual = visualLines}
    if name:find("gamemenu", 1, true) then
        opts.flow, opts.single = false, true
        opts.size, opts.minimum, opts.height = 22, 16, 28
    end
    local parent = c:GetParent()
    if name:find("champion", 1, true) and name:match("pointheader$")
        and child(parent, "ConstellationName") and child(parent, "PointValue") then
        local title, value = child(parent, "ConstellationName"), child(parent, "PointValue")
        title:SetWidth(200)
        title:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        c:ClearAnchors()
        c:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 0)
        value:ClearAnchors()
        value:SetAnchor(RIGHT, c, LEFT, -10, 0)
    end
    -- Tree rows have fixed native spacing. Keep their navigation caption on
    -- one measured line instead of spilling into the following menu entry.
    if parent and parent.node and parent.text == c then
        opts.flow, opts.single = false, true
        opts.size, opts.minimum = IsInGamepadPreferredMode() and 28 or 22, 16
    end
    -- A fixed-height row cannot grow when a translated caption wraps.
    -- This applies to keyboard navigation rows even when node.text is absent.
    if not IsInGamepadPreferredMode() and parent and parent.GetDesiredHeight then
        local rowHeight = parent:GetDesiredHeight()
        if rowHeight and rowHeight > 0 and rowHeight <= 40 then
            opts.flow, opts.single = false, true
            opts.height, opts.minimum = rowHeight, 14
        end
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
        if not IsInGamepadPreferredMode() and height > 0 and height <= 32 and not opts.multiline then
            opts.flow, opts.single = false, true
            opts.minimum = 14
        end
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
    if not IsInGamepadPreferredMode() and name:find("unitframe", 1, true)
        and (name:match("name$") or name:match("status$")) then
        opts.flow, opts.single = false, true
        opts.size, opts.minimum = 20, 14
        if name == "zo_companionunitframename" then
            -- Native nameWidth (215) extends beyond the 170px health bar.
            opts.autoWidth, opts.width, opts.height = false, 170, 22
            c:SetWidth(170)
            c:SetMaxLineCount(1)
        end
    end
    if not IsInGamepadPreferredMode() and name == "zo_guildsharedinfocountlabel" then
        opts.flow, opts.single, opts.autoWidth = false, true, true
        opts.size, opts.minimum = 18, 14
    end
    if not IsInGamepadPreferredMode() and name:find("questjournalnavigationentry", 1, true) then
        -- This native label is only 22px high. Header-sized Arabic glyphs
        -- extend below its clip rectangle even when their width fits.
        opts.flow, opts.single, opts.autoWidth = false, true, false
        opts.width, opts.height = 220, 22
        opts.size, opts.minimum = 16, 12
        c:SetMaxLineCount(1)
        c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    if not IsInGamepadPreferredMode() and name:find("collectionsbook", 1, true) then
        if name:find("subcategory", 1, true) then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.size, opts.minimum, opts.width = 20, 12, 218
            -- Match the actual label box to its measured width so the right
            -- edge remains inside the category scroll container's clip rect.
            c:SetWidth(218)
            c:SetMaxLineCount(1)
        end
    end
    if not IsInGamepadPreferredMode() and child(parent, "Title") == c
        and child(parent, "CooldownIconDesaturated") and child(parent, "CornerTag") then
        -- Collectible tiles reserve 54px below the icon, with side padding.
        opts.flow, opts.single, opts.autoWidth = false, false, false
        opts.multiline, opts.unlimited = true, true
        opts.height, opts.width = 50, math.max(40, parent:GetWidth() - 24)
        opts.size, opts.minimum = 20, 12
        opts.align = TEXT_ALIGN_CENTER
    end
    if not IsInGamepadPreferredMode() then
        if name:match("summaryinsetpoints$") and name:find("achievement", 1, true) then
            if not c.esoArabicSummaryPosition then
                c:ClearAnchors()
                c:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, -32)
                c.esoArabicSummaryPosition = true
            end
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.width, opts.size, opts.minimum = 300, 20, 14
        end
        local journalCategory = name:find("antiquityjournal_subcategory", 1, true)
            or name:find("achievements_subcategory", 1, true)
        if journalCategory then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.size, opts.minimum, opts.width = 18, 12, 210
            c:SetWidth(210)
            c:SetMaxLineCount(1)
        end
        if name:find("lorelibrarynavigationentry", 1, true) then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.size, opts.minimum, opts.width = 20, 12, 320
            c:SetWidth(320)
            c:SetMaxLineCount(1)
        elseif name:find("lorelibrary", 1, true) and child(parent, "Text") == c and child(parent, "Icon") then
            opts.flow, opts.single, opts.autoWidth = false, false, false
            opts.multiline, opts.unlimited = true, true
            opts.width, opts.height, opts.size, opts.minimum = c:GetWidth(), 44, 18, 12
        end
        if child(parent, "AntiquityType") and child(parent, "NumRecovered") then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.size, opts.minimum = 18, 12
            if child(parent, "Title") == c then opts.width = 340
            elseif child(parent, "AntiquityType") == c then opts.width = 155
            elseif child(parent, "NumRecovered") == c then opts.width = 175 end
            if opts.width then c:SetWidth(opts.width) end
            c:SetMaxLineCount(1)
        end
        if child(parent, "Points") and child(parent, "Description") and child(parent, "Title")
            and (child(parent, "Title") == c or child(parent, "Description") == c) then
            opts.flow, opts.autoWidth = false, false
            opts.width, opts.size, opts.minimum = 274, 18, 12
            c:SetWidth(274)
            if child(parent, "Title") == c then
                opts.single = true
                c:SetMaxLineCount(1)
            else
                local _, _, _, cap = c:GetDimensionConstraints()
                opts.height = cap and cap > 0 and cap or nil
                opts.multiline, opts.unlimited = true, true
                opts.flow = opts.height == nil
            end
        end
        if name:find("leaderboardsinformationarea", 1, true) then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.width = math.max(100, parent:GetWidth() / 2 - 12)
            opts.size, opts.minimum = 18, 12
            c:SetWidth(opts.width)
            c:SetMaxLineCount(1)
        end
    end
    -- Promotional activity rows reserve a single caption above Progress.
    -- Allowing automatic wrapping spills the caption into adjacent rows.
    if not IsInGamepadPreferredMode() and name:find("promotionalevent", 1, true)
        and child(parent, "Name") == c and child(parent, "TrackButton")
        and child(parent, "Progress") then
        opts.flow, opts.single, opts.autoWidth = false, true, false
        opts.size, opts.minimum = 22, 12
        opts.width = child(parent, "Progress"):GetWidth()
        opts.height = nil
        c:SetMaxLineCount(1)
    end
    if not IsInGamepadPreferredMode() then
        local collectionBook = name:find("dlcbook", 1, true) or name:find("housingbook", 1, true)
            or name:find("tributepatronbook", 1, true)
        if collectionBook and name:match("description$") then
            opts.reflowVisual = true
        end
        if name:find("specializedcollection_book_navigationentry", 1, true) then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.reflowVisual = true
            opts.width, opts.height, opts.size, opts.minimum = 200, 22, 16, 12
            c:SetWidth(200)
            c:SetMaxLineCount(1)
        end
        if name:find("lorelibrary", 1, true) and name:match("text$") then
            opts.reflowVisual = true
        end
        if name:find("itemsetsbook", 1, true) and child(parent, "Name") == c
            and child(parent, "Progress") then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.width = math.max(40, child(parent, "Progress"):GetWidth())
            opts.size, opts.minimum = 18, 12
            opts.reflowVisual = true
            c:SetMaxLineCount(1)
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
    -- Numeric labels never enter the Arabic shaping path. The replacement
    -- font has wider digits, so fit known numeric columns independently.
    local numericName = c:GetName() or ""
    local skillRank = numericName == "ZO_SkillsSkillInfoRank"
        or numericName == "ZO_CompanionSkills_Panel_KeyboardSkillLineInfoRank"
    if not IsInGamepadPreferredMode() and R.IsActive()
        and (skillRank
            or ((numericName:find("GuildRoster", 1, true)
                or numericName:find("FriendsList", 1, true)) and numericName:match("Level$"))) then
        local text = c:GetText() or ""
        local width = c:GetWidth()
        if text:match("^%d+$") and width > 0 then
            local signature = text .. ":" .. tostring(width)
            if c.esoArabicNumericFit ~= signature then
                c:SetMaxLineCount(1)
                if skillRank then
                    -- Name and XPBar anchor to opposite edges of Rank.
                    -- Preserve their vertical separation after fitting digits.
                    c:SetHeight(65)
                    c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                end
                local size = skillRank and 36 or 18
                c:SetFont(BOLD .. "|" .. size .. "|soft-shadow-thick")
                while c:GetTextWidth() > width and size > 12 do
                    size = size - 1
                    c:SetFont(BOLD .. "|" .. size .. "|soft-shadow-thick")
                end
                c.esoArabicNumericFit = signature
            end
        end
        return
    end
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
    -- Both chat systems share TextEntry, but maintain their own controls.
    local function alignEntry(entry)
        if not R.IsActive() then return end
        local label, bg, control = entry.channelLabel, entry.editBg, entry.control
        if not label or not bg or not control then return end
        label:ClearAnchors()
        label:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
        label:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
        label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        bg:ClearAnchors()
        bg:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
        bg:SetAnchor(TOPRIGHT, label, TOPLEFT, -8, 0)
    end
    for _, system in pairs({KEYBOARD_CHAT_SYSTEM, GAMEPAD_CHAT_SYSTEM}) do
        local entry = system and system.textEntry
        if entry and not entry.esoArabicRightEntry then
            entry.esoArabicRightEntry = true
            local original = entry.SetChannel
            entry.SetChannel = function(self, ...)
                local changed = original(self, ...)
                alignEntry(self)
                return changed
            end
            alignEntry(entry)
        end
    end

    local function fitCompanionName(self)
        if self.unitTag ~= "companion" or not R.IsActive() or IsInGamepadPreferredMode() then return end
        local label = self.nameLabel
        if not label or not R.HasArabic(label:GetText()) then return end
        -- Frame instances have generated names; identify the unit, not its
        -- virtual template name. Keep the caption inside the health bar edges.
        local refresh = R.BindLabel(label, function(c)
            c:ClearAnchors()
            c:SetAnchor(TOPLEFT, self.frame, TOPLEFT, 36, 17)
            c:SetWidth(170)
            c:SetMaxLineCount(1)
            return {single = true, autoWidth = false, width = 170, height = 22,
                size = 18, minimum = 12, align = TEXT_ALIGN_RIGHT}
        end)
        if refresh then refresh() end
    end
    hook(ZO_UnitFrameObject, "UpdateName", nil, fitCompanionName)
    hook(ZO_UnitFrameObject, "SetTextIndented", nil, fitCompanionName)
    local function refreshRaceClass(self)
        if not R.IsActive() or IsInGamepadPreferredMode() then return end
        local section = child(self.control, "TitleSection")
        local label = child(section, "RaceClass")
        local name = child(section, "Name")
        if not label or not name then return end
        label:SetText(zo_strformat("<<2>> — <<1>>", GetUnitRace("player"), GetUnitClass("player")))
        R.BindLabel(label, function()
            return {single = true, autoWidth = false, width = math.max(100, name:GetWidth()),
                size = 18, minimum = 12, align = TEXT_ALIGN_RIGHT}
        end)
    end
    hook(ZO_Stats, "RefreshTitleSection", nil, refreshRaceClass)
    if STATS then refreshRaceClass(STATS) end
    -- Use the original seconds, never parse already-localized unit strings.
    -- This formatter is shared by journal rows and Lua antiquity tooltips.
    if type(ZO_FormatAntiquityLeadTime) == "function" and not R.antiquityTimeHook then
        R.antiquityTimeHook = true
        local original = ZO_FormatAntiquityLeadTime
        ZO_FormatAntiquityLeadTime = function(seconds, ...)
            if R.IsActive() then return R.FormatDuration(seconds, 2) end
            return original(seconds, ...)
        end
    end
    hook(ZO_BattlegroundLeaderboardsManager_Keyboard, "RefreshHeaderTimer", nil, function(self)
        if not R.IsActive() or IsInGamepadPreferredMode() or not self.selectedSubType then return end
        local closes, opens = GetBattlegroundLeaderboardsSchedule(self.selectedSubType)
        local seconds = closes > 0 and closes or opens
        if seconds > 0 then
            self.timerLabel:SetText(zo_strformat(closes > 0 and SI_LEADERBOARDS_CLOSES_IN_TIMER
                or SI_LEADERBOARDS_REOPENS_IN_TIMER, R.FormatDuration(seconds, 2)))
        end
    end)
    if LORE_LIBRARY_SCENE and not R.journalLoreHook then
        R.journalLoreHook = true
        LORE_LIBRARY_SCENE:RegisterCallback("StateChange", function(_, state)
            if state ~= SCENE_SHOWING or not R.IsActive() then return end
            local search = _G.Lorebook_Research
            local label = child(search, "SearchLabel")
            if label then
                label:SetText(R.ShapeLogical("البحث في المكتبة:"))
                R.BindLabel(label, {single = true, width = 270, size = 18, minimum = 14, align = TEXT_ALIGN_RIGHT})
            end
            local box = child(search, "Box")
            if box then box:SetDefaultText(R.ShapeLogical("اسم الكتاب")) end
            local checkbox = LORE_LIBRARY and child(LORE_LIBRARY.totalCollectedLabel, "IncludeMotifs")
            if checkbox then ZO_CheckButton_SetLabelText(checkbox, R.ShapeLogical("تضمين الأنماط")) end
        end)
    end
    hook(_G, "ZO_GamepadGenericHeader_RefreshData", bindHeader, bindHeader)
    hook(ZO_Interaction, "ResetInteraction", bindKeyboard)
    hook(ZO_Interaction, "PopulateChatterOption", bindKeyboard)
    hook(ZO_GamepadInteraction, "ResetInteraction", bindGamepad)
    hook(ZO_GamepadInteraction, "FinalizeChatterOptions", bindGamepad)
    if INTERACTION then bindKeyboard(INTERACTION) end
    if GAMEPAD_INTERACTION then bindGamepad(GAMEPAD_INTERACTION) end
    local function subtitleOptions(c)
        local gp = IsInGamepadPreferredMode()
        return {flow = true, unlimited = true, reflowVisual = true,
            width = c:GetWidth(), size = gp and 30 or 26, minimum = 22,
            face = REGULAR, align = TEXT_ALIGN_CENTER}
    end
    local function bindSubtitle(self)
        local refresh = R.BindLabel(self.messageText, subtitleOptions)
        if refresh then refresh() end
    end
    local sub = ZO_SUBTITLE_MANAGER
    if sub then bindSubtitle(sub) end
    hook(ZO_SubtitleManager, "UpdatePlatformStyles", nil, bindSubtitle)
    hook(ZO_SubtitleManager, "OnShowSubtitle", bindSubtitle, function(self, messageType, speaker, message)
        if not R.IsActive() or not (R.HasArabic(message) or R.HasArabic(speaker)) then return end
        -- Preserve ESO's repeated-speaker suppression, timing and name color.
        -- Visual RTL text puts the speaker on the right, before the dialogue.
        local previous = self.previousSubtitle
        local showSpeaker = not (previous and previous:GetSpeakerName() == speaker
            and previous:GetStartTime() + previous:GetDisplayLength() + 5 >= GetFrameTimeSeconds())
        local text = R.Prepare(message)
        if showSpeaker then
            text = "|cffffff" .. text .. "|r :" .. R.Prepare(zo_strformat("<<t:1>>", speaker))
        end
        self.messageText:SetText(text)
        self.messageBackground:SetWidth(self.messageText:GetTextWidth())
    end)
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
    if R.InstallGamepadLayouts then R.InstallGamepadLayouts() end
end
