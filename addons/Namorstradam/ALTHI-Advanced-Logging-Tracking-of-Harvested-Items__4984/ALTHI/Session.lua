local A = ALTHarvestItems
function A:AccrueTime()
    local session = self.db.session
    local now = self.Now()
    if session.state == "running" and self.runningAt then
        session.elapsed = session.elapsed + math.max(0, now - self.runningAt)
    end
    self.runningAt = session.state == "running" and now or nil
end
function A:Play()
    self:AccrueTime()
    local session = self.db.session
    session.state = "running"
    self.runningAt = self.Now()
    self:QueueRefresh()
end
function A:Pause()
    self:AccrueTime()
    self.db.session.state = "paused"
    self.runningAt = nil
    self:QueueRefresh()
end
function A:Stop()
    -- Compatibility for existing Stop bindings: pause the same session.
    self:Pause()
end
function A:TogglePause()
    if self.db.session.state == 'paused' then self:Play() else self:Pause() end
end
function A:ResetSession()
    self:AccrueTime()
    self.db.lastSession = self.Copy(self.db.session)
    self.db.session = { state = "stopped", elapsed = 0, counts = {} }
    self.runningAt = nil
    self.offset = 0
    self:ClearHarvest()
    self:QueueRefresh()
end
function A:AcceptedHarvest(id, count)
    local session = self.db.session
    if session.state == "stopped" then
        if not self.db.options.autoStart then return false end
        self:Play()
    end
    if session.state == "paused" then
        if not self.db.options.autoResume then return false end
        self:Play()
    end
    self:AccrueTime()
    session.counts[id] = (session.counts[id] or 0) + count
    self:QueueRefresh()
    return true
end
-- An item type joins stock valuation only after this session acquired it.
-- Derive legacy sessions from their existing evidence; never import bag totals.
function A:SessionItemSeen(id)
    local session=self.db.session
    if (session.counts[id] or 0)>0 then return true end
    local fish=session.fishing
    return fish and ((fish.catches[id] or 0)>0 or (fish.outputs[id] or 0)>0
        or id==33753 and fish.filleted>0 or id==64222 and fish.roe>0) or false
end
function A:RowsAndTotals()
    local rows = {}
    local totals = { sessionCount = 0, stockCount = 0, sessionGold = 0, stockGold = 0,
        missingSession = 0, missingStock = 0 }
    for id, item in pairs(self.db.catalog) do
        if self:IsEnabled(id) then
            local count = self.db.session.counts[id] or 0
            local stock = self:SessionItemSeen(id) and (self.stock[id] or 0) or 0
            local price, source
            if count > 0 or stock > 0 then price, source = self:Price(id) end
            totals.sessionCount = totals.sessionCount + count
            totals.stockCount = totals.stockCount + stock
            if price then
                totals.sessionGold = totals.sessionGold + price * count
                totals.stockGold = totals.stockGold + price * stock
            else
                if count > 0 then totals.missingSession = totals.missingSession + 1 end
                if stock > 0 then totals.missingStock = totals.missingStock + 1 end
            end
            if count > 0 then
                rows[#rows + 1] = { id = id, name = zo_strformat("<<C:1>>", item.name),
                    icon = item.icon, quality = item.quality or 1, count = count, stock = stock,
                    price = price, source = source }
            end
        end
    end
    self:SortRows(rows)
    local seconds = self.db.session.elapsed
    if seconds >= 1 then totals.perHour = totals.sessionGold * 3600 / seconds end
    return rows, totals
end
