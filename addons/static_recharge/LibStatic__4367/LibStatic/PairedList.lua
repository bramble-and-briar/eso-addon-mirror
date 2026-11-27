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
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local LS = LibStatic


--[[------------------------------------------------------------------------------------------------
PairedList Class Initialization
------------------------------------------------------------------------------------------------]]--
local PairedList = ZO_InitializingObject:Subclass()


--[[------------------------------------------------------------------------------------------------
PairedList:Initialize()
Inputs:				Choices                             - Table of choices (enums)
              Values                              - (optional) Table of values
Outputs:			None
Description:	Initializes the object. If Values table is missing the object will be treated as an enumerated list.
              Once created as an enum that shouldn't be changed. It's better to destroy the object and start over.
------------------------------------------------------------------------------------------------]]--
function PairedList:Initialize(Choices, Values)
  self.Choices = {}
  self.Values = nil
  self.List = {}
  self.isEnum = (Values == nil)

  self:UpdateData(Choices, Values)

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
PairedList:GetChoiceByValue(value)
Inputs:				value                               - Value to look up
Outputs:			choice                              - Choice found by value
Description:	Returns the matching choice from the paired list.
------------------------------------------------------------------------------------------------]]--
function PairedList:GetChoiceByValue(value)
  for i, v in pairs(self.List) do
    if v == value then
      return i
    end
  end
end


--[[------------------------------------------------------------------------------------------------
PairedList:GetValueByChoice(choice)
Inputs:				choice                              - Choice to look up
Outputs:			choice                              - Value found by choice
Description:	Returns the matching value from the paired list.
------------------------------------------------------------------------------------------------]]--
function PairedList:GetValueByChoice(choice)
  return self.List[choice]
end


--[[------------------------------------------------------------------------------------------------
PairedList:UpdateData(Choices, Values)
Inputs:				Choices                             - Table of choices (enums)
              Values                              - (optional) Table of values
Outputs:			None
Description:	Updates the Choices, Values.
------------------------------------------------------------------------------------------------]]--
function PairedList:UpdateData(Choices, Values)
  -- clear old info
  if Choices ~= nil then
    self.List = {}
    self.Choices = ZO_ShallowTableCopy(Choices)
  end

  if self.isEnum then
    self.Values = {}
    for index, choice in ipairs(self.Choices) do
      table.insert(self.Values, index)
      self.List[choice] = index
    end
  else
    if Values ~= nil then
      self.Values = ZO_ShallowTableCopy(Values)
    end
    for index, choice in ipairs(self.Choices) do
      self.List[choice] = self.Values[index]
    end
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
  if sortType == nil then sortType = LIBSTATIC_LIST_SORT_ASCENDING end
  if sortType < LIBSTATIC_LIST_SORT_MIN or sortType > LIBSTATIC_LIST_SORT_MAX then return end
  if not sortKey then sortKey = "choice" end

  -- Build an indexed array of pairs so LS.Sort can sort them
  local tempList = {}
  for index, choice in ipairs(self.Choices) do
    table.insert(tempList, { choice = choice, value = self.Values[index] })
  end

  -- Sort the temporary indexed list
  LS.Sort(tempList, sortType, sortKey)

  -- Unmerge and save back onto self
  local Choices = {}
  local Values = {}
  for index, data in ipairs(tempList) do
    table.insert(Choices, data.choice)
    table.insert(Values, data.value)
  end

  self:UpdateData(Choices, Values)
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
LS.PAIREDLIST = PairedList