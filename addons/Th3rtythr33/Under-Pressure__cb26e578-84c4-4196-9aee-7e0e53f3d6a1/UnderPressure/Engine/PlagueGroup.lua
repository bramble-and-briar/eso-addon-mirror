-- =============================================================================
-- Under Pressure -- PlagueGroup.lua
-- =============================================================================
-- Which GROUPMATES are carrying a Plaguebreak plague right now (0.5.7,
-- EXPERIMENTAL, off by default: sv.plague_group_detect).
--
-- Why it matters: a plague explodes on everyone within 8 m of the PERSON
-- CARRYING IT when it is removed early. Your own plague is PlagueTracker's
-- business; this module answers the other question, "who in my group should I
-- be standing clear of?", and says so when the answer changes: on screen
-- ("<name> tested positive for the plague!", a centre-screen announcement,
-- sv.plague_group_screen) and/or in chat (sv.plague_group_alert).
--
-- HOW THE DATA ARRIVES. EVENT_EFFECT_CHANGED fires for every unit tag the
-- client holds for a unit, and group members hold "group1".."group12" (ZOS:
-- the event "will continue to be sent for each applicable unit tag"). So the
-- plague debuff landing on a groupmate reaches us as an effect event with
-- unitTag "groupN" and the member's name, and GetNumBuffs/GetUnitBuffInfo
-- read the same list on demand. EventIngest registers for it filtered by
-- REGISTER_FILTER_ABILITY_ID (the plague id) and REGISTER_FILTER_UNIT_TAG_PREFIX
-- "group", which is exactly the registration Group Buff Panels (code65536,
-- ships on Xbox and PlayStation) uses to track buffs on group members, and
-- LuiExtended's group food-buff tracker uses the same prefix filter and the
-- same buff reads. Neither records a range limit; what we know is that a
-- member who leaves the client's view may simply stop producing events, so a
-- plague whose FADED never arrives is dropped quietly once its own end time
-- has passed (prune), never announced as "removed early".
--
-- Two consequences of "every applicable unit tag" that the code below handles:
--   * the LOCAL PLAYER is also "groupN" while grouped, so our own plague
--     arrives here too. AreUnitsEqual("player", unitTag) screens it out; this
--     module is about other people.
--   * a refresh arrives as UPDATED (or a second GAINED) for a tag already
--     known, which must not re-announce.
--
-- Whether group-tag effect events arrive on console at all is the one thing
-- source cannot settle, which is why the switch is labelled Experimental and
-- off. The API audit prints the registration mode and a count of group plague
-- events seen this session; a non-zero count on hardware is the proof.
--
-- The on-screen line goes through ZOS's own centre-screen announcer
-- (CENTER_SCREEN_ANNOUNCE, one shared file for both platforms, used by every
-- "X has joined the group" style message): CSA_CATEGORY_SMALL_TEXT with the
-- SYSTEM_BROADCAST type, the same shape ZOS uses for EVENT_BROADCAST and the
-- one type allowed through even during scrying and Tribute. No sound. Every
-- call is pcall-wrapped so a renamed method degrades to "no message".
--
-- Nothing here registers events; EventIngest owns the registration and its
-- teardown (UP.Ingest.SetGroupPlagueDetection), so switching the setting off
-- stops group effect events reaching Lua at all.
-- =============================================================================

UP = UP or {}
UP.PlagueGroup = {}

local EFFECT_FADED = (type(EFFECT_RESULT_FADED) == "number") and EFFECT_RESULT_FADED or 2

local EARLY_FADE_MS  = 750     -- same meaning as PlagueTracker's: FADED this far before endTime is a removal
local PRUNE_GRACE_MS = 1000    -- a carrier whose end time passed this long ago without a FADED is forgotten
local PREFIX = "[Under Pressure] "

-- [unitTag] = { name = display name, endMs = 0 or end time in ms, gainedMs = }
local carriers = {}
local eventsSeen = 0           -- group plague effect events handed to OnEffect (audit)
local channel = "off"          -- "filtered" | "prefix" | "abilityId" | "unavailable" | "off"; set by EventIngest

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------
function UP.PlagueGroup.Enabled()
    return UP.sv ~= nil and UP.sv.plague_group_detect == true
end

local function chatOn()
    local sv = UP.sv
    return not sv or sv.plague_group_alert ~= false
end

local function screenOn()
    local sv = UP.sv
    return not sv or sv.plague_group_screen ~= false
end

-- ---------------------------------------------------------------------------
-- Output
-- ---------------------------------------------------------------------------
local function say(line)
    if not chatOn() then return end
    if type(d) == "function" then d(PREFIX .. line) end
end

-- Centre-screen small text, ZOS's own broadcast shape. Returns true if queued.
local function announce(text)
    if not screenOn() then return false end
    local csa = CENTER_SCREEN_ANNOUNCE
    if type(csa) ~= "table" or type(csa.CreateMessageParams) ~= "function"
       or type(csa.AddMessageWithParams) ~= "function" then
        return false
    end
    local ok = pcall(function()
        local sound = (type(SOUNDS) == "table") and SOUNDS.NONE or nil
        local params = csa:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, sound)
        params:SetText(text)
        if type(CENTER_SCREEN_ANNOUNCE_TYPE_SYSTEM_BROADCAST) == "number" then
            params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_SYSTEM_BROADCAST)
        end
        csa:AddMessageWithParams(params)
    end)
    return ok == true
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function isSelf(unitTag)
    if type(AreUnitsEqual) == "function" then
        local ok, same = pcall(AreUnitsEqual, "player", unitTag)
        if ok then return same == true end
    end
    -- Fallback: compare raw names. Only reached if the native is missing.
    if type(GetUnitName) == "function" then
        local ok1, a = pcall(GetUnitName, "player")
        local ok2, b = pcall(GetUnitName, unitTag)
        return ok1 and ok2 and a ~= nil and a ~= "" and a == b
    end
    return false
end

local function isPlague(abilityId, name)
    if UP.Plague and UP.Plague.IsPlagueEffect then
        return UP.Plague.IsPlagueEffect(abilityId, name)
    end
    return abilityId == 159612
end

-- The member's name as the player would recognise it. ZO_GetPrimaryPlayerName
-- honours the user's own "show character / account name" preference when it
-- exists; otherwise the character name from the event, formatted.
local function nameFor(unitTag, eventUnitName)
    local character = eventUnitName
    if (character == nil or character == "") and type(GetUnitName) == "function" then
        local ok, n = pcall(GetUnitName, unitTag)
        if ok and type(n) == "string" then character = n end
    end
    local display = nil
    if type(GetUnitDisplayName) == "function" then
        local ok, n = pcall(GetUnitDisplayName, unitTag)
        if ok and type(n) == "string" and n ~= "" then display = n end
    end
    if display and type(ZO_GetPrimaryPlayerName) == "function" then
        local ok, n = pcall(ZO_GetPrimaryPlayerName, display, character or "")
        if ok and type(n) == "string" and n ~= "" then return n end
    end
    if type(character) == "string" and character ~= "" then
        if type(zo_strformat) == "function" and type(SI_UNIT_NAME) == "number" then
            local ok, n = pcall(zo_strformat, SI_UNIT_NAME, character)
            if ok and type(n) == "string" and n ~= "" then return n end
        end
        return (character:gsub("%^.*$", ""))
    end
    return display or unitTag
end

local function secs(ms)
    if type(ms) ~= "number" or ms <= 0 then return "?" end
    return ("%.0f"):format(ms / 1000)
end

local function recount()
    local n = 0
    for _ in pairs(carriers) do n = n + 1 end
    return n
end

-- Forget carriers whose own end time is well past with no FADED seen (the
-- member left our view, or the event was dropped). Quiet: we do not know
-- whether it ran out or was cleansed.
local function prune(nowMs)
    for tag, c in pairs(carriers) do
        if c.endMs and c.endMs > 0 and nowMs > c.endMs + PRUNE_GRACE_MS then
            carriers[tag] = nil
        end
    end
end

-- ---------------------------------------------------------------------------
-- Ingest
-- ---------------------------------------------------------------------------
-- Called by EventIngest for EVENT_EFFECT_CHANGED on a "groupN" tag. endTimeMs
-- is already converted (0 = no timed expiry).
function UP.PlagueGroup.OnEffect(changeType, unitTag, unitName, abilityId, effectName, endTimeMs, nowMs)
    if type(unitTag) ~= "string" then return end
    if not isPlague(abilityId, effectName) then return end
    eventsSeen = eventsSeen + 1
    if isSelf(unitTag) then return end

    prune(nowMs)
    local known = carriers[unitTag]

    if changeType == EFFECT_FADED then
        if not known then return end
        carriers[unitTag] = nil
        local remaining = (known.endMs and known.endMs > 0) and (known.endMs - nowMs) or 0
        if remaining > EARLY_FADE_MS then
            say(("%s's plague was removed early with %ss left: it exploded on everyone within 8 m of them."):format(
                known.name, secs(remaining)))
        else
            say(("%s's plague has run out."):format(known.name))
        end
        return
    end

    -- GAINED / UPDATED / FULL_REFRESH
    local name = nameFor(unitTag, unitName)
    if known then
        known.name  = name
        known.endMs = (type(endTimeMs) == "number" and endTimeMs > 0) and endTimeMs or known.endMs
        return
    end
    carriers[unitTag] = {
        name     = name,
        endMs    = (type(endTimeMs) == "number" and endTimeMs > 0) and endTimeMs or 0,
        gainedMs = nowMs,
    }
    local left = carriers[unitTag].endMs > 0 and (carriers[unitTag].endMs - nowMs) or 0
    announce(("%s tested positive for the plague!"):format(name))
    say(("%s tested positive for the plague! Stay 8 m clear of them%s."):format(
        name, left > 0 and (" for the next %ss"):format(secs(left)) or ""))
end

-- Re-read every groupmate's buff list. Used when detection is switched on,
-- after a load screen and whenever the group changes. Quiet: nothing is
-- announced from a resync, it only brings the table in line with what the
-- client already shows.
function UP.PlagueGroup.Resync()
    local fresh = {}
    if type(GetGroupSize) == "function" and type(GetGroupUnitTagByIndex) == "function"
       and type(GetNumBuffs) == "function" and type(GetUnitBuffInfo) == "function" then
        local okSize, size = pcall(GetGroupSize)
        if okSize and type(size) == "number" then
            local nowMs = GetGameTimeMilliseconds()
            for i = 1, size do
                local okTag, tag = pcall(GetGroupUnitTagByIndex, i)
                if okTag and type(tag) == "string" and tag ~= "" and not isSelf(tag) then
                    local okN, n = pcall(GetNumBuffs, tag)
                    if okN and type(n) == "number" then
                        for b = 1, n do
                            local ok, buffName, _, timeEnding, _, _, _, _, _, _, _, abilityId = pcall(GetUnitBuffInfo, tag, b)
                            if ok and isPlague(abilityId, buffName) then
                                local endMs = (type(timeEnding) == "number" and timeEnding > 0) and timeEnding * 1000 or 0
                                local known = carriers[tag]
                                fresh[tag] = {
                                    name     = nameFor(tag, nil),
                                    endMs    = endMs,
                                    gainedMs = known and known.gainedMs or nowMs,
                                }
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    carriers = fresh
end

-- Group membership changed (join, leave, load screen): tags can now point at
-- different people, so rebuild from the buff lists rather than trusting them.
function UP.PlagueGroup.OnGroupChanged()
    UP.PlagueGroup.Resync()
end

function UP.PlagueGroup.Clear()
    carriers = {}
end

-- ---------------------------------------------------------------------------
-- Readers
-- ---------------------------------------------------------------------------
function UP.PlagueGroup.Count(nowMs)
    prune(nowMs or GetGameTimeMilliseconds())
    return recount()
end

function UP.PlagueGroup.Snapshot(nowMs)
    nowMs = nowMs or GetGameTimeMilliseconds()
    prune(nowMs)
    local out = {}
    for tag, c in pairs(carriers) do
        out[#out + 1] = { unitTag = tag, name = c.name, endMs = c.endMs,
                          remainingMs = (c.endMs > 0) and (c.endMs - nowMs) or 0 }
    end
    table.sort(out, function(a, b) return a.unitTag < b.unitTag end)
    return out
end

-- One line for the debug overlay: "off", "none", or "Bob 4s, Alice 9s".
function UP.PlagueGroup.Summary(nowMs)
    if not UP.PlagueGroup.Enabled() then return "off" end
    local list = UP.PlagueGroup.Snapshot(nowMs)
    if #list == 0 then return "none" end
    local parts = {}
    for _, c in ipairs(list) do
        parts[#parts + 1] = c.remainingMs > 0 and ("%s %ss"):format(c.name, secs(c.remainingMs)) or c.name
    end
    return table.concat(parts, ", ")
end

function UP.PlagueGroup.EventsSeen() return eventsSeen end
function UP.PlagueGroup.Channel() return channel end
function UP.PlagueGroup.SetChannel(mode) channel = mode or "off" end

-- Test hook: the exact on-screen text, so the harness and the docs agree.
function UP.PlagueGroup.ScreenText(name) return ("%s tested positive for the plague!"):format(name) end

function UP.PlagueGroup.Init()
    carriers = {}
    eventsSeen = 0
end
