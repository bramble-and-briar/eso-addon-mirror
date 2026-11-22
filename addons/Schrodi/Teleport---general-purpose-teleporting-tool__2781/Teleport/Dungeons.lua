Teleport.Dungeons = {}

local info  = Teleport.info
local dbg   = Teleport.dbg
local color = Teleport.color
local C     = Teleport.COLORS

--------------------------------------------------------------------------------

-- returns: nodeName, nodeIndex, difficulty (n, v or r)
local function findDungeon(namePrefix, aliasOnly)
    local dungeonName, difficulty = Teleport.Aliases:getDungeonByAlias(namePrefix)
    if aliasOnly and not dungeonName then
        return nil, nil, nil
    end
    
    if dungeonName then
        return dungeonName, Teleport.Nodes:getDungeonNodeIndex(dungeonName), difficulty
    end
    
    local nodeName, nodeIndex = Teleport.Nodes:findDungeonNode(namePrefix)
    return nodeName, nodeIndex, difficulty
end

local function teleportToDungeonAux(nodeName, nodeIndex)
    if Teleport.Helpers:isAtWayshrine() and Teleport.Nodes:isKnown(nodeIndex) then
        info("Teleporting to " .. color(nodeName, C.DUNGEON) .. Teleport.Nodes:getRecallCostString(nodeIndex))
        FastTravelToNode(nodeIndex)
        return
    end

    local player = Teleport.Players:findPlayerByDungeonName(nodeName)
    if player then
        dbg("Teleporting to " .. player.displayName .. " in " .. nodeName)
        Teleport.Players:teleportToPlayer(player)
        return
    end
    
    if not Teleport.Nodes:isKnown(nodeIndex) then
        info("Failed to teleport to " .. color(nodeName, C.NOT_UNLOCKED) .. ": Dungeon not unlocked.")
        return
    end

    info("Teleporting to " .. color(nodeName, C.DUNGEON) .. Teleport.Nodes:getRecallCostString(nodeIndex))
    FastTravelToNode(nodeIndex)
end

-------------------------------------------------------------------------------
-- Difficulty changes
--
-- SetVeteranDifficulty() is a request to the server. The answer comes back as
-- EVENT_VETERAN_DIFFICULTY_CHANGED (once per affected unit: player, group1..N)
-- plus EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED, in no particular order. So
-- instead of counting events, every change waits until the difficulty the
-- game reports actually is the one we asked for (checked on every event and
-- on a timer), resends the request once if it's slow, and gives up after a
-- timeout - always unregistering everything.

local NAMESPACE          = "Teleport_Difficulty"
local POLL_MS            = 200
local RESEND_MS          = 2000
local TIMEOUT_MS         = 6000
local BETWEEN_TOGGLES_MS = 500
local BEFORE_TRAVEL_MS   = 1000

local function isVeteran()
    if IsUnitGrouped("player") then
        return IsGroupUsingVeteranDifficulty() == true
    end
    return IsUnitUsingVeteranDifficulty("player") == true
end

local function getVeteranDifficulty()
    return isVeteran() and 'v' or 'n'
end

local function difficultyName(veteran)
    return veteran and "veteran" or "normal"
end

-- only one difficulty change / reset at a time - a second /tp in the middle
-- of a reset could otherwise leave you on the wrong difficulty
local OPERATION_TIMEOUT_MS = 2 * TIMEOUT_MS + BETWEEN_TOGGLES_MS + BEFORE_TRAVEL_MS + 1000
local operationId = 0
local operationStarted
local activeChange

local function startOperation()
    operationId = operationId + 1
    operationStarted = GetFrameTimeMilliseconds()
    return operationId
end

local function endOperation()
    operationStarted = nil
end

local function isOperationRunning()
    return operationStarted ~= nil and GetFrameTimeMilliseconds() - operationStarted < OPERATION_TIMEOUT_MS
end

local function stopChange()
    EVENT_MANAGER:UnregisterForEvent(NAMESPACE, EVENT_VETERAN_DIFFICULTY_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(NAMESPACE, EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED)
    EVENT_MANAGER:UnregisterForUpdate(NAMESPACE)
    activeChange = nil
end

-- callback(success), called asynchronously
local function changeDifficulty(toVeteran, callback)
    stopChange()

    local change = { started = GetFrameTimeMilliseconds(), resent = false }
    activeChange = change

    local function finish(success)
        if activeChange ~= change then return end
        stopChange()
        zo_callLater(function() callback(success) end, 0)
    end

    local function check()
        if activeChange ~= change then return end

        if isVeteran() == toVeteran then
            return finish(true)
        end

        local elapsed = GetFrameTimeMilliseconds() - change.started
        if elapsed > TIMEOUT_MS then
            return finish(false)
        end
        if not change.resent and elapsed > RESEND_MS then
            change.resent = true
            dbg("Difficulty change is taking a while, sending it again")
            SetVeteranDifficulty(toVeteran)
        end
    end

    EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_VETERAN_DIFFICULTY_CHANGED, check)
    EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED, check)
    EVENT_MANAGER:RegisterForUpdate(NAMESPACE, POLL_MS, check)

    SetVeteranDifficulty(toVeteran)
end

-- nil if the change is allowed, otherwise the reason (game's own strings)
local function getChangeBlocker(toVeteran)
    local canChange, reason = CanPlayerChangeGroupDifficulty()
    if not canChange and not (reason == GROUP_DIFFICULTY_CHANGE_REASON_NO_UNIT and not IsUnitGrouped("player")) then
        return GetString("SI_GROUPDIFFICULTYCHANGEREASON", reason)
    end
    if toVeteran and not CanUnitGainChampionPoints("player") then
        return GetString("SI_GROUPDIFFICULTYCHANGEREASON", GROUP_DIFFICULTY_CHANGE_REASON_NOT_UNLOCKED)
    end
    return nil
end

local function isLeader()
    return not IsUnitGrouped("player") or IsUnitGroupLeader("player")
end

-------------------------------------------------------------------------------

local function setDifficultyAndTravel(nodeName, nodeIndex, toVeteran)
    if not isLeader() then
        info("You have to be your group's leader to change difficulty.")
        return
    end

    local blocker = getChangeBlocker(toVeteran)
    if blocker then
        info("Can't change dungeon difficulty: " .. blocker)
        return
    end

    if IsUnitGrouped("player") and IsAnyGroupMemberInDungeon() then
        info("One or more group members are currently in a dungeon. Changing dungeon difficulty will kick them out.")
        info("If You wish to continue anyway, change dungeon difficulty manually in the group menu.")
        return
    end

    local myOperation = startOperation()

    info("Changing dungeon difficulty to " .. difficultyName(toVeteran))
    changeDifficulty(toVeteran, function(success)
        if myOperation ~= operationId then return end
        if not success then
            info("Failed to change dungeon difficulty to " .. difficultyName(toVeteran) .. ", not teleporting.")
            return endOperation()
        end
        zo_callLater(function()
            if myOperation ~= operationId then return end
            endOperation()
            teleportToDungeonAux(nodeName, nodeIndex)
        end, BEFORE_TRAVEL_MS)
    end)
end

local function resetAndTravel(nodeName, nodeIndex)
    if not isLeader() then
        info("Teleporting to a hopefully reset instance of " .. color(nodeName, C.DUNGEON) .. Teleport.Nodes:getRecallCostString(nodeIndex))
        FastTravelToNode(nodeIndex)
        return
    end

    if not Teleport.Nodes:isKnown(nodeIndex) then
        info("Failed to teleport to " .. color(nodeName, C.NOT_UNLOCKED) .. ": Dungeon not unlocked.")
        return
    end

    local original = isVeteran()
    local opposite = not original

    -- both directions have to be allowed (veteran needs CP)
    local blocker = getChangeBlocker(opposite) or getChangeBlocker(original)
    if blocker then
        info("Can't reset the instance: " .. blocker)
        return
    end

    local myOperation = startOperation()

    info("Resetting instance (" .. difficultyName(original) .. " -> " .. difficultyName(opposite) .. " -> " .. difficultyName(original) .. ")")
    changeDifficulty(opposite, function(success)
        if myOperation ~= operationId then return end
        if not success then
            info("Failed to reset the instance: difficulty didn't change, not teleporting.")
            return endOperation()
        end

        zo_callLater(function()
            if myOperation ~= operationId then return end
            changeDifficulty(original, function(success2)
                if myOperation ~= operationId then return end
                if not success2 then
                    info("Instance was reset, but switching back to " .. difficultyName(original) .. " failed - difficulty is now "
                        .. color(difficultyName(opposite), C.NOT_FOUND) .. ". Not teleporting.")
                    return endOperation()
                end

                zo_callLater(function()
                    if myOperation ~= operationId then return end
                    endOperation()
                    info("Teleporting to a reset instance of " .. color(nodeName, C.DUNGEON) .. Teleport.Nodes:getRecallCostString(nodeIndex))
                    FastTravelToNode(nodeIndex)
                end, BEFORE_TRAVEL_MS)
            end)
        end, BETWEEN_TOGGLES_MS)
    end)
end

-------------------------------------------------------------------------------

function Teleport.Dungeons:teleportToDungeon(name, aliasOnly)
    local nodeName, nodeIndex, difficulty = findDungeon(name, aliasOnly)
    if not nodeIndex then
        dbg("Failed to teleport to " .. name .. ": No such dungeon/trial/arena found."
            .. (aliasOnly and "(aliasOnly)" or ""))
        return false
    end

    if isOperationRunning() then
        info("Still changing dungeon difficulty, hold on...")
        return true
    end

    if difficulty == 'r' then
        resetAndTravel(nodeName, nodeIndex)
        return true
    end

    -- no change in difficulty
    if not difficulty or difficulty == getVeteranDifficulty() then
        teleportToDungeonAux(nodeName, nodeIndex)
        return true
    end

    setDifficultyAndTravel(nodeName, nodeIndex, difficulty == 'v')
    return true
end
