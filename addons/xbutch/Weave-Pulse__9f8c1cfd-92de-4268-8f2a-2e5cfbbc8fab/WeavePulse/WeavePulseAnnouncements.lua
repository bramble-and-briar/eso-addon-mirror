-- Native notification workflow adapted from WhatsMissing. No notification library.
local W = WeavePulse
local A = { providers = {} }
W.Announcements = A
local ID = "first-publication-1.51.01"
local ICON = "esoui/art/icons/ability_dualwield_002_b.dds"
local MESSAGE = "WeavePulse 1.51.01 initial experimental release: combat timing, latency, tick/tock cues, resources, execute reminders, six stack trackers and light attack statistics. Native controller settings; no external libraries. Independent and unofficial, inspired by CombatMetronome by Darianopolis and barny. Xbox runtime validation is pending.\n\nReports: DM @xbutch on Discord or ESO Xbox."
function A:IsUnread() return W.accountSV and W.accountSV.lastReadAnnouncementId ~= ID end
function A:MarkRead()
    W.accountSV.lastReadAnnouncementId = ID
    for _, provider in ipairs(self.providers) do provider:RefreshNotifications() end
end
local function ProviderFor(manager, gamepad)
    local Provider = ZO_NotificationProvider:Subclass()
    function Provider:BuildNotificationList()
        ZO_ClearNumericallyIndexedTable(self.list)
        if not A:IsUnread() then return end
        self.list[1] = { dataType = NOTIFICATIONS_REQUEST_DATA,
            notificationType = NOTIFICATION_TYPE_OUT_OF_DATE_ADDONS,
            secsSinceRequest = ZO_NormalizeSecondsSince(0),
            shortDisplayText = "WeavePulse", message = MESSAGE, note = not gamepad and MESSAGE or nil,
            acceptText = "Got it", declineText = "Later" }
    end
    function Provider:Accept() A:MarkRead() end
    function Provider:Decline()
        local name = gamepad and "gamepad_notifications_root" or "notifications"
        if SCENE_MANAGER:IsShowing(name) then SCENE_MANAGER:HideCurrentScene() end
    end
    function Provider:AddDataEntry(index, header)
        if not gamepad then return ZO_NotificationProvider.AddDataEntry(self, index, header) end
        local data = self.list[index]
        data.provider = self
        local row = ZO_GamepadEntryData:New(data.shortDisplayText, ICON)
        row.data = data
        row:SetIconTintOnSelection(true); row:SetIconDisabledTintOnSelection(true)
        local template = ZO_NOTIFICATION_TYPE_TO_GAMEPAD_TEMPLATE[data.dataType]
        if header then row:SetHeader("WeavePulse"); manager.list:AddEntryWithHeader(template, row)
        else manager.list:AddEntry(template, row) end
    end
    local provider = Provider:New(manager)
    manager.providers[#manager.providers + 1] = provider
    if not gamepad then
        ZO_PostHook(manager, "SetupBaseRow", function(_, control, data)
            if data.provider == provider then
                control:GetNamedChild("Icon"):SetTexture(ICON)
                control:GetNamedChild("Type"):SetText("WeavePulse")
            end
        end)
    end
    provider:RefreshNotifications()
    return provider
end
function A:Init()
    if not self.gamepad and GAMEPAD_NOTIFICATIONS then
        self.gamepad = ProviderFor(GAMEPAD_NOTIFICATIONS, true)
        self.providers[#self.providers + 1] = self.gamepad
    end
    if not self.keyboard and NOTIFICATIONS then
        self.keyboard = ProviderFor(NOTIFICATIONS, false)
        self.providers[#self.providers + 1] = self.keyboard
    end
end
