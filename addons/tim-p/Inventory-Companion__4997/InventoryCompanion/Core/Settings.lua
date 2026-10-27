InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local function RefreshProgressBarSettings()
    this.RefreshResourceProgressBars()
    this.UpdateEventRegistry()
    if type(LibAddonMenu2.RefreshAddonPanel) == "function" then
        LibAddonMenu2:RefreshAddonPanel("InventoryCompanionPanel")
    end
end

local function MakeProgressBarColorPicker(name, getColor, setColor, defaultColor)
    return {
        type = "colorpicker",
        name = name,
        getFunc = function()
            local color = getColor()
            return color.r, color.g, color.b, color.a
        end,
        setFunc = function(r, g, b, a)
            setColor({ r = r, g = g, b = b, a = a })
            RefreshProgressBarSettings()
        end,
        default = defaultColor,
    }
end

local function GetStandaloneProgressBarControls()
    local controls = {}
    for _, resource in ipairs(this.GetProgressBarResources()) do
        local resourceKey = resource.key
        local settings = this.GetProgressBarSettings(resourceKey)
        table.insert(controls, {
            type = "checkbox",
            name = "Show " .. resource.name .. " Bar",
            tooltip = "Show this resource in its own movable progress bar. This is independent of the Currency Summary Panel.",
            getFunc = function()
                return this.GetProgressBarSettings(resourceKey).showBar
            end,
            setFunc = function(value)
                this.SetProgressBarSetting(resourceKey, "showBar", value)
                RefreshProgressBarSettings()
            end,
            default = settings.showBar,
        })

        table.insert(controls, {
            type = "submenu",
            name = resource.name .. " Bar Advanced Settings",
            controls = {
                {
                    type = "slider",
                    name = "Warning Threshold (%)",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function()
                        return this.GetProgressBarSettings(resourceKey).warningThreshold * 100
                    end,
                    setFunc = function(value)
                        this.SetProgressBarSetting(resourceKey, "warningThreshold", value / 100)
                        RefreshProgressBarSettings()
                    end,
                    default = settings.warningThreshold * 100,
                },
                {
                    type = "slider",
                    name = "Danger Threshold (%)",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function()
                        return this.GetProgressBarSettings(resourceKey).dangerThreshold * 100
                    end,
                    setFunc = function(value)
                        this.SetProgressBarSetting(resourceKey, "dangerThreshold", value / 100)
                        RefreshProgressBarSettings()
                    end,
                    default = settings.dangerThreshold * 100,
                },
                MakeProgressBarColorPicker(
                    "Normal Bar Color",
                    function() return this.GetProgressBarNormalColor(resourceKey) end,
                    function(color) this.SetProgressBarSetting(resourceKey, "normalColor", color) end,
                    this.GetProgressBarNormalColor(resourceKey)
                ),
            },
        })
    end

    table.insert(controls, {
        type = "header",
        name = "Shared Alert Colors",
    })
    table.insert(controls, MakeProgressBarColorPicker(
        "Warning Color",
        function() return this.GetProgressBarAlertColor("warning") end,
        function(color) this.SetProgressBarAlertColor("warning", color) end,
        { r = 0.95, g = 0.55, b = 0.08, a = 1 }
    ))
    table.insert(controls, MakeProgressBarColorPicker(
        "Danger Color",
        function() return this.GetProgressBarAlertColor("danger") end,
        function(color) this.SetProgressBarAlertColor("danger", color) end,
        { r = 0.85, g = 0.18, b = 0.18, a = 1 }
    ))
    return controls
end

function this.CreateSettingsPanel()
    local LAM = LibAddonMenu2
    local panelName = this.Utils.DisplayName()

    local panelData = {
        type = "panel",
        name = panelName,
        displayName = panelName,
        author = this.Author,
        version = tostring(this.Version),
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local settingsPanel = LAM:RegisterAddonPanel("InventoryCompanionPanel", panelData)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
        if panel == settingsPanel then
            this.state.isCurrencySettingsOpen = true
        end
    end)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel == settingsPanel then
            this.state.isCurrencySettingsOpen = false
        end
    end)

    local optionsData = {
        {
            type = "header",
            name = "Bank & Chest Operations",
        },
        {
            type = "slider",
            name = "Item Transfer Delay (ms)",
            tooltip = "Delay between item transfers. Lower values speed up transfers, but setting it too low may cause ESO to disconnect you.",
            min = 1,
            max = 2000,
            step = 10,
            getFunc = function() return this.accountWide.bankItemDelay end,
            setFunc = function(v) this.accountWide.bankItemDelay = v end,
            default = this.defaultsAccount.bankItemDelay,
        },
        {
            type = "checkbox",
            name = "Auto-Merge Chest Stacks",
            tooltip = "Automatically merge matching backpack items onto existing stacks when opening house storage chests.",
            getFunc = function() return this.accountWide.autoMergeChests end,
            setFunc = function(v) 
                this.accountWide.autoMergeChests = v 
                this.UpdateEventRegistry()
            end,
            default = this.defaultsAccount.autoMergeChests,
        },
        {
            type = "header",
            name = "On-Screen Indicators",
        },
        {
            type = "submenu",
            name = "Item Tracker Panel",
            tooltip = "Configure the movable tracked items HUD window.",
            controls = {
                {
                    type = "checkbox",
                    name = "Show Tracked Items Panel",
                    tooltip = "Master switch to show or hide the Item Tracker window.",
                    getFunc = function() return this.accountWide.showTrackedItemsPanel ~= false end,
                    setFunc = function(v) 
                        this.accountWide.showTrackedItemsPanel = v 
                        this.UpdateEventRegistry()
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.showTrackedItemsPanel,
                },
                {
                    type = "slider",
                    name = "Tracker Group Threshold",
                    tooltip = "Minimum number of visible items required before group headers are rendered. Below this, items render as a flat, alphabetized list.",
                    min = 1,
                    max = 30,
                    step = 1,
                    getFunc = function() return this.accountWide.trackerGroupThreshold or 8 end,
                    setFunc = function(v) 
                        this.accountWide.trackerGroupThreshold = v 
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.trackerGroupThreshold,
                },
				{
                    type = "checkbox",
                    name = "Multiline Item Names",
                    tooltip = "If enabled, long item names will wrap onto multiple lines instead of truncating with ellipses.",
                    getFunc = function() return this.accountWide.wrapTrackedItemNames == true end,
                    setFunc = function(v) 
                        this.accountWide.wrapTrackedItemNames = v 
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.wrapTrackedItemNames,
                },
				{
                    type = "checkbox",
                    name = "Show Empty Tracked Items",
                    tooltip = "If enabled, tracked items with a count of 0 will still be shown.",
                    getFunc = function() return this.accountWide.showEmptyTrackedItems ~= false end,
                    setFunc = function(v) 
                        this.accountWide.showEmptyTrackedItems = v 
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.showEmptyTrackedItems,
                },
                {
                    type = "checkbox",
                    name = "Use Character-Specific List",
                    tooltip = "If enabled, this character uses their own independent tracked items list instead of the shared account-wide list.",
                    getFunc = function() return this.character.useCharacterItemList == true end,
                    setFunc = function(v) 
                        this.character.useCharacterItemList = v 
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                        if this.RefreshTrackedItemsEditor then this.RefreshTrackedItemsEditor() end
                    end,
                    default = this.defaultsCharacter.useCharacterItemList,
                },
            },
        },
        {
            type = "submenu",
            name = "Currency Summary Panel",
            tooltip = "Choose which currencies and capacity indicators appear in the Currency Summary Panel.",
            controls = this.GetCurrencyPanelSettingsControls(),
        },
        {
            type = "submenu",
            name = "Standalone Progress Bars",
            tooltip = "Choose which capped resources have independent movable progress bars.",
            controls = GetStandaloneProgressBarControls(),
        },
        {
            type = "header",
            name = "Debugging",
        },
        {
            type = "checkbox",
            name = "Enable Debug Mode",
            tooltip = "Output verbose debug logs to the chat window.",
            getFunc = function() return this.accountWide.debugEnabled end,
            setFunc = function(v) 
                this.accountWide.debugEnabled = v
            end,
            default = this.defaultsAccount.debugEnabled,
        },
    }

    LAM:RegisterOptionControls("InventoryCompanionPanel", optionsData)
end
