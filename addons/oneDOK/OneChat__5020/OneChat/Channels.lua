local A = OneChat

local function token(key, channel, category, incomingOnly)
    return { key = key, channel = channel,
        category = category or GetChannelCategoryFromChannel(channel), incomingOnly = incomingOnly }
end

function A:BuildChannels()
    self.groups, self.tokens, self.byChannel, self.byKey = {}, {}, {}, {}
    local function group(key, name, children)
        local g = { key = key, name = name, children = children }
        self.groups[#self.groups + 1] = g
        local function register(entries)
          for _, entry in ipairs(entries) do
            for _, t in ipairs(entry.tokens or {}) do
                self.tokens[#self.tokens + 1] = t
                self.byKey[t.key] = t
                if t.channel then self.byChannel[t.channel] = t end
            end
            if entry.children then register(entry.children) end
          end
        end
        register(children)
    end
    local function entry(nameId, key, channel)
        return { name = GetString(nameId), tokens = { token(key, channel) } }
    end
    local zone = { name = GetString(SI_CHAT_CHANNEL_NAME_ZONE), tokens = { token("zone", CHAT_CHANNEL_ZONE) } }
    -- The official table maps every supported language; do not assume enum order.
    for language = OFFICIAL_LANGUAGE_ITERATION_BEGIN, OFFICIAL_LANGUAGE_ITERATION_END do
        local info = ZO_OFFICIAL_LANGUAGE_TO_CHAT_INFO[language]
        zone.tokens[#zone.tokens + 1] = token("zone:" .. language, info.channel, info.category, true)
    end
    local npc = { name = GetString(SI_CHAT_CHANNEL_NAME_NPC), tokens = {} }
    for _, channel in ipairs({ CHAT_CHANNEL_MONSTER_SAY, CHAT_CHANNEL_MONSTER_YELL,
        CHAT_CHANNEL_MONSTER_WHISPER, CHAT_CHANNEL_MONSTER_EMOTE }) do
        npc.tokens[#npc.tokens + 1] = token("npc:" .. channel, channel, nil, true)
    end
    group("zone", GetString(SI_CHAT_CHANNEL_NAME_ZONE), {
        entry(SI_CHAT_CHANNEL_NAME_SAY, "say", CHAT_CHANNEL_SAY),
        entry(SI_CHAT_CHANNEL_NAME_EMOTE, "emote", CHAT_CHANNEL_EMOTE), zone,
        entry(SI_CHAT_CHANNEL_NAME_YELL, "yell", CHAT_CHANNEL_YELL), npc,
    })
    group("group", GetString(SI_CHAT_CHANNEL_NAME_PARTY), {
        entry(SI_CHAT_CHANNEL_NAME_PARTY, "group", CHAT_CHANNEL_PARTY),
    })
    -- Stable guild IDs, never slot numbers, are persisted. Slots can change.
    local guilds = {}
    for index = 1, GetNumGuilds() do
        local guildId = GetGuildId(index)
        local guildToken = token("guild:" .. guildId, _G["CHAT_CHANNEL_GUILD_" .. index])
        local officerToken = token("officer:" .. guildId, _G["CHAT_CHANNEL_OFFICER_" .. index])
        guildToken.guildId, officerToken.guildId = guildId, guildId
        guilds[#guilds + 1] = { key = "guild:" .. guildId, name = GetGuildName(guildId), children = {
            { name = GetString(SI_ONECHAT_GUILD), tokens = { guildToken } },
            { name = GetString(SI_ONECHAT_OFFICER), tokens = { officerToken } },
        } }
    end
    group("guilds", GetString(SI_ONECHAT_GUILD), guilds)
    group("other", GetString(SI_ONECHAT_OTHER), {
        { name = GetString(SI_CHAT_CHANNEL_NAME_WHISPER), tokens = {
            token("whisper:in", CHAT_CHANNEL_WHISPER, CHAT_CATEGORY_WHISPER_INCOMING, true),
            token("whisper:out", CHAT_CHANNEL_WHISPER_SENT, CHAT_CATEGORY_WHISPER_OUTGOING, true),
        } },
        { name = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_SYSTEM), tokens = {
            token("system", nil, CHAT_CATEGORY_SYSTEM, true),
        } },
    })
end

function A:NormalizeZoneState(container, window, state)
    -- One incoming Zone checkbox controls every zone category. Language zone
    -- channels are never outgoing choices, including in older saved profiles.
    for _, t in ipairs(self.tokens) do
        if t.key:match("^zone:") then
            state.incoming[t.key] = state.incoming.zone == true
            state.outgoing[t.key] = nil
            container:SetWindowFilterEnabled(window.tab.index, t.category, state.incoming[t.key])
        end
    end
    if state.last and state.last:match("^zone:") then
        state.last = state.outgoing.zone and "zone" or nil
    end
end

function A:IsAvailable(t)
    if not t or t.incomingOnly then return false end
    local data = self.chat.channelData[t.channel]
    return data ~= nil and (not data.requires or data.requires(t.channel))
        and not IsChannelCategoryCommunicationRestricted(t.category)
end

function A:Allowed(state)
    local result = {}
    for _, t in ipairs(self.tokens) do
        if state.outgoing[t.key] and self:IsAvailable(t) then result[#result + 1] = t end
    end
    return result
end

function A:ResolveSelection(state)
    local last = self.byKey[state.last or ""]
    if last and state.outgoing[last.key] and self:IsAvailable(last) then return last end
    local first = self:Allowed(state)[1]
    state.last = first and first.key or nil
    return first
end

function A:GroupTokens(group, direction)
    local tokens = {}
    for _, entry in ipairs(group.children) do
        for _, t in ipairs(entry.tokens or self:GroupTokens(entry, direction)) do
            if direction == "incoming" or not t.incomingOnly then tokens[#tokens + 1] = t end
        end
    end
    return tokens
end

function A:SelectionState(map, tokens)
    local count = 0
    for _, t in ipairs(tokens) do if map[t.key] then count = count + 1 end end
    return count > 0 and count == #tokens, count > 0 and count < #tokens
end

function A:SetTokens(container, window, direction, tokens, checked)
    local state = self:GetTabState(container, window)
    for _, t in ipairs(tokens) do
        state[direction][t.key] = checked
        if direction == "incoming" then
            container:SetWindowFilterEnabled(window.tab.index, t.category, checked)
        end
    end
    if window == self.activeWindow and direction == "outgoing" then self:RestoreSelection() end
    self:SnapshotTabs()
end
