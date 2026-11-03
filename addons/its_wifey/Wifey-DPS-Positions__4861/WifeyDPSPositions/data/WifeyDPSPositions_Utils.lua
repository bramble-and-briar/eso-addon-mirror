-- WifeyDPSPositions_Utils.lua
WifeyDPSPositions = WifeyDPSPositions or {}
local DDP = WifeyDPSPositions

function DDP.msg(text)
    d(string.format("::[WifeyDPSPositions]:: %s", tostring(text)))
end

function DDP.NormalizeName(name)
    return name and zo_strformat("<<1>>", name) or nil
end

function DDP.PrintName(name)
    return (not name or name == "@Missing") and "@Missing" or name
end

function DDP.GetUnitTagByName(name)
    if not name then return nil end
    for i = 1, (GROUP_SIZE_MAX or 24) do
        local unitTag = GetGroupUnitTagByIndex(i)
        if unitTag and DoesUnitExist(unitTag) then
            local unitName = zo_strformat("<<1>>", GetUnitDisplayName(unitTag))
            if unitName == name then
                return unitTag
            end
        end
    end
    return nil
end

function DDP.GetUnitRole(unitTag)
    if not unitTag or not DoesUnitExist(unitTag) then return nil end
    return GetGroupMemberAssignedRole(unitTag)
end

function DDP.IsUnitDPS(unitTag)
    return DDP.GetUnitRole(unitTag) == LFG_ROLE_DPS
end

function DDP.GetHealersInGroup()
    local healers = {}
    for i = 1, (GROUP_SIZE_MAX or 24) do
        local unitTag = GetGroupUnitTagByIndex(i)
        if unitTag and DoesUnitExist(unitTag) and DDP.GetUnitRole(unitTag) == LFG_ROLE_HEAL then
            local name = zo_strformat("<<1>>", GetUnitDisplayName(unitTag))
            table.insert(healers, name)
        end
    end
    return healers
end

function DDP.ShuffleTable(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end
