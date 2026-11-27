--[[------------------------------------------------------------------------------------------------
Title:					Chat
Author:					Static_Recharge
Description:		Object to manage sending messages to chat with proper wrappers.

Chat                                              - Object containing all functions, tables, variables, constants and other data managers.
├─ :IsInitialized()                               - Returns true if the object has been successfully initialized.
├─ :SetChatEnabled(state)                         - Sets the chat enabled state for the object.
├─ :SetDebugEnabled(state)                        - Sets the debug enabled state for the object.
├─ :Msg(...)                                      - Formats text to be sent to the chat box for the user. Bools, nil and empty strings will be converted to 
│                                                   text formats. All inputs after the first will be placed on a new line within the message.
│                                                   Only the first line gets the add-on prefix.
└─ :Debug(...)                                    - Routes the debug info to the chat method if debugging is on.
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local CS = CHAT_SYSTEM
local LCM = LibChatMessage
local LS = LibStatic


--[[------------------------------------------------------------------------------------------------
Chat Class Initialization
------------------------------------------------------------------------------------------------]]--
local Chat = ZO_InitializingObject:Subclass()


--[[------------------------------------------------------------------------------------------------
Chat:Initialize(Options)
Inputs:				Options                             - Table containing parameters
              ├─ .addonIdentifier                   - (optional) Addon long name
              ├─ .addonShortName                    - (optional) Addon short name
              ├─ .prefixColor                       - (optional) Prefix Hexcode color
              ├─ .textColor                         - (optional) Chat Hexcode color
              ├─ .chatEnabled                       - (optional) bool that enables chat
              └─ .debugEnabled                      - (optional) bool that enables debug
Outputs:			None
Description:	Initializes the object with given inputs.
<<prefixColor>>[<<addonIdentifier>>]: <<textColor>><<message>>
------------------------------------------------------------------------------------------------]]--
function Chat:Initialize(Options)
  if not Options then Options = {} end
  self.prefixColor = Options.prefixColor or "FFFFFF"
  self.addonIdentifier = Options.addonIdentifier or "LibStatic"
  self.textColor = Options.textColor or "FFFFFF"
  self.addonShortName = Options.addonShortName or "LS"
  if Options.chatEnabled == nil then self.chatEnabled = true else self.chatEnabled = Options.chatEnabled end
  if Options.debugEnabled == nil then self.debugEnabled = true else self.debugEnabled = Options.debugEnabled end

  self.Proxy = LCM.Create(self.addonIdentifier, self.addonShortName)

  self.initialized = true
end


--[[------------------------------------------------------------------------------------------------
Chat:IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function Chat:IsInitialized()
  return self.initialized
end


--[[------------------------------------------------------------------------------------------------
Chat:SetChatEnabled(state)
Inputs:				state                               - bool, true to enable chat.
Outputs:			None
Description:	Sets the chat enabled state for the object.
------------------------------------------------------------------------------------------------]]--
function Chat:SetChatEnabled(state)
  self.chatEnabled = state
end


--[[------------------------------------------------------------------------------------------------
Chat:SetDebugEnabled(state)
Inputs:				state                               - bool, true to enable debug.
Outputs:			None
Description:	Sets the debug enabled state for the object.
------------------------------------------------------------------------------------------------]]--
function Chat:SetDebugEnabled(state)
  self.debugEnabled = state
end


--[[------------------------------------------------------------------------------------------------
Chat:Msg(...)
Inputs:				...                                 - Any number of arguments that are strings, numbers or bools to post to chat. Will accept tables of strings
Outputs:			None
Description:	Formats text to be sent to the chat box for the user. Bools, nil and empty strings will be converted to 
							text formats. All inputs after the first will be placed on a new line within the message.
              Only the first line gets the add-on prefix.
------------------------------------------------------------------------------------------------]]--
function Chat:Msg(...)
  if not self.chatEnabled then return end

  local first = true
  local currentTagMode = LCM:GetTagPrefixMode()
  self.Proxy:SetTagColor(self.prefixColor)

  local function sendMsg(input)
    local formatted = zo_strformat("|c<<1>><<2>>|r", self.textColor, input)
    if first then
      self.Proxy:Print(formatted)
      first = false
    else
      LCM:SetTagPrefixMode(LCM.TAG_PREFIX_OFF)
      self.Proxy:Print(formatted)
      LCM:SetTagPrefixMode(currentTagMode)
    end
  end

  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "table" then
      for j, k in ipairs(v) do
        if type(k) ~= "table" then
          sendMsg(LibStatic.StringConvert(k))
        end
      end
    elseif v ~= nil then
      sendMsg(LibStatic.StringConvert(v))
    end
  end
end


--[[------------------------------------------------------------------------------------------------
Chat:Debug(...)
Inputs:				...                                 - Any number of arguments that are strings, numbers or bools to post to chat. Will accept tables of strings
Outputs:			None
Description:	Routes the debug info to the chat method if debugging is on.
------------------------------------------------------------------------------------------------]]--
function Chat:Debug(...)
  -- exit if not enabled
  if not self.debugEnabled then return end

	self:Msg(...)
end


--[[------------------------------------------------------------------------------------------------
Global template assignment
------------------------------------------------------------------------------------------------]]--
LS.CHAT = Chat