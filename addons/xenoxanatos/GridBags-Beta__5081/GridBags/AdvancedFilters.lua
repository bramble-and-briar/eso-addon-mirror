-- Temporarily dock the installed addon's real widgets; never copy its callbacks
-- or change item action handlers. Original parents/anchors are restored on exit.
GridBagsAdvancedFilters = { mounted = {} }
local A = GridBagsAdvancedFilters

function A:IsAvailable()
    return AdvancedFilters and AdvancedFilters.subfilterGroups and PLAYER_INVENTORY
        and PLAYER_INVENTORY.inventories and type(PLAYER_INVENTORY.ChangeFilter) == "function"
end

function A:ShouldShow(owner)
    local snapshot = GridBagsSnapshots:GetSelected(owner)
    local supported = not snapshot and self:IsAvailable()
    return supported and owner.saved.externalFilters and owner.saved.embeddedFilters
        and owner:IsActive() and not owner.nativeFiltersMode
end

function A:GetContext(owner)
    if not owner:IsBankScene() then return INVENTORY_BACKPACK end
    -- selectedTabType is a legacy inventory field, not the bank mode. Fragments
    -- remain authoritative even while their visual panels are suppressed.
    if BANK_FRAGMENT and BANK_FRAGMENT:IsShowing() then return INVENTORY_BANK end
    if INVENTORY_FRAGMENT and INVENTORY_FRAGMENT:IsShowing() then return INVENTORY_BACKPACK end
    return owner.afInventoryType or INVENTORY_BANK
end

function A:RestoreControl(control)
    local original = self.mounted[control]
    if not original then return end
    control:SetParent(original.parent)
    control:ClearAnchors()
    for _, anchor in ipairs(original.anchors) do control:SetAnchor(unpack(anchor, 1, 6)) end
    control:SetDimensions(original.width, original.height)
    control:SetScale(original.scale)
    local hidden = original.hidden
    if original.bar and original.inventory then
        local group = AdvancedFilters.subfilterGroups[original.inventory]
        if group and group.currentSubfilterBar and group.currentSubfilterBar ~= original.bar then hidden = true end
    end
    control:SetHidden(hidden)
    self.mounted[control] = nil
end

function A:Restore()
    local controls = {}
    for control in pairs(self.mounted) do controls[#controls + 1] = control end
    for _, control in ipairs(controls) do self:RestoreControl(control) end
    self.currentBar = nil
    if self.host then self.host:SetHidden(true) end
end

function A:Dock(control, parent, width, y, bar, inventory)
    if not self.mounted[control] then
        local anchors = {}
        for i = 0, control:GetNumAnchors() - 1 do
            local valid, point, relative, relativePoint, x, offsetY, constraints = control:GetAnchor(i)
            if valid then anchors[#anchors + 1] = { point, relative, relativePoint, x, offsetY, constraints } end
        end
        self.mounted[control] = { parent = control:GetParent(), anchors = anchors,
            width = control:GetWidth(), height = control:GetHeight(), scale = control:GetScale(),
            hidden = control:IsHidden(), bar = bar, inventory = inventory }
    end
    local nativeWidth = math.max(565, self.mounted[control].width)
    control:SetParent(parent)
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, y)
    control:SetDimensions(nativeWidth, self.mounted[control].height)
    control:SetScale(math.min(1, width / nativeWidth))
    control:SetHidden(false)
end

function A:SelectContext(owner, inventoryType)
    if not self:IsAvailable() then return end
    self:Restore()
    owner.afInventoryType = inventoryType
    if owner:IsBankScene() and ZO_PlayerBankMenuBar then
        ZO_MenuBar_SelectDescriptor(ZO_PlayerBankMenuBar,
            inventoryType == INVENTORY_BACKPACK and SI_BANK_DEPOSIT or SI_BANK_WITHDRAW)
    end
    -- Reuse the native selection flow so AF also updates its group and dropdown.
    local inventory = PLAYER_INVENTORY.inventories[inventoryType]
    if inventory then
        for _, tab in ipairs(inventory.tabFilters or {}) do
            if tab.filterType == inventory.currentFilter then
                PLAYER_INVENTORY:ChangeFilter(tab)
                break
            end
        end
    end
    owner:QueueRefresh()
end

function A:Update(owner, width)
    if not self:ShouldShow(owner) then self:Restore(); return end
    self.backpackButton:SetHidden(false)
    self.caption:SetHidden(false)
    local banking = owner:IsBankScene()
    local inventoryType = self:GetContext(owner)
    if inventoryType ~= INVENTORY_BANK then inventoryType = INVENTORY_BACKPACK end
    local inventory = PLAYER_INVENTORY.inventories[inventoryType]
    local group = AdvancedFilters.subfilterGroups[inventoryType]
    local categories = group and group[CRAFTING_TYPE_INVALID]
    local bar = categories and inventory and categories[inventory.currentFilter]
    if not bar or not bar.control then bar = group and group.currentSubfilterBar end
    local categoryControl = inventory and inventory.filterBar
    local keep = {}
    if categoryControl then keep[categoryControl] = true end
    if bar and bar.control then keep[bar.control] = true end
    local old = {}
    for control in pairs(self.mounted) do if not keep[control] then old[#old + 1] = control end end
    for _, control in ipairs(old) do self:RestoreControl(control) end
    self.host:SetHidden(false)
    self.host:SetDimensions(width, 168)
    self.backpackButton:SetAlpha(inventoryType == INVENTORY_BACKPACK and 1 or 0.55)
    self.bankButton:SetHidden(not banking)
    self.bankButton:SetAlpha(inventoryType == INVENTORY_BANK and 1 or 0.55)
    self.caption:SetText(banking and (inventoryType == INVENTORY_BANK and "Advanced Filters: bank withdrawals" or
        "Advanced Filters: backpack deposits") or "Advanced Filters: backpack")
    if categoryControl then self:Dock(categoryControl, self.host, width, 45) end
    if bar and bar.control then
        self:Dock(bar.control, self.host, width, 96, bar, inventoryType)
        self.currentBar = bar
    else
        self.currentBar = nil
    end
end

function A:Initialize(owner)
    local WM = WINDOW_MANAGER
    self.host = WM:CreateControl("GridBagsAdvancedFiltersHost", owner.root, CT_CONTROL)
    self.host:SetAnchor(TOPLEFT, owner.root, TOPLEFT, 20, 48)
    self.host:SetHidden(true)
    local function Button(text, x, callback)
        local button = WM:CreateControlFromVirtual(nil, self.host, "ZO_DefaultButton")
        button:SetDimensions(150, 28)
        button:SetAnchor(TOPLEFT, self.host, TOPLEFT, x, 0)
        button:SetText(text)
        button:SetHandler("OnClicked", callback)
        return button
    end
    self.backpackButton = Button("Backpack filters", 0, function() self:SelectContext(owner, INVENTORY_BACKPACK) end)
    self.bankButton = Button("Bank filters", 156, function() self:SelectContext(owner, INVENTORY_BANK) end)
    self.caption = WM:CreateControl(nil, self.host, CT_LABEL)
    self.caption:SetFont("ZoFontGameSmall")
    self.caption:SetAnchor(TOPLEFT, self.host, TOPLEFT, 4, 28)
    if self:IsAvailable() and SecurePostHook then
        SecurePostHook(PLAYER_INVENTORY, "ChangeFilter", function() owner:QueueRefresh() end)
        local util = AdvancedFilters.util
        if util and type(util.RefreshSubfilterBar) == "function" then
            SecurePostHook(util, "RefreshSubfilterBar", function() owner:QueueRefresh() end)
        end
    end
end
