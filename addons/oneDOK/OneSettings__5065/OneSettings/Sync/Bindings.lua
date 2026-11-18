local OS = OneSettings
local Bindings = { dirty = {} }
OS.modules.bindings = Bindings

function Bindings:ReadAction(layer, category, action)
    local result = {}
    for index = 1, GetMaxBindingsPerAction() do
        result[index] = { GetActionBindingInfo(layer, category, action, index) }
    end
    return result
end

function Bindings:Capture()
    local result = {}
    for layer = 1, GetNumActionLayers() do
        local _, categories = GetActionLayerInfo(layer)
        for category = 1, categories do
            local _, actions = GetActionLayerCategoryInfo(layer, category)
            for action = 1, actions do
                local name, rebindable = GetActionInfo(layer, category, action)
                if rebindable then result[name] = self:ReadAction(layer, category, action) end
            end
        end
    end
    -- Only unavailable actions need copying; live actions already have fresh tables.
    for name, bindings in pairs(OS.account.shared.bindings or {}) do
        if not result[name] then result[name] = OS.Copy(bindings) end
    end
    return result
end

function Bindings:Apply(shared)
    if IsUnitInCombat("player") then self.deferred = true; return end
    local changes = {}
    local maxBindings = GetMaxBindingsPerAction()
    for name, bindings in pairs(shared) do
        local layer, category, action = GetActionIndicesFromName(name)
        if layer and category and action then
            local _, rebindable = GetActionInfo(layer, category, action)
            if rebindable and not OS.Equal(bindings, self:ReadAction(layer, category, action)) then
                changes[#changes + 1] = { layer, category, action, bindings }
            end
        end
    end
    -- Clear all affected actions first, so swaps do not delete a just-restored binding.
    for _, entry in ipairs(changes) do
        if not CallSecureProtected("UnbindAllKeysFromAction", entry[1], entry[2], entry[3]) then
            self.deferred = true
            return
        end
    end
    for _, entry in ipairs(changes) do
        for index, binding in ipairs(entry[4]) do
            if index <= maxBindings and binding[1] and binding[1] ~= KEY_INVALID then
                if not CallSecureProtected("BindKeyToAction", entry[1], entry[2], entry[3], index, unpack(binding)) then
                    self.deferred = true
                    return
                end
            end
        end
    end
    self.deferred = false
    -- A successful protected dispatch does not prove the engine accepted every bind.
    for _, entry in ipairs(changes) do
        if not OS.Equal(entry[4], self:ReadAction(entry[1], entry[2], entry[3])) then
            self.deferred = true
            return
        end
    end
end

function Bindings:Changed(layer, category, action)
    if not OS.ready or OS.applying or self.deferred or not OS:Enabled("bindings") then return end
    local name, rebindable = GetActionInfo(layer, category, action)
    if rebindable then
        self.dirty[name] = { layer, category, action }
        OS:Later("Bindings", function() self:FlushChanges() end)
    end
end

function Bindings:FlushChanges()
    if not next(self.dirty) then return end
    OS:CancelLater("Bindings")
    if OS:Enabled("bindings") and not self.deferred then
        local shared = OS.account.shared.bindings
        for name, indices in pairs(self.dirty) do shared[name] = self:ReadAction(unpack(indices)) end
    end
    self.dirty = {}
end

function Bindings:Initialize()
    local function changed(_, layer, category, action) self:Changed(layer, category, action) end
    EVENT_MANAGER:RegisterForEvent(OS.name, EVENT_KEYBINDING_SET, changed)
    EVENT_MANAGER:RegisterForEvent(OS.name, EVENT_KEYBINDING_CLEARED, changed)
    EVENT_MANAGER:RegisterForEvent(OS.name, EVENT_KEYBINDINGS_LOADED, function()
        if OS.ready and OS:Enabled("bindings") then OS:Apply("bindings") end
    end)
end
