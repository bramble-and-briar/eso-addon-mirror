local O=ObsidianHUD
-- Timer tracking uses slot/effect events without changing game settings.
-- SetSetting is protected on console and must not run from HUD callbacks.

function O.ResolveStaffSkillId(id,bar)
    local family=O.wallStaffSkills and O.wallStaffSkills[id]
    if not family or not GetItemLink or not GetItemLinkWeaponType or not BAG_WORN then return id end
    local equip=bar==HOTBAR_CATEGORY_PRIMARY and EQUIP_SLOT_MAIN_HAND
        or bar==HOTBAR_CATEGORY_BACKUP and EQUIP_SLOT_BACKUP_MAIN
    if not equip then return id end
    -- Read the staff equipped on THIS bar, never the currently active weapon.
    local weapon=GetItemLinkWeaponType(GetItemLink(BAG_WORN,equip,LINK_STYLE_DEFAULT or 0))
    if WEAPONTYPE_FIRE_STAFF and weapon==WEAPONTYPE_FIRE_STAFF then return family[2] end
    if WEAPONTYPE_LIGHTNING_STAFF and weapon==WEAPONTYPE_LIGHTNING_STAFF then return family[3] end
    if WEAPONTYPE_FROST_STAFF and weapon==WEAPONTYPE_FROST_STAFF then return family[4] end
    return id
end

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
    return id>0 and O.ResolveStaffSkillId(id,bar) or 0
end
