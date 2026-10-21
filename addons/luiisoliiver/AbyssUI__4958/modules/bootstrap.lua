-- AbyssUI central bootstrap
-- Single EVENT_ADD_ON_LOADED; modules register via NAGA_UI.OnAddonLoaded(fn).
-- Namespaces: NAGA_UI (primary), NAGA_UI.MapUI (alias NagaMapUI), NAGA_UI.BUI (alias NAGA_BUI).

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI

-- Sub-namespaces (single global table pattern)
NAGA_UI.MapUI = NAGA_UI.MapUI or {}
NAGA_UI.BUI = NAGA_UI.BUI or {}
NAGA_UI.AbyssQuest = NAGA_UI.AbyssQuest or {}

-- Backward-compatible aliases (other files / SavedVariables still use these names)
NagaMapUI = NAGA_UI.MapUI
NAGA_BUI = NAGA_UI.BUI

NAGA_UI._initQueue = NAGA_UI._initQueue or {}
NAGA_UI._initDone = false

--- Queue a function to run once when AbyssUI finishes loading.
--- Prefer this over registering more EVENT_ADD_ON_LOADED handlers.
function NAGA_UI.OnAddonLoaded(fn)
    if type(fn) ~= "function" then return end
    if NAGA_UI._initDone then
        fn()
        return
    end
    NAGA_UI._initQueue[#NAGA_UI._initQueue + 1] = fn
end

function NAGA_UI.BuildLocalization()
    if NAGA_UI.Locale and NAGA_UI.Locale.SetLanguage then
        NAGA_UI.Locale.SetLanguage(NAGA_UI.Locale.GetClientLanguage())
    end
end

function NAGA_UI.BuildSettings()
    if NAGA_UI.Settings and NAGA_UI.Settings.Initialize then
        NAGA_UI.Settings:Initialize()
    end
end

local function RunInitQueue()
    if NAGA_UI._initDone then return end
    NAGA_UI._initDone = true

    NAGA_UI.BuildLocalization()

    -- Settings first so SavedVariables / defaults exist for modules
    NAGA_UI.BuildSettings()

    local queue = NAGA_UI._initQueue
    NAGA_UI._initQueue = {}
    for i = 1, #queue do
        queue[i]()
    end
end

EVENT_MANAGER:RegisterForEvent("AbyssUI_Main", EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= "AbyssUI" then return end
    EVENT_MANAGER:UnregisterForEvent("AbyssUI_Main", EVENT_ADD_ON_LOADED)
    RunInitQueue()
end)
