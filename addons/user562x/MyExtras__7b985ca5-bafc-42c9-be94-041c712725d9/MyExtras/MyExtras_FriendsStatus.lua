local ME = MyExtras
local FS = {}
ME.FriendsStatus = FS

--------------------------------------------------
-- Config
--------------------------------------------------
local SUBMENU_ICON   = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_contacts.dds"
local UPDATE_NAME    = "MyExtras_FriendsStatus"
local CHECK_INTERVAL = 3000

local CHAT_FEATURE           = "Friends"
local ONLINE_TEXT            = "<<1>> is |c33DD33online|r."
local ONLINE_CHARACTER_TEXT  = "<<1>> (<<2>>) is |c33DD33online|r."
local OFFLINE_TEXT           = "<<1>> is |cFF4444offline|r."
local OFFLINE_CHARACTER_TEXT = "<<1>> (<<2>>) is |cFF4444offline|r."
local SWITCH_TEXT            = "<<1>> is on <<2>>."

local SAMPLE_NAME      = "user562"
local SAMPLE_CHARACTER = "The Rōck"

local FAVORITE_ICON = "EsoUI/Art/Collections/Favorite_StarOnly.dds"
local FAVORITE_TEXT = "Favorite"
local UNFAVORITE_TEXT = "Unfavorite"
local SHOW_ALL = "All"
local SHOW_FAVORITES = "Favorites"

local GUILD_EVENTS = {
    EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED,
    EVENT_GUILD_MEMBER_CHARACTER_UPDATED,
}

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
    friendsStatusShow      = SHOW_ALL,
    friendsStatusOnline    = true,
    friendsStatusOffline   = true,
    friendsStatusCharacter = true,
}

FS.showChoices = {
    { name = "All Friends", value = SHOW_ALL       },
    { name = "Favorites",   value = SHOW_FAVORITES },
}

local gameFormatter = nil
local friends       = {}
local members       = {}
local watching      = false
local checkId       = 0
local hookedLists   = {}

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

local function ShowFavorites()
    return SV().friendsStatusShow == SHOW_FAVORITES
end

local function FriendFavorites()
    local sv = SV()
    if type(sv.friendsFavorites) ~= "table" then sv.friendsFavorites = {} end
    return sv.friendsFavorites
end

local function GuildFavorites(guildId)
    local sv = SV()
    if type(sv.guildFavorites) ~= "table" then sv.guildFavorites = {} end
    if guildId == nil then return sv.guildFavorites end
    local key = tostring(guildId)
    if type(sv.guildFavorites[key]) ~= "table" then sv.guildFavorites[key] = {} end
    return sv.guildFavorites[key]
end

local function IsFavorite(displayName, guildId)
    if type(displayName) ~= "string" or displayName == "" then return false end
    if guildId then
        local all = GuildFavorites()
        local favorites = all[tostring(guildId)]
        return type(favorites) == "table" and favorites[displayName] == true
    end
    return FriendFavorites()[displayName] == true
end

local function SetFavorite(displayName, guildId, value)
    local favorites = guildId and GuildFavorites(guildId) or FriendFavorites()
    favorites[displayName] = value and true or nil
    if guildId and next(favorites) == nil then GuildFavorites()[tostring(guildId)] = nil end
end

local function FriendReported(displayName)
    if not friends[displayName] then return false end
    if not ShowFavorites() then return true end
    return IsFavorite(displayName)
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

local function StatusIcon(online)
    local status = online and PLAYER_STATUS_ONLINE or PLAYER_STATUS_OFFLINE
    local texture
    if IsInGamepadPreferredMode() and ZO_GetGamepadPlayerStatusIcon then
        texture = ZO_GetGamepadPlayerStatusIcon(status)
    elseif ZO_GetPlayerStatusIcon then
        texture = ZO_GetPlayerStatusIcon(status)
    end
    return ME:Icon(texture)
end

local function Line(text, online, tag)
    local icon = online ~= nil and StatusIcon(online) or ""
    return ME:ChatPrefix(tag or CHAT_FEATURE) .. icon .. text
end

local function Print(text)
    ME:Chat(text)
end

--------------------------------------------------
-- Messages
--------------------------------------------------
local function PrintStatus(displayName, characterName, online, tag)
    local sv = SV()
    if online and not sv.friendsStatusOnline then return end
    if not online and not sv.friendsStatusOffline then return end

    local nameLink = ZO_LinkHandler_CreateDisplayNameLink(displayName)
    if sv.friendsStatusCharacter and characterName ~= "" then
        Print(Line(zo_strformat(online and ONLINE_CHARACTER_TEXT or OFFLINE_CHARACTER_TEXT, nameLink, characterName), online, tag))
    else
        Print(Line(zo_strformat(online and ONLINE_TEXT or OFFLINE_TEXT, nameLink), online, tag))
    end
end

local function PrintSwitch(displayName, characterName, tag)
    if not SV().friendsStatusCharacter then return end
    Print(Line(zo_strformat(SWITCH_TEXT, ZO_LinkHandler_CreateDisplayNameLink(displayName), characterName), nil, tag))
end

local function Track(list, displayName, online, raw, silent, report, tag)
    local entry = list[displayName]
    if not entry then
        entry = { online = online, raw = nil, character = "" }
        SetCharacter(entry, raw)
        list[displayName] = entry
    elseif entry.online ~= online then
        if online then
            SetCharacter(entry, raw)
            if report and not silent then PrintStatus(displayName, entry.character, true, tag) end
        else
            if report and not silent then PrintStatus(displayName, entry.character, false, tag) end
            SetCharacter(entry, "")
        end
        entry.online = online
    elseif online and raw ~= "" and raw ~= entry.raw then
        local hadCharacter = entry.character ~= ""
        SetCharacter(entry, raw)
        if hadCharacter and report and not silent then PrintSwitch(displayName, entry.character, tag) end
    end
    entry.seen = checkId
end

--------------------------------------------------
-- Friends List
--------------------------------------------------
function FS:Check(silent)
    if not (GetNumFriends and GetFriendInfo) then return end
    checkId = checkId + 1

    local showFavorites = ShowFavorites()
    for friendIndex = 1, GetNumFriends() do
        local displayName, _, status = GetFriendInfo(friendIndex)
        if type(displayName) == "string" and displayName ~= "" then
            local online = status ~= nil and status ~= PLAYER_STATUS_OFFLINE
            local raw    = online and RawCharacter(friendIndex) or ""
            local report = not showFavorites or IsFavorite(displayName)
            Track(friends, displayName, online, raw, silent, report)
        end
    end

    for displayName, entry in pairs(friends) do
        if entry.seen ~= checkId then friends[displayName] = nil end
    end

    self:CheckGuilds(silent)
end

local function RawMemberCharacter(guildId, memberIndex)
    if not GetGuildMemberCharacterInfo then return "" end
    local hasCharacter, characterName = GetGuildMemberCharacterInfo(guildId, memberIndex)
    if not hasCharacter or type(characterName) ~= "string" then return "" end
    return characterName
end

function FS:CheckGuilds(silent)
    if not (GetNumGuilds and GetGuildId and GetGuildMemberIndexFromDisplayName and GetGuildMemberInfo) then return end
    local all = GuildFavorites()
    for guildIndex = 1, GetNumGuilds() do
        local guildId = GetGuildId(guildIndex)
        local favorites = guildId and all[tostring(guildId)]
        if type(favorites) == "table" then
            local tag = GetGuildName(guildId)
            for displayName in pairs(favorites) do
                local entry = members[displayName]
                if not FriendReported(displayName) and not (entry and entry.seen == checkId) then
                    local memberIndex = GetGuildMemberIndexFromDisplayName(guildId, displayName)
                    if memberIndex then
                        local _, _, _, status = GetGuildMemberInfo(guildId, memberIndex)
                        local online = status ~= nil and status ~= PLAYER_STATUS_OFFLINE
                        local raw = online and RawMemberCharacter(guildId, memberIndex) or ""
                        Track(members, displayName, online, raw, silent, true, tag)
                    end
                end
            end
        end
    end

    for displayName, entry in pairs(members) do
        if entry.seen ~= checkId then members[displayName] = nil end
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
        members = {}
        self:Check(true)
        for i = 1, #FRIEND_EVENTS do
            if FRIEND_EVENTS[i] then
                EVENT_MANAGER:RegisterForEvent(UPDATE_NAME .. i, FRIEND_EVENTS[i], OnFriendEvent)
            end
        end
        for i = 1, #GUILD_EVENTS do
            if GUILD_EVENTS[i] then
                EVENT_MANAGER:RegisterForEvent(UPDATE_NAME .. "Guild" .. i, GUILD_EVENTS[i], OnFriendEvent)
            end
        end
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, CHECK_INTERVAL, OnFriendEvent)
    elseif watching then
        watching = false
        friends = {}
        members = {}
        for i = 1, #FRIEND_EVENTS do
            if FRIEND_EVENTS[i] then
                EVENT_MANAGER:UnregisterForEvent(UPDATE_NAME .. i, FRIEND_EVENTS[i])
            end
        end
        for i = 1, #GUILD_EVENTS do
            if GUILD_EVENTS[i] then
                EVENT_MANAGER:UnregisterForEvent(UPDATE_NAME .. "Guild" .. i, GUILD_EVENTS[i])
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
-- Favorites
--------------------------------------------------
local function RosterGuildId()
    if GUILD_ROSTER_MANAGER and GUILD_ROSTER_MANAGER.GetGuildId then
        return GUILD_ROSTER_MANAGER:GetGuildId()
    end
    return nil
end

local function SelectedName(list)
    local data
    if list.list and ZO_ScrollList_GetSelectedData then
        data = ZO_ScrollList_GetSelectedData(list.list)
    end
    if not data and type(list.GetSelectedData) == "function" then
        data = list:GetSelectedData()
    end
    if type(data) == "table" and type(data.displayName) == "string" and data.displayName ~= "" then
        return data.displayName
    end
    return nil
end

local function DecorateRow(control, data, guildId)
    if not IsEnabled() or type(data) ~= "table" or not control.GetNamedChild then return end
    if not IsFavorite(data.displayName, guildId) then return end
    local label = control:GetNamedChild("DisplayName")
    if not label then return end
    label:SetText(zo_iconFormat(FAVORITE_ICON, "100%", "100%") .. " " .. ZO_FormatUserFacingDisplayName(data.displayName))
end

local function ToggleSelected(list, isGuild)
    local displayName = SelectedName(list)
    if not displayName then return end
    local guildId = isGuild and RosterGuildId() or nil
    if isGuild and not guildId then return end
    SetFavorite(displayName, guildId, not IsFavorite(displayName, guildId))
    if list.list and ZO_ScrollList_RefreshVisible then ZO_ScrollList_RefreshVisible(list.list) end
    if type(list.UpdateKeybinds) == "function" then list:UpdateKeybinds() end
    if watching then FS:Check(true) end
end

local function HookList(list, isGuild)
    if not list or hookedLists[list] then return end
    local area = list.panelFocalArea
    if not (area and type(area.AppendKeybind) == "function" and type(list.SetupRow) == "function") then return end
    hookedLists[list] = true

    local setupRow = list.SetupRow
    list.SetupRow = function(self, control, data, ...)
        setupRow(self, control, data, ...)
        pcall(DecorateRow, control, data, isGuild and RosterGuildId() or nil)
    end

    area:AppendKeybind({
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        keybind   = "UI_SHORTCUT_LEFT_STICK",
        order     = 3000,
        name      = function()
            local displayName = SelectedName(list)
            if displayName and IsFavorite(displayName, isGuild and RosterGuildId() or nil) then
                return UNFAVORITE_TEXT
            end
            return FAVORITE_TEXT
        end,
        visible   = function()
            return IsEnabled() and SelectedName(list) ~= nil
        end,
        callback  = function()
            ToggleSelected(list, isGuild)
        end,
    })
end

function FS:HookLists()
    HookList(rawget(_G, "ZO_FRIENDS_LIST_GAMEPAD"), false)
    HookList(rawget(_G, "GUILD_ROSTER_GAMEPAD"), true)
end

--------------------------------------------------
-- Cleanup
--------------------------------------------------
local function JoinedGuilds()
    local joined = {}
    if not (GetNumGuilds and GetGuildId) then return joined end
    for guildIndex = 1, GetNumGuilds() do
        local guildId = GetGuildId(guildIndex)
        if guildId then joined[tostring(guildId)] = guildId end
    end
    return joined
end

function FS:PruneGuilds(force)
    if not GetNumGuilds then return end
    if not force and GetNumGuilds() == 0 then return end
    local all = GuildFavorites()
    local joined = JoinedGuilds()
    for key, favorites in pairs(all) do
        local guildId = joined[key]
        if not guildId or type(favorites) ~= "table" then
            all[key] = nil
        elseif GetNumGuildMembers and GetNumGuildMembers(guildId) > 0 and GetGuildMemberIndexFromDisplayName then
            for displayName in pairs(favorites) do
                if not GetGuildMemberIndexFromDisplayName(guildId, displayName) then
                    favorites[displayName] = nil
                end
            end
            if next(favorites) == nil then all[key] = nil end
        end
    end
end

function FS:PruneFriends()
    if not (GetNumFriends and GetFriendInfo) or GetNumFriends() == 0 then return end
    local current = {}
    for friendIndex = 1, GetNumFriends() do
        local displayName = GetFriendInfo(friendIndex)
        if type(displayName) == "string" then current[displayName] = true end
    end
    local favorites = FriendFavorites()
    for displayName in pairs(favorites) do
        if not current[displayName] then favorites[displayName] = nil end
    end
end

local function OnLeftGuild()
    zo_callLater(function() FS:PruneGuilds(true) end, 500)
end

local function OnMemberRemoved(_, guildId, displayName)
    if guildId and displayName then SetFavorite(displayName, guildId, false) end
end

local function OnFriendRemoved(_, displayName)
    if displayName then FriendFavorites()[displayName] = nil end
end

function FS:RegisterCleanup()
    if self.cleanupRegistered then return end
    self.cleanupRegistered = true
    local name = UPDATE_NAME .. "Cleanup"
    if EVENT_GUILD_SELF_LEFT_GUILD then
        EVENT_MANAGER:RegisterForEvent(name .. "Left", EVENT_GUILD_SELF_LEFT_GUILD, OnLeftGuild)
    end
    if EVENT_GUILD_MEMBER_REMOVED then
        EVENT_MANAGER:RegisterForEvent(name .. "Member", EVENT_GUILD_MEMBER_REMOVED, OnMemberRemoved)
    end
    if EVENT_FRIEND_REMOVED then
        EVENT_MANAGER:RegisterForEvent(name .. "Friend", EVENT_FRIEND_REMOVED, OnFriendRemoved)
    end
    if EVENT_GUILD_DATA_LOADED then
        EVENT_MANAGER:RegisterForEvent(name .. "Guilds", EVENT_GUILD_DATA_LOADED, function() FS:PruneGuilds(true) end)
    end
    if EVENT_SOCIAL_DATA_LOADED then
        EVENT_MANAGER:RegisterForEvent(name .. "Social", EVENT_SOCIAL_DATA_LOADED, function() FS:PruneFriends() end)
    end
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
        return Line(zo_strformat(online and ONLINE_CHARACTER_TEXT or OFFLINE_CHARACTER_TEXT, SAMPLE_NAME, SAMPLE_CHARACTER), online)
    end
    return Line(zo_strformat(online and ONLINE_TEXT or OFFLINE_TEXT, SAMPLE_NAME), online)
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
            tooltip = "Tells you in chat when your friends, or people you've favorited in your guilds, come online or go offline.\n\n"
                   .. ME.SAVED_ACCOUNT_TIP,
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
                    type     = "dropdown",
                    name     = "Show",
                    choices  = FS.showChoices,
                    default  = defaults.friendsStatusShow,
                    tooltip  = "Who you get messages about. To favorite someone, highlight them in your Friends list "
                            .. "or a Guild Roster and press the left stick. Favorites show a star next to their name.",
                    details  = function()
                        if ShowFavorites() then
                            return "Only tells you about the people you've favorited in your Friends list and Guild Rosters."
                        end
                        return "Tells you about all your friends, plus anyone you've favorited in your Guild Rosters."
                    end,
                    disabled = IsOff,
                    getFunc  = function() return SV().friendsStatusShow end,
                    setFunc  = function(val)
                        SV().friendsStatusShow = val
                        if watching then FS:Check(true) end
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
    self:HookLists()
    self:RegisterCleanup()
    self:Refresh()
end

function FS:OnPlayerActivated()
    self:Hook()
    self:HookLists()
    self:RegisterCleanup()
    self:PruneGuilds(false)
    self:Refresh()
end

function FS:OnReset()
    self:Refresh()
end

ME:RegisterFeature(FS)
