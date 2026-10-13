if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS


local favoritesExcludedListStatusIcon = "/esoui/art/buttons/cancel_down.dds"
local favoritesExcludedListStatusIconText = zo_iconTextFormatNoSpace(favoritesExcludedListStatusIcon, 24, 24, "excluded list", true)

------------------------------------------------------------------------------------------------------------------------
-- Settings menu --
------------------------------------------------------------------------------------------------------------------------

local preventEndlessLoop = false

function FCOChangeStuff.buildAddonMenu()
    local settings = FCOChangeStuff.settingsVars.settings
    if not settings or not FCOChangeStuff.LAM then return false end
    local defaults = FCOChangeStuff.settingsVars.defaults
    local addonVars = FCOChangeStuff.addonVars
    local addonName = addonVars.addonName

    local panelData = {
        type 				= 'panel',
        name 				= addonVars.addonNameMenu,
        displayName 		= addonVars.addonNameMenuDisplay,
        author 				= addonVars.addonAuthor,
        version 			= tostring(addonVars.addonVersion),
        registerForRefresh 	= true,
        registerForDefaults = true,
        slashCommand        = "/fcocss",
        website             = addonVars.addonWebsite,
        feedback            = addonVars.addonFeedback,
        donation            = addonVars.addonDonation,
    }
    FCOChangeStuff.FCOSettingsPanel = FCOChangeStuff.LAM:RegisterAddonPanel(addonName .. "_LAM", panelData)

    local savedVariablesOptions = {
        [1] = 'Each character',
        [2] = 'Account wide'
    }


    local colorMagic = GetItemQualityColor(ITEM_QUALITY_MAGIC)
    local colorArcane = GetItemQualityColor(ITEM_QUALITY_ARCANE)
    local colorArtifact = GetItemQualityColor(ITEM_QUALITY_ARTIFACT)
    local colorLegendary = GetItemQualityColor(ITEM_QUALITY_LEGENDARY)
    local qualityDropDownChoices = {
        [1] = "Off",
        [ITEM_QUALITY_MAGIC] 	 = colorMagic:Colorize(GetString(_G["SI_ITEMQUALITY"  .. tostring(ITEM_QUALITY_MAGIC)])),
        [ITEM_QUALITY_ARCANE] 	 = colorArcane:Colorize(GetString(_G["SI_ITEMQUALITY"  .. tostring(ITEM_QUALITY_ARCANE)])),
        [ITEM_QUALITY_ARTIFACT]  = colorArtifact:Colorize(GetString(_G["SI_ITEMQUALITY"  .. tostring(ITEM_QUALITY_ARTIFACT)])),
        [ITEM_QUALITY_LEGENDARY] = colorLegendary:Colorize(GetString(_G["SI_ITEMQUALITY"  .. tostring(ITEM_QUALITY_LEGENDARY)])),
    }
    FCOChangeStuff.qualityChoices = qualityDropDownChoices
    local qualityDropDownChoicesValues = {
        -1,
        ITEM_QUALITY_MAGIC,
        ITEM_QUALITY_ARCANE,
        ITEM_QUALITY_ARTIFACT,
        ITEM_QUALITY_LEGENDARY,
    }

    local optionsTable =
    {	-- BEGIN OF OPTIONS TABLE

        {
            type = 'description',
            text = 'Change some UI stuff to be hidden or shown in other ways',
        },
        {
            type = 'dropdown',
            reference = "FCOCS_LAM_SETTINGS_SV_SAVETYPE_COMBOBOX",
            name = 'Settings save type',
            tooltip = 'Use account wide settings for all your characters, or save them seperatley for each character?',
            choices = savedVariablesOptions,
            getFunc = function() return savedVariablesOptions[FCOChangeStuff.settingsVars.defaultSettings.saveMode] end,
            setFunc = function(value)
                for i,v in pairs(savedVariablesOptions) do
                    if v == value then
                        FCOChangeStuff.settingsVars.defaultSettings.saveMode = i
                    end
                end
            end,
            requiresReload = true,
        },
--[[
        --TODO 20231114 for debugging LibAddonMenu dropdwn.lua test for multiselection
        --settings._testMultiSelect = { "abc", "def" }
        {
            type = "dropdown",
            name = 'test multiselect',
            tooltip = 'test multiselect',
            choices = { "abc", "bcd", "cde", "def", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q" },
            choicesValues = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
            choicesTooltips = { "abc TT", "bcd TT", "cde TT", "def TT", "","","","","","","","","","","", },
            scrollable = 10,
            getFunc = function() return settings._testMultiSelectChoicesValues end,
            setFunc = function(values)
                settings._testMultiSelectChoicesValues = values
            end,
            default = defaults._testMultiSelectChoicesValues,
            width="full",
            multiSelect = true,
            --multiSelectTextFormatter = SI_COMBO_BOX_DEFAULT_MULTISELECTION_TEXT_FORMATTER,
            --multiSelectNoSelectionText = SI_COMBO_BOX_DEFAULT_NO_SELECTION_TEXT,
            --multiSelectMaxSelections = 2,
            reference = "FCOCS_LAM_TEST_MULTISELECT"
        },

        {
            type    = "orderlistbox",
            name    = "Test order listbox",
            tooltip = "Test order listbox",
            listEntries = settings.orderBoxTest1,
            getFunc = function() return settings.orderBoxTest1 end,
            setFunc = function(orderedList)
                settings.orderBoxTest1 = orderedList
            end,
            minHeight = 100,
            maxHeight = 200,
            width = "half",
            isExtraWide = true,
            showPosition = true,
            disabled = function() return false end,
            default = defaults.orderBoxTest1,
            addEntryDialog = {
                --title="Add new value",
                --text="Enter new value here",
                textType=TEXT_TYPE_ALL,
                --buttonTexture="/esoui/art/buttons/minus_up.dds",
                --maxInputCharacters=3,
                --specialCharacters={"a", "b", "c"},
                --defaultText = "Default text",
                --instructions = ZO_ValidNameInstructions:New(GetControl(self, "NameInstructions"), nil, { NAME_RULE_TOO_SHORT, NAME_RULE_CANNOT_START_WITH_SPACE, NAME_RULE_MUST_END_WITH_LETTER })
                validatesText = true,
                validator = function(text) return text ~= nil and text ~= "" end
            },
            showRemoveEntryButton = true,
            askBeforeRemoveEntry = function() return true end
        },
        {
            type    = "orderlistbox",
            name    = "Test order listbox 2",
            tooltip = "Test order listbox 2",
            listEntries = settings.orderBoxTest1,
            getFunc = function() return settings.orderBoxTest1 end,
            setFunc = function(orderedList)
                settings.orderBoxTest1 = orderedList
            end,
            minHeight = 100,
            maxHeight = 200,
            width = "half",
            isExtraWide = false,
            showPosition = true,
            disabled = function() return false end,
            default = defaults.orderBoxTest1,
            addEntryDialog = {
                title="Add new value 2",
                text="Enter new value 2 here",
                textType=TEXT_TYPE_NUMERIC,
                --buttonTexture="",
                --maxInputCharacters=0,
                --specialCharacters={"a", "b", "c"}
            },
            showRemoveEntryButton = function() return false end,
        },
]]

        --==============================================================================
        {
            type = 'submenu',
            name = 'Keybinds',
            controls = {
                {
                    type = "checkbox",
                    name = 'Compass quest givers',
                    tooltip = 'Enable/Disable keybind to toggle the setings for compass quest givers',
                    getFunc = function() return settings.enableKeybindCompassQuestGivers end,
                    setFunc = function(value) settings.enableKeybindCompassQuestGivers = value
                    end,
                    default = defaults.enableKeybindCompassQuestGivers,
                    width="full",
                },
                {
                    type = "checkbox",
                    name = 'Innocent attack',
                    tooltip = 'Enable/Disable keybind to toggle the setings for combat innocent attack',
                    getFunc = function() return settings.enableKeybindInnocentAttack end,
                    setFunc = function(value) settings.enableKeybindInnocentAttack = value
                    end,
                    default = defaults.enableKeybindInnocentAttack,
                    width="full",
                },

            },
        },
        --==============================================================================
        {
            type = 'header',
            name = 'Overall',
        },
        {
            type = "checkbox",
            name = 'Do not interrupt in world interaction on menu open',
            tooltip = 'If enabled the in world interactions (harvest, etc.) will not be interrupted if you open the menu/inventory.\n\nThis will also disable the character spinning around towards you if you open the inventory.\n\nAttention: This setting will be disabled if you already got the addon \"NoThankYou\" enabled as it provides the same settings with more details! Please use the other addon to control the settings then.',
            getFunc = function() return settings.doNotInterruptInWorldOnMenuOpen end,
            setFunc = function(value) settings.doNotInterruptInWorldOnMenuOpen = value
                FCOChangeStuff.overallSetDoNotInterruptInWorldOnMenuOpen(value)
            end,
            default = defaults.doNotInterruptInWorldOnMenuOpen,
            disabled = function()
                --if NoThankYou addon is enabled then let it control these settings
                return NO_THANK_YOU_VARS ~= nil or FCOChangeStuff.otherAddons.NoThankYou == true
            end,
            width="full",
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Main menu',
        },
        {
            type = "checkbox",
            name = 'Hide crown store button',
            tooltip = 'Hide the crown store button in the main menu',
            getFunc = function() return settings.hideCrownStoreButtonInMainMenu end,
            setFunc = function(value) settings.hideCrownStoreButtonInMainMenu = value
                --FCOChangeStuff.hideStuff()
            end,
            default = defaults.hideCrownStoreButtonInMainMenu,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Hide crown store points',
            tooltip = 'Hide your crown store points info in the main menu',
            getFunc = function() return settings.hideCrownStorePointsInMainMenu end,
            setFunc = function(value) settings.hideCrownStorePointsInMainMenu = value
                --FCOChangeStuff.hideStuff()
            end,
            default = defaults.hideCrownStorePointsInMainMenu,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Hide crown crates button',
            tooltip = 'Hide the crown crates button in the main menu',
            getFunc = function() return settings.hideCrownCratesButtonInMainMenu end,
            setFunc = function(value) settings.hideCrownCratesButtonInMainMenu = value
                --FCOChangeStuff.hideStuff()
            end,
            default = defaults.hideCrownCratesButtonInMainMenu,
            width="full",
        },
        {
            type = "checkbox",
            name = "Hide 'ESO Plus' membership info",
            tooltip = "Hide the 'ESO Plus' membership info in the main menu",
            getFunc = function() return settings.hideCrownStoreMembershipInMainMenu end,
            setFunc = function(value) settings.hideCrownStoreMembershipInMainMenu = value
                --FCOChangeStuff.hideStuff()
            end,
            default = defaults.hideCrownStoreMembershipInMainMenu,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Show addon settings button',
            tooltip = 'Show a button at the main menu which directly opens the LAM addon settings.\n\nThis button won\'t be shown if you got "Votan\'s settings menu" addon enabled!',
            getFunc = function() return settings.showAddonSettingsMainMenuButton end,
            setFunc = function(value) settings.showAddonSettingsMainMenuButton = value
            end,
            default = defaults.showAddonSettingsMainMenuButton,
            width="full",
            disabled = function() return VOTANS_MENU_SETTINGS and VOTANS_MENU_SETTINGS:IsMenuButtonEnabled() end,
            requiresReload = true,
        },
        {
            type = "checkbox",
            name = 'Stop player spinning',
            tooltip = 'Stop the player from spinning around if you open a menu. This will allow you to go on harvesting while opening a menu.',
            getFunc = function() return settings.spinStop end,
            setFunc = function(value) settings.spinStop = value
                FCOChangeStuff.cameraSpinChanges()
            end,
            default = defaults.spinStop,
            width="full",
            --requiresReload = true,
        },
        {
            type = "checkbox",
            name = 'Collections',
            tooltip = 'Stop the player from spinning around if you open the collections book.',
            getFunc = function() return settings.spinStopAtScenes["collectionsBook"] end,
            setFunc = function(value) settings.spinStopAtScenes["collectionsBook"] = value
                FCOChangeStuff.cameraSpinChanges()
            end,
            default = defaults.spinStopAtScenes["collectionsBook"],
            disabled = function() return not settings.spinStop end,
            width="half",
            --requiresReload = true,
        },
        {
            type = "checkbox",
            name = 'Inventory/Character',
            tooltip = 'Stop the player from spinning around if you open the inventory/character.',
            getFunc = function() return settings.spinStopAtScenes["inventory"] end,
            setFunc = function(value) settings.spinStopAtScenes["inventory"] = value
                FCOChangeStuff.cameraSpinChanges()
            end,
            default = defaults.spinStopAtScenes["inventory"],
            disabled = function() return not settings.spinStop end,
            width="half",
            --requiresReload = true,
        },
        {
            type = "checkbox",
            name = 'Stats',
            tooltip = 'Stop the player from spinning around if you open the stats.',
            getFunc = function() return settings.spinStopAtScenes["stats"] end,
            setFunc = function(value) settings.spinStopAtScenes["stats"] = value
                FCOChangeStuff.cameraSpinChanges()
            end,
            default = defaults.spinStopAtScenes["stats"],
            disabled = function() return not settings.spinStop end,
            width="half",
            --requiresReload = true,
        },
        {
            type = "checkbox",
            name = 'All others',
            tooltip = 'Stop the player from spinning around if you open any other scene.',
            getFunc = function() return settings.spinStopAtScenes["allOthers"] end,
            setFunc = function(value) settings.spinStopAtScenes["allOthers"] = value
                FCOChangeStuff.cameraSpinChanges()
            end,
            default = defaults.spinStopAtScenes["allOthers"],
            disabled = function() return not settings.spinStop end,
            width="half",
            --requiresReload = true,
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Notifications',
        },
                {
            type = "checkbox",
            name = 'Add "Mass-handling" button',
            tooltip = 'Add an "Mass handling" context menu button at the notifications top right, where you can "Accept all" or "Decline all" notifications',
            getFunc = function() return settings.addMassHandlingNotificationsButton end,
            setFunc = function(value) settings.addMassHandlingNotificationsButton = value
                FCOChangeStuff.addMassHandlingNotificationsButton()
            end,
            default = defaults.addMassHandlingNotificationsButton,
            width="full",
            requiresReload = true,
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Map',
        },
        {
            type = "checkbox",
            name = 'Reopen map upon mounting',
            tooltip = 'If you mount the map will be closed. This option will reopen the map if you were looking at it, as you started to mount.',
            getFunc = function() return settings.reOpenMapOnMounting end,
            setFunc = function(value) settings.reOpenMapOnMounting = value
                FCOChangeStuff.mapStuff("mount")
            end,
            default = defaults.reOpenMapOnMounting,
            width="full",
        },
        {
            type = "checkbox",
            name = 'En-/Disable all filters button',
            tooltip = 'Show two buttons at the worldmap filters: Enable all/Disable all',
            getFunc = function() return settings.showEnDisableAllFilterButtons end,
            setFunc = function(value) settings.showEnDisableAllFilterButtons = value
                FCOChangeStuff.mapStuff("filter")
            end,
            default = defaults.showEnDisableAllFilterButtons,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Player pin: Ping pong effect',
            tooltip = 'If you open the map the player pin will ping pong in it\'s size between big and small. This will work with a keybind (check the controls) as well, even on \'Votans Minimap\'',
            getFunc = function() return settings.pingPongPlayerPinOnMapOpen end,
            setFunc = function(value) settings.pingPongPlayerPinOnMapOpen = value
                FCOChangeStuff.mapStuff("playerpinpingpong")
            end,
            default = defaults.pingPongPlayerPinOnMapOpen,
            width="half",
        },
        {
            type = "slider",
            name = "Ping pong scaling",
            tooltip = "Set the scaling of the ping pong effect's pin",
            min = 1,
            max = 100,
            decimals = 0,
            autoSelect = true,
            getFunc = function() return settings.pingPongPlayerPinOnMapOpenScaling end,
            setFunc = function(volumeLevel)
                settings.pingPongPlayerPinOnMapOpenScaling = volumeLevel
            end,
            default = defaults.pingPongPlayerPinOnMapOpenScaling,
            width="half",
            disabled = function() return not settings.pingPongPlayerPinOnMapOpen end,
        },
        {
            type = "checkbox",
            name = 'Hide zone story',
            tooltip = 'Hides the zone story window at the map',
            getFunc = function() return settings.hideMapZoneStory end,
            setFunc = function(value) settings.hideMapZoneStory = value
                FCOChangeStuff.mapStuff("hidezonestory")
            end,
            default = defaults.hideMapZoneStory,
            width="full",
        },
        {
            type = "checkbox",
            name = 'BeamMeUp addon can show zone guide',
            tooltip = 'Allows the addon BeamMeUp to show the zone guid via it\'s toggle again',
            getFunc = function() return settings.hideMapZoneStoryBeamMeUpAllowedToShow end,
            setFunc = function(value) settings.hideMapZoneStoryBeamMeUpAllowedToShow = value
            end,
            default = defaults.hideMapZoneStoryBeamMeUpAllowedToShow,
            disabled = function() return not settings.hideMapZoneStory end,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Hide POIs in cities',
            tooltip = 'Will hide all kind of POI textures within subzones like cities.\nIf you currently are in a city while changing this option: Right click the map to show it\'s parent, else the city POI textures won\'t update!\n\nIf you want to remove the default POIs like wayshrine or house icon for the city name, use the default map filters please!',
            getFunc = function() return settings.hidePOIsInCities end,
            setFunc = function(value) settings.hidePOIsInCities = value
                FCOChangeStuff.mapStuff("cityPOIs")
            end,
            default = defaults.hidePOIsInCities,
            width="full",
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Group',
        },
        {
            type = "checkbox",
            name = 'Show real Champion Points',
            tooltip = 'Show the real gained CPs at the level column of your group members & friends list instead of the "maximum value" that ZOs allows to be effective at the moment.',
            getFunc = function() return settings.showRealCPs end,
            setFunc = function(value) settings.showRealCPs = value
                FCOChangeStuff.CPStuff()
            end,
            default = defaults.showRealCPs,
            width="full",
            --requiresReload = true,
        },
        {
            type = "checkbox",
            name = 'Auto decline group elections',
            tooltip = 'Automatically decline any group elections/ready checks as long as this setting is enabled. Can be changed via keybinding as well',
            getFunc = function() return settings.autoDeclineGroupElections end,
            setFunc = function(value) settings.autoDeclineGroupElections = value
                FCOChangeStuff.GroupElectionStuff()
            end,
            default = defaults.autoDeclineGroupElections,
            width="full",
            --requiresReload = true,
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Stable',
        },
        {
            type = "checkbox",
            name = 'Hide feed button: Speed',
            tooltip = 'Hide the stable\'s feed for speed button so you do not accidentally click it',
            getFunc = function() return settings.stableFeedSettings[RIDING_TRAIN_SPEED] end,
            setFunc = function(value) settings.stableFeedSettings[RIDING_TRAIN_SPEED] = value
            end,
            default = defaults.stableFeedSettings[RIDING_TRAIN_SPEED],
            disabled = function() return FCOChangeStuff.stableSkills[RIDING_TRAIN_SPEED].maxed or FCOChangeStuff.checkIfOtherStableButtonsAreMaxedOut(RIDING_TRAIN_SPEED) end,
            width="full",
            --requiresReload = true,
        },
        {
            type = "checkbox",
            name = 'Hide feed button: Stamina',
            tooltip = 'Hide the stable\'s feed for stamina button so you do not accidentally click it',
            getFunc = function() return settings.stableFeedSettings[RIDING_TRAIN_STAMINA] end,
            setFunc = function(value) settings.stableFeedSettings[RIDING_TRAIN_STAMINA] = value
            end,
            default = defaults.stableFeedSettings[RIDING_TRAIN_STAMINA],
            disabled = function() return FCOChangeStuff.stableSkills[RIDING_TRAIN_STAMINA].maxed or FCOChangeStuff.checkIfOtherStableButtonsAreMaxedOut(RIDING_TRAIN_STAMINA) end,
            width="full",
            --requiresReload = true,
        },
        {
            type = "checkbox",
            name = 'Hide feed button: Carry',
            tooltip = 'Hide the stable\'s feed for carry button so you do not accidentally click it',
            getFunc = function() return settings.stableFeedSettings[RIDING_TRAIN_CARRYING_CAPACITY] end,
            setFunc = function(value) settings.stableFeedSettings[RIDING_TRAIN_CARRYING_CAPACITY] = value
            end,
            default = defaults.stableFeedSettings[RIDING_TRAIN_CARRYING_CAPACITY],
            disabled = function() return FCOChangeStuff.stableSkills[RIDING_TRAIN_CARRYING_CAPACITY].maxed or FCOChangeStuff.checkIfOtherStableButtonsAreMaxedOut(RIDING_TRAIN_CARRYING_CAPACITY) end,
            width="full",
            --requiresReload = true,
        },
        --==============================================================================
        {
            type = 'header',
            name = 'Crafting',
        },
        {
            type = "checkbox",
            name = 'Create: Add armor type switch button',
            tooltip = 'Add a button to the crafting stations create panel to switch between light & medium armor',
            getFunc = function() return settings.smithingCreationAddArmorTypeSwitchButton end,
            setFunc = function(value) settings.smithingCreationAddArmorTypeSwitchButton = value
                FCOChangeStuff.smithingCreateAddArmorTypeSwitchButton()
            end,
            default = defaults.smithingCreationAddArmorTypeSwitchButton,
            width="full",
        },
--[[
        {
            type = "checkbox",
            name = 'Improvement with 100%',
            tooltip = 'Automatically try to set the improvement mats used to the maximum so you get a 100% chance',
            getFunc = function() return settings.improvementWith100Percent end,
            setFunc = function(value) settings.improvementWith100Percent = value
                if value then
                    FCOChangeStuff.smithingImproveTrySet100PercentChance()
                end
            end,
            default = defaults.improvementWith100Percent,
            width="full",
        },
]]
        {
            type = "dropdown",
            name = 'Block improvement to quality >=',
            tooltip = 'Block the improvement of items to the chosen, or higher, qualities (=improved item\'s new quality).\n\nAll qualities below the chosen one can be the result of your improvement. But the chosen quality and above (if any above exists) are blocked and wont be allowed.\nA chat message tells you that the item was blocked.',
            choices = qualityDropDownChoices,
            choicesValues = qualityDropDownChoicesValues,
            getFunc = function() return settings.improvementBlockQuality end,
            setFunc = function(value)
                settings.improvementBlockQuality = value
            end,
            default = defaults.improvementBlockQuality,
            width="half",
        },
        {
            type = "checkbox",
            name = 'Allow with SHIFT key',
            tooltip = 'Allow the improvement of the item if you hold the SHIFT key down as you try to improve the item.\n\nAttention: The standard keybinding to start the improvement cannot be used if you press the SHIFT key as SHIFT+E is another keybind then E!\n\nYou need to hold the SHIFT key until the improvement of the item starts! So you need to hold it while clicking on the improve button, and if the dialog asking you \'Are sure to improve the item?\' is used you also need to hold the SHIFT key if you press the dialog\'s  \'Accept\' button!',
            getFunc = function() return settings.improvementBlockQualityExceptionShiftKey end,
            setFunc = function(value) settings.improvementBlockQualityExceptionShiftKey = value
            end,
            default = defaults.improvementBlockQualityExceptionShiftKey,
            disabled = function() return settings.improvementBlockQuality == -1 end,
            width="half",
        },

        {
            type = "checkbox",
            name = 'Change sound volume',
            tooltip = 'Change the sound volume of the game as you start the interaction with a crafting station.\nThe volume will be reset to the value before again as you leave the crafting station.',
            getFunc = function() return settings.changeSoundAtCrafting end,
            setFunc = function(value) settings.changeSoundAtCrafting = value
                FCOChangeStuff.soundLowerAtCraftingCheck()
            end,
            default = defaults.changeSoundAtCrafting,
            width="full",
        },
        {
            type = "slider",
            name = "Crafting sound volume",
            tooltip = "Set the general game volume to this volume level during your craft activities.",
            min = 0,
            max = 100,
            decimals = 0,
            autoSelect = true,
            getFunc = function() return settings.changeSoundAtCraftingVolume end,
            setFunc = function(volumeLevel)
                settings.changeSoundAtCraftingVolume = volumeLevel
            end,
            default = defaults.changeSoundAtCraftingVolume,
            width="full",
            disabled = function() return not settings.changeSoundAtCrafting end,
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Inventory',
        },
        {
            type = "checkbox",
            name = 'Remove \"New item\" icon & animation',
            tooltip = 'Remove the animation and icon for new items in the inventories',
            getFunc = function() return settings.removeNewItemIcon end,
            setFunc = function(value) settings.removeNewItemIcon = value
                FCOChangeStuff.noNewMenuCategoryFlashAnimation()
            end,
            default = defaults.removeNewItemIcon,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Remove \"Not sellable item\" icon & animation',
            tooltip = 'Remove the animation and icon for items which are not sellable at a vendor',
            getFunc = function() return settings.removeSellItemIcon end,
            setFunc = function(value) settings.removeSellItemIcon = value
            end,
            default = defaults.removeSellItemIcon,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Remove \"Learnable item\" icon',
            tooltip = 'Remove the icon for learnable items in the inventories',
            getFunc = function() return settings.removeLearnableItemIcon end,
            setFunc = function(value) settings.removeLearnableItemIcon = value
            end,
            default = defaults.removeLearnableItemIcon,
            width="half",
        },
        {
            type = "checkbox",
            name = 'Keep icon in Loot',
            tooltip = 'Keep the learnabkle icon in the loot window',
            getFunc = function() return settings.keepLearnableItemIconInLoot end,
            setFunc = function(value) settings.keepLearnableItemIconInLoot = value
            end,
            default = defaults.keepLearnableItemIconInLoot,
            disabled = function() return not settings.removeLearnableItemIcon end,
            width="half",
        },
        {
            type = "colorpicker",
            name = '\"Learnable item\" icon color',
            tooltip = 'Change the color of the learnable item icon',
            getFunc = function()
                local learnableIconColor = settings.learnableItemIconColor
                return learnableIconColor.r, learnableIconColor.g, learnableIconColor.b, learnableIconColor.a
            end,
            setFunc = function(r,g,b,a)
                settings.learnableItemIconColor = { r=r, g=g, b=b, a=a }
            end,
            default = function()
                local learnableIconColor = defaults.learnableItemIconColor
                return learnableIconColor.r, learnableIconColor.g, learnableIconColor.b, learnableIconColor.a
            end,
            width="full",
        },
        {
            type = "slider",
            name = "Size (Inventory)",
            tooltip = 'Change the size of the learnable item icon in the inventory',
            min = 4,
            max = 100,
            step = 2,
            getFunc = function() return settings.learnableItemIconPos[BAG_BACKPACK].width end,
            setFunc = function(value)
                local learnabeItemIconPos = FCOChangeStuff.settingsVars.settings.learnableItemIconPos[BAG_BACKPACK]
                learnabeItemIconPos.width = value
                learnabeItemIconPos.height = value
            end,
            default = defaults.learnableItemIconPos[BAG_BACKPACK].width,
            width="full",
        },
        {
            type = "slider",
            name = "Position X (Inventory)",
            tooltip = 'Change the X position of the learnable item icon in the inventory',
            min = -30,
            max = 600,
            step = 1,
            getFunc = function() return settings.learnableItemIconPos[BAG_BACKPACK].x end,
            setFunc = function(value)
                settings.learnableItemIconPos[BAG_BACKPACK].x = value
            end,
            default = defaults.learnableItemIconPos[BAG_BACKPACK].x,
            width="half",
        },
        {
            type = "slider",
            name = "Position Y (Inventory)",
            tooltip = 'Change the Y position of the learnable item icon in the inventory',
            min = -50,
            max = 100,
            step = 1,
            getFunc = function() return settings.learnableItemIconPos[BAG_BACKPACK].y end,
            setFunc = function(value)
                settings.learnableItemIconPos[BAG_BACKPACK].y = value
            end,
            default = defaults.learnableItemIconPos[BAG_BACKPACK].y,
            width="half",
        },
        {
            type = "slider",
            name = "Size (Bank)",
            tooltip = 'Change the size of the learnable item icon in the bank',
            min = 4,
            max = 100,
            step = 2,
            getFunc = function() return settings.learnableItemIconPos[BAG_BANK].width end,
            setFunc = function(value)
                local learnabeItemIconPos = FCOChangeStuff.settingsVars.settings.learnableItemIconPos[BAG_BANK]
                learnabeItemIconPos.width = value
                learnabeItemIconPos.height = value
            end,
            default = defaults.learnableItemIconPos[BAG_BANK].width,
            width="full",
        },
        {
            type = "slider",
            name = "Position X (Bank)",
            tooltip = 'Change the X position of the learnable item icon in the bank',
            min = -30,
            max = 600,
            step = 1,
            getFunc = function() return settings.learnableItemIconPos[BAG_BANK].x end,
            setFunc = function(value)
                settings.learnableItemIconPos[BAG_BANK].x = value
            end,
            default = defaults.learnableItemIconPos[BAG_BANK].x,
            width="half",
        },
        {
            type = "slider",
            name = "Position Y (Bank)",
            tooltip = 'Change the Y position of the learnable item icon in the bank',
            min = -50,
            max = 100,
            step = 1,
            getFunc = function() return settings.learnableItemIconPos[BAG_BANK].y end,
            setFunc = function(value)
                settings.learnableItemIconPos[BAG_BANK].y = value
            end,
            default = defaults.learnableItemIconPos[BAG_BANK].y,
            width="half",
        },
        {
            type = "slider",
            name = "Size (House Bank)",
            tooltip = 'Change the size of the learnable item icon in the house banks',
            min = 4,
            max = 100,
            step = 2,
            getFunc = function() return settings.learnableItemIconPos[BAG_HOUSE_BANK_ONE].width end,
            setFunc = function(value)
                local learnabeItemIconPos = FCOChangeStuff.settingsVars.settings.learnableItemIconPos[BAG_HOUSE_BANK_ONE]
                learnabeItemIconPos.width = value
                learnabeItemIconPos.height = value
            end,
            default = defaults.learnableItemIconPos[BAG_HOUSE_BANK_ONE].width,
            width="full",
        },
        {
            type = "slider",
            name = "Position X (House Bank)",
            tooltip = 'Change the X position of the learnable item icon in the house banks',
            min = -30,
            max = 600,
            step = 1,
            getFunc = function() return settings.learnableItemIconPos[BAG_HOUSE_BANK_ONE].x end,
            setFunc = function(value)
                settings.learnableItemIconPos[BAG_HOUSE_BANK_ONE].x = value
            end,
            default = defaults.learnableItemIconPos[BAG_HOUSE_BANK_ONE].x,
            width="half",
        },
        {
            type = "slider",
            name = "Position Y (House Bank)",
            tooltip = 'Change the Y position of the learnable item icon in the house banks',
            min = -50,
            max = 100,
            step = 1,
            getFunc = function() return settings.learnableItemIconPos[BAG_HOUSE_BANK_ONE].y end,
            setFunc = function(value)
                settings.learnableItemIconPos[BAG_HOUSE_BANK_ONE].y = value
            end,
            default = defaults.learnableItemIconPos[BAG_HOUSE_BANK_ONE].y,
            width="half",
        },
        {
            type = "slider",
            name = "Size (Guild Bank)",
            tooltip = 'Change the size of the learnable item icon in the guild banks',
            min = 4,
            max = 100,
            step = 2,
            getFunc = function() return settings.learnableItemIconPos[BAG_GUILDBANK].width end,
            setFunc = function(value)
                local learnabeItemIconPos = FCOChangeStuff.settingsVars.settings.learnableItemIconPos[BAG_GUILDBANK]
                learnabeItemIconPos.width = value
                learnabeItemIconPos.height = value
            end,
            default = defaults.learnableItemIconPos[BAG_GUILDBANK].width,
            width="full",
        },
        {
            type = "slider",
            name = "Position X (Guild Bank)",
            tooltip = 'Change the X position of the learnable item icon in the guild banks',
            min = -30,
            max = 600,
            step = 1,
            getFunc = function() return settings.learnableItemIconPos[BAG_GUILDBANK].x end,
            setFunc = function(value)
                settings.learnableItemIconPos[BAG_GUILDBANK].x = value
            end,
            default = defaults.learnableItemIconPos[BAG_GUILDBANK].x,
            width="half",
        },
        {
            type = "slider",
            name = "Position Y (Guild Bank)",
            tooltip = 'Change the Y position of the learnable item icon in the guild banks',
            min = -50,
            max = 100,
            step = 1,
            getFunc = function() return settings.learnableItemIconPos[BAG_GUILDBANK].y end,
            setFunc = function(value)
                settings.learnableItemIconPos[BAG_GUILDBANK].y = value
            end,
            default = defaults.learnableItemIconPos[BAG_GUILDBANK].y,
            width="half",
        },
        {
            type = "slider",
            name = "Size (Guild Tradinghouse)",
            tooltip = 'Change the size of the learnable item icon in the guild Tradinghouse',
            min = 4,
            max = 100,
            step = 2,
            getFunc = function() return settings.learnableItemIconPos[990].width end,
            setFunc = function(value)
                local learnabeItemIconPos = FCOChangeStuff.settingsVars.settings.learnableItemIconPos[990]
                learnabeItemIconPos.width = value
                learnabeItemIconPos.height = value
            end,
            default = defaults.learnableItemIconPos[990].width,
            width="full",
        },
        {
            type = "slider",
            name = "Position X (Guild Tradinghouse)",
            tooltip = 'Change the X position of the learnable item icon in the guild Tradinghouse',
            min = -30,
            max = 600,
            step = 1,
            getFunc = function() return settings.learnableItemIconPos[990].x end,
            setFunc = function(value)
                settings.learnableItemIconPos[990].x = value
            end,
            default = defaults.learnableItemIconPos[990].x,
            width="half",
        },
        {
            type = "slider",
            name = "Position Y (Guild Tradinghouse)",
            tooltip = 'Change the Y position of the learnable item icon in the guild Tradinghouse',
            min = -50,
            max = 100,
            step = 1,
            getFunc = function() return settings.learnableItemIconPos[990].y end,
            setFunc = function(value)
                settings.learnableItemIconPos[990].y = value
            end,
            default = defaults.learnableItemIconPos[990].y,
            width="half",
        },
        {
            type = "checkbox",
            name = 'Enable easy destroy',
            tooltip = 'Prefill the destroy dialog for items with the \'Destroy\' text',
            getFunc = function() return settings.easyDestroy end,
            setFunc = function(value) settings.easyDestroy = value
                if value == true then
                    FCOChangeStuff.easyDestroy()
                end
            end,
            default = defaults.easyDestroy,
            width="full",
        },
        {
            type = "checkbox",
            name = "Show \'Scroll up/down\' at scrollbar",
            tooltip = 'Show scroll up and scroll down buttons at the top/bottom of the vertical scrollbars',
            getFunc = function() return settings.showScrollUpDownButtonsAtVerticalScrollbar end,
            setFunc = function(value) settings.showScrollUpDownButtonsAtVerticalScrollbar = value
                FCOChangeStuff.verticalScrollbarHacks()
            end,
            default = defaults.showScrollUpDownButtonsAtVerticalScrollbar,
            width="full",
        },
        --==============================================================================
        {
            type = 'header',
            name = 'Bank',
        },
        {
            type = "checkbox",
            name = 'Show character panel',
            tooltip = 'Show the equipped items at the bank',
            getFunc = function() return settings.showCharacterPanelAtBank end,
            setFunc = function(value) settings.showCharacterPanelAtBank = value
                 FCOChangeStuff.EnableCharacterFragment("bank")
            end,
            default = defaults.showCharacterPanelAtBank,
            width="full",
        },

        --[[
        {
            type = "checkbox",
            name = 'Enable currency deposit helpers',
            tooltip = 'Enables some helpers at the manual currency deposit dialog, at the bank deposit\'s tab',
            getFunc = function() return settings.enableCurrencyDepositDialogHelper end,
            setFunc = function(value) settings.enableCurrencyDepositDialogHelper = value
                FCOChangeStuff.EnableCurrencyDepositDialogHelpers()
            end,
            default = defaults.enableCurrencyDepositDialogHelper,
            width="full",
            requiresReload = true,
        },
        ]]

        {
            type = "checkbox",
            name = 'Enable auto-currency deposit helpers',
            tooltip = 'Enables some automatic currency deposit helpers',
            getFunc = function() return settings.enableCurrencyDepositHelpers end,
            setFunc = function(value) settings.enableCurrencyDepositHelpers = value
                FCOChangeStuff.EnableCurrencyDepositHelpers()
            end,
            default = defaults.enableCurrencyDepositHelpers,
            width="full",
        },
        {
            type = "slider",
            name = 'Threshold: Alliance Points',
            tooltip = 'The threshold value for automatic alliance points currency deposit into your bank.\If your currently worn currency is equal or above this value, all will be deposited into your bank as you open the bank.\nA value of 0 will always deposit all!',
            min = 0,
            max = 1000000,
            step = 1000,
            getFunc = function() return settings.currencyThresholdOnChar[CURT_ALLIANCE_POINTS] end,
            setFunc = function(value) settings.currencyThresholdOnChar[CURT_ALLIANCE_POINTS] = value
            end,
            default = defaults.currencyThresholdOnChar[CURT_ALLIANCE_POINTS],
            disabled = function() return not settings.enableCurrencyDepositHelpers  end,
            width="half",
        },
        {
            type = "slider",
            name = 'Threshold: Tel\'Var stones',
            tooltip = 'The threshold value for automatic Tel\'Var stones currency deposit into your bank.\If your currently worn currency is equal or above this value, all will be deposited into your bank as you open the bank.\nA value of 0 will always deposit all!',
            min = 0,
            max = 1000000,
            step = 1000,
            getFunc = function() return settings.currencyThresholdOnChar[CURT_TELVAR_STONES] end,
            setFunc = function(value) settings.currencyThresholdOnChar[CURT_TELVAR_STONES] = value
            end,
            default = defaults.currencyThresholdOnChar[CURT_TELVAR_STONES],
            disabled = function() return not settings.enableCurrencyDepositHelpers  end,
            width="half",
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Guild bank',
        },
        {
            type = "checkbox",
            name = 'Show character panel',
            tooltip = 'Show the equipped items at the guild bank',
            getFunc = function() return settings.showCharacterPanelAtGuildBank end,
            setFunc = function(value) settings.showCharacterPanelAtGuildBank = value
                 FCOChangeStuff.EnableCharacterFragment("guildbank")
            end,
            default = defaults.showCharacterPanelAtGuildBank,
            width="full",
        },
        --==============================================================================
        {
            type = 'header',
            name = 'Guild history',
        },
        {
            type = "checkbox",
            name = 'Add first/last page to navigation',
            tooltip = 'Add buttons for the first and the last page to the guild history navigation footer. The last page button can only be shown if you have received all events of the active category (via the \'Receive more\' keybind)!\nIf this is enabled then presing the get more keybind will automatically advanced to the last page (if possible).',
            getFunc = function() return settings.addGuildHistoryNavigationFirstAndLastPage end,
            setFunc = function(value) settings.addGuildHistoryNavigationFirstAndLastPage = value
                 FCOChangeStuff.GuildHistoryNavigationHelper()
            end,
            default = defaults.addGuildHistoryNavigationFirstAndLastPage,
            width="full",
        },
        --==============================================================================
        {
            type = 'header',
            name = 'Chat',
        },
        {
            type = "checkbox",
            name = 'Disable notification animation',
            tooltip = 'Disable the animation which makes the notifications button glow if new notifications are unread.',
            getFunc = function() return settings.disableChatNotificationAnimation end,
            setFunc = function(value) settings.disableChatNotificationAnimation = value
                FCOChangeStuff.chatDisableNotificationAnimation()
            end,
            default = defaults.disableChatNotificationAnimation,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Disable new notification sound',
            tooltip = 'Disable the sound for new notifications.',
            getFunc = function() return settings.disableChatNotificationSound end,
            setFunc = function(value) settings.disableChatNotificationSound = value
                FCOChangeStuff.chatDisableNotificationSound()
            end,
            default = defaults.disableChatNotificationSound,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Blacklist chat texts',
            tooltip = 'Enter chat texts in the edit box below. Each row (split by a carriage return) is one text which will be searched in the incoming chat messages. If the text is found the whole chat message will be not shown to you!\n\nEnabling/Disabling this function needs you to reload the UI!',
            getFunc = function() return settings.enableChatBlacklist end,
            setFunc = function(value) settings.enableChatBlacklist = value
            end,
            default = defaults.enableChatBlacklist,
            requiresReload = true,
            width="full",
        },
        {
            type = "editbox",
            name = "Chat blacklist key words/text",
            tooltip = "Enter the text messages, or parts/words of the messages here, which should be blacklisted in the chat.\nEach new word/phrase needs to be seperated via the carriage return (line feed/return key)!",
            isMultiline = true,
            getFunc = function()
                return settings.chatKeyWords
            end,
            setFunc = function(value)
                settings.chatKeyWords = value
                FCOChangeStuff.blacklistKeyWords = { zo_strsplit("\n", value) }
            end,
            default = defaults.chatKeyWords,
            disabled = function() return not settings.enableChatBlacklist end,
        },
        {
            type = "checkbox",
            name = 'Blacklist whispers',
            tooltip = 'Should incoming whisper messages be checked against your blacklist too?',
            getFunc = function() return settings.enableChatBlacklistForWhispers end,
            setFunc = function(value) settings.enableChatBlacklistForWhispers = value
            end,
            default = defaults.enableChatBlacklistForWhispers,
            disabled = function() return not settings.enableChatBlacklist end,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Blacklist group',
            tooltip = 'Should incoming group messages be checked against your blacklist too?',
            getFunc = function() return settings.enableChatBlacklistForGroup end,
            setFunc = function(value) settings.enableChatBlacklistForGroup = value
            end,
            default = defaults.enableChatBlacklistForGroup,
            disabled = function() return not settings.enableChatBlacklist end,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Blacklist guilds',
            tooltip = 'Should incoming guild and officer messages be checked against your blacklist too?',
            getFunc = function() return settings.enableChatBlacklistForGuilds end,
            setFunc = function(value) settings.enableChatBlacklistForGuilds = value
            end,
            default = defaults.enableChatBlacklistForGuilds,
            disabled = function() return not settings.enableChatBlacklist end,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Show info in chat',
            tooltip = 'Show the time, posting person, text and found keyword of the blacklisted text in the system chat (addon output)?',
            getFunc = function() return settings.blacklistedTextToChat end,
            setFunc = function(value) settings.blacklistedTextToChat = value
            end,
            default = defaults.blacklistedTextToChat,
            disabled = function() return not settings.enableChatBlacklist end,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Reminder: Whisper & flagged offline',
            tooltip = 'Show a reminder message on screen if you are whispering to someone and are flagged as offline',
            getFunc = function() return settings.enableChatWhisperAndFlaggedAsOfflineReminder end,
            setFunc = function(value) settings.enableChatWhisperAndFlaggedAsOfflineReminder = value
                FCOChangeStuff.chatWhisperAndFlaggedAsOffline()
            end,
            default = defaults.enableChatWhisperAndFlaggedAsOfflineReminder,
            width="full",
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Skills',
        },
        {
            type = "checkbox",
            name = 'Enable skill line context menu',
            tooltip = 'Enables the context menu at skill line headers (e.g. \"Bow\").',
            getFunc = function() return settings.enableSkillLineContextMenu end,
            setFunc = function(value) settings.enableSkillLineContextMenu = value
            end,
            default = defaults.enableSkillLineContextMenu,
            width="full",
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Action bars',
        },
        {
            type = "checkbox",
            name = 'Enable reposition of ability bar backRow timers',
            tooltip = 'Enable reposition of action slot timers of the backRow, which are shown if you have enabled the ability bar timers at the combat settings + enabled the ability bar backrow',
            getFunc = function() return settings.repositionActionSlotTimers end,
            setFunc = function(value)
                settings.repositionActionSlotTimers = value
            end,
            default = defaults.repositionActionSlotTimers,
            width="full",
            disabled = function()
                return not GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_TIMERS) or not GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_BACK_ROW)
            end,
            requiresReload = true,
        },
        {
            type = "checkbox",
            name = 'Show time left as number too',
            tooltip = 'Show the time left as a number above the icon of the backRow skill timer',
            getFunc = function() return settings.showActionSlotTimersTimeLeftNumber end,
            setFunc = function(value)
                settings.showActionSlotTimersTimeLeftNumber = value
            end,
            default = defaults.showActionSlotTimersTimeLeftNumber,
            width="full",
            disabled = function() return not settings.repositionActionSlotTimers end,
        },
        {
            type = "editbox",
            name = "Offset X",
            tooltip = "The offset on the X axis. Default value is 0.",
            isMultiline = false,
            getFunc = function()
                return settings.repositionActionSlotTimersOffset.x
            end,
            setFunc = function(value)
                if preventEndlessLoop == true then
                    settings.repositionActionSlotTimersOffset.x = value
                    preventEndlessLoop = false
                    return
                end
                local valueInt = tonumber(value)
                local screenWidth = GuiRoot:GetWidth()
                local screenXOffsetMin = ZO_ActionBar1:GetLeft() * -1
                local screenXOffsetMax = screenWidth + screenXOffsetMin
                if valueInt < screenXOffsetMin or valueInt > screenXOffsetMax then
                    value = "0"
                    preventEndlessLoop = true
                    FCOCHANGESTUFF_repositionActionSlotTimersOffsetX_EditBox:UpdateValue(value)
                else
                    settings.repositionActionSlotTimersOffset.x = value
                end
            end,
            width ="half",
            textType = TEXT_TYPE_NUMERIC,
            default = defaults.repositionActionSlotTimersOffset.x,
            disabled = function() return not settings.repositionActionSlotTimers end,
            reference = "FCOCHANGESTUFF_repositionActionSlotTimersOffsetX_EditBox"
        },
        {
            type = "editbox",
            name = "Offset Y",
            tooltip = "The offset on the Y axis. Default value is 0.",
            isMultiline = false,
            getFunc = function()
                return settings.repositionActionSlotTimersOffset.y
            end,
            setFunc = function(value)
                if preventEndlessLoop == true then
                    settings.repositionActionSlotTimersOffset.y = value
                    preventEndlessLoop = false
                    return
                end
                local valueInt = tonumber(value)
                local screenHeight = GuiRoot:GetHeight()
                local screenYOffsetMin = ZO_ActionBar1:GetTop() * -1
                local screenYOffsetMax = screenHeight + screenYOffsetMin
--d(">valueInt: " ..tostring(valueInt) ..", screenYOffsetMin: " ..tostring(screenYOffsetMin) .. ", screenYOffsetMax: " ..tostring(screenYOffsetMax))
                if valueInt < screenYOffsetMin or valueInt > screenYOffsetMax then
                    value = "0"
                    preventEndlessLoop = true
                    FCOCHANGESTUFF_repositionActionSlotTimersOffsetY_EditBox:UpdateValue(value)
                else
                    settings.repositionActionSlotTimersOffset.y = value
                end
            end,
            width ="half",
            textType = TEXT_TYPE_NUMERIC,
            default = defaults.repositionActionSlotTimersOffset.y,
            disabled = function() return not settings.repositionActionSlotTimers end,
            reference = "FCOCHANGESTUFF_repositionActionSlotTimersOffsetY_EditBox"
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Login/Reloadui',
        },
        {
            type = "checkbox",
            name = 'Remove enlightened sound',
            tooltip = 'Silence the enlightened sound upon login/reloadui',
            getFunc = function() return settings.noEnlightenedSound end,
            setFunc = function(value) settings.noEnlightenedSound = value
                FCOChangeStuff.noEnlightenedSound()
            end,
            default = defaults.noEnlightenedSound,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Hide crown store advertisements',
            tooltip = 'Hide the crown store advertisements popup after login',
            getFunc = function() return settings.noShopAdvertisementPopup end,
            setFunc = function(value) settings.noShopAdvertisementPopup = value
                FCOChangeStuff.noShopAdvertisement()
            end,
            default = defaults.noShopAdvertisementPopup,
            width="full",
        },
        --==============================================================================
        {
            type = 'header',
            name = 'Battleground',
        },
        {
            type = "checkbox",
            name = 'Make HUD movable',
            tooltip = 'Enable the mouse drag&drop move of the battleground HUD',
            getFunc = function() return settings.enableBGHUDMoveable end,
            setFunc = function(value) settings.enableBGHUDMoveable = value
                FCOChangeStuff.BGHUDMoveable()
            end,
            default = defaults.enableBGHUDMoveable,
            width="full",
        },
        {
            type = "button",
            name = 'Reset x & y',
            tooltip = 'Reset the x & y coordinates of the battleground HUD to their default values',
            func = function(value)
                FCOChangeStuff.BGHUDReset()
            end,
            isDangerous = true,
            width = "full",
            warning = "Do you really want to reset the x & y coordinates?",
        },
        --==============================================================================
        {
            type = 'header',
            name = 'Tooltips',
        },
        {
            type = "slider",
            name = 'Item tooltip border width',
            tooltip = 'Change the item tooltips border width. Default value: 416',
            min = 100,
            max = 1440,
            step = 1,
            getFunc = function() return settings.tooltipSizeItemBorder end,
            setFunc = function(value) settings.tooltipSizeItemBorder = value
                FCOChangeStuff.tooltipBorderSizeHack()
            end,
            default = defaults.tooltipSizeItemBorder,
            width="full",
        },
        {
            type = "slider",
            name = 'Popup tooltip border width',
            tooltip = 'Change the popup tooltips border width. Default value: 416',
            min = 100,
            max = 1440,
            step = 1,
            getFunc = function() return settings.tooltipSizePopupBorder end,
            setFunc = function(value) settings.tooltipSizePopupBorder = value
                FCOChangeStuff.tooltipBorderSizeHack()
            end,
            default = defaults.tooltipSizePopupBorder,
            width="full",
        },
        {
            type = "slider",
            name = 'Comparative tooltip border width',
            tooltip = 'Change the comparative tooltips border width. Default value: 416',
            min = 100,
            max = 1440,
            step = 1,
            getFunc = function() return settings.tooltipSizeComparativeBorder end,
            setFunc = function(value) settings.tooltipSizeComparativeBorder = value
                FCOChangeStuff.tooltipBorderSizeHack()
            end,
            default = defaults.tooltipSizeComparativeBorder,
            width="full",
        },
        {
            type = "slider",
            name = 'Item tooltip scale',
            tooltip = 'Make the item tooltips texts scale by this percentage value, instead of 100% size.',
            min = 25,
            max = 150,
            step = 0.5,
            getFunc = function() return settings.tooltipSizeItemScaleHackPercentage end,
            setFunc = function(value) settings.tooltipSizeItemScaleHackPercentage = value
                FCOChangeStuff.tooltipScalingHack()
            end,
            default = defaults.tooltipSizeItemScaleHackPercentage,
            width="full",
        },
        {
            type = "slider",
            name = 'Popup tooltip scale',
            tooltip = 'Make the popup tooltips texts scale by this percentage value, instead of 100% size.',
            min = 25,
            max = 150,
            step = 0.5,
            getFunc = function() return settings.tooltipSizePopupScaleHackPercentage end,
            setFunc = function(value) settings.tooltipSizePopupScaleHackPercentage = value
                FCOChangeStuff.tooltipScalingHack()
            end,
            default = defaults.tooltipSizeItemScaleHackPercentage,
            width="full",
        },
        {
            type = "slider",
            name = 'Comparative tooltip scale',
            tooltip = 'Make the comparative tooltips texts scale by this percentage value, instead of 100% size.',
            min = 25,
            max = 150,
            step = 0.5,
            getFunc = function() return settings.tooltipSizeComparativeScaleHackPercentage end,
            setFunc = function(value) settings.tooltipSizeComparativeScaleHackPercentage = value
                FCOChangeStuff.tooltipScalingHack()
            end,
            default = defaults.tooltipSizeComparativeScaleHackPercentage,
            width="full",
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Loot',
        },
        {
            type = "checkbox",
            name = 'Snap cursor to loot window',
            tooltip = 'Snap the cursor automatically to the loot window as it is shown.',
            getFunc = function() return settings.snapCursorToLootWindow end,
            setFunc = function(value)
                settings.snapCursorToLootWindow = value
            end,
            default = defaults.snapCursorToLootWindow,
            width="full",
        },

        --==============================================================================
        {
            type = 'header',
            name = GetString(SI_ITEMTYPE34) .. " " .. GetString(SI_COLLECTIBLECATEGORYTYPE26), --collectibles - fragment
        },
        {
            type = "checkbox",
            name = 'Show combined itemname at fragment tooltip',
            tooltip = 'Show the combined itemname of a collectible at the tooltip of a fragment of that combined collectible. Only shows at the collectibles menu, fragment category.',
            getFunc = function() return settings.collectibleTooltipShowFragmentCombinedItem end,
            setFunc = function(value)
                settings.collectibleTooltipShowFragmentCombinedItem = value
                FCOChangeStuff.collectibleChanges()
            end,
            default = defaults.collectibleTooltipShowFragmentCombinedItem,
            width="full",
        },
        --==============================================================================
        {
            type = 'header',
            name = 'Dialogs',
        },
        {
            type = "checkbox",
            name = 'Suppress confirm cancel listing',
            tooltip = 'Suppress the confirm cancel trading house lisitng item dialog',
            getFunc = function() return settings.suppressDialog["CONFIRM_TRADING_HOUSE_CANCEL_LISTING"] end,
            setFunc = function(value) settings.suppressDialog["CONFIRM_TRADING_HOUSE_CANCEL_LISTING"] = value
                --FCOChangeStuff.tradingHouseDialogChanges("CONFIRM_TRADING_HOUSE_CANCEL_LISTING")
            end,
            default = defaults.suppressDialog["CONFIRM_TRADING_HOUSE_CANCEL_LISTING"],
            width="full",
            --requiresReload = true,
        },
        --==============================================================================
        {
            type = 'header',
            name = 'Mail',
        },
        {
            type = "checkbox",
            name = 'Show context menu buttons (inbox/send)',
            tooltip = '[Mail inbox]Show mass-change context menu button top-left at the mail inbox\n\n[Mail send]Show triangle context menu buttons, and a settings context menu button, at the mail send panel, near the to/subject/text edit boxes.',
            getFunc = function() return settings.mailContextMenus end,
            setFunc = function(value) settings.mailContextMenus = value
                FCOChangeStuff.mailStuff("ContextMenu")
            end,
            default = defaults.mailContextMenus,
            width="full",
        },
        {
            type = "slider",
            name = "Mail delete delay",
            tooltip = "Set the delay in ms between each mail deletion, if mass-change is used (0 = instant/no delay)",
            min = 0,
            max = 5000,
            decimals = 0,
            autoSelect = true,
            getFunc = function() return settings.mailDeleteDelay end,
            setFunc = function(delay)
                settings.mailDeleteDelay = delay
            end,
            default = defaults.mailDeleteDelay,
            width="full",
            disabled = function() return not settings.mailContextMenus end,
        },
        {
            type = "checkbox",
            name = 'Enable \'Return to sender\' bot',
            tooltip = 'Enable automatic return to sender emails (suppressing the dialog asking if you want to return it) if the incoming emails have the subject RE, RTS, RETURN, RSVP or BOUNCE (subject is not case-sensitive, but it must not contain any other characters/words).\n\n.This setting is disabled if any other Mail return bot addon + this feature is enabled (e.g. PostMaster)',
            getFunc = function() return settings.mailAutoReturnToSenderBot end,
            setFunc = function(value) settings.mailAutoReturnToSenderBot = value
                FCOChangeStuff.mailStuff("RTSBot")
            end,
            default = defaults.mailAutoReturnToSenderBot,
            disabled = function() FCOChangeStuff.AnyOtherMailReturnBotActive() end,
            width="full",
        },


        --==============================================================================
        {
            type = 'header',
            name = 'UI',
        },
        {
            type = "checkbox",
            name = 'Hide Golden Pursuits tracker',
            tooltip = 'Hide the Golden Pursuits tracker at the UI',
            getFunc = function() return settings.hidePromotionalEventTracker end,
            setFunc = function(value)
                settings.hidePromotionalEventTracker = value
                FCOChangeStuff.PromotionalEventTrackerUIChanges(value)
            end,
            default = defaults.hidePromotionalEventTracker,
            disabled = function() return nil == PROMOTIONAL_EVENT_TRACKER end,
            width="half",
        },
        {
            type = "checkbox",
            name = 'Don\'t auto-pin Golden Pursuits',
            tooltip = 'Stop automatically tracking any Golden Pursuit at the UI.\n\nYou manually control it: After login or UI reload you need to open the Golden Pursuit UI and manually select one of the tracked pins!',
            getFunc = function() return settings.dontAutoPinGoldenPursuits end,
            setFunc = function(value)
                settings.dontAutoPinGoldenPursuits = value
            end,
            default = defaults.dontAutoPinGoldenPursuits,
            disabled = function() return nil == PROMOTIONAL_EVENT_TRACKER end,
            width="half",
        },
        {
            type = "checkbox",
            name = 'Hide \'Mundus\' row at stats',
            --tooltip = '',
            getFunc = function() return settings.hideStatsPanelMundusRow end,
            setFunc = function(value)
                settings.hideStatsPanelMundusRow = value
                FCOChangeStuff.StatsPanelUIChanges(value)
            end,
            default = defaults.hideStatsPanelMundusRow,
            width="full",
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Quests',
        },
        {
            type = "checkbox",
            name = "Make quest tracker movable",
            tooltip = "Make the vanilla quest tracker movable on the UI, and save it\'s position",
            getFunc = function() return settings.questTrackerMovable end,
            setFunc = function(value)
                settings.questTrackerMovable = value
                FCOChangeStuff.QuestTrackerMovable(value)
            end,
            default = defaults.questTrackerMovable,
            width="half",
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Sounds',
        },
        {
            type = "checkbox",
            name = 'Mute sound on mounting',
            tooltip = 'Mute the game sound upon mounting for the chosen time (see slider)',
            getFunc = function() return settings.muteMountSound end,
            setFunc = function(value)
                settings.muteMountSound = value
                FCOChangeStuff.muteMountSound()
            end,
            default = defaults.muteMountSound,
            width="half",
        },
        {
            type = "slider",
            name = "SFX volume as you mount",
            tooltip = "The SFX volume will be set to this value as you mount. Standard is 0",
            min = 0,
            max = 100,
            decimals = 0,
            autoSelect = true,
            getFunc = function() return settings.muteMountSoundVolume end,
            setFunc = function(volumeVal)
                settings.muteMountSoundVolume = volumeVal
            end,
            default = defaults.muteMountSoundVolume,
            width="half",
            disabled = function() return not settings.muteMountSound end,
        },
        {
            type = "slider",
            name = "Mute time after mount",
            tooltip = "Time in milliseconds the sound should be muted after you have mounted",
            min = 0,
            max = 10000,
            decimals = 0,
            autoSelect = true,
            getFunc = function() return settings.muteMountSoundDelay end,
            setFunc = function(delayVal)
                settings.muteMountSoundDelay = delayVal
            end,
            default = defaults.muteMountSoundDelay,
            width="half",
            disabled = function() return not settings.muteMountSound end,
        },
        {
            type = "checkbox",
            name = 'Disable some sounds',
            tooltip = 'Disable some selected sounds so you do not hear them anymore. Select the sounds to disable in the shift box below (left side) and move them to the right side to disable them.',
            getFunc = function() return settings.disableSoundsLibShifterBox end,
            setFunc = function(value)
                settings.disableSoundsLibShifterBox = value
                FCOChangeStuff.updateDisabledSoundsLibShifterBoxState(FCOCHANGESTUFF_LAM_CUSTOM_SOUNDS_DISABLE_PARENT, FCOChangeStuff.disableSoundsShifterBoxControl)
                FCOChangeStuff.updateDisableSoundsLibShifterBoxEntries(FCOChangeStuff.disableSoundsShifterBoxControl)
            end,
            default = defaults.disableSoundsLibShifterBox,
            width="full",
        },
        {
            type = "custom",
            reference = "FCOCHANGESTUFF_LAM_CUSTOM_SOUNDS_DISABLE_PARENT",
            createFunc = function(customControl)
                FCOChangeStuff.updateSoundsLibShifterBox(customControl)
            end,
            --[[
            refreshFunc = function(customControl)
                --d("[FCOCS]RefreshFunc of Custom Control LibShifterBox disable sounds called")
                --Build or update (if it exists already) the disable sounds LibShifterBox
                --FCOChangeStuff.updateSoundsLibShifterBox(customControl)
            end,
            maxHeight = 100,
            ]]
            minHeight = 275,
            width="full",
        },

        --==============================================================================
        {
            type = 'header',
            name = 'Mounts',
        },
        {
            type = "checkbox",
            name = 'Favorite mount context menus',
            tooltip = 'Enable context menu entries at the mount collections, to (mass)add/remove mounts to/from favorite mounts',
            getFunc = function() return settings.favoriteMountsContextMenu end,
            setFunc = function(value)
                settings.favoriteMountsContextMenu = value

                FCOChangeStuff.BuildFavoriteMountsContextMenu()

                FCOChangeStuff.updateExcludedMountIdsLibShifterBoxState(FCOCHANGESTUFF_LAM_MOUNT_FAVORITES_EXCLUDE_PARENT, FCOChangeStuff.excludedMountIdsShifterBoxControl)
                FCOChangeStuff.updateExcludedMountIdsLibShifterBoxEntries(FCOChangeStuff.excludedMountIdsShifterBoxControl)
            end,
            default = defaults.favoriteMountsContextMenu,
            width="half",
        },
        {
          type = "description",
          title = "Instructions for mount favorites |cFF0000" .. favoritesExcludedListStatusIconText .. "|r below",
          text = "Move the mounts from left to right, which should not automatically be added to your favorite mounts, if you use the \'|c00FF00Add all|r mounts to favorites\' entry at the mount collectibles tile contextmenu.\n\nLocked mount names are shown |cFF0000in red color|r (top of the list), while unlocked ones are shown |cFFFFFFin white color|r (bottom of the list).\nYou can click the search icon to open the search field, enter a search text and press enter key to filter the list. Press the search icon again to close the search.",
        },
        {
            type = "custom",
            reference = "FCOCHANGESTUFF_LAM_MOUNT_FAVORITES_EXCLUDE_PARENT",
            createFunc = function(customControl)
                FCOChangeStuff.updateExcludedMountIdsLibShifterBox(customControl)
            end,
            --[[
            refreshFunc = function(customControl)
            end,
            maxHeight = 100,
            ]]
            minHeight = 275,
            width="full",
        },

    } -- optionsTable
    -- END OF OPTIONS TABLE
    --[[
    local lamPanelCreationInitDone = false
    local function LAMControlsCreatedCallbackFunc(pPanel)
        if pPanel ~= FCOChangeStuff.FCOSettingsPanel then return end
        if lamPanelCreationInitDone == true then return end
        --Do stuff here
        lamPanelCreationInitDone = true
    end
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", LAMControlsCreatedCallbackFunc)
    ]]
    local isFirstOpen = true
    local function LAMPanelOpenedCallbackFunc(pPanel)
        if pPanel ~= FCOChangeStuff.FCOSettingsPanel then return end
        --Not on first open as then the LibShifterBox is created and calls the same function below already
        if isFirstOpen then
            isFirstOpen = false
            return
        end
        --Update the owned mounts
        FCOChangeStuff.updateExcludedMountIdsLibShifterBox(FCOCHANGESTUFF_LAM_MOUNT_FAVORITES_EXCLUDE_PARENT)
    end
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", LAMPanelOpenedCallbackFunc)

    FCOChangeStuff.LAM:RegisterOptionControls(addonName .. "_LAM", optionsTable)
end
