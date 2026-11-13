-- Putting a message into the chat box.
--
-- ---------------------------------------------------------------------------------------
-- WHY THE PLAYER PRESSES SEND
-- ---------------------------------------------------------------------------------------
--
-- SendChatMessage is *private*. The chat system reaches it through SubmitTextEntry (the box's Enter) and
-- AutoSendTextEntry (open + submit in one go), and an add-on can call neither: one add-on frame on the stack
-- makes the callstack untrusted, and the client answers with its UI error screen. So this file does the part
-- that is open to add-ons -- it opens the box with the message in it and the channel set -- and the console's
-- own keyboard, which comes up with the message on it, sends it with its confirm button. That last press is
-- the player's. (PB's Dice and PB's Translate end the same way.)
--
-- ---------------------------------------------------------------------------------------
-- HOW THE BOX IS OPENED
-- ---------------------------------------------------------------------------------------
--
-- Exactly the way PB's ChatAssistant opens it every day on a PS5, with the text and the channel passed
-- through (and the way PB's Translate 0.4.16 opens it with a text, which ran clean):
--
--   * StartChatInput() is not used. It reaches ZO_GamepadChatSystem:StartTextEntry(), which calls the private
--     SetSetting() to persist the "chat on the HUD" setting. The private call sits behind
--     `if not dontShowHUDWindow`, so the fourth argument true is the only way an add-on can open the box.
--     That flag also skips the work that puts the chat window on screen, so it is done here: SetHUDEnabled,
--     then Maximize (or FadeIn), then the edit control takes focus -- which is what makes the platform raise its
--     keyboard.
--   * Nothing is wrapped or hooked; everything is a plain call on the chat system and a write of a text and a
--     channel into it.
--   * The box is opened `delayMs` after the wheel closes, never in the same frame as the key release: the
--     console's keyboard does not come up when the box opens while the previous focus is still unwinding (that
--     is what ChatAssistant measured on PS5: open at once = keyboard missing, open later = keyboard there).
--   * A text that begins with "/" is a slash command and is handled by the client when it is sent (a message
--     "/zone hello" puts the box on the zone channel by itself).
--
-- PB's ChatAssistant keeps a key catcher up while it waits for Enter, and a shown catcher stops the keyboard
-- from appearing. When ChatAssistant is there it is asked to stand down for the length of the open (its own
-- SuspendCatcher / ResumeCatcherWhenChatCloses / StartStuckWatchdog, the same three calls it makes around its own
-- open). All of that is guarded; without ChatAssistant nothing of it runs.

local A, S = PBS_QUICK_CHAT, PBS_QUICK_CHAT_STRINGS

A.last = nil -- what the last attempt did, for /pbqc status
A.staging = false

local IME_CHECK_MS = 2500

local function Now()
	return GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
end

local function GetChat()
	if type(ZO_GetChatSystem) ~= "function" then
		return nil
	end
	local ok, chat = pcall(ZO_GetChatSystem)
	if ok and type(chat) == "table" then
		return chat
	end
	return nil
end

-- ---------------------------------------------------------------------------------------
-- PB's ChatAssistant, when it is there
-- ---------------------------------------------------------------------------------------

local function Assistant()
	local assistant = PBS_CHAT_ASSISTANT
	if A.sv and A.sv.coop and type(assistant) == "table" then
		return assistant
	end
	return nil
end

local function CallAssistant(name)
	local assistant = Assistant()
	if assistant and type(assistant[name]) == "function" then
		return pcall(assistant[name], assistant)
	end
	return false
end

function A:CoopSuspend()
	return CallAssistant("SuspendCatcher")
end

-- After the box has opened (or has failed to): the catcher comes back when the box closes, and the stuck-box
-- watchdog runs while it is open -- both are ChatAssistant's own, started by its own open the same way.
function A:CoopResume(opened)
	local ok = CallAssistant("ResumeCatcherWhenChatCloses")
	if opened then
		CallAssistant("StartStuckWatchdog")
	end
	return ok
end

function A:HasAssistant()
	local assistant = PBS_CHAT_ASSISTANT
	return type(assistant) == "table" and type(assistant.SuspendCatcher) == "function" and type(assistant.ResumeCatcherWhenChatCloses) == "function"
end

-- ---------------------------------------------------------------------------------------
-- Opening the box
-- ---------------------------------------------------------------------------------------

-- Returns opened, why (why is a sentence when the box did not open).
function A:OpenBox(text, channelId)
	local chat = GetChat()
	if not chat then
		return false, S.whyNoSystem
	end
	if type(chat.StartTextEntry) ~= "function" or type(chat.IsTextEntryOpen) ~= "function" then
		return false, S.whyNoStart
	end
	-- Never on top of a box that is open: it holds whatever the player was typing.
	if chat:IsTextEntryOpen() then
		return false, S.whyOpen
	end

	-- The mark stays in the file if the client's error screen follows and the player reloads: a strike against
	-- "chat" (Core.lua, Sanitize). It is put back as it was afterwards, so a wheel mark ("wheelUse") survives.
	local sv = self.sv
	local before = sv.pending
	sv.pending = "chat"
	local ok, result = pcall(function()
		-- Turns the HUD chat on for this session only (making it persist is the private call).
		if type(chat.SetHUDEnabled) == "function" then
			chat:SetHUDEnabled(true)
		end
		chat:StartTextEntry(text, channelId, nil, true)
		-- StartTextEntry declines in a good number of states and says so only by not opening.
		if not chat:IsTextEntryOpen() then
			return false
		end
		-- The skipped code would have done the next three things; the minimised case uses the client's own method
		-- (never write the flag: the menu fragment, the HUD tracker column and ChatAssistant's Enter key read it).
		if chat.isMinimized and type(chat.Maximize) == "function" then
			chat:Maximize()
		elseif chat.primaryContainer and type(chat.primaryContainer.FadeIn) == "function" then
			chat.primaryContainer:FadeIn()
		end
		chat.shouldMinimizeAfterEntry = false
		local textEntry = chat.textEntry
		local edit = textEntry and type(textEntry.GetEditControl) == "function" and textEntry:GetEditControl()
		if edit and type(edit.TakeFocus) == "function" then
			edit:TakeFocus()
		end
		return true
	end)
	sv.pending = before
	if not ok then
		return false, string.format(S.whyError, tostring(result))
	end
	if result ~= true then
		return false, S.whyDeclined
	end
	sv.strikes.chat = nil
	return true
end

-- The wheel entry's job: put slot `index` into the chat box. `source` is "wheel" or "command".
function A:Stage(index, source)
	local slot = self:GetSlot(index)
	if not slot or not self:HasText(index) then
		self:Fail(string.format(S.slotNoText, index))
		return false, "empty"
	end
	if self.staging then
		self:Fail(S.busy)
		return false, "busy"
	end
	local usable, why = self:CheckGroup("chat")
	if not usable then
		self:Fail(string.format(S.noChat, why))
		return false, "disabled"
	end

	-- the last line of defence before a text reaches a client control
	local text = A.SanitizeUTF8(slot.text)
	local def = self.CHANNEL_BY_KEY[slot.channel]
	local channelId = def and def.id or nil -- nil keeps the box's current channel
	local channelName = self:ChannelName(slot.channel)
	local delay = self.sv.delayMs
	if source == "command" then
		delay = math.max(delay, self.COMMAND_DELAY_MS)
	end

	local last = { slot = index, source = source, channel = slot.channel, delay = delay, requestedAt = Now() }
	self.last = last
	self.staging = true
	-- ChatAssistant lets go of Enter for the whole wait, the way it does around its own open
	self:CoopSuspend()

	local function open()
		self.staging = false
		last.openedAt = Now()
		local opened, reason = self:OpenBox(text, channelId)
		last.opened, last.why = opened, reason
		self:CoopResume(opened)
		if not opened then
			self:Fail(string.format(S.noChat, reason or "?"))
			return
		end
		self:Note(string.format(S.staged, self:WheelName(index), channelName))
		-- one read of the console keyboard's state a little later, for /pbqc status (read-only, as ChatAssistant does)
		if type(zo_callLater) == "function" and type(IsVirtualKeyboardOnScreen) == "function" then
			zo_callLater(function()
				local okRead, value = pcall(IsVirtualKeyboardOnScreen)
				last.ime = okRead and value == true or false
				last.imeRead = okRead
				last.imeAt = Now()
			end, IME_CHECK_MS)
		end
	end
	if delay > 0 and type(zo_callLater) == "function" then
		zo_callLater(open, delay)
	else
		open()
	end
	return true
end

function A:ChatStatusLines()
	local lines = {}
	local chat = GetChat()
	local private = "?"
	if type(IsPrivateFunction) == "function" then
		local ok, value = pcall(IsPrivateFunction, "SendChatMessage")
		private = ok and tostring(value) or "cannot ask"
	end
	lines[#lines + 1] = string.format("chat: system=%s available=%s box open=%s; the game marks SendChatMessage private: %s (sending is left to the player)",
		tostring(chat ~= nil), type(IsChatSystemAvailableForCurrentPlatform) == "function" and tostring((select(2, pcall(IsChatSystemAvailableForCurrentPlatform)))) or "?",
		tostring(chat ~= nil and type(chat.IsTextEntryOpen) == "function" and chat:IsTextEntryOpen() or false), private)
	local last = self.last
	if last then
		lines[#lines + 1] = string.format("last: slot %s via %s, channel %s, wait %d ms, opened=%s%s, console keyboard %s",
			tostring(last.slot), tostring(last.source), tostring(last.channel), last.delay or 0, tostring(last.opened), last.why and (" (" .. tostring(last.why) .. ")") or "",
			last.ime == nil and (last.opened and "not read yet" or "-") or (last.ime and "on screen 2.5 s after the open" or "NOT on screen 2.5 s after the open"))
	else
		lines[#lines + 1] = "last: nothing put into the chat box yet"
	end
	lines[#lines + 1] = string.format("ChatAssistant: %s, step aside while the box opens=%s", self:HasAssistant() and "present" or "absent", tostring(self.sv.coop))
	return lines
end
