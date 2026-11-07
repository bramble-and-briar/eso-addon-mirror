local IMP_STATS_SHARED = IMP_STATS_SHARED

local MyNotificationProvider = ZO_NotificationProvider:Subclass()

function MyNotificationProvider:Initialize(notificationManager)
    ZO_NotificationProvider.Initialize(self, notificationManager)
end

function MyNotificationProvider:BuildNotificationList()
    ZO_ClearNumericallyIndexedTable(self.list)

    local errors = IMP_STATS_SHARED.Errors:GetErrors()
    if #errors == 0 then return end

    for i = 1, 1 do
        self.list[i] = {
            dataType = NOTIFICATIONS_ALERT_DATA,
            notificationType = NOTIFICATION_TYPE_OUT_OF_DATE_ADDONS,
            note = table.concat(errors, '\n'),
            heading = 'ImpressiveStats',
            message = '|cFF5349Error occurred. Report it (see note) or disable notifications in settings.|r',
            texture = 'EsoUi/Art/campaign/campaignbrowser_indexicon_normal_up.dds',
        }
    end
end

-- function NotificationProvider:Accept(data)
--     PlaySound(SOUNDS.DIALOG_ACCEPT)
--     AcceptGuildInvite(data.guildId)
-- end

function MyNotificationProvider:Decline(data, button, openedFromKeybind)
    PlaySound(SOUNDS.DIALOG_DECLINE)

    IMP_STATS_SHARED.Errors:Ack()
    self.notificationManager:RefreshNotificationList()
end


local NOTIFICATION_MANAGER = NOTIFICATIONS
IMP_STATS_SHARED.Notifications = {
    RegisterNotifications = function()
        assert(NOTIFICATION_MANAGER, 'No notification manager available')

        local provider = MyNotificationProvider:New(NOTIFICATION_MANAGER)
        NOTIFICATION_MANAGER.providers[#NOTIFICATION_MANAGER.providers+1] = provider

        NOTIFICATION_MANAGER:RefreshNotificationList()  -- TODO: do I need this here?
    end,
    UpdateNotifications = function()
        NOTIFICATION_MANAGER:RefreshNotificationList()
    end
}
