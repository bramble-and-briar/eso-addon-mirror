-- Optional integrations, checked against the user's installed addon sources.
GridBagsCompatibility = {}
local C = GridBagsCompatibility

function C:NativeVisibility(owner, visible)
    self.suppressed = self.suppressed or {}
    local controls = { ZO_PlayerInventory, ZO_PlayerBank, ZO_PlayerBankMenu }
    if not visible then
        for _, control in pairs(controls) do
            if self.suppressed[control] == nil then self.suppressed[control] = control:IsHidden() end
            control:SetHidden(true)
        end
        return
    end
    local wasSuppressed = next(self.suppressed) ~= nil
    for control in pairs(self.suppressed) do control:SetHidden(true) end
    self.suppressed = {}
    if (wasSuppressed or owner.nativeFiltersMode) and owner.sceneName and not IsInGamepadPreferredMode() then
        local context = GridBagsAdvancedFilters and GridBagsAdvancedFilters:GetContext(owner)
        local deposit = not owner:IsBankScene() or context == INVENTORY_BACKPACK
        if ZO_PlayerInventory then ZO_PlayerInventory:SetHidden(not deposit) end
        if ZO_PlayerBank then ZO_PlayerBank:SetHidden(deposit) end
        if ZO_PlayerBankMenu then ZO_PlayerBankMenu:SetHidden(not owner:IsBankScene()) end
    end
end

function C:Warn(key, message)
    self.warnings = self.warnings or {}
    if self.warnings[key] then return end
    self.warnings[key] = true
    d("GridBags: " .. message)
end

function C:GetInventory(panel)
    local kind = panel.key == "Bank" and INVENTORY_BANK or INVENTORY_BACKPACK
    return PLAYER_INVENTORY and PLAYER_INVENTORY.inventories[kind], kind
end

function C:GetSlotData(panel, bag, slot)
    if not SHARED_INVENTORY then return nil end
    local source = SHARED_INVENTORY:GenerateSingleSlotData(bag, slot)
    if not source then return nil end
    -- Row decorators are allowed to annotate the copy, never the native row's data.
    local data = {}
    for k, v in pairs(source) do data[k] = v end
    data.inventory = self:GetInventory(panel)
    return data
end

function C:Matches(owner, panel, bag, slot)
    if not owner.saved.externalFilters then return true end
    local inventory = self:GetInventory(panel)
    local data = self:GetSlotData(panel, bag, slot)
    if not data then
        if LibFilters3 then
            panel.filterError = true
            self:Warn("slotData", "Native slot data unavailable; filtered results are withheld.")
            return false
        end
        return true
    end
    local ok, result = pcall(function()
        -- Keep native categories/subcategories chosen through the Filters button.
        if inventory and ZO_ItemFilterUtils then
            local filter, subfilter = inventory.currentFilter, inventory.subFilter
            if type(filter) == "function" then
                if not filter(data) then return false end
            elseif filter ~= nil and not ZO_ItemFilterUtils.IsSlotFilterDataInItemTypeDisplayCategory(data, filter) then
                return false
            end
            if type(subfilter) == "function" then
                if not subfilter(data) then return false end
            elseif type(subfilter) == "number" and not ZO_ItemFilterUtils.IsSlotInItemTypeDisplayCategoryAndSubcategory(data, filter, subfilter) then
                return false
            end
        end
        local lib = LibFilters3
        if not lib or type(lib.GetFilterTypeCallbacks) ~= "function" then return true end
        local context = panel.key == "Bank" and LF_BANK_WITHDRAW or
            (owner:IsBankScene() and LF_BANK_DEPOSIT or LF_INVENTORY)
        if context == nil then error("Missing LibFilters context") end
        local callbacks = lib:GetFilterTypeCallbacks(context)
        if (not callbacks or next(callbacks) == nil) and lib.useFilterAllFallback then
            callbacks = lib:GetFilterTypeCallbacks(LF_FILTER_ALL)
        end
        for _, callback in pairs(callbacks or {}) do
            if not callback(data) then return false end
        end
        return true
    end)
    if not ok then
        panel.filterError = true
        self:Warn("filter", "An external filter failed; affected results are withheld. " .. tostring(result))
        return false
    end
    return result
end

function C:SetupRow(owner, panel, cell, item)
    local row = cell.row
    if not row then return end
    local inventory = self:GetInventory(panel)
    local data = self:GetSlotData(panel, item.bag, item.slot)
    local list = inventory and inventory.listView
    local setup = list and list.dataTypes and list.dataTypes[1] and list.dataTypes[1].setupCallback
    if data and setup then
        row.dataEntry = { data = data }
        row.isGrid = true
        local ok, err = pcall(setup, row, data)
        if not ok then self:Warn("row", "A native row decorator failed: " .. tostring(err)) end
    end
    -- Stock row text is unnecessary in an icon cell. Addon-created marks remain.
    for _, name in ipairs({ "Name", "SellPrice", "SellPriceText", "Status", "TraitInfo", "SellInformation", "ItemCondition" }) do
        local child = row:GetNamedChild(name)
        if child then child:SetHidden(true) end
    end
    local research = row:GetNamedChild("Research")
    if research then
        research:ClearAnchors()
        research:SetAnchor(TOPLEFT, row, TOPLEFT, 2, 2)
    end
    local craft = row:GetNamedChild("CSMark")
    if craft then
        craft:ClearAnchors()
        craft:SetAnchor(TOPRIGHT, row, TOPRIGHT, -2, 2)
        craft:SetDimensions(22, 22)
    end
end

function C:HideDecorations(cell)
    if not cell.row then return end
    cell.row.dataEntry = nil
    for _, name in ipairs({ "Research", "CSMark", "Status", "TraitInfo", "SellInformation" }) do
        local child = cell.row:GetNamedChild(name)
        if child then child:SetHidden(true) end
    end
end

function C:Initialize(owner)
    if SecurePostHook then
        if PLAYER_INVENTORY and PLAYER_INVENTORY.UpdateList then
            SecurePostHook(PLAYER_INVENTORY, "UpdateList", function() owner:QueueRefresh() end)
        end
        if LibFilters3 then
            for _, method in ipairs({ "RegisterFilter", "UnregisterFilter", "RequestUpdate", "SetFilterAllState" }) do
                if type(LibFilters3[method]) == "function" then
                    SecurePostHook(LibFilters3, method, function() owner:QueueRefresh() end)
                end
            end
        end
    end
    local lam = LibAddonMenu2
    if lam then
        lam:RegisterAddonPanel("GridBagsOptions", { type = "panel", name = "GridBags", displayName = "GridBags",
            author = "XenoXanatos", version = "0.14.0", registerForRefresh = true })
        lam:RegisterOptionControls("GridBagsOptions", {
            { type = "checkbox", name = "Enable grid", getFunc = function() return owner.saved.enabled end,
                setFunc = function(v) owner.saved.enabled = v; owner:Refresh() end },
            { type = "checkbox", name = "Use native and Advanced Filters selections",
                tooltip = "Use the embedded Advanced Filters controls above the grid. Applies to live bags only.",
                getFunc = function() return owner.saved.externalFilters end,
                setFunc = function(v) owner.saved.externalFilters = v; owner:Refresh() end },
            { type = "slider", name = "Columns", min = 6, max = 12, step = 1,
                getFunc = function() return owner.saved.columns end,
                setFunc = function(v) owner.saved.columns = v; owner:Refresh() end },
            { type = "slider", name = "Icon size", min = 36, max = 64, step = 1,
                getFunc = function() return owner.saved.size end,
                setFunc = function(v) owner.saved.size = v; owner:Refresh() end },
            { type = "checkbox", name = "Show character and bank gold",
                getFunc = function() return owner.saved.showGold ~= false end,
                setFunc = function(v) owner.saved.showGold = v; owner:Refresh() end },
            { type = "dropdown", name = "Display sort", choices = { "name", "quality", "type", "stack", "slot" },
                getFunc = function() return owner.saved.sort end,
                setFunc = function(v) owner.saved.sort = v; owner:Refresh() end },
            { type = "button", name = "Open routing planner", func = function() owner:OpenInventoryTools("planner") end },
            { type = "button", name = "Delivery overview", tooltip="Filter saved item deliveries by stage, character or item. Inspect waiting and review reasons without changing transfers.", func = function() owner:OpenInventoryTools("deliveries") end },
            { type = "button", name = "Protected items and keep reserves", tooltip="Review, edit or remove source-specific Never export and Keep settings. ESO locks and uncertain transfer holds are separate.", func = function() owner:OpenInventoryTools("protected") end },
            { type = "button", name = "Character role profiles", func = function() owner:OpenInventoryTools("profiles") end },
            { type = "button", name = "Crafting overview and material rules", func = function() owner:OpenInventoryTools("crafting") end },
            { type = "button", name = "Gather known recipe ingredients", tooltip="Preview the selected learned recipe's requirements, bank and saved-character sources; confirm finite deliveries before authorizing them.", func = function() owner:OpenInventoryTools("gather") end },
            { type = "button", name = "Open grid to mark items", func = function() owner:OpenInventoryTools("mark") end },
            { type = "button", name = "Gold transfer rules", func = function() owner:OpenInventoryTools("gold") end },
            { type = "checkbox", name = "Lock inventory window", getFunc = function() return GridBagsLayout:Get("inventory").locked end,
                setFunc = function(v) GridBagsLayout:SetLocked("inventory", v) end },
            { type = "checkbox", name = "Lock banking window", getFunc = function() return GridBagsLayout:Get("bank").locked end,
                setFunc = function(v) GridBagsLayout:SetLocked("bank", v) end },
            { type = "button", name = "Reset inventory position", func = function() GridBagsLayout:Reset("inventory") end },
            { type = "button", name = "Reset banking position", func = function() GridBagsLayout:Reset("bank") end },
            { type = "checkbox", name = "Pause all planned item and gold transfers",
                getFunc = function() return GridBagsActivity:IsPaused() end,
                setFunc = function(v) GridBagsActivity:SetPaused(v) end },
            { type = "button", name = "Open transfer log", tooltip = "View successful moves, full-bank/full-inventory skips, missing items, snapshot changes and timeout/review reasons.",
                func = function() owner:OpenInventoryTools("history") end },
            { type = "button", name = "Preview next bank visit (no moves)", func = function() owner:OpenInventoryTools("preview") end },
            { type = "button", name = "Troubleshooting report", func = function() owner:OpenInventoryTools("report") end },
            { type = "button", name = "Configuration backups, export and import", func = function() owner:OpenInventoryTools("backups") end },
            { type = "description", text = "Unlock a layout to drag its header; inventory and banking keep separate positions. Gold rules start disabled. Configure carried min/max, optional fixed deposits and approval limits in Gold transfer rules. Daily reset hours use UTC." },
        })
    end
end
