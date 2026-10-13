if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

local EM = EVENT_MANAGER

------------------------------------------------------------------------------------------------------------------------
-- Map --
------------------------------------------------------------------------------------------------------------------------

local worldMap                          = ZO_WorldMap
local mapSceneKeyboard                  = WORLD_MAP_SCENE
local mapSceneGamepad                   = GAMEPAD_WORLD_MAP_SCENE
local mapZoneStoryFragmentKeyboard      = WORLD_MAP_ZONE_STORY_KEYBOARD_FRAGMENT
local mapZoneStoryFragmentGamepad       = WORLD_MAP_ZONE_STORY_GAMEPAD_FRAGMENT
local mapFilters                        = WORLD_MAP_FILTERS
local mapFiltersFragment                = WORLD_MAP_KEY_FILTERS_FRAGMENT
local mapSceneChangeCallBackRegistered = false

--Callback function for event mount state changed
function FCOChangeStuff.OnMountStateChanged(eventCode, isMounted)
    if not FCOChangeStuff.settingsVars.settings.reOpenMapOnMounting then return false end
    --Are we mounted?
    if isMounted then
        --If the WorldMap is shown, it will be closed. Reopen it now
        if FCOChangeStuff.worldMapShown then
            FCOChangeStuff.worldMapShown = false

            zo_callLater(function()
                if ZO_WorldMap_ShowWorldMap then ZO_WorldMap_ShowWorldMap() end
            end, 50)
        end
    else
        FCOChangeStuff.worldMapShown = false
    end
end

--======== WORLD MAP FILTERS ====================================================
function FCOChangeStuff.SetAllWorldMapFilters(state)
    if state == nil then return false end
    --Is the world map shown?
    if worldMap:IsHidden() then return false end
--d("[FCOCS]SetAllWorldMapFilters - state: " .. tostring(state))
--[[
    local worldMapfilterContainerPVE = ZO_WorldMapFiltersPvEContainer
    if worldMapfilterContainerPVE ~= nil and not worldMapfilterContainerPVE:IsHidden() then
        --Get the 1st child of the scroll area
        local worldMapfilterCheckboxes = worldMapfilterContainerPVE.scroll:GetChild(1)
        if worldMapfilterCheckboxes ~= nil then
            local numChildren = worldMapfilterCheckboxes:GetNumChildren()
            if numChildren > 0 then
                for checkBoxNr=1, numChildren, 1 do
                    local checkBoxControl = worldMapfilterCheckboxes:GetChild(checkBoxNr)
                    if checkBoxControl ~= nil then
                        --Get the checkbox state
                        local cbState = checkBoxControl:GetState() -- 1 enabled, 0 disabled
                        if state ~= cbState then
                            --checkBoxControl:SetState(state) -- Changing the state does nothing, we need to "simulate the click" on it
                            local cbOnClickedHandler = checkBoxControl:GetHandler("OnClicked")
                            if cbOnClickedHandler ~= nil and type(cbOnClickedHandler) == "function" then
                                --Simulate the OnClick handler on the checkbox
                                cbOnClickedHandler(checkBoxControl)
                            end
                        end
                    end
                end
            end
        end
    end
]]
    --More dynamic way to get the worldmap filters of each map types -> Using the current one (AvA, PvE, Battleground, ...)
    if mapFilters ~= nil then
        local currentWMFpanel = mapFilters.currentPanel
        if currentWMFpanel ~= nil then
            local cbPool = currentWMFpanel.checkBoxPool.m_Active
            if cbPool ~= nil then
                local numCBs = #cbPool or 1
                for checkBoxNr=1, numCBs, 1 do
                    local checkBoxControl = cbPool[checkBoxNr]
                    if checkBoxControl ~= nil then
                        --Get the checkbox state
                        local cbState = checkBoxControl:GetState() -- 1 enabled, 0 disabled
                        if state ~= cbState then
                            --checkBoxControl:SetState(state) -- Changing the state does nothing, we need to "simulate the click" on it
                            local cbOnClickedHandler = checkBoxControl:GetHandler("OnClicked")
                            if cbOnClickedHandler ~= nil and type(cbOnClickedHandler) == "function" then
                                --Simulate the OnClick handler on the checkbox
                                cbOnClickedHandler(checkBoxControl)
                            end
                        end
                    end
                end
            end
        end
    end

end

local mapFiltersFragmentRegistered = false
function FCOChangeStuff.WorldMapFilterButtons()
    if not mapFiltersFragmentRegistered then
        --Create 2 buttons as the world map's filters panel opens the first time
        --and let the buttons enable/disable all map filter checkboxes for you
        --FCOChangeStuff.SetAllWorldMapFilters(state) State 1=Enabled, 0=Disabled

        --AddButton(parent, name, callbackFunction, onMouseUpCallbackFunction, onMouseUpCallbackFunctionMouseButton,
        --          text, font, tooltipText, tooltipAlign, textureNormal, textureMouseOver, textureClicked, width, height,
        --          left, top, alignMain, alignBackup, alignControl, hideButton)
        local perfectPixelAddonIsLoaded = FCOChangeStuff.otherAddons.PerfectPixel or false
        local parent
        local left      = 0
        local left2     = 0
        local top       = 0
        local alignMain = RIGHT
        local alignBackup = RIGHT
        if not perfectPixelAddonIsLoaded then
            parent      = ZO_WorldMapInfoMenuBarLabel
            left        = 60
            left2       = 85
            top         = 0
            alignMain   = RIGHT
            alignBackup = RIGHT
        else
            parent      = ZO_WorldMapFilters
            left        = -25
            left2       = 25
            top         = -18
            alignMain   = TOP
            alignBackup = TOP
        end
        local name
        local callbackFunction
        local onMouseUpCallbackFunction
        local onMouseUpCallbackFunctionMouseButton = MOUSE_BUTTON_INDEX_RIGHT
        local text
        local font
        local tooltipText
        local tooltipAlign = RIGHT

        --[[
            normal="EsoUI/Art/Buttons/checkbox_unchecked.dds"
            pressed="EsoUI/Art/Buttons/checkbox_checked.dds"
            mouseOver="EsoUI/Art/Buttons/checkbox_mouseover.dds"
            pressedMouseOver="EsoUI/Art/Buttons/checkbox_mouseover.dds"
            disabled="EsoUI/Art/Buttons/checkbox_disabled.dds"
            disabledPressed="EsoUI/Art/Buttons/checkbox_checked_disabled.dds
        ]]

        local textureNormal = "/EsoUI/Art/Buttons/checkbox_checked.dds"
        local textureMouseOver = "/EsoUI/Art/Buttons/checkbox_checked.dds"
        local textureClicked = textureMouseOver
        local width     = 16
        local height    = 16
        local alignControl = parent
        local hideButton = true

    --This code needs to be run on a change of the world map info menu bar (buttons clicked to
    --show map filters, houses, etc.)
    --Hide buttons ZO_WorldMapFilterPanel_Sharedagain if the worldmap filters panel gets hidden
        mapFiltersFragment:RegisterCallback("StateChange",  function(oldState, newState)
            if newState == SCENE_FRAGMENT_SHOWN then
                local showWorldMapFilterAllButtons = FCOChangeStuff.settingsVars.settings.showEnDisableAllFilterButtons
                --d("WORLD_MAP_KEY_FILTERS_FRAGMENT - Shown: " .. tostring(showWorldMapFilterAllButtons))
                if showWorldMapFilterAllButtons then
                    --Anchor the buttons to the headline "Filters" right side
                    --The new button controls
                    --Enable button - Create if not existing
                    if FCOChangeStuff.wolrdMapFilterEnableAllButton == nil then
                        --Change some variables to differentiate the buttons
                        name = "FCOChangeStuff_WoldMapFilter_ButtonEnableAll"
                        tooltipText = "Enable all filter"
                        callbackFunction = function()
                            FCOChangeStuff.SetAllWorldMapFilters(1)
                        end
                        --Create the enable all button
                        local btnWMFenableAll = FCOChangeStuff.CreateButton(parent, name, callbackFunction, onMouseUpCallbackFunction, onMouseUpCallbackFunctionMouseButton, text, font, tooltipText, tooltipAlign, textureNormal, textureMouseOver, textureClicked, width, height, left, top, alignMain, alignBackup, alignControl, hideButton)
                        FCOChangeStuff.wolrdMapFilterEnableAllButton = btnWMFenableAll
                    end
                    --Disable button - Create if not existing
                    if FCOChangeStuff.wolrdMapFilterDisableAllButton == nil then
                        --Change some variables to differentiate the buttons
                        name = "FCOChangeStuff_WoldMapFilter_ButtonDisableAll"
                        tooltipText = "Disable all filter"
                        callbackFunction = function()
                            FCOChangeStuff.SetAllWorldMapFilters(0)
                        end
                        textureNormal = "/EsoUI/Art/Buttons/checkbox_unchecked.dds"
                        textureMouseOver = "/EsoUI/Art/Buttons/checkbox_unchecked.dds"
                        textureClicked = textureMouseOver
                        --Create the disable all button
                        local btnWMFdisableAll = FCOChangeStuff.CreateButton(parent, name, callbackFunction, onMouseUpCallbackFunction, onMouseUpCallbackFunctionMouseButton, text, font, tooltipText, tooltipAlign, textureNormal, textureMouseOver, textureClicked, width, height, left2, top, alignMain, alignBackup, alignControl, hideButton)
                        FCOChangeStuff.wolrdMapFilterDisableAllButton = btnWMFdisableAll
                    end
                end
                --Show the buttons now, if enabled in the settings
                local enableAllWMFbutton    = FCOChangeStuff.wolrdMapFilterEnableAllButton
                local disableAllWMFbutton   = FCOChangeStuff.wolrdMapFilterDisableAllButton
                if enableAllWMFbutton ~= nil then
                    enableAllWMFbutton:SetHidden(not showWorldMapFilterAllButtons)
                    enableAllWMFbutton:SetMouseEnabled(showWorldMapFilterAllButtons)
                end
                if disableAllWMFbutton ~= nil then
                    disableAllWMFbutton:SetHidden(not showWorldMapFilterAllButtons)
                    disableAllWMFbutton:SetMouseEnabled(showWorldMapFilterAllButtons)
                end

            elseif newState == SCENE_FRAGMENT_HIDING then
                --d("WORLD_MAP_KEY_FILTERS_FRAGMENT - Hiding")
                --Hide the buttons again
                local enableAllWMFbutton    = FCOChangeStuff.wolrdMapFilterEnableAllButton
                local disableAllWMFbutton   = FCOChangeStuff.wolrdMapFilterDisableAllButton
                if enableAllWMFbutton ~= nil then
                    enableAllWMFbutton:SetHidden(true)
                    enableAllWMFbutton:SetMouseEnabled(false)
                end
                if disableAllWMFbutton ~= nil then
                    disableAllWMFbutton:SetHidden(true)
                    disableAllWMFbutton:SetMouseEnabled(false)
                end
            end
        end)

        mapFiltersFragmentRegistered = true
    end
end

--Play an animation on the player pin: PingPong -> To easily see the arrow on the map
function FCOChangeStuff.playerPinPingPong(fromKeybind)
    local settings = FCOChangeStuff.settingsVars.settings
    if not settings.pingPongPlayerPinOnMapOpen then if not fromKeybind then return false end end
    local myPin = ZO_WorldMap_GetPinManager():GetPlayerPin():GetControl()
    if myPin then
        local scaling = settings.pingPongPlayerPinOnMapOpenScaling
        if MAP_MODE_VOTANS_MINIMAP ~= nil and ZO_WorldMap_GetMode() == MAP_MODE_VOTANS_MINIMAP then
            scaling=2
        end
        local animation, timeline = CreateSimpleAnimation(ANIMATION_SCALE, myPin, 150)
        animation:SetScaleValues(1, scaling)
        animation:SetDuration(150)
        timeline:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, 3)
        timeline:PlayFromStart()
    end
end

local isMapLocationVisibleHooked = false
function FCOChangeStuff.HideCityPOIs()
    if not FCOChangeStuff.settingsVars.settings.hidePOIsInCities then return end

    if isMapLocationVisibleHooked then return end
    ZO_PreHook("IsMapLocationVisible", function(locationIndex)
        if not FCOChangeStuff.settingsVars.settings.hidePOIsInCities then return false end
        if GetParentZoneId ~= nil then
            local zoneId, subZoneId
            zoneId = GetParentZoneId()
            if zoneId ~= nil then
                local zoneIndex = GetUnitZoneIndex("player")
                if zoneIndex ~= nil then
                    subZoneId = GetZoneId(zoneIndex)
                    if subZoneId ~= nil then
                        --d("HIDDEN: locationIndex: " ..tostring(locationIndex) .. ", name: " .. tostring(GetMapLocationTooltipHeader(locationIndex)))
                        return true
                    end
                end
            end
        end
        return false
    end)
    isMapLocationVisibleHooked = true
end

--======== WORLD MAP ============================================================
function FCOChangeStuff.mapStuff(type)
    type = type or "all"
    local settings = FCOChangeStuff.settingsVars.settings
    --Worldmap mount
    if type == "all" or type == "mount" or type == "hidezonestory" or type == "playerpinpingpong" then
        local function sceneCallBack(p_oldState, p_newState)
            if (p_oldState == SCENE_SHOWN and p_newState == SCENE_HIDING) then
                if settings.reOpenMapOnMounting then
                    if IsMounted() then
                        FCOChangeStuff.worldMapShown = true
                    end
                end
            elseif p_newState == SCENE_SHOWING then
                if settings.hideMapZoneStory then
                    if IsInGamepadPreferredMode() then
                        mapSceneKeyboard:RemoveFragment(mapZoneStoryFragmentGamepad)
                    else
                        mapSceneKeyboard:RemoveFragment(mapZoneStoryFragmentKeyboard)
                    end
                else
                    if IsInGamepadPreferredMode() then
                        mapSceneKeyboard:AddFragment(mapZoneStoryFragmentGamepad)
                    else
                        mapSceneKeyboard:AddFragment(mapZoneStoryFragmentKeyboard)
                    end
                end
            elseif p_newState == SCENE_SHOWN then
                if settings.pingPongPlayerPinOnMapOpen then
                    FCOChangeStuff.playerPinPingPong()
                end
            end
        end
        local function sceneFragmentCallBack(p_oldFragmentState, p_newFragmentState)
            if p_newFragmentState == SCENE_FRAGMENT_SHOWN then
                FCOChangeStuff.MapZoneStoryHide(true)
            end
        end
        if not mapSceneChangeCallBackRegistered then
            --Register a callback function for the wolrd map scene
            mapSceneKeyboard:RegisterCallback("StateChange", function(oldState, newState)
                sceneCallBack(oldState, newState)
            end)
            mapSceneGamepad:RegisterCallback("StateChange", function(oldState, newState)
                sceneCallBack(oldState, newState)
            end)
            --BeamMeUp fix: Worldmap zone guide
            local bmuGlobal
            if BMU ~= nil and BMU.toggleZoneGuide ~= nil then bmuGlobal = BMU end
            if bmuGlobal == nil and Teleporter ~= nil and Teleporter.toggleZoneGuide ~= nil then bmuGlobal = Teleporter end
            if bmuGlobal then
                ZO_PreHook(bmuGlobal, "toggleZoneGuide", function(doShow)
                    --If the FCOChangeStuff setting to hide the zoneGuide is enabled:
                    --Hide the zoneguide and do not show it again via BeamMeUp addon
                    --Except if the setting in FCOCS is enabeld to allow this
                    if doShow and settings.hideMapZoneStory then
                        if not settings.hideMapZoneStoryBeamMeUpAllowedToShow then
                            return true
                        end
                    end
                end)
            end
            mapSceneChangeCallBackRegistered = true
        end
        --Reopen the worldmap if it was open as you mounted is deactivated?
        if not settings.reOpenMapOnMounting then
            --Register callback function for event mount state changed
            EM:UnregisterForEvent(FCOChangeStuff.addonVars.addonName, EVENT_MOUNTED_STATE_CHANGED)
        else
            --Register callback function for event mount state changed
            EM:RegisterForEvent(FCOChangeStuff.addonVars.addonName, EVENT_MOUNTED_STATE_CHANGED, FCOChangeStuff.OnMountStateChanged)
        end
    end
    --World map filters
    if type == "all" or type == "filter" then
        --Add enable all/disbale all map filters button
        if settings.showEnDisableAllFilterButtons then
            FCOChangeStuff.WorldMapFilterButtons()
        end
    end
    --Remove POI icons in cities
    if type == "all" or type == "cityPOIs" then
        --Add enable all/disbale all map filters button
        FCOChangeStuff.HideCityPOIs()
    end
end
