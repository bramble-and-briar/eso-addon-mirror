local ADDON_NAME = "GroupFullDante"
local MAX_GROUP_SIZE = 12
local ANNOUNCEMENT = "12/12 players - GROUP FULL (DANTE learn to count)"

local wasFull = false

local function ShowAnnouncement()
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(
        CSA_CATEGORY_LARGE_TEXT,
        SOUNDS.ACHIEVEMENT_AWARDED
    )

    params:SetText(ANNOUNCEMENT)
    params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_POI_DISCOVERED)
    params:MarkSuppressIconFrame()

    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)

    d("|cFFD700[Group Full Dante]|r " .. ANNOUNCEMENT)
end

local function CheckGroupSize()
    local size = GetGroupSize()

    if size >= MAX_GROUP_SIZE then
        if not wasFull then
            wasFull = true
            ShowAnnouncement()
        end
    else
        wasFull = false
    end
end

local function OnGroupChanged()
    zo_callLater(CheckGroupSize, 250)
end

local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_MemberJoined",
        EVENT_GROUP_MEMBER_JOINED,
        OnGroupChanged
    )

    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_MemberLeft",
        EVENT_GROUP_MEMBER_LEFT,
        OnGroupChanged
    )

    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_PlayerActivated",
        EVENT_PLAYER_ACTIVATED,
        OnGroupChanged
    )

    -- Manual test: works even while solo.
    SLASH_COMMANDS["/gfdtest"] = function()
        ShowAnnouncement()
    end

    -- Shows current group size and runs the normal group-full check.
    SLASH_COMMANDS["/gfdcheck"] = function()
        local size = GetGroupSize()
        d(string.format("|cFFD700[Group Full Dante]|r Current group size: %d/%d", size, MAX_GROUP_SIZE))
        CheckGroupSize()
    end

    d("|cFFD700[Group Full Dante]|r loaded. Use /gfdtest to test the announcement.")
end

EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_ADD_ON_LOADED,
    OnAddOnLoaded
)
