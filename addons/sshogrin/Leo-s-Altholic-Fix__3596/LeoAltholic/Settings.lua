
LeoAltholic_Settings = ZO_Object:Subclass()
local LAM = LibAddonMenu2

function LeoAltholic_Settings:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function LeoAltholic_Settings:Initialize()
end

function LeoAltholic_Settings:CreatePanel()
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
            getFunc = LeoAltholicChecklistUI.IsEnabled,
            setFunc = LeoAltholicChecklistUI.SetEnabled,
        },
        {
            type = "button",
            name = GetString(SI_OUTFIT_STYLES_BOOK_PREVIEW_KEYBIND),
            func = function() LeoAltholicChecklistUI.ShowUI() end,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(SI_VIDEO_OPTIONS_UI_USE_CUSTOM_SCALE),
            getFunc = LeoAltholicChecklistUI.GetFontScale,
            setFunc = LeoAltholicChecklistUI.SetFontScale,
            min = 80,
            max = 120,
            default = 100,
        },
        {
            type = "checkbox",
            name = GetString(LEOALT_CHECKLIST_UPWARDS),
            default = false,
            getFunc = LeoAltholicChecklistUI.IsUpwards,
            setFunc = LeoAltholicChecklistUI.SetUpwards,
        },
        {
            type = "checkbox",
            name = GetString(SI_GAMEPAD_INTERFACE_OPTIONS_PRIMARY_PLAYER_NAME),
            default = false,
            getFunc = LeoAltholicChecklistUI.DisplayName,
            setFunc = LeoAltholicChecklistUI.SetDisplayName
        },
        {
            type = "checkbox",
            name = GetString(LEOALT_CHECKLIST_HIDE_WHEN_TOOLBAR),
            default = false,
            getFunc = LeoAltholicChecklistUI.IsHideWhenToolbar,
            setFunc = LeoAltholicChecklistUI.SetHideWhenToolbar
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
                    disabled = function() return not LeoAltholicChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholicChecklistUI.GetCraft(CRAFTING_TYPE_ALCHEMY) end,
                    setFunc = function(value)
                        LeoAltholicChecklistUI.SetCraft(CRAFTING_TYPE_ALCHEMY, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_ITEMFILTERTYPE13),
                    default = true,
                    disabled = function() return not LeoAltholicChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholicChecklistUI.GetCraft(CRAFTING_TYPE_BLACKSMITHING) end,
                    setFunc = function(value)
                        LeoAltholicChecklistUI.SetCraft(CRAFTING_TYPE_BLACKSMITHING, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_ITEMFILTERTYPE14),
                    default = true,
                    disabled = function() return not LeoAltholicChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholicChecklistUI.GetCraft(CRAFTING_TYPE_CLOTHIER) end,
                    setFunc = function(value)
                        LeoAltholicChecklistUI.SetCraft(CRAFTING_TYPE_CLOTHIER, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_ITEMFILTERTYPE17),
                    default = true,
                    disabled = function() return not LeoAltholicChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholicChecklistUI.GetCraft(CRAFTING_TYPE_ENCHANTING) end,
                    setFunc = function(value)
                        LeoAltholicChecklistUI.SetCraft(CRAFTING_TYPE_ENCHANTING, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_ITEMFILTERTYPE25),
                    default = true,
                    disabled = function() return not LeoAltholicChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholicChecklistUI.GetCraft(CRAFTING_TYPE_JEWELRYCRAFTING) end,
                    setFunc = function(value)
                        LeoAltholicChecklistUI.SetCraft(CRAFTING_TYPE_JEWELRYCRAFTING, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_ITEMFILTERTYPE18),
                    default = true,
                    disabled = function() return not LeoAltholicChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholicChecklistUI.GetCraft(CRAFTING_TYPE_PROVISIONING) end,
                    setFunc = function(value)
                        LeoAltholicChecklistUI.SetCraft(CRAFTING_TYPE_PROVISIONING, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_ITEMFILTERTYPE15),
                    default = true,
                    disabled = function() return not LeoAltholicChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholicChecklistUI.GetCraft(CRAFTING_TYPE_WOODWORKING) end,
                    setFunc = function(value)
                        LeoAltholicChecklistUI.SetCraft(CRAFTING_TYPE_WOODWORKING, value)
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_STAT_GAMEPAD_RIDING_HEADER_TRAINING),
                    default = false,
                    disabled = function() return not LeoAltholicChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = LeoAltholicChecklistUI.GetRiding,
                    setFunc = LeoAltholicChecklistUI.SetRiding,
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
            getFunc = LeoAltholicToolbarUI.IsEnabled,
            setFunc = LeoAltholicToolbarUI.SetEnabled,
        },
        {
            type = "checkbox",
            name = GetString(LEOALT_BUMP_COMPASS),
            default = false,
            disabled = function() return not LeoAltholicToolbarUI.IsEnabled() end,
            getFunc = LeoAltholicToolbarUI.GetBumpCompass,
            setFunc = LeoAltholicToolbarUI.SetBumpCompass,
        },
        {
            type = "checkbox",
            name = GetString(LEOALT_HIDE_DONE_WRIT),
            default = false,
            disabled = function() return not LeoAltholicToolbarUI.IsEnabled() end,
            getFunc = LeoAltholicToolbarUI.GetHideDoneWrit,
            setFunc = LeoAltholicToolbarUI.SetHideDoneWrit,
        },
        {
            type = "submenu",
            name = GetString(LEOALT_ENTRIES),
            controls = {
                {
                    type = "checkbox",
                    name = GetString(SI_GAMEPAD_PLAYER_INVENTORY_CAPACITY_FOOTER_LABEL),
                    default = true,
                    disabled = function() return not LeoAltholicToolbarUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholicToolbarUI.GetItem(LeoAltholicToolbarUI.items.INVENTORY) end,
                    setFunc = function(value)
                        LeoAltholicToolbarUI.SetItem(LeoAltholicToolbarUI.items.INVENTORY, value)
                        LeoAltholicToolbarUI.RestorePosition()
                        LeoAltholicToolbarUI.update()
                    end,
                },{    --Teva added this section
                    type = "checkbox",
                    name = GetString(SI_INTERACT_OPTION_BANK),
                    default = true,
                    disabled = function() return not LeoAltholicToolbarUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholicToolbarUI.GetItem(LeoAltholicToolbarUI.items.BANKSIZE) end,
                    setFunc = function(value)
                        LeoAltholicToolbarUI.SetItem(LeoAltholicToolbarUI.items.BANKSIZE, value)
                        LeoAltholicToolbarUI.RestorePosition()
                        LeoAltholicToolbarUI.update()
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_STAT_GAMEPAD_RIDING_HEADER_TRAINING),
                    default = true,
                    disabled = function() return not LeoAltholicToolbarUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholicToolbarUI.GetItem(LeoAltholicToolbarUI.items.RIDING) end,
                    setFunc = function(value)
                        LeoAltholicToolbarUI.SetItem(LeoAltholicToolbarUI.items.RIDING, value)
                        LeoAltholicToolbarUI.RestorePosition()
                        LeoAltholicToolbarUI.update()
                    end,
                },{
                    type = "checkbox",
                    name = GetString(SI_GAMEPAD_SMITHING_CURRENT_RESEARCH_HEADER),
                    default = true,
                    disabled = function() return not LeoAltholicToolbarUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholicToolbarUI.GetItem(LeoAltholicToolbarUI.items.RESEARCH) end,
                    setFunc = function(value)
                        LeoAltholicToolbarUI.SetItem(LeoAltholicToolbarUI.items.RESEARCH, value)
                        LeoAltholicToolbarUI.RestorePosition()
                        LeoAltholicToolbarUI.update()
                    end,
                },{
                    type = "checkbox",
                    name = GetString(LEOALT_WRIT),
                    default = true,
                    disabled = function() return not LeoAltholicToolbarUI.IsEnabled() or not LeoAltholicChecklistUI.IsEnabled() end,
                    width = "half",
                    getFunc = function() return LeoAltholicToolbarUI.GetItem(LeoAltholicToolbarUI.items.WRITSTATUS) end,
                    setFunc = function(value)
                        LeoAltholicToolbarUI.SetItem(LeoAltholicToolbarUI.items.WRITSTATUS, value)
                        LeoAltholicToolbarUI.RestorePosition()
                        LeoAltholicToolbarUI.update()
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

function LeoAltholic_Settings_OnMouseEnter(control, tooltip)
    InitializeTooltip(InformationTooltip, control, BOTTOMLEFT, 0, -2, TOPLEFT)
    SetTooltipText(InformationTooltip, tooltip)
end
