-- Policy: the one decision "should ESO treat the UI as gamepad right now?".
--
-- ESO asks IsInGamepadPreferredMode() whenever it builds an element, selects a
-- scene or resolves a keybind. Hybrid replaces that global with a wrapper that can
-- answer differently per context while the real input device stays the controller.
--
-- Important ESO fact (from its source): the platform of a menu, shop, bank,
-- crafting station, housing editor or screenshot mode is chosen at the moment it is
-- opened (ZO_UISystemManager:OpenPlatformUISystem, SYSTEMS:GetObject ...), and
-- that moment is usually spent on the base HUD. So "answer false on the HUD" also
-- makes ESO pick the KEYBOARD version of everything opened from the HUD.
--
--   Gamepad mode        : answer is the game's own (untouched).
--   Hybrid, policy
--   "gamepad" (default) : base HUD -> keyboard; menus are explicitly opened under
--                         WithNativeGamepadMode and remain native once their scene
--                         is shown. This keeps the HUD stable during bar/scene rebuilds.
--   "legacy" (3.x)      : base HUD -> false; only contexts recognized by
--                         HybridWantsGamepad use native gamepad presentation.
--   Depth scopes        : WithNativeGamepadMode / WithKeyboardWheelMode force an
--                         answer for the duration of one call.

local ADDON = ESOHybridUI
local rt = ADDON.runtime

local function RealAnswer()
    local original = rt.originalIsInGamepadPreferredMode
    if original then
        return original()
    end
    return false
end

function ADDON:IsNativeGamepadMode()
    return RealAnswer()
end

function ADDON:IsHybrid()
    return rt.hybrid == true
end

-- Re-run a callback with a forced answer and preserve all return values.
local function PackResults(...)
    return { n = select("#", ...), ... }
end

local function RunWithDepth(depthKey, callback, ...)
    rt[depthKey] = rt[depthKey] + 1

    -- Do not use pcall/xpcall here. Some native ESO input paths call secure
    -- functions (for example StartSoulGemResurrection) while a mode scope is
    -- active. A protected-call boundary makes that call stack insecure.
    -- The depth is restored on normal return; an unexpected callback error
    -- propagates and cannot be caught here without breaking that secure call path.
    local results = PackResults(callback(...))

    rt[depthKey] = math.max(0, rt[depthKey] - 1)
    return unpack(results, 1, results.n)
end

-- Native gamepad answer: used for things that must look like ESO's gamepad UI.
function ADDON:WithNativeGamepadMode(callback, ...)
    return RunWithDepth("forceNativeModeDepth", callback, ...)
end

-- Keyboard answer: used to make ESO build its keyboard-style wheels.
function ADDON:WithKeyboardWheelMode(callback, ...)
    return RunWithDepth("forceKeyboardWheelDepth", callback, ...)
end

local function WorldMapShowing()
    if WORLD_MAP_SCENE and WORLD_MAP_SCENE:IsShowing() then
        return true
    end
    -- The native map is a separate scene object; guarded because the global is
    -- not part of any documented contract.
    local gamepadMap = _G.GAMEPAD_WORLD_MAP_SCENE
    return gamepadMap ~= nil and gamepadMap:IsShowing() == true
end

-- "HUD scenes" replace the normal HUD (SetHUDScene) and therefore count as the
-- base scene, yet a controller cannot operate their keyboard versions: the
-- keyboard-only actions have no gamepad binding. Names seen in ESO's source;
-- /esohybrid_trace report lists every scene you visit so more can be added.
local NATIVE_HUD_SCENES = {
    housingEditorHud = true,
    gamepadScreenshotMode = true,
}

-- Legacy policy only: does the current context want ESO's native gamepad presentation?
local function HybridWantsGamepad()
    -- A dialog built with ESO's gamepad template must keep the native answer for
    -- its entire visible lifetime. Some updateFn callbacks branch on this global
    -- every frame and otherwise address keyboard-only Button1 controls.
    local dialogName = rt.gamepadDialogName
    if dialogName then
        if type(ZO_Dialogs_IsShowing) == "function" and ZO_Dialogs_IsShowing(dialogName) then
            return true
        end
        rt.gamepadDialogName = nil
    end

    -- ESO's built-in HUD editor uses IsInGamepadPreferredMode() to choose
    -- which saved layout to edit. Hybrid displays the Keyboard HUD, so keep the
    -- editor on that same layout instead of writing offsets to gamepadElements.
    if HUD_EDITOR_SCENE_KEYBOARD and HUD_EDITOR_SCENE_KEYBOARD:IsShowing() then
        return false
    end

    -- Loot has a dedicated native scene, but ESO can request the keyboard one.
    if GetInteractionType() == INTERACTION_LOOT then
        return true
    end
    -- Lockpicking keeps ESO's native gamepad scene.
    if rt.isLockpicking then
        return true
    end
    -- Opening the map does not necessarily enter UI mode.
    if WorldMapShowing() then
        return true
    end
    -- UI mode alone is not enough: ESO also enters UI mode on focus loss while
    -- showing its base HUD-UI scene. Require a real menu/overlay scene.
    local sceneManager = SCENE_MANAGER
    if not sceneManager then
        return false
    end
    if sceneManager.GetHUDSceneName and NATIVE_HUD_SCENES[sceneManager:GetHUDSceneName()] then
        return true
    end
    local inUIMode = sceneManager.IsInUIMode and sceneManager:IsInUIMode()
    local showingBase = sceneManager.IsShowingBaseScene and sceneManager:IsShowingBaseScene()
    return inUIMode and not showingBase
end

local function IsGamepadUIAllowed()
    local answer
    if rt.forceNativeModeDepth > 0 then
        answer = RealAnswer()
    elseif rt.forceKeyboardWheelDepth > 0 then
        answer = false
    elseif not rt.hybrid then
        answer = RealAnswer()
    else
        -- Hybrid is always a keyboard-style HUD. Native menus opt in through
        -- WithNativeGamepadMode while they are opened, then their scene is
        -- recognized by HybridWantsGamepad. Do not leave the whole HUD in
        -- gamepad mode just because the menu policy is set to "gamepad".
        answer = RealAnswer() and HybridWantsGamepad() or false
    end

    if rt.traceEnabled then
        ADDON:TraceModeQuery(answer)
    end
    return answer
end

function ADDON:InstallModeOverride()
    if rt.modeOverrideInstalled then
        -- Never fight another addon for the global; report it once per change.
        if _G.IsInGamepadPreferredMode ~= rt.overrideFunction then
            if not rt.overrideReplacedWarned then
                rt.overrideReplacedWarned = true
                self:LogWarn("IsInGamepadPreferredMode was replaced after Hybrid UI installed; another addon may be overriding the platform mode.")
            end
            return false
        end
        return true
    end

    rt.originalIsInGamepadPreferredMode = _G.IsInGamepadPreferredMode
    rt.overrideFunction = IsGamepadUIAllowed
    _G.IsInGamepadPreferredMode = IsGamepadUIAllowed
    rt.modeOverrideInstalled = true
    return true
end

-- Cheap cached flags for the hot path above.
function ADDON:RefreshSettingsCache()
    local settings = self:GetSettings()
    rt.hybrid = settings.mode == ADDON.MODE_HYBRID
    rt.menusGamepad = settings.menuPolicy ~= ADDON.POLICY_LEGACY
end
