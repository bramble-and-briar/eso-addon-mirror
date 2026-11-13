-- BGF_Api.lua
-- Thin layer over the game's group finder: searching, the listing draft,
-- posting/editing/removing, applying and handling applicants.
-- Everything here is UI-agnostic; the PC window and the console screen both
-- call into it and listen for BGF:Fire(...) notifications:
--   "SearchUpdated"     results or search state changed
--   "ListingChanged"    own listing created / edited / removed / roles changed
--   "ApplicantsChanged" applicant list changed
--   "StatusChanged"     anything else (applied, cooldown, queue...)

local BGF = BetterGroupFinderConsole
local U = BGF.util
local A = BGF.Activities
local R = BGF.Roles

local DRAFT = GROUP_FINDER_GROUP_LISTING_USER_TYPE_GROUP_LISTING_DRAFT
local CREATED = GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING
local APPLIED = GROUP_FINDER_GROUP_LISTING_USER_TYPE_APPLIED_TO_GROUP_LISTING

BGF.Api = {}
local Api = BGF.Api

function Api:IsAvailable()
    return RequestGroupFinderSearch ~= nil and GROUP_FINDER_SEARCH_MANAGER ~= nil and DRAFT ~= nil
end

function Api:CurrentUserType()
    return U.Safe(GetCurrentGroupFinderUserType) or DRAFT
end

function Api:HasListing()
    return HasGroupListingForUserType and HasGroupListingForUserType(CREATED) or false
end

function Api:HasApplied()
    return HasGroupListingForUserType and HasGroupListingForUserType(APPLIED) or false
end

function Api:IsEditing()
    return self:CurrentUserType() == CREATED
end

---------------------------------------------------------------------------
-- Name helpers
---------------------------------------------------------------------------
function Api:PlaystyleName(value)
    local s = value and GetString("SI_GROUPFINDERPLAYSTYLE", value) or ""
    return (s ~= "" and s) or "Any"
end

function Api:SizeName(value)
    local s = value and GetString("SI_GROUPFINDERGROUPSIZE", value) or ""
    return (s ~= "" and s) or "?"
end

function Api:GetPlaystyles()
    local list = {}
    for _, v in ipairs(U.FlagValues(GROUP_FINDER_PLAYSTYLE_ITERATION_BEGIN, GROUP_FINDER_PLAYSTYLE_ITERATION_END)) do
        list[#list + 1] = { value = v, name = self:PlaystyleName(v) }
    end
    return list
end

---------------------------------------------------------------------------
-- Search
---------------------------------------------------------------------------
Api.results = {}
Api.lastSearchCategory = nil

BGF.SORT_MODES = {
    { id = "best", name = "Best match" },
    { id = "open", name = "Most open slots" },
    { id = "full", name = "Nearly full" },
    { id = "cp_low", name = "Lowest CP req." },
    { id = "cp_high", name = "Highest CP req." },
    { id = "title", name = "Title A-Z" },
}

local function BuildResult(data, myRole, myCP)
    local r = { data = data }
    r.listingIndex = data:GetListingIndex()
    r.title = U.Safe(data.GetTitle, data) or ""
    r.description = U.Safe(data.GetDescription, data) or ""
    r.leader = U.Safe(data.GetOwnerDisplayName, data) or ""
    r.leaderCharacter = U.Safe(data.GetOwnerCharacterName, data) or ""
    r.category = data:GetCategory()
    r.primaryText = data:GetPrimaryOptionText() or ""
    r.secondaryText = data:GetSecondaryOptionText() or ""
    r.numRoles = data:GetNumRoles() or 0
    r.size = data:GetSize()
    r.playstyle = U.Safe(data.GetPlaystyle, data)
    r.requiresCP = U.Safe(data.DoesGroupRequireChampion, data) == true
    r.cp = r.requiresCP and (U.Safe(data.GetChampionPoints, data) or 0) or 0
    r.voip = U.Safe(data.DoesGroupRequireVOIP, data) == true
    r.inviteCode = U.Safe(data.DoesGroupRequireInviteCode, data) == true
    r.autoAccept = U.Safe(data.DoesGroupAutoAcceptRequests, data) == true
    r.joinability = U.Safe(data.GetJoinabilityResult, data)
    r.warning = U.Safe(data.GetWarningText, data)
    r.status = U.Safe(data.GetStatusIndicatorText, data)
    r.isActiveApplication = U.Safe(data.IsActiveApplication, data) == true

    r.desired, r.attained = {}, {}
    r.filled = 0
    for _, role in ipairs(R.ALL) do
        local desired, attained = data:GetRoleStatusCount(role)
        r.desired[role] = desired or 0
        r.attained[role] = attained or 0
        r.filled = r.filled + (attained or 0)
    end
    r.open, r.openTotal = R:Open(r.desired, r.attained)
    r.isFull = r.openTotal <= 0 or r.filled >= r.numRoles

    r.needsMyRole = (r.open[myRole] or 0) > 0 or (r.open[R.ANY] or 0) > 0
    r.meetsCP = (not r.requiresCP) or myCP >= r.cp
    r.canJoin = r.joinability == nil or r.joinability == GROUP_FINDER_ACTION_RESULT_SUCCESS

    local activityName = r.secondaryText ~= "" and r.secondaryText or r.primaryText
    r.activity = A:Lookup(r.secondaryText) or A:Lookup(r.primaryText)
    r.activityLabel = activityName
    if r.secondaryText ~= "" and r.primaryText ~= "" then
        r.activityLabel = string.format("%s - %s", r.secondaryText, r.primaryText)
    end

    -- Score used by "Best match".
    local score = 0
    if r.needsMyRole then score = score + 100 end
    if r.meetsCP then score = score + 50 end
    if r.canJoin then score = score + 40 end
    if r.autoAccept then score = score + 10 end
    if r.numRoles > 0 then score = score + math.floor(20 * r.filled / r.numRoles) end
    if r.isFull then score = score - 200 end
    r.score = score

    r.searchBlob = zo_strlower(table.concat({ r.title, r.description, r.leader, r.leaderCharacter,
        r.primaryText, r.secondaryText, r.activity and r.activity.abbr or "", BGF.Api:PlaystyleName(r.playstyle) }, " "))
    return r
end

function Api:StartSearch(category)
    if not self:IsAvailable() then
        BGF:Print("The group finder is not available on this client.")
        return false
    end
    if category then
        self.lastSearchCategory = category
        BGF.sv.lastCategory = category
        SetGroupFinderFilterCategory(category)
    end
    GROUP_FINDER_SEARCH_MANAGER:ExecuteSearch()
    BGF:Fire("SearchUpdated")
    return true
end

function Api:IsSearching()
    local mgr = GROUP_FINDER_SEARCH_MANAGER
    if not mgr then return false end
    return not mgr:IsSearchStateReady()
end

function Api:IsOnCooldown()
    return IsGroupFinderSearchOnCooldown and IsGroupFinderSearchOnCooldown() or false
end

function Api:SearchStateText()
    local mgr = GROUP_FINDER_SEARCH_MANAGER
    if not mgr then return "" end
    local state = mgr:GetSearchState()
    local S = ZO_GROUP_FINDER_SEARCH_STATES or {}
    if state == S.QUEUED then return "Waiting for search cooldown..." end
    if state == S.WAITING then return "Searching..." end
    if state == S.COMPLETE then return "" end
    return "Press Search to look for groups."
end

function Api:RefreshResults()
    local myRole, myCP = BGF:GetPlayerRole(), BGF:GetPlayerCP()
    ZO_ClearNumericallyIndexedTable(self.results)
    local mgr = GROUP_FINDER_SEARCH_MANAGER
    if not mgr then return self.results end
    local data = mgr:GetSearchResults() or {}
    for i = 1, #data do
        local ok, r = pcall(BuildResult, data[i], myRole, myCP)
        if ok and r then
            self.results[#self.results + 1] = r
        end
    end
    return self.results
end

-- Applies text search, toggles and sort from saved vars (or opts).
function Api:FilterResults(opts)
    opts = opts or BGF.sv
    local text = zo_strlower(U.Trim(opts.searchText))
    local terms = {}
    for word in text:gmatch("%S+") do terms[#terms + 1] = word end

    local out = {}
    for _, r in ipairs(self.results) do
        local keep = true
        for _, term in ipairs(terms) do
            if not zo_plainstrfind(r.searchBlob, term) then keep = false break end
        end
        if keep and opts.filterNeedsMyRole and not r.needsMyRole then keep = false end
        if keep and opts.filterMeetsCP and not r.meetsCP then keep = false end
        if keep and opts.filterHideFull and r.isFull then keep = false end
        if keep and opts.filterAutoAcceptOnly and not r.autoAccept then keep = false end
        if keep and opts.filterNoInviteCode and r.inviteCode then keep = false end
        if keep then out[#out + 1] = r end
    end

    local mode = (BGF.SORT_MODES[opts.sortMode or 1] or BGF.SORT_MODES[1]).id
    local comparators = {
        best = function(a, b) if a.score ~= b.score then return a.score > b.score end return a.title < b.title end,
        open = function(a, b) if a.openTotal ~= b.openTotal then return a.openTotal > b.openTotal end return a.title < b.title end,
        full = function(a, b) if a.openTotal ~= b.openTotal then return a.openTotal < b.openTotal end return a.title < b.title end,
        cp_low = function(a, b) if a.cp ~= b.cp then return a.cp < b.cp end return a.title < b.title end,
        cp_high = function(a, b) if a.cp ~= b.cp then return a.cp > b.cp end return a.title < b.title end,
        title = function(a, b) return zo_strlower(a.title) < zo_strlower(b.title) end,
    }
    table.sort(out, comparators[mode] or comparators.best)
    return out
end

function Api:SetExpectingUpdates(on)
    if RequestSetGroupFinderExpectingUpdates then
        RequestSetGroupFinderExpectingUpdates(on and true or false)
    end
end

---------------------------------------------------------------------------
-- Applying
---------------------------------------------------------------------------
function Api:Apply(result, message, inviteCode)
    if not result then return end
    local res
    message = U.Trim(message)
    if result.inviteCode then
        res = RequestApplyToGroupListing(result.listingIndex, message, tonumber(inviteCode))
    else
        res = RequestApplyToGroupListing(result.listingIndex, message)
    end
    if res ~= GROUP_FINDER_ACTION_RESULT_SUCCESS then
        BGF:Alert(BGF:ActionResultText(res), true)
        return false, res
    end
    BGF:Print(string.format("Applied to \"%s\"%s.", result.title, result.autoAccept and " (auto-accept)" or ""))
    return true, res
end

function Api:Rescind()
    if RequestResolveGroupListingApplication and RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_RESCIND then
        RequestResolveGroupListingApplication(RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_RESCIND)
    end
end

function Api:GetAppliedListing()
    if not self:HasApplied() then return nil end
    local data = ZO_GroupListingUserTypeData:New(APPLIED)
    return {
        title = U.Safe(data.GetTitle, data) or "",
        leader = U.Safe(data.GetOwnerDisplayName, data) or "",
        primaryText = U.Safe(data.GetPrimaryOptionText, data) or "",
        secondaryText = U.Safe(data.GetSecondaryOptionText, data) or "",
        category = U.Safe(data.GetCategory, data),
        description = U.Safe(data.GetDescription, data) or "",
    }
end

---------------------------------------------------------------------------
-- Applicants (for your own listing)
---------------------------------------------------------------------------
function Api:GetApplicants()
    local mgr = GROUP_FINDER_APPLICATIONS_LIST_MANAGER
    if not mgr then return {} end
    local list = {}
    for _, app in ipairs(mgr:GetApplicationsData() or {}) do
        list[#list + 1] = {
            app = app,
            characterId = app:GetCharacterId(),
            displayName = app:GetDisplayName() or "",
            characterName = app:GetCharacterName() or "",
            className = U.Safe(app.GetClassName, app) or "",
            level = app:GetLevel() or 0,
            cp = app:GetChampionPoints() or 0,
            role = app:GetRole(),
            note = U.Safe(app.GetNote, app) or "",
            timeLeft = U.Safe(app.GetTimeRemainingSeconds, app) or 0,
            pending = U.Safe(app.IsInPendingState, app) == true,
        }
    end
    return list
end

function Api:ResolveApplicant(characterId, approve)
    if not RequestResolveGroupListingApplication then return end
    local kind = approve and RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_APPROVE or RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_REJECT
    RequestResolveGroupListingApplication(kind, characterId)
end

---------------------------------------------------------------------------
-- Listing draft
---------------------------------------------------------------------------
-- The game keeps one editable draft (DRAFT user type). We read and write it
-- directly; the BGF draft table only remembers our own extras (intent,
-- auto flags, notes).
local L = {}
Api.Listing = L

function L:UT() return DRAFT end

function L:GetCategory()
    return GetGroupFinderUserTypeGroupListingCategory(DRAFT)
end

function L:SetCategory(category)
    if Api:IsEditing() then return end
    SetGroupFinderUserTypeGroupListingCategory(DRAFT, category)
    UpdateGroupFinderUserTypeGroupListingOptions(DRAFT)
    if SetGroupFinderUserTypeGroupListingSecondaryOptionDefault then
        SetGroupFinderUserTypeGroupListingSecondaryOptionDefault(DRAFT)
    end
end

local function ReadOptions(numFn, getFn)
    local list = {}
    local n = U.Safe(numFn, DRAFT) or 0
    for i = 1, n do
        local name, isSet = getFn(DRAFT, i)
        list[#list + 1] = { index = i, name = name or ("Option " .. i), isSet = isSet == true }
    end
    return list
end

function L:GetPrimaryOptions()
    return ReadOptions(GetGroupFinderUserTypeGroupListingNumPrimaryOptions, GetGroupFinderUserTypeGroupListingPrimaryOptionByIndex)
end

function L:GetSecondaryOptions()
    return ReadOptions(GetGroupFinderUserTypeGroupListingNumSecondaryOptions, GetGroupFinderUserTypeGroupListingSecondaryOptionByIndex)
end

local function Selected(list)
    for _, o in ipairs(list) do
        if o.isSet then return o end
    end
end

function L:GetPrimary() return Selected(self:GetPrimaryOptions()) end
function L:GetSecondary() return Selected(self:GetSecondaryOptions()) end

local function UsesDifficulty(category)
    return category == GROUP_FINDER_CATEGORY_DUNGEON or category == GROUP_FINDER_CATEGORY_ARENA or category == GROUP_FINDER_CATEGORY_TRIAL
end
L.UsesDifficulty = UsesDifficulty

function L:SetPrimary(index)
    if Api:IsEditing() then return end
    SetGroupFinderUserTypeGroupListingPrimaryOption(DRAFT, index)
    local category = self:GetCategory()
    if UsesDifficulty(category) and SetVeteranDifficulty and DUNGEON_DIFFICULTY_VETERAN then
        -- Same as the game's own create screen: primary option 2 is veteran.
        SetVeteranDifficulty(index == DUNGEON_DIFFICULTY_VETERAN)
    end
end

function L:IsVeteran()
    local category = self:GetCategory()
    if not UsesDifficulty(category) then return false end
    local p = self:GetPrimary()
    return p ~= nil and p.index == DUNGEON_DIFFICULTY_VETERAN
end

-- Picks the normal/veteran primary option for an intent.
function L:ApplyDifficulty(difficulty)
    if not difficulty or not UsesDifficulty(self:GetCategory()) then return end
    local want = difficulty == "veteran" and DUNGEON_DIFFICULTY_VETERAN or DUNGEON_DIFFICULTY_NORMAL
    for _, o in ipairs(self:GetPrimaryOptions()) do
        if o.index == want then
            self:SetPrimary(o.index)
            return
        end
    end
end

function L:SetSecondary(index)
    if Api:IsEditing() then return end
    SetGroupFinderUserTypeGroupListingSecondaryOption(DRAFT, index)
end

function L:GetSizes()
    local list = {}
    local first = U.Safe(GetGroupFinderUserTypeGroupSizeIterationBegin, DRAFT)
    local last = U.Safe(GetGroupFinderUserTypeGroupSizeIterationEnd, DRAFT)
    local current = self:GetSize()
    for _, v in ipairs(U.FlagValues(first, last)) do
        list[#list + 1] = { value = v, name = Api:SizeName(v), isSet = v == current }
    end
    return list
end

function L:GetSize() return GetGroupFinderUserTypeGroupListingGroupSize(DRAFT) end
function L:SetSize(v)
    if Api:IsEditing() then return end
    SetGroupFinderUserTypeGroupListingGroupSize(DRAFT, v)
end
function L:GetNumRoles() return GetGroupFinderUserTypeGroupListingNumRoles(DRAFT) or 4 end

function L:GetPlaystyle() return GetGroupFinderUserTypeGroupListingPlaystyle(DRAFT) end
function L:SetPlaystyle(v) SetGroupFinderUserTypeGroupListingPlaystyle(DRAFT, v) end

-- Picks a playstyle whose (localized) name contains one of the keywords.
function L:ApplyPlaystyleKeywords(keywords)
    if not keywords then return end
    local styles = Api:GetPlaystyles()
    for _, kw in ipairs(keywords) do
        for _, s in ipairs(styles) do
            if U.Contains(s.name, kw) then
                self:SetPlaystyle(s.value)
                return
            end
        end
    end
end

function L:GetTitle() return GetGroupFinderUserTypeGroupListingTitle(DRAFT) or "" end
function L:SetTitle(t) SetGroupFinderUserTypeGroupListingTitle(DRAFT, t or "") end
function L:GetDescription() return GetGroupFinderUserTypeGroupListingDescription(DRAFT) or "" end
function L:SetDescription(t) SetGroupFinderUserTypeGroupListingDescription(DRAFT, t or "") end

function L:GetRequiresCP() return DoesGroupFinderUserTypeGroupListingRequireChampion(DRAFT) end
function L:SetRequiresCP(b) SetGroupFinderUserTypeGroupListingRequiresChampion(DRAFT, b and true or false) end
function L:GetCP() return GetGroupFinderCreateGroupListingChampionPoints(DRAFT) or 0 end
function L:SetCP(n)
    local maxCP = 3600
    if GetMaxSpendableChampionPointsInAttribute and GetNumChampionDisciplines then
        maxCP = GetMaxSpendableChampionPointsInAttribute() * GetNumChampionDisciplines()
    end
    SetGroupFinderUserTypeGroupListingChampionPoints(DRAFT, U.Clamp(tonumber(n) or 0, 0, maxCP))
end

function L:GetVOIP() return DoesGroupFinderUserTypeGroupListingRequireVOIP(DRAFT) end
function L:SetVOIP(b) SetGroupFinderUserTypeGroupListingRequiresVOIP(DRAFT, b and true or false) end
function L:GetAutoAccept() return DoesGroupFinderUserTypeGroupListingAutoAcceptRequests(DRAFT) end
function L:SetAutoAccept(b) SetGroupFinderUserTypeGroupListingAutoAcceptRequests(DRAFT, b and true or false) end
function L:GetEnforceRoles() return DoesGroupFinderUserTypeGroupListingEnforceRoles(DRAFT) end
function L:SetEnforceRoles(b) SetGroupFinderUserTypeGroupListingEnforceRoles(DRAFT, b and true or false) end
function L:GetRequiresInviteCode() return DoesGroupFinderUserTypeGroupListingRequireInviteCode(DRAFT) end
function L:SetRequiresInviteCode(b) SetGroupFinderUserTypeGroupListingRequiresInviteCode(DRAFT, b and true or false) end
function L:GetInviteCode() return GetGroupFinderUserTypeGroupListingInviteCode(DRAFT) end
function L:SetInviteCode(n) SetGroupFinderUserTypeGroupListingInviteCode(DRAFT, tonumber(n) or 0) end

function L:GetRoles()
    local desired, attained = {}, {}
    for _, role in ipairs(R.ALL) do
        desired[role] = GetGroupFinderUserTypeGroupListingDesiredRoleCount(DRAFT, role) or 0
        attained[role] = GetGroupFinderUserTypeGroupListingAttainedRoleCount(DRAFT, role) or 0
    end
    return desired, attained
end

-- Writes T/H/D and puts whatever is left into "Any", like the game does.
function L:SetRoles(roles)
    local numRoles = self:GetNumRoles()
    local total = 0
    for _, role in ipairs(R.ORDER) do
        local n = math.max(0, roles[role] or 0)
        SetGroupFinderUserTypeGroupListingRoleCount(DRAFT, role, n)
        total = total + n
    end
    SetGroupFinderUserTypeGroupListingRoleCount(DRAFT, R.ANY, math.max(0, numRoles - total))
end

-- Changes one role by delta, keeping the total within the group size and
-- not going below members you already have.
function L:AdjustRole(role, delta)
    local desired, attained = self:GetRoles()
    local numRoles = self:GetNumRoles()
    local used = 0
    for _, r in ipairs(R.ORDER) do used = used + (desired[r] or 0) end
    local newValue = (desired[role] or 0) + delta
    if newValue < (attained[role] or 0) or newValue < 0 then return false end
    if delta > 0 and used + delta > numRoles then
        -- Take the slot from DPS (or heal/tank) to make room.
        local donor
        for _, r in ipairs({ R.DPS, R.HEAL, R.TANK }) do
            if r ~= role and (desired[r] or 0) > (attained[r] or 0) then donor = r break end
        end
        if not donor then return false end
        desired[donor] = desired[donor] - 1
    end
    desired[role] = newValue
    self:SetRoles(desired)
    self:RememberTarget(desired)
    return true
end

-- The composition the leader is aiming for: the auto template, or the last
-- roles they set by hand. Used to re-fit roles when the group changes.
function L:RememberTarget(roles)
    local t = { numRoles = self:GetNumRoles() }
    for _, role in ipairs(R.ORDER) do t[role] = roles[role] or 0 end
    self.target = t
end

function L:GetTarget(intent)
    local numRoles = self:GetNumRoles()
    if BGF.sv.autoRoles then
        return R:Template(numRoles, intent, self:GetActivity())
    end
    if self.target and self.target.numRoles == numRoles then
        return self.target
    end
    return (self:GetRoles())
end

-- Activity info (DB entry) for the current selection.
function L:GetActivity()
    local s = self:GetSecondary()
    return s and A:Lookup(s.name) or nil, s and s.name or nil
end

-- Generates roles from the intent/activity/size and the current group.
function L:AutoRoles(intent)
    local activity = self:GetActivity()
    local numRoles = self:GetNumRoles()
    local _, attained = self:GetRoles()
    local template = R:Template(numRoles, intent, activity)
    local fitted = R:Fit(template, numRoles, attained)
    self:SetRoles(fitted)
    self:RememberTarget(template)
    return fitted
end

function L:BuildContext(intent)
    local desired, attained = self:GetRoles()
    local open = R:Open(desired, attained)
    local activity, activityName = self:GetActivity()
    local primary = self:GetPrimary()
    if not activityName or activityName == "" then
        activityName = primary and primary.name or nil
    end
    return {
        intent = intent,
        activity = activity,
        activityName = activityName,
        difficultyText = (UsesDifficulty(self:GetCategory()) and primary) and primary.name or nil,
        isVeteran = self:IsVeteran(),
        open = open,
        cp = self:GetRequiresCP() and self:GetCP() or 0,
        voip = self:GetVOIP(),
        extraNotes = BGF.sv.extraNotes,
    }
end

function L:AutoTitle(intent)
    local t = R:BuildTitle(self:BuildContext(intent))
    self:SetTitle(t)
    return t
end

function L:AutoDescription(intent)
    local t = R:BuildDescription(self:BuildContext(intent))
    self:SetDescription(t)
    return t
end

-- Applies an intent: category, difficulty, playstyle, CP, roles, texts.
function L:ApplyIntent(intent, keepCategory)
    if not intent then return end
    BGF.sv.lastIntent = intent.id
    if not Api:IsEditing() then
        local cat = A:CategoryByKey(intent.category)
        if cat and not keepCategory and self:GetCategory() ~= cat.value then
            self:SetCategory(cat.value)
        end
        self:ApplyDifficulty(intent.difficulty)
    end
    self:ApplyPlaystyleKeywords(intent.playstyle)
    local activity = self:GetActivity()
    local cp = math.max(intent.cp or 0, activity and activity.cp or 0)
    if intent.difficulty ~= "veteran" then cp = intent.cp or 0 end
    self:SetRequiresCP(cp > 0)
    if cp > 0 then self:SetCP(cp) end
    self:RefreshAuto(intent)
end

-- Re-runs whatever parts are on "auto".
function L:RefreshAuto(intent)
    intent = intent or A:GetIntent(BGF.sv.lastIntent)
    if BGF.sv.autoRoles then self:AutoRoles(intent) end
    if BGF.sv.autoTitle then self:AutoTitle(intent) end
    if BGF.sv.autoDescription then self:AutoDescription(intent) end
end

---------------------------------------------------------------------------
-- Auto-adjust when the group changes
---------------------------------------------------------------------------
local REBALANCE_DELAY_MS = 600   -- let a burst of role/join events settle
local EDIT_DELAY_MS = 1500       -- then push one edit to the live listing
local EDIT_RETRIES = 10

local function Schedule(name, ms, fn)
    local id = BGF.name .. name
    EVENT_MANAGER:UnregisterForUpdate(id)
    EVENT_MANAGER:RegisterForUpdate(id, ms, function()
        EVENT_MANAGER:UnregisterForUpdate(id)
        fn()
    end)
end

-- Re-fits the draft's roles to the target for the current group members and
-- refreshes the automatic title / description. Returns true if anything
-- changed (and, for a live listing, queues an edit).
function L:Rebalance()
    if not BGF.sv.autoAdjustRoles then return false end
    local intent = A:GetIntent(BGF.sv.lastIntent)
    local numRoles = self:GetNumRoles()
    local desired, attained = self:GetRoles()
    local fitted = R:Fit(self:GetTarget(intent), numRoles, attained)

    local rolesChanged = false
    for _, role in ipairs(R.ALL) do
        if (fitted[role] or 0) ~= (desired[role] or 0) then rolesChanged = true break end
    end
    if rolesChanged then self:SetRoles(fitted) end

    local titleBefore, descBefore = self:GetTitle(), self:GetDescription()
    if BGF.sv.autoTitle then self:AutoTitle(intent) end
    if BGF.sv.autoDescription then self:AutoDescription(intent) end
    local textChanged = self:GetTitle() ~= titleBefore or self:GetDescription() ~= descBefore

    if not (rolesChanged or textChanged) then return false end
    if Api:HasListing() then self:QueueLiveEdit(EDIT_RETRIES) end
    BGF:Fire("ListingChanged")
    return true
end

function L:QueueRebalance()
    Schedule("Rebalance", REBALANCE_DELAY_MS, function() self:Rebalance() end)
end

-- Sends the draft to the live listing, quietly skipping when it can't.
function L:QueueLiveEdit(retries)
    Schedule("LiveEdit", EDIT_DELAY_MS, function()
        if not Api:HasListing() or not IsUnitSoloOrGroupLeader("player") then return end
        local busy = (HasPendingAcceptedGroupFinderApplication and HasPendingAcceptedGroupFinderApplication())
            or (IsGroupFinderRoleChangeRequested and IsGroupFinderRoleChangeRequested())
        if busy then
            if (retries or 0) > 0 then self:QueueLiveEdit(retries - 1) end
            return
        end
        local desc = self:GetDescription()
        local withAd = R:WithAd(desc)
        if withAd ~= desc then self:SetDescription(withAd) end
        if HasUserTypeGroupListingChanged and not HasUserTypeGroupListingChanged(DRAFT) then return end
        if self:GetNumRoles() <= GetGroupSize() then return end -- group is full
        if #self:Validate() > 0 then return end
        self.autoEditing = true
        RequestEditGroupListing()
    end)
end

-- Problems that block posting (empty table = ok).
function L:Validate()
    local problems = {}
    if IsGroupFinderRoleChangeRequested and IsGroupFinderRoleChangeRequested() then
        problems[#problems + 1] = GetString(SI_GROUP_FINDER_ROLE_CHANGING)
    end
    if not IsUnitSoloOrGroupLeader("player") then
        problems[#problems + 1] = "Only the group leader can post a listing."
    end
    if ZO_GroupFinder_GetIsCurrentlyInQueue and ZO_GroupFinder_GetIsCurrentlyInQueue() then
        problems[#problems + 1] = "You can't post while queued in the Activity Finder."
    end
    if self:GetNumRoles() <= GetGroupSize() then
        problems[#problems + 1] = "Your group is already at the listing size."
    end
    local title = self:GetTitle()
    if U.Trim(title) == "" then
        problems[#problems + 1] = "Title is empty."
    elseif ZO_GroupFinder_GetGroupTitleViolationString then
        local violations = { IsValidGroupFinderListingTitle(title) }
        if #violations > 0 then
            local text = U.Safe(ZO_GroupFinder_GetGroupTitleViolationString, title)
            problems[#problems + 1] = "Title: " .. tostring(text or "not allowed")
        end
    end
    if self:GetRequiresInviteCode() and (tonumber(self:GetInviteCode()) or 0) <= 0 then
        problems[#problems + 1] = "Enter an invite code or turn the invite code off."
    end
    return problems
end

function L:Post()
    -- Make sure the description ends with the Better Group Finder line
    -- (also for hand-written descriptions), unless turned off in settings.
    local desc = self:GetDescription()
    local withAd = R:WithAd(desc)
    if withAd ~= desc then self:SetDescription(withAd) end

    local problems = self:Validate()
    if #problems > 0 then
        BGF:Alert(problems[1], true)
        return false, problems
    end
    if Api:IsEditing() then
        RequestEditGroupListing()
    else
        RequestCreateGroupListing()
    end
    return true
end

function Api:RemoveListing()
    if RequestRemoveGroupListing then RequestRemoveGroupListing() end
end

function Api:GetMyListingSummary()
    if not self:HasListing() then return nil end
    local data = ZO_GroupListingUserTypeData:New(CREATED)
    local desired, attained = {}, {}
    for _, role in ipairs(R.ALL) do
        desired[role] = U.Safe(data.GetDesiredRoleCount, data, role) or 0
        attained[role] = U.Safe(data.GetAttainedRoleCount, data, role) or 0
    end
    local open, openTotal = R:Open(desired, attained)
    return {
        title = U.Safe(data.GetTitle, data) or "",
        description = U.Safe(data.GetDescription, data) or "",
        primaryText = U.Safe(data.GetPrimaryOptionText, data) or "",
        secondaryText = U.Safe(data.GetSecondaryOptionText, data) or "",
        category = U.Safe(data.GetCategory, data),
        numRoles = U.Safe(data.GetNumRoles, data) or 0,
        desired = desired, attained = attained, open = open, openTotal = openTotal,
    }
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function ResultFromEvent(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "number" then return v end
    end
end

BGF:OnInitialize(function()
    if not Api:IsAvailable() then return end
    local ns = BGF.name .. "Api"

    GROUP_FINDER_SEARCH_MANAGER:RegisterCallback("OnGroupFinderSearchResultsReady", function()
        Api:RefreshResults()
        BGF:Fire("SearchUpdated")
    end)
    GROUP_FINDER_SEARCH_MANAGER:RegisterCallback("OnGroupFinderSearchResultsUpdated", function()
        Api:RefreshResults()
        BGF:Fire("SearchUpdated")
    end)
    GROUP_FINDER_SEARCH_MANAGER:RegisterCallback("OnSearchStateChanged", function()
        Api:RefreshResults()
        BGF:Fire("SearchUpdated")
    end)

    if GROUP_FINDER_APPLICATIONS_LIST_MANAGER then
        GROUP_FINDER_APPLICATIONS_LIST_MANAGER:RegisterCallback("ApplicationsListUpdated", function()
            BGF:Fire("ApplicantsChanged")
        end)
    end

    local function Reg(eventName, fn)
        local id = _G[eventName]
        if id then
            EVENT_MANAGER:RegisterForEvent(ns .. eventName, id, fn)
        end
    end

    Reg("EVENT_GROUP_FINDER_CREATE_GROUP_LISTING_RESULT", function(_, ...)
        local result = ResultFromEvent(...)
        if result == GROUP_FINDER_ACTION_RESULT_SUCCESS then
            BGF:Print("Listing posted.")
        elseif result then
            BGF:Alert(BGF:ActionResultText(result), true)
        end
        BGF:Fire("ListingChanged")
    end)
    Reg("EVENT_GROUP_FINDER_UPDATE_GROUP_LISTING_RESULT", function(_, ...)
        local result = ResultFromEvent(...)
        local auto = L.autoEditing
        L.autoEditing = false
        if result == GROUP_FINDER_ACTION_RESULT_SUCCESS and auto then
            local desired, attained = L:GetRoles()
            BGF:Print("Group roles changed - listing updated. Now looking for: " .. R:Long((R:Open(desired, attained))) .. ".")
        elseif result == GROUP_FINDER_ACTION_RESULT_SUCCESS then
            BGF:Print("Listing updated.")
        elseif result then
            BGF:Alert(BGF:ActionResultText(result), true)
        end
        BGF:Fire("ListingChanged")
    end)
    Reg("EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_RESULT", function()
        BGF:Fire("ListingChanged")
    end)
    Reg("EVENT_GROUP_FINDER_GROUP_LISTING_ATTAINED_ROLES_CHANGED", function()
        L:QueueRebalance()
        BGF:Fire("ListingChanged")
    end)
    -- A member switched role, joined or left: re-fit the listing.
    Reg("EVENT_GROUP_MEMBER_ROLE_CHANGED", function() L:QueueRebalance() end)
    Reg("EVENT_GROUP_MEMBER_JOINED", function() L:QueueRebalance() end)
    Reg("EVENT_GROUP_MEMBER_LEFT", function() L:QueueRebalance() end)
    Reg("EVENT_GROUP_FINDER_APPLY_TO_GROUP_LISTING_RESULT", function(_, ...)
        local result = ResultFromEvent(...)
        if result and result ~= GROUP_FINDER_ACTION_RESULT_SUCCESS then
            BGF:Alert(BGF:ActionResultText(result), true)
        end
        BGF:Fire("StatusChanged")
    end)
    Reg("EVENT_GROUP_FINDER_APPLICATION_RECEIVED", function()
        if BGF.sv.alertOnApplicant then
            BGF:Alert("New group finder applicant!")
        end
        BGF:Fire("ApplicantsChanged")
    end)
    Reg("EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_APPLICATION", function() BGF:Fire("StatusChanged") end)
    Reg("EVENT_GROUP_FINDER_RESOLVE_GROUP_LISTING_APPLICATION_RESULT", function() BGF:Fire("StatusChanged") BGF:Fire("ApplicantsChanged") end)
    Reg("EVENT_GROUP_FINDER_STATUS_UPDATED", function() BGF:Fire("StatusChanged") end)
    Reg("EVENT_GROUP_FINDER_SEARCH_COOLDOWN_UPDATE", function() BGF:Fire("SearchUpdated") end)
end)
