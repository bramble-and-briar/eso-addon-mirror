local OS = OneSettings
local Addons = { pending = {}, latest = {}, catalog = {}, byIndex = {} }
OS.modules.addons = Addons

function Addons:WithFilter(filter, callback)
    local previous = self.manager:GetAddOnFilter()
    local changed = (previous or "") ~= (filter or "")
    if changed then
        if filter and filter ~= "" then self.manager:SetAddOnFilter(filter)
        else self.manager:RemoveAddOnFilter() end
    end
    local ok, result = pcall(callback)
    if (self.manager:GetAddOnFilter() or "") ~= (previous or "") then
        if previous and previous ~= "" then self.manager:SetAddOnFilter(previous)
        else self.manager:RemoveAddOnFilter() end
    end
    if not ok then error(result) end
    return result
end

function Addons:CaptureAt(filter)
    return self:WithFilter(filter, function()
        local states = {}
        for name, node in pairs(self.catalog) do
            states[name] = select(5, self.manager:GetAddOnInfo(node.index)) == true
        end
        return { states = states, enabled = self.manager:AreAddOnsEnabled() }
    end)
end

function Addons:Capture()
    return self:CaptureAt(self.filter)
end

function Addons:Participating(filter)
    local node = self.catalog[OS.name]
    if not node then return false end
    return self:WithFilter(filter, function()
        return self.manager:AreAddOnsEnabled() and select(5, self.manager:GetAddOnInfo(node.index)) == true
    end)
end

function Addons:RefreshUI()
    if ADD_ON_MANAGER and ADD_ON_MANAGER.control and not ADD_ON_MANAGER.control:IsHidden() then
        ADD_ON_MANAGER.isDirty = true
        ADD_ON_MANAGER:RefreshData()
        ADD_ON_MANAGER:RefreshKeybinds()
    end
end

function Addons:Write(snapshot, filter)
    local changed = false
    self.writing = true
    local ok, err = pcall(function()
        self:WithFilter(filter, function()
            if self.manager:AreAddOnsEnabled() ~= snapshot.enabled then
                self.manager:SetAddOnsEnabled(snapshot.enabled)
                changed = true
            end
            -- These are pending flags; the engine resolves dependency load order on reload.
            for _, enabled in ipairs({ true, false }) do
                for name, node in pairs(self.catalog) do
                    if snapshot.states[name] == enabled then
                        local current = select(5, self.manager:GetAddOnInfo(node.index))
                        if current ~= enabled then
                            self.manager:SetAddOnEnabled(node.index, enabled)
                            changed = true
                        end
                    end
                end
            end
        end)
    end)
    self.writing = false
    if not ok then error(err) end
    return changed
end

function Addons:Normalize(snapshot)
    local states, issues = OS.Dependencies.Resolve(self.catalog, snapshot.states)
    return { states = states, enabled = snapshot.enabled }, issues
end

function Addons:MergeShared(snapshot)
    local shared = OS.Copy(OS.account.shared.addons or { states = {} })
    shared.enabled = snapshot.enabled
    for name, enabled in pairs(snapshot.states) do shared.states[name] = enabled end
    shared.states[OS.name] = nil
    OS.account.shared.addons = shared
end

function Addons:Project(shared, filter)
    local current = self:CaptureAt(filter)
    for name, enabled in pairs(shared.states) do
        if name ~= OS.name and self.catalog[name] then current.states[name] = enabled end
    end
    current.enabled = shared.enabled
    return self:Normalize(current)
end

function Addons:PrepareOthers(shared)
    local failures = {}
    self:EachCharacter(function(filter)
        if filter ~= self.filter and self:Participating(filter) then
            local ok, verified = pcall(function()
                local desired = self:Project(shared, filter)
                self:Write(desired, filter)
                -- Verify the selected profile, not merely successful dispatch to a C API.
                return OS.Equal(desired, self:CaptureAt(filter))
            end)
            if not ok or not verified then failures[#failures + 1] = filter end
        end
    end)
    self.prepareFailures = failures
    return #failures == 0
end

function Addons:Apply(shared, allowReload)
    local normalized = self:Project(shared, self.filter)
    local changed = self:Write(normalized, self.filter)
    self:PrepareOthers(shared)
    self:RefreshUI()
    if allowReload ~= false and (changed or not OS.Equal(normalized, self.loadedStates)) then OS:RequestReload() end
end

function Addons:Signature()
    local snapshot, entries = self:Capture(), {}
    for name, enabled in pairs(snapshot.states) do
        entries[#entries + 1] = name .. "=" .. (enabled and "1" or "0")
    end
    table.sort(entries)
    return (snapshot.enabled and "1:" or "0:") .. table.concat(entries, ";")
end

function Addons:EachCharacter(callback)
    for index = 1, GetNumCharacters() do
        local name = GetCharacterInfo(index)
        if name and name ~= "" then callback(GetUniqueNameForCharacter(zo_strformat(SI_UNIT_NAME, name))) end
    end
end

function Addons:Changed(index, enabled)
    if self.writing or not OS.ready then return end
    local name = self.byIndex[index]
    if not name then return end
    local filter = self.manager:GetAddOnFilter() or ""
    if name == OS.name then self:SelfChanged(filter) end
    self.pending[filter] = OS.Dependencies.Edit(self.catalog, self.pending[filter] or {}, name, enabled == true, self.reverse)
    if name ~= OS.name and self:Participating(filter) then
        self.latest = OS.Dependencies.Edit(self.catalog, self.latest, name, enabled == true, self.reverse)
        self.latest[OS.name] = nil
    end
    OS:Later("Addons", function() self:FlushChanges() end)
end

function Addons:SelfChanged(selected)
    if selected ~= "" and selected ~= self.filter then return end
    local participating = self:Participating(self.filter)
    if participating and not self.participating then self.resumePending = true end
    self.participating = participating
end

function Addons:FlushChanges()
    if self.writing or (not self.resumePending and not next(self.pending)) then return end
    OS:CancelLater("Addons")
    local pending = self.pending
    local latest, global = self.latest, self.latestGlobal
    self.pending = {}
    self.latest = {}
    self.latestGlobal = nil
    if self.resumePending then
        self.resumePending = nil
        -- Re-enabling a loaded instance has the same direction as a fresh login.
        -- Discard edits queued while disconnected and suppress their delayed hooks.
        OS.modules.settings.dirty, OS.modules.windows.dirty = false, false
        OS.modules.bindings.dirty = {}
        for _, category in ipairs({ "addons", "settings", "bindings", "windows" }) do OS:Apply(category) end
        self:RefreshUI()
        return
    end
    for filter in pairs(pending) do
        local requested = self:CaptureAt(filter)
        for name, enabled in pairs(pending[filter]) do
            if self.catalog[name] then requested.states[name] = enabled end
        end
        local normalized = self:Normalize(requested)
        self:Write(normalized, filter)
    end
    if OS:Enabled("addons") and (next(latest) or global ~= nil) then
        -- Retain the last API edit per addon even when managers alternate character filters.
        local shared = OS.Copy(OS.account.shared.addons or self:Capture())
        for name, enabled in pairs(latest) do shared.states[name] = enabled end
        if global ~= nil then shared.enabled = global end
        local resolved = self:Normalize(shared)
        self:MergeShared(resolved)
        self:Apply(OS.account.shared.addons, false)
    end
    self:RefreshUI()
end

function Addons:Initialize()
    self.manager = GetAddOnManager()
    self.filter = GetUniqueNameForCharacter(GetUnitName("player"))
    self:WithFilter(self.filter, function()
        for index = 1, self.manager:GetNumAddOns() do
            local name, _, _, _, _, _, _, library = self.manager:GetAddOnInfo(index)
            self.catalog[name] = { index = index, library = library, version = self.manager:GetAddOnVersion(index), dependencies = {} }
            self.byIndex[index] = name
        end
        for _, node in pairs(self.catalog) do
            for index = 1, self.manager:GetAddOnNumDependencies(node.index) do
                local name, _, _, minimum = self.manager:GetAddOnDependencyInfo(node.index, index)
                node.dependencies[#node.dependencies + 1] = { name = name, minimum = minimum or 0 }
            end
        end
    end)
    self.reverse = OS.Dependencies.Reverse(self.catalog)
    self.loadedStates = self:Capture()
    self.participating = self:Participating(self.filter)
    -- AddOnManager is writable userdata. SecurePostHook requires a Lua table;
    -- the stock Lua hook helper supports its indexed methods instead.
    ZO_PostHook(self.manager, "SetAddOnEnabled", function(_, index, enabled) self:Changed(index, enabled) end)
    ZO_PostHook(self.manager, "SetAddOnsEnabled", function()
        if self.writing or not OS.ready then return end
        local filter = self.manager:GetAddOnFilter() or ""
        self:SelfChanged(filter)
        self.pending[filter] = self.pending[filter] or {}
        self.pending[filter].__global = true
        if self:Participating(filter) then self.latestGlobal = self.manager:AreAddOnsEnabled() end
        OS:Later("Addons", function() self:FlushChanges() end)
    end)
end
