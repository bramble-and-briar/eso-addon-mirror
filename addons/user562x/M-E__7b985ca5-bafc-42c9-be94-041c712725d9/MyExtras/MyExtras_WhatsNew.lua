local ME = MyExtras

--------------------------------------------------
-- Whats New
--------------------------------------------------
local DIALOG_NAME = "MYEXTRAS_WHATS_NEW"
local EVENT_NAME  = ME.name .. "_WhatsNew"

ME.whatsNew = {
    version = "",
    title   = "MyExtras " .. MyExtras.version,
    message = "New features and options have been added. Open the MyExtras settings to check everything out.",
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
