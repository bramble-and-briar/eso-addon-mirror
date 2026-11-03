local ADK = AntiDK2

-- Hardened variant of src/Run.lua: each init step is isolated in its own pcall
-- so one failure does not prevent the others from loading.
-- NOT listed in AntiDK2.addon; kept for reference.

-- ── Reset everything (player death) ──────────────────────────────────────────
local function ResetAll()
    ADK.Combat.Events.Corrosive.Reset()
    ADK.Combat.Events.Wings.Reset()
    ADK.Combat.Events.MoltenWhip.Reset()
    ADK.Combat.Events.PowerLash.Reset()
    ADK.UI.Stuns.Reset()
end

-- ── Register all combat event listeners ──────────────────────────────────────
local function RegisterEvents()
    ADK.Combat.Events.Corrosive.Register()
    ADK.Combat.Events.Wings.Register()
    ADK.Combat.Events.MoltenWhip.Register()
    ADK.Combat.Events.PowerLash.Register()
    ADK.Combat.Events.ShatteringRocks.Register()
    ADK.Combat.Events.Fossilize.Register()
    ADK.Combat.Events.DragonknightStandard.Register()
end

-- ── Build all UI panels (Popups first: it owns the main panel container) ─────
local function InitUI()
    local order = { "Popups", "Corrosive", "Stuns", "Wings", "MoltenStacks", "PowerLashStacks" }
    for _, name in ipairs(order) do
        local ok, err = pcall(ADK.UI[name].Init)
        if not ok then
            error("ADK.UI." .. name .. " failed: " .. tostring(err), 2)
        end
    end
end

-- Run one init step, reporting (but not propagating) any error.
local function Step(label, fn)
    local ok, err = pcall(fn)
    if not ok then ADK.Error(label, err) end
    return ok
end

-- ── Entry point ───────────────────────────────────────────────────────────────
local function OnAddOnLoaded(_, addOnName)
    if addOnName ~= ADK.name then return end
    EVENT_MANAGER:UnregisterForEvent(ADK.name .. "_Load", EVENT_ADD_ON_LOADED)

    -- Step 1: saved variables (fall back to defaults if broken)
    if not Step("SavedVars", function()
        ADK.savedVars = ZO_SavedVars:NewCharacterIdSettings(
            ADK.savedVarsName, ADK.savedVarsVersion, nil, ADK.defaults
        )
    end) then
        ADK.savedVars = ADK.defaults
    end

    -- Steps 2-3: UI and settings panel (non-critical)
    Step("UI",       InitUI)
    Step("Settings", ADK.Config.Settings.Init)

    -- Step 4: combat event registration (always attempted)
    if Step("Events", RegisterEvents) then
        ADK.Msg("Combat tracking active.")
    end

    EVENT_MANAGER:RegisterForEvent(ADK.name .. "_PlayerDead", EVENT_PLAYER_DEAD, ResetAll)
end

EVENT_MANAGER:RegisterForEvent(ADK.name .. "_Load", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
