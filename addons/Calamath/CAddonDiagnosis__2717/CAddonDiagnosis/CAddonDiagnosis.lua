--
-- Calamath's Addon Diagnosis [CDIAG]
--
-- Copyright (c) 2020 Calamath
--
-- This software is released under the Artistic License 2.0
-- https://opensource.org/licenses/Artistic-2.0
--

-- ---------------------------------------------------------------------------------------
-- CT_MinimalAddonFramework: Minimal Add-on Framework Template Class            rel.1.1.12
-- ---------------------------------------------------------------------------------------
local CT_MinimalAddonFramework = ZO_Object:Subclass()
function CT_MinimalAddonFramework:New(...)
	local newObject = setmetatable({}, self)
	newObject:Initialize(...)
	newObject:ConfigDebug()
	newObject:OnInitialized(...)
	return newObject
end
function CT_MinimalAddonFramework:Initialize(name, attributes)
	if type(name) ~= "string" or name == "" then return end
	self._name = name
	self._isInitialized = false
	if type(attributes) == "table" then
		for k, v in pairs(attributes) do
			if self[k] == nil then
				self[k] = v
			end
		end
	end
	self._external = {
		name = self.name or self._name, 
		version = self.version, 
		author = self.author, 
	}
	assert(not _G[name], name .. " is already loaded.")
	_G[name] = self._external
	EVENT_MANAGER:RegisterForEvent(self._name, EVENT_ADD_ON_LOADED, function(event, addonName)
		if addonName ~= self._name then return end
		EVENT_MANAGER:UnregisterForEvent(self._name, EVENT_ADD_ON_LOADED)
		self:OnAddOnLoaded(event, addonName)
		self._isInitialized = true
	end)
end
function CT_MinimalAddonFramework:ConfigDebug()
	local Dummy = function() end
	self.LDL = { Verbose = Dummy, Debug = Dummy, Info = Dummy, Warn = Dummy, Error = Dummy, }
	self._isDebugMode = false
end
function CT_MinimalAddonFramework:OnInitialized(name, attributes)
--  Available when overridden in an inherited class
end
function CT_MinimalAddonFramework:OnAddOnLoaded(event, addonName)
--  Should be Overridden
end

-- ---------------------------------------------------------------------------------------
-- Simple Text Buffer Template Class                                             rel.1.0.3
-- ---------------------------------------------------------------------------------------
local CT_SimpleTextBuffer = ZO_InitializingObject:Subclass()
function CT_SimpleTextBuffer:Initialize()
	self.buffer = {}
	self.nextIndex = 1
end
function CT_SimpleTextBuffer:Clear()
	ZO_ClearNumericallyIndexedTable(self.buffer)
	self.nextIndex = 1
end
function CT_SimpleTextBuffer:GetLine(pos)
	return pos and self.buffer[pos]
end
function CT_SimpleTextBuffer:GetNumLines()
	return #self.buffer
end
function CT_SimpleTextBuffer:AddLine(text)
	if text then
		self.buffer[self.nextIndex] = text
		self.nextIndex = self.nextIndex + 1
	end
end
function CT_SimpleTextBuffer:InsertLine(pos, text)
	if text then
		table.insert(self.buffer, pos, text)
		self.nextIndex = self.nextIndex + 1
	end
end
function CT_SimpleTextBuffer:RemoveLine(pos)
	table.remove(self.buffer, pos)
	self.nextIndex = #self.buffer + 1
end
function CT_SimpleTextBuffer:Concat(sep, i, j)
	return table.concat(self.buffer, sep, i, j)
end
function CT_SimpleTextBuffer:ConcatWithinLimit(limit, sep, i, j)
	sep = sep or ""
	i = i or 1
	j = j or #self.buffer

	local sepLength = string.len(sep)
	local count = 0
	local tail = j
	if limit and limit > 0 then
		for pos = i, j do
			count = count + string.len(self.buffer[pos]) + sepLength
			if count > limit then
				tail = pos - 1
				break
			end
		end
	end
	return table.concat(self.buffer, sep, i, tail), tail
end


-- ---------------------------------------------------------------------------------------
-- CAddonDiagnosis
-- ---------------------------------------------------------------------------------------
local CDIAG = CT_MinimalAddonFramework:New("CAddonDiagnosis", {
	name = "CAddonDiagnosis", 
	version = "5.0.5", 
	author = "Calamath", 
	authority = {2973583419,210970542}, 
})

local L = GetString
local am = GetAddOnManager()

local NORMAL_COLOR = "dcdcdc"
local DARK_ORANGE = "ffa500"
local YELLOW = "ffff00"
local RED = "ff0000"
local MAGENTA = "ff00ff"
local LIME = "00ff00"
local CORNFLOWER_BLUE = "6495ed"
local ICON_TEXTURE = {
	["ENABLED"] = "|c00ff00|t100%:100%:esoui/art/miscellaneous/check_icon_32.dds:inheritcolor|t|r", 
	["DISABLED"] = "|cff0000|t80%:80%:esoui/art/castbar/forbiddenaction.dds:inheritcolor|t |r", 
	["ERROR"] = "|cff0000|t100%:100%:esoui/art/miscellaneous/new_icon.dds:inheritcolor|t|r", 
	["ERROR_VERSION"] = "|cff00ff|t100%:100%:esoui/art/miscellaneous/new_icon.dds:inheritcolor|t|r", 
	["MISSING"] = "|cff0000|t100%:100%:esoui/art/miscellaneous/help_icon.dds:inheritcolor|t|r", 
	["LOCKED"] = "|cff0000|t100%:100%:esoui/art/miscellaneous/status_locked.dds:inheritcolor|t|r", 
	["OUTDATED"] = "|cffff00|t100%:100%:esoui/art/miscellaneous/eso_icon_warning.dds:inheritcolor|t|r", 
}

-- ---------------------------------------------------------------------------------------
-- Helper Functions
-- ---------------------------------------------------------------------------------------
local function GetTableElements(tbl)
	local n = 0
	if type(tbl) == "table" then
		for _ in pairs(tbl) do
			n = n + 1
		end
	end
	return n
end

local function GetFilename(filePath)
	if filePath then
		return zo_strmatch(filePath, "[^/]+$")
	end
end

local function GetAddonPath(filePath)
	if filePath then
		return zo_strmatch(filePath, "^/?([^/]+)/")
	end
end

local function GetFileExtension(filename)
	if filename then
		filenameWithoutExt, ext = zo_strmatch(filename, "(.+)%.([^%.]+)$")
		if ext == nil then
			filenameWithoutExt = filename
		end
		return ext, filenameWithoutExt
	end
end

local function GetTableKeyForValue(table, value)
	for k, v in pairs(table) do
		if v == value then 
			return k
		end
	end
	return nil
end

local function Decolorize(str)
	if type(str) == "string" then
		return str:gsub("|[cC]%x%x%x%x%x%x", ""):gsub("|[rR]", "")
	else
		return str
	end
end

local function Colorize(colorDef, str, option)
--	colorDef : ZO_ColorDef object or hexadecimal RGB notation (usually 6 characters, ignoring alpha)
--	str      : string
--	option   : string for specifying feature options [optional]
--				  nil      --> same as ZO_ColorDef:Colorize(), regardless of whether it is colored text or not.
--				 "FILL"    --> fills the entire text with the specified color, including colored text
--				 "DEFAULT" --> passes colored text unchanged and fills only standard color text with specified color
	local rgbHex
	local tbl
	if type(colorDef) == "string" then
		rgbHex = colorDef:match("(%x%x%x%x%x%x)")	-- checking hexadecimal RGB notation
	elseif type(colorDef) == "table" then
		if colorDef.ToHex and colorDef.Colorize then	-- checking ZO_ColorDef
			rgbHex = colorDef:ToHex()
		end
	end
	if rgbHex and type(str) == "string" then
		if option == "FILL" then
			tbl = { "|c", rgbHex, Decolorize(str), "|r" }
		elseif option == "DEFAULT" then
			tbl = { "|c", rgbHex, str:gsub("(|[cC]%x%x%x%x%x%x.-|[rR])", "|r%1|c"..rgbHex), "|r" }
		else
			tbl = { "|c", rgbHex, str, "|r" }
		end
		return table.concat(tbl)
	else
		return str
	end
end

local function RemoveTexture(str)
	if type(str) == "string" then
		return str:gsub("|t[^|]+|t", "")
	else
		return str
	end
end

local cached_pcall = pcall
local pcall = function(callback, ...)
	local status, result = cached_pcall(callback, ...)
	if not status then
--		assert(status, "[CDIAG]ERR: " .. result:match("[^%c]*"):match("[^/]+$") or result)
		CDIAG.LDL:Debug("ERR: %s", result:match("[^%c]*"):match("[^/]+$") or result)
	end
	return status, result
end

local cprint, cprintf
if CHAT_ROUTER then
	cprint = function(text)
		pcall(function(text) CHAT_ROUTER:AddSystemMessage(Colorize(NORMAL_COLOR, tostring(text), "DEFAULT")) end, text)
	end
	cprintf = function(text, ...)
		pcall(function(text, ...) CHAT_ROUTER:AddSystemMessage(Colorize(NORMAL_COLOR, text:format(...), "DEFAULT")) end, text, ...)
	end
else
	cprint = d
	cprintf = df
end

local textBuf = CT_SimpleTextBuffer:New()
local function sprint(text)
	textBuf:AddLine(tostring(text or ""))
end
local function sprintf(text, ...)
	textBuf:AddLine(text:format(...))
end

local function SplitCommandLineArgument(str, maxArg)
-- This function splits the command line arguments and returns the following lua table.
-- maxArg is optional and limits the maximum number of arguments that can be stored. If not specified, all arguments will be stored.
--
-- (1) the arguments separated by spaces are divided and stored in the numeric table.
--    (example) lua string "arg1 arg2 -option=x"  --->  luaTable[1] = "arg1", luaTable[2] = "arg2", luaTable[3] = "-option=x"
--
-- (2) Then, the option specifiers are analyzed and stored in the associative array part of the same lua table.
--     If each argument starts with a minus or a slash, it is considered as an option specifier.
--    (example)  -("option1")=("value")   --->  luaTable["option1"] = "value"
--               /("option2")             --->  luaTable["option2"] = true
--
-- NOTE : when referencing each split argument in a loop, you need to use only the numeric part using ipairs() instead of pairs().
--
	if type(str) == "string" then
		local optionList = {}
		local n = 0
--		local check = function(v) optionList[#optionList + 1] = v end
		local check = function(v)
			local opt, value = v:match("^[-/]([^=]+)%=*(.*)")
			optionList[#optionList + 1] = v
			if opt then
				if value == "" then value = true end
				optionList[opt] = value
			end
		end
		
		str, n = str:gsub("(%S+)", check, maxArg)
		if n > 0 then
			return optionList
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- local db_default = {}
function CDIAG:OnAddOnLoaded()
	self.currentApiVersion = GetAPIVersion()
	self.isOutputDialogInitialized = false
	self.errorFrameBackup = {}

	self.isMasterListCreated = false
	self.requestRebuildMasterList = false
	self.currentLoadOutOfDateAddons = am:GetLoadOutOfDateAddOns()	-- LoadOutOfDateAddons flag when creating master list
	self.masterList = {}

	self.sortedList = {}
	self.sortKeys = {
		["index"]		= {}, 
		["name"]		= {}, 
		["title"]		= { tiebreaker = "index", caseInsensitive = true, }, 
		["author"]		= {}, 
		["enabled"]		= {}, 
		["isLibrary"]	= { tiebreaker = "title", }, 
	}
	self.currentSortKey = "isLibrary"
	self.currentSortOrder = ZO_SORT_ORDER_UP
	self.sortFunction = function(entry1, entry2) return ZO_TableOrderingFunction(entry1, entry2, self.currentSortKey, self.sortKeys, self.currentSortOrder) end
	self.dependencySortFunction = function(entry1, entry2) return ZO_TableOrderingFunction(entry1, entry2, "name", { ["name"] = { caseInsensitive = true, }, }, ZO_SORT_ORDER_UP) end

	self.referencedList = {}
	self.forceDisabledList = {}

--	self.db = ZO_SavedVars:NewAccountWide(self.savedVarsDB, 1, nil, db_default)

	ZO_PreHook(am, "SetAddOnEnabled", function(ADDON_MANAGER_self, addOnIndex, enabled)
		self.LDL:Debug("SetAddOnEnabled : index=%s, enabled=%s", tostring(addOnIndex), tostring(enabled))
		self.requestRebuildMasterList = true
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_FORCE_DISABLED_ADDONS_UPDATED, function(event)
		self.LDL:Debug("ForceDisabledAddOnsUpdated : num=%s", tostring(am:GetNumForceDisabledAddOns()))
		self.requestRebuildMasterList = true
	end)
	self:RegisterMainCommand()
	self:RegisterKeybindsCommand()
	self:RegisterCScriptCommand()
end

-- -------------------------------------------------------------------------------------------------

function CDIAG:InitializeOutputDialog()
	if self.isOutputDialogInitialized then return end
	self.isErrorFrameBorrowed = false
	self.errorFrameBackup = self.errorFrameBackup or {}
	self.errorFrameBackup.dismissKeybindName = ZO_ERROR_FRAME.dismissKeybind and ZO_ERROR_FRAME.dismissKeybind.nameLabel and ZO_ERROR_FRAME.dismissKeybind.nameLabel:GetText()
	self.errorFrameBackup.uiErrorAdvancedView = GetCVar("UIErrorAdvancedView")
	self.errorFrameBackup.suppressErrorDialog = ZO_ERROR_FRAME.suppressErrorDialog

	self.directionalInputActivated = false
	self.verticalMovementController = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_VERTICAL, 10, function()
		return DIRECTIONAL_INPUT:GetY(ZO_DI_LEFT_STICK, ZO_DI_RIGHT_STICK)
	end)

	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
		if self.isErrorFrameBorrowed then
			self:ApplyOutputDialogStyle()
		end
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_LUA_ERROR, function(eventCode, ...)
		if self.isErrorFrameBorrowed then
			ZO_UIErrors_Dismiss()
			ZO_ERROR_FRAME:OnUIError(...)
		end
	end)
	if ZO_ERROR_FRAME.pageSpinner then
		ZO_ERROR_FRAME.pageSpinner:RegisterCallback("OnValueChanged", function()
			if self.isErrorFrameBorrowed then
				self:ApplyOutputDialogStyle()
			end
		end)
	end
	if ZO_ERROR_FRAME.DismissErrors then
		SecurePostHook(ZO_ERROR_FRAME, "DismissErrors", function()
			if self.isErrorFrameBorrowed then
				self:HideOutputDialog()
			end
		end)
	end
	self.isOutputDialogInitialized = true
end

function CDIAG:ShowOutputDialog()
	self:PopulateOutputDialog()
	if not self.directionalInputActivated then
		DIRECTIONAL_INPUT:Activate(self, ZO_ERROR_FRAME.textEditControl)
		self.directionalInputActivated = true
	end
end

function CDIAG:HideOutputDialog()
	if self.directionalInputActivated then
		DIRECTIONAL_INPUT:Deactivate(self)
		self.directionalInputActivated = false
	end
	self:RestoreOutputDialogStyle()
end

function CDIAG:UpdateDirectionalInput()
	local move = self.verticalMovementController:CheckMovement()
	if move ~= MOVEMENT_CONTROLLER_NO_CHANGE then
		local control = ZO_ERROR_FRAME.textEditControl
		local verticalExtents = control:GetScrollExtents()
		if verticalExtents > 0 then
			local deltaY = move == MOVEMENT_CONTROLLER_MOVE_NEXT and 1 or -1
			local nextLine = zo_clamp(control:GetTopLineIndex() + deltaY, 1, verticalExtents + 1)
			control:SetTopLineIndex(nextLine)
		end
	end
end

function CDIAG:PopulateOutputDialog()
	local limitCharacters = ZO_ERROR_FRAME.textEditControl:GetMaxInputChars()
	local context = ""
	local pos = 0

	if not self.isErrorFrameBorrowed then
		self.isErrorFrameBorrowed = true
		self.errorFrameBackup.uiErrorAdvancedView = GetCVar("UIErrorAdvancedView")
		self.errorFrameBackup.suppressErrorDialog = ZO_ERROR_FRAME.suppressErrorDialog
	end
	ZO_ERROR_FRAME.suppressErrorDialog = false
	ZO_ERROR_FRAME:HideErrorFrame()
	SetCVar("UIErrorAdvancedView", "1")
	while(pos < textBuf:GetNumLines()) do
		context, pos = textBuf:ConcatWithinLimit(limitCharacters, "\n", pos + 1)
		ZO_ERROR_FRAME:OnUIError(context)
	end
	ZO_ERROR_FRAME:RefreshPageSpinner()

	self:ApplyOutputDialogStyle()
end

function CDIAG:ApplyOutputDialogStyle()
	-- Set up the dialog title
	if ZO_ERROR_FRAME.titleControl then
		ZO_ERROR_FRAME.titleControl:SetText(self.name)
	end

	-- Always show the dismiss button and rename to the close button
	if ZO_ERROR_FRAME.dismissKeybind then
		ZO_ERROR_FRAME.dismissKeybind:SetHidden(false)
		ZO_ERROR_FRAME.dismissKeybind:SetText(L(SI_DIALOG_CLOSE))
	end

	-- Do not show the suppress button
	if ZO_ERROR_FRAME.suppressKeybind then
		ZO_ERROR_FRAME.suppressKeybind:SetHidden(true)
	end

	-- Do not show the more info button
	if ZO_ERROR_FRAME.moreInfoContainer then
		ZO_ERROR_FRAME.moreInfoContainer:SetHidden(true)
	end

	-- Do not show the reload button
	if ZO_ERROR_FRAME.reloadKeybind then
		ZO_ERROR_FRAME.reloadKeybind:SetHidden(true)
	end

	-- Only show the copy button in advanced mode (and not on consoles)
	if ZO_ERROR_FRAME.copyKeybind then
		ZO_ERROR_FRAME.copyKeybind:SetHidden(IsConsoleUI() or not ZO_ERROR_FRAME.advancedMode)
	end

	-- Do not show the close button on consoles
	if ZO_ERROR_FRAME.closeButton then
		ZO_ERROR_FRAME.closeButton:SetHidden(IsConsoleUI())
	end

	-- Do not show the copy error code button
	if ZO_ERROR_FRAME.copyErrorCodeButton then
		ZO_ERROR_FRAME.copyErrorCodeButton:SetHidden(true)
	end
end

function CDIAG:RestoreOutputDialogStyle()
	
	ZO_ERROR_FRAME.dismissKeybind:SetText(self.errorFrameBackup.dismissKeybindName or L(SI_UI_ERROR_SUPPRESS))
	ZO_ERROR_FRAME.suppressErrorDialog = self.errorFrameBackup.suppressErrorDialog
	SetCVar("UIErrorAdvancedView", self.errorFrameBackup.uiErrorAdvancedView)
	ZO_ERROR_FRAME:RefreshAdvancedMode()
	self.isErrorFrameBorrowed = false
end

-- -------------------------------------------------------------------------------------------------

function CDIAG:GetEntryDataByName(addOnName)
	return self.isMasterListCreated and self.masterList[addOnName or 0]
end

function CDIAG:GetEntryDataByIndex(addOnIndex)
	return self:GetEntryDataByName(self:GetAddOnNameByIndex(addOnIndex))
end

function CDIAG:GetAddOnIndexByName(addOnName)
	local entryData = self:GetEntryDataByName(addOnName)
	return entryData and entryData.index or 0
end

function CDIAG:GetAddOnNameByIndex(addOnIndex)
	return (am:GetAddOnInfo(addOnIndex))
end

function CDIAG:BuildAddonMasterList()
	if self.isMasterListCreated then return end
	local masterList = self.masterList
	local sortedList = self.sortedList
	for i = 1, am:GetNumAddOns() do
		local name, title, author, description, enabled, state, isOutOfDate, isLibrary = am:GetAddOnInfo(i)
        local entryData = {
			index = i, 
			name = Decolorize(name), 
			title = Decolorize(title), 
			author = Decolorize(author), 
			description = Decolorize(description), 
			enabled = enabled, 
			state = state,
			isOutOfDate = isOutOfDate, 
			isLibrary = isLibrary, 
			path = am:GetAddOnRootDirectoryPath(i):gsub("^user:/", ""):gsub("/$", ""), 
			version = am:GetAddOnVersion(i), 
		}

		-- investigating tier1 dependencies
		local numDependencies = am:GetAddOnNumDependencies(i)
		if numDependencies > 0 then
			local dependencies = {}
			for j = 1, numDependencies do
				local dependencyName, exists, active, minVersion, loadedVersion = am:GetAddOnDependencyInfo(i, j)
				local dependencyEntry = {
					name = dependencyName, 
					exists = exists, 
					active = active, 
					minVersion = minVersion, 
					loadedVersion = loadedVersion, 
					error = not (exists and active and (loadedVersion >= minVersion)), 
				}
				dependencies[dependencyName] = dependencyEntry
			end
			entryData.dependencies = dependencies
		end
		masterList[name] = entryData
		sortedList[#sortedList + 1] = entryData
	end
	table.sort(sortedList, self.sortFunction)	-- alphabetical sort by title

	-- making referencedList
	for name, entryData in pairs(self.masterList) do
		if entryData.dependencies then
			for referencedName, _ in pairs(entryData.dependencies) do
				local entries = self.referencedList[referencedName] or {}
				entries[#entries + 1] = name
				self.referencedList[referencedName] = entries
			end
		end
	end

	-- making forceDisabledList
	for i = 1, am:GetNumForceDisabledAddOns() do
		local disabledAddonName, shouldShowNotification = am:GetForceDisabledAddOnInfo(i)
		self.forceDisabledList[i] = disabledAddonName
	end

	self.currentLoadOutOfDateAddons = am:GetLoadOutOfDateAddOns()
	self.isMasterListCreated = true
	self.requestRebuildMasterList = false
	self.LDL:Debug("Add-on master list created")
end

function CDIAG:ConfirmMasterList()
	if not self.isMasterListCreated then
		self:BuildAddonMasterList()
	end
	if self.requestRebuildMasterList or am:GetLoadOutOfDateAddOns() ~= self.currentLoadOutOfDateAddons then
		-- Need to rebuild master list
		ZO_ClearTable(self.masterList)
		ZO_ClearTable(self.sortedList)
		ZO_ClearTable(self.referencedList)
		ZO_ClearTable(self.forceDisabledList)
		self.isMasterListCreated = false
		self:BuildAddonMasterList()
	end
end


function CDIAG:InvestigateNestedDependencies(targetAddOnName)
--	Investigate totalDependencies of target add-on, using depth-first search of dependency tree with pre-order traversal
	local depth = 0
	local totalDependencies = {}
	local verifiedNode = {}
	local appearedNode = {}
	local circularDependencies
	-- circularDependencies is a numeric table that contains 'source' and 'destination' when a circular dependency is found.

	local function TraverseDependencyGraph(addOnName)
		depth = depth + 1
--		self.LDL:Debug("Node[%d] : %s", depth, addOnName)
		local dependencyEdge = self.masterList[addOnName].dependencies
		appearedNode[addOnName] = true
		if dependencyEdge then	-- not leaf
			for edge, dependencies in pairs(dependencyEdge) do
				if appearedNode[edge] then	-- checking a circular dependency to avoid infinite loop
					circularDependencies = circularDependencies or {}
					circularDependencies[#circularDependencies + 1] = { source = addOnName, destination = edge }
				else
					if totalDependencies[edge] then
						-- if matching the registered file, it should update the minimum version requirement if necessary
						if totalDependencies[edge].minVersion < dependencies.minVersion then
							totalDependencies[edge].minVersion = dependencies.minVersion
						end
					else
						totalDependencies[edge] = dependencies
					end
					-- determines the need to investigate nested dependencies.
					if not verifiedNode[edge] and self.masterList[edge] then
						TraverseDependencyGraph(edge)
					end
				end
			end
		end
		verifiedNode[addOnName] = true
		appearedNode[addOnName] = nil
		depth = depth - 1
	end

	self:ConfirmMasterList()
	if type(targetAddOnName) ~= "string" then return end
	if not self.masterList[targetAddOnName] then return end

	TraverseDependencyGraph(targetAddOnName)

	self.LDL:Debug("totalDependencies = %d", GetTableElements(totalDependencies))
	if GetTableElements(totalDependencies) > 0 then
		return totalDependencies, circularDependencies
	end
end

function CDIAG:GetAddonStatusByName(addOnName)
	local entryData = self:GetEntryDataByName(addOnName)
	local status
	if entryData then
		if entryData.enabled then
			if entryData.state == ADDON_STATE_ENABLED then
				if entryData.isOutOfDate then
					status = "OUTDATED"
				else
					status = "ENABLED"
				end
			elseif entryData.state == ADDON_STATE_VERSION_MISMATCH then
				status = "LOCKED"
			else
				status = "ERROR"
			end
		else
			status = "DISABLED"
		end
	else
		status = "MISSING"
	end
	return status
end

function CDIAG:GetAddonStatusByIndex(addOnIndex)
	return self:GetAddonStatusByName(self:GetAddOnNameByIndex(addOnIndex))
end

function CDIAG:DoOutputHelpMessage()
	cprint("(usage) /cdiag [<filename> || <number> || -list || -all || -force][-v]")
	cprint(" <filename> : diagnose the operating environment of the specified add-on")
	cprint(" <number>   : same as above, but specify with the listed index number.")
	cprint(" -list      : list add-ons you have enabled")
	cprint(" -all       : list all add-ons installed (including currently disabled)")
	cprint(" -force     : list force disabled add-ons by the system.")
	cprint(" -v         : an additional option to output result to a dialog box.")
end

do
	-- filter function
	local IsLibrary = function(entryData) return entryData.isLibrary end
	local IsAddOn = function(entryData) return not entryData.isLibrary end
	local IsEnabled = function(entryData) return entryData.enabled end
	local IsDisabled = function(entryData) return not entryData.enabled end
	-- filter functions for valid assortType
	local filterFunctions = {
		["LIB"] = { IsLibrary, }, 
		["ADDON"] = { IsAddOn, }, 
		["ENABLED"] = { IsEnabled, }, 
		["DISABLED"] = { IsDisabled, }, 
		["ENABLED_ADDON"] = { IsEnabled, IsAddOn, }, 
		["DISABLED_ADDON"] = { IsDisabled, IsAddOn, }, 
		["ENABLED_LIB"] = { IsEnabled, IsLibrary, }, 
		["DISABLED_LIB"] = { IsDisabled, IsLibrary, }, 
	}
	function CDIAG:DoOutputAddonsList(assortType, outputGUI)
		local printf = outputGUI and sprintf or cprintf
		self:ConfirmMasterList()
		for visualIndex, entryData in ZO_FilteredNumericallyIndexedTableIterator(self.sortedList, filterFunctions[assortType]) do
			local status = self:GetAddonStatusByIndex(entryData.index)
			printf(" No.%3d : %s%s (Ver.%d) [%s] : %s", entryData.index, outputGUI and "" or ICON_TEXTURE[status] or "", entryData.title, entryData.version, entryData.state, entryData.path)
		end
	end
end

function CDIAG:DoOutputForceDisabledAddonsList(outputGUI)
	local printf = outputGUI and sprintf or cprintf
	self:ConfirmMasterList()
	if #self.forceDisabledList > 0 then	
		for _, name in ipairs(self.forceDisabledList) do
			local entryData = self:GetEntryDataByName(name)
			if entryData then
				local status = self:GetAddonStatusByName(name)
				printf(" No.%3d : %s%s (Ver.%d) [%s] : %s", entryData.index, outputGUI and "" or ICON_TEXTURE[status] or "", name, entryData.version or 0, entryData.state or "FORCE-DISABLED", entryData.path or "")
			end
		end
	else
		printf("no force-disabled add-ons.")
	end
end

function CDIAG:DoOutputAddonInfo(addOnName, outputGUI)
	if type(addOnName) ~= "string" then return end
	local printf = outputGUI and sprintf or cprintf
	local entryData = self:GetEntryDataByName(addOnName)
	local status = self:GetAddonStatusByName(addOnName) or ""
	if entryData then
		printf("%s%s (%s Ver.%d)", outputGUI and "" or ICON_TEXTURE[status] or "", entryData.title, entryData.name, entryData.version)
		if entryData.description and entryData.description ~= "" then
			printf("description: %s", entryData.description)
		end
		printf("file location: %s", entryData.path)
	end
end

function CDIAG:DoOutputDependencies(dependencies, outputGUI)
	local printf = outputGUI and sprintf or cprintf
	dependencies = dependencies or {}
	if type(dependencies) == "table" then
		local numDependencies = GetTableElements(dependencies)
		if numDependencies > 0 then
			local sortedDependencyList = {}
			for _, v in pairs(dependencies) do
				sortedDependencyList[#sortedDependencyList + 1] = v
			end
--			for k, v in pairs(sortedDependencyList) do self.LDL:Debug("%s = %s", tostring(k), tostring(v)) end
			table.sort(sortedDependencyList, self.dependencySortFunction)	-- alphabetical sort by dependency name
--			for k, v in pairs(sortedDependencyList) do self.LDL:Debug("%s = %s", tostring(k), tostring(v)) end
			for _, dependencyEntry in ipairs(sortedDependencyList) do
				local indexString, loadingInfo, reqVersionInfo, status
				local dependencyName = dependencyEntry.name
				local entryData = self:GetEntryDataByName(dependencyName)
				if entryData then
					indexString = string.format("%3d", entryData.index)
					loadingInfo = string.format("using Ver.%d (%s)", dependencyEntry.loadedVersion, entryData.path)
				else
					indexString = Colorize(RED, "???")
					loadingInfo = Colorize(RED, "missing !!")
				end

				if dependencyEntry.minVersion ~= 0 then
					reqVersionInfo = string.format("Ver.%d or later ", dependencyEntry.minVersion)
				else
					reqVersionInfo = ""
				end

				if dependencyEntry.exists then
					status = self:GetAddonStatusByName(dependencyName)
					if dependencyEntry.loadedVersion < dependencyEntry.minVersion then
						status = "ERROR_VERSION"
					end
				else
					status = "MISSING"
				end

--				printf("%s [%s][%s] : minVer=%d, Ver=%d", dependencyEntry.name, tostring(dependencyEntry.exists), tostring(dependencyEntry.active), dependencyEntry.minVersion, dependencyEntry.loadedVersion)	-- for debug
				printf("%sNo.%s : %s  %s-> %s", outputGUI and "" or ICON_TEXTURE[status] or "・", indexString, dependencyName, reqVersionInfo, loadingInfo)
			end
		else
			printf("no dependencies.")
		end
	end
end

function CDIAG:DoDiagnoseAddon(addOnName, outputGUI)
	local print = outputGUI and sprint or cprint
	local printf = outputGUI and sprintf or cprintf
	self:ConfirmMasterList()
	local totalDependencies, circularDependencies = self:InvestigateNestedDependencies(addOnName)

--	for k, v in pairs(totalDependencies) do self.LDL:Debug("totalDependencies : %s", k) end

	printf("Diagnose add-on [%s] ...", addOnName)
	if self.masterList[addOnName] then
		self:DoOutputAddonInfo(addOnName, outputGUI)
		print(Colorize(DARK_ORANGE, "Needed libraries/dependencies :"))
		self:DoOutputDependencies(totalDependencies, outputGUI)
	else
		printf("Error: The add-on [%s] could not found.", addOnName)
	end
end

-- -------------------------------------------------------------------------------------------------

function CDIAG:RegisterDebugCommand()
	if type(SLASH_COMMANDS["/cdiag.debug"]) == "function" then return end
	SLASH_COMMANDS["/cdiag.debug"] = function(arg) if arg ~= "" then self:ConfigDebug({tonumber(arg)}) end end
end

function CDIAG:RegisterTestCommand()
	if type(SLASH_COMMANDS["/cdiag.test"]) == "function" then return end
	SLASH_COMMANDS["/cdiag.test"] = function(arg)
		local optionList = SplitCommandLineArgument(arg) or {}
		if #optionList == 0 then
		-- internal test
			-- output datas
			self:ConfirmMasterList()
--			if self.masterList then self.db.masterList = self.masterList end
--			if self.referencedList then self.db.referencedList = self.referencedList end

			-- test icon textures
			for k, v in pairs(ICON_TEXTURE) do
				cprintf("%s : %s", k, v)
			end

		-- test function Colorize
			local sample = "TEST|CdcdcdcWHITE|Cff0000RED|RDEFAULT COLOR|R"
--			local sample = "TEST|cdcdcdcWHITE|cff0000RED|rDEFAULT COLOR|r"
			cprint(sample)
			cprint(Colorize(CORNFLOWER_BLUE, sample))
			cprint(Colorize(CORNFLOWER_BLUE, sample, "FILL"))
			cprint(Colorize(CORNFLOWER_BLUE, sample, "DEFAULT"))
			cprint(Colorize("#00ff00s", sample))
			cprint(Colorize("#00ff00s", sample, "FILL"))
			cprint(Colorize("#00ff00s", sample, "DEFAULT"))
			cprint(Colorize(nil, sample, "DEFAULT"))
			cprint(Colorize("#dummy00ff00", sample, "DEFAULT"))

		-- test advisory message	
			self.LDL:Verbose("hoge")
			self.LDL:Debug("hoge")
			self.LDL:Info("hoge")
			self.LDL:Warn("hoge")
			self.LDL:Error("hoge")
			return	-- command aborted
		end
	end
end


function CDIAG:RegisterMainCommand()
	if type(SLASH_COMMANDS["/cdiag"]) == "function" then return end
	local function MainCommand(arg)
		local outputGUI = false
		local print = cprint
		local printf = cprintf

		local optionList = SplitCommandLineArgument(arg)
		self:ConfirmMasterList()

--[[
		if optionList then
			self.LDL:Debug("#optionList  = %d", #optionList)
			self.LDL:Debug("in pairs trial")
			for k, v in pairs(optionList) do
				self.LDL:Debug("%s = %s", tostring(k), tostring(v))
			end
			self.LDL:Debug("in ipairs trial")
			for i, v in ipairs(optionList) do
				self.LDL:Debug("%s = %s", tostring(i), tostring(v))
			end
			self.LDL:Debug("trial end...")
		end
]]

--
		cprint(" ")
		cprintf("%s V%s  (API:%d)", Colorize(LIME, self.name), self.version, self.currentApiVersion)
		if IsConsoleUI() or IsGameCoreUI() then
			cprintf(zo_strformat("Add-On Mem Usage: <<1>> MB/<<2>> MB", string.format("%.2f", GetTotalUserAddOnMemoryPoolUsageMB()), GetTotalUserAddOnMemoryPoolCapacityMB()))
		end
		if not optionList then
			self:DoOutputHelpMessage()
			return
		end

		if optionList["v"] or IsConsoleUI() or IsGameCoreUI() then
			self:InitializeOutputDialog()
			outputGUI = true
			print = sprint
			printf = sprintf
		end

		if optionList["debug"] then
			self:RegisterDebugCommand()
			self:RegisterTestCommand()
			return
		end
		if optionList["list"] then
			print(Colorize(DARK_ORANGE, "Enabled add-ons :"))
			self:DoOutputAddonsList("ENABLED_ADDON", outputGUI)
			print(Colorize(DARK_ORANGE, "Enabled libraries :"))
			self:DoOutputAddonsList("ENABLED_LIB", outputGUI)
			return
		end
		if optionList["all"] then
			print(Colorize(DARK_ORANGE, "Installed add-ons :"))
			self:DoOutputAddonsList("ADDON", outputGUI)
			print(Colorize(DARK_ORANGE, "Installed libraries :"))
			self:DoOutputAddonsList("LIB", outputGUI)
			return
		end
		if optionList["force"] then
			print(Colorize(DARK_ORANGE, "Force-Disabled add-ons :"))
			self:DoOutputForceDisabledAddonsList(outputGUI)
			return
		end

		-- decode the first non-option argument from the optionList table
		local firstNonOptionArgument
		for i = 1, #optionList do	-- NOTE : iterate the number of elements in the numeric table part.
			if optionList[i]:match("^[^-/]+") then
				firstNonOptionArgument = optionList[i]
				break
			end
		end
	
		self.LDL:Debug("firstNonOptionArgument = %s", tostring(firstNonOptionArgument))

		-- <filename>
		if self.masterList[firstNonOptionArgument] then
			self:DoDiagnoseAddon(firstNonOptionArgument, outputGUI)
			return
		end
	
		-- <number>
		local indexNumber = tonumber(firstNonOptionArgument)
		if indexNumber and firstNonOptionArgument == string.format("%d", firstNonOptionArgument) then
			self.LDL:Debug("index number found : %d", indexNumber)
			self:DoDiagnoseAddon(self:GetAddOnNameByIndex(indexNumber), outputGUI)
			return
		end

		-- <filename : accepts lowercase and uppercase misspellings>
		local lowercaseFirstNonOptionArgument = zo_strlower(firstNonOptionArgument)
		for k, v in pairs(self.masterList) do
			if zo_strlower(k) == lowercaseFirstNonOptionArgument then
				self:DoDiagnoseAddon(k, outputGUI)
				return
			end
		end

		-- error : specific add-on not found.nt
		cprintf("The specified add-on [%s] could not be found.", firstNonOptionArgument)
		cprint("Please check the add-on filename for spelling mistakes.")
		cprint("You know it is necessary to install add-on files for diagnosis.")
	end

	SLASH_COMMANDS["/cdiag"] = function(arg)
		textBuf:Clear()
		MainCommand(arg)
		if textBuf:GetNumLines() > 0 then
			self:ShowOutputDialog()
		end
	end
end

function CDIAG:RegisterKeybindsCommand()
	if type(SLASH_COMMANDS["/cdiag.keybinds"]) == "function" then return end
	SLASH_COMMANDS["/cdiag.keybinds"] = function(arg)
		cprint(" ")
		cprintf("%s V%s  (API:%d)", Colorize(LIME, CDIAG.name), CDIAG.version, self.currentApiVersion)
		cprint("Diagnose custom keybinds slot ...")
		local numSavedBindings = GetNumSavedKeybindings()
		local maxNumSavedBindings = GetMaxNumSavedKeybindings()
		cprintf("remaining custom keybinds slot: %s / %s", tostring(maxNumSavedBindings - numSavedBindings), tostring(maxNumSavedBindings))
	end
end

do
	local function sEmitMessage(text)
		if text == "" then
			text = "[Empty String]"
		end
		textBuf:AddLine(text)
	end
	local function sEmitTable(t, indent, tableHistory)
		indent = indent or "."
		tableHistory = tableHistory or {}
		for k, v in pairs(t) do
			local vType = type(v)
			local vText = { indent, "(", vType, ")", tostring(k), " = ", tostring(v), }
			sEmitMessage(table.concat(vText))

			if vType == "table" then
				if tableHistory[v] then
					sEmitMessage(indent .. "Avoiding cycle on table...")
				else
					tableHistory[v] = true
					sEmitTable(v, indent .. "  ", tableHistory)
				end
			end
		end
	end
	local function d(...)
		for i = 1, select("#", ...) do
			local value = select(i, ...)
			if type(value) == "table" then
				sEmitTable(value)
			else
				sEmitMessage(tostring(value))
			end
		end
	end
	local function df(formatter, ...)
		return d(formatter:format(...))
	end
	function CDIAG:RegisterCScriptCommand()
		local env = "local d,df=...;"
		if type(SLASH_COMMANDS["/cscript"]) == "function" then return end
		SLASH_COMMANDS["/cscript"] = function(arg)
			local t = { env, arg, }
			self:InitializeOutputDialog()
			textBuf:Clear()
			assert(LoadString(table.concat(t)))(d, df)
			if textBuf:GetNumLines() > 0 then
				self:ShowOutputDialog()
			end
		end
	end
end
