local appName = "necroTracker"

local isLoaded = false
local BlastbonesSkillId = 117691
local nothingWastedSkillId = 263461
local isMenuOpen = false
local colourStartupText
local colourStartupNumber
local colourSet

necroTracker = {}

necroTracker.defaults = {
    trackNecro = true,
    yAxisText = 550,
    xAxisText = 450,
    textColor = { 0, 1, 0, 1 },
    numberColor = { 1, 0, 0, 1 }
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

--when UI opens
local function onMenuOpened()
	isMenuOpen = true
    necroText:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if necroTracker.savedVariables.trackNecro then
        necroText:SetHidden(false)
    end
end

--handle UI change when hud opens
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

--change anchor to move around the screen at app start
local function setAnchorStartup(x, y)  
    necroText:ClearAnchors()
    necroText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchor(x, y)  
    necroText:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then necroText:SetHidden(true) end end, 2000)
    necroText:ClearAnchors()
    necroText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end








--handle combat notifications
local function combatReport(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName,
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    if isError then
        return
    end

    local nameTmp = GetUnitName("player")

    if nameTmp ~= cleanName(sourceName) then
        return
    end

    if abilityId ~= BlastbonesSkillId then
        return
    end

    --all good, start timer ?
end

--handle effect changes
local function effectReport(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, 
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    --(changeType)	 -- 1 is gained, 2 is gone, 3 is update
	--(effectType)	 -- 1 is debuff, 0 is buff
    printMessage(" ")
    printMessage("effectReport")
    if changeType == 1 then
        printMessage("gained effect")
    elseif changeType == 2 then
        printMessage("lost effect")
    elseif changeType == 3 then
        printMessage("effect update")
    else
        printMessage(zo_strformat("changeType- <<1>>", changeType))
    end

    printMessage(zo_strformat("effectName- <<1>>", effectName))
    printMessage(zo_strformat("unitName- <<1>>", unitName))
    printMessage(zo_strformat("stackCount- " ..stackCount))
    printMessage(zo_strformat("abilityID- <<1>>", abilityID))
    printMessage(" ")
end

--register for notifications 
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("effectReport", EVENT_EFFECT_CHANGED, effectReport)
    EVENT_MANAGER:AddFilterForEvent("effectReport", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, nothingWastedSkillId)
    EVENT_MANAGER:RegisterForEvent("combatReport", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("combatReport", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, BlastbonesSkillId)
end

--unregister for notifications
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("effectReport", EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent("combatReport", EVENT_COMBAT_EVENT)
end

--setup options menu
local function createOptions()

    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "Necro Tracker",
        displayName = "Necro Tracker",
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
            tooltip = "Displays a timer while the Huntsman's Warmask buff is active.",
            getFunc = function()
                return necroTracker.savedVariables.trackNecro
            end,
            setFunc = function(value)
                necroTracker.savedVariables.trackNecro = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = necroTracker.defaults.trackNecro,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen text.",
            min = 0, max = 2200, step = 10,
            getFunc = function()
                return necroTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                necroTracker.savedVariables.xAxisText = value
                setAnchor(necroTracker.savedVariables.xAxisText, necroTracker.savedVariables.yAxisText)
            end,
            default = necroTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen text.",
            min = 0, max = 1200, step = 10,
            getFunc = function()
                return necroTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                necroTracker.savedVariables.yAxisText = value
                setAnchor(necroTracker.savedVariables.xAxisText, necroTracker.savedVariables.yAxisText)
            end,
            default = necroTracker.defaults.yAxisText,
        },
        {
            type = "colorpicker",
            name = "Text colour",
            tooltip = "Change the colour of the notification text.",
            default = ZO_ColorDef:New(unpack(necroTracker.defaults.textColor)),
            getFunc = function ()
                return unpack(necroTracker.savedVariables.textColor)
            end,
            setFunc = function (r, g, b, a)
                necroTracker.savedVariables.textColor = { r, g, b, a }
                colourSet = ZO_ColorDef:New(unpack(necroTracker.savedVariables.textColor))
                necroTextBlast:SetColor(colourSet:UnpackRGBA())
                necroTextWaste:SetColor(colourSet:UnpackRGBA())
                necroTextCorpse:SetColor(colourSet:UnpackRGBA())
            end,
        },
        {
            type = "button",
            name = "Test Colour",
            tooltip = "Show a short notification with the new colour you have set.",
            func = function()
                necroText:SetHidden(false)
                zo_callLater(function () if isMenuOpen == true then necroText:SetHidden(true) end end, 2000)
             end,
        },
        --numbers colour
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Necro Tracker", panelData)
    LAM:RegisterOptionControls("Necro Tracker", optionsData)
end

--add-on loaded
local function libLoaded(event, name)
    --if add-on loaded was not this add-on quit
    if name ~= appName then return end
    --unregister for notifications of add-on loaded
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)

    --load saved variables
    necroTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("necroTrackerSaveVars", 1, "Settings", necroTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()

    colourStartupText = ZO_ColorDef:New(unpack(necroTracker.savedVariables.textColor))

    --setup text fields
    necroText:SetMovable(true)

    necroTextBlast:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    necroTextBlast:SetText("Blastbones: ")
    necroTextBlast:SetColor(colourStartupText:UnpackRGBA())

    necroTextWaste:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    necroTextWaste:SetText("Nothing Wasted: ")
    necroTextWaste:SetColor(colourStartupText:UnpackRGBA())

    necroTextCorpse:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    necroTextCorpse:SetText("Corpses: ")
    necroTextCorpse:SetColor(colourStartupText:UnpackRGBA())

    setAnchorStartup(necroTracker.savedVariables.xAxisText, necroTracker.savedVariables.yAxisText)

    if necroTracker.savedVariables.trackNecro then
        zo_callLater(function() printMessage("add-on loaded") end, 400)
        necroText:SetHidden(false)
        registerAlerts()
    else
        necroText:SetHidden(true)
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, libLoaded)