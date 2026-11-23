local AH = _G.MarkTrialHelper

function AH.SendTip()
    if GetWorldName() ~= "EU Megaserver" then
        d("|cff9900[Mark Trial Helper]|r Автор играет на сервере PC EU (@BadKeni) / Author plays on PC EU (@BadKeni).")
        return
    end
    if not IsInGamepadPreferredMode() then
        SCENE_MANAGER:Show("mailSend")
        zo_callLater(function()
            if ZO_MailSendToField then ZO_MailSendToField:SetText("@BadKeni") end
            if ZO_MailSendSubjectField then ZO_MailSendSubjectField:SetText("Mark Trial Helper - Tips") end
            if ZO_MailSendBodyField then ZO_MailSendBodyField:TakeFocus() end
        end, 150)
    end
end
SLASH_COMMANDS["/mtip"] = function() AH.SendTip() end

local function Initialise()
    -- saved variables
    AH.Vars =
        _G.LibSavedVars:NewAccountWide("MarkTrialHelperSavedVars", "Account", AH.Defaults):AddCharacterSettingsToggle(
        "MarkTrialHelperSavedVars",
        "Characters"
    ):EnableDefaultsTrimming()

        AH.RegisterSettings()

    local selector_short = "ZO_EndDunBuffSelector_%s"
    local selector = "ZO_EndlessDungeonBuffSelector_%s"
    local selectorObject = "ENDLESS_DUNGEON_BUFF_SELECTOR_%s"

    if (IsInGamepadPreferredMode()) then
        AH.SELECTOR_SHORT = string.format(selector_short, "Gamepad")
        AH.SELECTOR = string.format(selector, "Gamepad")
        AH.SELECTOR_OBJECT = string.format(selectorObject, "GAMEPAD")
    else
        AH.SELECTOR_SHORT = string.format(selector_short, "Keyboard")
        AH.SELECTOR = string.format(selector, "Keyboard")
        AH.SELECTOR_OBJECT = string.format(selectorObject, "KEYBOARD")
    end

    AH.CheckDataShareLib()
    AH.SetupHooks()
    AH.FindMissingAbilityIds()
    AH.SetupEvents()

    if (GetCVar("language.2") == "ru") then
        AH.IsRu = true
    end

    _G.SLASH_COMMANDS["/mh"] = function(...)
        AH.HandleSlashCommand(...)
    end
end

function AH.OnAddonLoaded(_, addonName)
    if (addonName ~= AH.Name) then
        return
    end

    if (_G.LibChatMessage ~= nil) then
        AH.Chat = _G.LibChatMessage(AH.Name, "MH")
    end

    EVENT_MANAGER:UnregisterForEvent(AH.Name, EVENT_ADD_ON_LOADED)

    Initialise()
end

EVENT_MANAGER:RegisterForEvent(AH.Name, EVENT_ADD_ON_LOADED, AH.OnAddonLoaded)