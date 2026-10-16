-- Targeted controller adapters. No polling or traversal of the global UI tree.
local R = ESO_ARABIC_TEXT
local function active() return R.IsActive() and IsInGamepadPreferredMode() end
local function child(c, name) return c and c.GetNamedChild and c:GetNamedChild(name) end
local function after(object, method, fn, adapterId)
    if not object or type(object[method]) ~= "function" then return end
    -- Separate adapters may share one native method (quest rewards and the
    -- Crown Store both use RunSetupOnControl). Deduplicate each adapter,
    -- not the entire method, when initialization runs again after zoning.
    local key = "esoArabicGamepad_" .. method .. (adapterId and ("_" .. adapterId) or "")
    if object[key] then return end
    object[key] = true
    -- Never wrap the shared list setup: housing invokes private market APIs.
    if method == "RunSetupOnControl" then
        if SecurePostHook then
            SecurePostHook(object, method, function(self, ...)
                if active() then fn(self, ...) end
            end)
        end
        return
    end
    local original = object[method]
    object[method] = function(self, ...)
        local result = original(self, ...)
        if active() then fn(self, ...) end
        return result
    end
end
local function fit(c, width, size, height)
    if not c then return end
    local refresh = R.BindLabel(c, {single = true, autoWidth = false,
        width = math.max(20, width), height = height or size + 8,
        size = size, minimum = 16, align = TEXT_ALIGN_RIGHT})
    if refresh then refresh() end
end
local function box(c, parent, x, y, width, size)
    if not c then return end
    c:ClearAnchors()
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetWidth(width)
    fit(c, width, size)
end
local function antiquity(_, c)
    if not c or not c.header then return end
    local width = c.header:GetWidth()
    if width <= 0 then return end
    box(c.titleLabel, c.header, 0, 0, width, 30)
    -- Independent columns prevent natural-width Arabic labels overlapping.
    local column = (width - 16) / 3
    box(c.difficultyLabel, c.header, 2 * (column + 8), 38, column, 20)
    box(c.numRecoveredLabel, c.header, column + 8, 38, column, 20)
    box(c.antiquityTypeLabel, c.header, 0, 38, column, 20)
    box(c.zoneLabel, c.header, 0, 67, width, 22)
    fit(c.leadExpirationLabel, width, 22)
end
local function rewardItem(c)
    local label, icon, spacer = child(c, "Label"), child(c, "Icon"), child(c, "RootSpacer")
    if not label or not icon or not spacer then return end
    -- The row resizes to its descendants. Its RIGHT edge must never be an
    -- input to their positions. RootSpacer has a fixed template width and
    -- depends only on the row's TOPLEFT, so this chain has no size feedback.
    local width, iconWidth = spacer:GetWidth(), icon:GetWidth()
    if width <= iconWidth + 60 then return end
    label:ClearAnchors()
    label:SetAnchor(TOPRIGHT, spacer, TOPRIGHT, -iconWidth - 24, 0)
    label:SetWidth(width - iconWidth - 36)
    fit(label, width - iconWidth - 36, 28, 44)
    icon:ClearAnchors()
    icon:SetAnchor(LEFT, label, RIGHT, 12, 0)
    -- Highlight and stack count remain attached to the native icon.
end
local function researchSlot(_, c)
    local name, status, background = c.nameLabel, c.statusLabel, child(c, "Bg")
    if not name or not status or not background then return end
    local width = background:GetWidth()
    if width < 200 then return end
    local statusWidth = math.floor((width - 72) * 0.46)
    local nameWidth = width - 72 - statusWidth
    -- Research uses 43px rows in all four professions. Natural-width labels
    -- used to collide; give the trait and its state independent columns.
    name:ClearAnchors()
    name:SetAnchor(LEFT, c, RIGHT, 10, 0)
    name:SetWidth(nameWidth)
    fit(name, nameWidth, 26, 43)
    status:ClearAnchors()
    status:SetAnchor(RIGHT, background, RIGHT, -10, 0)
    status:SetWidth(statusWidth)
    fit(status, statusWidth, 26, 43)
end
local function researchHeader(self)
    local container = child(self.control, "ResearchLineList")
    local title, selected = child(container, "Title"), child(container, "SelectedLabel")
    if not title or not selected then return end
    local width = container:GetWidth() - 20
    if width <= 40 then return end
    -- The native 195px research panel places the icon list at y=62.5.
    -- Reserve two separate rows above it instead of centering the selected
    -- item over the title. Both rows finish at y=62, before the icons.
    title:ClearAnchors()
    title:SetAnchor(TOPRIGHT, container, TOPRIGHT, -10, 4)
    title:SetDimensions(width, 26)
    fit(title, width, 20, 26)
    selected:ClearAnchors()
    selected:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 0)
    selected:SetDimensions(width, 32)
    fit(selected, width, 26, 32)
end
local function skillEntry(c)
    local label = c and c.label
    if not label then return end
    local width = label:GetWidth()
    if width <= 40 then return end
    -- Skills Advisor uses 60px rows. Native setup reserves space for icons,
    -- locks and keybinds; keep that width and fit one complete name into it.
    -- Rejoin line breaks written by earlier generic/pool refreshes first.
    local refresh = R.BindLabel(label, {single = true, reflowVisual = true,
        width = width, height = 44, size = 26, minimum = 16,
        autoWidth = false, align = TEXT_ALIGN_RIGHT})
    label:SetHeight(44)
    label:SetMaxLineCount(1)
    if refresh then refresh() end
end
local function skillsHeader(c)
    if not GAMEPAD_SKILLS or c ~= GAMEPAD_SKILLS.header then return end
    local divider = child(c, "DividerSimple")
    if not divider then return end
    local titleContainer = child(c, "TitleContainer")
    local width = divider:GetWidth()
    if width < 200 and titleContainer then width = titleContainer:GetWidth() end
    if width < 200 then width = c:GetWidth() end
    if width < 200 then width = ZO_GAMEPAD_CONTENT_WIDTH or 400 end
    local title, subtitle = child(titleContainer, "Title"), child(titleContainer, "SubTitle")
    if title and subtitle then
        local subtitleHeight = (subtitle:GetText() or "") == "" and 0 or 30
        title:ClearAnchors()
        title:SetAnchor(BOTTOMRIGHT, titleContainer, BOTTOMRIGHT, 0, -subtitleHeight)
        title:SetDimensions(width, 46)
        fit(title, width, 36, 46)
        subtitle:ClearAnchors()
        subtitle:SetAnchor(BOTTOMRIGHT, titleContainer, BOTTOMRIGHT, 0, 0)
        subtitle:SetDimensions(width, 30)
        fit(subtitle, width, 20, 30)
    end
    local h1, v1 = child(c, "Data1Header"), child(c, "Data1")
    local h2, v2 = child(c, "Data2Header"), child(c, "Data2")
    if not h1 or not v1 or not h2 or not v2 then return end
    -- Points and Skyshards each get a separate half-width column: caption
    -- above value. Neither translated caption can collide with either number.
    local column = (width - 24) / 2
    for i, pair in ipairs({{h1, v1}, {h2, v2}}) do
        local caption, value = pair[1], pair[2]
        caption:ClearAnchors()
        caption:SetAnchor(TOPRIGHT, divider, BOTTOMRIGHT, -(i - 1) * (column + 24), 16)
        caption:SetDimensions(column, 28)
        fit(caption, column, 20, 28)
        value:ClearAnchors()
        value:SetAnchor(TOPRIGHT, caption, BOTTOMRIGHT, 0, 0)
        value:SetDimensions(column, 38)
        R.Manage(value)
        value:SetFont("EsoAR/fonts/ArabicUI.slug|28|soft-shadow-thin")
        value:SetMaxLineCount(1)
        value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    end
    local actionBar = child(c, "AssignableActionBar")
    if actionBar then
        actionBar:ClearAnchors()
        actionBar:SetAnchor(TOP, divider, BOTTOM, 0, 120)
    end
    if c.headerFocusControl then
        c.headerFocusControl:ClearAnchors()
        c.headerFocusControl:SetAnchor(TOPLEFT, divider, BOTTOMLEFT, 0, 84)
    end
end
R.LayoutSkillsHeader = skillsHeader
local function ridingBar(c)
    local value = c and (c.value or child(c, "Value"))
    if not value then return end
    R.ReleaseLabelBinding(value)
    R.Manage(value)
    value:SetFont("EsoAR/fonts/ArabicUI.slug|26|soft-shadow-thin")
    value:SetMaxLineCount(1)
    value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    value:ClearAnchors()
    value:SetAnchor(RIGHT, c, RIGHT, 0, 0)
    value:SetDimensions(90, 36)
    c:SetHeight(40)
end
local function ridingRow(_, c)
    local label, bar = c and c.label, child(c, "BarContainer")
    if not label or not bar then return end
    local width = label:GetWidth()
    if width <= 0 then return end
    label:SetHeight(36)
    label:SetMaxLineCount(1)
    fit(label, width, 26, 36)
    bar:ClearAnchors()
    bar:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, 8)
    bar:SetAnchor(TOPRIGHT, label, BOTTOMRIGHT, 0, 8)
    ridingBar(bar)
end
R.LayoutRidingBar = ridingBar
R.LayoutRidingRow = ridingRow
local function pursuitRow(self)
    local c, label, bar = self.control, self.nameLabel, self.progressStatusBar
    if not c or not label or not bar then return end
    local width = bar:GetWidth()
    if width <= 0 then width = c:GetWidth() - 130 end
    if width <= 0 then return end
    -- The scroll list owns a fixed 120px row. Reserve a bounded text area
    -- above the bar instead of letting wrapped text grow into adjacent rows.
    label:ClearAnchors()
    label:SetAnchor(TOPLEFT, c, TOPLEFT, 16, 4)
    label:SetDimensions(width, 72)
    local refresh = R.BindLabel(label, {width = width, height = 72,
        size = 26, minimum = 18, flow = false, multiline = true,
        reflowVisual = true, align = TEXT_ALIGN_RIGHT})
    if refresh then refresh() end
    label:SetHeight(72)
    label:SetMaxLineCount(2)
    bar:ClearAnchors()
    bar:SetAnchor(TOPLEFT, c, TOPLEFT, 16, 86)
    bar:SetWidth(width)
end
R.LayoutPursuitRow = pursuitRow
local function guildResult(_, c)
    local name, count, caption = c.guildNameLabel, c.guildSizeLabel, c.guildSizeHeaderLabel
    if not name or not count or not caption then return end
    name:SetWidth(270)
    name:SetFont("ZoFontGamepad27")
    count:SetWidth(58)
    count:SetMaxLineCount(1)
    caption:SetWidth(165)
    fit(caption, 165, 20, 30)
    local h, v = c.guildContextualInfoHeaderLabel, c.guildContextualInfoValueLabel
    if h and v then
        h:SetWidth(120)
        fit(h, 120, 20, 30)
        v:ClearAnchors()
        v:SetAnchor(TOPLEFT, h, TOPRIGHT, 12, 0)
        v:SetWidth(430)
        fit(v, 430, 24, 32)
    end
end
local function guildInfo(self)
    local keys = {"foundedLabelPair", "personalitiesLabelPair", "languagesLabelPair",
        "playtimeLabelPair", "rolesLabelPair", "minCPLabelPair", "guildTraderLabelPair"}
    for _, key in ipairs(keys) do
        local pair = self[key]
        if pair and pair.header and pair.value then
            local trader = key == "guildTraderLabelPair"
            local width = trader and 650 or 220
            pair:SetResizeToFitDescendents(false)
            pair:SetDimensions(width, 64)
            pair.header:ClearAnchors()
            pair.header:SetAnchor(TOPRIGHT, pair, TOPRIGHT, 0, 0)
            pair.header:SetDimensions(width, 28)
            fit(pair.header, width, 19, 28)
            pair.value:ClearAnchors()
            pair.value:SetAnchor(TOPRIGHT, pair.header, BOTTOMRIGHT, 0, 2)
            pair.value:SetDimensions(width, 32)
            R.ReleaseLabelBinding(pair.value)
            R.Manage(pair.value)
            pair.value:SetFont("EsoAR/fonts/ArabicUI.slug|22|soft-shadow-thin")
            pair.value:SetMaxLineCount(1)
            if R.HasArabic(pair.value:GetText()) then fit(pair.value, width, 22, 32) end
            pair.value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        end
    end
    local size = self.sizeLabelPair
    if size and size.header then fit(size.header, 165, 20, 30) end
end

-- Armory overview headers are pooled. Reserve separate RTL caption/value
-- columns and restore the native geometry on every acquisition.
local function installArmoryOverview()
    local class = ZO_ArmoryBuildOverview_Gamepad
    if not class or class.esoArabicSeparatedColumns then return end
    class.esoArabicSeparatedColumns = true
    local acquire = class.AcquireHeaderControl
    class.AcquireHeaderControl = function(self, ...)
        local row = acquire(self, ...)
        for _, name in ipairs({"Stat", "Value"}) do
            local label = child(row, name)
            if label then
                if not label.esoArabicArmoryNative then
                    local saved = {font = label:GetFont(), width = label:GetWidth(), height = label:GetHeight(), align = label:GetHorizontalAlignment(), anchors = {}}
                    for i = 0, label:GetNumAnchors() - 1 do
                        local valid, point, target, relative, x, y = label:GetAnchor(i)
                        if valid then table.insert(saved.anchors, {point, target, relative, x, y}) end
                    end
                    label.esoArabicArmoryNative = saved
                end
                R.ReleaseLabelBinding(label)
                local saved = label.esoArabicArmoryNative
                label:ClearAnchors()
                label:SetDimensions(saved.width, saved.height)
                label:SetFont(saved.font)
                label:SetHorizontalAlignment(saved.align)
                for _, anchor in ipairs(saved.anchors) do label:SetAnchor(unpack(anchor)) end
                if name == "Value" then label:SetHidden(true) end
            end
        end
        return row
    end
    local add = class.AddStatValuePair
    class.AddStatValuePair = function(self, ...)
        local row = add(self, ...)
        if active() then
            -- The native row can extend past the scroll viewport after its 50px indent.
            -- Limit both columns to the actual visible space, with a right inset.
            local width = math.min(395, self.scrollContainer:GetRight() - row:GetLeft() - 24)
            width = math.max(220, width)
            local gap = 20
            local valueWidth = math.floor((width - gap) * 0.48)
            local statWidth = width - gap - valueWidth
            for _, spec in ipairs({{"Stat", statWidth, BOTTOMRIGHT, TEXT_ALIGN_RIGHT, 24}, {"Value", valueWidth, BOTTOMLEFT, TEXT_ALIGN_LEFT, 32}}) do
                local label = child(row, spec[1])
                label:ClearAnchors()
                if spec[1] == "Stat" then
                    label:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, valueWidth + gap, -2)
                else
                    label:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, -2)
                end
                label:SetDimensions(spec[2], 44)
                label:SetMaxLineCount(1)
                label:SetHorizontalAlignment(spec[4])
                local fontSize = spec[5]
                repeat
                    label:SetFont("EsoAR/fonts/ArabicUI.slug|" .. fontSize .. "|soft-shadow-thin")
                    if label:GetTextWidth() <= spec[2] or fontSize <= 16 then break end
                    fontSize = fontSize - 1
                until false
            end
        end
        return row
    end
end

function R.InstallGamepadLayouts()
    installArmoryOverview()
    after(ZO_GuildBrowser_GuildList_Gamepad, "SetupRow", guildResult, "guildResult")
    after(ZO_GuildBrowser_GuildInfo_Gamepad, "RefreshInfoPanel", guildInfo, "guildInfo")
    after(ZO_PromotionalEventActivity_Entry_Gamepad, "SetActivityData", pursuitRow, "pursuitRow")
    after(ZO_StableTrainingBar_Gamepad, "SetValue", ridingBar, "ridingValue")
    after(ZO_Stable_Gamepad, "SetupEntry", ridingRow, "ridingRow")
    after(ZO_StableTrainingBar_Gamepad, "Initialize", function(_, control)
        ridingBar(control)
    end, "ridingInit")
    after(ZO_TooltipSection, "AddStatusBar", function(_, bar)
        if bar and bar.valueFormat and bar.value and child(bar, "StatusBar") then ridingBar(bar) end
    end, "ridingTooltip")
    after(_G, "ZO_GamepadSkillEntryTemplate_Setup", skillEntry, "skillRows")
    after(_G, "ZO_GamepadCompanionSkillEntryTemplate_Setup", skillEntry, "skillRows")
    after(_G, "ZO_GamepadSkillEntryPreviewRow_Setup", skillEntry, "skillPreviewRows")
    after(ZO_AntiquityJournalListGamepad, "SetupBaseLogbookRow", function(_, c)
        if not c.header or not c.progressContainer then return end
        local width = c.header:GetWidth()
        if width < 200 then return end
        -- The codex counter has its own left column, outside the title.
        box(c.titleLabel, c.header, 100, 0, width - 100, 26)
        box(c.antiquityTypeLabel, c.header, 100, 40, (width - 110) / 2, 20)
        box(c.numRecoveredLabel, c.header, 105 + (width - 110) / 2, 40, (width - 110) / 2, 20)
        c.progressContainer:ClearAnchors()
        c.progressContainer:SetAnchor(TOPLEFT, c.header, TOPLEFT, 0, 0)
        c.progressContainer:SetDimensions(90, 76)
        box(c.progressLabel, c.progressContainer, 0, 0, 90, 24)
        box(child(c.progressContainer, "LogBook"), c.progressContainer, 0, 36, 90, 22)
    end)
    for _, class in pairs({ZO_Veterancy_RankTile_Shared, ZO_Veterancy_RankTile_Gamepad}) do
    after(class, "Layout", function(self)
        local label, icon = self.titleLabel, self.iconTexture
        if not label or not icon then return end
        label:ClearAnchors()
        label:SetAnchor(TOPLEFT, icon, BOTTOMLEFT, 0, 3)
        label:SetWidth(150)
        label:SetHeight(48)
        label:SetMaxLineCount(2)
        local refresh = R.BindLabel(label, {width = 150, height = 48,
            size = 18, minimum = 18, reflowVisual = true, flow = true,
            align = TEXT_ALIGN_CENTER})
        if refresh then refresh() end
        label:SetHeight(48)
        label:SetMaxLineCount(2)
    end)
    end
    after(ZO_GamepadStats, "RefreshCharacterPanel", function(self)
        local panel, bar, value = self.characterStatsPanel, self.experienceBarControl, self.experienceProgress
        local caption = child(panel, "ExperienceProgressLabel")
        local anchor = child(panel, "LeftColumnRidingCapacityHeader")
        if not bar or not value or not caption or not anchor then return end
        local width = 400 -- native XML width; native fill direction is untouched
        caption:ClearAnchors()
        caption:SetAnchor(TOPLEFT, anchor, BOTTOMLEFT, 0, 50)
        fit(caption, width, 24, 32)
        caption:SetDimensions(width, 32)
        R.ReleaseLabelBinding(value)
        local xp, total
        if CanUnitGainChampionPoints("player") then
            xp = GetPlayerChampionXP()
            total = GetNumChampionXPInChampionPoint(GetPlayerChampionPointsEarned())
        else
            xp = GetUnitXP("player")
            total = GetNumExperiencePointsInLevel(GetUnitLevel("player"))
        end
        if type(total) == "number" and total > 0 then
            -- A numeric-only line remains LTR: earned / required (percent).
            value:SetText(ZO_CommaDelimitNumber(xp) .. " / " .. ZO_CommaDelimitNumber(total)
                .. " (" .. math.floor(xp / total * 100) .. "%)")
        end
        R.ProcessControl(value, {managed = true, single = true, force = true,
            width = width, size = 24, minimum = 24, align = TEXT_ALIGN_RIGHT})
        value:SetFont("EsoAR/fonts/ArabicUI.slug|24|soft-shadow-thin")
        value:SetDimensions(width, 32)
        value:SetMaxLineCount(1)
        value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        value:ClearAnchors()
        value:SetAnchor(TOPLEFT, anchor, BOTTOMLEFT, 0, 84)
        bar:ClearAnchors()
        bar:SetAnchor(TOPLEFT, anchor, BOTTOMLEFT, 0, 124)
        bar:SetWidth(width)
        -- Retain native enlightenment text width, colors, and bar direction.
    end)
    -- Copy this style: never mutate the shared native style table.
    if ZO_Tooltip and not R.rtlItemTopStyle then
        R.rtlItemTopStyle = true
        local original = ZO_Tooltip.GetStyle
        ZO_Tooltip.GetStyle = function(self, name)
            local style = original(self, name)
            if active() and name == "topSubsectionItemDetails" and style then
                local copy = {}; for k, v in pairs(style) do copy[k] = v end
                copy.layoutPrimaryDirection = "left"
                copy.layoutSecondaryDirection = "up"
                return copy
            end
            return style
        end
    end
    if ZO_Tooltip and ZO_TooltipSection and not R.rtlCurrencyRows then
        R.rtlCurrencyRows = true
        local inCurrencies = false
        local replacedPairs = setmetatable({}, {__mode = "k"})
        local layout, add = ZO_Tooltip.LayoutCurrencies, ZO_TooltipSection.AddStatValuePair
        if layout and add then
            ZO_Tooltip.LayoutCurrencies = function(self, ...)
                local previous = inCurrencies
                inCurrencies = active()
                local ok, result = pcall(layout, self, ...)
                inCurrencies = previous
                if not ok then error(result) end
                return result
            end
            ZO_TooltipSection.AddStatValuePair = function(self, pair)
                if replacedPairs[pair] then
                    pair:SetHidden(false)
                    replacedPairs[pair] = nil
                end
                if inCurrencies and pair.statLabel and pair.valueLabel then
                    -- Independent native tooltip labels replace the baseline-
                    -- anchored pair. Pool reset and measurement stay under ESO.
                    -- Read narration strings: they retain the complete source
                    -- even when a recycled label has an invalid/clipped width.
                    local width = self:GetInnerSecondaryDimension()
                    if type(width) ~= "number" or width <= 0 then return add(self, pair) end
                    local row = self:AcquireSection({width = width, height = 40,
                        layoutPrimaryDirection = "right", layoutSecondaryDirection = "down",
                        childSpacing = 12, padding = 0})
                    local amountWidth = math.floor(width * .47)
                    local amount = pair.valueTextNarration or pair.valueLabel:GetText() or ""
                    amount = amount:gsub("^(.-)%s*(|t[^|]+|t)$", "%2 %1")
                    local name = pair.statTextNarration or pair.statLabel:GetText() or ""
                    name = "|cC5C29E" .. name:gsub("|[cC]%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r"
                    local function column(text, columnWidth, alignment, size, color)
                        row:AddLine(text, {width = columnWidth, height = 40,
                            fontFace = "EsoAR/fonts/ArabicUI.slug", fontSize = size,
                            fontColorType = INTERFACE_COLOR_TYPE_GENERAL, fontColorField = color,
                            horizontalAlignment = alignment, uppercase = false,
                            esoArabicFixedRow = true})
                    end
                    column(amount, amountWidth, TEXT_ALIGN_LEFT, 22, GENERAL_COLOR_WHITE)
                    column(name, width - amountWidth - 12, TEXT_ALIGN_RIGHT, 20, GENERAL_COLOR_OFF_WHITE)
                    self:AddSection(row)
                    -- The source pair was acquired but never attached. Its old
                    -- anchors survive pool reuse; hide it until a native add.
                    pair:SetHidden(true)
                    replacedPairs[pair] = true
                    return
                end
                return add(self, pair)
            end
        end
    end
    after(_G, "ZO_GamepadGenericHeader_RefreshData", skillsHeader, "skillsHeader")
    local function refreshSkills(self)
        if not self.header then return end
        skillsHeader(self.header)
        if not self.header.esoArabicSkillsShown and ZO_PostHookHandler then
            self.header.esoArabicSkillsShown = true
            ZO_PostHookHandler(self.header, "OnEffectivelyShown", function(c)
                if active() then skillsHeader(c) end
            end)
        end
    end
    after(ZO_GamepadSkills, "RefreshHeader", refreshSkills, "skillsFinal")
    after(ZO_GamepadSkills, "RefreshPointsDisplay", refreshSkills, "skillsPoints")
    -- Scene activation runs after the generic header's native reflow.
    -- Defer once so measurements and hidden-parent transitions have settled.
    if not R.skillsSceneLayout and SCENE_MANAGER and zo_callLater then
        R.skillsSceneLayout = true
        local function queueSkills()
            zo_callLater(function()
                if active() and GAMEPAD_SKILLS and GAMEPAD_SKILLS.header then
                    skillsHeader(GAMEPAD_SKILLS.header)
                end
            end, 0)
        end
        for _, sceneName in ipairs({"gamepad_skills_root", "gamepad_skills_line_filter"}) do
            local scene = SCENE_MANAGER:GetScene(sceneName)
            if scene then
                scene:RegisterCallback("StateChange", function(_, state)
                    if state == SCENE_SHOWN then queueSkills() end
                end)
            end
        end
        queueSkills()
    end
    -- Full-screen controller chat has its own channel selector, separate
    -- from GAMEPAD_CHAT_SYSTEM.textEntry. Its parent has fixed screen anchors.
    local function alignChatMenu(self)
        if not R.IsActive() then return end
        local parent, channel, text = self.textInputControl, self.channelControl, self.textControl
        if not parent or not channel or not text then return end
        channel:ClearAnchors()
        channel:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
        text:ClearAnchors()
        text:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
        text:SetAnchor(BOTTOMRIGHT, channel, BOTTOMLEFT, -15, 0)
        if self.selectedChannelLabel then
            self.selectedChannelLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        end
    end
    after(ZO_ChatMenu_Gamepad, "OnChatChannelChanged", alignChatMenu)
    -- Refreshing channels and opening the screen can reset native geometry.
    after(ZO_ChatMenu_Gamepad, "OnShow", alignChatMenu, "chatEntry")
    after(ZO_ChatMenu_Gamepad, "RefreshChannelDropdown", alignChatMenu, "chatEntry")
    after(ZO_ChatMenu_Gamepad, "OnScreenResized", alignChatMenu, "chatEntry")
    if CHAT_MENU_GAMEPAD then alignChatMenu(CHAT_MENU_GAMEPAD) end

    -- The shared dropdown singleton follows the channel control automatically.
    -- Reapply its owner before it computes popup anchors; other menus keep theirs.
    if ZO_ComboBox_Gamepad and not ZO_ComboBox_Gamepad.esoArabicChatActivate then
        ZO_ComboBox_Gamepad.esoArabicChatActivate = true
        local original = ZO_ComboBox_Gamepad.Activate
        ZO_ComboBox_Gamepad.Activate = function(self, ...)
            local menu = CHAT_MENU_GAMEPAD
            if active() and menu and self == menu.channelDropdown then alignChatMenu(menu) end
            return original(self, ...)
        end
    end

    after(ZO_ChatMenu_Gamepad, "SetupLogMessage", function(_, c, data)
        local label = c and c.label
        if not label then return end
        R.ReleaseLabelBinding(label)
        local width = label:GetWidth()
        if width <= 0 then return end
        local text = data and data.text or label:GetText()
        local font = "EsoAR/fonts/ArabicUI.slug|28|soft-shadow-thin"
        label:SetFont(font)
        label:SetMaxLineCount(0)
        R.ProcessControl(label, {managed = true, text = text, width = width,
            flow = true, reflowVisual = true, size = 28, minimum = 28, force = true,
            align = R.HasArabic(text) and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT})
        -- Non-Arabic pooled entries may restore their old native 42px font.
        -- Keep both languages at the same size before the list measures height.
        label:SetFont(font)
        label:SetHorizontalAlignment(R.HasArabic(text) and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT)
    end, "chatTypography")

    -- Only quest reward title controls: reserve independent header and gold columns.
    after(ZO_ParametricScrollList, "RunSetupOnControl", function(_, c)
        local name = c and c.GetName and c:GetName() or ""
        if not name:find("ZO_QuestReward_Title_Gamepad", 1, true) then return end
        local gold, header = child(c, "Gold"), c.headerControl
        if not gold or not header then return end
        local width = c:GetWidth()
        if width <= 0 then return end
        local goldWidth = math.max(120, math.ceil(gold:GetTextWidth()) + 12)
        gold:ClearAnchors()
        gold:SetAnchor(TOPLEFT, c, TOPLEFT, 0, 0)
        gold:SetWidth(goldWidth)
        gold:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        header:ClearAnchors()
        header:SetAnchor(TOPRIGHT, c, TOPRIGHT, -12, 6)
        fit(header, math.max(120, width - goldWidth - 28), 26, 36)
    end, "questRewards")

    after(ZO_ParametricScrollList, "RunSetupOnControl", function(_, c)
        local name = c and c.GetName and c:GetName() or ""
        if name:find("ZO_QuestReward_Gamepad", 1, true) then rewardItem(c) end
        if name:find("ZO_GamepadAlchemyInventorySolventRow", 1, true) then
            local label, description = child(c, "Label"), child(c, "DescriptionLabel")
            if label and description then
                local width = label:GetWidth()
                if width > 40 then
                    description:ClearAnchors()
                    description:SetAnchor(TOPRIGHT, label, BOTTOMRIGHT, 0, 0)
                    description:SetWidth(width)
                    local refresh = R.BindLabel(description, {flow = true, reflowVisual = true,
                        width = width, size = 24, minimum = 20, align = TEXT_ALIGN_RIGHT})
                    if refresh then refresh() end
                end
            end
        end
    end, "craftingAndRewardItems")
    after(ZO_GamepadSmithingResearch, "SetupTraitDisplay", researchSlot)
    after(ZO_GamepadSmithingResearch, "PerformDeferredInitialization", researchHeader)
    after(ZO_GamepadSmithingResearch, "Refresh", researchHeader)

    after(ZO_GamepadOptions, "InitializeControl", function(_, c)
        local label = child(c, "Name")
        if label then fit(label, label:GetWidth(), 26, 34) end
        for _, name in ipairs({"On", "Off"}) do
            local value = child(c, name)
            if value then fit(value, math.max(80, value:GetWidth()), 24, 30) end
        end
    end)
    if GetAchievementCategoryInfo and not R.gamepadAchievementNames then
        R.gamepadAchievementNames = true
        local original = GetAchievementCategoryInfo
        GetAchievementCategoryInfo = function(...)
            local name, subcategories, count, earned, total, hidden = original(...)
            if active() and type(name) == "string" and name:upper() == "DLC DUNGEONS" then
                name = R.ShapeLogical("زنزانات الإضافات")
            end
            return name, subcategories, count, earned, total, hidden
        end
    end
    if CHAT_ROUTER and not R.gamepadMonsterChatInstalled then
        local formatters = CHAT_ROUTER:GetRegisteredMessageFormatters()
        local original = formatters[EVENT_CHAT_MESSAGE_CHANNEL]
        if original then
            R.gamepadMonsterChatInstalled = true
            CHAT_ROUTER:RegisterMessageFormatter(EVENT_CHAT_MESSAGE_CHANNEL, function(kind, speaker, message, ...)
                local formatted, target, display, raw, narration, color = original(kind, speaker, message, ...)
                local monster = kind == CHAT_CHANNEL_MONSTER_SAY or kind == CHAT_CHANNEL_MONSTER_YELL
                    or kind == CHAT_CHANNEL_MONSTER_WHISPER or kind == CHAT_CHANNEL_MONSTER_EMOTE
                if active() and monster and (R.HasArabic(speaker) or R.HasArabic(message)) then
                    formatted = R.Prepare(message) .. " :" .. R.Prepare(speaker)
                end
                return formatted, target, display, raw, narration, color
            end)
        end
    end
    after(ZO_EmoteGridEntry, "SetName", function(self)
        local width = self.control:GetWidth() - 32
        box(self.title, self.control, 16, 0, width, 28)
        self.title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        self.title:SetHeight(self.control:GetHeight())
    end)
    after(ZO_UnitFrameObject, "UpdateName", function(self)
        if self.unitTag ~= "companion" then return end
        box(self.nameLabel, self.frame, 0, 1, ZO_GAMEPAD_COMPANION_FRAME_WIDTH or 306, 24)
    end)
    after(ZO_UnitFrameObject, "SetTextIndented", function(self)
        if self.unitTag ~= "companion" then return end
        box(self.nameLabel, self.frame, 0, 1, ZO_GAMEPAD_COMPANION_FRAME_WIDTH or 306, 24)
    end)
    for _, method in ipairs({"SetupBaseRow", "SetupScryableAntiquityRow", "SetupScryableAntiquityNearExpirationRow"}) do
        after(ZO_AntiquityJournalListGamepad, method, antiquity)
    end
    after(ZO_GamepadSocialListPanel, "SetupRow", function(_, c)
        -- One size for every text column and language; native ellipsis handles
        -- long names without making individual cells smaller than their peers.
        for _, name in ipairs({"DisplayName", "CharacterName", "Zone", "Level"}) do
            local label = child(c, name)
            if label then
                R.ReleaseLabelBinding(label)
                local text = label:GetText() or ""
                local align = (name == "Level" or R.HasArabic(text)) and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT
                local font = "EsoAR/fonts/ArabicUI.slug|26|soft-shadow-thin"
                label:SetFont(font)
                label:SetMaxLineCount(1)
                R.ProcessControl(label, {managed = true, text = text,
                    width = math.max(20, label:GetWidth()), single = true,
                    reflowVisual = true, size = 26, minimum = 26, force = true, align = align})
                label:SetFont(font)
                label:SetHorizontalAlignment(align)
            end
        end
        local level, icon = child(c, "Level"), child(c, "Champion")
        if level and icon then
            icon:ClearAnchors()
            icon:SetAnchor(RIGHT, level, LEFT, -4, 0)
            icon:SetDimensions(26, 26)
        end
    end)
    after(ZO_ParametricScrollList, "RunSetupOnControl", function(list, c, index)
        local data = list:GetDataForDataIndex(index)
        local edit = c.editBoxControl
        if not edit then return end
        if (data and data.nameField) or (edit.GetDefaultText and edit:GetDefaultText() == ZO_GetInviteInstructions()) then
            edit.esoArabicInviteOriginalFont = edit.esoArabicInviteOriginalFont or edit:GetFont()
            -- Leave typed player identifiers and native anchors untouched.
            -- The 34px native placeholder exceeded the narrow invitation field.
            local width = edit:GetWidth()
            local size = math.max(16, math.min(24, math.floor(width / 18)))
            edit:SetFont("EsoAR/fonts/ArabicUI.slug|" .. size .. "|soft-shadow-thin")
        elseif edit.esoArabicInviteOriginalFont then
            edit:SetFont(edit.esoArabicInviteOriginalFont)
        end
    end, "inviteNameField")
    after(ZO_ParametricScrollList, "RunSetupOnControl", function(_, c)
        local balance, amount, icon = child(c, "Balance"), child(c, "RemainingCrowns"), child(c, "CurrencyIcon")
        local label = child(c, "Label")
        if not (balance and amount and icon and label) then return end
        -- Match the submenu title's reserved arrow column, rather than letting
        -- the store title use the full width and cover its arrow.
        local titleWidth = ZO_GAMEPAD_DEFAULT_LIST_ENTRY_WITH_ARROW_WIDTH_AFTER_INDENT
        if titleWidth then label:SetWidth(titleWidth); fit(label, titleWidth, 28) end
        local arrow = child(c, "Arrow")
        if arrow then
            arrow:ClearAnchors()
            arrow:SetAnchor(RIGHT, c, RIGHT, 0, 0)
            arrow:SetAnchor(LEFT, label, LEFT, 0, 0, ANCHOR_CONSTRAINS_Y)
        end
        balance:ClearAnchors()
        balance:SetAnchor(TOPRIGHT, label, BOTTOMRIGHT, 0, 2)
        fit(balance, 100, 26)
        -- A fixed 100px caption left an empty gap before the numeric amount.
        local balanceWidth = math.ceil(balance:GetTextWidth()) + 2
        balance:SetWidth(balanceWidth)
        fit(balance, balanceWidth, 26)
        amount:ClearAnchors()
        amount:SetAnchor(RIGHT, balance, LEFT, -8, 0)
        amount:SetFont("EsoAR/fonts/ArabicUI.slug|28|soft-shadow-thin")
        amount:SetWidth(math.ceil(amount:GetTextWidth()) + 2)
        icon:ClearAnchors()
        icon:SetAnchor(RIGHT, amount, LEFT, -5, 0)
        icon:SetDimensions(28, 28)
    end, "crownStore")
end
