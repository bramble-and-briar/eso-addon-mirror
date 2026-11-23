-- Gold Digger background work. Big jobs run a few milliseconds per frame, so they can't hit the
-- console's add-on time limit or make the game stutter.

local GP = ESOC_GoldDigger
local Jobs = {}
GP.Jobs = Jobs

local UPDATE_NAME = "ESOCGoldDiggerJobs"
local BUDGET_MS = 5

local queue = {}
local deadline = 0

-- Long loops call this often. It pauses the job when this frame's share of time is used.
local function tick()
    if GetGameTimeMilliseconds() >= deadline then coroutine.yield() end
end

local function step()
    deadline = GetGameTimeMilliseconds() + BUDGET_MS
    while queue[1] and GetGameTimeMilliseconds() < deadline do
        local job = queue[1]
        local ok, err = coroutine.resume(job.thread, tick)
        if not ok then
            table.remove(queue, 1)
            GP.Alert("background job failed: " .. tostring(err))
        elseif coroutine.status(job.thread) == "dead" then
            table.remove(queue, 1)
        else
            break
        end
    end
    if not queue[1] then EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME) end
end

function Jobs.IsRunning(name)
    for _, job in ipairs(queue) do
        if job.name == name then return true end
    end
    return false
end

-- Returns false if a job with this name is already waiting or running.
function Jobs.Start(name, fn)
    if Jobs.IsRunning(name) then return false end
    queue[#queue + 1] = { name = name, thread = coroutine.create(fn) }
    if #queue == 1 then EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 0, step) end
    return true
end
