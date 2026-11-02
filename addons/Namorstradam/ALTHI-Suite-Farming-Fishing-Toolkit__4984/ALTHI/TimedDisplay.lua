-- A one-second clock tick is not a request to rebuild every window and filter.
-- Full Refresh remains the event-driven path for data, settings and layout changes.
local A=ALTHarvestItems
local function text(control,value)
    if control and control:GetText()~=value then control:SetText(value) end
end
function A:SessionClockText()
    local running=self:IsSessionRunning()
    return string.format(self:T('SESSION_TWO_CLOCKS'),self.Time(self:SessionTotalSeconds()),self.Time(self.db.session.elapsed))
        ..' · '..(running and '|c44CC66' or '|cDD5555')..self:T(running and 'HARVESTING' or 'PAUSE')..'|r'
end
function A:RefreshTimedDisplay()
    if not self.window or self.window:IsHidden() then return end
    local activity=self.db.ui.activity
    if activity=='resources' or activity=='fishing' then
        text(self.sessionClocks,self:SessionClockText())
        local totals=self.displayTotals
        if totals then
            local seconds=self:SessionTotalSeconds()
            local rate=seconds>0 and totals.sessionGold*3600/seconds
            text(self.rate,rate and ((totals.missingSession>0 and self:T('PARTIAL') or '')..self.Gold(rate)..'/h') or self.coin..'/h: —')
        end
        if activity=='fishing' and not self.db.ui.minimized then
            local f,t=self:FishingState(); local stats=self.db.ui.fishingLifetime and t or f
            text(self.fishingInfo,self:T('FISHING_TIME')..': '..self.Time(stats.elapsed))
            for i,count in ipairs({stats.caught,stats.white}) do
                text(self.fishingCards[i].rate,stats.elapsed>0 and string.format('%.1f /h',count*3600/stats.elapsed) or '— /h')
            end
        end
    end
    -- Keep the existing minute-scale price freshness, without whole-window
    -- rebuilds every second. No price work for an empty session or refining.
    local priced=(activity=='resources' or activity=='fishing') and self.displayTotals and self.displayTotals.sessionCount>0
    if priced and self.Now()-(self.timedPricesAt or self.Now())>=60 then self:QueueRefresh() end
    -- Rolling trade periods also advance without new sales. Minute-scale
    -- maintenance replaces the old full rebuild on every second.
    if activity=='gold' and self.Now()-(self.timedPricesAt or self.Now())>=60 then self:QueueRefresh() end
end
local refresh=A.Refresh
function A:Refresh()
    refresh(self)
    self.timedPricesAt=self.Now()
end
