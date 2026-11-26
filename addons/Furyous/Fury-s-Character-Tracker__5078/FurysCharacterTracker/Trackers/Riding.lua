-- shared
-- Riding: speed + stamina + carry capacity, and when the next lesson can be bought.
--   c.riding, c.ridingMax    the three skills added up, and their top (180)
--   c.ridingReadyAt          the moment the next lesson can be taken (0 = now); nil once riding is maxed
local CT = FurysCharacterTracker
local U = CT.Util

CT.Track({
    id = "riding",
    read = function(c)
        local carry, carryMax, stamina, staminaMax, speed, speedMax = GetRidingStats()
        c.riding, c.ridingMax = carry + stamina + speed, carryMax + staminaMax + speedMax
        if c.riding >= c.ridingMax then
            c.ridingReadyAt = nil
        else
            local ms = GetTimeUntilCanBeTrained() or 0
            c.ridingReadyAt = ms > 0 and (GetTimeStamp() + math.ceil(ms / 1000)) or 0
        end
    end,
    events = { EVENT_RIDING_SKILL_IMPROVEMENT },
    columns = {
        { key = "riding", title = "Riding", width = 72, max = function(e) return e.c.ridingMax or CT.RIDING_MAX end,
          value = function(e) return e.c.riding or 0 end, tip = "Speed + stamina + carry capacity",
          head = "Riding: speed + stamina + carry capacity, out of " .. CT.RIDING_MAX .. " (60 each)." },
        { key = "ridingLesson", title = "Riding lesson", width = 110,
          head = "Riding lesson: time until this character can buy its next lesson at a stable.\nReady = it can buy one now. Maxed = nothing left to learn.",
          value = function(e)
              if not e.c.ridingReadyAt then return -1 end
              return math.max(0, e.c.ridingReadyAt - GetTimeStamp())
          end,
          display = function(v) return v < 0 and "Maxed" or (v == 0 and "Ready" or U.Duration(v)) end,
          gold = function(v) return v < 0 end,
          tip = function(e)
              local c = e.c
              if not c.ridingReadyAt then return "Riding maxed (" .. (c.riding or 0) .. " / " .. (c.ridingMax or CT.RIDING_MAX) .. ")" end
              if c.ridingReadyAt <= GetTimeStamp() then return "A riding lesson is ready: visit a stablemaster." end
              return "Next riding lesson at " .. U.DayTime(c.ridingReadyAt)
          end },
    },
    summary = function(e) return { CT.Trackers.Progress("Riding", e.c.riding, e.c.ridingMax or CT.RIDING_MAX) } end,
    sections = function(e)
        local readyAt = e.c.ridingReadyAt
        if not readyAt then return {} end
        local ready = readyAt <= GetTimeStamp()
        return { { title = "Daily", id = "daily", items = { { "Riding lesson", ready and "Ready" or "at " .. U.DayTime(readyAt), done = not ready } } } }
    end,
    export = { { "Riding", function(e) return e.c.riding end } },
})
