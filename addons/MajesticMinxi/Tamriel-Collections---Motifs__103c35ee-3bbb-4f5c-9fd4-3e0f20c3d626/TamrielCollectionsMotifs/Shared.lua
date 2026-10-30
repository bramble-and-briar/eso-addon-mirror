-- Tamriel Collections shared coordinator, v1 protocol.
-- Intentionally embedded in every future independently installable module.
-- Do not replace a coordinator already initialized by another module.
local TC = _G.TamrielCollections
if type(TC) ~= 'table' then
    TC = { protocol = 1, modules = {}, order = { 'motifs', 'antiquities', 'fragments', 'furnishings', 'lorebooks', 'achievements' } }
    _G.TamrielCollections = TC
end
TC.modules = TC.modules or {}
TC.order = TC.order or { 'motifs', 'antiquities', 'fragments', 'furnishings', 'lorebooks', 'achievements' }
TC.protocol = TC.protocol or 1
if not TC.RegisterModule then
    function TC:RegisterModule(id, definition)
        if type(id) ~= 'string' or type(definition) ~= 'table' then return false end
        if self.modules[id] then return false end
        self.modules[id] = definition
        if self.Refresh then self:Refresh() end
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
