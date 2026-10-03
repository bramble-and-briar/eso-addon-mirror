local KD = KyzderpsDerps
local Sync = KD.Sync

Sync.Kyzerg = {}
local Kyzerg = Sync.Kyzerg

---------------------------------------------------------------------
-- Known accounts
---------------------------------------------------------------------
local function FormatName(name)
    return zo_strformat("<<1>>", name)
end

local function NameIsUnit(name, unitTag)
    return GetUnitName(unitTag) == name or GetUnitDisplayName(unitTag) == name
end

local function NameIsPlayer(name)
    return NameIsUnit(name, "player")
end

local function GetSVTable()
    if (not KyzderpsDerpsSavedVariables.Default) then return {} end
    return KyzderpsDerpsSavedVariables.Default
end

local function IsSelf(name)
    -- @name
    if (GetSVTable()[name]) then
        return true
    end

    -- char name
    for _, accountData in pairs(GetSVTable()) do
        if (accountData.Values and accountData.Values.charIdInfo) then
            -- No longer keyed by char name, so have to iterate
            for _, info in pairs(accountData.Values.charIdInfo) do
                if (info.lastKnownName == name) then
                    return true
                end
            end
        end
    end

    return false
end

-- get acc name from char name, but it could be acc name already
local function GetGroupMemberAccountName(name)
    for i = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(i)
        if (NameIsUnit(name, unitTag)) then
            return GetUnitDisplayName(unitTag)
        end
    end
end

-- get both names from guild
local function GetGuildMemberAccountAndCharName(name)
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        for j = 1, GetNumGuildMembers(guildId) do
            local atName = GetGuildMemberInfo(guildId, j)
            local _, characterName = GetGuildMemberCharacterInfo(guildId, j)
            if (name == atName or name == characterName) then
                return atName, characterName
            end
        end
    end
end

local KYZ = {
    ["@Kyzeragon"] = true,
    ["@Kyzeragone"] = true,
    ["@TheClawlessConqueror"] = true,
}

local JWPD2 = {
    ["@camrenis"] = true,
    ["@efiye"] = true,
    ["@jetplane_18"] = true,
    ["@jetplane_19"] = true,
}

local function IsKyzer(name)
    local atName = GetGroupMemberAccountName(name)
    return KYZ[atName]
end

local function IsJWPD2(name)
    local atName = GetGroupMemberAccountName(name)
    return KYZ[atName] or JWPD2[atName]
end

local function IsJWPD2FromGuild(name)
    local atName, characterName = GetGuildMemberAccountAndCharName(name)
    return KYZ[atName] or JWPD2[atName]
end

-- Is own alt account, or is Kyzer
local function IsSelfOrKyzer(name)
    return IsSelf(name) or IsKyzer(name)
end

local function IsSelfOrJWPD2(name)
    return IsSelf(name) or IsJWPD2(name)
end

local function IsPlayerJWPD2()
    local atName = GetUnitDisplayName("player")
    return KYZ[atName] or JWPD2[atName]
end
KD.IsPlayerJWPD2 = IsPlayerJWPD2


---------------------------------------------------------------------
-- Misc
---------------------------------------------------------------------
local function IndexOf(tab, item)
    for i, v in ipairs(tab) do
        if (v == item) then
            return i
        end
    end
    return -1
end

local drivers = {}
local onlineCharNames = {}
local passengers = {}
local riders = {}
local function FindNearestDriver(fromName)
    ZO_ClearTable(drivers)
    ZO_ClearTable(onlineCharNames)
    ZO_ClearTable(passengers)

    local isPassenger = false

    -- Only online in group
    for i = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(i)
        local atName = GetUnitDisplayName(unitTag)
        if (IsUnitOnline(unitTag)) then
            local charName = GetUnitName(unitTag)
            onlineCharNames[atName] = charName

            local mountedState, isRidingGroupMount, hasFreePassengerSlot = GetTargetMountedStateInfo(charName)
            KD:dbg(zo_strformat("<<1>>: mountedState <<2>> isRidingGroupMount <<3>> hasFreePassengerSlot <<4>>", charName, mountedState, isRidingGroupMount and "true" or "false", hasFreePassengerSlot and "true" or "false"))
            if (mountedState == MOUNTED_STATE_MOUNT_RIDER and isRidingGroupMount and hasFreePassengerSlot) then
                table.insert(drivers, unitTag)
            else
                table.insert(passengers, unitTag)
                if (AreUnitsEqual(unitTag, "player")) then
                    isPassenger = true
                end
            end
        end
    end

    table.sort(drivers)
    table.sort(passengers)

    -- look for closest driver
    local driver
    local distance = math.huge
    if (isPassenger) then
        local _, pX, pY, pZ = GetUnitRawWorldPosition("player")
        for _, unitTag in ipairs(drivers) do
            if (IsUnitInGroupSupportRange(unitTag)) then
                local _, x, y, z = GetUnitRawWorldPosition(unitTag)
                local dist = math.pow(x - pX, 2) + math.pow(y - pY, 2) + math.pow(z - pZ, 2)
                KD:msg(GetUnitDisplayName(unitTag) .. " sqdistance: " .. dist)
                if (dist < distance) then
                    driver = unitTag
                    distance = dist
                end
            end
        end
    end

    return GetUnitDisplayName(driver)
end

local function KMount()
    if (IsMounted() or IsGroupMountPassenger()) then return end
    local driver = FindNearestDriver()
    if (driver) then
        KD:msg("Trying to use " .. driver .. "'s mount")
        UseMountAsPassenger(driver)
    end
end
Kyzerg.KMount = KMount

local function KJWPD2(fromName)
    for name, _ in pairs(KYZ) do
        if (name ~= GetUnitDisplayName("player")) then
            KD:msg("Inviting " .. name)
            GroupInviteByName(name)
        end
    end
    for name, _ in pairs(JWPD2) do
        if (name ~= GetUnitDisplayName("player")) then
            KD:msg("Inviting " .. name)
            GroupInviteByName(name)
        end
    end
end


---------------------------------------------------------------------
-- Functions
---------------------------------------------------------------------
-- fromName, text
local COMMANDS = {
    -- Port to sender
    k2me = function(fromName)
        if (NameIsPlayer(fromName)) then return end
        if (not IsSelfOrJWPD2(fromName)) then
            KD:msg("Unauthorized k2me from " .. fromName)
            return
        end
        KD:msg("Porting to " .. fromName)
        if (IsPlayerInGroup(fromName)) then
            JumpToGroupMember(fromName)
        else
            JumpToGuildMember(fromName)
        end
    end,

    -- TODO: port to crown

    -- Port to house
    khouse = function(fromName, text)
        if (not IsSelfOrJWPD2(fromName)) then
            KD:msg("Unauthorized khouse from " .. fromName)
            return
        end
        KD.KHouse.PortToHouse(string.sub(text, 8))
    end,

    -- Port to self house
    khouseself = function(fromName)
        if (not IsSelfOrJWPD2(fromName)) then
            KD:msg("Unauthorized khouseself from " .. fromName)
            return
        end
        RequestJumpToHouse(GetHousingPrimaryHouse())
    end,

    -- Mudball
    kmud = function(fromName)
        if (not IsSelfOrJWPD2(fromName)) then
            KD:msg("Unauthorized kmud from " .. fromName)
            return
        end
        UseCollectible(601)
    end,

    -- Snowball
    ksnow = function(fromName)
        if (not IsSelfOrJWPD2(fromName)) then
            KD:msg("Unauthorized ksnow from " .. fromName)
            return
        end
        UseCollectible(6932)
    end,

    -- Invite all (CURRENT PLAYER ONLY)
    kinvite = function(fromName)
        if (not NameIsPlayer(fromName)) then return end
        for name, _ in pairs(GetSVTable()) do
            if (name ~= GetUnitDisplayName("player")) then
                KD:msg("Inviting " .. name)
                GroupInviteByName(name)
            end
        end
    end,

    -- PTE
    kpte = function(fromName)
        if (IsSelf(fromName)) then
            ExitInstanceImmediately()
        end
    end,

    -- Accept whatever?
    kyes = function(fromName)
        if (not IsSelfOrJWPD2(fromName)) then
            KD:msg("Unauthorized kyes from " .. fromName)
            return
        end
        local groupInvite = GetGroupInviteInfo()
        if (groupInvite and groupInvite ~= "") then
            AcceptGroupInvite()
            KD:msg("Accepting group invite")
        elseif (HasLFGReadyCheckNotification()) then
            AcceptLFGReadyCheckNotification()
            KD:msg("Accepting ready check")
        elseif (GetOfferedQuestShareIds()) then
            local id = GetOfferedQuestShareIds()
            AcceptSharedQuest(id)
            KD:msg("Accepting quest " .. tostring(id))
        else
            KD:msg("Nothing to accept")
        end
    end,

    -- reloadui
    krl = function(fromName)
        if (IsSelf(fromName)) then
            ReloadUI()
        end
    end,

    -- log out
    klog = function(fromName)
        if (IsSelf(fromName)) then
            Logout()
        end
    end,

    -- quit
    kquit = function(fromName)
        if (IsSelf(fromName)) then
            Quit()
        end
    end,

    -- Get on multi rider mount as passenger
    kmount = KMount,

    -- Give crown
    kcrown = function(fromName)
        if (NameIsPlayer(fromName)) then return end
        if (not IsUnitGroupLeader("player")) then return end
        if (not IsSelfOrJWPD2(fromName)) then
            KD:msg("Unauthorized kcrown from " .. fromName)
            return
        end

        -- Find the sender's unit tag
        for i = 1, GetGroupSize() do
            local unitTag = GetGroupUnitTagByIndex(i)
            if (IsUnitOnline(unitTag) and NameIsUnit(fromName, unitTag)) then
                GroupPromote(unitTag)
                return
            end
        end
    end,

    -- ktp
    ktp = function(fromName, text)
        if (not IsSelfOrJWPD2(fromName)) then
            KD:msg("Unauthorized ktp from " .. fromName)
            return
        end
        KD.PortToAny(string.sub(text, 5))
    end,

    -- krez
    krez = function(fromName)
        if (not IsSelfOrJWPD2(fromName)) then
            KD:msg("Unauthorized krez from " .. fromName)
            return
        end
        Revive()
    end,
}

function Kyzerg.PrintCommands()
    for cmd, _ in pairs(COMMANDS) do
        KD:msg(cmd)
    end
end


---------------------------------------------------------------------
-- Chat handler
---------------------------------------------------------------------
local validChannels = {}
local attnChannel, fcChannel

local function OnChatMessage(_, channelType, fromName, text)
    -- jwpd2 autoinvite
    if (attnChannel == channelType and text == "jwpd2") then
        if (NameIsPlayer(fromName)) then return end
        if (not KYZ[GetUnitDisplayName("player")]) then return end
        -- Only invite if jwpd2 and self available
        if (IsJWPD2FromGuild(fromName) and GetPlayerStatus() == PLAYER_STATUS_ONLINE) then
            -- and is group leader or not in group
            if (GetGroupSize() < 2 or IsUnitGroupLeader("player")) then
                local atName, characterName = GetGuildMemberAccountAndCharName(fromName)
                GroupInviteByName(FormatName(characterName))
            end
        end
        return
    end

    if (channelType == fcChannel and text == "x") then
        if (NameIsPlayer(fromName)) then return end
        -- and is group leader or not in group
        if (GetGroupSize() < 2 or IsUnitGroupLeader("player")) then
            local atName, characterName = GetGuildMemberAccountAndCharName(fromName)
            GroupInviteByName(FormatName(characterName))
        end
        return
    end

    if (not validChannels[channelType]) then return end

    local cmd
    for word in text:gmatch("%S+") do
        if (word and word ~= "") then
            cmd = word
            break
        end
    end
    if (not cmd) then return end

    local func = COMMANDS[cmd]
    if (func) then
        func(zo_strformat("<<1>>", fromName), text)
    end
end


---------------------------------------------------------------------
-- Quest share handler
---------------------------------------------------------------------
local function OnQuestShared(_, questId)
    local questName, _, _, displayName = GetOfferedQuestShareInfo(questId)
    KD:msg(displayName .. " shared " .. questName .. " (" .. questId .. ")")

    if (IsSelfOrJWPD2(displayName)) then
        AcceptSharedQuest(questId)
        KD:msg("Accepting quest " .. questName .. " (" .. questId .. ") from " .. displayName)
    end
end


---------------------------------------------------------------------
---------------------------------------------------------------------
local function OnFocusChanged(_, hasFocus)
    if (hasFocus) then
        StopAllMovement()
    end
end


---------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------
function Kyzerg.Initialize()
    EVENT_MANAGER:UnregisterForEvent(KD.name .. "KyzergChatMessage", EVENT_CHAT_MESSAGE_CHANNEL)
    EVENT_MANAGER:UnregisterForEvent(KD.name .. "KyzergFocus", EVENT_GAME_FOCUS_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(KD.name .. "KyzergQuestShared", EVENT_QUEST_SHARED)

    if (KD.savedOptions.general.experimental or KD.savedOptions.kyzerg.group) then
        KD:dbg("    Initializing Kyzerg module...")

        EVENT_MANAGER:RegisterForEvent(KD.name .. "KyzergChatMessage", EVENT_CHAT_MESSAGE_CHANNEL, OnChatMessage)

        -- Add attn for jwpd2
        if (IsPlayerJWPD2()) then
            for i = 1, GetNumGuilds() do
                if (GetGuildId(i) == 555581) then
                    attnChannel = _G["CHAT_CHANNEL_GUILD_" .. tostring(i)]
                end
            end
        end

        if (KD.savedOptions.general.experimental) then
            -- Stop moving when tabbing back in
            EVENT_MANAGER:RegisterForEvent(KD.name .. "KyzergFocus", EVENT_GAME_FOCUS_CHANGED, OnFocusChanged)

            -- Put zerg guild channel in valid. This breaks if leaving or joining, but it's not like I do that often
            for i = 1, GetNumGuilds() do
                if (GetGuildId(i) == 580319) then -- FC
                    local channel = _G["CHAT_CHANNEL_GUILD_" .. tostring(i)]
                    fcChannel = channel
                    validChannels[channel] = true
                end
            end

            -- Auto accept quests from myself
            EVENT_MANAGER:RegisterForEvent(KD.name .. "KyzergQuestShared", EVENT_QUEST_SHARED, OnQuestShared)
        end

        validChannels[CHAT_CHANNEL_PARTY] = KD.savedOptions.kyzerg.group
    end

    if (not IsPlayerJWPD2()) then
        SLASH_COMMANDS["/kjwpd2"] = nil
    end
end
-- /script KyzderpsDerps.savedOptions.kyzerg.group = true KyzderpsDerps.Sync.Kyzerg.Initialize()

SLASH_COMMANDS["/kmount"] = KMount
SLASH_COMMANDS["/kjwpd2"] = KJWPD2
