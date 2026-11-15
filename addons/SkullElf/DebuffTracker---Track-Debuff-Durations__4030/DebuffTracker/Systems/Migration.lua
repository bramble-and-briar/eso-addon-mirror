-- One-time import of the settings of the released DebuffTracker (1.x, and the 4.x rewrite, which
-- kept the same saved-variables layout). The old data is read, never modified.
--
-- Old layout (ZO_SavedVars account-wide, default namespace of DebuffTrackerSavedVars):
--   trackedAbilities[id] = true|false      which abilities have a window (common debuffs are seeded false)
--   abilitySettings[id][key] = value       per-ability overrides of the global keys below
--   customTitles[id] = "title"             window title
--   customAbilityCopies[id] = { ids }      extra ability IDs counted as the same debuff
--   positions[id] = { x, y }               window TOPLEFT in screen pixels
--   global keys: trackDebuffsOnly, trackEffectsCastByYouOnly, trackEffectsCastToYouOnly, onlyInCombat,
--     alwaysShow, showStacks, showStacksOnPrimaryOnly, showTimer, ShowUptime, HighlightTarget, BarBlink,
--     useGradientBarColor, decimalNum, maxRows, sortMode, showBarsAboveHeader, barTexture,
--     minimumDifficulty (trials only), barStyle (4.x only)
--   ui = { barWidth, barHeight, headerHeight, windowAlpha, barAlpha, ... } (per-ability overrides via
--     abilitySettings too)
--   profiles[name] = same fields as above (+ folder, timestamp, version)
--   persistentData.dynamicDifficultyData[zoneId][name] = difficulty
--   Not carried over (inactive in the released version): reminderEnabled (reminders are disabled in
--   code), showMarker/markerSize (the marker is disabled in code).
-- Each tracked ability becomes one "All enemies" bar tracker that looks and behaves like its window.

local DT = DebuffTracker
local M = DT.Migration
local U = DT.Util
local S = DT.Schema
local L = DT.L
local C = DT.Const

-- The part of a ZO_SavedVars file that belongs to the account you're playing: raw[profile][@account] (profile "Default";
-- old files also keep a world-name profile). Saved-variable files hold every account that ever used the addon, and old
-- copies; searching this account's part first keeps those out. (Yarden, 5.20.0: the Miat import used a stale copy --
-- width 100, scale 1, a different place -- not the one Miat was using.)
local function ThisAccount(raw)
    if type(raw) ~= "table" or type(GetDisplayName) ~= "function" then return nil end
    local acct = GetDisplayName()
    if type(raw.Default) == "table" and type(raw.Default[acct]) == "table" then return raw.Default[acct] end
    for _, profile in pairs(raw) do
        if type(profile) == "table" and type(profile[acct]) == "table" then return profile[acct] end
    end
    return nil
end
M.ThisAccount = ThisAccount

local SORT_MAP = {
    ["Enemy name (A-Z)"] = "unit",
    ["Order of debuff application"] = "order",
    ["Time remaining (ascending)"] = "expiry",
    ["Time remaining (descending)"] = "expiryDesc",
}

-- defaults of the released version (used when a key is missing from the saved data)
local OLD_DEFAULTS = {
    trackDebuffsOnly = true, trackEffectsCastByYouOnly = false, trackEffectsCastToYouOnly = false,
    onlyInCombat = true, alwaysShow = false, showStacks = true, showStacksOnPrimaryOnly = false,
    showTimer = true, ShowUptime = true, HighlightTarget = false, BarBlink = true,
    useGradientBarColor = true, decimalNum = 1, maxRows = 10,
    barWidth = 165, barHeight = 20, headerHeight = 30, windowAlpha = 1, barAlpha = 1,
}
local UI_KEYS = { barWidth = true, barHeight = true, headerHeight = true, windowAlpha = true, barAlpha = true }

-- Resolve an old setting exactly like the old GetSetting/GetAbilityUIConfig did:
-- per-ability override -> global key (ui table for sizes) -> old default.
local function Getter(data)
    local overrides = type(data.abilitySettings) == "table" and data.abilitySettings or {}
    local ui = type(data.ui) == "table" and data.ui or {}
    return function(id, key)
        local o = overrides[id] or overrides[tostring(id)]
        if type(o) == "table" and o[key] ~= nil then return o[key] end
        if UI_KEYS[key] then
            if ui[key] ~= nil then return ui[key] end
        elseif data[key] ~= nil then
            return data[key]
        end
        return OLD_DEFAULTS[key]
    end
end

local GREEN, ORANGE, RED, OLIVE = { 0, 1, 0, 1 }, { 1, 0.65, 0, 1 }, { 1, 0, 0, 1 }, { 0.5, 0.5, 0, 1 }

local function ConvertAbility(data, id, get)
    local titles = type(data.customTitles) == "table" and data.customTitles or {}
    local copiesAll = type(data.customAbilityCopies) == "table" and data.customAbilityCopies or {}
    local copies = copiesAll[id] or copiesAll[tostring(id)] or {}
    local ids = { id }
    for _, c in ipairs(copies) do
        c = tonumber(c)
        if c and c ~= id then ids[#ids + 1] = c end
    end

    local title = titles[id] or titles[tostring(id)]
    local name = (type(title) == "string" and title ~= "") and title or U.CleanName(GetAbilityName(id))
    if name == "" then name = "#" .. id end

    local alwaysShow = get(id, "alwaysShow") == true
    -- the old addon let "always show" win over "only in combat"
    local onlyInCombat = get(id, "onlyInCombat") == true and not alwaysShow
    local gradient = get(id, "useGradientBarColor") ~= false
    local stacks = get(id, "showStacks") ~= false or get(id, "showStacksOnPrimaryOnly") == true

    local t = {
        name = name,
        trigger = {
            type = "effect",
            abilityIds = ids,
            scope = get(id, "trackEffectsCastToYouOnly") == true and "player" or "enemies",
            source = get(id, "trackEffectsCastByYouOnly") == true and "me" or "any",
            effectType = get(id, "trackDebuffsOnly") ~= false and "debuff" or "any",
            mode = "present",
            minDifficulty = math.floor(tonumber(data.minimumDifficulty) or 0),
        },
        display = {
            type = "bars",
            -- 4.x stored a style; the released 1.x look is the classic one
            style = (data.barStyle == "clean" or data.barStyle == "compact" or data.barStyle == "classic") and data.barStyle or "classic",
            width = (tonumber(get(id, "barWidth")) or 165) + 10,
            height = tonumber(get(id, "barHeight")) or 20,
            maxShown = tonumber(get(id, "maxRows")) or 10,
            sort = SORT_MAP[data.sortMode or ""] or "order",
            title = (type(title) == "string") and title or "",
            showUptime = get(id, "ShowUptime") ~= false,
            showStacks = stacks,
            showTimer = get(id, "showTimer") ~= false,
            highlightTarget = get(id, "HighlightTarget") == true,
            blink = get(id, "BarBlink") ~= false,
            blinkThreshold = 2,
            colorMode = gradient and "gradient" or "tiers",
            colorFull = GREEN,
            colorMid = gradient and OLIVE or ORANGE,
            colorEnd = RED,
            texture = type(data.barTexture) == "string" and data.barTexture ~= "" and data.barTexture or "DebuffTracker/icons/gradientProgressBar.dds",
            barAlpha = tonumber(get(id, "barAlpha")) or 1,
            timeFormat = (tonumber(get(id, "decimalNum")) or 1) > 0 and "tenths" or "seconds",
            grow = data.showBarsAboveHeader == true and "up" or "down",
            showEmpty = alwaysShow,
            labelFormat = "{unit}",
            background = { 0, 0, 0, 0.8 * (tonumber(get(id, "windowAlpha")) or 1) },
        },
        load = { combat = onlyInCombat and "in" or "any" },
    }

    -- old windows were anchored by their top-left corner; with bars above the header the 5.x window
    -- grows upward from its bottom edge, which was the header's bottom
    local positions = type(data.positions) == "table" and data.positions or {}
    local pos = positions[id] or positions[tostring(id)]
    if type(pos) == "table" and tonumber(pos.x) and tonumber(pos.y) then
        local y = tonumber(pos.y)
        if t.display.grow == "up" then y = y + (tonumber(get(id, "headerHeight")) or 30) end
        t.position = {
            x = math.floor(tonumber(pos.x) - GuiRoot:GetWidth() / 2 + 0.5),
            y = math.floor(y - GuiRoot:GetHeight() / 2 + 0.5),
        }
    end
    return S.Normalize(t)
end
M.ConvertAbility = ConvertAbility

-- data: the old saved-vars table or one of its profiles (same field names)
function M.ConvertSet(data)
    if type(data) ~= "table" then return {} end
    local get = Getter(data)
    local trackers, ids, seen = {}, {}, {}
    for id, tracked in pairs(type(data.trackedAbilities) == "table" and data.trackedAbilities or {}) do
        local n = tonumber(id)
        if tracked == true and n and not seen[n] then seen[n] = true; ids[#ids + 1] = n end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local ok, t = pcall(ConvertAbility, data, id, get)
        if ok and t then trackers[#trackers + 1] = t end
    end
    return trackers
end

local function ProfileFrom(trackers)
    local p = { trackers = {}, order = {} }
    for _, t in ipairs(trackers) do
        p.trackers[t.id] = t
        p.order[#p.order + 1] = t.id
    end
    return p
end

-- Old enemy-difficulty knowledge (trials), so "minimum difficulty" works from the first pull.
local function ImportDifficulty(oldSV, sv)
    local src = type(oldSV.persistentData) == "table" and oldSV.persistentData.dynamicDifficultyData
    if type(src) ~= "table" then return end
    sv.enemyDifficulty = sv.enemyDifficulty or {}
    for zoneId, names in pairs(src) do
        local z = tonumber(zoneId)
        if z and type(names) == "table" then
            local dst = sv.enemyDifficulty[z] or {}
            for name, difficulty in pairs(names) do
                if type(name) == "string" and tonumber(difficulty) then
                    dst[U.Lower(U.CleanName(name))] = tonumber(difficulty)
                end
            end
            sv.enemyDifficulty[z] = dst
        end
    end
end

-- Returns number of trackers and profiles created.
function M.Run(oldSV, sv)
    if type(oldSV) ~= "table" or sv.migratedFromV4 then return 0, 0 end
    local main = M.ConvertSet(oldSV)
    local profilesMade = 0
    if #main > 0 then
        local name = sv.profiles["Default"] and next(sv.profiles["Default"].trackers or {}) and DT.Profiles.UniqueName(L("Imported")) or "Default"
        sv.profiles[name] = ProfileFrom(main)
        sv.activeProfile = name
        profilesMade = 1
    end
    local names = {}
    for pname in pairs(type(oldSV.profiles) == "table" and oldSV.profiles or {}) do names[#names + 1] = tostring(pname) end
    table.sort(names)
    for _, pname in ipairs(names) do
        local pdata = oldSV.profiles[pname]
        if type(pdata) == "table" and type(pdata.trackedAbilities) == "table" then
            local list = M.ConvertSet(pdata)
            if #list > 0 then
                local folder = type(pdata.folder) == "string" and pdata.folder ~= "" and pdata.folder ~= "Uncategorized" and pdata.folder
                local base = folder and (folder .. " - " .. pname) or pname
                local name = sv.profiles[base] and DT.Profiles.UniqueName(base) or base
                sv.profiles[name] = ProfileFrom(list)
                profilesMade = profilesMade + 1
            end
        end
    end
    ImportDifficulty(oldSV, sv)
    sv.migratedFromV4 = true
    return #main, profilesMade
end

------------------------------------------------------------------------------
-- Import from the Cooldowns addon (g4rr3t / nogetrandom / B7TxSpeed).
--
-- Cooldowns saves (ZO_SavedVars "CooldownsVariables", version 1):
--   account-wide: sets[key] = { x, y (TOPLEFT, screen pixels), size, colorUp, colorDown,
--                  sounds = { onProc = {enabled, sound}, onReady = {enabled, sound} }, stack = {color} },
--                  colorUp, colorDown, stackColor, size, showOutsideCombat
--   per character: [procType][key] = true/false  (gear: false = switched off; synergies / passives /
--                  champion: true = shown)
-- Saved variables of another addon are only readable while that addon is loaded too, so Cooldowns
-- must be enabled for the import (it can be disabled afterwards).
--
-- Result: one "My procs" tracker for everything, plus an own tracker (same place, size, colours and
-- sounds) for every proc the user had moved somewhere in Cooldowns.
------------------------------------------------------------------------------

local COOL_DEFAULT_XY = 150

local function Color3(c, default)
    if type(c) ~= "table" then return U.Copy(default) end
    return { tonumber(c[1]) or default[1], tonumber(c[2]) or default[2], tonumber(c[3]) or default[3], tonumber(c[4]) or 1 }
end

-- Returns the account-wide preferences and this character's switches, or nil.
function M.FindCooldowns()
    local cool = rawget(_G, "Cool")
    if type(cool) == "table" and cool.name == "Cooldowns" and type(cool.preferences) == "table" then
        return cool.preferences, type(cool.character) == "table" and cool.character or {}
    end
    local raw = rawget(_G, "CooldownsVariables")
    if type(raw) ~= "table" then return nil end
    local function LooksLikeCharacter(t)
        return type(t) == "table" and (type(t.synergy) == "table" or type(t.set) == "table")
    end
    for _, accounts in pairs(raw) do
        if type(accounts) == "table" then
            local acct = accounts[type(GetDisplayName) == "function" and GetDisplayName() or ""]
            if type(acct) ~= "table" then
                for _, a in pairs(accounts) do if type(a) == "table" then acct = a break end end
            end
            if type(acct) == "table" and type(acct["$AccountWide"]) == "table" then
                local name = GetUnitName("player")
                local char = acct[name] or acct[U.CleanName(name)]
                if not LooksLikeCharacter(char) then
                    char = nil
                    for k, v in pairs(acct) do
                        if k ~= "$AccountWide" and LooksLikeCharacter(v) then char = v break end
                    end
                end
                return acct["$AccountWide"], char or {}
            end
        end
    end
    return nil
end

local function SoundRules(sounds)
    local rules = {}
    if type(sounds) ~= "table" then return rules end
    local onProc, onReady = sounds.onProc, sounds.onReady
    if type(onProc) == "table" and onProc.enabled and type(onProc.sound) == "string" then
        rules[#rules + 1] = { prop = "phase", op = "==", value = 1, action = "sound", arg = onProc.sound }
    end
    if type(onReady) == "table" and onReady.enabled and type(onReady.sound) == "string" then
        rules[#rules + 1] = { prop = "sinceReady", op = "<", value = 1, action = "sound", arg = onReady.sound }
    end
    return rules
end

local function Median(list)
    if #list == 0 then return nil end
    table.sort(list)
    return list[math.floor((#list + 1) / 2)]
end

-- prefs, char: from FindCooldowns. Returns a list of new trackers and a summary.
--
-- Cooldowns saves a position for every proc it ever drew, and players usually stack all their procs
-- in one spot (only the equipped ones show). So: ONE "My procs" tracker at the spot most procs were
-- (the median position of every switched-on proc), and an own tracker only for a proc you actually use -- a synergy / passive /
-- champion skill you switched on, or a set you're wearing right now -- that you had placed somewhere
-- else (more than 150 px away). Everything else simply shows in "My procs".
local SEPARATE_PX, MAX_OWN = 150, 12
function M.ConvertCooldowns(prefs, char)
    local Procs = DT.Procs
    local up = Color3(prefs.colorUp, { 0, 1, 0 })
    local down = Color3(prefs.colorDown, { 1, 0, 0 })
    local stackC = Color3(prefs.stackColor, { 1, 0.8, 0 })
    local sets = type(prefs.sets) == "table" and prefs.sets or {}
    local function Look(size, cUp, cDown, cStack)
        return {
            type = "icons", iconSize = math.floor(U.Clamp(tonumber(size) or 64, 16, 200)), showHeader = false,
            iconLabelFormat = "", columns = 8, separateTextColors = true, timerColor = cUp, cooldownColor = cDown,
            stackColor = cStack, cooldownDesaturate = true, background = { 0, 0, 0, 0 },
        }
    end
    local group = {
        name = L("My procs"), fromCooldowns = true,
        trigger = { type = "procs", procPicked = {}, procHidden = {} },
        display = Look(prefs.size, up, down, stackC),
        conditions = SoundRules(prefs.sounds),
        load = { combat = prefs.showOutsideCombat == false and "in" or "any", hideDead = true },   -- Cooldowns hides while dead
    }

    -- what's switched on, what's in use, and where things were
    local entries, xsAll, ysAll = {}, {}, {}
    for _, e in ipairs(Procs.All()) do
        local kindSwitches = type(char[e.t]) == "table" and char[e.t] or {}
        local on
        if Procs.IsGear(e) then on = kindSwitches[e.k] ~= false else on = kindSwitches[e.k] == true end
        local saved = sets[e.k]
        local x = type(saved) == "table" and tonumber(saved.x) or nil
        local y = type(saved) == "table" and tonumber(saved.y) or nil
        local placed = x and y and (x ~= COOL_DEFAULT_XY or y ~= COOL_DEFAULT_XY)
        local inUse = on and (not Procs.IsGear(e) or Procs.HasFull(e) == true)
        entries[#entries + 1] = { e = e, on = on, saved = saved, x = x, y = y, placed = placed, inUse = inUse }
        if placed and on then xsAll[#xsAll + 1], ysAll[#ysAll + 1] = x, y end
    end
    local cx, cy = Median(xsAll), Median(ysAll)
    local W2, H2 = GuiRoot:GetWidth() / 2, GuiRoot:GetHeight() / 2
    if cx then
        group.position = { x = math.floor(cx - W2 + 0.5), y = math.floor(cy - H2 + 0.5) }
        if group.position.x == 0 and group.position.y == 0 then group.position.x = 1 end   -- (0,0) = "place for me"
    end

    local own, picked = {}, 0
    for _, it in ipairs(entries) do
        local e = it.e
        if not it.on then
            if Procs.IsGear(e) then group.trigger.procHidden[#group.trigger.procHidden + 1] = e.k end
        else
            local apart = it.inUse and it.placed and cx
                and math.sqrt((it.x - cx) ^ 2 + (it.y - cy) ^ 2) > SEPARATE_PX and #own < MAX_OWN
            if apart then
                local saved = it.saved
                local cStack = (type(saved.stack) == "table" and saved.stack.color) and Color3(saved.stack.color, stackC) or stackC
                local t = Procs.TrackerFor(e, Look(saved.size or prefs.size, Color3(saved.colorUp, up), Color3(saved.colorDown, down), cStack))
                t.fromCooldowns = true
                t.display.maxShown = 1
                t.conditions = SoundRules(saved.sounds)
                t.load.combat = group.load.combat
                t.load.hideDead = true
                t.position = { x = math.floor(it.x - W2 + 0.5), y = math.floor(it.y - H2 + 0.5) }
                if t.position.x == 0 and t.position.y == 0 then t.position.x = 1 end
                own[#own + 1] = t
                if Procs.IsGear(e) then group.trigger.procHidden[#group.trigger.procHidden + 1] = e.k end
            elseif not Procs.IsGear(e) then
                group.trigger.procPicked[#group.trigger.procPicked + 1] = e.k
                picked = picked + 1
            end
        end
    end
    local list = { group }
    for _, t in ipairs(own) do list[#list + 1] = t end
    return list, { own = #own, picked = picked, hidden = #group.trigger.procHidden }
end

-- Trackers an earlier Cooldowns import made (marked when created; copies and "own tracker" splits you
-- make yourself are not marked).
local function FromCooldowns(t)
    return t.fromCooldowns == true
end
M.IsFromCooldowns = FromCooldowns

-- Adds the converted trackers to the active profile, replacing an earlier Cooldowns import.
-- Returns added trackers + summary (summary.replaced = trackers removed), or nil + reason.
function M.ImportCooldowns()
    local prefs, char = M.FindCooldowns()
    if not prefs then
        return nil, L("Cooldowns isn't loaded. Enable it in the add-ons list (just once, for the import), reload, and try again.")
    end
    local old = {}
    for _, t in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromCooldowns(t) then old[#old + 1] = t.id end
    end
    for _, id in ipairs(old) do DT.Profiles.RemoveTracker(id) end
    local replaced = #old
    local list, summary = M.ConvertCooldowns(prefs, char)
    local added = DT.Profiles.AddTrackers(list)
    summary.replaced = replaced
    DT.Profiles.SV().cooldownsImported = true
    return added, summary
end

-- Remove everything a Cooldowns import added (Settings > Maintenance). Returns how many.
function M.RemoveCooldownsImport()
    local old = {}
    for _, t in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromCooldowns(t) then old[#old + 1] = t.id end
    end
    for _, id in ipairs(old) do DT.Profiles.RemoveTracker(id) end
    return #old
end

------------------------------------------------------------------------------
-- Import from the Untaunted addon (Solinur).
--
-- Untaunted saves (ZO_SavedVars "Untaunted_Save", version 7; per account, or per character id when
-- its "account wide" box is off): window = { x, y, width, height }, maxbars, growthdirection (true = up),
-- bardirection (true = bars empty toward the right), trackonlyplayer, disablePvP, showmarker, markersize,
-- trackedabilities = { {abilityId, on}, ... }, customabilities = { abilityId, ... }.
-- What it does (Untaunted.lua 1.1.6), and the DebuffTracker equivalent:
--   * one row per enemy and ability; an own taunt green -> yellow -> red, other players' muted
--     -> bars, gradient, a "cast by me = false" colour rule;
--   * "only mine" (on by default) filters every ability to your own except Taunt Immunity, Off Balance
--     Immunity and Minor Magickasteal -> two triggers: "cast by me" + "cast by anyone";
--   * Aggressive Horn is followed on YOU -> a trigger on yourself;
--   * an ended row stays (no timer) until 5 s past its own end time, while the enemy has another row,
--     and only in combat; an enemy that dies loses its rows at once -> Keep it shown 5 s, also when
--     it ends early, counted from when it would have ended, while the enemy shows another entry,
--     only in combat;
--   * your current target's rows get a yellow edge -> Highlight my current target;
--   * "disable in PvP" -> every zone type but PvP.
------------------------------------------------------------------------------

local UNT_ANY_SOURCE = { [134599] = true, [39100] = true, [52788] = true }   -- Untaunted's exceptions to "only mine"
local UNT_ON_ME = 40224                                                       -- Aggressive Horn: on you
local UNT_DEFAULT_ON = { 38541, 52788 }                                       -- Taunt, Taunt Immunity

-- Returns Untaunted's settings table (the account's, or this character's), or nil.
function M.FindUntaunted()
    local un = rawget(_G, "Untaunted")
    if type(un) == "table" and un.name == "Untaunted" and type(un.db) == "table" then return un.db end
    local raw = rawget(_G, "Untaunted_Save")
    if type(raw) ~= "table" then return nil end
    for _, accounts in pairs(raw) do
        if type(accounts) == "table" then
            local acct = accounts[type(GetDisplayName) == "function" and GetDisplayName() or ""]
            if type(acct) ~= "table" then
                for _, a in pairs(accounts) do if type(a) == "table" then acct = a break end end
            end
            if type(acct) == "table" then
                local aw = acct["$AccountWide"]
                if type(aw) == "table" and aw.accountwide == false and type(GetCurrentCharacterId) == "function" then
                    local char = acct[tostring(GetCurrentCharacterId())]
                    if type(char) == "table" then return char end
                end
                if type(aw) == "table" then return aw end
            end
        end
    end
    return nil
end

local function UntauntedTrigger(ids, source, scope)
    return {
        type = "effect", scope = scope or "enemies", mode = "present", abilityIds = ids, source = source,
        linger = 5, lingerEarly = true, lingerToDue = true, lingerUnit = true,
    }
end

-- The Untaunted look and behaviour as a DebuffTracker tracker (also used by the Library preset).
function M.UntauntedTracker(db)
    db = type(db) == "table" and db or {}
    local onlyMine = db.trackonlyplayer ~= false
    local mine, any, horn = {}, {}, false
    local seen = {}
    local function Add(id, custom)
        id = math.floor(tonumber(id) or 0)
        if id <= 0 or seen[id] then return end
        seen[id] = true
        if id == UNT_ON_ME and not custom then horn = true
        elseif onlyMine and not UNT_ANY_SOURCE[id] then mine[#mine + 1] = id
        else any[#any + 1] = id end
    end
    if type(db.trackedabilities) == "table" then
        for _, d in ipairs(db.trackedabilities) do
            if type(d) == "table" and d[2] == true then Add(d[1]) end
        end
    else
        for _, id in ipairs(UNT_DEFAULT_ON) do Add(id) end
    end
    if type(db.customabilities) == "table" then
        for _, id in ipairs(db.customabilities) do Add(id, true) end
    end
    local triggers = {}
    if #mine > 0 then triggers[#triggers + 1] = UntauntedTrigger(mine, "me") end
    if #any > 0 then triggers[#triggers + 1] = UntauntedTrigger(any, "any") end
    if horn then triggers[#triggers + 1] = UntauntedTrigger({ UNT_ON_ME }, onlyMine and "me" or "any", "player") end
    if #triggers == 0 then return nil end

    local win = type(db.window) == "table" and db.window or {}
    local up = db.growthdirection == true
    local height = math.floor(U.Clamp(tonumber(win.height) or 25, 12, 60) + 0.5)
    local t = {
        name = L("Taunts (Untaunted)"),
        trigger = table.remove(triggers, 1),
        extraTriggers = triggers,
        display = {
            type = "bars", style = "clean", width = math.floor(U.Clamp(tonumber(win.width) or 300, 100, 600) + 0.5),
            height = height, iconSize = height, spacing = 4, showRowIcon = true, labelFormat = "{unit}",
            sort = "order", maxShown = math.floor(U.Clamp(tonumber(db.maxbars) or 15, 1, 40)),
            grow = up and "up" or "down", fillReverse = db.bardirection == true,
            showHeader = false, showUptime = false, highlightTarget = true, blink = false,
            colorMode = "gradient", colorFull = { 0, 0.8, 0, 1 }, colorMid = { 0.7, 0.7, 0, 1 }, colorEnd = { 0.8, 0, 0, 1 },
        },
        conditions = {},
        -- Untaunted clears everything when you leave combat
        load = { combat = "in" },
    }
    -- other players' entries: Untaunted's muted bar
    if #any > 0 or not onlyMine then
        t.conditions[1] = { prop = "mine", op = "==", value = "false", action = "color", arg = { 0.5, 0.5, 0.25, 1 } }
    end
    if db.disablePvP == true then
        t.load.zoneTypes = {}
        for _, z in ipairs(C.ZONE_TYPES) do if z[1] ~= "pvp" then t.load.zoneTypes[z[1]] = true end end
    end
    -- Untaunted's window: TOPLEFT from the screen's top left (growing up: BOTTOMLEFT from the bottom)
    local x, y = tonumber(win.x), tonumber(win.y)
    if x and y and GuiRoot then
        local W2, H2 = GuiRoot:GetWidth() / 2, GuiRoot:GetHeight() / 2
        local px = math.floor(x - W2 + 0.5)
        local py = up and math.floor(H2 + y + 0.5) or math.floor(y - H2 + 0.5)
        if px == 0 and py == 0 then px = 1 end
        t.position = { x = px, y = py }
    end
    return t
end

local function FromUntaunted(t) return t.fromUntaunted == true end
M.IsFromUntaunted = FromUntaunted

-- Adds the converted tracker to the active profile, replacing an earlier Untaunted import.
-- Returns the added trackers + summary, or nil + reason.
function M.ImportUntaunted()
    local db = M.FindUntaunted()
    if not db then
        return nil, L("Untaunted isn't loaded. Enable it in the add-ons list (just once, for the import), reload, and try again.")
    end
    local t = M.UntauntedTracker(db)
    if not t then return nil, L("Untaunted has no abilities switched on: nothing to import.") end
    t.fromUntaunted = true
    local old = {}
    for _, x in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromUntaunted(x) then old[#old + 1] = x.id end
    end
    for _, id in ipairs(old) do DT.Profiles.RemoveTracker(id) end
    local added = DT.Profiles.AddTrackers({ t })
    -- its red arrow over enemies: ours takes over once Untaunted is disabled (never both at once)
    local settings = DT.Profiles.Settings()
    local marker = db.showmarker == true
    if marker then
        settings.enemyMarker = true
        settings.enemyMarkerSize = math.floor(U.Clamp(tonumber(db.markersize) or 26, 12, 96) + 0.5)
        if DT.Marker and DT.Marker.SettingsChanged then DT.Marker.SettingsChanged() end
    end
    local n = 0
    for _, x in ipairs({ t.trigger, unpack(t.extraTriggers) }) do n = n + #x.abilityIds end
    DT.Profiles.SV().untauntedImported = true
    return added, { replaced = #old, abilities = n, marker = marker }
end

function M.RemoveUntauntedImport()
    local old = {}
    for _, t in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromUntaunted(t) then old[#old + 1] = t.id end
    end
    for _, id in ipairs(old) do DT.Profiles.RemoveTracker(id) end
    return #old
end

------------------------------------------------------------------------------
-- Import from BuffTheGroup (bitrock, garlicmoon; 3.5.0).
--
-- BuffTheGroup saves per character: ZO_SavedVars:NewCharacterIdSettings("BuffTheGroupSavedVariables", 4,
-- nil, defaults, nil, GetWorldName()) -- the server name sits where the account name usually is:
-- BuffTheGroupSavedVariables.Default["EU Megaserver"][characterId] = { enabled, gradientMode, showOnlyDPS,
-- singleColumnMode, minimalMode, maxRows, trackedBuffs = {[index] = bool}, framePositions = {[index] =
-- {left, top}}, startR/G/B, endR/G/B (0-255) }.
-- What it shows (BuffTheGroup.lua), and the DebuffTracker equivalent:
--   * one window per tracked buff, a row for EVERY group member (role icon, @account, time left), in
--     group order, kept while they don't have it -> group, Show = Cycle (also the dead), Fixed sort,
--     "{roleicon} {account}";
--   * the row's colour goes start -> end colour as the buff runs out; no buff: dark, "0"
--     -> gradient colours, "ready" step grey (step 0 rule);
--   * your own row brighter, members out of support range at half transparency -> rules "The unit is
--     me" / "Ally in support range" + Transparency;
--   * 6 rows then a 2nd column, or one column -> Bars per column 6 / 0;
--   * "show only DPS" -> Only these roles: DPS; "minimal mode" (the % of the group with the buff) ->
--     One entry: how many have it, as an icon with {pct};
--   * Pillager's Profit: after the buff, the cooldown (172056's duration) -> Then a cooldown (ID 172056);
--   * only in group dungeons, arenas and trials with 2+ in the group -> Load: In any group, zone types.
------------------------------------------------------------------------------

-- BuffTheGroup's buff list (BuffTheGroupData.lua): index -> ability ID (the saved indices refer to it)
M.BTG_BUFFS = {
    [1] = 61771, [2] = 93109, [3] = 109966, [4] = 61747, [5] = 62195, [6] = 61744, [7] = 147417, [8] = 61687,
    [9] = 61685, [10] = 61665, [11] = 61691, [12] = 61694, [13] = 61693, [14] = 61706, [15] = 61737, [16] = 61709,
    [17] = 40079, [18] = 61736, [19] = 163401, [20] = 88490, [21] = 61704, [22] = 61666, [23] = 61735,
    [1001] = 172055,
}
M.BTG_COOLDOWN_IDS = { [1001] = 172056 }     -- Pillager's Profit: its cooldown's duration
local BTG_GREY = { 0.35, 0.35, 0.38, 1 }

local function LooksLikeBTG(t)
    return type(t) == "table" and type(t.trackedBuffs) == "table"
end

-- Returns this character's BuffTheGroup settings, or nil.
function M.FindBTG()
    local live = rawget(_G, "btg")
    if type(live) == "table" and live.name == "BuffTheGroup" and LooksLikeBTG(live.savedVars) then return live.savedVars end
    local raw = rawget(_G, "BuffTheGroupSavedVariables")
    if type(raw) ~= "table" then return nil end
    local me = type(GetCurrentCharacterId) == "function" and tostring(GetCurrentCharacterId()) or nil
    local first
    local function Walk(t, depth)
        for k, v in pairs(t) do
            if LooksLikeBTG(v) then
                if me and tostring(k) == me then return v end
                first = first or v
            elseif type(v) == "table" and depth < 3 then
                local found = Walk(v, depth + 1)
                if found then return found end
            end
        end
    end
    local mine = ThisAccount(raw)
    local r = mine and Walk(mine, 2)
    if r or (mine and first) then return r or first end
    return Walk(raw, 1) or first
end

local function Rgb(r, g, b, dr, dg, db)
    return { (tonumber(r) or dr) / 255, (tonumber(g) or dg) / 255, (tonumber(b) or db) / 255, 1 }
end

-- One BuffTheGroup window as a tracker. sv = its settings (nil: its defaults); index = its buff index.
function M.BTGTracker(sv, index)
    sv = type(sv) == "table" and sv or {}
    local id = M.BTG_BUFFS[index] or index
    local startC = Rgb(sv.startR, sv.startG, sv.startB, 117, 222, 120)
    local endC = Rgb(sv.endR, sv.endG, sv.endB, 222, 117, 117)
    local minimal = sv.minimalMode == true
    local name = type(GetAbilityName) == "function" and U.CleanName(GetAbilityName(id)) or ""
    if name == "" then name = tostring(id) end
    local t = {
        name = name,
        trigger = { type = "effect", scope = "group", mode = "cycle", abilityIds = { id }, summary = minimal,
            unitRoles = sv.showOnlyDPS == true and { dps = true } or {},
            cooldownAfterId = M.BTG_COOLDOWN_IDS[index] or 0 },
        display = {
            type = "bars", style = "clean", width = 160, height = 24, spacing = 0, showRowIcon = false,
            labelFormat = "{roleicon} {account}", sort = "fixed", maxShown = 12, timeFormat = "tenths",
            barRows = (sv.singleColumnMode == true) and 0 or math.floor(U.Clamp(tonumber(sv.maxRows) or 6, 1, 12)),
            showHeader = true, title = name, showUptime = false, highlightTarget = false, blink = false,
            desaturateInactive = false, showEmpty = true,
            colorMode = sv.gradientMode == false and "solid" or "gradient", colorSolid = startC,
            colorFull = startC, colorMid = U.LerpColor(startC, endC, 0.5), colorEnd = endC,
        },
        conditions = {
            -- no buff: grey (Off Balance's "ready" step without the green)
            { prop = "phase", op = "==", value = 0, action = "color", arg = BTG_GREY },
            -- your own row brighter, members out of support range at half transparency
            { prop = "isMe", op = "==", value = "false", action = "alpha", arg = 85 },
            { prop = "inRange", op = "==", value = "false", action = "alpha", arg = 50 },
        },
        load = { group = "grouped", zoneTypes = { dungeon = true, trial = true } },
    }
    if minimal then
        t.display.type, t.display.iconSize, t.display.iconLabelFormat = "icons", 36, "{pct}"
        t.display.showHeader = false
        t.conditions = { { prop = "active", op = "==", value = "false", action = "color", arg = BTG_GREY } }
    end
    local pos = type(sv.framePositions) == "table" and sv.framePositions[index] or nil
    if type(pos) == "table" and tonumber(pos.left) and tonumber(pos.top) and GuiRoot then
        local W2, H2 = GuiRoot:GetWidth() / 2, GuiRoot:GetHeight() / 2
        t.position = { x = math.floor(pos.left - W2 + 0.5), y = math.floor(pos.top - H2 + 0.5) }
        if t.position.x == 0 and t.position.y == 0 then t.position.x = 1 end
    end
    return t
end

local function FromBTG(t) return t.fromBTG == true end
M.IsFromBTG = FromBTG

function M.ImportBTG()
    local sv = M.FindBTG()
    if not sv then
        return nil, L("BuffTheGroup isn't loaded. Enable it in the add-ons list (just once, for the import), reload, and try again.")
    end
    local list, indices = {}, {}
    for index in pairs(M.BTG_BUFFS) do
        if sv.trackedBuffs[index] == true or sv.trackedBuffs[tostring(index)] == true then indices[#indices + 1] = index end
    end
    table.sort(indices)
    if #indices == 0 then return nil, L("BuffTheGroup tracks no buffs: nothing to import.") end
    for _, index in ipairs(indices) do
        local t = M.BTGTracker(sv, index)
        t.fromBTG = true
        t.enabled = sv.enabled ~= false
        list[#list + 1] = t
    end
    local old = {}
    for _, x in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromBTG(x) then old[#old + 1] = x.id end
    end
    for _, oid in ipairs(old) do DT.Profiles.RemoveTracker(oid) end
    local added = DT.Profiles.AddTrackers(list)
    DT.Profiles.SV().btgImported = true
    return added, { replaced = #old, buffs = #list }
end

function M.RemoveBTGImport()
    local old = {}
    for _, t in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromBTG(t) then old[#old + 1] = t.id end
    end
    for _, id in ipairs(old) do DT.Profiles.RemoveTracker(id) end
    return #old
end

------------------------------------------------------------------------------
-- Import from StaggerTracker (andy.s; 0.3).
--
-- StaggerTracker saves only where its icon is: ZO_SavedVars:New("StaggerTrackerSV", 1) per character,
-- { controlCenterX, controlCenterY } = the icon's CENTRE from the screen's top left.
-- What it does (main.lua), and the DebuffTracker equivalent:
--   * one 64 px icon: YOUR Stagger (134336), the time of the last application on any enemy, the stacks
--     of your target when it has it -> all enemies, cast by me, Show = Cycle, Sort "My target first
--     (then the newest)", 1 entry;
--   * the frame red / orange / yellow / green for 0 / 1 / 2 / 3 stacks -> four colour rules (border);
--   * the icon grey until Stone Giant has been cast (its slot turns into the projectile 133027) ->
--     rule "Ability on my bars != 133027" -> Grey icon;
--   * only for Dragonknights, in combat, with Stone Giant (31816 / 133027) on either bar -> Load.
--
-- Update 49 (Dragonknight combat refresh, March 2026) turned Stone Giant into MAGMA FIST: same slot ID 31816, no
-- projectiles any more (not a chaining skill), and its debuff is now HEAT SHOCK, 134340, up to 3 stacks for 7 s.
-- Stagger 134336 is never applied. Found with "/dt watch 134336" (Yarden, 5.21.2): 30 s of casting, no Stagger event,
-- not on the target, the slot never changed; a combat log showed "(134340) 3x Heat Shock". So: Heat Shock (Stagger
-- kept too, for a client before the update), no grey-until-projectile rule (it would stay grey for ever).
------------------------------------------------------------------------------

M.STAGGER = { effect = 134340, old = 134336, stoneGiant = 31816, projectile = 133027 }
local ST_SIZE = 64
local ST_COLORS = { { 1, 0, 0, 1 }, { 1, 0.5, 0, 1 }, { 1, 0.8, 0, 1 }, { 0, 1, 0, 1 } }   -- 0..3 stacks

function M.StaggerTracker(sv)
    local id = M.STAGGER
    local t = {
        name = L("Heat Shock (Magma Fist)"),
        trigger = { type = "effect", scope = "enemies", source = "me", mode = "cycle", abilityIds = { id.effect, id.old } },
        display = {
            type = "icons", iconSize = ST_SIZE, borderSize = 5, maxShown = 1, sort = "target", showHeader = false,
            showUptime = false, iconLabelFormat = "", timeFormat = "seconds", fontSize = 30, showStacks = true,
            highlightTarget = false, desaturateInactive = false, blink = false, iconTimer = "none",
            background = { 0, 0, 0, 0 },
        },
        conditions = {
            { prop = "phase", op = "==", value = 0, action = "color", arg = ST_COLORS[1] },
            { prop = "stacks", op = "==", value = 1, action = "color", arg = ST_COLORS[2] },
            { prop = "stacks", op = "==", value = 2, action = "color", arg = ST_COLORS[3] },
            { prop = "stacks", op = ">=", value = 3, action = "color", arg = ST_COLORS[4] },
        },
        load = { combat = "in", classes = { [1] = true }, skills = { id.stoneGiant } },
    }
    sv = type(sv) == "table" and sv or {}
    local cx, cy = tonumber(sv.controlCenterX), tonumber(sv.controlCenterY)
    if cx and cy and GuiRoot then
        local W2, H2 = GuiRoot:GetWidth() / 2, GuiRoot:GetHeight() / 2
        t.position = { x = math.floor(cx - ST_SIZE / 2 - W2 + 0.5), y = math.floor(cy - ST_SIZE / 2 - H2 + 0.5) }
        if t.position.x == 0 and t.position.y == 0 then t.position.x = 1 end
    end
    return t
end

-- StaggerTracker's saved position for this character (or any), or nil when the addon isn't loaded.
function M.FindStagger()
    local raw = rawget(_G, "StaggerTrackerSV")
    if type(raw) ~= "table" then
        return (type(rawget(_G, "StaggerTracker")) == "table" and rawget(_G, "StaggerTracker").name == "StaggerTracker") and {} or nil
    end
    local me = type(GetUnitName) == "function" and GetUnitName("player") or nil
    local first
    local function Walk(t, depth)
        for k, v in pairs(t) do
            if type(v) == "table" then
                if v.controlCenterX or v.version then
                    if me and k == me then return v end
                    first = first or v
                elseif depth < 3 then
                    local f = Walk(v, depth + 1)
                    if f then return f end
                end
            end
        end
    end
    local mine = ThisAccount(raw)
    local r = mine and Walk(mine, 2)
    if r or (mine and first) then return r or first end
    return Walk(raw, 1) or first or {}
end

local function FromStagger(t) return t.fromStagger == true end
M.IsFromStagger = FromStagger

function M.ImportStagger()
    local sv = M.FindStagger()
    if not sv then
        return nil, L("StaggerTracker isn't loaded. Enable it in the add-ons list (just once, for the import), reload, and try again.")
    end
    local t = M.StaggerTracker(sv)
    t.fromStagger = true
    local old = {}
    for _, x in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromStagger(x) then old[#old + 1] = x.id end
    end
    for _, oid in ipairs(old) do DT.Profiles.RemoveTracker(oid) end
    local added = DT.Profiles.AddTrackers({ t })
    DT.Profiles.SV().staggerImported = true
    return added, { replaced = #old, placed = t.position ~= nil }
end

function M.RemoveStaggerImport()
    local old = {}
    for _, t in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromStagger(t) then old[#old + 1] = t.id end
    end
    for _, id in ipairs(old) do DT.Profiles.RemoveTracker(id) end
    return #old
end

------------------------------------------------------------------------------
-- Import from ExoY's ProcSet Timer (@ExoY94; 2.14.0).
--
-- It saves account-wide: ZO_SavedVars:NewAccountWide("EPTSV", 2) -> design = { iconSize, font (1-5),
-- hiding (only in combat), edge = { size, show, changeColor }, color = { active, cooldown, standby, high,
-- medium, low }, indicator = { showDecimal, changeColor, size (x iconSize / 10), offSetX, offSetY, font },
-- nameDisplay = { gameMode, ... } }, filter = { active, type (true = white list) }, [setId] = { left, top,
-- whiteList, blackList }, special = { zen.focusOnBoss, opportunist.showDuration / showAffected,
-- martial.showStamina }, setPieceOverwrite.
-- What it shows, and the DebuffTracker equivalent:
--   * a 50 px icon per worn proc set, each where you put it -> one "My procs" tracker where most of them
--     were, plus an own tracker for a worn set you placed elsewhere (like the Cooldowns import);
--   * buff time from the game, then the cooldown -> "Buff times from the game";
--   * the frame (edge) and the number green while active, red on cooldown -> colour rules;
--   * stacks of mythics green at the most, Z'en's DoTs low / medium / high -> proc colours (high / medium
--     / low), "count on the boss" for Z'en's focus on boss;
--   * hide out of combat -> Load: only in combat; white / black list -> the tracker's shown / hidden procs.
-- ExoY's "required number of pieces" was a workaround for mixing normal and perfected pieces; DebuffTracker
-- counts those together (the game's own count), so it isn't needed.
------------------------------------------------------------------------------

local EXOY_FONTS = { "MEDIUM_FONT", "BOLD_FONT", "ANTIQUE_FONT", "HANDWRITTEN_FONT", "STONE_TABLET_FONT" }
local EXOY_DEFAULT_XY = 600

function M.FindExoY()
    local live = rawget(_G, "EPT")
    if type(live) == "table" and live.name == "ExoYsProcSetTimer" and type(live.store) == "table" then return live.store end
    local raw = rawget(_G, "EPTSV")
    if type(raw) ~= "table" then return nil end
    for _, accounts in pairs(raw) do
        if type(accounts) == "table" then
            local acct = accounts[type(GetDisplayName) == "function" and GetDisplayName() or ""]
            if type(acct) ~= "table" then
                for _, a in pairs(accounts) do if type(a) == "table" then acct = a break end end
            end
            if type(acct) == "table" and type(acct["$AccountWide"]) == "table" then return acct["$AccountWide"] end
        end
    end
    return nil
end

-- the catalogue entry for one of ExoY's set IDs
local function EntryForSet(setId)
    for _, e in ipairs(DT.Procs.All()) do
        for _, id in ipairs(e.sets or {}) do if id == setId then return e end end
    end
end

function M.ConvertExoY(sv)
    sv = type(sv) == "table" and sv or {}
    local design = type(sv.design) == "table" and sv.design or {}
    local edge = type(design.edge) == "table" and design.edge or {}
    local ind = type(design.indicator) == "table" and design.indicator or {}
    local col = type(design.color) == "table" and design.color or {}
    local names = type(design.nameDisplay) == "table" and design.nameDisplay or {}
    local special = type(sv.special) == "table" and sv.special or {}
    local function Col(c, d) return Color3(c, d) end
    local size = math.floor(U.Clamp(tonumber(design.iconSize) or 50, 16, 200) + 0.5)
    local active, cooldown = Col(col.active, { 0, 1, 0 }), Col(col.cooldown, { 1, 0, 0 })
    local function Look()
        return {
            type = "icons", iconSize = size, showHeader = false, showUptime = false, background = { 0, 0, 0, 0 },
            iconLabelFormat = names.gameMode == true and "{name}" or "", columns = 8, spacing = 8,
            borderSize = (edge.show == false) and 0 or math.floor(U.Clamp(tonumber(edge.size) or 5, 0, 12)),
            gameFrame = false, highlightTarget = false, blink = false, desaturateInactive = false,
            timeFormat = ind.showDecimal == false and "seconds" or "auto",
            fontSize = math.floor(U.Clamp(size * (tonumber(ind.size) or 7) / 10, 8, 64)),
            fontFace = EXOY_FONTS[tonumber(ind.font) or 1] or "MEDIUM_FONT",
            timerOffsetX = math.floor(tonumber(ind.offSetX) or 0), timerOffsetY = math.floor(tonumber(ind.offSetY) or 0),
            procColorOk = Col(col.high, { 0, 1, 0 }), procColorPart = Col(col.medium, { 1, 1, 0 }),
            procColorBad = Col(col.low, { 1, 0, 0 }),
            procCards = not ((special.opportunist or {}).showDuration == false and (special.opportunist or {}).showAffected == false
                and (special.martial or {}).showStamina == false),
            cooldownDesaturate = false,
        }
    end
    local function Rules()
        local rules = {}
        if edge.changeColor ~= false then
            rules[#rules + 1] = { prop = "phase", op = "==", value = 1, action = "color", arg = active }
            rules[#rules + 1] = { prop = "onCooldown", op = "==", value = "true", action = "color", arg = cooldown }
        end
        if ind.changeColor ~= false then
            rules[#rules + 1] = { prop = "phase", op = "==", value = 1, action = "timerColor", arg = active }
            rules[#rules + 1] = { prop = "onCooldown", op = "==", value = "true", action = "timerColor", arg = cooldown }
        end
        return rules
    end
    local load = { combat = design.hiding == true and "in" or "any" }
    local group = {
        name = L("My procs (ExoY)"), fromExoY = true,
        trigger = { type = "procs", procPicked = {}, procHidden = {}, procGameDurations = true,
            procZenBoss = (special.zen or {}).focusOnBoss ~= false },
        display = Look(), conditions = Rules(), load = U.Copy(load),
    }
    -- white / black list
    local filter = type(sv.filter) == "table" and sv.filter or {}
    local listed = {}
    for setId, v in pairs(sv) do
        local id = tonumber(setId)
        if id and type(v) == "table" then
            local e = EntryForSet(id)
            if e then
                if filter.active and filter.type and v.whiteList then listed[#listed + 1] = e.k end
                if filter.active and not filter.type and v.blackList then
                    if not U.Contains(group.trigger.procHidden, e.k) then group.trigger.procHidden[#group.trigger.procHidden + 1] = e.k end
                end
            end
        end
    end
    if filter.active and filter.type then group.trigger.procOnly = listed end
    -- where things were: the median of the sets you moved; an own tracker for a worn set placed apart
    local placed, xs, ys = {}, {}, {}
    for setId, v in pairs(sv) do
        local id = tonumber(setId)
        if id and type(v) == "table" and tonumber(v.left) and tonumber(v.top)
            and (v.left ~= EXOY_DEFAULT_XY or v.top ~= EXOY_DEFAULT_XY) then
            local e = EntryForSet(id)
            if e then
                placed[#placed + 1] = { e = e, x = v.left, y = v.top, worn = DT.Gear.IsFull(id) }
                xs[#xs + 1], ys[#ys + 1] = v.left, v.top
            end
        end
    end
    local W2, H2 = GuiRoot:GetWidth() / 2, GuiRoot:GetHeight() / 2
    local cx, cy = Median(xs), Median(ys)
    if cx then
        group.position = { x = math.floor(cx - W2 + 0.5), y = math.floor(cy - H2 + 0.5) }
        if group.position.x == 0 and group.position.y == 0 then group.position.x = 1 end
    end
    local list, own = { group }, 0
    for _, p in ipairs(placed) do
        if p.worn and cx and math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2) > SEPARATE_PX and own < MAX_OWN
            and not U.Contains(group.trigger.procHidden, p.e.k) then
            local t = DT.Procs.TrackerFor(p.e, Look())
            t.fromExoY = true
            t.display.maxShown = 1
            t.conditions = Rules()
            t.load = U.Copy(load)
            t.trigger.procGameDurations, t.trigger.procZenBoss = true, group.trigger.procZenBoss
            t.position = { x = math.floor(p.x - W2 + 0.5), y = math.floor(p.y - H2 + 0.5) }
            if t.position.x == 0 and t.position.y == 0 then t.position.x = 1 end
            list[#list + 1] = t
            own = own + 1
            group.trigger.procHidden[#group.trigger.procHidden + 1] = p.e.k
        end
    end
    return list, { own = own, hidden = #group.trigger.procHidden }
end

local function FromExoY(t) return t.fromExoY == true end
M.IsFromExoY = FromExoY

function M.ImportExoY()
    local sv = M.FindExoY()
    if not sv then
        return nil, L("ExoY's ProcSet Timer isn't loaded. Enable it in the add-ons list (just once, for the import), reload, and try again.")
    end
    local old = {}
    for _, x in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromExoY(x) then old[#old + 1] = x.id end
    end
    for _, oid in ipairs(old) do DT.Profiles.RemoveTracker(oid) end
    local list, summary = M.ConvertExoY(sv)
    local added = DT.Profiles.AddTrackers(list)
    summary.replaced = #old
    DT.Profiles.SV().exoyImported = true
    return added, summary
end

function M.RemoveExoYImport()
    local old = {}
    for _, t in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromExoY(t) then old[#old + 1] = t.id end
    end
    for _, id in ipairs(old) do DT.Profiles.RemoveTracker(id) end
    return #old
end

------------------------------------------------------------------------------
-- Import from Meterskull (bibik92; 1.6.1).
--
-- It saves ZO_SavedVars:NewAccountWide("MeterskullSettings", 1, nil, defaults, GetWorldName()) -- or, with
-- "Account-wide Settings" off, NewCharacterIdSettings(...) for each character: sharedSettings = { combatOnly
-- (hide 5 s after combat), animationDuration (fast / standard / slow / off), show<Module> }, and per module
-- (armorskull, hybridarmorskull, powerskull, critskull, critresiskull, penskull, healthskull, magskull,
-- stamskull) = { location = {x, y} (top left, from the screen's top left), settings = { customScale (0-100,
-- 20 = 1x: 0.75x at 0, 1.5x at 100), backgroundColor, borderOpacity, textOpacity (%), levels = { [value] =
-- 3 x { level, color } } } } -- a value at or above a level (not 0) takes its colour, the later one wins.
-- DebuffTracker equivalent: the Library's "Character stats" trackers (Systems/Presets.lua), one per value,
-- with Meterskull's positions, sizes, colours, its thresholds as "Text color" rules, the animation and
-- "only in combat, 5 s after".
------------------------------------------------------------------------------

function M.FindMeterskull()
    local live = rawget(_G, "Meterskull")
    if type(live) == "table" and type(live.db) == "table" and type(live.db.sharedSettings) == "table" then return live.db end
    local raw = rawget(_G, "MeterskullSettings")
    if type(raw) ~= "table" then return nil end
    local world = type(GetWorldName) == "function" and GetWorldName() or nil
    local charId = type(GetCurrentCharacterId) == "function" and GetCurrentCharacterId() or nil
    local accountWide, mine, any
    local function Walk(t, depth, key)
        for k, v in pairs(t) do
            if type(v) == "table" then
                if type(v.sharedSettings) == "table" then
                    any = any or v
                    if k == "$AccountWide" then accountWide = accountWide or v end
                    if charId and tostring(k) == tostring(charId) then mine = v end
                elseif depth < 4 then
                    Walk(v, depth + 1, k)
                end
            end
        end
    end
    local acct = ThisAccount(raw)
    if acct then Walk(acct, 2) end
    if not (accountWide or mine) then Walk((world and raw[world]) or raw, 1) end
    if not (accountWide or mine) and world and raw[world] then Walk(raw, 1) end
    -- "Account-wide Settings" off: each character has its own
    if accountWide and accountWide.sharedSettings.accountWideSettings == false and mine then return mine end
    return accountWide or mine or any
end

local function FromMeterskull(t) return t.fromMeterskull == true end
M.IsFromMeterskull = FromMeterskull

-- Meterskull's size slider (0-100, 20 = 1x) -> DebuffTracker's scale
function M.MeterskullScale(v)
    v = tonumber(v) or 20
    if v == 20 then return 1 end
    if v < 20 then return 0.75 + 0.25 * (v / 20) end
    return 1 + 0.5 * ((v - 20) / 80)
end

local MS_ANIMS = { off = "off", fast = "fast", standard = "standard", slow = "slow" }

function M.MeterskullTrackers(sv)
    local shared = type(sv.shared) == "table" and sv.shared or (type(sv.sharedSettings) == "table" and sv.sharedSettings or {})
    local cx, cy = (GuiRoot and GuiRoot:GetWidth() or 1920) / 2, (GuiRoot and GuiRoot:GetHeight() or 1080) / 2
    local list = {}
    for _, m in ipairs(DT.Presets.METER_MODULES) do
        local mod = type(sv[m.key]) == "table" and sv[m.key] or {}
        local ms = type(mod.settings) == "table" and mod.settings or {}
        local levels = type(ms.levels) == "table" and ms.levels or {}
        local showKey = "show" .. m.key:gsub("^%l", string.upper)
        local on = shared[showKey]
        if on == nil then on = m.on == true end
        local ts = DT.Presets.MeterTrackers(m, function(i, st)
            -- its thresholds: "at or above <level> -> <colour>" for each level that isn't 0, in order (later wins)
            local rules = {}
            for _, l in ipairs(type(levels[st[2]]) == "table" and levels[st[2]] or {}) do
                local lvl = tonumber(type(l) == "table" and l.level) or 0
                if lvl ~= 0 and type(l.color) == "table" then
                    -- the crit resistance % tile shares the crit resistance levels: compared with the resistance
                    if st[1] == "critResistPct" then break end
                    rules[#rules + 1] = { prop = "value", op = ">=", value = lvl, action = "textColor", arg = U.Copy(l.color) }
                end
            end
            return rules
        end)
        local scale = M.MeterskullScale(ms.customScale)
        local bg = type(ms.backgroundColor) == "table" and ms.backgroundColor or { 0, 0, 0, 0.8 }
        local border = tonumber(ms.borderOpacity) or 50
        local text = (tonumber(ms.textOpacity) or 100) / 100
        for i, t in ipairs(ts) do
            t.enabled = on == true
            t.fromMeterskull = true
            local ds = t.display
            ds.scale = scale
            ds.background = { bg[1] or 0, bg[2] or 0, bg[3] or 0, bg[4] or 0.8 }
            ds.rowBorder = border > 0
            ds.borderSize = 1
            ds.borderColor = { 0.6, 0.6, 0.6, border / 100 }
            ds.textColor = { 1, 1, 1, text }
            ds.meterCaptionColor = { 0.95, 0.87, 0.64, text }
            ds.meterAnim = MS_ANIMS[shared.animationDuration] or "standard"
            if shared.combatOnly then t.load = { combat = "in", combatLinger = 5 } end
            if i == 1 then
                local loc = type(mod.location) == "table" and mod.location or nil
                if loc and tonumber(loc.x) and tonumber(loc.y) then
                    local x, y = math.floor(loc.x - cx + 0.5), math.floor(loc.y - cy + 0.5)
                    if x == 0 and y == 0 then x = 1 end      -- (0, 0) means "not placed yet"
                    t.position = { x = x, y = y }
                end
            end
            list[#list + 1] = t
        end
    end
    return list
end

function M.ImportMeterskull()
    local sv = M.FindMeterskull()
    if not sv then
        return nil, L("Meterskull isn't loaded. Enable it in the add-ons list (just once, for the import), reload, and try again.")
    end
    local list = M.MeterskullTrackers(sv)
    local old = {}
    for _, x in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromMeterskull(x) then old[#old + 1] = x.id end
    end
    for _, oid in ipairs(old) do DT.Profiles.RemoveTracker(oid) end
    local added = DT.Profiles.AddTrackers(list)
    local shown = 0
    for _, t in ipairs(added) do if t.enabled then shown = shown + 1 end end
    DT.Profiles.SV().meterskullImported = true
    return added, { trackers = #added, shown = shown, replaced = #old }
end

function M.RemoveMeterskullImport()
    local old = {}
    for _, t in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromMeterskull(t) then old[#old + 1] = t.id end
    end
    for _, id in ipairs(old) do DT.Profiles.RemoveTracker(id) end
    return #old
end

------------------------------------------------------------------------------
-- Miat's Ticks Tracker -> a "Resource tick" tracker (/dt miat). Its settings: MiatTickTrackerSettings, account-wide,
-- namespace "Settings" (ZO_SavedVars:NewAccountWide("MiatTickTrackerSettings", 1, "Settings", defaults)); while it's
-- loaded, MiatsTickTracker.SV is the same table.
------------------------------------------------------------------------------

local function LooksLikeMiat(t)
    return type(t) == "table" and (t.powerType ~= nil or t.regenColor ~= nil or t.preTickThreshold1 ~= nil)
end

function M.FindMiat()
    local live = rawget(_G, "MiatsTickTracker")
    if type(live) == "table" and LooksLikeMiat(live.SV) then return live.SV end
    local raw = rawget(_G, "MiatTickTrackerSettings")
    if type(raw) ~= "table" then return nil end
    -- exactly where Miat keeps it: ZO_SavedVars:NewAccountWide("MiatTickTrackerSettings", 1, "Settings")
    -- -> Default[@account]["$AccountWide"].Settings (1.12 keeps its table local, so the file is all there is to read)
    local mine = ThisAccount(raw)
    if mine and type(mine["$AccountWide"]) == "table" and LooksLikeMiat(mine["$AccountWide"].Settings) then
        return mine["$AccountWide"].Settings
    end
    local found
    local function Walk(t, depth)
        for k, v in pairs(t) do
            if type(v) == "table" then
                if k == "Settings" and LooksLikeMiat(v) then found = found or v
                elseif depth < 5 then Walk(v, depth + 1) end
            end
        end
    end
    if mine then Walk(mine, 2) end
    if not found then Walk(raw, 1) end
    return found
end

local function FromMiat(t) return t.fromMiat == true end
M.IsFromMiat = FromMiat

local function MiatColor(c, default)
    if type(c) ~= "table" then return U.Copy(default) end
    return { tonumber(c[1]) or default[1], tonumber(c[2]) or default[2], tonumber(c[3]) or default[3], tonumber(c[4]) or 1 }
end

function M.MiatTracker(sv)
    local res = "stamina"
    if sv.powerType == POWERTYPE_MAGICKA then res = "magicka" elseif sv.powerType == POWERTYPE_HEALTH then res = "health" end
    local scale = tonumber(sv.controlScale) or 1
    local width = math.floor((tonumber(sv.controlWidth) or 100) + 0.5)
    local t = DT.Presets.TickTracker({
        res = res, width = width, height = 27,
        regen = MiatColor(sv.regenColor, { 0, 1, 0, 1 }),
        zero = MiatColor(sv.zeroRegenColor, { 1, 0, 0, 1 }),
        pre1 = MiatColor(sv.preTickColor1, { 1, 1, 0, 1 }), t1 = tonumber(sv.preTickThreshold1) or 75,
        pre2 = MiatColor(sv.preTickColor2, { 1, 0.6, 0, 1 }), t2 = tonumber(sv.preTickThreshold2) or 85,
        fatigue = sv.showFatigue ~= false, fatigueMax = tonumber(sv.maxFatigueCount) or 5,
        fatigueMin = MiatColor(sv.minFatigueColor, { 1, 1, 0, 1 }), fatigueMaxColor = MiatColor(sv.maxFatigueColor, { 1, 0.1, 0, 1 }),
        showFull = sv.alwaysShown == true, showPct = sv.showBarPercentage ~= false, showGain = sv.showTickAmount ~= false,
        sound = (sv.playSound ~= false) and (type(sv.tickSound) == "string" and sv.tickSound or "COUNTDOWN_TICK") or nil,
        pulse = sv.playTickAnimation == true,
        background = MiatColor(sv.barBackgroundColor, { 0, 0, 0, 1 }),
    })
    t.fromMiat = true
    -- Where and how big Miat's bar really is (MiatsTickTracker.lua SetupControls / SavePosition, ui XML):
    --   * the frame is SetScale(controlScale), but its container is SetWidth(controlWidth / controlScale): on screen the
    --     bar is controlWidth wide and 27 x controlScale tall;
    --   * it's anchored by its CENTRE at (controlOffsetX, controlOffsetY) from the screen's centre (SavePosition stores
    --     GetCenter() minus half the screen); not moved yet = (0, 0), the screen's centre (the XML's 300 is replaced at
    --     once by SetupControls).
    -- Ours: the window is scaled the same, holds the bar inside its padding, and is placed by its top left corner. So
    -- the window is (controlWidth / scale + both sides' padding) wide, and its corner sits a padding up-left of the bar's.
    -- (5.20.0 used the scaled width twice and no padding: a scaled bar came out wider and lower than Miat's -- Yarden:
    -- "doesn't put the tracker in the same position as the one I had".)
    local s = U.Clamp(scale, 0.5, 2)
    t.display.scale = s
    local look = DT.Style and DT.Style.Look and DT.Style.Look(t.display) or { padX = 6, padBottom = 4 }
    local padX = look.padX or 6
    local pad = math.max(look.padBottom or 0, padX)      -- no header: top = bottom = the side padding (Display layout)
    t.display.width = math.floor(width / s + 2 * padX + 0.5)
    local ox, oy = tonumber(sv.controlOffsetX) or 0, tonumber(sv.controlOffsetY) or 0
    t.position = { x = math.floor(ox - width / 2 - padX * s + 0.5), y = math.floor(oy - 27 * s / 2 - pad * s + 0.5) }
    if t.position.x == 0 and t.position.y == 0 then t.position.x = 1 end
    return t
end

function M.ImportMiat()
    local sv = M.FindMiat()
    if not sv then
        return nil, L("Miat's Ticks Tracker isn't loaded. Enable it in the add-ons list (just once, for the import), reload, and try again.")
    end
    local old = {}
    for _, x in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromMiat(x) then old[#old + 1] = x.id end
    end
    for _, oid in ipairs(old) do DT.Profiles.RemoveTracker(oid) end
    local added = DT.Profiles.AddTrackers({ M.MiatTracker(sv) })
    return added, { replaced = #old, attached = sv.attachToDefaultBar == true }
end

function M.RemoveMiatImport()
    local old = {}
    for _, t in ipairs(DT.Profiles.ActiveTrackers()) do
        if FromMiat(t) then old[#old + 1] = t.id end
    end
    for _, id in ipairs(old) do DT.Profiles.RemoveTracker(id) end
    return #old
end

------------------------------------------------------------------------------
-- Combat Metronome / GCD Bar / Global Cooldown Monitor -> "Global cooldown" trackers (/dt gcd). Whichever is
-- installed (enabled once); each becomes its own tracker where its bar was.
--   CombatMetronomeSavedVars (ZO_SavedVars v2, per character or "$AccountWide"): .Progressbar = { xOffset, yOffset
--     (top left), width, height, progressColor, pingColor, channelColor + changeOnChanneled, dontShowPing, maxLatency,
--     globalAbilityAdjust, globalHeavyAdjust, stopHATracking, dontHide, sound tick / tock (+ effect: a SOUNDS value) }
--   GCDBarSavedVars (per character): frameX, frameY (top left), width, height, color, reverse
--   GCDMonitor_Settings (namespace "Settings"): FrameLeft / FrameTop, FrameSize, CDColor, AlertColor, LATime,
--     cTimeAdd, AutoHide (a radial icon -> an icon here)
------------------------------------------------------------------------------

local function Walk(t, depth, test, found)
    if type(t) ~= "table" or depth > 6 then return found end
    for _, v in pairs(t) do
        if type(v) == "table" then
            if test(v) then found[#found + 1] = v else Walk(v, depth + 1, test, found) end
        end
    end
    return found
end
local function Mine(list)
    -- this character's if it can be told, else this account's (account-wide), else any
    local charId = type(GetCurrentCharacterId) == "function" and tostring(GetCurrentCharacterId()) or nil
    local raw = list.raw
    if charId and raw then
        for _, acct in pairs(raw.Default or {}) do
            if type(acct) == "table" and type(acct[charId]) == "table" then
                for _, x in ipairs(list) do if x == acct[charId] or x == acct[charId].Settings then return x end end
            end
        end
    end
    local acct = raw and ThisAccount(raw)
    if acct then
        local own = Walk(acct, 1, function(v) for _, x in ipairs(list) do if x == v then return true end end return false end, {})
        if own[1] then return own[1] end
    end
    return list[1]
end

local function SoundKey(value)
    if type(value) ~= "string" or not SOUNDS then return nil end
    if SOUNDS[value] then return value end
    for k, v in pairs(SOUNDS) do if v == value then return k end end
    return nil
end

local function Col(c, d) return (type(c) == "table" and tonumber(c[1])) and { tonumber(c[1]), tonumber(c[2]) or 0, tonumber(c[3]) or 0, tonumber(c[4]) or 1 } or U.Copy(d) end

function M.FindGcdAddons()
    local out = {}
    local cm = rawget(_G, "CombatMetronomeSavedVars")
    if type(cm) == "table" then
        local l = Walk(cm, 1, function(v) return type(v.Progressbar) == "table" end, {})
        l.raw = cm
        if #l > 0 then out.metronome = Mine(l).Progressbar end
    end
    local live = rawget(_G, "CombatMetronome")
    if not out.metronome and type(live) == "table" and type(live.SV) == "table" and type(live.SV.Progressbar) == "table" then
        out.metronome = live.SV.Progressbar
    end
    local gb = rawget(_G, "GCDBarSavedVars")
    if type(gb) == "table" then
        local l = Walk(gb, 1, function(v) return v.frameX ~= nil and v.width ~= nil end, {})
        l.raw = gb
        if #l > 0 then out.gcdbar = Mine(l) end
    end
    local gm = rawget(_G, "GCDMonitor_Settings")
    if type(gm) == "table" then
        local l = Walk(gm, 1, function(v) return v.FrameSize ~= nil or v.LATime ~= nil end, {})
        l.raw = gm
        if #l > 0 then out.monitor = Mine(l) end
    end
    if not (out.metronome or out.gcdbar or out.monitor) then return nil end
    return out
end

function M.GcdTrackers(found)
    local cx, cy = (GuiRoot and GuiRoot:GetWidth() or 1920) / 2, (GuiRoot and GuiRoot:GetHeight() or 1080) / 2
    local list = {}
    local function Place(t, left, top)
        left, top = tonumber(left), tonumber(top)
        if left and top then
            local x, y = math.floor(left - cx + 0.5), math.floor(top - cy + 0.5)
            if x == 0 and y == 0 then x = 1 end
            t.position = { x = x, y = y }
        end
    end
    local function Get(m, k, d) if m[k] == nil then return d end return m[k] end
    local m = found.metronome
    if m then
        -- every Progressbar option (CMMiscellaneous.lua DEFAULT_SAVED_VARS for the ones never set)
        local t = DT.Presets.GcdBar()
        t.name = L("Global cooldown (Combat Metronome)")
        t.enabled = not (m.hide or m.hideProgressbar)
        local tr, ds = t.trigger, t.display
        ds.width, ds.height = tonumber(m.width) or 303, tonumber(m.height) or 30
        ds.colorSolid = Col(m.progressColor, { 1, 0.84, 0.24, 0.63 })
        ds.background = Col(m.backgroundColor, { 0, 0, 0, 0.5 })
        ds.zoneColor = Col(m.pingColor, { 1, 0, 0, 0.63 })
        local align = Get(m, "barAlign", "Center")
        ds.fillCenter, ds.fillReverse = align == "Center", align == "Right"
        if C.Find(C.FONT_FACES, m.labelFont) then ds.fontFace = m.labelFont end
        if C.Find(C.FONT_EFFECTS, m.fontStyle) then ds.fontEffect = m.fontStyle end
        if tonumber(m.spellSize) then ds.fontSize = tonumber(m.spellSize) end
        local showSpell = Get(m, "showSpell", true)
        ds.labelFormat = showSpell and "{name}" or ""
        ds.showRowIcon = showSpell
        ds.showTimer = Get(m, "showTimeRemaining", true)
        tr.gcdNames = (m.alwaysShowSpell or m.alwaysShowTimeRemaining) and "all" or "timed"
        tr.gcdHeavy = not m.stopHATracking
        tr.gcdHeavyNames = m.showHeavyDetails == true
        tr.gcdPing = not m.dontShowPing
        tr.gcdMaxPing = tonumber(Get(m, "maxLatency", 150)) or 150
        tr.gcdHeavyPing = Get(m, "displayPingOnHeavy", true) ~= false
        tr.gcdOtherPing = Get(m, "showPingOnGCD", true) ~= false
        tr.gcdAdjust = tonumber(Get(m, "gcdAdjust", 0)) or 0
        tr.gcdCastAdjust = tonumber(Get(m, "globalAbilityAdjust", 25)) or 25
        tr.gcdHeavyAdjust = tonumber(Get(m, "globalHeavyAdjust", 25)) or 25
        local per = {}
        for id, ms in pairs(type(m.abilityAdjusts) == "table" and m.abilityAdjusts or {}) do
            if tonumber(id) and tonumber(ms) then per[#per + 1] = { id = tonumber(id), ms = tonumber(ms) } end
        end
        table.sort(per, function(a, b) return a.id < b.id end)
        tr.gcdAbilityAdjust = per
        tr.gcdIdle = m.dontHide == true
        tr.gcdOther = m.trackGCD == true
        tr.gcdMountName = m.showMountNick == true
        -- the metronome
        tr.gcdTick, tr.gcdTock = m.soundTickEnabled == true, m.soundTockEnabled == true
        tr.gcdTickSound = SoundKey(m.soundTickEffect) or m.soundTickEffect or "Justice_PickpocketFailed"
        tr.gcdTockSound = SoundKey(m.soundTockEffect) or m.soundTockEffect or "Dialog_Decline"
        tr.gcdTickAt = m.forceTickMSBeforeEnd and "end" or (m.soundTickMidAbility and "mid" or "start")
        tr.gcdTickOffset = tonumber(Get(m, "soundTickOffset", 200)) or 200
        tr.gcdTickBeforeEnd = tonumber(Get(m, "forceTickTime", 500)) or 500
        tr.gcdTockOffset = tonumber(Get(m, "soundTockOffset", 300)) or 300
        tr.gcdTockForce = Get(m, "forceSoundTock", true) ~= false
        tr.gcdSoundHeavy = not m.noTickOnHeavy
        tr.gcdSoundLong = not m.noSoundOnLongAbilities
        tr.gcdSoundOOC = m.playSoundsOOC == true
        tr.gcdVolume = tonumber(Get(m, "tickVolume", 5)) or 5
        -- its colours: the channel colour only when it changed colour on channels; no heavy / green colours there
        t.conditions = {}
        if m.changeOnChanneled then
            t.conditions[1] = { prop = "gcdCasting", op = "==", value = "true", action = "color", arg = Col(m.channelColor, { 1, 0, 1, 0.63 }) }
        end
        local load = {}
        if not m.showOOC then load.combat = "in" end          -- abilities are tracked out of combat only with "Show OOC"
        if m.hideCMInPVP or m.hideInPVP then load.zoneTypes, load.never = { pvp = true }, { zones = true } end
        if next(load) then t.load = load end
        -- its spell icon sits outside the bar, on its left: the row here holds both, the bar keeps its length
        if showSpell then
            ds.width = ds.width + ds.height
            if tonumber(m.xOffset) then Place(t, tonumber(m.xOffset) - ds.height, m.yOffset) end
        else
            Place(t, m.xOffset, m.yOffset)
        end
        list[#list + 1] = t
    end
    local b = found.gcdbar
    if b then
        -- just the GCD, polled (no skill names, no casts, no heavies, no ping)
        local t = DT.Presets.GcdBar()
        t.name = L("Global cooldown (GCD Bar)")
        t.enabled = b.hideFrame ~= true
        local tr, ds = t.trigger, t.display
        ds.width, ds.height = tonumber(b.width) or 175, tonumber(b.height) or 50
        ds.colorSolid = Col(b.color, { 1, 0, 0, 0.7 })
        ds.background = { 0, 0, 0, 0.25 }
        ds.fillReverse = b.reverse == true
        ds.showRowIcon, ds.labelFormat, ds.showTimer = false, "", false
        ds.scale = tonumber(b.scale) or 1
        tr.gcdHeavy, tr.gcdCasts, tr.gcdChannels, tr.gcdPing, tr.gcdOther = false, false, false, false, true
        t.conditions = {}
        Place(t, b.frameX, b.frameY)
        list[#list + 1] = t
    end
    local g = found.monitor
    if g then
        -- a round sweep: the GCD, channels over 1 s + its delay; the alert colour for the last moments
        local t = DT.Presets.GcdBar()
        t.name = L("Global cooldown (Global Cooldown Monitor)")
        t.display = { type = "icons", showHeader = false, iconSize = tonumber(g.FrameSize) or 50, iconTimer = "sweep",
            showTimer = false, showName = false, colorSolid = Col(g.CDColor, { 1, 1, 1, 1 }),
            background = g.hideBG and { 0, 0, 0, 0 } or { 0.055, 0.067, 0.082, 0.82 } }
        local tr = t.trigger
        tr.gcdHeavy, tr.gcdCasts, tr.gcdChannels, tr.gcdPing, tr.gcdOther = false, false, true, false, true
        tr.gcdChannelExtra = tonumber(Get(g, "cTimeAdd", 100)) or 100
        local alert = Col(g.AlertColor, { 0, 1, 0, 1 })
        t.conditions = {
            { prop = "remaining", op = "<", value = (tonumber(Get(g, "LATime", 100)) or 100) / 1000, action = "glow", arg = alert,
              also = { prop = "gcdKind", op = "~=", value = "channel" } },
            { prop = "remaining", op = "<", value = (tonumber(Get(g, "cLATime", 100)) or 100) / 1000, action = "glow", arg = U.Copy(alert),
              also = { prop = "gcdKind", op = "==", value = "channel" } },
        }
        if g.AlertLong then
            -- "show alert colour after cooldown": the idle icon in the alert colour
            tr.gcdIdle = true
            t.conditions[#t.conditions + 1] = { prop = "gcdKind", op = "==", value = "idle", action = "glow", arg = U.Copy(alert) }
        end
        if g.AutoHide then t.load = { combat = "in" } end
        Place(t, g.FrameLeft, g.FrameTop)
        list[#list + 1] = t
    end
    for _, t in ipairs(list) do t.fromGcd = true end
    return list
end

function M.ImportGcd()
    local found = M.FindGcdAddons()
    if not found then
        return nil, L("None of Combat Metronome, GCD Bar or Global Cooldown Monitor is loaded. Enable the one you use in the add-ons list (just once, for the import), reload, and try again.")
    end
    local old = {}
    for _, x in ipairs(DT.Profiles.ActiveTrackers()) do if x.fromGcd then old[#old + 1] = x.id end end
    for _, oid in ipairs(old) do DT.Profiles.RemoveTracker(oid) end
    local added = DT.Profiles.AddTrackers(M.GcdTrackers(found))
    local names = {}
    if found.metronome then names[#names + 1] = "Combat Metronome" end
    if found.gcdbar then names[#names + 1] = "GCD Bar" end
    if found.monitor then names[#names + 1] = "Global Cooldown Monitor" end
    return added, { replaced = #old, from = table.concat(names, ", ") }
end

function M.RemoveGcdImport()
    local old = {}
    for _, t in ipairs(DT.Profiles.ActiveTrackers()) do if t.fromGcd then old[#old + 1] = t.id end end
    for _, id in ipairs(old) do DT.Profiles.RemoveTracker(id) end
    return #old
end
