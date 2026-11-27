--[[------------------------------------------------------------------------------------------------
Title:          Status
Author:         Static_Recharge
Description:    Controls the AFK and Offline timer and features
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local EM = EVENT_MANAGER
local SSF = StaticsSocialFeatures


--[[------------------------------------------------------------------------------------------------
Status Class Initialization
Status    													              - Parent object containing all functions, tables, variables, constants and other data managers.
├─ :IsInitialized()                               - Returns true if the object has been successfully initialized.
├─ :PlayerIdle()															    - Checks if the player is idle and updates the timer accordingly.
├─ :StartAFKTimerAgain()                					- Used to re-enable the afk timer from external code
├─ :OfflineTimerUpdate()               						- Checks if the offline timer end has been reached if enabled.
├─ :OnPlayerActivated(eventCode, initial)					- Fired when the player character is available after loading screens such as changing 
│                                                   zones, reloadui and logging in. Sets the desired player Status for the logged in
│                                                   character, if not disabled.
├─ :OnEventChatMessageChannel(eventCode, channelType, fromName, text, isCustomerService, fromDisplayName)
│                                     						- Fired when there is a chat message. Checking for outgoing whispers and notifying if needed.
└─ :GetParent()                                   - Returns the parent object of this object for reference to parent variables.
------------------------------------------------------------------------------------------------]]--
local Status = {}


--[[------------------------------------------------------------------------------------------------
Status.Initialize()
Inputs:				None  
Outputs:			None
Description:	Initializes all of the variables and tables.
------------------------------------------------------------------------------------------------]]--
function Status.Initialize()
  Status.afkEventSpace = "SSFAFKTimer"
  Status.offlineEventSpace = "SSFOfflineTimer"
  Status.eventSpace = "SSFStatus"
  Status.updateInterval = 1000 -- ms
  Status.afkAccumulator = 0 -- s

  local afkEnabled = SSF.SV.afkTimerEnabled
  local offlineEnabled = SSF.SV.offlineTimerEnabled

  if afkEnabled then
    EM:RegisterForUpdate(Status.afkEventSpace, Status.updateInterval, Status.PlayerIdle)
  end

  if offlineEnabled then
    -- wait for character to load in before timing
    EM:RegisterForEvent(Status.offlineEventSpace, EVENT_PLAYER_ACTIVATED, function(eventCode, initial)
      if initial then
        SSF.SV.offlineTimerEnd = os.clock() + (SSF.SV.offlineTimeout * 60)
      end
      EM:RegisterForUpdate(Status.offlineEventSpace, Status.updateInterval, Status.OfflineTimerUpdate)
      EM:UnregisterForEvent(Status.offlineEventSpace, EVENT_PLAYER_ACTIVATED)
    end)
  end

  EM:RegisterForEvent(Status.eventSpace, EVENT_PLAYER_ACTIVATED, Status.OnPlayerActivated)
  EM:RegisterForEvent(Status.eventSpace, EVENT_CHAT_MESSAGE_CHANNEL, Status.OnEventChatMessageChannel)

  Status.initialized = true
end


--[[------------------------------------------------------------------------------------------------
Status.IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function Status.IsInitialized()
  return Status.initialized
end


--[[------------------------------------------------------------------------------------------------
Status.PlayerIdle()
Inputs:				None  
Outputs:			None
Description:	Checks if the player is idle and updates the timer accordingly.
------------------------------------------------------------------------------------------------]]--
function Status.PlayerIdle()
  local afkEnabled = SSF.SV.afkTimerEnabled
  local afkNotice = SSF.SV.afkNotice
  -- Unregister timer and quit if setting changed since last update.
  if not afkEnabled then
    Status.afkAccumulator = 0
    EM:UnregisterForUpdate(Status.afkEventSpace)
    return
  end

  -- if even one of these evaluate to true then the player is busy.
  -- All have to be false for the player to be idle
	if (not ArePlayerWeaponsSheathed())
		or GetInteractionType() ~= 0
		or GetUnitStealthState("player") ~= 0
		or IsBlockActive()
		or (IsGameCameraUIModeActive() and DoesGameHaveFocus())
		or IsInteracting()
		or IsInteractionPending()
		or IsLooting()
		or IsMounted()
		or IsPlayerInteractingWithObject()
		or IsPlayerMoving()
		or IsPlayerStunned()
		or IsPlayerTryingToMove()
		or IsUnitDeadOrReincarnating("player")
		or IsUnitInCombat("player")
		or IsUnitSwimming("player")
	then
		Status.afkAccumulator = 0
    if GetPlayerStatus() == SSF.PlayerStatus.List.Away then
      SelectPlayerStatus(SSF.PlayerStatus.List.Online)
      if afkNotice then SSF.Notifications.Notify("Switched to Online.") end
    end
  else
    Status.afkAccumulator = Status.afkAccumulator + 1
    if Status.afkAccumulator >= SSF.SV.afkTimeout and GetPlayerStatus() == SSF.PlayerStatus.List.Online then
      SelectPlayerStatus(SSF.PlayerStatus.List.Away)
      if afkNotice then SSF.Notifications.Notify("Switched to AFK.") end
    end
  end
end


--[[------------------------------------------------------------------------------------------------
Status.StartAFKTimerAgain()
Inputs:				None
Outputs:			None
Description:	Used to re-enable the afk timer from external code
------------------------------------------------------------------------------------------------]]--
function Status.StartAFKTimerAgain()
  Status.afkAccumulator = 0
  EM:RegisterForUpdate(Status.afkEventSpace, Status.updateInterval, Status.PlayerIdle)
end


--[[------------------------------------------------------------------------------------------------
Status.OfflineTimerUpdate()
Inputs:				None  
Outputs:			None
Description:	Checks if the offline timer end has been reached if enabled.
------------------------------------------------------------------------------------------------]]--
function Status.OfflineTimerUpdate()
  local time = os.clock()
  local offlineEnabled = SSF.SV.offlineTimerEnabled
  -- unregister if they already switched to online or if they disabled it.
  if not offlineEnabled or GetPlayerStatus() == SSF.PlayerStatus.List.Online then
    EM:UnregisterForUpdate(Status.offlineEventSpace)
  end
  if time >= SSF.SV.offlineTimerEnd and GetPlayerStatus() == SSF.PlayerStatus.List.Offline then    
    SelectPlayerStatus(SSF.PlayerStatus.List.Online)
    if SSF.SV.offlineTimerNotice then SSF.Notifications.Notify("Automatically set to Online.") end
  end
end


--[[------------------------------------------------------------------------------------------------
Status.OnPlayerActivated(eventCode, initial)
Inputs:				eventCode				- Internal ZOS event code, not used here.
							initial					- Indicates if this is the first activation from log-in.
Outputs:			None
Description:	Fired when the player character is available after loading screens such as changing 
							zones, reloadui and logging in. Sets the desired player Status for the logged in
							character, if not disabled.
------------------------------------------------------------------------------------------------]]--
function Status.OnPlayerActivated(eventCode, initial)
	SSF.Chat:Debug("OnPlayerActivated event fired.")
	SSF.Chat:Debug(zo_strformat("Player Status is <<1>>", GetPlayerStatus()))
	if initial then
		if SSF.initialized then SSF.Chat:Debug("Initialized.") end
		local i = SSF.GetCharacterIndex()
		SSF.Chat:Debug(zo_strformat("Character \"<<1>>\" (<<2>>) loaded.", SSF.SV.Characters[i].name, SSF.SV.Characters[i].id))
		if SSF.SV.accountOverrideEnabled and SSF.SV.accountOverrideLogin then
			SelectPlayerStatus(SSF.SV.accountOverride)
			SSF.Chat:Debug(zo_strformat("Player Status set to <<1>>", SSF.SV.accountOverride))
		elseif
			SSF.SV.Characters[i].charOverride ~= SSF.PlayerStatus.List.Disabled and SSF.SV.Characters[i].charOverrideLogin then
			SelectPlayerStatus(SSF.SV.Characters[i].charOverride)
			SSF.Chat:Debug(zo_strformat("Player Status set to <<1>>", SSF.SV.Characters[i].charOverride))
		end
		if SSF.SV.offlineNotice and GetPlayerStatus() == SSF.PlayerStatus.List.Offline then
			SSF.Notifications.Notify("You are set to offline.")
		end
	end
	EM:UnregisterForEvent(Status.eventSpace, EVENT_PLAYER_ACTIVATED)
end


--[[------------------------------------------------------------------------------------------------
Status.OnEventChatMessageChannel(eventCode, channelType, fromName, text, isCustomerService, fromDisplayName)
Inputs:				eventCode				- Internal ZOS event code, not used here.
							channelType			- Global Constant channelType (using CHAT_CHANNEL_WHISPER_SENT)
							fromName  			- Character name of the sender
							text 						- body of the message
							isCustomerService- boolean if the message is from customer service
							fromDisplayName	- @name of the sender
Outputs:			None
Description:	Fired when there is a chat message. Checking for outgoing whispers and notifying if
							needed.
------------------------------------------------------------------------------------------------]]--
function Status.OnEventChatMessageChannel(eventCode, channelType, fromName, text, isCustomerService, fromDisplayName)
	if channelType ~= CHAT_CHANNEL_WHISPER_SENT then return end
	SSF.Chat:Debug("OnEventChatMessageChannel event fired.")
	if GetPlayerStatus() == SSF.PlayerStatus.List.Offline and SSF.SV.whisperNotice then
		SSF.Notifications.Notify("You are set to offline and cannot receive replies to whispers.")
	end
end


--[[------------------------------------------------------------------------------------------------
Global template assignment
------------------------------------------------------------------------------------------------]]--
StaticsSocialFeatures.Status = Status