local CMA = CraftMaterialAssistant

-- Core Vendor Liquidation Routine
function CMA:OnStoreOpen()
    if not self.db.enableAddon or not self.db.autoSellJunk then return end

    if self.db.showVendorAlerts then
        local vendoredItems = {}
        local totalGoldEarned = 0
        for i = 1, #self.junkedIds do
            local bagid, slotIndex = self:findItemByUniqueId(self.sourceBag, self.junkedIds[i])
            -- if bagid ~= nil and slotIndex ~= nil then
            local _, stackCount = GetItemInfo(bagid, slotIndex)
            if stackCount > 0 then
                local itemLink = GetItemLink(bagid, slotIndex)
                local sellPrice = GetItemSellValueWithBonuses(bagid, slotIndex)
                local itemTotalGold = sellPrice * stackCount

                totalGoldEarned = totalGoldEarned + itemTotalGold
                table.insert(vendoredItems, itemLink .. " (" .. itemTotalGold .. "g)")
                SellInventoryItem(bagid, slotIndex, stackCount)
            end
            -- end
        end
        if totalGoldEarned > 0 then
            self:SendChatMessage("|cFF0000Vendored materials for " .. tostring(totalGoldEarned) .. "g|r")
            self:SendChatMessageLimitedItemCount("|cFFEE00Sold items:|r ", vendoredItems)
        end
    end
    SellAllJunk()
    self.junkedItems = {}
    self.junkedIds = {}
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.ITEM_GOLD_CHANGED, "CMA: Sold filtered materials.")
end