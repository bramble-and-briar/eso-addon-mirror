-- WifeyDPSPositions_Core.lua
WifeyDPSPositions = WifeyDPSPositions or {}
local DDP = WifeyDPSPositions

DDP.SV = nil
DDP.savedAssignments = nil

local function buildAssignmentMessage(mechObjects)
    local parts = {}
    for _, obj in ipairs(mechObjects or {}) do
        local position = obj.position or "?"
        local playerName = DDP.PrintName and DDP.PrintName(obj.name or "@Missing") or (obj.name or "@Missing")
        table.insert(parts, string.format("%s: %s", position, playerName))
    end
    return "DPS Positions | " .. table.concat(parts, " | ")
end

local function getCurrentDPS()
    local dpsMap = {}
    for i = 1, (GROUP_SIZE_MAX or 24) do
        local unitTag = GetGroupUnitTagByIndex(i)
        if unitTag and DoesUnitExist(unitTag) and not IsUnitDead(unitTag) and DDP.IsUnitDPS(unitTag) then
            local name = DDP.NormalizeName(GetUnitDisplayName(unitTag))
            if name then dpsMap[name] = unitTag end
        end
    end
    return dpsMap
end

local function ensureAssignments(zoneId, mechKey, mechPositions)
    DDP.savedAssignments = DDP.savedAssignments or {}
    DDP.savedAssignments[zoneId] = DDP.savedAssignments[zoneId] or {}

    local mechObjects = DDP.savedAssignments[zoneId][mechKey]
    if not mechObjects then
        mechObjects = {}
        for i, pos in ipairs(mechPositions) do
            mechObjects[i] = { name = "@Missing", position = pos, override = false }
        end
        DDP.savedAssignments[zoneId][mechKey] = mechObjects
        return mechObjects
    end

    -- Keep SavedVariables in sync when a mechanic gains/loses slots.
    for i = #mechObjects, #mechPositions + 1, -1 do
        table.remove(mechObjects, i)
    end

    for i, pos in ipairs(mechPositions) do
        if not mechObjects[i] then
            mechObjects[i] = { name = "@Missing", position = pos, override = false }
        else
            mechObjects[i].position = pos
            if not mechObjects[i].name then mechObjects[i].name = "@Missing" end
            if mechObjects[i].override == nil then mechObjects[i].override = false end
        end
    end

    DDP.savedAssignments[zoneId][mechKey] = mechObjects
    return mechObjects
end


local function getCurrentGroupByRole()
    local tanks, heals, dps = {}, {}, {}
    local pools = {[LFG_ROLE_TANK]=tanks, [LFG_ROLE_HEAL]=heals, [LFG_ROLE_DPS]=dps}
    local seen = {}
    for i=1,GetGroupSize() do
        local tag=GetGroupUnitTagByIndex(i)
        if tag and DoesUnitExist(tag) then
            local name=DDP.NormalizeName(GetUnitDisplayName(tag))
            local role=GetGroupMemberSelectedRole and GetGroupMemberSelectedRole(tag)
            if not pools[role] then role=DDP.GetUnitRole(tag) end
            if name and not seen[name] then
                seen[name]=true
                if pools[role] then table.insert(pools[role],name)
                else DDP.msg("Set a group role for "..name.." or assign them manually; unknown role is not assumed tank.") end
            end
        end
    end
    table.sort(tanks); table.sort(heals); table.sort(dps)
    return tanks, heals, dps
end

-- Generic RTT -> Wifey DPS bridge for committed assignment PUSHes.
-- The receiver keeps this addon's own mechanic labels and copies the committed names by slot.
function DDP.ReceiveSharedAssignments(zoneId, mechKey, slots)
    zoneId = tonumber(zoneId)
    if not zoneId or type(mechKey) ~= "string" or type(slots) ~= "table" then return false end
    local zoneData = DDP.positions and DDP.positions[zoneId]
    local labels = zoneData and zoneData.mechanics and zoneData.mechanics[mechKey]
    if type(labels) ~= "table" then return false end
    DDP.savedAssignments = DDP.savedAssignments or {}
    DDP.savedAssignments[zoneId] = DDP.savedAssignments[zoneId] or {}
    local previous=DDP.savedAssignments[zoneId][mechKey] or {}
    local board = {}
    for i, label in ipairs(labels) do
        local src = slots[i]
        board[i] = {
            name = (type(src)=="table" and src.name) or "@Missing",
            position = label,
            manualEmpty = not (type(src)=="table" and src.name and src.name~="@Missing") or nil,
            override = false,
        }
    end
    if zoneId==1548 and mechKey=="HM CURSE" then
        for i,row in ipairs(board) do
            local old=previous[i]
            row.override=false
        end
    end
    DDP.savedAssignments[zoneId][mechKey] = board
    if DDP.SV then DDP.SV.savedAssignments = DDP.savedAssignments end
    if zoneId == 1548 and mechKey == "HM CURSE" and DDP.SyncVOCHMPortals then DDP.SyncVOCHMPortals() end
    if DDP.UI and DDP.UI.MarkDirty then DDP.UI:MarkDirty() end
    if DDP.UI and DDP.UI.RefreshAssignments then DDP.UI:RefreshAssignments() end
    if DDP.UI and DDP.UI.Refresh then DDP.UI:Refresh() end
    return true
end

-- HM CURSE owns the roster. HM PORTALS is always rebuilt from it:
-- Tank + Curse 1/2 -> Dragon; Healer + Curse 3/4 -> Channeler.
-- RCRT -> Wifey DPS Positions bridge.
-- A committed HM CURSE push from RTT replaces this addon's local HM CURSE board.
function DDP.ReceiveVOCHMCurseAssignments(slots)
    return DDP.ReceiveSharedAssignments(1548, "HM CURSE", slots)
end

function DDP.SyncVOCHMPortals()
    local z = DDP.savedAssignments and DDP.savedAssignments[1548]
    local curse = z and z["HM CURSE"]
    if not curse or #curse < 12 then return nil end
    local pp = DDP.positions[1548].mechanics["HM PORTALS"]
    local portals = ensureAssignments(1548, "HM PORTALS", pp)
    local source = {1,3,4, 2,5,6, 7,9,10, 8,11,12}
    for i, src in ipairs(source) do
        portals[i].name = curse[src].name or "@Missing"
        portals[i].override = false
    end
    DDP.savedAssignments[1548]["HM PORTALS"] = portals
    if DDP.SV then DDP.SV.savedAssignments = DDP.savedAssignments end
    return portals
end

local function assignVOCHMCurse(mechObjects,keepOverrides,fillOnly)
    local tanks,heals,dps=getCurrentGroupByRole()
    local pools={tanks,heals,dps}
    local roleAt={1,2,3,3,3,3,1,2,3,3,3,3}
    local live,used,keep={},{},{}
    for _,pool in ipairs(pools) do for _,name in ipairs(pool) do live[name]=true end end
    -- Preserve eligible existing assignments during fill-only operations.
    for i=1,GetGroupSize() do
        local tag=GetGroupUnitTagByIndex(i)
        if tag and DoesUnitExist(tag) then live[DDP.NormalizeName(GetUnitDisplayName(tag))]=true end
    end
    for i,obj in ipairs(mechObjects) do
        if live[obj.name] and not used[obj.name] and (fillOnly or (keepOverrides and obj.override)) then
            keep[i]=true; used[obj.name]=true
        end
    end
    for _,pool in ipairs(pools) do
        for i=#pool,1,-1 do if used[pool[i]] then table.remove(pool,i) end end
        DDP.ShuffleTable(pool)
    end
    for i=1,12 do
        local obj=mechObjects[i]
        if not keep[i] then obj.name=table.remove(pools[roleAt[i]],1) or "@Missing"; obj.override=false end
        obj.manualEmpty=nil
    end
    DDP.SyncVOCHMPortals()
    if DDP.SV then DDP.SV.savedAssignments=DDP.savedAssignments end
    return buildAssignmentMessage(mechObjects)
end

function DDP.AssignToPositions(zoneId, mechKey, mechPositions)
    if GetGroupSize() == 0 then return end

    local mechObjects = ensureAssignments(zoneId, mechKey, mechPositions)

    if zoneId == 1548 and mechKey == "HM CURSE" then
        -- Preserve a complete existing HM board; only auto-build when it is empty.
        local hasAny,explicitEmpty = false,false
        for _,obj in ipairs(mechObjects) do
            if obj.name and obj.name~="@Missing" then hasAny=true end
            if obj.manualEmpty then explicitEmpty=true end
        end
        if not hasAny and not explicitEmpty then return assignVOCHMCurse(mechObjects,true,false) end
        DDP.SyncVOCHMPortals()
        return buildAssignmentMessage(mechObjects)
    elseif zoneId == 1548 and mechKey == "HM PORTALS" then
        DDP.SyncVOCHMPortals()
        return buildAssignmentMessage(DDP.savedAssignments[1548]["HM PORTALS"])
    end

    local dpsMap = getCurrentDPS()

    -- Ossein Cage Portal: exactly five DPS plus one healer.
    if zoneId == 1548 and mechKey == "Portal" then
        local dpsNames = {}
        for name in pairs(dpsMap) do table.insert(dpsNames, name) end
        table.sort(dpsNames)
        for i = 1, 5 do
            mechObjects[i].name = dpsNames[i] or "@Missing"
            mechObjects[i].override = false
        end
        local healerName = nil
        for i = 1, (GROUP_SIZE_MAX or 24) do
            local unitTag = GetGroupUnitTagByIndex(i)
            if unitTag and DoesUnitExist(unitTag) and not IsUnitDead(unitTag) and DDP.GetUnitRole(unitTag) == LFG_ROLE_HEAL then
                healerName = DDP.NormalizeName(GetUnitDisplayName(unitTag))
                if healerName then break end
            end
        end
        mechObjects[6].name = healerName or "@Missing"
        mechObjects[6].override = false
        DDP.savedAssignments[zoneId][mechKey] = mechObjects
        if DDP.SV then DDP.SV.savedAssignments = DDP.savedAssignments end
        return buildAssignmentMessage(mechObjects)
    end

    for _, obj in ipairs(mechObjects) do
        if obj.name ~= "@Missing" then
            local stillInGroup = dpsMap[obj.name]
            if not stillInGroup then
                obj.name = "@Missing"
                obj.override = false
            end
        end
    end

    local unassigned = {}
    for name in pairs(dpsMap) do
        local alreadyAssigned = false
        for _, obj in ipairs(mechObjects) do
            if obj.name == name then
                alreadyAssigned = true
                break
            end
        end
        if not alreadyAssigned then
            table.insert(unassigned, name)
        end
    end

    for _, obj in ipairs(mechObjects) do
        if (obj.name == "@Missing" or obj.name == nil) and (not obj.override) and #unassigned > 0 then
            obj.name = table.remove(unassigned, 1)
        end
    end
	
	local seen = {}
	for _, obj in ipairs(mechObjects) do
		if obj.name ~= "@Missing" then
			if seen[obj.name] then
				DDP.msg("Duplicate found: " .. obj.name .. " (auto-cleared from one slot)")
				obj.name = "@Missing"
				obj.override = false
			else
				seen[obj.name] = true
			end
		end
	end

    DDP.savedAssignments[zoneId] = DDP.savedAssignments[zoneId] or {}
    DDP.savedAssignments[zoneId][mechKey] = mechObjects
    DDP.SV.savedAssignments = DDP.savedAssignments

    return buildAssignmentMessage(mechObjects)
end

function DDP.PrintCurrentAssignments(zoneId, mechKey)
    if not zoneId or not mechKey then return end
    local savedZone = DDP.savedAssignments[zoneId]
    if not savedZone or not savedZone[mechKey] then return end

    local mechObjects = savedZone[mechKey]
    StartChatInput(buildAssignmentMessage(mechObjects), CHAT_CHANNEL_PARTY)
end

function DDP.ClearOverride(zoneId, mechKey, positionIndex)
    if zoneId==1548 and mechKey=="HM PORTALS" then return false end
    local zoneData = DDP.positions[zoneId]
    if not zoneData or not zoneData.mechanics[mechKey] then return end
    local mechObjects = ensureAssignments(zoneId, mechKey, zoneData.mechanics[mechKey])
    local slot = mechObjects[positionIndex]
    if not slot then return end
    slot.override = false
    DDP.SV.savedAssignments = DDP.savedAssignments
    if DDP.UI and DDP.UI.PopulateMechanicList then
        DDP.UI:PopulateMechanicList()
    end
end


function DDP.SendNativeAssignmentPopup(mechName, message)
    if GetGroupSize() == 0 then
        DDP.msg("Popup requires a group.")
        return
    end

    local popupText = tostring(mechName or "DPS POSITIONS") .. " | " .. tostring(message or "")
    local flags = GROUP_ELECTION_FLAGS_REQUIRE_ALL_VOTES + GROUP_ELECTION_FLAGS_IGNORE_OFFLINE_MEMBERS

    BeginGroupElection(
        GROUP_ELECTION_TYPE_GENERIC_UNANIMOUS,
        popupText,
        nil,
        flags
    )
end

function DDP.ForceAssignPlayerToPosition(zoneId, mechKey, positionIndex, playerName)
    if zoneId==1548 and mechKey=="HM PORTALS" then return false end
    if not zoneId or not mechKey or not positionIndex or not playerName then
        DDP.msg("Invalid force-assign arguments.")
        return
    end

    local zoneData = DDP.positions[zoneId]
    if not zoneData or not zoneData.mechanics[mechKey] then
        DDP.msg("Mechanic not found for manual assign.")
        return
    end

    DDP.savedAssignments = DDP.savedAssignments or {}
    DDP.savedAssignments[zoneId] = DDP.savedAssignments[zoneId] or {}

    local mechObjects = DDP.savedAssignments[zoneId][mechKey]
    if not mechObjects then
        mechObjects = {}
        for i, pos in ipairs(zoneData.mechanics[mechKey]) do
            mechObjects[i] = { name = "@Missing", position = pos, override = false }
        end
    end

    local normalizedName = DDP.NormalizeName(playerName)

    mechObjects[positionIndex] = mechObjects[positionIndex] or {}
    mechObjects[positionIndex].name = normalizedName
    mechObjects[positionIndex].position = zoneData.mechanics[mechKey][positionIndex]
    mechObjects[positionIndex].override = false

    DDP.savedAssignments[zoneId][mechKey] = mechObjects
    if DDP.SV then
        DDP.SV.savedAssignments = DDP.savedAssignments
    end

    DDP.msg(string.format("Force-assigned %s -> %s (%s)", normalizedName, zoneData.mechanics[mechKey][positionIndex], mechKey))

    if DDP.UI and DDP.UI.PopulateMechanicList then
        DDP.UI:PopulateMechanicList()
    end
end

function DDP.SetFreeAssignment(zoneId, playerName, mechKey, positionIndex)
    if not zoneId or not playerName or not mechKey or not positionIndex then
        DDP.msg("Invalid FreeAssignment args."); return
    end

    local zoneData = DDP.positions[zoneId]
    if not zoneData or not zoneData.mechanics[mechKey] then
        DDP.msg("Mechanic not found for FreeAssignment."); return
    end

    DDP.freeAssignments = DDP.freeAssignments or {}
    DDP.freeAssignments[zoneId] = DDP.freeAssignments[zoneId] or {}

    local positionLabel = zoneData.mechanics[mechKey][positionIndex]
    DDP.freeAssignments[zoneId][playerName] = {
        mechKey = mechKey,
        positionIndex = positionIndex,
        position = positionLabel,
    }

    if DDP.SV then DDP.SV.freeAssignments = DDP.freeAssignments end

    if DDP.UI and DDP.UI.PopulateFreeAssignments then
        DDP.UI:PopulateFreeAssignments(zoneId)
    end

    DDP.SendFreeAssignmentsToChat(zoneId)
end

function DDP.ClearFreeAssignment(zoneId, playerName)
    if not zoneId or not playerName then return end

    if DDP.freeAssignments and DDP.freeAssignments[zoneId] then
        DDP.freeAssignments[zoneId][playerName] = nil
        if DDP.SV then DDP.SV.freeAssignments = DDP.freeAssignments end
    end

    if DDP.UI and DDP.UI.PopulateFreeAssignments then
        DDP.UI:PopulateFreeAssignments(zoneId)
    end

    DDP.SendFreeAssignmentsToChat(zoneId)
end

function DDP.SendFreeAssignmentsToChat(zoneId)
    if not zoneId then return end
    local zoneData = DDP.positions[zoneId]
    local freeZone = DDP.freeAssignments and DDP.freeAssignments[zoneId]
    if not freeZone or not next(freeZone) then return end

    local parts = {}
    for playerName, data in pairs(freeZone) do
        table.insert(parts, string.format("%s: %s", data.position or "?", playerName or "@Missing"))
    end

    local fullMessage = "DPS Positions | " .. table.concat(parts, " | ")
    StartChatInput(fullMessage, CHAT_CHANNEL_PARTY)
end



-- v1.1 host-console helpers. These actions edit locally until SEND/RESEND.
function DDP.BuildAssignmentMessage(mechObjects)
    return buildAssignmentMessage(mechObjects)
end

function DDP.ShuffleAllAssignments(zoneId, mechKey, mechPositions, keepOverrides)
    keepOverrides = false -- All assignments are unlocked.
    if GetGroupSize() == 0 then return end
    if zoneId==1548 and mechKey=="HM CURSE" then
        return assignVOCHMCurse(ensureAssignments(zoneId,mechKey,mechPositions),keepOverrides,false)
    elseif zoneId==1548 and mechKey=="HM PORTALS" then
        return buildAssignmentMessage(DDP.SyncVOCHMPortals() or {})
    end

    -- Ossein Cage Portal always stays five DPS + one healer, including REROLL.
    if zoneId == 1548 and mechKey == "Portal" then
        local mechObjects = ensureAssignments(zoneId, mechKey, mechPositions)
        local dpsMap = getCurrentDPS()
        local dpsNames = {}
        for name in pairs(dpsMap) do table.insert(dpsNames, name) end
        DDP.ShuffleTable(dpsNames)
        for i = 1, 5 do
            mechObjects[i].name = dpsNames[i] or "@Missing"
            mechObjects[i].override = false
        end
        local healers = {}
        for i = 1, (GROUP_SIZE_MAX or 24) do
            local unitTag = GetGroupUnitTagByIndex(i)
            if unitTag and DoesUnitExist(unitTag) and not IsUnitDead(unitTag) and DDP.GetUnitRole(unitTag) == LFG_ROLE_HEAL then
                local name = DDP.NormalizeName(GetUnitDisplayName(unitTag))
                if name then table.insert(healers, name) end
            end
        end
        DDP.ShuffleTable(healers)
        mechObjects[6].name = healers[1] or "@Missing"
        mechObjects[6].override = false
        DDP.savedAssignments[zoneId][mechKey] = mechObjects
        if DDP.SV then DDP.SV.savedAssignments = DDP.savedAssignments end
        return buildAssignmentMessage(mechObjects)
    end

    local dpsMap = getCurrentDPS()
    local mechObjects = ensureAssignments(zoneId, mechKey, mechPositions)
    local reserved = {}
    if keepOverrides then
        for _, obj in ipairs(mechObjects) do
            if obj.override and obj.name and obj.name ~= "@Missing" and dpsMap[obj.name] then
                reserved[obj.name] = true
            end
        end
    end
    local pool = {}
    for name in pairs(dpsMap) do
        if not reserved[name] then table.insert(pool, name) end
    end
    DDP.ShuffleTable(pool)
    local idx = 1
    for i, pos in ipairs(mechPositions) do
        local obj = mechObjects[i] or {position = pos, name = "@Missing", override = false}
        obj.position = pos
        if not (keepOverrides and obj.override and obj.name ~= "@Missing" and dpsMap[obj.name]) then
            obj.name = pool[idx] or "@Missing"
            obj.override = false
            idx = idx + 1
        end
        mechObjects[i] = obj
    end
    DDP.savedAssignments[zoneId][mechKey] = mechObjects
    if DDP.SV then DDP.SV.savedAssignments = DDP.savedAssignments end
    return buildAssignmentMessage(mechObjects)
end

function DDP.SwapAssignments(zoneId, mechKey, firstIndex, secondIndex)
    if zoneId==1548 and mechKey=="HM PORTALS" then return false end
    local zoneData = DDP.positions[zoneId]
    if not zoneData or not zoneData.mechanics[mechKey] then return false end
    local objs = ensureAssignments(zoneId, mechKey, zoneData.mechanics[mechKey])
    if not objs[firstIndex] or not objs[secondIndex] then return false end
    objs[firstIndex].name, objs[secondIndex].name = objs[secondIndex].name, objs[firstIndex].name
    objs[firstIndex].override, objs[secondIndex].override = objs[secondIndex].override, objs[firstIndex].override
    if zoneId==1548 and mechKey=="HM CURSE" then DDP.SyncVOCHMPortals() end
    if DDP.SV then DDP.SV.savedAssignments = DDP.savedAssignments end
    return true
end

function DDP.FillEmptyAssignments(zoneId, mechKey, mechPositions)
    if zoneId==1548 and mechKey=="HM CURSE" then
        return assignVOCHMCurse(ensureAssignments(zoneId,mechKey,mechPositions),true,true)
    end
    return DDP.AssignToPositions(zoneId, mechKey, mechPositions)
end

function DDP.ResetMechanic(zoneId, mechKey, mechPositions)
    if zoneId==1548 and mechKey=="HM PORTALS" then return false end
    DDP.savedAssignments = DDP.savedAssignments or {}
    DDP.savedAssignments[zoneId] = DDP.savedAssignments[zoneId] or {}
    local objs = {}
    for i, pos in ipairs(mechPositions or {}) do
        objs[i] = {name = "@Missing", position = pos, override = false, manualEmpty = true}
    end
    DDP.savedAssignments[zoneId][mechKey] = objs
    if DDP.SV then DDP.SV.savedAssignments = DDP.savedAssignments end
    if zoneId==1548 and mechKey=="HM CURSE" then DDP.SyncVOCHMPortals() end
    return objs
end

function DDP.SendAssignments(zoneId, mechKey)
    if zoneId == 1548 and (mechKey == "HM CURSE" or mechKey == "HM PORTALS") then
        DDP.SyncVOCHMPortals()
    end
    local savedZone = DDP.savedAssignments and DDP.savedAssignments[zoneId]
    local objs = savedZone and savedZone[mechKey]
    if not objs then
        DDP.msg("Nothing assigned yet.")
        return false
    end
    local message = buildAssignmentMessage(objs)
    DDP.SendNativeAssignmentPopup(mechKey, message)
    StartChatInput(message, CHAT_CHANNEL_PARTY)

    -- vLC Mirrors stays on the proven protocol-183 path. DO NOT change it.
    if zoneId == 1478 and mechKey == "Mirrors" then
        local rt = RyticTank
        local lc = rt and rt.Trials and rt.Trials.vLC
        if lc and lc.BroadcastMirrorAssignments then
            local ok = lc.BroadcastMirrorAssignments(objs)
            if ok then DDP.msg("RTT mirror sync queued from Wifey DPS Positions.")
            else DDP.msg("RTT mirror sync was NOT queued.") end
        else
            DDP.msg("RTT mirror bridge unavailable on this client.")
        end
    else
        -- Every other supported assignment board uses RTT's shared assignment transport.
        -- HM PORTALS is derived, so SEND its authoritative HM CURSE source board instead.
        local sendMech, sendObjs = mechKey, objs
        if zoneId == 1548 and mechKey == "HM PORTALS" then
            sendMech = "HM CURSE"
            sendObjs = savedZone and savedZone["HM CURSE"]
        end
        local rt = RyticTank
        local oc = rt and rt.Trials and rt.Trials.vOC
        if oc and oc.BroadcastAssignments and sendObjs then
            local ok = oc.BroadcastAssignments(zoneId, sendMech, sendObjs)
            if ok then DDP.msg("RTT assignment sync queued from Wifey DPS Positions.")
            else DDP.msg("RTT assignment sync was NOT queued.") end
        else
            DDP.msg("RTT shared assignment bridge unavailable on this client.")
        end
    end
    return true
end

-- Manual reassignment is now local; SEND/RESEND controls broadcasting.
function DDP.OverrideAssignment(zoneId, mechKey, positionIndex, playerName, makePersistent)
    if zoneId==1548 and mechKey=="HM PORTALS" then return false end
    if not zoneId or not mechKey or not positionIndex or not playerName then return end
    local zoneData = DDP.positions[zoneId]
    if not zoneData or not zoneData.mechanics[mechKey] then return end
    local objs = ensureAssignments(zoneId, mechKey, zoneData.mechanics[mechKey])
    local normalized = DDP.NormalizeName(playerName)
    local oldIndex
    for i, obj in ipairs(objs) do if obj.name == normalized then oldIndex = i break end end
    local target = objs[positionIndex]
    if not target then return false end
    local displaced = target.name
    if oldIndex and oldIndex ~= positionIndex then
        objs[oldIndex].name = displaced
        objs[oldIndex].override = false
    end
    target.manualEmpty=nil
    target.name = normalized
    target.override = false
    if DDP.SV then DDP.SV.savedAssignments = DDP.savedAssignments end
    if DDP.UI and DDP.UI.MarkDirty then DDP.UI:MarkDirty() end
    if DDP.UI and DDP.UI.RefreshAssignments then DDP.UI:RefreshAssignments() end
end

-- Selecting a mechanic prepares it locally; it no longer broadcasts immediately.
function DDP.AssignSpecificMechanic(zoneId, mechName)
    local zoneData = DDP.positions[zoneId]
    if not zoneData or not zoneData.mechanics[mechName] then return end
    DDP.AssignToPositions(zoneId, mechName, zoneData.mechanics[mechName])
    DDP.lastMechanicShown = mechName
    if DDP.UI and DDP.UI.MarkDirty then DDP.UI:MarkDirty() end
    if DDP.UI and DDP.UI.Refresh then DDP.UI:Refresh() end
end
