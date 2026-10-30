local O=ObsidianHUD
-- Timer tracking uses slot/effect events without changing game settings.
-- SetSetting is protected on console and must not run from HUD callbacks.

-- Resolve the ability represented by a slot, rather than treating a crafted
-- ability's grimoire ID as an ordinary ability/effect ID.
function O.GetSkillAbilityId(slot,bar)
    local id=GetSlotBoundId(slot,bar)
    id=tonumber(id) or 0
    if id<=0 then return 0 end
    if ACTION_TYPE_CRAFTED_ABILITY and GetSlotType and GetAbilityIdForCraftedAbilityId
        and GetSlotType(slot,bar)==ACTION_TYPE_CRAFTED_ABILITY then
        local resolved=GetAbilityIdForCraftedAbilityId(id)
        id=tonumber(resolved) or 0
    end
    return id>0 and id or 0
end
