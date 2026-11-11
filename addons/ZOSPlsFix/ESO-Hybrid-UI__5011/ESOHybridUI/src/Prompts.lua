-- Controller glyphs on the keyboard-layout HUD, without switching the platform.

local ADDON = ESOHybridUI
local rt = ADDON.runtime
local NIL_VALUE = {}

-- Glyph/prompt forcing applies only in Hybrid and only when the controller is the
-- real input device (ESO Gamepad Mode On).
function ADDON:ShouldShowControllerPrompts()
    return rt.hybrid == true and self:IsNativeGamepadMode()
end

local function SaveAndSet(object, key, value)
    if type(object) ~= "table" then
        return
    end
    local saved = rt.promptOriginals
    if saved[object] == nil then
        saved[object] = {}
    end
    if saved[object][key] == nil then
        saved[object][key] = object[key] == nil and NIL_VALUE or object[key]
    end
    object[key] = value
end

local function RestoreSavedValues()
    for object, values in pairs(rt.promptOriginals) do
        for key, value in pairs(values) do
            if value == NIL_VALUE then
                object[key] = nil
            else
                object[key] = value
            end
        end
        -- Drop the snapshot after restoration. If ESO rebuilds or updates a
        -- descriptor before the next Hybrid/Legacy switch, the next apply must
        -- capture the current native value rather than this stale snapshot.
        rt.promptOriginals[object] = nil
    end
end

-- Remaps one keybind-strip descriptor. These descriptors belong to ESO and are
-- addressed by position, which a game patch can shift, so every remap is logged
-- (/esohybrid_debug on) and refused when the entry is not a descriptor at all.
local function SetDescriptorKeybind(label, descriptor, keybind)
    if type(descriptor) ~= "table" or descriptor.keybind == nil then
        ADDON:LogDebug("Prompt remap skipped (no keybind at that position):", label)
        return
    end
    ADDON:LogDebug("Prompt remap:", label, tostring(descriptor.keybind), "->", tostring(keybind))
    SaveAndSet(descriptor, "keybind", keybind)
end

local function RemapKnownDescriptors(enabled)
    if not enabled then
        RestoreSavedValues()
        return
    end

    local leftStick = "UI_SHORTCUT_LEFT_STICK"

    if QUEST_JOURNAL_KEYBOARD and QUEST_JOURNAL_KEYBOARD.keybindStripDescriptor then
        SetDescriptorKeybind("quest journal [2]", QUEST_JOURNAL_KEYBOARD.keybindStripDescriptor[2], "UI_SHORTCUT_SECONDARY")
    end
    if ZONE_STORIES_KEYBOARD and ZONE_STORIES_KEYBOARD.keybindStripDescriptor then
        SetDescriptorKeybind("zone stories", ZONE_STORIES_KEYBOARD.keybindStripDescriptor, "UI_SHORTCUT_SECONDARY")
    end
    if GUILD_HOME and GUILD_HOME.keybindStripDescriptor then
        SetDescriptorKeybind("guild home [1]", GUILD_HOME.keybindStripDescriptor[1], leftStick)
    end

    if PLAYER_INVENTORY then
        local groups = {
            { "bank withdraw [3]", PLAYER_INVENTORY.bankWithdrawTabKeybindButtonGroup, 3 },
            { "bank deposit [2]", PLAYER_INVENTORY.bankDepositTabKeybindButtonGroup, 2 },
            { "house bank withdraw [1]", PLAYER_INVENTORY.houseBankWithdrawTabKeybindButtonGroup, 1 },
            { "house bank deposit [1]", PLAYER_INVENTORY.houseBankDepositTabKeybindButtonGroup, 1 },
        }
        for _, entry in ipairs(groups) do
            if entry[2] then
                SetDescriptorKeybind(entry[1], entry[2][entry[3]], leftStick)
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
    for descriptor, original in pairs(rt.stackAllOriginals) do
        descriptor.keybind = original
        rt.stackAllOriginals[descriptor] = nil
    end
end

local function InstallStackAllHook()
    if not ZO_KeybindStrip then
        return false
    end

    local function ProcessGroup(_, group)
        if type(group) ~= "table" then
            return
        end

        if not ADDON:ShouldShowControllerPrompts() then
            for _, descriptor in ipairs(group) do
                local original = rt.stackAllOriginals[descriptor]
                if original then
                    descriptor.keybind = original
                    rt.stackAllOriginals[descriptor] = nil
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
                if rt.stackAllOriginals[descriptor] == nil then
                    rt.stackAllOriginals[descriptor] = descriptor.keybind
                end
                descriptor.keybind = "UI_SHORTCUT_LEFT_STICK"
            end
        end
    end

    -- Hook the shared class so every strip instance gets the remap.
    ZO_PreHook(ZO_KeybindStrip, "AddKeybindButtonGroup", ProcessGroup)
    ZO_PreHook(ZO_KeybindStrip, "UpdateKeybindButtonGroup", ProcessGroup)
    return true
end

-- ESO's keybinding helpers decide which device's binding to resolve and whether
-- gamepad glyphs show. They return values, so a pre-hook cannot replace them:
-- wrap each original and forward every argument when Hybrid is not active.
local function InstallGlobalPromptHooks()
    local originalShouldUseGamepadAction = _G.ZO_Keybindings_ShouldUseGamepadAction
    local originalGetPreferredKeyType = _G.ZO_Keybindings_GetPreferredKeyType
    local originalShouldShowGamepadKeybind = _G.ZO_Keybindings_ShouldShowGamepadKeybind
    if not (originalShouldUseGamepadAction and originalGetPreferredKeyType and originalShouldShowGamepadKeybind) then
        return false
    end

    _G.ZO_Keybindings_ShouldUseGamepadAction = function(alwaysPreferGamepadMode, ...)
        if ADDON:ShouldShowControllerPrompts() and alwaysPreferGamepadMode ~= false then return true end
        return originalShouldUseGamepadAction(alwaysPreferGamepadMode, ...)
    end

    _G.ZO_Keybindings_GetPreferredKeyType = function(alwaysPreferGamepadMode, ...)
        if ADDON:ShouldShowControllerPrompts() and alwaysPreferGamepadMode ~= false then
            return PREFERRED_INPUT_DEVICE_TYPE_GAMEPAD
        end
        return originalGetPreferredKeyType(alwaysPreferGamepadMode, ...)
    end

    _G.ZO_Keybindings_ShouldShowGamepadKeybind = function(alwaysPreferGamepadMode, ...)
        if ADDON:ShouldShowControllerPrompts() and alwaysPreferGamepadMode ~= false then return true end
        return originalShouldShowGamepadKeybind(alwaysPreferGamepadMode, ...)
    end
    return true
end

local function InstallDeathPromptHook()
    if not DEATH or not DEATH.ApplyStyle then
        return false
    end

    local originalApplyStyle = DEATH.ApplyStyle
    ZO_PreHook(DEATH, "ApplyStyle", function(death, ...)
        if ADDON:ShouldShowControllerPrompts() then
            -- No meaningful return value: run the native-gamepad template
            -- selection ourselves and suppress the duplicate original call.
            ADDON:WithNativeGamepadMode(originalApplyStyle, death, ...)
            return true
        end
        return false
    end)
    return true
end

local function RefreshReticlePrompt()
    if not RETICLE or not RETICLE.interactKeybindButton then
        return
    end
    RETICLE.interactKeybindButton:SetKeybind("GAME_CAMERA_INTERACT", false, "GAMEPAD_JUMP_OR_INTERACT")
end

local function ApplyReticleFonts(forceGamepadPrompts)
    -- Re-apply the correct native style when leaving Hybrid as well. Returning
    -- early here left the addon's custom fonts on the reticle/stealth icon after
    -- switching to full Gamepad mode.
    local nativeGamepadStyle = IsInGamepadPreferredMode()
    local nativeFont = nativeGamepadStyle and "ZoFontGamepad42" or "ZoInteractionPrompt"
    local nativeStealthFont = nativeGamepadStyle and "ZoFontGamepad36" or "ZoInteractionPrompt"
    local contextFont = forceGamepadPrompts and ADDON:GetFont("reticleContext") or nativeFont

    if RETICLE and RETICLE.ApplyPlatformStyle and ZO_ShallowTableCopy then
        -- Hybrid keeps the keyboard prompt layout and only changes glyph
        -- resolution; full Gamepad mode uses ESO's native gamepad prompt style.
        local sourceStyle = nativeGamepadStyle and KEYBIND_STRIP_GAMEPAD_STYLE or KEYBIND_STRIP_STANDARD_STYLE
        if sourceStyle then
            local keybindStyle = ZO_ShallowTableCopy(sourceStyle)
            if forceGamepadPrompts then
                keybindStyle.nameFont = ADDON:GetFont("reticle")
            end
            keybindStyle.alwaysPreferGamepadMode = forceGamepadPrompts or nativeGamepadStyle
            RETICLE:ApplyPlatformStyle({
                font = contextFont,
                keybindButtonStyle = keybindStyle,
            })
        end
    end

    local stealthStyle = {
        font = forceGamepadPrompts and ADDON:GetFont("stealthIcon") or nativeStealthFont,
    }
    if RETICLE and RETICLE.stealthIcon and RETICLE.stealthIcon.ApplyPlatformStyle then
        RETICLE.stealthIcon:ApplyPlatformStyle(stealthStyle)
    end
    if LOCK_PICK and LOCK_PICK.stealthIcon and LOCK_PICK.stealthIcon.ApplyPlatformStyle then
        LOCK_PICK.stealthIcon:ApplyPlatformStyle(stealthStyle)
    end
end

function ADDON:ApplyPrompts()
    if not KEYBIND_STRIP_STANDARD_STYLE then
        return
    end

    local forceGamepadPrompts = self:ShouldShowControllerPrompts()

    self:InstallWhenReady("globalPromptHooks", InstallGlobalPromptHooks)
    self:InstallWhenReady("stackAllHook", InstallStackAllHook)
    self:InstallWhenReady("deathPromptHook", InstallDeathPromptHook)

    if not forceGamepadPrompts then
        RestoreStackAllMappings()
    end
    -- Keep the strip's native platform layout, but force controller glyph
    -- resolution on the keyboard HUD while Hybrid is active.
    local baseStripStyle = IsInGamepadPreferredMode()
        and KEYBIND_STRIP_GAMEPAD_STYLE or KEYBIND_STRIP_STANDARD_STYLE
    RemapKnownDescriptors(forceGamepadPrompts and not rt.menusGamepad)
    ApplyReticleFonts(forceGamepadPrompts)
    RefreshReticlePrompt()

    if KEYBIND_STRIP and KEYBIND_STRIP.SetStyle and ZO_ShallowTableCopy then
        local stripStyle = ZO_ShallowTableCopy(baseStripStyle)
        stripStyle.alwaysPreferGamepadMode = forceGamepadPrompts or IsInGamepadPreferredMode()
        KEYBIND_STRIP:SetStyle(stripStyle)
    end
end
