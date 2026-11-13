-- "/tradeqr trader": queues one record per guild with the trader (kiosk NPC) hired for the current week,
-- so the phone app can save the weekly guild trader. Guild metadata is loaded with the guild roster,
-- the official guild home screen reads it with the same call and no server request.
local TraderReporter = ZO_InitializingObject:Subclass()

local WEEK_SECONDS = 7 * 24 * 60 * 60
-- Values below this are durations, not Unix timestamps (defensive: the API names them timestamps).
local MIN_ABSOLUTE_TIMESTAMP_S = 1000000000

function TraderReporter:Initialize(saleQueue)
    self.saleQueue = saleQueue
end

-- Returns the number of queued records; prints one chat line per guild without a trader.
function TraderReporter:QueueCurrentTraders()
    local nowS = GetTimeStamp()
    local weekStartS, weekEndS = self:GetCurrentWeek(nowS)
    local queuedCount = 0
    for guildIndex = 1, GetNumGuilds() do
        local guildId = GetGuildId(guildIndex)
        local traderName = GetGuildOwnedKioskInfo(guildId)
        if traderName and traderName ~= "" then
            self.saleQueue:AddUnlessPending(self:BuildRecord(guildId, traderName, weekStartS, weekEndS, nowS))
            queuedCount = queuedCount + 1
        else
            d(zo_strformat(GetString(TRADEQR_CHAT_NO_TRADER), GetGuildName(guildId)))
        end
    end
    return queuedCount
end

-- The trader week ends when the kiosks despawn. Between despawn and respawn (a few minutes) the new week
-- starts at the respawn time.
function TraderReporter:GetCurrentWeek(nowS)
    local despawnS, _, respawnS = GetGuildKioskCycleTimes()
    despawnS = self:ToAbsoluteTimestamp(despawnS, nowS)
    respawnS = self:ToAbsoluteTimestamp(respawnS, nowS)
    if despawnS > nowS then
        return despawnS - WEEK_SECONDS, despawnS
    end
    return respawnS, respawnS + WEEK_SECONDS
end

function TraderReporter:ToAbsoluteTimestamp(valueS, nowS)
    if valueS < MIN_ABSOLUTE_TIMESTAMP_S then
        return nowS + valueS
    end
    return valueS
end

function TraderReporter:BuildRecord(guildId, traderName, weekStartS, weekEndS, nowS)
    return {
        kind = TradeQR.RECORD_KIND_TRADER,
        -- Queue key: one record per guild and week.
        eventId = string.format("trader-%d-%.0f", guildId, weekEndS),
        timestamp = nowS,
        guildId = guildId,
        guildName = GetGuildName(guildId),
        traderName = zo_strformat(SI_UNIT_NAME, traderName),
        weekStartS = weekStartS,
        weekEndS = weekEndS,
    }
end

TradeQR.TraderReporter = TraderReporter
