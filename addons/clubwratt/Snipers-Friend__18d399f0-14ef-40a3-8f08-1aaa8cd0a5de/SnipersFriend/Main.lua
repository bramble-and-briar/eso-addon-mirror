-- Main.lua: Entry point. Registers events and wires modules together.

local SnipersFriend = SnipersFriend

local function MergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            MergeDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

local function Initialize()
    local State = SnipersFriend.State
    SnipersFriend.state = State.Create()

    local defaults = State.Defaults()
    local sv = ZO_SavedVars:NewAccountWide(SnipersFriend.savedVarsName, SnipersFriend.savedVarsVersion, nil, defaults)
    MergeDefaults(sv, defaults)
    -- 0.3.1: height limits default to the native -0.30..0.50 again. Migrate users
    -- still on the old 0.3.0 defaults (-1.5..2.5) once; explicit custom values stay.
    local L = sv.camera.limits
    if not sv.camera.heightLimitsMigrated then
        if L.heightMin == -1.5 and L.heightMax == 2.5 then
            L.heightMin, L.heightMax = defaults.camera.limits.heightMin, defaults.camera.limits.heightMax
        end
        sv.camera.heightLimitsMigrated = true
    end
    SnipersFriend.state.savedVars = sv

    SLASH_COMMANDS["/sf"] = SnipersFriend.SlashActions.HandleCommand
    SLASH_COMMANDS["/snipersfriend"] = SnipersFriend.SlashActions.HandleCommand

    SnipersFriend.SettingsActions.Initialize()
    -- Native-panel work happens at load so the Camera menu is already patched the
    -- first time it is opened. Pure table edits; no engine calls.
    SnipersFriend.CameraActions.InjectDistanceSettings()
    if sv.camera.unlockNativeSliders then
        SnipersFriend.CameraActions.ApplySliderLimits()
    end

    EVENT_MANAGER:RegisterForEvent(SnipersFriend.name, EVENT_PLAYER_ACTIVATED, function()
        SnipersFriend.ReticleActions.Initialize()
        SnipersFriend.GroundTargetActions.Initialize()
        SnipersFriend.AimLineActions.Initialize()
        SnipersFriend.CameraActions.OnPlayerActivated()
    end)
    -- Ground-target indicator: know which abilities are ground-targeted and which was cast last.
    EVENT_MANAGER:RegisterForEvent(SnipersFriend.name, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, function()
        SnipersFriend.GroundTargetActions.RefreshAbilities()
    end)
    EVENT_MANAGER:RegisterForEvent(SnipersFriend.name, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, function()
        SnipersFriend.GroundTargetActions.RefreshAbilities()
    end)
    EVENT_MANAGER:RegisterForEvent(SnipersFriend.name, EVENT_ACTION_SLOT_ABILITY_USED, function(_eventId, slot)
        SnipersFriend.GroundTargetActions.OnAbilityUsed(slot)
    end)
    EVENT_MANAGER:RegisterForEvent(SnipersFriend.name, EVENT_PLAYER_DEACTIVATED, function()
        SnipersFriend.CameraActions.OnPlayerDeactivated()
    end)
    -- Adopt changes made in the game's own Settings > Camera menu when it closes.
    local optionsScene = _G["GAMEPAD_OPTIONS_PANEL_SCENE"]
    if optionsScene and optionsScene.RegisterCallback then
        optionsScene:RegisterCallback("StateChange", function(_oldState, newState)
            if newState == SCENE_HIDDEN then
                SnipersFriend.CameraActions.OnOptionsClosed()
            end
        end)
    end

    SnipersFriend.SlashUtils.Debug("Loaded v%s", SnipersFriend.version)
end

EVENT_MANAGER:RegisterForEvent(SnipersFriend.name, EVENT_ADD_ON_LOADED, function(_eventId, addonName)
    if addonName == SnipersFriend.name then
        Initialize()
        EVENT_MANAGER:UnregisterForEvent(SnipersFriend.name, EVENT_ADD_ON_LOADED)
    end
end)
