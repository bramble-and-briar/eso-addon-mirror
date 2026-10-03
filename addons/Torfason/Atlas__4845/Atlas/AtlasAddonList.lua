local AE = AtlasAddon
local T = AE.T
local wm = WINDOW_MANAGER

local function HideGear(control)
    if control and control.atlasSettingsGear then control.atlasSettingsGear:SetHidden(true) end
end

function AE:SetupAddonListGear(control, data)
    if not control then return end
    if type(data) ~= "table" or data.addOnFileName ~= self.name then
        HideGear(control)
        return
    end

    local gear = control.atlasSettingsGear
    if not gear then
        gear = wm:CreateControl(nil, control, CT_BUTTON)
        gear:SetDimensions(30, 26)
        gear:SetAnchor(RIGHT, control, RIGHT, -4, 0)
        gear:SetMouseEnabled(true)
        gear:SetClickSound("Click")

        local texture = wm:CreateControl(nil, gear, CT_TEXTURE)
        texture:SetDimensions(20, 20)
        texture:SetAnchor(CENTER, gear, CENTER, 0, 0)
        texture:SetTexture("Atlas/textures/settings_gear.dds")
        texture:SetColor(0.498, 0.780, 1.000, 1)
        texture:SetMouseEnabled(false)
        gear.texture = texture

        gear:SetHandler("OnMouseEnter", function(self)
            if self.texture then self.texture:SetColor(1, 1, 1, 1) end
            if InformationTooltip then
                InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -6, TOP)
                SetTooltipText(InformationTooltip, T.SETTINGS_GEAR_TOOLTIP or "Open Atlas settings")
            end
        end)
        gear:SetHandler("OnMouseExit", function(self)
            if self.texture then self.texture:SetColor(0.498, 0.780, 1.000, 1) end
            if InformationTooltip then ClearTooltip(InformationTooltip) end
        end)
        gear:SetHandler("OnClicked", function() AE:OpenSettings() end)
        control.atlasSettingsGear = gear
    end

    if gear.texture then gear.texture:SetColor(0.498, 0.780, 1.000, 1) end
    gear:SetHidden(false)
end

function AE:WrapAddonListDataType(typeId)
    if not ADD_ON_MANAGER or not ADD_ON_MANAGER.list or not ZO_ScrollList_GetDataTypeTable then return end
    local dataType = ZO_ScrollList_GetDataTypeTable(ADD_ON_MANAGER.list, typeId)
    if not dataType or dataType.atlasSettingsWrapped or type(dataType.setupCallback) ~= "function" then return end

    local original = dataType.setupCallback
    dataType.setupCallback = function(control, data, ...)
        original(control, data, ...)
        local ok = pcall(AE.SetupAddonListGear, AE, control, data)
        if not ok then HideGear(control) end
    end
    dataType.atlasSettingsWrapped = true
end

function AE:SetupAddonListIntegration()
    if self.addonListIntegrationDone then return end

    -- ESO normally creates the AddOn Manager before EVENT_ADD_ON_LOADED, but keep
    -- this integration independent and retry briefly if its UI is not ready yet.
    if not ADD_ON_MANAGER or not ADD_ON_MANAGER.list then
        self.addonListIntegrationRetries = (self.addonListIntegrationRetries or 0) + 1
        if self.addonListIntegrationRetries <= 10 then
            zo_callLater(function() AE:SetupAddonListIntegration() end, 500)
        end
        return
    end

    self.addonListIntegrationDone = true

    local ok = pcall(function()

        -- Data type 1 is ESO's normal add-on row. Expanded rows receive dynamic
        -- data types; SetupTypeId is wrapped below so those receive the same gear.
        AE:WrapAddonListDataType(1)

        if ZO_AddOnManager and type(ZO_AddOnManager.SetupTypeId) == "function" and not AE.addonListSetupTypeHooked then
            local originalSetupTypeId = ZO_AddOnManager.SetupTypeId
            ZO_AddOnManager.SetupTypeId = function(manager, ...)
                local height, typeId = originalSetupTypeId(manager, ...)
                if manager == ADD_ON_MANAGER and typeId then
                    pcall(AE.WrapAddonListDataType, AE, typeId)
                end
                return height, typeId
            end
            AE.addonListSetupTypeHooked = true
        end

        if ZO_PostHook and not AE.addonListRefreshHooked then
            ZO_PostHook(ADD_ON_MANAGER, "RefreshData", function()
                pcall(AE.WrapAddonListDataType, AE, 1)
            end)
            AE.addonListRefreshHooked = true
        end
    end)

    if not ok then
        -- The integration is intentionally optional. Atlas' map functionality
        -- must never depend on the add-on-list gear.
        self.addonListIntegrationDone = false
        self.addonListIntegrationRetries = (self.addonListIntegrationRetries or 0) + 1
        if self.addonListIntegrationRetries <= 10 then
            zo_callLater(function() AE:SetupAddonListIntegration() end, 500)
        end
    end
end
