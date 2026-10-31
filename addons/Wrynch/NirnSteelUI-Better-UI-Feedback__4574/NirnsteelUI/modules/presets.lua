Nirnsteel_UI = Nirnsteel_UI or {}
local Presets = { choices = {}, choiceValues = {} }
Nirnsteel_UI.Presets = Presets

local PRESET_VERSION = 1
local SAVED_VARS_METADATA = { version = true, ["$LastCharacterName"] = true }

local function Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = Copy(item) end
    return copy
end

local function SavedValues(settings)
    -- ZO_SavedVars exposes a proxy. Iterating it would copy its methods and
    -- defaults instead of the persisted settings behind its __index table.
    local meta = getmetatable(settings)
    return meta and type(meta.__index) == "table" and meta.__index or settings
end

local function CaptureSettings(settings)
    local snapshot = {}
    for key, value in pairs(SavedValues(settings)) do
        if not SAVED_VARS_METADATA[key] then snapshot[key] = Copy(value) end
    end
    return snapshot
end

local function RestoreSettings(settings, snapshot)
    local values = SavedValues(settings)
    for key in pairs(values) do
        if not SAVED_VARS_METADATA[key] then values[key] = nil end
    end
    for key, value in pairs(snapshot) do
        if not SAVED_VARS_METADATA[key] then values[key] = Copy(value) end
    end
end

local function NormalizeName(name)
    return type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
end

local function Notify(message)
    d("Nirnsteel UI: " .. message)
end

function Presets:Initialize(settings)
    self.settings = settings
    -- Keep the library outside the snapshots so saving and loading never
    -- nests presets or rolls the library back to an earlier version.
    self.saved = ZO_SavedVars:NewAccountWide("NirnsteelUI_Presets", 1, nil, { presets = {} }, settings.serverKey)
    if type(self.saved.presets) ~= "table" then self.saved.presets = {} end
    self.newName = ""
    self:RefreshChoices()
end

function Presets:IsReady()
    local settings = self.settings
    return settings and settings.account and settings.server and settings.character
        and (not HUD_MANAGER or (HUD_MANAGER.savedVars and type(HUD_MANAGER.savedVars.profiles) == "table"))
end

function Presets:GetSelectedName()
    local name = self.saved and self.saved.selectedPreset
    return name and self.saved.presets[name] and name or ""
end

function Presets:GetNewName()
    -- A button click can arrive before LAM's editbox loses focus.
    local control = NirnsteelUI_PresetName
    return control and control.editbox:GetText() or self.newName
end

function Presets:RefreshChoices()
    local names = {}
    for name in pairs(self.saved.presets) do names[#names + 1] = name end
    table.sort(names, function(left, right)
        local a, b = string.lower(left), string.lower(right)
        return a == b and left < right or a < b
    end)
    for i = #self.choices, 1, -1 do self.choices[i] = nil end
    for i = #self.choiceValues, 1, -1 do self.choiceValues[i] = nil end
    for i, name in ipairs(names) do self.choices[i], self.choiceValues[i] = name, name end
    if #names == 0 then
        self.choices[1], self.choiceValues[1] = "No saved presets", ""
    end
    if self:GetSelectedName() == "" then self.saved.selectedPreset = names[1] or "" end
end

function Presets:RefreshControls()
    self:RefreshChoices()
    local dropdown = NirnsteelUI_PresetList
    if dropdown then dropdown:UpdateChoices(self.choices, self.choiceValues) end
    local panel = Nirnsteel_UI_Settings
    if panel then CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel) end
end

function Presets:Save(name, overwrite)
    name = NormalizeName(name)
    if name == "" then
        Notify("Enter a name for the new preset.")
        return false
    end
    if not self:IsReady() then
        Notify("Settings and Edit HUD must finish loading before saving a preset.")
        return false
    end
    local exists = self.saved.presets[name] ~= nil
    if exists and not overwrite then
        Notify("That preset already exists. Select it and use Overwrite to update it.")
        return false
    elseif overwrite and not exists then
        return false
    end

    local settings = self.settings
    self.saved.presets[name] = {
        version = PRESET_VERSION,
        account = CaptureSettings(settings.account),
        server = CaptureSettings(settings.server),
        character = CaptureSettings(settings.character),
        -- ESO stores normalized offsets and custom Edit HUD options for both
        -- input modes here, including elements that are currently disabled.
        hudProfiles = HUD_MANAGER and Copy(HUD_MANAGER.savedVars.profiles) or nil,
    }
    self.saved.selectedPreset, self.newName = name, ""
    self:RefreshControls()
    Notify((exists and "Updated preset: " or "Saved preset: ") .. name)
    return true
end

function Presets:Load(name)
    local preset = self.saved.presets[name]
    if type(preset) ~= "table" or preset.version ~= PRESET_VERSION
        or type(preset.account) ~= "table" or type(preset.account.modules) ~= "table"
        or type(preset.server) ~= "table" or type(preset.server.modules) ~= "table"
        or type(preset.character) ~= "table" or type(preset.character.modules) ~= "table" then
        Notify("Select a valid saved preset to load.")
        return false
    end
    if not self:IsReady() or (preset.hudProfiles and not HUD_MANAGER) then
        Notify("Settings and Edit HUD must finish loading before loading a preset.")
        return false
    end
    if preset.hudProfiles and (type(preset.hudProfiles) ~= "table"
        or type(preset.hudProfiles[1]) ~= "table"
        or type(preset.hudProfiles[1].keyboardElements) ~= "table"
        or type(preset.hudProfiles[1].gamepadElements) ~= "table") then
        Notify("The preset's Edit HUD layout is invalid.")
        return false
    end

    local settings = self.settings
    RestoreSettings(settings.account, preset.account)
    RestoreSettings(settings.server, preset.server)
    RestoreSettings(settings.character, preset.character)
    if preset.hudProfiles then HUD_MANAGER.savedVars.profiles = Copy(preset.hudProfiles) end
    self.saved.selectedPreset = name
    ReloadUI()
    return true
end

function Presets:Delete(name)
    if not self.saved.presets[name] then return false end
    self.saved.presets[name] = nil
    self:RefreshControls()
    Notify("Deleted preset: " .. name)
    return true
end

function Presets:GetOptions()
    return {
        {
            type = "dropdown", name = "Saved Preset",
            choices = self.choices, choicesValues = self.choiceValues,
            scrollable = true, reference = "NirnsteelUI_PresetList",
            getFunc = function() return self:GetSelectedName() end,
            setFunc = function(name) self.saved.selectedPreset = name end,
            disabled = function() return self:GetSelectedName() == "" end,
            tooltip = "Choose a preset, then click Load / Reload UI to apply it.",
        },
        {
            type = "editbox", name = "New Preset Name", maxChars = 64,
            reference = "NirnsteelUI_PresetName",
            getFunc = function() return self.newName end,
            setFunc = function(name) self.newName = name end,
            tooltip = "Enter a new name and click Save New to capture your current configuration.",
        },
        {
            type = "button", name = "Save New", width = "half",
            func = function() self:Save(self:GetNewName()) end,
            disabled = function() return not self:IsReady() end,
            tooltip = "Save all current settings and the complete Edit HUD layout as a new preset.",
        },
        {
            type = "button", name = "Load / Reload UI", width = "half",
            func = function() self:Load(self:GetSelectedName()) end,
            disabled = function() return not self:IsReady() or self:GetSelectedName() == "" end,
            tooltip = "Apply the selected preset and reload the UI immediately. Save your current configuration first if you want to keep it.",
        },
        {
            type = "button", name = "Overwrite", width = "half", isDangerous = true,
            func = function() self:Save(self:GetSelectedName(), true) end,
            disabled = function() return not self:IsReady() or self:GetSelectedName() == "" end,
            warning = function() return "Replace preset '" .. self:GetSelectedName() .. "' with all current settings and the current Edit HUD layout?" end,
            tooltip = "Update the selected preset with your current configuration.",
        },
        {
            type = "button", name = "Delete", width = "half", isDangerous = true,
            func = function() self:Delete(self:GetSelectedName()) end,
            disabled = function() return self:GetSelectedName() == "" end,
            warning = function() return "Delete preset '" .. self:GetSelectedName() .. "'? Your current settings will stay as they are." end,
            tooltip = "Delete the selected saved preset.",
        },
    }
end
