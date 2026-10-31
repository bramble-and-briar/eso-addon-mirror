local ADDON_NAME = "NirnsteelUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_EnchantConfirmation"
local SUPPORTED_DIALOGS =
{
    CONFIRM_ENCHANT_LOCKED_ITEM = true,
    CONFIRM_IMPROVE_LOCKED_ITEM = true,
}

Nirnsteel_UI = Nirnsteel_UI or {}
local EnchantConfirmation = {}
Nirnsteel_UI.EnchantConfirmation = EnchantConfirmation

function EnchantConfirmation:FillDialog(name)
    if not Nirnsteel_UI.Settings:IsEnchantConfirmationEnabled() then return end
    local dialog
    if name then
        if not SUPPORTED_DIALOGS[name] then return end
        dialog = ZO_Dialogs_FindDialog(name)
    else
        for dialogName in pairs(SUPPORTED_DIALOGS) do
            dialog = ZO_Dialogs_FindDialog(dialogName)
            if dialog then break end
        end
    end
    if not dialog then return end
    local editBoxInfo = dialog.info and dialog.info.editBox
    local confirmation = editBoxInfo and editBoxInfo.matchingString
    if type(confirmation) ~= "string" or confirmation == "" then return end
    local editControl = dialog:GetNamedChild("EditBox")
    if not editControl or editControl:IsControlHidden() or editControl:GetText() ~= "" then return end

    -- Use the dialog's localized validation word. SetText also runs ESO's
    -- normal validation; the player still presses Accept to modify the item.
    editControl:SetText(confirmation)
    editControl:LoseFocus()
end

function EnchantConfirmation:RefreshSettings()
    if not self.hookInstalled then
        if type(ZO_Dialogs_ShowDialog) ~= "function" or type(ZO_Dialogs_FindDialog) ~= "function" then
            return
        end
        ZO_PostHook("ZO_Dialogs_ShowDialog", function(name)
            self:FillDialog(name)
        end)
        self.hookInstalled = true
    end
    self:FillDialog()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
        EnchantConfirmation:RefreshSettings()
    end)
    EnchantConfirmation:RefreshSettings()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
