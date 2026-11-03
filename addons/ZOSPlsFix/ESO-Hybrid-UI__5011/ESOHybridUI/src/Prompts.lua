-- Gamepad glyphs on keyboard-style UI, without switching the entire UI platform.

local ADDON = ESOHybridUI
local NIL_VALUE = {}

local function SaveAndSet(object, key, value)
    if type(object) ~= "table" then
        return
    end
    local saved = ADDON.runtime.promptOriginals
    if saved[object] == nil then saved[object] = {} end
    if saved[object][key] == nil then
        saved[object][key] = object[key] == nil and NIL_VALUE or object[key]
    end
    object[key] = value
end

local function RestoreSavedValues()
    for object, values in pairs(ADDON.runtime.promptOriginals) do
        for key, value in pairs(values) do
            if value == NIL_VALUE then
                object[key] = nil
            else
                object[key] = value
            end
        end
    end
end

local function SetDescriptorKeybind(descriptor, keybind)
    if type(descriptor) ~= "table" or descriptor.keybind == nil then
        return
    end
    SaveAndSet(descriptor, "keybind", keybind)
end

local function RemapKnownDescriptors(enabled)
    local map = enabled and "UI_SHORTCUT_LEFT_STICK" or nil

    if not enabled then
        RestoreSavedValues()
        return
    end

    if QUEST_JOURNAL_KEYBOARD and QUEST_JOURNAL_KEYBOARD.keybindStripDescriptor then
        SetDescriptorKeybind(QUEST_JOURNAL_KEYBOARD.keybindStripDescriptor[2], "UI_SHORTCUT_SECONDARY")
    end
    if ZONE_STORIES_KEYBOARD and ZONE_STORIES_KEYBOARD.keybindStripDescriptor then
        SetDescriptorKeybind(ZONE_STORIES_KEYBOARD.keybindStripDescriptor, "UI_SHORTCUT_SECONDARY")
    end
    if GUILD_HOME and GUILD_HOME.keybindStripDescriptor then
        SetDescriptorKeybind(GUILD_HOME.keybindStripDescriptor[1], "UI_SHORTCUT_LEFT_STICK")
    end

    if PLAYER_INVENTORY then
        local groups = {
            { PLAYER_INVENTORY.bankWithdrawTabKeybindButtonGroup, 3 },
            { PLAYER_INVENTORY.bankDepositTabKeybindButtonGroup, 2 },
            { PLAYER_INVENTORY.houseBankWithdrawTabKeybindButtonGroup, 1 },
            { PLAYER_INVENTORY.houseBankDepositTabKeybindButtonGroup, 1 },
        }
        for _, entry in ipairs(groups) do
            if entry[1] then
                SetDescriptorKeybind(entry[1][entry[2]], map)
            end
        end
    end

    if LOCK_PICK and LOCK_PICK.keybindStripDescriptor then
        local descriptor = LOCK_PICK.keybindStripDescriptor[4]
        if descriptor then
            SaveAndSet(descriptor, "alignment", KEYBIND_STRIP_ALIGN_RIGHT)
        end
    end
end

local function RestoreStackAllMappings()
    for descriptor, original in pairs(ADDON.runtime.stackAllOriginals) do
        descriptor.keybind = original
        ADDON.runtime.stackAllOriginals[descriptor] = nil
    end
end

local function HookStackAllMapping()
    if ADDON.runtime.promptHooksInstalled then
        return
    end

    local function ProcessGroup(_, group)
        if type(group) ~= "table" then return end
        local enabled = ADDON:ShouldShowControllerPrompts()
        if not enabled then
            for _, descriptor in ipairs(group) do
                local original = ADDON.runtime.stackAllOriginals[descriptor]
                if original then
                    descriptor.keybind = original
                    ADDON.runtime.stackAllOriginals[descriptor] = nil
                end
            end
            return
        end

        local sceneName = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
        if sceneName ~= "store" and sceneName ~= "inventory" and sceneName ~= "fence_keyboard" then
            return
        end

        for _, descriptor in ipairs(group) do
            if descriptor.keybind == "UI_SHORTCUT_STACK_ALL" then
                if ADDON.runtime.stackAllOriginals[descriptor] == nil then
                    ADDON.runtime.stackAllOriginals[descriptor] = descriptor.keybind
                end
                descriptor.keybind = "UI_SHORTCUT_LEFT_STICK"
            end
        end
    end

    -- Hook the shared class so existing and future keybind-strip instances
    -- receive the same descriptor remapping without shadowing one instance.
    ZO_PreHook(ZO_KeybindStrip, "AddKeybindButtonGroup", ProcessGroup)
    ZO_PreHook(ZO_KeybindStrip, "UpdateKeybindButtonGroup", ProcessGroup)
    ADDON.runtime.promptHooksInstalled = true
end

local function ShouldForceControllerPrompts()
    local settings = ADDON:GetSettings()
    return (settings.useHybridUI == true or settings.useGamepadButtons == true)
        and settings.useControllerUI ~= true
        and ADDON:IsNativeGamepadMode()
end

function ADDON:ShouldShowControllerPrompts()
    return ShouldForceControllerPrompts()
end

local function InstallGlobalPromptHooks()
    local runtime = ADDON.runtime
    if runtime.globalPromptHooksInstalled then return end

    -- ESO's shared keybinding helpers decide which input device's binding to
    -- resolve and whether controller glyphs should be displayed. Override
    -- those decisions centrally whenever controller prompts are enabled.
    -- These helpers return booleans/enums; a pre-hook cannot replace those
    -- return values while suppressing the original implementation. Preserve
    -- each original function and forward all arguments when Hybrid is off.
    local originalShouldUseGamepadAction = ZO_Keybindings_ShouldUseGamepadAction
    _G.ZO_Keybindings_ShouldUseGamepadAction = function(alwaysPreferGamepadMode, ...)
        if ShouldForceControllerPrompts() then return true end
        return originalShouldUseGamepadAction(alwaysPreferGamepadMode, ...)
    end

    local originalGetPreferredKeyType = ZO_Keybindings_GetPreferredKeyType
    _G.ZO_Keybindings_GetPreferredKeyType = function(alwaysPreferGamepadMode, ...)
        if ShouldForceControllerPrompts() then
            return PREFERRED_INPUT_DEVICE_TYPE_GAMEPAD
        end
        return originalGetPreferredKeyType(alwaysPreferGamepadMode, ...)
    end

    local originalShouldShowGamepadKeybind = ZO_Keybindings_ShouldShowGamepadKeybind
    _G.ZO_Keybindings_ShouldShowGamepadKeybind = function(alwaysPreferGamepadMode, ...)
        if ShouldForceControllerPrompts() then return true end
        return originalShouldShowGamepadKeybind(alwaysPreferGamepadMode, ...)
    end

    runtime.globalPromptHooksInstalled = true
end

local function InstallDeathPromptHook()
    local runtime = ADDON.runtime
    if runtime.deathPromptHookInstalled or not DEATH then
        return
    end

    local originalApplyStyle = DEATH.ApplyStyle
    ZO_PreHook(DEATH, "ApplyStyle", function(death, ...)
        if ShouldForceControllerPrompts() then
            -- The death-style refresh has no meaningful return value.
            -- Preserve its native gamepad template selection without
            -- replacing the shared DEATH method.
            ADDON:WithNativeGamepadMode(originalApplyStyle, death, ...)
            return true
        end
        return false
    end)
    runtime.deathPromptHookInstalled = true
end

local function RefreshReticlePrompt()
    if not RETICLE or not RETICLE.interactKeybindButton then return end
    local button = RETICLE.interactKeybindButton
    button:SetKeybind("GAME_CAMERA_INTERACT", false, "GAMEPAD_JUMP_OR_INTERACT")
end

local function RefreshPlayerInteractionPrompt()
    if not PLAYER_TO_PLAYER or not PLAYER_TO_PLAYER.actionKeybindButton then return end
    local button = PLAYER_TO_PLAYER.actionKeybindButton
    -- Keep the same action so ESO resolves the user's actual configured
    -- gamepad binding (including hold/chord combinations) instead of
    -- displaying the generic A-button glyph from GAMEPAD_JUMP_OR_INTERACT.
    button:SetKeybind("PLAYER_TO_PLAYER_INTERACT", false, nil)
end

local function ApplyReticleFonts(settings, forceGamepadPrompts)
    if settings.useControllerUI or not ADDON:IsNativeGamepadMode() then
        return
    end
    if RETICLE and RETICLE.ApplyPlatformStyle and ZO_ShallowTableCopy and KEYBIND_STRIP_STANDARD_STYLE then
        local keybindStyle = ZO_ShallowTableCopy(KEYBIND_STRIP_STANDARD_STYLE)
        keybindStyle.nameFont = settings.fonts.reticle
        keybindStyle.alwaysPreferGamepadMode = forceGamepadPrompts
        RETICLE:ApplyPlatformStyle({
            font = settings.fonts.reticleContext,
            keybindButtonStyle = keybindStyle,
        })
    end

    local stealthStyle = { font = settings.fonts.stealthIcon }
    if RETICLE and RETICLE.stealthIcon and RETICLE.stealthIcon.ApplyPlatformStyle then
        RETICLE.stealthIcon:ApplyPlatformStyle(stealthStyle)
    end
    if LOCK_PICK and LOCK_PICK.stealthIcon and LOCK_PICK.stealthIcon.ApplyPlatformStyle then
        LOCK_PICK.stealthIcon:ApplyPlatformStyle(stealthStyle)
    end
end

function ADDON:ApplyPrompts()
    local settings = self:GetSettings()
    if not KEYBIND_STRIP_STANDARD_STYLE then
        return
    end

    -- Hybrid's defining contract is a keyboard HUD with controller glyphs.
    -- The standalone prompt toggle must not accidentally turn those glyphs
    -- back into keyboard labels while Hybrid is active.
    local forceGamepadPrompts = self:ShouldShowControllerPrompts()

    InstallGlobalPromptHooks()
    KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode = forceGamepadPrompts
    if not forceGamepadPrompts then
        RestoreStackAllMappings()
    end
    RemapKnownDescriptors(forceGamepadPrompts)
    HookStackAllMapping()
    ApplyReticleFonts(settings, forceGamepadPrompts)
    InstallDeathPromptHook()
    RefreshReticlePrompt()
    RefreshPlayerInteractionPrompt()

    if KEYBIND_STRIP and KEYBIND_STRIP.SetStyle then
        KEYBIND_STRIP:SetStyle(KEYBIND_STRIP_STANDARD_STYLE)
    end
end

