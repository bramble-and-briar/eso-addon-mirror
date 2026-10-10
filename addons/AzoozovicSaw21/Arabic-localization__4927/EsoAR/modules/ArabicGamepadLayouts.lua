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
function R.InstallGamepadLayouts()
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
    if CHAT_MENU_GAMEPAD then alignChatMenu(CHAT_MENU_GAMEPAD) end

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
        local level, icon = child(c, "Level"), child(c, "Champion")
        if level and icon then
            -- Fit four digits without a champion icon covering the first one.
            level:SetFont("EsoAR/fonts/ArabicUI.slug|24|soft-shadow-thin")
            level:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            icon:ClearAnchors()
            icon:SetAnchor(RIGHT, level, LEFT, -4, 0)
            icon:SetDimensions(26, 26)
        end
        local zone = child(c, "Zone")
        if zone then fit(zone, zone:GetWidth(), 24) end
    end)
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
