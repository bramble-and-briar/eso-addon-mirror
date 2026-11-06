local A = OneChat
local COPY_LINK, PLAYER_LINK, GUILD_LINK = "onechatcopy", "onechatplayer", "onechatguild"
A.messageRecords = {}
A.messageSequence = 0
A.messageWindows = setmetatable({}, { __mode = "k" })

local function findMarkup(text, pattern, offset)
    local first, last = text:find(pattern, offset)
    while first do
        local cursor = first - 1
        while cursor > 0 and text:sub(cursor, cursor) == "|" do cursor = cursor - 1 end
        if (first - cursor - 1) % 2 == 0 then return first, last end
        first, last = text:find(pattern, first + 1)
    end
end

function A:PruneChatHistory(state, now)
    local history = state.history
    if not history then
        history = { entries = {}, first = 1, last = 0 }
        state.history = history
    end
    local cutoff = now - 24 * 60 * 60
    while history.first <= history.last do
        local entry = history.entries[history.first]
        if entry and entry.time > cutoff then break end
        history.entries[history.first] = nil
        history.first = history.first + 1
    end
    if history.first > history.last then
        history.first, history.last = 1, 0
    end
    return history
end

function A:RecordChatMessage(container, window, message, r, g, b, category)
    if self.restoringHistory then return end
    local state = self:GetTabState(container, window)
    local now = GetTimeStamp()
    local history = self:PruneChatHistory(state, now)
    history.last = history.last + 1
    -- Store original native links, never session-specific copy/player IDs.
    history.entries[history.last] = { time = now, text = message, r = r, g = g, b = b, category = category }
    window.buffer:SetMaxHistoryLines(math.max(window.buffer:GetMaxHistoryLines(), history.last - history.first + 1))
end

function A:RestoreChatHistory()
    if self.historyRestored then return end
    self.historyRestored = true
    self.restoringHistory = true
    local now = GetTimeStamp()
    for _, container in ipairs(self.chat.containers) do
        for _, window in ipairs(container.windows) do
            if not window.combatLog and window.buffer then
                local history = self:PruneChatHistory(self:GetTabState(container, window), now)
                window.buffer:SetMaxHistoryLines(math.max(window.buffer:GetMaxHistoryLines(), history.last - history.first + 1))
                for index = history.first, history.last do
                    local entry = history.entries[index]
                    container:AddMessageToWindow(window, entry.text, entry.r, entry.g, entry.b, entry.category)
                end
            end
        end
    end
    self.restoringHistory = false
end

function A:FormatMessage(base, messageType, fromName, text, customerService, displayName, ...)
    local formatted, target, fromDisplay, raw, narration, override = base(
        messageType, fromName, text, customerService, displayName, ...)
    local info = self.chat.channelData[messageType]
    if not formatted or not info or not info.playerLinkable then
        return formatted, target, fromDisplay, raw, narration, override
    end
    local name = displayName and displayName ~= "" and displayName or fromName
    local playerLink
    if IsDecoratedDisplayName(name) then
        playerLink = ZO_LinkHandler_CreateLinkWithoutBrackets(name, nil, DISPLAY_NAME_LINK_TYPE,
            UndecorateDisplayName(name))
    else
        name = zo_strformat(SI_UNIT_NAME, name)
        playerLink = ZO_LinkHandler_CreateLinkWithoutBrackets(name, nil, CHARACTER_LINK_TYPE, fromName)
    end
    local seconds = GetSecondsSinceMidnight()
    local time = string.format("%02d:%02d", math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60)
    local prefix, guildLink = "", ""
    if self.sv.timestamps then
        prefix = "[" .. time .. "] "
    end
    local t = self.byChannel[messageType]
    if t and t.guildId then
        local label = not self.sv.customMessage and self.sv.abbreviations[tostring(t.guildId)]
        if not label or label == "" then label = GetGuildName(t.guildId) end
        -- User-supplied abbreviations are plain labels, never link markup.
        label = label:gsub("|", ""):gsub("[\r\n]", " ")
        local createGuildLink = self.sv.customMessage and ZO_LinkHandler_CreateLinkWithoutBrackets or ZO_LinkHandler_CreateLink
        guildLink = createGuildLink(label, nil, GUILD_LINK, t.guildId)
        prefix = prefix .. guildLink .. " "
    end
    if customerService then prefix = prefix .. "|t16:16:EsoUI/Art/ChatWindow/csIcon.dds|t" end
    local message = info.formatMessage and zo_strformat(SI_CHAT_MESSAGE_FORMATTER, text) or text
    formatted = prefix .. playerLink .. " >" .. (self.sv.newline and "\n" or " ") .. message
    if self.sv.customMessage then
        local values = {
            name = playerLink, time = time, guild = guildLink, message = message,
            character = ZO_LinkHandler_CreateLinkWithoutBrackets(zo_strformat(SI_UNIT_NAME, fromName), nil, CHARACTER_LINK_TYPE, fromName),
            account = displayName and displayName ~= "" and ZO_LinkHandler_CreateLinkWithoutBrackets(displayName, nil,
                DISPLAY_NAME_LINK_TYPE, UndecorateDisplayName(displayName)) or "",
            channel = GetChannelName(messageType),
        }
        local template = self.sv.messageTemplate or self.defaultMessageTemplate
        -- Escape literal game markup before substitution; inserted native links stay intact.
        formatted = template:gsub("|", "||"):gsub("{([%a_]+)}", function(key) return values[key] end)
        if customerService then formatted = "|t16:16:EsoUI/Art/ChatWindow/csIcon.dds|t" .. formatted end
    end
    -- Preserve native targets, narration, category colors, and raw text.
    return formatted, target, fromDisplay, raw, narration, override
end

function A:ReleaseMessages(window)
    local history = self.messageWindows[window]
    if history then
        for _, id in pairs(history.ids) do self.messageRecords[id] = nil end
        self.messageWindows[window] = nil
    end
end

function A:WrapMessage(window, text)
    local history = self.messageWindows[window]
    if not history then
        history = { ids = {}, cursor = 0 }
        self.messageWindows[window] = history
    end
    local capacity = math.max(1, window.buffer:GetMaxHistoryLines())
    history.cursor = history.cursor % capacity + 1
    local previous = history.ids[history.cursor]
    if previous then self.messageRecords[previous] = nil end
    self.messageSequence = self.messageSequence + 1
    local id = self.messageSequence
    history.ids[history.cursor] = id
    self.messageRecords[id] = { text = self:PlainText(text) }

    local result, offset = {}, 1
    local function appendCopy(value)
        -- TextBuffer parses links per line. Keep line breaks outside their
        -- labels so a copy link cannot hide or break the next native link.
        local cursor = 1
        while cursor <= #value do
            local first, last = value:find("[\r\n]+", cursor)
            local finish = first and first - 1 or #value
            if finish >= cursor then
                result[#result + 1] = ZO_LinkHandler_CreateLinkWithoutBrackets(value:sub(cursor, finish), nil, COPY_LINK, id)
            end
            if not first then break end
            result[#result + 1] = value:sub(first, last)
            cursor = last + 1
        end
    end
    local function appendPlain(value)
        if value ~= "" then
            -- Color tags stay outside copy links; textures keep their markup
            -- inside the copy label. Never nest existing native links.
            local cursor = 1
            while cursor <= #value do
                local first, last = findMarkup(value, "|[crt]", cursor)
                if not first then
                    appendCopy(value:sub(cursor))
                    break
                end
                if first > cursor then
                    appendCopy(value:sub(cursor, first - 1))
                end
                local tag = value:sub(first, last)
                if tag == "|c" and value:sub(first + 2, first + 7):match("^%x%x%x%x%x%x$") then
                    last = first + 7
                elseif tag == "|t" then
                    local _, textureEnd = value:find("|t", last + 1, true)
                    last = textureEnd or last
                end
                local markup = value:sub(first, last)
                if tag == "|t" then appendCopy(markup)
                else result[#result + 1] = markup end
                cursor = last + 1
            end
        end
    end
    while true do
        local first, last = findMarkup(text, "|H[^|]*|h.-|h", offset)
        if not first then appendPlain(text:sub(offset)); break end
        appendPlain(text:sub(offset, first - 1))
        local link = text:sub(first, last)
        local label, _, linkType, data = ZO_LinkHandler_ParseLink(link)
        if linkType == CHARACTER_LINK_TYPE or linkType == DISPLAY_NAME_LINK_TYPE then
            link = ZO_LinkHandler_CreateLinkWithoutBrackets(label, nil, PLAYER_LINK, id, linkType, data)
        elseif linkType == GUILD_LINK then
            link = ZO_LinkHandler_CreateLinkWithoutBrackets(label, nil, GUILD_LINK, data, id)
        else
            local record = self.messageRecords[id]
            record.links = record.links or {}
            record.links[link] = true
        end
        result[#result + 1] = link
        offset = last + 1
    end
    return table.concat(result)
end

function A:CopyMessage(id)
    local record = self.messageRecords[tonumber(id)]
    if record then self:ShowCopy(record.text) else self:Notify(SI_ONECHAT_COPY_EXPIRED) end
end

function A:CopyMenu(id)
    ClearMenu()
    AddMenuItem(GetString(SI_ONECHAT_COPY), function() A:CopyMessage(id) end)
    ShowMenu()
end

function A:CopyEmbeddedLink(window, link)
    local history = self.messageWindows[window]
    if not history then return end
    local ids = {}
    for _, id in pairs(history.ids) do
        local record = self.messageRecords[id]
        if record and record.links and record.links[link] then ids[#ids + 1] = id end
    end
    table.sort(ids)
    if #ids == 0 then return end
    AddMenuItem(GetString(SI_ONECHAT_COPY), function()
        if #ids == 1 then A:CopyMessage(ids[1]); return end
        local lines = { zo_strformat(SI_ONECHAT_COPY_MULTIPLE, #ids) }
        for _, id in ipairs(ids) do
            local record = A.messageRecords[id]
            if record then lines[#lines + 1] = record.text end
        end
        A:ShowCopy(table.concat(lines, "\n\n"))
    end)
    ShowMenu()
end

function A:TravelToPlayer(playerName)
    if not CanLeaveCurrentLocationViaTeleport() or IsUnitDead("player") then
        self:Notify(SI_ONECHAT_TRAVEL_UNAVAILABLE)
        return
    end
    for index = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(index)
        if GetUnitDisplayName(unitTag) == playerName or GetUnitName(unitTag) == playerName then
            if CanJumpToGroupMember(unitTag) then JumpToGroupMember(GetUnitName(unitTag))
            else self:Notify(SI_ONECHAT_TRAVEL_UNAVAILABLE) end
            return
        end
    end
    if IsFriend(playerName) then JumpToFriend(playerName); return end
    for index = 1, GetNumGuilds() do
        if GetGuildMemberIndexFromDisplayName(GetGuildId(index), playerName) then
            JumpToGuildMember(playerName)
            return
        end
    end
    self:Notify(SI_ONECHAT_TRAVEL_UNAVAILABLE)
end

function A:PlayerMenu(playerName, rawName, id)
    ClearMenu()
    AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_WHISPER), function()
        self.chat:StartTextEntry(nil, CHAT_CHANNEL_WHISPER, playerName)
    end)
    -- Keep the native group, friend and ignore availability checks.
    if IsGroupModificationAvailable() then
        local grouped = IsUnitGrouped("player")
        local leader = IsUnitGroupLeader("player")
        local inGroup = IsPlayerInGroup(rawName)
        if not grouped or (leader and not inGroup) then
            AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_ADD_GROUP), function()
                TryGroupInviteByName(playerName, false, true)
            end)
        elseif inGroup and leader then
            AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_REMOVE_GROUP), function() GroupKickByName(rawName) end)
        end
    end
    if not IsFriend(playerName) then
        AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_ADD_FRIEND), function()
            ZO_Dialogs_ShowDialog("REQUEST_FRIEND", { name = playerName })
        end)
    end
    AddMenuItem(GetString(SI_SOCIAL_MENU_SEND_MAIL), function()
        if IsUnitDead("player") then A:Notify(SI_ONECHAT_ACTION_UNAVAILABLE)
        else MAIL_SEND:ComposeMailTo(playerName) end
    end)
    AddMenuItem(GetString(SI_SOCIAL_MENU_JUMP_TO_PLAYER), function() A:TravelToPlayer(playerName) end)
    AddMenuItem(GetString(SI_SOCIAL_MENU_VISIT_HOUSE), function()
        if CanJumpToHouseFromCurrentLocation() and not IsUnitDead("player") then JumpToHouse(playerName)
        else A:Notify(SI_ONECHAT_TRAVEL_UNAVAILABLE) end
    end)
    if not IsIgnored(playerName) then
        AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_ADD_IGNORE), function() ZO_PlatformIgnorePlayer(playerName) end)
    end
    AddMenuItem(zo_strformat(SI_CHAT_PLAYER_CONTEXT_REPORT, rawName), function()
        ZO_HELP_GENERIC_TICKET_SUBMISSION_MANAGER:OpenReportPlayerTicketScene(playerName)
    end)
    AddMenuItem(GetString(SI_ONECHAT_COPY), function() A:CopyMessage(id) end)
    ShowMenu()
end

function A:OnMessageLink(link, button, _, _, linkType, ...)
    if linkType == COPY_LINK then
        if button == MOUSE_BUTTON_INDEX_RIGHT then self:CopyMenu(...) end
        return true
    elseif linkType == PLAYER_LINK then
        local id, nativeType, rawName = ...
        local name = nativeType == DISPLAY_NAME_LINK_TYPE and DecorateDisplayName(rawName)
            or zo_strformat(SI_UNIT_NAME, rawName)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            IgnoreMouseDownEditFocusLoss()
            self.chat:StartTextEntry(nil, CHAT_CHANNEL_WHISPER, name)
        elseif button == MOUSE_BUTTON_INDEX_RIGHT then self:PlayerMenu(name, rawName, id) end
        return true
    elseif linkType == GUILD_LINK then
        local guildId, id = ...
        if button == MOUSE_BUTTON_INDEX_RIGHT then self:CopyMenu(id)
        elseif button == MOUSE_BUTTON_INDEX_LEFT then
            local t = self.byKey["guild:" .. guildId]
            if t then self:ChooseChannel(t) end
        end
        return true
    end
end

function A:InstallMessages()
    local formatters = CHAT_ROUTER:GetRegisteredMessageFormatters()
    local base = formatters[EVENT_CHAT_MESSAGE_CHANNEL]
    CHAT_ROUTER:RegisterMessageFormatter(EVENT_CHAT_MESSAGE_CHANNEL, function(...)
        return A:FormatMessage(base, ...)
    end)
    local statusFormatter = formatters[EVENT_FRIEND_PLAYER_STATUS_CHANGED]
    if statusFormatter then
        CHAT_ROUTER:RegisterMessageFormatter(EVENT_FRIEND_PLAYER_STATUS_CHANGED, function(...)
            if not A.sv.hidePlayerStatus then return statusFormatter(...) end
        end)
    end
    local original = SharedChatContainer.AddMessageToWindow
    SharedChatContainer.AddMessageToWindow = function(container, window, message, ...)
        if container.system == A.chat and not window.combatLog and window.buffer then
            A:RecordChatMessage(container, window, message, ...)
            if not window.oneChatLinkHook then
                window.oneChatLinkHook = true
                ZO_PostHookHandler(window.buffer, "OnLinkMouseUp", function(_, _, link, button)
                    local _, _, linkType = ZO_LinkHandler_ParseLink(link)
                    if button == MOUSE_BUTTON_INDEX_RIGHT and linkType ~= COPY_LINK
                        and linkType ~= PLAYER_LINK and linkType ~= GUILD_LINK then
                        A:CopyEmbeddedLink(window, link)
                    end
                end)
            end
            message = A:WrapMessage(window, message)
        end
        return original(container, window, message, ...)
    end
    -- Native channel links from preexisting history still obey tab permissions.
    ZO_PreHook(self.chat, "OnLinkClicked", function(_, _, button, _, _, linkType, name)
        if linkType == CHANNEL_LINK_TYPE and button == MOUSE_BUTTON_INDEX_LEFT then
            local t = A.byChannel[GetChatChannelId(name)]
            if t then A:ChooseChannel(t) end
            return true
        end
    end)
    local callback = function(...) return A:OnMessageLink(...) end
    LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, callback)
    LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_CLICKED_EVENT, callback)
end
