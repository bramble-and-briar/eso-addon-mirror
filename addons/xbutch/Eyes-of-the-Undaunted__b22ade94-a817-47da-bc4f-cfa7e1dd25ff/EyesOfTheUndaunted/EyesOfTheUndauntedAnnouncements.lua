-- Native update notifications, following the shared WhatsMissing workflow.
-- Announcement acknowledgement is independent of the saved-variable schema.
local addon = EOTU
local ANNOUNCEMENT_ID = "1.51.03-imperial-city"
local TITLE = "Eyes of the Undaunted 1.51.03"
local NAME = "Eyes of the Undaunted"
local ICON = "EsoUI/Art/WorldMap/map_indexicon_locations_down.dds"
local MESSAGE = "Added Imperial City boss pins in all six districts and the sewers, including patrol references, the Simulacrum of Molag Bal and its three central guards."
    .. "\n\nReports: DM @xbutch on Discord or ESO Xbox."
local Announcements = { providers = {}, registeredManagers = {} }
addon.Announcements = Announcements

function Announcements:IsUnread()
    return addon.savedVars and addon.savedVars.lastReadAnnouncementId ~= ANNOUNCEMENT_ID
end

function Announcements:MarkRead()
    if not self:IsUnread() then return end
    addon.savedVars.lastReadAnnouncementId = ANNOUNCEMENT_ID
    for _, provider in ipairs(self.providers) do provider:RefreshNotifications() end
end

local function CreateProvider(manager, isGamepad)
    local Provider = ZO_NotificationProvider:Subclass()

    function Provider:BuildNotificationList()
        ZO_ClearNumericallyIndexedTable(self.list)
        if not Announcements:IsUnread() then return end
        self.list[1] = {
            dataType = NOTIFICATIONS_REQUEST_DATA,
            notificationType = NOTIFICATION_TYPE_OUT_OF_DATE_ADDONS,
            secsSinceRequest = ZO_NormalizeSecondsSince(0),
            shortDisplayText = TITLE,
            message = MESSAGE,
            note = not isGamepad and MESSAGE or nil,
            acceptText = "Got it",
            declineText = "Later",
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
        if not isGamepad then return ZO_NotificationProvider.AddDataEntry(self, index, isHeader) end
        local data = self.list[index]
        data.provider = self
        local entry = ZO_GamepadEntryData:New(data.shortDisplayText, ICON)
        entry.data = data
        entry:SetIconTintOnSelection(true)
        entry:SetIconDisabledTintOnSelection(true)
        local template = ZO_NOTIFICATION_TYPE_TO_GAMEPAD_TEMPLATE[data.dataType]
        if isHeader then entry:SetHeader(NAME); manager.list:AddEntryWithHeader(template, entry)
        else manager.list:AddEntry(template, entry) end
    end

    local provider = Provider:New(manager)
    table.insert(manager.providers, provider)
    if not isGamepad then
        ZO_PostHook(manager, "SetupBaseRow", function(_, control, data)
            if data.provider == provider then
                control:GetNamedChild("Icon"):SetTexture(ICON)
                control:GetNamedChild("Type"):SetText(NAME)
            end
        end)
    end
    return provider
end

function Announcements:Init()
    if not addon.savedVars or not ZO_NotificationProvider then return end
    local function Register(manager, isGamepad)
        if not manager or self.registeredManagers[manager] then return end
        local provider = CreateProvider(manager, isGamepad)
        self.registeredManagers[manager] = provider
        self.providers[#self.providers + 1] = provider
        provider:RefreshNotifications()
    end
    Register(GAMEPAD_NOTIFICATIONS, true)
    Register(NOTIFICATIONS, false)
end
