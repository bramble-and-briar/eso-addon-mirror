local origTraitIcon = ZO_GetPlatformTraitInformationIcon
function ZO_GetPlatformTraitInformationIcon(traitInformation)
    if traitInformation == ITEM_TRAIT_INFORMATION_CAN_BE_RESEARCHED then
        return nil
    end
    return origTraitIcon(traitInformation)
end

local origSellIcon = ZO_GetItemSellInformationIcon
function ZO_GetItemSellInformationIcon(sellInformation)
    if sellInformation == ITEM_SELL_INFORMATION_CAN_BE_RESEARCHED then
        return nil
    end
    return origSellIcon(sellInformation)
end
