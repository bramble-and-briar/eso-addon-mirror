-- HideResearchIcon

HideResearchIcon = HideResearchIcon or {}
local HRI = HideResearchIcon

HRI.name = "HideResearchIcon"
HRI.version = "1.1.1"

local function Initialize()
    local origTraitIcon = ZO_GetPlatformTraitInformationIcon
    function ZO_GetPlatformTraitInformationIcon(traitInformation)
        if traitInformation == ITEM_TRAIT_INFORMATION_CAN_BE_RESEARCHED then
            return nil
        end
        return origTraitIcon(traitInformation)
    end

    -- gamepad store sell list adds the same magnifier via sellInformation
    local origSellIcon = ZO_GetItemSellInformationIcon
    function ZO_GetItemSellInformationIcon(sellInformation)
        if sellInformation == ITEM_SELL_INFORMATION_CAN_BE_RESEARCHED then
            return nil
        end
        return origSellIcon(sellInformation)
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= HRI.name then return end
    EVENT_MANAGER:UnregisterForEvent(HRI.name, EVENT_ADD_ON_LOADED)
    Initialize()
end

EVENT_MANAGER:RegisterForEvent(HRI.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
