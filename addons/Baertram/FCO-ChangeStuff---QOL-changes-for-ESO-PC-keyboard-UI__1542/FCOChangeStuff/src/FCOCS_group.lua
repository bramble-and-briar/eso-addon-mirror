if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

local EM = EVENT_MANAGER

local playerTag = "player"

------------------------------------------------------------------------------------------------------------------------
-- Group --
------------------------------------------------------------------------------------------------------------------------

local function WrapFunction(object, functionName, wrapper)
    if(type(object) == "string") then
        wrapper = functionName
        functionName = object
        object = _G
    end
    local originalFunction = object[functionName]
    object[functionName] = function(...) return wrapper(originalFunction, ...) end
end

function FCOChangeStuff.hookChampionRankUtils()
--d("hookChampionRankUtils")
    if not FCOChangeStuff.settingsVars.settings.showRealCPs then return false end
    local CHAMPION_CAP_NEW = GetMaxSpendableChampionPointsInAttribute() * 10 -- normal is * 3
    function GetLevelOrChampionPointsStringNoIcon(level, championPoints)
--d("GetLevelOrChampionPointsStringNoIcon HOOKED: " .. tostring(CHAMPION_CAP_NEW) .. ", level: " .. tostring(level) ..", CPs: " .. tostring(championPoints))
        if championPoints and championPoints > 0 then
            if championPoints > CHAMPION_CAP_NEW then
                return tostring(CHAMPION_CAP_NEW)
            else
                return tostring(championPoints)
            end
        elseif level and level > 0 then
            return tostring(level)
        else
            return ""
        end
    end
end

function FCOChangeStuff.hookGroupList(runItOnce)
    if not FCOChangeStuff.settingsVars.settings.showRealCPs then return false end
    runItOnce = runItOnce or false
--d("FCOChangeStuff.hookGroupList- runItOnce: " .. tostring(runItOnce))
    if GROUP_LIST_MANAGER then
        local originalBuildMasterList = GROUP_LIST_MANAGER.BuildMasterList
        if originalBuildMasterList == nil then return false end
        WrapFunction(GROUP_LIST_MANAGER, "BuildMasterList", function(originalBuildMasterList, ...)
            -- do something before it
            FCOChangeStuff.runGroupListCounter = FCOChangeStuff.runGroupListCounter + 1
--d("wrapper func called: " .. tostring(FCOChangeStuff.runGroupListCounter))
            --Save the original CP function
            local cpFuncEffective = FCOChangeStuff.originalUnitCPEffectiveFunc
            if cpFuncEffective == nil then return false end
--d("got here")
            --Change the CP effective to the CP function
            GetUnitEffectiveChampionPoints = GetUnitChampionPoints
--d("got here1")
            --d("originalBuildMasterList")
            originalBuildMasterList(...)
--d("got here2")
            -- do something after it
            --Change the CP effective to the original CP effective function
            GetUnitEffectiveChampionPoints = cpFuncEffective
--d("got here3")
        end)
        --Execute the BuildList funciton once now?
        if runItOnce and GROUP_LIST_MANAGER.BuildMasterList ~= nil then
--d("running wrapper function once!")
            GROUP_LIST_MANAGER:BuildMasterList()
        end
    end
end

--========= GROUP LIST ==========================================================
function FCOChangeStuff.CPStuff()
    if FCOChangeStuff.settingsVars.settings.showRealCPs then
--d("settings CP activated")
        --Overwrite the CP display function which only allows currently 561 max CPs
        FCOChangeStuff.hookChampionRankUtils()
        local runOnce = (FCOChangeStuff.runGroupListCounter == 0)
--d("RunOnce: " .. tostring(runOnce) .. ", counter: " .. tostring(FCOChangeStuff.runGroupListCounter))
        FCOChangeStuff.hookGroupList(runOnce)
        --GetUnitEffectiveChampionPoints = GetUnitChampionPoints
    else
        --Change back to original functios
        GetLevelOrChampionPointsStringNoIcon    = FCOChangeStuff.originalCPFunc
        GetUnitEffectiveChampionPoints          = FCOChangeStuff.originalUnitCPEffectiveFunc
        GetUnitChampionPoints                   = FCOChangeStuff.originalUnitCPFunc
    end
end



--========= GROUP ELECTION ==========================================================
local eventGroupElectionsWasAdded = false
function FCOChangeStuff.GroupElectionStuff()
    if eventGroupElectionsWasAdded == true then return end
--[[
    EM:RegisterForEvent(FCOCS.addonVars.addonName .. "_GroupElection", EVENT_GROUP_ELECTION_REQUESTED,
            function(_, descriptor)
d("[FCOCS]GroupElection, descriptor: " ..tostring(descriptor) .. "/"..tostring(ZO_GROUP_ELECTION_DESCRIPTORS.READY_CHECK) .. ", settings: " ..tostring(FCOChangeStuff.settingsVars.settings.autoDeclineGroupElections))
                if not FCOChangeStuff.settingsVars.settings.autoDeclineGroupElections then return end
                --Do not abort elections if you are in a trial / dungeon
                if IsInCyrodiil() or IsInImperialCity() or IsUnitInDungeon(playerTag) or IsPlayerInRaid() then return end
                if descriptor == ZO_GROUP_ELECTION_DESCRIPTORS.READY_CHECK then
                    CastGroupVote(GROUP_VOTE_CHOICE_AGAINST)
                end
            end
    )
]]
    EM:RegisterForEvent(FCOChangeStuff.addonVars.addonName .. "_GroupElection", EVENT_GROUP_ELECTION_NOTIFICATION_ADDED, function()
        if not FCOChangeStuff.settingsVars.settings.autoDeclineGroupElections then return end
        --Do not abort elections if you are in a trial / dungeon
        if IsInCyrodiil() or IsInImperialCity() or IsUnitInDungeon(playerTag) or IsPlayerInRaid() then return end
        local groupElectionType, timeRemainingSeconds, electionDescriptor, targetUnitTag = GetGroupElectionInfo()
--d("[FCOCS]GroupElection, descriptor: " ..tostring(electionDescriptor) .. "/"..tostring(ZO_GROUP_ELECTION_DESCRIPTORS.READY_CHECK) .. ", settings: " ..tostring(FCOChangeStuff.settingsVars.settings.autoDeclineGroupElections))
        if electionDescriptor == ZO_GROUP_ELECTION_DESCRIPTORS.READY_CHECK then
            CastGroupVote(GROUP_VOTE_CHOICE_AGAINST)
        end
    end)
end


function FCOChangeStuff.toggleGroupElectionAutoDecline()
    FCOChangeStuff.settingsVars.settings.autoDeclineGroupElections = not FCOChangeStuff.settingsVars.settings.autoDeclineGroupElections
end
