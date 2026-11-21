local ME = MyExtras

--------------------------------------------------
-- Whats New
--------------------------------------------------
local DIALOG_NAME = "MYEXTRAS_WHATS_NEW"
local EVENT_NAME  = ME.name .. "_WhatsNew"

ME.whatsNew = {
    version = "7.6",
    title   = "MyExtras " .. MyExtras.version,
    heading = "What's New",
    message = "A lot of new features have been added! Please go through all of the settings so you don't miss anything."
           .. "\n\nSome of these haven't been fully tested yet, so if you run into any issues or have any suggestions, please let me know."
           .. "\n\nXbox: user562\nDiscord: user562. (the period is part of the name)",
}

local registered = false

local function MarkSeen()
    local sv = ME.savedVariables
    if sv then sv.whatsNewSeen = ME.whatsNew.version end
end

local function RegisterDialog()
    if registered or not ZO_Dialogs_RegisterCustomDialog then return end
    ZO_Dialogs_RegisterCustomDialog(DIALOG_NAME, {
        canQueue   = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.BASIC },
        title      = { text = function() return ME.whatsNew.title end },
        mainText   = { text = function() return ME.whatsNew.message end },
        buttons    = {
            { keybind = "DIALOG_PRIMARY", text = SI_OK, callback = MarkSeen },
        },
    })
    registered = true
end

function ME:ShowWhatsNew()
    local panel = self.settingsPanel
    if panel and panel.ShowNotice then
        local shown = panel:ShowNotice({
            heading = self.whatsNew.heading,
            text    = self.whatsNew.message,
            onClose = MarkSeen,
        })
        if shown then return end
    end
    RegisterDialog()
    if ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog(DIALOG_NAME)
    elseif ZO_Dialogs_ShowPlatformDialog then
        ZO_Dialogs_ShowPlatformDialog(DIALOG_NAME)
    elseif ZO_Dialogs_ShowDialog then
        ZO_Dialogs_ShowDialog(DIALOG_NAME)
    end
end

function ME:WhatsNewCheck()
    local info = self.whatsNew
    local sv = self.savedVariables
    if not sv or type(info.version) ~= "string" or info.version == "" then return end
    if self.freshInstall then
        MarkSeen()
        return
    end
    if sv.whatsNewSeen == info.version then return end
    self:ShowWhatsNew()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_PLAYER_ACTIVATED)
    ME:WhatsNewCheck()
end)
