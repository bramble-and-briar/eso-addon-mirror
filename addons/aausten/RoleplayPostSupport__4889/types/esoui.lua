---@meta

-- Editor-only declarations for the ESOUI API used by this add-on.
-- Never add this file to the ESO manifest or execute it as a runtime shim.
-- API 101050 references and scope are documented in types/README.md.

---@param enabled boolean
function SetGameCameraUIMode(enabled) end

---@param name string
---@param text string
function ZO_CreateStringId(name, text) end

---@param stringId integer
---@param version integer
function SafeAddVersion(stringId, version) end

---@param stringId integer
---@param text string
---@param version integer
function SafeAddString(stringId, text, version) end

---@param stringId integer
---@return string
function GetString(stringId) end

---@alias AnchorPosition integer
---@alias ControlType integer

---@type AnchorPosition
TOPLEFT = nil
---@type AnchorPosition
BOTTOMRIGHT = nil
---@type AnchorPosition
TOP = nil
---@type AnchorPosition
CENTER = nil
---@type ControlType
CT_LABEL = nil
---@type ControlType
CT_CONTROL = nil
---@type ControlType
CT_BUTTON = nil
---@type ControlType
CT_BACKDROP = nil
---@type integer
MOUSE_BUTTON_INDEX_LEFT = nil
---@type integer
TEXT_ALIGN_RIGHT = nil

---@type integer
EVENT_ADD_ON_LOADED = nil
---@type integer
EVENT_PLAYER_ACTIVATED = nil
---@type integer
EVENT_PLAYER_DEACTIVATED = nil
---@type integer
EVENT_CHAT_MESSAGE_CHANNEL = nil

---@class Control
local Control = {}

---@param point AnchorPosition
---@param relativeTo? Control
---@param relativePoint? AnchorPosition
---@param offsetX? number
---@param offsetY? number
function Control:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY) end

---@param width number
---@param height number
function Control:SetDimensions(width, height) end

---@param anchorTargetControl Control
function Control:SetAnchorFill(anchorTargetControl) end

---@param clamped boolean
function Control:SetClampedToScreen(clamped) end

---@param movable boolean
function Control:SetMovable(movable) end

---@return boolean isMoving
function Control:StartMoving() end

function Control:StopMovingOrResizing() end

---@return number
function Control:GetLeft() end

---@return number
function Control:GetTop() end

---@param hidden boolean
function Control:SetHidden(hidden) end

---@param enabled boolean
function Control:SetMouseEnabled(enabled) end

---@return boolean
function Control:IsHidden() end

---@param handlerName string
---@param handler function|nil
---@param namespace? string
function Control:SetHandler(handlerName, handler, namespace) end

---@class TooltipControl: Control
---@type TooltipControl
InformationTooltip = nil

---@param tooltip TooltipControl
---@param owner Control
---@param point AnchorPosition
---@param offsetX? number
---@param offsetY? number
---@param relativePoint? AnchorPosition
function InitializeTooltip(tooltip, owner, point, offsetX, offsetY, relativePoint) end

---@param tooltip TooltipControl
---@param text string
function SetTooltipText(tooltip, text) end

---@param tooltip TooltipControl
function ClearTooltip(tooltip) end

---@class LabelControl: Control
local LabelControl = {}

---@param font string
function LabelControl:SetFont(font) end

---@param alignment integer
function LabelControl:SetHorizontalAlignment(alignment) end

---@param r number
---@param g number
---@param b number
---@param a number
function LabelControl:SetColor(r, g, b, a) end

---@param text string
function LabelControl:SetText(text) end

---@return string
function LabelControl:GetText() end

---@class ButtonControl: Control
local ButtonControl = {}

---@param font string
function ButtonControl:SetFont(font) end

---@param text string
function ButtonControl:SetText(text) end

---@param enabled boolean
function ButtonControl:SetEnabled(enabled) end

---@class EditControl: Control
local EditControl = {}

---@param font string
function EditControl:SetFont(font) end

---@param text string
---@param suppressCallbackHandler? boolean
function EditControl:SetText(text, suppressCallbackHandler) end

---@return string
function EditControl:GetText() end

---@param maxChars integer
function EditControl:SetMaxInputChars(maxChars) end

---@return integer
function EditControl:GetMaxInputChars() end

---@param enabled boolean
function EditControl:SetNewLineEnabled(enabled) end

---@return integer
function EditControl:GetScrollExtents() end

---@param index integer
function EditControl:SetTopLineIndex(index) end

function EditControl:LoseFocus() end

---@param multiline boolean
function EditControl:SetMultiLine(multiline) end

---@param enabled boolean
function EditControl:SetEditEnabled(enabled) end

---@class ComboBoxItem
---@field name string
---@field callback? fun(comboBox: ComboBox, itemName: string, item: ComboBoxItem, selectionChanged: boolean, oldItem: ComboBoxItem|nil)
---@field enabled boolean

---@class ComboBox
local ComboBox = {}

---@param font string
function ComboBox:SetFont(font) end

---@param sortsItems boolean
function ComboBox:SetSortsItems(sortsItems) end

---@param name string
---@param callback fun(comboBox: ComboBox, itemName: string, item: ComboBoxItem, selectionChanged: boolean, oldItem: ComboBoxItem|nil)
---@param enabled? boolean
---@return ComboBoxItem
function ComboBox:CreateItemEntry(name, callback, enabled) end

---@param item ComboBoxItem
---@param updateOptions? integer
function ComboBox:AddItem(item, updateOptions) end

---@param index integer
---@param ignoreCallback? boolean
---@return boolean|nil
function ComboBox:SelectItemByIndex(index, ignoreCallback) end

---@param text string
function ComboBox:SetSelectedItemText(text) end

---@param enabled boolean
function ComboBox:SetEnabled(enabled) end

---@param container Control
---@return ComboBox
function ZO_ComboBox_ObjectFromContainer(container) end

---@class BackdropControl: Control
---@class TopLevelControl: Control

---@type Control
GuiRoot = nil

---@class WindowManager
WINDOW_MANAGER = {}

---@param name string
---@return TopLevelControl
function WINDOW_MANAGER:CreateTopLevelWindow(name) end

---@return boolean
function WINDOW_MANAGER:IsHandlingHardwareEvent() end

---@param name string
---@param parent Control
---@param controlType ControlType
---@return Control
function WINDOW_MANAGER:CreateControl(name, parent, controlType) end

---@param name string
---@param parent Control
---@param templateName string
---@param suffix? string|integer
---@return Control
---@overload fun(self: WindowManager, name: string, parent: Control, templateName: 'ZO_DefaultButton'): ButtonControl
---@overload fun(self: WindowManager, name: string, parent: Control, templateName: 'ZO_EditBackdrop'): BackdropControl
---@overload fun(self: WindowManager, name: string, parent: Control, templateName: 'ZO_DefaultEditForBackdrop'): EditControl
---@overload fun(self: WindowManager, name: string, parent: Control, templateName: 'ZO_DefaultEditMultiLineForBackdrop'): EditControl
---@overload fun(self: WindowManager, name: string, parent: Control, templateName: 'ZO_SingleLineEditBackdrop_Keyboard'): BackdropControl
---@overload fun(self: WindowManager, name: string, parent: Control, templateName: 'ZO_MultiLineEditBackdrop_Keyboard'): BackdropControl
function WINDOW_MANAGER:CreateControlFromVirtual(name, parent, templateName, suffix) end

---@class EventManager
EVENT_MANAGER = {}

---@param namespace string
---@param eventId integer
---@param callback fun(eventCode: integer, ...: any)
---@return boolean
function EVENT_MANAGER:RegisterForEvent(namespace, eventId, callback) end

---@param namespace string
---@param eventId integer
---@return boolean
function EVENT_MANAGER:UnregisterForEvent(namespace, eventId) end

---@class ZO_SavedVars
ZO_SavedVars = {}

-- ESO supplies a saved-variable accessor that exposes the defaults' fields.
---@generic T: table
---@param savedVariableTable string
---@param version integer
---@param namespace string|nil
---@param defaults T
---@param profile? string
---@param displayName? string
---@return T
function ZO_SavedVars:NewAccountWide(savedVariableTable, version, namespace, defaults, profile, displayName) end

---@param stringId string
---@param stringValue string
function ZO_CreateStringId(stringId, stringValue) end

---@return integer
function GetAPIVersion() end

---@return integer
function GetGroupSize() end

---@param index integer
---@return string
function GetGroupUnitTagByIndex(index) end

---@param unitTag string
---@return string
function GetUnitDisplayName(unitTag) end

---@return string
function GetCurrentCharacterId() end

---@param unitTag string
---@return string
function GetUnitName(unitTag) end

---@type table<string, fun(arguments: string)>
SLASH_COMMANDS = {}

---@param ... any
function d(...) end

---@return string
function GetDisplayName() end

---@return string
function GetWorldName() end

---@return integer
function GetFrameTimeMilliseconds() end

---@return integer
function GetTimeStamp() end

---@return boolean
function IsInGamepadPreferredMode() end

---@param active boolean
function SetGameCameraUIMode(active) end

---@param formatString string|integer
---@param ... string|number
---@return string
function zo_strformat(formatString, ...) end

---@param callback fun(id: integer)
---@param milliseconds number
---@return integer id
function zo_callLater(callback, milliseconds) end

---@param targetTable table
---@param functionName string
---@param hookingFunction function
function SecurePostHook(targetTable, functionName, hookingFunction) end

-- A truthy hook result suppresses the original function; observers return nil/false.
---@param objectTable table
---@param existingFunctionName string
---@param hookFunction function
---@return function|nil originalFunction
---@overload fun(existingFunctionName: string, hookFunction: function): function|nil
function ZO_PreHook(objectTable, existingFunctionName, hookFunction) end

---@alias ChannelType integer

---@type ChannelType
CHAT_CHANNEL_SAY = nil
---@type ChannelType
CHAT_CHANNEL_YELL = nil
---@type ChannelType
CHAT_CHANNEL_EMOTE = nil
---@type ChannelType
CHAT_CHANNEL_PARTY = nil
---@type ChannelType
CHAT_CHANNEL_ZONE = nil
---@type ChannelType
CHAT_CHANNEL_WHISPER = nil
---@type ChannelType
CHAT_CHANNEL_WHISPER_SENT = nil
---@type ChannelType
CHAT_CHANNEL_GUILD_1 = nil
---@type ChannelType
CHAT_CHANNEL_GUILD_2 = nil
---@type ChannelType
CHAT_CHANNEL_GUILD_3 = nil
---@type ChannelType
CHAT_CHANNEL_GUILD_4 = nil
---@type ChannelType
CHAT_CHANNEL_GUILD_5 = nil
---@type ChannelType
CHAT_CHANNEL_OFFICER_1 = nil
---@type ChannelType
CHAT_CHANNEL_OFFICER_2 = nil
---@type ChannelType
CHAT_CHANNEL_OFFICER_3 = nil
---@type ChannelType
CHAT_CHANNEL_OFFICER_4 = nil
---@type ChannelType
CHAT_CHANNEL_OFFICER_5 = nil
---@type ChannelType
CHAT_CHANNEL_ZONE_LANGUAGE_1 = nil
---@type ChannelType
CHAT_CHANNEL_ZONE_LANGUAGE_2 = nil
---@type ChannelType
CHAT_CHANNEL_ZONE_LANGUAGE_3 = nil
---@type ChannelType
CHAT_CHANNEL_ZONE_LANGUAGE_4 = nil
---@type ChannelType
CHAT_CHANNEL_ZONE_LANGUAGE_5 = nil
---@type ChannelType
CHAT_CHANNEL_ZONE_LANGUAGE_6 = nil
---@type ChannelType
CHAT_CHANNEL_ZONE_LANGUAGE_7 = nil

-- Read the client's value; do not bake a numeric limit into editor bindings.
---@type integer
MAX_TEXT_CHAT_INPUT_CHARACTERS = nil

---@class ESOChatChannelInfo
---@field requires? fun(channel: ChannelType): boolean

---@return table<ChannelType, ESOChatChannelInfo>
function ZO_ChatSystem_GetChannelInfo() end

-- The stock TextEntry object wraps an edit control; it is not itself a control.
---@class ESOChatTextEntry
local ESOChatTextEntry = {}

---@return EditControl
function ESOChatTextEntry:GetEditControl() end

---@return string
function ESOChatTextEntry:GetText() end

---@return boolean
function ESOChatTextEntry:IsOpen() end

---@param keepText? boolean
function ESOChatTextEntry:Close(keepText) end

---@param text string
function ESOChatTextEntry:AddCommandHistory(text) end

---@class ESOChatSystem
---@field textEntry ESOChatTextEntry
---@field currentChannel ChannelType|nil
---@field currentTarget string|nil
local ESOChatSystem = {}

---@param text? string
---@param channel? ChannelType
---@param target? string
---@param dontShowHUDWindow? boolean
function ESOChatSystem:StartTextEntry(text, channel, target, dontShowHUDWindow) end

---@param keepText? boolean
function ESOChatSystem:CloseTextEntry(keepText) end

---@param newChannel? ChannelType
---@param channelTarget? string
function ESOChatSystem:SetChannel(newChannel, channelTarget) end

-- Declared for hook observation, not as an add-on send API.
function ESOChatSystem:SubmitTextEntry() end

-- The active keyboard/gamepad system is available after the player UI initializes.
---@return ESOChatSystem
function ZO_GetChatSystem() end

-- Prepares native input only. It has no success return value and does not send.
---@param text? string
---@param channel? ChannelType
---@param target? string
function StartChatInput(text, channel, target) end
