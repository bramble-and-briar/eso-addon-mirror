-- Groupbound_Finder.lua : the game's Group Finder, without opening its menu.
-- Search: the game keeps ONE result list and one search filter, so Groupbound searches the
-- categories you show in turns (Trials normal, Trials veteran, Dungeons normal, ...), copies each
-- result into its own list and waits out the game's search cooldown in between. While the
-- window is open it searches as often as the game allows; closed, each category every 2 min (for
-- alerts, setting "background"). It never searches while the game's own group menu is open.
-- Apply: a listing's number only fits the result list it came from. If another category was
-- searched since, Groupbound searches that category again first and finds the group by its
-- leader, then applies (RequestApplyToGroupListing, like the game's Apply dialog).
-- Your listing: the "Post a group" form fills the game's listing draft and asks the game to
-- create it (like the game's Create Group panel).
-- Ghost listings (players' biggest complaint): every listing remembers when Groupbound first saw
-- it and when its member count last changed ("nobody joined for 50 min"), and a group you
-- couldn't join is marked for 15 min (it often stays in the results after it's gone).
-- Leading: "List again" repeats your last listing (with the roles still missing now), and a
-- check 6 s later catches the game's known bug where a listing is "created" but never shows.
-- Applicants to your listing: read like the game's applications list (esoui
-- groupfinder_applicationlist_manager.lua / groupfinderdata.lua), accept / decline with
-- RequestResolveGroupListingApplication.
-- Every call is read from the game's source (esoui "live" branch: groupfinder_*.lua).

local G = Groupbound
local L = G.L
local Content = G.Content
local Parse = G.Parse
local Finder = {}
G.Finder = Finder

local BACKGROUND_EVERY = 120     -- seconds between searches of one category while the window is closed
local OPEN_GAP = 3               -- at least this many seconds between two searches
local STALE = 600                -- a category not searched for 10 min is dropped from the board
local BUSY_TIMEOUT = 10
local DEAD_FOR = 900             -- a group you couldn't join counts as gone for 15 min
local FORGET_AFTER = 1800        -- listing ages are forgotten 30 min after the listing was last seen
local LISTING_CHECK_MS = 6000    -- after creating a listing: is it really there?

local state = {
    seen = {},          -- [entry id] = { first, members, changed, last }: listing ages
    dead = {},          -- [account lowercase] = time you couldn't join it
    applyAccount = nil, -- the leader of your last application (for the game's late answer)
    createAt = nil,     -- when you last asked the game to create a listing
    knownApps = {},     -- [character id] = true: applications already announced
    lastRun = {},       -- [taskKey] = timestamp of the last search
    results = {},       -- [taskKey] = { t = timestamp, list = { entries } }
    clientKey = nil,    -- which task's results the game holds right now (nil = unknown / not ours)
    clientGen = 0,      -- bumps with every new result list in the game
    searchId = nil,
    searchKey = nil,
    busySince = nil,
    lastSearch = 0,
    pendingApply = nil, -- { account, taskKey, message, code, tries }
    searches = 0,
}

local function Supported()
    return RequestGroupFinderSearch ~= nil and GetGroupFinderSearchNumListings ~= nil
        and GROUP_FINDER_CATEGORY_TRIAL ~= nil
end

-- the Group Finder is open for this character (level etc.)
function Finder.Unlocked()
    if not Supported() then return false end
    local ok, status = pcall(GetGroupFinderStatusReason)
    if not ok then return true end
    return status == GROUP_FINDER_ACTION_RESULT_SUCCESS
        or status == GROUP_FINDER_ACTION_RESULT_FAILED_ACCOUNT_TYPE_BLOCKS_CREATION
end

local function GameMenuOpen()
    local scene = KEYBOARD_GROUP_MENU_SCENE
    if scene and scene.IsShowing and scene:IsShowing() then return true end
    if SCENE_MANAGER and SCENE_MANAGER.IsShowing then
        local ok, shown = pcall(SCENE_MANAGER.IsShowing, SCENE_MANAGER, "gamepad_groupList")
        if ok and shown then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Tasks: one search each (category + difficulty)

local KIND_CATS = {
    trial = { "GROUP_FINDER_CATEGORY_TRIAL" },
    dungeon = { "GROUP_FINDER_CATEGORY_DUNGEON" },
    arena = { "GROUP_FINDER_CATEGORY_ARENA", "GROUP_FINDER_CATEGORY_ENDLESS_DUNGEON" },
    other = { "GROUP_FINDER_CATEGORY_ZONE", "GROUP_FINDER_CATEGORY_ADVENTURE_ZONE", "GROUP_FINDER_CATEGORY_CUSTOM" },
}

local function HasDifficulty(cat)
    return cat == GROUP_FINDER_CATEGORY_TRIAL or cat == GROUP_FINDER_CATEGORY_DUNGEON or cat == GROUP_FINDER_CATEGORY_ARENA
end

local function TaskKey(cat, diff) return cat .. ":" .. diff end

local function KindOfCat(cat)
    for kind, names in pairs(KIND_CATS) do
        for _, name in ipairs(names) do
            if _G[name] == cat then return kind end
        end
    end
    return "other"
end

local function Tasks()
    local list = {}
    for _, kind in ipairs({ "trial", "dungeon", "arena", "other" }) do
        if G.sv.cats[kind] then
            for _, name in ipairs(KIND_CATS[kind]) do
                local cat = _G[name]
                local available = cat ~= nil
                if available and IsGroupFinderCategoryAvailable then
                    local ok, yes = pcall(IsGroupFinderCategoryAvailable, cat)
                    available = ok and yes
                end
                if available then
                    if HasDifficulty(cat) then
                        list[#list + 1] = { cat = cat, diff = DUNGEON_DIFFICULTY_NORMAL or 1, kind = kind }
                        list[#list + 1] = { cat = cat, diff = DUNGEON_DIFFICULTY_VETERAN or 2, kind = kind }
                    else
                        list[#list + 1] = { cat = cat, diff = 0, kind = kind }
                    end
                end
            end
        end
    end
    for _, t in ipairs(list) do t.key = TaskKey(t.cat, t.diff) end
    return list
end

-- ---------------------------------------------------------------------------
-- Reading the game's result list

local ROLE_LFG = {}
local function RoleCounts(i)
    local r = {}
    for role, lfg in pairs(ROLE_LFG) do
        local ok, desired, attained = pcall(GetGroupFinderSearchListingRoleStatusCount, i, lfg)
        r[role] = { d = ok and desired or 0, a = ok and attained or 0 }
    end
    return r
end

local function Read(i, task)
    local function Get(fn, ...)
        if not fn then return nil end
        local ok, a, b = pcall(fn, ...)
        if ok then return a, b end
    end
    local account = Get(GetGroupFinderSearchListingLeaderDisplayNameByIndex, i) or ""
    if account == "" then return nil end
    local e = { finder = true, src = "finder", account = account }
    e.id = "f:" .. G.AccountKey(account)
    e.index, e.taskKey, e.gen = i, task.key, state.clientGen
    e.cat = Get(GetGroupFinderSearchListingCategoryByIndex, i) or task.cat
    e.title = Get(GetGroupFinderSearchListingTitleByIndex, i) or ""
    e.desc = Get(GetGroupFinderSearchListingDescriptionByIndex, i) or ""
    local char = Get(GetGroupFinderSearchListingLeaderCharacterNameByIndex, i)
    e.char = char and char ~= "" and zo_strformat("<<1>>", char) or nil
    e.primary, e.secondary = Get(GetGroupFinderSearchListingOptionsSelectionTextByIndex, i)
    e.size = Get(GetGroupFinderSearchListingNumRolesByIndex, i) or 0
    local ps = Get(GetGroupFinderSearchListingPlaystyleByIndex, i)
    e.playstyle = ps and GetString("SI_GROUPFINDERPLAYSTYLE", ps) or ""
    e.roles = RoleCounts(i)
    e.cp = Get(DoesGroupFinderSearchListingRequireChampion, i) and Get(GetGroupFinderSearchListingChampionPointsByIndex, i) or nil
    if e.cp == 0 then e.cp = nil end
    e.voip = Get(DoesGroupFinderSearchListingRequireVOIP, i) and true or false
    e.invite = Get(DoesGroupFinderSearchListingRequireInviteCode, i) and true or false
    e.auto = Get(DoesGroupFinderSearchListingAutoAcceptRequests, i) and true or false
    e.join = Get(GetGroupFinderSearchListingJoinabilityResult, i)
    e.applied = Get(IsGroupFinderSearchListingActiveApplication, i) and true or false

    -- what it is: the listing's own option (trial / dungeon name), else read from the title
    local scan = Parse.Scan(e.title .. " " .. e.desc .. " " .. e.playstyle)
    if HasDifficulty(e.cat) then
        e.content = Content.FromName(e.secondary) or Content.FromName(e.primary) or scan.content
        e.vet = task.diff == (DUNGEON_DIFFICULTY_VETERAN or 2)
    else
        e.content = scan.content
        e.vet = scan.vet
        e.place = e.primary ~= "" and e.primary or e.secondary
    end
    e.kind = Content.Kind(e.content)
    if e.kind == "other" then e.kind = task.kind end
    -- a "group" that's really a guild ad or a sale (custom listings): handled like the chat ones
    if scan.kind == "recruit" or scan.kind == "sale" then e.ad = scan.kind end
    e.hm = scan.hm
    e.tags = scan.tags
    e.startAt, e.startNow = scan.startAt, scan.startNow
    -- (not the playstyle: that's the game's text in YOUR language)
    e.lang = Parse.Language(e.title .. " " .. e.desc)
    e.text = e.desc ~= "" and e.desc or e.title

    -- open places per role (from the game's tooltip logic): own open slots + "any role" slots,
    -- never more than the places left
    local members = 0
    for _, role in ipairs(G.ROLES) do members = members + (e.roles[role] and e.roles[role].a or 0) end
    e.members = members
    local free = math.max(0, e.size - members)
    local anyOpen = e.roles.any and math.max(0, e.roles.any.d - e.roles.any.a) or 0
    e.need = { any = 0 }
    for _, role in ipairs(G.ROLES) do
        local rc = e.roles[role]
        local own = rc and math.max(0, rc.d - rc.a) or 0
        e.need[role] = math.min(free, own)
    end
    e.need.any = math.min(free, anyOpen)
    e.free = free
    return e
end

-- how long a listing has been up, and how long since anyone joined or left
local function Age(e, now)
    local s = state.seen[e.id]
    if not s then
        s = { first = now, members = e.members, changed = now }
        state.seen[e.id] = s
    elseif s.members ~= e.members then
        s.members, s.changed = e.members, now
    end
    s.last = now
    e.listedAt, e.changedAt = s.first, s.changed
end

local function ReadAll(task)
    local list = {}
    local now = G.Now()
    local ok, n = pcall(GetGroupFinderSearchNumListings)
    for i = 1, (ok and n or 0) do
        local e = Read(i, task)
        if e then
            Age(e, now)
            list[#list + 1] = e
        end
    end
    state.results[task.key] = { t = now, list = list }
    for id, s in pairs(state.seen) do
        if now - s.last > FORGET_AFTER then state.seen[id] = nil end
    end
end

-- you couldn't join this leader's group: it's likely gone (15 min)
local function MarkDead(account)
    local key = G.AccountKey(account)
    if key then
        state.dead[key] = G.Now()
        G.callbacks:FireCallbacks("FinderChanged")
    end
end

function Finder.IsDead(account)
    local key = G.AccountKey(account)
    local t = key and state.dead[key]
    if t and G.Now() - t > DEAD_FOR then
        state.dead[key] = nil
        return false
    end
    return t ~= nil
end

-- a refusal that says something about you (CP, role, DLC, code), not about the group being gone
local function AboutYou(result)
    return result == GROUP_FINDER_ACTION_RESULT_FAILED_CP_REQUIREMENT
        or result == GROUP_FINDER_ACTION_RESULT_FAILED_ROLE_REQUIREMENT
        or result == GROUP_FINDER_ACTION_RESULT_FAILED_ENTITLEMENT_REQUIREMENT
        or (GROUP_FINDER_ACTION_RESULT_FAILED_INCORRECT_INVITE_CODE ~= nil and result == GROUP_FINDER_ACTION_RESULT_FAILED_INCORRECT_INVITE_CODE)
end

-- ---------------------------------------------------------------------------
-- Searching

local function FindTask(key)
    for _, t in ipairs(Tasks()) do
        if t.key == key then return t end
    end
    -- a task from a category you just hid (an Apply still needs it)
    local cat, diff = key:match("^(%d+):(%d+)$")
    if cat then
        cat, diff = tonumber(cat), tonumber(diff)
        return { cat = cat, diff = diff, key = key, kind = KindOfCat(cat) }
    end
end

-- ---------------------------------------------------------------------------
-- The game's extra search filters (its Group Finder > "Additional filters": own role only, auto-
-- accept only, voice chat, invite code, CP, group size, playstyle, search text). They're stored by
-- the game and shared with Groupbound's searches: one tick in the game's menu hid groups from the
-- board. With sv.allListings Groupbound searches with them cleared, and puts YOUR filters back when
-- its search is done (or the game's menu opens), so the game's own menu keeps them.
-- (Calls read from esoui groupfinder_additionalfilters_keyboard.lua / groupfinder_shared.lua.)

local function SaveExtras()
    local function Get(fn)
        if not fn then return nil end
        local ok, v = pcall(fn)
        if ok then return v end
    end
    return {
        enforce = Get(DoesGroupFinderFilterRequireEnforceRoles),
        auto = Get(DoesGroupFinderFilterAutoAcceptRequests),
        voip = Get(DoesGroupFinderFilterRequireVOIP),
        code = Get(DoesGroupFinderFilterRequireInviteCode),
        champ = Get(DoesGroupFinderFilterRequireChampion),
        cp = Get(GetGroupFinderFilterChampionPoints),
        sizes = Get(GetGroupFinderFilterGroupSizes),
        styles = Get(GetGroupFinderFilterPlaystyles),
        text = Get(GetGroupFinderGroupFilterSearchString),
    }
end

local function SetIf(fn, v)
    if fn and v ~= nil then pcall(fn, v) end
end

local function ClearExtras()
    if ResetGroupFinderFilterOptionsToDefault then pcall(ResetGroupFinderFilterOptionsToDefault) end
    SetIf(SetGroupFinderFilterEnforceRoles, false)
    SetIf(SetGroupFinderFilterAutoAcceptRequests, false)
    SetIf(SetGroupFinderFilterRequiresVOIP, false)
    SetIf(SetGroupFinderFilterRequiresInviteCode, false)
    SetIf(SetGroupFinderFilterRequiresChampion, false)
    SetIf(SetGroupFinderGroupFilterSearchString, "")
end

-- your own filters back (after Groupbound's search)
local function RestoreExtras()
    local s = state.savedExtras
    if not s then return end
    state.savedExtras = nil
    SetIf(SetGroupFinderFilterEnforceRoles, s.enforce)
    SetIf(SetGroupFinderFilterAutoAcceptRequests, s.auto)
    SetIf(SetGroupFinderFilterRequiresVOIP, s.voip)
    SetIf(SetGroupFinderFilterRequiresInviteCode, s.code)
    SetIf(SetGroupFinderFilterRequiresChampion, s.champ)
    SetIf(SetGroupFinderFilterChampionPoints, s.cp)
    SetIf(SetGroupFinderFilterGroupSizeFlags, s.sizes)
    SetIf(SetGroupFinderFilterPlaystyleFlags, s.styles)
    SetIf(SetGroupFinderGroupFilterSearchString, s.text)
end

local function RunTask(task)
    local ok = pcall(function()
        if G.sv.allListings then
            -- (one snapshot until it's put back: never save Groupbound's own cleared state)
            state.savedExtras = state.savedExtras or SaveExtras()
            SetGroupFinderFilterCategory(task.cat)
            UpdateGroupFinderFilterOptions()
            ClearExtras()
        end
        SetGroupFinderFilterCategory(task.cat)
        UpdateGroupFinderFilterOptions()
        if task.diff > 0 then
            local n = GetGroupFinderFilterNumPrimaryOptions()
            if task.diff > n then error("no such difficulty") end
            SetGroupFinderFilterPrimaryOptionByIndex(task.diff, true)
        end
    end)
    state.lastRun[task.key] = G.Now()
    if not ok then
        RestoreExtras()
        return false
    end
    local okSearch, id = pcall(RequestGroupFinderSearch)
    if not okSearch or id == nil then
        RestoreExtras()
        return false
    end
    state.searchId, state.searchKey, state.busySince = id, task.key, G.Now()
    state.lastSearch = G.Now()
    state.clientKey = nil
    state.searches = state.searches + 1
    G.callbacks:FireCallbacks("FinderState")
    return true
end

local function Due(task, now)
    local last = state.lastRun[task.key] or 0
    if G.UI and G.UI.IsShown() then return true, last end
    if not G.sv.background or G.Quiet() then return false end
    return now - last >= BACKGROUND_EVERY, last
end

local function Tick()
    if not state.ready or not G.sv.sources.finder or not Finder.Unlocked() then return end
    if G.InBattleground() then return end
    local now = G.Now()
    -- the game's own menu shows: your filters must be there
    if GameMenuOpen() then RestoreExtras() end
    if state.busySince then
        if now - state.busySince < BUSY_TIMEOUT then return end
        state.busySince = nil
        RestoreExtras()
    end
    if GameMenuOpen() then return end
    if IsGroupFinderSearchOnCooldown and IsGroupFinderSearchOnCooldown() then return end
    if now - state.lastSearch < OPEN_GAP then return end
    -- an Apply waiting for its category comes first
    local pa = state.pendingApply
    if pa then
        local task = FindTask(pa.taskKey)
        if task and RunTask(task) then return end
        pa.tries = (pa.tries or 0) + 1
        if not task or pa.tries >= 3 then
            state.pendingApply = nil
            MarkDead(pa.account)
            G.Print(L("APPLY_GONE"))
            G.callbacks:FireCallbacks("FinderState")
        end
        return
    end
    -- the task that waited longest; the kind picked in the window's tree counts as waiting
    -- 30 s longer (searched more often)
    local best, bestLast
    local shown = G.UI and G.UI.IsShown()
    for _, task in ipairs(Tasks()) do
        local due, last = Due(task, now)
        if due and shown and task.kind == G.sv.view then last = last - 30 end
        if due and (not best or last < bestLast) then best, bestLast = task, last end
    end
    if best then RunTask(best) end
end

local function DoApply(index, pa)
    local function Get(fn, ...)
        local ok, a = pcall(fn, ...)
        if ok then return a end
    end
    local join = Get(GetGroupFinderSearchListingJoinabilityResult, index)
    if join == GROUP_FINDER_ACTION_RESULT_FAILED_ENTITLEMENT_REQUIREMENT then
        G.Print(L("APPLY_DLC"))
        return
    end
    if join ~= nil and join ~= GROUP_FINDER_ACTION_RESULT_SUCCESS then
        if not AboutYou(join) then MarkDead(pa.account) end
        G.Print(GetString("SI_GROUPFINDERACTIONRESULT", join))
        return
    end
    local needsCode = Get(DoesGroupFinderSearchListingRequireInviteCode, index)
    local code = pa.code and tonumber(pa.code)
    if needsCode and not code then
        -- the game's own Apply dialog asks for the invite code
        local okDialog = pcall(ZO_Dialogs_ShowPlatformDialog, "GROUP_FINDER_APPLICATION_KEYBOARD", ZO_GroupListingSearchData:New(index))
        if not okDialog then G.Print(L("APPLY_NEEDS_CODE")) end
        return
    end
    local ok, result
    if needsCode then
        ok, result = pcall(RequestApplyToGroupListing, index, pa.message or "", code)
    else
        ok, result = pcall(RequestApplyToGroupListing, index, pa.message or "")
    end
    if not ok then
        -- the game didn't let an addon do it: open the game's own Apply dialog instead
        local okDialog = pcall(ZO_Dialogs_ShowPlatformDialog, "GROUP_FINDER_APPLICATION_KEYBOARD", ZO_GroupListingSearchData:New(index))
        if not okDialog then G.Print(L("APPLY_FAILED")) end
        return
    end
    if result ~= GROUP_FINDER_ACTION_RESULT_SUCCESS then
        if not AboutYou(result) then MarkDead(pa.account) end
        G.Print(GetString("SI_GROUPFINDERACTIONRESULT", result))
        return
    end
    state.applyAccount = pa.account
    G.Board.MarkContacted(pa.entry, "applied")
end

-- finds the waiting Apply's group in the fresh result list and applies
local function ResolvePendingApply()
    local pa = state.pendingApply
    if not pa or state.clientKey ~= pa.taskKey then return end
    state.pendingApply = nil
    local res = state.results[pa.taskKey]
    for _, e in ipairs(res and res.list or {}) do
        if G.AccountKey(e.account) == G.AccountKey(pa.account) then
            DoApply(e.index, pa)
            return
        end
    end
    MarkDead(pa.account)
    G.Print(L("APPLY_GONE"))
end

local function OnSearchComplete(_, result, searchId)
    if searchId ~= state.searchId then
        -- someone else's search (the game's own menu): the game's list isn't ours any more
        state.clientKey = nil
        return
    end
    local task = FindTask(state.searchKey)
    state.busySince = nil
    state.searchId = nil
    if not task then return end
    state.clientGen = state.clientGen + 1
    state.clientKey = task.key
    state.lastId = searchId
    ReadAll(task)
    RestoreExtras()
    G.callbacks:FireCallbacks("FinderChanged")
    ResolvePendingApply()
end

-- live updates of the list the game holds (only while RequestSetGroupFinderExpectingUpdates is on)
local function OnSearchUpdated(_, searchId)
    if searchId ~= state.lastId or not state.clientKey then return end
    local task = FindTask(state.clientKey)
    if not task then return end
    ReadAll(task)
    G.callbacks:FireCallbacks("FinderChanged")
end

-- ---------------------------------------------------------------------------
-- Public

-- every listing from every category still fresh, one per leader (newest search wins)
function Finder.Entries()
    local out, seen = {}, {}
    local now = G.Now()
    local enabled = {}
    for _, t in ipairs(Tasks()) do enabled[t.key] = true end
    local keys = {}
    for key, res in pairs(state.results) do
        if enabled[key] and now - res.t <= STALE then keys[#keys + 1] = key end
    end
    table.sort(keys, function(a, b) return state.results[a].t > state.results[b].t end)
    for _, key in ipairs(keys) do
        for _, e in ipairs(state.results[key].list) do
            if not seen[e.id] then
                seen[e.id] = true
                out[#out + 1] = e
            end
        end
    end
    return out
end

-- apply to a listing; message = the note the leader sees; code = invite code (if asked)
function Finder.Apply(entry, message, code)
    if not entry or not entry.finder then return end
    local pa = { entry = entry, account = entry.account, taskKey = entry.taskKey, message = message, code = code }
    if state.clientKey == entry.taskKey and state.clientGen == entry.gen then
        local ok, leader = pcall(GetGroupFinderSearchListingLeaderDisplayNameByIndex, entry.index)
        if ok and G.AccountKey(leader) == G.AccountKey(entry.account) then
            DoApply(entry.index, pa)
            return
        end
    end
    -- the game holds another list now: search this category again first
    state.pendingApply = pa
    G.Print(L("APPLY_REFRESHING"))
    G.callbacks:FireCallbacks("FinderState")
    Tick()
end

function Finder.ApplyPending()
    return state.pendingApply ~= nil
end

-- your open application: title, leader (or nil)
function Finder.MyApplication()
    local applied = GROUP_FINDER_GROUP_LISTING_USER_TYPE_APPLIED_TO_GROUP_LISTING
    if not applied or not HasGroupListingForUserType then return nil end
    local ok, has = pcall(HasGroupListingForUserType, applied)
    if not ok or not has then return nil end
    local _, title = pcall(GetGroupFinderUserTypeGroupListingTitle, applied)
    local _, leader = pcall(GetGroupFinderUserTypeGroupListingLeaderDisplayName, applied)
    return { title = title or "", leader = leader or "" }
end

-- who your live application goes to, from the game itself: the leader's account key, false = no
-- application, nil = the game can't tell (old client). The board's "Applied" follows this.
function Finder.LiveApplication()
    if not GROUP_FINDER_GROUP_LISTING_USER_TYPE_APPLIED_TO_GROUP_LISTING or not HasGroupListingForUserType then return nil end
    local app = Finder.MyApplication()
    if not app then return false end
    return G.AccountKey(app.leader) or false
end

function Finder.Rescind()
    pcall(RequestResolveGroupListingApplication, RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_RESCIND)
end

-- your own listing (or nil)
-- ---------------------------------------------------------------------------
-- Test mode (/gb test applicants): a made-up listing with three made-up applicants, so the
-- Applicants page, its keys and the notice can be checked without other players. Nothing is sent
-- to the game while it's on (accept / decline only print).

function Finder.StartTest()
    local now = G.Now()
    Finder.test = { started = now, apps = {
        { id = "test1", key = "test1", account = "@TestTank", char = "Tanky McShield", classId = 1, level = 50, cp = 1900,
          role = "tank", note = "vSS HM clear, have Godslayer", leftAt = now + 290 },
        { id = "test2", key = "test2", account = "@TestHealer", char = "Healer Person", classId = 6, level = 50, cp = 820,
          role = "heal", note = "", leftAt = now + 45 },
        { id = "test3", key = "test3", account = "@TestDamage", char = "Damage Dealer", classId = 3, level = 50, cp = 2100,
          role = "dps", note = "First time on HM but I know all the mechanics, have all trial sets and food ready.", leftAt = now + 200 },
    } }
    G.callbacks:FireCallbacks("FinderState")
    G.callbacks:FireCallbacks("ApplicantsChanged", Finder.Applicants()[1])
end

function Finder.StopTest()
    Finder.test = nil
    G.callbacks:FireCallbacks("FinderState")
    G.callbacks:FireCallbacks("ApplicantsChanged", nil)
end

function Finder.MyListing()
    if Finder.test then return { title = "Sunspire Veteran HM (test)" } end
    local created = GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING
    if not created or not HasGroupListingForUserType then return nil end
    local ok, has = pcall(HasGroupListingForUserType, created)
    if not ok or not has then return nil end
    local _, title = pcall(GetGroupFinderUserTypeGroupListingTitle, created)
    return { title = title or "" }
end

function Finder.RemoveListing()
    if Finder.test then
        Finder.StopTest()
        G.Print(L("TEST_OFF"))
        return
    end
    pcall(RequestRemoveGroupListing)
end

-- a title the game accepts: letters, spaces, few signs, ends with a letter
local function SafeTitle(text)
    local t = (text or ""):gsub("[^%w\128-\255 ]", " ")
    t = t:gsub("%s+", " ")
    t = zo_strtrim(t)
    if #t > 40 then
        t = t:sub(1, 40):gsub("%s+%S*$", "")
        t = zo_strtrim(t)
    end
    t = t:gsub("[^%a\128-\255]+$", "")
    return t
end

-- ---------------------------------------------------------------------------
-- The game's own listing choices (as its Create Group panel offers them, esoui groupfinder_shared
-- / groupfinderdata.lua): categories, the options of a category (difficulty / run / zone...),
-- group sizes and playstyles. Reading them sets up the game's listing draft (only Groupbound and
-- the game's own Create panel use it).

local function Flags(first, last)
    local out = {}
    if not first or not last then return out end
    if ZO_FlagHelpers and ZO_FlagHelpers.FlagIterator then
        for flag in ZO_FlagHelpers.FlagIterator(first, last) do out[#out + 1] = flag end
    else
        local f = first
        while f <= last do
            out[#out + 1] = f
            f = f * 2
        end
    end
    return out
end

-- { { value, name } } of every Group Finder category
function Finder.Categories()
    local out = {}
    local first, last = GROUP_FINDER_CATEGORY_ITERATION_BEGIN, GROUP_FINDER_CATEGORY_ITERATION_END
    if not first or not last then return out end
    for cat = first, last do
        local name = GetString("SI_GROUPFINDERCATEGORY", cat)
        if name and name ~= "" then out[#out + 1] = { value = cat, name = name } end
    end
    return out
end

function Finder.HasDifficulty(cat) return HasDifficulty(cat) end

-- the draft set to a category (and primary option): its primary options, secondary options and
-- group sizes, each { { value, name } }
function Finder.DraftChoices(cat, primaryIdx)
    local DRAFT = GROUP_FINDER_GROUP_LISTING_USER_TYPE_GROUP_LISTING_DRAFT
    local res = { primaries = {}, secondaries = {}, sizes = {} }
    if not DRAFT or cat == nil then return res end
    pcall(function()
        SetGroupFinderUserTypeGroupListingCategory(DRAFT, cat)
        UpdateGroupFinderUserTypeGroupListingOptions(DRAFT)
        for i = 1, GetGroupFinderUserTypeGroupListingNumPrimaryOptions(DRAFT) do
            local name = GetGroupFinderUserTypeGroupListingPrimaryOptionByIndex(DRAFT, i)
            res.primaries[#res.primaries + 1] = { value = i, name = name or tostring(i) }
        end
        if primaryIdx and primaryIdx <= #res.primaries then
            SetGroupFinderUserTypeGroupListingPrimaryOption(DRAFT, primaryIdx)
        end
        for i = 1, GetGroupFinderUserTypeGroupListingNumSecondaryOptions(DRAFT) do
            local name = GetGroupFinderUserTypeGroupListingSecondaryOptionByIndex(DRAFT, i)
            res.secondaries[#res.secondaries + 1] = { value = i, name = name or tostring(i) }
        end
        if GetGroupFinderUserTypeGroupSizeIterationBegin then
            for _, flag in ipairs(Flags(GetGroupFinderUserTypeGroupSizeIterationBegin(DRAFT), GetGroupFinderUserTypeGroupSizeIterationEnd(DRAFT))) do
                res.sizes[#res.sizes + 1] = { value = flag, name = GetString("SI_GROUPFINDERGROUPSIZE", flag) }
            end
        end
    end)
    return res
end

-- { { value, name } } of the playstyles
function Finder.Playstyles()
    local out = {}
    for _, flag in ipairs(Flags(GROUP_FINDER_PLAYSTYLE_ITERATION_BEGIN, GROUP_FINDER_PLAYSTYLE_ITERATION_END)) do
        out[#out + 1] = { value = flag, name = GetString("SI_GROUPFINDERPLAYSTYLE", flag) }
    end
    return out
end

-- spec = { key, vet, hm, need = { tank, heal, dps }, cp, title, desc }
--   (or total = { tank, heal, dps }: the whole group's roles; "List again" uses it, so roles that
--   joined since count as filled)
--   + the game's own options (all optional, the post page sets them): cat (category, else from
--   the run), primaryIdx / secondaryIdx (the category's options; else difficulty from vet and the
--   run by name), size (group size flag), playstyle (flag), voip, auto (auto-accept), enforce
--   (roles; default on when roles are given), code (invite code number)
-- editing = change your listing that's up (like the game's Edit: the same draft, then
-- RequestEditGroupListing; the category stays the listing's own)
-- returns true, or false + the reason (shown to you)
function Finder.CreateListing(spec, editing)
    if not Finder.Unlocked() or not RequestCreateGroupListing then return false, L("POST_FINDER_LOCKED") end
    local DRAFT = GROUP_FINDER_GROUP_LISTING_USER_TYPE_GROUP_LISTING_DRAFT
    local CREATED = GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING
    if editing then
        if not Finder.MyListing() or Finder.test then return false, L("POST_NO_LISTING") end
        if not RequestEditGroupListing then return false, L("POST_FAILED") end
    else
        if Finder.MyListing() then return false, L("POST_HAVE_LISTING") end
        if Finder.MyApplication() then return false, L("POST_HAVE_APPLICATION") end
    end
    if not IsUnitSoloOrGroupLeader("player") then return false, GetString(SI_GROUP_FINDER_CREATE_GROUP_DISABLED_NOT_LEADER) end
    local cat = spec.cat or Content.Category(spec.key) or GROUP_FINDER_CATEGORY_CUSTOM
    if editing then
        local okCat, liveCat = pcall(GetGroupFinderUserTypeGroupListingCategory, CREATED)
        if okCat and liveCat ~= nil then cat = liveCat end
    end
    local title = SafeTitle(spec.title)
    local violations = { IsValidGroupFinderListingTitle(title) }
    if #violations > 0 then return false, GetString(SI_GROUP_FINDER_CREATE_INVALID_TITLE_TOOLTIP) end

    local function Try(fn, ...)
        if fn then pcall(fn, ...) end
    end

    local why
    local ok, err = pcall(function()
        SetGroupFinderUserTypeGroupListingCategory(DRAFT, cat)
        UpdateGroupFinderUserTypeGroupListingOptions(DRAFT)
        local numPrimary = GetGroupFinderUserTypeGroupListingNumPrimaryOptions(DRAFT)
        -- primary option: picked by you, else the difficulty from what you typed
        if spec.primaryIdx and spec.primaryIdx <= numPrimary then
            SetGroupFinderUserTypeGroupListingPrimaryOption(DRAFT, spec.primaryIdx)
            if HasDifficulty(cat) and SetVeteranDifficulty then
                SetVeteranDifficulty(spec.primaryIdx == (DUNGEON_DIFFICULTY_VETERAN or 2))
            end
        elseif HasDifficulty(cat) then
            local diff = spec.vet and (DUNGEON_DIFFICULTY_VETERAN or 2) or (DUNGEON_DIFFICULTY_NORMAL or 1)
            if diff <= numPrimary then
                SetGroupFinderUserTypeGroupListingPrimaryOption(DRAFT, diff)
                -- (the game's Create panel sets your difficulty to match)
                if SetVeteranDifficulty then SetVeteranDifficulty(spec.vet and true or false) end
            end
        end
        -- secondary option (the run / zone / campaign): picked by you, else the run you typed by name,
        -- else the game's default
        local numSecondary = GetGroupFinderUserTypeGroupListingNumSecondaryOptions(DRAFT)
        if spec.secondaryIdx and spec.secondaryIdx <= numSecondary then
            SetGroupFinderUserTypeGroupListingSecondaryOption(DRAFT, spec.secondaryIdx)
        elseif spec.key and Content.Category(spec.key) == cat and numSecondary > 0 then
            local found = false
            for i = 1, numSecondary do
                local name = GetGroupFinderUserTypeGroupListingSecondaryOptionByIndex(DRAFT, i)
                if Content.FromName(name) == spec.key then
                    SetGroupFinderUserTypeGroupListingSecondaryOption(DRAFT, i)
                    found = true
                    break
                end
            end
            if not found then
                why = L("POST_NOT_IN_FINDER", Content.Name(spec.key))
                return
            end
        elseif numSecondary > 0 then
            Try(SetGroupFinderUserTypeGroupListingSecondaryOptionDefault, DRAFT)
        end
        -- group size before the roles (it sets how many places there are)
        if spec.size then Try(SetGroupFinderUserTypeGroupListingGroupSize, DRAFT, spec.size) end
        SetGroupFinderUserTypeGroupListingTitle(DRAFT, title)
        SetGroupFinderUserTypeGroupListingDescription(DRAFT, spec.desc or "")
        if spec.playstyle then Try(SetGroupFinderUserTypeGroupListingPlaystyle, DRAFT, spec.playstyle) end
        Try(SetGroupFinderUserTypeGroupListingRequiresVOIP, DRAFT, spec.voip and true or false)
        Try(SetGroupFinderUserTypeGroupListingAutoAcceptRequests, DRAFT, spec.auto and true or false)
        -- invite code (a code left in the draft from the game's own panel would block the listing)
        local code = tonumber(spec.code)
        Try(SetGroupFinderUserTypeGroupListingRequiresInviteCode, DRAFT, code ~= nil)
        if code then Try(SetGroupFinderUserTypeGroupListingInviteCode, DRAFT, code) end
        local cp = spec.cp or 0
        SetGroupFinderUserTypeGroupListingRequiresChampion(DRAFT, cp > 0)
        if cp > 0 then SetGroupFinderUserTypeGroupListingChampionPoints(DRAFT, cp) end
        -- roles: places for the roles you need (on top of the ones your group has), rest "any"
        local need = spec.need or {}
        local wanted = (need.tank or 0) + (need.heal or 0) + (need.dps or 0)
        if spec.total then
            wanted = 0
            for _, role in ipairs(G.ROLES) do
                local have = GetGroupFinderUserTypeGroupListingAttainedRoleCount(DRAFT, G.LfgRole(role))
                wanted = wanted + math.max(0, (spec.total[role] or 0) - have)
            end
        end
        -- "Enforce roles" off: anyone may join in any role (the game's checkbox)
        if spec.enforce == false then wanted = 0 end
        SetGroupFinderUserTypeGroupListingEnforceRoles(DRAFT, wanted > 0)
        if wanted > 0 then
            local places = GetGroupFinderUserTypeGroupListingNumRoles(DRAFT)
            local total = 0
            local desired = {}
            for _, role in ipairs(G.ROLES) do
                local lfg = G.LfgRole(role)
                local have = GetGroupFinderUserTypeGroupListingAttainedRoleCount(DRAFT, lfg)
                if spec.total then
                    desired[role] = math.max(have, spec.total[role] or 0)
                else
                    desired[role] = have + (need[role] or 0)
                end
                total = total + desired[role]
            end
            spec.total = desired
            if total > places then
                why = L("POST_TOO_MANY", places)
                return
            end
            for _, role in ipairs(G.ROLES) do
                SetGroupFinderUserTypeGroupListingRoleCount(DRAFT, G.LfgRole(role), desired[role])
            end
            SetGroupFinderUserTypeGroupListingRoleCount(DRAFT, LFG_ROLE_INVALID, places - total)
        end
        if ZO_GroupFinder_CanDoCreateEdit and ZO_GroupListingUserTypeData then
            local can, reason = ZO_GroupFinder_CanDoCreateEdit(ZO_GroupListingUserTypeData:New(DRAFT), nil, editing and true or nil)
            if not can then
                why = reason or L("POST_FAILED")
                return
            end
        end
        if editing then RequestEditGroupListing() else RequestCreateGroupListing() end
    end)
    if not ok then
        G.ReportError("Finder", err, true)
        return false, L("POST_FAILED")
    end
    if why then return false, why end
    -- remembered for "List again"
    G.sv.lastListing = { key = spec.key, vet = spec.vet, hm = spec.hm, cp = spec.cp, title = spec.title,
        desc = spec.desc, total = spec.total, t = G.Now(), cat = spec.cat, primaryIdx = spec.primaryIdx,
        secondaryIdx = spec.secondaryIdx, size = spec.size, playstyle = spec.playstyle, voip = spec.voip,
        auto = spec.auto, enforce = spec.enforce, code = spec.code, ownDesc = spec.ownDesc }
    if editing then return true end
    -- the game's known bug: the request goes through but the listing never shows (it happens
    -- after someone left a full group); only a zone change fixes it
    local asked = G.Now()
    state.createAt = asked
    G.Later(function()
        if state.createAt ~= asked then return end
        state.createAt = nil
        if not Finder.MyListing() then G.Print(L("LISTING_BUG")) end
        G.callbacks:FireCallbacks("FinderState")
    end, LISTING_CHECK_MS, "Finder")
    return true
end

-- your last listing (for "List again"), or nil
function Finder.LastListing()
    local last = G.sv.lastListing
    if not last or not last.title then return nil end
    return last
end

-- "List again": the same listing, with the roles still missing now
function Finder.Relist()
    if Finder.MyListing() then
        G.Print(L("POST_HAVE_LISTING"))
        return
    end
    local last = Finder.LastListing()
    if not last then
        G.Print(L("RELIST_NONE"))
        return
    end
    local spec = ZO_ShallowTableCopy(last)
    spec.total = last.total and ZO_ShallowTableCopy(last.total) or nil
    local ok, why = Finder.CreateListing(spec)
    if not ok then G.Print(why or L("POST_FAILED")) end
end

-- ---------------------------------------------------------------------------
-- Applicants to your listing

local function NextApplicant(_, last)
    return GetNextGroupListingApplicationCharacterId(last)
end

-- { id, account, char, classId, level, cp, role (our name), note, left (s), pending }
function Finder.Applicants()
    local list = {}
    if Finder.test then
        for _, a in ipairs(Finder.test.apps) do
            local copy = ZO_ShallowTableCopy(a)
            copy.left = math.max(0, a.leftAt - G.Now())
            list[#list + 1] = copy
        end
        table.sort(list, function(a, b) return a.left < b.left end)
        return list
    end
    if not GetNextGroupListingApplicationCharacterId or not Finder.MyListing() then return list end
    local ok = pcall(function()
        for charId in NextApplicant do
            local account, char, classId, level, cp, lfg = GetGroupListingApplicationInfoByCharacterId(charId)
            local a = { id = charId, key = tostring(charId), account = account or "", char = char or "",
                classId = classId, level = level or 0, cp = cp or 0 }
            a.role = lfg == LFG_ROLE_TANK and "tank" or (lfg == LFG_ROLE_HEAL and "heal" or "dps")
            local okNote, note = pcall(GetGroupListingApplicationNoteByCharacterId, charId)
            a.note = okNote and note or ""
            local okLeft, left = pcall(GetGroupListingApplicationTimeRemainingSecondsByCharacterId, charId)
            a.left = okLeft and left or nil
            local okPending, pending = pcall(IsGroupListingApplicationPendingByCharacterId, charId)
            a.pending = okPending and pending or false
            list[#list + 1] = a
        end
    end)
    if not ok then return {} end
    table.sort(list, function(a, b) return (a.left or 0) < (b.left or 0) end)
    return list
end

-- accept (true) or decline (false) one application
function Finder.Resolve(applicant, accept)
    if not applicant then return end
    if Finder.test then
        for i, a in ipairs(Finder.test.apps) do
            if a.key == applicant.key then table.remove(Finder.test.apps, i) break end
        end
        G.Print(L(accept and "TEST_ACCEPTED" or "TEST_DECLINED", applicant.account))
        G.callbacks:FireCallbacks("ApplicantsChanged", nil)
        return
    end
    local how = accept and RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_APPROVE or RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_REJECT
    if how == nil then return end
    pcall(RequestResolveGroupListingApplication, how, applicant.id)
end

-- whether your listing lets everyone in by itself (then there's nothing to decide)
function Finder.MyListingAutoAccepts()
    if Finder.test then return false end
    local created = GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING
    if not created or not DoesGroupFinderUserTypeGroupListingAutoAcceptRequests then return false end
    local ok, yes = pcall(DoesGroupFinderUserTypeGroupListingAutoAcceptRequests, created)
    return ok and yes or false
end

-- members / places of your listing
function Finder.MyListingSize()
    if Finder.test then return 6, 12 end
    local created = GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING
    local places = 0
    local okN, n = pcall(GetGroupFinderUserTypeGroupListingNumRoles, created)
    if okN and n then places = n end
    local have = 0
    for _, lfg in ipairs({ LFG_ROLE_TANK, LFG_ROLE_HEAL, LFG_ROLE_DPS }) do
        local ok, a = pcall(GetGroupFinderUserTypeGroupListingAttainedRoleCount, created, lfg)
        if ok and a then have = have + a end
    end
    return have, places
end

-- new applications since the last look: tells the board and the on-screen notice
-- (silent: after logging in, the ones already waiting aren't announced as new)
local function CheckApplicants(silent)
    local list = Finder.Applicants()
    local now = {}
    local newest
    for _, a in ipairs(list) do
        now[a.key] = true
        if not state.knownApps[a.key] then newest = a end
    end
    state.knownApps = now
    G.callbacks:FireCallbacks("ApplicantsChanged", silent ~= true and newest or nil)
end

-- "searching..." / "updated 12 s ago" for the window header
function Finder.StatusText()
    if not G.sv.sources.finder then return L("FINDER_OFF") end
    if not Finder.Unlocked() then return L("FINDER_LOCKED") end
    if GameMenuOpen() then return L("FINDER_PAUSED") end
    if not state.ready then return L("FINDER_WAITING") end
    if state.pendingApply then return L("FINDER_APPLYING") end
    if state.busySince then return L("FINDER_SEARCHING") end
    local newest
    for _, res in pairs(state.results) do
        if not newest or res.t > newest then newest = res.t end
    end
    if not newest then return L("FINDER_WAITING") end
    return L("FINDER_UPDATED", G.Ago(newest))
end

function Finder.PrintDebug()
    G.Print(string.format("Finder: supported %s, unlocked %s, searches %d, client list %s, busy %s",
        tostring(Supported()), tostring(Finder.Unlocked()), state.searches, tostring(state.clientKey),
        tostring(state.busySince ~= nil)))
    for key, res in pairs(state.results) do
        d(string.format("  %s: %d listings, %s", key, #res.list, G.Ago(res.t)))
    end
    local n = 0
    for _ in pairs(G.Chat.Posts()) do n = n + 1 end
    d("  chat posts kept: " .. n)
end

-- the window shows: ask the game for live updates of the list it holds
function Finder.SetWatching(on)
    if RequestSetGroupFinderExpectingUpdates then pcall(RequestSetGroupFinderExpectingUpdates, on and true or false) end
    if on then Tick() end
end

function Finder.Init()
    if not Supported() then return end
    ROLE_LFG = { tank = LFG_ROLE_TANK, heal = LFG_ROLE_HEAL, dps = LFG_ROLE_DPS, any = LFG_ROLE_INVALID }
    G.EM:RegisterForEvent("Groupbound_Finder", EVENT_GROUP_FINDER_SEARCH_COMPLETE, OnSearchComplete)
    G.EM:RegisterForEvent("Groupbound_FinderUpd", EVENT_GROUP_FINDER_SEARCH_UPDATED, OnSearchUpdated)
    if EVENT_GROUP_FINDER_REFRESH_SEARCH then
        G.EM:RegisterForEvent("Groupbound_FinderRefresh", EVENT_GROUP_FINDER_REFRESH_SEARCH, function()
            if state.clientKey then state.lastRun[state.clientKey] = 0 end
        end)
    end
    G.EM:RegisterForEvent("Groupbound_FinderApply", EVENT_GROUP_FINDER_APPLY_TO_GROUP_LISTING_RESULT, function(_, result)
        if result ~= nil and result ~= GROUP_FINDER_ACTION_RESULT_SUCCESS then
            if state.applyAccount and not AboutYou(result) then MarkDead(state.applyAccount) end
            G.Print(GetString("SI_GROUPFINDERACTIONRESULT", result))
        end
        state.applyAccount = nil
        G.callbacks:FireCallbacks("FinderState")
    end)
    -- applications to your listing
    local function AppsSoon() G.Later(CheckApplicants, 200, "Finder") end
    if EVENT_GROUP_FINDER_UPDATE_APPLICATIONS then
        G.EM:RegisterForEvent("Groupbound_FinderApps", EVENT_GROUP_FINDER_UPDATE_APPLICATIONS, AppsSoon)
    end
    if EVENT_GROUP_FINDER_APPLICATION_RECEIVED then
        G.EM:RegisterForEvent("Groupbound_FinderAppNew", EVENT_GROUP_FINDER_APPLICATION_RECEIVED, AppsSoon)
    end
    local function StateChanged() G.callbacks:FireCallbacks("FinderState") end
    if EVENT_GROUP_FINDER_RESOLVE_GROUP_LISTING_APPLICATION_RESULT then
        G.EM:RegisterForEvent("Groupbound_FinderResolve", EVENT_GROUP_FINDER_RESOLVE_GROUP_LISTING_APPLICATION_RESULT, StateChanged)
    end
    if EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_APPLICATION then
        G.EM:RegisterForEvent("Groupbound_FinderRemoveApp", EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_APPLICATION, StateChanged)
    end
    G.EM:RegisterForEvent("Groupbound_FinderCreate", EVENT_GROUP_FINDER_CREATE_GROUP_LISTING_RESULT, function(_, result)
        if result == GROUP_FINDER_ACTION_RESULT_SUCCESS then
            G.Print(L("POST_LISTED"))
        elseif result ~= nil then
            -- refused (the reason is printed): no "listing never showed" note on top
            state.createAt = nil
            G.Print(L("POST_REFUSED", GetString("SI_GROUPFINDERACTIONRESULT", result)))
        end
        G.callbacks:FireCallbacks("FinderState")
        AppsSoon()
    end)
    if EVENT_GROUP_FINDER_UPDATE_GROUP_LISTING_RESULT then
        G.EM:RegisterForEvent("Groupbound_FinderEdit", EVENT_GROUP_FINDER_UPDATE_GROUP_LISTING_RESULT, function(_, result)
            if result == GROUP_FINDER_ACTION_RESULT_SUCCESS then
                G.Print(L("POST_UPDATED"))
            elseif result ~= nil then
                G.Print(L("POST_REFUSED", GetString("SI_GROUPFINDERACTIONRESULT", result)))
            end
            G.callbacks:FireCallbacks("FinderState")
        end)
    end
    G.EM:RegisterForEvent("Groupbound_FinderRemove", EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_RESULT, function()
        StateChanged()
        AppsSoon()
    end)
    G.EM:RegisterForUpdate("Groupbound_FinderTick", 1000, Tick)
    -- no searches until the character is in the world (5 s after the first load screen)
    G.EM:RegisterForEvent("Groupbound_FinderReady", EVENT_PLAYER_ACTIVATED, function()
        G.EM:UnregisterForEvent("Groupbound_FinderReady", EVENT_PLAYER_ACTIVATED)
        CheckApplicants(true)
        G.Later(function() state.ready = true end, 5000, "Finder")
    end)
end
