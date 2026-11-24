-- Alerts while you play: a chat line when research or a riding lesson becomes ready on any
-- character (any account or megaserver saved on this PC). Checked once a minute. Settings page, or /fct alerts on|off
local CT = FurysCharacterTracker
local U = CT.Util
local Alerts = {}
CT.Alerts = Alerts

local CHECK_MS = 60000

-- Everything that became ready after `since` and by `now`, oldest first.
local function Due(since, now)
    local due = {}
    for _, account in ipairs(CT.Accounts()) do
        local previous = CT.view
        CT.view = account
        local data = CT.Data()
        CT.view = previous
        local suffix = account == CT.home and "" or string.format(" (%s)", CT.ViewLabel(account))
        for _, entry in ipairs(CT.Roster:List(nil, nil, data)) do
            local c = data.characters[entry.name]
            for _, craft in ipairs(CT.sv.alertResearch ~= false and c.researchCrafts or {}) do
                for _, timer in ipairs(craft.timers or {}) do
                    if timer.endsAt > since and timer.endsAt <= now then
                        due[#due + 1] = { at = timer.endsAt, text = string.format("Research done: %s%s, %s %s (%s)", entry.name, suffix,
                                          timer.item, timer.trait, CT.Research.CraftName(craft.craft)) }
                    end
                end
            end
            if CT.sv.alertRiding ~= false and c.ridingReadyAt and c.ridingReadyAt > since and c.ridingReadyAt <= now then
                due[#due + 1] = { at = c.ridingReadyAt, text = string.format("Riding lesson ready: %s%s", entry.name, suffix) }
            end
        end
    end
    table.sort(due, function(a, b) return a.at < b.at end)
    return due
end

function Alerts:Check()
    local now = GetTimeStamp()
    for _, item in ipairs(Due(self.since or now, now)) do U.Print(item.text) end
    self.since = now
    CT.Timers:RefreshIfShown()
end

function Alerts:Start()
    -- Anything that finished before this login is covered by the login line, so start from now.
    self.since = GetTimeStamp()
    if CT.sv.alertsOff then   -- 1.2.0 test builds: one switch for both
        CT.sv.alertResearch, CT.sv.alertRiding, CT.sv.alertsOff = false, false, nil
    end
    if CT.sv.alertResearch == false and CT.sv.alertRiding == false then return end
    EVENT_MANAGER:RegisterForUpdate(CT.name .. "Alerts", CHECK_MS, function() self:Check() end)
end

function Alerts:Restart()
    EVENT_MANAGER:UnregisterForUpdate(CT.name .. "Alerts")
    self:Start()
end

function Alerts:Set(on)
    CT.sv.alertResearch, CT.sv.alertRiding = on, on
    self:Restart()
    U.Print("Alerts %s: a chat line when research or a riding lesson is ready on any character.", on and "on" or "off")
end
