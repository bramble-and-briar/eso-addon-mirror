local ME = MyExtras
local CT = {}
ME.ChatTravel = CT

--------------------------------------------------
-- Eligibility Checks
--------------------------------------------------
local function GetLiveSocialData()
    local list = CHAT_MENU_GAMEPAD.list
    if not list then return nil end

    local ok, targetData = pcall(function() return list:GetTargetData() end)
    if not ok or not targetData then return nil end

    local entry = targetData.data or targetData
    if not entry or not entry.fromDisplayName then return nil end

    return {
        displayName   = entry.fromDisplayName,
        category      = entry.category,
        targetChannel = entry.targetChannel,
    }
end

local function IsCurrentGroupMember(displayName)
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and GetUnitDisplayName(tag) == displayName then
            return true
        end
    end
    return false
end

local function IsFriendJumpable()
    local data = GetLiveSocialData()
    if not data or not data.displayName then return false end
    return IsFriend(data.displayName)
end

local function IsGroupJumpable()
    if IsFriendJumpable() then return false end
    local data = GetLiveSocialData()
    if not data or not data.category then return false end
    return data.category == CHAT_CATEGORY_PARTY
        and IsCurrentGroupMember(data.displayName)
end

local function IsGuildJumpable()
    if IsFriendJumpable() then return false end
    local data = GetLiveSocialData()
    if not data or not data.category then return false end
    local cat = data.category
    return cat == CHAT_CATEGORY_GUILD_1   or cat == CHAT_CATEGORY_GUILD_2   or
           cat == CHAT_CATEGORY_GUILD_3   or cat == CHAT_CATEGORY_GUILD_4   or
           cat == CHAT_CATEGORY_GUILD_5   or
           cat == CHAT_CATEGORY_OFFICER_1 or cat == CHAT_CATEGORY_OFFICER_2 or
           cat == CHAT_CATEGORY_OFFICER_3 or cat == CHAT_CATEGORY_OFFICER_4 or
           cat == CHAT_CATEGORY_OFFICER_5
end

local function IsTypingInChat()
    local focalArea = CHAT_MENU_GAMEPAD.chatEntryPanelFocalArea
    if not focalArea then return false end
    return not focalArea:IsFocused()
end

local function IsAnyJumpable()
    if IsTypingInChat() then return false end
    if not GetLiveSocialData() then return false end
    return IsFriendJumpable() or IsGuildJumpable() or IsGroupJumpable()
end

--------------------------------------------------
-- Travel Attempt
--------------------------------------------------
local activeCancel = nil
local attemptId = 0

local function FireJump(displayName, isGroup, isFriend, isGuild)
    if isGroup then
        JumpToGroupMember(displayName)
    elseif isFriend then
        JumpToFriend(displayName)
    elseif isGuild then
        JumpToGuildMember(displayName)
    end
end

local function AttemptTravel(displayName, isGroup, isFriend, isGuild)
    if activeCancel then activeCancel() end
    attemptId = attemptId + 1
    local id = attemptId

    local prepareName = "MyExtras_ChatTravel_Prepare_" .. id
    local activName   = "MyExtras_ChatTravel_Activ_"   .. id
    local deactivName = "MyExtras_ChatTravel_Deactiv_" .. id
    local socialName  = "MyExtras_ChatTravel_Social_"  .. id

    local done = false
    local cancel

    local function cleanup()
        EVENT_MANAGER:UnregisterForEvent(prepareName, EVENT_PREPARE_FOR_JUMP)
        EVENT_MANAGER:UnregisterForEvent(activName,   EVENT_PLAYER_ACTIVATED)
        EVENT_MANAGER:UnregisterForEvent(deactivName, EVENT_PLAYER_DEACTIVATED)
        EVENT_MANAGER:UnregisterForEvent(socialName,  EVENT_SOCIAL_ERROR)
        if activeCancel == cancel then activeCancel = nil end
    end

    cancel = function()
        done = true
        cleanup()
    end
    activeCancel = cancel

    EVENT_MANAGER:RegisterForEvent(prepareName, EVENT_PREPARE_FOR_JUMP, function()
        if done then return end
        done = true
        cleanup()
    end)

    EVENT_MANAGER:RegisterForEvent(activName, EVENT_PLAYER_ACTIVATED, function()
        if done then return end
        done = true
        cleanup()
    end)

    EVENT_MANAGER:RegisterForEvent(deactivName, EVENT_PLAYER_DEACTIVATED, function()
        if done then return end
        done = true
        cleanup()
    end)

    EVENT_MANAGER:RegisterForEvent(socialName, EVENT_SOCIAL_ERROR, function(_, errorCode)
        if done then return end
        done = true
        cleanup()
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
            string.format("Could not travel to %s.", displayName))
    end)

    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, string.format("Traveling to %s...", displayName))
    FireJump(displayName, isGroup, isFriend, isGuild)
end

--------------------------------------------------
-- Chat Menu Keybind
--------------------------------------------------
local CHAT_TRAVEL_KEYBIND_DESCRIPTOR = nil
local keybindBuilt = false

local function BuildKeybindDescriptor()
    CHAT_TRAVEL_KEYBIND_DESCRIPTOR = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            name = "Travel To",
            keybind = "UI_SHORTCUT_QUINARY",
            order = 10000,
            enabled = function()
                return IsAnyJumpable()
                    and CanLeaveCurrentLocationViaTeleport()
                    and not IsUnitDead("player")
            end,
            visible = function() return IsAnyJumpable() end,
            callback = function()
                local data = GetLiveSocialData()
                if not data or not IsAnyJumpable() then
                    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, "No valid travel target.")
                    return
                end
                local displayName = data.displayName
                local isGroup  = IsGroupJumpable()
                local isFriend = IsFriendJumpable()
                local isGuild  = IsGuildJumpable()
                AttemptTravel(displayName, isGroup, isFriend, isGuild)
                SCENE_MANAGER:ShowBaseScene()
            end,
        },
    }
end

local REFRESH_TIMER_NAME = "MyExtras_ChatTravel_RefreshTimer"

local function OnChatMenuShow()
    if not keybindBuilt then
        keybindBuilt = true
        BuildKeybindDescriptor()
    end
    KEYBIND_STRIP:AddKeybindButtonGroup(CHAT_TRAVEL_KEYBIND_DESCRIPTOR)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(CHAT_TRAVEL_KEYBIND_DESCRIPTOR)

    EVENT_MANAGER:RegisterForUpdate(REFRESH_TIMER_NAME, 150, function()
        KEYBIND_STRIP:UpdateKeybindButtonGroup(CHAT_TRAVEL_KEYBIND_DESCRIPTOR)
    end)
end

local function OnChatMenuHide()
    EVENT_MANAGER:UnregisterForUpdate(REFRESH_TIMER_NAME)
    if CHAT_TRAVEL_KEYBIND_DESCRIPTOR then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(CHAT_TRAVEL_KEYBIND_DESCRIPTOR)
    end
end

--------------------------------------------------
-- Take Me There
--------------------------------------------------
local CHAT_SCENE = "gamepadChatMenu"

function CT:TakeMeThere()
    SCENE_MANAGER:Push(CHAT_SCENE)
end

--------------------------------------------------
-- Menu
--------------------------------------------------
function CT:GetOptions()
    return {
        {
            type          = "submenu",
            name          = "Chat Travel",
            icon          = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_textChat.dds",
            childrenAlign = "center",
            options       = {
                {
                    type = "button",
                    name = "Take Me There",
                    func = function() CT:TakeMeThere() end,
                },
            },
        },
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function CT:Init()
    if CHAT_MENU_GAMEPAD then
        ZO_PreHook(CHAT_MENU_GAMEPAD, "OnShow", OnChatMenuShow)
        ZO_PreHook(CHAT_MENU_GAMEPAD, "OnHide", OnChatMenuHide)
    end
end

ME:RegisterFeature(CT)
