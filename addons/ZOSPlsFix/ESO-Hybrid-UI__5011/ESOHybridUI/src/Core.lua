-- Core: separates controller input preference from the UI's preferred platform.

local ADDON = ESOHybridUI

local function DeepCopy(source)
    if type(source) ~= "table" then
        return source
    end
    local target = {}
    -- DeepCopy is used for ordinary nested settings tables. Never pass a
    -- ZO_SavedVars profile proxy here: its fields are exposed through __index
    -- and are not enumerable.
    for key, value in pairs(source) do
        target[key] = DeepCopy(value)
    end
    return target
end

local function CopyProfileSettings(source, target)
    if type(source) ~= "table" or type(target) ~= "table" then
        return false
    end

    -- ZO_SavedVars returns a proxy. pairs(source) does not enumerate the
    -- saved profile behind that proxy, so copy only keys from our plain
    -- defaults table and read each value through the proxy's __index.
    for key in pairs(ADDON.defaults) do
        local value = source[key]
        if value ~= nil then
            target[key] = DeepCopy(value)
        end
    end
    return true
end

local function OriginalGamepadPreferredMode()
    return ADDON.runtime.originalIsInGamepadPreferredMode()
end

local function GetSettings()
    -- Do not fall back to the defaults merely because one saved-variable
    -- profile failed to initialize. That would make settings appear to work
    -- for the session while every change was written only to the defaults
    -- table and lost at logout.
    if ADDON.savedVariablesAccountWide
        and ADDON.savedVariablesAccountWide._esoHybridUseAccountWideSettings == true then
        return ADDON.savedVariablesAccountWide
    end
    if ADDON.savedVariables then
        return ADDON.savedVariables
    end
    if ADDON.savedVariablesAccountWide then
        return ADDON.savedVariablesAccountWide
    end
    return ADDON.defaults
end

function ADDON:GetSettings()
    return GetSettings()
end

function ADDON:ApplyRecommendedESOSettings()
    local saveOption = SETTINGS_SET_OPTION_SAVE_TO_PERSISTED_DATA

    SetSetting(
        SETTING_TYPE_GAMEPAD,
        GAMEPAD_SETTING_INPUT_PREFERRED_MODE,
        tostring(INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD),
        saveOption
    )
    SetSetting(
        SETTING_TYPE_GAMEPAD,
        GAMEPAD_SETTING_KEYBIND_DISPLAY_MODE,
        tostring(KEYBIND_DISPLAY_MODE_ALWAYS_GAMEPAD),
        saveOption
    )
    SetSetting(
        SETTING_TYPE_GAMEPAD,
        GAMEPAD_SETTING_USE_KEYBOARD_CHAT,
        "1",
        saveOption
    )
    SetSetting(
        SETTING_TYPE_UI,
        UI_SETTING_RETURN_CURSOR_ON_CHAT_FOCUS,
        "1",
        saveOption
    )

    self:LogInfo("Recommended ESO controller and keyboard-chat settings applied and saved.")

    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("[ESO Hybrid UI] Recommended ESO settings applied and saved. Gamepad Mode, Gamepad keybinds, Keyboard Chat, and cursor-on-chat-focus are enabled.")
    end
end

function ADDON:IsNativeGamepadMode()
    return OriginalGamepadPreferredMode()
end

function ADDON:WithNativeGamepadMode(callback, ...)
    local runtime = ADDON.runtime
    runtime.forceNativeModeDepth = runtime.forceNativeModeDepth + 1

    local function Pack(...) return { n = select("#", ...), ... } end
    local results = Pack(pcall(callback, ...))
    runtime.forceNativeModeDepth = math.max(0, runtime.forceNativeModeDepth - 1)

    if not results[1] then
        error(results[2], 0)
    end
    return unpack(results, 2, results.n)
end

function ADDON:WithKeyboardWheelMode(callback, ...)
    local runtime = ADDON.runtime
    runtime.forceKeyboardWheelDepth = runtime.forceKeyboardWheelDepth + 1

    local function Pack(...) return { n = select("#", ...), ... } end
    local results = Pack(pcall(callback, ...))
    runtime.forceKeyboardWheelDepth = math.max(0, runtime.forceKeyboardWheelDepth - 1)

    if not results[1] then
        error(results[2], 0)
    end
    return unpack(results, 2, results.n)
end

local function IsGamepadUIAllowed()
    if ADDON.runtime.forceNativeModeDepth > 0 then
        return OriginalGamepadPreferredMode()
    end

    -- A wheel is a deliberate exception: Hybrid uses ESO's keyboard wheel
    -- presentation while keeping the surrounding menus in native gamepad mode.
    if ADDON.runtime.forceKeyboardWheelDepth > 0 then
        return false
    end

    local settings = GetSettings()
    if settings.useControllerUI then
        return OriginalGamepadPreferredMode()
    end

    -- Loot containers have a dedicated native gamepad scene, but ESO can
    -- request the keyboard scene while Hybrid mode keeps the gameplay HUD in
    -- keyboard presentation. Preserve the native controller loot workflow.
    if (settings.useHybridUI or settings.useGamepadButtons)
        and OriginalGamepadPreferredMode()
        and GetInteractionType() == INTERACTION_LOOT then
        return true
    end

    -- Lockpicking is part of Hybrid's controller-first interaction model:
    -- keep ESO's native gamepad lockpicking scene while preserving the
    -- compact keyboard-style gameplay HUD.
    if settings.useHybridUI
        and ADDON.runtime.isLockpicking
        and OriginalGamepadPreferredMode() then
        return true
    end

    -- In Hybrid mode, ESO's own UI-mode state selects native gamepad menus,
    -- while the base gameplay HUD remains on the compact keyboard platform.
    if settings.useHybridUI then
        -- Keep the combat/world HUD on the compact keyboard platform, but let
        -- the world map opt into ESO's native gamepad map presentation even
        -- though opening the map does not necessarily enter UI mode.
        local worldMapShowing = WORLD_MAP_SCENE:IsShowing()
        if worldMapShowing then
            return OriginalGamepadPreferredMode()
        end

        -- UI mode alone is not enough: ESO also enters UI mode on focus
        -- loss while showing its base HUD-UI scene. Only use gamepad styling
        -- for an actual menu/overlay scene, not for the base HUD scene.
        local inUIMode = SCENE_MANAGER
            and SCENE_MANAGER.IsInUIMode
            and SCENE_MANAGER:IsInUIMode()
        local showingBaseScene = SCENE_MANAGER
            and SCENE_MANAGER.IsShowingBaseScene
            and SCENE_MANAGER:IsShowingBaseScene()
        return OriginalGamepadPreferredMode() and inUIMode and not showingBaseScene
    end

    return false
end

local function InstallModeOverride()
    local runtime = ADDON.runtime
    -- Hybrid must replace the boolean result returned to every ESO caller.
    -- A normal ZO_PreHook cannot supply a replacement return value while
    -- suppressing the original, so preserve and wrap the original function.
    -- The identity check below avoids silently overwriting a later addon hook.
    if runtime.modeOverrideInstalled then
        -- Do not repeatedly overwrite another addon's later wrapper whenever
        -- ESO emits a gamepad-mode event. Direct return-value control is
        -- required for Hybrid, so this one global interception is intentional.
        if _G.IsInGamepadPreferredMode ~= IsGamepadUIAllowed then
            ADDON:LogWarn("IsInGamepadPreferredMode was replaced after Hybrid UI installed; another addon may be overriding the platform mode.")
            return false
        end
        return true
    end

    runtime.originalIsInGamepadPreferredMode = IsInGamepadPreferredMode
    _G.IsInGamepadPreferredMode = IsGamepadUIAllowed
    runtime.modeOverrideInstalled = true
    return true
end

local function IsShowingBaseHUDScene()
    return SCENE_MANAGER
        and SCENE_MANAGER.IsShowingBaseScene
        and SCENE_MANAGER:IsShowingBaseScene()
end

local function RefreshPlatformMode()
    local runtime = ADDON.runtime
    if runtime.isRefreshing then
        return false
    end

    -- Changing GAMEPAD_SETTING_INPUT_PREFERRED_MODE while a gamepad menu is
    -- current makes ESO's IngameSceneManager compare that menu's original
    -- input mode with the temporary mode. It can close the menu and return
    -- to the HUD. Never emit the mode-change event from an overlay/menu.
    if not IsShowingBaseHUDScene() then
        runtime.platformRefreshPending = true
        return false
    end

    -- PLATFORM_STYLE_MANAGER is private to ESO's platform-style library and
    -- has no public refresh method. The supported event is emitted by changing
    -- the preferred-mode setting. At the base HUD scene, ESO's scene manager
    -- will not replace the scene in response to that event. Restore the exact
    -- saved value immediately; this is a presentation refresh, not a setting.
    local currentMode = GetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE)
    local currentNumeric = tonumber(currentMode)
    local temporaryMode = currentNumeric == INPUT_PREFERRED_MODE_ALWAYS_KEYBOARD
        and INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD
        or INPUT_PREFERRED_MODE_ALWAYS_KEYBOARD

    runtime.isRefreshing = true
    local changed, changeError = pcall(
        SetSetting,
        SETTING_TYPE_GAMEPAD,
        GAMEPAD_SETTING_INPUT_PREFERRED_MODE,
        tostring(temporaryMode)
    )
    local restored, restoreError = pcall(
        SetSetting,
        SETTING_TYPE_GAMEPAD,
        GAMEPAD_SETTING_INPUT_PREFERRED_MODE,
        tostring(currentMode)
    )
    runtime.isRefreshing = false

    if not changed or not restored then
        runtime.platformRefreshPending = true
        ADDON:LogError("Could not refresh platform styles:", tostring(changeError or restoreError))
        return false
    end

    runtime.platformRefreshPending = false
    return true
end

function ADDON:Refresh()
    self:LogDebug("Refreshing UI presentation.")
    InstallModeOverride()

    self:ApplyAll()

    -- If called from a settings/menu scene, defer the native platform-style
    -- refresh. The scene callback below performs it after the base HUD returns.
    RefreshPlatformMode()
end

function ADDON:ApplyAll()
    self:LogDebug("Applying prompt styles.")
    self:ApplyPrompts()
    self:LogDebug("Applying dialog styles.")
    self:ApplyDialogs()
    self:LogDebug("Applying utility-wheel bridge.")
    self:ApplyUtilityWheel()
    self:LogDebug("Applying action-bar style.")
    self:ApplyActionBar()
    self:LogDebug("Applying world-map behavior.")
    self:ApplyWorldMap()
end

function ADDON:SetUseAccountWideSettings(enabled)
    local character = self.savedVariables
    local account = self.savedVariablesAccountWide

    if not character or not account then
        self:LogError("Cannot change settings scope: ESO SavedVariables profiles are not initialized.")
        return
    end

    if enabled and account._esoHybridUseAccountWideSettings == nil then
        -- Seed the account profile only on its first-ever activation. If the
        -- player temporarily disables account-wide settings and later enables
        -- them again, preserve the shared profile instead of overwriting it
        -- with this character's local settings.
        CopyProfileSettings(character, account)
    end

    if not enabled then
        -- Preserve the account profile on this character before switching
        -- back to character-specific settings.
        CopyProfileSettings(account, character)
    end

    -- The scope selector is account-wide, not character-specific. Once one
    -- character enables it, every character on this ESO account uses the
    -- same account profile without requiring a separate opt-in.
    account._esoHybridUseAccountWideSettings = enabled == true
    self:Refresh()
end

function ADDON:ToggleUI()
    local settings = GetSettings()
    -- Keyboard mode is intentionally not offered: this addon is for
    -- controller users. The toggle switches between native Gamepad and Hybrid.
    settings.useHybridUI = not settings.useHybridUI
    settings.useControllerUI = not settings.useHybridUI
    settings.useGamepadButtons = true
    self:LogInfo("UI mode toggled:", settings.useHybridUI and "Hybrid" or "Gamepad")
    self:Refresh()
end

local function InitializeSavedVariables()
    -- Character IDs already include a server prefix. Account-wide profiles do
    -- not, so namespace them by megaserver to keep EU, NA, and PTS settings
    -- separate while preserving the old un-namespaced profile for migration.
    local legacyAccountProfile = ZO_SavedVars:NewAccountWide(
        ADDON.SAVED_VARIABLES,
        ADDON.SAVED_VARIABLES_VERSION,
        nil,
        ADDON.defaults
    )

    ADDON.savedVariablesAccountWide = ZO_SavedVars:NewAccountWide(
        ADDON.SAVED_VARIABLES,
        ADDON.SAVED_VARIABLES_VERSION,
        GetWorldName(),
        ADDON.defaults
    )

    ADDON.savedVariables = ZO_SavedVars:NewCharacterIdSettings(
        ADDON.SAVED_VARIABLES,
        ADDON.SAVED_VARIABLES_VERSION,
        nil,
        ADDON.defaults
    )

    -- Migrate the old shared account profile into this megaserver's profile
    -- once. Keep the legacy data intact so this update is non-destructive.
    local account = ADDON.savedVariablesAccountWide
    if not account._esoHybridServerProfileMigrated then
        CopyProfileSettings(legacyAccountProfile, account)
        account._esoHybridUseAccountWideSettings = legacyAccountProfile._esoHybridUseAccountWideSettings
        account._esoHybridWelcomeShown = legacyAccountProfile._esoHybridWelcomeShown
        account._esoHybridServerProfileMigrated = true
    end

    -- This addon now supports controller UI modes only. Convert old Keyboard
    -- profiles to native Gamepad mode while preserving existing Hybrid choices.
    local function NormalizeControllerMode(profile)
        if type(profile) ~= "table" then return end
        profile.useControllerUI = profile.useHybridUI ~= true
        profile.useGamepadButtons = true
    end
    NormalizeControllerMode(ADDON.savedVariables)
    NormalizeControllerMode(ADDON.savedVariablesAccountWide)

    local raw = _G[ADDON.SAVED_VARIABLES]
    if type(raw) ~= "table" then
        ADDON:LogError("ESO did not create the declared SavedVariables root table.")
    else
        ADDON:LogInfo("SavedVariables initialized. Account and character profiles are available.")
    end
end

local function PrintStatus()
    local settings = GetSettings()
    local uiMode = settings.useHybridUI and "hybrid UI" or "native gamepad UI"
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("[ESO Hybrid UI] " .. uiMode .. " | controller prompts enabled")
    end
end

local function RegisterSlashCommands()
    SLASH_COMMANDS["/esohybrid"] = function()
        ADDON:ToggleUI()
        PrintStatus()
    end
    SLASH_COMMANDS["/esohybrid_status"] = PrintStatus
    SLASH_COMMANDS["/esohybrid_sv"] = function()
        local raw = _G[ADDON.SAVED_VARIABLES]
        local account = ADDON.savedVariablesAccountWide
        local character = ADDON.savedVariables
        local accountWide = account and account._esoHybridUseAccountWideSettings == true
        local message = string.format(
            "[ESO Hybrid UI] SV root=%s | account profile=%s | character profile=%s | account-wide=%s",
            type(raw),
            type(account),
            type(character),
            tostring(accountWide)
        )
        if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then CHAT_SYSTEM:AddMessage(message) end
        ADDON:LogInfo(message)
    end
end

local function ShowFirstInstallWelcome()
    local account = ADDON.savedVariablesAccountWide
    if not account or account._esoHybridWelcomeShown then
        return
    end

    -- Save the flag before showing the dialog so reloads cannot show it twice.
    account._esoHybridWelcomeShown = true

    local dialogName = "ESOHYBRIDUI_FIRST_INSTALL"
    ZO_Dialogs_RegisterCustomDialog(dialogName, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "Welcome to ESO Hybrid UI" },
        mainText = {
            text = "Open ESO Hybrid UI settings and click Apply Recommended ESO Settings once. This configures Gamepad Mode On, Gamepad keybind display, Keyboard Chat, and the mouse cursor when chat receives focus. Then choose Gamepad or Hybrid. You can apply the settings again later if needed.",
        },
        buttons = {
            { text = "Got it" },
        },
    })
    ZO_Dialogs_ShowDialog(dialogName)
end

local function OnLockpickBegin()
    ADDON.runtime.isLockpicking = true
    ADDON:LogDebug("Lockpicking began.")
    ADDON:Refresh()
end

local function OnLockpickEnd()
    if not ADDON.runtime.isLockpicking then
        return
    end
    ADDON.runtime.isLockpicking = false
    ADDON:LogDebug("Lockpicking ended.")
    ADDON:Refresh()
end

local function OnGamepadPreferredModeChanged()
    -- RefreshPlatformMode deliberately emits two native mode-change events
    -- to make ESO reapply its private platform-style manager. The addon's own
    -- modules were already refreshed before that operation, so avoid applying
    -- them twice (and avoid re-registering keybind labels during the flip).
    if ADDON.runtime.isRefreshing then
        return
    end

    ADDON:LogDebug("ESO gamepad-preferred-mode event received. Physical gamepad preference:", tostring(OriginalGamepadPreferredMode()))
    InstallModeOverride()
    if ADDON.ApplyAll then
        ADDON:ApplyAll()
    end
end


local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON.ADDON_NAME or ADDON.runtime.initialized then
        return
    end

    InitializeSavedVariables()
    ADDON:InitializeDiagnostics()
    ADDON:RegisterDiagnosticCommands()
    ADDON:LogInfo("Initializing addon", ADDON.VERSION)
    InstallModeOverride()

    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_LockpickBegin", EVENT_BEGIN_LOCKPICK, OnLockpickBegin)
    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_LockpickSuccess", EVENT_LOCKPICK_SUCCESS, OnLockpickEnd)
    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_LockpickFailed", EVENT_LOCKPICK_FAILED, OnLockpickEnd)
    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_ModeChanged", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, OnGamepadPreferredModeChanged)
    -- SceneStateChanged fires for the menu scene as it hides too. Listen to
    -- all scene transitions rather than only hud/hudui becoming SHOWN: HUD
    -- may have remained shown underneath a stacked settings scene and receive
    -- no new SHOWN event when it becomes current again. The delayed base-scene
    -- check handles both that case and focus loss (which shows hudui).
    if SCENE_MANAGER and SCENE_MANAGER.RegisterCallback then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
            if newState ~= SCENE_SHOWN and newState ~= SCENE_HIDDEN then
                return
            end

            local settings = GetSettings()
            if not ADDON.runtime.platformRefreshPending and not settings.useHybridUI then
                return
            end

            -- Scene transitions can arrive in bursts while menus stack or
            -- close. Coalesce them into one deferred base-HUD refresh.
            if ADDON.runtime.platformRefreshScheduled then
                return
            end
            ADDON.runtime.platformRefreshScheduled = true
            zo_callLater(function()
                ADDON.runtime.platformRefreshScheduled = false
                if ADDON.runtime.initialized
                    and IsShowingBaseHUDScene()
                    and (ADDON.runtime.platformRefreshPending or GetSettings().useHybridUI) then
                    ADDON:LogDebug("Refreshing platform styles after returning to the base HUD scene.")
                    RefreshPlatformMode()
                end
            end, 100)
        end)
    end


    local function OnLockpickSceneStateChanged(_, newState)
        if newState == SCENE_HIDDEN then
            OnLockpickEnd()
        end
    end

    if LOCK_PICK_SCENE and LOCK_PICK_SCENE.RegisterCallback then
        LOCK_PICK_SCENE:RegisterCallback("StateChange", OnLockpickSceneStateChanged)
    end
    if LOCK_PICK_GAMEPAD_SCENE and LOCK_PICK_GAMEPAD_SCENE.RegisterCallback then
        LOCK_PICK_GAMEPAD_SCENE:RegisterCallback("StateChange", OnLockpickSceneStateChanged)
    end

    RegisterSlashCommands()

    ADDON:RegisterSettings()

    ADDON.runtime.initialized = true
    ADDON:Refresh()

    ShowFirstInstallWelcome()

    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("[ESO Hybrid UI] " .. ADDON.VERSION .. " loaded. Use /esohybrid to switch between Gamepad and Hybrid. Debug: /esohybrid_debug on, snapshot: /esohybrid_dump.")
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON.ADDON_NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ESOHybridUI.ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
