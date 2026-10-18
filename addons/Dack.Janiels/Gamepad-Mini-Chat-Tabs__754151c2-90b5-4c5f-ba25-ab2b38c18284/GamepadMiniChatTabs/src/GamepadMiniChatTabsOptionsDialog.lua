--- @class GamepadMiniChatTabsOptionsManager : GamepadMiniChatTabsBaseModule
--- @field chatContainer table? Current chat container being configured
--- @field chatTabIndex integer? Current tab index being configured
--- @field filterEntries table Array of filter entries
local GamepadMiniChatTabsOptionsManager = GamepadMiniChatTabsBaseModule:Subclass();

--- Channel category definitions
--- @class ChatChannelCategory
--- @field category integer The chat category constant
--- @field nameString integer|function The localized string ID or function returning string for the channel name
--- @field channels table? Array of categories that should be toggled together

--- Channels to skip when building filters (handled separately)
local SKIP_CHANNELS =
{
    [CHAT_CATEGORY_GUILD_1] = true;
    [CHAT_CATEGORY_GUILD_2] = true;
    [CHAT_CATEGORY_GUILD_3] = true;
    [CHAT_CATEGORY_GUILD_4] = true;
    [CHAT_CATEGORY_GUILD_5] = true;
    [CHAT_CATEGORY_OFFICER_1] = true;
    [CHAT_CATEGORY_OFFICER_2] = true;
    [CHAT_CATEGORY_OFFICER_3] = true;
    [CHAT_CATEGORY_OFFICER_4] = true;
    [CHAT_CATEGORY_OFFICER_5] = true;
};

--- Channels that should be combined under one filter button
local COMBINED_CHANNELS =
{
    [CHAT_CATEGORY_WHISPER_OUTGOING] = { parentChannel = CHAT_CATEGORY_WHISPER_INCOMING; nameString = SI_CHAT_CHANNEL_NAME_WHISPER };
    [CHAT_CATEGORY_MONSTER_YELL] = { parentChannel = CHAT_CATEGORY_MONSTER_SAY; nameString = SI_CHAT_CHANNEL_NAME_NPC };
    [CHAT_CATEGORY_MONSTER_WHISPER] = { parentChannel = CHAT_CATEGORY_MONSTER_SAY; nameString = SI_CHAT_CHANNEL_NAME_NPC };
    [CHAT_CATEGORY_MONSTER_EMOTE] = { parentChannel = CHAT_CATEGORY_MONSTER_SAY; nameString = SI_CHAT_CHANNEL_NAME_NPC };
};

--- Channel ordering weights for display order
local CHANNEL_ORDERING_WEIGHT =
{
    [CHAT_CATEGORY_SYSTEM] = 5;
    [CHAT_CATEGORY_SAY] = 10;
    [CHAT_CATEGORY_YELL] = 20;
    [CHAT_CATEGORY_WHISPER_INCOMING] = 30;
    [CHAT_CATEGORY_PARTY] = 40;
    [CHAT_CATEGORY_EMOTE] = 50;
    [CHAT_CATEGORY_MONSTER_SAY] = 60;
    [CHAT_CATEGORY_ZONE] = 80;
};

--- Builds the channel categories list dynamically
--- @return table[] Array of channel category entries
local function BuildChannelCategories()
    local entryData = {};
    local lastEntry = CHAT_CATEGORY_HEADER_COMBAT - 1;

    for i = CHAT_CATEGORY_HEADER_CHANNELS, lastEntry do
        if not IsChannelCategoryCommunicationRestricted(i) then
            if SKIP_CHANNELS[i] == nil and GetString("SI_CHATCHANNELCATEGORIES", i) ~= "" then
                if COMBINED_CHANNELS[i] == nil then
                    local isParentOfCombined = false;
                    for combinedChannel, combinedInfo in pairs(COMBINED_CHANNELS) do
                        if combinedInfo.parentChannel == i then
                            isParentOfCombined = true;
                            break;
                        end;
                    end;

                    if not isParentOfCombined then
                        local nameString = GetString("SI_CHATCHANNELCATEGORIES", i);
                        if nameString ~= "" then
                            entryData[i] =
                            {
                                category = i;
                                nameString = function () return GetString("SI_CHATCHANNELCATEGORIES", i); end;
                                channels = { i };
                            };
                        end;
                    end;
                else
                    local parentChannel = COMBINED_CHANNELS[i].parentChannel;
                    if not entryData[parentChannel] then
                        entryData[parentChannel] =
                        {
                            category = parentChannel;
                            nameString = COMBINED_CHANNELS[i].nameString;
                            channels = { parentChannel };
                        };
                    end;
                    table.insert(entryData[parentChannel].channels, i);
                end;
            end;
        end;
    end;

    local sortedEntries = {};
    for _, entry in pairs(entryData) do
        sortedEntries[#sortedEntries + 1] = entry;
    end;

    table.sort(sortedEntries, function (left, right)
        local leftWeight = CHANNEL_ORDERING_WEIGHT[left.category];
        local rightWeight = CHANNEL_ORDERING_WEIGHT[right.category];
        if leftWeight and rightWeight then
            return leftWeight < rightWeight;
        elseif leftWeight then
            return true;
        end;
        return false;
    end);

    return sortedEntries;
end;

--- Resolves a channel entry name to display text
--- @param channelInfo table Channel category entry from BuildChannelCategories
--- @return string
local function GetChannelCategoryLabel(channelInfo)
    if type(channelInfo.nameString) == "function" then
        return channelInfo.nameString();
    end;

    return GetString(channelInfo.nameString);
end;

--- Creates a new options manager instance
--- @param manager GamepadMiniChatTabs The main manager instance
--- @return GamepadMiniChatTabsOptionsManager
function GamepadMiniChatTabsOptionsManager:New(manager)
    local obj = GamepadMiniChatTabsBaseModule.New(self, manager);
    return obj;
end;

--- Initializes the options manager
--- @param manager GamepadMiniChatTabs The main manager instance
function GamepadMiniChatTabsOptionsManager:Initialize(manager)
    GamepadMiniChatTabsBaseModule.Initialize(self, manager);

    self.chatContainer = nil;
    self.chatTabIndex = nil;
    self.filterEntries = {};
end;

--- Called when the module should perform its initialization
function GamepadMiniChatTabsOptionsManager:OnInitialize()
    self:RegisterDialog();
end;

--- Shows the options dialog for a specific chat tab
--- @param chatContainer table The chat container
--- @param chatTabIndex integer The tab index
function GamepadMiniChatTabsOptionsManager:Show(chatContainer, chatTabIndex)
    self.chatContainer = chatContainer;
    self.chatTabIndex = chatTabIndex;

    chatContainer:SetAllowSaveSettings(false);

    ZO_Dialogs_ShowGamepadDialog("GAMEPAD_CHAT_OPTIONS_DIALOG",
                                 {
                                     chatContainer = chatContainer;
                                     chatTabIndex = chatTabIndex;
                                 });
end;

--- Hides the options dialog
function GamepadMiniChatTabsOptionsManager:Hide()
    if self.chatContainer then
        self.chatContainer:SetAllowSaveSettings(true);
        self.chatContainer = nil;
        self.chatTabIndex = nil;
    end;
end;

--- Returns the channel filters that can be toggled for a chat tab
--- @return table[] Array of { label: string, channels: integer[] }
function GamepadMiniChatTabsOptionsManager:GetTabChannelFilters()
    local channelFilters = {};
    local channelCategories = BuildChannelCategories();

    for _, channelInfo in ipairs(channelCategories) do
        local channels = channelInfo.channels or { channelInfo.category };
        local channelLabel = GetChannelCategoryLabel(channelInfo);
        if channelLabel and channelLabel ~= "" then
            channelFilters[#channelFilters + 1] =
            {
                label = channelLabel;
                channels = channels;
            };
        end;
    end;

    local maxGuild = CHAT_CATEGORY_HEADER_GUILDS + MAX_GUILDS - 1;
    for guildCategoryIndex = CHAT_CATEGORY_HEADER_GUILDS, maxGuild do
        local guildIndex = guildCategoryIndex - CHAT_CATEGORY_HEADER_GUILDS + 1;
        local guildId = GetGuildId(guildIndex);
        local guildName = GetGuildName(guildId);

        if guildName ~= "" then
            channelFilters[#channelFilters + 1] =
            {
                label = guildName;
                channels = { guildCategoryIndex };
            };

            if DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_OFFICER_CHAT_WRITE) then
                local officerCategory = guildCategoryIndex + MAX_GUILDS;
                local officerLabel = GetString("SI_CHATCHANNELCATEGORIES", officerCategory);
                if officerLabel and officerLabel ~= "" then
                    channelFilters[#channelFilters + 1] =
                    {
                        label = zo_strformat("<<1>> - <<2>>", guildName, officerLabel);
                        channels = { officerCategory };
                    };
                end;
            end;
        end;
    end;

    return channelFilters;
end;

--- Builds the filter list for the dialog
--- @param dialog table The dialog instance
function GamepadMiniChatTabsOptionsManager:BuildFilterList(dialog)
    local chatContainer = dialog.data.chatContainer;
    local chatTabIndex = dialog.data.chatTabIndex;

    local parametricListEntries = {};

    table.insert(parametricListEntries,
                 {
                     template = "ZO_GamepadMenuEntryTemplate";
                     header = GetString(SI_CHAT_OPTIONS_FILTERS);
                     templateData =
                     {
                         text = "";
                         setup = function () end;
                     };
                 });

    self:BuildChannelFilterEntries(parametricListEntries, chatContainer, chatTabIndex);

    dialog.info.parametricList = parametricListEntries;
    dialog:setupFunc();
end;

--- Builds channel filter entries
--- @param parametricListEntries table The list to append entries to
--- @param chatContainer table The chat container
--- @param chatTabIndex integer The tab index
function GamepadMiniChatTabsOptionsManager:BuildChannelFilterEntries(parametricListEntries, chatContainer, chatTabIndex)
    local channelCategories = BuildChannelCategories();

    for _, channelInfo in ipairs(channelCategories) do
        local category = channelInfo.category;
        local channels = channelInfo.channels or { category };
        local primaryCategory = channels[1];
        local enabled = IsChatContainerTabCategoryEnabled(chatContainer.id, chatTabIndex, primaryCategory);

        local nameText;
        if type(channelInfo.nameString) == "function" then
            nameText = channelInfo.nameString();
        else
            nameText = GetString(channelInfo.nameString);
        end;

        table.insert(parametricListEntries,
                     {
                         template = "ZO_GamepadMenuEntryTemplate";
                         templateData =
                         {
                             text = nameText;
                             category = primaryCategory;
                             channels = channels;
                             enabled = enabled;
                             setup = function (control, data, selected, reselectingDuringRebuild, isEnabled, active)
                                 data:ClearIcons();
                                 if data.enabled then
                                     data:AddIcon("EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_equipped.dds");
                                 end;
                                 ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, isEnabled, active);
                             end;
                             callback = function (dialog)
                                 self:ToggleChannelFilter(dialog, primaryCategory, channels);
                             end;
                         };
                     });
    end;

    self:BuildGuildFilterEntries(parametricListEntries, chatContainer, chatTabIndex);
end;

--- Builds guild channel filter entries
--- @param parametricListEntries table The list to append entries to
--- @param chatContainer table The chat container
--- @param chatTabIndex integer The tab index
function GamepadMiniChatTabsOptionsManager:BuildGuildFilterEntries(parametricListEntries, chatContainer, chatTabIndex)
    local maxGuild = CHAT_CATEGORY_HEADER_GUILDS + MAX_GUILDS - 1;
    for guildCategoryIndex = CHAT_CATEGORY_HEADER_GUILDS, maxGuild do
        local guildIndex = guildCategoryIndex - CHAT_CATEGORY_HEADER_GUILDS + 1;
        local guildId = GetGuildId(guildIndex);
        local guildName = GetGuildName(guildId);

        if guildName ~= "" then
            local guildCategory = guildCategoryIndex;
            local guildEnabled = IsChatContainerTabCategoryEnabled(chatContainer.id, chatTabIndex, guildCategory);

            table.insert(parametricListEntries,
                         {
                             template = "ZO_GamepadMenuEntryTemplate";
                             templateData =
                             {
                                 text = guildName;
                                 category = guildCategory;
                                 enabled = guildEnabled;
                                 setup = function (control, data, selected, reselectingDuringRebuild, isEnabled, active)
                                     data:ClearIcons();
                                     if data.enabled then
                                         data:AddIcon("EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_equipped.dds");
                                     end;
                                     ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, isEnabled, active);
                                 end;
                                 callback = function (dialog)
                                     self:ToggleChannelFilter(dialog, guildCategory);
                                 end;
                             };
                         });

            if DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_OFFICER_CHAT_WRITE) then
                local officerCategory = guildCategory + MAX_GUILDS;
                local officerEnabled = IsChatContainerTabCategoryEnabled(chatContainer.id, chatTabIndex, officerCategory);

                table.insert(parametricListEntries,
                             {
                                 template = "ZO_GamepadMenuEntryTemplate";
                                 templateData =
                                 {
                                     text = GetString("SI_CHATCHANNELCATEGORIES", officerCategory);
                                     category = officerCategory;
                                     enabled = officerEnabled;
                                     setup = function (control, data, selected, reselectingDuringRebuild, isEnabled, active)
                                         data:ClearIcons();
                                         if data.enabled then
                                             data:AddIcon("EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_equipped.dds");
                                         end;
                                         ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, isEnabled, active);
                                     end;
                                     callback = function (dialog)
                                         self:ToggleChannelFilter(dialog, officerCategory);
                                     end;
                                 };
                             });
            end;
        end;
    end;
end;

--- Toggles a channel filter on/off
--- @param dialog table The dialog instance
--- @param category integer The chat category to toggle
--- @param channels table? Array of categories to toggle together (for combined channels)
function GamepadMiniChatTabsOptionsManager:ToggleChannelFilter(dialog, category, channels)
    local chatContainer = dialog.data.chatContainer;
    local chatTabIndex = dialog.data.chatTabIndex;

    channels = channels or { category };
    local primaryCategory = channels[1];
    local currentlyEnabled = IsChatContainerTabCategoryEnabled(chatContainer.id, chatTabIndex, primaryCategory);
    local newState = not currentlyEnabled;

    for _, channelCategory in ipairs(channels) do
        SetChatContainerTabCategoryEnabled(chatContainer.id, chatTabIndex, channelCategory, newState);
    end;

    local selectedData = dialog.entryList:GetTargetData();
    if selectedData and selectedData.category == primaryCategory then
        selectedData.enabled = newState;

        selectedData:ClearIcons();
        if selectedData.enabled then
            selectedData:AddIcon("EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_equipped.dds");
        end;

        local selectedControl = dialog.entryList:GetTargetControl();
        if selectedControl then
            dialog.entryList:RefreshVisible();
        end;
    end;
end;

--- Registers the options dialog
function GamepadMiniChatTabsOptionsManager:RegisterDialog()
    local manager = self;

    ESO_Dialogs["GAMEPAD_CHAT_OPTIONS_DIALOG"] =
    {
        gamepadInfo =
        {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC;
        };

        title =
        {
            text = SI_CHAT_CONFIG_OPTIONS;
        };

        setup = function (dialog)
            manager:BuildFilterList(dialog);
        end;

        parametricList = {};

        parametricListOnSelectionChangedCallback = function (dialog, list)
            local selectedData = list:GetTargetData();
        end;

        parametricListOnActivatedChangedCallback = function (list, isActive)
        end;

        blockDialogReleaseOnPress = true;

        buttons =
        {
            {
                keybind = "DIALOG_PRIMARY";
                text = SI_GAMEPAD_SELECT_OPTION;
                callback = function (dialog)
                    local data = dialog.entryList:GetTargetData();
                    if data and data.callback and not data.isHeader then
                        data.callback(dialog);
                    end;
                end;
            };
            {
                keybind = "DIALOG_NEGATIVE";
                text = SI_DIALOG_CLOSE;
                callback = function (dialog)
                    manager:Hide();
                    ZO_Dialogs_ReleaseDialogOnButtonPress("GAMEPAD_CHAT_OPTIONS_DIALOG");
                end;
            };
        };

        finishedCallback = function (dialog)
            manager:Hide();
        end;
    };
end;

local optionsManager = GamepadMiniChatTabsOptionsManager:New(GAMEPAD_MINI_CHAT_TABS);
GAMEPAD_MINI_CHAT_TABS:RegisterModule("options", optionsManager);
