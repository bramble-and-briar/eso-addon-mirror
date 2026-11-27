local LeoAltholic = LeoAltholic
LeoAltholic.Settings = ZO_Object:Subclass()
local LAM = LibAddonMenu2

function LeoAltholic.Settings:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function LeoAltholic.Settings:Initialize()
end

function LeoAltholic.Settings:CreatePanel()
    local OptionsName = "LeoAltholicOptions"
    local panelData = {
        type = "panel",
        name = LeoAltholic.name,
        slashCommand = "/leoaltoptions",
        displayName = "|c39B027"..LeoAltholic.displayName.."|r",
        author = "@LeandroSilva Fix by |c2046e5sshogrin|r",
        version = LeoAltholic.version,
        registerForRefresh = true,
        registerForDefaults = true,
        website = "https://www.esoui.com/downloads/info3596-LeosAltholicFix.html"
    }
    LAM:RegisterAddonPanel(OptionsName, panelData)

    local optionsData = {
        {
            type = "header",
            name = "|c3f7fff"..GetString(SI_GAME_MENU_SETTINGS).."|r"
        },
        {
            type = "checkbox",
            name = "Track inventory items",
            default = true,
            getFunc = function()
                if LeoAltholic.globalData.settings.inventory.enabled == nil then LeoAltholic.globalData.settings.inventory.enabled = true end
                return LeoAltholic.globalData.settings.inventory.enabled
            end,
            setFunc = function(value) LeoAltholic.globalData.settings.inventory.enabled = value end,
        },
        {
            type = "dropdown",
            name = "Character Sort Order",
            tooltip = "Choose how characters are ordered in the LeoAltholic window.",
            choices = { "Creation Order", "Alphabetical (A-Z)", "Alphabetical (Z-A)" },
            choicesValues = { "creation", "alpha_asc", "alpha_desc" },
            getFunc = function()
                LeoAltholic.globalData.settings = LeoAltholic.globalData.settings or {}
                return LeoAltholic.globalData.settings.charSortOrder or "creation"
            end,
            setFunc = function(value)
                LeoAltholic.globalData.settings = LeoAltholic.globalData.settings or {}
                LeoAltholic.globalData.settings.charSortOrder = value
                LeoAltholic.GetCharacters(true)
                if LeoAltholicUI then
                    local lists = {
                        LeoAltholicUI.bioList,
                        LeoAltholicUI.statsList,
                        LeoAltholicUI.championList,
                        LeoAltholicUI.skillsList,
                        LeoAltholicUI.skills2List,
                        LeoAltholicUI.writsList,
                        LeoAltholicUI.invList,
                        LeoAltholicUI.researchList,
                    }
                    for _, listObj in ipairs(lists) do
                        if listObj then
                            listObj.currentSortKey = "queueIndex"
                            listObj.currentSortOrder = ZO_SORT_ORDER_UP
                            listObj:RefreshData()
                        end
                    end
                end
            end,
            default = "creation",
        },
        {
            type = "header",
            name = "|c3f7fff"..GetString(LEOALT_CHECKLIST).."|r"
        },
        {
            type = "checkbox",
            name = GetString(SI_ADDON_MANAGER_ENABLED),
            default = true,
            getFunc = LeoAltholic.ChecklistUI.IsEnabled,
            setFunc = LeoAltholic.ChecklistUI.SetEnabled,
        },
        {
            type = "button",
            name = GetString(SI_OUTFIT_STYLES_BOOK_PREVIEW_KEYBIND),
            func = function() LeoAltholic.ChecklistUI.ShowUI() end,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(SI_VIDEO_OPTIONS_UI_USE_CUSTOM_SCALE),
            getFunc = LeoAltholic.ChecklistUI.GetFontScale,
            setFunc = LeoAltholic.ChecklistUI.SetFontScale,
            min = 80,
            max = 120,
            default = 100,
        },
        {
            type = "checkbox",
            name = GetString(LEOALT_CHECKLIST_UPWARDS),
            default = false,
            getFunc = LeoAltholic.ChecklistUI.IsUpwards,
            setFunc = LeoAltholic.ChecklistUI.SetUpwards,
        },
        {
            type = "checkbox",
            name = GetString(SI_GAMEPAD_INTERFACE_OPTIONS_PRIMARY_PLAYER_NAME),
            default = false,
            getFunc = LeoAltholic.ChecklistUI.DisplayName,
            setFunc = LeoAltholic.ChecklistUI.SetDisplayName
        },
        {
            type = "checkbox",
            name = GetString(LEOALT_CHECKLIST_HIDE_WHEN_TOOLBAR),
            default = false,
            getFunc = LeoAltholic.ChecklistUI.IsHideWhenToolbar,
            setFunc = LeoAltholic.ChecklistUI.SetHideWhenToolbar
        },
        {
            type = "submenu",
            name = GetString(LEOALT_ENTRIES),
            controls = {
                {
                    type = "description",
                    text = GetString(LEOALT_CHAR_CONFIGURATION)
                },{
                    type = "checkbox",
                    name = GetString(SI_ITEMFILTERTYPE16),
                    default = true,
                    disabled = function() return not LeoAltholic.ChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholic.ChecklistUI.GetCraft(CRAFTING_TYPE_ALCHEMY) end,
                    setFunc = function(value)
                        LeoAltholic.ChecklistUI.SetCraft(CRAFTING_TYPE_ALCHEMY, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_ITEMFILTERTYPE13),
                    default = true,
                    disabled = function() return not LeoAltholic.ChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholic.ChecklistUI.GetCraft(CRAFTING_TYPE_BLACKSMITHING) end,
                    setFunc = function(value)
                        LeoAltholic.ChecklistUI.SetCraft(CRAFTING_TYPE_BLACKSMITHING, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_ITEMFILTERTYPE14),
                    default = true,
                    disabled = function() return not LeoAltholic.ChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholic.ChecklistUI.GetCraft(CRAFTING_TYPE_CLOTHIER) end,
                    setFunc = function(value)
                        LeoAltholic.ChecklistUI.SetCraft(CRAFTING_TYPE_CLOTHIER, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_ITEMFILTERTYPE17),
                    default = true,
                    disabled = function() return not LeoAltholic.ChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholic.ChecklistUI.GetCraft(CRAFTING_TYPE_ENCHANTING) end,
                    setFunc = function(value)
                        LeoAltholic.ChecklistUI.SetCraft(CRAFTING_TYPE_ENCHANTING, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_ITEMFILTERTYPE25),
                    default = true,
                    disabled = function() return not LeoAltholic.ChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholic.ChecklistUI.GetCraft(CRAFTING_TYPE_JEWELRYCRAFTING) end,
                    setFunc = function(value)
                        LeoAltholic.ChecklistUI.SetCraft(CRAFTING_TYPE_JEWELRYCRAFTING, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_ITEMFILTERTYPE18),
                    default = true,
                    disabled = function() return not LeoAltholic.ChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholic.ChecklistUI.GetCraft(CRAFTING_TYPE_PROVISIONING) end,
                    setFunc = function(value)
                        LeoAltholic.ChecklistUI.SetCraft(CRAFTING_TYPE_PROVISIONING, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_ITEMFILTERTYPE15),
                    default = true,
                    disabled = function() return not LeoAltholic.ChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholic.ChecklistUI.GetCraft(CRAFTING_TYPE_WOODWORKING) end,
                    setFunc = function(value)
                        LeoAltholic.ChecklistUI.SetCraft(CRAFTING_TYPE_WOODWORKING, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_STAT_GAMEPAD_RIDING_HEADER_TRAINING),
                    default = false,
                    disabled = function() return not LeoAltholic.ChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = LeoAltholic.ChecklistUI.GetRiding,
                    setFunc = LeoAltholic.ChecklistUI.SetRiding,
                }
            }
        },
        {
            type = "header",
            name = "|c3f7fff"..GetString(LEOALT_TOOLBAR).."|r"
        },
        {
            type = "description",
            text = GetString(LEOALT_ACCOUNT_CONFIGURATION)
        },
        {
            type = "checkbox",
            name = GetString(SI_ADDON_MANAGER_ENABLED),
            default = true,
            getFunc = LeoAltholic.ToolbarUI.IsEnabled,
            setFunc = LeoAltholic.ToolbarUI.SetEnabled,
        },
        {
            type = "checkbox",
            name = GetString(LEOALT_BUMP_COMPASS),
            default = false,
            disabled = function() return not LeoAltholic.ToolbarUI.IsEnabled() end,
            getFunc = LeoAltholic.ToolbarUI.GetBumpCompass,
            setFunc = LeoAltholic.ToolbarUI.SetBumpCompass,
        },
        {
            type = "checkbox",
            name = GetString(LEOALT_HIDE_DONE_WRIT),
            default = false,
            disabled = function() return not LeoAltholic.ToolbarUI.IsEnabled() end,
            getFunc = LeoAltholic.ToolbarUI.GetHideDoneWrit,
            setFunc = LeoAltholic.ToolbarUI.SetHideDoneWrit,
        },
        {
            type = "submenu",
            name = GetString(LEOALT_ENTRIES),
            controls = {
                {
                    type = "checkbox",
                    name = GetString(SI_GAMEPAD_PLAYER_INVENTORY_CAPACITY_FOOTER_LABEL),
                    default = true,
                    disabled = function() return not LeoAltholic.ToolbarUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholic.ToolbarUI.GetItem(LeoAltholic.ToolbarUI.items.INVENTORY) end,
                    setFunc = function(value)
                        LeoAltholic.ToolbarUI.SetItem(LeoAltholic.ToolbarUI.items.INVENTORY, value)
                        LeoAltholic.ToolbarUI.RestorePosition()
                        LeoAltholic.ToolbarUI.update()
                    end,
                },{    --Teva added this section
                    type = "checkbox",
                    name = GetString(SI_INTERACT_OPTION_BANK),
                    default = true,
                    disabled = function() return not LeoAltholic.ToolbarUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholic.ToolbarUI.GetItem(LeoAltholic.ToolbarUI.items.BANKSIZE) end,
                    setFunc = function(value)
                        LeoAltholic.ToolbarUI.SetItem(LeoAltholic.ToolbarUI.items.BANKSIZE, value)
                        LeoAltholic.ToolbarUI.RestorePosition()
                        LeoAltholic.ToolbarUI.update()
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_STAT_GAMEPAD_RIDING_HEADER_TRAINING),
                    default = true,
                    disabled = function() return not LeoAltholic.ToolbarUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholic.ToolbarUI.GetItem(LeoAltholic.ToolbarUI.items.RIDING) end,
                    setFunc = function(value)
                        LeoAltholic.ToolbarUI.SetItem(LeoAltholic.ToolbarUI.items.RIDING, value)
                        LeoAltholic.ToolbarUI.RestorePosition()
                        LeoAltholic.ToolbarUI.update()
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_GAMEPAD_SMITHING_CURRENT_RESEARCH_HEADER),
                    default = true,
                    disabled = function() return not LeoAltholic.ToolbarUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholic.ToolbarUI.GetItem(LeoAltholic.ToolbarUI.items.RESEARCH) end,
                    setFunc = function(value)
                        LeoAltholic.ToolbarUI.SetItem(LeoAltholic.ToolbarUI.items.RESEARCH, value)
                        LeoAltholic.ToolbarUI.RestorePosition()
                        LeoAltholic.ToolbarUI.update()
                    end,
                },{
                    type = "checkbox",
                    name = GetString(LEOALT_WRIT),
                    default = true,
                    disabled = function() return not LeoAltholic.ToolbarUI.IsEnabled() or not LeoAltholic.ChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholic.ToolbarUI.GetItem(LeoAltholic.ToolbarUI.items.WRITSTATUS) end,
                    setFunc = function(value)
                        LeoAltholic.ToolbarUI.SetItem(LeoAltholic.ToolbarUI.items.WRITSTATUS, value)
                        LeoAltholic.ToolbarUI.RestorePosition()
                        LeoAltholic.ToolbarUI.update()
                    end,
                }
            }
        },
        {
            type = "header",
            name = "|c3f7fff"..GetString(LEOALT_TRACKED_QUESTS).."|r"
        },
        {
            type = "description",
            text = GetString(LEOALT_ACCOUNT_CONFIGURATION)
        },
        {
            type = "checkbox",
            name = GetString(LEOALT_AUTO_TRACK_WRIT),
            default = true,
            getFunc = function() return LeoAltholic.globalData.settings.tracked.dailyWrits end,
            setFunc = function(value)
                LeoAltholic.globalData.settings.tracked.dailyWrits = value
            end,
        },
        {
            type = "checkbox",
            name = GetString(LEOALT_AUTO_TRACK_DAILY),
            default = true,
            getFunc = function() return LeoAltholic.globalData.settings.tracked.allDaily end,
            setFunc = function(value)
                LeoAltholic.globalData.settings.tracked.allDaily = value
            end,
        },
        {
            type = "header",
            name = "|c3f7fff"..GetString(LEOALT_COMPLETED_RESEARCH).."|r"
        },
        {
            type = "description",
            text = GetString(LEOALT_ACCOUNT_CONFIGURATION)
        },
        {
            type = "checkbox",
            name = GetString(LEOALT_CHAT_ALL),
            tooltip = GetString(LEOALT_CHAT_ALL_TOOLTIP),
            default = true,
            getFunc = function() return LeoAltholic.globalData.settings.completedResearch.chat end,
            setFunc = function(value)
                LeoAltholic.globalData.settings.completedResearch.chat = value
            end,
        },
        {
            type = "checkbox",
            name = GetString(LEOALT_CENTERSCREEN_CURRENT),
            tooltip = GetString(LEOALT_CENTERSCREEN_CURRENT_TOOLTIP),
            default = true,
            getFunc = function() return LeoAltholic.globalData.settings.completedResearch.screen end,
            setFunc = function(value)
                LeoAltholic.globalData.settings.completedResearch.screen = value
            end,
        }
    }
    LAM:RegisterOptionControls(OptionsName, optionsData)
end

function LeoAltholic.Settings_OnMouseEnter(control, tooltip)
    InitializeTooltip(InformationTooltip, control, BOTTOMLEFT, 0, -2, TOPLEFT)
    SetTooltipText(InformationTooltip, tooltip)
end
