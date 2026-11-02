-- The announcement ID changes only when a new recap is prepared for publication.
local ANNOUNCEMENT_ID = "1.51.07"
local ICON = "EsoUI/Art/Journal/Gamepad/GP_journal_tabIcon_antiquities.dds"
local Announcements = { providers = {} }
AC.Announcements = Announcements

function Announcements:IsUnread()
	return AC.savedVars and AC.savedVars.lastReadAnnouncementId ~= ANNOUNCEMENT_ID
end

function Announcements:MarkRead()
	if not self:IsUnread() then return end
	AC.savedVars.lastReadAnnouncementId = ANNOUNCEMENT_ID
	for _, provider in ipairs(self.providers) do provider:RefreshNotifications() end
end

local function CreateProvider(manager, isGamepad)
	local Provider = ZO_NotificationProvider:Subclass()

	function Provider:BuildNotificationList()
		ZO_ClearNumericallyIndexedTable(self.list)
		if not Announcements:IsUnread() then return end
		local message = AC.ANNOUNCEMENT_MESSAGE
		self.list[1] = {
			dataType = NOTIFICATIONS_REQUEST_DATA,
			notificationType = NOTIFICATION_TYPE_OUT_OF_DATE_ADDONS,
			secsSinceRequest = ZO_NormalizeSecondsSince(0),
			shortDisplayText = AC.ANNOUNCEMENT_TITLE,
			message = message,
			note = not isGamepad and message or nil,
			acceptText = AC.ANNOUNCEMENT_CONFIRM,
			declineText = AC.ANNOUNCEMENT_LATER,
		}
	end

	function Provider:Accept()
		Announcements:MarkRead()
	end

	function Provider:Decline()
		local sceneName = isGamepad and "gamepad_notifications_root" or "notifications"
		if SCENE_MANAGER:IsShowing(sceneName) then SCENE_MANAGER:HideCurrentScene() end
	end

	function Provider:AddDataEntry(index, isHeader)
		if not isGamepad then
			return ZO_NotificationProvider.AddDataEntry(self, index, isHeader)
		end

		local data = self.list[index]
		data.provider = self
		local entry = ZO_GamepadEntryData:New(data.shortDisplayText, ICON)
		entry.data = data
		entry:SetIconTintOnSelection(true)
		entry:SetIconDisabledTintOnSelection(true)
		local template = ZO_NOTIFICATION_TYPE_TO_GAMEPAD_TEMPLATE[data.dataType]
		if isHeader then
			entry:SetHeader("Antiquarian Codex")
			manager.list:AddEntryWithHeader(template, entry)
		else
			manager.list:AddEntry(template, entry)
		end
	end

	local provider = Provider:New(manager)
	table.insert(manager.providers, provider)
	if not isGamepad then
		ZO_PostHook(manager, "SetupBaseRow", function(_, control, data)
			if data.provider == provider then
				control:GetNamedChild("Icon"):SetTexture(ICON)
				control:GetNamedChild("Type"):SetText("Antiquarian Codex")
			end
		end)
	end
	return provider
end

function Announcements:Init()
	if self.initialized then return end
	AC.savedVars = ZO_SavedVars:NewAccountWide("AntiquarianCodex_SavedVariables", 1, nil, {})
	self.initialized = true

	if GAMEPAD_NOTIFICATIONS then
		table.insert(self.providers, CreateProvider(GAMEPAD_NOTIFICATIONS, true))
	end
	if NOTIFICATIONS then
		table.insert(self.providers, CreateProvider(NOTIFICATIONS, false))
	end
	for _, provider in ipairs(self.providers) do provider:RefreshNotifications() end
end
