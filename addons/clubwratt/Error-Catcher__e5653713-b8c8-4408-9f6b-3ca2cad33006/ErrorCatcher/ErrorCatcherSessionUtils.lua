-- ErrorCatcherSessionUtils.lua: how the UI load before this one ended, read off the record it saved (pure)
--
-- Saved variables are written at a loading screen, a logout and a UI reload; a crash writes nothing. So the
-- record a UI load finds is the state at the last save before it, and the two clocks say what came between:
-- the wall clock runs on always, the game's clock restarts with the game.
local SessionUtils = {}

-- The two clocks may drift this far apart between two UI loads of one run of the game.
SessionUtils.CLOCK_SLACK_SECONDS = 30

local SAVE_LOAD_ERRORS = {
    "SLD_ERROR_ALLOW_OVERWRITE",
    "SLD_ERROR_FAILED_LOAD",
    "SLD_ERROR_FAILED_SAVE",
    "SLD_ERROR_FILE_CORRUPT",
    "SLD_ERROR_NO_SAVE_CREATED",
    "SLD_ERROR_NO_SAVE_DEVICE_SELECTED",
    "SLD_ERROR_OUT_OF_SPACE",
    "SLD_ERROR_SAVE_DEST_REMOVED",
}

---The name of a save/load error code, as the game's constants have it.
---@param code any
---@param globals table
---@return string
function SessionUtils.SaveLoadErrorName(code, globals)
    for _, name in ipairs(SAVE_LOAD_ERRORS) do
        if code ~= nil and globals[name] == code then
            return name
        end
    end
    return "error " .. tostring(code)
end

---Whether a saved record can be read.
---@param record any
---@return boolean
function SessionUtils.IsRecord(record)
    return type(record) == "table" and type(record.wall) == "number" and type(record.gameClock) == "number"
end

---Whether the game itself was started again between the record's last save and now.
---@param record ErrorCatcherSessionRecord
---@param now ErrorCatcherMoment
---@return boolean
function SessionUtils.Restarted(record, now)
    if now.gameClock < record.gameClock then
        return true
    end
    local wallGap = now.wall - record.wall
    local clockGap = now.gameClock - record.gameClock
    return math.abs(wallGap - clockGap) > SessionUtils.CLOCK_SLACK_SECONDS
end

---How the UI load that left the record ended.
---@param record ErrorCatcherSessionRecord
---@param now ErrorCatcherMoment
---@return string verdict, boolean crashed No logout came before the game was started again
function SessionUtils.Ended(record, now)
    local restarted = SessionUtils.Restarted(record, now)
    if record.logoutWall then
        local how = record.logoutQuit and "a quit" or "a logout"
        if restarted then
            return how .. ", and the game was started again since", false
        end
        return how .. " (character select or another character), the game kept running", false
    end
    if not restarted then
        if record.reloadWall then
            return "a UI reload asked from Lua (/reloadui, the add-on manager or an add-on), the game kept running", false
        end
        return "a UI reload with no logout and no reload call seen: one the game forced, or one made where this add-on cannot see", false
    end
    if record.reloadWall then
        return "THE GAME WAS STARTED AGAIN WITH NO LOGOUT ON RECORD. The last save was a UI reload; the UI load after it "
            .. "left no record, so it ended before its first save: a crash, or the game closed from the dashboard", true
    end
    local restart = "THE GAME WAS STARTED AGAIN WITH NO LOGOUT ON RECORD: a crash, or the game closed from the dashboard. "
    local zone = record.zone or "?"
    -- A record saved between leaving a zone and arriving in the next was saved by that loading screen.
    local left, arrived = record.deactivatedWall, record.activatedWall
    if left and (not arrived or left >= arrived) then
        return string.format("%sThe last save was the loading screen leaving %s, so it ended in that loading screen or in the zone after it",
            restart, zone), true
    end
    if not arrived then
        return restart .. "The last save came before the world was entered; what followed it is lost", true
    end
    return string.format("%sThe last save came %d s into %s, outside a loading screen (the game saved in the middle of the zone); what followed it is lost",
        restart, math.max(0, record.wall - arrived), zone), true
end

---@param seconds number
---@return string
local function Span(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    if seconds < 120 then
        return string.format("%d s", seconds)
    end
    if seconds < 7200 then
        return string.format("%d min", math.floor(seconds / 60 + 0.5))
    end
    return string.format("%.1f h", seconds / 3600)
end
SessionUtils.Span = Span

---The record of the UI load before this one, as lines.
---@param record any What the saved variables held; anything but a record reads as none
---@param now ErrorCatcherMoment
---@param wallClock fun(stamp: number): string
---@return string[] lines
function SessionUtils.Previous(record, now, wallClock)
    if not SessionUtils.IsRecord(record) then
        return { "UI load before this one: no record (the first run of this version, or the saved variables were lost)" }
    end
    local figures = {}
    if type(record.used) == "number" then
        local pool = string.format("add-on pool %.1f/%s MB", record.used,
            type(record.capacity) == "number" and string.format("%d", record.capacity) or "?")
        if type(record.high) == "number" and record.high > record.used + 0.05 then
            pool = pool .. string.format(" (highest %.1f)", record.high)
        end
        figures[#figures + 1] = pool
    end
    if type(record.heap) == "number" then
        figures[#figures + 1] = string.format("Lua heap %.1f MB", record.heap)
    end
    if type(record.pinsBuilt) == "number" then
        figures[#figures + 1] = string.format("map pins %d in use / %d built", record.pinsActive or 0, record.pinsBuilt)
    end
    figures[#figures + 1] = string.format("save data writes %d started / %d completed", record.savesStarted or 0, record.savesCompleted or 0)

    local verdict = SessionUtils.Ended(record, now)
    return {
        string.format("UI load before this one (#%s, v%s): %s in %s, last saved %s, %s before this load and %s after its own start: %s",
            tostring(record.loadNumber or "?"), tostring(record.version or "?"), tostring(record.character or "?"),
            tostring(record.zone or "?"), wallClock(record.wall), Span(now.wall - record.wall),
            Span(record.age or 0), table.concat(figures, ", ")),
        "it ended by " .. verdict,
    }
end

---Which add-ons are enabled now and were not on the UI load before, and the other way round.
---@param previous string[]|nil
---@param current string[]
---@return string[] added, string[] removed Sorted
function SessionUtils.EnabledDiff(previous, current)
    local was, is = {}, {}
    for _, name in ipairs(previous or {}) do was[name] = true end
    for _, name in ipairs(current) do is[name] = true end
    local added, removed = {}, {}
    for name in pairs(is) do
        if not was[name] then added[#added + 1] = name end
    end
    for name in pairs(was) do
        if not is[name] then removed[#removed + 1] = name end
    end
    table.sort(added)
    table.sort(removed)
    return added, removed
end

---The heading of the enabled add-ons, against the UI load before.
---@param count number
---@param character string
---@param before ErrorCatcherEnabledRecord|nil
---@param changed boolean
---@return string
function SessionUtils.EnabledHeading(count, character, before, changed)
    if not before or type(before.names) ~= "table" then
        return string.format("add-ons enabled: %d on %s", count, character)
    end
    local beforeCharacter = tostring(before.character or "?")
    if not changed then
        return string.format("add-ons enabled: %d on %s, the same set as the UI load before (on %s)", count, character, beforeCharacter)
    end
    return string.format("add-ons enabled: %d on %s; the UI load before (on %s) had %d", count, character, beforeCharacter, #before.names)
end

ErrorCatcher.SessionUtils = SessionUtils
