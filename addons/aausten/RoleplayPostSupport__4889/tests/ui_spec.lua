-- Run from the repository root: python3 tests/run.py tests/ui_spec.lua
-- Lua 5.1-compatible. Real Queue/Sessions/Splitter; mocked ESO controls and Chat
-- preparation boundary. This checks behavior, not native rendering or mouse routing.
local localization = dofile("tests/localization_fixture.lua")
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected "
        .. tostring(expected) .. ", got " .. tostring(actual))
end

TOPLEFT, TOP, CENTER = 1, 2, 3
CT_LABEL, CT_BUTTON, CT_BACKDROP, CT_CONTROL = 1, 2, 3, 4
MOUSE_BUTTON_INDEX_LEFT = 1
TEXT_ALIGN_RIGHT = 2
CHAT_CHANNEL_SAY, CHAT_CHANNEL_EMOTE, CHAT_CHANNEL_PARTY = 0, 13, 19
CHAT_CHANNEL_WHISPER, CHAT_CHANNEL_WHISPER_SENT = 31, 32
for i = 1, 5 do
    _G["CHAT_CHANNEL_GUILD_" .. i] = 200 + i
    _G["CHAT_CHANNEL_OFFICER_" .. i] = 300 + i
end

local function fixture(position, saved, translations)
    local f = { controls = {}, names = {}, trace = {}, notices = {}, prepared = {},
        timers = {}, previews = 0, starts = 0, sends = 0, violations = 0,
        cursorMode = false, cursorModeCalls = 0, currentChannel = CHAT_CHANNEL_SAY,
        currentTarget = "", currentDestinationCalls = 0 }
    local methods = {}
    function methods:SetHandler(event, callback) self.handlers[event] = callback end
    function methods:SetText(text, ...)
        equal(select("#", ...), 0, "SetText argument count")
        assert(type(text) == "string", "SetText requires a string")
        local changed = self.text ~= text
        self.setTextCalls = (self.setTextCalls or 0) + 1
        self.text = text
        if changed and self.handlers.OnTextChanged then self.handlers.OnTextChanged(self) end
    end
    function methods:GetText() return self.text or "" end
    function methods:SetHidden(hidden)
        assert(type(hidden) == "boolean")
        local changed = self.hidden ~= hidden
        self.hidden = hidden
        if changed and hidden and self.handlers.OnHide then self.handlers.OnHide(self) end
        if changed and not hidden and self.handlers.OnShow then self.handlers.OnShow(self) end
    end
    function methods:IsHidden()
        return self.hidden or (self.parent and self.parent:IsHidden()) or false
    end
    function methods:SetEnabled(enabled) assert(type(enabled) == "boolean"); self.enabled = enabled end
    function methods:SetAnchor(...) self.anchor = { ... } end
    function methods:SetAnchorFill(parent) self.fill = parent end
    function methods:SetDimensions(width, height) self.width, self.height = width, height end
    function methods:SetFont(font) self.font = font end
    function methods:SetHorizontalAlignment(value) self.horizontalAlignment = value end
    function methods:SetColor(...) self.color = { ... } end
    function methods:SetClampedToScreen(value) self.clamped = value end
    function methods:SetMouseEnabled(value) self.mouseEnabled = value end
    function methods:SetMovable(value) self.movable = value end
    function methods:SetMaxInputChars(value) self.cap = value end
    function methods:SetNewLineEnabled(value) self.newlines = value end
    function methods:GetScrollExtents()
        self.extentCalls = (self.extentCalls or 0) + 1
        self.extentText = self:GetText()
        -- Model a four-line viewport; tests can override the extent to simulate wrapping.
        local _, newlines = self.extentText:gsub("\n", "")
        return self.scrollExtent or math.max(0, newlines + 1 - 4)
    end
    function methods:SetTopLineIndex(value)
        self.topLineCalls = (self.topLineCalls or 0) + 1
        self.topLine = value
    end
    function methods:GetLeft() return self.left or 0 end
    function methods:GetTop() return self.top or 0 end
    function methods:StartMoving() assert(self.movable); self.moving = true end
    function methods:StopMovingOrResizing()
        self.moving = false
        if self.handlers.OnMoveStop then self.handlers.OnMoveStop(self) end
    end
    function methods:TakeFocus() f.focus = self end
    function methods:LoseFocus()
        f.trace[#f.trace + 1] = "blur"
        if f.focus == self then f.focus = nil end
    end
    f.nativeEscape = function(self) self:LoseFocus() end
    f.nativeWheel = function() end
    -- Only preserve the template handler identity; native menu rendering/closing is ESO's job.
    f.nativeComboHidden = function() end
    local comboMethods = {}
    function comboMethods:SetFont(font) self.font = font end
    function comboMethods:SetSortsItems(value) self.sortsItems = value end
    function comboMethods:CreateItemEntry(name, callback)
        assert(type(name) == "string" and type(callback) == "function")
        return { name = name, callback = callback }
    end
    function comboMethods:AddItem(item)
        self.items[#self.items + 1] = item
        if self.sortsItems then
            table.sort(self.items, function(a, b) return a.name < b.name end)
        end
    end
    function comboMethods:SetEnabled(value) assert(type(value) == "boolean"); self.enabled = value end
    function comboMethods:SetSelectedItemText(text) self.selectedText = text end
    function comboMethods:SelectItemByIndex(index, ignoreCallback)
        local item = assert(self.items[index], "combo item index out of range")
        local oldItem = self.selectedItem
        self.selectedItem, self.selectedText = item, item.name
        if not ignoreCallback then
            self.callbackCalls = self.callbackCalls + 1
            -- ESO passes the name second, not the item or its index.
            item.callback(self, item.name, item, item ~= oldItem, oldItem)
        end
    end
    local function create(name, parent, kind, template)
        assert(not f.names[name], "duplicate control name: " .. name)
        local item = setmetatable({ name = name, parent = parent, kind = kind,
            template = template, handlers = {}, hidden = false, enabled = true }, { __index = methods })
        if template == "ZO_DefaultEditMultiLineForBackdrop" then
            item.handlers.OnEscape, item.handlers.OnMouseWheel = f.nativeEscape, f.nativeWheel
        elseif template == "ZO_ComboBox" then
            item.handlers.OnEffectivelyHidden = f.nativeComboHidden
            item.combo = setmetatable({ container = item, items = {}, sortsItems = true,
                enabled = true, callbackCalls = 0 }, { __index = comboMethods })
        end
        f.controls[#f.controls + 1], f.names[name] = item, item
        return item
    end
    GuiRoot = create("GuiRoot")
    local windowManager = {}
    function windowManager:CreateTopLevelWindow(name) return create(name) end
    function windowManager:CreateControl(name, parent, kind) return create(name, parent, kind) end
    function windowManager:CreateControlFromVirtual(name, parent, template)
        return create(name, parent, nil, template)
    end
    WINDOW_MANAGER = windowManager
    ZO_ComboBox_ObjectFromContainer = function(container)
        equal(container.template, "ZO_ComboBox")
        return assert(container.combo)
    end
    SetGameCameraUIMode = function(active)
        assert(type(active) == "boolean")
        f.cursorMode, f.cursorModeCalls = active, f.cursorModeCalls + 1
    end
    local function forbidden()
        f.violations = f.violations + 1
        error("UI must not access native chat input, send, submit, or install hooks", 2)
    end
    SendChatMessage = function() f.sends = f.sends + 1; forbidden() end
    StartChatInput, ZO_PreHook, ZO_PostHook, SecurePostHook = forbidden, forbidden, forbidden, forbidden
    CHAT_SYSTEM = setmetatable({}, { __index = forbidden, __newindex = forbidden })
    -- This guard deliberately has no return value; it is not an ESO API declaration.
    rawset(_G, "ZO_GetChatSystem", forbidden)
    GetTimeStamp = function() return 1700000000 end
    GetDisplayName = function() return "@Local" end
    GetUnitName = function() return "Local Hero" end
    zo_callLater = function(callback, delay)
        f.timers[#f.timers + 1] = { callback = callback, delay = delay }
    end
    -- Keep a 24-character readable budget after reserving the four-character tag.
    RoleplayPostSupport = { version = "1.2.2", saved = { maxChars = 28, prefix = "+ ", suffix = " +", sentences = true,
        window = position or {} }, Debug = function(_message) end }
    local A = RoleplayPostSupport
    f.localization = localization.load(translations)
    for key, value in pairs(saved or {}) do A.saved[key] = value end
    f.A = A
    A.Chat = { Destinations = {
        { label = "Say", channel = CHAT_CHANNEL_SAY },
        { label = "Emote", channel = CHAT_CHANNEL_EMOTE },
        { label = "Group", channel = CHAT_CHANNEL_PARTY },
    } }
    for _, kind in ipairs({ "GUILD", "OFFICER" }) do
        for i = 1, 5 do
            A.Chat.Destinations[#A.Chat.Destinations + 1] = {
                label = kind .. i, channel = _G["CHAT_CHANNEL_" .. kind .. "_" .. i],
            }
        end
    end
    A.Chat.Destinations[#A.Chat.Destinations + 1] = { label = "Whisper", channel = CHAT_CHANNEL_WHISPER }
    function A.Chat.GetLimit() return 350 end
    function A.Chat.CurrentDestination()
        f.currentDestinationCalls = f.currentDestinationCalls + 1
        return f.currentChannel, f.currentTarget
    end
    function A.Chat.ValidateDestination(channel, target)
        if type(channel) ~= "number" then return nil, "Channel required." end
        if channel == CHAT_CHANNEL_WHISPER and (not target or target == "") then
            return nil, "Target required."
        end
        return true
    end
    function A.Chat.Prepare(text, channel, target, automatic)
        f.prepared[#f.prepared + 1] = { text = text, channel = channel, target = target, automatic = automatic }
        f.trace[#f.trace + 1] = "prepare"
        f.focus = "native chat"
        return true
    end
    function A.Chat.ClearOwnership() f.ownershipCleared = true end
    function A.Chat.SameDestination(channel, target, otherChannel, otherTarget)
        return channel == otherChannel and (target or "") == (otherTarget or "")
    end
    function A.Chat.MatchesEcho(attempt, channel, fromName, fromDisplayName)
        return channel == attempt.channel and fromDisplayName == "@Local"
    end
    dofile("RoleplayPostSupport_Splitter.lua")
    dofile("RoleplayPostSupport_Sessions.lua")
    dofile("RoleplayPostSupport_Queue.lua")
    assert(A.Sessions.Init(A.saved))
    function A.Preview(text)
        f.previews = f.previews + 1
        local limit, err = A.Chat.GetLimit()
        if not limit then return nil, err end
        return A.Splitter.Split(text, {
            maxChars = math.min(A.saved.maxChars or limit, limit) - A.Splitter.MESSAGE_TAG_LENGTH,
            prefix = A.saved.prefix, suffix = A.saved.suffix, sentences = A.saved.sentences,
        })
    end
    function A.Start(text, channel, target)
        f.starts = f.starts + 1
        f.startArguments = { text, channel, target }
        local chunks, err = A.Preview(text)
        if not chunks then return nil, err end
        if channel == CHAT_CHANNEL_WHISPER then
            target = (target or ""):gsub("^%s+", ""):gsub("%s+$", "")
        else
            target = nil
        end
        for index, chunk in ipairs(chunks) do chunks[index] = A.Splitter.MESSAGE_TAG .. chunk end
        return A.Queue.Start(chunks, channel, target)
    end
    function A.ApplySettings(maxChars, prefix, suffix, sentences)
        local options = { maxChars = maxChars, prefix = prefix, suffix = suffix, sentences = sentences }
        local chunks, err = A.Splitter.Split("Validate settings", options)
        if not chunks then return nil, err end
        A.saved.maxChars, A.saved.prefix, A.saved.suffix, A.saved.sentences = maxChars, prefix, suffix, sentences
        return true
    end
    function A.Notify(message)
        f.notices[#f.notices + 1] = message
        f.trace[#f.trace + 1] = "notify"
        A.UI.Notify(message)
    end
    dofile("RoleplayPostSupport_UI.lua")
    f.UI = A.UI
    function f:find(predicate)
        local found
        for _, item in ipairs(self.controls) do
            if predicate(item) then assert(not found, "ambiguous control lookup"); found = item end
        end
        assert(found, "control not found")
        return found
    end
    function f:within(item, parent)
        while item do
            if item == parent then return true end
            item = item.parent
        end
        return false
    end
    function f:button(text, parent)
        return self:find(function(item)
            return item.text == text and item.handlers.OnClicked and (not parent or self:within(item, parent))
        end)
    end
    function f:click(text, parent)
        local item = self:button(text, parent)
        assert(item.enabled and not item:IsHidden(), "button unavailable: " .. text)
        item.handlers.OnClicked(item)
    end
    function f:selectDestination(label)
        local combo = self.destination
        assert(combo.enabled and not combo.container:IsHidden(), "destination unavailable")
        for index, item in ipairs(combo.items) do
            if item.name == label then combo:SelectItemByIndex(index); return end
        end
        error("destination not found: " .. label)
    end
    function f:editor(width, height)
        -- Identify anonymous editors by backdrop geometry, never creation sequence.
        return self:find(function(item)
            return (item.template == "ZO_DefaultEditMultiLineForBackdrop" or item.template == "ZO_DefaultEditForBackdrop")
                and item.parent.width == width and item.parent.height == height
        end)
    end
    function f:init()
        assert(self.UI.Init())
        self.main = self.names.RoleplayPostSupportWindow
        self.queue = self.names.RoleplayPostSupportQueueIndicator
        self.recording = self.names.RoleplayPostSupportRecordingIndicator
        self.composer, self.participants = self:editor(740, 218), self:editor(740, 76)
        self.history, self.preview = self:editor(740, 120), self:editor(740, 84)
        self.destination = self:find(function(item) return item.template == "ZO_ComboBox" end).combo
        self.target = self:editor(370, 28)
        return self
    end
    function f:session(name, participants)
        local session = assert(A.Sessions.Create(name or "Tavern", CHAT_CHANNEL_SAY))
        assert(A.Sessions.Select(session.id))
        if participants then assert(A.Sessions.SetParticipants(participants)) end
        self.UI.Refresh()
        return session
    end
    function f:capture(first, last)
        for i = first, last do
            assert(A.Sessions.Capture(CHAT_CHANNEL_SAY, "Local Hero", "Line " .. i, false, "@Local"))
        end
    end
    function f:close()
        local close = self:find(function(item) return item.template == "ZO_CloseButton" end)
        close.handlers.OnClicked(close)
    end
    return f
end

local tests, failures = 0, {}
local function test(name, callback)
    local ok, err = xpcall(callback, debug.traceback)
    if not ok then
        failures[#failures + 1] = "FAIL UI: " .. name .. "\n" .. err
        print(failures[#failures])
        return
    end
    tests = tests + 1
    print("PASS UI: " .. name)
end

test("translations supplied before UI load render visible labels and real session errors", function()
    local f = fixture(nil, nil, { UI_WINDOW_TITLE = "Atelier RP", UI_COMPOSE_TAB = "Rédiger",
        UI_SESSIONS_TAB = "Archives", UI_PREVIEW = "Aperçu", UI_DRAFT_NOTICE = "Brouillon privé.",
        UI_CREATE_SESSION = "Créer une scène", UI_ERROR_NAME_REQUIRED = "Nom requis.",
        UI_VERSION = "Édition %s", UI_SESSION_TITLE = "Scène %d/%d : %s",
        UI_HISTORY_INCOMING = "À %s — %s dit : %s" }):init()
    f.UI.Toggle()
    for _, text in ipairs({ "Atelier RP", "Rédiger", "Archives", "Aperçu", "Brouillon privé.", "Édition 1.2.2" }) do
        assert(not f:find(function(item) return item.text == text end):IsHidden(), "translated label must be visible")
    end
    f:button("Apply") -- An omitted translation still renders English.
    f:click("Archives")
    local value, code = f.A.Sessions.Create("", CHAT_CHANNEL_SAY)
    equal(value, nil); equal(code, "name_required", "internal code is not translated")
    f:click("Créer une scène")
    equal(f.notices[#f.notices], "Nom requis.")
    assert(not f:find(function(item) return item.text == "Nom requis." end):IsHidden())
    local name, sender, raw = "Scène 100% <<1>> 雪", "@Zoë%s", "100% %d <<2>>\n雪 reste intacte"
    f:editor(424, 28):SetText(name)
    f:click("Créer une scène")
    local session = assert(f.A.Sessions.Current())
    equal(session.name, name)
    equal(session.channel, CHAT_CHANNEL_SAY)
    equal(f.notices[#f.notices], "Session created and selected. Recording is off.")
    assert(not f:find(function(item) return item.text == "Scène 1/1 : " .. name end):IsHidden())
    assert(f.A.Sessions.SetParticipants(sender))
    assert(f.A.Sessions.SetRecording(true))
    assert(f.A.Sessions.Capture(CHAT_CHANNEL_SAY, sender, raw, false, sender))
    f.UI.Refresh()
    equal(session.messages[1].sender, sender); equal(session.messages[1].text, raw)
    equal(f.history:GetText(), "À " .. os.date("%Y-%m-%d %H:%M:%S", session.messages[1].timestamp)
        .. " — " .. sender .. " dit : " .. raw)
    equal(f.A.saved.prefix, "+ "); equal(f.A.saved.suffix, " +")
    equal(#f.prepared, 0); equal(f.sends, 0); equal(f.violations, 0)
end)

test("all eleven stable session codes render readable English at the UI boundary", function()
    local f = fixture():init()
    f.UI.Toggle(); f:click("Sessions")
    local messages = {
        invalid_channel = "Select a valid player chat channel.",
        target_required = "Enter a whisper target.",
        invalid_saved_variables = "Session saved variables are invalid.",
        not_initialized = "Sessions are not initialized.",
        session_limit = "The saved session limit has been reached. Delete a session before creating another.",
        name_required = "Enter a session name.", session_not_found = "Session not found.",
        no_current_session = "Select a session first.", invalid_participants = "Enter participant names as text.",
        invalid_addon_only_flag = "The addon-only recording setting must be on or off.",
        invalid_recording_flag = "The recording setting must be on or off.",
    }
    for code, message in pairs(messages) do
        f.A.Sessions.Create = function() return nil, code end
        f:click("Create named session")
        equal(f.notices[#f.notices], message, code)
        assert(not f:find(function(item) return item.text == message end):IsHidden())
    end
    -- Messages already explained by other modules must not be mistaken for keys.
    ---@diagnostic disable-next-line: duplicate-set-field -- Replace the code-returning spy with a plain-message failure.
    f.A.Sessions.Create = function() return nil, "Custom failure 100% <<1>>" end
    f:click("Create named session")
    equal(f.notices[#f.notices], "Custom failure 100% <<1>>")
    equal(#f.prepared, 0); equal(f.sends, 0); equal(f.violations, 0)
end)

test("Init is deferred, guarded and idempotent; native editor handlers are inherited", function()
    local f = fixture()
    equal(#f.controls, 1, "no controls before Init")
    f.UI.Refresh()
    f.UI.Notify("Before Init")
    local saved = f.A.saved
    f.A.saved = nil
    local ok, err = f.UI.Init()
    assert(not ok and type(err) == "string")
    equal(#f.controls, 1)
    f.A.saved = saved
    f:init()
    local count = #f.controls
    assert(f.UI.Init())
    equal(#f.controls, count)
    assert(f.main:IsHidden() and f.queue:IsHidden() and f.recording:IsHidden())
    equal(f.main.width, 780); equal(f.main.height, 678)
    equal(f.composer.cap, 1000000); equal(f.composer.newlines, true)
    equal(f.participants.font, "ZoFontGameSmall")
    equal(f.history.font, "ZoFontGameSmall")
    equal(f.composer.handlers.OnEscape, f.nativeEscape)
    equal(f.composer.handlers.OnMouseWheel, f.nativeWheel)
    equal(f.main.handlers.OnEscape, nil, "no global Escape interception")
    f.composer:TakeFocus(); f.composer.handlers.OnEscape(f.composer)
    equal(f.focus, nil)
    equal(f.violations, 0)
end)

test("opening the main window enables cursor mode only on show, without taking editor focus", function()
    local f = fixture():init()
    equal(f.cursorModeCalls, 0)
    f.UI.Toggle()
    equal(f.cursorMode, true); equal(f.cursorModeCalls, 1)
    equal(f.focus, nil); equal(#f.prepared, 0); equal(f.sends, 0)
    f.cursorMode = false -- The player can leave cursor mode while the window stays open.
    f.UI.Refresh(); f.UI.Refresh()
    equal(f.cursorMode, false); equal(f.cursorModeCalls, 1)
    f.UI.Toggle()
    equal(f.cursorModeCalls, 1, "hiding does not force a cursor-mode change")
    f.UI.Toggle()
    equal(f.cursorMode, true); equal(f.cursorModeCalls, 2)
    f:close()
    equal(f.cursorMode, true); equal(f.cursorModeCalls, 2)
end)

test("queue indicator Open enables cursor mode without re-preparing or pausing", function()
    local f = fixture():init()
    assert(f.A.Queue.Start({ "One", "Two" }, CHAT_CHANNEL_SAY))
    equal(f.cursorModeCalls, 0, "indicator appearance does not enable cursor mode")
    local staged, prepared, focus = f.A.Queue.staged, #f.prepared, f.focus
    f:click("Open", f.queue)
    equal(f.cursorMode, true); equal(f.cursorModeCalls, 1)
    equal(f.A.Queue.staged, staged); equal(f.A.Queue.paused, false)
    equal(#f.prepared, prepared); equal(f.focus, focus); equal(f.sends, 0)
end)

test("recording indicator Open enables cursor mode and retains recording", function()
    local f = fixture():init()
    f:session("Cursor mode")
    assert(f.A.Sessions.SetRecording(true)); f.UI.Refresh()
    equal(f.cursorModeCalls, 0)
    f:click("Open", f.recording)
    equal(f.cursorMode, true); equal(f.cursorModeCalls, 1)
    assert(f.A.Sessions.IsRecording())
    assert(not f:button("|cFF4444Recording: ON - Stop|r"):IsHidden())
    equal(#f.prepared, 0); equal(f.sends, 0)
end)

test("refresh preserves drafts, settings, participants, review edits and session-local drafts", function()
    local f = fixture():init()
    local first = f:session("First", "@Saved")
    f.composer:SetText("Unsent draft")
    f.participants:SetText("@Unsaved")
    f.history:SetText("Temporary review edits")
    f:editor(90, 28):SetText("42")
    for i = 1, 5 do f.UI.Refresh() end
    equal(f.composer:GetText(), "Unsent draft")
    equal(f.participants:GetText(), "@Unsaved")
    equal(f.history:GetText(), "Temporary review edits")
    equal(f:editor(90, 28):GetText(), "42")
    equal(f.A.saved.maxChars, 28)
    equal(first.participants[1], "@Saved")
    equal(#first.messages, 0)
    local second = f:session("Second", "@Other")
    equal(f.participants:GetText(), "@Other")
    f.participants:SetText("Second draft")
    assert(f.A.Sessions.Select(first.id)); f.UI.Refresh()
    equal(f.participants:GetText(), "@Unsaved")
    assert(f.A.Sessions.Select(second.id)); f.UI.Refresh()
    equal(f.participants:GetText(), "Second draft")
    f.UI.Toggle(); f:click("Sessions"); f:click("Save participants")
    equal(second.participants[1], "Second draft")
    equal(first.participants[1], "@Saved")
    equal(f.A.saved.editor, nil)
end)

test("recording captures actual chat using saved participants, never unsaved editor text", function()
    local f = fixture():init()
    local session = f:session("Filter", "@Saved")
    f.participants:SetText("@Unsaved")
    f.composer:SetText("Never archive this draft")
    f.UI.Toggle(); f:click("Sessions"); f:click("Recording: OFF - Start")
    equal(session.participants[1], "@Saved")
    equal(#session.messages, 0)
    local S = f.A.Sessions
    assert(S.Capture(CHAT_CHANNEL_SAY, "Saved Hero", "Allowed", false, "@Saved"))
    equal(S.Capture(CHAT_CHANNEL_SAY, "Other Hero", "Excluded", false, "@Unsaved"), nil)
    assert(S.Capture(CHAT_CHANNEL_EMOTE, "Saved Hero", "Cross-channel emote", false, "@Saved"))
    assert(S.Capture(CHAT_CHANNEL_PARTY, "Local Hero", "Own group message", false, "@Local"))
    assert(S.Capture(CHAT_CHANNEL_SAY, "Local Hero", "Own actual message", false, "@Local"))
    f.UI.Refresh()
    equal(#session.messages, 4)
    equal(session.messages[2].channel, CHAT_CHANNEL_EMOTE)
    equal(session.messages[3].channel, CHAT_CHANNEL_PARTY)
    f:find(function(item)
        return item.text and item.text:find("Recording scope: all player chat channels", 1, true)
    end)
    f:find(function(item)
        return item.text and item.text:find("All player channels; outgoing whispers to anyone.", 1, true)
    end)
    equal(f.participants:GetText(), "@Unsaved")
    assert(f.history:GetText():find("Saved Hero", 1, true))
    f:click("Save participants")
    assert(S.Capture(CHAT_CHANNEL_SAY, "Other Hero", "Now included", false, "@Unsaved"))
    equal(S.Capture(CHAT_CHANNEL_SAY, "Saved Hero", "Now excluded", false, "@Saved"), nil)
    equal(#session.messages, 5)
end)

test("recording indicator survives close and queue Cancel; Open and Stop are independent", function()
    local f = fixture():init()
    f:session("Tavern")
    f.UI.Toggle(); f:click("Sessions"); f:click("Recording: OFF - Start")
    assert(not f.recording:IsHidden())
    f:find(function(item)
        return f:within(item, f.recording) and item.text and item.text:find("RECORDING", 1, true)
            and item.text:find("Tavern", 1, true)
    end)
    f:close()
    assert(f.main:IsHidden() and f.queue:IsHidden() and not f.recording:IsHidden())
    assert(f.A.Queue.Start({ "One" }, CHAT_CHANNEL_SAY))
    f:click("Cancel", f.queue)
    assert(f.A.Sessions.IsRecording())
    assert(f.queue:IsHidden() and not f.recording:IsHidden())
    f:click("Open", f.recording)
    assert(not f.main:IsHidden())
    assert(not f:button("|cFF4444Recording: ON - Stop|r"):IsHidden())
    f:close()
    f:click("Stop", f.recording)
    assert(not f.A.Sessions.IsRecording() and f.recording:IsHidden() and f.main:IsHidden())
end)

test("recording Stop refreshes immediately without canceling an active queue", function()
    local f = fixture():init()
    local session = f:session("Independent")
    assert(f.A.Sessions.SetRecording(true)); f.UI.Refresh()
    assert(f.A.Queue.Start({ "One" }, CHAT_CHANNEL_SAY))
    f:click("Stop", f.recording)
    assert(not f.A.Sessions.IsRecording() and f.recording:IsHidden())
    assert(f.A.Queue.active and not f.queue:IsHidden())
    equal(f.A.Sessions.Capture(CHAT_CHANNEL_SAY, "Local Hero", "Not recorded", false, "@Local"), nil)
    equal(#session.messages, 0)
end)

test("Finish stays enabled with a missing final echo and manually ends the real queue", function()
    local f = fixture():init()
    assert(f.A.Queue.Start({ "Only chunk" }, CHAT_CHANNEL_SAY))
    f.A.Queue.ObserveSubmission("Only chunk", CHAT_CHANNEL_SAY)
    equal(#f.timers, 1)
    equal(f.timers[1].delay, 10000)
    f.timers[1].callback()
    assert(f.A.Queue.paused and f.A.Queue.pending)
    equal(f:button("Finish", f.queue).enabled, true)
    f:click("Finish", f.queue)
    assert(not f.A.Queue.active and not f.A.Queue.pending and f.queue:IsHidden())
    equal(#f.prepared, 1, "Finish does not reprepare or resend")
    equal(f:button("Finish", f.queue).enabled, false)
    equal(f.sends, 0)
end)

test("Next advances and Previous warns before preparing a possibly sent chunk", function()
    local f = fixture():init()
    assert(f.A.Queue.Start({ "First", "Last" }, CHAT_CHANNEL_SAY))
    equal(f:button("Previous", f.queue).enabled, false)
    f:click("Next", f.queue)
    equal(f.A.Queue.current, 2)
    equal(f:button("Finish", f.queue).enabled, true)
    f.trace = {}
    f:click("Previous", f.queue)
    equal(f.A.Queue.current, 1)
    equal(f:button("Next", f.queue).enabled, true)
    equal(f.trace[1], "notify"); equal(f.trace[2], "prepare")
    assert(f.notices[#f.notices]:find("already sent", 1, true))
    equal(f.sends, 0)
end)

test("Preview never prepares/sends; Start hands off focus without a later UI blur", function()
    local f = fixture():init()
    local session = f:session("Drafts are not messages")
    assert(f.A.Sessions.SetRecording(true)); f.UI.Refresh()
    f.UI.Toggle()
    local text = "One long roleplay draft with several words that needs multiple chunks."
    f.composer:SetText(text)
    f:click("Preview")
    equal(f.previews, 1); equal(f.starts, 0); equal(#f.prepared, 0)
    assert(f.preview:GetText() ~= "")
    f.composer:TakeFocus()
    f.trace = {}
    f:click("Prepare / Start")
    equal(f.starts, 1); equal(#f.prepared, 1)
    equal(f.startArguments[1], text)
    equal(f.startArguments[2], CHAT_CHANNEL_SAY)
    equal(f.focus, "native chat")
    local prepared = false
    for _, event in ipairs(f.trace) do
        if event == "prepare" then prepared = true end
        assert(not (prepared and event == "blur"), "UI blurred an editor after native preparation")
    end
    equal(f.trace[1], "blur", "editor release must precede native focus handoff")
    equal(f.sends, 0); equal(f.violations, 0)
    equal(#session.messages, 0)
    equal(f.composer:GetText(), text)
    f:close()
    assert(f.A.Queue.active, "closing does not cancel")
end)

test("Compose uses an unsorted native combo with plain labels and idempotent initialization", function()
    local f = fixture()
    f.A.Chat.Destinations[2].label = "|Emote|"
    f:init()
    local combo, container = f.destination, f.destination.container
    equal(container.width, 196); equal(container.height, 28)
    equal(container.anchor[4], 34); equal(container.anchor[5], 0)
    local label = f:find(function(item) return item.text == "To:" end)
    equal(label.parent, container.parent); equal(label.anchor[4], 0)
    equal(combo.font, "ZoFontGame"); equal(combo.sortsItems, false)
    equal(combo.enabled, true); equal(combo.selectedText, "Say")
    equal(#combo.items, 14)
    local items = {}
    for index, entry in ipairs(f.A.Chat.Destinations) do
        equal(combo.items[index].name, (entry.label:gsub("|", "")), "source order and plain label")
        items[index] = combo.items[index]
    end
    local controls = #f.controls
    assert(f.UI.Init()); f.UI.Refresh(); f.UI.Refresh()
    equal(#f.controls, controls); equal(#combo.items, #items)
    for index, item in ipairs(items) do equal(combo.items[index], item, "no repopulation") end
    equal(combo.callbackCalls, 0, "initialization and refresh suppress selection callbacks")
    equal(f.currentDestinationCalls, 1, "native destination read only at initialization")
    equal(container.handlers.OnEffectivelyHidden, f.nativeComboHidden, "native close handler retained")
    equal(f.focus, nil); equal(#f.prepared, 0); equal(f.sends, 0); equal(f.violations, 0)
end)

local destinationCases = {
    { "Say", CHAT_CHANNEL_SAY }, { "Emote", CHAT_CHANNEL_EMOTE },
    { "Group", CHAT_CHANNEL_PARTY }, { "Whisper", CHAT_CHANNEL_WHISPER },
}
for i = 1, 5 do
    destinationCases[#destinationCases + 1] = { "GUILD" .. i, _G["CHAT_CHANNEL_GUILD_" .. i] }
    destinationCases[#destinationCases + 1] = { "OFFICER" .. i, _G["CHAT_CHANNEL_OFFICER_" .. i] }
end

for _, case in ipairs(destinationCases) do
    local label, channel = case[1], case[2]
    test("dropdown maps " .. label .. " to Start and new session metadata", function()
        local f = fixture():init()
        f.UI.Toggle()
        f.target:SetText("  @Partner  ")
        f.composer:SetText("Short draft.")
        f.composer:TakeFocus()
        f:selectDestination(label)
        equal(f.destination.selectedText, label)
        equal(f.destination.callbackCalls, 1)
        equal(f.focus, f.composer); equal(#f.prepared, 0); equal(f.starts, 0)
        f:click("Prepare / Start")
        equal(f.startArguments[2], channel)
        equal(f.startArguments[3], "  @Partner  ", "UI passes target to Start boundary")
        local target = channel == CHAT_CHANNEL_WHISPER and "@Partner" or nil
        equal(f.A.Queue.channel, channel); equal(f.A.Queue.target, target)
        equal(#f.prepared, 1)
        equal(f.prepared[1].channel, channel); equal(f.prepared[1].target, target)
        f:click("Sessions")
        f:editor(424, 28):SetText(label .. " scene")
        f:click("Create named session")
        local session = assert(f.A.Sessions.Current())
        equal(session.channel, channel); equal(session.target, target)
        equal(session.name, label .. " scene"); equal(#session.messages, 0)
        assert(not f.A.Sessions.IsRecording())
        equal(#f.prepared, 1, "session creation does not prepare")
        equal(f.target:GetText(), "  @Partner  ")
        equal(f.sends, 0); equal(f.violations, 0)
    end)

    test("dropdown initializes from native " .. label .. " without invoking callbacks", function()
        local f = fixture()
        f.currentChannel = channel
        f.currentTarget = channel == CHAT_CHANNEL_WHISPER and "@Initial" or nil
        f:init()
        equal(f.destination.selectedText, label)
        equal(f.target:GetText(), f.currentTarget or "")
        equal(f.destination.callbackCalls, 0)
        equal(f.focus, nil); equal(#f.prepared, 0)
        f.UI.Toggle(); f.composer:SetText("Initial draft."); f:click("Prepare / Start")
        equal(f.A.Queue.channel, channel); equal(f.A.Queue.target, f.currentTarget)
        equal(f.sends, 0); equal(f.violations, 0)
    end)
end

test("unknown native channel falls back to the first destination", function()
    local f = fixture()
    f.currentChannel, f.currentTarget = -999, "@Retained"
    f:init()
    equal(f.destination.selectedItem, f.destination.items[1])
    equal(f.destination.selectedText, "Say"); equal(f.destination.enabled, true)
    equal(f.target:GetText(), "@Retained"); equal(f.destination.callbackCalls, 0)
    f.UI.Toggle(); f.composer:SetText("Fallback."); f:click("Prepare / Start")
    equal(f.A.Queue.channel, CHAT_CHANNEL_SAY); equal(f.A.Queue.target, nil)
    equal(f.sends, 0); equal(f.violations, 0)
end)

test("empty destination list disables the native combo without selecting an item", function()
    local f = fixture()
    f.A.Chat.Destinations = {}
    f:init()
    local combo = f.destination
    equal(#combo.items, 0); equal(combo.enabled, false)
    equal(combo.selectedText, "unavailable"); equal(combo.selectedItem, nil)
    equal(combo.callbackCalls, 0)
    f.UI.Refresh(); f.UI.Toggle(); f:close(); f.UI.Toggle()
    equal(combo.enabled, false); equal(combo.selectedText, "unavailable")
    f.composer:SetText("No destination."); f:click("Prepare / Start")
    equal(f.startArguments[2], nil)
    assert(not f.A.Queue.active)
    equal(#f.prepared, 0); equal(f.sends, 0); equal(f.violations, 0)
end)

test("refresh, tab changes and window hide-show retain the selected destination", function()
    local f = fixture():init()
    f.UI.Toggle(); f:selectDestination("OFFICER3")
    local item, combo = f.destination.selectedItem, f.destination
    f.currentChannel, f.currentTarget = CHAT_CHANNEL_WHISPER, "@ChangedNative"
    f.target:SetText("@LocalDraft")
    f.UI.Refresh(); f.UI.Refresh()
    f:click("Sessions"); assert(combo.container:IsHidden())
    f:click("Compose"); assert(not combo.container:IsHidden())
    f:close(); assert(combo.container:IsHidden())
    f.UI.Refresh(); f.UI.Toggle()
    equal(combo.selectedItem, item); equal(combo.selectedText, "OFFICER3")
    equal(combo.callbackCalls, 1, "refresh does not invoke callbacks")
    equal(combo.container.handlers.OnEffectivelyHidden, f.nativeComboHidden)
    equal(f.currentDestinationCalls, 1); equal(f.target:GetText(), "@LocalDraft")
    equal(f.focus, nil); equal(#f.prepared, 0)
    f.composer:SetText("Retained."); f:click("Prepare / Start")
    equal(f.A.Queue.channel, CHAT_CHANNEL_OFFICER_3)
    equal(f.sends, 0); equal(f.violations, 0)
end)

test("choosing destinations leaves the active whisper queue, focus, target and drafts untouched", function()
    local f = fixture():init()
    local session = f:session("Selection is local", "@Saved")
    f.UI.Toggle()
    assert(f.A.Queue.Start({ "First", "Last" }, CHAT_CHANNEL_WHISPER, "@QueueTarget"))
    f.composer:SetText("Unsent Compose draft."); f:click("Preview")
    f.target:SetText("@DraftTarget"); f.participants:SetText("@Unsaved")
    f.history:SetText("Review draft"); f:editor(90, 28):SetText("42")
    f:editor(424, 28):SetText("Unsaved session name")
    local Q, state, drafts = f.A.Queue, {}, {}
    for key, value in pairs(Q) do state[key] = value end
    for _, control in ipairs(f.controls) do
        drafts[control] = { text = control:GetText(), writes = control.setTextCalls }
    end
    local prepared, previews, trace, notices = #f.prepared, f.previews, #f.trace, #f.notices
    for _, focus in ipairs({ f.composer, "native chat" }) do
        f.focus = focus
        for _, case in ipairs(destinationCases) do
            f:selectDestination(case[1])
            equal(f.focus, focus)
            for key, value in pairs(state) do equal(Q[key], value, "queue field " .. key) end
            for key, value in pairs(Q) do equal(value, state[key], "no new queue field " .. key) end
            for control, draft in pairs(drafts) do
                equal(control:GetText(), draft.text, "draft text")
                equal(control.setTextCalls, draft.writes, "no draft rewriting")
            end
        end
    end
    equal(Q.chunks[1], "First"); equal(Q.chunks[2], "Last")
    equal(Q.staged.text, "First"); equal(Q.staged.index, 1)
    equal(Q.staged.generation, state.generation)
    equal(f.A.Sessions.Current(), session); equal(session.participants[1], "@Saved")
    equal(#f.prepared, prepared); equal(f.previews, previews); equal(f.starts, 0)
    equal(#f.trace, trace); equal(#f.notices, notices); equal(#f.timers, 0)
    equal(f.currentDestinationCalls, 1); equal(f.ownershipCleared, nil)
    equal(f.sends, 0); equal(f.violations, 0)
    f:click("Next", f.queue)
    equal(f.prepared[#f.prepared].channel, CHAT_CHANNEL_WHISPER)
    equal(f.prepared[#f.prepared].target, "@QueueTarget", "next chunk retains original route")
end)

test("Whisper requires a target at Start while a non-whisper ignores the retained target", function()
    local f = fixture():init()
    f.UI.Toggle(); f.composer:SetText("Target validation."); f:selectDestination("Whisper")
    for _, target in ipairs({ "", "   " }) do
        f.target:SetText(target); f:click("Prepare / Start")
        assert(not f.A.Queue.active)
        equal(f.notices[#f.notices], "Target required."); equal(#f.prepared, 0)
        equal(f.destination.selectedText, "Whisper")
    end
    f.target:SetText("  @Partner  "); f:click("Prepare / Start")
    equal(f.A.Queue.target, "@Partner"); equal(f.prepared[1].target, "@Partner")
    f:click("Cancel", f.queue)
    f:selectDestination("Group")
    equal(f.target:GetText(), "  @Partner  ")
    f:click("Prepare / Start")
    equal(f.A.Queue.channel, CHAT_CHANNEL_PARTY); equal(f.A.Queue.target, nil)
    equal(f.prepared[2].target, nil)
    equal(f.target:GetText(), "  @Partner  "); equal(f.composer:GetText(), "Target validation.")
    equal(f.sends, 0); equal(f.violations, 0)
end)

test("session creation retains initial Compose metadata but does not start recording", function()
    local f = fixture():init()
    f.UI.Toggle()
    f:selectDestination("Whisper")
    f:editor(370, 28):SetText("@Partner")
    f:click("Sessions")
    f:editor(424, 28):SetText("Whisper scene")
    f:click("Create named session")
    local session = assert(f.A.Sessions.Current())
    equal(session.name, "Whisper scene")
    equal(session.channel, CHAT_CHANNEL_WHISPER)
    equal(session.target, "@Partner")
    assert(not f.A.Sessions.IsRecording())
end)

test("deletion requires two clicks and resets confirmation on tab change or close", function()
    local f = fixture():init()
    local session = f:session("Keep until confirmed")
    f.UI.Toggle(); f:click("Sessions"); f:click("Delete session")
    assert(f.A.Sessions.Get(session.id))
    f:click("Compose"); f:click("Sessions"); f:click("Delete session")
    assert(f.A.Sessions.Get(session.id))
    f:close(); f.UI.Toggle(); f:click("Delete session")
    assert(f.A.Sessions.Get(session.id))
    f:click("Confirm delete")
    equal(f.A.Sessions.Get(session.id), nil)
    equal(f.A.Sessions.Current(), nil)
end)

local function historyPage(f, oldest, newest, page, pages, newestFirst)
    local actual = {}
    for number in f.history:GetText():gmatch("Line (%d+)") do
        actual[#actual + 1] = tonumber(number)
    end
    equal(#actual, newest - oldest + 1, "visible message count")
    local _, separators = f.history:GetText():gsub("\n", "")
    equal(separators, math.max(0, #actual - 1), "single newline between messages, no blank lines")
    for i, number in ipairs(actual) do
        equal(number, newestFirst and (newest - i + 1) or (oldest + i - 1), "display insertion order")
    end
    if #actual > 0 then assert(f.history:GetText():find("Local Hero", 1, true), "persisted sender") end
    local title = "History " .. page .. "/" .. pages .. " - "
    f:find(function(item) return item.text and item.text:sub(1, #title) == title end)
    equal(f:button("<", f.history.parent.parent).enabled, page > 1)
    equal(f:button(">", f.history.parent.parent).enabled, page < pages)
end

local function snapshot(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, field in pairs(value) do copy[key] = snapshot(field) end
    return copy
end

local function unchanged(actual, expected)
    if type(expected) ~= "table" then
        if type(expected) == "number" and expected ~= expected then
            assert(type(actual) == "number" and actual ~= actual, "saved NaN unchanged")
        else
            equal(actual, expected, "saved field unchanged")
        end
        return
    end
    equal(type(actual), "table")
    for key, field in pairs(expected) do unchanged(actual[key], field) end
    for key in pairs(actual) do assert(expected[key] ~= nil, "no added saved fields") end
end

test("history order toggle fits beside the unchanged arrows and works without messages or selection", function()
    local f = fixture():init()
    f.UI.Toggle(); f:click("Sessions")
    local toggle = f:button("Oldest first")
    equal(toggle.enabled, true)
    equal(toggle.anchor[4], 424); equal(toggle.anchor[5], 354); equal(toggle.width, 192)
    local title = f:find(function(item) return item.text and item.text:find("History 1/1 - ", 1, true) == 1 end)
    equal(title.width, 412); equal(title.font, "ZoFontGameSmall")
    for _, arrow in ipairs({ { "<", 628 }, { ">", 690 } }) do
        local control = f:button(arrow[1], f.history.parent.parent)
        equal(control.anchor[4], arrow[2]); equal(control.anchor[5], 354); equal(control.width, 50)
    end
    local refresh, calls = f.UI.Refresh, 0
    f.UI.Refresh = function() calls = calls + 1; return refresh() end
    for _, selected in ipairs({ false, true }) do
        if selected then f:session("Empty") end
        local saved = snapshot(f.A.saved)
        for _, label in ipairs({ "Oldest first", "Newest first" }) do
            local before = calls
            f.history:SetTopLineIndex(9)
            f:click(label)
            assert(calls > before, "order callback refreshes the UI")
            local newestFirst = label == "Oldest first"
            equal(f.A.saved.historyNewestFirst, newestFirst, "click writes a strict boolean")
            equal(toggle:GetText(), newestFirst and "Newest first" or "Oldest first")
            equal(toggle.enabled, true)
            historyPage(f, 1, 0, 1, 1)
            equal(f.history:GetText(), ""); equal(f.history.topLine, 1)
            equal(f.history.extentCalls, nil, "empty order changes never query scroll extents")
            saved.historyNewestFirst = newestFirst
            unchanged(f.A.saved, saved)
        end
    end
end)

for _, case in ipairs({ {}, { value = false }, { value = "true" }, { value = "false" },
    { value = 0 }, { value = 1 }, { value = {} } }) do
    test("legacy history preference renders as oldest first without migration: " .. tostring(case.value), function()
        local f = fixture(nil, { historyNewestFirst = case.value })
        local session = f:session("Legacy preference")
        assert(f.A.Sessions.SetRecording(true)); f:capture(1, 11)
        local saved = snapshot(f.A.saved)
        f:init(); f.UI.Toggle(); f:click("Sessions")
        historyPage(f, 11, 11, 2, 2)
        equal(f.A.saved.historyNewestFirst, case.value)
        f:button("Oldest first")
        unchanged(f.A.saved, saved)
        f:click("Oldest first")
        equal(f.A.saved.historyNewestFirst, true)
        historyPage(f, 2, 11, 1, 2, true)
        equal(f.history.topLine, 1)
        f.history.scrollExtent = 17
        f:click("Newest first")
        equal(f.A.saved.historyNewestFirst, false)
        historyPage(f, 11, 11, 2, 2)
        equal(f.history.topLine, 18)
        unchanged(session, saved.sessions[1])
    end)
end

for _, newestFirst in ipairs({ false, true }) do
    for _, count in ipairs({ 0, 1, 10, 11, 21 }) do
        test("history boundaries and both order toggles: newest=" .. tostring(newestFirst) .. ", count=" .. count, function()
            local f = fixture(nil, { historyNewestFirst = newestFirst })
            local session = f:session("Order boundaries")
            assert(f.A.Sessions.SetRecording(true)); f:capture(1, count)
            local saved, records, messages = snapshot(session), {}, session.messages
            for i, record in ipairs(messages) do
                records[i] = record
                equal(record.timestamp, 1700000000)
            end
            f:init(); f.UI.Toggle(); f:click("Sessions")
            local pages = math.max(1, math.ceil(count / 10))
            local function page(mode, index)
                if count == 0 then historyPage(f, 1, 0, index, pages); return end
                local first = mode and math.max(1, count - index * 10 + 1) or ((index - 1) * 10 + 1)
                local last = mode and (count - (index - 1) * 10) or math.min(count, index * 10)
                historyPage(f, first, last, index, pages, mode)
            end
            page(newestFirst, newestFirst and 1 or pages)
            equal(f.history.topLine, newestFirst and 1 or (math.max(0, count - (pages - 1) * 10 - 4) + 1))
            if newestFirst or count == 0 then equal(f.history.extentCalls, nil) end
            for _, mode in ipairs({ newestFirst, not newestFirst, newestFirst }) do
                if f.A.saved.historyNewestFirst ~= mode then
                    f.history.scrollExtent = 23
                    local extents = f.history.extentCalls or 0
                    f:click(mode and "Oldest first" or "Newest first")
                    equal(f.A.saved.historyNewestFirst, mode)
                    page(mode, mode and 1 or pages)
                    equal(f.history.topLine, (not mode and count > 0) and 24 or 1)
                    equal(f.history.extentCalls or 0, extents + ((not mode and count > 0) and 1 or 0))
                end
                local extents = f.history.extentCalls
                if mode then
                    for index = 2, pages do
                        f.history:SetTopLineIndex(8); f:click(">", f.history.parent.parent)
                        page(mode, index); equal(f.history.topLine, 1)
                    end
                end
                for index = pages - 1, 1, -1 do
                    f.history:SetTopLineIndex(8); f:click("<", f.history.parent.parent)
                    page(mode, index); equal(f.history.topLine, 1)
                end
                for index = 2, pages do
                    f.history:SetTopLineIndex(8); f:click(">", f.history.parent.parent)
                    page(mode, index); equal(f.history.topLine, 1)
                end
                equal(f.history.extentCalls, extents, "manual navigation never measures the bottom")
                unchanged(session, saved)
                equal(session.messages, messages)
                for i, record in ipairs(records) do equal(messages[i], record, "archive identity/order") end
            end
        end)
    end
end

for _, newestFirst in ipairs({ false, true }) do
    test("global history order applies across populated session switches and reload: " .. tostring(newestFirst), function()
        local f = fixture(nil, { historyNewestFirst = not newestFirst }):init()
        local first = f:session("First order")
        assert(f.A.Sessions.SetRecording(true)); f:capture(1, 21)
        local second = f:session("Second order")
        assert(f.A.Sessions.SetRecording(true)); f:capture(101, 121)
        f.UI.Refresh(); f.UI.Toggle(); f:click("Sessions")
        f:click(newestFirst and "Oldest first" or "Newest first")
        local saved = snapshot(f.A.saved)
        f.history.scrollExtent = 14
        for _, entry in ipairs({ { "Previous", first, 0 }, { "Next", second, 100 } }) do
            f.history:SetText("Temporary review"); f.history:SetTopLineIndex(6)
            f:click(entry[1], f.participants.parent.parent)
            equal(f.A.Sessions.Current(), entry[2])
            historyPage(f, entry[3] + (newestFirst and 12 or 21), entry[3] + 21,
                newestFirst and 1 or 3, 3, newestFirst)
            equal(f.history.topLine, newestFirst and 1 or 15)
            equal(f.A.saved.historyNewestFirst, newestFirst)
        end
        unchanged(f.A.saved, saved)
        local reloaded = fixture(nil, f.A.saved)
        assert(reloaded.A.Sessions.Select(first.id))
        reloaded:init()
        historyPage(reloaded, newestFirst and 12 or 21, 21, newestFirst and 1 or 3, 3, newestFirst)
        reloaded:button(newestFirst and "Newest first" or "Oldest first")
        unchanged(reloaded.A.saved, saved)
    end)
end

for _, visibility in ipairs({ "Sessions", "Compose", "hidden window" }) do
    test("newest-first arrivals follow page one at top while on " .. visibility, function()
        local f = fixture(nil, { historyNewestFirst = true }):init()
        f:session("Reverse arrivals")
        assert(f.A.Sessions.SetRecording(true)); f:capture(1, 10)
        f.UI.Refresh(); f.UI.Toggle(); f:click("Sessions")
        for _, count in ipairs({ 11, 20, 21, 22 }) do
            if count > 11 then f:click(">", f.history.parent.parent) end
            f.history:SetText("Older review"); f.history:SetTopLineIndex(7)
            if visibility == "hidden window" then f:close()
            elseif visibility == "Compose" then f:click("Compose") end
            f.focus = "native chat"
            f.history.scrollExtent = 47
            local before = #f.A.Sessions.Current().messages
            f:capture(before + 1, count)
            f.UI.Refresh()
            historyPage(f, count - 9, count, 1, math.ceil(count / 10), true)
            equal(f.history.topLine, 1); equal(f.history.extentCalls, nil)
            equal(f.focus, "native chat")
            equal(f.history:IsHidden(), visibility ~= "Sessions")
            local writes, scrolls = f.history.setTextCalls, f.history.topLineCalls
            if visibility == "hidden window" then f.UI.Toggle()
            elseif visibility == "Compose" then f:click("Sessions") end
            f.UI.Refresh()
            equal(f.history.setTextCalls, writes); equal(f.history.topLineCalls, scrolls)
        end
    end)
end

for _, newestFirst in ipairs({ false, true }) do
    for _, pending in ipairs({ false, true }) do
        test("order changes preserve queue, drafts, recording and archive; newest=" .. tostring(newestFirst) .. ", pending=" .. tostring(pending), function()
            local f = fixture(nil, { historyNewestFirst = newestFirst }):init()
            local session = f:session("Unrelated state", "@Saved")
            f.UI.Toggle()
            f.composer:SetText("An unsent compose draft."); f:click("Preview"); f:click("Prepare / Start")
            local Q, S = f.A.Queue, f.A.Sessions
            if pending then Q.ObserveSubmission(Q.chunks[1], Q.channel, Q.target) end
            assert(S.SetRecording(true)); f:capture(1, 21)
            f.UI.Refresh(); f:click("Sessions")
            f:click(newestFirst and ">" or "<", f.history.parent.parent)
            f.participants:SetText("@Unsaved"); f.target:SetText("@DraftTarget")
            f:editor(90, 28):SetText("42"); f:editor(424, 28):SetText("Unsaved name")
            local drafts = {}
            for _, control in ipairs({ f.composer, f.preview, f.participants, f.target,
                f:editor(90, 28), f:editor(424, 28) }) do
                drafts[control] = { text = control:GetText(), writes = control.setTextCalls }
            end
            local queue, saved = snapshot(Q), snapshot(f.A.saved)
            local prepared, timers, starts, previews = #f.prepared, #f.timers, f.starts, f.previews
            f.history:SetText("Copy/edit only"); f.history:SetTopLineIndex(8); f.history:TakeFocus()
            local writes, scrolls, extents = f.history.setTextCalls, f.history.topLineCalls, f.history.extentCalls
            f.UI.Notify("Unrelated queue notice")
            f.UI.Refresh(); f.UI.Refresh()
            equal(f.history:GetText(), "Copy/edit only"); equal(f.history.topLine, 8)
            equal(f.history.setTextCalls, writes); equal(f.history.topLineCalls, scrolls)
            equal(f.history.extentCalls, extents)
            f:find(function(item) return item.text and item.text:find("History 2/3 - ", 1, true) == 1 end)
            for _, mode in ipairs({ not newestFirst, newestFirst }) do
                f:click(mode and "Oldest first" or "Newest first")
                saved.historyNewestFirst = mode
                unchanged(f.A.saved, saved); unchanged(Q, queue)
                equal(S.Current(), session); equal(S.IsRecording(), true)
                equal(f.recording:IsHidden(), false); equal(f.focus, f.history)
                for control, draft in pairs(drafts) do
                    equal(control:GetText(), draft.text); equal(control.setTextCalls, draft.writes)
                end
                equal(#f.prepared, prepared); equal(#f.timers, timers)
                equal(f.starts, starts); equal(f.previews, previews)
            end
            equal(f.sends, 0); equal(f.violations, 0)
        end)
    end
end

test("effective order changes are detected independently of arrival and equivalent false values are no-ops", function()
    local f = fixture(nil, { historyNewestFirst = true }):init()
    local session = f:session("Effective order")
    assert(f.A.Sessions.SetRecording(true)); f:capture(1, 21)
    f.UI.Refresh(); f.UI.Toggle(); f:click("Sessions")
    local saved = snapshot(session)
    f:click(">", f.history.parent.parent)
    f.A.saved.historyNewestFirst = "true"
    f.history.scrollExtent = 19
    f.UI.Refresh()
    historyPage(f, 21, 21, 3, 3)
    equal(f.history.topLine, 20); f:button("Oldest first")
    f:click("<", f.history.parent.parent)
    f.history:SetText("Do not rebuild"); f.history:SetTopLineIndex(8)
    local writes, scrolls, extents = f.history.setTextCalls, f.history.topLineCalls, f.history.extentCalls
    for _, case in ipairs({ {}, { value = false }, { value = 0 }, { value = "yes" }, { value = {} } }) do
        f.A.saved.historyNewestFirst = case.value
        f.UI.Refresh()
        equal(f.A.saved.historyNewestFirst, case.value, "render never migrates saved preference")
        equal(f.history:GetText(), "Do not rebuild"); equal(f.history.topLine, 8)
        equal(f.history.setTextCalls, writes); equal(f.history.topLineCalls, scrolls)
        equal(f.history.extentCalls, extents)
    end
    f.A.saved.historyNewestFirst = true
    f.UI.Refresh()
    historyPage(f, 12, 21, 1, 3, true)
    equal(f.history.topLine, 1); equal(f.history.extentCalls, extents)
    unchanged(session, saved)
end)

test("newest-first retention arrivals follow new record identity at equal timestamps without reordering archives", function()
    local f = fixture(nil, { historyNewestFirst = true }):init()
    local session = f:session("Reverse retention")
    assert(f.A.Sessions.SetRecording(true)); f:capture(1, 2000)
    f.UI.Refresh(); f.UI.Toggle(); f:click("Sessions")
    historyPage(f, 1991, 2000, 1, 200, true)
    local previousNewest = session.messages[2000]
    for number = 2001, 2002 do
        f:click(">", f.history.parent.parent)
        historyPage(f, number - 20, number - 11, 2, 200, true)
        f.history:SetText("Older review"); f.history:SetTopLineIndex(6)
        f:capture(number, number)
        equal(#session.messages, 2000); equal(session.dropped, number - 2000)
        equal(session.messages[1999], previousNewest)
        equal(session.messages[2000].timestamp, previousNewest.timestamp)
        assert(session.messages[2000] ~= previousNewest)
        local saved, records, messages = snapshot(session), {}, session.messages
        for i, record in ipairs(messages) do records[i] = record end
        f.UI.Refresh()
        historyPage(f, number - 9, number, 1, 200, true)
        equal(f.history.topLine, 1); equal(f.history.extentCalls, nil)
        unchanged(session, saved); equal(session.messages, messages)
        for i, record in ipairs(records) do equal(messages[i], record, "retained archive identity/order") end
        previousNewest = messages[2000]
    end
end)

test("shared bottom footer uses the app version on both tabs and survives status refresh", function()
    for _, version in ipairs({ "1.2.2", "1.2.2-test" }) do
        local f = fixture()
        f.A.version = version
        f:init(); f.UI.Toggle()
        local footer = f:find(function(item) return item.text == "Version " .. version end)
        equal(footer.parent, f.main, "footer is shared, not a tab child")
        equal(footer.font, "ZoFontGameSmall")
        equal(footer.horizontalAlignment, TEXT_ALIGN_RIGHT)
        equal(footer.anchor[4] + footer.width, f.main.width - 20, "footer right margin")
        equal(footer.anchor[5], 642); equal(footer.height, 16)
        equal(footer.anchor[5] + footer.height, f.main.height - 20, "footer bottom margin")
        local status = f:find(function(item)
            return item.parent == f.main and item.anchor and item.anchor[5] == 610
        end)
        equal(status.height, 28)
        assert(status.anchor[5] + status.height <= footer.anchor[5])
        for _, tab in ipairs({ "Sessions", "Compose" }) do
            assert(not footer:IsHidden())
            f:click(tab)
            f.UI.Notify("Status changed on " .. tab)
            f.UI.Refresh(); f.UI.Refresh()
            equal(status:GetText(), "Status changed on " .. tab)
            equal(footer:GetText(), "Version " .. version)
            equal(footer.horizontalAlignment, TEXT_ALIGN_RIGHT)
            assert(not footer:IsHidden())
        end
    end
end)

test("addon-only toggle is disabled without selection and displays each session's strict boolean flag", function()
    local f = fixture():init()
    f.UI.Toggle(); f:click("Sessions")
    local toggle = f:button("Record addon-marked only: OFF")
    equal(toggle.enabled, false)
    local S, calls = f.A.Sessions, {}
    local setAddonOnly = S.SetAddonOnly
    ---@diagnostic disable-next-line: duplicate-set-field -- Spy on the real setter for this fixture.
    S.SetAddonOnly = function(enabled)
        equal(type(enabled), "boolean")
        calls[#calls + 1] = enabled
        return setAddonOnly(enabled)
    end
    toggle.handlers.OnClicked(toggle)
    equal(#calls, 0, "no selection is also guarded by the callback")
    local first = f:session("First")
    equal(toggle.enabled, true); equal(toggle:GetText(), "Record addon-marked only: OFF")
    f:click("Record addon-marked only: OFF")
    equal(first.addonOnly, true); equal(calls[1], true)
    equal(toggle:GetText(), "Record addon-marked only: ON")
    local second = f:session("Second")
    equal(toggle:GetText(), "Record addon-marked only: OFF")
    f:click("Previous", f.participants.parent.parent)
    equal(S.Current(), first); equal(toggle:GetText(), "Record addon-marked only: ON")
    f:click("Record addon-marked only: ON")
    equal(first.addonOnly, false); equal(calls[2], false)
    equal(second.addonOnly, false, "toggle does not change another session")
    for _, legacy in ipairs({ {}, { value = "true" }, { value = 1 } }) do
        second.addonOnly = legacy.value
        assert(S.Select(second.id)); f.UI.Refresh()
        equal(toggle:GetText(), "Record addon-marked only: OFF")
        equal(second.addonOnly, legacy.value, "display does not migrate saved fields")
        f:click("Record addon-marked only: OFF")
        equal(second.addonOnly, true)
    end
    f:click("Delete session"); f:click("Confirm delete")
    equal(toggle.enabled, false); equal(toggle:GetText(), "Record addon-marked only: OFF")
    equal(S.IsRecording(), false)
end)

for _, pending in ipairs({ false, true }) do
    test("live addon-only switching affects future capture only and preserves drafts/queue; pending=" .. tostring(pending), function()
        local f = fixture():init()
        local session = f:session("Live filter", "@Saved")
        local S, Q, tag = f.A.Sessions, f.A.Queue, f.A.Splitter.MESSAGE_TAG
        f.UI.Toggle()
        f.composer:SetText("An unsent draft.")
        f:click("Preview"); f:click("Prepare / Start")
        if pending then Q.ObserveSubmission(Q.chunks[1], Q.channel, Q.target) end
        f:click("Sessions"); f:click("Recording: OFF - Start")
        f.participants:SetText("@Unsaved")
        local before = assert(S.Capture(CHAT_CHANNEL_SAY, "Local Hero", "Before switch", false, "@Local"))
        local beforeSaved = snapshot(before)
        f.UI.Refresh()
        f.history:SetText("Temporary review edits"); f.history:SetTopLineIndex(7)
        local queue, prepared, timers, preview = snapshot(Q), #f.prepared, #f.timers, f.preview:GetText()
        local function preserved()
            assert(S.IsRecording() and not f.recording:IsHidden())
            equal(f.composer:GetText(), "An unsent draft.")
            equal(f.participants:GetText(), "@Unsaved")
            equal(session.participants[1], "@Saved")
            equal(f.preview:GetText(), preview)
            unchanged(Q, queue)
            equal(#f.prepared, prepared); equal(#f.timers, timers)
            equal(session.messages[1], before); unchanged(before, beforeSaved)
        end
        f:click("Record addon-marked only: OFF")
        preserved()
        equal(f.history:GetText(), "Temporary review edits"); equal(f.history.topLine, 7)
        equal(#session.messages, 1, "switch does not rewrite or prune earlier ordinary messages")
        f:find(function(item)
            return item.text and item.text:find("exact addon marker required", 1, true)
        end)
        f:find(function(item) return item.text == "When ON: participants need RPS 1.2.0+." end)
        local warning = f:find(function(item)
            return item.text and item.text:find("Drafts never recorded.", 1, true)
        end)
        equal(warning.anchor[5], 314); equal(warning.height, 40)
        for _, sender in ipairs({ { "Local Hero", "@Local" }, { "Saved Hero", "@Saved" } }) do
            for _, text in ipairs({ "Ordinary", tag:sub(1, -4) .. "Partial tag", "Not leading " .. tag }) do
                equal(S.Capture(CHAT_CHANNEL_SAY, sender[1], text, false, sender[2]), nil)
            end
            local record = assert(S.Capture(CHAT_CHANNEL_PARTY, sender[1], tag .. "Marked", false, sender[2]))
            equal(record.text, "Marked"); equal(record.addonMarked, true)
        end
        equal(S.Capture(CHAT_CHANNEL_SAY, "Other Hero", tag .. "Outsider", false, "@Other"), nil)
        equal(S.Capture(CHAT_CHANNEL_SAY, "Unsaved Hero", tag .. "Unsaved", false, "@Unsaved"), nil)
        equal(S.Capture(CHAT_CHANNEL_WHISPER_SENT, "Other Hero", "Ordinary whisper", false, "@Other"), nil)
        local whisper = assert(S.Capture(CHAT_CHANNEL_WHISPER_SENT, "Other Hero", tag .. "Marked whisper", false, "@Other"))
        equal(whisper.text, "Marked whisper"); equal(whisper.addonMarked, true)
        local archive = snapshot(session.messages)
        f:click("Record addon-marked only: ON")
        preserved(); unchanged(session.messages, archive)
        assert(warning:GetText():find("marked and ordinary chat", 1, true))
        assert(warning:GetText():find("outgoing whispers to anyone", 1, true))
        assert(not warning:GetText():find("exact addon marker required", 1, true))
        assert(S.Capture(CHAT_CHANNEL_SAY, "Local Hero", "Ordinary own", false, "@Local"))
        assert(S.Capture(CHAT_CHANNEL_EMOTE, "Saved Hero", "Ordinary participant", false, "@Saved"))
        local outgoing = assert(S.Capture(CHAT_CHANNEL_WHISPER_SENT, "Other Hero", "Ordinary whisper", false, "@Other"))
        equal(outgoing.addonMarked, false); equal(outgoing.target, "@Other")
        local marked = assert(S.Capture(CHAT_CHANNEL_SAY, "Saved Hero", tag .. "Still marked", false, "@Saved"))
        equal(marked.text, "Still marked"); equal(marked.addonMarked, true)
        equal(S.Capture(CHAT_CHANNEL_SAY, "Other Hero", tag .. "Still excluded", false, "@Other"), nil)
        f.UI.Refresh()
        assert(not f.history:GetText():find(tag, 1, true), "history shows stripped text")
        preserved()
    end)
end

for _, addonOnly in ipairs({ false, true }) do
    test("app preview reserves the effective tag budget and all prepared chunks are marked; addonOnly=" .. tostring(addonOnly), function()
        local f = fixture():init()
        f:session("Prepared chunks")
        assert(f.A.Sessions.SetAddonOnly(addonOnly))
        local S, Q = f.A.Splitter, f.A.Queue
        equal(S.MESSAGE_TAG, string.rep("\226\128\139", 4))
        equal(S.MESSAGE_TAG_LENGTH, 4)
        f.UI.Toggle()
        for _, limits in ipairs({ { saved = 28, runtime = 350 }, { saved = 100, runtime = 28 } }) do
            f.A.saved.maxChars = limits.saved
            f.A.Chat.GetLimit = function() return limits.runtime end
            f.composer:SetText(string.rep("word ", 30))
            f:click("Preview")
            local readable = assert(f.A.Preview(f.composer:GetText()))
            assert(#readable > 1)
            equal(f.preview:GetText(), readable[1])
            f:click("Prepare / Start")
            equal(#Q.chunks, #readable)
            for index, chunk in ipairs(readable) do
                assert(not chunk:find(S.MESSAGE_TAG, 1, true))
                assert(S.Length(chunk) <= math.min(limits.saved, limits.runtime) - S.MESSAGE_TAG_LENGTH)
                equal(Q.chunks[index], S.MESSAGE_TAG .. chunk)
                assert(S.Length(Q.chunks[index]) <= math.min(limits.saved, limits.runtime))
                equal(f.prepared[#f.prepared].text, Q.chunks[index])
                if index < #readable then f:click("Next", f.queue) end
            end
            f:click("Cancel", f.queue)
        end
        equal(f.A.Sessions.Current().addonOnly, addonOnly)
        equal(f.sends, 0)
    end)
end

local function withNameFormatter(formatter, callback)
    local original = zo_strformat
    zo_strformat = formatter
    local ok, err = xpcall(callback, debug.traceback)
    zo_strformat = original
    if not ok then error(err, 0) end
end

test("history formats character names only and preserves raw records and continued capture", function()
    local f = fixture():init()
    local session = f:session("Names", "@Partner")
    assert(f.A.Sessions.SetRecording(true))
    assert(f.A.Sessions.Capture(CHAT_CHANNEL_SAY, "Leiadriel Milandris^Fx", "Literal ^Fx stays.", false, "@Local"))
    assert(f.A.Sessions.Capture(CHAT_CHANNEL_EMOTE, "A Nugget of Moon Sugar^Mx", "Reply", false, "@Partner"))
    assert(f.A.Sessions.Capture(CHAT_CHANNEL_PARTY, "@aausten", "Account", false, "@Local"))
    session.messages[#session.messages + 1] = { displayName = "@Fallback", text = "Legacy" }
    local saved, calls = snapshot(session), {}
    withNameFormatter(function(template, name)
        equal(template, "<<1>>")
        calls[#calls + 1] = name
        if name == "Leiadriel Milandris^Fx" then return "Leiadriel Milandris" end
        if name == "A Nugget of Moon Sugar^Mx" then return "A Nugget of Moon Sugar" end
        error("Unexpected formatter input: " .. name)
    end, function()
        f.UI.Refresh()
    end)
    local text = f.history:GetText()
    assert(text:find("(you) Leiadriel Milandris: Literal ^Fx stays.", 1, true))
    assert(text:find("A Nugget of Moon Sugar: Reply", 1, true))
    assert(text:find("(you) @aausten: Account", 1, true))
    assert(text:find("@Fallback: Legacy", 1, true))
    equal(#calls, 2, "only character names formatted")
    unchanged(session, saved)
    assert(f.A.Sessions.IsRecording())
    assert(f.A.Sessions.Capture(CHAT_CHANNEL_SAY, "Local Hero", "Still recording", false, "@Local"))
    equal(#session.messages, 5)
end)

for _, mode in ipairs({ "missing", "throwing" }) do
    test(mode .. " name formatter cannot interrupt history display", function()
        local f = fixture():init()
        local session = f:session("Name fallback")
        assert(f.A.Sessions.SetRecording(true))
        assert(f.A.Sessions.Capture(CHAT_CHANNEL_SAY, "Local Hero^Mx", "Recorded", false, "@Local"))
        local saved = snapshot(session)
        local formatter
        if mode == "throwing" then formatter = function() error("formatter unavailable") end end
        withNameFormatter(formatter, function() f.UI.Refresh() end)
        assert(f.history:GetText():find("Local Hero^Mx: Recorded", 1, true))
        unchanged(session, saved)
        assert(f.A.Sessions.IsRecording())
    end)
end

local function withDate(date, callback)
    local original = os.date
    os.date = date
    local ok, err = xpcall(callback, debug.traceback)
    os.date = original
    if not ok then error(err, 0) end
end

test("empty history and a single short message use page one and zero-extent scrolling", function()
    local f = fixture():init()
    historyPage(f, 1, 0, 1, 1)
    equal(f.history:GetText(), ""); equal(f.history.topLine, 1)
    equal(f.history.extentCalls, nil, "no arrival to measure without a session")
    local session = f:session("Empty")
    historyPage(f, 1, 0, 1, 1)
    equal(f.history:GetText(), ""); equal(f.history.topLine, 1)
    equal(f.history.extentCalls, nil, "empty session has no new last record")
    assert(f.A.Sessions.SetRecording(true))
    f:capture(1, 1); f.UI.Refresh()
    historyPage(f, 1, 1, 1, 1)
    equal(f.history.extentCalls, 1)
    equal(f.history.topLine, 1, "zero native extent plus one")
    local saved = snapshot(session)
    f.history:SetText("Review one message"); f.history:SetTopLineIndex(3)
    f.UI.Refresh()
    equal(f.history:GetText(), "Review one message"); equal(f.history.topLine, 3)
    equal(f.history.extentCalls, 1, "same last record is not another arrival")
    unchanged(session, saved)
end)

test("initial loading and switching populated sessions select each final page without taking focus", function()
    local f = fixture()
    local first = f:session("Loaded first")
    assert(f.A.Sessions.SetRecording(true)); f:capture(1, 21)
    local savedFirst = snapshot(first)
    f:init()
    historyPage(f, 21, 21, 3, 3)
    equal(f.history.topLine, 1); equal(f.history.extentCalls, 1)
    equal(f.focus, nil, "initial loading does not take focus")
    f.UI.Toggle(); f:click("Sessions")
    f:click("<", f.history.parent.parent)
    historyPage(f, 11, 20, 2, 3)
    local second = f:session("Loaded second")
    assert(f.A.Sessions.SetRecording(true)); f:capture(101, 121)
    local savedSecond = snapshot(second)
    f.history.scrollExtent = 18
    f.UI.Refresh()
    historyPage(f, 121, 121, 3, 3)
    equal(f.history.topLine, 19)
    f:click("<", f.history.parent.parent)
    f.history:SetText("Unsaved review"); f.history:SetTopLineIndex(5)
    f.focus = "native chat"
    f:click("Previous", f.participants.parent.parent)
    equal(f.A.Sessions.Current(), first)
    historyPage(f, 21, 21, 3, 3)
    equal(f.history.topLine, 19, "switch follows last page rather than restoring older browsing")
    equal(f.focus, "native chat")
    f:click("Next", f.participants.parent.parent)
    equal(f.A.Sessions.Current(), second)
    historyPage(f, 121, 121, 3, 3)
    equal(f.history.topLine, 19); equal(f.focus, "native chat")
    unchanged(first, savedFirst); unchanged(second, savedSecond)
    local empty = f:session("Switch to empty")
    historyPage(f, 1, 0, 1, 1)
    equal(f.history:GetText(), ""); equal(f.history.topLine, 1)
    equal(f.A.Sessions.Current(), empty)
end)

test("a long wrapped final message scrolls using the extent of the newly rendered text", function()
    local f = fixture():init()
    local session = f:session("Wrapped history")
    assert(f.A.Sessions.SetRecording(true)); f:capture(1, 10)
    f.UI.Refresh(); f.UI.Toggle(); f:click("Sessions")
    f.history:SetText("Temporary review edits"); f.history:SetTopLineIndex(2)
    local longText = string.rep("A long roleplay paragraph that wraps in the native editor. ", 40)
    assert(f.A.Sessions.Capture(CHAT_CHANNEL_SAY, "Local Hero", longText, false, "@Local"))
    local saved = snapshot(session)
    f.history.scrollExtent = 47 -- Simulate wrapped visual lines, not newline/message count.
    local extents, writes, scrolls = f.history.extentCalls, f.history.setTextCalls, f.history.topLineCalls
    f.focus = "native chat"
    f.UI.Refresh()
    assert(f.history:GetText():find(longText, 1, true), "complete final message rendered")
    assert(not f.history:GetText():find("Line ", 1, true), "final page contains only the new message")
    f:find(function(item) return item.text and item.text:find("History 2/2 - 11 messages", 1, true) end)
    equal(f.history.extentText, f.history:GetText(), "GetScrollExtents sees new SetText content")
    equal(f.history.extentCalls, extents + 1)
    equal(f.history.setTextCalls, writes + 1); equal(f.history.topLineCalls, scrolls + 1)
    equal(f.history.topLine, 48, "native extent plus one, not one message or eleven archive entries")
    equal(f.focus, "native chat", "auto-scroll does not take focus")
    f:click("<", f.history.parent.parent)
    historyPage(f, 1, 10, 1, 2)
    equal(f.history.topLine, 1)
    f:click(">", f.history.parent.parent)
    equal(f.history.topLine, 1, "manually opening wrapped final page starts at top")
    equal(f.history.extentCalls, extents + 1, "manual page changes do not query bottom extent")
    unchanged(session, saved)
end)

for _, visibility in ipairs({ "hidden window", "Compose tab" }) do
    test("new history follows final page while on " .. visibility .. " and survives showing Sessions", function()
        local f = fixture():init()
        local session = f:session("Hidden arrival")
        assert(f.A.Sessions.SetRecording(true)); f:capture(1, 20)
        f.UI.Refresh(); f.UI.Toggle(); f:click("Sessions")
        f:click("<", f.history.parent.parent)
        f.history:SetText("Older review"); f.history:SetTopLineIndex(5)
        if visibility == "hidden window" then f:close() else f:click("Compose") end
        assert(f.history:IsHidden())
        f.focus = "native chat"
        f.history.scrollExtent = 12
        f:capture(21, 21); f.UI.Refresh()
        historyPage(f, 21, 21, 3, 3)
        equal(f.history.topLine, 13); equal(f.focus, "native chat")
        assert(f.history:IsHidden(), "arrival does not open Sessions")
        local writes, scrolls, extents = f.history.setTextCalls, f.history.topLineCalls, f.history.extentCalls
        if visibility == "hidden window" then f.UI.Toggle() else f:click("Sessions") end
        assert(not f.history:IsHidden())
        historyPage(f, 21, 21, 3, 3)
        equal(f.history.topLine, 13); equal(f.focus, "native chat")
        equal(f.history.setTextCalls, writes); equal(f.history.topLineCalls, scrolls)
        equal(f.history.extentCalls, extents, "showing does not repeat arrival scrolling")
        equal(#session.messages, 21)
    end)
end

for _, count in ipairs({ 1, 9, 10, 11, 20, 21 }) do
    test("history browses chronological pages for " .. count .. " equal-time messages without changing the archive", function()
        local f = fixture():init()
        local session = f:session("History")
        assert(f.A.Sessions.SetRecording(true))
        f:capture(1, count)
        local saved, records = snapshot(session), {}
        for i, record in ipairs(session.messages) do
            records[i] = record
            equal(record.timestamp, 1700000000, "equal timestamps retain insertion order")
        end
        f.UI.Refresh(); f.UI.Toggle(); f:click("Sessions")
        local pages = math.ceil(count / 10)
        historyPage(f, (pages - 1) * 10 + 1, count, pages, pages)
        equal(f.history.topLine, math.max(0, count - (pages - 1) * 10 - 4) + 1, "arrival uses scroll extent plus one")
        for page = pages - 1, 1, -1 do
            f.history:SetTopLineIndex(7)
            f:click("<", f.history.parent.parent)
            historyPage(f, (page - 1) * 10 + 1, math.min(count, page * 10), page, pages)
            equal(f.history.topLine, 1, "previous page starts at top")
        end
        for page = 2, pages do
            f.history:SetTopLineIndex(7)
            f:click(">", f.history.parent.parent)
            historyPage(f, (page - 1) * 10 + 1, math.min(count, page * 10), page, pages)
            equal(f.history.topLine, 1, "next page starts at top, even on latest page")
        end
        unchanged(session, saved)
        for i, record in ipairs(records) do equal(session.messages[i], record, "saved record identity/order") end
    end)
end

for _, scenario in ipairs({
    { count = 9, page = 1 },
    { count = 10, page = 1 },
    { count = 11, page = 1 },
    { count = 11, page = 2 },
    { count = 20, page = 1 },
    { count = 20, page = 2 },
    { count = 21, page = 2 },
}) do
    test("arrival after " .. scenario.count .. " messages on page " .. scenario.page .. " follows final page and native bottom", function()
        local f = fixture():init()
        local session = f:session("Following")
        assert(f.A.Sessions.SetRecording(true))
        f:capture(1, scenario.count)
        f.UI.Refresh(); f.UI.Toggle(); f:click("Sessions")
        for page = math.ceil(scenario.count / 10) - 1, scenario.page, -1 do
            f:click("<", f.history.parent.parent)
        end
        historyPage(f, (scenario.page - 1) * 10 + 1, math.min(scenario.count, scenario.page * 10),
            scenario.page, math.ceil(scenario.count / 10))
        f.history:SetText("Temporary review edits")
        f.history:SetTopLineIndex(7)
        f.history.scrollExtent = 23
        f:capture(scenario.count + 1, scenario.count + 1)
        f.composer:TakeFocus()
        f.UI.Refresh()
        local count = scenario.count + 1
        local pages = math.ceil(count / 10)
        historyPage(f, (pages - 1) * 10 + 1, count, pages, pages)
        equal(f.history.topLine, 24, "new arrival uses native extent plus one, not message count")
        equal(f.history.extentText, f.history:GetText(), "extent measured after replacing review edits")
        equal(f.focus, f.composer, "arrival does not steal focus")
        equal(session.messages[count].text, "Line " .. count)
    end)
end

test("unrelated refreshes preserve older page, scroll and temporary review edits", function()
    local f = fixture():init()
    local session = f:session("Review", "@Saved")
    assert(f.A.Sessions.SetRecording(true))
    f:capture(1, 21)
    local saved = snapshot(session)
    f.UI.Refresh(); f.UI.Toggle(); f:click("Sessions")
    f:click("<", f.history.parent.parent)
    f.history:SetTopLineIndex(8)
    for i = 1, 3 do f.UI.Refresh() end
    historyPage(f, 11, 20, 2, 3)
    equal(f.history.topLine, 8)
    f.history:SetText("Copy/edit only")
    f.history:TakeFocus()
    local writes, scrolls, extents = f.history.setTextCalls, f.history.topLineCalls, f.history.extentCalls
    f.UI.Notify("Unrelated queue notice")
    for i = 1, 3 do f.UI.Refresh() end
    equal(f.focus, f.history, "unrelated refresh preserves focus")
    f:click("Compose"); f.UI.Refresh(); f:click("Sessions")
    f:close(); f.UI.Refresh(); f.UI.Toggle()
    equal(f.history:GetText(), "Copy/edit only")
    equal(f.history.topLine, 8)
    equal(f.history.setTextCalls, writes, "unchanged history is not rewritten")
    equal(f.history.topLineCalls, scrolls, "unchanged history is not scrolled")
    equal(f.history.extentCalls, extents, "unchanged history does not query scroll extents")
    f:click(">", f.history.parent.parent)
    historyPage(f, 21, 21, 3, 3)
    equal(f.history.topLine, 1, "manual navigation replaces edits and starts at top")
    unchanged(session, saved)
end)

test("retention-cap arrivals with equal timestamps and unchanged count return older browsing to newest page", function()
    local f = fixture():init()
    local session = f:session("Retention")
    assert(f.A.Sessions.SetRecording(true))
    f:capture(1, 2000)
    f.UI.Refresh(); f.UI.Toggle(); f:click("Sessions")
    historyPage(f, 1991, 2000, 200, 200)
    local previousNewest = session.messages[2000]
    for number = 2001, 2002 do
        if number == 2001 then
            f:click("<", f.history.parent.parent)
            historyPage(f, 1981, 1990, 199, 200)
        end
        f.history:SetTopLineIndex(6)
        f:capture(number, number)
        equal(#session.messages, 2000)
        equal(session.dropped, number - 2000)
        equal(session.messages[1999], previousNewest)
        equal(session.messages[2000].timestamp, previousNewest.timestamp)
        assert(session.messages[2000] ~= previousNewest)
        local saved = snapshot(session)
        f.UI.Refresh()
        historyPage(f, number - 9, number, 200, 200)
        equal(f.history.topLine, 7, "ten lines in a four-line viewport: extent six plus one")
        unchanged(session, saved)
        previousNewest = session.messages[2000]
    end
end)

test("saved message times and session creation use local readable dates without rewriting archived fields", function()
    local calls = {}
    local formatted = { [0] = "1970-01-01 03:00:00", [1700000000] = "2023-11-15 01:13:20" }
    withDate(function(format, timestamp, ...)
        calls[#calls + 1] = { format = format, timestamp = timestamp, extra = select("#", ...) }
        return formatted[timestamp]
    end, function()
        local f = fixture():init()
        local session = f:session("Dates")
        assert(f.A.Sessions.SetRecording(true))
        f:capture(1, 2)
        session.createdAt = 0
        session.messages[1].timestamp = 1700000000
        session.messages[2].timestamp = 0
        local saved = snapshot(session)
        calls = {}
        f.UI.Refresh()
        historyPage(f, 1, 2, 1, 1)
        for _, text in pairs(formatted) do
            assert(f.history:GetText():find("[" .. text .. "]", 1, true), "readable saved message time")
        end
        f:find(function(item) return item.text and item.text:find("Created: " .. formatted[0], 1, true) end)
        equal(#calls, 3, "creation and two saved messages formatted")
        local seen = {}
        for _, call in ipairs(calls) do
            equal(call.format, "%Y-%m-%d %H:%M:%S", "local timezone format (no UTC prefix)")
            equal(call.extra, 0)
            assert(formatted[call.timestamp], "format the original saved timestamp")
            seen[call.timestamp] = (seen[call.timestamp] or 0) + 1
        end
        equal(seen[0], 2); equal(seen[1700000000], 1)
        unchanged(session, saved)
    end)
end)

test("invalid saved timestamps render Unknown time without calling os.date or mutating the archive", function()
    local cases = {
        { "missing", nil }, { "string", "1700000000" }, { "boolean", false }, { "table", {} },
        { "negative", -1 }, { "infinity", math.huge }, { "negative infinity", -math.huge },
        { "NaN", 0 / 0 }, { "fractional", 1700000000.5 },
    }
    for _, case in ipairs(cases) do
        local f = fixture():init()
        local session = f:session(case[1])
        assert(f.A.Sessions.SetRecording(true))
        f:capture(1, 1)
        session.createdAt, session.messages[1].timestamp = case[2], case[2]
        local saved, calls = snapshot(session), 0
        withDate(function() calls = calls + 1; return "Unexpected date" end, function()
            f.UI.Refresh()
            assert(f.history:GetText():find("[Unknown time]", 1, true), case[1])
            f:find(function(item) return item.text and item.text:find("Created: Unknown time", 1, true) end)
            equal(calls, 0, "invalid timestamp rejected before date formatter: " .. case[1])
            unchanged(session, saved)
        end)
    end
end)

for _, mode in ipairs({ "missing", "throwing" }) do
    test(mode .. " os.date safely renders Unknown time and leaves saved timestamps intact", function()
        local f = fixture():init()
        local session = f:session("Unavailable date")
        assert(f.A.Sessions.SetRecording(true))
        f:capture(1, 1)
        local saved, calls = snapshot(session), 0
        local date
        if mode == "throwing" then
            date = function() calls = calls + 1; error("date unavailable") end
        end
        withDate(date, function()
            f.UI.Refresh()
            assert(f.history:GetText():find("[Unknown time]", 1, true))
            f:find(function(item) return item.text and item.text:find("Created: Unknown time", 1, true) end)
            if mode == "throwing" then equal(calls, 2, "guarded creation and message formatting") end
            unchanged(session, saved)
        end)
    end)
end

test("only main move stop persists position; indicator movement is independent", function()
    local position = { left = 120, top = 140 }
    local f = fixture(position):init()
    equal(f.main.anchor[1], TOPLEFT); equal(f.main.anchor[4], 120); equal(f.main.anchor[5], 140)
    f.main.left, f.main.top = 44, 55
    f.UI.Toggle(); f:close(); f.UI.Refresh()
    equal(position.left, 120); equal(position.top, 140)
    f.main.handlers.OnMoveStop(f.main)
    equal(position.left, 44); equal(position.top, 55)
    for _, indicator in ipairs({ f.queue, f.recording }) do
        local bar = f:find(function(item) return item.parent == indicator and item.handlers.OnMouseDown end)
        bar.handlers.OnMouseDown(bar, MOUSE_BUTTON_INDEX_LEFT)
        assert(indicator.moving)
        bar.handlers.OnMouseUp(bar, MOUSE_BUTTON_INDEX_LEFT)
        assert(not indicator.moving and not indicator.movable)
    end
    equal(position.left, 44); equal(position.top, 55)
    local centered = fixture():init()
    equal(centered.main.anchor[1], CENTER)
    equal(centered.A.saved.window.left, nil)
end)

-- Exercise completion through the real Queue, not by synthesizing UI completion
-- for ordinary sends. Only stale-callback tests call the UI hook directly.
local twoChunkDraft = "First distinct piece.\nLast distinct piece."
local threeChunkDraft = "First piece here.\nMiddle piece here.\nLast piece here."

local function startCompose(f, text)
    if f.main:IsHidden() then f.UI.Toggle() end
    f.composer:SetText(text)
    f:click("Preview")
    f:click("Prepare / Start")
    assert(f.A.Queue.active, "Compose created an active queue")
    equal(f.composer:GetText(), text, "Start preserves Compose")
    return f.A.Queue
end

local function runTimer(f, delay)
    for i, timer in ipairs(f.timers) do
        if timer.delay == delay then
            table.remove(f.timers, i)
            timer.callback()
            return
        end
    end
    error("No pending " .. delay .. "ms timer")
end

local function submitCurrent(f, text)
    local Q = f.A.Queue
    assert(Q.active and Q.staged and not Q.paused and not Q.pending)
    text = text or Q.chunks[Q.current]
    Q.ObserveSubmission(text, Q.channel, Q.target)
    assert(Q.pending and not Q.pending.ambiguous, "observed unique native submission")
    return text
end

local function confirmCurrent(f, text)
    local Q = f.A.Queue
    local index, postId, count = Q.current, Q.postId, #Q.chunks
    text = submitCurrent(f, text)
    local meta = assert(Q.OnMessage(Q.channel, "Local Hero", text, false, "@Local"))
    equal(meta.postId, postId); equal(meta.chunkIndex, index); equal(meta.chunkCount, count)
    return meta, text
end

local function watchCompletions(f)
    local calls, original = {}, f.UI.OnQueueCompleted
    f.UI.OnQueueCompleted = function(postId)
        calls[#calls + 1] = postId
        if original then return original(postId) end
    end
    return calls
end

for _, hidden in ipairs({ false, true }) do
    test("single confirmed Compose clears and invalidates preview without side effects; hidden=" .. tostring(hidden), function()
        local f = fixture():init()
        local emptyPreviewTitle = "Preview: use Preview to calculate with applied settings."
        local calls = watchCompletions(f)
        local Q = startCompose(f, "A short post.")
        equal(#Q.chunks, 1)
        local postId = Q.postId
        if hidden then f:close() else f.composer:TakeFocus() end
        local focus, notices = f.focus, #f.notices
        local changes, notifications = 0, 0
        local onTextChanged, notify = f.composer.handlers.OnTextChanged, f.UI.Notify
        f.composer:SetHandler("OnTextChanged", function(...)
            changes = changes + 1
            return onTextChanged(...)
        end)
        f.UI.Notify = function(...)
            notifications = notifications + 1
            return notify(...)
        end
        f.trace = {}
        confirmCurrent(f)
        assert(not Q.active and f.queue:IsHidden())
        equal(f.composer:GetText(), "", "confirmed Compose cleared")
        equal(changes, 1, "clear uses existing OnTextChanged handler")
        equal(f.preview:GetText(), "", "cached preview invalidated")
        f:find(function(item) return item.text == emptyPreviewTitle end)
        equal(f:button("<", f.preview.parent.parent).enabled, false)
        equal(f:button(">", f.preview.parent.parent).enabled, false)
        equal(#calls, 1); equal(calls[1], postId)
        equal(Q.OnMessage(Q.channel, "Local Hero", Q.chunks[1], false, "@Local"), nil)
        runTimer(f, 10000)
        equal(#calls, 1, "duplicate echo and stale timeout cannot repeat completion")
        equal(f.focus, focus, "completion leaves focus alone")
        equal(f.main:IsHidden(), hidden, "completion leaves window visibility alone")
        equal(#f.notices, notices); equal(notifications, 0)
        equal(#f.trace, 0, "no blur, preparation or notification on completion")
        equal(#f.prepared, 1); equal(f.sends, 0); equal(f.violations, 0)
    end)
end

test("all multi-chunk echoes clear Compose, retain the archive and allow a fresh next batch", function()
    local f = fixture():init()
    local session = f:session("Confirmed posts")
    assert(f.A.Sessions.SetRecording(true))
    local calls = watchCompletions(f)
    local Q = startCompose(f, threeChunkDraft)
    equal(#Q.chunks, 3)
    local postId, chunks = Q.postId, snapshot(Q.chunks)
    equal(#session.messages, 0, "preparation is not archived")
    for index = 1, #chunks do
        local meta, text = confirmCurrent(f)
        assert(f.A.Sessions.Capture(CHAT_CHANNEL_SAY, "Local Hero", text, false, "@Local", meta))
        if index < #chunks then
            equal(f.composer:GetText(), threeChunkDraft, "partial confirmation preserves Compose")
            equal(#calls, 0, "no early completion hook")
            equal(Q.staged, nil, "next preparation is deferred")
            runTimer(f, 50)
            equal(Q.staged.index, index + 1)
            equal(f.prepared[#f.prepared].automatic, true)
        end
    end
    equal(#session.messages, #chunks)
    for index, record in ipairs(session.messages) do
        local clean, marked = f.A.Splitter.StripMessageTag(chunks[index])
        equal(marked, true); equal(record.addonMarked, true)
        equal(record.text, clean); equal(record.postId, postId)
        equal(record.chunkIndex, index); equal(record.chunkCount, #chunks)
    end
    assert(f.A.Sessions.IsRecording(), "clearing does not stop recording")
    equal(f.composer:GetText(), ""); equal(f.preview:GetText(), "")
    equal(#calls, 1); equal(calls[1], postId)
    local archive = snapshot(session)
    Q = startCompose(f, twoChunkDraft)
    assert(Q.postId ~= postId, "next batch has a fresh ID")
    equal(#Q.chunks, 2)
    confirmCurrent(f)
    equal(f.composer:GetText(), twoChunkDraft, "next batch does not inherit confirmed indexes")
    equal(#calls, 1)
    runTimer(f, 50)
    confirmCurrent(f)
    equal(f.composer:GetText(), ""); equal(#calls, 2); equal(calls[2], Q.postId)
    unchanged(session, archive)
    equal(f.sends, 0)
end)

test("native chat edits still confirm the batch without editing Compose or its planned chunks", function()
    local f = fixture():init()
    local session = f:session("Native edits")
    assert(f.A.Sessions.SetRecording(true))
    local Q = startCompose(f, "Original Compose text.")
    local chunks = snapshot(Q.chunks)
    local actual = submitCurrent(f, "Edited in native chat.")
    equal(Q.OnMessage(Q.channel, "Local Hero", chunks[1], false, "@Local"), nil)
    equal(f.composer:GetText(), "Original Compose text.")
    local meta = assert(Q.OnMessage(Q.channel, "Local Hero", actual, false, "@Local"))
    local record = assert(f.A.Sessions.Capture(Q.channel, "Local Hero", actual, false, "@Local", meta))
    equal(record.text, actual); equal(record.postId, Q.postId)
    unchanged(Q.chunks, chunks)
    equal(f.composer:GetText(), "", "native edits do not invalidate the Compose snapshot")
end)

for _, mode in ipairs({ "changed draft", "edit then restore", "OnTextChanged with identical text" }) do
    test("completion preserves " .. mode, function()
        local f = fixture():init()
        local Q = startCompose(f, "Original draft.")
        local expected = "Original draft."
        if mode == "OnTextChanged with identical text" then
            f.composer.handlers.OnTextChanged(f.composer)
        else
            f.composer:SetText("A new unsent draft.")
            if mode == "edit then restore" then f.composer:SetText(expected)
            else expected = f.composer:GetText() end
        end
        f:click("Preview")
        local preview = f.preview:GetText()
        confirmCurrent(f)
        assert(not Q.active)
        equal(f.composer:GetText(), expected, "any Compose text event invalidates association")
        equal(f.preview:GetText(), preview, "preserved draft keeps its preview")
    end)
end

for _, pending in ipairs({ false, true }) do
    test("Cancel preserves Compose and ignores a late echo; pending=" .. tostring(pending), function()
        local f = fixture():init()
        local calls = watchCompletions(f)
        local Q = startCompose(f, "Cancelled draft.")
        local text = Q.chunks[1]
        if pending then submitCurrent(f) end
        local preview = f.preview:GetText()
        f:click("Cancel", f.queue)
        equal(Q.OnMessage(CHAT_CHANNEL_SAY, "Local Hero", text, false, "@Local"), nil)
        if pending then runTimer(f, 10000) end
        assert(not Q.active)
        equal(f.composer:GetText(), "Cancelled draft."); equal(f.preview:GetText(), preview)
        equal(#calls, 0)
    end)
end

test("manual Finish after a timeout preserves Compose even if the final echo later arrives", function()
    local f = fixture():init()
    local calls = watchCompletions(f)
    local Q = startCompose(f, "Manually finished.")
    local text = submitCurrent(f)
    runTimer(f, 10000)
    assert(Q.paused and Q.pending)
    equal(f.composer:GetText(), "Manually finished.")
    f:click("Finish", f.queue)
    equal(Q.OnMessage(CHAT_CHANNEL_SAY, "Local Hero", text, false, "@Local"), nil)
    assert(not Q.active)
    equal(f.composer:GetText(), "Manually finished."); equal(#calls, 0)
end)

for _, pending in ipairs({ false, true }) do
    test("a confirmed final chunk cannot clear an earlier skipped chunk; pending=" .. tostring(pending), function()
        local f = fixture():init()
        local calls = watchCompletions(f)
        local Q = startCompose(f, twoChunkDraft)
        equal(#Q.chunks, 2)
        local first = Q.chunks[1]
        if pending then submitCurrent(f) end
        f:click("Next", f.queue)
        equal(Q.current, 2)
        equal(Q.OnMessage(Q.channel, "Local Hero", first, false, "@Local"), nil)
        confirmCurrent(f)
        assert(not Q.active)
        equal(f.composer:GetText(), twoChunkDraft, "final echo alone is not full confirmation")
        equal(#calls, 0, "skipped batch must not invoke completion")
    end)
end

test("confirming one index twice cannot substitute for a skipped index", function()
    local f = fixture():init()
    local calls = watchCompletions(f)
    local Q = startCompose(f, threeChunkDraft)
    equal(#Q.chunks, 3)
    confirmCurrent(f)
    runTimer(f, 50)
    f:click("Previous", f.queue)
    equal(Q.current, 1)
    -- Different actual text avoids the queue's repeated-fingerprint guard: this
    -- is a second real confirmation for index 1, not confirmation for index 2.
    confirmCurrent(f, "First piece revised.")
    runTimer(f, 50)
    f:click("Next", f.queue)
    equal(Q.current, 3)
    confirmCurrent(f)
    assert(not Q.active)
    equal(f.composer:GetText(), threeChunkDraft)
    equal(#calls, 0, "count distinct indexes, not outgoing echoes")
end)

for _, previous in ipairs({ "completed", "cancelled" }) do
    test("confirmed indexes do not leak from a " .. previous .. " batch into a later skipped batch", function()
        local f = fixture():init()
        local calls = watchCompletions(f)
        local Q = startCompose(f, twoChunkDraft)
        local oldId = Q.postId
        confirmCurrent(f)
        if previous == "completed" then
            runTimer(f, 50)
            confirmCurrent(f)
        else
            f:click("Cancel", f.queue)
            runTimer(f, 50)
            assert(not Q.active and not Q.staged, "cancelled batch timer cannot stage a chunk")
        end
        local completed = #calls
        Q = startCompose(f, threeChunkDraft)
        assert(Q.postId ~= oldId)
        f:click("Next", f.queue)
        equal(Q.current, 2)
        confirmCurrent(f)
        runTimer(f, 50)
        confirmCurrent(f)
        assert(not Q.active)
        equal(f.composer:GetText(), threeChunkDraft, "index 1 was never confirmed in this batch")
        equal(#calls, completed, "prior confirmations cannot complete this batch")
    end)
end

test("a skipped index can be revisited and confirmed before full completion", function()
    local f = fixture():init()
    local Q = startCompose(f, twoChunkDraft)
    f:click("Next", f.queue)
    f:click("Previous", f.queue)
    confirmCurrent(f)
    equal(f.composer:GetText(), twoChunkDraft)
    runTimer(f, 50)
    confirmCurrent(f)
    assert(not Q.active)
    equal(f.composer:GetText(), "", "navigation alone does not permanently disqualify a batch")
end)

test("timeouts preserve Compose until eventual full confirmation, including a paused final echo", function()
    local f = fixture():init()
    local calls = watchCompletions(f)
    local Q = startCompose(f, twoChunkDraft)
    local first = submitCurrent(f)
    runTimer(f, 10000)
    assert(Q.paused and Q.pending)
    equal(f.composer:GetText(), twoChunkDraft); equal(#calls, 0)
    assert(Q.OnMessage(Q.channel, "Local Hero", first, false, "@Local"))
    assert(Q.active and Q.paused and not Q.pending and not Q.staged)
    equal(f.composer:GetText(), twoChunkDraft)
    equal(#f.prepared, 1, "late echo while paused cannot auto-prepare")
    f:click("Resume", f.queue)
    local last = submitCurrent(f)
    runTimer(f, 10000)
    assert(Q.paused and Q.pending)
    equal(f.composer:GetText(), twoChunkDraft); equal(#calls, 0)
    assert(Q.OnMessage(Q.channel, "Local Hero", last, false, "@Local"))
    assert(not Q.active)
    equal(f.composer:GetText(), ""); equal(#calls, 1); equal(calls[1], Q.postId)
end)

test("pre-submission, wrong text, wrong channel, other-player and service echoes never clear Compose", function()
    local f = fixture():init()
    local calls = watchCompletions(f)
    local Q = startCompose(f, "Echo guards.")
    local text = Q.chunks[1]
    equal(Q.OnMessage(Q.channel, "Local Hero", text, false, "@Local"), nil)
    equal(f.composer:GetText(), "Echo guards.")
    submitCurrent(f)
    local cases = {
        { Q.channel, "Local Hero", "Unrelated text", false, "@Local" },
        { CHAT_CHANNEL_EMOTE, "Local Hero", text, false, "@Local" },
        { Q.channel, "Other Hero", text, false, "@Other" },
        { Q.channel, "Local Hero", text, true, "@Local" },
    }
    for _, event in ipairs(cases) do
        equal(Q.OnMessage(event[1], event[2], event[3], event[4], event[5]), nil)
        assert(Q.active and Q.pending)
        equal(f.composer:GetText(), "Echo guards."); equal(#calls, 0)
    end
    assert(Q.OnMessage(Q.channel, "Local Hero", text, false, "@Local"))
    equal(f.composer:GetText(), ""); equal(#calls, 1)
end)

test("failed initial preparation retains the new Compose association for Resume and completion", function()
    local f = fixture():init()
    local prepare = f.A.Chat.Prepare
    f.A.Chat.Prepare = function() return nil, "Native input is occupied." end
    local Q = startCompose(f, "Resume this draft.")
    local postId = Q.postId
    assert(Q.active and Q.paused and not Q.staged)
    equal(#f.prepared, 0)
    equal(f.notices[#f.notices], "Native input is occupied.")
    f.A.Chat.Prepare = prepare
    f:click("Resume", f.queue)
    equal(Q.postId, postId)
    assert(Q.staged and not Q.paused)
    confirmCurrent(f)
    equal(f.composer:GetText(), "", "Start's failure result does not discard a newly created batch")
end)

test("rejected second Start preserves the unchanged original batch association", function()
    local f = fixture():init()
    local Q = startCompose(f, "Original active batch.")
    local postId = Q.postId
    f:click("Prepare / Start")
    equal(f.starts, 2); equal(#f.prepared, 1); equal(Q.postId, postId)
    assert(f.notices[#f.notices]:find("existing queue", 1, true))
    confirmCurrent(f)
    equal(f.composer:GetText(), "", "rejected Start must not erase the original association")
end)

test("rejected second Start cannot associate an edited draft with the active batch", function()
    local f = fixture():init()
    local Q = startCompose(f, "Original active batch.")
    local postId = Q.postId
    f.composer:SetText("Replacement draft.")
    f:click("Prepare / Start")
    equal(Q.postId, postId); equal(#f.prepared, 1)
    confirmCurrent(f)
    equal(f.composer:GetText(), "Replacement draft.", "rejected Start must not replace an invalidated snapshot")
end)

test("an external batch with identical Compose text cannot inherit a cancelled Compose association", function()
    local f = fixture():init()
    local Q = startCompose(f, "Same draft, new batch.")
    local oldId = Q.postId
    f:click("Cancel", f.queue)
    assert(f.A.Start(f.composer:GetText(), CHAT_CHANNEL_SAY))
    assert(Q.postId ~= oldId)
    confirmCurrent(f)
    assert(not Q.active)
    equal(f.composer:GetText(), "Same draft, new batch.", "only Compose-created queues can clear Compose")
end)

test("old completion cannot clear a different batch or consume its current association", function()
    local f = fixture():init()
    local Q = startCompose(f, "Same draft, new batch.")
    local oldId = Q.postId
    f:click("Cancel", f.queue)
    f:click("Prepare / Start")
    assert(Q.postId ~= oldId)
    assert(type(f.UI.OnQueueCompleted) == "function", "UI completion hook is available")
    f.UI.OnQueueCompleted(oldId)
    equal(f.composer:GetText(), "Same draft, new batch.")
    confirmCurrent(f)
    equal(f.composer:GetText(), "", "stale completion must not discard the current snapshot")
    f.composer:SetText("Same draft, new batch.")
    f.UI.OnQueueCompleted(Q.postId)
    equal(f.composer:GetText(), "Same draft, new batch.", "completion is not reusable after retyping")
end)

test("queue completion remains safe when the optional UI completion hook is absent", function()
    local f = fixture():init()
    local Q = startCompose(f, "No completion listener.")
    f.UI.OnQueueCompleted = nil
    confirmCurrent(f)
    assert(not Q.active)
    equal(f.composer:GetText(), "No completion listener.")
end)

print(string.format("UI: %d tests passed, %d failed", tests, #failures))
if #failures > 0 then error(string.format("UI: %d test(s) failed", #failures), 0) end
