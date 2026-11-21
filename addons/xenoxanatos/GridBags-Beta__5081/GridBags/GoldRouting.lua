-- Personal-bank currency policy. One combined gold operation per bank visit;
-- an item receipt can never acknowledge a currency operation.
GridBagsGold = {}
local G = GridBagsGold
local TIMER = "GridBagsGoldTick"
local function Whole(value)
    local n = tonumber(value)
    if not n or n ~= n or n < 0 or n > 9007199254740991 or n ~= math.floor(n) then return nil end
    return n
end

function G:IsBanking()
    return GridBagsRouting:IsBanking()
end

function G:Profile(id)
    return self.data.profiles[id] or { enabled = false, min = 0, fixed = 0, threshold = 0,
        cap = 0, frequency = "visit", resetHour = 0, mode = "ask", revision = 0 }
end

function G:ValidateProfile(spec)
    local p = {}
    for _, field in ipairs({ "min", "fixed", "threshold", "cap", "resetHour" }) do
        p[field] = Whole(spec[field])
        if p[field] == nil then return nil, field .. " must be a nonnegative whole number." end
    end
    if spec.max ~= nil and spec.max ~= "" then
        p.max = Whole(spec.max)
        if not p.max or p.max < p.min then return nil, "Maximum gold must be at least the minimum, or blank to disable it." end
    end
    if p.resetHour > 23 then return nil, "Daily reset hour must be 0–23 UTC." end
    if p.cap > 0 and p.fixed > p.cap then return nil, "Fixed deposit cannot exceed the per-move cap." end
    if spec.frequency ~= "visit" and spec.frequency ~= "daily" then return nil, "Choose a per-visit or daily deposit." end
    if spec.mode ~= "ask" and spec.mode ~= "once" and spec.mode ~= "limited" and spec.mode ~= "standing" then return nil, "Choose an approval mode." end
    for _, field in ipairs({ "unitsLeft", "movesLeft" }) do
        if spec[field] ~= nil and spec[field] ~= "" then
            p[field] = Whole(spec[field])
            if p[field] == nil then return nil, "Allowance counters must be nonnegative whole numbers, or blank." end
        end
    end
    if spec.mode == "limited" and p.unitsLeft == nil and p.movesLeft == nil then return nil, "Limited approval needs a gold or move counter." end
    p.enabled, p.frequency, p.mode = spec.enabled == true, spec.frequency, spec.mode
    p.refill = spec.refill ~= false
    return p
end

function G:SaveProfile(id, spec, bankReserve)
    if self.pending then return nil, "Wait for the current gold transfer to settle." end
    local p, err = self:ValidateProfile(spec)
    if not p then return nil, err end
    local reserve = Whole(bankReserve)
    if reserve == nil then return nil, "Bank reserve must be a nonnegative whole number." end
    p.revision = (self:Profile(id).revision or 0) + 1
    self.data.profiles[id] = p; self.data.bankReserve = reserve
    local visit = self.data.visit
    if visit and visit.open then
        visit.state = "changed"; visit.reason = "Gold settings changed; close and reopen the banker to use them."
        self.current = nil
    end
    self:Notify()
    return p
end

function G:DayKey(p)
    return math.floor((GetTimeStamp() - p.resetHour * 3600) / 86400)
end

function G:Compute(id, p, carried, bank, bankReserve)
    if not p.enabled then return nil, "Gold rule disabled." end
    if carried == nil or bank == nil then return nil, "Balances have not been observed yet.", "GOLD_NOT_OBSERVED" end
    local key = self:DayKey(p)
    local reserve = bankReserve ~= nil and bankReserve or (self.data.bankReserve or 0)
    local amount, direction, reasons, daily = 0, nil, {}, false
    if carried < p.min then
        if p.refill == false then return nil, "Below the protected carried minimum; automatic refill is off.", "GOLD_REFILL_DISABLED" end
        direction, amount = "withdraw", p.min - carried
        reasons[#reasons + 1] = "Refill carried minimum"
        if p.cap > 0 then amount = math.min(amount, p.cap) end
        if bank - amount < reserve then return nil, "Bank reserve or available funds cannot cover the refill.", "GOLD_BANK_RESERVE" end
    else
        if p.max and carried > p.max then amount = carried - p.max; reasons[#reasons + 1] = "Deposit carried excess" end
        local due = p.frequency == "visit" or self.data.daily[id] ~= key
        if due and p.fixed > 0 and carried > p.threshold and carried - p.fixed >= p.min then
            amount = math.max(amount, p.fixed)
            daily = p.frequency == "daily"
            reasons[#reasons + 1] = daily and "Daily deposit" or "Per-visit deposit"
        end
        if p.cap > 0 then amount = math.min(amount, p.cap) end
        if amount > 0 then direction = "deposit" end
    end
    if amount <= 0 then
        if p.fixed > 0 then
            if p.frequency == "daily" and self.data.daily[id] == key then return nil, "Daily contribution already completed for this reset period.", "GOLD_DAILY_ALREADY_DONE" end
            if carried <= p.threshold then return nil, "Carried gold is not above the fixed-deposit threshold.", "GOLD_BELOW_THRESHOLD" end
            if carried - p.fixed < p.min then return nil, "Fixed deposit would breach the protected carried minimum.", "GOLD_MIN_PROTECTED" end
        end
        return nil, "Carried gold is within limits; no fixed contribution is configured.", "GOLD_WITHIN_LIMITS"
    end
    return { character = id, direction = direction, amount = amount, beforeChar = carried, beforeBank = bank,
        revision = p.revision, reason = table.concat(reasons, "; "), daily = daily, dayKey = key }
end

function G:Balances()
    return GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER), GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_BANK)
end

function G:ItemWork()
    local R = GridBagsRouting
    if R.pending or R.current then return true end
    for _, op in ipairs(R.data.visit and R.data.visit.queue or {}) do if op.status == "queued" then return true end end
    return false
end

function G:IsBusy()
    return self.pending ~= nil or self.current ~= nil
end

function G:Allowed(op)
    local p = self:Profile(op.character)
    if p.mode == "once" or p.mode == "standing" then return true end
    return p.mode == "limited" and (p.unitsLeft == nil or p.unitsLeft >= op.amount) and (p.movesLeft == nil or p.movesLeft >= 1)
end

function G:Validate(op)
    if not self:IsBanking() then return nil, "Personal bank is not open in keyboard mode.", "BANK_UNAVAILABLE" end
    if BMR then return nil, "BankManager is still loaded; gold rules are blocked.", "AUTO_MOVER_CONFLICT" end
    local p = self:Profile(op.character)
    if not p.enabled then return nil, "Gold rule was disabled.", "GOLD_POLICY_DISABLED" end
    if p.revision ~= op.revision then return nil, "Gold rule changed since the proposal.", "GOLD_POLICY_CHANGED" end
    if op.character ~= self.character then return nil, "This move belongs to another character.", "WRONG_CHARACTER" end
    if self.data.holds[self.character] then return nil, "A previous gold transfer needs review.", "GOLD_REVIEW_HOLD" end
    if self:ItemWork() then return nil, "Finish the item queue first.", "ITEM_QUEUE_BUSY" end
    local carried, bank = self:Balances()
    if carried ~= op.beforeChar or bank ~= op.beforeBank then return nil, "Gold balances changed; reopen the banker for a fresh proposal.", "GOLD_BALANCES_CHANGED" end
    if op.daily and self:DayKey(p) ~= op.dayKey then return nil, "Daily reset passed; reopen the banker for a fresh proposal.", "GOLD_DAY_CHANGED" end
    if op.direction == "deposit" and carried - op.amount < p.min then return nil, "Carried minimum would be violated.", "GOLD_MIN_PROTECTED" end
    if op.direction == "withdraw" and bank - op.amount < (self.data.bankReserve or 0) then return nil, "Bank reserve would be violated.", "GOLD_BANK_RESERVE" end
    local from = op.direction == "deposit" and CURRENCY_LOCATION_CHARACTER or CURRENCY_LOCATION_BANK
    local to = op.direction == "deposit" and CURRENCY_LOCATION_BANK or CURRENCY_LOCATION_CHARACTER
    if GetMaxCurrencyTransfer and GetMaxCurrencyTransfer(CURT_MONEY, from, to) < op.amount then return nil, "The game cannot accept that currency amount.", "GOLD_CAPACITY" end
    return true, from, to
end

function G:Hold(op, reason, code)
    self.data.holds[op.character] = { operation = op, reason = reason, code = code or "GOLD_RESULT_UNCERTAIN" }
    self.data.visit.state = "review"; self.data.visit.reason = reason
    self.data.visit.inFlight = nil; self.pending = nil; self.current = nil
    GridBagsActivity:Gold(op, "review", reason, code or "GOLD_RESULT_UNCERTAIN")
    self:Notify()
end

function G:ReleaseHold(id)
    if self.pending then return nil, "Wait for the current gold transfer." end
    self.data.holds[id] = nil
    local p = self.data.profiles[id]
    if p then p.mode = "ask"; p.revision = p.revision + 1 end
    if self.data.visit and self.data.visit.character == id then
        self.data.visit.state = "changed"; self.data.visit.reason = "Review hold cleared; reopen the banker. The next move requires confirmation."
    end
    self:Notify(); return true
end

function G:Open()
    if not self:IsBanking() or self.pending then return end
    local visit = self.data.visit
    if visit and visit.open and visit.character == self.character then
        if visit.inFlight then self:Hold(visit.inFlight, "Reload during gold transfer: inspect both balances before releasing the hold.", "GOLD_RELOAD_UNCERTAIN") end
    else
        self.data.nextVisit = (self.data.nextVisit or 0) + 1
        self.data.visit = { open = true, id = self.data.nextVisit, character = self.character, state = "waiting" }
    end
    EVENT_MANAGER:RegisterForUpdate(TIMER, 250, function() self:Tick() end)
    self:Tick()
end

function G:Start(op)
    if GridBagsActivity:IsPaused() then return end
    local ok, from, to = self:Validate(op)
    if not ok then
        GridBagsActivity:Gold(op, "skipped", from, to or "GOLD_VALIDATION")
        self.data.visit.state = "skipped"; self.data.visit.reason = from; self.current = nil; self:Notify(); return
    end
    local visit = self.data.visit
    -- Persistent intent precedes the request. Reloads cannot authorize a retry.
    if visit.state ~= "waiting" and visit.state ~= "awaiting" then return end
    visit.state, visit.inFlight = "sent", op
    op.sentAt = GetFrameTimeSeconds(); self.pending = op; self.current = nil
    GridBagsActivity:Gold(op, "requested", op.reason .. "; awaiting both currency balances", "GOLD_REQUESTED")
    local called, accepted, detail = pcall(TransferCurrency, CURT_MONEY, op.amount, from, to)
    if not called or accepted == false then
        self:Hold(op, (called and "Game declined gold transfer" or "Client gold call raised an error") ..
            ((called and detail or accepted) and (": " .. tostring(called and detail or accepted):sub(1,1000)) or "") .. "; inspect both balances before retrying.",
            called and "GOLD_REQUEST_REJECTED" or "GOLD_CALL_ERROR")
    end
    self:Notify()
end

function G:Observe()
    local op = self.pending
    if not op then return end
    local carried, bank = self:Balances()
    op.afterChar, op.afterBank = carried, bank
    local change = op.direction == "deposit" and -op.amount or op.amount
    if carried == op.beforeChar + change and bank == op.beforeBank - change then
        local p = self:Profile(op.character)
        if p.unitsLeft ~= nil then p.unitsLeft = math.max(0, p.unitsLeft - op.amount) end
        if p.movesLeft ~= nil then p.movesLeft = math.max(0, p.movesLeft - 1) end
        if p.mode == "once" then p.mode = "ask" end
        if op.daily then self.data.daily[op.character] = op.dayKey end
        self.data.history[#self.data.history + 1] = { at = GetTimeStamp(), character = op.character,
            amount = op.amount, direction = op.direction, carried = carried, bank = bank }
        if #self.data.history > 100 then table.remove(self.data.history, 1) end
        self.pending = nil; self.data.visit.inFlight = nil; self.data.visit.state = "done"
        self.data.visit.reason = "Verified " .. op.direction .. " of " .. op.amount .. " gold."
        GridBagsActivity:Gold(op, "success", self.data.visit.reason, "GOLD_VERIFIED")
        GridBagsSnapshots:QueueCapture(); GridBagsSnapshots:CaptureBank(); self.owner:QueueRefresh(); self:Notify()
    elseif GetFrameTimeSeconds() - op.sentAt > 4 then
        self:Hold(op, "Gold transfer timed out without matching both balances. Outcome uncertain; no automatic retry.", "GOLD_TIMEOUT_UNCERTAIN")
    end
end

function G:Tick()
    if not self:IsBanking() then return end
    if self.pending then self:Observe(); return end
    if GridBagsActivity:IsPaused() then return end
    local visit = self.data.visit
    if not visit or not visit.open then return end
    if GridBagsRoutingUI.editingSession or (GridBagsGoldUI and GridBagsGoldUI:IsEditing()) then return end
    if self:ItemWork() then return end
    if BMR then
        visit.state = "skipped"; visit.reason = "Disable BankManager before using gold rules."
        if self:Profile(self.character).enabled then GridBagsActivity:GoldVisit(visit,visit.reason,"AUTO_MOVER_CONFLICT")end
        self:Notify(); return
    end
    if self.data.holds[self.character] then visit.state = "review"; self:Notify(); return end
    if visit.state == "awaiting" then
        self.current = visit.proposal
        if self.current and self:Allowed(self.current) then self:Start(self.current) else self:Notify() end
        return
    end
    if visit.state ~= "waiting" then return end
    local carried, bank = self:Balances()
    local op, reason, code = self:Compute(self.character, self:Profile(self.character), carried, bank)
    if not op then
        visit.state = "idle"; visit.reason = reason
        if self:Profile(self.character).enabled then GridBagsActivity:GoldVisit(visit, reason, code or "GOLD_LIMITS") end
        self:Notify(); return
    end
    visit.proposal = op
    if self:Allowed(op) then self:Start(op)
    else visit.state = "awaiting"; self.current = op; self:Notify() end
end

function G:Confirm()
    if GridBagsActivity:IsPaused() then return end
    if self.pending or not self.current or GridBagsRoutingUI.editingSession or GridBagsGoldUI:IsEditing() then return end
    self:Start(self.current)
end

function G:Skip(reason, code)
    if self.pending then return end
    reason, code = reason or "Gold skipped this bank visit.", code or "USER_SKIP"
    if self.current then GridBagsActivity:Gold(self.current, "skipped", reason, code)
    elseif self.data.visit then GridBagsActivity:GoldVisit(self.data.visit, reason, code) end
    if self.data.visit then self.data.visit.state = "skipped"; self.data.visit.reason = reason end
    self.current = nil; self:Notify()
end

function G:Manual(direction)
    if not self:IsBanking() then d("GridBags: currency transfers require an open personal bank."); return end
    if self.pending or GridBagsRouting.pending then d("GridBags: wait for the current transfer to settle."); return end
    if not self.data.visit or not self.data.visit.open or self.data.visit.character ~= self.character then
        self.data.nextVisit = (self.data.nextVisit or 0) + 1
        self.data.visit = { open = true, id = self.data.nextVisit, character = self.character, state = "manual" }
    end
    self:Skip("Native currency dialog opened; automatic gold skipped this visit.", "NATIVE_CURRENCY")
    ZO_Dialogs_ShowDialog(direction == "deposit" and "BANK_DEPOSIT_GOLD" or "BANK_WITHDRAW_GOLD")
end

function G:Close()
    if self.pending then self:Hold(self.pending, "Bank closed during gold transfer. Inspect balances before releasing the review hold.", "GOLD_BANK_CLOSED_UNCERTAIN") end
    if self.data.visit then self.data.visit.open = false end
    self.current = nil; EVENT_MANAGER:UnregisterForUpdate(TIMER); self:Notify()
end

function G:Notify()
    if GridBagsGoldUI then GridBagsGoldUI:Update() end
end

function G:Initialize(owner)
    self.owner, self.character = owner, GetCurrentCharacterId()
    owner.saved.goldRouting = owner.saved.goldRouting or {}
    local world = GetWorldName()
    owner.saved.goldRouting[world] = owner.saved.goldRouting[world] or {}
    self.data = owner.saved.goldRouting[world]
    for _, name in ipairs({ "profiles", "daily", "holds", "history" }) do self.data[name] = self.data[name] or {} end
    EVENT_MANAGER:RegisterForEvent("GridBagsGold", EVENT_OPEN_BANK, function()
        EVENT_MANAGER:RegisterForUpdate("GridBagsGoldOpen", 600, function()
            EVENT_MANAGER:UnregisterForUpdate("GridBagsGoldOpen"); self:Open()
        end)
    end)
    EVENT_MANAGER:RegisterForEvent("GridBagsGold", EVENT_CLOSE_BANK, function()
        EVENT_MANAGER:UnregisterForUpdate("GridBagsGoldOpen"); self:Close()
    end)
    EVENT_MANAGER:RegisterForEvent("GridBagsGold", EVENT_PLAYER_ACTIVATED, function()
        if self:IsBanking() then self:Open()
        elseif self.data.visit then
            if self.data.visit.inFlight then self:Hold(self.data.visit.inFlight, "Interrupted gold transfer; inspect both balances.", "GOLD_RELOAD_UNCERTAIN") end
            self.data.visit.open = false
        end
    end)
end
