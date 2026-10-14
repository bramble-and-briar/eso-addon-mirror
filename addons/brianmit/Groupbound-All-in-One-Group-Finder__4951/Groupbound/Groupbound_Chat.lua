-- Groupbound_Chat.lua : listens to zone chat (and say / yell) and your guild chats, keeps every
-- group post for sv.chatMinutes (15) minutes. One entry per player: posting again moves it back
-- to the top ("posted 3 times"); "full" removes it. Whispers from a player you contacted mark
-- their entry "replied". Addons can't send chat by themselves: Whisper / Zone chat buttons only
-- open the chat box with the text filled in; you press Enter.

local G = Groupbound
local Parse = G.Parse
local Chat = {}
G.Chat = Chat

local posts = {}          -- [account lowercase] = entry
local MAX_POSTS = 200
local FULL_KEEP = 60      -- a "full" group stays (greyed) this many seconds

-- channel -> "zone" | "guild" (+ guild number)
local CHANNELS = {}
local GUILD_OF = {}
local function AddChannel(name, src, guildIndex)
    local id = _G[name]
    if id ~= nil then
        CHANNELS[id] = src
        if guildIndex then GUILD_OF[id] = guildIndex end
    end
end
AddChannel("CHAT_CHANNEL_ZONE", "zone")
for i = 1, 7 do AddChannel("CHAT_CHANNEL_ZONE_LANGUAGE_" .. i, "zone") end
AddChannel("CHAT_CHANNEL_SAY", "zone")
AddChannel("CHAT_CHANNEL_YELL", "zone")
for i = 1, 5 do
    AddChannel("CHAT_CHANNEL_GUILD_" .. i, "guild", i)
    AddChannel("CHAT_CHANNEL_OFFICER_" .. i, "guild", i)
end

local function GuildName(index)
    local ok, id = pcall(GetGuildId, index)
    if not ok or not id or id == 0 then return "" end
    local okName, name = pcall(GetGuildName, id)
    return okName and name or ""
end

local function ZoneName()
    local ok, name = pcall(GetPlayerActiveZoneName)
    if ok and name and name ~= "" then return zo_strformat(SI_ZONE_NAME, name) end
    return ""
end

local changedPending = false
local function Changed()
    if changedPending then return end
    changedPending = true
    G.Later(function()
        changedPending = false
        G.callbacks:FireCallbacks("PostsChanged")
    end, 300, "Chat")
end

local function OnMessage(_, channelType, fromName, text, isCustomerService, fromDisplayName)
    if isCustomerService then return end
    local src = CHANNELS[channelType]
    local account = fromDisplayName ~= "" and fromDisplayName or fromName
    if channelType == CHAT_CHANNEL_WHISPER then
        -- a reply from someone you whispered / applied to
        local key = G.AccountKey(account)
        if key and G.Board.contacts[key] then
            G.Board.contacts[key].replied = G.Now()
            local p = posts[key]
            if p then p.replied = G.Now() end
            Changed()
        end
        return
    end
    if not src then return end
    local sv = G.sv
    if not sv.sources.zone and not sv.sources.guild then return end
    if not account or account == "" or account == GetDisplayName() then return end
    if IsIgnored and IsIgnored(account) then return end
    local key = G.AccountKey(account)
    local info = Parse.Post(text)
    if not info then return end
    local now = G.Now()
    local p = posts[key]
    if info.kind == "full" then
        if p and not p.full then
            p.full = now
            Changed()
        end
        return
    end
    local char = fromName ~= "" and not IsDecoratedDisplayName(fromName) and zo_strformat("<<1>>", fromName) or nil
    if not p then
        p = { id = "c:" .. key, chat = true, account = account, firstSeen = now, count = 0 }
        posts[key] = p
    elseif p.content ~= info.content then
        -- a different run: counts as a new post
        p.firstSeen, p.count, p.full, p.replied = now, 0, nil, nil
    end
    p.char = char or p.char
    p.src = src
    p.where = src == "guild" and GuildName(GUILD_OF[channelType]) or ZoneName()
    p.text = info.text
    p.raw = text            -- with its links (achievement links)
    p.lang = info.lang
    p.kind = info.kind
    p.content = info.content
    p.vet = info.vet
    p.hm = info.hm
    p.tags = info.tags
    p.need = info.need
    p.cp = info.cp
    p.startAt, p.startNow = info.startAt, info.startNow
    p.lastSeen = now
    p.count = p.count + 1
    p.full = nil
    Changed()
end

-- drops old posts (and the oldest when there are too many)
local function Prune()
    local now = G.Now()
    local keep = (G.sv.chatMinutes or 15) * 60
    local n, changed = 0, false
    for key, p in pairs(posts) do
        if now - p.lastSeen > keep or (p.full and now - p.full > FULL_KEEP) then
            posts[key] = nil
            changed = true
        else
            n = n + 1
        end
    end
    while n > MAX_POSTS do
        local oldestKey, oldest
        for key, p in pairs(posts) do
            if not oldest or p.lastSeen < oldest then oldestKey, oldest = key, p.lastSeen end
        end
        posts[oldestKey] = nil
        n = n - 1
        changed = true
    end
    if changed then Changed() end
end

function Chat.Posts()
    return posts
end

function Chat.Forget(account)
    local key = G.AccountKey(account)
    if key and posts[key] then
        posts[key] = nil
        Changed()
    end
end

-- opens the chat box with text filled in (you press Enter): the game's StartChatInput, as the
-- Friends list's Whisper does (esoui friendslist_keyboard.lua)
local function Open(text, channel, target)
    if StartChatInput then
        StartChatInput(text or "", channel, target)
    elseif CHAT_SYSTEM and CHAT_SYSTEM.StartTextEntry then
        CHAT_SYSTEM:StartTextEntry(text or "", channel, target)
    end
end

function Chat.Whisper(target, text)
    if not target or target == "" then return end
    Open(text, CHAT_CHANNEL_WHISPER, target)
end

-- a channel (zone, a guild)
function Chat.Prepare(channel, text)
    if channel then Open(text, channel) end
end

-- your guilds: { { index, name, channel } }
function Chat.Guilds()
    local list = {}
    local ok, n = pcall(GetNumGuilds)
    for i = 1, (ok and n or 0) do
        local channel = _G["CHAT_CHANNEL_GUILD_" .. i]
        local name = GuildName(i)
        if channel and name ~= "" then list[#list + 1] = { index = i, name = name, channel = channel } end
    end
    return list
end

function Chat.Init()
    G.EM:RegisterForEvent("Groupbound_Chat", EVENT_CHAT_MESSAGE_CHANNEL, OnMessage)
    G.EM:RegisterForUpdate("Groupbound_ChatPrune", 30000, Prune)
end
