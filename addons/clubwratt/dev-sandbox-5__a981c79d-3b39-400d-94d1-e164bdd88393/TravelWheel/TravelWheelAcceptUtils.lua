-- TravelWheelAcceptUtils.lua: Pure decisions about accepting a queue that is
-- ready: which kind of queue it is, and how long to wait before accepting.

local TravelWheelAcceptUtils = {}

-- A rule is the seconds to wait after the queue is ready before accepting it.
TravelWheelAcceptUtils.RULE_OFF = -1
TravelWheelAcceptUtils.RULE_AT_ONCE = 0
-- Longer than any prompt lasts, so it always runs into the margin below.
TravelWheelAcceptUtils.RULE_LAST_MOMENT = 9999

-- Seconds left on the prompt when a last-moment accept is sent: room for the
-- request to reach the server before the prompt expires.
TravelWheelAcceptUtils.MARGIN_SECONDS = 3

---The rules a player can pick, in the order shown.
---@return table[] items { name, data = rule }
function TravelWheelAcceptUtils.RuleItems()
    return {
        { name = "Off", data = TravelWheelAcceptUtils.RULE_OFF },
        { name = "At once", data = TravelWheelAcceptUtils.RULE_AT_ONCE },
        { name = "After 5 seconds", data = 5 },
        { name = "After 10 seconds", data = 10 },
        { name = "After 20 seconds", data = 20 },
        { name = "After 30 seconds", data = 30 },
        { name = "At the last moment", data = TravelWheelAcceptUtils.RULE_LAST_MOMENT },
    }
end

---Which accept rule a finder ready check falls under. Only battlegrounds and
---the dungeon finder are accepted; every other activity is left to the player.
---@param activityType integer LFGActivity
---@return TravelWheelQueueKind|nil
function TravelWheelAcceptUtils.ActivityKind(activityType)
    if activityType == LFG_ACTIVITY_BATTLE_GROUND_CHAMPION
        or activityType == LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION
        or activityType == LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL then
        return "battleground"
    end
    if activityType == LFG_ACTIVITY_DUNGEON or activityType == LFG_ACTIVITY_MASTER_DUNGEON then
        return "dungeon"
    end
    return nil
end

---How long to wait before accepting, or nil to leave the prompt alone. A wait
---never runs past the prompt: it stops MARGIN_SECONDS before the prompt expires.
---@param rule integer
---@param remainingSeconds integer Seconds the prompt still lasts
---@return integer|nil waitSeconds
function TravelWheelAcceptUtils.WaitSeconds(rule, remainingSeconds)
    if not rule or rule < 0 then
        return nil
    end
    local latest = (remainingSeconds or 0) - TravelWheelAcceptUtils.MARGIN_SECONDS
    if latest < 0 then
        latest = 0
    end
    if rule < latest then
        return rule
    end
    return latest
end

TravelWheel.AcceptUtils = TravelWheelAcceptUtils
