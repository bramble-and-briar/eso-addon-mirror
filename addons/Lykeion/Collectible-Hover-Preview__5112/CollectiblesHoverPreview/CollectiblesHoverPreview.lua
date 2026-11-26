local ADDON_NAME = "CollectiblesHoverPreview"
local PREVIEW_KEYBIND = "UI_SHORTCUT_QUINARY"
local GAMEPAD_PREVIEW_KEYBIND = "UI_SHORTCUT_QUATERNARY"
local UNLOAD_UPDATE = ADDON_NAME .. "Unload"
local CURSOR_UPDATE = ADDON_NAME .. "Cursor"
local STICK_UPDATE = ADDON_NAME .. "Stick"
local MOUSE_UP_EVENT = ADDON_NAME .. "MouseUp"
local UI_CHANGE_EVENT = ADDON_NAME .. "InputMode"
local LOAD_REFRESH_MS = 100
local CURSOR_REFRESH_MS = 50
local STICK_REFRESH_MS = 50
local STICK_THRESHOLD = 0.02
local GAMEPAD_LOAD_SETTLE_S = 0.02
local GAMEPAD_LOAD_TIMEOUT_S = 0.2

local loadedTile
local hoveredTile
local spinPendingTile
local spinning = false
local cursorUpdateActive = false
local mouseUpWatching = false

local gamepadPreviewCallback
local gamepadTargetData
local gamepadTargetSince = 0
local gamepadPreviewedId
local gamepadLoadedList
local gamepadLoadedAt = 0
local stickSpinning = false
local stickUpdateActive = false

local function Unload()
    if loadedTile then
        loadedTile.OnUpdate = nil
        loadedTile = nil
    end
    EVENT_MANAGER:UnregisterForUpdate(UNLOAD_UPDATE)
end

local function FindDescriptorCallback(descriptors, keybind, name)
    for index = 1, #descriptors do
        local descriptor = descriptors[index]
        if type(descriptor.callback) == "function"
            and (descriptor.keybind == keybind or (name and descriptor.name == name)) then
            return descriptor.callback
        end
    end
end

local function GetPreviewCallback(tile)
    return FindDescriptorCallback(tile.keybindStripDescriptor, PREVIEW_KEYBIND, GetString(SI_COLLECTIBLE_ACTION_PREVIEW))
end

local function CanSpinTile(tile)
    -- categories that show the utility wheel are left alone
    if not tile or tile.utilityWheel then
        return false
    end

    local collectibleData = tile.collectibleData
    if not collectibleData then
        return false
    end
    if not ITEM_PREVIEW_KEYBOARD:IsCurrentlyPreviewing(ZO_ITEM_PREVIEW_COLLECTIBLE, collectibleData:GetId()) then
        return false
    end
    return GetCursorContentType() == MOUSE_CONTENT_EMPTY and CanSpinPreviewCharacter()
end

local function StartSpin(tile)
    if spinning or not CanSpinTile(tile) then
        return
    end
    spinPendingTile = nil
    spinning = true
    BeginItemPreviewSpin()
end

local function UpdateCursor()
    if spinPendingTile and CanSpinTile(spinPendingTile) then
        StartSpin(spinPendingTile)
    end
    local rotatable = spinning or (hoveredTile and hoveredTile:IsMousedOver() and CanSpinTile(hoveredTile))
    if rotatable then
        WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_ROTATE)
    elseif WINDOW_MANAGER:GetMouseCursor() == MOUSE_CURSOR_ROTATE then
        WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
    end
end

local function SetCursorUpdateActive(active)
    if active == cursorUpdateActive then
        return
    end
    cursorUpdateActive = active
    if active then
        EVENT_MANAGER:RegisterForUpdate(CURSOR_UPDATE, CURSOR_REFRESH_MS, UpdateCursor)
    else
        EVENT_MANAGER:UnregisterForUpdate(CURSOR_UPDATE)
    end
end

local function StopSpin()
    spinPendingTile = nil
    if not spinning then
        return
    end
    spinning = false
    EndItemPreviewSpin()
    UpdateCursor()
    if not hoveredTile then
        SetCursorUpdateActive(false)
    end
end

local function StopWatchingMouseUp()
    if not mouseUpWatching then
        return
    end
    mouseUpWatching = false
    EVENT_MANAGER:UnregisterForEvent(MOUSE_UP_EVENT, EVENT_GLOBAL_MOUSE_UP)
end

local function EndSpin()
    StopWatchingMouseUp()
    StopSpin()
end

local function OnGlobalMouseUp(_, button)
    if 
    -- IsCurrentlyPreviewing() and 
    button == MOUSE_BUTTON_INDEX_LEFT then
        EndSpin()
    end
end

local function WatchMouseUp()
    if mouseUpWatching then
        return
    end
    mouseUpWatching = true
    EVENT_MANAGER:RegisterForEvent(MOUSE_UP_EVENT, EVENT_GLOBAL_MOUSE_UP, OnGlobalMouseUp)
end

local function HookTileMouse(tile)
    local control = tile.control
    if not control or control.collectiblesHoverPreviewHooked then
        return
    end
    control.collectiblesHoverPreviewHooked = true

    ZO_PreHookHandler(control, "OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            -- the preview may still be loading, so retry until it can spin
            spinPendingTile = tile
            WatchMouseUp()
            StartSpin(tile)
            if spinning then
                UpdateCursor()
            end
            SetCursorUpdateActive(true)
        end
    end)
end

local function OnCollectibleTileFocusChanged(tile, isFocused)
    if not tile.collectibleData then
        return
    end
    if tile.utilityWheel then
        return
    end
    
    if not IsCharacterPreviewingAvailable() or not tile:CanPreview() then
        return
    end

    local collectibleId = tile.collectibleData:GetId()
    if ITEM_PREVIEW_KEYBOARD:IsCurrentlyPreviewing(ZO_ITEM_PREVIEW_COLLECTIBLE, collectibleId) then
        return
    end
        local previewCallback = GetPreviewCallback(tile)
    if not previewCallback then
        return
    end

    if not isFocused then
        if spinPendingTile == tile then
            spinPendingTile = nil
            if not spinning then
                StopWatchingMouseUp()
            end
        end
        if loadedTile == tile then
            Unload()
        end
        if hoveredTile == tile then
            hoveredTile = nil
            if not spinning then
                SetCursorUpdateActive(false)
                UpdateCursor()
            end
        end
        return
    end

    hoveredTile = tile
    SetCursorUpdateActive(true)
    UpdateCursor()
    HookTileMouse(tile)

    if loadedTile then
        Unload()
    end

    loadedTile = tile
    tile.OnUpdate = previewCallback
    EVENT_MANAGER:RegisterForUpdate(UNLOAD_UPDATE, LOAD_REFRESH_MS, Unload, true)
end

local function IsUtilityWheelOpen(book)
    if book and book.pendingUtilityWheelCollectibleData then
        return true
    end
    return GAMEPAD_ACCESSIBLE_ASSIGNABLE_UTILITY_WHEEL_SCENE:IsShowing()
end

local function GetGamepadTargetData(book)
    if not book.currentList then
        return
    end
    return book:GetCurrentTargetData()
end

local function RestoreGamepadUpdate()
    if gamepadLoadedList then
        gamepadLoadedList.OnUpdate = nil
        gamepadLoadedList = nil
    end
end

local function LoadGamepadPreview(book, collectibleId)
    local currentList = book.currentList
    local list = currentList and currentList.list
    if not list then
        return
    end

    if not gamepadPreviewCallback then
        gamepadPreviewCallback = FindDescriptorCallback(book.collectionKeybindStripDescriptor,
            GAMEPAD_PREVIEW_KEYBIND, GetString(SI_COLLECTIBLE_ACTION_PREVIEW))
    end
    if not gamepadPreviewCallback then
        return
    end

    gamepadLoadedList = list
    gamepadLoadedAt = GetFrameTimeSeconds()
    gamepadPreviewedId = collectibleId
    list.OnUpdate = gamepadPreviewCallback
end

local function SetStickSpin(active)
    if active == stickSpinning then
        return
    end
    stickSpinning = active
    if active then
        BeginItemPreviewSpin()
    else
        EndItemPreviewSpin()
    end
end

local function UpdateGamepad()
    local book = GAMEPAD_COLLECTIONS_BOOK
    if not GAMEPAD_COLLECTIONS_BOOK_SCENE:IsShowing() then
        RestoreGamepadUpdate()
        SetStickSpin(false)
        return
    end

    local now = GetFrameTimeSeconds()
    if gamepadLoadedList and now - gamepadLoadedAt >= GAMEPAD_LOAD_TIMEOUT_S then
        RestoreGamepadUpdate()
    end

    local targetData = GetGamepadTargetData(book)
    if targetData ~= gamepadTargetData then
        gamepadTargetData = targetData
        gamepadTargetSince = now
        gamepadPreviewedId = nil
    end

    local wheelOpen = IsUtilityWheelOpen(book)
    if not wheelOpen and not gamepadLoadedList and targetData
        and now - gamepadTargetSince >= GAMEPAD_LOAD_SETTLE_S
        and IsCharacterPreviewingAvailable() and book:CanPreview(targetData) then
        local collectibleId = targetData:GetId()
        if collectibleId ~= gamepadPreviewedId
            and not ITEM_PREVIEW_GAMEPAD:IsCurrentlyPreviewing(ZO_ITEM_PREVIEW_COLLECTIBLE, collectibleId) then
            LoadGamepadPreview(book, collectibleId)
        end
    end

    if wheelOpen or not IsCurrentlyPreviewing() or not CanSpinPreviewCharacter() then
        SetStickSpin(false)
        return
    end
    SetStickSpin(zo_abs(GetGamepadRightStickX(false)) >= STICK_THRESHOLD)
end

local function SetStickUpdateActive(active)
    if active == stickUpdateActive then
        return
    end
    stickUpdateActive = active
    if active then
        EVENT_MANAGER:RegisterForUpdate(STICK_UPDATE, STICK_REFRESH_MS, UpdateGamepad)
    else
        EVENT_MANAGER:UnregisterForUpdate(STICK_UPDATE)
        SetStickSpin(false)
    end
end

local function OnGamepadPreviewEnded()
    SetStickSpin(false)
end

local function StopGamepadActivity()
    SetStickUpdateActive(false)
    RestoreGamepadUpdate()
    gamepadTargetData = nil
    gamepadPreviewedId = nil
end

local function OnGamepadSceneStateChanged(_, newState)
    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
        gamepadTargetData = nil
        gamepadPreviewedId = nil
        SetStickUpdateActive(true)
    elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
        StopGamepadActivity()
    end
end

-- This is mainly to handle players switching back and forth between keyboard/gamepad UI on PC
local keyboardHook
local keyboardOriginalOnFocusChanged

local function InstallKeyboardHooks()
    if keyboardHook then
        return
    end
    keyboardOriginalOnFocusChanged = ZO_PostHook(ZO_CollectibleTile_Keyboard, "OnFocusChanged",
        OnCollectibleTileFocusChanged)
    keyboardHook = ZO_CollectibleTile_Keyboard.OnFocusChanged
    ITEM_PREVIEW_KEYBOARD:RegisterCallback("EndCurrentPreview", EndSpin)
end

local function RemoveKeyboardHooks()
    EndSpin()
    hoveredTile = nil
    Unload()
    SetCursorUpdateActive(false)
    UpdateCursor()
    ITEM_PREVIEW_KEYBOARD:UnregisterCallback("EndCurrentPreview", EndSpin)
    if keyboardHook and ZO_CollectibleTile_Keyboard.OnFocusChanged == keyboardHook then
        ZO_CollectibleTile_Keyboard.OnFocusChanged = keyboardOriginalOnFocusChanged
    end
    keyboardHook = nil
    keyboardOriginalOnFocusChanged = nil
end

local function InstallGamepadHooks()
    GAMEPAD_COLLECTIONS_BOOK_SCENE:UnregisterCallback("StateChange", OnGamepadSceneStateChanged)
    ITEM_PREVIEW_GAMEPAD:UnregisterCallback("EndCurrentPreview", OnGamepadPreviewEnded)
    ITEM_PREVIEW_GAMEPAD:UnregisterCallback("RefreshActions", RestoreGamepadUpdate)
    GAMEPAD_COLLECTIONS_BOOK_SCENE:RegisterCallback("StateChange", OnGamepadSceneStateChanged)
    ITEM_PREVIEW_GAMEPAD:RegisterCallback("EndCurrentPreview", OnGamepadPreviewEnded)
    ITEM_PREVIEW_GAMEPAD:RegisterCallback("RefreshActions", RestoreGamepadUpdate)
end

local function RemoveGamepadHooks()
    StopGamepadActivity()
    GAMEPAD_COLLECTIONS_BOOK_SCENE:UnregisterCallback("StateChange", OnGamepadSceneStateChanged)
    ITEM_PREVIEW_GAMEPAD:UnregisterCallback("EndCurrentPreview", OnGamepadPreviewEnded)
    ITEM_PREVIEW_GAMEPAD:UnregisterCallback("RefreshActions", RestoreGamepadUpdate)
end

local function OnUIChanged(_, gamepadPreferred)
    if gamepadPreferred then
        RemoveKeyboardHooks()
        InstallGamepadHooks()
    else
        RemoveGamepadHooks()
        InstallKeyboardHooks()
    end
end

local function OnLoadHook()
    if ZO_IsConsoleOrGameCoreUI() then
        InstallGamepadHooks()
        return
    end
    if IsInGamepadPreferredMode() then
        InstallGamepadHooks()
    else
        InstallKeyboardHooks()
    end
    EVENT_MANAGER:RegisterForEvent(UI_CHANGE_EVENT, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, OnUIChanged)
end

local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    OnLoadHook()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
