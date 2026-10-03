local WR = Wegesruhe
if not WR then return end

local WM = WINDOW_MANAGER
local BLUE_R, BLUE_G, BLUE_B = 127 / 255, 199 / 255, 1

function WR:SetupAddonManagerGear(control, data)
    if not control or not data then return end

    local isWegesruhe = data.addOnFileName == self.name
    local gear = control.wegesruheSettingsGear

    if not gear and isWegesruhe then
        gear = WM:CreateControl(nil, control, CT_BUTTON)
        control.wegesruheSettingsGear = gear
        gear:SetDimensions(30, 26)
        gear:SetAnchor(RIGHT, control, RIGHT, -4, 0)
        gear:SetClickSound("Click")

        -- Use the same bundled DXT5 gear texture and row integration as Randwache.
        -- The icon is independent of ESO's UI font and is attached directly to
        -- Wegesruhe's Add-On Manager row instead of searching visible labels.
        local icon = WM:CreateControl(nil, gear, CT_TEXTURE)
        gear.wegesruheSettingsIcon = icon
        icon:SetDimensions(20, 20)
        icon:SetAnchor(CENTER, gear, CENTER, 0, 0)
        icon:SetTexture("Wegesruhe/textures/settings_gear.dds")
        icon:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
        icon:SetMouseEnabled(false)

        gear:SetHandler("OnClicked", function()
            self:OpenSettings("addonManager")
        end)
        gear:SetHandler("OnMouseEnter", function(selfControl)
            icon:SetColor(1, 1, 1, 1)
            InitializeTooltip(InformationTooltip, selfControl, TOPRIGHT, 0, 0, BOTTOMLEFT)
            SetTooltipText(InformationTooltip, self.L.SETTINGS_GEAR_TOOLTIP)
        end)
        gear:SetHandler("OnMouseExit", function()
            icon:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
            ClearTooltip(InformationTooltip)
        end)
    end

    if gear then
        gear:SetHidden(not isWegesruhe)
    end
end

function WR:PatchAddonManagerDataTypes()
    local manager = _G.ADD_ON_MANAGER
    if not manager or not manager.list or not ZO_ScrollList_GetDataTypeTable then return false end

    -- Type 1 is the normal row. Expanded rows may use dynamically allocated
    -- type IDs, so patch every data type that currently exists.
    for typeId = 1, 64 do
        local dataType = ZO_ScrollList_GetDataTypeTable(manager.list, typeId)
        if dataType and dataType.setupCallback and not dataType.wegesruheSettingsPatched then
            local originalSetup = dataType.setupCallback
            dataType.setupCallback = function(control, data, ...)
                originalSetup(control, data, ...)

                -- The Add-On Manager integration must never be able to break
                -- ESO's list or Wegesruhe's marker functionality.
                pcall(function()
                    if data and data.addOnFileName then
                        self:SetupAddonManagerGear(control, data)
                    elseif control and control.wegesruheSettingsGear then
                        control.wegesruheSettingsGear:SetHidden(true)
                    end
                end)
            end
            dataType.wegesruheSettingsPatched = true
        end
    end
    return true
end

function WR:InitializeAddonListGear()
    if self.addonManagerGearInstalled then return end
    self.addonManagerGearInstalled = true

    local managerClass = _G.ZO_AddOnManager
    if managerClass and ZO_PostHook then
        ZO_PostHook(managerClass, "SetupTypeId", function()
            pcall(function()
                self:PatchAddonManagerDataTypes()
            end)
        end)

        ZO_PostHook(managerClass, "OnShow", function(manager)
            pcall(function()
                self:PatchAddonManagerDataTypes()
                if manager and manager.list and ZO_ScrollList_RefreshVisible then
                    ZO_ScrollList_RefreshVisible(manager.list)
                end
            end)
        end)
    end

    pcall(function()
        self:PatchAddonManagerDataTypes()
    end)
end
