ZO_CreateStringId("SI_BINDING_NAME_SHOW_TOOLTIP", "Show Tooltip")

local function AddShowTooltip(inventorySlot, slotActions)

    local valid = ZO_Inventory_GetBagAndIndex(inventorySlot)

    if not valid then
        return
    end

    slotActions:AddCustomSlotAction(
        SI_BINDING_NAME_SHOW_TOOLTIP,
        function()

            local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
            local itemLink = GetItemLink(bagId, slotIndex)

            ZO_PopupTooltip_SetLink(itemLink)

        end,
        ""
    )
end

LibCustomMenu:RegisterContextMenu(
    AddShowTooltip,
    LibCustomMenu.CATEGORY_LATE
)