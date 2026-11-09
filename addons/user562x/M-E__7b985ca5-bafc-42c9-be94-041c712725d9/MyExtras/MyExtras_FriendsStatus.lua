local ME = MyExtras
local FS = {}
ME.FriendsStatus = FS

--------------------------------------------------
-- Config
--------------------------------------------------
local SUBMENU_ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_contacts.dds"

local ONLINE_TEXT           = "<<1>> is now |c33DD33online|r."
local ONLINE_CHARACTER_TEXT = "<<1>> (<<2>>) is now |c33DD33online|r."
local OFFLINE_TEXT           = "<<1>> is now |cFF4444offline|r."
local OFFLINE_CHARACTER_TEXT = "<<1>> (<<2>>) is now |cFF4444offline|r."

FS.defaults = {
    friendsStatusEnabled   = false,
    friendsStatusOnline    = true,
    friendsStatusOffline   = true,
    friendsStatusCharacter = true,
}

local gameFormatter = nil

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

local function ChatAvailable()
    if not (CHAT_ROUTER and CHAT_ROUTER.RegisterMessageFormatter and CHAT_ROUTER.GetRegisteredMessageFormatters) then
        return false
    end
    return IsChatSystemAvailableForCurrentPlatform() == true
end

--------------------------------------------------
-- Messages
--------------------------------------------------
local function FormatStatus(displayName, characterName, oldStatus, newStatus)
    local wasOnline = oldStatus ~= PLAYER_STATUS_OFFLINE
    local isOnline  = newStatus ~= PLAYER_STATUS_OFFLINE
    if wasOnline == isOnline then return nil end

    local sv = SV()
    if isOnline and not sv.friendsStatusOnline then return nil end
    if not isOnline and not sv.friendsStatusOffline then return nil end

    local nameLink = ZO_LinkHandler_CreateDisplayNameLink(displayName)
    local text
    if sv.friendsStatusCharacter and type(characterName) == "string" and characterName ~= "" then
        local characterLink = ZO_LinkHandler_CreateCharacterLink(characterName)
        text = zo_strformat(isOnline and ONLINE_CHARACTER_TEXT or OFFLINE_CHARACTER_TEXT, nameLink, characterLink)
    else
        text = zo_strformat(isOnline and ONLINE_TEXT or OFFLINE_TEXT, nameLink)
    end
    return text, nil, displayName
end

local function RouteStatus(...)
    if IsEnabled() then
        return FormatStatus(...)
    end
    if gameFormatter then
        return gameFormatter(...)
    end
end

function FS:Hook()
    if self.hooked or not ChatAvailable() then return end
    local formatters = CHAT_ROUTER:GetRegisteredMessageFormatters()
    if type(formatters) ~= "table" then return end
    gameFormatter = formatters[EVENT_FRIEND_PLAYER_STATUS_CHANGED]
    CHAT_ROUTER:RegisterMessageFormatter(EVENT_FRIEND_PLAYER_STATUS_CHANGED, RouteStatus)
    self.hooked = true
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
                    setFunc = function(val) SV().friendsStatusEnabled = val end,
                },
                {
                    type     = "toggle",
                    name     = "Show Online",
                    preset   = "YES_NO",
                    default  = defaults.friendsStatusOnline,
                    tooltip  = "Shows a message when a friend comes online.",
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
                    disabled = IsOff,
                    getFunc  = function() return SV().friendsStatusOffline end,
                    setFunc  = function(val) SV().friendsStatusOffline = val end,
                },
                {
                    type     = "toggle",
                    name     = "Show Character Name",
                    preset   = "YES_NO",
                    default  = defaults.friendsStatusCharacter,
                    tooltip  = "Shows which character your friend is on next to their name.",
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
end

function FS:OnPlayerActivated()
    self:Hook()
end

ME:RegisterFeature(FS)
