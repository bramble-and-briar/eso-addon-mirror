local addon = MOMR
if not addon then return end

local MapPins = addon.internal and addon.internal.mapPins
local LAM = LibAddonMenu2
if not LAM then return end

local defaults = addon.defaults

local panelData = {
    type = "panel",
    name = addon.addOnDisplayName or addon.addOnName,
    author = addon.author or "",
    version = addon.version or "",
}

local optionsData = {
    {   type = "checkbox", name = "Show treasure maps",
        getFunc = function() return addon.savedVars.showTreasure end,
        setFunc = function(value) addon.savedVars.showTreasure = value MapPins:RefreshPins(addon.pinType) end,
        default = defaults.showTreasure },
    {   type = "checkbox", name = "Show crafting surveys",
        getFunc = function() return addon.savedVars.showSurveys end,
        setFunc = function(value) addon.savedVars.showSurveys = value MapPins:RefreshPins(addon.pinType) end,
        default = defaults.showSurveys },
    {   type = "checkbox", name = "Only show items in backpack",
        getFunc = function() return addon.savedVars.backpackOnly end,
        setFunc = function(value)
            addon.savedVars.backpackOnly = value
            -- refresh all pins so every pin type is updated
            MapPins:RefreshPins()
        end,
        default = defaults.backpackOnly },
    {   type = "slider", name = "Pin Size", min = 16, max = 36, step = 1,
        getFunc = function() return addon.savedVars.pinSize end,
        setFunc = function(value) addon.savedVars.pinSize = value MapPins:SetLayoutKey(addon.pinType, "size", value) MapPins:RefreshPins(addon.pinType) end,
        default = defaults.pinSize },
}

function addon:CreateOptions()
    LAM:RegisterAddonPanel(addon.addOnName .. "Panel", panelData)
    LAM:RegisterOptionControls(addon.addOnName .. "Panel", optionsData)
end
