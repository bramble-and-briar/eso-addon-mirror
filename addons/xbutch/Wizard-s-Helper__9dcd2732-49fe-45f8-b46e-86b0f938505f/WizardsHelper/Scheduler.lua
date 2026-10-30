local WH = WizardsHelper
local updateName = WH.name .. "Work"

-- Every traversal yields per field/record. The count cap also works when the
-- millisecond clock does not advance during a short update.
function WH:StartJob(label, work, complete)
    if self.job then return false end
    local job = { thread = coroutine.create(work), complete = complete }
    self.job = job
    self:SetStatus(label)
    if self.SetBusy then self:SetBusy(true) end
    EVENT_MANAGER:RegisterForUpdate(updateName, 0, function()
        local started = GetGameTimeMilliseconds()
        for _ = 1, self.operationsPerSlice do
            if self.job ~= job then return end
            local ok, result = coroutine.resume(job.thread)
            if not ok or coroutine.status(job.thread) == "dead" then
                EVENT_MANAGER:UnregisterForUpdate(updateName)
                self.job = nil
                if self.SetBusy then self:SetBusy(false) end
                if not ok then
                    self:SetStatus("Operation stopped: " .. tostring(result), true)
                elseif job.complete then
                    local finished, reason = pcall(job.complete, result)
                    if not finished then self:SetStatus("Operation finished with a UI error: " .. tostring(reason), true) end
                end
                return
            end
            if GetGameTimeMilliseconds() - started >= self.sliceMilliseconds then return end
        end
    end)
    return true
end

function WH:CancelJob()
    if not self.job then return end
    EVENT_MANAGER:UnregisterForUpdate(updateName)
    self.job = nil
    if self.SetBusy then self:SetBusy(false) end
    self:SetStatus("Cancelled. No copy was written.")
end

-- Deliberately omit metatables, including WW's Setup methods.
function WH.CopyTable(value, seen)
    local kind = type(value)
    if kind ~= "table" then
        if kind ~= "nil" and kind ~= "string" and kind ~= "number" and kind ~= "boolean" then
            error("Unsupported SavedVariables value: " .. kind)
        end
        return value
    end
    seen = seen or {}
    if seen[value] then error("Cyclic or shared table in setup data.") end
    seen[value] = true
    local copy = {}
    for key, child in next, value do
        if type(key) ~= "string" and type(key) ~= "number" then error("Unsupported setup key.") end
        copy[key] = WH.CopyTable(child, seen)
        coroutine.yield()
    end
    seen[value] = nil
    return copy
end

function WH.SortedKeys(data)
    local keys = {}
    for key in next, data do
        if type(key) == "number" and key > 0 and key == math.floor(key) then keys[#keys + 1] = key end
        coroutine.yield()
    end
    return WH.Sort(keys)
end

-- Cooperative merge sort keeps even unusually large pages off one frame.
function WH.Sort(keys, less)
    less = less or function(a, b) return a < b end
    local width = 1
    while width < #keys do
        local sorted = {}
        for first = 1, #keys, width * 2 do
            local left, right = first, first + width
            local leftEnd, rightEnd = math.min(first + width - 1, #keys), math.min(first + width * 2 - 1, #keys)
            while left <= leftEnd or right <= rightEnd do
                if right > rightEnd or (left <= leftEnd and not less(keys[right], keys[left])) then
                    sorted[#sorted + 1] = keys[left]; left = left + 1
                else
                    sorted[#sorted + 1] = keys[right]; right = right + 1
                end
                coroutine.yield()
            end
        end
        keys = sorted
        width = width * 2
    end
    return keys
end
