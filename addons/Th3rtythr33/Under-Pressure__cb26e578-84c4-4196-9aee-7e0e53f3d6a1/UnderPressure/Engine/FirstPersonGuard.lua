-- =============================================================================
-- Under Pressure -- Engine/FirstPersonGuard.lua  ("No More Oopsies", 0.5.5)
-- =============================================================================
-- Stops an accidental press of the perspective button from flipping the
-- camera into first person. While the guard is on, the toggle only goes
-- through when the button is pressed PRESSES_REQUIRED times within WINDOW_MS;
-- the earlier presses are swallowed. Off by default, labelled experimental.
--
-- HOW (research 2026-10-08, CLAUDE.md "Which game inputs an addon can
-- intercept"): on console's default layout D-pad Down is the TOGGLE_FIRST_PERSON
-- action, and its whole binding handler in esoui/ingame/globals/bindings.xml
-- is the bare call `ToggleGameCameraFirstPerson()`. That native is NOT marked
-- *private*, so an add-on may call it, and a binding chunk resolves its
-- globals at press time, so replacing _G.ToggleGameCameraFirstPerson with a
-- wrapper is enough: the wrapper decides whether to call the original. ZOS's
-- own keyboard options panel calls the same global from Lua, so nothing else
-- in the client is bypassed by the swap.
--
-- WHAT IT CANNOT DO, by construction (all stated in the settings tooltip):
--   * The API has no getter for the current perspective, so the guard cannot
--     tell "into first person" from "out of it": leaving first person needs
--     the same triple press. Acceptable for an opt-in experimental tweak.
--   * The gamepad camera zoom (hold D-pad Down + right stick) reaches first
--     person through private natives (GameCameraGamepadZoomDown/Up) and is
--     not intercepted.
--   * Template B (the "alternate" console layout) has no single-button
--     perspective toggle at all, so there the guard has nothing to catch.
--
-- INSTALL / UNINSTALL. The wrapper is installed when the setting is turned
-- on and removed when it is turned off (house rule: every feature has a hard
-- switch with a real teardown). Removal restores the saved original only if
-- our wrapper is still what the global points at; if another add-on wrapped
-- the global after us, restoring would silently drop their wrapper, so the
-- wrapper stays and simply passes everything through. Never installed twice.
--
-- The hook is a plain function swap rather than ZO_PreHook because ZO_PreHook
-- has no undo, and because the original must be CALLED from inside the
-- wrapper on the third press, which ZO_PreHook's return-true-to-swallow
-- shape does not express cleanly.
--
-- Untested in game as of 2026-10-29. The one open question is whether the
-- console's binding chunk really does resolve the global at press time for
-- this action; if it does not, the setting does nothing and nothing breaks.
-- The API audit (Settings > Debug > Print) reports whether the native global
-- exists on this client and whether the wrapper is currently installed.
-- =============================================================================

UP = UP or {}
UP.FirstPersonGuard = {}
local G = UP.FirstPersonGuard

G.DEFAULT_ENABLED   = false
G.PRESSES_REQUIRED  = 3
G.WINDOW_MS         = 3000
G.ACTION_NAME       = "TOGGLE_FIRST_PERSON"
G.GLOBAL_NAME       = "ToggleGameCameraFirstPerson"

local original = nil        -- the native we replaced, while installed
local wrapper  = nil        -- our function, so we can tell if we are still on top
local presses  = {}         -- timestamps (ms) of swallowed presses, oldest first
local passed, swallowed = 0, 0

local function sv()
    return UP.sv
end

local function nowMs()
    return GetGameTimeMilliseconds()
end

function G.GetEnabled()
    local s = sv()
    if s and s.first_person_guard ~= nil then
        return s.first_person_guard == true
    end
    return G.DEFAULT_ENABLED
end

-- -----------------------------------------------------------------------------
-- The decision
-- -----------------------------------------------------------------------------
-- Drops presses older than the window, records this one, and says whether the
-- toggle should go through. Pure, so the harness can drive it on a fake clock.
function G.RegisterPress(t)
    t = t or nowMs()
    local keep = {}
    for _, p in ipairs(presses) do
        if t - p < G.WINDOW_MS then keep[#keep + 1] = p end
    end
    presses = keep
    presses[#presses + 1] = t
    if #presses >= G.PRESSES_REQUIRED then
        presses = {}
        return true
    end
    return false
end

function G.PendingPresses() return #presses end
function G.ResetPresses() presses = {} end

-- -----------------------------------------------------------------------------
-- The wrapper
-- -----------------------------------------------------------------------------
-- Each installed wrapper is a closure over the function it replaced and over
-- its own `state`. Uninstall retires the wrapper by clearing state.active, so
-- a wrapper that could not be removed (another add-on wrapped on top of it)
-- becomes a permanent pass-through and can never count a press again, even
-- if a fresh wrapper is later installed above it.
local function makeWrapper(nativeFn, state)
    return function(...)
        if not state.active or not G.GetEnabled() then
            return nativeFn(...)
        end
        if G.RegisterPress() then
            passed = passed + 1
            if UP.Debug and UP.Debug.Log then UP.Debug.Log("fpguard: 3rd press, toggle allowed") end
            return nativeFn(...)
        end
        swallowed = swallowed + 1
        if UP.Debug and UP.Debug.Log then
            UP.Debug.Log(("fpguard: press %d/%d swallowed"):format(#presses, G.PRESSES_REQUIRED))
        end
    end
end

local wrapperState = nil

-- True when the native global exists on this client (a function). Reported by
-- the API audit; on console this is the one fact the design rests on that can
-- be checked from Lua.
function G.NativeAvailable()
    return type(_G[G.GLOBAL_NAME]) == "function"
end

function G.IsInstalled()
    return wrapper ~= nil and _G[G.GLOBAL_NAME] == wrapper
end

function G.Install()
    if G.IsInstalled() then return true end               -- never twice
    local native = _G[G.GLOBAL_NAME]
    if type(native) ~= "function" then return false end   -- nothing to guard
    original = native
    wrapperState = { active = true }
    wrapper = makeWrapper(native, wrapperState)
    _G[G.GLOBAL_NAME] = wrapper
    presses = {}
    return true
end

function G.Uninstall()
    if not wrapper then return end
    if _G[G.GLOBAL_NAME] == wrapper then
        -- We are still on top: restore what we replaced, exactly.
        _G[G.GLOBAL_NAME] = original
    end
    -- Otherwise someone wrapped us; leave the chain intact. Either way the
    -- old wrapper is retired to a pure pass-through.
    if wrapperState then wrapperState.active = false end
    original, wrapper, wrapperState = nil, nil, nil
    presses = {}
end

function G.SetEnabled(value)
    local s = sv()
    if s then s.first_person_guard = value and true or false end
    if value then
        G.Install()
    else
        G.Uninstall()
    end
end

function G.Init()
    presses = {}
    passed, swallowed = 0, 0
    if G.GetEnabled() then
        if not G.Install() and UP.Note then
            UP.Note("First-person guard is on but ToggleGameCameraFirstPerson is not a function on this client; nothing installed.")
        end
    end
end

-- The live binding for the action, as controller glyph markup, for the
-- settings tooltip. Falls back to words if the lookup is unavailable.
function G.BindingText()
    if type(ZO_Keybindings_GetHighestPriorityBindingStringFromAction) == "function" then
        local ok, text = pcall(ZO_Keybindings_GetHighestPriorityBindingStringFromAction,
                               G.ACTION_NAME, KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
    return "the perspective button"
end

-- One line for the debug overlay.
function G.GetReport()
    if not G.GetEnabled() then return "fpGuard=off" end
    return ("fpGuard=on installed=%s pending=%d passed=%d swallowed=%d"):format(
        G.IsInstalled() and "yes" or "NO", #presses, passed, swallowed)
end
