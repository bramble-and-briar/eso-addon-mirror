--[[------------------------------------------------------------------------------------------------
Title:          Notifications
Author:         Static_Recharge
Description:    Creates and handles the notifications for the add-on.
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local CSA = CENTER_SCREEN_ANNOUNCE
local SSF = StaticsSocialFeatures


--[[------------------------------------------------------------------------------------------------
Notifications Class Initialization
Notifications    										              - Parent object containing all functions, tables, variables, constants and other data managers.
├─ :IsInitialized()                               - Returns true if the object has been successfully initialized.
├─ :Notify(message)															  - Updates the notification settings.
└─ :GetParent()                                   - Returns the parent object of this object for reference to parent variables.
------------------------------------------------------------------------------------------------]]--
local Notifications = {}


--[[------------------------------------------------------------------------------------------------
Notifications.Initialize()
Inputs:				None  
Outputs:			None
Description:	Initializes all of the variables and tables.
------------------------------------------------------------------------------------------------]]--
function Notifications.Initialize()
  local SV = SSF.SV
  Notifications.NotificationHandlers = {
    [SSF.NotificationTypes.List.Chat] = function(message)
      if not message then return end
      SSF.Chat:Msg(message)
      if SV.notificationSound then PlaySound(SV.notificationSound) end
    end,
    [SSF.NotificationTypes.List["Center Screen"]] = function(message)
      local messageParams = CSA:CreateMessageParams(SV.notificationSize, SV.notificationSound)
      messageParams:SetText(message)
      messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_LORE_BOOK_LEARNED)
      CSA:AddMessageWithParams(messageParams)
    end,
    [SSF.NotificationTypes.List.Alert] = function(message)
      ZO_Alert(UI_ALERT_CATEGORY_ALERT, SV.notificationSound, message)
    end,
  }

  Notifications.initialized = true
end


--[[------------------------------------------------------------------------------------------------
Notifications.IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function Notifications.IsInitialized()
  return Notifications.initialized
end


--[[------------------------------------------------------------------------------------------------
Notifications.Notify(message)
Inputs:				message         - The message to post to the correct notify channel 
Outputs:			None
Description:	Updates the notification settings.
------------------------------------------------------------------------------------------------]]--
function Notifications.Notify(message)
  local SV = SSF.SV
  Notifications.NotificationHandlers[SV.notificationType](message)
end


--[[------------------------------------------------------------------------------------------------
Notifications.GetParent()
Inputs:				None
Outputs:			Parent          - The parent object of this object.
Description:	Returns the parent object of this object for reference to parent variables.
------------------------------------------------------------------------------------------------]]--
function Notifications.GetParent()
  return Notifications.Parent
end


--[[------------------------------------------------------------------------------------------------
Global template assignment
------------------------------------------------------------------------------------------------]]--
StaticsSocialFeatures.Notifications = Notifications