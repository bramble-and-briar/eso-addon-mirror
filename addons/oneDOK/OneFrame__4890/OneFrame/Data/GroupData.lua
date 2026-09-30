local A = OneFrame
A.GroupData = {}
function A.GroupData:Members()
    local members = {}
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and DoesUnitExist(tag) then
            members[#members + 1] = { tag = tag, index = i,
                identity = GetUnitDisplayName(tag), role = GetGroupMemberSelectedRole(tag) }
        end
    end
    return members
end
function A.GroupData:IsPlayerFrame(frame)
    return frame and frame.unitTag and frame.unitTag:match("^group%d+$")
        and (frame.style == "ZO_GroupUnitFrame" or frame.style == "ZO_RaidUnitFrame")
end
