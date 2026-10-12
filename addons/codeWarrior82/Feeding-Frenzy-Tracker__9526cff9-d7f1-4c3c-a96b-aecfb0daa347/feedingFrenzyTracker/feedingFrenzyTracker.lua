local appName = "feedingFrenzyTracker"
local frenzyAbilityID = 131353
local ferociousRoarAbilityID = 39113
local picPath = GetAbilityIcon(frenzyAbilityID)
local iconText = zo_iconTextFormat(picPath, 80, 80, " ")
local isLoaded = false
local isMenuOpen = false
local frenzyCooldown = 19
local courageTime = 20
local needToNotify = true
local needNotify = true
local isEquiped = false
local ultiValuePrevious = 0
local ultThresholdTriggered = false

feedingFrenzyTracker = {}

feedingFrenzyTracker.defaults = {
    trackFF = true,
    autoTrack = true,
	notify = true,
    yAxisText = 930,
    xAxisText = 1400,
    trackUlti = true,
    ultValueMin = 280
}

--print message to chat box
local function printMessage(msg)
	local chat = LibChatMessage(appName, "MA")
	chat:Print(msg)
end

--clean player names
local function cleanName(str)
    return str:sub(1, -4)
end

--check if LibNotify is available
local function isLibAvailable()
    if LibNotify and type(LibNotify.notifyForAddonPlease) == "function" then
        return true
    else 
		return false
    end
end

local function processCourage()

    local text

    if courageTime > 9 then
        text = string.format("%d", courageTime)
    else
        text = string.format(" %d", courageTime)
    end

    if courageTime > 0 then
        EVENT_MANAGER:RegisterForUpdate("updateCourage", 1000, processCourage)
        ffAddonLabelCourage:SetText(text)
        courageTime = courageTime - 1
    else
        EVENT_MANAGER:UnregisterForUpdate("updateCourage")
        ffAddonLabelCourage:SetText("")
        courageTime = 19
    end
end

--handle combat alert
local function combatReportCourage(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, 
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    --target type 0 = npc's / innocents / world adds / world bosses / dungeon adds / dungeon bosses / pvp guards
    --target type 3 = players
    --target type 4 = training dummies
    if isError then
        return
    end

    local nameTmp = GetUnitName("player")

    if nameTmp == cleanName(sourceName) then
        courageTime = 19
        processCourage()
    end

end

local function processFrenzy()

    local text

    if frenzyCooldown > 9 then
        text = string.format("%d", frenzyCooldown)
    else
        text = string.format(" %d", frenzyCooldown)
    end

    if frenzyCooldown > 0 then
        EVENT_MANAGER:RegisterForUpdate("updateFrenzy", 1000, processFrenzy)
        ffAddonLabelSynergy:SetText(text)
        frenzyCooldown = frenzyCooldown - 1
    else
        EVENT_MANAGER:UnregisterForUpdate("updateFrenzy")
        ffAddonLabelSynergy:SetText("")
        frenzyCooldown = 19
		if isLibAvailable() and feedingFrenzyTracker.savedVariables.notify and needToNotify then
			needToNotify = false
            LibNotify.notifyForAddonPlease(appName, frenzyAbilityID, "Feeding Frenzy Ready")
        end
    end
end

local function combatReport(eventCode, changeType, effectSlot, effectName, unitTag,
    beginTime, endTimeParam, stackCount, iconNameParam, buffType, effectType,
    abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)

    if abilityId ~= frenzyAbilityID then return end

    local nameTmp = GetUnitName("player")

    --d(changeType)	 -- 1 is gained, 2 is gone, 3 is update

    if changeType == 1 then
        --gained frenzy, only first time when no frenzy is active 
        return
    elseif changeType == 2 then
        --frenzy finished
		needToNotify = true
        return
    elseif changeType == 3 and nameTmp == cleanName(unitName) then
        --here start 20 second timer that refreshes each time you
        frenzyCooldown = 19
        processFrenzy()
    else
        end

end

--when UI opens
local function onMenuOpened()
    isMenuOpen = true
    ffAddon:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if feedingFrenzyTracker.savedVariables.trackFF and isEquiped and feedingFrenzyTracker.savedVariables.autoTrack then
        ffAddon:SetHidden(false)
    elseif feedingFrenzyTracker.savedVariables.trackFF and not feedingFrenzyTracker.savedVariables.autoTrack then
        ffAddon:SetHidden(false)
    end
end

--menu has been opened
local function onSceneStateChange(scene, oldState, newState)
    if isLoaded then
        local sceneName = SCENE_MANAGER:GetCurrentScene():GetName()

        if sceneName == "hud" then
            if  newState == SCENE_HIDING then onMenuOpened()
            elseif  newState == SCENE_HIDDEN then onMenuClosed()
            end
        end
    end
end

--register for notifications 
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("feedfrenzy", EVENT_EFFECT_CHANGED, combatReport)
    EVENT_MANAGER:AddFilterForEvent("feedfrenzy", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, frenzyAbilityID)
    EVENT_MANAGER:RegisterForEvent("courageBuff", EVENT_COMBAT_EVENT, combatReportCourage)
    EVENT_MANAGER:AddFilterForEvent("courageBuff", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, ferociousRoarAbilityID)
end

--unregister for notifications
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("feedfrenzy", EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent("courageBuff", EVENT_EFFECT_CHANGED)
end

--change icon anchor to move icon around the screen at app start
local function setAnchorStartupIcon(x, y)  
    ffAddon:ClearAnchors()
    ffAddon:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    ffAddon:SetHidden(false)
    zo_callLater(function () if isMenuOpen == true then ffAddon:SetHidden(true) end end, 2000)
    ffAddon:ClearAnchors()
    ffAddon:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--process callback that ultimate value has changed
local function ultimateUpdate(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
    local ultValMin = feedingFrenzyTracker.savedVariables.ultValueMin

    --reset the trigger when ultimate rises above the threshold
    if powerValue > ultValMin then
        ultThresholdTriggered = false
    end

    --trigger only once while ultimate is at or below the threshold
    if not ultThresholdTriggered and powerValue <= ultValMin and IsPlayerInWerewolfForm() and powerValue < ultiValuePrevious then
        if isLibAvailable() and feedingFrenzyTracker.savedVariables.trackUlti then
            LibNotify.notifyForAddonPlease(appName, frenzyAbilityID, "Time to Feed!")
        end
        ultThresholdTriggered = true
    end

    --track the previous ultimate value
    ultiValuePrevious = powerValue
end

--setup options menu
local function createOptions()

    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "Feeding Frenzy Tracker",
        displayName = "Feeding Frenzy Tracker",
        author = "codewarrior82",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "description",
            title = "Add-On Settings",
            width = "full",
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Track Buff",
            tooltip = "Displays a timer while the Ferocious Roar Major Courage buff is active and a smaller timer while the Feeding Frenzy synergy is on cooldown.",
            getFunc = function()
                return feedingFrenzyTracker.savedVariables.trackFF
            end,
            setFunc = function(value)
                feedingFrenzyTracker.savedVariables.trackFF = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = feedingFrenzyTracker.defaults.trackFF,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you have the correct ability equipped and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return feedingFrenzyTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                feedingFrenzyTracker.savedVariables.autoTrack = value
            end,
            default = feedingFrenzyTracker.defaults.autoTrack,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 2200, step = 10,
            getFunc = function()
                return feedingFrenzyTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                feedingFrenzyTracker.savedVariables.xAxisText = value
                setAnchorIcon(feedingFrenzyTracker.savedVariables.xAxisText, feedingFrenzyTracker.savedVariables.yAxisText)
            end,
            default = feedingFrenzyTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1200, step = 10,
            getFunc = function()
                return feedingFrenzyTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                feedingFrenzyTracker.savedVariables.yAxisText = value
                setAnchorIcon(feedingFrenzyTracker.savedVariables.xAxisText, feedingFrenzyTracker.savedVariables.yAxisText)
            end,
            default = feedingFrenzyTracker.defaults.yAxisText,
        },
		{
            type = "checkbox",
            name = "Notification",
            tooltip = "Displays a notification and plays a sound when the cooldown on Feeding Frenzy has finished and you are able to take the synergy again.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return feedingFrenzyTracker.savedVariables.notify
            end,
            setFunc = function(value)
                feedingFrenzyTracker.savedVariables.notify = value
            end,
            default = feedingFrenzyTracker.defaults.notify,
        },
        {
            type = "checkbox",
            name = "Track Feeding",
            tooltip = "Track your ultimate level and display a notification when feeding becomes a priority.\nSet the minimum value below, when your ultimate drops to the minimum value you will receive a notification that it's time to feed. This option will only work if the main tracking at the top is enabled.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return feedingFrenzyTracker.savedVariables.trackUlti
            end,
            setFunc = function(value)
                feedingFrenzyTracker.savedVariables.trackUlti = value
                if value  and feedingFrenzyTracker.savedVariables.trackFF then
                    EVENT_MANAGER:RegisterForEvent("askUlti", EVENT_POWER_UPDATE, ultimateUpdate)
                    EVENT_MANAGER:AddFilterForEvent("askUlti", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_ULTIMATE)
                else
                    EVENT_MANAGER:UnregisterForEvent("askUlti", EVENT_POWER_UPDATE)
                end
            end,
            default = feedingFrenzyTracker.defaults.trackUlti,
        },
        {
            type = "slider",
            name = "Minumum Value",
            tooltip = "The amount of ultimate you need to drop to for you to be notified that it's time to feed.",
            min = 0, max = 500, step = 1,
            getFunc = function()
                return feedingFrenzyTracker.savedVariables.ultValueMin
            end,
            setFunc = function(value)
                feedingFrenzyTracker.savedVariables.ultValueMin = value
            end,
            default = feedingFrenzyTracker.defaults.ultValueMin,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("feed frenz Tracker", panelData)
    LAM:RegisterOptionControls("feed frenz Tracker", optionsData)
end

--stop tracking if set is not equipped
local function stopTrackingAuto()

    if feedingFrenzyTracker.savedVariables.trackFF and feedingFrenzyTracker.savedVariables.autoTrack then
        unRegisterAlerts()
        ffAddon:SetHidden(true)
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if feedingFrenzyTracker.savedVariables.trackFF and feedingFrenzyTracker.savedVariables.autoTrack then
        registerAlerts()
        if not isMenuOpen then ffAddon:SetHidden(false) end
    end
end

--check werewolf bar for ferocious roar
local function checkSkills()
    --hotbarCategory = HOTBAR_CATEGORY_PRIMARY / HOTBAR_CATEGORY_BACKUP
    --index is 1 and 2 are heavy attack and bash, 3 through 7 are skills, 8 is ulti

    for slotIndex = 3, 8 do
        local skillId = GetSlotBoundId(slotIndex, HOTBAR_CATEGORY_WEREWOLF)
        --printMessage("slotIndex - " .. tostring(slotIndex))
        --printMessage("skill id - " .. tostring(skillId))
        if skillId >= 0 then
            if skillId == ferociousRoarAbilityID then
                printMessage("ferocious roar equipped")
				isEquiped = true
				startTrackingAuto()
                return
            end
        end
    end
    printMessage("ferocious roar not equipped")
	isEquiped = false
	stopTrackingAuto()
    return
end

--handle werewolf form change callback
local function werewolfStateChanged(eventCode, isWerewolf)
    if isWerewolf and feedingFrenzyTracker.savedVariables.autoTrack and feedingFrenzyTracker.savedVariables.trackFF and needNotify then
        needNotify = false
        zo_callLater(function() needNotify = true end, 2000)
        zo_callLater(function() checkSkills() end, 500)
    elseif not isWerewolf and feedingFrenzyTracker.savedVariables.autoTrack and feedingFrenzyTracker.savedVariables.trackFF and needNotify then
        needNotify = false
        printMessage("ferocious roar not equipped")
        stopTrackingAuto()
        zo_callLater(function() needNotify = true end, 2000)
    end
end

--an addon has loaded
local function onAddOnLoaded(event, name)

    --if add-on loaded was not this add-on quit
    if name ~= appName then
        return
    end

    --unregister for notifications of add-on loaded
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)

    --load saved variables
    feedingFrenzyTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("feedAddonVars", 1, "Settings", feedingFrenzyTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()

    --notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 400)
		return
	elseif isLibAvailable() and feedingFrenzyTracker.savedVariables.trackFF then
		--notify that add-on has been loaded
	    zo_callLater(function() printMessage("add-on loaded") end, 400)
	end

    --check if set is equipped
    if feedingFrenzyTracker.savedVariables.autoTrack and feedingFrenzyTracker.savedVariables.trackFF and IsPlayerInWerewolfForm() then
        zo_callLater(function() checkSkills() end, 600)
    end

    zo_callLater(function()
        local currentUlt, maxUlt, effectiveMax = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE)
        ultiValuePrevious = currentUlt
    end, 500)

    --if tracking ulti is enabled
    if feedingFrenzyTracker.savedVariables.trackUlti and feedingFrenzyTracker.savedVariables.trackFF then
        EVENT_MANAGER:RegisterForEvent("askUlti", EVENT_POWER_UPDATE, ultimateUpdate)
        EVENT_MANAGER:AddFilterForEvent("askUlti", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_ULTIMATE)
    end

    --setup text field areas
    ffAddon:SetMovable(true)
    ffAddonIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    ffAddonLabelCourage:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_54)|soft-shadow-thick")
    ffAddonLabelSynergy:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_34)|soft-shadow-thick")
    ffAddonIcon:SetText(iconText)
    ffAddonLabelCourage:SetText("")
    ffAddonLabelSynergy:SetText("")

    setAnchorStartupIcon(feedingFrenzyTracker.savedVariables.xAxisText, feedingFrenzyTracker.savedVariables.yAxisText)

    --register for combat alerts if tracking is enabled
    if feedingFrenzyTracker.savedVariables.trackFF and not feedingFrenzyTracker.savedVariables.autoTrack then
        registerAlerts()
        ffAddon:SetHidden(false)
    elseif feedingFrenzyTracker.savedVariables.trackFF and feedingFrenzyTracker.savedVariables.autoTrack and isEquiped then
        registerAlerts()
        ffAddon:SetHidden(false)
    elseif feedingFrenzyTracker.savedVariables.trackFF and feedingFrenzyTracker.savedVariables.autoTrack and not isEquiped then
        ffAddon:SetHidden(true)
    elseif not feedingFrenzyTracker.savedVariables.trackFF then
        ffAddon:SetHidden(true)
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --register for a callback when switching in / out of werwolf form
	EVENT_MANAGER:RegisterForEvent("stateChangeWere", EVENT_WEREWOLF_STATE_CHANGED, werewolfStateChanged)

	--register for a callback when a skill is change, removed or updated, then check for relevent ulti
    ACTION_BAR_ASSIGNMENT_MANAGER:RegisterCallback("SlotUpdated", function(actionSlotIndex, hotbarCategory, isChangedByPlayer)
        if isChangedByPlayer and IsPlayerInWerewolfForm() and feedingFrenzyTracker.savedVariables.autoTrack and feedingFrenzyTracker.savedVariables.trackFF  then zo_callLater(function() checkSkills() end, 500) end
    end)

    --register for a callback when loading screen has been activated
    EVENT_MANAGER:RegisterForEvent("zoneCheckWere", EVENT_PLAYER_ACTIVATED, function()
        -- Give the UI a split second to settle after a loading screen
        zo_callLater(function() if IsPlayerInWerewolfForm() and feedingFrenzyTracker.savedVariables.autoTrack and feedingFrenzyTracker.savedVariables.trackFF  then checkSkills() end end, 500)
    end)

    --register for a callback when the armory station is used
    EVENT_MANAGER:RegisterForEvent("armoryCheckWere", EVENT_ARMORY_BUILD_RESTORED, function(eventCode, buildIndex, success)
        if success then
            zo_callLater(function() if IsPlayerInWerewolfForm() and feedingFrenzyTracker.savedVariables.autoTrack and feedingFrenzyTracker.savedVariables.trackFF then checkSkills() end end, 500)
        end
    end)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)