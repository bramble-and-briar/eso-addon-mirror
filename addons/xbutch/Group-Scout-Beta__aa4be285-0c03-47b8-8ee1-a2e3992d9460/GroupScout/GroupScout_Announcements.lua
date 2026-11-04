if GroupScout == nil then GroupScout = {} end

-- Change the ID and message only when publishing a new announcement. Reading
-- an announcement is independent of character snapshots and manifest versions.
local ANNOUNCEMENT_ID = "beta-0.1.0"
local ICON = "EsoUI/Art/LFG/Gamepad/LFG_menuIcon_groupFinder.dds"
local GS = GetString
local Announcements = { providers = {} }
GroupScout.Announcements = Announcements

function Announcements:IsUnread()
	return GroupScout.savedVars and GroupScout.savedVars.lastReadAnnouncementId ~= ANNOUNCEMENT_ID
end

function Announcements:MarkRead()
	if not self:IsUnread() then return end
	GroupScout.savedVars.lastReadAnnouncementId = ANNOUNCEMENT_ID
	for _, provider in ipairs(self.providers) do provider:RefreshNotifications() end
end

-- Each manager gets a native provider. Only our rows customize their heading
-- and icon; the managers and all other addons keep their normal behavior.
local function CreateProvider(manager, isGamepad)
	local Provider = ZO_NotificationProvider:Subclass()

	function Provider:BuildNotificationList()
		ZO_ClearNumericallyIndexedTable(self.list)
		if not Announcements:IsUnread() then return end
		local message = GS(GROUPSCOUT_ANNOUNCEMENT_MESSAGE)
		self.list[1] = {
			dataType = NOTIFICATIONS_REQUEST_DATA,
			notificationType = NOTIFICATION_TYPE_OUT_OF_DATE_ADDONS,
			secsSinceRequest = ZO_NormalizeSecondsSince(0),
			shortDisplayText = GS(GROUPSCOUT_ANNOUNCEMENT_TITLE),
			message = message,
			-- Native keyboard rows have a fixed height. Their note tooltip also
			-- exposes the complete recap on hover, without another click.
			note = not isGamepad and message or nil,
			acceptText = GS(GROUPSCOUT_ANNOUNCEMENT_CONFIRM),
			declineText = GS(GROUPSCOUT_ANNOUNCEMENT_LATER),
		}
	end

	function Provider:Accept()
		Announcements:MarkRead()
	end

	function Provider:Decline()
		-- "Later" leaves the saved read state untouched, including after reloads.
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
			entry:SetHeader(GS(GROUPSCOUT_NAME))
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
				control:GetNamedChild("Type"):SetText(GS(GROUPSCOUT_NAME))
			end
		end)
	end
	return provider
end

function Announcements:Init()
	if self.initialized then return end
	self.initialized = true

	if GAMEPAD_NOTIFICATIONS then
		table.insert(self.providers, CreateProvider(GAMEPAD_NOTIFICATIONS, true))
	end
	if NOTIFICATIONS then
		table.insert(self.providers, CreateProvider(NOTIFICATIONS, false))
	end
	for _, provider in ipairs(self.providers) do provider:RefreshNotifications() end
end
