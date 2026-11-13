-- Persistent queue of records (sales, listings, guild traders) waiting to be scanned, backed by SavedVariables.
-- Fires "Changed" whenever the pending list changes.
local SaleQueue = ZO_InitializingCallbackObject:Subclass()

function SaleQueue:Initialize(savedVars)
    self.savedVars = savedVars
end

function SaleQueue:HasSeen(eventId)
    return self.savedVars.seenEventIds[eventId] ~= nil
end

function SaleQueue:Add(sale)
    if self:HasSeen(sale.eventId) then
        return false
    end
    self.savedVars.seenEventIds[sale.eventId] = sale.timestamp
    table.insert(self.savedVars.pendingSales, sale)
    table.sort(self.savedVars.pendingSales, function(a, b) return a.timestamp < b.timestamp end)
    self:FireCallbacks("Changed")
    return true
end

-- For records asked for on demand (guild traders): no seen-id check, so the command can show them again,
-- but never twice in the queue at the same time.
function SaleQueue:AddUnlessPending(record)
    for _, pending in ipairs(self.savedVars.pendingSales) do
        if pending.eventId == record.eventId then
            return false
        end
    end
    table.insert(self.savedVars.pendingSales, record)
    table.sort(self.savedVars.pendingSales, function(a, b) return a.timestamp < b.timestamp end)
    self:FireCallbacks("Changed")
    return true
end

function SaleQueue:GetCount()
    return #self.savedVars.pendingSales
end

function SaleQueue:GetFirst()
    return self.savedVars.pendingSales[1]
end

function SaleQueue:RemoveFirst()
    if self:GetCount() > 0 then
        table.remove(self.savedVars.pendingSales, 1)
        self:FireCallbacks("Changed")
    end
end

function SaleQueue:MoveFirstToEnd()
    if self:GetCount() > 1 then
        local sale = table.remove(self.savedVars.pendingSales, 1)
        table.insert(self.savedVars.pendingSales, sale)
        self:FireCallbacks("Changed")
    end
end

function SaleQueue:PruneSeen(nowS)
    local oldestKeptS = nowS - self.savedVars.seenRetentionSeconds
    for eventId, timestamp in pairs(self.savedVars.seenEventIds) do
        if timestamp < oldestKeptS then
            self.savedVars.seenEventIds[eventId] = nil
        end
    end
end

TradeQR.SaleQueue = SaleQueue
