local O = OneCraft

function O.SortLevelEntries(entries)
    if O.settings and O.settings.descendingMaterialLevels then
        for i = 1, math.floor(#entries / 2) do
            local j = #entries - i + 1
            entries[i], entries[j] = entries[j], entries[i]
        end
    end
    return entries
end

local function initializeMaterialSorting()
    -- Sort before native Commit restores the selected material and updates controls.
    local refresh = ZO_SharedSmithingCreation.RefreshMaterialList
    ZO_SharedSmithingCreation.RefreshMaterialList = function(self, ...)
        local list = self.materialList
        if not list.oneCraftSorting then
            list.oneCraftSorting = true
            local commit = list.Commit
            list.Commit = function(materials, ...)
                if O.settings.descendingMaterialLevels then
                    table.sort(materials.list, function(a, b)
                        if a.isChampionPoint ~= b.isChampionPoint then return a.isChampionPoint end
                        if a.minCreatesItemOfLevel ~= b.minCreatesItemOfLevel then
                            return a.minCreatesItemOfLevel > b.minCreatesItemOfLevel
                        end
                        return a.materialIndex > b.materialIndex
                    end)
                end
                return commit(materials, ...)
            end
        end
        return refresh(self, ...)
    end
end

local function refreshMaterialSorting()
    for _, module in ipairs({O.Alchemy, O.Enchanting}) do
        if module.view then module.view:Refresh() end
    end
    for _, name in ipairs({"SMITHING", "GAMEPAD_SMITHING"}) do
        local station = _G[name]
        if station and station.creationPanel then station.creationPanel:DirtyAllLists() end
    end
end

local function initializeRefinementCompatibility()
    local addItemToCraft = ZO_SmithingRefinement.AddItemToCraft
    ZO_SmithingRefinement.AddItemToCraft = function(self, ...)
        local inventory = self.inventory
        if inventory:GetCurrentFilterType() ~= SMITHING_FILTER_TYPE_RAW_MATERIALS then
            -- Automation may slot raw materials before the native inventory has
            -- selected its only tab. Force selection even if the bar remembers it.
            ZO_MenuBar_SelectDescriptor(inventory.tabs, SMITHING_FILTER_TYPE_RAW_MATERIALS, true, true)
        end
        return addItemToCraft(self, ...)
    end
end

function O.InitializeSettings()
    O.settings = ZO_SavedVars:NewAccountWide("OneCraftSavedVariables", 1, nil,
        {skipMultiCraftConfirmation = false, descendingMaterialLevels = false}, GetWorldName())
    initializeMaterialSorting()
    initializeRefinementCompatibility()
    local LAM = LibAddonMenu2
    if LAM then
        LAM:RegisterAddonPanel("OneCraftSettings", {type = "panel", name = O.name,
            displayName = O.name, author = "oneDOK", registerForRefresh = true, registerForDefaults = true})
        LAM:RegisterOptionControls("OneCraftSettings", {{
            type = "checkbox",
            name = O.isRussian and "Не подтверждать массовое создание" or O.Translate("Skip multiple-item crafting confirmation"),
            tooltip = O.isRussian and "Создавать несколько предметов в алхимии и зачаровании без дополнительного окна подтверждения."
                or O.Translate("Create multiple items at alchemy and enchanting stations without an additional confirmation dialog."),
            getFunc = function() return O.settings.skipMultiCraftConfirmation end,
            setFunc = function(value) O.settings.skipMultiCraftConfirmation = value end,
            default = false,
        }, {
            type = "checkbox",
            name = O.isRussian and "Материалы по убыванию уровня" or O.Translate("Materials by descending level"),
            tooltip = O.isRussian and "Сортировать списки материалов и уровней от высоких к низким во всех ремесленных станциях."
                or O.Translate("Sort material and level lists from highest to lowest at all crafting stations."),
            getFunc = function() return O.settings.descendingMaterialLevels end,
            setFunc = function(value)
                O.settings.descendingMaterialLevels = value
                refreshMaterialSorting()
            end,
            default = false,
        }})
    end
    local requestCreate = ZO_KeyboardCraftingUtils_RequestCraftingCreate
    ZO_KeyboardCraftingUtils_RequestCraftingCreate = function(station, iterations, ...)
        local ownsStation = (station == ALCHEMY and O.Alchemy.active and station.mode == ZO_ALCHEMY_MODE_CREATION) or
            (station == ENCHANTING and O.Enchanting.CraftingIntegration.OwnsStation())
        if O.settings.skipMultiCraftConfirmation and ownsStation and not IsInGamepadPreferredMode() then
            return station:Create(iterations)
        end
        return requestCreate(station, iterations, ...)
    end
end
