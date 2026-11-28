local M = MountSwap

M.commandOptions = {{key = 'menu', name = 'Open MountSwap', default = '/ms'}}
for slot = 1, 8 do
    local multi = slot <= 4
    local label = (multi and 'M' or 'S') .. (multi and slot or slot - 4)
    M.commandOptions[#M.commandOptions + 1] = {
        key = slot, name = label .. ' command', default = '/' .. string.lower(label),
    }
end

local function normalize(text)
    if type(text) ~= 'string' then return nil end
    text = string.lower(text:match('^%s*(.-)%s*$'))
    if text == '' then return '' end -- A blank field disables that shortcut.
    if text:sub(1, 1) ~= '/' then text = '/' .. text end
    if #text > 25 or not text:match('^/[a-z][a-z0-9_]*$') then return nil end
    return text
end

function M:CommandConflict(command)
    if command == '' then return end
    -- Permanent commands cannot be repurposed as shortcuts, even for the same action.
    if command == '/mountswap' or command == '/mountswapr' or command == '/mountswapnear'
        or command:match('^/mountswap[1-8]$') then
        return 'reserved for an original MountSwap command'
    end
    local switches = ZO_ChatSystem_GetChannelSwitchLookupTable and ZO_ChatSystem_GetChannelSwitchLookupTable()
    if (switches and switches[command]) or (CHAT_SYSTEM and CHAT_SYSTEM.switchLookup and CHAT_SYSTEM.switchLookup[command]) then
        return 'used by an ESO chat channel'
    end
    local owner = SLASH_COMMANDS[command]
    if owner ~= nil and owner ~= (self.ownedCommands and self.ownedCommands[command]) then
        return 'already used by ESO or another addon'
    end
end

function M:RefreshCommandControls()
    if self.settingsPanel and CALLBACK_MANAGER and CALLBACK_MANAGER.FireCallbacks then
        CALLBACK_MANAGER:FireCallbacks('LAM-RefreshPanel', self.settingsPanel)
    end
end

function M:ApplyCommands()
    -- Release only handlers that still belong to us. Never erase another addon's replacement.
    for command, handler in pairs(self.ownedCommands or {}) do
        if SLASH_COMMANDS[command] == handler then SLASH_COMMANDS[command] = nil end
    end
    self.ownedCommands, self.commandErrors = {}, {}
    local owned, errors, commands = self.ownedCommands, self.commandErrors, self.saved.commands
    local seen = {}
    for _, option in ipairs(self.commandOptions) do
        local command = normalize(commands[option.key])
        local reason
        if not command then
            reason = 'use a letter followed by letters, numbers or underscores (24 characters maximum)'
        elseif command ~= '' then
            reason = seen[command] and 'assigned to another MountSwap shortcut' or self:CommandConflict(command)
            seen[command] = true
        end
        if reason then
            errors[option.key] = (command or M.L('Invalid command')) .. ': ' .. M.L(reason)
        elseif command ~= '' then
            local key = option.key
            local handler = function(argument)
                if key == 'menu' then SLASH_COMMANDS['/mountswap'](argument)
                else M:Slot(key) end
            end
            SLASH_COMMANDS[command] = handler
            owned[command] = handler
        end
    end
end

function M:InitializeCommands()
    if type(self.saved.commands) ~= 'table' then self.saved.commands = {} end
    local commands = self.saved.commands
    for _, option in ipairs(self.commandOptions) do
        if commands[option.key] == nil then commands[option.key] = option.default end
    end
    self:ApplyCommands()
end

function M:SetCommand(key, text)
    local commands = self.saved.commands
    local known
    for _, option in ipairs(self.commandOptions) do if option.key == key then known = true end end
    if not known then return false end
    local command = normalize(text)
    local reason
    if not command then
        reason = 'Use a letter followed by letters, numbers or underscores, up to 24 characters; leave blank to disable.'
    else
        reason = self:CommandConflict(command)
        if command ~= '' then
            for _, option in ipairs(self.commandOptions) do
                if option.key ~= key and normalize(commands[option.key]) == command then
                    reason = 'That command is assigned to another MountSwap shortcut.'
                end
            end
        end
    end
    if reason then
        self:Chat('Shortcut unchanged: ' .. M.L(reason), true)
        self:RefreshCommandControls()
        return false
    end
    commands[key] = command
    self:ApplyCommands()
    self:RefreshCommandControls()
    return true
end

function M:ResetCommands()
    local commands = self.saved.commands
    -- Validate the entire reset first, so a conflict cannot discard working custom commands.
    for _, option in ipairs(self.commandOptions) do
        local reason = self:CommandConflict(option.default)
        if reason then
            self:Chat('Shortcuts unchanged: ' .. option.default .. ' is ' .. M.L(reason) .. '.', true)
            self:RefreshCommandControls()
            return false
        end
    end
    for _, option in ipairs(self.commandOptions) do commands[option.key] = option.default end
    self:ApplyCommands()
    self:RefreshCommandControls()
    return true
end

function M:CommandStatus()
    local lines = {}
    local errors = self.commandErrors
    for _, option in ipairs(self.commandOptions) do
        local error = errors and errors[option.key]
        if error then lines[#lines + 1] = M.L(M.L(option.name) .. ' unavailable: ' .. error .. '.') end
    end
    if #lines == 0 then return 'Shortcuts apply immediately. Original /mountswap commands always remain available.' end
    lines[#lines + 1] = M.L('Choose a different shortcut. Original /mountswap commands remain available.')
    return table.concat(lines, '\n')
end
