--[[------------------------------------------------------------------------------------------------
Title:					LibStatic
Author:					Static_Recharge
Version:				2.2.0
Description:		Static_Recharge common utility functions.

LS                                                - Object containing all functions, tables, variables, constants and other data managers.
├─ .IsInitialized()                               - Returns true if the object has been successfully initialized.
├─ .ReverseTableLookup(data, value)               - Returns the key or nil of the found value.
├─ .StringConvert(input, returnType)              - Returns a string friendly converted input or the input if no change needed.
├─ .PairedListNew(Choices, Values)                - Returns a new PairedList object.
├─ .ChatNew(Options)                              - Returns a new Chat object.
├─ .TimerNew(Options)                             - Returns a new Timer object.
├─ .StringConvert(input, returnType)              - Returns a string friendly converted input or the input if no change needed.
├─ .Sort(list, sortType)                          - Sorts the list by the specified sortType (use globals). Defaults to LIBSTATIC_LIST_SORT_ASCENDING
└─ .Test(...)                                     - For internal add-on testing only.
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local CS = CHAT_SYSTEM
local EM = EVENT_MANAGER


--[[------------------------------------------------------------------------------------------------
Globals
------------------------------------------------------------------------------------------------]]--
-- for use with LibStatic:StringConvert
LIBSTATIC_BOOL_TYPE_MIN = 1
LIBSTATIC_BOOL_TYPE_MAX = 7
LIBSTATIC_BOOL_TYPE_TRUE_FALSE = 1
LIBSTATIC_BOOL_TYPE_POSITIVE_NEGATIVE = 2
LIBSTATIC_BOOL_TYPE_YES_NO = 3
LIBSTATIC_BOOL_TYPE_ON_OFF = 4
LIBSTATIC_BOOL_TYPE_ENABLED_DISABLED = 5
LIBSTATIC_BOOL_TYPE_PLUS_MINUS = 6
LIBSTATIC_BOOL_TYPE_ACTIVE_INACTIVE = 7

-- for use with LibStatic:Sort and PairedList:Sort
LIBSTATIC_LIST_SORT_MIN = 1
LIBSTATIC_LIST_SORT_MAX = 2
LIBSTATIC_LIST_SORT_ASCENDING = 1
LIBSTATIC_LIST_SORT_DESCENDING = 2


--[[------------------------------------------------------------------------------------------------
LibStatic Initialization
LibStatic    - Parent object containing all functions, tables, variables, constants and other data managers.
------------------------------------------------------------------------------------------------]]--
LibStatic = {
  -- Static definitions
	addonName = "LibStatic",
	addonVersion = "2.2.0",
	author = "|cFF0000Static_Recharge|r",
  chatPrefixColor = "FFFFFF",
	chatTextColor = "FFFFFF",
}
local Lib = LibStatic


--[[------------------------------------------------------------------------------------------------
Lib.Initialize()
Inputs:				None
Outputs:			None
Description:	Initializes all of the variables, object managers, slash commands and main event
							callbacks.
------------------------------------------------------------------------------------------------]]--
function Lib.Initialize()
	-- sort functions
  Lib.Sorts = {
    function(a, b) return a < b end,
    function(a, b) return a > b end,
    function(a, b) return a < b end,
    function(a, b) return a > b end,
  }

  -- Module Initialization
  local Options = {
		addonIdentifier = "LibStatic",
    addonShortName = "LS",
		prefixColor = Lib.chatPrefixColor,
		textColor = Lib.chatTextColor,
		chatEnabled = true,
		debugEnabled = false,
	}
	Lib.Chat = Lib.ChatNew(Options)


  SLASH_COMMANDS["/lstest"] = Lib.Test

  Lib.initialized = true
end


--[[------------------------------------------------------------------------------------------------
Lib.IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function Lib.IsInitialized()
  return Lib.initialized
end


--[[------------------------------------------------------------------------------------------------
Lib.ReverseTableLookup(data, search, subKey)
Inputs:				data                                - the table to search
              search                              - the value to search for
              subKey                              - (optional) if provided, will be used as the subKey to search
              min                                 - (optional) index to start at
              max                                 - (optional) index to end at
Outputs:			key                                 - the key for the found value (nillable)
Description:	Returns the key or nil of the found value.
------------------------------------------------------------------------------------------------]]--
function Lib.ReverseTableLookup(data, search, subKey, min, max)
  if subKey then
    if min and max then
      for i = min, max do
        if data[i][subKey] == search then
          return key
        end
      end
    else
      for key, value in ipairs(data) do
        if value[subKey] == search then
          return key
        end
      end
    end
  else
    if min and max then
      for i = min, max do
        if data[i] == search then
          return key
        end
      end
    else
      for key, value in ipairs(data) do
        if value == search then
          return key
        end
      end
    end
  end
end


--[[------------------------------------------------------------------------------------------------
Lib.StringConvert(input, returnType)
Inputs:				input 						                  - input to convert
              returnType                          - (optional) determines the pair of possible return values for bool inputs
Outputs:			string 					                    - string containing the converted input, or the input if no change needed
Description:	Returns a string friendly converted input or the input if no change needed.
------------------------------------------------------------------------------------------------]]--
function Lib.StringConvert(input, returnType)
  -- exit right away if nil with 'nil' text
  if input == nil then return "nil" end
  -- exit right away if empty string with 'empty_string' text
  if input == "" then return "empty_string" end
  -- exit right away if not a bool, return the original value
	if type(input) ~= "boolean" then return input end

  -- list of possible responses
  local Responses = {
    {"true", "false"},
    {"positive", "negative"},
    {"yes", "no"},
    {"on", "off"},
    {"enabled", "disabled"},
    {"+", "-"},
    {"active", "inactive"},
  }

  -- set default if no return type specified
  if not returnType or returnType < LIBSTATIC_BOOL_TYPE_MIN or returnType > LIBSTATIC_BOOL_TYPE_MAX then
    returnType = LIBSTATIC_BOOL_TYPE_TRUE_FALSE
  end

  -- if true
  if input then
    return Responses[returnType][1]
  -- if false
  else
    return Responses[returnType][2]
  end
end


--[[------------------------------------------------------------------------------------------------
Lib.Sort(list, sortType, sortKey)
Inputs:				list                                - the list to sort
              sortType                            - how to sort (globals)
              sortKey                             - key to sort by (optional)
Outputs:			None
Description:	Sorts the list by the specified sortType (use globals). Defaults to LIBSTATIC_LIST_SORT_ASCENDING
------------------------------------------------------------------------------------------------]]--
function Lib.Sort(list, sortType, sortKey)
  -- set default if not specified
  if sortType == nil then sortType = LIBSTATIC_LIST_SORT_ASCENDING end
  
  -- check range
  if sortType < LIBSTATIC_LIST_SORT_MIN or sortType > LIBSTATIC_LIST_SORT_MAX then 
    Lib.Chat:Msg("Sort type out of range.")
    return
  end

  -- sort the list
  if sortKey then
    table.sort(list, function(a, b)
      return Lib.Sorts[sortType](a[sortKey], b[sortKey])
    end)
  else
    table.sort(list, Lib.Sorts[sortType])
  end
end


--[[------------------------------------------------------------------------------------------------
Lib.TimerNew(Options)
Inputs:				Options                             - Table containing all of the options
                                                    - uniqueName
                                                    - (optional) timerType
                                                    - (optional) updateInterval (global)
                                                    - duration (ms)
                                                    - (optional) updateCallback(uniqueName, accumulator)
                                                    - (optional) finishedCallback(uniqueName)
Outputs:			Timer                                  - New timer object
Description:	Initializes the object with given inputs.
------------------------------------------------------------------------------------------------]]--
function Lib.TimerNew(Options)
  return Lib.TIMER:New(Options)
end


--[[------------------------------------------------------------------------------------------------
Lib.ChatNew(Options)
Inputs:				Options                             - Table containing parameters
              ├─ .addonIdentifier                   - (optional) addonIdentifier
              ├─ .prefixColor                       - (optional) Prefix Hexcode color
              ├─ .textColor                         - (optional) Chat Hexcode color
              ├─ .chatEnabled                       - (optional) bool that enables chat
              └─ .debugEnabled                      - (optional) bool that enables debug
Outputs:			Chat                                  - New chat object
Description:	Initializes the object with given inputs.
<<prefixColor>>[<<addonIdentifier>>]: <<textColor>><<message>>
------------------------------------------------------------------------------------------------]]--
function Lib.ChatNew(Options)
  return Lib.CHAT:New(Options)
end


--[[------------------------------------------------------------------------------------------------
Lib.PairedListNew(Choices, Values)
Inputs:				Choices                             - Table of choices (enums)
              Values                              - (optional) Table of values
Outputs:			PairedList                          - New paired list object
Description:	Initializes the object with given inputs.
------------------------------------------------------------------------------------------------]]--
function Lib.PairedListNew(Choices, Values)
  return Lib.PAIREDLIST:New(Choices, Values)
end


--[[------------------------------------------------------------------------------------------------
Lib.Test(...)
Inputs:				...							                    - Various test inputs
Outputs:			...                                 - Various test outputs
Description:	For internal add-on testing only.
------------------------------------------------------------------------------------------------]]--
function Lib.Test(...)
  Lib.Chat:Msg(
    "Test Cases:",
    "Empty String:",
    "",
    "Bool(T):",
    true,
    "Bool(F):",
    false,
    "Number:",
    5,
    "String:",
    "test string",
    {
      "Table Test:",
      "Empty String:",
      "",
      "Bool(T):",
      true,
      "Bool(F):",
      false,
      "Number:",
      5,
      "String:",
      "test string",
    }
  )
end


--[[------------------------------------------------------------------------------------------------
Main add-on event registration.
------------------------------------------------------------------------------------------------]]--
EM:RegisterForEvent(Lib.addonName, EVENT_ADD_ON_LOADED, function(eventCode, addonName)
	if addonName ~= Lib.addonName then return end
	EM:UnregisterForEvent(Lib.addonName, EVENT_ADD_ON_LOADED)
	Lib.Initialize()
end)