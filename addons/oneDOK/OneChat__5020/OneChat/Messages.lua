local A = OneChat
local COPY_LINK, PLAYER_LINK, GUILD_LINK = "onechatcopy", "onechatplayer", "onechatguild"
A.messageRecords = {}
A.messageSequence = 0
A.messageWindows = setmetatable({}, { __mode = "k" })

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
    local prefix = ""
    if self.sv.timestamps then
        local seconds = GetSecondsSinceMidnight()
        prefix = string.format("[%02d:%02d] ", math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60)
    end
    local t = self.byChannel[messageType]
    if t and t.guildId then
        local label = self.sv.abbreviations[tostring(t.guildId)]
        if not label or label == "" then label = GetGuildName(t.guildId) end
        -- User-supplied abbreviations are plain labels, never link markup.
        label = label:gsub("|", ""):gsub("[\r\n]", " ")
        prefix = prefix .. ZO_LinkHandler_CreateLink("" .. label, nil, GUILD_LINK, t.guildId) .. " "
    end
    if customerService then prefix = prefix .. "|t16:16:EsoUI/Art/ChatWindow/csIcon.dds|t" end
    local message = info.formatMessage and zo_strformat(SI_CHAT_MESSAGE_FORMATTER, text) or text
    formatted = prefix .. playerLink .. " >" .. (self.sv.newline and "\n" or " ") .. message
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
    local function appendPlain(value)
        if value ~= "" then
            -- Color tags stay outside copy links; textures keep their markup
            -- inside the copy label. Never nest existing native links.
            local cursor = 1
            while cursor <= #value do
                local first, last = value:find("|[crt]", cursor)
                if not first then
                    result[#result + 1] = ZO_LinkHandler_CreateLinkWithoutBrackets(value:sub(cursor), nil, COPY_LINK, id)
                    break
                end
                if first > cursor then
                    result[#result + 1] = ZO_LinkHandler_CreateLinkWithoutBrackets(value:sub(cursor, first - 1), nil, COPY_LINK, id)
                end
                local tag = value:sub(first, last)
                if tag == "|c" and value:sub(first + 2, first + 7):match("^%x%x%x%x%x%x$") then
                    last = first + 7
                elseif tag == "|t" then
                    local _, textureEnd = value:find("|t", last + 1, true)
                    last = textureEnd or last
                end
                local markup = value:sub(first, last)
                result[#result + 1] = tag == "|t"
                    and ZO_LinkHandler_CreateLinkWithoutBrackets(markup, nil, COPY_LINK, id) or markup
                cursor = last + 1
            end
        end
    end
    while true do
        local first, last = text:find("|H[^|]*|h.-|h", offset)
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
    -- Build the original menu first (report, group management, etc.), then
    -- append only actions it does not already supply.
    self.chat:ShowPlayerContextMenu(playerName, rawName)
    AddMenuItem(GetString(SI_ONECHAT_COPY), function() A:CopyMessage(id) end)
    AddMenuItem(GetString(SI_SOCIAL_MENU_SEND_MAIL), function()
        if IsUnitDead("player") then A:Notify(SI_ONECHAT_ACTION_UNAVAILABLE)
        else MAIL_SEND:ComposeMailTo(playerName) end
    end)
    AddMenuItem(GetString(SI_SOCIAL_MENU_JUMP_TO_PLAYER), function() A:TravelToPlayer(playerName) end)
    AddMenuItem(GetString(SI_SOCIAL_MENU_VISIT_HOUSE), function()
        if CanJumpToHouseFromCurrentLocation() and not IsUnitDead("player") then JumpToHouse(playerName)
        else A:Notify(SI_ONECHAT_TRAVEL_UNAVAILABLE) end
    end)
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
    local base = CHAT_ROUTER:GetRegisteredMessageFormatters()[EVENT_CHAT_MESSAGE_CHANNEL]
    CHAT_ROUTER:RegisterMessageFormatter(EVENT_CHAT_MESSAGE_CHANNEL, function(...)
        return A:FormatMessage(base, ...)
    end)
    local original = SharedChatContainer.AddMessageToWindow
    SharedChatContainer.AddMessageToWindow = function(container, window, message, ...)
        if container.system == A.chat and not window.combatLog and window.buffer then
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
