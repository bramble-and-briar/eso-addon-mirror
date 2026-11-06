-- HideResearchableIcon
-- Hides the "can be researched" magnifier icon by filtering it at the icon lookup level.
-- Returning nil is safe: ZO_MultiIcon:AddIcon(nil) is a no-op, so no icon is shown.
-- No item data is modified, so research warnings and other addons keep working.
-- Other trait icons (ornate / intricate / retraited / reconstructed) are untouched.

HideResearchableIcon = HideResearchableIcon or {}
local HRI = HideResearchableIcon

-- must match the addon folder / manifest name exactly (EVENT_ADD_ON_LOADED passes the folder name)
HRI.name = "HideResearchableIcon"
HRI.version = "1.1.2"

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
