GFTracker = { name = "GFTracker", seen = {}, cursor = 0, nextSearch = 0, scans = 0 }
local A = GFTracker
local EM = EVENT_MANAGER
local defaults = {
    enabled = true, interval = 210, sound = true, screen = true, initial = true,
    onlyJoinable = false, words = "", pauseCombat = false,
    trialVet = true, trialNormal = false, dungeonVet = true, dungeonNormal = false,
    archive = true, arenaVet = false, arenaNormal = false,
    pvp = false, zone = false, adventure = false, custom = false,
}

local function Say(text) d("|cE9BD65[GF Tracker]|r " .. text) end
local function Clean(text)
    return (tostring(text or ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\r\n]", " "))
end
local function IsOwnListingActive()
    return HasGroupListingForUserType and GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING
       and HasGroupListingForUserType(GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING)
end
local function IsRestrictedGuildMember()
    for i=1,GetNumGuilds() do
        local guildId=GetGuildId(i)
        local name=guildId and GetGuildName(guildId)
        if name then
            local normalized=zo_strlower(name):gsub("[%s%p]", "")
            if normalized=="badlife" then return true end
        end
    end
    return false
end
function A:CycleSeconds() return IsRestrictedGuildMember() and 390 or 210 end
function A:Interval()
    local jobs=self:Jobs()
    return self:CycleSeconds()/math.max(1,#jobs)
end
local function Showing(fragment) return fragment and fragment:IsShowing() end
function A:IsBrowsing()
    return Showing(GROUP_FINDER_KEYBOARD_FRAGMENT)
        or (SCENE_MANAGER and (SCENE_MANAGER:IsShowing("GroupFinderGamepad")
        or SCENE_MANAGER:IsShowing("group_finder_gamepad_list")))
        or Showing(GROUP_FINDER_GAMEPAD_LIST_SCENE)
        or (ZO_Dialogs_IsShowing and (ZO_Dialogs_IsShowing("GROUP_FINDER_ADDITIONAL_FILTERS_GAMEPAD")
        or ZO_Dialogs_IsShowing("GROUP_FINDER_ADDITIONAL_FILTERS_KEYBOARD")))
end

function A:Jobs()
    local jobs = {}
    local function Add(key, category, difficulty, label)
        if self.sv[key] and category then
            jobs[#jobs + 1] = {key = key, category = category, difficulty = difficulty, label = label}
        end
    end
    Add("trialVet", GROUP_FINDER_CATEGORY_TRIAL, DUNGEON_DIFFICULTY_VETERAN, "Veteran trial")
    Add("trialNormal", GROUP_FINDER_CATEGORY_TRIAL, DUNGEON_DIFFICULTY_NORMAL, "Normal trial")
    Add("dungeonVet", GROUP_FINDER_CATEGORY_DUNGEON, DUNGEON_DIFFICULTY_VETERAN, "Veteran dungeon")
    Add("dungeonNormal", GROUP_FINDER_CATEGORY_DUNGEON, DUNGEON_DIFFICULTY_NORMAL, "Normal dungeon")
    Add("archive", GROUP_FINDER_CATEGORY_ENDLESS_DUNGEON, nil, "Infinite Archive")
    Add("arenaVet", GROUP_FINDER_CATEGORY_ARENA, DUNGEON_DIFFICULTY_VETERAN, "Veteran arena")
    Add("arenaNormal", GROUP_FINDER_CATEGORY_ARENA, DUNGEON_DIFFICULTY_NORMAL, "Arena normal")
    Add("pvp", GROUP_FINDER_CATEGORY_PVP, nil, "PvP")
    Add("zone", GROUP_FINDER_CATEGORY_ZONE, nil, "Zone")
    Add("adventure", GROUP_FINDER_CATEGORY_ADVENTURE_ZONE, nil, "Adventure zone")
    Add("custom", GROUP_FINDER_CATEGORY_CUSTOM, nil, "Personalizado")
    return jobs
end

-- Every filter changed for a request is restored synchronously, before yielding.
local filterPairs = {
    {GetGroupFinderGroupFilterSearchString, SetGroupFinderGroupFilterSearchString},
    {GetGroupFinderFilterGroupSizes, SetGroupFinderFilterGroupSizeFlags},
    {GetGroupFinderFilterPlaystyles, SetGroupFinderFilterPlaystyleFlags},
    {DoesGroupFinderFilterRequireChampion, SetGroupFinderFilterRequiresChampion},
    {DoesGroupFinderFilterRequireVOIP, SetGroupFinderFilterRequiresVOIP},
    {DoesGroupFinderFilterRequireInviteCode, SetGroupFinderFilterRequiresInviteCode},
    {DoesGroupFinderFilterAutoAcceptRequests, SetGroupFinderFilterAutoAcceptRequests},
    {DoesGroupFinderFilterRequireEnforceRoles, SetGroupFinderFilterEnforceRoles},
    {GetGroupFinderFilterChampionPoints, SetGroupFinderFilterChampionPoints},
}
local function Options(count, getter)
    local values = {}
    for i = 1, count() do local _, selected = getter(i); values[i] = selected end
    return values
end
function A:Snapshot()
    local s = {category = GetGroupFinderFilterCategory(), values = {}}
    s.primary = Options(GetGroupFinderFilterNumPrimaryOptions, GetGroupFinderFilterPrimaryOptionByIndex)
    s.secondary = Options(GetGroupFinderFilterNumSecondaryOptions, GetGroupFinderFilterSecondaryOptionByIndex)
    for i, pair in ipairs(filterPairs) do s.values[i] = pair[1]() end
    return s
end
function A:Restore(s)
    SetGroupFinderFilterCategory(s.category, false)
    for i, selected in ipairs(s.primary) do SetGroupFinderFilterPrimaryOptionByIndex(i, selected) end
    for i, selected in ipairs(s.secondary) do SetGroupFinderFilterSecondaryOptionByIndex(i, selected) end
    for i, pair in ipairs(filterPairs) do pair[2](s.values[i]) end
end
function A:Configure(job)
    SetGroupFinderFilterCategory(job.category, false)
    ResetGroupFinderFilterOptionsToDefault()
    -- Difficulty indices are the same constants used by ESO's own search buttons.
    if job.difficulty then
        for i = 1, GetGroupFinderFilterNumPrimaryOptions() do
            SetGroupFinderFilterPrimaryOptionByIndex(i, i == job.difficulty)
        end
    end
    SetGroupFinderGroupFilterSearchString("")
    SetGroupFinderFilterEnforceRoles(false)
end
function A:SetEnabled(enabled)
    self.sv.enabled = enabled
    self.pending = nil
    self.lastSearch = nil
    self.nextSearch = 0
    Say(enabled and "Enabled." or "Disabled.")
end
function A:Fail(message)
    self.sv.enabled = false
    self.pending = nil
    Say("Paused due to error: " .. Clean(message) .. ". Use /gftracker status.")
    self.lastError = tostring(message)
end
function A:Tick()
    if not self.sv.enabled then return end
    local now = GetFrameTimeSeconds()
    if IsOwnListingActive() then
        self.pending = nil
        self.lastSearch = nil
        self.lastError = nil
        return
    end
    if self.pending then
        if now - self.pending.started > 30 then
            local manager = GROUP_FINDER_SEARCH_MANAGER
            if manager.currentSearchId == self.pending.id and not self:IsBrowsing() then
                manager:SetSearchState(ZO_GROUP_FINDER_SEARCH_STATES.NONE)
            end
            self.pending = nil
            self.lastError = "Search timed out after 30 seconds; retrying."
            self.nextSearch = now + self:Interval()
        end
        return
    end
    if now < self.nextSearch or self:IsBrowsing() or IsGroupFinderSearchOnCooldown() then return end
    if self.sv.pauseCombat and IsUnitInCombat("player") then return end
    local manager = GROUP_FINDER_SEARCH_MANAGER
    if manager and not manager:IsSearchStateReady() then return end
    if GetGroupFinderStatusReason() ~= GROUP_FINDER_ACTION_RESULT_SUCCESS then return end
    local jobs = self:Jobs()
    if #jobs == 0 then return end
    self.cursor = self.cursor % #jobs + 1
    local job = jobs[self.cursor]
    local snapshot = self:Snapshot()
    self.lastSearch = nil
    local ok, id = pcall(function()
        self:Configure(job)
        self.issuing = true
        local previousId = manager.currentSearchId
        manager:ExecuteSearchInternal()
        if manager.currentSearchId ~= previousId then return manager.currentSearchId end
    end)
    self.issuing = false
    local restored, restoreError = pcall(function() self:Restore(snapshot) end)
    if not restored then self:Fail("No se pudieron restaurar los filters: " .. tostring(restoreError)); return end
    if not ok then self:Fail(id); return end
    self.nextSearch = now + self:Interval()
    if id ~= nil then self.pending = {id = id, job = job, started = now} end
end
function A:Notify(text)
    Say(text)
    if self.sv.sound then PlaySound(SOUNDS.GENERAL_ALERT_ERROR) end
    if self.sv.screen then ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "GF Tracker: " .. text) end
end
function A:ReadResults(job)
    if not self.sv[job.key] then return end
    local now = GetFrameTimeSeconds()
    local count = 0
    for key, value in pairs(self.seen) do if now - value > 1800 then self.seen[key] = nil end end
    for i = 1, GetGroupFinderSearchNumListings() do
        if GetGroupFinderSearchListingCategoryByIndex(i) == job.category then
            local leader = GetGroupFinderSearchListingLeaderDisplayNameByIndex(i)
            local title = GetGroupFinderSearchListingTitleByIndex(i)
            local primary, secondary = GetGroupFinderSearchListingOptionsSelectionTextByIndex(i)
            local key = table.concat({job.key, leader or "", title or "", primary or "", secondary or ""}, "\031")
            local previous = self.seen[key]
            local description = GetGroupFinderSearchListingDescriptionByIndex(i)
            local words = zo_strlower(self.sv.words)
            local matches = words == "" or zo_strlower((title or "") .. " " .. (secondary or "") .. " " .. (description or "")):find(words, 1, true)
            local joinable = not self.sv.onlyJoinable or GetGroupFinderSearchListingJoinabilityResult(i) == GROUP_FINDER_ACTION_RESULT_SUCCESS
            if leader ~= GetDisplayName() and matches and joinable then
                count = count + 1
                if not previous and (self.sv.initial or self.baseline[job.key]) then
                    self:Notify(job.label .. " · " .. Clean(secondary) .. " · " .. Clean(title) .. " · " .. Clean(leader))
                end
                self.seen[key] = now
            end
        end
    end
    self.baseline[job.key] = true
    self.lastCount, self.lastLabel = count, job.label
end
function A:Complete(result, id)
    if not self.pending or id ~= self.pending.id then return end
    local request = self.pending
    self.pending = nil
    if result ~= GROUP_FINDER_ACTION_RESULT_SUCCESS then
        self.lastError = "Search result: " .. tostring(result)
        return
    end
    if not self.sv.enabled or self:IsBrowsing() or IsOwnListingActive() then return end
    self.lastSearch = request
    self.scans = self.scans + 1
    self.lastError = nil
    self:ReadResults(request.job)
end
function A:Settings()
    local LAM = LibAddonMenu2
    self.panel = LAM:RegisterAddonPanel(self.name .. "Panel", {
        type = "panel", name = "GF Tracker", displayName = "GF Tracker",
        author = "jcmed", version = "0.1.0", registerForRefresh = true,
    })
    local controls = {{type = "description", text = "Alerts you to new Group Finder listings. Pauses while Group Finder is open or you have your own listing. Use /gftracker config for settings."}}
    local function Check(key, label, tooltip)
        controls[#controls + 1] = {type = "checkbox", name = label, tooltip = tooltip,
            getFunc = function() return self.sv[key] end,
            setFunc = function(value)
                if key == "enabled" then self:SetEnabled(value) else self.sv[key] = value end
            end, default = defaults[key]}
    end
    Check("enabled", "Enable tracker")
    controls[#controls + 1] = {type = "header", name = "Alert categories"}
    for _, item in ipairs({{"trialVet", "Veteran trials"}, {"trialNormal", "Normal trials"},
        {"dungeonVet", "Veteran dungeons"}, {"dungeonNormal", "Normal dungeons"},
        {"archive", "Infinite Archive"}, {"arenaVet", "Veteran arenas"}, {"arenaNormal", "Normal arenas"},
        {"pvp", "PvP"}, {"zone", "Zone"}, {"adventure", "Adventure zone"}, {"custom", "Personalizado"}}) do
        Check(item[1], item[2])
    end
    controls[#controls + 1] = {type = "description", text = "Search cycle: approximately 3.5 minutes (6.5 minutes for members of Bad Life). Server limits and pauses may extend this time."}
    controls[#controls + 1] = {type = "editbox", name = "Required text (optional)",
        tooltip = "Match literal text in title, activity or description. Leave empty to include all.",
        getFunc = function() return self.sv.words end, setFunc = function(v) self.sv.words = v end, default = ""}
    Check("onlyJoinable", "Only groups I can join", "Disabled by default to avoid hiding listings due to role, CP or DLC requirements.")
    Check("sound", "Sound alert")
    Check("screen", "Screen alert")
    Check("initial", "Alert for existing listings on first scan", "When enabled, the first scan also alerts for existing listings.")
    Check("pauseCombat", "Pause searches in combat")
    controls[#controls + 1] = {type = "button", name = "Test alert", func = function() self:Notify("TEST · Veteran trial · Example without a live search") end}
    LAM:RegisterOptionControls(self.name .. "Panel", controls)
end
function A:Command(text)
    text = zo_strlower(text or ""):match("^%s*(.-)%s*$")
    if text == "" then self:SetEnabled(not self.sv.enabled)
    elseif text == "on" then self:SetEnabled(true)
    elseif text == "off" then self:SetEnabled(false)
    elseif text == "config" or text == "ajustes" then LibAddonMenu2:OpenToPanel(self.panel)
    elseif text == "test" then self:Notify("TEST · Veteran trial · Example without a live search")
    elseif text == "estado" or text == "status" then
        Say((self.sv.enabled and "ON" or "OFF") .. " · filters: " .. #self:Jobs() .. " · completed searches: " .. self.scans
            .. " · last: " .. (self.lastLabel or "pending") .. " · matches: " .. (self.lastCount or 0)
            .. (self:IsBrowsing() and " · paused: Group Finder open" or "")
            .. (self.lastError and " · " .. Clean(self.lastError) or ""))
    else Say("/gftracker [on | off | config | status | test]") end
end
local function Loaded(_, name)
    if name ~= A.name then return end
    EM:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
    A.sv = ZO_SavedVars:NewAccountWide("GFTrackerSavedVariables", 1, nil, defaults, GetWorldName())
    A.baseline = {}
    A:Settings()
    if IsRestrictedGuildMember() then Say("Bad Life members: 6.5-minute search cycle. Contact @juancar02 by in-game mail about access.") end
    SLASH_COMMANDS["/gftracker"] = function(text) A:Command(text) end
    if not SLASH_COMMANDS["/gf"] then SLASH_COMMANDS["/gf"] = SLASH_COMMANDS["/gftracker"]
    else Say("/gf belongs to another addon. Use /gftracker.") end
    EM:RegisterForEvent(A.name, EVENT_GROUP_FINDER_SEARCH_COMPLETE, function(_, result, id) A:Complete(result, id) end)
    EM:RegisterForEvent(A.name, EVENT_GROUP_FINDER_SEARCH_UPDATED, function(_, id)
        if A.sv.enabled and A.lastSearch and A.lastSearch.id == id and not A:IsBrowsing() and not IsOwnListingActive() then A:ReadResults(A.lastSearch.job) end
    end)
    -- ESO has one shared search cache. A search from the UI or another addon
    -- invalidates ownership, even if its completion arrives before our response.
    SecurePostHook(_G, "RequestGroupFinderSearch", function()
        if not A.issuing then
            A.pending, A.lastSearch = nil, nil
            A.nextSearch = GetFrameTimeSeconds() + A:Interval()
        end
    end)
    EM:RegisterForUpdate(A.name, 1000, function()
        local ok, err = pcall(function() A:Tick() end)
        if not ok then A:Fail(err) end
    end)
    Say("Loaded · " .. (A.sv.enabled and "enabled" or "disabled") .. " · /gf config")
end
EM:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, Loaded)

