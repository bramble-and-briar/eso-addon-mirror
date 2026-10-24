-- The boss timers: one per defeated boss, or per group of bosses that died together. They are saved account-wide
-- (in SlayansBossTimerSavedVars, under "timers") with the real time from GetTimeStamp, so every character shares them
-- and they keep running through /reloadui, logging out and switching characters, as the bosses do. A timer ends when
-- its boss respawns: it leaves the list, with a chat message and an alert if they are switched on. Timers that ran out
-- while the player was away are removed quietly when the add-on loads.

local addon = SlayansBossTimer
local Settings = addon.Settings

local Timers = {}
addon.Timers = Timers

local UPDATE_NAME = "SlayansBossTimerUpdate"
local UPDATE_INTERVAL_MS = 1000 -- One update a second is enough for a countdown.

-- Most world, delve and public dungeon bosses respawn about 5:06 after they die. The respawn times here were measured
-- in game by Kyzderp for the SpawnTimer module of Kyzderp's Derps (github.com/Kyzderp/KyzderpsDerps).
Timers.DEFAULT_RESPAWN_SECONDS = 306

-- Bosses that take noticeably longer, by their English name, so these match only in the English game; elsewhere they
-- get the default.
Timers.RESPAWN_SECONDS_BY_NAME = {
    ["Troll Colossus"] = 600, -- Craglorn's Nirncrux mines.
    ["Ri'Atahrashi"] = 600, -- Southern Elsweyr.
    ["Iratan the Lightbringer"] = 600, -- Southern Elsweyr.
    ["Shademother"] = 606, -- Western Skyrim.
    ["Dwarven Dynastor Supreme"] = 335, -- The Reach, Arkthzand Cavern.
    ["Bhrum"] = 331, -- Blackwood.
    ["Koska"] = 331, -- Blackwood.
    ["Old Deathwart"] = 330, -- Blackwood.
    ["Order Champion"] = 330, -- Gold Coast, Kvatch Arena.
    ["Knight Commander Panthius"] = 330, -- Gold Coast, Kvatch Arena.
}

-- Places where every boss takes longer, by zone ID, which is the same in every language.
Timers.RESPAWN_SECONDS_BY_ZONE = {
    [584] = 900, -- Imperial City: the district bosses.
    [643] = 600, -- Imperial Sewers.
}

-- Returns how long the bosses with these names take to respawn in this zone: the longest that applies.
function Timers.GetRespawnSeconds(names, zoneId)
    local seconds = Timers.RESPAWN_SECONDS_BY_ZONE[zoneId] or Timers.DEFAULT_RESPAWN_SECONDS
    for _, name in ipairs(names) do
        seconds = zo_max(seconds, Timers.RESPAWN_SECONDS_BY_NAME[name] or 0)
    end
    return seconds
end

-- Returns minutes and seconds, such as "5:06", for the countdown.
function Timers.FormatTime(seconds)
    seconds = zo_max(0, zo_floor(seconds))
    return string.format("%d:%02d", zo_floor(seconds / 60), seconds % 60)
end

-- Returns a length of time for chat, such as "5m 6s", "10m" or "45s". In a sentence "5:06" reads like a time of day.
function Timers.FormatDuration(seconds)
    seconds = zo_max(0, zo_floor(seconds))
    local minutes, rest = zo_floor(seconds / 60), seconds % 60
    if minutes == 0 then
        return zo_strformat(SI_SBT_DURATION_SECONDS, rest)
    elseif rest == 0 then
        return zo_strformat(SI_SBT_DURATION_MINUTES, minutes)
    end
    return zo_strformat(SI_SBT_DURATION_MINUTES_SECONDS, minutes, rest)
end

---------------------------------------------------------------------------------------------------
-- The saved list
---------------------------------------------------------------------------------------------------

-- Each timer: { name = the boss names as shown, zoneId, kind = the kind of place (see Detector.GetPlaceKind; missing
-- in timers saved before there were kinds), diedAt and respawnAt (GetTimeStamp seconds) }.
local function GetList()
    local list = Settings.Get("timers")
    if type(list) ~= "table" then
        list = {}
        Settings.Set("timers", list)
    end
    return list
end

-- Returns the timers, soonest respawn first.
function Timers.GetAll()
    local timers = {}
    for _, timer in ipairs(GetList()) do
        table.insert(timers, timer)
    end
    table.sort(timers, function(a, b)
        return a.respawnAt < b.respawnAt
    end)
    return timers
end

function Timers.Count()
    return #GetList()
end

-- Removes the timers whose boss has respawned by now and returns them.
function Timers.RemoveExpired(now)
    local list = GetList()
    local expired = {}
    for index = #list, 1, -1 do
        if list[index].respawnAt <= now then
            table.insert(expired, 1, table.remove(list, index))
        end
    end
    return expired
end

---------------------------------------------------------------------------------------------------
-- Notifications: chat messages and the alert in the middle of the screen
---------------------------------------------------------------------------------------------------

-- LibChatMessage is optional: players who have it get its tag before the timer's messages ("[Slayan's Boss Timer]",
-- in harvest gold) and their own time and tag choices; everyone else gets a plain system message.
local CHAT_TAG_COLOR = "FFD54F"
local chatProxy

local function Print(text)
    if LibChatMessage and LibChatMessage.Create then
        chatProxy = chatProxy or LibChatMessage.Create(GetString(SI_SBT_MENU_NAME), GetString(SI_SBT_CHAT_TAG_SHORT))
        chatProxy:SetTagColor(CHAT_TAG_COLOR):Print(text)
    else
        CHAT_ROUTER:AddSystemMessage(text)
    end
end

-- The boss's name in large text with "Has Respawned" under it, shown the way the game's own centre-screen
-- announcements are (ingame/centerscreenannounce), with the respawn sound if it's on.
local function ShowAlert(timer, sound)
    if not CENTER_SCREEN_ANNOUNCE then
        return
    end
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, sound)
    params:SetText(timer.name, GetString(SI_SBT_ALERT_RESPAWNED))
    params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT)
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
end

local RESPAWN_SOUND = SOUNDS.BATTLEGROUND_NEARING_VICTORY

local function OnTimerStarted(timer)
    if Settings.Get("showChat") then
        Print(zo_strformat(SI_SBT_CHAT_TIMER_STARTED, timer.name,
            Timers.FormatDuration(timer.respawnAt - timer.diedAt)))
    end
end

local function OnBossRespawned(timer)
    if Settings.Get("showChat") then
        Print(zo_strformat(SI_SBT_CHAT_BOSS_RESPAWNED, timer.name))
    end
    -- The sound comes with the alert, or plays on its own when the alert is off.
    local sound = Settings.Get("playSound") and RESPAWN_SOUND or nil
    if Settings.Get("showAlert") then
        ShowAlert(timer, sound)
    elseif sound then
        PlaySound(sound)
    end
end

---------------------------------------------------------------------------------------------------
-- Running the timers
---------------------------------------------------------------------------------------------------

local updating = false

local function StopUpdates()
    if updating then
        updating = false
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    end
end

-- Once a second while there are timers: bosses that are back leave the list, and the countdown shows the rest.
function Timers.Update()
    for _, timer in ipairs(Timers.RemoveExpired(GetTimeStamp())) do
        OnBossRespawned(timer)
    end
    addon.Countdown.Refresh()
    if Timers.Count() == 0 then
        StopUpdates()
    end
end

local function StartUpdates()
    if not updating then
        updating = true
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, UPDATE_INTERVAL_MS, Timers.Update)
    end
end

-- Starts a timer for bosses that just died in a zone, in a kind of place. Bosses already on the list there start
-- again.
function Timers.Start(names, label, zoneId, kind)
    local now = GetTimeStamp()
    local list = GetList()
    for index = #list, 1, -1 do
        if list[index].name == label and list[index].zoneId == zoneId then
            table.remove(list, index)
        end
    end
    local respawnAt = now + Timers.GetRespawnSeconds(names, zoneId)
    local timer = { name = label, zoneId = zoneId, kind = kind, diedAt = now, respawnAt = respawnAt }
    table.insert(list, timer)
    OnTimerStarted(timer)
    StartUpdates()
    addon.Countdown.Refresh()
    return timer
end

-- Clears every timer (/sbtreset and Reset Boss Timers in the settings), and says so in chat whatever the chat setting,
-- since the player asked for it.
function Timers.Reset()
    ZO_ClearTable(GetList())
    StopUpdates()
    addon.Countdown.Refresh()
    Print(GetString(SI_SBT_CHAT_TIMERS_CLEARED))
end

-- When the add-on loads (logging in, /reloadui): timers whose boss respawned meanwhile go quietly, and the rest run on.
function Timers.Initialize()
    Timers.RemoveExpired(GetTimeStamp())
    if Timers.Count() > 0 then
        StartUpdates()
    end
end
