--- @class GamepadMiniChatTabsSettingsManager : GamepadMiniChatTabsBaseModule
--- @field panel table? The LibHarvensAddonSettings panel
local GamepadMiniChatTabsSettingsManager = GamepadMiniChatTabsBaseModule:Subclass();

--- Creates a new settings manager instance
--- @param manager GamepadMiniChatTabs The main manager instance
--- @return GamepadMiniChatTabsSettingsManager
function GamepadMiniChatTabsSettingsManager:New(manager)
    local obj = GamepadMiniChatTabsBaseModule.New(self, manager);
    return obj;
end;

--- Initializes the settings manager
--- @param manager GamepadMiniChatTabs The main manager instance
function GamepadMiniChatTabsSettingsManager:Initialize(manager)
    GamepadMiniChatTabsBaseModule.Initialize(self, manager);
    self.panel = nil;
end;

function GamepadMiniChatTabsSettingsManager:OnInitialize()
    if not self:IsChatSystemAvailable() then
        return;
    end;

    self:CreateSettingsPanel();
end;

--- Creates the LibHarvensAddonSettings panel
function GamepadMiniChatTabsSettingsManager:CreateSettingsPanel()
    local manager = self;

    self.panel = LibHarvensAddonSettings:AddAddon("Gamepad Chat",
                                                  {
                                                      allowDefaults = true;
                                                      defaultsFunction = function ()
                                                          manager:ResetToDefaults();
                                                      end;
                                                      allowRefresh = true
                                                  });

    self:InstallNestedSectionSetup();
    self:AddFontSettings();
    self:AddTabManagement();
    self:AddFadeSettings();
end;

--- Adds font and appearance settings
function GamepadMiniChatTabsSettingsManager:AddFontSettings()
    self.panel:AddSetting(
        {
            type = LibHarvensAddonSettings.ST_SECTION;
            label = "Font & Appearance"
        });

    self.panel:AddSetting(
        {
            type = LibHarvensAddonSettings.ST_DROPDOWN;
            label = "Font Size";
            tooltip = "Adjust chat text size.";
            items =
            {
                { name = "Small";  data = GAMEPAD_CHAT_TEXT_SIZE_SETTING_SMALL  };
                { name = "Medium"; data = GAMEPAD_CHAT_TEXT_SIZE_SETTING_MEDIUM };
                { name = "Large";  data = GAMEPAD_CHAT_TEXT_SIZE_SETTING_LARGE  }
            };
            getFunction = function ()
                local currentSize = GetGamepadChatFontSize();
                if currentSize == GAMEPAD_CHAT_TEXT_SIZE_SETTING_SMALL then
                    return "Small";
                elseif currentSize == GAMEPAD_CHAT_TEXT_SIZE_SETTING_LARGE then
                    return "Large";
                else
                    return "Medium";
                end;
            end;
            setFunction = function (control, itemName, itemData)
                local fontSize = itemData.data or itemData;
                SetGamepadChatFontSize(fontSize);
                local chatSystem = self:GetChatSystem();
                if chatSystem then
                    chatSystem:SetFontSize(fontSize);
                end;
            end;
            default = "Medium"
        });
end;

local TAB_MANAGEMENT_SECTION_LABEL = "Tab Management";

--- Keeps tab sections inside Tab Management. LibHarvens SetupSections places every section on the root list.
function GamepadMiniChatTabsSettingsManager:InstallNestedSectionSetup()
    local panel = self.panel;
    local originalSetupSections = LibHarvensAddonSettings.AddonSettings.SetupSections;

    function panel:SetupSections()
        originalSetupSections(self);

        for settingIndex = 1, #self.settings do
            local setting = self.settings[settingIndex];
            local nestUnderLabel = setting.nestUnder;
            if nestUnderLabel then
                for parentIndex = 1, #self.settings do
                    local parentSetting = self.settings[parentIndex];
                    if parentSetting.type == LibHarvensAddonSettings.ST_SECTION and parentSetting.labelText == nestUnderLabel then
                        setting.currentSection = parentSetting;
                        break;
                    end;
                end;
            end;
        end;
    end;
end;

--- Adds a setting and marks it as a child of a parent section
--- @param params table LibHarvens setting params
--- @param nestUnderLabel string? Parent section label
--- @return table setting
function GamepadMiniChatTabsSettingsManager:AddNestedSetting(params, nestUnderLabel)
    local setting = self.panel:AddSetting(params);
    if nestUnderLabel then
        setting.nestUnder = nestUnderLabel;
        if params.type == LibHarvensAddonSettings.ST_SECTION then
            setting.gamepadMiniChatTabsSection = true;
        end;
    end;
    return setting;
end;

--- Adds tab management settings
function GamepadMiniChatTabsSettingsManager:AddTabManagement()
    self.panel:AddSetting(
        {
            type = LibHarvensAddonSettings.ST_SECTION;
            label = TAB_MANAGEMENT_SECTION_LABEL
        });

    local container = self:GetContainer();
    if container and container.windows then
        for tabIndex, window in ipairs(container.windows) do
            self:AddTabNameEditor(tabIndex);
        end;
    end;

    self:AddCreateTabButton();
end;

--- Adds a tab name editor
--- @param tabIndex integer The tab index
function GamepadMiniChatTabsSettingsManager:AddTabNameEditor(tabIndex)
    local manager = self;
    local container = manager:GetContainer();
    if not container then return; end;
    local tabName = container:GetTabName(tabIndex);
    local isPrimaryTab = container:IsPrimary() and tabIndex == 1;

    self:AddNestedSetting(
        {
            type = LibHarvensAddonSettings.ST_SECTION;
            label = "Tab " .. tabIndex .. ": " .. tabName
        },
        TAB_MANAGEMENT_SECTION_LABEL);

    -- Rename edit box
    self.panel:AddSetting(
        {
            type = LibHarvensAddonSettings.ST_EDIT;
            label = "Tab " .. tabIndex .. " Name";
            tooltip = "Enter new name for this tab";
            textType = TEXT_TYPE_ALL;
            maxChars = 50;
            getFunction = function ()
                local innerContainer = manager:GetContainer();
                if not innerContainer then return ""; end;
                return innerContainer:GetTabName(tabIndex);
            end;
            setFunction = function (value)
                if value and value ~= "" then
                    local innerContainer = manager:GetContainer();
                    if not innerContainer then return; end;
                    innerContainer:SetTabName(tabIndex, value);

                    local tabManager = manager.manager:GetModule("tabs");
                    if tabManager then
                        tabManager:RebuildTabs();
                    end;
                end;
            end;
            default = tabName
        });

    self:AddTabChannelFilters(tabIndex);

    -- Remove button (except for primary tab 1)
    if not isPrimaryTab then
        self.panel:AddSetting(
            {
                type = LibHarvensAddonSettings.ST_BUTTON;
                label = "Tab " .. tabIndex .. " - Remove";
                buttonText = "Remove Tab";
                tooltip = "Delete this chat tab";
                clickHandler = function ()
                    local innerContainer = manager:GetContainer();
                    if not innerContainer then return; end;

                    ZO_Dialogs_ShowGamepadDialog("GAMEPAD_CHAT_REMOVE_TAB",
                                                 {
                                                     container = innerContainer;
                                                     tabIndex = tabIndex;
                                                     tabName = innerContainer:GetTabName(tabIndex);
                                                     refreshCallback = function ()
                                                         manager:RebuildSettingsPanel();
                                                     end
                                                 });
                end
            });
    end;
end;

--- Adds channel filter checkboxes for one tab
--- @param tabIndex integer The tab index
function GamepadMiniChatTabsSettingsManager:AddTabChannelFilters(tabIndex)
    local manager = self;
    local optionsManager = manager.manager:GetModule("options");
    if not optionsManager or not optionsManager.GetTabChannelFilters then
        return;
    end;

    local channelFilters = optionsManager:GetTabChannelFilters();
    for _, channelFilter in ipairs(channelFilters) do
        local channels = channelFilter.channels;
        local primaryCategory = channels[1];
        local filterLabel = channelFilter.label;

        self.panel:AddSetting(
            {
                type = LibHarvensAddonSettings.ST_CHECKBOX;
                label = filterLabel;
                tooltip = "Show this channel on this tab";
                getFunction = function ()
                    local innerContainer = manager:GetContainer();
                    if not innerContainer then
                        return false;
                    end;
                    return IsChatContainerTabCategoryEnabled(innerContainer.id, tabIndex, primaryCategory);
                end;
                setFunction = function (enabled)
                    local innerContainer = manager:GetContainer();
                    if not innerContainer or not innerContainer.SetWindowFilterEnabled then
                        return;
                    end;
                    for _, channelCategory in ipairs(channels) do
                        innerContainer:SetWindowFilterEnabled(tabIndex, channelCategory, enabled);
                    end;
                end;
                ignoreDefault = true
            });
    end;
end;

--- Adds create tab button
function GamepadMiniChatTabsSettingsManager:AddCreateTabButton()
    local manager = self;

    self:AddNestedSetting(
        {
            type = LibHarvensAddonSettings.ST_BUTTON;
            label = "Create New Tab";
            buttonText = "Create";
            tooltip = "Add a new chat tab";
            clickHandler = function ()
                local container = manager:GetContainer();
                if not container or not container.AddWindow then
                    return;
                end;

                container:AddWindow(GetString(SI_CHAT_DIALOG_NEW_TAB));
                manager:RebuildSettingsPanel();
            end
        },
        TAB_MANAGEMENT_SECTION_LABEL);
end;

--- Rebuilds the settings panel and keeps the open section selected
function GamepadMiniChatTabsSettingsManager:RebuildSettingsPanel()
    if not self.panel then
        return;
    end;

    local openSectionLabel = nil;
    local settingsList = LibHarvensAddonSettings.list;
    if settingsList and settingsList.currentSection then
        local openSection = settingsList.currentSection;
        if openSection.nestUnder then
            openSectionLabel = openSection.nestUnder;
        elseif type(openSection.labelText) == "string" then
            openSectionLabel = openSection.labelText;
        end;
    end;

    self.panel:RemoveAllSettings();
    self:AddFontSettings();
    self:AddTabManagement();
    self:AddFadeSettings();
    self.panel:SetupSections();

    if openSectionLabel and settingsList then
        local restoredSection = nil;
        for settingIndex = 1, #self.panel.settings do
            local setting = self.panel.settings[settingIndex];
            if setting.type == LibHarvensAddonSettings.ST_SECTION and setting.labelText == openSectionLabel then
                restoredSection = setting;
                break;
            end;
        end;

        if restoredSection then
            settingsList.currentSection = restoredSection;
        else
            settingsList.currentSection = nil;
        end;

        self.panel:CreateControls();
    end;
end;

--- Adds fade settings
function GamepadMiniChatTabsSettingsManager:AddFadeSettings()
    self.panel:AddSetting(
        {
            type = LibHarvensAddonSettings.ST_SECTION;
            label = "Text Fade"
        });

    local manager = self;
    self.panel:AddSetting(
        {
            type = LibHarvensAddonSettings.ST_CHECKBOX;
            label = "Disable Text Fade Out";
            tooltip = "Prevents chat text from fading out over time";
            getFunction = function ()
                return GAMEPAD_MINI_CHAT_TABS:GetDisableTextFade();
            end;
            setFunction = function (value)
                GAMEPAD_MINI_CHAT_TABS:SetDisableTextFade(value);
                local container = manager:GetContainer();
                if container and container.FadeOutLines then
                    container:FadeOutLines();
                end;
            end;
            default = false
        });
end;

--- Resets all settings to defaults
function GamepadMiniChatTabsSettingsManager:ResetToDefaults()
    local container = self:GetContainer();
    if container then
        container:ResetMinAlphaToDefault();
    end;
    SetGamepadChatFontSize(GAMEPAD_CHAT_TEXT_SIZE_SETTING_MEDIUM);
    local chatSystem = self:GetChatSystem();
    if chatSystem then
        chatSystem:SetFontSize(GAMEPAD_CHAT_TEXT_SIZE_SETTING_MEDIUM);
    end;
    GAMEPAD_MINI_CHAT_TABS:SetDisableTextFade(false);
end;

local settingsManager = GamepadMiniChatTabsSettingsManager:New(GAMEPAD_MINI_CHAT_TABS);
GAMEPAD_MINI_CHAT_TABS:RegisterModule("settings", settingsManager);

if not LibHarvensAddonSettings.gamepadMiniChatTabsGoBackInstalled then
    LibHarvensAddonSettings.gamepadMiniChatTabsGoBackInstalled = true;
    local originalGoBack = LibHarvensAddonSettings.GoBack;

    function LibHarvensAddonSettings:GoBack()
        local settingsList = self.list;
        local openSection = settingsList and settingsList.currentSection;
        if openSection and openSection.gamepadMiniChatTabsSection and openSection.currentSection then
            settingsList.currentSection = openSection.currentSection;
            local settingsModule = GAMEPAD_MINI_CHAT_TABS and GAMEPAD_MINI_CHAT_TABS:GetModule("settings");
            if settingsModule and settingsModule.panel then
                settingsModule.panel:CreateControls();
            end;
            PlaySound(SOUNDS.GAMEPAD_MENU_BACK);
            return;
        end;

        originalGoBack(self);
    end;
end;
