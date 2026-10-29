AutoMasterWrits = {}
local AMW = AutoMasterWrits
AMW.name, AMW.title, AMW.author = "AutoMasterWrits", "Auto Master Writs", "xbutch"
AMW.version = "1.51.03"
AMW.commandDelayMilliseconds = 500
AMW.hudEnabled = false
AMW.defaults = {
    filterNirnhoned = true, filterEpicJewelry = true, autoDeposit = true,
    reserveSlots = 10, extractLimit = 50, showHUD = false,
    overrides = {}, deferred = {}, withdraw = {}, manualDeferred = {}, deliveryQuests = {},
}
AMW.status, AMW.inventory = "Ready", {}

function AMW:Print(message)
    local text = "|cD8BC77Auto Master Writs:|r " .. tostring(message)
    if CHAT_ROUTER then CHAT_ROUTER:AddSystemMessage(text) else d(text) end
end

function AMW:SetStatus(message, announce)
    self.status = message
    if announce then self:Print(message) end
    self:UpdateHUD()
end

function AMW:Alert(message)
    self:SetStatus(message, true)
    if ZO_Alert then ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.GENERAL_ALERT_ERROR, self.title .. ": " .. message) end
end

function AMW:SecureCall(name, ...)
    if IsProtectedFunction(name) then return CallSecureProtected(name, ...) end
    return _G[name](...)
end

function AMW:WaitForGameCommand(minimumDelay)
    local delay = math.max(self.commandDelayMilliseconds, minimumDelay or 0)
    while true do
        local remaining = self.lastCommandAt and self.lastCommandAt + delay - GetGameTimeMilliseconds() or 0
        if remaining > 0 then self:Yield(math.ceil(remaining))
        elseif not self:HasWorkBudget() then self:Yield(25)
        else return end
    end
end

function AMW:SendGameCommand(name, ...)
    local now = GetGameTimeMilliseconds()
    if self.lastCommandAt and now - self.lastCommandAt < self.commandDelayMilliseconds then
        return false, "Command interval has not elapsed"
    end
    self.lastCommandAt = now
    return pcall(self.SecureCall, self, name, ...)
end

function AMW:EnsureRuntime()
    if not self.saved then
        self.saved = ZO_SavedVars:NewCharacterIdSettings("AutoMasterWritsSavedVariables", 1, nil, self.defaults, GetWorldName())
    end
    if not self:LazyReady() then
        self:Alert("Lazy Writ Crafter is not ready. Enable its dependencies before using Auto Master Writs.")
        return false
    end
    return true
end

function AMW:ActivateSession()
    if not self:EnsureRuntime() then return false end
    if not self.sessionActive then
        self.sessionActive = true
        self:WatchDeactivation()
        self:InstallInventoryActions()
    end
    return true
end

function AMW:UniqueId(bag, slot)
    local id = Id64ToString(GetItemUniqueId(bag, slot))
    if id ~= "" and id ~= "0" then return id end
end

function AMW:FindItem(uid)
    local record = self.inventory[uid]
    if record and self:UniqueId(record.bag, record.slot) == uid then return record.bag, record.slot end
end

function AMW:IsBusy(except)
    if except ~= "delivery" and self.delivery then return true end
    if except ~= "bank" and self.bankOperation then return true end
    if except ~= "extract" and self.extracting then return true end
    if except ~= "jobs" and self.jobs and next(self.jobs) then return true end
    return false
end

function AMW:CanUseInventory()
    return not IsUnitInCombat("player") and not IsUnitSwimming("player") and not IsUnitDead("player")
        and not IsBankOpen() and not IsGuildBankOpen() and not IsLooting()
        and GetCraftingInteractionType() == CRAFTING_TYPE_INVALID
end

local craftNames = {
    [CRAFTING_TYPE_BLACKSMITHING] = "Blacksmithing", [CRAFTING_TYPE_CLOTHIER] = "Clothing",
    [CRAFTING_TYPE_WOODWORKING] = "Woodworking", [CRAFTING_TYPE_JEWELRYCRAFTING] = "Jewelry",
    [CRAFTING_TYPE_ENCHANTING] = "Enchanting", [CRAFTING_TYPE_ALCHEMY] = "Alchemy",
    [CRAFTING_TYPE_PROVISIONING] = "Provisioning",
}
function AMW:CraftName(craft) return craftNames[craft] or "Unsupported writ" end

function AMW:Describe(record)
    local quality = GetString("SI_ITEMQUALITY", record.quality or 0)
    local trait = record.trait and record.trait > 0 and GetString("SI_ITEMTRAITTYPE", record.trait) or ""
    return self:CraftName(record.craft) .. " - " .. quality .. (trait ~= "" and " - " .. trait or "")
        .. (record.vouchers and record.vouchers > 0 and " - " .. record.vouchers .. " vouchers" or "")
        .. (record.setId and record.setId > 0 and " - " .. GetItemSetName(record.setId) or "")
end

function AMW:Classify(record)
    record.reason = self:FilterReason(record)
    record.included = self.saved.overrides[record.uid] == true
    record.crafted = self:IsMarkedCrafted(record.uid)
    record.deferred = record.reason ~= nil and not record.included and not record.crafted
end

function AMW:ScanWorker(deliveryProducts, resetDeferred)
    local items, deferred = {}, {}
    local bags = { BAG_BACKPACK }
    local bankVisible = IsBankOpen() and (GetBankingBag() == BAG_BANK or GetBankingBag() == BAG_SUBSCRIBER_BANK)
    if bankVisible then
        bags[#bags + 1], bags[#bags + 2] = BAG_BANK, BAG_SUBSCRIBER_BANK
    elseif not resetDeferred then
        for uid, record in pairs(self.saved.deferred) do deferred[uid] = record; self:Yield() end
    end
    local counts = { eligible = 0, deferred = 0, crafted = 0 }
    for _, bag in ipairs(bags) do
        for slot = 0, GetBagSize(bag) - 1 do
            if bankVisible and not IsBankOpen() then return false end
            local record = self:ReadWrit(bag, slot)
            if record then
                self:Classify(record)
                items[record.uid] = record
                deferred[record.uid] = record.reason and not record.crafted and record or nil
                if bag == BAG_BACKPACK then
                    if record.crafted then counts.crafted = counts.crafted + 1
                    elseif record.deferred then counts.deferred = counts.deferred + 1
                    else counts.eligible = counts.eligible + 1 end
                end
            elseif deliveryProducts and bag==BAG_BACKPACK then
                local product=self:ReadDeliveryProduct(slot)
                if product then deliveryProducts[#deliveryProducts+1]=product end
            end
            self:Yield()
        end
    end
    -- Publication is atomic; cancellation never publishes a partial inventory.
    self.inventory, self.saved.deferred, self.counts = items, deferred, counts
    return true
end

function AMW:Scan(announce)
    if not self:ActivateSession() then return end
    if self:IsBusy() then return self:Alert("Finish or stop the current operation first.") end
    self:StartJob("scan", function()
        if not self:ScanWorker(nil, true) then return end
        self:ArmBanking()
        if announce then
            local c = self.counts
            self:SetStatus(string.format("%d ready to craft, %d deferred, %d marked crafted.",
                c.eligible, c.deferred, c.crafted), true)
        end
    end)
end

function AMW:ClearDeferred()
    if not self:EnsureRuntime() then return end
    if self:IsBusy() then return self:Alert("Finish or stop the current operation first.") end
    self.saved.deferred = {}
    if self.settingsPage == "review" and self:IsSettingsShowing() then self:OpenActions() end
    self:SetStatus("Deferred list cleared. Scanning applies the filters again.", true)
end

function AMW:SetOverride(uid, included)
    local record = self.inventory[uid] or self.saved and self.saved.deferred[uid]
    if not record then return end
    if included and record.unsupported then return self:Alert("Unsupported writs cannot be included automatically.") end
    self.saved.overrides[uid], self.saved.withdraw[uid] = included and true or nil, included and true or nil
    self:Classify(record)
    self:ArmBanking()
end

function AMW:DeferredRowsWorker()
    local rows = {}
    for uid, record in pairs(self.saved.deferred) do
        local row = {}
        for key, value in pairs(record) do row[key] = value end
        row.included = self.saved.overrides[uid] == true
        rows[#rows + 1] = row
        self:Yield()
    end
    return self:SortWorker(rows, function(a, b)
        if a.craft ~= b.craft then return a.craft < b.craft end
        return a.uid < b.uid
    end)
end

function AMW:OwnHook(group, target, key, before, after)
    -- Do not use Lua wrappers for native inventory action builders.
    self.ownedHooks = self.ownedHooks or {}
    local id = group .. ":" .. key
    if self.ownedHooks[id] then return end
    local original = target[key]
    if type(original) ~= "function" then return end
    local lease = { group = group, target = target, key = key, original = original, active = true }
    local wrapper = function(...)
        if lease.active and before and before(...) then return end
        if not after or not lease.active then return original(...) end
        local function capture(...) return { n = select("#", ...), ... } end
        local result = capture(original(...))
        if lease.active and after then after(...) end
        return unpack(result, 1, result.n)
    end
    lease.wrapper = wrapper
    self.ownedHooks[id] = lease
    target[key] = wrapper
end

function AMW:ReleaseHooks(group)
    for id, hook in pairs(self.ownedHooks or {}) do
        if not group or hook.group == group then
            hook.active = false
            if hook.target[hook.key] == hook.wrapper then hook.target[hook.key] = hook.original end
            self.ownedHooks[id] = nil
        end
    end
end

