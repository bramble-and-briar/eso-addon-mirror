local ADK = AntiDK2

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

-- ── Entry point ───────────────────────────────────────────────────────────────
local function OnAddOnLoaded(_, addOnName)
    if addOnName ~= ADK.name then return end
    EVENT_MANAGER:UnregisterForEvent(ADK.name .. "_Load", EVENT_ADD_ON_LOADED)

    local ok, err = pcall(function()
        -- Saved variables (per character)
        ADK.savedVars = ZO_SavedVars:NewCharacterIdSettings(
            ADK.savedVarsName, ADK.savedVarsVersion, nil, ADK.defaults
        )

        InitUI()
        ADK.Config.Settings.Init()
        RegisterEvents()

        -- Reset on player death
        EVENT_MANAGER:RegisterForEvent(ADK.name .. "_PlayerDead", EVENT_PLAYER_DEAD, ResetAll)
    end)

    if not ok then
        -- Report any init error to chat so it can be diagnosed
        ADK.Error("Init", err)
    end
end

EVENT_MANAGER:RegisterForEvent(ADK.name .. "_Load", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
