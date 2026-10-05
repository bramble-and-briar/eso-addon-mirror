local C = EOTU_Config or { NAME_SHORT = "EOTU" }
local addon = _G[C.NAME_SHORT] or EOTU
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
    {   type = "checkbox", name = "Show boss/champion pins",
        getFunc = function() return addon.savedVars.showBosses end,
        setFunc = function(value)
            addon.savedVars.showBosses = value
            MapPins:RefreshPins(addon.pinType)
        end,
        default = defaults.showBosses },
    {   type = "slider", name = "Pin Size", min = 16, max = 36, step = 1,
        getFunc = function() return addon.savedVars.pinSize end,
        setFunc = function(value)
            addon.savedVars.pinSize = value
            MapPins:SetLayoutKey(addon.pinType, "size", value)
            MapPins:RefreshPins(addon.pinType)
        end,
        default = defaults.pinSize },
}

function addon:CreateOptions()
    LAM:RegisterAddonPanel(addon.addOnName .. "Panel", panelData)
    LAM:RegisterOptionControls(addon.addOnName .. "Panel", optionsData)
end
