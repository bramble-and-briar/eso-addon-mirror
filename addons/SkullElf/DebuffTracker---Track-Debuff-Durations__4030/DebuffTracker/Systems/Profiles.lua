-- Profiles: named sets of trackers. The active profile can be account-wide or remembered per
-- character, and auto-switch rules can change it by role, zone type, class or character.

local DT = DebuffTracker
local P = DT.Profiles
local U = DT.Util
local S = DT.Schema
local L = DT.L

P.SV_DEFAULTS = {
    schema = 1,
    profiles = {},
    activeProfile = "Default",
    perCharacter = false,
    characterProfiles = {},
    autoSwitch = { enabled = false, rules = {} },
    settings = {
        gridSize = 16,
        snapToGrid = true,
        showGrid = true,
        alertY = 160,
        alertFontSize = 30,
        editorHeight = 720,
        lastTab = 1,
        testInEditor = true,
        editorPinned = true,        -- the editor stays on screen while you play (Pin); the X closes it
        skillTooltipIds = true,     -- add "Ability ID" to skill tooltips in the Skills window
        headHeight = 2.6,       -- metres above the feet
        headMaxDistance = 40,   -- metres
        headFade = true,        -- fade out near the max distance
        headShrink = true,      -- smaller when far away
        enemyMarker = false,    -- red arrow over enemies you fight (see Display/Marker.lua)
        enemyMarkerSize = 32,
        followTabTarget = true,     -- "my target" keeps your tab target when you look away (DT.TabTarget)
        penTargetResist = 0,        -- the enemy armour penetration is compared with; 0 = by zone (18200 instanced, 9100 overland)
        penCrusher = 2108,          -- Crusher on the enemy (infused; 1622 plain, 2740 with Torug's Pact)
        penAlkosh = 6000,           -- Roar of Alkosh on the enemy (up to 6000, with the wearer's weapon damage)
        penTremorscale = 2640,      -- Tremorscale on the enemy (scales with the tank's armour)
        penAnthelmir = 2000,        -- Anthelmir's Construct on the enemy (scales with the wearer's weapon damage)
    },
    migratedFromV4 = false,
    enemyDifficulty = {},       -- [zoneId][enemy name] = difficulty, learned in play (and from the old version)
    seenWelcome = false,
    debugLog = {},              -- "/dt debug" lines (see U.Debug)
}

local sv

local function CharacterId()
    if type(GetCurrentCharacterId) == "function" then return tostring(GetCurrentCharacterId()) end
    return GetUnitName("player")
end

function P.Initialize(savedVars)
    sv = savedVars
    U.ApplyDefaults(sv, P.SV_DEFAULTS)
    if next(sv.profiles) == nil then
        sv.profiles["Default"] = { trackers = {}, order = {} }
    end
    if not sv.profiles[P.ActiveName()] then
        P.SetActiveName(U.SortedKeys(sv.profiles)[1])
    end
    for _, profile in pairs(sv.profiles) do P.Repair(profile) end
    if not sv.heatShockFix then
        for _, profile in pairs(sv.profiles) do P.HeatShockFix(profile) end
        sv.heatShockFix = true
    end
end

-- Update 49 (March 2026): Stone Giant became Magma Fist -- no projectile any more, and its debuff is Heat Shock 134340
-- instead of Stagger 134336 (Systems/Migration.lua M.StaggerTracker). Trackers made for Stagger get Heat Shock added,
-- and the "grey until the projectile (133027) is on the bar" rule goes (it would keep the icon grey for ever).
-- Once per saved data.
function P.HeatShockFix(profile)
    local n = 0
    for _, t in pairs(profile.trackers or {}) do
        if type(t) == "table" and type(t.trigger) == "table" then
            local triggers = { t.trigger }
            for _, x in ipairs(t.extraTriggers or {}) do if type(x) == "table" then triggers[#triggers + 1] = x end end
            local had = false
            for _, tr in ipairs(triggers) do
                local ids = type(tr.abilityIds) == "table" and tr.abilityIds or {}
                if U.Contains(ids, 134336) and not U.Contains(ids, 134340) then ids[#ids + 1] = 134340; had = true end
            end
            if had then
                n = n + 1
                if t.name == "Stagger (Stone Giant)" then t.name = "Heat Shock (Magma Fist)" end
                local keep = {}
                for _, r in ipairs(t.conditions or {}) do
                    if not (r.prop == "onBar" and r.action == "grey" and tostring(r.value):find("133027", 1, true)) then keep[#keep + 1] = r end
                end
                t.conditions = keep
            end
        end
    end
    return n
end

function P.SV() return sv end
function P.Settings() return (sv and sv.settings) or P.SV_DEFAULTS.settings end

-- Normalizes every tracker and makes `order` list exactly the tracker ids.
function P.Repair(profile)
    profile.trackers = type(profile.trackers) == "table" and profile.trackers or {}
    profile.order = type(profile.order) == "table" and profile.order or {}
    local byId = {}
    for key, t in pairs(profile.trackers) do
        if type(t) == "table" then
            S.Normalize(t)
            if t.id ~= key then t.id = tostring(key) end
            byId[t.id] = t
        else
            profile.trackers[key] = nil
        end
    end
    local order, seen = {}, {}
    for _, id in ipairs(profile.order) do
        if byId[id] and not seen[id] then seen[id] = true; order[#order + 1] = id end
    end
    for _, id in ipairs(U.SortedKeys(byId)) do
        if not seen[id] then order[#order + 1] = id end
    end
    profile.order = order
    for _, t in pairs(byId) do
        if t.position.anchorTo ~= "" and not byId[t.position.anchorTo] then t.position.anchorTo = "" end
    end
    return profile
end

------------------------------------------------------------------------------
-- Active profile
------------------------------------------------------------------------------

function P.ActiveName()
    if sv.perCharacter then
        return sv.characterProfiles[CharacterId()] or sv.activeProfile
    end
    return sv.activeProfile
end

function P.SetActiveName(name)
    if sv.perCharacter then sv.characterProfiles[CharacterId()] = name end
    sv.activeProfile = name
end

function P.Active()
    local p = sv.profiles[P.ActiveName()]
    if not p then
        p = { trackers = {}, order = {} }
        sv.profiles[P.ActiveName()] = p
    end
    return p
end

function P.ActiveTrackers()
    local p = P.Active()
    local list = {}
    for _, id in ipairs(p.order) do
        local t = p.trackers[id]
        if t then list[#list + 1] = t end
    end
    return list
end

function P.Get(id)
    return P.Active().trackers[id]
end

function P.Names()
    return U.SortedKeys(sv.profiles, function(a, b) return U.Lower(a) < U.Lower(b) end)
end

local function Changed()
    DT.Engine.Rebuild()
    if DT.UI.OnProfileChanged then DT.UI.OnProfileChanged() end
end

function P.SetActive(name, quiet)
    if not sv.profiles[name] or name == P.ActiveName() then return false end
    P.SetActiveName(name)
    Changed()
    if not quiet then U.Print(L("Profile: <<1>>", name)) end
    return true
end

function P.SetPerCharacter(on)
    local current = P.ActiveName()
    sv.perCharacter = on == true
    P.SetActiveName(current)
end

------------------------------------------------------------------------------
-- Profile management
------------------------------------------------------------------------------

local function UniqueName(base)
    base = U.Trim(base) ~= "" and U.Trim(base) or L("Profile")
    if not sv.profiles[base] then return base end
    local i = 2
    while sv.profiles[base .. " " .. i] do i = i + 1 end
    return base .. " " .. i
end
P.UniqueName = UniqueName

function P.Create(name, copyFrom)
    name = UniqueName(name)
    local profile
    if copyFrom and sv.profiles[copyFrom] then
        profile = U.Copy(sv.profiles[copyFrom])
    else
        profile = { trackers = {}, order = {} }
    end
    sv.profiles[name] = P.Repair(profile)
    return name
end

function P.Rename(old, new)
    new = U.Trim(new)
    if new == "" or not sv.profiles[old] or sv.profiles[new] then return false end
    sv.profiles[new] = sv.profiles[old]
    sv.profiles[old] = nil
    if sv.activeProfile == old then sv.activeProfile = new end
    for char, name in pairs(sv.characterProfiles) do
        if name == old then sv.characterProfiles[char] = new end
    end
    for _, r in ipairs(sv.autoSwitch.rules) do
        if r.profile == old then r.profile = new end
    end
    if DT.UI.OnProfileChanged then DT.UI.OnProfileChanged() end
    return true
end

function P.Delete(name)
    if not sv.profiles[name] or U.Count(sv.profiles) <= 1 then return false end
    local wasActive = name == P.ActiveName()
    sv.profiles[name] = nil
    for char, n in pairs(sv.characterProfiles) do
        if n == name then sv.characterProfiles[char] = nil end
    end
    if not sv.profiles[sv.activeProfile] then sv.activeProfile = P.Names()[1] end
    if wasActive then Changed() elseif DT.UI.OnProfileChanged then DT.UI.OnProfileChanged() end
    return true
end

------------------------------------------------------------------------------
-- Trackers in the active profile
------------------------------------------------------------------------------

-- New trackers cascade down-right from the center so they never spawn on top of each other.
-- A new tracker's spot: a small staircase left of the screen centre -- or, with the editor open, right of the editor
-- (Casual player Geldis: a new tracker "places over main window by default"; the editor is 1180 wide from the left
-- edge, so the old spot was under it on most screens).
local function DefaultPosition(tracker, profile)
    local n = #profile.order
    local x, y = -300 + (n % 8) * 40, -200 + (n % 8) * 40
    local ui = DT.UI
    if ui and ui.window and ui.IsShowing and ui.IsShowing() and ui.window.GetRight then
        local half = GuiRoot:GetWidth() / 2
        local free = ui.window:GetRight() + 30 - half             -- the editor's right edge, from the centre
        local w = tracker.display.width or 260
        if free + w + 8 * 30 < half then
            x = math.floor(free + (n % 8) * 30)
            if tracker.display.grow == "left" then x = x + w end   -- anchored by its right edge
        end
    end
    tracker.position.x, tracker.position.y = x, y
end

function P.AddTracker(tracker, keepPosition)
    local profile = P.Active()
    tracker = S.Normalize(tracker)
    while profile.trackers[tracker.id] do tracker.id = U.NewId("t") end
    if not keepPosition then DefaultPosition(tracker, profile) end
    profile.trackers[tracker.id] = tracker
    profile.order[#profile.order + 1] = tracker.id
    Changed()
    return tracker
end

-- Several at once (presets/bundles), keeping anchors between them by remapping ids.
function P.AddTrackers(list)
    local profile = P.Active()
    local remap, byName = {}, {}
    local added = {}
    for _, t in ipairs(list) do
        local oldId = t.id
        t = S.Normalize(U.Copy(t))
        local newId = U.NewId("t")
        while profile.trackers[newId] do newId = U.NewId("t") end
        if type(oldId) == "string" and oldId ~= "" then remap[oldId] = newId end
        -- hand-written / AI-written bundles may attach by the other tracker's name
        if byName[t.name] == nil then byName[t.name] = newId end
        t.id = newId
        added[#added + 1] = t
    end
    for _, t in ipairs(added) do
        if t.position.anchorTo ~= "" then
            local target = remap[t.position.anchorTo] or byName[t.position.anchorTo] or ""
            t.position.anchorTo = target ~= t.id and target or ""
        end
        if t.position.anchorTo == "" and t.position.x == 0 and t.position.y == 0 then
            DefaultPosition(t, profile)
        end
        profile.trackers[t.id] = t
        profile.order[#profile.order + 1] = t.id
    end
    Changed()
    return added
end

function P.RemoveTracker(id)
    local profile = P.Active()
    if not profile.trackers[id] then return end
    profile.trackers[id] = nil
    U.RemoveValue(profile.order, id)
    for _, t in pairs(profile.trackers) do
        if t.position.anchorTo == id then t.position.anchorTo = "" end
    end
    Changed()
end

function P.MoveTracker(id, delta)
    local order = P.Active().order
    local i = U.IndexOf(order, id)
    if not i then return end
    local j = U.Clamp(i + delta, 1, #order)
    if i == j then return end
    table.remove(order, i)
    table.insert(order, j, id)
    Changed()
end

-- Copy one tracker's look (everything on the Display / Text & colors tabs, except its own title) to
-- others; with `withRules` also its condition rules. Returns how many were changed.
function P.CopyLook(from, targets, withRules)
    if not from then return 0 end
    local n = 0
    for _, t in ipairs(targets) do
        if t ~= from and t.id ~= from.id then
            local title = t.display.title
            t.display = U.Copy(from.display)
            t.display.title = title
            if withRules then t.conditions = U.Copy(from.conditions) end
            S.Normalize(t)
            n = n + 1
        end
    end
    if n > 0 then DT.Engine.Rebuild() end
    return n
end

-- "When it's active" from one tracker to others: the situation only -- combat, boss / trash fights, group size, zones,
-- bosses, dead -- not what belongs to each tracker (roles, classes, sets, champion skills, skills, characters,
-- werewolf), so ticking 8 trackers and making them "boss fights only" doesn't wipe a proc tracker's set condition.
P.SITUATION_LOAD = { "combat", "combatLinger", "bossOnly", "trashOnly", "group", "hideDead", "zoneTypes", "zoneIds", "zoneNames", "bossNames" }
P.SITUATION_NEVER = { "zones", "bosses" }
function P.CopySituation(from, targets)
    if not from then return 0 end
    local n = 0
    for _, t in ipairs(targets) do
        if t ~= from and t.id ~= from.id then
            for _, k in ipairs(P.SITUATION_LOAD) do t.load[k] = U.Copy(from.load[k]) end
            for _, k in ipairs(P.SITUATION_NEVER) do t.load.never[k] = from.load.never[k] end
            S.Normalize(t)
            n = n + 1
        end
    end
    if n > 0 then DT.Engine.Rebuild() end
    return n
end

-- Call after editing a tracker's fields in place.
function P.TrackerChanged(tracker)
    S.Normalize(tracker)
    DT.Engine.Rebuild()
end

------------------------------------------------------------------------------
-- Auto-switch
------------------------------------------------------------------------------

P.RULE_KINDS = {
    { "role", L("My role is") },
    { "zoneType", L("I'm in") },
    { "zone", L("I'm in the zone") },
    { "group", L("My group is") },
    { "class", L("My class is") },
    { "character", L("Character is") },
}
-- "My group is": the same sizes as a tracker's Group load condition (without "any")
P.GROUP_RULES = { { "solo", L("Solo") }, { "group", L("In a group (2-4)") }, { "raid", L("In a raid (5+)") }, { "grouped", L("In any group (2+)") } }

local function GroupMatches(want, size)
    if want == "solo" then return size < 2 end
    if want == "group" then return size >= 2 and size <= 4 end
    if want == "raid" then return size >= 5 end
    if want == "grouped" then return size >= 2 end
    return false
end

function P.RuleMatches(rule, ctx)
    if rule.kind == "role" then return rule.value == ctx.role end
    if rule.kind == "zoneType" then return rule.value == ctx.zoneType end
    if rule.kind == "zone" then return tonumber(rule.value) ~= nil and tonumber(rule.value) == ctx.zoneId end
    if rule.kind == "group" then return GroupMatches(rule.value, ctx.groupSize or 0) end
    if rule.kind == "class" then return tonumber(rule.value) == ctx.classId end
    if rule.kind == "character" then return U.Lower(rule.value or "") == U.Lower(ctx.character or "") end
    return false
end

-- Group size changes any time, not only at a loading screen: listened to only while a "My group is" rule is on, and a
-- switch it causes waits for the end of the fight (a profile swap rebuilds every window).
local NS_AUTO = "DebuffTracker5_AutoSwitch"
local groupWatched, pendingAfterCombat = false, false
local function HasGroupRule()
    if not sv.autoSwitch.enabled then return false end
    for _, r in ipairs(sv.autoSwitch.rules) do if r.kind == "group" then return true end end
    return false
end
local function OnCombatState(_, inCombat)
    if inCombat or not pendingAfterCombat then return end
    pendingAfterCombat = false
    EVENT_MANAGER:UnregisterForEvent(NS_AUTO .. "_Combat", EVENT_PLAYER_COMBAT_STATE)
    P.ApplyAutoSwitch()
end
local function OnGroupChanged()
    if IsUnitInCombat("player") then
        if not pendingAfterCombat then
            pendingAfterCombat = true
            EVENT_MANAGER:RegisterForEvent(NS_AUTO .. "_Combat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
        end
        return
    end
    P.ApplyAutoSwitch()
end
function P.SyncAutoSwitchEvents()
    local want = HasGroupRule() and EVENT_GROUP_UPDATE ~= nil
    if want == groupWatched then return end
    groupWatched = want
    if want then
        EVENT_MANAGER:RegisterForEvent(NS_AUTO .. "_Group", EVENT_GROUP_UPDATE, OnGroupChanged)
        EVENT_MANAGER:RegisterForEvent(NS_AUTO .. "_Joined", EVENT_GROUP_MEMBER_JOINED, OnGroupChanged)
        EVENT_MANAGER:RegisterForEvent(NS_AUTO .. "_Left", EVENT_GROUP_MEMBER_LEFT, OnGroupChanged)
    else
        EVENT_MANAGER:UnregisterForEvent(NS_AUTO .. "_Group", EVENT_GROUP_UPDATE)
        EVENT_MANAGER:UnregisterForEvent(NS_AUTO .. "_Joined", EVENT_GROUP_MEMBER_JOINED)
        EVENT_MANAGER:UnregisterForEvent(NS_AUTO .. "_Left", EVENT_GROUP_MEMBER_LEFT)
        if pendingAfterCombat then
            pendingAfterCombat = false
            EVENT_MANAGER:UnregisterForEvent(NS_AUTO .. "_Combat", EVENT_PLAYER_COMBAT_STATE)
        end
    end
end
function P.AutoSwitchWatching() return groupWatched end

function P.ApplyAutoSwitch()
    P.SyncAutoSwitchEvents()
    if not sv.autoSwitch.enabled then return end
    local ctx = DT.Load.Context()
    for _, rule in ipairs(sv.autoSwitch.rules) do
        if sv.profiles[rule.profile] and P.RuleMatches(rule, ctx) then
            if P.SetActive(rule.profile, true) then
                U.Print(L("Switched to profile <<1>> (auto-switch rule).", rule.profile))
            end
            return
        end
    end
end
