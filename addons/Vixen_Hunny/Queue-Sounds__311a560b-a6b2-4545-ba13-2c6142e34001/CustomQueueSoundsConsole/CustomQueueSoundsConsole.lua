-- Custom Queue Sounds (Console)
--
-- Console addons can't ship audio files or talk to outside programs, so this
-- version repeats one of the game's own sounds while a group finder ready
-- check (dungeon OR battleground) or a Cyrodiil "Enter campaign?" prompt is
-- waiting for you. It stops the moment you accept or decline (or the popup
-- closes for any other reason).

local ADDON_NAME = "CustomQueueSoundsConsole"
local POLL_MS = 250

-- Built-in sounds offered in the menu. Any that don't exist on this client
-- version are skipped automatically.
local SOUND_CHOICES = {
    { name = "Duel Invite",         key = "DUEL_INVITE_RECEIVED" },
    { name = "Duel Start",          key = "DUEL_START" },
    { name = "Group Invite",        key = "GROUP_INVITE" },
    { name = "Notification",        key = "NEW_NOTIFICATION" },
    { name = "Level Up",            key = "LEVEL_UP" },
    { name = "Achievement",         key = "ACHIEVEMENT_AWARDED" },
    { name = "Quest Complete",      key = "QUEST_COMPLETED" },
    { name = "Skill Gained",        key = "SKILL_GAINED" },
    { name = "Champion Point",      key = "CHAMPION_POINTS_COMMITTED" },
    { name = "Cyrodiil Gate Open",  key = "AVA_GATE_OPENED" },
    { name = "Error Alert",         key = "GENERAL_ALERT_ERROR" },
}

-- Icon + label shown on the message for each kind of queue.
local QUEUE_KINDS = {
    dungeon      = { label = "Dungeon",      icon = "EsoUI/Art/LFG/LFG_indexIcon_dungeon_up.dds" },
    battleground = { label = "Battleground", icon = "EsoUI/Art/LFG/LFG_indexIcon_battlegrounds_up.dds" },
    tribute      = { label = "Tales of Tribute", icon = "EsoUI/Art/LFG/LFG_indexIcon_tribute_up.dds" },
    cyrodiil     = { label = "Cyrodiil",     icon = "EsoUI/Art/MainMenu/menuBar_ava_up.dds" },
    imperialcity = { label = "Imperial City", icon = "EsoUI/Art/MainMenu/menuBar_ava_up.dds" },
    jerall       = { label = "Jerall Pass",  icon = "EsoUI/Art/MainMenu/menuBar_ava_up.dds" },
    other        = { label = "Group Finder", icon = nil },
}
local ICON_SIZE = 64
local ROLE_ICON_SIZE = 32

-- Role icons (same art the group frames use).
local ROLE_ICONS = {
    [LFG_ROLE_TANK] = "EsoUI/Art/LFG/LFG_icon_tank.dds",
    [LFG_ROLE_HEAL] = "EsoUI/Art/LFG/LFG_icon_healer.dds",
    [LFG_ROLE_DPS]  = "EsoUI/Art/LFG/LFG_icon_dps.dds",
}
local ROLE_FALLBACK_NAMES = {
    [LFG_ROLE_TANK] = "Tank",
    [LFG_ROLE_HEAL] = "Healer",
    [LFG_ROLE_DPS]  = "Damage",
}

local defaults = {
    sound = "Duel Invite",
    intervalSeconds = 2,
    showBanner = true,
    bannerText = "Queue Ready!",
    bannerRepeat = true,
    bannerIntervalSeconds = 4,
    showQueueType = true,
    showRole = true,
    showActivityName = true,
    alertCyrodiil = true,
}

local sv
local ringing = false
local testMode = false
local testKind = "dungeon"
local activityKindByValue = {}   -- LFG_ACTIVITY_* value -> "dungeon" / "battleground" / ...
local campaignKindByRuleset = {} -- CAMPAIGN_RULESET_TYPE_* value -> "cyrodiil" / "imperialcity" / "jerall"
local lastPlayed = 0
local lastBanner = 0
local available = {}      -- filtered SOUND_CHOICES that exist on this client

local function Msg(text)
    if CHAT_ROUTER then
        CHAT_ROUTER:AddSystemMessage("[Queue Sounds] " .. text)
    else
        d("[Queue Sounds] " .. text)
    end
end

local function GetSoundId(choiceName)
    for _, c in ipairs(available) do
        if c.name == choiceName then return SOUNDS[c.key] end
    end
    return available[1] and SOUNDS[available[1].key]
end

local function PlayChosenSound()
    local id = GetSoundId(sv.sound)
    if id then PlaySound(id) end
end

-- True while a ready-check popup is up that the player has NOT yet answered.
local function IsReadyCheckPending()
    if HasLFGReadyCheckNotification then
        return HasLFGReadyCheckNotification() == true
    end
    return GetActivityFinderStatus and GetActivityFinderStatus() == ACTIVITY_FINDER_STATUS_READY_CHECK
end

-- Sort every LFG_ACTIVITY_* constant the client has into a queue kind by its
-- name, so new battleground/dungeon activity types are picked up automatically.
-- Matches a constant's name to one of the PvP zone kinds, or nil.
local function PvpKindFromName(name)
    if name:find("JERALL") then return "jerall" end
    if name:find("IMPERIAL") then return "imperialcity" end
    if name:find("CYRODIIL") then return "cyrodiil" end
    return nil
end

local function BuildActivityKinds()
    local iter = zo_insecurePairs or pairs
    for name, value in iter(_G) do
        if type(name) == "string" and type(value) == "number" and name:find("^CAMPAIGN_RULESET_TYPE_") then
            campaignKindByRuleset[value] = PvpKindFromName(name)
        end
        if type(name) == "string" and type(value) == "number" and name:find("^LFG_ACTIVITY_") then
            local pvpKind = PvpKindFromName(name)
            if pvpKind then
                -- In case any of these zones are queued through the group finder.
                activityKindByValue[value] = pvpKind
            elseif name:find("BATTLE_GROUND") or name:find("BATTLEGROUND") then
                activityKindByValue[value] = "battleground"
            elseif name:find("DUNGEON") then
                activityKindByValue[value] = "dungeon"
            elseif name:find("TRIBUTE") then
                activityKindByValue[value] = "tribute"
            end
        end
    end
end

local function GetReadyCheckActivityType()
    if GetLFGReadyCheckNotificationInfo then
        return (GetLFGReadyCheckNotificationInfo())
    end
end

-- Cyrodiil campaign queue: returns campaignId, isGroup while the "enter
-- campaign" prompt is waiting for you, otherwise nil.
local function GetConfirmingCampaign()
    if not (sv.alertCyrodiil and GetNumCampaignQueueEntries and GetCampaignQueueEntry and GetCampaignQueueState) then
        return nil
    end
    for i = 1, GetNumCampaignQueueEntries() do
        local campaignId, isGroup = GetCampaignQueueEntry(i)
        if campaignId and GetCampaignQueueState(campaignId, isGroup) == CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then
            return campaignId, isGroup
        end
    end
    return nil
end

local function IsAnythingPending()
    return IsReadyCheckPending() or GetConfirmingCampaign() ~= nil
end

-- Which PvP zone a campaign is for: Cyrodiil, Imperial City or Jerall Pass.
local function GetCampaignKind(campaignId)
    if GetCampaignRulesetId and GetCampaignRulesetType then
        local kind = campaignKindByRuleset[GetCampaignRulesetType(GetCampaignRulesetId(campaignId))]
        if kind then return kind end
    end
    -- Fallback: look at the campaign's name.
    local name = GetCampaignName and zo_strupper(GetCampaignName(campaignId) or "") or ""
    return PvpKindFromName(name:gsub("%s+", "_")) or "cyrodiil"
end

local function GetQueueKind()
    if testMode then return testKind end
    if IsReadyCheckPending() then
        return activityKindByValue[GetReadyCheckActivityType()] or "other"
    end
    local campaignId = GetConfirmingCampaign()
    if campaignId then return GetCampaignKind(campaignId) end
    return "other"
end

-- Name of the activity you queued for that matches this ready check, e.g.
-- "Random Veteran Dungeon", "Fungal Grotto I" or the battleground queue name.
-- If you queued several specific dungeons at once, the game doesn't say which
-- one popped, so we say how many it could be instead.
local TEST_ACTIVITY_NAMES = { dungeon = "Fungal Grotto I", battleground = "Group Battleground", cyrodiil = "Gray Host",
                              imperialcity = "Imperial City", jerall = "Jerall Pass" }
local PVP_KINDS = { cyrodiil = true, imperialcity = true, jerall = true }

local function GetActivityLabel()
    if testMode then return TEST_ACTIVITY_NAMES[testKind] end

    if not IsReadyCheckPending() then
        local campaignId, isGroup = GetConfirmingCampaign()
        if campaignId and GetCampaignName then
            local name = zo_strformat("<<1>>", GetCampaignName(campaignId))
            if isGroup then name = name .. " (Group)" end
            return name
        end
        return nil
    end

    if not (GetNumActivityRequests and GetActivityRequestIds and GetActivityName) then return nil end

    local readyType = GetReadyCheckActivityType()
    local names = {}
    for i = 1, GetNumActivityRequests() do
        local activityId = GetActivityRequestIds(i)
        if activityId and activityId ~= 0 then
            local sameType = not (readyType and GetActivityType) or GetActivityType(activityId) == readyType
            if sameType then
                local name = GetActivityName(activityId)
                if name and name ~= "" then names[#names + 1] = zo_strformat("<<1>>", name) end
            end
        end
    end

    if #names == 1 then return names[1] end
    if #names > 1 then return zo_strformat("One of <<1>> queued activities", #names) end
    return nil
end

-- The role the ready check is offering you (tank / healer / damage), or nil.
local function GetQueuedRole()
    local role
    if testMode then
        if PVP_KINDS[testKind] then return nil end -- PvP campaigns have no roles
        role = GetSelectedLFGRole and GetSelectedLFGRole() or LFG_ROLE_DPS
    elseif IsReadyCheckPending() and GetLFGReadyCheckNotificationInfo then
        local _, playerRole = GetLFGReadyCheckNotificationInfo()
        role = playerRole
    end
    if role and ROLE_ICONS[role] then return role end
    return nil
end

local function FormatRole(role)
    local name = GetString("SI_LFGROLE", role)
    if not name or name == "" then name = ROLE_FALLBACK_NAMES[role] end
    return zo_iconTextFormat(ROLE_ICONS[role], ROLE_ICON_SIZE, ROLE_ICON_SIZE, name)
end

local function ShowBanner()
    if not (sv.showBanner and CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.CreateMessageParams) then return end
    local text = zo_strtrim(sv.bannerText or "")
    if text == "" then text = defaults.bannerText end
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)

    -- Second line: "Dungeon  -  [icon] Tank" (each part can be turned off).
    local parts = {}
    local kindKey = GetQueueKind()
    if sv.showQueueType then
        local kind = QUEUE_KINDS[kindKey] or QUEUE_KINDS.other
        if kind.icon then
            text = zo_iconTextFormatNoSpace(kind.icon, ICON_SIZE, ICON_SIZE, "") .. " " .. text
        end
        parts[#parts + 1] = kind.label
    end
    if sv.showActivityName then
        local activity = GetActivityLabel()
        local kindLabel = (QUEUE_KINDS[kindKey] or QUEUE_KINDS.other).label
        if activity and activity ~= kindLabel then
            if sv.showQueueType and not PVP_KINDS[kindKey] then
                -- Replace the plain "Dungeon"/"Battleground" label with the real name.
                parts[#parts] = activity
            else
                -- PvP: keep "Imperial City" etc. and add the campaign name after it.
                parts[#parts + 1] = activity
            end
        end
    end
    if sv.showRole then
        local role = GetQueuedRole()
        if role then parts[#parts + 1] = FormatRole(role) end
    end

    if #parts > 0 then
        params:SetText(text, table.concat(parts, "  -  "))
    else
        params:SetText(text)
    end
    params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_LARGE_TEXT)
    if sv.bannerRepeat and params.SetLifespanMS then
        -- Keep each banner shorter than the repeat gap so they don't pile up
        -- in the queue and keep showing after you've answered.
        params:SetLifespanMS(math.max(1000, sv.bannerIntervalSeconds * 1000 - 300))
    end
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
end

local RESPOND_GRACE_MS = 3000
local suppressUntil = 0

local Update -- forward declaration

local function SetRinging(on)
    if on == ringing then return end
    ringing = on
    if on then
        lastPlayed = 0
        lastBanner = GetFrameTimeMilliseconds()
        ShowBanner()
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Poll", POLL_MS, Update)
    else
        EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "Poll")
    end
end

Update = function()
    local inGrace = GetFrameTimeMilliseconds() < suppressUntil
    SetRinging(testMode or (not inGrace and IsAnythingPending()))
    if not ringing then return end
    local now = GetFrameTimeMilliseconds()
    if now - lastPlayed >= sv.intervalSeconds * 1000 then
        lastPlayed = now
        PlayChosenSound()
    end
    if sv.bannerRepeat and now - lastBanner >= sv.bannerIntervalSeconds * 1000 then
        lastBanner = now
        ShowBanner()
    end
end

local function OnResponded()
    testMode = false
    SetRinging(false)
    -- Give the server a moment to clear the popup so we don't restart the
    -- alert, then check again in case another popup is still waiting
    -- (e.g. a dungeon pop AND a Cyrodiil pop at once).
    suppressUntil = GetFrameTimeMilliseconds() + RESPOND_GRACE_MS
    zo_callLater(Update, RESPOND_GRACE_MS + 100)
end

local function ToggleTest(kind)
    if testMode and kind and kind ~= testKind then
        -- Switching test type while one is running: restart with the new type.
        testMode = false
        Update()
    end
    testKind = kind or testKind
    testMode = not testMode
    Update()
    return testMode
end

local function BuildSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = ADDON_NAME .. "Panel"
    LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "Custom Queue Sounds",
        author = "Vixen Hunny",
        version = "1.0.0",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local choices = {}
    for _, c in ipairs(available) do choices[#choices + 1] = c.name end

    LAM:RegisterOptionControls(panelName, {
        {
            type = "dropdown",
            name = "Alert Sound",
            tooltip = "The game sound that repeats while the queue popup is waiting for you.",
            choices = choices,
            getFunc = function() return sv.sound end,
            setFunc = function(name)
                sv.sound = name
                PlayChosenSound()
            end,
            default = defaults.sound,
        },
        {
            type = "slider",
            name = "Repeat Every (seconds)",
            tooltip = "How often the sound plays while the popup is up.",
            min = 1, max = 10, step = 1,
            getFunc = function() return sv.intervalSeconds end,
            setFunc = function(v) sv.intervalSeconds = math.max(1, math.min(10, math.floor(v + 0.5))) end,
            default = defaults.intervalSeconds,
        },
        {
            type = "checkbox",
            name = "Alert for Cyrodiil / Imperial City / Jerall Pass",
            tooltip = "Also alert when a PvP campaign queue pops (the \"Enter campaign?\" prompt).",
            getFunc = function() return sv.alertCyrodiil end,
            setFunc = function(v) sv.alertCyrodiil = v; Update() end,
            default = defaults.alertCyrodiil,
        },
        {
            type = "header",
            name = "On-Screen Message",
        },
        {
            type = "checkbox",
            name = "Show Message",
            tooltip = "Show a big message on screen when the queue pops.",
            getFunc = function() return sv.showBanner end,
            setFunc = function(v) sv.showBanner = v end,
            default = defaults.showBanner,
        },
        {
            type = "editbox",
            name = "Message Text",
            tooltip = "What the on-screen message says.",
            getFunc = function() return sv.bannerText end,
            setFunc = function(v) sv.bannerText = v end,
            isMultiline = false,
            disabled = function() return not sv.showBanner end,
            default = defaults.bannerText,
        },
        {
            type = "checkbox",
            name = "Repeat Message",
            tooltip = "Keep showing the message until you accept or decline.",
            getFunc = function() return sv.bannerRepeat end,
            setFunc = function(v) sv.bannerRepeat = v end,
            disabled = function() return not sv.showBanner end,
            default = defaults.bannerRepeat,
        },
        {
            type = "slider",
            name = "Repeat Message Every (seconds)",
            tooltip = "How often the message shows again while the popup is up.",
            min = 2, max = 15, step = 1,
            getFunc = function() return sv.bannerIntervalSeconds end,
            setFunc = function(v) sv.bannerIntervalSeconds = math.max(2, math.min(15, math.floor(v + 0.5))) end,
            disabled = function() return not (sv.showBanner and sv.bannerRepeat) end,
            default = defaults.bannerIntervalSeconds,
        },
        {
            type = "checkbox",
            name = "Show Queue Type Icon",
            tooltip = "Put a dungeon or battleground icon on the message, with the queue type underneath.",
            getFunc = function() return sv.showQueueType end,
            setFunc = function(v) sv.showQueueType = v end,
            disabled = function() return not sv.showBanner end,
            default = defaults.showQueueType,
        },
        {
            type = "checkbox",
            name = "Show Activity Name",
            tooltip = "Show what you queued for (e.g. the dungeon name, or Random Veteran Dungeon) instead of just \"Dungeon\" / \"Battleground\".",
            getFunc = function() return sv.showActivityName end,
            setFunc = function(v) sv.showActivityName = v end,
            disabled = function() return not sv.showBanner end,
            default = defaults.showActivityName,
        },
        {
            type = "checkbox",
            name = "Show Queued Role",
            tooltip = "Show the role you were queued as (tank, healer or damage) under the message.",
            getFunc = function() return sv.showRole end,
            setFunc = function(v) sv.showRole = v end,
            disabled = function() return not sv.showBanner end,
            default = defaults.showRole,
        },
        {
            type = "header",
            name = "Test",
        },
        {
            type = "button",
            name = "Test Dungeon Pop",
            tooltip = "Start or stop the alert as if a dungeon queue had popped.",
            func = function() ToggleTest("dungeon") end,
        },
        {
            type = "button",
            name = "Test Battleground Pop",
            tooltip = "Start or stop the alert as if a battleground queue had popped.",
            func = function() ToggleTest("battleground") end,
        },
        {
            type = "button",
            name = "Test Cyrodiil Pop",
            tooltip = "Start or stop the alert as if your Cyrodiil campaign queue had popped.",
            func = function() ToggleTest("cyrodiil") end,
        },
        {
            type = "button",
            name = "Test Imperial City Pop",
            tooltip = "Start or stop the alert as if your Imperial City queue had popped.",
            func = function() ToggleTest("imperialcity") end,
        },
        {
            type = "button",
            name = "Test Jerall Pass Pop",
            tooltip = "Start or stop the alert as if your Jerall Pass queue had popped.",
            func = function() ToggleTest("jerall") end,
        },
    })
end

local function OnLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("CustomQueueSoundsConsoleSV", 1, nil, defaults)

    for _, c in ipairs(SOUND_CHOICES) do
        if SOUNDS[c.key] then available[#available + 1] = c end
    end

    local function OnEvent() Update() end
    for _, ev in ipairs({
        EVENT_ACTIVITY_FINDER_STATUS_UPDATE,
        EVENT_GROUPING_TOOLS_READY_CHECK_UPDATED,
        EVENT_GROUPING_TOOLS_READY_CHECK_CANCELLED,
        EVENT_CAMPAIGN_QUEUE_STATE_CHANGED,
        EVENT_CAMPAIGN_QUEUE_JOINED,
        EVENT_CAMPAIGN_QUEUE_LEFT,
        EVENT_PLAYER_ACTIVATED,
    }) do
        if ev then
            EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. tostring(ev), ev, OnEvent)
        end
    end

    if AcceptLFGReadyCheckNotification then
        SecurePostHook("AcceptLFGReadyCheckNotification", OnResponded)
    end
    if DeclineLFGReadyCheckNotification then
        SecurePostHook("DeclineLFGReadyCheckNotification", OnResponded)
    end
    -- Cyrodiil "Enter campaign?" prompt: Accept and Decline both call this.
    if ConfirmCampaignEntry then
        SecurePostHook("ConfirmCampaignEntry", OnResponded)
    end

    BuildActivityKinds()

    -- /cqs = test dungeon pop, /cqs bg = test battleground pop. Same again stops it.
    SLASH_COMMANDS["/cqs"] = function(arg)
        arg = zo_strlower(zo_strtrim(arg or ""))
        local kind = "dungeon"
        if arg == "bg" or arg == "battleground" then kind = "battleground"
        elseif arg == "cyro" or arg == "cyrodiil" then kind = "cyrodiil"
        elseif arg == "ic" or arg == "imperial" then kind = "imperialcity"
        elseif arg == "jerall" or arg == "jp" then kind = "jerall" end
        Msg(ToggleTest(kind) and ("Test ON (" .. QUEUE_KINDS[kind].label .. ") - type /cqs again to stop.")
                             or "Test OFF.")
    end

    BuildSettings()
    Update()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnLoaded)
