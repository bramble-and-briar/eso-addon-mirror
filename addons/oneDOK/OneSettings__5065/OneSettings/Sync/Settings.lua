local OS = OneSettings
local Settings = { descriptors = {}, colors = {}, bubbles = {} }
OS.modules.settings = Settings

function Settings:Initialize()
    -- Read the game's own settings registry; do not guess enum ranges or setter names.
    for _, systems in pairs(ZO_SharedOptions_SettingsData or {}) do
        for system, entries in pairs(systems) do
            if type(system) == "number" and system ~= SETTING_TYPE_CUSTOM and system ~= SETTING_TYPE_ACCOUNT then
                for id, data in pairs(entries) do
                    -- Language belongs to the client; a reload after /script SetCVar must keep it.
                    local isLanguage = system == SETTING_TYPE_UI and id == UI_SETTING_TEXT_LANGUAGE
                    if type(id) == "number" and data.system == system and not isLanguage and not IsSettingDeferred(system, id) then
                        local exists = not KEYBOARD_OPTIONS or KEYBOARD_OPTIONS:DoesSettingExist(data)
                        if exists then
                            self.descriptors[system .. ":" .. id] = { system = system, id = id }
                        end
                    end
                end
            end
            for _, data in pairs(entries) do
                if data.chatChannelCategory then self.colors[data.chatChannelCategory] = true end
                for _, category in ipairs(data.channelCategories or {}) do self.bubbles[category] = true end
            end
        end
    end
    -- Gamma calibration is a separate stock scene, reached through a custom menu button.
    if SETTING_TYPE_GRAPHICS and GRAPHICS_SETTING_GAMMA_ADJUSTMENT then
        local system, id = SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_GAMMA_ADJUSTMENT
        self.descriptors[system .. ":" .. id] = { system = system, id = id }
    end
    local function changed() self:Changed() end
    EVENT_MANAGER:RegisterForEvent(OS.name, EVENT_INTERFACE_SETTING_CHANGED, changed)
    for _, name in ipairs({ "SetSetting", "ApplySettings", "ResetSettingToDefault", "ResetToDefaultSettings",
        "SetChatFontSize", "ResetChatFontSizeToDefault", "SetGamepadChatFontSize", "SetChatCategoryColor",
        "ResetChatCategoryColorToDefault", "ResetChatToDefaults", "SetChatBubbleCategoryEnabled" }) do
        if type(_G[name]) == "function" then SecurePostHook(_G, name, changed) end
    end
    if KEYBOARD_CHAT_SYSTEM then
        SecurePostHook(KEYBOARD_CHAT_SYSTEM, "SetMinAlpha", changed)
        SecurePostHook(KEYBOARD_CHAT_SYSTEM, "ResetMinAlphaToDefault", changed)
    end
end

function Settings:Capture()
    local result = { values = {}, colors = {}, bubbles = {} }
    for key, descriptor in pairs(self.descriptors) do
        local ok, value = pcall(GetSetting, descriptor.system, descriptor.id)
        if ok and type(value) == "string" and value ~= "" then result.values[key] = value end
    end
    result.font = GetChatFontSize()
    result.gamepadFont = GetGamepadChatFontSize()
    if KEYBOARD_CHAT_SYSTEM and KEYBOARD_CHAT_SYSTEM.primaryContainer then
        result.minAlpha = KEYBOARD_CHAT_SYSTEM:GetMinAlpha()
    end
    for category in pairs(self.colors) do result.colors[category] = { GetChatCategoryColor(category) } end
    for category in pairs(self.bubbles) do result.bubbles[category] = IsChatBubbleCategoryEnabled(category) end
    return result
end

function Settings:Apply(shared)
    local apply = false
    for key, value in pairs(shared.values) do
        local descriptor = self.descriptors[key]
        if descriptor and GetSetting(descriptor.system, descriptor.id) ~= value then
            SetSetting(descriptor.system, descriptor.id, value, SETTINGS_SET_OPTION_SAVE_TO_PERSISTED_DATA)
            apply = true
        end
    end
    if shared.font then
        SetChatFontSize(shared.font)
        if KEYBOARD_CHAT_SYSTEM then KEYBOARD_CHAT_SYSTEM:SetFontSize(shared.font) end
    end
    if shared.gamepadFont then
        SetGamepadChatFontSize(shared.gamepadFont)
        if GAMEPAD_CHAT_SYSTEM then GAMEPAD_CHAT_SYSTEM:SetFontSize(shared.gamepadFont) end
    end
    if shared.minAlpha and KEYBOARD_CHAT_SYSTEM then KEYBOARD_CHAT_SYSTEM:SetMinAlpha(shared.minAlpha) end
    for category, color in pairs(shared.colors) do
        if self.colors[category] then SetChatCategoryColor(category, unpack(color)) end
    end
    for category, enabled in pairs(shared.bubbles or {}) do
        if self.bubbles[category] then SetChatBubbleCategoryEnabled(category, enabled) end
    end
    if apply then ApplySettings() end
end

function Settings:Changed()
    if not OS.ready or OS.applying or not OS:Enabled("settings") then return end
    self.dirty = true
    OS:Later("Settings", function() self:FlushChanges() end)
end

function Settings:FlushChanges()
    if not self.dirty then return end
    self.dirty = false
    OS:CancelLater("Settings")
    OS:Publish("settings", self:Capture())
end
