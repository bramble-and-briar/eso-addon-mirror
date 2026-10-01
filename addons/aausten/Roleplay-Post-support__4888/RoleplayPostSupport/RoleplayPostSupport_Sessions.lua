-- Local archive only: call Capture for observed chat, never for a draft or staged chunk.
-- Singleton dot-call API (RoleplayPostSupport.Sessions):
--   Init(sv), SetRecording(bool), SetAddonOnly(bool), Delete(id) -> true or nil, error code
--   Create(name, channel, target), Select(id) -> session or nil, error code
--   Get(id), Current() -> session or nil; List() -> new array of session references
--   SetParticipants(text) -> normalized names array or nil, error code
--   IsRecording() -> boolean; NormalizeName(value) -> trimmed/formatted lowercase string
--   Capture(...) -> persisted record or nil when filtered (no error for ordinary filtering)
-- Create does not select. Select always disarms; successful Delete always disarms.
-- Only sv.sessions and sv.nextSessionId are written; other owners' saved keys are untouched.
-- Returned sessions/records are live saved tables; consumers should treat them as read-only.
-- The initial Compose channel/target remain session metadata only; recording spans
-- all verified player channels for the local player and exact participants.
-- New messages strip one leading Splitter message tag and store addonMarked;
-- addonOnly requires that tag for every eligible sender. This is a convention,
-- not authentication. Missing addonOnly is OFF; existing archives are not rewritten.
-- Messages retain the event channel (including WHISPER_SENT). Whisper
-- targets identify the event's correspondent (sender or recipient); other records
-- have no target. Outgoing whisper sender fields identify us, not the recipient
-- carried by the event. Incoming whispers are never own events; WHISPER_SENT always
-- is. Queue metadata is flat postId/chunkIndex/chunkCount, copied only on outgoing
-- records; it never establishes identity or route.

RoleplayPostSupport = RoleplayPostSupport or {}
local Sessions = {}
RoleplayPostSupport.Sessions = Sessions
local Splitter = RoleplayPostSupport.Splitter

local MAX_SESSIONS, MAX_MESSAGES, MAX_MESSAGE_BYTES = 50, 2000, 8192
local saved, selectedId
local recording = false

local function trim(value)
    if type(value) ~= "string" then return "" end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function formatName(value)
    local name = trim(value)
    if name ~= "" and type(zo_strformat) == "function" then
        name = trim(zo_strformat("<<1>>", name))
    end
    return name
end

function Sessions.NormalizeName(value)
    return string.lower(formatName(value))
end

local function integer(value)
    return type(value) == "number" and value >= 0 and value < math.huge
        and value == math.floor(value)
end

local function timestamp()
    return type(GetTimeStamp) == "function" and GetTimeStamp() or 0
end

local function isChannel(channel, constant)
    return type(constant) == "number" and channel == constant
end

local function destination(channel)
    if isChannel(channel, CHAT_CHANNEL_WHISPER_SENT) then
        return CHAT_CHANNEL_WHISPER
    end
    return channel
end

local channelNames = {
    "CHAT_CHANNEL_SAY", "CHAT_CHANNEL_YELL", "CHAT_CHANNEL_EMOTE",
    "CHAT_CHANNEL_PARTY", "CHAT_CHANNEL_ZONE", "CHAT_CHANNEL_WHISPER",
}
for index = 1, 5 do
    channelNames[#channelNames + 1] = "CHAT_CHANNEL_GUILD_" .. index
    channelNames[#channelNames + 1] = "CHAT_CHANNEL_OFFICER_" .. index
end
for index = 1, 7 do
    channelNames[#channelNames + 1] = "CHAT_CHANNEL_ZONE_LANGUAGE_" .. index
end

local function validPlayerChannel(channel)
    if type(channel) ~= "number" then return false end
    if isChannel(channel, CHAT_CHANNEL_WHISPER_SENT) then return true end
    for _, name in ipairs(channelNames) do
        if isChannel(channel, _G[name]) then return true end
    end
    return false
end

local function validDestination(channel, target)
    if not validPlayerChannel(channel) then return nil, "invalid_channel" end
    if isChannel(channel, CHAT_CHANNEL_WHISPER) and formatName(target) == "" then
        return nil, "target_required"
    end
    return true
end

-- Keep account and character identities distinct: never strip @ or guess aliases.
local function matches(name, fromName, displayName)
    local wanted = Sessions.NormalizeName(name)
    if wanted == "" then return false end
    if wanted:sub(1, 1) == "@" then
        return wanted == Sessions.NormalizeName(displayName)
            or wanted == Sessions.NormalizeName(fromName)
    end
    return wanted == Sessions.NormalizeName(fromName)
end

local function ownDisplayName()
    return type(GetDisplayName) == "function" and GetDisplayName() or ""
end

local function ownCharacterName()
    return type(GetUnitName) == "function" and GetUnitName("player") or ""
end

local function isLocal(fromName, displayName)
    local account = Sessions.NormalizeName(ownDisplayName())
    local eventAccount = Sessions.NormalizeName(displayName)
    if eventAccount ~= "" then
        return account ~= "" and eventAccount == account
    end
    local name = Sessions.NormalizeName(fromName)
    if name == "" then return false end
    return (account ~= "" and name == account)
        or name == Sessions.NormalizeName(ownCharacterName())
end

function Sessions.Init(sv)
    recording, selectedId, saved = false, nil, nil
    if type(sv) ~= "table" then return nil, "invalid_saved_variables" end
    if type(sv.sessions) ~= "table" then sv.sessions = {} end
    local nextId = 1
    for _, session in ipairs(sv.sessions) do
        if type(session) == "table" and integer(session.id) then
            nextId = math.max(nextId, session.id + 1)
        end
    end
    if integer(sv.nextSessionId) then nextId = math.max(nextId, sv.nextSessionId) end
    sv.nextSessionId = nextId
    saved = sv
    return true
end

function Sessions.Get(id)
    if not saved then return nil end
    for _, session in ipairs(saved.sessions) do
        if session.id == id then return session end
    end
end

function Sessions.List()
    local list = {}
    if saved then
        for index, session in ipairs(saved.sessions) do list[index] = session end
    end
    return list
end

function Sessions.Current()
    return Sessions.Get(selectedId)
end

function Sessions.Create(name, channel, target)
    if not saved then return nil, "not_initialized" end
    if #saved.sessions >= MAX_SESSIONS then return nil, "session_limit" end
    name = trim(name)
    if name == "" then return nil, "name_required" end
    channel = destination(channel)
    local ok, err = validDestination(channel, target)
    if not ok then return nil, err end
    local session = {
        id = saved.nextSessionId,
        name = name,
        createdAt = timestamp(),
        channel = channel,
        target = isChannel(channel, CHAT_CHANNEL_WHISPER) and formatName(target) or nil,
        participants = {},
        addonOnly = false,
        messages = {},
        dropped = 0,
    }
    saved.nextSessionId = saved.nextSessionId + 1
    saved.sessions[#saved.sessions + 1] = session
    return session
end

function Sessions.Select(id)
    recording = false
    local session = Sessions.Get(id)
    if not session then return nil, "session_not_found" end
    selectedId = id
    return session
end

function Sessions.SetParticipants(text)
    local session = Sessions.Current()
    if not session then return nil, "no_current_session" end
    if type(text) ~= "string" then return nil, "invalid_participants" end
    local participants = {}
    for chunk in text:gmatch("[^,\r\n]+") do
        local name = formatName(chunk)
        if name ~= "" then participants[#participants + 1] = name end
    end
    session.participants = participants
    return participants
end

function Sessions.SetAddonOnly(enabled)
    local session = Sessions.Current()
    if not session then return nil, "no_current_session" end
    if type(enabled) ~= "boolean" then return nil, "invalid_addon_only_flag" end
    session.addonOnly = enabled
    return true
end

function Sessions.SetRecording(enabled)
    if type(enabled) ~= "boolean" then return nil, "invalid_recording_flag" end
    recording = false
    if not enabled then return true end
    local session = Sessions.Current()
    if not session then return nil, "no_current_session" end
    recording = true
    return true
end

function Sessions.IsRecording()
    return recording
end

function Sessions.Delete(id)
    if not saved then return nil, "not_initialized" end
    for index, session in ipairs(saved.sessions) do
        if session.id == id then
            table.remove(saved.sessions, index)
            recording = false
            if selectedId == id then selectedId = nil end
            return true
        end
    end
    return nil, "session_not_found"
end

function Sessions.Capture(channel, fromName, text, isCustomerService, fromDisplayName, meta)
    local session = Sessions.Current()
    if not recording or not session or isCustomerService then return nil end
    if type(text) ~= "string" or #text > MAX_MESSAGE_BYTES then return nil end
    if not validPlayerChannel(channel) then return nil end

    local whisperSent = isChannel(channel, CHAT_CHANNEL_WHISPER_SENT)
    local whisper = isChannel(channel, CHAT_CHANNEL_WHISPER)
    local outgoing = whisperSent or (not whisper and isLocal(fromName, fromDisplayName))
    if not outgoing then
        local included = false
        for _, participant in ipairs(session.participants) do
            if matches(participant, fromName, fromDisplayName) then
                included = true
                break
            end
        end
        if not included then return nil end
    end

    local cleanText, addonMarked = Splitter.StripMessageTag(text)
    if session.addonOnly == true and not addonMarked then return nil end

    local target
    if whisper or whisperSent then
        target = formatName(fromDisplayName)
        if target == "" then target = formatName(fromName) end
        if target == "" then target = nil end
    end
    local sender, displayName = fromName, fromDisplayName
    if whisperSent then
        sender, displayName = ownCharacterName(), ownDisplayName()
        if sender == "" then sender = displayName end
    end
    local record = {
        text = cleanText,
        addonMarked = addonMarked,
        sender = type(sender) == "string" and sender or "",
        displayName = type(displayName) == "string" and displayName or "",
        channel = channel,
        timestamp = timestamp(),
        outgoing = outgoing,
        target = target,
    }
    -- A metadata table is not evidence of an own message, and must not carry drafts
    -- (or any arbitrary nested queue state) into SavedVariables.
    if outgoing and type(meta) == "table"
        and ((type(meta.postId) == "string" and meta.postId ~= "") or integer(meta.postId))
        and integer(meta.chunkIndex) and meta.chunkIndex >= 1
        and integer(meta.chunkCount) and meta.chunkIndex <= meta.chunkCount then
        record.postId = meta.postId
        record.chunkIndex = meta.chunkIndex
        record.chunkCount = meta.chunkCount
    end
    while #session.messages >= MAX_MESSAGES do
        table.remove(session.messages, 1)
        session.dropped = session.dropped + 1
    end
    session.messages[#session.messages + 1] = record
    return record
end

return Sessions
