AutoAcceptQ = AutoAcceptQ or {}
local AAQ = AutoAcceptQ

AAQ.name = "AutoAcceptQ"
AAQ.displayName = "AutoAcceptQ"
AAQ.version = "1.3.0"

AAQ.defaults = {
    enabled        = true,
    dungeons       = true,  -- Normal / Veteran dungeon finder
    battlegrounds  = true,  -- All battleground queues
    cyrodiil       = true,  -- Cyrodiil campaign entry
    imperialCity   = true,  -- Imperial City campaign entry
    jerallPass     = true,  -- Jerall Pass campaign entry
    tribute        = false, -- Tales of Tribute matchmaking
    other          = false, -- Any other group-finder activity
    delay          = 20,    -- Seconds to wait before accepting
    announce       = true,  -- Center-screen "accepting in X seconds" warning
    chatMessages   = true,
    settingsVersion = 2,
}

-- Maps LFG_ACTIVITY_* values to a setting key; built from globals so new
-- activity types added by ZOS are picked up automatically.
local activityKind = {}
-- Maps CAMPAIGN_RULESET_TYPE_* values to a setting key.
local campaignKindByRuleset = {}

-- Which PvP zone a constant / campaign name refers to.
local function PvpKindFromName(name)
    name = zo_strupper(name)
    if name:find("JERALL") then return "jerallPass" end
    if name:find("IMPERIAL") then return "imperialCity" end
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
                activityKind[value] = pvpKind
            elseif name:find("BATTLE_GROUND") or name:find("BATTLEGROUND") then
                activityKind[value] = "battlegrounds"
            elseif name:find("TRIBUTE") then
                activityKind[value] = "tribute"
            elseif name:find("DUNGEON") then
                activityKind[value] = "dungeons"
            elseif name:find("AVA") then
                activityKind[value] = "cyrodiil"
            elseif name ~= "LFG_ACTIVITY_INVALID" and not name:find("_MIN_VALUE$") and not name:find("_MAX_VALUE$")
                   and not name:find("ITERATION") then
                activityKind[value] = "other"
            end
        end
    end
end

local KIND_LABEL = {
    dungeons      = "Dungeon",
    battlegrounds = "Battleground",
    cyrodiil      = "Cyrodiil",
    imperialCity  = "Imperial City",
    jerallPass    = "Jerall Pass",
    tribute       = "Tales of Tribute",
    other         = "Activity",
}

function AAQ.Msg(text)
    if AAQ.sv and AAQ.sv.chatMessages and CHAT_ROUTER then
        CHAT_ROUTER:AddSystemMessage("|c66CCFF[AutoAcceptQ]|r " .. text)
    end
end

local function CanAccept()
    if not AAQ.sv.enabled then return false end
    return true
end

local function Announce(text)
    if not (AAQ.sv.announce and CENTER_SCREEN_ANNOUNCE) then return end
    pcall(function()
        local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.DEFAULT_CLICK)
        params:SetText(text)
        params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_SYSTEM_BROADCAST)
        params:SetLifespanMS(4000)
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
    end)
end

-- Waits the configured delay (capped so it never outlasts the prompt's own
-- timer), telling the player how long until it accepts, then runs fn.
local function Schedule(id, label, secondsLeftOnPrompt, fn)
    local seconds = zo_max(0, AAQ.sv.delay or 0)
    if type(secondsLeftOnPrompt) == "number" and secondsLeftOnPrompt > 0 then
        seconds = zo_min(seconds, zo_max(0, zo_floor(secondsLeftOnPrompt) - 3))
    end

    EVENT_MANAGER:UnregisterForUpdate(AAQ.name .. id)
    if seconds == 0 then
        fn()
        return
    end

    local text = zo_strformat("<<1>> queue popped! Auto-accepting in <<2>> seconds.", label, seconds)
    Announce(text)
    AAQ.Msg(text)
    EVENT_MANAGER:RegisterForUpdate(AAQ.name .. id, seconds * 1000, function()
        EVENT_MANAGER:UnregisterForUpdate(AAQ.name .. id)
        fn()
    end)
end

-- Calls a game function, going through CallSecureProtected if the game
-- treats it as protected (protected functions are blocked in combat otherwise).
local function SafeCall(funcName, ...)
    if IsProtectedFunction and IsProtectedFunction(funcName) and CallSecureProtected then
        return CallSecureProtected(funcName, ...)
    end
    return _G[funcName](...)
end

-- Accepts, then keeps retrying once a second while the prompt is still up
-- (covers the game ignoring the first attempt, e.g. during combat).
local RETRY_MS, MAX_RETRIES = 1000, 15
local function AcceptWithRetry(id, isPending, accept)
    local updateName = AAQ.name .. "Retry" .. id
    local tries = 0
    accept()
    EVENT_MANAGER:UnregisterForUpdate(updateName)
    EVENT_MANAGER:RegisterForUpdate(updateName, RETRY_MS, function()
        tries = tries + 1
        if not isPending() or not AAQ.sv.enabled or tries > MAX_RETRIES then
            EVENT_MANAGER:UnregisterForUpdate(updateName)
            return
        end
        accept()
    end)
end

---------------------------------------------------------------------------
-- Group finder ready checks (dungeons, battlegrounds, tribute, ...)
---------------------------------------------------------------------------
local lfgHandled = false

local function GetReadyCheckKind()
    local activityType = GetLFGReadyCheckNotificationInfo and GetLFGReadyCheckNotificationInfo()
    return activityType and activityKind[activityType] or "other", activityType
end

local function TryAcceptReadyCheck()
    if not HasLFGReadyCheckNotification() then
        lfgHandled = false
        return
    end
    if lfgHandled or not CanAccept() then return end

    local kind = GetReadyCheckKind()
    if not AAQ.sv[kind] then return end

    lfgHandled = true
    local _, _, secondsLeft = GetLFGReadyCheckNotificationInfo()
    Schedule("LFG", KIND_LABEL[kind], secondsLeft, function()
        if HasLFGReadyCheckNotification() and CanAccept() then
            AcceptWithRetry("LFG", HasLFGReadyCheckNotification, function()
                SafeCall("AcceptLFGReadyCheckNotification")
            end)
            AAQ.Msg("Accepted " .. KIND_LABEL[kind] .. " ready check.")
        end
    end)
end

local function OnReadyCheckCancelled()
    lfgHandled = false
    EVENT_MANAGER:UnregisterForUpdate(AAQ.name .. "LFG")
end

local function OnActivityFinderStatus(_, status)
    if status == ACTIVITY_FINDER_STATUS_READY_CHECK then
        TryAcceptReadyCheck()
    else
        OnReadyCheckCancelled()
    end
end

---------------------------------------------------------------------------
-- Campaign queue (Cyrodiil / Imperial City "Enter campaign?" prompt)
---------------------------------------------------------------------------
local campaignHandled = {}

-- Cyrodiil, Imperial City or Jerall Pass.
local function GetCampaignKind(campaignId)
    if GetCampaignRulesetId and GetCampaignRulesetType then
        local kind = campaignKindByRuleset[GetCampaignRulesetType(GetCampaignRulesetId(campaignId))]
        if kind then return kind end
    end
    local name = GetCampaignName(campaignId) or ""
    return PvpKindFromName((name:gsub("%s+", "_"))) or "cyrodiil"
end

local function CampaignKey(campaignId, isGroup)
    return tostring(campaignId) .. (isGroup and "g" or "s")
end

local function TryConfirmCampaign(campaignId, isGroup)
    local key = CampaignKey(campaignId, isGroup)
    if GetCampaignQueueState(campaignId, isGroup) ~= CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then
        campaignHandled[key] = nil
        return
    end
    local kind = GetCampaignKind(campaignId)
    if campaignHandled[key] or not CanAccept() or not AAQ.sv[kind] then return end

    campaignHandled[key] = true
    local secondsLeft = GetCampaignQueueRemainingConfirmationSeconds
                        and GetCampaignQueueRemainingConfirmationSeconds(campaignId, isGroup)
    Schedule("Campaign" .. key, KIND_LABEL[kind], secondsLeft, function()
        if GetCampaignQueueState(campaignId, isGroup) == CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING and CanAccept() then
            AcceptWithRetry("Campaign" .. key, function()
                return GetCampaignQueueState(campaignId, isGroup) == CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING
            end, function()
                SafeCall("ConfirmCampaignEntry", campaignId, isGroup, true)
            end)
            AAQ.Msg("Entering " .. KIND_LABEL[kind] .. ": " .. zo_strformat("<<1>>", GetCampaignName(campaignId)))
        end
    end)
end

local function OnCampaignQueueStateChanged(_, campaignId, isGroup, state)
    if state == CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then
        TryConfirmCampaign(campaignId, isGroup)
    else
        campaignHandled[CampaignKey(campaignId, isGroup)] = nil
    end
end

local function CheckAllCampaigns()
    for i = 1, GetNumCampaignQueueEntries() do
        local campaignId, isGroup = GetCampaignQueueEntry(i)
        if campaignId then TryConfirmCampaign(campaignId, isGroup) end
    end
end

-- Re-check anything already waiting (e.g. after a setting is turned on).
function AAQ.CheckPending()
    lfgHandled = false
    ZO_ClearTable(campaignHandled)
    TryAcceptReadyCheck()
    CheckAllCampaigns()
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
local function OnAddOnLoaded(_, addonName)
    if addonName ~= AAQ.name then return end
    EVENT_MANAGER:UnregisterForEvent(AAQ.name, EVENT_ADD_ON_LOADED)

    AAQ.sv = ZO_SavedVars:NewAccountWide("AutoAcceptQ_SV", 1, nil, AAQ.defaults)
    AAQ.sv.skipInCombat = nil -- option removed in 1.2.0
    if (AAQ.sv.settingsVersion or 1) < 2 then
        AAQ.sv.delay = 20 -- new 20 second default
        AAQ.sv.settingsVersion = 2
    end
    BuildActivityKinds()

    local em = EVENT_MANAGER
    em:RegisterForEvent(AAQ.name, EVENT_ACTIVITY_FINDER_STATUS_UPDATE, OnActivityFinderStatus)
    em:RegisterForEvent(AAQ.name, EVENT_GROUPING_TOOLS_READY_CHECK_UPDATED, TryAcceptReadyCheck)
    em:RegisterForEvent(AAQ.name, EVENT_GROUPING_TOOLS_READY_CHECK_CANCELLED, OnReadyCheckCancelled)
    em:RegisterForEvent(AAQ.name, EVENT_CAMPAIGN_QUEUE_STATE_CHANGED, OnCampaignQueueStateChanged)
    em:RegisterForEvent(AAQ.name, EVENT_PLAYER_ACTIVATED, AAQ.CheckPending)

    SLASH_COMMANDS["/aaq"] = function(arg)
        arg = zo_strlower(zo_strtrim(arg or ""))
        if arg == "on" then
            AAQ.sv.enabled = true
        elseif arg == "off" then
            AAQ.sv.enabled = false
        else
            AAQ.sv.enabled = not AAQ.sv.enabled
        end
        CHAT_ROUTER:AddSystemMessage("|c66CCFF[AutoAcceptQ]|r " .. (AAQ.sv.enabled and "Enabled" or "Disabled"))
        if AAQ.sv.enabled then AAQ.CheckPending() end
    end

    AAQ.BuildSettings()
end

EVENT_MANAGER:RegisterForEvent(AAQ.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
