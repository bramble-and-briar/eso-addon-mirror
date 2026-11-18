local OS = OneSettings
local Windows = OS.modules.windows
local settingKeys = { "timestamps", "newline", "hidePlayerStatus", "customMessage",
    "messageTemplate", "abbreviations", "toolbar" }

local function supported()
    return OneChat and OneChat.schema == 2 and OneChat.sv and OneChat.character
        and OneChat.sv.schema == 2 and OneChat.character.schema == 2
end

function Windows:ChatReady()
    -- OneChat initializes at PLAYER_ACTIVATED, whose callback order is unspecified.
    return not supported() or (OneChat.chat == KEYBOARD_CHAT_SYSTEM and OneChat.settingsPanel ~= nil)
end

function Windows:CaptureOneChat()
    if not supported() or not self:ChatReady() then return end
    local addon = OneChat
    local saved = { schema = 2, settings = {}, tabs = {} }
    for _, key in ipairs(settingKeys) do saved.settings[key] = OS.Copy(addon.sv[key]) end
    for index, container in ipairs(addon.chat.containers) do
        local tabs = {}
        saved.tabs[index] = tabs
        for tabIndex, window in ipairs(container.windows) do
            if not window.combatLog then
                local state = addon:GetTabState(container, window)
                tabs[tabIndex] = { name = container:GetTabName(tabIndex), incoming = OS.Copy(state.incoming),
                    outgoing = OS.Copy(state.outgoing), last = state.last }
            end
        end
    end
    return saved
end

function Windows:ApplyOneChat(shared)
    if not supported() or not self:ChatReady() then return end
    if not shared.oneChat then shared.oneChat = self:CaptureOneChat() end
    local saved, addon = shared.oneChat, OneChat
    if saved.schema ~= 2 then return end
    for _, key in ipairs(settingKeys) do
        if saved.settings[key] ~= nil then addon.sv[key] = OS.Copy(saved.settings[key]) end
    end
    for index, container in ipairs(addon.chat.containers) do
        for tabIndex, window in ipairs(container.windows) do
            local tab = saved.tabs[index] and saved.tabs[index][tabIndex]
            if not window.combatLog and tab and tab.name == container:GetTabName(tabIndex) then
                local state = addon:GetTabState(container, window)
                -- Keep history and runtime identity local to this window.
                state.incoming, state.outgoing, state.last = OS.Copy(tab.incoming), OS.Copy(tab.outgoing), tab.last
            end
        end
    end
    addon:RefreshMembership()
    addon:RestoreSelection()
    addon:RefreshToolbar()
    addon:RefreshOptions()
    addon:SnapshotTabs()
end

function Windows:InitializeOneChat()
    local function attach()
        if not OneChat or self.oneChatHooked == OneChat then return end
        self.oneChatHooked = OneChat
        local function changed() self:Changed() end
        for _, method in ipairs({ "SnapshotTabs", "ChooseChannel", "RefreshMembership" }) do
            SecurePostHook(OneChat, method, changed)
        end
        SecurePostHook(OneChat, "InstallSettings", function()
            OS:Later("OneChat", function()
                if OS.ready then OS:Apply("windows") end
            end)
        end)
    end
    attach()
    EVENT_MANAGER:RegisterForEvent(OS.name .. "OneChat", EVENT_ADD_ON_LOADED, function(_, name)
        if name == "OneChat" then attach() end
    end)
    -- OneChat registers these controls at PLAYER_ACTIVATED, after our initialization.
    SecurePostHook(LibAddonMenu2, "RegisterOptionControls", function(_, name, options)
        if name ~= "OneChatSettings" then return end
        for _, option in ipairs(options) do
            if type(option.setFunc) == "function" then
                SecurePostHook(option, "setFunc", function() self:Changed() end)
            end
        end
    end)
end
