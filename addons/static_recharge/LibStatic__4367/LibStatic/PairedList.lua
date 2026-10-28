--[[------------------------------------------------------------------------------------------------
Title:					Paired List
Author:					Static_Recharge
Description:		Object to manage a paired list of choices and values. Mainly for settings menus.
                If no Values table is passed in the object will become an enumerated list instead.

PairedList                                                - Object containing all functions, tables, variables, constants and other data managers.
├─ :IsEnum()                                      - Returns true if the object is an enum list.
├─ :IsInitialized()                               - Returns true if the object has been successfully initialized.
├─ :GetChoices()                                  - Returns the Choices table.
├─ :GetValues()                                   - Returns the Values table.
├─ :GetChoiceByValue(value)                       - Returns the matching choice from the paired list.
├─ :UpdateData(Choices, Values)                   - Updates the Choices and Values tables.
├─ :Sort(sortType)                                - Sorts the paired list by the specified sortType (use globals).
├─ .choice_1 ┐
¦      ¦     ├─                                   - Allows choices to be used directly, good for enums. Ex: PairedList.choice_2
└─ .choice_n ┘
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Globals
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
PairedList Class Initialization
------------------------------------------------------------------------------------------------]]--
local PairedList = ZO_InitializingObject:Subclass()


--[[------------------------------------------------------------------------------------------------
PairedList:Initialize()
Inputs:				Choices                             - Table of choices (enums)
              Values                              - (optional) Table of values
              Translations                        - (optional) Table of translations for the Choices
Outputs:			None
Description:	Initializes the object. If Values table is missing the object will be treated as an enumerated list.
              Once created as an enum that shouldn't be changed. It's better to destroy the object and start over.
------------------------------------------------------------------------------------------------]]--
function PairedList:Initialize(Choices, Values, Translations)
  self.Choices = Choices
  self.Values = Values
  self.isEnum = false

  -- if used as enum
  if self.Values == nil then
    self.Values = {}
    for index, choice in ipairs(self.Choices) do
      table.insert(self.Values, index)
      self[choice] = index
    end
    self.isEnum = true

  -- if not enum
  else
    for index, choice in ipairs(self.Choices) do
      self[choice] = self.Values[index]
    end
  end

  -- Assign Translations or set to "Choices" for compatibility
  if Translations and type(Translations == "table") then
    self.Translations = Translations
  else
    self.Translations = Choices
  end

  self.initialized = true
end


--[[------------------------------------------------------------------------------------------------
PairedList:IsEnum()
Inputs:				None
Outputs:			isEnum                              - bool for object enum state
Description:	Returns true if the object is an enum list.
------------------------------------------------------------------------------------------------]]--
function PairedList:IsEnum()
  return self.isEnum
end


--[[------------------------------------------------------------------------------------------------
PairedList:IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function PairedList:IsInitialized()
  return self.initialized
end


--[[------------------------------------------------------------------------------------------------
PairedList:GetChoices()
Inputs:				None
Outputs:			Choices                             - Table of indexed Choices
Description:	Returns the Choices table.
------------------------------------------------------------------------------------------------]]--
function PairedList:GetChoices()
  return self.Choices
end


--[[------------------------------------------------------------------------------------------------
PairedList:GetValues()
Inputs:				None
Outputs:			Values                              - Table of indexed values
Description:	Returns the Values table.
------------------------------------------------------------------------------------------------]]--
function PairedList:GetValues()
  return self.Values
end


--[[------------------------------------------------------------------------------------------------
PairedList:GetTranslations()
Inputs:				None
Outputs:			Tranlsations                        - Table of indexed Translations
Description:	Returns the Translations table.
------------------------------------------------------------------------------------------------]]--
function PairedList:GetTranslations()
  return self.Translations
end


--[[------------------------------------------------------------------------------------------------
PairedList:GetChoiceByValue(value)
Inputs:				value                               - Value to look up
Outputs:			choice                              - Choice found by value
Description:	Returns the matching choice from the paired list.
------------------------------------------------------------------------------------------------]]--
function PairedList:GetChoiceByValue(value)
  for i, v in ipairs(self.Values) do
    if v == value then
      return self.Choices[i]
    end
  end
end


--[[------------------------------------------------------------------------------------------------
PairedList:UpdateData(Choices, Values, Translations)
Inputs:				Choices                             - Table of choices (enums)
              Values                              - (optional) Table of values
              Translations                        - (optional) Table of translations
Outputs:			None
Description:	Updates the Choices, Values and Translations tables.
------------------------------------------------------------------------------------------------]]--
function PairedList:UpdateData(Choices, Values, Translations)
  -- clear old info
  if Choices ~= nil then
    for index, choice in ipairs(self.Choices) do
      self[choice] = nil
    end
    self.Choices = Choices
  end

  if self.isEnum then
    self.Values = {}
    for index, choice in ipairs(self.Choices) do
      table.insert(self.Values, index)
      self[choice] = index
    end
  else
    if Values ~= nil then
      self.Values = Values
    end
    for index, choice in ipairs(self.Choices) do
      self[choice] = self.Values[index]
    end
  end
  
  -- Assign Translations or set to "Choices" for compatibility
  if Translations and type(Translations == "table") then
    self.Translations = Translations
  else
    self.Translations = Choices
  end
end


--[[------------------------------------------------------------------------------------------------
PairedList:Sort(sortType, sortKey)
Inputs:				sortType                            - how to sort (globals)
              sortKey                             - key to sort by (optional) Default "choice"
Outputs:			None
Description:	Sorts the paired list by the specified sortType (use globals). Defaults to LIBSTATIC_LIST_SORT_ASCENDING
------------------------------------------------------------------------------------------------]]--
function PairedList:Sort(sortType, sortKey)
  -- set default if not specified
  if sortType == nil then sortType = LIBSTATIC_LIST_SORT_ASCENDING end
  
  -- check range
  if sortType < LIBSTATIC_LIST_SORT_MIN or sortType > LIBSTATIC_LIST_SORT_MAX then return end

  -- check sortKey
  if not sortKey then sortKey = "choice" end

  -- merge the lists to sort easy
  local Merged = {}
  for index, choice in ipairs(self.Choices) do
    table.insert(Merged, {choice = choice, value = self.Values[index], translation = self.Translations[index]})
  end

  -- sort the merged list
  LibStatic:Sort(Merged, sortType, sortKey)

  -- unmerge and update data
  local Choices = {}
  local Values = {}
  local Translations = {}
  for index, data in ipairs(Merged) do
    table.insert(Choices, data.choice)
    table.insert(Values, data.value)
    table.insert(Translations, data.translation)
  end
  self:UpdateData(Choices, Values, Translations)
end


--[[------------------------------------------------------------------------------------------------
PairedList:GetSelectedChoicesByValue(values)
Inputs:				values                              - Table of values to pick out
Outputs:			choices                             - Table of selected choices to pick out
Description:	Returns a table of selected choices by given list of values. Suitable for multi select dropdown menu usage.
------------------------------------------------------------------------------------------------]]--
function PairedList:GetSelectedChoicesByValues(values)
  local choices = {}
  for valueIndex, value in ipairs(self.Values) do
    for selectedIndex, selection in ipairs(values) do
      if value == selection then
        table.insert(choices, self.Choices[valueIndex])
        break
      end
    end
  end
  return choices
end


--[[------------------------------------------------------------------------------------------------
PairedList:GetSelectedValuesByChoices(choices)
Inputs:				choices                             - Table of choices to pick out
Outputs:			values                              - Table of selected values to pick out
Description:	Returns a table of selected values by given list of choices. Suitable for multi select dropdown menu usage.
------------------------------------------------------------------------------------------------]]--
function PairedList:GetSelectedValuesByChoices(choices)
  local values = {}
  for choiceIndex, choice in ipairs(self.Choices) do
    for selectedIndex, selection in ipairs(choices) do
      if choice == selection then
        table.insert(values, self.Values[choiceIndex])
        break
      end
    end
  end
  return values
end


--[[------------------------------------------------------------------------------------------------
Global template assignment
------------------------------------------------------------------------------------------------]]--
LibStatic.PAIREDLIST = PairedList