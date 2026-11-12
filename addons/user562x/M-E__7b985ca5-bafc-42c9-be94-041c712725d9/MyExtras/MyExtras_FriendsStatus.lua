local ME = MyExtras
local FS = {}
ME.FriendsStatus = FS

--------------------------------------------------
-- Config
--------------------------------------------------
local SUBMENU_ICON   = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_contacts.dds"
local UPDATE_NAME    = "MyExtras_FriendsStatus"
local CHECK_INTERVAL = 3000

local ONLINE_TEXT            = "<<1>> is now |c33DD33online|r."
local ONLINE_CHARACTER_TEXT  = "<<1>> (<<2>>) is now |c33DD33online|r."
local OFFLINE_TEXT           = "<<1>> is now |cFF4444offline|r."
local OFFLINE_CHARACTER_TEXT = "<<1>> (<<2>>) is now |cFF4444offline|r."
local SWITCH_TEXT            = "<<1>> is now on <<2>>."

local SAMPLE_NAME      = "user562"
local SAMPLE_CHARACTER = "The Rōck"

local FRIEND_EVENTS = {
    EVENT_FRIEND_PLAYER_STATUS_CHANGED,
    EVENT_FRIEND_CHARACTER_UPDATED,
    EVENT_FRIEND_CHARACTER_ZONE_CHANGED,
    EVENT_FRIEND_ADDED,
    EVENT_FRIEND_REMOVED,
    EVENT_SOCIAL_DATA_LOADED,
}

FS.defaults = {
    friendsStatusEnabled   = false,
    friendsStatusOnline    = true,
    friendsStatusOffline   = true,
    friendsStatusCharacter = true,
}

local gameFormatter = nil
local friends       = {}
local watching      = false
local checkId       = 0

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return ME.savedVariables
end

local function IsEnabled()
    local sv = SV()
    return sv ~= nil and sv.friendsStatusEnabled == true
end

local function RawCharacter(friendIndex)
    if not GetFriendCharacterInfo then return "" end
    local hasCharacter, characterName = GetFriendCharacterInfo(friendIndex)
    if not hasCharacter or type(characterName) ~= "string" then return "" end
    return characterName
end

local function SetCharacter(entry, raw)
    if entry.raw == raw then return end
    entry.raw = raw
    entry.character = raw ~= "" and zo_strformat("<<1>>", raw) or ""
end

local function Print(text)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(text)
    else
        d(text)
    end
end

--------------------------------------------------
-- Messages
--------------------------------------------------
local function PrintStatus(displayName, characterName, online)
    local sv = SV()
    if online and not sv.friendsStatusOnline then return end
    if not online and not sv.friendsStatusOffline then return end

    local nameLink = ZO_LinkHandler_CreateDisplayNameLink(displayName)
    if sv.friendsStatusCharacter and characterName ~= "" then
        Print(zo_strformat(online and ONLINE_CHARACTER_TEXT or OFFLINE_CHARACTER_TEXT, nameLink, characterName))
    else
        Print(zo_strformat(online and ONLINE_TEXT or OFFLINE_TEXT, nameLink))
    end
end

local function PrintSwitch(displayName, characterName)
    if not SV().friendsStatusCharacter then return end
    Print(zo_strformat(SWITCH_TEXT, ZO_LinkHandler_CreateDisplayNameLink(displayName), characterName))
end

--------------------------------------------------
-- Friends List
--------------------------------------------------
function FS:Check(silent)
    if not (GetNumFriends and GetFriendInfo) then return end
    checkId = checkId + 1

    for friendIndex = 1, GetNumFriends() do
        local displayName, _, status = GetFriendInfo(friendIndex)
        if type(displayName) == "string" and displayName ~= "" then
            local online = status ~= nil and status ~= PLAYER_STATUS_OFFLINE
            local raw    = online and RawCharacter(friendIndex) or ""
            local entry  = friends[displayName]

            if not entry then
                entry = { online = online, raw = nil, character = "" }
                SetCharacter(entry, raw)
                friends[displayName] = entry
            elseif entry.online ~= online then
                if online then
                    SetCharacter(entry, raw)
                    if not silent then PrintStatus(displayName, entry.character, true) end
                else
                    if not silent then PrintStatus(displayName, entry.character, false) end
                    SetCharacter(entry, "")
                end
                entry.online = online
            elseif online and raw ~= "" and raw ~= entry.raw then
                local hadCharacter = entry.character ~= ""
                SetCharacter(entry, raw)
                if hadCharacter and not silent then PrintSwitch(displayName, entry.character) end
            end
            entry.seen = checkId
        end
    end

    for displayName, entry in pairs(friends) do
        if entry.seen ~= checkId then friends[displayName] = nil end
    end
end

local function OnFriendEvent()
    FS:Check()
end

function FS:Refresh()
    if IsEnabled() then
        if watching then return end
        watching = true
        friends = {}
        self:Check(true)
        for i = 1, #FRIEND_EVENTS do
            if FRIEND_EVENTS[i] then
                EVENT_MANAGER:RegisterForEvent(UPDATE_NAME .. i, FRIEND_EVENTS[i], OnFriendEvent)
            end
        end
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, CHECK_INTERVAL, OnFriendEvent)
    elseif watching then
        watching = false
        friends = {}
        for i = 1, #FRIEND_EVENTS do
            if FRIEND_EVENTS[i] then
                EVENT_MANAGER:UnregisterForEvent(UPDATE_NAME .. i, FRIEND_EVENTS[i])
            end
        end
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    end
end

--------------------------------------------------
-- Game Message
--------------------------------------------------
local function RouteStatus(...)
    if IsEnabled() then return nil end
    if gameFormatter then
        return gameFormatter(...)
    end
end

function FS:Hook()
    if self.hooked then return end
    if not (CHAT_ROUTER and CHAT_ROUTER.RegisterMessageFormatter and CHAT_ROUTER.GetRegisteredMessageFormatters) then
        return
    end
    local formatters = CHAT_ROUTER:GetRegisteredMessageFormatters()
    if type(formatters) ~= "table" then return end
    gameFormatter = formatters[EVENT_FRIEND_PLAYER_STATUS_CHANGED]
    CHAT_ROUTER:RegisterMessageFormatter(EVENT_FRIEND_PLAYER_STATUS_CHANGED, RouteStatus)
    self.hooked = true
end

--------------------------------------------------
-- Samples
--------------------------------------------------
local function SystemColor()
    if GetChatCategoryColor and CHAT_CATEGORY_SYSTEM then
        local r, g, b = GetChatCategoryColor(CHAT_CATEGORY_SYSTEM)
        if r and g and b then return r, g, b end
    end
    return 1, 1, 1
end

local function SampleText(online)
    if SV().friendsStatusCharacter then
        return zo_strformat(online and ONLINE_CHARACTER_TEXT or OFFLINE_CHARACTER_TEXT, SAMPLE_NAME, SAMPLE_CHARACTER)
    end
    return zo_strformat(online and ONLINE_TEXT or OFFLINE_TEXT, SAMPLE_NAME)
end

local function Sample(online)
    local r, g, b = SystemColor()
    return SampleText(online), nil, r, g, b
end

--------------------------------------------------
-- Settings
--------------------------------------------------
function FS:GetOptions()
    local defaults = self.defaults

    local function IsOff() return not IsEnabled() end

    return {
        {
            type    = "submenu",
            name    = "Friends' Status",
            icon    = SUBMENU_ICON,
            tooltip = "Tells you in chat when your friends come online or go offline.\n\n" .. ME.SAVED_ACCOUNT_TIP,
            options = {
                {
                    type    = "toggle",
                    name    = "Enabled",
                    preset  = "YES_NO",
                    default = defaults.friendsStatusEnabled,
                    tooltip = "Shows a message in chat when a friend comes online or goes offline.",
                    getFunc = function() return SV().friendsStatusEnabled end,
                    setFunc = function(val)
                        SV().friendsStatusEnabled = val
                        FS:Refresh()
                    end,
                },
                {
                    type     = "toggle",
                    name     = "Show Online",
                    preset   = "YES_NO",
                    default  = defaults.friendsStatusOnline,
                    tooltip  = "Shows a message when a friend comes online.",
                    sample   = function() return Sample(true) end,
                    disabled = IsOff,
                    getFunc  = function() return SV().friendsStatusOnline end,
                    setFunc  = function(val) SV().friendsStatusOnline = val end,
                },
                {
                    type     = "toggle",
                    name     = "Show Offline",
                    preset   = "YES_NO",
                    default  = defaults.friendsStatusOffline,
                    tooltip  = "Shows a message when a friend goes offline.",
                    sample   = function() return Sample(false) end,
                    disabled = IsOff,
                    getFunc  = function() return SV().friendsStatusOffline end,
                    setFunc  = function(val) SV().friendsStatusOffline = val end,
                },
                {
                    type     = "toggle",
                    name     = "Show Character Name",
                    preset   = "YES_NO",
                    default  = defaults.friendsStatusCharacter,
                    tooltip  = "Shows which character your friend is on next to their name, and when they switch characters.",
                    sample   = function() return Sample(true) end,
                    disabled = IsOff,
                    getFunc  = function() return SV().friendsStatusCharacter end,
                    setFunc  = function(val) SV().friendsStatusCharacter = val end,
                },
            },
        },
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function FS:Init()
    self:Hook()
    self:Refresh()
end

function FS:OnPlayerActivated()
    self:Hook()
    self:Refresh()
end

function FS:OnReset()
    self:Refresh()
end

ME:RegisterFeature(FS)
