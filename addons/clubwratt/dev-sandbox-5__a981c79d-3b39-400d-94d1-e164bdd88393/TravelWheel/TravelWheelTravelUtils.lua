-- TravelWheelTravelUtils.lua: Pure decisions about a wayshrine trip and a
-- battleground queue.

local TravelWheelTravelUtils = {}

---Why a wayshrine trip cannot be made, or nil when it can.
---@param facts TravelWheelNodeFacts
---@return string|nil reason
function TravelWheelTravelUtils.NodeBlock(facts)
    if facts.dead then
        return "you are dead"
    end
    if not facts.canLeave then
        return "you cannot travel from here"
    end
    if not facts.known then
        return "not discovered on this character"
    end
    if facts.cost > facts.gold then
        return string.format("the trip costs %d gold and you carry %d", facts.cost, facts.gold)
    end
    return nil
end

---Whether a queue is ticked for an entry: every queue is, until the player
---unticks it, so one the game adds later is joined too.
---@param ticks table<integer, boolean> By the finder's set id
---@param setId integer
---@return boolean
function TravelWheelTravelUtils.IsQueueTicked(ticks, setId)
    return ticks[setId] ~= false
end

---The ticked queues among the ones the finder offers.
---@param queues TravelWheelQueue[]
---@param ticks table<integer, boolean>
---@return TravelWheelQueue[] ticked
function TravelWheelTravelUtils.TickedQueues(queues, ticks)
    local ticked = {}
    for _, queue in ipairs(queues) do
        if TravelWheelTravelUtils.IsQueueTicked(ticks, queue.setId) then
            ticked[#ticked + 1] = queue
        end
    end
    return ticked
end

---Which battleground queues a press joins: the ticked ones the game lets the
---player join now, as ticking them in the Activity Finder would. A locked
---one is left out, as a solo queue is in a group.
---@param queues TravelWheelQueue[] What the finder offers this character
---@param ticks table<integer, boolean>
---@return TravelWheelQueue[] join Empty when there is nothing to join
---@return string|nil reason Why there is nothing to join
function TravelWheelTravelUtils.QueuesToJoin(queues, ticks)
    if #queues == 0 then
        return {}, "the Activity Finder offers this character no battleground queue"
    end
    local ticked = TravelWheelTravelUtils.TickedQueues(queues, ticks)
    if #ticked == 0 then
        return {}, "no battleground queue is ticked for this entry"
    end
    local join = {}
    for _, queue in ipairs(ticked) do
        if not queue.locked then
            join[#join + 1] = queue
        end
    end
    if #join == 0 then
        local reason = ticked[1].lockReason
        return {}, string.format("%s: %s", ticked[1].name, reason ~= "" and reason or "locked")
    end
    return join, nil
end

---@param queues TravelWheelQueue[]
---@return string names "A, B, C"
function TravelWheelTravelUtils.QueueNames(queues)
    local names = {}
    for _, queue in ipairs(queues) do
        names[#names + 1] = queue.name
    end
    return table.concat(names, ", ")
end

TravelWheel.TravelUtils = TravelWheelTravelUtils
