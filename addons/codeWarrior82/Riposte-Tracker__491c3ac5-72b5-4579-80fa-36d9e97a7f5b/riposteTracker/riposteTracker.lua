local appName = "riposteTracker"
local appVersion = 1 -- bump this on each update
local name = "Riposte Tracker"
local info = "What's New:\nAdded option to resize tracker visual."
local alreadyChecked = false
local notFoundAlreadyChecked = false
local riposteAbilityID = 60230
local timeRemaining = 0
local picPath = GetAbilityIcon(riposteAbilityID)
-- [REMOVED] iconText using zo_iconTextFormat (replaced with <Texture> in XML so icon has zero font baseline padding)
local isLoaded = false
local isMenuOpen = false
local trackingRiposte = false
local riposteCp = 162
local isEquiped = false

-- [ADDED] 10 proportional size stages (1 = Smallest to 10 = Largest)
local sizeStages = {
    { font = "$(GP_27)", cornerFont = "$(GP_18)", icon = 36 },
    { font = "$(GP_34)", cornerFont = "$(GP_20)", icon = 45 },
    { font = "$(GP_36)", cornerFont = "$(GP_22)", icon = 47 },
    { font = "$(GP_42)", cornerFont = "$(GP_25)", icon = 55 },
    { font = "$(GP_54)", cornerFont = "$(GP_27)", icon = 71 },
    { font = "$(GP_61)", cornerFont = "$(GP_34)", icon = 80 },
}

riposteTracker = {}

riposteTracker.defaults = {
    trackRip = true,
    autoTrack = true,
    notify = false,
    notifyStart = true,
    yAxisText = 930,
    xAxisText = 1400,
    uiSize = 6, -- [ADDED] Default size stage (10 = 80x80 icon + GP_61 font)
    lastSeenVersion = 0
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

--check champion points
local function checkCP(id)
    for i = 1, 12 do
        local skillId = GetSlotBoundId(i, HOTBAR_CATEGORY_CHAMPION)

        if skillId and skillId > 0 then
            local skillName = GetChampionSkillName(skillId)

            if skillId == id then
                return true
            end
        end
    end
    return false
end

-- [ADDED] Dynamically scales container, texture icon, and fonts, then measures actual rendered text height to center digits
local function updateTrackerSize(stage)
    local s = sizeStages[stage] or sizeStages[6]
    riptrack:SetDimensions(s.icon, s.icon)

    riptrackIcon:SetTexture(picPath)
    riptrackLabelMain:SetFont("$(GAMEPAD_BOLD_FONT)|" .. s.font .. "|soft-shadow-thick")
    riptrackLabelCorner:SetFont("$(GAMEPAD_MEDIUM_FONT)|" .. s.cornerFont .. "|soft-shadow-thick")

    --measure rendered glyph height to dynamically compensate for gamepad font ascender/descender padding
    local prevText = riptrackLabelMain:GetText()
    riptrackLabelMain:SetText("0")
    local textHeight = riptrackLabelMain:GetTextHeight()
    riptrackLabelMain:SetText(prevText)

    --work out y offset based on size of icon and text
    local dynamicOffsetY = math.floor((s.icon - textHeight) * 0.12)
    riptrackLabelMain:ClearAnchors()
    riptrackLabelMain:SetAnchor(CENTER, riptrack, CENTER, 0, dynamicOffsetY)
end

--when UI opens
local function onMenuOpened()
    isMenuOpen = true
    riptrack:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
    isMenuOpen = false
    if riposteTracker.savedVariables.trackRip and isEquiped and riposteTracker.savedVariables.autoTrack then
        riptrack:SetHidden(false)
    elseif riposteTracker.savedVariables.trackRip and not riposteTracker.savedVariables.autoTrack then
        riptrack:SetHidden(false)
    end
end

--scene state change
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

--change icon anchor to move around the screen at app start
local function setAnchorStartupIcon(x, y)  
    riptrack:ClearAnchors()
    riptrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    riptrack:SetHidden(false)
    zo_callLater(function () if isMenuOpen == true then riptrack:SetHidden(true) end end, 2000)
    riptrack:ClearAnchors()
    riptrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--check if buff is active
local function buffActive()

    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, stackCount, _, _, _, iconFilename, _, abilityId, _, _ = GetUnitBuffInfo("player", i)

        if abilityId == riposteAbilityID then
            timeRemaining = timeEnding - GetFrameTimeSeconds()
            return true
        end
    end
    return false
end

--handle if player has buff
local function processBuff()
    
    if buffActive() then

        trackingRiposte = true

        -- [CHANGED] Removed leading spaces so centered text aligns cleanly at every scale
        riptrackLabelMain:SetText(string.format("%d", timeRemaining))

        zo_callLater(function() processBuff() end, 1000)
    else
        trackingRiposte = false
        riptrackLabelMain:SetText("")
    end
end

--report when new effect is gained
local function effectReport(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, 
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    local nameTmp = GetUnitName("player")

    if nameTmp ~= cleanName(unitName) or abilityID ~= riposteAbilityID then
        return
    end

    if changeType == 2 then
        riptrackLabelMain:SetText("")
        trackingRiposte = false
        if isLibAvailable() and riposteTracker.savedVariables.notify then
            LibNotify.notifyForAddonPlease(appName, riposteAbilityID, "Riposte ended")
        end	
        return
    end

    if not trackingRiposte then
        if isLibAvailable() and riposteTracker.savedVariables.notifyStart then
            LibNotify.notifyForAddonPlease(appName, riposteAbilityID, "Riposte Ready")
        end	
        processBuff()
    end

end

--register for notifications about archdruid proc
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("ripProc", EVENT_EFFECT_CHANGED, effectReport)
    EVENT_MANAGER:AddFilterForEvent("ripProc", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, riposteAbilityID)
end

--unregister for notifications about proc
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("ripProc", EVENT_EFFECT_CHANGED)
end

--stop tracking if set is not equipped
local function stopTrackingAuto()

    if riposteTracker.savedVariables.trackRip and riposteTracker.savedVariables.autoTrack then
        if not notFoundAlreadyChecked then
            printMessage("Riposte CP not found")
        end
        notFoundAlreadyChecked = true
        alreadyChecked = false
        unRegisterAlerts()
        riptrack:SetHidden(true)
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if riposteTracker.savedVariables.trackRip and riposteTracker.savedVariables.autoTrack then 
        if not alreadyChecked then
            printMessage("Found Riposte CP")
        end
        alreadyChecked = true
        notFoundAlreadyChecked = false
        registerAlerts()
    end
end

--handle champion points being changed
function riposteTracker.onChampionPurchaseResult(eventCode, result)
    if checkCP(riposteCp) then isEquiped = true startTrackingAuto() else isEquiped = false stopTrackingAuto() end
end

--setup options menu
local function createOptions()

    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "Riposte Tracker",
        displayName = "Riposte Tracker",
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
            name = "Track buff and cooldown",
            tooltip = "Displays the current stack amount of Gorethief while Gorethief is active.",
            getFunc = function()
                return riposteTracker.savedVariables.trackRip
            end,
            setFunc = function(value)
                riposteTracker.savedVariables.trackRip = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = riposteTracker.defaults.trackRip,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you have the Riposte CP slotted and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return riposteTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                riposteTracker.savedVariables.autoTrack = value
            end,
            default = riposteTracker.defaults.autoTrack,
        },
        -- [ADDED] 6-stage proportional size slider options to menu
        {
            type = "slider",
            name = "Tracker Size",
            tooltip = "Adjust the overall size of the icon and timer text.",
            min = 1, max = 6, step = 1,
            getFunc = function()
                return riposteTracker.savedVariables.uiSize
            end,
            setFunc = function(value)
                riposteTracker.savedVariables.uiSize = value
                updateTrackerSize(value)
                setAnchorIcon(riposteTracker.savedVariables.xAxisText, riposteTracker.savedVariables.yAxisText)
            end,
            default = riposteTracker.defaults.uiSize,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 2200, step = 10,
            getFunc = function()
                return riposteTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                riposteTracker.savedVariables.xAxisText = value
                setAnchorIcon(riposteTracker.savedVariables.xAxisText, riposteTracker.savedVariables.yAxisText)
            end,
            default = riposteTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1200, step = 10,
            getFunc = function()
                return riposteTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                riposteTracker.savedVariables.yAxisText = value
                setAnchorIcon(riposteTracker.savedVariables.xAxisText, riposteTracker.savedVariables.yAxisText)
            end,
            default = riposteTracker.defaults.yAxisText,
        },
        {
            type = "checkbox",
            name = "Notification Start",
            tooltip = "Displays a notification and plays a sound when the Riposte buff starts.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return riposteTracker.savedVariables.notifyStart
            end,
            setFunc = function(value)
                riposteTracker.savedVariables.notifyStart = value
            end,
            default = riposteTracker.defaults.notifyStart,
        },
        {
            type = "checkbox",
            name = "Notification End",
            tooltip = "Displays a notification and plays a sound when the Riposte buff finishes.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return riposteTracker.savedVariables.notify
            end,
            setFunc = function(value)
                riposteTracker.savedVariables.notify = value
            end,
            default = riposteTracker.defaults.notify,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Riposte Tracker", panelData)
    LAM:RegisterOptionControls("Riposte Tracker", optionsData)
end

--notify about update when player activates
local function activated()
    if riposteTracker.savedVariables.lastSeenVersion ~= appVersion then
        zo_callLater(function() LibNotify.postUpdateNotification(appName, info, name) end, 500)
        riposteTracker.savedVariables.lastSeenVersion = appVersion
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
    riposteTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("ripAddonVars", 1, "Settings", riposteTracker.defaults, GetUnitName("player"))

	-- [ADDED] Clamp saved uiSize to 1-6 in case an older saved variable held 7-10, just for first testing in first addon
    if riposteTracker.savedVariables.uiSize > 6 then
        riposteTracker.savedVariables.uiSize = 6
    elseif riposteTracker.savedVariables.uiSize < 1 then
        riposteTracker.savedVariables.uiSize = 1
    end

    --setup add on menu options
    createOptions()

    --notify about new library
    if not isLibAvailable() then
        zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 500)
        return
    elseif isLibAvailable() and riposteTracker.savedVariables.trackRip then
        --notify that add-on has been loaded
        zo_callLater(function() printMessage("add-on loaded") end, 500)
    end

    zo_callLater(function ()
        if checkCP(riposteCp) and riposteTracker.savedVariables.autoTrack and riposteTracker.savedVariables.trackRip then
            isEquiped = true
            printMessage("Found Riposte CP")
            alreadyChecked = true
        elseif not checkCP(riposteCp) and riposteTracker.savedVariables.autoTrack and riposteTracker.savedVariables.trackRip then
            printMessage("Riposte CP not found")
            notFoundAlreadyChecked = true
        end
    end, 1000)

    --setup text field areas
    riptrack:SetMovable(true)
    riptrackLabelMain:SetText("")
    -- [CHANGED] Applies saved scale, sets texture icon, and dynamically centers the countdown label
    updateTrackerSize(riposteTracker.savedVariables.uiSize)

    --setup icons place on screen
    setAnchorStartupIcon(riposteTracker.savedVariables.xAxisText, riposteTracker.savedVariables.yAxisText)

    --register for combat alerts if tracking is enabled
    zo_callLater(function ()
        if riposteTracker.savedVariables.trackRip and not riposteTracker.savedVariables.autoTrack then
            registerAlerts()
            riptrack:SetHidden(false)
        elseif riposteTracker.savedVariables.trackRip and riposteTracker.savedVariables.autoTrack and isEquiped then
            registerAlerts()
            riptrack:SetHidden(false)
        elseif riposteTracker.savedVariables.trackRip and riposteTracker.savedVariables.autoTrack and not isEquiped then
            riptrack:SetHidden(true)
        elseif not riposteTracker.savedVariables.trackRip then
            riptrack:SetHidden(true)
        end
    end, 1200)

    --must keep these firing
    EVENT_MANAGER:RegisterForEvent("callbackRiposte", EVENT_CHAMPION_PURCHASE_RESULT, riposteTracker.onChampionPurchaseResult)

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)
    
    --register for activation notifications, leaving this always active
    EVENT_MANAGER:RegisterForEvent(appName, EVENT_PLAYER_ACTIVATED, activated)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)
