NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local AddonLoadouts = {}

local function Message(key, ...)
    NQOL.Chat.Message(NQOL.L(key, ...), NQOL.L("features.slash_commands.feature_name"))
end

local function GetPresetPanel()
    local manager = GetAddOnManager and GetAddOnManager()
    if not manager or not manager.GetNumAddOns or not manager.GetAddOnInfo then
        return nil
    end

    local loaded = false
    for index = 1, manager:GetNumAddOns() do
        local name, _, _, _, enabled, state = manager:GetAddOnInfo(index)
        if name == "AddonLoadouts" then
            loaded = enabled == true and ADDON_STATE_ENABLED ~= nil and state == ADDON_STATE_ENABLED
            break
        end
    end

    local settings = LibHarvensAddonSettings
    if not loaded or type(settings) ~= "table" or type(settings.addons) ~= "table"
        or settings.ST_BUTTON == nil or SI_ADDONLOADOUTS_LOAD == nil or type(GetString) ~= "function"
    then
        return nil
    end

    local loadLabel = GetString(SI_ADDONLOADOUTS_LOAD)
    if type(loadLabel) ~= "string" or loadLabel == "" then
        return nil
    end

    for _, panel in ipairs(settings.addons) do
        if type(panel) == "table" and panel.name == "Addon Loadouts" and type(panel.settings) == "table" then
            return panel, loadLabel, settings.ST_BUTTON
        end
    end
end

local function FindPreset(panel, loadLabel, buttonType, name)
    local exact, folded
    local exactCount, foldedCount = 0, 0
    local searchName = NQOL.Util.Lower(name)
    for _, setting in ipairs(panel.settings) do
        -- These are Addon Loadouts' registered Load actions, not its management
        -- buttons. Both PC and console LibHarvens panels retain these fields.
        if type(setting) == "table" and setting.type == buttonType and setting.buttonText == loadLabel
            and type(setting.labelText) == "string" and type(setting.clickHandler) == "function"
        then
            if setting.labelText == name then
                exact, exactCount = setting, exactCount + 1
            end
            if NQOL.Util.Lower(setting.labelText) == searchName then
                folded, foldedCount = setting, foldedCount + 1
            end
        end
    end

    if exactCount > 0 then
        return exactCount == 1 and exact or nil, exactCount > 1
    end
    return foldedCount == 1 and folded or nil, foldedCount > 1
end

function AddonLoadouts.Load(args)
    local name = tostring(args or ""):match("^%s*(.-)%s*$")
    local unquoted = name:match('^"(.*)"$') or name:match("^'(.*)'$")
    if unquoted then
        name = unquoted:match("^%s*(.-)%s*$")
    end
    if name == "" then
        Message("features.addon_loadouts.usage")
        return false
    end

    local panel, loadLabel, buttonType = GetPresetPanel()
    if not panel then
        Message("features.addon_loadouts.unavailable")
        return false
    end

    local preset, ambiguous = FindPreset(panel, loadLabel, buttonType, name)
    if ambiguous then
        Message("features.addon_loadouts.ambiguous", name)
        return false
    end
    if not preset then
        Message("features.addon_loadouts.not_found", name)
        return false
    end

    Message("features.addon_loadouts.loading", preset.labelText)
    -- Delegate to the addon's own action. NQOL never reads/writes its saved
    -- variables, changes addon enabled states, or performs the UI reload.
    local succeeded = pcall(preset.clickHandler)
    if not succeeded then
        Message("features.addon_loadouts.failed", preset.labelText)
    end
    return succeeded
end

NQOL.Features.AddonLoadouts = AddonLoadouts
