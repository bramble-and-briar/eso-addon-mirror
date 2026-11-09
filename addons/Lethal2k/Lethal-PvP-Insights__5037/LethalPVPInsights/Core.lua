-- Lethal PVP Insights - core namespace, constants and helpers
PVPDataInsight = PVPDataInsight or {}
local PDI = PVPDataInsight

PDI.name        = "LethalPVPInsights"   -- the addon folder (PVPDataInsight before 1.9.59)
PDI.displayName = "Lethal PVP Insights"
PDI.version     = "1.9.74"

-- Retention
PDI.OPPONENT_RETENTION_DAYS = 7    -- combat/opponent data (feature 3)
PDI.DAILY_RETENTION_DAYS    = 70   -- daily kill buckets (enough for "last month")
PDI.NAMEMAP_RETENTION_DAYS  = 30   -- character -> @account mapping cache
PDI.MAX_PLAUSIBLE_HP        = 80000 -- reticle health readings above this are ignored as glitches
PDI.GROUP_HISTORY_MAX       = 200  -- grouped-with accounts kept (saved builds are not counted)
PDI.GROUP_NEW_SESSION_SEC   = 3600 -- (kept for reference; builds are split by day, see BUILD_SPLIT_SEC)
-- A player's build data (skills, buffs) is combined per character and game day. Set a number of
-- seconds here to also start fresh after that long without seeing them (e.g. 3600 once there are
-- enough uploaders to fill the gaps); nil = whole day.
PDI.BUILD_SPLIT_SEC         = nil

-- Timing windows (ms, game time)
PDI.ASSIST_WINDOW_MS   = 15000  -- you damaged them within this window before they died = assist
PDI.DEDUPE_WINDOW_MS   = 25000  -- same victim reported again within this window = the same death
PDI.FALLBACK_DELAY_MS  = 3000   -- wait for the kill feed before using combat-event fallback

PDI.PERIODS = {
    { key = "session",   label = "Session",    short = "Session" },
    { key = "today",     label = "Today",      short = "Today" },
    { key = "yesterday", label = "Yesterday",  short = "Yest." },
    { key = "week",      label = "7 Days",     short = "7 Days" },
    { key = "mtd",       label = "This Month", short = "Month" },
    { key = "lastmonth", label = "Last Month", short = "Last Mo." },
    { key = "lifetime",  label = "Lifetime",   short = "Lifetime" },
}

-- 0 = all factions
PDI.FACTIONS = { 0, 1, 2, 3 }  -- ALLIANCE_ALDMERI_DOMINION=1, EBONHEART_PACT=2, DAGGERFALL_COVENANT=3
PDI.FACTION_SHORT = { [0] = "All", [1] = "AD", [2] = "EP", [3] = "DC" }

-- Mundus stone "Boon" buff ability IDs
PDI.MUNDUS_IDS = {
    [13940] = "The Warrior",  [13943] = "The Mage",     [13974] = "The Serpent",
    [13975] = "The Thief",    [13976] = "The Lady",     [13977] = "The Steed",
    [13978] = "The Lord",     [13979] = "The Apprentice", [13980] = "The Ritual",
    [13981] = "The Lover",    [13982] = "The Atronach", [13984] = "The Shadow",
    [13985] = "The Tower",
}

PDI.defaults = {
    my        = {},  -- [dateKey] = { [who] = { k=, a=, al=, c= } }
    feed      = {},  -- [dateKey] = { [who] = { k=, al= } }
    lifetime  = { my = {}, feed = {} },
    opponents = {},  -- [dateKey] = { [who] = record }
    saved     = {},  -- [id] = { who=, date=, savedAt=, rec= }
    names     = {},  -- [charName] = { acct=, al=, t= }
    group     = {},  -- [@account] = build entry (last 200 grouped-with accounts)
    savedBuilds = {},-- [id] = { who=, savedAt=, rec= }
    follows = {},    -- [@account] = time you followed them (daily snapshots are added while you follow them)
    logCoverage = {},
    importedBuilds = {}, -- [@account] = { build=, storedAt= } copy of imported gear/bars, kept 7 days
    killEvents = {},
    captureStarts = {},  -- times the addon switched the encounter log on (the Companion only deletes logs it made)     -- [dateKey] = { event, ... } every kill feed message, one record each (see Data:AddKillEvent)
    profiles  = {},  -- [@account] = class/race/faction/health/mundus/buffs of any player you targeted-- [@account] = time their gear was captured in the log (until imported)
    settings  = {
        chatNotify = true,
        onlyPvP    = true,
        deathRecap = false,   -- Real Death Recap (off by default)
        updateNotice = true,  -- tell me when a new addon version is available
        autoLog    = "auto",  -- auto | ask | never  (encounter log while grouped)
        importPopup = true,   -- show the import window after a captured fight
        buffWindowHours = 36,
        groupScope = "pvp",
        killEventDays = 7,    -- kill feed event log retention (days)   -- group history: "pvp" | "pve" | "both" -- buffs of a targeted player build up for this long, then start from scratch
        window     = {},
    },
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
function PDI.Now() return GetTimeStamp() end

-- The game day runs from 03:00 UTC to 03:00 UTC the next day (the daily reset), the same for
-- every player whatever their time zone. Returns YYYYMMDD of that game day.
PDI.DAY_START_UTC_SEC = 3 * 3600
local function civilFromDays(z)   -- days since 1970-01-01 -> y, m, d (proleptic Gregorian)
    z = z + 719468
    local era = math.floor(z / 146097)
    local doe = z - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local mp = math.floor((5 * doy + 2) / 153)
    local d = doy - math.floor((153 * mp + 2) / 5) + 1
    local m = mp < 10 and mp + 3 or mp - 9
    if m <= 2 then y = y + 1 end
    return y, m, d
end
function PDI.DateKey(ts)
    ts = ts or GetTimeStamp()
    local y, m, d = civilFromDays(math.floor((ts - PDI.DAY_START_UTC_SEC) / 86400))
    return y * 10000 + m * 100 + d
end

function PDI.FormatDate(dateKey)
    if not dateKey then return "" end
    local y = math.floor(dateKey / 10000)
    local m = math.floor(dateKey / 100) % 100
    local d = dateKey % 100
    return string.format("%04d-%02d-%02d", y, m, d)
end

function PDI.FormatTime(ts)
    if not ts then return "" end
    return os.date("%Y-%m-%d %H:%M", ts)
end

-- Strip gender/grammar suffixes ("Name^Mx" -> "Name")
function PDI.CleanName(raw)
    if not raw or raw == "" then return nil end
    local n = zo_strformat("<<1>>", raw)
    if n == "" then return nil end
    return n
end

-- Player characters carry "^Mx"/"^Fx" suffixes in combat events; NPCs usually do not.
function PDI.LooksLikePlayerRaw(raw)
    return raw ~= nil and raw:find("%^[MmFf]x") ~= nil
end

function PDI.NormalizeAccount(acct)
    if not acct or acct == "" then return nil end
    if acct:sub(1, 1) ~= "@" then acct = "@" .. acct end
    return acct
end

function PDI.InPvPArea()
    if IsPlayerInAvAWorld and IsPlayerInAvAWorld() then return true end
    if IsActiveWorldBattleground and IsActiveWorldBattleground() then return true end
    return false
end

-- Where enemy players may be recorded as Opponents: PvP areas, or against your duel partner.
-- Returns "pvp" | "duel" (+ partner character name) | nil. Independent of the pvp-only setting.
function PDI.OpponentContext()
    if PDI.InPvPArea() then return "pvp" end
    if GetDuelInfo and DUEL_STATE_DUELING then
        local state, partnerChar = GetDuelInfo()
        if state == DUEL_STATE_DUELING then return "duel", PDI.CleanName(partnerChar) end
    end
    return nil
end

-- Group history / builds / encounter-log capture: "pvp" (Cyrodiil, IC, Battlegrounds), "pve" (everywhere
-- else) or "both"
function PDI.ShouldTrackGroup()
    if not PDI.sv then return false end
    local scope = PDI.sv.settings.groupScope or "pvp"
    if scope == "both" then return true end
    if scope == "pve" then return not PDI.InPvPArea() end
    return PDI.InPvPArea()
end

function PDI.ShouldTrack()
    if not PDI.sv then return false end
    if PDI.sv.settings.onlyPvP then return PDI.InPvPArea() end
    return true
end

function PDI.FactionText(al, short)
    if not al or al == 0 then return short and "-" or "Unknown" end
    local text = short and PDI.FACTION_SHORT[al] or zo_strformat(SI_ALLIANCE_NAME, GetAllianceName(al))
    local color = GetAllianceColor and GetAllianceColor(al)
    if color and color.Colorize then return color:Colorize(text) end
    return text
end

function PDI.ClassText(classId)
    if not classId or classId == 0 then return "-" end
    local n = GetClassName(GENDER_MALE, classId)
    if not n or n == "" then return "-" end
    return zo_strformat("<<1>>", n)
end

function PDI.RoleText(role)
    if role == LFG_ROLE_TANK then return "Tank" end
    if role == LFG_ROLE_HEAL then return "Healer" end
    if role == LFG_ROLE_DPS then return "DPS" end
    return "-"
end

function PDI.Num(n)
    if not n then return "0" end
    if ZO_CommaDelimitNumber then return ZO_CommaDelimitNumber(n) end
    return tostring(n)
end

function PDI.Msg(text)
    local line = "|c66CCFF[LPI]|r " .. text
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(line)
    else
        d(line)
    end
end
