local A = OneChat

function A:RestoreSelection()
    if not self.activeWindow then return end
    local state = self.windows[self.activeWindow]
    local selected = self:ResolveSelection(state)
    self.temporary, self.restoring = false, true
    self.empty = selected == nil
    if selected then
        local entry = self.chat.textEntry
        local draft = entry:GetText()
        if self.chat.currentChannel ~= selected.channel or self.chat.currentTarget ~= nil then
            self.chat:SetChannel(selected.channel)
        end
        -- Native SetChannel closes a nonfocused entry and can erase a draft
        -- retained by Escape. Restore that text without reparsing commands.
        if entry:GetText() ~= draft then
            local previous = self.chat.ignoreTextEntryChangedEvent
            self.chat.ignoreTextEntryChangedEvent = true
            entry:SetText(draft)
            self.chat.ignoreTextEntryChangedEvent = previous
        end
        self.chat:UpdateTextEntryChannel()
    else
        -- Keep a valid native channel internally. Native StartTextEntry and
        -- GetCurrentChannelData require one. SubmitTextEntry is gated below.
        self.chat.textEntry.channelLabel:SetText(GetString(SI_ONECHAT_EMPTY_CHANNEL))
    end
    self.restoring = false
end

function A:ChooseChannel(t)
    if not self.activeWindow then return end
    local state = self.windows[self.activeWindow]
    if not state.outgoing[t.key] or not self:IsAvailable(t) then return end
    state.last = t.key
    self:RestoreSelection()
    -- StartTextEntry preserves any current draft and places focus in it.
    self.restoring = true
    self.chat:StartTextEntry(self.chat.textEntry:GetText(), t.channel)
    self.restoring = false
end

function A:ShowChannelMenu()
    ClearMenu()
    local state = self.activeWindow and self.windows[self.activeWindow]
    local allowed = state and self:Allowed(state) or {}
    local switches = {}
    local function menuOrder(t)
        if t.key == "zone" then return 0 end
        if t.key == "say" then return 2 end
        if t.key == "yell" then return 3 end
        if t.key == "emote" then return 4 end
        if t.guildId then
            for slot = 1, GetNumGuilds() do
                if GetGuildId(slot) == t.guildId then
                    return 10 + slot * 2 + (t.key:match("^officer:") and 1 or 0)
                end
            end
        end
        if t.key == "group" then return 100 end
        return 110 -- Targeted/private channels, if available, follow Group.
    end
    for _, t in ipairs(allowed) do
        local switch = self.chat.switchLookup[t.channel]
        if switch then switches[#switches + 1] = { text = switch, token = t, order = menuOrder(t) } end
    end
    -- Keep the native labels/colors, but group related channels rather than
    -- sorting slash commands alphabetically across unrelated categories.
    table.sort(switches, function(left, right)
        if left.order ~= right.order then return left.order < right.order end
        return left.text < right.text
    end)
    for _, entry in ipairs(switches) do
        local t = entry.token
        local r, g, b = ZO_ChatSystem_GetCategoryColorFromChannel(t.channel)
        local choice = t
        AddMenuItem(entry.text, function() A:ChooseChannel(choice) end,
            nil, nil, ZO_ColorDef:New(r, g, b))
    end
    if #switches == 0 then
        AddMenuItem(GetString(SI_ONECHAT_NO_CHANNELS), function() end)
    end
    ShowMenu(self.chat.textEntry:GetControl())
end

function A:InstallInput()
    ZO_PreHook(self.chat, "ShowTextEntryMenu", function()
        A:ShowChannelMenu()
        return true
    end)
    -- A nonzero label width makes the empty selector clickable too.
    self.chat.textEntry.channelLabel:SetDimensionConstraints(24, 0, 0, 0)
    ZO_PostHookHandler(self.chat.textEntry.channelLabel, "OnMouseEnter", function()
        WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
    end)
    ZO_PostHookHandler(self.chat.textEntry.channelLabel, "OnMouseExit", function()
        WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
    end)
    SecurePostHook(self.chat, "SetChannelInternal", function(chat)
        if not A.restoring then
            A.temporary = true
            -- SetChannelInternal is a no-op when the manual command selects
            -- the same hidden backing channel used by an empty tab.
            chat:UpdateTextEntryChannel()
        end
    end)
    ZO_PreHook(self.chat, "SubmitTextEntry", function(chat)
        local text = chat.textEntry:GetText()
        A.pendingSend = false
        if #text == 0 then return end
        -- Native slash-command dispatch and switch parsing stay untouched.
        local isCommand = chat.commandPrefixes[text:byte(1)] ~= nil
        local switch = chat.switchLookup[text:lower()]
        if not isCommand and not switch then
            if A.empty and not A.temporary then
                A:Notify(SI_ONECHAT_SELECT_CHANNEL)
                return true
            end
            A.pendingSend = true
        end
    end)
    -- No replacement/call of the private SendChatMessage function. Only the
    -- player's normal vanilla submission path sends a message.
    SecurePostHook(self.chat, "SubmitTextEntry", function()
        if A.pendingSend then
            A.pendingSend = false
            A:RestoreSelection()
        end
    end)
end
