local AMW = AutoMasterWrits
AMW.sliceMilliseconds = 2
AMW.sliceUnits = 24
AMW.sharedReserveMilliseconds = 200

function AMW:HasWorkBudget()
    if GetTotalUserAddOnCPUTimeAvailableEachFrameMS and GetTotalUserAddOnCPUTimeUsedNowMS then
        local total = GetTotalUserAddOnCPUTimeAvailableEachFrameMS()
        if not total or total <= 0 then return false end
        local used = GetTotalUserAddOnCPUTimeUsedNowMS()
        return type(used) == "number" and used + self.sharedReserveMilliseconds < total
    end
    return true
end

function AMW:Yield(delay)
    return coroutine.yield(delay or 0)
end

function AMW:StartJob(key, worker)
    self.jobs = self.jobs or {}
    self.jobOrder = self.jobOrder or {}
    local listed = false
    for _, name in ipairs(self.jobOrder) do if name == key then listed = true; break end end
    if not listed then self.jobOrder[#self.jobOrder + 1] = key end
    self.jobs[key] = { thread = coroutine.create(worker), nextAt = 0 }
    self:WatchDeactivation()
    if not self.schedulerRunning then
        self.schedulerRunning = true
        EVENT_MANAGER:RegisterForUpdate(self.name .. "Work", 25, function() self:RunWorkSlice() end)
    end
end

function AMW:CancelJob(key)
    if self.jobs then self.jobs[key] = nil end
end

function AMW:RunWorkSlice()
    if not self.jobs or next(self.jobs) == nil then return self:StopScheduler() end
    if not self:HasWorkBudget() then return end
    local frame = GetFrameTimeMilliseconds()
    if frame == self.lastWorkFrame then return end
    self.lastWorkFrame = frame
    local started, units = GetGameTimeMilliseconds(), 0
    local order = self.jobOrder
    for position = #order, 1, -1 do if not self.jobs[order[position]] then table.remove(order, position) end end
    -- One job per callback. A delayed job never causes a busy loop.
    for position = 1, #order do
        local key = order[position]
        local job = self.jobs[key]
        if job and job.nextAt <= started then
            while units < self.sliceUnits and self:HasWorkBudget()
                and GetGameTimeMilliseconds() - started < self.sliceMilliseconds do
                units = units + 1
                local ok, delay = coroutine.resume(job.thread)
                if not ok then
                    if self.jobs[key] == job then self.jobs[key] = nil end
                    if self.delivery then self:PauseDelivery("Operation stopped: " .. tostring(delay))
                    else self:StopAll("Operation stopped: " .. tostring(delay)) end
                    return
                end
                if self.jobs[key] ~= job then break end
                if coroutine.status(job.thread) == "dead" then
                    self.jobs[key] = nil
                    break
                end
                job.nextAt = GetGameTimeMilliseconds() + (tonumber(delay) or 0)
                if job.nextAt > GetGameTimeMilliseconds() then break end
            end
            -- Round robin without leaving dead job names in the list.
            table.remove(order, position)
            if self.jobs[key] then order[#order + 1] = key end
            break
        end
    end
    if not next(self.jobs) then self:StopScheduler() end
    self:UpdateHUD()
end

function AMW:StopScheduler()
    if self.schedulerRunning then EVENT_MANAGER:UnregisterForUpdate(self.name .. "Work") end
    self.schedulerRunning = false
    self.jobs, self.jobOrder = {}, {}
    self.lastWorkFrame = nil
end

function AMW:SortWorker(rows, less)
    local width, count, work = 1, #rows, 0
    local output = {}
    while width < count do
        for first = 1, count, width * 2 do
            local middle, last = math.min(first + width, count + 1), math.min(first + width * 2 - 1, count)
            local left, right = first, middle
            for target = first, last do
                if left < middle and (right > last or less(rows[left], rows[right])) then
                    output[target], left = rows[left], left + 1
                else
                    output[target], right = rows[right], right + 1
                end
                work = work + 1
                if work % 16 == 0 then self:Yield() end
            end
        end
        rows, output = output, rows
        width = width * 2
        self:Yield()
    end
    return rows
end

function AMW:WatchDeactivation()
    if self.watchingDeactivation then return end
    self.watchingDeactivation = true
    EVENT_MANAGER:RegisterForEvent(self.name .. "Deactivate", EVENT_PLAYER_DEACTIVATED, function()
        self:StopAll()
    end)
end

function AMW:StopAll(message)
    self.generation = (self.generation or 0) + 1
    self:StopScheduler()
    self.delivery, self.extracting, self.bankOperation = nil, nil, nil
    self.bankArmed, self.sessionActive = false, false
    self:ReleaseDeliveryEvents()
    self:ReleaseHooks()
    EVENT_MANAGER:UnregisterForEvent(self.name .. "Bank", EVENT_OPEN_BANK)
    EVENT_MANAGER:UnregisterForEvent(self.name .. "BankClose", EVENT_CLOSE_BANK)
    EVENT_MANAGER:UnregisterForEvent(self.name .. "Deactivate", EVENT_PLAYER_DEACTIVATED)
    self.watchingDeactivation = false
    self.xpDirty = true
    if self.hud then self.hud:SetHidden(true); self.hudHidden = true end
    if message then self:SetStatus(message, true) end
end

