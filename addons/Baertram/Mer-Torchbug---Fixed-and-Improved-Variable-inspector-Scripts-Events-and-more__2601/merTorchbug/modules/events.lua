local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

--Event tracking code was spyed and copied from the addon Zgoo! All credits go to the authors.
--Authors: Errc, SinusPi, merlight, Rhyono

------------------------------------------------------------------------------------------------------------------------
--Local helper pointers
local type = type
local select = select
local strfind = string.find
local tinsert = table.insert
local tremove = table.remove

local types = tbug.types
local stringType = types.string
local numberType = types.number
local functionType = types.func
local tableType = types.table
local userDataType = types.userdata
local structType = types.struct


local eventsInspectorControl
local globalInspector
local getGlobalInspector

local throttledCall = tbug.throttledCall
local tbug_slashCommandWrapper = tbug.slashCommandWrapper

------------------------------------------------------------------------------------------------------------------------
local tbEvents = {}
tbug.Events = tbEvents

------------------------------------------------------------------------------------------------------------------------
--The possible events of the game
tbEvents.eventList = {}
local lookupEventName = tbug.Events.eventList
--Lookup table with key&value reversed
--tbEvents.eventListLookup = {}
--local lookupEvent = tbug.Events.eventListLookup

local realESOEventNames = tbug.realESOEventNames
local blacklistedEventIds = tbug.blacklistedEventIds
--local eventParamFieldsById = tbug.eventParamFieldsById
local eventParamFieldsByName = tbug.eventParamFieldsByName

------------------------------------------------------------------------------------------------------------------------
--The events currently tracked/fired list
tbEvents.eventsTable = {}
tbEvents.eventsTableInternal = {}
tbEvents.eventsTableIncluded = {}
tbEvents.eventsTableExcluded = {}

tbEvents.IsEventTracking = false
tbEvents.AreAllEventsRegistered = false

------------------------------------------------------------------------------------------------------------------------
--Local helper functions
local l_globalprefixes = function(prefix)
	local l_safeglobalnext = function(tab,index)
		for k, v in zo_insecureNext, tab, index do
			if type(k) == stringType and strfind(k, prefix, 1, true) == 1 then
				return k, v
			end
		end
	end
	return l_safeglobalnext,_G,nil
end

--Add the possible events of the game (from _G table) to the eventsList
for k,v in l_globalprefixes("EVENT_") do
	if not blacklistedEventIds[v] and type(v)==numberType then
        --Lookup the real eventname
        local eventName = realESOEventNames[v] or k
        lookupEventName[v]=eventName
	end
end
setmetatable(tbug.Events.eventList,{__index = "-NO EVENT-"})

lookupEventName = tbug.Events.eventList

--Build the reversed lookup table
--[[
for k,v in pairs(lookupEventName) do
    lookupEvent[v]=k
end
]]

------------------------------------------------------------------------------------------------------------------------

local function getEventsTrackerInspectorControl()
    if eventsInspectorControl ~= nil then return eventsInspectorControl end
    --Start the event tracking by registering all events
    globalInspector = globalInspector or tbug.getGlobalInspector()
    if not globalInspector then return end
    eventsInspectorControl = globalInspector.panels and globalInspector.panels.events and globalInspector.panels.events.control
    return eventsInspectorControl
end
tbEvents.getEventsTrackerInspectorControl = getEventsTrackerInspectorControl

local function scrollScrollBarToIndex(list, index, animateInstantly)
    if not list then return end
    local onScrollCompleteCallback = function() end
    animateInstantly = animateInstantly or false
    ZO_ScrollList_ScrollDataIntoView(list, index, onScrollCompleteCallback, animateInstantly)
end

local function updateEventTrackerLines()
    --Is the events panel currently visible?
    local eventsPanel = globalInspector.panels.events
    local eventsPanelControl = eventsPanel.control
    if not eventsPanel or (eventsPanel and eventsPanelControl and eventsPanelControl:IsHidden() == true) then return end

    --Add the event to the masterlist of the outpt table
    -->Already called via eventsPanel:refreshData -> BuildMasterList
    --tbug.RefreshTrackedEventsList()

    --Update the visual ZO_ScrollList
    eventsPanel:refreshData()

    --Scroll to the bottom, if scrollbar is needed/shown
    local eventsListOutput = eventsPanel.list
    local numEventsInList = #eventsListOutput.data
    if numEventsInList <= 0 then return end

    local scrollbar = eventsListOutput.scrollbar
    if scrollbar and not scrollbar:IsHidden() then
        scrollScrollBarToIndex(eventsListOutput, numEventsInList, true)
    end

    --Add context menu to each row in the events table
end

------------------------------------------------------------------------------------------------------------------------
--The events tracker functions

--Add the event tracked to the list and show them at the output tab
function tbEvents.EventHandler(eventId, ...)
    if not tbEvents.IsEventTracking == true then return end

    local timeStampAdded = GetTimeStamp()
    local frameTime = GetFrameTimeMilliseconds()
    local eventTab = {}
    eventTab._timeStamp     = timeStampAdded
    eventTab._frameTime     = frameTime
    eventTab._eventName     = lookupEventName[eventId] or "? UNKNOWN EVENT ?"
    eventTab._eventId       = eventId

    -- The wiki parameter list omits the callback's first argument. That argument is the event id
    -- and is already stored as _eventId. select keeps fields that follow a nil hole.
    -- Some callbacks pass that event id again as the first vararg. When they do, keep it as eventId
    -- and start the documented names on the next argument. A first vararg that is not the event id
    -- is a real payload field (guildId 266193 is not event id 131877).
    -- The live client name is authoritative. EVENT_IDS numbers drift when new events are inserted.
    local eventParamFields = tbEvents.GetEventParamFields(eventId, eventTab._eventName)

    local eventParamCount = select("#", ...)
    local firstEventParamValue = eventParamCount > 0 and select(1, ...) or nil
    local eventParamIndexOffset = (firstEventParamValue == eventId) and 1 or 0

    for paramIndex = 1, eventParamCount do
        local eventParamValue = select(paramIndex, ...)
        if eventParamValue ~= nil then
            local eventParamKey
            if paramIndex == 1 and eventParamIndexOffset == 1 then
                eventParamKey = "eventId"
            else
                local documentedParamIndex = paramIndex - eventParamIndexOffset
                local eventParamField = eventParamFields and eventParamFields[documentedParamIndex]
                eventParamKey = (eventParamField and eventParamField[1]) or ("param" .. tostring(paramIndex))
            end
            eventTab[eventParamKey] = eventParamValue
        end
    end

	local tabPosAdded = tinsert(tbEvents.eventsTableInternal, eventTab)

	--Add the added line to the output list as well, if the list is currently visible!
    throttledCall("UpdateTBUGEventsList", 100, updateEventTrackerLines)
end
local tbEvents_EventHandler = tbEvents.EventHandler

function tbEvents.GetEventParamFields(eventId, eventName)
    local eventParamFields = eventParamFieldsByName and eventName and eventParamFieldsByName[eventName]
    --[[
    if eventParamFields == nil and eventParamFieldsById ~= nil then
        eventParamFields = eventParamFieldsById[eventId]
    end
    ]]
    return eventParamFields
end

function tbug.UpdateEventsTrackingButton(selfVar)
    getGlobalInspector = getGlobalInspector or tbug.getGlobalInspector
    --todo 20250110 remove debug data
    if tbug.doDebug then
        tbug._debugUpdateEventsTrackingButton = {
            selfVar = selfVar,
            globalInspector = getGlobalInspector(),
        }
    end

    selfVar = selfVar or getGlobalInspector()
    local eventsButton = (selfVar and selfVar.eventsButton) or nil
    if eventsButton == nil then return end

    if tbEvents.IsEventTracking == true then
        eventsButton.toggleState = true
        eventsButton:fitText("E", 12)
        eventsButton:setMouseOverBackgroundColor(0.8, 0.0, 0, 0.4)
        eventsButton.tooltipText = "Event tracking is |c00FF00Enabled|r.\nClick to disable EVENT tracking"
    else
        eventsButton.toggleState = false
        eventsButton:fitText("e", 12)
        eventsButton:setMouseOverBackgroundColor(0, 0.8, 0, 1)
        eventsButton.tooltipText = "Event tracking is |cFF0000Disabled|r.\nClick to enable EVENT tracking"
    end
end
local UpdateEventsTrackingButton = tbug.UpdateEventsTrackingButton

--Fill the masterlist of the events output ZO_SortFilterList with the tracked events data rows
function tbug.RefreshTrackedEventsList()
    tbEvents.eventsTable = {}
    local intEventTable = tbEvents.eventsTableInternal
    if intEventTable == nil or #intEventTable == 0 then return end

    for numEventAdded, eventDataTable in ipairs(intEventTable) do
        tbEvents.eventsTable[numEventAdded] = eventDataTable
    end
end
--local RefreshTrackedEventsList = tbug.RefreshTrackedEventsList

function tbEvents.RegisterAllEvents(inspectorControl, override)
    if not inspectorControl then return end
    override = override or false
    --Event tracking is enabled?
    if not override == true and not tbEvents.IsEventTracking then return end
    --No need to register all events multiple times!
    if tbEvents.AreAllEventsRegistered == true then return end

    for id, _ in pairs(lookupEventName) do
        inspectorControl:RegisterForEvent(id, tbEvents_EventHandler)
    end
    tbEvents.AreAllEventsRegistered = true
end
local RegisterAllEvents = tbEvents.RegisterAllEvents

function tbEvents.UnRegisterAllEvents(inspectorControl, excludedEventsFromUnregisterTable, override)
    if not inspectorControl then return end
    override = override or false
    local keepEventsRegistered = (excludedEventsFromUnregisterTable ~= nil and type(excludedEventsFromUnregisterTable) == tableType) or false
    if not keepEventsRegistered then
        if not override == true and tbEvents.IsEventTracking == true then return end
        if not tbEvents.AreAllEventsRegistered then return end
        for id, _ in pairs(lookupEventName) do
            inspectorControl:UnregisterForEvent(id)
        end
        tbEvents.AreAllEventsRegistered = false
    else
        if not override == true and not tbEvents.IsEventTracking == true then return end
        for id, _ in pairs(lookupEventName) do
            inspectorControl:UnregisterForEvent(id)
        end
        for _, eventId in ipairs(excludedEventsFromUnregisterTable) do
            tbEvents.RegisterSingleEvent(inspectorControl, eventId)
        end
    end
end
local UnRegisterAllEvents = tbEvents.UnRegisterAllEvents

function tbEvents.UnRegisterSingleEvent(inspectorControl, eventId)
    if not inspectorControl then return end
    --Event tracking is not enabled?
    if not tbEvents.IsEventTracking == true then return end
    inspectorControl:UnregisterForEvent(eventId)
end
local UnRegisterSingleEvent = tbEvents.UnRegisterSingleEvent

function tbEvents.RegisterSingleEvent(inspectorControl, eventId)
    if not inspectorControl then return end
    --Event tracking is not enabled?
    if not tbEvents.IsEventTracking == true then return end
    inspectorControl:RegisterForEvent(eventId, tbEvents_EventHandler)
end
local RegisterSingleEvent = tbEvents.RegisterSingleEvent

function tbEvents.ReRegisterAllEvents(inspectorControl)
    if not inspectorControl then return end
    --Event tracking is not enabled?
    tbug.Events.eventsTableIncluded = {}
    tbug.Events.eventsTableExcluded = {}
    UnRegisterAllEvents(inspectorControl, nil, true)
    RegisterAllEvents(inspectorControl, true)
end

function tbug.StartEventTracking()
    --Start the event tracking by registering either all events, or if any are excluded/included respect those
    if tbEvents.IsEventTracking == true then return end
    tbEvents.IsEventTracking = true
    UpdateEventsTrackingButton(nil)

    eventsInspectorControl = eventsInspectorControl or getEventsTrackerInspectorControl()
    if not eventsInspectorControl then
        tbEvents.IsEventTracking = false
        return
    end
    --Any included "only" to show?
    if #tbEvents.eventsTableIncluded > 0 then
        UnRegisterAllEvents(eventsInspectorControl, nil)
        for _, eventId in ipairs(tbEvents.eventsTableIncluded) do
             RegisterSingleEvent(eventsInspectorControl, eventId)
        end

    --Any excluded to "not" show?
    elseif #tbEvents.eventsTableExcluded > 0 then
        RegisterAllEvents(eventsInspectorControl)
        for _, eventId in ipairs(tbEvents.eventsTableExcluded) do
             UnRegisterSingleEvent(eventsInspectorControl, eventId)
        end

    --Else: Register all events
    else
        RegisterAllEvents(eventsInspectorControl)
    end

    --Show the UI/activate the events tab
    tbug.slashCommandEvents()
end
local startEventTracking = tbug.StartEventTracking

function tbug.StopEventTracking()
    if not tbEvents.IsEventTracking == true then return false end
    tbEvents.IsEventTracking = false
    UpdateEventsTrackingButton(nil)

    eventsInspectorControl = eventsInspectorControl or getEventsTrackerInspectorControl()
    if not eventsInspectorControl then return end
    UnRegisterAllEvents(eventsInspectorControl)

    --if the events panel is shown update it one time to show the last incoming events properly
    if not eventsInspectorControl:IsHidden() then
        zo_callLater(function()
            updateEventTrackerLines()
        end, 1500)
    end

    return true
end
local stopEventTracking = tbug.StopEventTracking


--Saved tracked events to SavedVariables subtable savedEvents
local function addSavedEvents(doRestartEventsTracking)
    if tbEvents.IsEventTracking then return end
    local savedEvents = tbug.savedVars.savedEvents
    savedEvents = savedEvents or {}


    local intEventTable = tbEvents.eventsTableInternal
    if ZO_IsTableEmpty(intEventTable) then return end

    local newSavedEventsEntry = {
        _timeStamp = GetTimeStamp(),
        events = ZO_ShallowTableCopy(intEventTable),
    }
    local indexAdded = tinsert(savedEvents, newSavedEventsEntry)
    indexAdded = indexAdded or #savedEvents
    d("[TBUG]Saved the currently tracked #" .. tostring(#intEventTable)  .." events as index: " .. tostring(indexAdded))

    if not doRestartEventsTracking then return end
    startEventTracking()
end

function tbug.SaveEventsTracked()
    if stopEventTracking() == true then
        if not eventsInspectorControl:IsHidden() then
            --Wait 1,5s
            zo_callLater(function()
                addSavedEvents(true)
            end, 1501)
        else
            addSavedEvents(true)
        end
    else
        addSavedEvents(false)
    end
end

function tbug.DeleteEventsTracked(key)
    local savedEvents = tbug.savedVars.savedEvents
    if key == nil or savedEvents == nil or savedEvents[key] == nil then return end
    tremove(tbug.savedVars.savedEvents, key)
    d("[TBUG]Deleted saved events #" .. tostring(key))
end

function tbug.LoadEventsTracked(key, loadDetailsStr)
    local savedEvents = tbug.savedVars.savedEvents
    if key == nil or savedEvents == nil or savedEvents[key] == nil or savedEvents[key].events == nil then return end
    --Load the saved events and show them in an inspector UI, passing on data.specialMasterlistType to the BuildMasterList func of the panel (TableInspectorPanel)
    tbug_slashCommandWrapper("TBUG.savedVars.savedEvents["..tostring(key).."].events", nil, true, { specialMasterlistType = "EventsViewer", title = "Saved events: " .. tostring(loadDetailsStr) })
end


function tbug.SetAutomaticEventsTrackingFlag(value, doReloadUI, activateNextLogin, chatOutput, onlyFor1ReloadUI, allOff)
    doReloadUI = doReloadUI or false
    activateNextLogin = activateNextLogin or false
    chatOutput = chatOutput or false
    onlyFor1ReloadUI = onlyFor1ReloadUI or false
    allOff = allOff or false

    if value ~= nil and activateNextLogin == true then
        value = nil
    end

    if allOff == true then
        tbug.activateAutomaticEventTrackingOnNextLogin = false
        tbug.savedVars.enableEventTrackerAtNextLogin = nil
        tbug.savedVars.enableEventTrackerAtStartup = false
        tbug.savedVars.enableEventTrackerAtStartupOnlyOnce = nil
        if chatOutput == true then
            d("[TBUG]Automatic events: Off")
        end
        return
    end

    tbug.savedVars.enableEventTrackerAtStartup = value
    tbug.savedVars.enableEventTrackerAtStartupOnlyOnce = nil
    tbug.savedVars.enableEventTrackerAtNextLogin = nil
    if value ~= nil and value == true and not doReloadUI and not activateNextLogin then
        if true == onlyFor1ReloadUI then
            tbug.savedVars.enableEventTrackerAtStartupOnlyOnce = true
            if chatOutput == true then
                d("[TBUG]Automatic events at 1 next ReloadUI: On")
            end
        else
            if chatOutput == true then
                d("[TBUG]Automatic events at all ReloadUIs: On")
            end
        end
    end

    --Activate the automatic event tracking on next login?
    if activateNextLogin == true then
        tbug.activateAutomaticEventTrackingOnNextLogin = true
        if chatOutput == true then
            d("[TBUG]Automatic events at next login: On")
        end
    else
        tbug.activateAutomaticEventTrackingOnNextLogin = nil
    end

    --Reload the UI now?
    if doReloadUI == true then
        ReloadUI("ingame")
    end
end

--At startup of the addon EVENT_ADD_ON_LOADED: Automatically load the event tracking?
function tbug.AutomaticEventTrackingCheck()
    local doStartEventTrackingNow = false
    local sv = tbug.savedVars
    if sv.enableEventTrackerAtNextLogin == true then
        sv.enableEventTrackerAtNextLogin = nil
        sv.enableEventTrackerAtStartupOnlyOnce = nil
        sv.enableEventTrackerAtStartup = false
        doStartEventTrackingNow = true
    elseif sv.enableEventTrackerAtStartup == true then
        if sv.enableEventTrackerAtStartupOnlyOnce == true then
            sv.enableEventTrackerAtStartupOnlyOnce = nil
            sv.enableEventTrackerAtStartup = false
        end
        doStartEventTrackingNow = true
    end
    if doStartEventTrackingNow == true then
        startEventTracking()
    end
end
