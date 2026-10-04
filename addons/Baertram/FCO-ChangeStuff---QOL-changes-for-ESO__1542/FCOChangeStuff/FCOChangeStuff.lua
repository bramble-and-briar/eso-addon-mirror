if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER


FCOChangeStuff.addonVars = {}
local addonVars = FCOChangeStuff.addonVars
addonVars.addonVersion              = 0.596
addonVars.addonSavedVarsVersion	    = "0.02"
addonVars.addonName				    = "FCOChangeStuff"
addonVars.addonNameMenu  		    = "FCO ChangeStuff"
addonVars.addonNameMenuDisplay	    = "|c00FF00FCO |cFFFF00 ChangeStuff|r"
addonVars.addonNameShortColored	    = "|c00FF00FCO|cFFFF00CS|r"
addonVars.addonSavedVariablesName   = "FCOChangeStuff_Settings"
addonVars.settingsName   		    = "FCO ChangeStuff"
addonVars.addonAuthor			    = "Baertram"
addonVars.addonWebsite              = "https://www.esoui.com/downloads/info1542-FCOChangeStuff.html"
addonVars.addonFeedback             = "https://www.esoui.com/portal.php?uid=2028"
addonVars.addonDonation             = "https://www.esoui.com/portal.php?id=136&a=faq&faqid=131"
local addonName = addonVars.addonName

FCOChangeStuff.settingsVars = {}
FCOChangeStuff.settingsVars.defaultSettings = {}
FCOChangeStuff.settingsVars.settings = {}
FCOChangeStuff.settingsVars.defaults = {}

FCOChangeStuff.preventerVars = {}
FCOChangeStuff.preventerVars.doNotShowAskBeforeIgnoreDialog = false

FCOChangeStuff.worldMapShown			= false

FCOChangeStuff.ctrlVars = {}
local smithingTopLevelCreationPanel = ZO_SmithingTopLevelCreationPanel
FCOChangeStuff.ctrlVars.smithingCreatePanel                 = smithingTopLevelCreationPanel
local smithingTopLevelCreationPanelPatternList = smithingTopLevelCreationPanel:GetNamedChild("PatternList")
FCOChangeStuff.ctrlVars.smithingCreatePanelPatternListTitle = smithingTopLevelCreationPanelPatternList:GetNamedChild("Title") --ZO_SmithingTopLevelCreationPanelPatternListTitle
FCOChangeStuff.ctrlVars.smithingCreatePanelPatternListList  = smithingTopLevelCreationPanelPatternList:GetNamedChild("List") --ZO_SmithingTopLevelCreationPanelPatternListList

FCOChangeStuff.playerActivatedDone = false
FCOChangeStuff.gameMenuSceneActive = false

FCOChangeStuff.otherAddons = {}
FCOChangeStuff.otherAddons.PerfectPixel = false
FCOChangeStuff.otherAddons.NoThankYou = false

local spinFragments = {
		FRAME_PLAYER_FRAGMENT,
		FRAME_EMOTE_FRAGMENT_INVENTORY,
		FRAME_EMOTE_FRAGMENT_SKILLS,
		FRAME_EMOTE_FRAGMENT_JOURNAL,
		FRAME_EMOTE_FRAGMENT_MAP,
		FRAME_EMOTE_FRAGMENT_SOCIAL,
		FRAME_EMOTE_FRAGMENT_AVA,
		FRAME_EMOTE_FRAGMENT_SYSTEM,
		FRAME_EMOTE_FRAGMENT_LOOT,
		FRAME_EMOTE_FRAGMENT_CHAMPION,
}
FCOChangeStuff.spinFragments = spinFragments

local function disableOldSettings()
    --The 100% improvement was added into base game code with update to API100023 "Summerset"
    FCOChangeStuff.settingsVars.settings.improvementWith100Percent = false
end

local parentsOnEffectivelyShownHooked = {}

local function addButton(myAnchorPoint, relativeTo, relativePoint, offsetX, offsetY, buttonData)
    if not buttonData or not buttonData.parentControl or not buttonData.buttonName or not buttonData.callback then return end
    local button
    --Does the button already exist?
    local parent = buttonData.parentControl
    local btnName = parent:GetName() .. "_"..addonName .."_".. buttonData.buttonName
    button = WM:GetControlByName(btnName, "")
    if button == nil then
        --Create the button control at the parent
        button = WM:CreateControl(btnName, buttonData.parentControl, CT_BUTTON)
    end
    --Button was created?
    if button ~= nil then
        --Set the button's size
        button:SetDimensions(buttonData.width or 32, buttonData.height or 32)

        --SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
        button:SetAnchor(myAnchorPoint, relativeTo, relativePoint, offsetX, offsetY)

        --Texture
        local texture

        --Check if texture exists
        texture = WM:GetControlByName(btnName, "Texture")
        if texture == nil then
            --Create the texture for the button to hold the image
            texture = WM:CreateControl(btnName .. "Texture", button, CT_TEXTURE)
        end
        texture:SetAnchorFill()

        --Set the texture for normale state now
        texture:SetTexture(buttonData.normal)

        --Do we have seperate textures for the button states?
        button.upTexture 	  = buttonData.normal
        button.mouseOver 	  = buttonData.highlight
        button.clickedTexture = buttonData.pressed

        button.tooltipText	= buttonData.tooltip
        button.tooltipAlign = TOP
        button:SetHandler("OnMouseEnter", function(self)
            self:GetChild(1):SetTexture(self.mouseOver)
            ZO_Tooltips_ShowTextTooltip(self, self.tooltipAlign, self.tooltipText)
        end)
        button:SetHandler("OnMouseExit", function(self)
            self:GetChild(1):SetTexture(self.upTexture)
            ZO_Tooltips_HideTextTooltip()
        end)
        --Set the callback function of the button
        button:SetHandler("OnClicked", function(...)
            buttonData.callback(...)
        end)
        button:SetHandler("OnMouseUp", function(butn, mouseButton, upInside)
            if upInside then
                butn:GetChild(1):SetTexture(butn.upTexture)
            end
        end)
        button:SetHandler("OnMouseDown", function(butn)
            butn:GetChild(1):SetTexture(butn.clickedTexture)
        end)

        local isHidden = false
        local buttonVisibleType = type(buttonData.visible)
        if buttonVisibleType ~= nil then
            if buttonVisibleType == "function" then
                isHidden = not buttonData.visible()

                if not parentsOnEffectivelyShownHooked[parent] then
                    ZO_PostHookHandler(parent, "OnEffectivelyShown", function()
--d("[FCOCS]OnEffectivelyShown: " ..tostring(parent:GetName()))
                        button:SetHidden(not buttonData.visible())
                    end)
                    parentsOnEffectivelyShownHooked[parent] = true
                end
            elseif buttonVisibleType == "boolean" then
                isHidden = buttonData.visible
            end
        end
        --Show the button and make it react on mouse input
        button:SetHidden(isHidden)
        button:SetMouseEnabled(true)

        --Return the button control
        return button
    end
end
FCOChangeStuff.AddButton = addButton

local function throttledUpdate(callbackName, timer, callback, ...)
    timer = timer or 1
    if not callbackName or callbackName == "" or not callback then return end
    local args
    if ... ~= nil then
        args = {...}
    end
    local function Update()
        EVENT_MANAGER:UnregisterForUpdate(callbackName)
        if args then
            callback(unpack(args))
        else
            callback()
        end
    end
    EVENT_MANAGER:UnregisterForUpdate(callbackName)
    EVENT_MANAGER:RegisterForUpdate(callbackName, timer, Update)
end
FCOChangeStuff.ThrottledUpdate = throttledUpdate


--Keybinds callback function
function FCOChangeStuff.keybinds(keybindType)
    if keybindType == nil or keybindType == "" then return end
    local settings = FCOChangeStuff.settingsVars.settings
    --Toggle the settings quest giver on compass
    if keybindType == "FCOCS_TOGGLE_SETTINGS_COMPASS_QUEST_GIVERS" then
        if settings.enableKeybindCompassQuestGivers then
            --Get the current setting
            local currentSettingCompassQustGivers = tonumber(GetSetting(SETTING_TYPE_UI, UI_SETTING_COMPASS_QUEST_GIVERS))
            if currentSettingCompassQustGivers and currentSettingCompassQustGivers ~= "" then
                --Invert the number between 0 and 1
                if currentSettingCompassQustGivers == 0 then currentSettingCompassQustGivers = 1
                elseif currentSettingCompassQustGivers == 1 then currentSettingCompassQustGivers = 0 end
                if currentSettingCompassQustGivers then
                    --Set the new setting
                    SetSetting(SETTING_TYPE_UI, UI_SETTING_COMPASS_QUEST_GIVERS, tostring(currentSettingCompassQustGivers))
                end
            end
        end
    --Toggle the settings innocent attack
    elseif keybindType == "FCOCS_TOGGLE_SETTINGS_INNOCENT_ATTACK" then
        if settings.enableKeybindInnocentAttack then
            --Get the current setting
            local currentSettingInnocentAttack = tonumber(GetSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS))
            if currentSettingInnocentAttack and currentSettingInnocentAttack ~= "" then
                --Invert the number between 0 and 1
                if currentSettingInnocentAttack == 0 then currentSettingInnocentAttack = 1
                elseif currentSettingInnocentAttack == 1 then currentSettingInnocentAttack = 0 end
                if currentSettingInnocentAttack then
                    --Set the new setting
                    SetSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS, tostring(currentSettingInnocentAttack))
                end
            end
        end
    end
end

--Player activated function
function FCOChangeStuff.Player_Activated(...)
    --Is the addon NoThankYou enabled?
    if NO_THANK_YOU_VARS ~= nil then
        FCOChangeStuff.otherAddons.NoThankYou = true
    end

    --Save the currently used audio volume levels
    FCOChangeStuff.saveVolumeLevels(SETTING_TYPE_AUDIO, AUDIO_SETTING_AUDIO_VOLUME)

    --Reset the counter for the group list
    FCOChangeStuff.runGroupListCounter = 0

    --Disable some old/deprecated settings
    disableOldSettings()

    --Do stuff directly after login/reloadui
    FCOChangeStuff.afterLoginOrReloaduiFunctions()
    --The overall stuff
    FCOChangeStuff.overallFunctions()
    --Hide the other stuff
    FCOChangeStuff.hideStuff()
    --change map stuff
    FCOChangeStuff.mapStuff("all")
    --change mail stuff
    FCOChangeStuff.mailStuff()
    --change group list stuff
    FCOChangeStuff.CPStuff()
    --Hook the stable scene
    FCOChangeStuff.hookStableScene()
    --Add the crafting modifications
    FCOChangeStuff.craftingModifications()
    --Add the slash commands
    FCOChangeStuff.slashCommands()
    --Add main menu buttons
    FCOChangeStuff.addMainMenuButtons()
    --Inventory hacks (new item, not sellable item)
    FCOChangeStuff.inventoryChanges()
    --Bank hacks
    FCOChangeStuff.bankChanges()
    --Chat blacklist: Only loaded after ReloadUI
    --Prepare the keywords once
    FCOChangeStuff.blacklistKeyWords = { zo_strsplit("\n", FCOChangeStuff.settingsVars.settings.chatKeyWords) }
    --Prepare the chat blacklist messages hook
    FCOChangeStuff.chatBlacklist()
    --Chat notification stuff
    FCOChangeStuff.chatDisableNotificationStuff()
    --Chat CSA message if whisper but status is offline
    FCOChangeStuff.chatWhisperAndFlaggedAsOffline()
    --Prepare the battleground changes
    --Save the standard anchor of the BGHUD
    FCOChangeStuff.BGHUDStandardSave()
    --Apply the modifications for the BG now
    FCOChangeStuff.bgModifications()
    --Apply the mount related stuff
    FCOChangeStuff.mountChanges()
    --Apply the group election stuff
    FCOChangeStuff.GroupElectionStuff()
    --Apply the sound related stuff
    FCOChangeStuff.soundChanges()
    --Apply the tooltip related stuff
    FCOChangeStuff.tooltipChanges()
    --Apply the snap cursor changes
    FCOChangeStuff.snapCursor("-ALL-")
    --Apply the skill window changes
    FCOChangeStuff.skillChanges()
    --Apply the collectible changes
    FCOChangeStuff.collectibleChanges()
    --Apply mount changes
    FCOChangeStuff.favoriteMountChanges()
    --Apply the dialogs changes
    FCOChangeStuff.dialogsChanges()
    --Apply the guild history changes
    FCOChangeStuff.GuildHistoryChanges()
    --Quest changes
    FCOChangeStuff.questChanges()
    --Apply the UI changes
    FCOChangeStuff.UIChanges()
    --Notifications
    FCOChangeStuff.addNotificationsButtons()

    FCOChangeStuff.playerActivatedDone = true
end

local wasSettingsFragmentShown = false
local wasGameMenuSceneShown = false
local openingNewSceneDirectlyFromSettings = nil

local scenesBlacklisted = {
    hudui = true,
}
local sceneDelays = {
    hud = 0,
    hudui = 0,
}

local function specialHooks()
    local fixPlayerSpinFragments = FCOChangeStuff.FixPlayerSpinFragments
    local function runPlayerSpinFix()
        local sceneName = openingNewSceneDirectlyFromSettings
--d("[FCOCS]runPlayerSpinFix - wasSettingsFragmentShown: " .. tostring(wasSettingsFragmentShown) .. ", sceneName: " .. tostring(sceneName))
        local scene, delay
        if sceneName ~= nil then
            delay = sceneDelays[sceneName] or nil
            scene = SCENE_MANAGER:GetScene(sceneName)
        end

        if wasSettingsFragmentShown then
            --[[
            if openingNewSceneDirectlyFromSettings ~= nil and delay == nil then
    d(">DIRECT call runPlayerSpinFix - scene: " .. SCENE_MANAGER.currentScene.name .. ", wasSettingsFragmentShown: " .. tostring(wasSettingsFragmentShown))
                if wasSettingsFragmentShown then
                    wasSettingsFragmentShown = false
                    wasGameMenuSceneShown = false
                    fixPlayerSpinFragments(scene)
                end
            else
            ]]
                delay = delay or 0
                zo_callLater(function()
    --d(">delayed " .. tostring(delay) .." runPlayerSpinFix - scene: " .. SCENE_MANAGER.currentScene.name .. ", wasSettingsFragmentShown: " .. tostring(wasSettingsFragmentShown))
                    if wasSettingsFragmentShown then
                        wasSettingsFragmentShown = false
                        wasGameMenuSceneShown = false
                        fixPlayerSpinFragments(scene)
                    end
                end, delay)
            --end
        end
        openingNewSceneDirectlyFromSettings = nil
    end

    --[[
    local invScene = SCENE_MANAGER:GetScene('inventory')
    if invScene then
        invScene:RegisterCallback("StateChange", function(oldState, newState)
d("[FCOCS]Inventory scene - state: " .. tostring(newState) .. ", wasSettingsFragmentShown: " .. tostring(wasSettingsFragmentShown))
        end)
    end
    ]]

    --20250314 If PlayerSpin fragments are removed then opening a menu (e.g. settings) and closing it won't reset the
    --camera properly anymore!
    --Calling the spin fragment updater funciton fixes that
    -->Same for the collections screen (if opened directly after opening the game menu e.g.
    local gameMenuInGameScene = SCENE_MANAGER:GetScene('gameMenuInGame')
    if gameMenuInGameScene then
        gameMenuInGameScene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_SHOWN then
                wasSettingsFragmentShown = false
                wasGameMenuSceneShown = true
--d("[FCOCS]GameMenu scene - SHOWN - wasSettingsFragmentShown: " .. tostring(wasSettingsFragmentShown))
            elseif newState == SCENE_HIDDEN then
--d("[FCOCS]GameMenu scene - HIDDEN - wasSettingsFragmentShown: " .. tostring(wasSettingsFragmentShown))
                if wasSettingsFragmentShown or wasGameMenuSceneShown then
                    runPlayerSpinFix()
                end
            end
        end)
    end

    local gameMenuSettingsFragment = OPTIONS_WINDOW_FRAGMENT
    if gameMenuSettingsFragment then
        gameMenuSettingsFragment:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_FRAGMENT_SHOWN then
--d("[FCOCS]Settings fragment - SHOWN")
                wasSettingsFragmentShown = true
            elseif newState == SCENE_FRAGMENT_HIDDEN then
--d("[FCOCS]Settings fragment - HIDDEN - wasGameMenuSceneShown: " .. tostring(wasGameMenuSceneShown) ..", wasSettingsFragmentShown: " .. tostring(wasSettingsFragmentShown))
                --[[
                if wasSettingsFragmentShown and not wasGameMenuSceneShown then
                    runPlayerSpinFix()
                end
                ]]
            end
        end)
    end

    --Opening any other scene? Then reset player spin if it was not properly reset as the game menu scene or settings fragment hide
    SecurePostHook(SCENE_MANAGER, "Show", function(sm, sceneName, push, nextSceneClearsSceneStack, numScenesNextScenePops, bypassHideSceneConfirmationReaso)
        if wasSettingsFragmentShown and wasGameMenuSceneShown then
            if scenesBlacklisted[sceneName] then return end
--d("[FCOCS]SCENE_MANAGER - Showing a new scene now: " .. tostring(sceneName))
            openingNewSceneDirectlyFromSettings = sceneName
        end
    end)

end

function FCOChangeStuff.addonLoaded(eventName, addonNameOfEachAddonLoaded)
    if addonNameOfEachAddonLoaded == "PerfectPixel" then
        FCOChangeStuff.otherAddons.PerfectPixel = true
    elseif NO_THANK_YOU_VARS ~= nil or addonNameOfEachAddonLoaded == "NoThankYou" then
        FCOChangeStuff.otherAddons.NoThankYou = true
    end

    if addonNameOfEachAddonLoaded ~= addonName then return end
    EM:UnregisterForEvent(eventName)

    --Register for the zone change/player ready event
    EM:RegisterForEvent(addonName, EVENT_PLAYER_ACTIVATED, FCOChangeStuff.Player_Activated)

    --Save the original CP function
    FCOChangeStuff.originalUnitCPEffectiveFunc  = GetUnitEffectiveChampionPoints
    FCOChangeStuff.originalUnitCPFunc           = GetUnitChampionPoints
    FCOChangeStuff.originalCPFunc               = GetLevelOrChampionPointsStringNoIcon

    --Get the SavedVariables
    FCOChangeStuff.getSettings()

    --Check and set the enlightened sound
    FCOChangeStuff.noEnlightenedSound()

    --LibShifterBox
    FCOChangeStuff.LSB = LibShifterBox
    --Create the settings panel object of libAddonMenu 2.0
    FCOChangeStuff.LAM = LibAddonMenu2
    --Build the LAM settings panel
    FCOChangeStuff.buildAddonMenu()

    --Special hooks and workarounds
    specialHooks()

    --EVENTS
    --Crafting station interact
    EM:RegisterForEvent(addonName, EVENT_CRAFTING_STATION_INTERACT, FCOChangeStuff.OnEventCraftingStationOpened)
end

function FCOChangeStuff.initialize()
    EM:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, FCOChangeStuff.addonLoaded)
end

--Load the addon
FCOChangeStuff.initialize()




