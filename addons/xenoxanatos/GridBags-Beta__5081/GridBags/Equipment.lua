-- Saved equipment is read-only planning context. No equip or transfer APIs here.
GridBagsEquipment = {}
local E = GridBagsEquipment

function E:SlotName(slot)
    return GetString(SI_EQUIPSLOT, slot)
end

function E:GetMatches(link, equipment, backup)
    local first, second = GetItemLinkComparisonEquipSlots(link)
    local function BarSlot(slot)
        if slot == EQUIP_SLOT_MAIN_HAND or slot == EQUIP_SLOT_BACKUP_MAIN then
            return backup and EQUIP_SLOT_BACKUP_MAIN or EQUIP_SLOT_MAIN_HAND
        elseif slot == EQUIP_SLOT_OFF_HAND or slot == EQUIP_SLOT_BACKUP_OFF then
            return backup and EQUIP_SLOT_BACKUP_OFF or EQUIP_SLOT_OFF_HAND
        elseif slot == EQUIP_SLOT_POISON or slot == EQUIP_SLOT_BACKUP_POISON then
            return backup and EQUIP_SLOT_BACKUP_POISON or EQUIP_SLOT_POISON
        end
        return slot
    end
    local result, seen = {}, {}
    for _, slot in ipairs({ first, second }) do
        slot = BarSlot(slot)
        if slot and slot ~= EQUIP_SLOT_NONE and not seen[slot] then
            seen[slot] = true
            local match = { slot = slot }
            for _, item in ipairs(equipment.items) do
                if item.equipSlot == slot then match.item = item; break end
            end
            result[#result + 1] = match
        end
    end
    return result
end

function E:Clear()
    for _, tooltip in ipairs(self.tooltips or {}) do ClearTooltip(tooltip) end
end

function E:Show(owner, cell)
    self:Clear()
    local record = owner.compareCharacter and GridBagsSnapshots.records[owner.compareCharacter]
    if not record or not record.equipment or not cell or cell:IsHidden() then return end
    local link = cell.snapshotItem and cell.snapshotItem.link
    if not link and cell.itemIdentity and cell.bagId and cell.slotIndex then
        if Id64ToString(GetItemUniqueId(cell.bagId, cell.slotIndex)) ~= cell.itemIdentity then return end
        link = GetItemLink(cell.bagId, cell.slotIndex)
    end
    if not link or link == "" then return end
    -- Replace native current-character comparison with explicitly labelled saved links.
    ItemTooltip:HideComparativeTooltips()
    local matches = self:GetMatches(link, record.equipment, owner.compareBackup)
    self.tooltips = self.tooltips or {}
    local anchor = ItemTooltip
    for i, match in ipairs(matches) do
        local tip = self.tooltips[i]
        if not tip then
            tip = WINDOW_MANAGER:CreateControlFromVirtual("GridBagsSavedComparison" .. i, GuiRoot, "ZO_ItemIconTooltip")
            tip:SetDrawTier(DT_HIGH)
            tip:SetMouseEnabled(false)
            tip:SetClampedToScreen(true)
            self.tooltips[i] = tip
        end
        tip:ClearAnchors()
        InitializeTooltip(tip, anchor, TOPRIGHT, -8, 0, TOPLEFT)
        if match.item then tip:SetLink(match.item.link) end
        tip:AddLine(record.name .. " | " .. self:SlotName(match.slot))
        tip:AddLine("Saved equipment: " .. GetDateStringFromTimestamp(record.equipment.updatedAt))
        tip:AddLine(match.item and "Item details use your current character's context." or "Empty when last observed")
        anchor = tip
    end
end

function E:Menu(owner, button)
    ClearMenu()
    local function Select(id)
        owner.compareCharacter = id
        ClearMenu()
        owner:Refresh()
    end
    AddMenuItem("Saved comparison: off", function() Select(nil) end)
    AddMenuItem("Weapons: " .. (owner.compareBackup and "backup bar" or "main bar") .. " (click to switch)", function()
        owner.compareBackup = not owner.compareBackup
        ClearMenu(); owner:Refresh()
    end)
    local entries = {}
    for id, record in pairs(GridBagsSnapshots.records) do
        if id ~= GridBagsSnapshots.characterId and record.equipment then
            entries[#entries + 1] = { id = id, name = record.name }
        end
    end
    table.sort(entries, function(a, b) return a.name < b.name end)
    for _, entry in ipairs(entries) do
        local id = entry.id
        AddMenuItem("Compare with " .. entry.name, function() Select(id) end)
    end
    if #entries == 0 then
        AddMenuItem("Log into another character to capture equipped gear", function() end)
    end
    ShowMenu(button)
end

function E:Initialize(owner)
    -- Only hook presentation functions. Keep all native slot action handlers intact.
    ZO_PostHook(_G, "ZO_InventorySlot_OnMouseEnter", function(cell)
        if cell and cell.row and cell.row.isGrid and owner:IsActive() and not owner.root:IsHidden() then
            self:Show(owner, cell)
        end
    end)
    ZO_PostHook(_G, "ZO_InventorySlot_OnMouseExit", function(cell)
        if cell and cell.row and cell.row.isGrid then self:Clear() end
    end)
end
