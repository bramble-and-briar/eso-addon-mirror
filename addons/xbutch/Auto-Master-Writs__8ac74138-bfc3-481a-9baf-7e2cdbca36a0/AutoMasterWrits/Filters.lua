local AMW = AutoMasterWrits

function AMW:FilterReason(record)
    if record.unsupported then return "Unsupported or unreadable master writ" end
    if self.saved.manualDeferred[record.uid] then return "Manually deferred" end
    local craft, trait = record.craft, record.trait
    if self.saved.filterNirnhoned and (
        craft == CRAFTING_TYPE_BLACKSMITHING or craft == CRAFTING_TYPE_CLOTHIER
        or craft == CRAFTING_TYPE_WOODWORKING) then
        if trait == ITEM_TRAIT_TYPE_ARMOR_NIRNHONED or trait == ITEM_TRAIT_TYPE_WEAPON_NIRNHONED then
            return "Nirnhoned equipment"
        end
    end
    if self.saved.filterEpicJewelry and craft == CRAFTING_TYPE_JEWELRYCRAFTING
        and record.quality == ITEM_FUNCTIONAL_QUALITY_ARTIFACT
        and (trait == ITEM_TRAIT_TYPE_JEWELRY_INFUSED or trait == ITEM_TRAIT_TYPE_JEWELRY_HARMONY) then
        return "Epic Infused or Harmony jewelry"
    end
    -- No material-cost rules have been agreed for the three consumable crafts.
    return nil
end

