local ADDON_NAME = "PreviewAnywhere"

-- Preview mode starts asynchronously; poll until it is ready
local POLL_INTERVAL_MS = 100
local MAX_POLLS = 30

local function Print(message)
    d(string.format("[Preview Anywhere] %s", message))
end

-- The link we are showing, so its Preview action can be hidden while others stay available
local previewedLink

local function ShowPreview(itemLink)
    PreviewItemLink(itemLink, 1)
    ApplyChangesToPreviewCollectionShown()
    previewedLink = itemLink
end

local function IsPreviewReady()
    return GetPreviewModeEnabled() and not ITEM_PREVIEW_KEYBOARD:IsWaitingForPreviewBegin()
end

-- Bumped on each request so a newer /preview supersedes a pending one
local requestId = 0

local function PollUntilReady(itemLink, id, pollCount)
    -- Superseded, or the preview was closed (Escape, moving) before it started: drop it silently.
    -- Closing hides ZOS's preview fragment, which already ends the preview and disables preview mode.
    if id ~= requestId or not ITEM_PREVIEW_KEYBOARD:IsPreviewEnabled() then
        return
    end
    if IsPreviewReady() then
        ShowPreview(itemLink)
    elseif pollCount < MAX_POLLS then
        zo_callLater(function() PollUntilReady(itemLink, id, pollCount + 1) end, POLL_INTERVAL_MS)
    else
        Print("Preview mode did not start.")
    end
end

local function PreviewWhenReady(itemLink)
    requestId = requestId + 1
    PollUntilReady(itemLink, requestId, 0)
end

-- Same camera setup as the vendor window, whose right panel matches the bank's.
-- Toggling while enabled turns it off and restores the interact camera.
local function ToggleInteractionPreview()
    ITEM_PREVIEW_KEYBOARD:ToggleInteractionCameraPreview(FRAME_TARGET_STORE_WINDOW_FRAGMENT, FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT, RIGHT_PANEL_BG_EMPTY_WORLD_ITEM_PREVIEW_OPTIONS_FRAGMENT)
end

-- Banks have no base-game preview. House storage uses the bank interaction too.
local BANK_INTERACTION_TYPES =
{
    [INTERACTION_BANK] = true,
    [INTERACTION_GUILDBANK] = true,
}

local interactionScene
local hookedScenes = {}
local endInteractionPreviewKeybind

-- Turns the camera back to the interact camera, either from our keybind or when the scene hides: leaving with the
-- interaction preview still on would leave the camera out of interact mode
local function EndInteractionPreview()
    if not interactionScene then
        return
    end
    KEYBIND_STRIP:RemoveKeybindButtonGroup(endInteractionPreviewKeybind)
    interactionScene = nil
    if ITEM_PREVIEW_KEYBOARD:IsInteractionCameraPreviewEnabled() then
        ToggleInteractionPreview()
    end
end

endInteractionPreviewKeybind =
{
    alignment = KEYBIND_STRIP_ALIGN_CENTER,
    {
        name = GetString(SI_CRAFTING_EXIT_PREVIEW_MODE),
        -- Free at banks; matches the inventory's End Preview
        keybind = "UI_SHORTCUT_NEGATIVE",
        callback = EndInteractionPreview,
    },
}

local function OnInteractionSceneStateChange(oldState, newState)
    if newState == SCENE_HIDING then
        EndInteractionPreview()
    end
end

local function StartInteractionPreview(itemLink)
    ToggleInteractionPreview()
    interactionScene = SCENE_MANAGER:GetCurrentScene()
    -- Registered once per scene; EndInteractionPreview does nothing when no preview is active
    if not hookedScenes[interactionScene] then
        hookedScenes[interactionScene] = true
        interactionScene:RegisterCallback("StateChange", OnInteractionSceneStateChange)
    end
    KEYBIND_STRIP:AddKeybindButtonGroup(endInteractionPreviewKeybind)
    PreviewWhenReady(itemLink)
end

-- In the open world, show our own menu-like scene: it hides the HUD, frees the mouse cursor and closes
-- with Escape like any menu. The player is framed at the screen center, in an empty world.
local PREVIEW_SCENE_NAME = "previewAnywhere"

local function CreatePreviewScene()
    local scene = ZO_Scene:New(PREVIEW_SCENE_NAME, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_CENTERED)
    -- Order matters: the options fragment must be added before the preview fragment
    scene:AddFragment(ZO_ItemPreviewOptionsFragment:New({
        paddingLeft = 0,
        paddingRight = 0,
        dynamicFramingConsumedWidth = 0,
        dynamicFramingConsumedHeight = 0,
        previewInEmptyWorld = true,
        forcePreparePreview = false,
    }))
    scene:AddFragment(ITEM_PREVIEW_KEYBOARD:GetFragment())

    local exitKeybind =
    {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            name = GetString(SI_CRAFTING_EXIT_PREVIEW_MODE),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function() SCENE_MANAGER:Hide(PREVIEW_SCENE_NAME) end,
        },
    }
    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            KEYBIND_STRIP:AddKeybindButtonGroup(exitKeybind)
        elseif newState == SCENE_HIDDEN then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(exitKeybind)
        end
    end)
end

local function StartScenePreview(itemLink)
    SCENE_MANAGER:Show(PREVIEW_SCENE_NAME)
    PreviewWhenReady(itemLink)
end

local function IsOurPreviewActive()
    return interactionScene ~= nil or SCENE_MANAGER:IsShowing(PREVIEW_SCENE_NAME)
end

-- The open world: the HUD, or its mouse-cursor variant (e.g. when right-clicking chat)
local function IsInOpenWorld()
    return SCENE_MANAGER:IsShowingBaseScene() or SCENE_MANAGER:IsShowing("hudui")
end

-- Only where the base game has no preview: banks and the open world. Elsewhere (inventory, merchants, guild stores,
-- crafting stations) leave it to the base game.
local function CanPreviewHere()
    return IsOurPreviewActive() or BANK_INTERACTION_TYPES[GetInteractionType()] or IsInOpenWorld()
end

local function OnSlashCommand(args)
    local itemLink = zo_strtrim(args)
    if itemLink == "" then
        Print("Usage: /preview <item link>")
        return
    end
    if not CanItemLinkBePreviewed(itemLink) then
        Print(string.format("%s cannot be previewed.", itemLink))
        return
    end

    if IsOurPreviewActive() then
        -- Swap the item (once ready); also supersedes any pending request
        PreviewWhenReady(itemLink)
    elseif BANK_INTERACTION_TYPES[GetInteractionType()] then
        StartInteractionPreview(itemLink)
    elseif IsInOpenWorld() then
        StartScenePreview(itemLink)
    else
        Print("Only available in the open world and at banks.")
    end
end

-- Inventory Insight (IIfA) list rows go through the same inventory context menu, but hold a link instead of a bag
-- slot: the right-clicked control is a child of the row, which IIfA names IIFA_ListItem<n>
local function GetIIfARowItemLink(inventorySlot)
    local row = inventorySlot.GetParent and inventorySlot:GetParent()
    if not row or not zo_plainstrfind(row:GetName(), "IIFA_ListItem") then
        return nil
    end
    return row.itemLink or (row.dataEntry and row.dataEntry.data and row.dataEntry.data.itemLink)
end

local function GetSlotItemLink(inventorySlot)
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if bagId then
        return GetItemLink(bagId, slotIndex)
    end
    return GetIIfARowItemLink(inventorySlot)
end

-- "Preview" on hover (keybind strip) and in the right-click menu of items at banks and of IIfA rows, same as
-- /preview <link>. The base game offers no preview there, even while ours runs.
local function AddPreviewSlotAction(inventorySlot, slotActions)
    if not CanPreviewHere() then
        return
    end
    local itemLink = GetSlotItemLink(inventorySlot)
    if itemLink and itemLink ~= previewedLink and CanItemLinkBePreviewed(itemLink) then
        -- keybind1 is the hover strip's Secondary, the slot ZOS's own inventory "Preview" uses
        slotActions:AddCustomSlotAction(SI_ITEM_ACTION_PREVIEW, function() OnSlashCommand(itemLink) end, "keybind1")
    end
end

-- Right-clicking an item link (chat, mail, notes...): ZOS's handler has already built and shown the menu with
-- "Link in Chat", so append to it and show it again, as other addons (e.g. TTC) do
local function OnLinkMouseUp(link, button, control)
    if button ~= MOUSE_BUTTON_INDEX_RIGHT or link == previewedLink or not CanPreviewHere() then
        return
    end
    local _, _, linkType = ZO_LinkHandler_ParseLink(link)
    if linkType == ITEM_LINK_TYPE and CanItemLinkBePreviewed(link) then
        AddCustomMenuItem(GetString(SI_ITEM_ACTION_PREVIEW), function() OnSlashCommand(link) end, MENU_ADD_OPTION_LABEL)
        ShowMenu(control)
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    CreatePreviewScene()
    SLASH_COMMANDS["/preview"] = OnSlashCommand
    -- ZOS ends any preview (ours or its own) through these
    ITEM_PREVIEW_KEYBOARD:RegisterCallback("EndCurrentPreview", function() previewedLink = nil end)
    ITEM_PREVIEW_KEYBOARD:GetFragment():RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_FRAGMENT_HIDDEN then
            previewedLink = nil
        end
    end)
    LibCustomMenu:RegisterContextMenu(AddPreviewSlotAction, LibCustomMenu.CATEGORY_LATE)
    LibCustomMenu:RegisterKeyStripEnter(AddPreviewSlotAction, LibCustomMenu.CATEGORY_LATE)
    SecurePostHook("ZO_LinkHandler_OnLinkMouseUp", OnLinkMouseUp)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
