local M = MountSwap
function M:SetStandalonePanel(enabled)
    local library = LibAddonMenu2
    if not enabled and not library and not (IsInGamepadPreferredMode()) then
        self:Chat('Settings-only mode requires LibAddonMenu-2.0. The standalone panel remains available.', true)
        return false
    end
    self.saved.standalonePanel = enabled == true
    if not enabled then
        self:ClosePicker()
        self.keepControllerMenu=true
        if self.window then self:SetWindowHidden(self.window,true) end
        self.keepControllerMenu=nil
    end
    return true
end
function M:RefreshSettingsChoices()
    if not self.settingsDropdowns then return end
    local mounts = self:Mounts()
    self.settingsSearch = self.settingsSearch or {multi = "", single = ""}
    local dropdowns, search, slots = self.settingsDropdowns, self.settingsSearch, self.saved.slots
    for slot, data in ipairs(dropdowns) do
        local names, values = {M.L('None')}, {0}
        local expected = slot <= 4 and 'multi' or 'single'
        local query = string.lower(search[expected] or '')
        local savedId = slots[slot]
        local savedName
        for _, mount in ipairs(mounts) do
            if mount.id == savedId then savedName = mount.name end
            if self:MountGroup(mount.id) == expected and
                string.find(string.lower(mount.name), query, 1, true) then
                names[#names + 1], values[#values + 1] = mount.name, mount.id
            end
        end
        data.savedDisplayName = savedId and (savedName or M.L('[Unavailable favorite: ' .. tostring(savedId) .. ']')) or M.L('None')
        data.choices, data.choicesValues = names, values
        local control = _G[data.reference]
        if control and control.UpdateChoices then
            control:UpdateChoices(names, values)
            -- Label lookup is separate from the selectable menu entries.
            -- Keep the saved value readable without adding it to search results.
            if savedId and control.choices then control.choices[savedId] = data.savedDisplayName end
            if control.UpdateValue then control:UpdateValue() end
        end
    end
end
function M:SetSettingsSearch(group, text)
    self.settingsSearch = self.settingsSearch or {multi = '', single = ''}
    if self.settingsSearch[group] == text then return end
    self.settingsSearch[group] = text
    self:RefreshSettingsChoices()
end
function M:HookSettingsSearch()
    if not ZO_PostHookHandler then return end
    for _, group in ipairs({'multi', 'single'}) do
        local key = group
        local control = _G['MountSwapSettingsSearch_' .. key]
        local edit = control and control.editbox
        if edit and not edit.mountSwapSearchHooked then
            ZO_PostHookHandler(edit, 'OnTextChanged', function(field)
                M:SetSettingsSearch(key, field:GetText())
            end)
            edit.mountSwapSearchHooked = true
        end
    end
end
function M:SettingsControls()
    if self.settingsOptions then self:RefreshSettingsChoices(); return self.settingsOptions end
    local options = {
        {type = 'description', text = 'Choose four Multi-Rider and four Single-Rider favorites here or in the dashboard. Hotkeys work in either mode.'},
        {
            type = 'mountswapchattoggle', name = 'Show MountSwap chat messages', width = 'full',
            tooltip = 'Turn off normal MountSwap chat messages while keeping upper-right notifications. Explicit debug commands still print diagnostics.',
            getFunc = function() return M.saved.chatMessages ~= false end,
            setFunc = function(value) M.saved.chatMessages = value end,
            default = true,
        },
        {
            type = 'mountswapdashboard', name = 'Enable dashboard', width = 'full',
            tooltip = 'Turn off to manage favorites only in Settings. /mountswap and the open-selector key then open settings. Mount hotkeys keep working.',
            getFunc = function() return M.saved.standalonePanel ~= false end,
            setFunc = function(value) M:SetStandalonePanel(value) end,
            openFunc = function()
                if M.saved.standalonePanel == false then return end
                SCENE_MANAGER:Hide('gameMenuInGame')
                if not M.window or M.window:IsHidden() then M:Toggle() end
            end,
            default = true,
        },
        {type = 'mountswaprightbutton', name = 'Keybindings', width = 'full', func = function() M:OpenKeybindings() end},
        {type = 'dropdown', name = 'Controller text size', choices = {'Normal','Large','Extra Large'}, default = 'Normal',
            getFunc = function() return M.saved.controllerTextSize or 'Normal' end,
            setFunc = function(size)
                if size~='Normal' and size~='Large' and size~='Extra Large' then return end
                M.saved.controllerTextSize=size
                if M.menuState then M:RefreshControllerMenu() end
                M:SyncGamepad()
            end},
    }
    local languageNames,languageCodes=self:LanguageChoices()
    options[#options+1]={type='dropdown',name='Language',choices=languageNames,choicesValues=languageCodes,
        default='auto',requiresReload=true,
        tooltip='Language changes apply after /reloadui. Existing settings are preserved. ESO supplies mount names in the game client language.',
        getFunc=function() return M.saved.language or 'auto' end,
        setFunc=function(code)
            local valid={auto=true,en=true,de=true,fr=true,es=true,ru=true,zh=true,ja=true}
            if valid[code] then M.saved.language=code end
        end}
    options[#options+1]={type='button',name='Reload UI',func=function()
        ReloadUI()
    end}
    self.settingsDropdowns = {}
    for slot = 1, 8 do
        local s = slot
        if s == 1 or s == 5 then
            options[#options + 1] = {type = 'header', name = s == 1 and 'Multi-Rider favorites' or 'Single-Rider favorites'}
            local group = s == 1 and 'multi' or 'single'
            self.settingsSearch = self.settingsSearch or {multi = '', single = ''}
            options[#options + 1] = {
                type = 'editbox', name = s == 1 and 'Search Multi-Rider mounts' or 'Search Single-Rider mounts',
                tooltip = 'Filter the four mount dropdowns below. Clear the text to show all mounts. Search results include only matches. Your saved favorite stays displayed but is not added to the results unless it matches.',
                reference = 'MountSwapSettingsSearch_' .. group,
                getFunc = function() return M.settingsSearch[group] end,
                setFunc = function(text) M:SetSettingsSearch(group, text) end,
                isMultiline = false, maxChars = 100, default = '',
            }
        end
        local prefix = s <= 4 and 'M' or 'S'
        local number = s <= 4 and s or s - 4
        local data = {
            type = 'mountswapfavorite', name = prefix .. number, width = 'full', slotIndex = s,
            useName = 'Use ' .. prefix .. number,
            useFunc = function() M:Slot(s) end,
            tooltip = 'Unlocked mounts of this type, sorted A-Z. None clears this slot. Choosing a favorite saves it without activating it.',
            choices = {'None'}, choicesValues = {0}, scrollable = true,
            reference = 'MountSwapSettingsSlot' .. s,
            getFunc = function()
                local slots = M.saved.slots -- Resolve on invocation, not before a profile is loaded.
                return slots[s] or 0
            end,
            setFunc = function(id)
                if id == 0 then
                    M.saved.slots[s] = nil
                else
                    M:Mounts()
                    if M:Assign(s, id) then
                        M:NotifyMount(id, prefix .. number .. ' favorite saved')
                    end
                end
                M:Refresh()
                M:RefreshSettingsChoices()
            end,
            default = 0,
        }
        self.settingsDropdowns[s] = data
        options[#options + 1] = data

    end
    options[#options + 1] = {type = 'header', name = 'General actions'}
    options[#options + 1] = {type = 'button', name = 'Random mount', width = 'half', func = function() M:Random() end}
    options[#options + 1] = {type = 'button', name = 'Join nearest multi-rider', tooltip = 'Use the nearest available passenger seat on a group member’s multi-rider mount.', width = 'half', func = function() M:NearestPassenger() end}
    options[#options + 1] = {
        type = 'description',
        text = 'Mount lists use ESO Collections categories. If a mount is unclassified, enable the standalone panel temporarily and use Manage mount categories.',
    }
    options[#options + 1] = {type = 'header', name = 'Chat command shortcuts'}
    options[#options + 1] = {
        type = 'description',
        text = 'Choose a command for each action. Use letters, numbers or underscores, starting with a letter. The / is optional when entering a command. Leave blank to disable a shortcut. Press Enter or leave the field to apply.',
    }
    for _, option in ipairs(self.commandOptions) do
        local key, default = option.key, option.default
        options[#options + 1] = {
            type = 'editbox', name = option.name, isMultiline = false, maxChars = 26,
            getFunc = function() return tostring(M.saved.commands[key] or '') end,
            setFunc = function(text) M:SetCommand(key, text) end,
            warning = function() return M.commandErrors and M.commandErrors[key] end,
            default = default,
        }
    end
    options[#options + 1] = {type = 'button', name = 'Reset command shortcuts to defaults',
        tooltip = 'Restore /ms, /m1 through /m4, and /s1 through /s4. If any default is in use by ESO or another addon, no shortcuts are changed.',
        func = function() M:ResetCommands() end}
    options[#options + 1] = {type = 'description', text = function() return M:CommandStatus() end}
    self.settingsOptions=options
    self:LocalizeSettings(options)
    self:RefreshSettingsChoices()
    return options
end
function M:InitializeSettings()
    if self.settingsRegistered then return true end
    local library = LibAddonMenu2
    if not library then return false end
    self:RegisterFavoriteWidget(library)
    self:RegisterDashboardWidget(library)
    self:RegisterSettingsLayoutWidgets(library)
    self.settingsPanel = library:RegisterAddonPanel('MountSwapOptions', {
        type = 'panel', name = 'MountSwap', displayName = 'MountSwap',
        author = 'ShadowStrikerr', version = self.version, registerForRefresh = true,
    })
    local options=self:SettingsControls()
    library:RegisterOptionControls('MountSwapOptions', options)
    self.settingsRegistered = true
    if CALLBACK_MANAGER then
        CALLBACK_MANAGER:RegisterCallback('LAM-PanelOpened', function(panel)
            if panel == M.settingsPanel then M:ApplyCommands(); M:HookSettingsSearch(); M:RefreshSettingsChoices(); M:RefreshCommandControls() end
        end)
    end
    return true
end
function M:OpenSettings()
    if IsInGamepadPreferredMode() then self:GamepadSettings(); return end
    if self:InitializeSettings() then
        self:ClosePicker()
        self:CloseWindows()
        self:RefreshSettingsChoices()
        local library = LibAddonMenu2 -- Optional library is resolved after initialization.
        library:OpenToPanel(self.settingsPanel)
    else
        self:Chat('Settings > Addons requires LibAddonMenu-2.0. Use /mountswap chat off or /mountswap chat on to control chat messages.', true)
    end
end
