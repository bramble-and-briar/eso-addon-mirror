if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

--[[
function ZO_PlayerToPlayer:AddMenuEntry(text, icons, enabled, selectedFunction, errorReason)
    local normalIcon = enabled and icons.enabledNormal or icons.disabledNormal
    local selectedIcon = enabled and icons.enabledSelected or icons.disabledSelected
    self:GetRadialMenu():AddEntry(text, normalIcon, selectedIcon, selectedFunction, errorReason)
end
 ]]

--Overwrite the keyboard and gamepad interact icons to add disabled icons for abort and report
KEYBOARD_INTERACT_ICONS =
{
    [SI_PLAYER_TO_PLAYER_WHISPER] =
    {
        enabledNormal = "EsoUI/Art/HUD/radialIcon_whisper_up.dds",
        enabledSelected = "EsoUI/Art/HUD/radialIcon_whisper_over.dds",
        disabledNormal =  "EsoUI/Art/HUD/radialIcon_whisper_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/radialIcon_whisper_disabled.dds",
    },
    [SI_PLAYER_TO_PLAYER_ADD_GROUP] =
    {
        enabledNormal = "EsoUI/Art/HUD/radialIcon_inviteGroup_up.dds",
        enabledSelected = "EsoUI/Art/HUD/radialIcon_inviteGroup_over.dds",
        disabledNormal =  "EsoUI/Art/HUD/radialIcon_inviteGroup_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/radialIcon_inviteGroup_disabled.dds",
    },
    [SI_PLAYER_TO_PLAYER_REMOVE_GROUP] =
    {
        enabledNormal = "EsoUI/Art/HUD/radialIcon_removeFromGroup_up.dds",
        enabledSelected = "EsoUI/Art/HUD/radialIcon_removeFromGroup_over.dds",
        disabledNormal =  "EsoUI/Art/HUD/radialIcon_removeFromGroup_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/radialIcon_removeFromGroup_disabled.dds",
    },
    [SI_PLAYER_TO_PLAYER_ADD_FRIEND] =
    {
        enabledNormal = "EsoUI/Art/HUD/radialIcon_addFriend_up.dds",
        enabledSelected = "EsoUI/Art/HUD/radialIcon_addFriend_over.dds",
        disabledNormal = "EsoUI/Art/HUD/radialIcon_addFriend_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/radialIcon_addFriend_disabled.dds",
    },
    [SI_CHAT_PLAYER_CONTEXT_REPORT] =
    {
        enabledNormal = "EsoUI/Art/HUD/radialIcon_reportPlayer_up.dds",
        disabledNormal = "EsoUI/Art/HUD/radialicon_reportplayer_disabled.dds",
        enabledSelected = "EsoUI/Art/HUD/radialIcon_reportPlayer_over.dds",
        disabledSelected = "EsoUI/Art/HUD/radialicon_reportplayer_disabled.dds",
    },
    [SI_PLAYER_TO_PLAYER_INVITE_DUEL] =
    {
        enabledNormal = "EsoUI/Art/HUD/radialIcon_duel_up.dds",
        enabledSelected = "EsoUI/Art/HUD/radialIcon_duel_over.dds",
        disabledNormal = "EsoUI/Art/HUD/radialIcon_duel_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/radialIcon_duel_disabled.dds",
    },
    [SI_PLAYER_TO_PLAYER_INVITE_TRADE] =
    {
        enabledNormal = "EsoUI/Art/HUD/radialIcon_trade_up.dds",
        enabledSelected = "EsoUI/Art/HUD/radialIcon_trade_over.dds",
        disabledNormal = "EsoUI/Art/HUD/radialIcon_trade_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/radialIcon_trade_disabled.dds",
    },
    [SI_RADIAL_MENU_CANCEL_BUTTON] =
    {
        enabledNormal = "EsoUI/Art/HUD/radialIcon_cancel_up.dds",
        enabledSelected = "EsoUI/Art/HUD/radialIcon_cancel_over.dds",
        disabledNormal = "EsoUI/Art/HUD/radialicon_cancel_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/radialicon_cancel_disabled.dds",
    },
}
GAMEPAD_INTERACT_ICONS =
{
    [SI_PLAYER_TO_PLAYER_WHISPER] =
    {
        enabledNormal = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_whisper_down.dds",
        enabledSelected = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_whisper_down.dds",
        disabledNormal =  "EsoUI/Art/HUD/Gamepad/gp_radialIcon_whisper_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_whisper_disabled.dds",
    },
    [SI_PLAYER_TO_PLAYER_ADD_GROUP] =
    {
        enabledNormal = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_inviteGroup_down.dds",
        enabledSelected = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_inviteGroup_down.dds",
        disabledNormal =  "EsoUI/Art/HUD/Gamepad/gp_radialIcon_inviteGroup_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_inviteGroup_disabled.dds",
    },
    [SI_PLAYER_TO_PLAYER_REMOVE_GROUP] =
    {
        enabledNormal = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_removeFromGroup_down.dds",
        enabledSelected = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_removeFromGroup_down.dds",
        disabledNormal =  "EsoUI/Art/HUD/radialIcon_removeFromGroup_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/radialIcon_removeFromGroup_disabled.dds",
    },
    [SI_PLAYER_TO_PLAYER_ADD_FRIEND] =
    {
        enabledNormal = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_addFriend_down.dds",
        enabledSelected = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_addFriend_down.dds",
        disabledNormal = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_addFriend_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_addFriend_disabled.dds",
    },
    [SI_CHAT_PLAYER_CONTEXT_REPORT] =
    {
        enabledNormal = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_reportPlayer_down.dds",
        enabledSelected = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_reportPlayer_down.dds",
        disabledNormal = "EsoUI/Art/HUD/radialIcon_addFriend_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/radialIcon_addFriend_disabled.dds",
    },
    [SI_PLAYER_TO_PLAYER_INVITE_DUEL] =
    {
        enabledNormal = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_duel_down.dds",
        enabledSelected = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_duel_down.dds",
        disabledNormal = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_duel_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_duel_disabled.dds",
    },
    [SI_PLAYER_TO_PLAYER_INVITE_TRADE] =
    {
        enabledNormal = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_trade_down.dds",
        enabledSelected = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_trade_down.dds",
        disabledNormal = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_trade_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_trade_disabled.dds",
    },
    [SI_RADIAL_MENU_CANCEL_BUTTON] =
    {
        enabledNormal = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_cancel_down.dds",
        enabledSelected = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_cancel_down.dds",
        disabledNormal = "EsoUI/Art/HUD/radialicon_cancel_disabled.dds",
        disabledSelected = "EsoUI/Art/HUD/radialicon_cancel_disabled.dds",
    },
}

function FCOChangeStuff.AddPlayerToPlayerRadialMenuEntry(self, text, icons, enabled, selectedFunction, errorReason)
    local isInCombat = IsUnitInCombat("player")
    local isInGamePadMode = IsInGamepadPreferredMode()
--d("[FCOCS] AddMenuEntry - isInGamePadMode: " .. tostring(isInGamePadMode) .. ", inCombat: " .. tostring(isInCombat) .. ", text: " .. tostring(text) .. ", enabled: " .. tostring(enabled))
    local function doNothing()
        return true
    end
    --If we are not in combat call the original function ZO_PlayerToPlayer:AddMenuEntry() now
    if not isInCombat then return false end

    --Else: If we are in combat then disbale the menu entry
    local newEnabled = false
    local newSelectedFunction = doNothing

    --Fixes for report and abort as there are no "disabled" icons
    if text == SI_CHAT_PLAYER_CONTEXT_REPORT then
--d("> Report")
        newEnabled = true
    elseif text == SI_RADIAL_MENU_CANCEL_BUTTON then
--d("> Cancel")
        newEnabled = true
        --Let the original "abort" function work
        newSelectedFunction = selectedFunction
    --Fix for group invite so you're able to invite
    elseif text == SI_PLAYER_TO_PLAYER_ADD_GROUP then
--d("> Group add")
        newEnabled = true
        --Let the original "group invite" function work
        newSelectedFunction = selectedFunction
    --Fix for group kick so you're able to kick someone
--[[
    elseif text == SI_PLAYER_TO_PLAYER_REMOVE_GROUP then
d("> Group kick")
        newEnabled = true
        --Let the original "kick" function work
        newSelectedFunction = selectedFunction
]]
    --Fix for whisper
    elseif text == SI_PLAYER_TO_PLAYER_WHISPER then
--d("> Whisper")
        newEnabled = true
        --Let the original "whisper" function work
        newSelectedFunction = selectedFunction
    end

    --Get the icons (enabled or disabled. Abort and report do not have any disabled icon :-( )
    local normalIcon = (newEnabled and icons.enabledNormal) or (not newEnabled and icons.disabledNormal)
    local selectedIcon = (newEnabled and icons.enabledSelected) or (not newEnabled and icons.disabledSelected)

    --Set the entry to the radial menu now
    self:GetRadialMenu():AddEntry(text, normalIcon, selectedIcon, newSelectedFunction, errorReason)
    --Prevent the original function AddMenuEntry call now!
    return true
end

--PreHook the AddMenuEntry function of ZOs radial menu player to player
ZO_PreHook(ZO_PlayerToPlayer, 'AddMenuEntry', FCOChangeStuff.AddPlayerToPlayerRadialMenuEntry)

