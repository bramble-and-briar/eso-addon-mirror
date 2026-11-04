local Scout = GroupScout
local Core = Scout.Core
local NAME = "GroupScout"
local CYCLE = NAME .. "Cycle"
local TIMEOUT = NAME .. "Timeout"
local EXPIRY = NAME .. "Expiry"
local SESSION_MS = 30 * 60 * 1000
local RESPONSE_TIMEOUT_MS = 30 * 1000

local function Now() return GetFrameTimeMilliseconds() end

local function Once(name, delay, callback)
    EVENT_MANAGER:UnregisterForUpdate(name)
    EVENT_MANAGER:RegisterForUpdate(name, delay, function()
        EVENT_MANAGER:UnregisterForUpdate(name)
        callback()
    end)
end

local function Clean(text)
    text = tostring(text or "")
    text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|[cC]%x%x%x%x%x%x", "")
    text = text:gsub("|[rR]", ""):gsub("|[tT].-|[tT]", "")
    return text:gsub("|", ""):gsub("[%c]", " ")
end

function Scout:Print(message)
    local chat = CHAT_SYSTEM or (GetChatSystem and GetChatSystem())
    if chat and chat.AddMessage then
        chat:AddMessage("|c80D6A0[Group Scout]|r " .. message)
    elseif d then
        d("[Group Scout] " .. message)
    end
end

-- Read shared native filters without changing them or requesting any server data.
function Scout:FilterKey()
    local parts = { GetGroupFinderFilterCategory(), GetGroupFinderGroupFilterSearchString(),
        GetGroupFinderFilterGroupSizes(), GetGroupFinderFilterPlaystyles(),
        DoesGroupFinderFilterRequireChampion(), DoesGroupFinderFilterRequireVOIP(),
        DoesGroupFinderFilterRequireInviteCode(), DoesGroupFinderFilterAutoAcceptRequests(),
        DoesGroupFinderFilterRequireEnforceRoles(), GetGroupFinderFilterChampionPoints(),
        GetSelectedLFGRole() }
    for _, prefix in ipairs({ "Primary", "Secondary" }) do
        local count = _G["GetGroupFinderFilterNum" .. prefix .. "Options"]()
        parts[#parts + 1] = count
        for index = 1, count do
            local text, selected = _G["GetGroupFinderFilter" .. prefix .. "OptionByIndex"](index)
            parts[#parts + 1] = text
            parts[#parts + 1] = selected
        end
    end
    return Core.Pack(parts)
end

function Scout:Stop(reason)
    local wasActive = self.active
    self.active = false
    self.pendingId = nil
    for _, timer in ipairs({ CYCLE, TIMEOUT, EXPIRY }) do
        EVENT_MANAGER:UnregisterForUpdate(timer)
    end
    if wasActive and reason then self:Print("Stopped: " .. reason) end
end

function Scout:ValidateSession()
    if not self.active then return false end
    if Now() >= self.expiresAt then
        self:Stop("the 30-minute session ended. Use /gs start to search again.")
        return false
    end
    if self:FilterKey() ~= self.filters then
        self:Stop("Group Finder filters changed. Use /gs start with the new filters.")
        return false
    end
    if IsUnitGrouped("player") then
        self:Stop("you joined a group.")
        return false
    end
    return true
end

function Scout:UnavailableReason()
    if not self.worldActive then return "loading" end
    if GetUnitLevel("player") < 10 then return "character below level 10" end
    if IsActiveWorldBattleground() then return "battleground" end
    if HasGroupListingForUserType(GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING) then
        return "hosting a listing"
    end
    if not IsGroupFinderCategoryAvailable(GetGroupFinderFilterCategory()) then return "category unavailable" end
    if GetGroupFinderStatusReason() ~= GROUP_FINDER_ACTION_RESULT_SUCCESS then return "Group Finder unavailable" end
    if IsUnitInCombat("player") then return "combat" end
    if GetPlayerStatus() == PLAYER_STATUS_AWAY then return "away" end
    return nil
end

function Scout:Schedule()
    if not self.active then return end
    local delay = Core.Delay(self.intervalMs, self.consecutiveFailures, math.random)
    self.nextAt = Now() + delay
    Once(CYCLE, delay, function() self:Search() end)
end

function Scout:Failure(reason)
    if not self.active then return end
    self.pendingId = nil
    EVENT_MANAGER:UnregisterForUpdate(TIMEOUT)
    self.metrics.failures = self.metrics.failures + 1
    self.consecutiveFailures = self.consecutiveFailures + 1
    self.lastState = reason
    if self.consecutiveFailures == 1 then
        self:Print("Search failed or timed out. The next check will wait longer.")
    end
    self:Schedule()
end

function Scout:Search()
    if not self:ValidateSession() then return end
    local reason = self:UnavailableReason()
    local manager = GROUP_FINDER_SEARCH_MANAGER
    if reason or self.pendingId or IsGroupFinderSearchOnCooldown() or not manager:IsSearchStateReady() then
        self.metrics.skipped = self.metrics.skipped + 1
        self.lastState = reason or "native search busy or on cooldown"
        self:Schedule()
        return
    end

    -- Use the native manager so its current search and the standard UI agree.
    local previousId = manager.currentSearchId
    self.metrics.requests = self.metrics.requests + 1
    manager:ExecuteSearch()
    local searchId = manager.currentSearchId
    if searchId == nil or searchId == previousId then
        self:Failure("request was not accepted")
        return
    end
    self.pendingId = searchId
    self.lastState = "waiting for results"
    Once(TIMEOUT, RESPONSE_TIMEOUT_MS, function()
        if self.pendingId == searchId then self:Failure("response timeout") end
    end)
end

function Scout:ReadListings()
    local listings = {}
    for index = 1, GetGroupFinderSearchNumListings() do
        local primary, secondary = GetGroupFinderSearchListingOptionsSelectionTextByIndex(index)
        listings[#listings + 1] = {
            leader = GetGroupFinderSearchListingLeaderDisplayNameByIndex(index),
            category = GetGroupFinderSearchListingCategoryByIndex(index),
            primary = primary, secondary = secondary,
            title = GetGroupFinderSearchListingTitleByIndex(index),
        }
    end
    return listings
end

function Scout:OnResults(result, searchId)
    if not self:ValidateSession() then return end
    if searchId ~= GROUP_FINDER_SEARCH_MANAGER.currentSearchId or searchId == self.lastHandledId then return end
    if result ~= GROUP_FINDER_ACTION_RESULT_SUCCESS then
        if searchId == self.pendingId then self:Failure("server rejected the search") end
        return
    end
    self.lastHandledId = searchId
    if searchId ~= self.pendingId then self.metrics.reused = self.metrics.reused + 1 end
    self.pendingId = nil
    EVENT_MANAGER:UnregisterForUpdate(TIMEOUT)
    self.consecutiveFailures = 0
    self.metrics.responses = self.metrics.responses + 1
    self.lastState = "results received"
    local listings = self:ReadListings()
    local fresh, baseline = Core.Observe(self.tracker, listings)
    if baseline then
        self:Print(string.format("Baseline saved: %d listings. Future new listings will appear here.", #listings))
    elseif #fresh > 0 then
        self.metrics.alerts = self.metrics.alerts + #fresh
        self:Print(string.format("%d new listing(s):", #fresh))
        for index = 1, math.min(#fresh, 5) do
            local listing = fresh[index]
            self:Print(string.format("%s: %s (%s)", Clean(listing.leader), Clean(listing.title), Clean(listing.secondary)))
        end
        if #fresh > 5 then self:Print("Open Group Finder to see the remaining listings.") end
    end
    -- A manual search satisfies this cycle too; do not immediately duplicate it.
    self:Schedule()
end

function Scout:Start(minutes)
    minutes = minutes or 5
    if minutes ~= 5 and minutes ~= 10 then
        self:Print("Beta intervals are 5 or 10 minutes: /gs start 5 or /gs start 10.")
        return
    end
    if self.active then
        self:Print("Monitoring is already active. Use /gs stop before starting a new session.")
        return
    end
    if IsUnitGrouped("player") then self:Print("Leave your group before starting monitoring."); return end
    local reason = self:UnavailableReason()
    if reason then self:Print("Cannot start while " .. reason .. "."); return end
    self.active = true
    self.intervalMs = minutes * 60000
    self.expiresAt = Now() + SESSION_MS
    self.filters = self:FilterKey()
    self.tracker = Core.NewTracker()
    self.lastHandledId = nil
    self.consecutiveFailures = 0
    self.metrics = { requests = 0, responses = 0, failures = 0, skipped = 0, reused = 0, alerts = 0 }
    self.lastState = "waiting for first check"
    local delay = math.random(10000, 40000)
    self.nextAt = Now() + delay
    Once(CYCLE, delay, function() self:Search() end)
    Once(EXPIRY, SESSION_MS, function() self:Stop("the 30-minute session ended. Use /gs start to search again.") end)
    self:Print(string.format("Monitoring current filters every %d minutes plus a random delay, for 30 minutes. First check in %d seconds. /gs stop cancels.", minutes, math.floor(delay / 1000)))
end

function Scout:Status()
    if self.active then self:ValidateSession() end
    local metrics = self.metrics or { requests = 0, responses = 0, failures = 0, skipped = 0, reused = 0, alerts = 0 }
    local seconds = self.active and math.max(0, math.ceil((self.nextAt - Now()) / 1000)) or 0
    self:Print(string.format("Beta 0.1.0 | %s | next check: %ds | requests: %d | results: %d | reused: %d | failures: %d | skipped: %d | new: %d",
        self.active and (self.lastState or "active") or "off", seconds, metrics.requests,
        metrics.responses, metrics.reused, metrics.failures, metrics.skipped, metrics.alerts))
end

function Scout:Command(text)
    local command, value = string.lower(text or ""):match("^%s*(%S*)%s*(%S*)%s*$")
    if command == "start" then
        local minutes = value == "" and 5 or tonumber(value)
        if minutes ~= 5 and minutes ~= 10 then
            self:Print("Beta intervals are 5 or 10 minutes: /gs start 5 or /gs start 10.")
            return
        end
        self:Start(minutes)
        return
    end
    if command == "stop" then self:Stop("cancelled by you."); return end
    if command == "status" then self:Status(); return end
    self:Print("Select a category and filters in Group Finder, then /gs start [5|10]. /gs stop cancels; /gs status shows local request counters. Monitoring starts off after every login or reload.")
end

local function OnLoaded(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    Scout.savedVars = ZO_SavedVars:NewAccountWide("GroupScoutSavedVariables", 1, nil, {})
    Scout.active = false
    SLASH_COMMANDS["/groupscout"] = function(text) Scout:Command(text) end
    SLASH_COMMANDS["/gs"] = SLASH_COMMANDS["/groupscout"]
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
        Scout.worldActive = true
        if not Scout.announced then
            Scout.announced = true
            Scout.Announcements:Init()
            Scout:Print("Beta 0.1.0 loaded. Monitoring is off. Type /gs for help.")
        end
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEACTIVATED, function() Scout.worldActive = false end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GROUP_UPDATE, function()
        if Scout.active and IsUnitGrouped("player") then Scout:Stop("you joined a group.") end
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GROUP_FINDER_SEARCH_COMPLETE, function(_, result, searchId)
        Scout:OnResults(result, searchId)
    end)
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, OnLoaded)
