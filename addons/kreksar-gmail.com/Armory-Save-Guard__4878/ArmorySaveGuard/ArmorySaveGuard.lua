-- Armory Save Guard
-- Replaces the Armory's one-click Accept prompt for "Save Build" with a
-- type-to-confirm prompt modelled on the game's own destroy-item prompt.
-- Toggle with /armorysaveguard.
--
-- Verified API (esoui/esoui live branch @ f76cf16, API 101050; the files below
-- are unchanged or signature-identical on the pts branch @ 1baf113, API 101051):
--   ZO_ARMORY_MANAGER:ShowBuildOperationConfirmationDialog(operationType, buildIndex)
--       -> ingame/armory/armory_manager.lua. The keyboard "Save Build" keybind calls
--          this with ARMORY_BUILD_OPERATION_TYPE_SAVE (armory_keyboard.lua).
--   ZO_ARMORY_MANAGER:GetBuildDataByIndex(buildIndex), ZO_ArmoryBuildData:GetName()
--       -> armory_manager.lua / armorybuilddata.lua
--   SaveArmoryBuild(luaindex buildIndex), IsInGamepadPreferredMode()
--       -> ESOUIDocumentation.txt, no protected/private marking
--   ARMORY_BUILD_OPERATION_TYPE_SAVE, SI_ARMORY_SAVE_BUILD_ACTION, SI_DIALOG_CANCEL
--       -> ESOUIDocumentation.txt / localizegeneratedstrings.lua
--   Vanilla ARMORY_BUILD_SAVE_CONFIRM_DIALOG accept callback (armorydialogs.lua):
--       pauses the dialog queue, exempting ARMORY_BUILD_SAVE_DIALOG,
--       ARMORY_BUILD_SAVE_SUCCESS_DIALOG and ARMORY_BUILD_SAVE_FAILED_DIALOG, then
--       calls SaveArmoryBuild. Replicated exactly below (credit: ZeniMax Online Studios).
--   CONFIRM_DESTROY_ITEM_PROMPT (ingame/globals/ingamedialogs.lua): editBox.matchingString
--       + button.requiresTextInput. The button stays disabled until the text matches
--       exactly, case-sensitive (ZO_RequiredTextFields:UpdateButtonEnabled,
--       libraries/zo_templates/windowtemplates.lua). Pattern reused below.
--   ZO_Dialogs_RegisterCustomDialog, ZO_Dialogs_ShowDialog, ZO_Dialogs_GetEditBoxText,
--   ZO_Dialogs_SetDialogQueuePaused -> libraries/zo_dialog/zo_dialog.lua
--   ZO_PreHook(objectTable, functionName, hook) -> libraries/utility/zo_hook.lua
--   CHAT_ROUTER:AddSystemMessage(messageText) -> ingame/chatsystem/chathandlers.lua
--   ZO_SavedVars:NewAccountWide, zo_strtrim, zo_strlower -> esoui source
--
-- Tested in-game by the author.
--
-- Design decisions:
--   The hook target is a ZO_ method. If ZOS renames or refactors it, the vanilla
--       Accept/Cancel prompt simply appears again; nothing unsafe happens.
--   Gamepad mode intentionally keeps the vanilla prompt. The gamepad
--       type-to-confirm dialog (ZO_GAMEPAD_CONFIRM_DESTROY_DIALOG) is wired to
--       RespondToDestroyRequest and is not reusable here.

local ADDON_NAME = "ArmorySaveGuard"
local DIALOG_NAME = ADDON_NAME .. "_CONFIRM_SAVE"
local SAVED_VARS_VERSION = 1

-- Word the player must type. Case-sensitive, like the vanilla "DESTROY" prompt.
-- Addon-defined string, not a game constant; English only.
local CONFIRM_WORD = "OVERWRITE"

local DEFAULTS = {
    enabled = true,
}

-- Mirrors the exemption list in vanilla ARMORY_BUILD_SAVE_CONFIRM_DIALOG so the
-- game's own saving / success / failed dialogs still show while the queue is paused.
local SAVE_RESULT_DIALOG_EXEMPTIONS = {
    "ARMORY_BUILD_SAVE_DIALOG",
    "ARMORY_BUILD_SAVE_SUCCESS_DIALOG",
    "ARMORY_BUILD_SAVE_FAILED_DIALOG",
}

local sv

-- Centralized feedback: chat only, as a system message.
local function Notify(message)
    local text = string.format("[%s] %s", ADDON_NAME, message)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(text)
    else
        d(text)
    end
end

local function RegisterDialog()
    ZO_Dialogs_RegisterCustomDialog(DIALOG_NAME, {
        title = {
            text = SI_ARMORY_SAVE_BUILD_ACTION, -- "Save Build"
        },
        mainText = {
            -- <<1>> = colorized build name, <<2>> = colorized confirmation word
            text = "Are you sure you want to save over <<1>>?\nYour current gear, skills and champion points will replace it.\n\nType <<2>> to confirm.",
        },
        editBox = {
            matchingString = CONFIRM_WORD,
        },
        buttons = {
            {
                requiresTextInput = true,
                text = SI_ARMORY_SAVE_BUILD_ACTION,
                callback = function(dialog)
                    -- Defensive re-check; the button should already be disabled on a mismatch.
                    if ZO_Dialogs_GetEditBoxText(dialog) ~= CONFIRM_WORD then
                        Notify("Confirmation text did not match. Build was not saved.")
                        return
                    end
                    ZO_Dialogs_SetDialogQueuePaused(true, SAVE_RESULT_DIALOG_EXEMPTIONS)
                    SaveArmoryBuild(dialog.data.selectedBuildIndex)
                end,
            },
            {
                text = SI_DIALOG_CANCEL,
            },
        },
    })
end

-- ZO_PreHook: returning true suppresses the vanilla function, false lets it run.
local function OnShowBuildOperationConfirmation(manager, operationType, buildIndex)
    if not sv.enabled then return false end
    if operationType ~= ARMORY_BUILD_OPERATION_TYPE_SAVE then return false end
    if IsInGamepadPreferredMode() then return false end

    local buildData = manager:GetBuildDataByIndex(buildIndex)
    if not buildData then return false end -- let vanilla handle the odd case

    ZO_Dialogs_ShowDialog(
        DIALOG_NAME,
        { selectedBuildIndex = buildIndex },
        { mainTextParams = { ZO_SELECTED_TEXT:Colorize(buildData:GetName()), ZO_SELECTED_TEXT:Colorize(CONFIRM_WORD) } }
    )
    return true
end

local function OnSlashCommand(rawArgs)
    local arg = zo_strlower(zo_strtrim(rawArgs or ""))

    if arg == "on" then
        sv.enabled = true
    elseif arg == "off" then
        sv.enabled = false
    elseif arg == "" or arg == "toggle" then
        sv.enabled = not sv.enabled
    elseif arg ~= "status" then
        Notify("Usage: /armorysaveguard [on|off|toggle|status]")
        return
    end

    Notify(sv.enabled
        and ("Typed confirmation ON - type " .. CONFIRM_WORD .. " to save over a build.")
        or "Typed confirmation OFF - vanilla save prompt is used.")
end

local function Initialize(eventCode, addOnName)
    if addOnName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- Account-wide with no GetWorldName() split on purpose: a simple on/off
    -- preference, which the ESOUI release guidelines list as fine to share across
    -- servers.
    sv = ZO_SavedVars:NewAccountWide("ArmorySaveGuard_SV", SAVED_VARS_VERSION, nil, DEFAULTS)

    RegisterDialog()

    if ZO_ARMORY_MANAGER and ZO_ARMORY_MANAGER.ShowBuildOperationConfirmationDialog then
        ZO_PreHook(ZO_ARMORY_MANAGER, "ShowBuildOperationConfirmationDialog", OnShowBuildOperationConfirmation)
    else
        Notify("Armory manager not found; addon inactive (game UI may have changed).")
    end

    SLASH_COMMANDS["/armorysaveguard"] = OnSlashCommand
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, Initialize)
