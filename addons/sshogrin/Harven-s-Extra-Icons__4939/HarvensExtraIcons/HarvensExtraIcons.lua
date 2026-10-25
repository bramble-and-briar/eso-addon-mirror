-- Cache the global table locally at the top of the file for faster access speed
local HarvensExtraIcons = HarvensExtraIcons

-- Define the single global namespace safely if it hasn't been initialized yet
if not HarvensExtraIcons then
    HarvensExtraIcons = {}
    _G["HarvensExtraIcons"] = HarvensExtraIcons
end

HarvensExtraIcons.name = "HarvensExtraIcons"

-- Initialize your custom icon subtable here (or populate it in your Icons.lua)
HarvensExtraIcons.List = HarvensExtraIcons.List or {
    -- "path/to/your/DynamicEncounter.dds",
    -- "path/to/your/Skyshard.dds",
}

local function InjectIcons()
    -- Safely verify HarvensCustomMapPins variables exist
    if not HarvensCustomMapPinsIconList then
        HarvensCustomMapPinsIconList = {}
    end

    if not HarvensExtraIcons.List then return end

    -- Inject raw paths using the new subtable structure
    for _, path in ipairs(HarvensExtraIcons.List) do
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

local function OnAddOnLoaded(eventCode, addonName)
    -- Compare against the cached local table's string value
    if addonName ~= HarvensExtraIcons.name then return end

    -- Unregister immediately to save performance
    EVENT_MANAGER:UnregisterForEvent(HarvensExtraIcons.name, EVENT_ADD_ON_LOADED)

    -- Inject icons now that dependencies are verified loaded
    InjectIcons()

    -- Safe Hooking: InitializeSettings is guaranteed to exist now
    if HarvensCustomMapPins and HarvensCustomMapPins.InitializeSettings then
        local originalInit = HarvensCustomMapPins.InitializeSettings
        HarvensCustomMapPins.InitializeSettings = function(self, ...)
            InjectIcons()
            return originalInit(self, ...)
        end
    end
end

-- Register the event listener properly using the local cache reference
EVENT_MANAGER:RegisterForEvent(HarvensExtraIcons.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)



