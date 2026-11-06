local A = OneChat
local WM = WINDOW_MANAGER
local controlSequence = 0

local function label(parent, text, x, y, width, font)
    local control = WM:CreateControl(nil, parent, CT_LABEL)
    control:SetFont(font or "ZoFontWinH4")
    control:SetText(text)
    control:SetDimensions(width or 440, 28)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    return control
end

local function tooltip(control, text)
    control:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0, BOTTOMRIGHT)
        SetTooltipText(InformationTooltip, text)
    end)
    control:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
end

local function check(parent, text, x, y, callback, description, triState)
    controlSequence = controlSequence + 1
    local control = CreateControlFromVirtual("OneChatCheck" .. controlSequence, parent,
        triState and "ZO_TriStateCheckButton" or "ZO_CheckButton")
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    ZO_CheckButton_SetLabelText(control, text)
    ZO_CheckButton_SetLabelWidth(control, 390 - x)
    if triState then
        ZO_TriStateCheckButton_SetStateChangeFunction(control, function(button, state)
            callback(button, state == TRISTATE_CHECK_BUTTON_CHECKED)
        end)
        -- ZO_CheckButtonLabel normally dispatches the two-state handler.
        control.label:SetHandler("OnMouseUp", function(_, button, upInside)
            if upInside then ZO_TriStateCheckButton_OnClicked(control, button) end
        end)
    else
        ZO_CheckButton_SetToggleFunction(control, callback)
    end
    if description then ZO_CheckButton_SetTooltipText(control, description) end
    return control
end

function A:CreateChannelPane(direction, heading)
    local control = WM:CreateControl("OneChat" .. direction, ZO_ChatOptionsDialog, CT_CONTROL)
    control:SetDimensions(480, 1)
    control:SetAnchor(TOPLEFT, heading, BOTTOMLEFT, 10, 10)
    return { control = control, child = control, rows = {}, direction = direction }
end

function A:RefreshPane(pane)
    local container = CHAT_OPTIONS:GetCurrentContainer()
    local index = CHAT_OPTIONS:GetCurrentTabIndex()
    local window = container and container.windows[index]
    if not window or window.combatLog then return end
    local state = self:GetTabState(container, window)
    for _, row in ipairs(pane.rows) do row:SetHidden(true) end
    local rowIndex = 0
    local blocks, currentBlock = {}, nil
    local function beginBlock(isGuild)
        currentBlock = { isGuild = isGuild }
        blocks[#blocks + 1] = currentBlock
    end
    local function row(text, tokens, depth, font)
        rowIndex = rowIndex + 1
        local item = pane.rows[rowIndex]
        if not item then
            item = WM:CreateControl(nil, pane.child, CT_CONTROL)
            item:SetDimensions(240, 27)
            item.check = check(item, "", 0, 2, function(button, checked)
                A:SetTokens(container, window, pane.direction, button.oneChatTokens, checked)
                A:RefreshPane(pane)
            end, GetString(SI_ONECHAT_CHECK_HINT), true)
            pane.rows[rowIndex] = item
        end
        -- Controls are reused when configuring another tab.
        ZO_TriStateCheckButton_SetStateChangeFunction(item.check, function(button, selected)
            A:SetTokens(container, window, pane.direction, button.oneChatTokens,
                selected == TRISTATE_CHECK_BUTTON_CHECKED)
            A:RefreshPane(pane)
        end)
        item:SetHidden(false)
        item.oneChatDepth = depth
        currentBlock[#currentBlock + 1] = item
        item:ClearAnchors()
        item.check.oneChatTokens = tokens
        ZO_CheckButton_SetLabelText(item.check, text)
        item.check.label:SetFont(font or "ZoFontGameBold")
        ZO_CheckButton_SetLabelWidth(item.check, 300 - depth * 16)
        item.check.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local checked, mixed = A:SelectionState(state[pane.direction], tokens)
        ZO_TriStateCheckButton_SetState(item.check, mixed and TRISTATE_CHECK_BUTTON_INDETERMINATE
            or (checked and TRISTATE_CHECK_BUTTON_CHECKED or TRISTATE_CHECK_BUTTON_UNCHECKED))
    end
    local function visibleTokens(entry)
        local tokens = {}
        for _, t in ipairs(entry.tokens) do
            if pane.direction == "incoming" or not t.incomingOnly then tokens[#tokens + 1] = t end
        end
        return tokens
    end
    local orderedGroups, guildGroup = {}, nil
    for _, group in ipairs(self.groups) do
        if group.key == "guilds" then guildGroup = group
        else orderedGroups[#orderedGroups + 1] = group end
    end
    if guildGroup then orderedGroups[#orderedGroups + 1] = guildGroup end
    for _, group in ipairs(orderedGroups) do
        if group.key == "guilds" then
            for _, guild in ipairs(group.children) do
                beginBlock(true)
                -- The name selects guild chat only; officer chat stays independent.
                row(guild.name, visibleTokens(guild.children[1]), 0, "ZoFontWinH4")
                row(guild.children[2].name, visibleTokens(guild.children[2]), 1)
            end
        else
            for _, entry in ipairs(group.children) do
                local tokens = visibleTokens(entry)
                if #tokens > 0 then
                    beginBlock()
                    row(entry.name, tokens, 0)
                end
            end
        end
    end
    local columns = GetNumGuilds() > 3 and 3 or 2
    -- General channels always occupy the left column; guild/officer pairs
    -- share the remaining columns without splitting a pair.
    local columnWidth, heights = 240, { 0, 0, 0 }
    for _, block in ipairs(blocks) do
        local column = 1
        if block.isGuild then
            column = 2
            if columns == 3 and heights[3] < heights[2] then column = 3 end
        end
        for _, item in ipairs(block) do
            local depth = item.oneChatDepth
            item:SetDimensions(columnWidth, 27)
            item:SetAnchor(TOPLEFT, pane.child, TOPLEFT,
                (column - 1) * columnWidth + depth * 16, heights[column])
            ZO_CheckButton_SetLabelWidth(item.check, columnWidth - 30 - depth * 16)
            heights[column] = heights[column] + 27
        end
    end
    pane.columnCount = columns
    pane.control:SetDimensions(columnWidth * columns, math.max(1, unpack(heights)))
end

function A:RefreshOptions()
    if self.incomingPane and not ZO_ChatOptionsDialog:IsHidden() then
        self:RefreshPane(self.incomingPane)
        self:RefreshPane(self.outgoingPane)
    end
end

function A:InstallOptions()
    -- Keep the native dialog, tab-name edit, defaults/exit buttons and fonts.
    local dialog = ZO_ChatOptionsDialog
    dialog:GetNamedChild("FilterSection"):SetHidden(true)
    dialog:GetNamedChild("GuildSection"):SetHidden(true)
    dialog:GetNamedChild("FilterSection"):SetExcludeFromResizeToFitExtents(true)
    dialog:GetNamedChild("GuildSection"):SetExcludeFromResizeToFitExtents(true)
    local incoming = dialog:GetNamedChild("FilterLabel")
    local outgoing = dialog:GetNamedChild("GuildChannelLabel")
    incoming:SetText(GetString(SI_ONECHAT_INCOMING))
    incoming:SetWidth(330)
    outgoing:SetText(GetString(SI_ONECHAT_OUTGOING))
    self.incomingPane = self:CreateChannelPane("incoming", incoming)
    outgoing:ClearAnchors()
    outgoing:SetAnchor(TOPLEFT, self.incomingPane.control, BOTTOMLEFT, -10, 20)
    self.outgoingPane = self:CreateChannelPane("outgoing", outgoing)
    SecurePostHook(CHAT_OPTIONS, "Show", function() A:RefreshOptions() end)
    SecurePostHook(CHAT_OPTIONS, "Reset", function(options)
        local container, index = options:GetCurrentContainer(), options:GetCurrentTabIndex()
        local window = container.windows[index]
        A.windows[window] = nil
        A:GetTabState(container, window)
        if window == A.activeWindow then A:RestoreSelection() end
        A:SnapshotTabs()
        A:RefreshOptions()
    end)
    SecurePostHook(SharedChatContainer, "ShowContextMenu", function(container)
        if container.system == A.chat then
            AddMenuItem(GetString(SI_ONECHAT_SETTINGS), function() A:ShowSettings() end)
            ShowMenu(container.control)
        end
    end)
end

local function dialog(name, titleId, width, height)
    local control = CreateControlFromVirtual(name, GuiRoot, "ZO_CustomDialogBase")
    control:SetDimensions(width, height)
    control:SetHidden(true)
    local close = CreateControlFromVirtual(name .. "Close", control, "ZO_CustomDialogButton")
    ZO_Dialogs_RegisterCustomDialog(name, {
        customControl = control, title = { text = titleId },
        buttons = { { control = close, text = SI_DIALOG_CLOSE, keybind = "DIALOG_NEGATIVE" } },
    })
    return control
end

function A:ShowCopy(text)
    if not self.copyDialog then
        self.copyDialog = dialog("OneChatCopyDialog", SI_ONECHAT_COPY, 600, 350)
        label(self.copyDialog, GetString(SI_ONECHAT_COPY_HINT), 35, 65, 530)
        local bg = CreateControlFromVirtual("OneChatCopyBackdrop", self.copyDialog, "ZO_MultiLineEditBackdrop_Keyboard")
        bg:SetDimensions(520, 190)
        bg:SetAnchor(TOPLEFT, self.copyDialog, TOPLEFT, 40, 100)
        self.copyEdit = CreateControlFromVirtual("OneChatCopyEdit", bg, "ZO_DefaultEditMultiLineForBackdrop")
        self.copyEdit:SetMaxInputChars(65535)
    end
    ZO_Dialogs_ShowDialog("OneChatCopyDialog")
    self.copyEdit:SetText(text)
    self.copyEdit:TakeFocus()
    self.copyEdit:SelectAll()
end

function A:InstallSettings()
    local LAM = LibAddonMenu2
    self.settingsPanel = LAM:RegisterAddonPanel("OneChatSettings", {
        type = "panel", name = "OneChat", displayName = GetString(SI_ONECHAT_SETTINGS),
        author = "oneDOK", version = "26.11.2",
        registerForRefresh = true, registerForDefaults = true,
    })
    local options = {
        { type = "header", name = GetString(SI_ONECHAT_FORMATTING) },
        { type = "checkbox", name = GetString(SI_ONECHAT_TIMESTAMPS),
          disabled = function() return A.sv.customMessage end,
          tooltip = GetString(SI_ONECHAT_TIMESTAMPS_HINT), default = true,
          getFunc = function() return A.sv.timestamps end,
          setFunc = function(value) A.sv.timestamps = value end },
        { type = "checkbox", name = GetString(SI_ONECHAT_NEWLINE),
          disabled = function() return A.sv.customMessage end,
          tooltip = GetString(SI_ONECHAT_NEWLINE_HINT), default = false,
          getFunc = function() return A.sv.newline end,
          setFunc = function(value) A.sv.newline = value end },
        { type = "checkbox", name = GetString(SI_ONECHAT_HOME_BUTTON),
          tooltip = GetString(SI_ONECHAT_HOME_TOOLTIP), default = true,
          getFunc = function() return A.sv.toolbar.home end,
          setFunc = function(value) A.sv.toolbar.home = value; A:RefreshToolbar() end },
        { type = "header", name = GetString(SI_ONECHAT_ABBREVIATIONS) },
        { type = "description", text = GetString(SI_ONECHAT_ABBREVIATIONS_HINT) },
    }
    table.insert(options, 5, { type = "checkbox", name = GetString(SI_ONECHAT_LANGUAGE_BUTTON),
        tooltip = GetString(SI_ONECHAT_LANGUAGE_TOOLTIP), default = true,
        getFunc = function() return A.sv.toolbar.language end,
        setFunc = function(value) A.sv.toolbar.language = value; A:RefreshToolbar() end })
    table.insert(options, 5, { type = "checkbox", name = GetString(SI_ONECHAT_RELOAD_BUTTON),
        tooltip = GetString(SI_ONECHAT_RELOAD_TOOLTIP), default = true,
        getFunc = function() return A.sv.toolbar.reload end,
        setFunc = function(value) A.sv.toolbar.reload = value; A:RefreshToolbar() end })
    table.insert(options, 4, { type = "header", name = GetString(SI_ONECHAT_BUTTONS_SECTION) })
    for index = 1, MAX_GUILDS do
        local slot = index
        options[#options + 1] = {
            type = "editbox", width = "full", default = "",
            name = function()
                local id = GetGuildId(slot)
                return id and id ~= 0 and GetGuildName(id) or ""
            end,
            disabled = function() return A.sv.customMessage or slot > GetNumGuilds() end,
            getFunc = function()
                return A.sv.abbreviations[tostring(GetGuildId(slot))] or ""
            end,
            setFunc = function(value)
                if slot <= GetNumGuilds() then
                    A.sv.abbreviations[tostring(GetGuildId(slot))] = value:gsub("|", ""):gsub("[\r\n]", " ")
                end
            end,
        }
    end
    options[#options + 1] = { type = "header", name = GetString(SI_ONECHAT_NOTIFICATIONS_SECTION) }
    options[#options + 1] = {
        type = "checkbox", name = GetString(SI_ONECHAT_HIDE_PLAYER_STATUS),
        tooltip = GetString(SI_ONECHAT_HIDE_PLAYER_STATUS_HINT), default = false,
        getFunc = function() return A.sv.hidePlayerStatus end,
        setFunc = function(value) A.sv.hidePlayerStatus = value end,
    }
    table.insert(options, 2, {
        type = "checkbox", name = GetString(SI_ONECHAT_CUSTOM_MESSAGE), default = false,
        getFunc = function() return A.sv.customMessage end,
        setFunc = function(value) A.sv.customMessage = value end,
    })
    table.insert(options, 3, {
        type = "editbox", name = GetString(SI_ONECHAT_MESSAGE_TEMPLATE),
        tooltip = GetString(SI_ONECHAT_MESSAGE_TEMPLATE_HINT),
        isMultiline = true, isExtraWide = true, width = "full", maxChars = 4096,
        default = A.defaultMessageTemplate,
        disabled = function() return not A.sv.customMessage end,
        getFunc = function() return A.sv.messageTemplate end,
        setFunc = function(value) A.sv.messageTemplate = value end,
    })
    LAM:RegisterOptionControls("OneChatSettings", options)
end

function A:ShowSettings()
    LibAddonMenu2:OpenToPanel(self.settingsPanel)
end

function A:TravelHome()
    local houseId = GetHousingPrimaryHouse()
    if not houseId or houseId == 0 then self:Notify(SI_ONECHAT_NO_HOME); return end
    if not CanJumpToHouseFromCurrentLocation() or IsUnitDead("player") then
        self:Notify(SI_ONECHAT_TRAVEL_UNAVAILABLE)
        return
    end
    RequestJumpToHouse(houseId)
end

function A:RefreshToolbar()
    local previous
    for _, item in ipairs(self.toolbarButtons) do
        local shown = self.sv.toolbar[item.key] == true
        item.control:SetHidden(not shown)
        if shown then
            item.control:ClearAnchors()
            if previous then item.control:SetAnchor(RIGHT, previous, LEFT, -2, 0)
            else item.control:SetAnchor(TOPRIGHT, self.chat.primaryContainer.control, TOPRIGHT, -48, 10) end
            previous = item.control
        end
    end
end

function A:ShowLanguageMenu(owner)
    ClearMenu()
    local languages = {
        { "en", OFFICIAL_LANGUAGE_ENGLISH }, { "de", OFFICIAL_LANGUAGE_GERMAN },
        { "fr", OFFICIAL_LANGUAGE_FRENCH }, { "ru", OFFICIAL_LANGUAGE_RUSSIAN },
        { "es", OFFICIAL_LANGUAGE_SPANISH }, { "zh", OFFICIAL_LANGUAGE_CHINESE_S },
        { "jp", OFFICIAL_LANGUAGE_JAPANESE },
    }
    for _, entry in ipairs(languages) do
        local code = entry[1]
        AddMenuItem(GetString("SI_OFFICIALLANGUAGE", entry[2]), function()
            if GetCVar("language.2") ~= code then
                A:SnapshotTabs()
                SetCVar("language.2", code)
                ReloadUI("ingame")
            end
        end)
    end
    ShowMenu(owner)
end

function A:InstallToolbar()
    self.toolbarButtons = {}
    local definitions = {
        { key = "home", texture = "EsoUI/Art/WorldMap/map_indexIcon_housing",
          tooltip = SI_ONECHAT_HOME_TOOLTIP, action = function() A:TravelHome() end },
        { key = "reload", texture = "EsoUI/Art/LFG/LFG_groupFinder_refreshSearch",
          tooltip = SI_ONECHAT_RELOAD_TOOLTIP, action = function() A:SnapshotTabs(); ReloadUI("ingame") end },
        { key = "language", texture = "EsoUI/Art/MainMenu/menuBar_map",
          tooltip = SI_ONECHAT_LANGUAGE_TOOLTIP, action = function(button) A:ShowLanguageMenu(button) end },
    }
    for _, definition in ipairs(definitions) do
        local button = WM:CreateControl("OneChatToolbar" .. definition.key, self.chat.primaryContainer.control, CT_BUTTON)
        button:SetMouseEnabled(true)
        button:SetDimensions(24, 24)
        -- Use the same baked colors, glow and pressed states as native buttons.
        button:SetNormalTexture(definition.texture .. "_up.dds")
        button:SetMouseOverTexture(definition.texture .. "_over.dds")
        button:SetPressedTexture(definition.texture .. "_down.dds")
        button:SetHandler("OnClicked", definition.action)
        tooltip(button, GetString(definition.tooltip))
        self.toolbarButtons[#self.toolbarButtons + 1] = { key = definition.key, control = button }
    end
    self:RefreshToolbar()
end
