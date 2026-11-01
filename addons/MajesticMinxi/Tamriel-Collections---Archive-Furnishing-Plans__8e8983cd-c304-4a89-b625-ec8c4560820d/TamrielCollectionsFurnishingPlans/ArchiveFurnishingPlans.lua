-- Tamriel Collections - Furnishing Plans starter v0.1.0
-- Registers the standalone module in the shared family. Collection features
-- are intentionally left for a later release.
local TC = TamrielCollections
local MODULE_ID = 'furnishingPlans'
local DISPLAY_NAME = 'Furnishing Plans'

local function ShowStarter(screen, data)
    local category = TC:GetArchiveCategory(MODULE_ID)
    screen:ShowUnavailableCategory(data, category)
    if screen.moduleUnavailableTitle then
        screen.moduleUnavailableTitle:SetText(zo_strupper(DISPLAY_NAME))
    end
    if screen.moduleUnavailableBody then
        screen.moduleUnavailableBody:SetText(
            'Starter module installed.\n\nCollection data is not available in this starter version.')
    end
end

local function InstallStarterBack(screen)
    screen._tcStarterBackHooks = screen._tcStarterBackHooks or {}
    if screen._tcStarterBackHooks[MODULE_ID] then return end
    for _, descriptor in ipairs(screen.keybindStripDescriptor or {}) do
        if descriptor.keybind == 'UI_SHORTCUT_NEGATIVE' then
            local original = descriptor.callback
            descriptor.callback = function()
                if screen.mode == 'starter' and screen.activeModuleId == MODULE_ID then
                    screen:ShowCategories()
                elseif original then
                    return original()
                end
            end
            screen._tcStarterBackHooks[MODULE_ID] = true
            return
        end
    end
end

TC:RegisterArchiveModule(MODULE_ID, {
    displayName = DISPLAY_NAME,
    addonName = 'Tamriel Collections - Archive Furnishing Plans',
    assetRoot = 'TamrielCollectionsFurnishingPlans',
    screenControl = 'TCFQuestJournalTL',
    version = 100,
    supportsSearch = false,
    starter = true,
    onCategoryFocus = function(screen, data)
        InstallStarterBack(screen)
        ShowStarter(screen, data)
    end,
    open = function(screen)
        InstallStarterBack(screen)
        screen.activeModuleId = MODULE_ID
        screen.mode = 'starter'
        screen.styleList:Clear()
        screen.styleList:Commit()
        screen:SetCurrentList(screen.styleList)
        ShowStarter(screen)
        screen:RefreshKeybinds()
    end,
})
