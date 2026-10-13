if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

local defR, defG, defB, deafA = ZO_SUCCEEDED_TEXT:UnpackRGBA()

------------------------------------------------------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------------------------------------------------------

local function mixinNoOverride(info, object, ...)
--d("[FCOCS]mixinNoOverride - " ..tostring(info))
    local addedInfo = false
    for i = 1, select("#", ...) do
        local source = select(i, ...)
        for k,v in pairs(source) do
            if object[k] == nil then
                if not addedInfo then
                    d(">Adding missing SV default values for: " .. tostring(info))
                    addedInfo = true
                end
                object[k] = v
                d(">>key: " ..tostring(k) .."=" .. tostring(v) .. " (" .. type(v) .. ")")
            end
        end
    end
end

local function getCharactersOfAccount(keyIsCharName)
    keyIsCharName = keyIsCharName or false
    local charactersOfAccount
    --Check all the characters of the account
    for i = 1, GetNumCharacters() do
        local name, _, _, _, _, _, characterId = GetCharacterInfo(i)
        local charName = zo_strformat(SI_UNIT_NAME, name)
        if characterId ~= nil and charName ~= "" then
            if charactersOfAccount == nil then charactersOfAccount = {} end
            if keyIsCharName then
                charactersOfAccount[charName]   = characterId
            else
                charactersOfAccount[characterId]= charName
            end
        end
    end
    return charactersOfAccount
end


--Read the SavedVariables
function FCOChangeStuff.getSettings()
    --The default values for the language and save mode
    local defaultsSettings = {
        language 	 		    = 1, --Standard: English
        saveMode     		    = 2, --Standard: Account wide settings
    }

    --Pre-set the deafult values
    local defaults = {
        alwaysUseClientLanguage			    = true,
        showRealCPs                         = false,
        reOpenMapOnMounting                 = false,
        showEnDisableAllFilterButtons       = false,
        hideCrownStoreButtonInMainMenu      = false,
        hideCrownStoreMembershipInMainMenu  = false,
        hideCrownCratesButtonInMainMenu     = false,
        hideCrownStorePointsInMainMenu      = false,
        stableFeedSettings          = {
            [RIDING_TRAIN_SPEED]                = false,
            [RIDING_TRAIN_STAMINA]              = false,
            [RIDING_TRAIN_CARRYING_CAPACITY]    = false,
        },
        showAddonSettingsMainMenuButton     = false,
        smithingCreationAddArmorTypeSwitchButton = true,
        improvementWith100Percent           = false,
        improvementBlockQuality             = -1,
        improvementBlockQualityExceptionShiftKey = false,
        removeNewItemIcon = false,
        removeSellItemIcon = false,
        enableChatBlacklist = false,
        chatKeyWords = "",
        enableChatBlacklistForWhispers = false,
        enableChatBlacklistForGroup = false,
        enableChatBlacklistForGuilds = false,
        blacklistedTextToChat = false,
        enableSkillLineContextMenu = false,
        skillLineIndexState = {},
        noShopAdvertisementPopup = false,
        noEnlightenedSound = false,
        enableBGHUDMoveable = false,
        BGHUDcoordinates = {
            ["x"] = 21,
            ["y"] = 0,
        },
        changeSoundAtCrafting = false,
        changeSoundAtCraftingVolume = 0,
        volumes = {
            [SETTING_TYPE_AUDIO] = {
                [AUDIO_SETTING_AUDIO_VOLUME] = 0,
            },
        },
        pingPongPlayerPinOnMapOpen = true,
        pingPongPlayerPinOnMapOpenScaling = 25,
        enableChatWhisperAndFlaggedAsOfflineReminder = false,
        enableKeybindCompassQuestGivers = false,
        hideMapZoneStory = false,
        hideMapZoneStoryBeamMeUpAllowedToShow = false,
        disableChatNotificationAnimation = false,
        disableChatNotificationSound = false,
        showCharacterPanelAtBank = false,
        showCharacterPanelAtGuildBank = false,
        disableSoundsLibShifterBox = false,
        disabledSoundEntries = {},
        muteMountSound = false,
        muteMountSoundDelay = 500,
        muteMountSoundVolume = 0,
        autoDeclineGroupElections = false,
        tooltipSizeHack = false,
        tooltipSizeItemBorder = 416,
        tooltipSizePopupBorder = 416,
        tooltipSizeComparativeBorder = 416,
        tooltipSizeItemScaleHackPercentage = 100,
        tooltipSizePopupScaleHackPercentage = 100,
        tooltipSizeComparativeScaleHackPercentage = 100,
        snapCursorToLootWindow = false,
        repositionActionSlotTimers = false,
        repositionActionSlotTimersOffset = {
            x = 0,
            y = 0,
        },
        showActionSlotTimersTimeLeftNumber = false,
        spinStop = false,
        spinStopAtScenes = {
            inventory = true,
            collectionsBook = true,
            allOthers = true,
            stats = false,
        },
        collectibleTooltipShowFragmentCombinedItem = false,
        enableKeybindInnocentAttack = false,
        doNotInterruptHarvestOnMenuOpen = false,
        hidePOIsInCities = false,
        suppressDialog = {
            ["CONFIRM_TRADING_HOUSE_CANCEL_LISTING"] = false,
        },
        mailContextMenus = true,
        overwriteMailFields = {
            ["recipients"] = true,
            ["subjects"] = true,
            ["texts"] = true,
        },
        saveMailFields = {
            ["recipients"] = true,
            ["subjects"] = true,
            ["texts"] = true,
        },
        autoLoadMailFields = {
            ["recipients"] = false,
            ["subjects"] = false,
            ["texts"] = false,
        },
        autoLoadMailFieldsAt = {
            mailOpen = {
                ["recipients"] = false,
                ["subjects"] = false,
                ["texts"] = false,
            },
            mailWasSend = {
                ["recipients"] = false,
                ["subjects"] = false,
                ["texts"] = false,
            },
        },
        mailLastUsed = {
            ["recipients"] = "",
            ["subjects"] = "",
            ["texts"] = "",
        },
        mailFavorites = {
            ["recipients"] = false,
            ["subjects"] = false,
            ["texts"] = false,
        },
        mailTextsSaved = {
            ["recipients"] = {},
            ["subjects"] = {},
            ["texts"] = {},
        },
        mailFavoritesSaved = {
            ["recipients"] = {},
            ["subjects"] = {},
            ["texts"] = {},
        },

        mailProfiles = {},
        enableMailProfiles = false,
        --splitMailProfilesIntoAlphabet = false, --not supported as deletion would not be possible anymore!

        splitMailFavoritesIntoAlphabet = false,
        mailFavoritesContextMenusAtEditFields = false,
        mailLastUsedContextMenusAtEditFields = false,
        mailContextMenuSubmenusForceOpenToTheLeft = true,
        mailDeleteDelay = 0,
        showScrollUpDownButtonsAtVerticalScrollbar = false,

        addGuildHistoryNavigationFirstAndLastPage = false,

        -- Golden pursuits
        hidePromotionalEventTracker = false,
        dontAutoPinGoldenPursuits = false,
        dontAutoPinFinishedGoldenPursuits = nil,

        --Quest tracker
        questTrackerMovable = false,
        questTrackerPos = { x=1, y=-1 },

        --Stats scene
        hideStatsPanelMundusRow = false,

        easyDestroy = false,

        removeLearnableItemIcon = false,
        learnableItemIconColor = { r=defR, g=defG, b=defB, a=deafA },
        learnableItemIconPos = {
            [BAG_BACKPACK] =            { x=0, y=0, width=32, height=32 },
            [BAG_BANK] =                { x=0, y=0, width=32, height=32 },
            [BAG_HOUSE_BANK_ONE] =      { x=0, y=0, width=32, height=32 }, --Counts for all house banks
            [BAG_GUILDBANK] =           { x=0, y=0, width=32, height=32 },
            --[BAG_FURNITURE_VAULT] =     { x=0, y=0, width=32, height=32  }, --does that even show any learnable items?
            [990] =                     { x=0, y=0, width=32, height=32 }, --Trading house search! custom bagId of this addon
        },

        addMassHandlingNotificationsButton = false,

        --Currencyies deposit dialog
        --enableCurrencyDepositDialogHelper = false,

        --Currencyies automatic banking
        enableCurrencyDepositHelpers = false,
        currencyThresholdOnChar = {
          [CURT_TELVAR_STONES] = 1,
          [CURT_ALLIANCE_POINTS] = 1,
        },

        --Favorite mounts
        favoriteMountsContextMenu = false,
        excludedMountCollectionIdsEntries = {},

        --TODO 20231114 for debugging LibAddonMenu dropdwn.lua test for multiselection
        --[[
        _testMultiSelect = { "abc", "q" },
        _testMultiSelectChoicesValues = { 1, 15 },
        orderBoxTest1 = {
			[1] = {
				value 		= BAG_BACKPACK,
				uniqueKey 	= 1,
				text  		= "Entry 1",
				--tooltip 	= locVars["FCOIS_LibFilters_PanelIds"][LF_INVENTORY],

			},
			[2] = {
				value 		= BAG_BANK,
				uniqueKey 	= 2,
				text  		= "Entry 2",
				--tooltip 	= locVars["FCOIS_LibFilters_PanelIds"][LF_BANK_WITHDRAW],
			},
            [3] = {
				value 		= BAG_GUILDBANK,
				uniqueKey 	= 3,
				text  		= "Entry 3",
				--tooltip 	= locVars["FCOIS_LibFilters_PanelIds"][LF_GUILDBANK_WITHDRAW],
			},
			[4] = {
				value 		= BAG_HOUSE_BANK_ONE,
				uniqueKey 	= 4,
				text  		= "Entry 4",
				--tooltip 	= locVars["FCOIS_LibFilters_PanelIds"][LF_HOUSE_BANK_WITHDRAW],
			},
        },
        ]]
    }
    --Favoritable mounts: Excluded collectibleIds defaults
    local excludedMountIdsShifterBoxDefaults = {
        [5870] = true, --Curious Play wooden horse
        [5880] = true, --Curious Play dragon
        [7291] = true, --Nightmar Play wooden horse
        [9829] = true, --Stopfwell guar
    }
    for mountCollectibleIdToExclude, isEnabled in pairs(excludedMountIdsShifterBoxDefaults) do
        if isEnabled == true then
            defaults.excludedMountCollectionIdsEntries[mountCollectibleIdToExclude] = zo_strformat(SI_UNIT_NAME, GetCollectibleName(mountCollectibleIdToExclude)) or "Mount collectibleId: " ..tostring(mountCollectibleIdToExclude)
        end
    end


    FCOChangeStuff.settingsVars.defaults = defaults

    --=============================================================================================================
    --	MIGRATE USER SETTINGS from non-server to Server-dependent
    --=============================================================================================================
    local svName = FCOChangeStuff.addonVars.addonSavedVariablesName
    local svVersion = FCOChangeStuff.addonVars.addonSavedVarsVersion

    local serverName = GetWorldName()
    local account = GetDisplayName()
    --local currentCharId = GetCurrentCharacterId()
    local svTab = _G[svName] --FCOChangeStuff_Settings
    local svTabExists = (not ZO_IsTableEmpty(svTab) and true) or false
    local svDefaultSubTab = "Default"
    local svAccountWideSubTab = "$AccountWide"
    local svSettingsForAllTab = "SettingsForAll"
    local svSettingsTab = "Settings"

    --Old SV already exist, or is this a first-install of the addon?
    if svTabExists == true then
        local migrationDoneReloadUInow = false

        --New migrated basic version 999 settingsForAll do not exist yet?
        if (not svTab[serverName] or not svTab[serverName][account] or not svTab[serverName][account][svAccountWideSubTab])
                or (svTab[serverName] and svTab[serverName][account] and svTab[serverName][account][svAccountWideSubTab]
                and not svTab[serverName][account][svAccountWideSubTab][svSettingsForAllTab]) then
            --Migrate basic version 999 settings (Account wide or character specific: Flag) to Server dependent
            local oldAccountWideDefaultSettings = (svTab[svDefaultSubTab] and svTab[svDefaultSubTab][account] and svTab[svDefaultSubTab][account][svAccountWideSubTab] and ZO_ShallowTableCopy(svTab[svDefaultSubTab][account][svAccountWideSubTab][svSettingsForAllTab])) or nil
            if not ZO_IsTableEmpty(oldAccountWideDefaultSettings) then
                oldAccountWideDefaultSettings.version = 999
                d("[FCOChangeStuff]>=============================================================>")
                d("Old accountWide default version 999 SV found: " ..tostring(account))
                --Check if any defaultsSettings keys are missing and "fix" the SV that way by returning to it's defaults values
                mixinNoOverride("oldAccountWideDefaultSettings", oldAccountWideDefaultSettings, defaultsSettings)
                --Set the new account wide SV structures -> Use old settingsForAll
                svTab[serverName] = svTab[serverName] or {}
                svTab[serverName][account] = svTab[serverName][account] or {}
                svTab[serverName][account][svAccountWideSubTab] = svTab[serverName][account][svAccountWideSubTab] or {}
                svTab[serverName][account][svAccountWideSubTab][svSettingsForAllTab] = oldAccountWideDefaultSettings
                d("!1> migrated to new server dependent accountWide default version 999 SV")
                migrationDoneReloadUInow = true

                --Delete old SVs without server
                if svTab[svDefaultSubTab] and svTab[svDefaultSubTab][account] and svTab[svDefaultSubTab][account][svAccountWideSubTab] then
                    svTab[svDefaultSubTab][account][svAccountWideSubTab][svSettingsForAllTab] = nil
                    d("<Deleted old SV entry: " ..tostring(svDefaultSubTab) .. "/" .. tostring(account) .. "/" .. tostring(svAccountWideSubTab) .. "/" .. tostring(svSettingsForAllTab))
                    if ZO_IsTableEmpty(svTab[svDefaultSubTab][account][svAccountWideSubTab]) then
                        svTab[svDefaultSubTab][account][svAccountWideSubTab] = nil
                        d("<Deleted old SV entry: " ..tostring(svDefaultSubTab) .. "/" .. tostring(account) .. "/" .. tostring(svAccountWideSubTab))
                        if ZO_IsTableEmpty(svTab[svDefaultSubTab][account]) then
                            svTab[svDefaultSubTab][account] = nil
                            d("<Deleted old SV entry: " ..tostring(svDefaultSubTab) .. "/" .. tostring(account))
                        end
                    end
                end
            end
        end

        --New migrated accountWide settings do not exist yet?
        if (not svTab[serverName] or not svTab[serverName][account] or not svTab[serverName][account][svAccountWideSubTab])
                or (svTab[serverName] and svTab[serverName][account] and svTab[serverName][account][svAccountWideSubTab]
                and not svTab[serverName][account][svAccountWideSubTab][svSettingsTab]) then
            --Migrate SV from non-server dependent to Server dependent
            --Account wide
            local oldAccountWide = (svTab[svDefaultSubTab] and svTab[svDefaultSubTab][account] and svTab[svDefaultSubTab][account][svAccountWideSubTab] and ZO_ShallowTableCopy(svTab[svDefaultSubTab][account][svAccountWideSubTab][svSettingsTab])) or nil
            if not ZO_IsTableEmpty(oldAccountWide) then
                d("[FCOChangeStuff]>=============================================================>")
                d("Old accountWide SV found: " ..tostring(account))
                --Check if any defaultsSettings keys are missing and "fix" the SV that way by returning to it's defaults values
                mixinNoOverride("oldAccountWide", oldAccountWide, defaults)
                --Set the new account wide SV structures -> Use old settings
                svTab[serverName] = svTab[serverName] or {}
                svTab[serverName][account] = svTab[serverName][account] or {}
                svTab[serverName][account][svAccountWideSubTab] = svTab[serverName][account][svAccountWideSubTab] or {}
                svTab[serverName][account][svAccountWideSubTab][svSettingsTab] = oldAccountWide
                d("!2> migrated to new server dependent accountWide SV")
                migrationDoneReloadUInow = true

                --Delete old SVs without server
                if svTab[svDefaultSubTab] and svTab[svDefaultSubTab][account] and svTab[svDefaultSubTab][account][svAccountWideSubTab] then
                    svTab[svDefaultSubTab][account][svAccountWideSubTab][svSettingsTab] = nil
                    d("<Deleted old SV entry: " ..tostring(svDefaultSubTab) .. "/" .. tostring(account) .. "/" .. tostring(svAccountWideSubTab) .. "/" .. tostring(svSettingsTab))
                    if ZO_IsTableEmpty(svTab[svDefaultSubTab][account][svAccountWideSubTab]) then
                        svTab[svDefaultSubTab][account][svAccountWideSubTab] = nil
                        d("<Deleted old SV entry: " ..tostring(svDefaultSubTab) .. "/" .. tostring(account) .. "/" .. tostring(svAccountWideSubTab))
                        if ZO_IsTableEmpty(svTab[svDefaultSubTab][account]) then
                            svTab[svDefaultSubTab][account] = nil
                            d("<Deleted old SV entry: " ..tostring(svDefaultSubTab) .. "/" .. tostring(account))
                        end
                    end
                end
            end
        end

        --Get all CharacterIDs of current logged in account and migrate them
        local characterId2Name = getCharactersOfAccount(false)
        --For each characterId check old existing SVs
        for characterId, charName in pairs(characterId2Name) do
            --New migrated characterId settings do not exist yet?
            if (not svTab[serverName] or not svTab[serverName][account] or not svTab[serverName][account][characterId])
                    or (svTab[serverName] and svTab[serverName][account] and svTab[serverName][account][characterId]
                    and not svTab[serverName][account][characterId][svSettingsTab]) then
                local oldCharacterIDSettings = (svTab[svDefaultSubTab] and svTab[svDefaultSubTab][account] and svTab[svDefaultSubTab][account][characterId] and ZO_ShallowTableCopy(svTab[svDefaultSubTab][account][characterId][svSettingsTab])) or nil
                if not ZO_IsTableEmpty(oldCharacterIDSettings) then
                    d("[FCOChangeStuff]>=============================================================>")
                    d("Old characterID SV found, account: " ..tostring(account) .. ", charID: " .. tostring(characterId) .. ", name: " ..tostring(charName))
                    --Check if any defaultsSettings keys are missing and "fix" the SV that way by returning to it's defaults values
                    mixinNoOverride("oldCharacterIDSettings", oldCharacterIDSettings, defaults)
                    --Set the new character SV structures -> Use old settings
                    svTab[serverName] = svTab[serverName] or {}
                    svTab[serverName][account] = svTab[serverName][account] or {}
                    svTab[serverName][account][characterId] = svTab[serverName][account][characterId] or {}
                    svTab[serverName][account][characterId][svSettingsTab] = oldCharacterIDSettings
                    d("!3> migrated to new server dependent characterID SV, charID: " .. tostring(characterId) .. ", name: " ..tostring(charName))
                    migrationDoneReloadUInow = true

                    --Delete old SVs without server
                    if svTab[svDefaultSubTab] and svTab[svDefaultSubTab] and svTab[svDefaultSubTab][account] then
                        svTab[svDefaultSubTab][account][characterId] = nil
                        d("<Deleted old SV entry: " ..tostring(svDefaultSubTab) .. "/" .. tostring(account) .. "/" .. tostring(characterId))
                        if ZO_IsTableEmpty(svTab[svDefaultSubTab][account]) then
                            svTab[svDefaultSubTab][account] = nil
                            d("<Deleted old SV entry: " ..tostring(svDefaultSubTab) .. "/" .. tostring(account))
                        end
                    end
                end
            end
        end
        if migrationDoneReloadUInow == true then
            d("[FCOChangeStuff]<=============================================================")
            d("Migration to server was done - Reloading UI now!")
            ReloadUI()
        end
    end

    --=============================================================================================================
    --	LOAD USER SETTINGS
    --=============================================================================================================
    --Load the user's settings from SavedVariables file -> Account wide of basic version 999 at first
    --Check, by help of basic version 999 settings, if the SettingsForAll should be loaded for each character or account wide
    FCOChangeStuff.settingsVars.defaultSettings = ZO_SavedVars:NewAccountWide(svName, 999, svSettingsForAllTab, defaultsSettings, serverName)
    --Use the current addon version to read the settings now
    if (FCOChangeStuff.settingsVars.defaultSettings.saveMode == 1) then
        --FCOChangeStuff.settingsVars.settings = ZO_SavedVars:NewCharacterIdSettings(FCOChangeStuff.addonVars.addonSavedVariablesName, FCOChangeStuff.addonVars.addonSavedVarsVersion , "Settings", defaults )
        FCOChangeStuff.settingsVars.settings = ZO_SavedVars:NewCharacterIdSettings(svName, svVersion, svSettingsTab, defaults, serverName)
    else
        --FCOChangeStuff.settingsVars.settings = ZO_SavedVars:NewAccountWide(FCOChangeStuff.addonVars.addonSavedVariablesName, FCOChangeStuff.addonVars.addonSavedVarsVersion, "Settings", defaults)
        FCOChangeStuff.settingsVars.settings = ZO_SavedVars:NewAccountWide(svName, svVersion, svSettingsTab, defaults, serverName)
    end
    --=============================================================================================================
end
