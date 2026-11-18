OneSettings = { name = "OneSettings", version = "26.11.2", modules = {} }
local OS = OneSettings

function OS.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = OS.Copy(child) end
    return result
end

function OS.Equal(a, b)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not OS.Equal(value, b[key]) then return false end
    end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

function OS:Later(key, callback)
    local namespace = self.name .. key
    EVENT_MANAGER:UnregisterForUpdate(namespace)
    EVENT_MANAGER:RegisterForUpdate(namespace, 50, function()
        EVENT_MANAGER:UnregisterForUpdate(namespace)
        callback()
    end)
end

function OS:CancelLater(key)
    EVENT_MANAGER:UnregisterForUpdate(self.name .. key)
end

function OS:Enabled(category)
    return self.account and self.account.sync[category] == true
        and not self.modules.addons.resumePending
        and self.modules.addons:Participating(self.modules.addons.filter)
end

function OS:Publish(category, value)
    if not self:Enabled(category) or self.applying then return end
    self.account.shared[category] = OS.Copy(value)
    if category == "addons" then self.account.shared.addons.states[self.name] = nil end
end

function OS:Apply(category)
    local module = self.modules[category]
    if not self:Enabled(category) or not module then return end
    local shared = self.account.shared[category]
    if shared == nil then
        shared = module:Capture()
        if category == "addons" then shared = module:Normalize(shared) end
        self:Publish(category, shared)
        if category ~= "addons" then return end
    end
    self.applying = true
    local ok, err = pcall(module.Apply, module, shared)
    self.applying = false
    if not ok then error(err) end
end

function OS:SetEnabled(category, enabled)
    if not enabled then self:Flush() end
    self.account.sync[category] = enabled == true
    if enabled then
        self:Apply(category)
    end
end

function OS:Flush()
    if not self.ready or self.applying then return end
    self.modules.addons:FlushChanges()
    self.modules.settings:FlushChanges()
    self.modules.bindings:FlushChanges()
    self.modules.windows:FlushChanges()
end

function OS:Warn(key, ...)
    local message = self.strings[key] or key
    if select("#", ...) > 0 then message = string.format(message, ...) end
    if CHAT_SYSTEM then CHAT_SYSTEM:AddMessage("|cD8B46AOneSettings|r: " .. message) end
end

function OS:RequestReload()
    self.reloadPending = true
    if self.UI.settingsOpen then self.reloadNeedsWarning = true end
    if self.active then self:Later("Reload", function() self:TryReload() end) end
end

function OS:ShowPendingWarnings()
    local components = self.character.missingComponents
    if components then
        self.character.missingComponents = nil
        self:Warn("missingComponents", table.concat(components, ", "))
    end
end

function OS:TryReload()
    if not self.reloadPending or IsUnitInCombat("player") then return end
    if self.UI.settingsOpen then
        self.reloadNeedsWarning = true
        return
    end
    self:Flush()
    if self.Equal(self.modules.addons:Capture(), self.modules.addons.loadedStates) then
        self.reloadPending = false
        self.reloadNeedsWarning = false
        self:ShowPendingWarnings()
        return
    end
    local signature = self.modules.addons:Signature()
    -- A failed/no-op reload must never become a login loop, including across sessions.
    if self.character.reloadAttempt == signature then
        self.reloadPending = false
        self:ShowPendingWarnings()
        return
    end
    if self.reloadNeedsWarning then
        self.UI:ShowReloadWarning()
        return
    end
    self.character.reloadAttempt = signature
    self.reloadPending = false
    ReloadUI("ingame")
end
