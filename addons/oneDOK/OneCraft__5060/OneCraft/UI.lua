local O = OneCraft
local U = {}
O.UI = U

local function clearTooltip() ClearTooltip(InformationTooltip) end
function U.Create(module, station, fields, titleFor, rowsFor, choose, selectedFor, isCreation)
    local view = {module = module, station = station, fields = fields, rows = {}, isCreation = isCreation}
    local panel = WINDOW_MANAGER:CreateControl("OneCraft" .. module .. "Panel", station.control, CT_CONTROL)
    view.panel = panel
    panel:SetDimensions(500, 690)
    panel:SetAnchor(TOPRIGHT, station.control:GetNamedChild("Inventory"), TOPRIGHT, -15, 0)
    panel:SetHidden(true)
    for index, field in ipairs(fields) do
        local row = WINDOW_MANAGER:CreateControlFromVirtual("OneCraft" .. module .. "Row" .. index, panel, "ZO_SmithingHorizontalListTemplate")
        row:SetAnchor(TOP, panel, TOP, 0, 80 + (index - 1) * 127)
        row:GetNamedChild("Title"):SetText(titleFor(field))
        -- Retain the game's native row geometry, selection font and dividers.
        local selected = row:GetNamedChild("SelectedLabel")
        local list = ZO_HorizontalScrollList:New(row:GetNamedChild("List"), "ZO_SmithingListSlot", 5,
            function(control, data)
                control:GetNamedChild("Icon"):SetTexture(data.icon or O.noneTexture)
                control:GetNamedChild("StackCount"):SetText(data.count and tostring(data.count) or "")
                control:SetAlpha(data.available == false and 0.4 or 1)
                control:SetHandler("OnMouseEnter", function(c)
                    InitializeTooltip(InformationTooltip, c, RIGHT)
                    SetTooltipText(InformationTooltip, data.name)
                end)
                control:SetHandler("OnMouseExit", clearTooltip)
            end, function(a, b) return a.value == b.value end)
        list:SetScaleExtents(0.6, 1)
        local restoring, restoredValue
        list:SetOnTargetDataChangedCallback(function()
            -- A manual scroll takes over from a restored selection immediately.
            if not view.rebuilding then restoring = false end
        end)
        list:SetOnSelectedDataChangedCallback(function(data)
            if restoring then
                if not data or data.value ~= restoredValue then return end
                restoring = false
            end
            if data and not view.rebuilding and view.visible and not O[module].IsBusy() and selectedFor(field) ~= data.value then
                choose(field, data.value)
            end
        end)
        view.rows[index] = {control = row, list = list, selected = selected, field = field,
            restore = function(value) restoring, restoredValue = true, value end}
    end
    view.nativeContainer = station.control:GetNamedChild(module == "Alchemy" and "SlotContainer" or "RuneSlotContainer")
    view.spinner = view.nativeContainer:GetNamedChild("Spinner")
    view.hiddenControls = {station.control:GetNamedChild("Inventory")}

    function view:Refresh()
        if not self.visible then return end
        self.rebuilding = true
        for _, r in ipairs(self.rows) do
            local entries, chosenIndex = rowsFor(r.field), 1
            local value = selectedFor(r.field)
            for i, data in ipairs(entries) do
                if data.value == value then chosenIndex = i end
            end
            local sameOptions = r.entries and #r.entries == #entries
            if sameOptions then
                for i, data in ipairs(entries) do
                    if r.entries[i].value ~= data.value then sameOptions = false; break end
                end
            end
            if sameOptions then
                -- Keep native entry objects and the current scroll offset/target.
                -- A selection callback can fire before the slide has finished.
                local presentationChanged = false
                for i, data in ipairs(entries) do
                    for _, key in ipairs({"name", "icon", "count", "available", "quality"}) do
                        if r.entries[i][key] ~= data[key] then
                            r.entries[i][key] = data[key]
                            presentationChanged = true
                        end
                    end
                end
                local current = r.list:GetSelectedData()
                if not current or current.value ~= value then
                    r.restore(value)
                    r.list:SetSelectedDataIndex(chosenIndex, true)
                end
                if presentationChanged then r.list:RefreshVisible() end
            else
                local populated = r.entries ~= nil
                r.list:Clear()
                for _, data in ipairs(entries) do r.list:AddEntry(data) end
                r.entries = entries
                r.list:Commit()
                -- Animate dependent selections after rebuilding their options.
                -- Initial population still opens directly at the saved value.
                r.restore(value)
                r.list:SetSelectedDataIndex(chosenIndex, true, not populated)
            end
            local data = entries[chosenIndex]
            r.selected:SetText(data and data.name or O.text.noEffect)
            if data and data.quality then r.selected:SetColor(GetItemQualityColor(data.quality):UnpackRGBA())
            else r.selected:SetColor(ZO_NORMAL_TEXT:UnpackRGBA()) end
            r.list:SetEnabled(not O[module].IsBusy())
        end
        self.rebuilding = false
        if self.RefreshMaterials then self:RefreshMaterials() end
        self:EnforceHidden()
    end
    function view:EnforceHidden()
        if self.visible then for _, c in ipairs(self.hiddenControls) do c:SetHidden(true) end end
    end
    function view:Show()
        if self.visible then self:EnforceHidden(); return end
        self.visible = true
        self.hiddenStates = {}
        for _, c in ipairs(self.hiddenControls) do self.hiddenStates[c] = c:IsHidden() end
        self.panel:SetHidden(false)
        self:EnforceHidden()
    end
    function view:Hide()
        if not self.visible then return end
        self.visible = false
        self.panel:SetHidden(true)
        if self.hoveredMaterial then ClearTooltip(ItemTooltip); self.hoveredMaterial = nil end
        for _, preview in ipairs(self.materialPreviews or {}) do
            preview.icon:SetHidden(true)
            if preview.name then preview.name:SetHidden(true) end
        end
        -- Native mode changes have already assigned extraction/furniture visibility.
        if self.isCreation() then
            for c, hidden in pairs(self.hiddenStates) do c:SetHidden(hidden) end
        end
        clearTooltip()
    end
    -- Crafting animations can refresh their controls while their container is hidden.
    ZO_PostHook(station, "OnSlotChanged", function()
        view:EnforceHidden()
        if view.visible and not O[module].CraftingIntegration.applying and view.RefreshMaterials then view:RefreshMaterials() end
    end)
    return view
end

-- Missing items are a visual preview only; native slots retain real bag locations.
function U.Materials(view, slots, idsFor)
    local A, station = O[view.module], view.station
    view.materialPreviews = {}
    for i, slot in ipairs(slots) do
        local clicked = slot.control:GetHandler("OnClicked")
        slot.control:SetHandler("OnClicked", function(control, ...)
            if not view.visible and clicked then return clicked(control, ...) end
        end)
        local icon = WINDOW_MANAGER:CreateControl(nil, slot.control, CT_TEXTURE)
        icon:SetAnchorFill(slot.inventorySlotIcon)
        icon:SetDrawLayer(DL_OVERLAY)
        icon:SetMouseEnabled(true)
        icon:SetHidden(true)
        local preview = {slot = slot, icon = icon}
        view.materialPreviews[i] = preview
        for _, target in ipairs({slot.control, slot.inventorySlotIcon, icon}) do
            local enter, exit = target:GetHandler("OnMouseEnter"), target:GetHandler("OnMouseExit")
            target:SetHandler("OnMouseEnter", function(control, ...)
                if enter then enter(control, ...) end
                if view.visible and preview.id then
                    view.hoveredMaterial = preview
                    InitializeTooltip(ItemTooltip, slot.control, RIGHT, 0, 0, LEFT)
                    local bag, index = slot:GetBagAndSlot()
                    if bag ~= nil and index ~= nil and GetItemId(bag, index) == preview.id then
                        ItemTooltip:SetBagItem(bag, index)
                    else
                        ItemTooltip:SetLink(A.ItemLink(preview.id))
                    end
                end
            end)
            target:SetHandler("OnMouseExit", function(control, ...)
                if exit then exit(control, ...) end
                if view.hoveredMaterial == preview then
                    ClearTooltip(ItemTooltip)
                    view.hoveredMaterial = nil
                end
            end)
        end
        if slot.nameLabel then
            preview.name = WINDOW_MANAGER:CreateControl(nil, slot.control, CT_LABEL)
            preview.name:SetFont("ZoFontWinH4")
            preview.name:SetDimensions(185, 48)
            preview.name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            preview.name:SetAnchor(TOP, slot.control, BOTTOM)
            preview.name:SetHidden(true)
        end
    end
    function view:RefreshMaterials()
        if not self.visible or A.IsBusy() then return end
        local ids = idsFor()
        for i, preview in ipairs(self.materialPreviews) do
            local id, slot = ids[i], preview.slot
            local bag, index = slot:GetBagAndSlot()
            local staged = id and bag ~= nil and index ~= nil and GetItemId(bag, index) == id
            local show = id ~= nil and not staged
            if self.hoveredMaterial == preview and preview.id ~= id then
                ClearTooltip(ItemTooltip)
                self.hoveredMaterial = nil
            end
            preview.id = id
            preview.icon:SetHidden(not show)
            if preview.name then preview.name:SetHidden(not show) end
            if show then
                local item = A.inventory[id]
                local shade = item and item.count > 0 and 1 or 0.3
                preview.icon:SetTexture(U.Icon(A, id))
                preview.icon:SetColor(shade, shade, shade, 1)
                if preview.name then
                    preview.name:SetText(zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(A.ItemLink(id))))
                    preview.name:SetAlpha(shade)
                end
            end
        end
    end
    local updateMultiCraft = station.UpdateMultiCraft
    station.UpdateMultiCraft = function(self, ...)
        -- Intermediate empty slots must not clamp the user's chosen quantity.
        if A.active and view.isCreation() and A.CraftingIntegration.applying then return end
        if A.active and view.isCreation() and not A.IsBusy() and self:GetMultiCraftMaxIterations() == 0 then
            self.multiCraftSpinner:SetMinMax(0, 0)
            self.multiCraftSpinner:SetValue(0)
            self.multiCraftSpinner:UpdateButtons()
            return
        end
        return updateMultiCraft(self, ...)
    end
end

function U.Empty() return {value = false, name = O.text.noEffect, icon = O.noneTexture} end
function U.Icon(A, id) return GetItemLinkInfo(A.ItemLink(id)) end
