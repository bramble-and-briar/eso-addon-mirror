local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local myNAME = TBUG.name

local EM = EVENT_MANAGER

local tos = tostring
local ton = tonumber
local strformat = string.format
local strfind = string.find
local strgmatch = string.gmatch
local strlower = string.lower
local strsub = string.sub
local strgsub = string.gsub
local strlen = string.len
local zo_ls = zo_loadstring
local tins = table.insert
local trem = table.remove
local tsort = table.sort
local tcon = table.concat
local zo_strf = zo_strformat
local zo_strspl = zo_strsplit
local rawget = rawget

local types = tbug.types
local stringType = types.string
local numberType = types.number
local functionType = types.func
local tableType = types.table
local userDataType = types.userdata
local structType = types.struct


local sessionStartTime = tbug.sessionStartTime
local ADDON_MANAGER

local addOns = {}
local scenes = {}
local fragments = {}
tbug.IsEventTracking = false

local tbug_inspectorScrollLists = tbug.inspectorScrollLists

local titlePatterns      =       tbug.titlePatterns
local tablePatternPrefix =   "^table: "
local titleTemplate      =       titlePatterns.normalTemplate
local titleMocTemplate =    titlePatterns.mouseOverTemplate
local titleMocTemplatePattern
local title2ChatCleanUpIndex =              titlePatterns.title2ChatCleanUpIndex
local title2ChatCleanUpChild =              titlePatterns.title2ChatCleanUpChild
local title2ChatCleanUpTableAndColor =      titlePatterns.title2ChatCleanUpTableAndColor
local specialInspectTabTitles  = tbug.specialInspectTabTitles
local tbugScriptViewerValueForNewWindow = tbug.ScriptsViewer._name

local specialLibraryGlobalVarNames = tbug.specialLibraryGlobalVarNames
local lookupTabLibrary = tbug.LookupTabs["library"]

local unitConstants = tbug.unitConstants
local unitPlayer = unitConstants.player
local serversShort = tbug.serversShort


local firstToUpper = tbug.firstToUpper
local startsWith = tbug.startsWith
local endsWith = tbug.endsWith

local classes = tbug.classes
local filterModes = tbug.filterModes
local panelNames = tbug.panelNames
local openNewWindowSlashCommands = tbug.openNewWindowSlashCommands

local customKeysForInspectorRows = tbug.customKeysForInspectorRows
local customKey__usedInScenes = customKeysForInspectorRows.usedInScenes

local scrollListFunctionsToHookAndHideControls = tbug.scrollListFunctionsToHookAndHideControls


local tbug_glookup = tbug.glookup
local tbug_getKeyOfObject = tbug.getKeyOfObject
local getControlName = tbug.getControlName
local isControl = tbug.isControl
local throttledCall = tbug.throttledCall
local tbug_SetTemplate = tbug.SetTemplate
--local tbug_getActiveTabPanel = tbug.GetActiveTabPanel

local specialMasterListType2InspectorClass = tbug.specialMasterListType2InspectorClass
local allowedSlashCommandsEventsParameters = tbug.allowedSlashCommandsEventsParameters
local tbug_SetAutomaticEventsTrackingFlag


local tbug_inspect
local objInsp
local globalInspector
local tbug_getGlobalInspector
local tbug_savedTable
local useForScript
local tbug_slashCommandWrapper

local function evalString(source, funcOnly)
    funcOnly = funcOnly or false
    -- first, try to compile it with "return " prefixed,
    -- this way we can evaluate things like "_G.tab[5]"
    local func, err = zo_ls("return " .. source)
--d("[tbug]evalString-source: " ..tos(source) .. ", funcOnly: " .. tos(funcOnly) .. ", func: " .. tos(func) .. ", err: " .. tos(err))
--[[
tbug._evalString = {
    source = source,
    funcOnly = funcOnly,
    func = func,
    err = err,
}
]]
    if not func then
        -- failed, try original source
        func, err = zo_ls(source, "<< " .. source .. " >>")
--d(">Failed, original source func: " .. tos(func) .. ", err: " .. tos(err))
        if not func then
            return func, err
        end
    end
    if funcOnly then
--d("<returning func, err")
        -- return the function
        return func, err
    else
--d("<returning pcall(func, tbug.env)")
        -- run compiled chunk in custom  (_G)
        return pcall(setfenv(func, tbug.env))
    end
end

local function compareBySubTablesKeyName(a,b)
    if a.name and b.name then return a.name < b.name
    elseif a.__name and b.__name then return a.__name < b.__name end
end

--[[
local function compareBySubTablesLoadOrderIndex(a,b)
    if a._loadOrderIndex and b._loadOrderIndex then return a._loadOrderIndex < b._loadOrderIndex end
end
]]

--Check if a key or value is already inside a table
--checkKeyOrValue - true: Check the key, false: Check the value
local function checkIfAlreadyInTable(table, key, value, checkKeyOrValue)
    if not table or checkKeyOrValue == nil then return false end
    if checkKeyOrValue == true then
        if not key then return false end
        if table[key] == nil then return true end
    else
        if not value then return false end
        for k, v in pairs(table) do
            if key ~= nil then
                if k == key then
                    if v == value then return true end
                end
            else
                if v == value then return true end
            end
        end
    end
    return false
end

local function clearDataForInspector()
    tbug.dataForInspector = nil
    tbug.doOpenNewInspector = nil
end

local function isPlayerInCombatDungeonRaidAvA()
    if IsUnitInCombat(unitPlayer) or IsUnitInDungeon(unitPlayer) or IsPlayerInRaid() or IsPlayerInRaidStagingArea() or IsPlayerInAvAWorld() then return true end
    return false
end

local function showDoesNotExistError(object, winTitle, tabTitle)
--d("[TBUG]showDoesNotExistError - object: " ..tostring(object) .. ", winTitle: " ..tostring(winTitle) ..", tabTitle: " .. tostring(tabTitle))
    local errText = "[TBUG]No inspector for \'%s\' (%q)"
    local title = (winTitle ~= nil and tos(winTitle)) or tos(tabTitle)
    df(errText, title, tos(object))
end

local function isPrivateOrProtectedFunction(object, funcName)
    --d("[tbug]isPrivateOrProtectedFunction - object: " .. tos(object) .. ", funcName: " ..tos(funcName))
    if object == nil then return false end
    if funcName == nil then
        local functionRef = object
        if type(object) ~= functionType then
            if object.funcName == nil or type(object.funcName) ~= functionType then
                return false
            else
                functionRef = object.funcName
            end
        end
        funcName = tbug_glookup(functionRef)
    else
        funcName = tbug.cleanKey(funcName)
    end
    --d(">funcName is now: " ..tos(funcName))
    if type(funcName) ~= stringType then return false end
    return IsPrivateFunction(funcName) or IsProtectedFunction(funcName)
end
tbug.isPrivateOrProtectedFunction = isPrivateOrProtectedFunction

local function showFunctionReturnValue(object, tabTitle, winTitle, objectParent)
    --local objectType = type(object)
    --local isPrivOrProtectedFunc = isPrivateOrProtectedFunction(((objectType == functionType or objectType == tableType) and object) or nil, tabTitle)
    local wasRunWithoutErrors, resultsOfFunc

    --if isPrivOrProtectedFunc == true then
--        wasRunWithoutErrors, resultsOfFunc = pcall(setfenv(object, tbug.env))
--    else
        wasRunWithoutErrors, resultsOfFunc = pcall(setfenv(object, tbug.env))
--    end

--d("[tbug]showFunctionReturnValue - isPrivOrProtectedFunc: " .. tos(isPrivOrProtectedFunc) .. ", wasRunWithoutErrors: " ..tos(wasRunWithoutErrors) .. ", resultsOfFunc: " .. tos(resultsOfFunc))
--tbug._debugResultsOfFunc = resultsOfFunc



    local title = (winTitle and tos(winTitle)) or tos(tabTitle) or ""
    title = (objectParent and objectParent ~= "" and objectParent .. "." or "") .. title

    if wasRunWithoutErrors then
        d(resultsOfFunc and "[TBUG]Results of function '" .. tos(title) .. "':" or "[TBUG]No results for function '" .. tos(title) .. "'")
    else
        d("[TBUG]<<<ERROR>>>Function '" .. tos(title) .. "' ended with errors:")
    end

    if resultsOfFunc then
        if type(resultsOfFunc) == tableType then
            for k, v in ipairs(resultsOfFunc) do
                d("[" .. tos(k) .. "] " .. v)
            end
        else
            d("[1] " .. tos(resultsOfFunc))
        end
    end
end

local function getSavedVariablesTableName(selfVar, isGlobalInspector, id)
    if not isGlobalInspector then
        if selfVar then
            tbug_getGlobalInspector = tbug_getGlobalInspector or tbug.getGlobalInspector
            globalInspector = globalInspector or tbug_getGlobalInspector()
            isGlobalInspector = (globalInspector ~= nil and globalInspector == selfVar and true) or false
        end
    end

    tbug_savedTable = tbug_savedTable or tbug.savedTable
    if not isGlobalInspector then
        if selfVar.isScriptsViewer then
            return tbug_savedTable("ScriptsViewer" .. id)
        else
            return tbug_savedTable("objectInspector" .. id)
        end
    else
        return tbug_savedTable("globalInspector1")
    end
end
tbug.GetSavedVariablesTableName = getSavedVariablesTableName



local function valueEdit_CancelThrottled(editBox, delay)
    if not editBox or not editBox.panel or not editBox.panel.valueEditCancel then return end
    delay = delay or 0
--d("[tbug]valueEdit_CancelThrottled-text: " .. tos(editBox:GetText()) .. ", delay: " ..tos(delay))
    throttledCall("merTorchbugPanelValueEditCancel", delay,
            editBox.panel.valueEditCancel, editBox.panel, editBox
    )
end
tbug.valueEdit_CancelThrottled = valueEdit_CancelThrottled


local function valueSlider_CancelThrottled(sliderCtrl, delay)
    local sliderPanel = sliderCtrl ~= nil and sliderCtrl.panel
    if not sliderPanel or not sliderPanel.valueSliderCancel or not sliderPanel.sliderCtrlActive then return end
    delay = delay or 0
--d("[tbug]valueSlider_CancelThrottled-value: " .. tos(sliderCtrl:GetValue()) .. ", delay: " ..tos(delay))
    throttledCall("merTorchbugPanelValueSliderCancel", delay,
            sliderPanel.valueSliderCancel, sliderPanel, sliderCtrl
    )
end
tbug.valueSlider_CancelThrottled = valueSlider_CancelThrottled


local function cleanTitle(titleText)
    --Remove leading [MOC_<numbers>] prefix
    --[[
    if strfind(titleText, titleMocTemplate) ~= nil then
        local mocEndPosInTitle = strfind(titleText, "]", 5, true)
        if mocEndPosInTitle ~= nil then
            titleText = string.sub(titleText, mocEndPosInTitle + 2) --+2 to skip ] and space afterwards
        end
    end
    ]]

    --Get each character in MOC template (stop at the % as this is the placeholder for the number)
    if titleMocTemplatePattern == nil then
        local charsInMOCTemplate = {}
        local lastCharacter = ""
        for i=1, string.len(titleMocTemplate), 1 do
            local character = string.char(string.byte(titleMocTemplate, i))
            if character ~= "%" then
                if lastCharacter ~= "%" then
                    charsInMOCTemplate[#charsInMOCTemplate + 1] = character
                else
                    --insert placeholder character ^, will be replaced with %d*
                    charsInMOCTemplate[#charsInMOCTemplate + 1] = "^"
                end
            end
            lastCharacter = character
        end
        if #charsInMOCTemplate > 0 then
            titleMocTemplatePattern = ""
            for _, character in ipairs(charsInMOCTemplate) do
                if character == "^" then
                    titleMocTemplatePattern = titleMocTemplatePattern .. "%d*"
                else
                    --is the character a normal a-zA-Z0-9?
                    local strRepChar = (strgsub(character, '%w', ''))
                    --Any non normal character left?
                    if strRepChar ~= "" then
                        titleMocTemplatePattern = titleMocTemplatePattern .. "%" .. character
                    else
                        titleMocTemplatePattern = titleMocTemplatePattern .. character
                    end
                    titleMocTemplatePattern = titleMocTemplatePattern .. "?"
                end
            end
            titleMocTemplatePattern = '^'..tos(titleMocTemplatePattern)..'%s?(.*)'
        end
    end

    if titleMocTemplatePattern ~= nil then
        --titleText = titleText:match('^%[?M?O?C?_?%d*%]?%s?(.*)')
        titleText = titleText:match(titleMocTemplatePattern)
    end
    --Remove any inheritance info of classes -> metaindices
    titleText = (strgsub(titleText, title2ChatCleanUpIndex, ''))
    --Remove »Child:
    titleText = (strgsub(titleText, title2ChatCleanUpChild, ''))
    --Remove suffix "colored table or userdata" like " <|c86bff9table: 0000020E4A8004F0|r|r>"
    return (strgsub(titleText, title2ChatCleanUpTableAndColor, ''))
end
tbug.CleanTitle = cleanTitle

--Parse the arguments string
local function parseSlashCommandArgumentsAndReturnTable(args, doLower)
    doLower = doLower or false
    local argsAsTable = {}
    if not args then return argsAsTable end
    args = zo_strtrim(args)
    --local searchResult = {} --old: searchResult = { string.match(args, "^(%S*)%s*(.-)$") }
    for param in strgmatch(args, "([^%s]+)%s*") do
        if param ~= nil and param ~= "" then
            argsAsTable[#argsAsTable+1] = (not doLower and param) or strlower(param)
        end
    end
    return argsAsTable
end
tbug.parseSlashCommandArgumentsAndReturnTable = parseSlashCommandArgumentsAndReturnTable

local function getSearchDataAndUpdateInspectorSearchEdit(searchData, inspector)
--d("[TB]getSearchDataAndUpdateInspectorSearchEdit")
    if type(searchData) == tableType and inspector ~= nil and inspector.updateFilterEdit ~= nil then
        local searchText = searchData.searchText
--d(">searchStr: " .. tos(searchText))
        if searchText ~= nil then
            inspector:updateFilterEdit(searchText, searchData.mode, searchData.delay)
        end
    end
end
tbug.getSearchDataAndUpdateInspectorSearchEdit = getSearchDataAndUpdateInspectorSearchEdit

local function buildSearchData(searchValues, delay)
    delay = delay or 10
    local searchText = ""
    local searchMode = 1 --String search

    if searchValues ~= nil then
        local searchOptions = parseSlashCommandArgumentsAndReturnTable(searchValues, false)
        if searchOptions == nil or searchOptions ~= nil and #searchOptions == 0 then return end
        --Check if the 1st param was a number -> and if it's a valid searchMode number: Use it.
        --Else: Use it as normal search string part
        searchMode = ton(searchOptions[1])
        --{ [1]="str", [2]="pat", [3]="val", [4]="con" }
        if searchMode ~= nil and type(searchMode) == numberType and filterModes[searchMode] ~= nil then
            searchText = tcon(searchOptions, " ", 2, #searchOptions)
        else
            searchText = tcon(searchOptions, " ", 1, #searchOptions)
        end
    end

    return {
        searchText =    searchText,
        mode =          searchMode,
        delay =         delay
    }
end
tbug.buildSearchData = buildSearchData



local function closeAllTabs(inspectorObject)
    if inspectorObject == nil or inspectorObject.tabs == nil or ZO_IsTableEmpty(inspectorObject.tabs) then return end
    inspectorObject:removeAllTabs()
end
tbug.closeAllTabs = closeAllTabs


local function hasMember(tab, keyPattern, valueType, maxDepth)
    if type(tab) == tableType and maxDepth > 0 then
        for k, v in zo_insecureNext, tab do
            if type(v) == valueType and type(k) == stringType and strfind(k, keyPattern) then
                return true
            elseif hasMember(v, keyPattern, valueType, maxDepth - 1) then
                return true
            end
        end
    end
    return false
end
tbug.hasMember = hasMember


local preventEndlessLoop = false
local function inspectResults(specialInspectionString, searchData, data, source, status, ...) --status is the return value of evalString, ... contains the compiled result of pcall (evalString)
    local doDebug = tbug.doDebug
    if doDebug then
        TBUG._status = status
        TBUG._evalData = {...}
    end

    local noDirectExecute = (data ~= nil and data.noDirectExecute) or false --Do not execute the code/script but just show it in the ScriptsViewer editbox? In this case evalString was not called and statzs is nil, ... is nil too!

    local recycle
    local doOpenNewInspector = tbug.doOpenNewInspector
    if doOpenNewInspector == false then
        recycle = true
    elseif doOpenNewInspector == true then
        recycle = false
    elseif doOpenNewInspector == nil then
        recycle = not IsShiftKeyDown()
    end
    local isMOCFromGlobalEventMouseUp = (specialInspectionString and specialInspectionString == "MOC_EVENT_GLOBAL_MOUSE_UP") or false
    if isMOCFromGlobalEventMouseUp == true then recycle = true end
    local isMOC = (specialInspectionString ~= nil and (isMOCFromGlobalEventMouseUp == true or specialInspectionString == "MOC")) or false
    if doDebug then
        d("[TBUG]inspectResults - recycle: " ..tos(recycle) .. "; tbug.doOpenNewInspector: " ..tos(tbug.doOpenNewInspector) .. ", isMOCFromGlobalEventMouseUp: " .. tos(isMOCFromGlobalEventMouseUp) .. ", isMOC: " .. tos(isMOC))
    end
    tbug.doOpenNewInspector = nil

    --Prevent SHIFT key handling at EVENT_GLOBAL_MOUSE_UP, as the shift key always needs to be pressed there!
    if doDebug then d("tb: inspectResults - specialInspectionString: " ..tos(specialInspectionString) .. ", source: " ..tos(source) .. ", status: " ..tos(status) .. ", recycle: " ..tos(recycle) .. ", isMOC: " ..tos(isMOC) .. ", searchData: " ..tos(searchData)) end
    if not status then
        local foundNotAllowedCharacters = zo_plainstrfind(source, "=")
        if doDebug then d("[TB]inspectResults - execution of '" .. tos(source) .."' resulted in an error. foundNotAllowedCharacters: " ..tos(foundNotAllowedCharacters)) end
        --Passed in params 2ff are maybe a search string and not something to execute?
        if not preventEndlessLoop and source ~= nil and type(source) == stringType
                and not foundNotAllowedCharacters --no = (assignment) in the string
                and (searchData == nil or (searchData ~= nil and searchData.searchText == "")) then
            if doDebug then d(">testing other args") end
            --Build the searchData from the passed in "source" (args)
            local argsOptions = parseSlashCommandArgumentsAndReturnTable(source, false)
            if argsOptions ~= nil then
                local argsOptionsLower = parseSlashCommandArgumentsAndReturnTable(source, true)
                local searchValues = tcon(argsOptionsLower, " ", 2, #argsOptionsLower)
                if searchValues ~= nil then
                    local inspectStr = argsOptions[1]
                    --d(">>inspectStr: " ..tos(inspectStr))
                    searchData = buildSearchData(searchValues, 10) --10 milliseconds delay before search starts

                    preventEndlessLoop = true
                    inspectResults(nil, searchData, data, inspectStr, evalString(inspectStr)) --evalString uses pcall and returns boolean, table(nilable)
                    preventEndlessLoop = false

                    return
                end
            end
        end


        --Else: Show error message
        local err = tos(...)
        err = (strgsub(err, "(stack traceback)", "|cff3333%1", 1))
        err = (strgsub(err, "%S+/(%S+%.lua:)", "|cff3333> |c999999%1"))
        df("[TBUG]<<<ERROR>>>\n%s", err)
        return
    end
    local firstInspectorShow = false
    local firstInspector = tbug.firstInspector
    local nres = select("#", ...)
    if doDebug then d(">nres: " ..tos(nres)) end
    local numTabs = 0
    local errorOccured = false
    if firstInspector and firstInspector.tabs then
        numTabs = #firstInspector.tabs
        if doDebug then d(">>firstInspector found with numTabs: " ..tos(numTabs)) end
    end
    --Increase the number of tabs by 1 to show the correct number at the tab title and do some checks
    --The actual number of tabs increases in #firstInspector.tabs after (further down below) a new tab was created
    --via local newTab = firstInspector:openTabFor(...)
    numTabs = numTabs + 1
    local calledRes = 0
    for ires = 1, nres do
        local res = select(ires, ...)
        calledRes = calledRes +1
        if rawequal(res, _G) then
            --if not globalInspector then
            if doDebug then d(">>globalInspector shows _G var") end
            tbug_getGlobalInspector = tbug_getGlobalInspector or tbug.getGlobalInspector
            globalInspector = globalInspector or tbug_getGlobalInspector()
            globalInspector:refresh()
            globalInspector.control:SetHidden(false)
            globalInspector.control:BringWindowToTop()
            getSearchDataAndUpdateInspectorSearchEdit(searchData, globalInspector)
            --end
        else
            if doDebug then d(">>no _G var") end
            local tabTitle = ""
            --[[
            --Mouse ver Control currently also just uses the normal template: titleTemplate
            if isMOC == true then
                tabTitle = titleMocTemplate
            end
            ]]
            if data and data.title then
                tabTitle = data.title
            else
                if not isMOC and specialInspectionString and specialInspectionString ~= "" then
                    tabTitle = specialInspectionString
                else
                    tabTitle = strformat("%d", ton(numTabs) or ires)
                end
                tabTitle = strformat(titleTemplate, tos(tabTitle))
            end
            if doDebug then d(">>tabTitle: " ..tos(tabTitle)) end


            --20250330 Detect if passed in data contains a "custom class" like ScriptsViewer and then
            --do not always reuse the firstInspector to try to show that, but create a new inspctor with that class
            local useCustomInspectorClass = false --Any custom inspector class passed in?
            if data ~= nil then
                if not recycle then
                    --Shall the inspector be opened with a new one and a special class? e.g ScriptsViewer
                    local specialMasterlistType = data.specialMasterlistType
                    if specialMasterlistType ~= nil then
                        local newInspectorClass = specialMasterListType2InspectorClass[specialMasterlistType]
                        if newInspectorClass ~= nil then
                            useCustomInspectorClass = true
                        end
                    end
                    if tbug.doDebug then d(">useCustomInspectorClass: " ..tostring(useCustomInspectorClass)) end
                end
            end

            --Only reuse the firstInspector if no custom inspector class is acquired, or if it wasn't created with a custom inspector class
            if firstInspector ~= nil then
                if type(source) ~= stringType then
                    source = getControlName(res)
                else
                    if not isMOC and not specialInspectionString and type(ton(tabTitle)) == numberType then
                        local objectKey = tbug_getKeyOfObject(source)
                        if objectKey and objectKey ~= "" then
                            tabTitle = objectKey
                        end
                    end
                end
                --Open existing tab in firstInspector

                --Use existing inspector?
                if recycle == true and not useCustomInspectorClass and not firstInspector.usesCustomInspectorClass then
                    if doDebug then d(">using existing inspector") end
                    --ObjectInspector:openTabFor(object, title, inspectorTitle, useInspectorTitel, data, isMOC, openedFromExistingInspector)
                    local newTab = firstInspector:openTabFor(res, tabTitle, source, nil, nil, isMOC, false)

                    if doDebug then
                        tbug._res = res
                        tbug._newTab = newTab
                    end

                    if newTab ~= nil then
                        --d(">>newTab at first inspector!")
                        if doDebug then d(">>newTab at first inspector!") end
                        --local newTabLabelText = newTab.label:GetText()
                        --local newTabLabelTextNew = ((isMOC == true and newTabLabelText .. " " .. source) or (specialInspectionString ~= nil and newTabLabelText)) or source
                        --df(">newTabLabelTextNew: %s, tabTitle: %s, source: %s", tos(newTabLabelTextNew), tos(tabTitle), tos(source))
                        --firstInspector.title:SetText(newTabLabelTextNew)
                        firstInspectorShow = true
                    else
                        --d(">>tbug_inspect - res: " ..tos(res) .. ", source: " ..tos(source))
                        if doDebug then d(">>tbug_inspect - res: " ..tos(res) .. ", source: " ..tos(source)) end
                        tbug_inspect = tbug_inspect or tbug.inspect
                        --object, tabTitle, winTitle, recycleActive, objectParent, currentResultIndex, allResults, data, searchData, isMOC, wasClickedAtGlobalInspector
                        tbug_inspect(res, tabTitle, source, recycle, nil, ires, {...}, data, searchData, isMOC, nil)
                        --showDoesNotExistError(res, source, nil)
                        errorOccured = true
                    end
                else
                    if doDebug then d(">>create new inspector! useCustomInspectorClass: " ..tos(useCustomInspectorClass) .. ", firstInspector.usesCustomInspectorClass: " ..tos(firstInspector.usesCustomInspectorClass) .. ", noDirectExecute: " .. tos(noDirectExecute)) end
                    --Or open new one (SHIFT key was pressed)
                    tbug_inspect = tbug_inspect or tbug.inspect
                    tbug_inspect(res, tabTitle, source, recycle, nil, ires, {...}, data, searchData, isMOC, nil)
                end
            else
                if doDebug then d(">Creating firstInspector") end
                --Create new firstInspector
                if not isMOC and not specialInspectionString and source and source ~= "" and type(source) == stringType and type(ton(tabTitle)) == numberType then
                    local objectKey = tbug_getKeyOfObject(source)
                    if objectKey and objectKey ~= "" then
                        tabTitle = objectKey
                    end
                end
                if doDebug then d(">res: " ..tos(res) .. ", tabTitle: " ..tos(tabTitle) .. ", source: " ..tos(source)) end
                tbug_inspect = tbug_inspect or tbug.inspect
                firstInspector = tbug_inspect(res, tabTitle, source, recycle, nil, ires, {...}, data, searchData, isMOC, nil)
                firstInspectorShow = true
            end
        end
    end
    if calledRes == 0 then
        errorOccured = true
    end
    if doDebug then d(">calledRes: " ..tostring(calledRes) .. ", errorOccured: " ..tos(errorOccured)) end
--d(">calledRes: " ..tostring(calledRes) .. ", errorOccured: " ..tos(errorOccured))
    if firstInspector ~= nil then
        if doDebug then d(">firstInspector found, numTabs: " ..tos(numTabs) .. ", #firstInspector.tabs: " ..tos(#firstInspector.tabs)) end
        if not errorOccured then
--d(">firstInspector found, numTabs: " ..tos(numTabs) .. ", #firstInspector.tabs: " ..tos(#firstInspector.tabs))
            if not firstInspectorShow and numTabs > 0 and #firstInspector.tabs > 0 then firstInspectorShow = true end
            if firstInspectorShow == true then
                firstInspector.control:SetHidden(false)
                firstInspector.control:BringWindowToTop()
                getSearchDataAndUpdateInspectorSearchEdit(searchData, firstInspector)
            end
        end

        --Do not flag this inspector as the first inspector if it was a Scripts Inspector/Viewer!
        if firstInspector and not firstInspector.isScriptsInspector and not firstInspector.isScriptsViewer then
            tbug.firstInspector = firstInspector
        end
    end
end
tbug.inspectResults = inspectResults

function tbug.prepareItemLink(control, asPlainText)
    asPlainText = asPlainText or false
    local itemLink = ""
    local bagId = (control.dataEntry and control.dataEntry.data and (control.dataEntry.data.bagId or control.dataEntry.data.bag)) or
            (control.dataEntry and (control.dataEntry.bagId or control.dataEntry.bag))
            or control.bagId or control.bag
    local slotIndex = (control.dataEntry and control.dataEntry.data and (control.dataEntry.data.slotIndex or control.dataEntry.data.index or control.dataEntry.data.slot)) or
            (control.dataEntry and (control.dataEntry.slotIndex or control.dataEntry.index or control.dataEntry.slot))
            or control.slotIndex or control.index or control.slot
    if bagId == nil or slotIndex == nil then
        local parentControl = control:GetParent()
        if parentControl ~= nil then
            bagId = (parentControl.dataEntry and parentControl.dataEntry.data and (parentControl.dataEntry.data.bagId or parentControl.dataEntry.data.bag)) or
                    (parentControl.dataEntry and (parentControl.dataEntry.bagId or parentControl.dataEntry.bag))
                    or parentControl.bagId or parentControl.bag
            slotIndex = (parentControl.dataEntry and parentControl.dataEntry.data and (parentControl.dataEntry.data.slotIndex or parentControl.dataEntry.data.index or parentControl.dataEntry.data.slot)) or
                    (parentControl.dataEntry and (parentControl.dataEntry.slotIndex or parentControl.dataEntry.index or parentControl.dataEntry.slot))
                    or parentControl.slotIndex or parentControl.index or parentControl.slot
        end
    end

    if bagId and slotIndex and type(bagId) == numberType and type(slotIndex) == numberType then
        itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
    end
    if itemLink and itemLink ~= "" and asPlainText == true then
        --Controls within ESO will show itemLinks "comiled" as clickable item's link. If we only want the ||h* plain text
        --we need to remove the leading | so that it's not recognized as an itemlink anymore
        local ilPlaintext = (strgsub(itemLink, "^%|", "", 1))
        itemLink = "| " .. ilPlaintext
    end
    return itemLink
end

local function acquireInspector(inspectorClass, subject, name, reuseActiveInspector, titleName, data, searchData, isMOC, wasClickedAtGlobalInspector)
    objInsp = objInsp or classes.ObjectInspector

    if inspectorClass == nil then
        inspectorClass = objInsp
    end

    --local useCustomClass = inspectorClass ~= objInsp and true or false

    if tbug.doDebug then d("[tbug]acquireInspector - reuse: " ..(tos(reuseActiveInspector) ..(", class: " .. (tos((inspectorClass ~= nil and (inspectorClass == objInsp and "ObjectInspector") or (inspectorClass == tbug.specialMasterListType2InspectorClass["ScriptsViewer"] and "ScriptsViewer"))) or "n/a")))) end
    if inspectorClass ~= nil and inspectorClass.acquire ~= nil then

        local inspector = inspectorClass:acquire(subject, name, reuseActiveInspector, titleName, data) --> Calls ObjectInspector.acquire
        if inspector ~= nil then
            if tbug.doDebug then d(">inspector.usesCustomInspectorClass: " ..tos(inspector.usesCustomInspectorClass)) end

            inspector.control:SetHidden(false)
            inspector:refresh(isMOC, false, wasClickedAtGlobalInspector, data)
            getSearchDataAndUpdateInspectorSearchEdit(searchData, inspector)
            return inspector
        end
    end
    return
end
tbug.acquireInspector = acquireInspector

function tbug.inspect(object, tabTitle, winTitle, recycleActive, objectParent, currentResultIndex, allResults, data, searchData, isMOC, wasClickedAtGlobalInspector)
    local inspector = nil
    isMOC = isMOC or false
    wasClickedAtGlobalInspector = wasClickedAtGlobalInspector or false
    local doDebug = tbug.doDebug --TODO: change again

    local resType = type(object)
    if doDebug then
        tbug._debugInspect = {
            object = object,
            tabTitle = tabTitle,
            winTitle = winTitle,
            recycleActive = recycleActive,
            objectParent = objectParent,
            currentResultIndex = currentResultIndex,
            allResults = allResults,
            data = data,
            searchData = searchData,
            isMOC = isMOC,
            wasClickedAtGlobalInspector = wasClickedAtGlobalInspector,
        }
        d("[tbug.inspect]object: " ..tos(object) .. ", objType: "..tos(resType) ..", tabTitle: " ..tos(tabTitle) .. ", winTitle: " ..tos(winTitle) .. ", recycleActive: " .. tos(recycleActive) ..", objectParent: " ..tos(objectParent) .. ", searchData: " ..tos(searchData))
    end

    objInsp = objInsp or classes.ObjectInspector
    local newInspectorClass = objInsp
    local useCustomInspectorClass = false
    local dataTitle
    local noDirectExecute = false
    --Any custom inspector class passed in?
    if data ~= nil then
        noDirectExecute = data.noDirectExecute or false --do not execute the code but show it in the ScriptViewer e.g.
        dataTitle = data.title
        if tbug.doDebug then d(">data.title: " .. tos(dataTitle)) end

        if not recycleActive then
            --Shall the inspector be opened with a new one and a special class? e.g ScriptsViewer
            local specialMasterlistType = data.specialMasterlistType
            if specialMasterlistType ~= nil then
                newInspectorClass = specialMasterListType2InspectorClass[specialMasterlistType]
                useCustomInspectorClass = (newInspectorClass ~= nil and newInspectorClass ~= objInsp and true) or false

                if tbug.doDebug then d(">useCustomInspectorClass: " ..tos(useCustomInspectorClass)) end
                --[[
                local title = tbug_glookup(object) or winTitle or tos(object)


                local panel = tbug_makePanel(inspectorCurrentlyShown, ScriptsInspectorPanel, "ScriptsViewer", nil)
                if panel == nil then return false end
                inspectorCurrentlyShown:removeTab(selfVar.subject or 1)
                panel:buildMasterList() --> Calls ScriptsInspectorPanel:buildMasterList()
                ]]
            end
        end
    end


    if rawequal(object, _G) then
--d("!!!!!!rawequal _G")
        if doDebug then d(">rawequal _G") end
        tbug_getGlobalInspector = tbug_getGlobalInspector or tbug.getGlobalInspector
        globalInspector = globalInspector or tbug_getGlobalInspector()
        inspector = globalInspector
        inspector.control:SetHidden(false)
        inspector:refresh() --will remove all tabs and create them again
        getSearchDataAndUpdateInspectorSearchEdit(searchData, inspector)

    else

        if resType == tableType then
--d("!!!!!!TABLE")
            if doDebug then d(">table") end
            local title = tbug_glookup(object) or winTitle or tos(object)
            if wasClickedAtGlobalInspector == true and winTitle ~= nil and winTitle ~= "" and winTitle ~= title and not startsWith(winTitle, "table: ") then
                title = winTitle
            elseif wasClickedAtGlobalInspector == true and winTitle == nil then
                wasClickedAtGlobalInspector = false
                --Check which is the active tab at the global inspector and add it in front of the title
                tbug_getGlobalInspector = tbug_getGlobalInspector or tbug.getGlobalInspector
                globalInspector = globalInspector or tbug_getGlobalInspector()
                if globalInspector ~= nil then
                    local globalInspectorActiveTab = globalInspector.activeTab
                    if globalInspectorActiveTab ~= nil then
                        local newTitle = globalInspectorActiveTab.tabName or globalInspectorActiveTab.titleText
                        --d(">title: " ..tos(title) ..", newTitle: " ..tos(newTitle))
                        local newTitleTableIndex
                        if tabTitle ~= nil and tabTitle ~= title and startsWith(title, "table: ") then
                            newTitleTableIndex = tabTitle
                        else
                            newTitleTableIndex = title
                        end
                        if newTitle ~= nil and newTitleTableIndex ~= nil and newTitle ~= "" and newTitle ~= newTitleTableIndex then
                            title = newTitle .. "[" .. newTitleTableIndex .. "]"
                            wasClickedAtGlobalInspector = true
                        end
                    end
                end
            end
            if dataTitle == nil then
                if not endsWith(title, "]") and not endsWith(title, "[]") then title = title .. "[]" end
            end
            inspector = acquireInspector(newInspectorClass, object, tabTitle, recycleActive, title, data, searchData, isMOC, wasClickedAtGlobalInspector)
            --[[
            objInsp = objInsp or classes.ObjectInspector
            inspector = objInsp:acquire(object, tabTitle, recycleActive, title, data)
            if inspector ~= nil then
                inspector.control:SetHidden(false)
                inspector:refresh(isMOC, false, wasClickedAtGlobalInspector)
                getSearchDataAndUpdateInspectorSearchEdit(searchData, inspector)
            end
            ]]

        elseif isControl(object) then
--d("!!!!!!CONTROL")
            if doDebug then d(">isControl") end
            local title = ""
            if type(winTitle) == stringType then
                title = winTitle
            else
                title = getControlName(object)
            end

            inspector = acquireInspector(newInspectorClass, object, tabTitle, recycleActive, title, data, searchData, isMOC, nil)
            --[[
            objInsp = objInsp or classes.ObjectInspector
            inspector = objInsp:acquire(object, tabTitle, recycleActive, title, data)
            if inspector ~= nil then
                inspector.control:SetHidden(false)
                inspector:refresh(isMOC, false, nil)
                getSearchDataAndUpdateInspectorSearchEdit(searchData, inspector)
            end
            ]]

        else
            if useCustomInspectorClass == true and _G[object] ~= nil then
--d("!!!!!!useCustomInspectorClass - noDirectExecute: " ..tos(noDirectExecute))
                inspector = acquireInspector(newInspectorClass, object, tabTitle, recycleActive, winTitle, data, searchData, isMOC, nil)

            else
                if resType == functionType then
--d("!!!!!!FUNCTION")
                    if doDebug then d(">function") end
                    showFunctionReturnValue(object, tabTitle, winTitle, objectParent)
                else
--d("!!!!!!OTHERS")
                    if doDebug then d(">all others...") end
                    --Check if the source of the call was ending on () -> it was a function call then
                    --Output the function data then
                    local wasAFunction = false
                    if winTitle and winTitle ~= "" then
                        local winTitleLast2Chars = strsub(winTitle, -2)
                        local winTitleLastChar = strsub(winTitle, -1)
                        if winTitleLast2Chars == "()" or winTitleLastChar == ")" then
                            wasAFunction = true
                        end
                    end
                    if not wasAFunction then
                        if doDebug then d(">>showDoesNotExistError") end
                        showDoesNotExistError(object, winTitle, tabTitle)
                    else
                        --Object contains the current return value of the function.
                        --currentResult is the index of that result, in table allResults.
                        --Output the function return value text, according to the "call to tbug.inspect"
                        if currentResultIndex and allResults then
                            if currentResultIndex == 1 then
                                d("[TBUG]Results of function \'" .. tos((winTitle ~= nil and winTitle ~= "" and winTitle) or tabTitle) .. "\':")
                            end
                            d("[" ..tos(currentResultIndex) .."]" .. tos(object))
                        end
                    end
                end
            end
        end
    end

    if useCustomInspectorClass == true and inspector then
        inspector.usesCustomInspectorClass = true
    end

    return inspector
end
tbug_inspect = tbug.inspect

--Get a panel of an inspector
function tbug.getInspectorPanel(inspectorName, panelName)
    if tbug[inspectorName] then
        local inspector = tbug[inspectorName]
        local panels = inspector.panels
        if panels and panels[panelName] then
            return panels[panelName]
        end
    end
    return nil
end
local tbug_getInspectorPanel = tbug.getInspectorPanel

--Refresh the panel of a TableInspector
function tbug.refreshInspectorPanel(inspectorName, panelName, delay)
    delay = delay or 0
--d("[tbug.refreshInspectorPanel]inspectorName: " ..tos(inspectorName) .. ", panelName: " ..tos(panelName) .. ", delay: " ..tos(delay))
    local function refreshPanelNow()
        local panel = tbug_getInspectorPanel(inspectorName, panelName)
        if panel and panel.refreshData then
            --d(">refreshing now...")
            panel:refreshData()
            if panel.refreshVisible then panel:refreshVisible() end
        end
    end
    --Delayed call?
    if delay > 0 then
        zo_callLater(function() refreshPanelNow() end, delay)
    else
        refreshPanelNow()
    end
end
local tbug_refreshInspectorPanel = tbug.refreshInspectorPanel

--Check if the TBUG TableInspector with the scripts tab is currently shown and needs a refresh then
function tbug.checkIfInspectorPanelIsShown(inspectorName, panelName)
    if tbug[inspectorName] then
        local panel = tbug_getInspectorPanel(inspectorName, panelName)
        local panelCtrl = panel.control
        if panelCtrl and panelCtrl.IsHidden then
            return not panelCtrl:IsHidden()
        end
    end
    return false
end
local tbug_checkIfInspectorPanelIsShown = tbug.checkIfInspectorPanelIsShown

local function refreshTitleAndTabs(selfVar)
    if selfVar == nil then return end
    local titleCtrl = selfVar.title
    if titleCtrl ~= nil then
        tbug_SetTemplate(nil, titleCtrl)
    end
    tbug_SetTemplate(selfVar.tabs, nil)
    tbug_SetTemplate(selfVar.tabScroll, nil)
end
tbug.RefreshTitleAndTabs = refreshTitleAndTabs

local totalRefreshFunc = function(totalRefresh, selfVar)
    totalRefresh = totalRefresh or false
    if totalRefresh == true and selfVar ~= nil then
        refreshTitleAndTabs(selfVar)

        selfVar.contents:SetHidden(true)
        selfVar.contentsBg:SetHidden(true)
        selfVar.bg:SetHidden(true)
        selfVar.activeBg:SetHidden(true)
        selfVar.tabScroll:SetHidden(true)
        selfVar.title:SetHidden(true)

        selfVar.contents:SetHidden(false)
        selfVar.contentsBg:SetHidden(false)
        selfVar.bg:SetHidden(false)
        selfVar.activeBg:SetHidden(false)
        selfVar.tabScroll:SetHidden(false)
        selfVar.title:SetHidden(false)
    end
end


local function iterateInspectorsWithCallback(globalInspectorToo, firstInspectorSeparate, callbackFunc, totalRefresh)
    if type(callbackFunc) ~= functionType then return end
    globalInspectorToo = globalInspectorToo or false
    firstInspectorSeparate = firstInspectorSeparate or false
    totalRefresh = totalRefresh or false
    tbug_getGlobalInspector = tbug_getGlobalInspector or tbug.getGlobalInspector
    globalInspector = globalInspector or tbug_getGlobalInspector(true)

    local firstInspector
    if globalInspectorToo == true then
        callbackFunc(globalInspector, nil, nil, nil)
        totalRefreshFunc(totalRefresh, globalInspector)
    end

    if firstInspectorSeparate == true then
        firstInspector = tbug.firstInspector
        callbackFunc(firstInspector, nil, nil, nil)
        totalRefreshFunc(totalRefresh, firstInspector)
    end

    local inspectorWindows = tbug.inspectorWindows
    if inspectorWindows ~= nil and #inspectorWindows > 0 then
        for windowIdx, windowData in ipairs(inspectorWindows) do
            callbackFunc(windowData, windowIdx, globalInspector, firstInspector)
            totalRefreshFunc(totalRefresh, windowData)
        end
    end
end

local callbackFuncForClose = function(inspectorData, inspectorWindowIndex, p_globalInspector, firstInspector)
    if inspectorData == nil then return end
    if inspectorWindowIndex == nil and p_globalInspector == nil and firstInspector == nil then
        if inspectorData.release ~= nil then
            inspectorData.release()
            return true
        end
    elseif inspectorWindowIndex ~= nil then
        if (firstInspector == nil or (firstInspector ~= nil and inspectorData ~= firstInspector))
                and (p_globalInspector == nil or (p_globalInspector ~= nil and inspectorData ~= p_globalInspector)) then
            if inspectorData.control ~= nil and not inspectorData.control:IsHidden() then
                inspectorData:release()
                return true
            end
        end
    end
    return false
end

local callbackFuncForRefresh = function(inspectorData, inspectorWindowIndex, p_globalInspector, firstInspector)
    if inspectorData == nil then return end
    if inspectorWindowIndex == nil and p_globalInspector == nil and firstInspector == nil then
        if inspectorData.refresh ~= nil then
            inspectorData:refresh()
            return true
        end
    elseif inspectorWindowIndex ~= nil then
        if (firstInspector == nil or (firstInspector ~= nil and inspectorData ~= firstInspector))
                and (p_globalInspector == nil or (p_globalInspector ~= nil and inspectorData ~= p_globalInspector)) then
            if inspectorData.control ~= nil and not inspectorData.control:IsHidden() then
                if inspectorData.control.refresh ~= nil then
                    inspectorData.control:refresh()
                    return true
                elseif inspectorData.refresh ~= nil then
                    inspectorData:refresh()
                    return true
                end
            end
        end
    end
    return false
end

local function closeAllInspectors(globalInspectorToo)
    iterateInspectorsWithCallback(globalInspectorToo, true, callbackFuncForClose)
end
tbug.closeAllInspectors = closeAllInspectors

local function refreshVisibleInspectors(globalInspectorToo, totalRefresh)
    --Loop over the inspectors shown and refresh them
    iterateInspectorsWithCallback(globalInspectorToo, true, callbackFuncForRefresh, totalRefresh)
end
tbug.RefreshVisibleInspectors = refreshVisibleInspectors

local function checkIfScriptsViewerAndHideStuff(selfVar)
--d("[TBUG]checkIfScriptsViewerAndHideStuff: " .. tos(selfVar.isScriptsViewer))
    if not selfVar.isScriptsViewer then return end

    --At the ScriptsViewer completely hide the scrollList and filters
    if selfVar.list then
        selfVar.list:SetHidden(true)
        selfVar.list:SetMouseEnabled(false)
    end
    local filter = selfVar.inspector and selfVar.inspector.filterEdit and selfVar.inspector.filterEdit:GetParent()
    if filter then
        filter:SetDimensions(0, 0)
        filter:SetHidden(true)
        filter:SetMouseEnabled(false)

        for i=1, filter:GetNumChildren(), 1 do
            local filterChild = filter:GetChild(i)
            if filterChild and filterChild.SetHidden then
                filterChild:SetHidden(true)
                filterChild:SetMouseEnabled(false)
                filterChild:SetDimensions(0, 0)
            end
        end
    end
end
tbug.CheckIfScriptsViewerAndHideStuff = checkIfScriptsViewerAndHideStuff


--Select the tab at the global inspector
function tbug.inspectorSelectTabByName(inspectorName, tabName, tabIndex, doCreateIfMissing, searchData, data)
    doCreateIfMissing = doCreateIfMissing or false
--d("[TB]inspectorSelectTabByName - inspectorName: " ..tos(inspectorName) .. ", tabName: " ..tos(tabName) .. ", tabIndex: " ..tos(tabIndex) .. ", doCreateIfMissing: " ..tos(doCreateIfMissing) ..", searchData: ".. tos(searchData))
    local wasSelected = false
    if tbug[inspectorName] then
        local inspector = tbug[inspectorName]
        local isGlobalInspector = (inspectorName == "globalInspector") or false
        if inspector.getTabIndexByName and inspector.selectTab then
            --Special treatment: Restore all the global inspector tabs
            if isGlobalInspector == true and tabName == "-all-" and doCreateIfMissing == true then
                inspector:connectPanels(nil, true, true, nil)
                tabIndex = 1
            else
                tabIndex = tabIndex or inspector:getTabIndexByName(tabName)
--d(">tabIndex: " ..tos(tabIndex))
                --The tabIndex could be taken "hardcoded" from the table tbug.panelNames. So check if the current inspector's tab's really got a tab with the name of that index!
                if doCreateIfMissing == true then
                    local connectPanelNow = false
                    if isGlobalInspector == true then
--d(">>connecting tab new again: " ..tos(tabName))
                        if (not tabIndex or (tabIndex ~= nil and not inspector:getTabIndexByName(panelNames[tabIndex].name))) then
                            connectPanelNow = true
                        end
                    else
                        if tabIndex == nil then
                            connectPanelNow = true
                        end
                    end
                    if connectPanelNow == true then
                        inspector:connectPanels(tabName, true, false, tabIndex) --use the tabIndex to assure the differences between e.g. sv and Sv (see tbug.panelNames) are met!
                        tabIndex = inspector:getTabIndexByName(tabName)
                    end
                end
            end
            if tabIndex then
                wasSelected = inspector:selectTab(tabIndex)
                getSearchDataAndUpdateInspectorSearchEdit(searchData, inspector)
            end
        end
    end
    return wasSelected
end
local tbug_inspectorSelectTabByName = tbug.inspectorSelectTabByName

local currentWidthAndHeightPatternStr = "W: %s H: %s"

function tbug.updateTitleSizeInfo(selfInspector)
    local titleSizeInfo = selfInspector.titleSizeInfo
    if titleSizeInfo == nil then return end
    if titleSizeInfo:IsHidden() then return end

    local inspectorControl = selfInspector.control
    local currentWidthAndHeightStr = strformat(currentWidthAndHeightPatternStr, tos(inspectorControl:GetWidth()), tos(inspectorControl:GetHeight()))
    titleSizeInfo:SetText(currentWidthAndHeightStr)
end
local updateTitleSizeInfo = tbug.updateTitleSizeInfo

function tbug.toggleTitleSizeInfo(selfInspector)
    local titleSizeInfo = selfInspector.titleSizeInfo
    if titleSizeInfo == nil then return end
    local isHidden = titleSizeInfo:IsHidden()
    titleSizeInfo:SetHidden(not isHidden)
    if isHidden == true then
        updateTitleSizeInfo(selfInspector)
    else
        titleSizeInfo:SetText("")
    end
end

------------------------------------------------------------------------------------------------------------------------
local panelsLastRowClickedData = {}
--tbug.panelsLastRowClickedData = panelsLastRowClickedData
local function setLastRowClickedData(context, selfVar, row, data)
--d("[Tbug]setLastRowClickedData - context: " ..tos(context))
    if context == nil then return end
    if selfVar == nil and row == nil and data == nil then
        panelsLastRowClickedData[context] = nil
    else
        panelsLastRowClickedData[context] = {
            _context = context,
            self = selfVar,
            row = row,
            data = data,
        }
    end
end
tbug.setLastRowClickedData = setLastRowClickedData

local function getLastRowClickedData(context)
--d("[Tbug]setLastRowClickedData - context: " ..tos(context))
    if context == nil then return end
    return panelsLastRowClickedData[context]
end
tbug.getLastRowClickedData = getLastRowClickedData


local function isMouseRightAndLeftAndSHIFTClickEnabled(onlyBaseSetting)
    onlyBaseSetting = onlyBaseSetting or false
    local savedVars = tbug.savedVars
--d("[Tbug]isMouseRightAndLeftAndSHIFTClickEnabled - onlyBaseSetting: " ..tos(onlyBaseSetting))
    if savedVars.enableMouseRightAndLeftAndSHIFTInspector == true then
        if onlyBaseSetting == true then return true end

        if savedVars.enableMouseRightAndLeftAndSHIFTInspectorDuringCombat == false then
            return not isPlayerInCombatDungeonRaidAvA()
        end
        return true
    end
    return false
end

local onGlobalMouseUp
local function updateTbugGlobalMouseUpHandler(isEnabled)
--d("[Tbug]updateTbugGlobalMouseUpHandler - isEnabled: " ..tos(isEnabled))
    if isEnabled then
        EM:RegisterForEvent(myNAME.."_OnGlobalMouseUp", EVENT_GLOBAL_MOUSE_UP, onGlobalMouseUp)
    else
        EM:UnregisterForEvent(myNAME.."_OnGlobalMouseUp", EVENT_GLOBAL_MOUSE_UP)
    end
end
tbug.updateTbugGlobalMouseUpHandler = updateTbugGlobalMouseUpHandler


function tbug.slashCommandMOC(comingFromEventGlobalMouseUp, searchValues)
    comingFromEventGlobalMouseUp = comingFromEventGlobalMouseUp or false
    --d("tbug.slashCommandMOC - comingFromEventGlobalMouseUp: " ..tos(comingFromEventGlobalMouseUp))
    --Was already checked in event_global_mouse_up!
    --if comingFromEventGlobalMouseUp == true then
        --if not isMouseRightAndLeftAndSHIFTClickEnabled() then return end
    --end

    local env = tbug.env
    local wm = env.wm
    if not wm then return end
    local mouseOverControl = wm:GetMouseOverControl()
    --local mocName = (mouseOverControl ~= nil and ((mouseOverControl.GetName and mouseOverControl:GetName()) or mouseOverControl.name)) or "n/a"
    --d(">mouseOverControl: " .. tos(mocName))
    if mouseOverControl == nil then return end
    if mouseOverControl == GuiRoot then return end

    local searchData = buildSearchData(searchValues, 10) --10 milliseconds delay before search starts
    inspectResults((comingFromEventGlobalMouseUp == true and "MOC_EVENT_GLOBAL_MOUSE_UP") or "MOC", searchData, nil, mouseOverControl, true, mouseOverControl)
end
local tbug_slashCommandMOC = tbug.slashCommandMOC

function tbug.OpenNewWindow(windowType, searchValues)
    if not openNewWindowSlashCommands[windowType] then return end

    --Open a new ScriptsViewer?
    if windowType == "scriptsViewer" then
        searchValues = searchValues or ""
        useForScript = useForScript or tbug.useForScript
        local p_self = {}
        local p_row = {}
        local p_data = {
            key = 1,
            value = tbugScriptViewerValueForNewWindow, --pass in this table to open with the ScriptInspector UI, and then use p_data.scriptStr for the editBox there
            scriptStr = searchValues,
        }
                    --p_self, p_row, p_data, isKey, isFunctionsDataType, isClassOrObjectOrLibrary, showInNewTab, scriptStrIsValue
        useForScript(p_self, p_row, p_data, false, nil, nil, true, false, true) --noDirectExecute = true ! so the function knows to use p_data.value as table and p_data.scriptsStr for the editbox later
        --> Calls tbug_slashCommandWrapper
    end
end
local tbug_openNewWindow = tbug.OpenNewWindow

function tbug.slashCommand(args, searchValues)
    local supportedGlobalInspectorArgs = tbug.allowedSlashCommandsForPanels
    local supportedGlobalInspectorArgsLookup = tbug.allowedSlashCommandsForPanelsLookup

    local searchData = buildSearchData(searchValues, 10) --10 milliseconds delay before search starts

    --local openInNewInspector = tbug.doOpenNewInspector
    local data = tbug.dataForInspector
    local noDirectExecute = (data ~= nil and data.noDirectExecute) or false --do not execute the code but show it in the ScriptViewer e.g.

    if args ~= "" then
        if tbug.doDebug then d("[tbug]slashCommand - " ..tos(args) .. ", searchValues: " ..tos(searchValues)) end

        local argsOptions = parseSlashCommandArgumentsAndReturnTable(args, true)

        --local moreThanOneArg = (argsOptions and #argsOptions > 1) or false
        local argOne = argsOptions[1]

        if argOne == "mouse" or argOne == "m" then
            tbug_slashCommandMOC(false, searchValues)
        elseif argOne == "free" then
            SetGameCameraUIMode(true)
        elseif data == nil and openNewWindowSlashCommands[args] then --attention: pass in "args" ("scriptsViewer" e.g.), and not "argOne"!
            tbug_openNewWindow(args, searchValues)
        else
            local isSupportedGlobalInspectorArg = supportedGlobalInspectorArgs[argOne] or false
            --Check if only a number was passed in and then select the tab index of that number
            if not isSupportedGlobalInspectorArg then
                --Passed in first param is a number? Open this tab in global inspector then
                local firstArgNum = ton(argOne)
                if firstArgNum ~= nil and type(firstArgNum) == numberType and panelNames[firstArgNum] ~= nil then
                    argOne = panelNames[firstArgNum].slashCommand[1] -- use the 1st slashCommand of that panel as arguent 1 now
                    isSupportedGlobalInspectorArg = true
                end
            end

            if isSupportedGlobalInspectorArg then
                local supportedGlobalInspectorArg = firstToUpper(argOne)

                --Were searchValues added from a slash command, but they are provided via the 1st param "args"?
                if #argsOptions > 1 and searchValues == nil then
                    searchValues = tcon(argsOptions, " ", 2, #argsOptions)
                    searchData = buildSearchData(searchValues, 10) --10 milliseconds delay before search starts
                end

                --Call/show the global inspector
                if tbugGlobalInspector and tbugGlobalInspector:IsHidden() then
                    inspectResults(nil, nil, data, "_G", true, _G) -- Only call/create the global inspector, do no search. Will be done below at the "inspectorSelectTabByName" or "inspect results"
                end
                --Select the tab named in the slashcommand parameter
                local tabIndexToShow = supportedGlobalInspectorArgsLookup[supportedGlobalInspectorArg]
                if tbug.doDebug then d(">>tabIndexToShow: " ..tos(tabIndexToShow)) end
                if tabIndexToShow ~= nil then
                    if tbug.doDebug then d(">tbug_inspectorSelectTabByName") end
                    tbug_inspectorSelectTabByName("globalInspector", supportedGlobalInspectorArg, tabIndexToShow, true, searchData, data)
                else
                    if tbug.doDebug then d(">inspectResults1") end
                    inspectResults(nil, searchData, data, args, evalString(args)) --evalString uses pcall and returns boolean, table(nilable)
                end
            else
                --e.g. listtlc -> Calls function ListTLC()
                local specialInspectTabTitle
                for startStr, replaceData in pairs(specialInspectTabTitles) do
                    if startsWith(argOne, startStr) then
                        specialInspectTabTitle = replaceData.tabTitle

                        if replaceData.functionToCall ~= nil and replaceData.functionToCall ~= "" then
                            --Only 1 argument and argOne does not end on ) (closed function parameters)
                            if #argsOptions == 1 and not tbug.endsWith(argOne, ")") then
                                --replace the arguments with replaceData.functionToCall
                                args = replaceData.functionToCall
                            end
                        end
                        break
                    end
                end
                if tbug.doDebug then d(">>>>>specialInspectTabTitle: " ..tos(specialInspectTabTitle) .. ", args: " ..tos(args) .. ", noDirectExecute: " .. tos(noDirectExecute)) end
                --d(">inspectResults2")
                inspectResults(specialInspectTabTitle, searchData, data, args, evalString(args)) --evalString uses pcall and returns boolean, table(nilable) (->where the table will be the ... at inspectResults) -- Passin dummy TBUG to inspect for a new ScriptsViewer open from SlashCommand/Keybind
            end
        end
    elseif tbugGlobalInspector then
        tbug.doOpenNewInspector = nil

        if tbugGlobalInspector:IsHidden() then
            if tbug.doDebug then d(">show GlobalInspector") end
            inspectResults(nil, searchData, data, "_G", true, _G)
        else
            if tbug.doDebug then d(">hide GlobalInspector") end
            tbugGlobalInspector:SetHidden(true)
        end
    end

    clearDataForInspector()
end
local tbug_slashCommand = tbug.slashCommand

function tbug.slashCommandWrapper(args, searchValues, openInNewInspector, data)
    clearDataForInspector()
    if openInNewInspector ~= nil then
        tbug.doOpenNewInspector = openInNewInspector
    end
    if data ~= nil then
        tbug.dataForInspector = data
    end

    if tbug.doDebug then d("[TBUG]slashCommandWrapper - args: " .. tos(args) .. ", openInNewInspector: " .. tos(openInNewInspector) .. ", data: " .. tos(data)) end

    return tbug_slashCommand(args, searchValues)
end
tbug_slashCommandWrapper = tbug.slashCommandWrapper


function tbug.SoundStop()
    tbug.PlaySoundNow(nil, nil, nil, nil, false, nil)
end
local tbug_soundStop = tbug.SoundStop

function tbug.slashCommandSavedVariables(args)
    clearDataForInspector()
    tbug_slashCommand("sv", args)
end
local tbug_slashCommandSavedVariables = tbug.slashCommandSavedVariables

function tbug.slashCommandEvents(args)
    clearDataForInspector()

    local argsOptions = (args ~= nil and parseSlashCommandArgumentsAndReturnTable(args, true)) or nil
    local option1 = (argsOptions ~= nil and argsOptions[1]) or nil
--d(">argsOptions[1]: " .. tos(option1))
    if option1 ~= nil and allowedSlashCommandsEventsParameters[option1] then
        --[[
                /tbe start      Start the event tracking
                /tbe stop       Stop the event tracking
                /tbe autooff    Disable automatic event tracking
                /tbe 1reload    Enable event tracking after 1 next reloadui
                /tbe reload     Enable event tracking after each reloadui
                /tbe reloadnow  Enable event tracking after each reloadui and reload the UI now
                /tbe login      Enable event tracking once at next login
        ]]
        --value, doReloadUI, activateNextLogin, chatOutput, onlyFor1ReloadUI, allOff
        tbug_SetAutomaticEventsTrackingFlag = tbug_SetAutomaticEventsTrackingFlag or tbug.SetAutomaticEventsTrackingFlag
        if option1 == "reload" then
            tbug_SetAutomaticEventsTrackingFlag(true, false, nil, true)
        elseif option1 == "1reload" then
            tbug_SetAutomaticEventsTrackingFlag(true, false, nil, true, true)
        elseif option1 == "reloadnow" then
            tbug_SetAutomaticEventsTrackingFlag(true, true, nil, true)
        elseif option1 == "login" then
            tbug_SetAutomaticEventsTrackingFlag(nil, false, true, true)
        elseif option1 == "start" then
            tbug.StartEventTracking()
        elseif option1 == "stop" then
            tbug.StopEventTracking()
        elseif option1 == "autooff" then
            tbug_SetAutomaticEventsTrackingFlag(nil, nil, nil, true, nil, true)
        end

    else
        tbug_slashCommand("events", args)
    end
end
local tbug_slashCommandEvents = tbug.slashCommandEvents

function tbug.slashCommandScripts(args)
    clearDataForInspector()
    tbug_slashCommand("scripts", args)
end
local tbug_slashCommandScripts = tbug.slashCommandScripts

function tbug.slashCommandScriptsViewer(args)
    clearDataForInspector()
    tbug_slashCommand("scriptsViewer", args)
end
local tbug_slashCommandScriptsViewer = tbug.slashCommandScriptsViewer

function tbug.slashCommandAddOns(args)
    clearDataForInspector()
    tbug_slashCommand("addons", args)
end
local tbug_slashCommandAddOns = tbug.slashCommandAddOns

function tbug.slashCommandStrings(args)
    clearDataForInspector()
    tbug_slashCommand("strings", args)
end
local tbug_slashCommandStrings = tbug.slashCommandStrings

function tbug.slashCommandTBUG(args)
    clearDataForInspector()
    tbug_slashCommand("TBUG", args)
end
local tbug_slashCommandTBUG = tbug.slashCommandTBUG

function tbug.slashCommandITEMLINKINFO(args)
    clearDataForInspector()
    if not args or args=="" then return end
    args = zo_strtrim(args)
    if args ~= "" then
        local il = args
        d(">>>~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>>>")
        d("[TBUG]Itemlink Info: " .. il .. ", id: " ..tos(GetItemLinkItemId(il)))
        local itemType, specItemType = GetItemLinkItemType(il)
        d(string.format("-itemType: %s, specializedItemtype: %s", tos(itemType), tos(specItemType)))
        d(string.format("-armorType: %s, weaponType: %s, equipType: %s", tos(GetItemLinkArmorType(il)), tos(GetItemLinkWeaponType(il)), tos(GetItemLinkEquipType(il))))
        d("<<<~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~<<<")
    end
end
local tbug_slashCommandITEMLINKINFO = tbug.slashCommandITEMLINKINFO

function tbug.slashCommandITEMLINK()
    clearDataForInspector()
    local il = tbug.prepareItemLink(moc(), false)
    if not il or il=="" then return end
    --d(il)
    --StartChatInput("/tbiinfo "..il, CHAT_CHANNEL_SAY, nil)
    tbug.slashCommandITEMLINKINFO(il)
end
local tbug_slashCommandITEMLINK = tbug.slashCommandITEMLINK

function tbug.slashCommandSCENEMANAGER(args)
    clearDataForInspector()
    tbug_slashCommand("SCENE_MANAGER", args)
end
local tbug_slashCommandSCENEMANAGER = tbug.slashCommandSCENEMANAGER


function tbug.slashCommandDumpToChat(slashArguments)
    clearDataForInspector()
    --Dump the slashArguments' values to the chat
    local funcOfSlashArgs, errorText = zo_ls( ("d(\"[TBUG]Dump of \'%s\'\")"):format(slashArguments) )
    if funcOfSlashArgs ~= nil then
        funcOfSlashArgs()
        funcOfSlashArgs = nil
    elseif errorText ~= nil then
        d("[TBUG]|cffff0000Error:|r "..errorText)
    end
end
local tbug_slashCommandDumpToChat = tbug.slashCommandDumpToChat

function tbug.slashCommandSavedInspectors(saveOrLoad, args)
    clearDataForInspector()
    if saveOrLoad == nil then return end

    --Save inspectors?
    if saveOrLoad == true then
        --No new saved inspectors number provided: Get next free one
        local savedInspectorsNr, windowCounter, tabsCounter = tbug.saveCurrentInspectorsAndSubjects()
        if savedInspectorsNr ~= nil then
            d("[TBUG]Saved '".. tostring(windowCounter) .."' open inspector windows, with '" ..tos(tabsCounter) .. "' tabs, to:   #" ..tos(savedInspectorsNr))
        end

    elseif saveOrLoad == false then
        --Load inspectors
        local wasShiftpressed = IsShiftKeyDown()
        if args == nil or args == "" then return end
        local argsOptions = parseSlashCommandArgumentsAndReturnTable(args, true)
        local moreThanOneArg = (argsOptions and #argsOptions > 1) or false
        local argOne = argsOptions[1]

        --Only one param passed in?
        if not moreThanOneArg then
            --Check if param is a number -> Then load it if it exists
            local loadInspectorNumber = tonumber(argOne)
            if type(loadInspectorNumber) == numberType then
                tbug.loadSavedInspectors(loadInspectorNumber, wasShiftpressed)
            end
            --If not: Open the "savedInsp" tab!
            tbug_slashCommand("savedInsp", args)
            --else
            --More than 1 param passed in
            -->do nothing for now
        end
    end
end
local tbug_slashCommandSavedInspectors = tbug.slashCommandSavedInspectors

--Delayed call: /tbd <delayInSeconds> <command1> <command2> ...
function tbug.slashCommandDelayed(args)
    clearDataForInspector()
    local argsOptions = parseSlashCommandArgumentsAndReturnTable(args, false)
    local moreThanOneArg = (argsOptions and #argsOptions > 1) or false
    if moreThanOneArg then
        --Multiple arguments given after the slash command
        local secondsToDelay = ton(argsOptions[1])
        if not secondsToDelay or type(secondsToDelay) ~= numberType then return end
        if secondsToDelay < 0 then secondsToDelay = 0 end
        --Get the other arguments / search string
        local searchValuesStr
        local argsLeftStr = ""

        --Any search string provided?
        if #argsOptions > 2 then
            argsLeftStr = argsOptions[2]
            searchValuesStr = tcon(argsOptions, " ", 3, #argsOptions)
        else
            --No search string provided
            argsLeftStr = argsOptions[2]
        end
        d(strformat("[TBUG]Delayed call to: \'%s\', searchValues: %s (delay=%ss)", argsLeftStr, tos(searchValuesStr == nil and "" or searchValuesStr), tos(secondsToDelay)))
        if argsLeftStr ~= "" then
            zo_callLater(function()
                tbug_slashCommand(argsLeftStr, searchValuesStr)
            end, secondsToDelay * 1000)
        end
    end
end
local tbug_slashCommandDelayed = tbug.slashCommandDelayed

--Call the "Mouse cursor over control" slash command, but delayed (1st param of args)
function tbug.slashCommandMOCDelayed(args)
    clearDataForInspector()
    local argsOptions = parseSlashCommandArgumentsAndReturnTable(args, false)
    local secondsToDelay = (argsOptions ~= nil and ton(argsOptions[1])) or nil
    if not secondsToDelay or type(secondsToDelay) ~= numberType then return end
    if secondsToDelay < 0 then secondsToDelay = 0 end
    local searchValuesStr

    if argsOptions ~= nil then
        local numArgOptions = #argsOptions
        if numArgOptions >= 2 then
            searchValuesStr = tcon(argsOptions, " ", 2, numArgOptions)
        end
    end
    d(strformat("[TBUG]Delayed call to mouse cursor inspect, searchValues: %s  (delay=%ss)", tos(searchValuesStr == nil and "" or searchValuesStr), tos(secondsToDelay)))
    zo_callLater(function()
        d(strformat("[TBUG]Executed mouse cursor inspect, searchValues: %s  (delay=%ss)", tos(searchValuesStr == nil and "" or searchValuesStr), tos(secondsToDelay)))
        tbug_slashCommandMOC(nil, searchValuesStr)
    end, secondsToDelay * 1000)
end
local tbug_slashCommandMOCDelayed = tbug.slashCommandMOCDelayed

local function controlOutlineFunc(args, withChildren, doRemove, doRemoveAll)
    if not ControlOutline then return end
    withChildren = withChildren or false
    doRemove = doRemove or false
    doRemoveAll = doRemoveAll or false

    if doRemoveAll == true then
        ControlOutline_ReleaseAllOutlines()
        return
    end

    local outlineTheControlNowFunc = (doRemove and ControlOutline_ReleaseOutlines) or
            (not doRemove and (withChildren and ControlOutline_OutlineParentChildControls) or ControlOutline_ToggleOutline)
    if outlineTheControlNowFunc == nil then return end
    if args == nil or args == "" then
        local mouseUnderControl = moc()
        if mouseUnderControl ~= nil and mouseUnderControl.GetName then
            args = mouseUnderControl:GetName()
        end
    end
    if args == nil or args == "" then return end

    local argsOptions = parseSlashCommandArgumentsAndReturnTable(args, false)
    local moreThanOneArg = (argsOptions and #argsOptions >= 1) or false
    if moreThanOneArg then
        for _, control in ipairs(argsOptions) do
            if _G[control] ~= nil then
                outlineTheControlNowFunc(_G[control])
            end
        end
    end
end
function tbug.slashCommandControlOutline(args)
    clearDataForInspector()
    controlOutlineFunc(args, false, false, false)
end
local tbug_slashCommandControlOutline = tbug.slashCommandControlOutline

function tbug.slashCommandControlOutlineWithChildren(args)
    clearDataForInspector()
    controlOutlineFunc(args, true, false, false)
end
local tbug_slashCommandControlOutlineWithChildren = tbug.slashCommandControlOutlineWithChildren

function tbug.slashCommandControlOutlineRemove(args)
    clearDataForInspector()
    controlOutlineFunc(args, true, true, false)
end
local tbug_slashCommandControlOutlineRemove = tbug.slashCommandControlOutlineRemove

function tbug.slashCommandControlOutlineRemoveAll(args)
    clearDataForInspector()
    controlOutlineFunc(args, nil, nil, true)
end
local tbug_slashCommandControlOutlineRemoveAll = tbug.slashCommandControlOutlineRemoveAll

function tbug.dumpConstants()
    --Dump the constants to the SV table merTorchbugSavedVars_Dumps
    merTorchbugSavedVars_Dumps = merTorchbugSavedVars_Dumps or {}
    local worldName = serversShort[GetWorldName()]
    merTorchbugSavedVars_Dumps[worldName] = merTorchbugSavedVars_Dumps[worldName] or {}
    local APIVersion = GetAPIVersion()
    merTorchbugSavedVars_Dumps[worldName][APIVersion] = merTorchbugSavedVars_Dumps[worldName][APIVersion] or {}
    merTorchbugSavedVars_Dumps[worldName][APIVersion]["Constants"] = {}
    merTorchbugSavedVars_Dumps[worldName][APIVersion]["SI_String_Constants"] = {}
    --Save the "Constants" tab of the global inspector to the DUMP SVs
    tbug_getGlobalInspector = tbug_getGlobalInspector or tbug.getGlobalInspector
    globalInspector = globalInspector or tbug_getGlobalInspector()
    if not globalInspector then return end
    local constants = globalInspector.panels.constants
    if not constants then return end
    local masterList = constants.masterList
    if not masterList then return end
    local cntConstants, cntSIConstants = 0, 0
    --No entries in the constants list yet? Create it by forcing the /tbug slash command to show the global inspector,
    --and updating all variables
    if #masterList == 0 then
        tbug_slashCommand("Constants")
    end
    for idx, dataTable in ipairs(masterList) do
        --Do not save the SI_ string constants to the same table
        local data = dataTable.data
        local key = data.key
        if key ~= nil then
            local value = data.value
            if value ~= nil then
                local tvIsNumber = (type(value) == numberType) or false
                if tvIsNumber == true and string.match(key, '^SI_(.*)') ~= nil then
                    merTorchbugSavedVars_Dumps[worldName][APIVersion]["SI_String_Constants"][key] = value
                    cntSIConstants = cntSIConstants + 1
                else
                    merTorchbugSavedVars_Dumps[worldName][APIVersion]["Constants"][key] = value
                    cntConstants = cntConstants + 1
                end
            end
        end
    end
    d(string.format("[merTorchbug]Dumped %s constants, and %s SI_ string constants to the SavedVariables!\nPlease reload the UI to save the data to the disk!", tos(cntConstants), tos(cntSIConstants)))
end
local tbug_dumpConstants = tbug.dumpConstants

local function deleteDumpConstantsFromSV(worldName, APIVersion, deleteAll)
    deleteAll = deleteAll or false
    local wasError = false
    local APIVersionNumber = ton(APIVersion)
    --Delete the SV table of dumped data of the current server and apiversion
    if merTorchbugSavedVars_Dumps ~= nil then
        if deleteAll == true then
            merTorchbugSavedVars_Dumps = {}
            d("[merTorchbug]All dumped constants were deleted!\nPlease reload the UI to save the data to the disk!")
        else
            if merTorchbugSavedVars_Dumps[worldName] == nil then
                local worldNameLower = string.lower(worldName)
                if merTorchbugSavedVars_Dumps[worldNameLower] ~= nil then
                    worldName = worldNameLower
                else
                    local worldNameUpper = string.upper(worldName)
                    if merTorchbugSavedVars_Dumps[worldNameUpper] ~= nil then
                        worldName = worldNameUpper
                    end
                end
            end
            if merTorchbugSavedVars_Dumps[worldName] ~= nil then
                if merTorchbugSavedVars_Dumps[worldName][APIVersionNumber] ~= nil then
                    merTorchbugSavedVars_Dumps[worldName][APIVersionNumber] = nil
                    d(string.format("[merTorchbug]Dumped constants (server: %s, API: %s) were deleted!\nPlease reload the UI to save the data to the disk!", tos(worldName), tos(APIVersion)))
                else
                    wasError = true
                end
            else
                wasError = true
            end
        end
    else
        wasError = true
    end
    if wasError == true then
        d(string.format("[merTorchbug]Dumped constants (server: %s, API: %s) could not be found!", tos(worldName), tos(APIVersion)))
    end
end

function tbug.dumpConstantsDelete(args)
    local worldName = serversShort[GetWorldName()]
    local APIVersion = GetAPIVersion()
    if args ~= nil and  args ~= "" then
        local argsOptions = parseSlashCommandArgumentsAndReturnTable(args, false)
        --local moreThanOneArg = (argsOptions and #argsOptions > 1) or false
        local argOne = argsOptions[1]
        if argOne == "all" then
            deleteDumpConstantsFromSV(worldName, APIVersion, false)
        else
            --1st param is the worldName, 2nd is the APIversion
            local argTwo = argsOptions[2]
            if argTwo ~= nil then
                deleteDumpConstantsFromSV(argOne, argTwo, false)
            end
        end
    else
        deleteDumpConstantsFromSV(worldName, APIVersion, false)
    end
end
local tbug_dumpConstantsDelete = tbug.dumpConstantsDelete


function tbug.slashCommandLanguage(args)
    clearDataForInspector()
    local argsOptions = parseSlashCommandArgumentsAndReturnTable(args, true)
    local isOnlyOneArg = (argsOptions and #argsOptions == 1) or false
    if isOnlyOneArg == true then
        local langStr = argsOptions[1]
        if strlen(langStr) == 2 then
            SetCVar("language.2", langStr)
        end
    end
end
local tbug_slashCommandLanguage = tbug.slashCommandLanguage


--Add a script to the script history
function tbug.addScriptHistory(scriptToAdd, isScriptsViewer) --todo 20250331 add support for isScriptsViewer -> save the entries of ScriptsViewer editbox to the global inspector's scripts history too
    if tbug.doDebug then d("[TBUG]addScriptHistory - scriptToAdd: " ..tos(scriptToAdd) .. ", isScriptsViewer: " ..tos(isScriptsViewer)) end
    if scriptToAdd == nil or scriptToAdd == "" then return end
    --Check if script is not already in
    if tbug.savedVars and tbug.savedVars.scriptHistory then
        local scriptHistory = tbug.savedVars.scriptHistory
        --Check value of scriptHistory table
        local alreadyInScriptHistory = checkIfAlreadyInTable(scriptHistory, nil, scriptToAdd, false)
        if alreadyInScriptHistory == true then return end
        tins(tbug.savedVars.scriptHistory, scriptToAdd)
        --is the scripts panel currently shown? Then update it
        if tbug_checkIfInspectorPanelIsShown("globalInspector", "scriptHistory") then
            tbug.refreshInspectorPanel("globalInspector", "scriptHistory")
            --TODO: Why does a single data refresh not work directly where a manual click on the update button does work?! Even a delayed update does not work properly...
            tbug_refreshInspectorPanel("globalInspector", "scriptHistory")
        end
        if isScriptsViewer then
            local newScriptNum = #scriptHistory
            d("[tBug]Saved script as #" ..tos(newScriptNum) .. " into GlobalInspector's ScriptsHistory")
        end
    end
end
local tbug_addScriptHistory = tbug.addScriptHistory

--Chat text's entry return key was pressed
local function tbugChatTextEntry_Execute(control)
    --Update the script history if the text entry is not empty
    local chatTextEntry = CHAT_SYSTEM.textEntry
    if not chatTextEntry then return end
    local chatTextEntryText = chatTextEntry.editControl:GetText()
    if not chatTextEntryText or chatTextEntryText == "" then return end
    --Check if the chat text begins with "/script "
    local startingChatText = strlower(strsub(chatTextEntryText, 1, 8))
    if not startingChatText or startingChatText == "" then return end
    if startingChatText == "/script " then
        --Add the script to the script history (if not already in)
        tbug_addScriptHistory(strsub(chatTextEntryText, 9))
    else
        --Check if the chat text begins with "/tbug "
        startingChatText = strlower(strsub(chatTextEntryText, 1, 6))
        if startingChatText == "/tbug " then
            --Add the script to the script history (if not already in)
            tbug_addScriptHistory(strsub(chatTextEntryText, 7))
        else
            --Check if the chat text begins with "/tb "
            startingChatText = strlower(strsub(chatTextEntryText, 1, 4))
            if startingChatText == "/tb " then
                --Add the script to the script history (if not already in)
                tbug_addScriptHistory(strsub(chatTextEntryText, 5))
            end
        end
    end
end

--Logout and Quit hook function
local function tbugLogoutQuitHook(type)
--d("[TBUG]Logout/Quit PreHook - trackEventsAutoOnNextLogin: " ..tos(tbug.activateAutomaticEventTrackingOnNextLogin))
    if tbug.activateAutomaticEventTrackingOnNextLogin == true then
        tbug.savedVars.enableEventTrackerAtNextLogin = true
        tbug.savedVars.enableEventTrackerAtStartupOnlyOnce = true
        tbug.savedVars.enableEventTrackerAtStartup = false
    else
        tbug.savedVars.enableEventTrackerAtNextLogin = nil
    end
    --return true --todo remove after debugging: Prevent logout/quit to check debug messages
end

function tbug.UpdateAddOns()
    if addOns == nil or #addOns <= 0 then return end
    --Read each addon from the EVENT_ADD_ON_LOADED event: Read the addonData
    --and add infos from the AddOnManager
    for loadOrderIndex, addonData in ipairs(addOns) do
        local name = addonData.__name
        tbug.AddOnsOutput[loadOrderIndex] = {}
        local addonDataForOutput = {
            _directory = addonData.dir,
            _loadOrderIndex = loadOrderIndex,
            name = name,
            version = addonData.version,
            author = addonData.author,
            title = addonData.title,
            description = addonData.description,
            isOutOfDate = addonData.isOutOfDate,
            loadDateTime = addonData._loadDateTime,
            loadFrameTime = addonData._loadFrameTime,
            loadGameTime = addonData._loadGameTime,
            loadedAtGameTimeMS = addonData.loadedAtGameTimeMS,
            loadedAtFrameTimeMS = addonData.loadedAtFrameTimeMS,
        }
        if addonData.isLibrary then
            addonDataForOutput.isLibrary = addonData.isLibrary
            addonDataForOutput.LibraryGlobalVar = tbug.LibrariesOutput[name]
        end
        tbug.AddOnsOutput[loadOrderIndex] = addonDataForOutput
    end
end
local tbug_UpdateAddOns = tbug.UpdateAddOns

function tbug.UpdateAddOnsAndLibraries()
    tbug.AddOnsOutput = {}
    tbug.LibrariesData = {}
    --Non LibStub libraries here
    --Example
    --[[
        tbug.LibrariesData["LibSets"] = {
            name = "LibSets",
            version = "15",
            globalVarName = "LibSets",
            globalVar = { global table LibSets },
        }
    ]]


    local addonsLoaded = {}
    --Build local table of loaded addons
    for loadIndex, addonData in ipairs(addOns) do
        addonsLoaded[addonData.__name] = true
    end
    tbug.addOnsLoaded = addonsLoaded

    --Get the addon manager and scan it for IsLibrary tagged libs
    ADDON_MANAGER = GetAddOnManager()
    if ADDON_MANAGER then
        local libs = {}
        local numAddOns = ADDON_MANAGER:GetNumAddOns()
        for i = 1, numAddOns do
            local name, title, author, description, enabled, state, isOutOfDate, isLibrary = ADDON_MANAGER:GetAddOnInfo(i)
local debugHere = false
--if name == "LibGPS" then debugHere = true end
            local addonVersion = ADDON_MANAGER:GetAddOnVersion(i)
            local addonDirectory = ADDON_MANAGER:GetAddOnRootDirectoryPath(i)
if debugHere then d(">enabled: " ..tos(enabled) .. ", state: " .. tos(state) .. ", isLibrary: " .. tos(isLibrary)) end
            if enabled == true and state == ADDON_STATE_ENABLED then
                if isLibrary == true then
                    local libData = {
                        name = name,
                        version = addonVersion,
                        dir = addonDirectory,
                    }
                    tins(libs, libData)
                end
                --Is the currently looped addon loaded (no matter if library or real AddOn)?
                local addonIsLoaded = addonsLoaded[name] == true or false
if debugHere then d(">addonIsLoaded: " ..tos(addonIsLoaded)) end
                if addonIsLoaded == true then
                    --Add the addonManager data of the addon to the table addOns
                    local addonIndexInTbugAddOns
                    for idx, addonData in ipairs(addOns) do
                        if addonData.__name == name then
                            addonIndexInTbugAddOns = idx
                            break
                        end
                    end
if debugHere then d(">addonIndexInTbugAddOns: " ..tos(addonIndexInTbugAddOns)) end
                    if addonIndexInTbugAddOns ~= nil then
                        local addonDataOfTbugAddOns = addOns[addonIndexInTbugAddOns]
                        addonDataOfTbugAddOns.author = author
                        addonDataOfTbugAddOns.title = title
                        addonDataOfTbugAddOns.description = description
                        addonDataOfTbugAddOns.isOutOfDate = isOutOfDate
                        addonDataOfTbugAddOns.version = addonVersion
                        addonDataOfTbugAddOns.dir = addonDirectory
                        addonDataOfTbugAddOns.isLibrary = isLibrary
                    end
                end
            end
        end
        --Update library data for output in tbug "Libs" globalInspector tab
        if libs and #libs > 0 then
            tsort(libs, compareBySubTablesKeyName)
            --Check if a global variable exists with the same name as the librarie's name
            for _, addonData in ipairs(libs) do
                local addonName = addonData.name
                --Does the name contain a - (like in LibAddonMenu-2.0)?
                --Then split the string there and convert the 2.0 to an integer number
                local checkNameTable = {}
                if specialLibraryGlobalVarNames[addonName] ~= nil then
                    tins(checkNameTable, specialLibraryGlobalVarNames[addonName])
                else
                    tins(checkNameTable, addonName)
                    local firstCharUpperCaseName = firstToUpper(addonName)
                    if addonName ~= firstCharUpperCaseName then
                        tins(checkNameTable, firstCharUpperCaseName)
                    end
                    local nameStr, versionNumber = zo_strspl("-", addonName)
                    if versionNumber and versionNumber ~= "" then
                        versionNumber = ton(versionNumber)
                        local nameStrWithVersion = nameStr .. tos(versionNumber)
                        tins(checkNameTable, nameStrWithVersion)
                        local firstCharUpperCaseNameWithVersion = firstToUpper(nameStrWithVersion)
                        if nameStrWithVersion ~= firstCharUpperCaseNameWithVersion then
                            tins(checkNameTable, firstCharUpperCaseNameWithVersion)
                        end
                        if nameStr ~= addonName then
                            tins(checkNameTable, nameStr)
                        end
                    end
                end
                local libWasAdded = false
                for _, nameToCheckInGlobal in ipairs(checkNameTable) do
                    if _G[nameToCheckInGlobal] ~= nil then
                        local isFunction = (type(_G[nameToCheckInGlobal]) == functionType and true) or false

                        --d(">>>global was found!")
                        tbug.LibrariesData[addonName] = {
                            name = addonName,
                            version = addonData.version,
                            dir = addonData.dir,
                            globalVarName = nameToCheckInGlobal,
                            globalVar = _G[nameToCheckInGlobal],
                            globalVarIsFunction = (isFunction == true and true) or nil,
                        }
                        if not isFunction then
                            _G[nameToCheckInGlobal]._directory = addonData.dir
                        end
                        libWasAdded = true
                        break -- exit the loop
                    end
                end
                if libWasAdded == false then
                    tbug.LibrariesData[addonName] = {
                        name = addonName,
                        version = addonData.version,
                        dir = addonData.dir,
                        --globalVarName = "n/a",
                        --globalVar = nil,
                    }
                    libWasAdded = true
                end
            end
        end
    end
end
local tbug_UpdateAddOnsAndLibraries = tbug.UpdateAddOnsAndLibraries


function tbug.refreshScenes()
--d("[tbug]refreshScenes")
    tbug.ScenesOutput = {}
    tbug.FragmentsOutput = {}
    scenes = {}
    fragments = {}
    local fragmentsWithError = {}
    local globalScenes = _G.SCENE_MANAGER.scenes
    if globalScenes ~= nil then
        for sceneName, scene in pairs(globalScenes) do
            --Add the scenes for the output at the "Scenes" tbug globalInspector tab
            scenes[sceneName]            = scene
            tbug.ScenesOutput[sceneName] = scene

            --Add the fragments for the output at the "Fragm." tbug globalInspector tab
            if scene.fragments ~= nil then
                local fragmentsOfScene = scene.fragments
                for kf, vf in ipairs(fragmentsOfScene) do
                    local fragmentName = tbug_glookup(vf)
                    local fragmentNameType = type(fragmentName)
                    if fragmentNameType ~= "string" then
                        local fragmentNameWithoutTablePrefix = strgsub(tos(vf), tablePatternPrefix, "")
                        --d("[tbug]ERROR: Fragment name type wrong: " ..tos(fragmentNameType) .. ", Scene: " .. tos(v.name))
                        local wrongFragmentName = fragmentName
                        local metaTableName = (vf.__index ~= nil and "--" .. (tbug_glookup(vf.__index) or strgsub(tos(vf.__index), tablePatternPrefix, ""))) or ""
                        fragmentName = "_" .. ( (vf.control ~= nil and "CONTROL-" .. getControlName(vf.control))
                                                    or  (vf.actionLayerName ~= nil and "ACTION_LAYER-" .. tos(vf.actionLayerName))
                                                    or  (vf.__index ~= nil and (
                                                        (
                                                            ( vf.__index == ZO_WindowSoundFragment and "WINDOW_SOUND" .. (sceneName ~= nil and "_SCENE-" .. sceneName) .. ((vf.showSoundId ~= nil and "_ShowSoundId-" .. tos(vf.showSoundId)) or (vf.hideSoundId ~= nil and "_HideSoundId-" .. tos(vf.hideSoundId))) )
                                                            or ( vf.__index == ZO_TutorialTriggerFragment and "TUTORIAL_TRIGGER" .. ((vf.onShowTutorialTriggerType ~= nil and "_Type-" .. tos(vf.onShowTutorialTriggerType))) )
                                                            or ( vf.title ~= nil and "TITLE-" .. tos(vf.title) .. metaTableName )
                                                            or ( "METATABLE" .. metaTableName )
                                                        )
                                                        .. "-" .. fragmentNameWithoutTablePrefix
                                                        )
                                                    )
                                                    or  ("-" .. fragmentNameWithoutTablePrefix) )
                                        .. "_FRAGMENT"
                        local fragmentWithoutNameData = fragmentsWithError[fragmentName]
                        if fragmentWithoutNameData ~= nil then
                            fragmentWithoutNameData.__scenes = fragmentWithoutNameData.__scenes or {}
                            fragmentWithoutNameData.__scenes[sceneName] = scene
                        else
                            fragmentWithoutNameData = {
                                __scenes = { [sceneName] = scene },
                                _object = vf,
                                nameWrongType = wrongFragmentName,
                                name = fragmentName,
                            }
                        end
                        fragmentsWithError[fragmentName] = fragmentWithoutNameData
                    end
                    if fragmentName ~= nil and fragmentName ~= "" then
                        fragments[fragmentName] = fragments[fragmentName] or vf
                        fragments[fragmentName][customKey__usedInScenes]            = fragments[fragmentName][customKey__usedInScenes] or {}
                        fragments[fragmentName][customKey__usedInScenes][sceneName] = scene
                    end
                end
            end
        end
    end
    --Sort the fragments by their _G[fragmentName]
    if ZO_IsTableEmpty(fragments) then return end
    local orderFragmentsTab = {}
    for fragmentName, fragmentData in pairs(fragments) do
        table.insert(orderFragmentsTab, fragmentName)
    end
tbug._fragmentsWithError = fragmentsWithError
    tsort(orderFragmentsTab)
    for _, fragmentName in ipairs(orderFragmentsTab) do
        tbug.FragmentsOutput[fragmentName] = fragments[fragmentName]
    end
end


function tbug.refreshAddOnsAndLibraries()
--d("[tbug]refreshAddOnsAndLibraries")
    --Update and refresh the libraries list
    tbug_UpdateAddOnsAndLibraries()

    tbug.LibrariesOutput = {}
    if LibStub then
        local lsLibs = LibStub.libs
        if lsLibs then
            for k,v in pairs(lsLibs) do
                tbug.LibrariesOutput[k]=v
                lookupTabLibrary[k] = true
                local libraryTabName = tbug_glookup(v)
                if type(libraryTabName) == stringType then
                    lookupTabLibrary[libraryTabName] = true
                end
            end
        end
    end
    if tbug.LibrariesData then
        for k,v in pairs(tbug.LibrariesData) do
            tbug.LibrariesOutput[k]=v.globalVar
            lookupTabLibrary[k] = true
            local libraryTabName = (v.globalVarName ~= nil and v.globalVarName) or (tbug_glookup((v.globalVar ~= nil and v.globalVar) or v)) or nil
            if type(libraryTabName) == stringType then
                lookupTabLibrary[libraryTabName] = true
            end
        end
    end

    --Update the addonData now for the table output on tbug globalInspector tab "AddOns"
    tbug_UpdateAddOns()
end
local tbug_refreshAddOnsAndLibraries = tbug.refreshAddOnsAndLibraries

function tbug.refreshScripts()
--d(">refreshScripts")
    --Refresh the scripts history list
    tbug.ScriptsData = {}
    local svScriptsHist = tbug.savedVars.scriptHistory
    if svScriptsHist then
        tbug.ScriptsData = ZO_ShallowTableCopy(svScriptsHist)
    end
end

function tbug.refreshSavedVariablesTable()
    --Code taken from addon zgoo. All rights and thanks to the authors!
    tbug.SavedVariablesOutput = {}
    tbug.SavedVariablesTabs = {}
    tbug.SavedVariablesObjectsTabs = {}
    local svOutput = tbug.SavedVariablesOutput
    local svTabs   = tbug.SavedVariablesTabs
    local svSuffix = tbug.svSuffix
    local specialAddonSVTableNames = tbug.svSpecialTableNames
    local servers = tbug.servers
    local patternVersion = "^version$"
    local patternNumber = numberType

    --First check the addons found for possible "similar" global SV tables
    if tbug.addOnsLoaded ~= nil then
        for addonName, _ in pairs(tbug.addOnsLoaded) do
            local addonsSVTabFound = false

            for _, suffix in ipairs(svSuffix) do
                if addonsSVTabFound == false then
                    local addSVTable = 0
                    local possibeSVName = tos(addonName  .. suffix)
                    local possibeSVNameLower
                    local possibeSVNameUpper
                    local possibleSVTable = _G[possibeSVName]
                    if possibleSVTable ~= nil and type(possibleSVTable) == tableType then
                        addSVTable = 1
                    else
                        possibeSVNameLower = tos(addonName  .. suffix:lower())
                        possibleSVTable = _G[possibeSVNameLower]
                        if possibleSVTable ~= nil and type(possibleSVTable) == tableType then
                            addSVTable = 2
                        else
                            possibeSVNameUpper = tos(addonName  .. suffix:upper())
                            possibleSVTable = _G[possibeSVNameUpper]
                            if possibleSVTable ~= nil and type(possibleSVTable) == tableType then
                                addSVTable = 3
                            else

                            end
                        end
                    end
                    if addSVTable > 0 and possibleSVTable ~= nil then
                        addonsSVTabFound = true
                        if addSVTable == 1 and possibeSVName ~= nil then
                            svOutput[possibeSVName] = rawget(_G, possibeSVName)
                        elseif addSVTable == 2 and possibeSVNameLower ~= nil then
                            svOutput[possibeSVNameLower] = rawget(_G, possibeSVNameLower)
                        elseif addSVTable == 3 and possibeSVNameUpper ~= nil then
                            svOutput[possibeSVNameUpper] = rawget(_G, possibeSVNameUpper)
                        end
                    end
                else
                    break
                end
            end
        end
    end

    --Then check all other global tables for the "Default"/"EU/NA Megaserver/PTS" subtable with a value "version = <number>"
    for k, v in zo_insecureNext, _G do
        if svOutput[k] == nil and type(v) == tableType then
            --"Default" entry
            if hasMember(rawget(v, "Default"), patternVersion, patternNumber, 4) then
                svOutput[k] = v
            else
                --EU/NA Megaserveror PTS
                for _, serverName in ipairs(servers) do
                    if hasMember(rawget(v, serverName), patternVersion, patternNumber, 4) then
                        svOutput[k] = v
                    end
                end
            end
        end
    end

    --Special tables not found before (not using ZO_SavedVariables wrapper e.g.)
    for _, k in ipairs(specialAddonSVTableNames) do
        svOutput[k] = rawget(_G, k)
    end

    for k, v in pairs(svOutput) do
        --Lookup table where the found SV table is the key
        svTabs[v] = true
    end

    return svOutput
end
local tbug_refreshSavedVariablesTable = tbug.refreshSavedVariablesTable

function tbug.refreshSavedInspectors()
    --Refresh the saved inspector windows, or their "subjects"
    tbug.SavedInspectorsData = {}
    local svSavedInspectors = tbug.savedVars.savedInspectors
    if svSavedInspectors ~= nil then
        tbug.SavedInspectorsData = ZO_ShallowTableCopy(svSavedInspectors)
    end
end

local function refreshAddOnsAndLibrariesAndSavedVariablesNow()
    --Update libs and AddOns
    tbug_refreshAddOnsAndLibraries()
    --Find and update global SavedVariable tables
    tbug_refreshSavedVariablesTable()
end

local function onPlayerActivated(event)
    refreshAddOnsAndLibrariesAndSavedVariablesNow()
end

--The possible slash commands in the chat editbox
local function slashCommands()
    --Uses params: any variable/function. Show the result of the variable/function in the chat.
    --             any table/control/userdata. Open the torchbug inspector and show the variable contents
    --             "free": Frees the mouse and let's you move it around (same like the vanilla game keybind)
    --w/o param: Open the torchbug UI and load + cache all global variables, constants etc.
    SLASH_COMMANDS["/tbug"]     = tbug_slashCommand
    if SLASH_COMMANDS["/tb"] == nil then
        SLASH_COMMANDS["/tb"]   = tbug_slashCommand
    end

    --Call the slash command delayed
    SLASH_COMMANDS["/tbugd"]     = tbug_slashCommandDelayed
    SLASH_COMMANDS["/tbugdelay"] = tbug_slashCommandDelayed
    if SLASH_COMMANDS["/tbd"] == nil then
        SLASH_COMMANDS["/tbd"]   = tbug_slashCommandDelayed
    end

    --Show the info about the control below the mouse
    if SLASH_COMMANDS["/tbm"] == nil then
        SLASH_COMMANDS["/tbm"]   = function(...) tbug_slashCommandMOC(false, ...) end
    end
    SLASH_COMMANDS["/tbugm"]    = function(...) tbug_slashCommandMOC(false, ...) end

    --Show the info about the control below the mouse delayed by <seconds>
    if SLASH_COMMANDS["/tbdm"] == nil then
        SLASH_COMMANDS["/tbdm"]   = tbug_slashCommandMOCDelayed
    end
    SLASH_COMMANDS["/tbugdm"]    = tbug_slashCommandMOCDelayed
    SLASH_COMMANDS["/tbugdelaymouse"] = tbug_slashCommandMOCDelayed

    --Show the scripts tab at the torchbug UI
    if SLASH_COMMANDS["/tbs"]  == nil then
        SLASH_COMMANDS["/tbs"]  = tbug_slashCommandScripts
    end
    SLASH_COMMANDS["/tbugs"]    = tbug_slashCommandScripts

    --Show the scripts viewer inspector
    if SLASH_COMMANDS["/tbsv"]  == nil then
        SLASH_COMMANDS["/tbsv"]  = tbug_slashCommandScriptsViewer
    end
    SLASH_COMMANDS["/tbugsv"]    = tbug_slashCommandScriptsViewer

    --Show the events tab at the torchbug UI
    if SLASH_COMMANDS["/tbe"]  == nil then
        SLASH_COMMANDS["/tbe"]  = tbug_slashCommandEvents
    end
    SLASH_COMMANDS["/tbevents"] = tbug_slashCommandEvents
    SLASH_COMMANDS["/tbuge"]    = tbug_slashCommandEvents

    --Show the SavedVariables tab at the torchbug UI
    if SLASH_COMMANDS["/tbsv"]  == nil then
        SLASH_COMMANDS["/tbsv"]  = tbug_slashCommandSavedVariables
    end
    SLASH_COMMANDS["/tbugsv"]    = tbug_slashCommandSavedVariables

    --Show the AddOns tab at the torchbug UI
    if SLASH_COMMANDS["/tba"] == nil then
        SLASH_COMMANDS["/tba"]   = tbug_slashCommandAddOns
    end
    SLASH_COMMANDS["/tbugaddons"]    = tbug_slashCommandAddOns
    SLASH_COMMANDS["/tbuga"]    = tbug_slashCommandAddOns

    --Create an itemlink for the item below the mouse and get some info about it in the chat
    if SLASH_COMMANDS["/tbi"] == nil then
        SLASH_COMMANDS["/tbi"]   = tbug_slashCommandITEMLINK
    end
    SLASH_COMMANDS["/tbugi"]    = tbug_slashCommandITEMLINK
    SLASH_COMMANDS["/tbugitemlink"]    = tbug_slashCommandITEMLINK

    --Uses params: itemlink. Get some info about the itemlink in the chat
    if SLASH_COMMANDS["/tbiinfo"] == nil then
        SLASH_COMMANDS["/tbiinfo"]   = tbug_slashCommandITEMLINKINFO
    end
    SLASH_COMMANDS["/tbugiinfo"]    = tbug_slashCommandITEMLINKINFO
    SLASH_COMMANDS["/tbugitemlinkinfo"]    = tbug_slashCommandITEMLINKINFO

    --Show the Scenes tab at the torchbug UI
    if SLASH_COMMANDS["/tbsc"] == nil then
        SLASH_COMMANDS["/tbsc"]   = tbug_slashCommandSCENEMANAGER
    end
    SLASH_COMMANDS["/tbugsc"] = tbug_slashCommandSCENEMANAGER

    --Show the Strings tab at the torchbug UI
    if SLASH_COMMANDS["/tbst"] == nil then
        SLASH_COMMANDS["/tbst"]   = tbug_slashCommandStrings
    end
    SLASH_COMMANDS["/tbugst"] = tbug_slashCommandStrings

    --Dump the parameter's values to the chat. About the same as /tbug <variable>
    SLASH_COMMANDS["/tbdump"] = tbug_slashCommandDumpToChat
    SLASH_COMMANDS["/tbugdump"] = tbug_slashCommandDumpToChat

    --Dump ALL the constants to the SavedVariables table merTorchbugSavedVars_Dumps[worldName][APIversion]
    --About the same as the DumpVars addon does
    -->Make sure to disable other addons if you only want to dump vanilla game constants!
    SLASH_COMMANDS["/tbugdumpconstants"] = tbug_dumpConstants
    SLASH_COMMANDS["/tbugdumpconstantsdelete"] = tbug_dumpConstantsDelete

    --Language change
    SLASH_COMMANDS["/tbuglang"] = tbug_slashCommandLanguage
    SLASH_COMMANDS["/tblang"] = tbug_slashCommandLanguage

    --ControlOutlines - Add/Remove an outline at a control
    SLASH_COMMANDS["/tbugo"] = tbug_slashCommandControlOutline
    if SLASH_COMMANDS["/tbo"] == nil then
        SLASH_COMMANDS["/tbo"] = tbug_slashCommandControlOutline
    end

    --ControlOutlines - Add/Remove an outline at a control + it's children
    SLASH_COMMANDS["/tbugoc"] = tbug_slashCommandControlOutlineWithChildren
    if SLASH_COMMANDS["/tboc"] == nil then
        SLASH_COMMANDS["/tboc"] = tbug_slashCommandControlOutlineWithChildren
    end

    --ControlOutlines - Remove an outline at a control + it's children
    SLASH_COMMANDS["/tbugor"] = tbug_slashCommandControlOutlineRemove
    if SLASH_COMMANDS["/tbor"] == nil then
        SLASH_COMMANDS["/tbor"] = tbug_slashCommandControlOutlineRemove
    end

    --ControlOutlines - Remove ALL outline at ALL control + it's children
    SLASH_COMMANDS["/tbugo-"] = tbug_slashCommandControlOutlineRemoveAll
    if SLASH_COMMANDS["/tbo-"] == nil then
        SLASH_COMMANDS["/tbo-"] = tbug_slashCommandControlOutlineRemoveAll
    end

    local function tbug_slashCommandListTLCs(args)
        tbug_slashCommand(specialInspectTabTitles["listtlc"].functionToCall, args)
    end

    --Add the TopLevelControl list slash command
    SLASH_COMMANDS["/tbugtlc"] = tbug_slashCommandListTLCs
    if SLASH_COMMANDS["/tbtlc"] == nil then
        SLASH_COMMANDS["/tbtlc"] = tbug_slashCommandListTLCs
    end

    --Sound play stop slash command
    SLASH_COMMANDS["/tbugsoundstop"]     = tbug_soundStop
    SLASH_COMMANDS["/tbsoundstop"] = tbug_soundStop
    if SLASH_COMMANDS["/tbss"]  == nil then
        SLASH_COMMANDS["/tbss"] = tbug_soundStop
    end

    --Saved inspectors slash command
    SLASH_COMMANDS["/tbsave"] = function(args) tbug_slashCommandSavedInspectors(true, args) end
    SLASH_COMMANDS["/tbload"] = function(args) tbug_slashCommandSavedInspectors(false, args) end

    --Add an easier reloadUI slash command
    if SLASH_COMMANDS["/rl"] == nil then
        SLASH_COMMANDS["/rl"] = function() ReloadUI("ingame") end
    end

    --Compatibilty with ZGOO (if not activated)
    if SLASH_COMMANDS["/zgoo"] == nil then
        SLASH_COMMANDS["/zgoo"] = tbug_slashCommand
    end

    --Inspect the global TBUG variable
    if GetDisplayName() == "@Baertram" then
        SLASH_COMMANDS["/tbugt"]    = tbug_slashCommandTBUG
        if SLASH_COMMANDS["/tbt"] == nil then
            SLASH_COMMANDS["/tbt"]   = tbug_slashCommandTBUG
        end


        SLASH_COMMANDS["/tbdebug"] = function()
            tbug.doDebug = not tbug.doDebug
        end
    end
end

local function loadDialogs()
    --Regster custom merTorchbug dialogs, e.g. "Confirm before ..."
    tbug.RegisterCustomDialogs()
end

local function loadKeybindings()
    -- Register Keybindings
    ZO_CreateStringId("SI_BINDING_NAME_TBUG_TOGGLE",    "Toggle UI (/tbug)")
    ZO_CreateStringId("SI_BINDING_NAME_TBUG_MOUSE",     "Control below mouse (/tbugm)")
    ZO_CreateStringId("SI_BINDING_NAME_TBUG_RELOADUI",  "Reload the UI")

    for i=1, tbug.maxScriptKeybinds, 1 do
        ZO_CreateStringId("SI_BINDING_NAME_TBUG_SCRIPT" ..tos(i),  "Run script #"..tos(i))
    end
    ZO_CreateStringId("SI_BINDING_NAME_TBUG_SCRIPTSVIEWER",  "Open new ScriptsViewer")
end


local function loadCharacterDataOfAccount(keyIsCharName)
    keyIsCharName = keyIsCharName or false
    local charactersOfAccount
    --Check all the characters of the account
    for i = 1, GetNumCharacters() do
        local name, _, _, _, _, _, characterId = GetCharacterInfo(i)
        local charName = zo_strf(SI_UNIT_NAME, name)
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

local function onAddOnLoaded(event, addOnName)
    --Add all loaded AddOns and libraries to the global "TBUG.AddOns" table of merTorchbug
    local loadTimeMs = GetGameTimeMilliseconds()
    local loadTimeFrameMs = GetFrameTimeMilliseconds()
    local loadTimeMsSinceMerTorchbugStart = sessionStartTime + loadTimeMs
    local loadTimeFrameMsSinceSessionStart = sessionStartTime + loadTimeFrameMs
    local currentlyLoadedAddOnTab = {
        __name              = addOnName,
        _loadDateTime       = tbug.formatTime(loadTimeMsSinceMerTorchbugStart),
        _loadFrameTime      = loadTimeFrameMsSinceSessionStart,
        _loadGameTime       = loadTimeMsSinceMerTorchbugStart,
        loadedAtGameTimeMS  = loadTimeMs,
        loadedAtFrameTimeMS = loadTimeFrameMs,
    }
    tins(addOns, currentlyLoadedAddOnTab)


    --TBUG was loaded now?
    if addOnName ~= myNAME then return end

    tbug.initSavedVars()

    local env =
    {
        gg = _G,
        am = ANIMATION_MANAGER,
        cm = CALLBACK_MANAGER,
        em = EM,
        sm = SCENE_MANAGER,
        wm = WINDOW_MANAGER,
        tbug = tbug,
        conf = tbug.savedVars,
    }

    env.env = setmetatable(env, {__index = _G})
    tbug.env = env

    --Too early here! Addons might load after TBUG loaded so we need to move this to EVENT_ADD_ONS_LOADED or EVENT_PLAYER_ACTIVATED
    --[[
    if not EVENT_ADD_ONS_LOADED then
        --Update libs and AddOns
        tbug_refreshAddOnsAndLibraries()
        --Find and update global SavedVariable tables
        tbug_refreshSavedVariablesTable()
    end
    ]]

    --Load the slash commands
    slashCommands()

    --load Dialogs
    loadDialogs()

    --Load keybindings
    loadKeybindings()

    --Load the Character data of the current account
    tbug.CharacterIdToName = loadCharacterDataOfAccount()

    --If LibAsync is enabled: Prepare the lookup tables etc. for tbug already after addon load here
    if LibAsync ~= nil then
        tbug.doRefresh()
    end

    --Enable event tracking?
    tbug.AutomaticEventTrackingCheck()

    --PreHook the chat#s return key pressed function in order to check for run /script commands
    --and add them to the script history
    ZO_PreHook("ZO_ChatTextEntry_Execute", tbugChatTextEntry_Execute)

    --Add a global OnMouseDown handler so we can track mouse button left + right + shift key for the "inspection start"
    local mouseUpBefore = {}
    function onGlobalMouseUp(eventId, button, ctrl, alt, shift, command)
        --d(string.format("[merTorchbug]onGlobalMouseUp-button %s, ctrl %s, alt %s, shift %s, command %s", tos(button), tos(ctrl), tos(alt), tos(shift), tos(command)))
        if not shift == true then return end

        local goOn = false
        if button == MOUSE_BUTTON_INDEX_LEFT_AND_RIGHT then
            mouseUpBefore = {}
            if not isMouseRightAndLeftAndSHIFTClickEnabled() then return end
            goOn = true
        else
            --The companion scenes do not send any MOUSE_BUTTON_INDEX_LEFT_AND_RIGHT :-( We need to try to detect it by other means
            --Get the active scene
            local activeSceneIsCompanion = (env.sm.currentScene == COMPANION_CHARACTER_KEYBOARD_SCENE) or false
            if activeSceneIsCompanion == true then
                local controlbelowMouse = moc()
                if controlbelowMouse ~= nil then
                    local currentTimestamp = GetTimeStamp()
                    mouseUpBefore[controlbelowMouse] = mouseUpBefore[controlbelowMouse] or  {}
                    if mouseUpBefore[controlbelowMouse][MOUSE_BUTTON_INDEX_LEFT] ~= nil then
                        if currentTimestamp - mouseUpBefore[controlbelowMouse][MOUSE_BUTTON_INDEX_LEFT] <= 1000 then
                            if button == MOUSE_BUTTON_INDEX_RIGHT then
                                goOn = true
                            end
                        end
                    elseif mouseUpBefore[controlbelowMouse][MOUSE_BUTTON_INDEX_RIGHT] ~= nil then
                        if currentTimestamp - mouseUpBefore[controlbelowMouse][MOUSE_BUTTON_INDEX_RIGHT] <= 1000 then
                            if button == MOUSE_BUTTON_INDEX_LEFT then
                                goOn = true
                            end
                        end
                    end
                    if goOn == false then
                        mouseUpBefore[controlbelowMouse][button] = currentTimestamp
                    end
                end
            end
        end
        if not goOn then return end
        mouseUpBefore = {}
        tbug_slashCommandMOC(true, nil)
    end

    --DebugLogViewer
    --Enable right click on main UI to bring the window to the front
    if DebugLogViewer then
        if DebugLogViewerMainWindow then
            DebugLogViewerMainWindow:SetHandler("OnMouseUp", function(selfCtrl, mouseButton, upInside)
                if upInside and mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
                    DebugLogViewerMainWindow:SetDrawTier(DT_HIGH)
                    DebugLogViewerMainWindow:SetDrawTier(DT_MEDIUM) --2nd call to fix context menus for that control
                end
            end)

            local debugLogViewerUIAutoScrollEventName = "TBUG_DLV_AutoScroll"
            --Auto scroll debuglogviewer UI to the bottom if d messages are added
            local function autoScrollDebugLogViewerMainUI()
                EM:UnregisterForUpdate(debugLogViewerUIAutoScrollEventName)
                local dlvUIList = DebugLogViewerMainWindowList
                if dlvUIList == nil then return end

                if dlvUIList:IsHidden() then
                    --CHAT_ROUTER:AddSystemMessage("DLV UI is hidden!")
                    return
                end

                EM:RegisterForUpdate(debugLogViewerUIAutoScrollEventName, 0, function()
                    EM:UnregisterForUpdate(debugLogViewerUIAutoScrollEventName)
                    local l_dlvUIList = dlvUIList or DebugLogViewerMainWindowList
                    if l_dlvUIList == nil then return end

                    --CHAT_ROUTER:AddSystemMessage("Scrolling to 999999")
                    --local scrollBar = l_dlvUIList.scrollbar
                    --if scrollBar == nil then return end
                    --ZO_ScrollList_ScrollAbsolute(l_dlvUIList, 100)
                    l_dlvUIList.timeline:Stop()
                    l_dlvUIList.scrollbar:SetValue(999999)
                end)
            end

            SecurePostHook("d", function(...)
                autoScrollDebugLogViewerMainUI()
            end)
            SecurePostHook("df", function(...)
                autoScrollDebugLogViewerMainUI()
            end)
        end
    end

    --Scroll lists hooks - Hide controls of inspctors (e.g. edit box, or slider)
    local function checkForInspectorPanelScrollBarScrolledAndHideControls(selfScrollList)
        local panelOfInspector = tbug_inspectorScrollLists[selfScrollList]
        if panelOfInspector ~= nil then
            --d(">found panelOfInspector")
            --Hide the editBox and sliderControl at the inspector panel rows, if shown
            --panelOfInspector:valueEditCancel(panelOfInspector.editBox)
            valueEdit_CancelThrottled(panelOfInspector.editBox, 100)
            --panelOfInspector:valueSliderCancel(panelOfInspector.sliderControl)
            valueSlider_CancelThrottled(panelOfInspector.sliderControl, 100)
        end
    end

    for _, scrollListFuncName in ipairs(scrollListFunctionsToHookAndHideControls) do
        SecurePostHook(scrollListFuncName, function(selfScrollList, ...)
            --tbug._selfScrollList = selfScrollList
            --d("[tbug]" .. tos(scrollListFuncName))
            checkForInspectorPanelScrollBarScrolledAndHideControls(selfScrollList)
        end)

    end

    updateTbugGlobalMouseUpHandler(isMouseRightAndLeftAndSHIFTClickEnabled(true))

    --For the automatic event tracking on next login
    ZO_PreHook("Logout",    function() return tbugLogoutQuitHook("Logout") end)
    ZO_PreHook("Quit",      function() return tbugLogoutQuitHook("Quit") end)
end
EM:RegisterForEvent(myNAME .."_AddOnLoaded", EVENT_ADD_ON_LOADED, onAddOnLoaded)

--Update all loaded libraries and addon lists
local function onAllAddOnsLoaded()
    refreshAddOnsAndLibrariesAndSavedVariablesNow()
end
EM:RegisterForEvent(myNAME .."_AddOnsLoaded", EVENT_ADD_ONS_LOADED, onAllAddOnsLoaded)

--EM:RegisterForEvent(myNAME.."_AddOnActivated", EVENT_PLAYER_ACTIVATED, onPlayerActivated) --not needed 20250629
