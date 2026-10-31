-- Tamriel Collections - shared Tamriel Archive coordinator.
-- This file is intentionally safe to embed in every independently installable
-- Archive module. Modules register into one shared global registry and whichever
-- module initializes the Archive UI first owns the single shared menu/scene.
local TC = _G.TamrielCollections
if type(TC) ~= 'table' then
    TC = {}
    _G.TamrielCollections = TC
end

TC.archiveProtocol = math.max(tonumber(TC.archiveProtocol) or 0, 2)
TC.archiveModules = TC.archiveModules or {}
TC.archiveCategories = TC.archiveCategories or {
    { name = 'Motifs', key = 'motifs', addonName = 'Tamriel Collections - Archive Motifs' },
    { name = 'Style Pages', key = 'stylePages', addonName = 'Tamriel Collections - Archive Style Pages', icon = 'EsoUI/Art/Inventory/inventory_tabIcon_trophy_up.dds' },
    { name = 'Antiquities', key = 'antiquities', addonName = 'Tamriel Collections - Archive Antiquities', icon = 'EsoUI/Art/TreeIcons/gamepad/GP_antiquities_indexIcon_scryable.dds' },
    { name = 'Furnishing Plans', key = 'furnishingPlans', addonName = 'Tamriel Collections - Archive Furnishing Plans', icon = 'EsoUI/Art/Crafting/provisioner_indexIcon_furnishings_up.dds' },
    { name = 'Lorebooks', key = 'lorebooks', addonName = 'Tamriel Collections - Archive Lorebooks', icon = 'EsoUI/Art/ZoneStories/completionTypeIcon_lorebooks.dds' },
}

if not TC.RegisterArchiveModule then
    function TC:RegisterArchiveModule(id, definition)
        if type(id) ~= 'string' or type(definition) ~= 'table' then return false end
        definition.id = id
        self.archiveModules[id] = definition
        if self.questScreen and self.questScreen.OnArchiveModulesChanged then
            self.questScreen:OnArchiveModulesChanged()
        end
        return true
    end
end

if not TC.GetArchiveModule then
    function TC:GetArchiveModule(id)
        return id and self.archiveModules[id] or nil
    end
end

if not TC.IsArchiveModuleInstalled then
    function TC:IsArchiveModuleInstalled(id)
        return self:GetArchiveModule(id) ~= nil
    end
end

if not TC.GetArchiveCategory then
    function TC:GetArchiveCategory(id)
        for _, category in ipairs(self.archiveCategories or {}) do
            if category.key == id then return category end
        end
        return nil
    end
end

-- Keep the older shared map-section protocol available for future modules.
TC.modules = TC.modules or {}
TC.order = TC.order or { 'motifs', 'stylePages', 'antiquities', 'furnishingPlans', 'lorebooks' }
if not TC.RegisterModule then
    function TC:RegisterModule(id, definition)
        if type(id) ~= 'string' or type(definition) ~= 'table' then return false end
        self.modules[id] = definition
        return true
    end
end
if not TC.GetMapSections then
    function TC:GetMapSections(location)
        local sections = {}
        for _, id in ipairs(self.order) do
            local module = self.modules[id]
            if module and type(module.getMapSections) == 'function' then
                local ok, result = pcall(module.getMapSections, location)
                if ok and type(result) == 'table' then
                    for _, section in ipairs(result) do sections[#sections + 1] = section end
                end
            end
        end
        return sections
    end
end
