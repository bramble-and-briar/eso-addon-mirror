local addon = BureauOfPrivateDispatches
local ADDON_NAME = addon.name
local SAVED_VARIABLES_NAME = addon.savedVariablesName
local SAVED_VARIABLES_VERSION = addon.savedVariablesVersion

local EVENT_NAMESPACE_LOAD = ADDON_NAME
local EVENT_NAMESPACE_CHAT = ADDON_NAME .. "Chat"
local EVENT_NAMESPACE_ACTIVATED = ADDON_NAME .. "Activated"

-- Chat events can arrive after this file loads and before Initialize() has
-- created SavedVariables and the panel. Queue them so a whisper during the
-- reload gap is not dropped just because CHAT_SYSTEM is not ready yet.
local function OnChatMessageChannel(...)
	if addon.isInitialized then
		addon:OnChatMessageChannel(...)
		return
	end

	addon:QueuePendingChatEvent(...)
end

EVENT_MANAGER:RegisterForEvent(
	EVENT_NAMESPACE_CHAT,
	EVENT_CHAT_MESSAGE_CHANNEL,
	OnChatMessageChannel
)

function addon:Initialize()
	local defaults =
	{
		collapsed = false,
		whisperRestore = {},
		muted = false,
		incomingSound = true,
		overdueSound = true,
		autoDndInCombat = true,
		locked = false,
		scale = 1,
		opacity = 1,
		visibleSenderLimit = 6,
		autoCollapseInCombat = false,
		followUpWaitingSeconds = 90,
		followUpOverdueSeconds = 180,
		followUpReplyGraceSeconds = 30,
		followUpAnsweredVisibleSeconds = 4,
		usePChatPreview = true,
	}

	self.savedVariables = ZO_SavedVars:NewAccountWide(
		SAVED_VARIABLES_NAME,
		SAVED_VARIABLES_VERSION,
		nil,
		defaults
	)

	self.clockCallback = function()
		self:OnClockTick()
	end

	self:CreateInterface()
	self:ApplyPanelLock()
	self:ApplyPanelAppearance()
	self:RegisterSceneVisibility()
	self.wasDndActive = self:IsDndActive()
	self:RegisterSignalEvents()
	self:RegisterSlashCommands()
	self:RegisterSettingsPanel()
	self:RestoreWhisperSnapshot()

	if type(ZO_PreHook) == "function" then
		ZO_PreHook("ReloadUI", function()
			self:PersistWhisperRestore()
		end)
		ZO_PreHook("Logout", function()
			self:PersistWhisperRestore()
		end)
		ZO_PreHook("Quit", function()
			self:PersistWhisperRestore()
		end)
	end

	EVENT_MANAGER:RegisterForEvent(
		EVENT_NAMESPACE_ACTIVATED,
		EVENT_PLAYER_ACTIVATED,
		function()
			EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE_ACTIVATED, EVENT_PLAYER_ACTIVATED)
			self:RestoreWhisperSnapshot()
			if self:TryFillRestoredPreviewsFromPChat() then
				self:RefreshNotifications()
			end
			if type(zo_callLater) == "function" then
				zo_callLater(function()
					if self:TryFillRestoredPreviewsFromPChat() then
						self:RefreshNotifications()
					end
				end, 750)
			end
		end
	)

	self.isInitialized = true
	self.suppressArrivalCues = true
	self:ReplayPendingChatEvents()
	self:UpdateCombatCollapse()
	self:RefreshNotifications()
	self.suppressArrivalCues = false
end

local function OnAddOnLoaded(_, loadedAddOnName)
	if loadedAddOnName ~= ADDON_NAME then
		return
	end

	EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE_LOAD, EVENT_ADD_ON_LOADED)
	addon:Initialize()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE_LOAD, EVENT_ADD_ON_LOADED, OnAddOnLoaded)