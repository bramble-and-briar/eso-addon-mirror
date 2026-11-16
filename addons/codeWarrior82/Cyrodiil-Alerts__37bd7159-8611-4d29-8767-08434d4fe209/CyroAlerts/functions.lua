functions = {}
functions.__index = functions

--print message to chat box
function functions.printMessage(msg)

    --initialize proxy for chat
    local chat = LibChatMessage(appName, "MA")
    chat:Print(msg)
end

--notification for corrosive
function functions.showCorrosive()
    PlaySound(SOUNDS.ANTIQUITIES_FANFARE_FAILURE)
    corrosiveTextLabel:SetHidden(false)
    zo_callLater(function() functions.hideCorrosive() end, 800)
end
function functions.hideCorrosive()
    corrosiveTextLabel:SetHidden(true)
end

--notification for corrosive when setting x and y positions in options menu
function functions.showCorrosiveSet()
    corrosiveTextLabel:SetHidden(false)
    zo_callLater(function () functions.hideCorrosiveSet() end, 2000)
end
function functions.hideCorrosiveSet()
    corrosiveTextLabel:SetHidden(true)
end

--notification for onslaught
function functions.showOnslaught()
    PlaySound(SOUNDS.ANTIQUITIES_FANFARE_FAILURE)
    onslaughtTextLabel:SetHidden(false)
    zo_callLater(function() functions.hideOnslaught() end, 8000)
end
function functions.hideOnslaught()
    onslaughtTextLabel:SetHidden(true)
end

--notification for onslaught when setting x and y positions in options menu
function functions.showOnslaughtSet()
    onslaughtTextLabel:SetHidden(false)
    zo_callLater(function () functions.hideOnslaughtSet() end, 2000)
end
function functions.hideOnslaughtSet()
    onslaughtTextLabel:SetHidden(true)
end

--post system message to middle of screen
function functions.screenNotify(msg, path)
    --"esoui/art/icons/achievement_su_psijic_order_complete.dds"
    local preText = "|cFF0000Alert  |r "
    local iconText = zo_iconTextFormat(path, 50, 50, " ")
    local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.ANTIQUITIES_FANFARE_FAILURE)
    messageParams:SetText(iconText .. preText .. msg)
    messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_OBJECTIVE_COMPLETED)
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
end

--stop and start functions for takeover notifications
function functions.stopAll()
    functions.printMessage("Takeover notifications disabled")
    cyroTextLabel:SetText("Alerts - Inactive")
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_KEEP_UNDER_ATTACK_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_KEEP_ALLIANCE_OWNER_CHANGED)
end
function functions.startAll()
    functions.printMessage("Takeover notifications enabled")
    cyroTextLabel:SetText("Alerts - Active")
    if IsPlayerInAvAWorld() then
        EVENT_MANAGER:RegisterForEvent(appName, EVENT_KEEP_UNDER_ATTACK_CHANGED, functions.keepStatusUpdate)
        EVENT_MANAGER:RegisterForEvent(appName, EVENT_KEEP_ALLIANCE_OWNER_CHANGED, functions.keepOwnerChanged)
    end
end

--handle zone change
function functions.zoneChanged(_, initial)

	if appStart.savedVariables.lastSeenVersion ~= appStart.appVersion then
        zo_callLater(function() LibNotify.postUpdateNotification(appName, "What's New:\nAdded map pins to show Volendrung spawn points on the map, disabled by default.", "Cyrodiil Alerts") end, 500)
        appStart.savedVariables.lastSeenVersion = appStart.appVersion
    end

    if IsPlayerInAvAWorld() then

        local campaignID = GetCurrentCampaignId()
        
        --campaign ID list
        local IC_CP = 95
        local IC_NO_CP = 96
        local BR = 101
        local GH = 102
        local RW = 103
        local IR = 104
        local EG = 0

        local campaign = "unknown"

        if campaignID == 95 then campaign = "Imperial City"
        elseif campaignID == 96 then campaign = "NO_CP IC"
        elseif campaignID == 101 then campaign = "Blackreach"
        elseif campaignID == 102 then campaign = "Grey Host"
        elseif campaignID == 103 then campaign = "Ravenwatch"
        elseif campaignID == 104 then campaign = "Icereach"
        elseif campaignID == 105 then campaign = "Evergloam" end

        if campaignID ~= appStart.currentZone then
            zo_callLater(function() functions.printMessage(zo_strformat("PvP zone detected - <<C:1>>",campaign)) end, 1000)
        end

        if appStart.savedVariables.alertsEnabled then
            EVENT_MANAGER:RegisterForEvent(appName, EVENT_KEEP_UNDER_ATTACK_CHANGED, functions.keepStatusUpdate)
            EVENT_MANAGER:RegisterForEvent(appName, EVENT_KEEP_ALLIANCE_OWNER_CHANGED, functions.keepOwnerChanged)
        end

        appStart.currentZone = GetCurrentCampaignId()
    else
        EVENT_MANAGER:UnregisterForEvent(appName, EVENT_KEEP_UNDER_ATTACK_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(appName, EVENT_KEEP_ALLIANCE_OWNER_CHANGED)
    end
end

--handle keep alerts
function functions.keepStatusUpdate(_, keepID, battlegroundContext, underAttack)

    --hide IC district battles
    if GetKeepType(keepID) == KEEPTYPE_IMPERIAL_CITY_DISTRICT then
        return;
    end

    --need name of keep or resource
    if underAttack then
       functions.printMessage(zo_strformat("<<C:1>> - Under Attack",functions.shortenName(GetKeepName(keepID))))
    end
end

--handle change of alliance ownership
function functions.keepOwnerChanged(_, keepID, battlegroundContext, owningAlliance, oldAlliance)

	--hide IC district battles
    if GetKeepType(keepID) == KEEPTYPE_IMPERIAL_CITY_DISTRICT then
        return;
    end

    local colour = "none"
    local oldColour = "none"

    local AD = 1
    local EP = 2
    local DC = 3

    if owningAlliance == AD then colour = "Yellow" end
    if owningAlliance == DC then colour = "Blue" end
    if owningAlliance == EP then colour = "Red" end

    if oldAlliance == AD then oldColour = "Yellow" end
    if oldAlliance == DC then oldColour = "Blue" end
    if oldAlliance == EP then oldColour = "Red" end

    functions.printMessage("".. zo_strformat("<<C:1>>",functions.shortenName(GetKeepName(keepID))) .. " - Turned " .. colour .. " from " .. oldColour .. "")
end

--process keep names
function functions.shortenName(str)
    return str:gsub(",..$", ""):gsub("%^.d$", "")
    --words to remove
    :gsub("Outpost", "")
    :gsub("Keep", "")
    :gsub("Fort ", "")
    :gsub("Castle ", "")
end

--show or hide text field for status of takeover alerts
function functions.hideAlertText()
    cyroTextLabel:SetHidden(true)
end
function functions.showAlertText()
    cyroTextLabel:SetHidden(false)
end

--process combat state alerts
function functions.combatStatusChanged(eventID, inCombat)
    if inCombat then
        combatStateTextLabel:SetColor(204, 0, 0, 255)
        combatStateTextLabel:SetText("In Combat")
    else 
        combatStateTextLabel:SetColor(0, 204, 0, 255)
        combatStateTextLabel:SetText("Not in Combat")
    end
end

--stop and start functions for combat status
function functions.stopCombat()
    combatStateTextLabel:SetHidden(true)
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_PLAYER_COMBAT_STATE)
    functions.printMessage("Combat state updates disabled")
end
function functions.startCombat()
    combatStateTextLabel:SetHidden(false)
    EVENT_MANAGER:RegisterForEvent(appName, EVENT_PLAYER_COMBAT_STATE, functions.combatStatusChanged)
    functions.printMessage("Combat state updates enabled")
end

--show vampire stage
function functions.showVamp()
    vampTextLabel:SetHidden(false)
end
function functions.hideVamp()
    vampTextLabel:SetHidden(true)
end

--stop or start vampire notifications
function functions.stopVamp()
    vampTextLabel:SetHidden(true)
    functions.printMessage("Vampire Stage alerts disabled")
end
function functions.startVamp()
    functions.vampStatus()
    vampTextLabel:SetHidden(false)
    functions.printMessage("Vampire Stage alerts enabled")
end

--sets loaded flag to true, hack for vampire stage to not notify when app first loads 
function functions.setLoaded()
    appStart.loaded = true
end

--search buffs for vampire
function functions.vampStatus()    
    
    local vampPic1 = "/esoui/art/icons/ability_u26_vampire_infection_stage1.dds"
    local vampPic2 = "/esoui/art/icons/ability_u26_vampire_infection_stage2.dds"
    local vampPic3 = "/esoui/art/icons/ability_u26_vampire_infection_stage3.dds"
    local vampPic4 = "/esoui/art/icons/ability_u26_vampire_infection_stage4.dds"

    local vampPicTmp = ""
    local vampStageTmp = 0
    local vampirismFound = false
    local vampStage = "unknown"
    local numBuffs, buffName, timeStarted, timeEnding, matchResult
    numBuffs = GetNumBuffs("player")

    --very crude to use 4 for loops but i am short of time XD
    for i = 1, numBuffs do
        buffName, timeStarted, timeEnding, _, _, iconFilename, _, _, _, _ = GetUnitBuffInfo("player",i)
        matchResult = PlainStringFind(iconFilename, vampPic1)
        if (matchResult) then
            --found vampirism buff
            vampStage = zo_strformat("<<1>>",buffName)
            vampirismFound = true
            --stop searching for buffs if vampire is found
            vampStageTmp = 1
            vampPicTmp = vampPic1
            break  
        end
    end
    for i = 1, numBuffs do
        buffName, timeStarted, timeEnding, _, _, iconFilename, _, _, _, _ = GetUnitBuffInfo("player",i)
        matchResult = PlainStringFind(iconFilename, vampPic2)
        if (matchResult) then
            --found vampirism buff
            vampStage = zo_strformat("<<1>>",buffName)
            vampirismFound = true
            --stop searching for buffs if vampire is found
            vampStageTmp = 2
            vampPicTmp = vampPic2
            break  
        end
    end
    for i = 1, numBuffs do
        buffName, timeStarted, timeEnding, _, _, iconFilename, _, _, _, _ = GetUnitBuffInfo("player",i)
        matchResult = PlainStringFind(iconFilename, vampPic3)
        if (matchResult) then
            --found vampirism buff
            vampStage = zo_strformat("<<1>>",buffName)
            vampirismFound = true
            --stop searching for buffs if vampire is found
            vampStageTmp = 3
            vampPicTmp = vampPic3
            break  
        end
    end
    for i = 1, numBuffs do
        buffName, timeStarted, timeEnding, _, _, iconFilename, _, _, _, _ = GetUnitBuffInfo("player",i)
        matchResult = PlainStringFind(iconFilename, vampPic4)
        if (matchResult) then
            --found vampirism buff
            vampStage = zo_strformat("<<1>>",buffName)
            vampirismFound = true
            --stop searching for buffs if vampire is found
            vampStageTmp = 4
            vampPicTmp = vampPic4
            break  
        end
    end

    zo_callLater(function() functions.setLoaded() end, 3000)
    
    if appStart.vampStage ~= vampStageTmp and appStart.loaded and appStart.savedVariables.trackVampireStage then
        functions.screenNotify("Vampire Stage changed from " .. appStart.vampStage .. " to " .. vampStageTmp .. "", vampPicTmp)
        functions.printMessage("Vamp Stage changed from " .. appStart.vampStage .. " - " .. vampStageTmp .. "")
    end

    if vampirismFound then
        vampTextLabel:SetText(vampStage)
        appStart.isVamp = true
    else
        vampTextLabel:SetText("Not a Vampire")
        appStart.isVamp = false
    end

    appStart.vampStage = vampStageTmp

    --register for buff changes to catch vamp level changes
    EVENT_MANAGER:RegisterForEvent(appName, EVENT_EFFECT_CHANGED, functions.vampStatus) 
end 

--start and stop tracking corrosive armour
function functions.stopCorrosive()
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_COMBAT_EVENT)
    functions.printMessage("Corrosive Armour alerts disabled")
end
function functions.startCorrosive()
    EVENT_MANAGER:RegisterForEvent(appName, EVENT_COMBAT_EVENT, functions.combatAlert)
    EVENT_MANAGER:AddFilterForEvent(appName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, appStart.corrosiveID)
    functions.printMessage("Corrosive Armour alerts enabled")
end

--start and stop tracking onslaught
function functions.stopOnslaught()
    EVENT_MANAGER:UnregisterForEvent("onslaughtAlert", EVENT_COMBAT_EVENT)
    functions.printMessage("Onslaught alerts disabled")
end
function functions.startOnslaught()
    EVENT_MANAGER:RegisterForEvent("onslaughtAlert", EVENT_COMBAT_EVENT, functions.combatAlertOn)
    EVENT_MANAGER:AddFilterForEvent("onslaughtAlert", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, appStart.onslaughtID)
    functions.printMessage("Onslaught alerts enabled")
end

--handle combat alert
function functions.combatAlert(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, 
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
    
    local nameTmp = GetUnitName("player")

    if isError then
        return
    end

    if abilityId ~= appStart.corrosiveID then
        return
    end

    if functions.cleanName(targetName) == nameTmp then 
        functions.showCorrosive()
    end
end

--handle combat alert
function functions.combatAlertOn(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, 
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
    
    local nameTmp = GetUnitName("player")

    if isError then
        return
    end
    if abilityId ~= appStart.onslaughtID then
        return
    end

    if functions.cleanName(sourceName) ~= nameTmp then
        functions.showOnslaught()
    end
end

--clean player names
function functions.cleanName(str)
    return str:sub(1, -4)
end

--change text anchors to move text around the screen
function functions.setAnchor(x, y)
    
    cyroText:ClearAnchors()
    combatStateText:ClearAnchors()
    vampText:ClearAnchors()

    cyroText:SetHidden(false)
    zo_callLater(function () if appStart.isMenuOpen == true then cyroText:SetHidden(true) end end, 2000)
    combatStateText:SetHidden(false)
    zo_callLater(function () if appStart.isMenuOpen == true then combatStateText:SetHidden(true) end end, 2000)
    vampText:SetHidden(false)
    zo_callLater(function () if appStart.isMenuOpen == true then vampText:SetHidden(true) end end, 2000)

    cyroText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    combatStateText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y + 35)
    vampText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y + 70)
end

--move text anchors to move text around the screen
function functions.setAnchorCorro(x, y)
    corrosiveText:ClearAnchors()
    corrosiveText:SetAnchor(CENTERLEFT, GuiRoot, CENTERLEFT, x, y)
end

--move text anchors to move text around the screen
function functions.setAnchorOnslaught(x, y)
    onslaughtText:ClearAnchors()
    onslaughtText:SetAnchor(CENTERLEFT, GuiRoot, CENTERLEFT, x, y)
end

--register map pins for ayleid wells
function functions.registerPins()

    local layout  = {
        level   = 50,
        size    = 24,
        texture = appStart.wellPinsIcon,
    }

    local tooltip = {
        tooltip = ZO_MAP_TOOLTIP_MODE.INFORMATION,
        creator = function( pin )

        local tooltip = ZO_MapLocationTooltip_Gamepad.tooltip
        local lineSection = tooltip:AcquireSection(tooltip:GetStyle("mapLocationTooltipContentSection"))
        lineSection:AddLine(
            "\nAYLEID WELL",
            {
                fontFace = "$(GAMEPAD_BOLD_FONT)",
                fontSize = "$(GP_36)",
                fontStyle = "soft-shadow-thick",
            },
            tooltip:GetStyle("mapLocationTooltipContentLabel")
        )
        lineSection:AddLine(
            "     Increases Max Health by 10%\n     for 30 minutes.",
            {
                fontFace = "$(GAMEPAD_MEDIUM_FONT)",
                fontSize = "$(GP_27)",
                fontStyle = "soft-shadow-thick",
            },
            tooltip:GetStyle("mapLocationTooltipContentLabel")
        )


        tooltip:AddSection(lineSection)

        end,
    }

    local pinData    = {
        ["cyrodiil/ava_whole"] = {                   -- +
            { x = 0.1854, y = 0.4076 },
            { x = 0.2614, y = 0.6707 },
            { x = 0.3325, y = 0.7289 },
            { x = 0.3610, y = 0.3613 },
            { x = 0.3832, y = 0.5302 },
            { x = 0.3923, y = 0.6916 },
            { x = 0.4380, y = 0.2109 },
            { x = 0.4610, y = 0.2394 },
            { x = 0.4658, y = 0.7643 },
            { x = 0.5054, y = 0.7613 },
            { x = 0.6215, y = 0.7929 },
            { x = 0.6253, y = 0.5077 },
            { x = 0.6277, y = 0.4447 },
            { x = 0.6383, y = 0.6508 },
            { x = 0.6585, y = 0.6944 },
            { x = 0.7062, y = 0.5809 },              -- 18
        }
    }

    appStart.LMP:AddPinType(appStart.wellPinsName, function( pinManager )
        local mapName = appStart.LMP:GetZoneAndSubzone( true )
        local pins    = pinData[mapName]
        
        if pins then
            for _, pinInfo in ipairs( pins ) do
                appStart.LMP:CreatePin(appStart.wellPinsName, pinInfo, pinInfo.x, pinInfo.y )
            end
        end
    end, nil, layout, tooltip )
end

--register map pins for volendrung spawn locations
function functions.registerPinsHammer()

    local layout  = {
        level   = 99,
        size    = 23,
        texture = appStart.hammerPinsIcon,
    }

    local tooltip = {
        tooltip = ZO_MAP_TOOLTIP_MODE.INFORMATION,
        creator = function( pin )

        local tooltip = ZO_MapLocationTooltip_Gamepad.tooltip
        local lineSection = tooltip:AcquireSection(tooltip:GetStyle("mapLocationTooltipContentSection"))
        lineSection:AddLine(
            "\nVOLENDRUNG",
            {
                fontFace = "$(GAMEPAD_BOLD_FONT)",
                fontSize = "$(GP_36)",
                fontStyle = "soft-shadow-thick",
            },
            tooltip:GetStyle("mapLocationTooltipContentLabel")
        )
        lineSection:AddLine(
            "     Possible spawn location\n     for Volendrung.",
            {
                fontFace = "$(GAMEPAD_MEDIUM_FONT)",
                fontSize = "$(GP_27)",
                fontStyle = "soft-shadow-thick",
            },
            tooltip:GetStyle("mapLocationTooltipContentLabel")
        )

        tooltip:AddSection(lineSection)

        end,
    }

    local pinData = {
    ["cyrodiil/ava_whole"] = {                   -- +
        -- South (Aldmeri Dominion)
        { x = 0.5312, y = 0.8761 },              -- 01 (Behind Scroll Gates)
        { x = 0.4840, y = 0.7919 },              -- 07 (Southwest Border)
        { x = 0.6415, y = 0.7695 },              -- 08 (Southeast Border)

        -- Northwest (Daggerfall Covenant)
        { x = 0.1086, y = 0.2312 },              -- 17 (Behind Scroll Gates)
        { x = 0.2091, y = 0.2246 },              -- 18 (Northwest Border)
        { x = 0.3498, y = 0.1642 },              -- 19 (North Border)

        -- Northeast (Ebonheart Pact)
        { x = 0.8449, y = 0.1667 },              -- 09 (Behind Scroll Gates)
        { x = 0.7117, y = 0.1436 },              -- 10 (North Border)
        { x = 0.7766, y = 0.2782 },              -- 11 (Northeast Border)
    }
}

--[[ --all possible locations
    local pinData = {
    ["cyrodiil/ava_whole"] = {                   -- +
        { x = 0.5312, y = 0.8761 },              -- 01
        { x = 0.3043, y = 0.5361 },              -- 02
        { x = 0.3408, y = 0.7092 },              -- 03
        { x = 0.4088, y = 0.6367 },              -- 04
        { x = 0.4847, y = 0.5467 },              -- 05
        { x = 0.5263, y = 0.6195 },              -- 06
        { x = 0.4840, y = 0.7919 },              -- 07
        { x = 0.6415, y = 0.7695 },              -- 08
        { x = 0.8449, y = 0.1667 },              -- 09
        { x = 0.7117, y = 0.1436 },              -- 10
        { x = 0.7766, y = 0.2782 },              -- 11
        { x = 0.6317, y = 0.3021 },              -- 12
        { x = 0.5956, y = 0.3822 },              -- 13
        { x = 0.7112, y = 0.3940 },              -- 14
        { x = 0.7530, y = 0.4869 },              -- 15
        { x = 0.6859, y = 0.5330 },              -- 16
        { x = 0.1086, y = 0.2312 },              -- 17
        { x = 0.2091, y = 0.2246 },              -- 18
        { x = 0.3498, y = 0.1642 },              -- 19
        { x = 0.3476, y = 0.2405 },              -- 20
        { x = 0.3021, y = 0.3517 },              -- 21
        { x = 0.3924, y = 0.3613 },              -- 22
        { x = 0.4831, y = 0.2206 },              -- 23
        { x = 0.1999, y = 0.3726 },              -- 24
    }
}
]]
    appStart.LMP:AddPinType(appStart.hammerPinsName, function( pinManager )
        local mapName = appStart.LMP:GetZoneAndSubzone( true )
        local pins    = pinData[mapName]

        if pins then
            for _, pinInfo in ipairs( pins ) do
                appStart.LMP:CreatePin(appStart.hammerPinsName, pinInfo, pinInfo.x, pinInfo.y )
            end
        end
    end, nil, layout, tooltip )
end

--hide or show map pins
function functions.showPins()
    appStart.LMP:Enable(appStart.wellPinsName)
    appStart.LMP:SetEnabled(appStart.wellPinsName, true)
end
function functions.hidePins()
    appStart.LMP:Disable(appStart.wellPinsName)
    appStart.LMP:SetEnabled(appStart.wellPinsName, false)
end

--hide or show volendrung map pins
function functions.showPinsHammer()
    appStart.LMP:Enable(appStart.hammerPinsName)
    appStart.LMP:SetEnabled(appStart.hammerPinsName, true)
end
function functions.hidePinsHammer()
    appStart.LMP:Disable(appStart.hammerPinsName)
    appStart.LMP:SetEnabled(appStart.hammerPinsName, false)
end

--handle UI opened
function functions.onMenuOpened()
    appStart.isMenuOpen = true
    if appStart.savedVariables.alertStatusEnabled then
        cyroText:SetHidden(true)
    end
    if appStart.savedVariables.combatState then
        combatStateText:SetHidden(true)
    end
    if appStart.savedVariables.showVampStage then
        vampText:SetHidden(true)
    end
end

--handle UI closed
function functions.onMenuClosed()
    appStart.isMenuOpen = false
    if appStart.savedVariables.alertStatusEnabled then
        cyroText:SetHidden(false)
    end
    if appStart.savedVariables.combatState then
        combatStateText:SetHidden(false)
    end
    if appStart.savedVariables.showVampStage then
        vampText:SetHidden(false)
    end
end

--handle UI being opened
function functions.onSceneStateChange(scene, oldState, newState)

    local sceneName = SCENE_MANAGER:GetCurrentScene():GetName()

    if sceneName == "hud" then
        if  newState == SCENE_HIDING then functions.onMenuOpened()
        elseif  newState == SCENE_HIDDEN then functions.onMenuClosed()
        end
    end
end

--create options table
function functions.createOptions()

    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "Cyrodiil Alerts",
        displayName = "Cyrodiil Alerts",
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
            name = "Cyrodiil Map Alerts",
            tooltip = "Enable takeover alerts in Cyrodiil.",
            getFunc = function()
                return appStart.savedVariables.alertsEnabled
            end,
            setFunc = function(value)
                appStart.savedVariables.alertsEnabled = value
                if not value then
                    functions.stopAll()
                else
                    functions.startAll()
                end
            end,
            default = appStart.defaults.alertsEnabled,
        },
        {
            type = "checkbox",
            name = "Track Corrosive",
            tooltip = "Get alerts when someone is using corrosive armour near you.",
            getFunc = function()
                return appStart.savedVariables.trackCorrosive
            end,
            setFunc = function(value)
                appStart.savedVariables.trackCorrosive = value
                if not value then
                    functions.stopCorrosive()
                else
                    functions.startCorrosive()
                end
            end,
            default = appStart.defaults.trackCorrosive,
        },
        {
            type = "checkbox",
            name = "Track Onslaught",
            tooltip = "Get alerts when someone is using onslaught near you.",
            getFunc = function()
                return appStart.savedVariables.trackOnslaught
            end,
            setFunc = function(value)
                appStart.savedVariables.trackOnslaught = value
                if not value then
                    functions.stopOnslaught()
                else
                    functions.startOnslaught()
                end
            end,
            default = appStart.defaults.trackOnslaught,
        },
        {
            type = "checkbox",
            name = "Track Vampire Stage",
            tooltip = "Get an on screen alert and a text chat message when your vampire stage changes.",
            getFunc = function()
                return appStart.savedVariables.trackVampireStage
            end,
            setFunc = function(value)
                appStart.savedVariables.trackVampireStage = value
                if not value then
                    functions.stopVamp()
                else
                    functions.startVamp()
                end
            end,
            default = appStart.defaults.trackVampireStage,
        },
        {
            type = "checkbox",
            name = "Show Alerts Status",
            tooltip = "Shows if takeover alerts in Cyrodiil are enabled.",
            getFunc = function()
                return appStart.savedVariables.alertStatusEnabled
            end,
            setFunc = function(value)
                appStart.savedVariables.alertStatusEnabled = value
                if not value then
                    functions.hideAlertText()
                else
                    functions.showAlertText()
                end
            end,
            default = appStart.defaults.alertStatusEnabled,
        },
        {
            type = "checkbox",
            name = "Show Combat State",
            tooltip = "Shows a simple In Combat or Not in Combat text.",
            getFunc = function()
                return appStart.savedVariables.combatState
            end,
            setFunc = function(value)
                appStart.savedVariables.combatState = value
                if not value then
                    functions.stopCombat()
                else
                    functions.startCombat()
                end
            end,
            default = appStart.defaults.combatState,
        },
        {
            type = "checkbox",
            name = "Show Vampire Stage",
            tooltip = "Shows Vampire Stage.\nIf tracking vampire stage is enabled you will still receive notifications when your stage changes if you hide this text.",
            getFunc = function()
                return appStart.savedVariables.showVampStage
            end,
            setFunc = function(value)
                appStart.savedVariables.showVampStage = value
                if not value then
                    functions.hideVamp()
                else
                    functions.showVamp()
                end
            end,
            default = appStart.defaults.showVampStage,
        },
        {
            type = "checkbox",
            name = "Show Ayleid Wells",
            tooltip = "Shows all locations on the Cyrodiil map where you can find Ayleid Wells. All locations will have a (!) symbol.",
            getFunc = function()
                return appStart.savedVariables.showWellMapPins
            end,
            setFunc = function(value)
                appStart.savedVariables.showWellMapPins = value
                if not value then
                    functions.hidePins()
                else
                    functions.showPins()
                end
            end,
            default = appStart.defaults.showWellMapPins,
        },
        {
            type = "checkbox",
            name = "Show Volendrung Spawns",
            tooltip = "Shows possible Volendrung spawn locations on the Cyrodiil map. All locations will have a (H) symbol.",
            getFunc = function()
                return appStart.savedVariables.showHammerMapPins
            end,
            setFunc = function(value)
                appStart.savedVariables.showHammerMapPins = value
                if not value then
                    functions.hidePinsHammer()
                else
                    functions.showPinsHammer()
                end
            end,
            default = appStart.defaults.showHammerMapPins,
        },
        {
            type = "slider",
            name = "Text x Position",
            tooltip = "Adjust the left and right position of the on screen text.",
            min = 0, max = 2200, step = 10,
            getFunc = function()
                return appStart.savedVariables.xAxisText
            end,
            setFunc = function(value)
                appStart.savedVariables.xAxisText = value
                functions.setAnchor(appStart.savedVariables.xAxisText, appStart.savedVariables.yAxisText)
                corrosiveTextLabel:SetHidden(true)
            end,
            default = appStart.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Text y Position",
            tooltip = "Adjust the up and down position of the on screen text.",
            min = 0, max = 1200, step = 10,
            getFunc = function()
                return appStart.savedVariables.yAxisText
            end,
            setFunc = function(value)
                appStart.savedVariables.yAxisText = value
                functions.setAnchor(appStart.savedVariables.xAxisText, appStart.savedVariables.yAxisText)
            end,
            default = appStart.defaults.yAxisText,
        },
        {
            type = "slider",
            name = "Corrosive Alert x Position",
            tooltip = "Adjust the left and right position of the corrosive armour alert text.",
            min = 0, max = 2200, step = 10,
            getFunc = function()
                return appStart.savedVariables.xAxisTextCorro
            end,
            setFunc = function(value)
                appStart.savedVariables.xAxisTextCorro = value
                functions.setAnchorCorro(appStart.savedVariables.xAxisTextCorro, appStart.savedVariables.yAxisTextCorro)
                functions.showCorrosiveSet()
            end,
            default = appStart.defaults.xAxisTextCorro,
        },
        {
            type = "slider",
            name = "Corrosive Alert y Position",
            tooltip = "Adjust the up and down position of the corrosive armour alert text.",
            min = 0, max = 1200, step = 10,
            getFunc = function()
                return appStart.savedVariables.yAxisTextCorro
            end,
            setFunc = function(value)
                appStart.savedVariables.yAxisTextCorro = value
                functions.setAnchorCorro(appStart.savedVariables.xAxisTextCorro, appStart.savedVariables.yAxisTextCorro)
                functions.showCorrosiveSet()
            end,
            default = appStart.defaults.yAxisTextCorro,
        },
        {
            type = "slider",
            name = "Onslaught Alert x Position",
            tooltip = "Adjust the left and right position of the onslaught user alert text.",
            min = 0, max = 2200, step = 10,
            getFunc = function()
                return appStart.savedVariables.xAxisTextOnslaught
            end,
            setFunc = function(value)
                appStart.savedVariables.xAxisTextOnslaught = value
                functions.setAnchorOnslaught(appStart.savedVariables.xAxisTextOnslaught, appStart.savedVariables.yAxisTextOnslaught)
                functions.showOnslaughtSet()
            end,
            default = appStart.defaults.xAxisTextOnslaught,
        },
        {
            type = "slider",
            name = "Onslaught Alert y Position",
            tooltip = "Adjust the up and down position of the onslaught user alert text.",
            min = 0, max = 1200, step = 10,
            getFunc = function()
                return appStart.savedVariables.yAxisTextOnslaught
            end,
            setFunc = function(value)
                appStart.savedVariables.yAxisTextOnslaught = value
                functions.setAnchorOnslaught(appStart.savedVariables.xAxisTextOnslaught, appStart.savedVariables.yAxisTextOnslaught)
                functions.showOnslaughtSet()
            end,
            default = appStart.defaults.yAxisTextOnslaught,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("cyrodiilAlertsOptions", panelData)
    LAM:RegisterOptionControls("cyrodiilAlertsOptions", optionsData)

end

