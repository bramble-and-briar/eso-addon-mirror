HarvensExtraIcons = HarvensExtraIcons or {}
HarvensExtraIcons.name = "HarvensExtraIcons"

local function ForceImmediateInjection()
    -- Ensure both the Harven list and our custom list exist
    if not HarvensCustomMapPinsIconList then HarvensCustomMapPinsIconList = {} end
    if not HarvensExtraIconsList then return end
    
    -- Inject the raw paths straight into Harven's list array
    for _, path in ipairs(HarvensExtraIconsList) do
        local alreadyExists = false
        for _, existingPath in ipairs(HarvensCustomMapPinsIconList) do
            if existingPath == path then
                alreadyExists = true
                break
            end
        end
        
        if not alreadyExists then
            table.insert(HarvensCustomMapPinsIconList, path)
        end
    end
end

-- Run immediately at file load
ForceImmediateInjection()

-- Safety Net for UI re-initialization
if HarvensCustomMapPins and HarvensCustomMapPins.InitializeSettings then
    local originalInit = HarvensCustomMapPins.InitializeSettings
    HarvensCustomMapPins.InitializeSettings = function(self, ...)
        ForceImmediateInjection()
        return originalInit(self, ...)
    end
end

