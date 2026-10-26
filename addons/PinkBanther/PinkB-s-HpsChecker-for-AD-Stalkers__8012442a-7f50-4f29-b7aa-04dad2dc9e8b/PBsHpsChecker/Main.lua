PBsHpsChecker = PBsHpsChecker or {}
local ADDON = PBsHpsChecker

---------------------------------------------------------------------------------------------------
-- PB's HPS Checker
-- Author: PinkBanther
--
-- Shows how much the player heals in PvP: the amount, the healing per second (HPS), whom it went
-- to and with which skill -- and how much of it went to the party, to everybody else, and to the
-- player themself. It only reads game events; nothing is pressed or cast for the player.
--
-- HOW HEALS ARE READ
--
-- EVENT_COMBAT_EVENT with the player as the source, for the four heal results: a heal, a critical
-- heal, a heal-over-time tick and a critical tick. The engine does the filtering (one registration
-- per result, because a filter holds one value per field). The target's type says which share a heal
-- belongs to: COMBAT_UNIT_TYPE_GROUP is the party, COMBAT_UNIT_TYPE_PLAYER the player, and
-- COMBAT_UNIT_TYPE_OTHER everybody outside the party. The player's own pets and companions are not
-- counted (they are not players), and neither is a training dummy.
--
-- The player's share of what a party member RECEIVES needs the heals other healers do to that member
-- too. Those come through four more registrations, filtered on the target being a party member
-- (COMBAT_UNIT_TYPE_GROUP), for as long as "count other healers" is on. The player's own heals arrive
-- there as well and are ignored (their own handler counts them).
--
-- UNMEASURED on console, so /hps status, /hps debug and /hps probe exist: what a heal on somebody
-- outside the party reports as its target name and type, whether hitValue already has the overheal
-- taken off (see Records.ReadAmounts), and whether other healers' heals on party members arrive at all.
---------------------------------------------------------------------------------------------------

local DISPLAY_NAME = "PB’s HPS Checker"
local SAVED_VARS_NAME = "PBsHpsChecker_Data"
local SAVED_VARS_VERSION = 1
local TICK_MS = 1000
local DEBUG_LINES = 200

ADDON.name = "PBsHpsChecker"
ADDON.author = "PinkBanther"
ADDON.displayName = DISPLAY_NAME
ADDON.title = DISPLAY_NAME
ADDON.version = ""

ADDON.ZONES = { "cyrodiil", "pvp", "all" }

-- How many places the rankings (players healed, skills) show, in the statistics window and in chat.
ADDON.RANKING_ROWS = 10

ADDON.defaults = {
    enabled = true,
    -- Where heals are counted: "cyrodiil" (Cyrodiil itself), "pvp" (every PvP zone) or "all".
    zones = "cyrodiil",
    -- A fight ends when no heal has come for this many seconds.
    gapSec = 10,
    -- Show a player's PSN ID in the rankings where it is known (Names.lua), else the character name.
    showPsn = true,
    -- Count the heals other healers do to party members as well, for "your share of what a party
    -- member received".
    countOthers = true,
    hud = true,
    -- The HUD stays up this long after a fight ends, so the result can be read.
    hudHoldSec = 10,
    -- The HUD meter's text size, 1 (smallest) to 7 (largest); 4 is the standard one.
    hudSize = 4,
    -- The box itself: as big as its text needs, or this many pixels wide and high when hudCustomSize is on.
    hudCustomSize = false,
    hudWidth = 600,
    hudHeight = 220,
    hudLeft = 60,
    hudTop = 560,
}

local records = ADDON.records
local sv
local zoneOk = false
local debugLeft = 0

-- What the engine has told us, for /hps status: how many heals arrived, and of which target type.
local counters = {
    seen = 0, counted = 0, skippedZone = 0, skippedTarget = 0, byType = {},
    incoming = 0, incomingCounted = 0, incomingSkipped = 0,
}
ADDON.counters = counters

local function Print(text)
    d(text)
end
ADDON.Print = Print

---------------------------------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------------------------------

-- The height the client draws one line of a font at, which is what a row has to hold. The
-- Japanese client draws the named gamepad fonts smaller than the number in their name says, so the
-- layout is worked out from this and not from the number.
local function FontProbe()
    local probe = ADDON.fontProbe
    if not probe then
        probe = WINDOW_MANAGER:CreateControl(ADDON.name .. "FontProbe", GuiRoot, CT_LABEL)
        probe:SetHidden(true)
        ADDON.fontProbe = probe
    end
    return probe
end

-- How wide the client draws a text in a font, in UI units; nil when the client does not say. A label
-- that is too narrow for its text ends in "..." from the right, so rows are laid out from this and not
-- from a guess about how wide a glyph is.
function ADDON.MeasureText(font, text)
    local probe = FontProbe()
    probe:SetFont(font)
    probe:SetText(text)
    local width = type(probe.GetTextWidth) == "function" and probe:GetTextWidth() or nil
    if type(width) ~= "number" or width <= 0 then
        return nil
    end
    return width
end

function ADDON.MeasureFont(font)
    local probe = FontProbe()
    probe:SetFont(font)
    local height = type(probe.GetFontHeight) == "function" and probe:GetFontHeight() or 0
    if type(height) ~= "number" or height <= 0 then
        -- No answer: the number in the font's name, which a Western client draws it at, and a line
        -- is a little taller than that.
        height = math.ceil((tonumber(font:match("(%d+)$")) or 20) * 1.3)
    end
    return height
end

---------------------------------------------------------------------------------------------------
-- Where heals are counted
---------------------------------------------------------------------------------------------------

-- Cyrodiil itself, and nothing else the PvP zones also cover. The Imperial City is a zone of its own
-- (IsInCyrodiil is false there), its campaigns are fought on a different map entirely even though the
-- world is still Cyrodiil's, and a Battleground is neither. Same cut as PB's KillLog.
function ADDON.IsInCyrodiil()
    if not IsInCyrodiil() or IsInImperialCity() or IsActiveWorldBattleground() then
        return false
    end
    local campaignId = GetCurrentCampaignId()
    return campaignId == 0 or not IsImperialCityCampaign(campaignId)
end

function ADDON.ZoneAllowed()
    local mode = sv.zones
    if mode == "all" then
        return true
    elseif mode == "pvp" then
        return IsPlayerInAvAWorld() or IsInImperialCity() or IsActiveWorldBattleground()
    end
    return ADDON.IsInCyrodiil()
end

-- Looked up when a loading screen ends, which is how a player gets into or out of a zone, and when
-- the setting changes. Never per heal.
function ADDON.RefreshZone()
    zoneOk = ADDON.ZoneAllowed() and true or false
    return zoneOk
end

---------------------------------------------------------------------------------------------------
-- Heal events
---------------------------------------------------------------------------------------------------

-- Who was healed, from the event's target type. A pet, a companion, a dummy and "nobody" are not in
-- the table, so they are not counted.
local KIND_BY_TYPE = {
    [COMBAT_UNIT_TYPE_GROUP] = records.KIND_GROUP,
    [COMBAT_UNIT_TYPE_OTHER] = records.KIND_OTHER,
    [COMBAT_UNIT_TYPE_PLAYER] = records.KIND_SELF,
}

local TYPE_NAMES = { "GROUP", "OTHER", "PLAYER", "PLAYER_PET", "PLAYER_COMPANION", "TARGET_DUMMY", "NONE" }

local function TypeName(value)
    for _, name in ipairs(TYPE_NAMES) do
        if _G["COMBAT_UNIT_TYPE_" .. name] == value then
            return name
        end
    end
    return tostring(value)
end

ADDON.TYPE_NAMES = TYPE_NAMES
ADDON.TypeName = TypeName

local function MakeHealHandler(isCrit, isTick)
    return function(_, _, isError, abilityName, _, _, _, _, targetName, targetType, hitValue, _, _, _, _, _, abilityId, overflow)
        if isError then
            return
        end
        counters.seen = counters.seen + 1
        counters.byType[targetType] = (counters.byType[targetType] or 0) + 1
        if not sv.enabled then
            return
        end
        if not zoneOk then
            counters.skippedZone = counters.skippedZone + 1
            return
        end
        local kind = KIND_BY_TYPE[targetType]
        if not kind then
            counters.skippedTarget = counters.skippedTarget + 1
            return
        end

        local hit, over = records.ReadAmounts(hitValue, overflow)
        if debugLeft > 0 then
            debugLeft = debugLeft - 1
            Print(string.format("[HPS] %s%s id=%s %s > %s (%s) hit=%s over=%s",
                isTick and "tick " or "heal ", isCrit and "crit " or "", tostring(abilityId), tostring(abilityName),
                tostring(targetName), TypeName(targetType), tostring(hitValue), tostring(overflow)))
            if debugLeft == 0 then
                Print(GetString(SI_PBSHPS_DEBUG_FULL))
            end
        end

        if records:RecordHeal(GetFrameTimeMilliseconds(), kind, targetName, abilityId, abilityName, hit, over, isCrit, isTick) then
            counters.counted = counters.counted + 1
            if ADDON.hud then
                ADDON.hud:Poke()
            end
        end
    end
end

-- Four registrations, one per result: a filter holds one value per field.
local HEAL_RESULTS = {
    { name = "Heal", result = ACTION_RESULT_HEAL, crit = false, tick = false },
    { name = "CritHeal", result = ACTION_RESULT_CRITICAL_HEAL, crit = true, tick = false },
    { name = "Tick", result = ACTION_RESULT_HOT_TICK, crit = false, tick = true },
    { name = "CritTick", result = ACTION_RESULT_HOT_TICK_CRITICAL, crit = true, tick = true },
}

local function RegisterHealEvents()
    for _, entry in ipairs(HEAL_RESULTS) do
        local namespace = ADDON.name .. entry.name
        EVENT_MANAGER:RegisterForEvent(namespace, EVENT_COMBAT_EVENT, MakeHealHandler(entry.crit, entry.tick))
        EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_COMBAT_EVENT,
            REGISTER_FILTER_COMBAT_RESULT, entry.result,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    end
end

-- Heals somebody else did to a party member. Only the sources that are people count: the player's own
-- pets and companions are neither the player's heals nor another healer's.
local INCOMING_SOURCES = {
    [COMBAT_UNIT_TYPE_GROUP] = true,
    [COMBAT_UNIT_TYPE_OTHER] = true,
}

local function OnIncomingHeal(_, _, isError, _, _, _, _, sourceType, targetName, _, hitValue, _, _, _, _, _, _, overflow)
    -- The player's own heals on party members arrive here too (the registration is filtered on the
    -- target alone), and are counted by their own handler.
    if isError or sourceType == COMBAT_UNIT_TYPE_PLAYER then
        return
    end
    counters.incoming = counters.incoming + 1
    if not sv.enabled or not zoneOk then
        return
    end
    if not INCOMING_SOURCES[sourceType] then
        counters.incomingSkipped = counters.incomingSkipped + 1
        return
    end
    local hit = records.ReadAmounts(hitValue, overflow)
    if records:RecordReceived(GetFrameTimeMilliseconds(), targetName, hit) then
        counters.incomingCounted = counters.incomingCounted + 1
    end
end

local incomingOn = false

-- Registered only while it is wanted: in a big fight these are the heals of every healer in the
-- party, and nobody should pay for them who does not want the number.
function ADDON.SetCountOthers(value)
    value = value and true or false
    sv.countOthers = value
    if value == incomingOn then
        return
    end
    incomingOn = value
    for _, entry in ipairs(HEAL_RESULTS) do
        local namespace = ADDON.name .. "In" .. entry.name
        if value then
            EVENT_MANAGER:RegisterForEvent(namespace, EVENT_COMBAT_EVENT, OnIncomingHeal)
            EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_COMBAT_EVENT,
                REGISTER_FILTER_COMBAT_RESULT, entry.result,
                REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP)
        else
            EVENT_MANAGER:UnregisterForEvent(namespace, EVENT_COMBAT_EVENT)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Switches
---------------------------------------------------------------------------------------------------

function ADDON.SetEnabled(value)
    sv.enabled = value and true or false
    if not sv.enabled then
        records:Flush(GetFrameTimeMilliseconds())
    end
    if ADDON.hud then
        ADDON.hud:Refresh()
    end
end

function ADDON.SetZones(mode)
    sv.zones = mode
    ADDON.RefreshZone()
end

---------------------------------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------------------------------

-- The summary and the two rankings, ten places each: the same lines the statistics window shows.
local function PrintScope(scope)
    Print(string.format(GetString(SI_PBSHPS_CMD_SCOPE_HEADING), records:ScopeText(scope)))
    for _, line in ipairs(records:SummaryLines(scope)) do
        Print("  " .. line)
    end
    Print(GetString(SI_PBSHPS_CMD_TOP_TARGETS))
    for _, line in ipairs(records:TopLines("targets", scope, ADDON.RANKING_ROWS)) do
        Print("  " .. line)
    end
    Print(GetString(SI_PBSHPS_CMD_TOP_SKILLS))
    for _, line in ipairs(records:TopLines("skills", scope, ADDON.RANKING_ROWS)) do
        Print("  " .. line)
    end
end

local function PrintStatus()
    local fight = records.fight
    Print(string.format("[HPS] %s %s  enabled=%s  zones=%s  zoneOk=%s",
        DISPLAY_NAME, ADDON.version, tostring(sv.enabled), sv.zones, tostring(zoneOk)))
    Print(string.format("[HPS] heal events %d  counted %d  outside zone %d  other target %d",
        counters.seen, counters.counted, counters.skippedZone, counters.skippedTarget))
    local parts = {}
    for targetType, count in pairs(counters.byType) do
        parts[#parts + 1] = string.format("%s=%d", TypeName(targetType), count)
    end
    table.sort(parts)
    Print("[HPS] target types: " .. (#parts > 0 and table.concat(parts, "  ") or "-"))
    if fight then
        Print(string.format("[HPS] fight: %s healed, %.1f s, %d people",
            records.Commas(fight.heal), fight.secs, fight.people))
    end
    Print(string.format("[HPS] others > party members (%s): arrived %d  counted %d  not a person %d",
        incomingOn and "on" or "off", counters.incoming, counters.incomingCounted, counters.incomingSkipped))
    Print(string.format("[HPS] PSN IDs known: %d  learned from the group %d, the reticle %d, the kill feed %d  (no name to learn: %d)",
        ADDON.psn:Count(), ADDON.psn.learned.group, ADDON.psn.learned.reticle, ADDON.psn.learned.killfeed, ADDON.psn.empty))
    local left = ADDON.probe:SecondsLeft(GetFrameTimeMilliseconds())
    if left then
        Print(string.format(GetString(SI_PBSHPS_PROBE_RUNNING), left))
    end
end

local SCOPE_WORDS = { today = "today", month = "thismonth", all = "all" }

local function OnSlashCommand(argument)
    local words = {}
    for word in zo_strlower(zo_strtrim(argument or "")):gmatch("%S+") do
        words[#words + 1] = word
    end
    local command = words[1]

    if command == "on" or command == "off" then
        ADDON.SetEnabled(command == "on")
        Print(GetString(command == "on" and SI_PBSHPS_CMD_ON or SI_PBSHPS_CMD_OFF))
    elseif command == "hud" then
        sv.hud = not sv.hud
        ADDON.hud:Refresh()
        Print(GetString(sv.hud and SI_PBSHPS_CMD_HUD_ON or SI_PBSHPS_CMD_HUD_OFF))
    elseif command == "stats" then
        local window = ADDON.window
        local scope = SCOPE_WORDS[words[2] or ""]
        if scope then
            window:SetScope(scope)
        end
        window:Toggle()
    elseif SCOPE_WORDS[command or ""] then
        PrintScope(SCOPE_WORDS[command])
    elseif command == "probe" then
        ADDON.probe:Toggle(GetFrameTimeMilliseconds())
    elseif command == "status" then
        PrintStatus()
    elseif command == "debug" then
        if debugLeft > 0 then
            debugLeft = 0
            Print(GetString(SI_PBSHPS_CMD_DEBUG_OFF))
        else
            debugLeft = DEBUG_LINES
            Print(string.format(GetString(SI_PBSHPS_CMD_DEBUG_ON), DEBUG_LINES))
        end
    else
        Print(GetString(SI_PBSHPS_HELP))
    end
end

---------------------------------------------------------------------------------------------------
-- Who may use it
--
-- Two PSN IDs only: PinkBanther and Yukiblack1123. The check reads the console ID of the logged-in
-- player (GetPlatformDisplayName, the PSN online ID on a PS5) at load. The @account name is
-- deliberately not consulted: the IDs were given as PSN IDs. Everyone else gets no events, no
-- saved variables, no panel and no window, and one line in chat after login. It is a soft gate (plain
-- Lua anyone can read), the same as PB's TargetPlayer and Compass use.
---------------------------------------------------------------------------------------------------

-- Compared the way player names are everywhere else: case, a leading @ and a gender suffix do not
-- matter.
local ALLOWED_USERS = {
    ["pinkbanther"] = true,
    ["yukiblack1123"] = true,
}

-- Shown in Japanese whatever the client language is, as in PB's other restricted add-ons.
local DENIED_MESSAGE = "あなたはこのアドオンを使用できません"

local FULLWIDTH_AT = "＠"

local function NameKey(raw)
    if type(raw) ~= "string" or raw == "" then
        return ""
    end
    local name = (raw:gsub("%^%a+$", "")):match("^%s*(.-)%s*$")
    if name:sub(1, #FULLWIDTH_AT) == FULLWIDTH_AT then
        name = name:sub(#FULLWIDTH_AT + 1)
    elseif name:sub(1, 1) == "@" then
        name = name:sub(2)
    end
    return (name:match("^%s*(.-)%s*$")):lower()
end
ADDON.NameKey = NameKey

-- The console ID of the logged-in player. An empty answer is "unknown", which is not on the list.
local function PlatformId()
    return GetPlatformDisplayName and GetPlatformDisplayName() or ""
end

function ADDON.IsAllowedUser()
    return ALLOWED_USERS[NameKey(PlatformId())] == true
end

-- Everyone else: the message once after login (chat is not up at load, so it waits for the first
-- activation) and again whenever the command is tried. The command also says which ID was read, so
-- the owner can tell a refused stranger from a mis-read ID.
function ADDON.RefuseToRun()
    ADDON.denied = true
    SLASH_COMMANDS["/hps"] = function()
        Print(DENIED_MESSAGE)
        Print("PSN ID: " .. tostring(PlatformId()))
    end
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "Denied", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(ADDON.name .. "Denied", EVENT_PLAYER_ACTIVATED)
        Print(DENIED_MESSAGE)
    end)
end

---------------------------------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------------------------------

-- The version is written only in the manifest's ## Title line; read it back from there.
local function ReadManifestVersion()
    local manager = GetAddOnManager()
    for index = 1, manager:GetNumAddOns() do
        local name, title = manager:GetAddOnInfo(index)
        if name == ADDON.name and title then
            local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
            return plain:match("([%d]+[%d%.]*)%s*$") or ""
        end
    end
    return ""
end

local function OnTick()
    local now = GetFrameTimeMilliseconds()
    records:Tick(now)
    ADDON.psn:Tick(now)
    ADDON.probe:Tick(now)
end

local function OnPlayerActivated()
    ADDON.RefreshZone()
    ADDON.psn:LearnGroup()
    if not ADDON.announced then
        ADDON.announced = true
        -- Chat is up by now; a line printed at EVENT_ADD_ON_LOADED is lost.
        Print(string.format(GetString(SI_PBSHPS_LOADED), ADDON.version))
    end
end

-- A loading screen (zone change, logout) ends the fight whether or not the gap has passed.
local function OnPlayerDeactivated()
    records:Flush(GetFrameTimeMilliseconds())
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED)

    ADDON.version = ReadManifestVersion()
    ADDON.title = ADDON.version ~= "" and (DISPLAY_NAME .. " " .. ADDON.version) or DISPLAY_NAME

    -- Nothing below this check runs for anyone who is not on the list: no saved variables, no
    -- events, no tick, no panel, no controls.
    if not ADDON.IsAllowedUser() then
        ADDON.RefuseToRun()
        return
    end

    sv = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, ADDON.defaults)
    ADDON.sv = sv
    records:Initialize(sv)
    ADDON.psn:Initialize(sv)

    ADDON.hud:Initialize()

    RegisterHealEvents()
    ADDON.SetCountOthers(sv.countOthers)
    -- The names the game shows for players: from the group, whoever the reticle is on, and the kill feed
    -- (a line carries the display name and the character name of the killer and of the victim).
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "Group", EVENT_GROUP_UPDATE, function() ADDON.psn:LearnGroup() end)
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "Joined", EVENT_GROUP_MEMBER_JOINED, function() ADDON.psn:LearnGroup() end)
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "Reticle", EVENT_RETICLE_TARGET_CHANGED, function() ADDON.psn:LearnReticle() end)
    EVENT_MANAGER:RegisterForEvent(ADDON.name .. "KillFeed", EVENT_PVP_KILL_FEED_DEATH,
        function(_, _, killerDisplayName, killerCharacterName, _, _, victimDisplayName, victimCharacterName)
            ADDON.psn:LearnKillFeed(killerDisplayName, killerCharacterName, victimDisplayName, victimCharacterName)
        end)
    EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)
    EVENT_MANAGER:RegisterForUpdate(ADDON.name .. "Tick", TICK_MS, OnTick)
    SLASH_COMMANDS["/hps"] = OnSlashCommand

    if ADDON.InitializeSettings then
        ADDON.InitializeSettings()
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
