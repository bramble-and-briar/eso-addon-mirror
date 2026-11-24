-- FurnishingCatalogItemActions.lua: a furnishing's Actions prompt, and Link in Chat.
--
-- The prompt is a stock gamepad dialog shaped after the inventory's Actions dialog
-- (GAMEPAD_INVENTORY_ACTIONS_DIALOG in ingamedialogs.lua): one row per action, Select runs it.
-- The chosen action runs once the prompt has closed (the dialog's finishedCallback): Link in
-- Chat leaves for another screen and Remove from List rebuilds the list under the prompt.
--
-- Link in Chat is not the game's own call. The inventory's Link in Chat is
-- ZO_LinkHandler_InsertLinkAndSubmit, which ends in SendChatMessage, and on the gamepad starts
-- in StartChatInput -> ZO_GamepadChatSystem:StartTextEntry -> SetSetting: both are private
-- functions, which raise "Attempt to access a private function from insecure code" with an
-- add-on anywhere on the call stack (pcall does not catch it). What an add-on can do is write
-- the link into the message box of the game's Text Chat screen (CHAT_MENU_GAMEPAD, scene
-- "gamepadChatMenu") and open that screen on top of this one. The player presses the game's
-- own Send there (its callback is the game's, so no add-on is on that call stack), picks the
-- channel there, and Back returns to the catalog.
--
-- That screen is opened from here only once the game has shown it in this UI session (1.8.1).
-- It builds its buttons the first time its scene shows (PerformDeferredInitialize ->
-- ZO_ChatMenu_Gamepad:InitializeFocusKeybinds), and the client trusts a closure only when it was
-- born with no add-on on the call stack. When this file's Push was what showed the screen first,
-- Send's callback was untrusted until the UI reloaded, and every Send raised "Attempt to access
-- a private function 'SendChatMessage' from insecure code", from the main menu's Text Chat as
-- well (1.8.0 on console: it worked in a session that had had Text Chat open, and in no other).
-- Until the game has shown it, the link is written into the message box and the player is told
-- to open Text Chat from the main menu, where the link waits; that showing is the game's own.
local FC = FurnishingCatalog
local BrowseUtils = FC.BrowseUtils
local Shopping = FC.Shopping

local ItemActions = {}

ItemActions.DIALOG = "FURNISHING_CATALOG_ITEM_ACTIONS"
ItemActions.CHAT_SCENE = "gamepadChatMenu"

local CHAT_MAX_LENGTH = 350 -- MAX_TEXT_CHAT_INPUT_CHARACTERS, where the client does not name it

local dialogRegistered = false
---@type FurnishingCatalogItemAction|nil the row chosen in the prompt, until the prompt has closed
local pendingAction = nil

---A game string by the name of its id, or a fallback where this client lacks it.
---@param stringIdName string
---@param fallback string
---@return string
local function GameString(stringIdName, fallback)
    local stringId = rawget(_G, stringIdName)
    local text = stringId and GetString(stringId) or ""
    return text ~= "" and text or fallback
end

---What the prompt and its button are called: the inventory's word for it.
---@return string
function ItemActions.Label()
    return GameString("SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND", "Actions")
end

---@return string
function ItemActions.LinkLabel()
    return GameString("SI_ITEM_ACTION_LINK_TO_CHAT", "Link in Chat")
end

---The message box of the game's Text Chat screen, where this client has text chat.
---@return table|nil edit the box's edit control
---@return string state for /furn status
---@return boolean|nil built the game has shown the screen in this UI session, so its buttons are its own
local function ChatEdit()
    local available = rawget(_G, "IsChatSystemAvailableForCurrentPlatform")
    if type(available) ~= "function" or available() ~= true then
        return nil, "this client has no text chat"
    end
    local chatMenu = rawget(_G, "CHAT_MENU_GAMEPAD")
    local edit = chatMenu and chatMenu.textEdit
    if not (edit and edit.GetText and edit.SetText) then
        return nil, "the game's Text Chat screen has no message box to write to"
    end
    if not SCENE_MANAGER:GetScene(ItemActions.CHAT_SCENE) then
        return nil, "the game's Text Chat screen is not there"
    end
    if chatMenu.initialized ~= true then
        return edit, "into the message box of the game's Text Chat screen, which the player opens the first time in a session", false
    end
    return edit, "through the game's Text Chat screen, which the game has shown in this session", true
end

---Whether a link can be taken to chat on this client.
---@return boolean
function ItemActions.CanLinkInChat()
    return ChatEdit() ~= nil
end

---Write a link into the Text Chat screen's message box, after what it holds, and open that
---screen on top of the current one where the game has shown it before in this session; where
---it has not, the screen stays closed and the player is told to open it. Sending is the
---player's press there.
---@param link string
---@return boolean opened the Text Chat screen was asked for
function ItemActions.LinkInChat(link)
    local edit, state, built = ChatEdit()
    if not edit then
        Shopping.Notify("Text chat is not available here.")
        FC.Log("link in chat: %s", state)
        return false
    end
    local existing = edit:GetText() or ""
    -- The inventory's Link in Chat formats the link the same way.
    local text = BrowseUtils.ChatText(existing, zo_strformat(SI_TOOLTIP_ITEM_NAME, link), rawget(_G, "MAX_TEXT_CHAT_INPUT_CHARACTERS") or CHAT_MAX_LENGTH)
    if text then
        if text ~= existing then
            edit:SetText(text)
        end
    else
        Shopping.Notify("The chat message has no room for another link. Send it first.")
    end
    FC.Log("link in chat: %s -> message box %d -> %d characters (%s); Text Chat screen %s", link, #existing, #(text or existing), text and "written" or "no room",
        built and "shown by the game before: opening it" or "not shown in this session: left closed")
    if not built then
        if text then
            Shopping.Notify("Link added to your Text Chat message. Open Text Chat from the main menu to send it; after that, links open it for you.")
        end
        return false
    end
    SCENE_MANAGER:Push(ItemActions.CHAT_SCENE)
    return true
end

---For /furn status: how a link reaches chat right now.
---@return string
function ItemActions.StateText()
    local _, state = ChatEdit()
    return state
end

-- ---------------------------------------------------------------- the prompt

---One row of the prompt.
---@class FurnishingCatalogItemAction
---@field name string
---@field callback fun() run once the prompt has closed

local function RegisterDialog()
    if dialogRegistered then
        return true
    end
    if not (rawget(_G, "ZO_Dialogs_RegisterCustomDialog") and rawget(_G, "GAMEPAD_DIALOGS")) then
        return false
    end

    local function Setup(dialog, data)
        local parametricList = dialog.info.parametricList
        ZO_ClearNumericallyIndexedTable(parametricList)
        for _, action in ipairs(data.actions) do
            local entryData = ZO_GamepadEntryData:New(action.name)
            entryData.action = action
            entryData.setup = ZO_SharedGamepadEntry_OnSetup
            table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = entryData })
        end
        dialog:setupFunc()
    end

    ZO_Dialogs_RegisterCustomDialog(ItemActions.DIALOG,
    {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog, data) FC.SafeCall("ItemActionsSetup", Setup, dialog, data) end,
        title = { text = ItemActions.Label() },
        mainText = { text = function(dialog) return dialog.data and dialog.data.item and dialog.data.item.name or "" end },
        parametricList = {}, -- filled on setup
        -- Called once the prompt has closed and the screen has its buttons back.
        finishedCallback = FC.Guard("ItemActionsFinished", function()
            local action = pendingAction
            pendingAction = nil
            if action then
                action.callback()
            end
        end),
        buttons =
        {
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
            },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = FC.Guard("ItemActionsSelect", function(dialog)
                    local target = dialog.entryList:GetTargetData()
                    pendingAction = target and target.action or nil
                end),
            },
        },
    })
    dialogRegistered = true
    return true
end

---Open the prompt for a furnishing.
---@param item FurnishingCatalogItem
---@param actions FurnishingCatalogItemAction[] its rows, at least one
---@return boolean shown
function ItemActions.Show(item, actions)
    pendingAction = nil
    if #actions == 0 then
        return false
    end
    if not RegisterDialog() then
        FC.Log("actions: the gamepad dialog system is not there; no prompt")
        return false
    end
    ZO_Dialogs_ShowGamepadDialog(ItemActions.DIALOG, { item = item, actions = actions })
    return true
end

FC.ItemActions = ItemActions
