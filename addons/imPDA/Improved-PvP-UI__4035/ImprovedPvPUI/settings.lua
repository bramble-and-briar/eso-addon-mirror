local addon = {}

local LAM = LibAddonMenu2

function addon:Initialize(settingsName, settingsDisplayName, sv)
    local panelData = {
        type = 'panel',
        name = settingsDisplayName,
        author = '@impda',
    }

    local panel = LAM:RegisterAddonPanel(settingsName, panelData)

    local optionsData = {
        {
            type = 'submenu',
            name = 'Beautiful Campaigns Manager',
            tooltip = 'COME AND FIGHT!',
            controls = {
                {
                    type = 'checkbox',
                    name = 'Enable',
                    getFunc = function() return sv.beautifulCampaignsManager.enabled end,
                    setFunc = function(value) sv.beautifulCampaignsManager.enabled = value end,
                    requiresReload = true,
                },
                {
                    type = 'checkbox',
                    name = 'Always show Icereach',
                    getFunc = function() return sv.beautifulCampaignsManager.showIcereach end,
                    setFunc = function(value) sv.beautifulCampaignsManager.showIcereach = value end,
                    requiresReload = true,
                    tooltip = 'Icereach is "below 50" campaign and will be hidden for characters level 50 and above. Turn ON to show it all the time insted.'
                },
                {
                    type = 'checkbox',
                    name = 'Show tooltip',
                    getFunc = function() return sv.beautifulCampaignsManager.showTooltip end,
                    setFunc = function(value) sv.beautifulCampaignsManager.showTooltip = value end,
                    requiresReload = true,
                },
                {
                    type = 'checkbox',
                    name = '[EXPERIMENTAL] Show bonuses',
                    getFunc = function() return sv.beautifulCampaignsManager.showBonuses end,
                    setFunc = function(value) sv.beautifulCampaignsManager.showBonuses = value end,
                    requiresReload = true,
                },
                {
                    type = 'checkbox',
                    name = '[EXPERIMENTAL] Autotransfer',
                    getFunc = function() return sv.beautifulCampaignsManager.autotransfer end,
                    setFunc = function(value) sv.beautifulCampaignsManager.autotransfer = value end,
                    requiresReload = true,
                },
            },
        },
        {
            type = 'submenu',
            name = 'Keep Tooltip',
            -- tooltip = 'To go Cyrodiil or Imperial City',
            controls = {
                {
                    type = 'checkbox',
                    name = 'Enable',
                    getFunc = function() return sv.keepTooltip.enabled end,
                    setFunc = function(value) sv.keepTooltip.enabled = value end,
                    requiresReload = true,
                },
                {
                    type = 'checkbox',
                    name = 'Add tracker',
                    getFunc = function() return sv.keepTooltip.tracker end,
                    setFunc = function(value) sv.keepTooltip.tracker = value end,
                    requiresReload = true,
                },
                {
                    type = 'checkbox',
                    name = 'Add siege timer',
                    getFunc = function() return sv.keepTooltip.siegeTimer end,
                    setFunc = function(value) sv.keepTooltip.siegeTimer = value end,
                    requiresReload = true,
                },
                {
                    type = 'checkbox',
                    name = 'Add resources levels',
                    getFunc = function() return sv.keepTooltip.resourcesLevels end,
                    setFunc = function(value) sv.keepTooltip.resourcesLevels = value end,
                    requiresReload = true,
                },
                {
                    type = 'checkbox',
                    name = 'Update tooltip once per second',
                    getFunc = function() return sv.keepTooltip.continuousUpdate end,
                    setFunc = function(value) sv.keepTooltip.continuousUpdate = value end,
                    requiresReload = true,
                    tooltip = 'By default, tooltip updated only on MouseIn and MouseOut, enables update every second while mouse over any keep',
                },
                {
                    type = 'checkbox',
                    name = 'Show guild owner',
                    getFunc = function() return sv.keepTooltip.guildOwner end,
                    setFunc = function(value) sv.keepTooltip.guildOwner = value end,
                    requiresReload = true,
                },
                {
                    type = 'checkbox',
                    name = 'Hide resource guild owner',
                    getFunc = function() return sv.keepTooltip.hideResourceGuildOwner end,
                    setFunc = function(value) sv.keepTooltip.hideResourceGuildOwner = value end,
                    requiresReload = true,
                },
                {
                    type = 'checkbox',
                    name = 'Show forward camps timer',
                    getFunc = function() return sv.keepTooltip.forwardCampsTimer end,
                    setFunc = function(value) sv.keepTooltip.forwardCampsTimer = value end,
                    requiresReload = true,
                },
            },
        },
        {
            type = 'submenu',
            name = 'Battle Victories',
            tooltip = 'Customize Battle Victories (crossed swords on map, also known as kill locations)',
            controls = {
                {
                    type = 'checkbox',
                    name = 'Compact',
                    getFunc = function() return sv.battleVictories.compact end,
                    setFunc = function(value) sv.battleVictories.compact = value end,
                    requiresReload = true,
                },
            },
        },
        {
            type = 'submenu',
            name = '3D Labels in IC Sewers',
            -- tooltip = '',
            controls = {
                {
                    type = 'checkbox',
                    name = 'Enable',
                    getFunc = function() return sv.imprialSewersLabels.enabled end,
                    setFunc = function(value) sv.imprialSewersLabels.enabled = value end,
                    requiresReload = true,
                },
                {
                    type = 'dropdown',
                    name = 'Localization',
                    tooltip = [[
Addon Default - Short EN names (without "District").

Ingame Default - Full names in the chosen language (for EN and DE only, for now).

DE (Arboretum) - Same as "Ingame Default," but "Baumgartenbezirk" is replaced with "Arboretum".
                    ]],
                    choices = {'Addon Default', 'Ingame Default', 'DE (Arboretum)'},
                    choicesValues = {'default', 'auto', 'de_special'},
                    getFunc = function() return sv.imprialSewersLabels.localization end,
                    setFunc = function(var) sv.imprialSewersLabels.localization = var end,
                    width = 'full',
                    warning = 'Will need to reload the UI',
                    requiresReload = true,
                },
                {
                    type = 'slider',
                    name = 'Text size (district names)',
                    getFunc = function() return sv.imprialSewersLabels.scale * 100 end,
                    setFunc = function(value)
                        sv.imprialSewersLabels.scale = value / 100
                        IMP_ISL_ScaleLabels(value / 100)
                    end,
                    min = 50,
                    max = 450,
                },
                {
                    type = 'slider',
                    name = 'Text height (district names)',
                    getFunc = function() return sv.imprialSewersLabels.height end,
                    setFunc = function(value)
                        sv.imprialSewersLabels.height = value
                        IMP_ISL_ChangeHeight(value)
                    end,
                    min = 100,
                    max = 1000,
                },
                {
                    type = 'checkbox',
                    name = 'Show banked Tel Vars',
                    getFunc = function() return sv.imprialSewersBankedTelvarsLabels.enabled end,
                    setFunc = function(value) sv.imprialSewersBankedTelvarsLabels.enabled = value end,
                    requiresReload = true,
                },
            },
        },
        {
            type = 'submenu',
            name = '3D Labels for Battlegrounds',
            controls = {
                {
                    type = 'description',
                    text = 'It took much time to actually make it as I had to be lucky enough to visit all maps, so if you find any bug or you have better ideas where to place these labels or better layout in mind - please contact me via ESOUI forum. Enjoy :)',
                },
                {
                    type = 'checkbox',
                    name = 'Enable',
                    getFunc = function() return sv.battlegroundLabels.enabled end,
                    setFunc = function(value) sv.battlegroundLabels.enabled = value end,
                    requiresReload = true,
                }
            },
        },
    }

    local cyrodiilLabels = {}
    cyrodiilLabels[#cyrodiilLabels+1] = {
        type = 'checkbox',
        name = 'Show Banked AP',
        getFunc = function() return sv.cyrodiilLabels.showBankedAP end,
        setFunc = function(value) sv.cyrodiilLabels.showBankedAP = value end,
        requiresReload = true,
    }

    optionsData[#optionsData+1] = {
        type = 'submenu',
        name = 'Cyrodiil 3D Labels',
        -- tooltip = '',
        controls = cyrodiilLabels,
    }

    local klh = {}
    local klhsv = sv.killLocationsHistory

    klh[#klh + 1] = {
		type = 'checkbox',
		name = 'Enable',
		getFunc = function() return klhsv.on end,
		setFunc = function(value) klhsv.on = value end,
		requiresReload = true,
	}

    klh[#klh + 1] = {
		type = 'checkbox',
		name = 'Chat Notifications',
		getFunc = function() return klhsv.chatNotifications end,
		setFunc = function(value) klhsv.chatNotifications = value end,
	}

    local SELECT_CHAT_SETTING_REFERENCE = 'IMP_PVP_UI_SelectChatSettingsReference'
	klh[#klh + 1] = {
		type = 'dropdown',
		name = 'Chat tab',
		choices = IMP_PVP_UI_SHARED.GetTabNames(),
		choicesValues = IMP_PVP_UI_SHARED.GetTabValues(),
		getFunc = function() return klhsv.chatTab end,
		setFunc = function(value) klhsv.chatTab = value end,
		scrollable = true,
		reference = SELECT_CHAT_SETTING_REFERENCE,
	}

    klh[#klh + 1] = {
		type = 'colorpicker',
		name = 'Pin color',
		getFunc = function() return unpack(klhsv.pinColor) end,
		setFunc = function(r, g, b, a)
			klhsv.pinColor = { r, g, b, a }
			IMP_KLH_UpdateMap()
		end
	}

	klh[#klh + 1] = {
		type = 'slider',
		name = 'Duration',
		tooltip = 'How long to show hsitory pins on map (seconds)',
		getFunc = function() return klhsv.retention end,
		setFunc = function(value)
            klhsv.retention = value
            IMP_KLH_UpdateMap()
        end,
		min = 10,
		max = 3600,
		step = 1,
		decimals = 0,
	}

    klh[#klh+1] = {
        type = 'iconpicker',
        name = 'Map Pin Texture',
        choices = {
            -- 'EsoUI/Art/Miscellaneous/Gamepad/gp_bullet.dds',
            'ImprovedPvPUI/killlocations/bullet.dds',
	        'ImprovedPvPUI/killlocations/diamond.dds',
	        'ImprovedPvPUI/killlocations/star.dds',
        },
        choicesTooltips = {
            'Blurry diamond (default ESO small resolution icon)',
            'Diamond (custom with higher resolution)',
            'Star (custom with higher resolution)',
        },
        getFunc = function() return klhsv.pinTexture end,
        setFunc = function(texturePath)
            klhsv.pinTexture = texturePath
            IMP_KLH_SetTexture(texturePath)
        end
    }

    klh[#klh + 1] = {
		type = 'slider',
		name = 'Pin Scale Factor',
		tooltip = 'Changes pin size',
		getFunc = function() return klhsv.pinScale end,
		setFunc = function(value)
            klhsv.pinScale = value
            IMP_KLH_UpdateMap()
        end,
		min = 0.1,
		max = 3,
		step = 0.01,
		decimals = 2,
	}

    optionsData[#optionsData+1] = {
        type = 'submenu',
        name = 'Kill Locations History',
        tooltip = 'Shows pins on map of disappeared kill locations in Cyro and IC and prints info in chat',
        controls = klh,
    }

    LAM:RegisterOptionControls(settingsName, optionsData)

    CALLBACK_MANAGER:RegisterCallback('LAM-PanelOpened', function(panel_)
        if panel_ ~= panel then return end
        IMP_PVP_UI_SHARED.RefreshTabDropdownMenu(SELECT_CHAT_SETTING_REFERENCE)
    end)
end

function IMP_PVP_UI_InitializeSettings(...)
    addon:Initialize(...)
end