local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local tos = tostring
local ton = tonumber
local strformat = string.format
local strsub = string.sub
local strfind = string.find
local strlow = string.lower
local type = type
local osdate = os.date

local types = tbug.types
local stringType = types.string
local numberType = types.number
local functionType = types.func
local tableType = types.table
local userDataType = types.userdata
local structType = types.struct

local prefixForLeftKey = tbug.prefixForLeftKey

local RT = tbug.RT
local rtSpecialReturnValues = tbug.RTSpecialReturnValues
local localizationStringKeyText = rtSpecialReturnValues[RT.LOCAL_STRING].replaceName
local tbEvents = tbug.Events
local lookupEventName = tbEvents.eventList

local typeColors = tbug.cache.typeColors
local typeSafeLess = tbug.typeSafeLess
local isGetStringKey = tbug.isGetStringKey

local tbug_inspect = tbug.inspect
local tbug_truncate = tbug.truncate
local tbug_specialKeyToColorType = tbug.specialKeyToColorType
local tbug_glookup = tbug.glookup
local tbug_glookupEnum = tbug.glookupEnum

local customKeysForInspectorRows = tbug.customKeysForInspectorRows
local customKey__Object = customKeysForInspectorRows.object
local specialTabTitleCleanAtInspectorLists = tbug.specialTabTitleCleanAtInspectorLists

local tbug_buildRowContextMenuData = tbug.buildRowContextMenuData
local tbug_setEditValueFromContextMenu = tbug.setEditValueFromContextMenu

local isSpecialInspectorKey = tbug.isSpecialInspectorKey
local keyToSpecialEnum = tbug.keyToSpecialEnum
local keyToSpecialRightKeyFunc = tbug.keyToSpecialRightKeyFunc
local enums = tbug.enums
--local tmpGroups = tbug.tmpGroups

local getRelevantNameForCall = tbug.getRelevantNameForCall
local getControlName = tbug.getControlName
local getControlType = tbug.getControlType

local hideContextMenus = tbug.HideContextMenus
local valueSlider_CancelThrottled = tbug.valueSlider_CancelThrottled
local getLastRowClickedData = tbug.getLastRowClickedData

local tbug_slashCommand = tbug.slashCommand
local tbug_makePanel = tbug.makePanel

local classes = tbug.classes
--local BasicInspector = classes.BasicInspector


--Special passed in masterlist type at BuildMasterList function?
local specialMasterListTypePassedInToMasterList = {
    ["EventsViewer"] = RT.EVENTS_TABLE,
}


--------------------------------
local function getSpecialInspectorRightKeyValue(key, value, row, data)
    local specialRightKeyValueFunc = keyToSpecialRightKeyFunc[key]
    if type(specialRightKeyValueFunc) ~= functionType then return end
    local rightKeyValue = specialRightKeyValueFunc(value)
--d(">key: " .. tos(key) ..", rightKeyValue: " .. tos(rightKeyValue))
    return rightKeyValue
end


local function getSpecialInspectorKeyConstant(key, value, row, data)
    local enumNameForConstants = keyToSpecialEnum[key]
    if not enumNameForConstants then return getSpecialInspectorRightKeyValue(key, value, row, data) end

    local enumNameForConstantsWithoutUnderscoreSuffix = enumNameForConstants
    if strsub(enumNameForConstants, -1) == "_" then
        enumNameForConstantsWithoutUnderscoreSuffix = strsub(enumNameForConstants, 1, -2) --remove _ at the end
    end
--d(">enumNameForConstantsWithoutUnderscoreSuffix: " ..tos(enumNameForConstantsWithoutUnderscoreSuffix))
    local enumsForConstants = enums[enumNameForConstantsWithoutUnderscoreSuffix]
    if not enumsForConstants then return end
    --Get the prefix of the enum to check in table tbug.tmpGroups
    local constantStr = enumsForConstants[value]
    return constantStr
end


local function searchSpecialTabTitleStringPatternAndGetEnum(str, key)
    for _, patternData in ipairs(specialTabTitleCleanAtInspectorLists) do
        local stringPattern = patternData.pattern
        local enumsToUse = patternData.enum
        local stringToSearch = tostring(str)
        if strfind(stringToSearch, stringPattern) ~= nil then
--d(">>found: " .. tos(stringPattern) .. ", enumsToUse: " ..tos(enumsToUse))
            local enumsForConstants = enums[enumsToUse]
            if enumsForConstants ~= nil then
                local constantStr = enumsForConstants[key]
--d(">>>constantStr: " .. tos(constantStr))
                if constantStr ~= nil then
                    return constantStr
                end
            end
        end
    end
    return
end

local function getSpecialTabTitleCleanAtInspectorKeyConstant(selfPanel, k, v, row, data)
    --[[
    local activeTab = selfPanel.inspector.activeTab --todo bug 20240617 returns the "old active tab" at the inspector, not the one we currently switch to!!!
    if not activeTab then return end
    local tabTitleClean = activeTab.titleClean
    if tabTitleClean == nil or tabTitleClean == "" then return end
d(">getSpecialTabTitleCleanAtInspectorKeyConstant - tabTitleClean: " ..tos(tabTitleClean))

    local constantStr = searchSpecialTabTitleStringPatternAndGetEnum(tabTitleClean, k)
    if constantStr ~= nil then return constantStr end
    ]]
    --Actual tab was maybe the "last one" as code here was run before the new got updated
    --So check the saved data of last clicked row
    local lastRowClickedDataOfTableInspector = getLastRowClickedData(tableType)
    if lastRowClickedDataOfTableInspector ~= nil and lastRowClickedDataOfTableInspector.data ~= nil then
        local clickedKey = lastRowClickedDataOfTableInspector.data.key
--d(">getSpecialTabTitleCleanAtInspectorKeyConstant - clickedKey: " ..tos(clickedKey))
        if clickedKey ~= nil and clickedKey ~= "" then
            local constantStr = searchSpecialTabTitleStringPatternAndGetEnum(clickedKey, k)
            if constantStr ~= nil then return constantStr end
        end
    end
    return
end

--------------------------------
local function invoke(object, method, ...)
    return object[method](object, ...)
end

-- Same right-column conversion as keyToSpecialRightKeyFunc["uniqueId"].
local function isId64EventParamType(eventParamTypeName)
    return eventParamTypeName == "id64" or eventParamTypeName == "ItemSetCollectionSlot_id64"
end

-- Documented event payload field for an opened event record, or nil for metadata and paramN fallbacks.
-- Returns the { fieldName, typeName } entry and its 1-based signature index.
local function getEventParamField(eventRecord, key)
    if type(key) ~= stringType or type(eventRecord) ~= tableType then return nil end

    local eventParamFields = tbEvents.GetEventParamFields(eventRecord._eventId, eventRecord._eventName)
    if eventParamFields == nil then return nil end

    for paramIndex, eventParamField in ipairs(eventParamFields) do
        if eventParamField[1] == key then
            return eventParamField, paramIndex
        end
    end
    return nil
end

-- Signature order for payload keys. Documented names use their field index.
-- Undocumented extras and older saved captures stay paramN and sort by that number.
local function getEventParamSortIndex(eventRecord, key)
    if type(key) ~= stringType then return nil end
    if key == "eventId" then return 0 end

    local _, paramIndex = getEventParamField(eventRecord, key)
    if paramIndex ~= nil then return paramIndex end

    local _, _, paramNumberText = strfind(key, "^param(%d+)$")
    if paramNumberText ~= nil then
        return ton(paramNumberText)
    end
    return nil
end


-------------------------------
-- class TableInspectorPanel --

local ObjectInspectorPanel = classes.ObjectInspectorPanel
local TableInspectorPanel = classes.TableInspectorPanel .. ObjectInspectorPanel

TableInspectorPanel.CONTROL_PREFIX = "$(parent)PanelT"
TableInspectorPanel.TEMPLATE_NAME = "tbugTableInspectorPanel"

--Update the table tbug.panelClassNames with the TableInspectorPanel class
tbug.panelClassNames["tableInspector"] = TableInspectorPanel


function TableInspectorPanel:__init__(control, ...)
--d("[TBUG]TableInspectorPanel:__init__")
    ObjectInspectorPanel.__init__(self, control, ...)

    self.compareFunc = function(a, b)
        local aa, bb = a.data, b.data
        if not aa.meta then
            if bb.meta then
                return false
            end
        elseif not bb.meta then
            return true
        end

        local eventRecord = self.subject
        if type(eventRecord) == tableType and eventRecord._eventId ~= nil and not aa.meta and not bb.meta then
            local leftParamIndex = getEventParamSortIndex(eventRecord, aa.key)
            local rightParamIndex = getEventParamSortIndex(eventRecord, bb.key)
            if leftParamIndex ~= nil and rightParamIndex ~= nil then
                return leftParamIndex < rightParamIndex
            end
        end

        return typeSafeLess(aa.key, bb.key)
    end
end


function TableInspectorPanel:bindMasterList(editTable, specialMasterListID)
--d("[TBUG]TableInspectorPanel:bindMasterList - editTable: " .. tos(editTable) .. ", specialMasterListID: ".. tos(specialMasterListID))
    self.subject = editTable
    self.specialMasterListID = specialMasterListID
end


function TableInspectorPanel:buildMasterList(libAsyncTask)
--d("[TBUG]TableInspectorPanel:buildMasterList")

    if self:buildMasterListSpecial() then
--d("<was building special!")
        return
    end


    local masterList = self.masterList
    local n = 0

    local subject = self.subject
    --Add the _parentControl -> if you are at a __index invoked metatable control
    -->adds the "__Object" name
    local _parentSubject = self._parentSubject
--tbug._selfTableInspector = self
    if _parentSubject ~= nil then
        local rt = RT.GENERIC
        --local controlName = pcall(invoke, _parentSubject, "GetName")
--d(">found __parentSubject: " ..tostring(controlName))
        --if controlName then
            local data = {key = customKey__Object, value = _parentSubject} --"__Object"
            n = n + 1
            masterList[n] = ZO_ScrollList_CreateDataEntry(rt, data)
        --end
    end

    for k, v in zo_insecureNext , subject do --self.subject often is _G
        local tv = type(v)
        local rt = RT.GENERIC

        if tv == userDataType and pcall(invoke, v, "GetFontInfo") then
            rt = RT.FONT_OBJECT
        end

        local data = {key = k, value = v}
        n = n + 1
        masterList[n] = ZO_ScrollList_CreateDataEntry(rt, data)
    end

    local mt = getmetatable(subject)
    if mt then
        local rt = RT.GENERIC
        if rawequal(mt, rawget(mt, "__index")) then
            -- metatable refers to itself, which is typical for class
            -- tables containing methods => only insert the __index
            local data = {key = "__index", value = mt, meta = mt}
            n = n + 1
            masterList[n] = ZO_ScrollList_CreateDataEntry(rt, data)
        else
            -- insert the whole metatable contents
            for k, v in zo_insecureNext , mt do
                local data = {key = k, value = v, meta = mt}
                n = n + 1
                masterList[n] = ZO_ScrollList_CreateDataEntry(rt, data)
            end
        end
    end

    tbug_truncate(masterList, n)
end


function TableInspectorPanel:buildMasterListSpecial()
    local specialMasterlistType = self.specialMasterlistType
--d("[TBUG]TableInspectorPanel:buildMasterList-specialMasterlistType: " ..tos(specialMasterlistType))

    local editTable = self.subject

    local specialMasterListID = self.specialMasterListID
    local isScenes = ((specialMasterListID and specialMasterListID == RT.SCENES_TABLE) or rawequal(editTable, tbug.ScenesOutput)) or false
    local isFragments = ((specialMasterListID and specialMasterListID == RT.FRAGMENTS_TABLE) or rawequal(editTable, tbug.FragmentsOutput)) or false
--d(string.format("[tbug]TableInspectorPanel:buildMasterListSpecial - specialMasterListID: %s, scenes: %s, fragments: %s", tos(specialMasterListID), tos(isScenes), tos(isFragments)))

    tbEvents = tbug.Events

    ------------------------------------------------------------------------------------------------------------------------
    --Passed in a special masterlist setup etc. from e.g. opening a tab via the EventsViewer?
    if specialMasterlistType ~= nil then
        local specialMasterListTable = specialMasterListTypePassedInToMasterList[specialMasterlistType]
        if specialMasterListTable == nil then return false end
        local typeSpecialMasterListTable = type(specialMasterListTable)

        if typeSpecialMasterListTable == functionType then
            if tbug.doDebug then
                d(">specialMasterListPassedIn = function: " ..tos(specialMasterlistType))
                tbug._debugSelfTableInspectorPanel = self
            end
            return specialMasterListTable(self, editTable)
        elseif typeSpecialMasterListTable == tableType then
            if tbug.doDebug then
                d(">specialMasterListPassedIn = table: " ..tos(specialMasterlistType))
            end
            self:populateMasterList(editTable, specialMasterListTable)
        end
    end
    ------------------------------------------------------------------------------------------------------------------------

    if rawequal(editTable, nil) then
        return true
    elseif (specialMasterListID and specialMasterListID == RT.GENERIC) or (rawequal(editTable, _G.ESO_Dialogs)) then
        self:populateMasterList(editTable, RT.GENERIC)
    elseif isScenes or isFragments then
        tbug.refreshScenes()
        if isScenes then
            self:bindMasterList(tbug.ScenesOutput, RT.SCENES_TABLE)
            self:populateMasterList(editTable, RT.SCENES_TABLE)
        elseif isFragments then
            self:bindMasterList(tbug.FragmentsOutput, RT.FRAGMENTS_TABLE)
            self:populateMasterList(editTable, RT.FRAGMENTS_TABLE)
        end
    elseif (specialMasterListID and specialMasterListID == RT.LOCAL_STRING) or rawequal(editTable, _G.EsoStrings) then
        self:populateMasterList(editTable, RT.LOCAL_STRING)
    elseif (specialMasterListID and specialMasterListID == RT.SOUND_STRING) or rawequal(editTable, _G.SOUNDS) then
        self:populateMasterList(editTable, RT.SOUND_STRING)
        --elseif rawequal(editTable, LibStub.libs) then
    elseif (specialMasterListID and specialMasterListID == RT.LIB_TABLE) or rawequal(editTable, tbug.LibrariesOutput) then
        self:bindMasterList(tbug.LibrariesOutput, RT.LIB_TABLE)
        self:populateMasterList(editTable, RT.LIB_TABLE)
        --[[
        --ScriptsHistory is an own class -> See file classes, scriptsinspector.lua
        elseif (specialMasterListID and specialMasterListID == RT.SCRIPTHISTORY_TABLE) or rawequal(editTable, tbug.ScriptsData) then
            tbug.refreshScripts()
            self:bindMasterList(tbug.ScriptsData, RT.SCRIPTHISTORY_TABLE)
            self:populateMasterList(editTable, RT.SCRIPTHISTORY_TABLE)
        ]]
    elseif (specialMasterListID and specialMasterListID == RT.ADDONS_TABLE) or rawequal(editTable, tbug.AddOnsOutput) then
        self:bindMasterList(tbug.AddOnsOutput, RT.ADDONS_TABLE)
        self:populateMasterList(editTable, RT.ADDONS_TABLE)
    elseif (specialMasterListID and specialMasterListID == RT.EVENTS_TABLE) or rawequal(editTable, tbEvents.eventsTable) then
        tbug.RefreshTrackedEventsList()
        self:bindMasterList(tbEvents.eventsTable, RT.EVENTS_TABLE)
        self:populateMasterList(editTable, RT.EVENTS_TABLE)
    elseif (specialMasterListID and specialMasterListID == RT.SAVEDVARIABLES_TABLE) or rawequal(editTable, tbug.SavedVariablesOutput) then
        self:bindMasterList(tbug.SavedVariablesOutput, RT.SAVEDVARIABLES_TABLE)
        self:populateMasterList(editTable, RT.SAVEDVARIABLES_TABLE)
    else
        return false
    end
    return true
end


function TableInspectorPanel:canEditValue(data)
    local dataEntry = data.dataEntry
    if not dataEntry then return false end
    local typeId = dataEntry.typeId
    return typeId == RT.GENERIC
            or typeId == RT.LOCAL_STRING
            or typeId == RT.SOUND_STRING
            --or typeId == RT.SCRIPTHISTORY_TABLE
end


function TableInspectorPanel:clearMasterList(editTable)
    local masterList = self.masterList
    tbug_truncate(masterList, 0)
    self.subject = editTable
    return masterList
end


function TableInspectorPanel:initScrollList(control)
--d("[TBUG]TableInspectorPanel:initScrollList")
    ObjectInspectorPanel.initScrollList(self, control)

    local inspector = self.inspector

    local timeStampKeyPatterns = tbug.timeStampKeyPatterns
    local function checkForTimeStampKey(k, v)
        local isKeyTimeStamp = false
        if v >= -2147483647 and v <= 2147483647 then
            for _, timeStampKeyPattern in ipairs(timeStampKeyPatterns) do
                isKeyTimeStamp = (strfind(strlow(k), strlow(timeStampKeyPattern), 1, true) ~= nil and true) or false
                if isKeyTimeStamp == true then return true end
            end
        end
        return isKeyTimeStamp
    end

    --Check for special key colors!
    local function checkSpecialKeyColor(keyValue)
        if keyValue == "event" or not tbug_specialKeyToColorType then return end
        local newType = tbug_specialKeyToColorType[keyValue]
        return newType
    end

    local setupEventTable

    local function setupValue(cell, typ, val, isKey)
        isKey = isKey or false
        cell:SetColor(typeColors[typ]:UnpackRGBA())
        cell:SetText(tos(val))
    end

    local function setupValueLookup(cell, typ, val, row)
        cell:SetColor(typeColors[typ]:UnpackRGBA())
        local name = tbug_glookup(val)
        if name then
            cell:SetText(strformat("%s: %s", typ, name))
        else
            cell:SetText(tos(val))
        end
    end

    local function setupCommon(row, data, list, font)
        local k = data.key
        local tk = data.meta and "event" or type(k)
        local tkOrig = tk
        tk = checkSpecialKeyColor(k) or tkOrig

        self:setupRow(row, data)
        if row.cKeyLeft then
            setupValue(row.cKeyLeft, tk, k, true)
            if font and font ~= "" then
                row.cKeyLeft:SetFont(font)
            end
        end
        if row.cKeyRight then
            setupValue(row.cKeyRight, tk, "", true)
        end

        return k, tkOrig
    end

    local function setupAddOnRow(row, data, list, font)
        local k = data.key
        local tk = data.meta and "event" or type(k)
        local tkOrig

        self:setupRow(row, data)
        if row.cKeyLeft then
            local AddOnData = tbug.AddOnsOutput
            local addonNameClean
            local addonName
            if AddOnData and AddOnData[k] ~= nil then
                addonNameClean = AddOnData[k].name
                addonName = "[" .. tos(k) .."] " .. addonNameClean
            end

            tkOrig = tk
            tk = checkSpecialKeyColor(addonNameClean) or tkOrig
            setupValue(row.cKeyLeft, tk, addonName, true)
            if font and font ~= "" then
                row.cKeyLeft:SetFont(font)
            end
        end
        if row.cKeyRight then
            setupValue(row.cKeyRight, tk, "", true)
        end

        return k, tkOrig
    end

    local function setupGeneric(row, data, list)
        --This is a saved and now loaded eventsViewer table?
        local v = data.value
        local tv = type(v)
        if tv == tableType and v._eventId ~= nil then
            return setupEventTable(row, data, list, true)
        end


        local k, tk = setupCommon(row, data, list)
        local isNumber = tv == numberType or false
        local isKeyRightUsed = false

--d("[tbug]setupGeneric-k: " ..tos(k) ..", v: " ..tos(v) ..", tk: " ..tos(tk) ..", tv: " ..tos(tv) .. ", rightKey: " .. tos(row.cKeyRight))

        if v == nil or tv == "boolean" or isNumber then
            --Key is "text" and value is number? Show the GetString() for the text
            if k and isNumber and k ~= 0 and isGetStringKey(k)==true then
                local valueGetString = GetString(v)
                if valueGetString and valueGetString ~= "" then
                    setupValue(row.cVal, tv, v .. " |r|cFFFFFF(\""..valueGetString.."\")|r", false)
                end
            else
                if isNumber and tk == stringType and row.cKeyRight then
                    local isKeyTimeStamp = checkForTimeStampKey(k, v)
                    if isKeyTimeStamp == true then
                        row.cKeyRight:SetText(osdate("%c", v))
                        isKeyRightUsed = true
                    else
                        lookupEventName = lookupEventName or tbEvents.eventList
                        if lookupEventName ~= nil and lookupEventName[v] ~= nil and strfind(strlow(k), "eventid", 1, true) ~= nil then
                            setupValue(row.cKeyRight, "event", lookupEventName[v])
                        end
                    end
                end
                setupValue(row.cVal, tv, v)
            end
        elseif tv == stringType then
            setupValue(row.cVal, tv, strformat("%q", v))
        elseif tv == tableType and next(v) == nil then
            setupValue(row.cVal, tv, "{}")
        elseif tv == userDataType then
            local ct, ctName = getControlType(v, "CT_names")
            if ct then
                if row.cKeyRight then
                    setupValue(row.cKeyRight, type(ct), ctName, true)
                    isKeyRightUsed = true
                end
                setupValue(row.cVal, tv, getControlName(v))
            else
                setupValueLookup(row.cVal, tv, v)
            end
        else
            setupValueLookup(row.cVal, tv, v, row)

            if rawequal(v, self.subject) then
                if row.cKeyRight then
                    setupValue(row.cKeyRight, tv, "self", true)
                    isKeyRightUsed = true
                end
            else
                if row.cKeyRight and tk == stringType and tv == tableType and ton(k) ~= nil then
                    local svCharName = inspector:getSavedVariablesCharacterName(k, self.subject)
                    if svCharName ~= nil then
--d(">k: " ..tos(k) ..", v: " ..tos(v) ..", svCharName: " ..tos(svCharName))
                        setupValue(row.cKeyRight, stringType, svCharName, true)
                        isKeyRightUsed = true
                    end
                end
            end
        end

--d(">isKeyRightUsed: " ..tos(isKeyRightUsed) ..", k: " ..tos(k) ..", v: " ..tos(v))

        --Special String key -> Add right key info?
        if not isKeyRightUsed and row.cKeyRight and isSpecialInspectorKey[k] then
            local keyRightText = getSpecialInspectorKeyConstant(k, v, row, data)
            if keyRightText ~= nil and keyRightText ~= "" then
                setupValue(row.cKeyRight, type(keyRightText), keyRightText, true)
                isKeyRightUsed = true
            end
        end

        --Other special key: Key is number and tabTitleClean is e.g. bagTo*
        if not isKeyRightUsed and row.cKeyRight and tk == numberType then
            local keyRightText = getSpecialTabTitleCleanAtInspectorKeyConstant(self, k, v, row, data)
            if keyRightText ~= nil and keyRightText ~= "" then
                setupValue(row.cKeyRight, type(keyRightText), prefixForLeftKey .. keyRightText, true) -- <- to show the rightKey belongs to the left key and not the value!
                isKeyRightUsed = true
            end
        end

        -- Documented event payload field: show the API type. Skip when the right column already
        -- shows a timestamp or a resolved event name (_eventId and similar keys).
        if not isKeyRightUsed and row.cKeyRight and tk == stringType then
            local eventRecord = self.subject
            if type(eventRecord) == tableType and eventRecord._eventId ~= nil then
                local rightKeyText = row.cKeyRight:GetText()
                if rightKeyText == nil or rightKeyText == "" then
                    local eventParamField = getEventParamField(eventRecord, k)
                    local eventParamTypeName = eventParamField and eventParamField[2]
                    if isId64EventParamType(eventParamTypeName) then
                        setupValue(row.cKeyRight, stringType, zo_getSafeId64Key(v), true)
                    elseif eventParamTypeName ~= nil and eventParamTypeName ~= "" then
                        setupValue(row.cKeyRight, stringType, eventParamTypeName, true)
                    end
                end
            end
        end
    end

    local function setupFontObject(row, data, list)
        local k, tk = setupCommon(row, data, list, data.key)
        local v = data.value
        local tv = type(v)

        local ok, face, size, option = pcall(invoke, v, "GetFontInfo")
        if ok then
            --local nameFont = string.format("$(%s)|$(KB_%s)|%s", fontStyle, fontSize, fontWeight)
            v = tos(strformat("%s||%s||%s", typeColors[type(face)]:Colorize(face), typeColors[type(size)]:Colorize(size), typeColors[type(option)]:Colorize(option)))
        end

        setupValue(row.cVal, tv, v, false)
    end

    local function setupLibOrAddonTableRightKeyAndValues(row, data, list, k, tk, v, isLibrary, checkIfAddOnIsALibrary)
        isLibrary = isLibrary or false
        checkIfAddOnIsALibrary = checkIfAddOnIsALibrary or false
        local AddOnData = tbug.AddOnsOutput
        local addonName

        --Run if an addon should be handled as a library
        local isAddOnButShouldBeHandledAsLibrary = false
        if isLibrary == false and checkIfAddOnIsALibrary == true then
            addonName = AddOnData[k].name
            local libOutputTable = tbug.LibrariesOutput
            if libOutputTable[addonName] ~= nil then
                isAddOnButShouldBeHandledAsLibrary = true
            end
        end

        --Library or AddOn which is handled as a library
        if isLibrary == true or isAddOnButShouldBeHandledAsLibrary == true then
            local key = k
            if isAddOnButShouldBeHandledAsLibrary == true then
                key = addonName
            end
            if row.cKeyRight then
                local LibrariesData = tbug.LibrariesData
                local typeOfLibrary = stringType
                local libraryNameAndVersion = ""
                local wasFoundInLibStub = false
                if LibStub then
                    local lsLibs = LibStub.libs
                    local lsMinors = LibStub.minors
                    local lsLibsKey = lsLibs and lsLibs[key]
                    if lsLibsKey ~= nil and (lsLibsKey == v or (isAddOnButShouldBeHandledAsLibrary == true and v.LibraryGlobalVar and lsLibsKey == v.LibraryGlobalVar)) then
                        wasFoundInLibStub = true
                        typeOfLibrary = "obsolete"
                        libraryNameAndVersion = "LibStub"
                        if lsMinors and lsMinors[key] then
                            libraryNameAndVersion = libraryNameAndVersion .. " (v" .. tos(lsMinors[key]) ..")"
                        end
                    end
                end
                if wasFoundInLibStub == false then
                    if LibrariesData and LibrariesData[key] then
                        if LibrariesData[key].version ~= nil then
                            libraryNameAndVersion = tos(LibrariesData[key].version) or ""
                            if libraryNameAndVersion and libraryNameAndVersion ~= "" then
                                libraryNameAndVersion = "v" .. libraryNameAndVersion
                            end
                        end
                    end
                end
                setupValue(row.cKeyRight, typeOfLibrary, libraryNameAndVersion)

            end
            setupValue(row.cVal, type(v), v)

        --AddOn
        else
            if row.cKeyRight then
                local typeOfAddOn = stringType
                local addOnNameAndVersion = ""
                if AddOnData and AddOnData[k] then
                    if AddOnData[k].version ~= nil then
                        addOnNameAndVersion = tos(AddOnData[k].version) or ""
                        if addOnNameAndVersion and addOnNameAndVersion ~= "" then
                            addOnNameAndVersion = "v" .. addOnNameAndVersion
                        end
                    end
                end
                setupValue(row.cKeyRight, typeOfAddOn, addOnNameAndVersion)
            end
            setupValue(row.cVal, type(v), v)
        end
    end

    local function setupLibTable(row, data, list)
        local k, tk = setupCommon(row, data, list)
        local v = data.value
        setupLibOrAddonTableRightKeyAndValues(row, data, list, k, tk, v, true, nil)
    end

    local function setupAddOnTable(row, data, list)
        local k, tk = setupAddOnRow(row, data, list)
        local v = data.value
        local AddOnData = tbug.AddOnsOutput
        local isLibrary = AddOnData[k].isLibrary
        setupLibOrAddonTableRightKeyAndValues(row, data, list, k, tk, v, false, isLibrary)
    end

    local function setupLocalString(row, data, list)
        local k, tk = setupCommon(row, data, list)
        local v = data.value
        local tv = type(v)

        if tk == numberType then
            local si = rawget(tbug_glookupEnum("SI"), k)
            row.cKeyLeft:SetText(si or k)
            data[localizationStringKeyText] = si
            if row.cKeyRight then
                row.cKeyRight:SetText(tos(k))
            end
        end

        if tv == stringType then
            setupValue(row.cVal, tv, strformat("%q", v))
        else
            setupValue(row.cVal, tv, v)
        end
    end

    --[[
    local function setupScriptHistory(row, data, list)
        local k, tk = setupCommon(row, data, list)
        local v = data.value
        local tv = type(v)

        row.cVal:SetText("")
        if tv == stringType then
            setupValue(row.cVal, tv, v)
        end
        if row.cVal2 then
            row.cVal2:SetText("")
            v = nil
            v = tbug.getScriptHistoryComment(data.key)
            if v ~= nil and v ~= "" then
                setupValue(row.cVal2, "comment", v)
            end
        end
    end
    ]]

    function setupEventTable(row, data, list, isLoadedEventViewerTable)
        local k, tk = setupCommon(row, data, list)
        local v = data.value
        local tv = type(v)

        if not isLoadedEventViewerTable then
            if row.cKeyLeft then
                local timeStampAdded = data.value._timeStamp
                --local frameTimeAdded = data.value._frameTime
                if timeStampAdded then
                    row.cKeyLeft:SetText(osdate("%c", timeStampAdded))
                end
            end

            if tv == tableType and next(v) == nil then
                setupValue(row.cVal, tv, "{}")
            elseif tv == userDataType then
                setupValueLookup(row.cVal, tv, v)
            else
                setupValueLookup(row.cVal, tv, v)
                if rawequal(v, self.subject) then
                    if row.cKeyRight then
                        setupValue(row.cKeyRight, tv, "self")
                    end
                end
            end

            if row.cKeyRight then
                setupValue(row.cKeyRight, "event", data.value._eventName)
            end


        else
            if row.cKeyLeft then
                local timeStampAdded = data.value._timeStamp
                --local frameTimeAdded = data.value._frameTime
                if type(timeStampAdded) == numberType then
                    row.cKeyLeft:SetText(osdate("%c", timeStampAdded))
                end
            end

            if tv == tableType and next(v) == nil then
                setupValue(row.cVal, tv, "{}")
            elseif tv == userDataType then
                setupValueLookup(row.cVal, tv, v)
            else
                setupValueLookup(row.cVal, tv, v)
                if rawequal(v, self.subject) then
                    if row.cKeyRight then
                        setupValue(row.cKeyRight, tv, "self")
                    end
                end
            end

            if row.cKeyRight then
                setupValue(row.cKeyRight, "event", data.value._eventName)
            end
        end
    end

    local function hideCallback(row, data)
        if self.editData == data then
            self.editBox:ClearAnchors()
            self.editBox:SetAnchor(BOTTOMRIGHT, nil, TOPRIGHT, 0, -20)
        end
    end

    --Using height param = nil will read the actual height from the tbug.UITemplates/savedVariables
    --> See basicInspector:addDataType
	self:addDataType(RT.FONT_OBJECT,            "tbugTableInspectorRowFont", 56, setupFontObject,    hideCallback)
    self:addDataType(RT.GENERIC,                "tbugTableInspectorRow",    nil, setupGeneric,       hideCallback)
    self:addDataType(RT.LOCAL_STRING,           "tbugTableInspectorRow",    nil, setupLocalString,   hideCallback)
    self:addDataType(RT.SOUND_STRING,           "tbugTableInspectorRow",    nil, setupGeneric,       hideCallback)
    self:addDataType(RT.LIB_TABLE,              "tbugTableInspectorRow",    nil, setupLibTable,      hideCallback)
    self:addDataType(RT.ADDONS_TABLE,           "tbugTableInspectorRow",    nil, setupAddOnTable,    hideCallback)
    self:addDataType(RT.EVENTS_TABLE,           "tbugTableInspectorRow",    nil, setupEventTable,    hideCallback)
    self:addDataType(RT.SCENES_TABLE,           "tbugTableInspectorRow",    nil, setupGeneric,       hideCallback)
    self:addDataType(RT.FRAGMENTS_TABLE,        "tbugTableInspectorRow",    nil, setupGeneric,       hideCallback)
    self:addDataType(RT.SAVEDVARIABLES_TABLE,   "tbugTableInspectorRow",    nil, setupGeneric,       hideCallback)
end


--Clicking on a tables index (e.g.) 6 should not open a new tab called 6 but tableName[6] instead
function TableInspectorPanel:BuildWindowTitleForTableKey(data)
    local winTitle
    if data.key and type(tonumber(data.key)) == numberType then
        winTitle = self.inspector.activeTab.label:GetText()
        if winTitle and winTitle ~= "" then
            winTitle = tbug.cleanKey(winTitle)
            winTitle = winTitle .. "[" .. tos(data.key) .. "]"
--d(">tabTitle: " ..tos(tabTitle))
        end
    end
    return winTitle
end



function TableInspectorPanel:onRowClicked(row, data, mouseButton, ctrl, alt, shift)
    local isGlobalInspector = (self.inspector and self.inspector.control and self.inspector.control.isGlobalInspector) or false
--d"[tbug]TableInspectorPanel:onRowClicked - isGlobalInspector: " ..tos(isGlobalInspector))
    if tbug.doDebug then
        tbug._debugTableInspectorRowClicked = {
            row = row,
            data = data,
            self = self,
        }
    end
    hideContextMenus()
    local sliderCtrl = self.sliderControl
    if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
        tbug.setLastRowClickedData(tableType, self, nil, nil)

        self.editBox:LoseFocus()
        if sliderCtrl ~= nil then
            --sliderCtrl.panel:valueSliderCancel(sliderCtrl)
            valueSlider_CancelThrottled(sliderCtrl, 50)
        end

        local value = data.value
        if type(value) == stringType then
            if data.dataEntry.typeId == RT.SOUND_STRING then
                PlaySound(value)
            end
        else
            --Get metatable of a control? Save the subjectParent
            local valueToInspect = value
            local isFunctionCallWithParentSubject = false
            local _parentSubject, parentSubjectName
            local parentSubjectNameGiven = false
            if data.key == "__index" then
--d(">clicked on __index")
                --Add the subject as new line __parentSubject to the inspector result rows
                _parentSubject = self._parentSubject or (self.subject ~= nil and self.subject[customKey__Object])
                if _parentSubject == nil then
                    if self.subject ~= nil and type(self.subject == tableType) then
                        --Got the subject table metatables?
                        local mt = getmetatable(self.subject)
                        if mt ~= nil and mt.__index ~= nil then
--d(">found metatable.__index at self.subject -> parentSubject")
                            _parentSubject = self.subject
                        end
                    end
                end
                data._parentSubject = _parentSubject
            elseif type(value) == functionType and shift == true and not ctrl then
--d(">>function!")
                _parentSubject = self._parentSubject or (self.subject ~= nil and self.subject[customKey__Object])
                if _parentSubject ~= nil then
--d(">found _parentSubject")
                    --Get the name of the control but only if it's no scene as the scene name is not the control name
                    parentSubjectName = getRelevantNameForCall(_parentSubject)

                    isFunctionCallWithParentSubject = true
                    parentSubjectNameGiven = (parentSubjectName ~= nil and type(parentSubjectName) == stringType and parentSubjectName ~= "" and true) or false
                    if not parentSubjectNameGiven then
--d(">>no parentSubject name")
                        --Attention: Might only return the 1st return parameter of the function!
                        valueToInspect = function() return _parentSubject[value](_parentSubject) end
                    end
                end
            end

            tbug.setLastRowClickedData(tableType, self, row, data)
            if not shift and self.inspector.openTabFor then
                local winTitle = self:BuildWindowTitleForTableKey(data)
                local useInspectorTitel = (winTitle ~= nil and winTitle ~= "" and true) or false
--d(">inspector.openTabFor-winTitle: " ..tos(winTitle) .. ", useInspectorTitel: " ..tos(useInspectorTitel))
                self.inspector:openTabFor(valueToInspect, tos(data.key), winTitle, useInspectorTitel, data, nil, true)
            else
                local winTitle = self:BuildWindowTitleForTableKey(data)
                if (winTitle == nil or winTitle == "") and isFunctionCallWithParentSubject == true and parentSubjectNameGiven then
--d(">preparing winTitle for function")
                    winTitle = parentSubjectName .. ":" .. tos(data.key)
                end
                if shift == true and not ctrl and isFunctionCallWithParentSubject == true and parentSubjectNameGiven then
                    local slashCommand = parentSubjectName .. ":" .. tos(data.key) .. "()"
--d(">tbug.slashCommand -> function of parentSubject: " ..slashCommand)
                    --Do not use tbug_inspect directly but use the tbug.slashCommand handler instead so that all
                    --return parameters of the function are properly shown in chat
                    --valueToInspect = function() return value(_parentSubject) end
                    tbug_slashCommand(slashCommand)

                else
--d(">tbug_inspect-winTitle: " ..tos(winTitle))
                  --tbug.inspect(object, tabTitle, winTitle, recycleActive, objectParent, currentResultIndex, allResults, data, searchData, isMOC, wasClickedAtGlobalInspector)
                    local inspector = tbug_inspect(valueToInspect, tos(data.key), winTitle, not shift, nil, nil, nil, data, nil, nil, isGlobalInspector)
                    if inspector then
                        inspector.control:BringWindowToTop()
                    end
                end
            end
        end
    elseif mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
        self.editBox:LoseFocus()
        local mouseIsOverRightKey = MouseIsOver(row.cKeyRight)
        if self:canEditValue(data) then
--d(">can edit value!")
            if MouseIsOver(row.cVal) then
--d(">mouse is over cVal")
                if sliderCtrl ~= nil then
                    --sliderCtrl.panel:valueSliderCancel(sliderCtrl)
                    valueSlider_CancelThrottled(sliderCtrl, 50)
                end
--d(">valueEditStart")
                self:valueEditStart(self.editBox, row, data)
--d(">build context menu")
                tbug_buildRowContextMenuData(self, row, data, false, nil)
            elseif MouseIsOver(row.cVal2) then
                if sliderCtrl ~= nil then
                    --sliderCtrl.panel:valueSliderCancel(sliderCtrl)
                    valueSlider_CancelThrottled(sliderCtrl, 50)
                end
                self:valueEditStart(self.editBox, row, data)
            elseif MouseIsOver(row.cKeyLeft) or mouseIsOverRightKey then
                if sliderCtrl ~= nil then
                    --sliderCtrl.panel:valueSliderCancel(sliderCtrl)
                    valueSlider_CancelThrottled(sliderCtrl, 50)
                end
                self.editBox:LoseFocus()
                tbug_buildRowContextMenuData(self, row, data, true, mouseIsOverRightKey)
            end
        elseif MouseIsOver(row.cKeyLeft) or mouseIsOverRightKey then
            if sliderCtrl ~= nil then
                --sliderCtrl.panel:valueSliderCancel(sliderCtrl)
                valueSlider_CancelThrottled(sliderCtrl, 50)
            end
            self.editBox:LoseFocus()
            tbug_buildRowContextMenuData(self, row, data, true, mouseIsOverRightKey)
        elseif MouseIsOver(row.cVal1)  then
            if sliderCtrl ~= nil then
                --sliderCtrl.panel:valueSliderCancel(sliderCtrl)
                valueSlider_CancelThrottled(sliderCtrl, 50)
            end
            self.editBox:LoseFocus()
            tbug_buildRowContextMenuData(self, row, data, false, nil)
        else
            if sliderCtrl ~= nil then
                --sliderCtrl.panel:valueSliderCancel(sliderCtrl)
                valueSlider_CancelThrottled(sliderCtrl, 50)
            end
--d(">loosing focus of editbox")
            self.editBox:LoseFocus()
        end
    end
end

function TableInspectorPanel:onRowDoubleClicked(row, data, mouseButton, ctrl, alt, shift)
--df("tbug:TableInspectorPanel:onRowDoubleClicked")
    hideContextMenus()
    if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
        local sliderCtrl = self.sliderControl

        local value = data.value
        local typeValue = type(value)
        if MouseIsOver(row.cVal) then
            if sliderCtrl ~= nil then
                --sliderCtrl.panel:valueSliderCancel(sliderCtrl)
                valueSlider_CancelThrottled(sliderCtrl, 50)
            end
            if self:canEditValue(data) then
                if typeValue == "boolean" then
                    local oldValue = value
                    local newValue = not value
                    data.value = newValue
                    tbug_setEditValueFromContextMenu(self, row, data, oldValue)
                --elseif typeValue == stringType then
                    --[[
                    if value ~= "" and data.dataEntry.typeId == RT.SCRIPTHISTORY_TABLE then
                        --CHAT_SYSTEM.textEntry.system:StartTextEntry("/script " .. data.value)
                        StartChatInput("/tbug " .. value, CHAT_CHANNEL_SAY, nil, false)
                    end
                    ]]
                end
            end
        end
    end
end

function TableInspectorPanel:populateMasterList(editTable, dataType)
--d("[TBUG]populateMasterList - dataType: " .. tos(dataType))

    local masterList, n = self.masterList, 0
    for k, v in next, editTable do
        n = n + 1
        local dataEntry = masterList[n]
        if dataEntry then -- and dataType ~= RT.SCRIPTHISTORY_TABLE then
            dataEntry.typeId = dataType
            dataEntry.data.key = k
            dataEntry.data.value = v
        else
            local data = {key = k, value = v}
            masterList[n] = ZO_ScrollList_CreateDataEntry(dataType, data)
        end
    end
    return tbug_truncate(masterList, n)
end


function TableInspectorPanel:valueEditConfirmed(editBox, evalResult)
    local editData = self.editData
    --d(">editBox.updatedColumnIndex: " .. tos(editBox.updatedColumnIndex))
    local function confirmEditBoxValueChange(p_setIndex, p_editTable, p_key, p_evalResult)
        local l_ok, l_setResult = pcall(p_setIndex, p_editTable, p_key, p_evalResult)
        return l_ok, l_setResult
    end

    if editData then
        local editTable = editData.meta or self.subject
        local updateSpecial = false
        if editBox.updatedColumn ~= nil and editBox.updatedColumnIndex ~= nil then
            updateSpecial = true
        end
        if updateSpecial == false then
            local ok, setResult = confirmEditBoxValueChange(tbug.setindex, editTable, editData.key, evalResult)
            if not ok then return setResult end
            self.editData = nil
            editData.value = setResult
        else
            local typeId = editData.dataEntry.typeId
            --Update script history script or comment
            --[[
            if typeId and typeId == RT.SCRIPTHISTORY_TABLE then
                tbug.changeScriptHistory(editData.dataEntry.data.key, editBox, evalResult) --Use the row's dataEntry.data table for the key or it will be the wrong one after scrolling!
                editBox.updatedColumn:SetHidden(false)
                if evalResult == "" then
                    editBox.updatedColumn:SetText("")
                end
            --TypeId not given or generic
            else
            ]]
            if (not typeId or typeId == RT.GENERIC) then
                local ok, setResult = confirmEditBoxValueChange(tbug.setindex, editTable, editData.key, evalResult)
                if not ok then return setResult end
                self.editData = nil
                editData.value = setResult
            end
        end
        -- refresh only the edited row
        ZO_ScrollList_RefreshVisible(self.list, editData)
    end
    editBox:LoseFocus()
    editBox.updatedColumn = nil
    editBox.updatedColumnIndex = nil
end

function TableInspectorPanel:valueSliderConfirmed(sliderControl, evalResult)
--d("TableInspectorPanel:valueSliderConfirmed-evalResult: "..tostring(evalResult))
    ZO_Tooltips_HideTextTooltip()
    local sliderData = self.sliderData
--d(">sliderControl.updatedColumnIndex: " .. tos(sliderControl.updatedColumnIndex))
    local function confirmSliderCtrlValueChange(p_setIndex, p_sliderTable, p_key, p_evalResult)
        local l_ok, l_setResult = pcall(p_setIndex, p_sliderTable, p_key, p_evalResult)
        return l_ok, l_setResult
    end

    if sliderData then
        local sliderTable = sliderData.meta or self.subject
        local updateSpecial = false
        if sliderData.updatedColumn ~= nil and sliderData.updatedColumnIndex ~= nil then
            updateSpecial = true
        end
        if updateSpecial == false then
            local ok, setResult = confirmSliderCtrlValueChange(tbug.setindex, sliderTable, sliderData.key, tonumber(evalResult))
            if not ok then return setResult end
            self.sliderData = nil
            sliderData.value = setResult
        else
            local typeId = sliderData.dataEntry.typeId
            --TypeId not given or generic
            if (not typeId or typeId == RT.GENERIC) then
                local ok, setResult = confirmSliderCtrlValueChange(tbug.setindex, sliderTable, sliderData.key, tonumber(evalResult))
                if not ok then return setResult end
                self.sliderData = nil
                sliderData.value = setResult
            end
        end
        -- refresh only the changed slider row
        ZO_ScrollList_RefreshVisible(self.list, sliderData)
    end
    sliderControl.updatedColumn = nil
    sliderControl.updatedColumnIndex = nil
end