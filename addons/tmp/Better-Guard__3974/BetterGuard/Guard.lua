BetterGuardAddon = BetterGuardAddon or {}
local BG = BetterGuardAddon

local characterName = GetRawUnitName("player")

function BG.GuardGained(_, _, _, _, _, _, sourceName, unitType, targetName, ...)
    if unitType == COMBAT_UNIT_TYPE_GROUP or unitType == COMBAT_UNIT_TYPE_PLAYER then
        local sourceGroupMember = BG.groupMembers[sourceName]
        local targetGroupMember = BG.groupMembers[targetName]
        if not sourceGroupMember or not targetGroupMember then return end
        if sourceGroupMember and targetGroupMember and
        ((sourceName == characterName) or (targetName == characterName and BG.savedVariables.showGuardOnYou)) then
            BG.DrawLineBetweenPlayers(sourceGroupMember, targetGroupMember)
        end
    elseif COMBAT_UNIT_TYPE_PLAYER_COMPANION and GetGroupSize() == 0 then
        if sourceName == characterName then
            BG.DrawLineBetweenPlayers("player", "companion")
        end
    end
end

function BG.GuardLost(...)
    BG.RemoveLine()
    BG.unitTag1 = ""
    BG.unitTag2 = ""
end